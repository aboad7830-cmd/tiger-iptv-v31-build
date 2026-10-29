import Foundation
import GRDB

/// v2 schema additions.
///
/// Every migration is additive and idempotent-friendly: no existing table is dropped
/// or rewritten, so upgrading an installed build keeps all playlists, favourites,
/// history and downloads intact.
enum TigerMigrations {

    static func register(in migrator: inout DatabaseMigrator) {

        // MARK: Watchlist (movies + series the user wants to watch later)
        migrator.registerMigration("v2_addWatchlist") { db in
            try db.create(table: "watchlistItem", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("playlistId", .text).notNull()
                t.column("kind", .text).notNull()          // "vod" | "series"
                t.column("contentId", .integer).notNull()  // streamId / seriesId
                t.column("title", .text).notNull()
                t.column("posterURL", .text)
                t.column("rating", .text)
                t.column("addedAt", .datetime).notNull()
            }
            try db.create(
                index: "idx_watchlist_playlist",
                on: "watchlistItem",
                columns: ["playlistId", "addedAt"],
                ifNotExists: true
            )
            try db.create(
                index: "idx_watchlist_unique",
                on: "watchlistItem",
                columns: ["playlistId", "kind", "contentId"],
                unique: true,
                ifNotExists: true
            )
        }

        // MARK: Profiles (family members with their own preferences)
        migrator.registerMigration("v2_addProfiles") { db in
            try db.create(table: "profile", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("avatar", .text).notNull().defaults(to: "tiger")
                t.column("isKids", .boolean).notNull().defaults(to: false)
                t.column("pinHash", .text)
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "profilePlaylist", ifNotExists: true) { t in
                t.column("profileId", .text).notNull()
                t.column("playlistId", .text).notNull()
                t.primaryKey(["profileId", "playlistId"])
            }
        }

        // MARK: EPG (XMLTV guide)
        migrator.registerMigration("v2_addEPG") { db in
            try db.create(table: "epgChannel", ifNotExists: true) { t in
                t.column("playlistId", .text).notNull()
                t.column("channelId", .text).notNull()
                t.column("displayName", .text).notNull()
                t.column("iconURL", .text)
                t.primaryKey(["playlistId", "channelId"])
            }

            try db.create(table: "epgProgram", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("playlistId", .text).notNull()
                t.column("channelId", .text).notNull()
                t.column("title", .text).notNull()
                t.column("subtitle", .text)
                t.column("desc", .text)
                t.column("category", .text)
                t.column("start", .datetime).notNull()
                t.column("end", .datetime).notNull()
                t.column("iconURL", .text)
                t.column("episodeNum", .text)
            }
            try db.create(
                index: "idx_epgProgram_channel_start",
                on: "epgProgram",
                columns: ["playlistId", "channelId", "start"],
                ifNotExists: true
            )
            try db.create(
                index: "idx_epgProgram_window",
                on: "epgProgram",
                columns: ["playlistId", "start", "end"],
                ifNotExists: true
            )
        }

        // MARK: Catch-up / archive bookkeeping
        migrator.registerMigration("v2_addCatchup") { db in
            try db.alter(table: "liveStream") { t in
                t.add(column: "tvArchive", .integer).defaults(to: 0)
                t.add(column: "tvArchiveDuration", .integer).defaults(to: 0)
            }
        }

        // MARK: Recordings (DVR metadata; files live in Application Support)
        migrator.registerMigration("v2_addRecordings") { db in
            try db.create(table: "recording", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("playlistId", .text).notNull()
                t.column("channelId", .integer)
                t.column("title", .text).notNull()
                t.column("channelName", .text)
                t.column("scheduledStart", .datetime)
                t.column("scheduledEnd", .datetime)
                t.column("state", .text).notNull().defaults(to: "scheduled")
                t.column("filePath", .text)
                t.column("sizeBytes", .integer)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(
                index: "idx_recording_playlist",
                on: "recording",
                columns: ["playlistId", "createdAt"],
                ifNotExists: true
            )
        }

        // MARK: Playback statistics (local only, opt-in)
        migrator.registerMigration("v2_addPlaybackStats") { db in
            try db.create(table: "playbackStat", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("playlistId", .text).notNull()
                t.column("kind", .text).notNull()          // live | vod | series | m3u
                t.column("contentId", .text)
                t.column("title", .text)
                t.column("startedAt", .datetime).notNull()
                t.column("secondsWatched", .double).notNull().defaults(to: 0)
                t.column("lastUpdatedAt", .datetime).notNull()
            }
            try db.create(
                index: "idx_playbackStat_playlist",
                on: "playbackStat",
                columns: ["playlistId", "startedAt"],
                ifNotExists: true
            )
        }

        // MARK: Generic key/value settings (per playlist overrides, feature flags)
        migrator.registerMigration("v2_addUserSettings") { db in
            try db.create(table: "userSetting", ifNotExists: true) { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text)
                t.column("updatedAt", .datetime).notNull()
            }
        }
    }
}
