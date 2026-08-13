# Exe research notes

Read-only static inspection, asset extraction, and **native-inferred** mapping tables for the hash-identified `Emperor[EN].exe` / `China_Interface` construction UI. Not runtime dependencies.

| Note | Topic |
| --- | --- |
| [construction-panel-mapping.md](./construction-panel-mapping.md) | **Index** — asset-confirmed / native-inferred / runtime-unknown sections |
| [construction-panel-exe-mapping.md](./construction-panel-exe-mapping.md) | **Current source of truth** — executable-confirmed category slots, submenu groups, and Bbutton families |
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
| [cursor-roadblock-market-pass.md](./cursor-roadblock-market-pass.md) | Cursor pass: roadblock placement/test evidence and market shell/shop-bay static evidence |
| [cursor-animal-sprite-groups.md](./cursor-animal-sprite-groups.md) | Cursor pass: authored `SprMain`/`SprMain2` animal bitmap and logical-group bounds; figure-state selectors remain unresolved |
| [ambient-prey.md](./ambient-prey.md) | Confirmed pheasant figure/sprite data and the remaining map spawn-point gap |
| [great-wall-map-state.md](./great-wall-map-state.md) | Confirmed multipart Great Wall archive/counters, terminal 53-part sprite rendering, dirt-dump versus tamping labor actions, fixed no-direct-difficulty construction contract, worker timing, shared convoy transfer/access/routing, bounded part/whole completion with no Great-Wall-specific reward, aggregate formula, and the hash-identified Qin-4 load path's lack of a phase reset; an aligned historical save, Wine probe, and inaccessible public playthrough are recorded as negative evidence, while the intended first playable state remains open |
| [grand-canal-map-state.md](./grand-canal-map-state.md) | Confirmed Haunxian canal reserve, five phases, task 102/stone requirements, and explicit wood/control-flow gaps |

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
7. **Roadblock/market static pass** — `cursor-roadblock-market-pass.md` records building 126 placement evidence, `cRoadBuildTest` RTTI, market/vendor build-name records, and the authored market shell/shop image IDs. Route blocking, live bay state, and Bbutton ownership remain unresolved.

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

## Local Ghidra decompilation (2026-08-12)

A local Ghidra 12.1.2 headless toolchain is set up for the hash-identified binaries, so control-flow questions can now be answered by C-level decompilation instead of PE-immediate/string scans.

- Install: `brew install ghidra` (formula, not cask). Requires `openjdk@21`; set `JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.12/libexec/openjdk.jdk/Contents/Home`.
- Script: `Exe/ghidra/scripts/DecompileAll.java` dumps every function's C to `$GHIDRA_OUT_DIR/$GHIDRA_OUT_NAME` (env vars) with the input hash recorded in the header. Use `-postScript`, run with `-noanalysis` after a normal import+analysis pass.
- Projects/inputs live under gitignored `Exe/ghidra/`; outputs `decompiled-en.c` / `decompiled-ch.c` are 18 MB each (~26,080 / 26,084 functions). The proprietary exe copies stay out of git (`Exe/` is gitignored).
- Binaries: `Emperor[EN].exe` (hash `8a6d2df1…6753`, the reference build already installed under Wineskin) and `Emperor[CH].exe` (hash `dbdeca1e…15a`, the newer root build extracted from the `龙之崛起.exe` SFX at `Exe/extracted/`). Both analyzed and decompiled; CH has 4 extra functions (`FUN_0053b446`, `FUN_007688ba`, `FUN_007a8c38`, `FUN_007a8c9f`).
- Re-run decompilation: `Exe/ghidra/` has the exact `analyzeHeadless` invocations; the analyze logs are `out/analyze.log` (CH) and `out/analyze-en.log` (EN).

## Split function tree (2026-08-12)

The 18 MB single-file dumps are also split into a navigable per-function tree so
control-flow questions can be answered file-by-file.

- `Exe/ghidra/scripts/split_decompiled.py <dump.c> <strings.txt> <out_dir>` reads the DecompileAll dump plus the DumpStrings table and emits:
  - `functions/<range>/<name>_<addr>.c` — one file per function, grouped by 1 MB address range;
  - `functions-index.csv` — address, name, file, referenced-string count;
  - `strings-index.csv` — string content → the function files that reference it (2567 strings used by 516 functions).
- Outputs: `Exe/ghidra/out/split-ch/` (26,084 functions, 109 MB) and `split-en/` (26,080). Gitignored under `Exe/`.
- Readability: every `s_<name>_<addr>` string symbol is renamed to `s_<addr>__<content>`, and each function file that touches strings carries a header comment listing the exact contents — e.g. `FUN_00500c70` (packet dispatch) lists all `Trade/Spy/War/Monument … Packet received` message names. `DAT_*` globals are left as-is (pointers/numbers, not strings).
- The CH entry point is a packer stub (literal `LoadLibraryA(0x65706c65)`, packed arithmetic), consistent with the CH build being a repacked variant of the EN binary; both builds share the identical 8386-string pool, so Chinese text is in external data files (`EmperorText.*`, `EmperorMM.*`), not the exe.

## Heuristic variable renaming (2026-08-12)

`Exe/ghidra/scripts/rename_vars.py` rewrites Ghidra's `iVar1/uVar2/pcVar3` locals
into role names per function, driven by usage signals (not AI guesses):

- advancing read-only pointers → `src` (feeds a writer) / `scan`; written-through pointers → `dst`
- `~len` after a strlen walk → `len`; self-updating loop counters → `i`
- int/uint function results → `ret` / `result`; compared-to-zero results → `ok`
- byte/char/bool compared as flags → `flag`; scalar indexes → `idx`/`n`/`c`/`u` by type
- `param_N`, `local_*`, register names, and `DAT_*`/`PTR_*` globals are preserved as-is

Re-run after regenerating a split tree:
`python3 scripts/rename_vars.py out/split-ch` (idempotent on regenerated trees; each
run counts `renamed: N` = files with ≥1 local renamed — ~9,860 of 26,084 in CH).
Both `out/split-ch` and `out/split-en` have been regenerated + renamed; zero files
retain `iVar/uVar/pcVar/…` patterns, and a 400-file brace-balance sample passed.
These names are heuristics for readability, not recovered original symbols.

## Semantic folder reorganization (2026-08-12)

`Exe/ghidra/scripts/reorganize.py <split-tree>` reorganizes a renamed tree into
readable folders and file names:

- **Topic folders** (string-derived): `network`, `ui`, `save`, `campaign`,
  `building`, `images`, `audio`, `resource`, `fileio`, `math`, `weather`,
  `figure`, `debug` — files are `<topic>_<slug>_<addr>.c` where the slug is the
  most distinctive referenced string. Example: `FUN_00500c70` (multiplayer packet
  dispatch) → `network/network_War_War_Complete_Plunder_packet_500c70.c`.
- **`code/`** — functions without distinctive strings stay grouped by 1 MB
  address-module range (`0x040000`…`0x070000`, matching original PE module
  regions), files named `FUN_<addr>.c` (address already unique).
- Regenerates `functions-index.csv`, `strings-index.csv`, `README.md` for the new
  layout; every file header keeps the original `func NAME @ 0xADDR` marker.
- CH: 314 files land in topic folders, 25,770 in `code/`; EN is near-identical.
  These categories are string-derived heuristics, not recovered original modules.

## CH/EN merge (2026-08-12)

`Exe/ghidra/scripts/compare_dumps.py` and `merge_dumps.py` compare the two raw
dumps by address and produce one merged tree (`Exe/ghidra/out/split-merged/`):

- **26,064 of 26,084 CH functions are byte-identical to EN** (CH is a repack).
  These are stored once — no duplicate files.
- **16 functions differ**; both variants are kept as `<name>_ch.c` / `<name>_en.c`
  in the same folder. Nearly all diffs are the **1920×1080 resolution patch**
  (0x400/0x300 → 0x780/0x438 screen constants and derived values, e.g.
  `FUN_52b910_ch/en`), plus one font-weight change (`0x6c28a0`) and minor
  register/local naming differences.
- **4 CH-only functions**: the CH packer stub chain (`FUN_7a8c38`, `FUN_7a8c9f`,
  `FUN_53b446`, and the CH `entry`), stored once with `_ch`.
- The differing-address report lives at `out/compare-report.tsv`.

Regenerate: `merge_dumps.py decompiled-ch.c decompiled-en.c merged.c`, then the
usual pipeline `split_decompiled → rename_vars → reorganize → name_functions →`
`regenerate_indexes` (all under `Exe/ghidra/scripts/`).
