import Foundation

public struct GameDataCatalog: Sendable {
    public struct Entry: Identifiable, Sendable, Hashable {
        public let url: URL
        public let byteCount: Int64
        public var id: URL { url }
        public var name: String { url.lastPathComponent }
    }

    public let maps: [Entry]
    public let campaigns: [Entry]
    public let spriteDescriptions: [Entry]
    public let spritePixels: [Entry]
    public let modelFiles: [Entry]
    public let waveAudio: [Entry]
    public let music: [Entry]

    public var totalIndexedFiles: Int {
        maps.count + campaigns.count + spriteDescriptions.count + spritePixels.count
            + modelFiles.count + waveAudio.count + music.count
    }

    public static func scan(_ source: GameDataSource) throws -> GameDataCatalog {
        let cityMaps = try entries(in: source.citiesDirectory, extension: "map")
        let campaignMaps = try entries(in: source.campaignsDirectory, extension: "map")
        return try GameDataCatalog(
            maps: (cityMaps + campaignMaps).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            campaigns: entries(in: source.campaignsDirectory, extension: "pak"),
            spriteDescriptions: entries(in: source.dataDirectory, extension: "sg3"),
            spritePixels: entries(in: source.dataDirectory, extension: "555"),
            modelFiles: entries(in: source.modelDirectory, extension: "txt"),
            waveAudio: entries(in: source.audioDirectory, extension: "wav"),
            music: entries(in: source.audioDirectory, extension: "mp3")
        )
    }

    private static func entries(in directory: URL, extension wantedExtension: String) throws -> [Entry] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var result: [Entry] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.caseInsensitiveCompare(wantedExtension) == .orderedSame else { continue }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            result.append(Entry(url: url, byteCount: Int64(values.fileSize ?? 0)))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
