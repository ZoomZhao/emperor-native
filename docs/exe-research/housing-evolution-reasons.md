# Housing evolution reason text rows (`EmperorText` group 127)

Read-only evidence for the source of the housing "cannot upgrade" reason lines
shown in the building inspector. It records the authored row matrix that the
Native inspector consumes and the static control-flow anchor that ties those
rows to the original housing-reason state.

Binaries: `Emperor[EN].exe` (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`,
the canonical `1024 × 768` build) and `Emperor[CH].exe`
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, repacked widescreen
variant). The one function examined here, `0x51AF60`, is `identical` in
`local/source/compare-report.tsv`; there is no EN/CH divergence to reconcile.
No screenshots or runtime capture were required.

## 1. Authored data (evidence class: confirmed)

- `GameData/EmperorText.eng` group `0x7F` (127) has exactly **75 rows**. Its
  group-table record is at `0x20 + 127 × 8`; the record's string offsets are
  relative to the text-data base at `28 + 1000 × 8`.
- `GameData/EmperorText.txt` (GB 18030) group 127 has exactly **75 rows** by the
  `//----` group-separator parse used by `OriginalLocalizedTextCatalog`.
- Equal row counts plus a row-by-row semantic comparison confirm alignment:
  `localized(groupID: 127, rowIndex: n)` returns the same semantic row in the
  shipped English and Chinese tables.

The rows relevant to native upgrade-blocker display (zero-based):

| row | Chinese (authored) | English (authored, abbreviated) | meaning |
| --- | --- | --- | --- |
| 56 | `这所房子不能升级, 因为某些建筑物降低了这个地区的吸引力.` | `…Some of the buildings…reduced the neighborhood's appeal.` | appeal deficit attributed to negative nearby buildings |
| 57 | `除非这个地区的吸引力有所提高, 否则这所房子就不能升级.` | `…until the appeal of the neighborhood increases.` | generic low-appeal line |
| 58 | `干渴的居民们要喝水, 没有水这所房子就不能升级.` | water | water service |
| 59 | `这所房子里的居民需要 [food_quality] 食物, 房子才能升级.` | food quality placeholder | food-quality threshold |
| 60 | `这所房子里的居民要听到音乐, 房子才能升级.` | music | music service |
| 61 | `这所房子里的居民要看到杂技表演, 房子才能升级.` | acrobat | acrobat service |
| 62 | `这所房子里的居民要看到戏曲表演, 房子才能升级.` | drama | drama service |
| 63 | `这所房子里的居民 需要针灸医生来检查身体.` | acupuncturist | acupuncture service |
| 64 | `这所房子里的居民 需要草药医生来服务.` | herbalist | herbalist service |
| 65 | `除非有先祖庙的人到这里来, 否则这所房子不能升级.` | ancestral shrine | ancestor worship |
| 66 | `这所房子里的人 希望能有孔庙里的人来访.` | Confucian academy | Confucian access |
| 67 | `如果没有术士或和尚来这里, 那么这所房子就不能升级.` | Daoist or Buddhist building | Daoist/Buddhist access |
| 68 | `这所房子里的居民需要瓷器.` | ceramics | commodity `[25]` |
| 69 | `要是没有小贩送来苎麻, 这所房子就不能升级.` | hemp | commodity `[19]` |
| 70 | `要是没有小贩来卖茶叶, 这所房子就不能升级.` | tea | commodity `[13]` |
| 71 | `这所房子里的居民需要生活器皿.` | wares | commodity `Set[22, 23]` |
| 72 | `这所房子的居民没有买到丝绸, 房子就不能升级.` | silk | commodity `[24]` |

The authored Chinese rows cover every service/commodity shape produced by the
Native house table, so no paraphrase is required. The row-to-requirement mapping
for 60…72 is an `inferred` semantic match until the original reason-code writers
are recovered; it is not classified as recovered control flow.

## 2. Static control flow — `0x51AF60` (identical CH/EN)

`local/source/split-merged/audio/wavs_housing_wav.c` (`FUN_0051af60`) draws the
house detail panel next to the `housing.wav` audio reference. In the upgrade/
devolve reason path it selects the reason row by a byte on the house object:

- `reasonCode = *(byte *)(houseVtableGetter() + 0x3A)` (decompiled line 150 and
  217). As a byte ordinal, the drawn row is `reasonCode + 0x27` (`+39`):
  - `FUN_005278b0(0x7f, reasonCode + 0x27)` in the placeholder-formatting branch
    (line 166) and the `>` escape branch (line 181);
  - `FUN_00528cc0(0x7f, reasonCode + 0x27)` in the ordinary branch (line 219),
    which additionally draws the reason-row text; the `+0x2c`/`+0x1c` offsets in
    the same function are the separate state/devolve-message rows, not upgrade
    reasons.
- `FUN_005278b0(group, row)` advances through the group's null-terminated rows
  at `DAT_010db898[group × 8] + DAT_010dd8cc` and returns the `row`-th string
  pointer; its walker semantics confirm `param_2` is a zero-based row index, not
  an offset.
- Reason-code to row mapping (byte arithmetic `row = reasonCode + 0x27`):
  - `reasonCode` `17` → row `56` (appeal reduced by nearby buildings);
  - `reasonCode` `18` → row `57` (generic appeal must increase);
  - `reasonCode` `19` → row `58` (water);
  - `reasonCode` `20` → row `59` (food quality).
  Rows `60…72` follow the same `reasonCode + 0x27` scheme; the exact reason-code
  ordinals for each service/commodity were not individually enumerated, but the
  constant offset `+0x27` makes the authored rows `57…72` the same family.

The food-quality messages are the only placeholder-bearing rows in the group.
The formatter branch is gated directly on the same reason byte used for row
selection (decompiled line 151): when `*(byte *)(ok + 0x3A)` equals `0x02` or
`0x14` — reason codes `2` (devolve-food row 41) and `20` (upgrade-food row 59) —
the draw path loads the row through `FUN_005278b0(0x7f, reasonCode + 0x27)` and
runs the placeholder formatter: a getter supplies a food-quality scalar
(`FUN_0044cc80(ok, 8)`, or the `+0x22c` vtable getter for reason `0x14`),
`FUN_00545100` buckets it to a flavor 1…5 (points `≤29 / 30…49 / 50…69 /
70…89 / ≥90`), then `FUN_004987a0 → FUN_00498770 → FUN_00526350` copies the row
while substituting its `[food_quality]` token with the resolved flavor item
(the `[`…`]` scan in `FUN_00526350` and the per-item substitution callback
`(**(i2+8))()`).

## 3. Evidence classification

- **Confirmed (authored data):** the group-127 row matrix above; rows `57…72`
  are an upgrade-reason text family and row 59 carries
  the literal `[food_quality]` placeholder. Equal row counts plus row-by-row
  semantic comparison make the per-row Chinese alignment safe for this group.
- **Confirmed (static, identical):** `0x51AF60` selects `group 0x7F`, `row =
  reasonCode + 0x27`; reason codes 17/18/19/20 land on rows 56/57/58/59; the two
  food-quality reason codes `0x02`/`0x14` (rows 41/59) route through the
  `[food_quality]` placeholder formatter.
  The doc file name `wavs_housing_wav.c` and all local variable names are
  heuristics, not recovered symbols.
- **Confirmed-safe presentation for current Native:** **row 57** for the
  desirability blocker. Native knows the desirability is below the evolution
  threshold (`HouseEvolutionRequirement.desirability(current:required:)`) but
  cannot attribute the deficit to specific negative nearby buildings. Row 57 is
  the generic appeal line ("appeal of the neighborhood must increase"), which is
  exact for that state; row 56's attributed cause would be overclaiming.
- **Inferred (authored semantics):** rows 60…72 map to the service and commodity
  requirements named by their English and Chinese text. The Native model emits
  exactly those requirement shapes, but the original writers that assign every
  corresponding reason-code ordinal have not yet been recovered.
- **Unknown:**
  - **row 56 triggering cause** — the original reason-code selection feeding
    desirability into rows 56 vs 57 (i.e. the code that detects "nearby
    buildings reduced appeal") was not recovered; the reason-code meaning per
    value came from the row arithmetic and authored text, not from a recovered
    cause classifier. Native therefore never selects row 56.
  - **exact `[food_quality]` substitution source** — the formatter call chain
    and the 1…5 flavor bucket are recovered, but the string that supplies the
    substituted flavor name (which text group/row or other table the
    substitution callback resolves) was not recovered. Native composes the
    authored row 59 by substituting its existing localized
    `ClassicTextLocalization.foodQualityName` for the required `FoodQuality`,
    which is a builder-compatible presentation, not a claim about the original's
    text source.

## 4. Native contract

- `HouseEvolutionRequirement.emperorTextGroup127UpgradeReasonRowIndex` maps
  desirability → 57, food quality → 59, services → 58/60/61/62/63/64/65/66/67,
  commodities → 68/69/70/71/72, and returns `nil` for unsupported shapes
  (`.inspection`/`.constable`/`.tax`, composite or partial commodity sets).
- `OriginalLocalizedTextCatalog.localized(groupID:rowIndex:)` returns the exact
  aligned Chinese row, `nil` for groups/rows not proven aligned.
- `ClassicTextLocalization.housingEvolutionReason` substitutes
  `[food_quality]` **only** for the food requirement and falls back to the exact
  authored group-127 Chinese rows when GameData is absent. It appends no
  current/required diagnostics.
