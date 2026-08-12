# Construction panel — native inferred mapping

Most associations below are `inferred`; the four commerce rows retained for
traceability are explicitly `unknown` after the runtime contradiction. Sheet
family geometry remains `confirmed` only in `construction-bbutton-families.*`.
Nothing here closes the original exe writer.

Generated: `2026-08-11T03:33:47.582593+00:00`

## Inference rules

- buildingId→imageId from OriginalConstructionButtonSpriteCatalog only (inferredFromSheet)
- category from NativeConstructionTool.category (native taxonomy, not exe enum)
- slot = index in ClassicControlPanel filter order: enum CaseIterable order, excluding utility/agriculturalProducer/alias tools; agriculture prefixes cropOrder; NOT mission available-first sort
- buildingName from NativeConstructionTool.title (Chinese)
- frame=0 means normal state; hover/selected are imageId+1/+2 for buildings, +0..+3 for category rail
- screenRect absolute coords assume unscrolled catalog under 1024×768 classic shell (HUD 40 + advisor 281 → catalog top y=321); scrolling invalidates Y
- sharedFamily groups multiple buildingIds on one baseImageId; do not invent duplicate sprites
- Live UI reorders available tools first — that ordering is mission-dependent and is a known contradiction vs stableSlot

## Shared sprite families

| sharedFamily | baseImageId | buildingIds | states |
| --- | --- | --- | --- |
| `furnace_smelter` | 1524 | [39, 40] | [1524, 1525, 1526] |
| `market_pavilion` | 1546 | [59, 60] | [1546, 1547, 1548] |
| `daoist_shrine_temple` | 1599 | [215, 216] | [1599, 1600, 1601] |
| `guild_camp` | 1650 | [52, 235, 236] | [1650, 1651, 1652] |


## Critical contradiction: catalog base vs INDEX family start

Several `OriginalConstructionButtonSpriteCatalog` bases (especially commerce) are **not** the start of a confirmed 54×53 INDEX triple. Example: lumber family packs as `#1527–#1529` in sheet order, while the catalog also uses `#1528` as warehouse normal — these cannot both be independent three-state families under consecutive packing.

Affected buildingIds (confidence forced **low**):

- buildingId **54** catalogBase `1528` containingFamily `{'familyStart': 1527, 'states': [1527, 1528, 1529], 'offsetInFamily': 1}`
- buildingId **66** catalogBase `1531` containingFamily `{'familyStart': 1530, 'states': [1530, 1531, 1532], 'offsetInFamily': 1}`
- buildingId **59** catalogBase `1546` containingFamily `{'familyStart': 1545, 'states': [1545, 1546, 1547], 'offsetInFamily': 1}`
- buildingId **60** catalogBase `1546` containingFamily `{'familyStart': 1545, 'states': [1545, 1546, 1547], 'offsetInFamily': 1}`
- buildingId **212** catalogBase `1587` containingFamily `None`
- buildingId **213** catalogBase `1590` containingFamily `None`
- buildingId **225** catalogBase `1617` containingFamily `None`
- buildingId **223** catalogBase `1620` containingFamily `None`
- buildingId **120** catalogBase `1632` containingFamily `None`
- buildingId **121** catalogBase `1635` containingFamily `None`
- buildingId **233** catalogBase `1647` containingFamily `None`
- buildingId **52** catalogBase `1650` containingFamily `None`
- buildingId **235** catalogBase `1650` containingFamily `None`
- buildingId **236** catalogBase `1650` containingFamily `None`

- sheet_size_break: `#1535` size `(54, 52)` (not 54×53)

## Layout (inferred, 1024×768)

```json
{
  "canvas": {
    "w": 1024,
    "h": 768
  },
  "hudHeight": 40,
  "panel": {
    "x": 800,
    "y": 40,
    "w": 224,
    "h": 728
  },
  "categoryRail": {
    "x": 800,
    "y": 40,
    "w": 54
  },
  "categoryButtonFrame": {
    "w": 48,
    "h": 37,
    "padX": 3,
    "offsetY": -2,
    "spacing": 1
  },
  "advisorHeight": 280,
  "catalogTopY_canvas": 321,
  "catalogContentX": 858,
  "cell": {
    "w": 54,
    "h": 53
  },
  "columns": 3,
  "utilityStripHeight": 36,
  "minimapBlockHeight": 154,
  "navHeight": 40,
  "source": "EmperorTheme.swift + ContentView ClassicControlPanel (inferred native layout, not exe-measured)"
}
```

## Building button rows (53 catalog associations)

| category | slot | buildingId | buildingName | imageId | sharedFamily | confidence |
| --- | --- | --- | --- | --- | --- | --- |
| 住宅 | 0 | 2 | 住宅 | 1491 |  | medium |
| 住宅 | 1 | 11 | 贵族住宅 | 1494 |  | medium |
| 农业 | 12 | 31 | 捕鱼码头 | 1512 |  | medium |
| 农业 | 13 | 33 | 猎场 | 1506 |  | medium |
| 工业 | 0 | 35 | 粘土坑 | 1515 |  | medium |
| 工业 | 3 | 36 | 石料场 | 1518 |  | medium |
| 工业 | 1 | 43 | 窑炉 | 1521 |  | medium |
| 工业 | 5 | 39 | 青铜熔炉 | 1524 | furnace_smelter | medium |
| 工业 | 4 | 40 | 炼铁炉 | 1524 | furnace_smelter | medium |
| 工业 | 2 | 38 | 伐木棚 | 1527 |  | medium |
| 商业 | 0 | 54 | 仓库 | 1528 |  | medium |
| 商业 | 3 | 66 | 食物铺 | 1531 |  | medium |
| 商业 | 1 | 59 | 市场 | 1546 | market_pavilion | medium |
| 商业 | 2 | 60 | 大市场 | 1546 | market_pavilion | medium |
| 安全 | 0 | 72 | 水井 | 1551 |  | medium |
| 安全 | 1 | 207 | 药草铺 | 1554 |  | medium |
| 安全 | 2 | 208 | 针灸所 | 1557 |  | medium |
| None | None | 124 | inspector tower | 1560 |  | low |
| 安全 | 4 | 127 | 瞭望塔 | 1563 |  | medium |
| 行政 | 2 | 209 | 行政城 | 1566 |  | medium |
| 行政 | 3 | 110 | 宫殿 | 1569 |  | medium |
| 行政 | 1 | 125 | 税务所 | 1572 |  | medium |
| 农业 | 10 | 203 | 灌溉水车 | 1575 |  | medium |
| 娱乐 | 0 | 211 | 音乐学校 | 1584 |  | medium |
| 娱乐 | 1 | 212 | 杂技学校 | 1587 |  | medium |
| 娱乐 | 2 | 213 | 戏剧学校 | 1590 |  | medium |
| 宗教 | 0 | 214 | 祖先祠堂 | 1596 |  | medium |
| 宗教 | 2 | 215 | 道观 | 1599 | daoist_shrine_temple | medium |
| 宗教 | 3 | 216 | 道教大庙 | 1599 | daoist_shrine_temple | medium |
| 宗教 | 4 | 218 | 佛塔 | 1602 |  | medium |
| 宗教 | 1 | 219 | 儒家书院 | 1605 |  | medium |
| 军事 | 5 | 220 | 弩兵堡 | 1608 |  | medium |
| 军事 | 1 | 221 | 步兵堡 | 1611 |  | medium |
| 军事 | 7 | 224 | 骑兵堡 | 1614 |  | medium |
| 军事 | 8 | 225 | 战车堡 | 1617 |  | medium |
| 军事 | 6 | 223 | 投石车堡 | 1620 |  | medium |
| 美化 | 1 | 116 | 装饰雕塑 | 1623 |  | medium |
| 美化 | 0 | 115 | 花园 | 1626 |  | medium |
| 美化 | 2 | 117 | 华丽雕塑 | 1629 |  | medium |
| 美化 | 5 | 120 | 池塘 | 1632 |  | medium |
| 美化 | 6 | 121 | 太极园 | 1635 |  | medium |
| 美化 | 4 | 119 | 路亭 | 1638 |  | medium |
| 美化 | 3 | 118 | 花树 | 1641 |  | medium |
| 美化 | 7 | 122 | 私家园林 | 1644 |  | medium |
| 纪念 | 5 | 233 | 劳工营 | 1647 |  | medium |
| 纪念 | 6 | 52 | 木匠行会 | 1650 | guild_camp | medium |
| 纪念 | 7 | 235 | 石匠行会 | 1650 | guild_camp | medium |
| 纪念 | 8 | 236 | 陶工行会 | 1650 | guild_camp | medium |
| 纪念 | 14 | 93 | 大佛塔 | 1653 |  | medium |

## Agriculture crop buttons (inferred)

| slot | crop | imageId | sharedFamily |
| --- | --- | --- | --- |
| 0 | 小麦农场 | 1497 | crop_field |
| 1 | 大豆农场 | 1497 | crop_field |
| 2 | 稻米农场 | 1500 | crop_rice |
| 3 | 小米农场 | 1497 | crop_field |
| 4 | 卷心菜农场 | 1497 | crop_field |
| 5 | 麻农场 | 1497 | crop_field |
| 6 | 茶农场 | 1509 | crop_orchard |
| 7 | 桑树农场 | 1509 | crop_orchard |
| 8 | 漆树农场 | 1509 | crop_orchard |

## Category rail (inferred)

| slot | category | imageId (4-state base) | screenRect |
| --- | --- | --- | --- |
| 0 | 住宅 | 1323 | `{"x": 803, "y": 38, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 0}` |
| 1 | 农业 | 1327 | `{"x": 803, "y": 76, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 1}` |
| 2 | 工业 | 1331 | `{"x": 803, "y": 114, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 2}` |
| 3 | 商业 | 1335 | `{"x": 803, "y": 152, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 3}` |
| 4 | 安全 | 1339 | `{"x": 803, "y": 190, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 4}` |
| 5 | 行政 | 1343 | `{"x": 803, "y": 228, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 5}` |
| 6 | 娱乐 | 1347 | `{"x": 803, "y": 266, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 6}` |
| 7 | 宗教 | 1351 | `{"x": 803, "y": 304, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 7}` |
| 8 | 军事 | 1355 | `{"x": 803, "y": 342, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 8}` |
| 9 | 美化 | 1359 | `{"x": 803, "y": 380, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 9}` |
| 10 | 纪念 | 1319 | `{"x": 803, "y": 418, "w": 48, "h": 37, "coordSpace": "classicCanvas_1024x768", "railIndex": 10}` |

## Classic-grid tools without Bbutton catalog row (`unknown` image)

Count: **23**

| category | slot | buildingId | buildingName | nativeTool |
| --- | --- | --- | --- | --- |
| 农业 | 11 | 193 | 农田 | farmland |
| 工业 | 6 | 44 | 漆器作坊 | lacquerwareWorkshop |
| 工业 | 7 | 46 | 玉雕坊 | jadeWorkshop |
| 商业 | 6 | 70 | 茶铺 | teaShop |
| 商业 | 7 | 69 | 丝绸铺 | silkShop |
| 商业 | 8 | 68 | 漆器铺 | lacquerwareShop |
| 商业 | 9 | 64 | 青铜器铺 | bronzewareShop |
| 安全 | 3 | 126 | 路障 | roadblock |
| 行政 | 0 | None | 巡察塔 | inspectorTower |
| 军事 | 0 | None | 部队集结 | rally |
| 军事 | 2 | 129 | 城墙 | cityWall |
| 军事 | 3 | 130 | 城门 | gatehouse |
| 军事 | 4 | 131 | 城防塔 | tower |
| 纪念 | 0 | None | 郑国渠分段 | grandCanalSegment |
| 纪念 | 1 | None | 土长城分段 | earthenGreatWallSegment |
| 纪念 | 2 | 82 | 大宫殿 | largePalace |
| 纪念 | 3 | None | 大宫殿施工 | largePalacePhase |
| 纪念 | 4 | None | 陵墓分段施工 | phasedMonumentPhase |
| 纪念 | 9 | 76 | 陵冢 | tumulus |
| 纪念 | 10 | 77 | 大陵冢 | grandTumulus |
| 纪念 | 11 | 84 | 地下兵马俑坑 | undergroundVault |
| 纪念 | 12 | 78 | 大庙 | greatTemple |
| 纪念 | 13 | 79 | 宏伟庙宇 | splendidTemple |

## Sheet families without any catalog buildingId

`[1503, 1530, 1536, 1539, 1542, 1545, 1548, 1578, 1581]`

These bases exist as confirmed 54×53 families in `construction-bbutton-families.csv` but have no row in `OriginalConstructionButtonSpriteCatalog` / crop helpers.


## Contradictions

- **alias_excluded_from_classic_grid**: `{"type": "alias_excluded_from_classic_grid", "buildingId": 54, "tool": "granary", "detail": "granary aliases warehouse and is excluded from ClassicControlPanel catalog"}`
- **catalog_building_not_in_classic_grid_filter**: `{"type": "catalog_building_not_in_classic_grid_filter", "buildingId": 124, "tool": null, "detail": "Mapped in sprite catalog but excluded from classic grid filters or missing tool"}`
- **tool_title_vs_model_semantics**: `{"type": "tool_title_vs_model_semantics", "buildingId": 216, "tool": "bathhouse", "title": "道教大庙", "detail": "Swift case is bathhouse but title is 道教大庙; shares Daoist button family with shrine 215"}`
- **tool_title_vs_model_semantics**: `{"type": "tool_title_vs_model_semantics", "buildingId": 218, "tool": "magistrate", "title": "佛塔", "detail": "Swift case is magistrate but title is 佛塔"}`

## Exe / runtime gaps

- No exe-confirmed buildingId→Bbutton writer (see construction-bbuttons.md)
- screenRect not measured from original pixels — derived from native SwiftUI theme
- Category/slot order is native reproduction, may diverge from original mission filters
- `BV1W4411971F_p2.mp4` labels a visible page 商业 while showing the
  `#1533–#1544` mill/weaver/ceramics/hemp families. This conflicts with the
  current Native taxonomy (磨坊=农业, 织布坊=工业), so video slot order must
  not rewrite category ownership without recovering the original category
  filter.
- Original Chinese runtime capture is now active under Rosetta/Wine. The
  tutorial's 商业 rail directly shows the `#1533–#1535`, `#1536–#1538`, and
  `#1539–#1541` families (a fourth `#1542–#1544` family is visible in the
  reference video), but no tooltip or writer record has identified the
  building IDs. The former 53/47/65/67 sheet-order rows were therefore
  removed from the native catalog rather than promoted to semantic mappings.

## Runtime-unknown commerce families

| observed family | runtime page | candidate IDs | status |
| --- | --- | --- | --- |
| 1533–1535 | 商业 | unknown | directly observed; no semantic closure |
| 1536–1538 | 商业 | unknown | directly observed; do not map to 47/weaver |
| 1539–1541 | 商业 | unknown | directly observed; do not map to 65/ceramics |
| 1542–1544 | 商业 (reference video) | unknown | video-only until captured in the tutorial |

## Related files

- Asset confirmed: `construction-bbutton-families.csv`
- This inferred layer: `construction-panel-inferred-mapping.csv` / `.json`
- Index: `construction-panel-mapping.md` / `README.md`
