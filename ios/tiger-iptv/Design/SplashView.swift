import SwiftUI

/// Animated aurora background used behind the splash, onboarding and empty states.
struct TigerAuroraBackground: View {
    var animated: Bool = true
    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            TigerTheme.splashGradient

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                Circle()
                    .fill(TigerTheme.brandLight.opacity(0.55))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .blur(radius: w * 0.22)
                    .offset(x: -w * 0.25 + CGFloat(sin(phase)) * w * 0.08,
                            y: -h * 0.22 + CGFloat(cos(phase * 0.8)) * h * 0.05)

                Circle()
                    .fill(TigerTheme.gold.opacity(0.35))
                    .frame(width: w * 0.7, height: w * 0.7)
                    .blur(radius: w * 0.20)
                    .offset(x: w * 0.28 + CGFloat(cos(phase * 1.1)) * w * 0.06,
                            y: h * 0.24 + CGFloat(sin(phase * 0.9)) * h * 0.05)

                Circle()
                    .fill(Color(red: 0.10, green: 0.45, blue: 0.65).opacity(0.30))
                    .frame(width: w * 0.6, height: w * 0.6)
                    .blur(radius: w * 0.18)
                    .offset(x: CGFloat(sin(phase * 0.6)) * w * 0.30,
                            y: -h * 0.05)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                phase = .pi
            }
        }
    }
}

/// Floating light particles for the splash.
private struct TigerParticles: View {
    let count: Int
    @State private var drift: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let seed = Double(index)
                    let x = (seed * 37.0).truncatingRemainder(dividingBy: 100.0) / 100.0
                    let y = (seed * 61.0).truncatingRemainder(dividingBy: 100.0) / 100.0
                    let size = 1.5 + (seed * 7.0).truncatingRemainder(dividingBy: 3.0)

                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: size, height: size)
                        .position(x: proxy.size.width * x, y: proxy.size.height * y)
                        .offset(y: drift ? -18 - seed.truncatingRemainder(dividingBy: 12) : 14)
                        .opacity(drift ? 0.15 : 0.7)
                        .animation(
                            .easeInOut(duration: 2.6 + seed.truncatingRemainder(dividingBy: 2.0))
                            .repeatForever(autoreverses: true)
                            .delay(seed.truncatingRemainder(dividingBy: 1.6)),
                            value: drift
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A quiet, deep-space star field that matches the brand splash reference.
/// Stars twinkle at different cadences so the background never feels static.
struct TigerStarField: View {
    var count: Int = 90
    var animated: Bool = true

    @State private var twinkle: Bool = false

    private struct Star {
        let x: Double
        let y: Double
        let size: Double
        let baseOpacity: Double
        let delay: Double
        let warm: Bool
    }

    private var stars: [Star] {
        (0..<count).map { index in
            let seed = Double(index)
            let x = (seed * 47.13).truncatingRemainder(dividingBy: 100.0) / 100.0
            let y = (seed * 73.71).truncatingRemainder(dividingBy: 100.0) / 100.0
            let size = 0.8 + (seed * 13.0).truncatingRemainder(dividingBy: 2.2)
            let base = 0.18 + (seed * 29.0).truncatingRemainder(dividingBy: 55.0) / 100.0
            let delay = (seed * 17.0).truncatingRemainder(dividingBy: 40.0) / 10.0
            return Star(x: x, y: y, size: size, baseOpacity: base, delay: delay, warm: index % 7 == 0)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(star.warm ? TigerTheme.orangeLight : Color.white)
                        .frame(width: star.size, height: star.size)
                        .position(x: proxy.size.width * star.x, y: proxy.size.height * star.y)
                        .opacity(twinkle ? min(1, star.baseOpacity + 0.45) : star.baseOpacity)
                        .animation(
                            .easeInOut(duration: 1.8 + star.delay)
                            .repeatForever(autoreverses: true)
                            .delay(star.delay),
                            value: twinkle
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard animated else { return }
            twinkle = true
        }
    }
}

/// Full-screen animated entrance for the Tiger iptv brand.
///
/// Sequence (≈2.6 s):
/// 1. Deep-teal star field fades in.
/// 2. The lion medallion springs from 0.6 → 1.0, the gold ring draws itself.
/// 3. A light sweep crosses the lion, the mark "breathes".
/// 4. "Tiger" then "iptv" rise into place.
/// 5. Gold divider expands, tagline and version fade in.
///
/// Tapping anywhere skips to the end. Reduce Motion shows a static version.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var backgroundOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var eyeGlow: Double = 0
    @State private var scanProgress: Double = 0
    @State private var ringTrim: CGFloat = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 26
    @State private var lineWidth: CGFloat = 0
    @State private var taglineOpacity: Double = 0
    @State private var breathe = false
    @State private var finished = false

    var body: some View {
        ZStack {
            splashBackground
                .opacity(backgroundOpacity)

            if !reduceMotion {
                TigerStarField(count: 110, animated: true)
                    .opacity(backgroundOpacity)
                TigerParticles(count: 22)
                    .opacity(backgroundOpacity * 0.8)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                medallion
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Spacer().frame(height: 34)

                wordmark
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)

                Spacer().frame(height: 20)

                Rectangle()
                    .fill(TigerTheme.goldGradient)
                    .frame(width: lineWidth, height: 1.5)
                    .clipShape(Capsule())
                    .shadow(color: TigerTheme.gold.opacity(0.5), radius: 8)

                Spacer().frame(height: 16)

                Text(L("splash.tagline"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(taglineOpacity)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text("v\(Bundle.main.appVersion)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.38))
                    Circle().fill(.white.opacity(0.18)).frame(width: 3, height: 3)
                    Text("build \(Bundle.main.appBuild)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.28))
                }
                .padding(.bottom, 28)
                .opacity(taglineOpacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish(immediately: true) }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .task { await runSequence() }
    }

    // MARK: - Background

    private var splashBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.13, blue: 0.13),
                    Color(red: 0.03, green: 0.22, blue: 0.21),
                    Color(red: 0.01, green: 0.09, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [TigerTheme.orange.opacity(0.16), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            Circle()
                .fill(TigerTheme.orange.opacity(0.22))
                .frame(width: 214, height: 214)
                .blur(radius: 34)
                .scaleEffect(breathe ? 1.06 : 0.96)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.05, green: 0.30, blue: 0.29),
                                 Color(red: 0.02, green: 0.16, blue: 0.16)],
                        center: .topLeading,
                        startRadius: 6,
                        endRadius: 150
                    )
                )
                .frame(width: 190, height: 190)
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.06), lineWidth: 1)
                )

            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(
                    AngularGradient(
                        colors: [TigerTheme.goldLight, TigerTheme.gold, TigerTheme.orange, TigerTheme.goldLight],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 206, height: 206)
                .rotationEffect(.degrees(-90))
                .shadow(color: TigerTheme.gold.opacity(0.6), radius: 10)

            TigerLogoMark(size: 132, eyeGlow: eyeGlow, scanProgress: scanProgress)
                .scaleEffect(breathe ? 1.03 : 0.98)
        }
        .frame(width: 214, height: 214)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // MARK: - Wordmark

    private var wordmark: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("Tiger")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: TigerTheme.orange.opacity(0.45), radius: 14)

            Text("iptv")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(TigerTheme.orangeGradient)
                .shadow(color: TigerTheme.orange.opacity(0.55), radius: 12)
        }
        .opacity(wordmarkOpacity)
        .offset(y: wordmarkOffset)
        .accessibilityLabel("Tiger iptv")
    }

    // MARK: - Sequence

    private func runSequence() async {
        if reduceMotion {
            backgroundOpacity = 1
            logoScale = 1
            logoOpacity = 1
            eyeGlow = 1
            ringTrim = 1
            wordmarkOpacity = 1
            wordmarkOffset = 0
            lineWidth = 140
            taglineOpacity = 1
            try? await Task.sleep(for: .seconds(0.9))
            finish(immediately: false)
            return
        }

        withAnimation(.easeOut(duration: 0.45)) { backgroundOpacity = 1 }
        try? await Task.sleep(for: .milliseconds(160))

        withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) {
            logoScale = 1
            logoOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(280))

        withAnimation(.easeInOut(duration: 0.85)) { ringTrim = 1 }
        withAnimation(.easeInOut(duration: 0.55)) { eyeGlow = 1 }
        withAnimation(.easeInOut(duration: 0.95)) { scanProgress = 1 }

        try? await Task.sleep(for: .milliseconds(380))

        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            wordmarkOpacity = 1
            wordmarkOffset = 0
        }

        try? await Task.sleep(for: .milliseconds(220))

        withAnimation(.easeOut(duration: 0.5)) { lineWidth = 148 }

        try? await Task.sleep(for: .milliseconds(120))

        withAnimation(.easeIn(duration: 0.45)) { taglineOpacity = 1 }

        try? await Task.sleep(for: .milliseconds(620))
        finish(immediately: false)
    }

    private func finish(immediately: Bool) {
        guard !finished else { return }
        finished = true

        if immediately {
            withAnimation(.easeOut(duration: 0.25)) {
                logoScale = 1.06
                ringTrim = 1
                wordmarkOpacity = 1
                taglineOpacity = 1
            }
        }

        withAnimation(.easeInOut(duration: immediately ? 0.2 : 0.35)) {
            backgroundOpacity = 0
            logoOpacity = 0
            wordmarkOpacity = 0
            taglineOpacity = 0
            lineWidth = 0
        }

        Task {
            try? await Task.sleep(for: .milliseconds(immediately ? 220 : 360))
            onFinish()
        }
    }
}

extension Bundle {
    /// Marketing version, e.g. "2.0".
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0"
    }

    /// Build number, e.g. "1".
    var appBuild: String {
        (infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}

#Preview {
    SplashView(onFinish: {})
}
