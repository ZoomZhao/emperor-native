# Cursor roadblock and market static pass

Read-only inspection of the hash-matched original EN executable and shipped
GameData. No Swift/GameData changes were made.

> **Closure note (supersedes the `unknown` route-semantics conclusion below):**
> the original roadblock blocking semantics — placement terrain rule (`0x46D110`),
> passable derived caches (`0x5AD440`/`0x5223B0`), and the walker/**peddler
> roamer** vs **buyer/destination-walker** movement collision (`0x4E8BC0`) —
> were subsequently closed by
> [roadblock-path-blocking.md](./roadblock-path-blocking.md). The paragraphs in
> this pass that still say the blocking algorithm is `unknown` reflect the state
> at the time of *this* bounded scan and are superseded by that document. The
> market-shell and Bbutton items below remain open.

## Roadblock (`BUILD_ROADBLOCK`, building 126)

### Confirmed authored/native evidence

- `GameData/Model/EmperorBuildingModels.txt` contains the original
  `BUILD_ROADBLOCK` row (building ID 126); the model table is the source for
  its construction cost/flags.
- The original EXE string table contains `BUILD_ROAD` and a separate
  `BUILD_MARKET_ROAD`; there is no readable `BUILD_ROADBLOCK` string in the
  EN binary search. This is a naming difference, not evidence that the tool is
  absent.
- `Sources/EmperorCore/BuildingPlacement.swift` preserves the source-first
  rule already recovered for the native scaffold: roadblock placement requires
  an existing road tile and an unoccupied point; the placed one-tile object
  leaves the authored road underneath when demolished. The native sprite
  catalog maps ID 126 to `China_Government2` image #2046 (logical group 146).

### EXE evidence and limits

- The PE contains RTTI for `cRoadBuildTest` (`.rdata` string near file offset
  `0x417B28`), proving a dedicated road-build test class exists. Static string
  xrefs do not expose its methods or a literal building-ID comparison.
- `BUILD_ROADS` is present in the static build-name table, but it is the map
  editor/road tool name, not a confirmed roadblock mapping. No direct
  `BUILD_ROADBLOCK` string or isolated `126`→sprite record was recovered in
  this pass.
- *This pass* therefore left the exact blocking semantics `unknown`. That gap
  is now closed by [roadblock-path-blocking.md](./roadblock-path-blocking.md):
  placement validation `0x46D110`, passable main/fallback route caches
  (`0x5AD440`/`0x5223B0`), and the `0x4E8BC0` movement-collision branch that
  denies the roaming movement context at roadblock/gate tiles while
  path-following movement and heroes (`+0x12 == 0x4F`) pass. The global
  context flag's exact cross-figure inheritance remains inferred; the manual's
  peddler-is-a-roamer and buyers-are-destination-walkers framing (p.34/p.37–38)
  independently supplies the behavior test.

### Additional static passability evidence (EN `.text`)

An unnamed map-cell validation loop at `.text:0x46D593–0x46D767` repeatedly
calls `0x416BB0` and `0x416BD0` while iterating candidate map cells. Its
selected-building global is read from `[0x88EBDC]` (the same selector used by
the surrounding construction code). The loop contains an explicit
`cmp eax,126` at `0x46D659` and a second check at `0x46D72A`:

```asm
46D659  cmp eax, 126
46D65E  and esi, 8
...
46D6E3  call 0x416BD0
46D6F0  cmp dword ptr [0x88EBDC], 126
46D6F9  ; generic rejection flag is set only when selector != 126
...
46D72A  cmp dword ptr [0x88EBDC], 126
46D73D  ; roadblock-only map flag/occupancy test (bit 0x40 + byte test)
```

This is `confirmed` evidence that roadblock placement is handled by a
dedicated branch in the original map-cell test, with a different flag mask
and a post-loop occupancy/terrain check. The called routines' meanings were
not recoverable from this bounded scan and are now supplied by
[roadblock-path-blocking.md](./roadblock-path-blocking.md) (`0x46D110`
terrain rule for `0x40`/`0x8`/`0x400` and the road-water auxiliary byte).

## Market shell and shop bays

### Confirmed authored data

The original PE contains the build-name sequence:

```text
BUILD_MARKETS
BUILD_EMPTY_VENDOR
BUILD_MARKET_ROAD
BUILD_GRAND_MARKET
BUILD_COMMON_MARKET
BUILD_TRADING_POST
BUILD_FOOD_VENDOR
BUILD_CERAMICS_VENDOR
BUILD_BRONZEWARE_VENDOR
BUILD_HEMP_VENDOR
BUILD_LACQUERWARE_VENDOR
BUILD_SILK_VENDOR
BUILD_TEA_VENDOR
```

The string addresses are in the static build-name table around file offsets
`0x448878…0x4488B0` (the surrounding sequence also contains
`BUILD_EMPTY_VENDOR` and `BUILD_TRADING_POST`); nearby pointer tables point at these names. This confirms
that markets and their vendor/shop concepts are first-class authored model
records, but does not identify the China_Interface Bbutton rows.

Shipped `GameData/China_General` data and the native catalog provide the
following source-backed world-shop image IDs:

| shop building ID | authored shop | China_General image |
| ---: | --- | ---: |
| 64 | Bronzeware | 627 |
| 65 | Ceramics | 617 |
| 66 | Food | 611 |
| 67 | Hemp | 619 |
| 68 | Lacquerware | 621 |
| 69 | Silk | 623 |
| 70 | Tea | 625 |

`China_General` also contains shell/paving pieces #629 (entertainment area)
and #632–#635 (market tiles). These image IDs are `confirmed` authored asset
references. `MarketSimulation.swift` confirms common market ID 59 has four
shop bays and grand market ID 60 has six; the shop order is
`[66, 67, 65, 70, 69, 68, 64]` in the authored native data crosswalk.

### Static limits

- The PE has RTTI names `cMarket`, `cMarketInfo`, `cSmallMarketConstInfo`, and
  `cLargeMarketConstInfo`, confirming separate common/grand market runtime
  classes/records.
- The same build-test RTTI neighborhood contains `cRoadBuildTest` alongside
  other specialized tests (`cWallBuildTest`, `cMarshBuildTest`, etc.). This
  establishes a dedicated placement-test type, but the stripped/static image
  does not expose its vtable call sites or route-network side effects.
- A direct scan found no readable `shopImageIDByBuildingID` table and no
  contiguous `64…70` image-ID map in the initialized PE sections. The
  executable's global sprite resolver (`0x408170`) uses a paged runtime image
  table, so raw IDs in the native catalog cannot be inferred from simple PE
  concatenation.
- No static evidence ties video-observed Bbutton families `#1533–#1544` to
  shop IDs 64–70. Existing authored data instead treats 64–70 as market-bay
  sub-buildings, not independent construction permissions.
- Exact runtime shell state (empty/occupied bay frame, selected vendor,
  capacity text, staffing/stock overlays) remains `unknown` until the CH
  executable can enter a city without the macOS file-volume permission prompt.
- A native catalog comment associates market squares 59/60 with family
  `#1546`; this remains `inferred` from sheet-order/rendering and is not an EXE
  confirmed Bbutton or world-shell mapping.

## Evidence classification

- `confirmed`: original build-name strings/RTTI classes; China_General shop
  image IDs and market capacities from shipped authored data; roadblock ID and
  native one-tile placement invariant.
- `inferred`: any visual association between Bbutton families and market
  shells/vendors; the reason the EXE uses `BUILD_ROAD` rather than a literal
  `BUILD_ROADBLOCK` label.
- `unknown` (now resolved for roadblock route-blocking): the roadblock
  blocking algorithm flagged in this pass was `unknown` at scan time; it is
  closed by `roadblock-path-blocking.md` (placement, passable caches,
  `0x4E8BC0` roamer-denial/destination-pass, hero exemption). Still unknown:
  complete market shell state machine; EXE `buildingID → Bbutton` mapping for
  #1533–#1544.
