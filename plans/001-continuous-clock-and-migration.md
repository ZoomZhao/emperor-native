# Plan 001: 让城市按连续 tick 运行并自然迁入人口

> **2026-08-14 源码审计更正：** 连续 tick、月末边界与行人步进已完成；本计划第 4 节的
> “每日最多 5 人、150 人后按国库/失业阻断”没有原版来源，已从生产代码移除。自动迁入当前为
> `BLOCKED BY UNKNOWN`：`FUN_004ADE10` 只生成人物 `#11` 状态 6，抵达后的 `house+0x20`
> 写入链、`FUN_00590f30` 食物字段、`FUN_0055AE30` 纪念碑匹配、`DAT_01312564` Native
> 映射与 `DAT_01311FD0` writer 仍未知。生产 tick 只观测临路空置容量，不改变居民；
> 已确认的压力带/请求上限只记录在研究文档中，生产代码与测试不复述为可调用实现。下文保留为历史实施计划，不再是有效迁入合同。

> **执行者说明**：逐步执行本计划；每一步都运行验证命令。发生“停止条件”时停止并报告，
> 不要自行扩大范围。完成后把 `plans/README.md` 中 001 的状态改为 `DONE`。
>
> **漂移检查（首先运行）**：
> `shasum -a 256 -c plans/baseline.sha256`
> 本计划是第一项，所有现有文件都应显示 `OK`。任何不一致都表示计划生成后代码已变化；
> 对照下列摘录，若相关符号不再匹配则停止。

## 状态

- **优先级**：P1
- **投入**：L（多日）
- **风险**：HIGH；会改变所有月度系统的调用时序和存档状态
- **依赖**：无
- **类别**：direction / tech-debt / correctness
- **生成基线**：无 Git 仓库；`plans/baseline.sha256`，2026-07-22

## 为什么重要

当前 1x/2x/3x 速度只是每隔 2/1/0.5 秒直接结算整月，人口也只能由调试按钮直接写入。
玩家看不到居民、服务人员和货运在时间中活动，城市无法形成可理解的因果链。本计划建立唯一的
可保存确定性时钟，让行人逐步移动、月度规则只在月末发生，并让空置住宅自然吸引移民。

原版手册 `tmp/pdfs/manual/manual.txt:1292-1311` 说明迁入人数不能超过空置容量；
`manual.txt:1336-1340` 说明空地会吸引移民形成住所；`manual.txt:1582-1609` 说明新城会吸引
移民且建筑从现有人口自动取得劳工。这些是本垂直切片的行为基准。

## 当前状态

- `Sources/EmperorCore/CitySimulation.swift:3-19` 的 `SimulationCalendar` 只有年、月和
  `advanceMonth()`。
- `Sources/EmperorCore/CitySimulation.swift:2365` 的 `advanceMonth(rules:)` 同时处理税收、
  完整巡逻、生产、物流、市场、住宅演化、灾害和军事，然后一次跳到下月。
- `Sources/EmperorCore/WalkerSimulation.swift:234-284` 的
  `advanceOnePatrolPerWalker` 在一次月结中走完整条最大巡逻路线。
- `Sources/EmperorNative/LibraryModel.swift:565-586` 的速度计时器直接调用
  `advanceCityMonth()`。
- `Sources/EmperorNative/GameControlsView.swift:75-117` 暴露“迁入 10 人”“前进 8 格”
  和“建立下一贸易伙伴”等状态捷径；住宅快捷按钮还在 12 栋时禁用。
- `Sources/EmperorCore/CitySimulation.swift:1051-1060` 的 `admitResidents` 是唯一增加人口的
  生产路径；保留它作为内部/测试原语，但生产 UI 不得直接调用。
- 代码约定：核心状态是 `Sendable + Codable + Hashable/Equatable` 的值类型；旧存档字段通过
  optional backing 保持 format-v1 可解码。新增状态必须遵循 `CitySimulation.swift:221-249` 的
  optional 存储模式。

## 所需命令

| 用途 | 命令 | 成功标准 |
|------|------|----------|
| 核心定向测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SimulationClockTests` | exit 0，全部通过 |
| 迁入定向测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MigrationSimulationTests` | exit 0，全部通过 |
| 全量测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0，原有测试无回归 |
| 构建 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |

## 范围

**仅允许修改/创建：**

- `Sources/EmperorCore/SimulationClock.swift`（新建）
- `Sources/EmperorCore/MigrationSimulation.swift`（新建）
- `Sources/EmperorCore/CitySimulation.swift`
- `Sources/EmperorCore/WalkerSimulation.swift`
- `Sources/EmperorCore/LogisticsSimulation.swift`
- `Sources/EmperorCore/MarketSimulation.swift`
- `Sources/EmperorNative/LibraryModel.swift`
- `Sources/EmperorNative/GameControlsView.swift`
- `Sources/EmperorNative/ContentView.swift`
- `Sources/EmperorNative/StatusBarViews.swift`
- `Tests/EmperorCoreTests/SimulationClockTests.swift`（新建）
- `Tests/EmperorCoreTests/MigrationSimulationTests.swift`（新建）

**明确不在范围：**生产配方、作物选择、外交/军事规则、人物精灵、完整人气公式、犯罪导致的
迁出、存档格式版本升级、网络同步。不要修改原版安装目录。

## Git 工作流

工作区当前不是 Git 仓库。若操作方后来初始化了 Git，使用分支
`advisor/001-continuous-clock-and-migration`，按逻辑步骤提交，不推送；否则只保留工作区修改并
用 `shasum`/测试验证。

## 步骤

### 1. 先写月度等价和存档特征测试

新建 `SimulationClockTests.swift`，构造含道路、住宅、井和市场的确定性小城，记录当前
`advanceMonth(rules:)` 的月末关键结果：年月、税收、生产批次、住宅等级、库存和行人位置。
同时声明新 API 的目标：连续调用固定数量 tick 后只产生一次 `MonthlySettlement`，结果中的
月度经济字段与兼容 `advanceMonth` 一致；月中编码/解码后继续运行与不中断运行完全相同。

测试不要复制整个 4,728 行测试文件；使用 `import EmperorCore`、`import XCTest` 和独立
`XCTestCase`，风格参考 `Tests/EmperorCoreTests/EmperorCoreTests.swift:1-30`。

**验证**：测试应因新 API 尚不存在而编译失败；确认失败只指向计划中的新符号，然后继续。

### 2. 增加唯一的可保存子月时钟

在 `SimulationClock.swift` 新增：

- `SimulationClockState: Sendable, Hashable, Codable`，包含 `day`（1...30）和单调
  `tickSequence`；固定 `daysPerMonth = 30`。
- `advanceOneDay() -> SimulationClockAdvance`，返回是否到达月末；月末后 day 回到 1。
- `CityTickResult`，至少包含 tick 序号、当前 day、移动摘要和可选 `MonthlySettlement`。

在 `DeterministicCityState` 增加 optional backing `simulationClockState` 和月内服务覆盖累加器；
旧 format-v1 存档缺字段时从 day 1、空累加器开始。不要修改 `NativeSaveGame.currentFormatVersion`。

**验证**：`swift test --filter SimulationClockTests` 中纯时钟、12 月跨年、月中存档测试通过。

### 3. 把移动和月末结算拆开，保持单一路径

在 `DeterministicCityState` 增加
`advanceTick(rules:) -> CityTickResult`：每个 tick 只让已配员的服务行人、运输员、市场买手/
小贩各前进一步，并把沿途服务住宅集合并入月内累加器；仅第 30 天结束时调用私有
`settleMonth(rules:accumulatedCoverage:)` 进行生产、消费、税收、住房演化、风险和日历推进。

具体拆分要求：

- 将 `MarketSimulation.advanceMonth` 拆成“安排任务”“前进一步”“月末消费/汇总”三个明确函数；
  不允许月末再次把买手和小贩瞬移完整路线。
- 将物流已有的 `advanceDeliveries` 以 1 step/tick 调用；月末只安排新配送，不重复推进。
- 服务覆盖在访问住宅时立即累计，但住宅演化/税收只在月末读取本月累计值。
- 每个 tick 重新应用 `CityOperationsSimulation.workforce`，新建筑初始员工必须为 0，随后由现有人口
  分配；不要产生第二套 UI 员工真相。
- 兼容 `advanceMonth(rules:)` 必须循环调用 `advanceTick` 直到拿到月结并返回它；禁止保留旧的
  并行月结实现。

**验证**：新增测试断言 29 tick 不跨月，第 30 tick 恰好跨月一次；行人位置在相邻 tick 间只沿
合法路线变化；`advanceMonth` 和 30 tick 的最终完整城市状态相等。

### 4. 增加确定性自然迁入及原因状态

> **已撤销 / BLOCKED BY UNKNOWN：** 本节规则是 Native 近似，不是原版合同。不得恢复这些
> 阈值或用测试注入掩盖缺失生产者；当前替代仅为只读住房容量观测与显式 unsupported 状态。

在 `MigrationSimulation.swift` 新增 `MigrationAssessment`、`MigrationBlockReason` 和
`DeterministicMigrationState`。垂直切片采用以下明确兼容规则，避免执行者自行发明：

- 只考虑有地图位置、邻接道路且有空位的普通住宅；按 house ID 升序入住。
- 新城阶段（人口少于 150）每个游戏日最多迁入 5 人，仍受总空位限制。
- 150 人以后，若国库为负或失业率高于 10%，暂停迁入并记录原因；否则仍是最多 5 人/日。
- 劳工短缺不是阻止迁入的理由；它应该通过新居民缓解。
- 本计划不实现迁出，但状态类型应允许以后增加负数月度迁移而不破坏编码。

迁入必须通过核心函数执行，UI 只能显示本日/本月迁入和阻塞原因。把
`admitResidents` 降为内部兼容原语或保留 public 但删除所有生产 UI 调用。

**验证**：测试空房不足、无道路住宅、5 人/日上限、跨住宅顺序、150 人后高失业暂停、月中
存档重放一致；所有测试不直接修改 `residents`。

### 5. 让 SwiftUI 速度档驱动 tick，并移除生产调试捷径

将 `LibraryModel.restartSpeedTimer` 改为调用 `advanceCityTick()`。建议固定间隔：1x=0.25 秒、
2x=0.125 秒、3x=0.0625 秒；速度只影响墙钟频率，不改变单个 tick 的规则。只有
`CityTickResult.monthlySettlement != nil` 时才调用 `CampaignMissionRuntimeState.advance`。

从 `GameControlsView` 的 release UI 删除：迁入 10 人、三类前进 8 格、推进一月、自动建立下一
贸易伙伴和单独窑炉音效。若维护者坚持保留诊断能力，只能放在 `#if DEBUG` 且折叠到明确命名的
“开发诊断”区域。删除 12 栋住宅限制。

在年月卡片显示“年/月/日”，在状态条显示当日迁入数或暂停迁入原因。

**验证**：`rg -n '迁入 10 人|前进 8 格|推进一月' Sources/EmperorNative` 在 release 路径无匹配；
构建成功；暂停时等待不会改变 tick，1x/2x/3x 在相同 tick 数后状态完全一致。

## 测试计划

- `SimulationClockTests`：边界、跨年、一次月结、兼容 API 等价、中途存档重放。
- `MigrationSimulationTests`：容量、道路、顺序、速率、失业/负债阻塞、存档。
- 在原大测试文件中只调整因“行人逐步走”而失效的断言；不要删除测试或放宽为非确定性范围。
- 全量测试必须继续覆盖 62 个地图任务的启动和 49 个官方任务的确定性回放。

## 完成标准

- [ ] 29 tick 不跨月，第 30 tick 恰好生成一次月结。
- [ ] `advanceMonth` 与运行到下一月末的 tick 路径得到相同完整状态。
- [ ] 自动迁入恢复原版生产者后，新住宅无需 UI 注入即可入住，且不超过空置容量
  （当前 `BLOCKED BY UNKNOWN`）。
- [ ] 正常 UI 不存在迁入/移动/月跳调试按钮，也不存在 12 栋住宅限制。
- [ ] 月中存档恢复后的重放逐字段一致。
- [ ] `swift build` 和 `swift test` 均 exit 0。
- [ ] `git status --short`（若有 Git）只列出范围内文件和 `plans/README.md`。
- [ ] 001 迁入部分解除 `BLOCKED BY UNKNOWN`；连续时钟部分已完成。

## 停止条件

- 基线校验不一致且当前代码不再匹配摘录。
- 拆分后需要改变生产配方、贸易额度或战斗公式才能让 tick 工作。
- 旧存档无法在不升级/迁移格式的情况下解码。
- 两次合理修正后，30 tick 与兼容 `advanceMonth` 仍无法达到确定性等价。
- 必须修改范围外文件；先报告并申请调整范围。

## 维护说明

未来增加动画时只能读取 `tickSequence`/实体移动状态，不能让渲染时钟反向驱动规则。以后实现更
完整人气和迁出，应替换 `MigrationAssessment` 的策略，不要再次在 UI 直接修改居民数。审查时重点
检查月末是否存在任何“再走完整路线”的双重推进。
