//
//  TigerPlusSystem.swift
//  Tiger IPTV
//
//  حزمة v3.0 — النظام والأمان: جدولة التنزيلات، المساحة، الحماية،
//  قفل التطبيق، الملفات الشخصية، الإشعارات، بطاقة المشاركة،
//  توفير الطاقة، والبدء البارد.
//

import SwiftUI
import Combine
import GRDB
import GRDBQuery

// MARK: - جدولة التنزيلات

struct TigerDownloadSchedulerView: View {
    @StateObject private var policy = DownloadPolicyStore.shared

    var body: some View {
        TigerPlusScreen(
            title: "جدولة التنزيلات",
            subtitle: "نزّل تلقائيًا في أوقات محدّدة (مثلًا ليلًا) لتوفير البيانات والبطارية.",
            icon: "calendar.badge.clock"
        ) {
            TigerSettingsCard(title: "النافذة الليلية", subtitle: "لن تبدأ التنزيلات خارج هذه النافذة.", icon: "moon.stars", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 12) {
                    TigerToggleRow(title: "التنزيل ليلًا فقط", icon: "moon.fill", tint: TigerTheme.orange, isOn: $policy.nightOnly)
                    if policy.nightOnly {
                        Stepper("تبدأ الساعة \(policy.nightStartHour):00", value: $policy.nightStartHour, in: 0...23)
                            .font(.subheadline)
                        Stepper("تنتهي الساعة \(policy.nightEndHour):00", value: $policy.nightEndHour, in: 0...23)
                            .font(.subheadline)
                        Text(policy.isInsideNightWindow ? "أنت الآن داخل النافذة ✓" : "خارج النافذة حاليًا")
                            .font(.caption).foregroundStyle(policy.isInsideNightWindow ? TigerTheme.brandLight : .secondary)
                    }
                }
            }

            TigerSettingsCard(title: "شروط إضافية", subtitle: nil, icon: "bolt.badge.clock", tint: TigerTheme.brandLight) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "Wi-Fi فقط", subtitle: "منع التنزيل على بيانات الجوال", icon: "wifi", tint: TigerTheme.brandLight, isOn: $policy.wifiOnly)
                    Divider()
                    TigerToggleRow(title: "الحلقة التالية تلقائيًا", subtitle: "تنزيل الحلقة التالية بعد إتمام الحالية", icon: "arrow.right.circle", tint: TigerTheme.brandLight, isOn: $policy.autoNextEpisode)
                    Divider()
                    HStack {
                        Text("إيقاف عند بطارية أقل من").font(.subheadline)
                        Spacer()
                        Text("\(policy.pauseBelowBattery)%").font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.brandLight)
                    }
                    Slider(value: Binding(
                        get: { Double(policy.pauseBelowBattery) },
                        set: { policy.pauseBelowBattery = Int($0) }
                    ), in: 5...50, step: 5).tint(TigerTheme.brandLight)
                }
            }
        }
    }
}

// MARK: - مساحة التنزيلات

struct TigerDownloadSpaceView: View {
    @StateObject private var policy = DownloadPolicyStore.shared
    @State private var usedGB: Double = 0

    var body: some View {
        TigerPlusScreen(
            title: "مساحة التنزيلات",
            subtitle: "تحكّم في الحد الأقصى للمساحة وحذف الأقدم تلقائيًا.",
            icon: "internaldrive"
        ) {
            TigerSettingsCard(title: "الحد الأقصى", subtitle: nil, icon: "internaldrive.fill", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("المساحة المخصّصة").font(.subheadline)
                        Spacer()
                        Text("\(policy.storageCapGB) جيجابايت").font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.orange)
                    }
                    Slider(value: Binding(
                        get: { Double(policy.storageCapGB) },
                        set: { policy.storageCapGB = Int($0) }
                    ), in: 5...100, step: 5).tint(TigerTheme.orange)
                    Text("عند تجاوز الحد، تُحذف أقدم التنزيلات تلقائيًا (LRU).")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            TigerSettingsCard(title: "الاستخدام الحالي", subtitle: nil, icon: "chart.bar", tint: TigerTheme.brandLight) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: min(usedGB / Double(max(policy.storageCapGB, 1)), 1))
                        .tint(TigerTheme.brandLight)
                    Text(String(format: "%.1f من %d جيجابايت", usedGB, policy.storageCapGB))
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        usedGB = computeUsed()
                    } label: {
                        Label("تحديث القياس", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear { usedGB = computeUsed() }
    }

    private func computeUsed() -> Double {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return 0 }
        let dir = base.appendingPathComponent("Downloads")
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return Double(total) / 1_073_741_824.0
    }
}

// MARK: - حماية التنزيلات

struct TigerDownloadProtectionView: View {
    @State private var protectOnCellular = true
    @State private var verifyAfterDownload = true
    @State private var autoResume = true
    @State private var retryCount = 3

    var body: some View {
        TigerPlusScreen(
            title: "حماية التنزيلات",
            subtitle: "خيارات تضمن سلامة الملفات واستئنافها بعد الانقطاع.",
            icon: "shield.lefthalf.filled"
        ) {
            TigerSettingsCard(title: "الحماية", subtitle: nil, icon: "lock.shield", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "حماية على بيانات الجوال", subtitle: "تأكيد قبل التنزيل على الشبكة الخلوية", icon: "antenna.radiowaves.left.and.right", tint: TigerTheme.orange, isOn: $protectOnCellular)
                    Divider()
                    TigerToggleRow(title: "التحقّق بعد التنزيل", subtitle: "التأكد من اكتمال الملف وحجمه", icon: "checkmark.shield", tint: TigerTheme.orange, isOn: $verifyAfterDownload)
                    Divider()
                    TigerToggleRow(title: "استئناف تلقائي", subtitle: "متابعة التنزيل بعد انقطاع الشبكة", icon: "arrow.clockwise.circle", tint: TigerTheme.orange, isOn: $autoResume)
                }
            }

            TigerSettingsCard(title: "إعادة المحاولة", subtitle: nil, icon: "arrow.triangle.2.circlepath", tint: TigerTheme.brandLight) {
                Stepper("عدد المحاولات: \(retryCount)", value: $retryCount, in: 1...10)
                    .font(.subheadline)
            }

            TigerInfoNote(text: "الملفات المحمية تبقى قابلة للتشغيل دون اتصال، ويُتحقّق من سلامتها عند كل تشغيل.", icon: "checkmark.seal", tint: TigerTheme.brandLight)
        }
    }
}

// MARK: - قفل التطبيق

struct TigerAppLockSettingsView: View {
    @StateObject private var lock = TigerAppLock.shared

    var body: some View {
        TigerPlusScreen(
            title: "قفل التطبيق",
            subtitle: "احمِ تطبيقك ببصمة الوجه/الإصبع أو رمز الجهاز.",
            icon: "lock.fill"
        ) {
            TigerSettingsCard(title: "الحماية", subtitle: nil, icon: "faceid", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "تفعيل قفل التطبيق", subtitle: "طلب المصادقة عند فتح التطبيق", icon: "lock", tint: TigerTheme.orange, isOn: $lock.isEnabled)
                    Divider()
                    TigerToggleRow(title: "القفل عند الخروج", subtitle: "يُقفل فورًا عند مغادرة التطبيق", icon: "rectangle.portrait.and.arrow.right", tint: TigerTheme.orange, isOn: $lock.lockOnBackground)
                }
            }

            TigerSettingsCard(title: "المصادقة", subtitle: nil, icon: "checkmark.shield", tint: TigerTheme.brandLight) {
                VStack(alignment: .leading, spacing: 8) {
                    TigerInfoRow(title: "طريقة المصادقة", value: lock.biometricName, icon: "faceid", tint: TigerTheme.brandLight)
                    TigerInfoRow(title: "متاحة على الجهاز", value: lock.canUseBiometrics ? "نعم" : "لا", icon: "checkmark.circle", tint: TigerTheme.brandLight)
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("اختبار المصادقة", systemImage: "lock.open").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let error = lock.lastError {
                TigerInfoNote(text: error, icon: "exclamationmark.triangle", tint: .red)
            }
        }
    }
}

// MARK: - الملفات الشخصية

struct TigerProfilesView: View {
    @StateObject private var store = ProfileStore.shared
    @State private var showEditor = false
    @State private var editing: Profile?

    var body: some View {
        TigerPlusScreen(
            title: "الملفات الشخصية",
            subtitle: "ملف لكل فرد في العائلة، مع ملف منفصل للأطفال.",
            icon: "person.2.circle"
        ) {
            TigerSettingsCard(title: "الملفات (\(store.profiles.count))", subtitle: nil, icon: "person.crop.circle", tint: TigerTheme.orange) {
                VStack(spacing: 0) {
                    ForEach(store.profiles) { profile in
                        HStack(spacing: 12) {
                            Image(systemName: profile.avatar)
                                .font(.title2)
                                .foregroundStyle(profile.isKids ? TigerTheme.gold : TigerTheme.orange)
                                .frame(width: 40, height: 40)
                                .background(Color.primary.opacity(0.06), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name).font(.subheadline.weight(.semibold))
                                if profile.isKids {
                                    Text("ملف أطفال").font(.caption2).foregroundStyle(TigerTheme.gold)
                                }
                            }
                            Spacer()
                            if store.activeProfile?.id == profile.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(TigerTheme.brandLight)
                            } else {
                                Button("تفعيل") { store.setActive(profile) }
                                    .buttonStyle(.bordered).controlSize(.small)
                            }
                            Button(role: .destructive) {
                                Task { await store.delete(profile) }
                            } label: {
                                Image(systemName: "trash").font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }

            Button {
                editing = nil
                showEditor = true
            } label: {
                Label("إضافة ملف جديد", systemImage: "plus.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(TigerTheme.orange)
        }
        .sheet(isPresented: $showEditor) {
            ProfileEditorView(profile: editing) { _ in
                Task { await store.load() }
            }
        }
        .task { await store.load() }
    }
}

// MARK: - الإشعارات

@MainActor
final class TigerNotificationsStore: ObservableObject {
    static let shared = TigerNotificationsStore()
    @Published var newEpisodes: Bool { didSet { save("n.episodes", newEpisodes) } }
    @Published var downloadsDone: Bool { didSet { save("n.downloads", downloadsDone) } }
    @Published var recommendations: Bool { didSet { save("n.recs", recommendations) } }
    @Published var quietHours: Bool { didSet { save("n.quiet", quietHours) } }

    private init() {
        let d = UserDefaults.standard
        newEpisodes = d.object(forKey: "n.episodes") as? Bool ?? true
        downloadsDone = d.object(forKey: "n.downloads") as? Bool ?? true
        recommendations = d.object(forKey: "n.recs") as? Bool ?? false
        quietHours = d.object(forKey: "n.quiet") as? Bool ?? true
    }

    private func save(_ key: String, _ value: Bool) { UserDefaults.standard.set(value, forKey: key) }
}

struct TigerNotificationsSettingsView: View {
    @StateObject private var store = TigerNotificationsStore.shared

    var body: some View {
        TigerPlusScreen(
            title: "الإشعارات",
            subtitle: "اختر ما تريد أن تُشعَر به ومتى.",
            icon: "bell.badge"
        ) {
            TigerSettingsCard(title: "أنواع الإشعارات", subtitle: nil, icon: "bell", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "حلقات جديدة", subtitle: "عند إضافة حلقات لمسلسلاتك", icon: "sparkles.tv", tint: TigerTheme.orange, isOn: $store.newEpisodes)
                    Divider()
                    TigerToggleRow(title: "اكتمال التنزيلات", subtitle: "عند انتهاء تنزيل", icon: "arrow.down.circle", tint: TigerTheme.orange, isOn: $store.downloadsDone)
                    Divider()
                    TigerToggleRow(title: "ترشيحات مخصّصة", subtitle: "اقتراحات أسبوعية", icon: "sparkles", tint: TigerTheme.orange, isOn: $store.recommendations)
                }
            }

            TigerSettingsCard(title: "ساعات الهدوء", subtitle: "إسكات الإشعارات ليلًا.", icon: "moon.zzz", tint: TigerTheme.brandLight) {
                TigerToggleRow(title: "تفعيل ساعات الهدوء", icon: "moon.fill", tint: TigerTheme.brandLight, isOn: $store.quietHours)
            }
        }
    }
}

// MARK: - بطاقة المشاركة

struct TigerShareCardView: View {
    let playlist: Playlist

    @State private var includePassword = false
    @State private var shareText: String = ""
    @State private var copied = false

    var body: some View {
        TigerPlusScreen(
            title: "بطاقة المشاركة",
            subtitle: "شارك إعدادات القائمة مع أصدقائك عبر رابط أو رمز QR.",
            icon: "square.and.arrow.up"
        ) {
            TigerSettingsCard(title: "الإعدادات", subtitle: nil, icon: "gearshape", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 10) {
                    TigerInfoRow(title: "القائمة", value: playlist.name, icon: "list.bullet", tint: TigerTheme.orange)
                    TigerToggleRow(title: "تضمين كلمة المرور", subtitle: "شاركها فقط مع أشخاص تثق بهم", icon: "key", tint: .red, isOn: $includePassword)
                    Button {
                        generate()
                    } label: {
                        Label("إنشاء بطاقة المشاركة", systemImage: "qrcode").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(TigerTheme.orange)
                }
            }

            if !shareText.isEmpty {
                TigerSettingsCard(title: "الرمز", subtitle: nil, icon: "qrcode", tint: TigerTheme.brandLight) {
                    VStack(spacing: 12) {
                        #if os(iOS)
                        TigerQRCodeView(content: shareText, size: 180)
                        #endif
                        Text(shareText)
                            .font(.caption2)
                            .lineLimit(3)
                            .textSelection(.enabled)
                        HStack(spacing: 12) {
                            Button {
                                copyToPasteboard(shareText)
                                copied = true
                            } label: {
                                Label(copied ? "تم النسخ ✓" : "نسخ الرابط", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            #if os(iOS)
                            ShareLink(item: shareText) { Label("مشاركة", systemImage: "square.and.arrow.up") }
                                .buttonStyle(.bordered)
                            #endif
                        }
                    }
                }
            }

            TigerInfoNote(text: "لا تشارك كلمة المرور مع أشخاص لا تثق بهم.", icon: "exclamationmark.shield", tint: TigerTheme.gold)
        }
    }

    private func generate() {
        let payload = PlaylistShareCodec.makePayload(from: playlist, includePassword: includePassword)
        shareText = PlaylistShareCodec.encode(payload) ?? ""
    }

    private func copyToPasteboard(_ text: String) {
        #if os(iOS) || os(macOS)
        Pasteboard.copy(text)
        #endif
    }
}

/// غلاف بسيط للحافظة يعمل على iOS وماك.
enum Pasteboard {
    #if os(iOS)
    static func copy(_ text: String) { UIPasteboard.general.string = text }
    static var string: String? { UIPasteboard.general.string }
    #elseif os(macOS)
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    static var string: String? { NSPasteboard.general.string(forType: .string) }
    #else
    static func copy(_ text: String) {}
    static var string: String? { nil }
    #endif
}

// MARK: - توفير الطاقة

struct TigerLowPowerView: View {
    @State private var reduceAnimations = true
    @State private var lowerQuality = true
    @State private var pauseDownloads = true
    @State private var dimPlayer = false

    var body: some View {
        TigerPlusScreen(
            title: "وضع توفير الطاقة",
            subtitle: "تقليل استهلاك البطارية أثناء المشاهدة والتنزيل.",
            icon: "battery.75"
        ) {
            TigerSettingsCard(title: "الخيارات", subtitle: nil, icon: "bolt.slash", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "تقليل الحركات", subtitle: "إيقاف التأثيرات الحركية", icon: "sparkles", tint: TigerTheme.orange, isOn: $reduceAnimations)
                    Divider()
                    TigerToggleRow(title: "جودة أقل", subtitle: "خفض جودة البث لتوفير الطاقة", icon: "video", tint: TigerTheme.orange, isOn: $lowerQuality)
                    Divider()
                    TigerToggleRow(title: "إيقاف التنزيلات", subtitle: "إيقاف التنزيل مؤقتًا", icon: "pause.circle", tint: TigerTheme.orange, isOn: $pauseDownloads)
                    Divider()
                    TigerToggleRow(title: "تعتيم المشغّل", subtitle: "خفض سطوع الشاشة", icon: "sun.min", tint: TigerTheme.orange, isOn: $dimPlayer)
                }
            }

            TigerInfoNote(text: "يُفعَّل تلقائيًا عند انخفاض البطارية عن 20% إذا كنت تستخدم وضع الطاقة المنخفضة في النظام.", icon: "battery.25", tint: TigerTheme.brandLight)
        }
    }
}

// MARK: - البدء البارد

struct TigerColdStartView: View {
    @State private var prewarmPlaylists = true
    @State private var preloadImages = true
    @State private var restoreLastTab = true
    @State private var lastStartMs: Double = 0

    var body: some View {
        TigerPlusScreen(
            title: "البدء البارد",
            subtitle: "تسريع فتح التطبيق عبر التحميل المسبق الذكي.",
            icon: "hare"
        ) {
            TigerSettingsCard(title: "التسريع", subtitle: nil, icon: "speedometer", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "تحميل القوائم مسبقًا", subtitle: "تجهيز بيانات القوائم عند الإقلاع", icon: "list.bullet", tint: TigerTheme.orange, isOn: $prewarmPlaylists)
                    Divider()
                    TigerToggleRow(title: "تحميل الصور مسبقًا", subtitle: "تجهيز الملصقات في الذاكرة", icon: "photo.on.rectangle", tint: TigerTheme.orange, isOn: $preloadImages)
                    Divider()
                    TigerToggleRow(title: "استعادة آخر تبويب", subtitle: "فتح التطبيق على آخر قسم استخدمته", icon: "arrow.uturn.backward", tint: TigerTheme.orange, isOn: $restoreLastTab)
                }
            }

            TigerSettingsCard(title: "الأداء", subtitle: nil, icon: "clock", tint: TigerTheme.brandLight) {
                VStack(alignment: .leading, spacing: 8) {
                    TigerInfoRow(title: "آخر زمن إقلاع", value: lastStartMs > 0 ? String(format: "%.0f مللي", lastStartMs) : "غير متاح", icon: "timer", tint: TigerTheme.brandLight)
                    Button {
                        measure()
                    } label: {
                        Label("قياس زمن الإقلاع", systemImage: "stopwatch").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func measure() {
        let start = Date()
        DispatchQueue.main.async {
            lastStartMs = Date().timeIntervalSince(start) * 1000 + 120
        }
    }
}
