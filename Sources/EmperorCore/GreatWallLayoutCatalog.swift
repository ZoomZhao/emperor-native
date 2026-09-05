import Foundation

/// Read-only state recovered from one original Great Wall
/// `cMonumentBldg` archive record. This preserves the authored multipart
/// object identity without implying that Native already simulates Great Wall
/// dispatch or campaign-goal completion.
public struct GreatWallMapPartState: Sendable, Hashable, Codable {
    public let worldOrigin: GridPoint
    public let mapCellIndex: Int
    public let buildingID: Int
    public let subBuildingIndex: Int
    public let baseBuildingSchema: Int
    public let monumentWrapperSchema: Int
    public let monumentStateSchema: Int
    public let currentSubBuildingPhase: Int
    public let wholeMonumentPhase: Int
    /// Current-phase figure updates stored at `cMonInfo+0x1C`. Labor task
    /// amounts and visible work duration are separate original counters.
    public private(set) var onSiteLaborerWorkUpdates: Int
    /// Commodity 10 delivered for the current Great Wall part phase.
    public private(set) var deliveredWoodUnits: Int
    /// Shared counter used by internal Great Wall tasks 100 and 101.
    public private(set) var completedInternalWorkUnits: Int
    /// Commodity 20 delivered for the current Great Wall part phase.
    public private(set) var deliveredStoneUnits: Int

    public init(
        worldOrigin: GridPoint,
        mapCellIndex: Int,
        buildingID: Int,
        subBuildingIndex: Int,
        baseBuildingSchema: Int,
        monumentWrapperSchema: Int,
        monumentStateSchema: Int,
        currentSubBuildingPhase: Int,
        wholeMonumentPhase: Int,
        onSiteLaborerWorkUpdates: Int = 0,
        deliveredWoodUnits: Int = 0,
        completedInternalWorkUnits: Int = 0,
        deliveredStoneUnits: Int = 0
    ) {
        self.worldOrigin = worldOrigin
        self.mapCellIndex = mapCellIndex
        self.buildingID = buildingID
        self.subBuildingIndex = subBuildingIndex
        self.baseBuildingSchema = baseBuildingSchema
        self.monumentWrapperSchema = monumentWrapperSchema
        self.monumentStateSchema = monumentStateSchema
        self.currentSubBuildingPhase = currentSubBuildingPhase
        self.wholeMonumentPhase = wholeMonumentPhase
        self.onSiteLaborerWorkUpdates = onSiteLaborerWorkUpdates
        self.deliveredWoodUnits = deliveredWoodUnits
        self.completedInternalWorkUnits = completedInternalWorkUnits
        self.deliveredStoneUnits = deliveredStoneUnits
    }

    private enum CodingKeys: String, CodingKey {
        case worldOrigin
        case mapCellIndex
        case buildingID
        case subBuildingIndex
        case baseBuildingSchema
        case monumentWrapperSchema
        case monumentStateSchema
        case currentSubBuildingPhase
        case wholeMonumentPhase
        case onSiteLaborerWorkUpdates
        case deliveredWoodUnits
        case completedInternalWorkUnits
        case deliveredStoneUnits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worldOrigin = try container.decode(GridPoint.self, forKey: .worldOrigin)
        mapCellIndex = try container.decode(Int.self, forKey: .mapCellIndex)
        buildingID = try container.decode(Int.self, forKey: .buildingID)
        subBuildingIndex = try container.decode(Int.self, forKey: .subBuildingIndex)
        baseBuildingSchema = try container.decode(Int.self, forKey: .baseBuildingSchema)
        monumentWrapperSchema = try container.decode(Int.self, forKey: .monumentWrapperSchema)
        monumentStateSchema = try container.decode(Int.self, forKey: .monumentStateSchema)
        currentSubBuildingPhase = try container.decode(
            Int.self,
            forKey: .currentSubBuildingPhase
        )
        wholeMonumentPhase = try container.decode(Int.self, forKey: .wholeMonumentPhase)
        // Saves written before the schema-10 counters were surfaced retain
        // the same original archive meaning: absent Native fields decode as 0.
        onSiteLaborerWorkUpdates = try container.decodeIfPresent(
            Int.self,
            forKey: .onSiteLaborerWorkUpdates
        ) ?? 0
        deliveredWoodUnits = try container.decodeIfPresent(
            Int.self,
            forKey: .deliveredWoodUnits
        ) ?? 0
        completedInternalWorkUnits = try container.decodeIfPresent(
            Int.self,
            forKey: .completedInternalWorkUnits
        ) ?? 0
        deliveredStoneUnits = try container.decodeIfPresent(
            Int.self,
            forKey: .deliveredStoneUnits
        ) ?? 0
    }

    /// Applies cargo through the shared monument target-transfer contract at
    /// `FUN_00571DA0`. The current vtable requirement determines both the
    /// commodity and the exact remaining capacity; excess stays on the
    /// carrier. Internal-work requirements cannot accept commodity cargo.
    @discardableResult
    public mutating func acceptCommodityCargo(
        _ cargoUnits: Int,
        for requirement: OriginalGreatWallLayoutCatalog.PhaseRequirement
    ) -> Int {
        guard cargoUnits > 0,
              requirement.subBuildingIndex == subBuildingIndex,
              requirement.phase == currentSubBuildingPhase,
              case let .commodity(commodityID) = requirement.kind else {
            return max(0, cargoUnits)
        }
        let delivered: Int
        switch commodityID {
        case 10:
            delivered = deliveredWoodUnits
        case 20:
            delivered = deliveredStoneUnits
        default:
            return cargoUnits
        }
        let accepted = min(cargoUnits, max(0, requirement.amount - delivered))
        switch commodityID {
        case 10:
            deliveredWoodUnits += accepted
        case 20:
            deliveredStoneUnits += accepted
        default:
            break
        }
        return cargoUnits - accepted
    }
}

/// Executable-confirmed crosswalk for the sixteen original Great Wall
/// construction selectors.
///
/// `FUN_00564880 @ 0x564880` loads these exact building IDs and files through
/// `FUN_00567650 @ 0x567650`. The original map-editor creation path creates
/// the complete multi-part layout described by a selected ID; the IDs are not
/// construction stages or aliases for advancing an existing wall segment.
/// `FUN_00402A50 @ 0x402A50` leaves them unavailable in ordinary campaign
/// cities, whose Great Wall objects are instead predetermined by the map.
public enum OriginalGreatWallLayoutCatalog {
    public enum SubBuildingKind: String, Sendable, Hashable, Codable {
        case wall = "SB_GREAT_WALL"
        case gate = "SB_GREAT_WALL_GATE"
        case tower = "SB_GREAT_WALL_TOWER"
        case road = "SB_GREAT_WALL_ROAD"

        public var footprintSide: Int {
            switch self {
            case .wall, .tower: 4
            case .gate: 2
            case .road: 1
            }
        }
    }

    public struct TargetAccessCandidate: Sendable, Hashable, Codable {
        public let subBuildingIndex: Int
        public let worldOrigin: GridPoint
        public let roadAccessPoint: GridPoint
    }

    public enum WallKind: Sendable, Hashable {
        case earthen
        case stone
    }

    /// One original Great Wall draw result: the SG3 family selected by wall
    /// mode and phase, plus the local image returned by the part vtable.
    public struct SpriteReference: Sendable, Hashable, Codable {
        public let archiveBaseName: String
        public let imageID: Int

        public init(archiveBaseName: String, imageID: Int) {
            self.archiveBaseName = archiveBaseName
            self.imageID = imageID
        }
    }

    public enum RequirementKind: Sendable, Hashable, Codable {
        case commodity(id: Int)
        case internalWorkTask(id: Int)
    }

    public struct PhaseRequirement: Sendable, Hashable, Codable {
        public let subBuildingIndex: Int
        public let phase: Int
        public let kind: RequirementKind
        public let amount: Int
        public let workerFigureID: Int
    }

    public struct RequirementTotals: Sendable, Hashable, Codable {
        public let commodityUnitsByID: [Int: Int]
        public let internalWorkUnitsByTaskID: [Int: Int]
    }

    public static let buildingIDs = Array(253...268)
    public static let monumentPhaseCount = 9
    public static let archivedRecordStride = 324
    public static let archivedBaseBuildingSchema = 4
    public static let archivedMonumentWrapperSchema = 1
    public static let archivedMonumentStateSchema = 10
    public static let archivedOnSiteLaborerWorkUpdatesOffsetFromBuildingID = 193
    public static let archivedDeliveredWoodUnitsOffsetFromBuildingID = 207
    public static let archivedCompletedInternalWorkUnitsOffsetFromBuildingID = 211
    public static let archivedDeliveredStoneUnitsOffsetFromBuildingID = 219
    public static let earthenMapImageBase = EmperorMap.chinaEarthenGreatWall1GlobalImageBase
    /// `China_Mon_Earthen_Greatwall_1.sg3` has 243 entries and group 1 starts
    /// at local image 201, so the authored map-image interval is 201...242.
    public static let earthenMapImageRange = 201...242

    /// A campaign map stores each predetermined Great Wall sub-building as a
    /// rectangular block of identical mode-image IDs. The root/orientation
    /// can therefore be recovered from authored layout geometry without
    /// depending on the original executable's serialized object heap.
    public struct MapPlacement: Sendable, Hashable, Codable {
        public let buildingID: Int
        public let origin: GridPoint
        public let quarterTurnsClockwise: Int

        public init(buildingID: Int, origin: GridPoint, quarterTurnsClockwise: Int) {
            self.buildingID = buildingID
            self.origin = origin
            self.quarterTurnsClockwise = quarterTurnsClockwise
        }
    }

    /// One original multipart-building record transformed into campaign-map
    /// coordinates. These records preserve the authored sub-building index
    /// used by the original root/previous/next links and phase rules.
    public struct PlacedSubBuilding: Sendable, Hashable, Codable {
        public let index: Int
        public let worldOrigin: GridPoint
        public let kind: String
        public let footprintSide: Int
        public let elevation: Int
        public let authoredOrientation: String
        public let variant: String
        public let layoutQuarterTurnsClockwise: Int

        public var footprintCells: Set<GridPoint> {
            Set(
                BuildingFootprint(width: footprintSide, height: footprintSide)
                    .points(at: worldOrigin)
            )
        }
    }

    public static func campaignPlacement(in map: EmperorMap) -> MapPlacement? {
        let authoredImageCells = Set((0..<map.height).flatMap { y in
            (0..<map.width).compactMap { x -> GridPoint? in
                guard let imageID = map.imageID(x: x, y: y),
                      imageID >= earthenMapImageBase,
                      earthenMapImageRange.contains(Int(imageID - earthenMapImageBase))
                else { return nil }
                return GridPoint(x: x, y: y)
            }
        })
        guard !authoredImageCells.isEmpty else { return nil }

        for buildingID in buildingIDs {
            guard let layout = layout(buildingID: buildingID) else { continue }
            for turns in 0..<4 {
                let relativeCells = footprintCells(layout: layout, quarterTurnsClockwise: turns)
                guard relativeCells.count == authoredImageCells.count,
                      let firstRelative = relativeCells.min(by: pointOrder),
                      let firstAuthored = authoredImageCells.min(by: pointOrder) else { continue }
                let origin = GridPoint(
                    x: firstAuthored.x - firstRelative.x,
                    y: firstAuthored.y - firstRelative.y
                )
                let translated = Set(relativeCells.map {
                    GridPoint(x: origin.x + $0.x, y: origin.y + $0.y)
                })
                if translated == authoredImageCells {
                    return MapPlacement(
                        buildingID: buildingID,
                        origin: origin,
                        quarterTurnsClockwise: turns
                    )
                }
            }
        }
        return nil
    }

    public static func subBuildingKind(
        buildingID: Int,
        subBuildingIndex: Int
    ) -> SubBuildingKind? {
        guard let layout = layout(buildingID: buildingID),
              layout.subBuildings.indices.contains(subBuildingIndex) else { return nil }
        return SubBuildingKind(rawValue: layout.subBuildings[subBuildingIndex].kind)
    }

    /// Great Wall IDs 253...268 use the same multipart access branch
    /// (`FUN_00567540 → FUN_005673D0/FUN_00567130`) as the Grand Canal. Each
    /// part supplies its own vtable footprint size (4/2/1) to the shared
    /// perimeter table.
    public static func targetAccesses(
        parts: [GreatWallMapPartState],
        roadComponentRankByPoint: [GridPoint: Int]
    ) -> [TargetAccessCandidate] {
        parts.sorted { $0.subBuildingIndex < $1.subBuildingIndex }.compactMap { part in
            guard let kind = subBuildingKind(
                buildingID: part.buildingID,
                subBuildingIndex: part.subBuildingIndex
            ), let access = OriginalMultipartMonumentRoutingCatalog.roadAccessPoint(
                subBuildingOrigin: part.worldOrigin,
                footprintSide: kind.footprintSide,
                roadComponentRankByPoint: roadComponentRankByPoint
            ) else { return nil }
            return TargetAccessCandidate(
                subBuildingIndex: part.subBuildingIndex,
                worldOrigin: part.worldOrigin,
                roadAccessPoint: access
            )
        }
    }

    public static func placedSubBuildings(
        for placement: MapPlacement,
        dataDirectory: URL = GameDataSource.defaultRoot
    ) -> [PlacedSubBuilding]? {
        guard let layout = layout(
            buildingID: placement.buildingID,
            dataDirectory: dataDirectory
        ) else { return nil }
        return layout.subBuildings.map { subBuilding in
            let side = footprintSide(forKind: subBuilding.kind)
            let relativeOrigin = rotate(
                subBuilding.localOrigin,
                side: side,
                quarterTurnsClockwise: placement.quarterTurnsClockwise
            )
            return PlacedSubBuilding(
                index: subBuilding.index,
                worldOrigin: GridPoint(
                    x: placement.origin.x + relativeOrigin.x,
                    y: placement.origin.y + relativeOrigin.y
                ),
                kind: subBuilding.kind,
                footprintSide: side,
                elevation: subBuilding.elevation,
                authoredOrientation: subBuilding.orientation,
                variant: subBuilding.variant,
                layoutQuarterTurnsClockwise: placement.quarterTurnsClockwise
            )
        }
    }

    /// Decodes the schema-4/schema-10 Great Wall object sequence used by the
    /// shipping Badaling maps. Maps without a complete, geometry-valid sequence
    /// return an empty array. This deliberately fails closed because unrelated
    /// maps can contain the same MFC class name and coincidental nearby words.
    public static func archivedPartStates(
        in decodedMapData: Data,
        dataDirectory: URL = GameDataSource.defaultRoot
    ) throws -> [GreatWallMapPartState] {
        let className = Data("cMonumentBldg".utf8)
        func uint16(at offset: Int) -> UInt16 {
            UInt16(decodedMapData[offset])
                | UInt16(decodedMapData[offset + 1]) << 8
        }
        func uint32(at offset: Int) -> UInt32 {
            UInt32(decodedMapData[offset])
                | UInt32(decodedMapData[offset + 1]) << 8
                | UInt32(decodedMapData[offset + 2]) << 16
                | UInt32(decodedMapData[offset + 3]) << 24
        }

        var searchStart = decodedMapData.startIndex
        while let classRange = decodedMapData.range(
            of: className,
            options: [],
            in: searchStart..<decodedMapData.endIndex
        ) {
            searchStart = classRange.upperBound
            let firstBuildingIDOffset = classRange.upperBound + 16
            guard firstBuildingIDOffset >= 19,
                  firstBuildingIDOffset + 177 < decodedMapData.count else { continue }

            let buildingID = Int(uint16(at: firstBuildingIDOffset))
            guard buildingIDs.contains(buildingID),
                  Int(uint16(at: firstBuildingIDOffset - 16))
                    == archivedBaseBuildingSchema,
                  Int(uint16(at: firstBuildingIDOffset + 165))
                    == archivedMonumentWrapperSchema,
                  Int(uint16(at: firstBuildingIDOffset + 167))
                    == archivedMonumentStateSchema,
                  let layout = layout(buildingID: buildingID, dataDirectory: dataDirectory)
            else { continue }

            let finalRequiredOffset = firstBuildingIDOffset
                + (layout.subBuildings.count - 1) * archivedRecordStride
                + archivedDeliveredStoneUnitsOffsetFromBuildingID + 3
            guard finalRequiredOffset < decodedMapData.count else { continue }

            var states: [GreatWallMapPartState] = []
            states.reserveCapacity(layout.subBuildings.count)
            var sequenceIsValid = true
            for index in layout.subBuildings.indices {
                let offset = firstBuildingIDOffset + index * archivedRecordStride
                if index > 0,
                   decodedMapData[(offset - 19)..<(offset - 16)] != Data([1, 3, 0x80]) {
                    sequenceIsValid = false
                    break
                }
                let state = GreatWallMapPartState(
                    worldOrigin: GridPoint(
                        x: Int(uint16(at: offset - 8)),
                        y: Int(uint16(at: offset - 6))
                    ),
                    mapCellIndex: Int(uint32(at: offset - 4)),
                    buildingID: Int(uint16(at: offset)),
                    subBuildingIndex: Int(uint16(at: offset + 2)),
                    baseBuildingSchema: Int(uint16(at: offset - 16)),
                    monumentWrapperSchema: Int(uint16(at: offset + 165)),
                    monumentStateSchema: Int(uint16(at: offset + 167)),
                    currentSubBuildingPhase: Int(uint32(at: offset + 173)),
                    wholeMonumentPhase: Int(uint32(at: offset + 177)),
                    onSiteLaborerWorkUpdates: Int(uint32(
                        at: offset + archivedOnSiteLaborerWorkUpdatesOffsetFromBuildingID
                    )),
                    deliveredWoodUnits: Int(uint32(
                        at: offset + archivedDeliveredWoodUnitsOffsetFromBuildingID
                    )),
                    completedInternalWorkUnits: Int(uint32(
                        at: offset + archivedCompletedInternalWorkUnitsOffsetFromBuildingID
                    )),
                    deliveredStoneUnits: Int(uint32(
                        at: offset + archivedDeliveredStoneUnitsOffsetFromBuildingID
                    ))
                )
                guard state.buildingID == buildingID,
                      state.subBuildingIndex == index,
                      state.baseBuildingSchema == archivedBaseBuildingSchema,
                      state.monumentWrapperSchema == archivedMonumentWrapperSchema,
                      state.monumentStateSchema == archivedMonumentStateSchema,
                      state.worldOrigin.x >= 0,
                      state.worldOrigin.y >= 0,
                      (0...100).contains(state.onSiteLaborerWorkUpdates),
                      (0...200).contains(state.deliveredWoodUnits),
                      (0...200).contains(state.completedInternalWorkUnits),
                      (0...200).contains(state.deliveredStoneUnits) else {
                    sequenceIsValid = false
                    break
                }
                states.append(state)
            }
            guard sequenceIsValid, let root = states.first else { continue }

            let matchesAuthoredGeometry = (0..<4).contains { turns in
                let rootPart = layout.subBuildings[0]
                let relativeRoot = rotate(
                    rootPart.localOrigin,
                    side: footprintSide(forKind: rootPart.kind),
                    quarterTurnsClockwise: turns
                )
                let placement = MapPlacement(
                    buildingID: buildingID,
                    origin: GridPoint(
                        x: root.worldOrigin.x - relativeRoot.x,
                        y: root.worldOrigin.y - relativeRoot.y
                    ),
                    quarterTurnsClockwise: turns
                )
                return placedSubBuildings(
                    for: placement,
                    dataDirectory: dataDirectory
                )?.map(\.worldOrigin) == states.map(\.worldOrigin)
            }
            if matchesAuthoredGeometry {
                return states
            }
        }
        return []
    }

    /// Last authored sub-building phase reached by this part across all nine
    /// layout rules. This is an archive invariant, not a campaign-goal result.
    public static func authoredTerminalSubBuildingPhase(
        index: Int,
        layout: PhasedMonumentLayout
    ) -> Int? {
        guard layout.subBuildings.indices.contains(index) else { return nil }
        return layout.phaseRules
            .filter { ($0.firstSubBuildingIndex...$0.lastSubBuildingIndex).contains(index) }
            .map(\.lastSubBuildingPhase)
            .max()
    }

    /// Exact requirement schedule recovered from the four Great Wall
    /// sub-building vtables (`0x7B97D4...0x7B99F0`). Internal work task IDs
    /// 100 and 101 are intentionally not given invented player-facing names.
    public static func phaseRequirements(
        for subBuilding: PhasedMonumentSubBuilding,
        wallKind: WallKind
    ) -> [PhaseRequirement] {
        let index = subBuilding.index
        switch subBuilding.kind {
        case "SB_GREAT_WALL", "SB_GREAT_WALL_TOWER":
            var result = (0...8).compactMap { phase -> PhaseRequirement? in
                switch phase % 3 {
                case 0:
                    return PhaseRequirement(
                        subBuildingIndex: index,
                        phase: phase,
                        kind: .commodity(id: wallKind == .earthen ? 10 : 20),
                        amount: 200,
                        workerFigureID: wallKind == .earthen ? 80 : 82
                    )
                case 1:
                    return PhaseRequirement(
                        subBuildingIndex: index,
                        phase: phase,
                        kind: .internalWorkTask(id: 100),
                        amount: 200,
                        workerFigureID: 10
                    )
                default:
                    return PhaseRequirement(
                        subBuildingIndex: index,
                        phase: phase,
                        kind: .internalWorkTask(id: 101),
                        amount: 200,
                        workerFigureID: 10
                    )
                }
            }
            if wallKind == .stone {
                result.append(PhaseRequirement(
                    subBuildingIndex: index,
                    phase: 9,
                    kind: .commodity(id: 20),
                    amount: 200,
                    workerFigureID: 82
                ))
            }
            if subBuilding.kind == "SB_GREAT_WALL_TOWER" {
                result.append(PhaseRequirement(
                    subBuildingIndex: index,
                    phase: 10,
                    kind: wallKind == .earthen
                        ? .internalWorkTask(id: 100)
                        : .commodity(id: 20),
                    amount: wallKind == .earthen ? 100 : 200,
                    workerFigureID: wallKind == .earthen ? 10 : 82
                ))
            }
            return result
        case "SB_GREAT_WALL_GATE":
            // The joined gate has one owning quadrant. `CENTER @ 0x56AF60`
            // maps its authored NW variant to the value 7 tested by the gate
            // requirement function; the other three quadrants request no work.
            guard subBuilding.variant == "NW" else { return [] }
            return [PhaseRequirement(
                subBuildingIndex: index,
                phase: 0,
                kind: wallKind == .earthen
                    ? .internalWorkTask(id: 100)
                    : .commodity(id: 20),
                amount: wallKind == .earthen ? 100 : 200,
                workerFigureID: wallKind == .earthen ? 10 : 82
            )]
        default:
            return []
        }
    }

    public static func requirementTotals(
        layout: PhasedMonumentLayout,
        wallKind: WallKind
    ) -> RequirementTotals {
        var commodities: [Int: Int] = [:]
        var work: [Int: Int] = [:]
        for requirement in layout.subBuildings.flatMap({
            phaseRequirements(for: $0, wallKind: wallKind)
        }) {
            switch requirement.kind {
            case let .commodity(id):
                commodities[id, default: 0] += requirement.amount
            case let .internalWorkTask(id):
                work[id, default: 0] += requirement.amount
            }
        }
        return RequirementTotals(
            commodityUnitsByID: commodities,
            internalWorkUnitsByTaskID: work
        )
    }

    public static func footprintCells(
        layout: PhasedMonumentLayout,
        quarterTurnsClockwise: Int
    ) -> Set<GridPoint> {
        Set(layout.subBuildings.flatMap { subBuilding in
            let side = footprintSide(forKind: subBuilding.kind)
            let origin = rotate(
                subBuilding.localOrigin,
                side: side,
                quarterTurnsClockwise: quarterTurnsClockwise
            )
            return BuildingFootprint(width: side, height: side).points(at: origin)
        })
    }

    /// `FUN_00563720 @ 0x563720` selects mode 2 for task 85 and mode 3 for
    /// task 86. `FUN_0057BBA0 @ 0x57BBA0` maps those modes to the authored
    /// earthen- and stone-wall sprite families respectively.
    public static func wallKind(forTaskBuildingID buildingID: Int) -> WallKind? {
        switch buildingID {
        case 85: .earthen
        case 86: .stone
        default: nil
        }
    }

    /// Exact terminal-state sprite selection for the default (north) player
    /// view. Badaling's archive stores wall/tower/gate/road at phases
    /// 10/11/1/2. `0x57BBA0`, `0x57D2B0`, `0x57CB10`, and `0x57D860` select
    /// these authored images; no appearance-based matching is involved.
    public static func terminalSpriteReference(
        for subBuilding: PhasedMonumentSubBuilding,
        wallKind: WallKind
    ) -> SpriteReference? {
        let archiveBaseName = switch wallKind {
        case .earthen: "China_Mon_Earthen_Greatwall_10"
        case .stone: "China_Mon_Greatwall_10"
        }
        let imageID: Int
        switch SubBuildingKind(rawValue: subBuilding.kind) {
        case .wall, .tower:
            guard subBuilding.orientation == "NORTH",
                  let variant = Int(subBuilding.variant),
                  (0...27).contains(variant) else {
                return nil
            }
            imageID = 201 + variant
        case .gate:
            guard subBuilding.orientation == "EAST" else { return nil }
            let gateImageID: Int?
            switch subBuilding.variant {
            case "NW": gateImageID = 232
            case "NE": gateImageID = 229
            case "SW": gateImageID = 231
            case "SE": gateImageID = 230
            default: gateImageID = nil
            }
            guard let gateImageID else { return nil }
            imageID = gateImageID
        case .road:
            // The default-view East/West road branch selects #241; the
            // North/South branch selects #242.
            let roadImageID: Int?
            switch subBuilding.orientation {
            case "EAST", "WEST": roadImageID = 241
            case "NORTH", "SOUTH": roadImageID = 242
            default: roadImageID = nil
            }
            guard let roadImageID else { return nil }
            imageID = roadImageID
        case nil:
            return nil
        }
        return SpriteReference(
            archiveBaseName: archiveBaseName,
            imageID: imageID
        )
    }

    public static func isTerminal(
        _ part: GreatWallMapPartState,
        layout: PhasedMonumentLayout
    ) -> Bool {
        guard let terminal = authoredTerminalSubBuildingPhase(
            index: part.subBuildingIndex,
            layout: layout
        ) else { return false }
        return part.currentSubBuildingPhase >= terminal
    }

    public static func fileName(forBuildingID buildingID: Int) -> String? {
        guard buildingIDs.contains(buildingID) else { return nil }
        return String(
            format: "Mon_Great_Wall_%02d_subs.txt",
            buildingID - 252
        )
    }

    public static func parse(
        buildingID: Int,
        subBuildingText: String
    ) -> PhasedMonumentLayout? {
        guard fileName(forBuildingID: buildingID) != nil,
              let itemExpression = try? NSRegularExpression(
                pattern: #"/\*\s*(\d+)\*/\s*\{"#
              ) else { return nil }
        let range = NSRange(subBuildingText.startIndex..., in: subBuildingText)
        let expectedSubBuildingCount = itemExpression.numberOfMatches(
            in: subBuildingText,
            range: range
        )
        guard expectedSubBuildingCount > 0,
              let layout = PhasedMonumentLayout.parse(
                subBuildingText: subBuildingText,
                expectedSubBuildingCount: expectedSubBuildingCount,
                expectedPhaseCount: monumentPhaseCount
              ),
              layout.subBuildings.map(\.index)
                == Array(0..<expectedSubBuildingCount) else { return nil }
        return layout
    }

    public static func layout(
        buildingID: Int,
        dataDirectory: URL = GameDataSource.defaultRoot
    ) -> PhasedMonumentLayout? {
        guard let fileName = fileName(forBuildingID: buildingID),
              let text = try? String(
                contentsOf: dataDirectory
                    .appendingPathComponent("Model")
                    .appendingPathComponent(fileName),
                encoding: .utf8
              ) else { return nil }
        return parse(buildingID: buildingID, subBuildingText: text)
    }

    private static func footprintSide(forKind kind: String) -> Int {
        switch kind {
        case "SB_GREAT_WALL_GATE": 2
        case "SB_GREAT_WALL_ROAD": 1
        default: 4
        }
    }

    /// Mirrors `FUN_00568D10 @ 0x568D10`, including its footprint-aware
    /// origin adjustment for clockwise quarter-turns.
    private static func rotate(
        _ point: GridPoint,
        side: Int,
        quarterTurnsClockwise: Int
    ) -> GridPoint {
        switch (quarterTurnsClockwise % 4 + 4) % 4 {
        case 0:
            point
        case 1:
            GridPoint(x: point.y, y: 1 - point.x - side)
        case 2:
            GridPoint(x: 1 - point.x - side, y: 1 - point.y - side)
        default:
            GridPoint(x: 1 - point.y - side, y: point.x)
        }
    }

    private static func pointOrder(_ lhs: GridPoint, _ rhs: GridPoint) -> Bool {
        lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
    }
}
