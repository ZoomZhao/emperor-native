# Repository Instructions

## Product mission

This repository is a native macOS reproduction of the original application 《皇帝：龙之崛起》. For every player-facing flow, fidelity to the original application is the product requirement: reproduce the same composition, assets, density, states, feedback, interaction order, and simulation-visible consequences. Do not reinterpret the game as a modern city-builder UI.

The repository-root `DESIGN.md` is the normative visual and interaction specification. Read it in full before changing any player-visible UI, including SwiftUI views, AppKit bridges, layout, styling, colors, typography, icons, animation, assets, copy hierarchy, loading/empty/error states, cursors, placement feedback, or accessibility presentation.

## Evidence and reference material

Use evidence in this order:

1. Runtime assets and authored data under repository-root `GameData`.
2. Undistorted original screenshots and measured original-resource geometry.
3. Observable original behavior, including the local reference video described in `DESIGN.md`.
4. macOS compatibility and accessibility requirements.
5. Explicitly marked temporary fallbacks.

The local video `local/BV1uau26gEVV.mp4` is a behavioral reference, not a runtime dependency. It shows a `1920 × 1076` HD/widescreen distribution: the city view expands the visible map while pinning the classic control panel to the far right, and fixed-art front-end screens may be rescaled or cropped. It also includes a Bilibili watermark. Use it to verify screen order, tool selection, placement previews, map movement, transient messages, and simulation feedback; do not replace this repository's verified `1024 × 768` geometry or derive canonical typography, colors, or assets from the patched/compressed capture. Do not reproduce overlays, watermarks, capture artifacts, or uploader-added material. Do not commit extracted frames unless the user explicitly requests a checked-in reference set.

The extended playthrough `local/BV1W4411971F_p2.mp4` supplements that evidence with a complete mission run. Use it specifically for the two-stage farm-then-fields workflow, field tending range/capacity feedback, the distinct feng shui overlay, the upper-left rectangular building inspector, and the centered rectangular victory result. Its source, hash, duration, limitations, and timestamp index are normative in `DESIGN.md`; it remains local evidence only and must not become an application or test dependency.

When evidence is incomplete or conflicts, record the source, state, timestamp or screenshot name, asset archive and image ID, and the remaining inference. Never present a guess as confirmed original behavior.

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
- Put semantic original-interface image mappings in `Sources/EmperorCore/InterfaceSpriteCatalog.swift`; put building and figure mappings in their existing catalogs. Do not scatter unexplained archive IDs through individual views.
- Prefer an existing classic component and interaction pattern before adding a new player-facing pattern.
- Constrain fixed-width children explicitly. SwiftUI intrinsic size, translated Chinese, tooltips, VoiceOver labels, and test identifiers must not widen or rearrange the `224px` panel.
- Original game files remain read-only under `GameData`. `scripts/package-app.sh` copies that tree into bundle Resources so installed builds can launch without a developer path.
- Reference screenshots and video are development evidence only; packaged code must never depend on `local/`, `/Users/.../Downloads`, or another machine-specific path.
- If a UI task intentionally changes the design system, update `DESIGN.md` and centralized theme/catalog values in the same change, and explain the evidence and deviation. Accessibility, platform security, and functional correctness take priority when they genuinely conflict with a visual rule.

## Required workflow for player-visible changes

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
