# Construction right-panel mapping (evidence table)

Goal: recover the original city right-rail construction catalog as

`category × slot → buildingId → China_Interface imageId (+ frame / screenRect)`.

This note is research evidence only. It does **not** claim a complete authoritative map. **Inferred rows must never be labeled `confirmed`.**

## Evidence classes

| Class | Meaning |
| --- | --- |
| `confirmed` | Directly supported by SG3/INDEX geometry, hash-matched exe static rules, or a successful runtime capture |
| `inferred` | Native Swift catalogs / layout / sheet-look — **not** original exe control flow |
| `unknown` | Not evidenced; left empty — **do not invent** |

## Three-section map (keep separate)

### A. Asset-confirmed (sheet only)

| File | Contents |
| --- | --- |
| [construction-bbutton-families.csv](./construction-bbutton-families.csv) / [.json](./construction-bbutton-families.json) | 45× 54×53 families + lead-in `#1488–#1490`; **no** buildingId/category/slot/screenRect |
| [construction-panel-assets.json](./construction-panel-assets.json) | SG3 bitmap ranges; `map_panels` = map-editor only |

### B. Native-inferred (this pass)

| File | Contents |
| --- | --- |
| [construction-panel-inferred-mapping.md](./construction-panel-inferred-mapping.md) | Human-readable inferred layer + contradictions |
| [construction-panel-inferred-mapping.csv](./construction-panel-inferred-mapping.csv) | Flat rows: category, slot, buildingId, buildingName, imageId, frame, screenRect, evidenceType=`inferred`/`unknown`, confidence, source, contradictions |
| [construction-panel-inferred-mapping.json](./construction-panel-inferred-mapping.json) | Structured sections + sharedFamily + layout + exe gaps |
| [construction-panel-mapping-inferred-crosswalk.csv](./construction-panel-mapping-inferred-crosswalk.csv) | Older thin crosswalk (buildingId→imageId only); superseded for layout/slot work by the files above |

Most Bbutton↔building associations remain **`evidenceType=inferred`**. The
four former commerce/light-industry rows (53/47/65/67) are now explicit
`unknown` records because original runtime shows their families on 商业 but
does not identify their building IDs. Commerce stretch also has an extra
**`catalog_base_vs_index_family_start`** conflict — confidence **low** for
the remaining sheet-order rows.

### C. Runtime-unknown

| Item | Status |
| --- | --- |
| Wine/LLDB blit capture | **partial** — Rosetta/Wine reached tutorial 商业 and captured `#1533–#1541`; semantic IDs remain unknown |
| Exe `buildingId→button` writer | **unknown** (`construction-bbuttons.md`) |
| Authoritative original category/slot order | **unknown** (native taxonomy only) |
| Pixel-measured screenRect from original | **unknown** (native theme geometry only) |

`construction-panel-mapping.json` still holds the earlier asset dump + empty `runtimeCapture`.

## Deliverables index

| File | Role |
| --- | --- |
| [construction-bbuttons.md](./construction-bbuttons.md) | Exe static / negatives / Wine probes |
| [construction-panel-inferred-mapping.*](./construction-panel-inferred-mapping.md) | **Inferred completion layer** |
| [README.md](./README.md) | Commands, failures, next steps |

## Confirmed (asset) summary

- Bbutton sheet `#1488–#1655`; 45 families at 54×53; states = consecutive ids.
- `map_panels.555` via `China_Unloaded.sg3` is **map editor**, not city build rail.
- Early bases are **not** filled through `0x1192B88` + `0x4A5960` for construction grid icons.

## Inferred (native) summary

From `OriginalConstructionButtonSpriteCatalog` (**53** building rows), `NativeConstructionTool` / `ConstructionToolCategory`, and `ContentView` `ClassicControlPanel`:

- Category labels and stable slots (enum order + classic filters; **not** mission available-first).
- Chinese `buildingName` from tool titles.
- `screenRect` for unscrolled 1024×768 classic shell (catalog top ≈ canvas y=321, x=858, 54×53 cells, 3 columns).
- `sharedFamily` for furnace / market / Daoist / guild.
- Crop buttons (9) and category rail (11) included as inferred rows.
- 23 classic-grid tools remain **image unknown** (no catalog Bbutton row).

## Not closed with original exe

- No PE writer recovered for early Bbuttons.
- Catalog vs INDEX family-start misalignment unresolved.
- Runtime slot artwork is partially captured, but no semantic `buildingId`/writer/tooltip or original pixel rect is closed.
- Do not merge section B into section A.
