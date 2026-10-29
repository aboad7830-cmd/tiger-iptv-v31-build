//
//  TigerPlusLive.swift
//  Tiger IPTV
//
//  حزمة v3.0 — البث المباشر: فحص صحة القنوات، قائمة الصحة، وترتيب القنوات.
//

import SwiftUI
import GRDB
import GRDBQuery

// MARK: - حالة فحص قناة

enum TigerChannelStatus: Equatable {
    case unknown, checking, alive(latencyMs: Int), dead(reason: String)

    var label: String {
        switch self {
        case .unknown: return "غير مفحوص"
        case .checking: return "جارٍ الفحص…"
        case .alive(let ms): return "تعمل (\(ms) مللي)"
        case .dead(let r): return "لا تعمل — \(r)"
        }
    }

    var color: Color {
        switch self {
        case .unknown: return .secondary
        case .checking: return TigerTheme.gold
        case .alive: return TigerTheme.brandLight
        case .dead: return .red
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .checking: return "arrow.triangle.2.circlepath"
        case .alive: return "checkmark.circle.fill"
        case .dead: return "xmark.octagon.fill"
        }
    }
}

/// فاحص قناة خفيف عبر طلب HEAD مع مهلة قصيرة.
enum TigerChannelProbe {
    static func check(url: URL?, timeout: TimeInterval = 6) async -> TigerChannelStatus {
        guard let url else { return .dead(reason: "رابط غير صالح") }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                return .alive(latencyMs: ms)
            }
            return .dead(reason: "رمز \(((response as? HTTPURLResponse)?.statusCode) ?? 0)")
        } catch {
            return .dead(reason: "انتهت المهلة أو فشل الاتصال")
        }
    }
}

// MARK: - بطاقة صحة القناة

struct TigerChannelHealthCard: View {
    let playlist: Playlist
    let channel: DBLiveStream

    @State private var status: TigerChannelStatus = .unknown

    private var url: URL? {
        PlaybackURLBuilder(playlist: playlist).liveURL(streamId: channel.streamId)
    }

    var body: some View {
        TigerSettingsCard(title: "صحة القناة", subtitle: nil, icon: "waveform.path.ecg", tint: status.color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: status.icon).foregroundStyle(status.color)
                    Text(status.label).font(.subheadline.weight(.medium)).foregroundStyle(status.color)
                    Spacer(minLength: 0)
                }
                Button {
                    Task { await runCheck() }
                } label: {
                    Label("فحص الآن", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isChecking)
            }
        }
        .task { await runCheck() }
    }

    private var isChecking: Bool {
        if case .checking = status { return true }
        return false
    }

    private func runCheck() async {
        status = .checking
        status = await TigerChannelProbe.check(url: url)
    }
}

// MARK: - قائمة صحة القنوات

struct TigerChannelHealthListView: View {
    let playlist: Playlist

    @Query<LiveStreamsRequest> private var channels: [LiveStreamWithCategory]
    @State private var statuses: [String: TigerChannelStatus] = [:]
    @State private var isScanning = false
    @State private var progress: Double = 0

    init(playlist: Playlist) {
        self.playlist = playlist
        _channels = Query(LiveStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    private var deadCount: Int {
        statuses.values.filter { if case .dead = $0 { return true }; return false }.count
    }

    var body: some View {
        TigerPlusScreen(
            title: "صحة القنوات",
            subtitle: "افحص عيّنة من القنوات للتأكد من أنها تعمل، واكتشف القنوات الميتة.",
            icon: "waveform.path.ecg"
        ) {
            TigerSettingsCard(title: "الفحص", subtitle: nil, icon: "antenna.radiowaves.left.and.right", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 10) {
                    TigerInfoRow(title: "إجمالي القنوات", value: "\(channels.count)", icon: "tv", tint: TigerTheme.orange)
                    TigerInfoRow(title: "قنوات ميتة", value: "\(deadCount)", icon: "xmark.octagon", tint: .red)
                    if isScanning {
                        ProgressView(value: progress).tint(TigerTheme.orange)
                        Text("جارٍ الفحص… \(Int(progress * 100))%").font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await scan() }
                    } label: {
                        Label(isScanning ? "جارٍ الفحص…" : "فحص عيّنة (40 قناة)", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TigerTheme.orange)
                    .disabled(isScanning || channels.isEmpty)
                }
            }

            if !statuses.isEmpty {
                TigerSettingsCard(title: "النتائج", subtitle: nil, icon: "list.bullet", tint: TigerTheme.brandLight) {
                    VStack(spacing: 0) {
                        let checked = channels.filter { statuses[$0.stream.id] != nil }
                        ForEach(Array(checked.enumerated()), id: \.element.id) { index, ch in
                            HStack(spacing: 10) {
                                CachedImage(url: ch.stream.streamIcon.flatMap { URL(string: $0) }, width: 34, height: 34, cornerRadius: 8, contentMode: .fill, iconName: "tv")
                                Text(ch.stream.name).font(.subheadline).lineLimit(1)
                                Spacer(minLength: 0)
                                if let s = statuses[ch.stream.id] {
                                    Image(systemName: s.icon).foregroundStyle(s.color).font(.caption)
                                }
                            }
                            .padding(.vertical, 6)
                            if index < checked.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func scan() async {
        isScanning = true
        progress = 0
        statuses = [:]
        let sample = Array(channels.prefix(40))
        let builder = PlaybackURLBuilder(playlist: playlist)
        for (index, ch) in sample.enumerated() {
            let url = builder.liveURL(streamId: ch.stream.streamId)
            let result = await TigerChannelProbe.check(url: url)
            statuses[ch.stream.id] = result
            progress = Double(index + 1) / Double(max(sample.count, 1))
        }
        isScanning = false
    }
}

// MARK: - ترتيب القنوات

struct TigerChannelReorderView: View {
    let playlist: Playlist

    @Query<LiveStreamsRequest> private var channels: [LiveStreamWithCategory]
    @State private var order: [LiveStreamWithCategory] = []
    @State private var editMode: EditMode = .active
    @State private var saved = false

    init(playlist: Playlist) {
        self.playlist = playlist
        _channels = Query(LiveStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    var body: some View {
        TigerPlusScreen(
            title: "ترتيب القنوات",
            subtitle: "اسحب القنوات لإعادة ترتيبها كما تحب. يُحفظ الترتيب لكل قائمة.",
            icon: "arrow.up.arrow.down"
        ) {
            if channels.isEmpty {
                TigerInfoNote(text: "لا توجد قنوات في هذه القائمة.", icon: "tv", tint: TigerTheme.orange)
            } else {
                TigerSettingsCard(title: "القنوات (\(order.count))", subtitle: "اسحب لإعادة الترتيب.", icon: "list.number", tint: TigerTheme.orange) {
                    List {
                        ForEach(order) { ch in
                            HStack(spacing: 10) {
                                CachedImage(url: ch.stream.streamIcon.flatMap { URL(string: $0) }, width: 32, height: 32, cornerRadius: 7, contentMode: .fill, iconName: "tv")
                                Text(ch.stream.name).font(.subheadline).lineLimit(1)
                            }
                        }
                        .onMove { from, to in
                            order.move(fromOffsets: from, toOffset: to)
                            saved = false
                        }
                    }
                    .listStyle(.plain)
                    .frame(height: min(CGFloat(order.count) * 46 + 20, 520))
                    .scrollContentBackground(.hidden)
                }

                Button {
                    save()
                } label: {
                    Label(saved ? "تم الحفظ ✓" : "حفظ الترتيب", systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(saved ? TigerTheme.brandLight : TigerTheme.orange)

                Button(role: .destructive) {
                    resetOrder()
                } label: {
                    Label("استعادة الترتيب الأصلي", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .environment(\.editMode, $editMode)
        .onAppear { loadOrder() }
        .onChange(of: channels) { _, _ in if order.isEmpty { loadOrder() } }
    }

    private func loadOrder() {
        let savedIds = CustomOrderStore.shared.load(playlistId: playlist.id, scope: "live")
        if savedIds.isEmpty {
            order = channels
        } else {
            let map = Dictionary(uniqueKeysWithValues: channels.map { ($0.stream.id, $0) })
            var ordered = savedIds.compactMap { map[$0] }
            let existing = Set(ordered.map { $0.stream.id })
            ordered.append(contentsOf: channels.filter { !existing.contains($0.stream.id) })
            order = ordered
        }
    }

    private func save() {
        CustomOrderStore.shared.save(order.map { $0.stream.id }, playlistId: playlist.id, scope: "live")
        saved = true
    }

    private func resetOrder() {
        CustomOrderStore.shared.save([], playlistId: playlist.id, scope: "live")
        order = channels
        saved = false
    }
}
