import EmperorCore
import SwiftUI

// MARK: - Building info popup

/// Compact, non-interactive status shown while the pointer rests on a
/// building in browse mode. Houses surface the exact next-month upgrade
/// blockers; clicking still opens the complete inspector.
struct BuildingHoverStatusCard: View {
    let target: InspectedTarget
    let city: DeterministicCityState
    let models: OriginalEconomyModels

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: target.isHouse ? "house.fill" : "building.2.fill")
                    .foregroundStyle(EmperorTheme.primary)
                Text(title)
                    .font(EmperorTheme.headlineSmall)
                    .foregroundStyle(EmperorTheme.onSurface)
            }
            Text(summary)
                .font(EmperorTheme.bodySmall)
                .foregroundStyle(summaryColor)
                .fixedSize(horizontal: false, vertical: true)
            if !details.isEmpty {
                Divider().overlay(EmperorTheme.border.opacity(0.55))
                ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                    Label(detail, systemImage: "xmark.circle.fill")
                        .font(EmperorTheme.labelMedium)
                        .foregroundStyle(EmperorTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("左键或右键查看详情")
                .font(EmperorTheme.caption)
                .foregroundStyle(EmperorTheme.onSurfaceMuted)
        }
        .padding(10)
        .frame(width: 272, alignment: .leading)
        .background(EmperorTheme.surfaceDeep.opacity(0.94))
        .overlay(Rectangle().strokeBorder(EmperorTheme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("building-hover-status")
        .accessibilityLabel(title)
        .accessibilityValue(([summary] + details).joined(separator: "；"))
    }

    private var title: String {
        switch target {
        case let .placed(placement):
            NativeConstructionTool.allCases.first {
                $0.buildingID == placement.buildingID
            }?.title ?? models.buildings[buildingID: placement.buildingID]
                .map { ClassicTextLocalization.authoredName($0.name) }
                ?? "建筑 #\(placement.buildingID)"
        case let .house(house):
            models.buildings[houseLevelID: house.houseLevelID]
                .map { ClassicTextLocalization.houseName($0.name) }
                ?? "住宅"
        }
    }

    private var summary: String {
        switch target {
        case .placed:
            return "右键可调整建筑设置"
        case let .house(house):
            guard house.residents > 0 else {
                return "尚未入住；有居民后才会在月末评估升级"
            }
            guard let evaluation = evaluation(for: house) else {
                return "当前住宅资料不足，暂时无法评估升级"
            }
            guard let nextLevelID = evaluation.nextLevelID else {
                return "已达到当前住宅序列的最高等级"
            }
            let nextName = models.buildings[houseLevelID: nextLevelID]
                .map { ClassicTextLocalization.houseName($0.name) }
                ?? "等级 #\(nextLevelID)"
            if evaluation.missingEvolutionRequirements.isEmpty {
                return "条件已满足，将在下次月结升级为 \(nextName)"
            }
            return "暂时不能升级为 \(nextName)"
        }
    }

    private var summaryColor: Color {
        switch target {
        case .placed:
            return EmperorTheme.onSurfaceMuted
        case let .house(house):
            guard let evaluation = evaluation(for: house),
                  evaluation.nextLevelID != nil else {
                return EmperorTheme.onSurfaceMuted
            }
            return evaluation.missingEvolutionRequirements.isEmpty
                ? EmperorTheme.success
                : EmperorTheme.warning
        }
    }

    private var details: [String] {
        guard case let .house(house) = target,
              let evaluation = evaluation(for: house) else { return [] }
        return evaluation.missingEvolutionRequirements.map {
            houseEvolutionRequirementDescription($0, models: models)
        }
    }

    private func evaluation(for house: ResidentialUnit) -> HouseEvolutionEvaluation? {
        DeterministicHousingEvolution.evaluate(
            house: house,
            models: models.buildings,
            difficulty: city.difficulty
        )
    }
}

/// Floating inspector panel shown when a building or house is clicked in
/// inspect mode. Resolves category-specific detail: production buildings show
/// their recipe output, warehouses show storage, service buildings show their
/// service type, and houses show level/residents.
struct BuildingInfoPopup: View {
    let target: InspectedTarget
    let city: DeterministicCityState
    let models: OriginalEconomyModels
    let onSettingChange: (NativeBuildingSettingChange) -> Void
    let onClose: () -> Void

    private struct InfoRow {
        let label: String
        let value: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(EmperorTheme.headlineSmall)
                        .foregroundStyle(EmperorTheme.primary)
                    Text(subtitle)
                        .font(EmperorTheme.bodySmall)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(EmperorTheme.onSurfaceMuted)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            Divider().overlay(EmperorTheme.border)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                LabeledContent(row.label, value: row.value)
                    .font(EmperorTheme.bodySmall)
            }
            operationControls
        }
        .padding(14)
        .frame(width: 272, alignment: .leading)
        .foregroundStyle(EmperorTheme.onSurface)
        .background(EmperorTheme.surface)
        .overlay(
            Rectangle()
                .strokeBorder(EmperorTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }

    private var title: String {
        switch target {
        case let .placed(placement):
            chineseBuildingName(placement.buildingID)
        case .house:
            "住宅"
        }
    }

    private var subtitle: String {
        switch target {
        case let .placed(placement):
            placement.buildingID == 126
                ? "道路控制设施 · 建筑ID 126"
                : "\(categoryLabel(placement.category)) · 建筑ID \(placement.buildingID)"
        case let .house(house):
            "民居 · 等级ID \(house.houseLevelID)"
        }
    }

    private var rows: [InfoRow] {
        switch target {
        case let .placed(placement):
            placedRows(placement)
        case let .house(house):
            houseRows(house)
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        if case let .placed(placement) = target {
            switch placement.category {
            case .production:
                if let building = city.production.buildings.first(where: {
                    $0.id == placement.instanceID
                }) {
                    Divider()
                    settingHeader
                    Button {
                        onSettingChange(.productionEnabled(
                            instanceID: placement.instanceID,
                            enabled: !building.isEnabled
                        ))
                    } label: {
                        Label(
                            building.isEnabled ? "暂停生产" : "恢复生产",
                            systemImage: building.isEnabled ? "pause.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            case .warehouse:
                Divider()
                settingHeader
                Menu {
                    warehousePolicyButton("接收货物", policy: .accept, placement: placement)
                    warehousePolicyButton("拒收货物", policy: .doNotAccept, placement: placement)
                    warehousePolicyButton("主动调取", policy: .get, placement: placement)
                } label: {
                    Label("统一仓储模式", systemImage: "shippingbox.fill")
                        .frame(maxWidth: .infinity)
                }
                if let warehouse = city.logistics.warehouses.first(where: {
                    $0.id == placement.instanceID
                }) {
                    DisclosureGroup {
                        ScrollView {
                            LazyVStack(spacing: 5) {
                                ForEach(models.trade.commodities) { commodity in
                                    HStack(spacing: 6) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(ClassicTextLocalization.commodityName(commodity.name))
                                                .lineLimit(1)
                                            Text("库存 \(warehouse.inventoryByCommodityID[commodity.id, default: 0] / 100)")
                                                .font(EmperorTheme.labelSmall)
                                                .foregroundStyle(EmperorTheme.onSurfaceMuted)
                                        }
                                        Spacer(minLength: 4)
                                        Menu {
                                            warehouseCommodityPolicyButton(
                                                "接收",
                                                policy: .accept,
                                                warehouseID: placement.instanceID,
                                                commodityID: commodity.id
                                            )
                                            warehouseCommodityPolicyButton(
                                                "拒收",
                                                policy: .doNotAccept,
                                                warehouseID: placement.instanceID,
                                                commodityID: commodity.id
                                            )
                                            warehouseCommodityPolicyButton(
                                                "调取",
                                                policy: .get,
                                                warehouseID: placement.instanceID,
                                                commodityID: commodity.id
                                            )
                                        } label: {
                                            Text(warehousePolicyTitle(
                                                warehouse.policy(for: commodity.id)
                                            ))
                                                .frame(minWidth: 58, alignment: .trailing)
                                        }
                                        .menuStyle(.borderlessButton)
                                    }
                                    .font(EmperorTheme.bodySmall)
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    } label: {
                        Label("按商品设置", systemImage: "slider.horizontal.3")
                            .font(EmperorTheme.bodySmall)
                    }
                }
            case .trading:
                if let trading = city.trade.buildings.first(where: {
                    $0.id == placement.instanceID
                }) {
                    let isEnabled = !trading.importingCommodityIDs.isEmpty
                        || !trading.exportingCommodityIDs.isEmpty
                    Divider()
                    settingHeader
                    Button {
                        onSettingChange(.tradeEnabled(
                            tradingBuildingID: placement.instanceID,
                            enabled: !isEnabled
                        ))
                    } label: {
                        Label(
                            isEnabled ? "暂停进出口" : "恢复进出口",
                            systemImage: isEnabled ? "pause.fill" : "arrow.left.arrow.right"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    private var settingHeader: some View {
        Text("操作模式")
            .font(EmperorTheme.bold(size: 12))
            .foregroundStyle(.secondary)
    }

    private func warehousePolicyButton(
        _ title: String,
        policy: WarehouseCommodityPolicy,
        placement: PlacedBuilding
    ) -> some View {
        Button(title) {
            onSettingChange(.warehousePolicy(
                warehouseID: placement.instanceID,
                policy: policy
            ))
        }
    }

    private func warehouseCommodityPolicyButton(
        _ title: String,
        policy: WarehouseCommodityPolicy,
        warehouseID: Int,
        commodityID: Int
    ) -> some View {
        Button(title) {
            onSettingChange(.warehouseCommodityPolicy(
                warehouseID: warehouseID,
                commodityID: commodityID,
                policy: policy
            ))
        }
    }

    private func warehousePolicyTitle(_ policy: WarehouseCommodityPolicy) -> String {
        switch policy {
        case .doNotAccept: "拒收"
        case .accept: "接收"
        case .get: "调取"
        }
    }

    private func placedRows(_ placement: PlacedBuilding) -> [InfoRow] {
        var rows: [InfoRow] = [
            InfoRow(label: "建筑ID", value: "\(placement.buildingID)"),
            InfoRow(
                label: "类型",
                value: placement.buildingID == 126
                    ? "道路控制设施"
                    : categoryLabel(placement.category)
            ),
            InfoRow(label: "占地", value: "\(placement.footprint.width)×\(placement.footprint.height)"),
            InfoRow(
                label: "道路接入点",
                value: "(\(placement.roadAccessPoint.x), \(placement.roadAccessPoint.y))"
            )
        ]
        if let assignment = city.workforceAssignment(
            for: placement,
            models: models.buildings
        ), assignment.requiredWorkers > 0 {
            rows.append(InfoRow(
                label: "劳工",
                value: "\(assignment.assignedWorkers)/\(assignment.requiredWorkers) 人"
            ))
            if !assignment.isFullyStaffed {
                rows.append(InfoRow(label: "运行状态", value: "缺少劳工，设施暂停"))
            }
        }

        switch placement.category {
        case .production:
            if let building = city.production.buildings.first(where: { $0.id == placement.instanceID }) {
                rows.append(InfoRow(
                    label: "操作模式",
                    value: building.isEnabled ? "运行" : "暂停"
                ))
                if let agriculture = building.agriculture {
                    let cropName = models.trade[
                        commodityID: agriculture.crop.outputCommodityID
                    ].map {
                        ClassicTextLocalization.commodityName($0.name)
                    } ?? ClassicTextLocalization.commodityName(agriculture.crop.rawValue)
                    rows.append(InfoRow(label: "作物", value: cropName))
                    rows.append(InfoRow(label: "田块", value: "\(agriculture.fieldCount) 块"))
                } else if let recipe = OriginalProductionCatalog.recipe(forBuildingID: placement.buildingID) {
                    let outputName = models.trade[commodityID: recipe.outputCommodityID]
                        .map { ClassicTextLocalization.commodityName($0.name) }
                        ?? "商品 #\(recipe.outputCommodityID)"
                    rows.append(InfoRow(label: "配方产出", value: "\(outputName) ×\(recipe.outputAmount / 100)"))
                }
                let stored = building.outputInventoryByCommodityID.values.reduce(0, +)
                rows.append(InfoRow(label: "待运库存", value: "\(stored / 100) 车"))
            } else {
                rows.append(InfoRow(label: "劳工", value: "未投产"))
            }
        case .warehouse:
            if let warehouse = city.logistics.warehouses.first(where: { $0.id == placement.instanceID }) {
                rows.append(
                    InfoRow(
                        label: "仓储",
                        value: "\(warehouse.storedAmount / 100)/\(warehouse.capacity / 100) 车"
                    )
                )
                let kinds = warehouse.inventoryByCommodityID.values.filter { $0 > 0 }.count
                rows.append(InfoRow(label: "存货种类", value: "\(kinds) 种"))
            } else {
                rows.append(InfoRow(label: "仓储", value: "—"))
            }
        case .mill:
            if let mill = city.logistics.mills.first(where: { $0.id == placement.instanceID }) {
                rows.append(InfoRow(label: "磨坊储粮", value: "\(mill.storedAmount / 100) 车"))
            } else {
                rows.append(InfoRow(label: "磨坊储粮", value: "—"))
            }
        case .market:
            rows.append(InfoRow(label: "职能", value: "向住宅配送食物与商品"))
            if let market = city.markets.markets.first(where: {
                $0.id == placement.instanceID
            }) {
                let capacity = OriginalMarketCatalog.shopCapacity(
                    forMarketBuildingID: market.buildingID
                ) ?? 0
                rows.append(InfoRow(
                    label: "商铺",
                    value: "\(market.shopBuildingIDs.count)/\(capacity)"
                ))
                if !market.shopBuildingIDs.isEmpty {
                    rows.append(InfoRow(
                        label: "铺面",
                        value: market.shopBuildingIDs
                            .map(chineseBuildingName)
                            .joined(separator: "、")
                    ))
                }
            }
        case .trading:
            rows.append(InfoRow(label: "职能", value: "陆海贸易集散"))
            if let trading = city.trade.buildings.first(where: {
                $0.id == placement.instanceID
            }) {
                let enabled = !trading.importingCommodityIDs.isEmpty
                    || !trading.exportingCommodityIDs.isEmpty
                rows.append(InfoRow(label: "操作模式", value: enabled ? "进出口开启" : "暂停"))
            }
        case .residentialService:
            if let service = city.residentialServiceBuildings.first(where: { $0.id == placement.instanceID }) {
                rows.append(InfoRow(label: "服务类型", value: service.service.chineseTitle))
            }
        case .military:
            if let fort = city.military.forts.first(where: { $0.id == placement.instanceID }),
               let unit = city.military.units.first(where: { $0.id == fort.unitID }) {
                let figure = models.figures[figureID: unit.figureID]
                rows.append(InfoRow(
                    label: "部队",
                    value: figure.map {
                        ClassicTextLocalization.authoredName($0.name)
                    } ?? "人物 #\(unit.figureID)"
                ))
                rows.append(InfoRow(
                    label: "兵力",
                    value: "\(unit.survivingSoldiers(model: figure))/\(unit.originalSoldierCount) 人"
                ))
                let status = switch unit.status {
                case .garrisoned: "驻防"
                case .marching: "行军"
                case .victorious: "获胜"
                case .destroyed: "覆灭"
                }
                rows.append(InfoRow(label: "状态", value: status))
                rows.append(InfoRow(label: "士气", value: "\(unit.morale)"))
            } else if let defense = city.military.defensiveStructures.first(where: {
                $0.id == placement.instanceID
            }) {
                let kind = switch defense.kind {
                case .cityWall: "城墙"
                case .cityGate: "城门"
                case .tower: "城防塔"
                }
                rows.append(InfoRow(label: "防御类型", value: kind))
                rows.append(InfoRow(
                    label: "耐久",
                    value: "\(defense.integrity)/\(defense.maximumIntegrity)"
                ))
                rows.append(InfoRow(
                    label: "哨兵",
                    value: "\(city.military.sentries.filter { $0.defenseID == defense.id }.count) 人"
                ))
            }
        case .aesthetic:
            if placement.buildingID == 126 {
                rows.append(InfoRow(label: "用途", value: "阻止无目的漫游人员通过"))
                rows.append(InfoRow(label: "放行", value: "采购、运输、移民等目的性人员"))
                break
            }
            if let construction = city.aesthetics.constructions.first(where: {
                $0.id == placement.instanceID
            }) {
                let purpose = switch construction.kind {
                case .scenery: "景观美化"
                case .irrigationPump: "灌溉水车"
                case .laborersCamp: "劳工营"
                case .carpentersGuild: "木匠行会"
                case .masonsGuild: "石匠行会"
                case .ceramistsGuild: "陶工行会"
                case .monument: "纪念建筑"
                }
                rows.append(InfoRow(label: "用途", value: purpose))
            }
            if let project = city.aesthetics.monuments.first(where: {
                $0.id == placement.instanceID
            }) {
                rows.append(InfoRow(label: "工程进度", value: "\(project.completionPercent)%"))
                rows.append(InfoRow(
                    label: "施工量",
                    value: "\(project.completedWork)/\(project.requiredWork)"
                ))
            }
            if let evaluation = city.fengShuiSummary(models: models.buildings)
                .evaluations.first(where: { $0.buildingKey.instanceID == placement.instanceID
                    && $0.buildingKey.category == .aesthetic }) {
                let quality = switch evaluation.quality {
                case .neutral: "中性"
                case .harmonious: "和谐"
                case .inauspicious: "不吉"
                }
                rows.append(InfoRow(label: "风水", value: quality))
            }
        }
        return rows
    }

    private func houseRows(_ house: ResidentialUnit) -> [InfoRow] {
        var rows: [InfoRow] = [
            InfoRow(label: "等级ID", value: "\(house.houseLevelID)"),
            InfoRow(label: "居民", value: "\(house.residents) 人"),
            InfoRow(label: "占地", value: "2×2"),
            InfoRow(label: "朝向", value: house.orientation.localizedTitle),
            InfoRow(label: "税务覆盖", value: house.hasTaxCoverage ? "是" : "否")
        ]
        if house.footprintMultiplier > 1 {
            rows.append(InfoRow(label: "合并户数", value: "\(house.footprintMultiplier)"))
        }
        if let levelName = models.buildings[houseLevelID: house.houseLevelID]?.name {
            rows.insert(
                InfoRow(
                    label: "等级名称",
                    value: ClassicTextLocalization.houseName(levelName)
                ),
                at: 1
            )
        }
        if let location = house.location {
            rows.append(InfoRow(label: "位置", value: "(\(location.x), \(location.y))"))
        }
        if house.residents == 0 {
            rows.append(InfoRow(label: "升级状态", value: "尚未入住"))
        } else if let evaluation = DeterministicHousingEvolution.evaluate(
            house: house,
            models: models.buildings,
            difficulty: city.difficulty
        ) {
            if let nextLevelID = evaluation.nextLevelID {
                let nextName = models.buildings[houseLevelID: nextLevelID]
                    .map { ClassicTextLocalization.houseName($0.name) }
                    ?? "等级 #\(nextLevelID)"
                rows.append(InfoRow(label: "下一等级", value: nextName))
            } else {
                rows.append(InfoRow(label: "升级状态", value: "已达最高等级"))
            }
            if evaluation.missingEvolutionRequirements.isEmpty,
               evaluation.nextLevelID != nil {
                rows.append(InfoRow(label: "升级状态", value: "条件已满足，等待月结"))
            } else if !evaluation.missingEvolutionRequirements.isEmpty {
                rows.append(InfoRow(
                    label: "升级缺口",
                    value: evaluation.missingEvolutionRequirements
                        .map {
                            houseEvolutionRequirementDescription($0, models: models)
                        }
                        .joined(separator: "、")
                ))
            }
        } else {
            rows.append(InfoRow(
                label: "升级状态",
                value: "当前住宅资料不足"
            ))
        }
        return rows
    }

    /// Chinese display name for a building ID, preferring the construction-tool
    /// title (all Chinese) and falling back to the original model name.
    private func chineseBuildingName(_ buildingID: Int) -> String {
        if let tool = NativeConstructionTool.allCases.first(where: { $0.buildingID == buildingID }) {
            return tool.title
        }
        return models.buildings[buildingID: buildingID]
            .map { ClassicTextLocalization.authoredName($0.name) }
            ?? "建筑 #\(buildingID)"
    }

    private func categoryLabel(_ category: PlacedBuildingCategory) -> String {
        switch category {
        case .production: "生产建筑"
        case .warehouse: "仓库"
        case .mill: "磨坊"
        case .market: "市场"
        case .trading: "贸易建筑"
        case .residentialService: "市政服务"
        case .military: "军事设施"
        case .aesthetic: "美化/纪念建筑"
        }
    }
}

private extension InspectedTarget {
    var isHouse: Bool {
        if case .house = self { return true }
        return false
    }
}

private func houseEvolutionRequirementDescription(
    _ requirement: HouseEvolutionRequirement,
    models: OriginalEconomyModels
) -> String {
    switch requirement {
    case let .desirability(current, required):
        "宜居度 \(current)/\(required)"
    case let .service(service):
        "缺\(service.chineseTitle)"
    case let .foodQuality(current, required):
        "食物品质 \(current)/\(required)"
    case let .commodityAlternatives(ids):
        "缺" + ids.map {
            models.trade[commodityID: $0]
                .map { ClassicTextLocalization.commodityName($0.name) }
                ?? "商品 #\($0)"
        }
            .joined(separator: "或")
    }
}
