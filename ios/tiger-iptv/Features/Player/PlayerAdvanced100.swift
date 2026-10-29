//
//  PlayerAdvanced100.swift
//  Tiger IPTV
//
//  مزايا المشغّل المتقدمة (21–25) + مزايا تجربة المشاهدة (81–85)
//  ملف مستقل بالكامل: لا يعدّل أي ملف موجود، ويضيف أنواعًا جديدة فقط.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 21) سرعة التشغيل مع تصحيح النغمة (0.5× – 2.0×)

/// سرعات جاهزة + سرعة مخصّصة، مع حفظ آخر اختيار لكل مستخدم.
enum TigerPlaybackSpeed {
    static let presets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    static let minimum: Double = 0.5
    static let maximum: Double = 2.0

    static func label(_ value: Double) -> String {
        if abs(value - 1.0) < 0.001 { return "1×" }
        let rounded = (value * 100).rounded() / 100
        if abs(rounded - rounded.rounded()) < 0.001 {
            return String(format: "%.0f×", rounded)
        }
        return String(format: "%.2f×", rounded).replacingOccurrences(of: "0×", with: "×")
    }

    static func clamp(_ value: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}

// MARK: - 22) تزامن الصوت والصورة (±2000 مللي ثانية)

enum TigerAVSync {
    static let limitMs: Double = 2000
    static let stepMs: Double = 50

    static func clamp(_ ms: Double) -> Double { min(max(ms, -limitMs), limitMs) }
    static func label(_ ms: Double) -> String {
        let v = Int(ms.rounded())
        if v == 0 { return "0 ms" }
        return v > 0 ? "+\(v) ms" : "\(v) ms"
    }
}

// MARK: - 23) منتقي مسارات الصوت والترجمة

struct TigerTrackOption: Identifiable, Hashable {
    let id: Int
    let title: String
    let detail: String?
    let languageCode: String?
    let isExternal: Bool

    var subtitle: String {
        [languageCode?.uppercased(), detail].compactMap { $0 }.joined(separator: " · ")
    }
}

// MARK: - 24) قائمة سرعات + منتقي المسارات + ترجمة خارجية

@MainActor
final class PlayerAdvancedStore: ObservableObject {
    static let shared = PlayerAdvancedStore()

    @Published var speed: Double {
        didSet {
            speed = TigerPlaybackSpeed.clamp(speed)
            defaults.set(speed, forKey: Keys.speed)
        }
    }

    @Published var audioDelayMs: Double {
        didSet {
            audioDelayMs = TigerAVSync.clamp(audioDelayMs)
            defaults.set(audioDelayMs, forKey: Keys.audioDelay)
        }
    }

    @Published var subtitleDelayMs: Double {
        didSet {
            subtitleDelayMs = TigerAVSync.clamp(subtitleDelayMs)
            defaults.set(subtitleDelayMs, forKey: Keys.subDelay)
        }
    }

    @Published var autoHideControls: Bool {
        didSet { defaults.set(autoHideControls, forKey: Keys.autoHide) }
    }

    @Published var autoHideDelay: Double {
        didSet { defaults.set(autoHideDelay, forKey: Keys.autoHideDelay) }
    }

    @Published var nightModeButtons: Bool {
        didSet { defaults.set(nightModeButtons, forKey: Keys.nightButtons) }
    }

    @Published var rememberSpeedPerPlaylist: Bool {
        didSet { defaults.set(rememberSpeedPerPlaylist, forKey: Keys.perPlaylist) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let speed = "player.adv.speed"
        static let audioDelay = "player.adv.audioDelay"
        static let subDelay = "player.adv.subDelay"
        static let autoHide = "player.adv.autoHide"
        static let autoHideDelay = "player.adv.autoHideDelay"
        static let nightButtons = "player.adv.nightButtons"
        static let perPlaylist = "player.adv.perPlaylist"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedSpeed = defaults.object(forKey: Keys.speed) as? Double ?? 1.0
        speed = TigerPlaybackSpeed.clamp(storedSpeed)
        audioDelayMs = TigerAVSync.clamp(defaults.object(forKey: Keys.audioDelay) as? Double ?? 0)
        subtitleDelayMs = TigerAVSync.clamp(defaults.object(forKey: Keys.subDelay) as? Double ?? 0)
        autoHideControls = defaults.object(forKey: Keys.autoHide) as? Bool ?? true
        let delay = defaults.object(forKey: Keys.autoHideDelay) as? Double ?? 3.5
        autoHideDelay = min(max(delay, 1.5), 12)
        nightModeButtons = defaults.object(forKey: Keys.nightButtons) as? Bool ?? true
        rememberSpeedPerPlaylist = defaults.object(forKey: Keys.perPlaylist) as? Bool ?? true
    }

    /// يطبّق الإعدادات الحالية على مشغّل mpv.
    func apply(to player: MPVPlayer) {
        player.setPlaybackRate(speed)
        // mpv يستخدم `audio-delay` بالثواني، والترجمة `sub-delay`.
        player.setAudioDelay(seconds: audioDelayMs / 1000.0)
        player.setSubDelay(seconds: subtitleDelayMs / 1000.0)
    }

    func resetDelays() {
        audioDelayMs = 0
        subtitleDelayMs = 0
    }

    func bumpSpeed(by delta: Double) {
        speed = TigerPlaybackSpeed.clamp(speed + delta)
    }

    // MARK: حفظ السرعة لكل قائمة تشغيل

    func storedSpeed(forPlaylist id: UUID) -> Double? {
        guard rememberSpeedPerPlaylist else { return nil }
        return defaults.object(forKey: "player.adv.speed.\(id.uuidString)") as? Double
    }

    func storeSpeed(_ value: Double, forPlaylist id: UUID) {
        guard rememberSpeedPerPlaylist else { return }
        defaults.set(TigerPlaybackSpeed.clamp(value), forKey: "player.adv.speed.\(id.uuidString)")
    }
}

// MARK: - واجهة السرعة

struct TigerSpeedPickerView: View {
    @ObservedObject var player: MPVPlayer
    @ObservedObject private var store = PlayerAdvancedStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TigerPlaybackSpeed.presets, id: \.self) { value in
                        Button {
                            store.speed = value
                            player.setPlaybackRate(value)
                            HapticEngine.selection()
                        } label: {
                            HStack {
                                Text(TigerPlaybackSpeed.label(value))
                                    .font(.body.weight(abs(store.speed - value) < 0.001 ? .bold : .regular))
                                Spacer()
                                if abs(store.speed - value) < 0.001 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(TigerTheme.gold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(L("player.speed"))
                } footer: {
                    Text(L("player.speed.footer"))
                }

                Section {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text(L("player.speed.custom"))
                            Spacer()
                            Text(TigerPlaybackSpeed.label(store.speed))
                                .monospacedDigit()
                                .foregroundStyle(TigerTheme.gold)
                        }
                        Slider(
                            value: Binding(
                                get: { store.speed },
                                set: { store.speed = $0 }
                            ),
                            in: TigerPlaybackSpeed.minimum ... TigerPlaybackSpeed.maximum,
                            step: 0.05
                        ) { editing in
                            if !editing { player.setPlaybackRate(store.speed) }
                        }
                        .tint(TigerTheme.gold)
                    }
                    .padding(.vertical, Spacing.xs)

                    Toggle(L("player.speed.remember"), isOn: $store.rememberSpeedPerPlaylist)
                } header: {
                    Text(L("player.speed.advanced"))
                }
            }
            .navigationTitle(L("player.speed"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - واجهة تزامن الصوت/الترجمة

struct TigerAVSyncView: View {
    var player: MPVPlayer?
    @ObservedObject private var store = PlayerAdvancedStore.shared

    var body: some View {
        List {
            Section {
                syncRow(
                    title: L("player.sync.audio"),
                    value: $store.audioDelayMs,
                    onChange: { player?.setAudioDelay(seconds: $0 / 1000.0) }
                )
            } header: {
                Text(L("player.sync.audio"))
            } footer: {
                Text(L("player.sync.footer"))
            }

            Section {
                syncRow(
                    title: L("player.sync.subtitle"),
                    value: $store.subtitleDelayMs,
                    onChange: { player?.setSubDelay(seconds: $0 / 1000.0) }
                )
            } header: {
                Text(L("player.sync.subtitle"))
            }

            Section {
                Button(role: .destructive) {
                    store.resetDelays()
                    player?.setAudioDelay(seconds: 0)
                    player?.setSubDelay(seconds: 0)
                    HapticEngine.warning()
                } label: {
                    Label(L("player.sync.reset"), systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle(L("player.sync"))
    }

    private func syncRow(
        title: String,
        value: Binding<Double>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                Spacer()
                Text(TigerAVSync.label(value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(TigerTheme.gold)
            }
            HStack(spacing: Spacing.sm) {
                Button {
                    value.wrappedValue = TigerAVSync.clamp(value.wrappedValue - TigerAVSync.stepMs)
                    onChange(value.wrappedValue)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { value.wrappedValue },
                        set: { value.wrappedValue = TigerAVSync.clamp($0) }
                    ),
                    in: -TigerAVSync.limitMs ... TigerAVSync.limitMs,
                    step: TigerAVSync.stepMs
                ) { editing in
                    if !editing { onChange(value.wrappedValue) }
                }
                .tint(TigerTheme.gold)

                Button {
                    value.wrappedValue = TigerAVSync.clamp(value.wrappedValue + TigerAVSync.stepMs)
                    onChange(value.wrappedValue)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(TigerTheme.brand)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - منتقي المسارات

struct TigerTrackPickerView: View {
    @ObservedObject var player: MPVPlayer
    @Environment(\.dismiss) private var dismiss

    @State private var video: [TigerTrackOption] = []
    @State private var audio: [TigerTrackOption] = []
    @State private var subtitles: [TigerTrackOption] = []
    @State private var currentAudio: Int = -1
    @State private var currentSubtitle: Int = -1
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            row(title: L("player.subtitle_off"), selected: currentSubtitle < 0) {
                                player.selectSubtitleTrack(id: -1)
                                currentSubtitle = -1
                                HapticEngine.selection()
                            }
                            ForEach(subtitles) { track in
                                row(title: track.title, subtitle: track.subtitle, selected: currentSubtitle == track.id) {
                                    player.selectSubtitleTrack(id: track.id)
                                    currentSubtitle = track.id
                                    HapticEngine.selection()
                                }
                            }
                        } header: {
                            Text(L("player.subtitles"))
                        }

                        Section {
                            ForEach(audio) { track in
                                row(title: track.title, subtitle: track.subtitle, selected: currentAudio == track.id) {
                                    player.selectAudioTrack(id: track.id)
                                    currentAudio = track.id
                                    HapticEngine.selection()
                                }
                            }
                        } header: {
                            Text(L("player.audio"))
                        }

                        if !video.isEmpty {
                            Section {
                                ForEach(video) { track in
                                    row(title: track.title, subtitle: track.subtitle, selected: false) {
                                        player.selectVideoTrack(id: track.id)
                                        HapticEngine.selection()
                                    }
                                }
                            } header: {
                                Text(L("player.video"))
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("player.tracks"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { reload() }
    }

    private func reload() {
        isLoading = true
        player.reloadTrackList { v, a, s, _, aid, sid in
            video = v.map(Self.map)
            audio = a.map(Self.map)
            subtitles = s.filter { $0.id >= 0 }.map(Self.map)
            currentAudio = aid
            currentSubtitle = sid
            isLoading = false
        }
    }

    private static func map(_ option: TrackMenuOption) -> TigerTrackOption {
        TigerTrackOption(
            id: option.id,
            title: option.title,
            detail: option.detail,
            languageCode: option.langCode,
            isExternal: option.isExternal
        )
    }

    private func row(
        title: String,
        subtitle: String? = nil,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(TigerTheme.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 25) تحميل ترجمة خارجية (SRT/VTT) مع إزاحة زمنية

#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

struct TigerSubtitleFileImporter: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.init(filenameExtension: "srt") ?? .plainText,
                               .init(filenameExtension: "vtt") ?? .plainText,
                               .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
#endif

/// ينسخ ملف الترجمة إلى مجلد التطبيق ثم يمرّره إلى mpv.
@MainActor
enum TigerExternalSubtitleLoader {
    static func stage(url: URL) -> String? {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("ExternalSubtitles", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        try? fm.removeItem(at: destination)
        do {
            try fm.copyItem(at: url, to: destination)
            return destination.path
        } catch {
            Log.error("Subtitle", "stage failed: \(error.localizedDescription)")
            return nil
        }
    }
}

struct TigerExternalSubtitleButton: View {
    @ObservedObject var player: MPVPlayer
    @State private var showingPicker = false
    @State private var message: String?

    var body: some View {
        Button {
            #if canImport(UIKit)
            showingPicker = true
            #else
            message = L("player.subtitles.unsupported")
            #endif
        } label: {
            Label(L("player.subtitles.load"), systemImage: "captions.bubble")
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingPicker) {
            TigerSubtitleFileImporter { url in
                showingPicker = false
                if let path = TigerExternalSubtitleLoader.stage(url: url) {
                    player.addExternalSubtitle(filePath: path, title: url.lastPathComponent, select: true)
                    HapticEngine.success()
                    ToastCenter.shared.show(L("player.subtitles.loaded"), style: .success)
                } else {
                    ToastCenter.shared.show(L("player.subtitles.failed"), style: .error)
                }
            }
        }
        #endif
    }
}

// MARK: - 81) إخفاء أدوات التحكم تلقائيًا

@MainActor
final class ControlsAutoHideController: ObservableObject {
    @Published private(set) var isVisible = true
    private var hideTask: Task<Void, Never>?

    func reveal(delay: Double? = nil) {
        isVisible = true
        scheduleHide(after: delay ?? PlayerAdvancedStore.shared.autoHideDelay)
    }

    func hideNow() {
        hideTask?.cancel()
        withAnimation(TigerMotion.quick) { isVisible = false }
    }

    func toggle() {
        if isVisible { hideNow() } else { reveal() }
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        guard PlayerAdvancedStore.shared.autoHideControls else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                withAnimation(TigerMotion.quick) { self.isVisible = false }
            }
        }
    }
}

// MARK: - 82) معاينة أثناء السحب على شريط التقدم

struct TigerScrubPreview: View {
    let fraction: Double
    let duration: Double
    let thumbnailURL: URL?

    private var seconds: Double { max(0, min(duration, duration * fraction)) }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if let thumbnailURL {
                CachedImage(
                    url: thumbnailURL,
                    width: 160,
                    height: 90,
                    cornerRadius: Radius.sm,
                    contentMode: .fill
                )
            }
            Text(TigerNumerals.duration(seconds))
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - 83) أزرار ليلية منخفضة الإضاءة

struct TigerNightModeControls: View {
    @ObservedObject var player: MPVPlayer
    @ObservedObject private var store = PlayerAdvancedStore.shared

    private var tint: Color { store.nightModeButtons ? Color(white: 0.62) : .white }

    var body: some View {
        HStack(spacing: Spacing.lg) {
            control("gobackward.15") { player.seek(to: max(0, player.position - 15)) }
            control("gobackward.5") { player.seek(to: max(0, player.position - 5)) }
            control("plus.slash.minus") { store.bumpSpeed(by: -0.25); player.setPlaybackRate(store.speed) }
            control("plus.magnifyingglass") { store.bumpSpeed(by: 0.25); player.setPlaybackRate(store.speed) }
            control("goforward.5") { player.seek(to: player.position + 5) }
            control("goforward.15") { player.seek(to: player.position + 15) }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.black.opacity(0.45), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticEngine.soft()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 84) شريط تقدم يتلوّن حسب الحالة

enum TigerProgressState {
    case idle, buffering, playing, paused, error

    var tint: Color {
        switch self {
        case .idle: return Color.white.opacity(0.35)
        case .buffering: return TigerTheme.gold
        case .playing: return TigerTheme.brandLight
        case .paused: return Color.white.opacity(0.6)
        case .error: return Color.red
        }
    }

    var symbol: String? {
        switch self {
        case .buffering: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        default: return nil
        }
    }
}

struct TigerStateProgressBar: View {
    let progress: Double
    let buffered: Double
    let state: TigerProgressState
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: max(0, min(1, buffered)) * geo.size.width)
                Capsule()
                    .fill(state.tint)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .animation(TigerMotion.quick, value: progress)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

// MARK: - 85) إيماءات مخصّصة للمشغّل

struct TigerPlayerGestureConfig: Equatable {
    var doubleTapSeekSeconds: Double = 10
    var horizontalSwipeSeeks = true
    var verticalSwipeAdjustsVolume = true
    var pinchAdjustsZoom = true
    var longPressShowsSpeed = true
}

struct TigerPlayerGestureLayer: View {
    @ObservedObject var player: MPVPlayer
    var config = TigerPlayerGestureConfig()
    var onSingleTap: () -> Void
    var onLongPress: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var dragDirection: DragDirection = .none
    @State private var baseVolume: Double = 100

    private enum DragDirection { case none, horizontal, vertical }

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            if dragDirection == .none {
                                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                                dragDirection = horizontal ? .horizontal : .vertical
                                if !horizontal { baseVolume = player.volume }
                            }
                            dragOffset = value.translation.width
                            if dragDirection == .vertical, config.verticalSwipeAdjustsVolume {
                                let delta = -value.translation.height / max(geo.size.height, 1) * 120
                                player.setVolume(min(130, max(0, baseVolume + delta)))
                            }
                        }
                        .onEnded { value in
                            defer {
                                dragDirection = .none
                                withAnimation(TigerMotion.snappy) { dragOffset = 0 }
                            }
                            guard config.horizontalSwipeSeeks, dragDirection == .horizontal else { return }
                            let ratio = value.translation.width / max(geo.size.width, 1)
                            let target = player.position + Double(ratio) * 180
                            player.seek(to: max(0, target))
                            HapticEngine.soft()
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        let delta = config.doubleTapSeekSeconds
                        player.seek(to: max(0, player.position + delta))
                        HapticEngine.soft()
                    }
                )
                .simultaneousGesture(
                    TapGesture(count: 1).onEnded { onSingleTap() }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                        guard config.longPressShowsSpeed else { return }
                        onLongPress()
                    }
                )
                .overlay(alignment: .center) {
                    if abs(dragOffset) > 40, config.horizontalSwipeSeeks {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: dragOffset > 0 ? "goforward" : "gobackward")
                            Text(TigerNumerals.duration(abs(Double(dragOffset) / max(geo.size.width, 1)) * 180))
                        }
                        .font(.headline.monospacedDigit())
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                    }
                }
        }
    }
}

// MARK: - لوحة إعدادات المشغّل الكاملة

struct PlayerAdvancedSettingsView: View {
    @ObservedObject private var store = PlayerAdvancedStore.shared

    var body: some View {
        List {
            Section {
                Toggle(L("player.autohide"), isOn: $store.autoHideControls)
                if store.autoHideControls {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(L("player.autohide.delay"))
                            Spacer()
                            Text(String(format: "%.1f s", store.autoHideDelay))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $store.autoHideDelay, in: 1.5 ... 12, step: 0.5)
                            .tint(TigerTheme.gold)
                    }
                }
                Toggle(L("player.night.buttons"), isOn: $store.nightModeButtons)
            } header: {
                Text(L("player.section.controls"))
            } footer: {
                Text(L("player.autohide.footer"))
            }

            Section {
                NavigationLink {
                    TigerAVSyncView(player: nil)
                } label: {
                    Label(L("player.sync"), systemImage: "waveform.path")
                }
            } header: {
                Text(L("player.section.sync"))
            }
        }
        .navigationTitle(L("player.settings"))
    }
}
