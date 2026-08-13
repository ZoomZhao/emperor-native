# Population advisor housing-capacity and migration text (`EmperorText` group 55 rows 8/9/12/13/20)

Read-only evidence for the residential (population) advisor's housing-capacity
line and migration-status region in the right control panel. The Native
composition "prefix + capacity + suffix" consumes two authored rows
(8/9) from `GameData/EmperorText.txt`, and the migration region consumes the
three authored rows 12/13/20; no invented fallback prose is allowed.

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
- Both groups contain exactly 36 rows. Only the target rows **8/9/12/13/20**
  were directly compared and are semantically aligned across the two shipped
  tables (`localized(groupID: 55, rowIndex: 8/9/12/13/20)`); the remaining rows
  were not individually compared. No claim of full row-by-row semantic
  alignment is made.

Relevant rows (zero-based):

| row | Chinese (authored) | English (authored) | meaning |
| --- | --- | --- | --- |
| 8 | `目前住宅还可容纳` | `Housing for` | capacity sentence prefix (numeric capacity sits between 8 and 9) |
| 9 | `人居住` | `more people.` | capacity sentence suffix |
| 12 | `移民受到限制.原因是:` | `Immigration limited by` | migration restriction lead (the shipping Chinese keeps an ASCII full stop before, and an ASCII colon after, `原因是`) |
| 13 | `缺乏住房` | `lack of housing vacancies.` | migration restriction reason (housing shortage) |
| 20 | `人们希望迁居你的城市` | `People wish to come to the city.` | migration wish line |

The surrounding rows are supporting context only and confirm the intended
cluster: row 7 is `贵族`/`Nobles` (population history subdivision), rows 10/11
are the newcomer phrases (`个新移民本月到达` / `newcomer(s) arrived this month.`),
and row 14 is `工资太低`/`low Wages.` (an unverified alternative restriction
reason). None of rows 7/10/14 are claimed as independently verified alignment
evidence and none is authorized for row lookup.

## 2. Executable context

- No reference to the English row strings (`Housing for`, `more people`,
  `Immigration limited by`, `lack of housing vacancies`,
  `People wish to come to the city`) was found in
  `local/source/split-merged/strings-index.csv`, `functions-index.csv`,
  or any decompiled function in the corpus (negative search, 2026-08-14).
- Consequently **no draw-call function, group-table load, branching, or layout
  constant that consumes group 55 rows 8/9/12/13/20 was recovered**. The
  original executable's consumer, draw implementation, which assessment states
  map to the wish line versus the restriction block, and precise
  font/color/coordinate constants all remain `unknown`; the player-visible
  composition is independently confirmed by the screenshot in section 3.
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
  3. group 55 row 9 suffix `人居住` centered on a following line;
  4. the migration **wish** `人们希望迁居你的城市` on a separate normal-color
     line below;
  5. the migration **restriction block** below that: lead `移民受到限制.原因是:`
     on its own line, then the gold/warning reason `缺乏住房`.
- The migration wish and restriction-reason areas are separate rows *below* the
  capacity sentence; they are not merged into or attached to the
  prefix/value/suffix lines, and the wish and the restriction render
  simultaneously at zero free capacity.
- Horizontal separators are drawn between the advisor's two action buttons and
  the summary region, **between the capacity sentence and the migration wish**,
  and **between the wish and the restriction block** (screenshot-confirmed;
  see section 5). Their presence and positions are confirmed; their exact
  thickness, color, and padding are not recovered original constants.
- Evidence class: the visible composition, the line order (capacity three lines
  → normal-color wish line → restriction lead + gold/warning reason), the three
  separator positions listed above, and the gold numeric emphasis are
  `confirmed` by this screenshot. The exact state
  branch that produced the simultaneous wish+restriction (zero capacity before
  an assessment, or an `.noEligibleHousing` assessment) is **not** recovered
  from the executable; the screenshot alone does not reveal the mapping for
  negative treasury, high unemployment, or stable populations. No exact font
  metrics, color values, or pixel coordinates are claimed beyond the existing
  fixed panel geometry (`control-panel-width` 224px, `panel-content-width`
  170px, `population-advisor-height` 280px). The original executable's
  separator draw calls, their branch/control flow, and their exact layout
  constants remain `unknown`.

## 4. Native verification (visual)

- Capture: `tmp/ui-smoke-qin1/qin-m1-native-city-baseline.png` — a `2048 × 1600`
  window capture containing `1024 × 768` logical content (2×), from the Native
  Qin-1 baseline city. This path is gitignored development output; it is not
  committed and is not a dependency of any code or test.
- Computer Use accessibility (AX) read of the combined advisor text:
  `目前住宅还可容纳 0 人居住 人们希望迁居你的城市 移民受到限制.原因是: 缺乏住房` — the
  capacity sentence (`目前住宅还可容纳` + `0` + `人居住`) is followed by the separate
  wish line and then the migration-restriction block (`移民受到限制.原因是:` +
  `缺乏住房`), all using the authored row punctuation verbatim.
- The Qin-1 UI smoke (`scripts/qin1-ui-smoke.sh`) now asserts the five authored
  text rows plus the numeric `0` against the `advisor-population-panel` AX
  descendants (recursively collected `AXValue`/`AXDescription`/`AXTitle`,
  whitespace normalized) before the baseline capture, and requires the unsupported tokens
  (`等待下一个模拟日评估迁入条件`, `缺乏临路住房`, `国库为负`, `失业率过高`) to stay absent. It
  also asserts the panel AX frame width stays `<= 224`. This verifies the
  separator layout does not widen the fixed panel.
- Visual inspection matches the three-line capacity composition, the three
  screenshot-confirmed separators, and the separate wish + restriction rows
  without widening the `224px` control panel.

## 5. Evidence classification

- **Confirmed (authored data):** `EmperorText.eng` group 55 rows 8 = `Housing
  for`, 9 = `more people.`, 12 = `Immigration limited by`, 13 = `lack of
  housing vacancies.`, 20 = `People wish to come to the city.`;
  `EmperorText.txt` group 55 rows 8 = `目前住宅还可容纳`, 9 = `人居住`, 12 =
  `移民受到限制.原因是:`, 13 = `缺乏住房`, 20 = `人们希望迁居你的城市`. Both groups
  contain exactly 36 rows, and target rows 8/9/12/13/20 were directly compared
  and are semantically aligned (surrounding rows 7, 10, 11, 14 provide
  supporting context only). The remaining rows were not compared; no claim of
  full row-by-row alignment is made.
- **Confirmed (runtime screenshot):** at zero free capacity the Chinese
  residential/population advisor renders the row 8 prefix centered on its own
  line, a **gold `0`** centered on the next line, the row 9 suffix centered
  below, then the normal-color wish `人们希望迁居你的城市` on its own line, then the
  restriction block (`移民受到限制.原因是:` lead + gold/warning `缺乏住房` reason).
  Horizontal separators appear after the two action buttons, between the
  capacity sentence and the wish, and between the wish and the restriction
  block. This composition, line order, separator positions, and gold numeric
  emphasis are confirmed by
  `capcap-260724-160610.png`; the original executable's separator branch and
  exact font/color/coordinate constants are not recovered and remain
  `unknown`, and no values beyond the existing fixed panel geometry are
  claimed. Native matches the composition without widening the `224px` panel
  (verified by the Qin-1 AX smoke described in section 4).
- **Unknown (control flow):** the original executable consumer, data-group
  usage, draw implementation, assessment-state → text mapping, branching, and
  precise layout constants were not recovered from `local/source`; negative
  search results are recorded above. The screenshot confirms the zero-capacity
  composition but not the mapping for negative treasury, high unemployment,
  stable/zero planned immigration, or a nil assessment with positive capacity;
  those cases are therefore unsupported and must fail closed in Native. This
  does not weaken the screenshot-confirmed visible composition.

## 6. Native contract

- `OriginalLocalizedTextCatalog` authorizes row-index lookup per confirmed
  row, not per whole group: group `127` remains a fully aligned group exposing
  every equal-count row, while group `55` exposes only the recorded rows
  `8/9/12/13/20`. Row-index lookup remains fail-closed:
  `localized(groupID:rowIndex:)` returns `nil` for any other group, any
  unrecorded row (including group 55 rows 7, 10, 14 and every other
  non-target index), negative indices, and out-of-bounds indices.
- `ClassicTextLocalization.housingCapacityLegend` returns a
  `(prefix: "目前住宅还可容纳", suffix: "人居住")` only when both runtime rows
  exist and are nonempty; otherwise `nil`. There is no hardcoded or invented
  fallback sentence.
- `ClassicTextLocalization.migrationStatusText` returns the typed tuple
  (wish: `人们希望迁居你的城市`, restrictionLead: `移民受到限制.原因是:`,
  restrictionReason: `缺乏住房`) only when all three runtime rows exist and are
  nonempty; otherwise `nil`. There is no invented or hardcoded fallback, and
  unverified reason rows (for example the group 55 low-wages row) are never
  mapped.
- `ClassicCategoryAdvisorPanel` (residential) composes the capacity row as
  prefix / capacity metric / suffix, keeping the existing gold metric emphasis
  on `availableHousingCapacity`. When the legend is `nil`, only that row is
  omitted. The migration region renders:
  - zero capacity before the first assessment, or an `.noEligibleHousing`
    assessment: wish line **and** restriction block together;
  - an assessment with `plannedImmigrants > 0`: wish line only;
  - negative treasury, high unemployment, stable/zero planned immigration, and
    a nil assessment with positive capacity: **no migration line** (the exact
    original branch/text mapping is unsupported and fails closed).
  Summary rows are semantic (`housingCapacity` / `migrationWish` /
  `migrationRestriction` / `text`) rather than array-index positions. The
  summary inserts a semantic `separator` row only between consecutive content
  rows, so the residential ordering is capacity / separator / wish /
  separator / restriction at zero capacity (pre-assessment or
  `.noEligibleHousing`), capacity / separator / wish for a supported
  `plannedImmigrants > 0` assessment, and no trailing separators; the
  separator renders as the same one-pixel
  `EmperorTheme.secondary.opacity(0.68)` hairline with `1`pt vertical padding
  already used after the action buttons. No other category changes.
