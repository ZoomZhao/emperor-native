# Original city utility strip (road / roadblock / clear / undo / last-event)

Read-only inspection of shipping authored data and the hash-identified original
executables (`Emperor[EN].exe` `8a6d2df1…6753`, cross-checked against
`Emperor[CH].exe` `dbdeca1e…15a`). No GameData mutation.

## 1. Authored evidence (confirmed)

`GameData/EmperorText.txt` (GB18030) group containing the tool-strip button
names, rows 3694–3698, in exact order:

```
3694  修路
3695  路障
3696  清除
3697  撤销
3698  查看最后事件
```

`GameData/EmperorManual.pdf` p.16 lists the same five controls in the same
order: Build Roads / Place Roadblocks / Clear Item / Undo Last Action / Go to
(View Last Event). "Place Roadblocks" is therefore a **control-panel tool
button**, not a construction-panel (ministry grid) item: the confirmed
`0x855888` safety/health category row has only `72,207,208,124,127` plus an
empty sixth slot, so roadblock never appears in the ministry grid.

## 2. Icon families (confirmed geometry, semantic assignment by order)

`China_Interface_New_parts.BMP` (bitmap 7) stores five consecutive four-frame
33×33 families between the bottom-nav families and the category-rail families:

| Family | Image IDs | Strip button |
| --- | --- | --- |
| group 133 | 1275–1278 | 修路 / Build Roads |
| group 134 | 1279–1282 | 路障 / Place Roadblocks |
| group 135 | 1283–1286 | 清除 / Clear Item |
| group 136 | 1287–1290 | 撤销 / Undo Last Action (same family as `OriginalInterfaceSpriteCatalog .undo` = 1287) |
| group 115 | 1291–1294 | 查看最后事件 / View Last Event |

Classification: the five-button strip composition and the 修路/路障/清除 order
are `confirmed` by authored text order plus the manual; the per-family icon
semantics for 撤销/查看最后事件 are `inferred` from position (no separate
undo/event art exists elsewhere in the sheet).

## 3. Why the native strip had no roadblock button

`ContentView.constructionUtilityStrip` previously exposed
`[.road, .inspect, .clearLand, .demolish]` plus a help button. The original
strip has no `.inspect` button (browse is the default cursor/right-click mode),
and the roadblock tool was reachable only through the non-player SwiftUI
fallback toolbar's safety category. `PlayerConstructionTool.roadblock` and
`DeterministicCityState.constructRoadBlock` were already implemented and
Xia-tutorial-verified (Banpo.map: 75 of 89 road tiles accept a roadblock).

## 4. Native contract

- `OriginalInterfaceUtilityIcon` exposes `.roadblock` → `#1279` (group 134).
- `constructionUtilityStrip` order becomes `[.road, .roadblock, .clearLand,
  .demolish]` followed by the message/help entry, matching the original
  five-button row (Native maps 撤销 art to the demolish tool and keeps the
  trailing message entry).
- Roadblock selection, preview validity, placement and walker-blocking
  semantics are unchanged; see `roadblock-path-blocking.md`.
