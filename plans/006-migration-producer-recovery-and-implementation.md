# Plan 006: 恢复原版自动迁入生产者并解除发布门禁 BLOCK

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. The
> plan is research-first: Phase 1 closes remaining `unknown` evidence; Phase 2
> writes the implementation contract; Phases 3–5 implement and verify. Any
> Phase 1 item that stays `unknown` after the prescribed searches is a STOP
> condition — do not approximate a threshold, probability, factor, or timer to
> "unblock" migration. When done, update the status row in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 697f8f0d..HEAD -- Sources/EmperorCore/MigrationSimulation.swift Sources/EmperorCore/CitySimulation.swift Sources/EmperorCore/WalkerSimulation.swift Sources/EmperorCore/ResidentialUnit.swift Sources/EmperorCore/NativeSaveGame.swift Tests/EmperorGameplayTests`
> If any of those paths changed since 2026-08-16 (planned-at commit `697f8f0d`),
> compare the "Current state" excerpts against the live code; on a mismatch
> treat it as a STOP condition and report.

## Status

- **Priority**: P0 (unblocks the release gate and all positive playthroughs)
- **Effort**: L (multi-session research + implementation)
- **Risk**: HIGH — touches resident/population state, save format, walker
  simulation, and the release gate
- **Depends on**: plans/001 (continuous clock; completed), plans/002 (economy
  loop; subsystems complete, playthrough gated), plans/005 (release gate;
  infrastructure complete, playthrough gated)
- **Category**: correctness / research / direction
- **Planned at**: commit `697f8f0d`, 2026-08-16

## Why this matters

`scripts/release-gate.sh` currently exits 65 because the directed gameplay
gate contains skipped tests. Four positive player playthroughs
(`Xia1PlayerPlaythroughTests`, `Xia2PlayerPlaythroughTests`,
`Qin1PlayerPlaythroughTests`, `Qin2PlayerPlaythroughTests`) are skipped with
`BLOCKED BY UNKNOWN: original popularity/factor migration producer is not
implemented`, and the Xia UI-smoke victory leg cannot complete. The root cause
is one system: automatic immigration. Everything else in the tutorial economy
chain (construction, labor, logistics, market, housing evolution, victory
goals) already has passing tests. Restoring the original producer makes the
game naturally playable and turns the release gate green without weakening it.

## Current state

### Native files

- `Sources/EmperorCore/MigrationSimulation.swift` — the entire migration
  surface. `AutomaticMigrationAvailability` has exactly one case,
  `unsupportedOriginalProducer`; `DeterministicMigration.observeHousing`
  (lines 100–130) only counts road-adjacent vacancies and never changes
  residents. This is a temporary observer, explicitly **not** a recovered
  mapping of original `house+0x24`.
- `Sources/EmperorCore/CitySimulation.swift:3670-3677` — the daily tick calls
  `DeterministicMigration.observeHousing` then
  `migration.recordUnsupportedDay(assessment:)`, which zeroes all counters.
- `Sources/EmperorCore/CitySimulation.swift:22` — `struct ResidentialUnit`
  (location, residents, house level, supplies). There is **no** vacant-house
  lifecycle: building IDs 2 (Vacant House) and 11 (Unocc Elite) have no
  `ResidentialUnit` representation, and no `2→3` / `11→13` arrival switch.
- `Sources/EmperorCore/WalkerSimulation.swift` — deterministic walkers with
  `figureID`, movement modes, patrols, and save state. Immigrant figure `#11`
  has no walker type today.
- `Sources/EmperorCore/NativeSaveGame.swift` — versioned JSON; new fields use
  optional backing so format-v1 saves keep decoding (see
  `CitySimulation.swift:221-249` optional-storage pattern).
- `Sources/EmperorGameplay/PlayerCommand.swift` /
  `Sources/EmperorGameplay/GameSessionController.swift` — the single player
  command boundary used by UI and tests.
- `Tests/EmperorGameplayTests/Xia1PlayerPlaythroughTests.swift:83-84` (and
  the Xia2/Qin1/Qin2 siblings) — `XCTSkip("BLOCKED BY UNKNOWN: …")`; the
  release gate greps test output for `skipped|XCTSkip` and fails.

### Recovered original contract (read these before any code)

`docs/exe-research/migration-popularity-producer.md` is the source of truth
and was updated 2026-08-16 (§10). Key confirmed facts, in order of use:

1. **Calendar cadence** (§1): the assignment pass runs on day-ticks (calendar
   case `0x17`); the original month is 816 simulation steps; a 2-cycle
   cooldown is two day-ticks.
2. **Popularity** (§2): `DAT_0130F974` init 60, clamp 0…100, updated at slice
   0 and 8 each month with sum
   `feng + repression + 1 + monument×2 + debt + food + wage + employment +
   tax` and the documented damping bias table.
3. **Factor formulas** (§3): tax/wage/employment/feng-shui tables are
   recovered; `FUN_00590F30` food walk is recovered (`cMarket+0x2c` @
   `0x5437B0` is the recovered normal market-delivery writer of
   `cHouseInfo+0x36`; complete writer set not proven; mill visit `+0x2c` is a
   `ret 0` stub; the `cStall+0x260` blend/store into `cMarket+0x180` is
   recovered; mill-pickup cart `figure+0x13` is the mill `+0x2E4` selected
   recipe type-count, and the player-facing quality name / Native mapping
   remain open). `FUN_0055AE30` monument-object walk is recovered (matching
   building-goal pair count, ×2 in the popularity sum), but Native percent /
   object-vector / `goal+8` save mapping is not.
4. **Pressure and requests** (§4): `FUN_005917E0` pressure bands
   `<16→-25, 16…25→-17, 26…35→-8, 36…49→0, 50…60→50, 61…70→75, ≥71→100`;
   population > 199999 zeroes pressure; war count ≥ 4 suppresses positive
   pressure; request `ceil(12*abs(pressure)/100)`; 2-cycle cooldown.
5. **Assignment vs occupancy** (§5): `FUN_004ADA10` walks houses with
   `house+0x24 > 0`; spawns figure `#11` via `FUN_004ADE10` (state 6, links
   `house+0x32`); **does not** increment residents at spawn. `DAT_01311FB0`
   and `DAT_01311FCC` are assignment accounting, not arrival success.
6. **Arrival state machine** (§5.2–5.3): type `0xB` think is `FUN_004C9FD0`;
   states `6→7→8`; arrival at `0x4CA265` does
   `house+0x20 += (uint8)figure+0x6e`, recomputes `+0x22`, calls
   `FUN_00591900` (city population), then always clears `house+0x32`. Empty
   houses first convert type via `+0x230`: arg `3` for common (`FUN_005188F0`
   true → `(house+0x14,+0x16)=(3,0)`), arg `0xD` for elite (`→(13,10)`).
7. **`DAT_00D62408`** (§10, 2026-08-16): no static writer in EN or CH; always
   `0`; the `+0x230` skip branch is unreachable — Native may convert
   unconditionally.
8. **`house+0x24`** (§5.7, §10.4): a `DAT_01391FE0` flood snapshot refreshed
   from the land-entry seed (`DAT_00C5CDFC/CDFE`, calendar case `0x15` →
   `FUN_004ACFC0` → `FUN_005AE140`). The pass predicate was **recovered
   2026-08-16 by disassembly** (§10.4): 4-neighbour expansion N/E/S/W,
   neighbour passes iff `mainRouteCache16[neighbour] & 0xB7C != 0`, depth
   `n+1`, where `mainRouteCache16` is the same `DAT_013789C0` cache Native
   already derives for the Grand Canal. Native mapping must still verify its
   cache derivation bit-identical to the recovered write domain before
   wiring; it must not use road adjacency.
9. **`cHouseInfo+0x3C`** (§5.9, §10.3): nonzero skips the occupancy add and
   also gates the `FUN_00519060` / `FUN_00519F30` type-switch path; original
   semantic name, complete writer set, and Native mapping are unknown.
10. **`DAT_01311FD0`** (§6): init-zero and save/load closed; **not** a
    producer input; gameplay writer and nonzero-state source unknown; Native
    must not force it to 0 to enable migration.
11. **`DAT_01312564`** (§9): war figure count, incremented/decremented by
    `FUN_004EBB40` for figure types `0x3A…0x3E`, `0x4E`; Native military
    figures do not expose this lifecycle yet.

`docs/exe-research/population-advisor-housing-capacity.md` §7 documents the
zero-capacity advisor composition and the group-55 rows that may be selected.

### Repository conventions that apply

- Core state is `Sendable + Hashable/Codable` value types; new state uses
  optional backing fields so old saves decode (`CitySimulation.swift:221-249`).
- Player-visible behavior must be evidence-backed and recorded in
  `docs/exe-research/` before implementation (repository `AGENTS.md`,
  source-first gate). Research conclusions classify
  `confirmed` / `inferred` / `unknown`.
- Tests assert original constants, never implementation copies. The release
  gate bans state injection (`admitResidents`, `addHouse`, goal snapshots,
  `assignedWorkers`, etc.) via `scripts/release-gate.sh` patterns.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Core migration tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MigrationSimulationTests` | all pass |
| Playthrough tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Xia1PlayerPlaythroughTests` | runs **without** skip (after Phase 5) |
| Full tests | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` | exit 0, 0 skipped |
| Release gate | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/release-gate.sh` | `release-gate: PASS` |
| Build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build` | exit 0 |
| Corpus search | `rg '<pattern>' local/source/split-merged` | as noted per step |
| Exe byte scan | read-only Python over `Exe/ghidra/input/EmperorEN.exe` (methodology in `docs/exe-research/migration-popularity-producer.md` §10) | documented hits |

## Scope

**In scope (research phase)**:
- `docs/exe-research/migration-popularity-producer.md`
- `docs/exe-research/population-advisor-housing-capacity.md`
- `DESIGN.md` (only to record the implementation contract, Phase 2)
- read-only inspection of `local/source/split-merged` and the hash-identified
  executables (never copied into the repo)

**In scope (implementation phase, only after Phase 1 closure)**:
- `Sources/EmperorCore/MigrationSimulation.swift`
- `Sources/EmperorCore/CitySimulation.swift`
- `Sources/EmperorCore/WalkerSimulation.swift`
- `Sources/EmperorCore/DeterministicTerrainState.swift` (flood snapshot, if
  needed)
- `Sources/EmperorCore/NativeSaveGame.swift` (optional-backed fields only)
- `Sources/EmperorCore/OriginalEventMessageCatalog.swift` (no — out of scope,
  see plan 008)
- `Sources/EmperorNative/ContentView.swift` / `ClassicTextLocalization.swift`
  (advisor rows only, exactly the rows authorized by
  `population-advisor-housing-capacity.md`)
- `Tests/EmperorCoreTests/MigrationSimulationTests.swift`
- `Tests/EmperorGameplayTests/Xia1PlayerPlaythroughTests.swift` and the three
  sibling playthrough files (remove the `XCTSkip` only when the producer is
  supported)

**Out of scope**: hero lifecycle (plan 007), event messages (plan 008),
Great Wall first-playable state, real-time fire spread, network scenarios,
any change to victory goals or mission data, any direct resident/inventory/
worker injection, any new debug UI.

## Git workflow

Branch `advisor/006-migration-producer` (repo convention: `advisor/NNN-slug`,
see `git log --oneline -10`). Commit per phase with conventional messages
(e.g. `docs: record migration flood predicate recovery`,
`feat: wire immigrant figure #11 arrival state machine`). Do not push unless
the operator asks.

## Steps

### Phase 1 — close the remaining evidence (research, read-only)

Each sub-step below must end by recording the result in
`docs/exe-research/migration-popularity-producer.md` (a dated section),
including the evidence class and the negative searches performed. Do not
start Phase 2 until every item is `confirmed` or explicitly `confirmed`
negative with the caveat recorded.

#### 1a. Flood pass predicate — **closed 2026-08-16**; Native cache verified
**with a recorded ferry divergence**

The predicate is recovered and recorded in
`docs/exe-research/migration-popularity-producer.md` §10.4: 4-neighbour
flood N/E/S/W from the authored land-entry seed, neighbour passes iff
`mainRouteCache16[neighbour] & 0xB7C != 0` (`mainRouteCache16` =
`DAT_013789C0`, the same cache Native derives for the Grand Canal). Your
task is the follow-up gate, **partly done on 2026-08-16**:

- Read §10.4, then locate Native's main 16-bit route-cache derivation
  (the `WorkerRoutingCache` implementation used by the canal work in
  `Sources/EmperorCore/GrandCanalSimulation.swift` and
  `Sources/EmperorCore/CitySimulation.swift`).
- Write a focused test that asserts the Native cache word per cell matches
  the recovered write domain (`1/2/4/0x10/0x20/0x80/0x100/0x400/0x1000/
  0x4000` plus ferry `0x200/0x800`; `0x8` has no producer in this build) on
  a real map fixture (Haunxian or a Xia mission map), including ferry and
  elevation cells.
- Record the verification result in §10.4 (add a “Native verification”
  line). If any bit diverges, STOP and report — the mapping stays
  `unknown` and the producer stays fail-closed.

**Status 2026-08-16:** the two tests above are committed to
`Tests/EmperorCoreTests/GrandCanalSimulationTests.swift` and pass on the
Haunxian map (domain containment + `0xB7C` discrimination). The ferry
post-pass is **not wired** in the city grid projection (rule constants exist;
no application site; a placed Ferry throws `missingGenericFootprintPredicate`),
and the ferry connector-chain selection rule at placement is not recovered.
2026-08-16 second pass recovered the mechanisms (§10.9): ferry vtable
`0x7AFE48` (`+0x00` init all-`-1`/count 0, `+0x04` connector computation
via `FUN_005B3670`, `+0x08` post-pass); post-pass ORs `0x800` over the 6×6
`0x81FF18` footprint and `0x200` along the stored connector array `+0x154`
(count `+0x924`); the selection walk is flood-guided (`DAT_01391FE0`) toward
the nearest land. Remaining for a full contract: the walk's exact bounds and
the `0x85DE64` secondary-delta semantics (one more disassembly pass), plus
the placement call path. This is a recorded divergence: `house+0x24` is
exact for ferry-free maps but `unknown` on Ferry maps. **Do not wire the
flood or migration producer until the ferry post-pass and connector-state
contract are recovered and implemented** (tracked in §10.9).

**Verify**: `swift test --filter GrandCanalSimulationTests` passes the two
new tests; §10.4 records the divergence.

#### 1b. Complete writer set and Native mapping of `cHouseInfo+0x36`

Recover the complete writer set of `cHouseInfo+0x36` (known:
`cMarket+0x2c` @ `0x5437B0`; month settlement clear in `FUN_00518690` when
`+0x12 < 1`; cheat `20`; hero model 79 case 4 `0x5A`; mill `+0x2c` is
`ret 0`). Use byte-level scans for stores to `[reg+0x36]` of the
`cHouseInfo` object (methodology like `migration-popularity-producer.md`
§6.2/§10). Determine the player-facing quality name and the correct Native
representation of the `20 * type-count` blend contribution.

**Status 2026-08-16:** writer set narrowed to four sites (market blend
`0x543A09`; settlement zero + cheat `0x14` in `FUN_00518690`; `0x5A` at
`0x515259`), recorded in §10.5 with the house-`+0x36` red herrings
discriminated. The food factor contract is **closed** (§10.10): the byte is
a 0–100 raw value in Native's own `0/20/30/50/70/90` units; the
player-facing names are the `FUN_00545100` bands; the house stock word
(`+0x12` slot 0), monthly depletion `(residents*25)/100`, market quality
`+0x180` stall blend (`20*type-count`), and the five-ratio delivery blend
are all specified. Completeness of the writer set remains `inferred`
(§10.5). The remaining work is **implementation** (Phase 3/4): make
`ResidentialUnit` carry the stock word + raw quality byte with the recovered
depletion/delivery cadence, replacing the current non-isomorphic fields.

**Verify**: §10.10 records the contract; the food factor stays fail-closed
until the Phase 3 isomorphism lands.

#### 1c. Native mapping of `FUN_0055AE30` monument factor

Map the recovered walk to a Native percent: live `building+4` 1 vs 3, the
index-0 skip, `building+0xB4` list-index lifecycle, the type-2 object vector
`DAT_012A4BA8`, and `goal+8` save/load. This requires either runtime
tracing or a new save-format walk; record the result.

**Status 2026-08-16:** mapping contract **closed** (§10.8). The `≥ 100`
part-weight test is exactly the completion test, so Native's per-family
`isComplete` flags are isomorphic; `CampaignMissionGoal` already exposes
type-2 monument goals (`kind == .monument`, `buildingID = values[0]`).
Implementation contract: `monumentPopularityTerm(goals:aesthetics:)` =
`2 × matching (goal, complete root) pairs`, fresh each update, with unit
tests for 77 / 82 / 83 / wall-85 and multi-root counting. The remaining
implementation-time assertions are the exact legacy monument ID set and the
Great Wall layout-root enumeration.

**Verify**: §10.8 records the contract; the Phase 3 implementation adds
`monumentPopularityTerm` with the §10.8 tests.

#### 1d. War figure lifecycle for `DAT_01312564`

Identify how Native military figures can expose the increment/decrement
contract (`FUN_004EBB40`, figure types `0x3A…0x3E`, `0x4E`) so the
`war count ≥ 4` pressure suppression is computable from Native state.

**Status 2026-08-16:** mechanism confirmed (§10.7): `FUN_004E2560` is a pure
type gate for {58…62, 78}; `FUN_004EBB40` does `±1` clamped with spawn
(`0x4E199A`, `0x4EA01B`) and death (`0x4C90D7`) call sites; init zero at
`0x4EBBD0`; `FUN_005917E0` suppresses positive pressure when the count is
`≥ 4`. Native mapping candidate: `Σ soldierCount` of alive enemy forces with
`enemyTypeID ∈ {58…62, 78}`, decrement on `.repelled`, keep on
`.cityBreached`. **One open question:** whether original Qin invasions spawn
models 58–62/78 or regional models (6/8/…) — Native currently maps the Qin
Nomad Camps to model 6 (count 0). Verify the invasion figure-model choice
before wiring; if it stays open, record it and STOP the producer contract.

**Verify**: §10.7 records the gate/lifecycle; the invasion-model question is
either closed (with a source) or recorded as the 1d blocker.

#### 1e. `cHouseInfo+0x3C` and `DAT_01311FD0` final disposition

Confirm the `+0x3C` gate's complete writer/lifecycle set or explicitly
record it as an always-zero/never-set gate with the same caveat as
`DAT_00D62408`. Re-run the `DAT_01311FD0` negative search if any new
evidence appeared; record the outcome. These two do **not** block the
producer math (per §6/§10), but their Native disposition must be documented
before the contract is written.

**Status 2026-08-16:** `cHouseInfo+0x3C` lifecycle **closed** — setter
`FUN_004681A0` (`+0x3C = 2`, armed via the single direct caller
`FUN_00468420` = resident-removal/eviction path), 32-step countdown
`house+0x98`, daily clear `FUN_005185C0`; recorded in §10.6. Native must add
the settling-lock byte + countdown and skip the arrival write while
nonzero. `DAT_01311FD0` remains as documented (§6): not a producer input,
no writer, init-zero; no new evidence appeared.

**Verify**: §10.6 exists with the setter/clearer addresses; the arrival
contract in Phase 2 includes the settling-lock gate.

### Phase 2 — write the implementation contract

Once Phase 1 is closed, update `DESIGN.md` (the “自动迁入生产状态” paragraph)
and the research note with a precise contract: inputs (popularity factors,
pressure, war), state transitions (assignment → spawn → walk 6→7→8 →
arrival write), constants (init 60, clamp, bands, cooldown, request ceiling),
resource/object IDs (figure `#11`, vacant building IDs 2/11, `house+0x20` /
`+0x22` / `+0x32`), save/replay consequences (new optional-backed fields),
and the remaining exemptions. Determinism: the original RNG is not used for
migration; the recovered formulas are deterministic — preserve the exact
band/ceiling/clamp structure.

**Verify**: `git diff DESIGN.md` shows only the contract paragraph; every
number in it is traceable to the research note.

### Phase 3 — Native vacant-house lifecycle and immigrant walker

1. Add a vacant-house representation for building IDs 2/11 and the arrival
   type-switch `2→3` / `11→13` (the `+0x230` contract) inside
   `ResidentialUnit` / `CitySimulation`. `houseLevelID` 0 ↔ model 3
   (Shelter House), 10 ↔ model 13 (Modest Elite) is the confirmed
   relationship; do not extrapolate it to other levels.
2. Add figure `#11` (immigrant) as a deterministic walker in
   `WalkerSimulation.swift` following states 6→7→8 with the recovered
   movement/timing contract; the walker must be persisted and resumed on
   save/load (do **not** fold travel into instant occupancy).
3. At arrival, perform the `0x4CA265` occupancy write (`house+0x20 +=
   figure+0x6e`), capacity recompute, `FUN_00591900` population effect, and
   `house+0x32` clear — through a core function, never through the UI.

**Verify**: `swift test --filter MigrationSimulationTests` passes new tests
for vacant conversion, walker states, arrival write, and save/load mid-walk;
`rg -n 'admitResidents' Sources/EmperorNative` has no production call.

### Phase 4 — popularity/request/cooldown producer

Implement the recovered producer (popularity init/clamp/update with the eight
factors from Phase 1 mappings; pressure bands; request ceiling; two day-tick
cooldown; `DAT_01311FB0/FCC` accounting semantics; month rollover). Wire it
into the daily tick at the calendar `0x17` position and the month rollover at
the documented cadence. Keep group-55 row 10/11 selection fail-closed until
the advisor rows are authorized by the mapping.

**Verify**: `swift test --filter MigrationSimulationTests` covers init,
clamp, every pressure band boundary, cooldown, rollover, and save/replay
identity; counters follow the assignment-accounting semantics (not arrival
success).

### Phase 5 — re-enable playthrough tests and the release gate

1. Remove the four `XCTSkip` blocks only after the producer is supported and
   the playthroughs complete within their time bounds.
2. Re-run the fixed command tables; update only command coordinates if the
   map checksum is unchanged and placement feedback demands it — never inject
   residents, workers, inventory, goals, or outcomes.
3. Re-run the full gate including the UI smoke if Accessibility permission is
   available.

**Verify**: `./scripts/release-gate.sh` prints `release-gate: PASS`;
`swift test` reports 0 skipped; `git status --short` lists only in-scope
files plus `plans/README.md`.

## Test plan

- `MigrationSimulationTests` (new cases): vacant type conversion; figure `#11`
  spawn/state 6/7/8; arrival occupancy write and population effect;
  assignment accounting vs arrival; every pressure band; request ceiling;
  two-tick cooldown; month rollover; mid-month save/reload identity;
  old-save optional-field migration (defaults to unsupported, zero counts).
- `Xia1PlayerPlaythroughTests` / siblings: restore the fixed command tables;
  assert victory once, no injected state, and the same economic-chain
  evidence as before the block.
- Existing patterns: `Tests/EmperorCoreTests/MigrationSimulationTests.swift`
  and `Tests/EmperorGameplayTests/Xia1PlayerPlaythroughTests.swift` before
  the `XCTSkip` at line 83.

## Done criteria

- [ ] `docs/exe-research/migration-popularity-producer.md` has a dated Phase 1
      closure section covering 1a–1e with evidence classes; no item left
      `unknown` except explicitly recorded non-blockers.
- [ ] `DESIGN.md` contract paragraph updated and consistent with the note.
- [ ] `swift test` exits 0 with **0 skipped**; new migration tests exist.
- [ ] `./scripts/release-gate.sh` exits 0 with `release-gate: PASS`.
- [ ] `swift build` and `swift build --product emperor-ui-smoke` exit 0.
- [ ] No state-injection strings match the release-gate banned patterns.
- [ ] `plans/README.md` row 006 marked `DONE`; rows 001/002/005 unblocked.

## STOP conditions

- Phase 1a's Native cache verification fails (any cache bit diverges from
  the recovered write domain) — the `house+0x24` mapping stays `unknown`.
- Phase 1b–1d any item remains `unknown` after the prescribed searches.
- A factor, threshold, probability, cooldown, or field is needed but not
  directly supported by the recorded evidence (do not invent or borrow from
  another city-builder).
- The flood predicate in 1a turns out not to be expressible from Native state
  (e.g. depends on unmodeled map-entry semantics).
- Any test can only pass by injecting residents/inventory/goals or disabling
  housing evolution / public safety.
- Old save files cannot decode without a format-version migration.
- An in-scope file's current code no longer matches the excerpts above.

## Maintenance notes

- The recovered formulas must stay in `docs/exe-research/` as the contract;
  production code and tests must not restate them as separate truth.
- When hero effects (plan 007) land, the food writer set (Phase 1b) may gain
  the hero model-79 store — re-check the writer set there.
- If the game later adds real-time fire (plan 008/005 split), the monthly
  granularity of maintenance does not interact with migration; keep the two
  paths separate.
- Reviewers should scrutinize that `DAT_01311FCC` remains assignment
  accounting, that no `admitResidents` call appears in production paths, and
  that the advisor renders only rows authorized by
  `population-advisor-housing-capacity.md`.
