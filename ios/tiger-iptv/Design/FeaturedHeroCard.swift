import SwiftUI

/// A wide, cinematic "featured" card shown at the top of the Movies and
/// Series tabs. Gives the screen an immediate focal point and a single,
/// obvious entry into the best content — a strong aesthetic + instructional
/// improvement over a plain list of shelves.
struct FeaturedHeroCard: View {
    let title: String
    let backdropURL: URL?
    let posterURL: URL?
    let metaLine: String?
    let rating10: Double?
    var badge: String? = nil

    @State private var appeared = false

    private var imageURL: URL? { backdropURL ?? posterURL }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            imageLayer
            gradientLayer
            content
                .padding(16)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [TigerTheme.orange.opacity(0.55), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        .padding(.horizontal, 16)
        .scaleEffect(appeared ? 1 : 0.97)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    @ViewBuilder
    private var imageLayer: some View {
        if let url = imageURL {
            GeometryReader { proxy in
                CachedImage(
                    url: url,
                    width: proxy.size.width,
                    height: 210,
                    cornerRadius: 0,
                    contentMode: .fill,
                    iconName: "film",
                    loadProfile: .high
                )
                .frame(width: proxy.size.width, height: 210)
            }
        } else {
            LinearGradient(
                colors: [TigerTheme.orangeDeep.opacity(0.7), TigerTheme.ink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientLayer: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.15),
                .init(color: .black.opacity(0.35), location: 0.55),
                .init(color: .black.opacity(0.88), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let badge, !badge.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(TigerTheme.orangeGradient))
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.6), radius: 6)

            HStack(spacing: 8) {
                if let metaLine, !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
                if let rating10 {
                    TigerRatingBadge(value: rating10, compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
