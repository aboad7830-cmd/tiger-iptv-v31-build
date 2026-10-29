//
//  TigerPlatform.swift
//  Tiger IPTV
//
//  طبقة توافق موحّدة لكل أجهزة Apple: iPhone / iPad / Mac (Catalyst + Designed for iPad)
//  / Apple TV / Vision Pro. كل مكان في التطبيق يقرأ من هنا بدلًا من UIKit مباشرة،
//  حتى تبقى المسافات والأحجام والتنقّل متناسقة على كل جهاز.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - نوع الجهاز

enum TigerPlatformKind: String, CaseIterable, Identifiable, Sendable {
    case phone
    case pad
    case mac
    case tv
    case vision
    case unknown

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .phone: return "آيفون"
        case .pad: return "آيباد"
        case .mac: return "ماك"
        case .tv: return "Apple TV"
        case .vision: return "Vision Pro"
        case .unknown: return "جهاز Apple"
        }
    }

    var symbol: String {
        switch self {
        case .phone: return "iphone"
        case .pad: return "ipad"
        case .mac: return "laptopcomputer"
        case .tv: return "appletv"
        case .vision: return "visionpro"
        case .unknown: return "desktopcomputer"
        }
    }

    /// أجهزة التلفاز والماك تعمل بلمسة تركيز (Focus Engine) أو مؤشر، لا باللمس.
    var usesFocusEngine: Bool { self == .tv }
    var usesPointer: Bool { self == .mac || self == .vision }
    var isCompactWidth: Bool { self == .phone }
}

// MARK: - منصة التشغيل

enum TigerPlatform {
    static var kind: TigerPlatformKind {
        #if os(tvOS)
        return .tv
        #elseif os(visionOS)
        return .vision
        #elseif targetEnvironment(macCatalyst)
        return .mac
        #elseif os(macOS)
        return .mac
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone
        #else
        return .unknown
        #endif
    }

    static var isPhone: Bool { kind == .phone }
    static var isPad: Bool { kind == .pad }
    static var isMac: Bool { kind == .mac }
    static var isTV: Bool { kind == .tv }
    static var isVision: Bool { kind == .vision }

    /// مقياس الشاشة (Retina) — يُستخدم لتحجيم فكّ ترميز الصور.
    static var screenScale: CGFloat {
        #if canImport(UIKit)
        return max(UIScreen.main.scale, 1)
        #elseif canImport(AppKit)
        return max(NSScreen.main?.backingScaleFactor ?? 2, 1)
        #else
        return 2
        #endif
    }

    /// حجم الشاشة/النافذة الحالي.
    static var screenSize: CGSize {
        #if canImport(UIKit)
        return UIScreen.main.bounds.size
        #elseif canImport(AppKit)
        return NSScreen.main?.frame.size ?? CGSize(width: 1280, height: 800)
        #else
        return CGSize(width: 390, height: 844)
        #endif
    }

    static var deviceModel: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #elseif canImport(AppKit)
        return "Mac"
        #else
        return kind.arabicName
        #endif
    }

    static var systemDescription: String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #elseif canImport(AppKit)
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
        #else
        return "Apple"
        #endif
    }

    /// الاسم الظاهر في التقارير.
    static var displayName: String {
        #if os(tvOS)
        return "Apple TV"
        #elseif os(visionOS)
        return "Vision Pro"
        #elseif targetEnvironment(macCatalyst)
        return "Mac (Catalyst)"
        #elseif os(macOS)
        return "Mac"
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        return "Apple"
        #endif
    }

    static var supportsHaptics: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    static var supportsPiP: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// موضع أزرار شريط التنقّل — `.primaryAction` يعمل على كل المنصات.
    static var trailingPlacement: ToolbarItemPlacement { .primaryAction }

    /// موضع حقل البحث — `.navigationBarDrawer` غير متاح خارج iOS.
    static var searchPlacement: SearchFieldPlacement {
        #if os(iOS)
        return .navigationBarDrawer(displayMode: .always)
        #else
        return .automatic
        #endif
    }

    /// هل ندعم شريط التبويبات الجانبي (iPad/Mac)؟
    static var supportsSidebarTabs: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// هل نعرض أزرار التحكّم باللمس (السحب للتقديم/الصوت)؟
    static var supportsTouchGestures: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// هل نعرض لوحة المفاتيح/اختصاراتها؟
    static var supportsKeyboardShortcuts: Bool {
        #if os(iOS)
        return true
        #elseif os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// مساحة آمنة تقريبية (تُستخدم للتخطيطات المخصّصة).
    static var bottomSafeInset: CGFloat {
        #if os(iOS)
        return 16
        #else
        return 24
        #endif
    }

    /// أقصى عرض محتوى مريح للقراءة على الشاشات الكبيرة.
    static var readableMaxWidth: CGFloat {
        switch kind {
        case .tv: return 1500
        case .mac: return 1320
        case .pad: return 1100
        case .vision: return 1280
        case .phone: return .infinity
        case .unknown: return .infinity
        }
    }
}

// MARK: - الاهتزاز (Haptics) بشكل آمن

enum TigerHaptics {
    static func tap(_ intensity: Int = 1) {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: intensity > 1 ? .medium : .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

// MARK: - مؤشّرات التخطيط المتكيّف

/// كل المقاسات المشتقّة من الشاشة + حجم الفئة. تُمرَّر عبر البيئة حتى تتحدّث تلقائيًا
/// عند تغيير حجم النافذة على iPad/Mac أو تدوير الجهاز.
struct TigerAdaptiveMetrics: Equatable, Sendable {
    let width: CGFloat
    let height: CGFloat
    let sizeClass: UserInterfaceSizeClass?
    let platform: TigerPlatformKind

    static let fallback = TigerAdaptiveMetrics(
        width: TigerPlatform.screenSize.width,
        height: TigerPlatform.screenSize.height,
        sizeClass: nil,
        platform: TigerPlatform.kind
    )

    var isLandscape: Bool { width > height }
    var isWide: Bool { width >= 700 }
    var isVeryWide: Bool { width >= 1000 }

    /// هامش المحتوى الجانبي: 16 على الآيفون، 24 على الآيباد، 32 على الماك/التلفاز.
    var contentPadding: CGFloat {
        switch platform {
        case .phone: return 16
        case .pad: return isLandscape ? 28 : 22
        case .mac: return 32
        case .tv: return 60
        case .vision: return 36
        case .unknown: return 16
        }
    }

    var sectionSpacing: CGFloat {
        switch platform {
        case .phone: return 18
        case .pad: return 22
        case .mac: return 26
        case .tv: return 34
        case .vision: return 26
        case .unknown: return 18
        }
    }

    var cardSpacing: CGFloat {
        platform == .tv ? 22 : (platform == .pad ? 16 : 14)
    }

    /// عدد الأعمدة في الشبكات — يضمن تناسق الآيفون/الآيباد/الماك/التلفاز.
    var gridColumns: Int {
        switch platform {
        case .phone:
            if width >= 430 { return 3 }
            return isLandscape ? 5 : 3
        case .pad:
            if isLandscape { return width >= 1100 ? 6 : 5 }
            return 4
        case .mac:
            return width >= 1400 ? 7 : (width >= 1100 ? 6 : 5)
        case .tv:
            return 7
        case .vision:
            return 6
        case .unknown:
            return 3
        }
    }

    /// مقياس عام للبطاقات، مبني على أقصر ضلع مع مرجع 834pt (آيباد 11").
    var layoutScale: CGFloat {
        let reference: CGFloat
        switch platform {
        case .tv: reference = 1920
        case .mac: reference = 1440
        case .vision: reference = 1280
        default: reference = 834
        }
        let short = min(width, height)
        let raw = short / reference
        let lower: CGFloat = platform == .phone ? 0.46 : 0.62
        return min(1.35, max(lower, raw))
    }

    var shelfPosterWidth: CGFloat { (200 * layoutScale).rounded() }
    var shelfPosterHeight: CGFloat { (300 * layoutScale).rounded() }
    var shelfRowHeight: CGFloat { shelfPosterHeight + (platform == .tv ? 92 : 64) }

    var heroHeight: CGFloat {
        switch platform {
        case .phone: return isLandscape ? 240 : 300
        case .pad: return isLandscape ? 340 : 380
        case .mac: return 400
        case .tv: return 520
        case .vision: return 420
        case .unknown: return 300
        }
    }

    var titleFont: Font {
        .system(size: platform == .tv ? 34 : (platform == .mac ? 28 : 24), weight: .bold, design: .rounded)
    }

    var sectionFont: Font {
        .system(size: platform == .tv ? 26 : 19, weight: .bold, design: .rounded)
    }

    var bodyFont: Font {
        .system(size: platform == .tv ? 20 : 15, weight: .regular)
    }

    var maxContentWidth: CGFloat? {
        let limit = TigerPlatform.readableMaxWidth
        return limit.isFinite ? limit : nil
    }

    var usesSidebar: Bool {
        platform == .pad || platform == .mac || platform == .vision
    }
}

private struct TigerAdaptiveMetricsKey: EnvironmentKey {
    static var defaultValue: TigerAdaptiveMetrics { .fallback }
}

extension EnvironmentValues {
    var tigerMetrics: TigerAdaptiveMetrics {
        get { self[TigerAdaptiveMetricsKey.self] }
        set { self[TigerAdaptiveMetricsKey.self] = newValue }
    }
}

// MARK: - View modifiers مشتركة

extension View {
    /// إخفاء شريط التبويبات عند الدخول لشاشة تفاصيل — غير متاح على tvOS/Mac.
    @ViewBuilder
    func tigerHiddenTabBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }

    /// عنوان تنقّل مصغّر — غير مدعوم على tvOS.
    @ViewBuilder
    func tigerInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// بطاقة قابلة للتركيز على Apple TV (Focus Engine) مع تأثير تكبير خفيف.
    @ViewBuilder
    func tigerFocusCard(cornerRadius: CGFloat = 18) -> some View {
        #if os(tvOS)
        self
            .focusable(true)
            .buttonStyle(.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        #else
        self
        #endif
    }

    /// حدّ أقصى لعرض المحتوى مع توسيطه — يمنع تمدّد الصفوف على الماك/التلفاز.
    @ViewBuilder
    func tigerReadableWidth(_ maxWidth: CGFloat? = nil) -> some View {
        let limit = maxWidth ?? TigerPlatform.readableMaxWidth
        if limit.isFinite {
            self
                .frame(maxWidth: limit)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }

    /// هامش جانبي متكيّف موحّد.
    func tigerContentPadding(_ metrics: TigerAdaptiveMetrics? = nil) -> some View {
        padding(.horizontal, (metrics ?? .fallback).contentPadding)
    }

    /// إيماءة تركيز بسيطة على tvOS (تكبير عند التركيز).
    @ViewBuilder
    func tigerTVHoverEffect() -> some View {
        #if os(tvOS)
        self.hoverEffect(.highlight)
        #else
        self
        #endif
    }
}

// MARK: - شبكة متجاوبة تعتمد على المقاسات

struct TigerResponsiveGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    var minCellWidth: CGFloat = 150
    var spacing: CGFloat = 14
    @ViewBuilder var cell: (Item) -> Cell

    @Environment(\.tigerMetrics) private var metrics

    private var columns: [GridItem] {
        let available = max(metrics.width - metrics.contentPadding * 2, 280)
        let count = max(2, min(metrics.gridColumns, Int(available / minCellWidth)))
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                cell(item)
            }
        }
        .tigerContentPadding(metrics)
    }
}

// MARK: - قارئ بيئة المقاسات

/// يحدّث `tigerMetrics` تلقائيًا عند تغيّر حجم النافذة أو الفئة.
struct TigerAdaptiveMetricsReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: (TigerAdaptiveMetrics) -> Content

    var body: some View {
        GeometryReader { geo in
            let metrics = TigerAdaptiveMetrics(
                width: geo.size.width,
                height: geo.size.height,
                sizeClass: horizontalSizeClass,
                platform: TigerPlatform.kind
            )
            content(metrics)
                .environment(\.tigerMetrics, metrics)
                .environment(\.posterMetrics, PosterMetrics(metrics: metrics))
        }
    }
}

// MARK: - لوحة معلومات المنصّة

struct TigerPlatformInfoCard: View {
    @Environment(\.tigerMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: TigerPlatform.kind.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TigerTheme.orange)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(TigerTheme.orange.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(TigerPlatform.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(TigerPlatform.systemDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(metrics.width))×\(Int(metrics.height))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 14) {
                infoPill(icon: "square.grid.3x3", text: "\(metrics.gridColumns) أعمدة")
                infoPill(icon: "textformat.size", text: "خط \(Int(metrics.layoutScale * 100))%")
                infoPill(icon: metrics.usesSidebar ? "sidebar.left" : "rectangle.bottomthird.inset.filled",
                         text: metrics.usesSidebar ? "شريط جانبي" : "تبويبات")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    TigerAdaptiveMetricsReader { _ in
        VStack {
            TigerPlatformInfoCard()
            Text("TIGER IPTV").font(.largeTitle.bold())
        }
        .padding()
    }
}

// MARK: - مُعدِّل حقن القياسات

/// يُغلّف أي واجهة بـ `TigerAdaptiveMetricsReader` ويحقن
/// `\.tigerMetrics` و`\.posterMetrics` تلقائيًا.
private struct TigerAdaptiveMetricsModifier: ViewModifier {
    func body(content: Content) -> some View {
        TigerAdaptiveMetricsReader { _ in content }
    }
}

extension View {
    /// استخدمه على جذر الشاشة (أو الجذر العام) لتصبح القياسات متاحة في كل الشجرة.
    func tigerAdaptiveMetrics() -> some View {
        modifier(TigerAdaptiveMetricsModifier())
    }
}
