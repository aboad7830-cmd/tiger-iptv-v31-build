import SwiftUI

// MARK: - 66. انتقال Hero للبوستر (شبكة ← تفاصيل)
//
// يعتمد على `matchedGeometryEffect` مع namespace واحد في الجذر،
// فيتوسّع البوستر من مكانه في الشبكة إلى رأس شاشة التفاصيل بلا قطع.

struct TigerHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var tigerHeroNamespace: Namespace.ID? {
        get { self[TigerHeroNamespaceKey.self] }
        set { self[TigerHeroNamespaceKey.self] = newValue }
    }
}

struct TigerHeroSource: ViewModifier {
    let id: String
    @Environment(\.tigerHeroNamespace) private var ns

    func body(content: Content) -> some View {
        if let ns {
            content.matchedGeometryEffect(id: "hero-\(id)", in: ns)
        } else {
            content
        }
    }
}

extension View {
    /// ضعه على البوستر داخل الشبكة وعلى البوستر داخل شاشة التفاصيل بنفس المعرّف.
    func tigerHero(id: String) -> some View { modifier(TigerHeroSource(id: id)) }
}

// MARK: - 67. Parallax عند التمرير

struct TigerParallaxHeader<Content: View>: View {
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let stretch = minY > 0 ? minY : 0
            let offset = minY > 0 ? -minY * 0.35 : -minY * 0.18

            content()
                .frame(width: geo.size.width, height: height + stretch)
                .clipped()
                .offset(y: offset)
                .scaleEffect(1 + (stretch / max(height, 1)) * 0.25, anchor: .bottom)
        }
        .frame(height: height)
    }
}

// MARK: - 68. انتقالات موجّهة بالاتجاه

enum TigerEdgeDirection {
    case forward, backward

    var insertionEdge: Edge {
        self == .forward ? .trailing : .leading
    }

    var removalEdge: Edge {
        self == .forward ? .leading : .trailing
    }

    var transition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }
}

/// 69. حركة تفاعلية بالسحب — تقلّص تدريجي بمقاومة طبيعية.
struct TigerInteractiveDismiss: ViewModifier {
    @Binding var isPresented: Bool
    @State private var drag: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: max(0, drag))
            .scaleEffect(1 - min(0.08, max(0, drag) / 2600))
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        drag = value.translation.height
                    }
                    .onEnded { value in
                        let shouldClose = value.translation.height > 120
                            || value.predictedEndTranslation.height > 260
                        withAnimation(TigerMotion.standard) {
                            if shouldClose {
                                isPresented = false
                            }
                            drag = 0
                        }
                        if shouldClose { HapticEngine.play(.soft) }
                    }
            )
    }
}

extension View {
    func tigerInteractiveDismiss(_ isPresented: Binding<Bool>) -> some View {
        modifier(TigerInteractiveDismiss(isPresented: isPresented))
    }
}

// MARK: - 70. حركة تعمل 120Hz (TimelineView على ProMotion)

struct TigerSmoothPulse: View {
    var color: Color = TigerTheme.gold
    var size: CGFloat = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: TigerMotion.reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (sin(t * 2.4) + 1) / 2
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .opacity(0.55 + 0.45 * phase)
                .scaleEffect(0.9 + 0.25 * phase)
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .accessibilityHidden(true)
    }
}

// MARK: - 72. شارات حالة على البوستر

enum TigerBadge: String, CaseIterable {
    case new, ultraHD, live, completed, downloaded

    var label: String {
        switch self {
        case .new: return L("badge.new")
        case .ultraHD: return "4K"
        case .live: return L("badge.live")
        case .completed: return L("badge.completed")
        case .downloaded: return L("badge.downloaded")
        }
    }

    var tint: Color {
        switch self {
        case .new: return TigerColorBlindPalette.info
        case .ultraHD: return TigerTheme.gold
        case .live: return TigerColorBlindPalette.danger
        case .completed: return TigerColorBlindPalette.success
        case .downloaded: return TigerColorBlindPalette.info
        }
    }
}

struct TigerBadgeView: View {
    let badge: TigerBadge

    var body: some View {
        HStack(spacing: 3) {
            if badge == .live {
                TigerSmoothPulse(color: .white, size: 5)
            }
            Text(badge.label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.4)
        }
        .foregroundStyle(badge == .ultraHD ? Color.black : Color.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            Capsule(style: .continuous)
                .fill(badge.tint.opacity(badge == .ultraHD ? 0.95 : 0.88))
        }
        .accessibilityLabel(badge.label)
    }
}

// MARK: - 73. حلقة تقدّم المشاهدة حول البوستر

struct TigerProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 3
    var tint: Color = TigerTheme.gold

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel(L("progress.watched"))
        .accessibilityValue("\(Int(min(1, max(0, progress)) * 100))%")
    }
}

// MARK: - 74. شبكة كثافة قابلة للتغيير

enum TigerGridDensity: String, CaseIterable, Identifiable {
    case comfortable, compact

    var id: String { rawValue }

    var columns: Int {
        #if os(tvOS)
        return self == .comfortable ? 5 : 7
        #elseif os(macOS)
        return self == .comfortable ? 4 : 6
        #else
        return self == .comfortable ? 3 : 5
        #endif
    }

    var label: String {
        self == .comfortable ? L("grid.comfortable") : L("grid.compact")
    }

    var icon: String {
        self == .comfortable ? "square.grid.2x2" : "square.grid.3x3.fill"
    }

    static var stored: TigerGridDensity {
        TigerGridDensity(rawValue: UserDefaults.standard.string(forKey: "app.gridDensity") ?? "") ?? .comfortable
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: "app.gridDensity")
    }
}

// MARK: - 75. بطاقة قناة بشعار واضح وبديل أنيق

struct TigerChannelBadge: View {
    let name: String
    let logoURL: URL?
    var size: CGFloat = 56

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    private var hue: Double {
        // لون ثابت مشتق من الاسم حتى لا يتغيّر بين التشغيلات.
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(sum % 360) / 360.0
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.55, brightness: 0.45),
                            Color(hue: hue, saturation: 0.70, brightness: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let logoURL {
                CachedImage(url: logoURL, width: size - 12, height: size - 12, cornerRadius: 4, contentMode: .fit)
                    .padding(6)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DT.Corner.sm, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .accessibilityLabel(name)
    }
}

// MARK: - 76. شريط تبويب عائم زجاجي

struct TigerFloatingTabBar<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    let icon: (Tab) -> String

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    guard selection != tab else { return }
                    HapticEngine.play(.selection)
                    withAnimation(TigerMotion.snappy) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: icon(tab))
                            .font(.system(size: 17, weight: .semibold))
                        Text(title(tab))
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? Color.black : Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selection == tab {
                            Capsule(style: .continuous)
                                .fill(TigerTheme.goldGradient)
                                .matchedGeometryEffect(id: "tab-pill", in: pill)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(tab))
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.28), radius: DT.Elevation.high, y: 10)
        }
        .padding(.horizontal, DT.Space.x3)
        .padding(.bottom, DT.Space.x1)
    }
}

// MARK: - 77. مشغّل مصغّر عائم

struct TigerMiniPlayer: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?
    var progress: Double = 0
    var isPlaying: Bool = true
    var onExpand: () -> Void = {}
    var onClose: () -> Void = {}
    var onTogglePlay: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: DT.Space.x1) {
            Group {
                if let artworkURL {
                    CachedImage(url: artworkURL, width: 40, height: 40, cornerRadius: 6, contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: DT.Corner.xs, style: .continuous)
                        .fill(TigerTheme.brandGradient)
                        .overlay {
                            Image(systemName: "tv.fill")
                                .foregroundStyle(.white.opacity(0.85))
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: DT.Corner.xs, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? L("player.pause") : L("player.play"))

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("common.close"))
        }
        .padding(.horizontal, DT.Space.x1)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: DT.Corner.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: DT.Corner.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: TigerTheme.cardShadow(scheme), radius: DT.Elevation.mid, y: 6)
        }
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                Capsule()
                    .fill(TigerTheme.gold)
                    .frame(width: geo.size.width * max(0, min(1, progress)), height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onExpand)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 80. رأس ذكي يتقلّص عند التمرير

struct TigerCollapsingHeader: View {
    let title: String
    let subtitle: String?
    let scrollOffset: CGFloat
    var expandedHeight: CGFloat = 120

    private var collapsed: Bool { scrollOffset < -40 }

    var body: some View {
        HStack(alignment: .bottom, spacing: DT.Space.x1) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TigerType.font(collapsed ? TigerType.title3 : TigerType.title1))
                    .lineLimit(1)
                if let subtitle, !collapsed {
                    Text(subtitle)
                        .font(TigerType.font(TigerType.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DT.Space.x2)
        .frame(height: collapsed ? 44 : expandedHeight, alignment: .bottom)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(collapsed ? 1 : 0)
                .ignoresSafeArea(edges: .top)
        }
        .animation(TigerMotion.standard, value: collapsed)
    }
}

// MARK: - 93. قوائم سياقية غنية + 92. تأثير Hover + 91. تركيز tvOS

struct TigerPosterContextActions {
    var onPlay: () -> Void = {}
    var onDownload: () -> Void = {}
    var onFavorite: () -> Void = {}
    var onShare: () -> Void = {}
}

struct TigerHoverEffect: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.02 : 1)
            .shadow(color: Color.black.opacity(hovering ? 0.30 : 0.0), radius: hovering ? 14 : 0, y: 6)
            .animation(TigerMotion.standard, value: hovering)
            #if os(macOS)
            .onHover { hovering = $0 }
            #endif
    }
}

extension View {
    func tigerHover() -> some View { modifier(TigerHoverEffect()) }
}

// MARK: - 94. دعم الشاشة الدائمة (Always-On) + 95. احترام الشريط الديناميكي

struct TigerSafeAreaAware<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
    }
}

/// يعرض شريط تقدّم رفيعاً دائماً على أجهزة Pro عندما تكون الشاشة الدائمة مفعّلة.
struct TigerAlwaysOnProgress: View {
    var progress: Double
    var isEnabled: Bool

    var body: some View {
        if isEnabled {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.10))
                    Rectangle()
                        .fill(TigerTheme.gold.opacity(0.85))
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
    }
}
