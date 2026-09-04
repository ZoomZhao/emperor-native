# Grand Canal campaign object and construction state

## Scope and sources

This note records the predetermined Grand Canal used by Qin mission 1. Static
addresses refer to the hash-identified English executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`.
The indexed `local/source` comparison classifies the named functions as shared
with the Chinese build unless stated otherwise. Decompiled names and inferred
types are not original symbols.

Corroborating authored sources are:

- `GameData/Model/Mon_Grand_Canal_subs.txt`;
- `GameData/Model/SB_CANAL.txt`;
- `GameData/Model/EmperorFigureModels.txt`;
- `GameData/DATA/China_Mon_Grand_Canal.sg3`;
- `GameData/Cities/Haunxian.map` and `MPcanal1.map`;
- mission 1 of `GameData/Campaigns/4 Qin Dynasty.pak`;
- the monument-construction section of `GameData/EmperorManual.pdf`.

## Authored layout and Haunxian placement

`FUN_00564880 @ 0x564880` passes building ID 83 and
`Model\Mon_Grand_Canal_subs.txt` to `FUN_00567650 @ 0x567650`. The authored
file contains 33 independent `SB_CANAL` sub-buildings, indexes `0...32`, at
local origins `(0,0)` through `(128,0)` in four-cell increments. Every part is
`4x4`; indexes 10, 16, and 22 carry the entry/road-crossing marker. Its five
whole-monument records describe ranges `0→1`, `1→2`, `2→3`, `3→4`, and
`4→5`. The endpoint 5 is not a writable sub-building phase: the concrete
vtable reports a phase count of five and the shared completion predicate treats
index 4 as terminal, as closed below.

`China_Mon_Grand_Canal.sg3` has 323 entries and group 1 begins at local image
201. `Haunxian.map` contains exactly 528 cells with global image 98318, which
is local image 201 relative to the archive's global base 98117. Those cells
form the exact `33 × 4 × 4` layout at root `(4,68)`, with no rotation.
`MPcanal1.map` contains the same 528-cell reserve. The Haunxian terrain flags
are 506 cells `0x10000088`, 21 cells `0x100000c8`, and one cell `0x10000008`;
the differing flags do not change the image-footprint match.

Classification: building ID, source file, part count/index/origins, crossing
markers, five authored phase transitions, archive base/image ID, Haunxian
root/orientation, and 528-cell footprint are `confirmed`.

The decoded map contains additional full-grid byte layers after terrain. A
whole-map comparison of units `9...35` against the 528 reserve cells found no
layer in which the reserve is uniformly encoded as building `83`, sub-phase
`0`, or a 33-part object index. Units `13`, `16`, and `18` vary across the
reserve with the same coordinate/environment patterns seen elsewhere; units
`21...34` are sparse, high-entropy layers shared by the whole map. This is a
confirmed negative result about the **grid layers only**: they describe the
reserve footprint and environment, not object identity.

The same decoded `.map` has a later MFC object section beginning with the
runtime class name `cMonumentBldg`. It contains exactly 33 consecutive
monument-building records for building `83`. Their serialized base-building
fields store world origins `(4,68)`, `(8,68)` ... `(132,68)` and the original
sub-building indexes `0...32`; index zero is the root, so this is 33 total
objects, not one root plus 33 children. The coordinates, IDs, and indexes align
one-for-one with `Mon_Grand_Canal_subs.txt` and the 528 image cells. Thus the
grid-layer negative result must never be generalized to the file's object
section: `Haunxian.map` does serialize the predetermined runtime multipart
object.

The exact archive boundaries are now also closed. The first record carries the
`cMonumentBldg` runtime-class declaration; later records begin with MFC object
tag `0x8003` (new object of the already registered class). From one building-ID
field to the next is 323 bytes: two bytes of the next MFC object tag plus a
321-byte object payload. `FUN_00427430` must be followed through its schema-4
read branch, not through the current schema-5 write branch: schema 4 consumes
179 base-building bytes. It is followed by monument-wrapper schema `1`, then
`cMonInfo` schema `9`. Raw archive helpers at `0x42DBF0/0x42DC20`,
`0x4C9470/0x4C9600`, and `0x41FC60/0x41FCB0` confirm little-endian 32-, 8-, and
16-bit fields respectively. Relative to the serialized building-ID field,
wrapper schema is at `+165`, state schema at `+167`, `cMonInfo+0x08` current
sub-building phase at `+173`, and `cMonInfo+0x14` whole-monument phase at
`+177`. Direct vtable recovery closes the remaining state boundary:
`cMonumentBldg` vtable `0x7B887C` has serializer slot `+0x08 → FUN_005631B0`,
which invokes the embedded `building+0xC8` `cMonInfo`; that object's vtable
`0x7B886C` has serializer slot `+0x08 → 0x561E30`. The schema-9 read branch
serializes runtime fields `+0x04,+0x08,+0x14,+0x0C,+0x10,+0x18,+0x1C,+0x20`
in that order, with the null MFC object reference at `+0x20` consuming two
archive bytes, then continues through the commodity counters. Runtime
`cMonInfo+0x1C`, the phase-0/1 on-site laborer-work counter used by
`0x570670`, lands at building-ID-relative archive offset `+193`. Runtime
`cMonInfo+0x38`, the delivered-stone counter used by `0x5799B0`, therefore
lands at exact building-ID-relative archive offset `+219`; it is a
little-endian `UInt32`, not runtime offset `+0x38` copied into the archive
layout. Both `Haunxian.map` and `MPcanal1.map` contain all 33 records with
schema tuple `(4,1,9)`, phase tuple `(4,4)`, and delivered-stone value `0`.
This directly corrects the
earlier phase-0 inference: the authored maps begin at the fifth construction
phase (phase index 4), not phase 0.

These offsets are versioned rather than universal. `MPcanal4.map` begins with
base-building schema `3`, `MPcanal5.map` with base-building schema `5`, and
`Yangzhou.map` uses `cMonInfo` schema `10`. Native therefore applies the field
offsets above only after the exact `(4,1,9)` gate succeeds. Those maps
currently return no decoded per-part state instead of being treated as
malformed or read through schema-9 offsets. Their separate serializer branches
remain `unknown` and must be recovered before those scenarios can use Native
canal construction state.

Native now decodes those exact 33 records into `GrandCanalMapPartState` and
attaches them to `DeterministicAestheticState` when a city starts from the
authored map. Coordinates, full-grid cell index, object identity, all three
schema versions, current sub-building phase, and whole-monument phase are
`Codable`; the exact on-site laborer-work and delivered-stone counters are
retained per part as well. Older Native part records that predate these fields
decode them as zero, while an
absent optional collection still decodes as empty for format-v1 saves. The
obsolete `GrandCanalProjectRuntime` remains
decode-only compatibility state and is not created for new map-backed cities.

## Multipart object and persistence path

The static sub-building table record at `0x85AAC8` maps `SB_CANAL` to factory
`0x578660`; its constructor at `0x5786C0` installs vtable `0x7B9450`.
`FUN_005786E0 @ 0x5786E0` returns five, independently confirming the part's
five construction sub-phases.

`FUN_00563850 @ 0x563850` uses the ordinary multipart-building creation path
for building ID 83 and applies its canal-specific setup through
`FUN_00563FA0`. As with the Great Wall, `FUN_0042D790 @ 0x42D790`,
`FUN_0042D360 @ 0x42D360`, and `FUN_005631B0 @ 0x5631B0` persist the root and
child objects in the polymorphic building collection together with their
per-part monument state. The base serializer `FUN_00427430 @ 0x427430` writes
the two-byte building ID at object offset `+0x14` and the two-byte multipart
sub-index at `+0x16`; this exact field order identifies the `83,0...32` values
in the Haunxian object records independently of their visual appearance.
`FUN_0056C880 @ 0x56C880` coordinates the current
whole-monument phase. For each scheduled part it calls `FUN_0056BB40 @
0x56BB40`, which reads only the part vtable's worker slot `+0x50` and
requirement slot `+0x54` and classifies the result into one of six pending
collections. The root phase advances only after all six collections at
coordinator offsets `+0x30`, `+0x40`, `+0x50`, `+0x60`, `+0x70`, and `+0x80`
are empty and `FUN_0056B920 @ 0x56B920` confirms that every scheduled part
reached the required ending sub-phase.

Classification: serialized object count, coordinates, building IDs,
sub-indexes, MFC/object schema boundaries, current sub-building phase,
whole-monument phase, ordinary multipart object identity, per-part state, and
root-coordinated phase progression are `confirmed`. Friendly names for
unlisted saved fields are `unknown`.

## Recovered per-part requirements and workers

Canal vtable slot `+0x50` reaches `FUN_00579960 @ 0x579960`, which selects the
worker figure from the current part phase. Slot `+0x54` reaches
`FUN_005799B0 @ 0x5799B0`, which returns the current requirement. Direct
read-only disassembly is required for these two short functions because the
generated Ghidra corpus omitted their bodies.

| Current sub-phase | Requirement returned by `0x5799B0` | Worker from `0x579960` |
|---:|---|---:|
| 0 | internal work task 102, amount 0 | figure 10 (laborer) |
| 1 | internal work task 102, amount 0 | figure 10 (laborer) |
| 2 | commodity 20, `400 - delivered stone` | figure 82 (stone mason) |
| 3 | none | none (`-1`) |
| 4 | none | none (`-1`) |

The phase-2 constant is the double `400` at `.rdata 0x7ACA28`. Across the 33
authored parts this establishes a total stone requirement of 13,200 original
internal units. It does **not** establish a numeric total for task 102: zero is
the original requirement output, not permission to invent a work duration.
Callers including `FUN_0056D690 @ 0x56D690` and `FUN_0056E290 @ 0x56E290`
route requirement 102 as a distinct laborer action, confirming that it is an
internal work category rather than commodity ID 102. The figure creation path
stores action subtype `0x66` and selects worker state `0x0C`; its
restoration/reassignment path `FUN_0056DD30 @ 0x56DD30` selects state `0x0D`.
The figure dispatcher jump table at `0x4D6338` maps state `0x0C` to
`0x4D6178`, which calls `FUN_004D5D50 @ 0x4D5D50`. Once the laborer's current
coordinates equal its target coordinates, that function calls
`FUN_00564AC0 → FUN_0056D8A0`. Direct container-offset disassembly now
identifies task 102's pending queue as coordinator `+0x50`, its initial
dispatch records as `+0x60`, and bound active assignments as `+0x70`.
`FUN_0056D170` may create at most one initial worker per scheduler pass and
copies, rather than removes, the pending item into `+0x60`. State-`0x0C`
arrival removes that initial dispatch record, selects the nearest matching
pending item by strict Euclidean-distance comparison in enumeration order,
removes that item from `+0x50`, and adds its bound record to `+0x70` through
`FUN_0056DB50 → FUN_0056DD30`. A
reassigned task-102 worker enters state `0x0D`, reaches the new target through
`FUN_004D5E50`, then enters state `0x0E`; state `0x0E` dispatches
`FUN_004D5F60 → FUN_00564E00 → SB_CANAL vtable +0x38`, whose concrete handler
is `FUN_00570670 @ 0x570670`. Arrival therefore begins on-site work; it does
not complete the part.

The two coordinates in this path are distinct. `FUN_0056D690` calls
`FUN_00567540` for the pending target object and uses its returned road-access
cell both for provider-distance arbitration and for the initial state-`0x0C`
movement target. At state-`0x0C` arrival, `FUN_0056DB50` compares the worker's
current coordinate with each pending target building's signed-short origin at
`+0x0A/+0x0C`; after binding, `FUN_0056DD30` copies that origin into the
state-`0x0D` target. Thus the first leg ends at the selected perimeter road
access, while the second leg ends at the concrete canal-part origin. Native
now represents these separately and refuses an initial dispatch when the
caller has not supplied the recovered access point.

The on-site duration is authored rather than hidden or synthetic.
`GameData/Model/SB_CANAL.txt` contains four phase-0 animation records with
`ticks = 80,40,50,40` and four phase-1 records with
`ticks = 50,40,80,10`. The original parser `FUN_004484C0 @ 0x4484C0` reads the
sixth post-coordinate column into each 0x58-byte model record at `+0x44`.
`FUN_005702F0` selects the current phase's record vector and
`FUN_00448AC0 @ 0x448AC0` sums those exact `+0x44` fields. On every state-14
figure update, `FUN_00570670` increments `cMonInfo+0x1C` and completes at
`>=` that sum, yielding exactly 210 on-site laborer updates for sub-phase 0
and 180 for sub-phase 1. With Xi Wang Mu effect `3`, `FUN_00448AC0` integer-
halves each record before summing, giving 105 and 90. The handler's separate
virtual `+0x3C → 0x570CD0` constant 50 is used only when the phase record
vector is absent; its strict `>50` fallback would take 51 updates, but both
labor phases have authored records and never use that fallback. Completion
sets the worker to state `0x0F`, resets both `cMonInfo+0x1C` and `+0x90`, and
calls `FUN_00566B30`, which advances the part phase through vtable `+0x24` and
refreshes its monument state. `FUN_0056D8A0` then removes the bound `+0x70`
record. Its post-completion reassignment gate admits subtype 101 but explicitly
rejects subtype 102, so a Grand Canal laborer returns to its Laborers' Camp in
raw state `0x10` after one completed part; reaching the saved provider origin
releases the provider's active monument-worker count. Exact total elapsed time
still includes the initial dispatch, task-binding route, on-site interval, and
return route.
`FUN_00565410 @ 0x565410` also counts task 102 alongside task 100 when
producing monument labor/report totals; it is not the duration source.

The commodity transfer itself is now closed without importing Native's
unrelated logistics load size. `FUN_00571DA0 @ 0x571DA0` obtains the current
requirement through the part's vtable slot `+0x54`, computes the remaining
amount for commodity `20` as `400 - cMonInfo+0x38`, and accepts cargo only from
the matching figure ID while that carrier is figure type `0x13`, state
`0x14`, and commodity subtype `0x14`. If the carrier's signed 16-bit cargo at
`figure+0x82` fits, the full amount is added to `cMonInfo+0x38` and cargo is
zeroed. If it exceeds the remainder, the counter is set to exactly `400` and
the excess remains on the carrier. The confirmed state transition is therefore
`accepted = min(cargo, 400-delivered); delivered += accepted; cargo -= accepted`.
It does not reveal or imply a fixed cargo size. `FUN_0056E600/0x56EA60` is the
separate source-selection and carrier-creation chain, and `FUN_004CC59C →
FUN_00564AA0 → FUN_0056ED10` begins payload assignment when the stone mason
reaches its provider.

The source-side inventory class and request boundary are now closed as well.
`FUN_0056E600` starts from one pending material record, combines later records
of the same commodity, and issues at most the double constant `400`; a record
larger than 400 is split and a combined amount crossing 400 leaves the excess
queued. Its call to `FUN_0056EA60` supplies the resulting amount to
`FUN_005D3730`, whose strict candidate scan is `FUN_005D3A40`. The exact
building predicates are small ID functions: `FUN_005D61C0` accepts only
building `54`, `56`, or `58`; `FUN_005DDAF0` identifies `56` and `58`; and
`FUN_00418D60` identifies only `53`. `EmperorBuildingModels.txt` independently
names these Warehouse, Trading Quay, Trading Station, and Mill. The Mill branch
is gated by `FUN_005DB4C0`, which returns true only for commodities `1...9`;
therefore it is unreachable for canal stone commodity `20`, despite its own
minimum-400 inventory rule.

For stone, an active candidate must consequently be one Warehouse, Trading
Quay, or Trading Station other than the requesting object, and its inventory
vtable slot `+0x264` must report at least the complete request amount. Quay and
Station additionally reject per-commodity trade states `7` and `9`; Warehouse
does not take that extra branch. `FUN_005D3730` then chooses among surviving
candidates through the original path selector `FUN_005B04A0`, not by object ID
or Euclidean distance. Once selected, `FUN_0056EA60` immediately invokes the
provider's inventory slot `+0x298(commodity, requested, 1)`. This slot returns
the **unfulfilled remainder**: actual carrier cargo is
`requested - remainder`; a remainder greater than or equal to the request
kills the just-created carrier with zero cargo. The same return contract is
independently visible in `FUN_005711F0` and the generic inventory-withdrawal
callers.

The queue mutation around that call is now explicit. The first positive
pending record selects the commodity, but same-commodity records are gathered
across the pending container in its enumeration order rather than requiring a
contiguous run. If `FUN_0056EA60` cannot create a carrier, none of those
records are removed or shortened. On success, the selected amount is moved to
the carrier-bound material container: complete records are erased from the
pending container, while the one record crossing 400 is split into a bound
prefix and a pending remainder. State-20 `FUN_0056ED10` later consumes the
carrier-bound records by nearest-target order and erases a record when its
remaining amount becomes zero. Native now exposes this as a deterministic
pending→bound batch reducer and removes completed bound records during cargo
allocation; it does not prematurely decrement a target when the carrier is
created.

The phase-2 producer feeding the pending container is likewise bounded. During
the authored part scan, `FUN_0056BB40` keys duplicate suppression by the target
part plus its current phase across the relevant coordinator collections. For a
Canal part at phase 2, vtable `+0x54` contributes exactly
`400 - cMonInfo+0x38`. Direct disassembly of `0x56BB40` resolves the
decompiler's broken floating-point branch: a positive remainder and worker
`82` creates a commodity-20 material record in coordinator `+0x30`; when the
remainder compares equal to zero, execution instead enters `0x56BF53` and
creates an automatic record in `+0x80`. It does **not** create a stone-mason
worker item in `+0x50`. Native's
`PhaseTwoCoordinatorRuntime` therefore scans decoded parts in authored
sub-index order, emits one commodity-20 request per positive remainder, and
suppresses any sub-index already represented in its pending or carrier-bound
container. The original transient object allocator IDs are not available in
the decoded archive subset, so Native uses the stable authored sub-index as its
save/replay request key and does not claim numerical identity with an original
runtime building ID. Carrier allocation applies each delivery back to that
same per-part `deliveredStoneUnits` counter and removes the satisfied bound
record. The coordinator's two containers are saved beside convoy state and
decode empty from older Native saves.

The same coordinator is entered only on a triggered monument-scheduler pass,
not continuously on every simulation step. Starting from the executable's
initial threshold of 30, the first phase-2 maintenance pass is therefore
scheduler call 31. `FUN_0056BB40` creates or preserves the material requests;
because phase-2 material work occupies coordinator queue `+0x30`,
`FUN_0056D170` then reports active work and `FUN_00564B50` changes the next
threshold to 50. Subsequent maintenance passes occur after 51 more scheduler
calls while that queue remains active. Native reproduces this boundary by
creating only the missing pending requests on the triggered pass and by
persisting the resulting threshold/counter. It deliberately does not withdraw
inventory, create a live figure, move a convoy, or advance phase 2 while any
material request remains; those actions remain separate coordinator/figure
paths. Once all 33 remainders are zero and both material containers are empty,
the same triggered pass creates the `+0x80` automatic records.
`FUN_0056D170` can consume that collection only while `+0x30…+0x70` are all
empty, increments each part from sub-phase `2→3`, clears `+0x80`, and returns
false; the threshold therefore returns to 30. The following triggered pass can
then advance the shared whole phase from `2→3` after `FUN_0056B920` verifies
every scheduled part. This is the same two-pass per-part-then-whole-phase
boundary already recovered for phase 4.

`FUN_005B04A0` itself is now exact rather than an opaque “path selector.” It
clears a 228×228 visit grid, marks the supplied target cell as distance one,
tests that start cell before expansion, then performs four-neighbour BFS.
`FUN_005B0360`, used by this call, admits neighbours on nonzero intersection
with `0x0B0C` and enqueues them in fixed north, east, south, west order. At each
dequeued cell it scans the candidate-cell array from index zero upward, so
equal-cell candidates retain active-building enumeration order and equal-depth
cells resolve by the BFS queue order. It returns candidate index plus one, not
the building ID; `FUN_005D3730` then indexes the parallel candidate-building
array. Native now carries an exact selector for a caller-supplied target point,
ordered candidate-cell array, and already-derived primary grid. The multipart
branch that chooses which Grand Canal part coordinate to supply as that target
remains separate and is not replaced with the root, nearest road access, or a
straight-line heuristic.

The multipart target loop around that selector is also recovered. For Grand
Canal building `83`, `FUN_005D3730` calls `FUN_00567540` repeatedly up to the
authored sub-building count returned by `FUN_00567610` (33). Its canal-family
branch is `FUN_00567130`: it iterates the authored multipart table in index
order, transforms each entry to world origin using the root and orientation,
rejects an entry if `FUN_004BA6F0` cannot find a road-access cell, and ranks
the remaining entries by Manhattan distance from that sub-building origin to
the currently requesting child object's stored origin. The comparison is
strict `<`, so equal-distance entries retain authored index order. A small
exclusion set makes repeated calls return the next ranked entry. For every
returned entry, `FUN_005D3730` scans eligible inventory buildings and invokes
the BFS from the returned **road-access cell**, not from the sub-building
origin; it stops after the first access whose scan has any candidate.

The remaining road-access choice is exact too. `FUN_004BA6F0` reads the
size-specific 24-slot row at `0x820038 + size*0x60`; the `SB_CANAL` size is four
and its row contains 16 nonzero 228-wide linear offsets followed by zero. As
local `(x,y)` points these are the full one-cell perimeter in clockwise order:
top edge left-to-right, right edge top-to-bottom, bottom edge right-to-left,
then left edge bottom-to-top. A perimeter cell is eligible only when its live
terrain is road without water, after applying the original non-multipart
building adjustment branch when needed. `FUN_004AF350 → FUN_004AF490` labels
the components by row-major full-map discovery: a new component may start only
on terrain with road bit `0x40` and without water bit `0x04`; its north/east/
south/west flood then admits cells whose primary derived-grid value intersects
`0x0B0C`, except that primary bit `0x08` is admitted only with terrain bit
`0x400`. This means Ferry masks `0x200/0x800` can connect and enlarge a
component even though a non-road connector cannot itself be selected as a
building access cell. The routine keeps only the ten largest components in
descending cell-count order; strict insertion preserves discovery order for
equal sizes. `FUN_004BA6F0` selects the perimeter entry whose road component
has the best of those ten ranks, and because its rank comparison is also
strict, it preserves perimeter-table order within one component. Native now
implements the component discovery/ranking and this access selection from a
complete terrain plus primary-derived-grid snapshot; its returned access map
contains only ordinary dry-road cells while component sizes still include
admitted connectors.

The normal stone-carrier convoy lifecycle is now recovered as well. The main
figure-type dispatch used by `FUN_004C7580` reads the function column at
`0x84E784 + type*40`: carrier type `0x13` therefore enters
`FUN_004CBEC0`, while each type-`0x14` follower enters `FUN_004D4C70`.
This distinction matters because the neighbouring `0x84E788` column used by a
separate global pass is not the primary state dispatcher. `FUN_0056EA60`
creates one type-`0x13` carrier in raw state `0x13` (19), cargo subtype `0x14`
(stone commodity 20), state counter 30, and two linked type-`0x14` followers.
For stone, `FUN_004D6AC0` selects follower states 6 and 8. Their `+0x72`
links form follower 2 → follower 1 → carrier, and the reciprocal `+0x66`
fields retain the next follower. `FUN_004D4C70` keeps them attached to the
lead chain and destroys them on their own update after the chain becomes dead
or invalid; carrier destruction does not synchronously erase both followers.

The same static path now closes the ordinary stone convoy's visible sprite
selection and follower spacing. `FUN_005CCBF0 @ 0x5CCBF0` initializes the 41
SG3 load-page boundaries. The last three entries are `0x4CC3`, `0x4ECD`, and
`0x5007`; together with `FUN_005CCF70 @ 0x5CCF70`, which loads archive index
`n` at global image page `n << 9`, and `FUN_00408170 @ 0x408170`, which uses
the low nine bits as a one-based logical-group selector, this gives the exact
resource-key decoding rule:

```text
archive load index = resourceKey >> 9
SG3 logical group  = (resourceKey & 0x1FF) - 1
```

The city load list in `FUN_00475B60 @ 0x475B60` places `SprMain` at index 38
and `SprMain2` at index 39. This is independently checked by ordinary known
figure families and removes the misleading numerical coincidence between
global key `0x4E60` and local image `#8244`.

For carrier subtype/commodity `20`, `FUN_004D6A00/0x4D6A40` make
`FUN_004D6AC0` true and `FUN_004D6A80` false. The type-19 renderer
`FUN_004CB910 @ 0x4CB910` therefore uses key `0x4CA6`, decoded as
`SprMain` logical group `165`. The authored SG3 family is `TeamLeader`, first
local image `#9743`, eight directions by 12 frames. It is the stone convoy's
main visible pusher; the type-table default `0x4E60` is the `SprMain2`
`WheelbarrowPusher` group 95 and is not the ordinary stone branch.

The two type-20 followers use distinct branches of `FUN_004D4C70`:

- the direct follower in raw state `6` follows the carrier with lag argument
  `0x12` and, for a normal payload no greater than 400, selects key `0x4E38`:
  `SprMain2` logical group `55`, authored family `WaterBuffaloSolo`, first
  image `#2234`, eight directions by 12 frames;
- the second follower in raw state `8` resolves the active type-19 lead through
  `FUN_004D4BE0`, follows the first follower with lag argument `0x0D`, and
  selects key `0x4E88`: `SprMain2` logical group `135`, authored family
  `WaterBuffaloCart`, first image `#7033`, eight directions by 12 frames.

`0x4E8A`/group 137 belongs to `WaterBuffaloCartLarge`, but it is selected by a
different cargo/terrain-state branch and is not the normal 400-unit stone
convoy. These three associations and their SG3 frame geometry are
**confirmed** by executable control flow plus authored archive records.

Follower position is also not a guessed screen offset. The common attach
routine `FUN_004E7520 @ 0x4E7520` stores a 20-substep phase in figure `+0x41`.
Each update derives the follower phase as `(predecessorPhase - lag) mod 20`;
when that phase is `10` or `11` and the grid points differ, it moves the
follower onto the predecessor's current grid point while retaining its prior
point for interpolation. With the creation/link order above, the first
follower uses lag 18 and the second uses lag 13. At phase `0/1` they also copy
the predecessor's direction, and their animation frame byte is copied on the
ordinary attach call. Native rendering must therefore persist and advance
these linked grid points/phases; placing both buffalo sprites at the carrier
point or inventing fixed pixel offsets is not equivalent original behavior.

The three normal stone-source occupancy classes are now closed independently
of their inventory methods. In the hash-verified English executable,
Warehouse `#54` construction installs vtable `0x7BE1BC`. The trade factory
`FUN_005DDB10` branches on `FUN_005E1720` (true only for model `0x38`,
Trading Quay `#56`): that branch allocates the `0x16C` object through
`FUN_005E1730` and installs `0x7BEDC4`; the other branch allocates the `0x164`
object through `FUN_005E1420` for Trading Station `#58` and installs
`0x7BEAB8`. Every table's `+0xCC` slot contains `0x00416A50`, the same
constant-false predicate already disassembled for houses and the Laborers'
Camp. Their ordinary occupied cells therefore take primary class `2` and
generic fallback class `4`; this conclusion is limited to these three
identified classes and is not an inference from the shared storage role.

This corrects the Quay/Station labels in the earlier version of this note:
the raw vtable addresses were right but the two trade-class names were
reversed. The constructor/discriminator chain and `GameData/Model/
EmperorBuildingModels.txt` rows `56`/`58` are the controlling evidence.

### Trade-byte writer boundary (`FUN_005D4200`, confirmed; producer still open)

The indexed body `FUN_005D4200 @ 0x5D4200` is identical in the EN/CH
`compare-report.tsv` (`identical`, row 7879). Its stack layout is recoverable
from the CH comparison PE (`dbdeca1e…15a`, the only checked-in executable
with this image): after the prologue, `[esp+0x18]` is the commodity index and
`[esp+0x1C]` is the caller-supplied current state byte. The method resolves
the object handle passed as its first argument, calls source-object vtable
`+0x264(commodity)` and `+0x288(commodity, result)`, then writes one byte to
the city/provider record at `+200+commodity` after this exact mapping:

| caller-supplied byte | written byte |
| ---: | ---: |
| 5 | 6 |
| 6 | 5 |
| 7 | 8 |
| 8 | 7 |
| any other value | 9 |

For the four explicit cases it also calls `FUN_00443C60` (states 5/6) or
`FUN_00443CE0` (states 7/8), with the corresponding `0/1` flag. The default
case calls both helpers with flag `0`. Those helpers update separate bounded
per-city arrays (`+0x714` / `+0x718` after their own lookup) and emit the
original notification callback when the value changes; they are not the
`+200+commodity` byte itself.

A direct call is present at PE `0x5D43AF`, in the unindexed byte range that
precedes the indexed `FUN_005D43D0 @ 0x5D43D0`. That caller first reads the
current byte from `resolved-city + 200 + commodity`, then passes the exact
triple `(DAT_01312B1C, commodity, current-byte)` to `FUN_005D4200` and cleans
12 bytes from the stack. The corpus has no indexed caller file or additional
direct callsite for `0x5D4200`; this is a confirmed negative result, not proof
that no indirect path exists.

Native now exposes only the pure raw-byte mapping as
`OriginalGrandCanalLayoutCatalog.phaseTwoTradeCommodityStateTransition` and
tests all explicit/default cases. It does not synthesize these bytes, wire the
two auxiliary arrays, or treat a UI import/export flag as their source. The
trade source remains fail-closed until the object/provider producer and the
complete `+0x264`/`+0x288` state/ledger contract are recovered.

The `+0x288` side effect is now bounded at the trade vtable level. Direct
little-endian reads of both trade tables (`0x7BEAB8` for Station `#58` and
`0x7BEDC4` for Quay `#56`) give `+0x284 → 0x5DEEC0` and
`+0x288 → 0x5DEF20`. These two bodies are not separate indexed functions in
the corpus; the CH PE bytes are the available direct evidence. Both take
`(commodity, amount)` and return `ret 8`. `0x5DEEC0` adds `amount` to
`DAT_013123D0[commodity]` when the current `+200+commodity` byte is `7`, or
to `DAT_0131265C[commodity]` when it is `5`. `0x5DEF20` performs the same
state tests but subtracts instead. Other state bytes are no-ops in both
bodies. Because `FUN_005D4200` calls the source object's `+0x288` before it
writes the new byte, a current state `7` or `5` removes the corresponding
amount from that auxiliary global table before the transition to `8` or `6`.
The global tables' authored commodity-key mapping, initialization, consumers,
and the EN parity of these unindexed bodies remain unknown; no Native ledger
is synthesized from them.

The surrounding indexed refresh boundary is `FUN_005D3CB0 @ 0x5D3CB0`, marked
EN/CH-identical in `compare-report.tsv`. It clears 29 entries in each of the
three contiguous tables at `DAT_013123D0`, `+0x28C` (`DAT_0131265C`), and
`+0x31C` (`DAT_013126EC`), then enumerates active building records. The
model-ID gate admits the recovered Warehouse/Quay/Station set (54/56/58) or
the separate Mill predicate, applies `FUN_00426D10(0)`, classifies the object
through vtable `+0x0EC`, and invokes its `+0x280` callback only for a nonzero
classification. The scheduler calls this refresh from `FUN_004AC2B0` case
`0x10`; initialization also reaches it through `FUN_00591490` and other
setup paths. For the trade tables, `+0x280 → 0x5D5B10` walks provider records
and calls `+0x284` with raw `(record+4, record+8)`, rebuilding the `+0x31C`
aggregate from those records. This separates the record aggregate from the
state-5/7 auxiliary deltas above, but the table consumers and key-to-authored
commodity mapping remain unknown.

The Qin mission-one Stoneworks `#36` is closed through its factory rather than
by generalizing from another industrial building. `FUN_005F0E20` calls the
building-object factory `FUN_00557340`; its first discriminator is
`FUN_00559010 @ 0x559010`, which returns true exactly for building ID `0x24`
(`36`). That branch allocates the `0x150`-byte object and calls constructor
`FUN_00558F50`, installing vtable `0x7B75E0`. The table's `+0xCC` slot is
again `0x00416A50`, the constant-false footprint predicate. A live Stoneworks
cell therefore also reaches primary class `2` and generic fallback class `4`.
This evidence is `confirmed` for `#36` only; the neighbouring alternative
factory branches and unrelated production buildings remain unsupported until
their own discriminators and tables are identified.

Carrier routing is not the phase-labor mode-1/mode-19 pair. `FUN_0056EA60`
writes common movement mode `7` at `figure+0x80`. `FUN_004E83E0` dispatches
mode 7 to `FUN_005AFB00`, whose four neighbour tests read the same primary
derived grid and admit a neighbour when its value intersects decimal `300`
(`0x12C`). Flood order is north/east/south/west; because this branch clears
the common `bVar6` flag, route extraction first requests four-direction output
from `FUN_005B18B0` and retries with eight-direction compression only when
that fails. It has no mode-19 fallback. Authored `EmperorFigureModels.txt`
assigns speed value `8` to figure type `19`, while its dispatcher calls
`FUN_004EB9C0(...,8)` and then the shared `FUN_004E47A0` movement reducer, so
the carrier uses the same confirmed `1,1,2` substep cycle, 20-substep route
cadence, and initial progress 20. This closes the normal source-road to
monument-road movement contract without broadening the still-unknown state-6
provider search.

The Native live phase-2 adapter contract is consequently: update only convoys
that existed at the start of the original step; then execute the monument
scheduler; on a triggered material pass, attempt at most the single
`FUN_0056E600` batch. It enumerates physical source buildings in live placement
order, requires the full request in one eligible source, orders accessible
canal children by the recovered multipart rule, selects the first source by
the `0x0B0C` BFS, immediately removes the returned payload from that exact
inventory, and only then moves the pending prefix into the carrier-bound
container. A normal route must be representable by the recovered mode-7
contract before Native mutates inventory; route-unavailable/request-flag
recovery remains outside this adapter until its coordinator consequence is
closed. Arrival at the monument changes `19→20`; allocation occurs on the
following update and applies each bound delivery to its exact part. Empty
cargo returns through `13→12` and destruction; excess cargo uses the confirmed
state-7/state-10 return to the same source. Partial acceptance may enter the
existing explicit state-6 scaffold, but Native does not invent a replacement
provider. Warehouse inventory and aggregate city commodity stock must change
together. Trading Quay/Station remain ineligible until their raw per-commodity
state `7/9` representation is connected; an importing/exporting UI flag is not
a proven substitute for that byte.

Native now connects the confirmed ordinary-Warehouse subset of that adapter.
The city projects physical building `#54` in live placement order, uses its
saved road-access point as the carrier source point, applies the complete
request predicate to that exact warehouse inventory, validates a complete
mode-7 route before mutation, withdraws from the same warehouse, then moves
the pending prefix into the carrier-bound container and allocates one saved
carrier/two-helper ID triple. Convoys that existed at the beginning of each
original step update before the scheduler; a convoy created by that scheduler
cannot move until the following step. Route buffer, current point, raw carrier
state, cargo, helpers, bound requests, and next figure ID all survive Native
save/reload. Arrival changes state `19→20`; the next update performs target
allocation. Excess cargo returns only to the exact Warehouse and its accepted
amount is mirrored into both physical and aggregate Native inventory. Trading
Quay/Station remain excluded from this live projection until their raw
commodity states `7/9` have an equivalent Native source of truth; dynamic
state-6 alternate-provider recovery remains fail-closed.

The type-`0x13` jump table at `0x4CC624` maps the Grand Canal path as follows.
State 19 moves toward the selected monument access. Movement result 8 changes
it to state 20 and clears the counter. On its following figure update, state
20 calls `FUN_00564AA0 → FUN_0056ED10`. That allocator repeatedly chooses a
positive pending request of the same commodity by Euclidean distance from the
carrier's current coordinate; its comparison is strict `<`, so coordinator
enumeration order wins exact ties. It consumes as much cargo as each request
needs, updating or removing that pending record, until cargo is empty or no
matching request remains. It then restores the source object and source origin
as the return target, clears the route fields, and chooses state 7 when cargo
remains or state 13 when it is empty.

On movement result 8, state 7 returns to Warehouse 54, Trading Quay 56, or
Trading Station 58 through state 10. State 10 increments `figure+0x3E` and
waits while the new value is at most 10; on the update that raises it to 11 it
calls source vtable `+0x154(commodity,cargo)` and passes the accepted amount to
`FUN_004E2A20`. When the full remainder is accepted, that helper clears cargo,
selects state 13, and targets the saved source origin. State 13 reaches that
origin, enters state 12, and the zero-cargo carrier is destroyed on the next
figure update. If the source accepts only part, `FUN_004E2A20` subtracts that
amount and searches another provider, choosing raw state 7/8/9 by its building
class or state 6 when none is found. That dynamic re-provider branch is not yet
integrated in Native. Thus fully consumed cargo and excess cargo have distinct
cleanup paths rather than both being destroyed at the road access. Movement
result 10 destroys a carrier in both directions, but outbound state 19 first calls
`FUN_005688F0(source, commodity, 1)` to restore the source request flag; a
returning carrier does not. State 19 normally calls the same helper with zero
while movement continues.

Native now represents this confirmed subset with a Codable
`PhaseTwoCarrierConvoyRuntime`: it preserves raw states 19/20/7/13/10/12,
counter 30, stone follower states 6/8, strict nearest-request allocation,
the 11th-update source-transfer request, full-transfer state-13 cleanup,
outbound-only request-flag restoration, and the followers' later liveness
update. Movement result 9 is also exact for these states: state 19 or 7 first
releases its path through `FUN_004E8A30`, then falls to raw state 6 when the
current primary-grid cell lacks bit `0x8`; state 13 releases its path but keeps
state 13. The recovered primary-grid writer set has no `0x8` producer, so the
first branch normally reaches state 6 in this hash. Native now connects the
confirmed ordinary-Warehouse path to live deterministic city inventory and
convoys; unsupported provider classes still stop at this boundary. State 6's retry cadence is
now exact too: its counter increments before a strict `> 30` check, so provider
search runs on update 31 and the counter resets whether or not it succeeds.
`FUN_004E2960` then tries a fixed sequence of inventory-provider selectors;
the complete stone-specific eligibility and tie rules of those generic
selectors are not yet reduced to a safe Native contract. The Codable convoy
collection is persisted inside `DeterministicAestheticState`, defaulting empty
when older Native saves omit it; eligible ordinary Warehouses can create a
live convoy through the recovered city bridge. The
subsequent state-6 provider arbitration, partial source acceptance/re-provider path, special
non-54/56/58 source-return branches, friendly labels of trade states 7/9, and
occupied-perimeter adjustment outside the plain-road case remain `unknown` or
not yet semantically closed. Those boundaries must be recovered before wiring
the convoy to live figures and inventories.

Classification: request merging/splitting at 400, source building IDs, the
food-only exclusion of Mill for stone, full-request inventory predicate,
Quay/Station state exclusions, inventory vtable slots, immediate decrement,
remainder-to-cargo conversion, source-search passability mask, BFS order, and
candidate tie-breaking are `confirmed`. The normal type-19/type-20 convoy
creation, allocation, full-acceptance return, destruction, blocked-route
branch, and follower chain described above are also `confirmed`. The friendly
meanings of trade states `7` and `9`, partial-acceptance re-provider behavior,
and special occupied-perimeter/source-return branches are still `unknown`.
Native records and tests
the confirmed request, source, route-selection, and convoy-state contracts,
and dispatches live ordinary-Warehouse carriers only when the source,
inventory, target access, and routing inputs all satisfy that confirmed subset.
Other provider and return branches remain fail-closed.

The worker movement cadence is independently closed by authored model data
and executable control flow. `EmperorFigureModels.txt` identifies field `i`
as speed, defines value `8` as relative speed `1 1/3`, and assigns value `8`
to both laborer figure `10` and stone mason figure `82`. Their ordinary figure
vtable at `0x7AFE60` maps slot `+0x114` to `FUN_004C9310 @ 0x4C9310`, which
returns that model field when called with selector `8`. The monument-worker
state handler `0x4D6060` calls `FUN_004EB9C0(figureID,8)` once per figure
update and passes the result through `FUN_004D5D50` to
`FUN_004E47A0 @ 0x4E47A0`. For speed value `8`, the latter supplies a repeating
`1,1,2` substep pattern. `FUN_004E7EB0 @ 0x4E7EB0` advances one route step when
its progress passes `19`, then resets progress to zero; therefore subsequent
route steps require 20 substeps. `FUN_004E83E0 @ 0x4E83E0` initializes a newly
built route at progress `20`, so its first supplied substep advances
immediately. These cadence values are `confirmed`; route selection and
obstacle arbitration initially remained unresolved.

The update frequency and same-step dispatch boundary are also closed.
`FUN_005371A0` reaches `FUN_004E27E0` before `FUN_00564B50`; the former
iterates every active figure and calls its vtable update slot `+0x28` exactly
once per original inner simulation step. Monument workers created by the
scheduler at the end of that step therefore receive their first movement
update on the following step, not immediately on dispatch. This cadence is
the same 816-step-per-month clock recovered below.

The initial route-generation branch is now recovered. `FUN_0056D690` creates
the monument worker at the provider coordinates, writes the destination
returned by `FUN_00567540`, sets common figure movement mode `1`, and calls
`FUN_004E83E0`. Mode 1 calls `FUN_005B00D0(...,1)`: this is a four-neighbour
breadth-first search whose neighbour admission tests raw passability mask
`0x0B0C`. `FUN_005B0360` confirms this is an admission mask, not a blocking
mask: the candidate is enqueued when `derivedUInt16 & 0x0B0C != 0`, so the
accepted individual bits are `0x4`, `0x8`, `0x100`, `0x200`, and `0x800`.
`FUN_005AD440` assigns ordinary clear land `0x10`, roads `0x4`, and ordinary
water/impassable terrain `0x2`; its `0x100` branch instead requires terrain
bit `0x400` together with a road. Thus the monument worker is road-led
rather than free-ranging over bare terrain. One building post-pass is now
closed exactly. After deriving the base cells, `FUN_005AD440` enumerates active
building `210` (`EmperorBuildingModels.txt`: `Ferry`) objects and invokes their
vtable slot `+0x270`, `FUN_004C6D30 @ 0x4C6D30`. That routine uses the six rows
of six linear offsets at `0x81FF18` to OR `0x800` over the Ferry's `6x6`
footprint. It then walks the Ferry object's stored connector chain, whose
cardinal direction codes are `0/2/4/6`, and ORs `0x200` into each traversed
cell. Both bits are accepted by `0x0B0C`; the footprint and its connector are
therefore explicit primary-mode channels rather than terrain-word guesses.
The complete indexed writer search adds a useful negative result. Base
derivation produces only `1`, `2`, `4`, `0x10`, `0x20`, `0x80`, `0x100`,
`0x400`, `0x1000`, and `0x4000`; Ferry post-processing can OR `0x200` and
`0x800`. The other direct writers only clear the grid or assign/OR `2`.
No recovered writer produces admitted bit `0x8` in this hash-identified
build, even though the mode-1 mask includes it. Its classification is
`confirmed negative: admitted but no producer`, not an unknown terrain or
building semantic. If no shared path-buffer slot is assigned, the dispatcher retries
with movement mode `19`; that branch calls `MonMap_txt @ 0x520DE0` with a
the expansion parameter `100000` and admits cells through the separate raw predicate
`runtimeCellClass & 0x4C001CCE != 0`. This reads `DAT_01339270`, not the
authored `.map` terrain-word grid. `FUN_004E25A0` allocates the same path-buffer
pool used by ordinary figures, slots `1...999`, while `FUN_005B18B0` uses a
500-byte direction scratch buffer (count 500 fails; at most 499 bytes are
copied into the selected slot). Route creation, primary and
fallback modes, both raw masks, four-neighbour BFS, limits, and shared-buffer
identity are `confirmed`.

The post-route blocker behavior is also shared and now recovered.
`FUN_004E8BC0` validates the next queued cell before `FUN_004E7EB0` increments
the route index. Laborer `10` and stone mason `82` are not in
`FUN_004E2560`'s figure-collision group (`58...62` and `78`), so they do not
link to or detour around another figure through that special branch. If the
runtime terrain/building check rejects the next cell, the mover writes
direction `9`; `FUN_004E7EB0` then returns before changing the route index or
freeing its buffer. The next figure update retries the same queued cell, so a
temporary blocker makes the worker wait and a persistent blocker does not
trigger a fresh BFS. When both initial route modes fail, no buffer is retained
and direction `10` is written; the next update calls `FUN_004E83E0` again and
retries route creation. These arbitration states are `confirmed`. What remains
`unknown` is the complete derivation of the two runtime routing grids
`DAT_013789C0` and `DAT_01339270` from authored terrain plus live buildings;
the raw masks above must not be applied directly to `.map` terrain flags
without recovering that conversion. Total journey duration therefore still
cannot be derived from endpoint distance alone.

The same type-10 handler also closes the player-visible laborer animation
families. The type dispatch row at `0x84E908` selects
`FUN_004D6060 @ 0x4D6060`. After its state update, raw states `12/13` select
resource key `0x4C58`, on-site state `14` selects `0x4C5B`, and completed or
returning states `15/16` select `0x4C59`. Using the confirmed global resource
key decoder (`archiveIndex = key >> 9`, `logicalGroup = (key & 0x1FF)-1`)
maps all three to archive index `38`, `SprMain`: traveling group `87`, first
image `#5786`, `12` frames per direction; returning group `88`, first image
`#5882`, `12` frames per direction; and working group `90`, first image
`#6074`, `19` frames per direction. The `SprMain.sg3` bitmap table identifies
the family as `Laborer`. Each group is eight-directional, and the handler
increments the figure frame byte before wrapping against the selected group's
frame count. These resource keys, group boundaries, frame counts, and state
selection are `confirmed`; Native uses them only for its existing figure-10
Grand Canal labor runtime, not as a generic type-10 default outside this
state machine.

### Runtime routing-grid source and invalidation boundary

The serialization boundary is now `confirmed`. `FUN_0052E7C0 @ 0x52E7C0`
reads or writes the 228-by-228 terrain layer at `DAT_00F6A9E0` as one
`0x32C40`-byte block, exactly one little-endian `UInt32` per cell. This is the
same layer parsed by `EmperorMap.terrainFlags`; there is no intermediate
terrain-word conversion during `.map` or `.sav` loading. The two routing
grids are absent from that serialization sequence and are derived caches, not
authored map layers.

That same serializer also fixes the two auxiliary-layer offsets needed by the
recovered branches. After image `UInt32[228²]`, edge `UInt8[228²]`, and terrain
`UInt32[228²]`, it writes `DAT_00F37DA0 UInt32[228²]`, then byte grids
`DAT_00F9D620`, `DAT_00F1E780`, and `DAT_00F05160`, two scalar `UInt32`s,
then `DAT_00EAC3F0`, `DAT_00E92DD0`, and `DAT_00E9F8E0`. Thus the signed
primary elevation class read by `FUN_005AD440` is the second byte grid after
those scalars (`DAT_00E92DD0`). After a 36-byte serialized object, byte grids
`DAT_00BEBF3A` and `DAT_00BF8A4A`, one scalar `UInt32`, and a 360-byte block,
format versions greater than four serialize `DAT_00F2B290`; this is the
independent road/water auxiliary byte read by `FUN_00471CF0`. Native may parse
these exact saved layers by position; the pre-existing anonymous “13 byte
grids immediately after terrain” view is not a semantic substitute because
the first intervening layer is `UInt32[228²]`.

The complete value domain produced by fallback derivation
`FUN_005223B0 @ 0x5223B0` is also `confirmed`: `2`, `4`, `8`, `0x40`,
`0x10000200`, `0x20000100`, `0x40000010`, `0x40000020`, `0x48000400`,
`0x4C000800`, `0x4C001000`, and `0x80000001`. Applying the mode-19 mask
accepts the first four values and `0x40000010`, `0x40000020`, `0x48000400`,
`0x4C000800`, `0x4C001000`; it rejects only `0x10000200`, `0x20000100`, and
`0x80000001` among values that this function can produce. Direct terrain
branches identify ordinary land/road/irrigation as class `2`, water as
`0x10000200`, the unavailable/off-map class as `0x80000001`, a road-and-water
cell with its auxiliary byte present as `0x40`, terrain bit `0x400` as `8`,
and wall terrain as `0x40000010`.

The authored building switches are exact but some vtable predicate meanings
remain structural. Tea/lacquer/mulberry trees `26...28`, crop fields
`194...199`, Grand Way `111`, Imperial Way `113`, Road Block `126`, Ruin
`161`, and Irrigation Ditch `202` produce class `2`. Warehouse `54`, Trading
Quay `56`, and Trading Station `58` produce class `4`; Common/Grand Market
Squares `59/60` and Entertainment Area `71` produce `4` when the cell lacks a
road and otherwise fall through to `2`. The hexadecimal switch labels must not
be mistaken for decimal building IDs: case `0x53` is Grand Canal `83`, while
case `0x83` is Tower `131`. Canal cells produce `2` when the object returned by
vtable `+0x1EC` has field `+8 <= 0`, otherwise `0x4C001000` without a road or
`0x40` with one; all three are admitted by mode 19. The accessor is now closed
exactly: monument-building vtable slot `+0x1EC` is `FUN_00416B50 @ 0x416B50`,
which returns `building + 0xC8`, the embedded monument-state object serialized
by `FUN_005631B0`. Independent monument construction/rendering callers already
identify state offset `+0x08` as the current sub-building phase. The fallback
branch therefore means Grand Canal sub-phase `0` produces `2`, while
sub-phases `1...` produce `0x4C001000` off-road or `0x40` on-road; this is no
longer an unnamed vtable predicate. City Gate `130` produces
rejected `0x20000100`, Tower `131` produces admitted `0x40000020`, and Great
Wall layouts `253...268` select among admitted `2`, `0x48000400`, and
`0x4C000800` according to their recovered parent/sub-building predicates.
These branches close the values and mask result used by the fallback worker
route. Porting the derivation still requires typed Native equivalents for the
remaining generic building footprint predicate and the other live occupancy
branches; their meanings are not inferred here.

### Native route arbitration over derived grids

The post-derivation route contract is now implemented independently of the
unfinished cache producer. `OriginalGrandCanalLayoutCatalog.workerRoute`
accepts already-derived primary `UInt16` and fallback `UInt32` grids, tries
mode 1 first, and invokes mode 19 only if the primary search cannot reach the
destination. Both searches expand cardinal neighbours in the exact order used
by `FUN_005B0360` and `MonMap_txt`: north, east, south, west. Mode 19 passes
the recovered parameter `100000`; its original post-increment comparison is
strict (`parameter < processed`), so it may process queue item `100001` before
stopping.

Path extraction follows `FUN_004E83E0 -> FUN_005B18B0`: primary mode first
tries four-direction extraction and retries with eight directions only if
that extraction fails; fallback mode uses eight-direction extraction. The
eight-direction order is `N, NE, E, SE, S, SW, W, NW`; ties prefer the
direction pointing most directly toward the source, and the immediately
opposite prior step is excluded. The 500-byte scratch buffer rejects a route
as soon as its count reaches 500, so a successful route emits at most 499
direction bytes (the existing catalog field retains the buffer capacity 500).
The resulting Native value records which of the two original grids won, the
ordered points, and the original `0...7` direction codes. This component does
not derive either grid from terrain and buildings, allocate original global
path-buffer slots, or enable worker dispatch; those remain separate gates.

Classification: grid arbitration order, BFS neighbour order, extraction
modes/tie-breaking, expansion-parameter boundary, direction codes, and
500-byte scratch boundary are
`confirmed`. The Native route component is verified with primary-success,
fallback-success, and both-unreachable cases against independently authored
grid fixtures.

Their complete rebuild boundary and order are also `confirmed`:

1. `FUN_005AD8F0 @ 0x5AD8F0` calls `FUN_005AD920` to clear the 228-by-228
   `UInt16` primary grid `DAT_013789C0` to zero, then calls
   `FUN_005AD440` across the playable rectangle.
2. `FUN_00522810 @ 0x522810` initializes every `UInt32` fallback cell in
   `DAT_01339270` to `0x80000001`, then calls `FUN_005223B0` across the same
   rectangle.
3. Map creation/load paths including `FUN_0053CEC0`, `FUN_00534BF0`, and
   `FUN_0053D100` invoke those two rebuilds in that order after terrain and
   serialized building objects have been restored.

Live mutations use the same order on a bounded rectangle: callers such as
`FUN_0042BA40`, `FUN_0042BBD0`, and `FUN_005431C0` first call
`FUN_005AD440(region,...,1)` and then `FUN_005AD940(region)`, whose body calls
`FUN_005223B0`. These examples cover building creation and monument-part
state changes, and expand the affected footprint by two cells. Both derivation
functions read the direct terrain words and the live building-occupancy grid
`DAT_00FC3750`; they also consult building type/vtable state and auxiliary
cell layers. Consequently the source and cache invalidation boundary are
closed. The primary Ferry post-pass is also closed as described above, but the
complete semantic meaning of every remaining branch and auxiliary bit used by
`FUN_005AD440`/`FUN_005223B0` is not yet closed. Native may preserve
this read-only contract, but must not treat a terrain word as either derived
routing value or enable monument workers until those predicates are ported
and independently tested.

The shipping manual says the Grand Canal requires excavation, wood, and
stone, and describes carpenter/stone-mason guild deliveries generally. The
runtime construction pipeline conflicts with that prose: building `83` uses
the generic `FUN_0056BB40` classifier, which obtains every worker/task,
commodity, and amount from the two `SB_CANAL` vtable slots above. Those slots
never return commodity `10` (wood). `FUN_0056C880` has post-phase special cases
only for building IDs `78...82`; building `83` has no branch that injects an
additional wood request. The executable runtime therefore has no Grand Canal
wood requirement. This absence is `confirmed` for the hash-identified build;
the manual statement is retained as contradictory documentation, not converted
into an invented amount.

For sub-phases 3 and 4, worker `-1` and zero requirement enter the collection
at coordinator offset `+0x80` through `FUN_0056F610`. `FUN_0056D170 @
0x56D170` processes that collection only after the other five collections are
empty, increments each part's current phase through vtable slot `+0x24`, calls
`FUN_00563FD0` to refresh its sprite, and removes the item. Both final
sub-phases are therefore automatic queue-drain transitions; they do not
request a worker, commodity, timer, or player click.

Classification: the phase selectors, task/commodity IDs, phase-2 amount,
remaining-stone counter, worker figure IDs, task-102 arrival/reassignment and
authored on-site work completion,
worker substep cadence, initial route generation, blocker arbitration, the
absence of a runtime wood request, and automatic sub-phases 3/4 are
`confirmed`. The routing grids' serialized source, allocation sizes, reset
values, full/local rebuild order, and live-occupancy dependency are also
`confirmed`; the remaining `unknown` is the full semantic port of every
auxiliary-layer and building-state predicate in their two derivation
functions.

### 2026-08-31 routing model-ID predicates (confirmed, structural)

The occupied-object branches of the two routing-cache builders resolve a
live object's **model ID**, not its building ID. The exact leaf predicates are
identical in the English and Chinese executables (`local/source/compare-report.tsv`):

| source function | address | exact accepted model IDs | use site |
| --- | --- | --- | --- |
| `FUN_004EFF30` | `0x4EFF30` | `0xDC, 0xDD, 0xDF, 0xE0, 0xE1` | primary builder `FUN_005AD440` occupied-object branch |
| `FUN_004C0600` + `FUN_004C0630` + `FUN_004C0640` via `FUN_004C11B0` | `0x4C0600`, `0x4C0630`, `0x4C0640`, `0x4C11B0` | `0x1A…0x1C` and `0xC2…0xC7` | primary and fallback object branches |
| `FUN_00562F70` | `0x562F70` | `0x4C…0x56`, `0x5C`, `0x5D`, `0xFD…0x10C` | primary branch after the secondary-family test |

These sets are now exposed as the read-only
`OriginalGrandCanalLayoutCatalog.RoutingModelPredicateCatalog` and tested
without assigning player-facing names. They do **not** close routing by
themselves: the same branches also read the object's `+0xCC` predicate,
vtable slots (`+0x68`, `+0x1EC`), model-table phase data, and auxiliary terrain
layers. Native therefore keeps the live projection fail-closed when those
inputs are absent. The reusable conclusion is `confirmed` for the ID sets
and call edges; semantic category names and a complete object-record
projection remain `unknown`.

### 2026-09-02 building `+0xCC` footprint predicates (confirmed)

The generic occupied-cell branches call the live object's vtable slot `+0xCC`
before applying the model-ID families above. A direct little-endian read of
the canonical English PE and the Chinese comparison PE shows that the
following Qin-relevant classes all carry the same slot value:

| authored building IDs | constructor / class evidence | vtable | `+0xCC` target |
| --- | --- | --- | --- |
| `3...17` | `FUN_0042D480` house construction; `HouseBldg` | `0x7ABA38` | `0x00416A50` |
| `36` | `FUN_00558F50` Stoneworks factory branch | `0x7B75E0` | `0x00416A50` |
| `54` | Warehouse construction | `0x7BE1BC` | `0x00416A50` |
| `56` | `FUN_005DDB10` → `FUN_005E1730` (0x16C object) | `0x7BEDC4` | `0x00416A50` |
| `58` | `FUN_005DDB10` → `FUN_005E1420` (0x164 object) | `0x7BEAB8` | `0x00416A50` |
| `59/60` | `FUN_00543450` cMarket constructor | `0x7B6F3C` | `0x00416A50` |
| `71` | `FUN_0048CB10` cEntertainmentSquare constructor | `0x7AD878` | `0x00416A50` |
| `72/73` | `FUN_0051BEF0` → `FUN_0051C090` Well family | `0x7B5EB4` | `0x00416A50` |
| `207` | `FUN_0051C0B0` Herbalist constructor | `0x7B6114` | `0x00416A50` |
| `208` | `FUN_0051C0D0` Acupuncture constructor | `0x7B6374` | `0x00416A50` |
| `233` | `FUN_0050A570` Laborers' Camp constructor | `0x7B4FF8` | `0x00416A50` |

`FUN_00416A50 @ 0x416A50` is a constant-false two-argument callback: the
English bytes at the body are `32 C0 C2 08 00` (`xor al, al; ret 8`), and the
Chinese body is identical. The compare report marks the shared function rows
identical; the vtable words were read directly from both hash-matched PE
images rather than inferred from the building names or rendered footprint.
Therefore these classes take the `+0xCC == false` side of the primary and
fallback object branches. For ordinary occupied cells that means primary
class `2` and generic fallback class `4`; the explicit market/entertainment
fallback branches still apply their own road-dependent outputs after this
predicate. Canal and Great Wall records retain their separate monument
handling and are not included in this generic catalog.

Native exposes this exact subset through
`BuildingFootprintPredicateCatalog.genericFootprintPredicate(forBuildingID:)`.
`CitySimulation.grandCanalWorkerRoutingGrids()` now supplies a predicate only
for the listed IDs; an unlisted placed building supplies `nil` and remains
fail-closed instead of inheriting a guessed `false`. The conclusion is
`confirmed` for the vtable words, callback body, and listed building classes;
the complete map-load object projection and all other building classes remain
`unknown`.

## Completion and implementation gate

`FUN_0056D690 @ 0x56D690` dispatches individual workers and
`FUN_0056C880 @ 0x56C880` advances authored phases. Laborer figure `10` is
sourced from a Laborers' Camp, building `233`; stone-mason figure `82` is
sourced from guild building `235`. `FUN_0056D4D0 @ 0x56D4D0` starts provider
capacity at three for figure `10` and one for each artisan figure `80...82`.
It subtracts three, two, or one when the provider's vtable `+0x1B4` efficiency
result is respectively below `50`, `70`, or `80`; the provider is eligible
only while its active monument-worker count at `+0x78` is below the resulting
capacity. Among eligible buildings it chooses the smallest original isometric
distance `max(abs(dx),abs(dy))/2 + min(abs(dx),abs(dy))`.

The building-233 class constructor `FUN_0050A570` installs vtable
`0x7B4FF8`. Its `+0x1B4` entry is `FUN_00428ED0`, which calls `+0x1B0` for
required employees and `+0x1B8` for assigned employees, returning zero when
the former is non-positive and otherwise integer
`assigned * 100 / required`. On this vtable, `+0x1B0 → 0x428EB0` reads the
authored employee-table field (unless the building's no-labor byte is set),
while `+0x1B8 → 0x416B10` returns the signed-short live assignment at building
offset `+0x44`. `EmperorBuildingModels.txt` row 233 supplies required employees
`10`. The provider-active predicate at `+0x78 → 0x4289F0` returns the byte at
building `+0x90`; constructed, enabled Native camps currently project as
active. Native therefore now derives candidate efficiency from its common
workforce snapshot, counts still-live canal laborers by provider object ID,
and preserves placement enumeration and building origin for the strict
distance tie. The remaining city bridge is route/access derivation and live
figure movement, not provider efficiency.

The same vtable closes Laborers' Camp occupancy for the two cache builders.
The hash-verified English executable
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
stores `0x00416A50` at `0x7B4FF8 + 0xCC`; direct disassembly is the constant
false two-argument predicate (`xor al,al; ret 8`). Consequently a live camp
cell carrying terrain occupancy bits `0x8008` reaches primary class `2` in
`FUN_005AD440` and generic fallback class `4` in `FUN_005223B0`. The default
house construction path installs base vtable `0x7B65E4`, whose same `+0xCC`
slot is also `0x00416A50`; evolved building IDs `3...17` remain the same house
object class. This closes the residential + camp occupancy subset needed by
the first Qin mission without generalizing the predicate to unrelated
buildings. Other generic building types remain unsupported until their own
class vtables are verified.

Coordinator initialization at `FUN_0056A910 @ 0x56A910` sets total active
artisan workers to `3`, laborers to `8`, and per-worker pending-task limits to
laborer `7`, figure-80 `5`, figure-81 `3`, and figure-82 `3`.
`FUN_0056A940 @ 0x56A940` replaces these with exactly doubled values
`6,16,14,10,6,6` when `FUN_00564E80 @ 0x564E80` reports hero effect `3`
active. Disassembly corrects the generated decompiler's erroneous `void`
signature: this wrapper returns `FUN_005A8420(3)`, and `FUN_005A8420` tests the
active hero-effect ID stored in `DAT_010BFB40/50`. The authored `ALL HEROES`
table identifies ID `3` as Xiwangmu. Two independent users of the same effect
predicate close the numeric namespace: `FUN_00592D30` makes emissaries free
for effect `8`, matching hero `8` Sunwukong and his documented benefit, while
`FUN_00592DB0` halves the `600/800` spy purchase cost for effect `10`, matching
hero `10` Sunzi and his documented benefit. The manual likewise states that
Xi Wang Mu reduces monument construction time while active in the city.
Therefore both the doubled numeric limits and their Xi Wang Mu activation
semantics are `confirmed`, not a difficulty or general game-speed modifier.
Completion and reassignment enforce the same limits in `FUN_0056D8A0 @
0x56D8A0`.

Native now models the confirmed phase-0/1 coordinator boundary separately
from the phase-2 material coordinator. It preserves task-102 pending records,
initial and bound laborer states, stable figure IDs, provider identity/origin,
raw states `12→13→14→15→16`, nearest-task enumeration, per-part authored work
counters, one-task-then-return behavior, and the shared whole-phase advance
after both labor queues drain. These fields are `Codable` and older Native
saves decode an empty labor coordinator. Native now projects live building-233
provider efficiency and active dispatch count, while the core scheduler takes
separate canal-part origins and `FUN_00567540`-equivalent access points.
Native now rebuilds a complete Haunxian worker-routing snapshot from the
authored terrain and exact serialized auxiliary layers, overlays live Native
roads plus the source-confirmed house/camp/canal occupancy subset, ranks the
ten road components, and produces the multipart access candidates. A pending
request is **not** required to use the access of the same sub-building index:
`FUN_00567540 → FUN_005673D0/FUN_00567130` ranks every canal child with a
valid `FUN_004BA6F0` access by Manhattan distance from that candidate child's
origin to the current pending object's origin; strict comparison preserves
authored index on a tie. This correction is exercised by the real Haunxian
phase-0 city path, whose first pending child has no directly bound access.

Live phase-0/1 city dispatch now uses that snapshot and the recovered
816-step monthly bridge. Each saved figure stores the selected primary or
fallback route, route index, speed-cycle index, and substep progress. Existing
figures update before the scheduler on every original step, so a newly created
worker first moves on the following step; movement uses the confirmed `1,1,2`
cycle and 20-substep route cadence, including the newly built route's initial
progress 20. Arrival, on-site work, and one-task-then-return transitions feed
the same persisted coordinator state. Unsupported live building vtables still
stop cache derivation explicitly. The city-day adapter treats that typed
routing failure as an atomic unsupported boundary: it leaves the entire
scheduler batch unchanged instead of guessing a class or terminating the
surrounding city simulation; direct routing research callers still receive
the coordinate-bearing error. Xi Wang Mu's live city-presence bridge is not
yet connected; this implementation does not substitute Native's ordinary
road walkers.

`FUN_00564B50 @ 0x564B50` runs the monument scheduler after the recovered
threshold interval; the historical shorthand “30 without automatic phase
advancement, 50 after one” is not the executable's actual condition.

Direct disassembly corrects that last shorthand. `DAT_00859DA0` is initialized
to `30` in the executable's `.data` at `0x859DA0`; the separate counter
`DAT_012A6E78` is zero-initialized. `FUN_00564B50` increments first and uses a
strict comparison, so an active incomplete monument with threshold 30 fires
on scheduler call 31. It changes the threshold to 50 only when
`FUN_0056D170` returns true. That return tests whether coordinator queues
`+0x30` or `+0x50` remain active, not whether an automatic phase advanced.

The earlier claim that Haunxian then advances `4→5` was a Ghidra pseudocode
misread and is invalidated by direct machine code. `SB_CANAL` vtable
`0x7B9450` has slot `+0x0C → FUN_005786E0`, which returns phase count `5`, and
slot `+0x10 → FUN_00570C50`, which returns complete when
`cMonInfo+0x08 >= phaseCount-1`. Thus valid sub-building phases are exactly
`0...4`; index 4 is terminal. Both advancement sites enforce the same bound:
`FUN_00566B30 @ 0x566B30` and the automatic queue loop in
`FUN_0056D170 @ 0x56D170` compute `next = current+1` and skip the setter when
`next >= phaseCount` (`jge` at `0x566B9F` and `0x56D414`).
`FUN_0056C880` can advance the shared whole phase only after
`FUN_0056B920` approves the current authored range, but the root aggregate is
already complete when all parts are at terminal index 4. Therefore
Haunxian's archived `(sub,whole)=(4,4)` state is already 100%; it does not
mutate at calls 31 or 62. Native now derives building 83 completion directly
from the complete 33-record `(4,4)` archive and leaves the completed scheduler
state untouched. The general threshold interpretation remains confirmed: 30
without the two active-work queues, 50 while either remains.

The original calendar supplies the frequency bridge. `FUN_00536B20 @ 0x536B20`
calls `FUN_005371A0` once for every inner simulation step. On each such call,
`FUN_004AC2B0 @ 0x4AC2B0` advances `DAT_00C82EF8` through `0...50`; after the
51st call it resets that counter and calls `FUN_004AC650 @ 0x4AC650`.
`FUN_004AC650` increments `DAT_00C82EF0`; values `1...15` return through the
sub-month path, while value 16 executes the month settlement and explicitly
resets the counter to zero. Both new-city initialization `FUN_004AC240 @
0x4AC240` and the map-load path in `FUN_0042E6A0 @ 0x42E6A0` reset all three
calendar counters (`DAT_00C82EF8`, `DAT_00C82EF4`, and `DAT_00C82EF0`) to zero.
Therefore every original calendar month contains exactly `51 * 16 = 816`
inner simulation steps and exactly 816 calls to `FUN_00564B50`. This is a
`confirmed` call-count relationship; it is independent of real-time game
speed, because `FUN_0053A130` changes how quickly the inner steps are emitted,
not their calendar counter transitions.

Native persists the scheduler counter and threshold next to the 33 part
states and bridges its compatibility clock to those 816 original calls per
month for incomplete supported phases. The Native clock remains 30
deterministic save/replay days per month;
it distributes calls by cumulative integer ratio
`floor(day * 816 / 30) - floor((day - 1) * 816 / 30)`, producing 27 or 28
calls per Native day without claiming that a Native day existed as an original
engine unit. On day 30 the 816th call occurs after Native month settlement,
matching `FUN_005371A0`, where `FUN_004AC2B0` performs the original month
boundary before the same step reaches `FUN_00564B50`. Tests lock the 816-call
monthly sum, incomplete-phase transitions, and the fact that completed
Haunxian state never consumes or mutates this scheduler.

Native exposes building `83` to campaign-goal evaluation only when the decoded
collection remains structurally complete (exactly 33 unique sub-indices
`0...32`, all building ID 83) and every record has both sub-building and shared
whole-monument phase at least the terminal index 4. This mirrors the recovered
root aggregate `100%` predicate rather
than injecting a legacy synthetic `MonumentProject` completion flag.

There is no separate “begin project” transition for the predetermined canal.
The Haunxian root object is serialized with multipart sub-index zero, active
base-building state `3`, current sub-building phase `4`, and whole-monument
phase `4`. Its saved `mapCellIndex` values use the full 228x228 grid and
therefore include the playable-map border offset, while the saved `(x,y)`
origins are playable-area-relative. During city updates,
`FUN_005371A0 @ 0x5371A0` calls `FUN_00564B50`; incomplete predetermined
monuments are scheduled automatically through their coordinator. Haunxian's
terminal `(4,4)` canal is already complete and does not create a phase-4 labor
request or wait for a Laborers' Camp. The original entry for an incomplete
canal is still automatic scheduling of the loaded predetermined object, not a
construction-menu button or click on a canal segment.

The Qin campaign archive independently binds mission 1 “Zheng Guo's Canal” to
`Haunxian.map` and contains `cMonumentGoal` values `[83,0]` plus yearly
production goal `[15,1800,0]`. Building `83` is also reused by the separate
Sui campaign archive; that does not change the Qin/Haunxian evidence recorded
here. `FUN_005604C0 @ 0x5604C0` evaluates a monument goal by finding a root
record (sub-index zero) matching the goal building ID and requiring
`FUN_00565410(rootID,0,0) > 99`. The campaign goal is therefore satisfied at
100 percent aggregate monument progress. After a whole-monument phase
increments, `FUN_0056C880` contains building-specific post-phase cleanup only
for IDs `78...82`; building `83` falls through without a canal-specific
completion branch. Thus the canal itself adds no separate reward, unlock, or
cleanup write in this coordinator.

The wider victory path is a separate common campaign system and is now closed.
RTTI at `0x859120` binds `cMonumentGoal` to constructor `FUN_00559490` and its
vtable at `0x7B81D4`; completion slot `+0x18` is the `FUN_005604C0` predicate
above. `FUN_0055B6A0 @ 0x55B6A0` iterates every current mission-goal object and
ANDs the return value of that same completion slot. It returns victory only
when every ordinary goal is true and no special blocker is active. In the
single-player update path, `FUN_004AC2B0 → FUN_004AC650` reaches
`FUN_0055CEE0 → FUN_0055CE90 → FUN_0055B6A0` at the ordinary month rollover;
a true aggregate result sets the common victory state and enters the shared
end-of-game transition. Qin mission 1 contains both monument `[83,0]` and
yearly-production `[15,1800,0]` goals, so completing the canal alone cannot
win: both goal predicates must be true at the same monthly evaluation. This
all-goals AND, monthly boundary, and common transition are `confirmed`. The
exact result-screen rendering remains part of the separate front-end fidelity
contract, not a canal mechanic.

No evidence was found for a player action that clicks every 4x4 segment once
per phase. The existing Native values of `2,400` generic work, `600` wood,
`800` stone, four segment stages, and equal division across 33 independently
clicked blocks have no support in the authored data or recovered executable
path.

## Exact map artwork selection and crossing layers

The resource-key decoder `FUN_00408170 @ 0x408170` uses `key >> 9` as the
loaded archive index and `(key & 0x1FF)-1` as a zero-based logical SG3 group.
For `China_Mon_Grand_Canal.sg3`, the body keys used by
`SB_CANAL +0x14 → FUN_005786F0` resolve as follows: `C01 → #201`,
`C09 → #212`, `C03 → #224`, and `C02 → #232`. The crossing-overlay keys used
by `SB_CANAL +0xA0 → FUN_00578F30` resolve to `C08+2 → #236` and
`C07+2 → #240`. These are local SG3 image IDs, not group ordinals copied into
the renderer.

Phase zero does not draw a canal body. An ordinary part resolves resource key
`0x603` to `China_Terrain #247` over all sixteen cells. A crossing part first
writes `#247 + DAT_00F1E780[cell] % 9` over the full 4x4 footprint, then
overwrites the four authored road cells with key `0x61E`, which is
`China_Terrain #782` at default view rotation zero. The `DAT_00F1E780` byte
layer is the sixth decoded legacy byte grid immediately after the five earlier
full-grid byte fields; Native exposes it by the semantic name
`terrainVisualVariationValues`. For Haunxian's unrotated entry marker, the
road line is local row `y+2`, `x...x+3`. This phase-zero mapping is
`confirmed` by direct writes in `0x5786F0` and the two resource-key
resolutions.

For phases 1...3, `FUN_00578C90 @ 0x578C90` selects one body per 4x4 part from
its current phase, the two connected-neighbour phases, the crossing marker,
and the low bit of `DAT_00F1E780` for the variable straight/end families. The
confirmed local-image mapping is:

| Phase | shape 0...3 | shape 4 | shape 5 | shape 6 ordinary / crossing |
|---:|---:|---:|---:|---:|
| 1 | `#201...204` | `#205 + (v&1)` | `#208 + (v&1)` | `#211 / #211` |
| 2 | `#212...215` | `#216 + (v&1)` | `#219 + (v&1)` | `#223 / #222` |
| 3 | `#224...227` | `#228` | `#229` | `#231 / #230` |

The shape selector is also exact. For an ordinary part, equality with the
first neighbour yields shape `5` when the second is not behind and shape `1`
otherwise; equality with the second yields `5` or `3`; both neighbours behind
yield `6`, both ahead `5`, and a current phase between them yields `3` or `1`
according to direction. Crossing parts use the corresponding
`4/0`, `4/2`, `6`, `4`, `0`, and `2` shapes. This is control-flow evidence,
not a frame-look inference.

At terminal phase 4, view rotation zero draws body `#233` on ordinary parts
and body `#232` on entry/crossing parts. The latter is the perpendicular water
orientation. Every crossing is a second transparent draw over that body:
phases 1/2 use scaffold bridge `#236`; phases 3/4 use stone arch bridge
`#240`. After converting the original `FUN_005A0F60` projection anchor to
Native's tile centre, the exact source-pixel top-left offsets are `(60,-100)`
for phases 1/2, `(65,-92)` for phase 3, and `(56,-86)` for phase 4. The
authored map's 528 repeated reserve cells are therefore never 528 independent
canal sprites: the runtime replaces/suppresses them and draws exactly one
depth-sorted 318x160 body per part plus the three crossing overlays.

Classification: resource-key decoding, phase-zero terrain and road IDs,
variation byte, phase 1...4 body selector, crossing overlays, and default-view
offsets are `confirmed`. Other map-view rotations have recovered executable
jump tables but are not yet wired into Native because the current player
camera has no rotation action.

Native verification on 2026-08-13 used `scripts/qin1-ui-smoke.sh`. Its Retina
capture is 2048x1600 including the 32-logical-pixel macOS title bar, so the
player content is exactly 1024x768 logical pixels. The visible Haunxian canal
is continuous, the repeated 528-cell `#201` placeholder mosaic is absent, and
the crossing present in the viewport has the terminal stone-arch overlay. The
other two crossing indices are covered by the same catalog selection tests but
were outside that camera viewport. This is Native-side composition evidence,
not an original-state pixel comparison: an undistorted original Haunxian
capture at the same camera position has not yet been recovered, so exact visual
parity remains `unknown` and no pixel-diff completion claim is made. The smoke
capture stays under `tmp/` and is not a checked-in or runtime dependency.

Native now has an exact, fail-closed adapter for the recovered branches of both
routing caches. Its input keeps the serialized terrain word, live building
occupancy, current monument sub-phase, road/water auxiliary byte, primary
elevation-class byte, primary surface-object state, and generic building
footprint predicate as separate values; it never aliases a path mask to the
terrain word. Values from the independent layers remain optional, and the
adapter throws a coordinate-specific research error only when the branch being
executed actually reads an absent value. This preserves the original rebuild
order: primary derivation may clear stale terrain building bit `0x08` before
fallback derivation reads the same cell.

The Haunxian canal footprint supplies a closed source-backed fixture without
touching any unknown predicate. Its 528 cells derive primary values
`0x20 × 507` and `0x04 × 21`: the 507 monument cells reach the terrain
`0x10000000` branch before object dispatch and are rejected by mode 1, while
the 21 authored road-crossing cells reach the earlier road branch and are
accepted. The same cells derive fallback values `0x4C001000 × 507` and
`0x40 × 21` from building `83`, saved sub-phase `4`, and the road bit. A route
fixture between two original crossing cells proves that primary cannot span
the intervening canal but mode 19 can do so through the fallback classes. A
separate phase fixture confirms that phase `0` changes the off-road fallback
class to `2`, while phase `4` yields `0x4C001000`. These cache distributions,
the 21 crossing coordinates, and primary-to-fallback arbitration are
`confirmed` against `Haunxian.map` and the two hash-identified cache builders.

`FUN_00471CF0 @ 0x471CF0` closes one previously unnamed input: it returns true
only when the terrain low byte contains both water and road (`terrain & 0x44 ==
0x44`) and the separate `DAT_00F2B290` byte is nonzero. The fallback adapter
therefore requires that independent byte only for road/water cells. It yields
`0x40` when nonzero; with byte zero, ordinary water classification yields
`0x10000200`. `FUN_004C11B0 @ 0x4C11B0` is also no longer an unknown class:
its three callees reduce exactly to building IDs `26/27/28/194/195/196/197/
198/199`, all of which produce fallback class `2` in this builder.

## 2026-09-02 Qin occupancy classes: additional `+0xCC` closures

The Qin3 routing diagnostic reached `grandCanalWorkerRoutingGrids()` with
live placed buildings, but the previous catalog only covered houses and a
small set of service classes. I traced the building factory in both
hash-identified executables before extending the catalog. `FUN_0051C660
@ 0x51C660` dispatches these authored IDs to the following constructors and
vtable pointers:

| building IDs | vtable | direct factory path |
| --- | --- | --- |
| `31` | `0x007C0448` | `FUN_005F0C80` → `FUN_005F0E20` → `FUN_005F51D0` |
| `33` | `0x007C09B4` | `FUN_005F0C80` → `FUN_005F0E20` → `FUN_005F5270` |
| `43` | `0x007BFC2C` | `FUN_005F0C80` → `FUN_005F0E20` → `FUN_005F50C0` |
| `46` | `0x007C06FC` | `FUN_005F0C80` → `FUN_005F0E20` → `FUN_005F5230` |
| `116/117/243...248` | `0x007AA83C` | `FUN_004142E0` → `FUN_004143B0` → `FUN_00416C50` |
| `126` | `0x007B65E4` | `FUN_0051C660` fallthrough → `FUN_0051C9A0` (generic base) |
| `195...199` | `0x007AEA40` | `FUN_004C0600` → `FUN_004C0660` → `FUN_004C2220` |
| `194` | `0x007AECC8` | `FUN_004C0630` → `FUN_004C0660` → `FUN_004C25E0` |
| `26...28` | `0x007AEF50` | `FUN_004C0640` → `FUN_004C0660` → `FUN_004C2710` |
| `35` | `0x007BCA9C` | `FUN_005AC310` → `FUN_005AC260` → `FUN_005AC3A0` |
| `37` | `0x007BCD50` | `FUN_005AC310` → `FUN_005AC260` → `FUN_005AC6C0` |
| `27/28/29` | `0x007B7B64` | `FUN_00557430` → `FUN_00557340` → `FUN_00559040` |
| `36/48` | `0x007B7E24` | `FUN_00557430` → `FUN_00557340` → `FUN_005590A0` |
| `53` | `0x007B72C8` | `FUN_005D36E0` → `FUN_005D3580` → `FUN_00554D40` |
| `124` | `0x007BD274` | `FUN_005B3AF0` → `FUN_005B3B10` → `FUN_005B3FD0` |
| `125` | `0x007B43AC` | `FUN_00507670` → `FUN_005075A0` → `FUN_00507090` |
| `211` | `0x007ACEDC` | `FUN_0048A7E0` → `FUN_0048A800` → `FUN_0048A8E0` |
| `192` | `0x007AF6E0` | `FUN_004C2930` → `FUN_004C2960` → `FUN_004C5CA0` |
| `193/237/238/239` | `0x007AF95C` | `FUN_004C2930` → `FUN_004C2960` → `FUN_004C5CC0` |
| `214/215/217` | `0x007BC0B4` | `FUN_005AB030` → `FUN_005AAE70` → `FUN_005AB0D0` |
| `216/218` | `0x007BC584` | `FUN_005AB030` → `FUN_005AAE70` → `FUN_005ABF40` |
| `219` | `0x007BC318` | `FUN_005AB030` → `FUN_005AAE70` → `FUN_005AB860` |

For every vtable in this table, file-offset reads at `vtable + 0xCC` are
`50 6A 41 00` (`0x00416A50`) in both canonical PE images:

```
8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753  EmperorEN.exe
dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a  EmperorCH.exe
```

`FUN_00416A50` is the two-argument constant-false predicate (`xor al,al;
ret 8`). This is direct live-object vtable evidence, not a visual inference.
The new IDs are admitted by `BuildingFootprintPredicateCatalog`; roadblock
all other unlisted classes remain fail-closed because their concrete
construction/vtable path has not been recovered here. This section is
`confirmed` static evidence, but it does not establish the predicate's
higher-level gameplay meaning or the separate market-peddler/provider rules.

The following remains unresolved: the not-yet-taken branches of a complete
semantic port, chiefly the primary surface-object/image discrimination, the
generic building vtable `+0xCC` predicate, and the Great Wall subtype helpers.
Until those are closed:

- preserve the authored Haunxian placement, 33 part identities, five-phase
  schedule, recovered requirement table, and verified routing-cache inputs in
  Native state;
- do not expose the legacy begin-project button or click-a-segment tool;
- do not create a new Native project using the unsupported `2400/600/800`
  configuration;
- retain legacy Codable structures only to decode saves produced by earlier
  Native builds, never as evidence of original behavior.
