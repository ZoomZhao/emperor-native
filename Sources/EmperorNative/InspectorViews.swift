import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    let source: GameDataSource
    let catalog: GameDataCatalog
    let models: [ModelFileSummary]
    let economy: OriginalEconomyModels
    let map: MapProbe?
    let campaign: CampaignArchive?
    let embeddedCampaignMapCount: Int?
    let campaignMissionMaps: CampaignMissionMapArchive?
    let campaignGoals: CampaignGoalArchive?
    let campaignEvents: CampaignEventArchive?
    let campaignEmpireMap: CampaignEmpireMap?
    let city: DeterministicCityState?
    let latestSettlement: MonthlySettlement?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
            InspectorGroup("原版资源") {
                LabeledContent("地图", value: "\(catalog.maps.count)")
                LabeledContent("战役", value: "\(catalog.campaigns.count)")
                LabeledContent("精灵包", value: "\(catalog.spriteDescriptions.count)")
                LabeledContent("模型配置", value: "\(models.count)")
                LabeledContent("声音", value: "\(catalog.waveAudio.count + catalog.music.count)")
            }
            InspectorGroup("经济模型") {
                LabeledContent("建筑规则", value: "\(economy.buildings.buildings.count)")
                LabeledContent("住宅等级", value: "\(economy.buildings.houses.count)")
                LabeledContent("人物规则", value: "\(economy.figures.figures.count)")
                LabeledContent("商品价格", value: "\(economy.trade.prices.count)")
            }
            if let city {
                InspectorGroup("原生城市状态") {
                    LabeledContent("年月", value: "\(city.calendar.year) / \(city.calendar.month)")
                    LabeledContent("人口", value: "\(city.population)")
                    LabeledContent("容量", value: "\(city.housingCapacity(using: economy.buildings))")
                    LabeledContent("住宅", value: "\(city.houses.count)")
                    LabeledContent("道路格", value: "\(city.roadNetwork.points.count)")
                    LabeledContent("税务覆盖", value: "\(city.houses.count(where: \.hasTaxCoverage)) / \(city.houses.count)")
                    LabeledContent("国库", value: "\(city.economy.treasury)")
                    LabeledContent("累计收入", value: "\(city.economy.lifetimeIncome)")
                    LabeledContent("累计支出", value: "\(city.economy.lifetimeExpenses)")
                    LabeledContent("生产建筑", value: "\(city.production.buildings.count)")
                    LabeledContent(
                        "季节农场",
                        value: "\(city.production.buildings.count { $0.agriculture != nil })"
                    )
                    LabeledContent(
                        "农业田块",
                        value: "\(city.production.buildings.compactMap(\.agriculture).reduce(0) { $0 + $1.fieldCount })"
                    )
                    LabeledContent("实体仓库", value: "\(city.logistics.warehouses.count)")
                    LabeledContent("磨坊", value: "\(city.logistics.mills.count)")
                    LabeledContent(
                        "食物质量",
                        value: city.logistics.mills.first.map {
                            ClassicTextLocalization.foodQualityName($0.foodQuality)
                        } ?? "无"
                    )
                    LabeledContent("运货行人", value: "\(city.logistics.deliveryWalkers.count)")
                    LabeledContent("在途商旅", value: "\(city.trade.visitors.count)")
                    LabeledContent("仓储黏土", value: "\(city.logistics[commodityID: 18])")
                    LabeledContent("仓储陶瓷", value: "\(city.logistics[commodityID: 25])")
                    if let agriculture = city.production.lastAgriculturalSettlement {
                        LabeledContent("最近收获", value: "\(agriculture.harvests.reduce(0) { $0 + $1.outputAmount })")
                        LabeledContent("生长中农场", value: "\(agriculture.growingBuildingInstanceIDs.count)")
                        LabeledContent("受阻农场", value: "\(agriculture.blockedBuildingInstanceIDs.count)")
                    }
                    if let movement = city.logistics.lastMovement {
                        LabeledContent("运货步数", value: "\(movement.movedRoadSteps)")
                        LabeledContent("送达车次", value: "\(movement.deliveredLoads.count)")
                    }
                    LabeledContent("可用贸易路线", value: "\(city.trade.activePartnerCount)")
                    LabeledContent("已建贸易伙伴", value: "\(city.trade.establishedPartnerCount)")
                    LabeledContent("贸易建筑", value: "\(city.trade.buildings.count)")
                    LabeledContent(
                        "贸易站库存",
                        value: "\(city.trade.buildings.reduce(0) { $0 + $1.storedAmount })"
                    )
                    if let settlement = city.trade.lastSettlement {
                        LabeledContent("最近出口收入", value: "\(settlement.exportIncome)")
                        LabeledContent("最近进口支出", value: "\(settlement.importSpending)")
                    }
                    LabeledContent("已结算年度", value: "\(city.productionAccounting.completedCycleCount)")
                    LabeledContent(
                        "最佳陶瓷年产",
                        value: "\(city.productionAccounting.bestYearlyProductionUnitsByCommodityID[25, default: 0])"
                    )
                    LabeledContent("最佳年度利润", value: "\(city.productionAccounting.bestYearlyProfit)")
                    LabeledContent("市场", value: "\(city.markets.markets.count)")
                    LabeledContent("市场买手", value: "\(city.markets.buyers.count)")
                    LabeledContent("市场货郎", value: "\(city.markets.peddlers.count)")
                    LabeledContent(
                        "住宅陶瓷",
                        value: "\(city.houses.reduce(0) { $0 + $1[commodityID: 25] })"
                    )
                    LabeledContent(
                        "住宅食物",
                        value: "\(city.houses.reduce(0) { $0 + $1.foodSupplyAmount })"
                    )
                    if let settlement = city.markets.lastSettlement {
                        LabeledContent("商品配送", value: "\(settlement.householdDeliveries.count)")
                        LabeledContent("商品短缺", value: "\(settlement.underSuppliedHouseIDs.count)")
                    }
                    LabeledContent("道路行人", value: "\(city.walkers.walkers.count)")
                    LabeledContent(
                        "住宅服务建筑",
                        value: "\(city.residentialServiceBuildings.count)"
                    )
                    if let movement = city.walkers.lastMovement {
                        LabeledContent("行人步数", value: "\(movement.movedRoadSteps)")
                        LabeledContent("巡回完成", value: "\(movement.completedTrips)")
                    }
                    if let housing = city.lastHousingSettlement {
                        LabeledContent("住宅升级", value: "\(housing.evolvedCount)")
                        LabeledContent("住宅退化", value: "\(housing.devolvedCount)")
                        LabeledContent("迁出居民", value: "\(housing.displacedResidents)")
                    }
                    if let operations = city.operations.lastSettlement {
                        LabeledContent("可用劳力", value: "\(operations.workforce.availableWorkers)")
                        LabeledContent("岗位需求", value: "\(operations.workforce.requiredWorkers)")
                        LabeledContent("劳力缺口", value: "\(operations.workforce.workerShortage)")
                        LabeledContent("巡察建筑", value: "\(operations.inspectedBuildingKeys.count)")
                        LabeledContent("起火/倒塌", value: "\(operations.failures.count)")
                    }
                    if let safety = city.publicHealthSafety.lastSettlement {
                        LabeledContent("医疗覆盖", value: "\(safety.medicallyCoveredHouseIDs.count)")
                        LabeledContent("治安覆盖", value: "\(safety.protectedHouseIDs.count)")
                        LabeledContent("疾病死亡", value: "\(safety.diseaseDeaths)")
                        LabeledContent("失窃金额", value: "\(safety.stolenCash)")
                    }
                    LabeledContent(
                        "待防御入侵",
                        value: "\(city.campaignEvents.invasions.count { $0.status == .awaitingDefense })"
                    )
                    LabeledContent("灾害记录", value: "\(city.campaignEvents.disasters.count)")
                    LabeledContent(
                        "灾害减产",
                        value: "\(city.campaignEvents.conditions.agriculturalYieldPercent)%"
                    )
                    LabeledContent("战役消息", value: "\(city.campaignEvents.messages.count)")
                    LabeledContent("军事堡垒", value: "\(city.military.forts.count)")
                    LabeledContent(
                        "可战部队",
                        value: "\(city.military.units.count { $0.status != .destroyed })"
                    )
                    LabeledContent("战斗记录", value: "\(city.military.combatReports.count)")
                    LabeledContent("美化建筑", value: "\(city.aesthetics.constructions.count)")
                    LabeledContent(
                        "已完成纪念建筑",
                        value: "\(city.aesthetics.completedMonumentBuildingIDs.count)"
                    )
                    let fengShui = city.fengShuiSummary(models: economy.buildings)
                    LabeledContent("风水和谐", value: "\(fengShui.harmonyPercent)%")
                    LabeledContent("事务序号", value: "\(city.economy.transactionSequence)")
                }
                if let latestSettlement {
                    InspectorGroup("最近月结") {
                        LabeledContent("已征税人口", value: "\(latestSettlement.taxedPopulation)")
                        LabeledContent("未覆盖人口", value: "\(latestSettlement.untaxedPopulation)")
                        LabeledContent("入库税收", value: "\(latestSettlement.collectedTaxes)")
                        LabeledContent("未征税收", value: "\(latestSettlement.uncollectedTaxes)")
                        LabeledContent("民意影响", value: "\(latestSettlement.taxSentiment)")
                    }
                }
            }
            if let map {
                InspectorGroup("所选地图") {
                    LabeledContent("格式版本", value: map.formatVersion.map(String.init) ?? "未知")
                    LabeledContent("尺寸", value: "\(map.width ?? 0) × \(map.height ?? 0)")
                    LabeledContent("压缩块", value: "\(map.chunkCount)")
                    LabeledContent("解压大小", value: ByteCountFormatter.string(fromByteCount: Int64(map.decodedByteCount), countStyle: .file))
                }
            }
            if let campaign {
                InspectorGroup("所选战役") {
                    LabeledContent("任务", value: "\(campaign.missions.count)")
                    if let campaignGoals {
                        LabeledContent(
                            "胜利目标",
                            value: "\(campaignGoals.missions.reduce(0) { $0 + $1.goals.count })"
                        )
                        LabeledContent(
                            "目标归档",
                            value: campaignGoals.sectionOffset.map { "0x" + String($0, radix: 16) } ?? "自由建造"
                        )
                    }
                    if let campaignEvents {
                        LabeledContent(
                            "原版事件",
                            value: "\(campaignEvents.missions.reduce(0) { $0 + $1.events.count })"
                        )
                        LabeledContent(
                            "事件归档",
                            value: "v\(campaignEvents.archiveVersion) · 0x\(String(campaignEvents.sectionOffset, radix: 16))"
                        )
                    }
                    if let campaignMissionMaps {
                        LabeledContent("任务地图绑定", value: "\(campaignMissionMaps.missions.count)")
                        LabeledContent(
                            "地图名表",
                            value: campaignMissionMaps.mapNameTableOffset.map { "0x" + String($0, radix: 16) } ?? "无"
                        )
                    }
                    if let campaignEmpireMap {
                        LabeledContent("帝国城市", value: "\(campaignEmpireMap.activeCities.count) / \(CampaignEmpireMap.cityCount)")
                        LabeledContent("贸易城市", value: "\(campaignEmpireMap.tradingCities.count)")
                        LabeledContent("帝国对象", value: "\(campaignEmpireMap.objects.count)")
                        LabeledContent("帝国地图", value: "0x\(String(campaignEmpireMap.decodedOffset, radix: 16))")
                    }
                    if let embeddedCampaignMapCount {
                        LabeledContent("场景地图", value: "\(embeddedCampaignMapCount)")
                    }
                    LabeledContent("压缩块", value: "\(campaign.containerChunkCount)")
                    LabeledContent("任务表", value: "0x\(String(campaign.detectedMissionTableOffset, radix: 16))")
                    LabeledContent("解压大小", value: ByteCountFormatter.string(fromByteCount: Int64(campaign.decodedByteCount), countStyle: .file))
                }
            }
            InspectorGroup("数据源") {
                Text(source.root.path)
                    .font(EmperorTheme.caption)
                    .textSelection(.enabled)
            }
            }
            .padding(12)
        }
    }
}

struct SidebarGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(EmperorTheme.labelMedium)
        }
    }
}

struct InspectorGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 7) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(EmperorTheme.headlineMedium)
        }
    }
}
