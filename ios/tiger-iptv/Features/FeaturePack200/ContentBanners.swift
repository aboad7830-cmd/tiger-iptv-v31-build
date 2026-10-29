import SwiftUI
import Foundation
import Combine
import GRDB
import GRDBQuery

// MARK: - اختيار اليوم (Deterministic daily pick)
//
// نختار نفس العنصر لكل المستخدمين خلال نفس اليوم، ويتغيّر تلقائياً كل يوم.
// لا حاجة لأي شبكة أو حالة محفوظة: اليوم من السنة % عدد العناصر.

enum TigerDailyPick {
    static func index(count: Int, offset: Int = 0, date: Date = Date()) -> Int? {
        guard count > 0 else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let raw = (day + offset) % count
        return raw >= 0 ? raw : raw + count
    }

    static func pick<T>(from pool: [T], offset: Int = 0) -> T? {
        guard let i = index(count: pool.count, offset: offset) else { return nil }
        return pool[i]
    }
}

// MARK: - بانر "فلم اليوم" / "مسلسل اليوم"

struct TigerDailyPickBanner<Destination: View>: View {
    let eyebrow: String
    let name: String
    let meta: String
    let plot: String?
    let rating10: Double?
    let backdropURL: URL?
    let posterURL: URL?
    let ctaTitle: String
    let fallbackIcon: String
    var onSurprise: (() -> Void)? = nil
    let destination: Destination

    @State private var appeared = false

    init(
        eyebrow: String,
        name: String,
        meta: String,
        plot: String? = nil,
        rating10: Double? = nil,
        backdropURL: URL? = nil,
        posterURL: URL? = nil,
        ctaTitle: String = "شاهد الآن",
        fallbackIcon: String = "film",
        onSurprise: (() -> Void)? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.eyebrow = eyebrow
        self.name = name
        self.meta = meta
        self.plot = plot
        self.rating10 = rating10
        self.backdropURL = backdropURL
        self.posterURL = posterURL
        self.ctaTitle = ctaTitle
        self.fallbackIcon = fallbackIcon
        self.onSurprise = onSurprise
        self.destination = destination()
    }

    private var imageURL: URL? { backdropURL ?? posterURL }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                destination
            } label: {
                ZStack(alignment: .bottomLeading) {
                    imageLayer
                    gradientLayer
                    content
                        .padding(18)
                }
                .frame(height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [TigerTheme.orange.opacity(0.65), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.38), radius: 20, y: 12)
            }
            .buttonStyle(.plain)

            // زر "مفاجئني" شقيق للرابط (وليس داخله) حتى لا يفتح صفحة التفاصيل.
            if let onSurprise {
                Button {
                    onSurprise()
                } label: {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .padding(.trailing, 30)
                .accessibilityLabel("اقترح لي شيئاً")
            }
        }
        .padding(.horizontal, 16)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.42)) { appeared = true }
        }
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let url = imageURL {
            GeometryReader { proxy in
                CachedImage(
                    url: url,
                    width: proxy.size.width,
                    height: 236,
                    cornerRadius: 0,
                    contentMode: .fill,
                    iconName: fallbackIcon,
                    loadProfile: .high
                )
                .frame(width: proxy.size.width, height: 236)
            }
        } else {
            LinearGradient(
                colors: [TigerTheme.orangeDeep.opacity(0.75), TigerTheme.ink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientLayer: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.10), location: 0),
                .init(color: .black.opacity(0.45), location: 0.52),
                .init(color: .black.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(TigerTheme.orangeGradient))

                if let rating10 {
                    TigerRatingBadge(value: rating10, compact: true)
                }

                Spacer(minLength: 0)
            }

            Text(name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.55), radius: 8, y: 3)

            if !meta.isEmpty {
                Text(meta)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }

            if let plot, !plot.isEmpty {
                Text(plot)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(ctaTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(TigerTheme.orangeGradient))
            .shadow(color: TigerTheme.orange.opacity(0.45), radius: 10, y: 4)
            .padding(.top, 2)
        }
    }
}

// MARK: - صف تصفية سريعة (chips)

struct TigerQuickFilterChips: View {
    let title: String
    let chips: [String]
    let onSelect: (String) -> Void

    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TigerTheme.orange)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        let isOn = selected == chip
                        Button {
                            selected = isOn ? nil : chip
                            if !isOn { onSelect(chip) }
                        } label: {
                            Text(chip)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(isOn ? .white : .primary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(
                                        isOn
                                        ? AnyShapeStyle(TigerTheme.orangeGradient)
                                        : AnyShapeStyle(Color.primary.opacity(0.07))
                                    )
                                )
                                .overlay(
                                    Capsule().strokeBorder(
                                        isOn ? Color.clear : Color.primary.opacity(0.08),
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - بطاقات المجموعات (بنرات صغيرة)

struct TigerCollectionEntry: Identifiable {
    let icon: String
    let title: String
    let count: Int
    let colors: [Color]
    let destination: AnyView

    var id: String { title }
}

struct TigerCollectionTilesRow: View {
    let entries: [TigerCollectionEntry]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(entries) { entry in
                    NavigationLink {
                        entry.destination
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: entry.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.white.opacity(0.18)))

                            Spacer(minLength: 0)

                            Text(entry.title)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("\(entry.count) عنصر")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        .padding(12)
                        .frame(width: 132, height: 108, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: entry.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: entry.colors.first?.opacity(0.35) ?? .clear, radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - رف أفلام قابل لإعادة الاستخدام

struct TigerMovieShelf: View, Equatable {
    let playlist: Playlist
    let title: String
    var subtitle: String? = nil
    var icon: String = "film"
    let items: [DBVODStream]
    var showsRank: Bool = false
    var showsChevron: Bool = true

    static func == (lhs: TigerMovieShelf, rhs: TigerMovieShelf) -> Bool {
        lhs.playlist.id == rhs.playlist.id &&
        lhs.title == rhs.title &&
        lhs.items == rhs.items &&
        lhs.showsRank == rhs.showsRank
    }

    @Environment(\.posterMetrics) private var posterMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsChevron {
                NavigationLink {
                    TigerMovieCollectionView(playlist: playlist, title: title, items: items)
                } label: {
                    TigerSectionHeader(
                        title: title,
                        count: items.count,
                        subtitle: subtitle
                    )
                }
                .buttonStyle(.plain)
            } else {
                TigerSectionHeader(
                    title: title,
                    count: items.count,
                    subtitle: subtitle,
                    showsChevron: false
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, stream in
                        NavigationLink {
                            MovieDetailView(playlist: playlist, movie: stream, queue: items)
                        } label: {
                            ZStack(alignment: .topLeading) {
                                VODStreamCard(
                                    playlistId: playlist.id,
                                    stream: stream,
                                    posterWidth: posterMetrics.shelfPosterWidth,
                                    posterHeight: posterMetrics.shelfPosterHeight,
                                    imageLoadProfile: .shelf
                                )

                                if showsRank {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(TigerTheme.orangeGradient))
                                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: posterMetrics.shelfRowTotalHeight)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - رف مسلسلات قابل لإعادة الاستخدام

struct TigerSeriesShelf: View, Equatable {
    let playlist: Playlist
    let title: String
    var subtitle: String? = nil
    var icon: String = "play.tv"
    let items: [DBSeries]
    var showsRank: Bool = false
    var showsChevron: Bool = true

    static func == (lhs: TigerSeriesShelf, rhs: TigerSeriesShelf) -> Bool {
        lhs.playlist.id == rhs.playlist.id &&
        lhs.title == rhs.title &&
        lhs.items == rhs.items &&
        lhs.showsRank == rhs.showsRank
    }

    @Environment(\.posterMetrics) private var posterMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsChevron {
                NavigationLink {
                    TigerSeriesCollectionView(playlist: playlist, title: title, items: items)
                } label: {
                    TigerSectionHeader(
                        title: title,
                        count: items.count,
                        subtitle: subtitle
                    )
                }
                .buttonStyle(.plain)
            } else {
                TigerSectionHeader(
                    title: title,
                    count: items.count,
                    subtitle: subtitle,
                    showsChevron: false
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, series in
                        NavigationLink {
                            SeriesDetailView(playlist: playlist, series: series)
                        } label: {
                            ZStack(alignment: .topLeading) {
                                SeriesCard(
                                    playlistId: playlist.id,
                                    stream: series,
                                    posterWidth: posterMetrics.shelfPosterWidth,
                                    posterHeight: posterMetrics.shelfPosterHeight,
                                    imageLoadProfile: .shelf
                                )

                                if showsRank {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(TigerTheme.orangeGradient))
                                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: posterMetrics.shelfRowTotalHeight)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - شاشات عرض المجموعة الكاملة

struct TigerMovieCollectionView: View {
    let playlist: Playlist
    let title: String
    let items: [DBVODStream]

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?

    private var wrapped: [VODWithCategory] {
        items.map { VODWithCategory(stream: $0, categoryName: "") }
    }

    private var displayItems: [VODWithCategory] {
        let q = debouncedQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return wrapped }
        return wrapped.filter { CatalogTextSearch.matches(search: q, text: $0.stream.name) }
    }

    var body: some View {
        VODCategoryContent(playlist: playlist, items: displayItems)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
            .searchable(text: $searchText, placement: TigerPlatform.searchPlacement, prompt: L("vod.search_placeholder"))
            .onChange(of: searchText) { _, new in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { debouncedQuery = new }
                }
            }
            .onDisappear { debounceTask?.cancel(); debounceTask = nil }
    }
}

struct TigerSeriesCollectionView: View {
    let playlist: Playlist
    let title: String
    let items: [DBSeries]

    @State private var searchText = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?

    private var wrapped: [SeriesWithCategory] {
        items.map { SeriesWithCategory(series: $0, categoryName: "") }
    }

    private var displayItems: [SeriesWithCategory] {
        let q = debouncedQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return wrapped }
        return wrapped.filter { CatalogTextSearch.matches(search: q, text: $0.series.name) }
    }

    var body: some View {
        SeriesCategoryContent(playlist: playlist, items: displayItems)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
            .searchable(text: $searchText, placement: TigerPlatform.searchPlacement, prompt: L("series.search_placeholder"))
            .onChange(of: searchText) { _, new in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { debouncedQuery = new }
                }
            }
            .onDisappear { debounceTask?.cancel(); debounceTask = nil }
    }
}

// MARK: - الأكثر مشاهدة (أفلام)

struct TigerMostWatchedMovieShelf: View {
    let playlist: Playlist
    let movies: [DBVODStream]

    @Query<RecentWatchHistoryRequest> private var history: [DBWatchHistory]

    init(playlist: Playlist, movies: [DBVODStream]) {
        self.playlist = playlist
        self.movies = movies
        _history = Query(
            RecentWatchHistoryRequest(playlistId: playlist.id, limit: 80, type: "vod"),
            in: \.appDatabase
        )
    }

    private var ordered: [DBVODStream] {
        guard !history.isEmpty else { return [] }
        var byId: [String: DBVODStream] = [:]
        for movie in movies {
            byId[String(movie.streamId)] = movie
        }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for item in history {
            guard byId[item.streamId] != nil else { continue }
            if counts[item.streamId] == nil { order.append(item.streamId) }
            counts[item.streamId, default: 0] += 1
        }
        let sorted = order.sorted { lhs, rhs in
            let l = counts[lhs] ?? 0
            let r = counts[rhs] ?? 0
            if l != r { return l > r }
            return lhs < rhs
        }
        return sorted.compactMap { byId[$0] }.prefix(20).map { $0 }
    }

    var body: some View {
        if ordered.count >= 3 {
            TigerMovieShelf(
                playlist: playlist,
                title: "الأكثر مشاهدة",
                subtitle: "ما يشاهده الجميع الآن",
                icon: "flame.fill",
                items: ordered,
                showsRank: true
            )
        }
    }
}

// MARK: - الأكثر مشاهدة (مسلسلات)

struct TigerMostWatchedSeriesShelf: View {
    let playlist: Playlist
    let series: [DBSeries]

    @Query<RecentWatchHistoryRequest> private var history: [DBWatchHistory]

    init(playlist: Playlist, series: [DBSeries]) {
        self.playlist = playlist
        self.series = series
        _history = Query(
            RecentWatchHistoryRequest(playlistId: playlist.id, limit: 80, type: "series"),
            in: \.appDatabase
        )
    }

    private var ordered: [DBSeries] {
        guard !history.isEmpty else { return [] }
        var byId: [String: DBSeries] = [:]
        for item in series {
            byId[String(item.seriesId)] = item
        }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for item in history {
            // في المسلسلات قد يكون streamId معرف حلقة، لذا نعتمد seriesId أولاً.
            let key = item.seriesId ?? item.streamId
            guard byId[key] != nil else { continue }
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        let sorted = order.sorted { lhs, rhs in
            let l = counts[lhs] ?? 0
            let r = counts[rhs] ?? 0
            if l != r { return l > r }
            return lhs < rhs
        }
        return sorted.compactMap { byId[$0] }.prefix(20).map { $0 }
    }

    var body: some View {
        if ordered.count >= 3 {
            TigerSeriesShelf(
                playlist: playlist,
                title: "الأكثر مشاهدة",
                subtitle: "مسلسلات يتابعها الجميع",
                icon: "flame.fill",
                items: ordered,
                showsRank: true
            )
        }
    }
}

// MARK: - أدوات مساعدة للتصنيفات

enum TigerGenreChips {
    /// يستخرج أكثر التصنيفات شيوعاً من أسماء الأقسام (يفصل على / و , و |)
    static func chips(from names: [String], limit: Int = 10) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let separators = CharacterSet(charactersIn: "/,|·-–")
        for name in names {
            let parts = name.components(separatedBy: separators)
            for part in parts {
                let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard token.count >= 2, token.count <= 18 else { continue }
                let key = token.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                result.append(token)
                if result.count >= limit { return result }
            }
        }
        return result
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 18) {
            TigerDailyPickBanner(
                eyebrow: "فلم اليوم",
                name: "فيلم تجريبي طويل الاسم",
                meta: "أكشن · 2024",
                plot: "قصة مشوّقة عن عالم آخر مليء بالمفاجآت والتفاصيل.",
                rating10: 8.6,
                backdropURL: nil,
                posterURL: nil,
                onSurprise: {}
            ) {
                Text("التفاصيل")
            }

            TigerQuickFilterChips(
                title: "تصفّح سريع",
                chips: ["أكشن", "كوميدي", "دراما", "رعب"],
                onSelect: { _ in }
            )
        }
        .padding(.vertical)
    }
    .background(TigerTheme.splashGradient)
}

// MARK: - أضواء TIGER — بنرات متحركة لصفحة البث المباشر

/// شريحة واحدة داخل «أضواء TIGER».
struct TigerLiveSpotlight: Identifiable, Hashable {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String
    let badge: String
    let colors: [Color]
    /// كلمة مفتاحية تُستخدم للانتقال السريع إلى قسم مطابق عند الضغط.
    let categoryHint: String?

    static let defaults: [TigerLiveSpotlight] = [
        .init(
            id: "live-4k",
            eyebrow: "أضواء TIGER",
            title: "بث مباشر بجودة 4K",
            subtitle: "قنوات عربية وعالمية بجودة عالية وصوت نقيّ، لحظة بلحظة.",
            icon: "sparkles.tv",
            badge: "LIVE",
            colors: [TigerTheme.brand, TigerTheme.brandLight],
            categoryHint: "4k"
        ),
        .init(
            id: "live-matches",
            eyebrow: "أهم المباريات اليوم",
            title: "لا تفوّت أي هدف",
            subtitle: "تابع أهم المباريات والبطولات، وانتقل للقسم الرياضي بضغطة.",
            icon: "sportscourt.fill",
            badge: "مباشر",
            colors: [TigerTheme.orangeDeep, TigerTheme.gold],
            categoryHint: "رياضة"
        ),
        .init(
            id: "live-library",
            eyebrow: "مكتبتك الخاصة",
            title: "أفلام ومسلسلات بلا حدود",
            subtitle: "أحدث الإضافات، وواصل المشاهدة من حيث توقفت تمامًا.",
            icon: "film.stack.fill",
            badge: "جديد",
            colors: [Color(red: 0.35, green: 0.22, blue: 0.72), Color(red: 0.62, green: 0.34, blue: 0.86)],
            categoryHint: "أفلام"
        ),
        .init(
            id: "live-tools",
            eyebrow: "أدوات المشاهدة الذكية",
            title: "تحكّم كامل بمشاهدتك",
            subtitle: "مؤقت نوم، سرعة تشغيل، ترجمة، واختبار شبكة — كلها بضغطة.",
            icon: "slider.horizontal.3",
            badge: "أدوات",
            colors: [Color(red: 0.06, green: 0.42, blue: 0.44), Color(red: 0.10, green: 0.62, blue: 0.58)],
            categoryHint: nil
        )
    ]
}

/// كاروسيل بنرات متحرك يتقدّم تلقائيًا مع نقاط تنقّل وحركة لطيفة.
struct TigerLiveHeroCarousel: View {
    var items: [TigerLiveSpotlight] = TigerLiveSpotlight.defaults
    var onSelect: (TigerLiveSpotlight) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme
    @State private var index: Int = 0
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TigerTheme.orangeGradient)
                Text("أضواء TIGER")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(TigerAdaptive.text(scheme))
                Text("مختارات تتجدّد")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TigerAdaptive.tertiaryText(scheme))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            TabView(selection: $index) {
                ForEach(items.indices, id: \.self) { offset in
                    banner(items[offset], isActive: offset == index)
                        .padding(.horizontal, 16)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 178)

            HStack(spacing: 6) {
                ForEach(items.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? AnyShapeStyle(TigerTheme.orangeGradient)
                                         : AnyShapeStyle(TigerAdaptive.chipStroke(scheme)))
                        .frame(width: i == index ? 22 : 7, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
                        .onTapGesture { withAnimation(.easeInOut) { index = i } }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 6)
        .onAppear { shimmer = true }
        .onReceive(Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()) { _ in
            guard items.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.55)) {
                index = (index + 1) % items.count
            }
        }
    }

    private func banner(_ item: TigerLiveSpotlight, isActive: Bool) -> some View {
        Button {
            onSelect(item)
        } label: {
            ZStack(alignment: .leading) {
                LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

                // هالة ضوئية
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 190, height: 190)
                    .blur(radius: 40)
                    .offset(x: 150, y: -60)

                // أيقونة مائية كبيرة
                Image(systemName: item.icon)
                    .font(.system(size: 130, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.14))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 150, y: 20)

                // لمعة متحركة
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.20), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 90)
                    .rotationEffect(.degrees(18))
                    .offset(x: shimmer ? geo.size.width + 60 : -120)
                    .animation(.linear(duration: 2.6).repeatForever(autoreverses: false), value: shimmer)
                }
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(item.badge)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.22)))
                        Text(item.eyebrow)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer(minLength: 0)
                    }

                    Text(item.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(item.subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 5) {
                        Text("استكشف")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.left")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.20)))
                    .padding(.top, 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: item.colors.first?.opacity(0.35) ?? .clear, radius: 14, x: 0, y: 8)
            .scaleEffect(isActive ? 1 : 0.96)
            .animation(.easeInOut(duration: 0.35), value: isActive)
        }
        .buttonStyle(.plain)
    }
}
