# Exe research notes

Read-only static inspection, asset extraction, and **native-inferred** mapping tables for the hash-identified `Emperor[EN].exe` / `China_Interface` construction UI. Not runtime dependencies.

| Note | Topic |
| --- | --- |
| [construction-panel-mapping.md](./construction-panel-mapping.md) | **Index** — asset-confirmed / native-inferred / runtime-unknown sections |
| [construction-panel-inferred-mapping.md](./construction-panel-inferred-mapping.md) | Inferred category·slot·buildingId·imageId·screenRect (+ contradictions) |
| [construction-panel-inferred-mapping.csv](./construction-panel-inferred-mapping.csv) | Flat inferred/unknown rows |
| [construction-panel-inferred-mapping.json](./construction-panel-inferred-mapping.json) | Structured inferred payload |
| [construction-bbutton-families.csv](./construction-bbutton-families.csv) | **Confirmed** sheet families only |
| [construction-bbuttons.md](./construction-bbuttons.md) | Exe UI-record path, negatives, Wine probes |
| [construction-panel-assets.json](./construction-panel-assets.json) | SG3 / `map_panels` metadata |
| [construction-panel-mapping-inferred-crosswalk.csv](./construction-panel-mapping-inferred-crosswalk.csv) | Thin older crosswalk (superseded for layout) |
| [build-name-catalog.md](./build-name-catalog.md) | Static 253-entry `BUILD_*` name table from game/editor PE files + screenshot cross-check |
| [construction-orphan-family-crosswalk.md](./construction-orphan-family-crosswalk.md) | Static crosswalk for family-start frames missing from the native catalog |
| [video-panel-observations.md](./video-panel-observations.md) | `videoObserved` category/grid frames sampled from `BV1uau26gEVV.mp4` |
| [cursor-commercial-defense-monument-pass.md](./cursor-commercial-defense-monument-pass.md) | Cursor pass: commerce-panel observation and defense/monument evidence gaps |
| [cursor-animal-sprite-groups.md](./cursor-animal-sprite-groups.md) | Cursor pass: authored `SprMain`/`SprMain2` animal bitmap and logical-group bounds; figure-state selectors remain unresolved |
| [ambient-prey.md](./ambient-prey.md) | Confirmed pheasant figure/sprite data and the remaining map spawn-point gap |

Policy:

- Never copy the proprietary executable into the repo, bundle, or tests.
- Classify `confirmed` / `inferred` / `unknown` — **never** upgrade inferred catalog rows to confirmed without exe/runtime closure.
- Do not invent a complete original map; keep gaps explicit.

## Section map

1. **Asset-confirmed** — `construction-bbutton-families.*` (geometry only).
2. **Native-inferred / runtime-unknown** — `construction-panel-inferred-mapping.*` from Swift catalogs + classic panel layout; withdrawn commerce rows are retained only as `unknown` trace records.
3. **Static semantic crosswalk** — `build-name-catalog.md` confirms the original `buildingId → BUILD_*` names, and `construction-orphan-family-crosswalk.md` records family-start candidates without overclaiming image IDs.
4. **Video-observed** — `video-panel-observations.md` records visible category/slot frames and state offsets; it does not replace executable evidence.
5. **Runtime-unknown** — live slot artwork is partially captured under Rosetta/Wine, but the original building-ID writer/tooltip is still unresolved (below).
6. **Animal asset crosswalk** — `cursor-animal-sprite-groups.md` records the authored animal bitmap names, logical-group boundaries, and the explicit `inferred`/`unknown` figure-state gap. It does not authorize adding predator or prey behavior.

## Inferred-layer pass (2026-08-11)

Sources read for the mapping pass:

- `Sources/EmperorCore/InterfaceSpriteCatalog.swift` → 53 `baseImageIDByBuildingID` rows + crop helpers + category icon bases
- `Sources/EmperorNative/ConstructionToolbar.swift` → `ConstructionToolCategory`, `NativeConstructionTool` titles / buildingIDs / categories
- `Sources/EmperorNative/ContentView.swift` → `ClassicControlPanel` filters, 3×54 grid, advisor height, rail
- `Sources/EmperorNative/EmperorTheme.swift` → 1024×768, panel 224, rail 54, advisor 280 / grid y≈321

Outputs: `construction-panel-inferred-mapping.{md,csv,json}` (+ scratch copy under `.agent_scratch/exe_re/`).

Notable contradictions (still inferred, not “fixed”):

- **`catalog_base_vs_index_family_start`** — many commerce catalog bases are not INDEX family starts under consecutive 54×53 packing (e.g. warehouse `#1528` sits inside lumber pack `#1527–#1529`).
- `#1535` is **54×52**, breaking naive triples near mill.
- Live UI sorts available tools first; stable `slot` ignores that on purpose.
- Tool case names `bathhouse` / `magistrate` vs Chinese titles 道教大庙 / 佛塔.

The static `BUILD_*` name table confirms the original semantics behind those
rows and identifies the currently unmapped vendor, wall, farm, religious,
weaponsmith, and producer IDs. It does not close the Bbutton image mapping;
that remains a separate evidence track.

The follow-up video pass made one implementation-safe correction: semantic
crop lookup now selects the observed hemp family `#1503–#1505` instead of
reusing the generic field family. The broader mission-filtered agriculture
list remains data-dependent and is not synthesized from this observation.

## Runtime session (active, mapping still incomplete)

Rosetta 2 is now installed. `arch -x86_64 wine32on64 --version` returns
`wine-5.0`; the hash-matched temporary clone reaches the original Chinese
front end and a tutorial city. The first live 商业 panel capture confirms
that `#1533–#1544` are consumed as construction-slot artwork, while their
building IDs remain unknown. Details are in `construction-bbuttons.md` §10–§12.

### Next steps (interactive Mac + Rosetta)

1. Continue the temporary Wine session through each construction category and
   capture slot changes, tooltips, and selected/hover frames; the first 商业
   capture is complete but semantic IDs are still unknown.
2. LLDB log `0x408170` / `0x5288E0` for Bbutton-band ids + rects once a live
   slot object can be identified.
3. Resolve catalog vs INDEX family-start conflict from live frames.
4. Only then promote selected rows toward `confirmed`.

Do **not** resume generic PE immediate/string scans (`construction-bbuttons.md` exhausted list).
