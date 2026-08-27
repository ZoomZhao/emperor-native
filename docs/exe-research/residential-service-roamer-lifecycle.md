# Residential service roamer lifecycle and coverage timers

Read-only static inspection of the hash-matched original executables and
authored figure data. This note replaces the earlier Native inference that a
service walker should advance ten road tiles per Native day.

- canonical EN executable: `Emperor[EN].exe`, SHA-256
  `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
- CH cross-check executable: `Emperor[CH].exe`, SHA-256
  `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`
- static corpus: Ghidra 12.1.2 output under ignored `local/source/`
- authored source: `GameData/Model/EmperorFigureModels.txt`

Every function address cited below is `identical` between the EN and CH builds
in `local/source/compare-report.tsv`. Raw vtable words and interior entry points
were cross-checked against the EN PE disassembly because Ghidra did not emit
standalone functions for every short wrapper or threshold selector.

## 1. Exact original state

This research covers a staffed residential-service building after construction,
the periodic creation of its roaming figure, that figure's outbound road roam,
the coverage write when it crosses a road cell, its finite behavior-range
budget and return to its provider, and decay of the written house coverage.

The closed Native scope is deliberately limited to:

| Building family | Figure | Movement handler | Coverage callback |
| --- | ---: | --- | --- |
| Tax office `#125` | `#27` | generic `0x51D0C0` | `0x507F80` |
| Well `#72` | `#28` | water `0x4E3A80` | `0x51BC00` |
| Herbalist `#207` | `#30` | generic `0x51D0C0` | `0x51BD00` |
| Acupuncturist `#208` | `#31` | generic `0x51D0C0` | `0x51BD90` |
| Religion `#214…#219` | `#35` | generic `0x51D0C0` | `0x5AB580` |

Entertainment figures `#32…#34` use the separate `0x48A9A0` venue FSM,
watchtower guard `#29` uses `0x4D3B50`, and inspector `#39` uses `0x4CD230`.
They are not authorized to use this generic lifecycle.

## 2. Authored figure rows (confirmed)

`GameData/Model/EmperorFigureModels.txt` rows 27, 28, 30, 31 and 35 give
speed field 8 and behavior ranges 40, 40, 36, 36 and 50 respectively. Rows
32…34 also contain speed 8/range 36, but the executable dispatch proves that
the shared authored numbers do not imply a shared state machine.

The existing model parser identifies the speed as field index 8 and behavior
range as field index 15. The implementation consumes the parsed range; it does
not copy these ranges into a second magic-number table.

## 3. Calendar bridge and ordering (confirmed)

`0x5371A0` calls `0x4AC2B0` and then `0x4E27E0` once per original simulation
step. Therefore scheduler work for a step precedes that step's figure updates.

`0x4AC2B0` switches on `DAT_00C82EF8`, increments it through `0…50`, then
resets it to zero and calls `0x4AC650`. `0x4AC650` advances
`DAT_00C82EF0`; the monthly branch occurs after sixteen such 51-step slices.
The original month is therefore exactly `51 × 16 = 816` figure-update steps.

Native retains its 30-day compatibility clock and uses the already recovered
bridge

`floor(day × 816 / 30) − floor((day − 1) × 816 / 30)`

which produces 27/28 original steps per Native day and exactly 816 per month.
This replaces both the former one-tile/day approximation and the later
ten-tiles/day inference.

Relevant scheduler phases:

- phase `0x1F`: `0x4AC2B0 → 0x416D20`, building walk and service-provider
  virtual `+0x20`; one spawn opportunity per 51-step slice, sixteen per month;
- phase `0x23`: `0x517B40 → 0x517280`, inhabited-house ordinary coverage
  countdown walk;
- phase `0x2D`: `0x4B94A0`, visit-field aging counter;
- phase `0x30`: `0x4AE8B0`, building-byte countdown including tax coverage.

## 4. Provider creation cadence (confirmed)

### 4.1 Common service providers

The provider `+0x20` wrappers pass a fixed figure model to the common spawn
routine at vtable `+0x234 → 0x51CF90`. This routine:

1. rejects a provider with no assigned workers or a failed enabled/access gate;
2. reads the provider's worker percentage;
3. obtains a threshold through vtable `+0x230`;
4. increments provider byte `+0x36`;
5. creates a figure only when the new byte is strictly greater than the
   threshold, then resets it to zero and calls `0x4E6A70`.

The common threshold selector at interior entry `0x51CF40` is:

| Worker percentage | Threshold | Spawn opportunity interval |
| ---: | ---: | ---: |
| `>=100` | 1 | 2 slices |
| `>=75` | 3 | 4 slices |
| `>=50` | 7 | 8 slices |
| `>=25` | 15 | 16 slices |
| `1…24` | 29 | 30 slices |

This table applies to water, herbalist and acupuncture providers in the closed
scope.

### 4.2 Tax office override

Tax wrapper interior entry `0x507E30` passes figure `27` to the same
`0x51CF90` spawn routine. Its vtable `+0x230` override at `0x507E40` returns
thresholds `1/3/5/10/15` for the same five non-zero workforce bands. Tax spawn
intervals are consequently `2/4/6/11/16` service slices.

### 4.3 Religion override

`0x5AB030` accepts building IDs `0xD6…0xDB` (`214…219`) and `0x5AAE70`
constructs their three derived vtable families. Raw vtables `0x7BC0B4`,
`0x7BC318` and `0x7BC584` all retain:

- `+0x20 → 0x5AB300`, wrapper passing figure `35` to `+0x234`;
- `+0x24 → 0x51D0C0`, generic service FSM;
- `+0x28 → 0x429DF0`, radius scanner;
- `+0x2C → 0x5AB580`, religion coverage callback;
- `+0x230 → 0x5AB330`, religion workforce threshold selector;
- `+0x234 → 0x51CF90`, common spawn routine.

`0x5AB330` returns thresholds `3/6/12/24/32`; religious figures therefore
spawn every `4/7/13/25/33` service slices in the five non-zero workforce bands.

## 5. Figure dispatch, outbound budget and return (confirmed)

The per-model dispatch table begins at `0x84E784` with 40-byte rows:

- model 27 dispatches to `0x4D5D00`, which delegates to provider vtable
  `+0x24 → 0x51D0C0`;
- model 28 dispatches directly to `0x4E3A80`;
- models 30, 31 and 35 dispatch to `0x4D5D00 → 0x51D0C0`;
- models 32…34 also enter `0x4D5D00`, but their providers' `+0x24` is
  `0x48A9A0`, not `0x51D0C0`;
- model 29 dispatches to `0x4D3B50`; model 39 to `0x4CD230`.

`0x51D0C0` compares the saved traveled-budget word `+0x4C` against the
behavior-range word `+0x4A`, requests a provider route on exhaustion, and calls
`0x4E6B70` with movement code 6 while outbound and `0x4E47A0` with code 6 while
returning. `0x4E3A80` performs the same finite outbound/return split for the
water carrier, using model selector 8. `0x4E6B70` adds that code to the budget.

The word stored at figure `+0x4A` is **not** the authored range copied raw.
`0x4EB9C0` resolves the figure and calls vtable slot `+0x114`. The common
figure vtable at `0x7AFE60` maps that slot to interior entry `0x4C9310`
(between Ghidra boundaries `0x4C92D0` and `0x4C93E0`). It reads the selected
authored figure-model field and, only for selector `15`, evaluates
`value × 3 << 5`, i.e. `value × 96`, before returning. The EN and CH PE files
contain the same vtable word and instruction bytes at these addresses.
Consequently the closed outbound limits are:

| Figure | Authored range | Stored `+0x4A` budget |
| ---: | ---: | ---: |
| 27 tax | 40 | 3,840 |
| 28 water | 40 | 3,840 |
| 30 herbalist | 36 | 3,456 |
| 31 acupuncture | 36 | 3,456 |
| 35 religion | 50 | 4,800 |

For example code 6 reaches a religion limit after exactly `4,800 / 6 = 800`
outbound figure updates. Treating authored range 50 as 50 budget units would
force return after nine updates and is disproved by this accessor.

For code 6, `0x4E6B70` executes exactly one `0x4E6D80` road micro-step per
figure update. Code 8 instead branches on fractional phase byte `+0x170`:
phases 0 and 1 each execute one substep and increment the byte; phase 2
executes two substeps and resets it to zero. Water movement therefore repeats
the exact `1/1/2` cadence in both `0x4E6B70` outbound movement and
`0x4E47A0` return movement. This cadence does not alter budget accounting:
`0x4E6B70` still adds the code value 8 to `+0x4C` once per figure update.

Return movement goes through `0x4E47A0 → 0x4E7EB0`, not the outbound
`0x4E6D80 → 0x4EACD0` coverage path. Returning service figures therefore do
not refresh residential coverage.

The return route itself is now closed rather than represented as a road-only
guess. Common figure constructor `0x4C72B0` zeroes bytes `+0x80/+0x84`, and
initializer interior entry `0x4C9160` writes the creation arguments and map
coordinates without changing either byte. Thus these service figures enter
`0x4E83E0` movement mode 0. That case calls `0x5AE740`; neighbour writer
`0x5AE840` expands north/east/south/west and admits a neighbour exactly when
its **derived primary-routing-cache** word intersects `0x0B1D`. On success,
`0x4E83E0` calls `0x5B18B0` with reconstruction selector 8 and primes substep
byte `+0x41 = 20`, so the same return update consumes the first path step.
The input is the `0x5AD440`-derived cache, not the authored terrain word and
not a set of road cells. Native must derive that cache through its existing
source-backed routing-grid bridge; unavailable derivation fails closed.

The outbound-to-return boundary differs between the two handlers. Generic
`0x51D0C0` changes state 1/8 to return state 9 and destroys the old path
buffer, but still reaches its trailing `0x4E6B70(..., 6)` call on that update;
there is one final generic roaming micro-step before mode-0 route construction
on the following update. Water handler `0x4E3A80` instead changes to state 2,
destroys the old route, resets budget `+0x4C`, and returns immediately; its
mode-0 route is likewise constructed on the following update.

The normal live-provider terminal branch is also explicit. Provider vtable
slot `+0x23C` is `0x66EFA0` (returns false) and `+0x238` is `0x4FA410`
(returns true) for tax, common service, and religion provider vtables. When a
return path reports direction 8, `0x51D0C0` enters state 7 and interpolates to
the saved provider access. On completion it destroys the figure when the
provider-object identity still matches; the mismatch branch reinitializes
state 8 through `0x4E6A70`. Native construction/removal already owns the live
provider identity, so a normal completed return becomes a dormant provider
figure and the next creation still waits for its recovered spawn slice.

`0x4E6A70` initializes road substep `+0x41 = 20`, roaming marker `+0x4E = 0`,
fallback counter `+0x51 = -1`, direction increment `+0x50 = 2`, and remembers
the provider coordinates. `0x4E6D80` increments `+0x41`; when it crosses 20 it
resets the substep phase, increments crossing count `+0x4F`, invokes coverage,
chooses the next road direction, and records the new heading.

The provider exit-heading lifecycle is also closed. Base constructor chain
`0x51C9A0 → 0x426C90 → 0x426E60` zeroes 45 dwords beginning at the building
object, which includes provider byte `+0x38`; the first saved provider heading
is therefore direction 0. At spawn, `0x51CF90` creates the figure with the old
provider heading; common figure initializer interior entry `0x4C9160` writes
that fifth creation parameter directly to figure `+0x19`. The spawn routine
then writes `(old + 4) & 7` to provider `+0x38` and figure `+0x1A`.
`0x4E6A70 → 0x4E6690` selects the actual initial road direction and
writes that selected even direction back to provider `+0x38`. Thus the next
spawn begins from the prior saved selection rather than a new guessed heading.
Return-state path construction does not overwrite provider `+0x38`.

## 6. Junction selection and persisted visit fields (confirmed structure)

`0x4B9590` exposes four cardinal road candidates. Direction bytes are the even
values `0/2/4/6`; reverse is `(heading + 4) & 7`.

- one candidate: select it;
- two candidates: rotate from the current heading by saved increment 2 until a
  non-reverse valid direction is found;
- more than two candidates: read this figure model's 3-bit visit field from
  `DAT_00D62440`, discard candidates whose value is greater than the minimum,
  then seed direction with `(crossingCount + savedRandomByte[cell]) & 6` and
  rotate until valid.

The fallback state behind that last rotation is also recovered. `0x4E6A70`
initializes direction increment `+0x50 = 2` and fallback counter `+0x51 = -1`.
At an ordinary two-way crossing, `0x4E6D80` first calls `0x4E71D0` while that
counter is `-1`. Supported residential figures all have non-negative visit
selectors, so `0x4E71D0` takes its selector-backed branch: it enumerates the
four cardinal road neighbours in direction order `0/2/4/6`, chooses the
minimum 3-bit visit value, preserves the executable's RNG tie branch, chooses
increment `+2` or `-2` from the next RNG low bit, and reloads `+0x51 = 5`.
At a multi-way crossing, the random-byte/crossing-count seed is used directly
when valid; an invalid or reverse result decrements `+0x51`, calls `0x4E71D0`
when the new value is below one, then rotates by the saved signed increment.
`0x4E6690` uses the same fallback for initial exits with more than two choices,
while its initial two-choice branch rotates from the provider heading without
calling `0x4E71D0`. Native stores the signed increment, fallback counter and
deterministic RNG-call position; fixing the increment permanently clockwise is
not equivalent.

The model table's visit-field selectors are 6 for tax, 0 for water/herbalist/
acupuncture, and 5 for religion. `0x4EACD0 → 0x4B9460` saturates the current
cell's selected 3-bit field to 7 before the next junction choice. These are
shared per-selector city fields, not shortest-path distance-to-provider values.

The saved random-byte grid has one byte per 228×228 cell (`0x4B0AC0` creates
it; `0x52E7C0` persists it). Native may replace the original RNG source for
deterministic replay, but preserves one byte per cell and the original
mask/rotation selection structure. It also persists the per-selector visit
fields so save/reload does not reset junction history.

The visit fields are not permanent. Scheduler phase `0x2D` calls `0x4B94A0`.
That function increments `DAT_0101D12C`; only when the new value is greater
than 7 does it reset the counter and traverse the active map rows, decrementing
each non-zero one of the nine packed 3-bit fields by one. Since phase `0x2D`
runs sixteen times per original month, visit fields age twice per month.
Native persists the counter and applies the same saturation/floor behavior to
its sparse per-selector representation.

## 7. Coverage write and decay (confirmed)

At a road crossing `0x4EACD0` invokes provider vtable `+0x28`.
`0x429DF0 → 0x429E10` performs two nested square passes with radii 1 and 2
around the figure's current cell, in ascending `y`, then ascending `x` order.
The radius-2 pass includes the inner 3×3 square again. It reads the building
object grid at each cell and calls provider `+0x2C` only after the following
occlusion test.

`0x42A170 → 0x44E550` constructs sixteen angular sectors from these ordered
boundary-vector pairs (sector 0 through 15):

`(-4,-3)→(-3,-4)`, `(-3,-4)→(-1,-4)`,
`(-1,-4)→(1,-4)`, ` (1,-4)→(3,-4)`,
`(3,-4)→(4,-3)`, `(4,-3)→(4,-1)`, `(4,-1)→(4,1)`,
`(4,1)→(4,3)`, `(4,3)→(3,4)`, `(3,4)→(1,4)`,
`(1,4)→(-1,4)`, `(-1,4)→(-3,4)`, `(-3,4)→(-4,3)`,
`(-4,3)→(-4,1)`, `(-4,1)→(-4,-1)`,
`(-4,-1)→(-4,-3)`.

`0x44E770` uses `atan2(dy,dx)` and selects the first interval that contains
the angle, including the explicit wraparound interval. `0x42A1A0` first
requires auxiliary cell byte bit `4`; for such a cell it is opaque when its
terrain word intersects the dword at `0x817764` (raw EN and CH value `1`, the
tree bit), when it carries wall bit `0x4000`, or when its building ID passes
`0x415700`. The latter accepts exactly `89/90/91`, `104/105/106`, `231/232`;
authored
`EmperorBuildingModels.txt` identifies these as the four residential-wall and
four residential-gate levels. Their wall/gate constructors install vtables
`0x7AAAB8` / `0x7AAFB0` (shared base `0x7AAD34`); raw EN and CH words at
vtable `+0x268` are `0x4E1C40` (returns one) and at `+0x270` are `0x4153B0`.
The latter sets auxiliary bit `4` for this family, closing the prerequisite
rather than assuming every placed object owns the bit. A blocked sector
retains the nearest radius.
At radius 1, two blocked adjacent even sectors also close their intermediate
odd sector. A non-opaque building callback is suppressed only when its
Manhattan distance is greater than that sector's retained depth. These bodies,
the PE mask value, and the vector constructor are identical in EN and CH.

The callback operates on the object grid rather than on a single Native house
origin. Native therefore projects every cell in the authored 2×2 residential
footprint to the same house object before applying this scan.

Writes in the closed scope:

- water `0x51BC00`: `cHouseInfo+0x32` or `+0x34 = 0x60` according to the
  recovered well/water predicate;
- herbalist `0x51BD00`: `cHouseInfo+0x2D = 0x60`;
- acupuncture `0x51BD90`: `cHouseInfo+0x2A = 0x60`;
- religion `0x5AB580`: selects religious field index `0…3` from the provider
  building family and writes `cHouseInfo+(0x0D + index) = 0x28`;
- tax `0x507F80`: writes house-building byte `+0x52 = 0x32` and clears
  `cHouseInfo+0x3B`.

Tax `0x507F80`, water `0x51BC00`, herbalist `0x51BD00`, and acupuncture
`0x51BD90` all require the target's vtable `+0xB8` predicate and a strictly
positive population word at building `+0x20`. Native `ResidentialUnit`
contains only live house objects, so the remaining represented callback gate
is exactly `residents > 0`.

Religion has a different, completely recovered eligibility branch.
`0x5188B0` accepts target building IDs `2…17`. A vacant target is accepted only
when `0x5188D0` accepts IDs `11…17` (vacant elite housing). Provider constructor
`0x5AB0D0` stores `0x5AB080(buildingID)` at `+0x154`: ancestral `214→0`,
Daoist `215/216→1`, Buddhist `217/218→2`, Confucian `219→3`.
`0x5A7940 → 0x5A7010` initializes the corresponding provider-restriction byte
to zero for indices 0, 1 and 2, but one for index 3. Consequently a Confucian
academy callback accepts only house IDs `11…17`, while the other five
religious providers accept populated IDs `2…17` plus vacant elite IDs
`11…17`. `0x517270` supplies the exact write value `0x28`.

`0x517280`, reached at scheduler phase `0x23`, decrements ordinary service
bytes `+0x2A/+0x2B/+0x2C/+0x2D/+0x2E/+0x32/+0x33/+0x34` and religion bytes
`+0x0D…+0x10`, each independently and floor-to-zero. `0x4AE8B0`, reached at
phase `0x30`, decrements the tax building byte `+0x52`. Thus a single untouched
write remains active for 96 ordinary service-day slices, 40 religious slices,
or 50 tax slices; coverage is not reset wholesale at Native month start.

## 8. Evidence classification

### Confirmed

- authored speed/range fields and the model IDs named above;
- 51-step scheduler cycle, sixteen cycles per month, scheduler-before-figure
  ordering, and phase `0x1F/0x23/0x30` consumers;
- worker gating, strict `counter > threshold` spawning, and all three threshold
  families;
- provider vtable mappings and figure dispatch split;
- finite outbound budget, provider return path, one substep/update for code 6,
  `1/1/2` substeps for code 8, exact selector-15 `×96` scaling, and absence of
  coverage callbacks on return;
- mode-0 return routing over the derived primary cache with mask `0x0B1D`,
  N/E/S/W flood order, selector-8 route reconstruction, first-step priming,
  handler-specific transition frame, and live-provider terminal callbacks;
- provider `+0x38` zero initialization, opposite-heading spawn write, and
  selected-heading persistence;
- four-direction junction selection structure, 3-bit visit fields, selector
  IDs, eight-slice visit aging, random-byte mask, both nested radius passes,
  sixteen-sector occlusion vectors/depth rules, callback population/elite
  eligibility, religion provider indices/restriction, write constants and
  coverage decay sites;
- all cited function bodies are identical in the two hash-identified builds.

### Deterministic compatibility substitution

- Native distributes the confirmed 816 original steps over its existing
  30-day clock with an exact-sum floor bridge;
- Native derives the original saved random-byte grid from its replay seed/cell
  identity instead of the Windows RNG, preserving byte range and selection
  structure;
- Native replaces calls to the shared Windows RNG inside `0x4E71D0` with a
  persisted per-walker deterministic stream, preserving the exact call sites,
  modulo/tie branch and low-bit direction choice.

### Unknown / intentionally unsupported

- the water callback's branch between distinct `cHouseInfo+0x32` and `+0x34`
  bytes is still collapsed to Native's single `.water` requirement; both
  original branches write the confirmed value `0x60`, but their separate
  downstream house-evolution consumers require a separate contract;
- objects absent from Native's `ResidentialUnit` / `PlacedBuilding` state
  cannot participate in the recovered object-grid scan. Represented houses and
  all eight residential wall/gate IDs use the recovered predicates. Native has
  no general equivalent of auxiliary byte bit `4`, so the separate
  tree/wall-terrain branch for other original objects stays unsupported rather
  than treating every tree/wall terrain tile as an opaque object;
- entertainment `#32…#34`, watchtower `#29`, inspector `#39`, market peddler
  `#23`, and mid-flight roadblock collision/turn details require their own FSM
  contracts and must not be routed through this generic implementation.

## 9. Native implementation contract

1. Advance the recovered service subsystem by the exact number of original
   steps in each Native day, not by a guessed number of road tiles.
2. Run scheduler phases before figure updates and persist scheduler phase,
   provider spawn counter/exit heading, roamer phase/budget/substep/direction/
   crossing state, signed direction increment, fallback counter/RNG position,
   mode-0 return route, visit fields/aging counter and deterministic random-byte
   inputs. Scale authored behavior range by 96 before budget
   comparison. Never substitute a road-only shortest path when the derived
   primary routing cache is unavailable.
3. Only figures 27, 28, 30, 31 and 35 enter this recovered generic bridge.
4. Use provider-specific worker thresholds; zero workers never advance the
   provider spawn counter.
5. Apply coverage only at outbound cell crossings. Project complete house
   footprints into the object scan, preserve the two nested radius passes,
   sixteen-sector blocker depths and callback eligibility; return movement
   applies no coverage.
6. Store independent countdowns per service and remove only the service whose
   countdown reaches zero. Use write values `0x60`, `0x28`, and `0x32` exactly.
7. Preserve old-save decode by optional-backing newly serialized original
   fields and initializing missing active coverage from the confirmed write
   constants.
8. Keep every unsupported figure family fail-closed rather than borrowing this
   lifecycle because its authored speed/range happens to look similar.
