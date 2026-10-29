//
//  TigerPlusDiscovery.swift
//  Tiger IPTV
//
//  حزمة v3.0 — الاكتشاف والبحث: البحث الموحّد، السجل، الصوت، الفلاتر،
//  الترشيحات، الصفوف الذكية، الاكتشاف العشوائي، المحتوى المشابه،
//  غير المشاهد، والحلقات الجديدة.
//

import SwiftUI
import GRDB
import GRDBQuery

// MARK: - أدوات عرض مشتركة

/// شبكة ملصقات سينمائية متجاوبة تعمل على كل أجهزة Apple.
struct TigerPosterGrid<Item: Identifiable>: View {
    let items: [Item]
    let imageURL: (Item) -> URL?
    let title: (Item) -> String
    let subtitle: (Item) -> String?
    let badge: (Item) -> String?
    let action: (Item) -> AnyView

    var body: some View {
        TigerResponsiveGrid(items: items, minCellWidth: 132, spacing: Spacing.md) { item in
            Button {
                _ = action(item)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        CachedImage(url: imageURL(item), width: 160, height: 230, cornerRadius: Radius.md, contentMode: .fill, iconName: "film", loadProfile: .grid)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(2.0/3.0, contentMode: .fit)
                        if let badge = badge(item), !badge.isEmpty {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(TigerTheme.orange, in: Capsule())
                                .foregroundStyle(.black)
                                .padding(6)
                        }
                    }
                    Text(title(item)).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    if let subtitle = subtitle(item), !subtitle.isEmpty {
                        Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .tigerFocusCard(cornerRadius: Radius.md)
        }
    }
}

/// حاوية شاشة اكتشاف قياسية.
struct TigerDiscoveryScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.tigerMetrics) private var metrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                if let subtitle {
                    HStack(alignment: .top, spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TigerTheme.orange)
                                .frame(width: 26)
                        }
                        Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                content()
            }
            .padding(.horizontal, metrics.contentPadding)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: metrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .tigerInlineNavigationTitle()
    }
}

// MARK: - سجل البحث

struct TigerSearchHistoryScreen: View {
    @StateObject private var history = TigerSearchHistoryStore.shared
    @State private var draft: String = ""

    var body: some View {
        TigerPlusScreen(
            title: "سجل البحث",
            subtitle: "آخر ما بحثت عنه، جاهز لإعادة البحث بضغطة.",
            icon: "clock.arrow.circlepath"
        ) {
            TigerSettingsCard(title: "بحث جديد", subtitle: nil, icon: "magnifyingglass", tint: TigerTheme.orange) {
                HStack(spacing: 8) {
                    TextField("اكتب كلمة للبحث…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commit() }
                    Button("حفظ") { commit() }
                        .buttonStyle(.borderedProminent)
                        .tint(TigerTheme.orange)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if history.queries.isEmpty {
                TigerInfoNote(text: "السجل فارغ. ستُحفظ عمليات البحث تلقائيًا لتسهيل الوصول.", icon: "tray", tint: TigerTheme.orange)
            } else {
                TigerSettingsCard(title: "عمليات البحث (\(history.queries.count))", subtitle: nil, icon: "list.bullet", tint: TigerTheme.brandLight) {
                    VStack(spacing: 0) {
                        ForEach(Array(history.queries.enumerated()), id: \.offset) { index, q in
                            HStack {
                                Image(systemName: "clock").foregroundStyle(.secondary).font(.caption)
                                Text(q).font(.subheadline)
                                Spacer()
                                Button {
                                    history.remove(q)
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            if index < history.queries.count - 1 { Divider() }
                        }
                    }
                }
                Button(role: .destructive) {
                    history.clear()
                } label: {
                    Label("مسح السجل بالكامل", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        history.record(trimmed)
        draft = ""
    }
}

// MARK: - البحث الصوتي

struct TigerVoiceSearchScreen: View {
    @StateObject private var recognizer = TigerVoiceRecognizer()
    @State private var lastResult: String = ""

    var body: some View {
        TigerPlusScreen(
            title: "البحث الصوتي",
            subtitle: "تحدّث بالعربية وسيُحوَّل كلامك إلى نص للبحث مباشرة.",
            icon: "mic.circle"
        ) {
            TigerSettingsCard(title: "الميكروفون", subtitle: nil, icon: "waveform", tint: TigerTheme.orange) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(recognizer.isRecording ? TigerTheme.orange.opacity(0.18) : Color.primary.opacity(0.06))
                            .frame(width: 120, height: 120)
                        Image(systemName: recognizer.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(recognizer.isRecording ? TigerTheme.orange : .secondary)
                            .symbolEffect(.variableColor, isActive: recognizer.isRecording)
                    }
                    Text(recognizer.transcript.isEmpty ? "اضغط للتحدّث…" : recognizer.transcript)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button {
                        if recognizer.isRecording {
                            recognizer.stop()
                            lastResult = recognizer.transcript
                        } else {
                            recognizer.start(onResult: { text in
                                lastResult = text
                            }, onError: { _ in })
                        }
                    } label: {
                        Label(recognizer.isRecording ? "إيقاف" : "بدء الاستماع",
                              systemImage: recognizer.isRecording ? "stop.fill" : "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TigerTheme.orange)
                }
            }

            if !lastResult.isEmpty {
                TigerSettingsCard(title: "النتيجة", subtitle: nil, icon: "text.quote", tint: TigerTheme.brandLight) {
                    Text(lastResult).font(.body)
                }
            }

            TigerInfoNote(text: "البحث الصوتي متاح على iOS فقط حاليًا. على tvOS وماك استخدم لوحة المفاتيح أو الريموت.", icon: "info.circle", tint: TigerTheme.gold)
        }
    }
}

// MARK: - مختبر الفلاتر

struct TigerFilterLabView: View {
    let playlist: Playlist

    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<SeriesRequest> private var series: [SeriesWithCategory]

    @State private var kind: TigerSearchKind = .movies
    @State private var minRating: Double = 0
    @State private var genre: String = "الكل"
    @State private var yearFrom: String = ""
    @State private var yearTo: String = ""

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _series = Query(SeriesRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    private var genres: [String] {
        var set = Set<String>()
        for m in movies { if let g = m.stream.genre, !g.isEmpty { set.insert(g) } }
        for s in series { if let g = s.series.genre, !g.isEmpty { set.insert(g) } }
        return ["الكل"] + set.sorted()
    }

    private var filteredMovies: [VODWithCategory] {
        movies.filter { m in
            if let r = m.stream.rating5Based, r < minRating { return false }
            if genre != "الكل", !(m.stream.genre ?? "").localizedCaseInsensitiveContains(genre) { return false }
            if let y = Int((m.stream.releaseDate ?? "").prefix(4)), let from = Int(yearFrom), y < from { return false }
            if let y = Int((m.stream.releaseDate ?? "").prefix(4)), let to = Int(yearTo), y > to { return false }
            return true
        }
    }

    private var filteredSeries: [SeriesWithCategory] {
        series.filter { s in
            if let r = s.series.rating5Based, r < minRating { return false }
            if genre != "الكل", !(s.series.genre ?? "").localizedCaseInsensitiveContains(genre) { return false }
            if let y = Int((s.series.releaseDate ?? "").prefix(4)), let from = Int(yearFrom), y < from { return false }
            if let y = Int((s.series.releaseDate ?? "").prefix(4)), let to = Int(yearTo), y > to { return false }
            return true
        }
    }

    var body: some View {
        TigerDiscoveryScaffold(title: "الفلاتر الفورية", subtitle: "صفِّ الأفلام والمسلسلات حسب التقييم والنوع والسنة.", icon: "line.3.horizontal.decrease.circle") {
            TigerSettingsCard(title: "معايير التصفية", subtitle: nil, icon: "slider.horizontal.3", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("النوع", selection: $kind) {
                        Text("أفلام").tag(TigerSearchKind.movies)
                        Text("مسلسلات").tag(TigerSearchKind.series)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("أدنى تقييم").font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f ★", minRating)).font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.orange)
                    }
                    Slider(value: $minRating, in: 0...5, step: 0.5).tint(TigerTheme.orange)

                    Picker("التصنيف", selection: $genre) {
                        ForEach(genres, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    HStack(spacing: 12) {
                        TextField("من سنة", text: $yearFrom)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        TextField("إلى سنة", text: $yearTo)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                }
            }

            if kind == .movies {
                Text("النتائج: \(filteredMovies.count) فيلم").font(.subheadline.weight(.semibold))
                TigerPosterGrid(items: filteredMovies,
                                imageURL: { $0.stream.streamIcon.flatMap { URL(string: $0) } },
                                title: { $0.stream.name },
                                subtitle: { $0.categoryName },
                                badge: { $0.stream.rating },
                                action: { m in AnyView(MovieDetailView(playlist: playlist, movie: m.stream)) })
            } else {
                Text("النتائج: \(filteredSeries.count) مسلسل").font(.subheadline.weight(.semibold))
                TigerPosterGrid(items: filteredSeries,
                                imageURL: { $0.series.cover.flatMap { URL(string: $0) } },
                                title: { $0.series.name },
                                subtitle: { $0.categoryName },
                                badge: { $0.series.rating },
                                action: { s in AnyView(SeriesDetailView(playlist: playlist, series: s.series)) })
            }
        }
    }
}

// MARK: - الترشيحات

struct TigerRecommendationsView: View {
    let playlist: Playlist

    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<RecentWatchHistoryRequest> private var recent: [DBWatchHistory]

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _recent = Query(RecentWatchHistoryRequest(playlistId: playlist.id, limit: 40), in: \.appDatabase)
    }

    private var watchedIds: Set<String> { Set(recent.map { $0.streamId }) }

    private var recommended: [VODWithCategory] {
        let genres = Set(recent.compactMap { h -> String? in
            movies.first { String($0.stream.streamId) == h.streamId }?.stream.genre
        })
        let scored = movies.map { m -> (VODWithCategory, Double) in
            var score = m.stream.rating5Based ?? 0
            if let g = m.stream.genre, genres.contains(g) { score += 2 }
            if watchedIds.contains(String(m.stream.streamId)) { score -= 5 }
            return (m, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(30).map { $0.0 }
    }

    var body: some View {
        TigerDiscoveryScaffold(title: "محرّك الترشيحات", subtitle: "اقتراحات مبنية على ما شاهدته وتقييماتك.", icon: "sparkles") {
            if recent.isEmpty {
                TigerInfoNote(text: "شاهد بعض الأفلام أولًا لتحصل على ترشيحات مخصّصة. نعرض لك الآن الأعلى تقييمًا.", icon: "sparkles", tint: TigerTheme.orange)
            }
            TigerPosterGrid(items: recommended,
                            imageURL: { $0.stream.streamIcon.flatMap { URL(string: $0) } },
                            title: { $0.stream.name },
                            subtitle: { $0.stream.genre },
                            badge: { $0.stream.rating },
                            action: { m in AnyView(MovieDetailView(playlist: playlist, movie: m.stream)) })
        }
    }
}

// MARK: - الصفوف الذكية

struct TigerSmartRowsView: View {
    let playlist: Playlist

    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<SeriesRequest> private var series: [SeriesWithCategory]

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _series = Query(SeriesRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    private var topRated: [VODWithCategory] { movies.sorted { ($0.stream.rating5Based ?? 0) > ($1.stream.rating5Based ?? 0) }.prefix(12).map { $0 } }
    private var newest: [VODWithCategory] { movies.sorted { ($0.stream.added ?? "") > ($1.stream.added ?? "") }.prefix(12).map { $0 } }
    private var topSeries: [SeriesWithCategory] { series.sorted { ($0.series.rating5Based ?? 0) > ($1.series.rating5Based ?? 0) }.prefix(12).map { $0 } }

    var body: some View {
        TigerDiscoveryScaffold(title: "الصفوف الذكية", subtitle: "صفوف تلقائية: الأعلى تقييمًا، الأحدث، وأفضل المسلسلات.", icon: "square.stack.3d.up") {
            row(title: "الأعلى تقييمًا", icon: "star.fill", items: topRated)
            row(title: "أُضيف حديثًا", icon: "clock.badge.checkmark", items: newest)
            Text("أفضل المسلسلات").font(.headline)
            TigerPosterGrid(items: topSeries,
                            imageURL: { $0.series.cover.flatMap { URL(string: $0) } },
                            title: { $0.series.name },
                            subtitle: { $0.categoryName },
                            badge: { $0.series.rating },
                            action: { s in AnyView(SeriesDetailView(playlist: playlist, series: s.series)) })
        }
    }

    private func row(title: String, icon: String, items: [VODWithCategory]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(TigerTheme.orange)
                Text(title).font(.headline)
            }
            TigerPosterGrid(items: items,
                            imageURL: { $0.stream.streamIcon.flatMap { URL(string: $0) } },
                            title: { $0.stream.name },
                            subtitle: { $0.categoryName },
                            badge: { $0.stream.rating },
                            action: { m in AnyView(MovieDetailView(playlist: playlist, movie: m.stream)) })
        }
    }
}

// MARK: - الاكتشاف العشوائي

struct TigerRandomDiscoveryView: View {
    let playlist: Playlist

    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<SeriesRequest> private var series: [SeriesWithCategory]

    @State private var pickedMovie: DBVODStream?
    @State private var pickedSeries: DBSeries?
    @State private var spinning = false

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _series = Query(SeriesRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    var body: some View {
        TigerPlusScreen(title: "اكتشاف عشوائي", subtitle: "لا تعرف ماذا تشاهد؟ دع الحظ يختار لك.", icon: "dice") {
            TigerSettingsCard(title: "اختيار عشوائي", subtitle: nil, icon: "shuffle", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    if let m = pickedMovie {
                        HStack(spacing: 12) {
                            CachedImage(url: m.streamIcon.flatMap { URL(string: $0) }, width: 80, height: 116, cornerRadius: Radius.md, contentMode: .fill, iconName: "film")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.name).font(.headline)
                                Text(m.genre ?? "فيلم").font(.caption).foregroundStyle(.secondary)
                                NavigationLink("التفاصيل") { MovieDetailView(playlist: playlist, movie: m) }
                                    .buttonStyle(.borderedProminent).tint(TigerTheme.orange).controlSize(.small)
                            }
                            Spacer(minLength: 0)
                        }
                    } else if let s = pickedSeries {
                        HStack(spacing: 12) {
                            CachedImage(url: s.cover.flatMap { URL(string: $0) }, width: 80, height: 116, cornerRadius: Radius.md, contentMode: .fill, iconName: "tv")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name).font(.headline)
                                Text(s.genre ?? "مسلسل").font(.caption).foregroundStyle(.secondary)
                                NavigationLink("التفاصيل") { SeriesDetailView(playlist: playlist, series: s) }
                                    .buttonStyle(.borderedProminent).tint(TigerTheme.orange).controlSize(.small)
                            }
                            Spacer(minLength: 0)
                        }
                    } else {
                        Text("اضغط الزر لاختيار فيلم أو مسلسل عشوائيًا.")
                            .font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 12) {
                        Button {
                            spinMovie()
                        } label: {
                            Label("فيلم عشوائي", systemImage: "film").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(TigerTheme.orange)

                        Button {
                            spinSeries()
                        } label: {
                            Label("مسلسل عشوائي", systemImage: "tv").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(TigerTheme.brandLight)
                    }
                }
            }
        }
    }

    private func spinMovie() {
        pickedSeries = nil
        pickedMovie = movies.randomElement()?.stream
    }

    private func spinSeries() {
        pickedMovie = nil
        pickedSeries = series.randomElement()?.series
    }
}

// MARK: - المحتوى المشابه

struct TigerSimilarContentView: View {
    let playlist: Playlist

    @Query<VODStreamsRequest> private var movies: [VODWithCategory]

    @State private var seedGenre: String = ""

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    private var genres: [String] {
        Array(Set(movies.compactMap { $0.stream.genre }.filter { !$0.isEmpty })).sorted()
    }

    private var similar: [VODWithCategory] {
        guard !seedGenre.isEmpty else { return [] }
        return movies.filter { ($0.stream.genre ?? "").localizedCaseInsensitiveContains(seedGenre) }
    }

    var body: some View {
        TigerDiscoveryScaffold(title: "محتوى مشابه", subtitle: "اختر نوعًا لعرض أعمال مشابهة.", icon: "square.on.square") {
            TigerSettingsCard(title: "اختر النوع", subtitle: nil, icon: "tag", tint: TigerTheme.orange) {
                Picker("النوع", selection: $seedGenre) {
                    Text("اختر…").tag("")
                    ForEach(genres, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
            if seedGenre.isEmpty {
                TigerInfoNote(text: "اختر نوعًا من القائمة لعرض الأعمال المشابهة.", icon: "hand.point.up.left", tint: TigerTheme.orange)
            } else {
                TigerPosterGrid(items: similar,
                                imageURL: { $0.stream.streamIcon.flatMap { URL(string: $0) } },
                                title: { $0.stream.name },
                                subtitle: { $0.categoryName },
                                badge: { $0.stream.rating },
                                action: { m in AnyView(MovieDetailView(playlist: playlist, movie: m.stream)) })
            }
        }
    }
}

// MARK: - غير المشاهد

struct TigerUnwatchedView: View {
    let playlist: Playlist

    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<RecentWatchHistoryRequest> private var recent: [DBWatchHistory]

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _recent = Query(RecentWatchHistoryRequest(playlistId: playlist.id, limit: 500), in: \.appDatabase)
    }

    private var watched: Set<String> { Set(recent.map { $0.streamId }) }
    private var unwatched: [VODWithCategory] { movies.filter { !watched.contains(String($0.stream.streamId)) } }

    var body: some View {
        TigerDiscoveryScaffold(title: "غير المشاهد", subtitle: "كل ما لم تشاهده بعد — \(unwatched.count) عمل.", icon: "eye.slash") {
            if unwatched.isEmpty {
                TigerInfoNote(text: "شاهدت كل شيء! لا توجد أعمال غير مشاهدة.", icon: "checkmark.seal", tint: TigerTheme.brandLight)
            } else {
                TigerPosterGrid(items: unwatched,
                                imageURL: { $0.stream.streamIcon.flatMap { URL(string: $0) } },
                                title: { $0.stream.name },
                                subtitle: { $0.categoryName },
                                badge: { $0.stream.rating },
                                action: { m in AnyView(MovieDetailView(playlist: playlist, movie: m.stream)) })
            }
        }
    }
}

// MARK: - الحلقات الجديدة

struct TigerNewEpisodesView: View {
    let playlist: Playlist

    @Query<SeriesRequest> private var series: [SeriesWithCategory]

    init(playlist: Playlist) {
        self.playlist = playlist
        _series = Query(SeriesRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    private var newest: [SeriesWithCategory] {
        series.sorted { ($0.series.lastModified ?? "") > ($1.series.lastModified ?? "") }.prefix(30).map { $0 }
    }

    var body: some View {
        TigerDiscoveryScaffold(title: "الحلقات الجديدة", subtitle: "أحدث المسلسلات المحدَّثة على السيرفر.", icon: "sparkles.tv") {
            TigerPosterGrid(items: newest,
                            imageURL: { $0.series.cover.flatMap { URL(string: $0) } },
                            title: { $0.series.name },
                            subtitle: { $0.categoryName },
                            badge: { $0.series.rating },
                            action: { s in AnyView(SeriesDetailView(playlist: playlist, series: s.series)) })
        }
    }
}
