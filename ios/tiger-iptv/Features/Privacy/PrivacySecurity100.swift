//
//  PrivacySecurity100.swift
//  Tiger IPTV
//
//  الخصوصية والأمان (41–45)
//

import SwiftUI
import GRDB
import Foundation
import Security
import LocalAuthentication

#if canImport(UIKit)
import UIKit
import Combine
#endif

// MARK: - 43) مخزن Keychain لبيانات الاعتماد

enum TigerKeychain {
    private static let service = "com.tigeriptv.app.credentials"

    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func credentialKey(playlistId: UUID) -> String {
        "playlist.\(playlistId.uuidString)"
    }

    /// يخزّن اسم المستخدم وكلمة المرور معًا بشكل مشفّر.
    static func saveCredentials(playlistId: UUID, username: String, password: String) {
        save("\(username)\u{1F}\(password)", for: credentialKey(playlistId: playlistId))
    }

    static func loadCredentials(playlistId: UUID) -> (username: String, password: String)? {
        guard let raw = read(credentialKey(playlistId: playlistId)) else { return nil }
        let parts = raw.components(separatedBy: "\u{1F}")
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}

// MARK: - 41) قفل التطبيق بـ Face ID / Touch ID

@MainActor
final class TigerAppLock: ObservableObject {
    static let shared = TigerAppLock()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            if !isEnabled { isUnlocked = true }
        }
    }
    @Published private(set) var isUnlocked = false
    @Published private(set) var biometricName: String = "Face ID"
    @Published private(set) var lastError: String?

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled = "privacy.appLock"
        static let lockOnBackground = "privacy.lockOnBackground"
    }

    @Published var lockOnBackground: Bool {
        didSet { defaults.set(lockOnBackground, forKey: Keys.lockOnBackground) }
    }

    private init() {
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? false
        lockOnBackground = defaults.object(forKey: Keys.lockOnBackground) as? Bool ?? true
        isUnlocked = !isEnabled
        refreshBiometricName()
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func refreshBiometricName() {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: biometricName = "Face ID"
        case .touchID: biometricName = "Touch ID"
        case .opticID: biometricName = "Optic ID"
        default: biometricName = L("privacy.passcode")
        }
    }

    func unlock() async {
        guard isEnabled else {
            isUnlocked = true
            return
        }
        let context = LAContext()
        context.localizedCancelTitle = L("common.cancel")
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L("privacy.lock.reason")
            )
            isUnlocked = ok
            lastError = ok ? nil : L("privacy.lock.failed")
            if ok { HapticEngine.success() }
        } catch {
            lastError = error.localizedDescription
            isUnlocked = false
        }
    }

    func lockIfNeeded() {
        guard isEnabled, lockOnBackground else { return }
        isUnlocked = false
    }
}

struct TigerLockScreenView: View {
    @ObservedObject private var lock = TigerAppLock.shared
    @State private var appeared = false

    var body: some View {
        ZStack {
            TigerTheme.splashGradient.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(TigerTheme.goldGradient)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                Text(L("privacy.locked.title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(String(format: L("privacy.locked.message"), lock.biometricName))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label(String(format: L("privacy.unlock.with"), lock.biometricName), systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(TigerPrimaryButtonStyle())

                if let error = lock.lastError {
                    Text(error).font(.caption).foregroundStyle(.red.opacity(0.9))
                }
            }
        }
        .onAppear {
            withAnimation(TigerMotion.gentle) { appeared = true }
            Task { await lock.unlock() }
        }
    }
}

// MARK: - 42) تعتيم شاشة تبديل التطبيقات

#if canImport(UIKit)
struct TigerPrivacyShieldView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// يضيف طبقة تعتيم عند مغادرة التطبيق حتى لا تظهر المحتويات في مبدّل التطبيقات.
struct TigerAppSwitcherBlur: ViewModifier {
    @State private var obscured = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if obscured {
                    ZStack {
                        TigerTheme.splashGradient.ignoresSafeArea()
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(L("privacy.blur.title"))
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .transition(.opacity)
                }
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                withAnimation(.easeOut(duration: 0.12)) { obscured = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                withAnimation(.easeIn(duration: 0.18)) { obscured = false }
            }
            #endif
    }
}
#endif

extension View {
    @ViewBuilder
    func tigerAppSwitcherBlur() -> some View {
        #if canImport(UIKit)
        modifier(TigerAppSwitcherBlur())
        #else
        self
        #endif
    }
}

// MARK: - 44) مسح الخصوصية بلمسة واحدة

@MainActor
final class TigerPrivacyWipe: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var lastReport: [String] = []

    struct Options: OptionSet {
        let rawValue: Int
        static let history = Options(rawValue: 1 << 0)
        static let favorites = Options(rawValue: 1 << 1)
        static let credentials = Options(rawValue: 1 << 2)
        static let downloads = Options(rawValue: 1 << 3)
        static let caches = Options(rawValue: 1 << 4)
        static let all: Options = [.history, .favorites, .credentials, .downloads, .caches]
    }

    func wipe(_ options: Options) async {
        isWorking = true
        var report: [String] = []

        if options.contains(.history) {
            _ = try? await AppDatabase.shared.write { db in
                try DBWatchHistory.deleteAll(db)
            }
            report.append(L("wipe.history"))
        }

        if options.contains(.favorites) {
            UserDefaults.standard.removeObject(forKey: "watchlist.items")
            UserDefaults.standard.removeObject(forKey: "m3u.favorites")
            report.append(L("wipe.favorites"))
        }

        if options.contains(.credentials) {
            TigerKeychain.deleteAll()
            report.append(L("wipe.credentials"))
        }

        if options.contains(.downloads) {
            if let root = try? DownloadStorage.rootDirectory() {
                try? FileManager.default.removeItem(at: root)
            }
            report.append(L("wipe.downloads"))
        }

        if options.contains(.caches) {
            URLCache.shared.removeAllCachedResponses()
            if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let contents = (try? FileManager.default.contentsOfDirectory(at: caches, includingPropertiesForKeys: nil)) ?? []
                for url in contents { try? FileManager.default.removeItem(at: url) }
            }
            report.append(L("wipe.caches"))
        }

        lastReport = report
        isWorking = false
        HapticEngine.success()
        ToastCenter.shared.show(L("wipe.done"), style: .success)
    }
}

struct TigerPrivacyWipeView: View {
    @ObservedObject private var wipe = TigerPrivacyWipe()
    @State private var selection: TigerPrivacyWipe.Options = .all
    @State private var confirming = false

    var body: some View {
        List {
            Section {
                toggleRow(L("wipe.history"), option: .history)
                toggleRow(L("wipe.favorites"), option: .favorites)
                toggleRow(L("wipe.credentials"), option: .credentials)
                toggleRow(L("wipe.downloads"), option: .downloads)
                toggleRow(L("wipe.caches"), option: .caches)
            } header: {
                Text(L("wipe.section"))
            } footer: {
                Text(L("wipe.footer"))
            }

            Section {
                Button(role: .destructive) {
                    confirming = true
                } label: {
                    HStack {
                        Label(L("wipe.action"), systemImage: "trash.slash")
                        Spacer()
                        if wipe.isWorking { ProgressView() }
                    }
                }
                .disabled(wipe.isWorking || selection.isEmpty)
            }
        }
        .navigationTitle(L("wipe.title"))
        .confirmationDialog(L("wipe.confirm"), isPresented: $confirming, titleVisibility: .visible) {
            Button(L("wipe.action"), role: .destructive) {
                Task { await wipe.wipe(selection) }
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("wipe.confirm.message"))
        }
    }

    private func toggleRow(_ title: String, option: TigerPrivacyWipe.Options) -> some View {
        Toggle(title, isOn: Binding(
            get: { selection.contains(option) },
            set: { value in
                if value { selection.insert(option) } else { selection.remove(option) }
            }
        ))
    }
}

// MARK: - 45) التحليلات (اشتراك اختياري)

@MainActor
final class TigerAnalytics: ObservableObject {
    static let shared = TigerAnalytics()

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: "privacy.analytics") }
    }
    @Published var crashReports: Bool {
        didSet { defaults.set(crashReports, forKey: "privacy.crashReports") }
    }

    private let defaults = UserDefaults.standard
    private var queue: [[String: String]] = []

    private init() {
        isEnabled = defaults.object(forKey: "privacy.analytics") as? Bool ?? false
        crashReports = defaults.object(forKey: "privacy.crashReports") as? Bool ?? true
    }

    /// يسجّل حدثًا محليًا فقط، ولا يرسل شيئًا إن كان معطّلًا.
    func track(_ event: String, properties: [String: String] = [:]) {
        guard isEnabled else { return }
        var payload = properties
        payload["event"] = event
        payload["at"] = ISO8601DateFormatter().string(from: Date())
        queue.append(payload)
        if queue.count > 200 { queue.removeFirst(queue.count - 200) }
    }

    func exportLocalLog() -> String {
        queue.map { entry in
            entry.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " | ")
        }.joined(separator: "\n")
    }

    func clear() {
        queue.removeAll()
    }
}

// MARK: - لوحة الخصوصية

struct TigerPrivacySettingsView: View {
    @ObservedObject private var lock = TigerAppLock.shared
    @ObservedObject private var analytics = TigerAnalytics.shared

    var body: some View {
        List {
            Section {
                Toggle(L("privacy.appLock"), isOn: $lock.isEnabled)
                if lock.isEnabled {
                    Toggle(L("privacy.lockBackground"), isOn: $lock.lockOnBackground)
                    LabeledContent(L("privacy.biometric"), value: lock.biometricName)
                }
            } header: {
                Text(L("privacy.lock.section"))
            } footer: {
                Text(L("privacy.lock.footer"))
            }

            Section {
                NavigationLink {
                    TigerPrivacyWipeView()
                } label: {
                    Label(L("wipe.title"), systemImage: "trash.slash")
                }
                NavigationLink {
                    TigerCloudSyncSettingsView()
                } label: {
                    Label(L("sync.title"), systemImage: "icloud")
                }
            } header: {
                Text(L("privacy.data.section"))
            }

            Section {
                Toggle(L("privacy.analytics"), isOn: $analytics.isEnabled)
                Toggle(L("privacy.crash"), isOn: $analytics.crashReports)
            } header: {
                Text(L("privacy.analytics.section"))
            } footer: {
                Text(L("privacy.analytics.footer"))
            }
        }
        .navigationTitle(L("privacy.title"))
        .onAppear { lock.refreshBiometricName() }
    }
}
