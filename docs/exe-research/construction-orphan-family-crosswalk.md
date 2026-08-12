# Bbutton family-start crosswalk

This note records the next static pass over the nine 54×53 families that do
not have a direct row in `OriginalConstructionButtonSpriteCatalog`.

The `BUILD_*` names are **confirmed** from the original PE string-pointer
table (see [build-name-catalog.md](./build-name-catalog.md)). The family
association below is only **inferred** from the contact sheet and the repeated
three-frame layout in `INDEX.csv`; it is not a runtime draw capture.

## Why these families looked orphaned

The extracted native catalog frequently stores the middle frame of a
three-state button family, while the sheet starts at the normal frame. For
example, the warehouse row stores `#1528`, but the preceding lumber family is
`#1527–#1529`. Therefore “no catalog row at family start” does not imply a
missing building.

| Family start | Three frames | Static semantic candidate | Catalog row | Confidence | Evidence / limitation |
| ---: | --- | --- | ---: | --- | --- |
| 1503 | 1503–1505 | `BUILD_HEMP_CROP` (194) | — | medium | Agriculture frames in both local videos show the long-strip hemp-field motif; native crop model uses producer/plot ID 194 |
| 1530 | 1530–1532 | `BUILD_FOOD_VENDOR` (66) | 1531 | medium | Same food-stall motif as catalog row; catalog points to middle frame |
| 1536 | 1536–1538 | unknown | — | unknown | Directly observed on the original 商业 rail; the former weaver guess (47) is withdrawn |
| 1539 | 1539–1541 | unknown | — | unknown | Directly observed on the original 商业 rail; the former ceramics-shop guess (65) is withdrawn |
| 1542 | 1542–1544 | unknown | — | unknown | Seen in the reference video only; the former hemp-shop guess (67) is withdrawn |
| 1545 | 1545–1547 | `BUILD_COMMON_MARKET` / `BUILD_GRAND_MARKET` (59/60) | 1546 | medium | Market-pavilion motif; shared native family already recorded |
| 1548 | 1548–1550 | `BUILD_TRADING_QUAY` / `BUILD_DOCK` (56/57) | — | low | Boat/water motif; the two PE names cannot be separated from static art alone |
| 1578 | 1578–1580 | `BUILD_FERRY` (210) or adjacent civic utility | — | low | Flat water/platform motif; no native tool row and no direct name→image pointer |
| 1581 | 1581–1583 | `BUILD_TREASURY` / `BUILD_VENDORS` (205/206) | — | low | Civic/resource motif is visually plausible but unresolved without runtime or a writer table |

## Consequence for implementation

Do not assign the low-confidence rows to a Swift building tool yet. The
medium-confidence rows can share the existing family metadata, but the
rendering layer may use only the catalog's still-supported recorded frames
(`1531`, `1546`) until a runtime capture establishes the family start, semantic
ID, and frame passed to the original button widget.

The first Rosetta/Wine capture is now complete for the tutorial's 商业 page and
confirms the three visible families above. A tooltip, placement callback, or
button-writer trace is still needed to recover semantic IDs and to resolve the
remaining `1542/1548/1578/1581` candidates; generic PE string scans are not
enough.

## Evidence classes

- `confirmed`: `buildingId → BUILD_*` semantic name and 54×53 family geometry.
- `medium`: repeated visual motif agrees with an existing native catalog row,
  but no original writer/paint call has been observed.
- `low`: contact-sheet resemblance only, or multiple canonical names fit.
- `unknown`: original runtime frame selection and panel ordering.
