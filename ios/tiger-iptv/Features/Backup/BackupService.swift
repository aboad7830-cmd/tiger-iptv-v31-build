import Foundation
import GRDB
import SwiftUI
import UniformTypeIdentifiers
import Combine

/// نسخة احتياطية قابلة للنقل بين الأجهزة: الاشتراكات + المفضلة + قائمة المشاهدة + الإعدادات.
struct TigerBackup: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var appVersion: String
    var playlists: [Playlist]
    var favorites: [BackupFavorite]
    var watchlist: [WatchlistItem]
    var profiles: [Profile]
    var settings: [String: String]

    struct BackupFavorite: Codable {
        var streamId: Int
        var playlistId: UUID
        var type: String
        var createdAt: Date
    }
}

/// خدمة التصدير والاستيراد.
@MainActor
final class BackupService: ObservableObject {
    static let shared = BackupService()

    @Published private(set) var isWorking = false
    @Published private(set) var lastError: String?

    private init() {}

    // MARK: - التصدير

    func makeBackup() async throws -> Data {
        isWorking = true
        defer { isWorking = false }

        let snapshot = try await AppDatabase.shared.read { db -> (playlists: [Playlist], favorites: [TigerBackup.BackupFavorite], watchlist: [WatchlistItem], profiles: [Profile]) in
            let playlists = try Playlist.fetchAll(db)
            let favorites = try DBFavorite.fetchAll(db).map {
                TigerBackup.BackupFavorite(streamId: $0.streamId, playlistId: $0.playlistId, type: $0.type, createdAt: $0.createdAt)
            }
            let watchlist = try WatchlistItem.fetchAll(db)
            let profiles = try Profile.fetchAll(db)
            return (playlists, favorites, watchlist, profiles)
        }

        var settings: [String: String] = [:]
        let keys = [
            "app.theme", "app.accent", "app.selected_language", "app.splashEnabled",
            "epg.enabled", "player.sleepTimerDefaultMinutes", "parental.kidsMode",
            "parental.hideAdult", "parental.lockOnLaunch"
        ]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                settings[key] = "\(value)"
            }
        }

        let backup = TigerBackup(
            appVersion: Bundle.main.appVersion,
            playlists: snapshot.playlists,
            favorites: snapshot.favorites,
            watchlist: snapshot.watchlist,
            profiles: snapshot.profiles,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// يكتب النسخة إلى ملف مؤقت ويعيد رابطه للمشاركة.
    func exportToFile() async throws -> URL {
        let data = try await makeBackup()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let name = "TIGER-Backup-\(formatter.string(from: Date())).tigerbackup"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - الاستيراد

    struct ImportResult {
        var playlists: Int
        var favorites: Int
        var watchlist: Int
        var profiles: Int
    }

    @discardableResult
    func importBackup(from url: URL) async throws -> ImportResult {
        isWorking = true
        defer { isWorking = false }

        let data = try Data(contentsOf: url)
        return try await importBackup(data: data)
    }

    @discardableResult
    func importBackup(data: Data) async throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(TigerBackup.self, from: data)

        let result = try await AppDatabase.shared.write { db -> ImportResult in
            var playlistCount = 0
            for playlist in backup.playlists {
                if try Playlist.fetchOne(db, key: playlist.id) == nil {
                    try playlist.insert(db)
                    playlistCount += 1
                }
            }

            var favoriteCount = 0
            for fav in backup.favorites {
                let exists = try DBFavorite
                    .filter(Column("playlistId") == fav.playlistId.uuidString)
                    .filter(Column("streamId") == fav.streamId)
                    .filter(Column("type") == fav.type)
                    .fetchCount(db) > 0
                if !exists {
                    try DBFavorite(streamId: fav.streamId, playlistId: fav.playlistId, type: fav.type, createdAt: fav.createdAt).insert(db)
                    favoriteCount += 1
                }
            }

            var watchCount = 0
            for item in backup.watchlist {
                if try WatchlistItem.fetchOne(db, key: item.id) == nil {
                    try item.insert(db)
                    watchCount += 1
                }
            }

            var profileCount = 0
            for profile in backup.profiles {
                if try Profile.fetchOne(db, key: profile.id) == nil {
                    try profile.insert(db)
                    profileCount += 1
                }
            }

            return ImportResult(
                playlists: playlistCount,
                favorites: favoriteCount,
                watchlist: watchCount,
                profiles: profileCount
            )
        }

        for (key, value) in backup.settings {
            UserDefaults.standard.set(value, forKey: key)
        }

        return result
    }
}

// MARK: - شاشة النسخ الاحتياطي

struct BackupRestoreView: View {
    @StateObject private var service = BackupService.shared
    @State private var shareURL: URL?
    @State private var showingShare = false
    @State private var showingImporter = false
    @State private var message: String?
    @State private var showingMessage = false
    @State private var confirmRestore = false

    var body: some View {
        ZStack {
            TigerAuroraBackground()

            ScrollView {
                VStack(spacing: Spacing.md) {
                    infoCard
                    exportButton
                    importButton
                }
                .padding(Spacing.lg)
            }

            if service.isWorking {
                ProgressView().tint(.white)
                    .padding(Spacing.xl)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(.ultraThinMaterial))
            }
        }
        .navigationTitle(L("settings.backup"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShare) {
            if let shareURL { ShareSheet(items: [shareURL]) }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data, .json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                Task {
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    await performImport(url)
                }
            case .failure(let error):
                message = error.localizedDescription
                showingMessage = true
            }
        }
        .alert(L("common.done"), isPresented: $showingMessage) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(L("backup.info.title"), systemImage: "externaldrive.badge.checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TigerTheme.ink)
            Text(L("backup.info.body"))
                .font(.caption)
                .foregroundStyle(TigerTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(.ultraThinMaterial))
    }

    private var exportButton: some View {
        Button {
            Task { await performExport() }
        } label: {
            Label(L("backup.export"), systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(TigerTheme.brandGradient))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(service.isWorking)
    }

    private var importButton: some View {
        Button {
            showingImporter = true
        } label: {
            Label(L("backup.import"), systemImage: "square.and.arrow.down")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(.ultraThinMaterial))
                .foregroundStyle(TigerTheme.ink)
        }
        .buttonStyle(.plain)
        .disabled(service.isWorking)
    }

    private func performExport() async {
        do {
            shareURL = try await service.exportToFile()
            showingShare = true
        } catch {
            message = error.localizedDescription
            showingMessage = true
        }
    }

    private func performImport(_ url: URL) async {
        do {
            let result = try await service.importBackup(from: url)
            message = String(
                format: L("backup.import.result"),
                result.playlists, result.favorites, result.watchlist, result.profiles
            )
            showingMessage = true
        } catch {
            message = error.localizedDescription
            showingMessage = true
        }
    }
}
