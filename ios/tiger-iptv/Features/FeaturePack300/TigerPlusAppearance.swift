//
//  TigerPlusAppearance.swift
//  Tiger IPTV
//
//  حزمة v3.0 — شاشات المظهر والخطوط والتخطيط والأيقونات.
//  تعمل على iPhone / iPad / Mac / Apple TV / Vision Pro عبر TigerPlatform.
//

import SwiftUI
import Combine

// MARK: - مخزن تفضيلات المظهر

/// مخزن مركزي لتفضيلات المظهر المتقدمة (الخطوط، التخطيط، الأورورا، الأيقونة).
@MainActor
final class TigerAppearanceStore: ObservableObject {
    static let shared = TigerAppearanceStore()

    enum LayoutStyle: String, CaseIterable, Identifiable {
        case grid, list, compact
        var id: String { rawValue }
        var title: String {
            switch self {
            case .grid: return "شبكة"
            case .list: return "قائمة"
            case .compact: return "مدمج"
            }
        }
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2.fill"
            case .list: return "list.bullet"
            case .compact: return "rectangle.grid.1x2.fill"
            }
        }
    }

    enum FontWeightChoice: String, CaseIterable, Identifiable {
        case regular, medium, semibold, bold
        var id: String { rawValue }
        var title: String {
            switch self {
            case .regular: return "عادي"
            case .medium: return "متوسط"
            case .semibold: return "نصف عريض"
            case .bold: return "عريض"
            }
        }
        var weight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    enum IconVariant: String, CaseIterable, Identifiable {
        case classic, midnight, gold, emerald, sunset
        var id: String { rawValue }
        var title: String {
            switch self {
            case .classic: return "الكلاسيكي"
            case .midnight: return "منتصف الليل"
            case .gold: return "ذهبي"
            case .emerald: return "زمردي"
            case .sunset: return "غروب"
            }
        }
        var colors: [Color] {
            switch self {
            case .classic: return [TigerTheme.brand, TigerTheme.brandLight]
            case .midnight: return [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.15, green: 0.20, blue: 0.34)]
            case .gold: return [Color(red: 0.30, green: 0.22, blue: 0.05), TigerTheme.gold]
            case .emerald: return [TigerTheme.brand, TigerTheme.brandLight]
            case .sunset: return [TigerTheme.orangeDeep, TigerTheme.orangeLight]
            }
        }
        /// اسم الأيقونة البديلة في حزمة التطبيق (iOS فقط).
        var alternateName: String? {
            switch self {
            case .classic: return nil
            default: return "AppIcon-\(rawValue)"
            }
        }
    }

    @Published var fontScale: Double { didSet { defaults.set(fontScale, forKey: Keys.fontScale) } }
    @Published var lineSpacing: Double { didSet { defaults.set(lineSpacing, forKey: Keys.lineSpacing) } }
    @Published var fontWeight: FontWeightChoice { didSet { defaults.set(fontWeight.rawValue, forKey: Keys.fontWeight) } }
    @Published var roundedFonts: Bool { didSet { defaults.set(roundedFonts, forKey: Keys.roundedFonts) } }

    @Published var layoutStyle: LayoutStyle { didSet { defaults.set(layoutStyle.rawValue, forKey: Keys.layoutStyle) } }
    @Published var cardDensity: Double { didSet { defaults.set(cardDensity, forKey: Keys.cardDensity) } }
    @Published var posterScale: Double { didSet { defaults.set(posterScale, forKey: Keys.posterScale) } }
    @Published var showTitlesInGrid: Bool { didSet { defaults.set(showTitlesInGrid, forKey: Keys.showTitlesInGrid) } }

    @Published var auroraEnabled: Bool { didSet { defaults.set(auroraEnabled, forKey: Keys.auroraEnabled) } }
    @Published var auroraIntensity: Double { didSet { defaults.set(auroraIntensity, forKey: Keys.auroraIntensity) } }
    @Published var auroraSpeed: Double { didSet { defaults.set(auroraSpeed, forKey: Keys.auroraSpeed) } }

    @Published var iconVariant: IconVariant { didSet { defaults.set(iconVariant.rawValue, forKey: Keys.iconVariant) } }

    @Published var perProfileThemes: Bool { didSet { defaults.set(perProfileThemes, forKey: Keys.perProfileThemes) } }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let fontScale = "tiger.appearance.fontScale"
        static let lineSpacing = "tiger.appearance.lineSpacing"
        static let fontWeight = "tiger.appearance.fontWeight"
        static let roundedFonts = "tiger.appearance.roundedFonts"
        static let layoutStyle = "tiger.appearance.layoutStyle"
        static let cardDensity = "tiger.appearance.cardDensity"
        static let posterScale = "tiger.appearance.posterScale"
        static let showTitlesInGrid = "tiger.appearance.showTitlesInGrid"
        static let auroraEnabled = "tiger.appearance.auroraEnabled"
        static let auroraIntensity = "tiger.appearance.auroraIntensity"
        static let auroraSpeed = "tiger.appearance.auroraSpeed"
        static let iconVariant = "tiger.appearance.iconVariant"
        static let perProfileThemes = "tiger.appearance.perProfileThemes"
    }

    private init() {
        fontScale = defaults.object(forKey: Keys.fontScale) as? Double ?? 1.0
        lineSpacing = defaults.object(forKey: Keys.lineSpacing) as? Double ?? 2
        fontWeight = FontWeightChoice(rawValue: defaults.string(forKey: Keys.fontWeight) ?? "") ?? .medium
        roundedFonts = defaults.object(forKey: Keys.roundedFonts) as? Bool ?? false
        layoutStyle = LayoutStyle(rawValue: defaults.string(forKey: Keys.layoutStyle) ?? "") ?? .grid
        cardDensity = defaults.object(forKey: Keys.cardDensity) as? Double ?? 1.0
        posterScale = defaults.object(forKey: Keys.posterScale) as? Double ?? 1.0
        showTitlesInGrid = defaults.object(forKey: Keys.showTitlesInGrid) as? Bool ?? true
        auroraEnabled = defaults.object(forKey: Keys.auroraEnabled) as? Bool ?? true
        auroraIntensity = defaults.object(forKey: Keys.auroraIntensity) as? Double ?? 0.8
        auroraSpeed = defaults.object(forKey: Keys.auroraSpeed) as? Double ?? 1.0
        iconVariant = IconVariant(rawValue: defaults.string(forKey: Keys.iconVariant) ?? "") ?? .classic
        perProfileThemes = defaults.object(forKey: Keys.perProfileThemes) as? Bool ?? false
    }

    /// يعيد القيم الافتراضية لكل تفضيلات المظهر.
    func resetAll() {
        fontScale = 1.0
        lineSpacing = 2
        fontWeight = .medium
        roundedFonts = false
        layoutStyle = .grid
        cardDensity = 1.0
        posterScale = 1.0
        showTitlesInGrid = true
        auroraEnabled = true
        auroraIntensity = 0.8
        auroraSpeed = 1.0
        iconVariant = .classic
        perProfileThemes = false
    }

    /// يطبّق أيقونة التطبيق البديلة (iOS فقط، بلا أثر على بقية المنصات).
    func applyIconVariant() {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name = iconVariant.alternateName
        UIApplication.shared.setAlternateIconName(name) { _ in }
        #endif
    }
}

// MARK: - شاشة الخطوط

struct TigerTypographySettingsView: View {
    @StateObject private var store = TigerAppearanceStore.shared
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        TigerPlusScreen(
            title: "الخطوط والنصوص",
            subtitle: "تحكّم بحجم الخط، التباعد، والوزن لقراءة مريحة على كل شاشة.",
            icon: "textformat.size"
        ) {
            TigerSettingsCard(title: "معاينة مباشرة", subtitle: "هكذا سيبدو النص في التطبيق", icon: "eye.fill") {
                VStack(alignment: .leading, spacing: store.lineSpacing) {
                    Text("TIGER IPTV")
                        .font(previewFont(size: 26))
                        .foregroundStyle(TigerTheme.orangeGradient)
                    Text("بث مباشر بجودة عالية، أفلام ومسلسلات بلا حدود.")
                        .font(previewFont(size: 15))
                        .foregroundStyle(.primary)
                    Text("اضغط على أي قناة لتبدأ المشاهدة فوراً.")
                        .font(previewFont(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(Color.primary.opacity(0.05)))
            }

            TigerSettingsCard(title: "حجم الخط", subtitle: "من 85% إلى 140%", icon: "textformat") {
                VStack(spacing: 8) {
                    HStack {
                        Text("أصغر").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(store.fontScale * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TigerTheme.orange)
                        Spacer()
                        Text("أكبر").font(.caption2).foregroundStyle(.secondary)
                    }
                    Slider(value: $store.fontScale, in: 0.85...1.4, step: 0.05)
                        .tint(TigerTheme.orange)
                }
            }

            TigerSettingsCard(title: "التباعد بين الأسطر", icon: "text.alignleft") {
                VStack(spacing: 8) {
                    HStack {
                        Text("مضغوط").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(store.lineSpacing)) pt")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TigerTheme.orange)
                        Spacer()
                        Text("واسع").font(.caption2).foregroundStyle(.secondary)
                    }
                    Slider(value: $store.lineSpacing, in: 0...12, step: 1)
                        .tint(TigerTheme.orange)
                }
            }

            TigerSettingsCard(title: "وزن الخط", icon: "bold") {
                Picker("وزن الخط", selection: $store.fontWeight) {
                    ForEach(TigerAppearanceStore.FontWeightChoice.allCases) { weight in
                        Text(weight.title).tag(weight)
                    }
                }
                .pickerStyle(.segmented)
            }

            TigerSettingsCard {
                TigerToggleRow(
                    title: "خطوط مستديرة",
                    subtitle: "شكل أنعم وأكثر ودّية للعناوين",
                    icon: "circle.dashed",
                    isOn: $store.roundedFonts
                )
                Divider().opacity(0.3)
                TigerToggleRow(
                    title: "نص كبير (تكبير النظام)",
                    subtitle: "يكبّر كل نصوص التطبيق دفعة واحدة",
                    icon: "textformat.size.larger",
                    isOn: $theme.largeText
                )
            }

            TigerInfoNote(
                text: "يُحفظ حجم الخط والتباعد لكل ملف تعريف على حدة عند تفعيل «مظهر لكل ملف».",
                icon: "info.circle"
            )
        }
    }

    private func previewFont(size: CGFloat) -> Font {
        let scaled = size * CGFloat(store.fontScale)
        if store.roundedFonts {
            return .system(size: scaled, weight: store.fontWeight.weight, design: .rounded)
        }
        return .system(size: scaled, weight: store.fontWeight.weight)
    }
}

// MARK: - شاشة التخطيط

struct TigerLayoutStyleSettingsView: View {
    @StateObject private var store = TigerAppearanceStore.shared
    @Environment(\.tigerMetrics) private var metrics

    var body: some View {
        TigerPlusScreen(
            title: "نمط التخطيط",
            subtitle: "اختر طريقة عرض البطاقات والملصقات بما يناسب جهازك.",
            icon: "rectangle.3.group"
        ) {
            TigerSettingsCard(title: "نمط العرض", icon: "square.grid.2x2") {
                HStack(spacing: 10) {
                    ForEach(TigerAppearanceStore.LayoutStyle.allCases) { style in
                        Button {
                            withAnimation(TigerMotion.standard) { store.layoutStyle = style }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: style.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                Text(style.title)
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .fill(store.layoutStyle == style ? TigerTheme.orange.opacity(0.18) : Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(store.layoutStyle == style ? TigerTheme.orange : Color.clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(store.layoutStyle == style ? TigerTheme.orange : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            TigerSettingsCard(title: "حجم الملصقات", subtitle: "يكبّر/يصغّر بوسترات الأفلام والمسلسلات", icon: "photo") {
                VStack(spacing: 8) {
                    HStack {
                        Text("أصغر").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(store.posterScale * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TigerTheme.orange)
                        Spacer()
                        Text("أكبر").font(.caption2).foregroundStyle(.secondary)
                    }
                    Slider(value: $store.posterScale, in: 0.75...1.35, step: 0.05)
                        .tint(TigerTheme.orange)
                }
            }

            TigerSettingsCard(title: "كثافة البطاقات", subtitle: "المسافة بين البطاقات في الشبكة", icon: "square.resize") {
                Slider(value: $store.cardDensity, in: 0.6...1.6, step: 0.1)
                    .tint(TigerTheme.orange)
            }

            TigerSettingsCard {
                TigerToggleRow(
                    title: "إظهار العناوين أسفل البوسترات",
                    subtitle: "أطفئه لعرض بوسترات نظيفة فقط",
                    icon: "textformat",
                    isOn: $store.showTitlesInGrid
                )
            }

            TigerSettingsCard(title: "ملخص الجهاز", icon: "display") {
                TigerInfoRow(title: "الجهاز", value: TigerPlatform.displayName, icon: "iphone")
                Divider().opacity(0.3)
                TigerInfoRow(title: "عدد أعمدة الشبكة", value: "\(metrics.gridColumns)", icon: "square.grid.3x3")
                Divider().opacity(0.3)
                TigerInfoRow(title: "أقصى عرض للمحتوى", value: metrics.maxContentWidth.map { "\(Int($0)) pt" } ?? "بلا حد", icon: "arrow.left.and.right")
            }

            TigerInfoNote(
                text: "التخطيط يتكيّف تلقائياً: iPhone عمودان، iPad ثلاثة إلى أربعة، Mac وApple TV شبكة أوسع مع تركيز Focus.",
                icon: "sparkles"
            )
        }
    }
}

// MARK: - شاشة الأورورا

struct TigerAuroraSettingsView: View {
    @StateObject private var store = TigerAppearanceStore.shared

    var body: some View {
        TigerPlusScreen(
            title: "خلفية الأورورا",
            subtitle: "خلفية متحركة ناعمة تمنح التطبيق لمسة حيوية.",
            icon: "sparkles"
        ) {
            TigerSettingsCard(title: "معاينة", icon: "eye.fill") {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(Color.black)
                    if store.auroraEnabled {
                        TigerAuroraBackground(animated: true)
                            .opacity(store.auroraIntensity)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    } else {
                        Text("الأورورا متوقفة")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(height: 160)
            }

            TigerSettingsCard {
                TigerToggleRow(
                    title: "تفعيل الأورورا",
                    subtitle: "خلفية متحركة في الشاشات الفارغة والترحيب",
                    icon: "wand.and.stars",
                    isOn: $store.auroraEnabled
                )
            }

            if store.auroraEnabled {
                TigerSettingsCard(title: "شدّة الألوان", icon: "circle.lefthalf.filled") {
                    Slider(value: $store.auroraIntensity, in: 0.2...1.0, step: 0.05)
                        .tint(TigerTheme.orange)
                }

                TigerSettingsCard(title: "سرعة الحركة", subtitle: "أبطأ = أهدأ للعين", icon: "speedometer") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("هادئة").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1fx", store.auroraSpeed))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TigerTheme.orange)
                            Spacer()
                            Text("سريعة").font(.caption2).foregroundStyle(.secondary)
                        }
                        Slider(value: $store.auroraSpeed, in: 0.3...2.0, step: 0.1)
                            .tint(TigerTheme.orange)
                    }
                }
            }

            TigerInfoNote(
                text: "على Apple TV وMac تُقلَّل حركة الأورورا تلقائياً عند تفعيل «تقليل الحركة» في إعدادات النظام.",
                icon: "accessibility"
            )
        }
    }
}

// MARK: - شاشة أيقونات التطبيق

struct TigerAppIconsView: View {
    @StateObject private var store = TigerAppearanceStore.shared
    @State private var appliedNote: String? = nil

    var body: some View {
        TigerPlusScreen(
            title: "أيقونة التطبيق",
            subtitle: "اختر الشكل الذي يظهر على الشاشة الرئيسية.",
            icon: "app.badge"
        ) {
            TigerSettingsCard(title: "الأشكال المتاحة", icon: "square.stack.3d.up") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 14) {
                    ForEach(TigerAppearanceStore.IconVariant.allCases) { variant in
                        Button {
                            store.iconVariant = variant
                            store.applyIconVariant()
                            appliedNote = "تم اختيار «\(variant.title)»"
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(LinearGradient(colors: variant.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "tiger.head.fill")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(store.iconVariant == variant ? TigerTheme.orange : Color.clear, lineWidth: 2.5)
                                )
                                Text(variant.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(store.iconVariant == variant ? TigerTheme.orange : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let appliedNote {
                TigerInfoNote(text: appliedNote, icon: "checkmark.circle.fill", tint: TigerTheme.brandLight)
            }

            TigerSettingsCard(title: "ملاحظة", icon: "info.circle") {
                Text("تغيير الأيقونة يعمل على iPhone وiPad فقط. على Mac وApple TV تبقى الأيقونة الرسمية ثابتة داخل النظام.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - شاشة مظهر لكل ملف تعريف

struct TigerThemePerProfileView: View {
    @StateObject private var store = TigerAppearanceStore.shared
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var profiles = ProfileStore.shared

    var body: some View {
        TigerPlusScreen(
            title: "مظهر لكل ملف",
            subtitle: "اجعل كل ملف تعريف (بما فيه ملف الأطفال) بمظهره الخاص.",
            icon: "person.2.crop.square.stack"
        ) {
            TigerSettingsCard {
                TigerToggleRow(
                    title: "تفعيل المظهر المستقل",
                    subtitle: "يحفظ المظهر واللون المميز لكل ملف تعريف",
                    icon: "paintpalette",
                    isOn: $store.perProfileThemes
                )
            }

            if store.perProfileThemes {
                TigerSettingsCard(title: "لون التمييز الحالي", icon: "paintbrush.fill") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                        ForEach(ThemeManager.Accent.allCases) { accent in
                            Button {
                                withAnimation(TigerMotion.snappy) { theme.accent = accent }
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(accent.gradient)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle().strokeBorder(theme.accent == accent ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                                .opacity(theme.accent == accent ? 1 : 0)
                                        )
                                    Text(accent.label)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                TigerSettingsCard(title: "المظهر", icon: "circle.lefthalf.filled") {
                    Picker("المظهر", selection: $theme.appearance) {
                        ForEach(ThemeManager.Appearance.allCases) { appearance in
                            Label(appearance.label, systemImage: appearance.icon).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                TigerSettingsCard(title: "الملفات المتاحة", icon: "person.crop.circle") {
                    if profiles.profiles.isEmpty {
                        Text("لا توجد ملفات تعريف بعد. أنشئ ملفاً من إعدادات الملفات.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(profiles.profiles) { profile in
                            HStack(spacing: 10) {
                                Image(systemName: profile.isKids ? "figure.and.child.holdinghands" : "person.fill")
                                    .foregroundStyle(profile.isKids ? TigerTheme.gold : TigerTheme.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name).font(.subheadline.weight(.semibold))
                                    Text(profile.isKids ? "ملف أطفال" : "ملف عادي")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if profiles.activeProfile?.id == profile.id {
                                    Text("نشط")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(TigerTheme.orange.opacity(0.2)))
                                        .foregroundStyle(TigerTheme.orange)
                                }
                            }
                            .padding(.vertical, 4)
                            if profile.id != profiles.profiles.last?.id { Divider().opacity(0.3) }
                        }
                    }
                }
            } else {
                TigerInfoNote(
                    text: "عند الإيقاف، يُطبَّق مظهر واحد على كل الملفات. فعّل الخيار أعلاه لتخصيص كل ملف على حدة.",
                    icon: "info.circle"
                )
            }
        }
    }
}
