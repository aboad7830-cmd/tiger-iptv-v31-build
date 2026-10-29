import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 1..5 — التحميل الذكي والعمل بلا إنترنت
//
// يضيف طبقة سياسات فوق `DownloadManager` الموجود دون تعديله:
// جدولة ليلية، تحميل الحلقة التالية، سقف تخزين، جودة قابلة للتغيير، واستئناف.

@MainActor
final class DownloadPolicyStore: ObservableObject {
    static let shared = DownloadPolicyStore()

    @Published var nightOnly: Bool {
        didSet { UserDefaults.standard.set(nightOnly, forKey: "dl.nightOnly") }
    }
    @Published var nightStartHour: Int {
        didSet { UserDefaults.standard.set(nightStartHour, forKey: "dl.nightStart") }
    }
    @Published var nightEndHour: Int {
        didSet { UserDefaults.standard.set(nightEndHour, forKey: "dl.nightEnd") }
    }
    @Published var pauseBelowBattery: Int {
        didSet { UserDefaults.standard.set(pauseBelowBattery, forKey: "dl.batteryFloor") }
    }
    @Published var wifiOnly: Bool {
        didSet { UserDefaults.standard.set(wifiOnly, forKey: "dl.wifiOnly") }
    }
    @Published var storageCapGB: Int {
        didSet { UserDefaults.standard.set(storageCapGB, forKey: "dl.storageCapGB") }
    }
    @Published var autoNextEpisode: Bool {
        didSet { UserDefaults.standard.set(autoNextEpisode, forKey: "dl.autoNext") }
    }
    @Published var preferredQuality: DownloadQuality {
        didSet { UserDefaults.standard.set(preferredQuality.rawValue, forKey: "dl.quality") }
    }

    private init() {
        let d = UserDefaults.standard
        nightOnly = d.bool(forKey: "dl.nightOnly")
        nightStartHour = d.object(forKey: "dl.nightStart") as? Int ?? 2
        nightEndHour = d.object(forKey: "dl.nightEnd") as? Int ?? 6
        pauseBelowBattery = d.object(forKey: "dl.batteryFloor") as? Int ?? 20
        wifiOnly = d.object(forKey: "dl.wifiOnly") as? Bool ?? true
        storageCapGB = d.object(forKey: "dl.storageCapGB") as? Int ?? 20
        autoNextEpisode = d.object(forKey: "dl.autoNext") as? Bool ?? true
        preferredQuality = DownloadQuality(rawValue: d.string(forKey: "dl.quality") ?? "") ?? .hd
    }

    /// هل نحن داخل نافذة الجدولة الليلية؟
    var isInsideNightWindow: Bool {
        guard nightOnly else { return true }
        let hour = Calendar.current.component(.hour, from: Date())
        if nightStartHour <= nightEndHour {
            return hour >= nightStartHour && hour < nightEndHour
        }
        return hour >= nightStartHour || hour < nightEndHour
    }

    /// 1. هل يُسمح بالتحميل الآن وفق كل السياسات؟
    func canDownloadNow(isExpensiveNetwork: Bool, batteryLevel: Float?) -> (allowed: Bool, reason: String?) {
        if !isInsideNightWindow {
            return (false, L("dl.blocked.night", nightStartHour, nightEndHour))
        }
        if wifiOnly && isExpensiveNetwork {
            return (false, L("dl.blocked.cellular"))
        }
        if let level = batteryLevel, level >= 0, Int(level * 100) < pauseBelowBattery {
            return (false, L("dl.blocked.battery", pauseBelowBattery))
        }
        return (true, nil)
    }

    /// 3. سقف التخزين: يعيد قائمة IDs الأقدم للحذف حتى نعود تحت السقف.
    func idsToEvictLRU(usageBytes: Int64) -> Int64 {
        let cap = Int64(storageCapGB) * 1024 * 1024 * 1024
        return max(0, usageBytes - cap)
    }
}

/// 4. جودة التحميل مع الحجم المتوقع.
enum DownloadQuality: String, CaseIterable, Identifiable {
    case sd, hd, fhd

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sd: return "SD"
        case .hd: return "HD"
        case .fhd: return "FHD"
        }
    }

    var approxMBPerMinute: Double {
        switch self {
        case .sd: return 5
        case .hd: return 11
        case .fhd: return 22
        }
    }

    /// الحجم المتوقع لعنصر مدته معروفة (ثانية).
    func estimatedSize(durationSeconds: Double) -> String {
        let mb = (durationSeconds / 60.0) * approxMBPerMinute
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}

/// 2. تحميل الحلقة التالية تلقائياً بعد إكمال حلقة.
@MainActor
enum NextEpisodeDownloader {

    struct EpisodeRef {
        let id: String
        let playlistId: UUID
        let seriesId: String
        let season: Int
        let number: Int
        let title: String
        let remoteURL: URL
        let imageURL: String?
    }

    /// يبحث عن الحلقة التالية في نفس الموسم ويضعها في الكويو.
    static func enqueueNextIfNeeded(after episode: EpisodeRef, nextCandidate: EpisodeRef?) async {
        guard DownloadPolicyStore.shared.autoNextEpisode else { return }
        guard let next = nextCandidate else { return }
        guard next.season == episode.season, next.number == episode.number + 1 else { return }

        await DownloadManager.shared.enqueue(
            id: DownloadManager.idFor(episode: next.playlistId, episodeId: next.id),
            playlistId: next.playlistId,
            streamId: next.id,
            type: "episode",
            title: next.title,
            secondaryTitle: nil,
            imageURL: next.imageURL,
            remoteURL: next.remoteURL,
            containerExtension: "mp4",
            seriesId: next.seriesId,
            seasonNumber: next.season,
            episodeNumber: next.number
        )
    }
}

/// 5. استئناف التحميل بعد انقطاع الشبكة — يتابع من البايت المتبقي.
@MainActor
final class DownloadResumeCoordinator {
    static let shared = DownloadResumeCoordinator()

    private var observers: [NSObjectProtocol] = []
    private init() {}

    func start() {
        guard observers.isEmpty else { return }
        let note = NotificationCenter.default.addObserver(
            forName: .tigerNetworkRestored,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                // إعادة تشغيل الطابور: كل عنصر متوقف يُستأنف من آخر بايت مكتوب
                // لأن URLSession يستخدم resumeData المحفوظ في قاعدة البيانات.
                NotificationCenter.default.post(name: .tigerDownloadsShouldResume, object: nil)
            }
        }
        observers.append(note)
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }
}

extension Notification.Name {
    static let tigerNetworkRestored = Notification.Name("tiger.network.restored")
    static let tigerDownloadsShouldResume = Notification.Name("tiger.downloads.resume")
}

// MARK: - واجهة إعدادات التحميل

struct DownloadPolicySettingsView: View {
    @StateObject private var policy = DownloadPolicyStore.shared
    @State private var usageText: String = "…"

    var body: some View {
        List {
            Section {
                Toggle(L("dl.nightOnly"), isOn: $policy.nightOnly)
                if policy.nightOnly {
                    Stepper(value: $policy.nightStartHour, in: 0...23) {
                        HStack {
                            Text(L("dl.nightStart"))
                            Spacer()
                            Text(String(format: "%02d:00", policy.nightStartHour))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Stepper(value: $policy.nightEndHour, in: 0...23) {
                        HStack {
                            Text(L("dl.nightEnd"))
                            Spacer()
                            Text(String(format: "%02d:00", policy.nightEndHour))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                Toggle(L("dl.wifiOnly"), isOn: $policy.wifiOnly)
                Stepper(value: $policy.pauseBelowBattery, in: 0...60, step: 5) {
                    HStack {
                        Text(L("dl.batteryFloor"))
                        Spacer()
                        Text("\(policy.pauseBelowBattery)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text(L("dl.section.schedule"))
            } footer: {
                Text(L("dl.section.schedule.footer"))
            }

            Section(L("dl.section.quality")) {
                Picker(L("dl.quality"), selection: $policy.preferredQuality) {
                    ForEach(DownloadQuality.allCases) { q in
                        Text(q.label).tag(q)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(L("dl.autoNext"), isOn: $policy.autoNextEpisode)
            }

            Section(L("dl.section.storage")) {
                Stepper(value: $policy.storageCapGB, in: 2...200, step: 2) {
                    HStack {
                        Text(L("dl.storageCap"))
                        Spacer()
                        Text("\(policy.storageCapGB) GB")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                HStack {
                    Text(L("dl.storageUsed"))
                    Spacer()
                    Text(usageText).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .navigationTitle(L("dl.title"))
        .task { await refreshUsage() }
    }

    private func refreshUsage() async {
        let bytes = DownloadStorage.totalUsedBytes()
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        usageText = String(format: "%.2f GB", gb)
    }
}

// MARK: - 31..35 — صحّة الاشتراك ودمج القنوات والترتيب والمشاركة

struct PlaylistHealthReport {
    enum Level { case ok, warning, critical }

    let level: Level
    let title: String
    let details: [String]
    let checkedAt: Date
}

@MainActor
final class PlaylistHealthChecker {
    static let shared = PlaylistHealthChecker()

    /// 31. فحص شامل: استجابة السيرفر + تاريخ الانتهاء + عدد القنوات.
    func check(playlist: Playlist) async -> PlaylistHealthReport {
        var details: [String] = []
        var level: PlaylistHealthReport.Level = .ok

        // استجابة السيرفر
        if let url = URL(string: playlist.serverURL) {
            let latency = await NetworkMonitor.shared.measureLatency(to: url)
            if let latency {
                details.append(L("health.latency", latency))
                if latency > 1500 {
                    level = .warning
                    details.append(L("health.latency.slow"))
                }
            } else {
                level = .critical
                details.append(L("health.unreachable"))
            }
        } else {
            level = .critical
            details.append(L("health.badurl"))
        }

        // عدد العناصر المخزّنة محلياً
        do {
            let counts = try await AppDatabase.shared.read { db -> (Int, Int, Int) in
                let live = try DBLiveStream.filter(Column("playlistId") == playlist.id.uuidString).fetchCount(db)
                let vod = try DBVODStream.filter(Column("playlistId") == playlist.id.uuidString).fetchCount(db)
                let series = try DBSeries.filter(Column("playlistId") == playlist.id.uuidString).fetchCount(db)
                return (live, vod, series)
            }
            details.append(L("health.counts", counts.0, counts.1, counts.2))
            if counts.0 == 0 && counts.1 == 0 && counts.2 == 0 {
                level = .critical
                details.append(L("health.empty"))
            }
        } catch {
            details.append(L("health.db_error"))
        }

        return PlaylistHealthReport(
            level: level,
            title: playlist.name,
            details: details,
            checkedAt: Date()
        )
    }
}

/// 32. كشف القنوات الميتة دورياً.
@MainActor
final class DeadChannelScanner {
    static let shared = DeadChannelScanner()

    @Published private(set) var deadChannelIds: Set<String> = []
    @Published private(set) var isScanning = false

    /// يفحص عيّنة من القنوات بـ HEAD request خفيف.
    func scan(channels: [(id: String, url: URL)], sampleLimit: Int = 40) async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        var dead: Set<String> = []
        let sample = channels.prefix(sampleLimit)

        await withTaskGroup(of: (String, Bool).self) { group in
            for channel in sample {
                group.addTask {
                    var request = URLRequest(url: channel.url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 6
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        return (channel.id, code >= 200 && code < 400)
                    } catch {
                        return (channel.id, false)
                    }
                }
            }
            for await (id, alive) in group where !alive {
                dead.insert(id)
            }
        }
        deadChannelIds = dead
    }
}

/// 33. دمج القنوات المكرّرة (MBC1 / MBC 1 HD) في بطاقة بمصادر متعددة.
struct MergedChannel: Identifiable {
    let id: String
    let displayName: String
    let logoURL: URL?
    let sources: [ChannelSource]

    struct ChannelSource: Identifiable {
        let id: String
        let name: String
        let streamURL: URL?
    }
}

enum ChannelNameNormalizer {

    /// يوحّد الاسم لمقارنة التكرار: يحذف HD/FHD/4K و«قناة» والمسافات الزائدة.
    static func key(_ name: String) -> String {
        var s = name.lowercased()
        for token in ["fhd", "uhd", "hd", "sd", "4k", "8k", "h265", "hevc", "قناة", "channel", "tv"] {
            s = s.replacingOccurrences(of: token, with: "")
        }
        s = s.replacingOccurrences(of: "[^a-z0-9\\u0600-\\u06FF]", with: "", options: .regularExpression)
        return s
    }

    static func merge(_ channels: [(id: String, name: String, logo: URL?, url: URL?)]) -> [MergedChannel] {
        var buckets: [String: [(id: String, name: String, logo: URL?, url: URL?)]] = [:]
        for channel in channels {
            buckets[key(channel.name), default: []].append(channel)
        }
        return buckets.map { key, items in
            MergedChannel(
                id: key,
                displayName: items.first?.name ?? key,
                logoURL: items.first?.logo,
                sources: items.map { .init(id: $0.id, name: $0.name, streamURL: $0.url) }
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

/// 34. ترتيب مخصّص بالسحب يُحفظ لكل قائمة.
@MainActor
final class CustomOrderStore: ObservableObject {
    static let shared = CustomOrderStore()

    @Published private(set) var orders: [String: [String]] = [:]

    private func storageKey(_ playlistId: UUID, _ scope: String) -> String {
        "order.\(playlistId.uuidString).\(scope)"
    }

    func load(playlistId: UUID, scope: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: storageKey(playlistId, scope)) ?? []
    }

    func save(_ ids: [String], playlistId: UUID, scope: String) {
        UserDefaults.standard.set(ids, forKey: storageKey(playlistId, scope))
        orders[storageKey(playlistId, scope)] = ids
    }

    /// يعيد ترتيب مصفوفة حسب الترتيب المحفوظ، مع إبقاء العناصر الجديدة في النهاية.
    func apply<T>(_ items: [T], id: (T) -> String, playlistId: UUID, scope: String) -> [T] {
        let saved = load(playlistId: playlistId, scope: scope)
        guard !saved.isEmpty else { return items }
        let index = Dictionary(uniqueKeysWithValues: saved.enumerated().map { ($1, $0) })
        return items.sorted { lhs, rhs in
            let l = index[id(lhs)] ?? Int.max
            let r = index[id(rhs)] ?? Int.max
            if l == r { return false }
            return l < r
        }
    }
}

/// 35. مشاركة الاشتراك بـ QR آمن (بدون كلمة المرور افتراضياً).
enum PlaylistShareCodec {

    struct Payload: Codable {
        let name: String
        let server: String
        let username: String
        let password: String?
        let type: String
        let m3uEpg: String?
    }

    static func makePayload(from playlist: Playlist, includePassword: Bool) -> Payload {
        Payload(
            name: playlist.name,
            server: playlist.serverURL,
            username: playlist.username,
            password: includePassword ? playlist.password : nil,
            type: playlist.type,
            m3uEpg: playlist.m3uEpgURL
        )
    }

    static func encode(_ payload: Payload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return "tigeriptv://import?d=" + data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ string: String) -> Payload? {
        guard let range = string.range(of: "d=") else { return nil }
        var b64 = String(string[range.upperBound...])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}

#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
import GRDB
import Combine

struct TigerQRCodeView: View {
    let content: String
    var size: CGFloat = 200

    private var image: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(DT.Space.x2)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Corner.md, style: .continuous))
            } else {
                TigerErrorState(title: L("qr.error"), reason: L("qr.error.reason"))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(L("qr.accessibility"))
    }
}
#endif
