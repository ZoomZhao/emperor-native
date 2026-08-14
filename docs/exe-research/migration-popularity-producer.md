# Migration and popularity producer (`FUN_00591200` / `FUN_004AD4A0`)

Read-only control-flow recovery for automatic immigration. Binaries:
`Emperor[EN].exe` (`8a6d2df1…6753`, canonical) and `Emperor[CH].exe`
(`dbdeca1e…15a`). Named functions are CH/EN identical in
`local/source/compare-report.tsv`.

This note records recovered constants and the remaining blockers. It does
**not** authorize a Native occupancy producer. Production stays
`AutomaticMigrationAvailability.unsupportedOriginalProducer` until the
figure-`#11` arrival write chain and unmapped factor inputs are recovered.

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
`*(short *)(house + 0x24) > 0` (`confirmed` read). The Native semantic
mapping of `+0x24` is **not recovered** in this pass (`unknown`). Do
not summarize the walk as vacancy/capacity only, and do not equate
`+0x24` to Native road adjacency without evidence.

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

Arrival occupancy search (2026-08-14, `local/source/split-merged`):

- no `house+0x20 += figure+0x6e` writer;
- `FUN_004C8B70` on figure death clears `house+0x32` when
  `figure+0x64 != 0` (in-flight unlink, not occupancy);
- `FUN_004AE1A0` writes `house+0x20` only on negative-capacity
  homeless spawn (`FUN_004AE150` type `0xD`);
- figure FSA (`FigureFSA` @ `0x4D7310`) is a generic constructor;
  type-`0xB` action after state `6` is not recovered.

Folding that travel into instant `admitResidents` is therefore
forbidden. Replacement condition: recover the type-`0xB` state
machine from spawn state `6` through the `house+0x20` write and
wire figure `#11` from the authored land-entry point
(`DAT_00C5CDFC` / `DAT_00C5CDFE`).

`FUN_004ADC90` departure assignment walks occupied houses by
`house+0x16` buckets and calls `FUN_004ADED0`. Road-adjacent-only
departure filtering is **not** a recovered house-walk predicate.

## 6. Month rollover (confirmed)

`FUN_004AC650` copies `DAT_01311FCC` → `DAT_01312604` and zeros
`DAT_01311FCC` when the 16th slice wraps.

## 7. Native implementation contract (fail-closed)

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

- Immigrant completion path after `FUN_004ADE10`
  (type-`0xB` action from state `6` to `house+0x20` write).
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
- Semantic Native mapping of assignment-eligibility `house+0x24`
  (`confirmed` read of `>0` on every `FUN_004ADA10` pass).
