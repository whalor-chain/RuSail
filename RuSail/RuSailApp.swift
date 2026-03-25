import SwiftUI

@main
struct RuSailApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var themeManager = ThemeManager()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(favoritesStore)
                    .environmentObject(appDelegate.deepLink)
                    .environmentObject(themeManager)
                    .onOpenURL { url in
                        print("Opened from URL: \(url)")
                    }
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                setupNavigationBarAppearance()
                setupQuickActions()

                let soft   = UIImpactFeedbackGenerator(style: .soft)
                let light  = UIImpactFeedbackGenerator(style: .light)
                let medium = UIImpactFeedbackGenerator(style: .medium)
                let heavy  = UIImpactFeedbackGenerator(style: .heavy)
                let notify = UINotificationFeedbackGenerator()
                soft.prepare(); light.prepare(); medium.prepare(); heavy.prepare(); notify.prepare()

                // Rising haptic pattern: soft → light → medium → heavy → success
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)  { soft.impactOccurred(intensity: 0.4) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { light.impactOccurred(intensity: 0.6) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { medium.impactOccurred(intensity: 0.8) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { heavy.impactOccurred(intensity: 1.0) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) { notify.notificationOccurred(.success) }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSplash = false
                }
            }
        }
    }

    private func setupNavigationBarAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    private func setupQuickActions() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.rusail.favorites",
                localizedTitle: "Избранное",
                localizedSubtitle: "Твои отмеченные соревнования",
                icon: UIApplicationShortcutIcon(systemImageName: "heart.fill"),
                userInfo: nil
            )
        ]
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    let deepLink = DeepLinkState()

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            handleShortcut(shortcut)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func handleShortcut(_ shortcut: UIApplicationShortcutItem) {
        if shortcut.type == "com.rusail.favorites" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.deepLink.showFavorites = true
            }
        }
    }
}

// MARK: - SceneDelegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if shortcutItem.type == "com.rusail.favorites" {
            NotificationCenter.default.post(name: .openFavorites, object: nil)
        }
        completionHandler(true)
    }
}



// MARK: - Splash Screen

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color(hex: "#5272FF").opacity(0.35), radius: 30, x: 0, y: 10)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.7)) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                }
        }
    }
}






