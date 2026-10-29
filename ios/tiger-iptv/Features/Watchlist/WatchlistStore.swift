import Foundation
import GRDB
import Combine

/// A movie or series saved for later.
struct WatchlistItem: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: String
    var playlistId: String
    var kind: String            // "vod" | "series"
    var contentId: Int
    var title: String
    var posterURL: String?
    var rating: String?
    var addedAt: Date

    static let databaseTableName = "watchlistItem"

    init(
        id: String = UUID().uuidString,
        playlistId: String,
        kind: String,
        contentId: Int,
        title: String,
        posterURL: String? = nil,
        rating: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.playlistId = playlistId
        self.kind = kind
        self.contentId = contentId
        self.title = title
        self.posterURL = posterURL
        self.rating = rating
        self.addedAt = addedAt
    }
}

/// Local "watch later" list, persisted in SQLite.
@MainActor
final class WatchlistStore: ObservableObject {
    static let shared = WatchlistStore()

    @Published private(set) var items: [WatchlistItem] = []
    @Published private(set) var isLoading = false

    private var currentPlaylistId: String?

    private init() {}

    func load(playlistId: UUID) async {
        currentPlaylistId = playlistId.uuidString
        isLoading = true
        do {
            let rows = try await AppDatabase.shared.read { db in
                try WatchlistItem
                    .filter(Column("playlistId") == playlistId.uuidString)
                    .order(Column("addedAt").desc)
                    .fetchAll(db)
            }
            items = rows
        } catch {
            Log.error("Watchlist", "load failed: \(error)")
            items = []
        }
        isLoading = false
    }

    func contains(kind: String, contentId: Int, playlistId: UUID) -> Bool {
        items.contains {
            $0.kind == kind &&
            $0.contentId == contentId &&
            $0.playlistId == playlistId.uuidString
        }
    }

    @discardableResult
    func toggle(
        kind: String,
        contentId: Int,
        title: String,
        posterURL: String?,
        rating: String?,
        playlistId: UUID
    ) async -> Bool {
        if let existing = items.first(where: {
            $0.kind == kind && $0.contentId == contentId && $0.playlistId == playlistId.uuidString
        }) {
            await remove(existing)
            return false
        }

        let item = WatchlistItem(
            playlistId: playlistId.uuidString,
            kind: kind,
            contentId: contentId,
            title: title,
            posterURL: posterURL,
            rating: rating
        )

        do {
            try await AppDatabase.shared.write { db in
                try item.insert(db, onConflict: .ignore)
            }
            items.insert(item, at: 0)
        } catch {
            Log.error("Watchlist", "insert failed: \(error)")
        }
        return true
    }

    func remove(_ item: WatchlistItem) async {
        do {
            _ = try await AppDatabase.shared.write { db in
                try item.delete(db)
            }
            items.removeAll { $0.id == item.id }
        } catch {
            Log.error("Watchlist", "delete failed: \(error)")
        }
    }

    func clear(playlistId: UUID) async {
        do {
            _ = try await AppDatabase.shared.write { db in
                try WatchlistItem
                    .filter(Column("playlistId") == playlistId.uuidString)
                    .deleteAll(db)
            }
            items.removeAll { $0.playlistId == playlistId.uuidString }
        } catch {
            Log.error("Watchlist", "clear failed: \(error)")
        }
    }
}
