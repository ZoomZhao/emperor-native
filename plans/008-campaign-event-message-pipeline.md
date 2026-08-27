# Plan 008: 恢复战役事件消息短语族与变量绑定

> **Executor instructions**: research-first. The current message pipeline only
> closes fire/collapse; do not render titles/bodies for other event kinds
> until their phrase-family/phase/variable-binding control flow is recovered.
> When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 697f8f0d..HEAD -- Sources/EmperorCore/OriginalEventMessageCatalog.swift Sources/EmperorCore/CityOperationsSimulation.swift Sources/EmperorCore/CampaignCityEventSimulation.swift Sources/EmperorNative/ContentView.swift`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED — message rendering only, but phrase selection is authored
  data and must not be invented
- **Depends on**: none
- **Category**: research / correctness
- **Planned at**: commit `697f8f0d`, 2026-08-16

## Why this matters

Campaign events (requests, invasions, earthquakes, droughts, floods, strikes,
gifts, tribute) alter live city state but currently produce no original
message: `OriginalEventMessageCatalog.buildingFailureMessage` supports only
fire and collapse, and the message panel stays fail-closed for everything
else. Players lose the authored feedback the original game shows.

## Current state

- `Sources/EmperorCore/OriginalEventMessageCatalog.swift` — loads
  `Model/EmperorEventmsg.txt` (GB18030) and exposes
  `buildingFailureMessage(for:playerName:)` for `.fire` / `.collapse` only.
- `Sources/EmperorCore/CityOperationsSimulation.swift:43-44` —
  `BuildingFailureKind.fire` / `.collapse`; `OriginalEventMessageCatalogTests`
  covers those two families.
- `docs/exe-research/event-message-phrases.md` — `confirmed` GB18030 fire/
  collapse titles+bodies, the `0x4985D0` loader, and the `0x4987D0`
  message-category parser; the complete variable-substitution chain, ruler
  fallback, full-vs-condensed preference, sound, auto-open behavior, ordering,
  and lifetime are `unknown`.
- `docs/exe-research/disaster-event-message-pipeline.md` — drought/flood
  phrase families exist in the text file, but the kind-4/5
  phrase-ID writer/selector is `BLOCKED` (no phrase-key strings in the split
  decompilation; numeric-ID load; targeted call-site searches failed).

## Scope

**In scope**: `docs/exe-research/event-message-phrases.md`,
`docs/exe-research/disaster-event-message-pipeline.md`, `DESIGN.md` contract,
`Sources/EmperorCore/OriginalEventMessageCatalog.swift`,
`Sources/EmperorCore/CampaignCityEventSimulation.swift`,
`Sources/EmperorNative/ContentView.swift` (message panel wiring only),
`Tests/EmperorCoreTests/OriginalEventMessageCatalogTests.swift`.

**Out of scope**: event scheduling rules (already implemented), audio,
sound-trigger files, network messages, new message UI patterns.

## Steps

1. **Research** — recover the runtime record→(family, tone, phase) selection
   and the variable-binding chain for at least one non-fire family (start
   with drought/flood kind 4/5, then requests). Search strategy:
   `rg` the `local/source/split-merged/strings-index.csv` for phrase-key
   prefixes (`PHRASE_`), then trace the numeric-ID phrase loader
   (`0x4985D0` family) from the campaign event execution path
   (`CampaignCityEventSimulation`-equivalent in the exe). Record every
   `confirmed`/`inferred`/`unknown` step in the two notes.
2. **Contract** — for each closed family, extend the DESIGN.md message
   paragraph with the exact phrase keys, variable substitutions (including
   `[player_name]` handling and fallback), phase selection, and panel
   behavior. Keep unclosed kinds fail-closed.
3. **Implement** — extend `OriginalEventMessageCatalog` with typed message
   resolvers per closed family; wire the panel to show them only when the
   runtime record supplies the closed inputs.
4. **Tests** — for each closed family: title/body exactness (GB18030),
   variable substitution, unknown-player placeholder behavior, fail-closed
   behavior for unclosed kinds.

## Commands / verification

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Catalog tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OriginalEventMessageCatalogTests` | all pass |
| Full tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0 |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |

## Done criteria

- [ ] At least one non-fire family (drought/flood or request) is closed with
      recorded phrase keys and variable binding; remaining kinds documented
      as fail-closed.
- [ ] `OriginalEventMessageCatalog` resolves closed families from authored
      data; no invented prose.
- [ ] `swift test` exit 0 with new tests; `swift build` exit 0.
- [ ] `plans/README.md` row 008 updated.

## STOP conditions

- The kind→phrase-ID writer remains `unknown` after the targeted searches —
  keep that family fail-closed and report (do not map phrase families by
  name similarity or video text).
- A closed family needs a new UI pattern beyond the existing message panel.

## Maintenance notes

- The loader at `0x4985D0` and category parser at `0x4987D0` are shared; when
  a new family closes, reuse the same typed-resolver pattern.
- Keep the fail-closed invariant: no title/body renders without an authored
  key and a closed variable-binding contract.
