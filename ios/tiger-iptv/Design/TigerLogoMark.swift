import SwiftUI

/// TIGER IPTV logo mark — the lion profile line-art.
///
/// The artwork ships as a template image (`LionMark`) so it can be tinted with the
/// brand orange at any size, on any background, without losing sharpness.
/// The public API is unchanged (`size`, `eyeGlow`, `scanProgress`) so every screen
/// that already uses `TigerLogoMark` automatically picks up the new identity.
struct TigerLogoMark: View {
    /// Width/height of the mark.
    var size: CGFloat = 160
    /// 0…1 — drives the outer glow (animated by the splash).
    var eyeGlow: Double = 0.35
    /// 0…1 — vertical position of the light sweep (animated by the splash).
    var scanProgress: Double = 0
    /// Optional tint override. Defaults to the brand orange.
    var tint: Color = TigerTheme.orange

    var body: some View {
        ZStack {
            // Soft halo behind the mark.
            mark
                .blur(radius: size * 0.075)
                .opacity(0.28 + 0.45 * eyeGlow)
                .scaleEffect(1.04)

            // Crisp artwork.
            mark
                .shadow(color: tint.opacity(0.35 + 0.4 * eyeGlow), radius: size * 0.06)

            // Light sweep, clipped to the artwork silhouette.
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.85), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: size * 0.22)
            .offset(y: (scanProgress - 0.5) * size * 1.15)
            .blendMode(.plusLighter)
            .mask(mark)
            .opacity(scanProgress > 0 ? 0.9 : 0)
            .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Tiger IPTV")
    }

    private var mark: some View {
        Image("LionMark")
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
    }
}

/// Large, self-drawing variant used on the splash / onboarding hero.
/// The stroke "draws" itself from left to right using a mask wipe.
struct TigerLionDrawIn: View {
    var size: CGFloat = 190
    var progress: Double = 1
    var tint: Color = TigerTheme.orange

    var body: some View {
        Image("LionMark")
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: proxy.size.width * max(0, min(1, progress)))
                }
            }
    }
}

#Preview {
    ZStack {
        TigerTheme.splashGradient.ignoresSafeArea()
        VStack(spacing: 40) {
            TigerLogoMark(size: 220, eyeGlow: 1, scanProgress: 0.5)
            TigerLogoMark(size: 96, eyeGlow: 0.6)
        }
    }
}
