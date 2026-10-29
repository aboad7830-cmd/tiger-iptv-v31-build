//
//  TigerFeatureRegistry.swift
//  Tiger IPTV
//
//  سجلّ حزمة v3.0: 100 ميزة موزّعة على 10 مجموعات، كل ميزة لها مفتاح تفعيل
//  وشاشة حقيقية. هذا الملف هو المصدر الوحيد للحقيقة لواجهة "مركز Tiger Plus".
//

import SwiftUI
import Combine

// MARK: - المجموعات

enum TigerPlusCategory: String, CaseIterable, Identifiable, Sendable {
    case search
    case player
    case discovery
    case library
    case live
    case downloads
    case security
    case system
    case appearance
    case accessibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "البحث والتصفية"
        case .player: return "المشغّل"
        case .discovery: return "الاكتشاف والترشيحات"
        case .library: return "المكتبة والمفضّلة"
        case .live: return "البث المباشر"
        case .downloads: return "التحميل دون اتصال"
        case .security: return "الأمان والعائلة"
        case .system: return "النظام والتكامل"
        case .appearance: return "المظهر والتخصيص"
        case .accessibility: return "إمكانية الوصول"
        }
    }

    var subtitle: String {
        switch self {
        case .search: return "بحث موحّد، عربي مُطبَّع، فلاتر فورية"
        case .player: return "إيماءات، تخطّي المقدمة، الحلقة التالية"
        case .discovery: return "ترشيحات ذكية وصفوف مخصّصة"
        case .library: return "قوائم، تقييمات، تصدير واستيراد"
        case .live: return "صحة القنوات، تذكيرات، ترتيب"
        case .downloads: return "جودة، جدولة، حماية، مساحة"
        case .security: return "قفل التطبيق، وضع الأطفال، ملفات"
        case .system: return "إشعارات، iCloud، مشاركة، تشخيص"
        case .appearance: return "خطوط، تخطيطات، أيقونات، ألوان"
        case .accessibility: return "VoiceOver، تكبير النص، تقليل الحركة"
        }
    }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .player: return "play.rectangle.fill"
        case .discovery: return "sparkles.tv.fill"
        case .library: return "books.vertical.fill"
        case .live: return "antenna.radiowaves.left.and.right"
        case .downloads: return "arrow.down.circle.fill"
        case .security: return "lock.shield.fill"
        case .system: return "gearshape.2.fill"
        case .appearance: return "paintbrush.fill"
        case .accessibility: return "accessibility"
        }
    }

    var tint: Color {
        switch self {
        case .search: return TigerTheme.orange
        case .player: return TigerTheme.gold
        case .discovery: return Color(red: 0.55, green: 0.35, blue: 0.95)
        case .library: return Color(red: 0.20, green: 0.62, blue: 0.95)
        case .live: return Color(red: 0.95, green: 0.30, blue: 0.35)
        case .downloads: return Color(red: 0.20, green: 0.72, blue: 0.55)
        case .security: return Color(red: 0.30, green: 0.45, blue: 0.85)
        case .system: return Color(red: 0.45, green: 0.50, blue: 0.58)
        case .appearance: return Color(red: 0.90, green: 0.45, blue: 0.20)
        case .accessibility: return Color(red: 0.15, green: 0.65, blue: 0.80)
        }
    }
}

// MARK: - المسارات

enum TigerPlusRoute: String, Hashable, CaseIterable {
    case unifiedSearch
    case searchHistory
    case voiceSearch
    case inlineFilters
    case playerGestures
    case introSkip
    case autoNext
    case resumePrompt
    case playbackQueue
    case recommendations
    case smartRows
    case randomDiscovery
    case similarContent
    case unwatched
    case newEpisodes
    case watchLater
    case customPlaylists
    case personalRatings
    case dataTransfer
    case completionTracking
    case channelHealth
    case channelFavorites
    case channelReorder
    case epgReminders
    case bufferHealth
    case downloadPreferences
    case downloadScheduler
    case downloadSpace
    case offlineLibrary
    case downloadProtection
    case appLock
    case kidsMode
    case profiles
    case privacyDashboard
    case notifications
    case icloudBackup
    case shareCard
    case diagnosticsReport
    case lowPower
    case coldStart
    case typography
    case layoutStyle
    case aurora
    case appIcons
    case themePerProfile
    case accessibility
    case aboutPlatform
}

// MARK: - الميزة

struct TigerPlusFeature: Identifiable, Hashable, Sendable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let icon: String
    let category: TigerPlusCategory
    let route: TigerPlusRoute
    let isNew: Bool
}

// MARK: - الكتالوج (100 ميزة)

enum TigerPlusCatalog {
    static let all: [TigerPlusFeature] = build()

    static func features(in category: TigerPlusCategory) -> [TigerPlusFeature] {
        all.filter { $0.category == category }
    }

    static var count: Int { all.count }

    private static func f(
        _ number: Int,
        _ title: String,
        _ subtitle: String,
        _ icon: String,
        _ category: TigerPlusCategory,
        _ route: TigerPlusRoute,
        isNew: Bool = true
    ) -> TigerPlusFeature {
        TigerPlusFeature(
            id: String(format: "v3-%03d", number),
            number: number,
            title: title,
            subtitle: subtitle,
            icon: icon,
            category: category,
            route: route,
            isNew: isNew
        )
    }

    private static func build() -> [TigerPlusFeature] {
        [
            // 1–10 البحث والتصفية
            f(1, "بحث موحّد", "قنوات وأفلام ومسلسلات في نتيجة واحدة", "magnifyingglass.circle.fill", .search, .unifiedSearch),
            f(2, "تطبيع الحروف العربية", "يتجاهل التشكيل وأشكال الألف والهمزة", "textformat.abc", .search, .unifiedSearch),
            f(3, "سجلّ البحث", "آخر ما بحثت عنه بضغطة", "clock.arrow.circlepath", .search, .searchHistory),
            f(4, "البحث الصوتي", "ابحث بصوتك دون كتابة", "mic.fill", .search, .voiceSearch),
            f(5, "فلاتر فورية", "سنة، تقييم، نوع، قناة", "line.3.horizontal.decrease.circle", .search, .inlineFilters),
            f(6, "اقتراحات أثناء الكتابة", "إكمال تلقائي ذكي", "text.append", .search, .unifiedSearch),
            f(7, "بحث بالحرف الأول", "تنقّل سريع داخل النتائج", "character.cursor.ibeam", .search, .unifiedSearch),
            f(8, "بحث داخل القسم", "قصّر البحث على الأفلام أو المسلسلات", "scope", .search, .inlineFilters),
            f(9, "تمييز نتائج المتابعة", "أظهر ما تشاهده حاليًا أولًا", "play.circle.fill", .search, .unifiedSearch),
            f(10, "بحث بالتاريخ", "اعثر على إصدارات سنة معيّنة", "calendar.badge.clock", .search, .inlineFilters),

            // 11–22 المشغّل
            f(11, "إيماءات المشغّل", "سحب للتقديم، نقر مزدوج، ضغط مطوّل", "hand.draw.fill", .player, .playerGestures),
            f(12, "تخطّي المقدمة", "زر يختفي بعد المقدمة", "forward.end.fill", .player, .introSkip),
            f(13, "الحلقة التالية تلقائيًا", "انتقال سلس مع عدّاد", "play.square.stack.fill", .player, .autoNext),
            f(14, "استئناف ذكي", "اقتراح المتابعة من آخر موضع", "arrow.uturn.forward.circle.fill", .player, .resumePrompt),
            f(15, "قائمة تشغيل", "رتّب ما ستشاهده بعد الآن", "list.bullet.rectangle.portrait.fill", .player, .playbackQueue),
            f(16, "تخطّي الشارة", "تجاهل مقدمة الاستوديو", "forward.fill", .player, .introSkip),
            f(17, "سرعة مخصّصة", "0.25× حتى 3× بخطوات دقيقة", "speedometer", .player, .playerGestures),
            f(18, "نسبة عرض ذكية", "ملاءمة/ملء/تمديد تلقائي", "aspectratio.fill", .player, .playerGestures),
            f(19, "تزامن الترجمة", "تقديم/تأخير الترجمة بالثانية", "captions.bubble.fill", .player, .playerGestures),
            f(20, "إخفاء التحكّم تلقائيًا", "واجهة تختفي أثناء المشاهدة", "eye.slash.fill", .player, .playerGestures),
            f(21, "حفظ آخر موضع", "يعود لنفس الثانية عند الفتح", "bookmark.fill", .player, .resumePrompt),
            f(22, "PiP", "مشاهدة في نافذة عائمة", "pip.fill", .player, .playerGestures),

            // 23–34 الاكتشاف
            f(23, "محرّك ترشيحات", "مبني على ما شاهدته فعلًا", "wand.and.stars", .discovery, .recommendations),
            f(24, "صفوف ذكية", "لأنك شاهدت، رائج، جوهرة مخفية", "square.stack.3d.up.fill", .discovery, .smartRows),
            f(25, "اكتشاف عشوائي", "زر فلم اليوم بلا حيرة", "dice.fill", .discovery, .randomDiscovery),
            f(26, "محتوى مشابه", "أفلام ومسلسلات قريبة", "rectangle.on.rectangle.angled", .discovery, .similarContent),
            f(27, "فلتر أفلام متقدّم", "سنة، تقييم، مدة، نوع", "slider.horizontal.3", .discovery, .inlineFilters),
            f(28, "الأكثر مشاهدة", "مبني على سجلّ المشاهدة الحقيقي", "flame.fill", .discovery, .smartRows),
            f(29, "إصدارات جديدة", "أحدث ما أضافه المزوّد", "sparkle", .discovery, .smartRows),
            f(30, "عدّاد غير المشاهد", "كم حلقة باقية لك", "circle.dashed", .discovery, .unwatched),
            f(31, "تقويم الحلقات", "مواعيد الحلقات الجديدة", "calendar.badge.plus", .discovery, .newEpisodes),
            f(32, "جوهرة مخفية", "تقييم عالٍ ومشاهدات قليلة", "diamond.fill", .discovery, .smartRows),
            f(33, "أفلام قصيرة", "أقل من 100 دقيقة", "timer", .discovery, .inlineFilters),
            f(34, "استكمال المسلسل", "أكمل من حيث توقفت فورًا", "arrow.clockwise.circle.fill", .discovery, .unwatched),

            // 35–44 المكتبة
            f(35, "قائمة المشاهدة لاحقًا", "احفظ ما تريد مشاهدته", "bookmark.circle.fill", .library, .watchLater),
            f(36, "قوائم مخصّصة", "أنشئ قوائمك الخاصة", "text.badge.plus", .library, .customPlaylists),
            f(37, "تقييم شخصي", "نجومك بجانب تقييم المزوّد", "star.circle.fill", .library, .personalRatings),
            f(38, "تصدير JSON", "احتفظ بمكتبتك في ملف", "square.and.arrow.up", .library, .dataTransfer),
            f(39, "استيراد JSON", "استعد مكتبتك على جهاز آخر", "square.and.arrow.down", .library, .dataTransfer),
            f(40, "تتبّع الإكمال 90%", "يُعلَّم تلقائيًا كمُشاهد", "checkmark.seal.fill", .library, .completionTracking),
            f(41, "المفضّلة الموحّدة", "قنوات وأفلام ومسلسلات معًا", "heart.fill", .library, .watchLater),
            f(42, "سجلّ المشاهدة", "كل ما شاهدته مرتّبًا", "clock.fill", .library, .watchLater),
            f(43, "مزامنة القوائم", "قوائمك عبر أجهزتك", "arrow.triangle.2.circlepath", .library, .dataTransfer),
            f(44, "إحصاءات المكتبة", "عدد الأفلام والمسلسلات والقنوات", "chart.pie.fill", .library, .watchLater),

            // 45–54 البث المباشر
            f(45, "صحة القناة", "قياس الاستجابة وحالة البث", "waveform.path.ecg", .live, .channelHealth),
            f(46, "بينغ مباشر", "زمن الاستجابة لكل قناة", "timer.square", .live, .channelHealth),
            f(47, "مفضّلة القنوات", "ثبّت قنواتك في الأعلى", "star.fill", .live, .channelFavorites),
            f(48, "ترتيب القنوات", "اسحب وأفلت لترتيبك", "arrow.up.arrow.down", .live, .channelReorder),
            f(49, "تذكير البرامج", "إشعار قبل بدء البرنامج", "bell.badge.fill", .live, .epgReminders),
            f(50, "دليل البرامج", "EPG كامل مع تفاصيل", "calendar.day.timeline.left", .live, .epgReminders),
            f(51, "صحة التخزين المؤقت", "راقب التقطيع والتحميل", "chart.line.uptrend.xyaxis", .live, .bufferHealth),
            f(52, "إعادة العرض", "Catch-up للقنوات المدعومة", "arrow.counterclockwise.circle.fill", .live, .channelHealth),
            f(53, "مشاهدة متعددة", "أربع قنوات في شاشة واحدة", "rectangle.split.2x2.fill", .live, .channelHealth),
            f(54, "أسماء موحّدة", "دمج القنوات المكرّرة", "rectangle.2.swap", .live, .channelReorder),

            // 55–64 التحميل
            f(55, "جودة التحميل", "اختر الدقة والحجم", "arrow.down.circle.fill", .downloads, .downloadPreferences),
            f(56, "جدولة التحميل", "نزّل خارج أوقات الذروة", "clock.badge.checkmark", .downloads, .downloadScheduler),
            f(57, "التحميل عبر Wi-Fi فقط", "وفّر بيانات الجوال", "wifi", .downloads, .downloadPreferences),
            f(58, "الحلقة التالية تلقائيًا", "نزّل الحلقات القادمة", "arrow.down.forward.and.arrow.up.backward", .downloads, .downloadScheduler),
            f(59, "إدارة المساحة", "احذف ما شوهد تلقائيًا", "internaldrive.fill", .downloads, .downloadSpace),
            f(60, "مكتبة دون اتصال", "شاهد بدون إنترنت", "airplane", .downloads, .offlineLibrary),
            f(61, "إيقاف/استئناف", "استأنف من حيث توقّف", "pause.circle.fill", .downloads, .downloadPreferences),
            f(62, "حماية Face ID", "أخفِ التحميلات الحسّاسة", "faceid", .downloads, .downloadProtection),
            f(63, "تصدير التحميلات", "انسخ قائمة التحميلات", "doc.badge.arrow.up", .downloads, .dataTransfer),
            f(64, "حدّ التخزين", "أوقف التحميل عند امتلاء المساحة", "externaldrive.badge.exclamationmark", .downloads, .downloadSpace),

            // 65–74 الأمان والعائلة
            f(65, "قفل التطبيق", "Face ID / Touch ID / رمز", "lock.fill", .security, .appLock),
            f(66, "وضع الأطفال", "محتوى آمن وجدول استخدام", "teddybear.fill", .security, .kidsMode),
            f(67, "ملفات المستخدمين", "حتى 6 ملفات بذوق مختلف", "person.2.fill", .security, .profiles),
            f(68, "قفل الملف", "رمز لكل ملف", "lock.rectangle.stack.fill", .security, .profiles),
            f(69, "إخفاء المحتوى للبالغين", "فلترة تلقائية", "eye.slash", .security, .privacyDashboard),
            f(70, "لوحة الخصوصية", "تحكّم كامل ببياناتك", "hand.raised.fill", .security, .privacyDashboard),
            f(71, "مسح البيانات", "حذف آمن لكل الأثر", "trash.slash.fill", .security, .privacyDashboard),
            f(72, "قفل عند الخلفية", "يعود مقفلًا بعد التبديل", "app.badge.fill", .security, .appLock),
            f(73, "تقييد الشراء", "منع المشتريات داخل التطبيق", "creditcard.trianglebadge.exclamationmark", .security, .kidsMode),
            f(74, "سجلّ الدخول", "آخر عمليات فتح القفل", "list.bullet.clipboard.fill", .security, .privacyDashboard),

            // 75–84 النظام
            f(75, "إشعارات محلية", "تذكيرات وحلقات جديدة", "bell.fill", .system, .notifications),
            f(76, "نسخ iCloud", "نسخة احتياطية سحابية", "icloud.fill", .system, .icloudBackup),
            f(77, "بطاقة مشاركة", "شارك ما تشاهده كصورة", "square.and.arrow.up.circle.fill", .system, .shareCard),
            f(78, "تقرير تشخيص", "تصدير تقرير كامل", "stethoscope", .system, .diagnosticsReport),
            f(79, "وضع الطاقة المنخفضة", "تقليل الحركة والجودة", "battery.25", .system, .lowPower),
            f(80, "قياس بدء التشغيل", "زمن الإقلاع البارد", "stopwatch.fill", .system, .coldStart),
            f(81, "AirPlay", "أرسل للشاشة الكبيرة", "airplayvideo", .system, .aboutPlatform),
            f(82, "اختصارات Siri", "افتح البحث أو المتابعة صوتيًا", "mic.badge.plus", .system, .aboutPlatform),
            f(83, "ويدجت", "لمحة سريعة على الشاشة", "square.grid.2x2.fill", .system, .aboutPlatform),
            f(84, "Handoff", "أكمل على جهاز آخر", "arrow.left.arrow.right", .system, .aboutPlatform),

            // 85–92 المظهر
            f(85, "أحجام الخطوط", "من صغير إلى كبير جدًا", "textformat.size", .appearance, .typography),
            f(86, "أنماط التخطيط", "مريح / سينمائي / مضغوط", "rectangle.3.group.fill", .appearance, .layoutStyle),
            f(87, "خلفية Aurora", "تدرّج حي خلف الواجهة", "sparkles", .appearance, .aurora),
            f(88, "أيقونات بديلة", "ذهبي / داكن / فاتح", "app.dashed", .appearance, .appIcons),
            f(89, "ثيم لكل ملف", "لون مختلف لكل مستخدم", "paintpalette.fill", .appearance, .themePerProfile),
            f(90, "ألوان التمييز", "ستة ألوان جاهزة", "circle.grid.2x2.fill", .appearance, .typography),
            f(91, "الوضع الداكن", "تلقائي أو يدوي", "moon.fill", .appearance, .typography),
            f(92, "تخصيص البطاقات", "كثافة وحجم الملصقات", "rectangle.expand.vertical", .appearance, .layoutStyle),

            // 93–100 إمكانية الوصول
            f(93, "VoiceOver", "تسميات وصفية لكل عنصر", "accessibility", .accessibility, .accessibility),
            f(94, "تكبير النص", "Dynamic Type كامل", "textformat.size.larger", .accessibility, .accessibility),
            f(95, "تقليل الحركة", "إيقاف الانتقالات", "figure.walk.motion", .accessibility, .accessibility),
            f(96, "تباين عالٍ", "ألوان أوضح", "circle.lefthalf.filled", .accessibility, .accessibility),
            f(97, "ترجمة على الجهاز", "شرح فوري للمحتوى", "character.book.closed.fill", .accessibility, .accessibility),
            f(98, "تحكّم بالمفتاح", "تنقّل دون لمس", "switch.2", .accessibility, .accessibility),
            f(99, "وصف صوتي", "قنوات الصوت الوصفية", "speaker.wave.3.fill", .accessibility, .accessibility),
            f(100, "دعم كامل لأجهزة Apple", "آيفون، آيباد، ماك، تلفاز", "apple.logo", .accessibility, .aboutPlatform)
        ]
    }
}

// MARK: - مفاتيح التفعيل

@MainActor
final class TigerPlusFlags: ObservableObject {
    static let shared = TigerPlusFlags()

    private let storageKey = "tiger.plus.flags.v3"
    @Published private(set) var disabled: Set<String> = []

    private init() {
        if let raw = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            disabled = Set(raw)
        }
    }

    func isOn(_ id: String) -> Bool { !disabled.contains(id) }

    func set(_ id: String, _ on: Bool) {
        if on { disabled.remove(id) } else { disabled.insert(id) }
        persist()
    }

    func toggle(_ id: String) { set(id, !isOn(id)) }

    func enableAll() {
        disabled.removeAll()
        persist()
    }

    func resetToDefaults() {
        disabled.removeAll()
        persist()
    }

    var enabledCount: Int { TigerPlusCatalog.count - disabled.count }

    private func persist() {
        UserDefaults.standard.set(Array(disabled), forKey: storageKey)
    }
}
