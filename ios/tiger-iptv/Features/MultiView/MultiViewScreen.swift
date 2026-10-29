import SwiftUI
import AVKit
import GRDB
import AVFoundation
#if canImport(AppKit)
import AppKit
#endif

/// شاشة مشاهدة متعددة (2×2) لأربع قنوات مباشرة في نفس الوقت.
struct MultiViewScreen: View {
    let playlist: Playlist

    @State private var channels: [DBLiveStream] = []
    @State private var selected: [DBLiveStream] = []
    @State private var showingPicker = false
    @State private var mutedIndex: Int? = 0
    @State private var isLoading = true

    private var builder: PlaybackURLBuilder { PlaybackURLBuilder(playlist: playlist) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView().tint(.white)
            } else if selected.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .navigationTitle(L("multiview.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPicker = true
                } label: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            MultiViewPicker(playlist: playlist, channels: channels, selected: $selected)
        }
        .task { await loadChannels() }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 52))
                .foregroundStyle(TigerTheme.goldGradient)
            Text(L("multiview.empty.title"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(L("multiview.empty.body"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(L("multiview.pick")) { showingPicker = true }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Capsule().fill(TigerTheme.goldGradient))
        }
        .padding(Spacing.xl)
    }

    private var grid: some View {
        GeometryReader { geo in
            let columns = selected.count <= 1 ? 1 : 2
            let rows = selected.count <= 2 ? 1 : 2
            let cellWidth = geo.size.width / CGFloat(columns)
            let cellHeight = geo.size.height / CGFloat(rows)

            VStack(spacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < selected.count {
                                cell(for: selected[index], index: index)
                                    .frame(width: cellWidth - 2, height: cellHeight - 2)
                            } else {
                                Color.black
                                    .frame(width: cellWidth - 2, height: cellHeight - 2)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func cell(for channel: DBLiveStream, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let url = builder.liveURL(streamId: channel.streamId) {
                MultiViewPlayer(url: url, isMuted: mutedIndex != index)
            } else {
                Color.black
            }

            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)

            HStack(spacing: Spacing.xs) {
                Text(channel.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Button {
                    mutedIndex = (mutedIndex == index) ? nil : index
                } label: {
                    Image(systemName: mutedIndex == index ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .buttonStyle(.plain)

                Button {
                    selected.removeAll { $0.id == channel.id }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.sm)
        }
        .clipped()
    }

    private func loadChannels() async {
        isLoading = true
        defer { isLoading = false }
        do {
            channels = try await AppDatabase.shared.read { db in
                try DBLiveStream
                    .filter(Column("playlistId") == playlist.id.uuidString)
                    .order(Column("sortIndex"))
                    .limit(500)
                    .fetchAll(db)
            }
            if selected.isEmpty {
                selected = Array(channels.prefix(4))
            }
        } catch {
            Log.error("MultiView", "load failed: \(error)")
        }
    }
}

/// مشغّل AVPlayer بسيط يُستخدم داخل خلايا العرض المتعدد.
private struct MultiViewPlayer: View {
    let url: URL
    let isMuted: Bool

    @State private var player: AVPlayer?

    var body: some View {
        PlayerLayerView(player: player)
            .onAppear {
                let p = AVPlayer(url: url)
                p.isMuted = isMuted
                p.play()
                player = p
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
            .onChange(of: isMuted) { _, newValue in
                player?.isMuted = newValue
            }
    }
}

/// غلاف AVPlayerLayer.
#if os(iOS) || os(tvOS) || os(visionOS)
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
#elseif canImport(AppKit)
struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> PlayerContainerNSView {
        let view = PlayerContainerNSView()
        view.wantsLayer = true
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerContainerNSView, context: Context) {
        nsView.playerLayer.player = player
    }
}

final class PlayerContainerNSView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = playerLayer
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
#endif

// MARK: - اختيار القنوات

private struct MultiViewPicker: View {
    let playlist: Playlist
    let channels: [DBLiveStream]
    @Binding var selected: [DBLiveStream]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [DBLiveStream] {
        guard !query.isEmpty else { return channels }
        return channels.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { channel in
                Button {
                    toggle(channel)
                } label: {
                    HStack {
                        Text(channel.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(where: { $0.id == channel.id }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(TigerTheme.gold)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: L("multiview.search"))
            .navigationTitle(L("multiview.pick"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }

    private func toggle(_ channel: DBLiveStream) {
        if let index = selected.firstIndex(where: { $0.id == channel.id }) {
            selected.remove(at: index)
        } else if selected.count < 4 {
            selected.append(channel)
        }
    }
}
