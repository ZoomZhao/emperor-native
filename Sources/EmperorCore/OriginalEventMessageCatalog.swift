import CoreFoundation
import Foundation

/// Authored phrases loaded by the original game from
/// `Model/EmperorEventmsg.txt`.
public struct OriginalEventMessageCatalog: Sendable, Equatable {
    public struct BuildingFailureMessage: Sendable, Equatable {
        public let title: String
        public let body: String
    }

    private let phrases: [String: String]

    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let gb18030 = CFStringEncoding(0x0632)
        let encoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(gb18030)
        )
        guard let text = String(data: data, encoding: encoding) else {
            throw GameDataError.malformedFile("Emperor event-message encoding")
        }
        self.init(text: text)
    }

    public init(text: String) {
        var parsed: [String: String] = [:]
        for rawLine in text.components(separatedBy: CharacterSet.newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  !line.hasPrefix(";"),
                  !line.hasPrefix("//"),
                  let firstQuote = line.firstIndex(of: "\""),
                  let lastQuote = line.lastIndex(of: "\""),
                  firstQuote < lastQuote else { continue }
            let key = line[..<firstQuote].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            parsed[key] = String(line[line.index(after: firstQuote)..<lastQuote])
        }
        phrases = parsed
    }

    public func phrase(_ key: String) -> String? {
        phrases[key]
    }

    public func buildingFailureMessage(
        for kind: BuildingFailureKind,
        playerName: String?
    ) -> BuildingFailureMessage? {
        let keys = switch kind {
        case .fire:
            ("PHRASE_fire_title", "PHRASE_fire_initial_announcement")
        case .collapse:
            (
                "PHRASE_collapsed_building_title",
                "PHRASE_collapsed_building_initial_announcement"
            )
        }
        guard let title = phrase(keys.0),
              let authoredBody = phrase(keys.1) else { return nil }
        let body: String
        if let playerName, !playerName.isEmpty {
            body = authoredBody.replacingOccurrences(of: "[player_name]", with: playerName)
        } else {
            body = authoredBody
        }
        return BuildingFailureMessage(title: title, body: body)
    }
}
