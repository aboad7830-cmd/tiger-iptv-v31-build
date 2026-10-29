//
//  TigerPlusPlayer.swift
//  Tiger IPTV
//
//  حزمة v3.0 — ميزات المشغّل: الإيماءات، تخطّي المقدمة، التشغيل التلقائي،
//  استئناف المشاهدة، وقائمة التشغيل. كل الإعدادات محفوظة في UserDefaults
//  وتُطبَّق على المشغّل الحقيقي.
//

import SwiftUI
import Combine
import GRDB
import GRDBQuery

// MARK: - تفضيلات التشغيل

@MainActor
final class TigerPlaybackPrefs: ObservableObject {
    static let shared = TigerPlaybackPrefs()

    private let d = UserDefaults.standard

    @Published var doubleTapSeekSeconds: Int { didSet { d.set(doubleTapSeekSeconds, forKey: "tp.doubleTap") } }
    @Published var horizontalSwipeSeeks: Bool { didSet { d.set(horizontalSwipeSeeks, forKey: "tp.hSwipe") } }
    @Published var verticalSwipeVolume: Bool { didSet { d.set(verticalSwipeVolume, forKey: "tp.vSwipe") } }
    @Published var pinchZoom: Bool { didSet { d.set(pinchZoom, forKey: "tp.pinch") } }
    @Published var longPressSpeed: Bool { didSet { d.set(longPressSpeed, forKey: "tp.longPress") } }

    @Published var introSkipEnabled: Bool { didSet { d.set(introSkipEnabled, forKey: "tp.introSkip") } }
    @Published var introSkipSeconds: Int { didSet { d.set(introSkipSeconds, forKey: "tp.introSeconds") } }
    @Published var skipRecapEnabled: Bool { didSet { d.set(skipRecapEnabled, forKey: "tp.skipRecap") } }
    @Published var recapSeconds: Int { didSet { d.set(recapSeconds, forKey: "tp.recapSeconds") } }

    @Published var autoNextEnabled: Bool { didSet { d.set(autoNextEnabled, forKey: "tp.autoNext") } }
    @Published var autoNextCountdown: Int { didSet { d.set(autoNextCountdown, forKey: "tp.autoNextCountdown") } }

    @Published var resumePromptEnabled: Bool { didSet { d.set(resumePromptEnabled, forKey: "tp.resumePrompt") } }
    @Published var resumeThresholdSeconds: Int { didSet { d.set(resumeThresholdSeconds, forKey: "tp.resumeThreshold") } }
    @Published var rememberLastPosition: Bool { didSet { d.set(rememberLastPosition, forKey: "tp.rememberPosition") } }

    @Published var autoHideControls: Bool { didSet { d.set(autoHideControls, forKey: "tp.autoHide") } }
    @Published var autoHideDelay: Int { didSet { d.set(autoHideDelay, forKey: "tp.autoHideDelay") } }

    private init() {
        doubleTapSeekSeconds = (d.object(forKey: "tp.doubleTap") as? Int) ?? 10
        horizontalSwipeSeeks = (d.object(forKey: "tp.hSwipe") as? Bool) ?? true
        verticalSwipeVolume = (d.object(forKey: "tp.vSwipe") as? Bool) ?? true
        pinchZoom = (d.object(forKey: "tp.pinch") as? Bool) ?? true
        longPressSpeed = (d.object(forKey: "tp.longPress") as? Bool) ?? true
        introSkipEnabled = (d.object(forKey: "tp.introSkip") as? Bool) ?? true
        introSkipSeconds = (d.object(forKey: "tp.introSeconds") as? Int) ?? 85
        skipRecapEnabled = (d.object(forKey: "tp.skipRecap") as? Bool) ?? true
        recapSeconds = (d.object(forKey: "tp.recapSeconds") as? Int) ?? 45
        autoNextEnabled = (d.object(forKey: "tp.autoNext") as? Bool) ?? true
        autoNextCountdown = (d.object(forKey: "tp.autoNextCountdown") as? Int) ?? 10
        resumePromptEnabled = (d.object(forKey: "tp.resumePrompt") as? Bool) ?? true
        resumeThresholdSeconds = (d.object(forKey: "tp.resumeThreshold") as? Int) ?? 10
        rememberLastPosition = (d.object(forKey: "tp.rememberPosition") as? Bool) ?? true
        autoHideControls = (d.object(forKey: "tp.autoHide") as? Bool) ?? true
        autoHideDelay = (d.object(forKey: "tp.autoHideDelay") as? Int) ?? 4
    }

    var gestureConfig: TigerPlayerGestureConfig {
        TigerPlayerGestureConfig(
            doubleTapSeekSeconds: Double(doubleTapSeekSeconds),
            horizontalSwipeSeeks: horizontalSwipeSeeks,
            verticalSwipeAdjustsVolume: verticalSwipeVolume,
            pinchAdjustsZoom: pinchZoom,
            longPressShowsSpeed: longPressSpeed
        )
    }

    func reset() {
        doubleTapSeekSeconds = 10
        horizontalSwipeSeeks = true
        verticalSwipeVolume = true
        pinchZoom = true
        longPressSpeed = true
        introSkipEnabled = true
        introSkipSeconds = 85
        skipRecapEnabled = true
        recapSeconds = 45
        autoNextEnabled = true
        autoNextCountdown = 10
        resumePromptEnabled = true
        resumeThresholdSeconds = 10
        rememberLastPosition = true
        autoHideControls = true
        autoHideDelay = 4
    }
}

// MARK: - كاشف المقدمة

enum TigerIntroSkipDetector {
    static func isInsideIntro(position: Double, duration: Double, introSeconds: Int) -> Bool {
        guard introSeconds > 0, duration > 0 else { return false }
        return position >= 0 && position < Double(introSeconds)
    }

    static func isInsideRecap(position: Double, duration: Double, recapSeconds: Int) -> Bool {
        guard recapSeconds > 0, duration > 0 else { return false }
        return position >= 0 && position < Double(recapSeconds)
    }

    static func label(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 { return "\(m) د \(s) ث" }
        return "\(s) ث"
    }
}

// MARK: - شاشة إيماءات المشغّل

struct TigerPlayerGesturesSettingsView: View {
    @StateObject private var prefs = TigerPlaybackPrefs.shared

    var body: some View {
        TigerPlusScreen(
            title: "إيماءات المشغّل",
            subtitle: "تحكّم كامل في اللمس والسحب والقرص داخل المشغّل.",
            icon: "hand.draw"
        ) {
            TigerSettingsCard(title: "النقر المزدوج", subtitle: "مدة التقديم/التأخير عند النقر مرتين على الجانبين.", icon: "hand.tap", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("المدة").font(.subheadline)
                        Spacer()
                        Text("\(prefs.doubleTapSeekSeconds) ث").font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.orange)
                    }
                    Slider(value: Binding(
                        get: { Double(prefs.doubleTapSeekSeconds) },
                        set: { prefs.doubleTapSeekSeconds = Int($0) }
                    ), in: 5...60, step: 5)
                    .tint(TigerTheme.orange)
                }
            }

            TigerSettingsCard(title: "الإيماءات", subtitle: nil, icon: "waveform.path", tint: TigerTheme.brandLight) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "السحب الأفقي", subtitle: "تقديم/تأخير بالسحب يمينًا ويسارًا", icon: "arrow.left.and.right", tint: TigerTheme.orange, isOn: $prefs.horizontalSwipeSeeks)
                    Divider()
                    TigerToggleRow(title: "السحب العمودي", subtitle: "ضبط مستوى الصوت بالسحب لأعلى/أسفل", icon: "speaker.wave.2", tint: TigerTheme.orange, isOn: $prefs.verticalSwipeVolume)
                    Divider()
                    TigerToggleRow(title: "القرص للتكبير", subtitle: "تكبير/تصغير الصورة بإصبعين", icon: "arrow.up.left.and.arrow.down.right", tint: TigerTheme.orange, isOn: $prefs.pinchZoom)
                    Divider()
                    TigerToggleRow(title: "الضغط المطوّل", subtitle: "تشغيل سريع مؤقت عند الاستمرار بالضغط", icon: "forward.fill", tint: TigerTheme.orange, isOn: $prefs.longPressSpeed)
                }
            }

            TigerSettingsCard(title: "إخفاء الأزرار تلقائيًا", subtitle: "تختفي أدوات التحكّم أثناء التشغيل بعد فترة خمول.", icon: "eye.slash", tint: TigerTheme.gold) {
                VStack(alignment: .leading, spacing: 8) {
                    TigerToggleRow(title: "تفعيل الإخفاء التلقائي", icon: "timer", tint: TigerTheme.gold, isOn: $prefs.autoHideControls)
                    if prefs.autoHideControls {
                        HStack {
                            Text("المدة قبل الإخفاء").font(.subheadline)
                            Spacer()
                            Text("\(prefs.autoHideDelay) ث").font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.gold)
                        }
                        Slider(value: Binding(
                            get: { Double(prefs.autoHideDelay) },
                            set: { prefs.autoHideDelay = Int($0) }
                        ), in: 2...12, step: 1)
                        .tint(TigerTheme.gold)
                    }
                }
            }

            Button(role: .destructive) {
                prefs.reset()
            } label: {
                Label("إعادة ضبط الإيماءات", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - شاشة تخطّي المقدمة

struct TigerIntroSkipSettingsView: View {
    @StateObject private var prefs = TigerPlaybackPrefs.shared

    var body: some View {
        TigerPlusScreen(
            title: "تخطّي المقدمة والملخّص",
            subtitle: "زر ذكي يظهر تلقائيًا لتجاوز مقدمة المسلسل أو ملخّص الحلقة السابقة.",
            icon: "forward.end"
        ) {
            TigerSettingsCard(title: "المقدمة", subtitle: "يظهر زر «تخطّي المقدمة» في بداية كل حلقة.", icon: "play.rectangle", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 8) {
                    TigerToggleRow(title: "تفعيل تخطّي المقدمة", icon: "checkmark.circle", tint: TigerTheme.orange, isOn: $prefs.introSkipEnabled)
                    if prefs.introSkipEnabled {
                        HStack {
                            Text("طول المقدمة").font(.subheadline)
                            Spacer()
                            Text(TigerIntroSkipDetector.label(seconds: prefs.introSkipSeconds))
                                .font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.orange)
                        }
                        Slider(value: Binding(
                            get: { Double(prefs.introSkipSeconds) },
                            set: { prefs.introSkipSeconds = Int($0) }
                        ), in: 15...240, step: 5)
                        .tint(TigerTheme.orange)
                        Text("يُقترح 85 ثانية للمسلسلات العربية و90 ثانية للأجنبية.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            TigerSettingsCard(title: "ملخّص الحلقة السابقة", subtitle: "تجاوز «ما حدث سابقًا» في بداية الحلقات المتتابعة.", icon: "text.line.first.and.arrowtriangle.forward", tint: TigerTheme.brandLight) {
                VStack(alignment: .leading, spacing: 8) {
                    TigerToggleRow(title: "تفعيل تخطّي الملخّص", icon: "checkmark.circle", tint: TigerTheme.brandLight, isOn: $prefs.skipRecapEnabled)
                    if prefs.skipRecapEnabled {
                        HStack {
                            Text("طول الملخّص").font(.subheadline)
                            Spacer()
                            Text(TigerIntroSkipDetector.label(seconds: prefs.recapSeconds))
                                .font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.brandLight)
                        }
                        Slider(value: Binding(
                            get: { Double(prefs.recapSeconds) },
                            set: { prefs.recapSeconds = Int($0) }
                        ), in: 10...120, step: 5)
                        .tint(TigerTheme.brandLight)
                    }
                }
            }

            TigerIntroSkipPreviewCard()
        }
    }
}

private struct TigerIntroSkipPreviewCard: View {
    @State private var position: Double = 12
    private let duration: Double = 2700

    var body: some View {
        TigerSettingsCard(title: "معاينة حيّة", subtitle: "جرّب كيف يبدو زر التخطّي أثناء التشغيل.", icon: "eye", tint: TigerTheme.gold) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 120)
                    if position < 85 {
                        Button {
                            withAnimation(TigerMotion.snappy) { position = 90 }
                        } label: {
                            Label("تخطّي المقدمة", systemImage: "forward.end.fill")
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("بدأت الحلقة فعليًا ✓")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Slider(value: $position, in: 0...300)
                    .tint(TigerTheme.gold)
                Text("الموضع: \(Int(position)) ث")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - شاشة التشغيل التلقائي

struct TigerAutoNextSettingsView: View {
    @StateObject private var prefs = TigerPlaybackPrefs.shared

    var body: some View {
        TigerPlusScreen(
            title: "التشغيل التلقائي للحلقات",
            subtitle: "ينتقل تلقائيًا إلى الحلقة التالية مع عدّاد تنازلي يمكن إلغاؤه.",
            icon: "play.circle"
        ) {
            TigerSettingsCard(title: "الانتقال التلقائي", subtitle: nil, icon: "arrow.right.circle", tint: TigerTheme.orange) {
                VStack(alignment: .leading, spacing: 8) {
                    TigerToggleRow(title: "تشغيل الحلقة التالية تلقائيًا", subtitle: "عند انتهاء الحلقة الحالية", icon: "infinity", tint: TigerTheme.orange, isOn: $prefs.autoNextEnabled)
                    if prefs.autoNextEnabled {
                        HStack {
                            Text("مدة العدّاد").font(.subheadline)
                            Spacer()
                            Text("\(prefs.autoNextCountdown) ث").font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.orange)
                        }
                        Slider(value: Binding(
                            get: { Double(prefs.autoNextCountdown) },
                            set: { prefs.autoNextCountdown = Int($0) }
                        ), in: 3...30, step: 1)
                        .tint(TigerTheme.orange)
                    }
                }
            }

            TigerAutoNextCountdownPreview()
        }
    }
}

private struct TigerAutoNextCountdownPreview: View {
    @State private var remaining: Int = 10
    @State private var running = false

    var body: some View {
        TigerSettingsCard(title: "معاينة العدّاد", subtitle: "شكل العدّاد عند نهاية الحلقة.", icon: "timer", tint: TigerTheme.gold) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 6)
                        .frame(width: 92, height: 92)
                    Circle()
                        .trim(from: 0, to: CGFloat(remaining) / 10.0)
                        .stroke(TigerTheme.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 92, height: 92)
                        .animation(.linear(duration: 1), value: remaining)
                    Text("\(remaining)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                }
                Text("الحلقة التالية بعد \(remaining) ثانية")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button(running ? "إيقاف" : "بدء المعاينة") {
                        running ? stop() : start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TigerTheme.orange)
                    Button("إلغاء") { stop(); remaining = 10 }
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func start() {
        running = true
        remaining = 10
        tick()
    }

    private func stop() {
        running = false
    }

    private func tick() {
        guard running, remaining > 0 else { running = false; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard running else { return }
            remaining -= 1
            tick()
        }
    }
}

// MARK: - شاشة استئناف المشاهدة

struct TigerResumePromptSettingsView: View {
    @StateObject private var prefs = TigerPlaybackPrefs.shared

    var body: some View {
        TigerPlusScreen(
            title: "استئناف المشاهدة",
            subtitle: "يتذكّر آخر موضع شاهدته ويعرض بطاقة استئناف عند العودة.",
            icon: "clock.arrow.circlepath"
        ) {
            TigerSettingsCard(title: "الذاكرة", subtitle: nil, icon: "bookmark", tint: TigerTheme.orange) {
                VStack(spacing: 14) {
                    TigerToggleRow(title: "تذكّر آخر موضع", subtitle: "يحفظ الموضع لكل فيلم وحلقة", icon: "bookmark.fill", tint: TigerTheme.orange, isOn: $prefs.rememberLastPosition)
                    Divider()
                    TigerToggleRow(title: "عرض بطاقة الاستئناف", subtitle: "بطاقة «متابعة من حيث توقفت»", icon: "play.circle", tint: TigerTheme.orange, isOn: $prefs.resumePromptEnabled)
                }
            }

            TigerSettingsCard(title: "حد الاستئناف", subtitle: "لن تُعرض البطاقة إذا كان الموضع قريبًا جدًا من البداية.", icon: "slider.horizontal.3", tint: TigerTheme.brandLight) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("الحد الأدنى").font(.subheadline)
                        Spacer()
                        Text(TigerIntroSkipDetector.label(seconds: prefs.resumeThresholdSeconds))
                            .font(.subheadline.weight(.bold)).foregroundStyle(TigerTheme.brandLight)
                    }
                    Slider(value: Binding(
                        get: { Double(prefs.resumeThresholdSeconds) },
                        set: { prefs.resumeThresholdSeconds = Int($0) }
                    ), in: 5...120, step: 5)
                    .tint(TigerTheme.brandLight)
                }
            }

            TigerResumeCardPreview()
        }
    }
}

private struct TigerResumeCardPreview: View {
    var body: some View {
        TigerSettingsCard(title: "شكل البطاقة", subtitle: nil, icon: "rectangle.on.rectangle", tint: TigerTheme.gold) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(TigerTheme.orangeGradient)
                    .frame(width: 64, height: 88)
                    .overlay(Image(systemName: "film").foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 4) {
                    Text("اسم الفيلم أو الحلقة").font(.subheadline.weight(.bold)).lineLimit(1)
                    Text("توقفت عند 42:15").font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: 0.62).tint(TigerTheme.orange)
                    Button {
                    } label: {
                        Label("متابعة المشاهدة", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TigerTheme.orange)
                    .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - قائمة التشغيل

struct TigerPlaybackQueueView: View {
    let playlist: Playlist

    @Query<RecentWatchHistoryRequest> private var recent: [DBWatchHistory]
    @EnvironmentObject private var playerOverlay: PlayerOverlayController

    @State private var queue: [DBWatchHistory] = []
    @State private var editMode: EditMode = .inactive

    init(playlist: Playlist) {
        self.playlist = playlist
        _recent = Query(RecentWatchHistoryRequest(playlistId: playlist.id, limit: 40), in: \.appDatabase)
    }

    var body: some View {
        TigerPlusScreen(
            title: "قائمة التشغيل",
            subtitle: "رتّب ما ستشاهده تاليًا من سجلّ المشاهدة الأخير.",
            icon: "list.bullet.rectangle"
        ) {
            if queue.isEmpty {
                TigerInfoNote(text: "لا توجد عناصر في القائمة. ستُملأ تلقائيًا من سجلّ المشاهدة الأخير.", icon: "tray", tint: TigerTheme.orange)
            } else {
                TigerSettingsCard(title: "القائمة (\(queue.count))", subtitle: "اسحب لإعادة الترتيب أو احذف للإزالة.", icon: "list.number", tint: TigerTheme.orange) {
                    VStack(spacing: 0) {
                        ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                            queueRow(item, index: index)
                            if index < queue.count - 1 { Divider() }
                        }
                    }
                }

                Button {
                    playFirst()
                } label: {
                    Label("تشغيل القائمة", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(TigerTheme.orange)

                Button(role: .destructive) {
                    queue.removeAll()
                } label: {
                    Label("تفريغ القائمة", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .toolbar {
            ToolbarItem(placement: TigerPlatform.trailingPlacement) {
                Button {
                    withAnimation { editMode = editMode == .active ? .inactive : .active }
                } label: {
                    Image(systemName: editMode == .active ? "checkmark" : "arrow.up.arrow.down")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .onAppear {
            if queue.isEmpty { queue = Array(recent.prefix(20)) }
        }
        .onChange(of: recent) { _, newValue in
            if queue.isEmpty { queue = Array(newValue.prefix(20)) }
        }
    }

    private func queueRow(_ item: DBWatchHistory, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            CachedImage(url: item.imageURL.flatMap { URL(string: $0) }, width: 48, height: 64, cornerRadius: Radius.sm, contentMode: .fill, iconName: "film")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(progressLabel(item)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if editMode == .active {
                Button(role: .destructive) {
                    queue.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    private func progressLabel(_ item: DBWatchHistory) -> String {
        guard item.durationMs > 0 else { return item.type == "live" ? "بث مباشر" : "لم يُشاهد" }
        let pct = Int(min(max(Double(item.lastTimeMs) / Double(item.durationMs), 0), 1) * 100)
        return "أُنجز \(pct)%"
    }

    private func playFirst() {
        guard let first = queue.first else { return }
        let builder = PlaybackURLBuilder(playlist: playlist)
        let url: URL?
        switch first.type {
        case "live":
            url = builder.liveURL(streamId: Int(first.streamId) ?? 0, extension: first.containerExtension)
        case "series":
            url = builder.seriesURL(streamId: first.streamId, containerExtension: first.containerExtension)
        default:
            url = builder.movieURL(streamId: Int(first.streamId) ?? 0, containerExtension: first.containerExtension)
        }
        guard let url else { return }
        let item = first
        playerOverlay.present(playlistId: playlist.id) {
            PlayerView(
                url: url,
                title: item.title,
                subtitle: item.secondaryTitle,
                artworkURL: item.imageURL.flatMap { URL(string: $0) },
                isLiveStream: item.type == "live",
                playlistId: playlist.id,
                streamId: item.streamId,
                type: item.type,
                seriesId: item.seriesId,
                resumeTimeMs: item.lastTimeMs,
                containerExtension: item.containerExtension
            )
        }
    }
}
