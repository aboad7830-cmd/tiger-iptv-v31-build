//
//  FamilyAccessibility100.swift
//  Tiger IPTV
//
//  العائلة وإمكانية الوصول (46–50)
//

import SwiftUI
import Foundation
import Combine

// MARK: - 46 + 47) جدول وقت الشاشة وحد المشاهدة اليومي

struct TigerKidsSchedule: Codable, Equatable {
    var isEnabled: Bool = false
    var allowedStartHour: Int = 15
    var allowedEndHour: Int = 21
    var dailyLimitMinutes: Int = 90
    var blockWeekends: Bool = false

    func isWithinWindow(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = (weekday == 1 || weekday == 7)
        if blockWeekends, isWeekend { return false }
        let hour = calendar.component(.hour, from: date)
        if allowedStartHour <= allowedEndHour {
            return hour >= allowedStartHour && hour < allowedEndHour
        }
        // نافذة تعبر منتصف الليل
        return hour >= allowedStartHour || hour < allowedEndHour
    }
}

@MainActor
final class TigerKidsGuard: ObservableObject {
    static let shared = TigerKidsGuard()

    @Published var schedule: TigerKidsSchedule {
        didSet { persist() }
    }
    @Published private(set) var watchedMinutesToday: Int = 0
    @Published private(set) var isBlocked = false
    @Published private(set) var blockReason: String?

    private let defaults = UserDefaults.standard
    private let scheduleKey = "kids.schedule"
    private let usageKey = "kids.usage"
    private let usageDayKey = "kids.usageDay"

    private init() {
        if let data = defaults.data(forKey: scheduleKey),
           let decoded = try? JSONDecoder().decode(TigerKidsSchedule.self, from: data) {
            schedule = decoded
        } else {
            schedule = TigerKidsSchedule()
        }
        loadUsage()
        evaluate()
    }

    // MARK: تسجيل وقت المشاهدة

    func addWatchedMinute(_ minutes: Int = 1) {
        guard schedule.isEnabled else { return }
        rolloverIfNeeded()
        watchedMinutesToday += minutes
        defaults.set(watchedMinutesToday, forKey: usageKey)
        evaluate()
    }

    func resetToday() {
        watchedMinutesToday = 0
        defaults.set(0, forKey: usageKey)
        defaults.set(Self.dayStamp(), forKey: usageDayKey)
        evaluate()
    }

    /// يُستدعى قبل بدء التشغيل؛ يعيد سبب المنع إن وُجد.
    func evaluate(at date: Date = Date()) -> String? {
        guard schedule.isEnabled else {
            isBlocked = false
            blockReason = nil
            return nil
        }
        rolloverIfNeeded()

        if !schedule.isWithinWindow(date) {
            isBlocked = true
            blockReason = String(
                format: L("kids.block.schedule"),
                schedule.allowedStartHour,
                schedule.allowedEndHour
            )
            return blockReason
        }

        if schedule.dailyLimitMinutes > 0, watchedMinutesToday >= schedule.dailyLimitMinutes {
            isBlocked = true
            blockReason = String(format: L("kids.block.limit"), schedule.dailyLimitMinutes)
            return blockReason
        }

        isBlocked = false
        blockReason = nil
        return nil
    }

    var remainingMinutes: Int {
        max(0, schedule.dailyLimitMinutes - watchedMinutesToday)
    }

    var progress: Double {
        guard schedule.dailyLimitMinutes > 0 else { return 0 }
        return min(1, Double(watchedMinutesToday) / Double(schedule.dailyLimitMinutes))
    }

    private func rolloverIfNeeded() {
        let today = Self.dayStamp()
        if defaults.string(forKey: usageDayKey) != today {
            watchedMinutesToday = 0
            defaults.set(0, forKey: usageKey)
            defaults.set(today, forKey: usageDayKey)
        }
    }

    private func loadUsage() {
        let today = Self.dayStamp()
        if defaults.string(forKey: usageDayKey) == today {
            watchedMinutesToday = defaults.integer(forKey: usageKey)
        } else {
            watchedMinutesToday = 0
            defaults.set(today, forKey: usageDayKey)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(schedule) else { return }
        defaults.set(data, forKey: scheduleKey)
        evaluate()
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct TigerKidsBlockedView: View {
    let reason: String
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(TigerTheme.goldGradient)
            Text(L("kids.blocked.title"))
                .font(.title2.weight(.bold))
            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            if let onDismiss {
                Button(L("common.close"), action: onDismiss)
                    .buttonStyle(TigerSecondaryButtonStyle())
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

struct TigerKidsScheduleView: View {
    @ObservedObject private var guardModel = TigerKidsGuard.shared

    var body: some View {
        List {
            Section {
                Toggle(L("kids.enable"), isOn: Binding(
                    get: { guardModel.schedule.isEnabled },
                    set: { guardModel.schedule.isEnabled = $0 }
                ))
            } footer: {
                Text(L("kids.enable.footer"))
            }

            if guardModel.schedule.isEnabled {
                Section {
                    Stepper(value: Binding(
                        get: { guardModel.schedule.allowedStartHour },
                        set: { guardModel.schedule.allowedStartHour = $0 }
                    ), in: 0 ... 23) {
                        LabeledContent(L("kids.start"), value: String(format: "%02d:00", guardModel.schedule.allowedStartHour))
                    }
                    Stepper(value: Binding(
                        get: { guardModel.schedule.allowedEndHour },
                        set: { guardModel.schedule.allowedEndHour = $0 }
                    ), in: 0 ... 23) {
                        LabeledContent(L("kids.end"), value: String(format: "%02d:00", guardModel.schedule.allowedEndHour))
                    }
                    Toggle(L("kids.weekends"), isOn: Binding(
                        get: { guardModel.schedule.blockWeekends },
                        set: { guardModel.schedule.blockWeekends = $0 }
                    ))
                } header: {
                    Text(L("kids.window"))
                }

                Section {
                    Stepper(value: Binding(
                        get: { guardModel.schedule.dailyLimitMinutes },
                        set: { guardModel.schedule.dailyLimitMinutes = $0 }
                    ), in: 0 ... 480, step: 15) {
                        LabeledContent(
                            L("kids.limit"),
                            value: guardModel.schedule.dailyLimitMinutes == 0
                                ? L("kids.limit.none")
                                : "\(guardModel.schedule.dailyLimitMinutes) " + L("common.minutes")
                        )
                    }

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(L("kids.today"))
                            Spacer()
                            Text("\(guardModel.watchedMinutesToday) / \(guardModel.schedule.dailyLimitMinutes)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: guardModel.progress)
                            .tint(guardModel.progress > 0.85 ? .red : TigerTheme.gold)
                    }
                    .padding(.vertical, 2)

                    Button(L("kids.reset")) { guardModel.resetToday() }
                } header: {
                    Text(L("kids.daily"))
                } footer: {
                    Text(L("kids.daily.footer"))
                }
            }
        }
        .navigationTitle(L("kids.title"))
    }
}

// MARK: - 48) VoiceOver: تسميات وترتيب التركيز

struct TigerAccessibleLabel: ViewModifier {
    let label: String
    let hint: String?
    let value: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(Text(label))
            .accessibilityHint(Text(hint ?? ""))
            .accessibilityValue(Text(value ?? ""))
    }
}

extension View {
    func tigerAccessible(label: String, hint: String? = nil, value: String? = nil) -> some View {
        modifier(TigerAccessibleLabel(label: label, hint: hint, value: value))
    }

    /// يجعل العنصر يُقرأ كزر واحد بدل عدة عناصر منفصلة.
    func tigerMergeForVoiceOver(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityHint(Text(hint ?? ""))
            .accessibilityAddTraits(.isButton)
    }
}

/// ترتيب قراءة مخصّص لعناصر الشاشة.
struct TigerFocusOrder: ViewModifier {
    let index: Int

    func body(content: Content) -> some View {
        content.accessibilitySortPriority(Double(1000 - index))
    }
}

extension View {
    func tigerFocusOrder(_ index: Int) -> some View {
        modifier(TigerFocusOrder(index: index))
    }
}

// MARK: - 49) دعم Switch Control / اللمس المساعد

struct TigerSwitchControlFriendly: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .frame(minWidth: isEnabled ? 56 : nil, minHeight: isEnabled ? 56 : nil)
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    func tigerSwitchControlFriendly(_ isEnabled: Bool) -> some View {
        modifier(TigerSwitchControlFriendly(isEnabled: isEnabled))
    }
}

@MainActor
final class TigerAccessibilitySettings: ObservableObject {
    static let shared = TigerAccessibilitySettings()

    @Published var largeTargets: Bool {
        didSet { defaults.set(largeTargets, forKey: "a11y.largeTargets") }
    }
    @Published var extraContrast: Bool {
        didSet { defaults.set(extraContrast, forKey: "a11y.contrast") }
    }
    @Published var spokenChannelNames: Bool {
        didSet { defaults.set(spokenChannelNames, forKey: "a11y.spokenChannels") }
    }

    private let defaults = UserDefaults.standard

    private init() {
        largeTargets = defaults.object(forKey: "a11y.largeTargets") as? Bool ?? false
        extraContrast = defaults.object(forKey: "a11y.contrast") as? Bool ?? false
        spokenChannelNames = defaults.object(forKey: "a11y.spokenChannels") as? Bool ?? true
    }
}

// MARK: - 50) ترجمة واجهة على الجهاز (بدون شبكة)

@MainActor
final class TigerOnDeviceTranslator: ObservableObject {
    static let shared = TigerOnDeviceTranslator()

    @Published var targetLanguage: String {
        didSet {
            defaults.set(targetLanguage, forKey: "i18n.target")
            reloadGlossary()
        }
    }

    @Published private(set) var glossary: [String: String] = [:]

    private let defaults = UserDefaults.standard

    /// قاموس مدمج لمصطلحات الواجهة الأساسية (يعمل دون اتصال).
    private static let builtIn: [String: [String: String]] = [
        "ar": [
            "Home": "الرئيسية", "Live": "مباشر", "Movies": "أفلام", "Series": "مسلسلات",
            "Search": "بحث", "Settings": "الإعدادات", "Favorites": "المفضلة",
            "Play": "تشغيل", "Pause": "إيقاف مؤقت", "Downloads": "التنزيلات",
            "Guide": "الدليل", "Profile": "الملف الشخصي", "Add Playlist": "إضافة قائمة",
            "Continue Watching": "متابعة المشاهدة", "Retry": "إعادة المحاولة"
        ],
        "en": [
            "الرئيسية": "Home", "مباشر": "Live", "أفلام": "Movies", "مسلسلات": "Series",
            "بحث": "Search", "الإعدادات": "Settings", "المفضلة": "Favorites",
            "تشغيل": "Play", "إيقاف مؤقت": "Pause", "التنزيلات": "Downloads",
            "الدليل": "Guide", "الملف الشخصي": "Profile", "إضافة قائمة": "Add Playlist",
            "متابعة المشاهدة": "Continue Watching", "إعادة المحاولة": "Retry"
        ]
    ]

    private init() {
        targetLanguage = defaults.string(forKey: "i18n.target") ?? "ar"
        reloadGlossary()
    }

    func translate(_ text: String) -> String {
        glossary[text] ?? text
    }

    private func reloadGlossary() {
        glossary = Self.builtIn[targetLanguage] ?? [:]
    }

    var availableLanguages: [(code: String, name: String)] {
        [("ar", "العربية"), ("en", "English")]
    }
}

struct TigerAccessibilitySettingsView: View {
    @ObservedObject private var settings = TigerAccessibilitySettings.shared
    @ObservedObject private var translator = TigerOnDeviceTranslator.shared

    var body: some View {
        List {
            Section {
                Toggle(L("a11y.largeTargets"), isOn: $settings.largeTargets)
                Toggle(L("a11y.contrast"), isOn: $settings.extraContrast)
                Toggle(L("a11y.spokenChannels"), isOn: $settings.spokenChannelNames)
            } header: {
                Text(L("a11y.section"))
            } footer: {
                Text(L("a11y.footer"))
            }

            Section {
                Picker(L("a11y.language"), selection: $translator.targetLanguage) {
                    ForEach(translator.availableLanguages, id: \.code) { item in
                        Text(item.name).tag(item.code)
                    }
                }
                LabeledContent(L("a11y.sample"), value: translator.translate("Continue Watching"))
            } header: {
                Text(L("a11y.translate"))
            } footer: {
                Text(L("a11y.translate.footer"))
            }
        }
        .navigationTitle(L("a11y.title"))
    }
}
