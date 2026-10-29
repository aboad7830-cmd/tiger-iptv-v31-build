import SwiftUI

struct SearchView: View {
    let playlist: Playlist
    @Binding var searchText: String
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedFilter: SearchFilter = .all
    @ObservedObject private var featureRuntime = TigerFeatureRuntime.shared
    @State private var history: [String] = SearchHistoryStore.load()

    enum SearchFilter: String, CaseIterable {
        case all, live, movies, series

        var displayName: String {
            switch self {
            case .all:    return L("search.all")
            case .live:   return L("dashboard.live")
            case .movies: return L("dashboard.movies")
            case .series: return L("dashboard.series")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.displayName)
                                .font(.subheadline)
                                .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedFilter == filter ? Color.accentColor : Color(.systemGray5))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Divider()

            if debouncedQuery.count < 2 {
                if featureRuntime.isOn("f083"), !history.isEmpty {
                    SearchHistoryView(
                        history: history,
                        onPick: { searchText = $0 },
                        onClear: {
                            SearchHistoryStore.clear()
                            history = []
                        }
                    )
                } else {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.bottom, 8)
                    Text(L("search.min_chars"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                SearchResultsView(
                    playlist: playlist,
                    query: debouncedQuery,
                    filter: selectedFilter,
                    onSelectFilter: { selectedFilter = $0 }
                )
            }
        }
        .navigationTitle(L("search.title"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: TigerPlatform.searchPlacement, prompt: L("search.placeholder"))
        .onChange(of: searchText) { _, raw in
            debounceTask?.cancel()
            let q = raw.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { debouncedQuery = ""; return }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    debouncedQuery = q
                    // سجل البحث الذكي (f083).
                    if featureRuntime.isOn("f083") {
                        SearchHistoryStore.record(q)
                        history = SearchHistoryStore.load()
                    }
                }
            }
        }
        .onDisappear { debounceTask?.cancel() }
    }
}

// MARK: - Results

private struct SearchResult {
    enum Kind { case live(LiveStreamWithCategory), movie(VODWithCategory), series(SeriesWithCategory) }
    let kind: Kind
    var name: String {
        switch kind {
        case .live(let x): x.stream.name
        case .movie(let x): x.stream.name
        case .series(let x): x.series.name
        }
    }
    var categoryName: String {
        switch kind {
        case .live(let x): x.categoryName
        case .movie(let x): x.categoryName
        case .series(let x): x.categoryName
        }
    }
    var iconURL: URL? {
        switch kind {
        case .live(let x): x.stream.streamIcon.flatMap { URL(string: $0) }
        case .movie(let x): x.stream.streamIcon.flatMap { URL(string: $0) }
        case .series(let x): x.series.cover.flatMap { URL(string: $0) }
        }
    }
    var typeLabel: String {
        switch kind {
        case .live: L("dashboard.live")
        case .movie: L("stream.vod")
        case .series: L("stream.series")
        }
    }
    var typeIcon: String {
        switch kind {
        case .live: "tv"
        case .movie: "film"
        case .series: "play.tv"
        }
    }
}

private func search(_ q: String, in text: String) -> Bool {
    q.split(separator: " ").allSatisfy { text.localizedCaseInsensitiveContains($0) }
}

private struct SearchResultsView: View {
    let playlist: Playlist
    let query: String
    let filter: SearchView.SearchFilter
    let onSelectFilter: (SearchView.SearchFilter) -> Void

    @ObservedObject private var contentStore = PlaylistContentStore.shared
    @ObservedObject private var hiddenStore = HiddenCategoryStore.shared
    @ObservedObject private var featureRuntime = TigerFeatureRuntime.shared
    @EnvironmentObject private var playerOverlay: PlayerOverlayController

    @State private var liveResults: [LiveStreamWithCategory] = []
    @State private var movieResults: [VODWithCategory] = []
    @State private var seriesResults: [SeriesWithCategory] = []

    private var allLiveShown: Bool { filter == .live }
    private var allMoviesShown: Bool { filter == .movies }
    private var allSeriesShown: Bool { filter == .series }

    var body: some View {
        List {
            // Live
            if filter == .all || filter == .live {
                if !liveResults.isEmpty {
                    Section {
                        let visible = allLiveShown ? liveResults : Array(liveResults.prefix(4))
                        ForEach(visible) { item in
                            Button { playLive(item) } label: {
                                ResultRow(name: item.stream.name,
                                          subtitle: item.categoryName,
                                          iconURL: item.stream.streamIcon.flatMap { URL(string: $0) },
                                          typeIcon: "tv")
                            }
                            .buttonStyle(.plain)
                        }
                        if !allLiveShown && liveResults.count > 4 {
                            Button { onSelectFilter(.live) } label: {
                                Text(L("search.more_results_format", liveResults.count - 4))
                                    .font(.footnote).foregroundColor(.accentColor)
                            }
                        }
                    } header: { SectionLabel(title: L("dashboard.live"), count: liveResults.count, icon: "tv") }
                }
            }

            // Movies
            if filter == .all || filter == .movies {
                if !movieResults.isEmpty {
                    Section {
                        let visible = allMoviesShown ? movieResults : Array(movieResults.prefix(4))
                        ForEach(visible) { item in
                            NavigationLink {
                                MovieDetailView(playlist: playlist, movie: item.stream)
                            } label: {
                                ResultRow(name: item.stream.name,
                                          subtitle: item.categoryName,
                                          iconURL: item.stream.streamIcon.flatMap { URL(string: $0) },
                                          typeIcon: "film")
                            }
                        }
                        if !allMoviesShown && movieResults.count > 4 {
                            Button { onSelectFilter(.movies) } label: {
                                Text(L("search.more_results_format", movieResults.count - 4))
                                    .font(.footnote).foregroundColor(.accentColor)
                            }
                        }
                    } header: { SectionLabel(title: L("dashboard.movies"), count: movieResults.count, icon: "film") }
                }
            }

            // Series
            if filter == .all || filter == .series {
                if !seriesResults.isEmpty {
                    Section {
                        let visible = allSeriesShown ? seriesResults : Array(seriesResults.prefix(4))
                        ForEach(visible) { item in
                            NavigationLink {
                                SeriesDetailView(playlist: playlist, series: item.series)
                            } label: {
                                ResultRow(name: item.series.name,
                                          subtitle: item.categoryName,
                                          iconURL: item.series.cover.flatMap { URL(string: $0) },
                                          typeIcon: "play.tv")
                            }
                        }
                        if !allSeriesShown && seriesResults.count > 4 {
                            Button { onSelectFilter(.series) } label: {
                                Text(L("search.more_results_format", seriesResults.count - 4))
                                    .font(.footnote).foregroundColor(.accentColor)
                            }
                        }
                    } header: { SectionLabel(title: L("dashboard.series"), count: seriesResults.count, icon: "play.tv") }
                }
            }

            if liveResults.isEmpty && movieResults.isEmpty && seriesResults.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .listStyle(.insetGrouped)
        .task(id: query) { await runSearch() }
        .task(id: hiddenStore.version) { await runSearch() }
        .task(id: featureRuntime.revision) { await runSearch() }
    }

    private func runSearch() async {
        let live = contentStore.liveStreams
        let vod = contentStore.vodStreams
        let ser = contentStore.seriesItems
        let q = query
        let hiddenLive = hiddenStore.hiddenIds(playlistId: playlist.id, type: "live")
        let hiddenVod = hiddenStore.hiddenIds(playlistId: playlist.id, type: "vod")
        let hiddenSeries = hiddenStore.hiddenIds(playlistId: playlist.id, type: "series")

        // البحث الذكي (f076): مطابقة عربية/تركية مُطبّعة بدل المطابقة الحرفية.
        let smart = TigerFeatureRuntime.shared.isOn("f076")

        async let liveTask = Task.detached(priority: .userInitiated) {
            live.filter { item in
                !hiddenLive.contains(item.stream.categoryId ?? "") &&
                (smart ? CatalogTextSearch.matches(search: q, text: item.stream.name)
                       : search(q, in: item.stream.name))
            }
            .sorted { $0.stream.name.localizedCaseInsensitiveCompare($1.stream.name) == .orderedAscending }
        }.value
        async let vodTask = Task.detached(priority: .userInitiated) {
            vod.filter { item in
                !hiddenVod.contains(item.stream.categoryId ?? "") &&
                (smart ? CatalogTextSearch.matches(search: q, text: item.stream.name)
                       : search(q, in: item.stream.name))
            }
            .sorted { $0.stream.name.localizedCaseInsensitiveCompare($1.stream.name) == .orderedAscending }
        }.value
        async let serTask = Task.detached(priority: .userInitiated) {
            ser.filter { item in
                !hiddenSeries.contains(item.series.categoryId ?? "") &&
                (smart ? CatalogTextSearch.matches(search: q, text: item.series.name)
                       : search(q, in: item.series.name))
            }
            .sorted { $0.series.name.localizedCaseInsensitiveCompare($1.series.name) == .orderedAscending }
        }.value

        let (rawLive, rawVod, rawSeries) = await (liveTask, vodTask, serTask)
        guard !Task.isCancelled else { return }

        // تصفية/ترتيب عبر محرّك مزايا 200 (البالغون، الجودة، النوع، السنة، التقييم...).
        let runtime = TigerFeatureRuntime.shared
        liveResults = runtime.sortLive(runtime.filterLive(rawLive))
        movieResults = runtime.sortVOD(runtime.filterVOD(rawVod))
        seriesResults = runtime.sortSeries(runtime.filterSeries(rawSeries))
    }

    private func playLive(_ item: LiveStreamWithCategory) {
        let sections: [LiveChannelCategorySection] = {
            var seen = Set<String>()
            var ids: [String] = []
            for i in liveResults {
                let cid = i.stream.categoryId ?? "other"
                if seen.insert(cid).inserted { ids.append(cid) }
            }
            return ids.compactMap { cid -> LiveChannelCategorySection? in
                let streams = liveResults.filter { ($0.stream.categoryId ?? "other") == cid }.map(\.stream)
                guard let first = liveResults.first(where: { ($0.stream.categoryId ?? "other") == cid }) else { return nil }
                return LiveChannelCategorySection(id: cid, title: first.categoryName, streams: streams)
            }
        }()
        playerOverlay.present(playlistId: playlist.id) {
            LivePlayerShell(
                playlist: playlist,
                queue: liveResults.map(\.stream),
                sections: sections,
                initialStream: item.stream,
                initialHistory: nil,
                subtitle: nil
            )
        }
    }
}

private struct ResultRow: View {
    let name: String
    let subtitle: String
    let iconURL: URL?
    let typeIcon: String

    var body: some View {
        HStack(spacing: 12) {
            CachedImage(url: iconURL, width: 44, height: 44, iconName: typeIcon, loadProfile: .grid)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body).lineLimit(1)
                Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SectionLabel: View {
    let title: String
    let count: Int
    let icon: String
    var body: some View {
        Label("\(title) (\(count))", systemImage: icon)
    }
}

// MARK: - Search history (f083)

enum SearchHistoryStore {
    private static let key = "tiger.search.history"
    private static let limit = 10

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        var items = load()
        items.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        items.insert(trimmed, at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        UserDefaults.standard.set(items, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

private struct SearchHistoryView: View {
    let history: [String]
    let onPick: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(history, id: \.self) { term in
                    Button { onPick(term) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                            Text(term).foregroundColor(.primary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("سجل البحث")
                    Spacer()
                    Button("مسح") { onClear() }
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
