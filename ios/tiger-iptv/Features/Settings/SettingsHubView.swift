import SwiftUI

/// مركز الإعدادات الجديد — يجمع كل ميزات TIGER v2 في مكان واحد.
struct SettingsHubView: View {
    let playlist: Playlist

    var body: some View {
        List {
            Section(header: Text(L("hub.appearance.section"))) {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    hubRow(icon: "paintpalette.fill", title: L("settings.appearance"), subtitle: L("hub.appearance.subtitle"), tint: TigerTheme.gold)
                }

                NavigationLink {
                    ProfilePickerView { _ in }
                } label: {
                    hubRow(icon: "person.2.fill", title: L("profiles.title"), subtitle: L("hub.profiles.subtitle"), tint: TigerTheme.brandLight)
                }
            }

            Section(header: Text("المزايا")) {
                NavigationLink {
                    FeatureCenterView()
                } label: {
                    hubRow(icon: "sparkles", title: "المزايا والتفعيلات", subtitle: "200 ميزة أساسية + 100 ميزة Tiger Plus في مكان واحد", tint: TigerTheme.orange)
                }
            }

            Section(header: Text(L("hub.content.section"))) {
                NavigationLink {
                    EPGGuideView(playlist: playlist)
                } label: {
                    hubRow(icon: "calendar", title: L("epg.title"), subtitle: L("hub.epg.subtitle"), tint: TigerTheme.gold)
                }

                NavigationLink {
                    WatchlistView(playlistId: playlist.id)
                } label: {
                    hubRow(icon: "bookmark.fill", title: L("watchlist.title"), subtitle: L("hub.watchlist.subtitle"), tint: TigerTheme.brandLight)
                }

                NavigationLink {
                    MultiViewScreen(playlist: playlist)
                } label: {
                    hubRow(icon: "rectangle.split.2x2.fill", title: L("multiview.title"), subtitle: L("hub.multiview.subtitle"), tint: TigerTheme.gold)
                }

                NavigationLink {
                    DownloadsView(playlist: playlist)
                } label: {
                    hubRow(icon: "arrow.down.circle.fill", title: L("downloads.title"), subtitle: L("hub.downloads.subtitle"), tint: TigerTheme.brandLight)
                }

                NavigationLink {
                    PlaybackStatsView(playlist: playlist)
                } label: {
                    hubRow(icon: "chart.bar.fill", title: L("stats.title"), subtitle: L("hub.stats.subtitle"), tint: TigerTheme.gold)
                }
            }

            Section(header: Text(L("hub.safety.section"))) {
                NavigationLink {
                    ParentalSettingsView()
                } label: {
                    hubRow(icon: "lock.shield.fill", title: L("parental.title"), subtitle: L("hub.parental.subtitle"), tint: TigerTheme.brandLight)
                }

                NavigationLink {
                    SleepTimerSheet()
                } label: {
                    hubRow(icon: "moon.zzz.fill", title: L("sleep.title"), subtitle: L("hub.sleep.subtitle"), tint: TigerTheme.gold)
                }
            }

            Section(header: Text(L("support.section"))) {
                TigerSupportCard()
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
            }

            Section(header: Text(L("hub.advanced.section"))) {
                NavigationLink {
                    DiagnosticsView(playlist: playlist)
                } label: {
                    hubRow(icon: "stethoscope", title: L("settings.diagnostics"), subtitle: L("hub.diagnostics.subtitle"), tint: TigerTheme.brandLight)
                }

                NavigationLink {
                    BackupRestoreView()
                } label: {
                    hubRow(icon: "externaldrive.fill", title: L("settings.backup"), subtitle: L("hub.backup.subtitle"), tint: TigerTheme.gold)
                }

                NavigationLink {
                    OnboardingView { }
                } label: {
                    hubRow(icon: "sparkles", title: L("hub.tour.title"), subtitle: L("hub.tour.subtitle"), tint: TigerTheme.brandLight)
                }
            }
        }
        .navigationTitle(L("hub.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hubRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - إحصاءات المشاهدة

struct PlaybackStatsView: View {
    let playlist: Playlist

    @StateObject private var store = PlaybackStatsStore.shared

    var body: some View {
        List {
            Section {
                HStack {
                    statTile(value: store.summary.totalHoursText, label: L("stats.hours"), icon: "clock.fill")
                    statTile(value: "\(store.summary.sessions)", label: L("stats.sessions"), icon: "play.circle.fill")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if !store.summary.byKind.isEmpty {
                Section(header: Text(L("stats.by_type"))) {
                    ForEach(store.summary.byKind.keys.sorted(), id: \.self) { key in
                        HStack {
                            Text(kindLabel(key))
                            Spacer()
                            Text(durationText(store.summary.byKind[key] ?? 0))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            if !store.summary.topTitles.isEmpty {
                Section(header: Text(L("stats.top_titles"))) {
                    ForEach(Array(store.summary.topTitles.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.title).lineLimit(1)
                            Spacer()
                            Text(durationText(item.seconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await store.clearAll(playlistId: playlist.id) }
                } label: {
                    Label(L("stats.clear"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(L("stats.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadSummary(playlistId: playlist.id) }
    }

    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(TigerTheme.gold)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    private func kindLabel(_ key: String) -> String {
        switch key {
        case "live": return L("dashboard.live")
        case "vod": return L("dashboard.movies")
        case "series": return L("dashboard.series")
        default: return key
        }
    }

    private func durationText(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
