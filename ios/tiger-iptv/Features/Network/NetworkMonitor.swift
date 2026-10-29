import Foundation
import Network
import Combine
import SwiftUI

/// مراقبة حالة الشبكة (Wi-Fi / خلوي / بدون اتصال) + جودة الاتصال التقديرية.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    enum Status: Equatable {
        case unknown
        case satisfiedWiFi
        case satisfiedCellular
        case satisfiedOther
        case unsatisfied
        case requiresConnection

        var isOnline: Bool {
            switch self {
            case .satisfiedWiFi, .satisfiedCellular, .satisfiedOther: return true
            default: return false
            }
        }

        var label: String {
            switch self {
            case .satisfiedWiFi: return L("network.wifi")
            case .satisfiedCellular: return L("network.cellular")
            case .satisfiedOther: return L("network.other")
            case .unsatisfied, .requiresConnection: return L("network.offline")
            case .unknown: return L("network.unknown")
            }
        }

        var icon: String {
            switch self {
            case .satisfiedWiFi: return "wifi"
            case .satisfiedCellular: return "antenna.radiowaves.left.and.right"
            case .satisfiedOther: return "network"
            case .unsatisfied, .requiresConnection: return "wifi.slash"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    /// تقدير سرعة الاتصال (مللي ثانية) لآخر طلب.
    @Published private(set) var lastLatencyMs: Int?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tigeriptv.network.monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func apply(_ path: NWPath) {
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        guard path.status == .satisfied else {
            status = path.status == .requiresConnection ? .requiresConnection : .unsatisfied
            return
        }

        if path.usesInterfaceType(.wifi) {
            status = .satisfiedWiFi
        } else if path.usesInterfaceType(.cellular) {
            status = .satisfiedCellular
        } else {
            status = .satisfiedOther
        }
    }

    /// يقيس زمن الاستجابة لخادم معيّن ويحدّث `lastLatencyMs`.
    @discardableResult
    func measureLatency(to url: URL) async -> Int? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let start = Date()
        do {
            _ = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            lastLatencyMs = ms
            return ms
        } catch {
            lastLatencyMs = nil
            return nil
        }
    }

    /// تصنيف جودة الاتصال بحسب زمن الاستجابة.
    func qualityLabel(latencyMs: Int?) -> String {
        guard let latencyMs else { return L("network.quality.unknown") }
        switch latencyMs {
        case ..<120: return L("network.quality.excellent")
        case ..<300: return L("network.quality.good")
        case ..<700: return L("network.quality.fair")
        default: return L("network.quality.poor")
        }
    }
}

/// شارة صغيرة تعرض حالة الشبكة — تُستخدم في شاشة التشخيص.
struct NetworkStatusBadge: View {
    @StateObject private var monitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: monitor.status.icon)
                .font(.caption)
            Text(monitor.status.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(monitor.status.isOnline ? TigerTheme.brandLight.opacity(0.18) : Color.red.opacity(0.18))
        )
        .foregroundStyle(monitor.status.isOnline ? TigerTheme.brandLight : Color.red)
        .accessibilityElement(children: .combine)
    }
}
