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
plots 1×1); building 193 farmhouse is 3×3 per the table (native catalog has no
192/193 entry — this is new evidence for the missing farmstead footprint).

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
