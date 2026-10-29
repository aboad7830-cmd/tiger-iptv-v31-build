//
//  AppleIntegration100.swift
//  Tiger IPTV
//
//  تكامل عميق مع منظومة Apple (16–20)
//

import SwiftUI
import Foundation
import AppIntents

#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit)
import ActivityKit
import GRDB
#endif

// MARK: - 16) الويدجت: لقطة مشتركة عبر App Group

struct TigerWidgetSnapshot: Codable, Equatable {
    var playlistName: String
    var liveCount: Int
    var vodCount: Int
    var seriesCount: Int
    var continueTitle: String?
    var continueProgress: Double
    var continueStreamId: Int?
    var updatedAt: Date

    static let empty = TigerWidgetSnapshot(
        playlistName: "",
        liveCount: 0,
        vodCount: 0,
        seriesCount: 0,
        continueTitle: nil,
        continueProgress: 0,
        continueStreamId: nil,
        updatedAt: .distantPast
    )
}

enum TigerWidgetBridge {
    static let appGroup = "group.com.tigeriptv.app"
    static let snapshotKey = "widget.snapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func write(_ snapshot: TigerWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    static func read() -> TigerWidgetSnapshot {
        guard let data = defaults?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(TigerWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    /// يحدّث اللقطة من قاعدة البيانات (يُستدعى بعد أي استيراد أو مشاهدة).
    @MainActor
    static func refresh(playlist: Playlist?) async {
        var snapshot = TigerWidgetSnapshot.empty
        snapshot.playlistName = playlist?.name ?? ""
        snapshot.updatedAt = Date()

        if let playlist {
            let id = playlist.id.uuidString
            let counts = try? await AppDatabase.shared.read { db -> (Int, Int, Int) in
                let live = try DBLiveStream.filter(Column("playlistId") == id).fetchCount(db)
                let vod = try DBVODStream.filter(Column("playlistId") == id).fetchCount(db)
                let series = try DBSeries.filter(Column("playlistId") == id).fetchCount(db)
                return (live, vod, series)
            }
            if let counts {
                snapshot.liveCount = counts.0
                snapshot.vodCount = counts.1
                snapshot.seriesCount = counts.2
            }
        }

        if let last = try? await AppDatabase.shared.read { db in
            try DBWatchHistory.order(Column("lastWatchedAt").desc).fetchOne(db)
        } {
            snapshot.continueTitle = last.title
            snapshot.continueProgress = last.durationMs > 0
                ? min(1, max(0, Double(last.lastTimeMs) / Double(last.durationMs)))
                : 0
            snapshot.continueStreamId = Int(last.streamId)
        }

        write(snapshot)
    }
}

// MARK: - 17) النشاط الحيّ (Live Activity) لمباراة/برنامج مباشر

#if canImport(ActivityKit)
struct TigerLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var startedAt: Date
        var score: String?
    }

    var channelName: String
    var channelLogoURL: String?
}

@MainActor
final class TigerLiveActivityManager {
    static let shared = TigerLiveActivityManager()
    private var activity: Activity<TigerLiveActivityAttributes>?

    private init() {}

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(channelName: String, logoURL: String?, title: String, subtitle: String) {
        guard isSupported else { return }
        let attributes = TigerLiveActivityAttributes(channelName: channelName, channelLogoURL: logoURL)
        let state = TigerLiveActivityAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            startedAt: Date(),
            score: nil
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(4 * 3600))
            )
        } catch {
            Log.error("LiveActivity", "start failed: \(error.localizedDescription)")
        }
    }

    func update(title: String, subtitle: String, score: String?) async {
        guard let activity else { return }
        let state = TigerLiveActivityAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            startedAt: Date(),
            score: score
        )
        await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(3600)))
    }

    func end() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}
#endif

// MARK: - 18 + 19) Siri و Shortcuts (App Intents)

struct TigerOpenSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "فتح البحث"
    static var description = IntentDescription("يفتح شاشة البحث الموحّد في Tiger IPTV.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "نص البحث")
    var query: String?

    init() {}

    init(query: String?) { self.query = query }

    func perform() async throws -> some IntentResult {
        var info: [String: String] = [:]
        if let query, !query.isEmpty { info["query"] = query }
        NotificationCenter.default.post(name: .tigerOpenSearch, object: nil, userInfo: info)
        return .result()
    }
}

struct TigerOpenPlaylistIntent: AppIntent {
    static var title: LocalizedStringResource = "فتح قائمة تشغيل"
    static var description = IntentDescription("يفتح قائمة تشغيل محدّدة بالاسم.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "اسم القائمة")
    var name: String?

    init() {}
    init(name: String?) { self.name = name }

    func perform() async throws -> some IntentResult {
        var info: [String: String] = [:]
        if let name { info["name"] = name }
        NotificationCenter.default.post(name: .tigerOpenPlaylist, object: nil, userInfo: info)
        return .result()
    }
}

struct TigerResumeWatchingIntent: AppIntent {
    static var title: LocalizedStringResource = "متابعة المشاهدة"
    static var description = IntentDescription("يستأنف آخر محتوى كنت تشاهده.")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .tigerQuickAction, object: nil, userInfo: ["action": "resume"])
        return .result()
    }
}

struct TigerAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TigerOpenSearchIntent(),
            phrases: [
                "ابحث في \(.applicationName)",
                "Search \(.applicationName)"
            ],
            shortTitle: "بحث",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: TigerResumeWatchingIntent(),
            phrases: [
                "تابع المشاهدة في \(.applicationName)",
                "Resume \(.applicationName)"
            ],
            shortTitle: "متابعة",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: TigerOpenPlaylistIntent(),
            phrases: [
                "افتح قائمتي في \(.applicationName)",
                "Open playlist in \(.applicationName)"
            ],
            shortTitle: "قائمة",
            systemImageName: "list.bullet"
        )
    }
}

// MARK: - 20) نموذج تصفّح صوتي لـ CarPlay / الشاشات الخارجية

struct TigerAudioBrowseItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let artworkURL: String?
    let isPlayable: Bool
}

struct TigerAudioBrowseSection: Identifiable, Hashable {
    let id: String
    let title: String
    let items: [TigerAudioBrowseItem]
}

@MainActor
enum TigerAudioBrowseBuilder {
    /// يبني أقسامًا مبسّطة (بدون صور ثقيلة) مناسبة لشاشة السيارة.
    static func sections(playlistId: UUID, limit: Int = 20) async -> [TigerAudioBrowseSection] {
        var result: [TigerAudioBrowseSection] = []

        let live = (try? await AppDatabase.shared.read { db in
            try DBLiveStream
                .filter(Column("playlistId") == playlistId.uuidString)
                .order(Column("sortIndex"))
                .limit(limit)
                .fetchAll(db)
        }) ?? []
        if !live.isEmpty {
            result.append(
                TigerAudioBrowseSection(
                    id: "live",
                    title: L("carplay.live"),
                    items: live.map {
                        TigerAudioBrowseItem(
                            id: "live-\($0.streamId)",
                            title: $0.name,
                            subtitle: L("carplay.live"),
                            artworkURL: $0.streamIcon,
                            isPlayable: true
                        )
                    }
                )
            )
        }

        let vod = (try? await AppDatabase.shared.read { db in
            try DBVODStream
                .filter(Column("playlistId") == playlistId.uuidString)
                .order(Column("sortIndex"))
                .limit(limit)
                .fetchAll(db)
        }) ?? []
        if !vod.isEmpty {
            result.append(
                TigerAudioBrowseSection(
                    id: "movies",
                    title: L("carplay.movies"),
                    items: vod.map {
                        TigerAudioBrowseItem(
                            id: "vod-\($0.streamId)",
                            title: $0.name,
                            subtitle: nil,
                            artworkURL: $0.streamIcon,
                            isPlayable: true
                        )
                    }
                )
            )
        }

        return result
    }
}

// MARK: - لوحة التكامل

struct TigerAppleIntegrationView: View {
    @State private var snapshot = TigerWidgetBridge.read()
    @State private var liveSupported = false
    @State private var lastRefresh = Date()

    var body: some View {
        List {
            Section {
                LabeledContent(L("widget.live"), value: "\(snapshot.liveCount)")
                LabeledContent(L("widget.movies"), value: "\(snapshot.vodCount)")
                LabeledContent(L("widget.series"), value: "\(snapshot.seriesCount)")
                if let title = snapshot.continueTitle {
                    LabeledContent(L("widget.continue"), value: title)
                }
                Button {
                    Task {
                        await TigerWidgetBridge.refresh(playlist: nil)
                        snapshot = TigerWidgetBridge.read()
                        lastRefresh = Date()
                    }
                } label: {
                    Label(L("widget.refresh"), systemImage: "arrow.clockwise")
                }
            } header: {
                Text(L("widget.title"))
            } footer: {
                Text(L("widget.footer"))
            }

            Section {
                LabeledContent(L("liveactivity.supported"), value: liveSupported ? L("common.yes") : L("common.no"))
                Text(L("liveactivity.footer")).font(.caption).foregroundStyle(.secondary)
            } header: {
                Text(L("liveactivity.title"))
            }

            Section {
                Label(L("siri.search"), systemImage: "magnifyingglass")
                Label(L("siri.resume"), systemImage: "play.circle")
                Label(L("siri.playlist"), systemImage: "list.bullet")
            } header: {
                Text(L("siri.title"))
            } footer: {
                Text(L("siri.footer"))
            }

            Section {
                Label(L("carplay.live"), systemImage: "car.fill")
                Label(L("carplay.movies"), systemImage: "film.fill")
            } header: {
                Text(L("carplay.title"))
            } footer: {
                Text(L("carplay.footer"))
            }
        }
        .navigationTitle(L("apple.integration"))
        .onAppear {
            snapshot = TigerWidgetBridge.read()
            #if canImport(ActivityKit)
            liveSupported = TigerLiveActivityManager.shared.isSupported
            #endif
        }
    }
}
