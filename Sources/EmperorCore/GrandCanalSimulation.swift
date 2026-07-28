import Foundation

public struct GrandCanalSubBuilding: Sendable, Hashable, Codable {
    public let index: Int
    public let localOrigin: GridPoint
    public let isRoadCrossing: Bool

    public init(index: Int, localOrigin: GridPoint, isRoadCrossing: Bool) {
        self.index = index
        self.localOrigin = localOrigin
        self.isRoadCrossing = isRoadCrossing
    }

    public var footprint: BuildingFootprint {
        BuildingFootprint(width: 4, height: 4)
    }

    public func worldOrigin(from monumentOrigin: GridPoint) -> GridPoint {
        GridPoint(
            x: monumentOrigin.x + localOrigin.x,
            y: monumentOrigin.y + localOrigin.y
        )
    }
}

public struct GrandCanalPhaseRule: Sendable, Hashable, Codable {
    public let monumentPhase: Int
    public let firstSegmentIndex: Int
    public let lastSegmentIndex: Int
    public let firstSubBuildingPhase: Int
    public let lastSubBuildingPhase: Int
}

public struct GrandCanalLayout: Sendable, Hashable, Codable {
    public let segments: [GrandCanalSubBuilding]
    public let phaseRules: [GrandCanalPhaseRule]

    public static let haunxianOrigin = GridPoint(x: 4, y: 68)

    public static let original = GrandCanalLayout(
        segments: (0..<33).map { index in
            GrandCanalSubBuilding(
                index: index,
                localOrigin: GridPoint(x: index * 4, y: 0),
                isRoadCrossing: [10, 16, 22].contains(index)
            )
        },
        phaseRules: (0..<5).map { phase in
            GrandCanalPhaseRule(
                monumentPhase: phase,
                firstSegmentIndex: 0,
                lastSegmentIndex: 32,
                firstSubBuildingPhase: phase,
                lastSubBuildingPhase: phase + 1
            )
        }
    )

    public static func parse(subBuildingText: String) -> GrandCanalLayout? {
        let segmentExpression = try? NSRegularExpression(
            pattern: #"/\*\s*(\d+)\*/\s*\{\s*(\d+),\s*(\d+),\s*SB_CANAL,\s*\d+,\s*NORTH,\s*(\d+),"#
        )
        let phaseExpression = try? NSRegularExpression(
            pattern: #"<\s*(\d+),\s*(\d+),\s*\d+,\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),"#
        )
        guard let segmentExpression, let phaseExpression else { return nil }
        let range = NSRange(subBuildingText.startIndex..., in: subBuildingText)
        let segments = segmentExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> GrandCanalSubBuilding? in
            guard let index = match.integer(at: 1, in: subBuildingText),
                  let x = match.integer(at: 2, in: subBuildingText),
                  let y = match.integer(at: 3, in: subBuildingText),
                  let entry = match.integer(at: 4, in: subBuildingText) else { return nil }
            return GrandCanalSubBuilding(
                index: index,
                localOrigin: GridPoint(x: x, y: y),
                isRoadCrossing: entry == 1
            )
        }
        let phases = phaseExpression.matches(in: subBuildingText, range: range).compactMap {
            match -> GrandCanalPhaseRule? in
            guard let monumentPhase = match.integer(at: 1, in: subBuildingText),
                  match.integer(at: 2, in: subBuildingText) == 0,
                  let firstSegment = match.integer(at: 3, in: subBuildingText),
                  let lastSegment = match.integer(at: 4, in: subBuildingText),
                  let firstPhase = match.integer(at: 5, in: subBuildingText),
                  let lastPhase = match.integer(at: 6, in: subBuildingText) else { return nil }
            return GrandCanalPhaseRule(
                monumentPhase: monumentPhase,
                firstSegmentIndex: firstSegment,
                lastSegmentIndex: lastSegment,
                firstSubBuildingPhase: firstPhase,
                lastSubBuildingPhase: lastPhase
            )
        }
        guard segments.count == 33, phases.count == 5 else { return nil }
        return GrandCanalLayout(
            segments: segments.sorted { $0.index < $1.index },
            phaseRules: phases.sorted { $0.monumentPhase < $1.monumentPhase }
        )
    }
}

public struct GrandCanalSegmentRuntime: Sendable, Hashable, Codable {
    public let index: Int
    public private(set) var stage: Int
    public private(set) var deliveredWood: Int
    public private(set) var deliveredStone: Int
    public private(set) var completedWork: Int

    public var isFinal: Bool { stage == GrandCanalProjectRuntime.finalStage }

    fileprivate mutating func advance(
        deliveredWood: Int,
        deliveredStone: Int,
        completedWork: Int
    ) {
        stage = min(GrandCanalProjectRuntime.finalStage, stage + 1)
        self.deliveredWood = deliveredWood
        self.deliveredStone = deliveredStone
        self.completedWork = completedWork
    }
}

public struct GrandCanalProjectRuntime: Sendable, Hashable, Codable {
    public static let buildingID = 83
    public static let finalStage = 4

    public let projectID: Int
    public let origin: GridPoint
    public let rotation: Int
    public private(set) var segments: [GrandCanalSegmentRuntime]

    public init(
        projectID: Int,
        origin: GridPoint = GrandCanalLayout.haunxianOrigin,
        rotation: Int = 0
    ) {
        self.projectID = projectID
        self.origin = origin
        self.rotation = rotation
        segments = GrandCanalLayout.original.segments.map {
            GrandCanalSegmentRuntime(
                index: $0.index,
                stage: 0,
                deliveredWood: 0,
                deliveredStone: 0,
                completedWork: 0
            )
        }
    }

    public var isComplete: Bool {
        segments.allSatisfy(\.isFinal)
    }

    public var completionPercent: Int {
        let progress = segments.reduce(0) { $0 + $1.stage }
        return progress * 100 / max(1, segments.count * Self.finalStage)
    }

    public func segmentIndex(containing point: GridPoint) -> Int? {
        GrandCanalLayout.original.segments.first {
            $0.footprint.points(at: $0.worldOrigin(from: origin)).contains(point)
        }?.index
    }

    public func worldOrigin(forSegment index: Int) -> GridPoint? {
        GrandCanalLayout.original.segments.first(where: { $0.index == index })?
            .worldOrigin(from: origin)
    }

    public func isRoadCrossing(segment index: Int) -> Bool {
        GrandCanalLayout.original.segments.first(where: { $0.index == index })?
            .isRoadCrossing ?? false
    }

    mutating func advanceSegment(
        index: Int,
        project: MonumentProject
    ) -> Bool {
        guard let position = segments.firstIndex(where: { $0.index == index }),
              segments[position].stage < Self.finalStage else { return false }
        let nextStage = segments[position].stage + 1
        let wood = Self.segmentShare(total: project.requiredCommodityUnits[10, default: 0], index: index)
        let stone = Self.segmentShare(total: project.requiredCommodityUnits[20, default: 0], index: index)
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
        let quotient = total / 33
        return quotient + (index < total % 33 ? 1 : 0)
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
