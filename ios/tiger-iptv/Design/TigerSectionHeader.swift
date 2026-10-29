import SwiftUI

/// A tidy, consistent shelf header used across the Movies, Series and Live tabs.
///
/// Layout: `▍ Title  ·  count`  ………  `chevron ›`
///
/// The orange accent bar ties every shelf back to the brand, while the
/// optional count pill gives the user a quick sense of how much content
/// lives behind the tap target — a small "instructional" cue that the
/// whole row is browsable.
struct TigerSectionHeader<Trailing: View>: View {
    let title: String
    var count: Int? = nil
    var subtitle: String? = nil
    var showsChevron: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        count: Int? = nil,
        subtitle: String? = nil,
        showsChevron: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.count = count
        self.subtitle = subtitle
        self.showsChevron = showsChevron
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Capsule()
                .fill(TigerTheme.orangeGradient)
                .frame(width: 4, height: 20)
                .shadow(color: TigerTheme.orange.opacity(0.5), radius: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(TigerTheme.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(TigerTheme.orange.opacity(0.14))
                    )
            }

            Spacer(minLength: 8)

            trailing()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

extension TigerSectionHeader where Trailing == EmptyView {
    init(title: String, count: Int? = nil, subtitle: String? = nil, showsChevron: Bool = true) {
        self.init(title: title, count: count, subtitle: subtitle, showsChevron: showsChevron) {
            EmptyView()
        }
    }
}

/// Small pill that shows a rating with a star, colour-coded by score.
/// Used on posters, hero cards and detail screens for consistency.
struct TigerRatingBadge: View {
    let value: Double // 0…10
    var compact: Bool = false

    private var tint: Color {
        switch value {
        case 8...: return Color(red: 0.35, green: 0.85, blue: 0.45)
        case 6..<8: return TigerTheme.goldLight
        default: return Color(red: 0.95, green: 0.45, blue: 0.35)
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            Text(String(format: "%.1f", value))
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 5 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            Capsule().fill(Color.black.opacity(0.55))
        )
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.9), lineWidth: 1)
        )
    }
}

/// A subtle "tip" card used to teach users about a feature in context.
/// Appears once per screen and can be dismissed.
struct TigerTipCard: View {
    let icon: String
    let title: String
    let message: String
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TigerTheme.orange)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(TigerTheme.orange.opacity(0.14)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: TigerTheme.Radius.md, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TigerTheme.Radius.md, style: .continuous)
                    .strokeBorder(TigerTheme.orange.opacity(0.16), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
}

/// A compact row of "at a glance" counters (channels, movies, series…).
/// Adds a sense of scale and polish to the top of a tab without stealing
/// attention from the content itself.
struct TigerStatsStrip: View {
    struct Stat: Identifiable {
        let id = UUID()
        let icon: String
        let value: String
        let label: String
    }

    let stats: [Stat]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(stats) { stat in
                HStack(spacing: 8) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TigerTheme.orange)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(TigerTheme.orange.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 0) {
                        Text(stat.value)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                        Text(stat.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
    }
}
