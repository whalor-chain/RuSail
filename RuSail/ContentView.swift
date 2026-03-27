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
    static let cardBackground = Color(hex: "#1C1C1E")
    static let logoAssetName = "AppLogo"
}

// MARK: - Theme Mode

enum AppThemeMode: String, CaseIterable, Identifiable {
    case dark = "dark"
    case rusail = "rusail"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Тёмная"
        case .rusail: return "RuSail"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("app.themeMode") var mode: AppThemeMode = .dark
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

    /// True while the login→home logo transition is playing.
    @Published var isLoginTransitioning = false

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

    /// Logo flying from center to toolbar position
    @State private var logoLanded = false
    @State private var logoFaded = false

    var body: some View {
        ZStack {
            if session.isSignedIn {
                RootTabView()
                    .environmentObject(session)
                    .environmentObject(deepLink)
                    .opacity(session.isLoginTransitioning ? 0 : 1)
                    .animation(.easeOut(duration: 0.4), value: session.isLoginTransitioning)
            } else {
                LoginView()
                    .environmentObject(session)
            }

            // Floating logo overlay during transition
            if session.isLoginTransitioning {
                loginTransitionOverlay
            }
        }
        .onChange(of: session.isLoginTransitioning) { transitioning in
            guard transitioning else { return }
            logoLanded = false
            logoFaded = false

            // Phase 2: logo flies to toolbar position
            withAnimation(.easeInOut(duration: 0.55).delay(0.1)) {
                logoLanded = true
            }

            // Fade out logo earlier so it dissolves before reaching toolbar
            withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
                logoFaded = true
            }

            // Phase 3: reveal main UI, end transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.3)) {
                    session.isLoginTransitioning = false
                }
            }
        }
    }

    private var loginTransitionOverlay: some View {
        ZStack {
            // Keep the background visible while logo flies
            GlassBackground()
                .opacity(logoLanded ? 0 : 1)

            GeometryReader { geo in
                let startSize: CGFloat = 120
                let endSize: CGFloat = 36
                let startCorner: CGFloat = 30
                let endCorner: CGFloat = 8

                let size = logoLanded ? endSize : startSize
                let corner = logoLanded ? endCorner : startCorner

                // Login logo sits above screen center (bottom button block pushes it up)
                let bottomBlockHeight: CGFloat = 160
                let startX = geo.size.width / 2
                let startY = (geo.size.height - bottomBlockHeight) / 2
                let endX = geo.size.width / 2
                let endY = geo.safeAreaInsets.top + 44 / 2

                Image(AppTheme.logoAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .position(
                        x: logoLanded ? endX : startX,
                        y: logoLanded ? endY : startY
                    )
                    .opacity(logoFaded ? 0 : 1)
            }
        }
        .ignoresSafeArea()
    }
}

enum RuSailTab: Hashable {
    case home
    case calendar
    case profile
    case search
}

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var deepLink: DeepLinkState
    @StateObject private var toast = FavoriteToastState()
    @StateObject private var settingsToast = SettingsToastState()
    @StateObject private var profileVM = ProfileVM()
    @StateObject private var docStore = DocumentStore()
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
                    ProfileView(vm: profileVM, docStore: docStore)
                }

                Tab("Поиск", systemImage: "magnifyingglass", value: RuSailTab.search, role: .search) {
                    NavigationStack {
                        BrowseView()
                    }
                }
            }
            .tint(AppTheme.accent)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
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
    @State private var logoAppeared = false
    @State private var contentAppeared = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    /// Phase 1 of exit: fade out everything except logo
    @State private var exitingUI = false
    /// Pending credentials waiting for animation to finish
    @State private var pendingCredentials: (userID: String, name: String?, email: String?)?

    private let roleWords = ["тренеров", "спортсменов", "команд", "экипажей", "судей"]
    @State private var currentRoleIndex = 0

    var body: some View {
        ZStack {
            GlassBackground()

            VStack(spacing: 0) {
                Spacer()

                // Logo + Title
                VStack(spacing: 20) {
                    Image(AppTheme.logoAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: AppTheme.accent.opacity(exitingUI ? 0 : 0.3), radius: 30, x: 0, y: 15)
                        .scaleEffect(logoAppeared ? 1 : 0.8)
                        .opacity(logoAppeared ? 1 : 0)

                    VStack(spacing: 8) {
                        Text("RuSail")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        HStack(spacing: 0) {
                            Text("Парусное приложение для ")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))

                            Text(roleWords[currentRoleIndex])
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                                .id("role_\(currentRoleIndex)")
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                        }
                        .animation(.easeInOut(duration: 0.4), value: currentRoleIndex)
                    }
                    .opacity(exitingUI ? 0 : (logoAppeared ? 1 : 0))
                    .offset(y: exitingUI ? -10 : (logoAppeared ? 0 : 10))
                }

                Spacer()

                // Sign In button + legal
                VStack(spacing: 16) {
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

                            // Store credentials, play exit animation, then sign in
                            pendingCredentials = (
                                userID: userID,
                                name: name.isEmpty ? nil : name,
                                email: email
                            )
                            beginExitAnimation()

                        case .failure(let error):
                            errorText = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.08), radius: 12, x: 0, y: 4)

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Legal links
                    HStack(spacing: 4) {
                        Text("Продолжая, вы принимаете")
                            .foregroundStyle(.white.opacity(0.35))

                        Button { showTerms = true } label: {
                            Text("Условия")
                                .foregroundStyle(.white.opacity(0.55))
                                .underline(color: .white.opacity(0.25))
                        }
                        .buttonStyle(.plain)

                        Text("и")
                            .foregroundStyle(.white.opacity(0.35))

                        Button { showPrivacy = true } label: {
                            Text("Политику")
                                .foregroundStyle(.white.opacity(0.55))
                                .underline(color: .white.opacity(0.25))
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .opacity(exitingUI ? 0 : (contentAppeared ? 1 : 0))
                .offset(y: exitingUI ? 30 : (contentAppeared ? 0 : 20))
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTerms) {
            TermsOfUseView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                logoAppeared = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) {
                contentAppeared = true
            }
        }
        .onReceive(
            Timer.publish(every: 2, on: .main, in: .common).autoconnect()
        ) { _ in
            withAnimation {
                currentRoleIndex = (currentRoleIndex + 1) % roleWords.count
            }
        }
    }

    private func beginExitAnimation() {
        // Phase 1: fade out all UI except logo
        withAnimation(.easeInOut(duration: 0.35)) {
            exitingUI = true
        }

        // Phase 2: trigger transition in ContentView and sign in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let creds = pendingCredentials else { return }
            session.isLoginTransitioning = true
            session.signIn(
                userID: creds.userID,
                displayName: creds.name,
                email: creds.email
            )
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
                        .foregroundStyle(settingsToast.icon.contains("trash") ? .red : .green)
                        .symbolEffect(.bounce, value: settingsToast.isShowing)

                    Text(settingsToast.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.6
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
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
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.6
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
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
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            if themeManager.mode == .rusail {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.03, blue: 0.07),
                            Color(red: 0.06, green: 0.07, blue: 0.13),
                            Color(red: 0.04, green: 0.04, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.accent.opacity(0.40), AppTheme.accent.opacity(0.12), .clear],
                                center: .center,
                                startRadius: w * 0.05,
                                endRadius: w * 0.55
                            )
                        )
                        .frame(width: w * 1.1, height: w * 1.1)
                        .offset(x: w * 0.35, y: -h * 0.25)
                        .blur(radius: 60)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.secondary.opacity(0.25), Color.purple.opacity(0.10), .clear],
                                center: .center,
                                startRadius: w * 0.03,
                                endRadius: w * 0.50
                            )
                        )
                        .frame(width: w * 0.95, height: w * 0.95)
                        .offset(x: -w * 0.30, y: h * 0.35)
                        .blur(radius: 50)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.cyan.opacity(0.12), .clear],
                                center: .center,
                                startRadius: w * 0.03,
                                endRadius: w * 0.40
                            )
                        )
                        .frame(width: w * 0.75, height: w * 0.75)
                        .offset(x: w * 0.10, y: h * 0.10)
                        .blur(radius: 70)
                }
            } else {
                Color.black
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
                    .fill(AppTheme.cardBackground)
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
                    .fill(AppTheme.cardBackground)
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
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .contentShape(Rectangle())
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
                    if willAdd {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                } label: {
                    Image(systemName: favoritesStore.contains(event) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(favoritesStore.contains(event) ? .red : .white)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.cardBackground, in: Circle())
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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.cardBackground, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.6
                                        )
                                )
                        }
                    }
                }
                .frame(height: 38)
            }

        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
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
    .init(title: "Оптимист", aliases: ["Оптимист"], color: Color(hue: 0.63, saturation: 0.65, brightness: 0.95)),
    .init(title: "ILCA", aliases: ["Лазер 4.7", "Лазер-радиал", "Лазер-стандарт"], color: Color(hue: 0.58, saturation: 0.60, brightness: 0.90)),
    .init(title: "420", aliases: ["420"], color: Color(hue: 0.53, saturation: 0.55, brightness: 0.85)),
    .init(title: "470", aliases: ["470"], color: Color(hue: 0.48, saturation: 0.55, brightness: 0.80)),
    .init(title: "29er", aliases: ["29-й"], color: Color(hue: 0.43, saturation: 0.50, brightness: 0.80)),
    .init(title: "49er", aliases: ["49er", "49-й"], color: Color(hue: 0.38, saturation: 0.50, brightness: 0.78)),
    .init(title: "Финн", aliases: ["Финн"], color: Color(hue: 0.33, saturation: 0.50, brightness: 0.75)),
    .init(title: "MX700", aliases: ["MX700", "МХ700"], color: Color(hue: 0.28, saturation: 0.50, brightness: 0.75)),
    .init(title: "J/70", aliases: ["J/70"], color: Color(hue: 0.22, saturation: 0.50, brightness: 0.78)),
    .init(title: "SB20", aliases: ["SB20"], color: Color(hue: 0.15, saturation: 0.55, brightness: 0.80)),
    .init(title: "ЭМ-КА", aliases: ["ЭМ-КА", "эМ-Ка"], color: Color(hue: 0.10, saturation: 0.55, brightness: 0.82)),
    .init(title: "ORC", aliases: ["Крейсерская яхта ORC", "ORC"], color: Color(hue: 0.05, saturation: 0.58, brightness: 0.85)),
    .init(title: "Техно/iQF", aliases: ["Парусная доска Техно", "Парусная доска IQF", "Парусная доска iQF", "iQF"], color: Color(hue: 0.0, saturation: 0.60, brightness: 0.88)),
    .init(title: "Накра 17", aliases: ["Накра 17", "Nacra 17"], color: Color(hue: 0.95, saturation: 0.55, brightness: 0.85)),
    .init(title: "Кадет", aliases: ["Кадет"], color: Color(hue: 0.90, saturation: 0.50, brightness: 0.82)),
    .init(title: "Луч", aliases: ["Луч", "Луч-мини"], color: Color(hue: 0.85, saturation: 0.50, brightness: 0.80)),
    .init(title: "Ракета", aliases: ["Ракета"], color: Color(hue: 0.80, saturation: 0.50, brightness: 0.78)),
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
            SmallStatCard(title: "Сейчас идут", value: "\(currentEvents.count)", tint: .green, icon: "livephoto")
            SmallStatCard(title: "Избранное", value: "\(favoriteEvents.count)", tint: .red, icon: "heart.fill", pulseEffect: true)
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
                        .background(AppTheme.cardBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if events.isEmpty {
                EmptyLiveStateCard()
            } else {
                VStack(spacing: 8) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            LiveEventCard(event: event)
                                .tag(index)
                                .padding(.horizontal, 2)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 235)
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
                        .background(AppTheme.cardBackground, in: Capsule())
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
                VStack(spacing: 8) {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            FavoriteEventCard(event: event, favoritesStore: favoritesStore)
                                .tag(index)
                                .padding(.horizontal, 2)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 230)

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
                GlassBackground()

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
                GlassBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(events) { event in
                            LiveEventCard(event: event)
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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.cardBackground, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.6
                                        )
                                )
                        }
                    }
                }
                .frame(height: 38)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
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
                    .font(.system(size: 20, weight: .semibold))
                    .symbolEffect(.pulse.byLayer, options: .repeat(.periodic(delay: 2.0)))

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
    var icon: String?
    var pulseEffect: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let icon {
                    if pulseEffect {
                        Image(systemName: icon)
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(tint.opacity(0.15))
                            .symbolEffect(.breathe.pulse.byLayer, options: .repeat(.continuous))
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(tint.opacity(0.15))
                            .symbolEffect(.breathe)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 44, height: 44)
                }

                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.08), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [tint.opacity(0.25), tint.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        }
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

    var isUpcomingOrOngoing: Bool {
        guard let endDateValue else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: endDateValue)
        return end >= today
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
    @State private var showFavoritesOnly = false
    @State private var showUpcomingOnly = false

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

    private var displayedEvents: [RaceEvent] {
        var result = filteredEvents
        if showFavoritesOnly {
            result = result.filter { favoritesStore.contains($0) }
        }
        if showUpcomingOnly {
            result = result.filter { $0.isUpcomingOrOngoing }
        }
        return result
    }

    private var groupedEvents: [(key: Int, value: [RaceEvent])] {
        Dictionary(grouping: displayedEvents, by: { $0.month })
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        filters
                        togglesCard
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

                        if displayedEvents.isEmpty {
                            Text(showFavoritesOnly || showUpcomingOnly ? "Нет регат по выбранным фильтрам" : "По выбранному фильтру ничего не найдено")
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
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isSelected
                                ? AppTheme.accent
                                : Color.white.opacity(0.10),
                                in: Capsule()
                            )
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
                Text("\(displayedEvents.count)")
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

    private var togglesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: showFavoritesOnly ? "heart" : "heart.text.square")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.red)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))

                Text("Избранные регаты")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: $showFavoritesOnly.animation(.easeInOut(duration: 0.25)))
                    .labelsHidden()
                    .tint(.red)
            }
            .padding(14)

            Divider()
                .overlay(.white.opacity(0.1))

            HStack(spacing: 8) {
                Image(systemName: showUpcomingOnly ? "mappin" : "mappin.slash")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.green)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer), options: .nonRepeating))

                Text(showUpcomingOnly ? "Вот где!" : "Где я?")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: $showUpcomingOnly.animation(.easeInOut(duration: 0.25)))
                    .labelsHidden()
                    .tint(.green)
            }
            .padding(14)
        }
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
                    if willAdd {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? .red : .white)
                        .scaleEffect(isFavorite ? 1.0 : 0.92)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.6
                                        )
                                )
                        )
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
                            .background(AppTheme.cardBackground, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
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
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
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
    @State private var searchText = ""
    @State private var selectedDocURL: URL?

    private let activeCategories: [BrowseCategory] = [
        BrowseCategory(icon: "link", title: "Ссылки", tint: .red),
        BrowseCategory(icon: "text.document", title: "Документы", tint: .orange),
    ]

    private let devCategories: [BrowseCategory] = [
        BrowseCategory(icon: "newspaper.fill", title: "Новости", tint: .yellow),
        BrowseCategory(icon: "person.3.fill", title: "Отбор в Сборную", tint: .green),
        BrowseCategory(icon: "trophy.fill", title: "Результаты", tint: .cyan),
        BrowseCategory(icon: "cart.fill", title: "Магазин", tint: .purple),
        BrowseCategory(icon: "calendar.badge.clock", title: "Мероприятия", tint: .indigo),
        BrowseCategory(icon: "graduationcap.fill", title: "Студенческая Лига", tint: .mint),
    ]

    private var allLinks: [LinkItem] {
        linksTopSection + linksTelegramSection
    }

    private var allDocs: [BundleDocItem] {
        docsSection1 + docsSectionObmer
    }

    private var filteredActive: [BrowseCategory] {
        if searchText.isEmpty { return activeCategories }
        return activeCategories.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredDev: [BrowseCategory] {
        if searchText.isEmpty { return devCategories }
        return devCategories.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredLinks: [LinkItem] {
        guard !searchText.isEmpty else { return [] }
        return allLinks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredDocs: [BundleDocItem] {
        guard !searchText.isEmpty else { return [] }
        return allDocs.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            GlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(filteredActive) { cat in
                        NavigationLink {
                            destinationView(for: cat.title)
                        } label: {
                            RowChevron(icon: cat.icon, title: cat.title, tint: cat.tint)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .glassPane(cornerRadius: 20)
                        }
                        .buttonStyle(.plain)
                    }

                    // Search results from Links
                    if !filteredLinks.isEmpty {
                        HStack {
                            Text("Ссылки")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 2)

                        ForEach(filteredLinks) { item in
                            Button {
                                if let url = URL(string: item.url) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                RowChevron(icon: item.sfSymbol, title: item.title, tint: .red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .glassPane(cornerRadius: 20)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Search results from Documents
                    if !filteredDocs.isEmpty {
                        HStack {
                            Text("Документы")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 2)

                        ForEach(filteredDocs) { item in
                            Button {
                                if let url = Bundle.main.url(forResource: item.fileName, withExtension: item.fileExtension) {
                                    selectedDocURL = url
                                }
                            } label: {
                                RowChevron(icon: item.sfSymbol, title: item.title, tint: .orange)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .glassPane(cornerRadius: 20)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !filteredDev.isEmpty {
                        HStack {
                            Text("В разработке")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 2)

                        ForEach(filteredDev) { cat in
                            HStack(spacing: 14) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(cat.tint.opacity(0.45))
                                    .frame(width: 40, height: 40)
                                    .background(cat.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(cat.title)
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.40))

                                Spacer()

                                Text("Скоро")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.30))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.06), in: Capsule())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .glassPane(cornerRadius: 20)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск")
        .quickLookPreview($selectedDocURL)
    }

    @ViewBuilder
    private func destinationView(for title: String) -> some View {
        switch title {
        case "Ссылки":
            LinksListView()
        case "Документы":
            DocumentsListView()
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
            GlassBackground()

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
                                : Color.white.opacity(0.10),
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
                .fill(AppTheme.cardBackground)
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
                    .fill(AppTheme.cardBackground)
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
            GlassBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(AppTheme.cardBackground)
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
    case certificate    = "certificate"
    case helmsman       = "helmsman"
    case license        = "license"
    case insurance      = "insurance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .certificate: return "Сертификат РУСАДА"
        case .helmsman:    return "Права рулевого"
        case .license:     return "Права ГИМС"
        case .insurance:   return "Страховка"
        }
    }

    var icon: String {
        switch self {
        case .certificate: return "doc.richtext"
        case .helmsman:    return "person.text.rectangle"
        case .license:     return "person.text.rectangle"
        case .insurance:   return "cross.case"
        }
    }

    var tint: Color {
        switch self {
        case .certificate: return AppTheme.accent
        case .helmsman:    return AppTheme.accent
        case .license:     return AppTheme.accent
        case .insurance:   return AppTheme.accent
        }
    }

    fileprivate var storageKey: String { "doc_\(rawValue)_bookmark" }
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var urls: [DocKind: URL] = [:]

    private let fm = FileManager.default

    init() { loadAll() }

    // MARK: — Local folder (always available)

    private var localFolder: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("RuSailDocs", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: — iCloud folder (may be nil)

    private var iCloudFolder: URL? {
        guard let container = fm.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let folder = container.appendingPathComponent("Documents/RuSailDocs", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: — Save

    func save(_ kind: DocKind, from sourceURL: URL) {
        let ext = sourceURL.pathExtension.isEmpty ? "pdf" : sourceURL.pathExtension
        let fileName = "\(kind.rawValue).\(ext)"

        // Access security‑scoped resource
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        // 1. Сохраняем локально (всегда работает)
        let localDest = localFolder.appendingPathComponent(fileName)
        try? fm.removeItem(at: localDest)
        try? fm.copyItem(at: sourceURL, to: localDest)

        // 2. Копируем в iCloud (если доступен)
        if let cloud = iCloudFolder {
            let cloudDest = cloud.appendingPathComponent(fileName)
            try? fm.removeItem(at: cloudDest)
            try? fm.copyItem(at: localDest, to: cloudDest)
        }

        // 3. Запоминаем расширение для загрузки
        UserDefaults.standard.set(ext, forKey: kind.storageKey)
        #if !WIDGET_EXTENSION
        CloudSyncManager.shared.saveDocExtension(ext, for: kind)
        #endif

        urls[kind] = localDest
    }

    // MARK: — Delete

    func remove(_ kind: DocKind) {
        if let url = urls[kind] {
            try? fm.removeItem(at: url)
        }
        // Удаляем и из iCloud
        let ext = UserDefaults.standard.string(forKey: kind.storageKey) ?? "pdf"
        if let cloud = iCloudFolder {
            let cloudFile = cloud.appendingPathComponent("\(kind.rawValue).\(ext)")
            try? fm.removeItem(at: cloudFile)
        }

        UserDefaults.standard.removeObject(forKey: kind.storageKey)
        #if !WIDGET_EXTENSION
        CloudSyncManager.shared.removeDocExtension(for: kind)
        #endif

        urls.removeValue(forKey: kind)
    }

    // MARK: — Load

    private func loadAll() {
        let local = localFolder
        let cloud = iCloudFolder

        for kind in DocKind.allCases {
            // Получаем расширение: iCloud KV → UserDefaults → pdf
            var ext = UserDefaults.standard.string(forKey: kind.storageKey)
            #if !WIDGET_EXTENSION
            if ext == nil || ext?.isEmpty == true {
                ext = CloudSyncManager.shared.loadDocExtension(for: kind)
            }
            #endif
            let fileExt = ext ?? "pdf"
            let fileName = "\(kind.rawValue).\(fileExt)"

            let localFile = local.appendingPathComponent(fileName)

            // Если файл есть локально — используем
            if fm.fileExists(atPath: localFile.path) {
                urls[kind] = localFile
                continue
            }

            // Если нет локально — пробуем скачать из iCloud
            if let cloud, fm.fileExists(atPath: cloud.appendingPathComponent(fileName).path) {
                let cloudFile = cloud.appendingPathComponent(fileName)
                // Запускаем скачивание если файл ещё в облаке
                try? fm.startDownloadingUbiquitousItem(at: cloudFile)
                try? fm.copyItem(at: cloudFile, to: localFile)
                if fm.fileExists(atPath: localFile.path) {
                    urls[kind] = localFile
                    UserDefaults.standard.set(fileExt, forKey: kind.storageKey)
                }
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
    var onPicked: (() -> Void)?

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
            parent.onPicked?()
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

@MainActor
final class ProfileVM: ObservableObject {
    @Published var vfpsID: String {
        didSet { persistProfile() }
    }
    @Published var username: String {
        didSet { persistProfile() }
    }
    @Published var ruSailID: String {
        didSet { persistProfile() }
    }
    @Published var joinedAt: String {
        didSet { persistProfile() }
    }

    @Published var showMyDataSheet = false
    @Published var showMyFilesSheet = false
    @Published var showAboutSheet = false
    @Published var showPrivacyPolicy = false
    @Published var showTermsOfUse = false

    private let defaults = UserDefaults.standard
    private let sync = CloudSyncManager.shared

    init() {
        // Загрузка из локального хранилища, затем из iCloud (приоритет iCloud)
        self.vfpsID = Self.loadValue(key: CloudSyncManager.Key.vfpsID, fallback: "")
        self.username = Self.loadValue(key: CloudSyncManager.Key.username, fallback: "")
        self.ruSailID = Self.loadValue(key: CloudSyncManager.Key.ruSailID, fallback: "")
        self.joinedAt = Self.loadValue(key: CloudSyncManager.Key.joinedAt, fallback: "")

        // Подписка на обновления из iCloud (с другого устройства)
        sync.onProfileChanged = { [weak self] key, value in
            guard let self else { return }
            switch key {
            case CloudSyncManager.Key.vfpsID:   self.vfpsID = value
            case CloudSyncManager.Key.username:  self.username = value
            case CloudSyncManager.Key.ruSailID:  self.ruSailID = value
            case CloudSyncManager.Key.joinedAt:  self.joinedAt = value
            default: break
            }
        }
    }

    private func persistProfile() {
        defaults.set(vfpsID, forKey: CloudSyncManager.Key.vfpsID)
        defaults.set(username, forKey: CloudSyncManager.Key.username)
        defaults.set(ruSailID, forKey: CloudSyncManager.Key.ruSailID)
        defaults.set(joinedAt, forKey: CloudSyncManager.Key.joinedAt)
        sync.saveProfile(vfpsID: vfpsID, username: username, ruSailID: ruSailID, joinedAt: joinedAt)
    }

    private static func loadValue(key: String, fallback: String) -> String {
        // Приоритет: iCloud → локальный UserDefaults → fallback
        if let cloud = CloudSyncManager.shared.loadProfileValue(for: key), !cloud.isEmpty {
            return cloud
        }
        return UserDefaults.standard.string(forKey: key) ?? fallback
    }
}

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @ObservedObject var vm: ProfileVM
    @ObservedObject var docStore: DocumentStore

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView {
                    VStack(spacing: 10) {
                        Button {
                            vm.showMyDataSheet = true
                        } label: {
                            RowChevron(icon: "person.crop.square.on.square.angled", title: "Мои данные", tint: AppTheme.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .glassPane(cornerRadius: 20)
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.showMyFilesSheet = true
                        } label: {
                            RowChevron(icon: "folder", title: "Мои файлы", tint: AppTheme.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .glassPane(cornerRadius: 20)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { vm.showAboutSheet.toggle() } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $vm.showAboutSheet, arrowEdge: .top) {
                        AboutPopover(vm: vm)
                            .presentationCompactAdaptation(.popover)
                    }
                }

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
        .sheet(isPresented: $vm.showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $vm.showTermsOfUse) {
            TermsOfUseView()
        }
    }
}

struct MyDataSheet: View {
    @ObservedObject var vm: ProfileVM
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Мои данные")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

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
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
                            copied ? Color.green.opacity(0.15) : Color.black.opacity(0.3),
                            in: Capsule()
                        )
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Все данные защищены")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            Spacer(minLength: 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .presentationCornerRadius(56)
    }
}

struct MyFilesSheet: View {
    @ObservedObject var docStore: DocumentStore
    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Header — like native Sign in with Apple
            HStack {
                Text("Мои файлы")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

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

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Все файлы защищены")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            Spacer(minLength: 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .presentationCornerRadius(56)
        .quickLookPreview($previewURL)
    }
}

struct AboutPopover: View {
    @ObservedObject var vm: ProfileVM
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "RuSail v\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appVersion)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            aboutButton("Политика конфиденциальности") {
                vm.showAboutSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    vm.showPrivacyPolicy = true
                }
            }
            aboutButton("Условия пользования") {
                vm.showAboutSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    vm.showTermsOfUse = true
                }
            }

            Divider()

            Button {
                vm.showAboutSheet = false
                if let url = URL(string: "https://t.me/whalor") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Связаться с разработчиком")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(HighlightButtonStyle())
        }
        .frame(width: 260)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func aboutButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.page.badge.magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(HighlightButtonStyle())
    }
}

private struct HighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.gray.opacity(0.25) : Color.clear)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Последнее обновление: 24 марта 2026 г.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        policySection("1. Общие положения",
                            "Приложение RuSail (далее — «Приложение») предоставляет информацию о парусных регатах в России. Настоящая Политика конфиденциальности описывает, какие данные мы собираем, как их используем и защищаем.")

                        policySection("2. Какие данные мы собираем",
                            "Приложение собирает минимальный объём данных:\n\n• Идентификатор ВФПС — вводится вами добровольно для отображения персональной статистики.\n• Избранные регаты — список соревнований, добавленных вами в избранное, хранится локально на устройстве.\n• Настройки приложения — выбранная тема оформления и другие параметры хранятся локально.")

                        policySection("3. Чего мы НЕ собираем",
                            "• Мы не собираем персональные данные (имя, email, телефон).\n• Мы не отслеживаем геолокацию.\n• Мы не используем аналитику и трекеры.\n• Мы не передаём никакие данные третьим лицам.")

                        policySection("4. Хранение данных",
                            "Все данные хранятся исключительно на вашем устройстве с использованием стандартных механизмов iOS (UserDefaults). При удалении приложения все данные удаляются автоматически.")

                        policySection("5. Сетевые запросы",
                            "Приложение может обращаться к открытым источникам данных для получения актуального расписания регат. Эти запросы не содержат персональных данных пользователя.")

                        policySection("6. Безопасность",
                            "Мы заботимся о безопасности ваших данных. Поскольку данные хранятся только локально на устройстве, они защищены средствами безопасности iOS, включая шифрование устройства.")

                        policySection("7. Права пользователя",
                            "Вы можете в любой момент:\n\n• Удалить свой идентификатор ВФПС в настройках приложения.\n• Очистить список избранного.\n• Удалить приложение, что приведёт к полному удалению всех данных.")

                        policySection("8. Изменения политики",
                            "Мы оставляем за собой право обновлять настоящую Политику. При внесении существенных изменений мы уведомим вас через обновление приложения.")

                        policySection("9. Контакты",
                            "Если у вас есть вопросы относительно данной Политики конфиденциальности, свяжитесь с нами через раздел обратной связи в приложении.")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Политика конфиденциальности")
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

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Terms of Use

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Последнее обновление: 24 марта 2026 г.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        policySection("1. Принятие условий",
                            "Используя приложение RuSail (далее — «Приложение»), вы соглашаетесь с настоящими Условиями пользования. Если вы не согласны с каким-либо пунктом, пожалуйста, прекратите использование Приложения.")

                        policySection("2. Описание сервиса",
                            "RuSail — информационное приложение, предоставляющее расписание и сведения о парусных соревнованиях в Российской Федерации. Приложение носит исключительно информационный характер.")

                        policySection("3. Использование приложения",
                            "Вы обязуетесь:\n\n• Использовать Приложение только в законных целях.\n• Не пытаться обойти технические ограничения Приложения.\n• Не копировать, модифицировать или распространять содержимое Приложения без разрешения.")

                        policySection("4. Информационный контент",
                            "Расписание регат, даты и места проведения соревнований предоставляются на основе открытых данных. Мы стремимся поддерживать актуальность информации, однако не гарантируем её полноту и точность. Рекомендуем проверять информацию в официальных источниках организаторов соревнований.")

                        policySection("5. Документы",
                            "Документы, доступные в Приложении (ППГ, формы обмера и др.), предоставляются для удобства пользователей. Юридически обязывающими являются оригиналы документов, опубликованные на официальных сайтах соответствующих организаций.")

                        policySection("6. Интеллектуальная собственность",
                            "Дизайн, код и структура Приложения являются интеллектуальной собственностью разработчика. Логотипы и названия спортивных организаций принадлежат их правообладателям.")

                        policySection("7. Ограничение ответственности",
                            "Приложение предоставляется «как есть». Разработчик не несёт ответственности за:\n\n• Неточности в расписании соревнований.\n• Перебои в работе Приложения.\n• Убытки, связанные с использованием информации из Приложения.")

                        policySection("8. Изменения условий",
                            "Мы оставляем за собой право изменять настоящие Условия. Продолжая использование Приложения после внесения изменений, вы принимаете обновлённые Условия.")

                        policySection("9. Применимое право",
                            "Настоящие Условия регулируются и толкуются в соответствии с законодательством Российской Федерации.")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Условия пользования")
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

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
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
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: "eye.slash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(14)
            .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var s = SettingsVM()
    @State private var showSignOutAlert = false
    @State private var showDeleteVFPSAlert = false
    @State private var pickingDocKind: DocKind?
    @State private var deletingDocKind: DocKind?

    var body: some View {
        ZStack {
            GlassBackground()
                .ignoresSafeArea(.keyboard)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // MARK: Theme picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Тема оформления")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            HStack(spacing: 12) {
                                ForEach(AppThemeMode.allCases) { mode in
                                    let isSelected = themeManager.mode == mode
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            themeManager.mode = mode
                                        }
                                    } label: {
                                        VStack(spacing: 10) {
                                            ZStack {
                                                if mode == .rusail {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [
                                                                    Color(red: 0.03, green: 0.03, blue: 0.12),
                                                                    Color(red: 0.06, green: 0.07, blue: 0.18)
                                                                ],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                } else {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color.black)
                                                }
                                            }
                                            .frame(height: 70)
                                                .overlay(
                                                    Group {
                                                        if mode == .rusail {
                                                            Circle()
                                                                .fill(AppTheme.accent.opacity(0.4))
                                                                .frame(width: 40, height: 40)
                                                                .blur(radius: 12)
                                                                .offset(x: 15, y: -10)
                                                        }
                                                    }
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .strokeBorder(
                                                            isSelected ? AppTheme.accent : Color.white.opacity(0.10),
                                                            lineWidth: isSelected ? 2 : 1
                                                        )
                                                )

                                            Text(mode.title)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(isSelected ? AppTheme.accent : .white.opacity(0.7))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        // VFPS ID field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ВФПС ID")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))

                            TextField("Введите ВФПС ID", text: $s.vfpsInput)
                                .keyboardType(.numberPad)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button {
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        } label: {
                                            Image(systemName: "keyboard.chevron.compact.down")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(14)
                                .background {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppTheme.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
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
                            .fill(Color.white.opacity(0.10))
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
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)
                            .padding(.vertical, 4)

                        // Delete VFPS ID button
                        Button {
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                gen.notificationOccurred(.success)
                            }
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
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                gen.notificationOccurred(.success)
                            }
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

            }
            .background(.clear)
        }
        .overlay(alignment: .bottom) {
            if s.vfpsInput != vm.vfpsID {
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
                        .background {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.accent],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.8
                                        )
                                )
                                .shadow(color: AppTheme.accent.opacity(0.4), radius: 16, x: 0, y: 8)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: s.vfpsInput != vm.vfpsID)
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            s.vfpsInput = vm.vfpsID
        }
        .sheet(item: $pickingDocKind) { kind in
            DocumentPickerView(docKind: kind, store: docStore) {
                settingsToast.show("«\(kind.title)» добавлено", icon: "checkmark.circle.fill")
            }
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
                    settingsToast.show("«\(kind.title)» удалено", icon: "trash.circle.fill")
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
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        gen.notificationOccurred(.success)
                    }
                    deletingDocKind = kind
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 34, height: 34)
                        .background(AppTheme.cardBackground, in: Circle())
                        .overlay(Circle().strokeBorder(Color.red.opacity(0.25), lineWidth: 1.5))
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
    BundleDocItem(sfSymbol: "hand.raised", title: "ППГ 2025–2028", fileName: "PPG-2025-2028-2", fileExtension: "pdf", tint: .orange),
    BundleDocItem(sfSymbol: "signature", title: "Согласие на обработку персональных данных", fileName: "Soglasie-na-obrabotku-personalnykh-dannykh", fileExtension: "docx", tint: .orange),
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
            GlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Top docs
                    VStack(spacing: 0) {
                        ForEach(Array(docsSection1.enumerated()), id: \.element.id) { index, item in
                            bundleDocButton(item: item)

                            if index < docsSection1.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.10))
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .glassPane(cornerRadius: 20)

                    VStack(spacing: 0) {
                        ForEach(Array(docsSectionObmer.enumerated()), id: \.element.id) { index, item in
                            bundleDocButton(item: item)

                            if index < docsSectionObmer.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.10))
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
        .navigationBarTitleDisplayMode(.inline)
        .quickLookPreview($selectedDocURL)
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
    LinkItem(sfSymbol: "pills.fill", title: "Антидопинг 2026 (РУСАДА)", url: "https://course.rusada.ru/course/53", tint: .red),
]

private let linksTelegramSection: [LinkItem] = [
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Тольятти", url: "https://t.me/togliattiregattas", tint: .red),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Геленджике", url: "https://t.me/gelendzhik_regattas", tint: .red),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Сочи", url: "https://t.me/RusSailChamp2022", tint: .red),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в Таганроге", url: "https://t.me/parusataganrog2023", tint: .red),
    LinkItem(sfSymbol: "paperplane.fill", title: "Регаты в СПб", url: "https://t.me/pervenstvo", tint: .red),
]

struct LinksListView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            GlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Top section
                    VStack(spacing: 0) {
                        ForEach(linksTopSection) { item in
                            linkButton(item: item)
                        }
                    }
                    .glassPane(cornerRadius: 20)

                    VStack(spacing: 0) {
                        ForEach(Array(linksTelegramSection.enumerated()), id: \.element.id) { index, item in
                            linkButton(item: item)

                            if index < linksTelegramSection.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.10))
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
        .navigationBarTitleDisplayMode(.inline)
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
