# Migration and popularity producer (`FUN_00591200` / `FUN_004AD4A0`)

Read-only control-flow recovery for automatic immigration. Binaries:
`Emperor[EN].exe` (`8a6d2df1…6753`, canonical) and `Emperor[CH].exe`
(`dbdeca1e…15a`). Named functions are CH/EN identical in
`local/source/compare-report.tsv`.

This note records recovered constants and the remaining blockers. It does
**not** authorize a Native occupancy or automatic-migration producer.
Production stays
`AutomaticMigrationAvailability.unsupportedOriginalProducer`. The
figure-`#11` / type-`0xB` arrival `house+0x20` write is recovered below
(`FUN_004C9FD0` @ `0x4CA265`). War and several
house-field semantics remain unresolved. The `FUN_00590F30` food
walk is recovered in §3. The recovered normal market-delivery
writer/path of `cHouseInfo+0x36` is `cMarket` vtable `+0x2c` @
`0x5437B0` (§3); mill visit `+0x2c` is a `ret 0` stub. The
complete `+0x36` writer set is not proven. Native now matches the
confirmed monthly Dinners draw (`floor(residents × 25 / 100)`); the
remaining market-delivery blending/cadence and raw-quality mapping are
not yet isomorphic to the recovered original, so those fields must not
be treated as a completed Qin contract. The live `cStall+0x260` blend into
`cMarket+0x180` is recovered. Mill-pickup cart `figure+0x13` is
the mill vtable `+0x2E4` selected recipe type-count (§3); that is
not a recovered player-facing quality name and is not Native
`OriginalFoodCatalog.quality(in:)`. Peddler-vs-buyer spawn and
think rows are exclusive; `FUN_004EACD0` / `cMarket+0x2C` is
**not** exclusive to peddlers (§3). Native representation/mapping
remain open, and food stays a fail-closed
producer input. No implementation contract is authorized. The
`FUN_0055AE30`
monument walk is recovered in §3; Native mapping and save
lifecycle are not, so monument stays a fail-closed producer
input. `DAT_01311FD0` is **not**
read by `FUN_005917E0` / `FUN_004AD4A0` or the recovered
assignment/arrival chain (§6); any value of that dword is therefore
not a numeric input to the recovered pressure / request / spawn /
occupancy math. Init-zero and save/load are closed. The gameplay
writer, full value domain, and source of any nonzero state remain
`unknown`, so Native nonzero advisor/overlay modes (1 / 2 / other)
stay unwired. The producer stays fail-closed. Never treat
assigned/accounted `DAT_01311FCC` as an arrival success.

## 1. Calendar cadence (confirmed)

`FUN_004AC2B0` (`0x4AC2B0`) walks `DAT_00C82EF8` through `0…50`. Case
`0x17` calls `FUN_004AD4A0`. After 51 steps the counter resets and
`FUN_004AC650` advances one of 16 sub-month slices. Month length is
`51 × 16 = 816` simulation steps, matching the already recovered canal
clock adapter.

A “2 calendar cycle” cooldown is two **day-ticks** (two case-`0x17`
calls), not two months.

## 2. Popularity (`DAT_0130F974`)

| fact | value | class |
| --- | --- | --- |
| init | `FUN_00590A70` writes `0x3C` (60) | confirmed |
| clamp | `0…100` after each update | confirmed |
| update | `FUN_00591200` at slice `0` and `8` | confirmed |
| per-update sum | `feng + repression + 1 + monument×2 + debt + food + wage + employment + tax` | confirmed |
| `+1` | literal in `0x591200`, not a hero predicate | confirmed |
| monument | `FUN_0055AE30` returns the matching building-goal pair count (each passing `(building, type-2 goal)` pair increments; the same goal may be counted once per matching root; **not** a distinct-goal count); `FUN_00591200` adds that count × 2. Empty list / no match returns `0` (§3) | confirmed |
| festival | excluded from the per-update sum; applied only by `0x48EA40` / `0x48EAF0` | confirmed |

Damping (`FUN_00591200` @ `0x591200`, `confirmed`). Per-update sum `n`
is then biased. Bias `ret6`:

| popularity | bias |
| --- | --- |
| `<11` (`0xB`) | +4 |
| `<21` (`0x15`) | +3 |
| `<31` (`0x1F`) | +2 |
| `<41` (`0x29`) | +1 |
| `<61` (`0x3D`) | 0 |
| `<71` (`0x47`) | −1 |
| `<81` (`0x51`) | −2 |
| `<91` (`0x5B`) | −3 |
| else | −4 |

Exact apply branches (the `flag-1 & (bias+n)` form zeros when `flag` is
true and otherwise keeps `bias+n`; it does **not** fall back to raw `n`
in the damped arm):

- If popularity `<41`: if `n >= 0`, apply raw `n`. If `n < 0`, apply
  `bias+n` unless that sum is `>0` (crosses positive), in which case
  apply `0`.
- Else (popularity `>=41`): if popularity `<61` **or** `n < 0`, apply
  raw `n`. Otherwise (popularity `>=61` and `n >= 0`), apply `bias+n`
  unless that sum is `<0` (crosses negative), in which case apply `0`.

Then `popularity = clamp(popularity + n, 0, 100)`.

Native's `DeterministicMigration.originalPopularityProducerFactors` returns
that clamped write-back value directly.  The live `MigrationState` setter
retains its defensive clamp, but the pure source-boundary helper must also
preserve the executable's final domain when its explicit factor inputs drive
the sum below `0` or above `100`.

## 3. Factor formulas

### Tax (`FUN_00591180`) — confirmed

`EmperorTaxSentimentModel.txt` via `EconomyRulesEngine.taxSentiment`.
`FUN_00408BA0` computes integer coverage as `numerator×100/denominator`, and
`FUN_00591180` requires that truncated value to be at least `11`; therefore
coverage `≤10%` forces the None row (exactly 10% is not meaningful). Native
uses `DeterministicMigration.taxCoverageMeetsOriginalThreshold` for this
cross-product boundary. Negative effects are suppressed
while population `<350` and the city has never exceeded 349
(`DAT_01312575`).
Native monthly settlement reports use the same helper, so their
`taxSentiment` field cannot select a tax band at exactly 10% either.

The nearest-index receiver used by this tax path is a second, distinct
global object, not the wage object below. `0x592CD0` constructs
`DAT_0130F810` with `CRect @ 0x554730` using table `0x85CC8C`, count `7`,
and target pointer `DAT_0131226C`; canonical EN/CH `.data` bytes at
`0x85CC8C` are `[0, 3, 7, 9, 11, 15, 20]`. `FUN_00592CF0` dispatches that
object to the shared `FUN_00592BE0` nearest walk, with strict `<` tie
handling, and `FUN_00591180` consumes the resulting index into the
`DAT_0130F858` five-column table after its `DAT_0131223C >= 11` coverage gate.
The constructor's extra argument `286` is stored at object offset `+0x8` but
is not read by the nearest walk. This confirms the receiver, table, count,
target pointer, and boundary data; it does **not** recover the semantic producer of
`DAT_0131226C` or a Native tax-object projection, so no new live tax wiring is
enabled.

Native now preserves this index-only contract as
`DeterministicMigration.OriginalTaxCoverageIndexCatalog`: it exposes the raw
thresholds, strict nearest-index tie rule, and the `<11` None-row gate under
explicit coverage input. The helper is regression-tested but is not wired to
the unresolved `DAT_0130F858` result table or Qin settlement.

**Sources:** `local/source/split-merged/code/0x050000/CRect.c`,
`FUN_00592BE0.c`, `FUN_00592CF0.c`, `FUN_00591180.c`,
`local/source/compare-report.tsv` rows `0x554730`, `0x592BE0`, `0x592CF0`,
`0x591180`, and raw `.data` bytes at `0x85CC8C` from both canonical hashes.

**Evidence class:** **confirmed** for constructor fields, nearest-walk
ordering/tie behavior, table values, and EN/CH identity; **unknown** for the
semantic producer of `DAT_0131226C` and its Native object projection.

### Tax accumulator writer census — bounded direct-PE result

The corpus gives the accumulator update itself in `FUN_005919F0 @ 0x5919F0`:
when the reason mask contains `0x1000`, the explicit amount is added to
`DAT_01312268`; `FUN_004AE9B0 @ 0x4AE9B0` later snapshots that accumulator into
`DAT_0131226C` and clears it. Its indexed monthly caller is
`FUN_004AC650 @ 0x4AC650`, which calls `FUN_004AE900` (and therefore
`FUN_005180E0`) before the snapshot call.

The indexed split corpus has no function row for the body beginning at
`0x5DE430` (the gap ends at `0x5DE691`), so this edge was checked in the
hash-matched PE bytes directly. At `0x5DE605`, both canonical EN and CH builds
contain `push 0x1000; push ebp; mov ecx, DAT_0130F820; call 0x5919F0`.
The vtable tables also identify this body as a shared trade-building method:
both the Trading Station `#58` table at `0x7BEAB8` and the Trading Quay `#56`
table at `0x7BEDC4` contain `0x005DE430` at slot offset `+0x2F0` in both EN
and CH. Their constructors are the indexed `FUN_005E1420`/`FUN_005E1730`
branches described in the Grand Canal research. Therefore this body is a
confirmed Trading Station/Trading Quay writer of an amount held in its local
`ebp` value to the `0x1000` reason bucket, but the split corpus does not
recover the body's caller context or the computation's numeric domain. No
Native amount producer or automatic-migration wiring is enabled from this
single unsplit call.

As a negative indexed-corpus check, every other emitted direct call to
`FUN_005919F0` uses a different reason constant: `0x40`, `0x80`, `0x100`,
`0x200`, `0x400`, or `0x2` (callers at `0x444D40`, `0x4A3950`, `0x4A3280`,
`0x4A3C00`, `0x5F2FE0`, `0x5581F0`, `0x5180E0`, and `0x4966C0`). No indexed
caller supplies `0x1000`; the direct-PE edge above is the only recovered
`0x1000` writer, not proof of its domain.

**Evidence class:** **confirmed** for the accumulator branch, snapshot/reset
ordering, monthly call ordering, trade-class/vtable identity, and the EN/CH
direct-PE call bytes; **unknown** for the unsplit body's caller context and
amount semantics.

### Wage (`FUN_005911D0`) — confirmed table

Hash-matched `Emperor[EN].exe`
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`;
image base `0x400000`, `file_offset ≈ RVA` in initialized `.data`):

- Effects at VA `0x85CC5C` (file offset `0x45CC5C`): six little-endian
  `int32` values `[-10, -5, -2, 0, 2, 4]`.
- Thresholds at VA `0x85CC74` (file offset `0x45CC74`): six little-endian
  `int32` values `[0, 20, 26, 30, 34, 40]`.

Object init at `0x592BB0`:
`push DAT_01312214; push 0x11d; push 6; push 0x85CC74;`
`mov ecx, DAT_0130F820; call FUN_00554730`. Matcher fields used by
`FUN_00592BE0` are `[0]` = threshold pointer `0x85CC74`, `[1]` = count
`6`, `[3]` = pointer to current wage `DAT_01312214`. The `0x11d`
argument is not read by the nearest-match walk. `FUN_00592BD0`
(`0x592BD0`) does `mov ecx, DAT_0130F820; jmp FUN_00592BE0`. `FUN_00592BE0` (`0x592BE0`)
walks `abs(currentWage - threshold[i])` and keeps the nearest index;
ties keep the **first** index because the update is
`if ((n4 < 0) || (n < n3))` (strict `<`, not `<=`). `FUN_005911D0`
indexes `*(int *)(&DAT_0085cc5c + result * 4)`. Negative effects are
zeroed while population `<350` and `DAT_01312575 == 0`. City init and
`CampaignMissionRuntime` baseline wage are `30` (effect `0`).

### Employment (`FUN_00591130`) — confirmed

`unemployed × 100 / workforce` (`FUN_00408BA0`). Bands from
`DAT_01312208`:

- unemployment `<5` → **immediate** `return (DAT_01312208 < 5)` (`+1`);
  the population-`<350` / latch-clear zeroing is not reached.
- `5…10` → **immediate** `return (DAT_01312208 < 5)` (`0`); same early
  return, so low-population suppression is not reached.
- `11…17` → `n = -1`, then maybe zeroed.
- `18…25` → `n = -2`, then maybe zeroed.
- `≥26` → `n = -3`, then maybe zeroed.

Low-population suppression (`DAT_0130F988 < 0x15E` (350) and
`DAT_01312575 == 0` → `n = 0`) applies **only** to those negative bands
after the early return. Do not say `+1` is zeroed.

### Debt (`FUN_00590F00`) — confirmed

`DAT_01312630` consecutive debt **years** plus treasury `<0 → −2`.
Years accumulate from twelve consecutive negative months
(`FUN_004AC5B0`) and clear when treasury is non-negative.

### Feng shui (`FUN_00591670`) — confirmed bands

Population `<351` stores harmony `70` and returns `0`. Otherwise
harmony% bands: `100 → +2`, `≥90 → +1`, `≥80 → 0`, `≥70 → −1`,
`≥60 → −2`, `≥50 → −3`, `≥40 → −4`, else `−5`.

### Repression (`FUN_005915C0`) — confirmed

Count of building type `0x7F` (Watchtower `#127`). If
`population > 350` and `population ≤ count×500`, return
`−min(4, (count×500)/population)`.

### Food (`FUN_00590F30`) — walk recovered; Native fields not isomorphic

Canonical EN `.text` (`8a6d2df1…6753`). `FUN_00590F30` @ `0x590F30`
returns the popularity food term. Empty building list
(`FUN_00554C00` `this=0x8C7634`, `cmp eax, 1; jbe 0x59111F`) or an
occupied-house set that never enters the average returns **0**
(`confirmed`). Production stays `unsupportedOriginalProducer`. Do
not drive that term from Native `lastSuppliedFoodQuality` or from
`foodQualityRawValue` / `foodSupplyAmount`. No implementation
contract.

#### Authored house columns (`FUN_0044CC80`)

`FUN_0044CC80` @ `0x44CC80` is
`DAT_00A63BFC[column + row*0x18]` (`0x18` = 24 ints). Row is
`sx(house+0x16)` (the same house-level index as capacity column
`0x11`). `FUN_005D16D0` @ `0x5D16D0` fills `DAT_00A63BFC` from
static `DAT_00870E04` plus `HOUSE MODS`, clamping each sum through
`FUN_00445480(..., -99, 100)`. On-disk `DAT_00870E04` house 0
matches `GameData/Model/EmperorBuildingModels.txt` `ALL HOUSES`
“1: Shelter” (`confirmed`).

The file’s own column comments (lines 30–53), not column position
alone:

| index | name in the model file | `FUN_00590F30` use |
| ---: | --- | --- |
| 8 | `EVO_FOOD_QUALITY` — “Food quality needed to evolve” | popularity average threshold |
| 14 (`0xE`) | `EVO_CRIME_INC` — “Crime Risk Increment” | addend into `house+0x8C` |
| 15 (`0xF`) | `EVO_CRIME_BASE` — “Crime Risk Base” | lower bound for `house+0x8C` |

`ALL HOUSES` “1: Shelter”: col 8 `0`, col 14 `17`, col 15 `10`,
capacity `7`. “3: Plain Cottage”: col 8 `20`, col 14 `15`,
col 15 `5`, capacity `22`. Common-house col 8 is `0` (Shelter
and Hut), then `20 / 30 / 50`; `70` is on later elite rows. Native `FoodQuality` raw values
`0/20/30/50/70/90` are a **confirmed numeric correspondence**
with that unit set (`Sources/EmperorCore/FoodSimulation.swift`).
Native `ResidentialUnit` food fields are not isomorphic to the
recovered `cHouseInfo+0x36` / `+0x12` consumption, blending, and
cadence (§3), so they must not be substituted. `FUN_00545100` @ `0x545100` bands a byte as
`>89→5, >69→4, >49→3, >29→2, >0→1, else 0`. `FUN_00590F30`
compares the **raw** `cHouseInfo+0x36` quality byte to column 8,
not that 1…5 band. `EmperorText` group 127 row 59 is the evolution
`[food_quality]` sentence (`housing-evolution-reasons.md`); it is
not this popularity walk’s input.

#### Appeal-buffer consumer (`FUN_005180E0`, confirmed 2026-08-30)

The monthly population/popularity pass is a separate consumer of the appeal
buffer. `FUN_004AE900 @ 0x4AE900` calls `FUN_005180E0 @ 0x5180E0` after the
month-boundary scheduling work; both rows are `identical` in
`local/source/compare-report.tsv`. The function clears its 20-entry per-model
accumulator and counters, walks the active building list, and for each active
object invokes vtable `+0x204` and `+0x1F8`. The latter is the same
single-cell/multi-cell appeal reader documented in
`desirability-propagation.md`.

For each object it subtracts the model column `0` value from the signed appeal
byte, maps the delta through the recovered piecewise bins (thresholds at
`10/20/30/40/50`) scaled by global `DAT_0130F96C`, and adds a fixed `+20`
bonus when `FUN_005A8420(9)` passes. It multiplies the resulting score by the
object population word `p+0x20` and model column `0x12`, then by `10`, and
accumulates positive fixed-point results with `(value + 5000) / 10000`.
When the tax byte at `building +0x52` is non-zero, it additionally applies a
fixed-point delta to the `+0x40` field returned by vtable `+0x1E4`; the
function aggregates that delta by the `+0x204` class result and calls
`FUN_005919F0(delta, 0x400)`. The no-tax branch only accumulates population by
the same class result. This is direct evidence that appeal affects a monthly
population accumulator before any house-evolution reason rendering.

The exact semantic names of vtable `+0x204`, model column `0x12`, global
`DAT_0130F96C`, and the aggregate slots remain unresolved, and Native has no
isomorphic fixed-point population ledger. This consumer therefore remains a
research boundary; it does not authorize replacing Native migration math with
the current Manhattan desirability helper.

Columns `0xE`/`0xF` are **not** food-stock columns. They feed
`house+0x8C` in this walk. Do **not** name `house+0x8C`
`crimeRisk`: the model-file labels name the columns, not the
house dword; original field name and complete consumers are not
closed. The popularity **return** does not use `+0x8C`.

#### Occupied-house walk (confirmed EN sites)

Same building vector as monument matching: `FUN_00413B40(1)`
`this=0x8C7630` @ `0x590F4A`; index starts at **1**. Per house:

| check | site | polarity |
| --- | --- | --- |
| Live | `FUN_00426D10` @ `0x590F8A` | `house+4` is 1 or 3 |
| House class | vtable `+0xB8` @ `0x590F9B` | `house+9 != 0` (§5.8) |
| Empty | `cmp word [esi+0x20], 0` @ `0x590FA9` | residents 0 → `house+0x8C = 0` @ `0x590FB0` and **skip** both the `+0x8C` update and the food average |
| Elite skip of `+0x8C` only | `FUN_00516ED0(index)` cdecl @ `0x590FC0`; `this=0x8C7634` then `FUN_005188D0(building+0x14)` | true for types **11…17** inclusive (`cmp eax, 0xB` / `0x11` @ `0x5188D4`). Skips the `+0x8C` update; the food average still runs |
| `+0x8C` update | @ `0x590FCC` | `+0x8C += col 0xE + (40-popularity)/2`; if `<` col `0xF`, raise to col `0xF`; if `>100`, cap `100` |
| `(40-popularity)/2` | @ `0x590F3B` | popularity `DAT_0130F974` snapshotted once; signed toward-zero `/2` (`cdq; sub eax,edx; sar 1`) into `ebx` |
| Average threshold | `FUN_0044CC80(house+0x16, 8)` @ `0x59102F` | required `0` → `house+0x5C = 0` @ `0x59109E` and **do not** count this house |
| Quality compare | vtable `+0x1E4` @ `0x591046` then `movzx [eax+0x36]` @ `0x59104E` | `cHouseInfo+0x36` raw quality byte (object at `house+0xC8`, §5.9; same units as `FoodQuality` `0/20/30/50/70/90`). **`<` required**: increment streak byte `house+0x5C`, cap **3** (`jbe` @ `0x59106C`); streak `1→−1`, `2→−2`, `≥3→−3`. **`>=` required**: score `+2` and `house+0x5C = 0` @ `0x59105A` |

Mean of those per-house scores: `sum / count` then round **away
from zero** only when `abs(remainder) > count/2` (`cmp ebx, eax;
jle` skip @ `0x5910F2`; exact half does **not** round). If the
mean is `< 0` and `DAT_0130F988 < 0x15E` (350) and
`DAT_01312575 == 0`, return `0` @ `0x591116`. Else return the
mean (`mov eax, edi` @ `0x59111F`).

#### Authored food-quality and delivery semantics

`GameData/EmperorManual.pdf` p.48 (confirmed extract): five named
qualities bland / plain / appetizing / tasty / delicious from mill
food-type count plus salt and spices; delicious is **not** required
for housing evolution (tasty is the highest evolution demand) but
does affect hygiene (p.95). The type-count table on that page is
the same decision table as Native `OriginalFoodCatalog.quality(in:)`
(`confirmed` as mill/distribution **prose**; that Swift function is
**not** a recovered `cHouseInfo+0x36` writer). p.48 “Food
Distribution” defers to the Commerce Ministry (p.56). p.62: market
right-click “current quality” is the quality in the food shop being
distributed by **peddlers**; buyers fetch from the mill. p.82: Zao
Jun “delivers delicious food (see p.48) to every house he passes”
and can bless a food shop by one named level. `GameData/Readme1010.txt`
line 145 is evolution devolution for poor food quality, not this
popularity walk. `EmperorText` group 127 row 59 remains the
evolution `[food_quality]` sentence, not `FUN_00590F30`.

`GameData/Model/Trade.txt` `[DefaultPrices]` key order is Native
`TradeRules` 0-based IDs (`LegacyModelParser.swift`): index **28**
(`0x1c`) is **Dinners**. `EmperorFigureModels.txt` ID **23** is
`peddler`, **24** is `Marketplace buyer`, **79** (`0x4F`) is
`Player's Heroes`. Building ID **53** (`0x35`) is the mill, **66**
(`0x42`) is the food shop (`OriginalFoodCatalog` / building models).

#### `cHouseInfo+0x36` identity and writers

Object: `HouseBldg+0x1E4` = `FUN_00416B50` (`lea eax,[ecx+0xC8];
ret`; corpus gap). Constructor `FUN_00517190` @ `0x517190` writes
`+0x36 = 0`. House serialize `FUN_00518910` calls base
`FUN_00427430` then `cHouseInfo` vtable `+8` @ `0x517410` (EN
`.text`; **no** `compare-report.tsv` row). Save of `+0x36` is 1
byte @ `0x517570`.

`HouseBldg+0x36` is a **different** byte (`FUN_00427430` 1-byte
field; `FUN_00518B70` writes `idiv 0x28` remainder there). Do not
conflate it with `cHouseInfo+0x36`.

`FUN_00518490` starts @ `0x518490` and **reads**
`cHouseInfo+0x36` at `0x518510` (`cmp byte [eax+0x36], 0x14` /
`jb`; unsigned `< 0x14` skips, i.e. `> 0x13`) to count
residents. Do not cite `0x5184A0` as that read: it is not an
instruction start (`0x51849F`/`0x5184A1` zero `DAT_0130F98C`).
`FUN_00517330` **reads** it through `FUN_00545100` into
`cHouseInfo+0x38`.

##### `cHouseInfo+0x12` — food stock slot 0 (confirmed)

`FUN_00447600` @ `0x447600` (`identical`) maps commodity IDs onto
`cHouseInfo` **word** slots at `+0x12 + slot*2`:

| commodity | `Trade.txt` 0-based name | slot | address |
| ---: | --- | ---: | --- |
| `0x1c` (28) | Dinners | 0 | `+0x12` |
| `0x13` (19) | Hemp | 1 | `+0x14` |
| `0x19` (25) | Ceramics | 2 | `+0x16` |
| `0x18` (24) | Silk | 3 | `+0x18` |
| `0x17` (23) | Bronzeware | 4 | `+0x1A` |
| `0x16` (22) | Lacquerware | 5 | `+0x1C` |
| `0xd` (13) | Tea | 6 | `+0x1E` |
| other | — | `0xFFFFFFFF` | not a house slot |

The confirmed projection is also exposed as the side-effect-free
`OriginalMarketHouseInfoSlot.slot(forCommodityID:)` helper in
`Sources/EmperorCore/MarketSimulation.swift`, with regression coverage in
`EmperorCoreTests.testOriginalMarketHouseInfoSlotMatchesRecoveredCommodityProjection`.
This helper only records the executable's key-to-slot table; it does not imply
that the provider-record writer or Native market settlement has been recovered.

##### Native campaign live-wiring boundary (2026-08-31)

The static corpus still does not close the cMarket provider-record →
`cHouseInfo`/Native inventory, food-quality, coverage, or route lifecycle.  The
confirmed pieces are limited to the raw record operations (`+0x268`, `+0x280`,
`+0x298`, `+0x2790`), the normal callback arithmetic at `0x5437B0`, and the
month-depletion walk at `0x518690`; their callers and internal-key mapping do
not establish the Native `ResidentialUnit` fields.  Existing notes therefore
classify the Qin market settlement path as **unknown/fail-closed**, not as a
recoverable household-consumption contract.

Accordingly, `CitySimulation.settleMonth` now invokes
`DeterministicMarketState.settleMonth` only when `missionSettingsState == nil`
(the unscoped sandbox/fixture path).  Campaign-backed cities leave market
household stock, quality, shortage counters, and settlement records unchanged
until the missing provider mapping is recovered.  This is a wiring boundary,
not a claim that the sandbox implementation is original behavior; the direct
`DeterministicMarketState` APIs remain available for isolated tests of the
confirmed raw arithmetic.  Evidence class: **confirmed** for the negative
mapping boundary and the corresponding fail-closed requirement; **unknown** for
the provider-record population source, Native projection, and downstream
settlement semantics.

Do **not** name the whole array from this table alone. Monthly
food depletion (`FUN_00518690`) and the Dinners arm of `0x5437B0`
touch slot 0. Other goods are delivered by the `DAT_00857344` loop
inside `0x5437B0` (six records, stride `0x40`, through
`0x8574C4`): Hemp/Tea/Ceramics/Bronzeware/Lacquerware/Silk into
slots 1/6/2/4/5/3. That loop is not a `+0x36` writer.

##### Monthly depletion — `FUN_00518690` (confirmed)

`FUN_00518690` @ `0x518690` (`identical`) is called from
`FUN_004AC650` @ `0x4AC650` (`identical`) when the 16-slice
counter wraps (`DAT_00C82EF0 >= 0x10`) — **month rollover**, same
function that snapshots `DAT_01311FCC`. `FUN_00503E20` @
`0x503E20` (`identical`) returns `0x19` (25). `FUN_00408B80` @
`0x408B80` (`identical`) is `(a * b) / 100`. Per live building
(`p[1]==1`):

- required = `FUN_0044CC80(house+0x16, 8)` (model column 8).
- `ret2 = FUN_00408B80(sx(house+0x20), 25)` = `(residents * 25) / 100`.
- If `DAT_00C5CDA0 != 0` (cheat): `+0x12 = ret2` and
  `+0x36 = 0x14` @ `0x518721`.
- If cheat==0 and required `> 0`: subtract `ret2` from word
  `+0x12` (or drain the remainder); if `+0x12 < 1`, zero `+0x12`
  and **`+0x36 = 0`** @ `0x5187BF`. If required is 0, this block
  is skipped. Sum consumed → `DAT_0131252C`, then
  `FUN_005482E0(0)`.

##### Recovered normal market-delivery writer — `cMarket+0x2c` @ `0x5437B0` (confirmed store; complete writer set not proven)

Unsplit EN `.text` at **`0x5437B0`** (`sub esp, 0x18`; `this` in
`edi`; house stack-arg in `esi`; `ret 8`). **No**
`compare-report.tsv` row; do **not** call it identical. Direct byte
comparison of the hash-matched PE files nevertheless finds the complete
range `0x5437B0…0x543BBB` (1,035 bytes) byte-identical in the canonical EN
and CH builds; SHA-256 is
`3ef66c67084cb06aca47a741ad44c71304821948834509d5b75597da30678887`.
This upgrades the arithmetic body below to `confirmed` for both variants,
but it does not replace the missing split-corpus caller evidence. Ghidra
did not split it (`FUN_005436A0` is a nearby dtor). One PE
pointer: `cMarket` vtable `0x7B6F3C+0x2C` = `0x5437B0`. MSVC
RTTI TypeDescriptor `0x857E70` name `.?AVcMarket@@` (`confirmed`).
`cMarket+0x28` = `FUN_00429DF0` @ `0x429DF0` (`identical`), which
is `FUN_00429E10(figure, radius, this, 0)`.

`cMillBldg` vtable `0x7B72C8` (RTTI `.?AVcMillBldg@@`): `+0x28`
is the same `FUN_00429DF0`; **`+0x2C` = `0x42A210`** =
`xor eax, eax; ret 8`. The mill visit callback does **not** write
houses. Direct `E8` call xrefs to `0x5437B0` are none; the
recovered market-delivery path is this vtable slot. That does
**not** prove `0x5437B0` is the exhaustive unique normal writer
of `cHouseInfo+0x36`.

Walker cadence (`identical`): `FUN_004E7EB0` / `FUN_004E6D80`
increment figure `+0x41`; EN `FUN_004E7EB0` @ `0x4E7EFE` is
`cmp al, 0x14` / `jl` (call when the byte is `≥ 0x14` after
`inc`). They call `FUN_004EACD0` @ `0x4EACD0`. That function:

- figure `+0x12 == 0x26` (38, Elite Couple) → return 0;
- figure `+0x12 == 0x4F` (79, Player's Heroes) →
  `FUN_00429E10(figure, 2, 0, &LAB_00515120)` (hero visit,
  **not** `cMarket+0x2c`);
- else home building from figure `+0x62` → vtable `+0x28(figure, 2)`.

For a figure whose home object is `cMarket`, that is
`FUN_00429DF0` → Chebyshev radius **2** → `cMarket+0x2c(figure,
house)` = `0x5437B0`. `FUN_004EACD0` does **not** test model 23
versus 24. Model-24 states 6/7 enter this cadence (§3 below).

`0x5437B0` body (EN `.text`, `confirmed` bytes):

1. `ebx = FUN_00515770(this)` = `*(cMarket+0x180)` (`identical`
   getter). Treat as the market food-quality **dword** until every
   writer of `+0x180` is closed. `FUN_00544F10` (`identical`)
   save/loads that dword as 4 bytes.
2. Residential gate: `FUN_005188B0(house+0x14)` types **2…17**
   (`identical`). Empty houses (`house+0x20==0`) also need
   `FUN_005188D0` (elite **11…17**).
3. Elite: `FUN_00545100(ebx)`; if the 1…5 band is **`< 3`**
   (raw quality `≤ 49`), a flag at `[esp+0x30]` is cleared and
   the quality write is skipped.
4. Inventory: `FUN_00447600(0x1c)` → slot 0; `cMarket+0x264(0x1c)`
   is market Dinners stock. Add `min(need, stock)` into word
   `[cHouseInfo + slot*2 + 0x12]`; deduct via `cMarket+0x298`.
   If Dinners stock is then `≤ 0`, `FUN_00545140(0)` zeros
   `cMarket+0x180` @ `0x5438FE`.
5. Quality write @ **`0x543A09`**: `mov byte [cHouseInfo+0x36], bl`
   after `call [house+0x1E4]`.
   - If `ebx > 0` and `ebx >` current `+0x36`, **replace** with
     market quality.
   - Else if delivered amount `ebp > 0`, **blend** current `+0x36`
     with market quality using `r = delivered/existingStock`
     (`r = 10.0` if existing stock `≤ 0`). Float constants:
     `DAT_007B7248 = 3.0`, `DAT_007ACA38 = 2.0`,
     `DAT_007ACA3C = 0.5`, `DAT_007B7244 = 0x3EA8F5C3`
     (`0.33000001311302185`, single precision). Branches use
     `fcomp` / `test ah, 0x41` (not-greater). Signed integer
     blends (`confirmed` identities):
     `r > 3` → `(current + 3*market) / 4`;
     `r > 2` → `(current + 2*market) / 3`;
     `r > 0.5` → `(current + market) / 2`;
     `r > ≈0.33` → `(2*current + market) / 3`;
     else `(3*current + market) / 4`.
     (`/3` is `imul 0x55555556`; `/4` is MSVC signed `sar 2`.)

`FUN_00545140` @ `0x545140` (`identical`) is
`*(this+0x180) = param_2`. Recovered `E8` callers:

| site | effect | class |
| --- | --- | --- |
| `0x5438FE` in `0x5437B0` | zero when Dinners stock `≤ 0` after house delivery | confirmed |
| `FUN_00543450` @ `0x5435BB` | constructor zeros `+0x180` (`identical`; this is the `0x5435BB` `E8`) | confirmed |
| `FUN_00544B30` @ `0x544D18` | `FUN_00544340(0x1c)` then `FUN_00545140(0)` iff that call returns 0 | confirmed (`identical`); not constructor/init |
| `0x5411EA` in `cStall+0xC0` `FUN_00541180` | raise parent-market `+0x180` to `this+0x16c` if higher, only when `word this+0x14 == 0x42` (Food Shop 66) | confirmed bytes; `FUN_00541180` has **no** `compare-report` row |
| `0x541858` in `cStall+0x260` `FUN_00541760` | rounded weighted blend onto parent market | confirmed arithmetic below; **no** `compare-report` row |
| `FUN_00511080` case 4 | add up to `0x14` then store, capped so `FUN_00545100(new)` does not exceed `*(this+0x184)` | confirmed hero bless of the food shop / parent market |

Mill-pickup cart `figure+0x13` is the mill `+0x2E4` selected
recipe type-count (§3 below). Do **not** assign `cMarket+0x180`
or its store to `cMillBldg`: the mill returns a type-count onto
the cart; the stall blend writes the market. Do **not** treat
Native `OriginalFoodCatalog.quality(in:)` or manual p.48 as that
byte’s writer, and do **not** infer a 1…5 quality band merely
from the `20 * byte` blend.

##### `cMarket+0x180` live blend — `cStall+0x260` @ `0x541760`

`cStall` vtable `0x7B6C5C` (RTTI `.?AVcStall@@`):

- `+0x1C` = `FUN_00541130` @ `0x541130` (`identical`): spawn via
  stall `+0x18`; parent market `FUN_00490700`; copy cargo plan
  through market `+0x2D8`. If `word stall+0x14 == 0x42`,
  `FUN_00515770(parent market)` → `figure+0x16c`. Ghidra drops
  `ecx`; EN bytes @ `0x541169` are `mov ecx, ebx` (`ebx` = parent
  market).
- `+0x20` = `FUN_00541B80` @ `0x541B80` (`identical`): shop think;
  spawns buyer via `FUN_00540B40`.
- `+0x2C` = `0x42A210` (`xor eax, eax; ret 8`), same house-visit
  stub as `cMillBldg+0x2C`. The recovered peddler path writes
  houses through its home `cMarket+0x2C`; `cStall+0x2C` is that
  stub. Buyer delivery remains `unknown`.
- `+0xC0` = `FUN_00541180` @ `0x541180` (unsplit, no
  `compare-report` row): figure-return raise described above.
- `+0x260` = `FUN_00541760` @ `0x541760` (unsplit, no
  `compare-report` row; `ret 0xC`).

No direct `E8` to `0x541760`. The recovered virtual caller is
unsplit cart think `0x4D2970` (type-table slot 0 for model **25**;
no `compare-report` row) @ `0x4D2B15`:

```
push 0x64                 ; 100
push byte figure+0x13
push byte figure+0x88     ; commodity
mov  ecx, edi             ; stall
call [vtable+0x260]
```

`FUN_00540710` @ `0x540710` (`identical`) is `param == 0x1c`
(Dinners). For that commodity `FUN_00541760` reads current
`FUN_00515770(parent market)`, adds into the stall cargo slot
through `FUN_005D2790` (clip to cap; return overflow), then if
the added amount is food:

```
accepted = 100 - overflow
new = round( (old_quality * old_dinners_stock
              + 20 * accepted * (byte figure+0x13))
            / (old_dinners_stock + accepted) )
FUN_00545140(parent market, new)
```

`FUN_00541730` @ `0x541730` (`identical`) is the float→int round
(`call 0x7650FC`, then `+1` when the discarded fraction is not
`< 0.5`). This is the recovered **live store** of `cMarket+0x180`
when mill cargo returns to a food shop. Arithmetic proves an
incoming raw contribution of `20 * byte(figure+0x13)`. That
arithmetic does **not** by itself prove the byte is a 1…5
quality band: `FUN_00545100` would classify `20/40/60/80/100` as
bands 1…5, which is a consumer of the blended dword, not a
producer of `+0x13`.

This pass searched `.text` for a consecutive dword/byte sequence
`20,30,50,70,90` and did not find one. That is only a negative on
that encoding; it does not require such a lookup to exist.
`FUN_005557D0` / `FUN_005558D0` (`identical`) have **no** `E8`
callers. They are the mill vtable `+0x2F0` / `+0x2E0` targets
(only PE pointers `0x7B75B8` / `0x7B75A8` on `cMillBldg`
`0x7B72C8`). They compute hundred-unit recipe availability for a
1…5 type-count and salt/spice (8/9); they do **not** store
`cMarket+0x180`. Overlay `FUN_00544240` (`identical`
`FUN_00515770` / `FUN_00545100` on food-shop stalls) **reads**
`+0x180` for sprite index `0x458 + commodity + (band-1)`; it does
not write it.

##### Mill pickup → Dinners carts (model 25); cart `+0x13` producer

`FUN_005464E0` @ `0x5464E0` (`identical`) is mill pickup
(`push 0x35` = building 53 on the **dest mill**, `ebp`). `this`
(`mov ebx, ecx`) is the **market object**, not the mill and not
the cart. Buyer think unsplit `0x4D1810` (no `compare-report`
row) @ `0x4D1A04` calls `FUN_004E3C70` (`identical`, cdecl
`add esp, 0xC`): figure id `DAT_010aeee4`,
`*(parent_market+0xB4)` (building id; same `+0xB4` field as
§3 monument), dest mill id `figure+0x68`. `FUN_005463A0`
(`identical`) then `thiscall`s `FUN_005464E0` with that looked-up
building as `this`. `FUN_004E3C70` replaces that `this` with
`FUN_00490700(arg2)` only when arg2-building `+0xC8(-1)` is true.
Mill `+0xC8(-1)` is false (type 53 ≠ −1 and ≠ −7). Whether
`cMarket+0xC8(-1)` is live on this path is `unknown`;
constructor `cMarket+0x154` is a shop-array pointer, not a
building id. `FUN_00515780` / `FUN_00546C60`
(`identical`) read **`cMarket+0x184` / `+0x188`**.
`FUN_00543E50` (`identical`) is `this+0x264(0x1c)` (Dinners
stock); `cMarket` and `cMillBldg` share `+0x264 = 0x5D4A60`.

`cMillBldg` vtable `0x7B72C8` (RTTI `.?AVcMillBldg@@`) recipe
slots (each has exactly one PE pointer, on this vtable):

| slot | target | `compare-report` |
| --- | --- | --- |
| `+0x2E0` | `FUN_005558D0` @ `0x5558D0` | `identical` |
| `+0x2E4` | unsplit `0x555330` | **no** row; do not call identical |
| `+0x2E8` | unsplit `0x555E40` | **no** row |
| `+0x2EC` | `FUN_00555410` @ `0x555410` | `identical` |
| `+0x2F0` | `FUN_005557D0` @ `0x5557D0` | `identical` |

No `E8` to `0x555330`. `FUN_005464E0` @ `0x5465C3` calls mill
`+0x2E4` with `(cMarket+0x184, cMarket+0x188, capacity, &types,
&amounts)` (`ret 0x14`). EN bytes @ `0x555406` are
`mov eax, ebx; … ret 0x14`: the method **returns the selected
type-count**, not the hundred-unit amount. Selection (EN bytes
`0x555381…0x5553C3`): walk `i` ascending from `cMarket+0x188`
through `cMarket+0x184`; `ebx` starts 0. Whenever mill
`+0x2E0(i)` availability `> capacity/3` (`cmp` @ `0x555397`,
`jg 0x5553A5`), that `i` **replaces** the current selection, so
the result is the **highest** `i` whose availability exceeds
`capacity/3`. Only if no `i` exceeds that threshold does it
keep the **lowest** `i` with nonzero availability (`test ebx,ebx`
/ `test ecx,ecx` @ `0x55539B`). If none are nonzero,
return 0 and the type/amount arrays stay zero, so no cart spawn.
`FUN_005558D0` (`identical`) switches on `dec(arg); cmp eax, 4;
ja default` — valid args **1…5** — and uses mill `+0x2E8` plus
stock of commodities 8/9. `FUN_00555F70` (`identical`) is foods
**1…7** only (`FUN_005DB4C0` minus salt/spice). Then mill
`+0x2EC(selected_i, min(amount, capacity, 600), &types,
&amounts)` fills the bundle (`FUN_00555410`, `identical`;
virtual mill `+0x2F0` = `FUN_005557D0`).

`FUN_005467A0` (`identical`) converts a bundle slot into a 1…10
cart count. `FUN_00546960` @ `0x546960` (`identical`,
`ret 0x18`, six stdcall args) spawns figure model **`0x19` (25)**
`Buyer's Servant` (`EmperorFigureModels.txt` 1-based row 25,
range 50). After EH (`sub esp, 0x18` + four register pushes)
EN bytes @ `0x546A10` / `0x546A14` / `0x546A1E` / `0x546A30`:

- `figure+0x88` ← low byte of **arg1** (commodity);
- `figure+0x13` ← low byte of **arg2**.

Ghidra’s `FUN_00546960` store of `0xffffffff` into `+0x13` is
the EH cookie, not this write. If `FUN_005DB4C0` (`identical`)
is true (`1 ≤ commodity ≤ 9`), arg1 is **rewritten** to
**`0x1c` Dinners** before those stores (`mov dword [esp+0x38],
0x1c` @ `0x5469BF`). Cart `+0x62` copies the caller figure’s
home. `FUN_005464E0` @ `0x54663B` pushes mill `+0x2E4`’s return
as arg2, so mill-pickup cart `+0x13` **is** that selected
type-count (`confirmed`). Commodities 8/9 skip cart spawn at
`0x5465FB` / `0x546604` and deduct through mill `+0x298`.

Operational semantic (`confirmed` as the mill recipe switch,
not as an original symbol): the byte is the type-count integer
mill `+0x2E0` / `+0x2EC` already use. Constructor
`FUN_00543450` (`identical`) sets `cMarket+0x184` to **5** when
`param_2 == 0x3C` (building 60 Grand Market Square) else **3**
(Common Market 59 is `0x3B`); `FUN_00545160(1)` writes `+0x188`;
then zeros `+0x180`. Factory `FUN_005D3580` passes the building
type (`identical` `FUN_00543D90` gate). The scan range is
therefore `[1, 3]` or `[1, 5]` unless some other writer changes
those dwords. Hero case 4 uses `+0x184` as a max
`FUN_00545100` band. `FUN_00544F10` (`identical`) save/loads
both dwords as 4 bytes. Do **not** name cart `+0x13` a quality
band, and do **not** treat `20 * byte` or manual p.48 named
rows as that proof. p.48 remains mill/distribution **prose**.

Sibling `FUN_00546440` (`identical`), from `FUN_005463F0`
(`identical`) when a buyer slot dword at `figure+0xAC` is in
**1…6**, calls `FUN_00546960` with **arg2 = 0** (`push 0` @
`0x54649F`). That spawn writes cart `+0x13 = 0`. Whether those
carts deposit through `cStall+0x260` is `unknown`.

Figure ctor `FUN_004C72B0` (`identical`) zeros `+0x13`.
Serializer `FUN_004C75C0` (`identical`) save/loads that byte
via `FUN_004C95F0` (`identical`). Unsplit cart think `0x4D2970`
@ `0x4D2B04` **reads** `byte [esi+0x13]` for the `+0x260` push
and does not store the figure byte (local `[esp+0x13]` is a
different flag). Other `+0x13` writers (`FUN_004EAD60` /
`FUN_004EB420` hero-effect identity, `FUN_004CBA70` /
`FUN_004CBC70` copy of `+0x88`) are not this mill-pickup chain.

`Trade.txt` `[DefaultPrices]` 0-based IDs: foods 1…7, Salt 8,
Spices 9, Dinners 28. `+0x184` is a market food-type **cap**
(3 vs 5), not the mill’s current type count. The mill **selects**
a type-count in that cap and copies it onto the cart.

##### Peddler 23 vs buyer 24 — spawn/think exclusive; `FUN_004EACD0` shared

Authored: `EmperorFigureModels.txt` 23 `peddler` range 60; 24
`Marketplace buyer (Food/ Tea/ Hemp/ Bronzeware/ Lacquerware/ Silk/
Ceramic)` range 50; 25 `Buyer's Servant` range 50. Both 23 and
24 have speed field `i` = **8**. Buildings 53 Mill, 59/60
Common/Grand Market Square, 66 Food Shop (`0x42`). Manual p.62
(supporting prose only; not a code gate): right-click “current
quality” is the food-shop quality distributed by **peddlers**;
**buyers** fetch from the mill.

Spawn (`identical`):

- Peddler: `cMarket+0x20` = `FUN_00545170` → `FUN_00543ED0` @
  `0x543ED0` → `FUN_004EA050(..., 0x17, ...)` model **23**,
  `figure+0x40 = 1`, `figure+0x62 = market id`, `FUN_004E6A70`
  roam init (`+0x41 = 0x14`, `+0x4E` 0 then 1).
- Buyer: `cStall+0x20` = `FUN_00541B80` → `FUN_00540B40` @
  `0x540B40` → `FUN_004EA050(..., 0x18, ...)` model **24**,
  `figure+0x40 = 6` (or **7** if dest checks fail), `+0x62 =
  market id`, `FUN_004EA8C0` destination (`figure vtable +0x20`),
  `+0x68 = dest building`, seven dwords of cargo plan.

`FUN_004EA050` → `FUN_004E1420` (`identical`) default case
(neither 23 nor 24 is a special `param_2` arm) →
`FUN_004C71D0` (`identical`) sets vtable `0x7AFE60`. That
vtable `+0x114` = unsplit `FUN_004C9310` @ `0x4C9310` (**no**
`compare-report` row): `DAT_00A5F60C[type*18 + selector]`.
Selector **8** is authored field `i` (speed). PE
`DAT_0086ADF4` rows 23/24 already hold those model dwords
(speed **8**); `FUN_005D1E20` (`identical`) copies them into
`DAT_00A5F60C`. `FUN_004EB9C0` (`identical`) is
`vtable+0x114(arg)`.

Think trampoline (same table as §5.1): `FUN_004E27E0`
(`identical`) → figure vtable `+0x28` `FUN_004C7580` →
`jmp [type*40 + 0x84E784]` (slot 0 of row `type`). Slot 0:

| `figure+0x12` | authored row | slot 0 | class |
| --- | --- | --- | --- |
| `0x17` (23) | peddler | unsplit `0x4D0270` | no `compare-report` row |
| `0x18` (24) | Marketplace buyer | unsplit `0x4D1810` | no `compare-report` row |
| `0x19` (25) | Buyer's Servant | unsplit `0x4D2970` | no `compare-report` row |

`0x4D0270` **always** `call FUN_004E3A80` (`identical` roam tick:
states 1/2 → `FUN_004E6B70` / `FUN_004E47A0` → `FUN_004E7EB0` /
`FUN_004E6D80` → `FUN_004EACD0`). Peddler home `+0x62` is the
market id written at spawn (`confirmed`), so a live peddler on
this think row is a recovered `0x5437B0` delivery walker.

`0x4D1810` is a destination FSM on `figure+0x40 ∈ {4,5,6,7}`
(`add eax, -4` / `cmp eax, 3` / `jmp [eax*4 + 0x4D1A64]`).
Spawn uses 6/7. Prologue always `FUN_004EB9C0(figure, 8)` @
`0x4D181D` into `ebx`. State 6 @ `0x4D1922`: if dest
`building+4 == 1`, `FUN_004E47A0(id, ebx)` @ `0x4D196B`; else
set `+0x40 = 7` and return. State 7 @ `0x4D1A0E`: always
`FUN_004E47A0(id, ebx)` @ `0x4D1A15`. After state 6’s `47A0`,
`+0x19 == 8` jumps to mill pickup `FUN_004E3C70` @ `0x4D19ED`.

`FUN_004E47A0` (`identical`) `jmp [arg*4 + 0x4E4BBC]`. Speed 8
is **case 8** @ `0x4E4921`, not case 6: if
`figure+0x170 > 1` then `FUN_004E7EB0(id, 2)` @ `0x4E4B21`, else
`FUN_004E7EB0(id, 1)` and `inc +0x170`. Case 6 @ `0x4E48E0` is
unconditional `FUN_004E7EB0(id, 1)` (other speeds). Both cases
enter `FUN_004E7EB0` with `param_2 ≥ 1`.

`FUN_004E7EB0` (`identical`) @ `0x4E7F02` `call FUN_004EACD0`
when `+0x41 ≥ 0x14` after `inc` (`cmp al, 0x14` / `jl`
`0x4E7F52`). No model test. If `+0x42 < 1` and `+0x19 ≥ 8`
(`cmp al, 8` / `jge 0x4E7F79`) the increment/ACD0 loop is
skipped that tick (buyer standing at dest). Walking ticks
(`+0x42 ≥ 1` or `+0x19 < 8`) run the loop. Ctor
`FUN_004C72B0` zeros `+0x41`; peddler roam sets `0x14`, buyer
spawn does not, so the buyer’s first ACD0 is after 20 `inc`s.

`FUN_004EACD0` still does not test 23 vs 24. Buyer `+0x62` is
the market id, so home `+0x28(figure, 2)` is `FUN_00429DF0` →
`FUN_00429E10` Chebyshev 2 → `cMarket+0x2C` `0x5437B0`. That
method has no 23-vs-24 test (EN `0x5437B0` body). **Spawn
roles and type-table think rows are exclusive (`confirmed`).
`FUN_004EACD0` / `cMarket+0x2C` is not exclusive to peddlers:
model-24 states 6/7 can reach that writer (`confirmed`).**
Manual p.62 does not override that path. Cart think `0x4D2970`
remains the stall-deposit path, not house delivery.

`cMarket+0x2C` remains the recovered normal house-delivery writer.
Production stays `unsupportedOriginalProducer`. **No gameplay
implementation contract.**

##### Hero visit `0x5A` — unsplit `0x515120`, not `FUN_005149C0`

`FUN_005149C0` / Ghidra name `Check_if_going_to_fire` @
`0x5149C0` (`identical`) is a **constructor** that embeds the
string “Check if going to fire” and returns around `0x51511E`.
The `0x5A` store is in the **next**, unsplit function starting
`0x515120` (`sub esp, 0xc`). **No** `compare-report.tsv` row.
Do **not** cite `FUN_005149C0` @ `0x515259`. Do **not** use the
Ghidra name as an original symbol.

`0x515120` is the `FUN_004EACD0` hero callback
(`&LAB_00515120`) for figure model `0x4F`. Switch on figure
`+0x13` (hero-effect identity per `hero-effect-lifecycle.md`).
**Case 4** @ `0x51522F`: if `house+0x92==0`, `inc word
[cHouseInfo+0x12]` and set `house+0x92=1`; **always**
`mov byte [cHouseInfo+0x36], 0x5A` @ `0x515259`. This is a
hero house-visit effect (delicious = 90), **not** mill/peddler
quality. Manual p.82 Zao Jun “delivers delicious food” is
**supporting** player-facing prose for *a* hero delicious
delivery; it does **not** prove identity `4` is Zao Jun
(`hero-effect-lifecycle.md` identity `3` is Xi Wang Mu; the
Eventmsg name list is a different numbering). Case-4 identity
stays `unknown`. Do not treat this path as the recovered
normal market-delivery writer.

##### Store table (after `call [vtable+0x1E4]` unless noted)

| site | value | class |
| --- | --- | --- |
| `FUN_00517190` | `0` | init, confirmed |
| `FUN_00518690` @ `0x5187BF` | `0` when `cHouseInfo+0x12 < 1` | monthly food-slot drain, confirmed |
| `FUN_00518690` @ `0x518721` | `0x14` (20) when `DAT_00C5CDA0 != 0` | debug/cheat path, confirmed |
| `0x543A09` in `0x5437B0` | `bl` from `cMarket+0x180` (replace or ratio-blend) | recovered normal market-delivery store, confirmed; live `cMarket+0x180` blend at `0x541858` recovered; mill `+0x2E4` type-count producer of cart `+0x13` recovered; player-facing quality name/Native mapping and complete `+0x36` writer set not proven |
| unsplit `0x515120` @ `0x515259` | `0x5A` (90) after optional `inc +0x12` | hero model 79 case 4, confirmed store; identity `unknown` |

This pass does **not** claim those are the only writers. Further
unencoded or indirect stores remain possible; the complete writer
set is not proven.

#### `house+0x5C` / `house+0x8C`

`house+0x5C` is the food-average streak byte (`p+0x17`).
`house+0x8C` is the dword `p[0x23]` updated from columns 14/15
and zeroed on empty houses. Do **not** name it `crimeRisk`.
Both are copied by `FUN_00426EA0` and saved/loaded as 1 byte /
4 bytes in `FUN_00427430` schema 4 (`0x427430` @ `+0x5C` /
`+0x8C`; `FUN_00518910` uses that base serializer). Complete
constructor-zero set for the two fields is **unknown** beyond
the empty-house `+0x8C = 0` write above. `FUN_0058A950` reads
`house+0x8C / 10 < 7`; that is a confirmed read, not a recovered
original name or a complete consumer set.

#### Native mapping — historical mismatch inventory (partially superseded)

The rows below preserve the original mismatch audit. The monthly Dinners
arithmetic and raw-byte delivery representation were corrected in §§10.19–10.20;
the remaining writer/source and cadence questions are still not an original
implementation contract.

Numeric `FoodQuality` raw `0/20/30/50/70/90` matches
`cHouseInfo+0x36`, model column 8, and the named mill table on
manual p.48 (`confirmed` unit set only). Matching those enums does
**not** make Native fields isomorphic. The recovered behaviors
differ (`confirmed` mismatches):

| Native `ResidentialUnit` | recovered original used here | verified behavioral mismatch |
| --- | --- | --- |
| `foodSupplyAmount` | word `cHouseInfo+0x12` (Dinners slot 0) | Native now applies the confirmed monthly draw `floor(residents × 25 / 100)` when `foodQualityRequired > 0`; save layout and month-wrap cadence remain non-isomorphic |
| `foodQualityRawValue` | live `cHouseInfo+0x36` | Native `addFoodSupply` **min**-blends and zeros quality whenever stock hits 0 on consume. Recovered market delivery **replaces** if market quality `>` current, else ratio-blends with floats 3/2/0.5/≈0.33. Original zeros `+0x36` on the monthly path when `+0x12 < 1`. Cheat writes `20`; hero case 4 writes `90` — they do **not** zero `+0x36` |
| `lastSuppliedFoodQualityRawValue` | **no recovered original equivalent** in `cHouseInfo` or the `FUN_00590F30` consumer | Native `recordEvolutionSupplies` snapshots current quality iff `foodSupplyAmount >= residents`, else `.none`, on monthly market settlement. `FUN_00590F30` reads **live** `+0x36`. This is not an exhaustive proof that no original global snapshot exists. Do not substitute |
| `suppliesByCommodityID` | `cHouseInfo+0x12` word array | Native consumes food through `foodSupplyAmount`, not a Dinners key in that dictionary. Original monthly food drain is Dinners slot 0 of the same word array as hemp/ceramics. Layout difference is supporting, not by itself proof of absence of an equivalent |

Native has no `house+0x5C` streak and no `house+0x8C` dword from
columns 14/15 on this cadence, no recovered hero `0x5A`
house-visit. The live
`cStall+0x260` blend into `cMarket+0x180` is recovered; mill-pickup
cart `figure+0x13` is the mill `+0x2E4` selected recipe
type-count, not a recovered quality name and not Native
`quality(in:)`. Swift
`OriginalFoodCatalog.quality(in:)` matches **manual
p.48**, not the recovered `+0x36` or `+0x180` stores. Do not
substitute `lastSuppliedFoodQuality` for `FUN_00590F30`; the Native snapshot
remains a bridge until an original equivalent is recovered. Production stays
`unsupportedOriginalProducer`.
**No gameplay implementation contract** until Native
representation/mapping of the recovered type-count→`20 * byte`
blend, hero case-4 identity, and unencoded `+0x36` writer set
required for fidelity are closed. Peddler-vs-buyer
`FUN_004EACD0` exclusivity is closed in §3 (not exclusive).

#### CH/EN (`compare-report.tsv` rows only)

`identical`: `FUN_00408B80`, `FUN_00413B40`, `FUN_00426D10`,
`FUN_00426EA0`, `FUN_00427430`, `FUN_00429DF0`, `FUN_00429E10`,
`FUN_0044CC80`, `FUN_00447600`, `FUN_004AC650`, `FUN_004E6D80`,
`FUN_004E7EB0`, `FUN_004EACD0`, `FUN_00503E20`, `FUN_00510C20`,
`FUN_00511080`, `FUN_005149C0` (constructor only; the `0x5A` store
is not in this function), `FUN_00515770`, `FUN_00516ED0`,
`FUN_00517190`, `FUN_00517330`, `FUN_00518490`, `FUN_00518690`,
`FUN_005188B0`, `FUN_005188D0`, `FUN_00518910`, `FUN_00540710`,
`FUN_00540B40`, `FUN_00540E70`, `FUN_00540F80`, `FUN_00541130`,
`FUN_00541730`, `FUN_00541B80`, `FUN_00543450`, `FUN_00543D90`,
`FUN_00543E50`, `FUN_00543ED0`, `FUN_00544240`, `FUN_00544340`,
`FUN_00544480`, `FUN_00544B30`, `FUN_00544F10`, `FUN_00545100`,
`FUN_00545140`, `FUN_00545150`, `FUN_00545160`, `FUN_00545170`,
`FUN_005463A0`, `FUN_005463F0`, `FUN_00546440`, `FUN_005464E0`,
`FUN_005467A0`, `FUN_00546960`, `FUN_00546C60`, `FUN_00554C00`,
`FUN_00555410`, `FUN_005557D0`, `FUN_005558D0`, `FUN_00555F40`,
`FUN_00555F70`, `FUN_00590F30`, `FUN_005D16D0`, `FUN_005D3580`,
`FUN_005DB4C0`, `FUN_004E3A80`, `FUN_004E3C70`, `FUN_004E44E0`,
`FUN_004E47A0`, `FUN_004E6A70`, `FUN_004E6B70`, `FUN_004EA050`,
`FUN_004EA8C0`, `FUN_004EB9C0`, `FUN_00515780`, `FUN_004C71D0`,
`FUN_004C72B0`, `FUN_004C75C0`, `FUN_004C95F0`, `FUN_004E27E0`,
`FUN_004E1420`, `FUN_005D1E20`.
No `compare-report.tsv` row for `FUN_00416B50`, unsplit
`0x5437B0`, unsplit `0x515120`, unsplit `0x541180`
(`FUN_00541180`), unsplit `0x541760` (`FUN_00541760`), unsplit
`0x4D0270` / `0x4D1810` / `0x4D2970` (figure type-table slot 0
for models 23/24/25), unsplit mill `+0x2E4` `0x555330` /
`+0x2E8` `0x555E40`, unsplit `FUN_004C9310` @ `0x4C9310`,
`FUN_004C7580`, or `cHouseInfo` vtable `+8`
@ `0x517410`; do **not** call them identical. `FUN_005149C0` @
`0x5149C0` ends around `0x51511E`; `0x515120` is the next unsplit
function.

### Monument matching (`FUN_0055AE30`) — control flow recovered; Native unwired

Canonical EN `.text` (`8a6d2df1…6753`, image base `0x400000`).
`FUN_0055AE30` @ `0x55AE30` is `thiscall` (`mov esi, ecx` @
`0x55AE35`). `FUN_0055BCB0` @ `0x55BCB0` is `mov eax, 0x12A4BA8; ret`.
`FUN_00591200` @ `0x591281` and `FUN_0055B6A0` @ `0x55B6AB` call
`FUN_0055AE30` on that object. Empty/no-match returns `0` and does
**not** invent a completed monument. Production stays
`unsupportedOriginalProducer`. Do not pass missing monuments as `0`
and mark the producer supported. Do not guess completion from
`buildingID` alone.

#### Shared match predicate (`FUN_0055AE30` and `FUN_005604C0`)

Both walks use the same ID / root / percent tests (`confirmed` EN
bytes). Integer `cmp eax, 0x64` with `jl` skip / `jge` accept is
`>= 100`, equivalently integer `> 99`.

| check | EN site | polarity |
| --- | --- | --- |
| Building vector count | `FUN_00554C00` `this` = `0x8C7634` (`0x55AE4D`, `0x5604D9`) | `[ecx+4]==0` → `0`; else `([ecx+8]-[ecx+4])>>2`. `cmp eax, 1; jbe` → return `0` if count **≤ 1** (unsigned), i.e. `< 2` |
| Walk start | `FUN_00413B40(1)` `this` = `0x8C7630` (`0x55AE39`, `0x5604C6`) | **Index 0 is never visited.** Slot pointer `+4` per iter; `inc` index; `cmp index, count; jb` |
| Root only | `cmp word [building+0x16], 0` (`0x55AEC2`, `0x5604F0`) | nonzero sub-index skips the pair |
| Exact ID | `sx(building+0x14) == goal+0xC` (`0x55AEE2`, `0x5604F7`) | first arm |
| Special goal IDs | `goal+0xC` is `0x55` **or** `0x56`, **and** `0xFD ≤ (signed word)building+0x14 ≤ 0x10C` (`0x55AEF0` / `jle 0x10C`; `0x560505` / `jg` skip `0x10C`) | second arm; inclusive **253…268**. These `0x55`/`0x56` values are **goal `+0xC` IDs**, not placeable building types |
| Percent | `FUN_00565410(building+0xB4, 0, 0)` (`push 0; push 0; push [building+0xB4]` @ `0x55AED1`, `0x56051D`) | need return **≥ 100** |

`FUN_00565410` @ `0x565410` is `thiscall` with three stack args
(`ret 0xC`). Prologue: `param_1 < 1` → `0`; lookup
`FUN_0047F1B0(param_1)` with `ecx=0x8C7634`. The popularity /
goal calls pass `param_2=0`, `param_3=0`. The `param_2==0`
aggregate `(sumNumerator * 100) / sumDenominator`, or `100` when
the denominator is `≤ 0`, is already closed in
`docs/exe-research/great-wall-map-state.md` (`0x5666C4` /
`0x5666DE`). This note does not re-open that formula.

Call order differs; both predicates must still pass:

- `FUN_0055AE30`: live + type gates, then root, then percent, then ID.
- `FUN_005604C0` @ `0x5604C0`: zeros `goal+8`, no live/type gates,
  then root, then ID, then percent; first hit sets `goal+8=1` and
  returns `1`, else `0`.

#### `FUN_0055AE30`-only gates and return

| gate | EN site | polarity | class |
| --- | --- | --- | --- |
| Live building | `FUN_00426D10` @ `0x426D10`; `push 0; mov ecx, building; call` @ `0x55AE72` | `byte [this+4]` is **1 or 3**; else skip. Stack `0` unused (`ret 4`) | confirmed |
| Monument type | `FUN_00562E80` cdecl thunk → `FUN_00562F70` @ `0x562F70` (`0x55AE85`) | jump table `id-0x4C` over `0…0xC0`: true for **76…86, 92, 93, 253…268** | confirmed |
| Type-2 objects only | `cmp dword [object+4], 2` (`0x55AEB4`); object from `FUN_0047F1B0` with `ecx = this+0x10` | other goal types skipped | confirmed |
| Match side effect | `0x55AF11` / `0x55AF08` | match: `goal+8 = 1` and increment the return count; mismatch in this arm: `goal+8 = 0`. Incomplete / non-root does **not** write `+8` | confirmed |
| Return | `eax` = incremented count (`0x55AF5B`) | matching building-goal pair count: one increment per **(building, type-2 goal)** pair that passed the predicate. The same goal may be counted again for another matching root. **Not** a distinct-goal count. Empty list or no pair returns **0**. Later completed roots can clear an earlier `goal+8` without decrementing the already-added count | confirmed |

`FUN_00591200` uses that matching building-goal pair count as the
monument term of the per-update sum (`monument × 2`, §2). A zero
return is a real zero contribution, not a stand-in for “monument
complete”, and it is not a distinct-goal count.

#### `cMonumentGoal` construct / copy

Live object size `0x10` (`FUN_0055A8E0` @ `0x55A8E0` case `2`
allocates `0x10` and calls `FUN_00559490`). Constructor
`FUN_005603E0` @ `0x5603E0` writes `this+4 = 2`, `this+0xC = 0`,
`this+8 = 0` (`confirmed`). Call `+0xC` only the **goal
building/object ID**. Do not invent a second live value field
from the archive’s extra `UInt32`.

Mission load `FUN_0055F120` @ `0x55F120` constructs via
`FUN_0055A8E0(static+4)` then calls the static record’s vtable
`+0x44` with the live object. Canonical EN bytes immediately after
`FUN_005604C0` at `0x560560` (`thiscall`, dest on the stack,
`ret 4`) copy `[src+8] → [dst+8]` and `[src+0xC] → [dst+0xC]`.
That copy is `confirmed` on the hash-matched EN `.text`. Ghidra
did not split a named function at `0x560560`, and
`compare-report.tsv` has **no** row for it; do **not** call it
CH/EN `identical`. Binding vtable `+0x44` to `0x560560` is
`inferred` from that adjacency and the `FUN_0055F120` call; this
pass did not dump the `cMonumentGoal` vtable slot.

Authored cross-map (`confirmed` file/row, not a completion
oracle):

| ID | source | note |
| --- | --- | --- |
| building types 76…84, 92, 93 | `GameData/Model/EmperorBuildingModels.txt` lines 160–168, 191–192 | `BUILD_TUMULUS` … `BUILD_UNDERGROUND_VAULT`, `BUILD_CLOCK_TOWER`, `BUILD_GRAND_PAGODA` |
| building types 85, 86 | same file lines 169–170 | `BUILD_UNUSED4` / `BUILD_UNUSED5`. **Not** placeable layouts |
| building types 253…268 (`0xFD…0x10C`) | same file lines 337–352 | `BUILD_GREAT_WALL_01` … `16`; each ID is one multipart layout (`Model/Mon_Great_Wall_NN_subs.txt`), not a construction phase |
| goal `+0xC` `0x55` / `0x56` (decimal 85 / 86) | matching walk above; display-family mapping in `DESIGN.md` and `docs/exe-research/great-wall-map-state.md` | After city load, `0x5636B0 → 0x563720` selects earthen family for **task `#85`**, stone for **task `#86`**, ruin otherwise (`confirmed` in those notes). The special match arm uses these as **goal IDs** against layout buildings 253…268. Do **not** treat `0x55`/`0x56` as a building type that the player places |
| Qin-4 archive `cMonumentGoal [85, 0]` | `great-wall-map-state.md`; Native `CampaignGoalArchive` `typeID == 2`, `values[0] == 85` | `typeID` 2 agrees with live `+4 == 2`. `values[0]` is the archive word that the copy path puts in `+0xC` |

`GameData/Model/EmperorEventmsg.txt` has commemorative-monument
and “construction complete” phrase families (e.g. lines 1466–1472,
2350+). They are event text, not this popularity walk’s inputs.

#### Native mapping — not isomorphic; do not implement

Native `MonumentProject.completionPercent` (work + delivered
materials / required), `GrandCanalProjectRuntime.completionPercent`
(segment-stage fraction), and Earthen Great Wall stage counters
are **not** a recovered mapping of `FUN_00565410`’s part-weight
percent. Native `CampaignGoalEvaluation` tests
`completedMonumentBuildingIDs.contains(buildingID)`, not this
pair-count walk, and does not stamp live `goal+8`. There is no
Native walk over a type-2 object vector at `DAT_012A4BA8`, no
mapped `building+4 ∈ {1,3}`, no mapped `building+0xB4` list
index, and no recovered save/load of the matching `goal+8`
side effect.

Missing any of those inputs, production stays
`unsupportedOriginalProducer`. Do not fill a missing monument
with `0`. Do not derive `FUN_00565410 >= 100` from `buildingID`
alone.

#### CH/EN (`compare-report.tsv` rows only)

`identical`: `FUN_00413B40`, `FUN_00426D10`, `FUN_0047F1B0`,
`FUN_004F8210`, `FUN_00554C00`, `FUN_00559490`, `FUN_0055A8E0`,
`FUN_0055AE30`, `FUN_0055B6A0`, `FUN_0055BCB0`, `FUN_0055F120`,
`FUN_005603E0`, `FUN_005604C0`, `FUN_00562E80`, `FUN_00562F70`,
`FUN_00565410`, `FUN_00591200`. Canonical conclusions above are
EN `.text` plus those rows. The copy at `0x560560` has **no**
row. Non-canonical on-disk siblings are not used.

## 4. Pressure and requests (`FUN_005917E0`) — confirmed

| popularity | pressure |
| --- | --- |
| `<16` | −25 |
| `16…25` | −17 |
| `26…35` | −8 |
| `36…49` | 0 |
| `50…60` | 50 |
| `61…70` | 75 |
| `≥71` | 100 |

Population `>199999` zeros pressure. War troop count `≥4`
(`DAT_01312564`) zeros **positive** pressure only.

`DAT_01312564` increment/decrement is `FUN_004EBB40` when
`FUN_004E2560(figure+0x12)` is true: types `0x3A…0x3E` and `0x4E`
(`confirmed`). Native military entities do not yet expose that
lifecycle, so the count is **not** an implemented Native field.

`FUN_005917E0` and `FUN_004AD4A0` do **not** read `DAT_01311FD0`
(`confirmed` negative, §6). When signed pressure changes,
`FUN_005917E0` calls `FUN_00548340(0)`, which **reads** that dword
for overlay-message selection and does not write it.

Request size `ceil(12 × |pressure| / 100)` (`FUN_0043B860`). Arrival
requests use cooldown `DAT_01311FC8`; departure requests use
`DAT_01311FC4`. Making an arrival sets the **departure** cooldown to
2, and vice versa. Departures are suppressed while population `<101`.

## 5. Assignment spawn versus occupancy write

`FUN_004ADA10` house walk (`confirmed`). Local remaining request `i`
starts as `param_1`. Every assignment pass requires
`*(short *)(house + 0x24) > 0` (`confirmed` read). Lifecycle of that
short is in §5.7. Native still has **no** mapped field for it
(`unknown`). Do not summarize the walk as vacancy/capacity only, and
do not equate `+0x24` to Native `observeHousing` road adjacency.

Pass predicates, all conjoined with `house+0x24 > 0`:

1. vacant (`house+0x20 == 0`) with capacity `house+0x22 != 0`, in
   chunks of at most 6;
2. capacity `house+0x22 > 11` with no in-flight immigrant
   (`house+0x32 == 0`);
3. remaining capacity `house+0x22 > 0` with `house+0x32 == 0`.

After each `FUN_004ADE10` call the caller decrements `i` by the
requested people count (`6`, remaining `i`, or `house+0x22`) **without
reading spawn success**. Then `DAT_01311FB0 += (param_1 - i)` and
`DAT_01311FCC += DAT_01311FB0`. Those values are **assigned/accounted**
counts, not proven successfully spawned figure counts. They are
accounted at this assignment, not at walker arrival.

Failed-spawn edge (static control flow only; no runtime frequency is
claimed): `FUN_004ADE10` writes figure fields only when
`FUN_004EA050(...)` returns non-zero. If that spawn returns `0`,
`FUN_004ADE10` returns without linking `house+0x32` or writing
`figure+0x40/+0x64/+0x6e`. `FUN_004ADA10` still decrements `i` around
the call, so `param_1 - i` / `DAT_01311FB0` / `DAT_01311FCC` can
include accounted people for a spawn that did not occur. No guarantee
that `FUN_004EA050` always succeeds is recovered here.

`FUN_004ADE10` (`confirmed`):

- `FUN_004EA050(1, 0xB, DAT_00C5CDFC, DAT_00C5CDFE, …)` spawns
  figure type `0xB` (authored `EmperorFigureModels.txt` row 11
  `immigrant`);
- writes action state `figure+0x40 = 6`;
- stores house id at `figure+0x64` (`immigrant_to` debug string);
- stores people count at `figure+0x6e`;
- links `house+0x32` to the figure id;
- does **not** increment `house+0x20` residents.

Contrast: emigrant spawn `FUN_004ADED0` **does** subtract
`house+0x20` immediately, then spawns type `0xC` with state `6`.

### 5.1 Immigrant `#11` / type `0xB` dispatch (confirmed)

Authored `GameData/Model/EmperorFigureModels.txt` 1-based row **11** is
`immigrant` (combat/speed stats match laborer row 10). Row 12 is
`emmigrant`, row 13 `homeless`. Spawn stores model id **verbatim**:
`FUN_004C9160` writes `figure+0x12` from the spawn type argument, so
`FUN_004ADE10` yields `+0x12 == 0xB`. Default figure constructor
`FUN_004C71D0` (vtable `PTR_LAB_007afe60`) does **not** attach
`FigureFSA` @ `0x4D7310` to type `0xB`.

Think dispatch (`confirmed`, hash-matched EN `8a6d2df1…6753`, image
base `0x400000`):

1. Simulation tick `FUN_005371A0` calls `FUN_004E27E0`.
2. `FUN_004E27E0` walks live figures (`figure+0x16 != 0`) and calls
   vtable `+0x28`.
3. That slot is `FUN_004C7580` (`0x4C7580`):
   `mov al, [ecx+0x12]`; `lea eax, [eax+eax*4]`;
   `jmp dword ptr [eax*8 + 0x84E784]`.
   Index is `type * 40 + 0x84E784`, i.e. slot 9 of table row
   `type - 1`.
4. Type `0xB` therefore jumps to **`FUN_004C9FD0`** (`0x4C9FD0`), the
   `FIG_IMMIGRANT` think stored as table-row-10 slot 9.

Type-table layout at `0x84E788` (10 dwords / row). Debug names sit on
the row whose **slot 0** is indexed by `figure+0x12` in sprite tick
`FUN_004D6C40`, while think uses the trampoline above. Do not treat the
adjacent debug string `FIG_EMMIGRANT` on table row 11 as the immigrant
think: type `0xB` think is `0x4C9FD0`, not `FUN_004CA340`.

| `figure+0x12` | authored row | trampoline think | sprite slot 0 (`FUN_004D6C40`) |
| --- | --- | --- | --- |
| `0xB` (11) | immigrant | `FUN_004C9FD0` | `FUN_004D6D30` (sprite/frame only) |
| `0xC` (12) | emmigrant | `FUN_004CA340` (leave-map; no `+0x64`/`+0x6e` occupancy) | `FUN_004D6CF0` (skipped when `param_1==0`) |
| `0xD` (13) | homeless | `FUN_004CA960` | `FUN_004D6CF0` |

`FUN_004D6D30` is not occupancy. Slot-9 functions have no direct
`call rel32` sites; the trampoline is the recovered indirect edge.

`FUN_004C9FD0`, `FUN_004C7580`, `FUN_004C9160`, and `FUN_004D6D30` are
**absent** from `local/source/split-merged` / `compare-report.tsv`
(corpus gap after `FUN_004D6C40`). Bodies were read from the
hash-matched EN executable. The same byte ranges also match the sibling
`Emperor[CH].exe` in that Wineskin folder; that sibling’s **full-file**
SHA-256 is `0ca8fc07…`, not the documented `dbdeca1e…15a` CH build.
Do not upgrade the new functions to documented-CH identity. Callers
that **are** in `compare-report.tsv` (`FUN_004E27E0`, `FUN_004BA6F0`,
`FUN_004E9620`, `FUN_005188B0`, `FUN_005188F0`, `FUN_0044CC80`,
`FUN_00426D10`, `FUN_00591900`, `FUN_005919A0`, `FUN_004C8B70`,
`FUN_004ADE10`) are listed `identical`.

### 5.2 `FUN_004C9FD0` guards and states 6→7→8 (confirmed)

Preamble (any failure → `figure+0x16 = 2` and return at `0x4CA330`;
**does not** clear `house+0x32` here):

- `esi` = current figure (`DAT_010AEEE4` via `FUN_0047F1B0`);
- `FUN_004EB9C0(id, 8)` return value later passed to `FUN_004E47A0` as
  the state-7 step count;
- `figure+0x80 = 3`, `figure+0x194 = 0`;
- house `edi` = `FUN_0047F1B0(figure+0x64)` (ecx `0x8C7634`);
- `FUN_00426D10(house)` must be true (`house+4` is `1` or `3`);
- `house+0x32` must equal the current figure id;
- house vtable `+0xB8` must return true (`FUN_0042DD40`; §5.8);
- `FUN_005188B0(house+0x14)` must be true:
  `2 ≤ type ≤ 0x11` (building models **2…17**, Vacant House through
  Heavenly Elite).

Then `figure+5` increments and wraps at `0xC` (sprite phase). Switch
on `figure+0x40`:

| `+0x40` | behavior |
| --- | --- |
| `5` | `FUN_004E6280(id)` then sprite tail. Side state, not occupancy. |
| `4` | `FUN_004E6470(id)` then sprite tail. Increments `+0x3e`; at `>= 0x80` sets `+0x16 = 2`. Side state, not occupancy. |
| `6` | Spawn entry. `dec word [figure+0x3e]`; `+0x6f = 1`; `+5 = 0`. Signed `jg` if `+0x3e > 0`: wait (sprite tail only). Else `FUN_004BA6F0(house+0xA, house+0xC, house+7)`. Return `0`: `+0x16 = 2`. Return nonzero: `+0x40 = 7`; `+0x2c/+0x2e = DAT_010C72AC / DAT_010C72A8`; `+0x4c = 0`. |
| `7` | Walk. `+0x6f = 0`; `FUN_004E47A0(id, ebp)`. Then `figure+0x19`: **9** → `+0x40 = 6`, `+0x3e = 1`, `FUN_004E8A30(id, 1)` (reroute). **10** → `house+0x32 = 0` **and** `house+0x24 = 0`, `figure+0x16 = 2` (failure unlink). **8** → `+0x40 = 8`; target `house+0xA/+0xC`; `FUN_004E98A0`; `+0x4c = 0`. Other `+0x19`: sprite tail, remain in 7. |
| `8` | Approach / arrival. See §5.3. |
| other | `+0x40 = 6`. |

Spawn already wrote `+0x40 = 6` and the wait word
`figure+0x3e = (house+0x51 & 0xFF7F) + *DAT_00D62418`, then
`*DAT_00D62418 += 0x32`. `FUN_004AD4A0` does `DAT_00D62418 -= 0x33`
(clamp `>= 0`) before assignment. State 6 decrements that **word**,
matching spawn.

`FUN_004BA6F0` (`confirmed` control flow; tile-flag meaning
**unknown** beyond the recovered reads): walks up to `0x18` neighbor
slots from `(&DAT_00820038 + rot*0x60)` against map cell
`DAT_0101D0C8 + y*0xE4 + x`. On success writes
`DAT_010C72AC = idx % 0xE4` and `DAT_010C72A8 = idx / 0xE4` and
returns `1`; if no candidate remains (`n > 0xB`) returns `0`. Those
two globals are the state-6→7 waypoint, **not** the house tile.
State 7 direction **8** retargets to the house coordinates.

Direction `figure+0x19` (`confirmed` writers; names below are
operational, not original symbols):

- `FUN_005B2730` returns compass `0…7`, or **`8` when current tile
  equals target** (`param_1==param_3` and `param_2==param_4`).
- `FUN_004E8B40` (from `FUN_004E7EB0`): if `figure+0x42 < 1`, set
  `+0x19` from `FUN_005B2730`; if that value is not `8`, force
  **`10`**. If path index `+0x46 <= +0x44`, `FUN_004E8A30` and set
  **`8`**.
- `FUN_004E8BC0` stores **`9`** on collision/block (see
  `roadblock-path-blocking.md`).

### 5.3 Arrival write (`0x4CA265`) and counters (confirmed)

State `8`: `figure+0x14 = 1`; `FUN_004E9620(id, 1)`. That helper
returns `1` when remaining Bresenham lengths
`(short)figure+0x5C + (short)figure+0x5A < 1` (`confirmed` predicate).
If the return is **not** `1`, skip the occupancy block (no
`house+0x20` add, no `house+0x32` clear) and only set `+0x6f` from
`figure+0x48`.

If the return **is** `1`:

1. `figure+0x16 = 2` **before** the resident write.
2. Capacity `ebp = FUN_0044CC80(row, 0x11)` where `row` is `0xB`
   when `house+0x14 == 0xB` (Unocc Elite), else `house+0x16`.
3. If `house+0x20 == 0` (empty house):
   - if capacity `< 0`, treat as `0`;
   - if capacity `< (uint8)figure+0x6e`, clamp `figure+0x6e` down to
     that capacity;
   - `FUN_005188F0(house+0x14)` is true for `1 < type < 0xB`
     (models **2…10**, common housing);
   - if that is true **and** `DAT_00D62408 == 0`, call house vtable
     `+0x230(3)` (`FUN_00518DE0`; §5.10);
   - if that is false **and** `DAT_00D62408 == 0`, call
     `+0x230(0xD)`;
   - if `DAT_00D62408 != 0`, skip `+0x230`. Method identity and
     this site’s skip polarity are §5.10. `DAT_00D62408` writer
     and meaning remain **unknown**.
4. `eax = house vtable +0x1E4()` (`FUN_00416B50`; §5.9). If
   `*(byte *)(eax + 0x3C) != 0`, **skip** the add/`FUN_00591900`
   pair. Original name of that `cHouseInfo` byte is **unknown**.
5. If `+0x3C == 0` (`0x4CA260…0x4CA27E`):
   - **`add word [house+0x20], movzx byte [figure+0x6e]` at
     `0x4CA265`**;
   - `house+0x22 = capacity - house+0x20`;
   - `FUN_00591900((uint8)figure+0x6e)`.
6. **Always** `house+0x32 = 0` after that block, even when `+0x3C`
   skipped the add.

`FUN_00591900` (`confirmed`): `DAT_01311F90 = count`; `push 5`;
`FUN_005919A0(count)`. The immediate `5` is **unread**
(`FUN_005919A0` uses only `esp+4`). Then
`DAT_0130F988 += count` (city population), clamp `>= 0`,
`jmp FUN_00590A50` (high-water `DAT_0131257C`). This is the
population effect of a successful immigrant occupancy write. It is
**not** `DAT_01311FCC`.

Same-tick despawn: `FUN_004E27E0` after think, if `+0x16 == 2` and
`+0x12 != 0`, calls `FUN_004EA080(id)`.

### 5.4 `house+0x32` cleanup and failure (confirmed opcodes)

| site | `house+0x32` | `house+0x24` | `figure+0x16` |
| --- | --- | --- | --- |
| State 8, `FUN_004E9620 == 1` | `0` | unchanged | `2` (before the add) |
| State 7, `+0x19 == 10` | `0` | **`0`** | `2` |
| State 6, `FUN_004BA6F0 == 0` | unchanged here | unchanged | `2` |
| Preamble guard fail | unchanged here | unchanged | `2` |
| `FUN_004ADA10` start-of-pass scavenger | `0` if linked figure `+0x16 != 1` | unchanged | n/a |

`FUN_004C8B70` death tail (`0x4C909E`): tests **`figure+0x64 != 0`**,
then looks up an object with **`figure+0x62`** and writes that
object’s `+0x32 = 0`. Immigrant spawn writes the house id to
`+0x64` only; `FUN_004C72B0` zeros `+0x62`. Whether type-`0xB`
death therefore unlinks the target house is **not proven**. Do not
cite this site as confirmed immigrant-house unlink. Stale
`house+0x32` after preamble/state-6 fail is cleared by the
`FUN_004ADA10` scavenger when the figure is no longer live
(`+0x16 != 1`), or immediately on the state-7/`+0x19==10` path.

Zeroing `house+0x24` on direction `10` is a **confirmed write**.
Native mapping of `+0x24` remains **unknown**; lifecycle is §5.7.

### 5.5 Distinct vagrant writer at `0x4CB1CD` (confirmed; not immigrant)

A second `movzx` from `figure+0x6e` / `add word [house+0x20]` lives at
`0x4CB1C9` / **`0x4CB1CD`**, inside `FUN_004CA960` (type-`0xD` /
`FIG_VAGRANT` think). It calls **`FUN_00591930`**, not
`FUN_00591900`: `DAT_01311F8C -= count` then `FUN_005919A0(count)`
(unread immediate `4`). Emigrant think `FUN_004CA340` has **zero**
`house+0x20 += figure+0x6e` adds. Do not use `0x4CB1CD` as the
immigrant arrival write.

### 5.6 Negative searches / false positives

- `local/source/split-merged` C has **no** `house+0x20 += figure+0x6e`;
  the writers exist only in the EN `.text` opcode scan (two sites
  above). Corpus-only search is insufficient.
- `FUN_00408B40` `+0x6e` is building labor, not figure people count.
- `immigrant_to` string is a debug overlay (`Not_watching_a_figure` @
  `0x5BE170`), not the think dispatcher.
- Type-table `case 0xb` hits in `FUN_004E47A0` are movement-mode
  enums, not figure model id.
- `FigureFSA` @ `0x4D7310` is a generic constructor, not type-`0xB`
  occupancy.
- `FUN_004AE1A0` writes `house+0x20` only on negative-capacity
  homeless spawn (`FUN_004AE150` type `0xD`), not immigrant arrival.
- Assigned `DAT_01311FB0` / `DAT_01311FCC` remain assignment
  accounting, **not** arrival success.

Folding walker travel into instant `admitResidents` remains
forbidden. The original write is this per-model immigrant
think/state machine, not an assignment-tick side effect.
Production still must not spawn walkers or enable the
migration producer: Native food mapping / Native monument mapping /
war / mode / `house+0x24` / `DAT_00D62408` writer and meaning remain
unresolved. The `FUN_00590F30` and `FUN_0055AE30` walks themselves
are §3.
`cHouseInfo+0x3C` method identity and `FUN_004C9FD0` gate polarity
are closed (§5.9); original semantic name, complete writer/lifecycle
set, and Native mapping are not. House vtable `+0x230` method
identity and empty-house skip polarity are closed (§5.10). The
post-call pairs `(+0x14,+0x16)=(3,0)` and `(13,10)` map to Native
`houseLevelID` 0 and 10. Original vacant types are building IDs 2
and 11. Native `ResidentialUnit` representation/lifecycle of those
two states, walker-arrival type-switch timing `2→3` / `11→13`,
complete caller set, and original symbol name remain unclosed.

`FUN_004ADC90` departure assignment walks occupied houses by
`house+0x16` buckets and calls `FUN_004ADED0`. It does **not** read
`house+0x24` (`confirmed` negative). Road-adjacent-only departure
filtering is **not** a recovered house-walk predicate.

### 5.7 Residential `+0x24` lifecycle (2026-08-14)

Same signed short as `FUN_004ADA10` and the immigrant state-7
direction-10 zero at `0x4CA157`. Object layout matches the
`FUN_005177B0` → `DAT_010BFEF0` house list: `+0xA/+0xC` tile,
`+0x14` model, `+0x16` evolution, `+0x20` residents, `+0x22`
remaining capacity, `+0x32` in-flight figure, `+0xB4` id.

**Value source (`confirmed`).** Refresh methods zero `house+0x24`,
then store the low 16 bits of per-cell DWORD `DAT_01391FE0[cell]`.
`FUN_00416400` does **not** search for an access cell: it uses
`building+0x10` as the cell index and copies its own `+0xA/+0xC`
into `+0x2A/+0x2C`. Direct store @ `0x416424`:
`mov dx, word ptr [edi*4 + 0x1391FE0]`; `mov [esi+0x24], dx`.
Type-specific sister refreshers (`FUN_00426DF0`, `FUN_004F01F0`,
`FUN_00507950`, `FUN_00508D50`, `FUN_005E1D40`) choose an access
cell with `FUN_004BAF40` / `FUN_004BA6F0` (the latter already used
by immigrant state 6) before the same table store. Several of those
also copy `DAT_010C72AC/A8` into `house+0x2A/+0x2C`.
`FUN_00507950` requires terrain bit `0x40` (road) on the candidate
cell before the store.

**Table fill (`confirmed`).** `DAT_01391FE0` is a `0xCB10`-DWORD
cell map. `FUN_004ACFC0` (calendar case `0x15`, immediately before
capacity case `0x16` and assignment case `0x17`) calls
`FUN_005AE140(DAT_00C5CDFC, DAT_00C5CDFE, …)` — the same land-entry
tile used to spawn type `0xB` — then walks live buildings, zeros
`+0x2A/+0x2C`, and calls vtable `+0x84` (the refresher family
above). `FUN_005AE140` flood-fills the map from that seed
(`[seed]=1`, 4-neighbors `n+1` when the pass predicate holds).
A later `FUN_004AD3D0` (case `0x16`) includes a house in
`DAT_0130F994` / `DAT_0130F998` capacity totals only when
`(short)house+0x24 > 0`.

**Other same-layout readers of `+0x24 > 0` (`confirmed`):**
`FUN_004ADD60` (nearest house with capacity and `+0x32==0`) and
`FUN_004ADFB0` (add residents), besides assignment `FUN_004ADA10`
and capacity `FUN_004AD3D0`.

**Unclassified opcode candidates (not confirmed same-layout).**
An EN `.text` `cmp word [r+0x24], 0` scan also hits
`FUN_004AFC50`, `FUN_004E38E0`, `FUN_004AEBD0`, `FUN_004AEEB0`,
and later sites `0x506DCA`, `0x54132E`, `0x541404`, `0x5D2D50`,
`0x5D2FF1`, `0x5D3231`, `0x5D59A7`, `0x5D6122`, `0x5DB79C`,
`0x5DDDA0`, `0x5E1352`. Those sites were **not** re-traced; they
are candidate / negative-search evidence only. Do not treat them
as confirmed house `+0x24` readers.

**Other lifecycle writers/copies (`confirmed`).** Zero writer:
`FUN_005447F0` writes `+0x24 = 0` (function pointer appears as a
vtable entry at `0x7B7070`; also zeros `+0x4A/+0x4C` and sets
`+0x5D` from `param_2`; no direct `call rel32`). Refresh-then-store
writer: `FUN_00543DC0` first zeros `+0x24`, then selects a cell
through vtable `+0x194` and repopulates `+0x24` from
`DAT_01391FE0` in the same refresher. Copy helpers:
`FUN_00426EA0` copies `+0x20…+0x32` including `+0x24`;
`FUN_00540880` (function pointer appears as a vtable entry at
`0x7B6CE0`, no direct `call`) copies `+0x24/+0x2A/+0x2C` from
`FUN_0047F1B0(*(this+0x154))` and returns `+0x24 != 0`. Whether
every house uses that `+0x154` object is **unknown**.

**Debug overlay (`confirmed` strings, not Native names).** Watching
a building (`Not_over_a_building.c`) prints `*(short *)(obj+0x24)`
with label `rome`, `*(byte *)(obj+0x18)` with `roadnet`, and
`*(short *)(obj+0x22)` with `spare_room`. Do not call `+0x24`
`roadnet`; that overlay word is `+0x18`. Do not ship `rome` as a
Native identifier.

**Rejected names (`confirmed` negatives).** Not remaining capacity
(`+0x22` / overlay `spare_room`). Not the in-flight immigrant slot
(`+0x32`; zeroing `+0x24` also drops the house from city capacity
totals). `GameData/Model/EmperorBuildingModels.txt` house columns
are evolve requirements, not this runtime short. No authored model
field maps to it.

**Not named (`inferred` only).** Snapshot of the land-entry cell
flood, gated on a road-bit access cell in some refreshers, is
consistent with “reachable from the immigrant entry road.” That is
**not** a recovered original symbol and is **not** Native
`observeHousing` adjacency. Native mapping remains `unknown`.
Production stays fail-closed.

**False positives / negatives.** Figure `+0x24` is a byte delay in
`FUN_004E9620`; `FUN_004C72B0` zeros figure `+0x24`.
`FUN_0054CC60` `+0x24` is a `0xB4`-stride record, not a house.
`FUN_004090F0` `param_1+0x24` is an `int*` slot (byte `+0x90`).
Immediate `mov word [r+0x24], imm16` with `modrm=0x44` is SIB/disp
noise, not this field. `FUN_004C9FD0` is absent from
`split-merged`; the direction-10 write is EN `.text` @ `0x4CA157`.
Callers/helpers that exist in `compare-report.tsv`
(`FUN_004ADA10`, `FUN_004AD3D0`, `FUN_004ACFC0`, `FUN_00416400`,
`FUN_00426DF0`, `FUN_004F01F0`, `FUN_00507950`, `FUN_00508D50`,
`FUN_004BAF40`, `FUN_005AE140`, `FUN_005447F0`, `FUN_00540880`,
`FUN_004ADC90`) are listed `identical`.

### 5.7a `FUN_004BA6F0` footprint candidate rows (2026-08-30)

The candidate-offset table used by `FUN_004BA6F0`, `FUN_004BAF40`, and the
related neighborhood predicates is present as `DAT_00820038`. In both
canonical PE files, the initialized-data slice at file offset `0x420038`,
covering rows `0…6` (`0x2A0` bytes), has SHA-256
`259afaca30d1e86279c0175f8151089af9b215f1a3fe45ee6ff09ffd2663e50d`;
the EN and CH slices are byte-identical. The function indexes row
`footprintSide * 0x60`, walks at most 24 signed DWORDs, and stops at the
first zero. The nonzero rows are exact perimeter offsets in a 228-cell-wide
row-major map:

| row / side | nonzero slots | first → last local offsets |
|---|---:|---|
| 1 | 4 | `(0,-1) … (-1,0)` |
| 2 | 8 | `(0,-1) … (-1,0)` |
| 3 | 12 | `(0,-1) … (-1,0)` |
| 4 | 16 | `(0,-1) … (-1,0)` |
| 5 | 20 | `(0,-1) … (-1,0)` |
| 6 | 24 | `(0,-1) … (-1,0)` |

The concrete rows are now represented by
`OriginalMultipartMonumentRoutingCatalog.roadAccessOffsets`, including the
previously absent sides 3, 5, and 6, with independent Core coverage. This
only closes the geometric candidate ordering. Eligibility still depends on
live object/terrain flags (`DAT_00F6A9E0`, `DAT_00FC3750`) and, for house
refresh, the complete provider/object registry; those mappings remain
**unknown**, so migration production remains fail-closed.

**Evidence class:** **confirmed** for the EN/CH bytes, row stride, slot
counts, zero termination, and local offset order; **unknown** for the
semantic meaning of each object/terrain flag and the Native map projection.

### 5.7b `FUN_004E38E0` uses `house+0x24` as a live-house selector gate (2026-09-01)

The previously unclassified `cmp word [object+0x24]` in
`FUN_004E38E0 @ 0x4E38E0` is now traced through both of its corpus-visible
callers. The function walks the active object vector in existing order and,
after `FUN_00426D10(0)` succeeds, accepts the first object whose house
vtable `+0xB8` callback is true, whose `house+0x24` is positive, and whose
`house+0x20` resident count is positive. It returns that house's
`cHouseInfo`-style coordinates (`+0x2A/+0x2C`) and registry short (`+0xB4`)
through the caller-provided outputs. If no such house exists, it falls back
to `DAT_01312010` and returns that object's `+0x2A/+0x2C`; otherwise all
outputs are `-1`.

The direct caller `FUN_004C8B70 @ 0x4C8B70` is the figure-removal tail for
the model family accepted by `FUN_005EA4D0` (IDs `0x38…0x3E` and
`0x40…0x44`). When the returned house id is positive and its enclosing
figure state permits the branch, the caller decrements the selected house's
`+0x20` by one and invokes `FUN_00591920(1)`. The second caller,
`FUN_0054BAB0 @ 0x54BAB0`, is a multi-figure relocation path; it uses the
returned coordinates/id to retarget a live figure before its subsequent
state update. The `FUN_0054BAB0` call is reached only under its own
figure/route predicates, so this is not evidence that every `+0x24`-positive
house is a migration destination.

`FUN_004E38E0`, `FUN_004C8B70`, `FUN_0054BAB0`, `FUN_005EA4D0`, and
`FUN_0054B940` are all `identical` in `local/source/compare-report.tsv`.
This closes one concrete consumer of `house+0x24`: it participates in a
positive-live-house selection gate and can precede a one-resident decrement.
It does **not** prove an original semantic name, replace the recovered
land-entry-flood source, or authorize Native mapping of `house+0x24`; the
remaining refresh writers/readers and object-registry projection are still
unknown, so Qin production remains fail-closed.

**Evidence class:** `confirmed` for the selector predicates, output fields,
fallback, caller edges, figure-model filter, and EN/CH identity; `unknown`
for the field's semantic name, complete consumer set, and Native projection.

### 5.8 House vtable `+0xB8` (`FUN_0042DD40`, 2026-08-14)

Object factory `FUN_0042D360` (`confirmed`). First call is
`FUN_005188B0(param_1)`: `cmp eax, 2` / `jl` fail; `cmp eax, 0x11` /
`jg` fail; else `mov al, 1; ret` (fail `xor al, al; ret`). Every
building ID **2…17** returns true and takes the house arm:
`FUN_0040AE80(0x10C)` then `FUN_0042D480`. Those IDs do **not** enter
`FUN_0051C660`. `FUN_005188D0` (elite 11…17) is **not** used here;
common and elite share one class.

`FUN_0042D480` (`confirmed` last vfptr write). `FUN_00426C90()` on
`this`; `lea ecx, [esi+0xC8]` / `FUN_00517190()` (subobject, vtable
`0x7B5C44`, **not** the house vfptr); then
`mov dword [esi], 0x7ABA38`. `FUN_00516AB0` is the same allocator +
`FUN_0042D480`.

Final vtable `0x7ABA38` (`confirmed` RTTI). Dword at `0x7ABA34` is
COL `0x7CFAD0`; type descriptor `0x817938` name `.?AVHouseBldg@@`.
Slot `+0xB8` @ `0x7ABAF0` is **`FUN_0042DD40` @ `0x42DD40`**.

`FUN_0042DD40` (`confirmed` EN `.text`; corpus gap):
`mov dl, [ecx+9]; xor eax, eax; test dl, dl; setne al; ret`.
Returns 1 iff `house+9 != 0`. No stack args.

Call polarity (`confirmed`; any `al==0` skips):
`FUN_004C9FD0` call `[edx+0xB8]` @ `0x4CA03F`, `test al, al` @
`0x4CA045`, `je 0x4CA330` @ `0x4CA047`;
`FUN_004ADD60` call `[eax+0xB8]` @ `0x4ADDA5`, `test al, al` @
`0x4ADDAB`, `je 0x4ADDEA` @ `0x4ADDAD`;
`FUN_004ADFB0` call `[edx+0xB8]` @ `0x4AE039`, `test al, al` @
`0x4AE03F`, `je 0x4AE0E5` @ `0x4AE041`.
The three sites require a **true** return, then apply their own
`+0x24` / capacity / type checks. This predicate is **not**
`house+0x24`, remaining capacity `+0x22`, live-state
`FUN_00426D10` (`+4` is `1` or `3`), or the `+0x1E4` / `+0x3C` gate.

Byte `+9` writers (same layout; **not** a recovered original name):
`FUN_00518B70` writes `+9 = 1` after `FUN_00428C10` zeros it.
`FUN_0042AAA0` first calls `+0xB8`; only if that returns true **and**
`(short)param_1[8]` (`house+0x20` residents) is nonzero does it call
`FUN_00591920`, zero `+0x20`, and zero `+9`. Overlay
`Not_over_a_building.c` tests `obj+9 == 0` as a skip; no debug label
for that byte. `GameData` house columns do not map to it. Native name
remains **unknown**. Do not treat `+9` as occupancy.

**Rejected class (`confirmed` negative).** `FUN_0051C9A0` /
vtable `0x7B65E4` is `.?AVcIndustrialBldg@@`. Its `+0xB8` is
`FUN_00413A00` (`xor al, al; ret`). IDs 2…17 never take that path
from `FUN_0042D360`.

CH/EN: `FUN_0042D360`, `FUN_0042D480`, `FUN_005188B0`,
`FUN_00517190`, `FUN_00516AB0`, `FUN_00426C90`, `FUN_004ADD60`,
`FUN_004ADFB0`, `FUN_00426D10`, `FUN_00518B70` are `identical` in
`compare-report.tsv`. `FUN_0042DD40` and `FUN_004C9FD0` are absent
from `split-merged` / `compare-report.tsv` (EN `.text` only).

### 5.9 House vtable `+0x1E4` / `cHouseInfo+0x3C` (2026-08-14)

`HouseBldg` `0x7ABA38 + 0x1E4` @ `0x7ABC1C` is **`FUN_00416B50` @
`0x416B50`** (`confirmed` EN `.text`; corpus gap):
`lea eax, [ecx+0xC8]; ret`. Returns the subobject constructed in
`FUN_0042D480` (`lea ecx, [esi+0xC8]; call FUN_00517190`).

That subobject’s vfptr is `0x7B5C44`. COL `0x7D3408` / type
descriptor `0x854300` name `.?AVcHouseInfo@@` (`confirmed` RTTI).
`cHouseInfo+0x3C` is `HouseBldg+0x104`, **not** `HouseBldg+0x3C`.

`FUN_004C9FD0` state-8 arrival gate (`confirmed` opcodes), after the
empty-house `+0x230` block and before the occupancy add:
call `[eax+0x1E4]` @ `0x4CA253`; `mov cl, [eax+0x3C]` @ `0x4CA259`;
`test cl, cl` @ `0x4CA25C`; `jne 0x4CA281` @ `0x4CA25E`.
Nonzero **skips** `house+0x20 += figure+0x6e` @ `0x4CA265` and
`FUN_00591900`. Zero falls through to that add. `house+0x32 = 0` at
`0x4CA281` runs either way. Distinct from `house+0x24`, `house+9`,
remaining capacity `+0x22`, and occupancy `+0x20`.

**Writers of `cHouseInfo+0x3C` via this object (`confirmed`; not a
complete map).** Constructor `FUN_00517190` @ `0x51724F` /
`0x51725E`: `lea ecx, [esi+0x3C]`; `mov byte [ecx], 0`.
`FUN_004681A0` after `+0x1E4()`: call `FUN_00591920(count)` on the
converted count, then subtract the same count from `house+0x20`,
then write `cHouseInfo+0x3C = param_2` and `house+0x98`
(`p[0x26]`) `= 0x20`. Proven caller `FUN_00468420` passes `2`.
After `FUN_004681A0(param_1, 2)`, `FUN_00468420` loops three times
calling `FUN_004EA050(..., 0x12, ...)`.
`GameData/Model/EmperorFigureModels.txt` decimal ID 18 (`0x12`) is
“Disease Carrier”. Confirmed relationship: the value-`2` path
subsequently generates three Disease Carriers. That associates
`cHouseInfo+0x3C` with disease-carrier handling; it does not name
the byte, recover a threshold, or close its semantics. Calendar
case `6` (`FUN_004AC2B0`) calls `FUN_005185C0`: live `+0xB8` houses
with `+0x3C != 0` and `+0x98 > 0` decrement `+0x98` and write
`+0x3C = 0` when residents are 0 or the counter hits 0.

**Same-identity readers (`confirmed`, not a name).**
`FUN_004AD3D0` (capacity totals use current residents instead of
model capacity when `+0x3C != 0`); `FUN_00519F30`; `FUN_0058C420`
(`+0xB8` then `+0x3C != 0` sets a status bit). Overlay
`Not_over_a_building.c` prints other `+0x1E4` bytes (`+0x2A…+0x38`)
and has **no** label for `+0x3C`. This pass did not find a mapping
in authored house columns. Do not ship `cHouseInfo` or
“needs-object” as a Native field identifier for this byte.

**Rejected (`confirmed` negatives).** `FUN_004C9C80` writes figure
`+0x3C`. `FUN_00426EA0` copies `HouseBldg+0x3C` as a short, not
`cHouseInfo+0x3C`. `cIndustrialBldg` `0x7B65E4+0x1E4` is
`0x40E630`, not `FUN_00416B50`.

CH/EN: `FUN_00517190`, `FUN_004681A0`, `FUN_00468420`,
`FUN_005185C0`, `FUN_004AD3D0`, `FUN_00519F30`, `FUN_0058C420`,
`FUN_004AC2B0` are `identical`. `FUN_00416B50` and `FUN_004C9FD0`
are absent from `split-merged` / `compare-report.tsv`.

### 5.10 House vtable `+0x230` / `DAT_00D62408` (2026-08-14)

`HouseBldg` `0x7ABA38 + 0x230` @ `0x7ABC68` is **`FUN_00518DE0` @
`0x518DE0`** (`confirmed` EN `.text`; corpus gap). `thiscall` /
`ret 4`. `ecx` is the `HouseBldg`. The dword `0x518DE0` occurs
once in the image, at that slot. No `E8` rel32 to it.

`FUN_004C9FD0` state-8 empty-house gate (`confirmed` opcodes), after
`house+0x20 == 0` @ `0x4CA1FC` and the capacity clamp, before
`+0x1E4`. Execution order: `call FUN_005188F0` @ `0x4CA21C`;
`test al, al` @ `0x4CA224`; `mov eax, [0xD62408]` @ `0x4CA226`
(does not change flags); `je 0x4CA23F` @ `0x4CA22B`. The `JE`
uses the common predicate from `0x4CA224`, not the DAT load.
Common-true (`0x4CA22D`): `test eax, eax` / `jne 0x4CA24F`;
`push 3`; `call [eax+0x230]` @ `0x4CA237`; `jmp 0x4CA24F`.
Common-false (`0x4CA23F`): `test eax, eax` / `jne 0x4CA24F`;
`push 0xD`; `call [edx+0x230]` @ `0x4CA249`. Nonzero
`DAT_00D62408` **skips** both calls (`test eax` in each arm). The
method’s `al` is unread. Occupied houses (`+0x20 != 0`) jump to
`0x4CA24F` and never call it. Distinct from `house+0x24`,
`house+9`, occupancy `+0x20`, remaining capacity `+0x22`, and
`cHouseInfo+0x3C`.

`FUN_00518DE0` (`confirmed` opcodes). Saves old `house+0x14` /
`+0x16`. `bl = FUN_005188F0(old +0x14)` (common IDs **2…10**);
elite flag `= FUN_005188D0(old +0x14)` (IDs **11…17**). Then
`house+0x14 = param` and `house+0x16 = 0` if `param <= 3`, else
`param - 3`. If `FUN_005188F0(new +0x14)`: require old-common else
restore both words and `return 0`; else table
`[new+0x16]*4 + 0x8232F8`. If new type is not common: require
old-elite else restore and `return 0`; else table
`[new+0x14]*4 + 0x85410C`. Success arms call `FUN_00408170` on that
dword, optionally add `(*(byte *)(*(house+0x10) + 0xF1E780)) & 1`
(skipped in the non-common arm when `+0x14 == 0xB`), then
`FUN_004B72B0`, and `return 1`. Meaning of `0xF1E780` is
**unknown**. `FUN_004B72B0` writes map cells including
`DAT_00FC3750`; this pass does not name those helpers.

**Authored cross-evidence (`confirmed` relationship, not a method
name).** `GameData/Model/EmperorBuildingModels.txt` decimal ID 3
(line 87) is “Shelter House”; ID 13 (`0xD`, line 97) is “Modest
Elite”. `GameData/Audio/BuildingSounds.txt` rows 26 / 36 use the
same IDs. `FUN_004C9FD0` passes those immediates into a method that
writes `house+0x14` (the building-type word already used as
`Unocc Elite` `0xB` / common 2…10). That associates the
empty-house call with those model IDs. It does not name
`FUN_00518DE0`. Original empty-house types are authored ID 2
(line 86) “Vacant House” and ID 11 (line 95) “Unocc Elite”;
`BuildingSounds.txt` rows 25 / 34 use the same names.
`BuildingSpriteCatalog` already has vacant common/elite sprites.
`GameData/Model/EmperorFigureModels.txt` decimal 3 / 13 are
“zguy” / “homeless”; those are **not** this parameter.
`EmperorBuildingModels.txt` `ALL HOUSES` “1: Shelter” is a
1-based house-tier label; Native `houseLevelID` is 0-based, so
tier 1 Shelter corresponds to Native level 0. That is not the
building ID / `house+0x14` numbering.
`EmperorText.txt` / event tables: this pass did not find a mapping
for `DAT_00D62408` or for this method.

**Native post-call values (`confirmed` relationship; not the whole
original layout).** `ResidentialUnit.houseLevelID` and
`BuildingSpriteCatalog.housingBuildingID(forHouseLevelID:)` use
`buildingID = levelID + 3`. After `+0x230(3)`: `house+0x14 = 3`,
`house+0x16 = 0` → Native `houseLevelID` 0 / building ID 3. After
`+0x230(0xD)`: `house+0x14 = 13`, `house+0x16 = 10` → Native
`houseLevelID` 10 / building ID 13. Do not extrapolate that formula
to other `+0x14` / `+0x16` pairs. Original vacant type IDs 2 and
11 are **confirmed**. Still unclosed: Native `ResidentialUnit` /
simulation representation and lifecycle of those two pre-arrival
states, walker-arrival type-switch timing `2→3` / `11→13`,
complete `+0x230` caller set, and original symbol name.

**`DAT_00D62408` (`confirmed` reads; writer/meaning `unknown`).**
RVA `0x962408` sits in `.data` BSS (beyond the `0x7B000` raw
range), so the image does not initialize it (loader zero). Whole
file search for `08 24 D6 00` hit **three** `.text` disp32 bytes
and **no** `.rdata` / initialized-`.data` address constant. The
`mov` instruction starts are `mov eax, [0xD62408]` @ `0x42D9A0`
(`FUN_0042D9A0`, skip its walk when **`== 1`**);
`mov ecx, [0xD62408]` @ `0x4ACD00` (`FUN_004ACD00`, return `!= 0`);
this site @ `0x4CA226` (skip `+0x230` when **`!= 0`**). The pattern
hits at `0x42D9A1` / `0x4ACD02` / `0x4CA227` are the disp32, not
the `mov` addresses. No absolute writer (`C7 05` / `A3` /
`89 0D` and the same disp32) was found. Neighbor BSS dwords
`DAT_00D62400` / `04` / `0C` have their own writers; they are
**not** this dword. Register-indirect stores remain possible and
**unknown**.

**Same-identity extras (not a complete caller map).**
`FUN_00519180` / `FUN_00519200` (`identical`) call `[this+0x230]`
with `3` / `4` after `FUN_004ACD00` (nonzero DAT skips). They read
`house+0x20` and `+0x1E4`. Other `[r+0x230]` opcode hits are **not**
this method unless the object’s vfptr slot holds `0x518DE0`.

**Rejected (`confirmed` negatives).** `cIndustrialBldg`
`0x7B65E4+0x230` is `0x51CF40`, not `FUN_00518DE0`. Do not treat
param `3` / `0xD` as figure types, `house+0x24`, `house+9`,
capacity, occupancy, or `cHouseInfo+0x3C`.

CH/EN: `FUN_005188F0`, `FUN_005188D0`, `FUN_00408170`,
`FUN_004B72B0`, `FUN_004ACD00`, `FUN_0042D9A0`, `FUN_00519180`,
`FUN_00519200` are `identical`. `FUN_00518DE0` and `FUN_004C9FD0`
are absent from `split-merged` / `compare-report.tsv`.

## 6. `DAT_01311FD0` (advisor-mode dword)

City-stats object `DAT_0130F960` + `0x2670` is `DAT_01311FD0`
(`confirmed` arithmetic: `0x0130F960 + 0x2670 = 0x01311FD0`). The
dword lives in BSS (PE `.data` virtual size `0x1645F9C`, raw
`0x7B000`; loader zeros it unless written). Do **not** treat the
Ghidra name or advisor-string cluster as an original symbol.

This dword is an **advisor / overlay-message selector**.
`FUN_0053B850` branches on **0 / 1 / 2 / other**. It is **not**
read by `FUN_005917E0`, `FUN_004AD4A0`, or the recovered
assignment/arrival producer chain (`FUN_004ADA10` /
`FUN_004ADE10` / `FUN_004C9FD0`), so **any** value of the field
is outside that recovered pressure / request / spawn / occupancy
math. Init-zero and save/load writers are below. The gameplay /
runtime writer, the full value domain, and the source of any
nonzero state remain `unknown`. Native must not approximate the
field as always-0 to enable migration, and must not wire nonzero
advisor/overlay modes (1 / 2 / other). A loaded save may persist
whatever dword the stream held, not only 1 or 2.

### 6.1 Authored data (not a variable mapping)

Searched 2026-08-14. Hits are player-facing copy or walker audio.
None is a model field, campaign flag, or ini key that writes this
dword. Do not guess the strings below as the DAT’s original name.

| source | what was searched | result |
| --- | --- | --- |
| `GameData/Model/*.txt` | `immig` / `emig` / `migrat` / `open city` / `closed city` (ASCII) | only `EmperorFigureModels.txt` line 116 figure ID **11** `immigrant` |
| `GameData/Emperor.ini` | same ASCII | no hit (`CDDrive`/`RAM`/`CPU`/`PlayIntroMovie` only) |
| `GameData/DATA/status.txt` | same ASCII | no hit |
| `GameData/Audio/*.txt` | same ASCII plus GB18030 `移民` | `FigureSounds.txt` line 152 figure key `immigrant` (hit/die sounds) |
| `GameData/Campaigns/*.pak`, `Cities/*.map` | ASCII `immig`/`emig`/`migrat`/`OpenCity`/`ClosedCity`/`open_city` | no hit |
| `GameData/Model/EmperorEventmsg.txt` | GB18030 `移民`/`迁入`/`迁出` | `PHRASE_road_to_rome2_initial_announcement` (inspectors cleared a road-blocking building so immigrants and caravans can enter/leave). Access-event copy, not this dword |
| `GameData/EmperorText.eng` / `.txt` group 55 | rows consumed by `FUN_0053B850` | see consumer table; **not** a writer |
| `GameData/EmperorMM.eng` / `.txt` | immigration/emigration help | in-game manual prose (housing, popularity, walkers). No open/close-city toggle |
| `GameData/EmperorManual.pdf` | pypdf text extract, 151 pages | p.27–28 Population Ministry “Migration Status” / “Cause or Effect of Migration Status” describe the advisor display from popularity; p.34 “Attracting Immigrants” / “City Popularity”; p.35 Immigrant/Emigrant walkers. **No** player control that opens or closes the city to immigrants |
| `GameData/Emperor.chm` | `strings` on the compressed ITSF | no recoverable `Open city` / `Closed city` / `Immigration` body text in this environment (no CHM extractor). TOC-like `immig`/`emig` hits only; not used as a field mapping |

Group 55 rows 20–23 (`EmperorText.eng` exact; Chinese from
`EmperorText.txt` GB18030, the cluster already used by
`FUN_0053B850`):

| row | English | Chinese |
| --- | --- | --- |
| 20 | `People wish to come to the city.` | `人们希望迁居你的城市` |
| 21 | `People are leaving the city.` | `人们正在离开你的城市` |
| 22 | `Population migration is stable.` | `人口数较稳定` |
| 23 | `Immigration and emigration are balanced.` | `迁入人数和离开人数基本平衡` |

Row 24 `Immigrants aren't coming.` / `移民还没有来.` is the next
authored string; `FUN_0053B850` “other mode” draws **row 23**
(`0x17`), not row 24.

`FUN_0053B850` draws status `0x14…0x17` as group 55 rows 20–23
(`confirmed` in `population-advisor-housing-capacity.md`). Those
rows are **outputs** of the mode check, not evidence of a writer.

### 6.2 Direct `.text` xrefs (canonical EN `8a6d2df1…6753`)

Whole-file pattern `D0 1F 31 01` (`0x01311FD0`): **three** hits, all
in `.text`, all instruction-start `A1` loads. No `.rdata` / initialized
`.data` address constant. No `push 0x01311FD0`, `mov r32, 0x01311FD0`,
or `lea r, [0x01311FD0]`.

**Reads** (instruction starts, not the disp32):

| VA | bytes | function | next control flow |
| --- | --- | --- | --- |
| `0x53B8FC` | `A1 D0 1F 31 01` | `FUN_0053B850` @ `0x53B850` | `sub eax, 0` then mode 0 / `== 1` / `!= 2` (group-55 status 20–23) |
| `0x54835A` | same | `FUN_00548340` @ `0x548340` | `test eax,eax` / `jne 0x54853B`; mode 1 at `!= 1` returns |
| `0x5D7F86` | same | `FUN_005D7F70` @ `0x5D7F70` | `test eax,eax` / `jne 0x5D811B` |

**Absolute write-class opcodes targeting `0x01311FD0`:** none
(`confirmed` negative). Scanned `A3`, `89 05/0D/15/1D`, `C7 05`,
`C6 05`, `01/09/21/29/31/87 05…`, `FF 05/0D`, `81/83` rmw, `F7 05`.

**`[reg+0x2670]` dword stores (`89` / `C7` mod=2):** one site,
`0x59000F` `89 8A 70 26 00 00` = `mov [edx+0x2670], ecx` in
`FUN_0058FE40` (legacy-layout copy, §6.4). No `add r32, 0x2670`.

**`lea r, [reg+0x2670]`:** eight sites, all inside `FUN_00593140`,
all `push 4; push ptr; call` stream I/O (§6.4). Those are
save/load pointer formation, not a recovered gameplay store of a
mode immediate.

### 6.3 Init / reset writer (`confirmed`)

`FUN_00590A70` @ `0x590A70`:

```
0x590A72  mov ecx, 0xBDA
0x590A77  xor eax, eax
0x590A79  mov edi, 0x0130F960
0x590A7E  xor ebx, ebx
0x590A80  rep stosd
```

Range `[0x0130F960, 0x0130F960 + 0xBDA×4) = [0x0130F960, 0x013128C8)`.
`DAT_01311FD0` is inside that range (offset `0x2670`). This **zeros**
the dword. The same function then writes popularity `0x3C` and other
explicit fields; it has no later store to `+0x2670`.

Immediate `0xBDA` appears once as this count (`0x590A73`). The other
`.text` `DA 0B 00 00` at `0x72AE32` is a `call` rel32, not this loop.

Callers (`E8` to `0x590A70` only):

| call VA | function | when |
| --- | --- | --- |
| `0x42ECBC` | `FUN_0042E6A0` @ `0x42E6A0` | new-city path when `*(i+0x58)==0` |
| `0x5D141D` | `FUN_005D1400` @ `0x5D1400` | reset; afterwards copies a **string** from `DAT_010DE0E4` to `DAT_0130F930` (before `F960`, not this field) |

`rep movsd` sites that mention `0x0130F960` nearby copy the city
**name** to `0x0130F930` (`0x42EDA8`, `0x5D125E`) or use `ecx=F960` as
a `this` for a different call (`0x5B4ED8`, dest is not `F960`). None
bulk-copies onto `DAT_01311FD0`.

### 6.4 Save / load writers (`confirmed` object identity)

`FUN_00593140` @ `0x593140` prologue: `mov esi, ecx`. Every `.text`
caller sets `ecx = 0x0130F960` immediately before the `call`
(`push esi; mov ecx, 0x130F960` at nine sites). No `mov esi, …`
between `0x593149` and the first `+0x2670` lea, so `esi` is still
the city-stats object at the save-arm serialize.

`FUN_0041FBF0` (`mov ax, [ecx+4]` with `ecx=0x0130F958`) supplies
the load `switch` cases **1…7**. `FUN_0040CF90` non-zero takes the
save arm (`FUN_00780642`); zero takes the load arm
(`FUN_00780533`).

| kind | instruction start | bytes / call | effect on `DAT_01311FD0` |
| --- | --- | --- | --- |
| save | `0x593410` | `lea eax, [esi+0x2670]`; `push 4`; `push eax`; `call 0x780642` | **read** 4 bytes to the stream |
| load case 1 | `0x5943A4` | `lea ecx, [esi+0x2670]`; `call 0x780533` | **write** 4 bytes from the stream |
| load case 2 | `0x5952C9` | same shape | write |
| load case 3 | `0x595EA7` | same shape | write |
| load case 4 | `0x596D95` | same shape | write |
| load case 5 | `0x597C79` | same shape | write |
| load case 6 | `0x5985E2` | same shape | write |
| load case 7 | `0x59946C` | same shape | write |

`FUN_00780642` copies memory → stream. `FUN_00780533` copies stream
→ memory. Both take a pointer + length 4 at `this+0x2670`.

Nine `call 0x593140` sites, all `mov ecx, 0x0130F960` at call−6 or
call−5: `0x52FE9E`, `0x53069E`, `0x530C93`, `0x531293`,
`0x531A7B`, `0x532085`, `0x532674`, `0x532E22`, `0x533629` (inside
`FUN_0052FDA0` @ `0x52FDA0`).

**Legacy blob remap** (`FUN_0058FE40` @ `0x58FE40`):
`this` = source buffer, `[esp+4]` = dest. At `0x590009`
`mov ecx, [eax+0x2740]` then `0x59000F` `mov [edx+0x2670], ecx`.
Reached from `FUN_0052FDA0` @ `0x5335EB` `cmp ebx, 2; jg 0x533623`:
the `ebx <= 2` arm `push 0x3014; call 0x780533` into a stack
buffer, then `push 0x130F960; lea ecx, [esp+…] ; call 0x58FE40`.
The `jg` arm is the `FUN_00593140` path. `ebx` is a version
discriminator in that function (`inferred` from the two-arm shape;
the exact word’s original name is not recovered). No `.text` store
to `[reg+0x2740]` exists; `+0x2740` is only read as a source field
of that old blob.

A loaded save can therefore contain **any** persisted dword at this
offset, including nonzero values other than 1 or 2. That does not
identify a gameplay/runtime writer.

### 6.5 Consumer meaning (closed for UI; not a producer contract)

Already tabulated in `population-advisor-housing-capacity.md`:

| value | `FUN_0053B850` status row | notes |
| --- | --- | --- |
| 0 | checker (war / newcomers / housing / signed pressure) | Native’s only wired branch is the screenshot-confirmed zero-capacity arm |
| 1 | row 21 + `FUN_0053B790` reasons | same row as mode-0 negative pressure |
| 2 | row 22 | same row as mode-0 zero pressure |
| other | row 23 | |

`FUN_00548340` / `FUN_005D7F70` use the same 0 / 1 / other split for
overlay / help IDs. No original semantic name is assigned here.

`DAT_01311FD0` is not read by `FUN_005917E0` / `FUN_004AD4A0` or
the recovered assignment/arrival producer chain, so **any** value
of the field is outside that recovered pressure / request / spawn /
occupancy math (`confirmed` non-input). Remaining unknowns are the
gameplay/runtime writer, the full value domain, and the source of
any nonzero state.

### 6.6 Strict negatives (reusable)

Opcode-bounded. These are not a claim that every x86 form was
exhausted (no C6/66-width, arithmetic RMW, SIB, or other-base
alias scan is treated as complete).

- No absolute `.text` hit among the scanned write-class opcodes
  targeting `0x01311FD0` (`A3`, `89 05/0D/15/1D`, `C7 05`,
  `C6 05`, `01/09/21/29/31/87 05…`, `FF 05/0D`, `81/83` rmw,
  `F7 05`).
- No `89` / `C7` mod=2 **dword** store to `[reg+0x2670]` except
  `0x59000F` in `FUN_0058FE40`. `lea [reg+0x2670]` sites are the
  §6.4 stream pointer, not that store encoding. `add r32, 0x2670`
  was not found; SIB and other displacements were not scanned as
  a closed set.
- No second `rep stosd` / `rep movsd` whose dest range is proven
  to include this dword besides `FUN_00590A70`.
- Neighbor `DAT_01311FD4` is a different dword (`FUN_004AF020`
  touches `FD4`, not `FD0`).
- Known consumers `FUN_0053B850`, `FUN_00548340`, and
  `FUN_005D7F70` only read. Event phrase
  `PHRASE_road_to_rome2_initial_announcement` is unrelated access
  copy. This pass did not recover a write in those consumers or
  in the scans above; indirect writers outside that scope remain
  possible and `unknown`.
- Corpus `DAT_01311fd0 =` assignment: **none** (reads only in the
  three consumer functions). That corpus gap is closed for
  **absolute** assignments; it never was proof of “no writer”
  because of the stosd / serialize aliases above.

### 6.7 CH/EN

`FUN_0053B850`, `FUN_00548340`, `FUN_005D7F70`, `FUN_005917E0`,
`FUN_00590A70`, `FUN_0042E6A0`, `FUN_005D1400`, `FUN_0058FE40`,
`FUN_00593140`, `FUN_0052FDA0` are `identical` in
`local/source/compare-report.tsv`. Canonical conclusions above are
EN `.text` plus those identical rows. `decompiled-ch.c` shows the
same three `DAT_01311fd0` reads; no CH-only assignment is in the
corpus. On-disk CH siblings that are **not** hash
`dbdeca1e…15a` are not used.

## 7. Month rollover (confirmed)

`FUN_004AC650` copies `DAT_01311FCC` → `DAT_01312604` and zeros
`DAT_01311FCC` when the 16th slice wraps.

## 8. Native implementation contract (fail-closed)

The original immigrant arrival state machine in §5 is recovered.
That does **not** authorize enabling automatic migration. War,
`house+0x24`, and `DAT_00D62408` writer/meaning remain
unresolved. The `FUN_00590F30` walk is recovered in §3; the
recovered normal market-delivery writer/path of `cHouseInfo+0x36`
is `cMarket+0x2c` @ `0x5437B0` (complete writer set not proven).
Native now matches the confirmed monthly Dinners draw; the remaining
market-delivery blending/cadence and raw-quality mapping are confirmed
non-isomorphic or unresolved, so those fields must not be substituted as
a completed Qin contract. The live `cStall+0x260` blend/store into
`cMarket+0x180` is recovered. Mill-pickup cart `figure+0x13` is
the mill `+0x2E4` selected recipe type-count (§3); player-facing
quality name, Native `quality(in:)` mapping, and the correct Native
representation/mapping remain open. Peddler-vs-buyer
`FUN_004EACD0` exclusivity is closed in §3 (model 24 states 6/7
can reach `cMarket+0x2C`). Food
stays a fail-closed producer input.
No food implementation contract. The `FUN_0055AE30` walk is recovered in §3; Native
percent / object-vector / `+0xB4` / `goal+8` save mapping is
not, so monument stays a fail-closed producer input.
`DAT_01311FD0` init-zero and save/load are
§6; it is not a numeric input to the recovered producer chain.
The gameplay/runtime writer, full value domain, and nonzero-state
source are still `unknown`, so Native nonzero advisor/overlay
modes (1 / 2 / other) stay unwired and the field must not be
forced to 0 as a production default.
`cHouseInfo+0x3C` method identity and `FUN_004C9FD0` gate polarity
are closed (§5.9); original semantic
name, complete writer/lifecycle set, and Native mapping are not.
House vtable `+0x230` method identity and empty-house skip polarity
are closed (§5.10). The post-call pairs `(+0x14,+0x16)=(3,0)` and
`(13,10)` map to Native `houseLevelID` 0 and 10. Original vacant
types are building IDs 2 and 11. Native `ResidentialUnit`
representation/lifecycle of those two states, walker-arrival
type-switch timing `2→3` / `11→13`, complete caller set, and
original symbol name are not. Do not spawn walkers or call
`admitResidents` from the production tick.

**Do:**

- observe Native road-adjacent vacant housing (this Native filter is
  **not** a recovered mapping of original `house+0x24`);
- keep `automaticMigrationAvailability = unsupportedOriginalProducer`;
- leave residents unchanged on the production tick;
- decode legacy count fields, then zero them on the first production
  tick;
- keep confirmed constants and control flow in this research note;
  do not expose them as a production API.

**Do not:**

- fold figure `#11` travel into occupancy;
- drive popularity from `lastSuppliedFoodQuality`,
  `foodQualityRawValue`, `foodSupplyAmount`, or an invented
  shortage streak;
- pass monument / war / mode as `0` and mark the producer supported;
- upgrade `unsupportedOriginalProducer` saves to a supported tag;
- spawn immigrant walkers;
- implement nonzero advisor/overlay modes (1 / 2 / other) or
  render group-55 row 11;
- invent a Great-Wall first-playable state.

## 9. Remaining unknowns

- Original semantic name of `HouseBldg+9` (the byte `FUN_0042DD40`
  tests; complete writer set is not recovered). House vtable
  `+0xB8` itself is §5.8.
- Original semantic name of `cHouseInfo+0x3C`, complete
  writer/lifecycle set, and Native mapping (method identity and
  `FUN_004C9FD0` gate polarity are §5.9).
- Original method name of `FUN_00518DE0`, complete `+0x230` caller
  set, Native `ResidentialUnit` representation/lifecycle of
  pre-arrival vacant building IDs 2 and 11, and walker-arrival
  type-switch timing `2→3` / `11→13` (method identity, empty-house
  skip polarity, original vacant type IDs, and the two post-call
  Native `houseLevelID` pairs are §5.10).
- `DAT_00D62408` writer and meaning (empty-house `+0x230` skipped
  when nonzero; three absolute `.text` reads, no absolute writer).
- `FUN_004BA6F0` neighbor-slot / terrain-flag meaning beyond the
  recovered reads and the `DAT_010C72AC` / `DAT_010C72A8` writes.
- Whether `FUN_004C8B70` type-`0xB` death unlinks the spawn house
  (`+0x64` test vs `+0x62` lookup).
- Gameplay/runtime writer of `DAT_01311FD0`, the full value
  domain, the source of any nonzero state, and the original
  semantic name of the dword (`FUN_0053B850` branches 0 / 1 / 2 /
  other; absolute xrefs, `FUN_00590A70` zero, and `FUN_00593140` /
  `FUN_0058FE40` persistence are §6; non-input to the recovered
  producer chain is confirmed). Do not treat “no
  `DAT_01311FD0 =` in the decompiled corpus” as the full writer
  story, and do not treat 1/2 as the only persistable nonzero.
- Native military-figure mapping for `DAT_01312564`
  (`FUN_004EBB40` / `FUN_004E2560` types `0x3A…0x3E`, `0x4E`).
- Native mapping of the recovered `FUN_0055AE30` walk: live
  `building+4` values 1 vs 3, why index 0 is skipped, `building+0xB4`
  list-index lifecycle, a Native `FUN_00565410` part-weight percent
  (existing `MonumentProject` / Grand Canal / Earthen Great Wall
  percents are not that formula), the live type-2 object vector at
  `DAT_012A4BA8`, and save/load of `goal+8`. Vtable `+0x44` →
  `0x560560` pointer identity (copy bytes themselves are §3).
  Why skip index 0 and the 1-vs-3 live-byte distinction remain
  `unknown`; do not guess.
- Mill-pickup cart `figure+0x13` producer is closed (§3): mill
  vtable `+0x2E4` selected recipe type-count, copied by
  `FUN_00546960` arg2; stall blend incoming raw contribution is
  `20 * byte(figure+0x13)`. Do **not** infer a 1…5 quality band
  merely from that product, and do **not** treat
  `OriginalFoodCatalog.quality(in:)` or manual p.48 as that
  byte’s writer. Player-facing quality name and Native mapping of
  `20 * type-count` vs Native `20/30/50/70/90` remain `unknown`.
  Do **not** assign the `cMarket+0x180` **store** to `cMillBldg`.
  Peddler (23) vs buyer (24) spawn and type-table think rows are exclusive
  (`confirmed`); model-24 states 6/7 **can** reach
  `FUN_004EACD0` → `cMarket+0x2c` (`confirmed`). Hero model-79
  case-4 identity for the `0x5A` store. Unencoded `+0x36` writers
  beyond §3; the complete writer set is not proven. Native's monthly
  Dinners draw now matches the confirmed 25% arithmetic, while
  market-delivery blending/cadence and raw-quality mapping remain
  unresolved (§3), so those fields must not be substituted. No gameplay
  implementation contract is authorized. Do not
  name `house+0x8C` `crimeRisk`.
- Complete constructor-zero set for `house+0x5C` / `house+0x8C`
  beyond the empty-house `+0x8C = 0` write and `FUN_00427430`
  save/load.
- `DAT_01312214` runtime writers besides init (player wage buttons
  write `DAT_01312218`).
- Native mapping of `house+0x24` (lifecycle and
  `DAT_01391FE0` snapshot are in §5.7; overlay label is `rome`, not
  `roadnet`; no Native field is authorized).

## 10. 2026-08-16 closures: `DAT_00D62408` writer-negative, `+0x230` caller set, `cHouseInfo+0x3C` gate scope

Method: read-only byte-level scans of the hash-matched canonical EN
(`8a6d2df1…6753`) and CH (`dbdeca1e…15a`) executables at
`Exe/ghidra/input/`, plus corpus reads of the indexed functions that are
present in `local/source/split-merged`. No runtime observation was used.

### 10.1 `DAT_00D62408` has no static writer in EN or CH (`confirmed` negative)

Whole-file scan for the little-endian address constant `08 24 D6 00`
(`0x00D62408`) finds exactly **three** occurrences in each build, at the
identical file offsets / VAs:

| VA | function | read form | context |
| --- | --- | --- | --- |
| `0x42D9A1` | `FUN_0042D9A0` | `mov eax, [0xD62408]` | `if (DAT_00d62408 != 1)` gates the monthly maintenance risk-slot update (`FUN_004189a0() % DAT_00817748`, building vtable `+0x30`) and route-cache refresh |
| `0x4ACD02` | `FUN_004ACD00` | `mov ecx, [0xD62408]` | `return DAT_00d62408 != 0;` — boolean gate called by house type-switch / evolution paths (`FUN_00519180`, `FUN_00519200`, …) |
| `0x4CA227` | `FUN_004C9FD0` (immigrant arrival) | `mov eax, [0xD62408]` | when nonzero, skips the empty-house `+0x230` type-switch calls (§5.3) |

Write-class opcode scan (same classes as §6.2: `A3`, `89 05/0D/15/1D`,
`C7 05`, `C6 05`, `01/09/21/29/31/87 05`, `FF 05/0D`, `81/83` rmw,
`F7 05`), plus every `FF /r` / `89 /r` / `C7` form whose mod=10 disp32 equals
`0x00D62408`, and any imm32 form (`B8/68/BA/…`) containing the constant:
**zero hits** in both builds. Any instruction referencing the address,
directly or via `[reg+disp32]`, would contain the 4-byte constant and was
caught by the raw scan.

**Classification:** `confirmed` negative for a static direct writer.
Remaining caveat (unchanged policy): a block copy (`rep movsd` with computed
source/destination) could still write the BSS byte without the constant
appearing in the instruction stream; no such site is known, and the byte is
inside a standalone BSS region (`0xD62408` is far below the city-stats
object `0x0130F960…` saved by `FUN_00593140` / `FUN_0058FE40`).

**Consequence for the migration contract:** in the shipped EN/CH builds the
flag is always `0`, so `FUN_004ACD00` always returns false and the
immigrant-arrival `+0x230` calls are never skipped. The `DAT_00D62408 != 0`
skip branches are unreachable in these builds; Native may implement the
empty-house type switch unconditionally, with a save-migration guard that
treats an unknown persisted value the same way (a nonzero value would only
disable a branch these builds can never take).

### 10.2 `FUN_00518DE0` / house vtable `+0x230` caller set (partial closure)

EN `.text` scan for `FF /r` with mod=10 and disp32 `0x230` finds **39** call /
jump sites; scan for direct `E8` rel32 calls to `0x00518DE0` finds **zero**
(vtable-only reach, as documented). The two immigrant-arrival sites are
`0x4CA237 call [eax+0x230]` (common housing, arg `3`) and
`0x4CA249 call [edx+0x230]` (elite, arg `0xD`) inside `FUN_004C9FD0`
(§5.3). Other callers of the same slot:

- `0x4CB1A1` / `0x4CB1AF` — `FUN_004CA960` (vagrant think, type `0xD`).
- `0x4E1AB2 jmp [eax+0x230]` / `0x4E1AD2 call [eax+0x230]` — generic
  type-change path in the missing `0x4E` block.
- `0x5191EA` … `0x519F75` — corpus-visible evolution/eviction cluster
  (`FUN_00519180` calls `+0x230(3)` after the `FUN_004ACD00` gate;
  `FUN_00519200` calls `+0x230(4)`; `FUN_00519F30` falls back to
  `+0x230(param_2)` when its `cHouseInfo+0x3C` / `+0x2E` gate fails).
- `0x51CFF8`, and six sites in the missing `0x5E` block (`0x5E4686`,
  `0x5E74AB`, `0x5E7725`, `0x5E79C8`, `0x5E7EBE`, `0x5E8176`).

Corpus evidence for the sibling method `FUN_00519060`:
`FUN_00519060` writes `(+0x14,+0x16) = (3,0)` when `FUN_005188F0` is true
(common) and `(0xC,9)` when `FUN_005188D0` is true (elite), then rebuilds
the map object — the same family as `FUN_00518DE0`'s `(3,0)/(13,10)`
(§5.10), confirming that `+0x230` arguments select distinct vacant-type
conversions and that the conversion methods are called from many systems,
not only immigration. `FUN_00519F30` additionally shows the
`cHouseInfo+0x3C` byte gating **both** the occupancy add (immigrant
arrival) and the vacant-type switch path, strengthening the reading that
`+0x3C != 0` marks a house whose arrival/occupancy transition must not run.

### 10.3 Updated status of §9 items

- `DAT_00D62408` writer: **closed as confirmed-negative** (no static writer
  in EN/CH; always `0`; skip branches unreachable). Meaning: a global gate
  that, if nonzero, would suppress maintenance risk-slot updates and house
  type-switch/occupancy transitions; no shipped writer produces it. Native
  mapping: implement as "always absent/zero" with the save-migration guard
  in §10.1 — no runtime field is required.
- `+0x230` complete caller set: **partially closed** (39 sites enumerated;
  immigrant/vagrant sites confirmed; `0x4E`/`0x5E` block callers recorded
  but not function-mapped). For the migration contract only the
  `0x4CA237`/`0x4CA249` sites matter.
- `cHouseInfo+0x3C` gate scope: **widened** (also gates `FUN_00519F30` /
  `FUN_00519060`); original semantic name, complete writer/lifecycle set,
  and Native mapping remain `unknown`.
- `house+0x24` flood (`DAT_01391FE0`, seed `DAT_00C5CDFC/CDFE`, case `0x15`
  via `FUN_004ACFC0 → FUN_005AE140`): pass predicate inside `FUN_005AE140`
  remains `unknown`; Native mapping stays `unknown` (not road adjacency).

No implementation contract beyond §8 is authorized by this section; the
producer remains `unsupportedOriginalProducer` until the remaining
`unknown` inputs are closed.

### 10.4 `FUN_005AE140` flood pass predicate recovered (`confirmed`)

2026-08-16, second pass: disassembled the hash-matched EN executable
(`llvm-objdump -d` over `Exe/ghidra/input/EmperorEN.exe`) for
`FUN_005AE140` (`0x5AE140`) and its expander `FUN_005AE240` (`0x5AE240`).
The calendar case-`0x15` refresh (`FUN_004ACFC0`, corpus-visible) calls
`FUN_005AE140(DAT_00C5CDFC, DAT_00C5CDFE, …)` — the authored land-entry
seed — then walks live buildings and calls vtable `+0x84` refreshers that
store `DAT_01391FE0[cell]` into `house+0x24` (§5.7).

`FUN_005AE140` (`0x5AE140`–`0x5AE231`):

- `DAT_01391FE0[seed] = 1`; queue head/tail in `DAT_013C4C20` /
  `DAT_0131FC48`; iteration counter `DAT_0131FC4C` walks `0…0xCB0F`
  (`0xCB10` = 51984 cells).
- Each queued cell calls `FUN_005AE240(cell, depth+1, floodMap, queue)`.

`FUN_005AE240` (`0x5AE240`–`0x5AE37A`) expands four neighbours in the
order **north, east, south, west**, and for each neighbour with
`flood[neighbour] == 0`:

```
pass  ⇔  (word[DAT_013789C0 + 2*neighbour] & 0xB7C) != 0
```

The four table bases are exactly `DAT_013789C0 + 2*offset` for
`offset ∈ {-228, +1, +228, -1}` (`0x13787F8`, `0x13789C2`, `0x1378B88`,
`0x13789BE`; verified arithmetic), i.e. the predicate reads the
**neighbour cell's** word of the main derived route cache
(`DAT_013789C0`, rebuilt by `FUN_005AD8F0`). On pass, the neighbour gets
`depth+1` and is appended to the queue; the loop ends when the queue tail
catches the head or the counter exceeds `0xCB0F`.

Mask `0xB7C` bits: `0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x100 | 0x200 | 0x800`.
Against the recovered main-cache write domain (`1/2/4/0x10/0x20/0x80/
0x100/0x400/0x1000/0x4000` + ferry `0x200/0x800`; `0x8` has no producer in
this build), the flood therefore passes through road `0x4`, clear-land
`0x10`, `0x20`, road+elevation `0x100`, and ferry links `0x200/0x800`; it
does **not** pass through blocked `0x2`, `0x80`, elevation-only `0x400`,
`0x1000`, or `0x4000`.

Fallback `FUN_005AE380` → `FUN_005AE480` (used by `FUN_004ACFC0`'s
recovery loop when the entry check cell is unreached) uses mask `0x17C`
(`0x4|0x8|0x10|0x20|0x40|0x100`) and, on a blocked neighbour whose
`dword[0xF6A650 + 4*cell] & 0x4020` (or `0xF6A9E4` for east) is set,
performs side writes (`byte[0xFDCC8C+cell] |= 0x40`,
`byte[0xF9D53C+cell] &= 0xF0`,
`dword[0xF6A650+4*cell] &= 0x93872790`) and stores
`DAT_00D62400 = cell ± offset`. That fallback is the blocked-entry recovery
path, not the daily `house+0x24` refresh; its full semantics remain
`unknown` and are not part of the migration eligibility contract.

**Classification:** `confirmed` — direct machine code in the canonical EN
hash `8a6d2df1…6753`, with `compare-report.tsv` marking both
`FUN_005AE140 @ 0x5AE140` and `FUN_005AE240 @ 0x5AE240` `identical` in the
Chinese hash `dbdeca1e…15a`. The pass mask, neighbour order, queue bounds,
and seed/termination behaviour are therefore confirmed for both builds.

**Consequence for the migration contract:** Native can implement
`house+0x24` as a deterministic flood over its own main derived route
cache (the same cache contract already implemented and tested for the
Grand Canal work): seed = authored land-entry tile, 4-neighbour expansion
N/E/S/W, pass mask `0xB7C` on the neighbour word, depth `n+1`, refresh
per calendar day (case `0x15`) and on cache-rebuild events. Native's cache
derivation must be verified bit-identical against the recovered write
domain before wiring; if any cache bit diverges, this mapping stays
`unknown` and the producer stays fail-closed.

**Native verification (2026-08-16): partial** — plan 006 Phase 1a added
`testNativePrimaryRoutingCacheMatchesRecoveredWriteDomainAndFloodMask` and
`testFerryOccupancyStaysFailClosedUntilPostPassIsWired` to
`Tests/EmperorCoreTests/GrandCanalSimulationTests.swift`; both pass. On the
real Haunxian map every primary-cache value stays inside the recovered write
domain, and the `0xB7C` flood mask discriminates produced values exactly as
the original does.

**Recorded divergence:** the ferry post-pass (`0x800` over the 6×6 footprint,
`0x200` along the stored `0/2/4/6` connector chain, `FUN_004C6D30`) is
documented in `PrimaryRoutingClassRule` but **not applied** by the Native
city grid projection: `workerRoutingGrids` only maps per-cell derivation, and
a placed Ferry (building 210) reaches the unclassified generic-footprint
branch and throws `missingGenericFootprintPredicate` (fail-closed). The
ferry connector-chain selection rule at placement is also not recovered.
Therefore `house+0x24` is exact for ferry-free maps, but remains `unknown`
on maps containing a Ferry; the migration producer stays
`unsupportedOriginalProducer` until the ferry post-pass and connector-state
contract are recovered and wired (tracked in plan 006 Phase 1a).

### 10.5 `cHouseInfo+0x36` writer set (2026-08-16, improved)

Byte-level scan of EN `.text` for stores to offset `0x36`, cross-filtered by
proximity to a `call [r+0x1E4]` (the house vtable cHouseInfo getter) and by
disassembly of each candidate, yields this `cHouseInfo+0x36` writer set:

| site | function | value | class |
| --- | --- | --- | --- |
| `0x543A09` | `FUN_005437B0` (cMarket vtable `+0x2c`, market delivery) | blended quality byte (`bl` from the `cStall+0x260`-style mix) | confirmed |
| `0x51870D` / `0x51871B` | `FUN_00518690` (month settlement) | `0` when `cHouseInfo+0x12 < 1` | confirmed |
| `0x5187A9` / `0x5187B9` | `FUN_00518690` (same; `DAT_00C5CDA0` branch) | `0x14` (20) | confirmed |
| `0x515259` | `Check_if_going_to_fire` (`0x5149C0`) branch gated by `house+0x92` | `0x5A` (90) | confirmed site; object identity is the `+0x1E4` result of `esi` |

Discriminated non-writers: `FUN_00518B70` `0x518C32` writes
`house+0x36 = random % 40` (maintenance tick offset, not cHouseInfo);
`0x519DDE` / `0x519E60` copy `house+0x36` on `edi`; `FUN_00518490`
`0x51850A` is a `cmp byte [cHouseInfo+0x36], 0x13` **read** (population
with food quality ≥ 20 into `DAT_0130F98C`), not a write.

The complete-writer-set question is now narrowed to these four sites plus
any writer whose base is not within `±0x200` of a `+0x1E4` call. The
remaining **Native mapping** blocker is now market-delivery
blending/cadence and the player-facing quality name for the
`20 * type-count` contribution remains `unknown`, so the food factor stays
fail-closed.

### 10.6 `cHouseInfo+0x3C` lifecycle (2026-08-16, closed)

`cHouseInfo+0x3C` is a **post-removal occupancy lock**, not an
immigrant-specific field:

- Setter `FUN_004681A0` (`0x4681A0`, corpus): subtracts residents
  (`house+0x20 -= count`), calls `FUN_00591920` (population decrease
  effect), stores `cHouseInfo+0x3C = param_2`, arms `house+0x98 = 0x20`
  (32-step countdown), clears `house+0xA4`, refreshes the map object.
- Its only direct caller `FUN_00468420` (`0x468420`, corpus) passes
  `param_2 = 2` and spawns three type-`0x12` walkers (state 6,
  `+0x3E = 600`, `+0x62 = house id`) — the eviction/removal displacement
  path.
- Clear `FUN_005185C0` (`0x5185C0`, corpus): daily walk over houses with
  `vtable +0xB8` true and `cHouseInfo+0x3C != 0`: if `house+0x20 == 0`
  clear `+0x3C` and `house+0x98` immediately; else decrement `house+0x98`
  and clear `+0x3C` when it reaches `0`. Counts locked houses into
  `DAT_0131289C`.

Consequence for the arrival contract (§5.3, §5.9): after residents are
removed, the house suppresses immigrant occupancy writes for up to 32 steps;
the gate `cHouseInfo+0x3C != 0` at `0x4CA260` is therefore a real gameplay
path (eviction settling lock), not dead state. Native mapping: the
`ResidentialUnit` needs a `settlingLock` byte (values `0`/`2`) plus the
`house+0x98` countdown, decremented daily by the `FUN_005185C0` equivalent;
the immigrant arrival write must skip while nonzero. Remaining unknown:
complete writer set beyond `FUN_004681A0` (negative search: no other
`+0x1E4`-adjacent `+0x3C` store), and the original semantic name of the
byte. Classification: setter/clearer/lifecycle `confirmed` for the sites
above; completeness `inferred`.

### 10.6a Removal-lock writer preserves full-ledger and signed-short widths (confirmed, 2026-09-03)

The direct body of `FUN_004681A0 @ 0x4681A0` is now represented without
guessing the floating-point producer of its count.  After the source's
`__ftol` conversion, it passes the full integer to `FUN_00591920`, but the
house resident subtraction stores only the signed 16-bit conversion of that
integer.  It then writes the caller byte to `cHouseInfo+0x3C`, stores
`0x20` (32) at house `+0x98`, clears house `+0xA4`, and calls
`FUN_00418770` with the house registry word at `+0xB4`.  Its only indexed
caller is `FUN_00468420 @ 0x468420`, which passes byte `2` and then attempts
three type-`0x12` Disease Carrier figures; the caller/body rows are
EN/CH-identical (`0x4681A0` in `local/source/compare-report.tsv`).

`OriginalHouseInfoRemovalLock.apply` records the exact write set, full-ledger
delta, signed-short resident arithmetic, byte truncation, 32-step arm, and
refresh registry argument.  It is research-only: the source of the converted
count, figure allocation/route, and Native disease/object projection remain
unknown, so no new Qin incident behavior is enabled.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004681A0.c`,
`FUN_00468420.c`, `local/source/compare-report.tsv` row `0x4681A0`,
`GameData/Model/EmperorFigureModels.txt`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for call order, field offsets, widths,
constants, caller byte `2`, and EN/CH parity; **unknown** for the `__ftol`
input producer, incident trigger frequency, figure route/registry, and
downstream Qin settlement.

### 10.7 War count `DAT_01312564` lifecycle (2026-08-16, mechanism confirmed)

Direct disassembly (EN `8a6d2df1…6753`):

- `FUN_004E2560` (`0x4E2560`–`0x4E2578`) is a pure type gate:
  `mov eax, [esp+4]; cmp eax, 0x3A; jl false; cmp eax, 0x3E; jle true;
  cmp eax, 0x4E; jne false; true`. So it accepts exactly
  **types 58…62 and 78** = `EmperorFigureModels.txt` rows
  Enemy Infantry (58), Enemy Archer/Crossbow (59), Enemy Cavalry (60),
  Enemy Chariot (61), Enemy Catapult (62), Enemy's Heroes (78).
  The 0x4E25A0+ collision-table body belongs to a separate function and is
  not part of the gate.
- `FUN_004EBB40` (`0x4EBB40`) takes `(figureID, flag)`: looks up the
  figure, and if `FUN_004E2560(figure+0x12)` is true, does
  `DAT_01312564 += flag ? 1 : -1`, clamped at 0; then a second gate
  `FUN_004E2510` maintains `DAT_01312570` the same way.
- Lifecycle call sites (all `confirmed`): increment on figure creation at
  `0x4E199A` and `0x4EA01B` (`push 1`); decrement on figure death at
  `0x4C90D7` (`push 0`, in the `FUN_004C8B70` death tail). Init/reset zeroes
  both dwords at `0x4EBBD0`.
- Pressure rule (`FUN_005917E0`, corpus): `if DAT_01312564 < 4` the normal
  request/cooldown path runs; `else if pressure > 0` pressure is forced to
  `0` (war suppresses positive migration pressure); population > 199999
  also zeroes pressure. `DAT_01312570` is not read by the pressure function.

**Native mapping remains unknown:** Native models enemy units as one aggregate
`EnemyMilitaryForce` per invasion, while the executable increments
`DAT_01312564` once per individual figure creation and decrements on that
figure's death. `soldierCount` is therefore not an evidence-equivalent
replacement for the figure count, and neither one-force-per-alert nor one per
formation has been recovered in Native. The invasion spawn chain below closes
the source-side model family—Qin's type-2 invasion uses generic enemy models,
not regional model 6—but not figure multiplicity or creation/death timing.
Native consequently leaves the pressure war-count gate at zero (fail-closed)
until a per-figure ledger or an equivalent source-backed mapping is recovered.

### 10.7a Qin invasion event → generic enemy figure models (2026-08-30)

`EmperorInspector campaign-events 'GameData/Campaigns/4 Qin Dynasty.pak'`
reports Mission 4 “Emperor Qin's Great Wall” invasion events #2 and #3 with
`secondarySelectionID=10`, amounts `8…11` and `15…20`, city `0`, and the
one-time/recurring schedules recorded above. In the hash-identified English
build (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`),
the event-name table at `0x846608` labels object type `2` **INVASION**.

The static event/spawn chain is:

1. `FUN_0049d5c0 @ 0x49D5C0` dispatches `param_1[1] == 2` to
   `FUN_004a5340 @ 0x4A5340` (`local/source/split-merged/code/0x040000/`).
2. The invasion handler's due branch (`FUN_004a0d30 @ 0x4A0D30 == 0`)
   calls `FUN_00522d00 @ 0x522D00` (EN call site `0x4A55C5`), then stores
   the war-state result from `FUN_0054d850`.
3. `FUN_00522d00` forwards five arguments to `FUN_00522b30 @ 0x522B30`;
   that wrapper clamps the amount to `0x100` and obtains five formation
   counts through `FUN_00522c50 @ 0x522C50`, which applies
   `FUN_00408b80` difficulty scaling to the authored count table.
4. The normal branch of `FUN_00522d30 @ 0x522D30` selects models
   `0x3A,0x3B,0x3C,0x3D,0x3E` (decimal **58, 59, 60, 61, 62**) for formation
   categories `0…4` before creating figures through `FUN_004EA050`. A later
   optional branch creates enemy hero model `0x4E` (78). The separate
   friendly/response builder `FUN_0054F8D0` selects `0x40…0x44` (64…68) and
   is not this Qin invasion path.
5. `FUN_004EBB40` increments `DAT_01312564` for these models because
   `FUN_004E2560` accepts exactly 58…62 and 78. Model 6 therefore cannot
   contribute to the original war-count gate.

The resource side corroborates this mapping. `GameData/Model/EmperorFigureModels.txt`
rows 58…62 name the five enemy formations. `emperor-inspect
sg3-bitmap-map GameData/DATA/China_Chinese.sg3` identifies their sheets as
`NonPlayer_InfantryMan` (logical 12, first image #1289),
`NonPlayer_CrossbowMan` (logical 6, #629), `NonPlayer_Cavalry` (logical 0,
#1), `NonPlayer_Chariot` (logical 21, #2209), and `NonPlayer_Catapult`
(logical 16, #1793), each with a 12-frame walking entry. Native's
`OriginalFigureSpriteCatalog` now exposes these five verified families and
maps the one-force Qin representative to model 58.

The previously open five-count input is now recoverable as a pure explicit
calculation. `FUN_005D1E20 @ 0x5D1E20` loads the 42-row `ALL ENEMIES` table
from the authored model data into the runtime rows consumed by
`FUN_00522C50`; each six-row block is one regional set, with the sixth row the
blank separator. `FUN_0054B650 @ 0x54B650` initializes the period thresholds
`-1200, -500, -350, -200`, and `FUN_0054B6D0` maps a signed current year to
period index `0…4`. `FUN_00522C50` then reads period column `9 + periodIndex`
for the first five rows and applies `FUN_00408B80(amount, percentage)`
(`amount × percentage / 100`); `FUN_00522B30` clamps amount to `0x100` and
the enemy-set selector to `0…6`. For Qin's Chinese block (set `0`) at year
`-209` (period `3`), the authored percentages are `[35,20,15,15,15]`, so an
amount of `9` yields `[3,1,1,1,1]` figures for models `[58,59,60,61,62]`.
Native exposes this as the explicit-input
`OriginalInvasionFormationCatalog`/`OriginalInvasionFormationPlan` helper.

Evidence class: **confirmed** for type-2 INVASION dispatch, the due-handler
call, model selection, the period thresholds, authored percentage extraction,
war-count gate, and `China_Chinese.sg3` families; **inferred** only for
Native's one-force compression of the original five possible formations and
the Qin runtime binding of city selector `+0x3AAC` to Chinese set `0`. The
optional hero condition, per-figure creation/death ledger, and live Native
projection remain unknown.

### 10.7b War-count reset and variant identity (2026-09-01)

The lifecycle boundary is now explicit in both decompilation variants:

- `FUN_004EBBD0 @ 0x4EBBD0` assigns `DAT_01312564 = 0` and
  `DAT_01312570 = 0`; this is the initialization/reset point, not a derived
  value from the current invasion list.
- `FUN_004EBB40 @ 0x4EBB40` is the only recovered per-figure adjustment path:
  it looks up a figure, applies the `FUN_004E2560` model gate, increments or
  decrements the count, and clamps at zero. Creation and death call sites are
  the generic figure lifecycle (`FUN_004E1420`/`FUN_004EA050` and
  `FUN_004C8B70`), so the counter's unit is an individual figure rather than
  an invasion alert or a soldier subtotal.
- `local/source/compare-report.tsv` marks `0x4E2560`, `0x4EBB40`,
  `0x4EBBD0`, `0x4E9FE0`, `0x522B30`, `0x522C50`, `0x522D00`, `0x522D30`,
  `0x4A5340`, `0x4C8B70`, and `0x4E1420` as `identical` for EN/CH. The Chinese
  widescreen executable therefore supplies no alternate war-count contract.

Native now centralizes the confirmed model gate in
`OriginalWarFigureCatalog` (`Sources/EmperorCore/MilitarySimulation.swift`),
with an independent test for `{58…62, 78}`. This catalog is intentionally not
used to derive `warCount`: Native still lacks the executable's per-figure
creation/death ledger, so `warCount == 0` remains the evidence-safe pressure
gate. Evidence class: model gate, reset, lifecycle call shape, EN/CH identity,
and the authored five-count extraction **confirmed**; aggregate-to-figure
ledger projection, optional hero condition, and Qin runtime selector binding
remain **unknown**.

### 10.7c Explicit per-figure ledger primitive (2026-09-02)

The already recovered war-count lifecycle is now represented as an explicit
input ledger in `OriginalWarFigureLedger` (`Sources/EmperorCore/MilitarySimulation.swift`).
Its contract is exactly the source sequence: `FUN_004EBBD0 @ 0x4EBBD0` resets
the count to zero; `FUN_004EBB40 @ 0x4EBB40` first applies the
`FUN_004E2560 @ 0x4E2560` model gate (`58…62` and `78`), then adds one for a
creation event (`flag=1`) or subtracts one for a death event (`flag=0`),
clamping the stored dword at zero. The creation/death call sites previously
identified at `0x4E199A`, `0x4EA01B`, and `0x4C90D7` are EN/CH-identical in
`local/source/compare-report.tsv`.

This closes the reusable arithmetic and reset contract without synthesizing a
figure stream from Native's one-aggregate-per-invasion `EnemyMilitaryForce`.
The live Native object registry, figure identity/timing, archive prepopulation,
and any projection from the ledger into `CitySimulation.warCount` remain
**unknown**; `warCount` therefore stays fail-closed at zero. Evidence class:
**confirmed** for the explicit ledger transition and reset; **unknown** for
the Native event-source/projection boundary.

The selector scope is also bounded. `FUN_00481F10 @ 0x481F10` resolves one of
22 city slots at stride `0x3C00`, `FUN_00499740 @ 0x499740` returns the active
slot, and the invasion handler `FUN_004A5340 @ 0x4A5340` passes that city's
`+0x3AAC` field into `FUN_00522D00`. The indexed corpus finds the field's
direct initialization in `FUN_004416C0 @ 0x4416C0` (`FUN_0040E630` returns 0)
and a setup/UI clamp in `FUN_005F7130 @ 0x5F7130` (0…6, with a separate type-4
branch); it does not expose a campaign-map/archive writer for this field.
Those rows are EN/CH `identical` in `compare-report.tsv`. The indexed call
chain alone therefore did not prove the campaign-data binding; the serializer
and authored Qin-record check that closes this gap are recorded in §10.7e
below. Native keeps `enemySetIndex` as an explicit input until that parsed
record is carried through the still-unrecovered live invasion object path.

### 10.7c Invasion event strength is a separate weighted threat aggregate (2026-09-01)

The post-spawn value written into an event record is not the global war-count
counter and is not the authored event `amount` copied verbatim. In the canonical
EN build, the due branch of `FUN_004A5340 @ 0x4A5340` calls
`FUN_0054D850 @ 0x54D850` with the event's city index and stores its return value
at event-object `+0x104` and `+0x108` (`0x4A55D8` and `0x4A55E0`; the Ghidra
`short *` expression `param_1+0x82/+0x84` is byte offsets `0x104/0x108`). The
later pending/arrival code reads the `+0x104` value as the event's stored
invasion aggregate; the separate byte at `+0x84` used by `FUN_004A0B70` is a
different event flag and must not be conflated with this result. This write
therefore belongs to invasion-warning state rather than migration pressure.

`FUN_0054C4F0 @ 0x54C4F0` is the matching 64-slot allocator: it scans records
from `DAT_011A43A4` through `DAT_011A70A4` at stride `0xB4`, starting its
returned slot index at `0x23`; `FUN_005512D0` is the shared reset and clears
the same record's quantity byte at `+0x28`, model/coordinates, and city
selector fields. `FUN_0054D850` biases its cursor to `DAT_011A43CC` (= record
`+0x28`) and scans the same 64 slots through `DAT_011A70CC`. For each record it
requires the raw status expression `record+0x00 == 1`, a signed city-selector
match at `record+0x78 == param_1`, and a non-zero quantity byte at
`record+0x28`. It then
switches on the signed model key at `cursor[-0x24]`; the recognized enemy
classes are `0x3B…0x3E` (59…62) and the branch's default/hero class `0x4E`
(78). Direct read-only PE inspection resolves the five `.rdata` doubles in
both hash-identified builds: model 59 → **1.25**, 60 → **2.5**, 61 → **4.0**,
62 → **5.0**, and 78 → **10.0**. Each class multiplies the quantity by its
weight, converts with the shared floating-to-integer helper, and adds the
truncated result to the return sum. Native records this exact table in
`OriginalInvasionThreatWeightCatalog`, but does not call it from live
simulation because the archive/load path and Native registry projection for
this 64-record registry are still unmapped. The explicit-input
`OriginalInvasionThreatRecord`/`OriginalInvasionThreatAggregate` helper now
preserves the recovered status, city-selector, quantity, model-key, and
weighted-sum operations without pretending to be that missing registry.

A direct PE immediate-reference scan corroborates the same boundary: the
64-slot table base appears only in the allocator (`0x54C4F0`) and aggregate
reader (`0x54D850`); no additional direct table-index writer is exposed. This
is a confirmed negative for a simple global writer, not proof that an indirect
pointer/vtable path does not exist.

This proves a second, event-local aggregation layer: `FUN_0054D850`'s return is
not `DAT_01312564` (which `FUN_004EBB40` updates once per individual figure),
not an invasion alert's `strength`, and not a safe source for Native's
`EnemyMilitaryForce.soldierCount` until the archive/load path and registry
projection are recovered. The EN/CH rows for `0x54C4F0`, `0x54D850`, `0x4A5340`,
`0x4A0B70`, and `0x49D990` are `identical` in
`local/source/compare-report.tsv`. Native therefore keeps this aggregate
unwired and continues to leave the Qin pressure war-count gate fail-closed.

**Evidence class:** `confirmed` for the call/write chain, scan bounds, raw
predicates, record offsets, recognized model keys, weight literals, and EN/CH
identity; `unknown` for the archive/load path, indirect quantity-writer
coverage, and any Native registry projection.

### 10.7d Enemy's Heroes branch has a closed raw city-record gate (2026-09-02)

The optional model-78 branch in `FUN_00522D30 @ 0x522D30` is entered only
when the selected city record's signed short at `+0x38` satisfies
`-1 < value && value < 0xC`, i.e. `0...11`. The split body shows this test
immediately before the `FUN_0054C4F0(0x4E, ...)` allocation and subsequent
`FUN_00510C70` placement request. The canonical English and Chinese rows are
`identical` in `local/source/compare-report.tsv`; there is no variant-specific
hero gate.

Native exposes this exact branch predicate as the research-only
`OriginalInvasionHeroEligibility.rawCityFieldIsEligible(_:)`. It reports only
that the source branch is admitted. A later allocation, route/placement
request, and hero figure creation can still fail, and the authored semantic
name, producer, save/load source, and Native projection of the city `+0x38`
field remain unknown. Consequently this closure does not enable model-78
spawning or change `warCount` in live Qin simulation.

**Evidence class:** `confirmed` for the signed range test and EN/CH identity;
`unknown` for the field's semantic meaning, producer, archive binding, and
post-gate creation/placement success.

### 10.7e Qin city records persist the invasion enemy-set selector (2026-09-04)

The selector's storage boundary is now closed. `FUN_0043E230 @ 0x43E230`
installs the city-record vtable `PTR_LAB_007AC764`. The vtable's serializer at
`0x43E370` is not emitted as a separate file by the indexed Ghidra splitter,
so the EN/CH PE bytes were checked directly after the corpus search was
exhausted. In both hash-identified executables, that method calls the common
store/load primitive for the city-runtime fields at offsets `+0x3AA8` (1 byte),
`+0x3AA9` (1 byte), `+0x3AAC` (**4 bytes**), `+0x3AB0` (4 bytes),
`+0x3AB4` (4 bytes), and `+0x3AB8` (4 bytes). The `+0x3AAC` dword is therefore
serialized as part of each fixed city record; it is not only a fresh-object
default. The disassembly range `0x43E370...0x43E758` is byte-identical between
EN and CH (the compare table has no separate row because the splitter omitted
this vtable method).

The file layout independently locates this field. `CampaignEmpireMap` treats
each city as a schema word followed by a `0x3C00`-byte runtime record; the
selector is at `cityRecordBase + 2 + 0x3AAC`, immediately before the parser's
postlude beginning at `+0x3AB8`. Reading the authored `GameData/Campaigns/4 Qin
Dynasty.pak` gives decoded offset `0x6CAA2`, 193 empire objects, and **zero for
the selector dword in all 22 city slots** (including every active Qin city).
The regression `testLocalQinCampaignEmpireCitiesPersistChineseInvasionEnemySet`
asserts these exact archive facts and the `0...6` source clamp domain.

This changes the selector classification: `FUN_004A5340 @ 0x4A5340` passing the
selected city's `+0x3AAC` into `FUN_00522D00`, the serializer's four-byte field,
and Qin's authored value `0` are **confirmed**. It is now safe for an eventual
campaign event bridge to derive the Chinese `ALL ENEMIES` block from the Qin
empire record rather than from a hard-coded campaign guess. The per-figure
formation creation/death ledger, 64-slot threat registry projection, scheduler
RNG order, and Native combat/rendering binding remain unknown, so this commit
only exposes the parsed selector and does not synthesize enemy forces.

### 10.7f Source invasion counts split into multiple formation records (2026-09-04)

The stack-array portion of `FUN_00522D30 @ 0x522D30` closes the next narrow
formation boundary. Its five count parameters are copied into a local array and
each is capped independently at `0x200`. For a non-negative count `n`, the
source computes `full = floor(n / 16)` and first writes `full` groups of 16. A
zero remainder emits those groups unchanged. A remainder with no full group
emits the remainder as one group; otherwise the source overwrites the final
16-group with two groups
`ceil((remainder + 16) / 2), floor((remainder + 16) / 2)` and increases the
group count by one. Thus the recovered examples are `17 → [9, 8]`,
`31 → [16, 15]`, `32 → [16, 16]`, and `33 → [16, 9, 8]`; values above 512
are equivalent to 512. This is not a generic “sixteen units per squad” rule:
the near-half remainder split and the `0x200` cap are source-visible writes.

This trace is from the canonical EN hash
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
comparison-identical CH hash
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
The direct caller is `FUN_00522B30 @ 0x522B30`; relevant callees in this branch
are `FUN_0054C4F0` (64-slot record allocation), `FUN_004EA050` (individual
figure creation), `FUN_0047F1B0` (figure object access), and the
`FUN_005516A0`/`FUN_005516C0`/`FUN_0051E650` placement helpers. The indexed
`local/source/split-merged/code/0x050000/FUN_00522d30.c` body and
`compare-report.tsv` provide the EN/CH control-flow evidence; authored model
rows and the `+0x3AAC` archive field corroborate the model/selector inputs.

The normal branch then iterates those groups in category order. The initial
category uses model `0x3A` (58), followed by `0x3B…0x3E` (59…62), matching the
five authored Chinese `ALL ENEMIES` rows already recovered in §10.7a. For each
non-zero group it allocates a separate `0xB4` threat record through
`FUN_0054C4F0`, stores the selected city's `+0x3AAC` selector at record `+0x78`,
and creates each individual figure with `FUN_004EA050`. The figure receives the
record index at `+0x6A`, a ten-unit intra/formation spacing value at `+0x3E`,
and its slot is appended to the record's 16-byte figure link array. The later
model-78 hero branch is separate and remains gated by the unknown city `+0x38`
field documented in §10.7d.

Native now exposes the recovered count splitter as
`OriginalInvasionFormationCatalog.groups(forCount:)` and attaches the resulting
`OriginalInvasionFormationGroup` values to an explicit formation plan. This is
research/data plumbing only: the live Native `EnemyMilitaryForce` remains one
aggregate per alert because the original 64-slot registry, per-figure
save/load population, combat timing, and rendering projection are not yet
recovered. No player-facing force count or war-count behavior changes in this
commit.

Evidence class: **confirmed** for the per-category `0x200` cap, 16-group and
near-half split arithmetic, model IDs 58…62, separate threat-record allocation,
per-figure creation/link writes, and EN/CH-identical indexed function body;
**unknown** for the indirect registry population outside this call, archive
prepopulation, RNG order, and Native projection.

### 10.7g Threat records reset at level initialization and are serialized by the map/save path (2026-09-04)

The registry's lifecycle boundary is narrower than a campaign-city archive.
`FUN_0054D580 @ 0x54D580` walks `DAT_011A2B08` through 100 records at stride
`0xB4` (the enemy allocator's 64-slot slice is slots `0x23…0x62`) and calls
`FUN_005512D0 @ 0x5512D0` for every row, then clears `DAT_013127A8`. The reset
is called by the map/level initialization path
`FUN_0042E6A0 @ 0x42E6A0`, the new-level path `FUN_005D1400 @ 0x5D1400`, and
the fresh-game branch of `FUN_004FB530 @ 0x4FB530`; all four functions and the
reset helper are EN/CH `identical` in `compare-report.tsv`. `FUN_005512D0`
clears the active flag, model/coordinate fields, city selector, quantity byte,
and all 16 figure-link entries; if a linked model-9 fort figure exists, it is
retired before the row is zeroed.

The earlier save-subtree-only search was too narrow. The direct `.sav` writer
`save_FUN_004FD2A0 @ 0x4FD2A0` opens `%s\\%s.sav` and calls the broad
`FUN_0052FDA0 @ 0x52FDA0` serializer. In its save and load branches,
`FUN_0052FDA0` iterates from `DAT_011A2B08` to `0x011A7158` in `0xB4` steps,
therefore visiting exactly 100 rows and delegating each row to
`FUN_005501B0 @ 0x5501B0`. `FUN_0040CF90` selects load mode (the per-field
`FUN_00780642` calls); save mode uses the matching `FUN_00780533` calls. The
per-record routine explicitly covers the active/model/coordinate bytes,
quantity at `+0x28`, city selector at `+0x78`, figure links and remaining
record fields through the `+0xB0` dword (with the source's duplicate `+0xA4`
write retained). The EN/CH comparison rows for `0x4FD2A0`, `0x52FDA0`, and
`0x5501B0` are all `identical`.

The indexed evidence files are
`local/source/split-merged/save/save_FUN_004fd2a0_4fd2a0.c`,
`local/source/split-merged/code/0x050000/FUN_0052fda0.c`,
`local/source/split-merged/code/0x050000/FUN_005501b0.c`, and
`local/source/compare-report.tsv`. The trace applies to the canonical EN hash
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
comparison-identical CH hash
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

This closes the previous negative: a dedicated threat-record serializer does
exist in the broad map/save path. It does **not** yet prove that Native can
rehydrate its one-aggregate `EnemyMilitaryForce` into the source's 100-row
registry: level initialization still clears all rows, the schema-version
branches differ for older saves, and the post-load event/figure projection is
not recovered. Native therefore records the serializer boundary and remains
fail-closed for source-registry reconstruction rather than silently inventing
a conversion.

Evidence class: **confirmed** for the 100-row reset, save/load call chain,
field-level serializer, EN/CH identity, and exact table geometry; **unknown**
for schema-version migration semantics, event rehydration order after load,
and Native registry/combat projection.

### 10.7h Event-manager state is serialized before threat rows (2026-09-04)

The surrounding save order is now bounded as well. In every modern branch of
`local/source/split-merged/code/0x050000/FUN_0052fda0.c`, the call to
`FUN_00493F00 @ 0x493F00` occurs before the loop that delegates the 100 threat
rows to `FUN_005501B0`. `FUN_00493F00` dispatches the event-manager object's
vtable serializer, then persists its scalar fields at `+0x9D14…+0x9D1E` and
the nested object at `+0x9D20`; the load branch uses the matching read
primitives. The mission-loader dump
`local/source/split-merged/campaign/cMissionLoader_serialize_dump_0xpc.c`
confirms the same manager boundary and calls `FUN_00494040 @ 0x494040` for
older mission data. `FUN_00494040` copies `0x2742` dwords, exactly
`150 × 0x10C` bytes, from the serialized event-record block before restoring
the manager's trailing fields. `FUN_00492210 @ 0x492210` then scans those
`0x10C`-stride records by runtime kind; `FUN_0049F8B0 @ 0x49F8B0` is the
per-record update path, but its timer/RNG branches do not establish a Native
event-to-threat projection.

The EN/CH comparison rows for `0x492210`, `0x493F00`, `0x494040`, `0x49F8B0`,
and `0x52F4D0` are `identical`. This gives a source-backed reconstruction
ordering constraint: load the event-manager state before interpreting the
following threat rows, and preserve the event-record table's 150-row,
`0x10C`-stride shape. It does **not** authorize Native to synthesize active
invasions from saved event bytes: the vtable payload, schema-version migration,
RNG state, and post-load figure/combat registration remain **unknown**.

Evidence class: **confirmed** for the serializer call order, event-record copy
size/stride, direct indexed files, and EN/CH identity; **unknown** for event
record field semantics beyond the parser's authored offsets, vtable payload,
RNG continuation, and Native threat/figure rehydration.

### 10.7i Invasion builder receives the event amount and city selector at the call site (2026-09-04)

The canonical EN disassembly around `FUN_004A5340 @ 0x4A5340` resolves an
argument detail that the decompiler's one-argument call syntax obscures. At
`0x4A55A0…0x4A55C5`, the handler pushes the event record's `+0x1C` value,
then its `+0x0C` value, and finally the active city record's `+0x3AAC` dword
before calling `FUN_00522D00 @ 0x522D00`. Accounting for the two earlier
stack pushes, the wrapper receives the source tuple
`(enemySetSelector, event+0x0C, event+0x1C, placementArgument, event+0x00)`.
`FUN_00522B30` passes its second value directly to `FUN_00522C50` as the
requested invasion amount and uses its fifth value to resolve the selected
city through `FUN_00494180`; `FUN_00522C50` then extracts the five authored
period percentages. The event archive parser independently maps runtime record
`+0x0C` to `CampaignEventRecord.amount` and `+0x1C` to `cityFrom`, so the
Native `CampaignEventOccurrence.amount` input is source-backed rather than a
strength guess.

`FUN_00523740 @ 0x523740` is the direct event-list caller of `FUN_004A5340`
for ordinary (non-network) play, and `FUN_004AC650 @ 0x4AC650` invokes that
list pass at the recovered day/month boundary. The EN and CH rows for
`0x4A5340`, `0x522B30`, `0x522C50`, `0x522D00`, and `0x523740` are
`identical` in `local/source/compare-report.tsv`; the call-site byte sequence
was checked in both hash-identified PEs after the indexed corpus was
exhausted. This closes the event-amount → five-count boundary, but not the
event-range materialization/RNG consumer that chooses a value before the
handler, nor the post-builder registry/combat projection.

Evidence class: **confirmed** for the call-site argument order, event-record
offset mapping, direct caller chain, and EN/CH identity; **unknown** for the
upstream range-selection RNG order and downstream live-object reconstruction.

### 10.7j Native Qin event path now carries the recovered formation subtotal (2026-09-04)

The recovered call contract is now wired through the real campaign-event path,
without changing the behavior of hand-authored/custom alerts that do not carry
the source selector. `CampaignEmpireCity.serializedEnemySetIndex` parses the
city-runtime `+0x3AAC` dword and `GameSessionController.startCampaignMission`
copies that raw value to `DeterministicCityState`. During
`CampaignMissionRuntimeState.apply`, an invasion with both a selector and an
authored `CampaignEventOccurrence.amount` calls
`OriginalInvasionFormationCatalog.plan(enemySetIndex:year:amount:enemies:)`,
using `startYear + relativeYear` for the recovered source period lookup. The
result is retained on `CampaignInvasionAlert.sourceFormationPlan`; its
`sourceFigureCount` is the sum of the five normal-branch category counts.

The Qin baseline fixture (`enemySetIndex = 0`, year `-209`, amount `9`) therefore
retains the source counts `[3, 1, 1, 1, 1]` and subtotal `7`. Native's current
one-aggregate-per-invasion combat model consumes that subtotal for
`EnemyMilitaryForce.soldierCount` and combat reports, while preserving model
`58` as the representative enemy type. The aggregate compression is an
**inferred** compatibility projection, not evidence that the original uses one
force: the source creates separate records per category/group. A source plan
whose normal subtotal is zero produces no aggregate force rather than an
invented soldier; hero `78`, alternate branches, siege-object registration,
the 64/100-slot live registry, per-figure death timing, and renderer projection
remain **unknown** and are deliberately not synthesized.

Evidence class: **confirmed** for selector propagation, period/amount inputs,
five-count/subtotal calculation, optional-save compatibility, and the
zero-subtotal fail-closed guard; **inferred** only for the one-force combat
compression. Remaining unknowns are the upstream event-range RNG consumer and
all post-builder live-object/hero/siege/renderer projections. Relevant Native
files are `CampaignEmpireMap.swift`, `CampaignMissionRuntime.swift`,
`CampaignCityEventSimulation.swift`, `CitySimulation.swift`,
`GameSessionController.swift`, and `MilitarySimulation.swift`; the source
addresses and EN/CH hashes are recorded in §§10.7a–10.7i above.

### 10.7k Event-manager range RNG is recovered, but its shared stream is not yet safe to wire (2026-09-04)

The static corpus does close the random source used by the event-manager update
without identifying a semantic event-range API. `FUN_004189B0 @ 0x4189B0`
advances two 32-bit shift-register states (`DAT_010C714C` and
`DAT_010C7148`) for 31 rounds, stores the low 7/15/3-bit projections, and
exposes the low 7 bits as `DAT_010C713C`. Startup `FUN_0052B590 @ 0x52B590`
seeds the pair with `0x54657687` and `0x72641663`; `FUN_00529A80 @ 0x529A80`
resets the 100-entry history cursor and warms the generator with 100 calls.
The only direct state stores found by corpus-wide search are these startup
seeds and the generator's own updates; `cMissionLoader` serialization at
`0x52F4D0` writes/reads both 32-bit states before the event-manager payload.
The EN/CH comparison rows for `0x4189B0`, `0x529A80`, and `0x52F4D0` are
`identical`.

`FUN_0049F8B0 @ 0x49F8B0` consumes this shared stream while an event record is
in its initial wait state: it calls `FUN_004189B0` three times and, based on
the raw event-type byte at record `+0x60`, computes the next wait from exact
modulo formulas. Types `0/1/2` use `3 + r0%12 + r1%12 + r2%12`; type `3`
uses `2 + r0%3 + r1%3`; type `4` uses `12 + r0%13 + r1%13`; type `5` uses
`1 + r0%3`; type `6` uses `7 + r0%10 + r1%10 + r2%10`; the default is `24`.
The three generator calls are still consumed even where a formula uses fewer
saved values. The same stream is consumed by unrelated figure, trade,
building, and network paths (`FUN_004925F0`, `FUN_00442200`,
`FUN_0054DF70`, and many other indexed callers), so these formulas cannot be
turned into a Qin-only scheduler RNG without recovering the complete call
order and save/replay boundary. `FUN_004AC650 @ 0x4AC650` runs the event-list
pass after the monthly simulation work, and `FUN_00523740 @ 0x523740` walks
the list before `FUN_004A5340`; neither function supplies an independent seed
or isolates the range stream.

Evidence class: **confirmed** for the generator algorithm, startup seeds,
100-call warm-up, save-state fields/order, per-type wait formulas, call sites,
and EN/CH identity; **unknown** for the semantic mapping of raw `+0x60` types
to authored event kinds, all other shared-stream consumers' exact ordering,
and the replay seed/state exposed to Native campaign starts. Native therefore
keeps its deterministic scheduler and does not claim source-timed Qin event
occurrences until that shared-stream contract is recovered.

The arithmetic is preserved as a non-gameplay research boundary in
`Sources/EmperorCore/CampaignEventRandom.swift` and covered by
`testOriginalEventManagerRandomMatchesSeedWarmupAndWaitBranches`. The helper
is independently saveable and deliberately has no caller from
`CampaignEventScheduler`.

### 10.8 Monument factor Native mapping contract (2026-08-16)

The original `FUN_0055AE30` pair-count walk (§3) is recovered and the
Native side is now fully specifiable:

- `FUN_00591200` adds `matching-pair-count × 2` to the per-update popularity
  sum (§2, §3). A pair is `(live root monument building, type-2 goal)`
  passing: live (`building+4 ∈ {1,3}`), monument family
  (`76…86, 92, 93, 253…268`), root (`sub-index == 0`), ID match
  (`building+0x14 == goal+0xC`, or `goal+0xC ∈ {85,86}` with
  `building+0x14 ∈ 253…268`), and part-weight percent `≥ 100`
  (`FUN_00565410(building+0xB4, 0, 0) >= 100`).
- Percent `≥ 100` is the **completion test**: the part-weight aggregate is
  100 exactly when every part is at its authored final phase, so for the
  factor a building contributes iff it is complete. Native completion flags
  are therefore isomorphic for this predicate:
  `MonumentProject.isComplete` (legacy 76–84/92/93),
  `PhasedMonumentProjectRuntime.isComplete` (77, 84),
  `LargePalaceProjectRuntime.isComplete` (82),
  canal `completedMonumentBuildingIDs.contains(83)` (33 parts at final
  phase), and Great Wall layout roots whose `sub-index 0` part is at its
  final phase (253…268).
- Native inputs: `CampaignMissionGoal` already exposes type-2 monument goals
  as `kind == .monument` / `requirement = .monument(buildingID: value(at: 0))`
  (including `85`/`86` for the Great Wall special arm), and
  `DeterministicAestheticState` holds all monument families above.

**Implementation contract (Phase 3/4):** add
`monumentPopularityTerm(goals:aesthetics:)` returning
`2 × count of (goal, complete root) pairs` per the predicate, recomputed
each popularity update; no `goal+8` stamp persistence is needed because the
original popularity walk recounts fresh each update and the pair count is
not decremented by later mismatches (§3). Verification: unit tests with a
synthetic city — completed tumulus 77 + goal `[77,0]` → term 2; two
completed roots for one goal → 4; partial → 0; wall goal `[85,0]` with a
complete layout root 253…268 → 2. Classification: predicate and completion
equivalence `confirmed`; the exact enumeration of Native wall roots and the
legacy monument ID set must be asserted in the implementation test.

### 10.9 Ferry post-pass and connector selection (2026-08-16, mechanisms recovered)

Qin relevance: ferry (building 210, menu 46) is constructible in Qin
missions 2–5 (`buildingMenuIDs` includes `46`), so the ferry gap is a Qin
blocker, not just a canal edge case. Direct disassembly (EN
`8a6d2df1…6753`):

- **Ferry vtable** connector segment `0x7AFE40` is the secondary segment at
  `0x7AFBD8 + 0x268`, where the constructor `FUN_004C5DC0` installs the
  complete object vptr. Its `+0x00`/`+0x04`/`+0x08` entries are respectively
  `FUN_004C6C50` (connector init), `FUN_004C6C70` (connector computation), and
  `FUN_004C6D30` (route-cache post-pass). The `.rdata` address `0x7AFE48`
  is the same segment's `+0x08` entry and therefore points directly to
  `FUN_004C6D30`.
- **Init** `FUN_004C6C50` (`0x4C6C50`): `[+0x924] = 0` and
  `rep stosd` fills `+0x154` (500 dwords) with `-1` — the connector array is
  empty by default.
- **Post-pass** `FUN_004C6D30` (`0x4C6D30`): reads `[+7]` = footprint side
  (6), double-loops the `6×6` offset table `0x81FF18` (6 rows × 6 dword
  offsets, 8-byte stride) and ORs `0x800` into the primary cache
  (`DAT_013789C0 + 2*cell`); then reads connector count `[+0x924]` and the
  dword array `[+0x154]`, and for each connector ORs `0x200` into the cache
  along the stored direction (cardinal cell deltas `±228` / `±1`).
- **Connector computation** `FUN_004C6C70` (`0x4C6C70`, ferry vtable
  `+0x04`): calls `FUN_005B3670` with the connector array (`&ferry+0x154`)
  and limit `1001`, then stores the returned count into `[+0x924]`.
- **Selection walk** `FUN_005B3670` (`0x5B3670`): from the ferry perimeter,
  each step examines the **four cardinal** candidates (table `0x85DE64`,
  4 entries × 8 bytes; offsets `-228 / +1 / +228 / -1` = N/E/S/W; the bytes
  after `0x85DE84` belong to a neighbouring table) and reads the **flood
  map** `DAT_01391FE0[cell]`; it picks the candidate with the minimum
  nonzero flood value (ties broken by a bound compare against
  `DAT_00F1E780[cell] & 3` when the rotation argument is 1), i.e. it walks
  the min-flood gradient toward the seed, advances the current cell by the
  chosen cardinal delta (`ebx ∈ {0,2,4,6}` → N/E/S/W), stores each chosen
  direction byte into a 500-entry buffer, and stops when the flood value
  reaches `≤ 1` (the seed) or the buffer is full; the direction bytes are
  then copied into the connector array and the count returned.
- **Placement flood** `FUN_005B33C0` (`0x5B33C0`): a second flood variant
  seeded from a ferry-adjacent cell whose start byte layer at
  `0x136BEB0` is not `-1`, filling `DAT_01391FE0` with its own pass
  predicates before the gradient walk runs. Direct EN disassembly closes the
  directional source arithmetic: north tests `0x136BDCC[current]`, east tests
  `0x136BEB0[current + 1]`, south tests `0x136BF94[current]`, and west tests
  `0x136BEAF[current]`; each non-forced neighbour additionally requires its
  direction-specific terrain byte's bit 0 to be clear (`0xF6A9E2`,
  `0xF6A9E6`, `0xF6AD72`, and `0xF6A9DE` addressing respectively). The
  gradient tie source is likewise confirmed as `0x10C713C & 3` (not the
  earlier `0x10C773C` transcription). The expansion loop (`0x5B3447`+)
  admits a neighbour only when `flood[neighbour] == 0`, excepting the seed and
  footprint-edge endpoint, and writes `current + 1` with a 50,000-iteration
  bound. The PE layer arrays and terrain projections are not yet mapped to
  Native's serialized map state.

**Classification:** vtable/init/post-pass mechanics, the gradient-walk
shape, flood pass predicate, per-direction byte-layer bases, and the
`DAT_010C713C & 3` tie-break source are `confirmed`; the PE-layer-to-Native
projection, reset scheduling, and placement call path are still `unknown`
implementation-verification items.
**Implementation consequence:** the ferry post-pass contract is now fully
specifiable — persist the connector array (`+0x154`, direction bytes
`0/2/4/6`) and count (`+0x924`) per ferry object (new optional-backed Native
state), compute connectors at placement with the flood-guided gradient walk,
and apply `0x800` footprint + `0x200` connectors after base derivation in
the primary cache. Until it lands, ferry maps stay fail-closed
(`house+0x24` unknown on ferry maps, plan 006 Phase 1a).

### 10.10 Food factor contract (2026-08-16, research closed)

The `cHouseInfo+0x36` byte is a **0–100 raw quality value in the same units
as Native `OriginalFoodCatalog.quality(in:)`** (`0/20/30/50/70/90` nominal;
blends produce intermediates). Player-facing names come from
`FUN_00545100`: `>89 → 5 delicious, >69 → 4 tasty, >49 → 3 appetizing,
>29 → 2 plain, >0 → 1 bland, 0 → none`. The popularity walk
`FUN_00590F30` compares the **raw byte** against the model's required
`EVO_FOOD_QUALITY` (column 8), not the band.

Recovered lifecycle (all `confirmed` sites in §3):

1. **House food stock**: word slots at `cHouseInfo+0x12 + slot*2`
   (`FUN_00447600`); slot 0 = Dinners (`Trade.txt` 0-based ID 28). Monthly
   depletion `FUN_00518690` (month rollover) consumes
   `(residents * 25) / 100` from slot 0; when the remaining stock is
   `< 1`, it zeroes the word **and** `+0x36 = 0`.
2. **Market quality** `cMarket+0x180` (0–100 dword): constructor zero;
   `cStall+0x260` (`FUN_00541760`) weighted blend on mill-cart return —
   `new = round((old*oldStock + 20*accepted*(byte figure+0x13)) /
   (oldStock+accepted))`; zero when Dinners stock depletes; hero bless
   (`FUN_00511080` case 4) raises up to `+0x184` cap.
3. **House delivery** `cMarket+0x2c` (`FUN_005437B0`): adds Dinners into
   slot 0; writes `cHouseInfo+0x36` at `0x543A09` — replace when the
   market quality is higher, else blend with `r = delivered/existingStock`
   using the five documented ratio arms (3.0 / 2.0 / 0.5 / ≈0.33 thresholds;
   `(c+3m)/4, (c+2m)/3, (c+m)/2, (2c+m)/3, (3c+m)/4`).
4. **Consumer**: `FUN_00590F30` scores `+2` when raw `+0x36 ≥ required`,
   otherwise increments the streak byte `house+0x5C` (capped 3, mapped
   `1→−1, 2→−2, ≥3→−3`); mean across occupied houses with required > 0,
   round-away-from-zero only when `abs(remainder) > count/2`, and `< 0`
   returns 0 when population < 350 and never exceeded 349.

**Native implementation contract (Phase 3/4):** `ResidentialUnit` must carry
the Dinners stock word and the raw `+0x36` quality byte (both save-backed),
with monthly depletion and the market-delivery replace/blend per the
recovered arms; `cMarket+0x180` per-market quality must be maintained by the
existing peddler/buyer delivery path with the stall blend. The existing
`OriginalFoodCatalog` 0/20/30/50/70/90 values are the correct units; the
non-isomorphism to remove is the current consumption/blending cadence, not
the unit scale. Player-facing text uses the `FUN_00545100` bands.
Classification: lifecycle and arithmetic `confirmed`; the complete
`+0x36` writer set remains `inferred`-complete (four sites + market blend
enumerated, §10.5).

#### 10.10a Exact lower-ratio constant (2026-08-30)

The final market-delivery blend comparison was checked directly against the
canonical English PE (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`)
and the Chinese PE (`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`).
At `0x5439CB` the callback `FUN_005437B0` performs `fcomp dword ptr
[0x8090180]`; the corresponding recovered data constant is the IEEE-754
single `0x3EA8F5C3` (`0.33000001311302185`). The three preceding comparisons
remain the exact singles `3.0` (`0x40400000`), `2.0` (`0x40000000`), and
`0.5` (`0x3F000000`). The EN/CH callback bytes are identical at this site.

This matters only for ratios in the narrow interval `(0.33,
0.33000001311302185]`; a rational regression fixture (`251659 / 762603`)
falls in that interval and confirms that Native takes the recovered final
`(3 * current + market) / 4` arm. The change is arithmetic fidelity only. It
does not identify the unresolved `cMarket+0x180` producer, route/coverage
writer, or complete house-quality writer set, so no additional Qin-3 behavior
is enabled.

#### 10.10b Mill recipe type-count selector (2026-08-30)

The unsplit mill method at `0x555330` was checked directly in both
hash-matched PE inputs. The `0x555330…0x55540D` slice is 222 bytes and has
SHA-256 `96adc3a7b6c472af0ea62a6ddbb2cbc20c5e5113c64caec0c24dbb1bcd1168a5`
in both the English build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
Chinese build
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
There is no standalone `functions-index.csv` row for this method; its caller
`FUN_005464E0 @ 0x5464E0` invokes mill vtable `+0x2E4` with the market's
type-count cap, current type-count lower bound, a hundred-rounded request,
and two output arrays.

The method initializes six output words to zero, materializes each mill
`+0x2E0(typeCount)` availability (the first pass runs from the cap down to
the lower bound), then performs its selection pass from lower bound through
cap. It chooses the highest type count whose availability is strictly
greater than the fixed signed quotient `request / 3` (the `0x55555556`
multiply at `0x555385…0x555397`). The caller's request is already rounded
down to a hundred units; the selector itself does not divide by the
type-count cap or round its threshold to a hundred. If no candidate clears
that threshold, it keeps the first non-zero availability encountered. With
a choice, it clips the request to the selected availability and then to
`600` before calling vtable `+0x2EC`; the downstream writer itself early-outs
for a non-positive amount. No choice returns zero and leaves the output arrays
empty.
The current constructors establish the valid range as
`1…3` for Common Market and `1…5` for Grand Market (`+0x184`), with the
lower bound initialized to `1` (`+0x188`).

This arithmetic is represented by the pure
`OriginalMillFoodRecipeSelector` in `Sources/EmperorCore/FoodSimulation.swift`
and independently tested. The selector returns a **recipe type count**, not
an authored quality band: `FUN_005464E0` passes it to `FUN_00546960`, which
writes cart `figure+0x13`; the later cStall blend contributes
`20 * figure+0x13` to `cMarket+0x180`. The type-count-to-market settlement,
cart route/deposit lifecycle, and the complete `cHouseInfo+0x36` writer set
remain unknown, so this primitive is not wired into live Qin peddler or
buyer settlement.

**Evidence class:** **confirmed** for the byte-identical selector body,
caller argument order, strict threshold comparison, first-nonzero fallback,
ascending/highest selection, 600-unit cap, and cart handoff; **unknown** for
the remaining vtable `+0x2E0/+0x2EC` availability/output mappings and all
downstream market settlement semantics.

### 10.11 Implementation status (2026-08-17)

Phase 3 pieces landed in Native (all green, 322 tests):

- **Land-entry flood** (`DeterministicMigration.landEntryFloodDepths`):
  4-neighbour N/E/S/W flood over the main derived cache with mask `0xB7C`,
  depths `n+1`; tested on Haunxian (mask consistency + determinism).
- **Settling lock**: `ResidentialUnit.settlingLock`/`RemainingSteps`,
  `startSettlingLock` (32), daily `advanceSettlingLock` (empty clears
  immediately, §10.6), armed by housing-devolution displacement; arrival
  write skips while set.
- **Vacant lifecycle**: `ResidentialUnit.vacantTypeID` (`2`/`11`), set by
  `constructHouse`; `activateVacantHouse` applies the `+0x230` switch on
  first occupancy (common stays level 0, elite 8 → 10).
- **Immigrant figure #11** (`ImmigrantWalker`): states `6→7→8`, wait word
  from the recovered `(house+0x51 & 0xFF7F) + DAT_00D62418` formula
  (`house+0x51` semantics unknown → 0, recorded inference), movement with
  the 1/1/2 substep cadence and 20-substep route steps, arrival via the
  `0x4CA265` write (`settling` gate → vacant switch → clamped residents
  add); route from the authored land entry via the recovered mode-1/mode-19
  worker pathfinder; Native-day bridge `floor(day×816/30) −
  floor((day−1)×816/30)`. Spawned only by fixtures while the producer is
  unsupported.

Still pending (Phase 3/4): the popularity/pressure/request producer with the
food/monument/war factor wiring, the ferry post-pass, and the final
save-migration + playthrough-test gate. The producer remains
`unsupportedOriginalProducer` in production until then.

### 10.12 Implementation and verification status (2026-08-17, second pass)

The producer is **implemented and enabled in production**:

- `GameSessionController.startCampaignMission` sets
  `AutomaticMigrationAvailability.supportedOriginalProducer` and the
  `CampaignMigrationContext` (monument goals, wage, debt months) at mission
  start and each monthly advance.
- The daily tick runs the popularity update (slice days 1/16), the
  `FUN_005917E0` pressure/request/cooldown pass, and the `FUN_004AD4A0` +
  `FUN_004ADA10` three-pass assignment (with the in-flight skip on all three
  passes), spawning `ImmigrantWalker` figures that walk from the authored
  land entry and perform the `0x4CA265` occupancy write.
- Fixed en route: the city routing-cache projection now treats every placed
  building as blocking (`+0xCC == false` default) and non-wall/non-canal
  monuments as blocked in the fallback cache, so the grid no longer throws
  for normal cities (wells/shrines/towers/palace/ruins); the housing
  evolution now gates on the **target** level's authored requirements
  (Plain Cottage needs food 20, ancestor; Spacious needs herbalist/music),
  so the missing-market counterexample correctly cannot win.
- Verified playthroughs (all with the real producer, no state injection):
  Xia tutorial 0 victory + counterexample, **Qin 1 (Zheng Guo's Canal +
  iron 1800)**, and **Qin 2 (First Emperor's City, elite housing chain)**.
  Full suite: 324 tests, 0 failures; the only remaining skip is the Xia-2
  continuation, blocked on a separate new-map food-coverage item (some
  inherited houses fall outside the added markets' peddler coverage and
  devolve).

Remaining for the producer: departures (emigration) still fail-closed
(§4), the ferry post-pass (§10.9) for ferry maps, the Qin invasion enemy
model runtime observation (§10.7), and Qin 3/5 player playthrough tests +
the Qin-4 Great Wall first-playable state.

### 10.12a Current production gate correction (2026-08-30)

The second-pass integration note above is historical evidence of an earlier
experimental enablement; it is not the current production contract. The
remaining food/monument/war factor inputs, map/object registration, and full
arrival-writer mapping are still unresolved in the source-first audit. The
current `GameSessionController.startCampaignMission` therefore explicitly
sets `AutomaticMigrationAvailability.unsupportedOriginalProducer`, while the
supported mode remains available only to focused fixture tests. This keeps a
normal Qin mission from presenting guessed population growth as recovered
behavior.

The Qin-1, Qin-2, and Xia-1 player-command replays now use the same gate: their
prior `requireAutomaticMigrationProducer()` no-ops were relying on the
historical experimental enablement and failed with zero planned immigrants
after the production correction. They are explicit `XCTSkip`s until the
producer contract is independently recovered; their baseline/start checks
remain active. This is a test-integrity correction, not evidence that the
missions are complete.
The Xia-2 continuation replay is likewise gated by the same producer
condition, in addition to its independently unresolved inherited-house food
coverage.

### 10.13 Qin playthrough status (2026-08-17, third pass)

- **Qin 1 (Zheng Guo's Canal)** and **Qin 2 (First Emperor's City)** player
  playthroughs pass end-to-end with the real producer (no state injection).
- **Qin 3 (Land of Annam)** playthrough scaffolding is in place but **not yet
  verified**: the rice-farm → mill food chain does not produce on the
  Xiangjun map (mill stays empty, houses remain below the food-20 gate, and
  the treasury sinks to continuous debt). The diagnostic loop shows
  `mills=[[:]] buyers=0 peddlers=0 foodAtHouses=0` while the lacquer chain
  partially produces, pointing at farm-field placement / worker allocation
  on this map rather than the migration producer. Test is skipped with this
  note.
- The full suite is green: 325 tests, 2 skips (Xia-2 continuation coverage,
  Qin-3 WIP), 0 failures.

### 10.14 Qin-3 progress (2026-08-17, fourth pass)

The Qin-3 playthrough city now has a working food chain: the mill holds
rice/fish/meat (three food types → appetizing 50), food quality 50 reaches
residents, and the yearly lacquer goal (1,800) is met. The precise remaining
blocker is the **trade-station delivery**: imported hemp (19) and jade input
(17) stay in the stations (`active=nil`, correct `importingCommodityIDs`)
and never move to the warehouses/shops, so houses stall below level 3 (no
hemp) and the city sinks to continuous debt. The station→warehouse pair at
access (76,86)/(77,86) is the next trace target in `createTradeDelivery` /
`bestWarehouseDestination`. The test stays skipped with this note.

### 10.15 Qin-3 progress (2026-08-17, fifth pass)

Root cause of the stalled trade delivery found: the warehouses fill to their
3,200 capacity with production/exports, leaving `availableCapacity(for:)`
zero for imported hemp/jade, so `bestWarehouseDestination` returns nil. After
adding warehouse capacity, the **hemp import now delivers** (a
`tradingBuilding → warehouse` delivery walker is observed and the station's
hemp is consumed). The remaining blocker is layout on the constrained
Xiangjun map: the jade input station has no warehouse/workshop site within
the deliveryman's 24-step range, so jade (26) stays at 0 and the city sinks
to continuous debt. Next step: place trade stations + warehouses before the
houses congest the district (or widen the placement search). The test stays
skipped with this note.

### 10.16 Qin-3 progress (2026-08-17, sixth pass)

The Qin-3 city is now economically solvent end-to-end and the carved-jade
chain is closed:

- **Jade delivery** (§10.15) fixed by layout: placing the trade cluster
  (hemp station → jade workshop → jade station → warehouses) **before** the
  food chain/markets/houses keeps the workshop inside the export station's
  24-road-step range. Observed live walkers:
  `productionBuilding → tradingBuilding:26x100` (carved-jade export) and
  `tradingBuilding → productionBuilding:17x100` (jade input). Treasury
  stays positive for 12 simulated years; the carved-jade yearly goal
  (1,200) is met.
- **House food-quality write** (`ResidentialUnit.addFoodSupply`) now follows
  the recovered §10.10 `0x543A09` contract: a better market delivery
  **replaces** the house quality byte; a worse one blends by the confirmed
  five-ratio integer table (`r = delivered/existingStock`, branches
  `3/2/0.5/≈0.33`; integer `/3` `/4` per the `imul`/`sar` identities).
  The previous min-blend locked houses at the first delivered quality
  (30 = fish+meat) and blocked food-50 evolution. Elite houses (level ≥ 8)
  skip the quality write while market quality ≤ 49 (`FUN_005188D0` gate).
  Evidence class: `confirmed` (bytes/arithmetic in §10.10).
- **Warehouse policy**: refusing food commodities (1…7) at every warehouse
  keeps capacity for hemp/jade/carved-jade; stock-managed hemp import
  (pause ≥ 3,000, resume ≤ 500) prevents the export station from filling
  with hemp.
- **Residential service cadence — superseded by recovered control flow
  (2026-08-26)**: the one-road-tile/day and ten-road-tiles/day models were both
  Native inferences and are withdrawn. The executable closes the original
  month as 816 scheduler/figure steps, with service spawning at scheduler
  phase `0x1F`, coverage decay at `0x23/0x30`, one movement micro-step per
  figure update for the recovered code-6/code-8 paths, finite outbound range,
  and a non-covering return path. Coverage uses independent countdown bytes,
  not a monthly reset. Native now distributes the exact 816-step month over
  its 30-day compatibility calendar. Full addresses, provider-specific worker
  thresholds, selector-15 range scaling, coverage constants, junction fields,
  provider exit-heading persistence, and unsupported figure FSMs are recorded in
  `residential-service-roamer-lifecycle.md`. Any Qin/Xia fixture conclusion
  derived specifically from the former ten-tiles/day cadence is no longer
  fidelity evidence and must be revalidated against the recovered lifecycle.
- **Qin 3 player-replay boundary (2026-08-26)**: a map-aware, player-command-only
  layout anchored on the largest clear authored-groundwater district closes
  three-food delivery and raises housing through levels 0...3. After the full
  generic roamer recovery (including `0x4E71D0` signed fallback rotation,
  coverage eligibility and sixteen-sector occlusion), a fresh 120-month run
  still services only 27 of the initial 40 houses and ends with population 265,
  no level-6 residents, lacquer 1,200/1,600 and carved jade 1,200/1,200. Its
  final live missing requirements include water and music; music figure `#34`
  uses the separate `0x48A9A0` venue FSM, while the water `+0x32/+0x34` split,
  market-peddler coverage, and desirability chain remain outside the closed
  generic bridge. Further layout tuning is not evidence of original behavior.
  The full Qin-3 playthrough therefore remains fail-closed/skipped. The closed
  generic lifecycle is tracked in `residential-service-roamer-lifecycle.md`.
- Rice harvests only in month 10 (one 100-unit load per field), so the
  mill's rice stock drains and market food quality oscillates 30/50 between
  harvests; salt/spices are not available in this mission. Map/economy
  constraint, not a producer defect.

### 10.17 Qin-3 market-peddler follow-up (2026-08-30)

The static corpus closes an additional timing fact for the remaining Qin-3
coverage blocker. Peddler think row `0x4D0270` (the split corpus has no
standalone function row for this interior entry) always calls
`FUN_004E3A80`. That handler resolves selector `8` and calls
`FUN_004E6B70`; the same code-8 path used by the recovered water carrier
executes the `1/1/2` substep cadence and accounts movement budget in units of
`8` per figure update. The peddler's authored figure row `23` has behavior
range `60`, and the shared selector-15 accessor stores that as `60 × 96 =
5,760` budget units. This is an upper bound of `5,760 / 8 = 720` figure
updates; `FUN_004E3A10` can transition earlier once the figure is back at its
provider after the recovered `4/5` budget gate. Coverage is
issued by the shared `FUN_004EACD0` crossing callback; its market writer is
`cMarket+0x2C` at `0x5437B0`, not a special peddler-only call.

This is **confirmed** control flow from `FUN_004E3A80`, `FUN_004E3A10`,
`FUN_004E6B70`, `FUN_004EACD0`, and authored figure row 23. It does not close
the peddler's route-heading/collision details or the complete writer set, so
it is not an implementation contract by itself. Native currently advances a
precomputed `MarketPeddler` route with `10` road points per Native day
(`CitySimulation.swift`), which is a known temporary approximation and must
not be used as Qin-3 fidelity evidence. The route/coverage bridge remains
fail-closed for the playthrough gate until those missing branches are
recovered.

#### 10.17a Peddler code-8 return gate (2026-08-30)

The split corpus closes the early-return predicate used by the peddler's
water-shaped handler. `FUN_004E3A10` is `identical` in the EN/CH
`compare-report.tsv` and is called from `FUN_004E3A80` while figure state is
`1`. It returns true only when all of the following hold:

* figure type byte `+0x12` is neither `%` nor `O`;
* traveled-budget word `+0x4C` is at least `(behaviorRange × 4) / 5`; and
* figure coordinates `+0x1C/+0x1E` equal the saved coordinates
  `+0x15C/+0x15E`.

When the predicate is false, `FUN_004E3A80` continues through
`FUN_004E6B70(..., selector-8 result)`. When it is true (or when the budget
already reaches the stored range), the handler selects the provider/market
return coordinates, requests a route with `FUN_004BA580(..., 2)`, enters
state `2`, clears `+0x4C`, and clears the active route bookkeeping. A failed
route request writes figure failure byte `+0x16 = 2`. The `%`/`O` exemptions
therefore bypass the `4/5` early-return test, but do not by themselves prove
those models' complete route semantics.

This is a **confirmed** budget/coordinate gate, not a route implementation
contract: `FUN_004E3A80`'s heading choice, collision branches, and complete
market writer set remain unresolved, so Native keeps the peddler bridge
unsupported rather than substituting a fixed route length.

#### 10.17b Market peddler spawn threshold (2026-08-30)

The generic provider figure generator is `FUN_0051CF90 @ 0x51CF90`, present in
the split corpus and `identical` in the EN/CH compare report. Its vtable slot
`+0x234` applies the common figure-type, global-cap, provider-active and
positive-worker gates before calling a provider-specific threshold method and
incrementing a `+0x36` counter. That generic routine is useful context for the
shared provider lifecycle, but it is **not** the peddler-specific threshold
contract below.

The peddler-specific market wrapper is `FUN_00543ED0 @ 0x543ED0`, present in
the split corpus and `identical` in the EN/CH compare row. It computes an
assigned-worker percentage from `FUN_00544A80(-1)` over the authored employee
total from `FUN_00544A40`, then maps that percentage to the peddler counter
thresholds below. This is distinct from the generic `FUN_0051CF90` provider
generator and its common `0x51CF40` threshold table.

| worker percentage | threshold | spawn opportunity after strict `>` |
| ---: | ---: | ---: |
| `100+` | `2` | counter `3` |
| `75…99` | `3` | counter `4` |
| `50…74` | `4` | counter `5` |
| `25…49` | `5` | counter `6` |
| `1…24` | `10` | counter `11` |
| `0` | — | no opportunity (positive-worker gate) |

`FUN_00543ED0` first applies the model-23 slot gate and the provider's
`+0x268` virtual availability gate, then increments `+0x36` and calls
`FUN_00544910` before attempting the model-23 allocation. The threshold,
strict counter transition, and `+0x268` provider-quantity predicate are now
closed at the control-flow level. Selected road-origin semantics and the
downstream `FUN_004E3A80` route/coverage/writer behavior remain the Qin-3
fail-closed boundary; see §10.22 for the `+0x268` record walk.

#### 10.17c Peddler think-wrapper body (`0x4D0270`, 2026-08-30)

The split corpus has no standalone row for the interior type-table entry
`0x4D0270`. A direct static read of the hash-identified canonical EN and CH
PEs recovers the complete body from `0x4D0270` through the `ret` at
`0x4D0362` (243 bytes, SHA-256
`d74bf5fa923b659514e4eaf83e7e588f3ca338e4eedc2d02c9aab74f8514771e` in
both files). No byte or branch differs between the two builds. The entry is
reached indirectly through the figure type-table slot already identified in
this section; no direct `E8` caller to `0x4D0270` exists in either PE.

The recovered wrapper performs the following operations, in order:

1. Resolve the active figure through `FUN_0047F1B0` using the global figure
   context, set figure byte `+0x80` to `0x12`, clear `+0x14`, and call the
   common figure vtable `+0x114` with selector `15`. The returned word is
   stored at `figure+0x4A`; for authored peddler model 23 this is the
   previously recovered `60 × 96 = 5,760` range budget.
2. Resolve the market object from the signed market id at `figure+0x62`.
   If the market state byte at `market+4` is `1`, call its vtable `+0x48`
   with the global context and retain the returned boolean only as a failure
   test. A non-ready market, or a false result, writes `figure+0x16 = 2`.
   The vtable slot's semantic name is not recovered here.
3. Increment the figure animation/frame byte `+5`, wrapping to zero when
   the incremented value reaches `0x0C`.
4. Only while `figure+0x40 == 1`, call the market method at `0x543E40`.
   When that method returns non-positive, the traveled-budget word
   `figure+0x4C` is below `0x240`, and current coordinates
   `+0x1C/+0x1E` equal the saved pair `+0x15C/+0x15E`, copy the range word
   `+0x4A` into `+0x4C`. This is a wrapper-side refill/continuation gate;
   it does not identify the route or collision semantics of `0x543E40`.
5. Always call `FUN_004E3A80(figure, 1)`, the shared peddler roam handler.
   The wrapper then computes the global eight-way heading delta from
   `figure+0x19` and `DAT_0101D0D0`, stores the signed result in
   `DAT_0115F71C`, and normalizes negative values by adding eight.
6. If `figure+0x40 == 4`, derive a half-width value from signed
   `figure+0x3E`, call `FUN_005CFDF0(0x4C02, derived, 0)`, and store the
   returned value at `figure+8`. This final branch is a state side effect;
   its resource meaning is not identified by the corpus.

The body therefore confirms the peddler's per-update budget refill,
12-frame wrap, failure byte, heading-delta side effect, and unconditional
handoff to `FUN_004E3A80`. It does **not** expose the route-buffer consumer,
tile collision policy, crossing callback ordering, or the complete market
writer set. Those unknowns still block a legal Native peddler/coverage
bridge, so this evidence is not an implementation contract by itself.

#### 10.17d Peddler return-target search (2026-08-30)

The route request made by `FUN_004E3A80` is not a fixed road-length or a
nearest-cell shortcut. For the peddler's normal branch, the handler first
selects one of two market coordinate pairs: the market object's `+0x0A/+0x0C`
pair when its `+0x14` word is outside `59…60`, or the alternate `+0x2A/+0x2C`
pair when it is inside that interval. The first choice is returned by the
market vtable `+0x19C`; the direct EN/CH bytes at `0x416AF0` are
`0F BF 41 1C C3` (SHA-256
`26a0282020e5e48ef15dd8e47b139c01a80aa9de859c26668c2eee6737062ce8`), a
signed 16-bit read of the market object `+0x1C`. The interval branch calls
`FUN_00544910`, whose result is taken from the shared search globals.

`FUN_004BA580` then tries rotations `0…2` (inclusive) and delegates each
attempt to `FUN_004BA370`; both functions are `identical` in the EN/CH
`compare-report.tsv`. `FUN_004BA370` clamps a rectangular tile scan to map
bounds, invokes a nonzero tile object's vtable `+0xD0` adjustment callback,
and accepts a candidate only when its tile word satisfies
`(DAT_00F6A9E0[index] & 0x44) == 0x40`. Among accepted cells it compares the
tile auxiliary byte `DAT_00EC5A10[index]` against the 12-entry pair table
`DAT_01312588`, retaining the lowest matching table index. On success it
writes the selected coordinates to `DAT_010C72AC/DAT_010C72A8` and returns
true only for a table index below `0x0C`; failure leaves the peddler's figure
failure byte `+0x16 = 2` through the caller.

This is **confirmed** endpoint-selection control flow from
`FUN_004E3A80`, `FUN_004BA580`, `FUN_004BA370`, and the direct `0x416AF0`
method. The corpus does not identify the semantic names of the tile-word
bits, the 12-entry priority table, the `+0xD0` adjustment callback, or the
route-buffer/collision consumer after these coordinates are returned.
Consequently it closes the peddler's return-target predicate but not a legal
Native route implementation; the Qin-3 peddler bridge remains fail-closed.

The Native production bridge now honors that boundary: when
`originalSpawnGate == true` (the original phase-`0x1F` scheduler), a missing
recovered route prevents allocation and leaves the market stock untouched.
The deterministic patrol fallback remains available only through the older
explicit fixture API (`originalSpawnGate == false`). This prevents unresolved
route behavior from changing Qin simulation state while the endpoint and
collision consumers are still being recovered.

The same bridge exposes an explicit compatibility switch only for unscoped
Native sandbox cities (where `missionSettingsState == nil`); those fixtures
retain the pre-existing deterministic patrol observations. Campaign-backed
cities, including Qin mission starts, keep the switch disabled and therefore
remain fail-closed. This is a test/compatibility boundary, not evidence that
the patrol route is the original model-23 route.

#### 10.17j Campaign bridge rejects household routes even when they resolve (2026-08-31)

The strict boundary is stronger than a missing-route guard. In the campaign
path, `originalSpawnGate == true` now bypasses `Self.deliveryRoute` entirely,
even when the Native household-targeting route happens to produce a non-empty
path. The recovered English executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and
Chinese executable
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` are
`identical` for the relevant rows: `FUN_00543ED0 @ 0x543ED0` calls
`FUN_00543160 @ 0x543160` to select a market-owned record and creates model
`0x17` through `FUN_004EA050 @ 0x4EA050`/`FUN_004E1420 @ 0x4E1420`;
the figure's state-1 path calls `FUN_004E3A80 @ 0x4E3A80`,
`FUN_004BA580 @ 0x4BA580`, and `FUN_004BA370 @ 0x4BA370` to choose an endpoint
from the map-cache and its 12-entry component-priority table. Outbound mode
`0x12` then uses `FUN_004E83E0` → `FUN_005B00D0` → `FUN_005B0220` →
`FUN_005B18B0`, a cardinal cache BFS/gradient writer. None of these recovered
calls consumes a house list.

The map-cache-to-`RoadNetwork` projection, endpoint semantic mapping, and
collision/resource consumers remain **unknown**. Therefore a successful
`Self.deliveryRoute` is not evidence-equivalent to the original model-23
route. Only the explicit `allowCompatibilityRouteFallback` switch may consume
the household route/patrol fixture; Qin campaign scheduling leaves both
commodity and food peddlers unallocated until that projection is recovered;
food bundles are not withdrawn before this unresolved route gate. This
conclusion is **confirmed** by the static call chain and is covered by
`testOriginalMarketPeddlerSchedulerNeverUsesHouseholdRoute` (commodity path);
the food branch uses the same strict gate before withdrawing any bundle.

The 12-entry priority table is not an authored constant table; its population
is now bounded by the shared map-region pass. `FUN_004AF350 @ 0x4AF350`
clears eleven `(componentLabel, componentSize)` pairs at
`DAT_01312588…DAT_013125DC`, clears the `0x32C4`-cell auxiliary/type arrays,
then scans the active map row-major. A new component starts only when
`FUN_004AF310` accepts the cell (`DAT_00F6A9E0[index] & 0x44 == 0x40`) and
`DAT_00EC5A10[index]` is still zero. `FUN_004AF490(index, label)` marks the
component with that label and expands it through the four dword offsets at
`DAT_00820CD0`: `[-228, +1, +228, -1]` (north/east/south/west). Direct EN/CH
PE bytes for this 16-byte table are identical
(`1cffffff01000000e4000000ffffffff`, SHA-256
`7cbbe9bc14b2f89dc42e222ca999350d706300354eb4278cea350c1cbe7f5304`). A
neighbour is admitted when its primary cache word intersects `0x0B0C`, bit
`0x08` is additionally gated by terrain bit `0x400`, and its auxiliary byte
is zero. The pass increments the component size for each marked cell and
inserts the label/size pair into the eleven-entry table by strict size
improvement, preserving discovery order for ties. `FUN_00534BF0` invokes this
pass during map initialization, and the scheduler's `FUN_004AC2B0` case `7`
invokes it again; both function rows are EN/CH-identical.

This closes the priority-table **producer** and its cardinal component
arbitration. It does not name the terrain/cache bits, identify the complete
`+0xD0` adjustment callback, or expose the route-buffer/collision consumer;
therefore the peddler endpoint coordinates remain a research boundary and
the Native Qin-3 bridge stays fail-closed.

The `+0xD0` adjustment callback itself is now bounded for the generic object
family. Base/House/Well/Entertainment vtables point to `FUN_00426D80 @
0x426D80` (EN/CH-identical, 67-byte slice SHA-256
`c588957e2f2d42cf105c0763045438e5a0050ea387eaf0e39979a580b78c9bcd`). It
returns `-1` for model `0x7E` and for the residential wall/gate predicate
`FUN_00415700`; returns `0` for every other model; and only for Grand Way or
Imperial Way (`0x6F/0x71`) calls `FUN_00420EB0` to move the supplied linear
offset to the adjacent cell selected by the target's road-direction byte,
then writes that adjusted offset back. `FUN_00420EB0` is EN/CH-identical
(45-byte slice SHA-256
`2225cf1da07142c06fd5a5b6f9c21d9f649bd8bb1f580999a5093725e68b9c86`): when
the target lacks terrain road bit `0x40`, direction low bits `1/other` move
east/west (`±1`), while low bits zero with mask `0x38 == 8` move south,
otherwise north (`±0xE4`).

The cMarket override is `FUN_00544E70 @ 0x544E70` (EN/CH-identical, 35-byte
slice SHA-256
`d36f1091d5fa34e1f76b471c883098f1b5b8fa5e351334c636d94c4e048d2670`). It
calls the market's vtable `+0x194` on the adjusted linear cell and returns
success while storing the resulting offset; the `+0x194` method's market
coordinate semantics remain unresolved. Thus endpoint selection now has a
confirmed object-adjustment branch and a separately isolated cMarket
override, but the route-buffer/collision consumer is still unknown and no
Native peddler route is enabled.

The common-market `+0x194` method is now bounded to its helper scan:
`FUN_00544EA0` calls `FUN_00542350 @ 0x542350` on the object at `cMarket+0x158`.
The EN/CH function bodies are identical (`local/source/compare-report.tsv`,
237-byte slice SHA-256
`1c64ad616ba7efb47532d057fd8a10552083acecb587e10c0dae82b423fbcb9b`).
Given the adjusted target cell, it enumerates the helper's `+0x6C` records in
their stored order, obtains each `(x,y)` through `+0x70`, computes Manhattan
distance to the target, and retains the strict nearest record (initial best
distance `500000`; ties preserve record order). It returns that record's
linear map index, or the original target when the helper has no records. This
closes the market-side `+0x194` nearest-entrance reduction, but the helper
record population, route-buffer consumer, and collision/coverage settlement
remain unknown; Native still must not infer a peddler route from this reducer.

#### 10.17e Peddler market-slot gate (`+0x48`, 2026-08-30)

The market check in the recovered `0x4D0270` wrapper is not a generic
"market has stock" test. For the common market vtable `0x7B6F3C`, slot
`+0x48` points to `FUN_004295C0`; its EN/CH bodies are `identical` in the
split corpus. The method first calls the receiver's `+0x54` type accessor and
then compares the runtime id passed by the wrapper against the market's
stored id fields:

* type `1`: compare only market `+0x2E`;
* type `2`: accept `+0x2E`, otherwise compare record `+0x6A`;
* type `3`: accept `+0x2E`, otherwise compare record `+0x6A`, then `+0x6C`;
* any other type: return false.

The common-market `+0x54` entry is the interior method `0x543FF0` (not a
standalone split row). Direct EN/CH bytes at `0x543FF0…0x543FFD` are
`33 C0 66 83 79 14 3C 0F 94 C0 83 C0 02 C3` (14 bytes, SHA-256
`a50381afd77192a96185bea5aec124c7898ad9c5e825b047be028ca365aa0655` in
both PEs), returning `3` exactly for building ID `60` (Grand Market Square)
and `2` otherwise (including building ID `59`, Common Market Square).

In `0x4D0270` the gate is evaluated only when market byte `+4 == 1`; a
non-matching market state or a false `+0x48` result writes figure `+0x16 = 2`.
This closes the market-type dispatch and slot-membership comparisons, but
the semantic names/lifecycle of `+0x2E`, record `+0x6A/+0x6C`, and the
meaning of the market-state byte remain unknown. It therefore does not
authorize replacing the unresolved peddler route/coverage/writer contract
with an inventory or worker-count shortcut.

#### 10.17f Original peddler slot capacity (2026-08-30)

The executable's peddler-capacity gate is a live-figure slot count, not the
number of shop bays attached to a market. `FUN_00543ED0` asks the market
vtable `+0x4C` whether a figure of model `0x17` can still be admitted before
it increments the spawn counter or calls `FUN_004EA050`. For the common
market vtable `0x7B6F3C`, `+0x4C` resolves to `FUN_00429670` and is
EN/CH-identical. That gate calls the market's `+0x54` type accessor and then
requires every checked slot predicate to return true. Each predicate returns
true only when its stored figure is active, has model `0x17` (or the second
accepted model argument), and belongs to this market; an empty or stale slot
returns false. Therefore the gate itself is true only when all checked slots
are occupied, while a false result means at least one peddler slot is
available and spawning may proceed.

The slot predicates are the market vtable entries `+0x3C`, `+0x40`, and
`+0x44`. Type `2` evaluates `+0x3C` and `+0x40`; type `3` evaluates all three.
The first slot is stored at market `+0x2E`; the additional slots are stored in
the attached information object returned by `+0x1E8` (`market+0xC8`), at
`+0x6A` and (for type `3`) `+0x6C`. `FUN_00543ED0` registers a newly created
figure through vtable `+0x50` (`FUN_004272A0`), which fills those slots and
replaces a slot only when its previous figure is no longer active. The
`FUN_004295C0` predicate
documented in §10.17e reads the same slot set, so the spawn and per-update
membership checks are consistent.

The market `+0x54` method is the direct PE entry `0x543FF0`, which returns
`3` exactly when market building ID is `60` (Grand Market Square), and `2`
otherwise (including building ID `59`, Common Market Square). Therefore the
maximum simultaneous model-23 peddlers admitted by the recovered gate is:

| market building | `+0x54` type | live peddler slots |
| ---: | ---: | ---: |
| Common Market Square (`59`) | `2` | `2` |
| Grand Market Square (`60`) | `3` | `3` |

This is **confirmed** from `FUN_00429670`, `FUN_00429700`,
`FUN_00429780`, `FUN_00429810`, `FUN_004272A0`, `FUN_00543ED0`, the
`0x543FF0` bytes recorded in §10.17e, and the EN/CH vtable rows. The six
authored Grand Market shop bays are a separate shop-capacity concept and do
not justify six simultaneous peddlers. Native must use capacities `2/3`; the
remaining route, coverage, and market-quality writer contracts stay
independent unknowns.

#### 10.17g Peddler junction-visit selector (2026-08-30)

The shared crossing callback carries a model-specific visit-field selector;
it is not inferred from the figure's speed or range. `FUN_004EACD0` loads
the first dword of the model row at `DAT_0084E78C + figureModel * 0x28` and
passes it to `FUN_004B9460`, which saturates that selector's 3-bit field for
the current map cell (`figure+0x28`) to `7`.

Direct reads of the hash-matched EN/CH dispatch tables agree on the relevant
rows:

| figure model | role | row first dword passed to `FUN_004B9460` | effect |
| ---: | --- | ---: | --- |
| `23` (`0x17`) | peddler | `7` | updates packed visit selector `7` |
| `24` (`0x18`) | Marketplace buyer | `-1` | callback's `param_1 < 0` guard: no visit-field write |
| `25` (`0x19`) | Buyer's Servant | `-1` | no visit-field write |
| `28` (`0x1C`) | water carrier | `0` | updates packed visit selector `0` |
| `32…34` (`0x20…0x22`) | acrobat/actor/musician | `3` | updates packed visit selector `3` |
| `35` (`0x23`) | religious roamer | `5` | updates packed visit selector `5` |

The peddler row's value `7` and the buyer rows' `-1` are present in both
canonical tables at `0x84E78C + model * 0x28`; `FUN_004EACD0` and
`FUN_004B9460` are EN/CH `identical` in `compare-report.tsv`. This confirms
that peddlers maintain a dedicated junction-history lane, while buyers do
not perturb that lane even though buyer states 6/7 can reach the same market
writer callback.

This is a confirmed routing-state distinction and supplies the missing
`originalVisitFieldSelector = 7` fact for any future Native peddler bridge.
It does not identify the complete market writer or house-coverage semantics;
Native must still avoid enabling peddler delivery solely from this selector.

#### 10.17h Marketplace-buyer selector-8 movement cadence (2026-08-30)

The buyer's authored speed is not a direct road-tile count. `EmperorFigureModels.txt`
assigns model `24` speed field `i = 8`. The destination FSM `FUN_004D1810`
dispatches states `6/7` to `FUN_004E47A0` with selector `8`; the EN/CH
function bodies are identical in the split corpus. In `FUN_004E47A0`, the
stored fractional phase byte `figure+0x170` selects one substep for phases
`0/1`, then two substeps for phase `2` and resets it to `0`. Each substep
enters `FUN_004E7EB0`, which increments `figure+0x41`; at the `20`-substep
boundary it performs the shared crossing/collision update and advances one
route step. The figure constructor `FUN_004C72B0` zeros both phase/progress
bytes, so a newly spawned buyer begins at phase `0`, progress `0`.

Thus the recovered movement cadence is the repeating `1/1/2` substep pattern,
with one route-step crossing per `20` accumulated substeps. The peddler's
selector-8 handler uses the same cadence, but its route/collision/coverage
semantics remain independently unresolved. This section only closes the
buyer's movement clock; it does not claim that the Native route buffer or
destination pickup FSM is an exact implementation of the original.

This is **confirmed** from `EmperorFigureModels.txt` model `24`,
`FUN_004D1810`, `FUN_004E47A0`, `FUN_004E7EB0`, `FUN_004C72B0`, and the EN/CH
identical rows. Native may replace its former fixed `10` road-tile-per-day
buyer advance with this persisted selector-8 cadence while retaining the
existing fail-closed route/destination representation. The old explicit
`advanceBuyers(roadStepsPerBuyer:)` fixture API remains a compatibility path;
the city clock must use original figure updates rather than that approximation.

#### 10.17i Peddler selector-8 clock bridge (2026-08-30)

The peddler uses the same authored speed selector as the buyer, but its
spawn-time phase differs. `FUN_00543ED0` initializes the peddler through
`FUN_004E6A70`, which sets `figure+0x41` to `0x14` before the first
`FUN_004E3A80` think update. The peddler row `0x17` then calls
`FUN_004E6B70(..., 8)`; the selector-8 branch executes the recovered `1/1/2`
substep pattern and accounts budget in units of `8`. At each twentieth
substep the shared `FUN_004E7EB0` crossing path invokes `FUN_004EACD0` and
advances the current route state. The EN/CH bodies and authored model row are
identical for this portion of the path.

This closes the peddler's movement clock only: the route-heading, collision,
return-target, coverage writer, and market-quality writer remain the unknowns
listed in §§10.17a–10.18. Native may therefore replace its fixed ten-road-
points-per-day compatibility advance with a persisted selector-8 phase and
substep counter, while retaining its existing route/coverage fail-closed
boundary. The peddler's initial progress must be `20` (not the buyer's `0`),
so the first update reaches the crossing boundary as in `FUN_004E6A70`.

This is **confirmed** from `FUN_004E6A70`, `FUN_004E3A80`, `FUN_004E6B70`,
`FUN_004E7EB0`, `FUN_00543ED0`, and authored figure row `23`; it is not a
claim that the current Native path buffer is the original route.

### 10.18 Source-corpus audit of the remaining food-quality writer blocker (2026-08-30)

The remaining `cHouseInfo+0x36` writer question was re-audited against the
checked-in `local/source` corpus rather than inferred from the prior EN
opcode scan. `functions-index.csv` has no row for `0x5437B0` and neither
`decompiled-en.c` nor `decompiled-ch.c` contains a standalone
`FUN_005437B0` body. The split tree likewise has no file for that address.
The address and store remain valid as an earlier EN `.text` scan result
recorded in §10.5/§10.10. The direct PE comparison recorded in §3 confirms
that the recovered arithmetic body is byte-identical in the canonical EN and
CH files, but the corpus still cannot expose its callers, callee selection,
or an indexed CH function row.

A source-level cross-filter of every split function containing both a house
getter call (`vtable +0x1E4`) and an offset `0x36` access leaves only
`FUN_00518690`: it zeros `+0x36` when the Dinners stock word reaches zero and
writes `0x14` on the `DAT_00C5CDA0` debug/cheat branch. `FUN_00590F30` and
`FUN_00518490` only read the byte. `FUN_00518B70` writes its own parameter's
`+0x36` (`random % 0x28`) but has no `+0x1E4` house getter, so the corpus does
not establish that object as `cHouseInfo`; it remains an excluded candidate,
not a fourth confirmed house writer. `FUN_004EACD0` is also not a house-byte
store: it dispatches the market object's virtual `+0x28` callback and then
returns.

**Classification:** the four sites and market blend listed in §10.5 remain
`inferred`-complete from the EN opcode scan, while the source corpus provides
only the confirmed monthly writers and a negative result for any additional
direct getter-adjacent store. The complete writer set, market function body,
and CH-side market-store identity remain **unknown**. No Native food-quality
cadence or Qin-3 gate is enabled from this audit.

#### 10.18a Direct `+0x36` store census (2026-08-30)

To make the negative result reproducible, the canonical EN `.text` was
disassembled from the function boundaries in
`local/source/split-merged/functions-index.csv` and every instruction whose
destination is a non-stack base register plus displacement `0x36` was
recorded. The hash-matched files are
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
(EN) and `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`
(CH). The complete direct-store hit set is 47 instructions; the relevant
classes are:

| class | representative addresses / functions | why it is not a new `cHouseInfo+0x36` producer |
| --- | --- | --- |
| cHouseInfo copy | `0x426F67` in `FUN_00426EA0`, reached by `FUN_0051CAA0` | byte-for-byte record copy; it does not derive or produce quality |
| confirmed cHouseInfo writers | `0x518721`/`0x5187BF` in `FUN_00518690`; `0x515259` in the unsplit hero callback; `0x543A09` in the unsplit market callback | these are the getter-adjacent monthly, hero, and market-delivery stores already listed in §10.5 |
| HouseBldg/provider counters | `0x518C32` (`FUN_00518B70`), `0x51D003`/`0x51D01E` (`FUN_0051CF90`), `0x540BF6`/`0x540C7B` (`FUN_00540B40`), `0x543F5F`/`0x543F79` (`FUN_00543ED0`), `0x557C55`/`0x557C95` (provider update), `0x5F3303`/`0x5F34B0` and `0x5F37C8`/`0x5F37E1` | each writes the receiver's own `+0x36`; no call to a house `+0x1E4` getter precedes the store |
| figure/path state | `0x4990BE`, `0x4C364A`/`0x4C3666`, `0x4C7312`, `0x4C91C4`, `0x4CFB70`, `0x4E4036`, `0x4E46D4`, `0x4E8E79`, `0x52F78B`, `0x54C432`, `0x54C547`, `0x54F82E`, `0x55133C`, `0x56D74D`, `0x56EB39`/`0x56EC28`/`0x56EC8A`, `0x57138F`/`0x5713FB`, `0x59BCEF`, `0x5C0357`, `0x5EA91B`, `0x5F3F8B` | receiver is a figure, route, or unrelated object; stores are words/bytes in that object's own layout |

The only unsplit hit that is both a quality-byte store and immediately
follows a house getter call is `0x543A09` inside the direct PE body beginning
at `0x5437B0`; its EN/CH byte identity and missing corpus row are already
recorded in §10.10. `FUN_00518B70` remains an important exclusion: its
`random % 0x28` write is to the **HouseBldg receiver's** `+0x36`, not the
`cHouseInfo` subobject returned by `+0x1E4`. This census is therefore a
`confirmed` negative search for additional *direct getter-adjacent* writers,
not proof that an indirect or data-driven writer cannot exist. The market
delivery cadence, indirect writer possibility, and Native representation
remain unsupported exactly as stated in §10.18.

#### 10.18b Follow-up: indexed `+0x36` false positives are not cHouseInfo writers (2026-09-04)

The indexed corpus was rechecked for additional offset-only `+0x36` stores that can
look like food-quality producers when searched by offset alone. `FUN_0054C370
@ 0x54C370` walks the fixed `DAT_011A2BBC` table in `0xB4`-byte records and
writes `DAT_010C72AC` into each record's `+0x36` word while also initializing
its coordinate, figure-handle, and UI-marker fields. Its receiver is the
event/marker record selected by `FUN_0047F1B0`, not the `cHouseInfo` pointer
returned by a house vtable `+0x1E4` callback. `FUN_0048CE90 @ 0x48CE90`
similarly clears its own figure/object `+0x36` before spawning model `0x25`,
and `FUN_004E4600 @ 0x4E4600` copies a figure/object record's `+0x36` during a
relocation path. `FUN_005F3DD0 @ 0x5F3DD0` writes the same offset on a newly
spawned figure returned through its own vtable `+0x1E8` path. None of these
functions calls the house `+0x1E4` getter.

This leaves the source-level getter-adjacent set unchanged: only
`FUN_00518690` is indexed in `local/source` with both a house getter and a
`+0x36` write. The hero store at `0x515259` and market-delivery store at
`0x543A09` remain the two unsplit PE-only getter-adjacent sites documented in
§10.5/§10.18a. The new exclusions are **confirmed negative** evidence against
promoting those offset-only hits to a fourth or fifth residential quality
writer; they do not close the unsplit market body or the possibility of an
indirect/data-driven writer.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0054c370.c`,
`FUN_005f3dd0.c`, `local/source/split-merged/code/0x040000/FUN_004e4600.c`,
`FUN_0048ce90.c`, `FUN_004c72b0.c`, and the complete direct-store census in
§10.18a. Indexed EN/CH comparison rows are `identical` where those functions
are present.

#### 10.18c EN/CH market quality callback body is byte-identical (2026-09-04)

The unsplit market-delivery callback that writes the residential quality byte
is no longer an English-only observation.  The canonical EN and CH PE images
were read directly (image base `0x400000`) and compared over the complete
`0x5437B0…0x543BBB` body, including the return epilogue.  Both slices are
`1,036` bytes with SHA-256
`2cb8269ba719358e4ced7ec873ed2d2e4e0d51715afa64c51a91cb2633b8b1d2`; the
function's cMarket vtable word at `0x7B6F3C + 0x2C` is `0x005437B0` in both
images.  The quality store instruction at `0x543A09` is the same three-byte
sequence `88 58 36` (`mov byte ptr [eax+0x36], bl`) in both variants.

This closes the CH-side identity question for the recovered market callback:
the cMarket `+0x2C` route, all branch constants and arithmetic, and the final
`cHouseInfo+0x36` write are the same byte-level implementation as EN.  It does
not add a new producer or prove that the callback is reached by a Qin map
without the unresolved cMarket/provider registry, route, and settlement
projection.  The complete writer set and the source of the callback's `bl`
quality value therefore remain unknown, and Native remains fail-closed.

**Sources:** canonical EN
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and CH
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`) PE
hashes from `DESIGN.md`; direct PE reads of
`0x5437B0…0x543BBB` and cMarket vtable `0x7B6F3C + 0x2C`; the EN market-store
body and caller analysis in §§10.5, 10.10, 10.18a, and 10.18b; and the
`local/source/compare-report.tsv` rows for the surrounding indexed callers.

**Evidence class:** **confirmed** for EN/CH vtable target, complete callback
byte identity, exact body hash, and the `0x543A09` store; **unknown** for
callback reachability in Qin, indirect/data-driven writers, quality-source
mapping, provider registry, route, and household settlement.

#### 10.18d cMarket quality callback has one PE-visible vtable edge (2026-09-04)

As a second call-edge check, every aligned dword in the canonical `.rdata`
sections was scanned for the callback address `0x005437B0`.  EN and CH each
contain exactly one matching word, at `0x007B6F68`, which is
`0x007B6F3C + 0x2C`; no other `.rdata` word points at the quality callback.
An exhaustive direct-relative `E8` scan of both `.text` sections likewise
finds no direct call to `0x005437B0`, consistent with the callback being
reached through cMarket's virtual slot rather than a direct helper call.

The result narrows the PE-visible consumer edge to the cMarket vtable family:
there is no second direct or vtable alias that could be promoted to an
independent residential quality producer.  It still cannot identify the
runtime object that owns the cMarket instance in Qin, the producer of `bl`, or
any indirect/table dispatch outside the aligned `.rdata` and direct-`E8`
searches.  Native therefore keeps market quality and Qin settlement
fail-closed.

**Sources:** canonical EN/CH PE hashes above; aligned `.rdata` dword scan,
direct-relative `E8` scan, and vtable word at `0x007B6F68`; the byte-identical
callback body in §10.18c; and the cMarket vtable mapping in
`docs/exe-research/residential-service-roamer-lifecycle.md`.

**Evidence class:** **confirmed** for the unique PE-visible vtable pointer and
absence of direct relative callers; **unknown** for indirect dispatch,
runtime cMarket ownership, quality-source mapping, provider registry, route,
and household settlement.

### 10.19 Native food-draw correction (2026-08-30)

The closed monthly-consumption contract is now wired in
`Sources/EmperorCore/MarketSimulation.swift`: household Dinners demand is
`floor(residents × 25 / 100)`, matching `FUN_00518690 → FUN_00408B80`
(`FUN_00503E20` returns `0x19`). The integer truncation occurs before the
save-backed food-stock subtraction, and the existing quality/shortage logic
continues to run on that consumed amount. This is a supported arithmetic
correction only; it does not enable the unresolved market writer, peddler
route, water `+0x224` branch, or Qin-3 playthrough gate.

`testMillFoodBuyerAndPeddlerPreservePlainFoodQuality` now asserts the
22-resident fixture consumes `5` units at settlement (rather than `22`), and
the full `EmperorCoreTests` suite passes with this change.

### 10.20 Native raw food-byte preservation (2026-08-30)

The house-quality representation now keeps the recovered raw byte end to end
through the Native market-delivery boundary. `ResidentialUnit` retains the
existing `FoodQuality` overload for authored display bands, but its new
`addFoodSupply(amount:qualityRawValue:)` overload clamps only to the stored
byte domain `0…255` and applies the confirmed better-value replacement and
five-ratio integer blend without converting through the enum. The peddler
delivery path passes `MarketPeddler.foodQualityRawValue` directly, so an
intermediate value such as `45` is no longer converted to `.none` before the
blend.

This is a representation correction, not a claim that the market writer or
raw-value producer is fully recovered. The complete `cHouseInfo+0x36` writer
set, `cMarket+0x180` source mapping, and player-facing band selection remain
the unresolved blockers in §10.18. The focused regression
`testHouseFoodDeliveryPreservesRecoveredRawQualityBytes` proves a `70`/`45`
delivery blends to raw `63` and that a later raw `80` delivery replaces it;
the existing mill/peddler test and the full `EmperorCoreTests` suite remain
green.

`DeterministicHousingEvolution.requirementsMissing` now compares
`lastSuppliedFoodQualityRawValue` directly as well. This preserves an
intermediate saved byte such as `63` when evaluating a target requirement of
`50`; converting through the authored `FoodQuality` enum would incorrectly
collapse that value to `.none`. This is a representation fix only and does
not introduce a new original snapshot contract.

### 10.21 Native market peddler spawn scheduler bridge (2026-08-30)

The market peddler spawn gate is now represented at the same scheduler phase
as the recovered provider lifecycle. `FUN_00543ED0 @ 0x543ED0` is present in
`local/source/split-merged/functions-index.csv` and is `identical` in the EN/CH
row of `compare-report.tsv`. The peddler-specific body first rejects a
provider with no workers, checks the model-23 slot and `+0x268` availability
gates, computes the assigned-worker percentage from `FUN_00544A80(-1)` /
`FUN_00544A40`, increments the market counter byte `+0x36`, and creates a
figure only when the incremented byte is strictly greater than its
threshold; the counter is reset before the allocation attempt. The confirmed
peddler thresholds are `2/3/4/5/10` for worker percentages
`100+ / 75…99 / 50…74 / 25…49 / 1…24`; zero workers return before the table.

The provider `+0x20` call is issued by the original scheduler at phase
`0x1F`, once per 51 inner simulation steps (`0x4AC2B0`), not once per map
movement step. Native therefore persists a market scheduler phase and one
spawn counter per market, advances the phase through the existing 816-step
monthly bridge, and evaluates at most one peddler opportunity per market at
phase `0x1F`. Existing direct `schedulePeddlers` calls remain a compatibility
fixture API; the city path uses the phase-gated method. The `+0x268`
availability predicate is now closed as a provider-record quantity sum (see
§10.22), but its provider-to-Native-inventory mapping, selected road-origin
semantics, and downstream route/provider side effects remain unresolved. This
bridge therefore claims only the confirmed positive-worker gate, peddler
threshold, strict counter transition, phase timing, and the static `+0x268`
predicate; it does not claim complete `FUN_00543ED0` allocation or peddler
route equivalence.

Evidence class: **confirmed** for the gate, thresholds, phase timing, the
zero initialization, and the post-allocation rotation write; **unknown** for
requested-model selection, complete consumption of the rotation byte, and
route / coverage / market-quality writers.

The successful allocation tail also writes the market's direction byte
`+0x38` as `(old + 4) & 7` and copies that value to the new figure's `+0x1A`
before entering `FUN_004E6A70`. The market constructor chain
`FUN_00543450 → FUN_005D46A0 → FUN_0051C9A0 → FUN_00426E60` clears the base
building storage, including `+0x38`, before the first allocation. This write
is reached only when
`FUN_004EA050(..., model 0x17, ...)` returns a live figure; threshold crossing
or route-coordinate selection alone does not advance it. `FUN_00543160`,
reached through `FUN_00544910`, selects coordinates from an authored
four-way table, but the table's meaning and the subsequent route consumer are
not recovered. Native therefore persists the confirmed `+4 & 7` transition
on successful gated allocations without using it as a guessed route origin.

### 10.22 cMarket `+0x268` availability predicate (2026-08-30)

The previously open availability gate in the model-23 provider wrapper is
now closed at the executable-control-flow level. `FUN_00543E40 @ 0x543E40`
is a one-instruction dispatch to the cMarket virtual slot `+0x268`; the
canonical cMarket vtable is `0x7B6F3C`, so this slot targets
`FUN_005D4AC0 @ 0x5D4AC0`. `FUN_00543ED0` calls that wrapper immediately
after its model-23 slot check and before incrementing `cMarket+0x36` or
attempting `FUN_004EA050`. The EN/CH row for `0x5D4AC0` is `identical` in
`local/source/compare-report.tsv`, and the function is present in
`local/source/split-merged/functions-index.csv` and its split source file.

`FUN_005D4AC0` performs the following confirmed walk:

1. Call cMarket virtual `+0x2CC` (`FUN_00546BE0`). If the market's provider
   container at `market+0x150` is null, that method returns zero; otherwise it
   calls the container's first virtual method and returns its record count.
2. Call cMarket virtual `+0x2D8` (`FUN_00546C40`) with index `0`. The method
   returns `market+0x154`, the first record in a contiguous 16-byte (`0x10`)
   provider-record array; later records are reached by the loop's implicit
   `+0x10` stride.
3. For each record, call `FUN_004B04F0`. Its source-level predicate is
   `record+4 == 0 && record+8 == 0`; only records failing that empty test are
   counted. For every non-empty record, call `FUN_004F8200`, which returns
   `record+8`, and add that value to the running integer sum.
4. Return the un-clamped sum. Thus the gate is false for a null/empty provider
   list or a zero sum, and true for a positive sum; it does not inspect the
   model-23 figure, worker percentage, direction byte, or road coordinates.

The sibling cMarket slot `+0x264` (`FUN_005D4A60`, also EN/CH `identical`)
confirms the record interpretation: it uses the same count/pointer walk,
matches `record+4` against its item argument via `FUN_004B04D0`, and sums
`record+8` for matching records. This is strong evidence that `+0x268` is a
provider-quantity availability total rather than a separate route or quality
test.

The cMarket constructor supplies the storage provenance. In
`FUN_00543450 @ 0x543450`, `FUN_00543600` constructs the provider-container
object stored at `market+0x150`. The constructor then calls that container's
first virtual method for the record count, allocates `count * 0x10 + 4` bytes,
stores the count in the four-byte header, and exposes the first record at
`market+0x154` (`header + 4`). This closes the allocation/header/stride
relationship independently of the availability caller. The record initializer
callback (`FUN_00543680`) and the container's concrete first virtual method are
not emitted as standalone split functions, so the initial field values remain a
constructor concern. The later shop-placement writer that populates `record+4`
is recovered in §10.64. The cStall cart-deposit path also writes `record+8`
through `FUN_005D2790` (§10.63); other monthly/external provider quantity
sources remain unknown.

Evidence class: **confirmed** for the slot target, caller order, null-provider
behavior, 16-byte record stride, empty predicate, quantity field `+0x8`, and
the un-clamped summation. The provider container's concrete type and the
mapping from its `record+4/+8` fields to Native `inventoryByCommodityID` (or
to the food-shop bundle) remain **unknown**. Native therefore does not yet
replace the gate with an inventory-derived shortcut and does not advance the
peddler spawn counter on the strength of this predicate alone; doing so would
silently assert an unverified provider-to-inventory mapping. The remaining
Qin blockers are the selected model-23 allocation record, coordinate/route
consumer, coverage writer, and market-quality writer.

##### Native raw-record primitive (2026-08-30)

The confirmed record-level operation is now represented by
`OriginalMarketProviderRecord` and
`OriginalMarketProviderAvailability.total` in
`Sources/EmperorCore/MarketSimulation.swift`. The helper preserves the
executable's exact empty-record test (`rawField4 == 0 && rawField8 == 0`) and
sums `rawField8` for every non-empty record. It is intentionally side-effect
free and does not map either raw field to Native commodity inventory; the
model-23 gate and Qin-3 settlement remain fail-closed until that mapping and
the downstream coverage/quality writers are recovered.

##### Peddler crossing scan uses the recovered radius-two object walk (2026-08-30)

`FUN_004EACD0` invokes the home market object's `+0x28` callback, which
resolves to `FUN_00429DF0` and the two-ring `FUN_00429E10` object scan. Native's
original-timing peddler path now passes each route-crossing point through that
same `OriginalResidentialServiceCoverage.houseIndices` scan (including the
confirmed sixteen-sector wall/gate occlusion) before applying the market
commodity/stock predicates. Native retains its occupied-house delivery guard;
the original writer's separate empty-elite branch remains outside this bridge.
The compatibility route itself, the provider
selection record, and the complete market writer/quality cadence remain
unsupported; this change only removes the former orthogonal-neighbor shortcut
from the confirmed crossing geometry.

##### Market house callback demand/capacity outputs (2026-08-30)

The house object passed to `cMarket+0x2c` uses the `0x7ABA38` vtable in the
canonical residential class. Its `+0x228` entry is the unsplit EN/CH body at
`0x51A3A0` (no standalone `functions-index.csv` row). The method takes two
output pointers and returns `ret 8`; the call site at `0x543808` pushes the
first local pointer and then the second, so the callee's `[esp+4]` points to
the **second** local and `[esp+8]` to the **first**. Direct bytes in both
executables therefore establish this output contract:

The `0x51A370…0x51A3E6` method range is byte-identical in the canonical EN
and CH PE inputs (119 bytes, SHA-256
`d37bf5d8ba0e700a5656c3a95cf3db640619d68fceddb137145d07ce017c188b`); the
only indexed comparison row in this neighborhood is the separate
`0x51A330` helper. The callback's `+0x21c` call is the residential vtable
entry `0x518DA0`, which returns `house+0xDA` only when the house class byte at
`+9` is non-zero (otherwise zero). Its complete semantic name and Native
field mapping are still unknown, so this note calls it the **current-stock
input** only at the callback arithmetic boundary.

| house residents | first local (`[esp+0x10]`) | second local (`[esp+0x20]`) |
| ---: | ---: | ---: |
| `0` | `10` | `5` |
| `>0` | `residents × 2` | `max(1, residents / 2)` (signed integer division) |

The market callback treats the first local as the target Dinners stock and
the second as a per-callback delivery cap: after `house+0x21c` supplies the
current stock, it computes `target - current`, clamps that value to the
second local, then clamps again to the market's Dinners stock. This is a
confirmed callback-level quantity contract; the `+0x21c` field identity,
provider-record demand source, and route/coverage/quality writers remain
unknown. Empty-house delivery is additionally gated to elite model IDs by the
surrounding `0x5437B0` branch, so Native's occupied-house bridge does not
enable that case.

The pure Native helper `OriginalMarketFoodDeliveryDemand` records these two
outputs and the resulting non-negative request without claiming a Native
inventory representation. The original-timing peddler bridge applies only
the confirmed per-callback cap; the older direct `advancePeddlers` fixture API
is intentionally unchanged. This narrows over-delivery without asserting the
unresolved provider selection or route semantics.

##### `+0x21C` current-stock input remains an open writer boundary (2026-08-30)

The residential vtable `+0x21C` entry is `0x518DA0`. Its complete body is
indexed as `FUN_00518DA0` and returns zero when the receiver's class byte
`+9` is zero; otherwise it returns the signed word at receiver offset
`+0xDA`. A corpus-wide search of the split EN/CH tree for direct writes to a
receiver displacement `+0xDA` found no house-field writer. The remaining
literal `0xDA` hits are unrelated model IDs, event IDs, or serializer field
tags; the only direct PE load is `movsx word [ecx+0xDA]` at `0x518DA7`.

This is a **confirmed negative search**, not proof that an indirect,
table-indexed, or external-buffer writer cannot exist. The callback therefore
has a confirmed target-minus-current arithmetic boundary but no confirmed
producer for its current-stock word. Native must not equate `house+0xDA` with
`ResidentialUnit.foodSupplyAmount`, nor enable market settlement from this
getter alone; provider-record demand, stock lifecycle, and route/coverage
writers remain unknown.

##### Resource-route candidate selector boundary (2026-08-30)

The indexed route helpers `FUN_004E2960` and `FUN_004E3840` are the direct
callers of `FUN_005D2C70`/`FUN_005D2F60`/`FUN_005D31A0` (all EN/CH
`identical` in `compare-report.tsv`). Their fallback order is now explicit:
the mode-0 `FUN_005D2C70` candidate scan runs first, followed by a
`FUN_0042B6B0`/`FUN_00506CD0` path, then `FUN_005D2F60` with modes `2` and
`0`, then `FUN_005D31A0`, and finally a mode-1 `FUN_005D2C70` retry. The
selected result is stored in the caller's object field `+0x68`; a zero result
reaches the resource-index cleanup path.

Within `FUN_005D2C70`, the requested owner ID is resolved through
`FUN_0047F1B0`, and its object byte `+0x13` must be one of resource indices
`1…9`; the global `FUN_005DB4C0` gate and `FUN_005D2B90` state gate must pass.
The provider-list scan keeps only live providers with positive worker value,
accepted resource capacity, and a matching provider-owner result from vtable
`+0x1A8`. It records provider `+0x2D` and either the provider's `+0x1A4`
result or the map-cache coordinate `(DAT_010C72AC,
DAT_010C72A8, DAT_0101D0C8)`, then forwards the candidate arrays through
`FUN_004E7FD0` and resolves the selected provider's coordinates. These are
confirmed filter/ordering facts, not a semantic name for the resource or a
claim that the result is the model-23 peddler route.

The candidate arrays' owner/resource meaning, the route-mode policy inside
`FUN_004E7FD0`, and the relationship (if any) to cMarket provider records
remain unknown. No Native route or inventory mapping is enabled from this
selector; it only narrows the static search boundary for the remaining Qin
market blocker.

### 10.23 Model-23 spawn coordinate table (2026-08-30)

The coordinate selector behind model-23 allocation is now closed as a table
computation, while its downstream route consumer remains open. The static
entry point is `FUN_00544910 @ 0x544910` in
`local/source/split-merged/code/0x050000/FUN_00544910.c`; it tail-calls
`FUN_00543160 @ 0x543160`. `FUN_00543ED0 @ 0x543ED0` calls this selector
immediately before `FUN_004EA050(..., model 0x17, ...)` and passes the two
globals written by the selector as the new figure coordinates. The EN/CH
rows for all three functions are `identical` in
`local/source/compare-report.tsv`.

`FUN_00543160` receives the helper at `cMarket+0x158`, not the cMarket
object itself. Its constructor chain is visible in the split corpus:
`FUN_00543450 @ 0x543450` selects `FUN_00546C80` (vtable `0x7AB800`) for
building ID `59` and `FUN_00546CA0` (vtable `0x7AB878`) for ID `60`;
`FUN_00541EB0 @ 0x541EB0` stores helper fields `[1]=x`, `[2]=y`, and
`[3]=DAT_008C7628`. The grand-market constructor normalizes
`DAT_008C7628` to `0…1`. The helper vtable methods return these counts and
table bases:

| helper vtable | building | count (`+0x04`) | table VA (`+0x24`) | bank stride |
| --- | ---: | ---: | ---: | ---: |
| `0x7AB800` | Common Market Square (`59`) | `28` | `0x8574A8` | `0x1C0` (`28×0x10`) |
| `0x7AB878` | Grand Market Square (`60`) | `42` | `0x857828` | `0x2A0` (`42×0x10`) |

The direct bytes were checked in both repository PE inputs (EN hash
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, CH
hash `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`).
Each record is four little-endian dwords `(dx, dy, kind, aux)`:

* Common table bank `0` (`0x8574A8`) is a `4×7` grid; bank `1`
  (`0x857668`) is the transposed `7×4` grid. `kind=1` occupies records
  `12…15` (the `dy=3` row) in both banks.
* Grand table bank `0` (`0x857828`) is a `6×7` grid; bank `1`
  (`0x857AC8`) is the transposed `7×6` grid. `kind=1` occupies records
  `18…23` (the `dy=3` row) in both banks. The grand table's `kind=4` and
  `kind=1` rows carry authored auxiliary values `100…135` (bank `0`)
  and `100…129` (bank `1`); these are not route headings.

The selector starts at record index `3`, scans forward, and decrements its
three-bit direction counter only when `record.kind == 1`; when that counter
is already zero it stops on the current record. Consequently all four
market banks select `(dx,dy) == (3,3)` (common record `15`, grand record
`21`) and write:

```
DAT_010C72AC = helper[1] + 3
DAT_010C72A8 = helper[2] + 3
```

This `(3,3)` result is **confirmed** as the executable's selector output and
is independent of the two orientation banks. The cMarket placement/update
bridge also exposes the coordinate provenance: cMarket vtable slot `+0x100`
targets `FUN_005451A0 @ 0x5451A0`, whose `param6 == 0` path calls
`FUN_005428B0 @ 0x5428B0`; that path copies cMarket `+0x0A/+0x0C` into helper
`[1]/[2]` before consuming the helper table. This proves the helper can be
anchored to the market object's map coordinate, rather than a hard-coded
road tile. The static corpus does not, however, prove that this setup call
precedes every provider tick or that the helper's selected point is the
Native `MarketSquare.roadAccessPoint`.

The separate `+0x70` helper method used by `FUN_00543E70`, the
route-buffer/collision consumer after `FUN_004EA050`, and the provider-record
writer remain **unknown**. Native therefore records the proven selector and
coordinate-copy contract here without rewriting peddler routes or
substituting the road-access point as a guessed spawn origin.

The record-level result is represented by the pure
`OriginalMarketPeddlerSpawnSelector` helper in
`Sources/EmperorCore/MarketSimulation.swift`. It returns common-market record
`15` or grand-market record `21`, with offset `(3,3)`, for either orientation
bank and can anchor that offset to the copied market origin. The focused
`EmperorCoreTests.testOriginalMarketPeddlerSpawnSelectorUsesRecoveredThreeThreeRecord`
regression covers all four banks plus out-of-domain inputs. This helper is a
research primitive only: it is not used to replace Native route origins or to
enable market-peddler coverage.

### 10.24 cMarket helper coordinate copy and model-23 handoff (2026-08-30)

The helper/base relationship is independently visible in the executable
control flow. `FUN_005451A0 @ 0x5451A0` is the cMarket vtable slot `+0x100`.
It forwards `(param6, param3, param4)` to `FUN_00544220`, which forwards to
`FUN_005428B0` with the market's helper at `cMarket+0x158`. In the
`param6 == 0` branch, `FUN_005428B0` reads the cMarket object's short fields
at `+0x0A` and `+0x0C`, writes them to helper `[1]` and `[2]`, and copies the
orientation byte from the market's `+0x1E8` data (`[3]`). It then walks the
helper record table and clamps the resulting map coordinates to the map
bounds. In the nonzero branch it instead accepts an explicit origin and
orientation, which is why the helper layout is shared by placement and
object-update paths.

After a successful model-23 allocation, `FUN_004E6A70 @ 0x4E6A70` calls
`FUN_004E6690` up to four times. For cMarket figures (`model 59…60`), the
successful branch calls `FUN_00544910` again, which writes the selector
coordinates (`helper[1]+3`, `helper[2]+3`) into the figure's `+0x2C/+0x2E`
target fields. The model-23 constructor had already received those same
selector globals as its initial `+0x1C/+0x1E` coordinates. This closes the
static handoff from market coordinates to the figure's initial/target point.

Evidence class: **confirmed** for the `+0x100 → +0x5428B0` copy path, the
market-coordinate fields used, map-bound clamping, and the model-23 initial
and target-field writes. The invocation order relative to all save/load
paths, the later route-buffer/collision state machine, and provider-record
population remain **unknown**. No Native route change is justified until
those consumers are recovered.

### 10.25 Model-23 route-buffer construction and consumption boundary (2026-08-30)

The route builder used by the peddler is now closed through its byte-buffer
boundary, but the market coverage/writer side is still not. `FUN_004E83E0 @
0x4E83E0` clears the figure route slot (`+0x42`), route index (`+0x44`), and
route length (`+0x46`) before dispatching on the figure route mode at `+0x80`.
The peddler wrapper recovered at `0x4D0270` writes mode `0x12`; the
mode-`0x12` case calls `FUN_005B00D0(currentX,currentY,targetX,targetY,0)` and
marks the result as a non-fallback route. On success it first calls
`FUN_005B18B0(4,slot,current,target)`; only when that returns zero does it
retry `FUN_005B18B0(8,slot,target,current)` with the endpoints reversed.

`FUN_005B00D0 @ 0x5B00D0` is a breadth-first fill over the map-index array
`DAT_01391FE0`, whose row stride is `0xE4` cells. It seeds the current cell
with distance `1`, then uses `FUN_005B0220 @ 0x5B0220` for mode `0`. That
neighbor writer enqueues exactly the four cardinal offsets from
`DAT_0085DE64`: `-0xE4`, `+1`, `+0xE4`, `-1`, provided the corresponding
terrain/cache word has the `0x10C` passability mask. The target is reachable
when its distance entry is nonzero; no diagonal edge is added by this BFS.

`FUN_005B18B0 @ 0x5B18B0` reconstructs from the target distance entry toward
the source. For the first call's `param_1 == 4`, `n3 == 2`, so it scans the
cardinal direction slots in `DAT_0085DE64` in table order (0, 2, 4, 6),
choosing a strictly lower distance. Equal-distance candidates use the
heading from `FUN_005B2730` and the deterministic RNG state advanced by
`FUN_004189B0`; this is a tie-break, not a change to the four-way BFS graph.
Each chosen direction is written as the reverse heading `(direction + 4)
mod 8` into the temporary `DAT_013F7C48` buffer. At the distance-`<2`
boundary, the bytes are copied in reverse order to
`DAT_010345C0 + slot * 500`; the maximum serialized route length is `500`
bytes. The fallback call with `param_1 == 8` scans all eight offsets and uses
the same reverse-byte representation.

`FUN_004E8B40 @ 0x4E8B40` consumes that buffer only while `+0x42 > 0`: it
reads byte `DAT_010345C0 + (+0x42 * 500) + +0x44` as the next heading and
clears the route through `FUN_004E8A30` once `+0x44 >= +0x46`. When no route
slot exists it computes a direct heading with `FUN_005B2730`; an equal source
and target produces heading `8`, then the caller changes it to movement state
`10`. `FUN_004E7EB0` invokes this builder/consumer pair before collision and
again at each twentieth substep. A blocked step is then reported by
`FUN_004E8BC0` as direction `9`; `FUN_004E71D0` performs the separate retry /
clockwise-counter-clockwise turn search. These route and collision functions
are identical in the EN and CH variants (no rows for these addresses appear
in `local/source/compare-report.tsv`). The executable inputs are EN SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
SHA-256 `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
No `GameData` or manual row defines this internal route buffer, and no
original runtime was launched for this static-corpus pass.

This closes the original route-buffer format, the peddler mode-`0x12`
four-way BFS, cardinal direction table, 500-byte cap, direct-heading fallback,
and the exact consumer fields. It does **not** prove that Native's
`MarketPeddler.route` should target a house, nor does it identify the map
cache-to-`RoadNetwork` projection, the cMarket coverage writer, or the
provider-record quantity/quality mapping. Evidence class: **confirmed** for
the control flow, offsets, masks, table bytes, route serialization, and
EN/CH identity; **unknown** for the semantic destination supplied to model
23 during roaming, cache projection, collision retry side effects, and the
market writer. Native therefore remains fail-closed for a new peddler route
implementation; replacing the current household-delivery approximation
would require those remaining contracts rather than this route-buffer fact
alone.

### 10.26 cMarket `+0x298` provider-consumption reducer (2026-08-30)

The inventory-debit slot reached by the normal market-delivery writer is now
closed at the record-reducer boundary. The canonical cMarket vtable is
`0x7B6F3C`; its `+0x298` entry targets `FUN_005D50C0 @ 0x5D50C0`. The EN/CH
comparison row is `identical` (`0x5d50c0`), and the split source is
`local/source/split-merged/code/0x050000/FUN_005d50c0.c`. The market writer
`0x5437B0` invokes this slot after selecting commodity `0x1c` (Dinners), while
the independent canal-carrier path also invokes provider `+0x298` and records
the same return convention in `docs/exe-research/grand-canal-map-state.md`.

For a positive requested amount `R`, `FUN_005D50C0` performs this exact loop:

1. Read the provider-record count through cMarket `+0x2CC`, then reset the
   enumeration cursor with `+0x2D8(0)`. A zero/null provider container returns
   `R` unchanged.
2. Enumerate records in container order. `FUN_004B04F0` rejects a record only
   when both `record+4` and `record+8` are zero; `FUN_004B04D0` then keeps only
   records whose `record+4` equals the requested commodity. Among matching
   records with non-zero `record+8` below the initial `10000` sentinel, choose
   the one with the smallest quantity. Normal provider quantities are
   non-negative; the literal executable guard is `record+8 != 0 && < 10000`.
   Ties are not replaced because the comparison is strict `<`.
3. Select that record with `+0x2D8(index)`, read its quantity from `record+8`,
   and consume `min(R, quantity)`. The selected record's quantity is reduced
   by `FUN_005D2760`; that helper clamps at zero and, when its clear flag is
   nonzero, clears `record+4` when the quantity reaches zero.
4. The market-specific `+0x288(commodity, consumed)` callback is invoked for
   the consumed amount. The cMarket/building-ID predicate
   `FUN_005D61C0` gates that callback and the post-consumption `+0x2A0(index,1)`
   callback: it is true only for building IDs `54`, `56`, `58`, and false for
   other building IDs. The reducer itself still mutates the selected record
   regardless of that gate.
5. If `R` exceeds the selected quantity, repeat the scan against the next
   smallest matching non-zero record. Otherwise return zero. If no candidate
   remains, return the unfulfilled positive remainder. The return value is
   therefore **not** the amount consumed; it is the request remainder.

The helper identities are independently confirmed: `FUN_004F8200` returns
`record+8`; `FUN_005D2760` subtracts from `record+8`, clamps, and optionally
zeros `record+4`; and `FUN_005D61C0` accepts exactly `54`, `56`, or `58`.
`FUN_005D2790` (the sibling add/clamp helper) is EN/CH-identical but is not
called by `FUN_005D50C0`. The reducer's direct consumers include
`0x5437B0` (normal market house delivery) and the recovered canal material
carrier path; no direct `E8` caller for `0x5D50C0` is emitted because the
dispatch is virtual.

Evidence class: **confirmed** for the vtable slot, EN/CH identity, provider
record fields, strict minimum selection under the non-zero/`10000` guard,
split-consumption loop,
zero/clamp behavior, callback gates, and unfulfilled-remainder return. It
remains **unknown** which concrete provider-container writer populates
`record+4/+8`, whether cMarket `+0x288` has additional side effects beyond its
building-specific callback, and how the Dinners records map to Native's
`inventoryByCommodityID` / food-shop bundle. This closes the debit/remainder
contract but does not close peddler coverage, route destination semantics, or
market-quality production. Native must not substitute a direct inventory
decrement or enable model-23 coverage on this evidence alone.

##### Native raw-record reducer (2026-08-30)

The side-effect-free record mutation is now represented by
`OriginalMarketProviderConsumption.reduce` in
`Sources/EmperorCore/MarketSimulation.swift`. It preserves the strict
smallest-quantity scan, first-record tie behavior, repeated partial
consumption, the `FUN_005D2760` zero clamp, the caller-supplied clear flag for
`record+4`, and the unfulfilled remainder. The focused regression
`EmperorCoreTests.testOriginalMarketProviderConsumptionUsesStrictMinimumAndReturnsRemainder`
covers both a fully satisfied request and a multi-record remainder. No
cMarket callback or Native inventory mapping is attached to this helper, so
the Qin-3 market gate remains fail-closed.

##### Native raw-record stocking helper (2026-08-30)

`FUN_005D2690 @ 0x5D2690` initializes each 16-byte provider record's raw
fields `+4` and `+8` to zero and stores its supplied capacity at `+0xC`.
The cMarket constructor's `LAB_00543680` passes `0x190` (400) for that
capacity. `FUN_005D2790 @ 0x5D2790` then unconditionally writes `+4`, adds to
`+8`, clips only above `+0xC`, and returns the overflow; it does not clamp a
negative result upward. This is now represented by the pure
`OriginalMarketProviderStocking.add` helper and tested by
`EmperorCoreTests.testOriginalMarketProviderStockingWritesCommodityAndClipsAtRecordCapacity`.

The provider-record population callback and the mapping from its raw `+4`
field to authored commodities remain unknown, so this helper is not wired to
Native inventory or the Qin-3 settlement path.

### 10.27 cMarket `+0x284/+0x288` callbacks are global accumulators (2026-08-30)

The two cMarket virtual callbacks adjacent to the recovered record reducer
were checked directly in both hash-matched PEs. On the canonical cMarket
vtable `0x7B6F3C`, slot `+0x284` points to `0x5D5080` and slot `+0x288` points
to `0x5D50A0`; the 18-byte bodies are EN/CH-identical (SHA-256
`d5c6c0b4482bb46f0b3e75ac02011d5244893ddf70774de93217ac7974c4df75` and
`1428012642045f7dfdc3c11a5ed9844c0d4f4bc422768d2bff6ba36fe5835781`). Each
accepts `(index, amount)`, adds or subtracts `amount` from the global table
`DAT_013126EC[index]`, and returns with `ret 8`; neither body reads or writes
the 16-byte provider record.

The direct PE body of `FUN_005D4E80 @ 0x5D4E80` confirms the ordering on its
record-update path: after selecting a record, it calls cMarket `+0x284` with
the requested index and `1`, then calls `FUN_005D2790(record, index, 1)` to
write the record field and add quantity. The same function is present in the
six recovered vtable tables containing the `0x5D4E80` entry; all relevant
EN/CH bytes are identical (`compare-report.tsv` row `0x5d4e80`). This rules
out treating `+0x284` as the provider-record commodity writer. The global
table's initialization, index domain, and mapping to authored commodities
remain **unknown**, so no Native inventory or Qin-3 settlement path is
enabled from these callbacks.

### 10.28 cMarket `+0x280` raw-record accumulation pass (2026-08-30)

The cMarket vtable's `+0x280` entry points to
`FUN_005D5B10 @ 0x5D5B10`. The EN/CH split row is `identical` in
`local/source/compare-report.tsv`; direct PE bytes from the canonical EN and
CH builds are identical for the 82-byte body (SHA-256
`90f58c6184fa9d163bb7cab63f77b76bd42da157f2639d81783a35d1e1fd23fd`). The
corresponding split decompilation is
`local/source/split-merged/code/0x050000/FUN_005d5b10.c`; the raw record
accessors are `FUN_004F8200` (`record+8`) and `FUN_004F8210` (`record+4`). The
method obtains the provider-record count through `+0x2CC`, resets enumeration
with `+0x2D8(0)`, and iterates the records. For every record that is not
all-zero (the same `FUN_004B04F0` empty-record predicate used by the
`+0x268/+0x298` helpers), it pushes **raw `record+8` first and raw
`record+4` second** before calling cMarket `+0x284`; the resulting call is
therefore `(index: record+4, amount: record+8)`. The direct `0x5D5080`
callback adds that amount to `DAT_013126EC[index]`.

The raw index is not an unconstrained opaque number. `FUN_004B04D0 @
0x4B04D0` is an EN/CH-identical two-instruction predicate that compares
`record+4` directly with the reducer's requested commodity argument. The
normal market writer passes `0x1c` (Dinners), and the reducer therefore only
selects records whose raw `+4` key is `0x1c`; the same predicate is used by
the provider-consumption path for every requested key. This confirms
`record+4` as the cMarket internal commodity selector at the record boundary,
while the record-population writer and the complete mapping/lifecycle into
Native `inventoryByCommodityID` remain unresolved.

This closes the previously unknown source of the accumulator's index and
amount at the provider-record boundary and is represented by the pure
`OriginalMarketProviderAccumulator.add` helper plus
`EmperorCoreTests.testOriginalMarketProviderAccumulatorUsesRawRecordIndexAndAmount`.
It does **not** identify the writer that populates the records, the complete
consumer set of `DAT_013126EC`, or the full lifecycle mapping from the
cMarket-internal commodity key to Native inventory and food-shop bundles;
those mappings and the Qin-3 market settlement path remain **unknown**, so
Native inventory is still not wired to this table.

**Classification:** the `+0x280 → +0x284` call edge, all-zero filter, raw
index/amount ordering, EN/CH identity, accumulation operation, and the
`record+4 == requested commodity` selector predicate are **confirmed**. The
record-population writer, complete accumulator consumers, and the full
cMarket-key-to-Native-inventory/settlement mapping remain **unknown**.

### 10.29 `FUN_005D4E80` is a confirmed shared one-unit provider-record writer (2026-08-30)

The earlier `+0x284` trace established the write ordering but did not spell
out how the writer chooses a record. The direct EN/CH body at
`FUN_005D4E80 @ 0x5D4E80` (495 bytes from `0x5D4E80` through the `ret 8` at
`0x5D506E`; identical SHA-256
`e8349979fbceef22574807bfcfc94c96f2c189028e61a2f87215c668f64a1a83`) now
provides that contract. The indexed split file is
`local/source/split-merged/code/0x050000/FUN_005d4e80.c`; the EN/CH comparison
row is `identical 0x5d4e80`.

For a receiver whose vtable supplies this shared provider-record slot, and
requested internal commodity key `K` (`param_2`), the method first applies
receiver-state gates (`+0x1B8`, `+0x4E`, `+0x290`, `+0x2D0`, and the
building/state lookup at `FUN_005DDAF0`). If the gates pass, it derives a
positive remaining unit count `R`; the derivation depends on receiver fields
and is not yet mapped to a Native demand or peddler route. While `R > 0`, it
enumerates provider records using `+0x2CC` and `+0x2D8(0)`, advancing 16 bytes
per record. A candidate is accepted when
`FUN_004B04F0(record)` says it is all-zero **or**
`FUN_004B04D0(record,K)` matches the existing raw key; it must then have
non-zero free capacity from `FUN_005B0510(record) = record+0xC-record+8`
(the literal branch rejects only an exact zero; ordinary records are expected
to remain at or below capacity). Among candidates, the writer initializes its
quantity sentinel to `-1` and uses a strict `>` comparison, so it chooses the
**largest** current quantity `record+8`, not the smallest. An all-zero record
is eligible, but it loses to any eligible same-key record with a positive
quantity; it is selected only when no larger eligible candidate exists. If no
candidate is found, the method returns zero.

For each selected record, the method calls the receiver's `+0x284(K,1)` first,
then calls `FUN_005D2790(record,K,1)`. The latter writes `record+4 = K`, adds
one to `record+8`, and clips only at `record+0xC`. If
`FUN_005D61C0(buildingID)` is true (the separately recovered IDs are `54`,
`56`, and `58`), it also calls `+0x2A0(selectedIndex,1)`. The loop repeats
until `R` units have been added; the successful path returns that derived `R`
value (while gate failure or no candidate returns zero), not a Native inventory
quantity. The apparent direct call at `0x555254` is inside the cMillBldg
`+0x154` wrapper documented below; it is not evidence of a cMarket settlement
caller.

This closes the **shared raw provider-record writer algorithm**: empty-record
eligibility, same-key filtering, strict maximum-quantity selection, one-unit
increments, callback ordering, capacity gating, and the EN/CH identity are
**confirmed**. The state gates' gameplay meaning, the source of `R`, the
identity of the surrounding receiver and `0x555254` wrapper, and the mapping
from internal key `K` to authored goods/Native inventory or Qin-3 peddler
coverage remain **unknown**. Therefore the writer is documented but remains a
research-only contract; the side-effect-free
`OriginalMarketProviderWriter.add` helper and its strict-maximum/tie-order
regression test preserve the recovered record behavior without attaching any
Native inventory or route side effect. Native must not call it from cMarket
settlement until those demand and route mappings are recovered.

#### 10.29a Receiver-class correction for `0x555254` and `FUN_005D4E80` (2026-08-30)

The direct PE pointer tables resolve the receiver scope that the preceding
record-only trace could not establish. The scanned inputs are the canonical
English build `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
and Chinese build
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
In both hash-matched builds, the six vtable entries containing `0x5D4E80`
are at slot `+0x154`. Their RTTI
complete-object locators identify the classes as:

| vtable pointer | RTTI class |
| --- | --- |
| `0x7BDBF4` | `cStorageBldg` |
| `0x7BDED4` | `cStorageBaysBldg` |
| `0x7BE1BC` | `cWarehouse` |
| `0x7BE7A4` | `cTradeBldg` |
| `0x7BEAB8` | `cTradingStation` |
| `0x7BEDC4` | `cTradingQuay` |

The same scan finds `0x555230` at slot `+0x154` of the cMillBldg table
`0x7B72C8`. Its 44-byte EN/CH-identical body (`SHA-256`
`cfbcedf8ab2bdc0a2aee3ee67ce977294e145039509232061afab7aaf3caa0e0`)
accepts only commodity keys `1…9` via the two-compare body in
`local/source/split-merged/code/0x050000/FUN_005db4c0.c`, then forwards its two
arguments to `FUN_005D4E80`; the `E8` at `0x555254` is therefore inside this
cMillBldg wrapper. `FUN_005D2C10 @ 0x5D2C10` calls the common `+0x154` slot while walking
generic object lists, including loops over keys `1…28`, which explains why the
mill wrapper can reject keys outside its raw-food/resource domain.

No direct cMarket vtable slot points to `0x5D4E80`: the canonical cMarket
table `0x7B6F3C` uses its own `+0x264`, `+0x268`, `+0x290`, and `+0x298`
callbacks. Consequently, the earlier description of `FUN_005D4E80` as a
“cMarket provider-record writer” is withdrawn. The function is a shared
storage/trade receiver writer; it does not close cMarket record population,
the Qin-3 peddler route, or the internal-key-to-Native inventory mapping.

The EN/CH comparison row remains `identical 0x5d4e80`, and
`FUN_005DB4C0 @ 0x5DB4C0` is likewise `identical` in
`local/source/compare-report.tsv`. This receiver-class correction is
**confirmed** by PE pointer tables, RTTI names, and the byte-identical wrapper;
no Native behavior is changed.

### 10.30 Market house-level gates aligned with the raw writer (2026-08-30)

The direct `0x5437B0` market callback gates its residential receiver through
`FUN_005188B0 @ 0x5188B0`: only **building model** IDs `2…17` are eligible.
Native stores the corresponding residential level zero-based and derives the
building model with `houseLevelID + 3` (the same mapping used by the worker,
population, and placement bridges), so occupied Native levels `0…14` are the
eligible range. Its separate elite check `FUN_005188D0 @ 0x5188D0` is true only
for building IDs `11…17`, corresponding to Native levels `8…14`.
For an elite receiver, the callback converts the raw market quality through
`FUN_00545100 @ 0x545100` and skips the quality-byte write when the resulting
band is below `3`; the authored conversion is `raw < 30 → 0/1`, `30…49 → 2`,
`50…69 → 3`, `70…89 → 4`, and `90+ → 5`. All three helpers are
`identical` EN/CH rows in `local/source/compare-report.tsv`.

Native previously omitted the upper bound on its `houseLevelID >= 8` elite
cutoff and let the compatibility peddler delivery path serve levels outside
the residential model range. The cutoffs are now aligned with the recovered
predicates: `ResidentialUnit` quality writes exempt only Native levels
`8…14` below raw quality `50`, and the original peddler distribution helper
accepts only Native levels `0…14`. This is a
presentation/state correction only; route, demand, and cMarket-key mapping
remain fail-closed as documented above.

**Classification:** the source ID ranges, the `+3` Native building mapping,
raw-quality threshold, and EN/CH identity are **confirmed**. Synthetic Native
levels outside `0…14` remain unsupported by the original market callback;
standalone helper fixtures must not be read as market coverage evidence.

### 10.31 cMarket `+0x154` raw-record refill boundary (2026-08-30)

The canonical cMarket vtable has a distinct `+0x154` entry at
`0x543BC0`; this is not the shared storage/trade writer
`FUN_005D4E80 @ 0x5D4E80`. The body is not emitted as a standalone split
function in the generated corpus, so the control flow was checked directly
in both hash-matched PE inputs. The 387-byte range `0x543BC0…0x543D42`
has SHA-256 `a4d0de9c43a662ed38ba2c4dfa21cdf76828c7ffce05d2c450b0bfd990fe5de2`
in both the canonical English build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and
the Chinese build
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
The slot is reached through the generic `FUN_005D2C10` virtual walk, but no
caller establishes the source that supplies the cMarket records.

The two stack arguments are `(K, A)`: the first is the cMarket-internal raw
commodity key and the second is the requested amount. The confirmed gate and
remaining-count sequence is:

1. Resolve the market model data from `cMarket+0x62`. Reject when the global
   phase gate `FUN_00426D10(0)` fails, the market's `+0x1B8` worker value is
   non-positive, or `cMarket+0x4E` is non-zero.
2. Call cMarket `+0x290(0, K)`. On the canonical vtable this is
   `FUN_005D3C40 @ 0x5D3C40`; for model-data byte values other than `0` or
   `2` it returns true immediately. Otherwise it compares the model-data
   short at `+0x38 + K*2` with cMarket `+0x264(K)` and returns
   `available >= baseline` when the extra amount is zero. A true result is an
   early return, so the refill does not run when the existing quantity already
   meets that baseline.
3. Read cMarket `+0x2D0`, whose direct EN/CH body is `0x546C00` (the
   `0x546C00…0x546C11` bytes are identical in the two hash-matched PEs;
   18-byte slice SHA-256
   `7da4b6e1c5f8955bdbab739a87eb445d8ec885723ec8be033e8e912bd486933a`).
   It loads the child/container pointer at `cMarket+0x150`, returns zero when
   that pointer is null, and otherwise delegates to the child vtable `+0x08`.
   The returned container value is therefore confirmed as an opaque child
   result, not a proven `count * 400` quantity. The nearby cMarket `+0x2F4`
   entry is the separate direct body `0x546C70` (its 14-byte EN/CH slice
   SHA-256 is
   `1c2af953b279d2b154d1460e508c4bec07a77116cedb9eee72f0dd87ae833cc5`);
   it delegates to the same child at vtable `+0x00` and then computes
   `count * 5 * 5 * 16` (`count * 400`); the direct instruction sequence is
   `lea eax,[eax+4*eax]` twice followed by `shl eax,4`. `0x543BC0` does not
   call `+0x2F4` in this refill path.
   For model-data byte `0` or `2`, the local baseline is instead the
   model-data short at `+0x38 + K*2`.
4. Call `+0x290(A, K)`. When this gate is true, the body computes the refill
   count as `localBaseline - available`; when false, it uses `A` unchanged.
   The loop proceeds only when this resulting count `R` is positive. This is
   the exact arithmetic boundary, but the model-data fields and the gameplay
   meaning of `R` are not recovered.
5. For each of the `R` units, enumerate the provider records from
   `+0x2CC`/`+0x2D8(0)` with the confirmed 16-byte stride. Unlike
   `FUN_005D4E80`, the cMarket body calls only `FUN_004B04D0(record, K)`;
   all-zero records are not admitted unless their raw key is literally `K`.
   It requires `FUN_004B0510(record) != 0` (`record+0xC - record+0x8`),
   then chooses the strictly greatest current `record+0x8` using a `-1`
   sentinel, retaining the first tie. The selected record is updated by
   `FUN_005D2790(record, K, 1)`, which writes `record+4 = K`, increments
   `record+8`, clips only above `record+0xC`, and returns overflow.

If no matching record has non-zero free capacity, the function returns zero;
if all `R` iterations complete it returns `R`. There is no `+0x284` global
accumulator callback in this body. Thus this slot is a cMarket-internal
record refill/top-up operation. The placement path in §10.64 supplies the
record key and capacity for a shop slot; this body still does not prove that
Native inventory or the Qin-3 peddler route can be settled from
`inventoryByCommodityID`.

The pure helper `OriginalMarketProviderRefill.add` and regression
`testOriginalMarketProviderRefillKeepsOnlyMatchingRecords` preserve the
confirmed matching-key, strict-maximum, one-unit, capacity-gated record loop
without attaching market, route, or inventory side effects. The initial
state gates, model-data baseline, monthly/external provider quantity source,
and the downstream coverage/quality lifecycle remain **unknown**; the
placement-time key/capacity writer and cStall cart-deposit quantity write are
confirmed in §§10.63–10.64. Native Qin market settlement therefore remains
fail-closed.

**Classification:** the cMarket vtable slot, EN/CH byte identity, argument
order, `+0x290` gate semantics, `+0x2D0` child delegation/null behavior,
the separate `+0x2F4` `count * 400` helper, positive-count arithmetic shape,
matching-key filter, free-capacity predicate, strict-largest selection,
one-unit `FUN_005D2790` update, and return convention are **confirmed**.
The source and meaning of monthly/external provider quantities, the opaque
`+0x2D0` child result, model-data semantics, and any route/coverage/quality
consumer remain **unknown**; the placed-shop key/slot/capacity assignment and
cart-deposit quantity write are confirmed by §§10.63–10.64.

### 10.32 Provider-record population negative boundary (2026-08-30)

The remaining cMarket record-population blocker was rechecked from both
callers and raw call targets. `FUN_004AEDF0 @ 0x4AEDF0` walks the generic
object list and, under the global `DAT_00C5CDA0` gate, invokes every eligible
object's virtual `+0x154` with `(0x1c, 200)`. This proves that the normal
resource-dispatch loop can reach cMarket's `0x543BC0` body, but it does not
prove that the dispatch creates a provider record: the cMarket body filters
records with `FUN_004B04D0(record, 0x1c)` before selecting any record, so an
all-zero record is not admitted for Dinners.

The direct `FUN_005D2790 @ 0x5D2790` call inventory in both PE inputs contains
only four call sites: `0x4C4F46` (the unsplit storage/trade receiver path),
`0x5417E5` (the cStall blend/store path), `0x543D13` (cMarket
`0x543BC0` itself), and `0x5D5021` (the provider-record reducer). The cMarket
constructor `FUN_00543450` allocates its six 16-byte records and initializes
each with `FUN_005D2690(capacity = 0x190)`, which writes raw key `+4 = 0`,
quantity `+8 = 0`, and capacity `+C = 400`. Its cMarket save path
`FUN_00544F10 → FUN_005D4890` also serializes the record array before
persisting the market slot/quality fields (see §10.32a). The earlier negative
was limited to `FUN_005D2790` call
sites; a separate direct key/capacity writer is now confirmed: shop placement
reaches `FUN_00540E70 → FUN_00540F80`, which calls
`FUN_0053C700(record, key)` and `FUN_004C1550(record, 400/800)` (§10.64).
Thus placement populates `record+4` and `record+0xC`; the cStall cart-deposit
path populates `record+8`, while no separate monthly/external Qin provider
quantity producer has been recovered.

This is a **confirmed negative search**, not proof that an indirect
table-indexed store, an external buffer copy, or a runtime-only registration
callback cannot populate `record+4/+8`. It does establish that the generic
`(0x1c,200)` dispatch and cMarket `+0x154` refill cannot, by themselves, be
used as a Native inventory bridge. The monthly/external provider source and
route/coverage/quality lifecycle therefore remain **unknown**; the
placement-time key/slot/capacity mapping and cart-deposit quantity path are
confirmed in §§10.63–10.64. Native Qin settlement stays fail-closed.

### 10.32a cMarket provider records are persisted separately from producer discovery (2026-09-01)

The cMarket save/load boundary is separate from that negative producer search:
`FUN_00544F10 @ 0x544F10` begins by calling `FUN_005D4890 @ 0x5D4890`, whose
EN/CH-identical body obtains the provider-record count from cMarket `+0x2CC`,
selects the contiguous array through `+0x2D8(0)`, and invokes each record's
vtable `+0x08` serializer while advancing by `0x10` bytes. The corresponding
`FUN_005D4810 @ 0x5D4810` load path obtains the same count and advances through
the same array, applying the common record-field copier
`FUN_004C5B30 @ 0x4C5B30` to each slot. The cMarket-specific fields at
`+0x15C/+0x174…+0x188` are then restored by the remainder of
`FUN_00544F10`; this does not replace or omit the provider-record loop.
Therefore the six records' raw key/quantity/capacity state is part of the
cMarket persistence stream. The unresolved edge is the pre-save producer or
post-load registration that gives those records non-zero keys/quantities, not
whether the records can survive a save/load cycle.

**Evidence class:** **confirmed** for the save/load call order, shared record
array/count/stride, and the distinct cMarket field tail in EN/CH-identical
`FUN_00544F10`, `FUN_005D4890`, `FUN_005D4810`, and `FUN_004C5B30` rows;
**unknown** for the record vtable `+0x08` concrete stream encoding, the
pre-save quantity producer, and any post-load provider registration or Native
inventory/route projection. This persistence result does not authorize Qin
market settlement.

### 10.33 Residential commodity requirement reader (`FUN_00588CB0`, 2026-08-30)

The housing-upgrade commodity reader has a separate, directly recoverable
boundary that must not be conflated with the cMarket provider-record path.
`FUN_00588CB0 @ 0x588CB0` is present in
`local/source/split-merged/functions-index.csv` and
`local/source/split-merged/code/0x050000/FUN_00588cb0.c`; its EN/CH comparison
row is `identical` (`local/source/compare-report.tsv`). The split corpus has
no emitted direct caller, but a direct `E8` scan of both hash-matched PEs
recovers two call sites: `0x588E89` inside the omitted method
`FUN_00588D90 @ 0x588D90`, and `0x5890D3` inside the omitted method
`FUN_00588FB0 @ 0x588FB0`. Both methods are present in the `cSuppliesOverlay`
vtable at `0x7BA2F4` and the `cDistributionOverlay` vtable at `0x7BA448`
(`FUN_00588D90` at slot `+0x00`, `FUN_00588FB0` at slot `+0x28`); the RTTI
type descriptors identify those two overlay classes. The omitted method byte
ranges are EN/CH-identical: `0x588D90…0x588F0F` (384 bytes, SHA-256
`f7e00f35652e7587d6cd7a3a1fdf17313bcf2832e751e2dbb7af1dbd87adeeca`) and
`0x588FB0…0x5891AF` (512 bytes, SHA-256
`bb6d5e3f52106c82c1b47ab6feabb0cbb37534dde0c5d7efe3893f1bde074ef1`).
These are overlay/inspector consumers of the requirement predicate, not a
recovered housing-evolution scheduler caller; the evolution caller and any
indirect virtual dispatch remain unresolved.
A corpus-wide `rg` search finds `DAT_0085C334`, `DAT_0085C34C`, and
`DAT_0085C3DC` references only inside this function; no indexed initializer,
writer, or second reader for these tables is present. This is a negative
search boundary, not evidence that an indirect table access cannot exist.

The adjacent helper `FUN_00588C40 @ 0x588C40` is separately indexed and
`identical` in EN/CH. Its switch returns compact values
`0x13→1`, `0x19→2`, `0x16→3`, `0x0D→4`, and `0x18→5`, with `0` for every
other commodity (including `0x17`). The corpus has no direct caller for this
helper, so the values are recorded only as a raw mapping; they must not be
treated as the inverse of `DAT_0085C334` or as proof that bronzeware is
excluded from the luxury requirement. The explicit `0x16`→`0x17` maximum in
`FUN_00588CB0` is the stronger, caller-local evidence for that alternative.

For a residential object handle `H` and requirement index `R`, the function
performs this confirmed sequence:

1. Resolve `H` and classify the building through `FUN_005188D0`. The latter's
   recovered predicate accepts only building IDs `11…17` (elite houses).
2. Select a threshold from one of two global tables. For a non-elite object,
   the table row uses `houseBuildingID - 2` (clamped at zero) and an indexed
   expression based on `R`; for an elite object it uses `houseBuildingID - 13`
   (also clamped) and a separate expression. The table addresses are
   `DAT_0085C34C` and `DAT_0085C3DC`; their row values and semantic names are
   not emitted in the indexed corpus.
3. When `R == 0`, compare the result of `FUN_00519D40(H)` with that threshold.
   For `R > 0`, load the commodity ID from `DAT_0085C334[R]`, convert it to a
   `cHouseInfo` word slot with `FUN_00447600 @ 0x447600`, and read the signed
   word at `cHouseInfo + 0x12 + slot*2` through the house vtable `+0x1E4`.
4. The `0x16` (lacquerware) case performs the explicit alternate check for
   commodity `0x17` (bronzeware) and keeps the larger of the two slot values.
   The returned predicate is `storedQuantity <= selectedThreshold` (the
   canonical PE ends with `cmp` followed by `setle`).

The slot conversion itself is already represented by
`OriginalMarketHouseInfoSlot` and its focused regression. `GameData/Model/
EmperorBuildingModels.txt` independently names the corresponding authored
fields in order—hemp, ceramics, tea, silk, then “bronzeware or lacquerware”—
which corroborates the special two-good branch but does not recover the two
global threshold tables or the missing virtual caller.

#### 10.33a Authored `ALL HOUSES` rows carry commodity requirements (corrected, 2026-08-30)

Correction to the previous note: the 13-value rows at file lines 86–102 are
`ALL BUILDINGS`, not house requirement rows. The relevant data is the
24-value `ALL HOUSES` section at `GameData/Model/EmperorBuildingModels.txt`
(`HOUSE MODS` begins at line 355; `ALL HOUSES` at line 363). Its header
assigns requirement columns `j…n` to hemp, ceramics, tea, silk, and
“bronzeware or lacquerware” (header lines 40–44). The authored elite rows
contain these values in those positions: `Elite 1: Modest Siheyuan` has
`1,1,0,0,0`; `Elite 2: Lavish Siheyuan` has `1,1,0,1,0`; `Elite 3: Humble
Compound` has `1,1,0,1,1`; `Elite 4: Impressive Compound` has `1,1,0,1,1`;
and `Elite 5: Heavenly Compound` has `1,1,1,1,1`. The ordinary rows
progress from all-zero requirements through one-unit hemp/ceramics/tea
requirements; silk and the shared luxury field appear only in later elite
rows. These values are the authored semantic requirements, not the
population-capacity/tax fields that follow them.

This corroborates the executable reader's commodity domain and its shared
luxury branch, but it does **not** by itself prove that the values are the
runtime contents of `DAT_0085C34C`/`DAT_0085C3DC`, nor does it identify the
`DAT_0085C334` requirement-index mapping or the post-load/difficulty
conversion. Treating the authored values as a direct substitute for those
tables would still be an unsupported bridge.

The model-loader path makes that distinction explicit. `ERR_No_Building_Model_file`
@ `0x5D1830` parses the `ALL HOUSES` rows into the 24-column table at
`DAT_00A63BFC`, applying the selected difficulty modifier; the identical
`FUN_005D16D0 @ 0x5D16D0` reload path restores the same table from its static
defaults. `FUN_0044CC80 @ 0x44CC80` is the indexed reader for that table and
is itself `identical` in EN/CH. Neither loader nor `FUN_0044CC80` references
`DAT_0085C34C`, `DAT_0085C3DC`, or `DAT_0085C334`; the corpus-wide search
still finds those three globals only in `FUN_00588CB0`. Thus the authored
one-unit requirements are confirmed inputs to the ordinary house-model table,
while their relationship to the executable reader's separate threshold/index
tables remains an unresolved linkage rather than an absent-data case.

The threshold/index data itself is now recovered by read-only PE inspection
of the same hash-matched builds named at the top of this document. The raw
English and Chinese ranges are byte-identical (range SHA-256 values are shown
for auditability):

| global | range | decoded values | range SHA-256 |
| --- | --- | --- | --- |
| `DAT_0085C334` | `0x85C334..<0x85C34C` | `[49, 19, 25, 13, 24, 22]` | `df4f179d78a6dcf3e25920f893735536e17b023047dc9634756fe6ec5c35ffc6` |
| `DAT_0085C34C` | `0x85C34C..<0x85C3DC` | 9 rows × 4: `[2,0,0,0] … [20,2,3,2]` | `2cce50f754c253ea1fe0510616729afc983a28ff7a9e71f0f1f63cb9b6e6d8c7` |
| `DAT_0085C3DC` | `0x85C3DC..<0x85C454` | 5 rows × 6: `[1,2,2,0,0,0] … [5,2,2,2,2,2]` | `5ae2266527bbbf687705d1893ac8bebbf08694ebb70f56beaef6dbfd30b5e058` |

The first range's index zero (`49`) is bypassed by the `R == 0` branch;
indices `1…5` select hemp, ceramics, tea, silk, and lacquerware, with the
reader's explicit bronzeware (`0x17`) maximum in the final case. The nine
non-elite rows are selected by `buildingID - 2` and the five elite rows by
`buildingID - 13`, exactly matching the split expression. This closes the
numeric table contents and the requirement-index commodity mapping. It does
not close the caller or the Native cHouseInfo quantity lifecycle.

**Classification:** the `ALL HOUSES` field positions and listed values are
**confirmed** from the checked-in model file; their exact correspondence to
the executable's two threshold tables, difficulty adjustment, and
requirement-index table remains **unknown**. No Native evolution rule is
changed by this correction.

##### Native research-only table projection

The recovered PE constants are represented by the pure
`OriginalResidentialRequirementTable` lookup in
`Sources/EmperorCore/MarketSimulation.swift`, with regression coverage in
`EmperorCoreTests.testOriginalResidentialRequirementTableMatchesRecoveredPEData`.
It exposes the exact `DAT_0085C334` commodity IDs and the non-elite/elite
row values, including the source's clamped rows for building IDs 11 and 12.
The helper has no side effects and is not called by live housing evolution:
the mapping from these cHouseInfo quantities to Native's supply lifecycle is
still unresolved.

**Classification:** the elite split, table-index expressions, `cHouseInfo`
slot read, lacquerware/bronzeware maximum, and `<=` comparison are
**confirmed**, as are the numeric contents of the three referenced PE ranges
and the `DAT_0085C334` mapping. The direct caller, the relationship between
the authored model rows and the executable tables, and the Native mapping of
the stored quantity remain **unknown**. Native's current
`lastSuppliedCommodityIDs` presence check therefore remains a compatibility
approximation and must not be described as the original quantity predicate;
Qin-3 housing evolution stays fail-closed until the provider-to-house
quantity lifecycle is recovered.

### 10.34 Elite `cHouseInfo` stock consumption boundary (`FUN_005F05D0`, 2026-08-30)

The corpus also exposes a direct consumer of the same `cHouseInfo` stock
words. `FUN_005F0B50 @ 0x5F0B50` dispatches object state `+0x12 == 0x10` to
`FUN_005F05D0 @ 0x5F05D0`; both EN/CH rows are `identical`. The consumer gates
on `FUN_005188D0`, so its recovered body applies only to elite building IDs
11…17 and the global simulation gate. For IDs 13…17 it loads model fields
through `FUN_0044CC80` in the order `[12, 9, 10, 11, 13, 13, 17]`, doubles
them, and derives a per-pass target. The special ID 11 branch supplies
literal targets `[4, 4, 10, 10, 10, 20]`; its sixth (Dinner/capacity) local
value is not initialized in the decompilation and is kept **unknown**.

The six commodity/resource targets are projected through the raw PE array
`DAT_00875CA8`, whose EN/CH-identical seven-word range is
`[3, 1, 2, 6, 4, 5, 0]` (range `0x875CA8..<0x875CC4`, SHA-256
`604a80347c2171c61f22647568a892a381ae7f0efed7dfb31b9d98c7069f65f6`). This
maps the loop to cHouseInfo slots Silk, Hemp, Ceramics, Tea, Bronzeware,
Lacquerware, then Dinners. For each pass the body applies the signed
`(value + (value >> 31 & 3)) >> 2` quotient to the doubled target, raises it
to the current stock's quotient by four when the stock is larger, and
subtracts that amount from the cHouseInfo word; if stock is insufficient it
records the deficit and writes the word to zero. For non-negative values this
is truncation toward zero (not mathematical ceiling). The writes are direct
`+0x12 + slot*2` mutations, not a presence marker.

There is no direct caller for `FUN_005F0B50` or `FUN_005F05D0` in the split
corpus, so the scheduler/virtual dispatch boundary remains unresolved. This
evidence nevertheless closes an important negative: original residential
commodity quantities are consumed and can be cleared independently of the
upgrade predicate. Native's `suppliesByCommodityID` may be a compatible
storage shape, but its exact update cadence and projection into the original
house-info words are not proven; no live Native path is changed.

**Classification:** elite gate, model-field order, slot projection, signed
divide-by-four arithmetic, deficit/zero writes, and EN/CH identity are
**confirmed**. The
special ID-11 sixth value, outer scheduler/cadence, and Native quantity
correspondence remain **unknown**.

##### Native research-only stock projection

The confirmed seven-pass mutation is represented by the pure
`OriginalEliteHouseStockConsumption.consume` helper in
`Sources/EmperorCore/MarketSimulation.swift`, with regression coverage in
`EmperorCoreTests.testOriginalEliteHouseStockConsumptionMatchesRecoveredPassOrderAndDivision`.
It accepts the executable building ID, the corresponding Native `HouseModel`
row (`buildingID - 3`), resident count, and raw seven-word cHouseInfo stock;
it returns the updated slots, selected amounts, and pass-local deficits. IDs
11 remains unsupported because its special target array's seventh local is
uninitialized in the recovered body; ID 12 follows the generic model-field
branch and is included by the helper.

The implementation preserves the PE expression
`(value + (value >> 31 & 3)) >> 2`: for the non-negative authored values used
here this is truncation toward zero, not mathematical ceiling. This correction
is important because replacing it with a ceiling would consume a different
quantity from every positive stock word. The helper has no object-state or
calendar side effects and is not called by live Qin simulation.

**Evidence class:** the seven-pass projection and signed divide expression are
**confirmed**; the cHouseInfo-to-Native stock source, scheduler cadence, and
Qin reachability remain **unknown**.

#### 10.34a Direct figure-state caller for `FUN_005F0B50` (2026-08-30)

The split index omits the enclosing function, but direct PE disassembly
recovers its call edge. In the unindexed body beginning at `0x4D0390`, the
state switch on figure byte `+0x40` dispatches the `+0x40 == 7` branch through
`FUN_004E47A0`; when that movement call leaves heading byte `+0x19 == 8`, the
call instruction at `0x4D0460` invokes `FUN_005F0B50(figure)`. The
`0x4D0390..<0x4D0510` range is byte-identical in the canonical EN/CH PEs
(SHA-256 `da6dd9fbdce74811a21f63196f58364c17125087bb80428d68d17edf43701b84`).
`FUN_005F0B50` then dispatches to `FUN_005F05D0` only when the figure state
byte `+0x12` is `0x10`; state `0x11` takes a separate terminal branch.

This closes the immediate caller/trigger condition for the elite stock
consumer: it is reached after a figure movement update reaches heading 8,
not from a generic monthly house loop visible in the split corpus. The
outer scheduler that enters the unindexed `0x4D0390` body, the figure class,
and whether Qin's live figures reach this state remain **unknown**. Native
therefore still must not wire the recovered cHouseInfo consumption into its
calendar tick solely from this edge.

The callback's table context further separates it from service providers: the
executable's 10-word rows indexed by figure byte (`PTR_DAT_0084E788`) contain
`0x4D0390` in the final word for rows 13, 14, 15, and 16. The corresponding
authored figure IDs are homeless, beggar, muggar, and thief
(`GameData/Model/EmperorFigureModels.txt`, rows 13–16). The four-row PE range
`0x84E9A8..<0x84EA48` is EN/CH-identical (SHA-256
`287ac8c4cdab191526e12050e5556785eb9debfbd57c0f39941ec736106c1e51`). This
is evidence of a shared figure callback slot, not a provider-vtable entry;
the slot's business label remains **unknown**.

**Evidence class:** **confirmed** for the direct call address, state-7 and
heading-8 guards, EN/CH identity, and `+0x12` sub-dispatch; **unknown** for
the enclosing function's class, outer scheduler, and Qin reachability.

#### 10.34b Figure-update scheduler is a negative boundary for this callback

The ordinary per-step figure scheduler is separately visible: `FUN_005371A0
@ 0x5371A0` calls `FUN_004E27E0 @ 0x4E27E0` after the calendar phase dispatch,
and `FUN_004E27E0` walks active figure objects and invokes each figure vtable
slot `+0x28`. The EN/CH rows for both functions are `identical`. In the
hash-matched PE vtables inspected for the figure classes, that slot resolves
to the generic motion body `FUN_005E5CA0 @ 0x5E5CA0`, not to `0x4D0390`.

The `0x4D0390` body therefore cannot be promoted to the normal figure-update
entry merely because it contains the `0x4D0460 → FUN_005F0B50` call. A raw
PE pointer scan finds `0x4D0390` only in the final word of the 10-word rows
for figure-table rows 13–16; no direct call or vtable `+0x28` edge to that
address appears in the indexed corpus. This is consistent with a shared
figure-specific callback slot, but does not recover the slot's invoker or
semantic action. The stock projection above remains research-only and must
not be scheduled from `FUN_005371A0` or a Native calendar tick.

The adjacent state helpers reinforce this boundary. `FUN_005F04A0` selects a
provider/object candidate (falling through `FUN_005F0A20` when no special
provider is found), while `FUN_005F0800` decrements a figure countdown and
returns or terminates the figure based on its parent model. Both are in the
same figure-action family as the `0x4D0390` state switch; neither is a
residential monthly producer. Their EN/CH rows are `identical`, and no source
call from these helpers reaches `FUN_005F0B50`. This does not name the action
performed by `FUN_005F05D0`—it only rules out treating its raw stock mutation
as a confirmed housing-supply update.

**Evidence class:** **confirmed** for the ordinary scheduler edge and its
generic vtable slot; **confirmed negative** for the absent direct/vtable edge
to `0x4D0390`; **unknown** for the callback-table invoker, action semantics,
and Qin reachability.

#### 10.34c Stock-slot table is also an action-candidate filter

The same slot order is consumed by the adjacent figure-action selector.
`FUN_005F0A20 @ 0x5F0A20` scans its candidate-object list, gates each entry by
global state plus vtable slots `+0xB8` and `+0x204`, then checks cHouseInfo
words through `DAT_00875CC4` in the order `[3, 1, 2, 6, 4, 5, 0]`. With its
normal `param_2 == 0` call from `FUN_005F04A0`, a candidate is retained only
when the selected raw stock word is positive; the selector records provider
`+0x2D` and map coordinates before passing the records to `FUN_004E7FD0`.
`FUN_005F04A0` is reached from the same figure-action family as the
`0x4D0390` state switch. The EN/CH rows for `0x5F0A20` and `0x5F04A0` are
`identical`.

Direct PE reads show `DAT_00875CC4` is byte-identical to `DAT_00875CA8` in
both canonical builds: range `0x875CC4..<0x875CE0`, values
`[3, 1, 2, 6, 4, 5, 0]`, SHA-256
`604a80347c2171c61f22647568a892a381ae7f0efed7dfb31b9d98c7069f65f6`.
This confirms that the raw stock words serve both the action candidate filter
and the later seven-pass mutation, but it still does not identify the
human-facing action or map the original provider/object list to Native.

The list owner is now bounded without assigning a gameplay label to the
action. `FUN_005177B0 @ 0x5177B0` returns `&DAT_010BFEF0`; its `+4`/end
accessors are the same list used by `FUN_004ADA10`, whose admitted entries
carry building fields `+0x20/+0x22/+0x24` and a `+0x32` figure link. That
routine calls `FUN_004ADE10` with the entry's registry index; the helper
creates authored figure model 11 (`immigrant`), stores the target object in
the figure, and writes the reciprocal `building +0x32` link. The EN/CH rows
for `0x5177B0`, `0x4F8210`, `0x4ADA10`, and `0x4ADE10` are `identical`.
Together with `FUN_005F0A20`'s cHouseInfo `+0x1E4` read, this makes the
candidate list a building/house object list rather than a cMarket provider
record list. The exact action that later consumes the selected object remains
**unknown**.

**Evidence class:** **confirmed** for the shared list accessor, immigration
figure-link writes, and non-market object-list boundary; **unknown** for the
selected action's human meaning and its Qin reachability.

**Evidence class:** **confirmed** for the shared slot table, positive-stock
candidate gate, provider-index/coordinate record, and EN/CH identity;
**unknown** for the candidate list's semantic owner, action resolution, and
Qin reachability.

### 10.35 Shared provider-fill state predicate (`FUN_005D5C70`) (2026-08-30)

The previously unrecorded three-way provider-record predicate is now closed
at the raw record boundary. `FUN_005D5C70 @ 0x5D5C70` is present in the
indexed corpus and its EN/CH comparison row is `identical`. Direct bytes from
the canonical English and Chinese executables are identical for the 101-byte
body (`0x5D5C70..<0x5D5CD5`, SHA-256
`b7ad720542634b0b80a4169205453912f75a24f10aee9de6b504cc7d87984714`).

The body performs the following exact sequence:

1. Read the provider-record count through virtual slot `+0x2CC`, then reset
   the contiguous-record cursor with `+0x2D8(0)`.
2. For each 16-byte record, call `FUN_004B04F0`. An all-zero pair
   (`record+4 == 0 && record+8 == 0`) increments an `empty` counter; every
   other record contributes `FUN_004F8200(record)` (`record+8`) to an integer
   sum. The loop advances by `0x10` bytes in container order.
3. Return `0` immediately when any empty record was observed. Otherwise,
   return `1` when the sum is **at least `0xC80` (3200)**, and return `2` for
   a smaller sum. A null/zero-length container therefore returns `2`.

The target appears in five shared provider/market-derived function tables in
the `.rdata` section (table address points `0x7BE140`, `0x7BE420`,
`0x7BEA10`, `0x7BED20`, and `0x7BF030`); the exact concrete class and the
invoking scheduler are not identified by the corpus. The canonical cMarket
table at `0x7B6F3C` does **not** expose this address as a direct slot, so this
predicate must not be labelled a cMarket virtual method without an additional
RTTI/caller proof. No direct `E8` caller is emitted in the indexed source.

The raw contract is represented by
`OriginalMarketProviderFillState.classify` in
`Sources/EmperorCore/MarketSimulation.swift`. It is intentionally a pure
record-state helper: no provider quantity is mapped to Native inventory, no
UI label is assigned to values `0/1/2`, and no Qin-3 market or peddler path
consumes it.

**Evidence class:** **confirmed** for the EN/CH byte identity, record stride,
empty-record precedence, `3200` threshold, and return values; **unknown** for
the concrete receiver class, scheduler/caller, human-facing meaning, and
provider-record-to-Native inventory mapping. This narrows another market
state boundary but does not unblock Qin-3 settlement, route coverage, or
food-quality production.

### 10.36 House access/flood refresh state machine (`FUN_00518A50`) (2026-08-30)

The house vtable at `0x7ABA38` identifies `+0x84` as `FUN_00518A50 @
0x518A50`; the EN/CH comparison row is `identical`. In both canonical PE
files, the function range `0x518A50..<0x518B70` is 288 bytes with SHA-256
`04940d2a0c95d3ad6ad507b145020d652aef838d0f255d5499d93adea6fb2a44`.
Its direct callee
`FUN_004BA6F0 @ 0x4BA6F0` scans up to 24 orientation-specific candidate
offsets and writes the selected access coordinates to globals
`DAT_010C72AC/ DAT_010C72A8`. The house method then calls vtable `+0x1A4`
(`FUN_004273F0 @ 0x4273F0`) to turn those coordinates into a map-cell index
and reads `DAT_01391FE0[cell]` (the land-entry flood snapshot).

The recovered field transitions are now represented by the pure helper
`DeterministicMigration.refreshHouseAccess` in
`Sources/EmperorCore/MigrationSimulation.swift`, with no candidate scan or
`FUN_004AE150` side effect hidden inside it:

* A failed candidate increments house `+0x28` and zeros `+0x24`. When the
  retry becomes greater than `4`, a nonzero house `+0x20` requests the
  `FUN_004AE150` repair path and resets the retry; regardless of that path,
  house state byte `+0x04` is set to `2`.
* A candidate whose flood value is nonzero clears the retry and stores the
  exact value in `+0x24`; the method returns the original `retry == 0` result.
* A zero flood value zeros `+0x24`, conditionally copies house `+0x10` to
  the callback's external integer when the retry is zero and
  `(house +0x14 == 2 && house +0x20 == 0) || external == 0`, then increments
  the retry. A retry above `8` resets to zero; state byte `+0x04` becomes `2`
  only for the special `(house +0x14 == 2 && house +0x20 == 0)` case.

Focused tests cover the nonzero-flood store, the four-retry repair boundary,
the conditional external write, and the eight-retry zero-flood boundary.
This closes the refresher's retry/field contract but does **not** map
`FUN_004BA6F0`'s object/map flags or the access-coordinate globals to Native
house geometry. Native immigrant assignment therefore remains fail-closed;
the remaining blocker is the candidate/access-cell mapping, not the retry
state machine.

**Evidence class:** **confirmed** for the vtable slot, EN/CH identity,
callee chain, retry thresholds (`4` and `8`), field offsets, flood-value
store, and conditional external/state writes; **unknown** for the semantic
meaning of the candidate flags, complete object-type coverage, and Native
access-cell mapping.

### 10.36a `FUN_004BAF40` two-stage access candidate selection (2026-08-31)

The EN/CH-identical body at `FUN_004BAF40 @ 0x4BAF40` is now represented as
the pure, explicit-input helper
`DeterministicMigration.selectHouseAccessCandidate`. The helper is a research
boundary only; no live immigration or house refresher calls it. The canonical
hashes remain EN `8a6d2df1…6753` and CH `dbdeca1e…15a`, with the function pair
listed `identical` in `local/source/compare-report.tsv`.

The recovered control flow is:

1. Walk at most 24 signed offsets from `DAT_00820038 + footprintSide*0x60`.
   An occupied-cell object may adjust the offset through its vtable `+0xD0`;
   a return of `-1` rejects that row. The candidate then requires map flags
   `0x40` set and `0x04` clear, a positive `DAT_01391FE0` flood value, and a
   component label found in the ten-entry `DAT_01312588` priority table.
2. The table scan uses sentinel rank `11` for an absent label and keeps the
   first row at the best rank through a strict `<` comparison. The selected
   coordinates are the object-adjusted cell and are written to
   `DAT_010C72AC/A8`.
3. If no ranked row qualifies, the second loop ignores object callbacks,
   map flags, and component rank. It chooses the strictly smallest positive
   flood value over the raw perimeter offsets, preserving table order on
   ties; no candidate returns zero.

This closes the candidate arbitration order and the distinction between the
adjusted ranked pass and raw-offset flood fallback. It does **not** identify
the object registry behind `DAT_00FC3750`, the semantic mapping of runtime
flags `0x40/0x04`, or the coordinate-global projection into Native house
geometry. Those inputs remain **unknown**, so automatic migration and the
specialized `+0x84` refreshers stay fail-closed.

**Evidence class:** **confirmed** for the two loops, 24-slot bound, callback
rejection, flag/flood predicates, rank sentinel, strict tie behavior, and
fallback omissions; **unknown** for object/map projections and gameplay
meaning. Focused tests cover best-rank selection, adjusted-vs-raw coordinates,
and equal-depth fallback ties.

### 10.36b Generic house-access `+0xD0` callback (2026-08-31)

The generic object callback branch used by `FUN_004BAF40` (and the related
rectangular `FUN_004BA370` scan) is now represented independently as
`DeterministicMigration.houseAccessObjectCallback`. Its source chain is
`object vtable +0xD0 → FUN_00426D80`, with `FUN_00415700` providing the
rejection predicate and `FUN_00420EB0` performing the direction-byte
adjustment. The EN/CH rows for these three callback-chain functions are
`identical` in `local/source/compare-report.tsv`. `FUN_004BA6F0` is
deliberately excluded:
its occupied-object branch calls `+0xE4` and then `+0x190/+0x194`, which remain
a separate unresolved path.

The pure helper preserves the callback's raw return domain: `-1` for model
`0x7E` or `FUN_00415700` IDs `{0xE7,0x5B,0x5A,0x59,0xE8,0x6A,0x69,0x68}`;
`0` for other models; and `1` for Grand Way/Imperial Way (`0x6F/0x71`). The
`1` branch leaves an existing road cell unchanged, otherwise it applies the
same `±1` or `±0xE4` movement selected by the raw direction byte. The
canonical `0xE4` stride and all branch boundaries are asserted by
`MigrationSimulationTests`.

This closes the callback arithmetic and rejection polarity, but it does not
recover the runtime object registry, the meaning/projection of
`DAT_00F6A9E0`/`DAT_00FDCD70`, or the coordinate globals used by the house
records. The helper is therefore research-only and Qin automatic migration
remains fail-closed.

### 10.36c `FUN_004BA6F0` perimeter candidate arbitration (2026-08-31)

`FUN_004BA6F0 @ 0x4BA6F0..<0x4BA870` is the occupied-cell perimeter access
selector and is a separate path from the generic `+0xD0` callback above. The
EN and CH bodies are
`identical` in `local/source/split-merged/compare-report.tsv`; the canonical
inputs are EN SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
SHA-256 `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

The function reads the 24-entry perimeter table `DAT_00820038`, selecting the
row at `footprintSide * 0x60` (six bytes per `(dx,dy)` pair). It initializes a
rank sentinel of 12 and performs one pass over the row in table order. For an
occupied cell, the object is resolved through `DAT_00FC3750`; its `+0xE4`
callback must accept, `FUN_00562F70(modelID)` must return zero, and its `+0x190`
callback may replace the offset through `+0x194`. Empty cells skip this object
path. The resulting (possibly adjusted) cell must have flag `0x40` and not
`0x04`; the component label is ranked through the ten-entry `DAT_01312588`
table, with an absent label receiving source sentinel 11. The strict
`candidateRank < bestRank` comparison means the first equal-rank candidate
wins. There is no flood-depth fallback in this function: if no candidate has a
rank below 12 it returns zero.

Relevant callers include the house refresher `FUN_00518A50 @ 0x518A50` and
the rectangular/monument access wrappers `FUN_004F97D0`, `FUN_005078E0`,
`FUN_00428A80`, `FUN_004C6EE0`, `FUN_004F02C0`, `FUN_004F01F0`,
`FUN_00508C70`, and `FUN_005F1280`; `FUN_004BA9B0` also forwards the current
monument coordinates. The direct object/map callees are `FUN_0047F1B0`,
`FUN_00562F70`, and the receiver vtable slots `+0xE4`, `+0x190`, and
`+0x194`.

`selectOriginalHouseAccessCandidate` in
`Sources/EmperorCore/MigrationSimulation.swift` mirrors only this pure
arbitration. `MigrationSimulationTests` covers adjusted-vs-raw coordinates,
equal-rank ordering, and the no-candidate return. The runtime object registry,
occupied-object callbacks, map flag/component projection, and
orientation/coordinate globals remain **unknown**; Native does not synthesize
them, and Qin automatic migration remains fail-closed.

### 10.36d `FUN_004ADD60` nearest-house arbitration (2026-09-03)

`FUN_004ADD60 @ 0x4ADD60` is the object-vector selector that feeds a figure
state path before the house access writer. The EN and CH bodies are marked
`identical` in `local/source/compare-report.tsv`; the canonical executable
hashes are EN SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
SHA-256 `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
The indexed body in
`local/source/split-merged/code/0x040000/FUN_004add60.c` starts its object
pointer at `FUN_00413B40(1)`, starts the returned vector index at `1`, and
walks while `i < FUN_00554C00()`.

For each row it first requires the global `FUN_00426D10(0)` gate and a true
house vtable `+0xB8` callback. It then requires signed-short `+0x24 > 0`,
signed-short `+0x22 > 0`, and signed-short `+0x32 == 0`. The distance call
`FUN_00408BC0 @ 0x408BC0` compares the caller's two integer arguments with
the candidate shorts read from object `+0x28` and `+0x0C`; its EN/CH body is
also `identical` and returns `max(abs(dx), abs(dy))`. The selector initializes
its best-distance sentinel to `1000` and updates only on strict `<`, so a
distance of exactly 1000 is not selected and the first equal-distance row
wins. No candidate leaves the source return at zero.

Machine-level direct-call census in both canonical PEs found the selector at
`0x4CAAB3` and `0x4CAF47`; those sites pass figure coordinate words and, on a
nonzero house ID, continue through the house access/link and figure-state
writes. The surrounding caller is a corpus gap, so these callsites establish
the consumer edge but do not identify the state path as Qin-specific.

`DeterministicMigration.selectOriginalImmigrantHouse` mirrors only this pure
arbitration. Its candidate record normalizes the five source shorts and keeps
the raw distance fields intentionally unnamed; the helper is not wired to
Native objects or automatic migration. The active object-vector population,
`FUN_00413B40`/`FUN_00554C00` registry projection, house callback result,
meaning of the `+0x28/+0x0C` words, and downstream route/arrival settlement
remain **unknown**, so Qin production remains fail-closed.

**Evidence class:** **confirmed** for gate order, field offsets, signed widths,
Chebyshev distance, sentinel, strict tie behavior, vector start index, EN/CH
identity, and the two direct callsites; **unknown** for object registry
provenance, raw-field semantics, caller state identity, and Native projection.

### 10.37 Mill six-slot food bundle writer (`FUN_005557D0`) (2026-08-30)

The split corpus contains `FUN_005557D0 @ 0x5557D0`; its next indexed
function begins at `0x5558D0`, so the recovered body occupies
`0x5557D0..<0x5558D0` (256 bytes). `local/source/compare-report.tsv` marks
the EN/CH pair `identical`. The canonical executable inputs are EN SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
SHA-256 `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

The direct caller `FUN_00555410 @ 0x555410` dispatches cases 1 through 5
through the mill vtable's `+0x2F0` callback, supplying the requested amount,
the output type/amount arrays, and the selected type count. The decompiler
does not recover all register names in that caller, so this is a call-shape
finding rather than a semantic name for those arguments. The writer itself
performs the following confirmed operations:

1. Compute `perAmount = ((requested / typeCount) / 100) * 100` using signed
   integer division. While `perAmount * typeCount > 600`, subtract 100 from
   `perAmount`; the successful bundle therefore has a maximum total of 600.
2. Clear six output slots to `(amount = 0, commodityID = -1)`.
3. Scan candidate IDs 1 through 9 in ascending order. `FUN_00555F70` admits
   exactly IDs 1 through 7 because `FUN_005DB4C0` accepts 1…9 and the helper
   rejects 8 and 9. For each admitted ID, the virtual `+0x264` inventory
   quantity must satisfy `perAmount <= inventory` (equality is accepted), and
   `FUN_00555F40` rejects IDs already written to the six-slot output.
4. Stop after `typeCount` unique IDs and write `perAmount` for each. If fewer
   than `typeCount` IDs qualify, return 0; otherwise return
   `perAmount * typeCount`. A positive request smaller than one 100-unit
   bucket therefore still writes the first eligible ID with amount 0; the
   caller's upstream positive-result guard is separate.

The pure `OriginalMillFoodBundleComposer.compose` helper in
`Sources/EmperorCore/FoodSimulation.swift` mirrors this bounded contract for
the caller-valid type-count range 1…5 and returns the selected ascending IDs,
per-ID amount, and total. It intentionally takes inventory as an explicit
input and is not wired into `LogisticsSimulation.takeFoodBundle`: the
receiver's virtual `+0x264` source, the output-array ownership, and the
mapping from these raw IDs to Native market/provider records remain
unrecovered. No `FoodQuality` conversion is implied.

The authored-data cross-check is deliberately negative:
`GameData/Model/Trade.txt` contains named trade rows (for example
`Cabbage=31`, `Meat=34`, `Millet=27`, `Rice=29`, `Wheat=28`, `Salt=40`, and
`Spices=70`), but no row maps those authored trade IDs to the writer's raw
candidate IDs 1…9. Those namespaces are therefore not merged by this helper.

**Evidence class:** **confirmed** for the 100-unit rounding, 600 cap,
six-slot initialization, candidate range 1…7, inclusive inventory test,
ascending unique selection, return values, caller cases 1…5, and EN/CH
identity. **Unknown** for the virtual inventory producer, upstream request
semantics outside the caller-valid range, provider/market settlement, and
Qin reachability; the Native helper remains research-only.

### 10.38 Ferry primary-cache post-pass primitive (`FUN_004C6D30`) (2026-08-30)

The Ferry branch identified in §10.9 is now represented by an explicit-input
pure helper, `OriginalGrandCanalLayoutCatalog.applyFerryPrimaryPostpass` in
`Sources/EmperorCore/GrandCanalSimulation.swift`. Given an already-derived
primary cache and exact map points supplied by a caller, it applies the
confirmed executable order: OR `0x800` over every Ferry footprint cell, then
OR `0x200` over every connector-chain cell. Existing bits are preserved, and
overlapping footprint/connector cells receive both masks. Invalid dimensions,
cache lengths, or out-of-bounds points return `nil` without producing a
partially modified cache.

This is deliberately a partial boundary, not live Ferry wiring. The
connector-chain discovery in `FUN_005B33C0`/`FUN_005B3670` still lacks the
per-direction byte-layer bases and rotation tie-break source recorded in §10.9;
`PlacedBuilding` has no recovered serialized connector-point state, and
`DeterministicCityState.grandCanalWorkerRoutingGrids()` therefore does not call
the helper. A placed Ferry continues to fail closed in the generic occupancy
branch until those inputs and the complete post-pass call site are recovered.

Focused tests cover mask order, overlap, base-cache immutability, and
out-of-bounds rejection. No new executable body hash is introduced here; the
mask/order evidence and canonical EN/CH hashes are the direct findings already
recorded in §10.9.

**Evidence class:** **confirmed** for the two OR masks, footprint-before-
connector order, and preservation of existing cache bits; **unknown** for
connector discovery, persisted connector state, Ferry placement integration,
and Qin reachability. The helper is research scaffolding and is not a gameplay
source of truth.

### 10.39 Ferry connector gradient walk (`FUN_005B3670`) (2026-08-30)

The static EN/CH-identical body of `FUN_005B3670 @ 0x5B3670` is now captured
as `OriginalGrandCanalLayoutCatalog.deriveFerryConnectorDirections`. With an
explicit flood grid and Ferry-perimeter start cell, the helper reproduces the
confirmed bounded walk: inspect N/E/S/W in that order, exclude the direction
stored in `local_4` (the immediate reverse of the previous step), admit a
nonzero flood value lower than the current value, or an equal value only when
the recovered orientation tie gate matches, move by the selected cardinal
delta, and store the opposite direction code (`0/2/4/6`). It stops at flood
`< 2`, rejects a zero-flood start or unavailable neighbour, and fails closed
after the original 500-step direction-buffer bound. The optional cell-orientation array models
the `param_6 == 1` branch (`DAT_00F1E780[cell] & 3`); mode `0` uses the global
orientation (`DAT_010C713C & 3`) for the tie comparison.

The helper does not synthesize the flood grid, choose the Ferry perimeter, or
persist the returned bytes. The flood producer and its PE layer addresses are
now closed statically (see §10.40), but their projection into Native map data,
the Ferry object's `+0x154/+0x924` save state, and the placement caller remain
unresolved. Consequently the live city projection still does not invoke this
helper or the post-pass; it only narrows the gradient-walk boundary for a
future source-backed integration.

**Evidence class:** **confirmed** for cardinal candidate order, immediate
reverse exclusion, lower/nonzero selection, optional orientation tie gate,
opposite direction encoding, and 500-step bound; **unknown** for PE-layer-to-
Native projection, perimeter
selection, serialized connector ownership, placement integration, and Qin
reachability.

### 10.40 Ferry placement flood boundary (`FUN_005B33C0`) (2026-08-30)

The EN/CH-identical `FUN_005B33C0 @ 0x5B33C0` body is now represented by the
explicit-input `deriveFerryPlacementFlood` primitive. It seeds the start cell
with flood value `1`, expands FIFO in N/E/S/W order, writes `current + 1`,
admits the start/endpoint cells regardless of their layer flags, and otherwise
requires a non-`-1` directional byte plus a clear terrain block bit. The
bounded 50,000-iteration behaviour and zero for unreached cells are preserved.
The four directional byte and terrain layers are passed as arrays in the
source's direction order; the east passability layer is indexed at the east
neighbour while the other three use the current cell, matching the decompiled
address arithmetic.

This closes the flood algorithm's data-independent control flow only. The
per-direction PE base addresses and `FUN_00521140` reset (zeroing `0xCB10`
dwords at `DAT_01391FE0`) are confirmed by direct disassembly, but their
projection into Native's map layers and the Ferry object's seed-coordinate
state are still not mapped to Native. The helper therefore does not construct
a live Ferry connector chain or alter `workerRoutingGrids`.

**Evidence class:** **confirmed** for seed/endpoint exceptions, FIFO cardinal
expansion, directional pass checks, flood increment, reset size, and iteration
bound; **unknown** for PE-layer-to-map projection, seed-coordinate ownership,
placement call path, serialized connector ownership, and Qin reachability.
The helper is research scaffolding, not a gameplay source of truth.

### 10.41 Ferry computation call gates (`FUN_004C6C70`) (2026-09-01 direct EN/CH binary cross-check)

Direct disassembly of the canonical English (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`)
and Chinese (`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`)
builds at the Ferry vtable `+0x04` body `0x4C6C70` closes
the sequencing around the two recovered pure primitives. The method first
asks the Ferry object vtable `+0x278` for its coordinate pair and returns
false on failure; it then requires the object's `+0x150` positive gate and
asks the global map object at `0x8C7634` for the second coordinate pair. Only
after both coordinate lookups succeed does it call `FUN_005B33C0`, call
`FUN_005B3670` with output buffer `ferry + 0x154` and selector `0x3E9`, and
store the returned direction count at `ferry + 0x924`. The return value is
nonzero exactly when that count is nonzero. The generated corpus has no
`compare-report.tsv` row for this address; the direct EN/CH disassemblies
listed above are byte-identical.

Direct EN/CH disassembly of the adjacent `+0x08` post-pass at `0x4C6D30`
also confirms that the canonical map row stride is `0xE4` (228): the object
origin is read as signed words at `+0x0A/+0x0C`, converted to
`base + x + 228*y`, and the 6×6 table at `DAT_0081FF18` is consumed as
36 eight-byte entries. Its first dword offsets are the row-major sequence
`0,1,2,3,4,5; 228,229,…,233; 456,457,…,461`; the second dwords are the
paired `0…5, 8…13, 16…21` values. The loop ORs `0x800` into each footprint
cell, then computes the connector-pass map base from the same global map
base/origin arithmetic and iterates `+0x924` connector dwords. Each connector iteration ORs `0x200` into the
current cell, accepts only direction codes `0,2,4,6`, and advances by
`−228,+1,+228,−1` respectively; negative or out-of-range codes terminate
the pass. The EN and CH instruction bytes are identical at both functions.

This identifies the placement/update call gate but not the Native source of
the two coordinate pairs, the meaning of `+0x150`, or the object registry that
backs the global map lookup. Those state and serialization mappings remain
unknown, so Native still does not invoke the call chain for live Ferries.

**Evidence class:** **confirmed** for call order, positive `+0x150` gate,
`+0x154/+0x924` ownership, and return condition; **unknown** for coordinate
semantics, object-registry projection, placement scheduling, and Qin
reachability.

### 10.42 Immigrant assignment uses remaining capacity (`FUN_004ADA10`) (2026-08-31)

The canonical English build (`8a6d2df1…6753`) and Chinese cross-check
(`dbdeca1e…15a`) both expose the same `FUN_004ADA10 @ 0x4ADA10` three-pass
house walk. Its predicates read `house+0x20` as current residents and
`house+0x22` as **remaining capacity**: pass 1 requires `+0x20 == 0` and
`+0x22 != 0`, pass 2 requires `+0x22 > 11`, and pass 3 requires `+0x22 > 0`.
The arrival writer at `0x4CA265` confirms the field relationship by storing
`house+0x22 = capacity - house+0x20` after each occupancy update. Each pass
caps a spawned batch at six people, while pass 3 caps it at the remaining
`+0x22` value. The function's direct callee is `FUN_004ADE10`, which may fail
to create a figure; the caller still decrements its local request around each
call and later accounts `param_1 - i`.

Native previously compared the authored total model capacity in all three
passes, allowing an occupied house to be selected as though it had its full
capacity. The implementation now derives `max(0, modelCapacity - residents)`
for each pass, preserving the source predicates and the six-person caps. When
the recovered `cHouseInfo+0x3C` settling lock is set, Native exposes the same
effective zero remaining capacity as `FUN_004AD3D0`'s locked branch. A fixture
with one resident slot free now produces exactly one immigrant walker, not the
full request.

**Evidence class:** **confirmed** for the field predicates, capacity
relationship, settling-lock branch, pass ordering, and batch bounds; **unknown**
for the full `house+0x24` flood predicate and the figure-spawn success side
effects, which remain outside this correction.

### 10.42a Vacant elite assignment capacity (`FUN_004AD3D0`) (2026-09-02)

The EN and CH `FUN_004AD3D0 @ 0x4AD3D0` bodies are identical in
`local/source/compare-report.tsv`. After clearing `house+0x22`, the callback
only computes a capacity for houses whose refreshed `house+0x24` is positive.
It resolves the house-level index from `house+0x16`, except when the original
building-type short at `house+0x14` is `11` (Unoccupied Elite): in that branch
the index is incremented by one before the authored capacity lookup. The
result is clamped by `FUN_0044CC80(..., 0x11)`, then `house+0x22` is written as
capacity minus current occupancy. This is the capacity field consumed by all
three `FUN_004ADA10` assignment passes (§10.42).

`GameData/Model/EmperorBuildingModels.txt` confirms the corresponding Native
house rows: level `8` (`Elite: Unoccupied`) has capacity `0`, while level `9`
(`Elite 0: Abandoned`) has capacity `1`; first arrival later switches the
vacant building from original model `11` to `13`, represented by Native level
`10` (§5.10). Therefore an unoccupied elite can still be selected by pass 1:
its pre-arrival assignment capacity is the next-level value, while the arrival
writer performs the type switch before adding occupants.

Native now exposes this arithmetic as
`DeterministicMigration.assignmentRemainingCapacity` and uses it in the
research/fixture assignment adapter. Settling-lock state still forces zero,
matching the locked `FUN_004AD3D0` branch. This closes the vacant-elite
capacity projection only; the `house+0x24` refresh/registry mapping and the
complete original popularity producer remain unknown, so automatic Qin
migration stays fail-closed.

**Evidence class:** **confirmed** for the EN/CH branch, source offsets,
capacity-index increment, authored capacities, and Native helper/test;
**unknown** for the unresolved `house+0x24` source and full live producer.

### 10.43 Assigned-count month rollover (`FUN_004AC650`) (2026-08-31)

`FUN_004AC650 @ 0x4AC650` increments the executable's calendar slice and, on
the 16th-slice wrap, stores `DAT_01311FCC` into `DAT_01312604` before clearing
`DAT_01311FCC`. `FUN_0053B850` reads `DAT_01311FCC` for the current
assigned/accounted arrival display; no Native field currently represents the
history slot `DAT_01312604`. Therefore Native's `assignedThisMonth` is kept as
the current-month counter and is reset by `DeterministicMigrationState.finishMonth()`.
`assignedToday` is intentionally not reset there: the daily
`FUN_004AD4A0 @ 0x4AD4A0` pass resets `DAT_01311FB0` before assignment, matching
the existing Native daily boundary.

**Evidence class:** **confirmed** for the current-counter clear and history
copy; **unknown** for any player-facing consumer of `DAT_01312604`, which
remains unrepresented and therefore is not synthesized.

### 10.44 Assignment walk preserves house-vector order (`FUN_004ADA10`) (2026-08-31)

`FUN_004F8210 @ 0x4F8210` and `FUN_004F8200 @ 0x4F8200` are trivial vector
begin/end accessors. `FUN_004ADA10 @ 0x4ADA10` obtains that begin pointer for
each of its three passes and advances the pointer by one house record; no
comparison or sort by object ID occurs. The source therefore preserves the
runtime house-vector order across pass 1 (vacant), pass 2 (remaining capacity
`> 11`), and pass 3 (remaining capacity `> 0`).

Native had sorted `houses` by `id` in these passes. It now walks the persisted
array order directly, matching the source vector traversal and avoiding an
unsupported assumption that registry/object IDs define assignment order.
The separate loader/test-fixture `admitResidents` helper remains unchanged.

**Evidence class:** **confirmed** for vector-boundary access and unsorted pass
order in EN/CH (`compare-report.tsv` marks the three functions `identical`);
the relationship between serialized registry order and Native array order is
still **unknown** for legacy saves, so no registry reordering is synthesized.

### 10.45 Market-quality zeroing is tied to Dinners depletion (`FUN_00544B30`) (2026-08-31)

The split corpus contains the complete `FUN_00544B30 @ 0x544B30` body, and
`local/source/compare-report.tsv` marks its EN/CH pair `identical`. The method
does not clear `cMarket+0x180` on every market tick. Its recovered sequence is:

1. Return when the market state byte is `2` or `6`, when the selected market
   record pointer (`param_2+0x158`) is null, or when its selected record index
   (`param_2+0x150`) is negative.
2. Select that record through the market `+0x2D8` callback, deduct `800` from
   the indexed non-elite table entry or `400` from the elite entry, clamp the
   entry at zero, and clear the market-side state byte (`param_2+4`).
3. Recreate the transient type `0x3E` object at the market coordinates and
   attach its registry index to the market slot. This is the replacement
   object path, not a food-quality writer.
4. Call `FUN_00544340(0x1C)`, which scans six market records and counts active
   records whose internal commodity key equals `0x1C` (Dinners). Only when
   that count is zero does the method call `FUN_00545140(0)`, storing zero in
   `cMarket+0x180`.

The direct callee `FUN_00544340 @ 0x544340` is also present in the split corpus
and its body confirms the six-record bound, the active-record vtable `+0xC8`
predicate, and exact key comparison. This closes the **zeroing trigger**:
quality is reset as a consequence of the selected-market replacement path
when no Dinners provider record remains. It does not close the market-quality
producer set: the mill/stall weighted blend, hero write, constructor reset,
and normal residential-delivery consumer remain separate recovered edges, and
the provider-record-to-Native inventory mapping is still unknown. Native must
therefore not synthesize a reset from generic market inventory exhaustion.

**Evidence class:** **confirmed** for the EN/CH-identical call sequence,
state/record guards, `400/800` deductions and clamp, replacement-object
creation, six-record Dinners count, and conditional `+0x180 = 0` store;
**unknown** for the semantic owner of the selected record, the complete
market replacement schedule, and Native provider-record mapping.

### 10.46 Monthly household depletion preserves runtime house-vector order (`FUN_00518690`) (2026-08-31)

The split corpus contains `FUN_00518690 @ 0x518690`; its EN/CH comparison row
is `identical`. After the month-wrap caller has prepared the house vector, the
function obtains the vector begin pointer with `FUN_004F8210 @ 0x4F8210`, reads
the element count from `FUN_00554C00 @ 0x554C00`, and advances the pointer by
one record until that count is exhausted. The body performs no comparison,
sort, or lookup by the house object's `+0xB4` registry ID. Each occupied house
is therefore consumed in the persisted runtime-vector order; the same pass
updates that house's Dinners word, raw quality byte, and the aggregate
`DAT_0131252C` counter.

This is distinct from the recovered immigrant-assignment walk (§10.44), but
the ordering contract is the same: vector position is the only recovered
iteration key. Native's `consumeHouseholdCommodities` previously sorted its
indices by `ResidentialUnit.id`; that ordering was not supported by the
executable and could change the serialized consumption record sequence. The
implementation now walks `houses.indices` directly. The public
`underSuppliedHouseIDs` summary remains explicitly sorted because it is a
set-like presentation field, not the executable's per-house mutation order.

**Evidence class:** **confirmed** for vector begin/count access, one-record
advancement, and absence of ID sorting in EN/CH; **unknown** for the
serialized-registry-to-Native-array ordering of legacy saves, so no additional
reordering is synthesized.

### 10.47 cMarket provider-record allocation and producer boundary (2026-09-01)

The market constructor and its provider-record callbacks close the storage
shape, but not the producer mapping needed by Qin market settlement. The
canonical English build (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`)
and Chinese cross-check (`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`)
are byte-identical at the direct bodies listed below.

#### Constructor and record shape

`FUN_00543450 @ 0x543450` is the cMarket constructor. Its provider-container
field is `market+0x150` and its record-array field is `market+0x154`:

1. `FUN_00543600 @ 0x543600` constructs the provider container and installs
   vtable `0x7B7228`.
2. The container's first virtual method is `0x4E1BF0`, which returns **6**.
   This is the record count used by the constructor; it is not a runtime
   count inferred from Native buildings.
3. The constructor allocates `count * 0x10 + 4` bytes, stores the count in the
   leading dword, and stores `header + 4` in `market+0x154`.
4. `FUN_00765629` initializes each of the six 16-byte records with callback
   `FUN_00543680 @ 0x543680`, then calls `FUN_004C1550(0)` once per record.

Direct disassembly of `FUN_00543680` is only `push 0x190; call 0x5D2690; ret`.
`FUN_005D2690 @ 0x5D2690` installs record vtable `0x7BDBB4`, zeroes `record+4`
and `record+8`, and writes **400** to `record+0x0C`. Its serializer
`FUN_005D26C0 @ 0x5D26C0` reads/writes exactly those three fields. Therefore
the constructor's initial state is six records with `(rawField4, rawField8,
capacity) = (0, 0, 400)`; no commodity key or inventory quantity is authored
by this callback.

The cMarket accessors are also now closed directly:

* `FUN_00546BE0 @ 0x546BE0` (`+0x2CC`) dispatches the provider-container first
  virtual method and returns zero only when `market+0x150` is null.
* `FUN_00546C40 @ 0x546C40` (`+0x2D8`) returns
  `market+0x154 + index * 0x10`.
* `FUN_005D4A60 @ 0x5D4A60` (`+0x264`) sums `record+8` for records whose
  `record+4` equals the requested key.
* `FUN_005D4AC0 @ 0x5D4AC0` (`+0x268`) sums `record+8` for every nonempty
  record, where emptiness is exactly `(record+4 == 0 && record+8 == 0)`.

#### cMarket refill writer and placement-time key writer

The cMarket vtable `+0x154` body at `0x543BC0` is the market-side allocator.
After its state/gate checks, it walks the six records through `+0x2CC/+0x2D8`,
selects a record matching the requested key with positive free capacity
(`record+0x0C - record+8`), and calls `FUN_005D2790 @ 0x5D2790` with that key
and one-unit increments until the requested amount or the available free
capacity is exhausted. `FUN_005D2790` writes `record+4 = key`, adds to
`record+8`, clamps at `record+0x0C`, and returns overflow. The sibling
`FUN_005D2760 @ 0x5D2760` subtracts quantity and clears the key only when the
quantity reaches zero and its caller requests key clearing.

This refill writer is reached from `FUN_005D2C10 @ 0x5D2C10`, which iterates an
external provider/building vector and calls each provider object's vtable
`+0x154` with `(commodity, amount)`. The recovered callers include the
plunder paths (`FUN_00496CA0`/`Spoils_acquired_from_pctd_of_pctd`) and the
generic “Adding plunder” path; those callers do not identify the Qin market
provider population. The authored cMarket record key namespace for placed
market shops is closed by the separate placement path in §10.64; the cStall
cart quantity path is closed in §10.63, while monthly/external quantity
population and overflow routing remain separate questions.

`FUN_00540E70 @ 0x540E70` is the specialized placement/update path reached by
`FUN_004B1250` after `FUN_005418D0` admits model IDs `0x3E` and `0x40…0x46`.
It calls `FUN_00540F80 @ 0x540F80` for the new shop object. The latter resolves
the parent cMarket with `FUN_00490700`, obtains the selected record through
parent `+0x2D8(object+0x150)`, sets `ecx` to that record, and calls
`FUN_0053C700(record, tableRow+0x0C)`. `FUN_0053C700` writes
`record+4 = tableRow+0x0C`, i.e. the exact commodity key from the
`DAT_008572E8` row. It then calls `FUN_004C1550(record, 400)` when the row's
`+0x18` flag is non-zero, otherwise `FUN_004C1550(record, 800)`; the same
capacity is added to the model-data short at `model+0x38+key*2`.

The direct EN/CH `FUN_00540F80` body range `0x540F80…0x541027` is 168 bytes
with SHA-256
`9a310fc4eca16dd844da2efcf598fcd4202b2efbd6e0777cbb0302a862fc7abe` in both
canonical executables; the comparison report marks `FUN_00540E70` and
`FUN_00540F80` `identical`. This is the confirmed runtime writer for record
key, slot ownership, and placement capacity. It does not populate quantity
`record+8`, and it only runs when the object's `+0xC8(-1)` gate passes.

**Evidence class:** **confirmed** for the six-record count, 16-byte stride,
`400` capacity initialization, zero key/quantity constructor state, accessor
addresses, empty predicate, the cMarket refill arithmetic, and the separate
placement-time key/capacity writer in EN/CH; **unknown** for the external
provider vector's Qin quantity population, quality side effects, and the
Native projection. This sharpens but does not remove the market-peddler and
market-settlement blocker. Native must not synthesize provider quantities from
`MarketSquare.inventory` or enable campaign market settlement from this
allocation evidence alone.

### 10.48 Monthly Dinners refill caller (`FUN_004AEDF0`) (2026-09-01)

The previously unresolved external writer caller is narrowed by the complete
EN/CH-identical `FUN_004AEDF0 @ 0x4AEDF0` body (the comparison report marks the
pair `identical`). This is a calendar-side refill pass, not an inventory
projection that Native may freely substitute:

1. `FUN_00413B40(1)` returns the global live-object vector begin pointer plus
   one element. `FUN_00554C00` supplies the vector count; the loop visits
   indices `1 .. count-1` in persisted vector order.
2. For each object, the executable first requires the global simulation gate
   `FUN_00426D10(0)`, then the object's vtable `+0xC8` predicate with argument
   `-3`, and then global flag `DAT_00C5CDA0 != 0`.
3. Only when all three gates pass does it dispatch that object's vtable
   `+0x154` with `(commodity = 0x1C, amount = 200)`. The dispatched method is
   the cMarket/provider writer boundary described in §10.47; the caller does
   not write `record+4/+8` itself.
4. The pass then invokes `FUN_00591490`, which separately scans the same live
   vector for active objects and aggregates their provider/house statistics.

This closes the monthly call site and its exact Dinners request, but not the
identity of objects that satisfy `+0xC8(-3)`, the implementation of their
`+0x154` methods, or the association between those objects and a specific
market's six records. The plunder callers in §10.47 are therefore not the
only callers; they are simply separate callers with explicit resource
arguments. No Qin-specific serialized provider list or market ownership edge
was recovered from this pass.

**Evidence class:** **confirmed** for vector start/count/order, gate order,
commodity `0x1C`, amount `200`, and dispatch to vtable `+0x154` in EN/CH;
**unknown** for the provider object class predicate, market association,
record-key namespace beyond the literal Dinners request, and Native projection.
This provides a precise next tracing target but does not authorize enabling
Qin market settlement or inventing a Dinners refill rule in Native.

### 10.49 Market shop/provider table (`DAT_008572E8`) (2026-09-01)

The PE data table read by `FUN_005416C0 @ 0x5416C0` contains seven rows with a
`0x40`-byte stride. The first words of each row give the static table ordinal
and shop model ID; the fourth word is the commodity/resource key. The ordinal
is used as a shop-type/selection index, not as a permanently allocated cMarket
runtime-record slot (the latter is assigned dynamically by `FUN_005428B0`, see
§10.65). Reading the rows in table order yields this exact projection:

| table row index | shop model ID | commodity key |
| ---: | ---: | ---: |
| 0 | `66` Food Shop | `0x1C` Dinners |
| 1 | `67` Hemp Shop | `0x13` Hemp |
| 2 | `70` Tea Shop | `0x0D` Tea |
| 3 | `65` Ceramics Shop | `0x19` Ceramics |
| 4 | `64` Bronzeware Shop | `0x17` Bronzeware |
| 5 | `68` Lacquerware Shop | `0x16` Lacquerware |
| 6 | `69` Silk Shop | `0x18` Silk |

`GameData/Model/EmperorBuildingModels.txt` rows 148–154 independently names
the same seven model IDs (64…70). The recovered table therefore closes the
shop-ID, commodity-key, and static table-row identity without relying on sheet
order or visual appearance. Native now exposes this as
`OriginalMarketProviderSlotCatalog`; the catalog is research-only and does not
populate `MarketSquare.inventoryByCommodityID` or enable Qin market
settlement. The existing `OriginalMarketCatalog.commodityID` intentionally
omits Food Shop `66`, because Native's food/mill quality path is a separate
system; the new catalog preserves the executable's complete seven-row table
and exposes each row's confirmed `placementCapacity` (`800` for Food Shop 66,
`400` for the other six rows) as a pure data field.
The cMarket constructor separately reports six maximum provider records, while
the market-type helpers expose four active Common-market bays and six active
Grand-market bays. The seven table rows are therefore selectable shop types,
not seven fixed runtime records; the dynamic allocation evidence is recorded
in §10.65. Native must not add a seventh provider record from this table.

**Evidence class:** **confirmed** for all seven row identities and order in the
hash-matched EN/CH PE table, corroborated by authored building-model names,
and for the placement-time assignment of a selected row's key/capacity to a
cMarket record (see §10.50/§10.64); **unknown** for the selected-row to active
layout-entry mapping and for the provider object's serialized quantity/quality
lifecycle. No Qin gameplay wiring is authorized by this table alone.

### 10.50 Shop placement setup and remaining quantity/owner edge (2026-09-01)

The placement path provides a second, independent use of the shop IDs but does
not close the market-owner boundary. `FUN_004B1250 @ 0x4B1250` calls
`FUN_005418D0 @ 0x5418D0`; that predicate is true only for model IDs
`-2, -1, 0x3E, 0x40…0x46` (the seven authored shops are `0x40…0x46`, IDs
64…70). For those models it calls `FUN_00540E70 @ 0x540E70` instead of the
generic building constructor.

Inside `FUN_00540E70`, the `0x3E` selected-object branch writes the new object's
`+0x154` to the current market object's `+0xB4` ID, stores the selected market
slot at object `+0x150`, mirrors the object ID into `market+0x15C[slot]`, and
then calls `FUN_00540F80`. `FUN_00540F80` resolves the market record through
`market+0x2D8(slot)`, checks the object's vtable `+0xC8(-1)`, calls
`FUN_0053C700(record, tableRow+0x0C)` to set `record+4` to the row's commodity
key, and sets the record capacity through `FUN_004C1550` to `400` when helper
`+0x18` is nonzero, otherwise `800`. The same capacity is added to the
model-data short at `base+0x38+commodity*2`. These writes corroborate the
seven-row shop/provider table in §10.49 and close the placement-time
selected-row-to-record key/capacity writes. The object `+0x150` value at this
stage is a runtime record slot supplied by the market-layout allocator; it
must not be read back as the static `DAT_008572E8` row ordinal.

The call graph contains no other caller of `FUN_00540F80`. This setup path does
not identify the external provider vector consumed by
`FUN_005D2C10`/`FUN_004AEDF0`, does not serialize the provider record's
monthly/external quantity,
and does not identify the downstream quality/coverage consumer. The market
instance and selected-slot association are confirmed for placed shops;
cart-deposit quantity is confirmed through cStall `+0x260`, while
monthly/external provider population remains unresolved for Qin.

**Evidence class:** **confirmed** for the placement predicate, object/market
field writes, slot lookup, record-key write, and 400/800 capacity side effect
in EN/CH-identical functions; **unknown** for the provider vector's object
class, monthly/external quantity lifecycle, quality/coverage consumers, and
Native ownership projection. This narrows the blocker but does not authorize live market
settlement or monthly Dinners refill wiring.

### 10.51 Shop-to-source buyer selection (`FUN_00540770` → `FUN_00541220`) (2026-09-01)

The seven authored shop objects have a distinct construction/update family.
`FUN_005418D0 @ 0x5418D0` admits model IDs `0x40…0x46` (64…70), and the
specialized allocator `FUN_00540770 @ 0x540770` installs vtable
`0x7B6C5C`, allocates one 16-byte provider record with capacity `400`, and
stores `FUN_005416C0(shopModelID)` at object `+0x158`. The table pointer's
`+0x10` word is the seven-row static table/selection index recorded in §10.49.
It is separate from the compact runtime provider-record slot assigned by the
market helper during placement.

The vtable `+0x20` update `FUN_00541B80 @ 0x541B80` gates and dispatches
`FUN_00540B40 @ 0x540B40`. Its EN/CH bodies are `identical` in
`local/source/compare-report.tsv`. After the workforce/cadence and market
state gates, `FUN_00540B40` calls `FUN_00541220 @ 0x541220` with the shop's
slot-specific scratch arrays. The candidate scan starts at the active live
object vector `FUN_00413A50(1)` and preserves vector order. Each active
candidate is checked through the provider vtable rather than read as a Native
inventory value.

The scan has two source families:

* For a candidate accepted by vtable `+0xC8(0x35)`, the shop must be in helper
  mode `+0x18 == 0`; candidate `+0x48` and positive `+0x24` gates must pass,
  the candidate and shop must share the `+0x1A8` grouping value, and their
  Manhattan distance must be `< 40`. The candidate's vtable `+0x2DC` must
  report usable stock. Its object handle, `+0xB4` identity, and map origin
  are copied into arrays indexed by the shop's static table/selection index.
* The alternate family is selected by `FUN_005D61C0(candidateModelID)`, which
  is true only for model IDs `54`, `56`, and `58` (warehouse/trade sources).
  It requires helper mode `+0x18 == 1`, candidate `+0x48` and `+0x24 > 0`,
  distance `< 40`, and vtable `+0xC8(0x36)`. The commodity key is the exact
  `FUN_004475A0(slotIndex)` table (`0→0x1C`, `1→0x13`, `2→0x19`,
  `3→0x18`, `4→0x17`, `5→0x16`, `6→0x0D`); the scan additionally checks the
  global per-key reservation table, provider quantity, and the model-data
  exemption bytes before accepting the candidate.

After collection, `FUN_00541220` chooses the accepted candidate with the
smallest positive `DAT_01391FE0[mapCell]` distance (strict `<`, first tie),
then `FUN_00540B40` creates the original Marketplace Buyer model `0x18`
through `FUN_004EA050`, stores the selected source identity at figure `+0x68`,
and copies the selected map origin into the buyer target fields. The source
object is therefore selected by a provider vtable/route-cache contract, not
by a direct `MarketSquare.inventoryByCommodityID` lookup.

This closes the shop update's source-family split, exact slot-to-commodity
table, candidate gates, stable tie order, and shop→buyer/source identity
handoff. It does **not** recover the provider vtable `+0x2DC` stock semantics,
the raw `+0x4/+0x8` record writer, the route-cache projection to Native, or
the cMarket quality/house writer. Those remain **unknown**; Native must not
replace this path with a warehouse-distance or inventory shortcut when
enabling Qin market settlement.

**Evidence class:** **confirmed** for the constructor/vtable family, source
model filters, literal thresholds/masks, `FUN_004475A0` mapping, candidate
ordering/selection, and model-24 handoff in hash-matched EN/CH code;
**unknown** for provider stock/quality lifecycle and Native projection.

### 10.52 Storage-source stock predicate (`+0x2DC` → `FUN_005D5C70`) (2026-09-01)

The provider-stock call used by the alternate branch in §10.51 can now be
resolved for all three accepted storage/trade models. `FUN_005D3580 @ 0x5D3580`
dispatches model `54` to `FUN_005D61E0 @ 0x5D61E0`, models `56/58` through
`FUN_005DDB10 @ 0x5DDB10` to `FUN_005E1730 @ 0x5E1730` / `FUN_005E1420 @
0x5E1420`; their constructors install vtables `0x7BE1BC`, `0x7BEDC4`, and
`0x7BEAB8` respectively. Direct PE table reads show that all three vtables
share the same `+0x2DC` target, `FUN_005D5C70 @ 0x5D5C70` (the comparison report
marks this function `identical` for EN/CH).

`FUN_005D5C70` obtains the receiver's slot count through `+0x2CC`, selects the
first slot with `+0x2D8(0)`, and scans the contiguous records in slot order:

* `FUN_004B04F0` returns true only when both raw fields `+0x4` (internal key)
  and `+0x8` (quantity) are zero. Seeing any such empty record immediately
  classifies the source as return `0` (`hasEmptyRecord`).
* Otherwise it sums every non-empty record's raw `+0x8` quantity. A total above
  `0xC7F` (3199), i.e. at least `3200`, returns `1`
  (`meetsQuantityThreshold`); a non-empty total below that returns `2`
  (`belowQuantityThreshold`). An empty container also returns `2` because its
  quantity sum never crosses the threshold.

This is the exact predicate consumed by `FUN_00541220` before a model-54/56/58
source is admitted to a shop's candidate set. It is not a direct
`MarketSquare.inventoryByCommodityID` lookup: the key field is only tested for
all-zero status here, while the requested commodity-key equality and quantity
checks happen in the separate `+0x264/+0x298` branch. Native's
`OriginalMarketProviderFillState.classify` mirrors this record-level return
code, but no Qin market settlement or provider registration is enabled from it.

**Evidence class:** **confirmed** for model-to-vtable dispatch, shared
`+0x2DC` target, empty-slot predicate, slot order, `0xC7F` literal, and return
codes in hash-matched EN/CH; **unknown** for how the storage records are
populated from Qin archives, how `+0x264/+0x298` expose a requested commodity,
and how the selected source is projected into Native routes/coverage.

### 10.53 cMarket candidate score preparation (`+0x26C` → `0x5D4B10`) (2026-09-01)

The cMarket vtable `0x7B6F3C` entry `+0x26C` targets `0x5D4B10`. The indexed
split corpus has no standalone file for this address, so the body was checked
directly in both hash-matched PE inputs. The EN and CH ranges
`0x5D4B10…0x5D4CEF` are byte-identical (length `0x1E0`, SHA-256
`324b9418226bbb9ed6d16b7be8dd3200f2f97c607c06ead6047e324f7a25fec2`). The
function is reached by generic figure/status callers such as
`FUN_005F1F20`, `FUN_005F14D0`, `FUN_005F13E0`, and `FUN_0058C420`; those
callers consume the returned count/threshold but do not identify a player-facing
market-quality label.

For each candidate resource index returned by cMarket `+0x274`, the function
initializes a local score to `100`. It replaces that score only when all of the
following literal gates pass:

1. the resource-state byte at `FUN_00413AD0(buildingID) + index + 0x0E` is `2`;
2. cMarket `+0x25C(index)` returns nonzero;
3. cMarket `+0x264(index)` (the matching-record quantity sum from §10.47) is
   strictly below the authored capacity word at `base + 0x38 + index*2`;
4. `index > 0`.

When the gates pass, the score is the signed integer quotient
`quantity * 100 / capacity`; the executable computes the multiply by `100`
before `idiv`, so fractional percentages are truncated toward zero. A
zero-index candidate remains at `100` even when the other gates pass. The
function then forwards the candidate points and these scores to
`FUN_005D3730`; that downstream selector and the meaning of the candidate
resource-state table remain unresolved.

The pure `OriginalMarketProviderSelectionScore.score` helper records only this
per-entry arithmetic and gate order. It returns `nil` for a zero capacity to
make the executable's undefined divide-by-zero input explicit; authored tables
are expected to avoid that state. This is **confirmed** for the score
calculation, state/capacity offsets, strict comparisons, and EN/CH identity;
**unknown** for the semantic resource/quality label, the `+0x274` candidate
domain, the `FUN_005D3730` ordering policy, and any projection to Native market
coverage or settlement. No Qin runtime path is enabled from this primitive.

### 10.54 cMarket key-availability gate (`+0x25C` → `0x5D4900`) (2026-09-01)

The indexed EN/CH function files for `FUN_005D4900 @ 0x5D4900` are identical;
`local/source/compare-report.tsv` records the address as `identical`. The
function is the cMarket vtable `+0x25C` entry used by the score-preparation
path in §10.53. Before evaluating the gate it resolves the building-data base
(`FUN_00506240` → `FUN_00413AD0`), obtains the provider-record count from
`+0x2CC`, selects the contiguous record array through `+0x2D8(0)`, and counts
records for which `FUN_004B04F0` reports non-empty status. It then reads the
matching quantity from cMarket `+0x264(index)` and the signed capacity word at
`base + 0x38 + index*2`.

The return is `1` exactly when both conditions hold:

1. the matching quantity is not divisible by `400`, or at least one provider
   record is empty; and
2. the matching quantity is strictly below the signed capacity word.

Otherwise it returns `0`. The literal `400` is the executable's `idiv`
remainder test; no Native unit conversion is implied. The pure
`OriginalMarketProviderKeyAvailability.isAvailable` helper records this
boolean gate with caller-supplied raw values. It intentionally does not create
provider records, resolve the internal commodity key, or enable Qin market
settlement.

**Evidence class:** **confirmed** for the vtable slot, call sequence, empty
record count, `400` divisibility test, strict capacity comparison, and EN/CH
identity (hash-matched `8a6d2df1…6753` / `dbdeca1e…15a`); **unknown** for the
provider-record population source, the meaning of the internal key and
capacity table in Native, and the downstream route/coverage projection.

### 10.55 cMarket peddler endpoint arbitration (`FUN_004BA580` → `0x4BA370`) (2026-09-01)

The EN/CH split rows for `FUN_004BA580 @ 0x4BA580` and
`FUN_004BA370 @ 0x4BA370` are both `identical` in
`local/source/compare-report.tsv`. `FUN_004BA580` retries the rectangular
endpoint scan with rotation values `0…2`; each attempt delegates to
`FUN_004BA370` and returns on the first success. The scan clamps its rectangle
to the map bounds and lets a nonzero tile object adjust the candidate through
vtable `+0xD0`. The return value of that callback is not tested by this
function; a `-1` return is therefore not, by itself, an admission rejection
(the neighboring `FUN_004BAF40` has a separate return-value gate).

For each remaining cell, the executable requires low terrain flags
`(word & 0x44) == 0x40`. It looks up the cell's auxiliary component label in
the twelve `(label,size)` pairs at `DAT_01312588`; an absent label uses the
sentinel rank `11`. The scan keeps the strict lowest rank, so the first cell
in scan order wins equal ranks. A rank below `12` writes the selected map
coordinates to `DAT_010C72AC/DAT_010C72A8`; no ranked cell returns failure.
The cMarket object override (`FUN_00544E70`, vtable `+0x194`) may replace the
object-adjusted point with its nearest helper record, but that helper record
population remains a separate unknown.

`OriginalMarketPeddlerEndpointCandidate` and
`OriginalMarketPeddlerEndpointSelection.select` now preserve this arbitration
as a side-effect-free helper. The input is intentionally an already ordered
scan: map-cache projection, component-label generation, cMarket `+0x194`
records, route-buffer construction, collision, and coverage/quality writes
are not synthesized. **Evidence class:** **confirmed** for retry order,
the post-adjustment terrain gate, rank sentinel, strict tie policy, and EN/CH
identity;
**unknown** for the map-cache-to-Native projection and all downstream peddler
state/settlement semantics. Qin campaign scheduling remains fail-closed.

### 10.55a cMarket helper entrance records are fixed two-entry banks (2026-09-02)

The helper-record population used by the cMarket `+0x194` nearest reducer is
now closed at the static-data boundary. `FUN_00542350 @ 0x542350` calls the
helper vtable `+0x6C` for its record count and `+0x70(bank,index)` for each
record. The Common helper vtable `0x7AB800` maps `+0x6C` to
`FUN_004FA3C0 @ 0x4FA3C0` (constant count `2`) and `+0x70` to
`FUN_0042CD30 @ 0x42CD30`; the Grand helper vtable `0x7AB878` uses the same
count method and `FUN_0042CDD0 @ 0x42CDD0` for `+0x70`. The two accessor
bodies and the count body are byte-identical in the EN and CH PE inputs; the
accessor slices hash to `97092707e1b9b9664b010ce65b84371bcc5d2a51a21d06379cacf07b50a134c3`
and `d090fdc8bfeee9054c1fa10cc7ad71ecd05f041cf378bd9e16ea63024128ce07`,
and the count slice hashes to
`7140f35dee6220b79b12aecc27acf5105bf3b77d1588e89fce345de7c16c72b7`.

Each accessor computes `tableBase + 8 * (index + 2 * bank)` from the supplied
orientation bank (`0` or `1`). The fixed tables are at `0x857D88` (Common)
and `0x857D68` (Grand), with two signed `(dx,dy)` pairs per bank:

| market | bank `0` | bank `1` | PE table slice |
| --- | --- | --- | --- |
| Common Market (`59`) | `(0,3),(3,3)` | `(3,0),(3,3)` | `0x857D88`, 32 bytes |
| Grand Market (`60`) | `(0,3),(5,3)` | `(3,0),(3,5)` | `0x857D68`, 32 bytes |

The 32-byte EN/CH slices are identical (Common SHA-256
`d30411529de1f1b91f3884514006c0279a94fa5a386685f55a71e0ac79ea15bf`, Grand
SHA-256 `b8f2ebd52dfd5e5d24e1b04d41fc78bc19dc513d9c1c0a51e4a5d7a1459df2f8`).
`FUN_00542350` compares Manhattan distances to the supplied target, keeps a
strictly lower distance (stored-order ties), and returns the original target
only when the helper reports no records. Native now records these four exact
banks in `OriginalMarketPeddlerHelperRecordCatalog` with a pure nearest-point
helper and regression tests. This closes the helper-table input; helper
instance construction, map-cache projection, route/collision state, and
coverage/settlement writers remain unknown, so Qin campaign scheduling stays
fail-closed.

**Evidence class:** **confirmed** for the two-entry count, accessor formulas,
table addresses/values, strict Manhattan reduction, and EN/CH identity;
**unknown** for the runtime helper registry/instance lifecycle and all
downstream peddler route and market-provider semantics.

### 10.56 cMarket access/flood refresh projection (`FUN_00543DC0 @ 0x543DC0`) (2026-09-01)

The indexed EN/CH rows for `FUN_00543DC0 @ 0x543DC0` are byte-identical in
`local/source/compare-report.tsv` for the hash-matched English build
(`8a6d2df1…6753`) and Chinese build (`dbdeca1e…15a`). The function is reached
from the cMarket/building refresh path after the receiver's vtable `+0x194`
has selected a linear map cell. Its direct callees are the receiver callback at
`+0x194` (cell selection) and then the receiver callback at `+0x1AC` (opaque
cell/object refresh).

The recovered instruction order is:

1. call `+0x194` with the object's `+0x10` position and use its returned
   linear index;
2. clear the object's `+0x24` word;
3. load `DAT_00EC5A10[selected]` and pass that byte to `+0x1AC`;
4. load `DAT_01391FE0[selected]`, store it into `+0x24`, and derive the
   selected map coordinates relative to `DAT_0101D0C8` using the `0xE4` (228)
   row stride (`x = offset % 228`, `y = offset / 228`);
5. return true exactly when the stored flood/cache word is non-zero.

`OriginalMarketAccessRefresh.project` and
`OriginalMarketAccessRefreshProjection` now preserve this post-selection
arithmetic as a side-effect-free primitive. The caller must provide the
selected linear index, map base, row stride, callback input byte, and
post-callback flood value. The helper intentionally does not synthesize the
`+0x194` provider-record selector, the `+0x1AC` callback effects, the
`DAT_01391FE0` cache population, or any Native coverage/settlement state.

**Evidence class:** **confirmed** for the call order, `+0x24` reset/write,
`DAT_00EC5A10` callback byte, `DAT_01391FE0` flood read, 228-stride coordinate
projection, non-zero return predicate, and EN/CH identity; **unknown** for
both callback implementations, cache/provider registration, and the mapping
from this raw result to Qin's Native water/market coverage. Qin-3 remains
fail-closed.

### 10.56a cMarket helper auxiliary-byte projection (`FUN_00543E70 @ 0x543E70`) (2026-09-01)

`FUN_00543E70 @ 0x543E70` is present in the indexed split corpus and marked
`identical` for EN/CH in `local/source/compare-report.tsv`. Its body first
invokes the helper object's virtual `+0x70` accessor with selector `0`, then
again with selector `1`; the second record supplies the relative `(dx,dy)`
pair. The function adds that pair to the cMarket object's signed short origin
at `+0x0A/+0x0C`, computes the canonical linear index with row stride `0xE4`
(228), and returns the byte at `DAT_00EC5A10[origin.x + dx + (origin.y + dy)*228]`.
The first accessor call has no retained value, so it cannot be treated as a
second candidate or as a route step.

The pure `OriginalMarketHelperAuxiliary.project` helper records this exact
origin/record-1/auxiliary-array projection with checked arithmetic and
out-of-range rejection. The helper-record `+0x70` implementation, its table
population, and the consumer that gives this byte player-facing meaning are
still unknown. This therefore closes only the callback-input index
calculation; it does not authorize a Native market/water coverage writer or
Qin settlement bridge.

**Evidence class:** **confirmed** for the function body, helper selector order,
market-origin fields, 228 stride, auxiliary-array read, and EN/CH identity;
**unknown** for helper-record provenance, the callback's semantic consumer,
and all Native provider/coverage mappings. Qin campaign scheduling remains
fail-closed.

### 10.57 The recovered cMarket record writer is a plunder-only path (`FUN_005D2C10 @ 0x5D2C10`) (2026-09-01)

The provider-record writer in §10.47 is now bounded at its caller-side vector
source. `FUN_005D2B60 @ 0x5D2B60` returns the fixed vector object at
`DAT_01E4EE30`; the EN/CH rows for `0x5D2B60`, `0x5D2C10`,
`0x4F8210`, `0x4F8200`, and `0x426D10` are all `identical` in
`local/source/compare-report.tsv`. `FUN_005D2C10` is a `__thiscall`: its
incoming `this` is the vector object, `FUN_004F8210` returns `this+4` (begin),
and `FUN_004F8200` returns `this+8` (end). The loop advances by one dword,
loads each building pointer, and admits it only when `FUN_00426D10` sees the
building status byte at `+0x04` equal to `1` or `3`. For each admitted object
it calls the object's vtable `+0x154` with `(commodity, remainingAmount)` and
subtracts the returned consumed amount; the return value is the unconsumed
remainder.

The direct callers are limited to the plunder/spoils paths:

* `FUN_00496CA0` (`campaign/Adding_plunder_type_pctd_amount_pc_2.c`),
  which first obtains `FUN_005D2B60()` and then distributes each plunder type;
* `FUN_00524120` (`Spoils_acquired_from_pctd_of_pctd.c`), which does the same
  for commodity `0x15`; and
* `FUN_0054DB10` (`Adding_plunder_type_pctd_amount_pc.c`), which obtains the
  same fixed vector before its 29-type plunder loop.

The call-site rows for all three callers are `identical` in the comparison
report. No Qin market, stall, mill, migration, or monthly-settlement caller
was found for `FUN_005D2C10`, and the fixed vector's population is not
serialized or connected to the six cMarket records by this path. This is a
confirmed negative against reusing the plunder writer as the missing Qin
market-record producer: the writer's record arithmetic remains valid, but
its vector provenance is a separate plunder subsystem.

**Evidence class:** **confirmed** for the fixed vector address, `this+4/+8`
range access, active-status filter, vtable `+0x154` dispatch, remainder
arithmetic, and the three direct plunder callers in hash-matched EN/CH;
**unknown** for the vector's own population, the Qin market provider vector,
and any other producer of the six cMarket records. Native must not map
`DAT_01E4EE30` or `FUN_005D2C10` onto Qin market settlement; the campaign
market bridge remains fail-closed.

### 10.58 cMarket monthly Dinners gate is unconditional for selector `-3` (`FUN_00543D50 @ 0x543D50`) (2026-09-01)

The monthly refill caller `FUN_004AEDF0 @ 0x4AEDF0` dispatches each active
live object through vtable `+0xC8` with selector `-3` before requesting
`+0x154(commodity = 0x1C, amount = 200)`. The cMarket vtable at
`0x7B6F3C` maps `+0xC8` to `0x543D50`; direct EN/CH PE bodies for
`0x543D50…0x543D84` are byte-identical (35-byte slice SHA-256
`2b5281548ad27e94f4c478b5a416ee56f2ae0dfff7eb0144168f4b4349ba51b1`). The
indexed callees `FUN_005D4770 @ 0x5D4770` and `FUN_00427180 @ 0x427180` are
also `identical` in `local/source/compare-report.tsv`.

The predicate's exact order is:

1. `FUN_005D4770(selector)` returns true when the receiver's model word
   `+0x14` equals the selector, or when the selector is `-7`;
2. if that test fails, `FUN_00543D50` returns true immediately when the
   selector is `-3`; and
3. only for other selectors does it call the helper object at cMarket `+0x158`
   through virtual `+0x14` and compare that result with the selector.

Consequently both authored Common Market (`59`) and Grand Market (`60`)
instances pass the monthly selector `-3` without consulting their helper
object. `OriginalMarketMonthlyDinnersGate.isEligible` preserves the three
branches as a pure research helper. This closes the cMarket-side admission
gate and confirms the monthly caller's Dinners request, but it does not
populate or consume the six cMarket records by itself.

The monthly caller still requires the active-object gate
`FUN_00426D10(0)` and global `DAT_00C5CDA0 != 0`; it then dispatches the
object's `+0x154` writer. The separate shop-placement path now confirms
the cMarket record key, selected slot, and 400/800 capacity assignment
(§10.50/§10.64), but it does not identify the monthly quantity source or the
downstream Native food-quality/coverage projection. Therefore this confirmed
gate is not authorization to enable Qin Dinners settlement or to replace the
unresolved monthly/external quantity source with `MarketSquare.inventory`.

**Evidence class:** **confirmed** for the cMarket vtable slot, selector branch
order, Common/Grand Market applicability, monthly caller argument order, and
EN/CH identity; **unknown** for the active-object vector's population,
monthly/external provider-record quantity source, and all Native
settlement/coverage effects;
the placement-time key/slot/capacity writer is confirmed in §10.64.

### 10.59 cMarket `+0x1B8` worker gate is a six-slot aggregate (2026-09-01)

The cMarket vtable at `0x7B6F3C` maps `+0x1B8` to indexed
`FUN_00544EC0 @ 0x544EC0`; the EN/CH rows are `identical` in
`local/source/compare-report.tsv`. The body does not read a single worker
field from the market itself. It iterates slot indices `0…5`, resolves each
entry from the six dwords at `cMarket+0x15C` through `FUN_00544A00`, skips null
entries, and then requires the child object's vtable `+0xC8(-1)` predicate to
be true. Only passing children contribute their vtable `+0x1B8` result to the
sum returned by the market's `+0x1B8` call.

This closes the first `0x543BC0` refill gate's field provenance: the
`+0x1B8 > 0` test is an aggregate over active child/provider slots, not a
generic population or inventory count. The six slot IDs, child `+0xC8(-1)`
semantics for each concrete class, and the child `+0x1B8` producer remain
unresolved; no Native worker or market-inventory value may be substituted.

Native records the fixed traversal as the pure
`OriginalMarketWorkerAggregate.total` helper. It rejects more than six input
slots, ignores inactive or selector-rejected entries, and preserves signed
child values. This closes only the aggregate's input shape; it does not
populate the child slots or enable Qin market settlement.

**Evidence class:** **confirmed** for the six-slot iteration, null/active
filters, aggregate call order, and EN/CH identity; **unknown** for slot
population, concrete child classes, and the producer semantics of each child
`+0x1B8` value. Qin settlement remains fail-closed.

### 10.84 cMarket peddler threshold uses the empty-slot/filled-shop ratio (2026-09-02)

The first half of `FUN_00543ED0 @ 0x543ED0` was checked against the indexed
EN/CH body and the direct helper `FUN_00408BA0 @ 0x408BA0`. Before the model-23
allocation branch, the cMarket code computes two separate aggregates:

* `FUN_00544A40` walks the six child pointers, excludes model `0x3E` (Empty
  Shop), and adds `FUN_0044CC50(childModelID, 5)` for every remaining child;
  the direct helper reads the authored 24-column model table at
  `DAT_00A63BFC[column + row*0x18]`.
* `FUN_00544A80(-1)` walks the same slots, applies the cStall `+0xC8(-1)`
  selector, and adds the admitted child's signed `+0x44` word. The earlier
  child-admission result (§10.83) means this aggregate is restricted to Empty
  Shop children; named shops fail that selector.

The ratio helper is exact: `FUN_00408BA0(numerator, denominator)` returns
`(numerator * 100) / denominator` with integer truncation toward zero, and
returns `0` when the denominator is zero. `FUN_00543ED0` maps that percentage
to thresholds `10/5/4/3/2` for `<25/25…49/50…74/75…99/≥100`; it increments
the cMarket `+0x36` counter and spawns only when the incremented byte is
strictly above the selected threshold. A separate cMarket `+0x268` call must
also return non-zero before the allocation branch is entered.

Native records this arithmetic through
`OriginalMarketCatalog.peddlerWorkerPercent` and the explicit-input
`peddlerSpawnGate` helper, with overflow-safe behavior for the otherwise
unchecked C multiplication. The helpers are research-only: the producer and
semantic label of cStall `+0x44`, the live child/market registry, and the
model-23 route/coverage/settlement projection remain unknown. Consequently
the Qin campaign scheduler still does not replace its fail-closed gate with
this ratio alone.

**Evidence class:** **confirmed** for the two aggregate call sites, the
`FUN_00408BA0` arithmetic, threshold branch values, strict counter comparison,
and independent `+0x268` stock gate; **unknown** for `+0x44` production,
runtime object ownership, and downstream market settlement.

### 10.60 cMarket status virtuals do not provide a second six-record producer (2026-09-01)

The remaining cMarket virtuals around the record container were checked
against the indexed EN/CH corpus and, where the splitter omitted a function,
against the PE body. The cMarket vtable at `0x7B6F3C` maps `+0x278` to
`FUN_005D4D00 @ 0x5D4D00`, `+0x27C` to `FUN_005D5300 @ 0x5D5300`, `+0x2A8`
to `0x5D5380`, `+0x2AC` to `0x5D54A0`, `+0x2B4` to
`FUN_005D54B0 @ 0x5D54B0`, and `+0x2B8` to `0x5D5580`.

* `FUN_005D4D00` (EN/CH `identical`) enumerates the six records through
  `+0x2CC/+0x2D8`, sums the eligible capacity, updates the caller's amount,
  and only when its third argument is null delegates an accepted amount to
  the already recovered `+0x154` transfer writer. Its own stores target the
  caller accumulator; it does not write record `key/qty/capacity` fields.
* `FUN_005D5300` (EN/CH `identical`) resets `this+0xA4` and delegates
  `+0x2C0/+0x2C4`; there is no record-container access in the body.
* The direct PE body at `0x5D5380` resolves model data, calls the market's
  `+0x2D0/+0x274` helpers, writes a model-data short at
  `model+0x38+2*index`, and updates a notification byte. It has no store to
  `cMarket+0x154` or to the record offsets `+0/+4/+8/+C`, and contains no
  direct `FUN_005D2790` call. The EN and CH slices
  `0x5D5380…0x5D5492` are byte-identical (275-byte SHA-256
  `c7c55bb70f4417c07cfe018d1aad4f9fe513bfe94b5144b5e638f574c53df2c6`).
* The direct PE body at `0x5D54A0` only dispatches cMarket `+0x274` with
  `(0,-1)` and returns; its EN/CH 13-byte slice is identical (SHA-256
  `8550d211eecf014a5b13168ad9a2d810a15cd667746d3415c266d449ea649f48`).
* `FUN_005D54B0` (EN/CH `identical`) reads `+0x264/+0x25C` and emits text/UI
  notifications through `FUN_00413960`, `FUN_00528AF0`, and `FUN_005288E0`.
  It does not enumerate or write the six records.
* The direct PE body at `0x5D5580` branches on model/status/global fields,
  emits the same notification family, and advances its own UI/state pointer
  by `+0x14` on accepted branches. It contains no `+0x2CC/+0x2D8` record
  enumeration, no `cMarket+0x154` access, and no store to record offsets
  `+0/+4/+8/+C`. The EN/CH slice `0x5D5580…0x5D596A` is byte-identical
  (1003-byte SHA-256
  `9417daa1d546ed505312bb4745ec0c9e4223155406d626ab4844b21a8ce1fa49`).

This is a confirmed negative against treating these status/notification
virtuals as the missing Qin market-record producer. The only recovered
record-mutating routes remain the direct `FUN_005D2790` callers and the
cMarket `+0x154` refill/transfer body in §10.31; the source of initial
`key/qty` population, slot ownership, and child-provider `+0x1B8` values is
still unknown. Native must remain fail-closed at that boundary.

**Evidence class:** **confirmed** for the listed virtual mappings, the
`FUN_005D4D00/FUN_005D5300/FUN_005D54B0` EN/CH identity, the direct PE byte
slices, and the absence of record-field stores in these bodies; **unknown**
for the exact UI/state labels used by `+0x2B8` and for the producer/ownership
path outside these virtuals. This negative result does not authorize a
guessed market-inventory or provider-coverage bridge.

### 10.61 `FUN_00544B30` only clears a cMarket slot during object cleanup (2026-09-01)

The cMarket-adjacent function `FUN_00544B30 @ 0x544B30` is present and
`identical` for EN/CH in `local/source/compare-report.tsv`. A direct PE
call-site scan finds exactly one direct call, at `0x541106` inside the
`0x5410C0` cleanup path. The caller first dispatches the original object's
`+0xC8(-1)` gate, resolves the current cMarket through `0x490700`, then calls
`0x544B30` with that market as `this` and the original object as its argument.
The 76-byte EN/CH caller slice `0x5410C0…0x54110B` is also byte-identical
(SHA-256 `7ca54e6baf9ba8c336c631b075e038ec18e36dddef596aee51ff8e97de089952`).

The indexed body performs the following concrete operations when the parent
slot is valid:

1. resolve the parent slot record with market `+0x2D8(slot)`;
2. read that record's current quantity through `FUN_004F8200` and pass the
   value to `FUN_005D2760`, which reduces the record quantity to zero;
3. subtract `400` or `800` from the cMarket model-data commodity short
   selected by the child helper's `+0x0C`, clamp the short at zero, and clear
   the child object's status byte; and
4. create a new model-`0x3E` object at the former object's coordinates,
   relink its `+0x154` parent ID and `+0x150` slot index, and mirror its ID
   into the parent's `+0x15C[slot]` array.

The 497-byte EN/CH body slice `0x544B30…0x544D20` is byte-identical (SHA-256
`282196a07d2ae4cae6f7759c20f1fb936cc6588659a44e66d9ce136541e4f251`). No
instruction in this path assigns a record key or introduces a non-zero
quantity; it is a cleanup/relink mutation of an already selected slot. The
third byte argument consumed by `FUN_005D2760` is not materialized explicitly
at this call site, so the key-clearing side effect remains unclassified.

**Evidence class:** **confirmed** for the single direct caller, slot lookup,
quantity-zeroing call, `400/800` model-data decrement, status clear, model
`0x3E` relink, and EN/CH identity; **unknown** for the caller's user-facing
event name and the omitted optional-byte provenance. This path narrows the
record lifecycle but does not recover the initial six-record producer, so Qin
market settlement remains fail-closed.

### 10.62 model-`0x3E` shop `+0x1B8` is object `+0x44`; `+0x18C` is a monthly quantity writer (2026-09-01)

`GameData/Model/EmperorBuildingModels.txt` identifies decimal `62` (`0x3E`)
as **Empty Shop**; the adjacent authored rows `64…70` are the named shop
models. The explicit object factory path is present in the indexed corpus:
`FUN_0051C660 @ 0x51C660` calls `FUN_005418D0 @ 0x5418D0`, whose admitted
model set includes `0x3E` and `0x40…0x46`, and then dispatches
`FUN_00540770 @ 0x540770`. The latter initializes the base object, creates a
`400`-unit record through `FUN_005D2690(400)`, installs vtable
`0x7B6C5C`, sets `+0x54 = -1`, and stores the six-row table pointer returned
by `FUN_005416C0 @ 0x5416C0` (the table is searched through
`DAT_008572E8/DAT_0085746C`). `FUN_00540770`, `FUN_005418D0`, and
`FUN_005416C0` are `identical` for EN/CH in `local/source/compare-report.tsv`.

The raw vtable at `0x7B6C5C` maps the relevant slots as follows (the EN and CH
tables are byte-identical):

* `+0x188 → FUN_004271D0 @ 0x4271D0`, the object-admission gate;
* `+0x18C → 0x51E310`, the only recovered direct writer of this class's
  `+0x44` field;
* `+0x1B0 → 0x428EB0`, which returns `0` when `this+0x6E` is set, otherwise
  calls `FUN_0044CC50(modelWord+0x14, 5)`;
* `+0x1B4 → FUN_00428ED0 @ 0x428ED0`, computing
  `(vtable+0x1B8() * 100) / vtable+0x1B0()` when the denominator is positive;
* `+0x1B8 → FUN_00416B10 @ 0x416B10`, whose complete body is
  `movsx eax, word ptr [ecx+0x44]; ret`.

Therefore the cMarket aggregate in `FUN_00544EC0 @ 0x544EC0` is concretely
the sum of `+0x44` from up to six registered child objects, after each child
passes its `+0xC8(-1)` admission gate. This is not a cMarket record's
`key/qty/capacity` field and must not be represented as a generic worker
count.

The `+0x18C` implementation is omitted by the splitter, so its PE body was
checked directly. In both canonical EN
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and CH
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`) the
slice `0x51E310…0x51E48F` is 383 bytes with SHA-256
`54db9ff2518504155d259157d9bef71e4618577da87faa31c2d59099df02011b`.
Its confirmed effects are:

1. call `+0x188` with an out-parameter; if admission fails, clear `word
   this+0x44` (except for the selector-`9` early-return branch);
2. clear `this+0x44`, derive selector-indexed values from the global table
   region beginning at `DAT_01312138`, and use `+0xF4`, `FUN_00408BA0`, and
   `+0x1B0` while bounding the amount; and
3. store the bounded signed-short amount to `this+0x44` and subtract the same
   amount from one of the caller-provided integer arrays. When the first
   array is selected by `+0xF4`, this concrete shop vtable's `+0xF4` is
   `FUN_00413A00 @ 0x413A00`, which returns zero; the body therefore takes the
   other array branch for this class. This describes data flow only; the
   arrays' authored semantic names are not recovered.

The direct indexed caller is `FUN_004F19A0 @ 0x4F19A0` (`identical` EN/CH).
It builds ten-element `local_28` and `local_50` arrays from the five-dword
records beginning at `DAT_01312144`: for each record, when `src[-2] <
src[-3]`, it places `src[0]` in `local_28` and `src[-2] - src[0]` in
`local_50`; otherwise both entries are zero. It then iterates the registered
object vector and invokes each object's `+0x18C` twice, with selector `1`
and selector `2`, respectively. The phase dispatcher
`FUN_004AC2B0 @ 0x4AC2B0` invokes this routine in phase `0x19` after
`FUN_004AE220` and `FUN_004AE7F0`; the monthly/difficulty callers
`FUN_005929A0 @ 0x5929A0` and `FUN_00592690 @ 0x592690` also call it after
`FUN_004F1590` on their respective phase branches. All five caller rows are
`identical` in the comparison report.

**Evidence class:** **confirmed** for model `0x3E` identity, factory and
vtable slots, the `+0x1B8 → +0x44` implementation, six-child cMarket
aggregation, direct `+0x44` writes in the EN/CH-identical PE body, the
`+0x18C` call edge, selector order `1` then `2`, and the recovered monthly
callers. **Inferred/unknown:** `+0x44`'s player-facing label (stock versus
available goods), the semantic provenance of the `DAT_01312138…` arrays, the
meaning of selectors `1/2`, exact row-to-slot mapping beyond the recovered
table/key fields, and map-load reconstruction. No Native market/provider
settlement or coverage value may be derived from these fields; Qin remains
fail-closed at the unresolved producer boundary.

### 10.63 cStall virtual `+0x260` is a concrete record writer, with Dinners-specific price state (2026-09-01)

The previously broad negative around direct `FUN_005D2790` callers is narrowed
by the cStall vtable. `FUN_00540770 @ 0x540770` is the cStall constructor: it
creates one `400`-capacity record with `FUN_005D2690(400)`, installs vtable
`0x7B6C5C`, initializes `+0x54 = -1`, and stores the six-row model table
pointer returned by `FUN_005416C0`. `GameData/Model/EmperorBuildingModels.txt`
identifies model `62` (`0x3E`) as **Empty Shop**, while models `59` and `60`
are Common and Grand Market Square. The cStall vtable's `+0x260` entry is the
PE-only function beginning at `0x541760`; the next dword at `+0x264` is the
`0x7D3B18` RTTI locator for the following cMarketConstInfo sub-vtable, so
`0x541760` is the final cStall virtual in that table segment, not a stray data
pointer. The cStall type is confirmed by the preceding RTTI locator
`0x7D3AE0`, whose type descriptor is `.?AVcStall@@`.

The EN and CH `0x541760…0x541866` bodies are byte-identical (263-byte
SHA-256 `0d82e23754ffbd49c218fd133d2e8010a4d08ee0afd4f6bcf224a0facac61a54`)
for canonical executable hashes
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
Its confirmed control flow is:

1. resolve the current cMarket through `FUN_00490700` and require the
   `FUN_00426D10(0)` active gate;
2. resolve this stall's registered record with cMarket `+0x2D8(this+0x150)`;
3. pass the first method argument as the record key and the third method
   argument as the amount to `FUN_005D2790`; the helper writes the key,
   increases quantity, clips at record capacity, and returns overflow;
4. when overflow is non-zero, call cMarket `+0x154` with the second method
   argument and that overflow; and
5. when the key is exactly `0x1C` (the authored `Dinners` key), read cMarket
   `+0x264` and current market state `+0x180`, perform the recovered integer /
   float rounding sequence through `FUN_00541730`, and store the resulting
   value through `FUN_00545140` (`this+0x180`).

The indexed corpus exposes dynamic call sites for this virtual. The indexed
simulation routines `FUN_005DB640` and `FUN_005DC190` dispatch `+0x260` on
objects obtained from the global object vector. Those calls are consistent with
cStall receivers only when the object's vtable is the `0x7B6C5C` family; the
splitter does not preserve a typed call graph. `FUN_005DEE40` is a separate cMarket
call: its `+0x260` resolves to cMarket `FUN_005D49B0`, a market admission
predicate, not this cStall writer. UI helpers (`FUN_005F11F0`,
`FUN_005F1640`, `FUN_005F1A60`, and `FUN_005F4C60`) also read `+0x260` for
display/state fields, but do not write records themselves.

The unsplit cart-think body at `0x4D2970` supplies the missing direct caller
evidence. Its function returns at `0x4D2BCA`; the inclusive PE slice
`0x4D2970…0x4D2BCA` is 603 bytes and has SHA-256
`4064dcaef86641c69f4f517f4c2aac58d8f192e1c2262678f70d80a390ba5375` in both
canonical EN and CH executables (the files are byte-identical for this slice;
there is no `compare-report` row). The figure-type dispatch table identifies
this slot-0 body as model `25`, **Buyer's Servant**; authored
`GameData/Model/EmperorFigureModels.txt` row 25 gives speed `8` and range `50`.
At `0x4D2B04…0x4D2B15`, the body keeps `edi` as the current object receiver,
reads `byte figure+0x88` and `byte figure+0x13`, then performs:

```
push 0x64                 ; third method argument = amount 100
push byte figure+0x13     ; second method argument
push byte figure+0x88     ; first method argument = record key
mov  ecx, edi             ; receiver
call [vtable+0x260]
```

Combined with `FUN_00541760`'s stack reads, this confirms the cart deposits
100 units under the commodity key in `figure+0x88`; if the cStall record clips,
the overflow path receives the mill-selected type-count in `figure+0x13`.
The mill-pickup producer and the food rewrite of `figure+0x88` are documented in
§10.49–§10.52 above; this call-site hash independently verifies that the
producer reaches the cStall writer with those three arguments.

The cMarket `+0x154` overflow consumer, the `+0x264/+0x180` Dinners state
labels, the quantity lifecycle, and the quality/coverage projection remain
unknown. The runtime writer that assigns recovered table rows to a placed
shop's cMarket record is confirmed in §10.50/§10.64, so no Native market
settlement, peddler coverage, or Qin goal value may be derived from this method
until the remaining quantity/ownership/label edges are independently mapped.

**Evidence class:** **confirmed** for the cStall RTTI/vtable placement,
constructor and `400`-capacity record, EN/CH body identity, active/slot/key /
amount/overflow call order, the `0x1C` branch, the model-25 caller and its
three pushed values, and the listed dynamic call sites; **inferred/unknown** for
caller receiver typing outside the cStall vtable, the player-facing argument
labels, Dinners `+0x180` semantics, overflow ownership, monthly/external
quantity population, and quality/coverage projection. Qin remains fail-closed
at the unresolved producer/ownership boundary.

### 10.64 Shop-placement writer populates cMarket record key, runtime slot, and capacity (2026-09-01)

The placement chain is the recovered runtime assignment for a selected row of
the authored seven-row market-shop table. In the hash-matched English build
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and the
Chinese cross-check
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`),
`FUN_00540E70 @ 0x540E70` and `FUN_00540F80 @ 0x540F80` are marked
`identical` in `local/source/compare-report.tsv`. Their direct body slices are
also byte-identical: `0x540E70…0x540F7A` (267 bytes, SHA-256
`aa684e563a8e33f6c6d525dbed3b5ee2168468b5f861b61892d5f458971af229`) and
`0x540F80…0x541027` (168 bytes, SHA-256
`9a310fc4eca16dd844da2efcf598fcd4202b2efbd6e0777cbb0302a862fc7abe`).

The caller chain is `FUN_004B1250 @ 0x4B1250` →
`FUN_005418D0 @ 0x5418D0` → `FUN_00540E70` → `FUN_00540F80`. The admission
function accepts empty shop model `0x3E` and shop models `0x40…0x46`.
For the empty-shop branch, `FUN_00540E70` writes the new object's parent
market ID at `object+0x154`, selected runtime provider-record slot at
`object+0x150`, and mirrors the object ID into `market+0x15C[slot]`, then calls
`FUN_00540F80`.

`FUN_00540F80` resolves the parent cMarket with `FUN_00490700`, obtains the
selected record through parent virtual `+0x2D8(object+0x150)`, and requires
the object's `+0xC8(-1)` gate. Direct PE disassembly shows the omitted
`__thiscall` receivers in the split C output: it sets `ecx = record` before
calling `FUN_0053C700(record, tableRow+0x0C)`, which writes `record+4` to the
row's commodity key; it sets `ecx = record` before
`FUN_004C1550(record, 400)` or `FUN_004C1550(record, 800)`, which writes
`record+0xC` to the row-selected capacity. The same 400/800 value increments
the model-data short at `base+0x38+key*2`.

The exact `DAT_008572E8` table-row values are: row 0/model 66/Food Shop/key
`0x1C`/flag `+0x18 = 0` → capacity 800; row 1/model 67/key `0x13`, row
2/model 70/key `0x0D`, row 3/model 65/key `0x19`, row 4/model 64/key
`0x17`, row 5/model 68/key `0x16`, and row 6/model 69/key `0x18`, each
with flag `+0x18 = 1` → capacity 400. Constructor callback
`FUN_00543680 → FUN_005D2690` initially writes each record as key 0, quantity
0, capacity 400; the constructor's later six-record `FUN_004C1550(0)` loop
zeroes that capacity before placement installs the row-specific value.

The table exposes seven static row/selection IDs, while the cMarket constructor
allocates at most six provider records. The apparent discrepancy is resolved by
the helper/layout path in §10.65: Common markets expose four active shop bays,
Grand markets expose six, and `FUN_005428B0` compacts those active entries into
runtime slots `0…3` or `0…5`. The table row ordinal is not the value written to
object `+0x150`; the exact selected-row-to-active-layout-entry mapping remains
unknown. Do not synthesize a seventh Native record from the table alone.

This closes placement-time cMarket record key, dynamic runtime-slot assignment,
and capacity; the selected static row's mapping to an active layout bay remains
unknown.
The model-25 cart-think call in §10.63 is the confirmed cStall quantity path:
it deposits 100 units through `FUN_005D2790`, which writes `record+8` after
the placement writer has installed the key/capacity. It does not identify the
separate monthly/external provider vector, resolve overflow consumption, or
prove any Native quality/coverage/settlement effect.

**Evidence class:** **confirmed** for the EN/CH-identical placement call
chain, parent/runtime-slot writes, record lookup, key write, 400/800 capacity
write, model-data increment, exact table rows, and the cart-deposit quantity
path; **confirmed** for dynamic compact slot allocation and the Common/Grand
active-bay counts in §10.65; **unknown** for the selected-row-to-active-layout
mapping,
monthly/external quantity population, overflow consumer,
Dinners `+0x264/+0x180` labels, and all Native quality/coverage/settlement
projection. Qin remains fail-closed.

### 10.65 Market shop runtime slots are dynamically assigned from active layout entries (2026-09-01)

The apparent seven-row/six-record edge is resolved by tracing the actual
placement allocator in the hash-matched EN and CH executables. The EN hash is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`; the CH
cross-check is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
`local/source/compare-report.tsv` marks `FUN_005428B0 @ 0x5428B0` as
`identical`; the direct `0x5428B0…0x542C2B` body slice is 892 bytes with
SHA-256 `ea52de7dcd488dc43ebe5b7ecb4c8365abbe262d8cb1d5fbdd8d4a966caf6727`.
The corresponding indexed source files are
`local/source/split-merged/code/0x050000/FUN_005428b0.c`,
`FUN_00544220.c`, and `FUN_005451a0.c`; their EN/CH comparison rows are
`identical` at `0x5428B0`, `0x544220`, and `0x5451A0`.

`FUN_00544220 @ 0x544220` is a cMarket wrapper: it passes the cMarket helper
(`this + 0x158`) as the receiver and the cMarket object as an explicit
argument to `FUN_005428B0`. `FUN_005451A0 @ 0x5451A0` is the cMarket vtable
`+0x100` caller of that wrapper. In `FUN_005428B0`, helper virtual `+0x24`
returns the layout bank base and helper virtual `+0x4` returns its entry count.
The loop visits each layout entry and increments its local `i` only when
`entry.kind == 2 && entry.aux != 0`. For each such active entry, the created
empty-shop object (model `0x3E`) receives `object+0x150 = i`,
`object+0x154 = market[+0x2D]`, and its object ID is mirrored to
`market+0x15C[i]`. Thus `object+0x150` is a compact runtime active-bay ordinal,
not the `DAT_008572E8` static table-row ordinal.

The helper implementations and raw layout banks are directly recoverable:

| market type | helper vtable | `+0x4` count | `+0x24` layout base | active entries (`kind=2 && aux!=0`) |
| --- | ---: | ---: | ---: | --- |
| Common | `0x7AB800` | `28` (`0x42CD10`) | `0x8574A8` (`0x42CD20`) | indices `0, 2, 20, 22` → 4 bays |
| Grand | `0x7AB878` | `42` (`0x42CDA0`) | `0x857828` (`0x42CDB0`) | indices `0, 2, 4, 30, 32, 34` → 6 bays |

Native exposes these confirmed static values as the research-only
`OriginalMarketLayoutCatalog` (`Sources/EmperorCore/MarketSimulation.swift`);
its `runtimeSlot(forLayoutEntryIndex:)` helper returns the compact ordinal for
active entries and `nil` for inactive entries. It does not create provider
records or enable market settlement.

A corpus-wide literal search for `DAT_008572E8`/`0x8572E8` finds the table
lookup in `FUN_005416C0` but no additional writer that joins a table-row
ordinal to one of these active layout entries. This is the negative static
evidence behind the remaining selection-binding unknown; it is not a license
to infer a row-to-bay permutation.

The cMarket provider-container method `0x4E1BF0` returns `6`, and the record
accessor `0x546C40` computes `recordArray + index * 0x10` without a bounds
check. The constructor therefore reserves six maximum provider records, while
the helper chooses four or six active shop bays before compacting their runtime
slots. No seventh Native provider record is warranted.

**Evidence class:** **confirmed** for the EN/CH-identical allocator, wrapper
receiver/argument order, helper counts and bases, active-entry predicates,
dynamic `+0x150`/`+0x154`/`market+0x15C[i]` writes, and Common/Grand active-bay
cardinality. **Unknown** remains the exact mapping from a selected
`DAT_008572E8` shop row to a particular active layout entry, whether the row's
first dword participates in another path, and the downstream provider quantity,
coverage, quality, and settlement projection. Native market settlement stays
fail-closed until those edges are recovered.

### 10.65a Complete Common/Grand helper layout entries (2026-09-01)

The layout-bank evidence in §10.65 is now recorded at entry granularity. The
canonical English PE
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) stores
four little-endian dwords per entry at `DAT_008574A8` (28 rows) and
`DAT_00857828` (42 rows); the Chinese PE
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`) has the
same bytes at both addresses. In
`FUN_005428B0 @ 0x5428B0`, the allocator reads these fields as
`(x, y, kind, aux)` and advances its compact runtime ordinal only for
`kind == 2 && aux != 0`.

Native now exposes every row through `OriginalMarketLayoutEntry` in
`Sources/EmperorCore/MarketSimulation.swift`, rather than retaining only the
active index list. The exact Common bank is a `4 × 7` grid: rows `0…3` and
`20…23` are kind-2 bays, with active rows `0, 2, 20, 22` (`aux = 1`); the
remaining kind-2 rows have `aux = 0`, while rows `8…11` and `16…19` are
kind-4 and rows `12…15` are kind-1. The Grand bank is a `6 × 7` grid: active
rows `0, 2, 4, 30, 32, 34` (`aux = 1`), kind-4 rows `12…17`, `24…29`,
kind-1 rows `18…23`, and all other kind-2 rows have `aux = 0`; the kind-4 and
kind-1 auxiliary words are the literal set
`{112,113,114,115,116,117,118,119,120,121,122,123,130,131,132,133,134,135}`
in the PE table.

This complete bank confirms coordinates, structural kinds, and active-bay
predicate, and is covered by
`testOriginalMarketLayoutCatalogMatchesRecoveredActiveBays`. It does **not**
identify a selected `DAT_008572E8` shop row with a particular layout entry:
the corpus still has no writer joining those two tables. No provider record,
quantity, coverage, or settlement state is synthesized from the added rows.

**Evidence class:** **confirmed** for all 28/42 `(x,y,kind,aux)` rows, PE
addresses, EN/CH byte identity, and the allocator predicate; **unknown** for
shop-row-to-bay binding and every downstream provider/settlement projection.

### 10.65b Shop selection binds through the clicked placeholder object, not row ordinal (2026-09-01)

The remaining selection-binding question can be narrowed by the
EN/CH-identical construction dispatcher `FUN_004B1250 @ 0x4B1250`
(`local/source/split-merged/code/0x040000/FUN_004b1250.c`; comparison row
`identical`). For a shop model admitted by `FUN_005418D0`, the dispatcher uses
the construction coordinates `(param_4, param_5)` to read one object ID from
the map-cell table at `DAT_00FC3750[DAT_0101D0C8 + param_4 + 0xE4*param_5]`.
It passes that existing object ID, together with the selected shop model and
the same coordinates, to `FUN_00540E70`.

`FUN_00540E70 @ 0x540E70` first captures the existing object's `+0x150` word,
then its `0x3E` empty-shop branch creates the selected shop and writes that
captured word to the replacement object's `+0x150`. The subsequent
`FUN_00540F80` lookup uses this preserved compact slot to reach the cMarket
record and installs the selected row's commodity key/capacity. Therefore the
static row ordinal in `DAT_008572E8` is not converted directly to a bay:
the clicked empty placeholder already carries the runtime bay slot assigned by
`FUN_005428B0`.

This closes the binding mechanism at the construction call boundary while
leaving the Native prerequisites unresolved: the map-cell object registry,
placeholder coordinates/occupancy, and a serialized or authored projection of
those empty-shop objects are not recovered. Native must not manufacture
placeholder objects or infer a row-to-bay permutation from the layout arrays;
the market settlement/provider bridge remains fail-closed.

**Evidence class:** **confirmed** for the coordinate-indexed object lookup,
argument order, `+0x150` preservation, and EN/CH identity; **unknown** for
map-cell registry population, placeholder geometry/state, and downstream
provider quantity/coverage/settlement effects.

### 10.65c Placeholder-carried slot binding and raw removal delta (2026-09-02)

The placement/update and replacement bodies provide one more reusable boundary
without resolving the provider bridge. In the EN/CH-identical
`FUN_005428B0 @ 0x5428B0`, every active helper entry receives a compact ordinal
`i`; an empty-shop placeholder (model `0x3E`) stores that ordinal at
`object+0x150`, the parent market ID at `object+0x154`, and its registry ID at
`market+0x15C[i]`. The coordinate-selected replacement in
`FUN_00540E70 @ 0x540E70` first captures the placeholder's `+0x150` and writes
that same value to the selected shop, so the clicked object—not the static
`DAT_008572E8` row ordinal—carries the bay binding. `FUN_00540F80 @ 0x540F80`
then writes the selected row's commodity key and its `400/800` capacity to the
record reached through that preserved ordinal.

The selected-record removal path `FUN_00544B30 @ 0x544B30` uses the same row
flag: it subtracts `800` for Food Shop `66` (`+0x18 == 0`) and `400` for the
other six shop models (`64…70`, `+0x18 != 0`) from the indexed raw model-data
word, then clamps at zero. The direct bodies are marked `identical` in
`local/source/compare-report.tsv`; no new executable scan or runtime launch was
used.

Native exposes this as the research-only
`OriginalMarketRuntimeShopBinding`. It accepts the already coordinate-selected
placeholder order and explicit registry IDs, returns the compact runtime slot,
layout-entry index, parent/child IDs, and optional raw capacity delta, and
rejects malformed counts/model IDs. Its `rawQuantityAfterRemoval` helper
preserves only the confirmed non-negative subtract-and-clamp arithmetic. It
does not manufacture placeholders, infer a row-to-bay permutation, populate
`MarketSquare.inventoryByCommodityID`, or enable Qin market settlement.

**Evidence class:** **confirmed** for placeholder-carried slot preservation,
registry-field roles, row-selected key/capacity write, and the `400/800`
subtract-and-clamp arithmetic in EN/CH-identical functions; **unknown** for
serialized map-cell/object population, provider-record quantity/quality
lifecycle, coverage/route consumers, and Native projection.

### 10.66 cStall Dinners quality blend is exposed as a raw arithmetic primitive (2026-09-01)

The cStall virtual writer recovered in §10.63 has one completely closed
numeric boundary even though its provider ownership and settlement edges are
not closed. In the canonical English executable
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and the
Chinese cross-check
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`),
`FUN_00541760 @ 0x541760` is the cStall vtable `+0x260` body. Its cart caller
(`0x4D2970…0x4D2BCA`, model 25) pushes amount `100`, the raw byte
`figure+0x13`, and the commodity key `figure+0x88`; the writer clips the
amount through `FUN_005D2790` and calls the blend only on key `0x1C` (Dinners).

For `accepted = 100 - overflow`, the recovered stores are:

```
incomingQuality = 20 * byte(figure+0x13)
newQuality = round(
    (oldQuality * oldDinnersStock + incomingQuality * accepted)
    / (oldDinnersStock + accepted)
)
```

`FUN_00541730 @ 0x541730` is indexed at
`local/source/split-merged/code/0x050000/FUN_00541730.c` and is marked
`identical` for EN/CH in `local/source/compare-report.tsv`. It truncates the
positive float, then increments when the discarded fraction is at least
`DAT_007ACA3C = 0.5` (the constant is recorded in §10.5). Therefore the
non-negative integer half-up form is equivalent and avoids introducing a
platform-dependent float into save/replay code. The raw contribution is
`20 * typeCount`; it must not be converted to Native's authored
`FoodQuality` bands (`0, 20, 30, 50, 70, 90`) without recovering that separate
mapping.

Native now exposes this closed boundary as
`OriginalMarketQualityBlend.blend(...)` in
`Sources/EmperorCore/MarketSimulation.swift`. It accepts the post-overflow
amount and raw byte range `0…255`, returns the intermediate `20 * typeCount`
and rounded result, and rejects a zero denominator or checked arithmetic
overflow. It is a research primitive only: no market object, Qin campaign
goal, provider registry, cHouseInfo slot, or coverage projection calls it.

**Evidence class:** **confirmed** for the key gate, cart argument order,
`20 * typeCount` contribution, weighted numerator/denominator, positive
half-up rounding, and EN/CH identity of `FUN_00541730`; **unknown** remains
the caller that populates monthly/external Dinners stock, overflow ownership,
the semantic label of `cMarket+0x180`, and the projection into Native house
quality/coverage. Qin remains fail-closed at those unresolved edges.

### 10.66a House-quality replace/blend arithmetic is centralized (2026-09-01)

The normal market-delivery callback's quality write remains the direct PE
store at `FUN_005437B0 @ 0x5437B0`, `0x543A09`. After the independently
confirmed elite-house gate, the callback replaces `cHouseInfo+0x36` when the
market dword is greater; otherwise it uses the strict ratio branches
`3.0/2.0/0.5/0x3EA8F5C3` and the signed `/4,/3,/2,/3,/4` blends recovered in
§10.10. Native now exposes this exact post-gate arithmetic as
`OriginalMarketHouseQualityBlend.resolve(...)` and routes
`ResidentialUnit.addFoodSupply(amount:qualityRawValue:)` through it. The
single-precision lower threshold is retained from PE bits `0x3EA8F5C3`, and
invalid raw inputs return `nil` rather than widening the supported domain.

This is a refactoring of a previously tested Native projection, not a new
market or settlement bridge. It does not identify the complete
`cHouseInfo+0x36` writer set, provider-record source, overflow ownership, or
quality/coverage projection; Qin therefore remains fail-closed at those
unresolved edges.

**Evidence class:** **confirmed** for the replace gate, five ratio arms,
single-precision threshold, integer blend identities, and the direct PE store;
**unknown** for all provider/settlement ownership and the complete writer set.

### 10.67 Emigration assignment plan is closed, while figure departure remains unresolved (2026-09-01)

The departure half of the automatic-migration producer has a complete,
side-effect-free selection boundary in the indexed corpus. The canonical
English executable hash is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`; the
Chinese cross-check is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
`FUN_004ADC90 @ 0x4ADC90` is indexed at
`local/source/split-merged/code/0x040000/FUN_004adc90.c` and marked
`identical` in `local/source/compare-report.tsv`. Its only direct callee in
the assignment body is `FUN_004ADED0 @ 0x4ADED0`, also indexed and
`identical`.

`FUN_004ADC90` initializes a local remainder from its positive request and
scans level buckets `house+0x16 = 0…13`. For every bucket it rescans the live
house vector through the `FUN_004F8210`/`FUN_004F8200` begin/end accessors, so
the source order is preserved and no object-ID sort occurs. A house is
selected only when its signed `house+0x20` resident word is positive and its
level equals the current bucket. The batch passed to `FUN_004ADED0` is
`min(6, residents, remainder)`; the local remainder is reduced around the
call, not from a spawn-success return. After bucket 13, the unassigned count
is the remaining local value added to `DAT_01311FB4`.

`FUN_004ADED0` then supplies the downstream mutation boundary: it calls
`FUN_00591900(-batch)`, subtracts the batch from `house+0x20` (or clears the
word when exhausted), optionally invokes `FUN_00519060`, and attempts to
create figure type `0xC` (`emmigrant`) through `FUN_004EA050`. It does not
read `house+0x24`; departure selection is therefore independent of the land
entry flood/access short used by immigration. The source does not expose a
complete route-to-exit, home unlink, or figure-spawn-success contract in this
pass.

Native exposes only the closed selection boundary as
`OriginalDepartureAssignmentPlanner.plan(...)` in
`Sources/EmperorCore/MigrationSimulation.swift`. Its output identifies the
house-vector index, level bucket, six-person cap, and unassigned remainder;
it deliberately does not mutate `ResidentialUnit`, create an emigrant
walker, or consume `pendingDeparture`. This makes the departure ordering
reusable without enabling a guessed emigration side effect.

**Evidence class:** **confirmed** for the fourteen level buckets, positive
resident gate, live-vector ordering, six-person cap, remainder accounting,
`FUN_004ADED0` call boundary, and absence of a `house+0x24` read;
**unknown** remains the figure type-`0xC` route/exit state machine, home
unlink timing, spawn-failure handling beyond the caller's unconditional
remainder decrement, and Native departure projection. Qin production remains
fail-closed until the independent food/monument/war and registry edges are
closed.

### 10.67a `FUN_004ADED0` departure write boundary is explicit (confirmed, 2026-09-03)

The already-selected departure batch now has a pure field-level writer in
`Sources/EmperorCore/MigrationSimulation.swift` as
`OriginalDepartureWrite.apply(...)`. The EN body at `0x4ADED0` first calls
`FUN_00591900(-batch)`, then subtracts the batch from `house+0x20`; when the
batch exhausts the signed resident word it writes zero and conditionally calls
`FUN_00519060` after the `FUN_00516EB0` house-class predicate. The sibling
conversion writes `(house+0x14, house+0x16) = (3,0)` for the common predicate
and `(0xC,9)` for the elite predicate, then rebuilds the map object through
`FUN_004B72B0`.

The writer always attempts `FUN_004EA050(1, 0xC, ...)` after the house update.
When the caller reports allocation success, the new type-`0xC` figure is
initialized with state byte `6`, wait word `0`, and the signed request byte at
`+0x6E`. Native records these exact outputs without mutating its resident
array, global population ledger, map cells, or figure collection. This closes
the departure mutation/initialization boundary while keeping the unresolved
emigrant route, home unlink, allocator ownership, and spawn-failure behavior
fail-closed.

The EN/CH comparison rows for `0x4ADED0`, `0x516EB0`, and `0x519060` are
`identical`. `FUN_004ADC90` is the direct caller and reduces its local
remainder regardless of whether `FUN_004EA050` allocates a figure; the
planner therefore remains separate from this writer and from
`pendingDeparture` consumption.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004aded0.c`,
`local/source/split-merged/code/0x040000/FUN_004adc90.c`,
`local/source/split-merged/code/0x050000/FUN_00516eb0.c`,
`local/source/split-merged/code/0x050000/FUN_00519060.c`, the EN PE
disassembly at `0x4ADED0`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for ledger-call ordering, resident clamp,
common/elite conversion writes, map-rebuild call, type-`0xC` allocation
arguments, and figure initialization bytes; **unknown** for the map-cell
projection, allocator success side effects, route/exit FSM, home unlink, and
Native live projection.

### 10.68 Food popularity walk now preserves live house-vector order (2026-09-01)

`FUN_00590F30 @ 0x590F30` is indexed at
`local/source/split-merged/code/0x050000/FUN_00590f30.c` and is marked
`identical` in `local/source/compare-report.tsv` for the canonical English
and Chinese builds. Its occupied-house loop starts from the live vector
accessor `FUN_00413B40(1)` and increments the vector pointer; no object-ID
comparison or sort occurs. The loop mutates each house's food-shortage streak
(`house+0x5C`) before contributing its `−1/−2/−3` score, so preserving source
order is part of the state-transition contract even when a particular mean is
commutative.

Native `CitySimulation.migrationFoodTerm` previously sorted `houses` by
`ResidentialUnit.id` before applying the recovered quality comparison and
streak update. It now traverses `houses.indices` directly, matching the
persisted live-vector order used by the rest of the migration assignment
paths. It also clears the Native streak when the authored requirement is zero,
matching the source's explicit `house+0x5C = 0` write before that house is
excluded from the average. No food values, thresholds, or campaign wiring were
changed; the market/provider boundary remains fail-closed.

**Evidence class:** **confirmed** for the source vector walk and Native order
correction; **unknown** remains the legacy-save relationship between array
order and original registry order, plus the unresolved campaign cMarket
provider/quality lifecycle. This correction does not authorize automatic
migration in campaign-backed Qin cities.

### 10.69 cMarket `+0x180` visitor/event write is bounded, but its semantic label remains unknown (2026-09-01)

The canonical English executable hash is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`; the
Chinese cross-check is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
The relevant functions are all marked `identical` in
`local/source/compare-report.tsv`: `FUN_00511080 @ 0x511080`,
`FUN_00511860 @ 0x511860`, `FUN_00511710 @ 0x511710`,
`FUN_00511B10 @ 0x511B10`, `FUN_00515770 @ 0x515770`,
`FUN_00515780 @ 0x515780`, `FUN_00543450 @ 0x543450`,
`FUN_00545100 @ 0x545100`, and the setters at `0x545140`, `0x545150`,
and `0x545160`.

`FUN_00543450` is the cMarket constructor. For model `0x3C` (the grand
market square), it writes `5` through `FUN_00545150` to `cMarket+0x184`;
the other constructor branch (the common market square, model `0x3B`) writes
`3`. It writes `1` to `cMarket+0x188`, allocates and clears the six-slot
provider container, and finally writes `0` through `FUN_00545140` to
`cMarket+0x180`. `FUN_00515770` and `FUN_00515780` are direct getters for
`+0x180` and `+0x184`; the three `FUN_005451*` bodies are direct setters.

The only recovered write-side arithmetic is in case `4` of
`FUN_00511080`. Its direct caller `FUN_00511860` first passes the timer gate
`FUN_00511060` and selects an adjacent live object with `FUN_00511710`.
`FUN_00511B10` is the corresponding acceptance predicate: for models `0x3B`
and `0x3C` it scans six cMarket child slots and accepts the object only when
a child has model `0x42` (Bronzeware Maker); model `0x42` itself and model
`0x47` have their separate accepted paths. Once case 4 has a non-null target,
the write is exact:

1. Read `current = cMarket+0x180` and propose `current + 0x14`.
2. Classify that proposal with `FUN_00545100`: `0 → 0`, `1…0x1D → 1`,
   `0x1E…0x31 → 2`, `0x32…0x45 → 3`, `0x46…0x59 → 4`, and values above
   `0x59 → 5` (all comparisons are strict `>`).
3. Read `maximum = cMarket+0x184`. If the proposal's band exceeds
   `maximum`, retry `current + 0x13`, then decrement the offset one unit at
   a time through `current` until the band is no greater than `maximum`.
4. Store the accepted raw word through `FUN_00545140`, then finish the event
   state and notification calls in `FUN_00511860`.

Native records this arithmetic only as the research helper
`OriginalMarketStoredState.advance(...)` and its independent threshold tests
in `Sources/EmperorCore/MarketSimulation.swift` and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`. The helper is not called by
market settlement, provider refill, household coverage, or any Qin campaign
path.

This narrows the previously open source boundary but does **not** prove that
`+0x180` is food quality, popularity, inventory, or a monthly settlement
counter. The write sits inside an adjacent-object event/notification chain,
and no direct mapping from this raw word to an authored `GameData` quality or
house field was found in this pass. No source or call edge here authorizes
turning on Qin automatic migration, peddler spawning, or market coverage.

**Evidence class:** **confirmed** for constructor values (`+0x184 = 3/5`,
`+0x188 = 1`, `+0x180 = 0`), getter/setter offsets, accepted model branches,
strict band thresholds, `+0x14` proposal, downward retry through the current
value, and EN/CH identity; **unknown** remains the semantic identity of
`+0x180`, the event's gameplay trigger/timing, its relationship to cMarket
provider records and cHouseInfo, and any Native projection. Qin remains
fail-closed at those unresolved edges.

### 10.70 Ferry connector storage constructor is closed as a raw sentinel state (2026-09-01)

The canonical English executable (`8a6d2df1…6753`) and the Chinese
cross-check (`dbdeca1e…15a`) expose `FUN_004C6C50 @ 0x4C6C50`, called by the
Ferry constructor `FUN_004C5DC0 @ 0x4C5DC0`. The constructor first installs the
Ferry vtable and clears its adjacent state, then `0x4C6C50` writes:

* dword `ferry + 0x924 = 0` (the connector count), and
* exactly 500 dwords beginning at `ferry + 0x154` to `0xFFFFFFFF` (`-1`).

The span is internally consistent: `0x154 + 500 × 4 = 0x924`, so the count
word is immediately after the sentinel buffer. This is an object-construction
reset, not evidence that any connector exists or that the stored values are
already map coordinates. `FUN_004C6C70` later replaces the count and buffer via
the unresolved placement/flood/gradient chain documented in §§10.39–10.41.

Native records this byte-level boundary in the research-only
`OriginalGrandCanalLayoutCatalog.FerryStoredState` value. Its initializer and
`reset()` reproduce the zero count plus 500 `-1` slots, and tests verify both
the sentinel contents and Codable round-trip. No production map loader,
worker-routing cache, or Qin Ferry path consumes this state: the coordinate
pair source, `+0x150` gate, connector discovery caller, and object-registry
projection remain **unknown**. This closes only the constructor's raw storage
layout and does not authorize live Ferry post-processing.

**Evidence class:** **confirmed** for the constructor call edge, offsets,
500-dword span, sentinel value, and EN/CH identity; **unknown** for connector
semantics, serialized ownership, placement scheduling, and Native projection.

### 10.71 Immigrant wait stagger is decremented once per assignment day (2026-09-01)

The EN/CH `FUN_004AD4A0 @ 0x4AD4A0` body performs the shared immigrant wait
adjustment exactly once at the start of the calendar case: it subtracts
`0x33` from `DAT_00D62418` and clamps the result at zero. It then invokes the
assignment walk. The successful `FUN_004ADE10 @ 0x4ADE10` spawn reads that
already-adjusted word when composing `figure+0x3e`; its only stagger mutation
is the caller-visible `*param_3 += 0x32` after the figure was created. There is
no second `−0x33` in the per-house spawn path. The two functions are
`identical` across EN/CH in `local/source/compare-report.tsv`.

Native's `dailyMigrationAssignment` already performs the daily decrement.
Its private `spawnImmigrant` path previously decremented again before reading
the word, making later houses in the same assignment day wait less than the
source sequence. That extra decrement is removed; successful registration
continues to add `0x32` through `DeterministicMigrationState.registerImmigrantWalker`.
The regression test checks the exact `100 − 0x33 + 0x32` sequence without
claiming any unresolved meaning for the house `+0x51` term.

**Evidence class:** **confirmed** for the update count and arithmetic;
**unknown** for the semantic meaning of `house+0x51`, which remains an
explicitly supplied/fail-closed input.

### 10.72 Enemy threat quantity writer is the unified table's slot-0x23 slice (2026-09-01)

The canonical English executable (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`)
and the Chinese cross-check (`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`)
close the runtime writer that had previously been recorded as unknown. The
indexed EN/CH rows for `FUN_00522D30 @ 0x522D30`, `FUN_0054C4F0 @ 0x54C4F0`,
`FUN_005512D0 @ 0x5512D0`, `FUN_0054D850 @ 0x54D850`, `FUN_0054D580 @ 0x54D580`,
and `FUN_0054CC60 @ 0x54CC60` are `identical` in
`local/source/compare-report.tsv`.

The records are one unified 100-entry table rooted at `DAT_011A2B08`, with
stride `0xB4`; `FUN_0054D580` walks the full table and calls `FUN_005512D0`,
which clears the quantity byte at record offset `+0x28`. `FUN_0054C4F0`
allocates the enemy slice beginning at slot `0x23` (`DAT_011A43A4`) for 64
slots. Consequently the quantity address for the first enemy slot,
`DAT_011A43CC`, is the same byte as
`DAT_011A2B30 + slot*0xB4` under the unified-table view.

`FUN_00522D30` is the recovered runtime producer. On each of its normal,
fort-list, and model-`0x4E` branches it clears the selected slot's quantity
after `FUN_0054C4F0` succeeds, then, for each successful `FUN_004EA050` figure
creation, stores the figure ID in the record's link array at
`DAT_011A2B10 + slot*0xB4 + count*2`, writes figure `+0x6A = slot`, and
increments the same quantity byte. `FUN_00551D60 → FUN_00551D00` supplies the
finite link-capacity family (16, 4, or 1 depending on model family); this is
why the Native research helper rejects counts above the recovered 16-entry
array capacity rather than wrapping. `FUN_0054CC60` provides a maintenance
edge in the opposite direction: it scans active figures, reads figure
`+0x6A`, and increments the corresponding quantity. `FUN_00512550` clears a
linked quantity when the figure link is invalid or dead.

`FUN_0054F8D0 → FUN_0054F780` also clears and increments a quantity byte, but
its allocator is rooted at `DAT_011A39CC` (unified slots 21…29), a separate
friendly/special family; it is not the 64-slot enemy slice and must not be
used as its writer. A direct PE immediate-reference scan for
`DAT_011A43A4`, `DAT_011A43CC`, `DAT_011A70A4`, and `DAT_011A70CC` found no
additional simple global-base writer, which is a negative boundary only and
does not exclude indirect or archive-time population.

This closes the runtime spawn/reset/recount path, but not the serialized
archive/load prepopulation, post-load registry correspondence, complete
maintenance scheduling semantics, or a Native object-registry projection.
Therefore `OriginalInvasionThreatAggregate` remains an explicit-input
research projection and is still not wired to `EnemyMilitaryForce.soldierCount`
or `warCount`.

**Evidence class:** **confirmed** for the unified-table geometry, enemy
slot range, quantity alias, runtime spawn writer, link/recount/clear edges,
and EN/CH identity; **unknown** for archive/load population, registry
projection, and exact maintenance timing.

### 10.73 Peddler return gate is a pure budget/coordinate predicate (2026-09-01)

The canonical English executable hash is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`; the
Chinese cross-check is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
`FUN_004E3A10 @ 0x4E3A10` is indexed at
`local/source/split-merged/code/0x040000/FUN_004e3a10.c` and is marked
`identical` in `local/source/compare-report.tsv`. Its only caller in this
path is the peddler think wrapper `FUN_004E3A80 @ 0x4E3A80`, reached from the
model-23 interior entry documented in §10.17c.

The predicate returns true only when all of these conditions hold:

1. figure model byte `+0x12` is neither `0x25` (`%`) nor `0x4F` (`O`);
2. signed travelled-budget word `+0x4C` is at least the signed integer
   quotient `(signed behaviorRange × 4) / 5`, where the PE computes
   `((int16 range << 2) / 5)`; and
3. current coordinates `figure+0x1C/+0x1E` equal the saved pair
   `figure+0x15C/+0x15E`.

When true, `FUN_004E3A80` selects the market/provider return coordinates,
requests the route through `FUN_004BA580(..., rotation = 2)`, enters state
`2`, clears `+0x4C`, and clears the active route bookkeeping. When false it
continues through `FUN_004E6B70(..., selector = 8)`. A failed route request
sets figure byte `+0x16 = 2`; that failure side effect is outside the pure
predicate.

Native now exposes this exact decision boundary as
`OriginalMarketPeddlerReturnGate.shouldReturn` in
`Sources/EmperorCore/MarketSimulation.swift`, including the two model-byte
exemptions, checked `×4` arithmetic, signed division, and coordinate equality.
Focused tests cover the `60 → 48` threshold, the coordinate mismatch, and both
exemptions. The helper intentionally does not choose an endpoint, consume a
route buffer, perform collision turns, or write market/house coverage.

**Evidence class:** **confirmed** for the model exemptions, `4/5` budget
comparison, saved-coordinate equality, caller branch, and EN/CH identity;
**unknown** remains the endpoint helper-record population, route-buffer
construction/consumption, post-collision turn choice, and market coverage or
quality writer. Qin-3 peddler scheduling therefore remains fail-closed.

### 10.74 Peddler collision enters the default mode-0 branch (2026-09-01)

The canonical English executable hash is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`; the
Chinese cross-check is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
`FUN_004E8BC0 @ 0x4E8BC0`, `FUN_004E7EB0 @ 0x4E7EB0`, and
`FUN_004E71D0 @ 0x4E71D0` are each present in the split corpus and marked
`identical` in `local/source/compare-report.tsv`. `FUN_004E7EB0` invokes
`FUN_004E8BC0` after loading a route slot and again at each twentieth
substep, so this is the peddler's actual per-crossing collision entry rather
than a standalone route-builder check.

The direct source files used here are
`local/source/split-merged/code/0x040000/FUN_004e8bc0.c`,
`FUN_004e7eb0.c`, `FUN_004c72b0.c`, `FUN_004e71d0.c`, and
`FUN_004b9590.c`; the unsplit `0x4D0270` body remains the direct-PE evidence
recorded in §10.17c.

The mode bytes at this boundary are now closed by two independent source
edges. `FUN_004C72B0 @ 0x4C72B0` zeros figure `+0x21` (byte offset `0x84`)
and `+0x20` (byte offset `0x80`) in the common figure constructor. The
unsplit peddler type-table body at `0x4D0270`, recovered in §10.17c, then
writes `figure+0x80 = 0x12` before unconditionally calling
`FUN_004E3A80`. The peddler wrapper does not write `+0x21`, so a newly
constructed figure whose constructor value is still in force takes the
`+0x21 == 0` path. In that case `0x12` does not enter any of the explicitly
listed mode branches (`8/10/12/2/19/16`, `0x15`, `4`, `9`, `6`, or `0x0E`)
and falls through the function's default terrain/object branch. The corpus
also contains generic figure-state writers to offset `+0x84`; because their
peddler reachability is not closed, the unconditional claim that every later
crossing has `+0x21 == 0` remains **unknown**.

That default branch has the following **confirmed** gates and side effects:

* directional map auxiliary `DAT_013789C1[idx2 * 2] & 8`, or a nonzero
  `FUN_00424300(idx2, 0)` result, immediately sends the figure to heading
  `9`;
* when the same auxiliary has bit `2`, the current target object's vtable
  `+0x278` supplies a coordinate pair for `FUN_004EA050(..., model=0x30, ...)`;
  on success the new object is initialized, linked figures reachable through
  `+0x66` are stamped with `+0x6F = 1` and `+0x13C = newObject`, and the
  collision helper returns through the common rejection label;
* otherwise the branch evaluates map-word bits `0x40`, `0x400`, `0xC000`,
  `0x8`, and `0x4`, then object predicates including
  `FUN_004C11B0`, `FUN_00562F70`, `FUN_00568A50`, and `FUN_00415770` plus an
  owner vtable `+0xCC` callback; and
* the final `n & 0x100` guard forces heading `9` regardless of the earlier
  mode decision.

`FUN_004E71D0` is a separate retry/turn selector reached by
`FUN_004E6D80` when the candidate count and fallback counter require a new
heading; it is not called directly by `FUN_004E8BC0`. Its candidate flags
come from directional map arrays, object callbacks, and roadblock/gate/wall
predicates. For authored peddler model `23`, the shared candidate builder
`FUN_004B9590` uses the ordinary `0x40` terrain mask (only model bytes `O` and
`N` use `0x10C`) and the model's visit-score selector is `7`; the concrete
meaning of those arrays, callbacks, and score rows is still not recovered.

This closes the peddler collision *mode-0 entry branch* and the hard terrain
stop, but not a legal route implementation. The object-vtable callbacks, auxiliary
array semantics, spawned-object lifecycle, post-collision route state, and
coverage/writer ordering remain **unknown**. Native therefore keeps the
Qin-3 peddler route/coverage bridge fail-closed; no fixed route or generic
barrier approximation is promoted by this finding.

**Evidence class:** **confirmed** for the EN/CH-identical call chain, mode-byte
values, the conditional default-branch selection when `+0x21 == 0`, listed bit
tests, and final heading-`9` guard; **unknown** for later `+0x21` state at every
crossing, callback semantics, object side effects beyond the recorded stores,
route recovery after rejection, and downstream market or house-coverage
writes.

### 10.75 Peddler mode-`0x12` route primitive is shared with venue figures (2026-09-01)

The route-builder branch itself is now separable from the unresolved peddler
collision consumer. In `FUN_004E83E0 @ 0x4E83E0`, route mode `+0x80 == 0x12`
calls `FUN_005B00D0(currentX, currentY, targetX, targetY, 0)`. The peddler
wrapper's endpoint result is already copied into figure `+0x2C/+0x2E` before
this builder runs, so the builder consumes the same current/target coordinate
pairs as the venue mode-`0x12` path. `FUN_005B00D0` seeds the shared depth
array and expands only the four cardinal neighbours through
`FUN_005B0220`; each neighbour is admitted when its primary routing word
intersects `0x010C`.

On a reached target, `FUN_004E83E0` first asks `FUN_005B18B0` with selector
`4`, which reconstructs cardinal direction codes using the shared
`DAT_0085DE64` table. If that reconstruction returns no steps, it retries
selector `8`, which permits the full eight direction table. A successful
sequence is written to the per-figure route buffer and publishes the route
slot/count through figure `+0x42/+0x44/+0x46`; `FUN_004E8B40` and
`FUN_004E8BC0` consume that state on the next movement boundary.

The EN/CH function bodies for `FUN_004E83E0`, `FUN_005B00D0`,
`FUN_005B0220`, `FUN_005B18B0`, and `FUN_004E8BC0` are present in the split
corpus and marked `identical` in `local/source/compare-report.tsv`. The source
files are under `local/source/split-merged/code/0x040000/` and
`0x050000/` with the corresponding function names. This gives a confirmed
shared route primitive rather than a venue-only assumption.

Native now exposes this primitive as
`OriginalGrandCanalLayoutCatalog.marketPeddlerRoute` in
`Sources/EmperorCore/GrandCanalSimulation.swift`; its focused test asserts the
`0x010C` admission domain, cardinal-first route order, and full-eight fallback
boundary. It is deliberately not wired into live Qin peddler scheduling:
the endpoint record's semantic owner, collision/object callbacks, route state
after a heading-`9` rejection, and market/house-coverage writer ordering
remain **unknown**.

**Evidence class:** **confirmed** for the peddler mode-`0x12` dispatch, the
`0x010C` primary-cache mask, cardinal-first then full-eight reconstruction,
route-buffer counters, and EN/CH identity; **unknown** for endpoint semantics,
collision side effects, post-rejection route recovery, and downstream market
settlement or coverage writes.

### 10.76 Shared crossing callback provider-word update (2026-09-01)

The provider-side write in the shared crossing callback is now isolated as a
raw arithmetic contract. `FUN_004EACD0 @ 0x4EACD0` is reached by both
`FUN_004E7EB0 @ 0x4E7EB0` (the twentieth-substep crossing boundary) and the
`FUN_004E6D80 @ 0x4E6D80` scheduler path. Its home-object dispatch is either
`FUN_00429E10 @ 0x429E10` (hero callback) or the home object's vtable `+0x28`
method; after that callback returns, the non-null provider object is updated
at byte offset `0x1C` (`p + 7` in the decompiler):

```text
stored = signed16(provider[+0x1C]) + signed16(callbackResult)
provider[+0x1C] = signed16(stored)
if provider[+0x1C] > 300: provider[+0x1C] = 300
```

The assignment is a genuine 16-bit store, so overflow wraps before the
signed comparison; negative values are not clamped. The callback then
independently calls `FUN_004B9460 @ 0x4B9460`, which saturates the selected
3-bit visit field for the current map cell. `FUN_00429DF0 @ 0x429DF0` is the
market/ordinary-provider wrapper that forwards to the radius-two
`FUN_00429E10` scan. The EN/CH bodies for `FUN_004EACD0`, `FUN_004E7EB0`,
`FUN_004E6D80`, `FUN_00429DF0`, `FUN_00429E10`, and `FUN_004B9460` are all
marked `identical` in `local/source/compare-report.tsv`; the corresponding
split files are under `local/source/split-merged/code/0x040000/`.

`OriginalProviderCrossingAccumulator.nextValue` in
`Sources/EmperorCore/MarketSimulation.swift` reproduces only this signed-
short update and upper clamp. Its tests cover ordinary addition, the `300`
ceiling, negative results, and 16-bit wraparound. This does **not** identify
the provider object's class, the business meaning of `+0x1C`, or the callback's
coverage/market writer semantics; those remain **unknown**, and no Qin live
coverage or settlement path is enabled from this helper.

**Evidence class:** **confirmed** for the byte offset, signed widths, wrapping
store, upper-only clamp, caller/callee chain, and EN/CH identity; **unknown**
for provider-object identity, field semantics, callback return provenance, and
downstream Qin settlement ordering.

### 10.77 Market-owned peddler crossing reaches the normal house writer (2026-09-01)

The market-to-house callback edge is now closed statically. In the canonical
English executable (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`),
`FUN_004EACD0 @ 0x4EACD0` resolves a figure's home object from `figure+0x62`
and, for a non-hero figure, calls that object's vtable `+0x28` with the figure
and radius `2`. A cMarket home uses vtable `0x7B6F3C`, whose `+0x28` entry is
`FUN_00429DF0 @ 0x429DF0`. That wrapper forwards to
`FUN_00429E10 @ 0x429E10` with the cMarket receiver and a null callback.

`FUN_00429E10` scans the Chebyshev rings `1...2`, resolves each admitted map
object, and when a non-null receiver is supplied invokes its vtable `+0x2C`
with `(figure, object)`. For cMarket this slot is the unsplit
`FUN_005437B0 @ 0x5437B0` normal market-delivery writer. The direct PE vtable
entries are therefore:

| edge | address/offset | evidence |
| --- | --- | --- |
| crossing handler | `FUN_004EACD0 @ 0x4EACD0` | split corpus, EN/CH `identical` |
| cMarket radius wrapper | vtable `+0x28` → `FUN_00429DF0 @ 0x429DF0` | split corpus, EN/CH `identical` |
| radius scan | `FUN_00429E10 @ 0x429E10`, radius `2` | split corpus, EN/CH `identical` |
| cMarket house callback | vtable `+0x2C` → `FUN_005437B0 @ 0x5437B0` | direct PE vtable; EN/CH bytes identical over `0x5437B0…0x543BBB` |

The split sources used are
`local/source/split-merged/code/0x040000/FUN_004eacd0.c`,
`FUN_00429df0.c`, and `FUN_00429e10.c`; the identity rows are in
`local/source/compare-report.tsv` at `0x4eacd0`, `0x429df0`, and `0x429e10`.
There is no `functions-index.csv` row for the unsplit writer, so the writer
identity comes from the direct PE bytes and vtable pointer rather than a
decompiler split. The pure Native descriptor
`OriginalMarketPeddlerCoverageDispatch.canonical` records these addresses,
offsets, and radius for regression purposes.

This closes the question of whether a market-owned peddler can reach the
ordinary cMarket house-delivery callback. It does **not** recover how the
cMarket provider records are populated, what `+0x21C`/`+0x264` mean in the
settlement path, how collision rejection rebuilds a route, or whether other
writers also update `cHouseInfo+0x36`. Native therefore keeps this descriptor
research-only and does not enable the Qin peddler/coverage bridge from it.

**Evidence class:** **confirmed** for the EN/CH-identical crossing, wrapper,
radius-two scan, cMarket vtable offsets, and writer address; **unknown** for
provider-record population, route/collision recovery, complete writer census,
and the Native settlement projection.

### 10.78 Canonical EN/CH parity for the immigrant think body (2026-09-01)

The generated corpus has no split entry for `FUN_004C9FD0`, so its earlier
state-6/7/8 reconstruction was taken from the canonical English PE. A
direct read-only comparison of the canonical input pair closes the
build-variant question for this missing body: with `.text` VMA `0x00401000`
and raw section offset `0x1000`, the complete function slice
`0x004C9FD0…0x004CA337` (872 bytes; exclusive end `0x004CA338`) has SHA-256
`7a22da2c8c2d0f2e4c502b1744f2a28b4e1d772f355817c739a922f4861878e3` in both
hash-matched inputs:

| build | executable SHA-256 | function-slice SHA-256 | bytes |
| --- | --- | --- | ---: |
| canonical EN | `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` | `7a22da2c8c2d0f2e4c502b1744f2a28b4e1d772f355817c739a922f4861878e3` | 872 |
| canonical CH | `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` | `7a22da2c8c2d0f2e4c502b1744f2a28b4e1d772f355817c739a922f4861878e3` | 872 |

The disassemblies are byte-for-byte identical across the whole range, not
only at the already documented arrival writes. This confirms that the
state-6 wait, state-7 reroute/failure/arrival-direction branches, state-8
capacity clamp and `cHouseInfo+0x3C` gate, `house+0x20` add, `+0x32` cleanup,
and sprite-tail logic described in §§5.2–5.4 do not have a canonical EN/CH
control-flow divergence. It does **not** identify the missing semantic
inputs (`DAT_00D62408`, `house+0x24`, `cHouseInfo+0x3C`), archive-side house
specialization, or the Native projection of the figure/house fields.

This is direct PE corroboration because the function is absent from
`local/source/split-merged` and therefore has no `compare-report.tsv` row;
it does not promote the decompiler's heuristic names to original symbols.
The sibling Wineskin executable mentioned above remains non-canonical and is
not used for this parity claim.

**Evidence class:** `confirmed` for the complete canonical EN/CH byte identity
and slice boundaries; `unknown` for the semantic inputs, archive/runtime
specialization, and Native arrival projection. No runtime wiring changed.

### 10.79 Ferry `+0x150` is a paired-endpoint handle, not a capacity field (2026-09-01)

The remaining `FUN_004C6C70` gate can now be named structurally. The Ferry
object constructor `FUN_004C5DC0 @ 0x4C5DC0` installs the complete vtable at
`0x7AFBD8`, clears its adjacent state, and calls `FUN_004C6C50 @ 0x4C6C50`
(count `+0x924`, 500 sentinel slots at `+0x154`). The connector methods occupy
the secondary vtable segment at `0x7AFE40` (`0x7AFBD8 + 0x268`): relative to
the complete object vptr, `+0x278` is `FUN_004C6E80` (coordinate-pair
provider), `+0x27C` is `0x42AA80` (boolean validity provider), and `+0x280`
is `FUN_004C6EE0` (coordinate fallback). The split corpus has the adjacent
`FUN_004C6EC0 @ 0x4C6EC0` boolean body and `FUN_004C6EE0 @ 0x4C6EE0`
coordinate fallback body; only the latter has a `compare-report.tsv` split
row, while direct EN/CH bytes for the former are identical. The complete
connector vtable slice `0x7AFBD8…0x7AFE7F` (680 bytes) hashes to
`ade4e7cf80e94ca3b8ce8d08f5465010f607493c0802364c48c452fc8e71b8ad` in both
canonical inputs. The unsplit validity body
`0x004C6EC0…0x004C6EDE` (30 bytes) hashes to
`b7232270598f394f048dcc81a7ea806c40f67ed0115917d9008683c0748e4d16` in both
the English `8a6d2df1…6753` and Chinese `dbdeca1e…15a` executables.

The field at `+0x150` is written by two independent, EN/CH-identical paths:

* `FUN_004C5B50 @ 0x4C5B50` is a direct setter (`this+0x150 = value`).
* `FUN_004C68D0 @ 0x4C68D0`, reached by `FUN_004C6980 @ 0x4C6980`, keeps a
  pending endpoint in `DAT_01031488`. On the second endpoint it resolves both
  object IDs through `FUN_0047F1B0` and writes them mutually:
  `firstObject+0x150 = secondId` and `secondObject+0x150 = firstId`.
  The first click/selection path is tagged with `FUN_00547E60(0x11E,0,0)`;
  `FUN_004C6960` cancels that pending endpoint by setting its byte state to 6.

`FUN_004C6C70 @ 0x4C6C70` first asks the Ferry vtable `+0x278` for the local
coordinate pair, then returns false unless `this+0x150 > 0`. When positive, it
resolves that stored endpoint through the global object registry at
`DAT_008C7634`, asks the partner's `+0x278` for its coordinates, and only then
calls `FUN_005B33C0` (placement flood) and `FUN_005B3670` (500-entry cardinal
connector walk, selector `1001`). Therefore the gate is a paired-endpoint
identity/registration requirement, not the Ferry model's authored `80` value
in `GameData/Model/EmperorBuildingModels.txt` row 210.

This closes the field's write shape and its consumer ordering for the
canonical English executable (`8a6d2df1…6753`); `local/source/compare-report.tsv`
marks `0x4C5B50`, `0x4C5DC0`, `0x4C68D0`, `0x4C6980`, `0x4C6C50`, `0x4C6EE0`, and
`0x4C6F40` as EN/CH `identical`. It does not recover the semantic object class,
the exact `+0x278`/`+0x27C` provider bodies (the former's split boundary is
missing), the object-registry lifecycle, or the mapping from the two PE
coordinate/layer arrays into Native's serialized map. Ferry connector
computation and worker routing therefore remain fail-closed; no live placement,
save-state, or Qin simulation path changed.

**Evidence class:** **confirmed** for the mutual-ID writes, positive gate,
registry lookup, call order, constructor sentinels, and EN/CH identity;
**unknown** for endpoint class semantics, provider implementation details,
registry lifetime, coordinate/layer projection, and Native integration.

### 10.80 Ferry dynamic edge layer is derivable from terrain words, with live-object mapping still open (2026-09-01)

The split corpus contains the complete `FUN_005AD970 @ 0x5AD970` body and its
full-grid wrapper `FUN_005ADD10 @ 0x5ADD10`. `FUN_005ADD10` first fills the
`0x32C4`-dword byte layer at `DAT_0136BEB0` with `0xFF` (`-1`), then calls the
bounded rebuild over `x=0...DAT_0101D0C0-1`, `y=0...DAT_0101D0C4-1`.
`compare-report.tsv` marks both functions `identical` for EN/CH. The direct
canonical slices are also byte-identical: `0x5AD970...0x5ADD10` (928 bytes)
hashes to
`64b3e739e40f06fc35bbe8c7104985e9d9607fb98e78c118725cece23129d750`, and
the first 32 bytes of `FUN_005ADD10` hash to
`3e6f7c2df2f6ec87221848f5863567d5881262d00ea2eee9d08794de9d0091e2`, in
both the canonical English executable
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and
Chinese executable
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`).

For each cell, `FUN_005AD970` writes one signed byte to the dynamic layer. The
confirmed order is:

1. Clamp the requested rectangle to the map dimensions. A cell is `-1` when
   its terrain word has `0x100`, lacks `0x4`, or has `0x80000`.
2. Preserve `-1` when the existing dynamic byte is `-6`, or when any of the
   eight neighbouring terrain words lacks `0x4`.
3. Unless the auxiliary byte at `DAT_00F2B290 + index` is nonzero **and**
   `FUN_004BA230(index, 4)` returns exactly `3`, require all eight neighbours
   to contain `0x04080000`; otherwise write `-1`.
4. A surviving cell writes `-2` (`0xFE`) on the top/bottom rows or left column,
   writes `-2` for every non-final column, and writes `0` only on the final
   column. The source's arithmetic is
   `(x <= width-2 ? -1 : 0) & 0xFE` after the explicit row/left-boundary
   checks.
5. If the live object slot at `DAT_00FC3750 + index` is nonzero and the byte
   is not `-1`, the object model is resolved. Models `0x38` (`FUN_005E1720`)
   and `0xD2` (`FUN_004BDB60`) force `-1`; other models retain the byte after a
   side-effect-only `FUN_0042B740` query.

`FUN_005B33C0` consumes this one-byte layer through aliases: north is
`layer[index] - 0xE4`, east is `layer[index+1]`, south is `layer[index] + 0xE4`,
and west is `layer[index-1]`. Its terrain-block tests read the low bit of the
adjacent terrain-word high byte (`terrain >> 16 & 1`) at the candidate cell.
Therefore the Native research helper
`OriginalGrandCanalLayoutCatalog.deriveFerryWaterEdgeLayer` accepts explicit
row-major terrain words, serialized road/water auxiliary bytes, the
previous layer (for the `-6` sentinel), and explicit object-model states. It
reproduces the arithmetic above and returns `nil` when dimensions or an
occupied object's model identity are not supplied. It is intentionally not
wired into `CitySimulation`: object-registry identity, padded-PE index
projection, and the caller's coordinate-to-layer mapping remain unresolved.

**Evidence class:** **confirmed** for the layer reset, branch masks, neighbour
order/requirements, boundary arithmetic, model blockers, aliases, and EN/CH
parity; **inferred** for row-major Native indexing and out-of-bounds treatment
in the standalone helper; **unknown** for live object-registry projection,
PE padded-array origin, and the runtime caller's exact coordinate mapping.

### 10.81 Qin archive loading stops at the generic `Building` callback boundary (2026-09-01)

The canonical English executable
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and the
Chinese executable
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`) share
the same relevant loader control flow. `local/source/compare-report.tsv`
marks `0x42D790`, `0x42D0E0`, `0x42B590`, `0x5F01F0`, and `0x4271B0` as
`identical`; the evidence is from:

- `local/source/split-merged/code/0x040000/FUN_0042d790.c`
- `local/source/split-merged/code/0x040000/FUN_0042d0e0.c`
- `local/source/split-merged/code/0x040000/FUN_0042b590.c`
- `local/source/split-merged/code/0x040000/FUN_004271b0.c`
- `local/source/split-merged/code/0x050000/FUN_005f01f0.c`

When the archive-load branch receives a record count, `FUN_0042D790` loops
over the records and, for each one, calls `FUN_0042D0E0` followed by
`FUN_0042B590`. `FUN_0042D0E0` calls `FUN_0077FD90(&PTR_s_Building_00817890)`;
the literal table therefore supplies the generic class token `Building`, not
a service-specific constructor. `FUN_0042B590` obtains the current list end
through `FUN_004F8200` and inserts the object with `FUN_005F01F0`, whose body
delegates to `FUN_005C1670`.

For records whose active byte is nonzero, the loader invokes the object's
vtable slot `+0xC0`. The generic implementation at `FUN_004271B0` only asks
the object predicate at vtable `+0x150`; when that predicate is true it calls
`FUN_0042B6B0` and `FUN_0042B580`. No service-provider constructor, provider
slot (`+0x2D`) write, parent-link repair, or model-specific vtable replacement
is reached by this generic callback boundary. The later
`FUN_0052F030`/`FUN_0052F1D0` repair switch is a separate admitted-model pass,
already catalogued above, and does not change this loader conclusion.

`OriginalMapArchiveRepairCatalog` records these exact addresses and the
`Building` token so tests and future implementation work can refer to the
recovered boundary without depending on the ignored corpus. This is a
research catalog only. Qin provider registration, archive object identity,
and the projection from serialized records into the live provider registry
remain **unknown**, so Native continues to fail closed rather than inventing a
service specialization during map load.

**Evidence class:** **confirmed** for the generic descriptor token, insertion
order, callback slot, helper call chain, and EN/CH parity; **unknown** for
provider-class registration, serialized object identity, and any missing
post-load projection outside this callback path.

### 10.82 Direct-call census closes the two writer boundaries, not their indirect sources (2026-09-01)

To prevent a false Qin market bridge, the canonical PE `.text` sections were
scanned for x86 `CALL rel32` targets in both hash-identified inputs. The
English executable is `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`;
the Chinese executable is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`. The
results are byte-for-byte the same:

* `FUN_005D2C10 @ 0x5D2C10` has exactly three direct call instructions, at
  caller addresses `0x496CFC`, `0x524159`, and `0x54DE6F`. The indexed
  functions are `Adding_plunder_type_pctd_amount_pc_2 @ 0x496CA0`,
  `Spoils_acquired_from_pctd_of_pctd @ 0x524120`, and
  `Adding_plunder_type_pctd_amount_pc @ 0x54DB10`. Their source bodies all
  pass explicit plunder/spoils quantities to the same fixed vector returned
  by `FUN_005D2B60`; no market, stall, migration, or monthly-settlement
  function directly calls this writer.
* `FUN_004AEDF0 @ 0x4AEDF0` has exactly three direct call instructions, at
  `0x4AC3A2`, `0x4F157E`, and `0x518698`. These belong to
  `FUN_004AC2B0 @ 0x4AC2B0` (the `DAT_00C82EF8 == 0x11` dispatch case),
  `FUN_004F1560 @ 0x4F1560` (the fixed simulation-pass sequence), and
  `FUN_00518690 @ 0x518690` (the pass starts with the same refill call and
  then performs its own live-object iteration). All three caller rows and
  the callee are `identical` in `local/source/compare-report.tsv`.

This is a complete **direct** caller inventory for the two functions in the
hash-matched builds; it does not enumerate indirect calls through vtables or
function-pointer tables. The cMarket/provider `+0x154` dispatch therefore
remains the only unresolved quantity source: direct call tracing neither
populates the six cMarket records nor connects the fixed plunder vector to
Qin market settlement. Native must keep the Qin market/peddler bridge
fail-closed until the indirect provider population and key/quantity projection
are recovered.

**Evidence class:** **confirmed** for the PE direct-call counts, caller
addresses, caller identities, and EN/CH parity; **unknown** for indirect
vtable/table dispatch, provider-vector population, and the downstream Native
market projection.

### 10.83 cMarket `+0x1B8` aggregation admits only empty cStall children for selector `-1` (2026-09-01)

The child-admission predicate used by `FUN_00544A80(-1)` is now closed at the
instruction level. `GameData/Model/EmperorBuildingModels.txt` identifies
decimal `62` (`0x3E`) as **Empty Shop**, decimal `64…70` (`0x40…0x46`) as the
seven named shop models, and decimal `59/60` (`0x3B/0x3C`) as Common/Grand
Market Square. The indexed factory chain is explicit: `FUN_00543D90 @
0x543D90` recognizes `0x3B/0x3C` and dispatches `FUN_00543450 @ 0x543450`
(cMarket vtable `0x7B6F3C`), while `FUN_005418D0 @ 0x5418D0` recognizes
`0x3E…0x46` and dispatches `FUN_00540770 @ 0x540770` (cStall vtable
`0x7B6C5C`). `FUN_00540E70 @ 0x540E70` replaces a selected `0x3E` child with
the requested named shop model and relinks the parent's `+0x15C[slot]` entry.

The cStall vtable's `+0xC8` entry is `FUN_005408D0 @ 0x5408D0`. Its complete
EN/CH-identical body is the 64-byte slice `0x5408D0…0x54090F`, SHA-256
`eb70e5d6155c8e41d264d4270fedd556ee03f2b521b9063b14bb5f96db799d` in both
canonical executables (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
and `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`).
The predicate first accepts selector `-2`; otherwise it accepts when the
object model word at `+0x14` equals the selector, with one special case:
selector `-1` is accepted only when that model word is `0x3E`. Therefore:

* an Empty Shop child (`0x3E`) passes `+0xC8(-1)`;
* every filled named shop child (`0x40…0x46`) fails `+0xC8(-1)`; and
* `FUN_00544A80(-1)` adds the child `+0x44` word only for the first case.

`FUN_00544EC0 @ 0x544EC0` applies the same `+0xC8(-1)` gate before summing
each child's `+0x1B8` result, and the cStall `+0x1B8` implementation is the
signed-short read `movsx eax, word ptr [ecx+0x44]; ret` (`FUN_00416B10 @
0x416B10`). Consequently, after `FUN_00540E70` fills a market slot, both
market aggregates intentionally stop admitting that cStall for selector
`-1`; the remaining `+0x44` value is not a recoverable “active shop worker”
total. The peddler threshold numerator in `FUN_00543ED0` therefore cannot be
reproduced by summing all named-shop records, and it cannot be mapped to the
Native market/provider coverage count without an additional provider-side
contract.

`local/source/compare-report.tsv` marks `0x5408D0`, `0x540E70`, `0x5418D0`,
`0x543450`, `0x543D90`, `0x544A80`, and `0x544EC0` as `identical` for EN/CH.
The result is a strict negative boundary, not a replacement algorithm:
Native must not use cMarket `+0x1B8`, `FUN_00544A80(-1)`, or cStall `+0x44` as
market worker coverage or household-service truth. The indirect provider
population, the semantic label of `+0x44`, and the cMarket-to-house quality
projection remain **unknown**, so Qin stays fail-closed.

Native records only this admitted selector contract in
`OriginalMarketChildAdmission.cStallAdmits`; the helper returns `nil` for
non-cStall models and is not called by the campaign scheduler or settlement
path.

The cStall `+0x1B8` implementation is also exposed as the type-limited
`OriginalMarketChildWorkerValue.value` primitive. It sign-extends the raw
`+0x44` word and rejects non-cStall model IDs. This records the virtual read
without assigning a worker/coverage meaning or using it in Qin settlement.

**Evidence class:** **confirmed** for the model-ID factory sets, cMarket and
cStall vtables, replacement edge, selector `-1` admission predicate, and
aggregate call order; **unknown** for the player-facing meaning of `+0x44`,
provider-record population, and downstream coverage/quality projection.

### 10.79 Normal cMarket house-delivery pass order (2026-09-02)

The unsplit normal market writer `FUN_005437B0 @ 0x5437B0` performs its
non-Dinners household passes over six contiguous `0x40`-byte records beginning
at `0x857344`. In each iteration the first dword is the cMarket record slot
used for the `+0x1E8` count decrement; the dword immediately preceding the
record is the raw commodity key passed to the market `+0x264` quantity accessor.
The resulting order is:

| writer record | table address | cMarket slot | commodity key |
| ---: | ---: | ---: | ---: |
| 0 | `0x857344` | 1 | `0x13` Hemp |
| 1 | `0x857384` | 2 | `0x0D` Tea |
| 2 | `0x8573C4` | 3 | `0x19` Ceramics |
| 3 | `0x857404` | 4 | `0x16` Lacquerware |
| 4 | `0x857444` | 5 | `0x17` Bronzeware |
| 5 | `0x857484` | 6 | `0x18` Silk |

The Dinners key `0x1C` is handled by the writer's separate branch before this
loop. The table keys match the authored market shop rows in
`GameData/Model/EmperorBuildingModels.txt` and `Trade.txt`; this is an order
and slot identity, not evidence that Native `MarketSquare.inventory` is the
original cMarket record array.

`OriginalMarketHouseDeliveryPassCatalog` records these six exact entries for
tests and future source tracing. It is deliberately research-only: provider
record population, quantity ownership, route/collision state, and the
provider-to-Native settlement projection remain **unknown**, so Qin campaign
market settlement stays fail-closed.

**Evidence class:** **confirmed** for the six-record stride, addresses, raw
keys, slot order, and separate Dinners branch from the hash-matched canonical
EN/CH PE bytes (`0x5437B0…0x543BBB`, SHA-256
`3ef66c67084cb06aca47a741ad44c71304821948834509d5b75597da30678887`);
**unknown** for provider-record population and all downstream Native mapping.

### 10.80 cStall deposit splits accepted quantity from parent overflow (2026-09-02)

The cStall cart-deposit boundary is now represented as a single raw result
without attaching the unresolved parent callback to Native inventory. The
hash-matched EN/CH cStall body `FUN_00541760 @ 0x541760` (vtable `+0x260`;
263-byte identical slice documented in §10.63) resolves the parent cMarket,
selects the stall's registered record through `+0x2D8(this+0x150)`, and calls
`FUN_005D2790(record, key, amount)`. `FUN_005D2790 @ 0x5D2790` writes
`record+4 = key`, adds to `record+8`, clips only above `record+0xC`, and
returns the clipped overflow. The cStall body then calls the parent cMarket
`+0x154` with that overflow only; its second method argument is the separate
cart type-count byte and is not inferred as a Native commodity quantity.

The indexed model-25 cart caller (`0x4D2970…0x4D2BCA`, identical EN/CH slice
documented in §10.63) pushes the record key from `figure+0x88`, the type-count
byte from `figure+0x13`, and amount `100`. Thus a full 400-capacity record
accepting 10 of those 100 units forwards 90, while an empty record accepts all
100 and forwards zero. This is a record/overflow split only: the parent refill
consumer, monthly/external source, overflow ownership, and provider-to-house
settlement remain **unknown**.

Native exposes the side-effect-free
`OriginalMarketStallDeposit.deposit` helper and regression test. It delegates
the already-confirmed `OriginalMarketProviderStocking` semantics, reports
`acceptedAmount = amount - overflow`, and never invokes a cMarket callback or
mutates `MarketSquare.inventoryByCommodityID`. Qin market settlement remains
fail-closed.

**Evidence class:** **confirmed** for cStall receiver/vtable, record lookup,
key/amount order, upper-capacity clipping, overflow-only parent call, and the
model-25 argument values; **unknown** for the parent callback's second-argument
meaning, overflow source/ownership, provider registration, and all Native
quality/coverage/settlement projection.

### 10.85 Monthly Dinners depletion is exposed as a raw house-info boundary (2026-09-02)

The month-wrap consumer `FUN_00518690 @ 0x518690` is EN/CH-identical in
`local/source/compare-report.tsv` and is reached from the month-boundary
caller `FUN_004AC650 @ 0x4AC650`. For each live house, the body reads the
authored food requirement from model column `8`, computes
`floor(signedHouseResidents * 25 / 100)` through `FUN_00503E20` (`25`) and
`FUN_00408B80`, then applies one of two branches:

* normal (`DAT_00C5CDA0 == 0`): only a positive requirement enters the Dinners
  stock word at `cHouseInfo+0x12`; the draw is subtracted when stock is enough,
  otherwise the remaining stock is consumed, and an exhausted word is cleared
  together with the raw quality byte at `cHouseInfo+0x36`;
* cheat/debug (`DAT_00C5CDA0 != 0`): the stock word is replaced by the draw and
  the quality byte is written to raw `0x14` (20), without adding to the normal
  consumed-total accumulator.

The source stores the per-house consumed amount into the global
`DAT_0131252C` after the vector walk. It does not identify the provider-record
source, the market callback that supplied the stock, or a Native settlement
projection. `OriginalMarketMonthlyFoodDepletion.apply` in
`Sources/EmperorCore/MarketSimulation.swift` exposes this field-level result
(`stock`, `qualityRawValue`, `consumedAmount`) with explicit normal/zero-
requirement/cheat branches. A focused test covers a partial draw, stock
exhaustion (including quality clear), zero requirement no-op, and the cheat
replacement. The helper has no campaign caller; Qin provider population,
market-to-house delivery, and quality/coverage settlement remain **unknown**
and the production gate stays fail-closed.

**Evidence class:** **confirmed** for the EN/CH function identity, month-wrap
caller, model-column/25% draw, normal shortage handling, quality clear,
cheat writes, and aggregate counter; **unknown** for provider ownership and
Native settlement wiring.

### 10.86 Ferry placement flood terrain-byte indices corrected (2026-09-02)

The indexed EN/CH-identical body `FUN_005B33C0 @ 0x5B33C0` was re-read at the
instruction/address level to verify which cell each terrain-block byte tests.
The four directional passability layers and terrain-byte layers are not
indexed uniformly:

* north (`idx2 - 0xE4`) reads passability at the current cell
  (`DAT_0136BDCC[idx2]`) and terrain byte `DAT_00F6A9E0[(idx2-0xE4)*4+2]`
  at the candidate cell;
* east (`idx2 + 1`) reads passability at the candidate
  (`DAT_0136BEB0[idx2+1]`) but terrain byte
  `DAT_00F6A9E4[idx2*4+2]` at the current cell;
* south (`idx2 + 0xE4`) reads both passability and terrain byte at the current
  cell (`DAT_0136BF94[idx2]` and `DAT_00F6AD70[idx2*4+2]`); and
* west (`idx2 - 1`) reads both values at the current cell
  (`DAT_0136BEAF[idx2]` and `DAT_00F6A9DE[idx2*4]`).

`OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood` now preserves
this asymmetry: only north selects `terrainBlockByteByDirection` at the
candidate index; east/south/west select the current index. A focused
regression blocks east using only the current-cell terrain byte and blocks
north using only the candidate-cell byte, distinguishing the recovered
address arithmetic from a uniform candidate-cell approximation. The helper
remains explicit-input research scaffolding; PE-layer projection, Ferry
placement integration, serialized connector ownership, and Qin reachability
are still unknown, so the migration producer remains fail-closed.

**Evidence class:** **confirmed** for all four passability/terrain index
expressions, direction order, and EN/CH identity; **unknown** for mapping the
PE layers into Native map state and for the live Ferry placement caller.

### 10.87 cMarket construction is admitted only for model IDs 59/60 (2026-09-02)

The hash-matched EN/CH executable keeps the cMarket constructor behind a
small model recognizer. `FUN_00543D90 @ 0x543D90` returns true only when its
input is `0x3B` (59) or `0x3C` (60). `FUN_005D3580 @ 0x5D3580` calls that
recognizer before allocating the cMarket object and dispatches to
`FUN_00543450 @ 0x543450`; the constructor chooses the common helper for 59
and the Grand helper for 60. The relevant slices are byte-identical between
the canonical English build
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and
Chinese build
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`), as
checked in `local/source/compare-report.tsv` and the corresponding
`decompiled-en.c`/`decompiled-ch.c` bodies.

This closes the constructor identity but does not provide an archive bridge:
`FUN_0042D0E0` still supplies the generic `Building` class token during map
load, and the Qin generic records have a zero serialized base type word and
provider slot `-1` (see §§10.81 and the Qin archive tests). Consequently no
source-backed path currently connects those records to model 59/60 cMarket
instances or to the provider registry. `OriginalMarketCatalog` records the
three addresses and the exact admitted ID set for future tracing; it is
research metadata only, and Qin market settlement/automatic migration remains
fail-closed.

**Evidence class:** **confirmed** for recognizer inputs, constructor/factory
addresses, helper split, and EN/CH parity; **unknown** for how a live market
object is created from authored Qin state, provider-record population, and
Native settlement projection.

### 10.88 Peddler endpoint rectangle scan order is closed (2026-09-02)

The hash-matched EN/CH bodies for `FUN_004BA370 @ 0x4BA370` and
`FUN_004BA580 @ 0x4BA580` are marked `identical` in
`local/source/compare-report.tsv`. `FUN_004E3A80` supplies the peddler's
selected map anchor, the cMarket span word, and a retry limit of `2` to
`FUN_004BA580`. The wrapper tries
`FUN_004BA370(anchorX, anchorY, span, rotation)` for rotations `0…limit`,
stopping at the first success.

For one attempt, `FUN_004BA370` computes the inclusive rectangle

```
x = max(0, anchorX - rotation) … min(mapWidth - 1, anchorX + span - 1 + rotation)
y = max(0, anchorY - rotation) … min(mapHeight - 1, anchorY + span - 1 + rotation)
```

and visits rows in y-ascending order, with x ascending inside each row. An
empty clamped rectangle returns failure. Candidate object callbacks, terrain
flags, and the twelve-entry component-rank arbitration occur after this scan
ordering and are represented separately by
`OriginalMarketPeddlerEndpointSelection`.

`OriginalMarketPeddlerEndpointScan.rectangularPoints` records this pure
ordering/clamp contract and regression tests cover ordinary order, edge
clamping, an empty intersection, and the wrapper's non-negative retry domain.
The span remains an explicit input: the static corpus proves it is read from
the cMarket `+0x1C`/`+0x19C` path, but does not establish a Native footprint or
route-grid meaning for that word. Therefore no campaign route, collision,
coverage, or settlement code consumes this helper; Qin remains fail-closed.

**Evidence class:** **confirmed** for the formulas, inclusive bounds,
row-major ordering, retry sequence, and EN/CH parity; **unknown** for the
semantic identity of cMarket `+0x1C`, the map/cache projection, and every
downstream provider/house settlement edge.

### 10.89 cMarket primary access-cache control flow is bounded (2026-09-02)

The EN/CH-identical `FUN_005B1080 @ 0x5B1080` is called by
`FUN_00541220 @ 0x541220` after a source candidate exists. Its caller first
passes the cMarket `+0x2A/+0x0B` map coordinate pair. `FUN_005B1080` clears
`DAT_01391FE0` through `FUN_00521140`, seeds that cell with `1`, and expands
the queue in north/east/south/west order. A candidate is admitted only when
its cache word is still zero and its direction-specific PE layer intersects
`0x010C`; its cache value is the current cell's value plus one. The queue
cursor wraps at `0xCB0F`, matching the `0xCB10`-cell cache capacity.

The four source operands are `DAT_013789C0` (north), `DAT_013789C2` (east),
`DAT_01378B88` (south), and `DAT_013789BE` (west). Their mixed indexing and
the four output-buffer aliases are recorded in the correction in §10.91
below and are exposed by `OriginalMarketAccessFlood.build`.

This bounds the static cache control flow only. The PE layer arrays' map projection,
provider registry, cMarket callback `+0x1AC`, and quality/coverage/settlement
consumers remain unknown. The helper is not called by Qin campaign code, so
the market and migration gates remain fail-closed.

**Evidence class:** **confirmed** for the reset/seed sequence, mask, layer
addresses, mixed layer indexing, cardinal order, queue capacity, and EN/CH
parity; **unknown** for Native layer projection and all provider/settlement
semantics.

### 10.90 Shared directional-layer flood masks are separated (2026-09-02)

The adjacent candidate expanders are now recorded as one parameterized
primitive instead of being conflated with the market-only call. The
EN/CH-identical `FUN_005B0220 @ 0x5B0220` and `FUN_005B0360 @ 0x5B0360` both
read the same four current-cell-indexed layers (`north = DAT_013787F8`,
`east = DAT_013789C2`, `south = DAT_01378B88`, `west = DAT_013789BE`), enqueue
in strict north/east/south/west order, and write `currentDistance + 1`.
Their only recovered admission difference is the mask:

| source expander | mode | mask |
| --- | ---: | ---: |
| `FUN_005B0220` | zero/unweighted | `0x010C` |
| `FUN_005B0360` | nonzero/weighted | `0x0B0C` |

`OriginalDirectionalAccessFlood.build` exposes this exact shared algorithm
with an explicit mask and explicit layer arrays. Focused tests prove that a
`0x010C`-only current cell is admitted by mode zero but rejected by mode one,
while a `0x0B0C` current cell is admitted by both as the source masks require.

This closes the mode-specific flood arithmetic only. It does not recover the
PE-layer projection into Native map state, provider registry, occupancy,
route reconstruction, or settlement. No Qin market or entertainment runtime
path is enabled; both remain fail-closed pending those independent contracts.

**Evidence class:** **confirmed** for the shared layer operands, mask values,
current-cell indexing, neighbor order, and EN/CH parity; **unknown** for
Native layer projection and all provider/coverage/settlement effects.

### 10.91 CR correction: directional layers are current-cell indexed and market output is separate (2026-09-02)

A direct re-read of `local/source/split-merged/code/0x050000/FUN_005b0220.c`,
`FUN_005b0360.c`, and `FUN_005b1080.c` found an indexing distinction that the
previous §10.89/§10.90 implementation sketch had overstated. In
`FUN_005B0220` and `FUN_005B0360`, all four layer reads use the current queue
index (`*param_2`); the neighboring index appears only in the destination
cache slot and queue entry. `OriginalDirectionalAccessFlood.build` now uses
that current-cell indexing and its regression test distinguishes current from
candidate indexing.

`FUN_005B1080` is not the same primitive: it writes four direction-specific
offset views (`DAT_01391C50`, `DAT_01391FE4`, `DAT_01392370`, `DAT_01391FDC`)
of the central `DAT_01391FE0` cache, reads the north primary layer at the
north candidate, and reads east/south/west layers at the current index.
`OriginalMarketAccessFlood.build` now preserves this mixed-index contract;
the market/provider path remains fail-closed because layer projection and
downstream settlement are still unknown.

**Evidence class:** **confirmed** for the corrected pointer indexing, output
buffer identities, masks, and EN/CH parity; **unknown** for the PE-layer
projection, market-buffer consumers, provider registration, and settlement.

### 10.92 Direct-layer route entry point keeps `FUN_005B00D0` honest (2026-09-02)

The earlier `OriginalGrandCanalLayoutCatalog.entertainmentVenueRoute` and
`marketPeddlerRoute` helpers consume a caller-provided single array. That array
is useful for testing a projected primary-cache predicate, but it is not the
direct input shape of `FUN_005B00D0`: the executable calls
`FUN_005B0220 @ 0x5B0220`, which reads four direction-specific PE layers while
building `DAT_01391FE0`. To prevent the projection helper from being mistaken
for a recovered runtime mapping, Native now also exposes
`entertainmentVenueDirectionalRoute` and `marketPeddlerDirectionalRoute`.
They first call the source-backed `OriginalDirectionalAccessFlood.build`
contract (all four direction layers read at the current queue index), then
reconstruct the cardinal route with the existing selector-4/selector-8
boundary. The mixed north-candidate/east-south-west-current indexing belongs
only to `FUN_005B1080` and `OriginalMarketAccessFlood.build`.

`FUN_005B18B0` resolves equal-distance candidates deterministically: it first
accepts a strictly smaller flood value, then prefers the direction returned by
`FUN_005B2730` (the direct heading toward the origin), and otherwise keeps the
first remaining entry in `DAT_0085DE64`. The next iteration forbids the
opposite direction. A direct disassembly of `0x5B18B0…0x5B1B20` shows no RNG
read or call, and the EN/CH split rows for `0x5B18B0` and `0x5B2730` are
`identical`. Native's `routeFromDistances` now preserves this tie order for
both selector-4 and selector-8 reconstruction; it no longer rejects an
otherwise valid cardinal tie or substitutes an eight-way route merely because
the cardinal step had multiple equal candidates.

`GrandCanalSimulationTests.testEntertainmentDirectionalRouteUsesCurrentCellForEastAdmission`
uses a three-cell row where the first east edge is admitted but the second
current cell is not; the route is rejected until that second current-cell
entry is admitted. This distinguishes the recovered current-index read from
the incorrect candidate-index interpretation.

This closes the direct layer-input shape, its current/candidate index
boundary, and the deterministic selector-4/selector-8 route reconstruction.
The PE-layer projection from authored/runtime map state, endpoint selection,
collision/heading state, provider registry, and house-quality or coverage
settlement remain **unknown**. Neither market nor entertainment behavior is
wired into Qin simulation.

**Evidence class:** **confirmed** for the `FUN_005B00D0` → `FUN_005B0220`
dispatch, directional-layer contract, and route entry-point separation; **unknown**
for Native projection and every downstream provider/settlement contract.

### 10.93 cMarket Dinners-presence counter is a fixed six-slot active-key scan (2026-09-02)

`FUN_00544340 @ 0x544340` is the direct counter used by the cStall cleanup
path before it decides whether to clear the market-side Dinners state. The
body loops `i = 0…5`, resolves each child through `FUN_00544A00(i)`, skips a
null child, then requires the child vtable `+0xC8` call with selector `-1` to
return non-zero. Only an admitted child whose selected record key at
`child+0x158 + 0x0C` equals the requested key increments the result. The
function has no quantity, capacity, quality, worker, or house write. The EN/CH
comparison row for `0x544340` is `identical`.

Native now exposes this exact raw boundary through
`OriginalMarketActiveCommodityCount.count(entries:commodityID:)`, requiring no
more than six supplied child entries and counting only `isActive &&
commodityID == requested`. The helper is intentionally research-only: an empty
count can be used to describe the source's Dinners-presence trigger, but it does
not clear `cMarket+0x180` or enable Qin market settlement. Provider-record
ownership, quantity population, and quality/coverage projection remain
**unknown**.

**Evidence class:** **confirmed** for the six-slot bound, null/active/key
predicates, source address, and EN/CH parity; **unknown** for the record-owner
mapping and every downstream Native settlement effect.

### 10.94 Food popularity walk is encoded as an explicit-input primitive (confirmed, 2026-09-02)

The recovered `FUN_00590F30 @ 0x590F30` house walk is now represented by
`DeterministicMigration.originalFoodPopularityWalk` in
`Sources/EmperorCore/MigrationSimulation.swift`. The helper keeps the source
vector order and requires callers to provide the already-resolved live/class
predicates, resident word, food requirement column, raw `cHouseInfo+0x36`
quality byte, shortage streak, and the `+0x8C` model columns. It reproduces the
source-visible branches without pretending those fields are Native's current
food model:

* dead or non-house records are skipped; a zero-resident house clears its
  `+0x8C` value and does not enter the average;
* elite class records skip the `+0x8C` update but still participate in food
  scoring; non-elite records add column `0xE` plus signed
  `(40 - popularitySnapshot) / 2`, then clamp to column `0xF…100`;
* required quality `0` clears the shortage streak and contributes no score;
  otherwise raw quality `>=` the requirement contributes `+2`, while failed
  visits advance the streak `1→-1`, `2→-2`, `≥3→-3`;
* the mean uses integer division and rounds away from zero only when
  `abs(remainder) * 2 > count` (an exact half does not round), then applies
  the population `<350`/never-exceeded-349 suppression.

Focused tests cover the raw-quality comparison, elite/empty/zero-requirement
branches, crime-field arithmetic, streak progression, strict half rounding,
and the low-population latch. This is **confirmed** for the branch order,
thresholds, streak mapping, signed arithmetic, and rounding from the
canonical EN/CH-identical walk documented in §3. The `cHouseInfo+0x36` source,
the object-vector projection, and the remaining popularity ledger inputs are
still **unknown**; the helper is research-only and automatic Qin migration
remains `unsupportedOriginalProducer`.

### 10.95 Immigrant arrival write is now an explicit pure contract (confirmed, 2026-09-02)

The canonical English executable (`8a6d2df1…6753`) and Chinese executable
(`dbdeca1e…15a`) provide the state-8 body of `FUN_004C9FD0` only through the
direct PE trace; no generated split function exists (`qin3-blocker-audit-2026-08-30.md`,
§5.2). The confirmed order at `0x4CA265` is:

1. read the capacity from `FUN_0044CC80(row, 0x11)` **before** any vacant-house
   `+0x230` switch;
2. when `house+0x20 == 0`, clamp the figure byte `+0x6e` to that snapshot and
   call `+0x230(3)` for house types 2…10 or `+0x230(0xD)` otherwise (the
   `DAT_00D62408 != 0` skip is unreachable in both shipped builds because the
   byte has no direct writer);
3. fetch `cHouseInfo` through `+0x1E4`; a non-zero `+0x3C` skips only the
   `house+0x20` add and `FUN_00591900` population/high-water writer;
4. clear `house+0x32` unconditionally after that block. On an already occupied
   house the source does not repeat the empty-house capacity clamp.

`DeterministicMigration.originalImmigrantArrivalWrite` now records this order
with explicit raw inputs and returns the conversion argument, resulting type,
write count, resident delta, remaining capacity, population-writer gate, and
unconditional house-link clear. `DeterministicCityState.applyImmigrantArrival`
now consumes the confirmed capacity-table snapshot and preserves the
conversion-before-gate ordering: a locked vacant house is converted but does
not receive residents, while an already occupied house is not re-clamped to a
second capacity snapshot. `ResidentialUnit` carries optional, backward-
compatible projections for the signed `house+0x22` word and the in-flight
immigrant link `house+0x32`; the live bridge updates them only at the confirmed
spawn/arrival boundaries. The cHouseInfo gate and global population/high-water
side effects remain outside that narrow integration.

**Evidence class:** **confirmed** for the source field order, empty/occupied
branch distinction, `+0x230` arguments, `+0x3C` gate scope, link-clear
ordering, the `ALL HOUSES` capacity projection, and the optional Native field
storage; **inferred** only for the Native `vacantTypeID`/`houseLevelID`
representation and walker-ID encoding used by the integration; **unknown** for
the cHouseInfo gate's Native source, complete arrival/population side effects,
and automatic producer wiring.

### 10.96 Arrival capacity table is sourced from `ALL HOUSES` field 0x11 (confirmed, 2026-09-02)

The earlier `FUN_0044CC80` trace can now be connected to authored data without
guessing. `local/source/split-merged/code/0x040000/FUN_0044CC80.c` is a direct
table read: `DAT_00A63BFC[param_1 * 0x18 + param_2]`. The loader
`ERR_No_Building_Model_file @ 0x5D1830` reads the `ALL HOUSES` section into
that table, 24 integer fields per zero-based row, and applies the selected
`HOUSE MODS` row before clamping each value to `[-99, 100]`. The save/model
reload path `FUN_005D16D0 @ 0x5D16D0` copies the same 24-field rows and applies
the same clamp. EN/CH comparison rows for `0x44CC80`, `0x5D16D0`, and
`0x5D1830` are `identical`.

Consequently `param_2 == 0x11` is the authored population-capacity column,
not a derived Native capacity. The Native parser now exposes
`BuildingModelTable.originalHouseCapacity(sourceRow:difficulty:)`, including
the source difficulty modifier and inclusive clamp. The migration layer adds
`originalImmigrantCapacitySnapshot`, selecting source row `0xB` for an
Unoccupied Elite (`house+0x14 == 0xB`) and the raw `house+0x16` row otherwise,
matching the arrival and assignment call sites. Authored checks confirm rows
0/8/9/11 resolve to capacities 7/0/1/10 on Normal difficulty.

This closes the capacity-table source and difficulty-adjustment projection.
The narrow Native projections for `house+0x22`/`house+0x32` and their confirmed
arrival-boundary updates are now implemented. The conservative access/flood
and high-water projection is recorded in §10.99; automatic migration remains
fail-closed because its popularity, food, monument, war, and figure-registry
inputs are still incomplete.

**Evidence class:** **confirmed** for table stride, field 0x11, loader/reload
source, row selection, difficulty adjustment, clamp, and the original save
coverage; **inferred** for the Native optional field/walker-ID projection;
**unknown** for the remaining cHouseInfo and population-ledger mappings.

### 10.96a Capacity refresh arithmetic is now a pure source contract (confirmed, 2026-09-02)

`FUN_004AD3D0 @ 0x4AD3D0` is the daily calendar case `0x16`, immediately
before assignment case `0x17`. For each building it first clears the signed
`house+0x22` word, then requires a positive `house+0x24`. The same capacity
row selection used by assignment is read from `FUN_0044CC80(..., 0x11)`;
when the `cHouseInfo+0x3C` callback byte is non-zero, the capacity
contribution is replaced by current residents. The function writes
`house+0x22 = effectiveCapacity - residents` and raises `house+0x26` to the
maximum resident count observed. EN/CH bodies are identical.

`DeterministicMigration.originalCapacityRefresh` records this arithmetic with
explicit access and cHouseInfo inputs. It intentionally does not invent the
`DAT_01391FE0` flood producer or the Native object callback that supplies
those inputs; the conservative, ferry-free campaign projection that supplies
them is recorded in §10.99. Automatic migration itself remains disabled.

**Evidence class:** **confirmed** for case ordering, zero-before-gate,
capacity-row selection, cHouseInfo substitution, remaining-capacity write, and
high-water update; **inferred** for the conservative Native refresh trigger
and field projection; **unknown** for the complete Native object callback,
Ferry path, and cadence equivalence beyond the original daily dispatcher.

### 10.97 Negative spare-room cleanup is a separate vagrant path (confirmed, 2026-09-02)

`FUN_004AC2B0 @ 0x4AC2B0` dispatches daily case `0x18` to
`FUN_004AE1A0 @ 0x4AE1A0`; both EN/CH rows are `identical` in
`local/source/compare-report.tsv`. The walk reads signed `house+0x22` after
the capacity refresh. For each negative value `s`, it calls
`FUN_004AE150 @ 0x4AE150` with `-s` as the count for a type-`0xD` vagrant
figure. It then subtracts the overflow from `house+0x20`, but stores `1`
when the overflow is greater than or equal to the current resident count.
Non-negative spare room is untouched.

`DeterministicMigration.originalCapacityOverflowReconciliation` records this
arithmetic and the vagrant-spawn count with explicit inputs. It is not wired
to `ResidentialUnit`: the type-`0xD` route, figure registry, death/unlink
effects, and global `FUN_00591950` population ledger mapping remain unknown.
This also explains why a future faithful immigrant-arrival integration must
not silently clamp over-capacity residents to zero; the original next-day
cleanup has a distinct, observable minimum-one-resident consequence.

**Evidence class:** **confirmed** for the dispatch, signed spare-room test,
vagrant count, resident subtraction, and minimum-one clamp; **unknown** for
the vagrant figure's complete lifecycle and Native population-counter
projection.

### 10.98 Base building save path persists `house+0x22` and `house+0x32` (confirmed, 2026-09-02)

The original object/archive boundary for the two fields is now closed. The
base-building serializer `FUN_00427430 @ 0x427430` takes the building object
pointer as a byte address and explicitly serializes the 16-bit fields at
`+0x22` and `+0x32` in both its write branch and its schema-versioned read
branches. The city's main building collection is dispatched by
`FUN_0042D790 @ 0x42D790`; specialized building serializers, including
`FUN_005631B0` for multipart monuments, call the same base serializer first.
The EN/CH comparison row for `0x427430` is `identical`.

This confirms that remaining capacity (`+0x22`) and the in-flight figure link
(`+0x32`) are runtime fields carried through the original building save/load
path; it does **not** recover their semantic names beyond the traced consumers
or the vagrant figure's population-ledger effects. Native stores optional
backward-compatible fields on `ResidentialUnit` and updates them at the
conservative campaign refresh boundary in §10.99, as well as at the confirmed
immigrant spawn/arrival boundaries. The unresolved object-registry mapping,
Ferry path, and producer paths remain fail-closed.

**Evidence class:** **confirmed** for original serializer offsets, read/write
coverage, collection dispatch, and EN/CH identity; **inferred** for the
Native optional field names and walker-ID representation; **unknown** for the
remaining refresh and complete field lifecycle.

### 10.99 House access-word constructor and conservative Native projection (2026-09-02)

The previously unrecorded constructor edge is now closed. `FUN_0042D480 @
0x42D480` constructs `HouseBldg` by calling the base `FUN_00426C90 @ 0x426C90`,
then the `cHouseInfo` subobject initializer `FUN_00517190 @ 0x517190`, and
finally installing vtable `0x7ABA38`. The base helper
`Problems_creating_guid @ 0x426E60` clears `0x2D` dwords from the object base
before setting its GUID and sentinel fields; therefore HouseBldg words
`+0x24`, `+0x26`, `+0x28`, `+0x2A`, and `+0x2C` all start at zero. The copy
routine `FUN_00426EA0 @ 0x426EA0` copies these five 16-bit words explicitly,
and `FUN_00427430 @ 0x427430` serializes them. EN/CH comparison rows are
`identical` for all five functions.

Native now carries these words as optional `ResidentialUnit` projections:
`originalHouseAccessValue`, `originalCapacityHighWater`,
`originalHouseAccessRetryCount`, and `originalHouseAccessPoint`. A city tick
lazily refreshes unresolved projections only for campaign maps whose routing cache and
road-component ranks are fully derivable, whose residential perimeter cells
are in-bounds and have no source object bit `0x8`, and which contain no Ferry
(building `210`). It then applies the recovered `FUN_00518A50` state machine
and `FUN_004AD3D0` capacity arithmetic; assignment prefers the persisted
`+0x22` projection when present. Synthetic fixtures, Ferry maps, unknown
object callbacks, and incomplete cache derivations leave these fields
untouched. This path does not enable automatic Qin migration: the popularity,
food/market, monument, war, and figure-registry gates remain
`unsupportedOriginalProducer`.

**Evidence class:** **confirmed** for constructor zeroing, copy/save offsets,
and EN/CH identity; **inferred** for the conservative Native field names and
the ferry-free/no-object-bit projection boundary; **unknown** for object-vtable
`+0xD0` adjustments, Ferry post-pass/connector state, and the remaining
population-ledger/producer mappings.

### 10.100 cMarket access-word refresh and coordinate write order (2026-09-02)

The market-side refresh boundary is now recorded separately from the
HouseBldg refresher. `FUN_00543DC0 @ 0x543DC0` is an EN/CH-identical vtable
method. It first clears the receiver's `+0x24` word, resolves a linear map
cell with vtable `+0x194` using the receiver's `+0x10` value, and calls the
receiver's `+0x1AC` callback with the auxiliary terrain byte at that cell.
It then reads the signed 16-bit `DAT_01391FE0[cell]` value, stores that value
at `+0x24`, derives the column and row relative to `DAT_0101D0C8` using the
canonical `0xE4` stride, and writes those coordinates to `+0x2A/+0x2C`.
The return value is true exactly when the stored access word is non-zero.

Native exposes this post-selection arithmetic as
`OriginalMarketAccessRefresh.project`, retaining the callback input and raw
flood value as explicit fields. It does not invoke the opaque `+0x194` or
`+0x1AC` callbacks, populate a market object, or connect the result to Qin
market settlement. The existing focused test covers coordinate derivation,
zero/non-zero reachability, and invalid base/stride inputs.

This closes the market refresh's field/write ordering and signed-result
boundary only. The callback side effects, PE-layer projection, provider
registry, route/collision state, and provider-to-house quality/coverage
settlement remain **unknown**; the Qin market and migration gates stay
fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00543DC0.c`,
`local/source/compare-report.tsv` row `0x543DC0`,
`Sources/EmperorCore/MarketSimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the call/write order, offsets, signed
access result, `0xE4` coordinate arithmetic, and EN/CH identity; **unknown**
for callback effects, Native map-layer projection, and all downstream market
provider/settlement semantics.

### 10.101 Pressure/request pass is now an explicit pure contract (confirmed, 2026-09-02)

`FUN_005917E0 @ 0x5917E0` is EN/CH-identical and now has a side-effect-free
Native representation, `DeterministicMigration.originalPressurePass`. The
helper preserves the source's pressure bands, population cap (`>199999`),
war-count suppression of positive pressure at `>=4`, arrival/departure
cooldown decrements, the `<101` population departure gate, cross-cooldown
writes (`departure=2` after an arrival request and `arrival=2` after a
departure request), and `ceil(12×abs(pressure)/100)` request sizing. Early
returns intentionally suppress the shared `FUN_00548340(0)` overlay refresh;
the helper reports that unresolved callback only as a boolean.

The contract takes popularity, previous pressure, population, war count, and
both raw cooldowns as explicit inputs. It does not assign houses, spawn
figures, or enable automatic Qin migration: the war-figure counter,
assignment/arrival projection, and overlay semantics remain unresolved.
`DeterministicCityState.dailyMigrationAssignment` now consumes this contract
before continuing with the already-recovered pending/assignment bookkeeping;
the integration test confirms the source ordering even when terrain is absent
and the request becomes unfulfilled. Focused tests cover positive arrival
generation, cooldown return ordering, the `<101` departure gate, war
suppression, and the population cap.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005917e0.c`,
`FUN_0059a1b0.c`; `local/source/compare-report.tsv` row `0x5917E0`;
`Sources/EmperorCore/MigrationSimulation.swift`; and the focused migration
tests in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for pressure bands, early-return ordering,
cooldown/request arithmetic, and EN/CH identity; **unknown** for the
`FUN_00548340` overlay effects, war-count Native producer, and downstream
assignment/arrival/provider mapping.

### 10.102 Migration feng-shui factor remains fail-closed (2026-09-02)

The live popularity path no longer substitutes Native's terrain-element
`fengShuiSummary` for the original `FUN_00591670 @ 0x591670` input. The
executable computes its percentage from each active object-vector record's
`+0xA0` count, `+0x16` state, and `FUN_00562E80` special-model predicate,
with a population `<351` early return that stores `70`; the final bands are
source-confirmed, but the object-vector and field projection into Native are
not. `fengShuiSummary` remains available for its separate player-facing
overlay/inspector, while `updateMigrationPopularity` contributes `0` for this
factor until the original producer and object mapping are recovered.

This is a deliberate fail-closed correction, not a claim that the Qin
feng-shui factor is zero in the original. It prevents manually enabling the
otherwise unsupported migration producer from introducing a terrain-based
value with no executable evidence.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00591670.c`,
`FUN_00562E80.c`; `local/source/compare-report.tsv` row `0x591670`;
`Sources/EmperorCore/CitySimulation.swift` and
`Sources/EmperorCore/CityAestheticsSimulation.swift`.

**Evidence class:** **confirmed** for the original input fields, population
gate, and bands; **unknown** for object-vector semantics and Native mapping.

### 10.103 `+0xA0` is produced by placement-time feng-shui evaluation (2026-09-02)

The unresolved object-vector input has a concrete producer boundary. `FUN_0042B250
@ 0x42B250` calls `FUN_0044CC50 @ 0x44CC50` with selector `0xC`, matching the
model-table stride and the authored field 12 that
`GameData/Model/EmperorBuildingModels.txt` labels `m - Feng Shue Value`.
The decompiler emits `FUN_0044CC50` with a `void` prototype even though its
callers consume a return value; therefore the table-index linkage is
confirmed, while the wrapper's difficulty-adjustment details remain inferred.
Values `0`, `6`, `7`, and values above `7`
return fixed results (`0`, `-1`, `1`, and the value itself). Values `1...5`
perform the location-dependent branch: the function samples either the map
cell or a type-specific callback object returned by `FUN_0042C930`, counts
terrain/object categories through `FUN_0042B090`, and returns `1` or `-1`.
The optional diagnostic output records the first conflicting category. Both
functions are `identical` in the EN/CH comparison report.

The result is written into object word `+0xA0` after successful construction
by the generic placement path `FUN_00414F70`, the normal construction path
`FUN_004B1250`, the market/shop paths `FUN_00540E70` and `FUN_00544B30`, and
the type-2 placement path `FUN_004B2680`. Initializers `FUN_00415D30` and
`FUN_004157D0` instead seed a newly created object with `+0xA0 = 0`; the base
copy/serialization paths preserve that word. This establishes that
`FUN_00591670` is consuming a placement-time value, not directly calling the
terrain-element `fengShuiSummary` calculation.

The boundary is still insufficient for live Qin migration. `FUN_0042C930`
only exposes callback classes for a small model-ID set, the callback/vtable
semantics and category table behind `FUN_0042B090` are not recovered, and the
archive-load path does not show a generic recomputation of `+0xA0`. The field
is also overloaded by unrelated object classes (for example periodic visual
state code reads/writes the same offset), so a blanket `placedBuildings`
projection would mix records that `FUN_00591670` filters with
`FUN_00426D10(0)` and `FUN_00562E80`.

Native now exposes only the weighted aggregation helper
`fengShuiEffect(population:harmoniousWeight:totalWeight:)`; it performs the
source's integer truncation and bands after a caller supplies already
classified weights. No caller supplies those weights, and
`updateMigrationPopularity` remains fail-closed at zero for this factor.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042b250.c`,
`FUN_0042c930.c`, `FUN_0044cc50.c`, `FUN_00414f70.c`, `FUN_00415d30.c`,
`FUN_004157d0.c`, `local/source/split-merged/code/0x040000/FUN_004b1250.c`,
`local/source/split-merged/code/0x050000/FUN_00540e70.c`,
`FUN_00544b30.c`, `FUN_005428b0.c`, `local/source/compare-report.tsv`
rows `0x42B250` and `0x44CC50`, `GameData/Model/EmperorBuildingModels.txt`,
and `Sources/EmperorCore/MigrationSimulation.swift`.

**Evidence class:** **confirmed** for the `0xC` table selector, fixed and
location-dependent return branches, placement-time `+0xA0` writes, initial
zeroing, and weighted aggregation arithmetic; **inferred** for the wrapper's
returned difficulty-adjusted field value; **unknown** for callback and
category semantics, archive recomputation, object filtering projection, and
the complete Native migration producer.

### 10.104 `FUN_0042B250` result arithmetic is now an explicit pure boundary (2026-09-02)

Native now exposes `DeterministicMigration.originalFengShuiPlacementResult`,
which mirrors only the source arithmetic after the placement path has sampled
its counters. Model-table values `0`, `6`, `7`, and `>7` return `0`, `-1`, `1`,
and the value itself without reading the counters. Values `1...5` compare the
same five counter slots used by the decompiler (`local_1c[1]...local_1c[3]`,
`local_c`, and `local_8`): each model has a fixed pair that must both be zero
for result `1`; otherwise result `-1`. Diagnostic writes retain the source
order, so when both conflicts are present the later slot wins (for example,
model value `1` writes slot `3` then slot `4`).

This helper deliberately does not classify map cells, invoke the
`FUN_0042C930` callback objects, or infer the category meaning behind those
slots. Negative model/counter values are rejected as unsupported input rather
than promoted to a gameplay rule. It therefore closes a testable arithmetic
boundary while leaving the live `+0xA0` producer, archive projection, and
`FUN_00591670` object filtering fail-closed for Qin.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042b250.c`,
`FUN_0042b090.c`, `FUN_0042c930.c`; `local/source/compare-report.tsv` row
`0x42B250`; `Sources/EmperorCore/MigrationSimulation.swift` and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the fixed-value branches, counter pairs,
return values, and diagnostic write order; **unknown** for counter/category
semantics, callback behavior, archive recomputation, and live migration
integration.

### 10.105 `FUN_00591670` object-weight walk is explicit when records are supplied (2026-09-02)

The migration feng-shui consumer's remaining arithmetic boundary is now
represented by `DeterministicMigration.originalFengShuiWeightAggregate`. It
mirrors the source loop after the object-vector records and global
`FUN_00426D10(0)` gate have already been resolved. A non-zero signed `+0xA0`
value below `2` contributes one unit to the denominator, and contributes one
unit to the harmonious numerator only when it equals `1` (so a negative value
still contributes the source's unit denominator). Values `>=2` contribute
their raw weight to both totals unless `FUN_00562E80(modelID)` is true and the
record's signed `+0x16` state is non-zero; that excluded branch contributes
nothing. The exact special-model switch is centralized as
`originalFengShuiSpecialModel`, covering `0x4C...0x56`, `0x5C`, `0x5D`, and
`0xFD...0x10C`.

This closes the object-record filter and total/numerator arithmetic only. The
map object vector, record `+0xA0` producer, state-field lifecycle, and Native
projection remain unknown; no caller supplies these records in campaign
simulation, and `updateMigrationPopularity` remains fail-closed for Qin.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00591670.c`,
`FUN_00562e80.c`, `FUN_00562f70.c`; `local/source/compare-report.tsv` rows
`0x591670`, `0x562E80`, and `0x562F70`; `Sources/EmperorCore/MigrationSimulation.swift`;
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the non-zero/small/large value branches,
special-model ID switch, global-gate behavior, and weighted totals; **unknown**
for object-vector/archive projection, `+0xA0` production, state semantics,
and live migration integration.

### 10.106 cMarket peddler suppression byte is init-cleared, with no direct corpus writer (2026-09-03)

The global guard immediately before the cMarket peddler wrapper is now
bounded. `FUN_00545170 @ 0x545170` calls `FUN_004AFDB0(0xAC)` and invokes
`FUN_00543ED0` only when that byte is zero. The same byte guard is also used
by the generic model-23 allocator `FUN_0051CF90 @ 0x51CF90`, the buyer-side
wrapper `FUN_00541B80 @ 0x541B80`, and the unrelated model-37 wrapper
`FUN_0048CE90 @ 0x48CE90`; `FUN_004AFDB0 @ 0x4AFDB0` is a direct byte read from
`DAT_010BC7E0 + selector`.

Initialization is explicit in `FUN_005355F0 @ 0x5355F0`: after calling
`FUN_00535540 @ 0x535540`, it clears `0x43` dwords beginning at
`DAT_010BC7E0` and then clears the following byte. The latter store is at
offset `0xAC`, so a fresh initialized process has the peddler-suppression
byte equal to zero and therefore does not take this guard's early return.
The complete indexed corpus contains only the four reads above plus the
initialization clear for the symbol `DAT_010BC7E0`; no direct gameplay writer
for offset `0xAC` is present. `local/source/compare-report.tsv` marks the
five indexed functions (`0x4AFDB0`, `0x4AFD80`, `0x535540`, `0x5355F0`,
`0x545170`) as EN/CH `identical`.

This closes one negative explanation for Qin's missing peddlers: the
global `+0xAC` guard is not a confirmed startup blocker. It does **not**
authorize enabling the market bridge. An indirect writer through an alias or
runtime command remains unknown, as do the cStall/provider population,
quantity mapping, model-23 route, and household coverage/quality projection;
Native therefore keeps the campaign market and migration paths fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00545170.c`,
`FUN_0051cf90.c`, `FUN_00541b80.c`, `local/source/split-merged/code/0x040000/
FUN_0048ce90.c`, `FUN_004afdb0.c`, `FUN_004afd80.c`,
`local/source/split-merged/code/0x050000/FUN_00535540.c`,
`FUN_005355f0.c`, and `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the byte-read guard, initialization
clear range and offset, direct read inventory, and EN/CH parity;
**confirmed negative** for a direct corpus gameplay writer; **unknown** for
indirect alias writes and every downstream market/provider mapping.

### 10.107 Native peddler timing bridge requires an explicit raw worker-ratio input (2026-09-03)

The source peddler wrapper does not read Native assigned-worker percentages.
`FUN_00543ED0 @ 0x543ED0` obtains its numerator from the admitted Empty Shop
children's raw `+0x44` words (`FUN_00544A80(-1)`) and its denominator from
the filled-shop model-table employee total (`FUN_00544A40`), then applies the
integer ratio and strict counter threshold recorded in §10.84. The indexed
source does not provide a proven bridge from those raw cStall/provider fields
to Native `WorkforceMonthlySettlement` assignments.

Accordingly, `DeterministicMarketState.schedulePeddlers` now skips an
original-spawn-gate opportunity when `workerPercentByMarketID` has no entry;
it no longer defaults an absent raw input to `100%`. `CitySimulation` also
keeps the peddler scheduler and peddler advancement disabled for campaign
worlds until the provider/route/coverage projection is recovered. Unscoped
deterministic fixtures may still pass an explicit ratio and opt into the
compatibility route for isolated timing tests; the unscoped CitySimulation
compatibility branch may also supply its legacy 100% fixture value, while
campaign code never does so. The focused regression
`testOriginalMarketPeddlerSchedulerDoesNotAssumeMissingWorkerRatio` verifies
that missing input leaves both the source counter and market stock unchanged.

This is a fail-closed integration correction, not a claim that campaign
peddlers are absent in the original game. The cStall `+0x44` producer,
provider-record quantity source, model-23 route, and household quality/
coverage writer remain **unknown**; no Native staffing or inventory value is
substituted for them.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00543ed0.c`,
`FUN_00544a40.c`, `FUN_00544a80.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/MarketSimulation.swift`,
`Sources/EmperorCore/CitySimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the two raw source aggregates and
threshold inputs; **confirmed** for the absence of a direct Native mapping in
the indexed corpus; **inferred** for this integration's fail-closed policy;
**unknown** for all provider/route/coverage semantics.

### 10.108 `DAT_00C5CDA0` is not a confirmed startup Dinners gate (2026-09-03)

The monthly object pass `FUN_004AEDF0 @ 0x4AEDF0` checks three conditions before
calling each eligible object's virtual `+0x154(0x1C, 200)`: the global
`FUN_00426D10(0)` admission, the object's virtual `+0xC8(-3)` predicate, and
`DAT_00C5CDA0 != 0`. The same global byte also suppresses the normal food-slot
depletion in `FUN_00518690 @ 0x518690`, and it is read by the source status/
assignment helpers `FUN_00548770`, `FUN_005D2C70`, `FUN_005D7E40`, and
`FUN_00541220`.

The direct write inventory is negative for a gameplay enable: both the mission
setup path `FUN_0053CEC0 @ 0x53CEC0` and the save/new-mission path
`FUN_00535060 @ 0x535060` assign `DAT_00C5CDA0 = 0`. `FUN_00404990` writes
`DAT_00C5CDA0 + index*2 + 2`, which is the adjacent coordinate-array region,
not the base byte used by the Dinners guard. A complete indexed search finds no
other direct store to the base symbol, and all indexed EN/CH rows are
`identical`. Thus the base gate is confirmed false immediately after the
identified initialization paths; it is not evidence that Qin's missing
Dinners/peddlers are caused by a startup cheat flag. Alias-based or indirect
runtime writes remain unknown.

This closes only the gate-lifecycle question. The object callback's provider
record population, cMarket Dinners quantity/quality writers, and the Native
house/market projection are still unresolved, so no Qin Dinners settlement or
market spawn is enabled from this boundary.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AEDF0.c`,
`FUN_00404990.c`; `local/source/split-merged/code/0x050000/FUN_00518690.c`,
`FUN_00535060.c`, `FUN_0053CEC0.c`, `FUN_00541220.c`, `FUN_00548770.c`,
`FUN_005D2C70.c`, `FUN_005D7E40.c`; `local/source/compare-report.tsv` rows
`0x4AEDF0`, `0x404990`, `0x518690`, `0x535060`, `0x53CEC0`, `0x541220`,
`0x548770`, `0x5D2C70`, and `0x5D7E40`.

**Evidence class:** **confirmed** for the three monthly guard inputs, the
initialization clears, the adjacent-array offset, direct-reader inventory, and
EN/CH parity; **confirmed negative** for a direct startup/gameplay writer that
enables the base gate; **unknown** for alias/indirect writes and all downstream
provider/house settlement semantics.

### 10.109 `FUN_004AE150` callers are vagrant/repair paths, not the Qin migration producer (2026-09-03)

The canonical English executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
Chinese cross-check
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` both
encode the same three direct calls to `FUN_004AE150 @ 0x4AE150`:
`0x4AE1E2`, `0x4B31BF`, and `0x518A9C`. The indexed EN/CH bodies for the relevant callers are also
`identical` in `local/source/compare-report.tsv`:
`FUN_004AE1A0 @ 0x4AE1A0`, `FUN_004B2D00 @ 0x4B2D00`, and
`FUN_00518A50 @ 0x518A50`.

The callee has a narrow, source-visible contract. `FUN_004AE150` calls
`FUN_004EA050(1, 0xD, x, y, 0, 1, -1)`; when a figure is returned it sets
figure state `+0x40 = 6`, clears `+0x3E`, writes the signed count to
figure `+0x6E`, and calls `FUN_00591950(count)`. It never reads a house
capacity, food, popularity, mission, or provider record.

The first caller, `FUN_004AE1A0`, is reached only from calendar case `0x18`
inside `FUN_004AC2B0`. It walks the live object vector, selects negative
`house+0x22`, passes `-s` as the type-`0xD` count, and then applies the
minimum-one-resident subtraction recorded in §10.97. The second call is in
the `param_1 == 0` object/map rectangle pass of `FUN_004B2D00`, reached from
`FUN_004B29C0`; its branch is guarded by that object's virtual `+0xB8` result
and a positive object word at `+0x20`, then clears that word. The third is in
the indirect figure/object method `FUN_00518A50`: after a failed route check
and more than four retries, a non-zero pending count is converted into the
same type-`0xD` call and then cleared. These callers do not form a monthly
population-producer chain; the vtable dispatch around `FUN_00518A50` remains
unclassified.

This closes a useful negative for Qin: a future implementation must not map
the type-`0xD` vagrant helper to immigrant figure `0xB`, `pendingArrival`, or
the automatic migration producer. The figure route/registry and the
`FUN_00591950` population-ledger side effect remain unresolved, so Native
continues to keep both the vagrant spawn and campaign migration bridge
fail-closed.

**Sources:** canonical EN/CH PE call-byte scan at `0x4AE1E2`, `0x4B31BF`,
`0x518A9C`, and `0x4AC3EC`; `local/source/split-merged/code/0x040000/`
`FUN_004AE150.c`, `FUN_004AE1A0.c`, `FUN_004AC2B0.c`, `FUN_004B2D00.c`,
`FUN_004B29C0.c`; `local/source/split-merged/code/0x050000/`
`FUN_00518A50.c`; and `local/source/compare-report.tsv` rows for
`0x4AE150`, `0x4AE1A0`, `0x4B2D00`, and `0x518A50`.

**Evidence class:** **confirmed** for the callee's type/count writes, the
three direct call addresses, the calendar/repair and retry call contexts, and
EN/CH parity; **unknown** for the indirect vtable owner, route/registry
effects, and the `FUN_00591950` ledger meaning.

### 10.110 Source population input is an eligibility-filtered object aggregate (2026-09-03)

The population word consumed by the popularity and pressure producer is
refreshed by `FUN_00517CC0 @ 0x517CC0`, which calls
`FUN_00517DE0 @ 0x517DE0` and returns the aggregate stored at its `+0x28`
output.  The EN/CH rows for both functions are `identical` in
`local/source/compare-report.tsv`.  `FUN_00517DE0` walks the live object vector
through `FUN_004F8210`/`FUN_004F8200`; an object contributes its signed
16-bit `+0x20` word only when its state byte `+0x04` is not `0`, `2`, `5`, or
`6`, and its vtable `+0xB8` eligibility callback returns non-zero.  The same
walk separately accumulates the subset whose vtable `+0x204` class predicate
returns non-zero into output `+0x2C` (the employment/upper-class total).  The
indexed callers of `FUN_00517CC0` include `FUN_00591200 @ 0x591200`,
`FUN_00517D50`, and the surrounding health/service readers; the refreshed
`+0x28` value is therefore the source population input to the migration
factor pass, not a post-arrival ledger.

Native's `CitySimulation.population` currently sums `ResidentialUnit.residents`
without an equivalent object-state byte or `+0xB8` callback.  Qin campaign
houses are authored as residential units, but the corpus does not prove that
every Native unit is exactly one source-eligible object in all load, repair,
vacant, or specialized states.  This is therefore a confirmed source
aggregation boundary and a confirmed absence of the Native eligibility
projection, not permission to replace the source total with an inferred
filter or to enable automatic migration.  Until the object-state and
`+0xB8` mapping are closed, the campaign producer remains fail-closed even
when the simple resident sum happens to match a fixture.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00517cc0.c`,
`FUN_00517de0.c`, `FUN_00517d50.c`, `FUN_00591200.c`,
`local/source/compare-report.tsv` rows `0x517cc0` and `0x517de0`, and
`Sources/EmperorCore/CitySimulation.swift` (`population`).

**Evidence class:** **confirmed** for the object-vector walk, excluded state
bytes, signed `+0x20` aggregation, separate `+0x2C` class total, caller
relationship, and EN/CH parity; **unknown** for the complete object-state
serializer mapping, `+0xB8` semantic projection, specialized/vacant object
coverage, and Native equivalence.

### 10.110a HouseBldg `+0x09` direct-writer census narrows the lifecycle gap (2026-09-03)

The `HouseBldg` population callback at `+0xB8` reads object byte `+0x09`, so
the writer set was rechecked against both canonical PE inputs rather than
assuming that a residential archive row supplies the byte.  The EN and CH
executables are the hash-identified builds in `DESIGN.md` and the indexed
comparison rows for `FUN_00426EA0`, `FUN_00428C10`, `FUN_0042AAA0`, and
`FUN_00518B70` are all `identical`.

The direct machine-code stores that target this `HouseBldg` byte are:

* `FUN_00426EA0 @ 0x426EA0` copies source byte `+0x09` to a destination object;
* `FUN_00428C10 @ 0x428C10` clears byte `+0x09` during the common reset path;
* `FUN_0042AAA0 @ 0x42AAA0` clears byte `+0x09` only after its `+0xB8`
  predicate succeeds and the signed resident word `+0x20` is non-zero;
* `FUN_00518B70 @ 0x518B70` writes byte `+0x09 = 1` after calling the common
  reset routine.

The `HouseBldg` constructor `FUN_0042D480 @ 0x42D480` first calls the base
initializer `FUN_00426C90 @ 0x426C90`; that base's GUID/zeroing helper clears
the newly allocated object before the final `0x7ABA38` vtable is installed.
The separate `FUN_00517190 @ 0x517190` initializes the `cHouseInfo` subobject
at `HouseBldg + 0xC8`; its own `+0x09` is a different subobject offset and is
not the population callback byte.

A full direct-displacement scan of the `.text` sections found no additional
`HouseBldg`-class store to `object + 0x09`; remaining `+0x09` stores belong to
unrelated compact records/UI structures or to the `cHouseInfo` subobject.
This is a **confirmed negative** for another direct writer in the recovered
machine-code corpus, not proof that indirect virtual/table aliases cannot
mutate the byte. The lifecycle is still not closed because the caller order
that reaches `FUN_00518B70`, the map-load specialization that creates a
`HouseBldg`, and any indirect alias writer remain unresolved. Native therefore
keeps `houseEligibilityByte` as an explicit source projection and does not
derive it from `ResidentialUnit.residents`, vacancy, or construction state.

**Sources:** canonical PE hashes from `DESIGN.md`; direct EN/CH bodies and
`local/source/compare-report.tsv` rows for `0x426EA0`, `0x428C10`, `0x42AAA0`,
and `0x518B70`; direct PE slices at `0x42D480`, `0x426C90`, and the
`HouseBldg` vtable `0x7ABA38`; `FUN_00517190.c`; and the full `.text`
displacement census used during this audit.

**Evidence class:** **confirmed negative** for an additional direct
`HouseBldg + 0x09` writer and for the constructor/reset/set/copy operations
listed above; **unknown** for indirect aliases, caller timing, map-load
specialization, and Native object equivalence. Automatic Qin migration remains
fail-closed.

### 10.111 Population ledger arithmetic is closed, but its second word is not (2026-09-03)

The indexed source closes the raw arithmetic behind the population side
effects without closing the field's player-facing meaning. `FUN_00591970 @
0x591970` subtracts its signed argument from `DAT_0130F988`, clamps that word
at zero, and calls `FUN_00590A50 @ 0x590A50`, which raises
`DAT_0131257C` when the current word exceeds its high-water value.
`FUN_005919A0 @ 0x5919A0` performs the corresponding add-and-clamp operation
and the same high-water refresh. `FUN_00591920 @ 0x591920` is a one-argument
wrapper to the decrement path; `FUN_00591930 @ 0x591930` subtracts its
argument from `DAT_01311F8C` before using the increment path; and
`FUN_00591950 @ 0x591950` adds its argument to `DAT_01311F8C` before using the
decrement path. The latter is reached by `FUN_004AE150 @ 0x4AE150` after its
type-`0xD` figure creation, while the direct `FUN_00591920` callers include
the house/object and figure-cleanup paths at `0x42AAA0`, `0x4681A0`,
`0x4C8B70`, and `0x518960`. The natural-health and monthly population
reconciliation paths call `0x591970`/`0x5919A0` directly (`0x590E00` and
`0x591200`).

The EN/CH comparison rows for `0x591920`, `0x591930`, `0x591950`, `0x591970`,
`0x5919A0`, `0x590A50`, `0x590E00`, `0x591200`, and the listed callers are
`identical`. `OriginalPopulationLedger` in
`Sources/EmperorCore/MigrationSimulation.swift` now mirrors these raw
transitions and clamps, including the composite type-`D` order. It deliberately
calls the second field `unclassifiedDeltaWord`: the corpus has no stable
semantic name or Native object/figure projection for `DAT_01311F8C`, and the
type-`D` helper is already proven not to be Qin's immigrant producer.

This closes the ledger's arithmetic, not the Qin integration. Native does not
feed its house or figure collections into these words, so automatic migration,
vagrant creation, and population settlement remain fail-closed pending the
missing registry and event-stream mappings.

**Sources:** `local/source/split-merged/code/0x050000/`
`FUN_00591920.c`, `FUN_00591930.c`, `FUN_00591950.c`, `FUN_00591970.c`,
`FUN_005919a0.c`, `FUN_00590a50.c`, `FUN_00590e00.c`, `FUN_00591200.c`,
`FUN_00518960.c`, `FUN_005917e0.c`; `local/source/split-merged/code/0x040000/`
`FUN_0042aaa0.c`, `FUN_004681a0.c`, `FUN_004ae150.c`, `FUN_004c8b70.c`;
`local/source/compare-report.tsv`; and the raw ledger helper/tests.

**Evidence class:** **confirmed** for the counter arithmetic, clamp/high-water
ordering, direct caller sites, and EN/CH parity; **confirmed negative** for a
Qin-specific Native writer or object projection; **unknown** for the semantic
identity of `DAT_01311F8C`, indirect callers, and the complete event stream.

### 10.112 Global `+0x44` writer excludes cStall objects (confirmed negative, 2026-09-03)

The direct-assignment census was rechecked against the cStall claim in
§10.62. `FUN_004AD850 @ 0x4AD850` is an indexed function that writes a signed
short to `object + 0x44`, but its object-vector loop first requires
`FUN_0042B720(model) || FUN_0042B730(model)`. The two predicates are literal
comparisons (`model == 0x83` and `model == 0x82` respectively), so this writer
admits only those two model IDs. The cStall factory admits `0x3E` and
`0x40…0x46` (`FUN_005418D0`), which are disjoint from `0x82/0x83`; the global
writer therefore cannot populate a cStall's `+0x44` field.

`FUN_004AD850` is called by `FUN_004AD4A0`, itself reached from the monthly
phase dispatcher `FUN_004AC2B0`. Both function rows are EN/CH `identical` in
`local/source/compare-report.tsv`. This closes a potential false lead in the
`+0x44` search: the remaining cStall writer is the class-specific vtable
`+0x18C → 0x51E310` described in §10.62, while its table inputs, player-facing
meaning, and provider/market settlement remain unknown. No Native market or
Qin staffing value may be derived from the `0x82/0x83` monthly writer.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ad850.c`,
`FUN_004ad4a0.c`, `FUN_0042b720.c`, `FUN_0042b730.c`, `FUN_004ac2b0.c`,
`local/source/split-merged/code/0x050000/FUN_005418d0.c`,
`local/source/compare-report.tsv`, and `GameData/Model/EmperorBuildingModels.txt`.

**Evidence class:** **confirmed** for the global writer, its monthly caller,
literal model predicates, EN/CH parity, and disjointness from cStall model IDs;
**unknown** for cStall `+0x44` semantics and its table/provider inputs.

### 10.113 cMarket peddler ratio aggregates only Empty Shop `+0x44` (confirmed, 2026-09-03)

The two raw inputs to `FUN_00543ED0 @ 0x543ED0` are now represented as an
explicit six-slot boundary. `FUN_00544A40` walks the present child IDs from
`FUN_00544A00` and sums `FUN_0044CC50(child model, 5)` for every non-Empty-Shop
child; it does not require the selector-`-1` admission used by the numerator.
`FUN_00544A80(-1)` walks the same six slots, but its
`FUN_005408D0(-1)` predicate admits only Empty Shop model `0x3E`, and then
sums that child's signed `+0x44` word. Absent child IDs contribute nothing.

Native now exposes this as
`OriginalMarketPeddlerWorkerAggregate.from(entries:)`, requiring at most six
known cStall models and keeping model-table employee fields and raw `+0x44`
values explicit. Focused tests cover signed `0xFFFF`, filled-shop denominator
aggregation, absent slots, unsupported models, and the six-slot bound. This
does not identify the `+0x18C → 0x51E310` table producer of `+0x44`, nor the
market/provider route and household settlement; Qin peddler behavior remains
fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00543ED0.c`,
`FUN_00544A00.c`, `FUN_00544A40.c`, `FUN_00544A80.c`, `FUN_005408D0.c`,
`local/source/split-merged/code/0x040000/FUN_0044CC50.c`,
`GameData/Model/EmperorBuildingModels.txt`, and
`Sources/EmperorCore/MarketSimulation.swift`.

**Evidence class:** **confirmed** for slot count, Empty Shop selector,
non-Empty-Shop denominator, signed field width, and aggregation order;
**unknown** for the `+0x44` producer, provider registration, routing, and
settlement.

### 10.114 cStall `+0x18C` producer arithmetic is closed (confirmed, 2026-09-03)

The cStall vtable at `0x7B6C5C` dispatches `+0x18C` to the interior PE body
`FUN_0051E310 @ 0x51E310`. Its only recovered caller is
`FUN_004F19A0 @ 0x4F19A0`, which calls the virtual with selector `1` and then
`2`, a pointer to the first pool array, and a pointer to the second pool
array. Before either branch, the receiver's `+0x188` callback
`FUN_004271D0` writes a status word and returns an admission boolean; a false
return jumps directly to the epilogue when the status is exactly `9`
(preserving cStall `+0x44`), and otherwise clears it.

For selector `<=1`, the body clears `+0x44`, selects the first or second pool
from the receiver's `+0xF4` boolean, computes the corresponding source-record
ratio with `FUN_00408BA0`, scales the receiver's `+0x1B0` capacity through
`FUN_00408B80`, keeps the smaller of the scaled share and capacity, stores the
result as a signed 16-bit word at `+0x44`, and subtracts the full allocated
amount from the selected pool entry. For selector `>1`, it tops up the signed
`+0x44` value toward `+0x1B0` from the selected pool; if the pool is smaller
than the deficit it adds the pool's low 16 bits and zeros that pool, otherwise
it adds the deficit and subtracts it from the pool.

The exact pure boundary is now represented by
`OriginalMarketCStallField44Producer.apply(_:)`, with explicit callback/status,
ratio, capacity, field-width, and pool inputs. Focused tests cover both pool
choices, zero-denominator ratio behavior through the helper's explicit inputs,
the status-9 preserve branch, selector-1 allocation, selector-2 top-up, and the
low-pool 16-bit branch. This closes only the field producer arithmetic; it
does not identify the source record's semantic labels, cStall/provider
ownership, registry projection, peddler route, or household settlement, so
Qin market behavior remains fail-closed.

**Sources:** canonical EN/CH PE slice `0x51E310…0x51E48E` (383 bytes,
SHA-256 `54db9ff2518504155d259157d9bef71e4618577da87faa31c2d59099df02011b`),
`local/source/split-merged/code/0x040000/FUN_004F19A0.c`,
`FUN_004271D0.c`, `FUN_00408BA0.c`, `FUN_00408B80.c`, the cStall constructor
`local/source/split-merged/code/0x050000/FUN_00540770.c`, and
`Sources/EmperorCore/MarketSimulation.swift`.

**Evidence class:** **confirmed** for the call edge, status-9 gate,
selector branches, ratio/capacity arithmetic, selected-pool subtraction,
16-bit writes, low-pool handling, and EN/CH byte identity; **unknown** for
source-record semantic names, provider registration, route/coverage, and
settlement.

## 2026-09-03 Immigrant assignment walk is now an explicit three-pass boundary

The source's request-to-house assignment is `FUN_004ADA10 @ 0x4ADA10`, called
from `FUN_004AD4A0 @ 0x4AD4A0` after `FUN_005917E0` has produced a positive
arrival request.  The canonical English and Chinese functions are both marked
`identical` in `local/source/compare-report.tsv`.  Before assigning any
request, the function walks the live object vector and clears a non-zero
house-link word (`house+0x32`) when its linked object is not model `0xB` at
`+0x12` with a non-zero `+0x16` state.  An active model-`0xB` link is retained
and blocks that house in the following passes.

The assignment then rescans the same vector in order three times.  Pass 1
accepts `house+0x24 > 0`, `house+0x20 == 0`, `house+0x22 != 0`, and no retained
link; it emits up to six people without clamping that batch to `house+0x22`.
Pass 2 accepts `house+0x24 > 0`, `house+0x22 > 11`, and no link, again in
six-person batches.  Pass 3 accepts `house+0x24 > 0`, `house+0x22 > 0`, and no
link, emitting `min(6, house+0x22, requestRemainder)`.  Because the source
does not mutate `house+0x22` in this function, a house can be visited again in
pass 3 after receiving a pass-2 batch.  The local request remainder is reduced
when `FUN_004ADE10 @ 0x4ADE10` is called; the later figure constructor, route,
and arrival writer are separate edges.

`OriginalImmigrantAssignmentPlanner` records this exact cleanup, vector order,
pass order, six-person cap, and pass-1/non-zero-capacity distinction as a pure
research helper.  Its inputs are raw source words plus already-resolved linked
object fields; it does not reinterpret Native `ResidentialUnit` state or
create figures.  Focused tests cover repeated pass-2/pass-3 visits, the
uncapped pass-1 batch, invalid-link clearing, active-link blocking, and the
unassigned remainder.

This closes the request-assignment control-flow boundary only.  The producer of
the source `house+0x24` access value, the live object-vector/registry mapping
for Qin archives, `FUN_004ADE10`'s provider/route inputs, and
`FUN_004C9FD0` settlement remain unknown; automatic Qin migration therefore
stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ADA10.c`,
`FUN_004AD4A0.c`, `FUN_004ADE10.c`, `FUN_004ADED0.c`,
`local/source/compare-report.tsv` rows `0x4AD4A0`, `0x4ADA10`, `0x4ADE10`,
`0x4ADED0`, `Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for cleanup predicates, vector/pass order,
field comparisons, batch widths, remainder handling, caller order, and EN/CH
parity; **unknown** for access-value production, registry projection, figure
creation/route, and arrival settlement.

## 2026-09-03 Type-`0xB` immigrant constructor writes are explicit

`FUN_004ADE10 @ 0x4ADE10` calls `FUN_004EA050(1, 0xB,
DAT_00C5CDFC, DAT_00C5CDFE, 0, 1, -1)`.  The canonical EN/CH rows are both
`identical` in `local/source/compare-report.tsv`.  When the allocator returns a
non-zero figure object, the function writes figure state `+0x40 = 6`, stores
the source house object ID at `figure+0x64`, stores the requested batch byte at
`figure+0x6E`, and links the figure ID into `house+0x32`.  It also computes
`figure+0x3E = (house+0x51 & 0xFF7F) + *param_3` as a 16-bit unsigned store,
sets `figure+0x13 = house+0x51 & 1`, and sets `figure+0x49` to bit 6 of
`DAT_00F6A9E0[figure+0x28]`.  Only after all writes does it increment the
caller-provided wait word by `0x32`.

If `FUN_004EA050` returns zero, none of those figure/house writes occur and
the wait word is not incremented.  This is separate from the assignment
caller: `FUN_004ADA10` still consumes its local request remainder around the
call, so assignment accounting cannot be treated as proof of successful
figure creation.

`OriginalImmigrantFigureSpawn.apply(_:)` records the exact success/failure
write set, byte/word truncation, bit extraction, house link, and wait-pointer
update as a pure research helper.  It does not create a Native figure or route
and is not wired into Qin campaign simulation.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ADE10.c`,
`FUN_004ADA10.c`, `local/source/compare-report.tsv` rows `0x4ADE10` and
`0x4ADA10`, `GameData/Model/EmperorFigureModels.txt`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the allocator arguments, figure type,
field offsets, write order, bit masks, 16-bit/byte stores, failure no-op, wait
increment, and EN/CH parity; **unknown** for allocator success frequency,
registry projection, route construction, and arrival settlement.

## 2026-09-03 Generic figure allocator candidate gate is explicit

The allocator called by the immigrant constructor is now bounded at its own
source boundary. `FUN_004EA050 @ 0x4EA050` is a thin wrapper over
`FUN_004E1420 @ 0x4E1420`; the latter obtains one candidate from
`FUN_004E23A0`, then retries after a rejected candidate until five allocator
results have been examined. A result is rejected when its ID is non-positive,
when `FUN_004E2400(result)` maps to a null object slot, or when the mapped
object's byte at `+0x16` is non-zero. The first candidate passing all three
gates enters the requested model constructor; five rejected results return
zero. The EN and CH rows for `0x4E1420`, `0x4E23A0`, and `0x4E2400` are all
`identical`.

`OriginalFigureAllocator.firstAvailable(candidates:)` records this exact
five-call scan over already-resolved allocator results. The helper deliberately
does not model allocator-state consumption, object-vector registration,
constructor dispatch, pool ownership, or success frequency; those remain
separate unresolved boundaries. Tests cover invalid IDs, missing objects,
active object state, first eligible selection, and the fifth-attempt cap.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ea050.c`,
`FUN_004e1420.c`, `FUN_004e23a0.c`, `FUN_004e2400.c`,
`local/source/compare-report.tsv` rows `0x4e1420`, `0x4e23a0`, and `0x4e2400`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the five-result retry bound, positive-ID
gate, null-slot gate, inactive `+0x16` requirement, first-match return, and
EN/CH parity; **unknown** for allocator-state population, registry projection,
constructor success frequency, route construction, and arrival settlement.

## 2026-09-03 Figure allocator cursor/count transition is explicit

The allocator-state mutation in `FUN_004E23A0 @ 0x4E23A0` is now separated
from the unresolved source that fills its slots. When the raw count word at
`param_1 + 0x08` is zero, the function returns `-1` and leaves the read cursor
and count unchanged. For every non-zero count it reads the slot at
`param_1 + 0x0C + readCursor×4`, advances the read cursor, wraps it to zero
only after index `0x7CE`, and decrements the count by one. The companion
writer `FUN_004E23D0` uses a distinct write cursor at `param_1 + 0x04`, writes
the supplied ID at `+0x0C + writeCursor×4`, advances/wraps that cursor, and
increments the same count without a capacity clamp; `FUN_004EBBF0` clears all
three state words. Therefore the ring has `0x7CF = 1999` slots
(`0…0x7CE`); the source does not clamp a negative count. The EN and CH rows
are `identical`.

`OriginalFigureAllocatorState.consume(slotValue:)`, `.enqueue(slotValue:)`,
and `.reset()` record these exact read/write/reset transitions while requiring
the caller to resolve or store the current slot value. They do not invent slot
population, object-vector mapping, or registry ownership. Tests cover the read
wrap boundary, independent write cursor, refill wrap beyond the nominal ring
length, reset, zero-count no-op, and the source's non-zero negative-count
behavior.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004e23a0.c`,
`FUN_004e23d0.c`, `FUN_004ebbf0.c`, `FUN_004ebc00.c`,
`FUN_004e9fe0.c`, `local/source/compare-report.tsv` rows `0x4e23a0`,
`0x4e23d0`, `0x4ebbf0`, `0x4ebc00`, and `0x4e9fe0`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for slot offset, cursor order, `0x7CE`
wrap, zero-count early return, non-zero decrement, 1999-slot length, and
EN/CH parity; **unknown** for slot population, initialization callers,
registry projection, constructor success frequency, route construction, and
arrival settlement.

## 2026-09-03 Figure allocator queue refill order is explicit

The source that populates the allocator ring is now bounded without promoting
the object registry into Native. `FUN_004EBC00 @ 0x4EBC00` calls
`FUN_004EBBF0` and enqueues IDs `1…1999` in ascending order. The map/runtime
refresh `FUN_004E9FE0 @ 0x4E9FE0` also resets the queue, then scans IDs
`1999…1`: an object whose `+0x16` byte is zero is enqueued in that descending
order; a non-zero state other than `2` enters `FUN_004EBB40(id, 1)`, followed
by a re-read of `+0x12` that increments the separate `FUN_00417350` counters
only for value `1`. `FUN_004E9FB0` is the startup wrapper for the ascending
refill, while `FUN_00534BF0` reaches the descending refresh after map setup.
All inspected EN/CH rows (`0x4e9fe0`, `0x4ebbf0`, `0x4ebc00`, `0x417340`,
`0x417350`) are `identical`.

`OriginalFigureAllocatorQueue.bootstrapObjectIDs()` and
`OriginalFigureAllocatorQueue.rebuild(objects:)` record the two refill orders.
The rebuild requires one unique resolved record for every ID `1…1999`; an
incomplete or duplicate registry returns `nil` instead of treating missing
objects as free. It reports the non-free counter-update and `+0x12 == 1`
subsets but does not implement `FUN_004EBB40`'s model counters, object lookup,
or registry insertion. Tests cover ascending bootstrap, descending free-ID
order, state-2 exclusion, side-effect subsets, and fail-closed malformed
registry input.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004e9fe0.c`,
`FUN_004ebc00.c`, `FUN_004ebbf0.c`, `FUN_004e9fb0.c`,
`FUN_004ebb40.c`, `FUN_00417340.c`, `FUN_00417350.c`,
`local/source/split-merged/code/0x050000/FUN_00534bf0.c`,
`local/source/compare-report.tsv`, `Sources/EmperorCore/MigrationSimulation.swift`,
and `Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for reset/refill call order, ID ranges,
ascending/descending order, `+0x16` state gates, post-update `+0x12` subset,
and EN/CH parity; **unknown** for source registry contents on Qin archives,
provider specialization, and downstream route/settlement.

## 2026-09-03 Figure allocator non-free counter classes are explicit

The non-free branch of `FUN_004E9FE0` calls `FUN_004EBB40(id, 1)`, whose two
model predicates are now closed. `FUN_004E2560` admits model IDs `0x3A…0x3E`
and `0x4E` for the first global counter; `FUN_004E2510(model, 0)` admits
`0x38`, `0x39`, `0x40…0x44`, and `0x4F` for the second. Model `0x3F` is not
admitted because the caller supplies selector byte `0`. An add (`param_2 != 0`)
increments the selected counter(s); a remove (`param_2 == 0`) decrements them,
clamping each result at zero. Non-positive object IDs return before the object
lookup. The EN/CH rows for `0x4EBB40`, `0x4E2560`, and `0x4E2510` are
`identical`.

`OriginalFigureCounterClassification` and `OriginalFigureGlobalCounters`
record these model sets and clamped arithmetic after the caller resolves the
object's model byte. They intentionally do not model the object-vector lookup,
the source globals' semantic labels, or provider/figure registry ownership.
Focused tests cover both model sets, the excluded `0x3F` selector case,
increment/decrement behavior, clamping, and the non-positive-ID early return.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ebb40.c`,
`FUN_004e2560.c`, `FUN_004e2510.c`, `FUN_004e9fe0.c`,
`local/source/compare-report.tsv` rows `0x4ebb40`, `0x4e2560`, and `0x4e2510`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for model-ID sets, selector-0 behavior,
counter direction, zero clamp, non-positive-ID gate, and EN/CH parity;
**unknown** for source-global semantic labels, object registry contents,
provider specialization, and downstream route/settlement.

## 2026-09-03 Daily request batching preserves the source pending-word order

The request bookkeeping at `FUN_004AD4A0 @ 0x4AD4A0` is now captured as
`DeterministicMigration.originalDailyMigrationBatch`. The canonical English
and Chinese functions are byte-identical (`local/source/compare-report.tsv`
rows `0x4AD4A0`). Each stream starts from its own carried word (`DAT_01311F88`
for arrivals and `DAT_01311F84` for departures). A positive request below six
is added to that word and dispatches only when the combined value is greater
than five; the threshold path passes the combined value to
`FUN_004ADA10`/`FUN_004ADC90` and then stores zero. A request of six or more
dispatches immediately while preserving the previous carried word. Zero or
negative requests leave the carried word unchanged. The two streams are
independent, and the caller clears both request words after this bookkeeping.

`DeterministicCityState.dailyMigrationAssignment` now consumes this pure
boundary before invoking the already-recovered arrival assignment. Departure
dispatch remains unsupported because its figure/exit route is unresolved, but
its source-defined pending-word result is retained instead of accumulating
requests unconditionally. No house, figure, ledger, provider, or route state
is synthesized by the helper.

This closes the daily six-person batching and pending-word transition only.
The Qin automatic-migration producer remains fail-closed: source population,
food/monument/war inputs, object-vector projection, and figure/provider route
settlement are still unknown.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ad4a0.c`,
`FUN_004ada10.c`, `FUN_004adc90.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/MigrationSimulation.swift`,
`Sources/EmperorCore/CitySimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for six-person threshold (`>5`),
arrival/departure independence, immediate-request behavior, pending-word
clear/preserve order, request resets, and EN/CH parity; **unknown** for the
downstream departure route/figure effects and all unresolved Qin producer
inputs.

## 2026-09-03 cMarket provider-record quantity writers have a closed helper boundary

The 16-byte provider record used by the cMarket family has a dedicated
vtable at `0x7BDBB4` in both hash-identified executables.  Its constructor
`FUN_005D2690 @ 0x5D2690` writes the raw commodity key at `record+0x04`,
quantity at `record+0x08`, and supplied capacity at `record+0x0C`; the
cMarket constructor passes `0x190` (400) for that capacity.  The EN/CH rows
for `0x5D2690`, `0x5D2760`, and `0x5D2790` are `identical` in
`local/source/compare-report.tsv`.

The only provider-record quantity mutations recovered in the helper/call
inventory are the two direct helpers below:

* `FUN_005D2760 @ 0x5D2760` subtracts its amount from `record+0x08`, clamps
  negative results to zero, and clears `record+0x04` when the caller's clear
  flag is non-zero and the quantity reaches zero;
* `FUN_005D2790 @ 0x5D2790` unconditionally writes `record+0x04 = key`, adds
  the amount to `record+0x08`, clips only above `record+0x0C`, and returns the
  overflow.  It does not clamp a negative result upward.

The direct `FUN_005D2790` call sites in both PE inputs are exactly
`0x4C4F46` (storage/trade receiver), `0x5417E5` (cStall blend/store),
`0x543D13` (cMarket `+0x154` refill), and `0x5D5021` (the provider-record
reducer).  The cMarket save/load path serializes these same records through
`FUN_005D4890`/`FUN_005D4810`; therefore persistence is not the missing
producer.  A full direct-displacement scan of the canonical `.text` sections
found no additional provider-record-class store to `record+0x08` beyond
`FUN_005D2760` and `FUN_005D2790`.  This is a **confirmed negative boundary**
for another direct quantity writer, not proof that an indirect virtual/table
alias or external-buffer copy cannot populate the field.

Consequently, the placement-time key/capacity assignment and cStall deposit
quantity path are confirmed, while the monthly/external Qin source that would
give a market record a non-zero quantity remains **unknown**.  The vtable
helper boundary does not establish a mapping from the raw key to
`inventoryByCommodityID`, market quality, peddler coverage, or route
settlement, so Native keeps Qin market settlement fail-closed.

**Sources:** canonical EN/CH PE hashes from `DESIGN.md`;
`local/source/split-merged/code/0x050000/FUN_005d2690.c`,
`FUN_005d2760.c`, `FUN_005d2790.c`, `FUN_005d4890.c`, `FUN_005d4810.c`;
`local/source/compare-report.tsv` rows `0x5d2690`, `0x5d2760`,
`0x5d2790`; cMarket constructor/save/load and call-site scans recorded in
§§10.32–10.32a; and direct EN/CH `.text` displacement/call inventory.

**Evidence class:** **confirmed** for the record layout, constructor values,
subtract/add/clamp/clear/overflow arithmetic, direct call inventory,
persistence boundary, and EN/CH parity; **confirmed negative** for another
direct quantity writer; **unknown** for indirect aliases, monthly/external
population, raw-key-to-authored-good mapping, and downstream quality/route/
settlement effects.

## 2026-09-03 `FUN_00590F30` has only one gameplay caller and one advisor-display caller

The canonical EN and CH `.text` sections were scanned for every direct `E8`
call whose resolved target is `FUN_00590F30 @ 0x590F30`.  Both hash-identified
images contain exactly the same two callsites: `0x59126A`, inside
`FUN_00591200 @ 0x591200`, and `0x5B8B4A`, inside the string-bearing
`Popularity_pctd @ 0x5B8740`.  The indexed EN/CH comparison rows for
`0x590F30`, `0x591200`, and `0x5B8740` are all `identical`.

The first call is the recovered popularity producer's food term: the return
value is saved as `ret4` and included in the factor sum before the popularity
clamp/damping.  The second call occurs in the advisor rendering body after
the UI has advanced its layout cursor; its result is formatted with the
`"food effect %d"` resource string (`0x85E9F0`) and passed to the text-draw
helpers.  It does not write `cHouseInfo`, a cMarket record, a figure, or a
provider registry slot.  This is therefore a confirmed direct-call inventory
for the consumer, and a confirmed negative against treating the advisor
display as a second food-state producer.

The census does not exclude indirect calls through a table or virtual slot,
nor does it identify the complete writer set for live `cHouseInfo +0x36`.
The monthly food input, market quantity/quality projection, and peddler route
remain **unknown**; Native must continue to keep the Qin producer fail-closed
and must not substitute the advisor's formatted result for the live byte.

**Sources:** canonical EN/CH PE `.text` direct-call census; `local/source/
split-merged/code/0x050000/FUN_00590f30.c`, `FUN_00591200.c`, and
`Popularity_pctd.c`; `local/source/compare-report.tsv` rows `0x590F30`,
`0x591200`, and `0x5B8740`; and string-table entry `0x85E9F0`.

**Evidence class:** **confirmed** for the two direct callers, the producer/UI
contexts, the resource string, and EN/CH parity; **confirmed negative** for a
second direct food-state writer in those callers; **unknown** for indirect
aliases and the complete `+0x36` writer/settlement projection.

## 2026-09-03 cStall `+0x18C` consumes source category slot `2` for every accepted shop model

The cStall pool index passed to `FUN_0051E310 @ 0x51E310` is now bounded at
the raw table level.  Its `+0x188` callback is `FUN_004271D0 @ 0x4271D0`,
which loads the first dword of the fixed table at
`DAT_008235A8 + modelID * 0x18` into the callback out-parameter.  The cStall
model gate `FUN_005418D0 @ 0x5418D0` admits exactly `0x3E` (62) and
`0x40…0x46` (64…70), besides the non-shop sentinels `-2` and `-1`.

Direct little-endian reads from both canonical PE images show that the first
table dword is **2 for every admitted cStall shop model** 62 and 64…70.  The
remaining row words differ by model (for example, model 62 is
`(2, 8, 0, 0, 0, 0)` while model 66 is `(2, 8, 2, 0, 1046, 0)`), so only
the first word is promoted here as the stable category index.  The shared
`FUN_004AE220 @ 0x4AE220` pass clears the category arrays and adds each
provider's `+0x1B0` value into `DAT_01312138[category * 5]` (and into the
second array only when provider `+0xF4` is true).  `FUN_004F19A0 @ 0x4F19A0`
then forwards the category-selected pool pair to every object's `+0x18C`
callback with selectors `1` and `2`.

This proves the cStall branch always consumes pool slot `2`; it does not name
the pool's player-facing resource, recover the values in its five-dword rows,
or establish a Native `MarketSquare`/workforce projection.  The cStall
`+0x44` producer, provider registry, peddler route, and household quality
settlement therefore remain **unknown**, and no runtime market behavior is
enabled from the category number alone.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004271D0.c`,
`FUN_004AE220.c`, `FUN_004F1590.c`, `FUN_004F19A0.c`;
`local/source/split-merged/code/0x050000/FUN_005418D0.c`;
`local/source/compare-report.tsv` rows `0x4271D0`, `0x4AE220`, `0x4F1590`,
`0x4F19A0`, and `0x5418D0`; and canonical EN/CH PE table bytes at
`DAT_008235A8` (identical 0x1800-byte table hash
`8ef3a801aaebba2906146c105ab7f64c7592e67f3b48df07b6f2aad890cab13e`).

**Evidence class:** **confirmed** for the cStall model set, category value
`2`, array write/read order, selector order, and EN/CH table identity;
**unknown** for category semantics, row-value production, Native projection,
registry ownership, routing, and settlement.

## 2026-09-03 Qin generic map records carry no source population-eligibility byte

The serialized generic `Building` stream exposes both the common object state
byte at `+0x04` and the `HouseBldg` population-callback byte at `+0x09` in the
same field order recovered from `FUN_00427430 @ 0x427430`.  The archive scanner
now retains the latter as `serializedHousePopulationEligibilityByte` without
assigning it a live class.  A complete scan of the four authored Qin maps,
using the existing archive transition and schema-specific record lengths,
finds the following exact distributions:

| map | generic records | `+0x04` | `+0x09` |
| --- | ---: | ---: | ---: |
| Haunxian | 3,962 | `0: 3,962` | `0: 3,962` |
| Xianyang | 3,998 | `0: 3,998` | `0: 3,998` |
| Xiangjun | 3,956 | `0: 3,956` | `0: 3,956` |
| Badaling | 3,906 | `0: 3,906` | `0: 3,906` |

This is a confirmed archive-level negative: no generic Qin record directly
supplies a non-zero `HouseBldg +0x09` population-callback input.  It does not
prove that a later class factory or post-load alias cannot set the byte; the
rehydration pass `FUN_0052F030 @ 0x52F030` still has to be followed for that
indirect path.  Native therefore must not derive `houseEligibilityByte` from
the generic payload, resident count, vacancy, or map record ordinal.  The
automatic migration producer remains fail-closed pending the specialization
and caller-order evidence.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`local/source/split-merged/code/0x050000/FUN_0052F030.c`,
`FUN_0052F1D0.c`, `local/source/compare-report.tsv` rows `0x427430`,
`0x52F030`, and `0x52F1D0`; `GameData/Cities/Haunxian.map`,
`Xianyang.map`, `Xiangjun.map`, and `Badaling.map`; and
`OriginalGenericBuildingArchiveCatalog`/`testQinGenericBuildingArchiveCatalogMatchesRecoveredRecordLayout`.

**Evidence class:** **confirmed negative** for non-zero serialized `+0x04` or
`+0x09` bytes in all four generic Qin runs and for the field offsets/order;
**unknown** for indirect specialization, alias writes, and Native object
equivalence.

## 2026-09-03 HouseBldg factory range is explicit, but Qin rehydration still is not

The model factory boundary can now be stated without conflating it with map
loading.  `FUN_0042D360 @ 0x42D360` calls `FUN_005188B0 @ 0x5188B0`; the
predicate is true exactly for model IDs `2...17`.  That branch allocates the
`HouseBldg` object through `FUN_0042D480 @ 0x42D480`, installs vtable
`0x7ABA38`, and initializes the `cHouseInfo` subobject through
`FUN_00517190 @ 0x517190`.  The factory predicate is EN/CH-identical.

The map-load path is separate: `FUN_0052F030 @ 0x52F030` filters records
through `FUN_0052F1D0 @ 0x52F1D0` before it calls the generic creator.  Its
30-case whitelist contains no model ID in `2...17`; the four Qin generic
archive runs also expose base type word `0`, so they do not independently
select the HouseBldg factory.  This is a confirmed distinction between
“explicit creator can make a HouseBldg” and “Qin archive records become
HouseBldg objects”.

Native records the factory predicate and addresses as research metadata only.
No map-load specialization, registry slot, `+0x09` initialization timing, or
population callback input is inferred from the factory range; automatic Qin
migration remains fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042D360.c`,
`Creating_pctd_type_pctd.c`, `FUN_0042D480.c`,
`local/source/split-merged/code/0x050000/FUN_005188B0.c`,
`FUN_00517190.c`, `FUN_0052F030.c`, `FUN_0052F1D0.c`,
`local/source/compare-report.tsv`, and the Qin generic archive scan above.

**Evidence class:** **confirmed** for the `2...17` factory predicate,
constructor/vtable edge, whitelist exclusion, and EN/CH parity; **unknown**
for archive specialization, registry assignment, and callback timing.

## 2026-09-03 `FUN_00591670` direct callers are monthly/UI consumers only

The canonical English and Chinese PE `.text` sections contain the same four
direct relative-call sites to `FUN_00591670 @ 0x591670`:

| call site | indexed caller | recovered role |
| --- | --- | --- |
| `0x53C078` | `FUN_0053C020 @ 0x53C020` | diagnostic/resource renderer; calls the producer and draws resource `0x1E16` |
| `0x59129E` | `FUN_00591200 @ 0x591200` | monthly popularity producer; stores the returned factor in `DAT_0131251C` and folds it into the popularity sum |
| `0x59165B` | `FUN_00591650 @ 0x591650` | conditional wrapper; invokes the producer only for a non-zero caller flag, then returns `param+0x2F64` |
| `0x5B8C08` | `Popularity_pctd @ 0x5B8740` | advisor display; formats the returned value as `"feng effect %d"` |

This is a confirmed direct-call census, including the negative result that no
other direct `call 0x591670` appears in either canonical `.text` section.
`0x59129E` is the monthly popularity producer.  The conditional wrapper at
`0x59165B` is also consumed by `FUN_005A8980 @ 0x5A8980` for effect arithmetic,
while the remaining direct sites are presentation paths.  The census does not
recover the object-vector source consumed by `FUN_00591670`, the full writer
set for object `+0xA0`, an archive-to-object projection for Qin maps, or any
indirect table/vtable alias.  Automatic migration therefore remains
fail-closed.

**Sources:**
`local/source/split-merged/code/0x050000/FUN_00591670.c`,
`FUN_00591200.c`, `FUN_0053C020.c`, `FUN_00591650.c`,
`local/source/split-merged/code/0x050000/Popularity_pctd.c`,
`local/source/split-merged/code/0x050000/FUN_005a8980.c`,
`local/source/compare-report.tsv` rows `0x591670`, `0x591200`, `0x53C020`,
`0x591650`, and `0x5B8740`; canonical EN/CH PE `.text` direct-call scans;
`Sources/EmperorCore/MigrationSimulation.swift`; and
`testFengShuiConsumerDirectCallsitesMatchCanonicalPECensus`.

**Evidence class:** **confirmed** for the four direct addresses, EN/CH parity,
and the caller roles above; **unknown** for indirect dispatch, `+0xA0`
production, Qin object specialization, and Native migration projection.

## 2026-09-03 Popularity production is reached through the 51-phase calendar boundary

The trigger order is explicit in the canonical scheduler.  Per-step
`FUN_005371A0 @ 0x5371A0` calls `FUN_004AC2B0 @ 0x4AC2B0` while the simulation is
active.  That dispatcher runs `DAT_00C82EF8` through phases `0...0x32`; after
exactly `0x33` calls it resets the phase counter and enters
`FUN_004AC650 @ 0x4AC650`.  The boundary advances `DAT_00C82EF0`, and invokes
`FUN_00591200 @ 0x591200` only when that sub-month value is `0` (the 16th-slice
wrap) or `8` (the midpoint).  In the boundary function the producer call is
followed by `DAT_00D6241C = DAT_013128C0` and `FUN_0053BB30`; later event and
settlement branches therefore observe the updated popularity state.

The EN/CH comparison report marks all four scheduler/producer functions
`identical` (`0x5371A0`, `0x4AC2B0`, `0x4AC650`, `0x591200`).  This closes the
calendar trigger order, but not the unresolved object-vector projection or
the `+0xA0` writer data needed to make Qin automatic migration live.  Native
records the addresses and phase constants as
`OriginalMonthlyPopularitySchedule` metadata and keeps the runtime producer
fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005371a0.c`,
`local/source/split-merged/code/0x040000/FUN_004ac2b0.c`,
`FUN_004ac650.c`, `local/source/split-merged/code/0x050000/FUN_00591200.c`,
`local/source/compare-report.tsv` rows `0x5371a0`, `0x4ac2b0`, `0x4ac650`,
and `0x591200`; `Sources/EmperorCore/MigrationSimulation.swift`; and
`testMonthlyPopularityScheduleMatchesCanonicalPhaseBoundary`.

**Evidence class:** **confirmed** for driver/dispatcher/boundary call order,
the `0x33` phase count, producer slices `0` and `8`, and EN/CH parity;
**unknown** for the source object-vector contents, indirect dispatch aliases,
and Qin migration projection.

## 2026-09-03 Placement producer has no map-load direct callsite

Direct relative-call scans of both canonical PE `.text` sections find exactly
seven calls to `FUN_0042B250 @ 0x42B250`, with identical addresses and call
bytes in EN and CH:

| call site | indexed caller | path |
| --- | --- | --- |
| `0x4150A9` | `FUN_00414F70` | generic clear-cell placement |
| `0x42B55D` | `FUN_0042B520` | placement preview/result wrapper |
| `0x4B2516` | `FUN_004B1250` | normal construction |
| `0x4B2882` | `FUN_004B2680` | type-2 construction |
| `0x540F34` | `FUN_00540E70` | market/shop object creation |
| `0x542B16` | `FUN_005428B0` | market/quay child creation |
| `0x544C53` | `FUN_00544B30` | market/quay recreation |

The indexed map-load pass `FUN_0052F030 @ 0x52F030` and its predicate
`FUN_0052F1D0 @ 0x52F1D0` have no direct call to `FUN_0042B250` in either
canonical `.text` scan.  Combined with the Qin generic archive's serialized
`+0xA0 == 0` distribution, this is a confirmed negative for a generic
archive-time feng-shui recomputation.  It does not exclude an indirect
vtable/table alias or a post-load routine outside this direct call graph, and
it does not identify the object classes behind the seven construction paths.
Native therefore keeps archive `+0xA0` projection and automatic migration
fail-closed.

**Sources:** direct EN/CH PE `.text` scans for `call 0x42b250`;
`local/source/split-merged/code/0x040000/FUN_00414f70.c`,
`FUN_0042b520.c`, `FUN_004b1250.c`, `FUN_004b2680.c`;
`local/source/split-merged/code/0x050000/FUN_00540e70.c`,
`FUN_005428b0.c`, `FUN_00544b30.c`, `FUN_0052f030.c`, `FUN_0052f1d0.c`;
`Sources/EmperorCore/MigrationSimulation.swift`; and
`testFengShuiPlacementProducerDirectCallsitesMatchCanonicalPECensus`.

**Evidence class:** **confirmed negative** for direct map-load recomputation
and for the seven EN/CH-parity callsites; **unknown** for indirect aliases,
archive specialization, and Native projection.

## 2026-09-03 Map-load call chain reaches the whitelist without feng-shui recomputation

The canonical map-load entry `FUN_0043ABF0 @ 0x43ABF0` calls
`FUN_0053D100 @ 0x53D100` after the archive/mission data has been opened.  The
rebuild sequence then invokes `FUN_0052F030 @ 0x52F030`, whose only model
filter is `FUN_0052F1D0 @ 0x52F1D0`, before running the later post-load passes.
Both the EN and CH compare rows mark all four functions `identical`.

There is no direct edge from this chain to `FUN_0042B250 @ 0x42B250`: the
complete EN/CH direct-call census above contains only construction, placement,
and market/quay callers.  Thus the recovered load order confirms the negative
boundary: map loading reaches the explicit rehydration whitelist, but does not
recompute the placement-time feng-shui word through the known producer.  The
remaining possibility is an indirect alias or an unindexed post-load write;
neither is recovered in the current corpus.  Native records this chain as
`OriginalMapLoadRehydrationChain` metadata and continues to reject a Qin
`+0xA0` projection rather than synthesizing one.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0043abf0.c`,
`local/source/split-merged/code/0x050000/FUN_0053d100.c`,
`FUN_0052f030.c`, `FUN_0052f1d0.c`; `local/source/compare-report.tsv` rows
`0x43abf0`, `0x53d100`, `0x52f030`, and `0x52f1d0`; canonical EN/CH direct
call scans; `Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`; and
`testQinMapLoadRehydrationChainMatchesCanonicalCallOrder`.

**Evidence class:** **confirmed** for the load-entry/rebuild/whitelist order,
EN/CH parity, and absence of a direct producer edge; **unknown** for indirect
post-load aliases and final Native object equivalence.

## 2026-09-03 Generic archive deserialization has no hidden `+0xA0` write

The generic map loader's object path is now bounded through the deserializer.
`FUN_0042D790 @ 0x42D790` calls `FUN_0042D0E0 @ 0x42D0E0`, which requests the
`Building` class from `FUN_0077FD90 @ 0x77FD90`.  On a new object,
`FUN_0077FD90` invokes the object's vtable `+8` read method; the generic class
loader installs the base `Building` vtable `0x7AB59C`.  The loader then inserts
the object and invokes vtable `+0xC0` when the raw load-eligibility byte allows
it.  The base `+0xC0` target is `FUN_004271B0 @ 0x4271B0`, whose recovered body
only checks vtable `+0x150` and performs list/helper calls (`FUN_0042B6B0`,
`FUN_0042B580`); it contains no `+0xA0` write.

The subsequent object pass `FUN_0042DA10 @ 0x42DA10` dispatches vtable
`+0x1C8`.  For the base `Building` and Qin-relevant service/entertainment
vtable families, that slot points to `FUN_00413A00 @ 0x413A00` (`xor al,al;
ret`), so it also cannot recompute placement feng-shui.  EN/CH comparison rows
for the loader, callbacks, and post-load pass are `identical`; the direct PE
vtable reads and no-op body are byte-identical in both canonical images.

This closes the known generic deserialization, `+0xC0`, and listed `+0x1C8`
paths as sources of a hidden `+0xA0` update.  It does not rule out an indirect
table alias outside these slots or a specialized class not in the checked
vtable set.  Combined with the seven-call placement-producer census and the
zero-valued Qin generic archive records, the remaining Qin migration blocker
is now specifically the unresolved runtime object projection/indirect alias,
not an overlooked generic loader callback.  Native remains fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042d790.c`,
`FUN_0042d0e0.c`, `FUN_004271b0.c`, `FUN_0042b580.c`, `FUN_0042b6b0.c`,
`FUN_0042da10.c`, `local/source/split-merged/code/0x070000/FUN_0077fd90.c`,
`FUN_0077fd11.c`; `local/source/compare-report.tsv` rows `0x42d790`,
`0x42d0e0`, `0x4271b0`, `0x42da10`, and `0x413a00`; direct EN/CH vtable
reads; and `OriginalMapArchiveRepairCatalog` in
`Sources/EmperorCore/HousingEvolution.swift`.

**Evidence class:** **confirmed** for the generic deserializer call order,
base callback body, listed no-op post-load targets, and EN/CH parity;
**unknown** for unlisted specialized vtables and indirect aliases.

## 2026-09-03 `FUN_00427430` treats `+0xA0` as a serialized field, not a load-time formula

The common `Building` serializer `FUN_00427430 @ 0x427430` has two explicit
branches selected by the archive I/O mode. In the write branch it emits object
`+0xA0` with `FUN_00780642(param_1 + 0xa0, 4)`. In every recovered read schema
(`ret == 3`, `ret == 4`, and the remaining legacy branch) it reads the same
field with `FUN_00780533(param_1 + 0xa0, 4)`. There is no arithmetic, terrain
lookup, model dispatch, or call to `FUN_0042B250` between mode selection and
that field access. The schema-4-only `+0x92` read occurs before the shared
`+0xA0` access; the later `+0xB4/+0xB8` tail is separate.

The canonical EN/CH compare row for `0x427430` is `identical`. The Qin map
loader reaches the read branch through `FUN_0042D790 → FUN_0042D0E0 →
FUN_0077FD90`, whose new-object path invokes the object's vtable `+8` method
with this serializer context. Therefore the recovered generic load path
projects `+0xA0` from archive bytes when present; it does not synthesize a
placement value inside the common serializer. The four shipped Qin generic
record scans still report `serializedPlacementValue == 0`, so this evidence
does not create a non-zero migration input or prove specialized post-load
projection. It only closes the serializer itself as a hidden producer.

The alternate-I/O object-vector loop (`FUN_0042D790` via
`FUN_0042DC60 → FUN_0077FD11`) uses the object-reference helper rather than the
new-object `FUN_0077FD90` path; it therefore supplies no additional generic
load callback or `+0xA0` formula. Its caller-level save/reference semantics do
not change the load-side conclusion. Indirect aliases outside the recovered
vtable slots and specialized object projection remain **unknown**.

One remaining direct `+0xA0` hit in the base-class family is
`FUN_00426EA0 @ 0x426EA0`: it copies the entire base record, including
`*(param_2 + 0xa0) = *(param_1 + 0xa0)`, and performs no calculation. The
indexed direct-caller census contains only the derived copy routine
`FUN_0051CAA0 @ 0x51CAA0` (plus the merged definition itself); neither is
called by the map-load chain. This is therefore a value-preserving alias, not
an additional load-time producer. Both EN/CH compare rows are `identical`.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`FUN_0042d790.c`, `FUN_0042d0e0.c`,
`local/source/split-merged/code/0x070000/FUN_00780533.c`,
`FUN_00780642.c`, `FUN_0077fd90.c`, `FUN_0077fd11.c`; compare row
`0x427430` in `local/source/compare-report.tsv`; and the packed-field and
four-map regressions in `Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`
and `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the common serializer's direct read/write
of `+0xA0`, schema ordering, EN/CH parity, separation of the object-reference
branch, and the base-copy alias boundary; **unknown** for caller-level
save/load labeling, indirect aliases, specialized projection, and any
non-generic post-load writer.

## 2026-09-03 Immigrant sprite frame counter is preserved at the render boundary

The previously recovered type-table slot `FUN_004D6D30 @ 0x4D6D30` is the
immigrant (model 11) sprite callback, not an occupancy or registry callback.
Its non-state-4 path reads the active figure's byte `+5`, reads the normalized
direction byte `+0x19`, and passes both to the shared sprite resolver together
with the model's slot-0 resource pointer. The think body
`FUN_004C9FD0 @ 0x4C9FD0` increments byte `+5` once per successful update and
wraps the increment to zero at 12 (`0x4CA062…0x4CA074`). Thus the source frame
index is an object field, not a renderer-tick choice. The canonical EN and CH
`FUN_004D6D30` slices (`0x4D6D30…0x4D6E28`, 249 bytes) are byte-identical with
SHA-256 `8d7b61656b7c8bf86ec882d081e44da7b4b0970ae6c09b4a9b2f57094d6c2287`
in both hash-matched executables. The complete think slice parity is recorded
in §10.78.

Native now persists an optional `ImmigrantWalker.sourceAnimationFrame`,
advances it with the same 0…11 wrap at the walker update boundary, and keeps a
`movedOnLastSimulationStep` presentation bit so waiting/substep updates do not
invent interpolation. `CityCanvas` includes `migration.immigrantWalkers` in
the figure render list and passes the persisted frame to the existing
`FigureSpriteAnimation.reference(direction:frameIndex:)`. Missing frame keys in
older saves remain `nil` and use the existing generic fallback until the next
update; no producer, route, house, or population state is enabled by this
change.

This closes the source-backed immigrant figure render/frame boundary only. The
canonical resource pointer selection, object-vector registration, producer
inputs, and arrival settlement remain the documented unresolved Qin gates, so
`AutomaticMigrationAvailability` stays `unsupportedOriginalProducer` in normal
campaigns.

**Sources:** canonical EN/CH PE slices at `0x4C9FD0…0x4CA337` and
`0x4D6D30…0x4D6E28`; `local/source/split-merged/code/0x040000/FUN_004c7580.c`
and `FUN_004e27e0.c`; `Sources/EmperorCore/MigrationSimulation.swift`,
`Sources/EmperorNative/CityCanvasEntityRenderer.swift`, and the focused
`MigrationSimulationTests` frame-wrap regression.

**Evidence class:** **confirmed** for the frame-byte increment/wrap, sprite
callback field reads, canonical EN/CH byte identity, and Native render handoff;
**unknown** for resource-pointer semantics, registry ownership, and all
automatic-producer/settlement inputs.

## 2026-09-04 City Gate/Tower labor allocation is an explicit source boundary

The remaining `+0x44` writer found near the market investigation belongs to
the military City Gate/Tower family, not to cStall/Empty Shop providers.  The
phase-`0x17` path is `FUN_004AC2B0 @ 0x4AC2B0` →
`FUN_004AD4A0 @ 0x4AD4A0` → `FUN_004AD850 @ 0x4AD850`.  In its second object
pass, `FUN_004AD850` admits only `FUN_0042B720` or `FUN_0042B730`; the indexed
bodies compare the model word to exactly `0x83` or `0x82`.  `GameData/Model/
EmperorBuildingModels.txt` names these rows City Gate (`130/0x82`) and Tower
(`131/0x83`), with model-table field 5 equal to `9` and `6` respectively.

For each admitted object the source checks `FUN_00426D10(0)` and the model
predicate, clears object `+0x44`, then requires the global `DAT_013124F4` gate
and the object's vtable `+0x58` predicate before calling
`FUN_00408B40(vectorIndex)`.  The latter rejects a non-zero object
`+0x6E` byte and otherwise returns `FUN_0044CC50(modelID, 5)`, which indexes
the 13-column building table at `DAT_00A5B398`; direct canonical EN/CH PE
instructions at `0x408B40` and `0x44CC50` confirm the field-5 lookup.  The
result is clipped to the shared remaining-labor word `DAT_01312134`, stored
as a signed short at `+0x44`, and subtracted before the next object-vector
row.  The vector begins at index 1 and is not sorted.  `FUN_00552940 @
0x552940` independently sums these `+0x44` values only for the same `0x82 /
0x83` model pair and compares them with each object's `+0x1B0` aggregate.

Native now records this exact arithmetic as the explicit-input
`OriginalMilitaryDefenseStaffingCatalog` in
`Sources/EmperorCore/MilitarySimulation.swift`.  Its candidates keep the
source vector index, `+0x6E` no-labor byte and `+0x58` callback result
explicit; its plan keeps both source gates (`FUN_00426D10(0)` and the
`DAT_013124F4` labor-allocator gate) separate, consumes a supplied
source-labor word in input order, and caps rows at `9`/`6`.  The helper is
intentionally not wired to
`WorkforceMonthlySettlement`: the executable's `DAT_01312134` producer and
the Native object-registry/field projection are not proven equivalent.  It
also does not infer sentry creation, combat strength, or cStall peddler
ratios from this military field.

The EN/CH comparison rows for `0x4AC2B0`, `0x4AD4A0`, `0x4AD850`,
`0x408B40`, `0x44CC50`, `0x552940`, `0x2B720`, and `0x2B730` are
`identical`; the canonical hashes remain EN
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

Evidence class: **confirmed** for the phase/call order, model IDs, field-5
caps, gate order, vector order, signed `+0x44` write and subtraction;
**unknown** for the source-labor producer's full semantic mapping, Native
registry projection, and all downstream staffing/sentry effects.  This closes
the military allocation arithmetic without changing the unresolved Qin
automatic-migration, market-provider, or war-count gates.

## 2026-09-04 Ferry connector computation gate is now an explicit pure boundary

The previously recovered Ferry method `FUN_004C6C70 @ 0x4C6C70` is now
represented by `OriginalGrandCanalLayoutCatalog.evaluateFerryConnectorComputationGate`
in `Sources/EmperorCore/GrandCanalSimulation.swift`. The helper preserves the
source's early-return order: local Ferry coordinates must be available first;
the object field at `+0x150` must then be positive; the global map lookup for
the paired endpoint coordinates must then succeed. Only after those three
conditions does the source call the placement flood (`FUN_005B33C0`) and the
cardinal gradient walk (`FUN_005B3670`), store its returned count at `+0x924`,
and return nonzero exactly when that count is nonzero. The Native result keeps
the rejection stage, both call-stage booleans, and the unmodified returned
count explicit, including a zero count that is a completed computation but a
false method result.

Focused `GrandCanalSimulationTests` cover each early return, prove that no
downstream stage is marked as called before both coordinate gates pass, and
cover both nonzero and zero gradient counts. The local corpus has no indexed
function file or `compare-report.tsv` row for `0x4C6C70`/`0x4C6D30`; the
underlying order and EN/CH identity are therefore taken from the direct
canonical-PE disassembly already recorded in §10.41, with the negative corpus
search retained as evidence rather than silently treating the address as a
decompiler omission.

This closes the call-order boundary only. The coordinate providers, paired
object registry, `+0x150` serialization meaning, placement scheduling, and
projection of the recovered PE map layers into Native remain **unknown**.
The helper is research scaffolding and does not enable live Ferry post-pass,
worker routing, or Qin automatic migration.

**Evidence class:** **confirmed** for the three-stage guard order, positive
`+0x150` predicate, placement/gradient sequencing, `+0x924` count write, and
return condition; **confirmed negative** for an indexed `local/source`
function/compare row at these two addresses; **unknown** for all live-object,
serialization, and Native map-layer mappings.

## 2026-09-04 Popularity producer factor pass is centralized without enabling Qin inputs

The canonical source body `FUN_00591200 @ 0x591200` is now represented by the
explicit-input `DeterministicMigration.originalPopularityProducerFactors` in
`Sources/EmperorCore/MigrationSimulation.swift`. The helper preserves the
recovered factor order and arithmetic: feng-shui + repression + constant `1`,
the `FUN_0055AE30` monument result doubled by the producer, debt, food,
employment, wage, and tax; it then applies the existing current-popularity
damping branches. The diagnostic walk starts at zero, scans food → employment
→ tax → wage → debt → factor 6 → feng-shui → repression, uses strict `<` so
equal negative factors keep the first slot, and leaves the previous blame slot
unchanged when no factor is negative. Factor 6 is supplied separately because
the source's scaled `DAT_01312500` value participates in blame only; its event
producer remains outside the campaign projection.

`DeterministicCityState.updateMigrationPopularity` now calls this centralized
pass with the already recovered Native terms. Its unresolved feng-shui and
factor-6 inputs remain explicit zero values, and normal campaign migration is
still `.unsupportedOriginalProducer`; this change does not synthesize map
objects, provider records, or immigrant arrivals. Regression coverage checks
the doubled monument term, first-winner blame tie, and preservation of a prior
blame value when all factors are non-negative.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00591200.c`,
`FUN_00591180.c`, `FUN_005911D0.c`, `FUN_00591130.c`, `FUN_00590F30.c`,
`FUN_00590F00.c`, `FUN_0055AE30.c`, `FUN_005915C0.c`, `FUN_00591670.c`,
`FUN_0053B730.c`; `Sources/EmperorCore/MigrationSimulation.swift` and
`CitySimulation.swift`; and the existing EN/CH parity rows for the listed
functions in `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the factor ordering, constant/doubling,
damping call, strict blame comparisons, and factor-6 diagnostic separation;
**unknown** for the unresolved object-vector producers and Native mappings of
feng-shui, festival, provider, and arrival state. The Qin automatic producer
therefore remains fail-closed.

## 2026-09-04 Monument matching walk is explicit and still registry-gated

`FUN_0055AE30 @ 0x55AE30` is now represented by the explicit-input
`DeterministicMigration.originalMonumentMatchingWalk`. The helper preserves
the source's building-vector index starting at `1`, active-state gate
(`+0x04 == 1 or 3`), monument-model switch (`76…86`, `92`, `93`, `253…268`),
root-only `+0x16 == 0` predicate, and `FUN_00565410(+0xB4, 0, 0) >= 100`
completion threshold. It then scans type-2 `cMonumentGoal` rows in authored
vector order. Exact IDs match directly; goal IDs `0x55`/`0x56` match any
building ID `253…268`. Every matching `(building, goal)` pair increments the
returned count, while every eligible mismatch writes that goal's `+8`
completion flag to false, preserving the source's later-mismatch clearing
behaviour and duplicate-root counting.

`MigrationSimulationTests` covers index-0 exclusion, inactive/non-root/
incomplete skips, the special Great Wall goal IDs, pair counting, and the
mutable completion-flag side effects. This replaces the prior Native-only
set-based approximation as a reusable source boundary, but no campaign code
feeds it: the live object vector, `cMonumentGoal` registry, `+0xB4` percent
producer, and serialized map projection remain unresolved. Consequently the
Qin migration producer remains fail-closed and no monument completion is
inferred from a building ID alone.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0055AE30.c`,
`FUN_00554C00.c`, `FUN_00562E80.c`, `FUN_00562F70.c`,
`FUN_00565410.c`; the direct EN evidence and goal/object field analysis in
§3; `Sources/EmperorCore/MigrationSimulation.swift`; and the focused
`MigrationSimulationTests` regression.

**Evidence class:** **confirmed** for vector order, all five building gates,
type-2 goal filtering, direct/special ID matching, pair-count semantics, and
`+8` writes; **unknown** for live registry/object projection, percent
production, save lifecycle, and Native equivalence.

## 2026-09-04 Ferry placement caller is present in the indexed source

The previously unresolved Ferry placement caller is now bounded by the
`local/source` corpus. `Placing_admin_city_at_pctd @ 0x46CB40` dispatches the
selected building ID `0xD2` (authored model 210, Ferry) to
`FUN_004C5E10 @ 0x4C5E10`. In its `DAT_01031498 != 0` branch that function obtains the
two endpoint coordinate pairs, then calls `FUN_004C62C0 @ 0x4C62C0`; the
wrapper invokes `FUN_005B33C0 @ 0x5B33C0` (placement flood) followed by
`FUN_005B3670 @ 0x5B3670` (cardinal gradient walk), writes the returned
direction count to its output, and accepts the placement only after the
direction/orientation and endpoint-neighbour checks pass. The indexed
`FUN_004C62C0` row is `identical` in EN/CH and its sole corpus caller is the
Ferry case in `FUN_004C5E10`.

This closes the **direct selected-building → connector-computation call
chain**, which was previously recorded as an unknown placement caller. It does
not yet close the endpoint-coordinate provider, the PE directional-layer
projection, the output buffer's object ownership, or the final object/archive
write. `PlacedBuilding` therefore still cannot manufacture connector points;
the city routing projection remains fail-closed for a live Ferry. The new
source-backed metadata is centralized as
`OriginalGrandCanalLayoutCatalog.FerryPlacementCallerCatalog` and is covered
by a focused regression without changing gameplay wiring.

**Sources:** `local/source/split-merged/code/0x040000/Placing_admin_city_at_pctd.c`,
`FUN_004c5e10.c`, `FUN_004c62c0.c`, `local/source/split-merged/code/0x050000/
FUN_005b33c0.c`, `FUN_005b3670.c`, `functions-index.csv`, and
`compare-report.tsv` row `0x4c62c0`.

**Evidence class:** **confirmed** for the selected Ferry dispatch, caller
chain, flood→gradient order, output-count handoff, and EN/CH parity;
**unknown** for endpoint/map-layer projection, connector persistence, and
Native placement integration.

## 2026-09-04 Ferry placement endpoint argument provenance is bounded

The same indexed caller also bounds what enters the two endpoint probes. In
`FUN_004C5E10 @ 0x4C5E10`, the first pair passed to
`FUN_004C62C0 @ 0x4C62C0` is the current placement coordinate held in
`DAT_0101D0F4/DAT_0101D0F8`. The second pair is loaded from the selected Ferry
record returned by `FUN_0047F1B0(DAT_01031488)`: the decompiler shows the
record's low coordinate fields at byte offsets `+0x0A` and `+0x0C` (the latter
read through `src[3]`). The same record supplies the byte at `+0x07` as the
map-layer selector; the selected object's `+0x60` byte, doubled, supplies the
orientation selector used by the call. These are call-site facts, not a claim
that the Ghidra field names are authoritative.

`FUN_004C62C0` sends each coordinate pair through
`FUN_004BA9E0 @ 0x4BA9E0`. That helper scans the layer-offset table at
`DAT_00820038` against the terrain/object words at `DAT_00F6A9E0`; on a match
it writes the resolved endpoint cell to `DAT_010C72A8/DAT_010C72AC`. Only after
both probes succeed does the caller invoke the placement flood and gradient
walk. `FUN_004BA9E0` is `identical` in the EN/CH comparison report.

This closes the **argument provenance and probe ordering** for Ferry placement.
It does not identify the Native equivalent of the PE terrain/layer arrays, the
object-vector owner of the returned `local_fa0` connector buffer, or the final
write into the Ferry object's `+0x154/+0x924` state and archive. Those remain
**unknown**, so the live Ferry routing and Qin automatic-migration producer
continue to fail closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004c5e10.c`,
`FUN_004c62c0.c`, `FUN_004ba9e0.c`, `FUN_0047f1b0.c`,
`functions-index.csv`, and `compare-report.tsv` rows `0x4ba9e0` and
`0x4c62c0`.

**Evidence class:** **confirmed** for the two endpoint argument sources, the
layer-selector/orientation inputs, the two-probe order, and the EN/CH parity;
**unknown** for PE-layer projection, connector-buffer ownership, and object/
archive persistence.

## 2026-09-04 City Gate/Tower labor-pool tables are recovered as raw inputs

`FUN_004AD850 @ 0x4AD850` computes the shared labor word consumed by its
City Gate/Tower assignment pass as

```
DAT_01312134 = floor(n3 * (ret3 + ret2 + n) / 100)
```

where `n3` is the sum of positive object `+0x20` words after the source's
`FUN_00516ED0` exclusion, `ret3` is indexed by `DAT_010DE2E0`, `ret2` is
indexed by `FUN_00592BD0`, and `n` is indexed by the five-way popularity band
derived from `DAT_0130F97C`. Static bytes at the canonical data addresses are
identical in both hash-matched executables:

| source table | address | recovered signed DWORDs | use visible at `0x4AD850` |
| --- | --- | --- | --- |
| `ret3` | `DAT_00847410` (`0x847410`) | `[50, 45, 40, 37, 35]` | base percentage, index `DAT_010DE2E0` |
| `ret2` | `DAT_00847424` (`0x847424`) | `[-10, -6, -3, 0, 3, 5, -2]` | additive percentage adjustment, index `FUN_00592BD0()` |
| `n` | `DAT_0084743C` (`0x84743C`) | `[-2, -1, 0, 1, 2]` | additive popularity-band adjustment |

The executable body and data are therefore sufficient to preserve the exact
arithmetic and table values as explicit inputs. Native now exposes those
values through the pure `OriginalMilitaryDefenseLaborPoolCatalog` helper and
tests the percentage and integer division independently; the helper accepts
all three source indices explicitly and is not wired to the city loop. They
are not sufficient to name the `FUN_00592BD0` receiver/index domain or to
prove that Native's workforce total is the source `n3` object-vector sum. No
runtime staffing or Qin migration gate is changed; callers must continue to
provide this labor pool explicitly until that object projection is recovered.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ad850.c`,
`FUN_00592bd0.c`, `FUN_00592be0.c`, `FUN_00408b80.c`,
`local/source/compare-report.tsv` rows `0x4ad850`, `0x592bd0`, `0x592be0`,
`0x408b80`; `Sources/EmperorCore/MilitarySimulation.swift` and its focused
regression; and raw `.data` bytes at `0x847410`, `0x847424`, and `0x84743C`
from canonical EN
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

**Evidence class:** **confirmed** for the formula, table addresses/values,
indexing sites, and EN/CH byte identity; **unknown** for the
`FUN_00592BD0` index domain, source object-vector specialization, and Native
workforce equivalence.

## 2026-09-04 HouseBldg creation setter invokes the eligibility initializer

The explicit HouseBldg creation path now has a caller-order edge that was
missing from the earlier direct-writer census. In both canonical PEs,
`FUN_0042D540 @ 0x42D540` dispatches the newly created object through its
vtable `+0x94`, whose HouseBldg entry is the unindexed setter
`0x428AA0`. The recovered setter body is the byte-identical
`0x428AA0..0x428C01` slice documented in the creation-origin section above.
After writing the model/coordinate/map-origin fields and the creation-time
base fields, the setter loads the object vtable and calls `+0x90` at
`0x428B25`; the HouseBldg vtable `0x7ABA38 + 0x90` points to
`FUN_00518B70 @ 0x518B70`.

The `FUN_00518B70` body then calls the common reset, writes
`HouseBldg + 0x09 = 1`, derives `+0x16` from model word `+0x14`, and performs
the model-range branch that initializes the remaining house fields. This
proves the following **explicit-creation** order:

```text
FUN_0042D540
  -> HouseBldg vtable +0x94 (0x428AA0)
     -> HouseBldg vtable +0x90 (0x518B70)
        -> write object +0x09 = 1
```

This is stronger than treating `0x518B70` as an unreferenced direct writer,
but it does not prove that a generic Qin archive row reaches
`FUN_0042D540`, `0x428AA0`, or the specialized `0x7ABA38` vtable. The map-load
whitelist and archive-to-object registry edge therefore remain unresolved;
Native records the two slot/target addresses as research metadata and keeps
Qin automatic migration fail-closed.

**Sources:** canonical EN/CH PE slices at `0x42D540`, `0x428AA0..0x428C01`,
and vtable `0x7ABA38`; `local/source/split-merged/code/0x040000/
Creating_pctd_type_pctd.c`; `FUN_0042D480.c`; `FUN_00518B70.c`; and
`local/source/compare-report.tsv` rows `0x518B70` and `0x42D480`.

**Evidence class:** **confirmed** for the explicit-creation dispatch order,
vtable slot targets, `+0x09` write, and EN/CH identity; **unknown** for
archive rehydration, indirect/table aliases, and the Native object-equivalence
edge needed to enable automatic Qin migration.

## 2026-09-04 Native invasion projection removes an unsupported siege-count rule

The prior Native `EnemyMilitaryForce` projection derived
`siegeEngineCount = invasionAmount / 32` and applied an extra `120` structural
damage per derived engine. No such relation is present in the recovered Qin
call chain. `FUN_00522D30 @ 0x522D30` creates normal model-`62` catapult
figures through the same per-group allocator as models `58…61`; the event
handler instead obtains its separate warning aggregate from
`FUN_0054D850 @ 0x54D850` over active 64-slot records. The inspected source
functions contain no amount-to-32 conversion, and `compare-report.tsv` marks
the relevant EN/CH rows identical. The manual/video establish that catapults
can perform structure attacks, but do not provide a Native aggregate count or
the missing per-unit attack/target sequence.

Native therefore now leaves `EnemyMilitaryForce.siegeEngineCount` and
`MilitaryCombatReport.enemySiegeEngineCount` at zero unless a future
source-backed live projection supplies them. Model-`62` remains present in the
stored `OriginalInvasionFormationPlan`; it is not silently discarded or
reinterpreted as a fixed damage batch. The regression formerly asserting two
engines for amount `64` now asserts zero, while still verifying authored entry
movement and combat completion. This is a fidelity correction: it removes an
unsupported player-visible marker and structural-damage shortcut rather than
claiming that the original has no siege behavior.

Evidence class: **confirmed negative** for the former `/32` Native rule in the
recovered builder/handler path and **confirmed** for model-`62` figure creation;
**unknown** for the source catapult live object, target selection, attack
timing, structure damage, and renderer projection. Until those edges are
recovered, no Qin siege count or batch-building fire may be synthesized.

## 2026-09-04 Enemy threat allocator admission is a finite two-byte predicate

`FUN_0054C4F0 @ 0x54C4F0` is now represented by the pure
`OriginalInvasionThreatRecordLifecycle.firstAllocatableSlot` helper. The
canonical body starts at enemy slot `0x23` (`35`) and advances by the unified
record stride `0xB4` through 64 candidate rows. A row is admitted only when
both its active byte at `record + 0x00` and lifecycle byte at `record + 0x69`
are zero; the first admitted row is initialized by `FUN_005512D0` and the
allocator returns its slot index. The EN/CH comparison row for `0x54C4F0` is
`identical`. The helper rejects any input other than exactly 64 states rather
than padding an absent row.

This closes the source-side admission predicate and scan order. It does not
authorize Native to map one compressed `EnemyMilitaryForce` to one source
record: `FUN_00522D30` can allocate multiple records per invasion category,
the figure-link array and placement/route writes remain separate, and the
archive load/rebuild projection is not recovered. Native therefore keeps the
helper research-only and continues to fail closed for live 64-slot registry
rehydration.

**Sources:** canonical `local/source/split-merged/code/0x050000/
FUN_0054C4F0.c`, `FUN_005512D0.c`, `FUN_00522D30.c`, `functions-index.csv`,
and `compare-report.tsv` row `0x54c4f0`; `Sources/EmperorCore/
MilitarySimulation.swift`; and the focused lifecycle regression in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the starting slot, 64-row/`0xB4`
scan, both admission bytes, initializer call, and EN/CH parity; **unknown**
for live record ownership, per-group route/figure registration, and save
rehydration into Native.

## 2026-09-04 Wage nearest-match object is fully address-bound, but not a Qin producer

The wage factor's nearest-match receiver is now recorded without relying on
the decompiler's implicit `this` argument.  Canonical EN/CH disassembly at
`0x592BB0` constructs the object at `DAT_0130F820` with the threshold table
at `0x85CC74`, count `6`, and the current-wage pointer `DAT_01312214`.
`FUN_00592BD0 @ 0x592BD0` loads that object address and jumps to
`FUN_00592BE0 @ 0x592BE0`; the latter scans absolute distances and retains the
first entry on equal distance.  The six threshold/effect rows are therefore
`[0, 20, 26, 30, 34, 40] → [-10, -5, -2, 0, 2, 4]`, with the source init
`FUN_00590A70` setting the current wage to `30`.

The only indexed consumer of this result in the recovered factor pass is
`FUN_004AD850 @ 0x4AD850`, called by the monthly popularity update
`FUN_004AD4A0 @ 0x4AD4A0`; it adds the wage effect to the City Gate/Tower
labor-pool percentage.  No edge from this matcher reaches the Qin archive
loader, provider registry, house settlement, or the automatic-migration
arrival writer.  Native centralizes the addresses and rows in
`OriginalWageEffectCatalog` and keeps them an explicit-input helper only.

**Sources:** canonical EN/CH PE bytes at `0x592BB0`, `0x592BD0`, and
`0x592BE0`; `.data` rows at `0x85CC5C` and `0x85CC74`; indexed
`FUN_00590A70.c`, `FUN_00592BD0.c`, `FUN_00592BE0.c`, `FUN_004AD850.c`, and
`FUN_004AD4A0.c`; `compare-report.tsv` rows `0x592BD0`, `0x592BE0`, and
`0x5911D0`; and `Sources/EmperorCore/MigrationSimulation.swift`.

**Evidence class:** **confirmed** for the receiver address, constructor
fields, table rows, tie rule, baseline initialization, and monthly consumer;
**confirmed negative** for a recovered Qin-loader or arrival edge;
**unknown** for the object-vector projection that supplies the labor total and
for any separate Qin wage-state serialization.

## 2026-09-04 Explicit creation writes its vector slot to object `+0xB4`

The `+0xB4` field has a confirmed writer on the explicit object-creation path,
but that writer must not be generalized to the unresolved Qin archive
projection.  `FUN_00413B40 @ 0x413B40` returns the object-vector pointer at
`base + slot * 4`.  `Creating_pctd_type_pctd @ 0x42D540` replaces that entry
with the object from `FUN_0042D360`, then stores the selected slot into the new
object's dword at `+0xB4` before dispatching its vtable `+0x94` setter.  The
source therefore establishes a one-to-one vector-slot/index write for objects
created through this entry point.

This does not identify the `+0xB4` semantic for a provider, nor does it show a
generic Qin archive record reaching `Creating(...)`: the four authored generic
Qin runs expose model `0` and serialized tail `-1`, while the known
`FUN_0052F030` rebuild whitelist excludes those rows.  Native records only the
field/producer addresses in `OriginalMapLoadRehydrationChain`; provider
registry provenance, route, coverage, and household settlement remain
**unknown**, so automatic migration stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/Creating_pctd_type_pctd.c`,
`FUN_00413B40.c`, `local/source/compare-report.tsv` rows `0x42D540` and
`0x413B40`, canonical EN/CH bytes at `0x42D72E…0x42D736`, and
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`.

**Evidence class:** **confirmed** for vector-slot lookup and the explicit
`+0xB4` write; **unknown** for archive-to-vector population and all provider/
house settlement projections.
