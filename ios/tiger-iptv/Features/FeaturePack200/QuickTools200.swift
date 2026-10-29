import SwiftUI
import Foundation
import Combine
import UIKit

// MARK: - سياق الأدوات

/// سياق استخدام شريط الأدوات السريعة: البث المباشر، الأفلام، المسلسلات.
enum TigerToolContext: String, CaseIterable, Identifiable {
    case live, movies, series

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: return "أدوات البث المباشر"
        case .movies: return "أدوات الأفلام"
        case .series: return "أدوات المسلسلات"
        }
    }

    var icon: String {
        switch self {
        case .live: return "dot.radiowaves.left.and.right"
        case .movies: return "film"
        case .series: return "tv.inset.filled"
        }
    }
}

// MARK: - الأدوات

enum TigerQuickTool: String, Identifiable, CaseIterable {
    case sleep, speed, aspect, subtitle, network, storage, theme, stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "مؤقت النوم"
        case .speed: return "سرعة التشغيل"
        case .aspect: return "نسبة العرض"
        case .subtitle: return "مزامنة الترجمة"
        case .network: return "اختبار الشبكة"
        case .storage: return "تنظيف التخزين"
        case .theme: return "المظهر"
        case .stats: return "بيانات الجهاز"
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "moon.zzz.fill"
        case .speed: return "speedometer"
        case .aspect: return "rectangle.arrowtriangle.2.outward"
        case .subtitle: return "captions.bubble.fill"
        case .network: return "wifi"
        case .storage: return "trash.fill"
        case .theme: return "paintpalette.fill"
        case .stats: return "cpu"
        }
    }

    var tint: Color {
        switch self {
        case .sleep: return Color(red: 0.42, green: 0.62, blue: 1.00)
        case .speed: return TigerTheme.orange
        case .aspect: return Color(red: 0.35, green: 0.82, blue: 0.72)
        case .subtitle: return Color(red: 0.95, green: 0.55, blue: 0.85)
        case .network: return Color(red: 0.40, green: 0.80, blue: 1.00)
        case .storage: return Color(red: 1.00, green: 0.45, blue: 0.40)
        case .theme: return TigerTheme.gold
        case .stats: return Color(red: 0.70, green: 0.72, blue: 0.85)
        }
    }
}

// MARK: - الشريط

struct TigerQuickToolsStrip: View {
    var context: TigerToolContext = .live

    @State private var selected: TigerQuickTool?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TigerTheme.orangeGradient)

                Text(context.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TigerAdaptive.text(scheme))

                Spacer(minLength: 6)

                NavigationLink {
                    FeatureCenterView()
                } label: {
                    HStack(spacing: 4) {
                        Text("المزايا والتفعيلات")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(TigerTheme.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(TigerTheme.orange.opacity(0.14))
                    )
                    .overlay(
                        Capsule().stroke(TigerTheme.orange.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TigerQuickTool.allCases) { tool in
                        Button {
                            selected = tool
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 12, weight: .bold))
                                Text(tool.title)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(TigerAdaptive.text(scheme))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(TigerAdaptive.chipFill(scheme))
                            )
                            .overlay(
                                Capsule().stroke(tool.tint.opacity(scheme == .dark ? 0.35 : 0.55), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .sheet(item: $selected) { tool in
            TigerQuickToolSheet(tool: tool)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - الورقة

private struct TigerQuickToolSheet: View {
    let tool: TigerQuickTool

    var body: some View {
        ZStack {
            TigerTheme.splashGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(tool.tint.opacity(0.25))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.title)
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("أداة سريعة • TIGER IPTV")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }

                    content
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tool {
        case .sleep: SleepTimerToolView()
        case .speed: PlaybackSpeedToolView()
        case .aspect: AspectRatioToolView()
        case .subtitle: SubtitleSyncToolView()
        case .network: NetworkSpeedToolView()
        case .storage: StorageCleanerToolView()
        case .theme: ThemeQuickToolView()
        case .stats: DeviceStatsToolView()
        }
    }
}

// MARK: - أدوات فرعية

private struct ToolCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct SleepTimerToolView: View {
    @ObservedObject private var sleepTimer = TigerSleepTimer.shared
    @State private var now: Date = Date()

    private let presets = [15, 30, 45, 60, 90, 120]
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            ToolCard(
                title: "أوقف التشغيل تلقائياً",
                subtitle: "اختر مدة، وسيتم إيقاف التشغيل عند انتهائها. المؤقت يعمل حتى لو أغلقت هذه الشاشة أو التطبيق."
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                    ForEach(presets, id: \.self) { minutes in
                        Button {
                            sleepTimer.start(minutes: minutes)
                            now = Date()
                        } label: {
                            Text("\(minutes) د")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isActive(minutes) ? .white : .white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isActive(minutes) ? TigerTheme.orange.opacity(0.85) : Color.white.opacity(0.07))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let endsAt = sleepTimer.endsAt {
                ToolCard(title: "الوقت المتبقي", subtitle: "سيتم إيقاف التشغيل تلقائياً عند وصول العدّاد للصفر.") {
                    HStack {
                        Text(remainingText(from: endsAt))
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(TigerTheme.orangeGradient)
                            .monospacedDigit()
                        Spacer()
                        Button("إلغاء") {
                            sleepTimer.cancel()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.4))
                    }
                }
            }
        }
        .onReceive(ticker) { value in
            now = value
        }
    }

    private func isActive(_ minutes: Int) -> Bool {
        sleepTimer.activeMinutes == minutes
    }

    private func remainingText(from date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// مؤقت نوم حقيقي على مستوى التطبيق: يبقى شغّالاً بعد إغلاق الشاشة،
/// ويُرسل `.tigerSleepTimerFired` عند الانتهاء ليوقف المشغّل التشغيل.
@MainActor
final class TigerSleepTimer: ObservableObject {
    static let shared = TigerSleepTimer()

    @Published private(set) var endsAt: Date?
    @Published private(set) var activeMinutes: Int = 0

    private var timer: Timer?
    private let defaults = UserDefaults.standard
    private let endsAtKey = "tiger.sleep.endsAt"
    private let minutesKey = "tiger.sleep.minutes"

    private init() {
        resumeIfNeeded()
    }

    func start(minutes: Int) {
        let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
        endsAt = end
        activeMinutes = minutes
        defaults.set(end.timeIntervalSince1970, forKey: endsAtKey)
        defaults.set(minutes, forKey: minutesKey)
        schedule()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        endsAt = nil
        activeMinutes = 0
        defaults.removeObject(forKey: endsAtKey)
        defaults.set(0, forKey: minutesKey)
    }

    /// يُستدعى عند إقلاع التطبيق لاستعادة المؤقت إن كان ما زال سارياً.
    func resumeIfNeeded() {
        let stamp = defaults.double(forKey: endsAtKey)
        guard stamp > 0 else { return }
        let end = Date(timeIntervalSince1970: stamp)
        if end <= Date() {
            cancel()
            return
        }
        endsAt = end
        activeMinutes = defaults.integer(forKey: minutesKey)
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let end = self.endsAt else { return }
                if Date() >= end {
                    self.cancel()
                    NotificationCenter.default.post(name: .tigerSleepTimerFired, object: nil)
                }
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
}

private struct PlaybackSpeedToolView: View {
    @AppStorage("player.defaultSpeed") private var speed: Double = 1.0

    private let options: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        ToolCard(
            title: "السرعة الافتراضية",
            subtitle: "تُطبّق على كل فيديو جديد. يمكنك تغييرها أثناء التشغيل من أزرار المشغّل."
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { value in
                    Button {
                        speed = value
                    } label: {
                        Text(speedLabel(value))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(abs(speed - value) < 0.001 ? .white : .white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(abs(speed - value) < 0.001 ? TigerTheme.orange.opacity(0.85) : Color.white.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func speedLabel(_ value: Double) -> String {
        value == 1.0 ? "عادي" : String(format: "%.2fx", value)
    }
}

private struct AspectRatioToolView: View {
    @AppStorage("player.aspectMode") private var mode: String = "fit"

    private let options: [(id: String, title: String, icon: String)] = [
        ("fit", "ملائم", "rectangle.arrowtriangle.2.inward"),
        ("fill", "تعبئة", "rectangle.arrowtriangle.2.outward"),
        ("stretch", "تمديد", "arrow.up.left.and.arrow.down.right"),
        ("16:9", "16:9", "rectangle"),
        ("4:3", "4:3", "rectangle.portrait")
    ]

    var body: some View {
        ToolCard(
            title: "نسبة العرض",
            subtitle: "اختر كيف يُعرض الفيديو داخل الشاشة. «ملائم» يحافظ على الأبعاد الأصلية."
        ) {
            VStack(spacing: 8) {
                ForEach(options, id: \.id) { option in
                    Button {
                        mode = option.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: option.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 22)
                            Text(option.title)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            if mode == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TigerTheme.orange)
                            }
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(mode == option.id ? TigerTheme.orange.opacity(0.16) : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SubtitleSyncToolView: View {
    @AppStorage("player.subtitleDelay") private var delay: Double = 0.0

    var body: some View {
        ToolCard(
            title: "تأخير الترجمة",
            subtitle: "حرّك المؤشر لمزامنة الترجمة مع الصوت. القيمة تُطبّق على كل المقاطع."
        ) {
            VStack(spacing: 10) {
                HStack {
                    Text(String(format: "%+.1f ث", delay))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(TigerTheme.orangeGradient)
                        .monospacedDigit()
                    Spacer()
                    Button("تصفير") { delay = 0 }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Slider(value: $delay, in: -5...5, step: 0.1)
                    .tint(TigerTheme.orange)

                HStack {
                    Text("-5 ث")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("+5 ث")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

private struct NetworkSpeedToolView: View {
    @State private var status: String = "جاهز للاختبار"
    @State private var latency: Int?
    @State private var mbps: Double?
    @State private var isRunning = false

    var body: some View {
        ToolCard(
            title: "قياس سرعة الاتصال",
            subtitle: "اختبار سريع لزمن الاستجابة وسرعة التنزيل عبر شبكة Cloudflare."
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    metric(title: "زمن الاستجابة", value: latency.map { "\($0) ms" } ?? "—")
                    metric(title: "التنزيل", value: mbps.map { String(format: "%.1f Mbps", $0) } ?? "—")
                }

                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task { await runTest() }
                } label: {
                    HStack(spacing: 8) {
                        if isRunning {
                            ProgressView().tint(.white)
                        }
                        Text(isRunning ? "جارٍ القياس…" : "ابدأ الاختبار")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(TigerTheme.orangeGradient)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            }
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    @MainActor
    private func runTest() async {
        isRunning = true
        status = "جارٍ قياس زمن الاستجابة…"
        latency = nil
        mbps = nil

        do {
            let start = Date()
            var request = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=1")!)
            request.timeoutInterval = 10
            _ = try await URLSession.shared.data(for: request)
            latency = Int(Date().timeIntervalSince(start) * 1000)

            status = "جارٍ قياس سرعة التنزيل…"
            var bigRequest = URLRequest(url: URL(string: "https://speed.cloudflare.com/__down?bytes=3000000")!)
            bigRequest.timeoutInterval = 25
            let bigStart = Date()
            let (data, _) = try await URLSession.shared.data(for: bigRequest)
            let seconds = max(0.01, Date().timeIntervalSince(bigStart))
            let bits = Double(data.count) * 8
            mbps = bits / seconds / 1_000_000
            status = "تم الاختبار بنجاح."
        } catch {
            status = "تعذّر إكمال الاختبار. تحقّق من الاتصال وحاول مجدداً."
        }

        isRunning = false
    }
}

private struct StorageCleanerToolView: View {
    @State private var cacheSize: String = "—"
    @State private var tempSize: String = "—"
    @State private var cleared = false

    var body: some View {
        ToolCard(
            title: "تنظيف الملفات المؤقتة",
            subtitle: "حذف الكاش والملفات المؤقتة لتحرير مساحة. لن تُحذف بياناتك أو مفضّلاتك."
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    infoTile(title: "الكاش", value: cacheSize)
                    infoTile(title: "الملفات المؤقتة", value: tempSize)
                }

                Button {
                    URLCache.shared.removeAllCachedResponses()
                    clearTempDirectory()
                    refresh()
                    cleared = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text(cleared ? "تم التنظيف ✓" : "نظّف الآن")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(red: 1.0, green: 0.45, blue: 0.40))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { refresh() }
    }

    private func infoTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func refresh() {
        cacheSize = formatted(Int64(URLCache.shared.currentDiskUsage))
        tempSize = formatted(directorySize(FileManager.default.temporaryDirectory))
    }

    private func clearTempDirectory() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        if let items = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for item in items {
                try? fm.removeItem(at: item)
            }
        }
    }

    private func directorySize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func formatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private struct ThemeQuickToolView: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 14) {
            ToolCard(title: "وضع المظهر", subtitle: "اختر بين النظام أو الوضع الداكن أو الفاتح.") {
                HStack(spacing: 8) {
                    ForEach(ThemeManager.Appearance.allCases, id: \.self) { option in
                        Button {
                            theme.appearance = option
                        } label: {
                            Text(option.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.appearance == option ? .white : .white.opacity(0.72))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(theme.appearance == option ? TigerTheme.orange.opacity(0.8) : Color.white.opacity(0.07))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ToolCard(title: "لون التمييز", subtitle: "غيّر لون الأزرار والعناوين في كل التطبيق.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 10)], spacing: 10) {
                    ForEach(ThemeManager.Accent.allCases, id: \.self) { accent in
                        Button {
                            theme.accent = accent
                        } label: {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(theme.accent == accent ? 0.9 : 0.15), lineWidth: theme.accent == accent ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DeviceStatsToolView: View {
    @State private var freeSpace: String = "—"

    var body: some View {
        ToolCard(
            title: "بيانات التطبيق والجهاز",
            subtitle: "معلومات سريعة تساعدك عند التواصل مع الدعم الفني."
        ) {
            VStack(spacing: 0) {
                row("الإصدار", Bundle.main.appVersion)
                divider
                row("رقم البناء", Bundle.main.appBuild)
                divider
                row("الجهاز", TigerPlatform.deviceModel)
                divider
                row("النظام", TigerPlatform.systemDescription)
                divider
                row("المساحة المتاحة", freeSpace)
                divider
                row("اللغة", Locale.current.identifier)
            }
        }
        .onAppear { refreshSpace() }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func refreshSpace() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            freeSpace = formatter.string(fromByteCount: capacity)
        } else {
            freeSpace = "غير متاح"
        }
    }
}

// MARK: - الإشعارات

extension Notification.Name {
    /// يُرسَل عند انتهاء مؤقت النوم حتى يوقف المشغّل التشغيل.
    static let tigerSleepTimerFired = Notification.Name("tiger.sleep.timer.fired")
}

#Preview {
    NavigationStack {
        ScrollView {
            TigerQuickToolsStrip(context: .live)
        }
        .background(TigerTheme.splashGradient)
    }
}
