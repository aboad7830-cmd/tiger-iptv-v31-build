import Foundation

/// بناء روابط إعادة العرض (Catch-up / TV Archive) لخدمة Xtream Codes.
///
/// الصيغة المدعومة على نطاق واسع:
/// `{base}/{user}/{pass}/{streamId}.{ext}?start=YYYY-MM-DD:HH-MM&end=YYYY-MM-DD:HH-MM`
/// وبديل شائع: `&duration=MINUTES`.
struct CatchupURLBuilder {
    let playlist: Playlist

    private var cleanBaseURL: String {
        var base = playlist.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.lowercased().hasPrefix("http://") && !base.lowercased().hasPrefix("https://") {
            base = "http://\(base)"
        }
        if base.hasSuffix("/") { base.removeLast() }
        if base.lowercased().hasSuffix("/player_api.php") {
            base = String(base.dropLast(15))
        } else if base.lowercased().hasSuffix("player_api.php") {
            base = String(base.dropLast(14))
        }
        return base.replacingOccurrences(of: " ", with: "")
    }

    private var authPath: String {
        let u = playlist.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = playlist.password.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(u)/\(p)"
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd:HH-mm"
        return f
    }()

    /// رابط إعادة العرض بين تاريخين.
    func catchupURL(streamId: Int, start: Date, end: Date, containerExtension: String? = nil) -> URL? {
        guard end > start else { return nil }
        let ext = (containerExtension?.isEmpty == false) ? containerExtension! : "ts"
        var components = URLComponents(string: "\(cleanBaseURL)/\(authPath)/\(streamId).\(ext)")
        components?.queryItems = [
            URLQueryItem(name: "start", value: CatchupURLBuilder.stampFormatter.string(from: start)),
            URLQueryItem(name: "end", value: CatchupURLBuilder.stampFormatter.string(from: end))
        ]
        return components?.url
    }

    /// رابط إعادة العرض بمدة بالدقائق (بعض المزوّدين يفضّلونها).
    func catchupURL(streamId: Int, start: Date, minutes: Int, containerExtension: String? = nil) -> URL? {
        guard minutes > 0 else { return nil }
        let ext = (containerExtension?.isEmpty == false) ? containerExtension! : "ts"
        var components = URLComponents(string: "\(cleanBaseURL)/\(authPath)/\(streamId).\(ext)")
        components?.queryItems = [
            URLQueryItem(name: "start", value: CatchupURLBuilder.stampFormatter.string(from: start)),
            URLQueryItem(name: "duration", value: String(minutes))
        ]
        return components?.url
    }

    /// رابط إعادة العرض لبرنامج EPG محدد.
    func catchupURL(streamId: Int, program: EpgProgram, containerExtension: String? = nil) -> URL? {
        catchupURL(streamId: streamId, start: program.start, end: program.end, containerExtension: containerExtension)
    }

    /// أقصى تاريخ متاح للإرجاع (بحسب مدة الأرشيف بالأيام).
    static func earliestAvailable(days: Int, from now: Date = Date()) -> Date {
        now.addingTimeInterval(-Double(max(days, 1)) * 86_400)
    }

    /// هل التاريخ ضمن نطاق الأرشيف؟
    static func isWithinArchive(_ date: Date, days: Int, now: Date = Date()) -> Bool {
        date >= earliestAvailable(days: days, from: now) && date <= now
    }
}
