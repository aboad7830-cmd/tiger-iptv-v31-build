//
//  NetworkPerformance100.swift
//  Tiger IPTV
//
//  مزايا الشبكة والأداء (36–40)
//

import SwiftUI
import Foundation
import Combine

// MARK: - 36) عدّاد السرعة المباشر (Mbps)

@MainActor
final class TigerBandwidthMeter: ObservableObject {
    @Published private(set) var mbps: Double = 0
    @Published private(set) var peakMbps: Double = 0
    @Published private(set) var samples: [Double] = []

    private var timer: AnyCancellable?
    private weak var player: MPVPlayer?

    func attach(to player: MPVPlayer) {
        self.player = player
        start()
    }

    func start() {
        timer?.cancel()
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard let player else { return }
        let bitsPerSecond = player.networkSpeedBps
        let value = bitsPerSecond / 1_000_000
        mbps = value
        peakMbps = max(peakMbps, value)
        samples.append(value)
        if samples.count > 60 { samples.removeFirst(samples.count - 60) }
    }

    var quality: String {
        switch mbps {
        case 0 ..< 0.01: return L("net.quality.idle")
        case 0.01 ..< 2: return L("net.quality.low")
        case 2 ..< 6: return L("net.quality.sd")
        case 6 ..< 15: return L("net.quality.hd")
        default: return L("net.quality.uhd")
        }
    }
}

struct TigerBandwidthSparkline: View {
    let samples: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(samples.max() ?? 1, 0.001)
            Path { path in
                guard samples.count > 1 else { return }
                let step = geo.size.width / CGFloat(samples.count - 1)
                for (index, value) in samples.enumerated() {
                    let x = CGFloat(index) * step
                    let y = geo.size.height * (1 - CGFloat(value / maxValue))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(TigerTheme.goldGradient, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 40)
    }
}

// MARK: - 37) وضع توفير البيانات

@MainActor
final class TigerDataSaver: ObservableObject {
    static let shared = TigerDataSaver()

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }
    @Published var capLiveQuality: Bool {
        didSet { defaults.set(capLiveQuality, forKey: Keys.capLive) }
    }
    @Published var blockPreviews: Bool {
        didSet { defaults.set(blockPreviews, forKey: Keys.blockPreviews) }
    }
    @Published var warnOnCellular: Bool {
        didSet { defaults.set(warnOnCellular, forKey: Keys.warnCellular) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled = "net.dataSaver"
        static let capLive = "net.dataSaver.capLive"
        static let blockPreviews = "net.dataSaver.blockPreviews"
        static let warnCellular = "net.dataSaver.warnCellular"
    }

    private init() {
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? false
        capLiveQuality = defaults.object(forKey: Keys.capLive) as? Bool ?? true
        blockPreviews = defaults.object(forKey: Keys.blockPreviews) as? Bool ?? true
        warnOnCellular = defaults.object(forKey: Keys.warnCellular) as? Bool ?? true
    }

    /// هل يجب تقليل جودة الصور في هذه اللحظة؟
    var shouldReduceImageQuality: Bool {
        isEnabled && (NetworkMonitor.shared.isExpensive || NetworkMonitor.shared.isConstrained)
    }

    /// أعلى جودة مسموحة للمحتوى المباشر.
    var allowedLiveQualityLabel: String {
        isEnabled && capLiveQuality ? L("net.quality.sd") : L("net.quality.auto")
    }

    var shouldShowCellularWarning: Bool {
        warnOnCellular && NetworkMonitor.shared.isExpensive
    }
}

// MARK: - 38) اختيار أفضل سيرفر تلقائيًا

struct TigerServerCandidate: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
}

struct TigerServerProbeResult: Identifiable, Hashable {
    let id: String
    let name: String
    let latencyMs: Int?
    let isReachable: Bool
}

@MainActor
final class TigerServerProbe: ObservableObject {
    @Published private(set) var isProbing = false
    @Published private(set) var results: [TigerServerProbeResult] = []
    @Published private(set) var best: TigerServerProbeResult?

    func probe(_ candidates: [TigerServerCandidate], timeout: TimeInterval = 4) async {
        isProbing = true
        results = []
        var collected: [TigerServerProbeResult] = []

        await withTaskGroup(of: TigerServerProbeResult.self) { group in
            for candidate in candidates {
                group.addTask {
                    var request = URLRequest(url: candidate.url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = timeout
                    let start = Date()
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        let latency = Int(Date().timeIntervalSince(start) * 1000)
                        return TigerServerProbeResult(
                            id: candidate.id,
                            name: candidate.name,
                            latencyMs: latency,
                            isReachable: (200 ..< 400).contains(code)
                        )
                    } catch {
                        return TigerServerProbeResult(
                            id: candidate.id,
                            name: candidate.name,
                            latencyMs: nil,
                            isReachable: false
                        )
                    }
                }
            }
            for await result in group { collected.append(result) }
        }

        results = collected.sorted { lhs, rhs in
            if lhs.isReachable != rhs.isReachable { return lhs.isReachable }
            return (lhs.latencyMs ?? .max) < (rhs.latencyMs ?? .max)
        }
        best = results.first(where: { $0.isReachable })
        isProbing = false
    }

    /// يبني مرشّحين من عنوان البوابة (http://host:port) بعدة منافذ شائعة.
    static func candidates(serverURL: String, ports: [Int] = [80, 8080, 2082, 25461]) -> [TigerServerCandidate] {
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else { return [] }
        let scheme = url.scheme ?? "http"
        return ports.compactMap { port in
            guard let candidate = URL(string: "\(scheme)://\(host):\(port)/") else { return nil }
            return TigerServerCandidate(id: "\(host):\(port)", name: "\(host):\(port)", url: candidate)
        }
    }
}

// MARK: - 39) حجم المخزن المؤقت

enum TigerBufferSize: String, CaseIterable, Identifiable {
    case tiny, small, balanced, large, maximum

    var id: String { rawValue }

    var seconds: Double {
        switch self {
        case .tiny: return 3
        case .small: return 8
        case .balanced: return 15
        case .large: return 30
        case .maximum: return 60
        }
    }

    var title: String {
        switch self {
        case .tiny: return L("buffer.tiny")
        case .small: return L("buffer.small")
        case .balanced: return L("buffer.balanced")
        case .large: return L("buffer.large")
        case .maximum: return L("buffer.maximum")
        }
    }

    var detail: String {
        switch self {
        case .tiny: return L("buffer.tiny.detail")
        case .small: return L("buffer.small.detail")
        case .balanced: return L("buffer.balanced.detail")
        case .large: return L("buffer.large.detail")
        case .maximum: return L("buffer.maximum.detail")
        }
    }
}

@MainActor
final class TigerBufferStore: ObservableObject {
    static let shared = TigerBufferStore()

    @Published var size: TigerBufferSize {
        didSet { defaults.set(size.rawValue, forKey: "net.bufferSize") }
    }

    /// يضبط تلقائيًا حسب سرعة الشبكة عند التفعيل.
    @Published var adaptive: Bool {
        didSet { defaults.set(adaptive, forKey: "net.bufferAdaptive") }
    }

    private let defaults = UserDefaults.standard

    private init() {
        let raw = defaults.string(forKey: "net.bufferSize") ?? TigerBufferSize.balanced.rawValue
        size = TigerBufferSize(rawValue: raw) ?? .balanced
        adaptive = defaults.object(forKey: "net.bufferAdaptive") as? Bool ?? true
    }

    /// الحجم الفعلي بعد التكيّف مع الشبكة.
    var effectiveSize: TigerBufferSize {
        guard adaptive else { return size }
        if NetworkMonitor.shared.isConstrained { return .small }
        switch NetworkMonitor.shared.lastLatencyMs ?? 0 {
        case 0 ..< 60: return .small
        case 60 ..< 150: return .balanced
        default: return .large
        }
    }
}

// MARK: - 40) إعادة المحاولة الذكية (HLS ↔ TS)

struct TigerStreamRetryPlan {
    let original: URL
    let candidates: [URL]

    static func plan(for url: URL) -> TigerStreamRetryPlan {
        var list: [URL] = []
        let absolute = url.absoluteString
        let lower = absolute.lowercased()

        if lower.hasSuffix(".m3u8") {
            list.append(URL(string: String(absolute.dropLast(5)) + ".ts") ?? url)
            list.append(URL(string: String(absolute.dropLast(5)) + ".mp4") ?? url)
        } else if lower.hasSuffix(".ts") {
            list.append(URL(string: String(absolute.dropLast(3)) + ".m3u8") ?? url)
        }

        if absolute.contains("/live/") {
            list.append(URL(string: absolute.replacingOccurrences(of: "/live/", with: "/hls/")) ?? url)
        }

        // إزالة التكرارات والاحتفاظ بالعنوان الأصلي أولًا
        var seen = Set<String>([absolute])
        let unique = list.filter { candidate in
            let key = candidate.absoluteString
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        return TigerStreamRetryPlan(original: url, candidates: unique)
    }
}

@MainActor
final class TigerSmartRetry: ObservableObject {
    @Published private(set) var attempt = 0
    @Published private(set) var currentURL: URL?

    private var plan: TigerStreamRetryPlan?
    private var task: Task<Void, Never>?

    func begin(url: URL, onFallback: @escaping (URL) -> Void) {
        plan = TigerStreamRetryPlan.plan(for: url)
        currentURL = url
        attempt = 0
        task?.cancel()
        task = Task { [weak self] in
            // محاولة واحدة كل 6 ثوانٍ حتى تنتهي البدائل
            for _ in 0 ..< 3 {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await MainActor.run { self.next(onFallback: onFallback) }
            }
        }
    }

    func succeed() {
        task?.cancel()
        task = nil
        attempt = 0
    }

    private func next(onFallback: @escaping (URL) -> Void) {
        guard let plan, attempt < plan.candidates.count else { return }
        let candidate = plan.candidates[attempt]
        attempt += 1
        currentURL = candidate
        onFallback(candidate)
    }
}

// MARK: - لوحة الشبكة

struct TigerNetworkPerformanceView: View {
    @ObservedObject private var saver = TigerDataSaver.shared
    @ObservedObject private var buffer = TigerBufferStore.shared
    @ObservedObject private var monitor = NetworkMonitor.shared
    @StateObject private var probe = TigerServerProbe()
    @State private var serverURL = ""

    var body: some View {
        List {
            Section {
                LabeledContent(L("net.status"), value: monitor.status.label)
                LabeledContent(L("net.latency"), value: monitor.lastLatencyMs.map { "\($0) ms" } ?? "—")
                LabeledContent(L("net.expensive"), value: monitor.isExpensive ? L("common.yes") : L("common.no"))
            } header: {
                Text(L("net.connection"))
            }

            Section {
                Toggle(L("net.dataSaver"), isOn: $saver.isEnabled)
                if saver.isEnabled {
                    Toggle(L("net.dataSaver.capLive"), isOn: $saver.capLiveQuality)
                    Toggle(L("net.dataSaver.blockPreviews"), isOn: $saver.blockPreviews)
                    Toggle(L("net.dataSaver.warnCellular"), isOn: $saver.warnOnCellular)
                }
            } header: {
                Text(L("net.dataSaver"))
            } footer: {
                Text(L("net.dataSaver.footer"))
            }

            Section {
                Toggle(L("buffer.adaptive"), isOn: $buffer.adaptive)
                Picker(L("buffer.size"), selection: $buffer.size) {
                    ForEach(TigerBufferSize.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .disabled(buffer.adaptive)
                LabeledContent(L("buffer.effective"), value: buffer.effectiveSize.title)
            } header: {
                Text(L("buffer.title"))
            } footer: {
                Text(L("buffer.footer"))
            }

            Section {
                TextField(L("net.server.url"), text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button {
                    Task {
                        await probe.probe(TigerServerProbe.candidates(serverURL: serverURL))
                    }
                } label: {
                    HStack {
                        Label(L("net.probe"), systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if probe.isProbing { ProgressView() }
                    }
                }
                .disabled(probe.isProbing || serverURL.isEmpty)

                ForEach(probe.results) { result in
                    HStack {
                        Image(systemName: result.isReachable ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(result.isReachable ? Color.green : Color.red)
                        Text(result.name)
                        Spacer()
                        Text(result.latencyMs.map { "\($0) ms" } ?? "—")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if probe.best?.id == result.id {
                            Text(L("net.best"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TigerTheme.gold.opacity(0.2), in: Capsule())
                        }
                    }
                }
            } header: {
                Text(L("net.servers"))
            } footer: {
                Text(L("net.servers.footer"))
            }
        }
        .navigationTitle(L("net.title"))
        .task { await monitor.measureLatency(to: URL(string: "https://www.apple.com")!) }
    }
}
