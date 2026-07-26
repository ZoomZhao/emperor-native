import Foundation

public enum OriginalMusicCategory: String, Sendable, Hashable {
    case general
    case combat
}

public struct OriginalMusicTrack: Identifiable, Sendable, Hashable {
    public let category: OriginalMusicCategory
    public let url: URL

    public var id: URL { url }
    public var title: String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
    }
}

public struct OriginalBuildingSound: Identifiable, Sendable, Hashable {
    public let buildingID: Int
    public let buildingName: String
    public let url: URL
    public let volume: Double

    public var id: Int { buildingID }
}

public struct OriginalAudioCatalog: Sendable, Hashable {
    public let music: [OriginalMusicTrack]
    public let buildingSounds: [OriginalBuildingSound]

    public init(source: GameDataSource) throws {
        music = try Self.parseMusic(in: source.audioDirectory)
        buildingSounds = try Self.parseBuildingSounds(in: source.audioDirectory)
    }

    public func sound(forBuildingID buildingID: Int) -> OriginalBuildingSound? {
        buildingSounds.first { $0.buildingID == buildingID }
    }

    private static func parseMusic(in audioDirectory: URL) throws -> [OriginalMusicTrack] {
        let text = try LegacyModelText.read(audioDirectory.appendingPathComponent("music.txt"))
        var category: OriginalMusicCategory?
        var tracks: [OriginalMusicTrack] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";") else { continue }
            if line.caseInsensitiveCompare("GENERAL_MUSIC") == .orderedSame {
                category = .general
            } else if line.caseInsensitiveCompare("COMBAT_MUSIC") == .orderedSame {
                category = .combat
            } else if let category {
                tracks.append(OriginalMusicTrack(
                    category: category,
                    url: audioDirectory.appendingPathComponent("Music").appendingPathComponent(line)
                ))
            }
        }
        return tracks
    }

    private static func parseBuildingSounds(in audioDirectory: URL) throws -> [OriginalBuildingSound] {
        let text = try LegacyModelText.read(audioDirectory.appendingPathComponent("BuildingSounds.txt"))
        var sounds: [OriginalBuildingSound] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";"),
                  let colon = line.firstIndex(of: ":") else { continue }
            let identity = line[..<colon]
            guard let comma = identity.firstIndex(of: ","),
                  let buildingID = Int(identity[..<comma].trimmingCharacters(in: .whitespaces)) else {
                continue
            }
            let buildingName = identity[identity.index(after: comma)...]
                .trimmingCharacters(in: .whitespaces)
            let soundFields = line[line.index(after: colon)...].split(
                separator: ",",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            let fileName = soundFields.first.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !fileName.isEmpty else { continue }
            let volumePercent = soundFields.count > 1
                ? Int(soundFields[1].trimmingCharacters(in: .whitespaces)) ?? 100
                : 100
            sounds.append(OriginalBuildingSound(
                buildingID: buildingID,
                buildingName: buildingName,
                url: audioDirectory.appendingPathComponent("Ambient/Layer2").appendingPathComponent(fileName),
                volume: Double(min(max(volumePercent, 0), 100)) / 100
            ))
        }
        return sounds
    }
}
