# Plan 007: 恢复英雄物理在场生命周期并接通英雄效果

> **Executor instructions**: research-first like plan 006. Recover the
> physical hero figure lifecycle, write the contract, then implement. Do not
> substitute a monotonic set or a timer for the recovered lifecycle. When
> done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 697f8f0d..HEAD -- Sources/EmperorCore/CampaignEmpireSimulation.swift Sources/EmperorCore/GrandCanalSimulation.swift Sources/EmperorCore/CitySimulation.swift`

## Status

- **Priority**: P1
- **Effort**: M/L
- **Risk**: MED — touches effect math (monument speed, emissary/spy cost)
- **Depends on**: plans/006 (monument factor mapping reused for hero
  presence; not strictly required to start research)
- **Category**: research / correctness / direction
- **Planned at**: commit `697f8f0d`, 2026-08-16

## Why this matters

Hero effects (Xi Wang Mu monument speed doubling, Sun Wukong free emissary,
Sun Tzu halved spy cost) are recovered at the effect-math level but fail-closed
in Native because `activeHeroIDs` is a monotonic `Set<Int>` with no physical
figure lifecycle. Until a physical hero presence contract exists, monument
timing and diplomacy costs cannot match the original.

## Current state

- `Sources/EmperorCore/CampaignEmpireSimulation.swift:159,177,294-307` —
  `activeHeroIDs: Set<Int>`; `insert` on homage/arrival; used by
  `LibraryModel.swift:1556` to pick the first hero for UI. No removal path
  (no death/dismiss/load-clear), no slot exclusivity.
- `Sources/EmperorCore/GrandCanalSimulation.swift:2227-2237` —
  `xiWangMuHeroEffectID = 3` and `xiWangMuDispatchLimits` exist, but the
  effect is not wired to a physical presence source.
- `docs/exe-research/hero-effect-lifecycle.md` — recovered: 12-record
  `cHero` layout, slot-0 live-effect enter/exit chain
  (`FUN_005A8370 → FUN_005A7440 → FUN_00510C70 → FUN_00510F50`), slot
  selection (`FUN_00510E30`), clear on dismiss/death (`FUN_00514470`) and on
  load (`FUN_00535510`), persistence (`FUN_00511EA0`/`FUN_00510E60`).
  `BLOCKED BY UNKNOWN`: Native has no hero figure object, no `+0x134` slot
  stamp, no employer link, no slot exclusivity, no exit transition, no
  load-clear; exact post-load reactivation sequencing unknown.

## Scope

**In scope**: research notes under `docs/exe-research/`; `DESIGN.md` contract;
`Sources/EmperorCore/CampaignEmpireSimulation.swift`;
`Sources/EmperorCore/FigureSpriteCatalog.swift` (hero figure catalog if the
research closes sprite families);
`Sources/EmperorCore/WalkerSimulation.swift` (physical hero walker);
`Sources/EmperorCore/GrandCanalSimulation.swift` (effect wiring);
`Sources/EmperorCore/CampaignEmpireSimulation.swift` (effect costs);
`Tests/EmperorCoreTests/` (new hero lifecycle tests).

**Out of scope**: hero content/campaigns, menagerie species, save-format
version bumps, multiplayer.

## Steps

1. **Research** — recover the post-load reactivation sequencing (what happens
   to a loaded active hero's `+0x20` after `FUN_00535510`) and the complete
   enter/exit/clear rule set, including whether a loaded active hero
   re-enters slot 0 on the first simulation step. Record in
   `docs/exe-research/hero-effect-lifecycle.md` with evidence classes.
2. **Contract** — update `DESIGN.md` with the physical presence contract:
   figure-based hero object, slot-0 exclusivity, enter/dismiss/death/load-clear
   transitions, effect activation/deactivation points.
3. **Implement** — replace the monotonic set semantics with the recovered
   lifecycle (keep `activeHeroIDs` only as a derived projection for the UI).
   Wire Xi Wang Mu limits and emissary/spy costs to the physical presence.
4. **Tests** — hero enter→effect active, dismiss→effect off, death→effect
   off, save/load with an active hero (reactivation per the recovered
   sequencing), slot exclusivity.

## Commands / verification

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Hero tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Hero` | all pass |
| Full tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0, no new skips |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |

## Done criteria

- [ ] Hero lifecycle research recorded with the post-load sequencing closed
      (or explicitly `unknown` with the effect path still fail-closed).
- [ ] Effects (monument speed, emissary/spy costs) activate only from
      physical hero presence.
- [ ] `swift test` exit 0 with new lifecycle tests; `swift build` exit 0.
- [ ] `plans/README.md` row 007 updated.

## STOP conditions

- Post-load reactivation remains `unknown` and cannot be observed with the
  documented runtime/static methods — keep the effect path fail-closed and
  report, do not invent a default ordering.
- Any effect requires a hero content/campaign change not in scope.

## Maintenance notes

- When plan 006's food writer set is revisited, hero model-79 case 4
  (`cHouseInfo+0x36 = 0x5A`) is one of the writers to re-check.
- Keep `activeHeroIDs` as a projection so the UI does not become the source
  of truth.
