import Foundation

public struct GameDataSource: Sendable, Equatable {
    /// Local development checkout of the original game tree (repository root).
    public static let directoryName = "GameData"

    /// Folder name used by the legacy Wine/wrapper install under `/Applications`.
    public static let legacyInstallDirectoryName = "EmperorRotMK[ZeaS]"

    /// Resolved game-data root used when no explicit `--data` path is provided.
    /// Prefers app-bundle Resources, then the repository checkout, then a legacy
    /// wrapper install if present.
    public static var defaultRoot: URL {
        resolvedDefaultRoot()
    }

    public let root: URL

    public var dataDirectory: URL { root.appendingPathComponent("DATA", isDirectory: true) }
    public var citiesDirectory: URL { root.appendingPathComponent("Cities", isDirectory: true) }
    public var campaignsDirectory: URL { root.appendingPathComponent("Campaigns", isDirectory: true) }
    public var modelDirectory: URL { root.appendingPathComponent("Model", isDirectory: true) }
    public var audioDirectory: URL { root.appendingPathComponent("Audio", isDirectory: true) }
    public var moviesDirectory: URL { root.appendingPathComponent("Binks", isDirectory: true) }
    public var savesDirectory: URL { root.appendingPathComponent("Save", isDirectory: true) }

    public init(root: URL) throws {
        let standardized = root.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GameDataError.missingRoot(standardized.path)
        }

        for directory in Self.requiredDirectories {
            let candidate = standardized.appendingPathComponent(directory, isDirectory: true)
            var childIsDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &childIsDirectory),
                  childIsDirectory.boolValue else {
                throw GameDataError.missingDirectory(directory)
            }
        }
        self.root = standardized
    }

    public static func openDefault() throws -> GameDataSource {
        try GameDataSource(root: defaultRoot)
    }

    private static let requiredDirectories = ["DATA", "Cities", "Campaigns", "Model", "Audio"]

    private static func resolvedDefaultRoot() -> URL {
        for candidate in defaultRootCandidates() where isCompleteGameRoot(candidate) {
            return candidate.standardizedFileURL
        }
        return URL(
            fileURLWithPath: "/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/\(legacyInstallDirectoryName)",
            isDirectory: true
        ).standardizedFileURL
    }

    private static func defaultRootCandidates() -> [URL] {
        var candidates: [URL] = []
        var seen = Set<String>()

        func append(_ url: URL) {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                candidates.append(standardized)
            }
        }

        if let resourceRoot = Bundle.main.resourceURL {
            append(resourceRoot.appendingPathComponent(directoryName, isDirectory: true))
        }

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // EmperorCore
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // package root
        append(packageRoot.appendingPathComponent(directoryName, isDirectory: true))

        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        for _ in 0..<8 {
            append(directory.appendingPathComponent(directoryName, isDirectory: true))
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }

        append(
            URL(
                fileURLWithPath: "/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/\(legacyInstallDirectoryName)",
                isDirectory: true
            )
        )

        return candidates
    }

    private static func isCompleteGameRoot(_ root: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        for directory in requiredDirectories {
            let candidate = root.appendingPathComponent(directory, isDirectory: true)
            var childIsDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &childIsDirectory),
                  childIsDirectory.boolValue else {
                return false
            }
        }
        return true
    }
}

public enum GameDataError: Error, LocalizedError, Equatable {
    case missingRoot(String)
    case missingDirectory(String)
    case malformedFile(String)
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case let .missingRoot(path): return "找不到游戏数据目录：\(path)"
        case let .missingDirectory(name): return "游戏数据不完整，缺少目录：\(name)"
        case let .malformedFile(reason): return "数据文件格式无效：\(reason)"
        case let .unsupported(reason): return "暂不支持的数据格式：\(reason)"
        }
    }
}
