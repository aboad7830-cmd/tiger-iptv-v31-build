import SwiftUI

/// Grid of saved movies and series.
struct WatchlistView: View {
    let playlistId: UUID
    var onSelect: ((WatchlistItem) -> Void)? = nil

    @StateObject private var store = WatchlistStore.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Spacing.md)]

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Spacing.lg) {
                            ForEach(store.items) { item in
                                card(item)
                            }
                        }
                        .padding(Spacing.md)
                    }
                }
            }
            .navigationTitle(L("watchlist.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
            .task { await store.load(playlistId: playlistId) }
        }
    }

    private func card(_ item: WatchlistItem) -> some View {
        Button {
            onSelect?(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.primary.opacity(0.08))

                    if let poster = item.posterURL, let url = URL(string: poster) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: item.kind == "series" ? "tv" : "film")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                Text(item.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
            }
            .contextMenu {
                Button(role: .destructive) {
                    Task { await store.remove(item) }
                } label: {
                    Label(L("common.delete"), systemImage: "trash")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 44))
                .foregroundStyle(TigerTheme.goldGradient)
            Text(L("watchlist.empty.title"))
                .font(.headline)
            Text(L("watchlist.empty.message"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
