import SwiftUI
import Combine

/// مدير المظهر: فاتح / داكن / تلقائي + لون التمييز (Accent).
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return L("theme.system")
            case .light: return L("theme.light")
            case .dark: return L("theme.dark")
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    enum Accent: String, CaseIterable, Identifiable {
        case tiger, gold, ocean, sunset, violet, mint
        var id: String { rawValue }

        var label: String {
            switch self {
            case .tiger: return L("accent.tiger")
            case .gold: return L("accent.gold")
            case .ocean: return L("accent.ocean")
            case .sunset: return L("accent.sunset")
            case .violet: return L("accent.violet")
            case .mint: return L("accent.mint")
            }
        }

        var color: Color {
            switch self {
            case .tiger: return TigerTheme.brandLight
            case .gold: return TigerTheme.gold
            case .ocean: return Color(red: 0.12, green: 0.45, blue: 0.85)
            case .sunset: return Color(red: 0.95, green: 0.42, blue: 0.20)
            case .violet: return Color(red: 0.55, green: 0.32, blue: 0.92)
            case .mint: return Color(red: 0.15, green: 0.72, blue: 0.58)
            }
        }

        var gradient: LinearGradient {
            LinearGradient(
                colors: [color, color.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var accent: Accent {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }

    @Published var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) }
    }

    @Published var largeText: Bool {
        didSet { defaults.set(largeText, forKey: Keys.largeText) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appearance = "app.theme"
        static let accent = "app.accent"
        static let reduceMotion = "app.reduceMotion"
        static let largeText = "app.largeText"
    }

    private init() {
        let rawAppearance = defaults.string(forKey: Keys.appearance) ?? Appearance.system.rawValue
        appearance = Appearance(rawValue: rawAppearance) ?? .system

        let rawAccent = defaults.string(forKey: Keys.accent) ?? Accent.tiger.rawValue
        accent = Accent(rawValue: rawAccent) ?? .tiger

        reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        largeText = defaults.bool(forKey: Keys.largeText)
    }

    var colorScheme: ColorScheme? { appearance.colorScheme }

    var dynamicTypeSize: DynamicTypeSize {
        largeText ? .accessibility2 : .large
    }
}

// MARK: - شاشة إعدادات المظهر

struct ThemeSettingsView: View {
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            TigerAuroraBackground()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    appearanceSection
                    accentSection
                    accessibilitySection
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle(L("settings.appearance"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle(L("settings.appearance"))

            HStack(spacing: Spacing.sm) {
                ForEach(ThemeManager.Appearance.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            theme.appearance = option
                        }
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Image(systemName: option.icon)
                                .font(.system(size: 22))
                            Text(option.label)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .foregroundStyle(theme.appearance == option ? Color.white : Color.white.opacity(0.72))
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(theme.appearance == option ? AnyShapeStyle(theme.accent.gradient) : AnyShapeStyle(.ultraThinMaterial))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(theme.appearance == option ? theme.accent.color : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle(L("settings.accent"))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3), spacing: Spacing.sm) {
                ForEach(ThemeManager.Accent.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            theme.accent = option
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(option.gradient)
                                .frame(width: 18, height: 18)
                            Text(option.label)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(theme.accent == option ? option.color : Color.white.opacity(0.12), lineWidth: theme.accent == option ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle(L("settings.accessibility"))

            Toggle(isOn: $theme.reduceMotion) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("settings.reduce_motion"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("settings.reduce_motion.desc"))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .tint(theme.accent.color)

            Toggle(isOn: $theme.largeText) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("settings.large_text"))
                        .font(.subheadline.weight(.semibold))
                    Text(L("settings.large_text.desc"))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .tint(theme.accent.color)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.white.opacity(0.72))
            .textCase(.uppercase)
    }
}
