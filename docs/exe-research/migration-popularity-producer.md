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
complete `+0x36` writer set is not proven. Current Native
`ResidentialUnit` food consumption, blending, and cadence are
confirmed non-isomorphic to the recovered original, so those
fields must not be substituted. The producer of `cMarket+0x180`
and the correct Native representation/mapping remain open, and
food stays a fail-closed producer input. No implementation contract is
authorized. The `FUN_0055AE30`
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

## 3. Factor formulas

### Tax (`FUN_00591180`) — confirmed

`EmperorTaxSentimentModel.txt` via `EconomyRulesEngine.taxSentiment`.
Coverage `≤10%` forces the None row. Negative effects are suppressed
while population `<350` and the city has never exceeded 349
(`DAT_01312575`).

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
`compare-report.tsv` row; do **not** call it identical. Ghidra
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
increment figure `+0x41`; when the byte is `> 0x13` they call
`FUN_004EACD0` @ `0x4EACD0`. That function:

- figure `+0x12 == 0x26` (38, Elite Couple) → return 0;
- figure `+0x12 == 0x4F` (79, Player's Heroes) →
  `FUN_00429E10(figure, 2, 0, &LAB_00515120)` (hero visit,
  **not** `cMarket+0x2c`);
- else home building from figure `+0x62` → vtable `+0x28(figure, 2)`.

For a figure whose home object is `cMarket`, that is
`FUN_00429DF0` → Chebyshev radius **2** → `cMarket+0x2c(figure,
house)` = `0x5437B0`. Peddler (model 23) is the manual’s
distributor (`inferred` that a live peddler’s `+0x62` is a
`cMarket`; the code path itself does not test model 23). Whether
marketplace buyer (24) or other market employees on
`FUN_004E7EB0`/`FUN_004E6D80` also hit this writer is
`unknown`.

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
     `DAT_007ACA3C = 0.5`, `DAT_007B7244 ≈ 0.33`. Branches use
     `fcomp` / `test ah, 0x41` (not-greater). Signed integer
     blends (`confirmed` identities):
     `r > 3` → `(current + 3*market) / 4`;
     `r > 2` → `(current + 2*market) / 3`;
     `r > 0.5` → `(current + market) / 2`;
     `r > ≈0.33` → `(2*current + market) / 3`;
     else `(3*current + market) / 4`.
     (`/3` is `imul 0x55555556`; `/4` is MSVC signed `sar 2`.)

`FUN_00545140` @ `0x545140` (`identical`) is
`*(this+0x180) = param_2`. Recovered callers besides the
post-delivery zero: constructor/init zeros (`0x5435BB`,
`0x544D18` when `FUN_00544340(0x1c)==0`), figure `+0x16c` raise
(`0x5411EA`; `FUN_00541130` copies `FUN_00515770` onto
figure `+0x16c` when building type `== 0x42` food shop), a
float-round copy at `0x541858`, and `FUN_00511080` case 4
(`identical`) which adds up to `0x14` then stores. The producer
of `cMarket+0x180` (market / food-shop quality dword consumed by
`0x5437B0`) is **not** closed. Do **not** assign that dword or
its producer to `cMillBldg` unless a mill-object store is
directly proven. Do **not** treat Native
`OriginalFoodCatalog.quality(in:)` as that writer.

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
| `0x543A09` in `0x5437B0` | `bl` from `cMarket+0x180` (replace or ratio-blend) | recovered normal market-delivery store, confirmed; `cMarket+0x180` producer open; complete `+0x36` writer set not proven |
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

#### Native mapping — not isomorphic; do not implement

Numeric `FoodQuality` raw `0/20/30/50/70/90` matches
`cHouseInfo+0x36`, model column 8, and the named mill table on
manual p.48 (`confirmed` unit set only). Matching those enums does
**not** make Native fields isomorphic. The recovered behaviors
differ (`confirmed` mismatches):

| Native `ResidentialUnit` | recovered original used here | verified behavioral mismatch |
| --- | --- | --- |
| `foodSupplyAmount` | word `cHouseInfo+0x12` (Dinners slot 0) | Native `consumeFood` requests `residents` when `foodQualityRequired > 0`. Original monthly drain is `(residents * 25) / 100` and only when model column 8 `> 0`. Cadence: Native settlement vs original `FUN_004AC650` month wrap |
| `foodQualityRawValue` | live `cHouseInfo+0x36` | Native `addFoodSupply` **min**-blends and zeros quality whenever stock hits 0 on consume. Recovered market delivery **replaces** if market quality `>` current, else ratio-blends with floats 3/2/0.5/≈0.33. Original zeros `+0x36` on the monthly path when `+0x12 < 1`. Cheat writes `20`; hero case 4 writes `90` — they do **not** zero `+0x36` |
| `lastSuppliedFoodQualityRawValue` | **no recovered original equivalent** in `cHouseInfo` or the `FUN_00590F30` consumer | Native `recordEvolutionSupplies` snapshots current quality iff `foodSupplyAmount >= residents`, else `.none`, on monthly market settlement. `FUN_00590F30` reads **live** `+0x36`. This is not an exhaustive proof that no original global snapshot exists. Do not substitute |
| `suppliesByCommodityID` | `cHouseInfo+0x12` word array | Native consumes food through `foodSupplyAmount`, not a Dinners key in that dictionary. Original monthly food drain is Dinners slot 0 of the same word array as hemp/ceramics. Layout difference is supporting, not by itself proof of absence of an equivalent |

Native has no `house+0x5C` streak and no `house+0x8C` dword from
columns 14/15 on this cadence, no recovered hero `0x5A`
house-visit, and no `(residents*25)/100` Dinners drain. The
producer of `cMarket+0x180` (market / food-shop quality) is not
closed. Swift `OriginalFoodCatalog.quality(in:)` matches **manual
p.48**, not the recovered `+0x36` store. Do not substitute
`lastSuppliedFoodQuality` for `FUN_00590F30`. Do not change
Swift. Production stays `unsupportedOriginalProducer`. **No
gameplay implementation contract** until the `cMarket+0x180`
producer, peddler-vs-buyer exclusivity, hero case-4 identity, and
unencoded `+0x36` writer set required for fidelity are closed.

#### CH/EN (`compare-report.tsv` rows only)

`identical`: `FUN_00408B80`, `FUN_00413B40`, `FUN_00426D10`,
`FUN_00426EA0`, `FUN_00427430`, `FUN_00429DF0`, `FUN_00429E10`,
`FUN_0044CC80`, `FUN_00447600`, `FUN_004AC650`, `FUN_004E6D80`,
`FUN_004E7EB0`, `FUN_004EACD0`, `FUN_00503E20`, `FUN_00510C20`,
`FUN_00511080`, `FUN_005149C0` (constructor only; the `0x5A` store
is not in this function), `FUN_00515770`, `FUN_00516ED0`,
`FUN_00517190`, `FUN_00517330`, `FUN_00518490`, `FUN_00518690`,
`FUN_005188B0`, `FUN_005188D0`, `FUN_00518910`, `FUN_00541130`,
`FUN_00544340`, `FUN_00544F10`, `FUN_00545100`, `FUN_00545140`,
`FUN_00554C00`, `FUN_00590F30`, `FUN_005D16D0`. No
`compare-report.tsv` row for `FUN_00416B50`, unsplit `0x5437B0`,
unsplit `0x515120`, or `cHouseInfo` vtable `+8` @ `0x517410`; do
**not** call them identical. `FUN_005149C0` @ `0x5149C0` ends
around `0x51511E`; `0x515120` is the next unsplit function.

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
Current Native `ResidentialUnit` food consumption, blending, and
cadence are confirmed non-isomorphic, so those fields must not be
substituted. The producer of `cMarket+0x180` and the correct Native
representation/mapping remain open, and food stays a fail-closed
producer input.
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
- Producer of `cMarket+0x180` (market / food-shop quality dword
  consumed by `0x5437B0`; zeros, copies, `+0x14` bless, and a
  float-round copy are §3; the computer that produces the
  20/30/50/70/90 value is not closed). Do **not** assign that
  dword to `cMillBldg` unless a mill-object store is directly
  proven. Peddler (23) vs marketplace buyer (24) exclusivity on
  `FUN_004EACD0` → `cMarket+0x2c`. Hero model-79 case-4 identity
  for the `0x5A` store. Unencoded `+0x36` writers beyond §3; the
  complete writer set is not proven. Current Native
  `ResidentialUnit` food consumption, blending, and cadence are
  confirmed non-isomorphic (§3), so those fields must not be
  substituted. The correct Native representation/mapping remains
  `unknown`. No gameplay implementation contract is authorized. Do not
  name `house+0x8C` `crimeRisk`.
- Complete constructor-zero set for `house+0x5C` / `house+0x8C`
  beyond the empty-house `+0x8C = 0` write and `FUN_00427430`
  save/load.
- `DAT_01312214` runtime writers besides init (player wage buttons
  write `DAT_01312218`).
- Native mapping of `house+0x24` (lifecycle and
  `DAT_01391FE0` snapshot are in §5.7; overlay label is `rome`, not
  `roadnet`; no Native field is authorized).
