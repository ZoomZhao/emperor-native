# Emperor Native

`Emperor Native` is a clean, native macOS reimplementation of **Emperor: Rise of the Middle Kingdom**.
Extract the original game tree into repository-root `GameData` for local development; packaging copies the
same tree into the app bundle so an installed build can launch directly. A legacy wrapper install remains a
fallback when present.

The current **1.0.0** milestone delivers a save-compatible native campaign platform and a locally packaged
macOS application.

## Verified playability scope

The release gate now proves that the original Xia tutorial mission 0, “Shelter and Sustenance”, can be
started from its shipping data and completed in a bounded replay using only player-visible commands. The
fixed replay builds roads, houses, a hunting camp, mill, common market, wells, ancestral shrine and inspector
tower; it then observes natural migration, workforce assignment, physical meat delivery, market distribution,
all three residential services, housing evolution and a single victory transition. It does not inject
population, inventory, workers, housing levels, goal progress or disabled simulation rules. A missing-market
and broken-road replay is required not to win.

The same mutation boundary is used by SwiftUI and the headless gate. Mission outcomes now have save-compatible
running, victory and continuous-debt defeat states; payroll can create debt, 36 consecutive negative months
cause defeat, and terminal missions pause and offer replay/load/continue/return actions. The first tutorial's
permanent buildings and key walkers resolve to original SG3 sprites with deterministic eight-direction frames.

This evidence applies only to the first Xia tutorial. Other missions retain the parser and deterministic
simulation coverage described below, but are not yet claimed as player-completable vertical slices. The real
Accessibility + CGEvent replay in `scripts/xia1-ui-smoke.sh` passed on 2026-07-24: it selected the shipping
campaign and mission, issued 85 coordinate-verified construction clicks, selected 3× speed and observed the
native victory overlay at population 151. `RUN_UI_SMOKE=1 ./scripts/release-gate.sh` passed with all 121 tests,
the full build and no skipped directed test. The run saves built-city, live-city and victory images plus the
complete command log under `tmp/ui-smoke/`.

## Engine coverage

The engine can:

- locate and validate bundled or local `GameData`;
- index maps, campaigns, model tables, sprite archives and audio;
- decompress Emperor's chunked `.map` and `.pak` containers without Wine;
- parse and render Sierra Graphics V3 (`.sg3`/`.555`) RGB555, RLE and isometric sprites;
- read the centered 228×228 backing grid while preserving each mission's real playable rectangle (for
  example 112×112 at Bo and 140×140 at Anyang), then preview its original terrain;
- detect the differing campaign table layouts used by all 31 installed campaigns and list all 74 missions;
- match maps embedded in campaign containers back to their original `.map` files by exact decoded chunk data;
- decode all 210 original victory goals across the 28 goal-driven campaigns, including MFC runtime-class
  references, while identifying the three open-play campaigns correctly;
- evaluate all 11 goal types against a deterministic campaign snapshot, preserving original yearly
  production units and continuation semantics;
- decode all 948 scripted events from both original Campaign Creator archive versions, including exact
  month, year/amount/product ranges and the one-time, recurring and mission-complete trigger modes;
- schedule original mission events deterministically from a replay seed, including recurring intervals;
- execute the 16 event kinds used by the installed campaigns at the end of the authored city month: cash and
  storage-aware commodity/menagerie gifts, time-limited requests, one-level demand/supply changes, imperial
  price changes, normal-wage changes, invasions, earthquakes, floods, droughts, strikes, city messages and
  city-status mutations now alter live native city state;
- evaluate live victory goals after every monthly settlement, fire mission-complete events exactly once,
  expose request fulfillment and event outcomes in the city UI, and start the next original mission while
  retaining the existing continuation-map treasury rule;
- locate and validate the embedded Campaign Creator empire map in all 20 campaigns that contain one, decode
  all 22 fixed city slots and their nested relationship records, and correctly identify the 11 older/custom
  campaigns that do not embed this section;
- read the original city-name group from `EmperorText.eng`, then expose each active city's real name, land/sea
  route, four goods bought, four goods sold, 12/24/36-load yearly quotas and original prices directly in the
  native campaign browser and native `TradePartner` model;
- bind standard and continuation missions to their exact original scene maps (including continuation chains
  such as Shang mission 7 returning to the map from mission 5);
- decode the Campaign Creator's exact per-mission player-city table, validate each city against its empire
  marker object, and start a selected mission with its real player city and authored trade partners—without
  guessing from filenames such as `Anyang.map` or `Jiangxi.map`;
- decode every campaign's original mission start month/year, base treasury, 57 building-menu permissions
  and 29 resource permissions; apply the original 150%/100%/80% difficulty treasury rule, preserve these
  settings in native saves, and inherit the live treasury when a continuation mission follows its prior city;
- map the Campaign Creator's 56 selectable building permissions back through shipping `EmperorText.eng`
  group 67 to original building-model IDs; hide disabled tools in each mission and enforce the same rule in
  the deterministic core, while keeping raw producers resource-driven and allowing manufacturers to use
  either local inputs or goods sold by an open original trade partner;
- initialize a started mission on the original map's true dimensions, carry its water, trees, rocks,
  construction obstacles and existing roads into the deterministic native/save state, choose new houses on
  clear land beside those roads, and composite the original terrain sprites with simulated buildings and
  walkers in a draggable 32×32 isometric viewport;
- provide native browse/road/house tools directly on that isometric viewport: the same tested projection is
  used for drawing and pointer hit-testing, hover feedback marks legal and blocked diamonds, roads and houses
  are placed at the clicked map coordinate, and terrain obstacles, occupancy, road adjacency, original costs
  and atomic treasury changes are enforced by the saveable core rather than only by SwiftUI;
- place warehouses, mills, common markets, land trading stations, clay pits, kilns and the complete
  housing-service palette directly on the map with the original non-square footprints (including 3×3
  warehouses/stations, 5×5 mills and rotatable 7×4 common markets); preview every occupied tile in green/red,
  choose a deterministic adjacent-road entrance,
  prevent roads, houses and buildings from overlapping, require wells to sit on the original groundwater
  layer, and persist instance-linked geometry without breaking earlier format-v1 native saves;
- demolish a placed building, house or road from the native map with the original half-cost refund;
  remove the matching production, storage, mill, market, trade or residential-service instance in the
  same transaction; cancel linked deliverymen, buyers, peddlers and service walkers; discard demolished
  storage and in-transit cargo; and keep surviving source buildings free of stale active-walker IDs;
- resolve the original `China_General` logical image groups for every native construction tool and render
  the authored clay pit, kiln, mill, well, medicine, tax, entertainment and religion artwork at its real
  multi-tile footprint; assemble warehouses from original storage bays, land trading stations from eight
  bay tiles plus their dedicated office/crane tile, and markets from original paving, food-shop and
  entertainment-area pieces; assemble sea trading quays from the original `China_General` logical group 38
  house/deck sprites for all four water-facing edges; rotate component geometry with its footprint and
  depth-sort every component instead of leaving constructed buildings as colored occupancy markers;
- resolve the original `China_Elevation` global image interval independently of terrain flags, render raised
  ground, cliff faces, stairs and multi-cell slope transitions in both map and city canvases, and keep the
  verified high-ground bit as a native construction obstacle;
- identify and render the map-authored `China_Elevation_dirt`, first Great Wall construction and Grand Canal
  construction layers from their original global image intervals, including large multi-tile source sprites;
- load original building, housing, trade, farm and tax-sentiment model tables into typed Swift rules;
- run a deterministic native city sandbox with original house capacity, construction costs, population,
  tax coverage, monthly settlement and replay-stable transactions;
- build roads atomically at the original per-tile cost and run replay-stable Tax Official walkers over
  closed patrol routes capped by the original figure model's 40-tile movement range; only houses beside
  road tiles actually visited during the month receive tax coverage;
- render all 15 original housing levels and both isometric orientations from `China_General`;
- run both original common and elite housing chains one level per month using the original house model's
  difficulty-adjusted evolve/devolve desirability, water, herbalist, acupuncture, music, acrobat,
  drama, food quality, hemp, ceramics, tea, silk, luxury wares and three religious-access requirements;
- construct the original well, medical, entertainment and religious service buildings, send their original
  figure IDs over deterministic patrols capped by each figure model's range, recompute desirability from live
  buildings, and expose exact upgrade blockers plus monthly evolution/devolution in the native city UI;
- run 20 original industrial recipes with original building/commodity IDs, worker requirements,
  raw-material consumption, progress and pausing;
- move industrial goods physically between located producers, processors and 32-load warehouses using
  original deliveryman ID 22 and its 24-tile range, including 100-unit loads, warehouse accept/get limits,
  multi-month round trips and production stalls while a deliveryman has not returned;
- operate common/grand markets with original shop capacities, marketplace buyers (figure ID 24, range 50)
  and peddlers (figure ID 23, range 60): buyers collect stocked goods from warehouses, peddlers patrol roads,
  and adjacent houses retain and consume hemp, ceramics, tea, silk and luxury wares by resident count;
- route fish, meat and other food commodities into original 32-load mills, calculate Bland/Plain/Appetizing/
  Tasty/Delicious quality from the exact food-type, salt and spices table, then preserve that quality through
  food-buyer bundles, peddler deliveries and per-resident household consumption;
- grow and harvest soybeans, cabbage, millet, rice, wheat, hemp, tea, mulberry and lacquer on the exact
  calendar printed in the original manual; apply the original FarmConfig tending/harvesting limits, minimum
  fertility and arid/normal/humid modifiers, then move each harvest physically to mills or warehouses;
- keep replay-stable February-to-January production and profit accounts from actual industrial batches,
  harvests, tax income, construction spending and trade; feed their best completed year directly into the
  original campaign goal evaluator alongside live population, housing, treasury and trading-partner state;
- operate per-partner trading stations/quays with the original manual's 60-load storage, maximum four import
  and four export goods, 12/24/36-load annual volume levels, 8-load land and 12-load sea visit capacities,
  default Trade.txt prices and physical deliverymen between trade buildings, producers, mills and warehouses;
  choose a collision-free road-adjacent 3×3 origin for every land partner, charge the original construction
  cost and persist the instance-linked geometry; for sea partners, scan the mission terrain for a clear 3×3
  site whose complete edge borders water and whose land side reaches a road, then construct and render the
  matching directional quay rather than applying the land-station rule;
- decode the Campaign Creator's land/sea entry, exit, invasion, disaster and fishing-point fields from every
  original map; route physical caravans and trading junks from those authored points, suppress trade when a
  route is obstructed, and retain moving visitors in native saves;
- allocate the live population across original building employee requirements, pause understaffed services,
  production and trade, accumulate the original fire/damage risks, and let staffed inspector patrols repair
  covered buildings before deterministic fires or collapses remove their complete backing simulation state;
- accumulate disease and crime from the original house-model fields, apply food, water, herbalist,
  acupuncture and watchtower-guard protection, and resolve outbreaks, deaths, theft, lost goods and treasury
  losses as monthly city events;
- apply earthquakes and floods at map-authored disaster points, make drought/flood conditions reduce actual
  harvests, retain messages and city-status changes, and turn campaign invasions into pending defense alerts;
- construct all five original troop-fort types, create 16-soldier infantry, crossbow, cavalry, chariot and
  catapult units from the original figure model, march them over the mission terrain to authored invasion
  points, and resolve replay-stable armor, melee, missile, casualty, morale and breach/repel outcomes;
- paint original city walls, replace a straight five-tile wall span crossed by a road with the authentic
  rotatable 5×3 gatehouse, replace a complete 2×2 wall base with a staffed tower, render the corresponding
  original multi-piece military sprites, treat intact walls/towers as movement blockers and gates as
  passable, and let multiple formations receive one player rally order and fight together with ranged
  opening volleys, tower sentries, siege damage and durable save state;
- execute all 31 Campaign Creator city-status codes against a live empire model, including trade and tribute
  suspension, rebellions, alliances, vassals, conquest, visibility, military/economic state and favor;
  expose emissaries, spies, alliance requests, conquest, animal requests and prepaid hero homage in the
  campaign UI, and feed alliance, conquest, homage and menagerie state directly into victory goals;
- place gardens, small/ornate sculptures, flowering trees, pavilions, ponds, Tai Chi parks and private gardens
  without incorrectly requiring road access; feed their original desirability fields into nearby housing and
  expose per-building five-element feng-shui plus a city harmony score;
- build the Administrative City as its original two 4×4 courts and the Palace as its original two 5×5
  compounds, with rotatable 4×8 / 5×10 geometry and all eight matching `China_General` component sprites;
  require the Palace before requesting menagerie animals from sufficiently friendly cities;
- build labor camps and carpenter, mason and ceramist guilds, then advance tumulus, temple and pagoda projects
  from physical warehouse deliveries of the materials specified by the original manual; completed projects
  automatically satisfy the matching original monument goal and survive native save round-trips;
- start the original Shang campaign's “Start of a Dynasty” on its decoded Bo map, run its authored clock,
  economy, event table and two victory goals through completion, fire mission-complete events exactly once,
  and restore the resulting city and campaign runtime from a native save;
- complete all seven original Shang missions through the same native runtime, including whole-city
  continuation, original monuments, production/profit goals, diplomacy, hero homage and menagerie species;
- catalog all 74 entries in the 31 locally installed campaign packages; start and advance all 62 missions that
  have an original map, including 11 Campaign Creator missions recovered through their exact external `.map`
  references; and classify the remaining 12 one-mission packages as original network scenarios whose lobby,
  rather than the `.pak`, chooses the player map—without fabricating headless fallback cities;
- start map-bearing custom campaigns that do not embed an empire section as independent-city missions, while
  retaining the original city, relationship and trade records whenever an empire section is present;
- save and restore the complete deterministic city and campaign-clock state—including production,
  in-progress walker routes, scheduled events, requests, pending gifts and victory state—with a versioned
  native JSON format; create an automatic save when a mission starts and at every monthly settlement, keep the
  latest 24 automatic saves per campaign mission, retain quick saves, and expose the complete history in the
  classic pre-campaign lobby alongside standard macOS export/open panels;
- migrate format-v1 saves written before the 0.31 defense arrays, 0.32 empire runtime and 0.75 enemy-force state
  were added, and guard
  the 140×140-map profile with 24 full-map path searches plus two bit-identical 24-month replays (2.37 seconds
  on the 0.50 development machine, with an 8-second regression ceiling);
- resolve all 16 configured music tracks and 127 building sounds and play them through macOS AVFoundation;
- let the player select individual or multiple formations, show enemy forces maneuvering from authored invasion
  points toward live defenses, model invasion-size-dependent siege engines, dynamically orient surviving wall
  spans after gates, towers or demolitions change their neighbours, and preserve the battlefield in saves;
- run every mission in the eight official single-player campaigns for five simulated years twice with identical
  results (2,940 mission-months per replay), and retain a bounded local-only diagnostic log for release failures;
- start an arm64 SwiftUI application without launching Windows or Rosetta processes.

## Build and inspect

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect summary
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect economy
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect campaign-goals '/path/to/campaign.pak'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect campaign-events '/path/to/campaign.pak'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect campaign-empire '/path/to/campaign.pak'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect campaign-mission-maps '/path/to/campaign.pak'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect campaign-settings '/path/to/campaign.pak'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect map-images '/path/to/city.map'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect sprite-png '/path/to/archive.sg3' 225 /tmp/sprite.png
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run emperor-inspect sg3-logical-groups '/path/to/archive.sg3'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run EmperorNative
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/release-gate.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer RUN_UI_SMOKE=1 ./scripts/release-gate.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/package-app.sh
```

The UI uses [Sarasa Term SC Nerd](https://github.com/laishulu/Sarasa-Term-SC-Nerd). Install it on macOS with:

```sh
brew tap laishulu/homebrew
brew install font-sarasa-nerd
```

The app selects the Regular, SemiBold and Bold faces by PostScript name and falls back to the equivalent macOS
system font when they are unavailable. Font binaries are not copied into this repository or the packaged app.

The macOS **Game** menu lists the player shortcuts. `Command-S` makes a quick save, `Shift-Command-S` exports a
save, `Command-O` opens an external save, and `Command-L` loads the most recent history entry. In the city,
`Space` pauses or resumes time, `0`–`3` select speed, `B/H/G/C/X` select browse, housing, road, clear-land and
demolition tools, `R` rotates construction, and `Shift-Command-M` returns to the campaign lobby.

The default data source is resolved in this order:

1. `GameData` inside the app bundle Resources (installed builds)
2. repository-root `GameData` (local development and tests)
3. the legacy wrapper path
   `/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]` if still present

The inspector also accepts `--data /path/to/GameData`.

The non-UI release gate requires local `GameData`, rejects state-injection strings, runs the fixed Xia
playthrough and its counterexample, then runs all tests and builds both the app and UI harness. The optional UI
gate needs permission under **System Settings → Privacy & Security → Accessibility** and may take up to eight
minutes. Add the visible `dist/EmperorUISmoke.app` bundle there; without permission the gate exits immediately
with code 77 and does not launch or mutate a game session.

The packaging script first runs the non-UI release gate, then creates `dist/EmperorNative.app` with
`Contents/Resources/GameData`, a versioned ZIP and a SHA-256 file. By default it applies an ad-hoc
hardened-runtime signature for local testing. Set `SIGNING_IDENTITY` to a Developer ID Application identity and
`NOTARY_PROFILE` to a `notarytool` keychain profile to sign, notarize and staple the same build. No Apple
credentials are stored in this repository. Runtime diagnostics stay local at
`~/Library/Logs/EmperorNative/EmperorNative.log`.

## 1.0 milestone record

1. **0.60 — campaign compatibility:** external map references, independent-city missions, complete goal-source
   coverage and explicit network-scenario classification.
2. **0.75 — battlefield:** formation selection, enemy maneuver, siege engines, wall joins and battlefield status.
3. **0.90 — release candidate:** deterministic five-year official-campaign replay, legacy-save migration, bounded
   diagnostics and the existing dense 140×140 performance guard.
4. **1.0 — local distribution:** hardened-runtime app bundle, versioned ZIP and SHA-256 checksum. Developer ID
   signing and Apple notarization are automatically used when the owner's external credentials are supplied;
   the checked-in and locally produced default remains ad-hoc signed.

Native saves and diagnostics write under Application Support / Logs; packaged and local `GameData` trees are
treated as read-only.
