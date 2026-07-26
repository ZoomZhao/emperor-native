# Plan 004: 补齐胜利、连续负债失败和重玩闭环

> **执行者说明**：先确认计划 001、002 已是 `DONE`。本计划建立可存档的任务终局，不实现尚未
> 存在的军事战败。完成后更新 `plans/README.md` 的 004 状态。
>
> **漂移检查（首先运行）**：`shasum -a 256 -c plans/baseline.sha256`。计划 001、002 修改过的
> 文件 mismatch 是预期的；对照其最终 diff。若 campaign runtime、economy 或 save schema 有未知
> 变化，先停止并核对迁移策略。

## 状态

- **执行状态**：DONE
- **优先级**：P1
- **投入**：L（多日）
- **风险**：HIGH；涉及经济结算顺序、存档迁移和终局幂等性
- **依赖**：`plans/001-continuous-clock-and-migration.md`、`plans/002-xia-tutorial-economy-loop.md`
- **类别**：correctness / UX / tests
- **生成基线**：无 Git；`plans/baseline.sha256`，2026-07-22

## 为什么重要

现在核心能把 `missionCompleted` 置为 true，但 UI 只写一行状态文字；没有失败状态、终局暂停、
下一关或重玩闭环。更关键的是普通 `debit` 拒绝让国库变负，因此手册规定的“连续 36 个月负债
即失败”永远无法触发。没有可赢也可输的稳定边界，第一关仍只是沙盒演示。

完成后，玩家应在目标达成的月末看到胜利并能继续/重玩；连续 36 个结算月国库为负时看到明确
失败并能重玩。终局后的计时器和事件必须停止，保存/加载必须保留相同结果。

## 当前状态

- `CampaignMissionRuntime.swift:66-71` 的 advance result 只有 `missionCompletedNow`。
- `CampaignMissionRuntime.swift:100-102` 只存 `missionCompleted` 和完成年月；`183-218` 在月末评估
  目标并执行完成事件，没有失败分支。
- `EconomyRulesEngine.swift:87-93` 的 `debit` 要求 `treasury >= amount`，无法形成债务。
- `LibraryModel.swift:540-562` 每次整月结算后推进 campaign；完成时只设置
  “任务目标已达成”文本，timer 仍继续运行。
- 当前默认正常年薪是 30，战役事件可以增减 `normalAnnualWage`；尚未把工资作为城市月度支出。
- 原版手册 `tmp/pdfs/manual/manual.txt` 的失败规则说明：国库连续 36 个月处于负值会失去任务；
  被同一敌国再次征服属于军事失败，因本地军事战役闭环尚不完整而明确延期。

## 所需命令

| 用途 | 命令 | 成功标准 |
|------|------|----------|
| 终局测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter CampaignMissionOutcomeTests` | 全部通过 |
| 存档迁移 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Save` | 旧、新 fixture 全通过 |
| 经济测试 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Economy` | 全部通过 |
| 全量 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0 |
| 构建 | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |

## 范围

**允许修改/创建：**

- `Sources/EmperorCore/CampaignMissionRuntime.swift`
- `Sources/EmperorCore/EconomyRulesEngine.swift`
- `Sources/EmperorCore/CitySimulation.swift`
- `Sources/EmperorCore/NativeSaveGame.swift`（仅 schema/迁移需要时）
- `Sources/EmperorNative/LibraryModel.swift`
- `Sources/EmperorNative/StatusBarViews.swift`
- `Sources/EmperorNative/GameControlsView.swift`
- `Sources/EmperorNative/ContentView.swift`
- `Tests/EmperorCoreTests/CampaignMissionOutcomeTests.swift`（新建）
- `Tests/EmperorCoreTests/NativeSaveOutcomeMigrationTests.swift`（新建）

**不在范围：**军事二次征服失败、评分/排行榜、结算动画、联网结果、所有原版失败原因、改变战役
目标值、自动修改玩家存档。

## Git 工作流

若已有 Git，使用 `advisor/004-mission-outcome-and-debt-failure`；不要推送。无 Git 时保留范围内
修改，以存档 fixture、测试输出和终局截图交接。

## 步骤

### 1. 建立唯一、可存档的任务结果状态机

增加：

```swift
public enum CampaignMissionOutcome: Sendable, Hashable, Codable {
    case running
    case victory(CampaignVictoryRecord)
    case defeat(CampaignDefeatRecord)
}

public enum CampaignDefeatReason: Sendable, Hashable, Codable {
    case continuousDebt(months: Int)
}
```

record 至少保存终局的 settlement year/month；defeat 还保存触发时国库。`missionCompleted` 保留为
兼容计算属性或兼容字段，唯一事实源必须是 outcome。`CampaignMissionAdvanceResult` 增加
`outcomeChangedNow`，并提供 `missionCompletedNow` 兼容计算属性，避免一次迁移所有调用者。

对旧存档使用显式 `init(from:)`：旧 `missionCompleted == true` 映射为 victory，false/缺失映射为
running；新存档写 outcome。不得仅添加非 optional 字段依赖 synthesized Codable。

**验证**：旧 0.50/0.32 fixture 可读；胜、负、running 新存档 round-trip 后相等。

### 2. 把工资加入月末结算并允许这一类支出形成负债

不要放宽现有建造/交易 `debit`。新增用途明确的 `chargeOperatingExpense(_:)`，允许工资把国库降到
负数，同时更新 lifetime expenses 和 transaction sequence。只有系统运营支出可调用它。

用统一 workforce 本月实际 `assignedWorkers` 计算工资。原版工资值按“每 10 名工人每年”解释，
采用确定性整数公式：

```text
numerator = assignedWorkers * normalAnnualWage + payrollRemainder
monthlyPayroll = numerator / 120
payrollRemainder = numerator % 120
```

`payrollRemainder` 必须存档，避免逐月截断导致长期漏付。先冻结当月实际员工数，再收工资，再评估
债务与任务目标；工资事件从其被应用后的下一个工资结算周期生效，测试中固定这一顺序。

**验证**：0、部分、满员和工资事件场景的 12 个月总额与公式一致；建造仍不能透支，工资可以。

### 3. 实现连续 36 个负债月失败

在 runtime 保存 `consecutiveDebtMonths`。每次真实月末工资/收入/费用全部结算后：treasury < 0 则
加一，否则归零。第 36 次连续为负时生成 `defeat(.continuousDebt(months: 36))`；第 35 个月不能
提前失败，期间任何一个月回到零或正数都必须清零。

同一月同时满足住房目标和第 36 个负债月时，先判失败，避免玩家已经因财务破产仍获得胜利。
这是本地兼容规则，必须在测试名和维护说明中固定。终局只可从 running 转移一次。

**验证**：35/36 边界、归零重计、同月胜负冲突、无员工无工资、加载第 35 月后继续都通过。

### 4. 让终局冻结模拟且保持幂等

runtime 已为 victory/defeat 时，后续 `advance` 不再推进 scheduler、请求期限、礼物、工资、债务
计数或目标；返回空 effect 且 `outcomeChangedNow == false`。`LibraryModel` 观察到终局后立即把速度
设为 0 并取消 timer。

所有完成事件只在 victory 边界执行一次；defeat 不执行完成事件。保存后重开不得重新弹出为
“刚刚完成”，但 UI 应能从 outcome 恢复终局画面。

**验证**：终局后再调用 100 次 tick/month，城市哈希、事件数量、国库和 outcome 不变。

### 5. 补齐胜利、失败、继续与重玩 UI

在任务界面显示不可忽略的终局 overlay/sheet：

- 胜利：任务标题、达成年月、`进入下一任务`（存在时）、`重玩本任务`、`返回战役列表`。
- 失败：连续负债月数与国库、`从最近存档读取`、`重玩本任务`、`返回战役列表`。

“重玩”必须重新读取原版 mission world，重置城市、runtime、clock、选择工具和临时 UI 状态；不
覆盖旧存档，除非玩家之后主动保存。“下一任务”复用正常任务启动入口，不能复制一套初始化。

状态栏运行中显示负债连续月数（仅 >0 时），让失败可预判。按钮需有 accessibility identifier，
供计划 005 的 UI 门禁使用。

**验证**：手工分别触发胜利和失败，确认暂停、按钮路径、重玩初始资金/年月/空城都正确。

## 测试计划

- outcome：running→victory、running→defeat、终局不可逆、完成事件一次。
- 工资：整数余数、12 月累计、工资事件边界、只有运营费用可透支。
- 失败：35/36、非负重置、加载续算、同月胜负冲突先失败。
- 存档：旧 `missionCompleted` 迁移，新 outcome 三态 round-trip。
- UI model：终局设置速度 0，重玩重建全部 mission-scoped 状态。
- 回归：现有 Campaign、Economy、Save 测试与全量测试。

## 完成标准

- [ ] 任务有 running/victory/defeat 唯一状态，且可向后兼容存档。
- [ ] 工资按实际员工和正常年薪结算，可导致负国库；普通消费仍不能透支。
- [ ] 连续 36 个结算月负债准确失败，中断即清零。
- [ ] 同月胜负冲突按“失败优先”固定，终局后所有推进幂等。
- [ ] 胜利/失败 UI 可继续、读档、重玩或返回，并自动暂停。
- [ ] 旧、新存档测试、全量 `swift test` 和 `swift build` 全部 exit 0。
- [ ] 004 状态更新为 `DONE`。

## 停止条件

- 原版工资单位被本地数据/手册证据推翻，不能继续使用 `/120` 公式；先记录新证据并修订计划。
- 计划 001 不能提供唯一月末结算边界，导致工资或债务重复计算。
- 当前 save schema 无法在不丢玩家城市状态的前提下迁移 outcome。
- 实现需要伪造负国库或直接设置第 36 月状态才能通过测试。
- 军事失败逻辑被意外拉入范围。

## 维护说明

失败优先和工资 `/120` 是本地兼容规则，未来获得更强的原版逆向证据时可整体替换，但必须同步
迁移存档和边界测试。以后加入军事失败时扩展 `CampaignDefeatReason`，不要另建第二个
`gameOver` 布尔值。所有周期性支出必须明确走运营费用 API，普通玩家支出继续受余额保护。
