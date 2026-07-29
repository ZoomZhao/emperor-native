import Foundation

public struct PhasedMonumentSubBuilding: Sendable, Hashable, Codable {
    public let index: Int
    public let localOrigin: GridPoint
    public let kind: String
    public let elevation: Int
    public let orientation: String
    public let variant: String
}

public struct PhasedMonumentPhaseRule: Sendable, Hashable, Codable {
    public let monumentPhase: Int
    public let isJoined: Bool
    public let firstSubBuildingIndex: Int
    public let lastSubBuildingIndex: Int
    public let firstSubBuildingPhase: Int
    public let lastSubBuildingPhase: Int
}

public struct PhasedMonumentLayout: Sendable, Hashable, Codable {
    public let subBuildings: [PhasedMonumentSubBuilding]
    public let phaseRules: [PhasedMonumentPhaseRule]

    public static func parse(
        subBuildingText: String,
        expectedSubBuildingCount: Int,
        expectedPhaseCount: Int
    ) -> Self? {
        let itemExpression = try? NSRegularExpression(
            pattern: #"/\*\s*(\d+)\*/\s*\{\s*(-?\d+),\s*(-?\d+),\s*(SB_[A-Z_]+),\s*(-?\d+),\s*([A-Z]+),\s*([A-Z]+|\d+),"#
        )
        let phaseExpression = try? NSRegularExpression(
            pattern: #"<\s*(\d+),\s*(\d+),\s*\d+,\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),"#
        )
        guard let itemExpression, let phaseExpression else { return nil }
        let range = NSRange(subBuildingText.startIndex..., in: subBuildingText)
        let items = itemExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> PhasedMonumentSubBuilding? in
            guard let index = match.integer(at: 1, in: subBuildingText),
                  let x = match.integer(at: 2, in: subBuildingText),
                  let y = match.integer(at: 3, in: subBuildingText),
                  let kind = match.string(at: 4, in: subBuildingText),
                  let elevation = match.integer(at: 5, in: subBuildingText),
                  let orientation = match.string(at: 6, in: subBuildingText),
                  let variant = match.string(at: 7, in: subBuildingText) else {
                return nil
            }
            return PhasedMonumentSubBuilding(
                index: index,
                localOrigin: GridPoint(x: x, y: y),
                kind: kind,
                elevation: elevation,
                orientation: orientation,
                variant: variant
            )
        }
        let phases = phaseExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> PhasedMonumentPhaseRule? in
            guard let phase = match.integer(at: 1, in: subBuildingText),
                  let type = match.integer(at: 2, in: subBuildingText),
                  let first = match.integer(at: 3, in: subBuildingText),
                  let last = match.integer(at: 4, in: subBuildingText),
                  let firstPhase = match.integer(at: 5, in: subBuildingText),
                  let lastPhase = match.integer(at: 6, in: subBuildingText) else {
                return nil
            }
            return PhasedMonumentPhaseRule(
                monumentPhase: phase,
                isJoined: type == 1,
                firstSubBuildingIndex: first,
                lastSubBuildingIndex: last,
                firstSubBuildingPhase: firstPhase,
                lastSubBuildingPhase: lastPhase
            )
        }
        guard items.count == expectedSubBuildingCount,
              Set(phases.map(\.monumentPhase)) == Set(0..<expectedPhaseCount) else {
            return nil
        }
        return Self(
            subBuildings: items.sorted { $0.index < $1.index },
            phaseRules: phases.sorted {
                $0.monumentPhase == $1.monumentPhase
                    ? $0.firstSubBuildingIndex < $1.firstSubBuildingIndex
                    : $0.monumentPhase < $1.monumentPhase
            }
        )
    }
}

/// Player-visible construction phases for the two Qin V mausoleum projects.
///
/// The Windows data authors the underground vault as nine monument phases and
/// the grand tumulus as forty-three. The detailed sub-building animation is
/// separate from this runtime; this type owns the deterministic material/work
/// gates and save state so a fully supplied project cannot complete without
/// the player advancing every authored phase.
public struct PhasedMonumentProjectRuntime: Sendable, Hashable, Codable {
    public static let phaseCountsByBuildingID = [
        77: 43, // Grand Tumulus
        84: 9,  // Underground Vault
    ]

    public let projectID: Int
    public let buildingID: Int
    public let origin: GridPoint
    public let orientation: IsometricBuildingOrientation
    public let phaseCount: Int
    public private(set) var completedPhaseCount: Int
    public private(set) var deliveredCommodityUnits: [Int: Int]
    public private(set) var completedWork: Int

    public init?(
        projectID: Int,
        buildingID: Int,
        origin: GridPoint,
        orientation: IsometricBuildingOrientation
    ) {
        guard let phaseCount = Self.phaseCountsByBuildingID[buildingID] else {
            return nil
        }
        self.projectID = projectID
        self.buildingID = buildingID
        self.origin = origin
        self.orientation = orientation
        self.phaseCount = phaseCount
        completedPhaseCount = 0
        deliveredCommodityUnits = [:]
        completedWork = 0
    }

    public var isComplete: Bool { completedPhaseCount == phaseCount }
    public var completionPercent: Int { completedPhaseCount * 100 / phaseCount }

    public func contains(_ point: GridPoint) -> Bool {
        (OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID,
            orientation: orientation
        ) ?? BuildingFootprint(width: 1, height: 1))
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

    func nextPhaseRequirements(project: MonumentProject) -> MonumentPhaseRequirements? {
        guard !isComplete else { return nil }
        let nextPhase = completedPhaseCount + 1
        return MonumentPhaseRequirements(
            completedPhaseCount: nextPhase,
            work: Self.cumulativeShare(
                total: project.requiredWork,
                completed: nextPhase,
                count: phaseCount
            ),
            commodityUnits: project.requiredCommodityUnits.mapValues {
                Self.cumulativeShare(
                    total: $0,
                    completed: nextPhase,
                    count: phaseCount
                )
            }
        )
    }

    private static func cumulativeShare(total: Int, completed: Int, count: Int) -> Int {
        guard completed > 0 else { return 0 }
        return (total * min(completed, count) + count - 1) / count
    }
}

struct MonumentPhaseRequirements: Sendable, Hashable {
    let completedPhaseCount: Int
    let work: Int
    let commodityUnits: [Int: Int]
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
