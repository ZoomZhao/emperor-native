import Foundation

public enum IsometricBuildingOrientation: Int, CaseIterable, Sendable, Hashable, Codable {
    case northSouth
    case eastWest
}

public struct BuildingSpriteReference: Sendable, Equatable, Hashable {
    public let archiveBaseName: String
    public let imageID: Int

    public init(archiveBaseName: String, imageID: Int) {
        self.archiveBaseName = archiveBaseName
        self.imageID = imageID
    }
}

/// One independently depth-sorted part of an original building. Most
/// structures use a single square isometric sprite, while warehouses and
/// markets are assembled from the same one- and two-tile pieces used by the
/// Windows renderer.
public struct BuildingSpriteComponent: Sendable, Equatable, Hashable {
    public let sprite: BuildingSpriteReference
    public let tileOffsetX: Int
    public let tileOffsetY: Int
    public let footprint: BuildingFootprint

    public init(
        sprite: BuildingSpriteReference,
        tileOffsetX: Int,
        tileOffsetY: Int,
        footprint: BuildingFootprint
    ) {
        self.sprite = sprite
        self.tileOffsetX = tileOffsetX
        self.tileOffsetY = tileOffsetY
        self.footprint = footprint
    }

    public func origin(relativeTo buildingOrigin: GridPoint) -> GridPoint {
        GridPoint(
            x: buildingOrigin.x + tileOffsetX,
            y: buildingOrigin.y + tileOffsetY
        )
    }
}

public enum OriginalBuildingSpriteCatalog {
    public static let generalArchiveBaseName = "China_General"
    public static let grandCanalArchiveBaseName = "China_Mon_Grand_Canal"
    public static let tumulusArchiveBaseName = "China_Mon_Tumulus"
    public static let vacantCommonHouseImageID = 1_508
    public static let vacantEliteHouseImageID = 1_525

    public static let emptyWarehouseBayImageID = 1_317
    public static let foodWarehouseBayImageID = 1_101
    /// Logical group 37 in `China_General.sg3`: the dedicated office/crane
    /// tile at the center of the original land trading station.
    public static let tradingStationOfficeImageID = 645
    /// Logical group 38: four water-edge variants of the 2×2 quay house and
    /// their matching one-tile timber deck pieces.
    public static let quayHouseImageIDs: [QuayWaterEdge: Int] = [
        .north: 636, .east: 637, .south: 638, .west: 639,
    ]
    public static let quayDeckImageIDs: [QuayWaterEdge: Int] = [
        .north: 640, .east: 641, .south: 642, .west: 643,
    ]
    public static let foodShopImageID = 611
    public static let shopImageIDByBuildingID: [Int: Int] = [
        64: 627, // Bronzeware
        65: 617, // Ceramics
        66: foodShopImageID,
        67: 619, // Hemp
        68: 621, // Lacquerware
        69: 623, // Silk
        70: 625, // Tea
    ]
    public static let marketEntertainmentAreaImageID = 629
    public static let marketTileImageIDs = [632, 633, 634, 635]
    /// The shipping destruction archive contains five 50-frame fire families.
    /// These are the burning-ruin effects used per occupied tile; the previous
    /// `China_General` #2231 mapping was a frame from `China_Banners.bmp`.
    public static let destructionArchiveBaseName = "destruction"
    public static let operationsFireAnimationImageIDs: [[Int]] = [
        Array(201...250),
        Array(251...300),
        Array(301...350),
        Array(351...400),
        Array(401...450),
    ]
    /// Original model-table ID retained after a collapse so the footprint
    /// remains blocked until the player clears the ruins.
    public static let ruinBuildingID = 161
    public static let grandCanalStageImageIDs: Set<Int> = [201, 212, 224, 229, 232, 234, 238]
    public static let earthenGreatWallCutImageBase = 482

    public static func earthenGreatWallSprites(
        stage: Int,
        modeImageID: Int,
        cutVariant: Int
    ) -> [BuildingSpriteReference] {
        guard stage > 0 else { return [] }
        let archive = "China_Mon_Earthen_Greatwall_\(min(stage, 10))"
        var references = [
            BuildingSpriteReference(archiveBaseName: archive, imageID: modeImageID),
        ]
        if stage < EarthenGreatWallProjectRuntime.finalStage {
            references.append(BuildingSpriteReference(
                archiveBaseName: tumulusArchiveBaseName,
                imageID: earthenGreatWallCutImageBase + cutVariant
            ))
        }
        return references
    }

    public static func grandCanalSprite(
        stage: Int,
        isRoadCrossing: Bool
    ) -> BuildingSpriteReference? {
        guard stage > 0 else { return nil }
        let imageID: Int
        if isRoadCrossing {
            imageID = switch stage {
            case 1: 212
            case 2: 234
            default: 238
            }
        } else {
            imageID = switch stage {
            case 1: 212
            case 2: 224
            case 3: 229
            default: 232
            }
        }
        return BuildingSpriteReference(
            archiveBaseName: grandCanalArchiveBaseName,
            imageID: imageID
        )
    }

    /// Returns only phase sprites whose original frame mapping is verified.
    /// The grand-tumulus ramp family is a complete four-direction group.
    /// Other mausoleum sub-buildings retain their authored phase state but
    /// deliberately do not guess an image until the Windows visual comparison
    /// resolves their elevation/orientation lookup.
    public static func phasedMonumentSubBuildingSprite(
        buildingID: Int,
        subBuilding: PhasedMonumentSubBuilding,
        currentSubBuildingPhase: Int
    ) -> BuildingSpriteReference? {
        guard currentSubBuildingPhase > 0,
              buildingID == 77,
              subBuilding.kind == "SB_TUMULUS_RAMP" else {
            return nil
        }
        let directionOffset: Int
        switch subBuilding.orientation {
        case "NORTH": directionOffset = 0
        case "EAST": directionOffset = 1
        case "SOUTH": directionOffset = 2
        case "WEST": directionOffset = 3
        default: return nil
        }
        return BuildingSpriteReference(
            archiveBaseName: tumulusArchiveBaseName,
            imageID: 371 + directionOffset
        )
    }

    /// Building IDs currently constructible on the native isometric canvas.
    /// Keeping this list in the core makes the asynchronous sprite loader and
    /// archive validation tests consume exactly the same catalog.
    public static let supportedPlacedBuildingIDs = [
        26, 27, 28,
        31, 33, 35, 36, 38, 39, 40, 42, 43, 46, 52, 53, 54, 56, 58, 59, 60, 72,
        77, 82, 84,
        110, 124, 125,
        115, 116, 117, 118, 119, 126, 127, 129, 130, 131,
        194, 195, 196, 197, 198, 199, 203,
        207, 208, 209, 211, 212, 213, 214, 215, 216, 217, 218, 219,
        220, 221, 223, 224,
        226, 233, 235, 236, 237, 238,
    ]

    /// First mature-stage frame from each authored `China_Fields.bmp`
    /// logical group. These are crop plots, not the similarly numbered
    /// farmhouse/shed structures.
    public static func agriculturalPlotSprite(
        for crop: AgriculturalCrop
    ) -> BuildingSpriteReference {
        BuildingSpriteReference(
            archiveBaseName: generalArchiveBaseName,
            imageID: agriculturalPlotImageID(for: crop)
        )
    }

    public static func agriculturalPlotImageID(for crop: AgriculturalCrop) -> Int {
        switch crop {
        case .wheat: 2_410
        case .millet: 2_422
        case .soybeans: 2_434
        case .cabbage: 2_446
        case .hemp: 2_458
        case .tea: 2_470
        case .mulberry: 2_482
        case .lacquer: 2_494
        case .rice: 2_506
        }
    }

    public static func housingBuildingID(forHouseLevelID levelID: Int) -> Int? {
        guard (0...14).contains(levelID) else { return nil }
        return levelID + 3
    }

    public static func housingSprite(
        forHouseLevelID levelID: Int,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> BuildingSpriteReference? {
        guard let buildingID = housingBuildingID(forHouseLevelID: levelID) else { return nil }
        return housingSprite(forBuildingID: buildingID, orientation: orientation)
    }

    public static func housingSprite(
        forBuildingID buildingID: Int,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> BuildingSpriteReference? {
        let imageID: Int
        switch buildingID {
        case 2:
            imageID = vacantCommonHouseImageID
        case 3...10:
            imageID = 1_509 + (buildingID - 3) * 2 + orientation.rawValue
        case 11:
            imageID = vacantEliteHouseImageID
        case 12...17:
            imageID = 1_526 + (buildingID - 12) * 2 + orientation.rawValue
        default:
            return nil
        }
        return BuildingSpriteReference(archiveBaseName: generalArchiveBaseName, imageID: imageID)
    }

    /// Primary, fully-authored isometric sprite for a non-composite building.
    /// The image IDs are the first images of the corresponding logical groups
    /// in the original `China_General.sg3` header.
    public static func buildingSprite(
        forBuildingID buildingID: Int,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> BuildingSpriteReference? {
        switch buildingID {
        case 77:
            return BuildingSpriteReference(
                archiveBaseName: tumulusArchiveBaseName,
                imageID: 201
            )
        case 82:
            return BuildingSpriteReference(
                archiveBaseName: grandCanalArchiveBaseName,
                imageID: 272
            )
        case 84:
            return BuildingSpriteReference(
                archiveBaseName: tumulusArchiveBaseName,
                imageID: 376
            )
        default:
            break
        }
        let imageID: Int
        switch buildingID {
        case 26: imageID = agriculturalPlotImageID(for: .tea)
        case 27: imageID = agriculturalPlotImageID(for: .lacquer)
        case 28: imageID = agriculturalPlotImageID(for: .mulberry)
        case 31: imageID = 721   // Fishing quay
        case 33: imageID = 825   // Hunter's tent, China_Husbandry SG3 group 1791
        case 35: imageID = 2_789 // Clay pit
        case 36: imageID = 2_741 // Stoneworks
        case 38: imageID = 2_726 // Logging shed
        case 39: imageID = 2_697 // Bronze smelter
        case 40: imageID = 2_698 // Iron smelter
        case 42: imageID = 2_750 // Bronzeware maker
        case 43: imageID = 2_788 // Kiln
        case 46: imageID = 2_832 // Jade carver's studio
        case 52: imageID = 2_310 // Carpenters' guild
        case 53: imageID = 647   // Mill
        case 72: imageID = 1_559 // Well
        case 115: imageID = 201 // Gardens
        case 116: imageID = 209 // Decorative sculpture
        case 117: imageID = 225 // Ornate sculpture
        case 118: imageID = 241 // Flowering tree
        case 119: imageID = 250 // Wayside pavilion
        case 124: imageID = 1_704 // Inspector's tower, China_Safety logical group 137
        case 126: imageID = 2_046 // One-tile roadblock sign, China_Government2 logical group 146
        case 127: imageID = 1_618 // Watchtower, China_Safety logical group 134
        case 129: imageID = orientation == .northSouth ? 892 : 917 // City wall
        case 131: imageID = 879 // Staffed city-wall tower
        case 125: imageID = 1_908 // Tax office
        case 207: imageID = 1_580 // Herbalist's stall
        case 208: imageID = 1_593 // Acupuncturist's clinic
        case 211: imageID = 589   // Music school
        case 212: imageID = 460   // Acrobat school
        case 213: imageID = 501   // Drama school
        case 214: imageID = 2_232 // Ancestral shrine
        case 215: imageID = 2_245 // Daoist shrine
        case 216: imageID = 2_271 // Daoist temple
        case 217: imageID = 2_258 // Buddhist shrine
        case 218: imageID = 2_296 // Buddhist pagoda
        case 219: imageID = 2_309 // Confucian academy
        case 220, 221, 223, 224: imageID = 954 // Verified shared military fort HQ
        case 226: imageID = 918 // Weaponsmith
        case 233: imageID = 2_373 // Laborers' camp
        case 235: imageID = 2_331 // Masons' guild
        case 236: imageID = 2_352 // Ceramists' guild
        case 237: imageID = 812 // Tea curing shed
        case 238: imageID = 840 // Lacquer refinery
        case 194: imageID = agriculturalPlotImageID(for: .hemp)
        case 195: imageID = agriculturalPlotImageID(for: .wheat)
        case 196: imageID = agriculturalPlotImageID(for: .millet)
        case 197: imageID = agriculturalPlotImageID(for: .rice)
        case 198: imageID = agriculturalPlotImageID(for: .cabbage)
        case 199: imageID = agriculturalPlotImageID(for: .soybeans)
        default: return nil
        }
        return BuildingSpriteReference(
            archiveBaseName: generalArchiveBaseName,
            imageID: imageID
        )
    }

    /// Representative sprite shown in the construction catalog. Composite
    /// buildings normally use their first authored component, except markets:
    /// their component list starts with one-tile paving, which is not a useful
    /// or recognizable menu icon. Use the original food-shop centerpiece.
    public static func constructionCatalogSprite(
        forBuildingID buildingID: Int,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> BuildingSpriteReference? {
        if buildingID == 59 || buildingID == 60 {
            return BuildingSpriteReference(
                archiveBaseName: generalArchiveBaseName,
                imageID: foodShopImageID
            )
        }
        if let shopImageID = shopImageIDByBuildingID[buildingID] {
            return BuildingSpriteReference(
                archiveBaseName: generalArchiveBaseName,
                imageID: shopImageID
            )
        }
        return buildingComponents(
            forBuildingID: buildingID,
            orientation: orientation
        ).first?.sprite
    }

    public static func buildingComponents(
        forBuildingID buildingID: Int,
        orientation: IsometricBuildingOrientation = .northSouth,
        quayWaterEdge: QuayWaterEdge? = nil
    ) -> [BuildingSpriteComponent] {
        guard let canonicalFootprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID
        ) else { return [] }

        let canonical: [BuildingSpriteComponent]
        switch buildingID {
        case 203:
            let edge = quayWaterEdge
                ?? (orientation == .northSouth ? .north : .east)
            let imageID = switch edge {
            case .north: 761
            case .west: 777
            case .east: 745
            case .south: 729
            }
            canonical = [BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: imageID
                ),
                tileOffsetX: 0,
                tileOffsetY: 0,
                footprint: canonicalFootprint
            )]
        case 54:
            canonical = warehouseComponents(footprint: canonicalFootprint)
        case 56:
            canonical = quayComponents(
                footprint: canonicalFootprint,
                waterEdge: quayWaterEdge ?? (orientation == .northSouth ? .north : .east)
            )
        case 58:
            canonical = tradingStationComponents(footprint: canonicalFootprint)
        case 59, 60:
            canonical = marketComponents(footprint: canonicalFootprint)
        case 110:
            return palaceComponents(orientation: orientation)
        case 130:
            return gatehouseComponents(orientation: orientation)
        case 209:
            return administrativeCityComponents(orientation: orientation)
        case 220, 221, 223, 224:
            guard let sprite = buildingSprite(
                forBuildingID: buildingID,
                orientation: orientation
            ) else { return [] }
            // The verified #954 family is the 2×2 headquarters inside the
            // fort's authored 4×4 courtyard, not a bitmap spanning every
            // occupied fort tile.
            canonical = [BuildingSpriteComponent(
                sprite: sprite,
                tileOffsetX: 1,
                tileOffsetY: 1,
                footprint: BuildingFootprint(width: 2, height: 2)
            )]
        default:
            guard let sprite = buildingSprite(
                forBuildingID: buildingID,
                orientation: orientation
            ) else { return [] }
            canonical = [BuildingSpriteComponent(
                sprite: sprite,
                tileOffsetX: 0,
                tileOffsetY: 0,
                footprint: canonicalFootprint
            )]
        }

        // A quay uses four edge-specific source sprites and component origins;
        // applying the generic rectangular rotation would rotate it twice.
        guard buildingID != 56, orientation == .eastWest else { return canonical }
        return canonical.map { component in
            BuildingSpriteComponent(
                sprite: component.sprite,
                tileOffsetX: canonicalFootprint.height
                    - component.tileOffsetY
                    - component.footprint.height,
                tileOffsetY: component.tileOffsetX,
                footprint: BuildingFootprint(
                    width: component.footprint.height,
                    height: component.footprint.width
                )
            )
        }
    }

    public static var requiredImageIDsByArchive: [String: Set<Int>] {
        var references = Set((0...14).flatMap { levelID in
            IsometricBuildingOrientation.allCases.compactMap {
                housingSprite(forHouseLevelID: levelID, orientation: $0)
            }
        })
        for buildingID in supportedPlacedBuildingIDs {
            for orientation in IsometricBuildingOrientation.allCases {
                references.formUnion(
                    buildingComponents(
                        forBuildingID: buildingID,
                        orientation: orientation
                    ).map(\.sprite)
                )
            }
            if buildingID == 203 {
                for edge in QuayWaterEdge.allCases {
                    references.formUnion(
                        buildingComponents(
                            forBuildingID: buildingID,
                            quayWaterEdge: edge
                        ).map(\.sprite)
                    )
                }
            }
        }
        references.formUnion(quayHouseImageIDs.values.map {
            BuildingSpriteReference(archiveBaseName: generalArchiveBaseName, imageID: $0)
        })
        references.formUnion(quayDeckImageIDs.values.map {
            BuildingSpriteReference(archiveBaseName: generalArchiveBaseName, imageID: $0)
        })
        references.formUnion(operationsFireAnimationImageIDs.joined().map {
            BuildingSpriteReference(
                archiveBaseName: destructionArchiveBaseName,
                imageID: $0
            )
        })
        references.formUnion(shopImageIDByBuildingID.values.map {
            BuildingSpriteReference(archiveBaseName: generalArchiveBaseName, imageID: $0)
        })
        references.formUnion(grandCanalStageImageIDs.map {
            BuildingSpriteReference(
                archiveBaseName: grandCanalArchiveBaseName,
                imageID: $0
            )
        })
        for binding in EarthenGreatWallLayout.badalingMapBindings {
            for stage in 1...10 {
                references.insert(BuildingSpriteReference(
                    archiveBaseName: "China_Mon_Earthen_Greatwall_\(stage)",
                    imageID: binding.modeImageID
                ))
            }
        }
        references.formUnion(EarthenGreatWallLayout.original.segments.map {
            BuildingSpriteReference(
                archiveBaseName: tumulusArchiveBaseName,
                imageID: earthenGreatWallCutImageBase + $0.cutVariant
            )
        })
        references.formUnion((371...374).map {
            BuildingSpriteReference(
                archiveBaseName: tumulusArchiveBaseName,
                imageID: $0
            )
        })
        return Dictionary(grouping: references, by: \.archiveBaseName)
            .mapValues { Set($0.map(\.imageID)) }
    }

    public static var requiredImageIDs: Set<Int> {
        requiredImageIDsByArchive[generalArchiveBaseName, default: []]
    }

    private static func administrativeCityComponents(
        orientation: IsometricBuildingOrientation
    ) -> [BuildingSpriteComponent] {
        let size = BuildingFootprint(width: 4, height: 4)
        let specifications: [(Int, Int, Int)] = switch orientation {
        case .northSouth: [(1_904, 0, 0), (1_905, 0, 4)]
        case .eastWest: [(1_906, 0, 0), (1_907, 4, 0)]
        }
        return specifications.map { imageID, x, y in
            BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: imageID
                ),
                tileOffsetX: x,
                tileOffsetY: y,
                footprint: size
            )
        }
    }

    private static func palaceComponents(
        orientation: IsometricBuildingOrientation
    ) -> [BuildingSpriteComponent] {
        let size = BuildingFootprint(width: 5, height: 5)
        let specifications: [(Int, Int, Int)] = switch orientation {
        case .northSouth: [(1_930, 0, 0), (1_931, 0, 5)]
        case .eastWest: [(1_932, 0, 0), (1_933, 5, 0)]
        }
        return specifications.map { imageID, x, y in
            BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: imageID
                ),
                tileOffsetX: x,
                tileOffsetY: y,
                footprint: size
            )
        }
    }

    /// The original gatehouse is a five-piece wall assembly laid across the
    /// centre of its 5x3 (or rotated 3x5) reserved rectangle.
    private static func gatehouseComponents(
        orientation: IsometricBuildingOrientation
    ) -> [BuildingSpriteComponent] {
        let specifications: [(Int, Int, Int)] = switch orientation {
        case .northSouth:
            (898...902).enumerated().map { ($0.element, $0.offset, 1) }
        case .eastWest:
            (903...907).enumerated().map { ($0.element, 1, $0.offset) }
        }
        return specifications.map { imageID, x, y in
            BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: imageID
                ),
                tileOffsetX: x,
                tileOffsetY: y,
                footprint: BuildingFootprint(width: 1, height: 1)
            )
        }
    }

    private static func warehouseComponents(
        footprint: BuildingFootprint
    ) -> [BuildingSpriteComponent] {
        footprint.points(at: GridPoint(x: 0, y: 0)).map { point in
            let imageID = point.x == footprint.width / 2 && point.y == footprint.height / 2
                ? foodWarehouseBayImageID
                : emptyWarehouseBayImageID
            return BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: imageID
                ),
                tileOffsetX: point.x,
                tileOffsetY: point.y,
                footprint: BuildingFootprint(width: 1, height: 1)
            )
        }
    }

    /// The manual describes the station as 15 storage bays, but—as in the
    /// Windows renderer—the visible 3×3 footprint is assembled from storage
    /// tiles around one dedicated office/crane tile. Capacity remains a trade
    /// rule (60 loads), independent of the nine map tiles.
    private static func tradingStationComponents(
        footprint: BuildingFootprint
    ) -> [BuildingSpriteComponent] {
        footprint.points(at: GridPoint(x: 0, y: 0)).map { point in
            let isOffice = point.x == footprint.width / 2
                && point.y == footprint.height / 2
            return BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: isOffice ? tradingStationOfficeImageID : emptyWarehouseBayImageID
                ),
                tileOffsetX: point.x,
                tileOffsetY: point.y,
                footprint: BuildingFootprint(width: 1, height: 1)
            )
        }
    }

    private static func quayComponents(
        footprint: BuildingFootprint,
        waterEdge: QuayWaterEdge
    ) -> [BuildingSpriteComponent] {
        guard footprint == BuildingFootprint(width: 3, height: 3),
              let houseImageID = quayHouseImageIDs[waterEdge],
              let deckImageID = quayDeckImageIDs[waterEdge] else { return [] }
        let houseOrigin: GridPoint = switch waterEdge {
        case .north: GridPoint(x: 0, y: 0)
        case .east: GridPoint(x: 1, y: 0)
        case .south: GridPoint(x: 1, y: 1)
        case .west: GridPoint(x: 0, y: 1)
        }
        let houseFootprint = BuildingFootprint(width: 2, height: 2)
        let housePoints = Set(houseFootprint.points(at: houseOrigin))
        var components: [BuildingSpriteComponent] = footprint.points(
            at: GridPoint(x: 0, y: 0)
        ).compactMap { point -> BuildingSpriteComponent? in
            guard !housePoints.contains(point) else { return nil }
            return BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: deckImageID
                ),
                tileOffsetX: point.x,
                tileOffsetY: point.y,
                footprint: BuildingFootprint(width: 1, height: 1)
            )
        }
        components.append(BuildingSpriteComponent(
            sprite: BuildingSpriteReference(
                archiveBaseName: generalArchiveBaseName,
                imageID: houseImageID
            ),
            tileOffsetX: houseOrigin.x,
            tileOffsetY: houseOrigin.y,
            footprint: houseFootprint
        ))
        return components
    }

    private static func marketComponents(
        footprint: BuildingFootprint
    ) -> [BuildingSpriteComponent] {
        let foodOrigin = GridPoint(x: 0, y: 0)
        let entertainmentOrigin = GridPoint(
            x: footprint.width - 2,
            y: footprint.height - 2
        )
        let foodPoints = Set(BuildingFootprint(width: 2, height: 2).points(at: foodOrigin))
        let entertainmentPoints = Set(
            BuildingFootprint(width: 2, height: 2).points(at: entertainmentOrigin)
        )
        var components: [BuildingSpriteComponent] = footprint.points(
            at: GridPoint(x: 0, y: 0)
        ).compactMap { point in
            guard !foodPoints.contains(point), !entertainmentPoints.contains(point) else {
                return nil
            }
            let imageID = marketTileImageIDs[(point.x + point.y) % marketTileImageIDs.count]
            return BuildingSpriteComponent(
                sprite: BuildingSpriteReference(
                    archiveBaseName: generalArchiveBaseName,
                    imageID: imageID
                ),
                tileOffsetX: point.x,
                tileOffsetY: point.y,
                footprint: BuildingFootprint(width: 1, height: 1)
            )
        }
        components.append(BuildingSpriteComponent(
            sprite: BuildingSpriteReference(
                archiveBaseName: generalArchiveBaseName,
                imageID: foodShopImageID
            ),
            tileOffsetX: foodOrigin.x,
            tileOffsetY: foodOrigin.y,
            footprint: BuildingFootprint(width: 2, height: 2)
        ))
        components.append(BuildingSpriteComponent(
            sprite: BuildingSpriteReference(
                archiveBaseName: generalArchiveBaseName,
                imageID: marketEntertainmentAreaImageID
            ),
            tileOffsetX: entertainmentOrigin.x,
            tileOffsetY: entertainmentOrigin.y,
            footprint: BuildingFootprint(width: 2, height: 2)
        ))
        return components
    }
}
