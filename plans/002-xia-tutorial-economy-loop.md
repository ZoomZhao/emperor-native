# Plan 002: 让玩家只靠正常建造完成夏朝教程第一关的经济链

> **2026-08-14 源码审计更正：** 本计划依赖的原版自动迁入生产者尚未实现（人物 `#11`
> 抵达写入链仍未知），因此玩家闭环为 `BLOCKED BY UNKNOWN`。下游劳工、物流、市场与住房
> 子系统测试可用明确标注的 fixture 居民独立验证，但不能据此声称玩家无需状态注入即可自然通关。

> **执行者说明**：先确认计划 001 已是 `DONE`。逐步执行并运行每个验证门禁；不要通过直接写
> 人口、库存、员工或胜利快照让任务通过。完成后更新 `plans/README.md` 的 002 状态。
>
> **漂移检查（首先运行）**：`shasum -a 256 -c plans/baseline.sha256`。
> 计划 001 修改过的范围出现 mismatch 是预期的；对照计划 001 的最终 diff 和本计划摘录。
> `ConstructionToolbar.swift`、`BuildingPlacement.swift`、`ProductionSimulation.swift`、
> `HousingEvolution.swift` 若在 001 之外发生未知变化则停止。

## 状态

- **优先级**：P1
- **投入**：L（多日）
- **风险**：HIGH；横跨建造、劳工、食物配送和住房演化
- **依赖**：`plans/001-continuous-clock-and-migration.md`
- **类别**：direction / correctness / tests
- **生成基线**：无 Git；`plans/baseline.sha256`，2026-07-22

## 为什么重要

第一关是原版明确设计的最小教学闭环。手册 `tmp/pdfs/manual/manual.txt:215-229` 列出这一关只
教授普通住宅、井、巡查塔、祖庙、狩猎肉食、磨坊和普通市场。官方数据要求至少 150 人达到
housing code 5；若这一小组建筑仍靠满员工注入、月跳或库存捷径，扩大到其他战役没有意义。

完成后，玩家应能读懂“空地→移民→劳工→猎场产肉→磨坊→市场买手/小贩→住宅得到食物和
服务→住房升级→目标完成”的完整因果链。

## 当前状态

- 夏朝教程包的第一关数据已由本地 inspector 验证：2038 BCE、六月、资金 2000、资源 `[4]`、
  `buildingMenuIDs=[1,12,13,20,26,29]`，目标 `cHousingGoal values=[5,150,0]`。
- `Sources/EmperorNative/LibraryModel.swift:310-319` 建造生产建筑时把模型员工数直接作为
  `assignedWorkers`，导致落地即满员。
- `LibraryModel.swift:299-304` 的普通市场固定一个食品摊；对第一关这是正确默认，不应在本计划
  扩展为全市场编辑器。
- `CitySimulation.swift:715-723` 仅对井检查地下水；其他第一关建筑只要求清地和道路。
- `MarketSimulation.swift:357-402` 当前把买货、行走、投递和住宅消费塞在一个月结函数里；
  计划 001 应已拆成 tick 移动和月末消费。
- `HousingEvolution.swift:195-227` 已能按水、食物质量、祖先服务等计算升级缺口；应复用它，
  不为教程写第二套升级判定。
- `OriginalCampaignBuildingPermissionCatalog` 已把 menu 12/13/20/26/29 映射到磨坊、普通市场、
  祖庙、井和巡查塔；肉食生产建筑 33 由本地资源 commodity 4 控制。

## 所需命令

| 用途 | 命令 | 成功标准 |
|------|------|----------|
| 教程规则测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter XiaTutorialEconomyTests` | 全部通过 |
| 住房测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Housing` | 全部通过 |
| 全量 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0 |
| 构建 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |
| 数据核验 | `.build/debug/emperor-inspect campaign-settings '/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]/Campaigns/1 Xia Dynasty - Tutorials.pak' --raw` | 第一关数据与上文一致 |

## 范围

**允许修改/创建：**

- `Sources/EmperorCore/CitySimulation.swift`
- `Sources/EmperorCore/BuildingPlacement.swift`
- `Sources/EmperorCore/ProductionSimulation.swift`
- `Sources/EmperorCore/LogisticsSimulation.swift`
- `Sources/EmperorCore/MarketSimulation.swift`
- `Sources/EmperorCore/HousingEvolution.swift`
- `Sources/EmperorNative/LibraryModel.swift`
- `Sources/EmperorNative/ConstructionToolbar.swift`
- `Sources/EmperorNative/CityCanvasView.swift`（仅信息面板/阻塞原因，不做素材工作）
- `Sources/EmperorNative/StatusBarViews.swift`
- `Tests/EmperorCoreTests/XiaTutorialEconomyTests.swift`（新建）

**不在范围：**农田/作物选择、仓库/粮仓纠正、贸易、精英住宅、军事、全部市场铺位编辑、原版
人物动画、教程第二关以后、直接修改战役目标。

## Git 工作流

若已有 Git，使用 `advisor/002-xia-tutorial-economy-loop`；不要推送。无 Git 时保留范围内修改，
以测试输出和计划状态交接。

## 步骤

### 1. 固化第一关数据和“禁止注入”测试约束

新建 `XiaTutorialEconomyTests.swift`。第一个测试从默认原版资料读取夏朝教程，断言第一关标题、
年月、资金、权限、肉食资源和住房目标完全匹配上文；找不到原版资料时 `XCTSkip`。

增加一个源代码守卫测试或 shell done check，确保通关场景中不出现：

- `admitResidents`
- `addHouse(levelID:residents:)`
- `receiveCampaignCommodityGift`
- 非零 `assignedWorkers` 构造参数
- 手工构造 `CampaignGoalProgressSnapshot`

**验证**：数据测试通过；场景测试先因经济链尚未打通而失败，而不是因读取路径错误失败。

### 2. 让所有第一关建筑从零员工开始并由人口统一分配

修改 `LibraryModel.placeConstruction`：猎场（building 33）以及所有生产建筑传
`assignedWorkers: 0`。检查井、巡查塔、祖庙、磨坊和市场的 backing state 也不保存一份与
`CityOperationsSimulation.workforce` 冲突的“默认满员”。每 tick 由计划 001 的统一 workforce
分配结果更新服务、生产、市场和物流是否可工作。

在建筑信息面板显示 `已分配/需要` 以及因缺工暂停的明确原因。不得为第一关硬编码员工数。

**验证**：建设后、人口到达前所有有员工需求的设施不产出/不派行人；移民到达后按
`CityOperationsSimulation.workforcePriority` 恢复。新增至少 4 个测试覆盖无人口、部分员工、
满员工和拆除后重新分配。

### 3. 用实体运输打通肉食到磨坊

确认 building 33 的原版生产配方输出 commodity 4（meat）。满员猎场只在正常月末生产；产物
保存在该实例的本地库存。物流调度应优先为有容量的磨坊创建 deliveryman（figure 22），沿道路
逐 tick 前往磨坊并在到达时卸货，不允许月末直接移动库存。

第一关没有仓库权限，因此猎场→磨坊直送必须独立成立。道路断开、猎场缺工、磨坊缺工或磨坊
已满时应暂停并在建筑信息中显示原因。

**验证**：测试观察到“生产者本地库存增加→运输员出现并逐格移动→到达后生产者减少且磨坊
增加”的序列；任何一步都不直接写库存。

### 4. 用市场买手和小贩把食物送到住宅

普通市场 building 59 保持默认食品摊。满员市场应派买手 figure 24 从磨坊取食物，买手返回后
市场库存增加；随后小贩 figure 23 沿巡逻路逐 tick 服务邻路住宅。住宅仅在小贩实际经过时得到
食物，月末按居民数消费。

修正所有会让 `advanceTick` 与月末重复推进买手/小贩的路径。道路中断应取消或阻塞路线并给出
可见原因，不能瞬移完成。

**验证**：测试分别覆盖磨坊无货、有货但道路断开、正常取货、正常送达、人口增加后消费增加；
行人相邻 tick 位置必须相邻。

### 5. 验证水、祖先和巡查覆盖驱动住宅升级

井（72）、祖庙（214）和巡查塔（124）必须在有员工且邻接道路时生成各自服务行人；服务只对
本月实际经过的住宅生效。复用 `DeterministicHousingEvolution.requirementsMissing`，让住房按月
最多升级一级，不要直接设为目标等级。

在住宅信息弹层按当前等级显示下一等级缺口，例如缺水、缺食物质量、缺祖先服务、吸引力不足；
使用已有 `HouseEvolutionRequirement` 类型生成文本，避免 UI 重算规则。

**验证**：单独缺少每种必要条件时住宅停在对应等级；补齐后下一月升级一级；服务路线不经过时
不能升级。测试从空置住宅开始，由计划 001 的迁入产生居民。

### 6. 将第一关 UI 收敛到允许且可操作的工具

加载第一关后，工具栏只显示普通住宅、道路/路障以及数据允许或资源允许的第一关设施；不显示
农田、军营、贸易等后续教程功能。所有工具必须经过 `campaignConstructionRestriction` 的核心
校验，不能只在 SwiftUI 隐藏。

保留普通市场自动食品摊，以免第一关引入不必要配置窗口。提供目标进度 `当前住房人数/150` 和
最常见升级阻塞原因，但本计划不显示胜利弹窗（由计划 004 处理）。

**验证**：第一关工具集合测试精确匹配允许集合；尝试以核心 API 建造禁用建筑仍失败；
`swift build` 通过。

## 测试计划

- 原版数据 fixture：第一关名称、权限、资源、资金和目标。
- 劳工：零人口、迁入后、劳工短缺、拆除释放。
- 物流：猎场→磨坊完整逐 tick 序列及断路场景。
- 市场：买手→市场→小贩→住宅→消费完整序列。
- 住房：每个升级条件、每月一级、服务必须实际经过。
- 范围守卫：任何测试不得调用五类状态注入 API。

## 完成标准

- [ ] 第一关所有必需设施都能从工具栏正常建造，禁用设施核心层也拒绝。
- [ ] 新建筑不再瞬间满员；功能状态只来自统一劳工分配。
- [ ] 肉食沿真实运输实体从猎场到磨坊，再由买手/小贩送至住宅。
- [ ] 住宅只靠自然迁入、真实食物和服务逐月升级。
- [ ] 目标进度能达到 150 人 housing code 5，但尚不需要计划 004 的弹窗。
- [ ] 通关场景源文件没有人口、库存、员工、等级或目标快照注入。
- [ ] `swift build`、定向测试和全量 `swift test` 全部 exit 0。
- [ ] 002 状态更新为 `DONE`。

## 停止条件

- 原版第一关数据不匹配上文（可能安装版本不同）。
- 计划 001 没有提供逐 tick 市场/物流接口，必须先修复 001，不能在本计划恢复月末瞬移。
- building 33 无法从现有原版模型证明产出 commodity 4。
- 达成住房 code 5 需要第一关权限之外的商品/服务；输出具体 HouseModel 字段后停止。
- 需要修改战役目标或直接写状态才能通过。

## 维护说明

第一关市场固定食品摊是有意收敛，不代表后续市场编辑已经完成。以后加入农业和更多商品时，应
扩展既有生产/物流/市场接口，而不是给教程场景特殊送货。审查重点是搜索任何非零
`assignedWorkers`、直接库存转移和按目标等级硬编码的路径。
