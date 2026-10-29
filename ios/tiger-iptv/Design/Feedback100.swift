import SwiftUI
#if canImport(UIKit)
import UIKit
import Combine
#endif

// MARK: - 86. نظام إشعارات Toast أنيق

enum TigerToastStyle {
    case success, info, warning, error

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return TigerColorBlindPalette.success
        case .info: return TigerColorBlindPalette.info
        case .warning: return TigerColorBlindPalette.warning
        case .error: return TigerColorBlindPalette.danger
        }
    }
}

struct TigerToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let style: TigerToastStyle

    static func == (lhs: TigerToast, rhs: TigerToast) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published private(set) var current: TigerToast?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ message: String, style: TigerToastStyle = .info, duration: Double = 2.4) {
        dismissTask?.cancel()
        withAnimation(TigerMotion.snappy) {
            current = TigerToast(message: message, style: style)
        }
        HapticEngine.play(style == .error ? .error : .success)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(TigerMotion.standard) { self?.current = nil }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(TigerMotion.standard) { current = nil }
    }
}

struct TigerToastOverlay: ViewModifier {
    @StateObject private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                HStack(spacing: DT.Space.x1) {
                    Image(systemName: toast.style.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(toast.style.tint)
                    Text(toast.message)
                        .font(TigerType.font(TigerType.callout))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, DT.Space.x2)
                .padding(.vertical, DT.Space.x1 + 2)
                .background {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(toast.style.tint.opacity(0.35), lineWidth: 1)
                        }
                        .shadow(color: Color.black.opacity(0.18), radius: DT.Elevation.mid, y: 6)
                }
                .padding(.top, DT.Space.x1)
                .padding(.horizontal, DT.Space.x2)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { center.dismiss() }
                .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

extension View {
    /// أضف هذا المعدّل مرة واحدة على الجذر.
    func tigerToastHost() -> some View { modifier(TigerToastOverlay()) }

    func tigerToast(_ message: String, style: TigerToastStyle = .info) {
        ToastCenter.shared.show(message, style: style)
    }
}

// MARK: - 87. اهتزاز لمسي مدرّس

enum HapticEngine {

    enum Kind {
        case success, warning, error, selection, soft, heavy
    }

    static func play(_ kind: Kind) {
        #if canImport(UIKit)
        switch kind {
        case .success:
            TigerHaptics.success()
        case .warning:
            TigerHaptics.warning()
        case .error:
            TigerHaptics.warning()
        case .selection:
            TigerHaptics.selection()
        case .soft:
            TigerHaptics.tap(1)
        case .heavy:
            TigerHaptics.tap(2)
        }
        #endif
    }

    // MARK: - Convenience wrappers

    static func success() { play(.success) }
    static func warning() { play(.warning) }
    static func error() { play(.error) }
    static func selection() { play(.selection) }
    static func soft() { play(.soft) }
    static func heavy() { play(.heavy) }
}

// MARK: - 88. حالات فراغ مرسومة

struct TigerEmptyState: View {
    var icon: String = "sparkles.tv"
    var title: String
    var message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: DT.Space.x2) {
            ZStack {
                Circle()
                    .fill(TigerTheme.gold.opacity(0.10))
                    .frame(width: 96, height: 96)
                Circle()
                    .strokeBorder(TigerTheme.gold.opacity(0.25), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(TigerTheme.goldGradient)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)
            }

            Text(title)
                .font(TigerType.font(TigerType.title3))
                .multilineTextAlignment(.center)

            Text(message)
                .font(TigerType.font(TigerType.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(TigerType.lineSpacing(for: TigerType.caption, isArabic: TigerLocale.isArabic))
                .padding(.horizontal, DT.Space.x3)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(TigerSecondaryButtonStyle())
                    .padding(.horizontal, DT.Space.x4)
                    .padding(.top, DT.Space.x1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Space.x5)
        .onAppear {
            withAnimation(TigerMotion.respectingReduceMotion(TigerMotion.gentle)) { appeared = true }
        }
    }
}

// MARK: - 89. حالات خطأ مفيدة

struct TigerErrorState: View {
    var title: String
    var reason: String
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil
    var supportTitle: String? = nil
    var onSupport: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DT.Space.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(TigerColorBlindPalette.warning)

            Text(title)
                .font(TigerType.font(TigerType.title3))
                .multilineTextAlignment(.center)

            Text(reason)
                .font(TigerType.font(TigerType.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(TigerType.lineSpacing(for: TigerType.caption, isArabic: TigerLocale.isArabic))
                .padding(.horizontal, DT.Space.x3)

            HStack(spacing: DT.Space.x1) {
                if let retryTitle, let onRetry {
                    Button(retryTitle, action: onRetry)
                        .buttonStyle(TigerPrimaryButtonStyle())
                }
                if let supportTitle, let onSupport {
                    Button(supportTitle, action: onSupport)
                        .buttonStyle(TigerSecondaryButtonStyle())
                }
            }
            .padding(.horizontal, DT.Space.x3)
            .padding(.top, DT.Space.x1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DT.Space.x5)
    }
}

// MARK: - 90. انتقال ناعم بين الحالات (تحميل ← محتوى ← خطأ)

enum TigerLoadPhase<Value> {
    case loading
    case loaded(Value)
    case failed(String)
}

struct TigerPhaseView<Value, Content: View>: View {
    let phase: TigerLoadPhase<Value>
    var retry: (() -> Void)? = nil
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        ZStack {
            switch phase {
            case .loading:
                TigerSkeletonGrid()
                    .transition(.opacity)
            case .loaded(let value):
                content(value)
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            case .failed(let reason):
                TigerErrorState(
                    title: L("state.error.title"),
                    reason: reason,
                    retryTitle: L("common.retry"),
                    onRetry: retry,
                    supportTitle: L("state.error.support"),
                    onSupport: nil
                )
                .transition(.opacity)
            }
        }
        .animation(TigerMotion.standard, value: phaseKey)
    }

    private var phaseKey: Int {
        switch phase {
        case .loading: return 0
        case .loaded: return 1
        case .failed: return 2
        }
    }
}

// MARK: - 71. هيكل تحميل Shimmer

struct TigerShimmer: ViewModifier {
    @State private var phase: CGFloat = -1.4

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: phase * geo.size.width)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
                .clipped()
            }
            .onAppear {
                guard !TigerMotion.reduceMotion else { return }
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

extension View {
    func tigerShimmer() -> some View { modifier(TigerShimmer()) }
}

/// بطاقة هيكلية واحدة.
struct TigerSkeletonCard: View {
    var height: CGFloat = 190

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RoundedRectangle(cornerRadius: DT.Corner.md, style: .continuous)
            .fill(Color.primary.opacity(scheme == .dark ? 0.12 : 0.07))
            .frame(height: height)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 110, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 70, height: 8)
                }
                .padding(DT.Space.x1)
            }
            .tigerShimmer()
    }
}

struct TigerSkeletonGrid: View {
    var columns: Int = 3

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DT.Space.x1), count: columns),
                spacing: DT.Space.x2
            ) {
                ForEach(0..<9, id: \.self) { _ in
                    TigerSkeletonCard()
                }
            }
            .padding(DT.Space.x2)
        }
        .allowsHitTesting(false)
    }
}
