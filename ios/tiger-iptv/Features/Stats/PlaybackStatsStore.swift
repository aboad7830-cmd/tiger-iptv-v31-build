import Foundation
import GRDB
import Combine

/// سجل إحصائي لكل جلسة تشغيل: ماذا شوهد، وكم دقيقة، وعلى أي جهاز.
struct PlaybackStat: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: UUID
    var playlistId: UUID
    /// live / vod / series
    var kind: String
    var contentId: String
    var title: String
    /// إجمالي الثواني المشاهدة.
    var secondsWatched: Double
    var startedAt: Date
    var lastUpdatedAt: Date

    static let databaseTableName = "playbackStat"

    init(
        id: UUID = UUID(),
        playlistId: UUID,
        kind: String,
        contentId: String,
        title: String,
        secondsWatched: Double = 0,
        startedAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.playlistId = playlistId
        self.kind = kind
        self.contentId = contentId
        self.title = title
        self.secondsWatched = secondsWatched
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

/// ملخّص إحصاءات المشاهدة.
struct PlaybackSummary {
    var totalSeconds: Double = 0
    var sessions: Int = 0
    var byKind: [String: Double] = [:]
    var topTitles: [(title: String, seconds: Double)] = []

    var totalHoursText: String {
        let hours = totalSeconds / 3600
        return String(format: "%.1f", hours)
    }
}

/// يجمع إحصاءات المشاهدة ويكتبها دورياً إلى قاعدة البيانات.
@MainActor
final class PlaybackStatsStore: ObservableObject {
    static let shared = PlaybackStatsStore()

    @Published private(set) var summary = PlaybackSummary()
    @Published private(set) var recent: [PlaybackStat] = []

    private var currentSession: PlaybackStat?
    private var ticker: Task<Void, Never>?

    private init() {}

    // MARK: - الجلسة

    func beginSession(playlistId: UUID, kind: String, contentId: String, title: String) {
        endSession()
        currentSession = PlaybackStat(
            playlistId: playlistId,
            kind: kind,
            contentId: contentId,
            title: title
        )
        startTicker()
    }

    func pauseSession() {
        ticker?.cancel()
        ticker = nil
        flush()
    }

    func resumeSession() {
        guard currentSession != nil, ticker == nil else { return }
        startTicker()
    }

    func endSession() {
        ticker?.cancel()
        ticker = nil
        flush()
        currentSession = nil
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.currentSession?.secondsWatched += 5
                    self?.currentSession?.lastUpdatedAt = Date()
                }
            }
        }
    }

    private func flush() {
        guard let session = currentSession, session.secondsWatched >= 5 else { return }
        Task {
            do {
                try await AppDatabase.shared.write { db in
                    try session.save(db)
                }
            } catch {
                Log.error("PlaybackStats", "flush failed: \(error)")
            }
        }
    }

    // MARK: - القراءة

    func loadSummary(playlistId: UUID) async {
        do {
            let rows = try await AppDatabase.shared.read { db in
                try PlaybackStat
                    .filter(Column("playlistId") == playlistId.uuidString)
                    .order(Column("lastUpdatedAt").desc)
                    .fetchAll(db)
            }
            recent = Array(rows.prefix(30))

            var result = PlaybackSummary()
            result.sessions = rows.count
            for row in rows {
                result.totalSeconds += row.secondsWatched
                result.byKind[row.kind, default: 0] += row.secondsWatched
            }
            let grouped = Dictionary(grouping: rows, by: \.title)
                .mapValues { $0.reduce(0) { $0 + $1.secondsWatched } }
            result.topTitles = grouped
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { (title: $0.key, seconds: $0.value) }
            summary = result
        } catch {
            Log.error("PlaybackStats", "load failed: \(error)")
        }
    }

    func clearAll(playlistId: UUID) async {
        do {
            _ = try await AppDatabase.shared.write { db in
                try PlaybackStat
                    .filter(Column("playlistId") == playlistId.uuidString)
                    .deleteAll(db)
            }
            summary = PlaybackSummary()
            recent = []
        } catch {
            Log.error("PlaybackStats", "clear failed: \(error)")
        }
    }
}
