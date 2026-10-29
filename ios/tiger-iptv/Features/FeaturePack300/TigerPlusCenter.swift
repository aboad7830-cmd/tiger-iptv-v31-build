//
//  TigerPlusCenter.swift
//  Tiger IPTV
//
//  حزمة v3.0 — مركز Tiger Plus: واجهة واحدة تجمع الميزات المئة،
//  مع مفاتيح تشغيل/إيقاف حقيقية ومسار مستقل لكل ميزة.
//

import SwiftUI
import GRDB
import GRDBQuery

// MARK: - مكوّنات إعدادات مشتركة

/// بطاقة إعدادات موحّدة الشكل تُستخدم في كل شاشات v3.0.
struct TigerSettingsCard<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = TigerTheme.orange
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Spacer(minLength: 0)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// صفّ إعدادات مع مفتاح تشغيل.
struct TigerToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = TigerTheme.orange
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .tint(tint)
    }
}

/// صفّ معلومات بسيط.
struct TigerInfoRow: View {
    let title: String
    let value: String
    var icon: String? = nil
    var tint: Color = TigerTheme.orange

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }
}

/// ملاحظة صغيرة أسفل البطاقات.
struct TigerInfoNote: View {
    let text: String
    var icon: String = "info.circle"
    var tint: Color = TigerTheme.orange

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// غلاف موحّد لشاشات v3.0: عنوان + محتوى بعرض مقروء + تمرير.
struct TigerPlusScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.tigerMetrics) private var metrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                if let subtitle {
                    HStack(alignment: .top, spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TigerTheme.orange)
                                .frame(width: 26)
                        }
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                content()
            }
            .padding(.horizontal, metrics.contentPadding)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: metrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(title)
        .tigerInlineNavigationTitle()
    }
}

// MARK: - مركز Tiger Plus

struct TigerPlusCenterView: View {
    let playlist: Playlist?

    @ObservedObject private var flags = TigerPlusFlags.shared
    @Environment(\.tigerMetrics) private var metrics

    @State private var query = ""
    @State private var category: TigerPlusCategory? = nil
    @State private var showOnlyNew = false

    private var filtered: [TigerPlusFeature] {
        TigerPlusCatalog.all.filter { feature in
            if let category, feature.category != category { return false }
            if showOnlyNew && !feature.isNew { return false }
            guard !query.isEmpty else { return true }
            return TigerArabicNormalizer.matches(feature.title, query: query)
                || TigerArabicNormalizer.matches(feature.subtitle, query: query)
                || TigerArabicNormalizer.matches(feature.category.title, query: query)
        }
    }

    private var grouped: [(TigerPlusCategory, [TigerPlusFeature])] {
        TigerPlusCategory.allCases.compactMap { cat in
            let items = filtered.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                headerCard
                categoryChips
                searchBar

                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(grouped, id: \.0.id) { cat, items in
                        VStack(alignment: .leading, spacing: 10) {
                            TigerSectionHeader(
                                title: cat.title,
                                count: items.count,
                                subtitle: cat.subtitle,
                                showsChevron: false
                            )
                            ForEach(items) { feature in
                                featureRow(feature)
                            }
                        }
                    }
                }

                footerNote
            }
            .padding(.horizontal, metrics.contentPadding)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: metrics.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("المزايا والتفعيلات")
        .tigerInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: TigerPlatform.trailingPlacement) {
                Menu {
                    Button {
                        flags.enableAll()
                    } label: {
                        Label("تفعيل كل الميزات", systemImage: "checkmark.circle.fill")
                    }
                    Button {
                        flags.resetToDefaults()
                    } label: {
                        Label("استعادة الافتراضي", systemImage: "arrow.counterclockwise")
                    }
                    Divider()
                    Toggle("الجديد فقط", isOn: $showOnlyNew)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: الأجزاء

    private var headerCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: max(0.001, Double(flags.enabledCount) / Double(max(TigerPlusCatalog.count, 1))))
                    .stroke(
                        AngularGradient(colors: [TigerTheme.orange, TigerTheme.gold, TigerTheme.orange], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: flags.enabledCount)

                VStack(spacing: 0) {
                    Text("\(flags.enabledCount)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("من \(TigerPlusCatalog.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text("حزمة Tiger Plus")
                    .font(.title3.weight(.heavy))
                Text("مئة ميزة إضافية موزّعة على عشر مجموعات — تُحفظ حالتها هنا، والمزايا الموصولة تُطبّق أثرها فورًا.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        flags.enableAll()
                    } label: {
                        Label("تفعيل الكل", systemImage: "bolt.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(TigerTheme.orange.opacity(0.18)))
                            .foregroundStyle(TigerTheme.orange)
                    }
                    .buttonStyle(.plain)

                    Button {
                        flags.resetToDefaults()
                    } label: {
                        Text("الافتراضي")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(TigerTheme.orange.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(TigerTheme.orange.opacity(0.18), lineWidth: 1)
        )
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "الكل", icon: "square.grid.2x2.fill", tint: TigerTheme.orange, isSelected: category == nil) {
                    category = nil
                }
                ForEach(TigerPlusCategory.allCases) { cat in
                    chip(title: cat.title, icon: cat.icon, tint: cat.tint, isSelected: category == cat) {
                        category = (category == cat) ? nil : cat
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, icon: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? tint.opacity(0.22) : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? tint.opacity(0.45) : .clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? tint : .primary)
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("ابحث في الميزات…", text: $query)
                .textFieldStyle(.plain)
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func featureRow(_ feature: TigerPlusFeature) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(feature.category.tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(feature.category.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(feature.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if feature.isNew {
                        Text("جديد")
                            .font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(TigerTheme.orange.opacity(0.2)))
                            .foregroundStyle(TigerTheme.orange)
                    }
                }
                Text(feature.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Toggle("", isOn: Binding(
                get: { flags.isOn(feature.id) },
                set: { flags.set(feature.id, $0) }
            ))
            .labelsHidden()
            .tint(feature.category.tint)

            NavigationLink {
                TigerPlusRouteScreen(playlist: playlist, route: feature.route)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .opacity(flags.isOn(feature.id) ? 1 : 0.55)
        .tigerFocusCard(cornerRadius: Radius.md)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("لا ميزة تطابق بحثك")
                .font(.subheadline.weight(.semibold))
            Button("إظهار الكل") {
                query = ""
                category = nil
                showOnlyNew = false
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(TigerTheme.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var footerNote: some View {
        TigerInfoNote(
            text: "تُحفظ حالة كل ميزة هنا فورًا. المزايا الموصولة تعمل مباشرة (الفرز حسب الجودة، قنوات 4K، إخفاء البالغين، متابعة المشاهدة، سرعة التشغيل، نسبة العرض)، وبقية مفاتيح Tiger Plus ستُربط بسلوكها في تحديث قادم.",
            icon: "lightbulb.fill"
        )
        .padding(.top, 4)
    }
}

// MARK: - موجّه المسارات

struct TigerPlusRouteScreen: View {
    let playlist: Playlist?
    let route: TigerPlusRoute

    var body: some View {
        switch route {
        case .unifiedSearch:
            if let playlist {
                TigerPlusSearchView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "البحث الموحّد")
            }
        case .searchHistory:
            TigerSearchHistoryScreen()
        case .voiceSearch:
            TigerVoiceSearchScreen()
        case .inlineFilters:
            if let playlist {
                TigerFilterLabView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "الفلاتر الفورية")
            }
        case .playerGestures:
            TigerPlayerGesturesSettingsView()
        case .introSkip:
            TigerIntroSkipSettingsView()
        case .autoNext:
            TigerAutoNextSettingsView()
        case .resumePrompt:
            TigerResumePromptSettingsView()
        case .playbackQueue:
            if let playlist {
                TigerPlaybackQueueView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "قائمة التشغيل")
            }
        case .recommendations:
            if let playlist {
                TigerRecommendationsView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "محرّك الترشيحات")
            }
        case .smartRows:
            if let playlist {
                TigerSmartRowsView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "الصفوف الذكية")
            }
        case .randomDiscovery:
            if let playlist {
                TigerRandomDiscoveryView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "اكتشاف عشوائي")
            }
        case .similarContent:
            if let playlist {
                TigerSimilarContentView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "محتوى مشابه")
            }
        case .unwatched:
            if let playlist {
                TigerUnwatchedView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "غير المشاهد")
            }
        case .newEpisodes:
            if let playlist {
                TigerNewEpisodesView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "الحلقات الجديدة")
            }
        case .watchLater:
            if let playlist {
                WatchlistView(playlistId: playlist.id)
            } else {
                TigerPlusNeedsPlaylistView(title: "قائمة المشاهدة لاحقًا")
            }
        case .customPlaylists:
            if let playlist {
                TigerCustomPlaylistsView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "القوائم المخصّصة")
            }
        case .personalRatings:
            if let playlist {
                TigerPersonalRatingsView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "تقييمك الشخصي")
            }
        case .dataTransfer:
            if let playlist {
                TigerDataTransferView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "تصدير واستيراد")
            }
        case .completionTracking:
            if let playlist {
                TigerCompletionTrackingView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "تتبّع الإكمال")
            }
        case .channelHealth:
            if let playlist {
                TigerChannelHealthListView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "صحة القنوات")
            }
        case .channelFavorites:
            if let playlist {
                FavoritesView(playlist: playlist, initialType: "live")
            } else {
                TigerPlusNeedsPlaylistView(title: "قنواتي المفضّلة")
            }
        case .channelReorder:
            if let playlist {
                TigerChannelReorderView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "ترتيب القنوات")
            }
        case .epgReminders:
            if let playlist {
                EPGGuideView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "تذكيرات EPG")
            }
        case .bufferHealth:
            TigerNetworkPerformanceView()
        case .downloadPreferences:
            DownloadPolicySettingsView()
        case .downloadScheduler:
            TigerDownloadSchedulerView()
        case .downloadSpace:
            TigerDownloadSpaceView()
        case .offlineLibrary:
            if let playlist {
                DownloadsView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "المكتبة دون اتصال")
            }
        case .downloadProtection:
            TigerDownloadProtectionView()
        case .appLock:
            TigerAppLockSettingsView()
        case .kidsMode:
            TigerKidsScheduleView()
        case .profiles:
            TigerProfilesView()
        case .privacyDashboard:
            TigerPrivacySettingsView()
        case .notifications:
            TigerNotificationsSettingsView()
        case .icloudBackup:
            TigerCloudSyncSettingsView()
        case .shareCard:
            if let playlist {
                TigerShareCardView(playlist: playlist)
            } else {
                TigerPlusNeedsPlaylistView(title: "بطاقة المشاركة")
            }
        case .diagnosticsReport:
            DiagnosticsView(playlist: playlist)
        case .lowPower:
            TigerLowPowerView()
        case .coldStart:
            TigerColdStartView()
        case .typography:
            TigerTypographySettingsView()
        case .layoutStyle:
            TigerLayoutStyleSettingsView()
        case .aurora:
            TigerAuroraSettingsView()
        case .appIcons:
            TigerAppIconsView()
        case .themePerProfile:
            TigerThemePerProfileView()
        case .accessibility:
            TigerAccessibilitySettingsView()
        case .aboutPlatform:
            TigerPlatformInfoScreen()
        }
    }
}

/// شاشة بديلة عند غياب قائمة تشغيل.
struct TigerPlusNeedsPlaylistView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("تحتاج قائمة تشغيل")
                .font(.headline)
            Text("أضف قائمة تشغيل أولًا لتستخدم «\(title)».")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .navigationTitle(title)
        .tigerInlineNavigationTitle()
    }
}

// MARK: - شاشة معلومات المنصّة

struct TigerPlatformInfoScreen: View {
    @Environment(\.tigerMetrics) private var metrics

    var body: some View {
        TigerPlusScreen(
            title: "دعم أجهزة Apple",
            subtitle: "التطبيق يبني واجهته حسب الجهاز: آيفون، آيباد، ماك، Apple TV، وVision Pro — بنفس الهوية وتخطيط متجاوب.",
            icon: "apple.logo"
        ) {
            TigerSettingsCard(title: "الجهاز الحالي", icon: "desktopcomputer", tint: TigerTheme.gold) {
                TigerInfoRow(title: "النوع", value: TigerPlatform.kind.arabicName, icon: "iphone", tint: TigerTheme.gold)
                TigerInfoRow(title: "الطراز", value: TigerPlatform.deviceModel, icon: "cpu", tint: TigerTheme.gold)
                TigerInfoRow(title: "النظام", value: TigerPlatform.systemDescription, icon: "gear", tint: TigerTheme.gold)
                TigerInfoRow(
                    title: "الدقة",
                    value: "\(Int(TigerPlatform.screenSize.width))×\(Int(TigerPlatform.screenSize.height)) @\(String(format: "%.0f", TigerPlatform.screenScale))x",
                    icon: "rectangle.on.rectangle",
                    tint: TigerTheme.gold
                )
            }

            TigerSettingsCard(title: "التخطيط المتجاوب", icon: "square.grid.3x3.fill", tint: TigerTheme.orange) {
                TigerInfoRow(title: "أعمدة الشبكة", value: "\(metrics.gridColumns)", icon: "square.grid.2x2", tint: TigerTheme.orange)
                TigerInfoRow(title: "مقياس الخط", value: String(format: "%.2f×", metrics.layoutScale), icon: "textformat.size", tint: TigerTheme.orange)
                TigerInfoRow(title: "هامش المحتوى", value: "\(Int(metrics.contentPadding)) pt", icon: "arrow.left.and.right", tint: TigerTheme.orange)
                TigerInfoRow(title: "أقصى عرض", value: (metrics.maxContentWidth.map { $0.isFinite ? "\(Int($0)) pt" : "بلا حد" }) ?? "بلا حد", icon: "rectangle.expand.vertical", tint: TigerTheme.orange)
                TigerInfoRow(title: "شريط جانبي", value: metrics.usesSidebar ? "نعم" : "تبويبات", icon: "sidebar.left", tint: TigerTheme.orange)
            }

            TigerSettingsCard(title: "قدرات الجهاز", icon: "checkmark.seal.fill", tint: TigerTheme.brandLight) {
                capabilityRow("اللمس والإيماءات", TigerPlatform.supportsTouchGestures)
                capabilityRow("محرّك التركيز (Focus)", TigerPlatform.kind.usesFocusEngine)
                capabilityRow("المؤشّر ولوحة المفاتيح", TigerPlatform.kind.usesPointer || TigerPlatform.supportsKeyboardShortcuts)
                capabilityRow("الاهتزاز (Haptics)", TigerPlatform.supportsHaptics)
                capabilityRow("صورة داخل صورة (PiP)", TigerPlatform.supportsPiP)
            }

            TigerInfoNote(
                text: "على Apple TV وماك يعمل المشغّل بمحرّك AVPlayer الأصلي، وعلى آيفون وآيباد بمحرّك mpv لدعم صيغ IPTV الواسعة. الواجهة نفسها في كل الأجهزة.",
                icon: "play.rectangle.on.rectangle"
            )
        }
    }

    private func capabilityRow(_ title: String, _ supported: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: supported ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(supported ? TigerTheme.brandLight : Color.secondary)
            Text(title)
                .font(.subheadline)
            Spacer(minLength: 8)
            Text(supported ? "مدعوم" : "غير متاح")
                .font(.caption.weight(.semibold))
                .foregroundStyle(supported ? TigerTheme.brandLight : .secondary)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TigerPlusCenterView(playlist: nil)
    }
    .environmentObject(PlayerOverlayController())
    .tigerAdaptiveMetrics()
}
#endif
