import SwiftUI

/// شاشة الترحيب الأولى — تُعرض مرة واحدة فقط.
/// ملاحظة تصميمية: كل النصوص هنا بيضاء/فاتحة فوق الخلفية الداكنة
/// حتى تبقى واضحة تماماً في الوضعين الداكن والفاتح (كانت سابقاً بلون ink الداكن).
struct OnboardingView: View {
    var onFinish: () -> Void

    @AppStorage("app.onboardingDone") private var onboardingDone = false
    @State private var page = 0
    @StateObject private var theme = ThemeManager.shared

    private let pageCount = 5

    var body: some View {
        ZStack {
            TigerAuroraBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    featurePackPage.tag(2)
                    themePage.tag(3)
                    readyPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, Spacing.md)

                controls
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            TigerLogoMark(size: 168, eyeGlow: 0.9)
                .shadow(color: TigerTheme.orange.opacity(0.45), radius: 28)
            VStack(spacing: Spacing.sm) {
                HStack(spacing: 7) {
                    Text("TIGER")
                        .foregroundStyle(.white)
                    Text("IPTV")
                        .foregroundStyle(TigerTheme.orangeGradient)
                }
                .font(.system(size: 34, weight: .black, design: .rounded))
                .shadow(color: TigerTheme.orange.opacity(0.35), radius: 12)

                Text(L("onboarding.welcome.subtitle"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    private var featuresPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text(L("onboarding.features.title"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.25), radius: 8)

            VStack(spacing: Spacing.md) {
                featureRow(icon: "play.rectangle.on.rectangle", title: L("onboarding.feature.multiview"), body: L("onboarding.feature.multiview.desc"))
                featureRow(icon: "calendar", title: L("onboarding.feature.epg"), body: L("onboarding.feature.epg.desc"))
                featureRow(icon: "arrow.down.circle", title: L("onboarding.feature.downloads"), body: L("onboarding.feature.downloads.desc"))
                featureRow(icon: "lock.shield", title: L("onboarding.feature.parental"), body: L("onboarding.feature.parental.desc"))
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    /// صفحة جديدة تُبرز حزمة المزايا الكبيرة (200+ ميزة) داخل التطبيق.
    private var featurePackPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(TigerTheme.orange.opacity(0.18))
                    .frame(width: 132, height: 132)
                    .blur(radius: 22)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(TigerTheme.orangeGradient)
            }

            VStack(spacing: Spacing.sm) {
                Text("المزايا والتفعيلات")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("مركز مزايا كامل داخل التطبيق: تشغيل، صوت، ترجمة، بث مباشر، أفلام، مسلسلات، شبكة، خصوصية، إتاحة، وتخصيص — كل شيء قابل للتحكم من مكان واحد.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: Spacing.sm) {
                packChip(icon: "bolt.fill", text: "تشغيل")
                packChip(icon: "waveform", text: "صوت")
                packChip(icon: "captions.bubble", text: "ترجمة")
                packChip(icon: "network", text: "شبكة")
            }
            .padding(.top, Spacing.xs)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var themePage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Text(L("onboarding.theme.title"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.25), radius: 8)

            HStack(spacing: Spacing.sm) {
                ForEach(ThemeManager.Appearance.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            theme.appearance = option
                        }
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Image(systemName: option.icon).font(.system(size: 24))
                            Text(option.label).font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .foregroundStyle(theme.appearance == option ? .white : .white.opacity(0.72))
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .fill(theme.appearance == option ? AnyShapeStyle(theme.accent.gradient) : AnyShapeStyle(.ultraThinMaterial))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(theme.appearance == option ? theme.accent.color : Color.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: Spacing.sm) {
                ForEach(ThemeManager.Accent.allCases) { option in
                    Button {
                        withAnimation { theme.accent = option }
                    } label: {
                        Circle()
                            .fill(option.gradient)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().strokeBorder(theme.accent == option ? Color.white : Color.white.opacity(0.18), lineWidth: 2)
                            )
                            .shadow(color: option.color.opacity(0.45), radius: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.xs)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var readyPage: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 76))
                .foregroundStyle(TigerTheme.goldGradient)
                .shadow(color: TigerTheme.gold.opacity(0.45), radius: 18)
            VStack(spacing: Spacing.sm) {
                Text(L("onboarding.ready.title"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(L("onboarding.ready.subtitle"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Controls

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AnyShapeStyle(TigerTheme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.25)))
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Spacing.sm) {
            if page < pageCount - 1 {
                Button(L("onboarding.skip")) { finish() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(.ultraThinMaterial))

                Button(L("onboarding.next")) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(TigerTheme.orangeGradient))
                .shadow(color: TigerTheme.orange.opacity(0.35), radius: 12, y: 4)
            } else {
                Button(L("onboarding.start")) { finish() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).fill(TigerTheme.orangeGradient))
                    .shadow(color: TigerTheme.orange.opacity(0.35), radius: 12, y: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private func featureRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(TigerTheme.gold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func packChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }

    private func finish() {
        onboardingDone = true
        onFinish()
    }
}
