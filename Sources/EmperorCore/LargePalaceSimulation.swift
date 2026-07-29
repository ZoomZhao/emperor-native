import Foundation

public enum LargePalaceSubBuildingKind: String, Sendable, Hashable, Codable {
    case templeSteps = "SB_TEMPLE_STEPS"
    case palace = "SB_PALACE"
    case causeway = "SB_PALACE_CAUSEWAY"
    case courtyard = "SB_PALACE_COURTYARD"
    case palaceSteps = "SB_PALACE_STEPS"
}

public struct LargePalaceSubBuilding: Sendable, Hashable, Codable {
    public let index: Int
    public let localOrigin: GridPoint
    public let kind: LargePalaceSubBuildingKind
    public let isRoadEntrance: Bool
}

public struct LargePalacePhaseRule: Sendable, Hashable, Codable {
    public let monumentPhase: Int
    public let isJoined: Bool
    public let firstSubBuildingIndex: Int
    public let lastSubBuildingIndex: Int
    public let firstSubBuildingPhase: Int
    public let lastSubBuildingPhase: Int
}

public struct LargePalaceLayout: Sendable, Hashable, Codable {
    public let subBuildings: [LargePalaceSubBuilding]
    public let phaseRules: [LargePalacePhaseRule]

    public static func parse(subBuildingText: String) -> LargePalaceLayout? {
        let itemExpression = try? NSRegularExpression(
            pattern: #"/\*\s*(\d+)\*/\s*\{\s*(-?\d+),\s*(-?\d+),\s*(SB_[A-Z_]+),\s*\d+,\s*[A-Z]+,\s*(\d+),"#
        )
        let phaseExpression = try? NSRegularExpression(
            pattern: #"<\s*(\d+),\s*(\d+),\s*\d+,\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),"#
        )
        guard let itemExpression, let phaseExpression else { return nil }
        let range = NSRange(subBuildingText.startIndex..., in: subBuildingText)
        let items = itemExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> LargePalaceSubBuilding? in
            guard let index = match.integer(at: 1, in: subBuildingText),
                  let x = match.integer(at: 2, in: subBuildingText),
                  let y = match.integer(at: 3, in: subBuildingText),
                  let kindName = match.string(at: 4, in: subBuildingText),
                  let kind = LargePalaceSubBuildingKind(rawValue: kindName),
                  let entry = match.integer(at: 5, in: subBuildingText) else { return nil }
            return LargePalaceSubBuilding(
                index: index,
                localOrigin: GridPoint(x: x, y: y),
                kind: kind,
                isRoadEntrance: entry == 1
            )
        }
        let phases = phaseExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> LargePalacePhaseRule? in
            guard let phase = match.integer(at: 1, in: subBuildingText),
                  let type = match.integer(at: 2, in: subBuildingText),
                  let first = match.integer(at: 3, in: subBuildingText),
                  let last = match.integer(at: 4, in: subBuildingText),
                  let firstPhase = match.integer(at: 5, in: subBuildingText),
                  let lastPhase = match.integer(at: 6, in: subBuildingText) else { return nil }
            return LargePalacePhaseRule(
                monumentPhase: phase,
                isJoined: type == 1,
                firstSubBuildingIndex: first,
                lastSubBuildingIndex: last,
                firstSubBuildingPhase: firstPhase,
                lastSubBuildingPhase: lastPhase
            )
        }
        guard items.count == 153, Set(phases.map(\.monumentPhase)) == Set(0...15) else {
            return nil
        }
        return LargePalaceLayout(
            subBuildings: items.sorted { $0.index < $1.index },
            phaseRules: phases.sorted {
                $0.monumentPhase == $1.monumentPhase
                    ? $0.firstSubBuildingIndex < $1.firstSubBuildingIndex
                    : $0.monumentPhase < $1.monumentPhase
            }
        )
    }
}

public struct LargePalaceProjectRuntime: Sendable, Hashable, Codable {
    public static let buildingID = 82
    public static let phaseCount = 16

    public let projectID: Int
    public let origin: GridPoint
    public let orientation: IsometricBuildingOrientation
    public private(set) var completedPhaseCount: Int
    public private(set) var deliveredCommodityUnits: [Int: Int]
    public private(set) var completedWork: Int

    public init(
        projectID: Int,
        origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) {
        self.projectID = projectID
        self.origin = origin
        self.orientation = orientation
        completedPhaseCount = 0
        deliveredCommodityUnits = [:]
        completedWork = 0
    }

    public var isComplete: Bool { completedPhaseCount == Self.phaseCount }
    public var completionPercent: Int { completedPhaseCount * 100 / Self.phaseCount }

    struct PhaseRequirements: Sendable, Hashable {
        let completedPhaseCount: Int
        let work: Int
        let commodityUnits: [Int: Int]
    }

    public func contains(_ point: GridPoint) -> Bool {
        (OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: Self.buildingID,
            orientation: orientation
        ) ?? BuildingFootprint(width: 12, height: 12))
            .points(at: origin).contains(point)
    }

    mutating func advance(project: MonumentProject) -> Bool {
        guard let requirements = nextPhaseRequirements(project: project),
              project.completedWork >= requirements.work,
              requirements.commodityUnits.allSatisfy({
                  project.deliveredCommodityUnits[$0.key, default: 0] >= $0.value
              }) else { return false }
        completedPhaseCount = requirements.completedPhaseCount
        completedWork = requirements.work
        deliveredCommodityUnits = requirements.commodityUnits
        return true
    }

    func nextPhaseRequirements(project: MonumentProject) -> PhaseRequirements? {
        guard !isComplete else { return nil }
        let nextPhaseCount = completedPhaseCount + 1
        let requiredWork = Self.cumulativeShare(
            total: project.requiredWork,
            completed: nextPhaseCount,
            count: Self.phaseCount
        )
        let materialPhaseCount = max(0, nextPhaseCount - 5)
        let materialPhaseTotal = Self.phaseCount - 5
        var requiredMaterials: [Int: Int] = [:]
        for (commodityID, total) in project.requiredCommodityUnits {
            requiredMaterials[commodityID] = Self.cumulativeShare(
                total: total,
                completed: materialPhaseCount,
                count: materialPhaseTotal
            )
        }
        return PhaseRequirements(
            completedPhaseCount: nextPhaseCount,
            work: requiredWork,
            commodityUnits: requiredMaterials
        )
    }

    private static func cumulativeShare(total: Int, completed: Int, count: Int) -> Int {
        guard completed > 0 else { return 0 }
        return (total * min(completed, count) + count - 1) / count
    }
}

private extension NSTextCheckingResult {
    func integer(at index: Int, in source: String) -> Int? {
        string(at: index, in: source).flatMap(Int.init)
    }

    func string(at index: Int, in source: String) -> String? {
        guard let range = Range(range(at: index), in: source) else { return nil }
        return String(source[range])
    }
}
