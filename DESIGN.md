---
version: alpha
name: Imperial Bronze Chronicle
description: "Emperor Native 的经典中国古代城市营造界面系统：地图优先、铜褐器物感、金色信息层级与清晰的 macOS 原生交互。"
colors:
  background-app: "#0E110E"
  surface: "#381F11"
  surface-deep: "#1B1109"
  surface-raised: "#4A2611"
  surface-control: "#4D2E18"
  primary: "#F0BA40"
  on-primary: "#261409"
  secondary: "#A66329"
  tertiary: "#C72E1A"
  on-surface: "#FFF8E8"
  on-surface-muted: "#C8B9A3"
  success: "#6FAF68"
  warning: "#E58B2A"
  error: "#C72E1A"
  placement-valid: "rgba(85, 185, 106, 0.58)"
  placement-invalid: "rgba(217, 65, 50, 0.62)"
  overlay-scrim: "rgba(0, 0, 0, 0.62)"
typography:
  display:
    fontFamily: "SarasaTermSCNerd-Bold"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: "SarasaTermSCNerd-Bold"
    fontSize: 20px
    fontWeight: 700
    lineHeight: 1.2
  headline-md:
    fontFamily: "SarasaTermSCNerd-Bold"
    fontSize: 17px
    fontWeight: 700
    lineHeight: 1.25
  headline-sm:
    fontFamily: "SarasaTermSCNerd-SemiBold"
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.3
  body-md:
    fontFamily: "SarasaTermSCNerd-Regular"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
  body-sm:
    fontFamily: "SarasaTermSCNerd-Regular"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
  label-md:
    fontFamily: "SarasaTermSCNerd-SemiBold"
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.25
  label-sm:
    fontFamily: "SarasaTermSCNerd-SemiBold"
    fontSize: 10px
    fontWeight: 600
    lineHeight: 1.2
  caption:
    fontFamily: "SarasaTermSCNerd-Regular"
    fontSize: 9px
    fontWeight: 500
    lineHeight: 1.25
  metric:
    fontFamily: "SarasaTermSCNerd-Bold"
    fontSize: 12px
    fontWeight: 700
    lineHeight: 1.2
rounded:
  none: 0px
  subtle: 2px
  dialog: 4px
  native-card: 12px
  native-modal: 22px
  full: 9999px
spacing:
  none: 0px
  base: 4px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  window-min-width: 1120px
  window-min-height: 680px
  window-default-width: 1240px
  window-default-height: 760px
  hud-height: 48px
  panel-width: 286px
  panel-header-height: 34px
  category-rail-width: 54px
  command-row-height: 36px
  population-advisor-height: 148px
  city-navigation-height: 40px
  minimap-width: 156px
  minimap-height: 112px
components:
  imperial-hud:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.none}"
    height: "{spacing.hud-height}"
    padding: "{spacing.md}"
  control-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.none}"
    width: "{spacing.panel-width}"
    padding: "{spacing.none}"
  panel-header:
    backgroundColor: "{colors.surface-deep}"
    textColor: "{colors.primary}"
    typography: "{typography.headline-sm}"
    rounded: "{rounded.none}"
    height: "{spacing.panel-header-height}"
    padding: "10px"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.none}"
    padding: "{spacing.sm}"
  button-secondary:
    backgroundColor: "{colors.surface-control}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label-md}"
    rounded: "{rounded.none}"
    padding: "{spacing.sm}"
  button-selected:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label-md}"
    rounded: "{rounded.none}"
    padding: "{spacing.sm}"
  map-hint:
    backgroundColor: "{colors.surface-deep}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.none}"
    padding: "9px"
  mission-dialog:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    rounded: "{rounded.dialog}"
    padding: "{spacing.xl}"
    width: "620px"
  minimap:
    backgroundColor: "{colors.surface-deep}"
    rounded: "{rounded.none}"
    width: "{spacing.minimap-width}"
    height: "{spacing.minimap-height}"
---

# Emperor Native Design System

## Overview

Emperor Native 是面向 macOS 的《皇帝：龙之崛起》原生重实现。界面应让玩家感觉自己在使用一套古代中国城市治理器具，而不是现代 SaaS 仪表盘：地图和原版运行时素材是主角，界面像包围地图的铜木框架，信息密集但秩序清楚。

设计气质来自参考截图中的四个稳定特征：

- **地图优先：** 城市地图或叙事插画占据最大面积，控制面板停靠在边缘，不以浮动卡片遮挡主要内容。
- **铜册质感：** 面板使用深褐、赭石和低对比度纹理；一像素金铜色线条组织层级。
- **帝王金强调：** 标题、数值重点和选中态使用金色，红色只用于危险、破坏、失败或少量品牌时刻。
- **古典框架、原生行为：** 外观向经典游戏致敬，文字、焦点、键盘操作、菜单和辅助功能仍遵循现代 macOS 习惯。

界面分为两个层级：

1. **玩家界面**包括战役选择、任务说明、城市地图、建造栏、任务结果和存档流程。它必须使用本文件的经典铜册语言，优先使用方角、边框和色块组织信息。
2. **资料与诊断界面**包括地图/战役数据浏览、解析状态和开发诊断。它可以使用 `NavigationSplitView`、系统菜单和原生控件，也可以使用 `native-card`、`native-modal` 圆角；但色彩、排版和信息层级应与玩家界面保持亲缘关系。

参考图片位于开发机的 `/Users/zoomzhao/Downloads/emperor/`，用于观察构图、色彩和交互密度。可运行的游戏素材（地图、战役、精灵、音频等）解压在仓库根目录 `GameData`，供本地开发与测试，并由打包脚本复制到应用包 Resources。

当文字规则与 YAML token 冲突时，以 token 为准。实现中的集中式主题值应引用这些 token 的等价值，避免在各个 View 中继续增加零散颜色和尺寸。

## Colors

配色以深铜褐为骨架，以暖金为信息高光。界面不能大面积使用纯白或系统蓝；地图本身的草地、水体、建筑和人物颜色应保持真实，不套统一棕色滤镜。

- **Primary / Imperial Gold (`#F0BA40`)：** 标题、当前工具、当前分类、关键数字和焦点状态。一个局部区域通常只保留一个最强金色焦点。
- **Surface Brown (`#381F11`)：** 右侧面板、工具栏和经典对话框的基础面。
- **Deep Ink Brown (`#1B1109`)：** 地图提示、凹陷列表、迷你地图底槽和强分隔区域。
- **Raised Bronze (`#4A2611`)：** 顶栏渐变的亮端、对话框和轻微抬升的区域。
- **Control Brown (`#4D2E18`)：** 未选中的按钮和工具格。
- **Border Bronze (`#A66329`)：** 1px 分隔线和控件描边；可按上下文降到约 72% 不透明度。
- **Text Ivory (`#FFF8E8`)：** 深色表面上的主文字。辅助文字使用 `on-surface-muted`，不要仅依赖低透明度导致不可读。
- **Imperial Red (`#C72E1A`)：** 拆除、失败、严重告警和危险态；不可作为普通按钮的第二主色。
- **State colors：** `success` 表示达成或合法，`warning` 表示资源/条件受限，`error` 表示失败或非法。状态必须同时使用图标或文字，不能只靠颜色。

资源图层可保留与地图语义一致的颜色：食物/水为青色、木材为绿色、石材为灰色、黏土为橙色。覆盖层应半透明，必须让地形和格子边界仍可辨认。

## Typography

界面统一使用 `Sarasa Term SC Nerd`（[laishulu/Sarasa-Term-SC-Nerd](https://github.com/laishulu/Sarasa-Term-SC-Nerd)）。正文使用 Regular，层级标题与标签分别使用 SemiBold/Bold；数值直接利用该字体的中英文严格等宽特性。应用按字体的 PostScript 名称选择字重，字体不可用时回退到相同字号和字重的 macOS 系统字体，不能因字体缺失阻断启动或降低辅助功能可用性。

该字体采用 SIL Open Font License 1.1。当前工程不复制字体二进制；开发与运行环境需要单独安装字体。若发行包以后嵌入字体，必须同时包含上游版权声明及完整 OFL 许可证。

- **Display：** 仅用于任务胜利/失败、重大章节标题和少量空状态。
- **Headline：** 面板名称、任务名称和对话框标题；金色标题通常使用 `headline-sm` 或 `headline-md`。
- **Body：** 任务说明、事件详情和帮助信息。连续中文正文不得低于 `body-md`。
- **Labels：** 紧凑 HUD、工具名称、分类和次要操作。7.5–9pt 的遗留微型标签只能用于空间固定且有 tooltip/辅助标签的图标格，新界面默认不低于 `label-sm`。
- **Metrics：** 国库、人口、日期、速度和坐标等使用 Bold；Sarasa Term SC Nerd 本身为等宽字体，因此无需叠加另一套数字字体。

标题采用简洁的中文，不使用全大写英文。正文行宽控制在约 34–48 个中文字符；长任务说明使用左对齐和 1.4–1.5 行高。省略文字时必须通过 tooltip、详情面板或辅助功能名称提供完整内容。

## Layout

主城市界面采用固定框架的 **Map-first Docked Shell**：

- 窗口最小内容尺寸为 `1120 × 680`，默认 `1240 × 760`。
- 顶部 `48px` HUD 横跨窗口；地图占据剩余空间；右侧面板固定 `286px`，不压缩地图高度。
- HUD 从左到右依次为文件/选项/帮助、任务与城市身份、弹性空白、国库/人口/日期、情境徽记。高频指标必须单行可扫读。
- 右侧面板按“人口顾问（住房供给/城市行人）→ 分类轨道与建造目录 → 常驻工具条（浏览/道路/清理/拆除）→ 资源图层 → 命令/速度 → 迷你地图 → 城市/世界地图/目标导航”排列。完整任务目标由底栏卷轴按钮打开，不常驻挤占建造目录。
- 分类轨道宽 `54px`；建造目录使用两列紧凑网格。固定宽面板内不得再嵌套横向滚动。
- 常驻工具条始终可见，使用原版道路图块与清除/拆除图标；不要把长城分类按钮当作修路入口。
- 迷你地图保持 `156 × 112` 的核心画面，并与方向控制共同停靠在面板底部。
- 地图上的临时提示贴近左上安全边距 `8px`，只展示当前工具和一句可执行指令。

使用 4px 基线节奏。面板内部常用 8px，顶栏与较大组合使用 12px，叙事/诊断页面的大区块使用 16–24px。紧凑不等于拥挤：不同任务域之间用边框或 12px 以上空间明确分组。

战役和任务选择页沿用参考图的“双册页”逻辑：左侧为可选择列表，右侧为插画/说明/目标。大幅背景图仅在有合法运行时素材时使用；否则用深色渐变和地图预览，不制造仿原版插画。

窗口变窄时保持 HUD、右侧面板和地图的职责，不把所有内容改造成纵向卡片流。资料与诊断页则可以随窗口宽度在三栏、两栏之间响应式变化。

## Elevation & Depth

经典界面的层级主要由**色调、凹槽和边框**表达，而不是阴影：

- `surface-raised` → `surface` → `surface-deep` 表示从抬升到凹陷。
- 面板边界和按钮使用 1px `secondary` 描边；内部网格线可以降至 0.5–0.8px 或较低不透明度。
- 铜褐纹理必须低对比、低频率，只为消除大面积纯色的塑料感；不得影响文字阅读，也不得在每个小控件中使用不同纹理。
- 地图与控制栏之间使用明确分隔线，不使用大片投影。
- 只有模态任务结果、系统弹窗或需要阻断地图交互的浮层可使用阴影。背景同时覆盖 `overlay-scrim`，让焦点层级明确。

编织/回纹边框可以抽象为简洁的一像素双线或重复几何纹理；需要原版边框位图时，使用已打包的运行时素材，而不是额外描摹参考截图。

## Shapes

玩家界面的形状语言是**建筑式方正**：

- HUD、停靠面板、按钮、工具格、列表槽、迷你地图和地图提示使用 `rounded.none`。
- 经典任务对话框最多使用 `rounded.dialog`，边框比圆角更重要。
- 小型状态灯、方向标记、头像和确有语义的徽章可以使用圆形；普通按钮不要随意变成胶囊。
- 资料/诊断界面的原生卡片可以使用 `native-card`，结果模态可使用 `native-modal`。同一局部容器内不要混用方角经典控件与大圆角玻璃卡片。
- 图标优先使用清晰的 SF Symbols 或打包游戏数据中运行时解析出的图像。图标必须服务于识别，不以龙、印章、阴阳等符号作无意义装饰。

选中态通过金色填充和深色前景形成实心反转；悬停态只做轻微提亮；按下态略微变暗；禁用态降低饱和度并保留可读标签。键盘焦点必须有独立、可见的焦点环，不能只复用选中态。

## Components

### Imperial HUD

高度固定 48px，使用由 `surface-raised` 到 `surface-deep` 的水平渐变，底部一条半透明金线。菜单保持 macOS 原生行为。指标由金色图标、弱化标签和象牙白等宽数值组成；不得添加可滚动内容或超过两行的信息。

### Docked control panel

面板宽 286px 且占满 HUD 以下高度。顶部人口顾问高 148px，显示住房容量、迁入状态以及住房供给/城市行人覆盖入口。所有工具、速度、迷你地图和底栏导航都在此处闭环，避免在地图四周再堆第二套悬浮工具条。

### Category rail and construction tiles

分类轨道为纵向单选集合，当前分类使用 `button-selected`；非当前分类使用 `button-secondary`。建造工具为两列网格，图标在上、10–11px 标签在下。浏览、道路、清理树木与拆除另有常驻横条，避免埋在分类页里被误认成长城/纪念入口。工具必须有 tooltip、稳定的辅助功能标识和明确的选中状态。成本不足或任务禁用时使用真正的 disabled 状态，不仅降低透明度。

### Buttons

经典按钮使用方角、铜色 1px 描边和紧凑内边距：

- 主要/选中：金底深字。
- 次要：控制褐底象牙白字。
- 危险：红色图标或描边并带明确动词，如“拆除”“删除存档”；不要让整页充满红色。
- 图标按钮在固定面板中视觉尺寸可为 22–26px，但交互命中区应尽量达到 28px，并提供 tooltip。

同一组按钮的高度和标签基线必须一致。速度控制是单选分段组，暂停、1×、2×、3× 的选中态必须一眼可见。

### Mission guide and narrative panels

任务目标始终先显示“要达成什么”，再显示“下一步做什么”。固定右栏只保留卷轴入口，完整目标与下一步提示进入铜册对话框。完成态使用绿色勾选，未完成态使用金色方向提示；不要把完整教程正文塞进右栏。

战役说明、任务导语和目标页可以使用较大的铜册面板，内部正文槽采用 `surface-deep`。标题和正文都应保持高对比，不仿照原版截图中偏低对比的细小黄字。

### Map canvas, placement and overlays

地图必须是视觉重心。建筑、道路、人物和地形使用原版运行时精灵或确定性的原生渲染，不在其上加统一色调蒙版。原地图的 `offMap` 存储边界不显示为可玩的菱形格；可玩陆地缺少直接图像记录时使用原版草地底图补绘，不能暴露纯色解析占位。建筑放置预览应显示对应原版精灵的半透明落点形态，并完整覆盖 footprint：合法为 `placement-valid`，非法为 `placement-invalid`，并在提示中说明原因；只有没有可用精灵的道路、清理或调试工具可以仅使用格子反馈。拖拽、点击、旋转和相机移动必须共享同一套命中测试与视觉反馈。

地图提示使用 `map-hint`，只保留工具名和一条动作指令。浏览模式悬停住宅时显示当前等级、下一等级以及实时升级缺口；点击后进入完整建筑详情。需要长期阅读的信息进入右栏或对话框。

### Minimap

迷你地图固定在右栏底部，显示地图全貌、当前视口边框和可点击跳转。颜色来自地图语义而不是面板装饰色。方向按钮与迷你地图靠近，但不得遮挡地图内容。其下 40px 底栏使用原版四态接口精灵提供城市、世界地图与任务目标导航；缺少帝国数据时世界地图必须显示 disabled 态。

### Dialogs and mission outcomes

玩家流程中的对话框使用铜册表面、细金铜边框和明确标题。结果模态在 62% 黑色遮罩上居中，最大宽 620px。胜利和失败分别使用成功绿与帝王红，但正文仍为象牙白；主操作放在最前，重玩、读取和返回保持清楚的次级层级。

系统级文件选择、错误恢复和权限提示保留原生 macOS 控件，不伪装成游戏内面板。

### Loading, empty and error states

加载状态说明正在索引、解析或初始化的具体对象。错误状态提供原因与可执行恢复动作。空状态使用一个图标、短标题和一句说明即可，不为填满空间增加装饰图。

### Accessibility and input

所有图标按钮、地图工具、速度项、任务和结果操作都需要稳定的 accessibility label/identifier。保留已有自动化依赖的标识。键盘快捷键至少覆盖保存、载入和旋转；菜单项与按钮应呈现相同命令状态。正常正文保持 WCAG AA 级对比，颜色状态同时用文字/图标表达，并尊重 Reduce Motion 与系统字体可读性需求。

## Do's and Don'ts

- Do 让地图、原版运行时精灵和任务内容占据主要视觉面积。
- Do 从集中式主题/Token 取色和尺寸；新增共享 UI 时先复用现有组件。
- Do 使用金色表示当前焦点和关键层级，使用一像素铜色边框建立结构。
- Do 让固定右栏中的每个区块回答一个明确问题：目标、工具、图层、命令或导航。
- Do 为紧凑图标提供 tooltip、键盘焦点和辅助功能名称。
- Do 在实现有意改变视觉系统时，同一变更中更新本文件。
- Don't 把玩家界面改成一串半透明、大圆角、悬浮的通用 SwiftUI 卡片。
- Don't 用系统蓝作为品牌主色，也不要大面积使用纯白背景、玻璃材质或重投影。
- Don't 同时高亮多个主要动作；红色不得用于普通导航或装饰。
- Don't 为“古风”牺牲中文正文可读性，或引入来源不明的书法/像素字体；Sarasa Term SC Nerd 的正文最小字号仍必须遵循本规范。
- Don't 把参考截图目录当作运行时数据源；可运行素材应来自仓库根目录 `GameData` 或应用包内的同名 Resources。
- Don't 让装饰图案盖过数据、地图反馈、任务目标或错误原因。
