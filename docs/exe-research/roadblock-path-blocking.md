# Roadblock (`BUILD_ROADBLOCK`, 126) path-blocking control flow

Read-only static inspection of the hash-matched original executables
(`Emperor[EN].exe` `8a6d2df1…6753`, cross-checked against `Emperor[CH].exe`
`dbdeca1e…15a`), shipped `GameData`, and `GameData/EmperorManual.pdf`.
All four recovered addresses are `identical` in `local/source/compare-report.tsv`
(no EN/CH variant divergence). No GameData/`local/` mutation; this static pass
required no screenshot or runtime capture.

## 1. Authored data and manual (evidence class: confirmed unless noted)

- `GameData/Model/EmperorBuildingModels.txt` row 126 = `Road Block`, cost `2`,
  one tile. Neighboring rows 104/105/106 (`0x68/0x69/0x6a`) = `Residential Gate
  4/3/2`, 232 (`0xe8`) = `Residential Gate 1`, 111 (`0x6f`) = Grand Way,
  113 (`0x71`) = Imperial Way, 130 (`0x82`) = City Gate, 231 (`0xe7`) =
  Residential Wall 1, 89/90/91 (`0x59/0x5a/0x5b`) = Residential Wall 4/3/2,
  156 (`0x9c`) = SPECIAL, 161 (`0xa1`) = Ruin.
- **Manual p.37–38** (EmperorManual.pdf) is the normative player behavior
  contract, in short: a roamer who encounters a roadblock *turns away*; a walker
  with a specific destination *passes right through*; a roadblock can make no
  distinction between roamers, so blocking one roamer type also blocks the
  others. The manual names the **peddler** as a roamer ("Peddlers start at a
  market square and roam around your residential areas …") and uses it as the
  roadblock example (preventing a peddler from strolling into the industrial
  sector also blocks inspectors). Supporting framing: p.9 "Roadblocks are placed
  on a road to force a walker to move in a specific direction"; p.26 "place
  roadblocks around your road circuit(s) to prevent walkers from wandering off";
  p.34 Destination Walkers "always use your city's roads to find the shortest
  route", and lists Immigrant/Emigrant/Vagrant/Bandit/Thief/… alongside the
  *Buyers* ("go directly to a … warehouse to pick up …"); p.38 lists the roamers
  (Peddler, Announcer, Diviner, Scholar, Priest, …).
- `EmperorFigureModels.txt` rows 78/79 (`0x4E/0x4F`) = `Enemy's Heroes` /
  `Player's Heroes`; this confirms the `+0x12` "O"/"N" constants seen in the
  decompiler are ASCII renderings of the byte model id, not semantic letters.
- Every figure's `+0x12` byte is the figure **model id** stored as a byte; it is
  the base of the per-model dispatch row `DAT_0084e78c + model * 0x28`
  (`0x4EACD0`) and the `FUN_004ea050(model, …)` creation argument.

## 2. Recovered control flow

### 2.1 Placement validation — `0x46D110` (identical)

`DAT_0088ebdc` = selected building id. Roadblock-specific branches:

- footprint cell loop, building `0x7e` branch (decompiled around line 204–207):
  terrain mask becomes `n3 = terrain & 8` instead of the common
  `terrain & 0xAFFEDE6F`; any set `0x8` bit in a footprint cell sets the
  rejection flag.
- post-loop origin check (line 243–248): the origin (first footprint) cell must
  satisfy simultaneously `terrain & 0x40 != 0`, `terrain & 0x400 == 0`, and
  `DAT_00F2B290[origin] == 0` (road-water auxiliary byte). Any failure → reject.

Interpretation (confirmed placement rule): the block may be placed only on a
plain road tile (`0x40`), never on a `0x400` special crossing, never on a cell
whose occupied-surface marker `0x8` is already set, never on water. This matches
the existing native one-tile road-only placement invariant.

### 2.2 Derived-path caches — roadblock cell is passable (confirmed)

`0x5AD440` (main cache builder), occupied-cell branch, building object id `0x7e`
(explicit case, line 120–123): `DAT_013789c0[cell*2] |= 4` — the same value as a
road tile (write target confirmed as walker main cache by `0x4E8BC0`
`& 0xC`/`& 3` reads and `0x4E83E0` `& 0xB1C` read). The `0x9c` (156) case shares
the `|4` write; `0x6f/0x71` write `0x10`.

`0x5223B0` (fallback/mode-19 builder), switch case `0x7e` grouped with
`0x6f/0x71/0xa1/0xca` (line 104–110): `DAT_01339270[cell] = 2`. Mode-19 mask
`0x4C001CCE` accepts `0x2`, so fallback routing also crosses roadblocks.

Consequences (confirmed): no pathfinder is blocked by a roadblock in either
derived layer; the roadblock keeps the underlying road traversable. Routing that
uses `0x4E83E0` mode 3 / `0x5B0360` / `0x520DE0` treats a roadblock cell exactly
like a road cell. The existing native worker-routing derivation already encodes
`126 → (main 0x4, fallback 0x2)`.

### 2.3 Walker movement collision — `0x4E8BC0` (identical)

Called only from `0x4E7EB0` (the on-road movement micro-step loop); decides
whether the figure may step into the Next cell `idx2`. On denial it stores
direction `9` in figure `+0x19` (the original "blocked / turn" marker; direction
values `< 8` are real directions). The switch dispatches on figure `+0x20` raw
state:

- states `0x08/0x0A/0x0C/0x02/0x13/0x10`: consult `FUN_005221a0` (fallback-based
  per-mode class test). For a roadblock cell (fallback `2`) every reached mode
  path returns `0`, so these states pass roadblocks.
- state `0x09`: `main[idx2] & 3 == 0` → pass; roadblock main `4` → passes.
- state `0x0E`: `main[idx2] & 0xC != 0` → pass; roadblock main `4` → passes.
- state `0x15` / `0x04` / `0x06`: no roadblock relation recovered.
- **default (all other raw states)**: the road/gate/roadblock collision:
  - Branch A (Next cell without `0x40/0x400`): requires `terrain & 0x8`, then a
    building object at Next; building `0x7e`, Residential Gates
    (`FUN_00415770` = `{104,105,106,232}`), or City Gate `0x82` → shared label
    `LAB_004E90AD`.
  - Branch B (Next cell with `0x40` or `0x400`, i.e. a road-family surface):
    gate guard `DAT_01032664 == 0 → pass`; `local_4 == 0 → pass`;
    `terrain & 0x8 == 0 → pass`; building `0x7e` / gate family / `0x82` →
    `LAB_004E90AD`.
  - `LAB_004E90AD`: `if (figure.+0x12 == 0x4F) pass else block`.
- Non-roadblock occupancy generally passes Branch B; a hero (model 79,
  Player's Heroes) passes roadblocks and gates; every other figure model is
  denied (direction `9`).

Meaning of `DAT_01032664` (a global movement-context flag), by evidence level:

- `confirmed`: the only write that sets it to `1` is in `0x4E6D80`, guarded by
  the figure's `+0x4E` byte being `0` (see `FUN_004e6d80.c`).
- `confirmed`: `0x4E7EB0` (the on-road movement micro-step loop that calls
  `0x4E8BC0`) clears it to `0` in two sites: on entering with zero steps left,
  and on an early block exit (figure direction `+0x19 > 7`).
- `confirmed`: `0x4E47A0` is a per-state movement dispatch FSM that calls
  `0x4E7EB0` for path-following targets (`FUN_004e47a0.c`) and does not itself
  set the flag.
- `inferred`: targeted/path-updating movement normally reaches `0x4E8BC0` with
  the flag cleared and therefore passes Branch B. The manual independently
  confirms the player-visible destination-walker pass contract.
- `inferred`: the exact value a figure inherits across consecutive figure
  updates inside one outer simulation step is not fully closed (a pass over one
  figure is only guaranteed to clear the flag when it completes or exits early,
  so a partially processed `0x4E6D80` pass could still leak a `1` into the next
  figure's `0x4E47A0`/`0x4E7EB0` steps). This does not change the behavioral
  contract that roamers turn at roadblocks and destination walkers pass.

### 2.4 Place-carve relation (inferred but forced)

`0x46D110` requires footprint `0x8 == 0` before placement and building carve
writes `terrain |= 0x8008` (`0x4F9570` single-tile path) or
`(terrain & 0x93872790) | 0x8008` (`0x4B72B0`). For the roadblock to be a Branch
B cell (keeps `0x40`, gains `0x8`) the single-tile OR path must be used: this is
the only reading consistent with the manual's "destination walkers pass", since
Branch A (which clears `0x40`) has no `DAT_01032664` guard. The roadblock's
footprint-table bit (`p3[2]&1` vs `&2`) was not re-recovered; classification:
`inferred` (consistent with both placement rule and the p.37–38 contract).

## 3. Evidence classification

- `confirmed` (authored): manual p.37–38 roam-turn/destination-pass contract,
  plus p.9/p.26/p.34 framing; building-model rows 126/104–106/232/111/113/130/156;
  figure-model rows 78/79; gates/way rows used by the predicates.
- `confirmed` (identical CH/EN decompilation): placement mask/origin rule
  (`0x46D110`); main-cache `4` for 126 (`0x5AD440`); fallback `2` for 126
  (`0x5223B0`); movement-collision Branch A/B + `LAB_004E90AD` model-79 gate and
  `DAT_01032664` guard (`0x4E8BC0`); `DAT_01032664` set/clear sites
  (`0x4E6D80`, `0x4E7EB0`) and roamer-loop behavior; predicate
  tables `FUN_00415770` / `FUN_00415700` / `FUN_00562F70` (monuments) /
  `FUN_004C11B0` (trees/farms); `0x4EACD0` model-byte dispatch row stride.
- `inferred`: roadblock uses the single-tile OR carve (keeps `0x40`, gains
  `0x8`); `DAT_01032664` precise per-step inheritance edge cases; the exact set
  of `+0x20` raw states used by Native's non-represented walker classes.
- `unknown`: no runtime capture confirms the visual "turn around" pose; the
  `FUN_00431BB0`-style second-byte (`DAT_013789c1`) interactions with census /
  camps; gate-state animation coupling for 130/104–106/232.

## 4. Native contract for implementation

1. Roadblock is placed only on an existing plain road tile; footprint `0x8` and
   water-aux must be clear. Native centralizes this in
   `DeterministicTerrainState.canPlaceRoadBlock(at:)`; the predicate verifies
   the authored `0x40` road bit, while `roadNetwork.contains` also verifies
   Native's logical road membership.
2. A roadblock tile remains part of the road network and of every derived
   routing layer (main `4`, fallback `2`); destination/path-following movement
   (grand-canal laborers/carts, logistics delivery wagons, market **buyers**,
   convoys) crosses it.
3. Roaming walkers — Native `RoadServiceWalker` patrols and market **peddler**
   routes — must not enter a roadblock tile; schedule-time routing treats the
   tile as closed, and service coverage reachability stops there. Peddlers keep
   Native's pre-existing deterministic household-delivery approximation when
   it can build a route, with roadblocks added only as impassable points; its
   fallback patrol uses `DeterministicRoadPatrol.route`. The exact original
   roaming branch-selection algorithm remains `unknown`, so this change does
   not claim that Native's route shape is original. Roamers get no roadblock
   exemption.
4. Mid-flight boundary: a service walker or peddler already roaming when a
   roadblock appears refuses the blocked step and stays in place in front of
   it; it is neither auto-completed nor auto-rerouted, and peddler cargo is
   neither returned nor lost. Removing the barrier lets the stored route
   continue. The original post-collision reroute (`0x4E71D0` block counter /
   reverse direction) is marked `unknown`, so Native deliberately leaves the
   walker held instead of inventing back-tracking. This is a research boundary,
   not a claim that the hold reproduces the complete original turn behavior.
5. Player-visible help text already states the manual contract ("阻止漫游人员，
   放行采购、运输和移民"); no text change is required.
