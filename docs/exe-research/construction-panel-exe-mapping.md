# Executable-confirmed construction panel mapping

This note records the recovered original `category slot → selector/building →
China_Interface New_Bbuttons family` control flow. It supersedes the earlier
sheet-order mapping guesses in `construction-panel-inferred-mapping.*`.

## Binary identity and cross-build result

| Build | SHA-256 | Result |
| --- | --- | --- |
| `Emperor[EN].exe` | `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` | canonical 1024×768 table and control flow |
| `Emperor[CH].exe` | `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a` | byte-identical mapping tables and relevant functions |

Both builds contain the same 11×6 selector table at VA `0x855888` (file
offset `0x455888`) and the same 45×32 group-member table at VA `0x821164`
(file offset `0x421164`). Classification: `confirmed`.

## Recovered draw path

1. `FUN_0053a760 @ 0x53A760` selects one 48-byte category row from
   `0x855888`. Each of its six records is `(selectorID: u32,
   sheetFamilyIndex: u32)`.
2. It writes the selector to the live slot model and writes
   `sheetFamilyIndex * 3` to the slot's sprite offset.
3. `FUN_00449c10 @ 0x449C10` resolves image group key `#695` through
   `FUN_00408170 @ 0x408170`, adds that offset, and adds `0/1/2` for
   normal/hover/pressed.
4. In exported `China_Interface`, family index `1` starts at global image
   `#1491`; therefore `baseImageID = 1488 + 3 × sheetFamilyIndex`.
5. `FUN_0053a690 @ 0x53A690` calls `FUN_00403c80 @ 0x403C80` for submenu
   selectors, but performs singleton collapse only when `FUN_0053a640 @
   0x53A640` accepts the group index. The exact accepted groups are decimal
   `14, 35, 36, 38`, reached by selectors `63, 204, 205, 222`. For those four
   groups only, exactly one available member replaces the selector ID while
   preserving the same family. Every other group still opens state 6 with one
   row. Zero-member disabling is finalized by `FUN_0053a720 @ 0x53A720`.

This explains every earlier negative scan: the PE stores neither absolute
`#1491+` image IDs nor a flat `buildingID → imageID` array. It stores family
indices and multiplies them by three at runtime.

## Fixed top-level category rows

The original top-level construction panel has six fixed slots per category.
Zero entries are empty. `BUILD_*` names come from the confirmed 253-entry
static name table.

| Category index | Original category | Six `(selectorID, familyIndex → baseImageID)` slots |
| ---: | --- | --- |
| 0 | residential | `2,1→1491`; `11,2→1494`; empty ×4 |
| 1 | agriculture | `24,3→1497`; `200,4→1500`; `201,5→1503`; `29,6→1506`; `25,7→1509`; `30,8→1512` |
| 2 | industry | `35,9→1515`; `34,10→1518`; `204,11→1521`; `50,12→1524`; `140,13→1527`; `37,14→1530` |
| 3 | commerce | `53,15→1533`; `63,16→1536`; `206,17→1539`; `54,18→1542`; `88,19→1545`; `87,20→1548` |
| 4 | safety/health | `72,21→1551`; `207,22→1554`; `208,23→1557`; `124,24→1560`; `127,25→1563`; empty |
| 5 | government | `209,26→1566`; `125,27→1569`; `110,28→1572`; `123,29→1575`; `210,30→1578`; `205,31→1581` |
| 6 | entertainment | `211,32→1584`; `212,33→1587`; `213,34→1590`; `75,35→1593`; empty ×2 |
| 7 | religion | `214,36→1596`; `240,37→1599`; `241,38→1602`; `219,39→1605`; empty ×2 |
| 8 | military | `220,40→1608`; `221,41→1611`; `222,42→1614`; `223,43→1617`; `134,44→1620`; `226,45→1623` |
| 9 | aesthetics | `115,46→1626`; `229,47→1629`; `136,48→1632`; `230,49→1635`; `107,50→1638`; `242,51→1641` |
| 10 | monuments | `233,52→1644`; `234,53→1647`; four runtime monument slots |

Important category corrections for the native catalog: mill `#53` is in
commerce; inspector office/tower `#124` is in safety/health; tea shack
`#237`, lacquer refinery `#238`, and silkworm shed `#239` belong to the
agriculture submenu represented by selector `#29`.

## Submenu family expansion

These rows are confirmed original shared families. They do not mean the
original always flattened every member into simultaneous grid slots: when
multiple members are available, the original keeps the submenu selector.

| Selector | Group | Shared base | Member building IDs |
| ---: | ---: | ---: | --- |
| 24 | 9 | 1497 | `193, 192` |
| 200 | 33 | 1500 | `199, 198, 196, 197, 195, 194` |
| 201 | 34 | 1503 | `202, 203` |
| 29 | 30 | 1506 | `238, 239, 237` |
| 25 | 10 | 1509 | `27, 28, 26` |
| 30 | 11 | 1512 | `31, 33` |
| 34 | 12 | 1518 | `38, 36` |
| 204 | 35 | 1521 | `39, 40, 41` |
| 50 | 13 | 1524 | `43, 42, 44` |
| 140 | 15 | 1527 | `47, 45, 46` |
| 63 | 14 | 1536 | `59, 60` |
| 206 | 37 | 1539 | `66, 67, 65, 70, 69, 64, 68` |
| 205 | 36 | 1581 | `48, 49` |
| 240 | 32 | 1599 | `215, 216` |
| 241 | 31 | 1602 | `217, 218` |
| 222 | 38 | 1614 | `224, 225` |
| 134 | 6 | 1620 | `131, 129, 130` |
| 229 | 39 | 1629 | `116, 243, 244, 245, 117, 246, 247, 248` |
| 136 | 3 | 1632 | `119, 251, 120, 252, 121, 122` |
| 230 | 40 | 1635 | `111, 113` |
| 107 | 42 | 1638 | `231, 91, 90, 89` |
| 242 | 44 | 1641 | `118, 249, 250` |
| 234 | 41 | 1647 | `52, 235, 236` |

Selectors `88` and `87` lead to resource-choice groups rather than building
model groups and retain bases `#1545` and `#1548`. `0x403C80` maps selector
`88` to group `7` and selector `87` to group `19`; both group rows contain the
one-based empire-city positions `1…31`, terminated by zero. They are not
ordinary `buildingID` mappings in the native catalog.

### Resource selector control flow

The special group behavior is fully recovered and byte-identical in both
builds:

1. `FUN_005DB960 @ 0x5DB960` maps the zero-based available-city-list index to
   one of the 22 empire city slots. It skips the player city and slots that are
   not active/available.
2. `FUN_005DB9C0 @ 0x5DB9C0` rejects an invalid or unavailable route and rejects
   a city already referenced by an existing station/quay through
   `FUN_005DBB00`.
3. `FUN_005DBA20 @ 0x5DBA20` returns building ID `0x38` (`56`, Trading Quay)
   when the authored water-route/path predicate succeeds; otherwise it returns
   `0x3A` (`58`, Trading Station). `GameData/Model/BuildingModel.txt` independently
   identifies IDs 56 and 58 by those names.
4. `FUN_00402890 @ 0x402890` retains group 7 members only when the route result
   is `58`, and group 19 members only when it is `56`. Therefore selector `88`
   is the land-city/Trading Station menu and selector `87` is the sea-city/
   Trading Quay menu.
5. `FUN_00404040 @ 0x404040` converts the selected one-based list member back
   through `0x5DB960`, stores the city slot at `0x88EBC0`, changes the selected
   construction building to 56 or 58, and enters the ordinary placement path.
6. `FUN_005B7030 @ 0x5B7030` uses the same state-6 vertical overlay as building
   submenus, but draws the empire city name through `0x5DBA70` and the route
   building thumbnail for ID 56/58.

Classification: selector identity, group membership, filtering, one-building-
per-city exclusion, city-list order, selected city persistence, building ID,
and overlay content are `confirmed`. The Native empire parser already supplies
the corresponding city IDs, names, open state, route kind, and existing
physical buildings, so no substitute route heuristic is required.

## Dynamic monument slots

For category 10, `0x53A760` scans exact pairs at `0x855D88` in this order:
`76…84`, `92`, `93`, `253…268`, all with family index `55` (global base
`#1653`), followed by `-1,1`. `FUN_0053A5D0 @ 0x53A5D0` is now recovered:
it walks the current task-object list from `FUN_0055BCB0`, retains type-2
objects, and matches the candidate against the task building ID. The match is
normally exact. `FUN_0053A4E0 @ 0x53A4E0` additionally treats IDs `85`, `86`,
and all layout IDs `253…268` as one task family, so a task for either long-wall
project exposes layout candidates in authored order.

`0x53A760` accepts the first four matching candidates before scanning existing
map building/sub-building objects. An exact candidate already on the map clears
that slot's selector, sprite offset, and availability. The slot cursor has
already advanced, so later candidates do **not** compact into the hole. The
existing-object comparison is exact even for the `85/86/253…268` task family.

The tail of `0x53A760` separately gates the two fixed support slots from the
current type-2 task list:

- no type-2 tasks clears all six slots;
- tasks `76…86` retain both Laborers' Camp `233` and guild selector `234`;
- tasks `92` or `93` retain the guild selector but clear Laborers' Camp;
- unrecognized type-2 tasks retain neither support slot.

Classification: candidate order, task predicate, long-wall equivalence family,
first-four limit, exact existing-object removal, non-compaction, and support
slot gates are `confirmed`.

## Great Wall layouts: editor creation and campaign pre-placement

The recovered placement path disproves the earlier phase-button hypothesis:

1. `FUN_00564880 @ 0x564880` calls `FUN_00567650 @ 0x567650` to bind building
   IDs `253…268` one-to-one to `Model\\Mon_Great_Wall_01_subs.txt` through
   `Model\\Mon_Great_Wall_16_subs.txt`.
2. `FUN_00562F70 @ 0x562F70` classifies all sixteen IDs as multi-part
   monuments. In `FUN_004B1250 @ 0x4B1250`, `FUN_00563C60` computes the
   rotated authored bounds and `FUN_005643C0` validates the complete set of
   sub-building footprints before the root object is accepted.
3. The placement object's virtual call reaches `FUN_0056A0D0 @ 0x56A0D0` and
   then `FUN_00563850 @ 0x563850`, which creates and links every authored
   sub-building at its rotated relative offset. When this creation path is
   available, a click therefore places one complete selected layout; it does
   not advance one existing 4×4 segment.
4. `FUN_00563720 @ 0x563720` returns wall mode 2 for active task `85` and mode
   3 for task `86`. `FUN_0057BBA0 @ 0x57BBA0` maps those modes to
   `China_Mon_Earthen_Greatwall_*` and `China_Mon_Greatwall_*` respectively;
   mode 1 is the ruined-wall family.
5. `FUN_00402A50 @ 0x402A50` returns `1` for every selector when the map-editor
   flag `0x88EC00` is set, but has no normal-city cases for `253…268`; its
   default branch returns `0`. `FUN_00403920 @ 0x403920` writes that result to
   the availability table, and `FUN_0053A720 @ 0x53A720` marks a six-slot
   button disabled when either its selector or availability word is zero.
   Dynamic task-family matching can therefore populate a layout selector, but
   cannot make it player-placeable in an ordinary campaign city.
6. `FUN_005636B0 @ 0x5636B0`, called by the city-load path
   `FUN_00534BF0 @ 0x534BF0`, scans the already-loaded multipart objects and
   assigns each the mode returned by `FUN_00563720`. This is the campaign
   path: the map supplies predetermined Great Wall objects, while task `85`
   gives them earthen mode 2, task `86` gives stone mode 3, and the absence of
   either task leaves the ruined mode family.

All sixteen authored files parse as nine construction phases. Their sub-object
counts in ID order are `50, 51, 39, 53, 53, 51, 51, 49, 53, 53, 53, 53, 53,
53, 53, 53`; every layout has exactly four gate and four road sub-buildings.
The Badaling mission closes the map-data side of this contract independently:
`Model/Mon_Great_Wall_05_subs.txt` identifies itself as Badaling, and its
layout ID is therefore `257`. With no rotation and root `(55,32)`, its 45
4×4 wall/tower footprints, four 2×2 gate footprints, and four 1×1 road
footprints exactly equal the 740 cells in `Cities/Badaling.map` whose image IDs
fall in the authored `China_Mon_Earthen_Greatwall_1` interval. The count is
also exact (`45×16 + 4×4 + 4 = 740`), with no unmatched or extra map cells.
This disproves the legacy Native 35-segment/46-block Badaling binding.
The manual independently states that Great Wall positions are predetermined,
that earthen wall requires dirt and wood, and that stone wall requires dirt
and stone. Exact terrain-fit constraints, task material totals, construction
worker control flow, and save/replay transitions remain `unknown` and must not
be approximated.

Classification: ID-to-file mapping, editor full-layout creation, campaign
unavailability, preloaded-object mode assignment, task-to-wall-family mapping,
Badaling layout identity/root/rotation/footprint, and parsed layout invariants
are `confirmed`. The campaign map/save object records that retain per-part
construction phases and linked root/sub-building IDs remain `unknown`. The old
Native click-an-existing-segment command is retained only as legacy decode/state
plumbing and is no longer a player-facing tool. Layout buttons stay disabled
in ordinary player mode by original contract, not merely as a temporary Native
research gate.

## Recovered submenu interaction and geometry

The multi-member building submenu is a distinct original UI state, not a
second 3×2 page inside the right panel.

1. The six top-level button records live at `0x855A98`, stride `0x28`. Their
   classic relative rectangles are `(59,279,54,53)`, `(113,279,54,53)`,
   `(167,279,54,53)`, then the same three columns at `y=333`. Their normal
   click callback is `0x53A470`, which clears the active list/group state and
   jumps to `0x404040`.
2. `0x404040` reads the clicked selector from the current group table. For a
   selector recognized by `0x403C80`, it stores the returned group index,
   counts available members through `0x402950`, loads a count-dependent
   vertical offset from `0x822A3C`, switches the city UI to state `6`, and
   does not enter building placement yet.
3. State `6` draws the available group members through `0x5B7030`. It places
   rows at `panelOriginX - measuredWidth - 0x59` and
   `0x6E + countOffset + rowIndex × 0x18`; the count-offset table keeps the
   list bottom-aligned near the lower construction panel. Each row includes
   the original localized building name and, when available, a small building
   thumbnail. Thus the menu extends left from the right panel over the map.
4. Hit testing is handled by `0x402780`: it uses the same count and offset,
   advances through available members in authored group order, writes the
   one-based member position, and calls `0x404040` again. A concrete member
   then exits state `6` and enters the original placement path. The state-6
   right-click branch in `0x538160` returns to state `1` without selecting a
   member.

Classification: the state transition, authored member ordering, overlay side,
24-pixel row cadence, bottom-alignment formula, selection path, and right-click
cancel are `confirmed`. Exact text font rasterization, row background pixels,
and thumbnail scale still require an undistorted same-state screenshot and are
`unknown`; native presentation may use the existing original panel texture and
building thumbnail renderer only as an explicitly bounded presentation
fallback until that capture exists.

## Implementation contract

- `OriginalConstructionButtonSpriteCatalog` distinguishes direct executable
  rows from executable-confirmed shared submenu families.
- A missing association remains `unknown`; do not derive one from sheet order.
- Crop IDs `194…199` share `#1500`; `#1503` is irrigation, not hemp.
- The original does not reorder all available tools to the front. It preserves
  six top-level slots and disables unavailable selectors. Singleton collapse
  applies only to selectors `63`, `204`, `205`, and `222`; all other submenu
  and resource groups retain state 6 even with one row.
- When several building members are available, selecting the top-level family
  opens the confirmed left-extending, bottom-aligned vertical overlay; selecting
  a row enters placement and right-click closes the overlay.
- Resource selector `88` opens eligible land cities and places building `58`;
  selector `87` opens eligible sea cities and places building `56`. Both use
  the original state-6 overlay, skip closed/unavailable cities, and remove a
  partner after that city already has a physical trading building.
- Great Wall IDs `253…268` identify complete authored layouts. Never route
  them to the legacy Native segment-advance command or expose them as ordinary
  campaign placement tools. Their whole-layout placement path belongs to the
  original map editor; campaign missions load predetermined layout objects.
