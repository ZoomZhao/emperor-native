import EmperorCore
import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Original city-panel categories in their authored top-to-bottom order.
enum ConstructionToolCategory: String, CaseIterable, Identifiable {
    case residential = "住宅"
    case agriculture = "农业"
    case industry = "工业"
    case commerce = "商业"
    case safety = "安全"
    case government = "行政"
    case entertainment = "娱乐"
    case religious = "宗教"
    case military = "军事"
    case aesthetics = "美化"
    case monuments = "纪念"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .residential: "house.fill"
        case .agriculture: "leaf.fill"
        case .industry: "gearshape.2.fill"
        case .commerce: "shippingbox.fill"
        case .safety: "drop.fill"
        case .government: "building.columns.fill"
        case .entertainment: "theatermasks.fill"
        case .religious: "sparkles"
        case .military: "shield.fill"
        case .aesthetics: "leaf.fill"
        case .monuments: "building.columns.fill"
        }
    }

    /// Original city-panel family used when `China_Interface` is available.
    ///
    /// The Great Wall strip button (`.infrastructure`) is the monument
    /// category in the original UI — roads use a dirt-road tile icon
    /// instead (see `OriginalInterfaceUtilitySpriteCatalog.roadTerrainLocalID`).
    var originalInterfaceIcon: OriginalInterfaceIcon {
        switch self {
        case .residential: .residential
        case .agriculture: .agriculture
        case .industry: .industry
        case .commerce: .commerce
        // The archive's historical semantic names are misleading: #1339 is
        // the well/safety family, while #1347 is the fan/entertainment family.
        case .safety: .entertainment
        case .government: .government
        case .entertainment: .culture
        case .religious: .religion
        case .military: .military
        case .aesthetics: .aesthetics
        case .monuments: .infrastructure
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
    case eliteHouse
    case warehouse
    case mill
    case market
    case grandMarket
    case foodShop
    case hempShop
    case ceramicsShop
    case teaShop
    case silkShop
    case lacquerwareShop
    case bronzewareShop
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
    case irrigationPump
    case grandCanalSegment
    case earthenGreatWallSegment
    case largePalace
    case largePalacePhase
    case phasedMonumentPhase
    case cropFarm
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
    case lacquerwareWorkshop
    case jadeWorkshop
    case silkWeaver
    case weaver
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
    case undergroundVault
    case greatTemple
    case splendidTemple
    case grandPagoda

    var id: Self { self }

    var supportsDragPlacement: Bool {
        switch self {
        case .road, .house, .eliteHouse, .farmland, .cityWall, .demolish, .clearLand: true
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
        case .eliteHouse: "贵族住宅"
        case .warehouse: "仓库"
        case .mill: "磨坊"
        case .market: "市场"
        case .grandMarket: "大市场"
        case .foodShop: "食物铺"
        case .hempShop: "麻布铺"
        case .ceramicsShop: "陶器铺"
        case .teaShop: "茶铺"
        case .silkShop: "丝绸铺"
        case .lacquerwareShop: "漆器铺"
        case .bronzewareShop: "青铜器铺"
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
        case .irrigationPump: "灌溉水车"
        case .grandCanalSegment: "郑国渠分段"
        case .earthenGreatWallSegment: "土长城分段"
        case .largePalace: "大宫殿"
        case .largePalacePhase: "大宫殿施工"
        case .phasedMonumentPhase: "陵墓分段施工"
        case .cropFarm: "农场"
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
        case .lacquerwareWorkshop: "漆器作坊"
        case .jadeWorkshop: "玉雕坊"
        case .silkWeaver: "养蚕棚"
        case .weaver: "织布坊"
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
        case .undergroundVault: "地下兵马俑坑"
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
        case .eliteHouse: "house.and.flag.fill"
        case .warehouse: "shippingbox.fill"
        case .mill: "gearshape.2.fill"
        case .market: "storefront.fill"
        case .grandMarket: "storefront.circle.fill"
        case .foodShop: "takeoutbag.and.cup.and.straw.fill"
        case .hempShop: "tshirt.fill"
        case .ceramicsShop: "cup.and.saucer.fill"
        case .teaShop: "leaf.fill"
        case .silkShop: "scissors"
        case .lacquerwareShop: "paintbrush.fill"
        case .bronzewareShop: "seal.fill"
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
        case .irrigationPump: "water.waves"
        case .grandCanalSegment: "hammer.circle.fill"
        case .earthenGreatWallSegment: "hammer.circle"
        case .largePalace: "building.columns.fill"
        case .largePalacePhase: "hammer.circle.fill"
        case .phasedMonumentPhase: "hammer.circle"
        case .cropFarm: "building.2.crop.circle.fill"
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
        case .lacquerwareWorkshop: "paintbrush.fill"
        case .jadeWorkshop: "diamond.fill"
        case .silkWeaver: "scissors"
        case .weaver: "tshirt.fill"
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
        case .tumulus, .grandTumulus, .undergroundVault: "triangle.fill"
        case .greatTemple, .splendidTemple: "building.columns.fill"
        case .grandPagoda: "building.fill"
        }
    }

    var buildingID: Int? {
        switch self {
        case .inspect, .demolish, .clearLand, .road, .rally, .cropFarm,
             .grandCanalSegment, .earthenGreatWallSegment, .largePalacePhase: nil
        case .phasedMonumentPhase: nil
        case .house: 2
        case .eliteHouse: 11
        case .warehouse: 54
        case .mill: 53
        case .market: 59
        case .grandMarket: 60
        case .bronzewareShop: 64
        case .ceramicsShop: 65
        case .foodShop: 66
        case .hempShop: 67
        case .lacquerwareShop: 68
        case .silkShop: 69
        case .teaShop: 70
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
        case .irrigationPump: 203
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
        case .lacquerwareWorkshop: 44
        case .jadeWorkshop: 46
        case .silkWeaver: 239
        case .weaver: 47
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
        case .undergroundVault: 84
        case .greatTemple: 78
        case .splendidTemple: 79
        case .grandPagoda: 93
        case .largePalace: 82
        }
    }

    /// Toolbar accordion section this tool belongs to.
    var category: ConstructionToolCategory {
        switch self {
        case .house, .eliteHouse:
            .residential
        case .cropFarm, .farmland, .irrigationPump, .fishingWharf, .huntingCamp:
            .agriculture
        case .clayPit, .kiln, .lumberMill, .quarry, .ironMine, .bronzeWorks,
             .jadeWorkshop,
             .lacquerGuild, .lacquerwareWorkshop, .silkWeaver, .weaver, .teaHouse:
            .industry
        case .warehouse, .granary, .mill, .market, .grandMarket, .foodShop, .hempShop,
             .ceramicsShop, .teaShop, .silkShop, .lacquerwareShop,
             .bronzewareShop:
            .commerce
        case .well, .herbalist, .acupuncture, .watchtower,
             .inspect, .demolish, .clearLand, .road, .roadblock:
            .safety
        case .inspectorTower, .taxOffice, .administrativeCity, .palace:
            .government
        case .musicSchool, .acrobatSchool, .dramaSchool:
            .entertainment
        case .ancestralShrine, .confucianAcademy, .daoistShrine,
             .bathhouse, .magistrate:
            .religious
        case .barracks, .cityWall, .gatehouse, .tower, .fort, .catapultFort,
             .cavalryFort, .chariotFort, .rally:
            .military
        case .garden, .decorativeSculpture, .ornateSculpture, .floweringTree,
             .waysidePavilion, .pond, .taiChiPark, .privateGarden:
            .aesthetics
        case .laborersCamp, .carpentersGuild, .masonsGuild, .ceramistsGuild,
             .tumulus, .grandTumulus, .greatTemple, .splendidTemple, .grandPagoda,
             .undergroundVault, .grandCanalSegment, .earthenGreatWallSegment,
             .largePalace, .largePalacePhase, .phasedMonumentPhase:
            .monuments
        }
    }
}

extension NativeConstructionTool {
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
        case .cropFarm:
            "先在临路清地放置\(library.selectedAgriculturalCrop.localizedTitle)农场，再选择农田铺设田块"
        case .farmland:
            "点击或拖动种植\(library.selectedAgriculturalCrop.fieldTitle) · 须在同类农场耕作范围内 · 右键取消"
        case .market:
            "先放置 7×4 普通市场（4 个铺位），再选择具体商铺并点击市场内部"
        case .grandMarket:
            "先放置 7×6 大市场（6 个铺位），再选择具体商铺并点击市场内部"
        case .foodShop, .hempShop, .ceramicsShop, .teaShop, .silkShop,
             .lacquerwareShop, .bronzewareShop:
            "点击仍有空铺位的市场；同类商铺可以重复建造 · 右键取消"
        case .irrigationPump:
            "放在河岸清地，须同时邻接水面与道路 · 右键取消"
        case .grandCanalSegment:
            "点击地图中任意 4×4 郑国渠段推进当前施工阶段 · 右键取消"
        case .earthenGreatWallSegment:
            "点击 Badaling 山脊上的 4×4 土长城段推进当前施工阶段 · 右键取消"
        case .largePalacePhase:
            "点击已放置的大宫殿推进下一施工相位 · 右键取消"
        case .phasedMonumentPhase:
            "点击已放置的大陵冢或地下兵马俑坑推进下一施工相位 · 右键取消"
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
        if let imageID = OriginalInterfaceSpriteCatalog.imageID(
            for: category.originalInterfaceIcon
           ),
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
        if tool == .grandCanalSegment {
            return city.aesthetics.grandCanalProject?.isComplete == false
        }
        if tool == .earthenGreatWallSegment {
            return city.aesthetics.earthenGreatWallProject?.isComplete == false
        }
        if tool == .largePalacePhase {
            return city.aesthetics.largePalaceProject?.isComplete == false
        }
        if tool == .phasedMonumentPhase {
            return city.aesthetics.phasedMonumentProjects.contains { !$0.isComplete }
        }
        if tool == .rally {
            guard city.missionSettings != nil else { return true }
            return !city.military.forts.isEmpty || !city.military.defensiveStructures.isEmpty
        }
        return tool.buildingID.map(city.isBuildingAvailableInCampaign) ?? true
    }
}

extension ConstructionToolCategory {
    var accessibilitySlug: String {
        switch self {
        case .residential: "residential"
        case .agriculture: "agriculture"
        case .industry: "industry"
        case .commerce: "commerce"
        case .safety: "safety"
        case .government: "government"
        case .entertainment: "entertainment"
        case .religious: "religious"
        case .military: "military"
        case .aesthetics: "aesthetics"
        case .monuments: "monuments"
        }
    }

    var advisorTitle: String {
        switch self {
        case .residential: "人口"
        case .agriculture: "农业"
        case .industry: "工业"
        case .commerce: "商业"
        case .safety: "安全"
        case .government: "行政"
        case .entertainment: "娱乐"
        case .religious: "宗教"
        case .military: "军事"
        case .aesthetics: "美化"
        case .monuments: "纪念碑"
        }
    }

    func advisorMetric(in city: DeterministicCityState) -> String {
        if self == .residential { return "\(city.population)" }
        return "\(matchingPlacements(in: city).count)"
    }

    func advisorSummary(in city: DeterministicCityState) -> String {
        let count = matchingPlacements(in: city).count
        return switch self {
        case .agriculture: "全城有 \(count) 座农业与粮食设施"
        case .industry: "全城有 \(count) 座工业生产设施"
        case .commerce: "全城有 \(count) 座仓储、市场或贸易设施"
        case .safety: "全城有 \(count) 座供水、医药或安全设施"
        case .government: "全城有 \(count) 座行政与税务设施"
        case .entertainment: "全城有 \(count) 座娱乐设施"
        case .religious: "全城有 \(count) 座宗教设施"
        case .military: "全城有 \(count) 处城防与军事设施"
        case .aesthetics: "全城有 \(count) 处园林与美化设施"
        case .monuments: "全城有 \(count) 处纪念碑及营造设施"
        case .residential: "当前人口 \(city.population) 人"
        }
    }

    var advisorHint: String {
        switch self {
        case .residential: "住房与移民状况"
        case .agriculture: "农田、渔猎与磨坊维持城市粮食供应"
        case .industry: "原料与工坊共同构成城市生产链"
        case .commerce: "先建市场，再选择食物、麻布、陶器、茶或奢侈品铺并点击市场内部"
        case .safety: "供水、医药与巡防覆盖影响住宅发展"
        case .government: "巡察与税务维持城市行政运转"
        case .entertainment: "音乐、杂技与戏剧满足居民娱乐需求"
        case .religious: "宗教覆盖可满足居民的精神需求"
        case .military: "城墙、哨塔和要塞共同构成城市防务"
        case .aesthetics: "园林与雕塑可改善周边住宅吸引力"
        case .monuments: "大型工程需要劳工营和专业公会支持"
        }
    }

    private func matchingPlacements(in city: DeterministicCityState) -> [PlacedBuilding] {
        city.placedBuildings.filter { placement in
            switch self {
            case .residential:
                false
            case .agriculture:
                [26, 27, 28, 31, 33, 53, 193, 194, 195, 196, 197, 198, 199]
                    .contains(placement.buildingID)
            case .industry:
                (35...48).contains(placement.buildingID)
                    || [237, 238, 239].contains(placement.buildingID)
            case .commerce:
                [.warehouse, .market, .trading].contains(placement.category)
            case .safety:
                [72, 124, 127, 207, 208, 216].contains(placement.buildingID)
            case .government:
                [110, 125, 209, 218].contains(placement.buildingID)
            case .entertainment:
                (211...213).contains(placement.buildingID)
            case .religious:
                (214...219).contains(placement.buildingID)
            case .military:
                placement.category == .military
                    || [126, 129, 130, 131].contains(placement.buildingID)
            case .aesthetics:
                (115...122).contains(placement.buildingID)
                    || (243...252).contains(placement.buildingID)
            case .monuments:
                [52, 76, 77, 78, 79, 80, 81, 82, 84, 92, 93, 233, 235, 236]
                    .contains(placement.buildingID)
            }
        }
    }
}
