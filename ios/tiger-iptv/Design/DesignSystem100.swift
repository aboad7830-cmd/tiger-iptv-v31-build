import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

// MARK: - 51. رموز تصميم موحّدة (Design Tokens)
//
// ملف واحد يجمع كل المسافات والزوايا والظلال. تعديل رقم واحد هنا يغيّر التطبيق كله.

enum DT {

    // 54. شبكة 8 نقاط — كل المسافات مضاعفات 8
    enum Space {
        static let x1: CGFloat = 8
        static let x2: CGFloat = 16
        static let x3: CGFloat = 24
        static let x4: CGFloat = 32
        static let x5: CGFloat = 40
        static let x6: CGFloat = 48
        static let x8: CGFloat = 64
    }

    enum Corner {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    enum Elevation {
        static let low: CGFloat = 6
        static let mid: CGFloat = 14
        static let high: CGFloat = 26
    }

    enum Opacity {
        static let hairline: Double = 0.12
        static let muted: Double = 0.55
        static let strong: Double = 0.86
    }

    enum Duration {
        static let instant: Double = 0.12
        static let quick: Double = 0.20
        static let normal: Double = 0.32
        static let slow: Double = 0.52
    }

    /// ظل موحّد يحترم الوضع الليلي.
    static func shadow(_ scheme: ColorScheme, level: CGFloat = Elevation.mid) -> Color {
        scheme == .dark ? Color.black.opacity(0.50) : Color.black.opacity(0.10)
    }
}

// MARK: - 52. مقياس طباعي هرمي (8 أحجام ثابتة النسب)

enum TigerType {

    struct Style {
        let size: CGFloat
        let weight: Font.Weight
        let tracking: CGFloat
        let lineHeight: CGFloat
    }

    static let display = Style(size: 34, weight: .bold, tracking: -0.6, lineHeight: 1.15)
    static let title1 = Style(size: 28, weight: .bold, tracking: -0.4, lineHeight: 1.18)
    static let title2 = Style(size: 22, weight: .semibold, tracking: -0.2, lineHeight: 1.22)
    static let title3 = Style(size: 19, weight: .semibold, tracking: -0.1, lineHeight: 1.26)
    static let body = Style(size: 16, weight: .regular, tracking: 0, lineHeight: 1.40)
    static let callout = Style(size: 15, weight: .medium, tracking: 0.1, lineHeight: 1.34)
    static let caption = Style(size: 13, weight: .regular, tracking: 0.2, lineHeight: 1.30)
    static let micro = Style(size: 11, weight: .semibold, tracking: 0.6, lineHeight: 1.24)

    /// 65. تباعد أسطر محسّن للعربية — الحروف العربية تحتاج مساحة أكبر.
    static func lineSpacing(for style: Style, isArabic: Bool) -> CGFloat {
        let ratio = isArabic ? max(style.lineHeight, 1.9) : style.lineHeight
        return max(0, (ratio - 1.0) * style.size)
    }

    static func font(_ style: Style, isArabic: Bool = TigerLocale.isArabic) -> Font {
        // 61. خط عربي مخصّص للعناوين مع بديل نظامي عند غيابه.
        if isArabic, style.size >= 19, let custom = TigerFonts.arabicHeadline {
            return .custom(custom, size: style.size, relativeTo: .title2).weight(style.weight)
        }
        return .system(size: style.size, weight: style.weight, design: .default)
    }
}

/// 61. تسجيل الخطوط العربية المرفقة (Cairo / Tajawal) إن وُجدت داخل الحزمة.
enum TigerFonts {
    static let arabicHeadline: String? = {
        for name in ["Cairo-Bold", "Tajawal-Bold", "Cairo-SemiBold"] {
            #if canImport(UIKit)
            if UIFont(name: name, size: 17) != nil { return name }
            #else
            return name
            #endif
        }
        return nil
    }()
}

enum TigerLocale {
    /// هل لغة الواجهة الحالية عربية؟
    static var isArabic: Bool {
        let stored = UserDefaults.standard.string(forKey: "app.selected_language") ?? "system"
        if stored == "ar" { return true }
        if stored != "system" { return false }
        let code = Locale.preferredLanguages.first ?? "en"
        return code.lowercased().hasPrefix("ar")
    }

    static var isRTL: Bool { isArabic }
}

// MARK: - 53. مقياس حركة موحّد

enum TigerMotion {

    static let fast = Animation.timingCurve(0.2, 0.0, 0.0, 1.0, duration: DT.Duration.quick)
    static let standard = Animation.spring(response: 0.36, dampingFraction: 0.82)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.90)
    static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.72)
    static let slow = Animation.easeInOut(duration: DT.Duration.slow)
    /// Short alias used by the player overlays.
    static let quick = Animation.timingCurve(0.2, 0.0, 0.0, 1.0, duration: DT.Duration.quick)

    /// يحترم «تقليل الحركة» في إعدادات النظام.
    static func respectingReduceMotion(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    static var reduceMotion: Bool {
        #if canImport(UIKit)
        return UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
}

// MARK: - 55. دليل نمط حيّ (Style Guide)

struct StyleGuideView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var accent: Color = TigerTheme.gold

    private let typeSamples: [(String, TigerType.Style)] = [
        ("Display", TigerType.display),
        ("Title 1", TigerType.title1),
        ("Title 2", TigerType.title2),
        ("Title 3", TigerType.title3),
        ("Body", TigerType.body),
        ("Callout", TigerType.callout),
        ("Caption", TigerType.caption),
        ("Micro", TigerType.micro)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DT.Space.x3) {
                section(L("style.title")) {
                    VStack(alignment: .leading, spacing: DT.Space.x2) {
                        ForEach(Array(typeSamples.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.0)
                                    .font(TigerType.font(item.1))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(item.1.size))pt")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                section(L("style.colors")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: DT.Space.x1)], spacing: DT.Space.x1) {
                        swatch(TigerTheme.brand, "brand")
                        swatch(TigerTheme.brandLight, "brandLight")
                        swatch(TigerTheme.gold, "gold")
                        swatch(TigerTheme.goldLight, "goldLight")
                        swatch(TigerTheme.ink, "ink")
                        swatch(TigerTheme.inkSoft, "inkSoft")
                    }
                }

                section(L("style.spacing")) {
                    VStack(alignment: .leading, spacing: DT.Space.x1) {
                        ForEach([DT.Space.x1, DT.Space.x2, DT.Space.x3, DT.Space.x4, DT.Space.x5], id: \.self) { value in
                            HStack(spacing: DT.Space.x1) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(accent.opacity(0.35))
                                    .frame(width: value, height: 14)
                                Text("\(Int(value))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                section(L("style.components")) {
                    VStack(spacing: DT.Space.x2) {
                        Button(L("common.ok")) { }
                            .buttonStyle(TigerPrimaryButtonStyle())
                        Button(L("common.cancel")) { }
                            .buttonStyle(TigerSecondaryButtonStyle())
                        TigerGlassCard {
                            Text(L("style.glass_sample"))
                                .font(TigerType.font(TigerType.callout))
                        }
                    }
                }
            }
            .padding(DT.Space.x2)
        }
        .background(TigerTheme.ink.opacity(scheme == .dark ? 0.0 : 0.03))
        .navigationTitle(L("style.title"))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DT.Space.x2) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(DT.Space.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DT.Corner.md, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous)
                .fill(color)
                .frame(height: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
            Text(name)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - 56 / 57 / 58 / 59 / 60 — الألوان والثيمات

/// 56. لوحة نهارية مصمّمة خصيصاً (ليست عكس ألوان).
enum TigerDayPalette {
    static let canvas = Color(red: 0.965, green: 0.960, blue: 0.945)
    static let surface = Color.white
    static let surfaceAlt = Color(red: 0.925, green: 0.918, blue: 0.900)
    static let primaryText = Color(red: 0.10, green: 0.11, blue: 0.12)
    static let secondaryText = Color(red: 0.36, green: 0.37, blue: 0.39)
    static let hairline = Color(red: 0.80, green: 0.79, blue: 0.76)
    static let brandOnLight = Color(red: 0.03, green: 0.36, blue: 0.28)
    static let goldOnLight = Color(red: 0.62, green: 0.44, blue: 0.00)
}

/// 58. ثيم تلقائي حسب الوقت (نهار / ليل).
enum TigerTimeTheme {
    static var prefersDark: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 19 || hour < 6
    }

    /// يعمل فقط عندما يكون المستخدم مختاراً «تلقائي».
    static func resolvedScheme(selected: ThemeManager.Appearance) -> ColorScheme? {
        switch selected {
        case .system: return prefersDark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 59. لوحة صديقة لعمى الألوان — تمييز بالأشكال لا بالألوان فقط.
enum TigerColorBlindPalette {
    static let success = Color(red: 0.10, green: 0.55, blue: 0.42)
    static let warning = Color(red: 0.85, green: 0.58, blue: 0.05)
    static let danger = Color(red: 0.80, green: 0.22, blue: 0.20)
    static let info = Color(red: 0.15, green: 0.42, blue: 0.80)

    static func symbol(for kind: String) -> String {
        switch kind {
        case "success": return "checkmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "danger": return "xmark.octagon.fill"
        default: return "info.circle.fill"
        }
    }
}

/// 60. تدرّج ذهبي متحرك يحاكي انعكاس المعدن الحقيقي.
struct TigerGoldShimmerGradient: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: TigerTheme.gold.opacity(0.55), location: 0.0),
                    .init(color: TigerTheme.goldLight, location: 0.45),
                    .init(color: Color.white.opacity(0.95), location: 0.50),
                    .init(color: TigerTheme.goldLight, location: 0.55),
                    .init(color: TigerTheme.gold.opacity(0.55), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 2)
            .offset(x: phase * geo.size.width)
        }
        .mask(Rectangle())
        .onAppear {
            guard !TigerMotion.reduceMotion else { return }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

/// 57. استخراج اللون السائد من غلاف الفيلم لتلوين خلفية التفاصيل تدريجياً.
enum DominantColorExtractor {

    #if canImport(CoreImage)
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func color(from image: UIImage?) -> Color? {
        guard let image, let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)
        let filter = CIFilter.areaAverage()
        filter.inputImage = ci
        filter.extent = ci.extent
        guard let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        // ارفع التشبّع قليلاً حتى لا تبدو الخلفية رمادية.
        return Color(red: min(1, r * 1.25), green: min(1, g * 1.25), blue: min(1, b * 1.25))
    }
    #else
    static func color(from image: Any?) -> Color? { nil }
    #endif

    /// خلفية متدرّجة من اللون السائد إلى الأسود.
    static func backdrop(_ color: Color?) -> LinearGradient {
        let base = color ?? TigerTheme.ink
        return LinearGradient(
            colors: [base.opacity(0.55), TigerTheme.ink.opacity(0.96)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// 63. أرقام عربية / لاتينية قابلة للتبديل.
enum TigerNumerals {
    static var prefersArabicDigits: Bool {
        UserDefaults.standard.bool(forKey: "app.arabicDigits")
    }

    static func string(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if prefersArabicDigits {
            formatter.locale = Locale(identifier: "ar_EG")
        } else {
            formatter.locale = Locale(identifier: "en_US_POSIX")
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(string(h)):\(String(format: "%02d", m)):\(String(format: "%02d", s))"
        }
        return "\(string(m)):\(String(format: "%02d", s))"
    }
}

/// 64. معالجة العناوين المختلطة عربي/إنجليزي بلا تشويه اتجاه.
struct BidiText: View {
    let text: String
    var style: TigerType.Style = TigerType.body

    private var isMixed: Bool {
        let hasArabic = text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
        let hasLatin = text.unicodeScalars.contains { (0x0041...0x007A).contains($0.value) }
        return hasArabic && hasLatin
    }

    var body: some View {
        Text(text)
            .font(TigerType.font(style))
            .multilineTextAlignment(isMixed ? .leading : (TigerLocale.isRTL ? .trailing : .leading))
            .lineSpacing(TigerType.lineSpacing(for: style, isArabic: TigerLocale.isArabic))
            .environment(\.layoutDirection, isMixed ? .leftToRight : (TigerLocale.isRTL ? .rightToLeft : .leftToRight))
    }
}

/// 62. حاوية تحترم Dynamic Type حتى 200% بلا كسر التخطيط.
struct ScaledTextContainer<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: () -> Content

    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }

    var body: some View {
        Group {
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: DT.Space.x1) { content() }
            } else {
                content()
            }
        }
    }
}
