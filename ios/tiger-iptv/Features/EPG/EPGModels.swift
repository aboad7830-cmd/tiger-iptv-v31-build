import Foundation
import GRDB

// MARK: - Models

struct EpgChannel: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable {
    var playlistId: String
    var channelId: String
    var displayName: String
    var iconURL: String?

    var id: String { "\(playlistId)|\(channelId)" }

    static let databaseTableName = "epgChannel"
}

struct EpgProgram: Identifiable, Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: String
    var playlistId: String
    var channelId: String
    var title: String
    var subtitle: String?
    var desc: String?
    var category: String?
    var start: Date
    var end: Date
    var iconURL: String?
    var episodeNum: String?

    static let databaseTableName = "epgProgram"

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    func progress(at date: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) / duration))
    }

    func isLive(at date: Date = Date()) -> Bool {
        date >= start && date < end
    }
}

// MARK: - XMLTV parser

/// Streaming XMLTV parser. Handles the subset of XMLTV that IPTV providers actually emit.
final class EPGXMLTVParser: NSObject, XMLParserDelegate {

    struct Output {
        var channels: [EpgChannel] = []
        var programs: [EpgProgram] = []
    }

    private let playlistId: String
    private var output = Output()

    // Current element state
    private var currentChannelId: String?
    private var currentChannelName: String?
    private var currentChannelIcon: String?

    private var currentProgram: EpgProgram?
    private var currentText = ""
    private var inProgramme = false

    init(playlistId: String) {
        self.playlistId = playlistId
    }

    static func parse(data: Data, playlistId: String) -> Output {
        let parser = EPGXMLTVParser(playlistId: playlistId)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.shouldProcessNamespaces = false
        xml.parse()
        return parser.output
    }

    // MARK: XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""

        switch elementName {
        case "channel":
            currentChannelId = attributeDict["id"]
            currentChannelName = nil
            currentChannelIcon = nil

        case "programme":
            inProgramme = true
            guard let channelId = attributeDict["channel"],
                  let start = Self.parseDate(attributeDict["start"]) else {
                currentProgram = nil
                return
            }
            let stop = Self.parseDate(attributeDict["stop"])
            currentProgram = EpgProgram(
                id: UUID().uuidString,
                playlistId: playlistId,
                channelId: channelId,
                title: "",
                subtitle: nil,
                desc: nil,
                category: nil,
                start: start,
                end: stop ?? start.addingTimeInterval(3600),
                iconURL: nil,
                episodeNum: nil
            )

        case "icon":
            if let src = attributeDict["src"], !src.isEmpty {
                if inProgramme {
                    currentProgram?.iconURL = src
                } else {
                    currentChannelIcon = src
                }
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "display-name":
            if currentChannelId != nil, currentChannelName == nil, !text.isEmpty {
                currentChannelName = text
            }

        case "title":
            if inProgramme, currentProgram?.title.isEmpty == true, !text.isEmpty {
                currentProgram?.title = text
            }

        case "sub-title":
            if inProgramme, !text.isEmpty { currentProgram?.subtitle = text }

        case "desc":
            if inProgramme, !text.isEmpty { currentProgram?.desc = text }

        case "category":
            if inProgramme, !text.isEmpty, currentProgram?.category == nil {
                currentProgram?.category = text
            }

        case "episode-num":
            if inProgramme, !text.isEmpty { currentProgram?.episodeNum = text }

        case "channel":
            if let id = currentChannelId {
                output.channels.append(
                    EpgChannel(
                        playlistId: playlistId,
                        channelId: id,
                        displayName: currentChannelName ?? id,
                        iconURL: currentChannelIcon
                    )
                )
            }
            currentChannelId = nil
            currentChannelName = nil
            currentChannelIcon = nil

        case "programme":
            if let program = currentProgram, !program.title.isEmpty {
                output.programs.append(program)
            }
            currentProgram = nil
            inProgramme = false

        default:
            break
        }

        currentText = ""
    }

    // MARK: Date parsing

    /// XMLTV dates look like `20240101123000 +0000` or `20240101123000`.
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        let formats = [
            "yyyyMMddHHmmss Z",
            "yyyyMMddHHmmss",
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        // Fallback: strip a trailing timezone and retry the basic format.
        if let space = trimmed.lastIndex(of: " ") {
            return parseDate(String(trimmed[..<space]))
        }
        return nil
    }
}
