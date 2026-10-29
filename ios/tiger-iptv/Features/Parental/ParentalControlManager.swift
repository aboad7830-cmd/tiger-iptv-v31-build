import Foundation
import CryptoKit
import Security
import Combine

/// Local parental control: a 4–6 digit PIN, a Kids Mode and an adult-content switch.
///
/// The PIN is never stored in clear text — only a salted SHA-256 digest is kept in
/// `UserDefaults`. This is enough for an on-device parental lock (it is not a
/// cryptographic secret store), and it keeps the feature dependency-free.
@MainActor
final class ParentalControlManager: ObservableObject {
    static let shared = ParentalControlManager()

    private let defaults = UserDefaults.standard
    private let pinHashKey = "parental.pinHash"
    private let saltKey = "parental.salt"
    private let kidsModeKey = "parental.kidsMode"
    private let hideAdultKey = "parental.hideAdult"
    private let lockOnLaunchKey = "parental.lockOnLaunch"

    /// Whether the current session has passed the PIN gate.
    @Published private(set) var isUnlocked: Bool = false

    /// Kids Mode: hides adult categories, disables purchases/imports and locks settings.
    @Published var kidsModeEnabled: Bool {
        didSet {
            defaults.set(kidsModeEnabled, forKey: kidsModeKey)
            if kidsModeEnabled { isUnlocked = false }
        }
    }

    /// Hide adult categories everywhere (independent of Kids Mode).
    @Published var hideAdultContent: Bool {
        didSet { defaults.set(hideAdultContent, forKey: hideAdultKey) }
    }

    /// Ask for the PIN every time the app becomes active.
    @Published var lockOnLaunch: Bool {
        didSet { defaults.set(lockOnLaunch, forKey: lockOnLaunchKey) }
    }

    private init() {
        kidsModeEnabled = defaults.bool(forKey: kidsModeKey)
        hideAdultContent = defaults.bool(forKey: hideAdultKey)
        lockOnLaunch = defaults.bool(forKey: lockOnLaunchKey)
        // If no PIN exists, the session starts unlocked so the app is never bricked.
        isUnlocked = !defaults.bool(forKey: lockOnLaunchKey) || !Self.hasStoredPIN(defaults)
    }

    // MARK: - PIN

    var isPINSet: Bool { Self.hasStoredPIN(defaults) }

    private static func hasStoredPIN(_ defaults: UserDefaults) -> Bool {
        (defaults.string(forKey: "parental.pinHash")?.isEmpty == false)
    }

    /// Stores a new PIN. Throws when the PIN is too short.
    func setPIN(_ pin: String) throws {
        let digits = pin.filter(\.isNumber)
        guard digits.count >= 4 else { throw ParentalError.pinTooShort }

        let salt = Self.randomSalt()
        defaults.set(salt, forKey: saltKey)
        defaults.set(Self.hash(pin: digits, salt: salt), forKey: pinHashKey)
        isUnlocked = true
    }

    func removePIN() {
        defaults.removeObject(forKey: pinHashKey)
        defaults.removeObject(forKey: saltKey)
        isUnlocked = true
    }

    /// Verifies a PIN and unlocks the session on success.
    @discardableResult
    func verify(pin: String) -> Bool {
        guard let salt = defaults.string(forKey: saltKey),
              let stored = defaults.string(forKey: pinHashKey) else {
            return false
        }
        let candidate = Self.hash(pin: pin.filter(\.isNumber), salt: salt)
        let ok = candidate == stored
        if ok { isUnlocked = true }
        return ok
    }

    func lock() {
        isUnlocked = false
    }

    /// Called from the app lifecycle when it becomes active.
    func handleBecameActive() {
        if lockOnLaunch || kidsModeEnabled {
            isUnlocked = false
        }
    }

    // MARK: - Helpers

    private static func randomSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    private static func hash(pin: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + pin).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum ParentalError: LocalizedError {
    case pinTooShort

    var errorDescription: String? {
        switch self {
        case .pinTooShort:
            return L("parental.error.pin_too_short")
        }
    }
}
