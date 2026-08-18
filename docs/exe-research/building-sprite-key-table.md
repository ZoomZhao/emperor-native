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

## 2. Key → image resolution (blocked)

`FUN_00408170` resolves a key: `group = sign-extended(key & 0x1FF)`,
`record = FUN_004081D0(group - 1)`, `image = *(record + 4) + (key >> 9) × 0x4000`.
`FUN_004081D0` reads the record table from a runtime object whose `+4` pointer
and `+0xCC38` count live in the zero-filled tail of `.data` (object appears to
be `0x0130F960`, populated at load). The group→base records are therefore
**runtime-initialized, not statically present in the file**; the naive
"group first image" shortcut holds for some rows (food shop 66 → group 19 →
#611; soybean 199 → group 47 → #2434) but fails for others (mill 53 → group 34
→ #1066 ≠ #647; millet 196 → group 43 → #646), so it cannot be used as a
general rule.

## 3. Consequence for the farmstead sprite

The crop-farm producer (192/193) map sprite and the mountain-terrain flag
families both depend on this runtime group table. Native keeps the fail-closed
behavior: no farmstead sprite is claimed until the group table values are
recovered from a legal runtime observation (or the load path that fills
`0x0130F960` is traced).
