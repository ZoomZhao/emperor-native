import EmperorCore
import Foundation

enum NativeSaveHistoryKind: String, Sendable {
    case autosave = "auto"
    case quickSave = "quick"

    var title: String {
        switch self {
        case .autosave: "自动存档"
        case .quickSave: "快速存档"
        }
    }

    var symbol: String {
        switch self {
        case .autosave: "clock.arrow.circlepath"
        case .quickSave: "bolt.fill"
        }
    }
}

struct NativeSaveHistoryEntry: Identifiable, Sendable {
    let url: URL
    let kind: NativeSaveHistoryKind
    let savedAt: Date
    let campaignFileName: String?
    let missionIndex: Int?
    let year: Int?
    let month: Int?
    let population: Int?
    let treasury: Int?
    let outcome: CampaignMissionOutcome?
    let errorDescription: String?

    var id: URL { url }
    var isReadable: Bool { errorDescription == nil }
}

enum NativeSaveHistoryStore {
    static let autosaveLimitPerMission = 24

    static func directory(fileManager: FileManager = .default) throws -> URL {
        let arguments = ProcessInfo.processInfo.arguments
        let directory: URL
        if let optionIndex = arguments.firstIndex(of: "--save-directory"),
           arguments.indices.contains(optionIndex + 1) {
            directory = URL(fileURLWithPath: arguments[optionIndex + 1], isDirectory: true)
        } else {
            guard let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            directory = applicationSupport
                .appendingPathComponent("EmperorNative", isDirectory: true)
                .appendingPathComponent("Saves", isDirectory: true)
        }
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    static func write(
        _ save: NativeSaveGame,
        kind: NativeSaveHistoryKind,
        at date: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try directory(fileManager: fileManager)
        let campaign = sanitizedFileComponent(
            save.campaignFileName
                .map { ($0 as NSString).deletingPathExtension }
                ?? "free-city"
        )
        let mission = save.missionIndex.map { "m\($0 + 1)" } ?? "sandbox"
        let timestamp = timestampFormatter.string(from: date)
        let url = directory.appendingPathComponent(
            "\(kind.rawValue)-\(campaign)-\(mission)-\(timestamp).emperor-save.json"
        )
        try NativeSaveGameStore.save(save, to: url)
        if kind == .autosave {
            try pruneAutosaves(
                campaignFileName: save.campaignFileName,
                missionIndex: save.missionIndex,
                keeping: autosaveLimitPerMission,
                fileManager: fileManager
            )
        }
        return url
    }

    static func entries(fileManager: FileManager = .default) -> [NativeSaveHistoryEntry] {
        guard let directory = try? directory(fileManager: fileManager),
              let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        return urls.compactMap { url in
            guard url.lastPathComponent.hasSuffix(".emperor-save.json") else {
                return nil
            }
            let values = try? url.resourceValues(
                forKeys: [.contentModificationDateKey, .isRegularFileKey]
            )
            guard values?.isRegularFile != false else { return nil }
            let savedAt = values?.contentModificationDate ?? .distantPast
            let kind: NativeSaveHistoryKind = url.lastPathComponent.hasPrefix("auto-")
                ? .autosave
                : .quickSave
            do {
                let save = try NativeSaveGameStore.load(from: url)
                return NativeSaveHistoryEntry(
                    url: url,
                    kind: kind,
                    savedAt: savedAt,
                    campaignFileName: save.campaignFileName,
                    missionIndex: save.missionIndex,
                    year: save.city.calendar.year,
                    month: save.city.calendar.month,
                    population: save.city.population,
                    treasury: save.city.economy.treasury,
                    outcome: save.campaignRuntime?.outcome,
                    errorDescription: nil
                )
            } catch {
                return NativeSaveHistoryEntry(
                    url: url,
                    kind: kind,
                    savedAt: savedAt,
                    campaignFileName: nil,
                    missionIndex: nil,
                    year: nil,
                    month: nil,
                    population: nil,
                    treasury: nil,
                    outcome: nil,
                    errorDescription: error.localizedDescription
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.savedAt != rhs.savedAt { return lhs.savedAt > rhs.savedAt }
            return lhs.url.lastPathComponent > rhs.url.lastPathComponent
        }
    }

    static func remove(
        _ entry: NativeSaveHistoryEntry,
        fileManager: FileManager = .default
    ) throws {
        let savesDirectory = try directory(fileManager: fileManager)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let target = entry.url
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard target.deletingLastPathComponent() == savesDirectory else {
            throw CocoaError(.fileWriteNoPermission)
        }
        try fileManager.removeItem(at: target)
    }

    private static func pruneAutosaves(
        campaignFileName: String?,
        missionIndex: Int?,
        keeping limit: Int,
        fileManager: FileManager
    ) throws {
        let matching = entries(fileManager: fileManager).filter {
            $0.kind == .autosave
                && $0.campaignFileName == campaignFileName
                && $0.missionIndex == missionIndex
        }
        for entry in matching.dropFirst(max(1, limit)) {
            try fileManager.removeItem(at: entry.url)
        }
    }

    private static func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map {
            allowed.contains($0) ? Character(String($0)) : "-"
        }
        let compact = String(scalars)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String((compact.isEmpty ? "campaign" : compact).prefix(48))
    }

    private static var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }
}
