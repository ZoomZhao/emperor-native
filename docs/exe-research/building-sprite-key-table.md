# Building primary-sprite key table (`DAT_008235a0`)

Read-only static recovery from the hash-identified `Emperor[EN].exe`
(`8a6d2df1…6753`, local `Exe/ghidra/input/EmperorEN.exe`).

## 1. Recovered table (confirmed)

`FUN_004C2AC0` reads each building's primary map-sprite key at
`DAT_008235a0 + buildingID × 0x18`; the footprint dword sits 8 bytes before
(`DAT_00823598 + n`). Direct PE reads of `.data` (VA base 0x400000, `.data`
raw 0x414000) give, for the farms and nearby references:

| building | model name | key | f1 (footprint dword) |
| ---: | --- | --- | ---: |
| 31 | Fishing Quay | 0x438 | 2 |
| 33 | Hunter's Tent | 0x437 | 2 |
| 36 | Stoneworks | 0x43F | 2 |
| 38 | Logging Shed | 0x43E | 2 |
| 53 | Mill | 0x423 | 5 |
| 54 | Warehouse | 0x424 | 3 |
| 58 | Trading Station | 0x425 | 4 |
| 59 | Common Market | 0x0 (composite) | 1 |
| 66 | Food Shop | 0x414 | 2 |
| 72 | Well | 0x482 | 2 |
| 124 | Inspector's Tower | 0x486 | 2 |
| 192 | Hemp Farm | 0x4AD | 2 |
| 193 | Farmhouse | 0x43A | 3 |
| 194 | Hemp Field | 0x431 | 1 |
| 195 | Wheat Field | 0x42E | 1 |
| 196 | Millet Field | 0x42C | 1 |
| 197 | Rice Paddy | 0x42D | 1 |
| 198 | Cabbage Field | 0x42F | 1 |
| 199 | Soybean Field | 0x430 | 1 |

Footprint dwords match the native footprint catalog (mill 5×5, warehouse 3×3,
plots 1×1); building 193 farmhouse is 3×3 per the table and the native
catalog now records both farmstead producer footprints.

## 2. Key → image resolution (confirmed)

`FUN_00408170` resolves a key:
`group = key & 0x1FF` (sign-extended), `record = FUN_004081D0(group - 1)`,
`image = *(record + 4) + (key >> 9) × 0x4000`. Disassembly (raw 0x8170) shows
the low-9-bit mask is used directly (no `-1` before the group), and the record
table lives in a runtime object (`lea ecx,[ecx+archive×58956+0x1000]`).
In practice the resolved image equals the **first image of the key's group in
the archive named by `key >> 9`** (China_General for keys `0x4xx` = archive 2,
China_Terrain for `0x60x` = archive 3): 41 of 53 native catalog entries match,
and every mismatch's native value appears at another building's correct slot.
The resolution is therefore `confirmed` as "group first image".

## 3. Native catalog corrections (from this table)

The following native sprite assignments were wrong (each old value belonged to
another building; all corrected and covered by tests):

| building | old | corrected (exe) | group |
| ---: | ---: | ---: | ---: |
| 33 Hunter's Tent | 825 | **708** | 55 |
| 42 Bronzeware Maker | 2750 | **2788** | 71 |
| 43 Kiln | 2788 | **2810** | 73 |
| 124 Inspector's Tower | 1704 | **1618** | 134 |
| 127 Watchtower | 1618 | **1680** | 136 |
| 192 Hemp Farm | — | **825** | 173 |
| 193 Farmhouse | — | **793** | 58 |
| 195 Wheat Field | 2410 | **2422** | 46 |
| 196 Millet Field | 2422 | **2410** | 44 |
| 198 Cabbage Field | 2446 | **2434** | 47 |
| 199 Soybean Field | 2434 | **2446** | 48 |
| 237 Tea Curing Shed | 812 | **840** | 59 |
| 238 Lacquer Refinery | 840 | **812** | 61 |

Footprint dwords (record −8) are 2×2 for #192 and 3×3 for #193, matching the
newly added native footprints; the farmstead producers are now placeable.

## 4. Terrain families (unlocks the mountain fix)

Keys `0x60x` (archive 3 = China_Terrain) resolve to: rock `0x606` → group 6
(#458…#471, 14 frames), copper rock `0x607` → group 7 (#472…#485, 14
frames), and the second ore rock `0x608` → group 8 (#486…#499, 14 frames);
each rock family is partitioned into 8 single-cell, 4 2×2, and 2 3×3 frames.
Bare `0x603` → group 3 (#247, 59 frames); grass
`0x602/0x604` → groups 2/4 (#202/#336); water `0x605` → group 5 (#386);
sand `0x60e` → group 14 (#1138); water variants `0x61a…0x61c` → groups 26–28.
`CityCanvasTerrainRenderer` now draws the rock family for non-elevation rock
cells (terrain 0x2) using the map variation byte, mirroring the original
flag-based rebuild (`FUN_0053EC90`).

## 5. Residential wall/gate primary-table entries (confirmed; connected draw is separate)

The same direct PE table read covers the residential barrier model IDs used by
the Qin Xiangjun archive.  For IDs 89/90/91 (`0x59/0x5A/0x5B`), 104/105/106
(`0x68/0x69/0x6A`), 231 (`0xE7`), and 232 (`0xE8`), the entries at
`DAT_008235a0 + id × 0x18` all contain key `0x451`; the footprint dword at
`DAT_00823598 + id × 0x18` is `1`, and the image offset at
`DAT_008235a4 + id × 0x18` is `0x0F`.

| building IDs | authored family | key | image offset | footprint dword |
| --- | --- | ---: | ---: | ---: |
| 89, 90, 91 | Residential Wall 4/3/2 | 0x451 | 0x0F | 1 |
| 104, 105, 106 | Residential Gate 4/3/2 | 0x451 | 0x0F | 1 |
| 231 | Residential Wall 1 | 0x451 | 0x0F | 1 |
| 232 | Residential Gate 1 | 0x451 | 0x0F | 1 |

`FUN_004C2AC0 @ 0x4C2AC0` resolves the model-table key through `FUN_00408170`,
then adds that per-model image offset before calling `FUN_004B72B0`; this is the
generic `Building` primary-sprite path. It must not be conflated with the
connected residential-barrier draw. The wall/gate constructors install
vtable `0x7AAAB8` / `0x7AAFB0` (shared base `0x7AAD34`), whose `+0x270` entry is
`FUN_004153B0 @ 0x4153B0` (EN/CH identical). That callback computes cardinal
neighbor masks and selects a separate key family via `FUN_004152D0`:

| model IDs | specialized key | resolved group / first image |
| --- | ---: | ---: |
| 0x59 / 0x68 (89 / 104) | 0x427 | logical 39 / #421 |
| 0x5A / 0x69 (90 / 105) | 0x428 | logical 40 / #404 |
| 0x5B / 0x6A (91 / 106) | 0x429 | logical 41 / #387 |
| 0xE7 / 0xE8 (231 / 232) | 0x4B5 | logical 181 / #370 |

For wall models the callback adds frame offsets `0x0D` or `0x0E` (with a
map-rotation-dependent swap); gate models use the recovered neighbor-mask table
at `DAT_00815D40` and may add a 0-or-2 variation. The exact mask-to-frame table
values are now recovered directly from the canonical PE data (the EN and CH
tables are byte-identical). The table is at VA `0x00815D40` (file offset
`0x00415D40` in both `8a6d2df1…6753` and `dbdeca1e…15a`); each row is six
DWORDs: the 4-bit mask followed by five stored offsets. The callback uses the
first four offsets for raw map rotations `0/2/4/6` (`DAT_0101D0D0 >> 1`);
the fifth stored value is not read by this path.

| neighbor mask | stored offsets (active rotation bands 0…3, then unread slot) |
| ---: | --- |
| 0 | 0, 2, 0, 2, 13 |
| 1 | 2, 0, 2, 0, 14 |
| 2 | 0, 2, 0, 2, 13 |
| 3 | 7, 6, 5, 4, 14 |
| 4 | 2, 0, 2, 0, 14 |
| 5 | 2, 0, 2, 0, 14 |
| 6 | 4, 7, 6, 5, 14 |
| 7 | 9, 8, 11, 10, 14 |
| 8 | 0, 2, 0, 2, 13 |
| 9 | 6, 5, 4, 7, 14 |
| 10 | 0, 2, 0, 2, 13 |
| 11 | 8, 11, 10, 9, 13 |
| 12 | 5, 4, 7, 6, 14 |
| 13 | 11, 10, 9, 8, 14 |
| 14 | 10, 9, 8, 11, 13 |
| 15 | 12, 12, 12, 12, 14 |

The post-load invocation that applies these callbacks to serialized Xiangjun
objects is still not present in the generated corpus. Native therefore applies
the recovered resolver only to read-only authored barrier records for map
presentation; it does not register them as live simulation objects.

`OriginalBuildingSpriteCatalog.residentialBarrierSpriteFamily(forBuildingID:)`
records the confirmed family keys and first images; the adjacent
`residentialBarrierConnectedFrameOffset` helper applies the recovered table
without changing the generic primary-table entry.

`FUN_004157D0 @ 0x4157D0` and `FUN_004158D0 @ 0x4158D0` independently show that
residential barriers are painted one cell at a time. Native now renders these
authored records with the connected resolver. Native currently supplies the
classic-canvas default map rotation `0` (an **inferred presentation default**;
dynamic runtime rotation is not exposed by this renderer), the four-bit
cardinal mask from neighboring archived records, and terrain `0x40` road bits
for the callback's opaque mask. Gate rows that request
`FUN_0041FAA0(2)` use sequence parity as a deterministic 0/1 replacement; it
preserves the source distribution without claiming to recover the original
random seed. The confirmed one-cell footprint and generic #936 primary-table
entry remain separate from this connected draw. The serialized
`cResWall`/`cResGate` post-load provider registration, collision side effects,
orientation state, and save/replay linkage remain unknown (see
`xiangjun-residential-barrier-archive.md`).
