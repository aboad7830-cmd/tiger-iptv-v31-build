import SwiftUI
import UIKit
import GRDB

/// شاشة التشخيص: حالة الشبكة، سرعة الخادم، مساحة التخزين، إصدارات، وسجل قابل للمشاركة.
struct DiagnosticsView: View {
    let playlist: Playlist?

    @StateObject private var network = NetworkMonitor.shared
    @State private var latency: Int?
    @State private var isTesting = false
    @State private var storageText = "—"
    @State private var downloadsText = "—"
    @State private var shareURL: URL?
    @State private var showingShare = false

    var body: some View {
        ZStack {
            TigerAuroraBackground()

            ScrollView {
                VStack(spacing: Spacing.md) {
                    networkCard
                    serverCard
                    storageCard
                    buildCard
                    shareButton
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle(L("settings.diagnostics"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStorage() }
        .sheet(isPresented: $showingShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
    }

    // MARK: - Cards

    private var networkCard: some View {
        card(title: L("diagnostics.network"), icon: "wifi") {
            row(L("diagnostics.status"), network.status.label)
            row(L("diagnostics.expensive"), network.isExpensive ? L("common.yes") : L("common.no"))
            row(L("diagnostics.constrained"), network.isConstrained ? L("common.yes") : L("common.no"))
            row(L("diagnostics.latency"), latency.map { "\($0) ms · \(network.qualityLabel(latencyMs: $0))" } ?? "—")
        }
    }

    private var serverCard: some View {
        card(title: L("diagnostics.server"), icon: "server.rack") {
            row(L("diagnostics.server_url"), playlist?.serverURL ?? "—")
            row(L("diagnostics.username"), playlist?.username ?? "—")
            Button {
                Task { await testServer() }
            } label: {
                HStack {
                    if isTesting { ProgressView().tint(.white) }
                    Text(isTesting ? L("diagnostics.testing") : L("diagnostics.test_speed"))
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(TigerTheme.brandGradient)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(playlist == nil || isTesting)
        }
    }

    private var storageCard: some View {
        card(title: L("diagnostics.storage"), icon: "internaldrive") {
            row(L("diagnostics.free_space"), storageText)
            row(L("diagnostics.downloads"), downloadsText)
        }
    }

    private var buildCard: some View {
        card(title: L("diagnostics.build"), icon: "hammer") {
            row(L("diagnostics.version"), Bundle.main.appVersion)
            row(L("diagnostics.build_number"), Bundle.main.appBuild)
            row(L("diagnostics.device"), TigerPlatform.deviceModel)
            row(L("diagnostics.system"), TigerPlatform.systemDescription)
        }
    }

    private var shareButton: some View {
        Button {
            exportLog()
        } label: {
            Label(L("diagnostics.share_log"), systemImage: "square.and.arrow.up")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .foregroundStyle(TigerTheme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building blocks

    private func card<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(TigerTheme.gold)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TigerTheme.ink)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(TigerTheme.inkSoft)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(TigerTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Actions

    private func testServer() async {
        guard let playlist else { return }
        isTesting = true
        defer { isTesting = false }
        let base = playlist.serverURL.hasPrefix("http") ? playlist.serverURL : "http://\(playlist.serverURL)"
        if let url = URL(string: base) {
            latency = await network.measureLatency(to: url)
        }
    }

    private func refreshStorage() async {
        let bytes = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber)?.int64Value
        if let bytes {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            storageText = formatter.string(fromByteCount: bytes)
        }

        do {
            let total = try await AppDatabase.shared.read { db in
                try DBDownloadedItem
                    .filter(Column("status") == "completed")
                    .fetchAll(db)
                    .reduce(Int64(0)) { $0 + Int64($1.totalBytes) }
            }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            downloadsText = formatter.string(fromByteCount: total)
        } catch {
            downloadsText = "—"
        }
    }

    private func exportLog() {
        var lines: [String] = []
        lines.append("TIGER IPTV — Diagnostics")
        lines.append("Date: \(Date())")
        lines.append("Version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
        lines.append("Device: \(TigerPlatform.deviceModel) — \(TigerPlatform.systemDescription)")
        lines.append("Network: \(network.status.label) · expensive=\(network.isExpensive) · constrained=\(network.isConstrained)")
        lines.append("Latency: \(latency.map(String.init) ?? "—") ms")
        lines.append("Free space: \(storageText)")
        if let playlist {
            lines.append("Playlist: \(playlist.name) — \(playlist.serverURL) — type=\(playlist.type)")
        }

        let text = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tiger-diagnostics.txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            shareURL = url
            showingShare = true
        } catch {
            Log.error("Diagnostics", "export failed: \(error)")
        }
    }
}

/// غلاف UIActivityViewController.
#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif canImport(AppKit)
struct ShareSheet: View {
    let items: [Any]
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up").font(.largeTitle)
            if let url = items.first as? URL {
                ShareLink(item: url) { Text("مشاركة") }
            }
        }
        .padding()
    }
}
#endif
