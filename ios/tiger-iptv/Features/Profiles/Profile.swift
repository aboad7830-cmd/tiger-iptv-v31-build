import Foundation
import GRDB

/// ملف مستخدم داخل التطبيق (مثل Netflix): اسم + صورة رمزية + وضع أطفال + قفل PIN.
/// الجدول `profile` يُنشأ في `TigerMigrations.v2_addProfiles`.
struct Profile: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: UUID
    var name: String
    /// اسم رمز من SF Symbols أو إيموجي — يُستخدم كصورة رمزية.
    var avatar: String
    var isKids: Bool
    /// بصمة PIN (SHA-256 hex) لقفل الملف، أو nil إذا لم يكن مقفلاً.
    var pinHash: String?
    var sortIndex: Int
    var createdAt: Date

    static let databaseTableName = "profile"

    init(
        id: UUID = UUID(),
        name: String,
        avatar: String = "person.crop.circle.fill",
        isKids: Bool = false,
        pinHash: String? = nil,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.isKids = isKids
        self.pinHash = pinHash
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

extension Profile {
    /// الصورة الرمزية الافتراضية حسب نوع الملف.
    static var defaultAvatar: String { "person.crop.circle.fill" }
    static var kidsAvatar: String { "teddybear.fill" }

    /// الأفاتارز المتاحة في شاشة التحرير.
    static let avatarChoices: [String] = [
        "person.crop.circle.fill",
        "person.2.circle.fill",
        "teddybear.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "gamecontroller.fill",
        "film.circle.fill",
        "tv.circle.fill",
        "music.note.list",
        "pawprint.circle.fill"
    ]
}
