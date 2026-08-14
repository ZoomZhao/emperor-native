# Population advisor housing-capacity and migration text (`EmperorText` group 55 rows 8/9/10/12/13/20)

Read-only evidence for the residential (population) advisor's housing-capacity
line and migration-status region in the right control panel. The Native
composition "prefix + capacity + suffix" consumes two authored rows
(8/9) from `GameData/EmperorText.txt`, and the migration region consumes the
three authored rows 12/13/20; group-55 row 10 remains catalog-authorized and
renderer-confirmed but is **no longer selected by Native** (see section 7 for
the correction and the superseded `currentMonthImmigrants > 4` UI contract).
No invented fallback prose is allowed.

Binaries: `Emperor[EN].exe` (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`,
the canonical `1024 × 768` build) and `Emperor[CH].exe`
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, repacked
widescreen variant). An initial pass recovered no static consumer, and the
executable context below was corpus identity only; that provisional statement
is **superseded** by the wrapper-discovered consumer in section 2.2
(`FUN_0053b850` @ `0x53B850`, reached from `FUN_0053ab80` @ `0x53AB80`), while
the audit trail of the earlier searches is preserved in sections 2 and 2.1.

## 1. Authored data (evidence class: confirmed)

- `GameData/EmperorText.eng` group **55** has exactly **36 rows** under the
  group-table parse used by `OriginalLocalizedTextCatalog` (record at
  `0x20 + 55 × 8`, string offsets relative to `28 + 1000 × 8`).
- `GameData/EmperorText.txt` (GB 18030) group 55 has exactly **36 rows** by the
  `//----` group-separator parse.
- Both groups contain exactly 36 rows. Only the target rows **8/9/10/12/13/20**
  were directly compared and are semantically aligned across the two shipped
  tables (`localized(groupID: 55, rowIndex: 8/9/10/12/13/20)`); the remaining rows
  were not individually compared. No claim of full row-by-row semantic
  alignment is made.

Relevant rows (zero-based):

| row | Chinese (authored) | English (authored) | meaning |
| --- | --- | --- | --- |
| 8 | `目前住宅还可容纳` | `Housing for` | capacity sentence prefix (numeric capacity sits between 8 and 9) |
| 9 | `人居住` | `more people.` | capacity sentence suffix |
| 10 | `个新移民本月到达` | `newcomers arrived this month.` | newcomer-count suffix (plural; count drawn before this row) |
| 12 | `移民受到限制.原因是:` | `Immigration limited by` | migration restriction lead (the shipping Chinese keeps an ASCII full stop before, and an ASCII colon after, `原因是`) |
| 13 | `缺乏住房` | `lack of housing vacancies.` | migration restriction reason (housing shortage) |
| 20 | `人们希望迁居你的城市` | `People wish to come to the city.` | migration wish line |

The surrounding rows are supporting context only and confirm the intended
cluster: row 7 is `贵族`/`Nobles` (population history subdivision), row 11 is
`个新移民本月到达`/`newcomer arrived this month.` (the singular variant, whose
selection occurs when signed pressure is positive and the assigned/accounted
monthly count equals 1; it is **not** authorized for row lookup because that
row pair was not included in the direct alignment audit), and row 14 is
`工资太低`/`low Wages.` (an
unverified alternative restriction reason). Row 10 was directly compared (its
authored Chinese `个新移民本月到达` and English `newcomers arrived this month.`
are exact) and is authorized; rows 7/11/14 are not.

## 2. Executable context

- No reference to the English row strings (`Housing for`, `more people`,
  `newcomers arrived this month.`, `Immigration limited by`, `lack of housing
  vacancies`, `People wish to come to the city`) was found in
  `local/source/split-merged/strings-index.csv`, `functions-index.csv`,
  or any decompiled function in the corpus (negative search, 2026-08-14).
- The initial pass **recovered no draw-call function, group-table load,
  branching, or layout constant that consumes group 55 rows 8/9/12/13/20
  (later including row 10)**.
  That temporary conclusion is **superseded** by section 2.2, which recovers
  the consumer (`FUN_0053b850` @ `0x53B850`), the draw implementation, and the
  assessment-state → text mapping; only precise font/color/coordinate
  constants remain `unknown`. The player-visible composition is independently
  confirmed by the screenshot in section 3.
- The original caveat that "the doc must not be read as evidence that group 55
  is executable-linked" belonged to that no-consumer pass; the rows are used by
  Native because they are authored, semantically aligned player text, and are
  additionally now demonstrably consumed by the recovered control flow in
  section 2.2.

### 2.1 Bounded negative static search: group 55 rows 10-35 (2026-08-14)

- Bounded search targets: text lookup `FUN_005278b0` @ `0x5278B0` and draw
  helper `FUN_00528CC0` @ `0x528CC0` in the `local/source/split-merged/`
  corpus.
- A clean full-corpus call-line filter found **no literal group first argument
  `0x37` (decimal 55) to either helper**. An initial `grep -n` attempt was
  invalid because the line-number prefix `55` contaminated the matches and was
  discarded.
- Intersecting callee files that contain a literal `0x37` produced
  `FUN_005A3430` and `FUN_00486E10`, but inspection showed both are **false
  positives**: `0x5A3430` uses a case/building-type `0x37` and text groups
  `0x17`/`0x1C`/`0x81`; `0x486E10` uses text group `0x29` with a row sweep
  roughly 7-22.
- Under this bounded literal-helper filter, selection/control flow for group
  55 rows 10-35 remained `unknown`, and **no additional row mapping/behavior
  was authorized from that result**. That sentence was the temporary conclusion
  of the literal-helper search only and is **superseded** by the wrapper
  discovery in section 2.2: the filter examined literal `0x37` first arguments
  to `FUN_005278b0`/`FUN_00528CC0`, but the actual group-55 consumers are
  `FUN_00528890` (row text), `FUN_00528d00` (status/detail text), and
  `FUN_00528b80` (numeric values), which that filter never tested. The audit
  trail above (discarded `grep` contamination, false-positive pair inspection)
  is retained, not erased.
- Narrow next experiment: direct xref/disassembly of the hash-identified
  executable around the text-table group-offset table, or a runtime
  watchpoint on group-55 retrieval, because decompiler symbol recovery may
  have hidden/corrupted call shapes.
- The confirmed screenshot contract (section 3) is **unchanged**. The absence
  of a literal call does **not** prove the original never uses group 55.

### 2.2 Wrapper-discovered consumer: `FUN_0053b850` @ `0x53B850` (2026-08-14)

This subsection **supersedes the temporary conclusion** of section 2.1 (and
the "no consumer / no draw-call function" statements in section 2 and the file
banner). That earlier result was a bounded literal-helper finding, not a
demonstration that group 55 has no executable consumer.

- Discovery: a direct wrapper scan of the corpus found `FUN_0053b850` @
  `0x53B850`, reached from `FUN_0053ab80` @ `0x53AB80` (the population-advisor
  renderer). It is the executable draw consumer of the documented text. The
  actual group-55 consumer helpers are `FUN_00528890` (row text),
  `FUN_00528d00` (status/detail text), and `FUN_00528b80` (numeric values);
  the section 2.1 filter never targeted these helpers, which is why the
  literal `0x37` sweep came up empty. The two false-positive pairs
  (`FUN_005A3430`, `FUN_00486E10`) remain unrelated, and the discarded `grep`
  contamination finding stands.
- Fixed preamble (always runs): `FUN_00528890(0x37, 8, …)` draws the capacity
  prefix, the numeric value **`max(0, DAT_0130F998)`** is drawn via
  `FUN_00528b80` (the decompiled expression
  `((DAT_0130F998 < 0) - 1) & DAT_0130F998` evaluates to the field itself when
  nonnegative and to zero when negative), and
  `FUN_00528890(0x37, 9, …)` draws the suffix. Group 55 rows 8/9 therefore
  bracket a gold numeric capacity exactly as section 3 observes.
- Status line and optional detail: `FUN_00528d00(0x37, status, …)` draws the
  group-55 status row (row 20 is the documented wish line; rows 21-23 are the
  other status rows, not individually compared in section 1). When a branch
  keeps `flag == true`, a group-55 row 12 lead is drawn before the detail,
  followed by the detail `ret2` from `FUN_00528d00`; the newcomer count is
  drawn by `FUN_00528b80` on the numeric-value path (`n4`). In that path the
  number uses `y = DAT_010C73D4 + n2`, while the row-10/11 suffix uses
  `y = DAT_010C73D4 + 0x10 + n2`: they are vertically stacked on separate
  lines, not concatenated horizontally.
- **Decision table** for status + detail (mode `DAT_01311fd0`; field names are
  corpus heuristics — see field notes below):

  | branch | predicate | status | detail / count |
  | --- | --- | --- | --- |
  | mode 0 (1st) | `DAT_01312564 > 3` | 21 (`0x15`) | group 61 (`0x3d`) row 52 (`0x34`); no group-55 row-12 lead (`flag = false`) |
  | mode 0 (2nd) | newcomer count `DAT_01311FCC > 4` | 20 (`0x14`) | numeric count `DAT_01311FCC`; row 10 |
  | mode 0 (3rd) | housing capacity `DAT_0130F998 < 1` | 20 | row 12 lead + row 13 (housing reason) |
  | mode 0 (4th) | signed pressure `DAT_01311FBC > 0` | 20 | numeric count `DAT_01311FCC`; row 11 when count == 1 else row 10 (`ret2 = 0xb - (uint)(count != 1)`) |
  | mode 0 (5th) | pressure `DAT_01311FBC < 0` | 21 | row 12 lead + reason from `FUN_0053b790` |
  | mode 0 (else) | pressure `DAT_01311FBC == 0` | 22 (`0x16`) | — |
  | mode 1 | `DAT_01311fd0 == 1` | 21 | row 12 lead + reason from `FUN_0053b790` |
  | mode 2 | `DAT_01311fd0 == 2` | 22 | — |
  | other mode | any other value | 23 (`0x17`) | — |

  Statuses are drawn as group-55 rows (20/21/22/23). The zero-capacity
  screenshot (section 3) corresponds to the mode-0 branch `DAT_0130F998 < 1`
  (status 20 wish + row 12 lead + row 13 `缺乏住房`).
- **Reason selector `FUN_0053b790`** (switch on `DAT_01312484`): predicate
  `c` from the paired `FUN_0053b7xx`; `false` (c == 0) selects the *current*
  reason row, `true` (c != 0) the *past* reason row:

  | selector | predicate fn | current (false) | past (true) |
  | --- | --- | --- | --- |
  | 1 food | `FUN_0053b760` | 16 (`0x10`) | 29 (`0x1d`) |
  | 2 unemployment | `FUN_0053b780` | 15 (`0x0f`) | 30 (`0x1e`) |
  | 3 taxes | `FUN_0053b700` | 17 (`0x11`) | 25 (`0x19`) |
  | 4 wages | `FUN_0053b710` | 14 (`0x0e`) | 26 (`0x1a`) |
  | 5 debt | `FUN_0053b750` | 18 (`0x12`) | 27 (`0x1b`) |
  | 6 festivals | `FUN_0053b730` | 19 (`0x13`) | 28 (`0x1c`) |
  | 7 feng shui | `FUN_0053b720` | 33 (`0x21`) | 31 (`0x1f`) |
  | 8 despotism | `FUN_0053b740` | 34 (`0x22`) | 32 (`0x20`) |
  | default | — | 24 (`0x18`) | — |

  Corroboration: selector-4 wages *current* selects row 14, whose authored
  tables contain `工资太低` / `low Wages.`. This recovers row selection but does
  not by itself authorize row-index lookup or Native rendering; those remain
  fail-closed until the row pair and its simulation producer are separately
  recorded as supported evidence.
- Field notes: `DAT_0130f998` (housing capacity — Native
  `availableHousingCapacity`, exactly representable) is the only renderer input
  with an equivalent Native producer. `DAT_01311fcc` is the original successfully
  housed monthly newcomer count; Native's similarly named
  `currentMonthImmigrants` does not have the same producer or cadence and is not
  an equivalent input. `plannedImmigrants` is **not** an input to
  this renderer: no recovered branch consumes it. The other fields (mode
  `DAT_01311fd0`, signed pressure `DAT_01311fbc`, `DAT_01312564`, selector
  `DAT_01312484`) have recovered *selection* semantics only; their producer
  meanings are `inferred` from corpus heuristic naming, not independently
  source-mapped.
- Separator candidates: `FUN_005bf250(DAT_013f8e0c + 0x3c, …, 10)` is called
  twice — after the status line (y `i + 0x6a`) and again before the
  detail/count region (y `i + 0xae`) — matching section 3's two separators in
  the migration region. Role is `inferred`; exact thickness/color/padding
  remain `unknown`.

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
  branch that produced the simultaneous wish+restriction is now matched by the
  recovered mode-0 branch `DAT_0130F998 < 1` (status 20 wish + row 12 lead +
  row 13 housing reason, section 2.2); the screenshot's zero-capacity state
  satisfies that predicate purely through `availableHousingCapacity < 1`, and
  the earlier `.noEligibleHousing`/pre-assessment reading is **superseded**:
  the Native implementation selects this branch by capacity alone and never by
  `lastAssessment.blockReason`. The newcomer branches (`DAT_01311FCC > 4` →
  status 20 + numeric count + row 10; and the signed-pressure row 11/10 branch
  for counts 1-4) appear in the section 2.2 decision table but are not shown
  in this capture, and the pressure-equivalence fields are not yet
  source-mapped. No
  exact font metrics, color values, or pixel coordinates are claimed beyond the
  existing fixed panel geometry (`control-panel-width` 224px,
  `panel-content-width` 170px, `population-advisor-height` 280px). The
  original executable's candidate separator draws (`FUN_005bf250`, section
  2.2) are `inferred`; their branch/control flow and exact layout
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
- The Qin-1 UI smoke (`scripts/qin1-ui-smoke.sh`) asserts the five authored
  text rows 8/12/13/20 plus the numeric `0` against the `advisor-population-panel` AX
  descendants (recursively collected `AXValue`/`AXDescription`/`AXTitle`,
  whitespace normalized) before the baseline capture, and requires the unsupported tokens
  (`等待下一个模拟日评估迁入条件`, `缺乏临路住房`, `国库为负`, `失业率过高`, plus the
  research-confirmed but intentionally unselected newcomer suffix
  `个新移民本月到达`) to stay absent. The baseline is taken at zero free capacity
  (`availableHousingCapacity < 1`), so the only selected branch is the
  screenshot-confirmed wish + restriction block; the row-10 suffix must be
  absent because Native deliberately keeps it unselected until the original
  `DAT_01311FCC` producer is implemented (see section 7), and a wrong priority
  or leaked state would render it and be detected by both token sets. The smoke
  also asserts the panel AX frame width stays `<= 224`. This verifies the
  separator layout does not widen the fixed panel.
- Visual inspection matches the three-line capacity composition, the three
  screenshot-confirmed separators, and the separate wish + restriction rows
  without widening the `224px` control panel.

## 5. Evidence classification

- **Confirmed (authored data):** `EmperorText.eng` group 55 rows 8 = `Housing
  for`, 9 = `more people.`, 10 = `newcomers arrived this month.`, 12 =
  `Immigration limited by`, 13 = `lack of housing vacancies.`, 20 = `People
  wish to come to the city.`;
  `EmperorText.txt` group 55 rows 8 = `目前住宅还可容纳`, 9 = `人居住`, 10 =
  `个新移民本月到达`, 12 =
  `移民受到限制.原因是:`, 13 = `缺乏住房`, 20 = `人们希望迁居你的城市`. Both groups
  contain exactly 36 rows, and target rows 8/9/10/12/13/20 were directly compared
  and are semantically aligned (surrounding rows 7, 11, 14 provide
  supporting context only; row 11's Chinese duplicates row 10 while its
  English is the singular `newcomer arrived this month.`, and it stays
  unauthorized). The remaining rows were not compared; no claim of
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
  `capcap-260724-160610.png`; the original executable's exact separator layout
  and font/color/coordinate constants are not recovered and remain `unknown`,
  and no values beyond the existing fixed panel geometry are
  claimed. Native matches the composition without widening the `224px` panel
  (verified by the Qin-1 AX smoke described in section 4).
- **Recovered (control flow):** the original executable consumer, draw
  implementation, branching, and assessment-state → text mapping for group 55
  rows 8/9, the status rows 20-23, the row 12 lead, row 13, and the
  reason-selector rows are recovered in `FUN_0053b850` @ `0x53B850` (reached
  from `FUN_0053ab80` @ `0x53AB80`); the exact decision table is section 2.2,
  which supersedes the earlier negative-search conclusion while the audit
  trail stands. The zero-capacity composition is the mode-0 branch
  `DAT_0130F998 < 1`.
- **Unknown (remaining):** the writer and semantics of mode `DAT_01311fd0`, the
  full military/runtime lifecycle behind `DAT_01312564`, the equivalent Native
  popularity/factor producer, and the exact font/color/coordinate and separator
  layout constants remain `unknown`. Signed pressure `DAT_01311fbc`, the
  newcomer count, and selector `DAT_01312484` have the partially recovered
  producer chains classified in section 7. Until those simulation fields are
  implemented with equivalent producers, only the
  section-6 contract rows are supported in Native; all other recovered
  branches fail closed. This does not weaken the screenshot-confirmed visible
  composition.
- **Corrected (2026-08-14):** the earlier Native UI selection of the
  `currentMonthImmigrants > 4` wish + numeric count + row-10 suffix branch is
  **superseded** (section 7): Native's custom daily max-5 / `population >= 150`
  block model is not an equivalent producer for `DAT_01311FCC`, so the branch
  and `AdvisorSummaryLine.newcomerCount` are removed from the player UI and
  `migrationStatusText` consumes rows 12/13/20 only. Group-55 row 10 alignment
  and renderer use remain `confirmed`; only its Native UI selection is revoked.

## 6. Native contract

- `OriginalLocalizedTextCatalog` authorizes row-index lookup per confirmed
  row, not per whole group: group `127` remains a fully aligned group exposing
  every equal-count row, while group `55` exposes only the recorded rows
  `8/9/10/12/13/20`. Row-index lookup remains fail-closed:
  `localized(groupID:rowIndex:)` returns `nil` for any other group, any
  unrecorded row (including group 55 rows 7, 11, 14 and every other
  non-target index), negative indices, and out-of-bounds indices. Row 11 stays
  unauthorized because its CH/EN pair was not directly included in the row
  alignment audit; it is never selected by pressure guesswork.
  Row 10 stays catalog-authorized (its alignment is confirmed and the
  `FUN_00528b80` numeric + row-10 renderer path is recovered) but is
  deliberately not read by `migrationStatusText`.
- `ClassicTextLocalization.housingCapacityLegend` returns a
  `(prefix: "目前住宅还可容纳", suffix: "人居住")` only when both runtime rows
  exist and are nonempty; otherwise `nil`. There is no hardcoded or invented
  fallback sentence.
- `ClassicTextLocalization.migrationStatusText` returns the typed tuple
  (wish: `人们希望迁居你的城市`, restrictionLead: `移民受到限制.原因是:`,
  restrictionReason: `缺乏住房`) only when all three runtime rows exist and are
  nonempty; otherwise `nil` (no fallback). Unverified reason rows (for example
  the group 55 low-wages row 14, or the duplicated singular row 11) are never
  mapped. This supersedes the former four-row tuple that read group-55 row 10.
- `ClassicCategoryAdvisorPanel` (residential) composes the capacity row as
  prefix / capacity metric / suffix, keeping the existing gold metric emphasis
  on `availableHousingCapacity`. When the legend is `nil`, only that row is
  omitted. The migration region renders **only** the screenshot-confirmed
  mode-0 zero-housing branch from `FUN_0053b850` (section 2.2), in its original
  checker position (the zero-capacity predicate is the third mode-0 check, so a
  previous branch must not mask it):
  1. `availableHousingCapacity < 1` (mode-0 branch `DAT_0130F998 < 1`):
     status-20 wish line, then the restriction block (row-12 lead `移民受到限制.原因是:`
     + gold/warning row-13 `缺乏住房`);
  2. else **(no migration rows)** — every other state (any newcomer count,
     negative treasury, high unemployment, stable/zero immigration, positive
     capacity, modes 1/2/other) renders no migration line.
  The predicate depends only on `availableHousingCapacity < 1` and never on a
  row-10 suffix being present.
- The former `city.migration.currentMonthImmigrants > 4` newcomer-count block
  is **removed from the player UI and superseded** (see section 7): Native's
  custom daily max-5 / `population >= 150` block model cannot reproduce the
  original `DAT_01311FCC` producer, so that branch and the other recovered
  renderer branches (`DAT_01312564 > 3`, signed pressure `DAT_01311FBC > 0` /
  `< 0` / `== 0`, and the `FUN_0053b790` reason-selector families) remain
  research-only and fail closed until a source-mapped producer exists.
- `lastAssessment.blockReason`, `.noEligibleHousing`, and `plannedImmigrants`
  **never select a player-visible row**. The zero-capacity trigger is the
  capacity-only predicate `availableHousingCapacity < 1`, and the former
  `plannedImmigrants > 0` wish-only path is **removed**: `plannedImmigrants`
  is not an input to `FUN_0053b850`. The supported branch input maps exactly to
  a recoverable field (`DAT_0130f998` ↔ `availableHousingCapacity`).
  Summary lines are semantic (`housingCapacity` / `migrationWish` /
  `migrationRestriction` / `text`) rather than array-index positions. The
  summary inserts a semantic `separator` row only between consecutive content
  rows, so the residential ordering is capacity / separator / wish / separator
  / restriction when `availableHousingCapacity < 1` and capacity alone
  otherwise, with no trailing separators; the separator renders as the same
  one-pixel `EmperorTheme.secondary.opacity(0.68)` hairline with `1`pt vertical
  padding already used after the action buttons. No other category changes.
- Contract status: the corrected contract is **implemented** — the
  `currentMonthImmigrants > 4` branch is dropped from the player UI,
  `AdvisorSummaryLine.newcomerCount` and its renderer are removed as unused,
  and `migrationStatusText` consumes rows 12/13/20 only. This **supersedes** the
  earlier row-10 UI selection contract (implemented in the file's prior commit
  and recorded as history above) because Native's custom daily max-5 /
  `population >= 150` block model is not an equivalent producer for
  `DAT_01311FCC`. Do not select the row-10/11 block until Native reproduces the
  original persisted popularity and migration producer.

## 7. Partial migration producer recovery and Native correction (2026-08-14)

This section records a partial recovery of the migration producer that
feeds the status region, and the reason the earlier row-10 Native UI
selection is superseded. It is not a fully recovered producer chain.
Binaries are those in the file banner: `Emperor[EN].exe`
(`8a6d2df1…6753`, canonical build) and `Emperor[CH].exe` (`dbdeca1e…15a`,
repacked widescreen variant). Per `local/source/compare-report.tsv`, the CH/EN functions
named here are identical; no CH/EN divergence changes these statements.

### 7.1 Popularity and migration pressure (producer input)

| recoverable fact | value / formula | evidence class |
| --- | --- | --- |
| popularity `DAT_0130F974` | init 60; clamped to 0…100 | confirmed (static control flow) |
| `FUN_005917E0` pressure bands | `<16` → -25; `16…25` → -17; `26…35` → -8; `36…49` → 0; `50…60` → 50; `61…70` → 75; `>=71` → 100 | confirmed (static control flow) |
| population suppression | `> 199999` population → zero pressure | confirmed (static control flow) |
| war suppression | war counter `>= 4` suppresses positive pressure | confirmed (static control flow) |

These facts produce *requested* arrivals or departures, not the assigned/
accounted spawn count displayed by the renderer. The link is direct:
`FUN_005917E0` calls `FUN_0059A1B0(12, abs(pressure))`, whose callee
`FUN_0043B860` performs the integer ceiling recorded below.

### 7.2 Request cadence and calendar consumption

| recoverable fact | value / formula | evidence class |
| --- | --- | --- |
| request amount | `ceil(12 * abs(pressure) / 100)` | confirmed (static control flow) |
| request cooldown | 2 calendar cycles between requests | confirmed (static control flow) |
| calendar case `0x17` | `FUN_004AD4A0` handles arrivals/departures | confirmed (static control flow) |
| renderer count | `FUN_004ADA10` adds `param_1 - remaining` to `DAT_01311FB0`, then accumulates that value into `DAT_01311FCC`; `FUN_0053B850` displays `DAT_01311FCC`. Remaining request `i` is decremented around each `FUN_004ADE10` call without checking `FUN_004EA050` spawn success, so these are assigned/accounted counts, not proven successfully spawned figure counts | confirmed (static control flow) |
| departures | `FUN_004AD4A0` sends a negative-pressure request through the separate `FUN_004ADC90` departure path; it does not subtract that count from `DAT_01311FCC` | confirmed (static control flow) |
| month rollover | `FUN_004AC650` copies `DAT_01311FCC` to `DAT_01312604`, then resets `DAT_01311FCC` to zero | confirmed (static control flow) |

### 7.3 Why the Native producer is not equivalent (correction status)

- The former Native `DeterministicMigration.assess` admitted at most five people
  per day and used population 150, treasury, and unemployment gates. Those
  rules had no authored-data or executable source and have been removed.
- Production migration is now explicitly
  `AutomaticMigrationAvailability.unsupportedOriginalProducer`. Each tick only
  observes road-adjacent vacant housing through `observeHousing`; planned,
  daily, current-month, and last-month counts remain zero, and no resident is
  admitted or removed. `CitySimulation.admitResidents` remains a loader/test
  fixture primitive and has no production caller.
- A later attempt to fold `FUN_004ADE10` figure-`#11` travel into instant
  occupancy, substitute `lastSuppliedFoodQuality` for `FUN_00590F30`,
  pass monument/war/mode as 0, and upgrade
  `unsupportedOriginalProducer` saves was withdrawn. The food walk
  itself is recovered; `cMarket+0x2c` @ `0x5437B0` is the recovered
  normal market-delivery writer/path of `cHouseInfo+0x36` (complete
  writer set not proven). Current Native food consumption, blending,
  and cadence are confirmed non-isomorphic; the producer of
  `cMarket+0x180` and the correct Native representation/mapping
  remain open. Confirmed
  tables live in
  `docs/exe-research/migration-popularity-producer.md`; they are not a public
  production API, and production ticks do not call them.
- Legacy saves that contain the former count fields still decode. Their values
  are retained at decode time for compatibility, then cleared by the first
  production tick so they cannot be presented as original behavior.
- Native diagnostic migration strips, summary rows, and the count-driven fake
  immigrant figure have been removed. Qin-1/Qin-2 and Xia-1/Xia-2 positive
  player playthroughs that need natural population growth are skipped with
  `BLOCKED BY UNKNOWN`; their migration-independent baseline and negative tests
  still run. Downstream
  subsystem unit tests seed residents explicitly and label that setup as a
  fixture rather than migration evidence.
- Correction: because the consumer requires an equivalent producer, the earlier
  Native UI contract that selected `currentMonthImmigrants > 4` → status-20
  wish + numeric count + row-10 suffix **is superseded**. The branch,
  `AdvisorSummaryLine.newcomerCount`, and its renderer are removed from the
  player UI; `ClassicTextLocalization.migrationStatusText` returns only rows
  wish 20 / lead 12 / reason 13; and the zero-housing branch
  (`availableHousingCapacity < 1` → wish + row 12/13) stays independent of any
  row-10 suffix presence.
- Group-55 row 10 alignment (section 1) and its renderer use (section 2.2,
  `FUN_00528b80` numeric + row-10 suffix at `y = DAT_010C73D4 + 0x10 + n2`)
  remain `confirmed` evidence, and the row index stays catalog-authorized; only
  the Native UI *selection* is revoked pending a source-mapped producer. Row 10
  and all other unmapped renderer branches fail closed, exactly as before.

### 7.4 Remaining unknowns

- Immigrant figure-`#11` arrival write chain after `FUN_004ADE10`
  spawn state `6` through house `+0x20` is recovered in
  `docs/exe-research/migration-popularity-producer.md` §5. Native
  vacant-state / type-switch mapping (`ResidentialUnit` IDs 2/11 and
  walker-arrival `2→3` / `11→13`) remains `unknown`.
- `FUN_00590F30` occupied-house walk is recovered
  (`migration-popularity-producer.md` §3). Authored columns 8 /
  14 / 15 are `EVO_FOOD_QUALITY` / `EVO_CRIME_INC` / `EVO_CRIME_BASE`,
  not food-stock columns. Remaining unknown is the producer of
  `cMarket+0x180` (market / food-shop quality), peddler-vs-buyer
  exclusivity, the complete `cHouseInfo+0x36` writer set, and the
  correct Native representation/mapping of that raw quality byte.
  Current Native `ResidentialUnit` food consumption, blending, and
  cadence are confirmed non-isomorphic, so
  `lastSuppliedFoodQuality` must not be substituted. Do not name
  `house+0x8C` `crimeRisk`.
- `FUN_0055AE30` monument-object matching walk is recovered
  (`migration-popularity-producer.md` §3). Remaining unknown is Native
  mapping of `FUN_00565410` percent, the type-2 object vector,
  `building+0xB4`, and `goal+8` save/load.
- `DAT_01312564` Native mapping. Increment/decrement is `FUN_004EBB40` when
  `FUN_004E2560` accepts figure types `0x3A…0x3E` and `0x4E` (`confirmed`);
  Native military figures do not yet expose that lifecycle.
- `DAT_01311FD0` mode writer — no assignment appears in the decompiled corpus
  searched on 2026-08-14.
- Assignment-eligibility `house+0x24 > 0` is a `confirmed` read on every
  `FUN_004ADA10` pass; its Native semantic mapping remains `unknown` and is
  not equated to road adjacency.
- `DAT_01312484 = min(DAT_01312514, 9)` and the eight selected factor families
  are `confirmed`; Native does not yet reproduce all underlying food,
  unemployment, tax, wage, debt, festival, feng-shui, and despotism inputs with
  the original update cadence, so current/past reason selection remains
  unsupported.
- The pressure bands, request ceiling, arrival/departure split, assigned/
  accounted spawn accounting (`param_1 - remaining` into `DAT_01311FB0` /
  `DAT_01311FCC`, without a `FUN_004EA050` success check), and row-11 singular
  (`DAT_01311FCC == 1`) versus row-10 plural selection are recovered. Their
  Native use remains unsupported because Native vacant-state /
  type-switch mapping and the remaining unmapped factors are absent,
  not because the arrival write chain or those downstream formulas
  are unknown. Every `FUN_004ADA10` assignment pass also requires
  `house+0x24 > 0` (`confirmed` read; Native semantic mapping `unknown`).
- Exact font/color/coordinate and separator layout constants — `unknown`
  (unchanged from section 5); no precise separator geometry is claimed beyond
  existing evidence.

The prior history (sections 2–6, including the negative-search audit trail and
the superseded `currentMonthImmigrants > 4` UI implementation contract) is
preserved above as-is, with only the correction markers and this section
appended.
