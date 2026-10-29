import SwiftUI

/// Root container: animated logo entrance → optional onboarding → content.
///
/// Responsibilities:
/// - Splash animation (once per cold launch, toggle via `app.splashEnabled`).
/// - First-run onboarding (`app.onboardingDone`).
/// - Theme application (`ThemeManager`).
/// - Parental lock gate (`ParentalControlManager`).
/// - Deep links (`tigeriptv://…`) and Home Screen quick actions.
struct AppRootView: View {
    @AppStorage("app.splashEnabled") private var splashEnabled: Bool = true
    @AppStorage("app.onboardingDone") private var onboardingDone: Bool = false

    @StateObject private var theme = ThemeManager.shared
    @StateObject private var parental = ParentalControlManager.shared

    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash: Bool = true
    @State private var contentVisible: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var needsUnlock: Bool = false

    var body: some View {
        ZStack {
            ContentView()
                .opacity(contentVisible ? 1 : 0)
                .scaleEffect(contentVisible ? 1 : 0.985)

            if showOnboarding {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showOnboarding = false
                        contentVisible = true
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.35)) {
                        contentVisible = true
                    }
                    showSplash = false
                    if !onboardingDone {
                        withAnimation(.easeOut(duration: 0.35)) {
                            showOnboarding = true
                        }
                    }
                }
                .transition(.opacity)
                .zIndex(3)
            }

            if needsUnlock {
                unlockGate
                    .transition(.opacity)
                    .zIndex(4)
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .dynamicTypeSize(theme.dynamicTypeSize)
        .onAppear(perform: bootstrap)
        .onOpenURL { handleDeepLink($0) }
        .onReceive(NotificationCenter.default.publisher(for: .tigerQuickAction)) { note in
            if let type = note.object as? String { handleQuickAction(type) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                parental.handleBecameActive()
                if parental.lockOnLaunch && parental.isPINSet && !parental.isUnlocked {
                    needsUnlock = true
                }
            case .background:
                if parental.lockOnLaunch && parental.isPINSet {
                    parental.lock()
                }
            default:
                break
            }
        }
    }

    // MARK: - Unlock gate

    private var unlockGate: some View {
        ZStack {
            TigerAuroraBackground()
            PINEntryView(
                title: L("parental.enter_pin"),
                subtitle: L("parental.unlock.subtitle"),
                length: 4,
                onComplete: { pin in
                    let ok = parental.verify(pin: pin)
                    if ok {
                        withAnimation(.easeOut(duration: 0.25)) { needsUnlock = false }
                    }
                    return ok
                },
                onCancel: { }
            )
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        if !splashEnabled {
            showSplash = false
            if !onboardingDone {
                showOnboarding = true
            } else {
                contentVisible = true
            }
        }

        if parental.lockOnLaunch && parental.isPINSet && !parental.isUnlocked {
            needsUnlock = true
        }

        QuickAction.register()

        // Load user profiles once per launch so the picker is instant.
        Task { await ProfileStore.shared.load() }

        // Consume a quick action that arrived before the view was on screen.
        if let pending = UserDefaults.standard.string(forKey: "quickaction.pending"),
           !pending.isEmpty {
            UserDefaults.standard.removeObject(forKey: "quickaction.pending")
            handleQuickAction(pending)
        }
    }

    // MARK: - Quick actions

    private func handleQuickAction(_ type: String) {
        switch type {
        case QuickAction.addPlaylist.rawValue, "com.tigeriptv.app.quick.addPlaylist":
            NotificationCenter.default.post(name: .tigerOpenAddPlaylist, object: nil)
        case QuickAction.search.rawValue, "com.tigeriptv.app.quick.search":
            NotificationCenter.default.post(name: .tigerOpenSearch, object: nil)
        case QuickAction.favorites.rawValue, "com.tigeriptv.app.quick.favorites":
            UserDefaults.standard.set("favorites", forKey: "deeplink.pendingTab")
            NotificationCenter.default.post(name: .tigerOpenTab, object: nil)
        case QuickAction.downloads.rawValue, "com.tigeriptv.app.quick.downloads":
            UserDefaults.standard.set("downloads", forKey: "deeplink.pendingTab")
            NotificationCenter.default.post(name: .tigerOpenTab, object: nil)
        default:
            break
        }
    }

    // MARK: - Deep links

    private func handleDeepLink(_ url: URL) {
        guard DeepLinkManager.shared.handle(url) else { return }
        guard let destination = DeepLinkManager.shared.consume() else { return }

        switch destination {
        case .addPlaylist(let prefill):
            if let prefill, !prefill.isEmpty {
                UserDefaults.standard.set(prefill, forKey: "deeplink.pendingSubscription")
            }
            NotificationCenter.default.post(name: .tigerOpenAddPlaylist, object: nil)
        case .search(let query):
            UserDefaults.standard.set(query, forKey: "deeplink.pendingSearch")
            NotificationCenter.default.post(name: .tigerOpenSearch, object: nil)
        case .openTab(let tab):
            UserDefaults.standard.set(tab, forKey: "deeplink.pendingTab")
            NotificationCenter.default.post(name: .tigerOpenTab, object: nil)
        case .openPlaylist(let id):
            UserDefaults.standard.set(id.uuidString, forKey: "lastPlaylistId")
            NotificationCenter.default.post(name: .tigerOpenPlaylist, object: nil)
        }
    }
}

extension Notification.Name {
    static let tigerOpenAddPlaylist = Notification.Name("tiger.open.addPlaylist")
    static let tigerOpenSearch = Notification.Name("tiger.open.search")
    static let tigerOpenTab = Notification.Name("tiger.open.tab")
    static let tigerOpenPlaylist = Notification.Name("tiger.open.playlist")
    static let tigerQuickAction = Notification.Name("tiger.quick.action")
}

#Preview {
    AppRootView()
        .environment(\.appDatabase, .empty())
}
