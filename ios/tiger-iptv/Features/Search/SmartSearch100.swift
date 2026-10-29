import Foundation
import SwiftUI
#if canImport(Speech)
import Speech
import AVFoundation
import GRDB
import Combine
#endif

// MARK: - 6..10 — البحث والاكتشاف الذكي

/// نتيجة بحث موحّدة عبر كل الاشتراكات.
struct UnifiedSearchResult: Identifiable, Hashable {
    enum Kind: String { case live, vod, series, m3u }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let imageURL: URL?
    let playlistId: UUID
    let playlistName: String
    let score: Int
}

/// 8. مسافة Levenshtein للبحث التقريبي.
enum FuzzyMatcher {

    static func distance(_ a: String, _ b: String) -> Int {
        let x = Array(a)
        let y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }

        var previous = Array(0...y.count)
        var current = [Int](repeating: 0, count: y.count + 1)

        for i in 1...x.count {
            current[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[y.count]
    }

    /// هل النصّان متقاربان بما يكفي؟ (يسمح بخطأ لكل 3 أحرف)
    static func matches(_ query: String, _ candidate: String) -> Bool {
        let q = normalize(query)
        let c = normalize(candidate)
        guard !q.isEmpty else { return true }
        if c.contains(q) { return true }
        let tolerance = max(1, q.count / 3)
        if abs(q.count - c.count) > tolerance + 2 { return false }
        return distance(q, String(c.prefix(max(q.count + tolerance, 3)))) <= tolerance
    }

    static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        s = s.replacingOccurrences(of: "أ", with: "ا")
        s = s.replacingOccurrences(of: "إ", with: "ا")
        s = s.replacingOccurrences(of: "آ", with: "ا")
        s = s.replacingOccurrences(of: "ى", with: "ي")
        s = s.replacingOccurrences(of: "ة", with: "ه")
        s = s.replacingOccurrences(of: "ؤ", with: "و")
        s = s.replacingOccurrences(of: "ئ", with: "ي")
        s = s.replacingOccurrences(of: "ـ", with: "")
        s = s.replacingOccurrences(of: "[\\u064B-\\u065F\\u0670]", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 6. محرّك البحث الموحّد.
@MainActor
final class UnifiedSearchEngine: ObservableObject {
    static let shared = UnifiedSearchEngine()

    @Published private(set) var results: [UnifiedSearchResult] = []
    @Published private(set) var isSearching = false
    @Published var query: String = ""

    private var task: Task<Void, Never>?

    func search(_ text: String, in playlists: [Playlist], limitPerSource: Int = 40) {
        query = text
        task?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        isSearching = true

        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }

            var collected: [UnifiedSearchResult] = []
            for playlist in playlists {
                guard !Task.isCancelled else { return }
                collected.append(contentsOf: await Self.query(trimmed, playlist: playlist, limit: limitPerSource))
            }

            let sorted = collected.sorted { $0.score > $1.score }
            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.results = sorted
                self.isSearching = false
            }
        }
    }

    private static func query(_ text: String, playlist: Playlist, limit: Int) async -> [UnifiedSearchResult] {
        do {
            return try await AppDatabase.shared.read { db -> [UnifiedSearchResult] in
                var out: [UnifiedSearchResult] = []
                let like = "%\(text)%"

                let lives = try DBLiveStream
                    .filter(Column("playlistId") == playlist.id.uuidString)
                    .filter(Column("name").like(like))
                    .limit(limit)
                    .fetchAll(db)
                for item in lives {
                    out.append(.init(
                        id: "live-\(item.id)", kind: .live, title: item.name,
                        subtitle: playlist.name, imageURL: item.streamIcon.flatMap(URL.init(string:)),
                        playlistId: playlist.id, playlistName: playlist.name,
                        score: Self.score(text, item.name)
                    ))
                }

                let vods = try DBVODStream
                    .filter(Column("playlistId") == playlist.id.uuidString)
                    .filter(Column("name").like(like))
                    .limit(limit)
                    .fetchAll(db)
                for item in vods {
                    out.append(.init(
                        id: "vod-\(item.id)", kind: .vod, title: item.name,
                        subtitle: playlist.name, imageURL: item.streamIcon.flatMap(URL.init(string:)),
                        playlistId: playlist.id, playlistName: playlist.name,
                        score: Self.score(text, item.name)
                    ))
                }

                let series = try DBSeries
                    .filter(Column("playlistId") == playlist.id.uuidString)
                    .filter(Column("name").like(like))
                    .limit(limit)
                    .fetchAll(db)
                for item in series {
                    out.append(.init(
                        id: "series-\(item.id)", kind: .series, title: item.name,
                        subtitle: playlist.name, imageURL: item.cover.flatMap(URL.init(string:)),
                        playlistId: playlist.id, playlistName: playlist.name,
                        score: Self.score(text, item.name)
                    ))
                }

                return out
            }
        } catch {
            Log.error("Search", "unified search failed: \(error.localizedDescription)")
            return []
        }
    }

    /// ترتيب: تطابق تام > بادئة > احتواء > تقريبي.
    private static func score(_ query: String, _ candidate: String) -> Int {
        let q = FuzzyMatcher.normalize(query)
        let c = FuzzyMatcher.normalize(candidate)
        if c == q { return 100 }
        if c.hasPrefix(q) { return 80 }
        if c.contains(q) { return 60 }
        if FuzzyMatcher.matches(query, candidate) { return 30 }
        return 10
    }
}

/// 7. البحث الصوتي العربي/الإنجليزي.
@MainActor
final class VoiceSearchController: ObservableObject {
    static let shared = VoiceSearchController()

    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""
    @Published private(set) var errorMessage: String?

    #if canImport(Speech)
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: TigerLocale.isArabic ? "ar-SA" : "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    #endif

    func start() {
        #if canImport(Speech)
        errorMessage = nil
        transcript = ""
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.errorMessage = L("search.voice.denied")
                    return
                }
                self.beginSession()
            }
        }
        #else
        errorMessage = L("search.voice.unavailable")
        #endif
    }

    #if canImport(Speech)
    private func beginSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            request?.shouldReportPartialResults = true

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                self.request?.append(buffer)
            }

            engine.prepare()
            try engine.start()
            isRecording = true

            task = recognizer?.recognitionTask(with: request!) { result, _ in
                Task { @MainActor in
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            stop()
        }
    }
    #endif

    func stop() {
        #if canImport(Speech)
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        #endif
        isRecording = false
    }
}

/// 9. مرشّحات مركّبة محفوظة.
struct SavedSearchFilter: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var kinds: [String] = []
    var categoryId: String?
    var minRating: Double?
    var yearFrom: Int?
    var yearTo: Int?
    var playlistId: UUID?
}

@MainActor
final class SearchFilterStore: ObservableObject {
    static let shared = SearchFilterStore()

    @Published private(set) var filters: [SavedSearchFilter] = []

    private let key = "search.savedFilters"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedSearchFilter].self, from: data) else {
            filters = []
            return
        }
        filters = decoded
    }

    func save(_ filter: SavedSearchFilter) {
        if let index = filters.firstIndex(where: { $0.id == filter.id }) {
            filters[index] = filter
        } else {
            filters.append(filter)
        }
        persist()
    }

    func delete(_ id: UUID) {
        filters.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(filters) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// 10. عنصر «متابعة المشاهدة».
struct ContinueWatchingItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let imageURL: URL?
    let progress: Double
    let kind: String
    let lastWatched: Date
}

/// 10. صف «متابعة المشاهدة» الذكي أعلى الرئيسية.
struct ContinueWatchingShelf: View {
    let items: [ContinueWatchingItem]
    var onSelect: (ContinueWatchingItem) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DT.Space.x1) {
                HStack {
                    Text(L("home.continue"))
                        .font(TigerType.font(TigerType.title3))
                    Spacer()
                    Text("\(items.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DT.Space.x2)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DT.Space.x1) {
                        ForEach(items) { item in
                            Button { onSelect(item) } label: {
                                ContinueWatchingCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DT.Space.x2)
                }
            }
        }
    }
}

struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                Group {
                    if let url = item.imageURL {
                        CachedImage(url: url, width: 150, height: 210, cornerRadius: DT.Corner.sm, contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous)
                            .fill(TigerTheme.brandGradient)
                            .frame(width: 150, height: 210)
                    }
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous))
                }
                .overlay(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.25))
                            Capsule()
                                .fill(TigerTheme.gold)
                                .frame(width: geo.size.width * max(0.02, min(1, item.progress)))
                        }
                    }
                    .frame(height: 4)
                    .padding(8)
                }
                .overlay(alignment: .center) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(radius: 6)
                }
            }
            .frame(width: 150, height: 210)

            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Text(item.subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.subtitle)")
        .accessibilityValue("\(Int(item.progress * 100))%")
    }
}

/// شاشة البحث الموحّد الجاهزة للاستخدام.
struct UnifiedSearchView: View {
    @StateObject private var engine = UnifiedSearchEngine.shared
    @StateObject private var voice = VoiceSearchController.shared
    @StateObject private var filters = SearchFilterStore.shared

    let playlists: [Playlist]
    var onSelect: (UnifiedSearchResult) -> Void

    @State private var showFilters = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if engine.isSearching {
                ProgressView().padding(.top, DT.Space.x2)
            }
            if !filters.filters.isEmpty {
                filterChips
            }
            List(engine.results) { result in
                Button { onSelect(result) } label: {
                    HStack(spacing: DT.Space.x1) {
                        Group {
                            if let url = result.imageURL {
                                CachedImage(url: url, width: 44, height: 44, cornerRadius: 8, contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.18))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            Text("\(result.playlistName) · \(result.kind.rawValue)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if engine.results.isEmpty && !engine.isSearching && engine.query.count >= 2 {
                    TigerEmptyState(
                        icon: "magnifyingglass",
                        title: L("search.empty.title"),
                        message: L("search.empty.message")
                    )
                }
            }
        }
        .navigationTitle(L("search.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showFilters = true } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(L("search.filters"))
            }
        }
        .sheet(isPresented: $showFilters) {
            SavedFiltersSheet()
        }
        .onChange(of: voice.transcript) { _, newValue in
            if !newValue.isEmpty {
                engine.search(newValue, in: playlists)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: DT.Space.x1) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L("search.placeholder"), text: Binding(
                get: { engine.query },
                set: { engine.search($0, in: playlists) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !engine.query.isEmpty {
                Button {
                    engine.search("", in: playlists)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                if voice.isRecording { voice.stop() } else { voice.start() }
            } label: {
                Image(systemName: voice.isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(voice.isRecording ? TigerColorBlindPalette.danger : TigerTheme.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("search.voice"))
        }
        .padding(.horizontal, DT.Space.x2)
        .padding(.vertical, DT.Space.x1)
        .background(.ultraThinMaterial)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DT.Space.x1) {
                ForEach(filters.filters) { filter in
                    Button {
                        engine.search(filter.name, in: playlists)
                    } label: {
                        Text(filter.name)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                Capsule().fill(TigerTheme.gold.opacity(0.16))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DT.Space.x2)
            .padding(.vertical, 6)
        }
    }
}

struct SavedFiltersSheet: View {
    @StateObject private var store = SearchFilterStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section(L("search.filters.saved")) {
                    ForEach(store.filters) { filter in
                        Text(filter.name)
                    }
                    .onDelete { indexSet in
                        indexSet.map { store.filters[$0].id }.forEach(store.delete)
                    }
                }
                Section(L("search.filters.new")) {
                    TextField(L("search.filters.name"), text: $newName)
                    Button(L("common.save")) {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.save(SavedSearchFilter(name: trimmed))
                        newName = ""
                        HapticEngine.play(.success)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(L("search.filters"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}
