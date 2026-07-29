import Foundation

public enum FengShuiElement: Int, Sendable, Hashable, Codable {
    case earth = 1
    case metal = 2
    case water = 3
    case wood = 4
    case fire = 5
}

public enum FengShuiPlacementQuality: String, Sendable, Hashable, Codable {
    case neutral
    case harmonious
    case inauspicious
}

public struct FengShuiBuildingEvaluation: Identifiable, Sendable, Hashable, Codable {
    public let buildingKey: OperationalBuildingKey
    public let buildingID: Int
    public let element: FengShuiElement?
    public let quality: FengShuiPlacementQuality

    public var id: String { "\(buildingKey.category.rawValue)-\(buildingKey.instanceID)" }
}

public struct FengShuiCitySummary: Sendable, Hashable, Codable {
    public let evaluations: [FengShuiBuildingEvaluation]
    public let harmoniousCount: Int
    public let inauspiciousCount: Int
    public let neutralCount: Int

    public var harmonyPercent: Int {
        let considered = harmoniousCount + inauspiciousCount
        return considered == 0 ? 100 : harmoniousCount * 100 / considered
    }
}

public enum AestheticConstructionKind: String, Sendable, Hashable, Codable {
    case scenery
    case irrigationPump
    case laborersCamp
    case carpentersGuild
    case masonsGuild
    case ceramistsGuild
    case monument
}

public struct AestheticConstruction: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let kind: AestheticConstructionKind
    public let location: GridPoint
}

public struct OriginalMonumentConfiguration: Sendable, Hashable, Codable {
    public let buildingID: Int
    public let requiredWork: Int
    public let requiredCommodityUnits: [Int: Int]
    public let requiredSupportKinds: Set<AestheticConstructionKind>

    public static func configuration(buildingID: Int) -> Self? {
        let labor: Set<AestheticConstructionKind> = [.laborersCamp]
        let carpenter: Set<AestheticConstructionKind> = [.carpentersGuild]
        let mason: Set<AestheticConstructionKind> = [.masonsGuild]
        let ceramist: Set<AestheticConstructionKind> = [.ceramistsGuild]
        switch buildingID {
        case 76: // Tumulus: dirt, wood, burial provisions.
            return Self(
                buildingID: buildingID,
                requiredWork: 1_500,
                requiredCommodityUnits: [10: 400, 23: 200, 24: 200, 25: 200],
                requiredSupportKinds: labor.union(carpenter)
            )
        case 77:
            return Self(
                buildingID: buildingID,
                // Emperor Heaven records 89 loads of wood, 11 loads of
                // lacquerware or bronzeware, 10 silk, 9 ceramics, 7 weapons,
                // and 4 carved-jade loads. One warehouse load is 100 internal
                // units. Dirt remains represented by requiredWork because it
                // is excavated by laborers rather than stored as a commodity.
                requiredWork: 2_400,
                requiredCommodityUnits: [
                    10: 8_900,
                    21: 700,
                    22: 1_100,
                    24: 1_000,
                    25: 900,
                    26: 400,
                ],
                requiredSupportKinds: labor.union(carpenter)
            )
        case 78: // Great Temple.
            return Self(
                buildingID: buildingID,
                requiredWork: 1_200,
                requiredCommodityUnits: [10: 400, 18: 400],
                requiredSupportKinds: labor.union(carpenter).union(ceramist)
            )
        case 79:
            return Self(
                buildingID: buildingID,
                requiredWork: 2_000,
                requiredCommodityUnits: [10: 800, 18: 800],
                requiredSupportKinds: labor.union(carpenter).union(ceramist)
            )
        case 80:
            return Self(
                buildingID: buildingID,
                requiredWork: 2_600,
                requiredCommodityUnits: [10: 800, 18: 800, 20: 600],
                requiredSupportKinds: labor.union(carpenter).union(ceramist).union(mason)
            )
        case 81:
            return Self(
                buildingID: buildingID,
                requiredWork: 3_600,
                requiredCommodityUnits: [10: 1_200, 18: 1_200, 20: 1_000],
                requiredSupportKinds: labor.union(carpenter).union(ceramist).union(mason)
            )
        case 82:
            return Self(
                buildingID: buildingID,
                requiredWork: 2_800,
                requiredCommodityUnits: [10: 800, 18: 800, 20: 800],
                requiredSupportKinds: labor.union(carpenter).union(ceramist).union(mason)
            )
        case 83:
            return Self(
                buildingID: buildingID,
                requiredWork: 2_400,
                requiredCommodityUnits: [10: 600, 20: 800],
                requiredSupportKinds: labor.union(carpenter).union(mason)
            )
        case 84:
            return Self(
                buildingID: buildingID,
                // 106 wood loads and 11 clay loads. The 337 dirt loads are
                // laborer work and therefore do not enter the warehouse map.
                requiredWork: 4_000,
                requiredCommodityUnits: [10: 10_600, 18: 1_100],
                requiredSupportKinds: labor.union(carpenter).union(ceramist)
            )
        case 85: // Earthen Great Wall, assembled from map-authored segments.
            return Self(
                buildingID: buildingID,
                requiredWork: 3_600,
                requiredCommodityUnits: [10: 800, 20: 1_200],
                requiredSupportKinds: labor.union(carpenter).union(mason)
            )
        case 92: // Clock tower needs wood and bronze; no labor camp.
            return Self(
                buildingID: buildingID,
                requiredWork: 1_600,
                requiredCommodityUnits: [10: 500, 11: 500],
                requiredSupportKinds: carpenter
            )
        case 93: // Grand pagoda needs wood and stone; no labor camp.
            return Self(
                buildingID: buildingID,
                requiredWork: 2_200,
                requiredCommodityUnits: [10: 700, 20: 700],
                requiredSupportKinds: carpenter.union(mason)
            )
        default:
            return nil
        }
    }
}

public struct MonumentProject: Identifiable, Sendable, Hashable, Codable {
    public let id: Int
    public let buildingID: Int
    public let requiredWork: Int
    public let requiredCommodityUnits: [Int: Int]
    public let requiredSupportKinds: Set<AestheticConstructionKind>
    public private(set) var deliveredCommodityUnits: [Int: Int]
    public private(set) var completedWork: Int
    public private(set) var isComplete: Bool

    public var completionPercent: Int {
        let materialRequired = requiredCommodityUnits.values.reduce(0, +)
        let materialDelivered = requiredCommodityUnits.reduce(0) {
            $0 + min(
                $1.value,
                deliveredUnits(satisfyingRequirementFor: $1.key)
            )
        }
        let totalRequired = max(1, requiredWork + materialRequired)
        return min(100, (completedWork + materialDelivered) * 100 / totalRequired)
    }

    /// Building #77 accepts the original burial-provision alternatives:
    /// lacquerware (22) and bronzeware (23) can be mixed to satisfy the single
    /// 11-load requirement. Qin V has no legal bronzeware source, so normal
    /// play supplies lacquerware without losing compatibility with other
    /// scenarios or imported saves that already delivered bronzeware.
    public func deliveredUnits(satisfyingRequirementFor commodityID: Int) -> Int {
        if buildingID == 77, commodityID == 22 {
            return deliveredCommodityUnits[22, default: 0]
                + deliveredCommodityUnits[23, default: 0]
        }
        return deliveredCommodityUnits[commodityID, default: 0]
    }

    public func hasDelivered(_ requirements: [Int: Int]) -> Bool {
        requirements.allSatisfy {
            deliveredUnits(satisfyingRequirementFor: $0.key) >= $0.value
        }
    }

    mutating func recordDelivery(commodityID: Int, amount: Int) {
        deliveredCommodityUnits[commodityID, default: 0] += max(0, amount)
    }

    mutating func performWork(_ amount: Int, allowCompletion: Bool = true) {
        completedWork = min(requiredWork, completedWork + max(0, amount))
        isComplete = allowCompletion
            && completedWork >= requiredWork
            && hasDelivered(requiredCommodityUnits)
    }

    mutating func markSegmentedConstructionComplete() {
        guard completedWork >= requiredWork,
              hasDelivered(requiredCommodityUnits) else { return }
        isComplete = true
    }
}

public struct MonumentMonthlySettlement: Sendable, Hashable, Codable {
    public let deliveredCommodityUnitsByProjectID: [Int: [Int: Int]]
    public let workByProjectID: [Int: Int]
    public let completedProjectIDs: [Int]

    public static let empty = Self(
        deliveredCommodityUnitsByProjectID: [:],
        workByProjectID: [:],
        completedProjectIDs: []
    )
}

public struct DeterministicAestheticState: Sendable, Hashable, Codable {
    public private(set) var constructions: [AestheticConstruction]
    public private(set) var monuments: [MonumentProject]
    public private(set) var grandCanalProject: GrandCanalProjectRuntime?
    public private(set) var earthenGreatWallProject: EarthenGreatWallProjectRuntime?
    public private(set) var largePalaceProject: LargePalaceProjectRuntime?
    private var phasedMonumentProjectsState: [PhasedMonumentProjectRuntime]?
    public private(set) var lastMonumentSettlement: MonumentMonthlySettlement?
    private var nextConstructionID: Int

    public init() {
        constructions = []
        monuments = []
        grandCanalProject = nil
        earthenGreatWallProject = nil
        largePalaceProject = nil
        phasedMonumentProjectsState = []
        lastMonumentSettlement = nil
        nextConstructionID = 1
    }

    public var completedMonumentBuildingIDs: Set<Int> {
        Set(monuments.filter(\.isComplete).map(\.buildingID))
    }

    public var phasedMonumentProjects: [PhasedMonumentProjectRuntime] {
        phasedMonumentProjectsState ?? []
    }

    @discardableResult
    mutating func addConstruction(
        buildingID: Int,
        kind: AestheticConstructionKind,
        location: GridPoint,
        origin: GridPoint? = nil,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> Int {
        let id = nextConstructionID
        nextConstructionID += 1
        constructions.append(AestheticConstruction(
            id: id,
            buildingID: buildingID,
            kind: kind,
            location: location
        ))
        if let configuration = OriginalMonumentConfiguration.configuration(buildingID: buildingID) {
            monuments.append(MonumentProject(
                id: id,
                buildingID: buildingID,
                requiredWork: configuration.requiredWork,
                requiredCommodityUnits: configuration.requiredCommodityUnits,
                requiredSupportKinds: configuration.requiredSupportKinds,
                deliveredCommodityUnits: [:],
                completedWork: 0,
                isComplete: false
            ))
            if buildingID == LargePalaceProjectRuntime.buildingID {
                largePalaceProject = LargePalaceProjectRuntime(
                    projectID: id,
                    origin: origin ?? location,
                    orientation: orientation
                )
            }
            if let runtime = PhasedMonumentProjectRuntime(
                projectID: id,
                buildingID: buildingID,
                origin: origin ?? location,
                orientation: orientation
            ) {
                var projects = phasedMonumentProjects
                projects.append(runtime)
                phasedMonumentProjectsState = projects
            }
        }
        return id
    }

    @discardableResult
    mutating func addMapMonument(buildingID: Int) -> Int? {
        guard monuments.contains(where: { $0.buildingID == buildingID }) == false,
              let configuration = OriginalMonumentConfiguration.configuration(
                buildingID: buildingID
              ) else { return nil }
        let id = nextConstructionID
        nextConstructionID += 1
        monuments.append(MonumentProject(
            id: id,
            buildingID: buildingID,
            requiredWork: configuration.requiredWork,
            requiredCommodityUnits: configuration.requiredCommodityUnits,
            requiredSupportKinds: configuration.requiredSupportKinds,
            deliveredCommodityUnits: [:],
            completedWork: 0,
            isComplete: false
        ))
        if buildingID == GrandCanalProjectRuntime.buildingID {
            grandCanalProject = GrandCanalProjectRuntime(projectID: id)
        }
        if buildingID == EarthenGreatWallProjectRuntime.buildingID {
            earthenGreatWallProject = EarthenGreatWallProjectRuntime(projectID: id)
        }
        return id
    }

    @discardableResult
    mutating func advanceGrandCanalSegment(at point: GridPoint) -> Int? {
        guard var canal = grandCanalProject,
              let segmentIndex = canal.segmentIndex(containing: point),
              let monumentIndex = monuments.firstIndex(where: { $0.id == canal.projectID }),
              canal.advanceSegment(index: segmentIndex, project: monuments[monumentIndex]) else {
            return nil
        }
        grandCanalProject = canal
        if canal.isComplete {
            monuments[monumentIndex].markSegmentedConstructionComplete()
        }
        return segmentIndex
    }

    @discardableResult
    mutating func advanceEarthenGreatWallSegment(index: Int) -> Int? {
        guard var wall = earthenGreatWallProject,
              let monumentIndex = monuments.firstIndex(where: { $0.id == wall.projectID }),
              wall.advanceSegment(index: index, project: monuments[monumentIndex]) else {
            return nil
        }
        earthenGreatWallProject = wall
        if wall.isComplete {
            monuments[monumentIndex].markSegmentedConstructionComplete()
        }
        return index
    }

    @discardableResult
    mutating func advanceLargePalacePhase(at point: GridPoint) -> Int? {
        guard var palace = largePalaceProject,
              palace.contains(point),
              let monumentIndex = monuments.firstIndex(where: { $0.id == palace.projectID }),
              palace.advance(project: monuments[monumentIndex]) else { return nil }
        largePalaceProject = palace
        if palace.isComplete {
            monuments[monumentIndex].markSegmentedConstructionComplete()
        }
        return palace.completedPhaseCount
    }

    @discardableResult
    mutating func advancePhasedMonument(at point: GridPoint) -> Int? {
        var projects = phasedMonumentProjects
        guard let projectIndex = projects.firstIndex(where: {
            !$0.isComplete && $0.contains(point)
        }),
        let monumentIndex = monuments.firstIndex(where: {
            $0.id == projects[projectIndex].projectID
        }),
        projects[projectIndex].advance(project: monuments[monumentIndex]) else {
            return nil
        }
        let completedPhase = projects[projectIndex].completedPhaseCount
        if projects[projectIndex].isComplete {
            monuments[monumentIndex].markSegmentedConstructionComplete()
        }
        phasedMonumentProjectsState = projects
        return completedPhase
    }

    @discardableResult
    mutating func removeConstruction(id: Int) -> Bool {
        guard let index = constructions.firstIndex(where: { $0.id == id }) else { return false }
        constructions.remove(at: index)
        monuments.removeAll { $0.id == id }
        if grandCanalProject?.projectID == id {
            grandCanalProject = nil
        }
        if earthenGreatWallProject?.projectID == id {
            earthenGreatWallProject = nil
        }
        if largePalaceProject?.projectID == id {
            largePalaceProject = nil
        }
        phasedMonumentProjectsState = phasedMonumentProjects.filter {
            $0.projectID != id
        }
        return true
    }

    mutating func advanceMonuments(
        logistics: inout DeterministicLogisticsState,
        production: inout DeterministicProductionState
    ) -> MonumentMonthlySettlement {
        let supportCounts = Dictionary(grouping: constructions, by: \.kind).mapValues(\.count)
        var deliveries: [Int: [Int: Int]] = [:]
        var work: [Int: Int] = [:]
        var completed: [Int] = []
        for index in monuments.indices where !monuments[index].isComplete {
            let palaceRequirements: MonumentPhaseRequirements?
            if monuments[index].buildingID == LargePalaceProjectRuntime.buildingID,
               let palace = largePalaceProject,
               palace.projectID == monuments[index].id {
                palaceRequirements = palace.nextPhaseRequirements(
                    project: monuments[index]
                )
            } else {
                palaceRequirements = nil
            }
            let phasedRequirements = phasedMonumentProjects.first(where: {
                $0.projectID == monuments[index].id
            })?.nextPhaseRequirements(project: monuments[index])
            let phaseRequirements = palaceRequirements ?? phasedRequirements
            let requiredCommodityUnits = phaseRequirements?.commodityUnits
                ?? monuments[index].requiredCommodityUnits
            let requiredWork = phaseRequirements?.work
                ?? monuments[index].requiredWork
            for (commodityID, required) in requiredCommodityUnits.sorted(by: { $0.key < $1.key }) {
                let remaining = max(
                    0,
                    required
                        - monuments[index].deliveredUnits(
                            satisfyingRequirementFor: commodityID
                        )
                )
                let load = min(DeterministicLogisticsState.originalDeliveryLoad, remaining)
                if load > 0, logistics.takeCampaignRequestGoods(
                    commodityID: commodityID,
                    amount: load,
                    production: &production
                ) {
                    monuments[index].recordDelivery(commodityID: commodityID, amount: load)
                    deliveries[monuments[index].id, default: [:]][commodityID, default: 0] += load
                }
            }
            let hasMaterials = monuments[index].hasDelivered(requiredCommodityUnits)
            let crewCount = monuments[index].requiredSupportKinds
                .map { supportCounts[$0, default: 0] }
                .min() ?? 0
            if hasMaterials, crewCount > 0 {
                let performed = min(
                    max(0, requiredWork - monuments[index].completedWork),
                    crewCount * 100
                )
                if performed > 0 {
                    monuments[index].performWork(
                        performed,
                        allowCompletion: monuments[index].buildingID
                            != GrandCanalProjectRuntime.buildingID
                            && monuments[index].buildingID
                            != EarthenGreatWallProjectRuntime.buildingID
                            && monuments[index].buildingID
                            != LargePalaceProjectRuntime.buildingID
                            && PhasedMonumentProjectRuntime
                                .phaseCountsByBuildingID[monuments[index].buildingID] == nil
                    )
                    work[monuments[index].id] = performed
                    if monuments[index].isComplete { completed.append(monuments[index].id) }
                }
            }
        }
        let settlement = MonumentMonthlySettlement(
            deliveredCommodityUnitsByProjectID: deliveries,
            workByProjectID: work,
            completedProjectIDs: completed
        )
        lastMonumentSettlement = settlement
        return settlement
    }
}

public extension DeterministicCityState {
    func fengShuiSummary(models: BuildingModelTable) -> FengShuiCitySummary {
        let evaluations = placedBuildings.map { placement in
            let model = models[buildingID: placement.buildingID]
            let element = model.flatMap { FengShuiElement(rawValue: $0.fengShuiValue) }
            let quality: FengShuiPlacementQuality
            if let element {
                quality = isHarmonious(
                    element: element,
                    footprint: placement.occupiedPoints
                ) ? .harmonious : .inauspicious
            } else {
                quality = .neutral
            }
            return FengShuiBuildingEvaluation(
                buildingKey: OperationalBuildingKey(
                    category: placement.category,
                    instanceID: placement.instanceID
                ),
                buildingID: placement.buildingID,
                element: element,
                quality: quality
            )
        }
        return FengShuiCitySummary(
            evaluations: evaluations,
            harmoniousCount: evaluations.count { $0.quality == .harmonious },
            inauspiciousCount: evaluations.count { $0.quality == .inauspicious },
            neutralCount: evaluations.count { $0.quality == .neutral }
        )
    }

    private func isHarmonious(element: FengShuiElement, footprint: [GridPoint]) -> Bool {
        guard let terrain else { return true }
        let sampled = Set(footprint + footprint.flatMap(RoadServiceCoverage.orthogonalNeighbors(of:)))
            .compactMap(terrain.terrain(at:))
        guard !sampled.isEmpty else { return false }
        switch element {
        case .earth:
            return sampled.contains { !$0.contains(.water) && !$0.contains(.deepWater) }
        case .metal:
            return sampled.contains { $0.contains(.rock) || $0.contains(.elevation) }
        case .water:
            return sampled.contains { $0.contains(.water) || $0.contains(.deepWater) || $0.contains(.groundwater) }
        case .wood:
            return sampled.contains { $0.contains(.tree) || $0.contains(.scrub) || $0.contains(.garden) }
        case .fire:
            return sampled.contains { !$0.contains(.water) && !$0.contains(.groundwater) && !$0.contains(.deepWater) }
        }
    }
}
