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
5. when the new byte is strictly greater than the threshold, clears the
   counter before calling `0x4EA050`; a non-zero allocator result then enters
   the provider/figure attach, parent-link, heading-copy, and
   `0x4E6A70` bootstrap tail. A zero allocator result still leaves the
   counter cleared.

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

### 4.3 Native threshold catalog parity (2026-09-02)

The threshold rows used by the existing Native generic-roam bridge are now
centralized in `OriginalResidentialServiceCatalog.residentialSpawnThreshold`.
This is a source-backed refactor, not a new provider implementation. It
preserves the strict `counter > threshold` comparison in
`FUN_0051CF90 @ 0x51CF90` and the five recovered figure families:

| Figure | Original selector | Thresholds (`100+ / 75…99 / 50…74 / 25…49 / 1…24 / 0`) |
| ---: | --- | --- |
| 27 | tax override `0x507E40` | `1 / 3 / 5 / 10 / 15 / 15` |
| 28 | Well/common service | `1 / 3 / 7 / 15 / 29 / 29` |
| 30 | Herbalist/common service | `1 / 3 / 7 / 15 / 29 / 29` |
| 31 | Acupuncture/common service | `1 / 3 / 7 / 15 / 29 / 29` |
| 35 | Religion selector `0x5AB330` | `3 / 6 / 12 / 24 / 32 / 32` |

The helper deliberately returns the selector row even for zero workers so
the caller can keep the separate source gate `worker > 0`; it does not model
the provider access callbacks, registry, figure allocation, route, or
coverage writes. Regression coverage checks all worker-band boundaries and
keeps unsupported entertainment figure `34` out of this table.

**Evidence class:** **confirmed** for the selector rows, thresholds, and
strict comparison; **unknown** for the unresolved provider gates and all
provider/figure side effects.

### 4.4 Religion override

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

The sector definitions are stored in the executable's initialized global
object, not synthesized by the Native projection. Direct EN/CH PE bytes at
`0x44E4C0` are identical (`b9 20 54 a6 00 e9 a6 bc fd ff`, SHA-256
`4e255da2033b56f7c0d736a45b60c1258807b7c5894925f39d7107cf01c633d2`). This
thunk loads `ECX = 0x00A65420` and jumps to `FUN_0042A170`; the constructor
allocates the `0x18`-byte record with the `0x10`-record count and invokes
`FUN_0044E550` with that object base. `FUN_0044E550` writes the sixteen
`(lowerAngle, upperAngle, wrapFlag)` records beginning at `0x00A65428`
(`object + 8`). Every `FUN_0044E770` call in the negative-appeal path uses
this object. The `0x00A655A0`/`0x00A655A4` arrays are separate per-source
scratch state and are cleared by the propagation drivers.

**Evidence class:** `confirmed` for the global object address, constructor
thunk, sixteen-record layout, and EN/CH byte identity. Startup ordering and
any semantic meaning of unused record bytes remain `unknown`; this does not
resolve the class-dependent occupancy predicate or the appeal-buffer-to-house
projection.

Writes in the closed scope:

- water `0x51BC00`: `cHouseInfo+0x32` or `+0x34 = 0x60` according to the
  recovered well/water predicate;
- herbalist `0x51BD00`: `cHouseInfo+0x2D = 0x60`;
- acupuncture `0x51BD90`: `cHouseInfo+0x2A = 0x60`;
- religion `0x5AB580`: selects religious field index `0…3` from the provider
  building family and writes `cHouseInfo+(0x0D + index) = 0x28`;
- tax `0x507F80`: writes house-building byte `+0x52 = 0x32` and clears
  `cHouseInfo+0x3B`.

### 7.1 The water callback writes two distinct house-info bytes (confirmed)

The two destinations in `0x51BC00` are not aliases for one Native water bit.
The `cHouseInfo` lifecycle and its direct consumers establish separate roles:

- `0x517190` (`FUN_00517190`) zero-initializes both bytes `+0x32` and `+0x34`.
- `0x517280` (`FUN_00517280`) decrements `+0x32` and `+0x34` independently,
  clamping each to zero. A visit writes `0x60`, so each untouched write has
  its own 96-slice lifetime.
- `0x589BA0` and `0x589C00` use **only `+0x32`** for the common-house water
  gate: after `0x516E90` accepts house building IDs `2…17`, `0x516ED0`
  excludes elite IDs `11…17`; for a non-elite house the predicate is
  `(+0x32 / 10) < 4` (blocked) or its inverse (satisfied). Elite IDs bypass
  this byte. These functions have no `+0x34` read.
- `0x517330` (`FUN_00517330`) derives the house service/health score byte `+0x38`:
  `+15` when `+0x34 != 0`; otherwise `+5` when `+0x32 != 0`; otherwise
  `+0`. The `+0x34` contribution therefore takes precedence over `+0x32`.
  The same function then adds the independent herbalist, acupuncture and food
  quality contributions.
- `0x5179B0` (`FUN_005179B0`) projects the pair into the service-status byte
  `building+0x39`: `0` for neither, `1` for `+0x32`, and `2` for `+0x34`;
  because the second test runs last, `+0x34` wins when both are nonzero.

The EN and CH bodies for `0x517190`, `0x517280`, `0x517330`, `0x5179B0`,
`0x589BA0` and `0x589C00` are `identical` in
`local/source/compare-report.tsv`. A corpus-wide direct-offset search found no
additional `cHouseInfo` consumers of `+0x34`; the remaining `+0x34` matches
belong to unrelated structures or figure/path records.

This closes the field roles but not the writer selection. `0x51BC00` chooses
`+0x32` only when provider vtable `+0x224` is false and the global context
returned by `0x48DF30` does **not** satisfy `0x48E110` (`active`, state
`+0x54 == 3`, subtype `+0x58 == 4`); every other branch writes `+0x34`.
The corpus does not recover the semantic name or Native-equivalent state for
the provider `+0x224` fields or the global context fields used by
`0x48E110`. Consequently Native must keep the branch unsupported rather than
route both writes through `.water` or invent a second service requirement.

### 7.1b Correction: `0x7AD878` belongs to Entertainment Area, not Well (2026-08-30)

The earlier subsection misattributed an entertainment-provider constructor to
the authored Well. The canonical EN executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
cross-check
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` both
have `FUN_0048A420 @ 0x48A420` compare active provider model `0x47`. In
`GameData/Model/EmperorBuildingModels.txt`, model row `71` is **Entertainment
Area** and row `72` is **Well**; the model IDs used by the executable match
these authored row IDs (as also shown by the market rows `59/60`).
`FUN_0048B560 @ 0x48B560` dispatches `0x47` to `FUN_0048CB10 @ 0x48CB10`,
whose PE RTTI for vtable `0x7AD878` is `cEntertainmentSquare`. Its `+0x224`
slot is `0x413A00`, and `FUN_00413A00 @ 0x413A00` returns `0`; the EN/CH
control-flow rows for `0x48A420`, `0x48B560`, `0x48CB10`, and `0x413A00` are
`identical` in `local/source/compare-report.tsv`.

This proves a constant-false `+0x224` predicate for the **Entertainment Area**
provider, not for a Well. The actual Well provider is created by
`FUN_0051BEF0 @ 0x51BEF0` for authored ID `72`, installs vtable `0x7B5EB4`,
and uses `+0x224 = 0x5B3AD0`, as documented in §7.3. The direct 23-byte
`0x5B3AD0` body is identical in EN/CH (`66 83 79 16 00 7F 0A 8A 41 6F 84 C0
77 03 33 C0 C3 B8 01 00 00 00 C3`, SHA-256
`ba0a204c6c96cd061c7b6d9e69805d8fdc767d60488ab87dc40d9d238d3607f5`).
Therefore the previous Well conclusion is withdrawn: the water callback's Well
branch remains dependent on `0x5B3AD0` (`+0x16 > 0 || +0x6F > 0`) and is not
constant-false.

No Native behavior is enabled by this correction. The pure
`OriginalWaterProviderState.houseInfoWaterByte` helper remains field-level
only; the provider/house mapping and the global-context branch remain
unknown.

### 7.1c Well provider-to-house callback chain (confirmed, 2026-08-30)

The target-house dispatch is now closed at the executable object/callback
boundary. `FUN_004EACD0 @ 0x4EACD0` resolves the figure's home object from
figure field `+0x62` through `FUN_0047F1B0`. For a normal residential service
figure (the non-`'O'` branch), it invokes that home object's vtable `+0x28`
with `(figure, 2)`. The authored Well figure is model `28` and the Well
provider family is building ID `72` (`FUN_0051BEF0 @ 0x51BEF0`); its vtable
`0x7B5EB4` maps `+0x28` to the shared wrapper `FUN_00429DF0 @ 0x429DF0`.

`FUN_00429DF0` forwards to `FUN_00429E10(figure, radius=2, provider, 0)`.
The shared scanner clears its sixteen-sector scratch arrays, scans each
square radius `1` then `2` around the figure coordinates (`+0x1C/+0x1E`) in
ascending `y`, then `x`, and reads candidate object IDs from
`DAT_00FC3750`. After the terrain/sector occlusion and retained-depth tests,
the non-null callback receiver path invokes the Well provider receiver's
vtable `+0x2C` with `(figure, candidateObject)`. For a Well that slot is
`FUN_0051BC00 @ 0x51BC00`, whose third argument is therefore the resolved
house/map object, not a provider slot or a preselected Native house index.

The callback itself then applies the global gate, candidate vtable `+0xB8`
eligibility, and positive population check before resolving the candidate's
`cHouseInfo` through vtable `+0x1E4` and writing `+0x32` or `+0x34`. This is a
confirmed provider-to-house chain: the map-object grid and the callback's
candidate object select the target before the water-field branch runs.
The EN/CH comparison rows for `0x429DF0`, `0x429E10`, `0x4EACD0`, `0x517AD0`,
and `0x51BC00` are all `identical` in `local/source/compare-report.tsv`.

This does **not** close the serialized registry mapping. `FUN_00429E10`'s
`DAT_00FC3750` candidate object, the provider's inherited `+0x2D` reference,
the serialized value's producer, and the post-load registry assignment remain
separate questions covered by §§7.3g–7.3j. Native's `houseIndices` projection is consequently a documented
compatibility projection of the confirmed radius-two object scan; it must not
be described as the original provider-slot/object-registry layout. No Native
water write is enabled by this subsection.

**Evidence class:** `confirmed` for the call order, radius, map-grid lookup,
occlusion gate, callback receiver/arguments, and Well vtable slots;
`unknown` for the provider registry object's serialized producer/post-load
assignment and the semantic meaning of the two water-field selectors.

### 7.1a House health aggregate is separate from housing appeal (confirmed, 2026-08-30)

The recovered `cHouseInfo` score path is a health/service calculation, not the
housing-appeal value that drives Native residential evolution. This conclusion
uses the canonical EN executable `8a6d2df1…6753`, CH cross-check
`dbdeca1e…15a`, and the `identical` rows for `0x517190`, `0x517280`,
`0x517330`, `0x5173E0`, `0x5179B0`, `0x518490`, `0x518D10`, `0x518D60`,
`0x590DB0`, and `0x4AC2B0` in `local/source/compare-report.tsv`. The direct EN
HouseBldg vtable address point is `0x7ABA38`: `+0x1E4` calls the
`cHouseInfo` getter at `0x416B50`, `+0x214` calls `0x518D10`, and `+0x218`
calls `0x518D60`.

The per-house formulas are closed by the following bodies (all offsets are
relative to the `cHouseInfo` pointer returned by `+0x1E4`):

| Function | Recovered operation |
| --- | --- |
| `0x517330` | Rebuilds byte `+0x38`: `+15` if water byte `+0x34` is non-zero, else `+5` if `+0x32` is non-zero; then `+30` for `+0x2D`, `+15` for `+0x2A`, and food-quality additions `+10/+20/+30/+35/+40` for buckets `1…5` from `0x545100`. |
| `0x5173E0` | Rebuilds separate goods byte `+0x37`: `+33` each for non-zero `+0x2C`, `+0x2B`, and `+0x2E`. |
| `0x518D60` | House virtual `+0x218`; refreshes `+0x38` and `+0x37` through the two functions above. |
| `0x518D10` | House virtual `+0x214`; computes `signed(+0x38) × signed population / 100`, returning `1` when both inputs are positive but integer division would yield zero. |

The scheduler establishes the cadence. In `0x4AC2B0`, phase `0x23` calls
`0x517B40`, which decrements the packed service bytes through `0x517280`
(including `+0x32`, `+0x34`, and the other service fields); phase `0x24` calls
`0x517AD0`, which iterates active, eligible buildings and invokes virtual
`+0x218` (`0x518D60`). At the month boundary, `0x4AC650` calls `0x590DB0`;
that function stores `0x518490(1)` into global `DAT_0130F978`. The aggregate
`0x518490` sums each live house's population-scaled `+0x214` result, then
applies the recovered city-population correction and clamps the result below
100. `0x590D40` moves displayed `DAT_0130F97C` toward that target by one point
per update. The advisor string in `Popularity_pctd.c` is literal
`Health %d (nat %d)`, proving the two globals are displayed as current and
natural **health**. The separate popularity producer `0x591200` builds its
effect sum from tax, wage, employment, food, debt, repression, feng-shui,
hero, and related getters; it does not read `DAT_0130F978`.

The authored manual corroborates the separation: `GameData/EmperorManual.pdf`
p.31 describes residential evolution as goods/services plus an aesthetic
requirement and directs the player to the Aesthetic Ministry for “Desirability”;
p.32 describes well water as hygiene. Therefore the recovered `+0x38` score
must not be folded into Native `ResidentialUnit.desirability` or treated as the
housing-evolution threshold. This also matches the existing Native test in
which a well's aura raises evolution desirability independently of the water
service timer.

**Implementation contract / remaining unknowns.** Native keeps the health
aggregate unimplemented and leaves `ResidentialUnit.desirability` on its
separate authored-aura path. No player-facing or simulation code may consume
`DAT_0130F978` until the Native house-health model and its disease/hygiene
consumers are recovered. Confirmed here are the byte formulas, scheduler
phases, vtable slots, population scaling, and current/natural-health display;
the semantic names of every remaining `cHouseInfo` byte, all consumers of the
city aggregate beyond `0x590DB0`, and the exact relationship to Native public
health remain **unknown**.

The confirmed per-house arithmetic is now preserved as the research-only
`OriginalHouseHealthAggregate` helper in
`Sources/EmperorCore/PublicHealthSafetySimulation.swift`. It mirrors
`FUN_00545100 @ 0x545100`'s raw-quality boundaries (`0x1D/0x31/0x45/0x59`),
`FUN_00517330 @ 0x517330`'s `+0x34`-over-`+0x32` precedence and additive
`+0x2D/+0x2A` contributions, `FUN_005173E0 @ 0x5173E0`'s three `+33` goods
terms, and `FUN_00518D10 @ 0x518D10`'s signed population scaling with a
minimum positive result of one. Focused regression coverage verifies every
bucket boundary, the source byte/short truncation semantics, and the
precedence/minimum rules. This does not wire a
Native provider or incident producer: the cHouseInfo field projection,
natural-health aggregation, and disease/crime side effects remain unknown.

### 7.1a.1 Natural-health population branch is closed as arithmetic only (confirmed, 2026-09-02)

The monthly health branch is distinct from automatic migration. In the
canonical EN source, `FUN_004AC650 @ 0x4AC650` reaches `FUN_00590DE0 @
0x590DE0` on the month boundary; that function sets `DAT_01311FA4 = 1` and
refreshes the health target. `FUN_004AD4A0 @ 0x4AD4A0` then calls `FUN_00590E00
@ 0x590E00` followed by `FUN_00590EC0 @ 0x590EC0` when that flag is set. The
EN/CH comparison row for `0x590DE0`, `0x590E00`, and `0x590EC0` is
`identical` in `local/source/compare-report.tsv`.

`FUN_00590E00` reads displayed natural health `DAT_0130F97C` (clamped to
`0…100` by `FUN_00590D40`) and computes a signed percentage of current city
population through `FUN_00408B80(population, rate)`, where integer division is
toward zero. The exact interval table is:

| natural health | rate | downstream selector |
| --- | ---: | --- |
| `<1` | 0 | no population operation |
| `1…10` | −5% | `FUN_00517E90(amount, 0)` removes lower-class residents |
| `11…20` | −3% | same lower-class removal |
| `21…30` | −2% | same lower-class removal |
| `31…40` | −1% | same lower-class removal |
| `41…50` | +1% | `FUN_004ADFB0(amount, 0)` adds to lower-class houses |
| `51…60` | +2% | same lower-class addition |
| `61…70` | +3% | same lower-class addition |
| `71…80` | +4% | same lower-class addition |
| `81…100` | +6% | same lower-class addition |

The lower-class argument is not inferred from the function name: in
`FUN_00517E90` and `FUN_004ADFB0`, `param_2 = 0` accepts houses for which
`FUN_005188D0(house+0x14)` is false. `FUN_004ADFB0` then caps each write at
model column `0x11` (population capacity) minus current residents and updates
the house remaining-capacity word. `FUN_00591970`/`FUN_005919A0` apply the
actual assigned count to `DAT_0130F988`; the requested percentage is therefore
not itself a guaranteed city-population delta when capacity or residents are
insufficient.

This arithmetic is preserved as the research-only
`OriginalNaturalHealthPopulationAdjustment.plan` helper with boundary and
toward-zero tests. It does **not** enable Qin population growth: Native has no
recovered `DAT_0130F97C`/`DAT_0130F978` projection, cHouseInfo health bytes, or
equivalent lower-class object registry. Wiring this plan into
`CitySimulation` would invent those missing mappings and remains unsupported.

**Evidence class:** `confirmed` for month call order, interval constants,
percentage scaling, lower-class selector, and EN/CH identity;
`unknown` for Native health-field projection, assignment side effects when no
eligible houses exist, and the separate automatic-migration producer.

### 7.1a.2 Lower-class population addition scan is now explicit (confirmed, 2026-09-03)

The positive natural-health selector `FUN_004ADFB0 @ 0x4ADFB0` is now captured
as an explicit-input planner. It clamps its persistent cursor with
`FUN_00445480 @ 0x445480` to `0…vectorCount−1`, increments before each lookup,
wraps from the end to vector index `1`, and performs `vectorCount` iterations
unless the request is exhausted. A successful write stores the selected index
back to `DAT_01311FA8`; skipped candidates do not move that cursor.

Each candidate must pass the global active check and the house vtable `+0xB8`,
have a positive raw `house+0x24` gate word, match the source class selector
(`param_2 == 0` selects a false class predicate, the lower-class path), and
have positive remaining capacity. The write is capped at the already-resolved
model column `0x11` capacity minus the current resident word; the planner
accepts that capacity delta explicitly and returns the exact assignment order,
applied amount, remainder, and next cursor. It does not mutate Native houses
or call the global population ledger.

The EN/CH comparison rows for `0x4ADFB0` and `0x445480` are `identical`. This
closes the source scan/capacity arithmetic while leaving the health display,
object projection, and campaign wiring unknown. The helper remains
research-only; Qin automatic population growth and migration stay fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ADFB0.c`,
`FUN_00445480.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/PublicHealthSafetySimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for cursor clamp/increment/wrap, candidate
gates, class polarity, capacity cap, write cursor update, and EN/CH parity;
**unknown** for the semantic identity of `house+0x24`, health-field producer,
and Native object/ledger projection.

### 7.1a.3 Lower-class population removal scan is now explicit (confirmed, 2026-09-03)

The negative natural-health selector `FUN_00517E90 @ 0x517E90` is now captured
as an explicit-input planner. The EN PE body contains two scan stages. Each
stage increments before lookup, wraps from the vector end to index `1`, and
walks at most `vectorCount` entries. A successful candidate must pass the
global active check and house vtable `+0xB8`, match the same class polarity as
`FUN_004ADFB0` (`param_2 == 0` means the false/lower-class predicate), and have
a positive signed resident word at `house+0x20`. Each success removes exactly
one resident, writes the selected index to `DAT_01311FAC`, decrements the
request, and updates the house status word from `FUN_0044CC80(model, 0x11)`.

The first stage repeats full scans while a write succeeds. If work remains,
the second stage clamps the persistent cursor again and repeats the same
scan shape. `FUN_004F8210` between scans only returns a context field; no
additional candidate refresh is represented by the explicit inputs, so this
second stage is preserved structurally but cannot invent a Native hook. The
planner returns the exact successful visit order, one-resident assignments,
remaining request, and next cursor without mutating Native houses or the
population ledger. The model-derived `+0x22` status write remains outside the
planner because its Native model/object projection is not recovered.

The EN/CH comparison row for `0x517E90` is `identical`. The source wrapper
`FUN_004AE120 @ 0x4AE120` calls this removal selector after the positive
selector, confirming its role in the natural-health negative branch.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00517E90.c`,
`local/source/split-merged/code/0x040000/FUN_004AE120.c`, the EN PE
disassembly at `0x517E90`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/PublicHealthSafetySimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the two-stage scan, cursor movement,
class polarity, positive-resident gate, one-resident decrement, and EN/CH
parity; **unknown** for the semantic identity of the status word at `+0x22`,
the refresh context returned by `FUN_004F8210`, and Native object/ledger
projection.

### 7.1b Disease/crime incident producer is not recovered; Native must not synthesize events (2026-08-31)

The hash-matched EN build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
CH cross-check
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` expose a
health aggregation path, but not the incident simulation currently present in
Native. The relevant EN/CH rows are `identical` in
`local/source/compare-report.tsv`:

* `FUN_00517190 @ 0x517190` initializes the `cHouseInfo` service/health bytes;
  `FUN_00517280 @ 0x517280` only decrements their packed timers.
* `FUN_00517330 @ 0x517330` rebuilds the per-house health byte `+0x38` from
  water, health-service, and raw food-quality fields; `FUN_005173E0 @ 0x5173E0`
  rebuilds the separate goods byte `+0x37`.
* `FUN_00518D60 @ 0x518D60` invokes those two rebuilders, and
  `FUN_00518D10 @ 0x518D10` returns the population-scaled health contribution.
  `FUN_005180E0 @ 0x5180E0` aggregates health statistics without mutating
  residents, inventory, treasury, or an incident queue. `FUN_00518490 @
  0x518490` computes the natural-health percentage; `FUN_00590DB0` stores it in
  the city health statistic consumed by the `Health %d (nat %d)` advisor string.

The string-led search in `local/source/split-merged/strings-index.csv` finds
only that health display string for this path; it finds no disease, theft,
outbreak, cash-loss, or resident-death event text. Direct function searches
for `FUN_005180E0`, `FUN_00518490`, `FUN_00517330`, `FUN_005173E0`, and
`FUN_00590DB0` likewise expose only health-byte/tally consumers. This is a
negative result, not proof that an indirect event table does not exist: the
incident selector, random/source state, cadence, affected-population rule,
commodity/cash side effects, event messages, and caller remain **unknown**.

The former Native `DeterministicPublicHealthSafetyState.advanceMonth` invented
a `100`-point incident threshold, food/tax/service increments, one-tenth death
loss, `25` risk reset, `2×` resident cash loss, and lexicographically selected
commodity theft. None of those operations is present in the recovered health
callers above or supported by authored event text. The Native live month path
therefore now records an empty compatibility settlement and leaves residents,
inventory, desirability, treasury, and legacy risk records unchanged until an
incident producer and its complete mapping are recovered.

**Evidence class:** **confirmed** for the health aggregation/refresh path and
the EN/CH identity; **confirmed negative** for the direct incident behavior in
the recovered callers and string table; **unknown** for any indirect/table-
driven incident producer and all player-facing consequences. The old
approximate event behavior is not a supported Qin contract.

### 7.2 Entertainment callback and venue-capacity evidence (2026-08-30)

The authored rows are explicit: `EmperorFigureModels.txt` rows `32`, `33`,
and `34` are **acrobat**, **actor**, and **Musician**, each with speed `8` and
behavior range `36`; `EmperorBuildingModels.txt` rows `211`, `212`, and `213`
are Music School, Acrobat School, and Drama School. These shared speed/range
values do not close their movement state machine.

One part of the entertainment path is now closed. `FUN_0048ad20 @ 0x48AD20`
(EN and CH `identical` in `compare-report.tsv`) is a residential callback. It
requires the target building's `+0xB8` eligibility predicate and a positive
target population, then dispatches the figure model byte as follows:

| figure model | authored role | `cHouseInfo` destination | write |
| ---: | --- | ---: | ---: |
| `0x20` (`32`) | acrobat | `+0x2B` | `0x60` |
| `0x21` (`33`) | actor | `+0x2E` | `0x60` |
| `0x22` (`34`) | musician | `+0x2C` | `0x60` |

The callback edge is also confirmed for each authored provider class. The
constructors `FUN_0048A8E0`, `FUN_0048A900`, and `FUN_0048A920` install vtables
`0x7ACEDC`, `0x7AD140`, and `0x7AD3A4` for building IDs `211`, `212`, and `213`
respectively; reading each installed table at virtual slot `+0x2C` resolves
to the same `0x48AD20` body in both hash-matched PEs. This closes the
provider-to-residential-callback dispatch, not the separate venue movement
FSM or its provider-selection side effects.

The callback's shared object scan is also the same radius-two path used by
other residential services. At each 20-substep crossing, `FUN_004EACD0 @
0x4EACD0` resolves the figure's home provider from figure `+0x62` and invokes
provider vtable `+0x28` with `(figure, 2)`. Entertainment provider vtables
`0x7ACEDC`, `0x7AD140`, and `0x7AD3A4` all point at `FUN_00429DF0 @ 0x429DF0`;
that wrapper calls `FUN_00429E10(figure, radius=2, provider, 0)`. The shared
scanner walks the figure's current coordinates (`+0x1C/+0x1E`) through rings
1 and 2 in map-object order, applies its 16-sector occlusion and retained
depth checks, then calls provider `+0x2C` with `(figure, candidateObject)`.
For all three entertainment classes that slot is `FUN_0048AD20`, so a visible
populated eligible house receives exactly the figure-specific `cHouseInfo`
`+0x2B/+0x2E/+0x2C = 0x60` write described above. `FUN_004EACD0`,
`FUN_00429DF0`, `FUN_00429E10`, and `FUN_0048AD20` are EN/CH-identical in
`local/source/compare-report.tsv`.

This closes the entertainment provider-to-house coverage callback, its
radius/timing, and its candidate-object argument. It does not close the
venue-specific provider chooser, mode-`0x12` route/collision branches, or
terminal provider settlement, so Native still must not enable figures
`32…34` in the generic road-walker bridge.

`FUN_0048b780 @ 0x48B780` checks provider slot `+0x25C` for all three model
IDs and calls `FUN_00416B60` when any is positive. The body of that callee is
outside the entertainment class in this corpus, so the invalidation/refresh
side effect is recorded but not given a Native meaning.

The venue manager is also observable but is not the walker FSM. `FUN_0048EA40`
calls `FUN_0048F140 @ 0x48F140`; that function scans the provider list and, for
building IDs `0xD3`/`0xD4`/`0xD5` (`211`/`212`/`213`), updates manager slots
`+0x2C`/`+0x34`/`+0x3C` when provider slot `+0x1BC` is positive. The update is
not a copied `+0x8` work value: the first active provider in a slot contributes
`3`, and each later active provider contributes `1` (the exact expression is
`(slot != 0 ? 1 : 3) + slot`); the three slots are then summed at `+0x40`.
`FUN_0048F420`
consumes one of those three slots (return selectors `4`, `5`, or `6`) and
updates the manager's rotating counter. This is confirmed venue-capacity and
festival-manager structure, not evidence that a figure can use the generic
`0x51D0C0` road FSM.

The movement entry cited by the model dispatch, `0x48A9A0`, is a negative
**split-corpus** result: it has no row in `functions-index.csv`, no standalone
body in `decompiled-en.c`/`decompiled-ch.c`, and no direct caller emitted by the
split tree. The nearest emitted functions (`0x48A940` thunk and `0x48AD20`
callback) do not cover that interior address. The hash-matched PE files do,
however, contain a real 896-byte body at that address; the recovered body is
recorded below. Therefore the earlier statement that all entertainment state
transitions were unknown is superseded only for the branches explicitly listed
in the PE recovery. Native still keeps figures `32…34` outside
`supportsRecoveredResidentialRoam`; adding them to the generic route would
contradict the confirmed dispatch split.

### 7.2a Direct PE recovery of the entertainment venue FSM (2026-08-30)

The canonical EN PE (`Exe/ghidra/input/EmperorEN.exe`) and the CH PE
(`Exe/ghidra/input/EmperorCH.exe`) have identical raw `.text` bytes for
`0x48A9A0…0x48AD1F` (896 bytes; SHA-256
`ef2208e8151ae4cd47703ffcefc3a9cdd77360bc6c42d0a9af5c46d51bfb76a8`). This
direct byte comparison is used because the generated Ghidra split omitted the
interior function. The body is reached through four vtable words in the EN
`.rdata` at VMA `0x7ACF00`, `0x7AD160`, `0x7AD3C0`, and `0x7ADBC0`, each storing
the entry address `0x0048A9A0`.

The following field transitions are directly visible in the instruction bytes
(figure object is the stack argument at `+0x14` and the provider is `ecx`):

- Entry calls `0x4EB9C0` with selector `8`, then provider/figure virtual slot
  `+0x114` with selector `15`; the returned word is stored at figure `+0x4A`.
  It initializes figure bytes `+0x80 = 0x12` and `+0x14 = 0`, then increments
  the figure tick byte `+0x05` with a 12-tick wrap.
- State byte `+0x40 == 5` calls `0x4E6280`, increments `+0x05`, and wraps it at
  32. State `4` calls `0x4E6470` and exits through the common tail.
- State `6` decrements word `+0x3E`; on exhaustion it requests a route through
  `0x4BA580(..., 2)`. Failure writes figure `+0x16 = 2`; success enters state
  `7`, copies provider coordinates `+0x2A/+0x2C` to figure `+0x2C/+0x2E`,
  calls `0x4E98A0`, and clears `+0x4C`.
- State `7` advances `0x4E9620(..., 1)`, then calls `0x48A340` followed by
  `0x48A520` to select a venue provider. Failure writes `+0x16 = 2`; success
  enters state `8`, copies the selected provider coordinates and word `+0xB4`,
  and clears `+0x4C`.
- State `8` increments `+0x4C` and fails at `+0x4C >= 3200`; otherwise it calls
  `0x4E47A0` with the selector-8 result from entry. State `10` compares `+0x4C`
  with the saved word, requests a return route through `0x4BA580(..., 2)`, and
  enters state `11` on success. State `11` calls `0x4E47A0` and provider/figure
  virtual slot `+0x128`; a true result writes `+0x16 = 2`.
- The common tail computes a heading/position using figure bytes `+0x19`,
  `+0x1A`, `+0x12`, and the shared `0x408170` helper. The exact route,
  collision, and provider callback meanings are not recoverable from this body
  alone.

The omitted middle states are also bounded by the same PE slice. State `9`
does not perform a provider callback: it calls `FUN_004E8A30(figure, 1)` to
clear the current route slot and then falls through to the common heading
tail. State `10` clears the active flag before testing the saved `+0x4C`; if
the return-route request fails it writes `+0x16 = 2`, while a successful request
changes the state to `11` and copies the original provider coordinates into the
figure target fields. State `11` invokes provider/figure slot `+0x128` after
`FUN_004E47A0` movement; only a true return marks the figure failed with
`+0x16 = 2`. In the common tail, state `4` derives the animation/heading helper
argument from the saved `+0x3E` countdown, capped at `7`; all other states add
the shared directional phase (`DAT_010C713C`-derived) to the per-figure tick
`+0x05`, then write the resulting map/animation word to figure `+0x08` and
return success. These branches are byte-identical in EN and CH (range
`0x48A9A0…0x48AD1F`, SHA-256
`ef2208e8151ae4cd47703ffcefc3a9cdd77360bc6c42d0a9af5c46d51bfb76a8`). They
close state-9 cleanup, the state-10 failure boundary, and the common-tail
heading inputs, but do not identify the route/collision helper semantics or
the provider slot `+0x128`'s terminal settlement.

The coverage callback's placement in the movement loop is separately confirmed
by `FUN_004E7EB0` (`identical`). For each selector-8 movement update it
increments figure `+0x41`; when the 20-substep boundary is reached it calls
`FUN_004EACD0` before recomputing heading (`0x4E8B40`) and collision (`0x4E8BC0`),
then resets `+0x41` to `0x14`. `FUN_004EACD0` resolves the figure's home object
from `+0x62`, invokes its virtual `+0x28`, and the shared `0x429DF0/0x429E10`
scan uses radius `2` before dispatching the provider's `+0x2C` callback. Thus
the `0x48AD20` writes above occur at the 20-substep crossing boundary, ahead of
that update's direction/collision result. This closes callback timing and
ordering; it does not close the venue-specific route buffer or provider
selection side effects.

This closes the existence, dispatch, state labels, route-call sites, and hard
`3200` guard of the venue FSM (`confirmed`). The venue spawn threshold and
selector-8 speed value are closed separately in §§7.2b and 7.2e. The complete
provider-selection side effects and the `0x4E47A0` collision/coverage
contract remain `unknown`. `FUN_0048A520` is separately recovered in the split
corpus; its provider-list filters and owner callback are not a license to map
the generic residential walker to figures `32…34`.

### 7.2a.1 Pure venue-FSM transition contract (confirmed, 2026-09-02)

The direct PE disassembly above is now represented by the pure
`OriginalResidentialServiceCatalog.entertainmentVenueFSMTransition` helper.
It accepts only the branch result that the executable obtains from an
unrecovered route/provider/callback call and returns ordered operation labels;
it never performs a lookup, mutates a figure, or enables figures `32…34` in
the live walker. The contract preserves the following source-visible edges:

* state `6` decrements signed word `+0x3E`, sets the active/tick/auxiliary
  bytes, requests the venue route only when the result is non-positive, and
  enters state `7` only on route success; success copies the provider-entry
  target, calls `0x4E98A0`, and clears `+0x4C`; failure writes `+0x16 = 2`;
* state `7` writes visit/mode bytes (`+0x14 = 1`, `+0x6F = 1`, `+0x80 = 1`),
  calls `0x4E9620(..., 1)` before `0x48A340`/`0x48A520`, then enters state `8`
  only after provider selection; success copies the selected coordinates/word
  and clears `+0x4C`;
* state `8` writes `+0x80 = 1`, clears the active flag, increments word
  `+0x4C` modulo 16 bits, marks failure at `>= 0xC80` (3200), and still calls
  `0x4E47A0` in that same step;
* state `9` clears the route slot; state `10` clears the active flag and
  compares `+0x4C` with the saved word. The below-saved branch continues
  through `0x4E6B70`; the reached branch requests the return route, copies the
  original provider coordinates on success, and enters state `11`. A failed
  return route marks `+0x16 = 2` but still reaches `0x4E6B70`;
* state `11` calls `0x4E47A0` and the `+0x128` terminal predicate; only a true
  callback result marks failure. States `4` and `5` retain their distinct
  heading and school-animation operations.

The helper and focused tests are in
`Sources/EmperorCore/HousingEvolution.swift` and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`. This is **confirmed** for
state values, operation order, `+0x3E`/`+0x4C` arithmetic, the `3200` guard,
and failure ordering from the EN/CH-identical PE slice
`0x48A9A0…0x48AD1F` (SHA-256
`ef2208e8151ae4cd47703ffcefc3a9cdd77360bc6c42d0a9af5c46d51bfb76a8`). It
remains **unknown** which map-loaded objects populate the provider registry,
what route/collision results mean, and how provider/house settlement is
committed; those inputs remain explicit and Native stays fail-closed.

### 7.2b Entertainment provider spawn thresholds (2026-08-30)

The entertainment provider constructors identify the threshold methods without
requiring the omitted walker body. `FUN_0048A8E0` (building `211`, Music School)
installs vtable `0x7ACEDC`; `FUN_0048A900` (building `212`, Acrobat School)
installs `0x7AD140`; and `FUN_0048A920` (building `213`, Drama School) installs
`0x7AD3A4`. Their vtable `+0x230` entries are respectively `0x5AB330`,
`0x5AB330`, and `0x48B380`. The common provider spawn routine
`0x51CF90` calls this slot and creates a figure only when its incremented byte
is **strictly greater** than the returned threshold.

Direct EN/CH PE bytes are identical for both threshold methods. The returned
thresholds by worker percentage are:

| provider building | threshold method | worker percentage | threshold | spawn opportunity interval |
| ---: | --- | ---: | ---: | ---: |
| 211 Music School | `0x5AB330` | `100+` / `75…99` / `50…74` / `25…49` / `1…24` / `0` | 3 / 6 / 12 / 24 / 32 / 64 | 4 / 7 / 13 / 25 / 33 / 65 slices |
| 212 Acrobat School | `0x5AB330` | same | 3 / 6 / 12 / 24 / 32 / 64 | 4 / 7 / 13 / 25 / 33 / 65 slices |
| 213 Drama School | `0x48B380` | `100+` / `75…99` / `50…74` / `25…49` / `1…24` / `0` | 6 / 12 / 24 / 32 / 48 / 96 | 7 / 13 / 25 / 33 / 49 / 97 slices |

The zero-workforce rows are included because the methods return 64 or 96 when
the input is zero; the common spawn gate separately rejects providers with no
assigned workers. Thus the zero rows are not reachable in normal spawning but
are part of the recovered method domain. These thresholds and strict intervals
are `confirmed`; the method's semantic name and the rest of the entertainment
FSM remain `unknown`. Native must not enable figures `32…34` until their
provider selection, route/collision, coverage callback timing, and terminal
side effects are independently represented.

### 7.2c Venue-provider selection filters (2026-08-30)

`FUN_0048A520 @ 0x48A520` is present in the split corpus and is called by the
recovered venue FSM after its path advance. It accepts only figure model bytes
`0x20…0x22` (32…34). It then scans the live provider list and keeps a provider
only when all of these conditions pass:

- global `FUN_00426D10(0)` gate is nonzero;
- provider vtable `+0x264` accepts the requested figure model;
- provider vtable `+0x78` accepts the provider in the current state;
- provider vtable `+0x1B4` returns a strictly positive work value; and
- provider vtable `+0x25C` returns capacity `n` within the current bucket.

The bucket starts at `0x20` and increases by `0x20` through values below
`0x60`; a candidate is kept when `n <= bucket / 4`. For each kept candidate,
the function records provider word `+0xB4`, the vtable `+0x1A4` result, and
`n × 2` in temporary arrays. If any candidate remains, the current figure's
vtable `+0xF0` is invoked and `FUN_004E7FD0` then consumes the forwarded candidate
arrays through the route-mode helpers and resolves a provider object.

The selector range, all five filters, bucket arithmetic, temporary-array
fields, and owner-resolution call are `confirmed` from `FUN_0048A520` and its
EN/CH-identical compare row. The semantic names of the provider virtual slots,
the route-specific selection policy, and the resulting route/collision side
effects remain `unknown`; Native must not replace this selection with
nearest-building or sheet-order heuristics.

### 7.2c.1 Venue capacity-byte lifecycle (2026-08-30)

The provider capacity getter and its storage are now bounded, but their full
simulation lifecycle is not. In all three entertainment provider vtables,
`+0x1E8` resolves to `0x416B50`, which returns the provider record at
`provider + 0xC8`. `+0x25C` (`0x48A950`) maps the requested figure model to a
single byte in that record: model `32` reads `+0x5D`, model `33` reads `+0x5F`,
and model `34` reads `+0x5E`; an unknown model returns the constant `32`.
`FUN_0048ADC0` clears record words `+0x4E…+0x54` and all three bytes
`+0x5D…+0x5F`. `0x48ADC0` and `0x48AE30` are EN/CH `identical` in
`compare-report.tsv`; the direct EN/CH bytes for the omitted `0x48A950` body
also match (SHA-256 `bf5624c21db2d3d1b2a4a39f3d32630f19c09d40b3c0111e551df218431b8aee`).
The emitted callers of `FUN_0048B6D0` are provider update/accessor paths
(`0x48C270` and `0x48D6D0`), not the three vtable constructors themselves.

`FUN_0048AE30` is the only recovered entertainment-provider body that
decrements all three bytes as a group: it decrements each non-zero byte once,
counts how many were non-zero,
stores that count at record `+0x5C`, and calls `FUN_0051CCA0`. The split corpus
contains no direct C caller for `0x48AE30`; the indirect scheduler dispatch is
now recovered in §7.2c.4b. `FUN_0048B780` reads
the three model bytes and, when any is positive, calls `FUN_00416B60`; that
callee only redispatches the current object's `+0x1B4` slot, so the refresh or
invalidation meaning is still unknown.

These facts establish the storage shape, the periodic decay dispatch (closed
in §7.2c.4b), and one decay primitive, but not the provider/route lifecycle
that makes a musician, actor, or acrobat opportunity available to
`FUN_0048A520`. The positive state-8 writer is now documented in §7.2c.5;
the preceding state-7 selection and its route/collision conditions remain
unknown. Native therefore keeps
figures `32…34` fail-closed; synthesizing counters from worker percentage,
house population, or manager slots would be an unsupported rule.

Native now records the closed byte-level contract in
`OriginalResidentialServiceCatalog.EntertainmentVenueCapacityState`: model
`32/33/34` select `+0x5D/+0x5F/+0x5E`, unknown model IDs preserve the original
constant `32` getter result, and `decayOnce()` decrements each positive byte
once while returning the pre-decrement non-zero count (the value written to
`+0x5C`). This is a pure research helper only; the scheduler, positive writer,
provider refresh, route/collision, and figure coverage are not wired into
Native, so the Qin venue figures remain disabled in gameplay.

### 7.2c.2 `+0xF0` is an index/cache hook; candidate arrays are forwarded (2026-08-30)

The apparent owner-selection call in `FUN_0048A520` has now been checked
against the actual common figure vtable. `FUN_004C71D0 @ 0x4C71D0` installs
vtable `0x7AFE60`, whose `+0xF0` entry is `FUN_004C75A0 @ 0x4C75A0` in both
hash-identified builds. The direct EN/CH body bytes for `0x4C75A0…0x4C75BA`
are identical (SHA-256
`21ceaee2cc1b9c6c4a5347ae1c021c0c11ec10f3f3d60d2bd9d8fad72d83c13f`) and do
only this:

```text
if figure +0x0C == -1:
    figure +0x0C = FUN_004E1380(figure)
return figure +0x0C
```

`FUN_004E1380 @ 0x4E1380` scans the global figure list and returns its
1-based index (or zero when absent); its EN/CH body is also identical (the
`0x4E1380` compare row). `FUN_004C75A0` has a plain `ret`, not `ret N`, and
does not read the three explicit stack arguments pushed by `FUN_0048A520`.
Those arguments therefore remain on the caller's stack. The following
`push returnedIndex; call FUN_004E7FD0` turns the call into the effective
four-argument sequence:

```text
FUN_004E7FD0(figureIndex,
             &DAT_00D5A6FC,       // candidate provider IDs
             DAT_00D56878,        // candidate count
             &DAT_00D5687C)       // candidate n*2 values
```

This is confirmed by the call-site disassembly at `0x48A65F…0x48A674` and by
the cdecl signature of `FUN_004E7FD0`. Its mode-0/0x14 branches pass the
candidate-ID array and count to `FUN_005AE970`; its mode-0x12 branch passes
the same array/count to `FUN_005B04A0` when the fourth argument is zero, or
uses the fourth array in the alternate `FUN_005B0620` path. The EN/CH bodies
of `FUN_005AE970 @ 0x5AE970` and `FUN_005B04A0 @ 0x5B04A0` are identical (the
corresponding compare rows); neither treats `+0xF0` as a score/tie callback.

Therefore the previous wording “owner `+0xF0` chooses among candidates” is
superseded. Confirmed facts are now: `+0xF0` returns the current figure-list
index, stack arguments are intentionally forwarded to `0x4E7FD0`, and the
route helpers consume the candidate list. The exact route-mode choice,
round-robin/occupancy update policy inside `0x5AE970`/`0x5B04A0`, use of the
`n×2` side array in alternate modes, and resulting provider/figure side
effects remain `unknown`; Native must keep figures `32…34` fail-closed.

### 7.2c.3 Entertainment candidate target resolves to provider coordinates (2026-09-01)

The `+0x1A4` value stored by `FUN_0048A520` is now tied to the provider's
map coordinates. In the canonical EN build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
build `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`,
the vtable words at `0x7ACEDC + 0x1A4`, `0x7AD140 + 0x1A4`, and
`0x7AD3A4 + 0x1A4` all point to `FUN_004273F0 @ 0x4273F0`. These are the
Music School, Acrobat School, and Drama School provider vtables installed by
`FUN_0048A8E0`, `FUN_0048A900`, and `FUN_0048A920`; the `0x4273F0` row is
EN/CH-identical in `local/source/compare-report.tsv`. Its body is:

```text
return DAT_0101D0C8 + object[+0x2A] + object[+0x2C] * 0xE4
```

Because `FUN_0048A520` writes this return into `DAT_00D5A6FC`, each candidate
target is the provider object's absolute map-cell index, not an opaque score.
`OriginalResidentialServiceCatalog.entertainmentProviderSelectionPoint`
exposes the inverse conversion with an explicit map base.

**Classification:** vtable-slot dispatch, provider coordinate fields, absolute
linear-index formula, and handoff into the candidate array are **confirmed**.
Provider registry loading, object occupancy, route reconstruction, and final
coverage/settlement effects remain **unknown**, so the venue FSM remains
fail-closed.

### 7.2c.4 Capacity-byte writer search separates house/object fields from venue records (2026-09-01)

The repository-wide split-corpus search for writes to offsets `+0x5D`,
`+0x5E`, and `+0x5F` finds two generic object-field paths that must not be
mistaken for the entertainment provider record returned by vtable `+0x1E8`:

- `FUN_005447F0 @ 0x5447F0` writes its receiver's own `+0x5D` and is present as
  a vtable entry at `0x7B7070`. It then calls `FUN_0042BBD0 @ 0x42BBD0`.
- `FUN_0042BBD0` iterates map-cell objects and writes each resolved object's
  own `+0x5D = param_2`; its receiver is a map/building object, not the
  provider-capacity record at `provider + 0xC8`.

`local/source/split-merged/code/0x040000/FUN_0042bbd0.c` has the only emitted
caller of `FUN_0042BBD0`, namely `FUN_005447F0`; both functions are EN/CH
`identical` in `local/source/compare-report.tsv`. The entertainment decay
body `FUN_0048AE30 @ 0x48AE30` has no emitted direct caller in the split tree,
and no split-corpus writer passes the `FUN_0048AE30` provider record from
`+0x1E8` into a positive increment. This is a negative static result, not
proof that no indirect vtable or scheduler edge exists in the executable.

As a direct PE cross-check, a little-endian scan of both hash-matched inputs
for the absolute pointer `0x0048AE30` finds exactly seven occurrences in each
file, at `.rdata` file offsets
`0x3ACF78`, `0x3AD1DC`, `0x3AD440`, `0x3AD6A4`, `0x3AD914`, `0x3ADC40`, and
`0x3ADEA4`; none is in the `.text` section. These are vtable entries for the
entertainment/provider class family, so they confirm indirect dispatch slots,
not a call-site or an increment producer. The same scan finds four `.rdata`
entries for `0x0048ADC0` (the resetter) and seven for `0x0048A950` (the getter),
matching their vtable roles. This direct scan narrows the negative result but
does not rule out a scheduler invoking the slots indirectly at runtime.

Consequently, the known generic `+0x5D` writers cannot supply the
music/acrobat/drama capacity increments. The direct positive writer reached
by the venue FSM is documented in §7.2c.5; the scheduler edge that invokes the
decay routine is documented in §7.2c.4b, while the provider-registration
projection remains **unknown**.
Native keeps the venue FSM and figures `32…34` fail-closed.

**Evidence class:** **confirmed negative** for the emitted direct-call and
receiver-field distinctions above; **confirmed** for the indirect scheduler
dispatch documented in §7.2c.4b; **unknown** for the registry lifecycle.

### 7.2c.4a Initialization-only `+0x26C` dispatch does not close decay cadence (2026-09-02)

The remaining `+0x26C` edge was checked against its only emitted caller in the
startup path. `FUN_0048A6B0 @ 0x48A6B0` walks the active object vector and, after
`FUN_0042B6C0 @ 0x42B6C0` returns true, invokes the object's virtual `+0x26C`
slot. `FUN_0042B6C0` is an exact equality predicate: only authored model
`0x47` (decimal `71`, Entertainment Area) is admitted. `FUN_00406A20 @
0x406A20` calls `FUN_0048A6B0` in both its map/editor initialization branches,
after map/cache setup and before the remaining startup tail. The EN/CH rows for
all three functions are `identical` in `local/source/compare-report.tsv`.

This proves an initialization-time virtual dispatch site for an Entertainment
Area object's `+0x26C` implementation, but it does not identify that slot as
`FUN_0048AE30` at the call site and does not provide a monthly/phase scheduler
edge by itself. The periodic `+0x9C` dispatch is separately recovered in
§7.2c.4b. The absolute-pointer scan in §7.2c.4 still only proves that
`0x48AE30` appears in seven entertainment/provider vtable slices. Therefore
the startup refresh and the periodic opportunity-byte decay must remain
separate evidence classes: both the startup `+0x26C` edge and the periodic
school `+0x9C` edge are **confirmed**; the increment producer and any
Theatre Pavilion `+0x9C` mapping remain **unknown**.
Native keeps `EntertainmentVenueCapacityState.decayOnce()` as a pure byte-level
research primitive and does not call it from initialization or the Qin runtime.

### 7.2c.4b Periodic phase `0x21` dispatch closes school opportunity-byte decay cadence (2026-09-02)

The canonical English executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
Chinese comparison executable
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` have
`identical` rows for `FUN_004AC2B0`, `FUN_004AF230`, `FUN_0048AE30`, and the
three school constructors in `local/source/compare-report.tsv`.

`FUN_004AC2B0 @ 0x4AC2B0` switches on the global scheduler phase. At phase
`0x21` it calls `FUN_004AF230 @ 0x4AF230`, then advances the phase; when the
phase reaches `0x32`, it wraps to zero and calls `FUN_004AC650`. Whenever the
normal phase counter advances through its full range, the dispatch site
therefore recurs once per `0x33`-phase scheduler cycle. `FUN_004AF230`
resets the provider-statistics tables, walks the active object vector from
`FUN_00413B40(1)` to `FUN_004F8200()`, and invokes each object's virtual
`+0x9C` slot only when the object state byte at decompiler index `[1]` is
`1` or `3`.

The school constructors establish the relevant vtable starts:
`FUN_0048A8E0` (Music School, model `211`) uses `0x007ACEDC`,
`FUN_0048A900` (Acrobat School, model `212`) uses `0x007AD140`, and
`FUN_0048A920` (Drama School, model `213`) uses `0x007AD3A4`. A direct
little-endian PE scan finds `0x0048AE30` at `.rdata` virtual addresses
`0x007ACF78`, `0x007AD1DC`, and `0x007AD440`; each is exactly
`0x9C` bytes after its corresponding vtable start. Therefore those three
school `+0x9C` entries resolve to `FUN_0048AE30`, whose body decrements
record bytes `+0x5D`, `+0x5E`, and `+0x5F` once when non-zero, writes the
pre-decrement non-zero count to `+0x5C`, and calls `FUN_0051CCA0`.

`FUN_004AF230` also appears at the beginning of `FUN_00534BF0` map/cache
initialization and in `FUN_004B1250` construction/terrain processing. Those
additional callers do not change the recovered phase-`0x21` cadence; they
show that the same pass is reused outside the regular scheduler. The
polymorphic `+0x9C` slot is shared by other provider families (for example,
the Well/Herbalist/Acupuncture thunk documented in §7.3v), so that slot alone
does not prove a provider-registration projection.

This closes the periodic dispatch and all-three-byte decay cadence for the
three school vtables as **confirmed** static behavior. It does not establish
the runtime phase-to-calendar interpretation, the positive opportunity-byte
writer (closed separately in §7.2c.5), the Theatre Pavilion `+0x9C` target,
or the provider registry, route/collision, and terminal-settlement lifecycle.
Native therefore records only the constants and active-state predicate in
`OriginalResidentialServiceCatalog`; `decayOnce()` remains a pure helper and
figures `32…34` remain fail-closed.

**Evidence class:** **confirmed** for phase `0x21`, cycle length `0x33`,
active-state filter `1/3`, school vtable `+0x9C` pointer arithmetic, and the
decay body; **unknown** for calendar mapping, Theatre Pavilion dispatch,
registry projection, route/collision, and settlement.

### 7.2c.4c Common figure cleanup decrements the provider record `+0x5C` (2026-09-02)

The common figure cleanup body is present in both hash-identified executables
as `FUN_004C8B70 @ 0x4C8B70`; `local/source/compare-report.tsv` marks the EN/CH
row `identical`. The direct constructor `FUN_004C71D0 @ 0x4C71D0` installs
vtable `0x007AFE60`. A little-endian scan of the canonical English PE and the
Chinese comparison PE finds `0x004C8B70` at vtable-relative offset `+0x158`
(`0x007AFFB8` in the canonical table), so this is a concrete common
figure virtual edge rather than a name-based association. The constructor is
used by the emitted figure allocation helpers (`FUN_004E1100`,
`FUN_004E12C0`, `FUN_004E1420`, and `FUN_004E44E0`); the exact caller that
assigns authored models `32…34` remains indirect.

Inside `FUN_004C8B70`, the switch on figure byte `+0x12` has a direct
`0x20/0x21/0x22/0x23` branch. For the first three values (authored
`EmperorFigureModels.txt` rows 32 `acrobat`, 33 `actor`, and 34 `Musician`),
the callback resolves the linked object from figure `+0x62`, calls that
object's virtual `+0x1E8`, reads record byte `+0x5C`, and decrements it by one
only when it is non-zero. It then falls through the shared cleanup sequence
(`FUN_004E8A30`, `FUN_004EA610`, `FUN_004EBAC0`, and `FUN_004EBB40`). The same
switch also contains model `35` and `40…42` cases; those shared cases are not
promoted to entertainment semantics here.

This closes one raw exit-side transition: for figure models `32…34`, a
positive provider-record byte at `+0x5C` becomes `count−1`, while zero stays
zero. It does **not** identify the field's business meaning, prove which
runtime event dispatches the virtual slot, register a provider, or settle a
house service. The exact figure-dispatch caller and provider registry/route
lifecycle therefore remain **unknown**. Native records the offset and
side-effect-free count helper only; it does not enable venue figures or call
this callback from gameplay.

**Evidence class:** **confirmed** for the EN/CH-identical function body, the
common-vtable `+0x158` edge, figure-model switch, linked-object `+0x1E8`
lookup, non-zero guard, decrement, and common cleanup calls; **unknown** for
the caller/event ordering, record-field semantics, provider registration,
route/collision, and settlement.

### 7.2c.5 Venue performance callback writes the opportunity byte (2026-09-02)

The state-8 heading-8 callback is now closed at the provider vtable boundary.
In the canonical EN build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
CH build
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, the
body at `0x48B710…0x48B7BF` is byte-identical (176 bytes; SHA-256
`73fc6bb9f64681477ee633ed58c7e6b1f3b03f17f6add6b5355eb595800d0ab9`). The
state-8 path in `0x48A9A0` resolves the selected provider object, accepts it
only when `FUN_0048B540(model)` is true (`model == 0x47` or `0x4B`, authored
building IDs `71` Entertainment Area or `75` Theatre Pavilion), and then
dispatches that provider's vtable `+0x260` with the current figure model byte.

The two provider vtables are independently identified by RTTI and their
constructors:

| authored provider | constructor / vtable | `+0x260` target |
| --- | --- | --- |
| 75 Theatre Pavilion (`cEntertainmentVenue`) | `FUN_0048BBA0` → `0x7AD608` | `0x48B710` |
| 71 Entertainment Area (`cEntertainmentSquare`) | `FUN_0048CB10` → `0x7AD878` | `0x48B710` |

`0x48B710` obtains the provider record through vtable `+0x1E8` (the record
returned by `FUN_00416B50`) and applies this exact model dispatch:

- figure model `32` writes byte `record + 0x5D = 0x20`;
- figure model `33` writes byte `record + 0x5F = 0x20`, increments byte
  `record + 0x64`, and clears that counter when the increment reaches `5`;
- figure model `34` writes byte `record + 0x5E = 0x20`;
- any other model returns without a write.

The callback returns `void`; the preceding `FUN_0048B540` guard is the only
model/provider filter in this branch. `GameData/Model/EmperorBuildingModels.txt`
confirms IDs `71` and `75` as Entertainment Area and Theatre Pavilion, while
the provider-capacity getter `0x48A950` maps models `32/33/34` to record bytes
`+0x5D/+0x5F/+0x5E` respectively. Therefore the previously missing positive
writer for those three opportunity bytes is no longer unknown: a venue figure
that reaches this callback refreshes its corresponding opportunity byte to
`32` slices, with the model-33 auxiliary counter side effect above.

This does **not** close the route/collision precondition that produces heading
`8`, the provider registry/object projection, or the callback's surrounding
terminal/coverage settlement. The periodic scheduler edge that invokes the
shared decay routine `0x48AE30` is documented in §7.2c.4b; its remaining
registry and runtime wiring boundaries are still open. The Native venue FSM and
figures `32…34` therefore remain fail-closed; the newly closed callback is
recorded only as a pure research contract.

**Evidence class:** callback write, model mapping, vtable targets, EN/CH
identity, and the periodic decay dispatch are **confirmed**. The semantic
meaning of `record +0x64`, the heading-8 route condition, Theatre Pavilion's
`+0x9C` target, and the provider registry lifecycle remain **unknown**.

### 7.2c.6 Entertainment callback house-byte contract (2026-09-02)

The earlier residential callback trace can now be consumed as a side-effect-
free contract by
`OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite`. The
helper preserves the callback's two entry gates: the candidate building must satisfy its `+0xB8` eligibility
predicate and its population must be strictly positive. A failed gate returns
no write. For an eligible populated target, figure models `32`, `33`, and
`34` write `0x60` to `cHouseInfo` bytes `+0x2B`, `+0x2E`, and `+0x2C`
respectively; unknown models take the callback's no-op default branch.

This is the exact field/value boundary recovered from `FUN_0048AD20`; it does
not project a provider registry entry, interpret the house bytes' later
consumers, or enable live venue figures. Route, collision, registry, and
settlement remain unknown as stated in §§7.2c.5 and 7.2d.

**Evidence class:** gate conditions, model-to-byte mapping, and write value are
**confirmed**; the semantic labels and downstream countdown/level effects are
**unknown**.

### 7.2d Venue return terminal callback (2026-08-30)

The state-11 call in `0x48A9A0` is not an unresolved arbitrary virtual call.
Entertainment figures are allocated by the common figure constructor
`FUN_004C71D0`, which installs the EN/CH-identical vtable at `0x7AFE60`.
Reading that vtable at `+0x128` gives the interior entry `0x4C9950` in both
PEs. The split corpus has no standalone row for this short method, so its
24-byte body was checked directly in both hash-matched PEs
(`0x4C9950…0x4C9967`, identical SHA-256
`7224f1286516b9432398f315836dfa4ebffba25810555d56add1afa436e4300f`).

The method is a pure predicate on the figure receiver: it returns `1` only
when figure byte `+0x19` is `8`, `9`, or `10`; all other values return `0`.
The venue FSM invokes it after `0x4E47A0` in state `11`; a true result then
writes figure failure byte `+0x16 = 2`. No provider lookup, coverage write,
or coordinate mutation occurs inside `0x4C9950` itself.

This closes the terminal callback's exact branch and return domain
(`confirmed`). It does **not** identify the route result represented by
figure byte `+0x19` or the provider/coverage side effects of the preceding
`0x4E47A0` call; those remain `unknown`, and Native continues to exclude
figures `32…34` from the generic roam bridge.

Native records this closed predicate as the pure
`OriginalResidentialServiceCatalog.entertainmentVenueTerminalFailure` helper.
It is intentionally not called by the live walker: the preceding collision
and provider-settlement effects remain unresolved.

### 7.2e Figure selector-8 speed value (2026-08-30)

The word returned by `0x4EB9C0(figure, selector)` is now tied to the authored
figure table rather than left as an opaque selector result. The common figure
vtable at `0x7AFE60` maps `+0x114` to interior entry `0x4C9310`; direct EN/CH
PE bytes for `0x4C9310…0x4C9330` are identical (33 bytes; SHA-256
`804abebbaa4a0361a61256f7841f1f57b5d823072dbc0def6f4285956901fc13`). The
method indexes `DAT_00A5F60C` at `figureType × 18 + selector`. The 18-column
layout is established by the figure-model loader (`ALL FIGURES` rows in
`EmperorFigureModels.txt` and `FUN_005D1E20`): field index `8` is authored
speed and field index `15` is behavior range. For selector `15`, the method
applies `value × 3 << 5` (`value × 96`); all other selectors are returned raw.

Therefore the venue FSM's entry call with selector `8` returns the authored
speed value, which is `8` for figure rows `32`, `33`, and `34`; the peddler
row `23` likewise returns speed `8`. The same call with selector `15` returns
the previously recovered budgets `36 × 96 = 3,456` for venue figures and
`60 × 96 = 5,760` for the peddler. The selector-8 movement code and selector-
15 budget scaling are `confirmed`; the remaining route/collision and provider
side effects are independent unknowns.

### 7.2f Venue mode-`0x12` route and collision gates (2026-08-30)

The venue FSM's `+0x80 = 0x12` mode has a distinct, source-visible path setup;
it is not the mode-0 residential flood. `FUN_004E83E0` (`identical` EN/CH)
dispatches mode `0x12` to `FUN_005B00D0(..., 0)`. That routine seeds the
per-tile search at the current figure cell, expands the four cardinal
neighbours through `FUN_005B0220`, and admits a neighbour only when its
derived terrain/routing word intersects mask `0x10C`. The search queue and
depth array are the shared `DAT_013C4C20` / `DAT_01391FE0` structures.

The four source operands in `FUN_005B0220` are offset views of one primary
`UInt16` cache, not a second untracked cache: north reads
`DAT_013787F8` (`DAT_013789C0 - 0x1C8`), west reads `DAT_013789BE`
(`-2`), the current cell reads `DAT_013789C0`, east reads `DAT_013789C2`
(`+2`), and south reads `DAT_01378B88` (`+0x1C8`). This is the same
per-cell primary routing domain already reconstructed from `FUN_005AD440`;
only the mode-specific admission mask changes to `0x010C`.

When the mode-`0x12` flood reaches the destination,
`FUN_004E83E0` first asks `FUN_005B18B0` with reconstruction selector `4`.
That selector scans the eight-direction table with stride `2` (cardinal
directions only); if it returns no route, the function retries selector `8`,
which scans the full eight-direction table. A successful reconstruction writes
the direction sequence to the figure's route buffer and primes the same
`+0x42/+0x44/+0x46` path counters used by the generic movement loop.

The matching collision reader `FUN_004E8BC0` (`identical` EN/CH) makes the
mode-specific hard guard explicit: after its normal tile/object checks, any
candidate tile whose terrain word contains bit `0x100` forces figure heading
byte `+0x19 = 9`. This is the blocked/turn result consumed by the venue FSM;
the method does not write residential coverage or select a provider.

The masks (`0x10C` for venue flood admission and `0x100` for the terminal
collision guard), cardinal-first reconstruction order, full-eight fallback,
and state-byte write are `confirmed` from `FUN_004E83E0`, `FUN_005B00D0`,
`FUN_005B0220`, `FUN_005B18B0`, and `FUN_004E8BC0`. The meanings of the other
terrain bits and object callbacks inside `FUN_004E8BC0` are still `unknown`;
this narrows but does not yet authorize a Native entertainment walker
implementation.

### 7.2g Venue mode-`0x12` route primitive in Native (2026-08-30)

The recovered mode-`0x12` flood/reconstruction contract is now represented as
the side-effect-free `OriginalGrandCanalLayoutCatalog.entertainmentVenueRoute`
helper in `Sources/EmperorCore/GrandCanalSimulation.swift`. It consumes the
existing source-backed primary routing cache, admits only values intersecting
`0x010C`, performs the same cardinal flood, and preserves the
`FUN_005B18B0(selector 4)` cardinal reconstruction before the full-eight
fallback. `GrandCanalSimulationTests.testEntertainmentVenueRouteUsesRecoveredMode12PrimaryMask`
asserts the exact accepted/rejected mask domain and route order independently
of the entertainment FSM.

This is an implementation of the recovered route primitive only. It does not
choose a provider, construct the venue-specific state machine, interpret the
remaining object/collision callbacks, or issue coverage. Figures `32…34`
therefore remain outside `supportsRecoveredResidentialRoam` until those
downstream contracts are recovered.

### 7.2g.1 Weighted provider route uses mode-1 mask (2026-08-30)

The weighted provider-selection path uses a different expansion mask from the
unweighted venue route above. In `FUN_004E7FD0 @ 0x4E7FD0`, the `+0x80 == 0x12`
branch passes the non-null `+0x08` weight array to `FUN_005B0620`; the direct
EN/CH call-site bytes push literal `1` as that routine's final mode argument.
`FUN_005B0620` dispatches a non-zero mode to `FUN_005B0360`, whose four
neighbor writes admit primary-cache values intersecting `0x0B0C` (not
`0x010C`). Cardinal flood and the existing selector-4 then selector-8 route
reconstruction remain the same. Native now exposes this distinction as
`OriginalGrandCanalLayoutCatalog.entertainmentVenueProviderRoute`; the earlier
`entertainmentVenueRoute` remains the `FUN_005B00D0`/`0x010C` fallback.

This closes the provider-route expansion mask and mode dispatch
(`confirmed`). Candidate weighting/tie behavior, object occupancy effects,
and provider settlement remain **unknown**, so this helper is not wired into
live venue figures and does not enable Qin entertainment production.

### 7.2h Venue route-coordinate and fixed-point arrival contract (2026-08-30)

The route hand-off made by the venue FSM has a closed coordinate contract.
`FUN_004E98A0 @ 0x4E98A0` is `identical` for EN/CH in
`local/source/compare-report.tsv`. It stores the target map coordinates at
figure offsets `+0x56/+0x58`, computes absolute residuals to the current
fixed-point position in `+0x5A/+0x5C`, and stores the signed diagonal residual
`+0x5E` as `2*minResidual - maxResidual` (zero when the two residuals are
equal). With its final argument nonzero it takes the shared heading helper
`0x5B2790`; with zero it uses `0x5B2730` and then applies the explicit
two-to-one corrections that change headings `1/3/5/7` when one axis is more
than twice the other. It sets movement-axis byte `+0x60` to `1` when the
vertical residual is no greater than the horizontal residual, otherwise `2`.

`FUN_004E9620 @ 0x4E9620` and its helpers are likewise EN/CH `identical`.
For each supplied substep it decrements countdown byte `+0x24` (clamped at
zero), returns arrival when `+0x5A + +0x5C < 1`, and otherwise calls
`0x4E9730` to update the signed diagonal residual. Axis movement then follows
`+0x60`: mode `2` invokes `0x4E9BF0` (move integer-y one step toward target),
decrements the `+0x5A` residual when `+0x5E >= 0`, and invokes `0x4E9C60`
(integer-x one step toward target); mode `1` performs the symmetric
`0x4E9C60`, `+0x5C`-residual decrement, and `0x4E9BF0` sequence. The
helpers only move one integer coordinate toward the stored target; they do not
perform collision or provider callbacks. After the substep loop the function
converts fixed-point `+0x52/+0x54` to tile coordinates by division by `20`,
writes `+0x1C/+0x1E`, refreshes the map-cell pointer at `+0x28`, clears byte
`+0x48`, and calls `0x4EA3B0`.

The direct callers show this is shared movement plumbing: generic residential
handlers (`0x4175B0`, `0x51D0C0`) use the same initializer/arrival pair, and the
recovered entertainment FSM reaches the initializer from its venue-route
branch. The coordinate fields, residual arithmetic, heading correction, and
arrival ordering are therefore **confirmed**; the route-buffer format and
consumer are closed separately in §7.2i. The provider/object callbacks around
`0x4E47A0` remain **unknown**. This evidence narrows the venue FSM
implementation contract; it does not authorize adding figures `32…34` to
Native's generic walker.

### 7.2h.1 Route-anchor arithmetic is now a pure Native boundary (2026-09-04)

The exact fields above are now represented by
`OriginalResidentialServiceCatalog.sharedRouteAnchor` in
`Sources/EmperorCore/HousingEvolution.swift`. The helper preserves the
signed-short target/residual storage width, the `2*min - max` diagonal
residual, and the movement-axis choice. Its
`sharedCoordinateHeading`/`correctedSharedCoordinateHeading` helpers encode
the complete `FUN_005B2730 @ 0x5B2730` table and the two explicit ratio-based
correction blocks in `FUN_004E98A0`.

The `FUN_005B2790` branch is represented by
`SharedRouteHeadingSource.sharedCallback` with a `nil` heading. That branch
depends on executable-global slope state and is not fabricated from the
coordinate table. `EmperorCoreTests` independently checks diagonal,
vertical, horizontal, and unresolved-global cases. This is a source-backed
arithmetic boundary only: it does not project map objects, route buffers,
collision results, provider registries, or venue settlement, and figures
`32…34` remain excluded from the live Qin walker.

### 7.2i Venue route-buffer consumption and 20-substep advancement (2026-08-30)

The route buffer written by `FUN_004E83E0` is consumed by the shared movement
loop, rather than being an opaque side effect. `FUN_004E83E0`, `FUN_004E7EB0`,
`FUN_004E8B40`, `FUN_004E8BC0`, and `FUN_004E92C0` are all EN/CH `identical` in
`local/source/compare-report.tsv`. A successful `FUN_005B18B0` reconstruction
returns a route slot in figure word `+0x42`, its direction count in `+0x46`,
and starts cursor `+0x44` at zero; the direction bytes are stored in the
shared table `DAT_010345C0` at `slot * 500 + cursor`.

Before movement, `FUN_004E8B40` loads the direction byte at that exact offset
when `+0x44 < +0x46`. When the cursor reaches the count it destroys the route
slot through `0x4E8A30` and emits heading `8`; with no route slot it falls back
to the direct `0x5B2730` heading helper and emits heading `10` if that helper
does not return `8`. `FUN_004E8BC0` then applies collision/object checks and
the mode-`0x12` terrain bit `0x100` hard guard, which forces heading `9`.

`FUN_004E7EB0` advances the route at the same fixed cadence already observed
for coverage: each supplied update increments byte `+0x41`; when it crosses
the 20-substep boundary it calls `0x4EACD0`, reconstructs heading/collision,
increments cursor `+0x44`, copies the selected heading to `+0x1A`, and resets
`+0x41`. `FUN_004E92C0` applies the eight heading cases to fixed-point
coordinates `+0x52/+0x54` and updates the figure's animation/turn bytes. Thus
the venue route primitive's output has a confirmed consumer and cadence,
including slot/cursor/count fields and the collision-result hand-off. The
remaining unknowns are the non-`0x100` terrain/object semantics and the venue
provider side effects around `0x4E47A0`; this still does not authorize a
Native figure-32…34 implementation.

### 7.2j Venue selector-8 update cadence (2026-08-30)

`FUN_004E47A0 @ 0x4E47A0` is `identical` for EN/CH. The recovered venue
initializer obtains the authored speed through selector `8`; for the venue
figures this value is `8` (rows `32…34` in `EmperorFigureModels.txt`). The
selector-8 branch uses figure byte `+0x170` as a small phase counter: when the
counter is `0` or `1` it calls `FUN_004E7EB0` with one update and increments
`+0x170`; when it is greater than `1` it calls `FUN_004E7EB0` with two updates
and resets `+0x170` to zero. The resulting supplied-update cadence is therefore
the exact repeating sequence `1, 1, 2`, independent of the authored speed
value's numeric `8`.

Because `FUN_004E7EB0` performs the 20-substep boundary work, this cadence
determines when venue figures advance their route cursor, invoke the radius-2
coverage scan, and run heading/collision evaluation. The counter's semantic
label and any additional selector values remain **unknown**; this is a
confirmed scheduling contract only and does not authorize generic-walker
support for figures `32…34`.

### 7.2j.1 Raw selector-switch plan is now encoded (2026-09-02)

The complete switch body in `local/source/split-merged/code/0x040000/FUN_004e47a0.c`
was re-read after the venue-only cadence note above. The cases are now
represented by the side-effect-free
`OriginalResidentialServiceCatalog.entertainmentVenueMovementUpdatePlan`
helper and a branch-by-branch test. This closes the raw scheduling plan for
selectors `0…17` plus the default branch: each case records the exact
`FUN_004E7EB0` update count and whether byte `+0x170` is incremented or reset.
Selectors `1…17` use the recovered strict thresholds (`>2`, `>1`, or `<2/<3`)
and reset values; selectors `0`, `6`, and `0x0C` leave the phase byte
unchanged, while the default branch supplies three updates without touching
it. The helper uses byte addition semantics for the incrementing cases.

This is a confirmed byte-level dispatch contract for the canonical English
build (`8a6d2df1…9d6753`); the Chinese build (`dbdeca1e…ac15a`) is identical
for this function in `local/source/compare-report.tsv`. It does **not** infer
the domain meaning of the other selector values, and it does not bridge the
unresolved venue provider registry, route/collision side effects, or terminal
settlement into Native gameplay. The only venue selector currently consumed
by a recovered FSM remains selector `8`, whose tested phase sequence is
`(0→1 update 1), (1→2 update 1), (2→0 update 2)`.

### 7.2j.2 Selector-8 reuse in already-supported clocks (2026-09-02)

The same pure helper is now consumed by the existing Native compatibility
clocks for recovered road service walkers (`WalkerSimulation.originalSubsteps`)
and market buyer/peddler figures (`MarketSimulation.advanceOriginalFigureUpdate`).
Those callers pass selector `8` only where their existing contracts already
document the recovered `1,1,2` cadence; non-selector-8 walker inputs retain
their prior one-substep behavior. This removes three duplicated hand-written
phase branches without enabling the venue figures `32…34` or changing the
campaign provider/route gate. The helper remains a byte-level scheduling
primitive: its call sites still lack the PE-layer projection, provider
registry, collision, and house-settlement evidence required for Qin live
service coverage.

### 7.2k Venue mode-`0x12` category-table callback is a low-byte no-op (2026-08-30)

One object-collision branch that was previously left opaque is now bounded.
`FUN_005221A0` forwards the figure mode byte `+0x80` and candidate cell index
to `FUN_005221C0`; both functions are EN/CH `identical` in
`local/source/compare-report.tsv`. `FUN_004E8BC0` includes mode `0x12` in the
set that invokes this callback and treats a zero returned byte as the
non-blocking path. `FUN_005221C0` has explicit cases for selectors `2`, `8`,
`10`, `0x0C`, `0x10`, `0x13`, and `0x14`, but no case for selector `0x12`.
That selector therefore reaches the common return `DAT_01339270[cell] &
0xFFFFFF00`; because the caller stores the result in a byte, its low byte is
always zero and this category-table callback cannot itself block a mode-`0x12`
venue step.

This is a confirmed negative result, not a semantic name for the table. The
later terrain-word tests (`0x40`, `0x400`, `0x08`, `0x04`, `0xC000`) and the
owner-vtable branches in `FUN_004E8BC0` still remain separate unknowns; Native
must not collapse them into a generic “object passable” predicate.

### 7.2l Venue collision predicate: exact branch shape (2026-08-30)

The remaining collision uncertainty can be bounded without assigning business
names to the terrain tables. `FUN_004E8BC0 @ 0x4E8BC0` is `identical` in the EN
and CH rows of `local/source/compare-report.tsv`; its direct caller is the
shared `FUN_004E7EB0` movement loop. The function first resolves the candidate
cell from the figure heading (`+0x19`), terrain word `DAT_00F6A9E0[idx2]`, and
object index `DAT_00FC3750[idx2]`. A heading value greater than `7` returns
before any terrain test.

The following predicates and writes are directly present in the split body:

| branch | exact condition | effect |
| --- | --- | --- |
| object-state precheck | `FUN_004E2560(figure+0x12)` is true, `FUN_005E3400(idx2)` returns an object, and that object's `+0x40 == 5` | call object-owner `+0xF0`, pass result to `FUN_004EBA80`, write figure `+0x19 = 9`, return |
| figure mode `3` | `figure+0x21 == 3` and auxiliary byte `DAT_0136BEB0[idx2] != -5` | write `+0x19 = 9` |
| mode `0`, category callback | `figure+0x20 ∈ {2,8,10,12,16,19}` | call `FUN_005221A0`; nonzero returned byte writes `+0x19 = 9` |
| mode `0`, terrain equality | `figure+0x20 == 0x15` and `terrain[idx] != 0x80000` | write `+0x19 = 9` |
| mode `0`, auxiliary height | `figure+0x20 == 4` and `DAT_0132C760[idx2] < 0x80` | write `+0x19 = 9` |
| mode `0`, routing bits | category `9`: `routing[idx2] & 3`; category `6`: `(routing[idx2] & 2) == 0 || terrain[idx2] & 0x10004`; category `14`: `routing[idx2] & 0xC` | any nonzero/failed requirement writes `+0x19 = 9` |
| mode `0`, default terrain/object path | `routing[idx2+1] & 8`, `FUN_00424300(idx2,0)`, `terrain & 0x40/0x400/0xC000`, `terrain & 8/4`, object type tests through `FUN_004C11B0`, `FUN_00562F70`, `FUN_00568A50`, `FUN_00415770`, and owner `+0xCC` | branch-specific return, heading `9`, or linked-object creation; no single collapsed predicate is emitted |
| mode nonzero | `terrain & 4` and auxiliary byte is `>= -1` or `-5` | write `+0x19 = 9` |
| final hard guard | `terrain[idx2] & 0x100` | write `+0x19 = 9` |

The default terrain/object path also contains a confirmed side effect: when
`routing[idx2+1] & 2` is set, it resolves the object at `local_4`, invokes its
`+0x278` coordinate writer, creates an object through `FUN_004EA050(..., 0x30,
..., 0, 1, -1)`, stamps the current and linked figures with `+0x6F = 1`,
stores the created ID at `+0x13C`, and advances the linked chain through
`+0x66`. This is not a venue-provider callback and cannot be represented by a
boolean passability test.

The branch shape, constants, helper call edges, and the mode-`0x12` final
`0x100 → +0x19 = 9` guard are **confirmed**. The semantic identities of the
terrain words, auxiliary arrays, object types, and owner virtual slots remain
**unknown**. In particular, this evidence still does not authorize enabling
figures `32…34` in Native: doing so would require implementing the object
creation/chain side effect and every branch that can alter heading or failure
state, not merely the recovered mode-`0x12` route mask.

### 7.2m Venue provider candidate admission primitive (2026-08-30)

The candidate-admission half of `FUN_0048A520 @ 0x48A520` is now represented
as the side-effect-free `OriginalResidentialServiceCatalog.entertainmentProviderCandidates`
helper. The helper is deliberately a
record of recovered predicates, not a provider chooser: it accepts only
figure models `32…34`, requires the global `FUN_00426D10(0)` gate, and keeps a
provider only when its `+0x264` model test and `+0x78` state test are non-zero
and its `+0x1B4` work value is strictly positive. It preserves provider-list
order and applies the exact first-non-empty capacity buckets `n <= 8`, then
`n <= 16`, then `n <= 24`; each retained record carries `+0xB4`, the
`+0x1A4` result, the model capacity `n`, and side weight `n×2`.

The EN/CH split-corpus function bodies are identical (`compare-report.tsv`),
and the implementation is covered by
`EmperorCoreTests.testEntertainmentProviderCandidatesUseRecoveredTieredAdmissionAndWeights`.
The returned records are not consumed by simulation. The subsequent
`FUN_004E7FD0` dispatch forwards them to `FUN_005B0620` for mode `0x12`; that
route/occupancy chooser's map-cost and side-effect contract remains unknown,
so Native still keeps figures `32…34` outside `supportsRecoveredResidentialRoam`.

### 7.2n Venue provider weighted-route selector (2026-08-30)

The route-selection portion of the same chain is now bounded by the split
corpus and a direct PE check. `FUN_004E7FD0 @ 0x4E7FD0` passes the candidate
target array and the `n×2` weights from `FUN_0048A520` to
`FUN_005B0620 @ 0x5B0620` for mode `0x12`. The EN/CH split bodies are marked
`identical` in `local/source/compare-report.tsv`; the recovered EN/CH PE
function bytes are identical (length `0x26d`, SHA-256
`b7739a4c6ac199cadd1d2d45e05736b4b152627573d34aa01ec0e333d5b4aa71`) for the
canonical builds recorded at the top of this file.

`FUN_005B0620` materializes one 16-byte work record per candidate before its
map walk:

| record offset | value | evidence |
| --- | --- | --- |
| `+0x00` | candidate ordinal `0…count-1` | direct decompilation assignment |
| `+0x04` | candidate target cell from the target array | direct decompilation assignment |
| `+0x08` | base weight from the weight array (`n×2` for the entertainment admission path) | direct decompilation assignment and §7.2m |
| `+0x0C` | best cost, initialized to `100000` and overwritten on improvement | direct decompilation assignment |

The pre-walk `FUN_00765EE9(..., stride 0x10, &LAB_005B0600)` sort compares
record `+0x08` values (`LAB_005B0600` returns left `+0x08` minus right
`+0x08`). The BFS then visits the current map cell, scans candidate records
from the highest ordinal downward, and for each target match computes
`baseWeight + localDistance`. A record is updated only on a strict `<` cost
improvement; the selected result is the winning candidate ordinal plus one,
or zero when no candidate is reached. The mode flag selects the neighboring
cell expansion helper: mode zero calls `FUN_005B0220` (mask `0x10C`), while a
nonzero flag calls `FUN_005B0360` (mask `0xB0C`). The walk uses the shared map
distance buffer, wraps its queue cursor at `0xCB10`, and performs a recovered
best-cost bound check before continuing expansion.

This closes the chooser's arithmetic, return convention, and deterministic
equal-weight ordering for a given input sequence, but not its full gameplay
meaning. The map masks, distance-buffer initialization, object/occupancy side
effects, and the route's interaction with provider capacity remain **unknown**.
Consequently this evidence does not authorize enabling the venue FSM or wiring
the selector to live simulation; it only narrows the original contract to a
weighted map search with a one-based candidate return.

**Classification:** record layout, caller/callee edges, `n×2` weight source,
strict cost comparison, mode-specific expansion helpers, and one-based return
are **confirmed**. The map/object semantics and provider occupancy/settlement
effects remain **unknown**; the sorter and equal-cost tie order are closed in
§7.2n.1 below.

### 7.2n.1 Weighted candidate primitive with source quicksort ties (2026-08-31)

The confirmed arithmetic is exposed by
`OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidate`. It uses
the provider path's `0x0B0C` cardinal flood, preserves each candidate's
original ordinal, and computes the same initialized-distance cost: a target at
the origin contributes `0`, while a target reached after `d > 0` edges
contributes `d + 1` to its base weight. Before the walk it now translates the
source `FUN_00765EE9` sorter: ranges of up to eight use the exact
`FUN_0076603D` selection pass, while larger ranges use the median-pivot,
forward/backward partition and explicit segment stack. The comparator is
`FUN_005B0600` (`left.baseWeight - right.baseWeight`), and the chooser scans
the sorted records from the highest index down with a strict cost comparison.
Equal-cost ties therefore resolve to the first record encountered after the
source's actual swaps; they are no longer represented as an invented `nil`
result. Regression coverage includes both the small-range swap order and the
greater-than-eight pivot path.

This closes the sort/tie mechanics only. The provider registry, map-object
occupancy effects, and terminal settlement remain outside this helper, so it
is not wired into live Qin venue figures.

### 7.2n.2 Unweighted venue candidate-array floods (2026-08-31)

The two unweighted candidate selectors forwarded by `FUN_004E7FD0` are now
closed from the split corpus. `FUN_005AE970 @ 0x5AE970` seeds the current cell,
checks the candidate array from the highest index down, then expands cardinal
neighbours through `FUN_005AE840`; its admission mask is `0x0B1D`. The mode-
`0x12` fallback `FUN_005B04A0 @ 0x5B04A0` checks candidates from index zero
upward and dispatches to `FUN_005B0220` for flag zero (`0x010C`) or
`FUN_005B0360` for a nonzero flag (`0x0B0C`). Both paths test the start cell
before expansion and enqueue north, east, south, west in that order. The
EN/CH rows for all five helpers are `identical` in
`local/source/compare-report.tsv`.

`OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex`
represents these three pure contracts, including one-based return values,
same-cell duplicate arbitration, and BFS queue order. It does not construct
the shared route buffer, resolve provider objects, update occupancy, or write
house coverage; those downstream effects remain unknown and the venue FSM
stays fail-closed.

**Classification:** masks, candidate scan direction, cardinal order, start-cell
test, and zero/one-based return conventions are **confirmed**. Provider
registry mapping, object occupancy, route reconstruction, and settlement remain
**unknown**.

### 7.2n.3 Venue state-7 selects the weighted mode-1 flood (2026-09-03)

The venue-specific call context is now separated from the generic mode labels
used by `FUN_004E7FD0`. The direct EN/CH PE recovery of the interior
`0x48A9A0` body shows that state `7` writes figure byte `+0x80 = 1` before
calling `0x4E9620(..., 1)`, `0x48A340`, and `0x48A520`. At
`FUN_004E7FD0 @ 0x4E7FD0`, switch case `1` sets its route-mode local to `1`
and falls through the shared provider-selection branch. When the fourth
forwarded argument is non-zero, that branch calls `FUN_005B0620` with the
candidate target array, the side-weight array, the candidate count, and the
literal final mode `1`; the zero-fourth-argument branch instead calls
`FUN_005B04A0` with mode `1`.

This is a calling-convention correction rather than a new gameplay rule. The
generated C for `0x4E7FD0` emits only four formal parameters, while the direct
call-site bytes preserve the additional stack arguments consumed by
`FUN_005B0620`'s six-argument body. `FUN_0048A520` supplies the candidate
targets from provider vtable `+0x1A4` and the `n × 2` side array described in
§§7.2c and 7.2h. Therefore an entertainment figure that reaches state 7 uses
the non-zero-mode `FUN_005B0360` expansion (four cardinal neighbours admitted
by mask `0x0B0C`), followed by the weighted record walk and one-based return
described in §7.2n. The earlier §7.2n wording that attributed this venue call
to the `+0x80 == 0x12` case is superseded; that case remains a separate
generic caller of the same shared branch.

The state assignment, branch selection, literal mode, candidate/weight
forwarding, EN/CH parity, and four-neighbour `0x0B0C` expansion are
**confirmed** from the hash-identified PE pair and
`local/source/split-merged/code/0x040000/FUN_0048a520.c`,
`local/source/split-merged/code/0x040000/FUN_004e7fd0.c`,
`local/source/split-merged/code/0x050000/FUN_005b0620.c`,
`local/source/split-merged/code/0x050000/FUN_005b0360.c`, and the
`compare-report.tsv` row for `0x5B0620`. This still does not recover the
provider registry/object projection, route collision semantics, occupancy
mutation, or provider-to-house settlement. Native therefore remains
fail-closed for figures `32…34`; the correction narrows the missing contract
but does not authorize live venue wiring.

### 7.3 Provider `+0x224` dispatch and predicate (2026-08-30)

The water callback's boolean is a virtual dispatch, not an inline field test.
`FUN_0051BC00 @ 0x51BC00` invokes `param_1`'s vtable slot `+0x224` before
choosing the `+0x32`/`+0x34` destination. The specialized provider factory
`FUN_0051BEF0` is keyed by authored building IDs `72` (Well), `73` (unused),
`207` (Herbalist's Stall), and `208` (Acupuncturist's Clinic); all four share
the `FUN_0051BA50` base constructor but install vtable labels `0x7B5EB4`,
`0x7B6114`, and `0x7B6374`.

Direct vtable reads from the hash-matched EN and CH PE files close the slot
dispatch that the split corpus omitted:

| authored IDs | vtable | `+0x224` target | observed result |
| --- | --- | --- | --- |
| 72, 73 | `0x7B5EB4` | `0x5B3AD0` | `1` iff provider word `+0x16 > 0` **or** provider byte `+0x6F > 0`, otherwise `0` |
| 207 | `0x7B6114` | `0x413A00` | always `0` |
| 208 | `0x7B6374` | `0x413A00` | always `0` |

`0x413A00` is present in `functions-index.csv` and its EN/CH bodies are
identical. `0x5B3AD0` is a short interior method omitted as a standalone row;
direct PE bytes at `0x5B3AD0…0x5B3AE6` are identical in EN and CH (23 bytes;
SHA-256 `ba0a204c6c96cd061c7b6d9e69805d8fdc767d60488ab87dc40d9d238d3607f5`)
and contain only the two field tests and the `0/1` return. This establishes the
predicate and its provider-family mapping without assigning semantic names to
the two fields.

The same slot is called by five other emitted functions (`0x508BA0`,
`0x509520`, `0x51CE70`, `0x53C020`, and `0x5B3A60`), each on a different
receiver/context. Their EN/CH bodies are `identical`; those call sites do not
change the provider-family mapping above. No additional `+0x224` target is
selected by the recovered residential provider constructors.

**Classification:** the dispatch targets, provider ID mapping, field offsets,
and `0/1` return domain are `confirmed`. The semantic names/lifecycle of
provider `+0x16` and `+0x6F`, and the meaning/lifecycle of the global object's
`+0x50/+0x54/+0x58` fields used by the false branch, remain **unknown**.
Native must not collapse the predicate to a building-ID check or substitute a
guessed worker/water flag.

### 7.3a Well-provider `+0x16` setter chain (2026-08-30)

The well predicate's word field `+0x16` has explicit setter methods in the
well vtable. Direct EN/CH PE reads at vtable `0x7B5EB4` resolve slots
`+0x21C` and `+0x220` to short bodies `0x51BB90` and `0x51BBA0`; the former
writes provider word `+0x16 = 0`, while the latter writes `+0x16 = 1`.
The seven-byte bodies are byte-identical in the hash-matched EN/CH PEs:
`0x51BB90` bytes `66 C7 41 16 00 00 C3` (SHA-256
`8429b126df70bbfab399eba5d88fe1e8ee452a5da511380c007aa0d453f87c78`) and
`0x51BBA0` bytes `66 C7 41 16 01 00 C3` (SHA-256
`e05b50378c170e24ef9a470fd82e8e9364c8ddc07e884e08d387b3f9e098fed5`).
`FUN_0051CEC0 @ 0x51CEC0` (EN/CH `identical`) is the provider method at slot
`+0x218`: it obtains value `FUN_0044CC50(buildingID, 10)`, tests vtable
`+0x228` first with mode `0`, then mode `1`, invokes the corresponding
`+0x21C/+0x220` setter when one test succeeds, and finally calls slot `+0x100`
with the provider building ID and coordinates. For the well vtable,
`+0x228` is `0x51CE70`, whose result itself depends on the provider's
`+0x1F8` value and the `+0x224` predicate.

This closes a provider-internal state transition: `+0x16` is actively toggled
by the provider update path before `0x51BC00` evaluates it, rather than being a
constant worker count. The base constructor `0x51C2E0` initializes both
`+0x16` and `+0x6F` to zero; no constructor or provider-scheduler writer for
`+0x6F` was recovered (the immediate writes at `0x416E58` and `0x4181D2` are
figure init/update code). A separate generic object-state writer is now
documented in §7.3i, but its trigger is not part of the provider scheduler.
The mode-0/mode-1 resource semantics, `+0x1F8` calculation, and the remaining
indirect writes to `+0x6F` remain **unknown**;
Native must not reduce the water predicate to a guessed boolean until those
inputs are recovered.

The caller of this setter chain is also identified. `FUN_00517AD0 @ 0x517AD0`
(EN/CH `identical`) is the scheduler phase-`0x24` consumer: it iterates the
active provider list, requires global `FUN_00426D10(0)` and each provider's
vtable `+0xB8` eligibility predicate, then invokes that provider's `+0x218`
method. The well therefore reaches `0x51CEC0` through the normal provider
scheduler rather than an ad-hoc water-only path. The scheduler's exact
phase-to-month scaling is already recorded in §7.1; the unresolved parts here
are limited to the provider appeal-value semantics and the external
`+0x6F` writer's trigger/cadence. The authored Well threshold is fixed at 40
as recorded in §7.3f1.

### 7.3b Well-provider `+0x16` transition formula (2026-08-30)

The two setter calls in `0x51CEC0` are selected by a fully recoverable
predicate. For the well vtable, slot `+0x1F8` is `0x4273D0`; its body reads
provider word `+0x10`, performs the intermediate `0x53C870` call, and returns
the byte from `0x44F180`. `FUN_0051CE70` then compares that signed
byte `v` with the threshold `t` passed by `0x51CEC0` (the value returned by
`FUN_0044CC50(providerBuildingID, 10)`). Its mode-0 result is true exactly
when `v < t` **and** the `+0x224` predicate is true; its mode-1 result is
true exactly when `v >= t` **and** the `+0x224` predicate is false.

Consequently, the well provider's word `+0x16` is written as `0` only for
`v < t && predicate`, and as `1` only for `v >= t && !predicate`; otherwise
the existing word is left unchanged. The subsequent `+0x100` callback is
still invoked after either setter. This transition is `confirmed` from
`FUN_0051CE70`, `FUN_0051CEC0`, and the EN/CH-identical vtable rows. The
semantic meaning of `v` and the indirect callers of slot `+0x218` remain
**unknown**; the authored threshold value is closed in §7.3f1, but Native
still must not synthesize a
water-ready state from worker count or building ID.

### 7.3c Water callback `+0x32`/`+0x34` branch condition (2026-08-30)

The destination choice in `FUN_0051BC00` is now fully explicit. After the
global gate, target `+0xB8` eligibility, and positive population checks, a
true provider `+0x224` predicate writes `cHouseInfo +0x34`. When that
predicate is false, the function obtains the global object `DAT_00C701D8`
through `FUN_0048DF30` and calls `FUN_0048E110`. The latter is EN/CH
`identical` and returns true exactly when `FUN_00608620` reports its object
byte `+0x50` nonzero **and** object dwords `+0x54 == 3` and `+0x58 == 4`. A
true result takes the same `+0x34` write; otherwise the callback writes
`cHouseInfo +0x32`. Both writes use `0x60` and return success.

Thus the branch condition and call ordering are **confirmed**; only the
semantic meaning and lifecycle of the global object's `+0x50/+0x54/+0x58`
fields remain **unknown**. Native must preserve the two distinct house bytes
and must not replace this condition with a difficulty, building-ID, or worker
heuristic.

The source-backed `OriginalWaterProviderState.writeHouseInfoWater` helper now
also models the complete callback gate and write: the initial global gate,
candidate `+0xB8`, and positive `+0x20` checks must all pass; then provider
`+0x224 == true` selects `+0x34`, the global `3/4` branch also selects
`+0x34`, and all other successful calls select `+0x32`. It writes `0x60` only
to the selected byte and preserves the other byte. This helper is still
research-only because the resolved map-object/provider registry is not
available in Native.

### 7.3d Distinct water fields are consumed independently (2026-08-30)

The two callback destinations are not merely alternate storage for one Native
water flag. `FUN_004AC2B0 @ 0x4AC2B0` dispatches calendar phase `0x1C` to
`FUN_004ACE30`; both EN and CH rows are `identical` in
`local/source/compare-report.tsv`. `FUN_004ACE30` calls `FUN_005179B0`, which
scans live providers and, for each eligible provider, resolves its target house
through vtable `+0x1E4` and performs this exact reduction:

```text
building +0x39 = 0
if cHouseInfo +0x32 != 0: building +0x39 = 1
if cHouseInfo +0x34 != 0: building +0x39 = 2
```

The second test therefore has precedence when both bytes are nonzero. A
separate provider/house pass, `FUN_00518D60`, calls
`FUN_00517330` and `FUN_005173E0`. `FUN_00517330` adds **5** to score byte
`+0x38` when `+0x32` is nonzero and **15** when `+0x34` is nonzero, alongside
independent service/desirability terms; `FUN_005173E0` does not read either
water byte. These bodies are `identical` at `0x5179B0`, `0x518D60`,
`0x517330`, and `0x5173E0`.

This closes three facts as **confirmed**: phase `0x1C` is the field-consumer
boundary, `+0x32` and `+0x34` are independently tested, and their downstream
score weights are 5 and 15 with `+0x34` taking precedence in the compact status
byte. The semantic names of the two services, the meaning of provider
`+0x224`/global fields, and the later consumers of house `+0x39/+0x38` remain
**unknown**. Native must not collapse these writes into one boolean until those
consumer contracts are recovered.

### 7.3e Global branch object is an outcome/difficulty state machine, not a water counter (2026-08-30)

The object returned by `FUN_0048DF30` is the fixed global `DAT_00C701D8`.
The EN and CH rows for the relevant accessors and mutators are all
`identical` in `local/source/compare-report.tsv` (`0x48E020`, `0x48E0D0`,
`0x48E0F0`, `0x48E110`, `0x48E140`, `0x48E170`, `0x48E1D0`, `0x48E200`,
`0x48E230`, `0x48E930`, `0x48EA40`, `0x48EB90`, `0x48CC80`, `0x48F770`,
`0x48F820`, and `0x48F8D0`). Static tracing gives the following bounded
lifecycle:

* `0x48EB90` clears object byte `+0x50` and dword `+0x54`, then calls
  `0x48E930`. That evaluator scans the population/month counters, computes
  resource and military thresholds, and returns success only after all of its
  checks pass. Its out-parameter classifies failure as `1…4`.
* On the success path `0x48EA40` sets byte `+0x50 = 1` and dword `+0x54 = 0`.
  The three explicit mutators then set `+0x54` to `2`, `3`, or `4` and copy a
  selector into `+0x58` (`0x48F770`, `0x48F820`, `0x48F8D0`). Each emits a
  distinct resource-message range (`0x7A2…0x7A6`, `0x7A7…0x7AB`, or
  `0x7AC…0x7B0`), so these are presentation/state transitions, not per-house
  service writes.
* The helper predicates are exact state tests gated by byte `+0x50`:
  `0x48E0D0` tests `+0x54 == 2`; `0x48E0F0` tests `== 3`; `0x48E110` tests
  `== 3 && +0x58 == 4`; `0x48E140` tests `== 4 && +0x58 == 0`;
  `0x48E170` tests `== 4 && +0x58 == 1`; `0x48E1D0` tests `== 4 &&
  +0x58 == 3`; and `0x48E200` tests `== 4 && +0x58 == 4`.
  `0x48E230` consumes `+0x58` as a five-way selector and returns a
  selector-specific resource-ID allow-list.
* Independent callers use those predicates for non-water adjustments:
  `0x44C380` applies a quartering rule to selected resource quantities when
  `0x48E0D0` and `0x48E230` match; `0x54C370` chooses one of two UI/message
  markers from `0x48E140`; and `0x552100` applies a 13/10 modifier when
  `0x48E170` matches. These callers do not access residential `cHouseInfo`.

Therefore the `0x51BC00` false-provider branch's call to `0x48E110` is
confirmed as a cross-system outcome/state predicate, but its semantic labels
and exact transition trigger are still **unknown**. This trace rules out
using the object as a water-service counter or replacing it with a guessed
difficulty/building/worker flag. Native must keep that branch unsupported
until the outcome-state contract is independently represented; the distinct
water bytes remain required regardless of this negative result.

**Evidence class:** `confirmed` for the fixed global address, field tests,
mutator values, selector allow-list, and non-water callers; `unknown` for the
human-facing names and the exact event that advances each outcome state.

### 7.3f Well threshold value is the appeal-buffer byte at the provider slot (2026-08-30)

The previously unresolved `+0x1F8` input is now identified as a per-cell
appeal-buffer read. Direct EN/CH PE disassembly for `0x4273D0` is identical
(17-byte slice SHA-256
`2baa3fe1b196daeeac0c024e4df658dddada6842463541ab17e36e08c2cf018f`). The
body loads the provider dword at `+0x10`, performs the intermediate call at
`0x53C870`, and then calls `0x44F180`, which consumes the still-pushed index
and returns the byte. `0x44F180` reads
`DAT_00F11C70[index]` (identical 11-byte EN/CH slice SHA-256
`dce0384464f81f8bcbdff0537466f57d2950b0d700de58fcde80f2ac9c83e199`). The
the recovered `0x4273D0` body leaves the pushed provider `+0x10` as the actual
index consumed by the reader.

`DAT_00F11C70` is not a water-specific table. `0x44F1D0` clears and rebuilds
the `0x32C4`-cell appeal buffer from active building desirability fields, and
`0x4AC2B0` schedules that producer in phase `0x25`; `0x4ACD10` subsequently
copies the buffer into live-object appeal bytes. Independent callers
(`0x4B7270`, `0x4BDEF0`, and `0x4ACD10`) compare or aggregate the
same buffer as neighborhood appeal. Provider `+0x10` is also used as an index
into the per-cell `DAT_00FE9880`/`DAT_00F6A9E0` arrays by `0x51DBD0`,
`0x51E1C0`, and `0x4C24D0`; static evidence therefore supports a runtime
map-slot identity, not an authored water quantity. The exact assignment of
that slot during object deserialization remains unknown.

The `FUN_0051CE70` transition can consequently be stated without a semantic
guess: let `v = DAT_00F11C70[provider.+0x10]` and let `t` be the runtime
`FUN_0044CC50(buildingID, 10)` value. `+0x16` is set to `0` only for
`v < t && predicate`, set to `1` only for `v >= t && !predicate`, and is left
unchanged otherwise. Native records this exact comparison as the pure
`OriginalWaterProviderState.nextFlag` helper and tests all four truth-table
cases, but does not wire it into simulation: the appeal-buffer rebuild,
provider-slot assignment, the trigger/cadence of the generic `+0x6F` writer,
and the two house-byte consumer contracts are still not isomorphic.

**Evidence class:** `confirmed` for the byte-level reader, appeal-buffer
producer/consumer chain, and four-way transition formula; `unknown` for the
provider slot's complete assignment/deserialization lifecycle and the
semantic labels of the well predicate fields.

### 7.3f1 Well transition threshold is authored value 40 (confirmed, 2026-08-30)

The threshold passed to `FUN_0051CE70` is not an unrecovered magic number.
`FUN_0044CC50 @ 0x44CC50` computes the model-table address
`0x00A5B398 + buildingID × 13 + fieldIndex`, loads the dword, and only applies
the `FUN_0044C380` difficulty adjustment when `fieldIndex == 0`. The Well
provider calls it with `(buildingID = 72, fieldIndex = 10)`, so no adjustment
branch is taken. In the authored source
`GameData/Model/EmperorBuildingModels.txt`, the Well row is:

```
72,Well,{,25,4,2,-2,4,4,0,8,0,0,40,200,3,},
```

The file header labels field 10 (zero-based) **Evolve Desirability**. The five
difficulty modifier rows at the top of the same file all carry `100` at field
10, and `FUN_005D16D0 @ 0x5D16D0` multiplies each authored model field by that
modifier and divides by 100 when building the runtime `DAT_00A5B398` table.
Therefore the runtime threshold for Well is exactly **40** across the authored
Very Easy through Very Hard rows. The unused Well-family row 73 and the
Herbalist/Acupuncturist rows 207/208 carry field-10 value `0`; they do not
change the conclusion for the live Well model 72.

This closes the numeric threshold input to the `+0x16` transition. It does not
close the appeal-buffer value's semantic source (beyond its confirmed table
identity), the provider `+0x6F` writer trigger/cadence, or the two house-byte
consumer lifecycle. Native may use `40` only inside the existing pure research
primitive; it must not enable the water requirement until those remaining
object/registry contracts are recovered.

**Evidence class:** `confirmed` for the table index calculation, field index,
authored Well value, difficulty-modifier scaling, and resulting value `40`;
`unknown` remains for the semantic meaning/lifecycle of the provider state
fields and the external writer.

#### 7.3g Provider `param[0x2d]` (`+0xb4`) is an unresolved registry-object reference (negative type-9 result)

The `+0x10` index used by the well threshold reader must not be conflated with
the `+0x10` field of the campaign-goal **type 9** record. In the decompiler's
`int *` view, the provider stores `param[0x2d]`, i.e. the dword at byte offset
`+0xb4`; this is distinct from a byte field at byte offset `+0x2d`.
`FUN_00426C90`/`Problems_creating_guid`
initializes that field to `-1`, and the common object serializer
`FUN_00427430 @ 0x427430` persists it as a four-byte field. Provider callers
resolve the value through `FUN_0047F1B0` and, in
`FUN_004B38C0 → FUN_004B3930`, follow an object-parent link at `+0x3c` before
reading a root object's `+0xb4`. `FUN_0051DBD0` then reads the resolved
object's `+0x10`, `+0x0c`, and `+0x0a` and dispatches its vtable `+0x174`;
this is the shape of a registry/map-object reference, not a direct water
quantity.

The type-9 constructor path is independently bounded by
`FUN_0055A8E0(case 9) → FUN_00559900 → FUN_00560E50`: it allocates `0x14`
bytes, sets `+4 = 9`, and initializes only `+8`, `+0x0c`, and `+0x10` to zero;
`FUN_00560EF0` serializes exactly those three fields. Its known consumers
(`FUN_0055AFD0`, `FUN_0055B6A0`) aggregate campaign-goal values and do not
provide the provider's parent-link/coordinate/vtable contract. Because the
type-9 object does not contain the `+0x3c` link read by `FUN_004B3930` (and its
allocation is only `0x14` bytes), no static evidence authorizes treating a
provider `+0x2d` target as type 9 or using type-9 `+0x10` as the appeal-buffer
slot. The registry class, serialized value's source, and map-object
assignment for provider `+0x2d` therefore remain **unknown**; the common
deserialization write site itself is closed in §7.3h.

**Evidence class:** `confirmed` for initialization, serialization, parent-link
and resolved-field reads, and the type-9 allocation/field layout; `unknown`
for the provider's concrete registry target, serialized value source, and
map-object assignment. This negative result supersedes the exploratory type-9
hypothesis and keeps the Native water bridge fail-closed.

### 7.3h Well `+0x2D` deserialization write site (confirmed, 2026-08-30)

The assignment mechanism for the provider's registry slot is no longer wholly
unknown. In both canonical PEs, the Well vtable at `0x7B5EB4` has slot `+0x08`
equal to `0x51CE00` (the `.rdata` words at `0x7B5EB4` begin
`20 BA 51 00 30 F4 4B 00 00 CE 51 00`). `FUN_0051CE00 @ 0x51CE00` is the
Well-family object save/load wrapper and calls `FUN_00427430 @ 0x427430`.

`FUN_00427430` branches on the archive I/O mode. Its write branch emits the
provider slot with `FUN_00780642(param + 0xB4, 4)`. Its read branches consume
the same four-byte field with `FUN_00780533(param + 0xB4, 4)` after the common
object fields (the `ret == 3`, `ret == 4`, `ret == 5`, and default schema paths
all converge on that final read). Thus a loaded Well object receives its
serialized `+0xB4` value before the wrapper's post-load callback runs; this is
the concrete deserialization write site, not a guessed runtime assignment.
The EN/CH compare row for `0x427430` is `identical`, and the Well vtable words
at `0x7B5EB4` match between the two PE inputs.

This closes the read/write mechanism and field width, but not the serialized
value's producer: the map/archive record that supplies the registry index, the
parent-link chain used by `0x4B38C0`, and the post-load registration that makes
that object a usable provider target remain **unknown**. Native must not
populate `provider +0x2D` from a Native house ID,
campaign-goal field, or water quantity without that source mapping.

**Evidence class:** `confirmed` for the Well vtable slot, wrapper call, dual
I/O branches, field offset/width, and EN/CH identity; `unknown` for the
serialized record's producer, referenced object class, and post-load registry
semantics.

### 7.3l Generic Building load and model-specialization conversion (confirmed mechanism, unknown trigger)

The map archive does not expose a separate Well/Herbalist/Acupuncture record
class in the static load path. `FUN_0042D0E0 @ 0x42D0E0` asks the `Building`
type descriptor at `0x817890` for a record, whose constructor is
`FUN_0042D050 @ 0x42D050`; that constructor installs the base building vtable
(`0x7AB59C`). `FUN_0042D790 @ 0x42D790` then inserts each decoded record into
the building list and invokes the object's `vtable +0xC0` callback when the
record is active. The EN/CH compare rows for `0x42D0E0` and `0x42D790` are
`identical`.

The common serializer `FUN_00427430 @ 0x427430` reads and writes the generic
record fields, including one byte at `+0x5E` and the four-byte provider slot at
`+0xB4`; its read branches all converge on the `+0xB4` read after the schema
specific field blocks. `FUN_00426EA0 @ 0x426EA0` copies the same generic field
range, including `+0x5E`, and is the base object's `vtable +0x0C` method. The
relevant `0x426EA0`, `0x427430`, `0x42D0E0`, and `0x42D790` rows are
`identical` in `local/source/compare-report.tsv`.

There is a separate, explicit specialization mechanism: the common building
vtable slot `+0x18` points to `FUN_00427150 @ 0x427150` for the base, House,
Well-family, Herbalist, and Acupuncturist vtables checked in both PEs. It reads
the model ID from source offset `+0x14`, calls `FUN_0042D360(modelID)` to
construct the model-specific object (House IDs `2…17`, Well-family `72/73`,
Herbalist `207`, Acupuncture `208`), then invokes the source object's
`+0x0C` copier to transfer the generic fields and returns the specialized
object. For the provider families the copier is `FUN_0051CAA0`, which extends
the generic copy with the provider tail; for the base object it is
`FUN_00426EA0`. The `0x427150` body is `identical` in EN/CH.

This closes the existence and field-copy direction of generic-record →
model-specific-object conversion. The split corpus does **not** identify the
caller that invokes `vtable +0x18` for objects loaded by `FUN_0042D790`, nor the
point at which the specialized object is reinserted into the runtime registry
and receives a usable `+0x2D` parent/object link. Consequently the archive
producer, conversion trigger/cadence, and post-load registry registration
remain **unknown**. `+0x5E` being present in the generic record is therefore
not evidence that a loaded Qin building already has a live appeal projection,
and Native must keep the load-time provider/desirability bridge fail-closed.

**Evidence class:** `confirmed` for the generic descriptor/constructor,
serializer field coverage, common copier, specialization function, model-ID
dispatch, and provider copier selection; `unknown` for the specialization
caller, replacement/list-registration order, serialized record producer, and
parent-link assignment.

### 7.3m Post-load repair excludes provider models (negative, 2026-08-30)

The map setup path supplies one additional negative boundary. The direct
`local/source` call graph does **not** have `FUN_00534BF0 @ 0x534BF0` calling
`FUN_0052F030 @ 0x52F030`; that function's own post-load sequence rebuilds map
caches and invokes `FUN_004AFEF0`, `FUN_005636B0`, and the `FUN_005AD*` passes
without a direct `FUN_0052F030` edge. The generic repair routine is instead
called by `FUN_0053D100 @ 0x53D100`, which is reached from the CHD/mission-load
sequence `FUN_0043ABF0 @ 0x43ABF0` and by the difficulty-change path
`Diff_Level_at_pctd @ 0x587690`. `FUN_0052F030` walks the existing object list
and recreates only models accepted by `FUN_0052F1D0 @ 0x52F1D0`; its explicit
whitelist is `0x53, 0x59, 0x5A, 0x5B, 0x68, 0x69, 0x6A, 0x7B, 0x81, 0x82,
0x83, 0xD2, 0xE7, 0xE8, 0xFD…0x10C`. It contains none of Well `0x48/0x49`,
Herbalist `0xCF`, or Acupuncture `0xD0`; its `Creating_pctd_type_pctd` calls
therefore cannot be the post-load provider specialization that supplies a
Well-family registry slot. The `0x534BF0`, `0x53D100`, `0x52F030`, and
`0x52F1D0` rows are `identical` in the EN/CH comparison report. This
correction matters for the load boundary: `FUN_00534BF0` is a separate
map-initialization path, while the provider-excluding repair switch belongs
specifically to `FUN_0053D100`.

This negative result narrows the remaining provider `+0x2D` source: it is not
the generic post-load repair pass, even though that pass does perform
model-specific object replacement for other map classes. The archive index
producer, provider-specific conversion trigger, and parent-link registration
remain unknown; Native stays fail-closed.

**Evidence class:** `confirmed` for the call order and complete accepted-model
switch, and `unknown` for any other post-load callback or archive-side provider
creation path.

### 7.3m.1 `FUN_00534BF0` is a separate map-initialization path (confirmed negative, 2026-09-01)

The direct call graph was rechecked to remove an ambiguity in the preceding
subsection. `FUN_00534A30 @ 0x534A30` and `FUN_0042E6A0 @ 0x42E6A0` both call
`FUN_00534BF0 @ 0x534BF0`; the `FUN_00534BF0` body then performs map-dimension,
terrain, object-grid, and route-cache setup. Its relevant calls are
`FUN_004AFEF0`, `FUN_005636B0`, `FUN_0053D630`, `FUN_0053CAE0`,
`FUN_0053CBD0`, and the `FUN_005ADD*` cache passes. None of these calls
directly names `FUN_0052F030`, `FUN_00427150`, `FUN_0051C660`,
`FUN_0051BEF0`, or `FUN_0051CB80`.

The called bodies bound the apparent alternatives. `FUN_004AFEF0` only
rebuilds model `0x70` and objects admitted by the multipart predicate
`FUN_00562F70`; it dispatches `FUN_004B11F0`/`FUN_00563FD0` and has no service
model case. `FUN_005636B0` also filters through `FUN_00562F70` and writes
multipart auxiliary fields `+0x5C/+0x94`, while `FUN_0053D630` only sanitizes
the object-grid index array before invoking map refresh helpers. The
`FUN_0053CAE0`/`FUN_0053CBD0` and `FUN_005ADD*` bodies rebuild bounds and cache
layers; they do not allocate or replace `Building` records. All listed
functions, including the two direct callers, are `identical` EN/CH rows in
`local/source/compare-report.tsv`.

This is a confirmed negative for treating `FUN_00534BF0` as the caller of the
provider-excluding repair switch. Provider reconstruction in the separate
`FUN_0053D100 → FUN_0052F030` path remains excluded for service IDs, while the
`FUN_00534BF0` map-initialization path provides no additional specialization
edge. The archive-side provider index, any indirect/table-driven replacement,
and final registry insertion remain **unknown**; no Native behavior is enabled.

**Evidence class:** **confirmed** for the two `FUN_00534BF0` callers, the
map-cache/object-grid call sequence, and the absence of service constructor or
conversion calls in those bodies; **unknown** for table-driven/runtime edges
outside the recovered call graph and for archive-side provider reconstruction.

### 7.3m.2 `FUN_0053D100` post-load initialization chain has no service specialization edge (confirmed negative, 2026-09-01)

The remaining callees in the `FUN_0053D100 @ 0x53D100` post-load sequence were
read directly rather than inferred from their names. `FUN_005355F0 @ 0x5355F0`
calls `FUN_00535540`, clears global buffers, runs the generic map/grid setup,
then invokes `FUN_0054F050`, `FUN_005AD3F0`, `FUN_00535510`,
`FUN_00535B10`, `FUN_0055D1B0`, `FUN_00592240`, `FUN_00547580`,
`FUN_005AD130`, `FUN_0053BB30`, `FUN_00535960`, `FUN_005C3570`, and
`FUN_005253A0`. The inspected bodies establish only initialization semantics:

* `FUN_00535540` resets runtime subsystems, terrain bounds, and map dimensions;
  it contains no `FUN_0042D360`, `FUN_0051C660`, `FUN_0051BEF0`,
  `FUN_00427150`, or registry insertion call.
* `FUN_0054F050` clamps the difficulty byte to `6`; `FUN_005AD3F0` writes
  ordinal indices into two fixed tables; `FUN_00535510` clears transient
  records; and `FUN_00535B00` clears one object field. None allocates or
  replaces a `Building` record.
* `FUN_005AD130` initializes route/figure table bytes from the authored
  `FUN_005AD200`/`FUN_005AD290`/`FUN_005AD320` helpers. Its switch accepts
  only table indices `0…11` and has no service model-ID dispatch.

`FUN_0053D100` then calls `FUN_0052F030`; the latter's already recovered
`FUN_0052F1D0` whitelist still excludes Well `0x48/0x49`, Herbalist `0xCF`,
and Acupuncture `0xD0`. The EN/CH comparison report marks
`0x53D100`, `0x5355F0`, `0x535540`, `0x54F050`, `0x5AD3F0`, `0x5AD130`,
`0x535510`, and `0x535B00` as `identical`. This closes the apparent
post-load-initialization alternatives in the recovered chain: no inspected
initializer can stand in for the missing provider replacement or registry
registration. The archive provider-index source, any dispatch through an
unindexed table, and the final `+0x2D` parent/list registration remain
**unknown**; Native remains fail-closed.

**Evidence class:** **confirmed** for the inspected callee bodies, call order,
EN/CH identity, and absence of service constructor/replacement calls;
**unknown** for runtime/table-driven edges outside the recovered static graph
and archive-side provider reconstruction.

### 7.3n Building-load callback vtable boundary (confirmed, 2026-08-30)

The vtable dispatch performed by `FUN_0042D790` can be bounded directly from
the canonical EN/CH PE bytes. After `FUN_005F01F0` inserts each decoded
`Building` record, the load path invokes the record's vtable slot `+0xC0`.
For the base `Building` vtable at `0x7AB59C`, slot `+0xC0` is
`FUN_004271B0`. That callback only runs the common active-object hooks
`FUN_0042B6B0`/`FUN_0042B580`; it does not construct a model-specific provider
object. The model-specific provider vtables at `0x7B5EB4` (Well `72/73`),
`0x7B6114` (Herbalist `207`), and `0x7B6374` (Acupuncture `208`) all have
slot `+0xC0 = FUN_0051CB80`. That callback runs `FUN_004271B0`'s common
prelude, then allocates the auxiliary object with `FUN_00526830`, passing the
provider's own `+0x2D` registry index, stores the result at provider `+0x14C`,
and invokes provider slot `+0x1FC`.

The four vtable slices are byte-for-byte the same at these slots in the
canonical EN (`8a6d2df1…6753`) and CH (`dbdeca1e…15a`) executables. This
narrows the unresolved order: a provider-specific vtable must already have
replaced the generic `Building` object before `FUN_0042D790`'s `+0xC0` callback
can reach `FUN_0051CB80`; the base callback cannot itself perform that
replacement. The corpus still does not identify the virtual `+0x18` caller or
the list/registry replacement point, so the archive producer and the source of
the serialized provider `+0x2D` value remain **unknown**. Native remains
fail-closed for this load-time bridge.

**Evidence class:** `confirmed` for the `FUN_0042D790 → vtable +0xC0`
dispatch and all four slot targets/side effects; `unknown` for the
specialization caller, replacement order, archive producer, and parent-link
registration.

### 7.3o Direct-call inventory tightens the specialization boundary (confirmed negative, 2026-08-30)

The canonical EN and CH PE disassemblies were searched for direct calls to the
model factory `FUN_0042D360`, the conversion wrapper `FUN_00427150`, and the
map-load routine `FUN_0042D790`. Both executables produce the same inventory:

| target | direct call sites | static meaning |
| --- | --- | --- |
| `0x42D360` | `0x42715E`, `0x42D714` | the first is inside `FUN_00427150`; the second is inside `FUN_0042D540` (`Creating[...]`) |
| `0x427150` | `0x541113` | `FUN_00541110` only; its containing vtable accepts `-2`, `-1`, and `0x3E…0x46`, not Well/Herbalist/Acupuncture IDs |
| `0x42D790` | `0x52E961`, `0x52EB28`, and the repeated campaign-load call sites `0x52FE5F…0x5335B7` | map/save load entry points |

No other direct `FUN_0042D360` or `FUN_00427150` call exists in either PE's
`.text`. `FUN_0042D790` itself has no direct model-factory call: after generic
`Building` deserialization it dispatches only the current record's `+0xC0`
slot. The `0x541113` caller is `FUN_00541110`, whose vtable is installed by
`FUN_00540770`; `FUN_005418D0` limits that class to the transient/event type
range above, so it cannot be used as the provider replacement path. The only
remaining direct factory path is `FUN_0042D540`, which explicitly creates a
registry entry, writes `object + 0xB4 = registryIndex`, and calls the new
object's `+0x94` initializer; this is the authored construction/creation
mechanism, not a map-load specialization proof.

This is a **confirmed negative** for an omitted direct factory edge, identical
between the two hash-matched builds. It does not rule out an indirect virtual
`+0x18` call or a helper that replaces the list entry without naming
`FUN_00427150`; those indirect edges and the serialized provider-index source
remain **unknown**. Native therefore keeps the provider replacement and
parent-link registration boundary fail-closed.

**Evidence class:** `confirmed` for the complete direct-call inventory and the
transient-class ID filter; `unknown` for any indirect conversion caller,
replacement/list-registration order, and archive-side provider index source.

### 7.3o.1 Load callback does not hide provider specialization (confirmed negative, 2026-09-01)

The generic map loader's callback edge was traced one vtable slot further in
both hash-matched PEs. `FUN_0042D790 @ 0x42D790` obtains each record from
`FUN_0042D0E0 @ 0x42D0E0`, whose descriptor is the authored generic
`PTR_s_Building_00817890`; `FUN_0042B590` then inserts that object into the
building list. For an active record the loader invokes the current object's
vtable `+0xC0` with argument zero. The base `Building` vtable
`0x7AB59C + 0xC0` is `FUN_004271B0 @ 0x4271B0`.

`FUN_004271B0` first calls the object's vtable `+0x150` predicate (the PE
instruction is `call dword ptr [eax + 0x150]`). Direct vtable extraction gives
the same `0x413A00` target for the base `Building` table and the Well,
Herbalist, and Acupuncture tables (`0x7AB59C`, `0x7B5EB4`, `0x7B6114`, and
`0x7B6374`, respectively). `FUN_00413A00 @ 0x413A00` is the two-byte body
`xor al, al; ret`, so this predicate is false for all four classes. The
remaining branch calls `FUN_0042B6B0`/`FUN_0042B580`, which resolves the
common global helper and reinserts through `FUN_0042B590`; it does not call
`FUN_0042D360`, copy a model-specific vtable, assign provider `+0x2D`, or
create a parent link.

The provider-specific `+0xC0` target (`FUN_0051CB80`) is therefore reachable
only after some earlier replacement has installed a provider vtable. The
loader itself supplies no such replacement, and the EN/CH compare rows for
`0x413A00`, `0x4271B0`, `0x42D0E0`, and `0x42D790` are all `identical`.
Combined with the direct-call inventory in §7.3o, this is a confirmed
negative for the hypothesis that the load callback indirectly performs the
missing Qin provider specialization. The replacement/list-registration
caller, serialized provider-index source, and Native projection remain
**unknown**; Native must remain fail-closed.

**Evidence class:** `confirmed` for generic descriptor construction, list
insertion, callback order, vtable targets, and the constant-false predicate;
`unknown` for the pre-callback replacement and archive-side provider index.

The obvious indirect-call candidate `FUN_004E1420 @ 0x4E1420` is separately
bounded as an event/object factory, not the map `Building` conversion. Its
only wrapper is `FUN_004EA050`; callers pass event/FSA type selectors and the
factory allocates a fixed `0x19C`-byte object, invokes that object's `+0xE8`,
`+0xEC`, and virtual `+0x18`, then registers it through the two event lists
returned by `FUN_004E2350`/`FUN_004E2370`. It never calls the object registry
base (`FUN_00413B40`/`FUN_0047F1B0`) or the `Building` conversion wrapper.
Although some event selector values numerically overlap authored model IDs
`0x48/0x49`, the allocation and list-registration chain is distinct from the
`Building` path. The `0x4E1420` callers and EN/CH rows are therefore a
confirmed negative for this candidate; other indirect `+0x18` sites still
require class-context tracing.

### 7.3q Multi-part object rebuild is not a provider specialization path (confirmed negative, 2026-08-30)

The remaining direct caller of `FUN_00563850 @ 0x563850` is
`FUN_0056A0D0 @ 0x56A0D0`; the canonical EN and CH `.text` each contain the
same direct edge at `0x56A124`. `FUN_0056A0D0` dispatches on its model-ID
argument and calls `FUN_00563850` only for the explicit multi-part families
`0x4C…0x54`, `0x5C…0x5D`, and `0xFD…0x10C`. `GameData/Model/EmperorBuildingModels.txt`
identifies these as authored IDs `76…84` (tumulus/temple/canal/vault),
`92…93` (clock tower/grand pagoda), and `253…268` (Great Wall segments).
The provider IDs `72/73`, `207`, and `208` are absent from this switch.

Inside `FUN_00563850`, the existing object's model ID is read from `p[5]`,
its multi-part count is obtained from `FUN_00567610`, and each additional
part is created by `Creating_pctd_type_pctd(p[5], …)`. Therefore this helper
can rebuild only the model family admitted by the caller's switch; it does
not provide an indirect Well/Herbalist/Acupuncture conversion. The function
also has no direct call to `FUN_00427150`, no provider-specific vtable swap,
and no archive-load entry. `local/source/compare-report.tsv` marks both
`0x563850` and `0x56A0D0` `identical` across the two hash-matched builds.

This closes the suspected `FUN_00563850` omission as a **confirmed negative**:
the multi-part/Great-Wall rebuild path cannot supply provider specialization
or its `+0x2D` parent registration. The archive producer, provider-specific
replacement caller, and list/parent registration order remain **unknown**;
Native stays fail-closed for the load-time provider bridge.

**Evidence class:** `confirmed` for the sole direct caller, model-ID switch,
multi-part creation behavior, and EN/CH identity; `unknown` for any other
indirect virtual factory edge and the serialized provider-index source.

### 7.3r The only recovered `+0x3C/+0x3E` parent-link writer is multipart-only (confirmed negative, 2026-08-30)

The parent-link fields read by `FUN_004B3930` are written explicitly inside
`FUN_00563850 @ 0x563850`, but only while rebuilding an admitted multipart
family. The helper first clears the root object's `+0x3C` (`*(undefined2 *)(p +
0xF) = 0`). For each additional part it creates the next registry entry with
`Creating_pctd_type_pctd`, writes the new part's `+0x3C` to the previous
registry index (`local_10`), and writes the previous part's `+0x3E` to the new
child index. This is the concrete writer/reader shape of the short parent and
forward-child chain; it is not merely a field copied by the serializer.

The call is gated by `FUN_0056A0D0 @ 0x56A0D0`. Its complete switch admits
only model IDs `0x4C…0x54`, `0x5C…0x5D`, and `0xFD…0x10C`, the authored
multipart monument/Great-Wall families listed in §7.3q. Provider IDs `0x48`
(Well), `0x49` (Well upgrade), `0xCF` (Herbalist), and `0xD0`
(Acupuncture) have no case and therefore cannot reach this writer. The helper
also has no provider-specific branch; its optional `FUN_00563FA0` follow-up
is invoked only for the same admitted multipart parts and calls their virtual
`+0x18` method.

`local/source/compare-report.tsv` marks `0x563850`, `0x563FA0`, and `0x56A0D0`
`identical` for the canonical EN/CH executables. Therefore the corpus now
provides a confirmed parent-link writer for multipart objects and a confirmed
negative for using that writer as the missing provider registration path. No
other `+0x3C/+0x3E` writer has been tied to a map `Building` provider; the
provider archive-index source, replacement caller, and registration order
remain **unknown**, so Native stays fail-closed.

**Evidence class:** `confirmed` for the multipart `+0x3C/+0x3E` write order,
model-ID gate, and EN/CH identity; `unknown` for any provider-specific writer
outside this excluded family and for the serialized provider-index source.

### 7.3s Map-load call graph contains no virtual `+0x18` specialization edge (confirmed negative, 2026-08-30)

The complete static call sequence around map deserialization was checked after
the multipart writer was separated out. `FUN_0052E7C0 @ 0x52E7C0` calls
`FUN_0042D790 @ 0x42D790` for the building archive, and the latter allocates
generic `Building` records, invokes `FUN_005F01F0 → FUN_005C1670`, then calls
only each active record's virtual `+0xC0` callback. The base `+0xC0` target is
`FUN_004271B0`; it has no model factory call and only performs the active-object
hooks. The provider `+0xC0` target `FUN_0051CB80` is reachable only after a
provider vtable is already installed and consumes the provider's existing
`+0x2D` index.

The two post-load passes reachable from this wrapper were also checked:
`FUN_0052F030` admits models through `FUN_0052F1D0`, whose switch excludes
`72/73/207/208`, and `FUN_004AFEF0` admits model `0x70` or the multipart
predicate `FUN_00562F70`; it then calls `FUN_004B11F0`/`FUN_00563FD0`, not the
conversion slot. `FUN_004B8B10` invokes the same `FUN_004AFEF0` pass and has no
additional provider conversion. `FUN_0042D250` is the object-pool reset and
generic callback setup; it likewise contains no virtual `+0x18` dispatch.

`local/source/compare-report.tsv` marks `0x42D250`, `0x42D790`, `0x52E7C0`,
`0x52F030`, `0x52F1D0`, `0x4AFEF0`, and `0x4B8B10` `identical` in EN/CH.
This is a confirmed negative for a virtual `+0x18` conversion edge in the
recovered map-load/post-load call graph. Other global virtual `+0x18` callers
operate on campaign records, event/FSA objects, multipart parts, or UI/figure
state machines and have not been shown to receive a map-loaded provider. The
provider replacement caller, serialized archive index, and final registry
registration therefore remain **unknown**; Native stays fail-closed.

**Evidence class:** `confirmed` for the inspected load/post-load call graph,
provider-excluding switches, and EN/CH identity; `unknown` for any conversion
edge outside this graph and for the serialized provider-index source.

### 7.3t Xiangjun printable-run probe (superseded by §7.3w, 2026-08-30)

The initial scan of `GameData/Cities/Xiangjun.map` reported printable runs
`Building` at `0x10AFF3`, `cResWall` at `0x10B0B4`, and `cResGate` at
`0x10D1C3`. That scan did not establish record boundaries, and its former
“class-marker/model-slot” interpretation is superseded by §7.3w: the runs
follow the fixed map layers at the `FUN_0042D790` archive transition. The
bytes are retained as a reproducible observation only; they are not enough to
decode object records and do not prove absence of Well/Herbalist/Acupuncture
objects.

The archive-index source, post-load creation order, and Native registry
correspondence remain **unknown**. Native therefore stays fail-closed for
map-loaded providers.

**Evidence class:** `confirmed` for the decoded printable-byte offsets;
`unknown` for their semantics, object-record boundaries, provider index, and
any post-load provider creation.

### 7.3w Xiangjun marker bytes follow the fixed layers at the archive transition (confirmed boundary, 2026-09-01)

The three printable runs reported by the corrected probe have a more precise
location than the earlier wording implied. `FUN_0052E7C0 @ 0x52E7C0` writes
the fixed map layers, including scalar/block fields interleaved between the
byte-sized arrays, and then calls `FUN_0042D790 @ 0x42D790`. Summing those
source-backed writes from `EmperorMap.headerByteCount = 1,535` places that
archive transition at decoded offset `0x10AFE7` for the canonical maps. In
`Xiangjun.map`, `Building` (`0x10AFF3`), `cResWall` (`0x10B0B4`) and
`cResGate` (`0x10D1C3`) therefore occur after the transition, inside the
variable archive candidate, not inside a thirteenth contiguous fixed grid.
No independent count/schema or object-table boundary is recovered from those
strings, so they are not sufficient to identify provider records or model
slots.

This is a **confirmed boundary** for the fixed-layer/archive transition, based
on the serializer ordering and decompressed file bytes. It does not decode the
variable archive or identify the trailing-map payload, nor does it rule out a
post-load provider factory. The archive-index source, replacement caller, and
registry insertion order therefore remain **unknown**; Native stays fail-closed
for map-loaded provider objects.

**Evidence class:** `confirmed` for the fixed-layer/archive boundary and
serializer ordering; `unknown` for archive count/schema, trailing-payload
semantics, and any post-load provider creation path.

### 7.3x Xiangjun archive transition and final auxiliary grid (corrected, 2026-09-01)

The earlier §7.3x claim that decoded offset `0x10AFE7` was the v5 auxiliary
grid was incorrect. It is the fixed-layer/`FUN_0042D790 @ 0x42D790` Building
archive transition; the variable-size archive follows the fixed layers and
precedes the final `DAT_00F2B290` write. The apparent
`01 00 a0 0f 00 00` sequence and printable runs (`Building`, `cResWall`,
`cResGate`) at that offset are consequently archive-candidate bytes, but they
do not yet provide a trustworthy count, schema, or model-slot mapping.

This correction follows the source serializer ordering. `FUN_0052E7C0 @
0x52E7C0` invokes `FUN_0042D790` after the fixed layers and before writing the
format-v5 `DAT_00F2B290` auxiliary grid. In the authored maps, the final
`228*228 = 51,984` decoded bytes are that last write; Native now computes the
offset as `decodedByteCount - 51,984` rather than using `0x10AFE7`. For
`Xiangjun.map` this is `0x1BD25D`, and the authored auxiliary layer is all
zero. The Building archive start is now fixed at the preceding transition;
its per-record lengths and nested-record schema are still not recovered.
`FUN_0042D790` still allocates generic records through `FUN_0042D0E0`, inserts
them, and invokes only the current record's `+0xC0` callback. The
specialization/replacement caller, serialized provider index, and post-load
registry insertion remain **unknown**. Native stays fail-closed for map-loaded
Well/Herbalist/Acupuncture providers.

**Evidence class:** `confirmed` for the auxiliary-grid offset, fixed-layer /
archive transition, and serializer ordering; `unknown` for per-record payload
boundaries, record schema, provider index, and any post-load specialization.
The superseded count/class-marker assertions must not be used as Qin provider
evidence.

### 7.3ae Qin map archive preamble and runtime-class dispatch (confirmed, 2026-09-01)

The archive transition can now be traced one level further without guessing
record payloads. `FUN_0042D790 @ 0x42D790` first calls `FUN_0041FC10`, which
reads the archive schema WORD. For schema `1` it calls `FUN_0042DC20 @
0x42DC20` to read the following raw DWORD slot count, then creates one generic
`Building` descriptor per slot through `FUN_0042D0E0`. That descriptor calls
`FUN_0077FD90 @ 0x77FD90`; its `FUN_0077FFC8` helper consumes the MFC object
tag, resolves a class name through `FUN_007802FE`, and invokes the resolved
class serializer. The EN/CH comparison rows for `0x42D790`, `0x42DC20`,
`0x427430`, `0x77FD90`, `0x77FFC8`, and `0x7802FE` are all `identical`.

The decoded Qin maps agree with this preamble. At `0x10AFE7` the bytes are
`01 00 a0 0f 00 00 ff ff`: schema `1`, slot count `4,000`, then the first
MFC new-class tag. The first class-name record begins six bytes into the
archive and is `Building` (`0x10AFF3`). `Haunxian.map`, `Xianyang.map`,
`Xiangjun.map`, and `Badaling.map` all carry this same preamble. This closes
the archive transition, schema, slot count, and class-dispatch path; it does
not recover the per-class payload schema, provider `+0x2D` index, or the
post-load specialization/registry insertion. Native therefore records these
fields as research evidence only and keeps map-loaded Qin providers
fail-closed.

**Evidence class:** `confirmed` for schema/slot-count/tag dispatch and EN/CH
identity; `unknown` for per-record payload boundaries, provider index, and
post-load registration.

### 7.3af First generic-record lengths are versioned (confirmed, 2026-09-01)

The first `Building` record can be bounded without assigning names to its
serialized fields.  The class declaration starts at decoded offset
`0x10AFED`; its MFC header is 14 bytes (`0xFFFF`, class schema `0`, name
length `8`, and `Building`).  The following two bytes at `0x10AFFB` are the
`FUN_0041FBF0` object schema.  In `Xiangjun.map` they are `03 00`.  The
`ret == 3` read branch of `FUN_00427430` consumes 157 bytes, and the common
tail after the schema branches consumes `+0xB4` (4 bytes) and `+0xB8` (16
bytes), for 177 generic payload bytes.  Including the two-byte object schema,
the first record is therefore 179 bytes; the next class declaration begins at
`0x10B0AE`, exactly 193 bytes after the class-header start.

The other Qin maps in this set (`Haunxian.map`, `Xianyang.map`, and
`Badaling.map`) carry `04 00` at the same object-schema position.  Their
`ret == 4` branch consumes 159 bytes before the same 20-byte common tail, so
their first record is 181 bytes after the schema and the next class declaration
starts at `0x10B0B0` (195 bytes after the class-header start).  The decoded
bytes at these boundaries are stable across repeated reads; EN/CH rows for
`FUN_00427430` and all archive helpers used here are `identical`.

This closes the first-record byte boundaries and demonstrates that the archive
uses versioned generic `Building` payloads.  It does **not** identify the
meaning of the zero/default fields in the first record, the later class
payloads, a provider `+0x2D` source, or the specialization/registry callback;
those remain `unknown`, so Native must not convert these offsets into building
IDs, providers, or house coverage.

**Evidence class:** `confirmed` for the two schema-specific lengths, common
tail, class-header boundaries, and map-byte locations; `unknown` for field
semantics and all provider/post-load mappings.

### 7.3ag Qin service-class marker negative is regression-tested (confirmed, 2026-09-01)

The explicit class-name scan is now guarded by
`EmperorCoreTests.testQinMapsHaveNoExplicitServiceClassMarkerInBuildingArchive`.
For each of `Haunxian.map`, `Xianyang.map`, `Xiangjun.map`, and `Badaling.map`,
the decoded bytes are searched for the complete marker set `Well`, `cWell`,
`Herbalist`, `cHerbalist`, `Acupuncturist`, `cAcupuncturist`, and `cMarket`.
All seven markers are absent in every map.  The test uses the same
`SierraChunkedFile` decode path as the archive-offset tests, so it covers the
entire decoded file rather than only the fixed-layer boundary.

This is a negative result about explicit MFC/class-name records only.  It does
not prove that service objects are absent: ordinary buildings may carry a
generic `Building` tag, or a later runtime/table dispatch may specialize and
register them.  The EN/CH decompilation rows for the loader and class-dispatch
helpers remain `identical`; no direct provider-constructor edge is recovered.
Consequently this evidence tightens the fail-closed rule (do not synthesize a
Qin provider from a class-name search) while leaving the serialized provider
index, replacement caller, post-load registry insertion, and Native projection
**unknown**.

**Evidence class:** `confirmed` for the complete marker set and four-map scan;
`unknown` for generic-record service semantics and any indirect/table-driven
provider creation.

### 7.3ah Qin archive class inventory and raw type-word cross-check (confirmed bytes, inferred field role, 2026-09-01)

The MFC stream can be inventoried without interpreting the generic records as
providers.  After the common schema-1 / 4,000-slot preamble, the four maps
contain these complete new-class declarations (class-name offsets are decoded
file offsets):

| map | MFC class declarations | object schema | first base type word at class-name-end + 16 |
| --- | --- | ---: | ---: |
| `Xiangjun.map` | `Building` (`0x10AFF3`), `cResWall` (`0x10B0B4`), `cResGate` (`0x10D1C3`) | 3 | `0`, `90`, `105` |
| `Haunxian.map` | `Building` (`0x10AFF3`), `cMonumentBldg` (`0x10B0B6`), `cIndustrialBldg` (`0x10DA6A`) | 4 | `0`, `83`, `173` |
| `Xianyang.map` | `Building` (`0x10AFF3`), `cIndustrialBldg` (`0x10B0B6`) | 4 | `0`, `173` |
| `Badaling.map` | `Building` (`0x10AFF3`), `cMonumentBldg` (`0x10B0B6`), `cFillBldg` (`0x10F3DB`) | 4 | `0`, `257`, `94` |

The offsets above are the start of the printable class name; each declaration
has the MFC new-class header `FF FF 00 00`, a little-endian name length, the
ASCII name, and the following object-schema WORD.  A second scan accepts any
class-table WORD (the `FUN_007802FE` reader does not require it to be zero) and
finds no additional valid printable declarations before the trailing grid.
The type-word position is
the same base-building position recovered by the existing `cMonumentBldg`
parser (`class-name-end + 16`); the table records the raw WORD only.  Its
interpretation as a building/model ID is **inferred** from the independently
recovered monument rows and must not be used to manufacture a provider or
house-coverage object.

The recurring existing-class tokens reinforce the boundary: `0x8001` records
use the generic `Building` serializer (schema 3 in Xiangjun, schema 4 in the
other three maps) and their base type words are zero in the decoded records;
`0x8003` repeats the wall/monument-family payload with fixed map-specific
spacing.  This is a byte-level observation, not proof that the generic slots
are the only buildings or that the specialized classes cover every runtime
object.  The provider `+0x2D` source, replacement caller, and post-load
registry insertion remain **unknown**; Native therefore continues to reject
map-loaded Qin service providers rather than converting these words.

**Evidence class:** `confirmed` for the class inventory, schema words, offsets,
and raw type-word values (regression-tested in
`testQinBuildingArchiveClassInventoryAndFirstTypeWords`); `inferred` for the
base type-word/model-ID correspondence; `unknown` for generic-record
semantics, provider registration, and any indirect table dispatch.

### 7.3ai Provider-looking object reinsertion is not a map-load bridge (confirmed, 2026-09-01)

`FUN_005C89F0 @ 0x5C89F0` is a tempting false lead because it scans the active
object vector (`FUN_00413B40(1)`), checks the object's model word at `+0x14`,
and calls `FUN_0042B580` for model IDs `0x7C`, `0xD6`, `0x47`, `0x48`, `0x7F`,
`0xCF`, and `0xD0`.  The latter is only the common vector insertion path
(`0x42B580 → 0x42B590 → 0x5F01F0`); it does not allocate a provider, assign
provider `+0x2D`, or install a specialized vtable.

The complete direct-call search in the merged function tree contains one
caller only: `Spy_has_been_killed_at_city_pctd @ 0x444610`, where the helper is
used after `getPNSStr`/`FUN_004F8A60` while selecting a target for the spy-kill
event.  There is no call from `FUN_0042D790`/`FUN_0042D0E0`, `FUN_00534BF0`, or
the `FUN_0053D100` map/post-load chains.  The EN/CH comparison row for
`0x5C89F0` is `identical`.

This is a confirmed negative for promoting the model-ID whitelist to the Qin
map-load provider bridge.  The serialized provider index, any indirect/table
dispatch, and the actual post-load specialization/registry insertion remain
**unknown**; Native must continue to leave map-loaded Qin service providers
fail-closed.

**Evidence class:** `confirmed` for the body, whitelist, sole direct caller,
callee chain, and EN/CH identity; `unknown` for all map-load provider
registration semantics.

### 7.3aj Qin generic `Building` records contain no non-zero base model word (confirmed, 2026-09-01)

Using the recovered archive transition and the generic serializer's packed
field order, the complete `0x8001` record scan finds only zero base-model words
at stream offset `+18` (four-byte stream header plus the packed object
`+0x14` field).  The counts
are `3,956` in `Xiangjun.map`, `3,962` in `Haunxian.map`, `3,998` in
`Xianyang.map`, and `3,906` in `Badaling.map`; the scan is regression-tested by
`EmperorCoreTests.testQinGenericBuildingArchiveRecordsKeepZeroBaseTypeWord`.
The `+2` object-schema words are `3` for Xiangjun and `4` for the other three,
matching the versioned serializer branches.

This closes a specific false lead: a Qin service ID cannot be recovered by
reading the generic `Building` records' base-model field.  The non-zero model
words observed in these archives belong to the separately declared
`cResWall`/`cResGate`, `cMonumentBldg`, `cIndustrialBldg`, and `cFillBldg`
families already inventoried above.  The zero value does not prove that the
generic slots are absent at runtime or that no later table dispatch exists;
the provider index, specialization caller, and registry insertion remain
**unknown**, so Native must not synthesize service providers from these slots.

**Evidence class:** `confirmed` for all four counts, schema words, and zero
field values; `unknown` for generic-slot runtime meaning and provider
registration.

### 7.3aj.1 Qin generic records never enter the `+0xC0` load callback (confirmed, 2026-09-03)

The packed generic-record scanner now also exposes object `+0x04`, the first
one-byte field emitted by `FUN_00427430 @ 0x427430`, and raw object `+0x10` at
packed stream offset `+14` (the field used as a linear map-cell word by the
specialized Xiangjun barrier records).  `FUN_0042D790 @ 0x42D790` tests the
`+0x04` byte (`local_18[1]`) before dispatching the current object's vtable
`+0xC0` callback.  A complete scan of the four canonical Qin city archives
finds `+0x04 == 0` and raw `+0x10 == 0` in all 3,956 Xiangjun, 3,962 Haunxian,
3,998 Xianyang, and 3,906 Badaling generic records.  The result is regression-tested
by `EmperorCoreTests.testQinGenericBuildingArchiveCatalogMatchesRecoveredRecordLayout`.

This is a confirmed negative for the hypothesis that the serialized generic
records themselves trigger `FUN_004271B0`/`FUN_0051CB80` during the loader's
record loop, and it confirms that these records do not carry the specialized
barrier-style linear cell word needed for direct coordinate reconstruction.
It does not rule out a separate post-load pass or a runtime table-driven
projection that mutates an object after construction; provider
registration, object identity, and house settlement therefore remain
**unknown**, and Native keeps the Qin provider bridge fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`FUN_0042D790.c`, `FUN_004271B0.c`, the identical EN/CH rows in
`local/source/compare-report.tsv`, the four decoded `GameData/Cities/*.map`
archives, `Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and
the focused regression named above.

**Evidence class:** **confirmed** for the serialized zero eligibility bytes,
loader gate, record counts, and EN/CH parity; **unknown** for any separate
post-load/table-driven object projection and all provider/house settlement.

### 7.3am Xiangjun specialized barrier records preserve object slots (confirmed, 2026-09-01)

The specialized `cResWall`/`cResGate` runs provide a second, independent
check on the common Building registry field. `FUN_00415AE0 @ 0x415AE0` and
`FUN_00416490 @ 0x416490` both call `FUN_0051CE00 → FUN_00427430`; in the
schema-3 common serializer the `+0xB4` DWORD is emitted 143 bytes after the
stream model word (`+0x14`). The authored Xiangjun records therefore decode
to `1…27` for the 27 `cResWall` objects, followed by `28…43` for the 16
`cResGate` objects. This is now exposed as
`OriginalResidentialBarrierMapState.serializedRegistryIndex` and regression-
tested against the complete `1…43` sequence.

The slot sequence is consumed as an object-vector index by the specialized
load lifecycle: `FUN_0051CB80` passes object `+0xB4` to `FUN_00526830`, whose
auxiliary constructor stores it at `+0x14`; `FUN_00418D90 → FUN_00418E80`
then calls `FUN_0047F1B0(auxiliary + 0x14)` and dereferences that vector
entry. The object-vector-slot meaning is therefore **confirmed** for these
records. It does **not** identify a Well/Herbalist/Acupuncture provider: the
generic Qin `Building` records carry `+0xB4 == -1`, and no map-load caller to
the service factory or provider-slot writer has been recovered. The Native
catalog consequently keeps this field read-only and does not register the
barrier objects or use their slots for migration/water coverage.

**Evidence class:** `confirmed` for the serializer call chain, schema-3
offset, authored slot bytes/order, and the auxiliary-to-object-vector read
chain; `unknown` for auxiliary semantics, provider specialization, and Native
registry projection.

The same schema-3 records expose the common object byte at `+0x07`, eleven
bytes before the stream model word. `FUN_0042A5A0 @ 0x42A5A0` reads that byte
as the square side `n` for its `n×n` object-grid writer. Every Xiangjun
`cResWall`/`cResGate` record stores `n = 1`, confirming one-cell authored
occupancy geometry for these barriers. This does not recover the runtime
registry allocation, render orientation, or post-load collision registration;
Native keeps the evidence read-only.

The serialized map-cell word in each of those records also equals
`10076 + y×0xE4 + x`. That is the selected Xiangjun 140×140 runtime
descriptor (`DAT_0101D0C8 = 10076`, row stride `0xE4`) used by the writer's
linear-cell arithmetic. The coordinate-to-cell projection is therefore
confirmed for this authored run; the registry-owned object ID and the later
collision-grid stores remain unknown.

**Evidence class:** `confirmed` for the `+0x07` field position, writer
consumer, all 43 authored values, and the map-base/stride relation; `unknown`
for the live registry/grid projection and collision side effects.

### 7.3am.1 Xiangjun connected callback writer inputs (confirmed, 2026-09-04)

The specialized vtables route post-load `+0x1C8 → FUN_00415AD0` to
`+0x270 → FUN_004153B0(0, 0)`. For the only two model IDs present in
`Xiangjun.map`, the selector bodies are exact: model `90` (`0x5A`) satisfies
`FUN_00415740` and writes terrain overlay `0x48`; model `105` (`0x69`) fails
that test, satisfies `FUN_00415770`, and writes overlay `0x08`. Both vtables'
`+0x268` slot calls `FUN_004E1C40 @ 0x4E1C40`, whose EN/CH body returns `1`;
the callback then ORs bit `0x04` into `DAT_00F37DA0[object+0x10]`, where the
serialized `+0x10` field is the map-cell index (distinct from the `+0xB4`
object-vector slot).

This closes the exact writer inputs and raw state-bit transition for the
authored barrier run. It does not recover the semantic meaning of that bit,
runtime orientation, or a legal Native route/collision projection, so the
implementation remains read-only.

**Sources:** `FUN_004153B0.c`, `FUN_00415740.c`, `FUN_00415770.c`,
`FUN_004E1C40.c`, `FUN_004B72B0.c`, identical EN/CH rows in
`local/source/compare-report.tsv`, and
`Sources/EmperorCore/ResidentialBarrierArchiveCatalog.swift`.

**Evidence class:** `confirmed` for model branch, overlays, completion target,
return value, and state-bit write; `unknown` for bit semantics and Native
collision/route projection.

### 7.3an Map-load `vtable +0x18` scan does not reveal a service-object bridge (confirmed negative, 2026-09-01)

The remaining hypothesis was that the generic `Building` archive records are
converted to Well/Herbalist/Acupuncture objects by an indirect virtual call
that does not appear as a direct `FUN_00427150` caller. Both canonical PE
files were disassembled with the `.text` virtual-address mapping
(`VA 0x401000`, raw pointer `0x1000`) and every `call dword ptr [reg+0x18]`
site was mapped back to `functions-index.csv`. The EN and CH instruction
bytes are identical at every site in the map-load address band
`0x520000..<0x540000`:

| site | containing function | recovered role |
| --- | --- | --- |
| `0x52325C`, `0x5234E7` | `FUN_00522D30` | figure/route action creation; initializes a newly-created figure object, not a map `Building` |
| `0x53B05C`, `0x53B124` | `FUN_0053B000` | UI/campaign state predicate over objects returned by `FUN_004F8210`; no archive read, object factory, or provider-registry write |

The map-load and post-load functions themselves (`FUN_0052E7C0`,
`FUN_0042D790`, `FUN_0042D0E0`, `FUN_0052FDA0`, `FUN_00534BF0`,
`FUN_0053D100`, and `FUN_0053D630`) contain no `+0x18` indirect call. The
only direct `FUN_00427150` caller in the merged corpus is
`FUN_00541110`; its body immediately copies cart state at `+0x158`, so it is
not a map-load conversion path. `FUN_0042D790` instead allocates each
archive object through the MFC `Building` class factory, inserts it through
`FUN_0042B590 → FUN_005F01F0`, and invokes the object's `+0xC0` callback. No
caller in that chain reaches the Well/Herbalist/Acupuncture factory
(`FUN_0042D360 → FUN_0051C660 → FUN_0051BEF0`) or writes provider index
`+0x2D`.

This is a confirmed negative for the indirect-`+0x18` conversion hypothesis,
not proof that a table-driven or data-driven bridge cannot exist elsewhere.
The serialized provider index, any non-virtual dispatch, and the post-load
registry projection remain **unknown**. Native therefore keeps Qin service
provider reconstruction fail-closed; no model-ID or generic-record shortcut
is justified by this scan.

**Evidence class:** `confirmed` for the exhaustive EN/CH call-site inventory
in the map-load band, containing-function classification, and direct-caller
negative; `unknown` for unindexed table/data dispatch and runtime-only paths.

### 7.3p Building-side water status is a separate projection (confirmed, 2026-08-30)

The phase-`0x1C` helper `FUN_004ACE30 @ 0x4ACE30` has only two callees:
`FUN_005177B0` (the active-building iteration setup) and
`FUN_005179B0 @ 0x5179B0`. The latter operates on the live `Building` object
returned by each registry entry (`p = *src`), not on the `cHouseInfo` pointer
returned by vtable `+0x1E4`. For each eligible, populated object it clears
building bytes `+0x39` and `+0x43`, then reads the target `cHouseInfo` through
`+0x1E4` and projects the two `cHouseInfo` water bytes into **building**
`+0x39`:

```text
building +0x39 = 0
if cHouseInfo +0x32 != 0: building +0x39 = 1
if cHouseInfo +0x34 != 0: building +0x39 = 2
```

The second assignment has precedence when both `cHouseInfo` bytes are
nonzero. `Not_over_a_building @ 0x5BCAD0` confirms the object domains: it
prints `building +0x39` as the compact service status, reads `building +0x43`
for the alternate “well supply” diagnostic, and separately reads
`cHouseInfo +0x32/+0x34` only through the provider callback path. The direct
phase caller and both EN/CH function rows are identical in
`local/source/compare-report.tsv` (`0x4ACE30`, `0x5179B0`, `0x5BCAD0`).

This closes a previously ambiguous pointer-domain boundary: the compact
`+0x39` status used by the building inspector is not a third `cHouseInfo`
water byte. Native's single `.water` coverage bit therefore cannot stand in
for this projection, and the `+0x43` diagnostic writer/consumer remains
unrecovered. Keep the building-status projection and its `+0x43` branch
unsupported until the provider/object bridge and the remaining writer are
represented.

A bounded corpus search for direct assignments further narrows that unknown:
within the confirmed `Building` paths, `0x5179B0` only clears `+0x43` and
`0x426EA0`/`0x52F710` only copy it. The other apparent nonzero `+0x43`
assignments resolve to unrelated manager/auxiliary structures (for example,
`0x4FC950` writes an emissary-record field), so they do not establish a
provider or well-supply writer. This is a negative result, not proof that an
indirect virtual writer does not exist.

The recovered assignment order is mirrored as the pure
`OriginalWaterProviderState.buildingWaterStatus(primary32:secondary34)`
research helper and regression test. It is deliberately not called from the
live simulation: without the unresolved provider/object registry bridge, doing
so would fabricate the source of either byte and would not reproduce Qin's
water coverage.

**Evidence class:** `confirmed` for the phase caller, pointer domains, and
assignment order; `unknown` for the semantic label of building `+0x43`, its
writer, and the Native registry/object equivalent.

### 7.3z Direct `Building +0x43` writer search is negative (confirmed boundary, 2026-08-31)

The indexed EN/CH corpus was searched for every direct store using the
`Building` object domain established by `0x5179B0` and `0x5BCAD0`. The only
simulation-phase store is the clear in `FUN_005179B0 @ 0x5179B0`; its
constructor/reset path `FUN_004909D0 @ 0x4909D0` also initializes the byte to
zero. `FUN_00426EA0 @ 0x426EA0` and `FUN_0052F710 @ 0x52F710` copy the byte
between serialized/working records; neither computes a non-zero value.
`FUN_005501B0 @ 0x5501B0` persists the byte, but is a serializer rather than
its producer. All four rows are `identical` in
`local/source/compare-report.tsv` where present (`0x5179B0`, `0x4909D0`,
`0x426EA0`, `0x5BCAD0`), and the `0x52F710` copy is reached from the save
version branch in `FUN_0052FDA0`, not from the building simulation phase.

Other textual `param[0x43]` assignments in the corpus resolve to unrelated
manager, networking, or auxiliary structures; no direct caller passes a
Well-family provider into one of those bodies. This is a **confirmed negative**
for a recovered direct non-zero `Building +0x43` producer. It does not rule
out an indirect virtual setter or an unindexed table-driven write, so the
inspector's “well supply” value remains `unknown` and Native must not derive
it from `.water` or from provider `+0x6F`.

**Evidence class:** `confirmed` for constructor/reset, simulation clear,
copy/serializer boundaries, and EN/CH identity; `unknown` for any indirect
virtual/table writer and the semantic source of a non-zero value (if one is
reachable in Qin).

### 7.3i One confirmed `+0x6F` writer is an external object-state path (2026-08-30)

The corpus does contain a real write of the Well-family byte, but it is not
reachable from the recovered provider scheduler. `FUN_00511080 @ 0x511080`
receives a candidate map object from `FUN_00511710 @ 0x511710`; that selector
searches the eight neighboring cells around the object referenced by its
controller's `+0x8`, resolves each non-zero `DAT_00FC3750` ID with
`FUN_0047F1B0`, and accepts the first object whose vtable `+0x1D0` and
`FUN_00511B10` filters pass. In `FUN_00511080`'s `switch` case `6`, the
candidate model IDs `0x48` and `0x49` (authored Well-family IDs `72` and `73`)
are the only accepted targets in that case. The body then sets the write value
to `FUN_00511700(6) = 6 << 4 = 0x60` and calls
`FUN_0042AE30(candidate, 0x60)`.

`FUN_0042AE30 @ 0x42AE30` writes `candidate + 0x6F = 0x60` and calls
`FUN_00418680(candidate + 0xB4)`, which resolves the linked object and emits
the associated map-state update. `FUN_00511860 @ 0x511860` is reached from
`TBD_Hit_eHIB_CallTroops @ 0x515800` when the controller global
`DAT_010C6F60` is command value `0x69`; on success that caller applies the
same controller UI/selection flags as the neighboring eHIB commands. The
string table labels this switch family with `Hit eHIB_Patrol`, `Hit eHIB_Halt`,
`TBD: Hit eHIB_CallTroops`, `Hit eHIB_CaptureAnimals`, and `TBD : Hit
eHIB_Dismiss`, but it does not name command `0x69` itself. The EN/CH
comparison rows for `0x42AE30`, `0x511080`, `0x511710`, `0x511B10`,
`0x511860`, and `0x515800` are all `identical`.

A direct global-write search adds a tighter dispatch boundary. In the indexed
corpus, `DAT_010C6F60` is written only by `FUN_005C0E80 @ 0x5C0E80`: after
the input record's `+0x0C` gate, that handler copies the record's `+0x158`
command and `+0x15C` payload into the two globals, sets the record's `+0x155`
handled byte, and invokes its `+0x14C` or `+0x150` callback under the
controller-state gates (`DAT_010DE070`, `DAT_010DE063`, `DAT_010DE064`). No
monthly/calendar function directly stores this command global. This is a
**confirmed negative** for a recovered simulation-phase writer; indirect
table/vtable stores and the upstream input record remain **unknown**. The
`0x5C0E80` EN/CH compare row is `identical`.

This closes **one writer and value** for provider bytes `+0x6F` (`0x60`) and
proves that the predicate's second input can be changed by an object-state
path targeting Well IDs. The dispatch command value (`DAT_010C6F60 == 0x69`)
and its caller are confirmed, but the command's human-facing meaning, user
gesture/event source, cadence, whether every write reaches a live provider,
and the other indirect stores found by the corpus scan remain **unknown**.
Native must not invoke this writer or treat `+0x6F = 0x60` as a water-ready
condition without the missing trigger and object-registry contract.

**Evidence class:** `confirmed` for the case-6 model filter, constant value,
write helper, linked-object side effect, command-value caller, and EN/CH
identity; `unknown` for the command's human-facing semantics, user/event
source, reachability in Qin-3, and remaining indirect writers.

### 7.3i1 The generic writer has five call instructions and four non-water domains (2026-08-30)

The preceding subsection isolates the Well-family branch, but the same
`FUN_00511080 @ 0x511080` body has a wider model dispatch. `FUN_00511700 @
0x511700` is exactly `return param << 4`; it has no table lookup or additional
scaling. `FUN_0042AE30 @ 0x42AE30` is the only direct callee that stores the
candidate byte (`candidate + 0x6F`) and then calls `FUN_00418680(candidate +
0xB4)`. The EN and CH rows for all three functions are `identical` in
`local/source/compare-report.tsv`.

The five direct call instructions in the canonical EN body are
`0x51111F`, `0x51114E`, `0x5114F8`, `0x51153C`, and `0x511558`. Their model
domains and exact monotonic writes are:

| Call instruction(s) | Controller case / model IDs | Authored model names | Encoded write |
| --- | --- | --- | --- |
| `0x51111F`, `0x51114E` | case 0 / `0x7C` (124) | Inspector's Tower | `max(current byte, FUN_00511700(6)) = max(current, 0x60)` |
| `0x5114F8` | case 6 / `0x48`, `0x49` (72, 73) | Well; `** unused **` | `max(current, 0x60)` |
| `0x5114F8` | case 7 / `0x7F` (127) | Watchtower | `max(current, 0x60)` |
| `0x5114F8` | case 10 / `0xDC`, `0xDD`, `0xDF`, `0xE0`, `0xE1` (220, 221, 223, 224, 225) | Crossbow, Infantry, Catapult, Cavalry, Chariot Fort | `max(current, 0x60)` |
| `0x51153C`, `0x511558` | case 11 / `0x38`, `0x3A` (56, 58) | Trading Quay; Trading Station | `max(current byte, FUN_00511700(3)) = max(current, 0x30)` |

The model names and IDs above are read from
`GameData/Model/EmperorBuildingModels.txt` (rows 56, 58, 72, 73, 124, 127,
220, 221, 223, 224, 225). The shared tail at `0x5114F8` is reached after
case-6, case-7, or case-10 dispatch; it is one instruction, not three
independent writer implementations. The byte is zero-extended before the
comparison (`mov al, [candidate+0x6F]`), so although the branch mnemonic is
signed `jle`, its ordering is equivalent to unsigned ordering for the observed
`0…255` byte domain. The high value is preserved rather than reset.

`FUN_00511710 @ 0x511710` supplies the candidate by scanning eight offsets in
the fixed order `[-0xE4, -0xE3, +1, +0xE5, +0xE4, +0xE3, -1, -0xE5]` from the
controller-referenced map cell. It resolves each non-zero object through
`FUN_0047F1B0`, rejects objects whose vtable `+0x1D0` reports active or whose
`FUN_00511B10` model/controller filter fails, and returns the first survivor.
`FUN_00511860 @ 0x511860` calls this selector and then `FUN_00511080`; its only
recovered caller is `TBD_Hit_eHIB_CallTroops @ 0x515800`, command global
`DAT_010C6F60 == 0x69`. The command handler's adjacent string table labels
the neighboring eHIB commands but does not name `0x69`; no Qin-specific
cadence or simulation-phase caller is recovered in the generated source
corpus.

This expands the negative boundary rather than closing water semantics:
`+0x6F` is a shared monotonic object-state byte used by military, trading, and
Well-family candidates, while the writer's command meaning, event source,
frequency, and relationship to a live provider remain `unknown`. Native must
not project these writes into water coverage or invoke them during Qin
simulation without the missing controller/object-registry contract.

The confirmed Well case-6 value and monotonic update are also exposed as the
research-only `OriginalWaterProviderState.raisedWellCommandState` helper
(`wellCommandStateValue == 0x60`). It preserves an existing byte above `0x60`
and does not imply that the unresolved command trigger is active in Qin.

**Evidence class:** `confirmed` for the five call instructions, dispatch model
sets, encoded values, helper bodies, candidate scan order, and EN/CH identity;
`unknown` for the semantic meaning of the byte outside the already documented
consumer predicates, command/event cadence, and Qin reachability.

### 7.3i2 `FUN_005E5CA0` is a virtual figure-motion flag writer, not a provider source (2026-08-30)

The corpus contains another direct `+0x6F` writer at
`FUN_005E5CA0 @ 0x5E5CA0`. Its EN/CH row is `identical`, but the split corpus
has no direct caller or vtable label for this address. The body is coupled to
figure-motion state rather than provider storage: it reads a figure index at
`+0x6A`, uses movement/grid fields `+0x19`, `+0x1C/+0x1E`, `+0x28`, and
`+0x41`, and delegates to figure slots `+0x1E8`, `+0xF0`, `+0x128` plus the
route helpers `0x4E47A0`, `0x4E8A30`, `0x4EA610`, and `0x4EA3B0`. Its direct
writes are lifecycle transitions—clearing `figure+0x6F` before a route
attempt, setting it to `1` on the successful return/arrival path, and leaving
it clear on failure—alongside state bytes `+0x10`, `+0x19`, `+0x3E`, and
`+0x6D`.

Because no recovered edge passes a Well/Herbalist/Acupuncture provider into
this virtual body, these writes cannot be promoted to the water provider's
`+0x6F` source. They do, however, explain why a corpus-wide assignment search
finds additional `+0x6F` stores outside `FUN_00511080`. The receiver class,
dispatch slot, trigger, and relationship (if any) to a live Qin provider stay
**unknown**; Native must not reuse this figure flag as water coverage.

**Evidence class:** `confirmed` for the direct writer sites, movement-field
access pattern, helper call edges, and EN/CH identity; **unknown** for the
virtual receiver/class and any external caller or provider linkage.

### 7.3i3 Generic residential-service FSM writes a figure flag, not provider water (2026-08-31)

The remaining direct writer in the residential-service family is
`FUN_0051D0C0 @ 0x51D0C0`. Its vtable contract is already established in §5:
tax (`27`), herbalist (`30`), acupuncture (`31`) and religion (`35`) provider
families dispatch their movement slot `+0x24` to this body, while Well (`28`)
uses the separate `0x4E3A80` handler. The function takes the provider as
`param_1` and the roaming figure as `param_2`; all of the fields used by its
state switch (`+0x10`, `+0x19`, `+0x1A`, `+0x3E`, `+0x4A`, `+0x4C`, `+0x6D`)
belong to the figure record initialized by `FUN_004C72B0 @ 0x4C72B0`.

The direct stores are state-machine lifecycle transitions on that figure:

| FSM state / branch | exact store | surrounding operation |
| --- | --- | --- |
| entry and states `1/8` | `figure + 0x6F = 0` | reset heading/budget state, request provider route, then run `0x4E6B70(..., 6)` |
| state `6` | `figure + 0x6F = 1` | decrement `+0x3E`; when the countdown expires, request the provider return route |
| state `7` | `figure + 0x6F = 1` | mark the return interpolation phase before the provider-identity check |
| state `0xC` | `figure + 0x6F = 0` | decrement the return countdown and finish/continue return state |

`FUN_004C72B0` clears the same byte during figure construction. The body only
passes the provider through virtual slots `+0x240/+0x244/+0x23C/+0x238` for
route, heading and identity checks; it never writes a provider object field or
calls the water callback `0x51BC00`. The direct EN/CH comparison row for
`0x51D0C0` is `identical`; its helper rows `0x4C72B0`, `0x4E6B70`,
`0x4E47A0`, and `0x4E8A30` are also identical where indexed.

The other direct `+0x6F` stores found in the same motion/object family are
likewise figure transitions: `FUN_005E5B90 @ 0x5E5B90` sets the flag when a
figure arrives at a linked point, `FUN_004E7460 @ 0x4E7460` / `FUN_004E7520 @
0x4E7520` set or clear it during interpolation, and `FUN_004E8BC0 @ 0x4E8BC0`
stamps current/linked transient objects created by its collision side effect.
Their EN/CH rows are `identical`, and none has a recovered edge into a
Well-family provider record. This is a **confirmed negative** for treating a
generic figure `+0x6F` store as the provider predicate input consumed by
`FUN_005B3AD0`; the provider-side `+0x6F` writer trigger/cadence remains
**unknown**.

**Evidence class:** `confirmed` for the receiver field domain, state-specific
stores, constructor reset, helper/caller edges and EN/CH identity; `unknown`
for the provider-side writer and any indirect vtable/table path that could
change a live provider object. Native must keep the water bridge fail-closed
and must not promote figure `+0x6F` to `.water` coverage.

### 7.3i4 Phase-`0x1F` sentry counter writes a figure flag, not provider water (2026-08-31)

The phase-`0x1F` scheduler call is emitted in the split corpus as
`FUN_00416D20 @ 0x416D20`, reached only from `FUN_004AC2B0 @ 0x4AC2B0` after
its `DAT_00C82EF8` switch. The EN/CH comparison row is `identical`. Its first
pass walks the active object list and, for objects whose model word
`+0x14 == 0x34`, calls virtual slot `+0x1E8` and clears the returned record
byte `+0x5C`. Its second pass scans registry indices `1..<2000`; for an active
object whose figure/model byte `+0x12 == '9'` (the authored figure row 57,
`Sentry (stands in tower)`), it resolves the linked object from figure `+0x62`,
increments that object's `+0x5C` through virtual `+0x1E8`, and checks the linked
object's model word against `0x34`. When that linked record byte exceeds the
global threshold `DAT_00847398`, the function writes **the figure**
`+0x40 = 4` and **the figure** `+0x6F = 1`.

The function therefore contributes another direct `+0x6F` assignment to the
corpus-wide search, but the receiver is the registry figure returned by
`FUN_0047F1B0`, not a Well/Herbalist/Acupuncture provider. Its only provider
side effect is the `+0x5C` counter on the linked model-`0x34` object; it never
calls `FUN_0051BC00`, `FUN_005B3AD0`, or writes provider `+0x6F`. The caller's
phase ordering and the `0x34`/figure-`0x39` gates are directly visible in
`FUN_004AC2B0` and `FUN_00416D20`; no Native water field is implicated.

This is a **confirmed negative boundary** for the remaining water writer
search: phase `0x1F` has a sentry/counter flag path, not a provider-water
writer. The meaning of the model-`0x34` record byte and threshold, and any
indirect/table-indexed writer not present in these functions, remain
**unknown**. Native must keep the provider-side `+0x6F` trigger/cadence
fail-closed and must not map this sentry flag to `.water` coverage.

### 7.3i5 Generic-to-provider conversion preserves `+0x6F` (confirmed, 2026-08-31)

The generic-record conversion path adds a transport boundary that is distinct
from a provider-side writer. `FUN_00427150 @ 0x427150` constructs the
model-specific target through `FUN_0042D360` and then invokes the source
object's vtable slot `+0x0C`. For a generic `Building` source, that slot is
`FUN_00426EA0 @ 0x426EA0`; the copier explicitly assigns
`destination + 0x6F = source + 0x6F` and
`destination + 0xB4 = source + 0xB4`, alongside the other serialized generic
fields. The provider-family copier `FUN_0051CAA0 @ 0x51CAA0` first delegates
to the same generic copy and then copies its provider tail, so an already
specialized provider is also not allowed to silently replace this byte during
that copy operation. The `0x427150`, `0x426EA0`, and `0x51CAA0` rows are
`identical` in `local/source/compare-report.tsv`.

This is **confirmed** evidence that a future map-load specialization caller
could carry a serialized generic `+0x6F` value into a live Well-family object;
it is not evidence for the value's producer, trigger, or cadence. The corpus
still does not identify the caller that applies `vtable +0x18` to a
`FUN_0042D790`-loaded record, nor the generic record's `+0x6F` producer. Native
must therefore preserve the fail-closed water bridge and must not synthesize a
provider flag from `.water` or treat the conversion copy as a recovered
simulation writer.

**Evidence class:** `confirmed` for the conversion call edge, byte/dword copy
offsets, provider-tail delegation, and EN/CH identity; `unknown` for the map
conversion caller, serialized generic-byte producer, and provider-side runtime
trigger/cadence.

### 7.3j Provider `+0x2D` is the runtime object-registry index (confirmed, 2026-08-30)

The object factory closes the field's runtime identity. `FUN_0042D540 @
0x42D540` is the common map-object create/replace path. After constructing the
model through `FUN_0042D360` (which dispatches authored Well ID `72` through
`FUN_0051C660 → FUN_0051BEF0 → FUN_0051C090`), it obtains the registry slot
`FUN_00413B40(param_6)`, stores the new object pointer there, and executes
`p[0x2D] = param_6`. `FUN_00413B40` returns the registry base plus
`param_6 * 4`; `FUN_0047F1B0` uses the same base-plus-index calculation for
lookups. The logged create/replace record also prints `param_6` as the object
index alongside model ID and coordinates.

This is a direct assignment, not a semantic inference: at runtime
`provider + 0xB4` (`+0x2D` dword) is the integer key used by
`FUN_0047F1B0`/`FUN_00413B40` to locate that provider object in the global
object registry. `FUN_004B3930` then follows the object-parent short at `+0x3C`
by repeatedly resolving those registry indices; `FUN_004B38C0` applies the
root-object virtual checks and can return a further object's `+0xB4`. The EN/CH
rows for `0x42D540`, `0x413B40`, `0x47F1B0`, `0x4B3930`, `0x4B38C0`, and
`0x51C660` are `identical` in `local/source/compare-report.tsv`.

The remaining unknown is now narrower: the archive record and post-load code
that choose a particular registry index/parent link for a placed Well, plus
the Native representation of that object registry, are not recovered. The
confirmed identity does not authorize using a Native house ID as a provider
index or bypassing the parent/root checks; the live water bridge remains
fail-closed until that mapping is represented.

**Evidence class:** `confirmed` for the registry base/index arithmetic, factory
assignment, parent-link traversal, and EN/CH identity; `unknown` for the
archive record's index source, post-load registration order, and Native object
registry correspondence.

### 7.3u Player placement proves a free-slot source for new providers (confirmed, 2026-08-30)

The construction dispatcher supplies a separate, closed runtime source for a
newly placed service building. In `FUN_004B1250 @ 0x4B1250`, the ordinary
construction branch calls `Creating_pctd_type_pctd(modelID, x, y, 0, 0)` when
`FUN_005418D0(modelID)` is false. That helper's switch contains `-2`, `-1`, and
`0x3E…0x46`, but not Well `0x48/0x49`, Herbalist `0xCF`, or Acupuncture
`0xD0`; those service IDs therefore reach the common creator. With the final
creator argument zero, `FUN_0042D540 @ 0x42D540` scans for a free object-table
slot, stores the model-specific provider from `FUN_0042D360`, and writes that
slot into provider `+0x2D` (`+0xB4`). `FUN_0042D360` dispatches the service
models through `FUN_0051C660 → FUN_0051BEF0` before the assignment.

This confirms the `+0x2D` source for a player-created provider: it is an
allocator-selected global registry index, not a house ID or a fixed building
model constant. It does not close the load path. `FUN_0042D790` starts from
generic `Building` records, and the only recovered post-load repair pass
(`FUN_0052F030 → FUN_0052F1D0`) excludes the four service IDs. The serialized
index source and any provider-specific replacement/registration after archive
load therefore remain **unknown**; Native must keep Qin's load-time bridge
fail-closed.

**Evidence class:** `confirmed` for the placement branch, provider-ID negative
switch, free-slot allocator path, and provider factory dispatch; `unknown` for
archive-load provider reconstruction and Native registry correspondence.

### 7.3y Provider model factory is closed for explicit creation, not map-load replacement (confirmed boundary, 2026-08-30)

The model factory's service branch can be traced without relying on a
heuristic class name. `FUN_0042D360 @ 0x42D360` first tests house IDs
`2…17` through `FUN_005188B0`. For a non-house model it calls
`FUN_0051C620`; that helper excludes the same house range, the multipart set
recognized by `FUN_00562E80`, and model `0x5E`. The remaining models enter
`FUN_0051C660 @ 0x51C660`, whose `FUN_0051BE30` predicate has exactly four
service cases: `0x48`, `0x49`, `0xCF`, and `0xD0` (authored Well, unused
Well-family, Herbalist's Stall, and Acupuncturist's Clinic). The following
`FUN_0051BEF0` switch allocates `0x150` bytes and installs, respectively,
`FUN_0051C090 → vtable 0x7B5EB4`, `FUN_0051C0B0 → vtable 0x7B6114`, or
`FUN_0051C0D0 → vtable 0x7B6374`; IDs `0x48/0x49` share the first target.
The `0x42D360`, `0x51C620`, `0x51C660`, `0x51BE30`, `0x51BEF0`, `0x51C090`,
`0x51C0B0`, and `0x51C0D0` rows are all `identical` in the EN/CH comparison
report.

That branch is reached by the explicit creator `FUN_0042D540 @ 0x42D540`
after it obtains a free slot with `FUN_00413B40`, stores the returned object,
and writes the slot index into object `+0xB4` (`+0x2D`). The map loader is a
different path: `FUN_0042D790 → FUN_0042D0E0` asks the generic `Building`
descriptor for each record, inserts it, and invokes only the record's current
`+0xC0` callback. The base callback is `FUN_004271B0`; no direct call from
that load path reaches `FUN_0042D360`, `FUN_0051BEF0`, or any provider vtable
constructor. Therefore the service factory is **confirmed** for explicit
creation, while the generic-record replacement trigger, replacement/list
registration order, and serialized provider-index source remain **unknown**.
This is a sharper boundary against wiring the explicit placement factory into
Qin map deserialization; Native remains fail-closed for that load-time bridge.

**Evidence class:** `confirmed` for the model-ID predicate, constructor/vtable
mapping, explicit creator's registry write, generic map-loader allocation and
callback edge, and EN/CH identity; `unknown` for any indirect virtual
`+0x18` caller, archive-side provider index, and post-load replacement order.

### 7.3y.1 Complete direct `FUN_0042D540` call-site census leaves Qin replacement unknown (confirmed negative, 2026-09-01)

The canonical EN and CH PE images were scanned for every direct relative
`E8` call to `FUN_0042D540 @ 0x42D540`. Both images contain the same 21 call
sites: `0x415093`, `0x41586D`, `0x415DCD`, `0x420F0B`, `0x42A63A`,
`0x42A853`, `0x42BAEB`, `0x42BC5D`, `0x4B2461`, `0x4B24C9`, `0x4B2853`,
`0x4C1452`, `0x52F0D1`, `0x540ED2`, `0x542AF4`, `0x542CAD`, `0x543269`,
`0x544C39`, `0x5639E9`, `0x572B6D`, and `0x5E21F3`. The call-site bytes and
the `local/source/compare-report.tsv` rows for the enclosing indexed
functions are EN/CH-identical.

Argument inspection classifies the fixed-model sites as marker/auxiliary
objects (`0xA1`), multipart/market child objects (`0x3E`/`0x47`), terrain
marker `0x5E`, or combat/terrain object `2`; they cannot instantiate a
Well-family provider. The map repair caller at `0x52F0D1` passes an existing
object model through the explicit whitelist in `FUN_0052F1D0`, which excludes
`0x48/0x49/0xCF/0xD0`. The player construction caller at `0x4B1250`
(`0x4B2461`/`0x4B24C9`) is the only call site whose dynamic model argument is
already tied to the construction dispatcher; its service-ID branch is the
placement path documented in §7.3u. The remaining dynamic calls belong to
terrain, map-decoration, or multipart subsystems, and their argument
provenance does not resolve to a serialized service record in the corpus.

This is a **confirmed negative** for an additional direct, statically
identified service-provider replacement caller. It does not exclude an
indirect virtual/table dispatch or an archive-side conversion edge; those
remain the explicit unknowns. Native must not treat any of the 21 direct call
sites as proof of a Qin load-time provider registry mapping.

**Evidence class:** `confirmed` for the complete direct-call address set,
fixed-model exclusions, repair whitelist exclusion, placement caller, and
EN/CH identity; `unknown` for indirect conversion dispatch, serialized
provider-index production, and post-load registration order.

### 7.3v Post-load `+0x9C` is a provider-consistency consumer, not registration (confirmed negative, 2026-08-30)

The city initializer does consume provider virtual state after map objects have
been restored, but the recovered consumer does not create or register a provider.
`FUN_00534BF0 @ 0x534BF0` calls `FUN_004AF230 @ 0x4AF230` after the map dimensions,
terrain rows, and object-list setup. `FUN_004AF230` clears the service/model
counter arrays, walks the object registry through `FUN_00413B40`, and invokes
each active object's vtable slot `+0x9C` when its state byte is `1` or `3`.

The Well, Herbalist, and Acupuncture vtables all point at the same thunk
`0x5B3BB0`, which jumps to `FUN_0051CCA0 @ 0x51CCA0` in both hash-matched
executables. That method increments per-model counts and, for the special model
`0x38`, records up to ten registry indices. Independently, when the object's
parent short at `+0x32` is nonzero, it resolves that short through
`FUN_0047F1B0`, verifies the target's active byte `+0x16 == 1`, and verifies the
target's `+0x68` equals the current object's registry index `+0x2D`; an invalid
link is cleared. The method never calls `FUN_0042D360`, `FUN_00427150`, or a
vector insertion routine, and it never writes the provider `+0x2D` index.

The `+0x9C` slot is polymorphic: the three entertainment school vtables use
the same slot for `FUN_0048AE30`, as established by the pointer arithmetic in
§7.2c.4b. The slot therefore identifies a shared dispatch position, not one
universal provider-registration implementation.

`FUN_004AF230` is also called at the beginning of player construction and during
simulation phases `0x21`, so this pass is a reusable counter/parent-link refresh,
not a map-load-only specialization trigger. The EN/CH comparison rows for
`0x534BF0`, `0x4AF230`, `0x5B3BB0`, and `0x51CCA0` are all `identical`.

This closes the suspected post-load `+0x9C` edge as a **confirmed negative** for
provider registration. It proves that a specialized provider object must already
exist before the city initializer can consume it, while the archive index source,
generic-record replacement caller, and registry insertion order remain unknown.
Native therefore remains fail-closed for Qin's load-time provider bridge.

The field-level tail is now captured by the research-only
`OriginalWaterProviderState.validatedParentShort` helper. It accepts the
already-resolved target fields explicitly and preserves the parent short only
for active byte `1` plus an exact target `+0x68 == provider +0x2D` match; it does
not perform registry lookup or imply that Native has a load-time provider
projection.

**Evidence class:** `confirmed` for the post-load call order, vtable targets,
counter updates, parent-link validation, and EN/CH identity; `unknown` for the
provider specialization/replacement path and serialized registry-index source.

### 7.3k Qin-3 map archive does not expose a service-object index (negative, 2026-08-30)

The authored `GameData/Cities/Xiangjun.map` was decoded with the repository's
`SierraChunkedFile` format (58 zlib chunks, 1,875,309 decoded bytes) and its
MFC/class-name area was scanned before considering any executable fallback. The
class-like printable markers found in the decoded archive are `Building` at
`0x10AFF3`, `cResWall` at `0x10B0B4`, and `cResGate` at `0x10D1C3`; there is no
`Well`, `cWell`, `Herbalist`, `Acupuncturist`, or corresponding service-class
marker. This is a negative result about explicit class-name records, not proof
that the map contains no runtime objects: the executable may encode ordinary
buildings through the generic `Building` class or create providers after map
load.

The result therefore does not identify the serialized value that becomes
provider `+0x2D`, nor the post-load order that registers it in the global object
table. It does, however, rule out treating a named service record in
`Xiangjun.map` as that source. The archive-index source, post-load parent
registration, and Native registry correspondence remain **unknown**; no water
writer is enabled from this scan.

**Evidence class:** `confirmed` for the decoded-byte count and complete
class-like marker search; `unknown` for generic `Building` payload semantics
and any service objects represented without a class-name marker.

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

### 7.4 Appeal propagation shape arrays for multi-cell buildings (2026-08-30)

`FUN_0044CDE0 @ 0x44CDE0` (identical in the English and Chinese hashes)
builds one perimeter array for each radius around footprint sides `2…6`.
The body is a five-loop generator: it emits the top edge from `x=0`, the
right edge, the bottom edge, the left edge, and a final top-left closure while
advancing `n2=-1,-2,…` and the side extent.  This is not the symmetric
`[-radius, side+radius)` rectangle previously used by the Native research
helper.  For example, side 2/radius 1 is the ordered sequence
`(0,-1),(1,-1),(2,-1),(2,0),(2,1),(2,2),(1,2),(0,2),(-1,2),(-1,1),(-1,0),(-1,-1)`;
the side-2/radius-2 array has 20 entries and begins
`(0,-2),(1,-2),(2,-2),(3,-2),(3,-1)…`.

The Native `OriginalAppealPropagationCatalog.squareRingOffsets` now follows
those loop bounds and append/update order exactly, with coordinate-level tests
for both rings.  This closes the generated-array geometry only (`confirmed`);
`FUN_0044ED90` still applies occupancy/sector suppression and writes a shared
appeal buffer whose house-anchor copy is unresolved.  Therefore this correction
does not enable Qin-3 desirability and must not be wired as a complete appeal
simulation.

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
- well-provider `+0x16` setter bodies, phase-`0x24` `+0x218` scheduler call,
  and the recovered `+0x1F8`/threshold/predicate transition formula;
- water callback phase-`0x1C` field reduction, independent `+0x32`/`+0x34`
  tests, and the recovered score contributions `5` and `15`;
- entertainment venue FSM existence at `0x48A9A0`, its state labels and route
  call sites, hard `+0x4C >= 3200` guard, provider spawn threshold methods and
  intervals, exact state-11 terminal predicate `0x4C9950` (`+0x19 ∈ {8,9,10}`),
  selector-8 authored speed dispatch and selector-15 `×96` budget scaling,
  mode-`0x12` flood mask `0x10C`, cardinal-first/full-eight route
  reconstruction (now represented by the Native route primitive) and the
  `0x100 → +0x19=9` collision guard, and provider
  `+0x224` vtable targets (`0x5B3AD0`/`0x413A00`) with their observed `0/1`
  predicate;
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
  bytes is intentionally unsupported in Native's single `.water` requirement;
  both original branches write the confirmed value `0x60`, but their separate
  downstream health consumers require a separate contract. The provider
  predicate's field semantics (`+0x16`, `+0x6F`) and the semantic meaning of
  the global object's `+0x50/+0x54/+0x58` fields remain unknown; the city
  natural-health aggregate is documented in §7.1a but is not yet represented
  in Native.
- objects absent from Native's `ResidentialUnit` / `PlacedBuilding` state
  cannot participate in the recovered object-grid scan. Represented houses and
  all eight residential wall/gate IDs use the recovered predicates. Native has
  no general equivalent of auxiliary byte bit `4`, so the separate
  tree/wall-terrain branch for other original objects stays unsupported rather
  than treating every tree/wall terrain tile as an opaque object;
- entertainment `#32…#34`, watchtower `#29`, inspector `#39`, market peddler
  `#23`, and mid-flight roadblock collision/turn details require their own FSM
  contracts and must not be routed through this generic implementation. The
  entertainment callback's populated-house eligibility is represented in the
  Native coverage projection, but that does not enable the unsupported figure
  state machine.

### 8.1 Object-grid writer geometry is now isolated (confirmed, 2026-08-31)

The shared object-grid writer `FUN_004B72B0 @ 0x4B72B0` is identical in the
canonical English and Chinese executables (`compare-report.tsv`). After the
caller validates the requested rectangle against runtime dimensions, it
computes the cell base as `DAT_0101D0C8 + y×0xE4 + x`. Each row advances through
the six-entry row of `DAT_0081FF18` (the table is therefore six-by-six and
row-major); the first dword is added to that base, while the paired direction
byte is copied to `DAT_00FDCD70`. The writer then stores:

```text
DAT_00F6A9E0[cell] = (previous & 0x93872790) | param_7
DAT_00FC3750[cell] = param_1             // object/registry ID
DAT_00FE9880[cell] = param_6             // auxiliary image/state value
DAT_00F9D620[cell] = preserved-high-bits | (width - 1)
DAT_00FDCD70[cell] = directionByte | 0x40 on one direction-selected corner
```

The corner is `(column 0,row height−1)` for direction `0`, `(0,0)` for `2`,
`(width−1,0)` for `4`, and `(width−1,height−1)` for `6`. These are camera/render
directions controlled by `DAT_0115F720`, not a recovered Native building
orientation. `FUN_004B7520` is a related writer that walks the first dword of
each paired table entry and marks every written cell with `0x40`; it remains a
separate path.

The side-effect-free `OriginalMapObjectGridProjection` primitive mirrors the
closed `0x4B72B0` merge, table indexing, width code, direction byte, and edge
corner. It includes the canonical EN/CH table literals while requiring callers
to supply prior map words. Tests cover row-major indexing, `0xE4` stride,
terrain preservation, canonical paired-byte values, and all unsupported-size/
direction guards. This does **not** enable Qin provider, appeal, or migration
behavior: the Native backing-grid base, object-registry allocation/parent
links, and orientation mapping are still unknown. No live simulation path
consumes this helper.

**Evidence class:** `confirmed` for writer arithmetic, masks, stores, table
shape/indexing, canonical table literals, direction corner selection, and
EN/CH identity; `unknown` for Native backing-grid/registry projection and the
semantic mapping from render direction to building orientation.

### 8.2 MFC class-name dispatch is dynamic (confirmed, 2026-09-01)

The map loader's `FUN_0042D0E0 @ 0x42D0E0` passes the default
`PTR_s_Building_00817890` descriptor into `FUN_0077FD90 @ 0x77FD90`; this does
not by itself prove that every record is a generic `Building`. In the stream
reader `FUN_0077FFC8 @ 0x77FFC8`, the `0xFFFF` class tag calls
`FUN_007802FE @ 0x7802FE`, which reads the serialized class-name length and
bytes, then scans the registered MFC runtime-class list for an exact name.
`FUN_0077FD90` invokes the selected class constructor and its serializer before
returning the object. The loader then invokes the object's virtual `+0xC0`
callback (`FUN_0042D790 @ 0x42D790`).

The EN/CH split-corpus rows for all four functions are `identical`. Xiangjun's
authored archive declares `Building`, `cResWall`, and `cResGate`; the latter
constructors are explicit in `FUN_004143B0 @ 0x4143B0` and install the
specialized vtables through `FUN_00416CB0 @ 0x416CB0` and
`FUN_00416D00 @ 0x416D00`. This closes the class-dispatch mechanism and
explains why the read-only barrier parser must preserve the specialized runs.
It does **not** recover what each class's post-load `+0xC0` callback registers,
how it populates the object grid, or whether any callback specializes a generic
record after construction; those provider/collision/save links remain
**unknown** and Native stays fail-closed.

**Evidence class:** **confirmed** for the class-tag reader, exact-name runtime
lookup, constructor/serializer dispatch, loader callback edge, and Xiangjun
class declarations; **unknown** for post-load callback side effects and Native
registry projection.

### 7.3z Well vtable `+0x224` field-width predicate (confirmed, 2026-08-31)

`FUN_005B3AD0 @ 0x5B3AD0` is a two-input predicate used by the Well-family
vtable at slot `+0x224`. The direct EN and CH bodies are identical in
`local/source/compare-report.tsv` and have the following exact semantics:

```text
return ((signed16)provider[+0x16] > 0) || ((uint8)provider[+0x6F] > 0)
```

The first comparison is a signed word `cmp word [ecx+0x16], 0; jg`; the second
loads a byte and takes the unsigned `ja` branch after `test`. Consequently a
raw `0xFFFF` word is false while byte `0xFF` is true. The predicate is now
represented by the side-effect-free
`OriginalWaterProviderState.providerVTable224Predicate(providerWord16:providerByte6F:)`
with explicit `Int16`/`UInt8` inputs and regression coverage in
`EmperorCoreTests`.

This closes comparison width and signedness only. The provider specialization,
map registry identity, and writers/cadence that supply these fields remain
unknown; Native must not promote the predicate to `.water` coverage or invoke
the command-side `+0x6F = 0x60` writer without those mappings.

**Evidence class:** `confirmed` for predicate instructions, field widths,
EN/CH identity, and pure helper tests; `unknown` for provider object reachability,
field lifecycle/cadence, and Native registry projection.

### 7.3aa Exhaustive indirect `vtable +0x18` caller audit does not reach map loading (confirmed negative, 2026-09-01)

The remaining suspected specialization trigger was audited by searching every
indirect call of the form `(*object->vtable + 0x18)(...)` in the merged corpus,
then reading the caller and its direct registry/object callees. The map-load
chain is `FUN_0052E7C0 → FUN_0042D790 → FUN_0042D0E0`; the loader allocates a
generic `Building`, inserts it, and invokes only the record's current virtual
`+0xC0` callback. No `+0x18` call instruction has a direct caller edge from
`FUN_0042D790`, `FUN_0042D0E0`, `FUN_0052E7C0`, or the surrounding object-archive
read helpers.

The apparent global candidates have different, closed contexts:

* `FUN_005C0490` iterates the already-populated object registry
  (`FUN_004F8210…FUN_004F8200`) and calls each object's `+0x18` only to match a
  requested value; its callers (`FUN_00486950`, `FUN_00486E10`, `FUN_0040D9D0`,
  and `FUN_00586280`) are UI/screen queries.
* `FUN_0055D8E0` calls `+0x18` on UI list/settings objects while drawing or
  updating controls, not on map `Building` records.
* `FUN_004E1420` creates figure-side objects and invokes their virtual slots
  after construction; it has no edge back to the map archive loader.
* `FUN_005B4BD0`, `FUN_005D0D30`, `FUN_00589480`, `FUN_0053B000`,
  `FUN_00515A40`, `FUN_005C6DA0`, `FUN_0054F8D0`, and `FUN_00522D30` are
  campaign/figure/UI/state aggregators. Their `+0x18` operands are reached
  through pre-existing registries or screen state, with no map-load object
  parameter shape and no provider factory/replacement call.

The EN and CH function files were checked for the loader and the relevant
caller families; no variant-specific edge adds a provider constructor,
registry insertion, or generic-record replacement. This is a negative result
about the recovered call graph, not proof that no post-load trigger exists:
the archive-side provider-index source, any indirect dispatch through a table
not represented by these call sites, and replacement/list-registration order
remain **unknown**. Native therefore keeps Qin's load-time water/provider
bridge fail-closed and must not reinterpret a registry-wide `+0x18` query as a
map specialization pass.

**Evidence class:** `confirmed` for the exhaustive corpus search, loader edge,
and caller-context classification; `unknown` for any table-driven or runtime
trigger outside the recovered static call graph, serialized provider index,
and Native registry projection.

### 7.3ab Provider factory model-family map (confirmed, 2026-09-01)

The provider constructor dispatch is now represented as a small, pure Native
catalog. `FUN_0051BE30 @ 0x51BE30` accepts exactly model IDs `0x48/0x49`,
`0xCF`, and `0xD0`; `FUN_0051BEF0 @ 0x51BEF0` routes those cases to
`FUN_0051C090`, `FUN_0051C0B0`, and `FUN_0051C0D0` respectively. The three
initializers install vtables `0x7B5EB4`, `0x7B6114`, and `0x7B6374`. The
EN/CH comparison rows for all five functions are `identical`.

The mapping is corroborated by `GameData/Model/EmperorBuildingModels.txt`:
model `72` is Well, `207` is Herbalist's Stall, and `208` is Acupuncturist's
Clinic. Model `73` is an unused Well-family row in the authored table but is
still accepted by the executable's factory switch and is therefore retained
in the catalog. Native exposes these rows as
`OriginalResidentialServiceCatalog.providerFactoryDescriptors` and keeps the
catalog research-only; it does not assign serialized provider `+0xB4`/`+0x2D`,
insert an object into the registry, or write either house water byte.

**Evidence class:** `confirmed` for the accepted model IDs, initializer
functions, vtable addresses, EN/CH identity, and authored model corroboration;
`unknown` remains for the archive-side provider index, specialization caller,
post-load registration, and coverage writer/cadence.

### 7.3ac Provider constructor direct-call inventory has no second entry (confirmed negative, 2026-09-01)

The service-constructor branch was checked at the raw call-site level so that
the catalog above is not mistaken for an additional map-load path. In both
hash-matched PE images, the only direct relative call to
`FUN_0051C660 @ 0x51C660` is the identical five-byte call at `0x42D3CC`, inside
`FUN_0042D360`. The only direct call to `FUN_0051BEF0 @ 0x51BEF0` is the
identical call at `0x51C71C`, inside `FUN_0051C660`. The three initializer
targets occur only from the corresponding switch cases in `FUN_0051BEF0`:

| target | direct call sites in EN and CH | enclosing branch |
| --- | --- | --- |
| `0x51C090` (Well family) | `0x51B9F2`, `0x51BF45` | `FUN_0051BEF0` cases `0x48/0x49` |
| `0x51C0B0` (Herbalist) | `0x51B962`, `0x51BFA5` | `FUN_0051BEF0` case `0xCF` |
| `0x51C0D0` (Acupuncture) | `0x51B8D2`, `0x51BF75` | `FUN_0051BEF0` case `0xD0` |

`objdump -D -Mintel` emits the same addresses and call bytes for
`Exe/ghidra/input/EmperorEN.exe` and `Exe/ghidra/input/EmperorCH.exe`; the
split-corpus rows for `0x42D360`, `0x51C660`, and `0x51BEF0` are
`identical` in `local/source/compare-report.tsv`. This is a complete direct
constructor inventory, not a claim about indirect table dispatch: there is no
second direct service-constructor caller in the executable text that could be
used as a map-load replacement shortcut.

The result tightens the remaining Qin boundary. Explicit creation still flows
through `FUN_0042D360 → FUN_0051C660 → FUN_0051BEF0`; the generic map loader
still starts at `FUN_0042D790` and invokes only the current object's `+0xC0`
callback. Any archive-side provider specialization would therefore have to be
an indirect/table-driven replacement or an already-specialized serialized
object, neither of which is recovered by this direct inventory. The
serialized provider index, replacement/list-registration order, and Native
registry projection remain **unknown**; no runtime wiring changes.

**Evidence class:** **confirmed** for the complete direct constructor call
inventory, switch-local initializer edges, EN/CH byte identity, and the
separation from the generic map-loader path; **unknown** for indirect/table
dispatch and archive-side provider reconstruction.

### 7.3ad Entertainment provider rotation buckets (confirmed, 2026-09-01)

The venue manager's slot accounting is now closed as a pure state transition.
`FUN_0048EA40 @ 0x48EA40` is the only recovered caller of
`FUN_0048F140 @ 0x48F140`; after the manager refreshes, `FUN_0048CE90 @
0x48CE90` is the only recovered caller of `FUN_0048F420 @ 0x48F420`. The
EN/CH comparison rows for `0x48EA40`, `0x48CE90`, `0x48F140`, and `0x48F420`
are all `identical` in `local/source/compare-report.tsv`.

The refresh scans the active object registry and considers only provider model
IDs `0xD3`/211 (music), `0xD4`/212 (acrobat), and `0xD5`/213 (drama), after
the global/provider virtual gates and positive provider callback have passed.
For each model family, the first accepted provider writes three slots to the
manager field (`+0x2C`, `+0x34`, or `+0x3C`); each later accepted provider
increments that family by one. The total field `+0x40` is the sum of the three
families, and `+0x44` is initialized by the manager's random call in
`FUN_0041FAA0(total)`.

`FUN_0048F420` consumes one slot by strict cursor intervals: cursor `< +0x2C`
returns selector `4` and decrements music; cursor `< +0x2C + +0x34` returns
`5` and decrements acrobat; otherwise it returns `6` and decrements drama. It
then decrements total. If slots remain, the next cursor is
`(randomOffset + previousCursor) % newTotal`; when exhausted it is reset to
zero. The Native primitive
`OriginalResidentialServiceCatalog.EntertainmentProviderRotationState` keeps
these fields and requires the random offset as an explicit input; it does not
invent an RNG stream, provider registry, spawn side effect, or coverage write.
Focused tests cover first-three/unit-increment rebuilding, both strict bucket
boundaries, cursor rotation, and exhaustion.

This closes only slot accounting. Provider admission/selection, venue route and
collision, figure state transitions, coverage settlement, and the call that
refreshes/consumes these buckets remain **unknown**. Consequently figures
32…34 and Qin's venue FSM stay fail-closed in live Native simulation.

**Evidence class:** **confirmed** for the field update formula, strict selector
intervals, total/cursor update, caller edges, and EN/CH identity; **unknown**
for provider registry semantics, random-source identity, and all downstream
venue side effects.

### 7.3ae Qin generic `Building` records serialize an unbound provider slot (confirmed negative, 2026-09-01)

The common serializer's field order gives a direct byte-level check for the
registry slot, without assigning semantics to the other generic payload
words. In `FUN_00427430 @ 0x427430`, the schema-3 and schema-4 read branches
consume their schema-specific fields and then converge on
`FUN_00780533(param_1 + 0xB4, 4)` followed by the 16-byte `+0xB8` tail. The
corresponding generic `0x8001` record lengths are 181 bytes for schema 3
(Xiangjun) and 183 bytes for schema 4 (Haunxian, Xianyang, Badaling), counting
the two-byte stream token. The `+0xB4` field is therefore the first four bytes
of the final 20-byte record tail, not the stream offset `token + 0xB4`.

The decoded authored maps were scanned from the recovered archive transition
`0x10AFE7` to the final auxiliary grid. Every valid generic `0x8001` record has
`FF FF FF FF` at that tail position, i.e. serialized `+0xB4 == -1`:

| map | schema | generic records | non-`-1` provider slots |
| --- | ---: | ---: | ---: |
| Xiangjun | 3 | 3,956 | 0 |
| Haunxian | 4 | 3,962 | 0 |
| Xianyang | 4 | 3,998 | 0 |
| Badaling | 4 | 3,906 | 0 |

`EmperorCoreTests.testQinGenericBuildingArchiveRecordsKeepUnboundProviderRegistrySlot`
locks these counts and tail words using the same `SierraChunkedFile` decode
path as the archive-boundary tests. The EN/CH serializer rows are
`identical` in `local/source/compare-report.tsv`; the archive bytes are the
shipping GameData records, not a runtime-generated approximation.

This is a confirmed negative for using a generic Qin archive record's
serialized provider slot as the missing load-time registry mapping: the
records explicitly carry the constructor default `-1`. It does **not** prove
that no later table/virtual conversion can specialize a record, nor does it
recover the post-load order or an alternate provider-index source. Native must
therefore keep the Qin provider bridge fail-closed and must not substitute a
house ID, record ordinal, or generic token offset for `+0x2D`.

**Evidence class:** `confirmed` for serializer field order, schema-specific
record lengths, all four map counts, and the all-`-1` tail values; `unknown`
for any indirect specialization/replacement dispatch, post-load registration,
and Native object-registry correspondence.

### 7.3ah MFC object-reference helpers do not add a Qin provider registration edge (confirmed negative, 2026-09-01)

The remaining class/slot helpers were traced to distinguish archive object
identity from the missing service-provider registry. `FUN_0077FD90 @ 0x77FD90`
delegates tag decoding to `FUN_0077FFC8 @ 0x77FFC8`; the latter reads the MFC
object token, resolves a class name through `FUN_007802FE @ 0x7802FE`, and
invokes the class factory/serializer selected by that name. `FUN_0077FD11 @
0x77FD11` is the inverse reference writer: it stores an object token in the
archive's reference table and does not inspect building model IDs, provider
IDs, or map coordinates. EN/CH comparison rows for all four helpers are
`identical`.

For the Qin map path, `FUN_0042D790 @ 0x42D790` calls
`FUN_0042D0E0 → FUN_0077FD90` once per schema-1 slot, then inserts the returned
object through `FUN_0042B590 → FUN_005F01F0` and invokes only that object's
vtable `+0xC0` callback. The callback is reached before the loader pads the
vector to 4,000 slots; no call in this path reaches the recovered provider
constructor `FUN_0042D360`, writes provider `+0x2D`, or installs a parent link.
The generic archive records independently carry `+0xB4 == -1` (§7.3ae), so the
MFC reference table cannot be treated as an implicit provider-slot source.

This is a confirmed negative for promoting class-token resolution or vector
insertion into a Qin service-provider bridge. The indirect class factory table,
any post-load specialization caller outside `FUN_0042D790`, and the source of
an eventual non-negative provider index remain **unknown**. Native therefore
must not synthesize service objects from MFC tokens, record ordinals, or the
generic callback; campaign-backed Qin service coverage remains fail-closed.

**Evidence class:** `confirmed` for the object-reference responsibilities,
loader call sequence, vtable callback boundary, and EN/CH identity; `unknown`
for indirect class-factory dispatch, post-load specialization, and provider
registry projection.

### 7.3ai Entertainment provider class dispatch is closed, but archive registration is not (confirmed, 2026-09-01)

The entertainment branch of the model factory can now be separated from the
unresolved map-archive path. `FUN_0051C660 @ 0x51C660` calls
`FUN_0048A7E0 @ 0x48A7E0`, whose admitted range is exactly model IDs `0xD3`,
`0xD4`, and `0xD5` (211, 212, 213). `FUN_0048A800 @ 0x48A800` then allocates
the common `0x150`-byte object and selects the following constructors and
vtables:

| model | family | constructor | vtable |
| ---: | --- | --- | --- |
| 211 (`0xD3`) | music | `FUN_0048A8E0 @ 0x48A8E0` | `0x7ACEDC` |
| 212 (`0xD4`) | acrobat | `FUN_0048A900 @ 0x48A900` | `0x7AD140` |
| 213 (`0xD5`) | drama | `FUN_0048A920 @ 0x48A920` | `0x7AD3A4` |

The EN/CH comparison rows for `0x48A7E0`, `0x48A800`, `0x48A8E0`,
`0x48A900`, `0x48A920`, and `0x51C660` are all `identical`. Native now exposes
this exact class-dispatch table as
`OriginalResidentialServiceCatalog.entertainmentProviderFactoryDescriptors`;
the table records constructor identity only and has no side effects.

This closes the indirect class-factory question for an already-known
entertainment model object. It does **not** establish that a Qin map archive
contains such an object: Qin's generic `Building` records still carry base
type `0` and provider slot `-1` (§7.3ae), and the map loader still invokes only
the generic record callback. The archive-side specialization/replacement
caller, non-negative provider registry index, and Native venue projection
remain **unknown**; figures 32…34 therefore stay fail-closed in campaign
simulation.

**Evidence class:** `confirmed` for the model range, constructor/vtable mapping,
and EN/CH identity; `unknown` for archive-side object creation, replacement,
registry assignment, and venue coverage wiring.

### 7.3ak Qin post-load repair switch excludes service-provider models (confirmed negative, 2026-09-01)

The map-startup chain contains a distinct missing-object repair pass,
`FUN_0052F030 @ 0x52F030`, which scans the active object vector and calls
`Creating_pctd_type_pctd` only when `FUN_0052F1D0 @ 0x52F1D0` admits the
object's model word.  The exact switch cases are
`83, 89, 90, 91, 104, 105, 106, 123, 129, 130, 131, 210, 231, 232,
253…268`; EN/CH rows for both functions are `identical`.  The authored table
identifies these as the Grand Canal section (`83`), residential wall/gate
variants (`89…91`, `104…106`, `231…232`), bridge/city-wall/city-gate/tower
(`123`, `129…131`), Ferry (`210`), and Great Wall editor rows (`253…268`).
The switch has no cases for Well
`72/73`, Herbalist `207`, Acupuncture `208`, entertainment `211…213`, or
religious/Confucian providers `214…219`.

`FUN_0052F030` is called from the map/post-load chain (`FUN_0053D100`), but
its only creation call is the generic `Creating_pctd_type_pctd` path; it does
not call `FUN_0051C660`, assign provider `+0x2D`, or rebuild the entertainment
manager.  The same negative is now represented by
`OriginalMapArchiveRepairCatalog` and locked by
`testQinArchiveRepairSwitchExcludesResidentialServiceProviderModels`.
This closes the tempting “repair pass creates missing Qin service objects”
shortcut while leaving indirect/table-driven specialization, the serialized
provider index, and Native registry projection **unknown**.  No live service
bridge is enabled.

**Evidence class:** `confirmed` for the complete switch, caller chain,
EN/CH identity, and service-ID exclusion; `unknown` for any separate indirect
post-load specialization or provider registration path.

### 7.3ap The only recovered provider-slot writer is the generic create/replace helper (confirmed, 2026-09-01)

`Creating_pctd_type_pctd @ 0x42D540` is the concrete writer for the object
registry slot that the service callbacks later read as `object +0x2D`. On its
create branch it obtains the registry entry with `FUN_00413B40(param_6)`,
constructs the model through `FUN_0042D360(param_2)`, stores the object pointer,
then writes `object +0x2D = param_6` before invoking the object's placement
callback `vtable +0x94(param_2,param_3,param_4)`. Its replace branch reuses the
same registry entry and does not introduce another slot source. The helper's
EN/CH comparison row is `identical`.

The direct callers recovered in the corpus divide into placement/editor paths:
`FUN_004C1320 @ 0x4C1320` and `FUN_00414F70 @ 0x414F70` scan clear map cells and
create the requested model; `FUN_00563850 @ 0x563850` creates authored
multi-part building components and links their registry indices; and
`FUN_00540E70 @ 0x540E70` creates a market child during shop placement while
copying the selected cMarket slot/key. The post-load repair caller
`FUN_0052F030 @ 0x52F030` is the only recovered map-startup caller and is
guarded by the exclusion switch recorded in §7.3ak. No recovered caller feeds
the generic Qin archive's `Building` record ordinal or its serialized
`+0xB4 == -1` value into this helper.

This closes the slot-write mechanics and explains why a placed service object
can participate in the provider registry while an archived generic record
cannot be promoted by copying its tail word. It does **not** recover an
archive-side caller that specializes Qin records into Well, Herbalist,
Acupuncture, or entertainment objects, nor the parent/house projection after
slot assignment. Native must keep the campaign provider bridge fail-closed and
must not assign `+0x2D` from a map record index, object ordinal, or guessed
service mapping.

**Evidence class:** `confirmed` for the sole recovered slot writer, its create/
replace semantics, direct caller categories, and EN/CH identity; `unknown` for
any unindexed archive specialization and subsequent provider-to-house
projection.

### 7.3al `cHouseInfo` service bytes decay independently at phase `0x23` (confirmed, 2026-09-01)

The service-timer cadence is now represented without collapsing the two water
destinations. In the canonical EN executable,
`FUN_004AC2B0 @ 0x4AC2B0` advances `DAT_00C82EF8` through phases `0…0x32`;
at phase `0x23` it calls `FUN_00517B40 @ 0x517B40`. That routine walks the
active object vector (`FUN_004F8210`/`FUN_00554C00`), filters through each
building's `+0xB8` eligibility callback, resolves `cHouseInfo` via `+0x1E4`,
and invokes `FUN_00517280 @ 0x517280`. The EN/CH comparison rows for
`0x4AC2B0`, `0x517B40`, and `0x517280` are `identical`.

`0x517280` applies the byte operation `< 2 → 0, otherwise −1` independently
to `cHouseInfo +0x2A`, `+0x2C`, `+0x2B`, `+0x2E`, `+0x2D`, `+0x32`, `+0x34`, and
`+0x33`. It then walks exactly four bytes at `+0x0D…+0x10`, applying
`!= 0 → −1` to each. Thus the water bytes `+0x32` and `+0x34` have separate
lifetimes even though both are refreshed by `0x51BC00` with `0x60` under
different provider/context predicates (§7.1). The subsequent phase `0x24`
calls `FUN_00517AD0`, whose `+0x218` virtual dispatch reaches
`FUN_00518D60 → FUN_00517330` and `FUN_005173E0`; the health aggregate gives
`+0x34` precedence over `+0x32` but does not merge their timers.

The exact field-level operation is preserved by
`OriginalHouseInfoCountdownState.advanceOriginalServiceDecaySlice()` in
`Sources/EmperorCore/HousingEvolution.swift`, with regression coverage for
the floor, independent-water, and fixed-width byte-loop behavior. This is a
research primitive only. The map archive still lacks a recovered provider
registry index and post-load specialization, so Native does not create or
advance this state for Qin buildings; no service coverage is enabled by this
finding.

**Evidence class:** `confirmed` for phase ordering, active-object walk,
per-byte operations, four-byte loop width, and EN/CH identity; `unknown` for
the serialized source/meaning of each byte and the provider/object projection
needed to wire it into Qin.

### 7.3ao Residential provider vtables separate service writes from loader/decay callbacks (confirmed, 2026-09-01)

The canonical EN and CH PE images expose the three concrete residential
provider vtables installed by the recovered factory.  `FUN_0051C090 @
0x51C090` installs `PTR_LAB_007B5EB4` for Well IDs `0x48/0x49` (72/73),
`FUN_0051C0B0 @ 0x51C0B0` installs `PTR_LAB_007B6114` for Herbalist `0xCF`
(207), and `FUN_0051C0D0 @ 0x51C0D0` installs `PTR_LAB_007B6374` for
Acupuncture `0xD0` (208).  The 0x2D0-byte vtable slices are byte-identical
between the hash-matched EN (`8a6d2df1…6753`) and CH (`dbdeca1e…15a`)
executables.

The primary service callback is the vtable `+0x2C` slot.  Its exact targets
are:

| provider model | vtable | `+0x2C` target | recovered write |
| ---: | ---: | --- | --- |
| 72/73 (Well) | `0x007B5EB4` | `FUN_0051BC00 @ 0x51BC00` | writes `cHouseInfo +0x32` or `+0x34` to `0x60` after the Well context predicates |
| 207 (Herbalist) | `0x007B6114` | `FUN_0051BD00 @ 0x51BD00` | writes `cHouseInfo +0x2D` to `0x60` |
| 208 (Acupuncture) | `0x007B6374` | `FUN_0051BD90 @ 0x51BD90` | writes `cHouseInfo +0x2A` to `0x60` |

All three vtables share the `+0x1E4` `cHouseInfo` accessor (`FUN_0040E630`)
and the base `+0xC0` load callback (`FUN_0051CB80`).  The service callbacks
are not part of the map-load or timer-decay edges: `FUN_0042D790 @ 0x42D790`
creates a serialized object through `FUN_0042D0E0 → FUN_0077FD90`, inserts it,
and invokes only vtable `+0xC0`; `FUN_00517B40 @ 0x517B40` invokes `+0xB8`,
`+0x1E4`, then `FUN_00517280` for byte decay.  Neither edge invokes `+0x2C`
or installs provider `+0x2D`.  The EN/CH function bodies for
`FUN_0051BC00`, `FUN_0051BD00`, `FUN_0051BD90`, `FUN_0051CB80`,
`FUN_0042D790`, and `FUN_00517B40` are `identical` in the comparison report.

This closes the concrete callback target for an already-instantiated provider
object, while preserving the unresolved boundary that matters to Qin: the
map archive contains generic `Building` records with provider slot `-1`, and
the post-load path still has no recovered object-specialization or registry
assignment edge.  Native may retain the callback map as research metadata, but
must not invoke these writers for Qin until the provider object-to-map and
house projection are recovered.

**Evidence class:** `confirmed` for factory/vtable addresses, byte identity,
`+0x2C` targets, shared accessor/loader/decay separation, and write constants;
`unknown` for archive-side specialization, provider registry assignment, and
the runtime house/road projection required for live Qin coverage.

The callback table is now centralized as
`OriginalResidentialServiceCatalog.providerCoverageCallbackDescriptors` in
`Sources/EmperorCore/HousingEvolution.swift`. It records the exact provider
model families, vtable addresses, callback addresses, and raw `cHouseInfo`
write offsets (`72/73 → 0x51BC00 → +0x32/+0x34`, `207 → 0x51BD00 → +0x2D`,
`208 → 0x51BD90 → +0x2A`). This is metadata for the future registry bridge;
it does not invoke a callback, manufacture an archive provider, or collapse the
two Well water bytes into Native `.water` coverage.

### 7.3ap.1 Direct dynamic-factory census leaves archive specialization unresolved (confirmed, 2026-09-02)

The indexed EN/CH corpus contains only two direct callers of the generic
factory `FUN_0042D360 @ 0x42D360`: `FUN_00427150 @ 0x427150` and
`Creating_pctd_type_pctd @ 0x42D540`. The first is itself called only by
`FUN_00541110 @ 0x541110`, whose body invokes `FUN_00427150` and copies the
result's `+0x158` from its input; it is not a map-loader or provider-registry
path. The second is the already recovered create/replace helper: after
allocating a registry entry it writes the new object's `+0xB4` (`+0x2D` in
byte-oriented provider callbacks) and invokes `vtable +0x94`.

The residential service branch inside `FUN_0042D360` dispatches through
`FUN_0051C660 @ 0x51C660`, but no direct map-loader call reaches that branch.
The EN/CH comparison rows for `0x42D360`, `0x427150`, `0x541110`, and
`0x42D540` are `identical`. `OriginalMapArchiveRepairCatalog` now records
these direct caller addresses and the residential dispatcher as a regression
boundary. This closes the direct-call inventory, not indirect or table-driven
dispatch: the generic Qin archive still carries `Building` records with an
unbound provider slot, so Native must remain fail-closed for post-load service
specialization and provider-to-house projection.

**Evidence class:** `confirmed` for the indexed direct caller set, the
`FUN_00541110` copy-only use, the create/replace slot writer, and EN/CH parity;
`unknown` for any unindexed indirect/table dispatch and the archive-side
provider registry source.

### 7.3ap.2 `+0x9C` refresh registers only admitted Trading Quay slots (confirmed, 2026-09-02)

The provider statistics callback `FUN_0051CCA0 @ 0x51CCA0` first calls
`FUN_005E1720 @ 0x5E1720`, whose complete body returns true only for model
`0x38` (decimal `56`, **Trading Quay**). For every other model it increments
the per-model counter array at `DAT_00A5AF64[model]`; when the provider's
vtable `+0x1B4` method returns a positive value it also increments
`DAT_00A5AB30[model]`. These arrays are reset by `FUN_004AF230` before the
active-object walk. The EN/CH comparison rows for `0x51CCA0`, `0x5E1720`,
and `0x4AF230` are `identical`.

The model-56 branch does not increment those per-model arrays. While the
global count `DAT_00A5B044` is strictly below `10`, it appends the already
assigned object registry value `param_1[0x2D]` (object offset `+0xB4`) to
`DAT_0131249C[0…9]`, increments the count, and then increments the separate
staffed count `_DAT_00A5AC10` only when the same `+0x1B4` method is positive.
When the ten-entry table is full, the callback performs none of those model-56
append/staffed-count operations. The callback's final parent-link tail is
already captured by `OriginalWaterProviderState.validatedParentShort`; it
does not assign the registry slot itself.

`GameData/Model/EmperorBuildingModels.txt` row 56 names the model **Trading
Quay** and row 58 names **Trading Station**. `FUN_0051CCA0` therefore closes
the raw refresh-table bound and counter split for sea-trade objects, but not
the provider's source inventory, route, or settlement semantics. In
particular, the callback is reached by the active-object refresh walk only
after a specialized object and its `+0xB4` slot already exist; it is not an
archive specialization or market-record population edge. Native records this
field-level result through
`OriginalResidentialServiceCatalog.refreshProviderRegistry(...)` and leaves
the Qin trade/provider bridge fail-closed.

**Evidence class:** `confirmed` for the model classifier, counter/table
addresses, ten-entry admission bound, `+0xB4` registry value, `+0x1B4` staffing
test, reset walk, and EN/CH identity; `unknown` for the specialized-object
creation source in Qin archives, the semantic meaning of the staffing method,
and all downstream trade inventory/route/settlement projections.

### 7.3ap.3 Provider load callback auxiliary construction is explicit but not a registry bridge (confirmed, 2026-09-02)

The shared provider load callback `FUN_0051CB80 @ 0x51CB80` has a small,
reproducible auxiliary-object construction sequence. It first calls the generic
load callback `FUN_004271B0 @ 0x4271B0`, then checks the global gate through
`FUN_00426D10(0)`. When the gate is open it requests `0x20` bytes from
`FUN_0077BB08`, constructs the object with `FUN_00526830(param_1[0x2D])`,
stores the returned pointer at provider object offset `+0x14C`, and invokes
the provider vtable `+0x1FC` method. The provider `+0x2D` input is the raw
`+0xB4` word already present on the object; this callback does not write that
word.

`FUN_00526830 @ 0x526830` calls the base constructor
`FUN_00418D70 @ 0x418D70`, which stores its input at auxiliary-object
offset `+0x14` and installs `PTR_FUN_007AB3F4`, then replaces the vtable with
`PTR_FUN_007B6B3C`. The matching destructor thunk is
`FUN_00526850 @ 0x526850`; it calls `FUN_00526870 @ 0x526870` before the
base release initializer `FUN_00418FE0 @ 0x418FE0`. The same load callback is
also reached by the non-provider construction paths
`FUN_0048B670 @ 0x48B670` and `FUN_005F11A0 @ 0x5F11A0`; those callers perform
their own post-gate work and do not expose a provider registry or archive
object mapping. All inspected EN/CH function pairs (`0x418D70`, `0x418FE0`,
`0x48B670`, `0x51C9A0`, `0x51CB50`, `0x51CAD0`, `0x51CB80`, `0x526830`,
`0x526850`, `0x526870`, `0x5F11A0`) are `identical` in
`local/source/compare-report.tsv`.

The construction constants are centralized as
`OriginalResidentialServiceCatalog.providerLoadAuxiliaryDescriptor` in
`Sources/EmperorCore/HousingEvolution.swift`. This is a confirmed object
layout/call-order boundary only. The auxiliary vtable's semantic methods,
the provenance of the input `+0xB4` value for Qin map records, any indirect
provider specialization, and the route/house projection remain **unknown**.
Native therefore records the shape without allocating this object or opening
Qin water/entertainment/market settlement.

**Evidence class:** `confirmed` for allocation size, constructor/destructor
addresses, vtable replacements, field offsets, gate/order, and EN/CH parity;
`unknown` for auxiliary semantics, archive registry provenance, indirect
specialization, and all downstream provider settlement.

### 7.3ap.5 Provider load callback has eight direct PE callsites (confirmed, 2026-09-03)

The canonical EN and CH PE `.text` scans contain the same eight direct `E8`
calls to `FUN_0051CB80 @ 0x51CB80`: `0x48B678`, `0x4C1778`, `0x4C3068`,
`0x524368`, `0x54118B`, `0x5AB1F8`, `0x5D4868`, and `0x5F11A8`. The two
named split-corpus wrappers are `FUN_0048B670` (followed by
`FUN_0048A340`/`FUN_00490300` when the gate is open) and `FUN_005F11A0`
(followed by `FUN_005F0C70`/`FUN_005F4F70`); the remaining callsites are split
entry points whose merged C output does not retain a single named caller.
None of the eight callsites lies in the generic map loader
(`FUN_0042D790 → FUN_0042D0E0`), and the callsite bytes are identical between
the EN and CH PE images.

This is a confirmed negative for treating the generic loader's `+0xC0`
callback as an implicit provider-load edge: all recovered direct edges are
construction/lifecycle wrappers, not the map-loader record loop. An
indirect/table-driven dispatch is not excluded by this census, so the archive
specialization caller, provider registry source, and house/route settlement
remain **unknown**. Native keeps the Qin provider bridge fail-closed and
exposes the eight callsites only as research metadata in
`OriginalResidentialServiceCatalog`.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051CB80.c`,
`local/source/split-merged/code/0x040000/FUN_0048B670.c`,
`local/source/split-merged/code/0x050000/FUN_005F11A0.c`, the generic loader
`FUN_0042D790.c`, canonical EN/CH PE `.text` callsite scans, and
`local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the complete PE direct-callsite set,
caller follow-up branches, generic-loader separation, and EN/CH identity;
**unknown** for indirect/table-driven dispatch and all archive/provider
projection semantics.

### 7.3ap.4 Directional routing layers are offset views of one padded cache (confirmed, 2026-09-02)

The four routing layers consumed by the mode-`0`/mode-`1` candidate floods are
not four independently populated arrays. `FUN_005AD920 @ 0x5AD920` clears
`0x6588` DWORDs—one `228×228` map of 16-bit cells—beginning at
`DAT_013789C0`; `FUN_005AD8F0 @
0x5AD8F0` then rebuilds it by calling `FUN_005AD440 @ 0x5AD440` over the
current map rectangle. The flood readers use four address aliases of that
region: `DAT_013787F8` (north), `DAT_013789C2` (east), `DAT_01378B88` (south),
and `DAT_013789BE` (west). Relative to the central `DAT_013789C0` cell these
are `-0x1C8`, `+2`, `+0x1C8`, and `-2` bytes respectively; `0x1C8` is
`2 × 228`, the canonical 16-bit map row stride. The same aliases and deltas
are visible in both `FUN_005B0220 @ 0x5B0220` and `FUN_005B0360 @ 0x5B0360`.

This closes the PE storage/view relationship and explains the one-cell/one-row
border arithmetic without assigning a Native terrain meaning to any bit. The
producer still depends on unresolved terrain globals, object callbacks, and
the live object-grid projection, so Native must not synthesize the central
cache or infer a service route from these offsets. The relationship is exposed
only through the read-only `OriginalDirectionalLayerViews` helper and its
regression test.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005ad920.c`,
`FUN_005ad8f0.c`, `FUN_005ad440.c`, `FUN_005b0220.c`, and
`FUN_005b0360.c`; `local/source/compare-report.tsv` rows `0x5AD440`,
`0x5AD8F0`, and `0x5AD920`; `Sources/EmperorCore/MarketSimulation.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** `confirmed` for the shared storage base, alias addresses,
byte deltas, 228-cell row stride, reset/rebuild order, and EN/CH identity;
`unknown` for the central-cache producer's terrain/object semantics and its
projection into Native routing grids.

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

## 10. 2026-09-02 provider/map-load negative trace

The remaining Qin provider-registration blocker was re-audited against the
indexed EN/CH corpus. `FUN_0052FDA0` and `FUN_0052E7C0` call
`FUN_0042D790 @ 0x42D790` for map/archive object loading. That loader creates
each record through `FUN_0042D0E0`, inserts it through `FUN_0042B590`, and then
invokes the loaded object's vtable `+0xC0`; the loader body contains no direct
`FUN_0042D360`, `FUN_0051C660`, `FUN_0051BEF0`, provider `+0x2D` assignment, or
separate provider-list insertion. The two direct `FUN_0042D360` call sites in
the corpus are the generic conversion wrapper `FUN_00427150` and the explicit
player create/replace path `Creating_pctd_type_pctd @ 0x42D540`; the latter
writes `p[0x2D] = param_6` after allocation.

`FUN_0051C660 @ 0x51C660` remains a model-factory dispatch reached from
`FUN_0042D360`, including service IDs `0x48/0x49/0xCF/0xD0` through
`FUN_0051BEF0`; no call edge from the archive loader to that dispatch was
found. `FUN_0053D100` and `FUN_0052F030` are post-load/reset chains in the
same load path, but their indexed bodies contain no provider factory or
registry-slot writer. EN/CH comparison rows for the inspected functions are
identical. This is a confirmed negative result, not proof that no later
indirect callback exists: the unresolved edges are the source of the archive
registry value, any vtable `+0xC0` specialization/replacement, and the Native
object/provider projection.

Native therefore keeps Qin market, water, and entertainment provider
coverage/settlement fail-closed. No registry bridge or guessed archive-to-
provider conversion is permitted from this search.

**Evidence class:** **confirmed negative** for the direct factory/slot-writer
edges listed above; **unknown** for indirect vtable specialization, serialized
registry-value provenance, and Native projection/settlement.

### 10.1 `+0x6F` decay and expiry callback boundary (confirmed, 2026-09-02)

`FUN_0042DA70 @ 0x42DA70` is called from the scheduler-wrap body
`FUN_004AC650 @ 0x4AC650`, after the normal `0x33`-phase counter reaches its
wrap. With `FUN_00426D10(0)` open, the function walks the active object vector,
clears a non-zero object `+0x92`, and decrements each non-zero object `+0x6F`
exactly once. When that decrement produces zero, it invokes the object's
vtable `+0x100` with `(modelID, originX, originY, footprintSide, 0, 0)`.
When the global gate is closed, neither the decrement nor the expiry callback
occurs; an already-zero byte likewise does nothing.

`OriginalWaterProviderState.decayCommandState` records this byte-level result
(`nextByte6F`, `didExpire`) and tests the closed-gate, ordinary-decrement,
zero-expiry, and already-clear cases. This closes the provider/object state
decay boundary and its scheduler-wrap location, but not the identity of the
object vector entries, the callback's provider-specific side effects, or the
registry projection needed to invoke it for map-loaded Qin providers. Native
therefore keeps this helper pure and does not enable the provider callback.

**Evidence class:** **confirmed** for the caller, gate, one-step decrement,
zero-expiry callback condition, and callback arguments; **unknown** for
provider/object ownership, callback implementation, and live Qin registration.

### 10.2 Entertainment manager initialization separates object counts from rotation slots (confirmed, 2026-09-02)

`FUN_004106D0 @ 0x4106D0` initializes the entertainment manager and calls
`FUN_00410620 @ 0x410620`. The callee clears five counters, then walks the
active object vector returned by `FUN_00413B40(1)` until `FUN_004F8200()`.
Only entries passing the global `FUN_00426D10(0)` gate and the model whitelist
`FUN_0048A7E0` are counted. Model `211` (Music School), `212` (Acrobat
School), and `213` (Drama School) increment manager fields `+0x34`, `+0x38`,
and `+0x3C`; model `71` (Entertainment Area) and `75` (Theatre Pavilion)
increment `+0x40` and `+0x44`. Unknown models are ignored. The EN and CH
functions are byte-for-byte equivalent in `compare-report.tsv`.

This is an object-total boundary, not a staffed-capacity or figure-rotation
boundary. `FUN_0048F140 @ 0x48F140` separately derives rotation slots from
active school objects (first active school contributes three slots and later
schools one); venue models `71/75` do not participate in that slot calculation.
Native exposes the five raw totals through
`EntertainmentProviderObjectCounts.rebuilt(...)` while retaining the
existing `EntertainmentProviderRotationState` for school rotation slots. The
helper does not register providers, spawn figures, or settle coverage because
the archive/provider projection remains unresolved (§10).

**Sources:** `local/source/split-merged/code/0x040000/FUN_00410620.c`,
`FUN_004106D0.c`, `FUN_0048A7E0.c`, and `FUN_0048B540.c`;
`local/source/compare-report.tsv` row `0x410620`;
`Sources/EmperorCore/HousingEvolution.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the five counter offsets, admitted model
IDs, active-vector order, global gate, call edge, and EN/CH parity; **unknown**
for provider registration, staffing/figure capacity, and downstream settlement.

### 10.3 Provider-load auxiliary order is gated, not a registry bridge (confirmed, 2026-09-02)

The EN/CH-identical `FUN_0051CB80 @ 0x51CB80` body was re-read together with
its alternate construction sibling `FUN_0051CAD0 @ 0x51CAD0`. The load callback
always dispatches `FUN_004271B0` first. It then tests the global
`FUN_00426D10(0)` gate; when that gate is closed, the callback returns without
allocating or storing an auxiliary object. When the gate is open, it allocates
exactly `0x20` bytes through `FUN_0077BB08`, constructs
`FUN_00526830(provider + 0x2D)`, stores the returned pointer at provider
`+0x14C`, and invokes the provider vtable `+0x1FC`. A failed allocation also
returns without the store or callback dispatch.

The auxiliary constructor `FUN_00526830` calls `FUN_00418D70`, which installs
base vtable `0x007AB3F4` and stores its input at auxiliary `+0x14`, before the
derived vtable `0x007B6B3C` is installed. The alternate `FUN_0051CAD0` path
performs the same allocation/constructor/store/callback sequence without the
`FUN_00426D10(0)` gate; its emitted callers are explicit object construction
helpers, not the map/archive loader. `local/source/compare-report.tsv` marks
`0x418D70`, `0x51CAD0`, `0x51CB80`, and `0x526830` identical for EN/CH.

`OriginalResidentialServiceCatalog.providerLoadAuxiliaryOutcome` records only
the gated order and allocation result. It deliberately does not allocate the
auxiliary object, assign a registry slot, or invoke a provider callback in
Native. The map loader's direct factory/slot-writer negative result in §10
therefore remains unchanged: the source of `provider +0x2D`, any indirect
specialization, and all provider-to-house settlement effects are still
**unknown**. Qin water, market, and entertainment registration stay
fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051CB80.c`,
`FUN_0051CAD0.c`, `FUN_00526830.c`, `local/source/split-merged/code/0x040000/`
`FUN_00418D70.c`, `FUN_004271B0.c`, and the direct caller census for
`FUN_0051CAD0`/`FUN_0051CB80`; `local/source/compare-report.tsv` rows listed
above; `Sources/EmperorCore/HousingEvolution.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for callback order, gate, allocation size,
field offsets, constructor/vtable chain, and EN/CH identity; **confirmed
negative** for a direct map-loader edge; **unknown** for registry provenance,
indirect specialization, and downstream settlement.

### 10.4 Well `+0x6F` refresh is an adjacency callback, not the service scheduler (confirmed, 2026-09-02)

`FUN_00511860 @ 0x511860` first calls `FUN_00511060` (the calendar guard),
then `FUN_00511710` scans the eight fixed neighbouring offsets around its
source object. A candidate is admitted only when its vtable `+0x1D0` predicate
is false and `FUN_00511B10` accepts the source-category/target-model pair.
The admitted candidate is passed to `FUN_00511080 @ 0x511080`, whose outer
category-6 branch accepts target model IDs `0x48/0x49` (Well `72/73`). It reads
the target byte `+0x6F`, compares it with `FUN_00511700(6) = 6 << 4 = 0x60`,
and calls `FUN_0042AE30` with the larger of the existing byte and `0x60`.
`FUN_0042AE30 @ 0x42AE30` writes that byte at target `+0x6F` and then calls
`FUN_00418680(target + 0xB4)`; it does not write either `cHouseInfo` byte.

The EN/CH rows for `0x42AE30`, `0x511080`, `0x511860`, and `0x511B10` are
`identical`. This closes one additional `+0x6F` writer and explains why the
existing pure `raisedWellCommandState` helper uses a floor of `0x60`. It does
**not** establish that the adjacency callback is the staffed-provider
scheduler: the source-category meaning, indirect caller/vtable registration,
and the object-registry projection are still unknown. Native therefore must
not invoke this writer from generic `.water` visits or from the Qin map loader.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00511860.c`,
`FUN_00511080.c`, `FUN_00511710.c`, `FUN_00511B10.c`,
`local/source/split-merged/code/0x040000/FUN_0042AE30.c`,
`local/source/compare-report.tsv`, and `Sources/EmperorCore/HousingEvolution.swift`
(`OriginalWaterProviderState.raisedWellCommandState`).

**Evidence class:** **confirmed** for the adjacency scan, Well model admission,
`0x60` floor, and byte writer; **unknown** for callback cadence, source-category
semantics, provider registration, and downstream house-service settlement.

## 2026-09-02 Native dual-water-byte persistence boundary

The source-backed water callback writes two independent `cHouseInfo` bytes:
`FUN_0051BC00 @ 0x51BC00` stores `0x60` in either `+0x32` or `+0x34`, while
`FUN_00517280 @ 0x517280` decays each byte independently with the
`< 2 → 0, otherwise −1` operation. The two bytes are consumed separately by
the health score (`+0x34` has the `+15` precedence over `+0x32`'s `+5`) and
the building-side status projection (`+0x34` wins with status `2`). The
provider/global predicates that select the destination are still unresolved
for Native, so a single `.water` coverage bit cannot be promoted to either
source byte.

`ResidentialUnit` now carries optional, backward-compatible
`originalWaterPrimaryRemainingSlices` and
`originalWaterSecondaryRemainingSlices` projections. The optionals preserve
the distinction between an explicitly recovered zero and an unprojected byte
in pre-bridge saves. `applyOriginalWaterVisit(destination:)` and
`setOriginalWaterRemainingSlices(_:destination:)` require the caller to pass
the already-resolved source destination; `advanceOriginalWaterServiceSlice()`
applies the exact byte decay to both projected values without filling a
missing byte. No live Well/provider path invokes these methods, and the
existing generic `.water` walker remains unchanged, so this state addition
does not invent the unresolved provider/object registry mapping.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051BC00.c`,
`local/source/split-merged/code/0x050000/FUN_00517280.c`,
`local/source/compare-report.tsv` (both rows `identical`), and the existing
water callback/score traces in this document §§7.1a, 7.3p, and 10.96.

**Evidence class:** **confirmed** for the two byte identities, write value,
independent decay, and Native optional persistence shape; **unknown** for the
provider/object bridge and destination-selection inputs, so runtime water
coverage remains fail-closed.

### 10.5 Well adjacency candidate admission is now explicit (2026-09-02)

The external refresh path `FUN_00511860 @ 0x511860` obtains one candidate
from `FUN_00511710 @ 0x511710`. The candidate scan checks the eight neighboring
map offsets in the fixed order
`[-0xE4,-0xE3,+1,+0xE5,+0xE4,+0xE3,-1,-0xE5]`; each non-zero object is
rejected when its vtable `+0x1D0` reports active, then passed to
`FUN_00511B10 @ 0x511B10` for a controller-category/model whitelist. The
English and Chinese bodies are `identical` in
`local/source/compare-report.tsv` (rows `0x511710`, `0x511B10`, and
`0x511860`).

The category/model admissions are now recorded by the pure
`OriginalWaterProviderState.adjacentTargetAdmission` helper. It preserves the
direct sets from `FUN_00511B10`: category 6 admits Well IDs `72/73`; category
0 admits `31/33/35/124`; categories 1, 2, 3, 5, 7, 8, 9, 10, and 11 retain
their exact model sets from the switch body. Category 4 admits model `66`
directly, while models `59`, `60`, and `71` require the additional
`FUN_00544A00` six-slot/object check (and model 71's `+0x268` child
resolution); the helper exposes that unresolved branch as
`requiresAuxiliaryCheck`. The separate `+0x1D0` active predicate is also an
explicit argument and rejects an otherwise whitelisted candidate.

This closes the candidate filter and order without assigning a meaning to the
controller category, resolving the object registry, or proving that command
`0x69` reaches a live Qin provider. The helper is research-only; the Native
simulation still does not invoke `FUN_00511860`, `FUN_00511080`, or project
the resulting `+0x6F` write into water coverage.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00511710.c`,
`FUN_00511B10.c`, `FUN_00511860.c`, `FUN_00511080.c`,
`local/source/compare-report.tsv`, and
`Sources/EmperorCore/HousingEvolution.swift`.

**Evidence class:** **confirmed** for the eight-neighbour order, active
predicate, direct category/model sets, and EN/CH parity; **unknown** for
category semantics, the auxiliary callback's object meaning, command cadence,
registry projection, and downstream water settlement.

### 10.6 Canonical PE direct-call census closes the specialized factory edge (2026-09-03)

I rescanned the canonical EN and CH PE `.text` sections (`0x401000..0x7A9000`)
for every direct `E8 rel32` call whose resolved target is one of the
service/entertainment factory and provider callbacks below. The two binaries
produce the same callsite set:

| target | direct callsites (caller) |
| --- | --- |
| `FUN_0051C660 @ 0x51C660` | `0x42D3CC` (`FUN_0042D360`) only |
| `FUN_0051BEF0 @ 0x51BEF0` | `0x51C71C` (`FUN_0051C660`) only |
| `FUN_0048A800 @ 0x48A800` | `0x51C766` (`FUN_0051C660`) only |
| `FUN_0051CCA0 @ 0x51CCA0` | `0x48AEB9` (`FUN_0048AE30`), `0x4C1288` (`FUN_004C1240`) |
| `FUN_0051CB80 @ 0x51CB80` | `0x48B678`, `0x4C1778`, `0x4C3068`, `0x524368`, `0x54118B`, `0x5AB1F8`, `0x5D4868`, `0x5F11A8` |
| `FUN_0051BC00 @ 0x51BC00`, `FUN_0051BD00 @ 0x51BD00`, `FUN_0051BD90 @ 0x51BD90`, `FUN_0051CB30 @ 0x51CB30` | no direct `E8` callsite observed |

The source bodies corroborate the reachability boundary. `FUN_0051C660`
selects the service/entertainment constructors (`FUN_0051BEF0` for models
`72/73/207/208`, `FUN_0048A800` for `211..213`) and is called directly only
by the explicit factory `FUN_0042D360`. The map-load path
`FUN_0042D790 → FUN_0042D0E0` therefore has no direct edge into this
specialized branch. `FUN_0051CCA0` is a statistics/auxiliary refresh called
from `FUN_0048AE30` and `FUN_004C1240`, while `FUN_0051CB80` consumes an
already-populated object `+0x2D` and writes an auxiliary `+0x53`; neither
caller set is a map-loader site. The four callback targets with no direct
`E8` edge remain candidates for vtable/indirect dispatch only.

This is a **confirmed negative** for another direct archive-load → service
factory/provider callback path in both language variants. It does not recover
the indirect registry/table that may dispatch `FUN_0051BC00` or the source of
object `+0x2D`, nor does it establish provider-to-house settlement. Native
must keep Qin provider registration, water-byte projection, market supply,
and entertainment settlement fail-closed until those inputs are recovered.

**Sources:** canonical PE files `Exe/ghidra/input/EmperorEN.exe` and
`EmperorCH.exe` (hashes recorded in `DESIGN.md`), direct `E8 rel32` census;
`local/source/split-merged/code/0x050000/FUN_0051C660.c`,
`FUN_0051BEF0.c`, `FUN_0051CB80.c`, `FUN_0051CCA0.c`, `FUN_0051BC00.c`,
`FUN_0051BD00.c`, `FUN_0051BD90.c`, and
`local/source/split-merged/code/0x040000/FUN_0042D360.c`,
`FUN_0042D790.c`, `FUN_0048A800.c`, `FUN_0048AE30.c`, `FUN_004C1240.c`;
`local/source/compare-report.tsv` rows `0x48A800`, `0x51BEF0`,
`0x51C660`, `0x51CB80`, `0x51CCA0`, `0x51BC00`, `0x51BD00`, and `0x51BD90`.

**Evidence class:** **confirmed** for direct-call reachability, constructor
model sets, callback caller identities, and EN/CH parity; **confirmed
negative** for a second direct archive-load edge; **unknown** for indirect
vtable/table dispatch, registry provenance, and all downstream settlement.

### 10.6a Entertainment provider `+0x1BC` is a guarded raw staffing ratio (confirmed, 2026-09-03)

The positive `+0x1BC` gate used by `FUN_0048F140 @ 0x48F140` can be reduced to
its exact input fields for all three school vtables. Direct little-endian
reads from the canonical EN and CH PE images show identical words at
`0x7ACEDC`, `0x7AD140`, and `0x7AD3A4`:

| vtable slot | target | target contract |
| ---: | ---: | --- |
| `+0x1B0` | `0x00428EB0` | return `0` when object byte `+0x6E` is non-zero; otherwise return `FUN_0044CC50(object model ID, 5)` |
| `+0x1B8` | `0x00416B10` | sign-extend object word `+0x44` |
| `+0x1BC` | `0x00428ED0` | if denominator `+0x1B0` is positive, return `(signed +0x44 * 100) / denominator`; otherwise return `0` |

`FUN_00428ED0.c` confirms the two virtual calls and strict `n < 1` zero
branch. The target at `0x416B10` is a short PE body (`movsx eax,[ecx+0x44];
ret`), while the target at `0x428EB0` is the short branch that tests `+0x6E`
and, only for zero, calls `FUN_0044CC50` with selector `5`. The latter
selector is the authored model-table employee field (`EmperorBuildingModels.txt`
column `f`), not the placement Feng Shue column `m`. All three entertainment
provider vtables share these targets, so `FUN_0048F140`'s `+0x1BC > 0` test is
a guarded staffing ratio rather than an independent venue-capacity source.

This closes the source of the manager's positive-work gate and the signedness/
denominator behavior. It does **not** recover the cStall/provider registry
projection, the producer of object `+0x44`, or the venue route and settlement
effects. Native may expose this as a pure input primitive only; it must not
derive the missing raw fields from assigned-worker percentages or enable Qin
entertainment figures from this ratio alone.

**Sources:** canonical EN/CH PE vtable words at `0x7ACEDC/0x7AD140/0x7AD3A4`
and slots `+0x1B0/+0x1B8/+0x1BC`; direct EN/CH PE bodies at
`0x00428EB0`, `0x00416B10`, and `0x00428ED0`; `local/source/split-merged/code/
0x040000/FUN_00428ED0.c`, `FUN_0044CC50.c`, `FUN_0048F140.c`; and
`GameData/Model/EmperorBuildingModels.txt`.

**Evidence class:** **confirmed** for the shared targets, field offsets,
selector `5`, signed ratio arithmetic, and EN/CH parity; **unknown** for the
object `+0x44` producer, registry identity, and downstream venue settlement.

### 10.6b Scheduler phase `0x14` provider-record update is closed (confirmed, 2026-09-03)

The provider-record maintenance pass is `FUN_0051E4A0 @ 0x51E4A0`, reached by
the phase-`0x14` branch of `FUN_004AC2B0 @ 0x4AC2B0` before its separate
`FUN_004BC440` pass. The canonical EN and CH PE bodies are byte-identical for
the complete `0x51E4A0…0x51E5B5` slice (278 bytes; SHA-256
`be85aadfceaf8f07fc227e3eee0eb97165b5d4cbf41f60934007f62a8682b9cc`). The
function walks the active object vector from index `1` through the current
object count, and it processes an object only when the global
`FUN_00426D10(0)` gate and object byte `+0x47` are both non-zero.

For a candidate, the source requires all of these already-resolved virtual or
registry predicates: `+0xC8(-4)` returns false, `+0x198` returns true, signed
word `+0x44` is positive, `+0x78` returns true,
`FUN_004AE560(provider + 0xB4)` returns zero, and `+0x208` returns false. The
provider record comes from `+0x1E8`. If record byte `+0x63` is non-zero, only
that byte is decremented. Otherwise a positive record byte `+0x5F` is
decremented, the converted `+0x74(+0x1BC())` result is added to signed record
word `+0x04` with a 16-bit `add`, and the resulting sign-extended word is
capped against the provider `+0x204` result by a 16-bit store.

`OriginalResidentialServiceCatalog.ProviderRecordUpdateInput` and
`updateProviderRecord(_:)` now represent this exact gate/order/width boundary;
focused tests cover every gate, the mutually exclusive `+0x63` branch, the
`+0x5F` decrement, upper-cap clamp, and signed 16-bit wrap. This is still a
research-only helper for the admission-passed update branch. When
`+0xC8(-4)` returns true, the source instead dispatches `FUN_004C0F60`; that
separate recovery/decay path is deliberately not synthesized here. The
provider object, registry source, route, and house settlement are also not
invented, and no Qin runtime path is enabled by this change.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051e4a0.c`,
`local/source/split-merged/code/0x040000/FUN_004ac2b0.c`,
`local/source/compare-report.tsv` row `0x51e4a0`, the direct canonical EN/CH
PE slice above, `Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for phase/caller, vector order, all gates,
record offsets, admission-passed branch order, byte decrements, signed 16-bit
arithmetic, cap, and EN/CH identity; **unknown** for semantic labels, the
`FUN_004C0F60` admission-failure side path, provider registration, and
downstream Qin route/coverage/settlement.

### 10.6c Phase-`0x14` admission-failure record update is bounded (confirmed, 2026-09-03)

The non-zero result of the provider virtual `+0xC8(-4)` check in
`FUN_0051E4A0` dispatches `FUN_004C0F60 @ 0x4C0F60`. The canonical EN and CH
function bodies are byte-identical for `0x4C0F60…0x4C1033` (212 bytes;
SHA-256 `842bf5654490260abc735faa40edbc886b483d27b66939c534fa68390b9afa6d`),
and `local/source/compare-report.tsv` marks both `0x4C0F60` and its helper
`0x4C11B0` `identical`. `FUN_004C11B0((short)object + 0x14)` admits exactly
model IDs `0x1A/0x1B/0x1C` and `0xC2…0xC7`; authored building data identifies
these as crop/tree rows (Tea Bush, Lacquer Tree, Mulberry Tree, and six field
rows), but the executable function supplies no stronger semantic label. The
path also requires the raw global-table predicate
`(DAT_00F6A9E0[object + 0x10] & 0x100) == 0`.

On an admitted object, the function returns `1`. If record byte `+0x63` is
positive, it decrements that byte and returns immediately, so the terminal
`+0x260` callback is not invoked. Otherwise it calls provider `+0x25C(0)`, adds
the returned value to signed record word `+0x04` with a 16-bit `add`, and uses
a signed comparison to cap the stored word at `10000`. It then calls
`FUN_004AFD80(object + 0x2D)`; when that raw registry predicate is true, the
record word is overwritten with zero. Finally it invokes provider `+0x260()`.
The helper `FUN_004AFD80` itself resolves the registry slot through
`FUN_0047F1B0` and tests the model-indexed `DAT_010BC7E0` byte, so Native
receives this as an explicit boolean rather than inventing a slot mapping.

`OriginalResidentialServiceCatalog.AdmissionFailureRecordUpdateInput` and
`updateAdmissionFailureRecord(_:)` now preserve the model/global gates, the
short count branch, callback order, signed-width arithmetic, `10000` cap,
registry reset, and terminal-callback reachability. This is a raw research
boundary only: the `+0x25C`/`+0x260` virtual implementations, registry source,
and resulting house/population settlement are not synthesized, and no Qin
runtime producer is enabled.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004c0f60.c`,
`FUN_004c11b0.c`, `FUN_004c0600.c`, `FUN_004c0630.c`, `FUN_004c0640.c`,
`FUN_004afd80.c`, `FUN_0047f1b0.c`, `local/source/compare-report.tsv`, direct
canonical EN/CH PE slice `0x4C0F60…0x4C1033`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the model whitelist (with authored
crop/tree cross-reference but no semantic upgrade), global mask gate,
record byte/word offsets, branch order, virtual callback ordering, signed
16-bit add/cap/reset, return values, and EN/CH identity; **unknown** for
semantic labels, virtual callback implementations, registry provenance, and
downstream Qin settlement.

### 10.6d Phase-`0x14` admission-failure callbacks are agricultural object paths, not the Qin migration producer (confirmed boundary, 2026-09-03)

The callback slots reached by `FUN_004C0F60` were checked against the canonical
English PE vtables and the Chinese build (`8a6d2df1…6753` and
`dbdeca1e…15a`).  The admitted model IDs are authored crop/tree rows in
`GameData/Model/EmperorBuildingModels.txt`: `0x1A/0x1B/0x1C` are Tea Bush,
Lacquer Tree, and Mulberry Tree, while `0xC2…0xC7` are Hemp, Wheat, Millet,
Rice, Cabbage, and Soybean fields.  The direct vtable entries for these
families point at agricultural/status callbacks: the `+0x25C` implementations
return model/status-dependent values (`FUN_004C2260`, `FUN_004C2600`, and
`FUN_004C2730`), while the corresponding `+0x260` implementations call the
feedback writer (`FUN_004B72B0`) or return field-status data.  The field-family
`+0x25C` predicate uses `FUN_004C3440`, whose complete mapping is
`26→0xED`, `27→0xEE`, `28→0xEF`, `0xC2→0xC0`, and `0xC3…0xC7→0xC1`.

This callback family is reached only from the `+0xC8(-4) != 0` branch in
`FUN_0051E4A0 @ 0x51E4A0`; its caller iterates the active object vector during
scheduler phase `0x14`.  No edge from this branch reaches the migration
producer, figure-`#11` arrival path, a residential provider registry, or a
house-coverage writer.  The model/data cross-reference therefore closes a
false lead: the raw phase-`0x14` helper can remain available for record-width
regression tests, but it must not be used to synthesize Qin migration or
residential settlement.

**Evidence class:** **confirmed** for the caller branch, admitted model IDs,
authored crop/tree rows, callback targets/return families, `FUN_004C3440`
mapping, and EN/CH parity; **unknown** for the callbacks' player-facing
agricultural meanings, registry provenance, and any separate post-load/table
dispatch that could create a provider object.

### 10.6e Herbalist and Acupuncture coverage callbacks are single-byte writes (confirmed, 2026-09-03)

The service-provider vtables identify two additional residential coverage
callbacks.  For Herbalist model `207` (`0xCF`), vtable `0x7B6114` dispatches
`+0x2C0` to `FUN_0051BD00 @ 0x51BD00`; for Acupuncture model `208` (`0xD0`),
vtable `0x7B6374` dispatches the same slot to `FUN_0051BD90 @ 0x51BD90`.
Both EN/CH function rows are `identical` in
`local/source/compare-report.tsv`, and neither function has an indexed direct
caller because the entry is reached through the provider vtable.

Each callback first requires `FUN_00426D10(0)` to be non-zero, then the target
building's `+0xB8` virtual eligibility callback and a strictly positive signed
`cHouseInfo +0x20` population.  On success it resolves the target
`cHouseInfo` through `+0x1E4` and stores `0x60` at one distinct byte:
`+0x2D` for Herbalist and `+0x2A` for Acupuncture.  A failed gate returns zero
without writing.  Native records this as the pure
`OriginalResidentialServiceCatalog.residentialProviderHouseCoverageWrite`
helper with explicit gates, offsets, value, and regression coverage.

This closes only the provider-to-house field-write arithmetic.  The provider
registry source, archive specialization/slot projection, route, and settlement
remain **unknown**, so the helper is research-only and Qin service simulation
stays fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051BD00.c`,
`FUN_0051BD90.c`, the canonical EN/CH provider vtables at `0x7B6114` and
`0x7B6374`, `local/source/compare-report.tsv` rows `0x51BD00`/`0x51BD90`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for model/vtable/slot mapping, gate order,
field offsets, value, return behavior, and EN/CH parity; **unknown** for
registry provenance, archive projection, routing, and downstream settlement.

### 10.6f Religion callback target admission and field mapping are explicit (confirmed, 2026-09-03)

`FUN_005AB580 @ 0x5AB580` is the religion-provider coverage callback for
models `214...219`, reached through the shared generic service vtable.  Its
target gate is distinct from the ordinary services: `FUN_005188B0` admits
target house models `2...17`, `+0x09` must be non-zero, and a target with
signed population `+0x20 < 1` is accepted only for elite models `11...17`
(`FUN_005188D0`).  A non-zero provider restriction byte at `+0x174` applies
the same elite-only rule.  On success the callback resolves `cHouseInfo`
through `+0x1E4`, obtains value `0x28` from `FUN_00517270`, and writes one
religion field at `0x0D + index`.

The provider constructor's `FUN_005AB080` mapping is exact: `214→0`,
`215/216→1`, `217/218→2`, and `219→3`, yielding offsets `0x0D...0x10`.
Native now records this as the pure
`OriginalResidentialServiceCatalog.religiousHouseCoverageWrite` helper and
tests populated/elite-vacant admission, restriction rejection, model/index
mapping, and all failure gates.  The helper is research-only: provider
registry ownership, archive projection, route, and settlement remain
**unknown**, so Qin religious coverage is still fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005AB580.c`,
`FUN_005188B0.c`, `FUN_005188D0.c`, `FUN_00517270.c`, `FUN_005AB080.c`,
`FUN_005AB0D0.c`, `local/source/compare-report.tsv` rows `0x5AB580`,
`0x5188B0`, `0x5188D0`, `0x517270`, and `0x5AB080`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for provider/target model ranges, raw field
gates, provider-index mapping, offsets, write value, and EN/CH parity;
**unknown** for provider registry provenance, archive specialization, routing,
and downstream settlement.

### 10.6g House service countdown clears `cHouseInfo+0x3C` at expiry (confirmed, 2026-09-03)

The daily phase-`6` caller `FUN_004AC2B0 @ 0x4AC2B0` invokes
`FUN_005185C0 @ 0x5185C0` after the shared `FUN_005177B0` setup.  The
EN/CH-identical `FUN_005185C0` walks the live object vector and enters its
branch only when the global `FUN_00426D10(0)` gate, the object's virtual
`+0xB8` eligibility result, `cHouseInfo+0x3C != 0`, and the object dword at
`+0x98` (`p[0x26]`) are all non-zero/positive.  It then tests the signed
resident word at object `+0x20`:

* a zero resident word clears `cHouseInfo+0x3C` and the object `+0x98`
  countdown, without changing the global `DAT_0131289C` counter;
* a non-zero resident word decrements `+0x98`, increments `DAT_0131289C`,
  and clears `cHouseInfo+0x3C` only when the countdown reaches zero.

The source does not expose a provider/registry lookup in this body; the
`+0x1E4` callback merely resolves the already-associated `cHouseInfo`.  Native
now records this byte/word transition in the pure
`OriginalHouseInfoServiceCountdown.advance` helper with explicit gate inputs,
signed resident handling, expiry, and counter delta.  It is not wired to
Native house state because the source object-vector and callback projection
remain unresolved.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AC2B0.c`,
`local/source/split-merged/code/0x050000/FUN_005185C0.c`,
`local/source/compare-report.tsv` row `0x5185C0`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for phase/caller order, all four gates,
field offsets, zero-resident clear, non-zero decrement/counter increment,
expiry clear, and EN/CH parity; **unknown** for the semantic producer of
`+0x98`, registry/object specialization, and the downstream service/arrival
settlement that consumes `cHouseInfo+0x3C`.

### 10.6h City natural-health aggregate arithmetic is explicit (confirmed, 2026-09-03)

`FUN_00518490 @ 0x518490` computes the displayed natural-health target from
the live object-vector population and the sum of each eligible house's
`+0x214` contribution.  When the signed population total `n` is non-positive,
the function returns `100`.  Otherwise it computes `(healthSum * 100) / n`,
adds `(1000 - n) / 10` only when `n < 1000`, adds `10` only when the explicit
`FUN_005A8420(6)` flag is non-zero, and clamps only the upper result to `100`.
The arithmetic is integer division toward zero; there is no lower clamp in
this function.  `FUN_00590DB0 @ 0x590DB0` stores the result in
`DAT_0130F978`, while the source of the bonus flag and the cHouseInfo object
projection remain unresolved.

Native now exposes this raw contract as
`OriginalNaturalHealthAggregate.aggregate(totalPopulation:weightedHealthSum:bonusEnabled:)`.
The helper records the low-population correction, explicit bonus, and capped
result without mutating `CitySimulation` or claiming a health-field mapping.
This narrows the health blocker but does not enable Qin population growth,
disease incidents, or provider settlement.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00518490.c`,
`FUN_00590DB0.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/PublicHealthSafetySimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the population/weighted-sum arithmetic,
low-population correction, bonus value, upper clamp, no-population return, and
EN/CH parity; **unknown** for bonus-flag provenance, cHouseInfo projection,
and all downstream health/incidents.

### 10.6i Theatre Pavilion lookup and Entertainment Area raw pair table are bounded (confirmed, 2026-09-03)

The venue-adjacent lookup `FUN_0048A350 @ 0x48A350` scans the active object
vector and considers only object model `0x4B`/`75` (Theatre Pavilion in
`GameData/Model/EmperorBuildingModels.txt`).  A candidate must first pass the
object vtable `+0x19C` predicate.  The routine then probes the current figure
point against the candidate's separate `+0x2A/+0x2C` point with
`FUN_005B00D0(..., 0)` and rejects a false result.  Among the survivors it
computes the Chebyshev distance from the current figure point to the
candidate's `+0x0A/+0x0C` origin and keeps the first strict minimum; ties do not
replace the earlier vector entry.  The only direct `E8` caller in both
canonical PE images is `0x4D1BD0`, inside the recovered figure-update body.
The EN and CH function rows are `identical` (`compare-report.tsv` row
`0x48A350`).  The route-probe implementation and the meaning of the two
coordinate pairs remain unresolved, so this is a candidate-selection boundary
only.

The same Entertainment Area update body at `0x48C030` (a virtual/table-driven
entry not emitted as a split function) calls `FUN_0048BE00 @ 0x48BE00` four
times for figure models `32`, `34`, and `33` and once per non-empty slot for
dispatch model `0x26`/`38`.  The exact raw output table is:

| dispatch model | slot | first word | second word |
| ---: | ---: | ---: | ---: |
| 32 | ignored | `0xAF` | `-0x2D` |
| 33 | ignored | `0x97` | `0x12` |
| 34 | ignored | `0x3E` | `-0x30` |
| 38 (`0x26`) | 0…9 | `0xFD,0x3F,0xD6,0x5F,0x75,0xD5,0xB5,0xBE,0x82,0xA0` | `0x29,0x24,0x32,0x35,0x46,0x47,0x42,0x56,0x4C,0x5A` |

`FUN_0048BE00` has four direct callers at `0x48C059`, `0x48C0AA`,
`0x48C0E9`, and `0x48C15D` in both PE images; its EN/CH split rows are
`identical` (`compare-report.tsv` row `0x48BE00`).  `GameData/Model/
EmperorFigureModels.txt` identifies rows `32/33/34` as acrobat/actor/Musician
and row `37` as Festival Performer, but the pair words themselves have no
recovered player-facing label.  Native records them as raw research data in
`OriginalResidentialServiceCatalog`; neither helper allocates figures,
performs route probes, registers providers, or writes house coverage.

**Sources:** canonical EN/CH PE direct-call census and disassembly for
`0x48A350`, `0x4D1BD0`, `0x48BE00`, and `0x48C030`;
`local/source/split-merged/code/0x040000/FUN_0048a350.c`,
`FUN_0048be00.c`, `FUN_0048c000.c`, `FUN_0048c270.c`,
`local/source/compare-report.tsv`; `GameData/Model/EmperorBuildingModels.txt`;
`GameData/Model/EmperorFigureModels.txt`; and
`Sources/EmperorCore/HousingEvolution.swift`.

**Evidence class:** **confirmed** for the model-75 filter, `+0x19C` gate,
route-probe call/order, Chebyshev strict-minimum selection, raw pair values,
direct caller addresses, and EN/CH parity; **unknown** for route-probe
semantics, coordinate-pair meaning, pair-word presentation, provider registry,
and downstream venue/house settlement.

### 10.6j Qin service constructors do not encode the provider registry slot (confirmed negative, 2026-09-03)

The service-factory and constructor chain was rechecked for an overlooked
provider-index assignment.  `FUN_0051BEF0 @ 0x51BEF0` allocates `0x150` bytes
for Well (`0x48/0x49`), Herbalist (`0xCF`), and Acupuncture (`0xD0`) and
dispatches to `FUN_0051C090`, `FUN_0051C0B0`, or `FUN_0051C0D0`.  Each
constructor calls the shared `FUN_0051BA50`, which calls `FUN_0051C9A0` and
then installs its class vtable (`0x7B5EB4`, `0x7B6114`, or `0x7B6374`).
The EN/CH rows for the indexed constructors are `identical`.

The shared base initializer `FUN_0051C2E0 @ 0x51C2E0` clears the provider
state words and bytes, including word `+0x16`, byte `+0x6F`, and the packed
service fields, then sets byte `+0x69 = 1`.  It contains no explicit store to
the provider registry/index word at `param[0x2D]` (byte offset `+0xB4`).
`FUN_0051C9A0` likewise only runs the generic base initializer, the service
state initializer, and sets its own `+0x14C` sentinel.  Therefore the
constructor chain cannot be used as the missing source of the serialized
provider index; any value observed at `+0xB4` must come from the generic
allocation/zeroing or a later copy/registration path.

This is a **confirmed negative** for a constructor-local provider-slot
assignment.  It narrows, but does not solve, the Qin map-load blocker: the
specialized vtable must still be installed before `+0xC0` can run
`FUN_0051CB80`, while the source of the slot, any indirect replacement, and
the provider-list/house-settlement projection remain **unknown**.  Native
keeps Well, Herbalist, Acupuncture, and entertainment registration
fail-closed and does not derive a provider ID from the building model alone.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051bef0.c`,
`FUN_0051c090.c`, `FUN_0051c0b0.c`, `FUN_0051c0d0.c`, `FUN_0051ba50.c`,
`FUN_0051c9a0.c`, `FUN_0051c2e0.c`; `local/source/compare-report.tsv` rows
`0x51BEF0`, `0x51C090`, `0x51C0B0`, `0x51C0D0`, `0x51BA50`, `0x51C9A0`,
`0x51C2E0`; and the provider vtable/load boundary in §§7.3a, 7.3n, and
10.3.

**Evidence class:** **confirmed** for allocation size, model dispatch,
constructor/vtable order, cleared state fields, absence of an explicit
`+0xB4` store, and EN/CH parity; **confirmed negative** for a
constructor-local registry writer; **unknown** for allocator zeroing,
post-construction copies, indirect specialization, registry ownership, and
house/route settlement.

### 10.6k Corpus-wide `+0xB4` store census adds no provider-family writer (confirmed negative, 2026-09-03)

To check that the constructor result was not an artefact of inspecting only a
few split files, I scanned the `.text` section of both canonical PE inputs for
every decoded `mov` whose destination memory operand has displacement
`+0xB4`.  The EN and CH images each contain 113 such instructions at the same
addresses.  Most are stack slots or unrelated UI/manager records.  Within the
service/entertainment factory and lifecycle set (`0x48A7E0`, `0x48A800`,
`0x48A8E0`, `0x48A900`, `0x48A920`, `0x48B540`, `0x48B560`, `0x48C230`,
`0x48C270`, `0x51BA50`, `0x51BEF0`, `0x51C090`, `0x51C0B0`, `0x51C0D0`,
`0x51C2E0`, `0x51C9A0`, `0x51CAA0`, and `0x51CB80`) there is no direct
`+0xB4` store.  `FUN_0051CAA0` reaches the field only by delegating to the
generic `FUN_00426EA0` copier.

The remaining provider-relevant stores are therefore the already bounded
generic paths: `FUN_00426EA0 @ 0x426EA0` copies source `+0xB4` into the
destination during `FUN_00427150`, and `Creating_pctd_type_pctd @ 0x42D540`
stores the explicit object-table index at `p[0x2D]` (`+0xB4`) after
`FUN_0042D360` returns.  No additional direct store in either PE supplies a
Well/Herbalist/Acupuncture or entertainment registry slot.  This scan does
not rule out an indirect virtual/table-driven alias, and it does not identify
which serialized field producer feeds the generic copier.

**Sources:** canonical EN/CH `EmperorEN.exe` and `EmperorCH.exe` `.text`
disassembly; `local/source/split-merged/code/0x040000/FUN_00426EA0.c`,
`FUN_00427150.c`, `Creating_pctd_type_pctd.c`; provider constructor/load files
listed in §10.6j; and the identical EN/CH rows in
`local/source/compare-report.tsv` for the service/entertainment functions.

**Evidence class:** **confirmed negative** for an additional direct
provider-family `+0xB4` writer in the indexed instruction census; **confirmed**
for the generic-copy and explicit object-table assignment boundaries;
**unknown** for indirect aliases, serialized-field production, registry
ownership, and downstream route/house settlement.

### 10.6k Model-23 initial exit direction keeps the cache/callback boundary (2026-09-03)

The first direction chosen by the common service/peddler bootstrap is now
bounded at `FUN_004E6690 @ 0x4E6690`. The function reads four cardinal
direction words from the per-cell map-cache views and masks each with
`0x440`. When a word also carries bit `0x8`, it resolves the adjacent object
through the map registry and suppresses that direction only when the object's
virtual `+0xE8` callback returns non-zero. The admitted headings remain the
source table order `0, 2, 4, 6`.

For one admitted direction the function returns it directly. For exactly two,
it starts at the figure's current heading (`+0x19`) and rotates by the signed
increment (`+0x50`), accepting the first candidate that is not the normalized
forbidden heading; the loop is bounded to four attempts. Three or four
directions enter the saved map-byte/crossing-count and fallback-RNG branch,
which is not collapsed into this helper because its random call order and
object-table projection are still unresolved.

This is represented by the pure
`OriginalResidentialServiceCatalog.InitialExitDirection` helper and its
focused regression. It records the executable's candidate mask and callback
polarity without wiring a Native road graph, treating a missing callback as
approval, or enabling Qin market/service figures. The map-cache producer,
multi-way RNG state, and downstream route/coverage effects remain unknown.

**Sources:** canonical EN/CH `EmperorEN.exe` / `EmperorCH.exe`;
`local/source/split-merged/code/0x040000/FUN_004e6690.c`,
`FUN_004e6a70.c`, `FUN_004e71d0.c`, and the corresponding identical rows in
`local/source/compare-report.tsv`; implementation in
`Sources/EmperorCore/HousingEvolution.swift`; regression in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the `0x440` mask, conditional `0x8`
callback suppression, heading order, one/two-candidate rotation, and four
attempt bound; **unknown** for the multi-way saved-byte/RNG path, map-cache
projection, and route/provider settlement.

### 10.6l Model-23 multi-way exit selection preserves the fallback-counter seam (2026-09-03)

The three/four-candidate branch of `FUN_004E6690 @ 0x4E6690` is now recorded
without pretending to recover its random source. After the candidate count is
greater than two, the executable forms the initial heading as
`(savedMapByte + figure[+0x4F]) & 0x06`, where the first term is the per-cell
byte read from `DAT_00F1E780` and the second is the figure's crossing/turn
counter. If that heading is absent from the admitted `0,2,4,6` table or equals
the normalized forbidden heading, it decrements figure byte `+0x51`. Only
when the decremented value is below `1` does it call `FUN_004E71D0`; that
callee's returned heading and signed rotation increment then clear the
forbidden heading for the subsequent bounded search. The selector rotates by
the current increment for at most four attempts and returns failure when no
candidate is found.

`InitialExitDirection.selectMultiWay` exposes this arithmetic as a pure
contract. The caller must provide the saved map byte, turn counter, current
increment, fallback counter, and (when the counter crosses the threshold) the
explicit result of `FUN_004E71D0`; absent fallback output returns `nil` and is
not replaced with a deterministic guess. Focused regression covers direct
selection, counter decrement without fallback, fallback invocation/reset, and
malformed candidate input.

The source addresses, branch order, byte mask, counter threshold, four-attempt
bound, and EN/CH-identical bodies are **confirmed** from
`FUN_004e6690.c`, `FUN_004e71d0.c`, and `compare-report.tsv`. The producer of
`DAT_00F1E780`, the exact random stream and tie updates inside
`FUN_004E71D0`, object callback projection, and route/provider settlement
remain **unknown**. This narrows the initial-exit blocker but does not justify
wiring Qin service, venue, or peddler figures to the Native road graph.

**Sources:** canonical EN/CH PE inputs; `local/source/split-merged/code/
0x040000/FUN_004e6690.c` and `FUN_004e71d0.c`; implementation in
`Sources/EmperorCore/HousingEvolution.swift`; regression in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the multi-way arithmetic, fallback
counter threshold, fallback handoff, rotation bound, and EN/CH parity;
**unknown** for map-byte production, RNG sequence, object projection, and
downstream route/coverage settlement.

### 10.6m `FUN_004E71D0` minimum-visit fallback is explicit for residential figures (2026-09-03)

The fallback callee used by the multi-way exit branch is now separated at its
non-negative visit-selector path. `FUN_004E71D0 @ 0x4E71D0` scans the four
even headings in `DAT_0085DE64` order (`0,2,4,6`) and calls
`FUN_004B9440` for each admitted map neighbour. A strictly smaller visit
value replaces the current minimum and resets the tie count to `2`. An equal
minimum increments the tie count and replaces the selected heading only when
the next `FUN_004189B0` value is non-zero modulo that count. After the scan,
the next RNG low bit selects `+0x50 = 2` for even or `0xFE` (`-2`) for odd,
and the fallback counter `+0x51` is reloaded to `5`.

`InitialExitDirection.selectFallback` records this algorithm with explicit
visit scores and RNG outputs. It rejects duplicate/non-cardinal headings and
missing tie RNG values rather than supplying a deterministic stream. This is
the source branch used by the supported residential figure model selectors;
the separate negative-selector branch, map-word producer, and object-table
projection remain outside the helper.

The scan order, strict-minimum/tie update, modulo rule, signed increment,
counter reload, and EN/CH parity are **confirmed** from
`FUN_004e71d0.c`, `FUN_004b9440.c`, `FUN_004189b0.c`, and
`compare-report.tsv`. The visit-field producer, exact RNG state evolution,
negative-selector branch, and route/provider settlement remain **unknown**.
This closes the fallback arithmetic only; Qin service, venue, and peddler
figures remain fail-closed.

**Sources:** canonical EN/CH PE inputs; `local/source/split-merged/code/
0x040000/FUN_004e71d0.c`, `FUN_004b9440.c`, and `FUN_004189b0.c`;
implementation in `Sources/EmperorCore/HousingEvolution.swift`; regression
in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the supported fallback branch's scan,
tie, RNG-low-bit, and counter semantics; **unknown** for score/RNG producers,
the negative-selector branch, object projection, and downstream settlement.
### 7.3aq Well vtable `+0x1DC` is a non-zero geometry offset, not the common no-op (confirmed, 2026-09-03)

The water-provider vtable has one geometry distinction that is easy to miss in
the indexed decompilation.  Direct PE vtable reads at the canonical image
base show:

| provider vtable | authored IDs | slot `+0x1DC` |
| ---: | ---: | ---: |
| `0x007B5EB4` | Well `72/73` | `0x0051BB50` |
| `0x007B6114` | Herbalist `207` | `0x0066DB00` |
| `0x007B6374` | Acupuncture `208` | `0x0066DB00` |

`FUN_0066DB00 @ 0x66DB00` is indexed and returns a zero `UInt16`.  The Well
target at `0x51BB50` is not present in `functions-index.csv`, but the raw EN
and CH `.text` bytes are identical (`66 B8 A3 FF C3 90 90 90`): it loads
`AX = 0xFFA3` and returns, i.e. signed `-93`.  The surrounding canonical
vtable slices are also byte-identical between the English build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
Chinese build `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

`FUN_0042AE50 @ 0x42AE50` consumes this slot through a virtual call and then
selects the returned offset by object byte `+0x07` and global direction
`DAT_0101D0D0`.  For the Well vtable's `-93`, the recovered helper emits the
following signed `(xOffset, yOffset)` pairs:

| object `+0x07` | direction `0` | direction `2` | direction `4` | direction `6` |
| ---: | ---: | ---: | ---: | ---: |
| `3` | `(0, +0x40)` | `(+0x7C, +6)` | `(0, -0x38)` | `(-0x78, +6)` |
| `4` | `(0, +0x78)` | `(+0xA0, +0x28)` | `(0, -0x28)` | `(-0xA0, +0x28)` |

Other direction values follow the helper's default branches; no new model or
provider identity is introduced there.  This is a geometry/access-point
input only: the indexed corpus has no direct caller proving that this helper
is the missing Qin archive-specialization edge, and the generic map loader
still constructs the base `Building` class.  Therefore the Well `+0x1DC`
offset must not be used to synthesize a provider registry entry or house
coverage.  Native records the distinction as research evidence only; the Qin
water and migration gates remain fail-closed.

**Sources:** canonical EN/CH PE vtable words at `0x007B5EB4`, `0x007B6114`,
and `0x007B6374`; raw `.text` bytes at `0x0051BB50` and `0x0066DB00`;
`local/source/split-merged/code/0x040000/FUN_0042ae50.c`,
`local/source/split-merged/code/0x060000/FUN_0066db00.c`, and
`local/source/compare-report.tsv` row `0x42AE50`/`0x66DB00`.

**Evidence class:** **confirmed** for the vtable slot targets, Well constant
`-93`, common zero implementation, EN/CH byte identity, and the
`FUN_0042AE50` direction/level arithmetic; **unknown** for the semantic name,
caller timing, archive projection, provider registration, and house
settlement.

### 10.6n Byte `+0x2d` and dword `param[0x2d]` are separate fields (confirmed negative, 2026-09-03)

The provider-index notation used by the lifecycle code is now made explicit.
The indexed decompiler prints `param_1[0x2d]` for a four-byte load at object
offset `+0xb4`; this is the value consumed by `FUN_0051CCA0`,
`FUN_0051D0C0`, `FUN_0051DBD0`, `FUN_0051CB80`, and `FUN_0051CAD0` when they
resolve or allocate a registry object.  The common serializer and copier
likewise operate on `+0xb4` as a dword (`FUN_00427430` and
`FUN_00426EA0`).  It must not be abbreviated as a byte `+0x2d` field when
reasoning about the provider registry.

There is a real byte `+0x2d` in the separate house-information layout.  The
EN/CH split bodies show `FUN_00517190` zeroing it, `FUN_00517280` applying the
ordinary `< 2 ? 0 : -1` decay, and `FUN_00517330` adding `0x1e` to the house
score when it is non-zero.  `FUN_0051BD00` writes byte `+0x2d` through the
provider vtable `+0x1e4` return, so its destination is the returned
`cHouseInfo` object, not the provider's `param[0x2d]` dword.  The provider
constructor family (`FUN_0051BEF0`, `FUN_0051C090`, `FUN_0051C0B0`,
`FUN_0051C0D0`, `FUN_0051BA50`, `FUN_0051C9A0`, `FUN_0051C2E0`) contains no
explicit store that supplies the provider-index dword; the only provider-side
copy reaches `+0xb4` by delegating to `FUN_00426EA0`.

This is a confirmed negative for treating a house byte `+0x2d` write as the
missing provider registry assignment.  It also explains why the existing
`+0x2d` search has both score/decay hits and provider-index reads: they are
different offsets and object layouts.  The serialized producer, any
indirect/table-driven provider assignment, and final registry/house
projection remain **unknown**; Native keeps the Qin provider bridge
fail-closed.

**Sources:** canonical EN/CH hashes; `local/source/split-merged/code/0x050000/
FUN_00517190.c`, `FUN_00517280.c`, `FUN_00517330.c`, `FUN_0051BD00.c`,
`FUN_0051CCA0.c`, `FUN_0051D0C0.c`, `FUN_0051DBD0.c`, `FUN_0051BEF0.c`,
`FUN_0051C090.c`, `FUN_0051C0B0.c`, `FUN_0051C0D0.c`, `FUN_0051BA50.c`,
`FUN_0051C9A0.c`, `FUN_0051C2E0.c`; `local/source/split-merged/code/0x040000/
FUN_00426EA0.c`, `FUN_00427430.c`, `Problems_creating_guid.c`; and the
corresponding `identical` rows in `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the two offset interpretations, the
house-byte writer/decay/score chain, constructor-local negative, and EN/CH
parity; **unknown** for allocator zeroing, serialized-field production,
indirect aliases, registry ownership, and downstream settlement.

### 10.6o Provider `+0x268` has class-specific targets, not a global occupancy predicate (confirmed, 2026-09-03)

The provider vtable slot `+0x268` can now be tied to concrete class targets,
while preserving its polymorphic meaning.  Direct `.rdata` reads at the
canonical image base give the same EN/CH mapping:

| provider vtable | authored IDs | slot `+0x268` | target-body shape |
| ---: | ---: | ---: | --- |
| `0x7B5EB4` | Well `72/73` | `0x51CE00` | body is an indexed wrapper around common `FUN_00427430` serialization and post-load hooks |
| `0x7B6114` | Herbalist `207` | `0x51CE00` | same shared target body |
| `0x7B6374` | Acupuncture `208` | `0x51C3A0` | body has an archive-mode branch over offsets `+0x04`, `+0x06`, `+0x4E`, `+0x5C…+0x80` |

`FUN_0051CE00 @ 0x51CE00` is present in the split corpus and calls
`FUN_00427430`, then the auxiliary object's `+8` callback before its common
post-load cleanup.  The Acupuncture target `0x51C3A0` is not emitted as a
separate `functions-index.csv` body; raw EN/CH `.text` disassembly shows the
archive-mode branch and fixed field sequence above, with no direct call to
`FUN_00427430` and no direct access to provider `+0xB4` inside that body.  The
next decoded function boundary is `0x51C620`, so the factory code following
`0x51C61C` is not attributed to the `0x51C3A0` body.

These target bodies are evidence about the concrete implementations only.
The `+0x268` slot itself is dispatched by unrelated callers with different
return conventions (boolean, pointer, or numeric ID in the bounded census of
§7.3), so its semantic name and call-site contract remain unresolved.  The
slot must not be promoted to a universal serializer, occupancy test, or
provider-registration hook.

This closes only the class-to-target distinction, not the caller or
replacement order.  A `+0x268` dispatch therefore cannot be generalized into
one Native occupancy, registry, or provider-state field.  The indirect caller,
serialized producer, post-load registration, and house settlement remain
**unknown**; Native keeps the Qin bridge fail-closed.

**Sources:** canonical EN/CH vtable words at `0x007B5EB4`, `0x007B6114`, and
`0x007B6374`; `local/source/split-merged/code/0x050000/FUN_0051ce00.c`;
`local/source/split-merged/code/0x040000/FUN_00427430.c`;
`local/source/split-merged/functions-index.csv`; raw `.text` disassembly at
`0x0051C3A0`/`0x0051C620`; and the corresponding `identical` rows in
`local/source/compare-report.tsv`; research-only catalog
`OriginalResidentialServiceCatalog.providerVTableSlot268Descriptors` and its
focused regression in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the vtable slot targets, target-body
shapes, EN/CH parity, and function boundary; **unknown** for the slot's
semantic name at each call site, the meaning of `0x51C3A0`, its indirect
caller, replacement/registration order, serialized producer, and downstream
service settlement.

### 10.6p Provider `+0x1FC` is an existing-auxiliary refresh gate (confirmed, 2026-09-03)

The final virtual dispatch in `FUN_0051CB80 @ 0x51CB80` is now closed at its
interior target.  Direct little-endian reads from the canonical EN and CH
images show `0x0051CC10` at slot `+0x1FC` for Well (`0x7B5EB4`), Herbalist
(`0x7B6114`), Acupuncture (`0x7B6374`), Entertainment Area (`0x7AD878`),
Music School (`0x7ACEDC`), Acrobat School (`0x7AD140`), and Drama School
(`0x7AD3A4`).  The 16-byte slice at `0x51CC10` is identical in both images:
it loads provider `+0x14C`, returns when that pointer is null, and otherwise
tail-jumps to `FUN_00418D90 @ 0x418D90`.

`FUN_00418D90` clears auxiliary `+0x0C`, dispatches auxiliary vtable `+0x14`
and `+0x08`, stores the latter result at auxiliary `+0x08`, and calls the
common `+0xE80` finalizer.  It never writes provider `+0xB4`, inserts an
object-vector entry, reads a map archive record, or projects a house-service
byte.  The callback therefore refreshes an auxiliary object that must already
exist; it is not a hidden provider-registration or map-load specialization
edge.

The raw addresses are recorded in
`OriginalResidentialServiceCatalog.providerLoadAuxiliaryDescriptor`.
Auxiliary method semantics, the source of provider `+0x14C`/`+0xB4`, indirect
specialization, registry ownership, and provider-to-house settlement remain
unknown; Native continues to keep Qin provider behavior fail-closed.

**Sources:** canonical EN/CH vtable words above; raw `.text`
`0x51CC10…0x51CC1F`; `FUN_0051CB80.c`, `FUN_00526830.c`, and
`FUN_00418D90.c`; `local/source/compare-report.tsv` rows for indexed
functions; and `Sources/EmperorCore/HousingEvolution.swift`.

**Evidence class:** **confirmed** for all seven vtable targets, the exact
null gate, tail call, auxiliary field updates, and EN/CH identity; **unknown**
for auxiliary method semantics, archive/provider provenance, indirect
specialization, registry ownership, and settlement.

### 10.6q Canonical PE-wide `vtable +0x18` census adds no Qin load edge (confirmed negative, 2026-09-04)

The earlier map-band scan was extended to the complete `.text` section of
both hash-matched executables.  Searching the raw instruction bytes for all
`FF 5? 18` forms (the x86 encodings of `call dword ptr [register + 0x18]`)
finds exactly 84 sites in each image, at the same virtual addresses and with
the same three instruction bytes.  The complete address set is:

```text
0x42F1ED  0x435ED1  0x44ADD2  0x44D799  0x44D8C0  0x44DD07
0x4669A2  0x46B913  0x477E76  0x4E18F9  0x4E6349  0x4EC4AC
0x4F3A89  0x4F3C21  0x4F3E0E  0x4F43F1  0x4F49F3  0x4F7B7B
0x50373D  0x5126D6  0x5126F4  0x512B50  0x512E16  0x514872
0x515AA5  0x52325C  0x5234E7  0x53B05C  0x53B124  0x541137
0x54FCE2  0x54FEF9  0x55AE04  0x55B757  0x55B789  0x55B7AA
0x55DCFC  0x563FCA  0x578775  0x57BC3F  0x57D35D  0x5894DD
0x5B4C90  0x5B4E26  0x5C04B6  0x5C766C  0x5C76E9  0x5C7726
0x5C7775  0x5D0D5A  0x5FCC8C  0x602B50  0x6143AC  0x6163E6
0x6163FA  0x616508  0x616843  0x616928  0x617A5F  0x617FD3
0x62DA25  0x640CEC  0x644C87  0x646B40  0x646D2C  0x64D03F
0x65405A  0x65B4AD  0x65D94B  0x65F0F4  0x6C4477  0x6C62CB
0x6C6FD1  0x6CDAB6  0x6E522A  0x6E5E32  0x6E5F04  0x735E74
0x73EB9F  0x7403A6  0x7456B8  0x747929  0x756DBE  0x7803DF
```

The four sites inside the loader's address neighborhood are the already
bounded non-loader paths:

| site | containing body | receiver/source recovered from the body |
| ---: | --- | --- |
| `0x52325C` | `FUN_00522D30` | newly allocated figure used by the figure/route creation loop; initializes the figure before the later state write at `0x5234E7` |
| `0x5234E7` | `FUN_00522D30` | newly allocated figure used by the figure/route creation loop; the call is followed by figure state writes, not a map `Building` insertion |
| `0x53B05C` | `FUN_0053B000` | object returned by the global object/overlay aggregation path; state predicate, not archive deserialization or factory dispatch |
| `0x53B124` | `FUN_0053B000` | object returned by the global object/overlay aggregation path; the result is consumed as a state predicate, with no archive read, factory dispatch, or list replacement |

The remaining game-logic sites have similarly closed or non-loader shapes:
`0x541137` is the cStall/transient `FUN_00541110` callback path;
`0x5C04B6` scans the existing object registry for a matching value;
`0x5C766C`/`0x5C76E9` are branches of the figure/AI status aggregator;
`0x4E6349`, `0x515AA5`, and the `0x5126D6`/`0x5126F4` pair query figure or
class tables; and `0x54FCE2`/`0x54FEF9` invoke callbacks on figures created by
the military/event allocation loop.  `0x4EC4AC`, `0x50373D`, and the remaining
sites outside the gameplay band are generic object, graphics, UI, or engine
state callbacks; their bodies do not call the map archive loader or a
provider factory.  Where a raw site lies inside an unindexed function
interior (`0x512B50`, `0x514872`, and several graphics bodies), the receiver
class is left **unknown** rather than inferred from the slot number.

The actual Qin load chain (`FUN_0052E7C0 → FUN_0042D790 → FUN_0042D0E0`,
followed by `FUN_0053D100`/`FUN_0052F030`) contains no `FF 50 18` site, and no
site in the full census has a recovered edge to `FUN_0042D360`, a provider
constructor, provider-index `+0xB4` assignment, or replacement of the
generic archive-list entry.  EN/CH source rows for the indexed containing
bodies remain `identical`; the raw callsite bytes are also identical at all
38 addresses.

This is a **confirmed negative** for a PE-visible virtual `+0x18` map-load
specialization trigger.  It is not proof that an unindexed table/data
dispatch or a runtime-only hook cannot replace a generic record.  The
serialized provider-index producer, any such indirect replacement, and
post-load registry ordering therefore remain **unknown**.  Native keeps Qin
service/provider reconstruction and desirability projection fail-closed.

**Sources:** canonical EN PE
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
PE `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`;
raw `.text` byte census for all `FF 5? 18` register forms;
`local/source/split-merged/
functions-index.csv`; and the indexed bodies
`FUN_004E6280.c`, `FUN_004EC4A0.c`, `FUN_00503720.c`,
`China_UnknownHero.c`, `FUN_00515A40.c`, `FUN_00522D30.c`,
`FUN_0053B000.c`, `FUN_00541130.c`, `FUN_0054F8D0.c`,
`FUN_005C0490.c`, `FUN_005C6DA0.c`, and `FUN_005D0D30.c`, together with the
loader bodies cited in §§7.3m, 7.3s, 7.3aa, and 7.3an.

**Evidence class:** **confirmed** for the 84-site EN/CH census, identical
callsite bytes, loader-band classification, and absence of a recovered
factory/replacement edge; **unknown** for unindexed table/data dispatch,
runtime-only hooks, and provider registry/settlement projection.

### 10.6r Entertainment-school coverage dispatch boundary (confirmed, 2026-09-04)

The three entertainment-school providers share the crossing scanner used by
the other residential providers, but not its callback body.  At each
20-substep crossing, `FUN_004EACD0` invokes the home/provider `+0x28` method;
the school vtables at `0x7ACEDC` (Music, model `211`), `0x7AD140` (Acrobat,
model `212`), and `0x7AD3A4` (Drama, model `213`) all point `+0x28` to
`FUN_00429DF0 @ 0x429DF0`.  That wrapper enters `FUN_00429E10` with radius
`2`, whose admitted candidates are then dispatched through provider `+0x2C`
to `FUN_0048AD20 @ 0x48AD20`.  The EN/CH rows for `0x4EACD0`, `0x429DF0`,
`0x429E10`, and `0x48AD20` are identical; the three vtable words and the
unsplit callback body are byte-identical in the two hash-matched PEs.

This closes the entertainment coverage dispatch boundary and is represented
by `EntertainmentCoverageDispatchDescriptor.canonical`.  It does **not**
resolve the school/provider registry source, venue route/collision result,
or terminal settlement, so Native still does not invoke this callback from
Qin's live walker.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004eacd0.c`,
`FUN_00429df0.c`, `FUN_00429e10.c`, `local/source/compare-report.tsv`,
canonical EN/CH vtable words at `0x7ACEDC/0x7AD140/0x7AD3A4`, and the direct
PE body at `0x48AD20`; `Sources/EmperorCore/HousingEvolution.swift` and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the shared crossing/scanner chain,
radius, vtable offsets, callback address, and EN/CH parity; **unknown** for
provider registry projection, route/collision outcomes, and settlement.

### 2026-09-04 Venue performance callback actor-counter transition

The direct EN/CH body at `0x48B710` is identical. Models `32`, `33`, and `34`
write `0x20` to provider-record bytes `+0x5D`, `+0x5F`, and `+0x5E`; only
model `33` touches `+0x64`. That branch performs a byte increment, stores the
incremented value, and clears it when the result is `>= 5`. Consequently
`0…3 → 1…4`, `4 → 0`, and `0xFF → 0` by byte wrap without the `>=5` reset
branch. Native records this as
`entertainmentVenuePerformanceTransition`; provider registration, route/
collision, dispatch cadence, and house settlement remain unresolved.

**Sources:** canonical EN/CH `.text` slices `0x48B710…0x48B77C`,
`local/source/compare-report.tsv` rows for the surrounding venue FSM, and
the regression in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the writes and byte arithmetic;
**unknown** for the auxiliary counter's semantic meaning and all downstream
venue lifecycle effects.

### 2026-09-04 Dynamic factory admission metadata is explicit for Qin service families

The Qin-relevant constructor rows now retain the complete admission envelope,
not only their leaf initializer and vtable. `FUN_0051C660 @ 0x51C660` is the
shared dynamic-factory entry. Its residential-service predicate
`FUN_0051BE30 @ 0x51BE30` admits Well models `0x48/0x49` (72/73), Herbalist
`0xCF` (207), and Acupuncture `0xD0` (208), after which
`FUN_0051BEF0 @ 0x51BEF0` allocates exactly `0x150` bytes and selects
`FUN_0051C090`, `FUN_0051C0B0`, or `FUN_0051C0D0` with vtables
`0x7B5EB4`, `0x7B6114`, or `0x7B6374`.

The entertainment predicate `FUN_0048A7E0 @ 0x48A7E0` admits school models
`0xD3/0xD4/0xD5` (211/212/213); `FUN_0048A800 @ 0x48A800` allocates the same
`0x150` bytes and selects initializers `0x48A8E0/0x48A900/0x48A920` with
vtables `0x7ACEDC/0x7AD140/0x7AD3A4`. Native stores the dispatcher,
predicate, allocation size, initializer, and vtable in the two factory
descriptor tables and regression-tests every row. This is constructor
metadata only: it does not specialize generic Qin archive records, assign
`+0xB4`, register providers, route figures, or settle house coverage.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051c660.c`,
`FUN_0051be30.c`, `FUN_0051bef0.c`, `FUN_0051c090.c`, `FUN_0051c0b0.c`,
`FUN_0051c0d0.c`; `local/source/split-merged/code/0x040000/FUN_0048a7e0.c`,
`FUN_0048a800.c`, `FUN_0048a8e0.c`, `FUN_0048a900.c`, `FUN_0048a920.c`;
`local/source/compare-report.tsv`; and the focused factory-catalog
regressions in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the shared entry, family predicates,
model sets, allocation size, leaf initializer, vtable, and EN/CH parity;
**unknown** for archive specialization, provider-slot ownership, registry
projection, route/collision, and house settlement.

### 2026-09-04 Provider parent-link walk is a bounded `+0x3C` chain

`FUN_004B3930 @ 0x4B3930`, reached by `FUN_004B38C0 @ 0x4B38C0`, is now
recorded as a standalone field-level boundary. Starting from a registry ID,
the function resolves the object through `FUN_0047F1B0`, reads the signed
16-bit parent link at object offset `+0x3C`, and returns the current ID as soon
as that link is below `1`. A positive link becomes the next registry ID and
the loop repeats for at most `500` iterations; if all 500 links are positive,
the executable returns `0`. This is the exact loop order, including the
strict `< 1` root test and the source's hop-limit result.

`OriginalWaterProviderState.resolveRegistryParentChain` mirrors that arithmetic
for an explicitly supplied `[registryID: parentID]` map. Missing entries are
reported as a separate fail-closed result rather than being treated as a root;
the helper does not invent a registry slot or use Native house IDs. It stops
before `FUN_004B38C0`'s subsequent root virtual checks and `+0xB4` read, whose
receiver and provider meaning remain unresolved.

The chain is used by provider-side callers such as `FUN_0051DBD0`, but no
caller in the inspected map-load path supplies a recovered Qin archive index
or parent link. Therefore this closes only the parent traversal boundary;
provider registry provenance, archive assignment, route/occupancy, and house
settlement remain **unknown**, and the Native Qin bridge stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004b3930.c`,
`FUN_004b38c0.c`, `FUN_0047f1b0.c`; provider caller
`local/source/split-merged/code/0x050000/FUN_0051dbd0.c`; corresponding
`identical` rows in `local/source/compare-report.tsv`; and the focused
regression in `Sources/EmperorCore/HousingEvolution.swift` plus
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the `+0x3C` signed read, root polarity,
500-iteration bound, and return order; **unknown** for missing-registry
behavior outside the supplied pure input map, the later root virtual checks,
archive parent-link producer, and all provider/house settlement effects.

### 2026-09-04 Generic archive insertion appends in stream order without assigning `+0xB4`

The generic map loader's vector insertion can be separated from the explicit
creation index writer.  `FUN_0042D790 @ 0x42D790` passes the address of its
decoded local object pointer to `FUN_0042B590 @ 0x42B590`.  That helper obtains
the current vector end through `FUN_004F8200 @ 0x4F8200` and calls
`FUN_005F01F0 @ 0x5F01F0`; the latter computes the source-slot offset and calls
`FUN_005C1670 @ 0x5C1670` with insertion position equal to the current end and
count `1`.  The result is an append of the decoded object pointer in stream
order.  None of these bodies writes object `+0xB4`; that field remains the
serializer's `-1` for the generic Qin records documented in §7.3ae.

Native records this as `OriginalMapArchiveRuntimeClassCatalog` insertion
metadata and regression-tests the helper addresses, append position, count,
and the explicit no-`+0xB4` write boundary.  This closes only vector ordering;
it cannot turn a stream ordinal or append position into the provider registry
slot assigned by `Creating(...)`.  Archive specialization, provider registry
ownership, route/coverage, and house settlement therefore remain **unknown**;
Qin service loading stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042d790.c`,
`FUN_0042b590.c`, `FUN_004f8200.c`,
`local/source/split-merged/code/0x050000/FUN_005f01f0.c`,
`FUN_005c1670.c`, and canonical EN/CH instruction slices at
`0x42D8E7…0x42D91A`; `Sources/EmperorCore/MapArchiveClassCatalog.swift`;
and `testMapArchiveRuntimeClassDispatchMatchesMFCReaderBoundary`.

**Evidence class:** **confirmed** for the append-at-vector-end call chain,
single-element insertion, and absence of a `+0xB4` assignment in that chain;
**unknown** for any later indirect specialization or provider registration.
