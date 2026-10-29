import Foundation
import SwiftUI
import Combine
import UIKit

/// روابط عميقة (Deep Links) + إجراءات سريعة من أيقونة التطبيق.
///
/// الصيغ المدعومة:
/// - `tigeriptv://add?url=<subscription>` — فتح شاشة إضافة اشتراك مع تعبئة مسبقة.
/// - `tigeriptv://search?q=<text>` — فتح البحث.
/// - `tigeriptv://open?tab=live|movies|series|settings`
/// - `tigeriptv://playlist?id=<uuid>` — فتح اشتراك محدد.
@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()

    enum Destination: Equatable {
        case addPlaylist(prefill: String?)
        case search(query: String)
        case openTab(String)
        case openPlaylist(UUID)
    }

    @Published var pending: Destination?

    private init() {}

    /// يعالج رابطاً وارداً. يعيد true إذا كان الرابط مدعوماً.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "tigeriptv" else { return false }
        let host = url.host?.lowercased() ?? ""
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first(where: { $0.name.lowercased() == name })?.value
        }

        switch host {
        case "add", "playlist-add":
            pending = .addPlaylist(prefill: value("url"))
        case "search":
            pending = .search(query: value("q") ?? "")
        case "open":
            pending = .openTab(value("tab") ?? "live")
        case "playlist":
            if let raw = value("id"), let id = UUID(uuidString: raw) {
                pending = .openPlaylist(id)
            } else {
                return false
            }
        default:
            // دعم الصيغة المختصرة: tigeriptv://<url-encoded subscription>
            if let raw = url.absoluteString.removingPercentEncoding,
               let range = raw.range(of: "://") {
                let rest = String(raw[range.upperBound...])
                if rest.contains("get.php") || rest.contains("player_api") || rest.hasPrefix("http") {
                    pending = .addPlaylist(prefill: rest)
                } else {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }

    func consume() -> Destination? {
        defer { pending = nil }
        return pending
    }
}

// MARK: - الإجراءات السريعة (Home Screen Quick Actions)

enum QuickAction: String {
    case search = "com.tigeriptv.quickaction.search"
    case favorites = "com.tigeriptv.quickaction.favorites"
    case downloads = "com.tigeriptv.quickaction.downloads"
    case addPlaylist = "com.tigeriptv.quickaction.add"

    var title: String {
        switch self {
        case .search: return L("quick.search")
        case .favorites: return L("quick.favorites")
        case .downloads: return L("quick.downloads")
        case .addPlaylist: return L("quick.add_playlist")
        }
    }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .favorites: return "heart.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .addPlaylist: return "plus.circle.fill"
        }
    }

    /// يُسجّل الإجراءات السريعة عند بدء التطبيق.
    static func register() {
        #if os(iOS)
        UIApplication.shared.shortcutItems = QuickAction.allCases.map { action in
            UIApplicationShortcutItem(
                type: action.rawValue,
                localizedTitle: action.title,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: action.icon),
                userInfo: nil
            )
        }
        #endif
    }

    static var allCases: [QuickAction] { [.search, .favorites, .downloads, .addPlaylist] }
}

