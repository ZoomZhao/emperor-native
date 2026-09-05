# Emperor Native 实施计划

由 `improve` 审计流程生成。2026-08-16 更新：仓库已有 Git（当前
`697f8f0d`），计划以 `git diff --stat <planned-at SHA>..HEAD -- <in-scope>`
做漂移检查；`plans/baseline.sha256` 仍是历史基线，不再单独维护。

001–005 是原垂直切片计划。001/002/005 的“自然迁入”部分曾因
`BLOCKED BY UNKNOWN` 阻断（原版流行度/因子迁移生产者未实现），其余子系统
已完成；003/004 已 `DONE`。006 是该阻断的恢复计划（研究优先），
2026-08-30 已实质完成：自动迁入生产者已实现并通过 Xia1/Qin1/Qin2
通关验证；仅剩 Xia2 续关布局覆盖与 Qin3 独立机制两个未被解封项，
不再有 `unknown` 阻断。007/008 是 2026-08-16 新增的后续高价值计划。

## 执行顺序与状态

| 计划 | 标题 | 优先级 | 投入 | 依赖 | 状态 |
|------|------|--------|------|------|------|
| 001 | 连续时钟、行人步进与自然迁入 | P1 | L | — | DONE（迁入生产者由 006 恢复并通过 Xia1/Qin1/Qin2 通关验证） |
| 002 | 打通夏朝教程第一关的玩家经济链 | P1 | L | 001 | DONE（Xia1 固定命令表 10 年自然胜利，证据链完整） |
| 003 | 用原版素材完整表现教程垂直切片 | P1 | L | 001、002 | DONE |
| 004 | 增加胜利、负债失败与重玩闭环 | P1 | L | 001、002 | DONE |
| 005 | 建立无状态注入的教程通关发布门禁 | P1 | L | 001–004 | BLOCKED: Xia2 续关继承房屋在新增市场 peddler 覆盖外而降级，人口不增长；需调整续关布局覆盖（更多市场/花园），见 006 收尾 |
| 006 | 恢复原版自动迁入生产者并解除发布门禁 BLOCK | P0 | L | 001、002、005 | IN PROGRESS（Phase 1 研究项 1a–1e 全部闭合；实现已落地；Xia1/Qin1/Qin2 通关恢复；剩余：Xia2 续关布局、Qin3 独立机制不做门禁前置） |
| 007 | 恢复英雄物理在场生命周期并接通英雄效果 | P1 | M/L | — | TODO（依赖 006 已恢复的纪念碑因子/食物写入者走查，均可读） |
| 008 | 恢复战役事件消息短语族与变量绑定 | P1 | M | — | TODO |

状态值：`TODO`、`IN PROGRESS`、`DONE`、`BLOCKED: <原因>`、
`REJECTED: <原因>`。

## 当前纵向切片验收（2026-08-30 更新）

- [x] 原版夏朝第一关可由唯一玩家命令控制器启动和推进。
- [x] 固定命令表在十年上限内自然形成完整食物与住宅服务链并胜利（自动迁入生产者已恢复，Xia1 通关测试真实运行 10 年胜利）。
- [x] 缺市场、断路反例不会误胜，源码守卫拒绝状态注入。
- [x] running/victory/defeat、工资、连续负债、存档迁移与终局冻结已验证。
- [x] 第一关建筑及关键人物原版素材目录、解码、方向与确定性帧已验证。
- [x] 非 UI 发布门禁的构建、测试、打包路径存在；当前因 Xia2 续关 skipped 测试退出 65（release-gate 的 skip 守卫已修复为 grep，不再被 rg 缺失静默放行）。
- [ ] 真实 UI 通关：release-gate 的 xia1-ui-smoke 胜利段已恢复；需在已授权 macOS 主机上以 Accessibility 权限运行 `RUN_UI_SMOKE=1 scripts/release-gate.sh` 验证。

## 依赖说明

- 006 已实质完成：自动迁入生产者实现并通过 Xia1/Qin1/Qin2 通关验证；
  001/002 不再 BLOCK。剩余两个未解封项：Xia2 续关布局覆盖（005 门禁前置，
  合法布局调参）与 Qin3 的 music/水字段/货郎覆盖/吸引力独立机制（不做
  门禁前置，见 007 与最近 water house-info roles 闭合提交）。
- 007 依赖 006 中恢复的纪念碑因子/食物写入者走查（西王母效果写入
  `cHouseInfo+0x36`）；这些走查已由 006 记录在迁移文档 §10，可直接读用。
- 008 独立于 006/007，但共用 `OriginalEventMessageCatalog` 的
  GB18030 短语加载路径。

## 统一验证命令

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/release-gate.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect summary
```

需要本机原版资料的测试应在找不到
`/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]`
时用 `XCTSkip`，不能伪造替代资料后宣称官方任务通过；`release-gate.sh`
把 skip 视为失败。

## 共同边界

- 原版安装与 `Exe/ghidra/input/` 可执行文件始终只读，不修改、不复制进发行包。
- 不把“能启动”“可确定性空跑”“测试直接写入满足目标的快照”视为可玩。
- `advanceMonth(rules:)` 可以保留为兼容测试 API，但必须通过真实 tick 跑到月末。
- 006/007/008 均是研究优先；任何 `unknown` 缺口不得用近似常量、概率、
  计时器或现代城市建造规则填补。

## 已考虑但本轮延后

- **12 个网络任务**：需要大厅、同步和多人胜负协议，不能混入单人可玩化路径。
- **全 269 建筑和所有人物素材**：先覆盖已解析的官方单人路径；全量展开会让验收失焦。
- **Developer ID、公证与商店发行**：当前本地打包已经存在，不解决“游戏不好玩”的核心问题。
- **实时火灾蔓延/灭火状态机**：当前月级折叠是 DESIGN.md 记录的时间粒度折衷；
  需要逐帧火场状态机，另立计划。
