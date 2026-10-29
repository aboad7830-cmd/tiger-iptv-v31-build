//
//  BrandIdentity100.swift
//  Tiger IPTV
//
//  الهوية البصرية والتسويق (96–100)
//

import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
import Combine
#endif

// MARK: - 96) أيقونات تطبيق بديلة

struct TigerAlternateIcon: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let tint: Color

    static let all: [TigerAlternateIcon] = [
        TigerAlternateIcon(id: "AppIcon", name: L("icon.default"), symbol: "tiger.head", tint: TigerTheme.brand),
        TigerAlternateIcon(id: "AppIconGold", name: L("icon.gold"), symbol: "crown.fill", tint: TigerTheme.gold),
        TigerAlternateIcon(id: "AppIconDark", name: L("icon.dark"), symbol: "moon.stars.fill", tint: Color(white: 0.2)),
        TigerAlternateIcon(id: "AppIconLight", name: L("icon.light"), symbol: "sun.max.fill", tint: Color(white: 0.95))
    ]
}

@MainActor
final class TigerAppIconPicker: ObservableObject {
    static let shared = TigerAppIconPicker()

    @Published private(set) var currentIconName: String?
    @Published private(set) var isSupported = false
    @Published private(set) var lastError: String?

    private init() {
        #if os(iOS)
        let app = UIApplication.shared
        isSupported = app.supportsAlternateIcons
        currentIconName = app.alternateIconName
        #endif
    }

    func setIcon(_ icon: TigerAlternateIcon) {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            lastError = L("icon.unsupported")
            return
        }
        let target: String? = icon.id == "AppIcon" ? nil : icon.id
        guard target != UIApplication.shared.alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(target) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    ToastCenter.shared.show(L("icon.failed"), style: .error)
                } else {
                    self.currentIconName = target
                    HapticEngine.success()
                    ToastCenter.shared.show(L("icon.changed"), style: .success)
                }
            }
        }
        #else
        lastError = L("icon.unsupported")
        #endif
    }
}

struct TigerAppIconPickerView: View {
    @ObservedObject private var picker = TigerAppIconPicker.shared

    var body: some View {
        List {
            Section {
                ForEach(TigerAlternateIcon.all) { icon in
                    Button {
                        picker.setIcon(icon)
                    } label: {
                        HStack(spacing: Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: [icon.tint, icon.tint.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 52, height: 52)
                                Image(systemName: icon.symbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(icon.name).foregroundStyle(.primary)
                            Spacer()
                            if isSelected(icon) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(TigerTheme.gold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(L("icon.title"))
            } footer: {
                if let error = picker.lastError {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text(L("icon.footer"))
                }
            }
        }
        .navigationTitle(L("icon.title"))
    }

    private func isSelected(_ icon: TigerAlternateIcon) -> Bool {
        let current = picker.currentIconName ?? "AppIcon"
        return current == icon.id
    }
}

// MARK: - 97) بطاقة مشاركة مصمّمة

struct TigerShareCard: View {
    let title: String
    let subtitle: String?
    let imageURL: String?
    let badge: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL {
                CachedImage(url: URL(string: imageURL), width: 600, height: 800, cornerRadius: 0, contentMode: .fill)
            } else {
                TigerTheme.splashGradient
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TigerTheme.gold, in: Capsule())
                        .foregroundStyle(.black)
                }
                Text(title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Image(systemName: "tiger.head.fill")
                    Text("Tiger IPTV")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 4)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 600, height: 800)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }
}

@MainActor
enum TigerShareCardRenderer {
    static func render(title: String, subtitle: String?, imageURL: String?, badge: String?) -> UIImage? {
        #if canImport(UIKit)
        let card = TigerShareCard(title: title, subtitle: subtitle, imageURL: imageURL, badge: badge)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        return renderer.uiImage
        #else
        return nil
        #endif
    }

    static func share(title: String, subtitle: String?, imageURL: String?, badge: String?) -> UIImage? {
        render(title: title, subtitle: subtitle, imageURL: imageURL, badge: badge)
    }
}

struct TigerShareCardPreview: View {
    let title: String
    let subtitle: String?
    let imageURL: String?
    let badge: String?

    @State private var rendered: UIImage?
    @State private var showingShare = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            TigerShareCard(title: title, subtitle: subtitle, imageURL: imageURL, badge: badge)
                .scaleEffect(0.5)
                .frame(width: 300, height: 400)

            Button {
                rendered = TigerShareCardRenderer.render(title: title, subtitle: subtitle, imageURL: imageURL, badge: badge)
                showingShare = rendered != nil
            } label: {
                Label(L("share.create"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(TigerPrimaryButtonStyle())
        }
        .padding(Spacing.md)
        #if canImport(UIKit)
        .sheet(isPresented: $showingShare) {
            if let rendered {
                TigerActivityView(items: [rendered])
            }
        }
        #endif
    }
}

#if canImport(UIKit)
struct TigerActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - 98) استوديو لقطات App Store

struct TigerScreenshotScene: Identifiable, Hashable {
    let id: String
    let headline: String
    let subheadline: String
    let symbol: String
    let tint: Color

    static let all: [TigerScreenshotScene] = [
        TigerScreenshotScene(id: "live", headline: L("shot.live.head"), subheadline: L("shot.live.sub"), symbol: "tv.fill", tint: TigerTheme.brand),
        TigerScreenshotScene(id: "movies", headline: L("shot.movies.head"), subheadline: L("shot.movies.sub"), symbol: "film.fill", tint: Color(red: 0.16, green: 0.24, blue: 0.45)),
        TigerScreenshotScene(id: "guide", headline: L("shot.guide.head"), subheadline: L("shot.guide.sub"), symbol: "calendar", tint: Color(red: 0.35, green: 0.18, blue: 0.42)),
        TigerScreenshotScene(id: "downloads", headline: L("shot.dl.head"), subheadline: L("shot.dl.sub"), symbol: "arrow.down.circle.fill", tint: Color(red: 0.12, green: 0.35, blue: 0.30))
    ]
}

struct TigerScreenshotSlide: View {
    let scene: TigerScreenshotScene
    let size: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [scene.tint.opacity(0.95), scene.tint.opacity(0.55), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 18) {
                Image(systemName: scene.symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 60)
                Text(scene.headline)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(scene.subheadline)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: size.height * 0.42)
                    .overlay(
                        VStack(spacing: 10) {
                            ForEach(0 ..< 3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.18))
                                    .frame(height: 54)
                                    .padding(.horizontal, 18)
                                    .opacity(1 - Double(index) * 0.2)
                            }
                        }
                    )
                    .padding(.horizontal, 26)
                    .padding(.bottom, 40)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

@MainActor
enum TigerScreenshotStudio {
    static let sizes: [(name: String, size: CGSize)] = [
        ("iPhone 6.9\"", CGSize(width: 1320, height: 2868)),
        ("iPhone 6.5\"", CGSize(width: 1242, height: 2688)),
        ("iPad 13\"", CGSize(width: 2064, height: 2752))
    ]

    static func render(scene: TigerScreenshotScene, size: CGSize) -> UIImage? {
        #if canImport(UIKit)
        let renderer = ImageRenderer(content: TigerScreenshotSlide(scene: scene, size: size))
        renderer.scale = 1
        return renderer.uiImage
        #else
        return nil
        #endif
    }
}

struct TigerScreenshotStudioView: View {
    @State private var renderedCount = 0
    @State private var isWorking = false

    var body: some View {
        List {
            Section {
                ForEach(TigerScreenshotScene.all) { scene in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: scene.symbol)
                            .foregroundStyle(scene.tint)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scene.headline).font(.body.weight(.semibold))
                            Text(scene.subheadline).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(L("shot.scenes"))
            }

            Section {
                ForEach(TigerScreenshotStudio.sizes, id: \.name) { item in
                    LabeledContent(item.name, value: "\(Int(item.size.width))×\(Int(item.size.height))")
                }
                Button {
                    generate()
                } label: {
                    HStack {
                        Label(L("shot.generate"), systemImage: "camera.viewfinder")
                        Spacer()
                        if isWorking { ProgressView() }
                    }
                }
                .disabled(isWorking)
                if renderedCount > 0 {
                    Text(String(format: L("shot.done"), renderedCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L("shot.sizes"))
            } footer: {
                Text(L("shot.footer"))
            }
        }
        .navigationTitle(L("shot.title"))
    }

    private func generate() {
        isWorking = true
        var count = 0
        for scene in TigerScreenshotScene.all {
            for item in TigerScreenshotStudio.sizes {
                if TigerScreenshotStudio.render(scene: scene, size: item.size) != nil { count += 1 }
            }
        }
        renderedCount = count
        isWorking = false
        HapticEngine.success()
    }
}

// MARK: - 99) شاشة "ما الجديد"

struct TigerWhatsNewItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

@MainActor
final class TigerWhatsNewStore: ObservableObject {
    static let shared = TigerWhatsNewStore()

    @Published private(set) var lastSeenVersion: String

    private let defaults = UserDefaults.standard
    private let key = "whatsnew.lastSeen"

    private init() {
        lastSeenVersion = defaults.string(forKey: key) ?? ""
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.3.0"
    }

    var shouldPresent: Bool { lastSeenVersion != currentVersion }

    func markSeen() {
        lastSeenVersion = currentVersion
        defaults.set(currentVersion, forKey: key)
    }
}

struct TigerWhatsNewView: View {
    let items: [TigerWhatsNewItem]
    var onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(TigerTheme.goldGradient)
                Text(L("whatsnew.title"))
                    .font(.largeTitle.weight(.heavy))
                Text(String(format: L("whatsnew.version"), TigerWhatsNewStore.shared.currentVersion))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xl)

            ScrollView {
                VStack(spacing: Spacing.md) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: Spacing.md) {
                            Image(systemName: item.symbol)
                                .font(.title3)
                                .foregroundStyle(TigerTheme.gold)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(Spacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(TigerMotion.gentle.delay(Double(index) * 0.05), value: appeared)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }

            Button(L("common.continue")) {
                TigerWhatsNewStore.shared.markSeen()
                onClose()
            }
            .buttonStyle(TigerPrimaryButtonStyle())
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - 100) ترحيب سينمائي عند أول تشغيل

struct TigerCinematicWelcomeView: View {
    var onFinish: () -> Void

    @State private var stage = 0
    @State private var glow = false

    private let lines: [(String, String)] = [
        ("tv.and.mediabox.fill", L("welcome.line1")),
        ("sparkles.tv.fill", L("welcome.line2")),
        ("bolt.horizontal.circle.fill", L("welcome.line3"))
    ]

    var body: some View {
        ZStack {
            TigerTheme.splashGradient.ignoresSafeArea()

            RadialGradient(
                colors: [TigerTheme.gold.opacity(glow ? 0.35 : 0.12), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glow)

            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: "tiger.head.fill")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(TigerTheme.goldGradient)
                    .scaleEffect(glow ? 1.04 : 0.98)
                    .shadow(color: TigerTheme.gold.opacity(0.5), radius: 30)

                Text("TIGER IPTV")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)

                VStack(spacing: Spacing.md) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: line.0)
                                .foregroundStyle(TigerTheme.gold)
                            Text(line.1)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .opacity(stage > index ? 1 : 0)
                        .offset(y: stage > index ? 0 : 10)
                        .animation(TigerMotion.gentle, value: stage)
                    }
                }
                .padding(.top, Spacing.md)

                Spacer()

                Button(L("welcome.start")) {
                    onFinish()
                }
                .buttonStyle(TigerPrimaryButtonStyle())
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
                .opacity(stage >= lines.count ? 1 : 0)
                .animation(TigerMotion.gentle, value: stage)
            }
        }
        .onAppear {
            glow = true
            Task {
                for index in 0 ..< lines.count {
                    try? await Task.sleep(nanoseconds: 550_000_000)
                    await MainActor.run { stage = index + 1 }
                }
            }
        }
    }
}

// MARK: - لوحة الهوية

struct TigerBrandStudioView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    TigerAppIconPickerView()
                } label: {
                    Label(L("icon.title"), systemImage: "app.badge")
                }
                NavigationLink {
                    TigerScreenshotStudioView()
                } label: {
                    Label(L("shot.title"), systemImage: "camera.viewfinder")
                }
                NavigationLink {
                    TigerShareCardPreview(
                        title: L("share.sample.title"),
                        subtitle: L("share.sample.subtitle"),
                        imageURL: nil,
                        badge: L("badge.live")
                    )
                } label: {
                    Label(L("share.title"), systemImage: "square.and.arrow.up")
                }
            } header: {
                Text(L("brand.title"))
            } footer: {
                Text(L("brand.footer"))
            }
        }
        .navigationTitle(L("brand.title"))
    }
}
