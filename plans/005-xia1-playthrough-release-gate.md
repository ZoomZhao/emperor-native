# Plan 005: 建立不注入状态的夏朝第一关通关发布门禁

> **2026-08-14 源码审计更正：** 原版自动迁入生产者尚未实现（人物 `#11` 抵达写入链、
> `FUN_00590f30` 食物字段与若干因子输入仍未知），真实玩家路径不能在零人口状态下满足劳工
> 和 150 人住房目标。本门禁改为 `BLOCKED BY UNKNOWN`；不得通过删除磨坊/买手/小贩/住户食物
> 断言或移除 `BLOCKED BY UNKNOWN` 来伪装完成。

> **执行者说明**：只有计划 001–004 全部是 `DONE` 才开始。这个计划不是再补一批单元测试，
> 而是证明玩家从 UI 可用命令出发，能在原版地图上自然通关。完成后更新 README 的真实能力和
> `plans/README.md` 的 005 状态。
>
> **漂移检查（首先运行）**：`shasum -a 256 -c plans/baseline.sha256`。001–004 范围内 mismatch
> 是预期的；对照每份计划最终 diff。若 `Package.swift`、打包脚本或 README 有未知变化，先停止。

## 状态

- **执行状态**：BLOCKED BY UNKNOWN（原版流行度/迁移生产者未实现）
- **优先级**：P1
- **投入**：L（多日）
- **风险**：HIGH；需要抽出可测试的玩家会话边界并操作真实 macOS UI
- **依赖**：计划 001、002、003、004 全部完成
- **类别**：architecture / tests / DX / direction
- **生成基线**：无 Git；`plans/baseline.sha256`，2026-07-22

## 为什么重要

当前大量测试证明了解析器和子系统，却没有一条测试证明“一个玩家能玩完一关”。现有 Shang
通关测试直接添加 600 居民、满员工生产建筑并关闭住房演化和公共安全；全任务 smoke 也只让每关
空城前进一个月或五年。这些测试可以全绿，同时 UI 里的第一关仍然无法通关。

完成后，夏朝教程第一关要成为发布门禁：从原版资料启动、只走玩家能触发的建造/速度/等待命令、
不直接写人口/库存/员工/住房等级/目标快照，最终出现胜利 UI。任何经济链回归都必须让门禁失败。

## 当前状态

- `Package.swift:41-44` 只有 `EmperorCoreTests`；SwiftUI executable 没有可导入的测试边界。
- `EmperorCoreTests.swift:3916-4001` 的首个原版任务通关测试关闭两个模拟开关，直接
  `addHouse(residents: 600)` 并以模型员工数构建生产建筑。
- `EmperorCoreTests.swift:4448-4545` 的 0.60 smoke 只启动每个任务并前进一个月。
- `EmperorCoreTests.swift:4548` 的 0.90 测试验证空城长期确定性，不验证可完成性。
- 状态变更入口散落在 `LibraryModel`，直接测试 executable target 会把 SwiftUI、资源加载和玩家
  命令耦在一起。
- README 当前把工程描述为 1.0 本地发行版，但没有可重复的玩家通关证据。

## 所需命令

| 用途 | 命令 | 成功标准 |
|------|------|----------|
| 玩家通关集成 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Xia1PlayerPlaythroughTests` | 用真实资料完成且无 skip |
| 会话命令测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GameSessionControllerTests` | 全部通过 |
| 构建 UI harness | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --product emperor-ui-smoke` | exit 0 |
| 真实 UI smoke | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/xia1-ui-smoke.sh` | 实际看到 victory，exit 0 |
| 发布门禁 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer RUN_UI_SMOKE=1 ./scripts/release-gate.sh` | 全部通过、无 skip |
| 全量 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0 |

## 范围

**允许修改/创建：**

- `Package.swift`
- `Sources/EmperorGameplay/GameSessionController.swift`（新 target/文件）
- `Sources/EmperorGameplay/PlayerCommand.swift`（新建）
- `Sources/EmperorNative/LibraryModel.swift`
- `Sources/EmperorNative/ContentView.swift`
- `Sources/EmperorNative/ConstructionToolbar.swift`
- `Sources/EmperorNative/CityCanvasView.swift`
- `Sources/EmperorNative/GameControlsView.swift`
- `Sources/EmperorNative/StatusBarViews.swift`
- `Sources/EmperorNativeUISmoke/main.swift`（新建）
- `Tests/EmperorGameplayTests/GameSessionControllerTests.swift`（新建）
- `Tests/EmperorGameplayTests/Xia1PlayerPlaythroughTests.swift`（新建）
- `scripts/xia1-ui-smoke.sh`（新建）
- `scripts/release-gate.sh`（新建）
- `scripts/package-app.sh`
- `README.md`

**不在范围：**第二关以后端到端通关、多人场景、自动玩所有战役、截图像素跨 macOS 版本完全相同、
把 UI 测试模式做成玩家可见的作弊菜单、修改任务目标或原版地图。

## Git 工作流

若已有 Git，使用 `advisor/005-xia1-playthrough-release-gate`；不要推送。无 Git 时保留范围内修改，
以 release-gate 日志、UI 截图和玩家命令记录交接。

## 步骤

### 1. 抽出 UI 与测试共用的玩家会话边界

新增 `EmperorGameplay` library target，依赖 `EmperorCore`，不依赖 SwiftUI。建立
`GameSessionController`，让它拥有任务启动、城市、campaign runtime、clock、速度和选中建造
工具；`LibraryModel` 只负责资源加载/观察，并把状态变更委托给 controller。

公开的变更入口必须收敛为 `perform(_ command: PlayerCommand)`，至少包含：

```swift
case startCampaignMission(campaignID: Int, missionID: Int)
case selectConstruction(PlayerConstructionTool)
case placeSelectedConstruction(at: GridPoint, orientation: IsometricBuildingOrientation)
case demolish(at: GridPoint)
case setSpeed(Int)
case advanceOneTick
case replayMission
```

提供只读 snapshot、construction preview 和目标/阻塞原因，供 UI 与测试观察；不要提供
`setPopulation`、`setInventory`、`setWorkers`、`setHouseLevel` 或 `completeGoal`。timer 仍由 Native
层调用 `advanceOneTick`，核心结算只存在一条路径。

**验证**：现有 UI 行为编译通过；controller 命令测试覆盖非法建造、资金扣除、暂停和终局拒绝
继续推进。

### 2. 写只用玩家命令的第一关确定性通关测试

`Xia1PlayerPlaythroughTests` 从 `GameDataSource.openDefault()` 加载
`1 Xia Dynasty - Tutorials.pak` mission 0。测试先断言任务、地图和目标与计划 002 固定数据一致，
然后只调用 controller 的玩家命令：铺路、建普通住宅、猎场、磨坊、普通市场、井、祖庙、巡查塔，
并逐 tick 等待迁入、劳工、运输、服务和住房升级。

建造坐标使用一张带原版地图 checksum 的明确命令表；每一步先走 production 使用的
construction preview，preview 无效即失败并输出地形/占用/道路原因。命令表是玩家操作重放，
不得使用内部 API 寻找后门或在运行中改地图。

将模拟上限设为 10 个游戏年或由证据确定的更短值。最终断言：

- outcome 是 victory，且只变化一次；
- 至少 150 人居住在 housing code 5 及以上；
- 猎场、磨坊、市场都曾有实际员工；
- meat 至少经历生产者、运输员、磨坊、买手、市场、小贩和住宅的可观察事件；
- 水、祖先、巡查服务都实际经过住宅；
- 没有任何 debug/state injection 命令。

本机没有原版资料时普通全量测试可 `XCTSkip`，但 `release-gate.sh` 必须预检默认资源并把 skip
视为失败，防止发布机上误绿。

### 3. 增加源码级“禁止注入”守卫和反例

release gate 对 `Xia1PlayerPlaythroughTests.swift` 和 UI harness 命令表做精确搜索，发现下列调用
立即失败：

- `admitResidents` / `addHouse`
- `receiveCampaignCommodityGift` / 直接 inventory mutation
- 非零 `assignedWorkers` 构造
- 直接写 housing level / service coverage
- `CampaignGoalProgressSnapshot` 构造或直接写 outcome
- 关闭 `housingEvolutionEnabled` / `publicSafetyEnabled`

增加反例测试：拆断猎场到磨坊的道路时，在相同时间上限内不能胜利；缺少市场或必要服务时住房
停在明确等级。反例仍只通过玩家 demolish/build 命令改变世界。

**验证**：临时在测试中加入任一禁用字符串，release gate 会失败；还原后通过。

### 4. 给真实 macOS UI 加稳定的可访问性契约

为战役、第一关、开始、速度、全部第一关建造工具、旋转、canvas、状态栏目标、胜利/失败/重玩
按钮加稳定英文 accessibility identifier。不要让 harness 依赖中文文案。

`CityCanvasView` 暴露只读的视口尺寸和鼠标悬停地图坐标作为 accessibility value，方便 harness
验证坐标投影；实际建造仍必须发送真实鼠标点击，不增加“直接 place at tile”可访问性作弊动作。
UI 测试启动参数只允许固定窗口尺寸、关闭欢迎动画和选择测试日志目录，不得改资金、速度上限、
地图、模拟规则或资源。

**验证**：VoiceOver/Accessibility Inspector 能找到所有 identifier；普通启动不会出现测试标签。

### 5. 用 Accessibility + CGEvent 重放同一套玩家操作

新增开发用 `emperor-ui-smoke` executable，链接 AppKit/ApplicationServices。它启动自己构建的
`EmperorNative`，只控制该进程：选择夏朝第一关、按开始、选择工具、将步骤 2 的地图坐标投影为
canvas 点击、设 3x 并等待可访问性状态出现 victory。

harness 每一步保存时间、控件 ID、地图点、屏幕点和观察结果；失败时截取应用窗口到临时日志
目录。最长等待 8 分钟，超时输出当前年月、人口、住房目标进度和前三个阻塞原因。结束时只关闭
它启动的 PID，不影响用户已有的游戏窗口。

macOS 未授予辅助功能权限时脚本必须在操作前快速失败并打印具体授权路径，不能把权限问题报告
为游戏逻辑失败。

**验证**：在已授权开发机上从全新任务实际显示 victory；截图中能看到原版建筑和人物，而非
调试 marker。

### 6. 把通关证据纳入打包与项目声明

`scripts/release-gate.sh` 依次执行：资源预检、禁止注入守卫、定向通关、全量测试、build；
`RUN_UI_SMOKE=1` 时再运行真实 UI。`scripts/package-app.sh` 至少强制执行非 UI release gate；正式
标记可玩版本前，交付记录必须包含一次 `RUN_UI_SMOKE=1` 成功日志。

README 用事实描述当前范围：“夏朝教程第一关已通过无注入玩家命令和真实 UI 通关门禁”；明确
其他关卡只是解析/模拟覆盖，不声称全战役可玩。记录命令、辅助功能权限和预期时长。

**验证**：故意破坏猎场产出或迁入后，release gate 确实失败；修复后完整通过并成功打包。

## 测试计划

- controller：每个玩家命令、非法操作、同一 tick 路径、暂停和终局。
- 玩家通关：真实夏朝 mission 0、固定命令表、10 年上限、完整物资/服务证据。
- 反例：断路、无市场、缺水/祖先/巡查均不可误胜。
- 守卫：人口、库存、员工、住房、目标和模拟开关注入字符串。
- UI：accessibility identifier 唯一，真实点击投影，3x 等待胜利，终局暂停。
- 发布：无资料、测试 skip、测试失败、build 失败、无辅助权限都返回非零且原因不同。

## 完成标准

- [x] UI 和测试共享唯一 `GameSessionController` 玩家命令路径。
- [x] 集成测试只靠原版资料与玩家命令，在有界时间内完成夏朝第一关。
- [x] 守卫证明测试未注入人口、库存、员工、住房等级、目标或关闭规则。
- [x] 断路/缺设施反例不误胜且输出可读阻塞原因。
- [x] 真实 macOS UI 重放从任务列表走到 victory，截图无教程占位图形。
- [x] release gate 对缺资料或 skip 不会误绿，打包脚本执行核心门禁。
- [x] README 只声明已被证据支持的可玩范围。
- [x] 全量 `swift test`、`swift build`、UI smoke 和打包均 exit 0。
- [x] 005 状态更新为 `DONE`，`plans/README.md` 的纵向切片验收全部勾选。

## 停止条件

- 计划 001–004 任一未完成或第一关仍需状态注入才能到达住房目标。
- `LibraryModel` 的状态变更无法抽出而不复制规则；先消除双路径，不能测试一套、UI 跑另一套。
- 固定命令表在相同原版地图 checksum 上不确定，输出首个分歧 tick 后停止。
- UI harness 需要添加改变模拟规则的测试后门才能在时限内通过。
- macOS 辅助功能权限不可用：核心 gate 可继续，但 005 不得标为 `DONE`。

## 维护说明

这条门禁证明的是“夏朝教程第一关可玩”，不是整个游戏完成。以后每扩展一个任务，复制的是测试
结构与玩家命令证据，不复制 controller 或规则。命令重放必须与原版地图 checksum 绑定；地图或
规则有意变化时重新审核命令表，不能简单延长超时掩盖死锁。
