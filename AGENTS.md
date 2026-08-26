# Repository Instructions

## Product mission

This repository is a native macOS reproduction of the original application 《皇帝：龙之崛起》. For every player-facing flow, fidelity to the original application is the product requirement: reproduce the same composition, assets, density, states, feedback, interaction order, and simulation-visible consequences. Do not reinterpret the game as a modern city-builder UI.

The repository-root `DESIGN.md` is the normative visual and interaction specification. Read it in full before changing any player-visible UI, including SwiftUI views, AppKit bridges, layout, styling, colors, typography, icons, animation, assets, copy hierarchy, loading/empty/error states, cursors, placement feedback, or accessibility presentation.

## Evidence and reference material

Use evidence in this order:

1. Runtime assets and authored data under repository-root `GameData`.
2. Read-only behavior and static control flow of the hash-identified original program recorded in `DESIGN.md`.
3. Undistorted original screenshots and measured original-resource geometry.
4. Observable original behavior, including the local reference videos described in `DESIGN.md`.
5. macOS compatibility and accessibility requirements.
6. Explicitly marked temporary fallbacks.

The development-only `local/source/` tree is the current searchable static-control-flow corpus for the hash-identified English and Chinese executables. It contains Ghidra 12.1.2 headless decompilations, raw string tables, a CH/EN comparison report, and a merged per-function tree. Search `local/source/split-merged/strings-index.csv` first for string-led questions and `functions-index.csv` for addresses, then open only the relevant function files. When a function differs, read both `_en.c` and `_ch.c` variants and `local/source/compare-report.tsv`. The English executable (`8a6d2df1…6753`) remains the canonical `1024 × 768` behavior and geometry build; the Chinese executable (`dbdeca1e…15a`) is a repacked widescreen variant useful for cross-checking shared logic and identifying patched constants, not for redefining the classic canvas.

`local/source/` is generated reverse-engineering output, not recovered original source code. Ghidra types and expressions can be imperfect; post-processing renamed local variables and assigned topic folders/file slugs heuristically. Treat function addresses, literal values, referenced strings, branches, and call relationships as static evidence only after checking the relevant callers/callees and authored data. Never treat a heuristic name as an original symbol, copy a decompiled function verbatim into Swift, or cite the presence of C-like output as sufficient proof of original behavior.

For any original behavior or similarly named mechanism, use `local/source/` as the first static-tracing entry point. Start with literal/string searches, then read the indexed function file and its `_en.c`/`_ch.c` counterpart, inspect direct callers/callees and vtable/data-table edges, and check `compare-report.tsv` before using runtime observation. Record negative searches as well as positive findings. Do not launch the original program when the request is scoped to static corpus research; only use a legal local runtime after the corpus is exhausted and the user has explicitly authorized that fallback.

Any reusable conclusion from `local/source/` must be recorded under `docs/exe-research/` before implementation. Record the executable hash/build, function address and variant, relevant callers/callees, constants or resource IDs, corroborating `GameData`/manual/runtime evidence, evidence class, and remaining unknowns. The ignored corpus may be regenerated or absent on another machine, so source code, builds, tests, and packaged resources must never depend on it.

The local video `local/BV1uau26gEVV.mp4` is a behavioral reference, not a runtime dependency. It shows a `1920 × 1076` HD/widescreen distribution: the city view expands the visible map while pinning the classic control panel to the far right, and fixed-art front-end screens may be rescaled or cropped. It also includes a Bilibili watermark. Use it to verify screen order, tool selection, placement previews, map movement, transient messages, and simulation feedback; do not replace this repository's verified `1024 × 768` geometry or derive canonical typography, colors, or assets from the patched/compressed capture. Do not reproduce overlays, watermarks, capture artifacts, or uploader-added material. Do not commit extracted frames unless the user explicitly requests a checked-in reference set.

The extended playthrough `local/BV1W4411971F_p2.mp4` supplements that evidence with a complete mission run. Use it specifically for the two-stage farm-then-fields workflow, field tending range/capacity feedback, the distinct feng shui overlay, the upper-left rectangular building inspector, and the centered rectangular victory result. Its source, hash, duration, limitations, and timestamp index are normative in `DESIGN.md`; it remains local evidence only and must not become an application or test dependency.

When evidence is incomplete or conflicts, record the source, state, timestamp or screenshot name, asset archive and image ID, and the remaining inference. Never present a guess as confirmed original behavior.

For simulation rules, video is supporting evidence only. Read the relevant files under `GameData/Model`, the shipping `EmperorManual.pdf`/`Emperor.chm`, event text, audio tables, figure models, and sprite archives before implementing a mechanic. Numeric thresholds, difficulty scaling, exemptions, random frequencies, damage, and resource IDs must come from those authored sources when available. When those sources expose constants but not control flow, reproduce the behavior in a legal local installation and, if still ambiguous, perform read-only static inspection of the hash-identified original executable recorded in `DESIGN.md`; never add that proprietary executable to the repository, bundle, or tests. Do not infer a numeric rule from elapsed video time or add a deterministic shortcut merely because it resembles one edited playthrough. If the exact algorithm remains unknown, preserve any parsed constants as research evidence, document the missing control flow, and keep the behavior unimplemented instead of presenting an approximation as fidelity work.

Read-only exe findings that later agents must reuse (addresses, negative searches, evidence classes) live under `docs/exe-research/`. For construction-menu `China_Interface` Bbuttons and `buildingID → button base` work, read `docs/exe-research/construction-panel-exe-mapping.md` and `construction-bbuttons.md` before changing `OriginalConstructionButtonSpriteCatalog` or re-scanning the exe. The compact writer/table is recovered; do not regress confirmed direct/shared-family rows to sheet-order guesses.

## Source-first development gate

The project goal is reproduction, not invention. Research is a required part of implementation, not an optional preliminary step. Do not write or modify player-visible behavior until the corresponding original evidence has been located and recorded.

For every gameplay, simulation, UI, input, rendering, audio, campaign, save, or data-parsing change, complete this sequence in order:

1. **Define the exact original state.** Name the original screen, mechanic, building, figure, campaign event, input sequence, or save state being reproduced. Do not begin from a proposed native design.
2. **Search authored data first.** Use `rg` and the repository inspection tools across `GameData/Model`, text tables, campaign/event files, maps, sprite archives, audio tables, the manual, and existing semantic catalogs. Record exact filenames, sections, row IDs, field indices, image groups, dimensions, and constants.
3. **Recover control flow when data is insufficient.** Observe a legal local installation in the same state. If constants are known but their sequencing, branching, random selection, or state transition is not, search the indexed `local/source/split-merged/` corpus before starting a new executable scan. Verify relevant callers/callees and any CH/EN variant difference, then record the binary hash, addresses, expressions, and call relationships under `docs/exe-research/`.
4. **Classify every conclusion.** Mark it as `confirmed` (directly supported), `inferred` (supported by multiple observations but not recovered exactly), or `unknown`. A video impression, genre convention, developer intuition, or behavior from another city-builder is never `confirmed` evidence.
5. **Write the implementation contract before code.** State the original inputs, state transition, output/visual feedback, constants, resource IDs, timing, exemptions, and save/replay consequences. Update `DESIGN.md` when this changes a player-visible or cross-system contract.
6. **Implement only the supported contract.** Parse and consume original data instead of copying magic numbers where practical. Preserve original ordering and causality. Determinism required by native save replay may replace the original random-number source, but it must preserve the recovered range, frequency, selection structure, and distribution.
7. **Verify against the source, not against the new code.** Tests must assert original constants and invariants independently of the implementation. For visible behavior, compare the same pre-action, interaction, and post-action states with original evidence.

Authored city/map archives may be editor snapshots rather than the intended first playable mission state. When an archive's serialized state conflicts with campaign text or goals, do not silently normalize it from design intent. Trace the hash-identified executable's deserializer, post-load hooks, mission-goal lookup, and first simulation/goal-evaluation boundary; record whether the shipped build actually transforms the archive. If no transformation exists, document the shipping data/control-flow conflict and keep Native fail-closed until the first playable state is confirmed by runtime observation or an equally direct original source.

If the necessary data or control flow cannot be found, stop implementation of that behavior. Document what was searched and what remains unknown, then leave the feature unsupported or behind an explicitly named research scaffold. Do not fill the gap with a plausible threshold, timer, probability, resource mapping, UI pattern, batch effect, or “temporary” gameplay rule. A temporary fallback is acceptable only for platform plumbing or presentation that cannot affect gameplay truth, and it must be labeled with its replacement condition.

Every fidelity commit or pull-request description must identify the primary original sources used and list any remaining `inferred` or `unknown` behavior. “Looks like the video” is not completion evidence.

## Player UI contract

- Keep the classic player canvas at a fixed `1024 × 768` logical size. Preserve the `800px` map column and `224px` right control panel; do not introduce responsive reflow inside the canvas.
- Preserve the distinction between the classic player-facing shell and native diagnostic/library surfaces. `NavigationSplitView`, system tables, cards, and other native patterns belong only to diagnostics and development tooling.
- Prefer original sprites, textures, illustrations, cursors, and state frames. Nearest-neighbor rendering is required for original pixel assets. SF Symbols and code-drawn surfaces are temporary fallbacks only when the corresponding original asset has not been identified.
- Treat normal, hover, pressed/selected, and disabled states as distinct original states. Do not simulate the whole system with a generic tint.
- Match original information hierarchy and control density. Do not add permanent labels, cards, toolbars, resource rows, debug controls, or convenience commands to the player canvas when the original has no such element.
- Placement behavior is part of the reproduction: use the real isometric footprint/sprite, green whole-footprint feedback for legal placement, red for illegal placement, continuous road previews, and original-style transient messages. A colored rectangle or modern toast is not an equivalent substitute.
- Keep player actions connected to `GameSessionController`/`PlayerCommand` and real simulation state. UI smoke tests and replays must not inject completed state, residents, service coverage, workers, goals, or outcomes.

## Centralized implementation

- Put shared geometry, fallback colors, typography, and classic/native distinctions in `Sources/EmperorNative/EmperorTheme.swift`, synchronized with the YAML tokens in `DESIGN.md`.
- Put semantic original-interface image mappings in `Sources/EmperorCore/InterfaceSpriteCatalog.swift`; put building and figure mappings in their existing catalogs. Do not scatter unexplained archive IDs through individual views. Construction Bbutton rows recovered through `0x53A760` keep their direct/shared-submenu evidence class from `docs/exe-research/construction-panel-exe-mapping.md`; genuinely unmapped rows remain `unknown`, and sheet/frame appearance alone never upgrades them.
- Prefer an existing classic component and interaction pattern before adding a new player-facing pattern.
- Constrain fixed-width children explicitly. SwiftUI intrinsic size, translated Chinese, tooltips, VoiceOver labels, and test identifiers must not widen or rearrange the `224px` panel.
- Original game files remain read-only under `GameData`. `scripts/package-app.sh` copies that tree into bundle Resources so installed builds can launch without a developer path.
- Reference screenshots, videos, and the decompilation corpus are development evidence only; packaged code and tests must never depend on `local/`, `/Users/.../Downloads`, or another machine-specific path.
- If a UI task intentionally changes the design system, update `DESIGN.md` and centralized theme/catalog values in the same change, and explain the evidence and deviation. Accessibility, platform security, and functional correctness take priority when they genuinely conflict with a visual rule.

## Additional workflow for player-visible changes

Before implementation:

1. Read `DESIGN.md` completely.
2. Name the original screen and state being reproduced.
3. Locate the best screenshot/video interval and original resource family.
4. Identify the fixed region, state variants, input sequence, and visible post-action feedback.

During implementation, preserve stable accessibility identifiers and keyboard workflows used by the UI smoke harness. Keep temporary fallbacks explicit and localizable for later replacement; a fallback must not silently become the new source of truth.

After a material UI change:

1. Build the macOS target with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`.
2. Capture the affected state at exactly `1024 × 768` logical content size.
3. Compare it against an undistorted original screenshot at the same state, preferably with an overlay or pixel diff. Use the video only for behavioral sequencing.
4. Run focused unit/gameplay tests for affected commands and state.
5. Run the covered UI flow: `scripts/xia1-ui-smoke.sh` for the Xia tutorial, `scripts/qin1-ui-smoke.sh` for the Qin baseline, or `RUN_UI_SMOKE=1 scripts/release-gate.sh` when the broader release path is warranted. UI smoke requires macOS Accessibility permission; report clearly if it could not run.

A change is not complete merely because it builds. It is complete when the original-state composition, asset selection, clipping, state frame, interaction sequence, simulation feedback, keyboard behavior, and accessibility semantics have been proportionately verified.
