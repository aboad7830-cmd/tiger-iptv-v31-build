import Foundation
import Combine
import CryptoKit
import GRDB

/// إدارة ملفات المستخدمين: إنشاء/تعديل/حذف + تذكّر الملف النشط.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var isLoading = false
    @Published var activeProfile: Profile?

    private let activeKey = "profiles.active_id"

    private init() {}

    // MARK: - التحميل

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await AppDatabase.shared.read { db in
                try Profile.order(Column("sortIndex"), Column("createdAt")).fetchAll(db)
            }
            profiles = rows
            restoreActive()
        } catch {
            Log.error("Profiles", "load failed: \(error)")
        }
    }

    private func restoreActive() {
        guard let raw = UserDefaults.standard.string(forKey: activeKey),
              let id = UUID(uuidString: raw) else {
            activeProfile = profiles.first
            return
        }
        activeProfile = profiles.first(where: { $0.id == id }) ?? profiles.first
    }

    // MARK: - الكتابة

    @discardableResult
    func create(name: String, avatar: String, isKids: Bool) async -> Profile? {
        let nextIndex = (profiles.map(\.sortIndex).max() ?? 0) + 1
        let profile = Profile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            avatar: avatar,
            isKids: isKids,
            sortIndex: nextIndex
        )
        do {
            try await AppDatabase.shared.write { db in
                try profile.save(db)
            }
            profiles.append(profile)
            profiles.sort { $0.sortIndex < $1.sortIndex }
            if activeProfile == nil { setActive(profile) }
            return profile
        } catch {
            Log.error("Profiles", "create failed: \(error)")
            return nil
        }
    }

    func update(_ profile: Profile) async {
        do {
            try await AppDatabase.shared.write { db in
                try profile.update(db)
            }
            if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[idx] = profile
            }
            if activeProfile?.id == profile.id { activeProfile = profile }
        } catch {
            Log.error("Profiles", "update failed: \(error)")
        }
    }

    func delete(_ profile: Profile) async {
        do {
            try await AppDatabase.shared.write { db in
                _ = try Profile.deleteOne(db, key: profile.id)
            }
            profiles.removeAll { $0.id == profile.id }
            if activeProfile?.id == profile.id {
                activeProfile = profiles.first
                persistActive()
            }
        } catch {
            Log.error("Profiles", "delete failed: \(error)")
        }
    }

    // MARK: - الملف النشط

    func setActive(_ profile: Profile?) {
        activeProfile = profile
        persistActive()
    }

    private func persistActive() {
        if let id = activeProfile?.id {
            UserDefaults.standard.set(id.uuidString, forKey: activeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeKey)
        }
    }

    /// هل التطبيق يجب أن يعرض شاشة اختيار الملف؟
    var needsPicker: Bool { profiles.count > 1 }

    // MARK: - قفل PIN

    static func hash(pin: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// يتحقق من PIN ملف معيّن. يعيد true إذا لم يكن الملف مقفلاً.
    func verify(pin: String, for profile: Profile) -> Bool {
        guard let stored = profile.pinHash else { return true }
        let salt = "profile.\(profile.id.uuidString)"
        return ProfileStore.hash(pin: pin, salt: salt) == stored
    }

    func setPIN(_ pin: String, for profile: Profile) async -> Bool {
        guard pin.count >= 4 else { return false }
        var copy = profile
        let salt = "profile.\(profile.id.uuidString)"
        copy.pinHash = ProfileStore.hash(pin: pin, salt: salt)
        await update(copy)
        return true
    }

    func clearPIN(for profile: Profile) async {
        var copy = profile
        copy.pinHash = nil
        await update(copy)
    }
}
