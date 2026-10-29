import SwiftUI

#if os(iOS)
/// مُفوَّض التطبيق — يعمل على iOS/iPadOS فقط (توجيه الشاشة، جلسات التحميل الخلفية، الإجراءات السريعة).
class AppDelegate: NSObject, UIApplicationDelegate {
    /// الافتراضي: كل الاتجاهات. `LiveChannelBrowserScreen` يفرض `.landscape` عند فتحه.
    static var orientationLock: UIInterfaceOrientationMask = .allButUpsideDown

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    /// يستدعيه النظام لأحداث جلسة التحميل الخلفية. نمرّر المُكمِّل إلى DownloadManager.
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == DownloadManager.sessionIdentifier else {
            completionHandler()
            return
        }
        Task { @MainActor in
            DownloadManager.shared.backgroundCompletionHandler = completionHandler
        }
    }

    /// إجراءات الشاشة الرئيسية السريعة (3D Touch / الضغط المطوّل على الأيقونة).
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        UserDefaults.standard.set(shortcutItem.type, forKey: "quickaction.pending")
        NotificationCenter.default.post(name: .tigerQuickAction, object: shortcutItem.type)
        completionHandler(true)
    }
}
#endif

@main
struct TigerIPTVApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        IPTVRemoteImagePipeline.installAsShared()
        _ = AppDatabase.shared
        MockFixture.seedIfNeeded()
        UserDefaults.standard.register(defaults: [
            "player.pipEnabled": true,
            "player.continuePlayingInBackground": true,
            "player.speedUpOnLongPress": true,
            "app.splashEnabled": true,
            "app.theme": "system",
            "app.accent": "tiger",
            "epg.enabled": true,
            "player.sleepTimerDefaultMinutes": 0
        ])
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.appDatabase, .shared)
                .tint(.accentColor)
                .tigerAdaptiveMetrics()
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 820)
        #endif
    }
}
