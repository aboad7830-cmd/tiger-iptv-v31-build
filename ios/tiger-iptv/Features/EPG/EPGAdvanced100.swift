//
//  EPGAdvanced100.swift
//  Tiger IPTV
//
//  مزايا الدليل الإلكتروني المتقدمة (26–30)
//

import SwiftUI
import Foundation
import UserNotifications
import Combine

// MARK: - 26) إشعار قبل بدء البرنامج

@MainActor
final class ProgramReminderScheduler: ObservableObject {
    static let shared = ProgramReminderScheduler()

    @Published private(set) var scheduledIds: Set<String> = []

    private let defaults = UserDefaults.standard
    private let storageKey = "epg.reminders"
    private let leadMinutes = 5

    private init() {
        scheduledIds = Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    func isScheduled(_ program: EpgProgram) -> Bool {
        scheduledIds.contains(Self.key(program))
    }

    func toggle(_ program: EpgProgram) async {
        if isScheduled(program) {
            cancel(program)
        } else {
            await schedule(program)
        }
    }

    func schedule(_ program: EpgProgram) async {
        let fireDate = program.start.addingTimeInterval(-Double(leadMinutes) * 60)
        guard fireDate > Date() else {
            ToastCenter.shared.show(L("epg.reminder.tooLate"), style: .warning)
            return
        }

        let granted = await requestAuthorization()
        guard granted else {
            ToastCenter.shared.show(L("epg.reminder.denied"), style: .error)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = program.title
        content.body = String(
            format: L("epg.reminder.body"),
            program.channelId,
            leadMinutes
        )
        content.sound = .default
        content.userInfo = ["programId": program.id, "channelId": program.channelId]

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.key(program),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            scheduledIds.insert(Self.key(program))
            persist()
            HapticEngine.success()
            ToastCenter.shared.show(L("epg.reminder.set"), style: .success)
        } catch {
            Log.error("EPG", "reminder add failed: \(error.localizedDescription)")
            ToastCenter.shared.show(L("epg.reminder.failed"), style: .error)
        }
    }

    func cancel(_ program: EpgProgram) {
        let id = Self.key(program)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        scheduledIds.remove(id)
        persist()
        HapticEngine.selection()
    }

    func cancelAll() {
        let ids = scheduledIds.map { $0 }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        scheduledIds.removeAll()
        persist()
    }

    private func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    private func persist() {
        defaults.set(Array(scheduledIds), forKey: storageKey)
    }

    static func key(_ program: EpgProgram) -> String {
        "epg.reminder.\(program.id)"
    }
}

// MARK: - 27 + 28) قواعد التسجيل (مسلسل / أسبوعي متكرر)

enum TigerRecordingKind: String, Codable, CaseIterable, Identifiable {
    case single
    case series
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return L("rec.kind.single")
        case .series: return L("rec.kind.series")
        case .weekly: return L("rec.kind.weekly")
        }
    }

    var symbol: String {
        switch self {
        case .single: return "record.circle"
        case .series: return "rectangle.stack.badge.plus"
        case .weekly: return "calendar.badge.clock"
        }
    }
}

struct TigerRecordingRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var playlistId: UUID
    var channelId: String
    var channelName: String
    var matchTitle: String
    var kind: TigerRecordingKind
    var startPaddingSeconds: Double = 120
    var endPaddingSeconds: Double = 300
    var keepOnlyNewEpisodes: Bool = true
    var createdAt: Date = Date()
    var isEnabled: Bool = true

    var normalizedTitle: String { ChannelNameNormalizer.key(matchTitle) }
}

@MainActor
final class RecordingRuleStore: ObservableObject {
    static let shared = RecordingRuleStore()

    @Published private(set) var rules: [TigerRecordingRule] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "epg.recordingRules"

    private init() { load() }

    func add(_ rule: TigerRecordingRule) {
        rules.append(rule)
        persist()
        HapticEngine.success()
        ToastCenter.shared.show(L("rec.rule.added"), style: .success)
    }

    func remove(_ rule: TigerRecordingRule) {
        rules.removeAll { $0.id == rule.id }
        persist()
    }

    func setEnabled(_ rule: TigerRecordingRule, enabled: Bool) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index].isEnabled = enabled
        persist()
    }

    func rules(for playlistId: UUID) -> [TigerRecordingRule] {
        rules.filter { $0.playlistId == playlistId }
    }

    /// يبحث في برامج القناة عن أي برنامج يطابق قاعدة مسلسل.
    func matches(program: EpgProgram) -> TigerRecordingRule? {
        let key = ChannelNameNormalizer.key(program.title)
        return rules.first { rule in
            guard rule.isEnabled, rule.playlistId.uuidString == program.playlistId else { return false }
            guard rule.channelId == program.channelId else { return false }
            return key.contains(rule.normalizedTitle) || rule.normalizedTitle.contains(key)
        }
    }

    /// يحوّل برنامجًا مطابقًا إلى فترة تسجيل مع الهوامش.
    func window(for program: EpgProgram, rule: TigerRecordingRule) -> ClosedRange<Date> {
        let start = program.start.addingTimeInterval(-rule.startPaddingSeconds)
        let end = program.end.addingTimeInterval(rule.endPaddingSeconds)
        return start ... max(start, end)
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TigerRecordingRule].self, from: data) else { return }
        rules = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

struct TigerRecordingRuleEditor: View {
    let program: EpgProgram
    let playlistId: UUID
    var channelName: String

    @Environment(\.dismiss) private var dismiss
    @State private var kind: TigerRecordingKind = .single
    @State private var startPadding: Double = 2
    @State private var endPadding: Double = 5
    @State private var onlyNew = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(L("rec.program"), value: program.title)
                    LabeledContent(L("rec.channel"), value: channelName)
                    LabeledContent(L("rec.time"), value: Self.timeRange(program))
                }

                Section {
                    Picker(L("rec.kind"), selection: $kind) {
                        ForEach(TigerRecordingKind.allCases) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text(L("rec.kind"))
                } footer: {
                    Text(L("rec.kind.footer"))
                }

                Section {
                    stepperRow(L("rec.padding.start"), value: $startPadding, range: 0 ... 15)
                    stepperRow(L("rec.padding.end"), value: $endPadding, range: 0 ... 60)
                    if kind != .single {
                        Toggle(L("rec.onlyNew"), isOn: $onlyNew)
                    }
                } header: {
                    Text(L("rec.padding"))
                }
            }
            .navigationTitle(L("rec.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        RecordingRuleStore.shared.add(
                            TigerRecordingRule(
                                playlistId: playlistId,
                                channelId: program.channelId,
                                channelName: channelName,
                                matchTitle: program.title,
                                kind: kind,
                                startPaddingSeconds: startPadding * 60,
                                endPaddingSeconds: endPadding * 60,
                                keepOnlyNewEpisodes: onlyNew
                            )
                        )
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stepperRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) " + L("common.minutes"))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func timeRange(_ program: EpgProgram) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: program.start)) – \(formatter.string(from: program.end))"
    }
}

struct TigerRecordingRulesView: View {
    @ObservedObject private var store = RecordingRuleStore.shared

    var body: some View {
        List {
            if store.rules.isEmpty {
                TigerEmptyState(
                    icon: "record.circle",
                    title: L("rec.empty.title"),
                    message: L("rec.empty.message")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.rules) { rule in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: rule.kind.symbol)
                            .foregroundStyle(TigerTheme.gold)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.matchTitle).font(.body.weight(.semibold))
                            Text("\(rule.channelName) · \(rule.kind.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { store.setEnabled(rule, enabled: $0) }
                        ))
                        .labelsHidden()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet { store.remove(store.rules[index]) }
                }
            }
        }
        .navigationTitle(L("rec.rules"))
    }
}

// MARK: - 29) دليل XMLTV يعمل بدون اتصال

@MainActor
final class OfflineGuideStore: ObservableObject {
    static let shared = OfflineGuideStore()

    @Published private(set) var lastRefresh: Date?
    @Published private(set) var programCount: Int = 0
    @Published private(set) var isOffline = false

    private let defaults = UserDefaults.standard

    private init() {
        if let stamp = defaults.object(forKey: "epg.lastRefresh") as? Date {
            lastRefresh = stamp
        }
        programCount = defaults.integer(forKey: "epg.cachedCount")
    }

    func recordRefresh(programs: Int) {
        lastRefresh = Date()
        programCount = programs
        defaults.set(lastRefresh, forKey: "epg.lastRefresh")
        defaults.set(programs, forKey: "epg.cachedCount")
    }

    func markOffline(_ value: Bool) {
        isOffline = value
    }

    var freshnessLabel: String {
        guard let lastRefresh else { return L("epg.offline.never") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastRefresh, relativeTo: Date())
    }

    var canBrowseOffline: Bool { programCount > 0 }
}

struct TigerOfflineGuideBanner: View {
    @ObservedObject private var store = OfflineGuideStore.shared

    var body: some View {
        if store.isOffline, store.canBrowseOffline {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(TigerTheme.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("epg.offline.title")).font(.footnote.weight(.semibold))
                    Text(String(format: L("epg.offline.detail"), store.programCount, store.freshnessLabel))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(Spacing.sm)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .padding(.horizontal, Spacing.md)
        }
    }
}

// MARK: - 30) كشف المباريات الرياضية من عناوين الدليل

struct TigerSportsMatch: Identifiable, Hashable {
    let id: String
    let program: EpgProgram
    let home: String
    let away: String
    let competition: String?

    var title: String { "\(home) × \(away)" }

    static func == (lhs: TigerSportsMatch, rhs: TigerSportsMatch) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum TigerSportsDetector {
    static let keywords: [String] = [
        "vs", "v ", "×", "x ", " ضد ", "مباراة", "match", "derby", "ديربي",
        "final", "نهائي", "semi", "نصف النهائي", "cup", "كأس", "league", "دوري",
        "champions", "أبطال", "premier", "laliga", "serie a", "bundesliga",
        "nba", "nfl", "ufc", "f1", "grand prix", "tennis", "كرة القدم", "كرة السلة"
    ]

    static let competitions: [String: String] = [
        "champions": "دوري أبطال أوروبا",
        "premier": "الدوري الإنجليزي",
        "laliga": "الدوري الإسباني",
        "serie a": "الدوري الإيطالي",
        "bundesliga": "الدوري الألماني",
        "world cup": "كأس العالم",
        "nba": "NBA",
        "ufc": "UFC",
        "f1": "الفورمولا 1"
    ]

    static func isSports(_ program: EpgProgram) -> Bool {
        let category = (program.category ?? "").lowercased()
        if category.contains("sport") || category.contains("رياض") { return true }
        let haystack = "\(program.title) \(program.subtitle ?? "") \(program.desc ?? "")".lowercased()
        return keywords.contains { haystack.contains($0) }
    }

    static func match(from program: EpgProgram) -> TigerSportsMatch? {
        guard isSports(program) else { return nil }
        let title = program.title
        let separators = [" vs ", " VS ", " vs. ", " × ", " ضد ", " - "]
        var parts: [String] = []
        for separator in separators where title.contains(separator) {
            parts = title.components(separatedBy: separator)
            if parts.count >= 2 { break }
        }
        guard parts.count >= 2 else {
            return TigerSportsMatch(
                id: program.id,
                program: program,
                home: title,
                away: "",
                competition: competition(for: program)
            )
        }
        return TigerSportsMatch(
            id: program.id,
            program: program,
            home: parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            away: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            competition: competition(for: program)
        )
    }

    static func competition(for program: EpgProgram) -> String? {
        let haystack = "\(program.title) \(program.desc ?? "")".lowercased()
        for (needle, name) in competitions where haystack.contains(needle) {
            return name
        }
        return program.category
    }

    static func upcoming(in programs: [EpgProgram], within hours: Double = 72) -> [TigerSportsMatch] {
        let limit = Date().addingTimeInterval(hours * 3600)
        return programs
            .filter { $0.end > Date() && $0.start < limit }
            .compactMap(match(from:))
            .sorted { $0.program.start < $1.program.start }
    }
}

struct TigerSportsMatchCard: View {
    let match: TigerSportsMatch

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 2) {
                Text(Self.dayLabel(match.program.start))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(TigerTheme.gold)
                Text(Self.timeLabel(match.program.start))
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                if let competition = match.competition, !competition.isEmpty {
                    Text(competition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if match.program.isLive() {
                Text(L("badge.live"))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - شاشة المباريات

struct TigerSportsGuideView: View {
    let playlistId: UUID
    @StateObject private var service = EPGService.shared
    @State private var matches: [TigerSportsMatch] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matches.isEmpty {
                TigerEmptyState(
                    icon: "sportscourt",
                    title: L("sports.empty.title"),
                    message: L("sports.empty.message")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(matches) { match in
                            TigerSportsMatchCard(match: match)
                        }
                    }
                    .padding(Spacing.md)
                }
            }
        }
        .navigationTitle(L("sports.title"))
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        let channels = await service.channels(playlistId: playlistId)
        var collected: [EpgProgram] = []
        for channel in channels.prefix(80) {
            let programs = await service.programs(
                playlistId: playlistId,
                channelId: channel.channelId,
                from: Date(),
                to: Date().addingTimeInterval(72 * 3600)
            )
            collected.append(contentsOf: programs)
        }
        matches = TigerSportsDetector.upcoming(in: collected)
        isLoading = false
    }
}
