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
(`FUN_004C9FD0` @ `0x4CA265`). Food, monument, war, mode, and several
house-field semantics remain unresolved, so the producer stays
fail-closed. Never treat assigned/accounted `DAT_01311FCC` as an arrival
success.

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
| monument | `FUN_0055AE30`; empty building list (`FUN_00554C00() < 2`) returns `0` | confirmed |
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

### Food (`FUN_00590F30`) — partial; Native field unmapped

Empty/unoccupied houses (`(short)p[8] == 0` at `house+0x20` residents)
reset accumulator `p[0x23]` (`+0x8C`). Non-empty houses
(`house+0x20 != 0`) may update it: if `FUN_00516ED0` returns `0`, add
`FUN_0044CC80(model, 0xE) + (40 - popularity)/2`; column `0xF` is then
a lower bound — if the accumulator is `<` col `0xF`, it is raised to
col `0xF`; then values `>100` are capped at `100`. `FUN_00516ED0` /
`FUN_005188D0` skips that stock update when building type is
`11…17` (`confirmed` type window; role `inferred`).

The popularity **average** uses model column 8
(`FUN_0044CC80(..., 8)` = `foodQualityRequired`):

- required `0` → reset streak byte `*(p+0x17)` (`+0x5C`) and skip the
  average;
- else compare `*(byte *)((vtable +0x1E4)() + 0x36)` to required:
  met → `+2` and streak `0`; else increment streak, cap `3`;
  streak `1 → −1`, `2 → −2`, `≥3 → −3`.
- mean of those per-house scores, rounded away from zero when
  `|remainder| > counted/2`; negative mean zeroed while population
  `<350` and `DAT_01312575 == 0`.

Native `ResidentialUnit.lastSuppliedFoodQuality` is **not** the
`+0x36` byte. Inventing a parallel shortage-streak map to drive
gameplay is forbidden. Empty occupied-house set returns `0`
(`confirmed`).

### Monument matching (`FUN_0055AE30`) — fail-closed

Empty city returns `0` (`confirmed`). Live matching walks buildings
against campaign objects with `*(int *)(*p + 4) == 2`, building
`+0x16 == 0`, `FUN_00565410(...) > 99`, then either exact
`building+0x14 == object+0xC` or object IDs `0x55`/`0x56` with
building type in `0xFD…0x10C`. Native does not wire that walk;
passing `0` while marking the producer `supported` is forbidden.

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
     `+0x230(3)`;
   - if that is false **and** `DAT_00D62408 == 0`, call
     `+0x230(0xD)`;
   - if `DAT_00D62408 != 0`, skip `+0x230`. Method identity and
     `DAT_00D62408` meaning are **unknown** (no `.text` absolute
     writer to `DAT_00D62408` was found; three reads only:
     `FUN_0042D9A0`, `FUN_004ACD00`, this site).
4. `eax = house vtable +0x1E4()`; if `*(byte *)(eax + 0x3C) != 0`,
   **skip** the add/`FUN_00591900` pair. The `+0x3C` byte’s semantic
   name is **unknown**. One confirmed writer of that byte on the
   `+0x1E4` object is `FUN_004681A0` (stores `param_2`; caller
   `FUN_00468420` passes `2` while subtracting house residents). Do
   not treat that as a complete `+0x3C` map.
5. If `+0x3C == 0` (`0x4CA25C…0x4CA27E`):
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
migration producer: food / monument / war / mode / `house+0x24` /
`+0x3C` / `DAT_00D62408` semantics are unresolved.

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

## 6. Month rollover (confirmed)

`FUN_004AC650` copies `DAT_01311FCC` → `DAT_01312604` and zeros
`DAT_01311FCC` when the 16th slice wraps.

## 7. Native implementation contract (fail-closed)

The original immigrant arrival state machine in §5 is recovered.
That does **not** authorize enabling automatic migration. Food,
monument, war, mode, `house+0x24`, needs-object `+0x3C`, and
`DAT_00D62408` remain unresolved. Do not spawn walkers or call
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
- drive popularity from `lastSuppliedFoodQuality` or an invented
  shortage streak;
- pass monument / war / mode as `0` and mark the producer supported;
- upgrade `unsupportedOriginalProducer` saves to a supported tag;
- spawn immigrant walkers;
- implement advisor modes 1/2 or render group-55 row 11;
- invent a Great-Wall first-playable state.

## 8. Remaining unknowns

- Original semantic name of `HouseBldg+9` (the byte `FUN_0042DD40`
  tests; complete writer set is not recovered). House vtable
  `+0xB8` itself is §5.8.
- House vtable methods used by `FUN_004C9FD0`: `+0x1E4` (object
  whose `+0x3C` gates the add), `+0x230` (empty-house call with `3`
  or `0xD`).
- Semantic name of that `+0x3C` byte (gate is confirmed; complete
  writer set is not).
- `DAT_00D62408` writer and meaning (empty-house `+0x230` skipped
  when nonzero; no `.text` absolute writer found).
- `FUN_004BA6F0` neighbor-slot / terrain-flag meaning beyond the
  recovered reads and the `DAT_010C72AC` / `DAT_010C72A8` writes.
- Whether `FUN_004C8B70` type-`0xB` death unlinks the spawn house
  (`+0x64` test vs `+0x62` lookup).
- `DAT_01311FD0` mode writer (corpus has reads in `FUN_0053B850` /
  `FUN_00548340` / `FUN_005D7F70` only; no `DAT_01311FD0 =`
  assignment).
- Native military-figure mapping for `DAT_01312564`
  (`FUN_004EBB40` / `FUN_004E2560` types `0x3A…0x3E`, `0x4E`).
- `FUN_0055AE30` monument-object matching walk.
- Original food-stock columns `0xE`/`0xF`, house `+0x8C` accumulator,
  house `+0x5C` streak, and the `vtable +0x1E4` object `+0x36` food
  byte versus Native `lastSuppliedFoodQuality`.
- `DAT_01312214` runtime writers besides init (player wage buttons
  write `DAT_01312218`).
- Native mapping of `house+0x24` (lifecycle and
  `DAT_01391FE0` snapshot are in §5.7; overlay label is `rome`, not
  `roadnet`; no Native field is authorized).
