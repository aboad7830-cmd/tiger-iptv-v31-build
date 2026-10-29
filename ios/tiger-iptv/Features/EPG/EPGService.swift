import Foundation
import GRDB
import Combine

/// Downloads, parses and stores XMLTV guides, and answers "what's on now / next" queries.
@MainActor
final class EPGService: ObservableObject {
    static let shared = EPGService()

    @Published private(set) var isRefreshing = false
    @Published private(set) var progress: String?
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private init() {}

    // MARK: - URL

    func guideURL(for playlist: Playlist) -> URL? {
        switch playlist.kind {
        case .xtream:
            var base = playlist.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            while base.hasSuffix("/") { base.removeLast() }
            guard var components = URLComponents(string: base + "/xmltv.php") else { return nil }
            components.queryItems = [
                URLQueryItem(name: "username", value: playlist.username),
                URLQueryItem(name: "password", value: playlist.password)
            ]
            return components.url

        case .m3u:
            guard let raw = playlist.m3uEpgURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            return URL(string: raw)
        }
    }

    func hasGuideSource(_ playlist: Playlist) -> Bool {
        guideURL(for: playlist) != nil
    }

    // MARK: - Refresh

    @discardableResult
    func refresh(playlist: Playlist) async throws -> Int {
        guard let url = guideURL(for: playlist) else {
            throw EPGError.noSource
        }

        isRefreshing = true
        progress = L("epg.progress.downloading")
        lastError = nil
        defer {
            isRefreshing = false
            progress = nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("TIGER IPTV", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw EPGError.http(http.statusCode)
        }
        guard !data.isEmpty else { throw EPGError.emptyGuide }

        progress = L("epg.progress.parsing")

        let playlistId = playlist.id.uuidString
        let parsed = EPGXMLTVParser.parse(data: data, playlistId: playlistId)

        progress = L("epg.progress.saving")

        let horizonStart = Date().addingTimeInterval(-24 * 3600)
        let horizonEnd = Date().addingTimeInterval(8 * 24 * 3600)

        let storedPrograms = parsed.programs.filter { $0.end > horizonStart && $0.start < horizonEnd }

        try await AppDatabase.shared.write { db in
            // Replace the guide for this playlist.
            _ = try EpgProgram.filter(Column("playlistId") == playlistId).deleteAll(db)
            _ = try EpgChannel.filter(Column("playlistId") == playlistId).deleteAll(db)

            for channel in parsed.channels {
                try channel.insert(db, onConflict: .replace)
            }
            for program in storedPrograms {
                try program.insert(db, onConflict: .replace)
            }
        }

        lastUpdated = Date()
        return storedPrograms.count
    }

    // MARK: - Queries

    func channels(playlistId: UUID) async -> [EpgChannel] {
        (try? await AppDatabase.shared.read { db in
            try EpgChannel
                .filter(Column("playlistId") == playlistId.uuidString)
                .order(Column("displayName"))
                .fetchAll(db)
        }) ?? []
    }

    func programs(
        playlistId: UUID,
        channelId: String,
        from: Date = Date().addingTimeInterval(-3600),
        to: Date = Date().addingTimeInterval(12 * 3600)
    ) async -> [EpgProgram] {
        (try? await AppDatabase.shared.read { db in
            try EpgProgram
                .filter(Column("playlistId") == playlistId.uuidString)
                .filter(Column("channelId") == channelId)
                .filter(Column("end") > from)
                .filter(Column("start") < to)
                .order(Column("start"))
                .fetchAll(db)
        }) ?? []
    }

    /// Returns (current, next) for a channel.
    func nowAndNext(playlistId: UUID, channelId: String) async -> (EpgProgram?, EpgProgram?) {
        let now = Date()
        let items = await programs(
            playlistId: playlistId,
            channelId: channelId,
            from: now.addingTimeInterval(-6 * 3600),
            to: now.addingTimeInterval(6 * 3600)
        )
        let current = items.first { $0.isLive(at: now) }
        let next = items.first { $0.start > now }
        return (current, next)
    }

    /// Removes guide rows older than 48 hours for every playlist.
    func pruneOldPrograms() async {
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        _ = try? await AppDatabase.shared.write { db in
            try EpgProgram.filter(Column("end") < cutoff).deleteAll(db)
        }
    }

    func programCount(playlistId: UUID) async -> Int {
        (try? await AppDatabase.shared.read { db in
            try EpgProgram.filter(Column("playlistId") == playlistId.uuidString).fetchCount(db)
        }) ?? 0
    }
}

enum EPGError: LocalizedError {
    case noSource
    case emptyGuide
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .noSource:
            return L("epg.error.no_source")
        case .emptyGuide:
            return L("epg.error.empty")
        case .http(let code):
            return L("epg.error.http", code)
        }
    }
}
