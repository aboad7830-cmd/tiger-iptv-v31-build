//
//  TigerPlusSearch.swift
//  Tiger IPTV
//
//  حزمة v3.0 — البحث الموحّد (الميزات 1…10)
//  بحث واحد يغطّي القنوات والأفلام والمسلسلات، مع تطبيع الحروف العربية،
//  سجلّ بحث، بحث صوتي، وفلاتر فورية.
//

import SwiftUI
import GRDB
import GRDBQuery
import Combine

#if canImport(Speech) && os(iOS)
import Speech
import AVFoundation
#endif

// MARK: - تطبيع الحروف العربية

enum TigerArabicNormalizer {
    /// يزيل التشكيل والتطويل ويوحّد الألف والهمزة والياء والتاء المربوطة،
    /// ويحوّل الأرقام العربية-الهندية إلى لاتينية.
    static func normalize(_ input: String) -> String {
        guard !input.isEmpty else { return "" }

        let tashkeel: Set<Unicode.Scalar> = [
            "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}",
            "\u{0650}", "\u{0651}", "\u{0652}", "\u{0653}", "\u{0654}",
            "\u{0655}", "\u{0670}", "\u{0640}", "\u{06D6}", "\u{06D7}",
            "\u{06D8}", "\u{06D9}", "\u{06DA}", "\u{06DB}", "\u{06DC}",
            "\u{06DF}", "\u{06E0}", "\u{06E1}", "\u{06E2}", "\u{06E3}",
            "\u{06E4}", "\u{06E7}", "\u{06E8}", "\u{06EA}", "\u{06EB}",
            "\u{06EC}", "\u{06ED}"
        ]

        var scalars = String.UnicodeScalarView()
        for scalar in input.unicodeScalars {
            if tashkeel.contains(scalar) { continue }

            switch scalar {
            case "\u{0623}", "\u{0625}", "\u{0622}", "\u{0671}": // أ إ آ ٱ
                scalars.append("\u{0627}")
            case "\u{0624}": // ؤ
                scalars.append("\u{0648}")
            case "\u{0626}": // ئ
                scalars.append("\u{064A}")
            case "\u{0649}": // ى
                scalars.append("\u{064A}")
            case "\u{0629}": // ة
                scalars.append("\u{0647}")
            case "\u{06A9}": // ک
                scalars.append("\u{0643}")
            case "\u{06AF}": // گ
                scalars.append("\u{0643}")
            case "\u{06CC}": // ی
                scalars.append("\u{064A}")
            case "\u{06C0}": // ۀ
                scalars.append("\u{0647}")
            case "\u{0660}"..."\u{0669}": // ٠…٩
                if let ascii = Unicode.Scalar(scalar.value - 0x0660 + 0x30) {
                    scalars.append(ascii)
                }
            case "\u{06F0}"..."\u{06F9}": // ۰…۹
                if let ascii = Unicode.Scalar(scalar.value - 0x06F0 + 0x30) {
                    scalars.append(ascii)
                }
            default:
                scalars.append(scalar)
            }
        }

        let lowered = String(scalars).lowercased()
        return lowered
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "-" || $0 == "_" })
            .joined(separator: " ")
    }

    static func matches(_ text: String, query: String) -> Bool {
        let q = normalize(query)
        guard !q.isEmpty else { return true }
        return normalize(text).contains(q)
    }

    /// 100 = مطابقة تامة، 80 = بداية الاسم، 60 = بداية كلمة، 40 = احتواء، 0 = لا شيء.
    static func score(_ text: String, query: String) -> Int {
        let q = normalize(query)
        guard !q.isEmpty else { return 0 }
        let t = normalize(text)
        if t == q { return 100 }
        if t.hasPrefix(q) { return 80 }
        if t.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 60 }
        if t.contains(q) { return 40 }
        return 0
    }
}

// MARK: - سجلّ البحث

@MainActor
final class TigerSearchHistoryStore: ObservableObject {
    static let shared = TigerSearchHistoryStore()

    private let storageKey = "tiger.search.history.v3"
    private let limit = 24

    @Published private(set) var queries: [String] = []

    private init() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            queries = saved
        }
    }

    func record(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return }
        queries.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        queries.insert(value, at: 0)
        if queries.count > limit { queries = Array(queries.prefix(limit)) }
        persist()
    }

    func remove(_ value: String) {
        queries.removeAll { $0 == value }
        persist()
    }

    func clear() {
        queries.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(queries, forKey: storageKey)
    }
}

// MARK: - الفلاتر

enum TigerSearchKind: String, CaseIterable, Identifiable {
    case all, live, movies, series

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "الكل"
        case .live: return "قنوات"
        case .movies: return "أفلام"
        case .series: return "مسلسلات"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .live: return "tv.fill"
        case .movies: return "film.fill"
        case .series: return "play.tv.fill"
        }
    }
}

struct TigerSearchFilterState: Equatable {
    var kind: TigerSearchKind = .all
    var minRating: Double = 0
    var yearFrom: String = ""
    var yearTo: String = ""
    var genre: String = ""
    var maxMinutes: Int = 0
    var onlyUnwatched: Bool = false

    var isActive: Bool {
        kind != .all || minRating > 0 || !yearFrom.isEmpty || !yearTo.isEmpty
            || !genre.isEmpty || maxMinutes > 0 || onlyUnwatched
    }

    var activeCount: Int {
        var n = 0
        if kind != .all { n += 1 }
        if minRating > 0 { n += 1 }
        if !yearFrom.isEmpty || !yearTo.isEmpty { n += 1 }
        if !genre.isEmpty { n += 1 }
        if maxMinutes > 0 { n += 1 }
        if onlyUnwatched { n += 1 }
        return n
    }

    mutating func reset() { self = TigerSearchFilterState() }
}

// MARK: - نتيجة البحث

struct TigerSearchHit: Identifiable {
    enum Kind { case live, movie, series }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let imageURL: URL?
    let rating: Double?
    let year: Int?
    let minutes: Int?
    let score: Int
    let live: DBLiveStream?
    let movie: DBVODStream?
    let series: DBSeries?
}

// MARK: - محرّك البحث الموحّد

enum TigerUnifiedSearchEngine {
    static func search(
        query: String,
        live: [LiveStreamWithCategory],
        movies: [VODWithCategory],
        series: [SeriesWithCategory],
        filters: TigerSearchFilterState,
        watchedKeys: Set<String>
    ) -> [TigerSearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var hits: [TigerSearchHit] = []

        if filters.kind == .all || filters.kind == .live {
            for item in live {
                let s = item.stream
                let score = trimmed.isEmpty ? 1 : TigerArabicNormalizer.score(s.name, query: trimmed)
                guard score > 0 else { continue }
                hits.append(
                    TigerSearchHit(
                        id: "live-\(s.id)",
                        kind: .live,
                        title: s.name,
                        subtitle: item.categoryName,
                        imageURL: URL(string: s.streamIcon ?? ""),
                        rating: nil,
                        year: nil,
                        minutes: nil,
                        score: score,
                        live: s,
                        movie: nil,
                        series: nil
                    )
                )
            }
        }

        if filters.kind == .all || filters.kind == .movies {
            for item in movies {
                let m = item.stream
                let score = trimmed.isEmpty ? 1 : TigerArabicNormalizer.score(m.name, query: trimmed)
                guard score > 0 else { continue }
                guard passesMovieFilters(m, filters: filters, watchedKeys: watchedKeys) else { continue }
                hits.append(
                    TigerSearchHit(
                        id: "movie-\(m.id)",
                        kind: .movie,
                        title: m.name,
                        subtitle: item.categoryName,
                        imageURL: URL(string: m.streamIcon ?? ""),
                        rating: m.rating5Based.map { $0 * 2 },
                        year: parseYear(m.releaseDate ?? m.added),
                        minutes: parseMinutes(m.duration),
                        score: score,
                        live: nil,
                        movie: m,
                        series: nil
                    )
                )
            }
        }

        if filters.kind == .all || filters.kind == .series {
            for item in series {
                let s = item.series
                let score = trimmed.isEmpty ? 1 : TigerArabicNormalizer.score(s.name, query: trimmed)
                guard score > 0 else { continue }
                guard passesSeriesFilters(s, filters: filters, watchedKeys: watchedKeys) else { continue }
                hits.append(
                    TigerSearchHit(
                        id: "series-\(s.id)",
                        kind: .series,
                        title: s.name,
                        subtitle: item.categoryName,
                        imageURL: URL(string: s.cover ?? ""),
                        rating: s.rating5Based.map { $0 * 2 },
                        year: parseYear(s.releaseDate),
                        minutes: parseMinutes(s.episodeRunTime),
                        score: score,
                        live: nil,
                        movie: nil,
                        series: s
                    )
                )
            }
        }

        return hits.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if (lhs.rating ?? 0) != (rhs.rating ?? 0) { return (lhs.rating ?? 0) > (rhs.rating ?? 0) }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func passesMovieFilters(_ m: DBVODStream, filters: TigerSearchFilterState, watchedKeys: Set<String>) -> Bool {
        if filters.minRating > 0 {
            guard let r = m.rating5Based, r * 2 >= filters.minRating else { return false }
        }
        if let from = Int(filters.yearFrom), let year = parseYear(m.releaseDate ?? m.added), year < from { return false }
        if let to = Int(filters.yearTo), let year = parseYear(m.releaseDate ?? m.added), year > to { return false }
        if !filters.genre.isEmpty {
            guard TigerArabicNormalizer.matches(m.genre ?? "", query: filters.genre) else { return false }
        }
        if filters.maxMinutes > 0, let minutes = parseMinutes(m.duration), minutes > filters.maxMinutes { return false }
        if filters.onlyUnwatched, watchedKeys.contains("vod:\(m.streamId)") { return false }
        return true
    }

    private static func passesSeriesFilters(_ s: DBSeries, filters: TigerSearchFilterState, watchedKeys: Set<String>) -> Bool {
        if filters.minRating > 0 {
            guard let r = s.rating5Based, r * 2 >= filters.minRating else { return false }
        }
        if let from = Int(filters.yearFrom), let year = parseYear(s.releaseDate), year < from { return false }
        if let to = Int(filters.yearTo), let year = parseYear(s.releaseDate), year > to { return false }
        if !filters.genre.isEmpty {
            guard TigerArabicNormalizer.matches(s.genre ?? "", query: filters.genre) else { return false }
        }
        if filters.onlyUnwatched, watchedKeys.contains("series:\(s.seriesId)") { return false }
        return true
    }

    static func parseYear(_ raw: String?) -> Int? {
        guard let raw, raw.count >= 4 else { return nil }
        let digits = raw.prefix(4)
        return Int(digits)
    }

    static func parseMinutes(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ":").compactMap { Int($0) }
        if parts.count == 3 { return parts[0] * 60 + parts[1] }
        if parts.count == 2 { return parts[0] }
        return Int(raw)
    }
}

// MARK: - شاشة البحث الموحّد

struct TigerPlusSearchView: View {
    let playlist: Playlist

    @EnvironmentObject private var playerOverlay: PlayerOverlayController
    @ObservedObject private var history = TigerSearchHistoryStore.shared
    @Environment(\.tigerMetrics) private var metrics

    @Query<LiveStreamsRequest> private var live: [LiveStreamWithCategory]
    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<SeriesRequest> private var series: [SeriesWithCategory]
    @Query<RecentWatchHistoryRequest> private var recent: [DBWatchHistory]

    @State private var query = ""
    @State private var filters = TigerSearchFilterState()
    @State private var showFilters = false
    @FocusState private var searchFocused: Bool

    init(playlist: Playlist) {
        self.playlist = playlist
        _live = Query(LiveStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _series = Query(SeriesRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _recent = Query(RecentWatchHistoryRequest(playlistId: playlist.id, limit: 300), in: \.appDatabase)
    }

    private var watchedKeys: Set<String> {
        Set(recent.map { "\($0.type):\($0.streamId)" })
    }

    private var results: [TigerSearchHit] {
        TigerUnifiedSearchEngine.search(
            query: query,
            live: live,
            movies: movies,
            series: series,
            filters: filters,
            watchedKeys: watchedKeys
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                searchField

                if filters.isActive {
                    activeFilterBar
                }

                if query.isEmpty {
                    historySection
                    quickSuggestions
                } else if results.isEmpty {
                    emptyState
                } else {
                    resultsHeader
                    ForEach(results) { hit in
                        row(for: hit)
                    }
                }
            }
            .padding(.horizontal, metrics.contentPadding)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: metrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(TigerTheme.ink.opacity(0.001))
        .navigationTitle("البحث الموحّد")
        .tigerInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: TigerPlatform.trailingPlacement) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: filters.isActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("الفلاتر")
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                TigerSearchFiltersView(filters: $filters)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("تم") { showFilters = false }
                        }
                    }
            }
        }
        .onChange(of: query) { _, newValue in
            if newValue.count >= 3 {
                history.record(newValue)
            }
        }
    }

    // MARK: أجزاء الواجهة

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("ابحث في القنوات والأفلام والمسلسلات", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { history.record(query) }
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("مسح البحث")
            }

            TigerVoiceSearchButton { spoken in
                query = spoken
                history.record(spoken)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(TigerTheme.orange.opacity(searchFocused ? 0.55 : 0.12), lineWidth: 1)
        )
    }

    private var activeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("\(filters.activeCount) فلتر مفعّل")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TigerTheme.orange)

                if filters.kind != .all {
                    chip(filters.kind.title, icon: filters.kind.icon) { filters.kind = .all }
                }
                if filters.minRating > 0 {
                    chip(String(format: "★ %.1f+", filters.minRating), icon: "star.fill") { filters.minRating = 0 }
                }
                if !filters.yearFrom.isEmpty || !filters.yearTo.isEmpty {
                    chip("\(filters.yearFrom)–\(filters.yearTo)", icon: "calendar") {
                        filters.yearFrom = ""
                        filters.yearTo = ""
                    }
                }
                if !filters.genre.isEmpty {
                    chip(filters.genre, icon: "theatermasks.fill") { filters.genre = "" }
                }
                if filters.maxMinutes > 0 {
                    chip("≤ \(filters.maxMinutes) د", icon: "timer") { filters.maxMinutes = 0 }
                }
                if filters.onlyUnwatched {
                    chip("غير مشاهد", icon: "eye.slash.fill") { filters.onlyUnwatched = false }
                }

                Button {
                    filters.reset()
                } label: {
                    Label("تصفير", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ title: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(title).font(.caption.weight(.semibold))
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(TigerTheme.orange.opacity(0.14)))
            .foregroundStyle(TigerTheme.orange)
        }
        .buttonStyle(.plain)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !history.queries.isEmpty {
                HStack {
                    TigerSectionHeader(title: "آخر ما بحثت عنه", count: history.queries.count, showsChevron: false)
                    Spacer()
                    Button("مسح") { history.clear() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                FlowChips(
                    items: history.queries,
                    icon: "clock.arrow.circlepath",
                    onSelect: { query = $0 },
                    onDelete: { history.remove($0) }
                )
            }
        }
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            TigerSectionHeader(title: "اقتراحات سريعة", showsChevron: false)

            FlowChips(
                items: ["أكشن", "دراما", "كوميدي", "أطفال", "رياضة", "أخبار", "رعب", "وثائقي"],
                icon: "sparkles",
                onSelect: { query = $0 },
                onDelete: nil
            )

            HStack(spacing: 10) {
                ForEach(TigerSearchKind.allCases) { kind in
                    Button {
                        filters.kind = kind
                    } label: {
                        Label(kind.title, systemImage: kind.icon)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(filters.kind == kind
                                               ? TigerTheme.orange.opacity(0.22)
                                               : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(filters.kind == kind ? TigerTheme.orange : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultsHeader: some View {
        HStack(spacing: 8) {
            Text("\(results.count) نتيجة")
                .font(.subheadline.weight(.bold))
            Text("لـ «\(query)»")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)
            Text("لا توجد نتائج")
                .font(.headline)
            Text("جرّب كلمة أقصر أو أزل بعض الفلاتر.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if filters.isActive {
                Button("إزالة الفلاتر") { filters.reset() }
                    .buttonStyle(.borderedProminent)
                    .tint(TigerTheme.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func row(for hit: TigerSearchHit) -> some View {
        switch hit.kind {
        case .live:
            if let stream = hit.live {
                NavigationLink {
                    TigerLiveChannelScreen(playlist: playlist, channel: stream)
                } label: {
                    TigerSearchHitRow(hit: hit)
                }
                .buttonStyle(.plain)
                .tigerFocusCard(cornerRadius: Radius.md)
            }
        case .movie:
            if let movie = hit.movie {
                NavigationLink {
                    MovieDetailView(playlist: playlist, movie: movie)
                } label: {
                    TigerSearchHitRow(hit: hit)
                }
                .buttonStyle(.plain)
                .tigerFocusCard(cornerRadius: Radius.md)
            }
        case .series:
            if let series = hit.series {
                NavigationLink {
                    SeriesDetailView(playlist: playlist, series: series)
                } label: {
                    TigerSearchHitRow(hit: hit)
                }
                .buttonStyle(.plain)
                .tigerFocusCard(cornerRadius: Radius.md)
            }
        }
    }
}

// MARK: - صفّ النتيجة

struct TigerSearchHitRow: View {
    let hit: TigerSearchHit

    private var badgeText: String {
        switch hit.kind {
        case .live: return "قناة"
        case .movie: return "فيلم"
        case .series: return "مسلسل"
        }
    }

    private var badgeTint: Color {
        switch hit.kind {
        case .live: return Color(red: 0.95, green: 0.30, blue: 0.35)
        case .movie: return TigerTheme.orange
        case .series: return Color(red: 0.55, green: 0.35, blue: 0.95)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(
                url: hit.imageURL,
                width: hit.kind == .live ? 64 : 58,
                height: hit.kind == .live ? 48 : 82,
                cornerRadius: 10,
                contentMode: .fill,
                iconName: hit.kind == .live ? "tv" : "film",
                loadProfile: .grid
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(hit.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(hit.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(badgeTint.opacity(0.18)))
                        .foregroundStyle(badgeTint)

                    if let rating = hit.rating, rating > 0 {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(TigerTheme.goldLight)
                    }
                    if let year = hit.year {
                        Text(String(year))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let minutes = hit.minutes, minutes > 0 {
                        Text("\(minutes) د")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - شاشة قناة مباشرة

struct TigerLiveChannelScreen: View {
    let playlist: Playlist
    let channel: DBLiveStream

    @EnvironmentObject private var playerOverlay: PlayerOverlayController
    @Environment(\.tigerMetrics) private var metrics

    private var iconURL: URL? { URL(string: channel.streamIcon ?? "") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                HStack(alignment: .top, spacing: 16) {
                    CachedImage(
                        url: iconURL,
                        width: 96,
                        height: 96,
                        cornerRadius: 18,
                        contentMode: .fill,
                        iconName: "tv",
                        loadProfile: .standard
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(channel.name)
                            .font(.title3.weight(.bold))
                            .lineLimit(3)
                        if channel.supportsCatchup {
                            Label("يدعم الإعادة \(channel.tvArchiveDuration ?? 0) ساعة", systemImage: "arrow.counterclockwise.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TigerTheme.orange)
                        } else {
                            Text("بث مباشر")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    play()
                } label: {
                    Label("مشاهدة الآن", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TigerTheme.orangeGradient, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                TigerChannelHealthCard(playlist: playlist, channel: channel)
            }
            .padding(metrics.contentPadding)
            .frame(maxWidth: metrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(channel.name)
        .tigerInlineNavigationTitle()
    }

    private func play() {
        guard let url = PlaybackURLBuilder(playlist: playlist).liveURL(streamId: channel.streamId) else { return }
        playerOverlay.present(playlistId: playlist.id) {
            PlayerView(
                url: url,
                title: channel.name,
                subtitle: "بث مباشر",
                artworkURL: iconURL,
                isLiveStream: true,
                playlistId: playlist.id,
                streamId: String(channel.streamId),
                type: "live"
            )
        }
    }
}

// MARK: - شاشة الفلاتر

struct TigerSearchFiltersView: View {
    @Binding var filters: TigerSearchFilterState
    @Environment(\.dismiss) private var dismiss

    private let genres = ["", "أكشن", "دراما", "كوميدي", "رعب", "خيال علمي", "وثائقي", "أطفال", "رومانسي", "جريمة"]
    private let durations = [0, 60, 90, 120, 150]

    var body: some View {
        Form {
            Section("النوع") {
                Picker("النوع", selection: $filters.kind) {
                    ForEach(TigerSearchKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("التقييم الأدنى") {
                HStack {
                    Slider(value: $filters.minRating, in: 0...5, step: 0.5)
                        .tint(TigerTheme.orange)
                    Text(filters.minRating == 0 ? "بدون" : String(format: "%.1f", filters.minRating))
                        .font(.caption.monospacedDigit())
                        .frame(width: 46, alignment: .trailing)
                }
            }

            Section("سنة الإصدار") {
                HStack {
                    TextField("من", text: $filters.yearFrom)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Divider()
                    TextField("إلى", text: $filters.yearTo)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }

            Section("التصنيف") {
                Picker("التصنيف", selection: $filters.genre) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre.isEmpty ? "الكل" : genre).tag(genre)
                    }
                }
            }

            Section("المدة القصوى") {
                Picker("المدة", selection: $filters.maxMinutes) {
                    ForEach(durations, id: \.self) { value in
                        Text(value == 0 ? "بدون حد" : "\(value) دقيقة").tag(value)
                    }
                }
            }

            Section {
                Toggle("غير المشاهد فقط", isOn: $filters.onlyUnwatched)
                    .tint(TigerTheme.orange)
            }

            Section {
                Button("تصفير كل الفلاتر", role: .destructive) {
                    filters.reset()
                }
            }
        }
        .navigationTitle("الفلاتر")
        .tigerInlineNavigationTitle()
    }
}

// MARK: - شرائح مرنة

struct FlowChips: View {
    let items: [String]
    var icon: String = "tag.fill"
    let onSelect: (String) -> Void
    var onDelete: ((String) -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: icon)
                                .font(.system(size: 9, weight: .bold))
                            Text(item)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)

                    if let onDelete {
                        Button {
                            onDelete(item)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
                .contentShape(Capsule())
            }
        }
    }
}

// MARK: - البحث الصوتي

struct TigerVoiceSearchButton: View {
    let onResult: (String) -> Void

    @StateObject private var recognizer = TigerVoiceRecognizer()
    @State private var showError = false

    var body: some View {
        Button {
            if recognizer.isRecording {
                recognizer.stop()
            } else {
                recognizer.start(
                    onResult: { text in
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { onResult(trimmed) }
                    },
                    onError: { _ in showError = true }
                )
            }
        } label: {
            Image(systemName: recognizer.isRecording ? "waveform.circle.fill" : "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(recognizer.isRecording ? TigerTheme.orange : Color.secondary)
                .symbolEffect(.pulse, isActive: recognizer.isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("البحث الصوتي")
        .alert("تعذّر تشغيل الميكروفون", isPresented: $showError) {
            Button("حسنًا", role: .cancel) {}
        } message: {
            Text("تأكد من السماح للتطبيق باستخدام الميكروفون والتعرّف على الكلام من الإعدادات.")
        }
    }
}

@MainActor
final class TigerVoiceRecognizer: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var transcript = ""

    #if canImport(Speech) && os(iOS)
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif

    func start(onResult: @escaping (String) -> Void, onError: @escaping (Error?) -> Void) {
        #if canImport(Speech) && os(iOS)
        guard !isRecording else { return }
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    onError(nil)
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        guard granted else {
                            onError(nil)
                            return
                        }
                        self.begin(onResult: onResult, onError: onError)
                    }
                }
            }
        }
        #else
        onError(nil)
        #endif
    }

    func stop() {
        #if canImport(Speech) && os(iOS)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        #endif
    }

    #if canImport(Speech) && os(iOS)
    private func begin(onResult: @escaping (String) -> Void, onError: @escaping (Error?) -> Void) {
        do {
            task?.cancel()
            task = nil

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        let text = result.bestTranscription.formattedString
                        self.transcript = text
                        if result.isFinal {
                            onResult(text)
                            self.stop()
                        }
                    }
                    if error != nil {
                        self.stop()
                    }
                }
            }
        } catch {
            stop()
            onError(error)
        }
    }
    #endif
}
