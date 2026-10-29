//
//  TigerPlusLibrary.swift
//  Tiger IPTV
//
//  حزمة v3.0 — المكتبة: قوائم مخصّصة، تقييم شخصي، تصدير/استيراد، وتتبّع الإكمال.
//

import SwiftUI
import Combine
import GRDB
import GRDBQuery

// MARK: - مخزن القوائم المخصّصة

struct TigerCustomList: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var itemKeys: [String] = []   // "vod:123" / "series:456"
    var createdAt: Date = Date()
}

@MainActor
final class TigerCustomListStore: ObservableObject {
    static let shared = TigerCustomListStore()
    @Published private(set) var lists: [TigerCustomList] = []
    private let key = "tiger.customLists.v3"

    private init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TigerCustomList].self, from: data) else {
            lists = []
            return
        }
        lists = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func create(name: String) {
        lists.append(TigerCustomList(name: name))
        persist()
    }

    func delete(_ list: TigerCustomList) {
        lists.removeAll { $0.id == list.id }
        persist()
    }

    func toggle(key itemKey: String, in list: TigerCustomList) {
        guard let idx = lists.firstIndex(where: { $0.id == list.id }) else { return }
        if let existing = lists[idx].itemKeys.firstIndex(of: itemKey) {
            lists[idx].itemKeys.remove(at: existing)
        } else {
            lists[idx].itemKeys.append(itemKey)
        }
        persist()
    }
}

// MARK: - القوائم المخصّصة

struct TigerCustomPlaylistsView: View {
    let playlist: Playlist

    @StateObject private var store = TigerCustomListStore.shared
    @Query<VODStreamsRequest> private var movies: [VODWithCategory]
    @Query<SeriesRequest> private var series: [SeriesWithCategory]
    @State private var newName = ""
    @State private var showCreate = false

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
        _series = Query(SeriesRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    var body: some View {
        TigerPlusScreen(title: "القوائم المخصّصة", subtitle: "أنشئ قوائمك الخاصة واجمع فيها ما تحب.", icon: "folder.badge.plus") {
            TigerSettingsCard(title: "قائمة جديدة", subtitle: nil, icon: "plus.circle", tint: TigerTheme.orange) {
                HStack(spacing: 8) {
                    TextField("اسم القائمة…", text: $newName).textFieldStyle(.roundedBorder)
                    Button("إنشاء") {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.create(name: trimmed)
                        newName = ""
                    }
                    .buttonStyle(.borderedProminent).tint(TigerTheme.orange)
                }
            }

            if store.lists.isEmpty {
                TigerInfoNote(text: "لا توجد قوائم بعد. أنشئ أول قائمة بالأعلى.", icon: "folder", tint: TigerTheme.orange)
            } else {
                ForEach(store.lists) { list in
                    TigerSettingsCard(title: list.name, subtitle: "\(list.itemKeys.count) عنصر", icon: "folder.fill", tint: TigerTheme.brandLight) {
                        VStack(alignment: .leading, spacing: 8) {
                            if list.itemKeys.isEmpty {
                                Text("فارغة — أضف أفلامًا ومسلسلات من الأزرار أدناه.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text(list.itemKeys.joined(separator: "، "))
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                            }
                            HStack {
                                Menu {
                                    ForEach(movies.prefix(20)) { m in
                                        Button(m.stream.name) {
                                            store.toggle(key: "vod:\(m.stream.streamId)", in: list)
                                        }
                                    }
                                } label: {
                                    Label("إضافة فيلم", systemImage: "film")
                                }
                                Menu {
                                    ForEach(series.prefix(20)) { s in
                                        Button(s.series.name) {
                                            store.toggle(key: "series:\(s.series.seriesId)", in: list)
                                        }
                                    }
                                } label: {
                                    Label("إضافة مسلسل", systemImage: "tv")
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    store.delete(list)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - التقييم الشخصي

@MainActor
final class TigerPersonalRatingStore: ObservableObject {
    static let shared = TigerPersonalRatingStore()
    @Published private(set) var ratings: [String: Int] = [:]
    private let key = "tiger.personalRatings.v3"

    private init() {
        if let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] {
            ratings = dict
        }
    }

    func rating(for k: String) -> Int { ratings[k] ?? 0 }

    func set(_ value: Int, for k: String) {
        if value == 0 { ratings.removeValue(forKey: k) } else { ratings[k] = value }
        UserDefaults.standard.set(ratings, forKey: key)
    }
}

struct TigerPersonalRatingsView: View {
    let playlist: Playlist

    @StateObject private var store = TigerPersonalRatingStore.shared
    @Query<VODStreamsRequest> private var movies: [VODWithCategory]

    init(playlist: Playlist) {
        self.playlist = playlist
        _movies = Query(VODStreamsRequest(playlistId: playlist.id, categoryId: nil, searchText: nil), in: \.appDatabase)
    }

    var body: some View {
        TigerPlusScreen(title: "تقييمك الشخصي", subtitle: "قيّم الأفلام بنجومك الخاصة — مستقلًا عن تقييم السيرفر.", icon: "star.circle") {
            if movies.isEmpty {
                TigerInfoNote(text: "لا توجد أفلام لتقييمها.", icon: "film", tint: TigerTheme.orange)
            } else {
                ForEach(movies.prefix(40)) { m in
                    TigerSettingsCard(title: m.stream.name, subtitle: m.categoryName, icon: "film", tint: TigerTheme.gold) {
                        TigerStarRatingRow(key: "vod:\(m.stream.streamId)", store: store)
                    }
                }
            }
        }
    }
}

// MARK: - تصدير واستيراد

struct TigerDataTransferView: View {
    let playlist: Playlist

    @State private var exportText: String = ""
    @State private var importText: String = ""
    @State private var message: String?

    var body: some View {
        TigerPlusScreen(title: "تصدير واستيراد", subtitle: "انقل قوائمك وتقييماتك وإعداداتك بين أجهزة Apple.", icon: "arrow.up.arrow.down.circle") {
            TigerSettingsCard(title: "تصدير", subtitle: "انسخ النص التالي واحفظه أو شاركه.", icon: "square.and.arrow.up", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        exportText = buildExport()
                        message = "تم إنشاء نسخة التصدير."
                    } label: {
                        Label("إنشاء نسخة تصدير", systemImage: "doc.on.doc").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(TigerTheme.orange)

                    if !exportText.isEmpty {
                        TextEditor(text: .constant(exportText))
                            .font(.caption2)
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
                        #if os(iOS)
                        ShareLink(item: exportText) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.bordered)
                        #endif
                    }
                }
            }

            TigerSettingsCard(title: "استيراد", subtitle: "الصق نص النسخة لاستعادة بياناتك.", icon: "square.and.arrow.down", tint: TigerTheme.brandLight) {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $importText)
                        .font(.caption2)
                        .frame(height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
                    Button {
                        importData()
                    } label: {
                        Label("استيراد", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(TigerTheme.brandLight)
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let message {
                TigerInfoNote(text: message, icon: "checkmark.circle", tint: TigerTheme.brandLight)
            }
        }
    }

    private func buildExport() -> String {
        let lists = TigerCustomListStore.shared.lists
        let ratings = TigerPersonalRatingStore.shared.ratings
        let payload: [String: Any] = [
            "version": 3,
            "playlist": playlist.name,
            "lists": lists.map { ["name": $0.name, "items": $0.itemKeys] },
            "ratings": ratings
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    private func importData() {
        guard let data = importText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            message = "صيغة غير صالحة."
            return
        }
        if let ratings = obj["ratings"] as? [String: Int] {
            for (k, v) in ratings { TigerPersonalRatingStore.shared.set(v, for: k) }
        }
        if let lists = obj["lists"] as? [[String: Any]] {
            for l in lists {
                if let name = l["name"] as? String {
                    TigerCustomListStore.shared.create(name: name)
                }
            }
        }
        message = "تم الاستيراد بنجاح."
    }
}

// MARK: - تتبّع الإكمال

struct TigerCompletionTrackingView: View {
    let playlist: Playlist

    @Query<RecentWatchHistoryRequest> private var history: [DBWatchHistory]

    init(playlist: Playlist) {
        self.playlist = playlist
        _history = Query(RecentWatchHistoryRequest(playlistId: playlist.id, limit: 200), in: \.appDatabase)
    }

    private var completed: [DBWatchHistory] {
        history.filter { watchedRatio($0) >= 0.9 }
    }

    private var inProgress: [DBWatchHistory] {
        history.filter { item in
            let ratio: Double = watchedRatio(item)
            return ratio >= 0.05 && ratio < 0.9
        }
    }

    private func watchedRatio(_ item: DBWatchHistory) -> Double {
        guard item.durationMs > 0 else { return 0 }
        let duration = Double(item.durationMs)
        let watched = Double(item.lastTimeMs)
        return watched / duration
    }

    var body: some View {
        TigerPlusScreen(
            title: "تتبّع الإكمال",
            subtitle: "تابع ما أكملته وما لا يزال قيد المشاهدة.",
            icon: "checkmark.circle"
        ) {
            summaryCard
            inProgressCard
            completedCard
            emptyNote
        }
    }

    private var summaryCard: some View {
        TigerSettingsCard(title: "ملخّص", subtitle: nil, icon: "chart.pie", tint: TigerTheme.orange) {
            VStack(spacing: 8) {
                TigerInfoRow(title: "مكتمل", value: "\(completed.count)", icon: "checkmark.seal.fill", tint: TigerTheme.brandLight)
                Divider()
                TigerInfoRow(title: "قيد المشاهدة", value: "\(inProgress.count)", icon: "hourglass", tint: TigerTheme.gold)
                Divider()
                TigerInfoRow(title: "الإجمالي", value: "\(history.count)", icon: "list.bullet", tint: TigerTheme.orange)
            }
        }
    }

    @ViewBuilder
    private var inProgressCard: some View {
        if !inProgress.isEmpty {
            TigerSettingsCard(title: "قيد المشاهدة", subtitle: nil, icon: "play.circle", tint: TigerTheme.gold) {
                VStack(spacing: 0) {
                    ForEach(Array(inProgress.enumerated()), id: \.element.id) { index, h in
                        inProgressRow(h, index: index)
                    }
                }
            }
        }
    }

    private func inProgressRow(_ h: DBWatchHistory, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CachedImage(
                    url: h.imageURL.flatMap { URL(string: $0) },
                    width: 40, height: 56, cornerRadius: 6,
                    contentMode: .fill, iconName: "film"
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(h.title).font(.subheadline).lineLimit(1)
                    ProgressView(value: progress(of: h)).tint(TigerTheme.gold)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            if index < inProgress.count - 1 { Divider() }
        }
    }

    private func progress(of h: DBWatchHistory) -> Double {
        let total = Double(max(h.durationMs, 1))
        return Double(h.lastTimeMs) / total
    }

    @ViewBuilder
    private var completedCard: some View {
        if !completed.isEmpty {
            TigerSettingsCard(title: "مكتمل", subtitle: nil, icon: "checkmark.seal", tint: TigerTheme.brandLight) {
                VStack(spacing: 0) {
                    ForEach(Array(completed.enumerated()), id: \.element.id) { index, h in
                        completedRow(h, index: index)
                    }
                }
            }
        }
    }

    private func completedRow(_ h: DBWatchHistory, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(TigerTheme.brandLight)
                Text(h.title).font(.subheadline).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            if index < completed.count - 1 { Divider() }
        }
    }

    @ViewBuilder
    private var emptyNote: some View {
        if history.isEmpty {
            TigerInfoNote(text: "لا يوجد سجل مشاهدة بعد.", icon: "tray", tint: TigerTheme.orange)
        }
    }
}

// MARK: - صف التقييم بالنجوم (مستخرج لتسريع التحقق النوعي)

struct TigerStarRatingRow: View {
    let key: String
    @ObservedObject var store: TigerPersonalRatingStore

    private var current: Int { store.rating(for: key) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    store.set(current == star ? 0 : star, for: key)
                } label: {
                    Image(systemName: star <= current ? "star.fill" : "star")
                        .foregroundStyle(TigerTheme.gold)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(current == 0 ? "لم تُقيّم" : "\(current)/5")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
