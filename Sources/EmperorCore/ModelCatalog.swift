import Foundation

public struct ModelFileSummary: Identifiable, Sendable, Hashable {
    public let url: URL
    public let nonEmptyLineCount: Int
    public let assignmentCount: Int
    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}

public enum ModelCatalog {
    public static func scan(_ source: GameDataSource) throws -> [ModelFileSummary] {
        let files = try FileManager.default.contentsOfDirectory(
            at: source.modelDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.caseInsensitiveCompare("txt") == .orderedSame }

        return files.map { url in
            let data = (try? Data(contentsOf: url, options: [.mappedIfSafe])) ?? Data()
            let text = String(data: data, encoding: .windowsCP1252) ?? String(decoding: data, as: UTF8.self)
            let lines = text.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty && !$0.hasPrefix("//") && !$0.hasPrefix("#") }
            return ModelFileSummary(
                url: url,
                nonEmptyLineCount: lines.count,
                assignmentCount: lines.filter { $0.contains("=") }.count
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
