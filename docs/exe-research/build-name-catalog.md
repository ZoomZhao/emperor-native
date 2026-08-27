# Static building-name catalog

This note records a static executable finding that is independent from the
construction Bbutton image mapping.

## Finding

`Emperor[EN].exe`, `Emperor[CH].exe`, and `EmperorEdit.exe` each contain a
contiguous pointer table of 253 `BUILD_*` strings. The first entry is
`BUILD_NOTHING` at index `0`; the final entry is `BUILD_POND2` at index `252`.
The index agrees with the building IDs already used by the native model
catalog for known buildings (`2 = BUILD_HOUSE1`, `31 = BUILD_FISHING_QUAY`,
`54 = BUILD_WAREHOUSE`, `203 = BUILD_IRRIGATION_PUMP`, and so on).

This is strong static evidence for `buildingId → original BUILD_* name`. It is
not evidence for `buildingId → China_Interface Bbutton imageId`: the pointer
table contains names only, and the Bbutton writer is still unresolved.

| Binary | Pointer-table file offset | Entries | Status |
| --- | ---: | ---: | --- |
| `Emperor[EN].exe` | `0x4474AC` | 253 (`0..252`) | confirmed name table |
| `Emperor[CH].exe` | same data layout as EN | 253 (`0..252`) | confirmed name table |
| `EmperorEdit.exe` | `0x45A1D4` | 253 (`0..252`) | confirmed editor copy |

The EN and CH binaries have byte-identical `.rdata` and `.data` sections for
this table. The editor carries the same ordered names at a different file
offset.

## Relevant rows for the construction research

| buildingId | Original static name | Native inferred title | Current Bbutton status |
| ---: | --- | --- | --- |
| 64 | `BUILD_BRONZEWARE_VENDOR` | 青铜器铺 | unknown |
| 68 | `BUILD_LACQUERWARE_VENDOR` | 漆器铺 | unknown |
| 69 | `BUILD_SILK_VENDOR` | 丝绸铺 | unknown |
| 70 | `BUILD_TEA_VENDOR` | 茶铺 | unknown |
| 129 | `BUILD_WALL` | 城墙 | unknown |
| 130 | `BUILD_GATEHOUSE` | 城门 | unknown |
| 131 | `BUILD_TOWER` | 城防塔 | unknown |
| 193 | `BUILD_FARMHOUSE` | 农田/农场关联 | unknown |
| 217 | `BUILD_BUDDHIST_SHRINE` | 未覆盖 | unknown |
| 226 | `BUILD_WEAPONSMITH` | 未覆盖 | unknown |
| 237 | `BUILD_TEA_SHACK` | 制茶棚关联 | unknown |
| 238 | `BUILD_LACQUER_REFINERY` | 漆料棚关联 | unknown |
| 239 | `BUILD_SILKWORM_SHED` | 养蚕棚关联 | unknown |

The table also resolves two native naming contradictions: ID `216` is
`BUILD_DAOIST_TEMPLE` and ID `218` is `BUILD_BUDDHIST_PAGODA`. The native
cases currently named `bathhouse` and `magistrate` should not be used as
original semantic names.

The two local playthroughs add one non-authoritative visual cross-check: the
agriculture panel presents the ordinary field family (`#1497`), rice (`#1500`),
and hemp (`#1503`) alongside hunting, orchard, and fishing entries. This makes
`193 = BUILD_FARMHOUSE → #1497 family` and `194 = BUILD_HEMP_CROP → #1503
family` plausible, but both remain `videoObserved`/`inferred` rather than
exe-confirmed Bbutton associations.

## Screenshot cross-check

The original city screenshot
`/Users/zoomzhao/Downloads/emperor/capcap-260724-160610.png` is a 2× capture.
Nearest-neighbor template matching against the checked-in image exports found:

- `#1491` (`54×53`) at physical `(1752, 732)` with normalized correlation
  `0.99997`; this is the visible residential button.
- Category-rail resources `#1327`, `#1335`, `#1339`, and `#1351` at the
  expected 2× rail positions with correlation `1.0`.

This upgrades those particular visual observations to `screenshotObserved`
evidence. It still does not prove the original executable's internal button
writer or the mission-specific slot order.

## Extraction method

The table was recovered by scanning the PE data section for the longest
4-byte-aligned run of pointers whose targets are `BUILD_*` strings. The run is
253 entries long in both the game and editor binaries. No proprietary binary
is copied into the repository; only offsets, names, and evidence are recorded.

## Next static use

Use this table as the canonical semantic crosswalk for the 23 currently
unmapped native-grid rows. Then perform a separate resource/image pass for
their Bbutton families. Do not promote those image associations beyond
`inferred` until a screenshot, resource-geometry match, or runtime draw path
ties the row to a concrete `China_Interface` image family.
