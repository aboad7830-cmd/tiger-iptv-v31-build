import SwiftUI

/// "What's on" guide: one row per channel with the current programme, a progress
/// bar and the next programme. Tapping a row can start playback.
struct EPGGuideView: View {
    let playlist: Playlist
    var onPlayChannel: ((String) -> Void)? = nil

    @StateObject private var service = EPGService.shared
    @State private var rows: [GuideRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    struct GuideRow: Identifiable {
        let id: String
        let channel: EpgChannel
        let current: EpgProgram?
        let next: EpgProgram?
    }

    private var filteredRows: [GuideRow] {
        guard !searchText.isEmpty else { return rows }
        return rows.filter { $0.channel.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingState
                } else if let errorMessage {
                    errorState(errorMessage)
                } else if rows.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(L("epg.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: L("epg.search"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await load(forceRefresh: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(service.isRefreshing)
                }
            }
            .task { await load(forceRefresh: false) }
            .refreshable { await load(forceRefresh: true) }
        }
    }

    private var list: some View {
        List(filteredRows) { row in
            Button {
                onPlayChannel?(row.channel.channelId)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: Spacing.sm) {
                        if let icon = row.channel.iconURL, let url = URL(string: icon) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        Text(row.channel.displayName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let current = row.current {
                            Text(Self.timeRange(current))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let current = row.current {
                        Text(current.title)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        ProgressView(value: current.progress())
                            .tint(TigerTheme.brandLight)

                        if let next = row.next {
                            Text("\(L("epg.next")): \(next.title)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(L("epg.no_data"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text(service.progress ?? L("epg.progress.downloading"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Button(L("common.try_again")) {
                Task { await load(forceRefresh: true) }
            }
            .buttonStyle(TigerSecondaryButtonStyle())
            .padding(.horizontal, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(TigerTheme.goldGradient)
            Text(L("epg.empty.title"))
                .font(.headline)
            Text(L("epg.empty.message"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            if service.hasGuideSource(playlist) {
                Button(L("epg.refresh")) {
                    Task { await load(forceRefresh: true) }
                }
                .buttonStyle(TigerPrimaryButtonStyle())
                .padding(.horizontal, Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading

    private func load(forceRefresh: Bool) async {
        isLoading = rows.isEmpty
        errorMessage = nil

        let playlistId = playlist.id
        let existingCount = await service.programCount(playlistId: playlistId)

        if forceRefresh || existingCount == 0 {
            if service.hasGuideSource(playlist) {
                do {
                    try await service.refresh(playlist: playlist)
                } catch {
                    if existingCount == 0 {
                        errorMessage = error.localizedDescription
                        isLoading = false
                        return
                    }
                }
            }
        }

        let channels = await service.channels(playlistId: playlistId)
        var built: [GuideRow] = []
        for channel in channels {
            let pair = await service.nowAndNext(playlistId: playlistId, channelId: channel.channelId)
            built.append(
                GuideRow(
                    id: channel.id,
                    channel: channel,
                    current: pair.0,
                    next: pair.1
                )
            )
        }
        rows = built
        isLoading = false
    }

    private static func timeRange(_ program: EpgProgram) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: program.start))–\(formatter.string(from: program.end))"
    }
}
