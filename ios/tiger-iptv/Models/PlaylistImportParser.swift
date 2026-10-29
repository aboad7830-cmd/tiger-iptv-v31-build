import Foundation

/// Parses the many shapes a customer might paste into the "add subscription" screen
/// and turns them into structured Xtream credentials.
///
/// Supported inputs:
/// - `http://host:port/get.php?username=U&password=P&type=m3u_plus`
/// - `http://host:port/player_api.php?username=U&password=P`
/// - `http://host:port/xmltv.php?username=U&password=P`
/// - `host:port` + `username` + `password` on separate lines
/// - `host:port username password` on one line
/// - `username:password@host:port`
/// - bare `host` or `host:port`
struct PlaylistImportParser {

    struct Result: Equatable {
        var serverURL: String
        var username: String
        var password: String
        var suggestedName: String?
        var isM3ULink: Bool = false
    }

    /// Attempts to extract credentials from arbitrary pasted text.
    /// Returns `nil` when nothing usable was found.
    static func parse(_ raw: String) -> Result? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // 1) Full URL with query items (get.php / player_api.php / xmltv.php)
        if let urlResult = parseURL(text) {
            return urlResult
        }

        // 2) user:pass@host:port
        if let atResult = parseUserInfoStyle(text) {
            return atResult
        }

        // 3) Tokenised text: host[:port] [user] [pass]
        let tokens = text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "|" })
            .map(String.init)
            .filter { !$0.isEmpty }

        if tokens.count >= 3 {
            let host = tokens[0]
            let user = tokens[1]
            let pass = tokens[2]
            if looksLikeHost(host), !user.isEmpty, !pass.isEmpty {
                return Result(
                    serverURL: normalizeServer(host),
                    username: user,
                    password: pass,
                    suggestedName: hostName(from: host)
                )
            }
        }

        // 4) Just a host — useful while typing.
        if tokens.count == 1, looksLikeHost(tokens[0]) {
            return Result(
                serverURL: normalizeServer(tokens[0]),
                username: "",
                password: "",
                suggestedName: hostName(from: tokens[0])
            )
        }

        return nil
    }

    /// True when the text is an M3U/M3U8 playlist URL (handled by `AddM3UPlaylistView`).
    static func isM3ULink(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return false }
        return lower.contains(".m3u8") || lower.contains(".m3u") || lower.contains("type=m3u")
    }

    // MARK: - URL parsing

    private static func parseURL(_ text: String) -> Result? {
        var candidate = text
        if !candidate.lowercased().hasPrefix("http://") && !candidate.lowercased().hasPrefix("https://") {
            candidate = "http://" + candidate
        }
        guard let components = URLComponents(string: candidate),
              let host = components.host, !host.isEmpty else { return nil }

        let queryItems = components.queryItems ?? []
        func value(_ names: [String]) -> String? {
            for name in names {
                if let item = queryItems.first(where: { $0.name.lowercased() == name }),
                   let v = item.value, !v.isEmpty {
                    return v
                }
            }
            return nil
        }

        let user = value(["username", "user", "login"])
        let pass = value(["password", "pass", "pwd"])

        // Build a clean base URL: scheme://host[:port]
        var base = "\(components.scheme ?? "http")://\(host)"
        if let port = components.port { base += ":\(port)" }

        let m3u = isM3ULink(text)

        if let user, let pass {
            return Result(
                serverURL: base,
                username: user,
                password: pass,
                suggestedName: host,
                isM3ULink: m3u
            )
        }

        // No credentials in the URL — only useful if it looks like a server root.
        if components.path.isEmpty || components.path == "/" {
            return Result(serverURL: base, username: "", password: "", suggestedName: host)
        }
        return nil
    }

    // MARK: - user:pass@host:port

    private static func parseUserInfoStyle(_ text: String) -> Result? {
        guard text.contains("@") else { return nil }
        let parts = text.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        let credentials = parts[0].split(separator: ":", maxSplits: 1).map(String.init)
        guard credentials.count == 2 else { return nil }

        var hostPart = parts[1]
        if hostPart.lowercased().hasPrefix("http://") { hostPart = String(hostPart.dropFirst(7)) }
        if hostPart.lowercased().hasPrefix("https://") { hostPart = String(hostPart.dropFirst(8)) }
        hostPart = hostPart.split(separator: "/").first.map(String.init) ?? hostPart

        guard looksLikeHost(hostPart) else { return nil }
        return Result(
            serverURL: normalizeServer(hostPart),
            username: credentials[0],
            password: credentials[1],
            suggestedName: hostName(from: hostPart)
        )
    }

    // MARK: - Helpers

    static func looksLikeHost(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return false }
        // host.tld or host:port or IP
        let withoutScheme = trimmed
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        let hostOnly = withoutScheme.split(separator: ":").first.map(String.init) ?? withoutScheme
        if hostOnly.isEmpty { return false }
        if hostOnly.contains(".") { return true }
        // localhost or bare IP-ish
        return hostOnly == "localhost" || hostOnly.allSatisfy { $0.isNumber || $0 == "." }
    }

    /// Ensures a scheme is present and trailing slashes are removed.
    static func normalizeServer(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        v = v.replacingOccurrences(of: " ", with: "")
        if !v.lowercased().hasPrefix("http://") && !v.lowercased().hasPrefix("https://") {
            v = "http://" + v
        }
        while v.hasSuffix("/") { v.removeLast() }
        return v
    }

    private static func hostName(from value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        let host = cleaned.split(separator: ":").first.map(String.init) ?? cleaned
        // "iptv.example.com" → "iptv"
        return host.split(separator: ".").first.map(String.init) ?? host
    }
}
