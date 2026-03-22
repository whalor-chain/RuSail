import SwiftUI
import Combine
import UniformTypeIdentifiers
import AuthenticationServices
import QuickLook

// MARK: - Theme

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }

        guard s.count == 6, let v = UInt64(s, radix: 16) else {
            self = .white
            return
        }

        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum AppTheme {
    static let accent = Color(hex: "#5272FF")
    static let secondary = Color(hex: "#7F8CFF")
    static let logoAssetName = "AppLogo"
}

// MARK: - Session

enum SessionKeys {
    static let isSignedIn = "session.isSignedIn"
    static let appleUserID = "session.appleUserID"
    static let displayName = "session.displayName"
    static let email = "session.email"
}

@MainActor
final class SessionStore: ObservableObject {
    @AppStorage(SessionKeys.isSignedIn) var isSignedIn: Bool = false
    @AppStorage(SessionKeys.appleUserID) var appleUserID: String = ""
    @AppStorage(SessionKeys.displayName) var displayName: String = ""
    @AppStorage(SessionKeys.email) var email: String = ""

    func signOut() {
        isSignedIn = false
        appleUserID = ""
        displayName = ""
        email = ""
    }

    func signIn(userID: String, displayName: String?, email: String?) {
        appleUserID = userID
        if let displayName, !displayName.isEmpty {
            self.displayName = displayName
        }
        if let email, !email.isEmpty {
            self.email = email
        }
        isSignedIn = true
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var session = SessionStore()
    @EnvironmentObject private var deepLink: DeepLinkState

    var body: some View {
        Group {
            if session.isSignedIn {
                RootTabView()
                    .environmentObject(session)
                    .environmentObject(deepLink)
            } else {
                LoginView()
                    .environmentObject(session)
            }
        }
    }
}

enum RuSailTab: Hashable {
    case home
    case calendar
    case profile
}

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var deepLink: DeepLinkState
    @StateObject private var toast = FavoriteToastState()
    @StateObject private var settingsToast = SettingsToastState()
    @State private var selectedTab: RuSailTab = .home

    private var calendarIcon: String {
        let day = Calendar.current.component(.day, from: Date())
        return "\(day).calendar"
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab("Главная", systemImage: "figure.sailing", value: .home) {
                    HomeView()
                }

                Tab("Календарь", systemImage: calendarIcon, value: .calendar) {
                    SearchView()
                }

                Tab("Профиль", systemImage: "person.fill", value: .profile) {
                    ProfileView()
                }

                Tab(role: .search) {
                    NavigationStack {
                        BrowseView()
                    }
                }
            }
            .tint(AppTheme.accent)
            .onAppear {
                let navAppearance = UINavigationBarAppearance()
                navAppearance.configureWithTransparentBackground()
                navAppearance.shadowColor = .clear
                navAppearance.backgroundColor = .clear
                navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                UINavigationBar.appearance().standardAppearance = navAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
                UINavigationBar.appearance().compactAppearance = navAppearance
            }

            FavoriteToastOverlay()
            SettingsToastOverlay()
        }
        .environmentObject(toast)
        .environmentObject(settingsToast)
        .onChange(of: deepLink.showFavorites) { newValue in
            if newValue {
                selectedTab = .home
            }
        }
    }
}


// MARK: - Login

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var errorText: String?

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 18) {
                Spacer()

                VStack(spacing: 14) {
                    Image(AppTheme.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)

                    Text("RuSail")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Войдите, чтобы пользоваться приложением")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .glassCard(.ultraThinMaterial, cornerRadius: 30)

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                errorText = "Не удалось получить Apple ID credential"
                                return
                            }

                            let userID = cred.user
                            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                                .compactMap { $0 }
                                .joined(separator: " ")
                            let email = cred.email

                            session.signIn(
                                userID: userID,
                                displayName: name.isEmpty ? nil : name,
                                email: email
                            )

                        case .failure(let error):
                            errorText = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(Capsule())


                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                }
                .glassCard(.thinMaterial, cornerRadius: 28)

                Spacer()

                Text("Продолжая, вы соглашаетесь с обработкой данных")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Deep Link

@MainActor
final class DeepLinkState: ObservableObject {
    @Published var showFavorites = false
}

extension Notification.Name {
    static let openFavorites = Notification.Name("openFavorites")
}

// MARK: - Favorite Toast

@MainActor
final class FavoriteToastState: ObservableObject {
    @Published var isShowing = false
    @Published var isAdded = true
    @Published var eventTitle = ""

    private var hideTask: Task<Void, Never>?

    func show(added: Bool, title: String) {
        hideTask?.cancel()
        eventTitle = title.count > 30 ? String(title.prefix(30)) + "…" : title
        isAdded = added

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isShowing = true
        }

        hideTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                isShowing = false
            }
        }
    }
}

// MARK: - Settings Toast

@MainActor
final class SettingsToastState: ObservableObject {
    @Published var isShowing = false
    @Published var message = ""
    @Published var icon = "checkmark.circle.fill"

    private var hideTask: Task<Void, Never>?

    func show(_ text: String, icon: String = "checkmark.circle.fill") {
        hideTask?.cancel()
        message = text
        self.icon = icon

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isShowing = true
        }

        hideTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                isShowing = false
            }
        }
    }
}

struct SettingsToastOverlay: View {
    @EnvironmentObject private var settingsToast: SettingsToastState

    var body: some View {
        VStack {
            if settingsToast.isShowing {
                HStack(spacing: 12) {
                    Image(systemName: settingsToast.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: settingsToast.isShowing)

                    Text(settingsToast.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}

struct FavoriteToastOverlay: View {
    @EnvironmentObject private var toast: FavoriteToastState

    var body: some View {
        VStack {
            if toast.isShowing {
                HStack(spacing: 12) {
                    Image(systemName: toast.isAdded ? "heart.fill" : "heart.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(toast.isAdded ? .red : .white.opacity(0.7))
                        .symbolEffect(.bounce, value: toast.isShowing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.isAdded ? "Добавлено в избранное" : "Удалено из избранного")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(toast.eventTitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}

// MARK: - Shared UI

struct GlassBackground: View {
    var showGradient: Bool = true

    var body: some View {
        ZStack {
            Color.black

            if showGradient {
                // Accent gradient at top
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.50),
                        AppTheme.secondary.opacity(0.25),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )

                // Accent orb — top right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 140, y: -180)
                    .blur(radius: 80)
            }
        }
        .ignoresSafeArea()
    }
}

struct GlassCardModifier: ViewModifier {
    var material: Material = .ultraThinMaterial
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(white: 0.11))
            }
    }
}

extension View {
    func glassCard(_ material: Material = .ultraThinMaterial, cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(material: material, cornerRadius: cornerRadius))
    }

    func glassPane(cornerRadius: CGFloat = 16) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(white: 0.11))
            }
    }
}

struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.55), in: Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    var color: Color = AppTheme.accent

    var body: some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: Capsule())
    }
}

struct RowChevron: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 26, height: 26)
                .foregroundStyle(.white.opacity(0.90))

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}
// MARK: - Favourit
struct FavoriteEventCard: View {
    let event: RaceEvent
    @ObservedObject var favoritesStore: FavoritesStore
    @EnvironmentObject private var toast: FavoriteToastState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    let willAdd = !favoritesStore.contains(event)
                    favoritesStore.toggle(event)
                    toast.show(added: willAdd, title: event.title)
                } label: {
                    Image(systemName: favoritesStore.contains(event) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(favoritesStore.contains(event) ? .red : .white)
                        .frame(width: 36, height: 36)
                        .background(Color(white: 0.2), in: Circle())
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: favoritesStore.contains(event))
            }

            infoRow(icon: "calendar", text: "\(event.startDate) – \(event.endDate)")
            infoRow(icon: "mappin.and.ellipse", text: event.location)

            VStack(alignment: .leading, spacing: 8) {
                Text("Классы яхт")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(event.classes, id: \.self) { yachtClass in
                            Text(yachtClass)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(white: 0.18), in: Capsule())
                        }
                    }
                }
                .frame(height: 38)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.11))
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.74))
                .frame(width: 18)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func shortDiscipline(_ text: String) -> String {
        if text.count > 22 {
            return String(text.prefix(22)) + "…"
        }
        return text
    }
}




// MARK: - Data models


struct YachtFilter: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let aliases: [String]
    let color: Color
}

let yachtFilters: [YachtFilter] = [
    .init(title: "Все", aliases: [], color: AppTheme.accent),
    .init(title: "Оптимист", aliases: ["Оптимист"], color: .orange),
    .init(title: "ILCA", aliases: ["Лазер 4.7", "Лазер-радиал", "Лазер-стандарт"], color: .pink),
    .init(title: "420", aliases: ["420"], color: .purple),
    .init(title: "29er", aliases: ["29-й"], color: .teal),
    .init(title: "Финн", aliases: ["Финн"], color: .mint),
    .init(title: "MX700", aliases: ["MX700", "МХ700"], color: .cyan),
    .init(title: "J/70", aliases: ["J/70"], color: .indigo),
    .init(title: "SB20", aliases: ["SB20"], color: .blue),
    .init(title: "ЭМ-КА", aliases: ["ЭМ-КА", "эМ-Ка"], color: .brown),
    .init(title: "ORC", aliases: ["Крейсерская яхта ORC", "ORC"], color: .gray),
    .init(title: "Техно/iQF", aliases: ["Парусная доска Техно", "Парусная доска IQF", "Парусная доска iQF"], color: .yellow)
]






// MARK: - Home

import SwiftUI
import Combine

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


struct HomeView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var deepLink: DeepLinkState
    @State private var showFavoritesFromShortcut = false
    private let events = raceEvents2026

    private var currentEvents: [RaceEvent] {
        events
            .filter { $0.isHappeningToday }
            .sorted {
                guard let lhs = $0.startDateValue, let rhs = $1.startDateValue else { return false }
                return lhs < rhs
            }
    }

    private var favoriteEvents: [RaceEvent] {
        events
            .filter { favoritesStore.contains($0) }
            .sorted {
                guard let lhs = $0.startDateValue, let rhs = $1.startDateValue else { return false }
                return lhs < rhs
            }
    }


    private var upcomingEvents: [RaceEvent] {
        let today = Calendar.current.startOfDay(for: Date())

        return events
            .filter {
                guard let start = $0.startDateValue else { return false }
                return Calendar.current.startOfDay(for: start) > today
            }
            .sorted {
                guard let lhs = $0.startDateValue, let rhs = $1.startDateValue else { return false }
                return lhs < rhs
            }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        headerCards
                        LiveNowCarouselSection(events: currentEvents)
                        FavoritesSection(events: favoriteEvents)
                        UpcomingEventsSection(events: upcomingEvents)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(AppTheme.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFavoritesFromShortcut) {
            FavoritesEventsSheet(events: favoriteEvents)
                .environmentObject(favoritesStore)
        }
        .onChange(of: deepLink.showFavorites) { newValue in
            if newValue {
                showFavoritesFromShortcut = true
                deepLink.showFavorites = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFavorites)) { _ in
            showFavoritesFromShortcut = true
        }
    }

    private var headerCards: some View {
        HStack(spacing: 10) {
            SmallStatCard(title: "Сейчас идут", value: "\(currentEvents.count)", tint: .green)
            SmallStatCard(title: "Избранное", value: "\(favoriteEvents.count)", tint: .red)
        }
    }

}

// MARK: - Live now carousel

struct LiveNowCarouselSection: View {
    let events: [RaceEvent]

    @State private var selectedIndex = 0
    @State private var showAllLiveEvents = false

    private let timer = Timer.publish(every: 3.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Проходят сейчас")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                if !events.isEmpty {
                    Button {
                        showAllLiveEvents = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Посмотреть")
                                .font(.subheadline.weight(.semibold))

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if events.isEmpty {
                EmptyLiveStateCard()
            } else {
                VStack(spacing: 12) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            LiveEventCard(event: event)
                                .tag(index)
                                .padding(.horizontal, 2)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 290)
                    .onReceive(timer) { _ in
                        guard events.count > 1 else { return }
                        withAnimation(.easeInOut(duration: 0.45)) {
                            selectedIndex = (selectedIndex + 1) % events.count
                        }
                    }
                    .onChange(of: events.count) { newCount in
                        if selectedIndex >= newCount {
                            selectedIndex = 0
                        }
                    }

                    HStack(spacing: 8) {
                        ForEach(0..<events.count, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.22))
                                .frame(width: index == selectedIndex ? 18 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAllLiveEvents) {
            LiveNowEventsSheet(events: events)
        }
    }
}

// MARK: - Favorites section

struct FavoritesSection: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let events: [RaceEvent]
    @State private var selectedIndex = 0
    @State private var showAllFavorites = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Избранное")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                if !events.isEmpty {
                    Button {
                        showAllFavorites = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Посмотреть")
                                .font(.subheadline.weight(.semibold))

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Пока нет избранных событий")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Добавляй соревнования в избранное в календаре, и они появятся здесь.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(18)
                .glassPane(cornerRadius: 24)
            } else {
                VStack(spacing: 12) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            FavoriteEventCard(event: event, favoritesStore: favoritesStore)
                                .tag(index)
                                .padding(.horizontal, 2)
                                .padding(.vertical, 6)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 260)

                    HStack(spacing: 8) {
                        ForEach(0..<events.count, id: \.self) { index in
                            Capsule()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.22))
                                .frame(width: index == selectedIndex ? 18 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.25), value: selectedIndex)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAllFavorites) {
            FavoritesEventsSheet(events: events)
        }
    }
}

struct FavoritesEventsSheet: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    let events: [RaceEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(showGradient: false)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(events) { event in
                            FavoriteEventCard(event: event, favoritesStore: favoritesStore)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Избранное")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}




// MARK: - Live now modal sheet

struct LiveNowEventsSheet: View {
    let events: [RaceEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(showGradient: false)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(events) { event in
                            LiveEventCard(event: event)
                                .frame(height: 290)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Проходят сейчас")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Empty state

struct EmptyLiveStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Сегодня активных соревнований нет")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Когда дата попадёт внутрь периода проведения соревнования, оно появится здесь автоматически.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassPane(cornerRadius: 24)
    }
}

// MARK: - Live event card

struct LiveEventCard: View {
    let event: RaceEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Pill(text: "Идёт сейчас", color: .green)
                        Pill(text: shortDiscipline(event.discipline), color: AppTheme.accent)
                    }
                }

                Spacer()
            }

            infoRow(icon: "calendar", text: "\(event.startDate) – \(event.endDate)")
            infoRow(icon: "mappin.and.ellipse", text: event.location)

            VStack(alignment: .leading, spacing: 8) {
                Text("Классы яхт")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(event.classes, id: \.self) { yachtClass in
                            Text(yachtClass)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(white: 0.18), in: Capsule())
                        }
                    }
                }
                .frame(height: 38)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.11))
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.74))
                .frame(width: 18)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func shortDiscipline(_ text: String) -> String {
        if text.count > 22 {
            return String(text.prefix(22)) + "…"
        }
        return text
    }
}

// MARK: - Upcoming

struct UpcomingEventsSection: View {
    let events: [RaceEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ближайшие старты")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            if events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Нет будущих стартов")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Когда в календаре появятся события позже сегодняшней даты, они будут показаны здесь.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassPane(cornerRadius: 22)
            } else {
                VStack(spacing: 12) {
                    ForEach(events) { event in
                        UpcomingEventRow(event: event)
                    }
                }
            }
        }
    }
}

struct UpcomingEventRow: View {
    let event: RaceEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(AppTheme.accent)
                    .font(.headline)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 2)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(event.startDate) – \(event.endDate)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                Text(event.location)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassPane(cornerRadius: 22)
    }
}


// MARK: - Small stat

struct SmallStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Capsule()
                .fill(tint.opacity(0.9))
                .frame(width: 28, height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPane(cornerRadius: 22)
    }
}

// MARK: - Date helpers

extension RaceEvent {
    var startDateValue: Date? {
        Self.homeDateFormatter.date(from: startDate)
    }

    var endDateValue: Date? {
        Self.homeDateFormatter.date(from: endDate)
    }

    var isHappeningToday: Bool {
        guard let startDateValue, let endDateValue else { return false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: startDateValue)
        let end = cal.startOfDay(for: endDateValue)

        return today >= start && today <= end
    }

    private static let homeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
}



// MARK: - Search

struct SearchView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var toast: FavoriteToastState
    @State private var q = ""
    @State private var selectedFilter: YachtFilter = yachtFilters[0]


    private var filteredEvents: [RaceEvent] {
        let term = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return raceEvents2026.filter { event in
            let classMatch: Bool = {
                if selectedFilter.title == "Все" { return true }
                return event.classes.contains { cls in
                    selectedFilter.aliases.contains { alias in
                        cls.localizedCaseInsensitiveContains(alias)
                    }
                }
            }()

            let searchMatch: Bool = {
                if term.isEmpty { return true }
                let haystack = [
                    event.title,
                    event.location,
                    event.discipline,
                    event.classes.joined(separator: " ")
                ].joined(separator: " ").lowercased()

                return haystack.contains(term)
            }()

            return classMatch && searchMatch
        }
        .sorted {
            if $0.month == $1.month {
                return $0.startDate < $1.startDate
            }
            return $0.month < $1.month
        }
    }

    private var groupedEvents: [(key: Int, value: [RaceEvent])] {
        Dictionary(grouping: filteredEvents, by: { $0.month })
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        filters
                        statsCard

                        ForEach(groupedEvents, id: \.key) { month, events in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(monthTitle(month))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)

                                ForEach(events) { event in
                                    eventCard(event)
                                }
                            }
                            .glassCard(.thinMaterial, cornerRadius: 28)
                        }

                        if filteredEvents.isEmpty {
                            Text("По выбранному фильтру ничего не найдено")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(.top, 24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("Календарь")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $q, prompt: "Регата, класс, город…")
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(yachtFilters) { filter in
                    let isSelected = selectedFilter == filter

                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedCategory(isSelected))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isSelected
                                ? filter.color.opacity(0.65)
                                : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                            .shadow(color: isSelected ? filter.color.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func selectedCategory(_ isSelected: Bool) -> Color {
        isSelected ? .white : .white.opacity(0.85)
    }

    private var statsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Событий")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(filteredEvents.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Фильтр")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text(selectedFilter.title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .glassPane(cornerRadius: 24)
    }

    private func eventCard(_ event: RaceEvent) -> some View {
        let isFavorite = favoritesStore.contains(event)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    let willAdd = !favoritesStore.contains(event)
                    favoritesStore.toggle(event)
                    toast.show(added: willAdd, title: event.title)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? .red : .white)
                        .scaleEffect(isFavorite ? 1.0 : 0.92)
                        .frame(width: 34, height: 34)
                        .background(Color(white: 0.2), in: Circle())
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFavorite)
            }

            Text("\(event.startDate) – \(event.endDate)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.accent)

            Text(event.location)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))

            Text(event.discipline)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(event.classes, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(white: 0.18), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.6
                                    )
                            )
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        )
    }




    private func monthTitle(_ month: Int) -> String {
        switch month {
        case 1: return "Январь"
        case 2: return "Февраль"
        case 3: return "Март"
        case 4: return "Апрель"
        case 5: return "Май"
        case 6: return "Июнь"
        case 7: return "Июль"
        case 8: return "Август"
        case 9: return "Сентябрь"
        case 10: return "Октябрь"
        case 11: return "Ноябрь"
        case 12: return "Декабрь"
        default: return "Месяц"
        }
    }
}

import SwiftUI

// MARK: - Model

struct NewsArticle: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let category: String
    let date: String
    let source: String
    let imageSystemName: String
    let content: String
    let isFeatured: Bool
}

// MARK: - Browse (Search tab)

struct BrowseCategory: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let tint: Color
}

struct BrowseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let categories: [BrowseCategory] = [
        BrowseCategory(icon: "newspaper.fill", title: "Новости", tint: .blue),
        BrowseCategory(icon: "person.3.fill", title: "Отбор в Сборную", tint: .orange),
        BrowseCategory(icon: "trophy.fill", title: "Результаты", tint: .yellow),
        BrowseCategory(icon: "cart.fill", title: "Магазин", tint: .green),
    ]

    private var filteredCategories: [BrowseCategory] {
        if searchText.isEmpty { return categories }
        return categories.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, cat in
                        NavigationLink {
                            destinationView(for: cat.title)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(cat.tint)
                                    .frame(width: 32, height: 32)

                                Text(cat.title)
                                    .font(.body)
                                    .foregroundStyle(.white)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if index < filteredCategories.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.leading, 62)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(white: 0.11))
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for title: String) -> some View {
        switch title {
        case "Новости":
            NewsView()
        case "Отбор в Сборную":
            placeholderPage(title: "Отбор в Сборную", icon: "person.3.fill", color: .orange)
        case "Результаты":
            placeholderPage(title: "Результаты", icon: "trophy.fill", color: .yellow)
        case "Магазин":
            placeholderPage(title: "Магазин", icon: "cart.fill", color: .green)
        default:
            EmptyView()
        }
    }

    private func placeholderPage(title: String, icon: String, color: Color) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(color)
                Text("Скоро")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Раздел в разработке")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - News

struct NewsView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "Все"

    private let categories = ["Все", "Регаты", "Флот", "Клубы", "Мир паруса", "Обучение"]

    private let articles: [NewsArticle] = [
        NewsArticle(
            title: "Открыт весенний сезон регат в Санкт-Петербурге",
            subtitle: "Первые старты сезона собрали экипажи из нескольких яхт-клубов города.",
            category: "Регаты",
            date: "06.03.2026",
            source: "RuSail",
            imageSystemName: "sailboat.fill",
            content: "В Санкт-Петербурге стартовал весенний сезон парусных соревнований. В программу вошли тренировочные гонки, клубные встречи и первые рейтинговые старты для взрослых и юниоров. Организаторы отмечают высокий интерес к соревнованиям и рост числа новых экипажей.",
            isFeatured: true
        ),
        NewsArticle(
            title: "Новый флот MX700 готовится к серии любительских стартов",
            subtitle: "Организаторы планируют расширить календарь коротких гонок выходного дня.",
            category: "Флот",
            date: "05.03.2026",
            source: "RuSail",
            imageSystemName: "ferry.fill",
            content: "К весеннему сезону подготовлен обновлённый флот MX700. В ближайшие месяцы он будет использоваться в формате коротких регат, корпоративных стартов и тренировок для любительских экипажей.",
            isFeatured: true
        ),
        NewsArticle(
            title: "Яхт-клубы усиливают детские программы обучения",
            subtitle: "Школы делают акцент на базовой безопасности, практике и командной работе.",
            category: "Обучение",
            date: "04.03.2026",
            source: "RuSail",
            imageSystemName: "figure.sailing",
            content: "Несколько яхт-клубов обновили свои учебные программы для детей и подростков. В новых курсах больше практики на воде, работы с ветром и манёврами, а также упражнений по взаимодействию в экипаже.",
            isFeatured: false
        ),
        NewsArticle(
            title: "Клубные лиги готовят серию городских матч-рейсов",
            subtitle: "Формат позволит зрителям следить за гонками с берега и в прямых эфирах.",
            category: "Клубы",
            date: "03.03.2026",
            source: "RuSail",
            imageSystemName: "flag.checkered.2.crossed",
            content: "Организаторы городских лиг рассматривают запуск матч-рейсов в зрительском формате. Такие гонки проще воспринимать аудитории, а их короткая продолжительность делает их удобными для трансляций.",
            isFeatured: false
        ),
        NewsArticle(
            title: "Как выбрать первую программу обучения парусному спорту",
            subtitle: "Разбираем, на что смотреть новичку перед записью в школу.",
            category: "Обучение",
            date: "02.03.2026",
            source: "RuSail",
            imageSystemName: "book.fill",
            content: "Новичкам важно обращать внимание не только на стоимость, но и на формат практики, размер групп, состояние флота и опыт инструкторов. Оптимальный старт — короткая вводная программа с выходом на воду.",
            isFeatured: false
        ),
        NewsArticle(
            title: "Мировые тренды: компактные регаты и короткие форматы набирают популярность",
            subtitle: "Организаторы всё чаще выбирают динамичные соревнования с понятным расписанием.",
            category: "Мир паруса",
            date: "01.03.2026",
            source: "RuSail",
            imageSystemName: "globe.europe.africa.fill",
            content: "Короткие форматы регат становятся всё более востребованными. Они удобны для участников, понятны зрителям и подходят для трансляций и цифрового сопровождения.",
            isFeatured: true
        )
    ]

    private var filteredArticles: [NewsArticle] {
        articles.filter { article in
            let matchesCategory = selectedCategory == "Все" || article.category == selectedCategory

            let matchesSearch =
                searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                article.title.localizedCaseInsensitiveContains(searchText) ||
                article.subtitle.localizedCaseInsensitiveContains(searchText) ||
                article.category.localizedCaseInsensitiveContains(searchText)

            return matchesCategory && matchesSearch
        }
    }

    private var featuredArticles: [NewsArticle] {
        filteredArticles.filter { $0.isFeatured }
    }

    private var regularArticles: [NewsArticle] {
        filteredArticles.filter { !$0.isFeatured }
    }

    var body: some View {
        ZStack {
            GlassBackground(showGradient: false)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    headerSection
                    categorySection

                    if filteredArticles.isEmpty {
                        emptyState
                    } else {
                        if !featuredArticles.isEmpty {
                            featuredSection
                        }

                        allNewsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .searchable(text: $searchText, prompt: "Поиск новостей")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Новости")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Свежие события, обновления флота и новости парусного сообщества")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedCategory == category ? .white : .white.opacity(0.80))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                selectedCategory == category
                                ? AppTheme.accent.opacity(0.65)
                                : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                            .shadow(color: selectedCategory == category ? AppTheme.accent.opacity(0.25) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Главное")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            TabView {
                ForEach(featuredArticles) { article in
                    NavigationLink {
                        NewsDetailView(article: article)
                    } label: {
                        FeaturedNewsCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 250)
        }
    }

    private var allNewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Все новости")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            LazyVStack(spacing: 12) {
                ForEach(regularArticles.isEmpty ? filteredArticles : regularArticles) { article in
                    NavigationLink {
                        NewsDetailView(article: article)
                    } label: {
                        NewsRowCard(article: article)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ничего не найдено")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Попробуй изменить категорию или очистить строку поиска.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassPane(cornerRadius: 24)
    }
}

// MARK: - Featured Card

struct FeaturedNewsCard: View {
    let article: NewsArticle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(white: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.40),
                                    Color.blue.opacity(0.20),
                                    Color.black.opacity(0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(article.category, systemImage: article.imageSystemName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())

                    Spacer()
                }

                Spacer()

                Text(article.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)

                Text(article.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)

                HStack {
                    Text(article.date)
                    Text("•")
                    Text(article.source)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: AppTheme.accent.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Row Card

struct NewsRowCard: View {
    let article: NewsArticle

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(white: 0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(AppTheme.accent.opacity(0.18), lineWidth: 0.6)
                    )

                Image(systemName: article.imageSystemName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(article.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text(article.date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(article.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .glassPane(cornerRadius: 24)
    }
}

// MARK: - Detail

struct NewsDetailView: View {
    let article: NewsArticle

    var body: some View {
        ZStack {
            GlassBackground(showGradient: false)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(white: 0.11))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.accent.opacity(0.35),
                                                Color.blue.opacity(0.18),
                                                Color.black.opacity(0.25)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                            .frame(height: 240)

                        VStack(alignment: .leading, spacing: 12) {
                            Label(article.category, systemImage: article.imageSystemName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.14), in: Capsule())

                            Text(article.title)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            HStack {
                                Text(article.date)
                                Text("•")
                                Text(article.source)
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                        }
                        .padding(18)
                    }

                    Text(article.subtitle)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(article.content)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Новость")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Profile

// MARK: - Document Store

enum DocKind: String, CaseIterable, Identifiable {
    case certificate = "certificate"
    case license     = "license"
    case insurance   = "insurance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .certificate: return "Сертификат РУСАДА"
        case .license:     return "Права ГИМС"
        case .insurance:   return "Страховка"
        }
    }

    var icon: String {
        switch self {
        case .certificate: return "doc.richtext"
        case .license:     return "person.text.rectangle"
        case .insurance:   return "cross.case"
        }
    }

    var tint: Color {
        switch self {
        case .certificate: return .green
        case .license:     return AppTheme.accent
        case .insurance:   return .orange
        }
    }

    fileprivate var storageKey: String { "doc_\(rawValue)_bookmark" }
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var urls: [DocKind: URL] = [:]

    init() { loadAll() }

    // MARK: — Save
    func save(_ kind: DocKind, from sourceURL: URL) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("RuSailDocs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        let dest = folder.appendingPathComponent("\(kind.rawValue).\(ext)")

        // Access security‑scoped resource
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: sourceURL, to: dest)

        if let bookmark = try? dest.bookmarkData(options: .minimalBookmark) {
            UserDefaults.standard.set(bookmark, forKey: kind.storageKey)
        }
        urls[kind] = dest
    }

    // MARK: — Delete
    func remove(_ kind: DocKind) {
        if let url = urls[kind] {
            try? FileManager.default.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: kind.storageKey)
        urls.removeValue(forKey: kind)
    }

    // MARK: — Load
    private func loadAll() {
        for kind in DocKind.allCases {
            guard let data = UserDefaults.standard.data(forKey: kind.storageKey) else { continue }
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path) {
                urls[kind] = url
            }
        }
    }

    func hasFile(_ kind: DocKind) -> Bool { urls[kind] != nil }
    func url(for kind: DocKind) -> URL? { urls[kind] }
}

// MARK: - Document Picker Representable

struct DocumentPickerView: UIViewControllerRepresentable {
    let docKind: DocKind
    @ObservedObject var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .jpeg, .png]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.store.save(parent.docKind, from: url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

@MainActor
final class ProfileVM: ObservableObject {
    @Published var vfpsID: String = "12222"
    @Published var username: String = "@whalor"
    @Published var ruSailID: String = "#866858352"
    @Published var joinedAt: String = "14.02.2026 18:49:08"

    @Published var showMyDataSheet = false
    @Published var showMyFilesSheet = false
}

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm = ProfileVM()
    @StateObject private var docStore = DocumentStore()

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        Button {
                            vm.showMyDataSheet = true
                        } label: {
                            RowChevron(icon: "person.text.rectangle", title: "Мои данные")
                                .glassCard(.thinMaterial, cornerRadius: 24)
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.showMyFilesSheet = true
                        } label: {
                            RowChevron(icon: "folder", title: "Мои файлы")
                                .glassCard(.thinMaterial, cornerRadius: 24)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            DocumentsListView()
                        } label: {
                            RowChevron(icon: "doc.text", title: "Документы")
                                .glassCard(.thinMaterial, cornerRadius: 24)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            LinksListView()
                        } label: {
                            RowChevron(icon: "link", title: "Ссылки")
                                .glassCard(.thinMaterial, cornerRadius: 24)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(vm: vm, docStore: docStore)
                            .environmentObject(session)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $vm.showMyDataSheet) {
            MyDataSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showMyFilesSheet) {
            MyFilesSheet(docStore: docStore)
        }
    }
}

struct MyDataSheet: View {
    @ObservedObject var vm: ProfileVM
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(showGradient: false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ВФПС ID")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))

                                if vm.vfpsID.isEmpty {
                                    Text("Не добавлено")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.35))
                                } else {
                                    Text(vm.vfpsID)
                                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }

                            Spacer()
                        }

                        if !vm.vfpsID.isEmpty {
                            Button {
                                UIPasteboard.general.string = vm.vfpsID
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    copied = true
                                }
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    withAnimation { copied = false }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 13, weight: .semibold))

                                    Text(copied ? "Скопировано" : "Скопировать")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(copied ? .green : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    copied ? Color.green.opacity(0.15) : Color(white: 0.18),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .glassPane(cornerRadius: 20)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Мои данные")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct MyFilesSheet: View {
    @ObservedObject var docStore: DocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground(showGradient: false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(DocKind.allCases) { kind in
                            FileRowButton(
                                icon: kind.icon,
                                title: kind.title,
                                tint: kind.tint,
                                hasFile: docStore.hasFile(kind)
                            ) {
                                if let url = docStore.url(for: kind) {
                                    previewURL = url
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Мои файлы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .quickLookPreview($previewURL)
    }
}

struct FileRowButton: View {
    let icon: String
    let title: String
    var tint: Color = .white
    var hasFile: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(hasFile ? "Прикреплён" : "Не добавлен")
                        .font(.caption)
                        .foregroundStyle(hasFile ? .green.opacity(0.8) : .white.opacity(0.4))
                }

                Spacer()

                if hasFile {
                    Image(systemName: "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(14)
            .glassPane(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .opacity(hasFile ? 1 : 0.55)
    }
}

@MainActor
final class SettingsVM: ObservableObject {
    @Published var vfpsInput: String = ""
}

struct SettingsView: View {
    @ObservedObject var vm: ProfileVM
    @ObservedObject var docStore: DocumentStore
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var settingsToast: SettingsToastState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var s = SettingsVM()
    @State private var showSignOutAlert = false
    @State private var showDeleteVFPSAlert = false
    @State private var pickingDocKind: DocKind?
    @State private var deletingDocKind: DocKind?

    var body: some View {
        ZStack {
            GlassBackground(showGradient: false)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // VFPS ID field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ВФПС ID")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            TextField("Введите ВФПС ID", text: $s.vfpsInput)
                                .keyboardType(.numberPad)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color(white: 0.11))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color.white.opacity(0.04))
                                        )
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        // MARK: Documents section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Документы")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            ForEach(DocKind.allCases) { kind in
                                docRow(kind: kind)
                            }
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        // Delete VFPS ID button
                        Button {
                            showDeleteVFPSAlert = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Удалить ВФПС ID")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        // Sign out button
                        Button {
                            showSignOutAlert = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .semibold))

                                Text("Выйти")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }

                // Bottom Save button pinned
                Button {
                    vm.vfpsID = s.vfpsInput
                    settingsToast.show("Настройки сохранены")
                    dismiss()
                } label: {
                    Text("Сохранить")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent.opacity(0.55), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: AppTheme.accent.opacity(0.30), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            s.vfpsInput = vm.vfpsID
        }
        .sheet(item: $pickingDocKind) { kind in
            DocumentPickerView(docKind: kind, store: docStore)
        }
        .alert("Выйти из аккаунта?", isPresented: $showSignOutAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) {
                session.signOut()
            }
        } message: {
            Text("Вы уверены, что хотите выйти? Для повторного входа потребуется Apple ID.")
        }
        .alert("Удалить ВФПС ID?", isPresented: $showDeleteVFPSAlert) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                vm.vfpsID = ""
                s.vfpsInput = ""
                settingsToast.show("ВФПС ID удалён", icon: "trash.circle.fill")
                dismiss()
            }
        } message: {
            Text("Ваш ВФПС ID будет удалён. Вы сможете добавить его снова в настройках.")
        }
        .alert("Удалить \(deletingDocKind?.title ?? "")?", isPresented: Binding(
            get: { deletingDocKind != nil },
            set: { if !$0 { deletingDocKind = nil } }
        )) {
            Button("Отмена", role: .cancel) { deletingDocKind = nil }
            Button("Удалить", role: .destructive) {
                if let kind = deletingDocKind {
                    docStore.remove(kind)
                    settingsToast.show("\(kind.title) удалён", icon: "trash.circle.fill")
                }
                deletingDocKind = nil
            }
        } message: {
            Text("Файл будет удалён с устройства. Вы сможете прикрепить его снова.")
        }
    }

    // MARK: - Document row
    @ViewBuilder
    private func docRow(kind: DocKind) -> some View {
        let attached = docStore.hasFile(kind)

        HStack(spacing: 14) {
            Image(systemName: kind.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(kind.tint)
                .frame(width: 40, height: 40)
                .background(kind.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(kind.tint.opacity(0.20), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(attached ? "Прикреплён" : "Не добавлен")
                    .font(.caption)
                    .foregroundStyle(attached ? .green.opacity(0.8) : .white.opacity(0.4))
            }

            Spacer()

            if attached {
                Button {
                    deletingDocKind = kind
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(Color(white: 0.2), in: Circle())
                        .overlay(Circle().strokeBorder(Color.red.opacity(0.15), lineWidth: 0.6))
                }
                .buttonStyle(.plain)

                Button {
                    pickingDocKind = kind
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 34, height: 34)
                        .background(Color(white: 0.2), in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    pickingDocKind = kind
                } label: {
                    Text("Прикрепить")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent.opacity(0.40), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [AppTheme.accent.opacity(0.45), AppTheme.accent.opacity(0.12)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: AppTheme.accent.opacity(0.20), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassPane(cornerRadius: 20)
    }
}

// MARK: - QLPreview Wrapper

struct QLPreviewSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        return UINavigationController(rootViewController: ql)
    }

    func updateUIViewController(_ vc: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: - Documents List

struct BundleDocItem: Identifiable {
    let id = UUID()
    let sfSymbol: String
    let title: String
    let fileName: String
    let fileExtension: String
    let tint: Color
}

private let docsSection1: [BundleDocItem] = [
    BundleDocItem(sfSymbol: "hand.raised", title: "ППГ 2025–2028", fileName: "PPG-2025-2028-2", fileExtension: "pdf", tint: .pink),
    BundleDocItem(sfSymbol: "signature", title: "Согласие на обработку персональных данных", fileName: "Soglasie-na-obrabotku-personalnykh-dannykh", fileExtension: "docx", tint: .blue),
]

private let docsSectionObmer: [BundleDocItem] = [
    BundleDocItem(sfSymbol: "ruler", title: "Оптимист", fileName: "Nomera-i-Bukvy-Optimist", fileExtension: "PNG", tint: .orange),
    BundleDocItem(sfSymbol: "ruler", title: "ILCA 4", fileName: "Nomera-i-Bukvy-ILCA-4", fileExtension: "pdf", tint: .orange),
    BundleDocItem(sfSymbol: "ruler", title: "ILCA 6", fileName: "Nomera-i-Bukvy-ILCA-6", fileExtension: "pdf", tint: .orange),
    BundleDocItem(sfSymbol: "ruler", title: "ILCA 7", fileName: "Nomera-i-Bukvy-ILCA-7", fileExtension: "pdf", tint: .orange),
    BundleDocItem(sfSymbol: "ruler", title: "Ромб – ILCA 4, ILCA 6", fileName: "Romb-ILCA4-ILCA6", fileExtension: "pdf", tint: .orange),
]

struct DocumentsListView: View {
    @State private var selectedDocURL: URL?

    var body: some View {
        ZStack {
            GlassBackground(showGradient: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Top docs
                    VStack(spacing: 0) {
                        ForEach(Array(docsSection1.enumerated()), id: \.element.id) { index, item in
                            bundleDocButton(item: item)

                            if index < docsSection1.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .glassPane(cornerRadius: 20)

                    // Obmer section
                    Text("ОБМЕР")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.leading, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(docsSectionObmer.enumerated()), id: \.element.id) { index, item in
                            bundleDocButton(item: item)

                            if index < docsSectionObmer.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .glassPane(cornerRadius: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Документы")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: Binding(
            get: { selectedDocURL.map { IdentifiableURL(url: $0) } },
            set: { selectedDocURL = $0?.url }
        )) { item in
            QLPreviewSheet(url: item.url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func bundleDocButton(item: BundleDocItem) -> some View {
        Button {
            if let url = Bundle.main.url(forResource: item.fileName, withExtension: item.fileExtension) {
                selectedDocURL = url
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 44, height: 44)
                    .background(item.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Links List

struct LinkItem: Identifiable {
    let id = UUID()
    let sfSymbol: String
    let title: String
    let url: String
    let tint: Color
}

private let linksTopSection: [LinkItem] = [
    LinkItem(sfSymbol: "pills.fill", title: "Антидопинг 2026 (РУСАДА)", url: "https://course.rusada.ru/course/53", tint: .pink),
]

private let linksTelegramSection: [LinkItem] = [
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Тольятти", url: "https://t.me/togliattiregattas", tint: .blue),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Геленджике", url: "https://t.me/gelendzhik_regattas", tint: .blue),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Сочи", url: "https://t.me/RusSailChamp2022", tint: .blue),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Таганроге", url: "https://t.me/parusataganrog2023", tint: .blue),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в СПб", url: "https://t.me/pervenstvo", tint: .blue),
]

struct LinksListView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            GlassBackground(showGradient: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Top section
                    VStack(spacing: 0) {
                        ForEach(linksTopSection) { item in
                            linkButton(item: item)
                        }
                    }
                    .glassPane(cornerRadius: 20)

                    // Telegram section
                    Text("ТЕЛЕГРАМ КАНАЛЫ")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.leading, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(linksTelegramSection.enumerated()), id: \.element.id) { index, item in
                            linkButton(item: item)

                            if index < linksTelegramSection.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .glassPane(cornerRadius: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Ссылки")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func linkButton(item: LinkItem) -> some View {
        Button {
            if let url = URL(string: item.url) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 44, height: 44)
                    .background(item.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
