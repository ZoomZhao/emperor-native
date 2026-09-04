# Housing desirability propagation (`0x44F1D0` → `0x44ECD0`)

Static evidence for the original neighborhood-appeal field. This pass is
separate from the housing upgrade-reason classifier in
`housing-evolution-reasons.md`.

Binaries: `EmperorEN.exe`
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and
`EmperorCH.exe`
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`). The
EN/CH entries for every function listed below are `identical` in
`local/source/compare-report.tsv`; no original runtime was launched.

## Recovered control flow

- `FUN_0044F1D0 @ 0x44F1D0` clears a `0x32C4`-cell appeal buffer at
  `DAT_00F11C70`, enumerates the live building objects from `FUN_00413B40(1)`,
  skips objects that are not active, and obtains each building's model fields
  1…4 through `FUN_0044CC50(buildingModelID, fieldIndex)`. The object's vtable
  supplies its map footprint/anchor values (`+0x168`, `+0x16C`, `+0x170`).
  It then calls `FUN_0044ECD0` once per active building. `FUN_0044EB20` is the
  post-pass that handles the remaining map-cell cases and invokes the same
  writer for explicit blocked/terrain states.
- `FUN_0044ECD0 @ 0x44ECD0` is the radial propagation driver. It rejects a
  non-positive footprint or zero initial value, clamps the authored maximum
  range to **10**, starts at radius 1, and invokes `FUN_0044ED90` once per
  radius. After `param_5` tiles it changes the propagated value by
  `param_6` (the model's desirability step and step size), preserving the
  original sign and clamping at ±100 in the cell writer. The five arguments
  passed by `FUN_0044F1D0` are the object footprint, initial desirability,
  step distance, step size, and maximum range from the building model table.
- `FUN_0044ED90 @ 0x44ED90` selects a footprint/radius offset list (for
  one-tile objects via `FUN_004BB390`; larger footprints use
  `FUN_0044D090`), translates each offset into the map buffer, and writes the
  value through `FUN_0044F1B0`/`FUN_0044F190`. It uses `FUN_0044E770` to assign
  one of 16 angular sectors. For negative values, the `DAT_00A655A0` /
  `DAT_00A655A4` sector state suppresses or shortens propagation through
  occupied cells and carries the nearest blocking radius; positive values
  follow the direct cell path. `FUN_004BB390` contains the original
  footprint/radius boundary tables and returns an out-of-bounds result.

- `FUN_0044F180 @ 0x44F180`, `FUN_0044F1B0 @ 0x44F1B0`, and
  `FUN_0044F190 @ 0x44F190` are the byte-buffer read/add/absolute-write
  primitives used by the propagation loop. `FUN_0044E4D0 @ 0x44E4D0` defines
  the 16-sector angular intervals used by `FUN_0044E770`.

### Post-pass special-cell producers (confirmed, flag meanings unknown)

`FUN_0044EB20 @ 0x44EB20` runs from the tail of `FUN_0044F1D0` after the
ordinary active-building walk. It scans the map's row spans and can invoke the
same `FUN_0044ECD0` producer for cells that are not ordinary live building
objects. The dispatch is exact:

* Objects whose model is Grand Way (`0x6F`) or Imperial Way (`0x71`) use that
  object's model fields 1…4.
* A cell with `DAT_00F9D620` bit `0x80` and `DAT_00F6A9E0` bit `0x2` uses
  Vacant House model `2` fields 1…4; if bit `0x2` is absent, the routine
  clears bit `0x80` instead.
* A cell without bit `0x80` but with `DAT_00F6A9E0` bit `0x20` uses Gardens
  model `0x73` fields 1…4.
* A cell without bits `0x80` or `0x20` is skipped unless bit `0x1000` is set;
  that path emits the fixed producer tuple `initial=-2`, `stepDistance=1`,
  `stepSize=1`, `maximumRange=2`.

The EN/CH body is identical in `local/source/compare-report.tsv`. This closes
the **post-pass producer set and branch constants**, showing that the shared
appeal buffer is not sourced solely from the ordinary `FUN_0044F1D0` building
list. The semantic names of the three map flag bits, the provenance of the
row-span arrays, and the Native map-state projection remain unknown; no
special-cell branch is enabled in Native.

**Evidence class:** `confirmed` for model IDs, branch masks, field selection,
fixed tuple, and producer call; `unknown` for flag semantics, row-span source,
and Native representation.

The row-span source is now separately bounded. `FUN_004B05F0 @ 0x4B05F0`,
called by the map setup paths `FUN_0053D100`, `FUN_0053CEC0`, `FUN_00534410`,
and `FUN_00534BF0`, derives `DAT_0101CD18`/`DAT_0101C988` start/end columns
and `DAT_0101C5F8` row bases from the runtime map dimensions and the canonical
stride `0xE4`; it does not read the appeal or terrain flag arrays. Therefore
`FUN_0044EB20`'s scan is a clipped row-major traversal of the active map
window, not a hidden authored producer list. The map flag bits remain the only
unknown inputs to its special-cell branches.

### Square-ring table reconstruction (confirmed, 2026-08-30)

The apparent count mismatch between `FUN_004BB810` and `FUN_004B0710` is an
address-labeling error, not an unresolved runtime contradiction. `FUN_004B0710`
fills twelve pointer arrays with the perimeter of squares whose coordinate
bounds are `[-1,1]`, `[-2,2]`, …, `[-12,12]`; their point counts are therefore
`8,16,24,…,96`. `FUN_004BB810` then reads twelve contiguous halfwords at
`DAT_0081F158` (the first value is the `8` halfword at the labeled address,
not the preceding zero-valued sentinel) and copies exactly that many `(x,y)`
pairs into `DAT_00A63704`, flattening each pair as `x + y * 0xE4`.
`FUN_0044ED90` indexes those generated rings with radius values 1…10 after
`FUN_0044ECD0` clamps the authored maximum range to 10. This closes the ring
cardinality and ordering contract; it does **not** close the map-anchor or
occupancy semantics needed to replace Native's fallback.

- The shared footprint table at `DAT_0081FF18` is recoverable from the EN PE
  `.data` bytes. The corresponding `.data` dump slice (`0x81FF10…0x82003F`)
  has the same SHA-256
  (`3df0584d6878f86618c5f904700a96783302b91603d42bb4aa91359e6f58871b`)
  in the CH PE, so the table is not part of the widescreen patch. It
  is a row-major **6 × 6** array of 8-byte pairs. The first dword in each pair
  is the linear map offset consumed by the map writers; rows advance by the
  canonical map stride `0xE4`, and columns advance by one. In row-major form
  the first dwords are:

  ```text
  [ 0, 1, 2, 3, 4, 5 ]
  [ 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9 ]
  [ 0x1C8, 0x1C9, 0x1CA, 0x1CB, 0x1CC, 0x1CD ]
  [ 0x2AC, 0x2AD, 0x2AE, 0x2AF, 0x2B0, 0x2B1 ]
  [ 0x390, 0x391, 0x392, 0x393, 0x394, 0x395 ]
  [ 0x474, 0x475, 0x476, 0x477, 0x478, 0x479 ]
  ```

  The paired second dwords are `[0…5], [8…13], …, [40…45]`; every current
  caller in the split corpus uses only the first dword, so the second field's
  semantic purpose remains **unknown**. `FUN_0042C480` and `FUN_004F8ED0`
  independently confirm the same row stride (`src += 2`, row pointer `+= 0xC`)
  while iterating object dimensions returned by vtable `+0x28`. The appeal
  copy (`FUN_004ACD10`) uses the same table for multi-cell objects, but the
  object byte at `+0x07` supplies a single square side length; this does not
  prove that Native's rectangular `BuildingFootprint` orientation or anchor
  convention is equivalent.
- The negative-propagation occupancy byte is also bounded, but not named. The
  relevant map array is `DAT_00F37DA0`; `FUN_0044ED90` reads bit `0x04` to
  choose its occupied-cell sector path. `FUN_004153B0` sets that bit when the
  current object's vtable `+0x268` callback returns nonzero, while
  `FUN_004146D0` clears it after the same callback. This proves a callback-
  driven transient cell state, not a direct `PlacedBuilding` occupancy flag;
  the `+0x268` predicate and its complete writer lifecycle remain **unknown**.

### Negative propagation arbitration (confirmed, predicate still unknown)

The sector branch itself is fully specified by `FUN_0044ED90` and is captured
by the side-effect-free `OriginalAppealPropagationCatalog.negativePropagationStep`
helper. For a negative ring value, an unoccupied cell writes the current
appeal only when `sector == -1`, the sector has not been marked, or
`currentRadius <= blockingRadius[sector]`. An occupied cell never writes. If
its sector is unset or the current radius is nearer (`< blockingRadius`), the
routine marks that sector and records the radius. For rings with fewer than 16
cells, an even sector additionally seeds the clockwise/counter-clockwise
adjacent sectors when their existing blocking radius is exactly `1`; the
seeded entries receive the current radius. The state is reset for each source
building by `FUN_0044ECD0`.

This closes the **arbitration algorithm** and its strict comparison polarity,
but not the input occupancy predicate: `DAT_00F37DA0` bit `0x04` still comes
from the unresolved, class-dependent `vtable +0x268` callback and its writer
lifecycle. The helper is therefore a research contract only and is not wired
to Native desirability.

**Evidence class:** `confirmed` for sector indexing, write suppression,
nearest-radius updates, short-ring neighbor seeding, and per-source reset;
`unknown` for the callback's class coverage/meaning and Native map projection.

### One confirmed occupancy-dispatch family (2026-08-30)

The only complete caller body recovered for the occupancy bit is
`FUN_004153B0 @ 0x4153B0`, a residential wall/gate operation. Its candidate
filter `FUN_00415700 @ 0x415700` accepts exactly model IDs
`0x59,0x5A,0x5B,0x68,0x69,0x6A,0xE7,0xE8` (the authored residential wall and
gate variants). For each of four cardinal offsets it resolves the map object,
rechecks that filter, and invokes the candidate's `vtable +0x270`; the source
wall/gate invokes its own `vtable +0x268` and ORs bit `0x04` into
`DAT_00F37DA0[sourceObject +0x10]` when that callback is non-zero; `+0x10`
is the object's canonical map-cell index, not its load-state byte at `+0x04`.
`FUN_004146D0 @ 0x4146D0` clears the same bit at the source object's canonical
map index after its `+0x268` callback. Constructors `FUN_00416CB0` and
`FUN_00416CD0` install the two wall/gate vtable families, so this dispatch is
not evidence that ordinary houses or service providers own the predicate.

This closes the **residential-wall/gate caller and model filter** portion of
the occupancy path. It does not identify the boolean meaning returned by the
wall/gate `+0x268`, the lifetime of the candidate `+0x270` side effect, or the
ordinary-building dispatches that may set the bit elsewhere; those remain
unknown and keep Native desirability fail-closed.

### Provider vtable `+0x268` is not the appeal-occupancy predicate (confirmed,
2026-08-30)

The service-provider constructors recovered in the split corpus install three
distinct vtables: `FUN_0051C090` (Well IDs `72/73`) installs `0x7B5EB4`,
`FUN_0051C0B0` (Herbalist's Stall `207`) installs `0x7B6114`, and
`FUN_0051C0D0` (Acupuncturist's Clinic `208`) installs `0x7B6374`. Direct
little-endian reads of the `+0x268` word from both hash-matched PE inputs give
the same four-word sequence (SHA-256 of the concatenated 16 bytes:
`f980c37ab531cd6842fb485cd06b661b6ba596f80415d51a47e8b7e3b9139910`):

| vtable / authored class | `+0x268` target | static role |
| --- | --- | --- |
| `0x7B5EB4` / Well `72/73` | `0x51CE00` | common provider serializer wrapper (`FUN_00427430` + state serializer) |
| `0x7B6114` / Herbalist `207` | `0x51CE00` | same serializer wrapper |
| `0x7B6374` / Acupuncturist `208` | `0x51C3A0` | provider-state serializer body; direct code begins with `FUN_0040CF80`, `FUN_0041FC10`, `FUN_0041FBF0` and repeated `FUN_00780642/533` field I/O |
| `0x7AD878` / Entertainment Area `71` | `0x48D6B0` | registry-linked object accessor (`[this+0x150]` → `FUN_0047F1B0`) |

The Well/Herbalist target is present in `local/source/split-merged` as
`FUN_0051CE00 @ 0x51CE00`; the Acupuncturist body is not emitted as a split
entry but its target word and serializer-shaped instructions are identical in
the canonical English and Chinese PE files. The Entertainment target is also
not a boolean constant: its first instructions load the object's `+0x150`
registry key and return the resolved object pointer. Therefore these provider
slots cannot be used as evidence that a service building contributes the
`FUN_004153B0` appeal-occupancy bit. The generic `+0x268` callback remains
class-dependent and unresolved for the ordinary map-object classes that reach
the appeal pass.

**Evidence class:** `confirmed` for the constructor→vtable assignments, the
four PE slot words, the Well/Herbalist serializer target, and the Entertainment
registry accessor; `unknown` for the complete ordinary-building `+0x268`
dispatch set and its relation to terrain/occupancy semantics. No Native appeal
or service bridge is enabled from this table.

### Ordinary-building `+0x268` is heterogeneous, not a universal occupancy callback (confirmed negative, 2026-09-01)

To close the remaining ordinary-building question without treating a vtable
label as a semantic name, the `+0x268/+0x26C/+0x270` words were read directly
from both hash-matched PE inputs. The English executable is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`; the
Chinese executable is
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`. All
listed 12-byte slices are byte-identical between the two builds:

| vtable / known class | `+0x268` | `+0x26C` | `+0x270` | direct byte-level classification |
| --- | ---: | ---: | ---: | --- |
| `0x7AB59C` / base `Building` | `0x0042CD10` | `0x004FA3C0` | `0x00416CA0` | `.text`, `.text`, `.text`; `0x42CD10` is `mov eax,0x1C; ret` |
| `0x7ABA38` / `HouseBldg` | `0x007CFCF8` | `0x0042E0B0` | `0x007CFD48` | first and third words are `.rdata` descriptor blocks, not code addresses |
| `0x7B5EB4` / Well `72/73` | `0x0051CE00` | `0x0051CAA0` | `0x005037F0` | `.text`; provider serializer/house-state helpers |
| `0x7B6114` / Herbalist `207` | `0x0051CE00` | `0x0051CAA0` | `0x005037F0` | `.text`; same provider helper family |
| `0x7B6374` / Acupuncturist `208` | `0x0051C3A0` | `0x007D35F0` | `0x0051C1A0` | mixed; provider-state serializer family |
| `0x7AD878` / Entertainment Area `71` | `0x0048D6B0` | `0x0048D4F0` | `0x0048D610` | `.text`; registry-linked object accessor family |

The House words are not a transcription error: the bytes at `0x7CFCF8` and
`0x7CFD48` are structured `.rdata` records (zero header words followed by
`0x817A80`/`0x817AA0` links and `0xFFFFFFFF` sentinels), whereas the executable
`.text` range begins at `0x00401000` and ends before the `.rdata` range. A
direct virtual call therefore cannot be assigned the same meaning as the
wall/gate `+0x268 → FUN_004E1C40` path merely because the byte offset matches.

The only direct call to `FUN_004146D0 @ 0x4146D0` in the canonical `.text` is
at `0x4163B8` (the containing body starts at `0x4163B0`); that helper then
dispatches the *current object's* `+0x268`, clears `DAT_00F37DA0` bit `0x04`,
and dispatches `+0x26C/+0x270`. There are no direct calls to `0x42CD10` in
either PE. The split corpus marks `0x4146D0` and `0x42E0B0` EN/CH-identical,
but has no indexed body for the tiny `0x42CD10` stub or the House descriptor
blocks. This is a confirmed negative for using `FUN_004146D0` or the Base
Building slot as a universal ordinary-house occupancy implementation.

The callback's class coverage, the meaning of the House descriptor pair, and
the complete writer/lifecycle for `DAT_00F37DA0` therefore remain **unknown**.
Native desirability and occupancy stay fail-closed; no new service or House
mapping is justified by the slot bytes alone.

**Evidence class:** `confirmed` for the EN/CH slot words, section/range
classification, the `0x4163B8` direct-call site, and the absence of direct
`0x42CD10` calls; `unknown` for descriptor semantics, indirect callers, and
ordinary-building occupancy behavior.

- The producer/copy boundary is two scheduler phases in `FUN_004AC2B0 @
  0x4AC2B0`: phase `0x25` runs `FUN_0053C870` then `FUN_0044F1D0`, and the next
  phase `0x26` runs `FUN_004ACD10`. `FUN_004ACD10` walks the same live-object
  list and writes each object's `+0x5E` appeal field from the buffer. Single-cell
  objects read the anchor cell through their vtable `+0x1F8`; multi-cell
  objects enumerate the footprint offsets at `DAT_0081FF18` and take the
  maximum cell value. A separate object flag (`+0x60`) adds exactly 10 to the
  copied value. The flag's creation-time writer is now recovered below; the
  live map-base projection and dynamic object lifecycle remain separate
  boundaries.

### Creation-time map origin: Qin-class setter recovered (confirmed, 2026-08-30)

The indexed Ghidra corpus skips the short function immediately after
`FUN_00428A80 @ 0x428A80`, but direct read-only PE disassembly recovers the
missing body at `0x428AA0..0x428C01`. Its 0x162 bytes are byte-identical in
the canonical EN/CH pair (SHA-256
`d83c197c8d106887fbd5ccb70a461298a5f6089b670d2a9a0112ed8ea55445e` for the
function slice). The caller `FUN_0042D540 @ 0x42D540` pushes
`(param_4, param_3, param_2)` and invokes vtable `+0x94`, so the callee's
effective arguments are `(modelID, x, y)`.

The recovered setter writes the model ID to object `+0x14`, then writes the
creation coordinates directly to `+0x0A = x` and `+0x0C = y`. It computes the
linear map pointer as

```text
DAT_0101D0C8 + x + y * 0xE4
```

and stores it at `+0x10`, then reads the terrain byte and initializes the
remaining base-object fields before returning `ret 12`. The only coordinate
adjustment branch is `FUN_005E1720 @ 0x5E1720`, which returns true only for
model IDs `56` and `58`; that branch applies `FUN_004B8200` and
`FUN_005DD940` deltas and recomputes `+0x10`. It therefore does not apply to
Qin houses `2…17`, Entertainment `71`, Well/Herbalist/Acupuncture
`72/73/207/208`.

Direct vtable reads in both PE images show the base/House, Well, Herbalist,
Acupuncture, and Entertainment Area vtables all carry `+0x94 → 0x428AA0`.
Together with `FUN_00416400 @ 0x416400` copying `+0x0A/+0x0C` into appeal
reader coordinates `+0x2A/+0x2C`, this closes the **Qin creation-origin
source**: the supplied `(x,y)` is the origin for these classes, with no
model-specific translation branch.

This does not identify the paired fields in `DAT_0081FF18`, the multi-cell
occupancy arbitration, or the downstream Native projection. The appeal path
therefore remains fail-closed until those independent contracts are recovered.

### Appeal `+0x60` adjustment flag writer (confirmed, 2026-09-01)

The creation setter at `0x428AA0` does not leave the appeal adjustment flag
uninitialized. After computing the object's origin and side, it calls
`FUN_004BAEE0 @ 0x4BAEE0` with `(x, y, footprintSide)` and stores the boolean
result at object `+0x60` (`mov byte [esi+0x60], al` at `0x428B8F`). The indexed
corpus contains the callee and marks the EN/CH pair `identical` in
`local/source/compare-report.tsv`.

`FUN_004BAEE0` selects `DAT_00820038 + footprintSide*0x60`, scans the ordered
non-zero perimeter offsets (at most 24, stopping at the first zero), and tests
the canonical terrain word `DAT_00F6A9E0[DAT_0101D0C8 + x + y*0xE4 + offset]`
for bit `0x04`. It returns true on the first matching cell and false when the
row is exhausted. `FUN_00516BE0` independently calls the same helper before
adding ten to its appeal maximum, corroborating that this is the source of
the `+0x60`-gated `+10` adjustment rather than a guessed object field.

`OriginalAppealPropagationCatalog.objectOffset60Flag` represents this scan as
an explicit-input, fail-closed primitive using the recovered perimeter rows.
Native already preserves the serialized `DAT_00F6A9E0` terrain words, but the
runtime `DAT_0101D0C8` base/coordinate projection and post-placement refresh
lifecycle are not yet proven isomorphic; the helper is therefore not wired
into live Qin simulation.

**Evidence class:** **confirmed** for the writer call, perimeter-table order,
24-entry bound, zero sentinel, terrain bit `0x04`, EN/CH identity, and the
`+10` consumer; **unknown** for the runtime map-base projection and any later
writer that mutates the flag after creation.

The coordinate helper is present as `FUN_004273F0 @ 0x4273F0`. It returns

```text
DAT_0101D0C8 + object[+0x2A] + object[+0x2C] * 0xE4
```

and is used by provider/venue code to turn refreshed coordinate fields into an
absolute map-cell index. It is not the appeal byte getter. The appeal getter is
the separate, direct-PE body at `FUN_004273D0 @ 0x4273D0`, installed at vtable
`+0x1F8` for the Qin-relevant classes listed below; it reads object `+0x10`,
then returns `DAT_00F11C70[object+0x10]` through `0x44F180`; the intermediate
`0x53C870` call's return value is not the appeal buffer and the pushed index
remains the reader's argument.
Both 17-byte EN/CH bodies are identical (SHA-256
`2baa3fe1b196daeeac0c024e4df658dddada6842463541ab17e36e08c2cf018f`).
Refresh-time `+0x84` callbacks still overwrite `+0x2A/+0x2C` for access cells,
so those coordinates must not be conflated with the creation origin or the
`+0x10` appeal index. Multi-cell orientation, `DAT_00F37DA0` occupancy
suppression, and the Native grid projection remain unresolved; Qin
desirability stays disabled.

**Evidence class:** `confirmed` for the recovered `0x428AA0` setter body,
its EN/CH byte identity, Qin vtable targets, `(modelID,x,y)` argument order,
`+0x0A/+0x0C/+0x10` origin writes, the `0xE4` formula, and the `56/58`-only
adjustment branch; `unknown` for multi-cell orientation details, paired
footprint-table fields, occupancy semantics, and Native grid projection.

### Qin `+0x1F8` appeal getter is a shared `+0x10` index reader (confirmed, 2026-09-04)

Direct read-only PE inspection corrects the earlier slot/address conflation.
In both canonical images, the `+0x1F8` word for the base Building/House
(`0x7AB59C`), HouseBldg (`0x7ABA38`), Entertainment Area (`0x7AD878`), Well
(`0x7B5EB4`), Herbalist (`0x7B6114`), and Acupuncture (`0x7B6374`) vtables is
`0x004273D0`. The 17-byte EN/CH function slice is identical (SHA-256
`2baa3fe1b196daeeac0c024e4df658dddada6842463541ab17e36e08c2cf018f`) and
the concatenated six `+0x1F8` slot words are also identical (SHA-256
`c918b2b00ae76df23218c23b6f1907de868ab29c16fc81f0cab426103729142d`),
with every word equal to `0x004273D0`. The function disassembles to:

```text
eax = object[+0x10]
push object[+0x10]
call FUN_0053C870             // intermediate call; return value is unused
return FUN_0044F180           // DAT_00F11C70[object+0x10]
```

The neighboring `FUN_004273F0` is a distinct coordinate-to-linear-index
helper (`DAT_0101D0C8 + object[+0x2A] + object[+0x2C]×0xE4`) used by refreshed
access/venue targets; it is not the `+0x1F8` appeal getter. The creation setter
at `0x428AA0` establishes `+0x10 = DAT_0101D0C8 + x + y×0xE4` for the Qin
classes, so the getter's input is now closed as the canonical object map-cell
index. Native records this descriptor and the six vtable addresses in
`OriginalAppealPropagationCatalog`, but does not wire the getter: the
multi-cell occupancy arbitration, post-placement writers, and complete
Native object-grid projection remain independent blockers.

**Evidence class:** `confirmed` for the vtable words, EN/CH function bytes,
buffer addresses, `+0x10` read, and Qin creation-index relationship;
`unknown` for occupancy/lifecycle and Native projection.

### Runtime map-base selector is table-backed (confirmed control flow, 2026-09-01)

The runtime `DAT_0101D0C8` source is now closed at the control-flow level.
`FUN_0053CE60 @ 0x53CE60` obtains a selector from
`FUN_004F8210(FUN_0052E7B0())`, multiplies it by `0x10`, and copies one
four-dword row from `DAT_00856C64` into both the map descriptor and the
runtime globals:

```text
mapWidth  = DAT_00856C64[idx*0x10 + 0x00]  -> DAT_0101D0C0
mapHeight = DAT_00856C64[idx*0x10 + 0x04]  -> DAT_0101D0C4
base      = DAT_00856C64[idx*0x10 + 0x08]  -> DAT_0101D0C8
rowAdvance = DAT_00856C64[idx*0x10 + 0x0C]  -> DAT_0101D0CC
```

`FUN_00534410 @ 0x534410`, `FUN_00534BF0 @ 0x534BF0`, and
`FUN_0053CEC0 @ 0x53CEC0` call this selector before map initialization or
passes. The EN/CH variants of all four functions are marked `identical` in
`local/source/compare-report.tsv`; `FUN_00534BF0` consumes the selected
width/height for its full-map loops. Thus `DAT_0101D0C8` is a selected,
table-backed base offset, not a constant that can be inferred from a
serialized city rectangle.

The initialized table rows are present in the hash-matched PE data section
(`DAT_00856C64`, file offset `0x456C64`, 0x60 bytes). Direct reads from both
canonical files produce the same six rows (little-endian), and the slice
SHA-256 is `ac39b5610e0a3be60215936402e8f8064686b4c8778029af3857f7eec965a7f3`:

| selector | width | height | base | rowAdvance |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 56 | 56 | 19,694 (`0x4CEE`) | 172 |
| 1 | 84 | 84 | 16,488 (`0x4068`) | 144 |
| 2 | 112 | 112 | 13,282 (`0x33E2`) | 116 |
| 3 | 140 | 140 | 10,076 (`0x275C`) | 88 |
| 4 | 170 | 170 | 6,641 (`0x19F1`) | 58 |
| 5 | 226 | 226 | 229 (`0x00E5`) | 2 |

`FUN_0052E630 @ 0x52E630` scans these six rows in order and stores the
matching selector when the current map width (`DAT_00C5CAFC`) matches the row;
the width/height pairs are equal in every row. Each row also satisfies
`base = ((228 - width) / 2) * 228 + ((228 - width) / 2)` and
`rowAdvance = 228 - width`, so the selected base is exactly the serialized
centered `startOffset`, while `width + rowAdvance` is the canonical `0xE4`
row stride. `EmperorMap` validates those same centered-origin invariants and
now exposes the source-backed `OriginalMapRuntimeDescriptorCatalog` rather
than substituting a guessed dimension mapping.

This closes the map-base/row-advance projection for every authored rectangle
whose dimensions are in the recovered table (all current GameData city maps),
including the selector and literal rows. It does not close multi-cell
orientation, object-registry occupancy writes, or later post-load descriptor
mutation; those remain separate Qin desirability blockers.

**Evidence class:** **confirmed** for the selector call chain, literal rows,
dimension-keyed selection, centered base/stride relationship, runtime
assignments, and EN/CH identity; **unknown** only for any post-load mutation
that would replace the selected descriptor after this initialization.

### Appeal-reader coordinates are refreshed through vtable `+0x84` (confirmed, 2026-08-30)

The corpus does expose a separate writer for the coordinates consumed by
`FUN_004273F0`. `FUN_004ACFC0 @ 0x4ACFC0` (calendar case `0x15`) first runs
`FUN_005AE140`'s flood pass, then walks active objects, clears `+0x2A` and
`+0x2C`, and invokes each object's vtable slot `+0x84` with a local result
pointer. The common refresher `FUN_00416400 @ 0x416400` uses the object's
`+0x10` cell index to read `DAT_01391FE0[index]`, copies object `+0x0A/+0x0C`
into `+0x2A/+0x2C`, and stores the flood value in its result field. The
type-specific refreshers `FUN_00426DF0`, `FUN_004F01F0`, `FUN_00507950`,
`FUN_00508D50`, and `FUN_005E1D40` instead choose a candidate through
`FUN_004BAF40`; the latter two require terrain bit `0x40` (road) on the
selected cell before writing `+0x2A/+0x2C`.

This closes the **refresh-time writer** and its caller order, but it does not
identify which `+0x84` implementation is installed for every Qin-relevant
class. The coordinates are an access/refresh contract, not permission to
substitute those access cells for the creation origin. Native must keep the
live appeal projection disabled until the class-specific `+0x84` selection,
multi-cell occupancy arbitration, and map-buffer projection are all
represented.

**Evidence class:** `confirmed` for the `FUN_004ACFC0 → vtable +0x84` order,
the `FUN_00416400` field copies, and the road-bit guard in the specialized
refreshers; `unknown` for vtable-class assignment, multi-cell occupancy,
map-buffer projection, and Native wiring.

### Appeal buffer → residential object field (confirmed, 2026-08-30)

The final object-field boundary is now closed independently of the map-anchor
work. `FUN_004ACD10 @ 0x4ACD10` runs in scheduler phase `0x26` after the
`FUN_0044F1D0` buffer rebuild and writes the computed appeal byte to the live
building object at `object +0x5E` (single-cell: the `vtable +0x1F8` anchor read;
multi-cell: the footprint maximum plus the recovered `+0x60` adjustment).
The direct PE reason classifier at `FUN_0051A660` reads the same byte from its
HouseBldg `ecx` object (`movsx ecx, byte ptr [edi+0x5e]`) before comparing it
with the authored house columns returned by `FUN_0044CC80`; when blocked, it
writes only the reason ordinal to `cHouseInfo +0x3A` through `vtable +0x1E4`.
The EN/CH `0x51A660…0x51AEC0` range is byte-identical (SHA-256
`65e81e5a6501606e01191fa6ef0d6436b2deb7461ea0d6c457c7789b70b4bd1e`).

The monthly popularity/immigration walk independently consumes the buffer
before the cached copy: `FUN_004AE900 @ 0x4AE900` calls
`FUN_005180E0 @ 0x5180E0`, whose active-building loop invokes each object's
`vtable +0x1F8` and uses that byte in the authored housing/popularity
calculation. Both function rows are `identical` in
`local/source/compare-report.tsv`. Thus the original contract is not
“appeal is an unconnected global buffer”: it is (1) rebuilt into the shared
map buffer, (2) read by the single-cell/multi-cell object getter, (3) cached at
HouseBldg `+0x5E`, and (4) consumed by both the monthly population walk and the
reason classifier.

This closes the **buffer→residential-object** projection boundary. It does not
close how Native should represent the 6×6 multi-cell origin, transient
occupancy/sector arbitration, or the exact conversion of the cached byte into
all housing-evolution side effects. No Native Manhattan contribution is
upgraded to confirmed behavior by this section.

**Evidence class:** `confirmed` for the writer/readers, scheduler order,
HouseBldg field identity, reason-classifier use, and EN/CH identity; `unknown`
for multi-cell map projection, occupancy semantics, and downstream evolution
side effects.

### Residential object footprint side (confirmed, 2026-08-30)

The multi-cell loop's bound is the live object byte at `object +0x07`; it is
not a Native sprite-sheet or menu value. `FUN_004ACD10 @ 0x4ACD10` loads that
byte into `ok`, iterates `ok` rows and `ok` columns through the first dword of
`DAT_0081FF18`, and takes the maximum appeal-buffer byte over the resulting
square. The same byte is written by the common placement setter at
`0x428AA0` from the 24-byte model-record table at
`DAT_00823598` (the table's footprint/side field is eight bytes before the
primary-sprite key). Direct EN-PE table reads, cross-checked against the CH
image, give these Qin-relevant side values:

| authored model IDs | object +0x07 | shape used by the appeal copy |
| ---: | ---: | --- |
| houses `2…10` | `2` | 2×2 square |
| elite houses `11…17` | `4` | 4×4 square |
| Entertainment Area `71` | `2` | 2×2 square |
| Well `72/73` | `2` | 2×2 square |
| Herbalist's Stall `207` | `2` | 2×2 square |
| Acupuncturist's Clinic `208` | `2` | 2×2 square |

This closes the **side-length and supplied-origin** parts of the Qin multi-cell
contract: `0x428AA0` seeds the base linear index from the factory `(x,y)`, and
`0x4ACD10` adds the row-major first-dword offsets for that side. The paired
second dword in each footprint-table entry and the transient occupancy
arbitration remain unknown; a 2×2/4×4 size and origin alone are not sufficient
to wire the live Qin path.

**Evidence class:** `confirmed` for the `+0x07` read/write path, the model
record stride, the listed side values, square iteration, and Qin creation
origin; `unknown` for paired-table-field semantics, occupancy arbitration,
map projection, and downstream evolution effects.

The Native service-coverage bridge now keeps this distinction explicit:
`OriginalBuildingFootprintCatalog.residentialObjectFootprint` consumes the
confirmed 2×2/4×4 side values when projecting the radius-two callback, while
`footprint(forBuildingID:)` remains the separate construction-occupancy
catalog. This is a compatibility projection, not a claim that Native has
recovered the executable's object-slot or serialized map arbitration. The
outer-cell regression is covered by
`EmperorCoreTests.testRecoveredServiceCallbacksPreservePopulationAndEliteHousingGates`.

**Implementation class:** `inferred` for using the confirmed side byte in the
Native callback projection; the executable's occupancy/arbitration and full
map projection remain `unknown`.

### Qin building vtables select the generic radial producer (confirmed, 2026-08-30)

The geometry branch in `FUN_0044F1D0` is a virtual dispatch, so a model's
`+0x168` result must be checked before treating `FUN_0044EA70` as its shape
producer. The hash-matched Chinese PE
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`
contains the following identical three-word slice at `+0x168/+0x16C/+0x170`
for the base Building/House vtable `0x7AB59C`, HouseBldg vtable `0x7ABA38`,
Well `0x7B5EB4`, Herbalist `0x7B6114`, Acupuncture `0x7B6374`, and
Entertainment Area `0x7AD878`:

```text
+0x168 -> 0x00413A00
+0x16C -> 0x00416AC0
+0x170 -> 0x00416AD0
```

The corresponding raw bodies are short stubs. `0x413A00` returns zero,
`0x416AC0` is a `ret 0x10` no-op, and `0x416AD0` returns the object's byte
`+0x07`. Therefore these Qin-relevant classes all take the `c == 0` branch
of `FUN_0044F1D0`, call `FUN_0044ECD0`, and use the object side byte as the
producer footprint; none selects the custom rectangle path
`FUN_0044EA70 → FUN_0044E7F0`. This is consistent with the independently
recovered 2×2/4×4 side values above and removes a possible but unsupported
assumption that service buildings use a separate rectangle callback.

The split corpus has an indexed entry for `FUN_00413A00` (and marks it
EN/CH-identical in `compare-report.tsv`) but no standalone files for the two
tiny `0x416AC0`/`0x416AD0` interiors; the slot words and bytes above are
therefore recorded as direct read-only PE evidence rather than decompiler
source. The raw 12-byte slot slice at each listed vtable has SHA-256
`a778a79edb9ea78528fac476a145795a73c9faafd651e553c2391309f0d3af3a`.

This closes the **Qin-class branch selection and creation-origin source** only.
The occupancy callback and Native grid projection remain unknown, so the live
Qin desirability path stays fail-closed.

**Evidence class:** `confirmed` for the listed Chinese-PE vtable words, the
three raw stub bodies, and the `0x413A00` EN/CH compare row; `unknown` for any
unlisted building class and for the remaining occupancy/projection contract.

### Serialized occupancy layer retained by Native (confirmed, 2026-08-30)

The map serializer `FUN_0052E7C0 @ 0x52E7C0` writes the terrain layer
`DAT_00F6A9E0` as `UInt32[228²]`, immediately followed by
`DAT_00F37DA0` as another `UInt32[228²]`, before the subsequent byte grids.
This ordering is also recorded in `docs/exe-research/grand-canal-map-state.md`.
The latter layer is the array whose bit `0x04` is read by
`FUN_0044ED90 @ 0x44ED90` during negative appeal arbitration; its dynamic
writers include the class-dependent wall/gate path in `FUN_004153B0` and
`FUN_004146D0`.

`Sources/EmperorCore/EmperorMap.swift` now reads and preserves the exact
little-endian words in `appealFlags`, and
`DeterministicTerrainState.appealFlagsRawValues` projects the active mission
window for save/state inspection. `firstByteGridOffset` remains a compatibility
boundary for existing `legacyByteGrids`; it is not evidence that this
`UInt32` layer is a byte-only grid. Focused map parsing and the full
`EmperorCoreTests` suite cover the retained layer and projection.

This is a data-preservation bridge only. Native does **not** consume these
words for live desirability, nor does it reproduce the unresolved
`vtable +0x268` callback lifecycle, dynamic OR/clear operations, multi-cell
occupancy mapping, map-buffer projection, or special-cell producers. Those unknowns continue
to keep Qin desirability fail-closed.

**Evidence class:** `confirmed` for serializer order, layer width/type, parser
offset, and active-window projection; `unknown` for all dynamic writer
semantics and the complete Native appeal contract.

## Corroborating authored data

`GameData/Model/EmperorBuildingModels.txt` documents fields 1…4 as initial
desirability, step distance, step size, and maximum range, and separately
states that the maximum spread range is 10 tiles. The values passed by
`FUN_0044F1D0` therefore align with authored model semantics. The code also
confirms that chained structures are not a special source: only live objects
with a non-zero model value reach the propagation driver.

## Native gap and classification

The current `DeterministicDesirability.contribution` in
`Sources/EmperorCore/HousingEvolution.swift` is a presentation-safe fallback:
it uses Manhattan distance and does not model the 16 angular sectors,
footprint/radius offset tables, occupied-cell suppression, or the shared
0x32C4 appeal buffer. The recovered executable path and its
buffer→HouseBldg `+0x5E` projection are **confirmed**, but the Native
implementation is not yet isomorphic.

### Native live-wiring boundary (2026-08-31)

Before this audit, `CitySimulation.updateResidentialDesirability` consumed
that Manhattan helper during every monthly settlement and wrote its result into
`ResidentialUnit.desirability`, which then influenced `HousingEvolution`. That
was an unsupported gameplay consequence: the recovered executable's occupancy
callback, map-buffer projection, and multi-cell anchor mapping are still
unknown, so no distance-only value can stand in for the original `+0x5E` byte.
The monthly live path now leaves persisted desirability unchanged until those
inputs are recovered. `DeterministicDesirability.contribution` and the closed
ring/value helpers remain side-effect-free research/fixture primitives only;
they are not a Qin simulation source.

**Evidence class:** **confirmed** for the executable producer and object-field
boundary; **unknown** for the Native occupancy/anchor projection. The prior
live Manhattan write was an approximation and is intentionally fail-closed.

`OriginalAppealPropagationCatalog.squareRingOffsets` now records and tests the
closed ring geometry without changing simulation output. It is a research
scaffold only: the catalog is deliberately not wired into
`CitySimulation.updateResidentialDesirability` until the unresolved occupancy
and Native multi-cell projection are recovered.

The same catalog now exposes `propagatedValue`, a side-effect-free translation
of `FUN_0044ECD0`'s per-ring schedule: it emits the initial value at radius 1,
updates after the authored step-distance, snaps a signed progression to zero
when it crosses the original sign boundary, clamps writes to `[-100,100]`, and
honors the ten-ring cap. Coordinate/edge tests cover the schedule and both
zero-crossing directions. This closes only the value schedule; it does not
authorize replacing the live Manhattan fallback.

The following details remain **unknown** for a legal Native implementation:

- the complete mapping from the PE's footprint/radius tables to the Native
  isometric grid and building anchor convention;
- the exact occupancy/terrain bits consulted by `FUN_0044ED90`, the semantic
  meaning of the paired second dwords in `DAT_0081FF18`, and the runtime
  map-base/coordinate projection used by the `+0x60` flag scan;
- whether all object classes enumerated by `FUN_00413B40(1)` are represented by
  the current Native source lists.

### Object-field copy primitive (`FUN_004ACD10`, confirmed 2026-09-01)

The final buffer-to-object step is now represented as an explicit-input
research primitive, `OriginalAppealPropagationCatalog.copyObjectAppeal` in
`Sources/EmperorCore/HousingEvolution.swift`. It follows the recovered
`FUN_004ACD10 @ 0x4ACD10` order exactly:

* a one-cell object reads the caller-supplied anchor returned by vtable
  `+0x1F8`;
* a multi-cell object enumerates the row-major first dword of the `6 × 6`
  `0xE4`-stride footprint table and keeps the greatest **signed** appeal byte;
* a non-zero object `+0x60` flag adds `10` after the copy.

The helper rejects an invalid anchor, stride, or footprint side rather than
clipping or inventing a map coordinate. Tests cover signed maxima, the
post-copy offset, one-cell reads, and out-of-bounds rejection. This closes the
field-copy arithmetic only. The vtable anchor source, multi-cell occupancy
state, and map/object registry projection remain **unknown**, so the helper is
not called by `CitySimulation` and does not enable Qin desirability or housing
evolution.

The offset correction is deliberate. The split decompiler spells the final
condition as `(char)p[0x18]`, but `p` is an `int *`, so that expression reads
the byte at object offset `0x18 × 4 = 0x60`. Direct canonical-EN disassembly
at `0x4ACDDB` is `8A 46 60 84 C0` (read `object+0x60`, test it), followed by
`0x4ACDE2: 80 46 5E 0A` (add ten to `object+0x5E`); the corresponding CH
bytes are identical. The Native API therefore names the input
`objectOffset60NonZero`, and no `+0x18` object-field interpretation remains.

**Evidence class:** **confirmed** for the read order, signed maximum, `+10`
post-copy adjustment, canonical stride, and bounds behavior; **unknown** for
the unresolved inputs and their live Native projection.

### `DAT_0081FF18` second-dword census (confirmed negative, bounded, 2026-09-03)

The indexed EN/CH split corpus contains 18 function bodies that reference or
take the base address of `DAT_0081FF18`: `FUN_0042A5A0`, `FUN_0042C480`,
`FUN_004ACD10`, `FUN_004B7480`, `FUN_004B7520`, `FUN_004B7660`,
`FUN_004B7870`, `FUN_004B7CA0`, `FUN_004B7E80`, `FUN_004B8000`,
`FUN_004B8100`, `FUN_004B8940`, `FUN_004B8AB0`, `FUN_004F8ED0`,
`FUN_00516BE0`, `FUN_00563390`, `FUN_00563FD0`, and `FUN_005643C0`.
`local/source/compare-report.tsv` classifies every one of these 18 EN/CH
pairs as `identical`.

In each table-consuming loop, the map index is formed from the first dword
(`*src` or `*src2`) and the pointer advances by two dwords for the next cell;
the row pointer advances by `0xC` bytes. No indexed body dereferences the
paired value at `src + 1`/`src2 + 1` after it has been established from the
`DAT_0081FF18` base. The three apparent `src[1]` hits are not exceptions:
`FUN_004F8ED0` and `FUN_0042C480` read `src2[1]` from an object-specific
geometry record returned by vtable `+0x28`, while `FUN_005643C0` reads
`src[1]` from shape data returned by `FUN_00567610`; neither pointer aliases
the paired footprint table. `FUN_00563FD0` uses `p == &DAT_0081FF18` only as
an edge-of-row identity test and still consumes the first dword for map writes.

Therefore the second-dword sequence `[0…5], [8…13], …, [40…45]` has no
recoverable semantic consumer in the complete indexed corpus. This is a
confirmed negative for treating that column as a coordinate, occupancy bit,
rotation, or service projection, and it must not be mapped into Native. Raw PE
immediate aliases or function interiors not emitted as indexed split rows are
outside this census and remain **unknown**; this boundary is recorded instead
of being silently generalized. No simulation or UI behavior changes follow
from this finding, and Qin remains fail-closed at the unresolved map/object
projection boundary.

**Evidence class:** **confirmed negative (bounded)** for the indexed EN/CH
function bodies, pointer strides, and non-aliasing `src[1]` cases;
**unknown** for unindexed/raw-PE aliases and the second column's original
purpose.

### `vtable +0x268` is a polymorphic slot, not a global occupancy predicate (confirmed boundary, 2026-09-03)

The indexed call census also narrows the meaning of the callback used by the
occupancy path. In `FUN_004153B0 @ 0x4153B0` and `FUN_004146D0 @ 0x4146D0`,
the result of `(**(code **)(*object + 0x268))()` is consumed as a boolean:
the former ORs `0x04` into `DAT_00F37DA0[object+0x10]`, and the latter clears
that bit after the same callback reports nonzero. This is the only indexed
writer chain that connects the slot to the transient occupancy byte.

The same virtual slot is not semantically uniform elsewhere. The service and
object-selection helpers `FUN_004B29C0`, `FUN_004B2D00`, `FUN_004ED840`,
`FUN_00511080`, `FUN_00511B10`, and `FUN_005F0120` use its return as an
object pointer; `FUN_004B38C0` immediately reads `return + 0xB4`. The
resource/type helpers `FUN_0051FA20`, `FUN_0051FBA0`, `FUN_005F11F0`,
`FUN_005F1510`, and `FUN_005F1540` compare or store the return as a numeric
ID, while `FUN_0058C420` compares it against a per-object threshold. All
listed EN/CH function pairs are `identical` in
`local/source/compare-report.tsv`.

Therefore `+0x268` is a class-specific virtual contract whose occupancy use
is bounded to the two map-bit call sites above; it cannot be projected into a
single Native `isOccupied` or provider-state field without recovering the
concrete vtable implementations for each object class. The provider runtime
class records cataloged in `residential-service-roamer-lifecycle.md` do not
close those slot implementations. This keeps Qin service projection
fail-closed and prevents reusing the pointer/ID interpretations as map-grid
occupancy evidence.

**Evidence class:** **confirmed** for the call-site result types, the sole
indexed `DAT_00F37DA0` writer/clearer chain, and EN/CH identity;
**unknown** for concrete per-class vtable targets and the complete occupancy
lifecycle.

Until those mappings are recovered, Qin3 desirability remains fail-closed and
the Manhattan helper must not be presented as confirmed original behavior.

### Monthly appeal-to-population arithmetic (`FUN_005180E0`, confirmed 2026-09-01)

The monthly consumer behind the migration/population path is now represented
as a pure arithmetic primitive. `FUN_005180E0 @ 0x5180E0` is called by
`FUN_004AE900 @ 0x4AE900`; both entries are marked `identical` for the
canonical EN/CH pair in `local/source/compare-report.tsv`. The complete split
body is `local/source/split-merged/code/0x050000/FUN_005180e0.c`.

For each active object it reads the signed appeal byte from vtable `+0x1F8`,
subtracts model column `0`, and applies the exact strict intervals:

```text
delta > 50:       scale*10 + 25
41 <= delta <= 50: scale*5 + 10, then ×2
31 <= delta <= 40: scale*10 + 15, then ×2
21 <= delta <= 30: scale*5 + 5, then ×2
11 <= delta <= 20: scale*10 + 5, then ×2
delta <= 10:      scale*5, then ×2
```

When the score is positive and `FUN_005A8420(9)` succeeds, the source adds
`20`. It then multiplies by the signed resident word, model column `0x12`,
and `10`; positive fixed-point results are converted with
`(raw + 5000) / 10000`, while non-positive values contribute zero.
`OriginalAppealPopulationAccumulator.contribution` in
`Sources/EmperorCore/HousingEvolution.swift` preserves these boundaries,
signed input, blessing, overflow rejection, and rounding order. Focused tests
cover lower, strict-boundary, upper, blessing, and negative-input cases.

This closes the per-object arithmetic only. The authored meanings of model
columns `0` and `0x12` are now confirmed by the `EmperorBuildingModels.txt`
header and the `ALL HOUSES` loader: column `0` is the initial desirability
value and column `0x12` is the tax-rate multiplier. `FUN_00590A70` initializes
the global scale `DAT_0130F96C` to **9** during both `FUN_005D1400` model setup
and `FUN_0042E6A0` city-start setup; this value is represented by
`OriginalAppealPopulationAccumulator.defaultAppealScale`. The Qin residential
`HouseBldg` `+0x204` class split is closed below; its Native row projection,
appeal anchors, occupancy state, and aggregate ledger slots remain **unknown**.
The helper is therefore not
wired into `CitySimulation`, migration popularity, or Qin housing evolution;
the prior distance-only desirability path remains fail-closed.

**Evidence class:** **confirmed** for the caller/callee chain, interval
boundaries, score arithmetic, selector-9 bonus, signed resident multiplication,
fixed-point rounding, authored model-column names, scale initialization, and
EN/CH identity; **unknown** for the object/row projection, appeal anchors,
occupancy state, aggregate ledger integration, and live Native mapping.

### Appeal population scale initialization (`FUN_00590A70`, confirmed 2026-09-02)

`FUN_00590A70 @ 0x590A70` clears the popularity/appeal working area and writes
`DAT_0130F96C = 9`. The canonical EN/CH split rows are `identical` in
`local/source/compare-report.tsv`. The function is called from
`FUN_005D1400 @ 0x5D1400` during normal model initialization and from
`FUN_0042E6A0 @ 0x42E6A0` during city-start setup, before the shared scheduler
and object initialization chain. This establishes the appeal-score scale as a
fixed original input, rather than an unresolved runtime tuning value.

The same loader source proves the field labels consumed by the arithmetic:
`ERR_No_Building_Model_file @ 0x5D1830` and `FUN_005D16D0 @ 0x5D16D0` copy the
24-value `ALL HOUSES` rows into `DAT_00A63BFC`, and
`FUN_0044CC80 @ 0x44CC80` indexes that table by house-level row and field.
`GameData/Model/EmperorBuildingModels.txt` names field `0` “Initial
desirability value” and field `18 (0x12)` “tax rate multiplier.” Native keeps
these as explicit helper inputs and does not infer the unresolved object
registry/appeal-buffer projection from the labels alone.

**Evidence class:** **confirmed** for the initialization value `9`, both
callers, EN/CH identity, the 24-column table loader, and authored field names;
**unknown** for the live row/object projection, appeal anchors/occupancy, and
aggregate ledger consumers.

### HouseBldg appeal population class split (`FUN_00518D90`, confirmed 2026-09-02)

The canonical `HouseBldg` vtable `0x7ABA38` maps slot `+0x204` to the direct
PE body `FUN_00518D90 @ 0x518D90`. The 11-byte EN and CH slices are identical
(SHA-256 `5fa9ca638c1cd084d840b34ed6ebe6f7889a58264da20b6c02306aeec13d01f3`). The body performs
a signed 16-bit comparison of `house+0x14` against `11` and returns a Boolean:
false below `11`, true at `11` and above. `FUN_005180E0` uses this result only
to choose its lower/upper population and tax-delta accumulator buckets.
`OriginalHouseAppealPopulationClass` records the exact boundary as a pure
helper with regression coverage.

This closes the residential class split, not the ledger itself. Generic
non-`HouseBldg` vtable implementations, the source of `house+0x14`, appeal
anchors/occupancy, and the final aggregate-to-Native projection remain
unknown; no Qin appeal or migration path is enabled.

**Evidence class:** **confirmed** for the `0x7ABA38 + 0x204 → 0x518D90`
mapping, signed comparison, threshold `11`, accumulator use, and EN/CH byte
identity; **unknown** for non-residential classes and downstream ledger
projection.

### Appeal tax-ledger aggregation (`FUN_00517BC0`, confirmed 2026-09-02)

The aggregate arithmetic after the monthly object pass is now closed from
the split EN/CH bodies at `local/source/split-merged/code/0x050000/FUN_00517bc0.c`.
`local/source/compare-report.tsv` marks `FUN_00517BC0 @ 0x517BC0` as
`identical` in both executables; direct caller `FUN_004F1A70 @ 0x4F1A70` invokes
it before the ledger-facing formatting path. The function clears the lower/upper buckets,
walks the active-object vector returned by `FUN_004F8210` (only records with
byte `+0x04 == 1`), calls each object's vtable `+0x204` class predicate, and
reads `FUN_0044CC80((short)(object+0x16), 0x12)`. When object byte `+0x52` is
non-zero it adds signed resident word `(short)object[8] × column-0x12` to
`DAT_01312258` (lower class) or `DAT_01312260` (upper class).

It then applies the exact integer helper `FUN_00408B80(value, scale) =
(value × scale) / 100` to each bucket, where `DAT_0130F96C` is the recovered
scale `9`. The month multiplier is `1` when `DAT_00C82EEC == 0`, otherwise
`0xD - DAT_00C82EEC`. Finally it writes
`DAT_01312250 = DAT_01312244 + DAT_01312240` and
`DAT_01312530 = monthMultiplier × (lowerScaled + upperScaled) +
DAT_01312244 + DAT_01312240`. `FUN_004098F0` formats `DAT_01312530` for the
ledger-facing text path. `OriginalAppealTaxLedger.project` records this pure
arithmetic with explicit inputs and overflow rejection; it is not wired into
`CitySimulation`.

This closes the raw bucket, percentage, month, and output-register arithmetic.
The meanings and producers of object `+0x52`, resident word `+0x20`,
`DAT_01312240/44`, the object-vector projection, and the final Native ledger
mapping remain **unknown**. Qin desirability, migration, and tax settlement
therefore remain fail-closed.

**Evidence class:** **confirmed** for the EN/CH-identical body, active-vector
walk, class split, authored column-0x12 weighting, integer percentage helper,
month multiplier, output assignments, and `FUN_004098F0` consumer; **unknown**
for the unresolved object/ledger inputs and Native projection.

### Appeal tax per-house fixed-point delta (`FUN_005180E0`, 2026-09-02)

The tax-covered branch of `FUN_005180E0 @ 0x5180E0` has a separate confirmed
fixed-point update that feeds the two aggregate delta slots. After converting
the current contribution with `__ftol`, the body reads the previous
`cHouseInfo + 0x40`, adds the converted increment back into that field, and
computes the integer change as:

```text
delta = ((updatedFixedPoint + 5000) / 10000)
      - ((previousFixedPoint + 5000) / 10000)
```

The delta is added to `DAT_01312240` for the lower `+0x204` class and to
`DAT_01312244` for the upper class. Endpoint rounding is independent and
precedes the aggregate ledger's month multiplier in `FUN_00517BC0`. EN/CH
split bodies are `identical` in `local/source/compare-report.tsv`. Native
records this exact field-level operation as
`OriginalAppealTaxLedger.projectTaxDelta`, with explicit inputs and checked
overflow; it is not wired into simulation because the producer of the
`__ftol` increment, the field's semantic label, and the object-to-Native
projection remain unresolved. The field's constructor/reset/read/save
lifecycle is bounded below.

**Evidence class:** **confirmed** for the update order, signed endpoint
rounding, aggregate destination split, and EN/CH identity; **unknown** for the
increment producer, `cHouseInfo + 0x40` semantic label, and live Native ledger
mapping.

### Appeal tax field-40 lifecycle and save boundary (`FUN_00517950` / `0x517410`, 2026-09-02)

The raw field used by the delta is now bounded at its lifecycle edges. The
`HouseBldg` constructor's `cHouseInfo` initializer `FUN_00517190 @ 0x517190`
writes zero at `+0x40`. The month-boundary reset `FUN_00517950 @ 0x517950`,
called by `FUN_004AE910 @ 0x4AE910` after publishing the previous ledger,
walks the active house vector and writes a dword zero to the same field through
the `+0x1E4` house-info getter. The direct reader `FUN_004AFFB0 @ 0x4AFFB0`
returns `(field40 + 5000) / 10000`; its callers `FUN_0058AAB0` and
`FUN_005A5390` use that rounded value for the original inspector/detail
presentation paths.

The cHouseInfo vtable `+8` serializer at `0x517410` (invoked by
`FUN_00518910`) serializes four bytes beginning at `+0x40`, so the accumulator
is save-backed rather than transient. The EN and CH `0x517410…0x5177A4`
slices are byte-identical (917 bytes, SHA-256
`563141debd2315082ad527b9a4a279b7c199902a1e27ef3a90fdc1b6b858aa6f`); the
short function is not emitted as a standalone split-corpus row. Native exposes
the reader arithmetic as `OriginalAppealTaxLedger.roundedFixedPointUnits` and
keeps the field-level state out of live simulation until its increment producer
and object projection are recovered.

**Evidence class:** **confirmed** for constructor/reset/read/save coverage and
EN/CH identity; **unknown** for the field's player-facing semantic name, the
`__ftol` increment producer, and Native object/ledger projection.

### `FUN_004B7480` is an editor-only appeal-grid mask writer (confirmed negative, 2026-09-02)

The apparent generic appeal-grid writer `FUN_004B7480 @ 0x4B7480` has exactly
one caller in the merged static corpus: `FUN_004B5290 @ 0x4B5290`. The caller
is reached only from the map-edit input handler `FUN_004051F0 @ 0x4051F0`
after the selected-tool state has been checked. In its `DAT_0088EBDC == 0x97`
branch it validates a 5×5 region, invokes the edit-side `FUN_004B72B0`, and
then calls `FUN_004B7480(minX, minY, 5, 5, FUN_004B9C90(DAT_0088EB68))`.
`FUN_004B9C90` returns only the four mode masks `8`, `16`, `32`, or `64`.

`FUN_004B7480` itself ORs that caller-supplied mask into the serialized
`DAT_00F37DA0` word for each footprint cell, after a bounds check. The
canonical English and Chinese call sites are identical in the available
corpus; no simulation tick, object-vector walk, provider vtable, house-info
writer, or monthly appeal pass reaches this helper. The tool/mode labels for
`DAT_0088EB68` and the gameplay meaning of masks `8/16/32/64` remain
unresolved, so they must not be mapped to desirability, service coverage, or
provider state.

This is a confirmed negative for using `FUN_004B7480` as the missing Qin
appeal-occupancy producer. It only closes an editor-side write path; the
runtime `+0x268`/occupancy lifecycle and the object-to-Native appeal
projection remain unknown, and Qin3 stays fail-closed.

**Evidence class:** **confirmed** for the sole caller, input-handler chain,
5×5 dimensions, mask-return table, bounds-checked OR writes, and absence of a
simulation/provider caller; **unknown** for editor mode labels and mask
semantics.
