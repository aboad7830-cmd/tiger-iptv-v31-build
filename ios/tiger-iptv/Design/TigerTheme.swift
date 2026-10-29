import SwiftUI

/// نظام التصميم الموحّد لتطبيق TIGER IPTV.
/// كل الألوان والمسافات والخطوط تُسحب من هنا حتى تبقى الواجهة متّسقة
/// عبر iPhone وiPad وMac وApple TV.
enum TigerTheme {

    // MARK: - الألوان الأساسية

    /// الأخضر العميق — لون العلامة الأساسي.
    static let brand = Color(red: 0.04, green: 0.30, blue: 0.24)

    /// الأخضر الفاتح — للتمييز والتدرّجات.
    static let brandLight = Color(red: 0.09, green: 0.55, blue: 0.42)

    /// الذهبي — لون التمييز (Accent) المستخدم في الأزرار والعناوين.
    /// Brand orange (#FF9900) — the primary accent of the Tiger iptv identity.
    static let orange = Color(red: 1.00, green: 0.60, blue: 0.00)
    /// Softer orange used for gradients and glows.
    static let orangeLight = Color(red: 1.00, green: 0.72, blue: 0.26)
    /// Deep burnt orange for pressed states and dark surfaces.
    static let orangeDeep = Color(red: 0.85, green: 0.42, blue: 0.00)
    static let orangeGradient = LinearGradient(
        colors: [orangeLight, orange, orangeDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let gold = Color(red: 0.88, green: 0.64, blue: 0.00)

    /// الذهبي الفاتح — للتدرّجات والوميض.
    static let goldLight = Color(red: 1.00, green: 0.82, blue: 0.30)

    /// خلفية داكنة عميقة.
    static let ink = Color(red: 0.05, green: 0.06, blue: 0.07)

    /// خلفية ثانوية.
    static let inkSoft = Color(red: 0.10, green: 0.11, blue: 0.13)

    // MARK: - التدرّجات

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brand, brandLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [gold, goldLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var splashGradient: LinearGradient {
        LinearGradient(
            colors: [ink, Color(red: 0.08, green: 0.05, blue: 0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - المسافات

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - أنصاف الأقطار

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - الظلال

    static func cardShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.10)
    }
}

// MARK: - اختصارات عامة

/// اختصارات حتى تُستخدم `Spacing.md` و`Radius.lg` مباشرة في الواجهات.
typealias Spacing = TigerTheme.Spacing
typealias Radius = TigerTheme.Radius

// MARK: - بطاقة زجاجية قابلة لإعادة الاستخدام

/// حاوية بخلفية زجاجية (Liquid Glass) مع حدود رقيقة وظل ناعم.
struct TigerGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = TigerTheme.Radius.lg
    var padding: CGFloat = TigerTheme.Spacing.md
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(scheme == .dark ? 0.18 : 0.55),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: TigerTheme.cardShadow(scheme), radius: 18, x: 0, y: 8)
            }
    }
}

// MARK: - زر أساسي

struct TigerPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: TigerTheme.Radius.md, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(TigerTheme.brandGradient)
                                  : AnyShapeStyle(Color.gray.opacity(0.35)))
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - زر ثانوي

struct TigerSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(TigerTheme.brand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: TigerTheme.Radius.md, style: .continuous)
                    .strokeBorder(TigerTheme.brand.opacity(0.5), lineWidth: 1.4)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - ألوان متكيّفة (تباين مضمون على الفاتح والداكن)

/// مجموعة رموز لونية تتغيّر تلقائيًا مع مظهر النظام، حتى يبقى النص
/// مقروءًا سواء كانت الخلفية بيضاء أو داكنة.
enum TigerAdaptive {
    // النصوص
    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.09, green: 0.10, blue: 0.12)
    }
    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.70) : Color(red: 0.30, green: 0.32, blue: 0.36)
    }
    static func tertiaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.45) : Color(red: 0.45, green: 0.47, blue: 0.52)
    }

    // الأسطح
    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.045)
    }
    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
    static func chipFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.055)
    }
    static func chipStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }
    static func fieldFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    // خلفية الشاشة
    @ViewBuilder
    static func background(_ scheme: ColorScheme) -> some View {
        if scheme == .dark {
            TigerAuroraBackground()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.98, blue: 0.94),
                    Color(red: 0.98, green: 0.96, blue: 0.93),
                    Color(red: 1.00, green: 0.97, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(TigerTheme.orange.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: 120, y: -140)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(TigerTheme.brand.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: -120, y: 140)
            }
            .ignoresSafeArea()
        }
    }
}
