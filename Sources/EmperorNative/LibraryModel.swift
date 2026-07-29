import EmperorCore
import EmperorGameplay
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct RenderedTerrainSprite {
    let image: CGImage
    let width: Int
    let height: Int
    let offsetX: Int
    let offsetY: Int

    init(image: CGImage, width: Int, height: Int, offsetX: Int = 0, offsetY: Int = 0) {
        self.image = image
        self.width = width
        self.height = height
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

enum NativeBuildingSettingChange {
    case productionEnabled(instanceID: Int, enabled: Bool)
    case warehousePolicy(warehouseID: Int, policy: WarehouseCommodityPolicy)
    case warehouseCommodityPolicy(
        warehouseID: Int,
        commodityID: Int,
        policy: WarehouseCommodityPolicy
    )
    case tradeEnabled(tradingBuildingID: Int, enabled: Bool)
}

struct MapSpriteArchiveDescriptor: Sendable {
    let baseName: String
    let globalImageBase: UInt32
}

let mapSpriteArchiveDescriptors: [MapSpriteArchiveDescriptor] = [
    .init(baseName: "China_Terrain", globalImageBase: EmperorMap.chinaTerrainGlobalImageBase),
    .init(baseName: "China_Elevation", globalImageBase: EmperorMap.chinaElevationGlobalImageBase),
    .init(baseName: "China_Elevation_dirt", globalImageBase: EmperorMap.chinaElevationDirtGlobalImageBase),
    .init(baseName: "China_Mon_GreatWall_1", globalImageBase: EmperorMap.chinaGreatWall1GlobalImageBase),
    .init(baseName: "China_Mon_Grand_Canal", globalImageBase: EmperorMap.chinaGrandCanalGlobalImageBase),
    .init(
        baseName: "China_Mon_Earthen_Greatwall_1",
        globalImageBase: EmperorMap.chinaEarthenGreatWall1GlobalImageBase
    ),
]

struct DecodedMapSpriteArchive: Sendable {
    let globalImageBase: UInt32
    let imageCount: Int
    let sprites: [Int: DecodedSprite]
    let vegetationSprites: [Int: DecodedSprite]
}

struct RenderedMapSpriteArchive {
    let globalImageBase: UInt32
    let imageCount: Int
    let sprites: [Int: RenderedTerrainSprite]
    let vegetationSprites: [Int: RenderedTerrainSprite]

    func sprite(globalImageID: UInt32) -> RenderedTerrainSprite? {
        guard globalImageID >= globalImageBase else { return nil }
        let localID = Int(globalImageID - globalImageBase)
        guard (0..<imageCount).contains(localID) else { return nil }
        return sprites[localID]
    }
}

struct RenderedMap {
    let map: EmperorMap
    let spriteArchives: [RenderedMapSpriteArchive]
    private let roadSpritesByConnectionMask: [Int: RenderedTerrainSprite]

    init(map: EmperorMap, spriteArchives: [RenderedMapSpriteArchive]) {
        self.map = map
        self.spriteArchives = spriteArchives

        func resolvedSprite(x: Int, y: Int) -> RenderedTerrainSprite? {
            guard let globalImageID = map.imageID(x: x, y: y) else { return nil }
            return spriteArchives.lazy.compactMap {
                $0.sprite(globalImageID: globalImageID)
            }.first
        }

        func authoredRoad(at point: GridPoint) -> Bool {
            guard point.x >= 0, point.x < map.width,
                  point.y >= 0, point.y < map.height else { return false }
            return map.terrain(at: point)?.contains(.road) == true
        }

        func connectionMask(at point: GridPoint) -> Int {
            var mask = 0
            if authoredRoad(at: GridPoint(x: point.x, y: point.y - 1)) { mask |= 1 }
            if authoredRoad(at: GridPoint(x: point.x + 1, y: point.y)) { mask |= 2 }
            if authoredRoad(at: GridPoint(x: point.x, y: point.y + 1)) { mask |= 4 }
            if authoredRoad(at: GridPoint(x: point.x - 1, y: point.y)) { mask |= 8 }
            return mask
        }

        var catalog: [Int: RenderedTerrainSprite] = [:]
        for y in 0..<map.height {
            for x in 0..<map.width {
                let point = GridPoint(x: x, y: y)
                guard authoredRoad(at: point),
                      let sprite = resolvedSprite(x: x, y: y) else { continue }
                let mask = connectionMask(at: point)
                catalog[mask] = catalog[mask] ?? sprite
            }
        }
        roadSpritesByConnectionMask = catalog
    }

    func sprite(x: Int, y: Int) -> RenderedTerrainSprite? {
        guard let globalImageID = map.imageID(x: x, y: y) else { return nil }
        if let direct = spriteArchives.lazy.compactMap({
            $0.sprite(globalImageID: globalImageID)
        }).first {
            return direct
        }
        // Banpo stores many cliff/slope faces as elevation object IDs rather
        // than direct China_Elevation globals. Resolve those before any grass
        // fallback paints over the cliff bed.
        if globalImageID & EmperorMap.chinaElevationObjectImageFlag != 0,
           let elevationArchive = spriteArchives.first(where: {
                $0.globalImageBase == EmperorMap.chinaElevationGlobalImageBase
           }),
           let localID = map.chinaElevationSpriteID(
               x: x,
               y: y,
               imageCount: elevationArchive.imageCount
           ) {
            return elevationArchive.sprites[localID]
        }
        return nil
    }

    /// Resolves only authored elevation artwork. This distinction matters
    /// because ordinary fertile cells also carry a direct, bare-soil terrain
    /// image: drawing that record as the final layer erases the original
    /// fertility grass, while cliff transition records must win over it.
    func elevationSprite(x: Int, y: Int) -> RenderedTerrainSprite? {
        guard let globalImageID = map.imageID(x: x, y: y),
              let elevationArchive = spriteArchives.first(where: {
                  $0.globalImageBase == EmperorMap.chinaElevationGlobalImageBase
              }) else { return nil }

        if let direct = elevationArchive.sprite(globalImageID: globalImageID) {
            return direct
        }
        guard globalImageID & EmperorMap.chinaElevationObjectImageFlag != 0 else {
            return nil
        }
        guard let localID = map.chinaElevationSpriteID(
            x: x,
            y: y,
            imageCount: elevationArchive.imageCount
        ) else { return nil }
        return elevationArchive.sprites[localID]
    }

    /// A stable grass variation used underneath legacy object records whose
    /// high-bit map image encoding has not yet been resolved to a standalone
    /// SG3 overlay. This preserves the original land bed instead of leaving a
    /// flat empty diamond in otherwise continuous terrain.
    func baseLandSprite(x: Int, y: Int) -> RenderedTerrainSprite? {
        let localID = 238 + abs(x &* 31 &+ y &* 17) % 9
        return spriteArchives.first {
            $0.globalImageBase == EmperorMap.chinaTerrainGlobalImageBase
        }?.vegetationSprites[localID]
    }

    func treeSprite(x: Int, y: Int) -> RenderedTerrainSprite? {
        let localID = 927 + abs(x &* 13 &+ y &* 29) % 18
        return spriteArchives.first {
            $0.globalImageBase == EmperorMap.chinaTerrainGlobalImageBase
        }?.sprites[localID]
    }

    /// Reuses the authored road family for player-built roads. Prefer an exact
    /// N/E/S/W topology match; sparse tutorial maps fall back to the closest
    /// authored connection shape, then to the shared China_Terrain dirt-road
    /// family so Banpo-style maps without authored roads still get real tiles.
    func roadSprite(connectionMask: Int) -> RenderedTerrainSprite? {
        if let exact = roadSpritesByConnectionMask[connectionMask] {
            return exact
        }
        if let nearest = roadSpritesByConnectionMask.min(by: { lhs, rhs in
            let lhsDistance = (lhs.key ^ connectionMask).nonzeroBitCount
            let rhsDistance = (rhs.key ^ connectionMask).nonzeroBitCount
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return lhs.key < rhs.key
        })?.value {
            return nearest
        }
        let localID = OriginalInterfaceUtilitySpriteCatalog.defaultRoadLocalID(
            forConnectionMask: connectionMask
        )
        return spriteArchives.first {
            $0.globalImageBase == EmperorMap.chinaTerrainGlobalImageBase
        }?.sprites[localID]
    }

    /// Dirt-road tile used by the infrastructure category rail and road tool.
    func roadToolIconSprite() -> RenderedTerrainSprite? {
        if let exact = roadSpritesByConnectionMask[0]
            ?? roadSpritesByConnectionMask[5]
            ?? roadSpritesByConnectionMask.values.first {
            return exact
        }
        return spriteArchives.first {
            $0.globalImageBase == EmperorMap.chinaTerrainGlobalImageBase
        }?.sprites[OriginalInterfaceUtilitySpriteCatalog.roadTerrainLocalID]
    }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case city = "城市"
    case campaigns = "战役"
    case saves = "存档"
    case maps = "资料"

    var id: Self { self }
}

private enum ClassicPlayerAccountStore {
    static let accountsKey = "EmperorNative.playerAccounts"
    static let selectedKey = "EmperorNative.selectedPlayerAccount"

    static func loadAccounts() -> [String] {
        UserDefaults.standard.stringArray(forKey: accountsKey) ?? []
    }

    static func saveAccounts(_ accounts: [String]) {
        UserDefaults.standard.set(accounts, forKey: accountsKey)
    }

    static func loadSelected() -> String? {
        UserDefaults.standard.string(forKey: selectedKey)
    }

    static func saveSelected(_ name: String?) {
        UserDefaults.standard.set(name, forKey: selectedKey)
    }
}

@MainActor
final class LibraryModel: ObservableObject {
    private struct AutosaveFingerprint: Equatable {
        let campaignFileName: String?
        let missionIndex: Int?
        let tickSequence: UInt64
    }

    enum State {
        case loading
        case loaded(GameDataSource, GameDataCatalog, [MapProbe], [ModelFileSummary], OriginalEconomyModels, [CampaignArchive])
        case failed(String)
    }

    @Published var state: State = .loading
    // Classic FE entry precedes the campaign browser unless a UI-smoke harness
    // asks to jump straight into the playable shell.
    @Published var frontEndStage: ClassicFrontEndStage = LibraryModel.initialFrontEndStage
    @Published var playerAccounts: [String] = ClassicPlayerAccountStore.loadAccounts()
    @Published var selectedPlayerAccount: String? = ClassicPlayerAccountStore.loadSelected()
    @Published var selectedDifficulty: GameDifficulty = .normal
    // Launch into the playable campaign browser. Map/model diagnostics remain
    // available, but are no longer the first thing a player sees.
    @Published var section: LibrarySection = .campaigns
    @Published var selectedMap: MapProbe?
    @Published private(set) var selectedMapURL: URL?
    @Published var selectedCampaign: CampaignArchive?
    @Published var embeddedCampaignMaps: [EmbeddedCampaignMap] = []
    @Published var campaignMissionMaps: CampaignMissionMapArchive?
    @Published var isResolvingCampaignMaps = false
    @Published var campaignMissionSettings: CampaignMissionSettingsArchive?
    @Published var isResolvingCampaignSettings = false
    @Published var campaignGoalArchive: CampaignGoalArchive?
    @Published var isResolvingCampaignGoals = false
    @Published var campaignEventArchive: CampaignEventArchive?
    @Published var isResolvingCampaignEvents = false
    @Published var campaignEmpireMap: CampaignEmpireMap?
    @Published var isResolvingCampaignEmpire = false
    @Published var cityNames: OriginalCityNameCatalog?
    @Published var selectedMissionID: Int?
    @Published var activeMissionWorld: CampaignMissionWorldState?
    @Published var cityState: DeterministicCityState?
    @Published var latestTick: CityTickResult?
    @Published var latestSettlement: MonthlySettlement?
    @Published var campaignRuntimeState: CampaignMissionRuntimeState?
    @Published var latestCampaignAdvance: CampaignMissionAdvanceResult?
    @Published var audioCatalog: OriginalAudioCatalog?
    @Published var musicIsPlaying = false
    @Published var saveStatus: String?
    @Published private(set) var saveHistory: [NativeSaveHistoryEntry] = []
    @Published private(set) var isAutosaving = false
    @Published private(set) var lastAutosaveDate: Date?
    @Published var constructionTool: NativeConstructionTool = .inspect
    @Published var constructionOrientation: IsometricBuildingOrientation = .northSouth
    @Published var selectedAgriculturalCrop: AgriculturalCrop = .wheat
    /// Empty means all surviving formations. Non-empty sets are controlled by
    /// clicking formation markers while the rally tool is active.
    @Published var selectedMilitaryUnitIDs: Set<Int> = []
    /// 0 = paused, 1/2/3 = auto-advance speed. Speed changes wall-clock
    /// frequency only; every callback advances exactly one deterministic day.
    @Published var gameSpeed: Int = 0
    var lastCityTickPresentationDate = Date()
    /// Drives the auto-advance loop while `gameSpeed > 0`.
    private var speedTimerCancellable: AnyCancellable?
    @Published var renderedMap: RenderedMap?
    @Published var buildingSprites: [BuildingSpriteReference: RenderedTerrainSprite] = [:]
    @Published var figureSprites: [FigureSpriteReference: RenderedTerrainSprite] = [:]
    @Published var interfaceSprites: [Int: RenderedTerrainSprite] = [:]
    /// Resource deposit overlays currently highlighted on the city canvas.
    @Published var activeResourceOverlays: Set<ResourceOverlayKind> = []
    private var mapLoadGeneration = 0
    private var mapSelectionGeneration = 0
    private var campaignMapLoadGeneration = 0
    private var campaignSettingsLoadGeneration = 0
    private var campaignGoalLoadGeneration = 0
    private var campaignEventLoadGeneration = 0
    private var campaignEmpireLoadGeneration = 0
    private var musicPlayer: AVAudioPlayer?
    private var effectPlayer: AVAudioPlayer?
    private var lastSaveURL: URL?
    private var lastAutosaveFingerprint: AutosaveFingerprint?
    private var gameplayController: GameSessionController?

    var dataSourceRoot: URL? {
        if case let .loaded(source, _, _, _, _, _) = state {
            return source.root
        }
        return nil
    }

    private static var initialFrontEndStage: ClassicFrontEndStage {
        ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-smoke") })
            ? .play
            : .mainMenu
    }

    func createPlayerAccount(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if !playerAccounts.contains(name) {
            playerAccounts.append(name)
            ClassicPlayerAccountStore.saveAccounts(playerAccounts)
        }
        selectedPlayerAccount = name
        ClassicPlayerAccountStore.saveSelected(name)
        saveStatus = "已创建玩家帐号：\(name)"
    }

    func deleteSelectedPlayerAccount() {
        guard let selected = selectedPlayerAccount else { return }
        playerAccounts.removeAll { $0 == selected }
        ClassicPlayerAccountStore.saveAccounts(playerAccounts)
        selectedPlayerAccount = playerAccounts.first
        ClassicPlayerAccountStore.saveSelected(selectedPlayerAccount)
        saveStatus = "已删除玩家帐号：\(selected)"
    }

    func confirmSelectedPlayerAccount() {
        guard let selected = selectedPlayerAccount else { return }
        ClassicPlayerAccountStore.saveSelected(selected)
        frontEndStage = .accountHome
        saveStatus = "当前统治者：\(selected)"
    }

    func enterPlaySection(_ section: LibrarySection) {
        self.section = section
        frontEndStage = .play
    }

    func returnToClassicFrontEnd() {
        frontEndStage = .accountHome
        section = .campaigns
        cityState = nil
        selectedMissionID = nil
        campaignRuntimeState = nil
    }

    func load() {
        state = .loading
        Task.detached(priority: .userInitiated) {
            do {
                let source = try GameDataSource.openDefault()
                let catalog = try GameDataCatalog.scan(source)
                let models = try ModelCatalog.scan(source)
                let economy = try OriginalEconomyModels(source: source)
                let audio = try OriginalAudioCatalog(source: source)
                let cityNames = try OriginalCityNameCatalog(
                    contentsOf: source.root.appendingPathComponent("EmperorText.eng")
                )
                let campaigns = try CampaignCatalog.load(source)
                let defaultCampaign = campaigns.first {
                    $0.url.lastPathComponent == "1 Xia Dynasty - Tutorials.pak"
                } ?? campaigns.first
                let gameplayController = try GameSessionController(source: source)
                let probes = try catalog.maps.prefix(24).map { try MapProbe(url: $0.url) }
                await MainActor.run {
                    self.selectedMap = probes.first
                    self.selectedMapURL = probes.first?.url
                    self.selectedCampaign = defaultCampaign
                    self.cityState = Self.makeSampleCity(models: economy)
                    self.audioCatalog = audio
                    self.cityNames = cityNames
                    self.gameplayController = gameplayController
                    self.state = .loaded(source, catalog, probes, models, economy, campaigns)
                    self.loadBuildingSprites(dataDirectory: source.dataDirectory)
                    self.loadFigureSprites(dataDirectory: source.dataDirectory)
                    self.loadInterfaceSprites(dataDirectory: source.dataDirectory)
                    if let first = probes.first {
                        self.loadRenderedMap(first, dataDirectory: source.dataDirectory)
                    }
                    if let defaultCampaign {
                        self.loadEmbeddedMaps(defaultCampaign, candidates: catalog.maps.map(\.url))
                        self.loadCampaignSettings(defaultCampaign)
                        self.loadCampaignGoals(defaultCampaign)
                        self.loadCampaignEvents(defaultCampaign)
                        self.loadCampaignEmpire(defaultCampaign)
                        if ProcessInfo.processInfo.arguments.contains("--ui-smoke-auto-start-xia"),
                           let firstMission = defaultCampaign.missions.first {
                            self.startMission(firstMission)
                        }
                    }
                    self.refreshSaveHistory()
                }
            } catch {
                NativeDiagnostics.record("Original data indexing failed", error: error)
                await MainActor.run { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    func toggleResourceOverlay(_ kind: ResourceOverlayKind) {
        if activeResourceOverlays.contains(kind) {
            activeResourceOverlays.remove(kind)
        } else {
            activeResourceOverlays.insert(kind)
        }
    }

    func beginMapMonument(buildingID: Int) {
        if let controller = gameplayController,
           controller.selectedCampaignID != nil,
           controller.selectedMissionID == selectedMissionID {
            let result = controller.perform(.beginMapMonument(buildingID: buildingID))
            syncFromGameplayController()
            saveStatus = result.message
            return
        }
        guard var city = cityState,
              city.beginMapMonument(buildingID: buildingID) != nil else {
            saveStatus = "地图纪念碑不可用或已经开工"
            return
        }
        cityState = city
        saveStatus = "地图纪念碑 #\(buildingID) 已开工"
    }

    func selectConstructionTool(_ tool: NativeConstructionTool) {
        if let buildingID = tool.buildingID,
           let restriction = cityState?.campaignConstructionRestriction(
               forBuildingID: buildingID
           ) {
            constructionTool = .inspect
            saveStatus = campaignRestrictionMessage(restriction, tool: tool)
            return
        }
        constructionTool = tool
        if let playerTool = playerConstructionTool(for: tool) {
            if tool == .farmland {
                _ = gameplayController?.perform(
                    .selectAgriculturalCrop(selectedAgriculturalCrop)
                )
            }
            _ = gameplayController?.perform(.selectConstruction(playerTool))
        }
        if tool == .inspect {
            saveStatus = "浏览模式：拖动画布移动视野"
        } else if tool == .demolish {
            saveStatus = "拆除工具：点击或拖动一片区域拆除建筑、住宅或道路；右键取消"
        } else if tool == .clearLand {
            saveStatus = "清理树木：点击或拖动一片区域清除树木与灌木；右键取消"
        } else if tool == .road {
            saveStatus = "道路工具：在清地上点击或拖动铺路，每格使用原版造价；右键取消"
        } else if tool == .rally {
            saveStatus = "部队集结：点击军队标记选择编队，再点击可通行地面下令；右键取消"
        } else if tool == .house {
            saveStatus = "住宅工具：点击建造 2×2 住宅，或拖动区域连续建造；右键取消"
        } else if tool == .farmland {
            saveStatus = "\(selectedAgriculturalCrop.fieldTitle)：点击清地种植 1 格，须邻接道路；右键取消"
        } else if tool == .cityWall {
            saveStatus = "城墙：逐格建造；可跨过既有道路以便改建城门；右键取消"
        } else if tool == .gatehouse {
            saveStatus = "城门：占地 5×3；先铺直墙，再让道路垂直贯穿中央；右键取消"
        } else if tool == .tower {
            saveStatus = "城防塔：占地 2×2；四格都须先建城墙并部署两名哨兵；右键取消"
        } else if let buildingID = tool.buildingID,
                  let footprint = OriginalBuildingFootprintCatalog.footprint(
                    forBuildingID: buildingID,
                    orientation: constructionOrientation
                  ) {
            saveStatus = "\(tool.title)：占地 \(footprint.width)×\(footprint.height)，必须邻接道路；右键取消"
        }
    }

    func selectAgriculturalCrop(_ crop: AgriculturalCrop) {
        guard cityState?.isAgriculturalCropAvailable(crop) ?? true else {
            saveStatus = "\(crop.fieldTitle)：本关暂未开放"
            return
        }
        selectedAgriculturalCrop = crop
        constructionTool = .farmland
        _ = gameplayController?.perform(.selectAgriculturalCrop(crop))
        _ = gameplayController?.perform(.selectConstruction(.farmland))
        saveStatus = "\(crop.fieldTitle)：点击清地种植 1 格，须邻接道路；右键取消"
    }

    func cancelCurrentInteraction() {
        let previousTool = constructionTool
        let hadMilitarySelection = !selectedMilitaryUnitIDs.isEmpty
        selectedMilitaryUnitIDs.removeAll()

        guard previousTool != .inspect else {
            if hadMilitarySelection {
                saveStatus = "已清除编队选择"
            }
            return
        }
        selectConstructionTool(.inspect)
        saveStatus = "已取消\(previousTool.title)，切换到浏览模式"
    }

    func rotateConstructionTool() {
        guard constructionTool.supportsRotation else {
            saveStatus = "\(constructionTool.title)为对称占地，无需旋转"
            return
        }
        constructionOrientation = constructionOrientation == .northSouth ? .eastWest : .northSouth
        selectConstructionTool(constructionTool)
        let footprintDescription: String
        if let buildingID = constructionTool.buildingID,
           let footprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: buildingID,
            orientation: constructionOrientation
           ) {
            footprintDescription = " · 占地 \(footprint.width)×\(footprint.height)"
        } else {
            footprintDescription = ""
        }
        saveStatus = "已将\(constructionTool.title)旋转为\(constructionOrientation.localizedTitle)"
            + footprintDescription
    }

    func placeConstruction(at point: GridPoint) {
        guard case let .loaded(_, _, _, _, models, _) = state,
              var city = cityState else { return }
        let rules = EconomyRulesEngine(models: models)
        if let controller = gameplayController,
           controller.selectedCampaignID != nil,
           controller.selectedMissionID == selectedMissionID,
           let playerTool = playerConstructionTool(for: constructionTool) {
            if playerTool == .farmland {
                _ = controller.perform(
                    .selectAgriculturalCrop(selectedAgriculturalCrop)
                )
            }
            _ = controller.perform(.selectConstruction(playerTool))
            let result: PlayerCommandResult = playerTool == .demolish
                ? controller.perform(.demolish(at: point))
                : controller.perform(.placeSelectedConstruction(
                    at: point,
                    orientation: constructionOrientation
                ))
            syncFromGameplayController()
            saveStatus = playerCommandStatus(
                result,
                tool: constructionTool,
                at: point
            )
            if result.wasApplied, let buildingID = playerTool.buildingID {
                playOriginalBuildingSound(buildingID)
            }
            return
        }
        switch constructionTool {
        case .inspect:
            return
        case .demolish:
            let outcome = city.demolish(at: point, rules: rules)
            switch outcome {
            case let .building(buildingID, refund):
                saveStatus = "已在 \(point.x), \(point.y) 拆除建筑 #\(buildingID) · 返还 \(refund) · 国库 \(city.economy.treasury)"
            case let .house(refund):
                saveStatus = "已在 \(point.x), \(point.y) 拆除住宅 · 返还 \(refund) · 国库 \(city.economy.treasury)"
            case let .road(refund):
                saveStatus = "已在 \(point.x), \(point.y) 拆除道路 · 返还 \(refund) · 国库 \(city.economy.treasury)"
            case .nothing:
                saveStatus = "目标格没有可拆除的建筑、住宅或道路"
            }
            cityState = city
            return
        case .clearLand:
            guard city.clearVegetation(at: point) else {
                saveStatus = "目标格没有可清理的树木或灌木"
                return
            }
            saveStatus = "已清理 \(point.x), \(point.y) 的树木与灌木"
        case .road:
            guard city.canConstructRoad(at: point) else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            guard city.buildRoad([point], rules: rules) == 1 else {
                saveStatus = "无法铺路：国库不足"
                return
            }
            saveStatus = "已在 \(point.x), \(point.y) 铺设道路 · 国库 \(city.economy.treasury)"
        case .rally:
            if let unit = city.military.units
                .filter({ $0.status != .destroyed && $0.currentPoint == point })
                .sorted(by: { $0.id < $1.id })
                .first {
                if selectedMilitaryUnitIDs.contains(unit.id) {
                    selectedMilitaryUnitIDs.remove(unit.id)
                } else {
                    selectedMilitaryUnitIDs.insert(unit.id)
                }
                let count = selectedMilitaryUnitIDs.count
                saveStatus = count == 0
                    ? "已清除编队选择；下一道命令将调动全部存活部队"
                    : "已选择 \(count) 支编队"
                return
            }
            let liveIDs = Set(city.military.units.filter { $0.hitPoints > 0 }.map(\.id))
            selectedMilitaryUnitIDs.formIntersection(liveIDs)
            let ordered = city.issueMilitaryOrder(
                unitIDs: selectedMilitaryUnitIDs,
                to: point,
                models: models.figures
            )
            guard ordered > 0 else {
                saveStatus = "无法集结：目标不可通行或没有存活部队"
                return
            }
            saveStatus = "已命令 \(ordered) 支部队向 \(point.x), \(point.y) 集结"
        case .house:
            guard city.canConstructHouse(at: point) else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            guard city.constructHouse(
                location: point,
                orientation: constructionOrientation,
                rules: rules
            ) != nil else {
                saveStatus = "无法建造住宅：国库不足"
                return
            }
            saveStatus = "已在 \(point.x), \(point.y) 建造住宅 · 国库 \(city.economy.treasury)"
        case .eliteHouse:
            guard city.constructHouse(
                levelID: 8,
                constructionBuildingID: 11,
                location: point,
                orientation: constructionOrientation,
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = "已在 \(point.x), \(point.y) 建造贵族住宅 · 国库 \(city.economy.treasury)"
        case .warehouse, .granary:
            guard city.constructWarehouse(
                at: point,
                orientation: constructionOrientation,
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .mill:
            guard city.constructMill(
                at: point,
                orientation: constructionOrientation,
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .market:
            guard city.constructMarket(
                at: point,
                orientation: constructionOrientation,
                shopBuildingIDs: [OriginalFoodCatalog.foodShopBuildingID],
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .grandMarket:
            guard city.constructMarket(
                at: point,
                orientation: constructionOrientation,
                marketBuildingID: OriginalMarketCatalog.grandMarketBuildingID,
                shopBuildingIDs: [
                    OriginalFoodCatalog.foodShopBuildingID, 65, 67, 68, 69, 70,
                ],
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .clayPit, .kiln, .fishingWharf, .huntingCamp, .quarry, .lumberMill,
             .ironMine, .bronzeWorks, .jadeWorkshop, .lacquerGuild, .silkWeaver, .teaHouse,
             .lacquerwareWorkshop, .weaver:
            guard let buildingID = constructionTool.buildingID,
                  models.buildings[buildingID: buildingID] != nil,
                  city.constructProductionBuilding(
                    buildingID: buildingID,
                    at: point,
                    orientation: constructionOrientation,
                    assignedWorkers: 0,
                    rules: rules
                  ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .taxOffice:
            guard city.constructTaxOffice(
                at: point,
                orientation: constructionOrientation,
                replaySeed: serviceReplaySeed(at: point, city: city),
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .roadblock:
            guard city.constructRoadBlock(at: point, rules: rules) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .farmland:
            guard city.constructAgriculturalPlot(
                crop: selectedAgriculturalCrop,
                at: point,
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = "已在 \(point.x),\(point.y) 种植\(selectedAgriculturalCrop.fieldTitle)"
        case .irrigationPump:
            guard city.constructIrrigationPump(
                at: point,
                orientation: constructionOrientation,
                rules: rules
            ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .grandCanalSegment:
            guard let segment = city.advanceGrandCanalSegment(at: point) else {
                saveStatus = "该运河段尚不能推进：请先交付木材、石料并完成相应工期"
                return
            }
            saveStatus = "郑国渠第 \(segment + 1) 段施工阶段已推进"
        case .earthenGreatWallSegment:
            guard let segment = city.advanceEarthenGreatWallSegment(at: point) else {
                saveStatus = "该土长城段尚不能推进：请先进口石料、交付木材并完成相应工期"
                return
            }
            saveStatus = "土长城第 \(segment + 1) 段施工阶段已推进"
        case .largePalacePhase:
            guard let phase = city.advanceLargePalacePhase(at: point) else {
                saveStatus = "大宫殿下一相位尚不能推进：请先交付材料并完成相应工期"
                return
            }
            saveStatus = "大宫殿施工已推进至第 \(phase)/\(LargePalaceProjectRuntime.phaseCount) 相位"
        case .barracks, .fort, .catapultFort, .cavalryFort, .chariotFort:
            guard let buildingID = constructionTool.buildingID,
                  city.constructMilitaryFort(
                    buildingID: buildingID,
                    at: point,
                    orientation: constructionOrientation,
                    rules: rules
                  ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .cityWall, .gatehouse, .tower:
            guard let buildingID = constructionTool.buildingID,
                  city.constructMilitaryDefense(
                    buildingID: buildingID,
                    at: point,
                    orientation: constructionOrientation,
                    rules: rules
                  ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .garden, .decorativeSculpture, .ornateSculpture, .floweringTree,
             .waysidePavilion, .pond, .taiChiPark, .privateGarden,
             .administrativeCity, .palace,
             .laborersCamp, .carpentersGuild, .masonsGuild, .ceramistsGuild,
             .tumulus, .grandTumulus, .greatTemple, .splendidTemple, .grandPagoda,
             .largePalace:
            guard let buildingID = constructionTool.buildingID,
                  city.constructAestheticBuilding(
                    buildingID: buildingID,
                    at: point,
                    orientation: constructionOrientation,
                    rules: rules
                  ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        case .well, .herbalist, .acupuncture, .inspectorTower, .musicSchool, .acrobatSchool,
             .dramaSchool, .ancestralShrine, .confucianAcademy, .daoistShrine,
             .bathhouse, .magistrate, .watchtower:
            guard let buildingID = constructionTool.buildingID,
                  city.constructResidentialServiceBuilding(
                    buildingID: buildingID,
                    at: point,
                    orientation: constructionOrientation,
                    replaySeed: serviceReplaySeed(at: point, city: city),
                    rules: rules
                  ) != nil else {
                saveStatus = constructionFailure(at: point, city: city, tool: constructionTool)
                return
            }
            saveStatus = constructionSuccess(at: point, city: city, tool: constructionTool)
        }
        cityState = city
        if constructionTool == .farmland {
            playOriginalBuildingSound(selectedAgriculturalCrop.producerBuildingID)
        } else if let buildingID = constructionTool.buildingID {
            playOriginalBuildingSound(buildingID)
        }
    }

    func placeConstructions(at points: [GridPoint]) {
        guard !points.isEmpty else { return }
        var applied = 0
        var lastFailure: String?
        for point in points {
            let before = cityState
            placeConstruction(at: point)
            if cityState != before {
                applied += 1
            } else {
                lastFailure = saveStatus
            }
        }
        if applied > 0 {
            saveStatus = "区域操作完成：\(constructionTool.title) \(applied)/\(points.count) 处成功"
                + (applied < points.count ? "，其余位置被地形、道路、占地或国库条件阻挡" : "")
        } else {
            saveStatus = lastFailure ?? "所选区域没有可执行的位置"
        }
    }

    func applyBuildingSetting(_ change: NativeBuildingSettingChange) {
        let command: PlayerCommand
        switch change {
        case let .productionEnabled(instanceID, enabled):
            command = .setProductionEnabled(
                buildingInstanceID: instanceID,
                enabled: enabled
            )
        case let .warehousePolicy(warehouseID, policy):
            command = .setWarehousePolicy(
                warehouseID: warehouseID,
                policy: policy
            )
        case let .warehouseCommodityPolicy(warehouseID, commodityID, policy):
            command = .setWarehouseCommodityPolicy(
                warehouseID: warehouseID,
                commodityID: commodityID,
                policy: policy
            )
        case let .tradeEnabled(tradingBuildingID, enabled):
            command = .setTradeEnabled(
                tradingBuildingID: tradingBuildingID,
                enabled: enabled
            )
        }

        if let controller = gameplayController,
           controller.selectedCampaignID != nil,
           controller.selectedMissionID == selectedMissionID {
            let result = controller.perform(command)
            syncFromGameplayController()
            saveStatus = ClassicTextLocalization.statusMessage(result.message)
            return
        }

        guard var city = cityState else { return }
        let applied: Bool
        switch change {
        case let .productionEnabled(instanceID, enabled):
            applied = city.setProductionEnabled(
                enabled,
                buildingInstanceID: instanceID
            )
            saveStatus = enabled ? "生产设施已恢复运行" : "生产设施已暂停"
        case let .warehousePolicy(warehouseID, policy):
            guard case let .loaded(_, _, _, _, models, _) = state else { return }
            applied = city.setWarehousePolicy(
                policy,
                warehouseID: warehouseID,
                commodityIDs: models.trade.commodities.map(\.id)
            )
            saveStatus = "仓库模式已设为\(warehousePolicyTitle(policy))"
        case let .warehouseCommodityPolicy(warehouseID, commodityID, policy):
            guard case let .loaded(_, _, _, _, models, _) = state else { return }
            applied = city.setWarehousePolicy(
                policy,
                warehouseID: warehouseID,
                commodityIDs: [commodityID]
            )
            let commodity = models.trade.commodities
                .first(where: { $0.id == commodityID })
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "商品 #\(commodityID)"
            saveStatus = "\(commodity)已设为\(warehousePolicyTitle(policy))"
        case let .tradeEnabled(tradingBuildingID, enabled):
            applied = city.setTradeEnabled(
                enabled,
                tradingBuildingID: tradingBuildingID
            )
            saveStatus = enabled ? "贸易设施已恢复进出口" : "贸易设施已暂停进出口"
        }
        if applied {
            cityState = city
        } else {
            saveStatus = "建筑设置未能应用"
        }
    }

    private func warehousePolicyTitle(_ policy: WarehouseCommodityPolicy) -> String {
        switch policy {
        case .doNotAccept: "拒收"
        case .accept: "接收"
        case .get: "主动调取"
        }
    }

    func selectAllMilitaryUnits() {
        guard let city = cityState else { return }
        selectedMilitaryUnitIDs = Set(city.military.units.filter { $0.hitPoints > 0 }.map(\.id))
        saveStatus = "已选择全部 \(selectedMilitaryUnitIDs.count) 支存活编队"
    }

    func clearMilitaryUnitSelection() {
        selectedMilitaryUnitIDs.removeAll()
        saveStatus = "已清除编队选择；下一道命令将调动全部存活部队"
    }

    private func serviceReplaySeed(at point: GridPoint, city: DeterministicCityState) -> UInt64 {
        0x504C_4143_454D_454E
            ^ UInt64(point.x * 4_099 + point.y * 131)
            ^ UInt64(city.residentialServiceBuildings.count)
    }

    private func constructionSuccess(
        at point: GridPoint,
        city: DeterministicCityState,
        tool: NativeConstructionTool
    ) -> String {
        "已在 \(point.x), \(point.y) 建造\(tool.title) · 国库 \(city.economy.treasury)"
    }

    private func constructionFailure(
        at point: GridPoint,
        city: DeterministicCityState,
        tool: NativeConstructionTool
    ) -> String {
        guard city.roadNetwork.isInside(point) else { return "目标格超出可玩地图" }
        if tool == .farmland {
            guard city.isAgriculturalCropAvailable(selectedAgriculturalCrop) else {
                return "\(selectedAgriculturalCrop.fieldTitle)在本关暂未开放"
            }
            if city.canConstructAgriculturalPlot(
                crop: selectedAgriculturalCrop,
                at: point
            ) {
                return "无法种植\(selectedAgriculturalCrop.fieldTitle)：国库不足或农业模型不可用"
            }
            return "无法种植\(selectedAgriculturalCrop.fieldTitle)：目标格须为邻接道路的无碰撞清地"
        }
        if tool == .irrigationPump {
            if city.canConstructIrrigationPump(
                at: point,
                orientation: constructionOrientation
            ) {
                return "无法建造灌溉水车：国库不足或建筑模型配置不可用"
            }
            return "灌溉水车必须放在同时邻接水面与道路的河岸清地"
        }
        if let buildingID = tool.buildingID,
           let restriction = city.campaignConstructionRestriction(
               forBuildingID: buildingID
           ) {
            return campaignRestrictionMessage(restriction, tool: tool)
        }
        if tool == .roadblock {
            if city.canConstructRoadBlock(at: point) {
                return "无法建造路障：国库不足或建筑模型配置不可用"
            }
            if !city.roadNetwork.contains(point) {
                return "路障必须直接放在既有道路上"
            }
            return "无法建造路障：道路格已被其他建筑占用"
        }
        if let buildingID = tool.buildingID,
           OriginalMilitaryDefenseConfiguration.configuration(buildingID: buildingID) != nil {
            if city.canConstructMilitaryDefense(
                buildingID: buildingID,
                at: point,
                orientation: constructionOrientation
            ) {
                return "无法建造\(tool.title)：国库不足或人物模型配置不可用"
            }
            return switch tool {
            case .cityWall: "无法建造城墙：目标格须为清地或可修复的损毁城墙"
            case .gatehouse: "无法建造城门：5×3 占地中央须有五格直墙，并由三格道路垂直贯通"
            case .tower: "无法建造城防塔：完整 2×2 占地必须已经铺设城墙"
            default: "无法建造\(tool.title)"
            }
        }
        if city.roadNetwork.contains(point) { return "目标格已经是道路" }
        if city.occupiedBuildingPoints.contains(point) { return "目标格已有建筑" }
        if city.terrain?.isClearLand(point) == false { return "原版地形阻挡了建造" }
        if tool == .house,
           !RoadServiceCoverage.orthogonalNeighbors(of: point).contains(where: city.roadNetwork.contains) {
            return "住宅必须紧邻道路"
        }
        if tool == .well,
           let footprint = OriginalBuildingFootprintCatalog.footprint(
            forBuildingID: 72,
            orientation: constructionOrientation
           ), footprint.points(at: point).contains(where: {
               city.terrain?.terrain(at: $0)?.contains(.groundwater) == false
           }) {
            return "水井的完整占地必须位于原版地下水层上"
        }
        if let buildingID = tool.buildingID {
            if !city.canConstructBuilding(
                buildingID: buildingID,
                at: point,
                orientation: constructionOrientation
            ) {
                return "无法建造\(tool.title)：完整占地必须是无碰撞清地，并至少一边邻接道路"
            }
            return "无法建造\(tool.title)：国库不足或建筑模型配置不可用"
        }
        return "目标格目前不能建造"
    }

    private func playerCommandStatus(
        _ result: PlayerCommandResult,
        tool: NativeConstructionTool,
        at point: GridPoint
    ) -> String {
        if result.wasApplied {
            return switch tool {
            case .demolish:
                "已在 \(point.x), \(point.y) 拆除目标"
            case .clearLand:
                "已清理 \(point.x), \(point.y) 的树木与灌木"
            case .road:
                "已在 \(point.x), \(point.y) 铺设道路"
            case .farmland:
                "已在 \(point.x), \(point.y) 种植\(selectedAgriculturalCrop.fieldTitle)"
            default:
                "已在 \(point.x), \(point.y) 建造\(tool.title)"
            }
        }
        if campaignRuntimeState?.outcome != .running {
            return "任务已经结束，不能继续建造"
        }
        switch tool {
        case .demolish:
            return "目标格没有可拆除的建筑、住宅或道路"
        case .clearLand:
            return "目标格没有可清理的树木或灌木"
        default:
            guard let city = cityState else { return "当前没有可操作的城市" }
            return constructionFailure(at: point, city: city, tool: tool)
        }
    }

    private func campaignRestrictionMessage(
        _ restriction: CampaignConstructionRestriction,
        tool: NativeConstructionTool
    ) -> String {
        campaignRestrictionMessage(restriction, buildingTitle: tool.title)
    }

    private func campaignRestrictionMessage(
        _ restriction: CampaignConstructionRestriction,
        buildingTitle: String
    ) -> String {
        switch restriction {
        case let .buildingNotAllowed(menuID, _):
            return "本关不允许建造\(buildingTitle)（原版建筑许可 #\(menuID)）"
        case let .localResourceNotAllowed(commodityID):
            return "本关没有建造\(buildingTitle)所需的本地资源 #\(commodityID)"
        case let .requiredInputsUnavailable(options):
            let descriptions = options.map { $0.map(String.init).joined(separator: "+") }
                .joined(separator: " 或 ")
            return "本关无法取得\(buildingTitle)所需原料（\(descriptions)）"
        }
    }

    func setTaxBand(_ bandID: Int) {
        guard var city = cityState else { return }
        city.taxBandID = bandID
        cityState = city
    }

    func advanceCityTick() {
        if let controller = gameplayController,
           controller.selectedMissionID == selectedMissionID,
           controller.selectedCampaignID != nil {
            let result = controller.perform(.advanceOneTick)
            if result.wasApplied { lastCityTickPresentationDate = Date() }
            syncFromGameplayController()
            if controller.latestTick?.monthlySettlement != nil {
                autosaveIfNeeded()
            }
            if !result.wasApplied {
                saveStatus = ClassicTextLocalization.statusMessage(result.message)
            }
            if let changed = controller.latestCampaignAdvance?.outcomeChangedNow {
                switch changed {
                case .running: break
                case .victory: saveStatus = "任务目标已达成；任务完成事件已执行"
                case let .defeat(record):
                    saveStatus = "连续负债 36 个月，任务失败；国库 \(record.treasury)"
                }
            }
            return
        }
        guard case let .loaded(_, _, _, _, models, _) = state,
              var city = cityState else { return }
        if let runtime = campaignRuntimeState, runtime.outcome != .running {
            setGameSpeed(0)
            return
        }
        let rules = EconomyRulesEngine(models: models)
        let tick = city.advanceTick(rules: rules)
        latestTick = tick
        if let settlement = tick.monthlySettlement {
            latestSettlement = settlement
            advanceCampaignAfterSettlement(
                settlement,
                city: &city,
                rules: rules
            )
        }
        lastCityTickPresentationDate = Date()
        cityState = city
        if tick.monthlySettlement != nil {
            autosaveIfNeeded()
        }
    }

    private func advanceCampaignAfterSettlement(
        _ settlement: MonthlySettlement,
        city: inout DeterministicCityState,
        rules: EconomyRulesEngine
    ) {
        if var runtime = campaignRuntimeState, runtime.missionID == selectedMissionID {
            let goalSet = campaignGoalArchive?.missions.first { $0.id == runtime.missionID }
            let result = runtime.advance(
                settlementYear: settlement.year,
                month: settlement.month,
                city: &city,
                rules: rules,
                goalSet: goalSet
            )
            campaignRuntimeState = runtime
            latestCampaignAdvance = result
            if let changed = result.outcomeChangedNow {
                setGameSpeed(0)
                switch changed {
                case .running:
                    break
                case .victory:
                    saveStatus = "任务目标已达成；任务完成事件已执行"
                case let .defeat(record):
                    saveStatus = "连续负债 36 个月，任务失败；国库 \(record.treasury)"
                }
            } else if result.missionCompletedNow {
                saveStatus = "任务目标已达成；任务完成事件已执行"
            } else if !result.occurrences.isEmpty {
                saveStatus = "本月触发 \(result.occurrences.count) 条原版事件"
            } else if !result.expiredRequestIDs.isEmpty {
                saveStatus = "有 \(result.expiredRequestIDs.count) 项原版请求逾期"
            }
        }
    }

    func setGameSpeed(_ speed: Int) {
        let requested = max(0, min(3, speed))
        if let controller = gameplayController,
           controller.selectedCampaignID != nil,
           controller.selectedMissionID == selectedMissionID {
            let result = controller.perform(.setSpeed(requested))
            gameSpeed = controller.speed
            if !result.wasApplied {
                saveStatus = ClassicTextLocalization.statusMessage(result.message)
            }
            restartSpeedTimer()
            return
        }
        gameSpeed = campaignRuntimeState.map { $0.outcome == .running } ?? true
            ? requested : 0
        restartSpeedTimer()
    }

    private func restartSpeedTimer() {
        speedTimerCancellable?.cancel()
        speedTimerCancellable = nil
        guard gameSpeed > 0 else { return }
        let interval: TimeInterval
        switch gameSpeed {
        case 1: interval = 0.25
        case 2: interval = 0.125
        default: interval = 0.0625
        }
        speedTimerCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.advanceCityTick()
                }
            }
    }

    func fulfillFirstCampaignRequest() {
        guard var runtime = campaignRuntimeState,
              var city = cityState else { return }
        if runtime.fulfillFirstPendingRequest(city: &city) {
            campaignRuntimeState = runtime
            cityState = city
            saveStatus = "已交付最早到期的原版请求"
        } else {
            saveStatus = "库存或国库不足，暂时无法满足请求"
        }
    }

    func sendCampaignEmissary(to cityID: Int) {
        guard var runtime = campaignRuntimeState, var city = cityState else { return }
        if runtime.sendEmissary(to: cityID, city: &city) {
            campaignRuntimeState = runtime
            cityState = city
            saveStatus = "使者已抵达，好感提升 10"
        } else {
            saveStatus = "无法派遣使者：城市不可互动或国库不足 50"
        }
    }

    func sendCampaignSpy(to cityID: Int) {
        guard var runtime = campaignRuntimeState, var city = cityState else { return }
        if runtime.sendSpy(to: cityID, city: &city) {
            campaignRuntimeState = runtime
            cityState = city
            saveStatus = "间谍已抵达，可查看目标军力与经济实力"
        } else {
            saveStatus = "无法派遣间谍：城市不可互动或国库不足 100"
        }
    }

    func requestCampaignAlliance(with cityID: Int) {
        guard var runtime = campaignRuntimeState else { return }
        if runtime.requestAlliance(with: cityID) {
            campaignRuntimeState = runtime
            saveStatus = "联盟已经成立"
        } else {
            saveStatus = "结盟需要使者先抵达，且目标好感达到 60"
        }
    }

    func conquerCampaignCity(_ cityID: Int) {
        guard var runtime = campaignRuntimeState, let city = cityState else { return }
        if runtime.conquerCity(cityID, using: city) {
            campaignRuntimeState = runtime
            saveStatus = "目标城市已成为附庸"
        } else {
            saveStatus = "征服失败：需要存活部队，且六级军力城市不可征服"
        }
    }

    func prepayCampaignHomage() {
        guard var runtime = campaignRuntimeState, var city = cityState else { return }
        let heroID = runtime.empireState?.activeHeroIDs.sorted().first ?? 0
        if runtime.prepayHeroHomage(heroID: heroID, city: &city) {
            campaignRuntimeState = runtime
            cityState = city
            saveStatus = "已为英雄维持 1 个月香火；月末计入朝拜目标"
        } else {
            saveStatus = "国库不足 100，无法维持英雄香火"
        }
    }

    func requestCampaignMenagerieAnimal(from cityID: Int) {
        guard var runtime = campaignRuntimeState, let city = cityState else { return }
        if let speciesID = runtime.requestMenagerieAnimal(from: cityID, using: city) {
            campaignRuntimeState = runtime
            saveStatus = "异兽 #\(speciesID) 已进入宫殿动物园"
        } else {
            saveStatus = "索取异兽需要宫殿、已抵达的使者及至少 60 好感"
        }
    }

    func startNextMission() {
        guard campaignRuntimeState?.missionCompleted == true,
              let campaign = selectedCampaign,
              let missionID = selectedMissionID,
              let index = campaign.missions.firstIndex(where: { $0.id == missionID }),
              campaign.missions.indices.contains(index + 1) else {
            saveStatus = "当前已是战役最后一关，或任务目标尚未达成"
            return
        }
        startMission(campaign.missions[index + 1])
    }

    func replayMission() {
        autosaveIfNeeded(force: true)
        if let controller = gameplayController,
           controller.selectedCampaignID != nil,
           controller.selectedMissionID == selectedMissionID {
            let result = controller.perform(.replayMission)
            syncFromGameplayController()
            if result.wasApplied, let world = controller.activeWorld {
                selectedMap = try? MapProbe(url: world.mapAssignment.embeddedMap.mapURL)
                if case let .loaded(source, _, _, _, _, _) = state,
                   let selectedMap {
                    loadRenderedMap(selectedMap, dataDirectory: source.dataDirectory)
                }
                saveStatus = "已重玩当前任务"
            } else {
                saveStatus = ClassicTextLocalization.statusMessage(result.message)
            }
            return
        }
        guard let campaign = selectedCampaign,
              let missionID = selectedMissionID,
              let mission = campaign.missions.first(where: { $0.id == missionID }) else {
            saveStatus = "没有可重玩的当前任务"
            return
        }
        startMission(mission)
    }

    func returnToCampaignList() {
        autosaveIfNeeded(force: true)
        setGameSpeed(0)
        frontEndStage = .play
        section = .campaigns
    }

    func loadMostRecentSave() {
        guard let url = saveHistory.first(where: \.isReadable)?.url ?? lastSaveURL else {
            loadCity()
            return
        }
        loadCity(from: url)
    }

    func saveCity() {
        guard let save = currentNativeSave() else { return }
        do {
            let url = try NativeSaveHistoryStore.write(save, kind: .quickSave)
            lastSaveURL = url
            saveStatus = "快速存档完成：\(url.lastPathComponent)"
            refreshSaveHistory()
        } catch {
            NativeDiagnostics.record("Quick save failed", error: error)
            saveStatus = "快速存档失败：\(error.localizedDescription)"
        }
    }

    func saveCityAs() {
        guard let save = currentNativeSave() else { return }
        let panel = NSSavePanel()
        panel.title = "保存原生城市"
        panel.prompt = "保存"
        panel.nameFieldStringValue = "皇帝龙之崛起存档.emperor-save.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try NativeSaveGameStore.save(save, to: url)
            lastSaveURL = url
            saveStatus = "已保存：\(url.lastPathComponent)"
        } catch {
            NativeDiagnostics.record("Save failed", error: error)
            saveStatus = "保存失败：\(error.localizedDescription)"
        }
    }

    func loadCity() {
        let panel = NSOpenPanel()
        panel.title = "载入原生城市"
        panel.prompt = "载入"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        loadCity(from: url)
    }

    func loadSaveHistoryEntry(_ entry: NativeSaveHistoryEntry) {
        guard entry.isReadable else {
            saveStatus = "该存档已损坏，无法载入"
            return
        }
        loadCity(from: entry.url)
    }

    func deleteSaveHistoryEntry(_ entry: NativeSaveHistoryEntry) {
        do {
            try NativeSaveHistoryStore.remove(entry)
            if lastSaveURL == entry.url {
                lastSaveURL = nil
            }
            saveStatus = "已删除存档：\(entry.url.lastPathComponent)"
            refreshSaveHistory()
        } catch {
            NativeDiagnostics.record("Delete save failed", error: error)
            saveStatus = "删除存档失败：\(error.localizedDescription)"
        }
    }

    func refreshSaveHistory() {
        saveHistory = NativeSaveHistoryStore.entries()
        if lastSaveURL == nil {
            lastSaveURL = saveHistory.first(where: \.isReadable)?.url
        }
    }

    func autosaveIfNeeded(force: Bool = false) {
        guard section == .city,
              !isAutosaving,
              let save = currentNativeSave() else { return }
        let fingerprint = AutosaveFingerprint(
            campaignFileName: save.campaignFileName,
            missionIndex: save.missionIndex,
            tickSequence: save.city.simulationClock.tickSequence
        )
        guard force || fingerprint != lastAutosaveFingerprint else { return }

        isAutosaving = true
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                do {
                    return (
                        Optional(try NativeSaveHistoryStore.write(save, kind: .autosave)),
                        nil as String?
                    )
                } catch {
                    return (nil as URL?, error.localizedDescription)
                }
            }.value
            guard let self else { return }
            self.isAutosaving = false
            if let url = result.0 {
                self.lastSaveURL = url
                self.lastAutosaveDate = Date()
                self.lastAutosaveFingerprint = fingerprint
                self.refreshSaveHistory()
            } else if let message = result.1 {
                self.saveStatus = "自动存档失败：\(message)"
            }
        }
    }

    private func currentNativeSave() -> NativeSaveGame? {
        guard let city = cityState else { return nil }
        return NativeSaveGame(
            campaignFileName: selectedCampaign?.url.lastPathComponent,
            missionIndex: selectedMissionID,
            replaySeed: 0x454D_5045_524F_52,
            city: city,
            campaignRuntime: campaignRuntimeState
        )
    }

    private func loadCity(from url: URL) {
        do {
            let save = try NativeSaveGameStore.load(from: url)
            cityState = save.city
            constructionTool = .inspect
            constructionOrientation = .northSouth
            latestTick = nil
            latestSettlement = nil
            latestCampaignAdvance = nil
            if case let .loaded(_, _, _, _, _, campaigns) = state,
               let campaignFileName = save.campaignFileName,
               let campaign = campaigns.first(where: { $0.url.lastPathComponent == campaignFileName }) {
                selectedCampaign = nil
                select(campaign)
                selectedMissionID = save.missionIndex
            }
            campaignRuntimeState = save.campaignRuntime
            if let controller = gameplayController {
                let result = controller.restorePersistedSession(save)
                if result.wasApplied { syncFromGameplayController() }
            }
            lastSaveURL = url
            lastAutosaveFingerprint = AutosaveFingerprint(
                campaignFileName: save.campaignFileName,
                missionIndex: save.missionIndex,
                tickSequence: save.city.simulationClock.tickSequence
            )
            if save.campaignRuntime?.outcome != .running { setGameSpeed(0) }
            saveStatus = "已载入：\(url.lastPathComponent)"
            section = .city
        } catch {
            NativeDiagnostics.record("Load failed", error: error)
            saveStatus = "载入失败：\(error.localizedDescription)"
        }
    }

    func toggleOriginalMusic() {
        if musicIsPlaying {
            musicPlayer?.stop()
            musicPlayer = nil
            musicIsPlaying = false
            return
        }
        guard let track = audioCatalog?.music.first(where: { $0.category == .general }),
              let player = try? AVAudioPlayer(contentsOf: track.url) else { return }
        player.numberOfLoops = -1
        player.volume = 0.35
        player.prepareToPlay()
        musicIsPlaying = player.play()
        musicPlayer = player
    }

    func playOriginalBuildingSound(_ buildingID: Int) {
        guard let sound = audioCatalog?.sound(forBuildingID: buildingID),
              let player = try? AVAudioPlayer(contentsOf: sound.url) else { return }
        player.volume = Float(sound.volume)
        player.prepareToPlay()
        _ = player.play()
        effectPlayer = player
    }

    func select(_ probe: MapProbe?) {
        guard let probe, probe.url != selectedMap?.url else { return }
        selectedMap = probe
        selectedMapURL = probe.url
        guard case let .loaded(source, _, _, _, _, _) = state else { return }
        loadRenderedMap(probe, dataDirectory: source.dataDirectory)
    }

    func selectMapEntry(_ entry: GameDataCatalog.Entry) {
        guard entry.url != selectedMapURL else { return }
        mapSelectionGeneration += 1
        let generation = mapSelectionGeneration
        selectedMapURL = entry.url
        renderedMap = nil
        saveStatus = "正在读取地图：\(ClassicTextLocalization.mapName(entry.url))"
        Task.detached(priority: .userInitiated) {
            do {
                let probe = try MapProbe(url: entry.url)
                await MainActor.run {
                    guard generation == self.mapSelectionGeneration else { return }
                    self.select(probe)
                    self.saveStatus = "已载入地图：\(ClassicTextLocalization.mapName(entry.url))"
                }
            } catch {
                await MainActor.run {
                    guard generation == self.mapSelectionGeneration else { return }
                    NativeDiagnostics.record("Map selection failed", error: error)
                    self.saveStatus = "地图读取失败，请检查原版地图文件"
                }
            }
        }
    }

    func select(_ campaign: CampaignArchive?) {
        guard let campaign, campaign.url != selectedCampaign?.url else { return }
        selectedCampaign = campaign
        selectedMissionID = nil
        activeMissionWorld = nil
        campaignRuntimeState = nil
        latestCampaignAdvance = nil
        guard case let .loaded(_, catalog, _, _, _, _) = state else { return }
        loadEmbeddedMaps(campaign, candidates: catalog.maps.map(\.url))
        loadCampaignSettings(campaign)
        loadCampaignGoals(campaign)
        loadCampaignEvents(campaign)
        loadCampaignEmpire(campaign)
    }

    func startMission(_ mission: CampaignMission) {
        if let controller = gameplayController {
            _ = controller.perform(.selectDifficulty(selectedDifficulty))
        }
        if let controller = gameplayController,
           let campaign = selectedCampaign,
           let campaignID = controller.campaignID(fileName: campaign.url.lastPathComponent) {
            let result = controller.perform(
                .startCampaignMission(campaignID: campaignID, missionID: mission.id)
            )
            if result.wasApplied, let world = controller.activeWorld,
               case let .loaded(source, _, _, _, _, _) = state {
                selectedMissionID = mission.id
                activeMissionWorld = world
                syncFromGameplayController()
                constructionTool = .inspect
                constructionOrientation = .northSouth
                if let probe = try? MapProbe(url: world.mapAssignment.embeddedMap.mapURL) {
                    selectedMap = probe
                    loadRenderedMap(probe, dataDirectory: source.dataDirectory)
                }
                saveStatus = "已开始："
                    + "\(ClassicTextLocalization.missionTitle(mission.title))"
                    + " · \(ClassicTextLocalization.difficultyTitle(selectedDifficulty))"
                    + " · 国库 \(controller.city?.economy.treasury ?? 0)"
                    + " · \(ClassicTextLocalization.cityName(world.playerCityName))"
                frontEndStage = .play
                section = .city
                autosaveIfNeeded(force: true)
            } else {
                saveStatus = ClassicTextLocalization.statusMessage(result.message)
            }
            return
        }
        guard case let .loaded(source, _, _, _, models, _) = state,
              let missionMaps = campaignMissionMaps,
              let missionSettings = campaignMissionSettings,
              let eventSet = campaignEventArchive?.missions.first(where: { $0.id == mission.id }),
              let cityNames else { return }
        do {
            let world = try CampaignMissionWorldState(
                missionID: mission.id,
                missionSettings: missionSettings,
                missionMaps: missionMaps,
                empireMap: campaignEmpireMap,
                cityNames: cityNames,
                tradeRules: models.trade
            )
            let originalMap = try EmperorMap(url: world.mapAssignment.embeddedMap.mapURL)
            let canContinueExistingCity = world.mapAssignment.isContinuation
                && activeMissionWorld?.mapAssignment.embeddedMap.mapURL
                    == world.mapAssignment.embeddedMap.mapURL
                && cityState != nil
            var city: DeterministicCityState
            if canContinueExistingCity, var inherited = cityState {
                inherited.continueCampaignMission(with: world.startSettings)
                city = inherited
            } else {
                city = DeterministicCityState(
                    missionSettings: world.startSettings,
                    difficulty: selectedDifficulty,
                    map: originalMap
                )
            }
            _ = world.installTradePartners(
                in: &city,
                rules: EconomyRulesEngine(models: models)
            )
            let probe = try MapProbe(url: world.mapAssignment.embeddedMap.mapURL)
            selectedMissionID = mission.id
            activeMissionWorld = world
            cityState = city
            constructionTool = .inspect
            constructionOrientation = .northSouth
            latestTick = nil
            latestSettlement = nil
            campaignRuntimeState = CampaignMissionRuntimeState(
                missionID: mission.id,
                startYear: world.startSettings.startYear,
                startMonth: world.startSettings.startMonth,
                eventSet: eventSet,
                replaySeed: 0x454D_5045_524F_52,
                empireMap: campaignEmpireMap,
                playerCityID: world.playerCity?.id,
                cityNames: cityNames
            )
            latestCampaignAdvance = nil
            setGameSpeed(0)
            selectedMap = probe
            loadRenderedMap(probe, dataDirectory: source.dataDirectory)
            let yearLabel = world.startSettings.startYear < 0
                ? "公元前 \(-world.startSettings.startYear) 年"
                : "公元 \(world.startSettings.startYear) 年"
            let inheritanceLabel = world.mapAssignment.isContinuation
                ? (canContinueExistingCity ? " · 已继承前关整座城市" : " · 未找到可继承的前关城市")
                : ""
            saveStatus = "已开始：\(ClassicTextLocalization.missionTitle(mission.title))"
                + " · \(ClassicTextLocalization.difficultyTitle(selectedDifficulty))"
                + " · \(yearLabel) · 国库 \(city.economy.treasury)"
                + " · \(ClassicTextLocalization.cityName(world.playerCityName))"
                + " · \(world.tradePartners.count) 条原版贸易路线\(inheritanceLabel)"
            frontEndStage = .play
            section = .city
            autosaveIfNeeded(force: true)
        } catch {
            NativeDiagnostics.record("Mission initialization failed", error: error)
            saveStatus = "任务初始化失败，请检查原版战役资料"
        }
    }

    private func loadCampaignSettings(_ campaign: CampaignArchive) {
        campaignSettingsLoadGeneration += 1
        let generation = campaignSettingsLoadGeneration
        campaignMissionSettings = nil
        isResolvingCampaignSettings = true
        Task.detached(priority: .utility) {
            let archive = try? CampaignMissionSettingsArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            await MainActor.run {
                guard generation == self.campaignSettingsLoadGeneration else { return }
                self.campaignMissionSettings = archive
                self.isResolvingCampaignSettings = false
            }
        }
    }

    private func loadCampaignEmpire(_ campaign: CampaignArchive) {
        campaignEmpireLoadGeneration += 1
        let generation = campaignEmpireLoadGeneration
        campaignEmpireMap = nil
        isResolvingCampaignEmpire = true
        Task.detached(priority: .utility) {
            let empire = try? CampaignEmpireMap.loadIfPresent(campaignURL: campaign.url)
            await MainActor.run {
                guard generation == self.campaignEmpireLoadGeneration else { return }
                self.campaignEmpireMap = empire ?? nil
                self.isResolvingCampaignEmpire = false
            }
        }
    }

    private func loadCampaignEvents(_ campaign: CampaignArchive) {
        campaignEventLoadGeneration += 1
        let generation = campaignEventLoadGeneration
        campaignEventArchive = nil
        isResolvingCampaignEvents = true
        Task.detached(priority: .utility) {
            let archive = try? CampaignEventArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            await MainActor.run {
                guard generation == self.campaignEventLoadGeneration else { return }
                self.campaignEventArchive = archive
                self.isResolvingCampaignEvents = false
            }
        }
    }

    private func loadCampaignGoals(_ campaign: CampaignArchive) {
        campaignGoalLoadGeneration += 1
        let generation = campaignGoalLoadGeneration
        campaignGoalArchive = nil
        isResolvingCampaignGoals = true
        Task.detached(priority: .utility) {
            let archive = try? CampaignGoalArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            await MainActor.run {
                guard generation == self.campaignGoalLoadGeneration else { return }
                self.campaignGoalArchive = archive
                self.isResolvingCampaignGoals = false
            }
        }
    }

    private func loadEmbeddedMaps(_ campaign: CampaignArchive, candidates: [URL]) {
        campaignMapLoadGeneration += 1
        let generation = campaignMapLoadGeneration
        embeddedCampaignMaps = []
        campaignMissionMaps = nil
        isResolvingCampaignMaps = true
        Task.detached(priority: .utility) {
            let missionMaps = try? CampaignMissionMapArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count,
                candidateMapURLs: candidates
            )
            let matches = missionMaps?.embeddedMaps ?? ((try? CampaignEmbeddedMapResolver.resolve(
                campaignURL: campaign.url,
                candidateMapURLs: candidates
            )) ?? [])
            await MainActor.run {
                guard generation == self.campaignMapLoadGeneration else { return }
                self.embeddedCampaignMaps = matches
                self.campaignMissionMaps = missionMaps
                self.isResolvingCampaignMaps = false
            }
        }
    }

    private func loadRenderedMap(_ probe: MapProbe, dataDirectory: URL) {
        mapLoadGeneration += 1
        let generation = mapLoadGeneration
        renderedMap = nil
        Task.detached(priority: .userInitiated) {
            do {
                let map = try EmperorMap(url: probe.url)
                var decodedArchives: [DecodedMapSpriteArchive] = []
                for descriptor in mapSpriteArchiveDescriptors {
                    let archive = try SG3Archive(
                        contentsOf: dataDirectory.appendingPathComponent("\(descriptor.baseName).sg3")
                    )
                    let pixels = try Data(
                        contentsOf: dataDirectory.appendingPathComponent("\(descriptor.baseName).555"),
                        options: [.mappedIfSafe]
                    )
                    var localIDs = Set<Int>()
                    for y in 0..<map.height {
                        for x in 0..<map.width {
                            if let id = map.localSpriteID(
                                x: x,
                                y: y,
                                globalImageBase: descriptor.globalImageBase,
                                imageCount: archive.images.count
                            ) {
                                localIDs.insert(id)
                            }
                            if descriptor.baseName == "China_Elevation",
                               map.chinaElevationObjectSpriteID(
                                x: x,
                                y: y,
                                imageCount: archive.images.count
                               ) != nil,
                               let displayID = map.chinaElevationSpriteID(
                                x: x,
                                y: y,
                                imageCount: archive.images.count
                               ) {
                                localIDs.insert(
                                    displayID
                                )
                            }
                        }
                    }
                    if descriptor.baseName == "China_Terrain",
                       (0..<map.height).contains(where: { y in
                           (0..<map.width).contains(where: { x in
                               map.terrain(at: GridPoint(x: x, y: y))?.contains(.tree) == true
                           })
                       }) {
                        localIDs.formUnion(927..<945)
                    }
                    // Toolbar / player-built roads reuse the dirt-road family.
                    if descriptor.baseName == "China_Terrain" {
                        localIDs.formUnion(
                            OriginalInterfaceUtilitySpriteCatalog.roadTerrainLocalIDs
                        )
                    }
                    var decoded: [Int: DecodedSprite] = [:]
                    for id in localIDs.sorted() {
                        let metadata = archive.images[id]
                        guard metadata.width > 0, metadata.height > 0,
                              let sprite = try? SpriteDecoder.decode(
                                image: metadata,
                                pixelData: pixels
                              ) else { continue }
                        decoded[id] = sprite
                    }
                    var vegetationSprites: [Int: DecodedSprite] = [:]
                    if descriptor.baseName == "China_Terrain" {
                        for id in 238..<247 where archive.images.indices.contains(id) {
                            let metadata = archive.images[id]
                            guard let sprite = try? SpriteDecoder.decode(
                                image: metadata,
                                pixelData: pixels
                            ) else { continue }
                            vegetationSprites[id] = sprite.greenVegetationOnly()
                        }
                    }
                    decodedArchives.append(DecodedMapSpriteArchive(
                        globalImageBase: descriptor.globalImageBase,
                        imageCount: archive.images.count,
                        sprites: decoded,
                        vegetationSprites: vegetationSprites
                    ))
                }
                let decodedMapSpriteArchives = decodedArchives
                await MainActor.run {
                    guard generation == self.mapLoadGeneration else { return }
                    let renderedArchives = decodedMapSpriteArchives.map { archive in
                        RenderedMapSpriteArchive(
                            globalImageBase: archive.globalImageBase,
                            imageCount: archive.imageCount,
                            sprites: archive.sprites.reduce(into: [:]) { result, item in
                                guard let image = item.value.makeCGImage() else { return }
                                result[item.key] = RenderedTerrainSprite(
                                    image: image,
                                    width: item.value.width,
                                    height: item.value.height
                                )
                            },
                            vegetationSprites: archive.vegetationSprites.reduce(into: [:]) {
                                result, item in
                                guard let image = item.value.makeCGImage() else { return }
                                result[item.key] = RenderedTerrainSprite(
                                    image: image,
                                    width: item.value.width,
                                    height: item.value.height
                                )
                            }
                        )
                    }
                    self.renderedMap = RenderedMap(
                        map: map,
                        spriteArchives: renderedArchives
                    )
                }
            } catch {
                NativeDiagnostics.record("Map rendering failed", error: error)
                await MainActor.run {
                    guard generation == self.mapLoadGeneration else { return }
                    self.renderedMap = nil
                }
            }
        }
    }

    private func loadBuildingSprites(dataDirectory: URL) {
        Task.detached(priority: .utility) {
            do {
                struct DecodedBuilding: Sendable {
                    let reference: BuildingSpriteReference
                    let sprite: DecodedSprite
                    let offsetX: Int
                    let offsetY: Int
                }
                var decodedSprites: [DecodedBuilding] = []
                for (baseName, imageIDs) in
                    OriginalBuildingSpriteCatalog.requiredImageIDsByArchive {
                    let archive = try SG3Archive(
                        contentsOf: dataDirectory.appendingPathComponent("\(baseName).sg3")
                    )
                    let pixels = try Data(
                        contentsOf: dataDirectory.appendingPathComponent("\(baseName).555"),
                        options: [.mappedIfSafe]
                    )
                    for imageID in imageIDs.sorted() where archive.images.indices.contains(imageID) {
                        decodedSprites.append(DecodedBuilding(
                            reference: BuildingSpriteReference(
                                archiveBaseName: baseName,
                                imageID: imageID
                            ),
                            sprite: try SpriteDecoder.decode(
                                image: archive.images[imageID],
                                pixelData: pixels
                            ),
                            offsetX: archive.images[imageID].spriteOffsetX,
                            offsetY: archive.images[imageID].spriteOffsetY
                        ))
                    }
                }
                let loadedSprites = decodedSprites
                await MainActor.run {
                    self.buildingSprites = loadedSprites.reduce(into: [:]) { result, item in
                        guard let image = item.sprite.makeCGImage() else { return }
                        result[item.reference] = RenderedTerrainSprite(
                            image: image,
                            width: item.sprite.width,
                            height: item.sprite.height,
                            offsetX: item.offsetX,
                            offsetY: item.offsetY
                        )
                    }
                }
            } catch {
                NativeDiagnostics.record("Building sprite loading failed", error: error)
                await MainActor.run { self.buildingSprites = [:] }
            }
        }
    }

    private func loadFigureSprites(dataDirectory: URL) {
        Task.detached(priority: .utility) {
            do {
                struct DecodedFigure: Sendable {
                    let reference: FigureSpriteReference
                    let sprite: DecodedSprite
                    let offsetX: Int
                    let offsetY: Int
                }
                var decodedFigures: [DecodedFigure] = []
                for (baseName, imageIDs) in OriginalFigureSpriteCatalog.requiredImageIDsByArchive {
                    let archive = try SG3Archive(
                        contentsOf: dataDirectory.appendingPathComponent("\(baseName).sg3")
                    )
                    let pixels = try Data(
                        contentsOf: dataDirectory.appendingPathComponent("\(baseName).555"),
                        options: [.mappedIfSafe]
                    )
                    for imageID in imageIDs.sorted() where archive.images.indices.contains(imageID) {
                        let record = archive.images[imageID]
                        decodedFigures.append(DecodedFigure(
                            reference: FigureSpriteReference(
                                archiveBaseName: baseName,
                                imageID: imageID
                            ),
                            sprite: try SpriteDecoder.decode(
                                image: record,
                                pixelData: pixels
                            ).correctingFigureShadow(),
                            offsetX: record.spriteOffsetX,
                            offsetY: record.spriteOffsetY
                        ))
                    }
                }
                let decodedFiguresForRendering = decodedFigures
                await MainActor.run {
                    self.figureSprites = decodedFiguresForRendering.reduce(into: [:]) { result, item in
                        guard let image = item.sprite.makeCGImage() else { return }
                        result[item.reference] = RenderedTerrainSprite(
                            image: image,
                            width: item.sprite.width,
                            height: item.sprite.height,
                            offsetX: item.offsetX,
                            offsetY: item.offsetY
                        )
                    }
                }
            } catch {
                NativeDiagnostics.record("Figure sprite loading failed", error: error)
                await MainActor.run { self.figureSprites = [:] }
            }
        }
    }

    private func loadInterfaceSprites(dataDirectory: URL) {
        Task.detached(priority: .utility) {
            do {
                let baseName = OriginalInterfaceSpriteCatalog.archiveBaseName
                let archive = try SG3Archive(
                    contentsOf: dataDirectory.appendingPathComponent("\(baseName).sg3")
                )
                let pixels = try Data(
                    contentsOf: dataDirectory.appendingPathComponent("\(baseName).555"),
                    options: [.mappedIfSafe]
                )
                var decoded: [Int: DecodedSprite] = [:]
                let requiredImageIDs = OriginalInterfaceSpriteCatalog.requiredImageIDs
                    .union(OriginalInterfaceUtilitySpriteCatalog.requiredImageIDs)
                for imageID in requiredImageIDs.sorted()
                    where archive.images.indices.contains(imageID) {
                    let record = archive.images[imageID]
                    guard !record.isExternal, record.width > 0, record.height > 0 else {
                        continue
                    }
                    decoded[imageID] = try SpriteDecoder.decode(
                        image: record,
                        pixelData: pixels
                    )
                }
                let decodedSprites = decoded
                await MainActor.run {
                    self.interfaceSprites = decodedSprites.reduce(into: [:]) { result, item in
                        guard let image = item.value.makeCGImage() else { return }
                        let record = archive.images[item.key]
                        result[item.key] = RenderedTerrainSprite(
                            image: image,
                            width: item.value.width,
                            height: item.value.height,
                            offsetX: record.spriteOffsetX,
                            offsetY: record.spriteOffsetY
                        )
                    }
                }
            } catch {
                NativeDiagnostics.record("Interface sprite loading failed", error: error)
                await MainActor.run { self.interfaceSprites = [:] }
            }
        }
    }

    private func syncFromGameplayController() {
        guard let controller = gameplayController else { return }
        cityState = controller.city
        campaignRuntimeState = controller.campaignRuntime
        activeMissionWorld = controller.activeWorld
        latestTick = controller.latestTick
        latestSettlement = controller.latestSettlement
        latestCampaignAdvance = controller.latestCampaignAdvance
        gameSpeed = controller.speed
        selectedAgriculturalCrop = controller.selectedAgriculturalCrop
    }

    private func playerConstructionTool(
        for nativeTool: NativeConstructionTool
    ) -> PlayerConstructionTool? {
        switch nativeTool {
        case .inspect: .inspect
        case .demolish: .demolish
        case .clearLand: .clearLand
        case .road: .road
        case .house: .house
        case .eliteHouse: .eliteHouse
        case .warehouse: .warehouse
        case .huntingCamp: .huntingCamp
        case .mill: .mill
        case .market: .market
        case .grandMarket: .grandMarket
        case .clayPit: .clayPit
        case .kiln: .kiln
        case .well: .well
        case .herbalist: .herbalist
        case .acupuncture: .acupuncture
        case .ancestralShrine: .ancestralShrine
        case .confucianAcademy: .confucianAcademy
        case .daoistShrine: .daoistShrine
        case .inspectorTower: .inspectorTower
        case .taxOffice: .taxOffice
        case .musicSchool: .musicSchool
        case .acrobatSchool: .acrobatSchool
        case .dramaSchool: .dramaSchool
        case .farmland: .farmland
        case .irrigationPump: .irrigationPump
        case .grandCanalSegment: .grandCanalSegment
        case .earthenGreatWallSegment: .earthenGreatWallSegment
        case .largePalace: .largePalace
        case .largePalacePhase: .largePalacePhase
        case .lumberMill: .lumberMill
        case .quarry: .quarry
        case .granary: .granary
        case .barracks: .barracks
        case .cityWall: .cityWall
        case .gatehouse: .gatehouse
        case .tower: .tower
        case .roadblock: .roadblock
        case .administrativeCity: .administrativeCity
        case .palace: .palace
        case .fort: .fort
        case .catapultFort: .catapultFort
        case .cavalryFort: .cavalryFort
        case .chariotFort: .chariotFort
        case .fishingWharf: .fishingWharf
        case .ironMine: .ironMine
        case .bronzeWorks: .bronzeWorks
        case .lacquerGuild: .lacquerGuild
        case .lacquerwareWorkshop: .lacquerwareWorkshop
        case .jadeWorkshop: .jadeWorkshop
        case .silkWeaver: .silkWeaver
        case .weaver: .weaver
        case .teaHouse: .teaHouse
        case .bathhouse: .bathhouse
        case .magistrate: .magistrate
        case .watchtower: .watchtower
        case .garden: .garden
        case .decorativeSculpture: .decorativeSculpture
        case .ornateSculpture: .ornateSculpture
        case .floweringTree: .floweringTree
        case .waysidePavilion: .waysidePavilion
        case .pond: .pond
        case .taiChiPark: .taiChiPark
        case .privateGarden: .privateGarden
        case .laborersCamp: .laborersCamp
        case .carpentersGuild: .carpentersGuild
        case .masonsGuild: .masonsGuild
        case .ceramistsGuild: .ceramistsGuild
        case .tumulus: .tumulus
        case .grandTumulus: .grandTumulus
        case .greatTemple: .greatTemple
        case .splendidTemple: .splendidTemple
        case .grandPagoda: .grandPagoda
        case .rally: nil
        }
    }

    private static func makeSampleCity(
        models: OriginalEconomyModels,
        includeDemonstrationTrade: Bool = true
    ) -> DeterministicCityState {
        var city = DeterministicCityState(year: 1600, month: 6, treasury: 2_000, taxBandID: 3)
        city.workforceEnabled = true
        let rules = EconomyRulesEngine(models: models)
        let roads = (0..<12).map { GridPoint(x: $0, y: 2) }
            + (2..<9).map { GridPoint(x: 3, y: $0) }
        _ = city.buildRoad(roads, rules: rules)
        for (index, levelID) in [0, 2, 5, 7, 10, 14].enumerated() {
            let capacity = models.buildings[houseLevelID: levelID]?.populationCapacity ?? 0
            _ = city.addHouse(
                levelID: levelID,
                residents: max(1, capacity / 2),
                location: GridPoint(x: 1 + (index % 4) * 3, y: 1 + (index / 4) * 3),
                models: models.buildings
            )
        }
        _ = city.constructTaxOffice(
            serviceRoadStart: GridPoint(x: 0, y: 2),
            replaySeed: 0x454D_5045_524F_52,
            rules: rules
        )
        _ = city.advanceServiceWalkers(roadStepsPerWalker: 8)
        _ = city.constructProductionBuilding(
            buildingID: 31,
            assignedWorkers: models.buildings[buildingID: 31]?.employees ?? 0,
            serviceRoadStart: GridPoint(x: 1, y: 2),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 33,
            assignedWorkers: models.buildings[buildingID: 33]?.employees ?? 0,
            serviceRoadStart: GridPoint(x: 2, y: 2),
            rules: rules
        )
        _ = city.constructAgriculturalProducer(
            crop: .wheat,
            fieldCount: 4,
            fertilityPercent: 100,
            climate: .temperate,
            serviceRoadStart: GridPoint(x: 6, y: 2),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 35,
            assignedWorkers: 14,
            serviceRoadStart: GridPoint(x: 5, y: 2),
            rules: rules
        )
        _ = city.constructProductionBuilding(
            buildingID: 43,
            assignedWorkers: 12,
            serviceRoadStart: GridPoint(x: 7, y: 2),
            rules: rules
        )
        _ = city.constructWarehouse(
            serviceRoadStart: GridPoint(x: 10, y: 2),
            rules: rules
        )
        _ = city.constructMill(
            serviceRoadStart: GridPoint(x: 4, y: 2),
            rules: rules
        )
        _ = city.constructMarket(
            serviceRoadStart: GridPoint(x: 3, y: 5),
            shopBuildingIDs: [65, 66],
            rules: rules
        )
        if includeDemonstrationTrade, city.addTradePartner(
            TradePartner(
                id: 1,
                name: "Banpo",
                routeKind: .land,
                demandByCommodityID: [25: .high],
                supplyByCommodityID: [5: .low]
            ),
            rules: rules
        ), let origin = city.nextBuildingConstructionLocation(buildingID: 58),
           let tradingStationID = city.constructTradingBuilding(
            partnerID: 1,
            at: origin,
            rules: rules
        ) {
            city.setTradeImporting(true, commodityID: 5, tradingBuildingID: tradingStationID)
            city.setTradeExporting(true, commodityID: 25, tradingBuildingID: tradingStationID)
        }
        return city
    }
}
