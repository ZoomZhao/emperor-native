# Cursor pass: commerce, defense and monument Bbuttons

This pass was performed against the checked-in `GameData` exports, the
hash-identified local installation, and frames from the local playthroughs.
It deliberately does **not** change Swift catalogs. The original executable's
construction-button writer is still not recovered, so an image association is
not promoted to `confirmed` from sheet order alone.

## Commerce: a new direct video observation

At approximately `00:08:20` in `local/BV1W4411971F_p2.mp4` (1920×1080 frame),
the right panel title is `商业`. Template matching against the native-size
`54×53` Bbutton exports found these visible grid families:

| Panel slot | Observed family | Evidence | Semantic result |
| --- | ---: | --- | --- |
| row 1, col 1 | `#1533–#1535` | `videoObserved` | `unknown` |
| row 1, col 2 | `#1536–#1538` | `videoObserved` | `unknown` |
| row 1, col 3 | `#1539–#1541` | `videoObserved` | `unknown` |
| row 2, col 1 | `#1542–#1544` | `videoObserved` | `unknown` |

The four observations are stronger than contact-sheet resemblance because the
same frame family is present at a fixed panel slot in an original-game
capture. They still do not identify a `buildingId`: mission filtering can hide
other commerce rows, and hover/selected state shifts the matched id within a
three-frame family.

`OriginalBuildingSpriteCatalog.shopImageIDByBuildingID` supplies the authored
world-image semantics for shop IDs 64–70 (`#627, #617, #611, #619, #621,
#623, #625`). No checked-in data joins those world image IDs to the Bbutton
families. Therefore the four visible families must remain `videoObserved` /
`unknown`; assigning them to bronzeware, lacquerware, silk or tea would be a
guess.

### Source-first correction: shops are market sub-buildings

Two independent authored catalogs explain the apparent category conflict:

- `Sources/EmperorCore/MarketSimulation.swift` calls IDs `[66, 67, 65, 70,
  69, 68, 64]` `shopBuildingIDs`, stores them in `MarketSquare.shopBuildingIDs`,
  and limits them by the common/grand-market bay capacity.
- `Sources/EmperorCore/CampaignBuildingPermissions.swift` has no permission
  menu entry for IDs 64–70. Its menu entry 16 is `Trade Buildings` and maps
  only IDs 56/58. `BuildingSpriteCatalog.supportedPlacedBuildingIDs` likewise
  excludes 64–70 while rendering them as occupied market bays.

This is `confirmed` authored-data evidence that IDs 64–70 are market
sub-buildings, not seven independent player placement buttons. The four
`商业` families observed in the video therefore should not be forced onto
64/68/69/70; they are more likely the visible top-level trade/industry tools
(the former native sheet-order associations for IDs 53/47/65/67 have now been
withdrawn). The original market panel still needs a runtime capture to tell
whether a shop bay is selected via a separate market-management control.

### Cross-check against the previous inferred catalog

The previous sheet-order catalog placed the middle frame of these families at
`#1534 → building 53 (磨坊)`, `#1537 → building 47 (织布坊)`,
`#1540 → building 65 (陶器铺)`, and `#1543 → building 67 (麻布铺)`.
The direct runtime capture contradicts those assignments: all three families
are rendered together on the original 商业 rail. Those four speculative rows
were removed from `OriginalConstructionButtonSpriteCatalog`; the native UI
now falls back to the authored world-thumbnail assets until a tooltip or live
slot record supplies a building ID. This is an implementation correction, not
a promotion to a new semantic mapping.

### PE reverse-reference pass

The EN and CH executables were byte-identical for the relevant code/data
regions. Searching raw image IDs as little-endian `u16`, `u32`, `push imm32`,
and stack-template constants produced no contiguous
`#1533/#1536/#1539/#1542/#1545/#1548` construction list. The notable hits are
negative evidence:

| Address | Immediate(s) | Classification |
| ---: | --- | --- |
| `0x53FA59` | `1549, 1546, 1545, 1561` | `confirmed` world/tile renderer: reads per-tile state, computes map coordinates, calls `0x408170` then a terrain blitter |
| `0x4B39AE`, `0x4B4036`, `0x4B4299` | `1539` | `confirmed` world/terrain sprite paths; each passes the id to `0x408170` while indexing tile arrays |
| `0x4B3CA8`–`0x4B3CC4` | `1542, 1543, 1544` | `confirmed` world/terrain variant selection, followed by `0x408170`, not a panel widget |
| `0x4A5C28`–`0x4A5C46`, `0x4A6D0E`–`0x4A6DA4` | late outputs `#1580+`, `#1598+`, `#1604+` | `confirmed` `0x4A5960` switch stubs; no early commerce-family output and no building-ID input |

The same search found no code site that loads a shop/building ID and an early
`New_Bbuttons` family into a panel rectangle. These numeric collisions are
why a raw `find(1539)` or contact-sheet resemblance must not be promoted to a
button mapping.

## Defense

The contact sheet confirms that `#1608–#1622` are five consecutive three-state
military-looking families. Existing native rows already use:

| Building ID | `BUILD_*` name (static PE table) | Current family | Evidence |
| ---: | --- | ---: | --- |
| 220 | `BUILD_XBOW_FORT` | `#1608` | inferred |
| 221 | `BUILD_INFANTRY_FORT` | `#1611` | inferred |
| 224 | `BUILD_CAVALRY_FORT` | `#1614` | inferred |
| 225 | `BUILD_CHARIOT_FORT` | `#1617` | inferred |
| 223 | `BUILD_SIEGE_FORT` | `#1620` | inferred |

IDs 222 (`BUILD_MOUNTEDS`) and 226 (`BUILD_WEAPONSMITH`) have no native
construction-tool row and no additional military family separated from the
five families above. The contact sheet alone cannot establish that either is
constructible in the city panel. Keep both `unknown`.

The authored model table and `Mon_Great_Wall_*_subs.txt` describe walls as
multi-part monument sub-buildings (`SB_GREAT_WALL`, `SB_GREAT_WALL_GATE`, and
`SB_GREAT_WALL_TOWER`). The static executable pass found a dedicated triple
writer at `0x4B0010` that emits world/monument sprite IDs, not a normal
`54×53` construction Bbutton. Consequently IDs 129 (`BUILD_WALL`), 130
(`BUILD_GATEHOUSE`), and 131 (`BUILD_TOWER`) remain `unknown` rather than
being assigned one of the fort families.

## Monuments

The static PE name table confirms these IDs and the checked-in authored model
files provide their sub-building definitions:

| Building ID | Static name | Authored source | Bbutton status |
| ---: | --- | --- | --- |
| 76 | `BUILD_TUMULUS` | `Mon_Tumulus_Subs.txt` | unknown |
| 77 | `BUILD_GRAND_TUMULUS` | `Mon_Grand_Tumulus_subs.txt` | unknown |
| 78 | `BUILD_GREAT_TEMPLE` | `Mon_Great_Temple_subs.txt` | unknown |
| 79 | `BUILD_SPLENDID_TEMPLE` | `Mon_Splendid_Temple_subs.txt` | unknown |
| 82 | `BUILD_LARGE_PALACE` | `Mon_Palace_Subs.txt` | unknown |
| 84 | `BUILD_UNDERGROUND_VAULT` | `Mon_Underground_Vault_subs.txt` | unknown |

The Bbutton contact sheet contains no unassigned family whose motif can be
uniquely tied to these six multi-part projects. `#1653–#1655` is already the
grand-pagoda family (`BUILD_GRAND_PAGODA`, ID 93). The exe's `0x4B0010`
specialized writer and the `China_Mon_*` archives are the relevant rendering
paths; treating a guild, garden, or fort icon as a monument button would mix
two different systems.

## Result and next experiment

- New evidence: four commerce panel slots are `videoObserved` as
  `#1533/#1536/#1539/#1542` families.
- No requested ID can be upgraded to `confirmed` Bbutton mapping.
- Wall/gate/tower and the six multi-part monuments should be traced through
  their runtime builder creation path, not through the generic Bbutton sheet.
- The highest-value next capture is the original executable while opening the
  commerce panel and selecting each visible slot, recording the building ID
  passed to the placement builder together with the image family.
