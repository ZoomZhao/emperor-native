# Plan 003: 用原版建筑和人物素材替换教程占位图形

> **执行者说明**：先确认计划 001、002 已是 `DONE`。本计划只覆盖夏朝教程第一关可见的
> 建筑和人物，不借机扩成全素材重制。完成后更新 `plans/README.md` 的 003 状态。
>
> **漂移检查（首先运行）**：`shasum -a 256 -c plans/baseline.sha256`。计划 001、002 修改过的
> 文件 mismatch 是预期的；对照其最终 diff。若 `SG3Archive.swift`、`BuildingSpriteCatalog.swift`
> 或 `EmperorInspector/main.swift` 有来源不明的变化，先停止并核对。

## 状态

- **执行状态**：DONE（原版目录/解码/渲染路径与确定性测试通过；真实 UI 胜利截图由 005 门禁统一留证）
- **优先级**：P1
- **投入**：L（多日）
- **风险**：HIGH；SG3 分组映射尚未完全证明，且人物需要方向/帧序列
- **依赖**：`plans/001-continuous-clock-and-migration.md`、`plans/002-xia-tutorial-economy-loop.md`
- **类别**：direction / correctness / UX / tests
- **生成基线**：无 Git；`plans/baseline.sha256`，2026-07-22

## 为什么重要

当前第一关虽然已有部分原版建筑，但未支持的建筑仍画成彩色地砖，所有服务员、运输员和市场
人物仍是带汉字的圆形标记。玩家无法凭画面理解“谁在运肉、谁在卖食物、哪些住宅被服务”，
视觉上也仍像调试器而不是游戏。

完成后，第一关画面中所有常驻建筑和关键人物都应来自用户本机原版资源；规则状态仍由核心模拟
驱动，动画不得反过来推进或修改模拟。

## 当前状态

- `Sources/EmperorNative/CityCanvasView.swift:283-310` 对没有 sprite component 的建筑绘制分类色
  菱形；`651-675` 对行人绘制“税/运”等 marker。
- `CityCanvasView.swift:533` 只绘制 `city.houses.prefix(12)`，人口再多也只显示十二栋住宅。
- `BuildingSpriteCatalog.swift:73-78` 把 33 列为支持建筑，但 `buildingSprite` 的 switch 没有 33、
  124，实际仍落入占位绘制。
- 本地导出的 `China_General.sg3` image 825 已人工确认是猎场；image 1704 是巡查设施候选，必须
  通过分组元数据和相邻帧再次证明后才能写入目录，不能仅凭外观猜测。
- 核心已有第一关人物 ID：运输员 22、市场小贩 23、买手 24、水夫 28、祖先服务 35、巡查员
  39；计划 001 还会加入移民人物。
- 原版人物位图在 `SprMain.sg3` / `SprMain2.sg3`；当前 `SG3Archive.Image.bitmapGroupID` 已解析
  字段，但 inspector 输出曾把多个逻辑组都映射到 `Peddler`，说明名字与分组对应关系仍需核验。

## 所需命令

| 用途 | 命令 | 成功标准 |
|------|------|----------|
| 导出猎场 | `.build/debug/emperor-inspect sprite-png '/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]/Data/China_General.sg3' 825 /tmp/emperor-hunting-camp.png` | PNG 可打开且为猎场 |
| 导出巡查候选 | `.build/debug/emperor-inspect sprite-png '/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]/Data/China_General.sg3' 1704 /tmp/emperor-inspector-tower.png` | PNG 与分组证明同时成立 |
| SG3 定向测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SG3` | 全部通过 |
| 素材目录测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SpriteCatalog` | 全部通过 |
| 全量 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0 |
| 构建 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |

## 范围

**允许修改/创建：**

- `Sources/EmperorCore/SG3Archive.swift`
- `Sources/EmperorCore/BuildingSpriteCatalog.swift`
- `Sources/EmperorCore/FigureSpriteCatalog.swift`（新建）
- `Sources/EmperorInspector/main.swift`
- `Sources/EmperorNative/LibraryModel.swift`
- `Sources/EmperorNative/CityCanvasView.swift`
- `Tests/EmperorCoreTests/SG3FigureSpriteTests.swift`（新建）
- `Tests/EmperorCoreTests/BuildingSpriteCatalogTests.swift`（新建或拆分现有测试）

**不在范围：**第二关以后的专属设施、军事单位、灾害、动物、全部 269 类建筑、重新绘制素材、
修改原版档案、将原版资源复制进仓库或安装包。

## Git 工作流

若已有 Git，使用 `advisor/003-original-visuals-for-tutorial`；不要推送。无 Git 时保留范围内修改，
以素材核验输出、截图和测试结果交接。

## 步骤

### 1. 先证明 SG3 人物分组与位图名称映射

扩展 `emperor-inspect`，让一个命令同时打印 image ID、logical group/index、bitmap group/name、
方向、帧序号、尺寸、偏移和 sprite count。对 `SprMain.sg3`、`SprMain2.sg3` 打印全部第一关人物
候选，并与档案内 bitmap 名称表和相邻序列交叉核对。

若 `bitmapGroupID` 的偏移或哨兵处理错误，在 `SG3Archive` 修正，并用原版档案 fixture 测试固定
至少三个不同名称的组，避免“所有人物都是 Peddler”的假阳性。测试找不到本机原版资源时
`XCTSkip`，纯二进制解析 fixture 仍必须运行。

**验证**：同一人物的八方向/多帧形成连续且尺寸合理的序列；Peddler、Immigrant、Inspector、
WaterBearer 至少四组名字互不混淆。

### 2. 补齐第一关全部建筑 sprite

把已确认的猎场 image 825 加入 `OriginalBuildingSpriteCatalog`。对巡查塔先以 inspector 输出证明
building 124 对应的逻辑组、第一帧、朝向和 footprint；只有证据一致时才加入 image 1704 或核验
得到的替代 ID。

为第一关允许集合建立测试：住宅、猎场 33、磨坊 53、普通市场 59、井 72、巡查塔 124、祖庙
214 都必须返回非空 component，且对应图片能由原版 SG3 解码。删除 `prefix(12)`，按视口裁剪绘制
全部住宅。

**验证**：第一关每种已建建筑 `hasRenderableComponents` 都为 true；正常运行不出现分类色菱形。

### 3. 建立只覆盖第一关的原版人物目录

新建 `OriginalFigureSpriteCatalog`，键至少包含计划 002 实际会生成的人物：移民、运输员 22、
小贩 23、买手 24、水夫 28、祖先服务 35、巡查员 39。目录保存 archive base name、八方向序列、
每方向帧数和 anchor；不要把 SwiftUI `Image` 或 `CGImage` 放进可存档核心状态。

`LibraryModel` 异步加载这些 image ID，缓存策略与建筑 sprite 共用或抽成统一 loader。资源只从用户
的 `GameDataSource` 读取；缺失档案时显示明确错误，不静默用圆形 marker 当正式表现。

**验证**：目录测试断言所有所需人物都有八方向、每方向至少一帧、所有 image ID 可解码且非空。

### 4. 让模拟 tick 驱动方向和动画帧

在 `CityCanvasView` 为 walker、delivery、buyer、peddler、migration 建立统一 render item。方向来自
上一个与当前道路点之差；帧号来自计划 001 的确定性 tick sequence，例如
`(tickSequence + stableFigureID) % frameCount`。暂停时帧号不得继续变化。

人物的规则位置只在核心 tick 改变；SwiftUI 可在两 tick 之间做纯视觉插值，但不得修改路线索引、
库存或服务覆盖。没有移动方向时沿用最后方向，避免朝向闪烁。

**验证**：给定相同存档和 tick sequence，人物的 image ID、位置、方向完全一致；暂停后连续重绘
截图哈希不因动画计时器变化。

### 5. 与建筑一起做等距深度排序

把建筑 component 与人物 render item 放入同一 depth key 体系，至少按地图 `x + y`、地图层级、
稳定 ID 排序。人物走到建筑后方时被遮挡，走到前方时可见；anchor 使用 SG3 偏移而不是统一
圆心。视口外人物不解码/绘制。

保留占位 marker 仅限 `#if DEBUG` 的显式诊断开关。Release 中缺素材时使用一个固定的“素材缺失”
图标并记录具体 archive/image ID；第一关验收不允许触发该路径。

**验证**：固定小地图场景生成前/后遮挡快照；手工以 1x、2x、3x 和暂停观察动画与方向。

## 测试计划

- SG3：位图名称映射、逻辑组、图像解码、偏移和外部图像标记。
- 建筑目录：第一关允许建筑全覆盖，footprint 与核心目录一致。
- 人物目录：七类第一关人物的八方向、帧数、archive 和 image 可解码。
- 确定性：相同 tick/state 得到相同渲染引用；暂停不变。
- 视觉：全部住宅、建筑深度、人物前后遮挡、缺素材诊断。
- 手工截图：迁入、运肉、市场买货、小贩送货、三种服务巡逻各一张。

## 完成标准

- [ ] 第一关所有常驻建筑使用原版 sprite，不再出现彩色地砖占位。
- [ ] 第一关所有关键人物使用原版八方向动画，不再出现汉字圆点。
- [ ] 所有住宅都可见，不再限制为十二栋。
- [ ] 动画仅由确定性 tick/state 派生，暂停后静止。
- [ ] 人物与建筑共享正确的等距深度排序。
- [ ] Release 第一关不触发素材缺失 fallback。
- [ ] 素材目录测试、全量 `swift test` 和 `swift build` 全部 exit 0。
- [ ] 003 状态更新为 `DONE`，交接中附五类场景截图。

## 停止条件

- 无法用 SG3 元数据证明 image 1704 或替代图确属 building 124。
- `bitmapGroupID` 与位图名称的映射无法通过至少三组独立人物验证。
- 第一关人物帧不在 `SprMain` / `SprMain2`，且需要猜测其他档案。
- 需要把原版资源复制进仓库或发行包才能工作。
- 计划 001 未提供稳定 tick sequence 或人物稳定 ID。

## 维护说明

此计划的目录只承诺夏朝第一关覆盖。后续扩展应按“某个可玩任务所需集合”逐批加入并复用相同
验证工具，不能用连续 image ID 猜测所有人物。视觉插值是展示层能力，任何物资、服务或迁入判定
仍以核心 tick 的离散位置为准。
