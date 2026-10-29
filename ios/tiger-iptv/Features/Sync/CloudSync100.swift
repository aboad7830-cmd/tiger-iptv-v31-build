//
//  CloudSync100.swift
//  Tiger IPTV
//
//  مزامنة سحابية بين أجهزة Apple (11–15)
//

import SwiftUI
import Foundation
import CryptoKit
import Combine

// MARK: - نموذج بيانات المزامنة

struct TigerSyncEnvelope: Codable, Equatable {
    var payload: [String: String]
    var updatedAt: Date
    var deviceName: String
    var schemaVersion: Int = 1
}

enum TigerSyncScope: String, Codable, CaseIterable, Identifiable {
    case playlists
    case favorites
    case resumePositions
    case settings
    case watchHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlists: return L("sync.scope.playlists")
        case .favorites: return L("sync.scope.favorites")
        case .resumePositions: return L("sync.scope.resume")
        case .settings: return L("sync.scope.settings")
        case .watchHistory: return L("sync.scope.history")
        }
    }

    var symbol: String {
        switch self {
        case .playlists: return "list.bullet.rectangle"
        case .favorites: return "star.fill"
        case .resumePositions: return "play.circle"
        case .settings: return "slider.horizontal.3"
        case .watchHistory: return "clock.arrow.circlepath"
        }
    }
}

// MARK: - 11 + 12 + 13) محرّك المزامنة (iCloud Key-Value + الأحدث يفوز)

@MainActor
final class TigerCloudSync: ObservableObject {
    static let shared = TigerCloudSync()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?
    @Published var enabledScopes: Set<TigerSyncScope> {
        didSet { persistScopes() }
    }

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private let scopesKey = "sync.enabledScopes"
    private let lastSyncKey = "sync.lastSync"
    private var observer: NSObjectProtocol?

    private init() {
        let raw = defaults.stringArray(forKey: scopesKey) ?? []
        let scopes = raw.compactMap(TigerSyncScope.init(rawValue:))
        enabledScopes = scopes.isEmpty ? Set(TigerSyncScope.allCases) : Set(scopes)
        lastSync = defaults.object(forKey: lastSyncKey) as? Date

        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleExternalChange(note) }
        }
        store.synchronize()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: الكتابة

    /// يرفع قاموسًا من القيم تحت نطاق معيّن مع بصمة زمنية.
    func push(_ payload: [String: String], scope: TigerSyncScope) {
        guard enabledScopes.contains(scope) else { return }
        let envelope = TigerSyncEnvelope(
            payload: payload,
            updatedAt: Date(),
            deviceName: Self.deviceName
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        store.set(data, forKey: "tiger.sync.\(scope.rawValue)")
        store.synchronize()
        lastSync = Date()
        defaults.set(lastSync, forKey: lastSyncKey)
    }

    /// يقرأ نطاقًا من iCloud ويعيد القاموس إن كان أحدث من المحلي.
    func pull(scope: TigerSyncScope, localUpdatedAt: Date?) -> [String: String]? {
        guard enabledScopes.contains(scope),
              let data = store.data(forKey: "tiger.sync.\(scope.rawValue)"),
              let envelope = try? JSONDecoder().decode(TigerSyncEnvelope.self, from: data) else {
            return nil
        }
        if let localUpdatedAt, envelope.updatedAt <= localUpdatedAt {
            return nil // 13) الأحدث يفوز: المحلي أحدث
        }
        return envelope.payload
    }

    /// مزامنة كاملة: يسحب كل النطاقات المفعّلة.
    func syncNow() async {
        isSyncing = true
        lastError = nil
        store.synchronize()
        for scope in enabledScopes {
            _ = pull(scope: scope, localUpdatedAt: nil)
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        lastSync = Date()
        defaults.set(lastSync, forKey: lastSyncKey)
        isSyncing = false
        HapticEngine.success()
    }

    /// يحل تعارضًا بين نسختين بنفس المفتاح: الأحدث يفوز، وعند التعادل يفوز المحلي.
    static func resolve(local: TigerSyncEnvelope, remote: TigerSyncEnvelope) -> TigerSyncEnvelope {
        remote.updatedAt > local.updatedAt ? remote : local
    }

    private func handleExternalChange(_ note: Notification) {
        guard let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        let changed = keys.filter { $0.hasPrefix("tiger.sync.") }
        guard !changed.isEmpty else { return }
        lastSync = Date()
        NotificationCenter.default.post(name: .tigerCloudSyncDidUpdate, object: nil)
    }

    private func persistScopes() {
        defaults.set(enabledScopes.map { $0.rawValue }, forKey: scopesKey)
    }

    static var deviceName: String {
        #if os(iOS)
        return TigerPlatform.displayName
        #else
        return Host.current().localizedName ?? "Apple Device"
        #endif
    }
}

extension Notification.Name {
    static let tigerCloudSyncDidUpdate = Notification.Name("tiger.sync.updated")
}

// MARK: - 14) Handoff: متابعة المشاهدة على جهاز آخر

@MainActor
enum TigerHandoff {
    static let activityType = "com.tigeriptv.app.watching"

    static func start(streamId: Int, playlistId: UUID, title: String, position: Double) {
        let activity = NSUserActivity(activityType: activityType)
        activity.title = title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.userInfo = [
            "streamId": streamId,
            "playlistId": playlistId.uuidString,
            "position": position
        ]
        activity.becomeCurrent()
    }

    static func stop() {
        NSUserActivity.deleteAllSavedUserActivities {}
    }

    struct ResumePayload: Equatable {
        let streamId: Int
        let playlistId: UUID
        let position: Double
    }

    static func parse(_ activity: NSUserActivity) -> ResumePayload? {
        guard activity.activityType == activityType,
              let info = activity.userInfo,
              let streamId = info["streamId"] as? Int,
              let raw = info["playlistId"] as? String,
              let playlistId = UUID(uuidString: raw) else { return nil }
        let position = info["position"] as? Double ?? 0
        return ResumePayload(streamId: streamId, playlistId: playlistId, position: position)
    }
}

// MARK: - 15) نسخة احتياطية أسبوعية مشفّرة

struct TigerBackupRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var fileName: String
    var byteCount: Int
    var isEncrypted: Bool
}

@MainActor
final class TigerBackupManager: ObservableObject {
    static let shared = TigerBackupManager()

    @Published private(set) var backups: [TigerBackupRecord] = []
    @Published private(set) var isWorking = false
    @Published private(set) var lastError: String?

    private let defaults = UserDefaults.standard
    private let indexKey = "backup.index"
    private let autoKey = "backup.autoWeekly"

    @Published var autoWeekly: Bool {
        didSet { defaults.set(autoWeekly, forKey: autoKey) }
    }

    private init() {
        autoWeekly = defaults.object(forKey: autoKey) as? Bool ?? true
        loadIndex()
    }

    private var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("TigerBackups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// ينشئ نسخة مشفّرة (AES-GCM) من ملف JSON يحتوي بيانات المستخدم.
    func createBackup(json: Data, passphrase: String) throws -> TigerBackupRecord {
        isWorking = true
        defer { isWorking = false }

        let key = SymmetricKey(data: SHA256.hash(data: Data(passphrase.utf8)))
        let sealed = try AES.GCM.seal(json, using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "TigerBackup", code: 1)
        }

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "tiger-backup-\(stamp).tgbak"
        let url = folder.appendingPathComponent(fileName)
        try combined.write(to: url, options: .atomic)

        let record = TigerBackupRecord(
            fileName: fileName,
            byteCount: combined.count,
            isEncrypted: true
        )
        backups.insert(record, at: 0)
        persistIndex()
        HapticEngine.success()
        return record
    }

    func restore(_ record: TigerBackupRecord, passphrase: String) throws -> Data {
        let url = folder.appendingPathComponent(record.fileName)
        let data = try Data(contentsOf: url)
        let key = SymmetricKey(data: SHA256.hash(data: Data(passphrase.utf8)))
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    func delete(_ record: TigerBackupRecord) {
        let url = folder.appendingPathComponent(record.fileName)
        try? FileManager.default.removeItem(at: url)
        backups.removeAll { $0.id == record.id }
        persistIndex()
    }

    /// ينفّذ نسخة أسبوعية تلقائية إن مرّ سبعة أيام على آخر نسخة.
    func runAutoBackupIfNeeded(json: Data, passphrase: String) {
        guard autoWeekly else { return }
        if let newest = backups.first, Date().timeIntervalSince(newest.createdAt) < 7 * 86400 {
            return
        }
        _ = try? createBackup(json: json, passphrase: passphrase)
    }

    var totalBytes: Int { backups.reduce(0) { $0 + $1.byteCount } }

    private func loadIndex() {
        guard let data = defaults.data(forKey: indexKey),
              let decoded = try? JSONDecoder().decode([TigerBackupRecord].self, from: data) else { return }
        backups = decoded
    }

    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(backups) else { return }
        defaults.set(data, forKey: indexKey)
    }
}

// MARK: - شاشة المزامنة

struct TigerCloudSyncSettingsView: View {
    @ObservedObject private var sync = TigerCloudSync.shared
    @ObservedObject private var backups = TigerBackupManager.shared
    @State private var passphrase = ""
    @State private var showingBackups = false

    var body: some View {
        List {
            Section {
                ForEach(TigerSyncScope.allCases) { scope in
                    Toggle(isOn: Binding(
                        get: { sync.enabledScopes.contains(scope) },
                        set: { value in
                            if value { sync.enabledScopes.insert(scope) }
                            else { sync.enabledScopes.remove(scope) }
                        }
                    )) {
                        Label(scope.title, systemImage: scope.symbol)
                    }
                }
            } header: {
                Text(L("sync.scopes"))
            } footer: {
                Text(L("sync.scopes.footer"))
            }

            Section {
                Button {
                    Task { await sync.syncNow() }
                } label: {
                    HStack {
                        Label(L("sync.now"), systemImage: "arrow.triangle.2.circlepath.icloud")
                        Spacer()
                        if sync.isSyncing { ProgressView() }
                    }
                }
                .disabled(sync.isSyncing)

                if let lastSync = sync.lastSync {
                    LabeledContent(L("sync.last"), value: lastSync.formatted(date: .abbreviated, time: .shortened))
                }
                if let error = sync.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text(L("sync.status"))
            }

            Section {
                Toggle(L("backup.auto"), isOn: $backups.autoWeekly)
                SecureField(L("backup.passphrase"), text: $passphrase)
                Button {
                    showingBackups = true
                } label: {
                    Label(L("backup.list"), systemImage: "externaldrive.badge.timemachine")
                }
                LabeledContent(L("backup.size"), value: ByteCountFormatter.string(fromByteCount: Int64(backups.totalBytes), countStyle: .file))
            } header: {
                Text(L("backup.title"))
            } footer: {
                Text(L("backup.footer"))
            }
        }
        .navigationTitle(L("sync.title"))
        .sheet(isPresented: $showingBackups) {
            TigerBackupsListView()
        }
    }
}

struct TigerBackupsListView: View {
    @ObservedObject private var backups = TigerBackupManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if backups.backups.isEmpty {
                    TigerEmptyState(
                        icon: "externaldrive",
                        title: L("backup.empty.title"),
                        message: L("backup.empty.message")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(backups.backups) { record in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.body.weight(.medium))
                            HStack(spacing: 6) {
                                Image(systemName: record.isEncrypted ? "lock.fill" : "lock.open")
                                    .font(.caption2)
                                Text(ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file))
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet { backups.delete(backups.backups[index]) }
                    }
                }
            }
            .navigationTitle(L("backup.list"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}
