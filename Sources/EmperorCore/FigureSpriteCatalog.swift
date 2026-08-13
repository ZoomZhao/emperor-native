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
    case watchman
    case ancestorPriest
    case inspector
    case taxOfficial
    case herbalist
    case acupuncturist
    case acrobat
    case actor
    case musician
    case chineseInfantry
    case chineseCrossbow
    case chineseCavalry
    case chineseCatapult
    case xiongnuInfantry
    case ambientPheasant
    case grandCanalLaborerTraveling
    case grandCanalLaborerWorking
    case grandCanalLaborerReturning
    case grandCanalStoneCarrier
    case grandCanalStoneFirstFollower
    case grandCanalStoneSecondFollower
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

    public func reference(
        direction: FigureMovementDirection,
        frameIndex: Int
    ) -> FigureSpriteReference {
        let frames = framesByDirection[direction.rawValue]
        let normalizedFrame = ((frameIndex % frames.count) + frames.count) % frames.count
        return FigureSpriteReference(
            archiveBaseName: archiveBaseName,
            imageID: frames[normalizedFrame]
        )
    }

    public var imageIDs: Set<Int> {
        Set(framesByDirection.flatMap { $0 })
    }
}

/// Verified original figure animations used by the native city simulation.
/// Each walking entry starts at an SG3 logical animation boundary and covers
/// eight contiguous directions. The adjacent source-record names and exported
/// contact sheets are inspectable with `emperor-inspect sg3-figure`.
public enum OriginalFigureSpriteCatalog {
    public static let mainArchiveBaseName = "SprMain"
    public static let main2ArchiveBaseName = "SprMain2"
    public static let xiongnuArchiveBaseName = "China_Xiongnu"
    public static let meatCommodityID = 4
    public static let clayCommodityID = 18
    public static let woodCommodityID = 10

    /// Deliveryman cargo families occupy contiguous SG3 logical groups starting
    /// at `Cart` #113. Trade commodity IDs from `Trade.txt` map as
    /// `logicalGroup = 112 + commodityID` (Meat #4 → #116 / first image #7684;
    /// Clay #18 → #130 / #7908). Groups 113...126 live in `Cart`; 127... continue
    /// in `Gen_Transport`.
    public static let deliveryLogicalGroupBase = 112

    /// First image ID of each delivery family, keyed by Trade.txt commodity ID.
    /// Stone (#20) uses 3 frames/direction; Dinners (#28) uses 8; all others use 2.
    public static let deliveryFirstImageIDByCommodityID: [Int: Int] = [
        1: 7_636, 2: 7_652, 3: 7_668, 4: 7_684, 5: 7_700, 6: 7_716, 7: 7_732,
        8: 7_748, 9: 7_764, 10: 7_780, 11: 7_796, 12: 7_812, 13: 7_828, 14: 7_844,
        15: 7_860, 16: 7_876, 17: 7_892, 18: 7_908, 19: 7_924, 20: 7_940, 21: 7_964,
        22: 7_980, 23: 7_996, 24: 8_012, 25: 8_028, 26: 8_044, 27: 8_060, 28: 8_076,
    ]

    public static let xiongnuInfantryAnimation = FigureSpriteAnimation(
        role: .xiongnuInfantry,
        figureID: 6,
        archiveBaseName: xiongnuArchiveBaseName,
        sourceBitmapName: "Xiongnu_Infantry",
        logicalGroupID: 0,
        firstImageID: 1,
        framesPerDirection: 12
    )

    /// Ambient prey use the original Pheasant bitmap rather than a marker.
    /// The model table names figure 76 `Pheasant`; `emperor-inspect
    /// sg3-figure SprMain.sg3 pheasant` resolves it to logical group 42 and
    /// image IDs #2657...#2752 (eight directions, twelve frames each).
    public static let pheasantAnimation = FigureSpriteAnimation(
        role: .ambientPheasant,
        figureID: 76,
        archiveBaseName: mainArchiveBaseName,
        sourceBitmapName: "pheasant",
        logicalGroupID: 42,
        firstImageID: 2_657,
        framesPerDirection: 12
    )

    /// Ordinary Grand Canal stone convoy selected by the hash-matched
    /// executable for commodity 20. These are not the type-table defaults.
    public static let grandCanalStoneCarrierAnimation = FigureSpriteAnimation(
        role: .grandCanalStoneCarrier,
        figureID: 19,
        archiveBaseName: mainArchiveBaseName,
        sourceBitmapName: "TeamLeader",
        logicalGroupID: 165,
        firstImageID: 9_743,
        framesPerDirection: 12
    )

    public static let grandCanalStoneFirstFollowerAnimation = FigureSpriteAnimation(
        role: .grandCanalStoneFirstFollower,
        figureID: 20,
        archiveBaseName: main2ArchiveBaseName,
        sourceBitmapName: "WaterBuffaloSolo",
        logicalGroupID: 55,
        firstImageID: 2_234,
        framesPerDirection: 12
    )

    public static let grandCanalStoneSecondFollowerAnimation = FigureSpriteAnimation(
        role: .grandCanalStoneSecondFollower,
        figureID: 20,
        archiveBaseName: main2ArchiveBaseName,
        sourceBitmapName: "WaterBuffaloCart",
        logicalGroupID: 135,
        firstImageID: 7_033,
        framesPerDirection: 12
    )

    /// Figure 10 monument-laborer states selected by `FUN_004D6060` in the
    /// hash-matched executable. Raw states 12/13 use key 0x4C58, state 14
    /// uses 0x4C5B, and states 15/16 use 0x4C59.
    public static let grandCanalLaborerTravelingAnimation = FigureSpriteAnimation(
        role: .grandCanalLaborerTraveling,
        figureID: 10,
        archiveBaseName: mainArchiveBaseName,
        sourceBitmapName: "Laborer",
        logicalGroupID: 87,
        firstImageID: 5_786,
        framesPerDirection: 12
    )

    public static let grandCanalLaborerWorkingAnimation = FigureSpriteAnimation(
        role: .grandCanalLaborerWorking,
        figureID: 10,
        archiveBaseName: mainArchiveBaseName,
        sourceBitmapName: "Laborer",
        logicalGroupID: 90,
        firstImageID: 6_074,
        framesPerDirection: 19
    )

    public static let grandCanalLaborerReturningAnimation = FigureSpriteAnimation(
        role: .grandCanalLaborerReturning,
        figureID: 10,
        archiveBaseName: mainArchiveBaseName,
        sourceBitmapName: "Laborer",
        logicalGroupID: 88,
        firstImageID: 5_882,
        framesPerDirection: 12
    )

    public static func grandCanalLaborerAnimation(
        forRawState rawState: Int
    ) -> FigureSpriteAnimation? {
        switch rawState {
        case 12, 13: return grandCanalLaborerTravelingAnimation
        case 14: return grandCanalLaborerWorkingAnimation
        case 15, 16: return grandCanalLaborerReturningAnimation
        default: return nil
        }
    }

    public static func deliveryLogicalGroupID(forCommodityID commodityID: Int) -> Int? {
        guard deliveryFirstImageIDByCommodityID[commodityID] != nil else { return nil }
        return deliveryLogicalGroupBase + commodityID
    }

    public static func deliveryFramesPerDirection(forCommodityID commodityID: Int) -> Int {
        switch commodityID {
        case 20: return 3
        case 28: return 8
        default: return 2
        }
    }

    public static func deliverySourceBitmapName(forLogicalGroupID logicalGroupID: Int) -> String {
        logicalGroupID <= 126 ? "Cart" : "Gen_Transport"
    }

    private static func transportAnimation(
        logicalGroupID: Int,
        firstImageID: Int,
        framesPerDirection: Int
    ) -> FigureSpriteAnimation {
        FigureSpriteAnimation(
            role: .delivery,
            figureID: 22,
            archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: deliverySourceBitmapName(forLogicalGroupID: logicalGroupID),
            logicalGroupID: logicalGroupID,
            firstImageID: firstImageID,
            framesPerDirection: framesPerDirection
        )
    }

    public static func makeDeliveryAnimation(forCommodityID commodityID: Int) -> FigureSpriteAnimation? {
        guard let firstImageID = deliveryFirstImageIDByCommodityID[commodityID],
              let logicalGroupID = deliveryLogicalGroupID(forCommodityID: commodityID) else {
            return nil
        }
        return transportAnimation(
            logicalGroupID: logicalGroupID,
            firstImageID: firstImageID,
            framesPerDirection: deliveryFramesPerDirection(forCommodityID: commodityID)
        )
    }

    public static let meatDeliveryAnimation = makeDeliveryAnimation(forCommodityID: meatCommodityID)!

    public static let deliveryAnimationsByCommodityID: [Int: FigureSpriteAnimation] = {
        Dictionary(uniqueKeysWithValues: deliveryFirstImageIDByCommodityID.keys.map { commodityID in
            (commodityID, makeDeliveryAnimation(forCommodityID: commodityID)!)
        })
    }()

    public static let animations: [FigureSpriteAnimation] = [
        .init(
            role: .immigrant, figureID: 11, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Immigrant", logicalGroupID: 18,
            firstImageID: 1_097, framesPerDirection: 12
        ),
        .init(
            role: .delivery, figureID: 22, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Cart", logicalGroupID: 122,
            firstImageID: 7_780, framesPerDirection: 2
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
            role: .watchman, figureID: 29, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Watchman", logicalGroupID: 26,
            firstImageID: 1_521, framesPerDirection: 12
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
        .init(
            role: .taxOfficial, figureID: 27, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Clerk", logicalGroupID: 64,
            firstImageID: 4_425, framesPerDirection: 12
        ),
        .init(
            role: .herbalist, figureID: 30, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "herbalist", logicalGroupID: 29,
            firstImageID: 1_813, framesPerDirection: 12
        ),
        .init(
            role: .acupuncturist, figureID: 31, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Acupuncturist", logicalGroupID: 2,
            firstImageID: 109, framesPerDirection: 12
        ),
        .init(
            role: .acrobat, figureID: 32, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Acrobat", logicalGroupID: 147,
            firstImageID: 8_541, framesPerDirection: 12
        ),
        .init(
            role: .actor, figureID: 33, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Actor", logicalGroupID: 106,
            firstImageID: 7_205, framesPerDirection: 12
        ),
        .init(
            role: .musician, figureID: 34, archiveBaseName: mainArchiveBaseName,
            sourceBitmapName: "Musician", logicalGroupID: 102,
            firstImageID: 7_076, framesPerDirection: 12
        ),
        .init(
            role: .chineseInfantry, figureID: 64, archiveBaseName: main2ArchiveBaseName,
            sourceBitmapName: "Chinese_InfantryMan", logicalGroupID: 169,
            firstImageID: 9_990, framesPerDirection: 12
        ),
        .init(
            role: .chineseCrossbow, figureID: 65, archiveBaseName: main2ArchiveBaseName,
            sourceBitmapName: "Chinese_CrossbowMan", logicalGroupID: 165,
            firstImageID: 9_606, framesPerDirection: 12
        ),
        .init(
            role: .chineseCavalry, figureID: 66, archiveBaseName: main2ArchiveBaseName,
            sourceBitmapName: "Chinese_Cavalry", logicalGroupID: 159,
            firstImageID: 8_970, framesPerDirection: 12
        ),
        .init(
            role: .chineseCatapult, figureID: 68, archiveBaseName: main2ArchiveBaseName,
            sourceBitmapName: "Chinese_Catapult", logicalGroupID: 154,
            firstImageID: 8_558, framesPerDirection: 12
        ),
        pheasantAnimation,
    ]

    /// Context-selected families that must not become generic figure-ID
    /// defaults. Type 19/20 use other resource groups outside stone convoys.
    public static let specializedAnimations = [
        grandCanalLaborerTravelingAnimation,
        grandCanalLaborerWorkingAnimation,
        grandCanalLaborerReturningAnimation,
        grandCanalStoneCarrierAnimation,
        grandCanalStoneFirstFollowerAnimation,
        grandCanalStoneSecondFollowerAnimation,
    ]

    public static func animation(forFigureID figureID: Int) -> FigureSpriteAnimation? {
        animations.first { $0.figureID == figureID }
    }

    public static func animation(for role: TutorialFigureRole) -> FigureSpriteAnimation? {
        animations.first { $0.role == role }
    }

    public static func animation(forEnemyTypeID enemyTypeID: Int) -> FigureSpriteAnimation? {
        switch enemyTypeID {
        case 6: xiongnuInfantryAnimation
        default: nil
        }
    }

    public static func deliveryAnimation(forCommodityID commodityID: Int) -> FigureSpriteAnimation? {
        deliveryAnimationsByCommodityID[commodityID] ?? animation(for: .delivery)
    }

    public static var requiredImageIDsByArchive: [String: Set<Int>] {
        Dictionary(
            grouping: animations
                + Array(deliveryAnimationsByCommodityID.values)
                + [xiongnuInfantryAnimation]
                + specializedAnimations,
            by: \.archiveBaseName
        ).mapValues { items in
            items.reduce(into: Set<Int>()) { $0.formUnion($1.imageIDs) }
        }
    }
}
