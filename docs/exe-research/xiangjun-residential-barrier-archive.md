# Xiangjun residential wall/gate archive (2026-09-01)

## Evidence scope

This note records a read-only decode of the authored `GameData/Cities/Xiangjun.map`
format-v5 object archive. The executable references are from the canonical
English build `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
and the Chinese cross-check build
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
No original runtime was launched.

## Recovered boundary

`FUN_0052E7C0 @ 0x52E7C0` writes the variable Building archive after the
fixed map layers. `FUN_0042D790 @ 0x42D790` dispatches each serialized object
through the MFC class table, and the wall/gate vtables use the inherited
`+0x08` serializer (`FUN_00415AE0 @ 0x415AE0` for `cResWall` and
`FUN_00416490 @ 0x416490` for `cResGate`). Both variants call the same common
Building serializer (`FUN_0051CE00 → FUN_0041FC10`).

The two specialized runs have a stable record cadence in both PEs and the
authored Xiangjun archive:

* the first object begins at class-name end + 16, where the common model ID is
  read;
* each following object is 313 bytes later and carries the MFC token
  `[01 00 03 80]` twenty bytes before that model-ID field;
* the common serializer's origin fields are eight and six bytes before the
  model ID, and its map-cell word is four bytes before it.
* for Xiangjun's selected 140×140 runtime descriptor, every serialized
  map-cell word equals `10076 + y×0xE4 + x`, the exact `DAT_0101D0C8` base and
  row-stride expression consumed by the object-grid writer.
* for schema 3, the common serializer emits the `+0xB4` DWORD 143 bytes
  after the model ID. The authored wall/gate records carry the contiguous
  values `1…43` at that position.
* the common serializer's `+0x07` byte is eleven bytes before the model ID in
  this stream. `FUN_0042A5A0 @ 0x42A5A0` consumes that byte as the square side
  count for object-grid writes; every Xiangjun wall/gate record stores `1`.

The parser in `ResidentialBarrierArchiveCatalog.swift` exposes these
confirmed fields plus the raw word immediately after the model ID. It does not
register objects, alter collision grids, or infer provider/occupancy behavior.
Its search and fixed-stride loop stop at the recovered archive end
(`decoded.count - EmperorMap.gridCellCount`), because the trailing fixed grid is
not an MFC object stream and cannot supply additional barrier records.

## Xiangjun result

`cResWall` contributes 27 records, all model/building ID 90, with origins
`(74,68)` through `(92,80)`. `cResGate` contributes 16 records: one model 105
record at `(93,80)`, followed by 15 model 90 records ending at `(96,65)`.
Their serialized `+0xB4` values are exactly `1…27` for `cResWall` followed by
`28…43` for `cResGate`. The load callback passes this field to
`FUN_00526830`, whose constructor stores it at auxiliary `+0x14`; the refresh
chain `FUN_00418D90 → FUN_00418E80` then calls `FUN_0047F1B0(auxiliary +
0x14)` and dereferences the corresponding object-vector entry. The
object-vector-slot meaning is therefore confirmed for this specialized
barrier lifecycle. It is not a service-provider slot and does not authorize
replaying the records into Native's live registry.
Their common object `+0x04` load-eligibility byte is `3` for all 43 records,
so the original `FUN_0042D790` record loop admits both class runs to vtable
`+0xC0` (`FUN_0051CB80`); the four Qin generic `Building` runs instead carry
zero and are skipped at that callback boundary.
Their serialized `+0x07` footprint-side byte is `1` for all 43 records. This
confirms that the authored barrier objects enter the original square-grid
writer as one-cell writes; it does not recover the object-vector allocation,
orientation, or post-load collision registration.
Their serialized map-cell words also match the selected runtime descriptor's
base/stride formula for every record. This closes the coordinate-to-linear-cell
projection for the authored barrier run, while live registry ownership and
post-load collision writes remain unresolved.
The post-model raw word is not treated as state; it changes across the run
(`0x9F00` on the first record and `0xC900` on the last), so its producer and
meaning remain unknown.

These records are now asserted by
`testXiangjunResidentialBarrierArchiveRecordsUseSpecializedRuns`. This closes
the existence, ordering, model IDs, and coordinate boundary for the authored
residential barrier objects. `CityCanvas` uses the records as a read-only
presentation layer: it builds the four-bit cardinal mask from this same set,
reads adjacent terrain `0x40` road bits for the callback's opaque mask, and
resolves the connected `China_General` frame at Native's inferred classic-
canvas default map rotation `0` (dynamic runtime rotation is not exposed by
the renderer).
Gate rows that require the original two-way variation use sequence parity as a
deterministic replacement, preserving the recovered 0/1 distribution. This
does **not** prove that Native may inject the records into the live Qin
session: original post-load object registration, collision side effects,
orientation/footprint interpretation, and save/replay linkage remain unknown.

The callback/slot boundary is also recorded in
`OriginalResidentialBarrierLoadLifecycleCatalog`; its auxiliary is retained
as research metadata only. `FUN_0051CC10` refreshes an existing auxiliary
through `FUN_00418D90` and does not establish collision, provider, or house
settlement state.

The map post-load walk also invokes the specialized vtable `+0x1C8` entry
(`0x415AD0`, recovered from the canonical EN/CH vtable/body bytes), which
calls `+0x270 → FUN_004153B0(0, 0)`. That callback recomputes the four
neighbor slots and writes the connected barrier state through
`FUN_004B72B0`; these are confirmed ordering/target facts, while the Native
collision-grid projection and runtime orientation remain unresolved.

For the only model IDs present in this archive, the callback branch is now
fully pinned at the writer boundary: `FUN_00415740(0x5A)` admits model `90`
and selects overlay `0x48` (wall), while `FUN_00415740(0x69)` is false and
`FUN_00415770(0x69)` admits model `105`, selecting overlay `0x08` (gate).
Both vtables' `+0x268` completion target is `FUN_004E1C40 @ 0x4E1C40`, whose
EN/CH bodies return `1`; `FUN_004153B0` consequently ORs bit `0x04` into
`DAT_00F37DA0[object+0x10]`, where serialized `+0x10` is the map-cell index
(distinct from the `+0xB4` object-vector slot). This establishes the exact
map-grid write inputs and raw state-bit transition for Xiangjun, but not the
semantic name of that bit or permission to mirror it into Native's
route/collision state.
