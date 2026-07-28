import EmperorCore
import Foundation

public enum PlayerConstructionTool: String, CaseIterable, Sendable, Hashable, Codable {
    case inspect
    case demolish
    case clearLand
    case road
    case house
    case warehouse
    case huntingCamp
    case mill
    case market
    case clayPit
    case kiln
    case well
    case herbalist
    case acupuncture
    case ancestralShrine
    case confucianAcademy
    case daoistShrine
    case inspectorTower
    case taxOffice
    case musicSchool
    case acrobatSchool
    case dramaSchool
    case farmland
    case lumberMill
    case quarry
    case granary
    case barracks
    case cityWall
    case gatehouse
    case tower
    case roadblock
    case administrativeCity
    case palace
    case fort
    case catapultFort
    case cavalryFort
    case chariotFort
    case fishingWharf
    case ironMine
    case bronzeWorks
    case lacquerGuild
    case jadeWorkshop
    case silkWeaver
    case teaHouse
    case bathhouse
    case magistrate
    case watchtower
    case garden
    case decorativeSculpture
    case ornateSculpture
    case floweringTree
    case waysidePavilion
    case pond
    case taiChiPark
    case privateGarden
    case laborersCamp
    case carpentersGuild
    case masonsGuild
    case ceramistsGuild
    case tumulus
    case grandTumulus
    case greatTemple
    case splendidTemple
    case grandPagoda

    public var buildingID: Int? {
        switch self {
        case .inspect, .demolish, .clearLand: nil
        case .road: 1
        case .house: 2
        case .fishingWharf: 31
        case .huntingCamp: 33
        case .clayPit: 35
        case .quarry: 36
        case .lumberMill: 38
        case .bronzeWorks: 39
        case .ironMine: 40
        case .jadeWorkshop: 46
        case .kiln: 43
        case .carpentersGuild: 52
        case .mill: 53
        case .warehouse, .granary: 54
        case .market: 59
        case .well: 72
        case .tumulus: 76
        case .grandTumulus: 77
        case .greatTemple: 78
        case .splendidTemple: 79
        case .grandPagoda: 93
        case .palace: 110
        case .inspectorTower: 124
        case .taxOffice: 125
        case .roadblock: 126
        case .watchtower: 127
        case .cityWall: 129
        case .gatehouse: 130
        case .tower: 131
        case .garden: 115
        case .decorativeSculpture: 116
        case .ornateSculpture: 117
        case .floweringTree: 118
        case .waysidePavilion: 119
        case .pond: 120
        case .taiChiPark: 121
        case .privateGarden: 122
        case .farmland: 193
        case .herbalist: 207
        case .acupuncture: 208
        case .administrativeCity: 209
        case .musicSchool: 211
        case .acrobatSchool: 212
        case .dramaSchool: 213
        case .ancestralShrine: 214
        case .daoistShrine: 215
        case .bathhouse: 216
        case .magistrate: 218
        case .confucianAcademy: 219
        case .fort: 220
        case .barracks: 221
        case .catapultFort: 223
        case .cavalryFort: 224
        case .chariotFort: 225
        case .laborersCamp: 233
        case .masonsGuild: 235
        case .ceramistsGuild: 236
        case .teaHouse: 237
        case .lacquerGuild: 238
        case .silkWeaver: 239
        }
    }
}

public enum PlayerCommand: Sendable, Hashable, Codable {
    case startCampaignMission(campaignID: Int, missionID: Int)
    case selectConstruction(PlayerConstructionTool)
    case selectAgriculturalCrop(AgriculturalCrop)
    case selectDifficulty(GameDifficulty)
    case placeSelectedConstruction(at: GridPoint, orientation: IsometricBuildingOrientation)
    case demolish(at: GridPoint)
    case setProductionEnabled(buildingInstanceID: Int, enabled: Bool)
    case setWarehousePolicy(warehouseID: Int, policy: WarehouseCommodityPolicy)
    case setWarehouseCommodityPolicy(
        warehouseID: Int,
        commodityID: Int,
        policy: WarehouseCommodityPolicy
    )
    case setTradeEnabled(tradingBuildingID: Int, enabled: Bool)
    case beginMapMonument(buildingID: Int)
    case setSpeed(Int)
    case advanceOneTick
    case replayMission
}

public enum PlayerCommandResult: Sendable, Hashable {
    case applied(String)
    case rejected(String)

    public var wasApplied: Bool {
        guard case .applied = self else { return false }
        return true
    }

    public var message: String {
        switch self {
        case let .applied(message), let .rejected(message): message
        }
    }
}

public struct ConstructionPreview: Sendable, Hashable {
    public let point: GridPoint
    public let tool: PlayerConstructionTool
    public let orientation: IsometricBuildingOrientation
    public let isValid: Bool
    public let reason: String?
}

public struct GameSessionEvidence: Sendable, Hashable, Codable {
    public var sawStaffedProducer = false
    public var sawProducerStock = false
    public var sawDeliveryWalker = false
    public var sawMillStock = false
    public var sawBuyer = false
    public var sawPeddler = false
    public var sawHouseFood = false
    public var sawWaterService = false
    public var sawAncestorService = false
    public var sawInspectionService = false
    public var outcomeChangeCount = 0

    public init() {}
}

public struct GameSessionSnapshot: Sendable, Equatable {
    public let city: DeterministicCityState?
    public let campaignRuntime: CampaignMissionRuntimeState?
    public let campaignID: Int?
    public let missionID: Int?
    public let speed: Int
    public let selectedConstruction: PlayerConstructionTool
    public let replayFingerprint: UInt64?
    public let lastBlockReason: String?
    public let evidence: GameSessionEvidence
}
