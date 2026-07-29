import Foundation

public struct EarthenGreatWallSubBuilding: Sendable, Hashable, Codable {
    public let index: Int
    public let localOrigin: GridPoint
    public let elevation: Int
    public let cutVariant: Int

    public init(
        index: Int,
        localOrigin: GridPoint,
        elevation: Int,
        cutVariant: Int
    ) {
        self.index = index
        self.localOrigin = localOrigin
        self.elevation = elevation
        self.cutVariant = cutVariant
    }

    public var footprint: BuildingFootprint {
        BuildingFootprint(width: 4, height: 4)
    }
}

public struct EarthenGreatWallPhaseRule: Sendable, Hashable, Codable {
    public let monumentPhase: Int
    public let firstSegmentIndex: Int
    public let lastSegmentIndex: Int
    public let firstSubBuildingPhase: Int
    public let lastSubBuildingPhase: Int
}

public struct EarthenGreatWallLayout: Sendable, Hashable, Codable {
    public let segments: [EarthenGreatWallSubBuilding]
    public let phaseRules: [EarthenGreatWallPhaseRule]

    public static let original = EarthenGreatWallLayout(
        segments: [
            (-36, 32, 0, 25), (-32, 32, 0, 1), (-28, 32, 0, 0),
            (-24, 32, 0, 8), (-20, 32, 0, 20), (-20, 28, 0, 19),
            (-20, 24, 0, 15), (-20, 20, 0, 16), (-20, 16, 0, 11),
            (-20, 12, 0, 10), (-20, 8, 0, 12), (-20, 4, 1, 14),
            (-20, 0, 1, 21), (-16, 0, 1, 3), (-12, 0, 1, 7),
            (-8, 0, 2, 25), (-4, 0, 1, 2), (0, 0, 0, 2),
            (4, 0, 0, 1), (8, 0, 0, 0), (12, 0, 0, 8),
            (16, 0, 0, 20), (16, -4, 0, 19), (16, -8, -1, 17),
            (16, -12, -1, 24), (16, -16, -1, 12), (16, -20, 0, 24),
            (16, -24, 0, 11), (16, -28, 0, 10), (16, -32, 0, 24),
            (16, -36, 0, 14), (16, -40, 0, 21), (20, -40, 0, 3),
            (24, -40, 0, 25), (28, -40, 0, 25),
        ].enumerated().map { index, value in
            EarthenGreatWallSubBuilding(
                index: index,
                localOrigin: GridPoint(x: value.0, y: value.1),
                elevation: value.2,
                cutVariant: value.3
            )
        },
        phaseRules: [
            (0, 0, 1), (1, 1, 3), (2, 3, 4), (3, 4, 6),
            (4, 6, 7), (5, 7, 9), (6, 9, 10), (7, 10, 11),
        ].map { phase, first, last in
            EarthenGreatWallPhaseRule(
                monumentPhase: phase,
                firstSegmentIndex: 0,
                lastSegmentIndex: 34,
                firstSubBuildingPhase: first,
                lastSubBuildingPhase: last
            )
        }
    )

    public static func parse(subBuildingText: String) -> EarthenGreatWallLayout? {
        let segmentExpression = try? NSRegularExpression(
            pattern: #"/\*\s*(\d+)\*/\s*\{\s*(-?\d+),\s*(-?\d+),\s*SB_EARTHEN_GREAT_WALL,\s*(-?\d+),\s*NORTH,\s*(\d+),"#
        )
        let phaseExpression = try? NSRegularExpression(
            pattern: #"<\s*(\d+),\s*(\d+),\s*\d+,\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),"#
        )
        guard let segmentExpression, let phaseExpression else { return nil }
        let range = NSRange(subBuildingText.startIndex..., in: subBuildingText)
        let segments = segmentExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> EarthenGreatWallSubBuilding? in
            guard let index = match.integer(at: 1, in: subBuildingText),
                  let x = match.integer(at: 2, in: subBuildingText),
                  let y = match.integer(at: 3, in: subBuildingText),
                  let elevation = match.integer(at: 4, in: subBuildingText),
                  let cutVariant = match.integer(at: 5, in: subBuildingText) else {
                return nil
            }
            return EarthenGreatWallSubBuilding(
                index: index,
                localOrigin: GridPoint(x: x, y: y),
                elevation: elevation,
                cutVariant: cutVariant
            )
        }
        let phases = phaseExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> EarthenGreatWallPhaseRule? in
            guard let phase = match.integer(at: 1, in: subBuildingText),
                  match.integer(at: 2, in: subBuildingText) == 0,
                  let first = match.integer(at: 3, in: subBuildingText),
                  let last = match.integer(at: 4, in: subBuildingText),
                  let firstSubPhase = match.integer(at: 5, in: subBuildingText),
                  let lastSubPhase = match.integer(at: 6, in: subBuildingText) else {
                return nil
            }
            return EarthenGreatWallPhaseRule(
                monumentPhase: phase,
                firstSegmentIndex: first,
                lastSegmentIndex: last,
                firstSubBuildingPhase: firstSubPhase,
                lastSubBuildingPhase: lastSubPhase
            )
        }
        guard segments.count == 35, phases.count == 8 else { return nil }
        return EarthenGreatWallLayout(
            segments: segments.sorted { $0.index < $1.index },
            phaseRules: phases.sorted { $0.monumentPhase < $1.monumentPhase }
        )
    }
}

public struct EarthenGreatWallSegmentRuntime: Sendable, Hashable, Codable {
    public let index: Int
    public private(set) var stage: Int
    public private(set) var deliveredWood: Int
    public private(set) var deliveredStone: Int
    public private(set) var completedWork: Int

    public var isFinal: Bool { stage == EarthenGreatWallProjectRuntime.finalStage }

    fileprivate mutating func advance(
        deliveredWood: Int,
        deliveredStone: Int,
        completedWork: Int
    ) {
        stage = min(EarthenGreatWallProjectRuntime.finalStage, stage + 1)
        self.deliveredWood = deliveredWood
        self.deliveredStone = deliveredStone
        self.completedWork = completedWork
    }
}

public struct EarthenGreatWallProjectRuntime: Sendable, Hashable, Codable {
    public static let buildingID = 85
    public static let finalStage = 11
    public static let segmentCount = 35

    public let projectID: Int
    public private(set) var segments: [EarthenGreatWallSegmentRuntime]

    public init(projectID: Int) {
        self.projectID = projectID
        segments = (0..<Self.segmentCount).map {
            EarthenGreatWallSegmentRuntime(
                index: $0,
                stage: 0,
                deliveredWood: 0,
                deliveredStone: 0,
                completedWork: 0
            )
        }
    }

    public var isComplete: Bool { segments.allSatisfy(\.isFinal) }

    public var completionPercent: Int {
        let progress = segments.reduce(0) { $0 + $1.stage }
        return progress * 100 / (Self.segmentCount * Self.finalStage)
    }

    mutating func advanceSegment(index: Int, project: MonumentProject) -> Bool {
        guard let position = segments.firstIndex(where: { $0.index == index }),
              !segments[position].isFinal else { return false }
        let nextStage = segments[position].stage + 1
        let wood = Self.segmentShare(
            total: project.requiredCommodityUnits[10, default: 0],
            index: index
        )
        let stone = Self.segmentShare(
            total: project.requiredCommodityUnits[20, default: 0],
            index: index
        )
        let work = Self.segmentShare(total: project.requiredWork, index: index)
        let nextWood = Self.cumulativeShare(wood, stage: nextStage)
        let nextStone = Self.cumulativeShare(stone, stage: nextStage)
        let nextWork = Self.cumulativeShare(work, stage: nextStage)

        let assignedWood = segments.reduce(0) { $0 + $1.deliveredWood }
            - segments[position].deliveredWood + nextWood
        let assignedStone = segments.reduce(0) { $0 + $1.deliveredStone }
            - segments[position].deliveredStone + nextStone
        let assignedWork = segments.reduce(0) { $0 + $1.completedWork }
            - segments[position].completedWork + nextWork
        guard project.deliveredCommodityUnits[10, default: 0] >= assignedWood,
              project.deliveredCommodityUnits[20, default: 0] >= assignedStone,
              project.completedWork >= assignedWork else { return false }
        segments[position].advance(
            deliveredWood: nextWood,
            deliveredStone: nextStone,
            completedWork: nextWork
        )
        return true
    }

    private static func segmentShare(total: Int, index: Int) -> Int {
        let quotient = total / segmentCount
        return quotient + (index < total % segmentCount ? 1 : 0)
    }

    private static func cumulativeShare(_ total: Int, stage: Int) -> Int {
        (total * min(max(stage, 0), finalStage) + finalStage - 1) / finalStage
    }
}

private extension NSTextCheckingResult {
    func integer(at index: Int, in source: String) -> Int? {
        guard let range = Range(range(at: index), in: source) else { return nil }
        return Int(source[range])
    }
}
