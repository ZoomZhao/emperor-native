import Foundation

public struct NativeSaveGame: Sendable, Equatable, Codable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let campaignFileName: String?
    public let missionIndex: Int?
    public let replaySeed: UInt64
    public let city: DeterministicCityState
    /// Optional so format-v1 saves written before the campaign clock existed
    /// continue to decode as ordinary native cities.
    public let campaignRuntime: CampaignMissionRuntimeState?

    public init(
        campaignFileName: String? = nil,
        missionIndex: Int? = nil,
        replaySeed: UInt64,
        city: DeterministicCityState,
        campaignRuntime: CampaignMissionRuntimeState? = nil
    ) {
        formatVersion = Self.currentFormatVersion
        self.campaignFileName = campaignFileName
        self.missionIndex = missionIndex
        self.replaySeed = replaySeed
        self.city = city
        self.campaignRuntime = campaignRuntime
    }
}

public enum NativeSaveGameStore {
    public static func encoded(_ save: NativeSaveGame) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(save)
    }

    public static func decoded(_ data: Data) throws -> NativeSaveGame {
        let save = try JSONDecoder().decode(NativeSaveGame.self, from: data)
        guard save.formatVersion == NativeSaveGame.currentFormatVersion else {
            throw GameDataError.unsupported("native save format v\(save.formatVersion)")
        }
        return save
    }

    public static func save(_ save: NativeSaveGame, to url: URL) throws {
        try encoded(save).write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> NativeSaveGame {
        try decoded(Data(contentsOf: url, options: [.mappedIfSafe]))
    }
}
