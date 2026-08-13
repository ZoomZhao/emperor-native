# Population advisor housing-capacity sentence (`EmperorText` group 55 rows 8/9)

Read-only evidence for the residential (population) advisor's housing-capacity
line in the right control panel. The Native composition "prefix + capacity +
suffix" consumes two authored rows from `GameData/EmperorText.txt`; no invented
fallback prose is allowed.

Binaries: `Emperor[EN].exe` (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`,
the canonical `1024 × 768` build) and `Emperor[CH].exe`
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, repacked
widescreen variant). No static control-flow reference for this text was
recovered in this pass; the executable context below is the corpus identity
only, not a claim that any named function consumes group 55.

## 1. Authored data (evidence class: confirmed)

- `GameData/EmperorText.eng` group **55** has exactly **36 rows** under the
  group-table parse used by `OriginalLocalizedTextCatalog` (record at
  `0x20 + 55 × 8`, string offsets relative to `28 + 1000 × 8`).
- `GameData/EmperorText.txt` (GB 18030) group 55 has exactly **36 rows** by the
  `//----` group-separator parse.
- Both groups contain exactly 36 rows. Only the target rows **8/9** were
  directly compared and are semantically aligned across the two shipped
  tables (`localized(groupID: 55, rowIndex: 8/9)`); the remaining rows were
  not individually compared. No claim of full row-by-row semantic alignment is
  made.

Relevant rows (zero-based):

| row | Chinese (authored) | English (authored) | meaning |
| --- | --- | --- | --- |
| 8 | `目前住宅还可容纳` | `Housing for` | capacity sentence prefix (numeric capacity sits between 8 and 9) |
| 9 | `人居住` | `more people.` | capacity sentence suffix |

The surrounding rows are supporting context only and confirm the intended
sentence: row 7 is `贵族`/`Nobles` (population history subdivision) and rows
10/11 are the newcomer phrases (`个新移民本月到达` / `newcomer arrived this
month.`), reinforcing that row 8/9 are the "Housing for N more people."
legend. They are not claimed as independently verified alignment evidence.

## 2. Executable context

- No reference to the English row strings (`Housing for`, `more people`) was
  found in `local/source/split-merged/strings-index.csv`, `functions-index.csv`,
  or any decompiled function in the corpus (negative search, 2026-08-14).
- Consequently **no draw-call function, group-table load, or layout constant
  that consumes group 55 rows 8/9 was recovered**. The original executable's
  consumer, draw implementation, and precise font/color/coordinate constants
  remain `unknown`; the player-visible composition is independently confirmed
  by the screenshot in section 3.
- The doc must not be read as evidence that group 55 is executable-linked. The
  rows are used by Native because they are authored, semantically aligned
  player text, not because a recovered control-flow path draws them.

## 3. Runtime visual evidence (original screenshot)

- Reference: `/Users/zoomzhao/Downloads/emperor/capcap-260724-160610.png`
  (development-only reference material). Physical
  `2124 × 1680`, containing `1024 × 768` logical game content at an exact
  Retina 2× scale.
- State captured: the Chinese residential (population) advisor at **zero free
  capacity** in the right control panel.
- Visible composition (top to bottom):
  1. `EmperorText` group 55 row 8 prefix `目前住宅还可容纳` centered on its own
     single line;
  2. a **gold `0`** centered on the next line — the numeric-capacity value keeps
     its gold emphasis;
  3. group 55 row 9 suffix `人居住` centered on a following line.
- The **migration wish** and **restriction-reason** areas remain as separate
  rows *below* the capacity sentence; they are not merged into or attached to
  the prefix/value/suffix lines.
- Evidence class: the visible composition, the line order (prefix line → gold
  value line → suffix line), and the gold numeric emphasis are `confirmed` by
  this screenshot. No exact font metrics, color values, or pixel coordinates
  are claimed beyond the existing fixed panel geometry (`control-panel-width`
  224px, `panel-content-width` 170px, `population-advisor-height` 280px).

## 4. Native verification (visual)

- Capture: `tmp/ui-smoke-qin1/qin-m1-native-city-baseline.png` — a `2048 × 1600`
  window capture containing `1024 × 768` logical content (2×), from the Native
  Qin-1 baseline city. This path is gitignored development output; it is not
  committed and is not a dependency of any code or test.
- Computer Use accessibility (AX) read of the combined advisor text:
  `目前住宅还可容纳 0 人居住 移民受到限制，原因是： 缺乏住房` — the capacity
  sentence (`目前住宅还可容纳` + `0` + `人居住`) is followed by the separate
  migration-restriction rows (`移民受到限制，原因是：` + `缺乏住房`).
- Visual inspection matches the three-line capacity composition and the
  separate migration rows without widening the `224px` control panel.

## 5. Evidence classification

- **Confirmed (authored data):** `EmperorText.eng` group 55 row 8 = `Housing
  for`, row 9 = `more people.`; `EmperorText.txt` group 55 row 8 =
  `目前住宅还可容纳`, row 9 = `人居住`. Both groups contain exactly 36 rows, and
  target rows 8/9 were directly compared and are semantically aligned
  (surrounding rows 7, 10, 11 provide supporting context). The remaining rows
  were not compared; no claim of full row-by-row alignment is made. The
  capacity sentence is the only usage Native makes of these two rows.
- **Confirmed (runtime screenshot):** at zero free capacity the Chinese
  residential/population advisor renders the row 8 prefix centered on its own
  line, a **gold `0`** centered on the next line, and the row 9 suffix centered
  below; the migration wish and restriction-reason rows remain separate below
  the sentence. This composition, line order, and gold numeric emphasis are
  confirmed by `capcap-260724-160610.png`; exact font metrics, color values, and
  coordinates beyond the existing fixed panel geometry are not claimed. Native
  matches the three-line composition and the separate migration rows without
  widening the `224px` panel.
- **Unknown (control flow):** the original executable consumer, data-group
  usage, draw implementation, and precise layout constants were not recovered
  from `local/source`; negative-search results are recorded above. This does
  not weaken the screenshot-confirmed visible composition.

## 6. Native contract

- `OriginalLocalizedTextCatalog` authorizes row-index lookup per confirmed
  row, not per whole group: group `127` remains a fully aligned group exposing
  every equal-count row, while group `55` exposes only the recorded rows `8/9`.
  Row-index lookup remains fail-closed: `localized(groupID:rowIndex:)` returns
  `nil` for any other group, any unrecorded row (including group 55 rows other
  than 8/9), negative indices, and out-of-bounds indices.
- `ClassicTextLocalization.housingCapacityLegend` returns a
  `(prefix: "目前住宅还可容纳", suffix: "人居住")` only when both runtime rows
  exist and are nonempty; otherwise `nil`. There is no hardcoded or invented
  fallback sentence.
- `ClassicCategoryAdvisorPanel` (residential) composes the capacity row as
  prefix / capacity metric / suffix, keeping the existing gold metric emphasis
  on `availableHousingCapacity`. When the legend is `nil`, only that row is
  omitted and the migration-status rows keep their current typed rendering;
  summary rows are semantic (`housingCapacity` / `migrationStatus` /
  `text`) rather than array-index positions.
