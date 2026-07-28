import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// The six labeled groups used by the categorized construction toolbar.
/// Order here drives the display order of the accordion sections.
enum ConstructionToolCategory: String, CaseIterable, Identifiable {
    case residential = "住宅"
    case production = "生产"
    case military = "军事"
    case civic = "市政"
    case religious = "宗教"
    case aesthetics = "美化"
    case monuments = "纪念"
    case infrastructure = "基础设施"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .residential: "house.fill"
        case .production: "gearshape.2.fill"
        case .military: "shield.fill"
        case .civic: "building.columns.fill"
        case .religious: "sparkles"
        case .aesthetics: "leaf.fill"
        case .monuments: "building.columns.fill"
        case .infrastructure: "point.topleft.down.to.point.bottomright.curvepath"
        }
    }

    /// Original city-panel family used when `China_Interface` is available.
    ///
    /// The Great Wall strip button (`.infrastructure`) is the monument /
    /// defense category in the original UI — roads use a dirt-road tile icon
    /// instead (see `OriginalInterfaceUtilitySpriteCatalog.roadTerrainLocalID`).
    var originalInterfaceIcon: OriginalInterfaceIcon? {
        switch self {
        case .residential: .residential
        case .production: .agriculture
        case .military: .military
        case .civic: .government
        case .religious: .religion
        case .aesthetics: .aesthetics
        case .monuments: .infrastructure
        case .infrastructure: nil
        }
    }
}

enum NativeConstructionTool: String, CaseIterable, Identifiable {
    case inspect
    case demolish
    case clearLand
    case road
    case rally
    case house
    case warehouse
    case mill
    case market
    case clayPit
    case kiln
    case well
    case herbalist
    case acupuncture
    case inspectorTower
    case taxOffice
    case musicSchool
    case acrobatSchool
    case dramaSchool
    case ancestralShrine
    case confucianAcademy
    case daoistShrine
    // Sprint 2 — expanded building menu (20 new tools).
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
    case huntingCamp
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

    var id: Self { self }

    var supportsDragPlacement: Bool {
        switch self {
        case .road, .house, .farmland, .cityWall, .demolish, .clearLand: true
        default: false
        }
    }

    /// Rotation is meaningful only when the original assets or footprint have
    /// a distinct second orientation. Keeping this explicit prevents square,
    /// symmetric tools such as wells from presenting an apparent no-op.
    var supportsRotation: Bool {
        if self == .house || self == .cityWall { return true }
        guard let buildingID,
              let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID
              ) else { return false }
        return footprint.width != footprint.height
    }

    var title: String {
        switch self {
        case .inspect: "浏览"
        case .demolish: "拆除"
        case .clearLand: "清理树木"
        case .road: "道路"
        case .rally: "部队集结"
        case .house: "住宅"
        case .warehouse: "仓库"
        case .mill: "磨坊"
        case .market: "市场"
        case .clayPit: "粘土坑"
        case .kiln: "窑炉"
        case .well: "水井"
        case .herbalist: "药草铺"
        case .acupuncture: "针灸所"
        case .inspectorTower: "巡察塔"
        case .taxOffice: "税务所"
        case .musicSchool: "音乐学校"
        case .acrobatSchool: "杂技学校"
        case .dramaSchool: "戏剧学校"
        case .ancestralShrine: "祖先祠堂"
        case .confucianAcademy: "儒家书院"
        case .daoistShrine: "道观"
        case .farmland: "农田"
        case .lumberMill: "伐木棚"
        case .quarry: "石料场"
        case .granary: "粮仓"
        case .barracks: "步兵堡"
        case .cityWall: "城墙"
        case .gatehouse: "城门"
        case .tower: "城防塔"
        case .roadblock: "路障"
        case .administrativeCity: "行政城"
        case .palace: "宫殿"
        case .fort: "弩兵堡"
        case .catapultFort: "投石车堡"
        case .cavalryFort: "骑兵堡"
        case .chariotFort: "战车堡"
        case .fishingWharf: "捕鱼码头"
        case .huntingCamp: "猎场"
        case .ironMine: "炼铁炉"
        case .bronzeWorks: "青铜熔炉"
        case .lacquerGuild: "漆料棚"
        case .jadeWorkshop: "玉雕坊"
        case .silkWeaver: "养蚕棚"
        case .teaHouse: "制茶棚"
        case .bathhouse: "道教大庙"
        case .magistrate: "佛塔"
        case .watchtower: "瞭望塔"
        case .garden: "花园"
        case .decorativeSculpture: "装饰雕塑"
        case .ornateSculpture: "华丽雕塑"
        case .floweringTree: "花树"
        case .waysidePavilion: "路亭"
        case .pond: "池塘"
        case .taiChiPark: "太极园"
        case .privateGarden: "私家园林"
        case .laborersCamp: "劳工营"
        case .carpentersGuild: "木匠行会"
        case .masonsGuild: "石匠行会"
        case .ceramistsGuild: "陶工行会"
        case .tumulus: "陵冢"
        case .grandTumulus: "大陵冢"
        case .greatTemple: "大庙"
        case .splendidTemple: "宏伟庙宇"
        case .grandPagoda: "大佛塔"
        }
    }

    var symbol: String {
        switch self {
        case .inspect: "hand.draw"
        case .demolish: "trash.fill"
        case .clearLand: "tree.fill"
        case .road: "point.topleft.down.to.point.bottomright.curvepath"
        case .rally: "flag.checkered"
        case .house: "house.fill"
        case .warehouse: "shippingbox.fill"
        case .mill: "gearshape.2.fill"
        case .market: "storefront.fill"
        case .clayPit: "mountain.2.fill"
        case .kiln: "flame.fill"
        case .well: "drop.fill"
        case .herbalist: "leaf.fill"
        case .acupuncture: "cross.case.fill"
        case .inspectorTower: "wrench.and.screwdriver.fill"
        case .taxOffice: "building.columns.fill"
        case .musicSchool: "music.note"
        case .acrobatSchool: "figure.gymnastics"
        case .dramaSchool: "theatermasks.fill"
        case .ancestralShrine: "house.lodge.fill"
        case .confucianAcademy: "books.vertical.fill"
        case .daoistShrine: "sparkles"
        case .farmland: "leaf.circle.fill"
        case .lumberMill: "tree.circle.fill"
        case .quarry: "mountain.2.circle.fill"
        case .granary: "shippingbox.circle.fill"
        case .barracks: "shield.fill"
        case .cityWall: "rectangle.3.group.fill"
        case .gatehouse: "door.left.hand.closed"
        case .tower: "shield.lefthalf.filled"
        case .roadblock: "nosign"
        case .administrativeCity: "building.2.fill"
        case .palace: "crown.fill"
        case .fort: "scope"
        case .catapultFort: "burst.fill"
        case .cavalryFort: "figure.equestrian.sports"
        case .chariotFort: "arrow.up.right"
        case .fishingWharf: "fish.fill"
        case .huntingCamp: "pawprint.fill"
        case .ironMine: "hammer.fill"
        case .bronzeWorks: "gearshape.circle.fill"
        case .lacquerGuild: "paintbrush.pointed.fill"
        case .jadeWorkshop: "diamond.fill"
        case .silkWeaver: "scissors"
        case .teaHouse: "cup.and.saucer.fill"
        case .bathhouse: "bathtub.fill"
        case .magistrate: "gavel.fill"
        case .watchtower: "eye.circle.fill"
        case .garden: "leaf.fill"
        case .decorativeSculpture: "person.crop.square.fill"
        case .ornateSculpture: "seal.fill"
        case .floweringTree: "tree.fill"
        case .waysidePavilion: "house.lodge.fill"
        case .pond: "drop.circle.fill"
        case .taiChiPark: "circle.hexagongrid.fill"
        case .privateGarden: "camera.macro"
        case .laborersCamp: "figure.strengthtraining.traditional"
        case .carpentersGuild: "hammer.fill"
        case .masonsGuild: "mountain.2.fill"
        case .ceramistsGuild: "flame.fill"
        case .tumulus, .grandTumulus: "triangle.fill"
        case .greatTemple, .splendidTemple: "building.columns.fill"
        case .grandPagoda: "building.fill"
        }
    }

    var buildingID: Int? {
        switch self {
        case .inspect, .demolish, .clearLand, .road, .rally: nil
        case .house: 2
        case .warehouse: 54
        case .mill: 53
        case .market: 59
        case .clayPit: 35
        case .kiln: 43
        case .well: 72
        case .herbalist: 207
        case .acupuncture: 208
        case .inspectorTower: 124
        case .taxOffice: 125
        case .musicSchool: 211
        case .acrobatSchool: 212
        case .dramaSchool: 213
        case .ancestralShrine: 214
        case .confucianAcademy: 219
        case .daoistShrine: 215
        case .farmland: 193
        case .lumberMill: 38
        case .quarry: 36
        case .granary: 54
        case .barracks: 221
        case .cityWall: 129
        case .gatehouse: 130
        case .tower: 131
        case .roadblock: 126
        case .administrativeCity: 209
        case .palace: 110
        case .fort: 220
        case .catapultFort: 223
        case .cavalryFort: 224
        case .chariotFort: 225
        case .fishingWharf: 31
        case .huntingCamp: 33
        case .ironMine: 40
        case .bronzeWorks: 39
        case .lacquerGuild: 238
        case .jadeWorkshop: 46
        case .silkWeaver: 239
        case .teaHouse: 237
        case .bathhouse: 216
        case .magistrate: 218
        case .watchtower: 127
        case .garden: 115
        case .decorativeSculpture: 116
        case .ornateSculpture: 117
        case .floweringTree: 118
        case .waysidePavilion: 119
        case .pond: 120
        case .taiChiPark: 121
        case .privateGarden: 122
        case .laborersCamp: 233
        case .carpentersGuild: 52
        case .masonsGuild: 235
        case .ceramistsGuild: 236
        case .tumulus: 76
        case .grandTumulus: 77
        case .greatTemple: 78
        case .splendidTemple: 79
        case .grandPagoda: 93
        }
    }

    /// Toolbar accordion section this tool belongs to.
    var category: ConstructionToolCategory {
        switch self {
        case .house, .well, .herbalist, .acupuncture,
             .musicSchool, .acrobatSchool, .dramaSchool:
            .residential
        case .warehouse, .mill, .market, .clayPit, .kiln,
             .farmland, .lumberMill, .quarry, .granary, .fishingWharf,
             .huntingCamp, .ironMine, .bronzeWorks, .jadeWorkshop,
             .lacquerGuild, .silkWeaver, .teaHouse:
            .production
        case .barracks, .cityWall, .gatehouse, .tower, .fort, .catapultFort,
             .cavalryFort, .chariotFort, .watchtower:
            .military
        case .inspectorTower, .taxOffice, .administrativeCity,
             .palace, .magistrate, .bathhouse:
            .civic
        case .ancestralShrine, .confucianAcademy, .daoistShrine:
            .religious
        case .garden, .decorativeSculpture, .ornateSculpture, .floweringTree,
             .waysidePavilion, .pond, .taiChiPark, .privateGarden:
            .aesthetics
        case .laborersCamp, .carpentersGuild, .masonsGuild, .ceramistsGuild,
             .tumulus, .grandTumulus, .greatTemple, .splendidTemple, .grandPagoda:
            .monuments
        case .inspect, .demolish, .clearLand, .road, .roadblock, .rally:
            .infrastructure
        }
    }
}

extension AgriculturalCrop {
    var localizedTitle: String {
        switch self {
        case .soybeans: "大豆"
        case .cabbage: "卷心菜"
        case .millet: "小米"
        case .rice: "稻米"
        case .wheat: "小麦"
        case .hemp: "麻"
        case .tea: "茶"
        case .mulberry: "桑树"
        case .lacquer: "漆树"
        }
    }

    var fieldTitle: String {
        switch category {
        case .field, .hemp: "\(localizedTitle)田"
        case .orchard: "\(localizedTitle)园"
        }
    }
}

extension IsometricBuildingOrientation {
    var localizedTitle: String {
        switch self {
        case .northSouth: "南北向"
        case .eastWest: "东西向"
        }
    }

    var directionSymbol: String {
        switch self {
        case .northSouth: "arrow.up.and.down"
        case .eastWest: "arrow.left.and.right"
        }
    }
}

struct ConstructionToolbar: View {
    @ObservedObject var library: LibraryModel
    let city: DeterministicCityState
    @State private var expandedCategories = Set(ConstructionToolCategory.allCases)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label("地图建造", systemImage: "hammer.fill")
                    .font(EmperorTheme.headlineMedium)
                Text(constructionInstruction(library.constructionTool))
                    .font(EmperorTheme.bodySmall)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    library.rotateConstructionTool()
                } label: {
                    Label(
                        "旋转 · \(library.constructionOrientation.localizedTitle)",
                        systemImage: library.constructionOrientation.directionSymbol
                    )
                }
                .disabled(!library.constructionTool.supportsRotation)
                .keyboardShortcut("r", modifiers: [])
                .accessibilityIdentifier("construction-rotate")
            }
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ConstructionToolCategory.allCases) { category in
                        let categoryTools = NativeConstructionTool.allCases.filter {
                            $0.category == category
                        }
                        let tools = categoryTools.filter(isAvailable)
                            + categoryTools.filter { !isAvailable($0) }
                        if !tools.isEmpty {
                            DisclosureGroup(isExpanded: Binding(
                                get: { expandedCategories.contains(category) },
                                set: { isExpanded in
                                    if isExpanded { expandedCategories.insert(category) }
                                    else { expandedCategories.remove(category) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(tools) { tool in
                                        Button {
                                            library.selectConstructionTool(tool)
                                        } label: {
                                            HStack(spacing: 7) {
                                                constructionToolIcon(tool)
                                                Text(tool.title)
                                            }
                                                .font(EmperorTheme.labelMedium)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 7)
                                                .frame(maxWidth: .infinity)
                                                .foregroundStyle(
                                                    library.constructionTool == tool ? Color.white : Color.primary
                                                )
                                                .background(
                                                    library.constructionTool == tool
                                                        ? Color.accentColor
                                                        : Color.primary.opacity(0.08),
                                                    in: Capsule()
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!isAvailable(tool))
                                        .accessibilityIdentifier("construction-tool-\(tool.rawValue)")
                                        .help(
                                            isAvailable(tool)
                                                ? constructionInstruction(tool)
                                                : "\(tool.title)：本关暂未开放"
                                        )
                                    }
                                }
                                .padding(.top, 4)
                            } label: {
                                HStack(spacing: 6) {
                                    categoryIcon(category)
                                    Text(category.rawValue)
                                }
                                .font(EmperorTheme.bold(size: 12))
                                .accessibilityIdentifier("construction-category-\(category.accessibilitySlug)")
                            }
                        }
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxHeight: 250)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func constructionInstruction(_ tool: NativeConstructionTool) -> String {
        switch tool {
        case .inspect: "悬停住宅查看升级条件，点击查看详情"
        case .demolish: "点击或拖动区域拆除 · 右键取消"
        case .clearLand: "点击或拖动区域清理树木与灌木 · 右键取消"
        case .road: "点击或拖动铺路 · 每格原版造价 2 · 右键取消"
        case .rally: "先点军队标记多选，再点地面下令；右键取消"
        case .house:
            "点击或拖动建造 2×2 住宅 · \(library.constructionOrientation.localizedTitle) · R 旋转 · 右键取消"
        case .farmland:
            "点击或拖动种植\(library.selectedAgriculturalCrop.fieldTitle) · 须邻接道路 · 右键取消"
        default:
            if let buildingID = tool.buildingID,
               let footprint = OriginalBuildingFootprintCatalog.footprint(
                forBuildingID: buildingID,
                orientation: library.constructionOrientation
               ) {
                "点击占地左上格放置 · \(footprint.width)×\(footprint.height)"
                    + (tool.supportsRotation
                        ? " · \(library.constructionOrientation.localizedTitle) · R 旋转"
                        : "")
                    + " · 右键取消"
            } else {
                "选择建造工具"
            }
        }
    }

    @ViewBuilder
    private func categoryIcon(_ category: ConstructionToolCategory) -> some View {
        if category == .infrastructure,
           let sprite = library.renderedMap?.roadToolIconSprite() {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        } else if let icon = category.originalInterfaceIcon,
           let imageID = OriginalInterfaceSpriteCatalog.imageID(for: icon),
           let sprite = library.interfaceSprites[imageID] {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        } else {
            Image(systemName: category.symbol)
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func constructionToolIcon(_ tool: NativeConstructionTool) -> some View {
        if tool == .road,
           let sprite = library.renderedMap?.roadToolIconSprite() {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        } else if let imageID = utilityInterfaceImageID(for: tool),
                  let sprite = library.interfaceSprites[imageID] {
            Image(decorative: sprite.image, scale: 1)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        } else {
            Image(systemName: tool.symbol)
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        }
    }

    private func utilityInterfaceImageID(for tool: NativeConstructionTool) -> Int? {
        switch tool {
        case .clearLand:
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .clearLand)
        case .demolish:
            OriginalInterfaceUtilitySpriteCatalog.imageID(for: .demolish)
        default:
            nil
        }
    }

    private func isAvailable(_ tool: NativeConstructionTool) -> Bool {
        if tool == .rally {
            guard city.missionSettings != nil else { return true }
            return !city.military.forts.isEmpty || !city.military.defensiveStructures.isEmpty
        }
        return tool.buildingID.map(city.isBuildingAvailableInCampaign) ?? true
    }
}

private extension ConstructionToolCategory {
    var accessibilitySlug: String {
        switch self {
        case .residential: "residential"
        case .production: "production"
        case .military: "military"
        case .civic: "civic"
        case .religious: "religious"
        case .aesthetics: "aesthetics"
        case .monuments: "monuments"
        case .infrastructure: "infrastructure"
        }
    }
}
