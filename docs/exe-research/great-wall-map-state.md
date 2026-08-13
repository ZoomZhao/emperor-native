# Great Wall campaign object and save state

## Scope and sources

This note records the original campaign state used by the predetermined Great
Wall layouts. It covers the hash-identified English executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`.
The indexed `local/source` comparison classifies the named functions below as
shared with the Chinese build unless otherwise noted. The corpus is generated
decompiler output, so object-field names below are semantic descriptions based
on callers and authored data, not recovered C++ declarations.

Corroborating authored sources are:

- `GameData/Model/Mon_Great_Wall_01_subs.txt` through
  `Mon_Great_Wall_16_subs.txt`;
- `GameData/Model/SB_GREAT_WALL.txt`, `SB_GREAT_WALL_TOWER.txt`, and
  `SB_GREAT_WALL_GATE.txt`;
- `GameData/DATA/China_Mon_Earthen_Greatwall_1.sg3` (243 entries; group 1
  starts at local image 201);
- `GameData/Cities/Badaling.map`;
- the Great Wall construction section of `GameData/EmperorManual.pdf`.

Two runtime-oriented probes supplement those sources without changing their
evidence priority:

- a local historical save named `历史战役自动保存_1.sav` (SHA-256
  `4595309c42ff910f58796b15871383c4636d5eb0642edb40437ab8b6904dca96`;
  preserved outside the repository) contains a byte-for-byte
  aligned copy of the Badaling static map-image layer at a constant decoded
  offset, but its serialized 4,000-slot `Building` collection has building ID
  zero in every base payload. It therefore confirms only that the Badaling
  layer was present in that save container; it contains no live Great Wall
  object from which an unfinished phase can be recovered;
- an isolated launch of the hash-matched build under the available Wine /
  DirectDraw wrapper remained on a black transition frame. The public
  [GamerZakh playthrough “Mission 24 Emperor Qin's Great Wall - Badaling”](https://www.youtube.com/watch?v=n7Vtc8EEimY)
  was also located, but the accessible YouTube player returned a sign-in/bot-check
  screen and exposed no video stream to the read-only browser or `yt-dlp`
  probe. No frame or timestamp from that upload is classified as observed.

Classification: the save-container alignment, empty building IDs, and failed
runtime/video access are `confirmed` negative evidence. They do not establish
the save's exact campaign transition moment or any Qin-4 initial phase value.

## Multipart `Building` records

1. `FUN_0042D790 @ 0x42D790` serializes the city's main building collection.
   Its write path emits the object count and writes every polymorphic building;
   its read path reconstructs each `Building` object and invokes virtual slot
   `+0xC0` before rebuilding global indexes. Great Wall parts therefore live in
   the ordinary building collection, not in a separate map-image-only payload.
2. `FUN_0042D360 @ 0x42D360` selects a specialized allocation when
   `FUN_00562E80` recognizes the building ID. The resulting constructor path
   allocates the multipart-monument building with its extra monument-state
   object.
3. `FUN_005631B0 @ 0x5631B0` serializes that subclass by first calling the base
   building serializer `FUN_00427430 @ 0x427430`, then invoking the serializer
   of the state object stored at base-building offset `+0xC8`.
4. `FUN_00563850 @ 0x563850` creates the root and every authored child as
   consecutive building IDs. Base-building offset `+0x16` stores the authored
   sub-building index. Offsets `+0x3C` and `+0x3E` form the previous/next chain;
   the root has index zero and each later record points back toward it through
   this consecutive chain.

Classification: the ordinary polymorphic building collection, consecutive
part records, authored part index, and linked root/children are `confirmed`.
Native save/replay may use its own representation, but it must preserve these
observable identities and must not collapse the layout into the legacy 35
segment model.

## Per-part monument state

The monument-state object is initialized by `FUN_00561D60 @ 0x561D60`. Its
vtable serializer is an analyzer gap at `0x561E30`; direct read-only disassembly
of the same hash-identified executable confirms that the save path writes the
state fields, including offsets `+0x08`, `+0x14`, `+0x20`, `+0x24...+0x26`,
`+0x28...+0x5C`, `+0x64...+0x90`, and the byte at `+0x60`. The read path accepts
versions 1 through 10.

Callers establish the following meanings:

- `+0x08`: current sub-building phase. Construction and rendering functions
  repeatedly read and update this field.
- root `+0x14`: current whole-monument phase. `FUN_0056C880 @ 0x56C880`
  advances it only after the current phase's queued part work is complete.
- `+0x2C...+0x50`: saved delivered-material counters. `FUN_00565410 @
  0x565410` temporarily clears/restores these while calculating remaining and
  total requirements by commodity ID.
- `+0x5C`: wall display mode. The load path assigns ruined/earthen/stone mode,
  and `FUN_0057BBA0 @ 0x57BBA0` selects the corresponding authored archive.
- `+0x84`: layout orientation written during multipart creation.

`FUN_0056C880` coordinates work for the root's current authored phase, while
`FUN_0056D170 @ 0x56D170` advances individual part phases. For Great Wall
layout 257 (`Mon_Great_Wall_05_subs.txt`), the authored nine phase records
advance the wall/tower parts through their staged ranges, then finish the four
joined gate pieces and four road pieces. This is part-level state, not one
click per arbitrary 4x4 map block.

Classification: persistence of the part phase, root phase, delivered-resource
counters, orientation and wall mode is `confirmed`; friendly field names for
unlisted offsets remain `unknown`.

## Badaling campaign transform

`China_Mon_Earthen_Greatwall_1.sg3` has 243 entries and group 1 starts at
local image 201, yielding the map-image interval `201...242`. Matching those
cells against all 16 authored layouts and the exact four rotations from
`FUN_00568D10 @ 0x568D10` identifies `Badaling.map` as layout building ID 257,
root `(55,32)`, zero quarter turns.

The transformed 53 sub-buildings retain authored indexes `0...52`:

- 39 ordinary 4x4 wall parts;
- 6 4x4 tower parts;
- 4 2x2 gate quadrants;
- 4 1x1 road cells.

Their footprint union is exactly the map's 740 matching cells. This is an
independent authored-data invariant used by Native tests.

Classification: the archive interval, Badaling layout ID/root/rotation,
part-kind counts and footprint union are `confirmed`.

## Badaling serialized construction state

Direct decoding of the `cMonumentBldg` sequence in both `Badaling.map` and
`Badaling_S.map` closes the shipping archive shape. The first building-ID
field is at decoded offset `0x10B0D3`; all 53 records use base-building schema
4, monument-wrapper schema 1 and `cMonInfo` schema 10. Schema 10 adds one byte
to this object compared with Haunxian's schema 9, so the complete record stride
including the following MFC tag is `324` bytes. Records after the first begin
with MFC bytes `01 03 80`.

Every record preserves building ID 257, authored sub-index `0...52`, and the
exact world origin from `Mon_Great_Wall_05_subs.txt`. The root stores whole
phase 8. Every part is already at the last phase endpoint assigned to it by
the nine authored layout rules:

- ordinary wall pieces are at sub-phase 10;
- the six tower pieces are at sub-phase 11;
- the four joined gate pieces are at sub-phase 1;
- the four road pieces are at sub-phase 2.

Schema-10 field order plus the independently decoded schema-9 canal record
anchors the four counters used by the recovered Great Wall work paths. Offsets
below are relative to the record's first building-ID field:

| Runtime field | Archive offset | Recovered use |
|---|---:|---|
| `cMonInfo+0x1C` | `+193` | current-phase on-site laborer updates |
| `cMonInfo+0x2C` | `+207` | delivered commodity 10 (wood) |
| `cMonInfo+0x30` | `+211` | shared internal-work counter for tasks 100/101 |
| `cMonInfo+0x38` | `+219` | delivered commodity 20 (stone) |

All four values are zero in every Badaling record in both archives. This is
compatible with an editor-authored terminal snapshot: the phase fields are at
their endpoints even though the in-phase counters contain no residual work.

The four part vtables close the endpoint interpretation independently of the
archive parser. Their `+0x0C` slots return phase counts `11` (wall), `12`
(tower), `2` (joined gate) and `3` (road), and every `+0x10` slot reaches the
common predicate `FUN_00570C50`, which returns true exactly when
`currentPhase >= phaseCount - 1`. The archived `10/11/1/2` values are therefore
the completed value of every individual part, not merely high-looking image
indices.

`FUN_00565410` closes the aggregate percentage. It iterates every part, calls
the part's authored progress-weight function (`vtable +0x2C`) for its current
phase and its base-weight function (`+0x1C`), and uses
`(phaseWeight + baseWeight) * (phaseCount - 1)` as that part's denominator.
A part accepted by `+0x10` contributes its complete denominator; an unfinished
part contributes the recovered partial-phase numerator. The function sums all
parts and returns integer `(sumNumerator * 100) / sumDenominator`, or 100 when
the denominator is zero. Consequently the archived Badaling object, if passed
to this function unchanged, evaluates to 100%.

`FUN_005604C0` accepts Great Wall task IDs 85/86 through any layout building ID
253...268 and requires that aggregate to be greater than 99. The independent
goal path in `FUN_0055AE30` applies the same condition. This closes aggregation
but exposes a campaign-initialization conflict: Qin mission 4 contains the sole
goal `cMonumentGoal [85,0]`, while its authored introduction and victory text
require the player to build the earthen wall. Treating the archived editor
state as live unchanged would therefore satisfy the only goal immediately.

The creation path explains why a map archive may contain terminal values.
`FUN_00563850` first clears each new multipart object's sub-phase and root whole
phase. In map-editor mode, or for a Great Wall created in the ruined display
mode, it then sets every part to `phaseCount - 1` and the root to its terminal
whole phase so the authored ruin is fully visible. On city load,
`FUN_005636B0 → FUN_00563720` only changes the Great Wall display family
(earthen task 85, stone task 86, or ruined); it does not reset construction
phases. `FUN_00563850` itself is called from the placement path, not the
ordinary load path.

Direct machine-code inspection closes the previously suspected Qin-4 startup
reset as absent from the hash-identified 1.0.1.0 load chain:

1. `FUN_00561E30 @ 0x561E30` is the `cMonInfo` serializer. Its schema-10 read
   arm at `0x562CE6` reads `+0x08`, `+0x14`, the material counters and all later
   saved fields directly. Its common epilogue at `0x562E1F` calls
   `FUN_00563720(-1)` and writes only the returned display mode through the
   pointer to `+0x5C`; it does not alter `+0x08` or `+0x14`.
2. Contrary to an earlier working hypothesis, `FUN_00563720` does not inspect
   the later-instantiated current goal objects. It calls
   `FUN_0055F5D0/FUN_0055F5E0` over the campaign's static per-mission goal table,
   indexed by `DAT_010DE118`. For Qin mission 4 it sees type 2 / task 85 during
   deserialization itself and returns earthen mode `2`.
3. The new-mission branch of `FUN_0042E6A0 @ 0x42E6A0` restores the embedded
   map, then calls `FUN_00534BF0 @ 0x534BF0`. That city initializer invokes
   `FUN_005636B0` (another display-mode refresh), later creates the goal objects
   with `FUN_0055F120`, and finally invokes `FUN_0042DA10` over loaded buildings.
   The multipart Great Wall vtable is `0x7B887C`; its `+0x1C8` entry is
   `FUN_00413A00`, a two-instruction `xor al,al; ret` no-op. The other direct
   initialization calls between map restoration and goal creation do not call
   the Great Wall creation, phase setter, coordinator, or completion helpers.
4. `FUN_0055F120` only constructs goal objects from the static records. The
   `cMonumentGoal` constructor initializes goal bookkeeping and does not mutate
   a monument. There is no later startup call to `FUN_00563850`, nor a write to
   the loaded Great Wall's `cMonInfo+0x08/+0x14`, in this chain.

The wider common victory chain is already recovered independently:
`FUN_004AC2B0 → FUN_004AC650 → FUN_0055CEE0 → FUN_0055CE90 → FUN_0055B6A0`.
The new-city path resets the calendar counters, and ordinary single-player
goals are evaluated at the month rollover after `51 * 16 = 816` inner
simulation steps. Qin mission 4 has only the one ordinary monument goal and
no second authored goal that could hold victory back. Therefore, under this
static control flow, the unchanged terminal archive evaluates to 100 percent
and satisfies the sole goal at the first normal monthly goal evaluation.
This is not evidence for the intended player construction workflow; it is a
confirmed conflict between the shipping archive/control flow and the authored
mission introduction/victory text.

The campaign PAK is not a different map variant:
`CampaignEmbeddedMapResolver` resolves chunks `203..<261` of
`4 Qin Dynasty.pak` to the same bytes as shipping `Badaling.map`; both
`Badaling.map` and `Badaling_S.map` carry the same terminal 53-part state.

Classification: schema versions, stride/tag, all 53 identities/coordinates,
part phase endpoints, root whole phase, per-part completion predicates,
aggregate percentage, goal threshold, PAK identity, editor/ruin creation
behavior, deserializer display-mode write, absence of a phase reset in the
hash-identified new-mission chain, and first monthly goal-evaluation consequence
are `confirmed` static evidence. A successful first-playable runtime observation
of Qin mission 4 in that exact build remains `unknown`; the attempted isolated
Wine launch did not progress past its DirectDraw transition, the aligned local
save contains no instantiated building records, and the located public
playthrough could not be viewed past YouTube's login check. None supplies
behavior evidence. Because the mission text and intended construction flow
conflict with the confirmed shipping archive/control flow, Native preserves the
53 records but deliberately does not add task 85 to its completed set, start
construction, or reproduce a likely first-month auto-victory as if it were the
intended fidelity contract.

## Exact part-phase requirements

The static type table at `0x85B180...0x85B1C8` maps the four authored names to
their constructors and vtables:

- `SB_GREAT_WALL` → constructor `0x57BAF0`, vtable `0x7B97D4`;
- `SB_GREAT_WALL_GATE` → constructor `0x57CA90`, vtable `0x7B9888`;
- `SB_GREAT_WALL_TOWER` → constructor `0x57D220`, vtable `0x7B993C`;
- `SB_GREAT_WALL_ROAD` → constructor `0x57D7E0`, vtable `0x7B99F0`.

Their virtual requirement slot `+0x54` reaches `FUN_0057C650 @ 0x57C650`,
`FUN_0057D090 @ 0x57D090`, `FUN_0057D640 @ 0x57D640`, or the base no-work
implementation respectively. The exact per-part contract is:

| Part | Current sub-phase | Earthen mode 2 | Stone mode 3 |
|---|---:|---|---|
| wall or tower | 0, 3, 6 | commodity 10, 200 | commodity 20, 200 |
| wall or tower | 1, 4, 7 | internal work task 100, 200 | same |
| wall or tower | 2, 5, 8 | internal work task 101, 200 | same |
| wall or tower | 9 | none | commodity 20, 200 |
| tower only | 10 | internal work task 100, 100 | commodity 20, 200 |
| joined gate owner (`NW`, orientation value 7), phase 0 | internal work task 100, 100 | commodity 20, 200 |
| other gate quadrants and road parts | all | none | none |

`FUN_0057C5A0 @ 0x57C5A0` and `FUN_0057D5D0 @ 0x57D5D0` independently
identify the worker figures: commodity stages use figure 80 (carpenter) for
earthen mode or figure 82 (stone mason) for stone mode; internal tasks 100 and
101 use figure 10 (laborer). These IDs agree with
`GameData/Model/EmperorFigureModels.txt`. The manual's dirt-and-wood versus
dirt-and-stone distinction therefore agrees with the recovered control flow.
The two internal labor categories now also have confirmed action semantics:
task 100 is dirt carrying/dumping and task 101 is tamping/level preparation.
Those are research descriptions, not recovered player-facing labels; no
separate names for the two categories were found in the original text tables
or monument report path.

For Badaling's 39 wall, 6 tower, 4 joined-gate-quadrant and 4 road records,
the completed earthen layout totals commodity 10 = `27,000`, task 100 =
`27,700`, and task 101 = `27,000`. The stone-mode counterpart totals commodity
20 = `37,400`, task 100 = `27,000`, and task 101 = `27,000`. These totals are
derived from the exact per-part phase functions and authored part counts, not
from video timing.

Classification: type/vtable mapping, phase-to-requirement IDs, amounts,
worker figure IDs, and Badaling totals are `confirmed`.

## Laborer task state and authored work duration

`FUN_0056D690 @ 0x56D690` dispatches figure 10 for the two Great Wall internal
tasks. Task 100 enters raw figure state 7 and task 101 enters state 17. Direct
disassembly of the figure-10 handler at `0x4D6060` closes their state families:

- task 100 uses states `7 → 8 → 9 → 10/11`;
- task 101 uses states `17 → 18 → 19 → 20/21`;
- the first state travels to the initial target, the second travels to the
  selected work target, the third performs on-site work through
  `FUN_004D5F60 → FUN_00570670`, and the final states reassign or return to
  the provider;
- `FUN_0056D8A0/FUN_0056DB50` permit both task families to chain to the nearest
  pending target of the same task before returning, unlike canal task 102's
  one-task return behavior.

The same handler, `SprMain.sg3`, and `GameData/Audio/FigureSounds.txt` close the
action distinction rather than merely showing two opaque task IDs:

| Internal task | Raw states | Animation keys / SG3 groups | Authored sound | Supported action meaning |
|---|---|---|---|---|
| 100 | `7 → 8 → 9 → 10/11` | `0x4C59` / Laborer logical group 88 while carrying and dumping; `0x4C58` / group 87 on return | sound slot 9, `laborer_dump2` (#97), fired at arrival when the requirement is 100 | carry and dump dirt |
| 101 | `17 → 18 → 19 → 20/21` | `0x4C57` / group 86 for travel/return; `0x4C5A` / group 89 for on-site work | sound slot 11, `walker_tamping` (#133), selected by the `0x4C5A` work animation for the Great Wall target subtype | tamp/prepare the current layer |

For comparison, canal task 102 uses `0x4C58` / group 87 for travel,
`0x4C5B` / group 90 for work with sound slot 10 `laborer_work` (#98), and
`0x4C59` / group 88 for return. The manual independently describes laborers as
delivering or excavating dirt and preparing each monument level, and describes
Great Wall construction as many layers of rammed earth. Classification: the
task-to-state, animation, sound, and action meanings above are `confirmed`;
any short Chinese names such as “运土” and “夯土” remain explanatory Native
terminology unless an original localized label is later recovered.

`FUN_00570670` increments the per-part on-site work counter once per figure
update and compares it with `FUN_00448AC0`, the sum of the current authored
animation-record ticks. Xi Wang Mu halves each record before summing. Therefore
the requirement amount 200/100 is not a work-update count. The exact ordinary
thresholds from the three authored sub-building model files are:

| Part | Sub-phase | Normal updates |
|---|---:|---:|
| wall | 1 | 40 |
| wall | 2 | 100 |
| wall | 4 | 100 |
| wall | 5 | 80 |
| wall | 7 | 100 |
| wall | 8 | 80 |
| tower | 1 | 100 |
| tower | 2 | 80 |
| tower | 4 | 50 |
| tower | 5 | 50 |
| tower | 7 | 50 |
| tower | 8 | 60 |
| tower | 10 | 80 |
| owning joined gate | 0 | 100 (`50 + 50`) |

`FUN_0056D4D0` gives a laborers' camp a baseline capacity of three figure-10
workers, reduced by 3/2/1 when efficiency is below 50/70/80. It selects the
nearest eligible provider with the same distance metric used by the common
monument system. The common coordinator limits recovered for the canal also
apply: ordinary capacity allows eight laborers with seven pending items per
laborer, and Xi Wang Mu doubles the coordinator limits.

Classification: dispatch states, reassignment/return structure, per-part
animation tick thresholds, provider capacity and Xi Wang Mu effects are
`confirmed`.

## Shared commodity convoy and target transfer

The Great Wall does not have a separate material-delivery reducer. The wall,
gate, tower and road vtables (`0x7B97D4`, `0x7B9888`, `0x7B993C`, and
`0x7B99F0`) all place `FUN_00571DA0 @ 0x571DA0` in slot `+0x8C`. That function
asks the current part for its requirement through vtable slot `+0x54`, then:

- accepts only a figure of type `0x13` (19), raw state `0x14` (20), whose
  commodity subtype matches the requirement;
- uses `cMonInfo+0x2C` for commodity 10 and `cMonInfo+0x38` for commodity 20;
- accepts `min(carrierCargo, requirementAmount - delivered)` and leaves any
  excess on the carrier.

Consequently a Great Wall material phase has an exact capacity of 200 units,
not the generic convoy batch ceiling. The common coordinator path recovered
for the Grand Canal still gathers same-commodity pending records in stable
enumeration order and splits a carrier-bound batch at 400, so one normal batch
may cover two 200-unit Great Wall records. `FUN_0056EA60` creates the visible
commodity convoy as one type-19 lead plus two linked type-20 followers. The
figure 80/82 values returned by the Great Wall phase tables are the associated
carpenter/stone-mason work categories used by the coordinator; they are not
the delivery carrier's runtime type.

The common source-side predicates are also unchanged: eligible inventory comes
from Warehouse 54, Trading Quay 56 or Trading Station 58, subject to the
recovered inventory/trade-state and path-selector checks, and cargo equals the
requested amount minus the provider's unfulfilled remainder. This closes the
shared batching, source withdrawal, convoy composition and target clipping;
the following section closes target road access and routing separately.

Classification: the four vtable links, matching-carrier gate, counter choice,
200-unit clipping, shared 400-unit batching/source path and three-figure convoy
composition are `confirmed`.

## Multipart road access and routing-cache classes

The previously open Great Wall target-access branch is shared rather than
Great-Wall-specific. `FUN_005673D0 @ 0x5673D0` sends building 83 and all layout
IDs 253...268 to `FUN_00567130 @ 0x567130`. It enumerates every authored child,
transforms its origin, asks `FUN_004BA6F0` for a road perimeter cell, and ranks
survivors by Manhattan distance from candidate origin to the requesting child
origin. Strict comparison preserves authored order on a tie; repeated calls
exclude the prior result and return the next candidate. A pending wall/tower
request may therefore use a gate or road child's access; it is not required to
have road directly beside its own footprint.

`FUN_004BA6F0` indexes 24-slot rows at `0x820038 + footprintSide*0x60`.
The nonzero signed 228-wide offsets form clockwise one-cell perimeters:

- size 1 (road): `(0,-1),(1,0),(0,1),(-1,0)`;
- size 2 (gate): top 2, right 2, bottom 2, left 2 (8 cells);
- size 4 (wall/tower): top 4, right 4, bottom 4, left 4 (16 cells).

The child vtable size slot `+0x1C` returns 4 for wall/tower, 2 for gate and 1
for road. Road-component arbitration is the same recovered top-ten ranking as
the Canal: best component rank wins and strict improvement preserves perimeter
table order within one rank.

Both routing-cache builders are now closed for these four part types. In the
primary builder, `FUN_00568A50 → child vtable +0x68 → FUN_00570DD0` tests the
child's current phase: phase zero produces `0x20`, later phases produce `2`;
neither is admitted by mode 1. In fallback builder `FUN_005223B0`, the parent
root phase must be positive. It then consults three child predicates:

- gate (`+0x6C` true, `+0x70` false) → `0x48000400`;
- wall/tower (`+0x6C/+0x74` false) → `0x4C000800`;
- road (`+0x74` true) → `2`.

All three values are admitted by mode 19. Rebuilding the real terminal
Badaling map with these inputs succeeds and produces exactly eight accessible
children, authored indexes 13...16 and 49...52: the four gate quadrants and
the four road cells. The other 45 wall/tower parts are still reachable as work
targets through the shared ranking of those eight access children.

Classification: multipart branch membership, ranking, size rows, vtable sizes,
primary/fallback class selection and the eight Badaling access children are
`confirmed`. Native now derives these exact values and target candidates. Live
Great Wall dispatch is still not scheduled because the intended Qin-4
unfinished initial state remains unknown, not because road access is unknown.

## Completion transition and side effects

The completion transition uses the common multipart-monument coordinator; it
does not add a Great-Wall-specific reward or cleanup write. This is
`confirmed` by the following independent boundaries:

1. `FUN_0056D170 @ 0x56D170` advances each drained automatic pending record by
   calling the part vtable's current-phase getter (`+0x20`) and setter
   (`+0x24`), bounded by the part phase count (`+0x0C`), then refreshes that
   part with `FUN_00563FD0`. The same queue boundary is used by the recovered
   commodity and labor paths.
2. `FUN_00566B30 @ 0x566B30`, called when an individual worker completes its
   target, performs the same bounded phase increment, refreshes the sprite,
   and calls common coordinator bookkeeping. Its following spatial refresh
   special case applies only to building IDs 76/77 and 83/84; Great Wall
   layout IDs 253...268 take the ordinary refresh return.
3. After all authored ranges for the root's current whole phase satisfy
   `FUN_0056B920`, `FUN_0056C880 @ 0x56C880` increments root
   `cMonInfo+0x14`. The only building-specific post-phase switch cases are
   IDs 78...82. There is no case for task 85/86 or layout IDs 253...268, so
   Great Wall completion adds no coordinator-side reward, unlock, terrain
   rewrite, or cleanup mutation.
4. Campaign success remains the separately recovered common goal path:
   `FUN_005604C0` accepts task 85/86 through a layout ID 253...268 only when
   `FUN_00565410` returns greater than 99; the ordinary monthly victory chain
   then ANDs that goal with all other mission goals.

The English and Chinese decompiler corpus classifies all three coordinator
functions above as identical at the same addresses. Friendly names for their
internal containers remain deliberately absent; the observable state
transition and lack of a Great-Wall-specific completion side effect are now
closed.

## Terminal multipart rendering

The shipping Badaling archive's terminal state can be rendered without
assuming any unknown first-playable construction phase. Four vtable draw slots
close the default-view contract:

- wall `0x57BBA0` and tower `0x57D2B0` select
  `China_Mon_Earthen_Greatwall_10` in mode 2 (or
  `China_Mon_Greatwall_10` in mode 3) and return local image
  `201 + authored variant` for the North-oriented Badaling parts;
- gate `0x57CB10` uses its East-oriented joined-part jump table. In the
  Badaling default view, variants `NW/NE/SW/SE` return local images
  `232/229/231/230`. Image 232 is the 2x2 ground quadrant; the other three
  large images compose the visible gate;
- road `0x57D860` selects local image 241 for the East/West orientation branch
  (242 for North/South). The result is the 78x40 one-cell paved insert.

All 53 archived Badaling parts are already at their authored terminal phase,
so each resolves through this table. Native now suppresses the 740 repeated
editor-reserve map cells when a Great Wall mission mode is active and draws
the 53 wall/tower/gate/road objects as depth-sorted multipart sprites. It does
not apply this terminal table to unfinished states; intermediate phase
rendering remains a separate control-flow recovery task.

Classification: terminal archive family, local image IDs, default-view
orientation/variant mapping, joined-gate composition, and reserve-cell
suppression are `confirmed`.

## Difficulty boundary

There is no direct difficulty multiplier in the Great Wall construction
contract. This negative result is `confirmed` for the hash-identified build,
not inferred from equal-looking playthrough times:

- the wall, tower and gate requirement functions
  `FUN_0057C650/FUN_0057D640/FUN_0057D090` read only current sub-phase,
  earthen/stone display mode and the matching delivered counter before
  returning the fixed authored `200` or `100` amount;
- `FUN_00448AC0` derives on-site duration solely by summing the authored model
  record ticks and halves each record only when hero effect 3 (Xi Wang Mu) is
  active;
- `FUN_0056A910/FUN_0056A940` install fixed ordinary or Xi-Wang-Mu-doubled
  coordinator limits, while `FUN_0056D4D0` derives provider capacity from
  figure class, building efficiency and active-worker count;
- the shared material path retains the fixed 400-unit batch ceiling and
  current-part clipping described above. None of these functions calls a
  difficulty getter or indexes a five-band difficulty table.

Difficulty can still affect elapsed player progress indirectly through the
wider economy, labor allocation, hazards or other independently recovered
systems. Native must therefore keep `GameDifficulty` on the city, but must not
scale Great Wall requirements, authored animation ticks, coordinator limits,
provider capacity or convoy batch size merely because a mission uses a harder
difficulty.

## Remaining unknowns and implementation gate

The intended Qin-4 first playable unfinished part state is not yet closed.
Tasks 100/101 have confirmed action meanings (dirt carrying/dumping and
tamping/level preparation), but no evidence that the original UI gives those
internal categories separate player-visible labels; Native must not invent
such labels.
A mission-start reset in the hash-identified
1.0.1.0 load chain has been ruled out rather than remaining an open candidate.
Aggregate progress itself is closed: the unmodified shipping archive is 100%,
which is precisely why it must not be treated as the mission's intended
playable initial state.
The aligned historical save, isolated Wine launch, and located public
playthrough have all been exhausted as currently accessible evidence and do
not justify assigning phase zero (or any other phase) to the live mission.

Until that evidence is complete:

- do not use the legacy Native `3600` work / `800` wood / `1200` stone values;
- do not expose the legacy click-an-existing-segment construction action;
- preserve the authored campaign placement, part identities and recovered
  requirement schedule, exact schema-10 archive counters and source-backed
  transfer clipping, but do not claim that Native simulates Great Wall live
  dispatch or completion.
