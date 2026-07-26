import Foundation

public enum FigureMovementDirection: Int, CaseIterable, Sendable, Hashable, Codable {
    case north
    case northEast
    case east
    case southEast
    case south
    case southWest
    case west
    case northWest

    public static func direction(from previous: GridPoint?, to current: GridPoint) -> Self {
        guard let previous else { return .south }
        let dx = current.x - previous.x
        let dy = current.y - previous.y
        switch (dx.signum(), dy.signum()) {
        case (0, -1): return .north
        case (1, -1): return .northEast
        case (1, 0): return .east
        case (1, 1): return .southEast
        case (0, 1): return .south
        case (-1, 1): return .southWest
        case (-1, 0): return .west
        case (-1, -1): return .northWest
        default: return .south
        }
    }
}

public enum TutorialFigureRole: String, CaseIterable, Sendable, Hashable, Codable {
    case immigrant
    case delivery
    case peddler
    case buyer
    case waterBearer
    case ancestorPriest
    case inspector
}

public struct FigureSpriteReference: Sendable, Equatable, Hashable {
    public let archiveBaseName: String
    public let imageID: Int

    public init(archiveBaseName: String, imageID: Int) {
        self.archiveBaseName = archiveBaseName
        self.imageID = imageID
    }
}

public struct FigureSpriteAnimation: Sendable, Equatable, Hashable {
    public let role: TutorialFigureRole
    public let figureID: Int
    public let archiveBaseName: String
    public let sourceBitmapName: String
    public let logicalGroupID: Int
    public let framesByDirection: [[Int]]

    public init(
        role: TutorialFigureRole,
        figureID: Int,
        archiveBaseName: String,
        sourceBitmapName: String,
        logicalGroupID: Int,
        firstImageID: Int,
        framesPerDirection: Int
    ) {
        self.role = role
        self.figureID = figureID
        self.archiveBaseName = archiveBaseName
        self.sourceBitmapName = sourceBitmapName
        self.logicalGroupID = logicalGroupID
        framesByDirection = FigureMovementDirection.allCases.map { direction in
            let start = firstImageID + direction.rawValue * framesPerDirection
            return Array(start..<(start + framesPerDirection))
        }
    }

    public func reference(
        direction: FigureMovementDirection,
        tickSequence: Int,
        stableFigureID: Int
    ) -> FigureSpriteReference {
        let frames = framesByDirection[direction.rawValue]
        let frameIndex = abs(tickSequence &+ stableFigureID) % frames.count
        return FigureSpriteReference(
            archiveBaseName: archiveBaseName,
            imageID: frames[frameIndex]
        )
    }

    public var imageIDs: Set<Int> {
        Set(framesByDirection.flatMap { $0 })
    }
}

/// The deliberately small, verified catalog needed by Xia tutorial mission 1.
/// Each entry starts at an SG3 logical animation boundary and covers eight
/// contiguous directions. The adjacent source-record names and exported
/// contact sheets are inspectable with `emperor-inspect sg3-figure`.
public enum OriginalFigureSpriteCatalog {
    public static let mainArchiveBaseName = "SprMain"
    public static let meatCommodityID = 4

    /// `Gen_Transport` stores one 16-frame, eight-direction family per cargo.
    /// Logical group 127 (#7860) is the timber cart; hunting camps produce
    /// meat and therefore use logical group 130 (#7908).
    public static let meatDeliveryAnimation = FigureSpriteAnimation(
        role: .delivery,
        figureID: 22,
        archiveBaseName: mainArchiveBaseName,
        sourceBitmapName: "Gen_Transport",
        logicalGroupID: 130,
        firstImageID: 7_908,
        framesPerDirection: 2
    )

    public static let animations: [FigureSpriteAnimation] = [
        .init(
            role: .immigrant, figureID: 11, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Immigrant", logicalGroupID: 18,
            firstImageID: 1_097, framesPerDirection: 12
        ),
        .init(
            role: .delivery, figureID: 22, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Gen_Transport", logicalGroupID: 127,
            firstImageID: 7_860, framesPerDirection: 2
        ),
        .init(
            role: .peddler, figureID: 23, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Peddler", logicalGroupID: 0,
            firstImageID: 1, framesPerDirection: 12
        ),
        .init(
            role: .buyer, figureID: 24, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "FoodVendor", logicalGroupID: 35,
            firstImageID: 2_217, framesPerDirection: 12
        ),
        .init(
            role: .waterBearer, figureID: 28, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "WaterBearer", logicalGroupID: 84,
            firstImageID: 5_586, framesPerDirection: 12
        ),
        .init(
            role: .ancestorPriest, figureID: 35, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Priest", logicalGroupID: 111,
            firstImageID: 7_528, framesPerDirection: 12
        ),
        .init(
            role: .inspector, figureID: 39, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Inspector", logicalGroupID: 8,
            firstImageID: 433, framesPerDirection: 12
        ),
    ]

    public static func animation(forFigureID figureID: Int) -> FigureSpriteAnimation? {
        animations.first { $0.figureID == figureID }
    }

    public static func animation(for role: TutorialFigureRole) -> FigureSpriteAnimation? {
        animations.first { $0.role == role }
    }

    public static func deliveryAnimation(forCommodityID commodityID: Int) -> FigureSpriteAnimation? {
        if commodityID == meatCommodityID {
            return meatDeliveryAnimation
        }
        return animation(for: .delivery)
    }

    public static var requiredImageIDsByArchive: [String: Set<Int>] {
        Dictionary(
            grouping: animations + [meatDeliveryAnimation],
            by: \.archiveBaseName
        ).mapValues { items in
            items.reduce(into: Set<Int>()) { $0.formUnion($1.imageIDs) }
        }
    }
}
