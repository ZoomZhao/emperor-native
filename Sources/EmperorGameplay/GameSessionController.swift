import EmperorCore
import Foundation

/// The mutation boundary shared by the native UI and release-gate replay.
/// It intentionally exposes no population, inventory, workforce, housing or
/// goal setters: every state transition is a player command or one live tick.
public final class GameSessionController: @unchecked Sendable {
    public let source: GameDataSource
    public let catalog: GameDataCatalog
    public let models: OriginalEconomyModels
    public let campaigns: [CampaignArchive]
    public let cityNames: OriginalCityNameCatalog

    public private(set) var city: DeterministicCityState?
    public private(set) var campaignRuntime: CampaignMissionRuntimeState?
    public private(set) var activeWorld: CampaignMissionWorldState?
    public private(set) var selectedCampaignID: Int?
    public private(set) var selectedMissionID: Int?
    public private(set) var speed = 0
    public private(set) var selectedConstruction: PlayerConstructionTool = .inspect
    public private(set) var selectedAgriculturalCrop: AgriculturalCrop = .wheat
    public private(set) var selectedDifficulty: GameDifficulty = .normal
    public private(set) var lastBlockReason: String?
    public private(set) var evidence = GameSessionEvidence()
    public private(set) var latestTick: CityTickResult?
    public private(set) var latestSettlement: MonthlySettlement?
    public private(set) var latestCampaignAdvance: CampaignMissionAdvanceResult?

    private var activeGoalSet: CampaignMissionGoalSet?

    public convenience init() throws {
        try self.init(source: .openDefault())
    }

    public init(source: GameDataSource) throws {
        self.source = source
        catalog = try GameDataCatalog.scan(source)
        models = try OriginalEconomyModels(source: source)
        campaigns = try CampaignCatalog.load(source)
        cityNames = try OriginalCityNameCatalog(
            contentsOf: source.root.appendingPathComponent("EmperorText.eng")
        )
    }

    public var snapshot: GameSessionSnapshot {
        GameSessionSnapshot(
            city: city,
            campaignRuntime: campaignRuntime,
            campaignID: selectedCampaignID,
            missionID: selectedMissionID,
            speed: speed,
            selectedConstruction: selectedConstruction,
            replayFingerprint: city.map(replayFingerprint(for:)),
            lastBlockReason: lastBlockReason,
            evidence: evidence
        )
    }

    public func campaignID(fileName: String) -> Int? {
        campaigns.firstIndex { $0.url.lastPathComponent == fileName }
    }

    @discardableResult
    public func restorePersistedSession(_ save: NativeSaveGame) -> PlayerCommandResult {
        guard let campaignFileName = save.campaignFileName,
              let missionID = save.missionIndex,
              let campaignID = campaignID(fileName: campaignFileName) else {
            return .rejected("save does not identify a campaign mission")
        }
        let started = startCampaignMission(campaignID: campaignID, missionID: missionID)
        guard started.wasApplied else { return started }
        city = save.city
        campaignRuntime = save.campaignRuntime
        speed = 0
        latestTick = nil
        latestSettlement = nil
        latestCampaignAdvance = nil
        evidence = GameSessionEvidence()
        return .applied("restored persisted mission")
    }

    @discardableResult
    public func perform(_ command: PlayerCommand) -> PlayerCommandResult {
        let result: PlayerCommandResult
        switch command {
        case let .startCampaignMission(campaignID, missionID):
            result = startCampaignMission(campaignID: campaignID, missionID: missionID)
        case let .selectConstruction(tool):
            guard tool != .grandCanalSegment,
                  tool != .earthenGreatWallSegment else {
                result = .rejected(
                    "Map monument construction is awaiting source-verified rules"
                )
                break
            }
            selectedConstruction = tool
            result = .applied("selected \(tool.rawValue)")
        case let .selectAgriculturalCrop(crop):
            guard city?.isAgriculturalCropAvailable(crop) ?? true else {
                result = .rejected("crop is unavailable in this mission")
                break
            }
            selectedAgriculturalCrop = crop
            result = .applied("selected \(crop.rawValue)")
        case let .selectDifficulty(difficulty):
            selectedDifficulty = difficulty
            result = .applied("difficulty \(difficulty.rawValue)")
        case let .placeSelectedConstruction(point, orientation):
            result = placeSelectedConstruction(at: point, orientation: orientation)
        case let .demolish(point):
            result = demolish(at: point)
        case let .setProductionEnabled(buildingInstanceID, enabled):
            guard var updated = city,
                  updated.setProductionEnabled(
                    enabled,
                    buildingInstanceID: buildingInstanceID
                  ) else {
                result = .rejected("production building does not exist")
                break
            }
            city = updated
            result = .applied(enabled ? "生产设施已恢复运行" : "生产设施已暂停")
        case let .setWarehousePolicy(warehouseID, policy):
            guard var updated = city,
                  updated.setWarehousePolicy(
                    policy,
                    warehouseID: warehouseID,
                    commodityIDs: models.trade.commodities.map(\.id)
                  ) else {
                result = .rejected("warehouse does not exist")
                break
            }
            city = updated
            let title = switch policy {
            case .doNotAccept: "拒收"
            case .accept: "接收"
            case .empty: "清空"
            case .get: "主动调取"
            }
            result = .applied("仓库模式已设为\(title)")
        case let .setWarehouseCommodityPolicy(warehouseID, commodityID, policy):
            guard var updated = city,
                  updated.setWarehousePolicy(
                    policy,
                    warehouseID: warehouseID,
                    commodityIDs: [commodityID]
                  ) else {
                result = .rejected("warehouse does not exist")
                break
            }
            city = updated
            let commodity = models.trade.commodities
                .first(where: { $0.id == commodityID })?.name ?? "#\(commodityID)"
            let title = switch policy {
            case .doNotAccept: "拒收"
            case .accept: "接收"
            case .empty: "清空"
            case .get: "主动调取"
            }
            result = .applied("\(commodity)已设为\(title)")
        case let .setMillPolicy(millID, commodityID, policy):
            guard var updated = city,
                  updated.setMillPolicy(
                      policy,
                      millID: millID,
                      commodityID: commodityID
                  ) else {
                result = .rejected("mill does not exist")
                break
            }
            city = updated
            result = .applied("磨坊订单已更新")
        case let .setMillStorageLimit(millID, commodityID, amount):
            guard var updated = city,
                  updated.setMillStorageLimit(
                      amount,
                      millID: millID,
                      commodityID: commodityID
                  ) else {
                result = .rejected("mill does not exist")
                break
            }
            city = updated
            result = .applied("磨坊存储限制已更新")
        case let .setTradeEnabled(tradingBuildingID, enabled):
            guard var updated = city,
                  updated.setTradeEnabled(
                    enabled,
                    tradingBuildingID: tradingBuildingID
                  ) else {
                result = .rejected("trading building does not exist")
                break
            }
            city = updated
            result = .applied(enabled ? "贸易设施已恢复进出口" : "贸易设施已暂停进出口")
        case let .setTradeImporting(tradingBuildingID, commodityID, enabled):
            guard var updated = city,
                  updated.trade.buildings.contains(where: {
                      $0.id == tradingBuildingID
                  }) else {
                result = .rejected("trading building does not exist")
                break
            }
            updated.setTradeImporting(
                enabled,
                commodityID: commodityID,
                tradingBuildingID: tradingBuildingID
            )
            city = updated
            result = .applied(enabled ? "商品已设为进口" : "商品进口已停止")
        case let .constructTradingBuilding(partnerID, point, orientation):
            guard var updated = city,
                  let tradingBuildingID = updated.constructTradingBuilding(
                    partnerID: partnerID,
                    at: point,
                    orientation: orientation,
                    rules: EconomyRulesEngine(models: models)
                  ) else {
                result = .rejected("贸易设施无法在此建造")
                break
            }
            _ = updated.setTradeEnabled(
                true,
                tradingBuildingID: tradingBuildingID
            )
            city = updated
            result = .applied("贸易设施已建成并启用")
        case let .setTaxBand(bandID):
            guard models.taxSentiment.bands.contains(where: { $0.id == bandID }),
                  var updated = city else {
                result = .rejected("税率档位无效")
                break
            }
            updated.taxBandID = bandID
            city = updated
            result = .applied("税率已调整为第 \(bandID) 档")
        case let .beginMapMonument(buildingID):
            guard var updated = city,
                  updated.beginMapMonument(buildingID: buildingID) != nil else {
                result = .rejected("地图纪念碑不可用或已经开工")
                break
            }
            city = updated
            result = .applied("地图纪念碑 #\(buildingID) 已开工")
        case let .advanceEarthenGreatWallSegment(index):
            _ = index
            result = .rejected("Great Wall construction is awaiting source-verified rules")
        case let .issueMilitaryOrder(unitIDs, point):
            guard campaignRuntime?.outcome == .running,
                  var updated = city else {
                result = .rejected("mission has reached a terminal outcome")
                break
            }
            let ordered = updated.issueMilitaryOrder(
                unitIDs: unitIDs,
                to: point,
                models: models.figures
            )
            guard ordered > 0 else {
                result = .rejected("目标不可通行或没有存活部队")
                break
            }
            city = updated
            result = .applied("已命令 \(ordered) 支部队向 \(point.x), \(point.y) 集结")
        case let .setSpeed(requested):
            if campaignRuntime?.outcome != .running, requested > 0 {
                result = .rejected("mission has reached a terminal outcome")
            } else {
                speed = min(max(requested, 0), 3)
                result = .applied("speed \(speed)")
            }
        case .advanceOneTick:
            result = advanceOneTick()
        case .replayMission:
            guard let campaignID = selectedCampaignID, let missionID = selectedMissionID else {
                result = .rejected("no active mission")
                break
            }
            result = startCampaignMission(campaignID: campaignID, missionID: missionID)
        }
        if case let .rejected(reason) = result { lastBlockReason = reason }
        else { lastBlockReason = nil }
        return result
    }

    public func constructionPreview(
        at point: GridPoint,
        orientation: IsometricBuildingOrientation = .northSouth
    ) -> ConstructionPreview {
        guard var previewCity = city else {
            return ConstructionPreview(
                point: point, tool: selectedConstruction, orientation: orientation,
                isValid: false, reason: "no active city"
            )
        }
        let result = Self.applyConstruction(
            selectedConstruction,
            agriculturalCrop: selectedAgriculturalCrop,
            agriculturalClimate: activeWorld?.agriculturalClimate ?? .temperate,
            at: point,
            orientation: orientation,
            city: &previewCity,
            rules: EconomyRulesEngine(models: models)
        )
        return ConstructionPreview(
            point: point,
            tool: selectedConstruction,
            orientation: orientation,
            isValid: result,
            reason: result ? nil : constructionBlockReason(at: point)
        )
    }

    private func startCampaignMission(campaignID: Int, missionID: Int) -> PlayerCommandResult {
        guard campaigns.indices.contains(campaignID),
              let mission = campaigns[campaignID].missions.first(where: { $0.id == missionID }) else {
            return .rejected("campaign or mission does not exist")
        }
        do {
            let campaign = campaigns[campaignID]
            let settings = try CampaignMissionSettingsArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let maps = try CampaignMissionMapArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count,
                candidateMapURLs: catalog.maps.map(\.url)
            )
            let events = try CampaignEventArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let goals = try CampaignGoalArchive(
                campaignURL: campaign.url,
                missionCount: campaign.missions.count
            )
            let empire = try CampaignEmpireMap.loadIfPresent(campaignURL: campaign.url)
            let world = try CampaignMissionWorldState(
                missionID: missionID,
                missionSettings: settings,
                missionMaps: maps,
                empireMap: empire,
                cityNames: cityNames,
                tradeRules: models.trade
            )
            let map = try EmperorMap(url: world.mapAssignment.embeddedMap.mapURL)
            let canContinueExistingCity = world.mapAssignment.isContinuation
                && selectedCampaignID == campaignID
                && selectedMissionID == world.mapAssignment.sourceMissionIndex
                && activeWorld?.mapAssignment.embeddedMap.mapURL
                    == world.mapAssignment.embeddedMap.mapURL
                && campaignRuntime.map {
                    if case .victory = $0.outcome { return true }
                    return false
                } == true
            let inheritedMenagerie = canContinueExistingCity
                ? campaignRuntime?.menagerieAnimalCountsByProductID
                : nil
            var newCity: DeterministicCityState
            if canContinueExistingCity, var inherited = city {
                inherited.continueCampaignMission(with: world.startSettings)
                newCity = inherited
            } else {
                newCity = DeterministicCityState(
                    missionSettings: world.startSettings,
                    difficulty: selectedDifficulty,
                    map: map
                )
            }
            _ = world.installTradePartners(
                in: &newCity,
                rules: EconomyRulesEngine(models: models)
            )
            city = newCity
            var newRuntime = CampaignMissionRuntimeState(
                missionID: missionID,
                startYear: world.startSettings.startYear,
                startMonth: world.startSettings.startMonth,
                eventSet: events.missions[missionID],
                replaySeed: 0x454D_5045_524F_52,
                empireMap: empire,
                playerCityID: world.playerCity?.id,
                cityNames: cityNames
            )
            if let inheritedMenagerie {
                newRuntime.inheritMenagerie(
                    animalCountsByProductID: inheritedMenagerie
                )
            }
            campaignRuntime = newRuntime
            activeWorld = world
            activeGoalSet = goals.missions[missionID]
            let monumentGoalIDs = goals.missions[missionID].goals.compactMap { goal in
                if case let .monument(buildingID) = goal.requirement {
                    return buildingID
                }
                return nil
            }
            var migrationCity = city ?? newCity
            migrationCity.setMigrationContext(CampaignMigrationContext(
                monumentGoalBuildingIDs: monumentGoalIDs,
                normalAnnualWage: newRuntime.normalAnnualWage,
                consecutiveDebtMonths: newRuntime.consecutiveDebtMonths
            ))
            // The recovered producer is implemented and integration-verified;
            // enabling it here restores natural population growth.
            migrationCity.setAutomaticMigrationAvailability(
                .supportedOriginalProducer
            )
            city = migrationCity
            selectedCampaignID = campaignID
            selectedMissionID = missionID
            selectedConstruction = .inspect
            selectedAgriculturalCrop = .wheat
            speed = 0
            evidence = GameSessionEvidence()
            latestTick = nil
            latestSettlement = nil
            latestCampaignAdvance = nil
            return .applied("started \(mission.title)")
        } catch {
            return .rejected("mission initialization failed: \(error.localizedDescription)")
        }
    }

    private func placeSelectedConstruction(
        at point: GridPoint,
        orientation: IsometricBuildingOrientation
    ) -> PlayerCommandResult {
        guard var updated = city else { return .rejected("no active city") }
        guard campaignRuntime?.outcome == .running else {
            return .rejected("mission has reached a terminal outcome")
        }
        guard selectedConstruction != .inspect, selectedConstruction != .demolish else {
            return .rejected("select a construction tool")
        }
        guard Self.applyConstruction(
            selectedConstruction,
            agriculturalCrop: selectedAgriculturalCrop,
            agriculturalClimate: activeWorld?.agriculturalClimate ?? .temperate,
            at: point,
            orientation: orientation,
            city: &updated,
            rules: EconomyRulesEngine(models: models)
        ) else {
            return .rejected(constructionBlockReason(at: point))
        }
        city = updated
        return .applied("placed \(selectedConstruction.rawValue) at \(point.x),\(point.y)")
    }

    private func demolish(at point: GridPoint) -> PlayerCommandResult {
        guard var updated = city else { return .rejected("no active city") }
        guard campaignRuntime?.outcome == .running else {
            return .rejected("mission has reached a terminal outcome")
        }
        let outcome = updated.demolish(
            at: point,
            rules: EconomyRulesEngine(models: models)
        )
        guard outcome != .nothing else { return .rejected("nothing to demolish at tile") }
        city = updated
        return .applied("demolished tile \(point.x),\(point.y)")
    }

    private func advanceOneTick() -> PlayerCommandResult {
        guard speed > 0 else { return .rejected("simulation is paused") }
        guard var updatedCity = city, var runtime = campaignRuntime else {
            return .rejected("no active mission")
        }
        guard runtime.outcome == .running else {
            speed = 0
            return .rejected("mission has reached a terminal outcome")
        }
        let rules = EconomyRulesEngine(models: models)
        let tick = updatedCity.advanceTick(rules: rules)
        latestTick = tick
        if let settlement = tick.monthlySettlement {
            latestSettlement = settlement
            let advance = runtime.advance(
                settlementYear: settlement.year,
                month: settlement.month,
                city: &updatedCity,
                rules: rules,
                goalSet: activeGoalSet,
                completedMonumentBuildingIDsAtBoundary:
                    settlement.completedMonumentBuildingIDsAtBoundary
            )
            latestCampaignAdvance = advance
            if advance.outcomeChangedNow != nil { evidence.outcomeChangeCount += 1 }
            // Refresh wage / debt-months / goal inputs for the migration
            // producer after the monthly advance.
            updatedCity.setMigrationContext(CampaignMigrationContext(
                monumentGoalBuildingIDs: activeGoalSet?.goals.compactMap { goal in
                    if case let .monument(buildingID) = goal.requirement {
                        return buildingID
                    }
                    return nil
                } ?? [],
                normalAnnualWage: runtime.normalAnnualWage,
                consecutiveDebtMonths: runtime.consecutiveDebtMonths
            ))
        }
        updateEvidence(city: updatedCity)
        city = updatedCity
        campaignRuntime = runtime
        if runtime.outcome != .running { speed = 0 }
        return .applied("advanced tick \(tick.tickSequence)")
    }

    private func updateEvidence(city: DeterministicCityState) {
        evidence.sawStaffedProducer = evidence.sawStaffedProducer || city.production.buildings.contains {
            $0.buildingID == 33 && $0.assignedWorkers > 0
        }
        evidence.sawProducerStock = evidence.sawProducerStock || city.production.buildings.contains {
            $0.buildingID == 33 && $0.outputInventoryByCommodityID[4, default: 0] > 0
        }
        evidence.sawDeliveryWalker = evidence.sawDeliveryWalker || !city.logistics.deliveryWalkers.isEmpty
        // A food buyer reserves its cargo from the mill when it is spawned, so
        // the mill can be empty again before this end-of-tick snapshot.  The
        // buyer's millID is durable proof that food was stocked and collected.
        evidence.sawMillStock = evidence.sawMillStock
            || city.logistics.mills.contains {
                $0.inventoryByCommodityID[4, default: 0] > 0
            }
            || city.markets.buyers.contains {
                $0.millID != nil && $0.cargoes.contains { $0.commodityID == 4 && $0.amount > 0 }
            }
            // A settlement's purchased meat loads are durable proof the mill
            // stocked meat and a buyer collected it, even when both the mill
            // and the buyer are empty again at this end-of-tick snapshot.
            || (city.markets.lastSettlement?.purchasedLoads.contains {
                $0.commodityID == 4 && $0.amount > 0
            } ?? false)
        evidence.sawBuyer = evidence.sawBuyer
            || !city.markets.buyers.isEmpty
            || !(city.markets.lastSettlement?.purchasedLoads.isEmpty ?? true)
        evidence.sawPeddler = evidence.sawPeddler
            || !city.markets.peddlers.isEmpty
            || !(city.markets.lastSettlement?.householdDeliveries.isEmpty ?? true)
        evidence.sawHouseFood = evidence.sawHouseFood || city.houses.contains { $0.foodSupplyAmount > 0 }
        evidence.sawWaterService = evidence.sawWaterService || city.houses.contains {
            $0.serviceCoverage.contains(.water)
        }
        evidence.sawAncestorService = evidence.sawAncestorService || city.houses.contains {
            $0.serviceCoverage.contains(.ancestor)
        }
        evidence.sawInspectionService = evidence.sawInspectionService || city.houses.contains {
            $0.serviceCoverage.contains(.inspection)
        }
    }

    private static func applyConstruction(
        _ tool: PlayerConstructionTool,
        agriculturalCrop: AgriculturalCrop,
        agriculturalClimate: AgriculturalClimate,
        at point: GridPoint,
        orientation: IsometricBuildingOrientation,
        city: inout DeterministicCityState,
        rules: EconomyRulesEngine
    ) -> Bool {
        switch tool {
        case .inspect: false
        case .demolish: city.demolish(at: point, rules: rules) != .nothing
        case .clearLand: city.clearVegetation(at: point)
        case .road: city.buildRoad([point], rules: rules) == 1
        case .house:
            city.constructHouse(
                location: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .eliteHouse:
            city.constructHouse(
                levelID: 8,
                constructionBuildingID: 11,
                location: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .warehouse, .granary:
            city.constructWarehouse(
                at: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .clayPit, .kiln, .fishingWharf, .huntingCamp, .quarry, .lumberMill,
             .ironMine, .bronzeWorks, .jadeWorkshop, .lacquerGuild, .silkWeaver,
             .teaHouse, .lacquerwareWorkshop, .weaver:
            city.constructProductionBuilding(
                buildingID: tool.buildingID ?? 0,
                at: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .mill:
            city.constructMill(at: point, orientation: orientation, rules: rules) != nil
        case .market:
            city.constructMarket(
                at: point,
                orientation: orientation,
                shopBuildingIDs: [],
                rules: rules
            ) != nil
        case .grandMarket:
            city.constructMarket(
                at: point,
                orientation: orientation,
                marketBuildingID: OriginalMarketCatalog.grandMarketBuildingID,
                shopBuildingIDs: [],
                rules: rules
            ) != nil
        case .foodShop, .hempShop, .ceramicsShop, .teaShop, .silkShop,
             .lacquerwareShop, .bronzewareShop:
            city.constructMarketShop(
                shopBuildingID: tool.buildingID ?? 0,
                at: point,
                rules: rules
            ) != nil
        case .taxOffice:
            city.constructTaxOffice(
                at: point,
                orientation: orientation,
                replaySeed: replaySeed(at: point),
                rules: rules
            ) != nil
        case .well, .herbalist, .acupuncture, .inspectorTower, .musicSchool,
             .acrobatSchool, .dramaSchool, .ancestralShrine, .confucianAcademy,
             .daoistShrine, .bathhouse, .magistrate, .watchtower:
            city.constructResidentialServiceBuilding(
                buildingID: tool.buildingID ?? 0,
                at: point,
                orientation: orientation,
                replaySeed: replaySeed(at: point),
                rules: rules
            ) != nil
        case .roadblock:
            city.constructRoadBlock(at: point, rules: rules) != nil
        case .cropFarm:
            city.constructAgriculturalProducer(
                crop: agriculturalCrop,
                at: point,
                orientation: orientation,
                climate: agriculturalClimate,
                rules: rules
            ) != nil
        case .farmland:
            city.constructAgriculturalPlot(
                crop: agriculturalCrop,
                at: point,
                climate: agriculturalClimate,
                rules: rules
            ) != nil
        case .irrigationPump:
            city.constructIrrigationPump(
                at: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .grandCanalSegment, .earthenGreatWallSegment:
            false
        case .largePalacePhase:
            city.advanceLargePalacePhase(at: point) != nil
        case .phasedMonumentPhase:
            city.advancePhasedMonument(at: point) != nil
        case .barracks, .fort, .catapultFort, .cavalryFort, .chariotFort:
            city.constructMilitaryFort(
                buildingID: tool.buildingID ?? 0,
                at: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .cityWall, .gatehouse, .tower:
            city.constructMilitaryDefense(
                buildingID: tool.buildingID ?? 0,
                at: point,
                orientation: orientation,
                rules: rules
            ) != nil
        case .garden, .decorativeSculpture, .ornateSculpture, .floweringTree,
             .waysidePavilion, .pond, .taiChiPark, .privateGarden,
             .administrativeCity, .palace, .laborersCamp, .carpentersGuild,
             .masonsGuild, .ceramistsGuild, .tumulus, .grandTumulus,
             .undergroundVault, .greatTemple, .splendidTemple, .grandPagoda,
             .largePalace:
            city.constructAestheticBuilding(
                buildingID: tool.buildingID ?? 0,
                at: point,
                orientation: orientation,
                rules: rules
            ) != nil
        }
    }

    private static func replaySeed(at point: GridPoint) -> UInt64 {
        0x504C_4143_454D_454E
            ^ UInt64(bitPattern: Int64(point.x * 4_099 + point.y * 131))
    }

    private func constructionBlockReason(at point: GridPoint) -> String {
        guard let city else { return "no active city" }
        if !city.roadNetwork.isInside(point) { return "tile is outside the playable map" }
        if selectedConstruction == .farmland {
            guard city.isAgriculturalCropAvailable(selectedAgriculturalCrop) else {
                return "crop is unavailable in this mission"
            }
            return "crop plot needs clear land within an available matching farm's tending range"
        }
        if selectedConstruction == .cropFarm {
            guard city.isAgriculturalCropAvailable(selectedAgriculturalCrop) else {
                return "crop is unavailable in this mission"
            }
            return "farm needs a clear authored footprint beside a road and sufficient funds"
        }
        if selectedConstruction == .road {
            if city.roadNetwork.contains(point) { return "tile already contains a road" }
            if city.occupiedBuildingPoints.contains(point) { return "tile is occupied" }
            if city.terrain?.isClearLand(point) == false {
                return "original terrain, including canal reserve tiles, blocks road construction"
            }
            if city.canConstructRoad(at: point) {
                return "treasury blocks road construction"
            }
            return "tile cannot accept a road"
        }
        if let shopBuildingID = selectedConstruction.marketShopBuildingID {
            if city.canConstructMarketShop(shopBuildingID: shopBuildingID, at: point) {
                return "treasury or building model blocks market shop construction"
            }
            return "select a market square with an empty shop bay"
        }
        if let buildingID = selectedConstruction.buildingID,
           let restriction = city.campaignConstructionRestriction(forBuildingID: buildingID) {
            return "campaign restriction: \(restriction)"
        }
        if city.placedBuildings.contains(where: { $0.occupiedPoints.contains(point) })
            || city.houses.contains(where: { $0.location == point }) {
            return "tile is occupied"
        }
        return "terrain, footprint, road access, resource layer or treasury blocks construction"
    }

    private func replayFingerprint(for city: DeterministicCityState) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ value: UInt64) {
            hash ^= value
            hash &*= 0x0000_0100_0000_01b3
        }
        mix(UInt64(city.roadNetwork.width))
        mix(UInt64(city.roadNetwork.height))
        for raw in city.terrain?.terrainRawValues ?? [] { mix(UInt64(raw)) }
        for point in city.roadNetwork.points.sorted(by: {
            $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y
        }) {
            mix(UInt64(point.x))
            mix(UInt64(point.y))
        }
        return hash
    }
}

private extension PlayerConstructionTool {
    var marketShopBuildingID: Int? {
        switch self {
        case .foodShop, .hempShop, .ceramicsShop, .teaShop, .silkShop,
             .lacquerwareShop, .bronzewareShop:
            buildingID
        default:
            nil
        }
    }
}
