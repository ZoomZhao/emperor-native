import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct CityMetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(EmperorTheme.headlineMedium)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CitySettlementStrip: View {
    let settlement: MonthlySettlement?

    var body: some View {
        Group {
            if let settlement {
                HStack(spacing: 18) {
                    Label("\(settlement.year) 年 \(settlement.month) 月结算", systemImage: "checkmark.seal.fill")
                        .font(EmperorTheme.headlineMedium)
                    Spacer()
                    LabeledContent("征税人口", value: "\(settlement.taxedPopulation)")
                    LabeledContent("税收", value: "+\(settlement.collectedTaxes)")
                    LabeledContent("民意", value: settlement.taxSentiment.formatted(.number.sign(strategy: .always())))
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                    Text("推进一个月后，这里会显示按原版税率与住宅等级计算的结算。")
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProductionStatusStrip: View {
    let production: DeterministicProductionState
    let logistics: DeterministicLogisticsState
    let trade: DeterministicTradeState
    let models: OriginalEconomyModels

    var body: some View {
        HStack(spacing: 18) {
            Label("原版工业链", systemImage: "shippingbox.fill")
                .font(EmperorTheme.headlineMedium)
            Spacer()
            LabeledContent("工坊", value: "\(production.buildings.count)")
            LabeledContent("仓库", value: "\(logistics.warehouses.count)")
            LabeledContent("磨坊", value: "\(logistics.mills.count)")
            LabeledContent("在途", value: "\(logistics.deliveryWalkers.count + trade.visitors.count)")
            LabeledContent("黏土", value: formattedCommodity(18))
            LabeledContent("陶瓷", value: formattedCommodity(25))
            LabeledContent("待运", value: "\(pendingOutput / 100) 车")
            if let settlement = production.lastSettlement {
                LabeledContent("本月批次", value: "\(settlement.operations.count)")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formattedCommodity(_ commodityID: Int) -> String {
        let amount = logistics[commodityID: commodityID]
        let name = models.trade[commodityID: commodityID]
            .map { ClassicTextLocalization.commodityName($0.name) }
            ?? "#\(commodityID)"
        return "\(name) \(amount / 100) 箱"
    }

    private var pendingOutput: Int {
        production.buildings.reduce(0) { partial, building in
            partial + building.outputInventoryByCommodityID.values.reduce(0, +)
        }
    }
}

struct AgricultureStatusStrip: View {
    let calendar: SimulationCalendar
    let production: DeterministicProductionState
    let logistics: DeterministicLogisticsState
    let models: OriginalEconomyModels

    var body: some View {
        HStack(spacing: 18) {
            Label("原版节气农业", systemImage: "leaf.fill")
                .font(EmperorTheme.headlineMedium)
            Spacer()
            LabeledContent("农场/果园", value: "\(farms.count)")
            LabeledContent("田块", value: "\(farms.reduce(0) { $0 + $1.fieldCount })")
            LabeledContent("本月", value: "\(calendar.month) 月 · \(phase)")
            LabeledContent("作物", value: cropNames)
            LabeledContent("最近收获", value: "\(recentHarvestAmount)")
            LabeledContent("磨坊粮食", value: "\(logistics.mills.reduce(0) { $0 + $1.storedAmount })")
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help("月份来自原版手册；田块上限、收割人数、最低肥力与地域产量系数直接读取 FarmConfig.txt。")
    }

    private var farms: [AgriculturalConfiguration] {
        production.buildings.compactMap(\.agriculture)
    }

    private var phase: String {
        let harvesting = farms.count { $0.crop.harvestMonths.contains(calendar.month) }
        let growing = farms.count { $0.crop.growingMonths.contains(calendar.month) }
        if harvesting > 0 { return "\(harvesting) 处收获" }
        if growing > 0 { return "\(growing) 处生长" }
        return "休耕"
    }

    private var cropNames: String {
        let names = farms.map {
            models.trade[commodityID: $0.crop.outputCommodityID]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? ClassicTextLocalization.commodityName($0.crop.rawValue)
        }
        return names.isEmpty ? "—" : names.joined(separator: "、")
    }

    private var recentHarvestAmount: Int {
        production.lastAgriculturalSettlement?.harvests.reduce(0) { $0 + $1.outputAmount } ?? 0
    }
}

struct WalkerStatusStrip: View {
    let walkers: DeterministicWalkerState
    let houses: [ResidentialUnit]

    var body: some View {
        HStack(spacing: 18) {
            Label("道路服务", systemImage: "figure.walk")
                .font(EmperorTheme.headlineMedium)
            Spacer()
            LabeledContent("服务人员", value: "\(walkers.walkers.count)")
            LabeledContent("税吏", value: "\(walkers.walkers.count { $0.service == .tax })")
            if let official = walkers.walkers.first(where: { $0.service == .tax }) {
                LabeledContent(
                    "位置",
                    value: "\(official.currentPoint.x), \(official.currentPoint.y)"
                )
                LabeledContent("巡回", value: "\(official.completedTrips)")
            }
            LabeledContent("征税覆盖", value: "\(houses.count(where: \.hasTaxCoverage)) / \(houses.count)")
            LabeledContent(
                "生活服务",
                value: "\(houses.count { !$0.serviceCoverage.isEmpty }) / \(houses.count)"
            )
            if let movement = walkers.lastMovement {
                LabeledContent("最近步数", value: "\(movement.movedRoadSteps)")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MilitaryStatusStrip: View {
    let military: DeterministicMilitaryState
    let selectedUnitIDs: Set<Int>
    let onSelectAll: () -> Void
    let onClearSelection: () -> Void

    private var liveUnits: [MilitaryUnit] {
        military.units.filter { $0.status != .destroyed }
    }

    private var activeEnemies: [EnemyMilitaryForce] {
        military.enemyForces.filter { $0.status == .maneuvering || $0.status == .engaged }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Label("战场", systemImage: "shield.lefthalf.filled")
                    .font(EmperorTheme.headlineMedium)
                Spacer()
                LabeledContent("我方编队", value: "\(liveUnits.count)")
                LabeledContent("已选择", value: selectedUnitIDs.isEmpty ? "全军" : "\(selectedUnitIDs.count)")
                LabeledContent("城防", value: "\(military.defensiveStructures.count { $0.isOperational })")
                LabeledContent("来敌", value: "\(activeEnemies.count)")
                Button("全选", action: onSelectAll)
                    .controlSize(.small)
                Button("清除选择", action: onClearSelection)
                    .controlSize(.small)
            }
            if let force = activeEnemies.first {
                HStack(spacing: 10) {
                    Image(systemName: force.siegeEngineCount > 0 ? "scope" : "figure.run")
                        .foregroundStyle(.red)
                    Text("敌军 \(force.soldierCount) 人正在向 \(force.targetPoint.x), \(force.targetPoint.y) 推进")
                    if force.siegeEngineCount > 0 {
                        Text("· 攻城器械 \(force.siegeEngineCount)")
                            .foregroundStyle(.purple)
                    }
                    Spacer()
                    Text("当前位置 \(force.currentPoint.x), \(force.currentPoint.y)")
                        .foregroundStyle(.secondary)
                }
                .font(EmperorTheme.bodySmall)
            } else if let report = military.combatReports.last {
                Text(
                    report.outcome == .repelled
                        ? "最近战果：击退 \(report.enemySoldiersBefore) 名敌军"
                        : "最近战果：城防被突破"
                )
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(report.outcome == .repelled ? .green : .red)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CampaignRuntimeStatusStrip: View {
    let runtime: CampaignMissionRuntimeState
    let latestAdvance: CampaignMissionAdvanceResult?
    let city: DeterministicCityState
    let models: OriginalEconomyModels
    let onFulfillRequest: () -> Void
    let onStartNextMission: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Label(
                    runtime.missionCompleted ? "原版任务已完成" : "原版任务时钟",
                    systemImage: runtime.missionCompleted ? "checkmark.seal.fill" : "clock.badge.checkmark"
                )
                .font(EmperorTheme.headlineMedium)
                .foregroundStyle(runtime.missionCompleted ? .green : .primary)
                Spacer()
                LabeledContent("已触发", value: "\(runtime.occurrences.count)")
                LabeledContent("待交请求", value: "\(runtime.pendingRequests.count)")
                LabeledContent("待入库", value: "\(runtime.pendingGiftAmount / 100) 车")
                LabeledContent("正常年薪", value: "\(runtime.normalAnnualWage)")
                if runtime.consecutiveDebtMonths > 0 {
                    LabeledContent("连续负债", value: "\(runtime.consecutiveDebtMonths) / 36 月")
                        .foregroundStyle(.red)
                }
            }

            if let request = earliestRequest {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .foregroundStyle(.orange)
                    Text("请求：\(productName(request.productID)) \(formattedAmount(request))")
                        .font(EmperorTheme.labelMedium)
                    Text("· \(deadlineText(request))")
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("交付最早请求", action: onFulfillRequest)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            if let latestAdvance, !latestAdvance.effects.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "scroll.fill")
                        .foregroundStyle(.teal)
                    Text("最近事件：")
                        .font(EmperorTheme.labelMedium)
                    Text(latestAdvance.effects.map(effectDescription).joined(separator: "、"))
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
            }

            if runtime.missionCompleted {
                HStack {
                    Text("全部可运行目标已满足，任务完成事件也已在同月执行。")
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("进入下一任务", action: onStartNextMission)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help("事件在原版设定月份的月末执行。灾害、入侵、外交、贡赋与已知城市状态会直接改变原生状态；仅原版未使用或尚无独立规则的事件保留为可追踪日志。")
        .accessibilityIdentifier("campaign-goal-status")
        .accessibilityValue(accessibilityStatus)
    }

    private var accessibilityStatus: String {
        let outcome: String
        switch runtime.outcome {
        case .running: outcome = "running"
        case .victory: outcome = "victory"
        case .defeat: outcome = "defeat"
        }
        return "outcome=\(outcome);year=\(city.calendar.year);month=\(city.calendar.month);day=\(city.simulationClock.day);population=\(city.population);treasury=\(city.economy.treasury);debtMonths=\(runtime.consecutiveDebtMonths)"
    }

    private var earliestRequest: CampaignRequestState? {
        runtime.pendingRequests.min {
            $0.deadlineAbsoluteMonth == $1.deadlineAbsoluteMonth
                ? $0.id < $1.id
                : $0.deadlineAbsoluteMonth < $1.deadlineAbsoluteMonth
        }
    }

    private var currentAbsoluteMonth: Int {
        max(0, city.calendar.year - runtime.startYear) * 12 + city.calendar.month - 1
    }

    private func deadlineText(_ request: CampaignRequestState) -> String {
        let remaining = max(0, request.deadlineAbsoluteMonth - currentAbsoluteMonth + 1)
        return remaining == 0 ? "本月到期" : "剩余 \(remaining) 个月"
    }

    private func formattedAmount(_ request: CampaignRequestState) -> String {
        if request.productID == CampaignMissionRuntimeState.cashProductID {
            return request.amount.formatted()
        }
        if request.productID >= CampaignMissionRuntimeState.firstMenagerieProductID {
            return "\(request.amount) 只"
        }
        let loads = Double(request.amount) / Double(CampaignMissionRuntimeState.internalUnitsPerLoad)
        return loads.rounded() == loads ? "\(Int(loads)) 车" : String(format: "%.2f 车", loads)
    }

    private func productName(_ productID: Int) -> String {
        if productID == CampaignMissionRuntimeState.cashProductID { return "钱币" }
        if productID >= CampaignMissionRuntimeState.firstMenagerieProductID {
            return "珍禽异兽 #\(productID)"
        }
        return models.trade[commodityID: productID]
            .map { ClassicTextLocalization.commodityName($0.name) }
            ?? "商品 #\(productID)"
    }

    private func effectDescription(_ effect: CampaignEventEffect) -> String {
        let title = effect.kind?.chineseTitle ?? "事件 #\(effect.kindRawValue)"
        switch effect.disposition {
        case .applied: return "\(title)已生效"
        case .pending: return "\(title)待处理"
        case .recorded: return "\(title)已记录"
        case .noEffect: return "\(title)无有效参数"
        }
    }
}

struct CampaignEmpireStatusStrip: View {
    let empire: CampaignEmpireRuntimeState
    let onSendEmissary: (Int) -> Void
    let onSendSpy: (Int) -> Void
    let onRequestAlliance: (Int) -> Void
    let onConquer: (Int) -> Void
    let onRequestAnimal: (Int) -> Void
    let onPrepayHomage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Label("帝国外交", systemImage: "globe.asia.australia.fill")
                    .font(EmperorTheme.headlineMedium)
                Spacer()
                LabeledContent("盟友", value: "\(empire.alliedCityCount)")
                LabeledContent("附庸", value: "\(empire.conqueredCityCount)")
                LabeledContent("朝拜月", value: "\(empire.homageProgress)")
                LabeledContent("预付", value: "\(empire.prepaidHomageMonths)")
                Button("维持英雄香火", action: onPrepayHomage)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            ForEach(empire.visibleForeignCities.filter(\.isActive)) { city in
                HStack(spacing: 9) {
                    Text(ClassicTextLocalization.cityName(city.name))
                        .font(EmperorTheme.labelMedium)
                        .frame(width: 116, alignment: .leading)
                    Text(relationshipTitle(city.relationship))
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(relationshipColor(city.relationship))
                        .frame(width: 42, alignment: .leading)
                    Label("\(city.favor)", systemImage: "heart.fill")
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(.pink)
                        .frame(width: 54, alignment: .leading)
                    if city.spyStatus == .arrived {
                        Text("军 \(city.militaryStrength) · 财 \(city.economicStrength)")
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("军力未探明")
                            .font(EmperorTheme.bodySmall)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("使者") { onSendEmissary(city.id) }
                    Button("间谍") { onSendSpy(city.id) }
                    Button("结盟") { onRequestAlliance(city.id) }
                        .disabled(city.relationship != .rival)
                    Button("征服") { onConquer(city.id) }
                        .disabled(city.relationship != .rival)
                    Button("求兽") { onRequestAnimal(city.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help("使者提高好感并开启结盟；间谍揭示实力；存活部队可征服非六级敌城；英雄香火按月累计朝拜目标。")
    }

    private func relationshipTitle(_ relationship: CampaignDiplomaticRelationship) -> String {
        switch relationship {
        case .rival: "敌对"
        case .ally: "盟友"
        case .vassal: "附庸"
        }
    }

    private func relationshipColor(_ relationship: CampaignDiplomaticRelationship) -> Color {
        switch relationship {
        case .rival: .red
        case .ally: .green
        case .vassal: .orange
        }
    }
}

struct TradeStatusStrip: View {
    let trade: DeterministicTradeState
    let accounting: DeterministicProductionAccounting
    let models: OriginalEconomyModels

    var body: some View {
        HStack(spacing: 18) {
            Label("原版陆海贸易", systemImage: "arrow.left.arrow.right.circle.fill")
                .font(EmperorTheme.headlineMedium)
            Spacer()
            LabeledContent("可用路线", value: "\(trade.activePartnerCount)")
            LabeledContent("已建伙伴", value: "\(trade.establishedPartnerCount)")
            LabeledContent("贸易站/码头", value: "\(trade.buildings.count)")
            LabeledContent("站内货物", value: "\(stagedAmount / 100) 车")
            if let settlement = trade.lastSettlement {
                LabeledContent("进口", value: "-\(settlement.importSpending)")
                LabeledContent("出口", value: "+\(settlement.exportIncome)")
            }
            LabeledContent("本年陶瓷", value: "\(accounting.currentProductionUnitsByCommodityID[25, default: 0])")
            LabeledContent("最佳年产", value: "\(accounting.bestYearlyProductionUnitsByCommodityID[25, default: 0])")
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help("贸易站 60 车仓容；陆商每次买卖各 8 车、海船各 12 车。低/中/高额度为每年 12/24/36 车；商品价格来自 Trade.txt。")
    }

    private var stagedAmount: Int {
        trade.buildings.reduce(0) { $0 + $1.storedAmount }
    }
}

struct MarketStatusStrip: View {
    let markets: DeterministicMarketState
    let houses: [ResidentialUnit]
    let models: OriginalEconomyModels

    var body: some View {
        HStack(spacing: 18) {
            Label("市场配送", systemImage: "basket.fill")
                .font(EmperorTheme.headlineMedium)
            Spacer()
            LabeledContent("市场", value: "\(markets.markets.count)")
            LabeledContent("店内", value: "\(marketInventory / 100) 车")
            LabeledContent("买手", value: "\(markets.buyers.count)")
            LabeledContent("货郎", value: "\(markets.peddlers.count)")
            LabeledContent("住宅食物", value: "\(houses.reduce(0) { $0 + $1.foodSupplyAmount })")
            LabeledContent("住宅陶瓷", value: "\(houseSupply(25))")
            if let settlement = markets.lastSettlement {
                LabeledContent("本月送达", value: "\(settlement.householdDeliveries.count)")
                LabeledContent("短缺住宅", value: "\(settlement.underSuppliedHouseIDs.count)")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help(
            "使用原版买手与货郎范围，将磨坊食物和仓库商品送入住宅；"
                + "食物质量与瓷器均按居民数逐月消耗。"
        )
    }

    private var marketInventory: Int {
        markets.markets.reduce(0) { partial, market in
            partial + market.inventoryByCommodityID.values.reduce(0, +)
        }
    }

    private func houseSupply(_ commodityID: Int) -> Int {
        houses.reduce(0) { $0 + $1[commodityID: commodityID] }
    }
}

struct HousingEvolutionStatusStrip: View {
    let houses: [ResidentialUnit]
    let serviceBuildings: [ResidentialServiceBuilding]
    let settlement: HousingMonthlySettlement?
    let models: OriginalEconomyModels

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 18) {
                Label("原版住宅演化", systemImage: "house.and.flag.fill")
                    .font(EmperorTheme.headlineMedium)
                Spacer()
                LabeledContent("住宅等级", value: levelSummary)
                LabeledContent(
                    "住宅服务",
                    value: "\(serviceBuildings.count { $0.service != .tax }) / 9"
                )
                if let settlement {
                    LabeledContent("本月升级", value: "\(settlement.evolvedCount)")
                    LabeledContent("本月退化", value: "\(settlement.devolvedCount)")
                }
            }
            if let evaluation = firstBlockedEvaluation,
               let house = houses.first(where: { $0.id == evaluation.houseID }) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "arrow.up.right.circle")
                        .foregroundStyle(.orange)
                    Text("\(houseName(house.houseLevelID)) 下一步：")
                        .font(EmperorTheme.labelMedium)
                    Text(
                        evaluation.missingEvolutionRequirements
                            .map(requirementDescription)
                            .joined(separator: "、")
                    )
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("宜居度 \(evaluation.desirability)")
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(.secondary)
                }
            } else if !houses.isEmpty {
                Text("当前住宅已满足可用链条的升级条件，或已达到该住宅链最高等级。")
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help("升级与退化阈值、食物品质、商品、医药、娱乐和宗教需求均直接读取 EmperorBuildingModels.txt；服务覆盖由原版人物模型的巡回范围决定。")
    }

    private var levelSummary: String {
        let groups = Dictionary(grouping: houses, by: \.houseLevelID)
        let populated = groups.keys.sorted().map { levelID in
            "\(levelID + 1)级×\(groups[levelID]?.count ?? 0)"
        }
        return populated.isEmpty ? "—" : populated.joined(separator: " ")
    }

    private var firstBlockedEvaluation: HouseEvolutionEvaluation? {
        settlement?.evaluations.first {
            $0.nextLevelID != nil && !$0.missingEvolutionRequirements.isEmpty
        }
    }

    private func houseName(_ levelID: Int) -> String {
        guard let name = models.buildings[houseLevelID: levelID]?.name else {
            return "住宅 #\(levelID)"
        }
        return ClassicTextLocalization.houseName(name)
    }

    private func requirementDescription(_ requirement: HouseEvolutionRequirement) -> String {
        switch requirement {
        case let .desirability(current, required):
            return "宜居度 \(current)/\(required)"
        case let .service(service):
            return service.chineseTitle
        case let .foodQuality(current, required):
            let currentName = FoodQuality(rawValue: current)
                .map { ClassicTextLocalization.foodQualityName($0) } ?? "\(current)"
            let requiredName = FoodQuality(rawValue: required)
                .map { ClassicTextLocalization.foodQualityName($0) } ?? "\(required)"
            return "食物品质 \(currentName)/\(requiredName)"
        case let .commodityAlternatives(ids):
            return ids.map {
                models.trade[commodityID: $0]
                    .map { ClassicTextLocalization.commodityName($0.name) }
                    ?? "商品 #\($0)"
            }.joined(separator: "或")
        }
    }
}
