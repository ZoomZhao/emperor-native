# Qin-3 blocker audit (2026-08-30)

## Scope and evidence

This note records the latest player-command replay and the static-corpus
boundary for Qin mission 3 (Land of Annam / `Xiangjun.map`). The executable
hashes are the canonical English build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and the
Chinese cross-check build
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
No original runtime was launched for this pass.

## Replay observation

The existing player-command scenario was run with its skip guard temporarily
removed and then restored. It executes only public `PlayerCommand` actions
and advances the native calendar for 120 months. The terminal diagnostic was:

- population `259`, 40 houses initially placed, 30 remaining after late
  workforce/food collapse;
- only `27/40` houses reached the recorded service/coverage path;
- no level-6 residents (`0/1000` for the mission housing goal);
- lacquer best year `1200/1600`, carved jade `1200/1200`;
- food peddlers still delivered authored 30/50 quality bundles, but coverage
  remained partial (`foodAtHouses=14` at the terminal snapshot);
- missing requirements included commodity 19 (hemp), negative or zero
  desirability, and uncovered services.

This is a diagnostic of the current native bridge, not evidence for changing
the map layout or inventing a timer. The test remains skipped until each live
contract is independently recovered.

## Static findings used for the gate

The corpus confirms the following but does not close the Qin-3 blockers:

* Entertainment models `32/33/34` (acrobat/actor/musician) use the separate
  venue FSM at `0x48A9A0`, not generic `0x51D0C0`. The shared crossing callback
  passes visit selector `3`; `FUN_0048AD20 @ 0x48AD20` writes house fields
  `+0x2B/+0x2E/+0x2C = 0x60`. The callback is reached through the confirmed
  `FUN_004EACD0 → 0x429DF0 → 0x429E10(radius=2) → provider +0x2C` scan, which
  supplies the current figure and each visible candidate object. Provider
  selection (`FUN_0048A520`), terrain/object collision, and final
  market/venue settlement side effects remain unknown.
  Direct PE recovery also closes the previously omitted FSM middle branches:
  state `9` clears the route via `0x4E8A30`; state `10` fails with `+0x16 = 2`
  when its return route request fails and otherwise enters state `11`; state
  `11` calls provider/figure `+0x128` and fails only on a true return. The
  common tail uses the saved `+0x3E` countdown (capped at `7`) for state `4`
  and the shared directional phase for other states. These bytes are EN/CH
  identical, but route/collision helper semantics and terminal provider
  settlement remain unknown. Native therefore records selector `3` but keeps
  these figures outside `supportsRecoveredResidentialRoam`. The provider
  spawn-threshold rows are
  now stored as a side-effect-free source table in
  `OriginalResidentialServiceCatalog.entertainmentSpawnThreshold` and tested
  for provider IDs `211/212/213`; the closed candidate-admission portion of
  `FUN_0048A520` is likewise represented by
  `OriginalResidentialServiceCatalog.entertainmentProviderCandidates` (model
  range, global/provider gates, first non-empty `8/16/24` buckets, list order,
  and `n×2` side weight). Its downstream `FUN_005B0620` chooser is now
  narrowed to a weighted map search (`baseWeight + localDistance`, strict
  improvement, one-based candidate return; mode-specific `FUN_005B0220` /
  `FUN_005B0360` expansion). The exact `FUN_00765EE9` sorter, comparator, and
  reverse scan now close equal-cost tie order in the pure chooser (including
  the `<=8` selection-sort and `>8` quicksort paths). Map/object effects and
  occupancy settlement remain unknown, so the route/occupancy boundary stays
  fail-closed and the venue FSM is still disabled. The unweighted candidate
  selectors are also represented by
  `OriginalGrandCanalLayoutCatalog.selectEntertainmentVenueCandidateIndex`:
  `FUN_005AE970` uses reverse candidate order with mask `0x0B1D`, while
  `FUN_005B04A0` uses forward order with masks `0x010C`/`0x0B0C` for its two
  flags; all three preserve the source north/east/south/west BFS order and
  one-based return. Provider registry, route reconstruction, occupancy, and
  settlement remain unknown, so this is still a pure evidence helper.
  The candidate `+0x1A4` target is now also resolved for the three school
  provider vtables (`0x7ACEDC/0x7AD140/0x7AD3A4`): all dispatch to
  `FUN_004273F0`, yielding `DAT_0101D0C8 + x + y×0xE4`; Native exposes only
  the inverse conversion and still does not wire provider loading or coverage.
  The formerly missing positive opportunity writer is now closed: state-8
  heading `8` dispatches provider `+0x260` (`FUN_0048B710`) for Entertainment
  Area/Theatre Pavilion providers (building IDs `71/75`), writing record
  `+0x5D/+0x5F/+0x5E = 32` for figure models `32/33/34`; model `33` also
  increments and five-wraps record `+0x64`. Route/collision preconditions,
  registry projection, and surrounding settlement remain unknown. See
  `residential-service-roamer-lifecycle.md` §7.2c.5.
  The common figure cleanup callback `FUN_004C8B70` is also now bounded: via
  the common figure vtable `0x007AFE60 + 0x158`, figure models `32/33/34`
  decrement linked provider record byte `+0x5C` only when positive before the
  shared figure cleanup tail. This is an exit-side raw transition only; its
  dispatch event, field meaning, provider registry, and settlement remain
  unknown. See `residential-service-roamer-lifecycle.md` §7.2c.4c.
  The residential side of this callback is now also represented by the pure
  `OriginalResidentialServiceCatalog.entertainmentHouseCoverageWrite`
  contract: after the confirmed `+0xB8` eligibility and positive-population
  gates, figures `32/33/34` write `0x60` to `cHouseInfo +0x2B/+0x2E/+0x2C`.
  This closes only the field/value write; route, registry, and settlement
  remain unresolved, so the live venue bridge stays disabled. See
  `residential-service-roamer-lifecycle.md` §7.2c.6.
  A direct constructor inventory further tightens this boundary: in both
  hash-matched PEs the only direct call to `FUN_0051C660` is `0x42D3CC` inside
  `FUN_0042D360`, the only direct call to `FUN_0051BEF0` is `0x51C71C` inside
  that dispatcher, and the three service initializers are called only by its
  `0x48/0x49`, `0xCF`, and `0xD0` switch cases (`0x51B9F2/0x51BF45`,
  `0x51B962/0x51BFA5`, and `0x51B8D2/0x51BF75`). The EN/CH call bytes are
  identical. This is a confirmed negative for a second direct
  provider-constructor entry that could be reused during Qin map loading;
  indirect/table dispatch and the serialized provider-index source remain
  unknown. See `residential-service-roamer-lifecycle.md` §7.3ac.
  The map-load call graph was also corrected: `FUN_00534BF0` is called by
  `FUN_00534A30`/`FUN_0042E6A0` for map/cache initialization and does not call
  `FUN_0052F030`; the provider-excluding repair switch is reached through the
  separate `FUN_0053D100` path. This is confirmed by the corresponding
  `local/source` bodies and EN/CH `identical` rows (see §7.3m.1).
  The remaining `FUN_0053D100` post-load initialization chain was also read
  directly: `FUN_005355F0`/`FUN_00535540`, `FUN_0054F050`, `FUN_005AD3F0`,
  `FUN_005AD130`, `FUN_00535510`, and `FUN_00535B00` only reset map, route,
  and transient tables; none names a service constructor, model-specific
  replacement, or registry insertion. Their EN/CH rows are `identical`, and
  the downstream `FUN_0052F030` whitelist still excludes `0x48/0x49/0xCF/0xD0`.
  This is a confirmed negative for treating post-load initialization as the
  missing provider bridge; the archive index and any unindexed runtime/table
  dispatch remain unknown (see residential-service-roamer-lifecycle.md
  §7.3m.2).
* Water coverage has two independent house bytes (`+0x32` and `+0x34`) with
  different consumers and precedence. `FUN_0051BC00` chooses between them via
  provider slot `+0x224` and a global context branch. A prior note incorrectly
  attributed the Entertainment Area constructor to the Well: `FUN_0048CB10` /
  vtable `0x7AD878` is `cEntertainmentSquare` for authored model row `71`, not
  Well row `72`. The actual Well path is `FUN_0051BEF0(72)` → vtable `0x7B5EB4`,
  whose `+0x224` entry is `FUN_005B3AD0` (`+0x16 > 0 || +0x6F > 0`); it is not
  constant-false. The water callback's global predicate (`active`, `+0x54 ==
  3`, `+0x58 == 4`) remains the only recovered alternate selector for `+0x34`
  when the Well predicate is false. The well update's `+0x1F8` input is now
  closed as the `DAT_00F11C70[provider.+0x10]` appeal-buffer byte, and the
  mode-0/mode-1 four-way transition is captured by the pure
  `OriginalWaterProviderState.nextFlag` helper; the field selection is exposed
  by `houseInfoWaterByte`. Provider-slot assignment for non-Well providers,
  the remaining `+0x6F` writer triggers/cadence, the global branch's
  human-facing semantics, and provider/house mapping remain unknown; a single
  Native `.water` bit still
  cannot claim this contract. The provider `+0x2d` field is
  initialized to `-1` and persisted by the common object serializer; its
  callers follow a `+0x3c` parent link and read resolved object
  coordinates/vtable. A static trace of the campaign-goal type-9 record
  (`+4/+8/+0xC/+0x10`, 0x14-byte allocation) is a negative result: it cannot
  be used as the provider map-slot target, so the serialized record source,
  post-load parent registration, and Native registry correspondence remain
  unknown; the common deserialization write site is confirmed at
  `0x51CE00 → 0x427430`, and object creation assigns `+0xB4 = registryIndex`
  through `0x42D540` (see residential-service-roamer-lifecycle.md
  §§7.3g–7.3j).
  A complete direct-call census of `0x42D540` finds the same 21 relative `E8`
  sites in both canonical PEs. Fixed-model calls create marker/multipart/
  terrain objects, and the repair caller remains explicitly whitelisted away
  from service IDs; only the already-known player construction caller has a
  dynamic model argument tied to the service dispatcher. No additional direct
  service replacement caller is therefore confirmed (see residential-service-
  roamer-lifecycle.md §7.3y.1).
  The generic `Building` object-list path `0x42D790 → 0x42D0E0` also has no
  direct provider-factory call, and its separate archive-repair pass has an
  explicit whitelist excluding `0x48/0x49/0xCF/0xD0`; this is a confirmed
  negative, not evidence that Qin providers are absent (see
  residential-service-roamer-lifecycle.md §§7.3m and 7.3s).
  The provider-to-house dispatch itself is no longer unknown:
  `0x4EACD0` resolves the figure's home object, Well `+0x28` calls
  `0x429DF0 → 0x429E10(figure, 2, provider, 0)`, and the scanner dispatches
  each visible `DAT_00FC3750` map object through provider `+0x2C` (`0x51BC00`)
  before resolving `cHouseInfo +0x1E4`. Native's house-index projection now
  has this radius-two map-object callback as its explicit evidence boundary;
  the archive index source/post-load registry correspondence, remaining
  `+0x6F` writer triggers, and water-field selector semantics remain unknown.
  One external object-state
  path is now confirmed to write `+0x6F = 0x60` for Well-family IDs `72/73`:
  `0x511080` case 6 → `0x42AE30(candidate, 0x60)`, reached from the
  `0x511860 → 0x511710` candidate search when the controller command global is
  `DAT_010C6F60 == 0x69` in `0x515800`. Its human-facing meaning, user/event
  source, cadence, and linkage to a live Qin provider remain unknown, so Native still must not invoke it
  (see residential-service-roamer-lifecycle.md §§7.1c, 7.3g, 7.3h, and 7.3i).
  The wider `FUN_00511080` inventory now bounds this as a shared monotonic
  object-state writer: five direct call instructions cover Inspector's Tower
  (`124`), Well/unused (`72/73`), Watchtower (`127`), five Fort IDs
  (`220/221/223/224/225`) at `0x60`, and Trading Quay/Station (`56/58`) at
  `0x30`; `FUN_00511700` confirms the exact `level << 4` encoding. This does
  not identify a water semantic—its command/event cadence and Qin reachability
  remain unknown (see residential-service-roamer-lifecycle.md §7.3i1).
  The generic residential-service FSM adds a separate confirmed negative:
  `FUN_0051D0C0` writes `+0x6F` on its **figure** receiver during states
  `1/8/6/7/0xC`, while `FUN_004C72B0` clears that figure byte at construction;
  it never writes the provider object or calls `0x51BC00`. `FUN_005E5B90`,
  `FUN_004E7460`, `FUN_004E7520`, and the transient-object branch of
  `FUN_004E8BC0` are likewise figure/object lifecycle stores. Their EN/CH
  rows are identical, so these writes cannot be promoted to the Well provider
  predicate; the provider-side writer trigger/cadence remains unknown (see
  residential-service-roamer-lifecycle.md §7.3i3).
  The phase-`0x1F` scheduler adds another confirmed negative boundary:
  `FUN_004AC2B0 → FUN_00416D20` clears/updates `+0x5C` on model-`0x34`
  linked objects and, when an authored figure-57 (`'9'`) counter crosses
  `DAT_00847398`, writes `+0x40/+0x6F` on that **figure**. It does not write
  provider `+0x6F` or call `0x51BC00`; the provider-side trigger/cadence
  therefore remains unknown (see residential-service-roamer-lifecycle.md
  §7.3i4).
  The generic-record conversion boundary is now also explicit: the
  `0x427150 → source vtable +0x0C` path uses `0x426EA0` for a generic
  `Building`, and that copier preserves source `+0x6F` and `+0xB4` into the
  model-specific destination; `0x51CAA0` delegates to the same generic copy
  before its provider tail. This proves a serialized generic byte could be
  transported into a future Well object, but does not recover the generic
  byte's producer or the missing map-load conversion caller, so it does not
  enable water coverage (see residential-service-roamer-lifecycle.md
  §7.3i5).
  The Xiangjun byte-level probe is now corrected: the apparent `Building`,
  `cResWall`, and `cResGate` runs begin just after the fixed-layer/archive
  transition at `0x10AFE7`; they are not enough to decode named object
  records. `FUN_0052E7C0` writes the variable Building archive through
  `FUN_0042D790` and then writes `DAT_00F2B290`; Native therefore locates that
  final variable-layout grid from the last 51,984 decoded bytes
  (`Xiangjun.map`: `0x1BD25D`, all zero). The Building archive's exact
  count/schema remains unknown, so the water bridge stays fail-closed (see
  residential-service-roamer-lifecycle.md §7.3x).
  The earlier “thirteenth fixed byte-grid” interpretation is superseded:
  scalar/block writes are interleaved between byte-sized arrays, and the
  printable runs occur in the variable archive candidate rather than proving
  a grid payload. The trailing archive semantics and any post-load provider
  factory remain unknown (see residential-service-roamer-lifecycle.md §7.3w).
  A source-first preamble trace now closes the archive schema/slot boundary:
  `FUN_0042D790` reads schema `1`, then DWORD slot count `4,000`, and
  `FUN_0077FD90 → FUN_0077FFC8` consumes the first new-class tag (`Building`)
  at `0x10AFED`. The per-record payload schema, provider index, and post-load
  specialization/registration remain unknown (see
  residential-service-roamer-lifecycle.md §7.3ae).
  The player-placement path is separately closed: `0x4B1250` sends service IDs
  `0x48/0x49/0xCF/0xD0` through `0x42D540`'s free object-table slot allocator,
  which writes that slot to provider `+0x2D` after `0x42D360` installs the
  model-specific provider. This proves the source for newly placed providers,
  but not the serialized slot or post-load registration (see
  residential-service-roamer-lifecycle.md §7.3u).
  The map initializer's remaining provider-looking callback is also bounded:
  `0x534BF0 → 0x4AF230` walks the restored object registry and invokes active
  objects' `vtable +0x9C`; the Well/Herbalist/Acupuncture slots share
  `0x5B3BB0 → 0x51CCA0`. That body only updates per-model counters and validates
  an existing `+0x32` parent short against registry `+0x2D`; it does not call a
  factory, insert into a vector, or write `+0x2D`. Because `0x4AF230` is also
  called by player construction and simulation phases, this is a
  post-load-consistency consumer, not the missing specialization/registration
  edge. The four function rows are EN/CH-identical, so the archive index source,
  replacement caller, and insertion order remain unknown (see residential-
  service-roamer-lifecycle.md §7.3v).
  A further vtable-slot audit closes the most plausible hidden edge in the
  generic loader. `FUN_0042D790` constructs each record through the generic
  `Building` descriptor (`FUN_0042D0E0`), inserts it (`FUN_0042B590`), then
  invokes the current object's `+0xC0`. The base table's `+0xC0` is
  `FUN_004271B0`; its first operation is a virtual `+0x150` predicate. In
  both PEs the base, Well, Herbalist, and Acupuncture tables all point that
  slot at `FUN_00413A00`, whose body is `xor al,al; ret`. The callback then
  reaches only the common helper/reinsert path (`FUN_0042B6B0` /
  `FUN_0042B580`), never `FUN_0042D360`, provider `+0x2D`, or a parent link.
  Provider `+0xC0 → FUN_0051CB80` can therefore run only after an earlier
  vtable replacement that the loader does not perform. EN/CH rows for
  `0x413A00`, `0x4271B0`, `0x42D0E0`, and `0x42D790` are `identical`; this is
  a confirmed negative for a hidden callback-based Qin provider factory, not
  evidence that archive providers are absent. The replacement caller,
  serialized provider-index source, and Native projection remain unknown;
  Qin stays fail-closed (details in residential-service-roamer-lifecycle.md
  §7.3o.1).
* Market model-23 movement, route-buffer construction, provider-record
  reduction, and spawn capacity are separately recovered in
  `migration-popularity-producer.md` §§10.17–10.26. The route destination,
  map-cache projection, complete cMarket coverage writer, and Dinners/raw-food
  quality mapping remain unknown. The current household-delivery bridge is
  therefore not Qin fidelity evidence.
  The seven `DAT_008572E8` shop rows are static selection indices, not seven
  fixed provider records: `FUN_005428B0` assigns compact runtime slots from
  four Common or six Grand active layout bays (see
  `migration-popularity-producer.md` §10.65). The selected-row-to-bay binding
  and all quantity/coverage/settlement edges remain unknown.
  The record-level `+0x268` operation
  (empty-record filter plus raw `+0x8` sum) is now exposed as a pure Native
  primitive; the `+0x298` reducer is likewise represented as a pure raw-record
  mutation (strict smallest-quantity selection, split consumption, clear flag,
  and remainder), and `+0x2790` stocking is represented with the confirmed
  400-unit default cap and overflow. Their mapping to
  `inventoryByCommodityID` is still unknown and no market settlement path
  consumes them; cMarket `+0x284/+0x288` are separately confirmed as global
  indexed accumulators. The `+0x280` pass now confirms that its raw-record
  accumulation calls `+0x284(record+4, record+8)` after skipping only an
  all-zero record; the authored meaning of that raw index and downstream
  settlement remain unknown. `FUN_004B04D0` additionally confirms that
  provider `record+4` is the cMarket-internal commodity selector compared
  directly against the requested key. A new `FUN_00544B30`/`FUN_00544340`
  trace closes the quality-zeroing trigger: `cMarket+0x180` is cleared only
  after the selected-market replacement path leaves no active Dinners record
  (`0x1C`), not on generic inventory exhaustion. This does not close the
  replacement schedule or provider-record mapping, so the live market-quality
  bridge remains fail-closed. `FUN_005D4E80` now closes the shared
  storage/trade `+0x154` raw record-writer selection and one-unit update
  algorithm (empty-or-same-key candidates, non-zero free-capacity gate, strict
  maximum quantity, callback ordering, and EN/CH identity), represented by a
  side-effect-free Native helper. Direct RTTI/vtable evidence places it on
  cStorageBldg, cStorageBaysBldg, cWarehouse, cTradeBldg, cTradingStation, and
  cTradingQuay; the `0x555254` edge is inside a cMillBldg wrapper, not a cMarket
  callback. It therefore does not establish cMarket record population. The
  demand source, internal-key-to-Native-inventory lifecycle, and route/coverage
  semantics remain unknown. Original-timing peddler crossings now
  use the recovered radius-two object scan and wall/gate occlusion; the
  compatibility route, selected provider record, and quality/coverage writer
  remain fail-closed. The residential `+0x228` callback output order and
  Dinners per-callback cap are now closed (`target = residents×2`,
  `cap = max(1, residents/2)` for occupied houses; empty-house outputs are
  `10/5`) and represented by `OriginalMarketFoodDeliveryDemand`; only the
  original-timing bridge applies that cap, while the direct fixture API is
  unchanged.
  The cMarket vtable's own `+0x154` body (`0x543BC0`) is now separately
  bounded as a raw-record refill: it accepts only already-matching keys,
  chooses the strict greatest current quantity with non-zero free capacity,
  and applies one-unit `FUN_005D2790` updates until its derived positive
  remainder is met. Its model-data gates, record-population source, and
  internal-key/route/coverage mapping remain unknown; the pure
  `OriginalMarketProviderRefill` helper therefore does not enable settlement.
  A caller/byte-level negative search also finds the generic `(0x1c,200)`
  dispatch (`FUN_004AEDF0`) but no recovered key-population step after the
  cMarket constructor zeros its six records; indirect/table-indexed stores
  remain unexcluded, so this is a blocker boundary rather than a gameplay
  approximation.
* The original appeal producer is now bounded by `FUN_0044F1D0` →
  `FUN_0044ECD0` → `FUN_0044ED90`: it clears a `0x32C4`-cell appeal buffer, walks
  active building models, clamps propagation to 10 tiles, applies the
  authored step/step-size fields, and uses 16 angular sectors plus occupied-cell
  suppression for negative values. The shared `DAT_0081FF18` table is now
  confirmed as a 6×6 row-major map-offset table (with paired second dwords of
  unknown meaning), but the mapping from that table to Native
  anchors/orientations and occupancy bits remains unknown. The executable's
  buffer-to-HouseBldg `+0x5E` projection is confirmed below; the current Native
  Manhattan helper is therefore
  still a fallback and not Qin fidelity evidence.
  The separately generated ring arrays are also closed: `FUN_004B0710` emits
  square perimeters for bounds `[-1,1]…[-12,12]`, and `FUN_004BB810` consumes
  their exact `8,16,…,96` point counts from `DAT_0081F158` before flattening
  offsets with the canonical stride `0xE4`. This removes the former count-table
  ambiguity but does not identify the Native anchor or transient occupancy
  mapping, so it is not sufficient to enable Qin-3 desirability. The separate
  multi-cell shape arrays from `FUN_0044CDE0` are now represented literally in
  `OriginalAppealPropagationCatalog.squareRingOffsets`; their non-symmetric
  loop order is confirmed, but the same unresolved occupancy/anchor boundary
  still prevents wiring them into the live appeal simulation.
  Direct PE evidence also closes the global sector-object source: the
  byte-identical EN/CH thunk at `0x44E4C0` loads `0xA65420` and jumps through
  `0x42A170` to initialize the sixteen angle records consumed by
  `0x44E770`/`0x44E4D0`. This confirms the existing vector ordering is the
  executable's initialized table; it does not identify the missing Native
  object-grid occupancy or house-anchor projection.
  `FUN_0044ECD0`'s per-ring value schedule (step-distance cadence, sign-boundary
  snap-to-zero, `[-100,100]` clamp, and ten-ring cap) is also now represented
  by a side-effect-free Native primitive; it does not close the map-cell or
  house-anchor mapping.
  The `FUN_0044EB20` post-pass is now also bounded: Grand/Imperial Way objects
  (`0x6F/0x71`), Gardens (`0x73`), Vacant House (`2`), and a fixed
  `(-2,1,1,2)` producer tuple can inject additional appeal based on map flags
  `0x80/0x2/0x20/0x1000`. The flag meanings and row-span source remain
  unknown. `FUN_004B05F0` confirms the row spans themselves are derived from
  runtime map dimensions and stride `0xE4`, so these special-cell producers
  are documented but not enabled in Native.
  A vtable cross-check further rules out treating service providers themselves
  as the appeal occupancy writer: Well/Herbalist `+0x268` points to the common
  provider serializer (`0x51CE00`), Acupuncturist `+0x268` points to the
  serializer body at `0x51C3A0`, and Entertainment Area `+0x268` is a registry
  object accessor (`0x48D6B0`). These four slot words are identical in the
  canonical EN/CH PE pair (see `desirability-propagation.md`), so the ordinary
  map-object `+0x268` dispatch set—not the service-provider classes—remains the
  unresolved occupancy boundary.
  The Qin creation-origin setter is now recovered by direct PE disassembly:
  `0x428AA0..0x428C01` (EN/CH byte-identical, 0x162-byte slice SHA-256
  `d83c197c8d106887fbd5ccb70a461298a5f6089b670d2a9a0112ed8ea55445e`).
  `FUN_0042D540` pushes `(param_4,param_3,param_2)`, so the setter receives
  `(modelID,x,y)`, stores `+0x0A=x`, `+0x0C=y`, and computes
  `+0x10=DAT_0101D0C8+x+y×0xE4`. The only coordinate delta branch is for
  model IDs `56/58`, outside the Qin classes listed below. The confirmed
  appeal getter is `FUN_004273D0 @ 0x4273D0` at vtable `+0x1F8`, which reads
  the canonical object index at `+0x10` from `DAT_00F11C70`; the neighboring
  `FUN_004273F0 @ 0x4273F0` remains the separate coordinate-to-linear-index
  helper (`DAT_0101D0C8 + object[+0x2A] + object[+0x2C]×0xE4`). Refresh-time
  `+0x84` callbacks may replace those coordinate fields with access cells.
  Multi-cell side length is now also confirmed from the same model-record table:
  houses `2…10` are 2×2, elite houses `11…17` are 4×4, and Well/Herbalist/
  Acupuncture/Entertainment IDs `71/72/73/207/208` are 2×2. Orientation/
  orientation details beyond the supplied origin, occupancy suppression, and
  Native grid projection still block live Qin desirability; side length and
  creation-origin evidence alone do not authorize wiring the path.
  A separate refresh boundary is confirmed: calendar case `0x15`
  (`FUN_004ACFC0`) clears `+0x2A/+0x2C` and invokes object vtable `+0x84`;
  `FUN_00416400` copies the generic object's `+0x0A/+0x0C`, while specialized
  refreshers select road/flood access cells. This is refresh-time evidence,
  not a substitute for the recovered creation-time `+0x94` origin setter or
  the unresolved Native occupancy/projection mapping.
  A direct vtable check further narrows the producer branch for these
  Qin-relevant classes: base/House, Well, Herbalist, Acupuncture, and
  Entertainment Area all carry `+0x168 → 0x413A00` (zero),
  `+0x16C → 0x416AC0` (no-op), and `+0x170 → 0x416AD0` (returns object byte
  `+0x07`) in the hash-matched CH PE. They therefore all take the generic
  `FUN_0044ECD0` radial path with the authored 2×2/4×4 side byte; none selects
  `FUN_0044EA70`'s custom rectangle path. This removes a class-branch
  ambiguity and, together with `0x428AA0`, closes the Qin creation origin;
  occupancy callback and Native projection remain unresolved, so Qin desirability stays fail-closed
  (see `desirability-propagation.md`).
  The buffer-to-object boundary is now confirmed: `0x4ACD10` writes the
  appeal byte to HouseBldg `+0x5E`, and direct PE `0x51A660` reads that same
  `house +0x5E` for the evolution reason classifier; monthly `0x4AE900 →
  0x5180E0` also consumes `vtable +0x1F8` from the shared appeal buffer.
  This removes the prior “unknown final house field” wording, but does not
  solve Native multi-cell projection, occupancy arbitration, or downstream
  evolution side effects.
  Generic map `Building` records are loaded through the base constructor and
  common serializer (`0x42D0E0/0x42D050 → 0x427430`), which explicitly reads
  both appeal byte `+0x5E` and provider slot `+0xB4`. A shared `vtable +0x18`
  conversion (`0x427150 → 0x42D360 → +0x0C copier`) can instantiate the
  model-specific House/Well/Herbalist/Acupuncture object and copy the generic
  fields, but the corpus does not close its caller for map-loaded records or
  the subsequent registry/parent-link registration. This confirms the
  conversion mechanism only; it does not authorize treating archive records as
  live Qin service objects or wiring `+0x5E` into Native housing state.
  A direct PE vtable check further bounds the load callback: base `Building`
  vtable `0x7AB59C + 0xC0` targets `0x4271B0`, while provider vtables
  `0x7B5EB4/0x7B6114/0x7B6374 + 0xC0` target `0x51CB80`; the latter allocates
  its auxiliary object from the provider `+0x2D` index. Thus a provider
  vtable must already replace the generic record before the load callback can
  execute provider registration, and the specialization/replacement caller
  remains unresolved in both EN and CH.
  An exhaustive direct-call inventory in both canonical PEs finds only
  `FUN_0042D360` call sites `0x42715E` (inside `FUN_00427150`) and `0x42D714`
  (inside the explicit registry-creating `FUN_0042D540` path). The sole direct
  `FUN_00427150` caller is `0x541113` (`FUN_00541110`), whose containing class
  accepts only transient/event IDs `-2`, `-1`, and `0x3E…0x46`, not the
  Well/Herbalist/Acupuncture IDs. `FUN_0042D790` has no direct model-factory
  call; it dispatches only the current record's `+0xC0`. This is a confirmed
  negative for an omitted direct factory edge, while an indirect virtual
  `+0x18` conversion caller and the replacement/list-registration order remain
  unknown (see residential-service-roamer-lifecycle.md §7.3o).
  The suspected multi-part rebuild edge is also closed negatively: the only
  direct caller of `FUN_00563850 @ 0x563850` is `FUN_0056A0D0 @ 0x56A0D0`
  (`0x56A124` in both PEs), whose switch admits only model IDs
  `0x4C…0x54`, `0x5C…0x5D`, and `0xFD…0x10C`—authored IDs `76…84`, `92…93`,
  and `253…268` for multi-part monuments/Great Wall segments. It excludes
  provider IDs `72/73`, `207`, and `208`; the helper therefore cannot be the
  missing provider specialization or `+0x2D` registration path (see
  residential-service-roamer-lifecycle.md §7.3q).
  The helper does write the short multipart parent/child chain (`+0x3C/+0x3E`),
  but its complete caller switch excludes provider IDs `72/73/207/208`; this
  is now recorded as a confirmed multipart-only writer and a negative provider
  registration result (see residential-service-roamer-lifecycle.md §7.3r).
  The phase-`0x1C` caller `0x4ACE30 → 0x5179B0` also resolves a pointer-domain
  ambiguity: `0x5179B0` writes the compact status to the live `Building`
  object at `+0x39` after reading `cHouseInfo +0x32/+0x34` through vtable
  `+0x1E4`; it does not write another `cHouseInfo` water byte. The inspector
  `0x5BCAD0` separately reads `Building +0x43` for its “well supply” branch.
  This is confirmed in both EN/CH rows and leaves the `+0x43` writer and the
  Native object-registry projection unknown (see §7.3p).
  The other obvious indirect `+0x18` candidate, `0x4E1420` via
  `0x4EA050`, is an event/FSA object factory: it allocates fixed-size
  `0x19C` objects and registers them in the `0x4E2350/0x4E2370` lists, never
  in the Building registry. This rules out that candidate despite numeric
  selector overlap with Well IDs; remaining indirect `+0x18` sites still
  need class-context tracing (see residential-service-roamer-lifecycle.md
  §7.3o).
  `FUN_005A5F60` remains an inspector-side nearby-object scan and the recovered
  `+0x38` aggregate (`FUN_00517330`) remains health/service, not housing appeal.
  The residential commodity requirement reader `FUN_00588CB0 @ 0x588CB0`
  is now bounded separately: it reads a threshold from one of two global
  tables, projects the requirement commodity through `FUN_00447600` into a
  `cHouseInfo` stock word, and takes the larger lacquerware/bronzeware stock
  for the shared luxury requirement. Direct PE call sites at `0x588E89` and
  `0x5890D3` place it in the omitted `cSuppliesOverlay`/
  `cDistributionOverlay` methods (`0x588D90`/`0x588FB0`), confirming an
  overlay/inspector consumer but not the housing-evolution scheduler. The
  EN/CH row is `identical`, and the numeric threshold/index contents are now
  confirmed by identical PE ranges; the evolution caller, authored-table
  linkage, and Native stock lifecycle remain unknown. `FUN_005F05D0` separately confirms direct elite-house stock
  consumption/zeroing; its immediate direct PE caller is now recovered at
  `0x4D0460` (movement state 7, heading 8), while the enclosing scheduler and
  Qin reachability remain unknown. The current ID-presence check is therefore
  not Qin fidelity evidence (see migration-popularity-producer.md
  §§10.33–10.34a).

## 2026-08-31 live-wiring corrections

The static corpus was rechecked against the monthly Native call graph after
the previous audit. `FUN_00518690 @ 0x518690` and the raw cMarket record
helpers (`0x5437B0`, `+0x268/+0x280/+0x298/+0x2790`) confirm arithmetic and
field-level boundaries, but no provider-record → `cHouseInfo`/Native inventory,
quality, coverage, or route mapping. Existing research therefore classifies
Qin market settlement as **unknown**, not as a usable household-consumption
implementation. `CitySimulation.settleMonth` now keeps
`DeterministicMarketState.settleMonth` on the unscoped sandbox/fixture branch
only (`missionSettingsState == nil`); campaign-backed Qin month boundaries
leave Native food/commodity stock, quality, shortage counters, and market
settlement records unchanged. This is a confirmed negative live-wiring guard,
not a claim that the sandbox API is original behavior. Regression coverage is
`EmperorCoreTests.testCampaignMonthLeavesUnrecoveredMarketSettlementFailClosed`.

The same pass retains the previously recorded fail-closed boundaries for
health incidents and appeal projection: `0x517190…0x5180E0` closes health
aggregation/display but no incident producer, and `0x44F1D0→0x44ECD0→0x44ED90`
closes appeal-buffer geometry but not Native occupancy/anchor projection.

`FUN_004BAF40 @ 0x4BAF40` is now closed as a two-stage access-candidate
arbitration helper (migration-popularity-producer.md §10.36a). The ranked pass
walks the recovered 24-slot perimeter table, applies the object `+0xD0`
adjustment and `0x40/0x04` road-bit predicates, then keeps the first strict
minimum from the ten-entry component table (missing labels use sentinel rank
11). If no ranked row qualifies, the original fallback ignores object and
terrain flags and chooses the first strictly smallest positive flood value
using raw offsets. This is represented by explicit-input pure tests only;
the object registry, runtime flag-to-map projection, and access-coordinate
mapping remain unknown, so Qin automatic migration and specialized refreshers
remain fail-closed.

The per-house health arithmetic is also preserved as an explicit-input
research helper (`OriginalHouseHealthAggregate`, residential-service-roamer-
lifecycle.md §7.1a). It covers the exact food-quality bucket boundaries,
`+0x34` over `+0x32` precedence, herbalist/acupuncture additions, three
`+33` goods terms, and the population-scaled minimum-one result. This closes
field arithmetic only; cHouseInfo/provider projection, natural-health
aggregation, and disease/crime production remain unknown and are not wired
into Qin runtime.

## 2026-09-01 appeal-adjustment writer closure

The remaining appeal `+0x60` writer is no longer wholly unknown. Direct
canonical EN/CH disassembly of the Qin-shared creation setter
`0x428AA0` shows a call to `FUN_004BAEE0 @ 0x4BAEE0` with the supplied origin
`(x,y)` and the authored footprint side, followed by `mov byte [object+0x60],
al` at `0x428B8F`. The indexed callee is EN/CH-identical and scans the ordered
`DAT_00820038 + side*0x60` perimeter row (maximum 24 entries, zero sentinel),
testing bit `0x04` in `DAT_00F6A9E0` at each `DAT_0101D0C8 + x + y*0xE4 + offset`
cell. `FUN_00516BE0` independently calls the same predicate before its
appeal `+10` adjustment. `OriginalAppealPropagationCatalog.objectOffset60Flag`
and focused tests now preserve this arithmetic as an explicit-input,
fail-closed primitive. This closes the flag writer and terrain-bit predicate;
the runtime `DAT_0101D0C8` projection into Native coordinates and later
post-placement mutations remain unknown, so live Qin desirability is still
disabled.

## 2026-09-01 runtime map-base selector closure

The runtime `DAT_0101D0C8` assignment is recovered at the control-flow
level. `FUN_0053CE60 @ 0x53CE60` (EN/CH `identical`) obtains a selector from
`FUN_004F8210(FUN_0052E7B0())`, multiplies it by `0x10`, and copies the four
dwords in `DAT_00856C64 + idx*0x10` into the map descriptor and
`DAT_0101D0C0…D0CC`. The fields are map width, map height, linear base
offset, and row-advance/padding value. `FUN_00534410 @ 0x534410`, `FUN_00534BF0 @ 0x534BF0`,
and `FUN_0053CEC0 @ 0x53CEC0` call this selector before map
initialization/passes; `FUN_00534BF0` consumes the selected width/height in
its full-map loops.

This closes the source of the base variable but not its authored values. The
decompilation corpus does not emit the literal `DAT_00856C64` rows or a
selector-index-to-`GameData/Cities` mapping. Native therefore keeps the
appeal helper explicit-input and fail-closed: `startOffset` may not be
silently substituted for the executable's selected base until that table
mapping is independently recovered.

**Evidence class:** `confirmed` for the selector/assignment chain and
EN/CH identity; `unknown` for literal table rows, city mapping, and any
post-load descriptor mutation.

## Classification and remaining action

The replay result is **confirmed** as a native diagnostic. The selector-3
metadata and the three static separations above are **confirmed**. The exact
entertainment provider/route/collision contract, any indirect/non-zero
`Building +0x43` writer (the direct-writer search is a confirmed negative),
the remaining water writer and provider-slot mapping, the market
coverage/quality writer, and the PE appeal occupancy/projection mapping are
still **unknown**. The Qin
creation-origin source, appeal producer, shared 6×6 offset table, and
buffer-to-object copy boundaries are confirmed,
but the current Native mapping is not isomorphic.
The object-grid writer's cell merge, six-by-six table indexing, `0xE4` row
stride, and direction-selected edge marker are now isolated in the
side-effect-free `OriginalMapObjectGridProjection` primitive; the canonical
table literals are now represented, while Native registry/orientation mapping
remains unknown, so this does not change the fail-closed boundary. The `house+0x24`
land-entry flood predicate is also confirmed in both EN/CH
(`FUN_005AE140` / `FUN_005AE240`, `compare-report.tsv` = `identical`);
Native's projection is source-equivalent on Ferry-free maps. Ferry
post-pass/connector projection and blocked-entry fallback semantics remain
unknown. The Ferry primary-cache
post-pass masks/order, bounded cardinal gradient walk, and data-independent
placement-flood control flow (including the PE layer addresses, reset size,
tie source, and Ferry computation call gates) are now captured by pure
explicit-input helpers and static call evidence, while PE-layer projection,
coordinate ownership, connector serialization, and placement integration
remain unknown; this does not change the live fail-closed boundary. Qin-3 remains
fail-closed; the next implementation may proceed only after one of those
contracts is closed from `local/source` (including its callers/callees and
EN/CH comparison) and the corresponding Native mapping is specified.

The Well vtable predicate used by the water-field selector is now closed at
the instruction level: `FUN_005B3AD0 @ 0x5B3AD0` returns true iff signed word
`provider + 0x16 > 0` or unsigned byte `provider + 0x6F > 0`. EN/CH are
`identical` in `local/source/compare-report.tsv`; the pure
`OriginalWaterProviderState.providerVTable224Predicate` helper and regression
test preserve the two field widths. This narrows the water unknown without
enabling it: provider specialization/registry identity, field writers and
cadence, and the command-side `+0x6F = 0x60` reachability in Qin remain
unknown, so the campaign water bridge stays fail-closed.

## 2026-09-01 follow-up

The canonical EN (`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`)
and CH (`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`)
PE bodies at `0x4C6D30` were disassembled directly because the generated
`local/source` corpus has no function file for this address. The bytes match:
the post-pass uses signed origin words `+0x0A/+0x0C`, the `0xE4` row stride,
the 36-entry `DAT_0081FF18` table, `0x800` footprint writes, and a bounded
connector loop that accepts only `0/2/4/6` and advances by
`-228/+1/+228/-1` while OR-ing `0x200`. This is corroborating binary evidence,
not a replacement for the still-missing PE-layer-to-Native projection.

The `FUN_0051CCA0` parent-link tail is now represented by
`OriginalWaterProviderState.validatedParentShort`, preserving a non-zero parent
short only when the resolved target is active (`+0x16 == 1`) and owned by the
provider (`target +0x68 == provider +0x2D`). Registry lookup, serialized index
source, and post-load specialization remain unknown; no runtime wiring changed.

## 2026-09-01 map descriptor literal closure

The runtime map-base table previously lacked initialized values in the
decompilation output. Direct read-only inspection of the hash-matched EN/CH
PEs closes that missing input: `DAT_00856C64` at file offset `0x456C64`
contains six identical rows `(56,56,19694,172)`, `(84,84,16488,144)`,
`(112,112,13282,116)`, `(140,140,10076,88)`, `(170,170,6641,58)`, and
`(226,226,229,2)`. The 0x60-byte slice SHA-256 is
`ac39b5610e0a3be60215936402e8f8064686b4c8778029af3857f7eec965a7f3` in both
executables. `FUN_0052E630 @ 0x52E630` selects the row by the current map
width; each base equals the centered serialized `startOffset`, and each
`rowAdvance` equals `228 - width`.

Native now records these rows in `OriginalMapRuntimeDescriptorCatalog` and
validates the effective `228` row stride. This supersedes the earlier
“selector-index-to-city mapping unknown” wording for the map-base input. It
does not resolve the independent object-registry, multi-cell occupancy, or
post-load provider/desirability mappings, so Qin-3 remains fail-closed.

**Evidence class:** `confirmed` for table literals, selector-by-dimension,
centered base and row stride; `unknown` for any later descriptor mutation and
all remaining object/service projections.

## 2026-09-01 diagnostic-only producer run

To separate the migration gate from downstream Qin failures, the existing Qin-3
player replay was run once with the campaign's `AutomaticMigrationAvailability`
temporarily changed from `unsupportedOriginalProducer` to
`supportedOriginalProducer`; the test skip guard and production source were
restored immediately afterward. This run is a diagnostic of the current Native
bridge, not an authorization to ship the gate bypass.

With migration temporarily admitted, population rose to about `395` and then
collapsed to `297` by the terminal month, with workforce about `252`. The
terminal snapshot recorded no peddlers (`p=0`, buyers `=0`) and no active mill
output; shops remained populated as buildings (`66,65,67,65,66,66`). Farms
still produced authored goods (rice `800`, lacquer `600` per farm), and trade
partner stock/delivery records advanced (partner `0`: commodity `19 = 500`;
partner `6`: commodity `17 = 500`; one `17×100` trading-building→warehouse
delivery). The mission counters therefore reached lacquer `1200/1600` and jade
`1200/1200`, but population was only `297/1800` and level-6 housing `0/1000`.
The unresolved service boundary was visible in the same snapshot: food quality
was `0` for `15` houses and water service was missing for `14`; no peddler
spawn occurred because the campaign route remains fail-closed.

**Classification:** **confirmed** as a temporary diagnostic result. It shows
that merely admitting the generic migration producer does not close Qin-3:
the market/peddler route and provider-record lifecycle, water provider
registry/writer, and desirability/coverage projection remain independent
blockers. **Unknown** remains the exact original migration arrival writer and
the provider/route contracts; the production campaign gate consequently stays
`unsupportedOriginalProducer`.

## 2026-09-01 post-load repair-switch follow-up

The map/post-load missing-object repair pass is now bounded by the exact
`FUN_0052F1D0` switch consumed by `FUN_0052F030`. Its admitted model IDs are
`83,89,90,91,104,105,106,123,129,130,131,210,231,232,253…268`; EN/CH bodies
are identical. None of the residential service models (`72/73,207/208,
211…219`) are admitted, and the pass calls only generic
`Creating_pctd_type_pctd`, not the service factory or provider-slot writer.
`OriginalMapArchiveRepairCatalog` and a regression test preserve this as a
confirmed negative. Indirect/table-driven specialization and the serialized
provider index remain unknown; Qin stays fail-closed.

## 2026-09-01 invasion-record follow-up

The previously open “quantity writer” boundary for the invasion threat
aggregate is now closed at runtime. The unified 100-record table, the enemy
slice beginning at slot `0x23`, and the `FUN_00522D30` successful-figure
creation/reset/recount edges are recorded in
`migration-popularity-producer.md` §10.72. This identifies how the executable
maintains the raw quantity byte, but it does not identify archive/load
prepopulation or the Native object-registry projection. The aggregate remains
an explicit-input research helper and is not connected to
`EnemyMilitaryForce.soldierCount` or `warCount`; Qin therefore remains
fail-closed at this boundary.

## 2026-09-01 market crossing callback follow-up

The cMarket peddler-to-house edge is now statically closed. `FUN_004EACD0`
dispatches a market-owned figure through the home object's vtable `+0x28`;
cMarket's entry is `FUN_00429DF0`, which calls the radius-two
`FUN_00429E10` scan. The scan invokes the cMarket receiver's vtable `+0x2C`,
the normal market-delivery writer `FUN_005437B0`. These split-corpus functions
are EN/CH `identical`; the unsplit writer's EN/CH PE bytes are identical over
`0x5437B0…0x543BBB`. The chain is recorded in
`migration-popularity-producer.md` §10.77 and represented by the pure
`OriginalMarketPeddlerCoverageDispatch` descriptor plus regression test.

This confirms the callback destination but not the provider-record population,
the `+0x21C`/`+0x264` inventory semantics, collision-rejection route recovery,
or the complete house-quality writer set. No Qin runtime coverage or
settlement bridge is enabled from this finding; those boundaries remain
`unknown` and the campaign stays fail-closed.

## 2026-09-01 indirect map-load conversion scan

The suspected indirect `vtable +0x18` bridge from generic map `Building`
records to Well/Herbalist/Acupuncture objects was exhaustively checked in
both hash-matched PEs. With `.text` VA `0x401000` and raw pointer `0x1000`,
all `call dword ptr [reg+0x18]` sites in `0x520000..<0x540000` are limited to
`FUN_00522D30` (`0x52325C`, `0x5234E7`, figure/route action initialization)
and `FUN_0053B000` (`0x53B05C`, `0x53B124`, UI/campaign predicates). The
map-load/post-load functions (`FUN_0052E7C0`, `FUN_0042D790`,
`FUN_0042D0E0`, `FUN_0052FDA0`, `FUN_00534BF0`, `FUN_0053D100`,
`FUN_0053D630`) contain no such call, and the only direct
`FUN_00427150` caller (`FUN_00541110`) is cart-state copying at `+0x158`.
EN/CH bytes are identical and `FUN_0042D790` still terminates at the MFC
`Building` factory, vector insertion, and object `+0xC0` callback. No
provider factory or `+0x2D` writer is reached.

This is a confirmed negative for the indirect-call hypothesis; table/data
dispatch and runtime-only registry projection remain **unknown**. Qin-3
automatic migration and service settlement therefore remain fail-closed.

## 2026-09-01 canonical immigrant-think parity follow-up

`FUN_004C9FD0` has no generated split file, so the state-6/7/8 body is a
direct-PE finding. The complete `.text` slice `0x004C9FD0…0x004CA337`
(exclusive end `0x004CA338`, 872 bytes) is byte-identical in the canonical EN
(`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and CH
(`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`) inputs;
both slices hash to
`7a22da2c8c2d0f2e4c502b1744f2a28b4e1d772f355817c739a922f4861878e3`.
This removes any canonical build-difference concern for the recovered
immigrant wait/walk/arrival control flow. It does not recover the missing
archive-side house specialization, provider/house projection, or the
`DAT_00D62408`/`house+0x24`/`cHouseInfo+0x3C` semantic inputs; no Native
producer or arrival wiring is enabled and Qin-3 remains fail-closed.

## 2026-09-01 `house+0x24` selector follow-up

The previously unclassified `FUN_004E38E0 @ 0x4E38E0` reader is now closed
through both corpus-visible callers. It scans the active object vector and
selects the first house passing `+0xB8`, `house+0x24 > 0`, and
`house+0x20 > 0`, returning `+0x2A/+0x2C` and `+0xB4`; if none qualifies it
falls back to `DAT_01312010`, otherwise returning `-1` outputs. In
`FUN_004C8B70` this can precede a one-resident decrement for the
`FUN_005EA4D0` figure family; `FUN_0054BAB0` uses the result in its figure
relocation path. All five functions are EN/CH `identical` in the comparison
report. This narrows one concrete `house+0x24` consumer but does not identify
the field's semantic name or Native projection, so the Qin migration/service
bridge remains fail-closed.

## 2026-09-01 market-child admission follow-up

The market child class and selector gate are now closed (see
`migration-popularity-producer.md` §10.83). Authored rows and the indexed
factory chain identify `0x3B/0x3C` as cMarket and `0x3E…0x46` as cStall; the
placement replacement path changes a slot from Empty Shop `0x3E` to a named
shop `0x40…0x46`. cStall `+0xC8` (`FUN_005408D0`) admits selector `-1` only
for model `0x3E`, while `FUN_00544A80(-1)` and `FUN_00544EC0` apply that gate
before consuming child `+0x44`/`+0x1B8`. Filled shops therefore do not
contribute to the selector-`-1` aggregate. This is a confirmed negative for
using the aggregate as a Native market-worker or household-coverage count;
provider-record population and the `+0x44` semantic label remain unknown.
Qin's campaign market/peddler bridge stays fail-closed.

## 2026-09-02 market helper entrance-table follow-up

The cMarket `+0x194` nearest-record reducer's previously open helper-table
input is now statically closed. `FUN_00542350 @ 0x542350` uses helper virtual
`+0x6C` (both Common/Grand helpers return exactly two records) and virtual
`+0x70(bank,index)`. Common vtable `0x7AB800` dispatches `+0x70` to
`0x42CD30`, Grand vtable `0x7AB878` dispatches to `0x42CDD0`; the EN/CH
accessor and count bytes are identical. Direct PE table slices at `0x857D88`
(Common) and `0x857D68` (Grand) contain, by orientation bank, Common
`(0,3),(3,3)` / `(3,0),(3,3)` and Grand `(0,3),(5,3)` / `(3,0),(3,5)`.
`OriginalMarketPeddlerHelperRecordCatalog` and focused tests preserve these
exact values and the strict Manhattan nearest reduction.

This closes only the static helper-record input. Runtime helper instance
registration, map-cache projection, route/collision recovery, provider
records, and coverage/quality writer ordering remain unknown; no Qin peddler
or settlement path was enabled.

## 2026-09-02 appeal-scale follow-up

The monthly appeal-to-population primitive's scale input is now closed. The
EN/CH-identical `FUN_00590A70 @ 0x590A70` writes
`DAT_0130F96C = 9`; it is called by both normal model initialization
`FUN_005D1400` and city-start setup `FUN_0042E6A0`. The `ALL HOUSES` loader
(`0x5D1830`/`0x5D16D0`) and `GameData/Model/EmperorBuildingModels.txt` also
confirm field `0` as initial desirability and field `0x12` as tax-rate
multiplier. `OriginalAppealPopulationAccumulator.defaultAppealScale` records
the recovered constant.

This closes only authored arithmetic inputs. The vtable `+0x204` class result,
appeal-buffer-to-house projection, occupancy/anchor state, and aggregate
ledger remain unknown; Qin desirability and migration stay fail-closed.

## 2026-09-02 HouseBldg appeal-class follow-up

The Qin residential class branch in the monthly appeal accumulator is now
closed. `HouseBldg` vtable `0x7ABA38` slot `+0x204` points to
`FUN_00518D90 @ 0x518D90`; the EN/CH PE body is identical and returns true
exactly when signed `house+0x14 >= 11`. `FUN_005180E0` uses that Boolean to
split lower/upper population and tax-delta buckets. The pure
`OriginalHouseAppealPopulationClass` helper and regression test preserve the
boundary.

The appeal-buffer projection, occupancy/anchor state, aggregate ledger, and
non-`HouseBldg` class mappings remain unknown; Qin desirability and migration
remain fail-closed.

## 2026-09-02 appeal tax-ledger follow-up

The aggregate arithmetic in `FUN_00517BC0 @ 0x517BC0` is now closed from the
EN/CH-identical split body (`local/source/split-merged/code/0x050000/FUN_00517bc0.c`;
`local/source/compare-report.tsv`). It walks active records, splits covered
house residents by the `HouseBldg` `+0x204` class result, weights each signed
resident word by authored house column `0x12`, scales both buckets with
`FUN_00408B80(value, DAT_0130F96C)` (`DAT_0130F96C = 9`), and applies month
multiplier `1` for month `0`, otherwise `13 - month`. The exact outputs are
`DAT_01312250 = DAT_01312244 + DAT_01312240` and
`DAT_01312530 = multiplier × (lowerScaled + upperScaled) +
DAT_01312244 + DAT_01312240`; `FUN_004098F0` consumes `DAT_01312530`.
`OriginalAppealTaxLedger.project` preserves this arithmetic as a pure,
overflow-checked research helper with focused regression coverage.

Only the arithmetic is closed. The meanings/producers of object `+0x52`, the
resident/coverage projection, `DAT_01312240/44`, and the final Native ledger
mapping remain unknown; no Qin appeal, migration, or tax settlement path is
enabled.

The same `FUN_005180E0` tax-covered branch also closes the per-house fixed-point
delta arithmetic feeding `DAT_01312240/44`: it adds the `__ftol` contribution to
`cHouseInfo + 0x40`, rounds old and new values independently with
`(value + 5000) / 10000`, and accumulates their difference into the class
selected by `+0x204`. This is represented by the pure
`OriginalAppealTaxLedger.projectTaxDelta` helper and focused tests. The
increment producer, field semantic label, and Native object/ledger projection
remain unknown, so the Qin gate is unchanged. The raw field lifecycle and
save boundary are closed in the follow-up evidence below.

The raw `cHouseInfo +0x40` lifecycle is also bounded: constructor
`FUN_00517190` initializes it to zero, month-boundary `FUN_00517950` resets it
after publishing the prior ledger, `FUN_004AFFB0` reads it as
`(value + 5000) / 10000`, and the cHouseInfo serializer at `0x517410` saves
four bytes beginning at that offset. The reader is represented by
`OriginalAppealTaxLedger.roundedFixedPointUnits`; this closes storage and
rounding edges only. The semantic label, `__ftol` increment producer, and
Native object projection remain unknown, so Qin remains fail-closed.

## 2026-09-02 invasion hero-gate follow-up

The optional Enemy's Heroes branch in `FUN_00522D30 @ 0x522D30` now has a
closed raw admission predicate. The selected city record's signed short at
`+0x38` must be in `0...11` before the model-78 `FUN_0054C4F0` allocation and
`FUN_00510C70` placement request are attempted. The EN/CH comparison row is
`identical`. Native records this as the research-only
`OriginalInvasionHeroEligibility` helper; it does not imply allocation,
route/placement success, or a recovered city-field semantic. The model-78
spawn path, per-figure war-count ledger, and Qin runtime selector binding
therefore remain fail-closed.

## 2026-09-02 war-count ledger follow-up

The recovered `DAT_01312564` arithmetic is now available as the explicit-input
`OriginalWarFigureLedger`. It mirrors `FUN_004EBBD0 @ 0x4EBBD0` reset and
`FUN_004EBB40 @ 0x4EBB40`'s per-figure `+1/-1` transition after the exact
`FUN_004E2560` model gate (`58…62, 78`) with a lower bound of zero. The
creation/death call sites (`0x4E199A`, `0x4EA01B`, `0x4C90D7`) and the EN/CH
comparison rows are recorded in `migration-popularity-producer.md` §10.7c.

This closes the arithmetic primitive only. Native still has no recovered
individual-figure registry, archive prepopulation, or event timing from which
to feed the ledger; `CitySimulation.warCount` remains zero and Qin migration
pressure stays fail-closed. Evidence class: **confirmed** for reset/gate/
transition; **unknown** for the Native figure-event projection.

## 2026-09-02 market placeholder-slot follow-up

The market placement boundary is now represented without enabling Qin
settlement. EN/CH-identical `FUN_005428B0 @ 0x5428B0` assigns compact runtime
ordinals to active Common/Grand layout entries and stores each empty-shop
placeholder's ordinal at `object+0x150`, its parent market ID at `+0x154`, and
its registry ID in `market+0x15C[ordinal]`. The coordinate-selected replacement
(`FUN_00540E70 @ 0x540E70`) preserves that ordinal; `FUN_00540F80 @ 0x540F80`
then installs the selected `DAT_008572E8` row key and its 400/800 capacity.
`FUN_00544B30 @ 0x544B30` subtracts the same 400/800 value on selected-record
removal and clamps the raw word at zero. The comparison report marks all four
functions `identical`.

`OriginalMarketRuntimeShopBinding` records this already coordinate-selected
placeholder order and explicit registry IDs, and its raw removal helper keeps
the non-negative subtract-and-clamp arithmetic. It does not synthesize map
objects, infer a row-to-bay permutation, populate provider quantities, or turn
on the Qin market bridge. Serialized map-cell/object population, provider
quantity/quality lifecycle, route/coverage consumers, and Native projection
remain unknown; the Qin market blocker therefore stays fail-closed.

## 2026-09-02 residential-provider callback follow-up

The already-instantiated residential provider callback map is now centralized
in `OriginalResidentialServiceCatalog.providerCoverageCallbackDescriptors`.
The EN/CH-identical vtable evidence is explicit: Well IDs `72/73` use vtable
`0x7B5EB4` and callback `FUN_0051BC00 @ 0x51BC00`, writing raw
`cHouseInfo +0x32` or `+0x34`; Herbalist `207` uses `0x7B6114` /
`FUN_0051BD00 @ 0x51BD00` → `+0x2D`; Acupuncture `208` uses `0x7B6374` /
`FUN_0051BD90 @ 0x51BD90` → `+0x2A`. Focused tests lock all model, vtable,
callback, and offset values.

This remains a dispatch catalog only. Qin map records are still generic
`Building` objects with provider slot `-1`, and no archive specialization or
registry assignment has been recovered. Provider-to-house projection,
route/collision, and live coverage timing therefore remain unknown; Native
does not invoke these callbacks for Qin and the water blocker stays
fail-closed.

## 2026-09-02 dynamic-factory direct-call census follow-up

The indexed EN/CH corpus was rechecked for the generic object factory
`FUN_0042D360 @ 0x42D360`. Its only direct callers are
`FUN_00427150 @ 0x427150` and `Creating_pctd_type_pctd @ 0x42D540`.
`FUN_00427150` has only one corpus caller, `FUN_00541110 @ 0x541110`, and
that body copies the returned object's `+0x158` from its input; it is not an
archive or provider-registration path. `Creating_pctd_type_pctd` is the
known create/replace helper that writes `object +0xB4` (`+0x2D` in the
provider byte-oriented view) after obtaining a registry entry. Its
residential branch reaches `FUN_0051C660`, but no direct map-loader edge
reaches that branch. All four EN/CH comparison rows are `identical`.

This closes the direct dynamic-factory inventory and strengthens the negative
map-load result. It does not exclude unindexed indirect/table dispatch, nor
recover the archive provider-slot source or provider-to-house projection;
Qin service coverage and migration remain fail-closed.

## 2026-09-02 Trading Quay provider-refresh follow-up

`FUN_0051CCA0 @ 0x51CCA0` is a post-instantiation statistics/consistency
consumer, not the missing Qin trade-object factory. Its classifier
`FUN_005E1720 @ 0x5E1720` returns true only for model 56 (Trading Quay), as
confirmed by the indexed bodies and the `identical` EN/CH rows. Non-56
objects increment `DAT_00A5AF64[model]` and, when vtable `+0x1B4` is positive,
`DAT_00A5AB30[model]`. Model 56 instead appends object `+0xB4`
(`param_1[0x2D]`) to `DAT_0131249C` only while `DAT_00A5B044 < 10`; the same
capacity gate also controls the staffed counter `_DAT_00A5AC10`.
`FUN_004AF230` resets these arrays and counters before walking active objects
and invoking vtable `+0x9C`.

The raw split is now represented by
`OriginalResidentialServiceCatalog.refreshProviderRegistry(...)` and its
regression test. This closes the Trading Quay table-capacity and counter
boundary without assigning a Native trade record: the specialized object,
registry-slot producer, commodity state, route source, and settlement writer
remain unknown. Qin trade and migration remain fail-closed at those edges.

## 2026-09-02 Qin-2 forced-migration boundary follow-up

Two local isolation replays were run against the Qin-2 player flow with the
production availability gate temporarily forced to
`supportedOriginalProducer`; the gate and test skip were restored immediately
after each run. Before the replay, the static `FUN_004AD3D0 @ 0x4AD3D0`
finding was applied: an unoccupied elite (original building model `11`) uses
`house+0x16 + 1` for its pre-arrival capacity lookup. This maps the authored
Native rows `8: Elite: Unoccupied` (capacity `0`) and `9: Elite 0: Abandoned`
(capacity `1`) and is covered by
`DeterministicMigration.assignmentRemainingCapacity`.

With that correction, Qin-2 no longer fails at the earlier “elite housing did
not open for migration” guard. The replay passes the occupied-elite assertion
(`city.houses[level >= 9].residents > 0`) and reaches the final household-goods
delivery assertion, then fails at
`Tests/EmperorGameplayTests/Qin2PlayerPlaythroughTests.swift:396` because no
ceramics delivery is present for an elite house. The earlier route diagnostic
also recorded the authored entry `(52,164)`, `11,860` flood-reachable cells,
and five sampled elite access routes with lengths `134…158`; this rules out a
generic Qin-2 road/entry reachability failure in the current adapter.

This is isolation evidence only, not permission to enable the producer in
mission starts. The remaining failure is downstream of the unresolved market
provider/quality/route/settlement chain (`FUN_00541220`, `FUN_005D5C70`,
`FUN_00543DC0`, and related writers documented in the market sections above).
Qin automatic migration and market settlement therefore remain fail-closed.

**Evidence class:** **confirmed** for the forced-run boundary and assertion
ordering; **unknown** for the market provider record population, household
delivery writer, and Native projection.

## 2026-09-02 market household-pass order follow-up

The missing normal cMarket writer's non-Dinners iteration order is now
recorded from the direct hash-matched EN/CH PE slice for
`FUN_005437B0 @ 0x5437B0` (`0x5437B0…0x543BBB`, SHA-256
`3ef66c67084cb06aca47a741ad44c71304821948834509d5b75597da30678887`). Six
`0x40`-byte records begin at `0x857344`; their first dwords are cMarket record
slots `1…6`, and the preceding dwords are raw commodity keys in this order:
`0x13` Hemp, `0x0D` Tea, `0x19` Ceramics, `0x16` Lacquerware, `0x17`
Bronzeware, `0x18` Silk. Dinners (`0x1C`) is handled by the writer's separate
pre-loop branch. The keys match the authored shop rows in
`GameData/Model/EmperorBuildingModels.txt` and `Trade.txt`.

Native exposes this as the research-only
`OriginalMarketHouseDeliveryPassCatalog`; no campaign code consumes it. This
closes pass ordering and raw slot/key identity only. Provider-record
population, quantity ownership, peddler route/collision state, and the
provider-to-Native house settlement projection remain unknown, so the Qin
market bridge remains fail-closed.

## 2026-09-02 peddler ratio-gate follow-up

The cMarket peddler scheduler's worker-ratio arithmetic is now explicit. In
`FUN_00543ED0 @ 0x543ED0`, `FUN_00544A40` sums authored model-table column 5
for non-Empty-Shop children, while `FUN_00544A80(-1)` sums the admitted Empty
Shop children' raw `+0x44` words. `FUN_00408BA0 @ 0x408BA0` converts those
aggregates to `(rawEmptyChildWorkerUnits * 100) / filledShopEmployeeUnits`,
returning zero for a zero denominator. The scheduler then applies thresholds
`10/5/4/3/2` for the resulting `<25/25…49/50…74/75…99/≥100` bands, increments
the market `+0x36` counter, and requires the incremented value to be strictly
greater than the threshold. cMarket `+0x268` must independently report stock
before model 23 is allocated.

The arithmetic is represented by
`OriginalMarketCatalog.peddlerWorkerPercent` and `peddlerSpawnGate` with a
focused regression. This is not a runtime enablement: the producer/semantic
meaning of cStall `+0x44`, the live child registry, and the route/coverage/
settlement projection remain unknown. Qin therefore continues to use the
fail-closed market gate.

**Evidence class:** **confirmed** for the aggregate inputs, integer ratio,
thresholds, strict counter comparison, and independent stock gate;
**unknown** for `+0x44` production and every downstream Native mapping.

## 2026-09-02 cStall deposit/overflow split follow-up

The cStall cart writer's raw quantity boundary is now explicit, but it does
not unblock the Qin market bridge. In the hash-matched EN/CH body
`FUN_00541760 @ 0x541760` (cStall vtable `+0x260`, identical slice and
constructor chain recorded in `migration-popularity-producer.md` §10.63), the
stall resolves its registered parent record and calls
`FUN_005D2790(record, key, amount)`. That helper writes the key, increments the
quantity, clips only above `record+0xC`, and returns the clipped overflow. The
stall then forwards only that overflow to parent cMarket `+0x154`; the second
parent argument is the cart's separate type-count byte, not a recovered Native
commodity amount. The model-25 cart caller at
`0x4D2970…0x4D2BCA` pushes key `figure+0x88`, type count `figure+0x13`, and
amount `100`.

`OriginalMarketStallDeposit.deposit` records this accepted/overflow split as a
pure helper and has no campaign or settlement caller. Provider registration,
the parent callback's second-argument meaning, monthly/external quantity
population, overflow ownership, and provider-to-house quality/coverage
projection remain **unknown**. Qin automatic migration and market settlement
therefore stay fail-closed.

**Evidence class:** **confirmed** for the cStall vtable/receiver, record lookup,
argument order, upper-capacity clipping, overflow-only parent call, and
model-25 values; **unknown** for provider population and every downstream
Native mapping.

## 2026-09-02 monthly Dinners depletion boundary follow-up

The month-wrap consumer `FUN_00518690 @ 0x518690` is now represented by the
pure `OriginalMarketMonthlyFoodDepletion` helper. The EN/CH-identical body
reads model column `8`, computes `floor(residents * 25 / 100)`, and in the
normal branch subtracts that draw from cHouseInfo `+0x12` only when the
requirement is positive. A shortfall drains the remaining stock and clears
the raw quality byte at `+0x36`; zero requirement leaves both fields alone.
The separate cheat branch replaces stock with the draw and writes quality
`20`, without contributing to the normal consumed-total counter. Focused
tests cover each branch.

This closes only the month-boundary raw field arithmetic. It does not identify
the market provider-record population, the callback that supplies Dinners, or
the Native settlement projection, so campaign Qin market settlement and
automatic migration remain fail-closed. **Evidence class:** **confirmed** for
the function/caller, 25% draw, branch ordering, quality clear, cheat write,
and vector-level consumed counter; **unknown** for provider ownership and
all downstream Native mapping.

## 2026-09-02 Ferry placement terrain-index follow-up

The Ferry placement flood helper was corrected after a fresh instruction-level
read of EN/CH-identical `FUN_005B33C0 @ 0x5B33C0`. The source does not read all
terrain-block bytes at the candidate cell: north uses the north candidate
(`idx2 - 0xE4`), while east, south, and west use the current cell (`idx2`),
with the west byte coming from the direction-specific zero-offset table. East
passability alone is candidate-indexed; north/south/west passability is
current-indexed. `OriginalGrandCanalLayoutCatalog.deriveFerryPlacementFlood`
now models those exact index choices, and a focused test independently blocks
east via only the current terrain byte and north via only the candidate byte.

This closes a previously over-generalized research helper boundary but does
not map the PE layer arrays into Native map state or wire Ferry placement and
connector persistence. Qin reachability and the migration producer therefore
remain fail-closed. **Evidence class:** **confirmed** for the four directional
index expressions and EN/CH identity; **unknown** for Native layer projection,
placement integration, and serialized connector ownership.

## 2026-09-02 Qin-3 peddler endpoint scan follow-up

The exact pre-arbitration rectangle scan is now captured in
`OriginalMarketPeddlerEndpointScan.rectangularPoints`. The EN/CH-identical
`FUN_004BA370 @ 0x4BA370` computes the inclusive x/y bounds from the selected
anchor, cMarket span, and retry rotation, clamps each bound to the map, and
walks y-major/x-minor. `FUN_004BA580 @ 0x4BA580` retries rotations in strict
`0…param4` order; the peddler caller passes `2`.

This closes only candidate enumeration order. The span's cMarket `+0x1C`
meaning, object callback adjustment, primary-cache route projection,
collision/resource consumers, and provider-to-house coverage/settlement
remain unresolved. The helper is therefore research-only and is not wired to
the Qin producer or campaign scheduler; the production gate remains
fail-closed.

**Evidence class:** **confirmed** for formulas, clamping, traversal order,
retry order, and EN/CH parity; **unknown** for span semantics and all live
route/coverage/settlement mappings.

## 2026-09-02 Qin market primary-cache follow-up

The cMarket access-cache writer is bounded by the EN/CH-identical
`FUN_005B1080 @ 0x5B1080` and its call from `FUN_00541220 @ 0x541220`.
It clears and seeds `DAT_01391FE0`, then expands cardinally with mask
`0x010C`, but its north read uses the primary layer at the north candidate,
its east/south/west reads use their direction layers at the current index,
and it writes four offset views (`DAT_01391C50`, `DAT_01391FE4`,
`DAT_01392370`, `DAT_01391FDC`) of the central `DAT_01391FE0` cache.
`OriginalMarketAccessFlood.build` preserves that mixed-index contract.

This corrects the cache contract without providing the missing Native layer
projection, provider registry, cMarket callback effects, or provider-to-house
quality/coverage settlement. No Qin runtime wiring was enabled; the
production market/migration gate remains fail-closed.

**Evidence class:** **confirmed** for the control-flow call, mask, mixed
indexing, output-buffer aliases, and EN/CH parity; **unknown** for Native
layer mapping, exact consumer semantics, and all live market settlement edges.

## 2026-09-02 Shared market/venue directional flood follow-up

The two neighboring expanders used by the original candidate-search family
are now represented by `OriginalDirectionalAccessFlood.build`. Static bodies
`FUN_005B0220 @ 0x5B0220` and `FUN_005B0360 @ 0x5B0360` are EN/CH-identical and
share the four current-cell-indexed PE layers and north/east/south/west queue
order; their recovered masks are `0x010C` (mode zero) and `0x0B0C` (nonzero
mode). No market wrapper is inferred from this helper.

This narrows a reusable route/cache primitive but does not solve the Qin
blocker: the four PE layers still have no proven Native projection, and no
provider registration, occupancy, route terminal, or house-quality/coverage
settlement edge has been recovered. Qin market and entertainment behavior
therefore remains fail-closed.

**Evidence class:** `confirmed` for the masks, layer operands, current-cell
indexing, queue order, and EN/CH parity; `unknown` for the Native layer
projection and downstream provider/settlement contracts.

## 2026-09-04 Qin-3 model-23 route-mode follow-up

The first route mode used by the market peddler is now closed at the
constructor boundary. In both canonical PEs, `FUN_004C71D0 @ 0x4C71D0`
installs the common figure vtable and calls `FUN_004C72B0`, whose zero-init
includes figure `+0x80`. The model-23 virtual initializer
`FUN_004C9160 @ 0x4C9160` writes the model/coordinate/heading fields but does
not write `+0x80`; the peddler allocation in `FUN_00543ED0` therefore reaches
`FUN_004E83E0 @ 0x4E83E0` with route mode `0`.

Mode 0 dispatches to the EN/CH-identical `FUN_005AE740 @ 0x5AE740`. It calls
`FUN_00521140` to clear the `0xCB10`-entry depth table, seeds the current
linear map index, and expands north/east/south/west through
`FUN_005AE840 @ 0x5AE840`. Each neighbour is admitted only when its
direction-specific layer word intersects mask `0x0B1D`; the queue wraps at
`0xCB10` entries and the map row stride is `0xE4`. The resulting depth table
is queried for reachability of the destination index.

Native records these inputs in
`OriginalMarketPeddlerRouteSearchDescriptor.canonical` and keeps them as a
pure research descriptor. The four PE layer projection, cMarket endpoint
selection/consumer, collision rejection, and provider-to-house settlement
are still not recovered, so no Qin campaign route or coverage behavior is
enabled from this result.

**Evidence class:** `confirmed` for constructor writes, default mode, helper
addresses, mask, four-way order, queue capacity, stride, and EN/CH parity;
`unknown` for Native layer mapping and every route-terminal/settlement edge.

## 2026-09-04 Qin-3 model-23 return-route dispatch follow-up

The peddler's return request is now bounded through the complete indexed
caller chain. `FUN_004E3A80 @ 0x4E3A80` clears the figure's `+0x6F` active
marker, applies `FUN_004E3A10 @ 0x4E3A10` (the recovered `4/5` travelled-budget
and saved-coordinate gate), then chooses its endpoint source from the linked
object class word. Class words `0x3B` and `0x3C` are the Common/Grand Market
objects; those use `FUN_00544910 @ 0x544910` → `FUN_00543160` and the shared
market entrance coordinates. Other linked objects call their virtual
`+0x19C` endpoint method; the returned coordinates are not semantically
resolved in Native.

Both branches call EN/CH-identical `FUN_004BA580 @ 0x4BA580` with maximum
rotation `2`, so the endpoint scan attempts rotations `0`, `1`, and `2` in
that order. On success the handler writes the selected target to figure
`+0x2C/+0x2E`, sets figure `+0x40 = 2`, clears the route through
`FUN_004E8A30 @ 0x4E8A30`, and resets travelled budget `+0x4C` to zero. A
failed route sets figure `+0x16 = 2`; it does not invent a fallback route.
Native records this dispatch/state contract in
`OriginalMarketPeddlerReturnRouteDescriptor.canonical`, but does not enable
campaign peddlers because the PE-layer endpoint consumer, collision
rejection, provider records, and house-quality/coverage settlement remain
unknown.

**Evidence class:** `confirmed` for branch class words, gate/route calls,
rotation order, success/failure writes, and EN/CH parity; `unknown` for the
non-market virtual endpoint's semantic coordinates and all downstream Qin
settlement effects.

## 2026-09-02 CR correction: directional-layer indexing and market buffers

The preceding shared-flood note was corrected after a direct pointer-arithmetic
re-read. `FUN_005B0220 @ 0x5B0220` and `FUN_005B0360 @ 0x5B0360` read all four
directional layers at the current queue index; only the destination cache
slot and queued neighbor use the directional offset. `OriginalDirectionalAccessFlood`
now preserves that current-cell indexing, with a regression case that would
fail under candidate-cell indexing.

`FUN_005B1080 @ 0x5B1080` remains a distinct market routine: its north read
uses the primary layer at the north candidate, while east/south/west read
their layers at the current index, and its four writes are offset views of
the central `DAT_01391FE0` cache. `OriginalMarketAccessFlood.build` preserves
that mixed-index relationship. No Qin market, provider, route, or settlement
runtime path was enabled.

**Evidence class:** `confirmed` for the corrected indexing, masks, output
buffers, and EN/CH parity; `unknown` for Native layer projection, market
buffer consumers, provider registration, and settlement.

## 2026-09-02 Direct-layer route boundary

The source-backed route surface now separates two inputs that must not be
conflated. `FUN_004E83E0 @ 0x4E83E0` dispatches mode `0x12` to
`FUN_005B00D0 @ 0x5B00D0`, whose zero-mode expander is
`FUN_005B0220 @ 0x5B0220`; that expander consumes four directional PE layers,
not a Native single-array passability projection. The new
`OriginalGrandCanalLayoutCatalog.entertainmentVenueDirectionalRoute` and
`marketPeddlerDirectionalRoute` first apply the recovered
`OriginalDirectionalAccessFlood.build` contract (all four layers read at the
current queue cell), then apply the selector-4/cardinal and selector-8
fallback reconstruction boundary. The mixed north-candidate/east-south-west-
current contract belongs only to the separate `FUN_005B1080` market cache
writer and `OriginalMarketAccessFlood.build`.

The directional route entry point is fail-closed for the remaining
reconstruction unknown: if a cardinal reconstruction has multiple equally
close candidates, it returns no route because the original
`FUN_005B2730`/RNG tie-break has not been recovered. It uses the eight-way
fallback only when the cardinal route has no solution, never as a substitute
for an unresolved cardinal tie.

The existing single-array route helpers remain pure projected-cache tests only;
they are not used by Qin scheduling and do not establish the missing map-layer
projection. A regression case proves that the east layer is read at the
current queue cell: admitting the first edge but not the second rejects the
three-cell route, while admitting both current cells succeeds.

This advances the route/cache boundary and closes only the no-tie route subset,
but leaves the Qin gate closed. PE-layer projection, cMarket/provider registry
population, endpoint and collision state, equal-distance RNG arbitration, and
provider-to-house quality/coverage settlement remain **unknown**.

**Evidence class:** `confirmed` for the direct call chain, input shape,
current-cell indexing, and route reconstruction split; `unknown` for all
Native projection and downstream market/entertainment effects.

## 2026-09-02 `FUN_005B18B0` equal-distance reconstruction correction

The preceding direct-layer note incorrectly treated equal-distance
reconstruction as an unresolved RNG boundary. A direct disassembly of the
canonical English PE (`0x5B18B0…0x5B1B20`) shows no RNG read or call. The
English and Chinese split rows for `FUN_005B18B0 @ 0x5B18B0` and
`FUN_005B2730 @ 0x5B2730` are both `identical` in
`local/source/compare-report.tsv`.

The reconstruction loop is deterministic: it rejects zero-valued neighbors,
accepts a strictly smaller flood value, and for an equal value first accepts
the direction returned by `FUN_005B2730` (the direct heading toward the
origin). If that direction is absent, the first remaining entry in the
`DAT_0085DE64` direction table wins. After each step it stores the opposite
direction (`n + 4`, wrapped at eight) as the next-step prohibition. The
selector-4 path scans direction entries `0,2,4,6`; selector-8 scans all eight,
and both paths stop at 499 stored steps. This is the source behavior already
represented by `routeFromDistances`; the `failOnTie` rejection was an
unsupported Native guard and has been removed.

The regression case now covers a fully admitted `2×2` cardinal tie. From
`(0,0)` to `(1,1)`, the direct diagonal heading is not in selector-4, so the
source chooses direction `0` first while reconstructing backward and emits
the forward route `(0,0) → (1,0) → (1,1)`. This closes the route
reconstruction tie policy, but does not close directional-layer projection,
endpoint/collision state, provider registry, or market/venue settlement.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005b18b0.c`,
`FUN_005b2730.c`, `local/source/compare-report.tsv`, and the canonical PE
disassembly at `0x5B18B0…0x5B1B20`; `Sources/EmperorCore/GrandCanalSimulation.swift`;
`Tests/EmperorCoreTests/GrandCanalSimulationTests.swift`.

**Evidence class:** **confirmed** for deterministic strict-lower/direct-heading/
first-entry tie order, opposite-direction prohibition, selector stride, and
EN/CH identity; **unknown** remains for PE-layer production and all downstream
provider/settlement edges.

## 2026-09-02 Qin routing occupancy predicate closure

The occupied-cell branches of `FUN_005AD440 @ 0x5AD440` and
`FUN_005223B0 @ 0x5223B0` call the live object's vtable `+0xCC`. A direct
little-endian read of both hash-matched PE images closes this callback for the
Qin classes that can occur in the mission flow: HouseBldg `3...17`, Stoneworks
`36`, Warehouse/Trading Quay/Trading Station `54/56/58`, Common/Grand Market
Squares `59/60`, Entertainment Area `71`, Well `72/73`, Herbalist `207`,
Acupuncturist `208`, and Laborers' Camp `233`. Their vtables (`0x7ABA38`,
`0x7B75E0`, `0x7BE1BC`, `0x7BEAB8`, `0x7BEDC4`, `0x7B6F3C`, `0x7AD878`,
`0x7B5EB4`, `0x7B6114`, `0x7B6374`, `0x7B4FF8`) all contain
`+0xCC → 0x00416A50`. The direct body bytes at `0x416A50` are
`32 C0 C2 08 00` (`xor al,al; ret 8`), identical in EN/CH, so the result is
confirmed false rather than a default inferred from visible blocking.

`BuildingFootprintPredicateCatalog` records this exact ID set. Native routing
now passes the recovered false result only for these classes; an unlisted
placed building leaves the callback nil and fails closed. This removes one
source-level approximation from the Qin route projection but does not close
the PE-layer projection, cMarket/provider registry, endpoint/collision, or
provider-to-house quality/coverage settlement blockers. The Qin-3 completion
test therefore remains intentionally skipped at 27/40 houses and below level
6.

**Evidence class:** `confirmed` for the vtable words, callback bytes, and ID
set; `unknown` for all remaining route-layer and market/entertainment live
state mappings.

## 2026-09-02 Venue selector-switch contract closure

The complete `FUN_004E47A0 @ 0x4E47A0` switch is now recorded as a pure
`OriginalResidentialServiceCatalog.entertainmentVenueMovementUpdatePlan`
helper. Direct source inspection of
`local/source/split-merged/code/0x040000/FUN_004e47a0.c` confirms the exact
update-count and `+0x170` phase transition for selectors `0…17` and the
default branch. The venue FSM's selector `8` remains the only selector bound
to figures `32…34` by the recovered `0x48A9A0` entry path; its states are
`phase 0→1` with one update, `1→2` with one update, and `2→0` with two
updates. The helper's branch table is regression-tested independently of
simulation.

This is a `confirmed` raw scheduling contract for the canonical EN executable
(`8a6d2df1…9d6753`); the CH executable (`dbdeca1e…ac15a`) is identical for
the function. It does not supply the missing venue provider registry, PE-layer
projection, endpoint/occupancy and collision effects, or provider-to-house
settlement. Qin-3 therefore remains fail-closed and the player completion
replay remains intentionally skipped.

## 2026-09-02 Selector-8 clock deduplication

The confirmed selector-switch helper is now reused by the existing Native
compatibility clocks in `WalkerSimulation.swift` and `MarketSimulation.swift`.
The road-service path calls it only for movement code `8` and keeps the prior
one-substep fallback for every other code; buyer and peddler paths pass the
already recovered selector `8`. This is a mechanical consolidation of the
source-backed `1,1,2` phase cadence, covered by the selector branch regression;
it does not register venue providers, project PE layers, resolve endpoint or
collision callbacks, or perform provider-to-house settlement. Qin-3 remains
fail-closed at the same unresolved downstream boundary.

**Evidence class:** `confirmed` for the shared selector-switch contract and
the existing call-site selector values; `unknown` for all venue/provider live
state and Qin completion consequences.

## 2026-09-02 Water provider `+0x6F` decay boundary

The provider-state audit now also captures the scheduler-wrap decay in
`FUN_0042DA70 @ 0x42DA70`, called by `FUN_004AC650` after the `0x33`-phase
cycle. With the global gate open, a non-zero `+0x6F` decrements once and a
one-byte value invokes vtable `+0x100` exactly when it reaches zero; closed
gate and already-zero inputs are no-ops. The pure
`OriginalWaterProviderState.decayCommandState` helper and focused regression
test encode those cases. This narrows water's command-state timing but does
not recover provider registry ownership, callback side effects, or the
map-loaded Qin bridge, so Qin water coverage remains fail-closed.

**Evidence class:** `confirmed` for the scheduler caller, gate, decrement,
expiry condition, and callback argument shape; `unknown` for provider
registration and callback/house settlement effects.

## 2026-09-02 Residential spawn-threshold catalog closure

The already recovered `FUN_0051CF90 @ 0x51CF90` strict spawn comparison is now
represented by one centralized Native research primitive,
`OriginalResidentialServiceCatalog.residentialSpawnThreshold`. Its rows are
the tax/Herbalist override `1/3/5/10/15`, the Well override with the same
non-zero bands plus its explicit `+0x224` input-doubling gate, the Acupuncture
row `1/3/7/15/29`, and the Religion selector `3/6/12/24/32`, each ordered by
the source worker bands `100+`, `75…99`, `50…74`, `25…49`, and `1…24` (the zero
worker input returns the last selector value but remains blocked by the
separate `worker > 0` gate). A regression test covers every boundary and
rejects unsupported figure `34`.

The generic walker now consumes this catalog instead of duplicating the table
inside `WalkerSimulation`. This does not enable entertainment figures or
provider creation: the source access gates, provider registry, figure
allocation, route/collision, and coverage writers remain unresolved. Qin-3's
music, water, market, and desirability blockers therefore remain fail-closed.

**Evidence class:** `confirmed` for threshold rows and strict table parity;
`unknown` for provider-side effects and the four remaining Qin-3 contracts.

## 2026-09-02 Routing-cache callers may omit an already recovered `+0xCC` result

The `FUN_005AD440 @ 0x5AD440` and `FUN_005223B0 @ 0x5223B0` occupied-cell
branches both consult the live object's vtable slot `+0xCC`. The direct
predicate body is already recovered as constant false for the building IDs in
`OriginalGrandCanalLayoutCatalog.BuildingFootprintPredicateCatalog` (the
canonical EN/CH vtable rows and the `FUN_00416A50 @ 0x416A50` body are
identical). A Native caller that supplied only one of those authored IDs was
previously rejected because the per-cell `genericFootprintPredicate` field
was nil, even though the independent catalog had already established the
same result.

The cache adapter now resolves a missing per-cell value through that catalog
in both builders. It still throws `missingGenericFootprintPredicate` for an
unlisted ID and still rejects a supplied `true` result in the primary branch;
no unresolved model-family or vtable behavior is collapsed. A focused test
compares an omitted and explicit-false Warehouse `54` cell (primary `0x2`,
fallback `0x4`) and verifies that unknown building `37` remains fail-closed.

This is a **confirmed** input-normalization closure only. It does not recover
the map-object registry, PE-layer projection, market/venue provider records,
or downstream Qin settlement, so the Qin-3 completion gate remains closed.

## 2026-09-02 Map archive version gates are explicit

The map serializer `FUN_0052E7C0 @ 0x52E7C0` reads the variable-size
`Building` archive only when the decoded archive schema is greater than `3`;
the trailing `DAT_00F2B290` road/water auxiliary grid is read only when the
schema is greater than `4`. These branches are present in both canonical
English and Chinese executables and are independent of the later generic
`FUN_0042D790` callback boundary. Native now records the exact predicates in
`OriginalMapArchiveRepairCatalog` and tests versions `3/4/5` directly.

This closes the format-version gate and prevents legacy map bytes from being
treated as a provider/object stream. It does not provide a Qin provider
registry index, generic-record model identity, or post-load specialization;
those remain `unknown`, so the market, water, entertainment, and automatic
migration bridges stay fail-closed.

**Evidence class:** `confirmed` for the serializer address, strict version
comparisons, and EN/CH parity; `unknown` for archive object semantics and
provider projection.

## 2026-09-02 Map-loaded object callback eligibility byte is explicit

The body of `FUN_0042D790 @ 0x42D790` inserts each decoded object and then
checks `(char)local_18[1]` before invoking its vtable `+0xC0` load callback.
Because `local_18` is the object base pointer returned by
`FUN_0042D0E0 @ 0x42D0E0`, the raw condition is object offset `+0x04`: zero
skips the callback and any non-zero byte invokes it. The loop also records the
last eligible index in `DAT_00C82EE0`; this condition is independent of the
archive schema gates and does not perform provider specialization. The EN/CH
rows for `0x42D790`, `0x42D0E0`, and `0x5F01F0` are `identical` in
`local/source/compare-report.tsv`.

Native records this byte/branch as
`OriginalMapArchiveRepairCatalog.loadCallbackEligibilityFieldOffset` and
`invokesLoadCallback(eligibilityByte:)`. The field's semantic name, its
serialized producer, and any relationship to provider registry assignment are
**unknown**; no Qin provider callback is enabled from this predicate alone.

**Evidence class:** `confirmed` for the offset, zero/non-zero branch, loop
ordering, and EN/CH parity; `unknown` for field semantics, archive producer,
and provider/object projection.

## 2026-09-02 Main map-load tail has no recovered provider projection edge

The direct callees in the canonical map-load wrapper
`FUN_0052FDA0 @ 0x52FDA0` were read from the indexed EN corpus after the
generic object loader returns.  The relevant order is
`FUN_0042D790` (object archive), `FUN_004E1E40`, the `FUN_00506240` and
`FUN_00480740` serializer objects, `FUN_00510E60`, `FUN_00564E30`,
`FUN_00593140`, `FUN_0052CD90`, `FUN_00493F00`, the repeated
`FUN_005501B0` table records, and the later map/grid initializers.  The
EN/CH comparison row for `0x52FDA0` is `identical`.

The inspected bodies provide the following hard boundaries:

* `FUN_004E1E40 @ 0x4E1E40` iterates an existing object vector, invokes each
  object's vtable `+0xF8`, and updates the last qualifying index.  It has no
  `FUN_0042D360`, `FUN_0051C660`, `FUN_0051BEF0`, or provider-slot write.
* `FUN_00510E60 @ 0x510E60` scans fixed state records and, for active entries,
  resolves an already-existing object through `FUN_0047F1B0`; it clears or
  updates state fields and does not construct a `Building` or service object.
* `FUN_00564E30 @ 0x564E30` only repeats `FUN_0056AB00` over a fixed table.
  `FUN_0056AB00 @ 0x56AB00` creates `WorkerCommodityItem` records through
  `FUN_0056F300 → FUN_0077FD90`, then inserts them with `FUN_005F01F0`;
  this is a worker/commodity registry, not the residential-service factory.
* `FUN_00517CC0 @ 0x517CC0` calls `FUN_00517DE0`, which aggregates counts from
  the existing object vector and stores two totals.  `FUN_005A7C40 @ 0x5A7C40`
  resets four fixed disaster tables and dispatches existing objects; neither
  function allocates a provider or writes its `+0x2D` parent link.
* `FUN_00593140`, `FUN_0052CD90`, and `FUN_00493F00` are serializer bodies;
  their field reads/writes contain no service factory, generic-to-specialized
  conversion, or provider-registry insertion.  `FUN_00506240` and
  `FUN_00480740` return serializer-object addresses only.

The separate post-load repair switch is already bounded by
`FUN_0052F1D0 → FUN_0052F030`; its admitted IDs exclude Well/Herbalist/
Acupuncture.  Combining that negative with this direct tail audit closes the
remaining “ordinary map-load tail might specialize providers” hypothesis in
the recovered call graph.  It does **not** recover an indirect/table-driven
dispatch, the serialized provider-index producer, or final registry insertion;
those remain **unknown**, so Native must keep Qin-3 service projection and
automatic migration fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004e1e40.c` and
`FUN_00493f00.c`; `local/source/split-merged/code/0x050000/FUN_00510e60.c`,
`FUN_00517cc0.c`, `FUN_00517de0.c`, `FUN_0052cd90.c`, `FUN_0056ab00.c`,
`FUN_0056f300.c`, `FUN_00564e30.c`, `FUN_00593140.c`, and `FUN_005a7c40.c`;
`local/source/compare-report.tsv` rows `0x52FDA0`, `0x4E1E40`, `0x510E60`,
`0x517CC0`, `0x52CD90`, `0x564E30`, `0x56AB00`, `0x56F300`, `0x593140`,
and `0x5A7C40`.

**Evidence class:** `confirmed` for the direct call order, inspected bodies,
and EN/CH identity; `unknown` for unindexed indirect/table-driven edges,
archive provider-index production, and final provider-registry projection.

## 2026-09-02 Qin migration house access now uses recovered component ranking

`FUN_004BA6F0 @ 0x4BA6F0` does not choose an arbitrary or coordinate-sorted
adjacent road.  It indexes the exact `DAT_00820038` perimeter row selected by
the house object's serialized footprint side (`2` for common vacant houses,
`4` for elite vacant houses), walks the clockwise offsets in table order, and
keeps the first candidate whose dry-road cell belongs to the best ranked road
component.  The component ranks come from `FUN_004AF350 → FUN_004AF490` and
are limited to the ten largest components; the comparison is strict, so equal
ranks preserve perimeter order.  The EN/CH comparison rows for `0x4BA6F0`,
`0x4AF350`, and `0x4AF490` are `identical`.

Native's campaign-backed immigrant assignment now derives the same component
rank map from the recovered terrain and primary routing grids, then calls the
source-backed `DeterministicMigration.recoveredHouseRoadAccessPoint` helper.
This replaces the previous coordinate-sorted adjacency choice for real Qin
maps and makes a candidate unavailable when the recovered source inputs cannot
produce a ranked road component.  The helper intentionally stops before the
unresolved object `+0xD0` adjustment and map-object registry projection. Core
fixture cities with no authored terrain retain their explicit compatibility
access rule only; that path is not used by campaign-backed missions.

The perimeter order is covered by
`MigrationSimulationTests.testRecoveredHouseRoadAccessUsesOriginalPerimeterAndComponentRank`.
This closes only the house-access arbitration subset.  Provider registry
population, object-adjusted candidates, and provider-to-house settlement stay
**unknown**, so automatic Qin migration remains fail-closed in campaign
starts.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ba6f0.c`,
`local/source/compare-report.tsv` rows `0x4BA6F0`, `0x4AF350`, `0x4AF490`,
`docs/exe-research/migration-popularity-producer.md` §5.7a/§10.36c, and
`Sources/EmperorCore/MultipartMonumentRoutingCatalog.swift`.

**Evidence class:** `confirmed` for perimeter table order, strict component
ranking, source parity, and the Native campaign call path; `unknown` for
object-adjustment and provider/registry projection.

## 2026-09-02 Residential provider-link slot contract

The HouseBldg service-link validators expose three distinct raw slots. In the
canonical EN executable, `FUN_00429700 @ 0x429700` reads the house-object
short at `+0x2E`; `FUN_00429780 @ 0x429780` reads `cHouseInfo +0x6A`; and
`FUN_00429810 @ 0x429810` reads `cHouseInfo +0x6C` through the house's
`+0x1E8` accessor. `FUN_004291A0 @ 0x4291A0` counts the same three links for
the untyped service scan. The EN/CH comparison rows for all four functions
are `identical`.

For the typed validators, the resolved provider must be active (provider
byte `+0x16 != 0`), its type byte (`+0x12`) must equal either caller-supplied
type argument, and its parent word (`+0x62`) must equal the house registry ID
(`house +0x2D`). The `FUN_004291A0` `param_2 == 0` branch omits the type
comparison but retains the active and parent-ownership checks. A failed link
clears the corresponding short slot to zero in the validator that owns it.

Native now records these offsets and pure predicates in
`OriginalResidentialProviderLinkCatalog`. The helper is research-only: the
Qin archive still has no recovered provider-registry source or post-load slot
projection, so no `ResidentialUnit` state or campaign simulation path uses
these predicates. This closes the house-side validation contract while
leaving provider object creation, registry assignment, and provider-to-house
settlement **unknown**.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004291a0.c`,
`FUN_00429700.c`, `FUN_00429780.c`, and `FUN_00429810.c`;
`local/source/compare-report.tsv` rows `0x4291A0`, `0x429700`, `0x429780`,
and `0x429810`; `Sources/EmperorCore/HousingEvolution.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** `confirmed` for slot offsets, active/type/parent checks,
failure-clearing behavior, and EN/CH identity; `unknown` for serialized
provider-registry production, post-load assignment, and the Native projection.

## 2026-09-02 Festival popularity adjustment contract

The festival adjustment is not part of the regular `FUN_00591200 @ 0x591200`
factor sum.  The positive phase `FUN_0048EA40 @ 0x48EA40` computes the current
season with `FUN_0052CA40(DAT_00D623FC)`, compares it with the festival season
from `FUN_00413BC0`, and writes `DAT_01312500` as `12` when they differ or
`18` when they match before adding it to `DAT_0130F974`.  The negative phase
`FUN_0048EAF0 @ 0x48EAF0` first requires population `> 350` and at least one of
`DAT_00C5CE7E`, `DAT_00C5CE80`, or `DAT_00C5CE82` to be nonzero; it then writes
`-12` for a differing season or `-18` for a matching season and adds the value
to the same popularity word.  The bitwise expressions are
`(-(ret2 == ret) & 6) + 0xC` and `(-(ret2 != ret) & 6) - 0x12`, respectively.

`FUN_0048EB90 @ 0x48EB90` confirms the event boundary: it calls
`FUN_0048E930` for festival eligibility, uses the population gate and the
three qualification bytes before selecting event IDs `0xD4…0xD9`, and
schedules the two adjustment callbacks while a festival is active.  The
season resolver `FUN_0052CA40 @ 0x52CA40` returns a normalized `0…11` month
value; `FUN_00413C20 @ 0x413C20` reads the event object's season word at
`+0x21`.  EN/CH comparison rows for `0x48EA40`, `0x48EAF0`, `0x48EB90`,
`0x48E930`, `0x52CA40`, and `0x413C20` are `identical`.

Native records these formulas as the pure
`DeterministicMigration.originalFestivalPositiveEffect` and
`originalFestivalNegativeEffect` helpers with boundary tests.  They are not
wired into `updateMigrationPopularity`: the writers and lifecycle for the
three qualification bytes, the active event object, and the season source are
not yet mapped to campaign state.  Automatic Qin migration therefore remains
fail-closed, and no festival state is synthesized from event text alone.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0048EA40.c`,
`FUN_0048EAF0.c`, `FUN_0048EB90.c`, `FUN_0048E930.c`,
`FUN_00413C20.c`; `local/source/split-merged/code/0x050000/FUN_0052CA40.c`;
`local/source/compare-report.tsv`; `Sources/EmperorCore/MigrationSimulation.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** `confirmed` for both raw adjustments, population and
qualification gates, callback ordering, season normalization, and EN/CH
identity; `unknown` for qualification-byte writers, active event-object
serialization, and campaign-state projection.

## 2026-09-02 Directional routing storage views

The venue/peddler route blockers now have a precise storage boundary. The
original `FUN_005AD920 @ 0x5AD920` clears `0x6588` DWORDs—exactly one
`228×228` map of 16-bit cells—beginning at `DAT_013789C0`, and
`FUN_005AD8F0 @ 0x5AD8F0` rebuilds it with
`FUN_005AD440 @ 0x5AD440`. `FUN_005B0220` and `FUN_005B0360` read that same
cache through four aliases: north `DAT_013787F8` (`-0x1C8` bytes), east
`DAT_013789C2` (`+2`), south `DAT_01378B88` (`+0x1C8`), and west
`DAT_013789BE` (`-2`). The `0x1C8` delta is `2 × 228`, the canonical
16-bit row stride. The reset/rebuild functions and both flood readers are
`identical` in the EN/CH comparison report.

This closes the PE cache/view arithmetic but not the producer's terrain-word,
object-callback, or live map projection semantics. Native exposes only the
read-only `OriginalDirectionalLayerViews` index/value helper and keeps the
Qin venue, peddler, and provider routes fail-closed until the central cache
producer and settlement edges are recovered.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005ad920.c`,
`FUN_005ad8f0.c`, `FUN_005ad440.c`, `FUN_005b0220.c`, and
`FUN_005b0360.c`; `local/source/compare-report.tsv` rows `0x5AD440`,
`0x5AD8F0`, and `0x5AD920`; `Sources/EmperorCore/MarketSimulation.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** `confirmed` for shared storage, alias offsets, row stride,
and EN/CH identity; `unknown` for cache generation and Native projection.

## 2026-09-02 Event-driven neighboring-cell invalidation boundary

The indexed EN/CH corpus also closes one separate map-cell write boundary.
`FUN_00492430 @ 0x492430` advances only event records whose raw byte at
`+0x0A` equals `5`, and dispatches their state machine through
`FUN_004ED3B0 @ 0x4ED3B0`. In state zero, `FUN_004ED4C0 @ 0x4ED4C0` scans the
map using the canonical `0xE4` row stride. Its admitted cells pass the
`FUN_00416C20`/`FUN_00408CF0` predicates, have terrain/object flag
`0x04000000`, pass `FUN_004ED6D0`, and carry the event's byte marker. The
state then advances with an eleven-tick delay before the next sweep.

For an admitted center cell, `FUN_004ED700 @ 0x4ED700` probes exactly eight
neighbor offsets in this order:
`[-0xE4, +1, +0xE4, -1, -0xE3, +0xE5, +0xE3, -0xE5]`. Each neighbor is
checked by `FUN_004ED7E0`; an admitted neighbor is written by
`FUN_004ED840 @ 0x4ED840`, which ORs its map word with `0x04000100`, writes
the event byte as `param+0x10` plus one, and stores routing-cache value `2`
at `DAT_013789C0[index]`. The writer may additionally invoke object vtable
slots `+0x0C8`, `+0x268`, `+0x148`, `+0x138`, clear object-side house-info
words, and set linked figure state byte `+0x16` to `2`; those callbacks and
their object ownership remain unresolved.

`FUN_004ED3B0` is reached from the event loop in `FUN_00492430`, itself called
by the periodic `FUN_00466E90` update. `FUN_004ED5A0` provides the reverse
state sweep and clears `0x04000000`/the event byte after the matching delay.
The inspected functions (`0x466E90`, `0x492430`, `0x4ED3B0`, `0x4ED4C0`,
`0x4ED5A0`, `0x4ED700`, `0x4ED840`, `0x4EDA50`, `0x4EDCD0`) are all
`identical` in `local/source/compare-report.tsv` for EN and CH.

Native records the exact addresses, masks, row stride, event-byte increment,
and eight-offset fanout in `OriginalMapCellInvalidation`; its regression test
is arithmetic-only. This does **not** identify the type-byte-5 event's
semantic label, the `0x04000000` flag producer, the callback side effects, or
the projection of this cache write into Qin simulation. No live Native
terrain/object/figure mutation is enabled from this boundary.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00492430.c`,
`FUN_004ed3b0.c`, `FUN_004ed4c0.c`, `FUN_004ed5a0.c`, `FUN_004ed700.c`,
`FUN_004ed7e0.c`, `FUN_004ed840.c`, `FUN_004eda50.c`, `FUN_004edcd0.c`,
`FUN_00466e90.c`; `local/source/compare-report.tsv` rows listed above;
`Sources/EmperorCore/OriginalMapCellInvalidation.swift`;
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the event-loop edge, state/sweep order,
neighbor offsets, masks, routing-cache write, event-byte increment, and EN/CH
identity; **unknown** for event semantics, flag production, callback effects,
and Native projection.

## 2026-09-02 cStall `+0x44` producer attribution correction

The previous note incorrectly attributed cStall `+0x44` production to the
general workforce allocator. A direct cross-check now disproves that edge:
`FUN_00544B30 @ 0x544B30` creates the market child with model `0x3E` (the
authored `Empty Shop`, row 62), while `FUN_004AD850 @ 0x4AD850` only writes
`+0x44` after predicates `FUN_0042B720`/`FUN_0042B730` accept model IDs
`0x83`/`0x82`. Those are a separate object family, so that writer cannot be
claimed as the Empty-Shop field's producer.

The generic object-update path `FUN_004E7EB0 @ 0x4E7EB0` is reached through
the global update loop (`DAT_010AEEE4`) and must not be typed as cStall or
Empty Shop: its callers also drive the shared figure/state-machine path. It
resets `+0x42/+0x44/+0x46` when an object update starts, then increments
`+0x44` once each time its 20-substep counter wraps, after recomputing object
state and animation through `FUN_004E83E0`, `FUN_004E8B40`, and
`FUN_004E8BC0`. This proves only a generic periodic raw write to the same
offset. `FUN_00544A80` still reads child `p[0x11]`; no cStall-specific writer
or complete producer/consumer ownership is established by this trace.

`FUN_004E7EB0`, `FUN_004E7FD0`, `FUN_004E83E0`, `FUN_004E8B40`,
`FUN_00544B30`, `FUN_00543ED0`, and `FUN_00544A80` are `identical` EN/CH rows
where present in `local/source/compare-report.tsv`. The earlier allocator
helper and test were removed; no runtime behavior was enabled.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004e27e0.c`,
`FUN_004e3a80.c`, `FUN_004e6d80.c`, `FUN_004e7eb0.c`, `FUN_004e7fd0.c`,
`FUN_004e83e0.c`, `local/source/split-merged/code/0x050000/`
`FUN_00544b30.c`, `FUN_00543ed0.c`, `FUN_00544a80.c`, and
`FUN_004ad850.c`; `local/source/compare-report.tsv`;
`GameData/Model/EmperorBuildingModels.txt` row 62;
`Sources/EmperorCore/MarketSimulation.swift`.

**Evidence class:** **confirmed** for the `Empty Shop` creation ID, the
separation from `FUN_004AD850`'s `0x82/0x83` predicates, and the generic
periodic `+0x44` write; **unknown** for any cStall-specific producer, field
semantic, peddler ratio ownership, live child registry projection, and Qin
provider settlement.

## 2026-09-03 `FUN_004AD850` is the City-Gate/Tower labor allocator, not a cStall producer

The remaining `0x82/0x83` writer was traced one level further to prevent a
second misattribution of cStall `+0x44`. `FUN_004AC2B0 @ 0x4AC2B0` dispatches
`FUN_004AD4A0 @ 0x4AD4A0` from phase `0x17`; that function calls
`FUN_004AD850 @ 0x4AD850`. The allocator first computes
`DAT_01312134 = FUN_00408B80(n3, n + ret2 + ret3)`, where `n3` is the sum of
positive object `+0x20` values after excluding objects for which
`FUN_00516ED0(index)` is true. The direct PE body of `FUN_00516ED0` returns
the result of `FUN_005188D0(modelID)`, and `FUN_005188D0` accepts only model
IDs `11...17` (the authored elite-house range).

The allocator's only object-side `+0x44` assignment is in its second pass.
After the active-object gate, `FUN_0042B720`/`FUN_0042B730` restrict the model
word to exactly `0x83` or `0x82`; the pass clears `+0x44`, requires
`DAT_013124F4 != 0` and the object's vtable `+0x58` predicate, then writes a
bounded result from `FUN_00408B40(index)`. `FUN_00408B40` rejects objects whose
`+0x6E` byte is non-zero and otherwise reads model-table field `5` through
`FUN_0044CC50(modelID, 5)`. `FUN_0044CC50`'s direct PE instructions index the
raw 13-column table at `DAT_00A5B398`; difficulty scaling is bypassed for the
non-zero column selector. `GameData/Model/EmperorBuildingModels.txt` names
model `130 (0x82)` **City Gate** with field `5 = 9`, and model `131 (0x83)`
**Tower** with field `5 = 6`.

The same family is consumed by `FUN_00552940 @ 0x552940`, which sums the
signed `+0x44` words only for active `0x82/0x83` objects and compares that
sum against their `+0x1B0` aggregate before selecting string IDs `0x1E16` or
`0x1E1B`. This is corroborating evidence for a gate/labor subsystem, not a
market-child path. `FUN_004AD850`, `FUN_004AD4A0`, `FUN_00516ED0`,
`FUN_005188D0`, `FUN_0042B720`, `FUN_0042B730`, `FUN_00408B40`,
`FUN_0044CC50`, and `FUN_00552940` are `identical` EN/CH rows in
`local/source/compare-report.tsv`; the canonical executable hashes remain EN
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

**Conclusion:** **confirmed** that `FUN_004AD850`'s `+0x44` writes target
the City Gate/Tower (`0x82/0x83`) family and use authored labor field `5`;
**confirmed negative** that this edge identifies the Empty-Shop/cStall
producer. The peddler numerator's Empty-Shop `+0x44` producer, cMarket child
registry projection, route settlement, and household quality/coverage remain
**unknown**. Native must keep the Qin peddler and migration bridge
fail-closed; no workforce or City Gate/Tower count may be substituted for
the raw cStall input.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ac2b0.c`,
`FUN_004ad4a0.c`, `FUN_004ad850.c`, `FUN_0042b720.c`, `FUN_0042b730.c`,
`FUN_00408b40.c`, `FUN_0044cc50.c`; `local/source/split-merged/code/0x050000/`
`FUN_00516ed0.c`, `FUN_005188d0.c`, `FUN_00552940.c`; direct EN/CH PE
instructions at `0x408B40` and `0x44CC50`; `GameData/Model/`
`EmperorBuildingModels.txt`; `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the phase/call order, model predicates,
elite exclusion, raw field-5 lookup, authored IDs/values, and EN/CH parity;
**unknown** for the semantic labels of `0x1E16/0x1E1B`, indirect alias writes,
and every cMarket/provider/settlement projection.

## 2026-09-02 Qin3 routing predicate closure and remaining live blockers

The previous Qin3 diagnostic was failing before flood derivation because
Xiangjun's placed `Decorative Sculpture` (`buildingID=116`) had no recorded
generic footprint predicate. A direct temporary start-and-build diagnostic
reported `missingGenericFootprintPredicate` at `(85,67)` for that ID. The
factory trace identifies `116` as branch `FUN_004142E0` → `FUN_004143B0` →
`FUN_00416C50`, whose constructor installs vtable `0x007AA83C`; both PE
images store `50 6A 41 00` at that vtable's `+0xCC`, i.e. the constant-false
`FUN_00416A50` callback. The same vtable covers authored IDs `117` and
`243...248`, which are recorded alongside the other directly verified Qin
classes in `BuildingFootprintPredicateCatalog`.

After adding this source-backed row, the same diagnostic reports routing
success both immediately after the complete Qin3 placement sequence and after
one simulated year. A shortened research run (two years, with the mission
producer gate temporarily enabled) reaches `floodReachable=40/40`, population
`367`, yearly production `14=1800` and `26=1200`, and no routing error. This
proves the occupancy catalog was the first barrier; it does not prove the
mission is complete. The run still has zero supplied food quality, 20 houses
without water, only housing levels `0/1`, and negative popularity after the
initial arrival batch. The production gate therefore remains
`.unsupportedOriginalProducer` in normal campaign starts, and the Qin3 test
remains skipped until the independent migration-producer, water-house-field,
market-peddler, and desirability contracts are recovered.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004142E0.c`,
`FUN_004143B0.c`, `FUN_00416C50.c`, `FUN_004C0600.c`, `FUN_004C0630.c`,
`FUN_004C0640.c`, `FUN_004C0660.c`, `FUN_004C2220.c`,
`FUN_004C25E0.c`, `FUN_004C2710.c`; `local/source/split-merged/code/0x050000/`
factory files listed in `grand-canal-map-state.md`; both hash-identified PE
images; `GameData/Model/EmperorBuildingModels.txt` rows `116` and `194...199`;
`Sources/EmperorCore/GrandCanalSimulation.swift` and
`Tests/EmperorGameplayTests/Qin3PlayerPlaythroughTests.swift`.

**Evidence class:** **confirmed** for ID `116`'s missing-predicate failure,
constructor/vtable identity, both-PE `+0xCC` bytes, and post-closure routing
success; **unknown** for the original migration producer and the remaining
water, peddler settlement, and desirability control flow.

## 2026-09-02 cMarket access-word refresh boundary

The cMarket-side access refresh is now recorded as a distinct static edge.
`FUN_00543DC0 @ 0x543DC0` is `identical` in the EN/CH comparison report. Its
ordered writes are: clear market `+0x24`; resolve a linear map cell through
vtable `+0x194` from the receiver's `+0x10`; invoke vtable `+0x1AC` with the
auxiliary terrain byte; read signed `DAT_01391FE0[cell]`; store the value at
`+0x24`; derive column/row relative to `DAT_0101D0C8` with stride `0xE4`; and
write those coordinates to `+0x2A/+0x2C`. The method returns non-zero exactly
when the stored access word is non-zero.

`OriginalMarketAccessRefresh.project` preserves the post-selection arithmetic
and keeps the callback input and raw flood value explicit. It is not wired to
Qin: the opaque selector/callback effects, PE-layer projection, provider
registry, route/collision state, and provider-to-house quality/coverage
settlement are still unknown. Qin market and automatic migration therefore
remain fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00543DC0.c`,
`local/source/compare-report.tsv` row `0x543DC0`,
`Sources/EmperorCore/MarketSimulation.swift`, and the focused market tests.

**Evidence class:** **confirmed** for the call/write order, offsets, signed
result, coordinate stride, and EN/CH parity; **unknown** for callback effects,
Native projection, and downstream settlement.

## 2026-09-02 Well `+0x6F` adjacency writer boundary

The remaining Well command-byte lead was traced through the indexed corpus.
`FUN_00511860 @ 0x511860` applies the calendar guard, then
`FUN_00511710` scans eight neighbouring map offsets and filters candidates via
vtable `+0x1D0` and `FUN_00511B10`. Its accepted candidate reaches
`FUN_00511080 @ 0x511080`; outer category `6` admits only target model IDs
`0x48/0x49` (72/73). That branch raises target byte `+0x6F` to
`FUN_00511700(6) = 0x60`, preserving a larger byte, through
`FUN_0042AE30 @ 0x42AE30`. The setter writes only `+0x6F` and calls
`FUN_00418680(target + 0xB4)`; it does not write `cHouseInfo +0x32/+0x34`.

EN/CH compare rows for all four functions are `identical`. This confirms the
`0x60` floor already represented by the pure `raisedWellCommandState` helper,
but does not identify the source category, callback cadence, indirect
registration, or map-object/provider projection. Consequently the Qin water
bridge remains fail-closed: Native must not call this adjacency writer from
generic `.water` visits or map loading.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00511860.c`,
`FUN_00511080.c`, `FUN_00511710.c`, `FUN_00511B10.c`,
`local/source/split-merged/code/0x040000/FUN_0042AE30.c`,
`local/source/compare-report.tsv`, and
`docs/exe-research/residential-service-roamer-lifecycle.md` §10.4.

**Evidence class:** **confirmed** for the adjacency scan, Well model filter,
`0x60` floor, and byte writer; **unknown** for cadence, category semantics,
provider registration, and house-service settlement.

## 2026-09-02 `+0xA0` placement producer narrows feng-shui blocker

The migration feng-shui consumer's input now has a bounded producer trace.
`FUN_0042B250 @ 0x42B250` calls `FUN_0044CC50` with selector `0xC`, matching
authored model field 12 (`m - Feng Shue Value`). Direct canonical-EN PE
instructions at `0x44CC50` close the decompiler's incomplete `void` prototype:
the wrapper returns `DAT_00A5B398[modelID * 13 + selector]`, and only selector
`0` calls the difficulty/runtime adjustment `FUN_0044C380`; selector `0xC`
therefore returns the raw field-12 word. The function returns fixed values for
field values `0`, `6`, `7`, and above `7`, and performs a location/category test
for values `1...5`.
Successful
construction stores that result at object `+0xA0` in the generic placement,
normal construction, market/shop, and type-2 placement paths. New-object
initializers seed the same word to zero, and base copy/serialization keeps it.
The EN/CH rows for `0x42B250` and `0x44CC50` are `identical`.

This is stronger than treating Native's terrain-element `fengShuiSummary` as
the migration input: `FUN_00591670` consumes the placement-time `+0xA0`
weights, then applies integer `harmonious * 100 / total` and the already
recovered population/band rules. Native records that final arithmetic in a
pure weighted helper and tests it, but does not classify map objects or wire
the factor. The callback classes behind `FUN_0042C930`, category mapping from
`FUN_0042B090`, archive-load recomputation, and the overlap with unrelated
classes that also use `+0xA0` remain unknown. Qin migration therefore stays
fail-closed pending those mappings.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042b250.c`,
`FUN_0042c930.c`, `FUN_0044cc50.c`, `FUN_00414f70.c`, `FUN_00415d30.c`,
`FUN_004157d0.c`, `FUN_004b1250.c`; `local/source/split-merged/code/0x050000/`
`FUN_00540e70.c`, `FUN_00544b30.c`, `FUN_005428b0.c`, `FUN_00591670.c`;
`local/source/compare-report.tsv`; `GameData/Model/EmperorBuildingModels.txt`;
`Sources/EmperorCore/MigrationSimulation.swift`; and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the placement producer, raw field-12
lookup, selector-0-only adjustment branch, and weighted aggregation arithmetic;
**unknown** for object classification, callback and category semantics, archive
recomputation, and Native projection.

## 2026-09-02 Qin generic Building archive remains unbound

The map archive now has a reusable, data-only scanner for the generic
`Building` records emitted by `FUN_00427430 @ 0x427430`.  It recognizes the
little-endian stream token `0x8001`, the schema word (`3` or `4`), the common
serializer's packed base-type word at object `+0x14`, and the final 20-byte tail whose
first DWORD is object `+0xB4`.  The recovered record spans are 181 bytes for
schema 3 and 183 bytes for schema 4.  The scanner is deliberately bounded by
the decoded archive range before the fixed trailing auxiliary grid; it is not a
runtime object loader.

Against the installed canonical Qin maps, the scanner returns exactly 3,956
records for Xiangjun, 3,962 for Haunxian, 3,998 for Xianyang, and 3,906 for
Badaling.  Every returned record has base-type word `0` and raw `+0xB4`
provider-registry slot `-1`.  This corroborates the existing byte-level tests
and the `FUN_0042D0E0 → FUN_0042D790` generic archive-load path: the serialized
records do not carry a recoverable provider slot that can be projected into
the live residential-service registry.  The catalog therefore improves
inspection and future evidence capture only; it does not enable Qin migration,
water, market, or entertainment settlement.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`local/source/split-merged/code/0x040000/FUN_0042D0E0.c`,
`local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`local/source/compare-report.tsv` row `0x427430`, the installed
`GameData/Maps/Cities/{Xiangjun,Haunxian,Xianyang,Badaling}.map` archives,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the token/schema boundaries, packed
field offsets, record lengths, four-map counts, zero base-type words, and
`-1` raw registry slots;
**unknown** for any indirect post-load specialization, object-grid ownership,
provider registration, or service-to-house settlement.

## 2026-09-02 Qin MFC class-declaration catalog follow-up

The variable archive's MFC `new class` declarations are now exposed through
the read-only `OriginalMapArchiveClassCatalog`.  It recognizes the canonical
`FF FF 00 00` header, little-endian class-name length, printable class name,
following schema word, and the first base-building type word at the recovered
class-name-relative offset `+16`.  The scan is bounded to the archive region
before the trailing fixed grid and does not act as a runtime class registry.

The four canonical Qin city archives contain exactly these declarations and
first type words:

| map | declarations `(class, first type word)` |
| --- | --- |
| Xiangjun | `Building/0`, `cResWall/90`, `cResGate/105` |
| Haunxian | `Building/0`, `cMonumentBldg/83`, `cIndustrialBldg/173` |
| Xianyang | `Building/0`, `cIndustrialBldg/173` |
| Badaling | `Building/0`, `cMonumentBldg/257`, `cFillBldg/94` |

All declarations use schema `3` in Xiangjun and schema `4` in the other three
maps.  No declaration names a Well, Herbalist, Acupuncturist, or `cMarket`
class.  This corroborates the generic-record scan and the
`FUN_0052F1D0`/`FUN_0052F030` negative: no explicit service-provider MFC class
is present in the Qin map object archive.  It still does not rule out an
indirect post-load projection or identify provider registry ownership, so the
Qin water, market, entertainment, and automatic-migration bridges remain
fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`local/source/split-merged/code/0x050000/FUN_0052F1D0.c`, the installed
`GameData/Maps/Cities/{Xiangjun,Haunxian,Xianyang,Badaling}.map` archives,
`Sources/EmperorCore/MapArchiveClassCatalog.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the declaration grammar, class lists,
schema values, first type words, and absence of the named service classes;
**unknown** for any runtime class-table registration or indirect provider
specialization not represented by these declarations.

## 2026-09-02 `FUN_0042DA10` post-load callback gate is not a provider bridge

The remaining object-pass candidate was checked directly in both indexed
executables. `FUN_0042DA10 @ 0x42DA10` starts at object-vector index `1`, reads
the global `FUN_00426D10(0)` gate, and invokes the current object's virtual
`+0x1C8` entry only when that gate is non-zero **or** the object's raw state
byte at `+0x04` equals `6`. The EN/CH row for `0x42DA10` is `identical`.
Its direct callers are the map/editor initialization paths
`FUN_00406A20`, `FUN_00534A30`, `FUN_00534BF0`, and `FUN_0042E6A0`; the
surrounding bodies contain no direct service factory,
provider-slot write, or provider-list insertion.

This closes the dispatch gate and call context as **confirmed**, and records
the raw constants in `OriginalMapArchiveRepairCatalog` with a pure
`invokesPostLoadObjectCallback(globalGateOpen:objectStateByte:)` helper. It
does not identify the class-specific `+0x1C8` targets for Well, Herbalist,
Acupuncture, market, or entertainment objects. No recovered target writes
provider `+0x2D`, installs a service vtable, or projects coverage into a
house. The serialized provider index, any table-driven specialization, and
the Native registry/settlement projection therefore remain **unknown**;
Native stays fail-closed for Qin service providers.

**Sources:**
`local/source/split-merged/code/0x040000/FUN_0042DA10.c`,
`FUN_00406A20.c`, `FUN_0042E6A0.c`;
`FUN_00534A30.c`, `FUN_00534BF0.c`;
`local/source/compare-report.tsv` row `0x42DA10`; and
`Sources/EmperorCore/HousingEvolution.swift`.

**Evidence class:** **confirmed** for object-vector start, global/state-byte
OR gate, virtual offset, callers, and EN/CH identity; **unknown** for the
class-specific callback targets, serialized provider-slot provenance, and
any provider registration or house-service settlement.

## 2026-09-02 Qin service vtables make post-load `+0x1C8` a no-op (confirmed negative)

The class-specific target question is now closed for the Qin-relevant vtables
that are present in the executable's service/entertainment families.  Direct
little-endian PE reads at `vtable + 0x1C8` agree in the canonical EN build and
the CH cross-check build:

| class/family | vtable | `+0x1C8` target |
| --- | ---: | ---: |
| base `Building` | `0x7AB59C` | `0x00413A00` |
| Well | `0x7B5EB4` | `0x00413A00` |
| Herbalist | `0x7B6114` | `0x00413A00` |
| Acupuncture | `0x7B6374` | `0x00413A00` |
| Entertainment Area | `0x7AD878` | `0x00413A00` |
| Music School | `0x7ACEDC` | `0x00413A00` |
| Acrobat School | `0x7AD140` | `0x00413A00` |
| Drama School | `0x7AD3A4` | `0x00413A00` |

`local/source/split-merged/code/0x040000/FUN_00413A00.c` is the matching
function body and returns zero; `local/source/compare-report.tsv` marks the
EN/CH function row `0x413A00` as `identical`.  The raw PE body is byte-identical
`32 C0 C3` (`xor al,al; ret`) at `0x413A00` in both images.  This is a
confirmed negative: the post-load object pass's virtual dispatch does not
provide a hidden service-provider registration or house-coverage bridge for
these classes.  It also means the earlier class-specific-target unknown is
resolved only for the eight listed vtables; other classes and any separate
table-driven projection remain unknown.

The result is recorded as the read-only
`OriginalMapArchiveRepairCatalog.postLoadObjectNoOpVTableDescriptors` table and
the `postLoadObjectCallbackIsNoOp(forVTableAddress:)` predicate.  These helpers
are evidence metadata only and are not called by map loading or simulation.
Provider registry ownership, serialized-slot provenance, map-to-runtime
projection, and Qin campaign settlement therefore remain fail-closed.

**Sources:** canonical `Exe/ghidra/input/EmperorEN.exe` SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, CH
`Exe/ghidra/input/EmperorCH.exe` SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, direct
`.text`/`.rdata` reads at the listed addresses, `FUN_00413A00.c`, and the
`0x413A00` comparison row.

**Evidence class:** **confirmed** for the eight vtable words, the no-op target,
the byte body, and EN/CH identity; **unknown** for unlisted class vtables,
table-driven specialization not represented by these entries, provider
registry ownership, and house-service settlement.

## 2026-09-02 `FUN_0042B090` placement terrain classifier is isolated (confirmed)

The placement-time terrain category producer was traced in both indexed
executables. `FUN_0042B090 @ 0x42B090` scans the inclusive offsets `-4...3` in
both axes (an 8×8 window) around the candidate point. It ignores words with
bit `0x80000`, classifies bit-0-clear words through the exact masked-kind
helpers `FUN_0042B600` (`(word & 0x300002) == 0x100002`),
`FUN_0042B620` (`== 0x200002`), and `FUN_0042B5E0` (`== 2`), and tracks the
nearest squared distance for source slots 1, 2, and 4 (`local_c`). If no
category is found, it returns 5 when the center word has neither `0x84` nor
`0x4000000`, otherwise 3. Otherwise the nearest category-1 distance wins
ties; the final branch returns 4 when the category-4 slot is nearer than
category 2, otherwise 2.
The EN/CH comparison row for `0x42B090` is `identical`.

`OriginalFengShuiTerrainClassification.classify` now mirrors this arithmetic
as a side-effect-free helper. It requires an explicit linear map-word
projection and base/stride; missing cells return `nil` rather than treating an
unresolved object grid as clear terrain. This helper is not wired to Native
placement or migration: the PE backing-grid origin, object/registry writers,
and the caller's model-to-`+0xA0` mapping remain unknown. It therefore reduces
the unresolved placement boundary without weakening Qin's fail-closed producer.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042b090.c`,
`FUN_0042b600.c`, `FUN_0042b620.c`, `FUN_0042b5e0.c`,
`FUN_0042b250.c`, `local/source/compare-report.tsv` row `0x42B090`,
`Sources/EmperorCore/FengShuiTerrainClassification.swift`, and focused tests
in `Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for window geometry, masks, distance/tie
ordering, fallback values, and EN/CH identity; **unknown** for backing-grid
projection, object registry, and live `+0xA0` producer wiring.

## 2026-09-02 authored terrain can project to the recovered PE backing index (confirmed)

The descriptor closure above now has a direct Native projection boundary.
`EmperorMap` already reads each mission cell from the centered serialized
`startOffset`; `OriginalMapRuntimeDescriptorCatalog` confirms that the same
base and `228` effective row stride are selected by the original runtime for
all supported dimensions. `DeterministicTerrainState.originalAuthoredTerrainWords()`
therefore exposes a linear `[base + y×0xE4 + x] → terrainWord` dictionary for
the authored layer, and the terrain overload of
`OriginalFengShuiTerrainClassification.classify` consumes it.

This is a static authored-layer bridge only. It intentionally omits every
later `FUN_004B72B0` dynamic object write, registry ID, auxiliary state byte,
and orientation edge marker. Consequently it is useful for future
side-effect-free placement diagnostics but does not enable Qin desirability or
automatic migration; the dynamic object/registry projection and `+0xA0`
producer wiring remain unknown.

**Sources:** `FUN_0053CE60.c`, `FUN_0052E630` evidence and descriptor rows in
`docs/exe-research/desirability-propagation.md`, `Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/DeterministicTerrainState.swift`, and focused tests in
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for authored-cell extraction, centered base,
and effective stride; **unknown** for dynamic object overlays and runtime
registry/state projection.

## 2026-09-02 object-grid registry array has no direct writer in the corpus (negative)

The dynamic occupancy candidate was audited by literal-address search across
the complete indexed EN/CH corpus. `DAT_00890210` is read only by
`FUN_00416BB0 @ 0x416BB0`, `FUN_004BE8E0 @ 0x4BE8E0`, `FUN_0053FB30 @
0x53FB30`, `FUN_005643C0 @ 0x5643C0`, and `FUN_005AD440 @ 0x5AD440`.
Every read treats `DAT_00890210[cell]` as a pointer and accepts it only when
the pointed object byte at `+0x18` is zero; no indexed function body contains
an assignment to that array.  The EN/CH comparison rows for `0x416BB0` and
`0x416BD0` are `identical`.

The adjacent `DAT_00FAA130` array is a different structure: `FUN_00416BD0 @
0x416BD0` follows a short-linked figure list (`figure+0x10`, type byte
`figure+0x12 == 3`) and never accesses `DAT_00890210`.  Conversely, the
confirmed dynamic writer `FUN_004B72B0 @ 0x4B72B0` updates terrain words,
`DAT_00FC3750`, `DAT_00FE9880`, `DAT_00FDCD70`, and `DAT_00F9D620`; its body
does not write `DAT_00890210`.  Thus the writer's `registryID` parameter is a
terrain-cell auxiliary/index value, not proof of the object-pointer array's
population.

This negative closes the tempting shortcut of projecting Native buildings into
`DAT_00890210` from the visible `FUN_004B72B0` call sites.  The actual object
registry owner, insertion/removal path, and any indirect/table-driven store
are not present as direct assignments in the searchable corpus.  Without that
ownership boundary, the PE occupancy checks cannot be safely mapped to Native
residential anchors, provider coverage, or desirability; Qin service,
automatic-migration, and appeal settlement remain fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00416BB0.c`,
`FUN_00416BD0.c`, `FUN_004BE8E0.c`,
`local/source/split-merged/code/0x050000/FUN_0053FB30.c`,
`FUN_005643C0.c`, `FUN_005AD440.c`, `FUN_004B72B0.c`, the complete literal
search over `local/source/split-merged/code`, and
`local/source/compare-report.tsv` rows `0x416BB0`/`0x416BD0`.

**Evidence class:** **confirmed negative** for the listed direct reads,
field predicates, linked-list distinction, and absence of direct stores;
**unknown** for stores hidden behind unresolved indirect code or outside the
indexed corpus, and for the Native registry/occupancy projection.

## 2026-09-02 generic Building archive records do not expose a safe coordinate/model projection (confirmed boundary)

The Qin map's generic-building section was traced from its loader rather than
decoded by byte position. `FUN_0042D790 @ 0x42D790` reads the archive schema and
slot count, constructs each entry through the generic `Building` stream factory
(`FUN_0042D0E0 → FUN_0077FD90`), and inserts the resulting object through
`FUN_0042B590`. The object serializer/deserializer
`FUN_00427430 @ 0x427430` then visits fields through the archive-buffer helpers
`FUN_00780533` and `FUN_00780642`; those helpers operate on the MFC archive
buffer and compression/memmove path (`FUN_0076AB30`). The observed 181/183-byte
spans in `GenericBuildingArchiveCatalog` are therefore encoded stream lengths,
not a raw object struct whose bytes can be indexed as `x`, `y`, model, or
footprint fields.

The runtime coordinate semantics themselves are confirmed elsewhere:
`FUN_00544930` and `FUN_00544970` read object offsets `+0x0A` and `+0x0C` as the
map origin, and `FUN_00508B10` stores those values while calculating the
backing-grid address. However, no indexed EN/CH function closes the inverse
mapping from the compressed generic record bytes to those runtime fields. A
read-only probe of the authored Qin maps finds the expected generic-record
counts (Xiangjun 3956, Haunxian 3962, Xianyang 3998, Badaling 3906), but the
records are predominantly default/zero payloads with repeated archive tails;
their apparent sequential tail words do not correlate to a recoverable
coordinate/model schema. All four maps also report the generic scanner's
provider slot as `-1`, which is not evidence that the runtime provider list is
empty—it only records the unresolved archive value.

This closes the tempting initial-house shortcut: Native must not synthesize
residential anchors, providers, footprints, or migration inputs from fixed
byte offsets inside the 181/183-byte records. The generic loader's later
specialization/registration edge, the serialized provider-index source, and
the exact stream field encoding remain **unknown**. Qin initial residential
projection and automatic migration therefore remain fail-closed until a legal
runtime observation or a further static/table-driven decode recovers that
boundary.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`FUN_0042D790.c`, `FUN_0042D0E0.c`,
`local/source/split-merged/code/0x070000/FUN_00780533.c`,
`FUN_00780642.c`, `FUN_0076ab30.c`,
`Creating_pctd_type_pctd.c` (`0x42D540`), `FUN_00544930.c`,
`FUN_00544970.c`, `FUN_00508B10.c`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and the
read-only Qin map probe for `GameData/Cities/{Xiangjun,Haunxian,Xianyang,Badaling}.map`.

**Evidence class:** **confirmed boundary** for archive-factory call order,
MFC/compressed stream handling, runtime coordinate offsets, map counts, and the
absence of a safe inverse byte projection; **unknown** for the serialized
field encoding, provider-index provenance, post-load specialization, and
Native initial-house/registry correspondence.

## 2026-09-02 PE geometry tables close the model-to-footprint sampling input (confirmed)

The earlier table audit treated `DAT_00823598`, `DAT_00822C0C`, and
`DAT_00822D48` as BSS-only candidates because the decompiler labels them as
globals. The canonical English PE actually contains their complete initialized
data in the file-backed image. Reading the image at the address-minus-image
base offsets yields:

* `DAT_00823598` is a 0x10D-entry table with 0x18-byte records. The first
  DWORD is the geometry-group index consumed by `FUN_0042B250`; the model IDs
  used by placement select groups `1...6` (whose counts are 1, 4, 9, 16, 25,
  and 36). The remaining record words include the primary image key and other
  model metadata, but are not reinterpreted here.
* `DAT_00822C0C` supplies the group counts. `FUN_0042B250` indexes it with
  the first `DAT_00823598` DWORD, then reads exactly that many relative map
  offsets.
* `DAT_00822D48` stores signed relative linear offsets with the executable's
  228-cell row stride. `FUN_0042B250` starts at
  `DAT_00822D48 + (DAT_0101D0D0 / 2) * 0x24` and consumes the selected group
  count. The 0x24 increment is therefore the original rotation-bank stride;
  larger footprints continue through adjacent banks exactly as the PE loop
  does. Negative offsets are two's-complement signed values.

This closes the model-to-footprint/sample-offset input for the non-custom
placement path. It does **not** close the custom callback `FUN_0042C930`, the
dynamic object-grid overlay, or provider/house registration. The Native
implementation therefore exposes these tables only through a pure evidence
catalog and does not enable automatic Qin production or desirability.

**Sources:** canonical English `Exe/ghidra/input/EmperorEN.exe` initialized
image bytes at `0x00823598`, `0x00822C0C`, and `0x00822D48` (image base
`0x00400000`); `local/source/split-merged/code/0x040000/FUN_0042b250.c`,
`FUN_00414c40.c`, `FUN_0046d110.c`, and the EN/CH comparison report rows for
these callers; `GameData/Model/EmperorBuildingModels.txt` for model-ID scope.

**Evidence class:** **confirmed** for table addresses, record stride, group
counts, signed offset encoding, and rotation-bank selection; **unknown** for
custom-model callback geometry and any runtime registration side effects.

## 2026-09-02 `FUN_0042C930` custom-sampler dispatch is catalogued (confirmed boundary)

The canonical EN/CH bodies of `FUN_0042C930 @ 0x42C930` enumerate a separate
placement-sampling path for model IDs that cannot use the ordinary geometry
table. The dispatch is now recorded in
`OriginalBuildingGeometryCatalog.CustomSamplerDescriptor` with the exact
allocation size, constructor, vtable, and fort selector observed in the PE:

* `11` (unoccupied elite) allocates `0x18` bytes and constructs
  `FUN_0042CDF0` (`0x7AB8F0` vtable).
* `59/60` (common/grand market) allocate `0x14` bytes and construct
  `FUN_0042CCD0`/`FUN_0042CD50` (`0x7AB800`/`0x7AB878`).
* `110/209` (palace/administrative city) allocate `0x18` bytes and construct
  `FUN_0042CED0`/`FUN_0042CE60` (`0x7AB9C0`/`0x7AB95C`).
* `130` (city gate) uses `FUN_004F8EA0` (`0x7B4180`) with selector `-1`.
* `220/221/223/224/225` share `FUN_004EF240` (`0x7B2BF0`) with selectors
  `3/0/2/1/4` respectively.

This is a dispatch/identity boundary only. The callback point enumeration,
`FUN_0042B090` category inputs, and callback object side effects are not
recovered. Native therefore returns this descriptor only as research data and
continues to fail closed for these models; a normal geometry footprint is not
substituted. This matters directly to Qin-3 because its player flow places
common markets and may encounter the same model family during later expansion.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042c930.c`,
`FUN_0042ccd0.c`, `FUN_0042cd50.c`, `FUN_0042cdf0.c`, `FUN_0042ce60.c`,
`FUN_0042ced0.c`, `FUN_004f8ea0.c`, `FUN_004ef240.c`, and identical EN/CH
comparison rows; `Sources/EmperorCore/OriginalBuildingGeometryCatalog.swift`;
focused assertions in `Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for model-ID dispatch, allocation sizes,
constructor/vtable identities, and fort selector values; **unknown** for
custom callback geometry/category semantics, object-grid projection, and
provider/house settlement.

## 2026-09-02 Qin market custom point banks are recovered (confirmed partial)

The market entries are the first custom callbacks whose point data can be
closed without interpreting the callback's category semantics. In both
hash-identified executables, the market vtables use the common enumerator
`FUN_0042CC30 @ 0x42CC30`; it obtains the point count from vtable `+0x04`,
the data base from vtable `+0x24`, and passes each record through
`FUN_0042B820 @ 0x42B820`. That helper reads only the first two signed words
of each 16-byte record and applies the map-rotation transform.

The PE data returned by the market vtables is exact:

| model | data base | count per bank | recovered banks |
| --- | ---: | ---: | --- |
| Common Market `59` | `0x008574A8` | `28` | `4×7`, `7×4` |
| Grand Market `60` | `0x00857828` | `42` | `6×7`, `7×6` |

The second Common Market bank begins immediately after its first 28 records;
the Grand Market table follows at `0x00857828` and likewise contains two
banks. `FUN_0042CD50` masks the orientation-bank selector to `0/1`, matching
the two-bank layout. Bank zero is stored row-major (`(0,0)…(3,0),(0,1)` for
Common), while the transposed bank is stored column-major (`(0,0)…(0,3),(1,0)`
for Common and `(0,0)…(0,5),(1,0)` for Grand). The fourth dword is also
retained: Common uses the corner `aux=1` markers, while Grand uses its
authored `100…135` auxiliary values on the interior rows.
`OriginalBuildingGeometryCatalog` records the table bases, counts, dimensions,
raw flags, auxiliary values, and stored point order as research data; it does
not assign those fields a player-facing meaning.

This closes only the custom point-coordinate input. The category callback
(`FUN_0042B090`), dynamic occupancy, market/provider registry, and house
settlement remain unresolved, so Native does not yet use these points to
produce `+0xA0` or enable Qin market/migration behavior.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042cc30.c`,
`FUN_0042b820.c`, `FUN_0042ccd0.c`, `FUN_0042cd50.c`, and the canonical EN/CH
PE data at `0x008574A8`/`0x00857828`; the corresponding vtable rows are
byte-identical in `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for enumerator call order, record width,
point counts, bank dimensions, bases, raw flags/auxiliary values, and stored
point order; **unknown** for
rotation-state ownership outside `FUN_0042B820`, category semantics, object
registration, and provider/house settlement.

## 2026-09-02 market callback records preserve raw flags and stored order (confirmed partial)

The Common/Grand market vtables at `0x7AB800`/`0x7AB878` use
`FUN_0042C750 @ 0x42C750` at slot `+0x50` after enumerating the same
16-byte records. That callback reads the record flags at `+0x08` and the
auxiliary dword at `+0x0C`; it does not treat every point as a uniform
rectangle. For flag `0x2` with a nonzero auxiliary dword it forwards the
record through the shared object-grid writer `FUN_004B72B0 @ 0x4B72B0`; flags
`0x1` and `0x4` use distinct branches, and other flag combinations can invoke
the callback's `+0x5C` method. The callback iterates records in the exact
vtable order, then applies the map rotation through `+0x2C` and
`FUN_0042B960 @ 0x42B960`.

Direct PE reads show that Common's two banks contain the corner `aux=1`
markers and Grand's interior rows carry the authored `aux=100…135` values.
The EN and CH vtable slots are byte-identical (`+0x30/+0x34/+0x38/+0x3C`,
`+0x48`, `+0x4C`, `+0x50`, and `+0x5C` all resolve to the same addresses).
`CustomGeometryDescriptor.PointRecord` now preserves each market record's
coordinate, raw flags, auxiliary dword, and bank-specific stored order. This
`OriginalBuildingGeometryCatalog.customSamplerCallbackSlots` also records the
ten recovered market callback slots as raw addresses. This is an input catalog
only: the `+0x30` image/state callback, dynamic registry ownership, and the
source arguments passed to `FUN_004B72B0` are not promoted to Native simulation
behavior.

**Sources:** canonical EN/CH PE vtable bytes at `0x7AB800` and `0x7AB878`,
`local/source/split-merged/code/0x040000/FUN_0042C750.c`,
`FUN_0042B960.c`, `FUN_004B72B0.c`, `FUN_0042CC30.c`, the market data at
`0x8574A8`/`0x857828`, and
`Sources/EmperorCore/OriginalBuildingGeometryCatalog.swift` with focused
tests in `Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for slot identities, record field offsets,
flag branches, callback ordering, raw market metadata, and EN/CH identity;
**unknown** for callback-specific image/state semantics, registry allocation,
and the provider/house settlement consequences of those writes.

## 2026-09-02 Explicit-bank market feng-shui sampler (confirmed partial)

The recovered market point banks can now feed the same pure placement
classifier as ordinary geometry, without inventing the unresolved orientation
selection. `FUN_0042B250 @ 0x42B250` uses the custom object when
`FUN_0042C930` returns one, enumerates each point through the vtable
`+0x2C`/`+0x04`/`+0x24` chain, and passes the transformed coordinate to
`FUN_0042B090 @ 0x42B090`. `FUN_0042B820` applies map rotations `0/2/4/6` as
`(+x,+y)`, `(-x,+y)`, `(-x,-y)`, and `(+x,-y)`; this is separate from the
custom bank selector stored in `DAT_008C7628`.

`OriginalFengShuiTerrainClassification.samplePlacement` therefore accepts an
explicit `customOrientationBank` only when a recovered custom table exists.
Common Market `59` and Grand Market `60` use their confirmed 28/42-point
banks; omitting the bank still returns `nil`, preserving the unknown
`FUN_0042C100` bank-choice/occupancy search. The helper writes no object state,
does not register a market, and does not enable market access or house
settlement. Focused tests cover both the explicit Common Market bank and the
fail-closed omitted-bank path.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042B250.c`,
`FUN_0042B820.c`, `FUN_0042CC30.c`, `FUN_0042C100.c`,
`FUN_0042CD50.c`; canonical EN/CH vtable/data bytes;
`Sources/EmperorCore/OriginalBuildingGeometryCatalog.swift`,
`FengShuiTerrainClassification.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** `confirmed` for the callback enumeration, signed rotation
transform, explicit-bank sampler behavior, and fail-closed boundary; `unknown`
for automatic bank selection, callback category side effects, dynamic
occupancy, market/provider registration, and house settlement.

## 2026-09-02 custom orientation-bank search order is closed (confirmed partial)

`FUN_0042C100 @ 0x42C100` is the shared custom-placement search called by the
administrative-city/palace wrappers `FUN_005074A0 @ 0x5074A0` and
`FUN_00516B70 @ 0x516B70`, and directly by the construction dispatcher
`FUN_004B1250 @ 0x4B1250` for the city-gate/fort families. The EN/CH comparison
row for `0x42C100` is `identical`.

Before testing any point, the function obtains the callback's bank count from
vtable `+0x08` and chooses its starting bank exactly as follows:

1. When the placement-mode argument (`param_6`) is zero and
   `DAT_008C7628` is within `0 .. bankCount-1`, start at that persisted bank.
2. Otherwise, when `DAT_00C05810` is nonzero, start at `1 % bankCount`.
3. Otherwise start at bank zero.

It then tests each bank once, advancing `(bank + 1) % bankCount` after a
failed bank. The callback/occupancy vtable calls determine acceptance; a
successful bank is written back to both `DAT_008C7628` and the sampler's
`+0x0C` word. When every bank fails, the status remains false and the wrapped
index is still written, so this is not equivalent to “bank zero on failure”.

`OriginalCustomOrientationBankSearch` records the exact pre-search order and
the first-accepted reduction from caller-supplied booleans. It deliberately
rejects a zero bank count rather than reproducing the source's undefined
modulo boundary. No callback flags, dynamic occupancy arrays, object-grid
writes, or placement-origin scan are synthesized, and the helper is not wired
to Native construction or Qin campaign state.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042c100.c`,
`FUN_004b1250.c`, `local/source/split-merged/code/0x050000/FUN_005074a0.c`,
`FUN_00516b70.c`, `local/source/compare-report.tsv` row `0x42C100`,
`Sources/EmperorCore/OriginalBuildingGeometryCatalog.swift`, and focused
tests in `Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for bank-count acquisition, initial-bank
precedence, one-pass wrapping order, write-back boundary, and EN/CH identity;
**unknown** for per-bank callback acceptance, dynamic occupancy projection,
origin-search side effects, and market/provider/house settlement.

## 2026-09-02 generic-house canvas projection remains fail-closed

The generic Qin `Building` archive has no proven inverse mapping from its
compressed record bytes to the runtime residential coordinates (see the
archive boundary above). `CityCanvas` therefore must not turn a missing
`ResidentialUnit.location` into a synthetic grid position. The player canvas
now skips that house until an authored or runtime-backed coordinate is present;
this removes fabricated residential sprites without changing simulation state
or the already-supported authored map/barrier rendering.

**Evidence class:** **confirmed boundary** for the absence of a safe archive
coordinate projection; **fail-closed presentation correction** for the Native
renderer. The original post-load object registration and coordinate source
remain **unknown**.

## 2026-09-02 compact-to-directional cache projection is bounded (confirmed partial)

The recovered map descriptor rows provide an additional safe boundary for the
directional routing blocker.  For the supported Qin rectangle sizes,
`OriginalMapRuntimeDescriptor.effectiveRowStride` is `228`, matching the
16-bit row stride recovered from the aliases around `DAT_013789C0` in
`FUN_005AD440`, `FUN_005B0220`, and `FUN_005B0360`.  Given a derived primary
cache value for one active rectangle, the alias offsets can therefore be
converted back to an active local cell by subtracting the descriptor base and
performing floor division by `228`.

`OriginalDirectionalLayerViews.activeRectangleValues` records that conversion
without inventing the surrounding backing grid.  North/east/south/west values
are emitted only when the aliased address lands inside the supplied rectangle;
an edge crossing returns `nil`.  The helper rejects dimension/count mismatch
and never wraps a compact row into its neighbour.  This is a storage-view
adapter only: it does not derive `FUN_005AD440`'s primary cache, populate
object callbacks, or enable the Qin market/venue/provider route.  Cells outside
the authored rectangle still require the original 228×228 terrain/object state.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005AD440.c`,
`FUN_005B0220.c`, `FUN_005B0360.c`; `Sources/EmperorCore/EmperorMap.swift`
(`OriginalMapRuntimeDescriptorCatalog`); `Sources/EmperorCore/MarketSimulation.swift`
(`OriginalDirectionalLayerViews`); focused regression coverage in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the 228-cell descriptor stride, alias
offset arithmetic, in-rectangle floor conversion, and fail-closed edge
handling; **unknown** for values outside the active rectangle, cache producer
inputs, provider registry, and downstream route/settlement semantics.

## 2026-09-02 phase-0x23 water decay requires explicit object eligibility (confirmed boundary)

The scheduler integration now preserves the recovered call boundary without
pretending that Native has the original provider registry.  In the canonical
EN executable, `FUN_004AC2B0 @ 0x4AC2B0` reaches phase `0x23`, then
`FUN_00517B40 @ 0x517B40`; the active-object walk checks the building `+0xB8`
eligibility callback, resolves `cHouseInfo` through `+0x1E4`, and invokes
`FUN_00517280 @ 0x517280`.  That decay routine independently applies
`<2 → 0, otherwise −1` to `+0x32` and `+0x34` (as well as the other house
service bytes).

`DeterministicWalkerState.advanceRecoveredOriginalSteps` now accepts an
explicit `waterDecayEligibleHouseIDs` set.  At phase `0x23` it always advances
the already-modeled ordinary Native coverage timers, but it advances the two
optional water projections only for IDs in that set.  The default is empty,
so Qin remains fail-closed while the provider/object registry and `+0xB8`
eligibility projection are unresolved.  A focused regression advances exactly
`0x24` scheduler steps and verifies both projected bytes decay for the explicit
house while an otherwise identical house remains unchanged.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ac2b0.c`,
`local/source/split-merged/code/0x050000/FUN_00517b40.c`,
`local/source/split-merged/code/0x050000/FUN_00517280.c`, and identical EN/CH
rows in `local/source/compare-report.tsv`; implementation in
`Sources/EmperorCore/WalkerSimulation.swift`; regression in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`; prior byte/persistence
analysis in `docs/exe-research/residential-service-roamer-lifecycle.md` §7.3al.

**Evidence class:** **confirmed** for phase ordering, byte decay, and the
explicit-eligibility seam; **unknown** for the provider/object registry and
the set of Qin objects that should enter it, so no live campaign caller
populates the set.

## 2026-09-02 market-access cache producer/consumer boundary (confirmed partial)

The static corpus closes the remaining distinction between the directional
layer writer and the market flood consumer.  `FUN_005B1080 @ 0x5B1080` is a
seeded breadth-first walk called by `FUN_00541220 @ 0x541220` after the market
object supplies its two signed map-origin words (`+0x2A` and `+0x2C` in the
caller).  It seeds `DAT_01391FE0[origin] = 1`, then consumes a ring queue whose
capacity is `0xCB10` cells.  For each dequeued cell it writes depth `current +
1` to four separate output views in this fixed order: north
`DAT_01391C50[idx]` gated by the central cache at `idx - 0xE4`, east
`DAT_01391FE4[idx]` gated by `DAT_013789C2[idx]`, south
`DAT_01392370[idx]` gated by `DAT_01378B88[idx]`, and west
`DAT_01391FDC[idx]` gated by `DAT_013789BE[idx]`.  Every admission uses the
same `0x010C` mask and enqueues the corresponding signed `±0xE4`/`±1` index;
the queue head/tail wrap at `0xCB0F` and the loop ends when head equals tail.
The EN and CH rows are byte-identical (`compare-report.tsv`, `0x5B1080`).

`FUN_005AD8F0 @ 0x5AD8F0` clears the shared `DAT_013789C0` backing words via
`FUN_005AD920`, then invokes `FUN_005AD440` over the full authored map.  The
producer classifies each cell using terrain/object flags, `DAT_00890210`
object records, and indirect callbacks at vtable `+0x264/+0x270`; its
branches set the central bits consumed by `0x5B1080` and by the separate
`0x5B0220`/`0x5B0360` expanders.  No direct writer from a Native map or
provider registry reaches those callbacks in the indexed corpus.  Therefore
`OriginalMarketAccessFlood.build` remains a faithful pure consumer projection
only: it may consume caller-supplied four layers, but it must not synthesize
those layers from authored terrain, infer a market origin, or enable Qin
provider/house settlement.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005b1080.c`,
`FUN_00541220.c`, `local/source/decompiled-en.c` functions
`FUN_005ad8f0`/`FUN_005ad920`/`FUN_005ad440`,
`local/source/split-merged/code/0x050000/FUN_005b0220.c`,
`FUN_005b0360.c`, and the identical EN/CH row in
`local/source/compare-report.tsv`; Native projection in
`Sources/EmperorCore/MarketSimulation.swift` (`OriginalMarketAccessFlood`)
with focused tests in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the call boundary, seed/depth values,
four output views, admission mask, signed offsets, and bounded queue; **unknown**
for the `FUN_005AD440` object/terrain callback inputs, market-origin producer,
runtime object-grid ownership, and all provider/house settlement effects.

## 2026-09-05 map-load rebuild has a fixed post-rehydration call order

The map-load sequence is now recorded as an ordered source boundary rather
than only a set of individual calls.  `FUN_0053D100 @ 0x53D100` invokes the
generic-object whitelist pass `FUN_0052F030` first.  It then calls, in order,
`FUN_0053D630`, `FUN_0053CAE0`, `FUN_0053CBD0`, `FUN_005ADDD0`,
`FUN_005ADD10`, `FUN_005AD8F0`, `thunk_FUN_00522810`, `FUN_005ADD40`, and
`FUN_00468B80`.  In particular, `FUN_005AD8F0` clears the directional cache
(`FUN_005AD920`) and rebuilds it through `FUN_005AD440` only after the
whitelisted live-object pass.  This ordering rules out treating the cache
rebuild as an archive-row-to-provider conversion step.

The direct sequence is taken from
`local/source/split-merged/code/0x050000/FUN_0053d100.c`; the canonical EN/CH
comparison row for `0x53D100` is identical.  Native records it as
`OriginalMapLoadRehydrationChain.postRehydrationCallSequence` and tests the
addresses independently.  **Evidence class:** **confirmed** for the direct
order and the cache refresh boundary; **unknown** for any indirect/table-driven
calls, the object-vtable predicates that feed `FUN_005AD440`, and the missing
Qin provider/house/market settlement projection.

## 2026-09-05 cMarket child registration is an explicit-creation boundary

The market helper's child registration path is now separated from map-load
rehydration. `FUN_005428B0 @ 0x5428B0` is reached directly through the thin
wrapper `FUN_00544220 @ 0x544220`, whose only indexed direct caller is
`FUN_005451A0 @ 0x5451A0`. In `FUN_005428B0`, the third formal is tested as a
creation-mode byte. When it is non-zero, the function runs the layout
allocator, creates Empty Shop model `0x3E` (GameData building ID `62`) for
active helper bays, writes each generated child's parent market registry ID at
child `+0x154`, its compact bay ordinal at `+0x150`, writes the child registry
ID into the parent `market + 0x15C[ordinal]`, and finally creates model `0x47`
(GameData building ID `71`) for the generated market-area object. The child
placement-time value is copied to `+0xA0`. The zero branch instead obtains
coordinates from the receiver's virtual helper and does not enter the
placeholder-creation block.

`FUN_005451A0` confirms the wrapper edge: when its final byte is non-zero it
resolves the receiver's registry object through `FUN_004AFE60 @ 0x4AFE60`,
writes the returned short to receiver `+0x62`, then forwards the creation-mode
byte and coordinates to `FUN_00544220`. This is an object/event creation edge,
not a generic archive conversion. The direct post-rehydration sequence in
`FUN_0053D100` contains neither `0x5428B0` nor `0x544220` nor `0x5451A0`; the
`FUN_0052F030` whitelist also excludes market model IDs `0x3B`/`0x3C`.
Therefore a Qin generic archive record cannot be promoted to a live cMarket
with registered Empty Shop/provider children from the recovered map-load path.
Native records this boundary in `OriginalMarketCreationBoundaryCatalog` and
keeps Qin provider/settlement fail-closed.

The enclosing explicit-object factory is also now closed. `Creating @
0x42D540` calls `FUN_0042D360`, whose class dispatch reaches
`FUN_0051C660 @ 0x51C660`; its `FUN_005D36E0 @ 0x5D36E0` predicate recognizes
the shared trade/market model set `{0x35,0x36,0x38,0x3A,0x3B,0x3C}`. The
market-family branch enters `FUN_005D3580 @ 0x5D3580`, which first applies
`FUN_00543D90 @ 0x543D90`; only `0x3B`/`0x3C` then construct through
`FUN_00543450 @ 0x543450` and install vtable `0x007B6F3C`. Inside that
constructor, model `0x3C` selects the Grand-specific five-slot/layout branch.
This proves that an explicit `Creating(59/60, ...)` action can reach the
cMarket construction path; it does not change the map-load result because
`FUN_0052F030` never calls `Creating` for those model IDs under its recovered
whitelist.

As a class-identity cross-check, a raw little-endian pointer scan of both
hash-matched PE files finds the `FUN_005451A0` pointer exactly once, at file
offset `0x003B703C`, corresponding to the first word of the cMarket vtable at
`0x007B6F3C`. EN and CH contain the same word and surrounding vtable row. This
confirms the method's cMarket vtable placement, but does not recover an
indirect caller or a map-load promotion edge.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005428b0.c`,
`FUN_00544220.c`, `FUN_005451a0.c`,
`local/source/split-merged/code/0x040000/FUN_004afe60.c`,
`FUN_0052f030.c`, `FUN_0052f1d0.c`, `FUN_0053d100.c`,
`GameData/Model/EmperorBuildingModels.txt` rows 59–71, and the identical
EN/CH rows in `local/source/compare-report.tsv` for `0x5428B0` and `0x5451A0`,
`0x42D360`, `0x51C660`, `0x5D3580`, `0x5D36E0`, and `0x543450`, plus direct
PE `.rdata` pointer reads at `0x007B6F3C`.

**Evidence class:** **confirmed** for the explicit-mode branch, child model
IDs, offsets, explicit factory chain, direct caller chain, cMarket vtable
placement, and absence from the direct map-load sequence; **unknown** for
indirect vtable dispatch, the exact event that supplies the source
layout/coordinates, provider registry population after creation, route
endpoints, and Qin house/market settlement.

## 2026-09-03 phase-0x21 entertainment decay keeps provider eligibility explicit (confirmed boundary)

The venue scheduler boundary is now represented alongside the water seam.  In
the canonical EN executable, `FUN_004AC2B0 @ 0x4AC2B0` dispatches each active
object's vtable `+0x9C` during scheduler phase `0x21`; the shared callback
`FUN_004AF230 @ 0x4AF230` admits only active-state bytes `1` and `3`, and the
three entertainment-school vtables route that slot to
`FUN_0048AE30 @ 0x48AE30`.  The latter decrements non-zero opportunity bytes
`+0x5D` (acrobat), `+0x5F` (actor), and `+0x5E` (musician) once, counts the
pre-decrement non-zero bytes into record `+0x5C`, and refreshes the provider.
The EN/CH function and vtable bytes are identical in
`local/source/compare-report.tsv`.

`DeterministicWalkerState.advanceRecoveredOriginalSteps` therefore accepts an
explicit `EntertainmentVenueProviderProjection` dictionary carrying the
provider active state, three capacity bytes, and record `+0x5C` count.  At
phase `0x21` it applies the decay only to providers whose supplied state is
`1` or `3`, then stores the pre-decrement non-zero count in `+0x5C`; the legacy
overload passes an empty projection, so Qin's unresolved provider registry
remains fail-closed.  A focused test advances exactly `0x22` scheduler steps
and verifies that an active provider decays all three bytes and records count
`3`, while an inactive provider is unchanged.
This adds no venue walker, route, occupancy, or house settlement behavior.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ac2b0.c`,
`local/source/split-merged/code/0x040000/FUN_004af230.c`,
`local/source/split-merged/code/0x040000/FUN_0048ae30.c`, identical EN/CH
vtable rows in `local/source/compare-report.tsv`, implementation in
`Sources/EmperorCore/WalkerSimulation.swift` and
`Sources/EmperorCore/HousingEvolution.swift`, and regression coverage in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for phase, active-state gate, slot offset,
three byte offsets, decrement/count operation, and explicit Native seam;
**unknown** for provider-object registration, callback refresh side effects,
route/collision state, and the provider-to-house settlement path.

## 2026-09-03 generic-record packed fields are decoded but remain unbound

The generic `Building` stream can be decoded at the field-order level without
pretending that its bytes are an in-memory struct.  `FUN_00427430 @ 0x427430`
reads the schema, then invokes `FUN_00780533` in a fixed sequence.  Summing the
schema-3 calls gives 157 payload bytes; schema 4 adds the two-byte `+0x92`
field for 159.  With the four-byte stream header and the final 20-byte
`+0xB4/+0xB8` tail, these sums exactly reproduce the observed 181/183-byte
record spans.

The resulting packed stream offsets are now explicit in
`OriginalGenericBuildingArchiveCatalog`: load-callback eligibility `+0x04` at
stream `+4`, the raw map-cell word `+0x10` at stream `+14`, base type `+0x14`
at stream `+18`, coordinates `+0x0A/+0x0C` at `+10/+12`, and placement result
`+0xA0` at `+143` (schema 3) or `+145` (schema 4).  The complete scanner
regression over Xiangjun, Haunxian, Xianyang, and Badaling finds zero for the
eligibility byte, map-cell word, both serialized coordinates, and `+0xA0` in
every generic record, alongside the existing zero-base-type and `-1` tail-slot
results.  Because `FUN_0042D790` invokes the
record's `+0xC0` callback only when raw `+0x04` is nonzero, this is a confirmed
negative for callback entry on the serialized generic records themselves.

These are confirmed archive facts, not proof that the runtime objects have no
coordinates or feng-shui state: a different post-load path could still mutate
state after generic construction, even though the generic record's own
`+0xC0` callback is gated off by zero `+0x04`.  Provider registration and any
post-load coordinate/weight writer remain **unknown**.  Native therefore keeps
Qin generic-house, provider, and migration feng-shui projection fail-closed
while retaining the decoded raw fields for future evidence.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00427430.c`,
`FUN_0042D0E0.c`, `FUN_0042D790.c`,
`local/source/split-merged/code/0x070000/FUN_00780533.c`,
`local/source/compare-report.tsv`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and the complete
four-map regression in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for field-order offsets, schema sums,
four-map zero coordinate/placement values, token/schema boundaries, and tail
slots; **unknown** for post-load specialization, runtime coordinate/weight
writers, provider registration, and Native projection.

## 2026-09-03 custom orientation fallback candidate order is closed (confirmed partial)

The failure path in `FUN_0042C100 @ 0x42C100` performs one additional
position search after every orientation bank has failed. When the fallback
mode argument is nonzero, it calls the object's vtable `+0x4C` callback over
an 11×11 window centered on the original point. The outer Y coordinate starts
at `center.y + 5` and decrements through `center.y - 5`; for each Y, X starts
at `center.x + 5` and decrements through `center.x - 5`. The first callback
that sets the object's success byte terminates the scan; if none succeeds,
the source restores the original coordinates. `OriginalCustomOrientationBankSearch.fallbackCandidateOrder`
records the exact 121-point order without supplying callback acceptance or
mutating placement state.

This closes only the deterministic candidate enumeration. The callback's
occupancy/grid predicates, object-state writes, and provider/house effects
remain unknown, so Native does not use this order to select a live market,
palace, gate, or fort orientation.

**Sources:** canonical EN `local/source/split-merged/code/0x040000/FUN_0042C100.c`,
the identical CH row in `local/source/compare-report.tsv`, and
`Sources/EmperorCore/OriginalBuildingGeometryCatalog.swift` with focused
coverage in `Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the 11×11 bounds, descending Y/X order,
termination condition, and EN/CH identity; **unknown** for callback semantics,
dynamic occupancy, and any resulting object or simulation state.

## 2026-09-03 residential provider spawn counter transition is explicit (confirmed boundary)

The common provider generator `FUN_0051CF90 @ 0x51CF90` has now been reduced
to a side-effect-free counter transition.  After the provider's virtual access
and worker gates pass, the routine increments byte `+0x36` with byte semantics,
compares the incremented value **strictly greater than** the provider-specific
`+0x230` threshold, and resets the byte to zero only on a successful figure
request.  A failed access gate, failed worker gate, or non-positive worker
percentage leaves the counter unchanged.  The threshold rows remain the
already recovered tax (`27`), common (`28/30/31`), and religion (`35`) tables.

`OriginalResidentialServiceCatalog.residentialSpawnCounterTransition` records
this transition only when the caller supplies the two unresolved gate results.
It intentionally does not allocate the figure, invoke route/coverage code,
write provider registry slots, or treat Native staffing as a substitute for
the original virtual callbacks.  UInt8 wrap is preserved (`255 → 0`) before
the strict comparison.  Focused regression coverage checks gate blocking,
the threshold-equal non-spawn state, successful reset, zero-worker blocking,
and wrap behavior.

**Sources:** canonical EN
`local/source/split-merged/code/0x050000/FUN_0051cf90.c`, identical EN/CH
comparison row for `0x51cf90`, threshold selectors `FUN_0051cf40`,
`FUN_00507e40`, and `FUN_005ab330` as recorded in
`docs/exe-research/residential-service-roamer-lifecycle.md`; implementation
in `Sources/EmperorCore/HousingEvolution.swift`; focused test in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for gate ordering represented by the explicit
inputs, UInt8 increment, strict `>`, reset, and EN/CH parity; **unknown** for
provider/object registration, callback side effects, figure allocation,
routing, and provider-to-house settlement.

## 2026-09-03 Qin `cIndustrialBldg/173` records are map invasion points (confirmed archive classification)

The specialized class declaration found in `Haunxian.map` and `Xianyang.map`
is not evidence of an authored production building. `GameData/Model/
EmperorBuildingModels.txt` names building ID `173` `BUILD_MAP_INVASION_POINT`,
and `FUN_0051C660 @ 0x51C660` falls through to the `cIndustrialBldg` factory
for this unrecognized model after the specialized predicates return false. The
archive records therefore represent map-point objects despite the runtime class
name.

The read-only `OriginalMapInvasionPointArchiveCatalog` validates the schema-4
class run, common-building ID `173`, inherited coordinate/map-cell fields, the
repeated 313-byte cadence, and the runtime descriptor's backing index. The
canonical records are:

| map | records `(x,y; backing index)` |
| --- | --- |
| `Haunxian.map` | `(106,37; 18618)`, `(34,37; 18546)`, `(15,56; 22859)`, `(5,75; 27181)` |
| `Xianyang.map` | `(114,4; 1255)` |
| `Xiangjun.map`, `Badaling.map` | no `cIndustrialBldg` run |

This parser is archive evidence only. It does not turn these records into
production, invasion formations, routes, or live object-registry entries; the
event-to-figure and registry projection remain separate contracts.

**Sources:** `GameData/Model/EmperorBuildingModels.txt` row 173,
`local/source/split-merged/code/0x050000/FUN_0051C660.c`,
`FUN_0051C9A0.c`, `FUN_0051CE00.c`, common serializer
`local/source/split-merged/code/0x040000/FUN_00427430.c`, EN/CH-identical
factory rows in `local/source/compare-report.tsv`, implementation in
`Sources/EmperorCore/MapInvasionPointArchiveCatalog.swift`, and regression
coverage in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for model 173's authored label, generic
factory fall-through, schema/class/record cadence, coordinates, and backing
indices; **unknown** for complete map-point runtime consumers, registry
ownership, and any event/formation timing derived from these records.

## 2026-09-03 `EmperorMap` exposes archived map-point records without live projection

The map parser now carries the already-validated `cIndustrialBldg/173` run as
`archivedMapInvasionPointStates`.  The property is populated by the same
`OriginalMapInvasionPointArchiveCatalog` scanner used by the focused Qin
regression, so callers no longer need to decode the map a second time merely
to inspect the archive evidence.  It deliberately remains separate from
`authoredPoints.landInvasion`: the header point arrays and the serialized
runtime-class records are distinct source regions, and no source-backed
projection from either region to invasion formations, routes, or the live
object registry has been recovered.

The regression asserts that `EmperorMap` returns byte-for-byte equivalent
archive states for Haunxian, Xianyang, Xiangjun, and Badaling.  This is a
read-only plumbing boundary; no campaign event, military state, or simulation
behavior is changed.

**Sources:** `Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/MapInvasionPointArchiveCatalog.swift`,
`Tests/EmperorCoreTests/EmperorCoreTests.swift`, and the model/factory evidence
listed in the preceding section.

**Evidence class:** **confirmed** for parser reuse and equality with the
validated archive scan; **unknown** for any runtime consumer or event timing.

## 2026-09-04 Qin invasion coordinates are two distinct authored inputs

The four canonical Qin maps make the separation between the header invasion
slots and the serialized `cIndustrialBldg/173` archive concrete.  A
GameData-backed regression compares both source regions and records the exact
ordered values:

| map | header `landInvasion` slots | archive `worldOrigin` records |
| --- | --- | --- |
| `Xiangjun.map` | `(8,77),(31,100),(50,119),(84,124),(95,113),(121,87),(15,55),(43,27)` | none |
| `Haunxian.map` | `(5,74),(15,55),(34,36),(47,23),(68,2),(80,11),(106,37)` | `(106,37),(34,37),(15,56),(5,75)` |
| `Xianyang.map` | `(52,163),(22,134),(6,109),(24,89),(45,68),(82,31),(97,16),(114,4)` | `(114,4)` |
| `Badaling.map` | `(38,122),(28,112),(10,94),(8,77),(21,64),(36,49)` | none |

The header values are serialized by the map descriptor's type `0xAD`
branch (`FUN_0053E560 @ 0x53E560` transfers the parallel eight-slot X/Y arrays
`DAT_00C5CDA4`/`DAT_00C5CDC4`), while the archive values come from the
separate schema-4 `cIndustrialBldg` run already bounded by
`OriginalMapInvasionPointArchiveCatalog`.  Their order and membership are
not interchangeable: even on maps containing both runs, the coordinate sets
and (for `Haunxian`) the Y values differ.  `EmperorMap` therefore keeps both
collections and the regression `testQinInvasionArchiveOriginsAreDistinctFromHeaderSlots`
prevents a future loader change from silently collapsing them.

The EN/CH comparison report marks the descriptor serializer (`0x53E560`), its
header serializer (`0x52CD90`), and the adjacent header-slot consumers
(`0x522AE0` scan and `0x4FA8C0` save/linearization) as `identical`.  Those
consumers therefore corroborate that the `0xAD` slots are a distinct serialized
header state, but they still do not establish which state the campaign event
selector chooses.

This closes a data distinction, not the runtime behavior.  The indexed corpus
does not connect the `0xAD` header arrays or the `173` archive objects to the
campaign event selector, invasion formation builder, or object registry with
enough evidence to choose one as the universal source.  Native's existing
campaign event path consumes `authoredPoints.landInvasion`; archive records
remain read-only evidence, and no archive-to-formation projection is enabled.
Any attempt to substitute the archive origins (or to merge both sets) remains
**unknown** and must stay fail-closed until the missing consumer edge is
recovered.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0053E560.c`,
`local/source/split-merged/code/0x050000/FUN_0052CD90.c`,
`local/source/split-merged/code/0x050000/FUN_00522AE0.c`,
`local/source/split-merged/code/0x040000/FUN_004FA8C0.c`,
`local/source/compare-report.tsv` (identical rows `0x522AE0`, `0x4FA8C0`,
`0x52CD90`, `0x53E560`),
`Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/MapInvasionPointArchiveCatalog.swift`,
`Tests/EmperorCoreTests/EmperorCoreTests.swift`, and the four canonical
`GameData/Cities/{Xiangjun,Haunxian,Xianyang,Badaling}.map` files.

**Evidence class:** **confirmed** for the two serialized coordinate regions,
the exact Qin values, their non-equivalence, and the `0xAD` header write;
**unknown** for the campaign/military consumer choice, archive promotion,
formation timing, and registry ownership.

## 2026-09-03 Eight-slot runtime map-point boundary is preserved (confirmed data boundary)

The canonical EN executable keeps land invasion coordinates in two parallel
eight active entries in two parallel arrays, `DAT_00c5cda4` (X) and
`DAT_00c5cdc4` (Y).  The `FUN_0053cec0 @ 0x53cec0` initialization loop clears
sixteen words in each array; `FUN_0053e560 @ 0x53e560` stores model `0xad`
(`BUILD_MAP_INVASION_POINT`) into the selected array slot;
`FUN_00534410 @ 0x534410` invalidates a pair when the map-coordinate check
fails.  `FUN_0049daf0 @ 0x49daf0` then accepts an object's `+0x78` slot only
when it is in `0...7` and both coordinates are present.  `FUN_00403ea0 @
0x403ea0` consumes the same pair as `(x, y)` and converts it to the canonical
backing-grid index.  `FUN_00522ae0 @ 0x522ae0` scans the X words for eight
iterations from a caller-provided start and wraps at the active eight-slot
boundary.  Its special `param_1 == 8` start expression and the sixteen-word
backing initialization are recorded below.

`Sources/EmperorCore/MapInvasionPointArchiveCatalog.swift` now records the
confirmed slot count, sentinels, pair-validity rule, and deterministic
circular scan order.  `Sources/EmperorCore/EmperorMap.swift` exposes the
header's land-invasion coordinates in the same eight-slot order as
`authoredLandInvasionPointSlots`; the existing compact `authoredPoints` view
is retained for compatibility.  No event, formation, route, or live registry
is wired from this boundary.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0053cec0.c`,
`FUN_0053e560.c`, `FUN_00534410.c`, `local/source/split-merged/code/0x040000/
FUN_0049daf0.c`, `FUN_00403ea0.c`, `FUN_004fa8c0.c`, and the map-header
serializer `local/source/split-merged/code/0x050000/FUN_0052e7c0.c` →
`FUN_0052cd90.c`; implementation in `Sources/EmperorCore/EmperorMap.swift`
and `MapInvasionPointArchiveCatalog.swift`; regression coverage in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for eight active slots, sixteen-word backing
initialization, `0xffff`/`-1` sentinels, paired-coordinate validity, explicit
circular scan order, and header-slot preservation; **unknown** for
event/formation timing or registry ownership.

## 2026-09-03 Invasion random-start and eight-step scan are closed (event remains blocked)

The remaining random-start expression in `FUN_00522AE0 @ 0x522AE0` was checked
from the merged source body and the canonical EN address-range disassembly;
the CH/EN comparison row is `identical`.  The `param_1 == 8` branch calls
`FUN_004189B0`, reads the published primary value, masks it with
`0x8000000F`, and applies the signed fallback `(value - 1 | 0xFFFFFFF0) + 1`
only when the masked value is negative.  The routine returns its scan index in
`EAX`; `FUN_00522B30` stores the low byte into the selected object's `+0x78`
slot before reading the parallel X/Y arrays.  Because
`FUN_004189B0` writes `DAT_010C7138 = stateA & 0x7FFF`, canonical random
starts are the published low nibble `0…15`, including the source-visible
`8…15` range.

The sixteen-word initialization in `FUN_0053CEC0` closes the apparent tail
read: starts `8…15` inspect one initialized `-1` X word, then wrap at eight.
The
Native `sourceRandomStartIndex` and `sourceRandomScanIndex` helpers preserve
the mask, raw start, eight checks, X-only absence test, active-boundary wrap,
and post-loop returned index.  This remains a pure boundary, not a live event
fix: scheduler RNG call order, formation construction, and object-registry
ownership are still not mapped to Native.  The campaign invasion bridge
therefore remains fail-closed; the previous modulo-`eventID` entry selection
remains marked as compatibility behavior rather than original fidelity.

**Sources:** canonical EN/CH hashes above; `local/source/split-merged/code/
0x050000/FUN_00522AE0.c`, `FUN_00522B30.c`, `FUN_00522D00.c`,
`FUN_0053CEC0.c`, and `local/source/compare-report.tsv`; static disassembly of
`Exe/ghidra/input/EmperorEN.exe` at `0x522AE0…0x522B2E`; implementation in
`Sources/EmperorCore/MapInvasionPointArchiveCatalog.swift`; focused regression
in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for mask, signed normalization, RNG call,
sixteen-word initialization, eight-step wrap, X-only absence test, return
register, caller store, and EN/CH parity; **unknown** for full scheduler RNG
order, formation timing, and live registry projection.

## 2026-09-03 Well adjacency refresh is command/UI-owned, not a service scheduler edge

The apparent recurring Well refresh caller was rechecked from the complete
indexed corpus and both hash-matched PE disassemblies. `FUN_00511860 @
0x511860` has exactly one direct call site in each executable:
`0x515913`, inside `TBD_Hit_eHIB_CallTroops @ 0x515800`, the eHIB command
handler's command-`0x69` branch. The function itself performs the already
recovered calendar guard, eight-neighbour target scan, category/model
admission, `+0x6F` write, and command-side notifications; it is not called by
the monthly residential scheduler or by any map-load/post-load routine.

`FUN_00515DF0 @ 0x515DF0` is a nearby UI/command state updater. Its only
related call is `FUN_00511710` (candidate discovery); it does **not** call
`FUN_00511860`, `FUN_00511080`, or the Well byte writer. The direct callers and
the bodies of `FUN_00511860`, `FUN_00511060`, `FUN_00511080`, `FUN_00511710`,
`FUN_00515DF0`, and `TBD_Hit_eHIB_CallTroops` are EN/CH `identical` in
`local/source/compare-report.tsv`; the direct call address `0x515913` is also
identical in the two PE `.text` slices.

This is a confirmed negative for promoting the adjacency callback into Qin's
residential service cadence. The callback's command-owned source object,
controller-category semantics, and provider/object registry projection remain
unknown. Native therefore keeps `FUN_00511860`/`FUN_00511080` research-only:
generic `.water` visits and the Qin map loader must not invoke this path, and
the Qin water provider bridge remains fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00511860.c`,
`FUN_00511060.c`, `FUN_00511080.c`, `FUN_00511710.c`, `FUN_00515DF0.c`,
`local/source/split-merged/figure/TBD_Hit_eHIB_CallTroops.c`,
`local/source/compare-report.tsv`, and canonical EN/CH disassembly call-site
searches for `0x511860`.

**Evidence class:** **confirmed** for the complete direct caller inventory,
command-`0x69` ownership, and EN/CH parity; **confirmed negative** for a
residential scheduler/map-load caller; **unknown** for the source command's
semantic category, callback registration, and provider settlement.

## 2026-09-03 cMarket `+0xAC` guard is not a startup peddler blocker

The peddler wrapper's global guard is now bounded from the complete static
corpus. `FUN_00545170 @ 0x545170` reads `DAT_010BC7E0 + 0xAC` through
`FUN_004AFDB0 @ 0x4AFDB0` and calls `FUN_00543ED0` only when the byte is zero.
`FUN_005355F0 @ 0x5355F0` clears `0x43` dwords at that array and then the
following byte, which is exactly offset `0xAC`; after initialization the
guard is therefore false. A corpus-wide search finds no direct gameplay
writer for this offset (only the peddler, buyer, generic model-23, and model-
37 reads plus initialization). EN/CH comparison rows for the indexed
functions are `identical`.

This is a confirmed negative against treating the global suppression byte as
the Qin market failure. It does not resolve the cStall/provider record
population, model-23 route, or household quality/coverage writer, so the Qin
market and migration bridges remain fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00545170.c`,
`FUN_00543ed0.c`, `FUN_0051cf90.c`, `FUN_00541b80.c`, `FUN_00535540.c`,
`FUN_005355f0.c`, `local/source/split-merged/code/0x040000/FUN_004AFDB0.c`,
and `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for read/clear order and EN/CH parity;
**confirmed negative** for a direct corpus writer; **unknown** for indirect
alias writes and downstream market settlement.

## 2026-09-03 Qin campaign peddler timing remains fail-closed without raw cStall input

The source ratio gate consumes Empty Shop cStall `+0x44` units divided by
the filled-shop model-table employee aggregate. Native's workforce
assignment percentage is not a proven equivalent. The timing bridge now
requires an explicit `workerPercentByMarketID` value and does not turn a
missing value into `100%`; a focused regression verifies that the counter and
stock remain unchanged when the raw input is absent. Campaign worlds also do
not advance or mutate peddler state while provider-record, route, and
household quality/coverage projection remain unresolved. Explicit-ratio
compatibility fixtures remain available for isolated source-arithmetic tests.

This is an integration safety correction, not evidence that the original
campaign has no peddlers. It prevents Native staffing from silently becoming
the source of original cStall state while the Qin bridge is still unknown.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00543ed0.c`,
`FUN_00544a40.c`, `FUN_00544a80.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/MarketSimulation.swift`,
`Sources/EmperorCore/CitySimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for source aggregate inputs and EN/CH
parity; **inferred** for the fail-closed integration policy; **unknown** for
provider quantity, route, and settlement projection.

## 2026-09-03 `DAT_00C5CDA0` startup Dinners-gate audit

The monthly object pass `FUN_004AEDF0 @ 0x4AEDF0` reaches an object's virtual
`+0x154(0x1C, 200)` only when the global `FUN_00426D10(0)` check, the object's
virtual `+0xC8(-3)` check, and `DAT_00C5CDA0 != 0` all succeed. The same byte is
read by the food depletion/status helpers (`FUN_00518690`, `FUN_00548770`,
`FUN_005D2C70`, `FUN_005D7E40`, and `FUN_00541220`).

Both identified mission initialization paths clear the base byte:
`FUN_0053CEC0 @ 0x53CEC0` and `FUN_00535060 @ 0x535060` assign
`DAT_00C5CDA0 = 0`. The only other textual match that writes near this symbol,
`FUN_00404990`, uses `&DAT_00C5CDA0 + index*2 + 2`, i.e. the adjacent
coordinate-array region rather than the base gate. Complete indexed search and
the EN/CH comparison report show no direct store that enables the base byte.

**Conclusion:** confirmed negative for “Qin Dinners/peddlers are absent because
the startup global gate is still enabled.” Alias/indirect runtime writes remain
unknown. This does not recover the object callback, cMarket provider records,
food quantity/quality projection, or Native household settlement; Qin market
and automatic migration therefore remain fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AEDF0.c`,
`FUN_00404990.c`; `local/source/split-merged/code/0x050000/FUN_00518690.c`,
`FUN_00535060.c`, `FUN_0053CEC0.c`, `FUN_00541220.c`, `FUN_00548770.c`,
`FUN_005D2C70.c`, `FUN_005D7E40.c`; `local/source/compare-report.tsv` rows
`0x4AEDF0`, `0x404990`, `0x518690`, `0x535060`, `0x53CEC0`, `0x541220`,
`0x548770`, `0x5D2C70`, and `0x5D7E40`.

**Evidence class:** confirmed for the guard, initialization clears, adjacent
array offset, reader inventory, and EN/CH parity; confirmed negative for a
direct startup/gameplay writer; unknown for alias/indirect writes and all
provider/settlement projections.

## 2026-09-03 Type-`0xD` vagrant helper is not Qin automatic migration

The complete EN/CH call inventory for `FUN_004AE150 @ 0x4AE150` contains only
`0x4AE1E2` (`FUN_004AE1A0`), `0x4B31BF` (`FUN_004B2D00`), and `0x518A9C`
(`FUN_00518A50`); the four call bytes are identical in both hash-matched PE
images. The callee creates figure type `0xD`, initializes its state/count
fields, and calls `FUN_00591950`; it has no immigrant type-`0xB`, food,
popularity, mission, or provider input. `FUN_004AE1A0` is calendar case
`0x18`'s negative-spare-room repair and is already covered by §10.97.
`FUN_004B2D00` reaches the helper only inside its object/map rectangle pass;
`FUN_00518A50` reaches it after a failed route check and retry overflow. The
vtable owner and the population-ledger meaning remain unknown.

This is a confirmed negative against using the type-`0xD` helper to unblock
Qin migration. Native keeps vagrant spawning, route/registry projection, and
the automatic campaign producer fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AE150.c`,
`FUN_004AE1A0.c`, `FUN_004AC2B0.c`, `FUN_004B2D00.c`, `FUN_004B29C0.c`,
`local/source/split-merged/code/0x050000/FUN_00518A50.c`, the EN/CH
`local/source/compare-report.tsv` rows, and the direct PE call-byte scan.

**Evidence class:** **confirmed** for the call inventory, type/count writes,
calendar/object/retry contexts, and EN/CH parity; **unknown** for indirect
vtable ownership, figure route/registry effects, and `FUN_00591950` ledger
semantics.

## 2026-09-03 Qin migration population is not a proven raw house sum

The source population input was separated from the Native convenience
property. `FUN_00517CC0 @ 0x517CC0` calls `FUN_00517DE0 @ 0x517DE0`; the latter
walks the live object vector and adds signed 16-bit object `+0x20` only when
state byte `+0x04` is not `0`, `2`, `5`, or `6` and the object's vtable
`+0xB8` eligibility callback succeeds. It stores that total at caller output
`+0x28`; a second total at `+0x2C` includes only objects whose vtable `+0x204`
class predicate succeeds. `FUN_00591200 @ 0x591200` is one indexed caller of
`FUN_00517CC0`, so this filtered `+0x28` aggregate is the population value
used by the original popularity update. The indexed EN/CH rows for
`0x517CC0` and `0x517DE0` are `identical`.

Native `CitySimulation.population` sums `ResidentialUnit.residents` and has
no source-equivalent state byte or `+0xB8` callback. Qin's authored houses
are residential records, but the corpus does not establish that every
Native unit remains a source-eligible object through vacant conversion,
repair, specialized load, and object-state transitions. This is a confirmed
input mismatch boundary, not evidence for adding a guessed filter: the
campaign automatic-migration producer stays `.unsupportedOriginalProducer`
until the object-state and eligibility projection are recovered. The prior
120-month replay and all service/market blockers are unchanged.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00517cc0.c`,
`FUN_00517de0.c`, `FUN_00591200.c`, `local/source/compare-report.tsv`, and
`Sources/EmperorCore/CitySimulation.swift` (`population`).

**Evidence class:** **confirmed** for the filtered object-vector aggregation,
separate `+0x2C` class total, migration caller, and EN/CH parity; **unknown**
for the complete serialized state mapping, `+0xB8` semantic projection,
specialized/vacant object eligibility, and Native equivalence.

## 2026-09-03 Population-ledger arithmetic is explicit but not a Qin bridge

The source-side population side effects are now represented as a raw ledger
helper, but this does not close Qin migration. `FUN_00591970` subtracts from
`DAT_0130F988`, clamps at zero, and updates high-water `DAT_0131257C` through
`FUN_00590A50`; `FUN_005919A0` performs the corresponding add. `FUN_00591950`
first increments `DAT_01311F8C` and then takes the decrement path, while
`FUN_00591930` first decrements `DAT_01311F8C` and then takes the increment
path. These functions and the relevant direct callers are EN/CH `identical`.

The second global word has no stable semantic name or Native projection in the
corpus. `FUN_00591950` is reached from the already-separated type-`0xD`
vagrant helper, not the type-`0xB` Qin migration producer. Native therefore
keeps the helper research-only and does not synthesize population events or
enable the producer from this arithmetic alone.

**Evidence:** `local/source/split-merged/code/0x050000/`
`FUN_00591920.c`, `FUN_00591930.c`, `FUN_00591950.c`, `FUN_00591970.c`,
`FUN_005919a0.c`, `FUN_00590a50.c`, `FUN_00590e00.c`, `FUN_00591200.c`;
`local/source/split-merged/code/0x040000/FUN_004ae150.c`,
`FUN_0042aaa0.c`, `FUN_004681a0.c`, `FUN_004c8b70.c`;
`local/source/compare-report.tsv`; and
`Sources/EmperorCore/MigrationSimulation.swift`.

**Evidence class:** **confirmed** for arithmetic, call ordering, and EN/CH
parity; **confirmed negative** for a recovered Qin Native event bridge;
**unknown** for `DAT_01311F8C` semantics, indirect callers, and provider/
registry projection.

## 2026-09-03 Map-load provider-registration census remains a confirmed negative

The map/archive load path was re-traced from the indexed EN and CH functions,
including the direct factory callers. `FUN_0042D790 @ 0x42D790` decodes each
record through `FUN_0042D0E0`, inserts the resulting generic `Building` through
`FUN_0042B590`/`FUN_005F01F0`, and conditionally invokes the current object's
virtual `+0xC0`. The generic `Building` slot resolves to
`FUN_004271B0 @ 0x4271B0`; its `+0x150` dispatch is the constant-false
`FUN_00413A00` for the base, Well, Herbalist, and Acupuncture vtables checked
in the corpus, after which only the common reinsert path runs. The loader body
contains no call to `FUN_0042D360`, `FUN_0051C660`, `FUN_0051BEF0`, no
provider `+0x2D` assignment, and no provider-list insertion.

The only direct `FUN_0042D360 @ 0x42D360` call sites remain `0x42715E` inside
the conversion wrapper `FUN_00427150` and `0x42D714` inside
`Creating_pctd_type_pctd @ 0x42D540`; its service branch reaches
`FUN_0051C660 → FUN_0051BEF0` only on those explicit create/replace paths.
The separate post-load repair `FUN_0052F030 → FUN_0052F1D0` admits authored
repair models but excludes service IDs `72/73`, `207/208`, and `211…213`.
The EN/CH comparison rows for all of these functions are `identical`.

**Conclusion:** confirmed negative for treating generic map loading or the
known post-load repair pass as Qin Well/Herbalist/Acupuncture/Music provider
registration. The source of serialized provider identity, any indirect
specialization, provider-list ordering, and downstream house settlement remain
**unknown**. Native therefore keeps Qin service refresh and campaign
automatic migration fail-closed; no gameplay wiring changes follow from this
trace.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_0042D0E0.c`, `FUN_004271B0.c`, `FUN_0042D360.c`,
`Creating_pctd_type_pctd.c`, `FUN_0042B590.c`, `FUN_0042B580.c`,
`FUN_005f01f0.c`,
`local/source/split-merged/code/0x050000/FUN_0051C620.c`,
`FUN_0051C660.c`, `FUN_0051BEF0.c`, `FUN_0052F030.c`, `FUN_0052F1D0.c`,
`local/source/compare-report.tsv`, and the direct caller census in
`docs/exe-research/residential-service-roamer-lifecycle.md` §§7.3ak, 7.3ap,
10.

**Evidence class:** **confirmed** for the loader call order, generic callback,
factory call-site inventory, service-model exclusion, and EN/CH parity;
**confirmed negative** for a direct map-load registration edge; **unknown**
for indirect/table-driven specialization, serialized provider identity, and
runtime registry/settlement projection.

## 2026-09-03 Canonical PE callsite census separates map loading from explicit factory creation

To make the preceding negative reproducible, a direct `E8` call census was
run against both canonical PE images with image base `0x00400000` (English
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`). The
relative callsite sets are identical in EN and CH:

* `FUN_0042D360 @ 0x0042D360` has exactly two direct callers: `0x0042715E`
  in `FUN_00427150` and `0x0042D714` in
  `Creating_pctd_type_pctd @ 0x0042D540`.
* `FUN_0042D790 @ 0x0042D790` has eleven direct callers: `0x0052E961`,
  `0x0052EB28`, `0x0052FE5F`, `0x0053065F`, `0x00530C54`, `0x0053125A`,
  `0x00531A42`, `0x00532031`, `0x0053263B`, `0x00532DE9`, and
  `0x005335B7`. These are the archive/map-load entry points; none is a
  direct call to the specialized factory.
* `Creating_pctd_type_pctd @ 0x0042D540` has twenty-one direct callers. The
  map-adjacent repair edge is `0x0052F0D1` (the
  `FUN_0052F030 → FUN_0052F1D0` pass); its authored-model whitelist excludes
  service IDs `72/73`, `207/208`, and `211…213`. The remaining indexed edges
  are explicit object/mission operations, not callers from the
  `FUN_0042D790` load sites.
* `FUN_0051C9A0` has seventeen direct callers in both images. These are
  factory-side constructors reached from explicit creation paths; the census
  found no edge from the eleven map-load sites above.

This is a callsite inventory, not proof that indirect dispatch or serialized
provider identity cannot exist. It closes only the direct-edge question:
generic archive loading and the known repair pass do not directly register
Qin Well/Herbalist/Acupuncture/Music providers. Indirect/table-driven
specialization, provider-list ordering, and house-service settlement remain
**unknown** and stay fail-closed in Native.

**Sources:** `Exe/ghidra/input/EmperorEN.exe`,
`Exe/ghidra/input/EmperorCH.exe`; `local/source/split-merged/` entries for
`FUN_0042D790`, `FUN_0042D360`, `Creating_pctd_type_pctd`,
`FUN_0051C9A0`, `FUN_0052F030`, and `FUN_0052F1D0`; and
`local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the direct PE callsite sets and EN/CH
parity; **confirmed negative** for a direct archive-load-to-service-factory
edge; **unknown** for indirect dispatch, serialized provider identity, and
runtime registry/settlement.

## 2026-09-03 Model-23 construction does not hide the missing peddler route

The model-23 allocation boundary was followed past the market wrapper. After
the cMarket worker/stock gates, `FUN_00543ED0 @ 0x543ED0` calls
`FUN_004EA050(..., 0x17, ...)`. That function is only a thunk to
`FUN_004E1420 @ 0x4E1420`; its `param_2 == 0x39` case allocates `0x19C` bytes,
selects `FUN_004E1D80 @ 0x4E1D80`, and labels the figure type `0x17`.
`FUN_004E1D80` itself only runs the common `FUN_004E1A40` constructor and
replaces the vtable pointer; it writes no peddler route, destination, market,
or cargo fields.

The common creator then invokes the newly selected object's virtual slots
`+0xE8`, `+0xEC(param_1,param_2,param_3,param_4,param_5)`, and `+0x18` before
returning the figure. A direct read-only table check against both canonical
PEs resolves these entries for vtable `0x7B27AC` as `0x5E3610`, `0x4C9160`,
and `0x4C92D0` (the same words are present at the base figure vtable
`0x7B023C`). `0x5E3610` runs the common zeroing pass, calls `+0x1F0(-1,-1)`,
`+0x1C4`, `+0x1D0`, and stores the `+0x1B4` result at figure `+0x174`.
`0x4C9160` is the concrete five-argument initializer: it writes the model
and active bytes, copies the two supplied coordinates into the figure's
`+0x1C/+0x20/+0x2C/+0x34` and `+0x1E/+0x22/+0x2E/+0x36` fields, sets
`+0x41 = 0x14`, stores map-space coordinates at `+0x52/+0x54`, and records
the supplied heading at `+0x19`. `0x4C92D0` is the short common post-init
predicate. These concrete initializers are now recovered; they still do not
construct a route buffer. The post-allocation writes that *are* visible
remain the wrapper's `figure+0x40 = 1`, `figure+0x62 = market registry ID`,
market/figure eight-way rotation update, and the `FUN_004E6A70` bootstrap.

`FUN_004C72B0` zeros the common figure state, including the mode byte at
`+0x80`, selector/phase storage at `+0x170`, and route progress byte `+0x41`.
`FUN_004E6A70` then sets `+0x41 = 0x14`, initializes the return/heading state,
and performs the first route-target probe. This confirms the existing Native
model-23 clock seed (`20` substeps) but does not recover the route buffer,
collision callback, or market-house writer. EN and CH bodies for the named
functions are identical.

**Conclusion:** the concrete virtual initializer targets are confirmed, while
the constructor remains a confirmed negative for “supplies a complete
peddler route.” The route buffer/collision consumer, map-cache projection,
and subsequent market writer remain the Qin peddler blocker. Native must not
replace its fail-closed campaign route boundary with a constructor-derived
household route.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00543ed0.c`,
`local/source/split-merged/code/0x040000/FUN_004ea050.c`,
`FUN_004e1420.c`, `FUN_004e1d80.c`, `FUN_004e1a40.c`, `FUN_004c72b0.c`,
`FUN_004e6a70.c`, `local/source/compare-report.tsv`, and the direct EN/CH
vtable/call-site inventory for `0x4E1420`. Direct read-only PE slices used for
the three previously unindexed interiors are `0x4C9160…0x4C921B`
(SHA-256 `1f75357d87073c806b469f4370aefe9f9dd2bfe4f4073460c8cbd3b0fcc3b18f`),
`0x5E3610…0x5E365B` (SHA-256
`f8f0869560d10aef71e404543f73d1024a2042829bacb9aa065aee14017dcbfe`), and
`0x4C92D0…0x4C92E3` (SHA-256
`c37e72a6f8bc87da554aed773d8319f2b69c56168aaf6d30dc46841c611bc355`),
identical in EN and CH.

**Evidence class:** **confirmed** for the allocation switch, vtable targets,
initializer field writes, visible post-allocation writes, common zeroing,
bootstrap seed, and EN/CH parity; **confirmed negative** for a
constructor-level route; **unknown** for the route-buffer/collision consumer,
map-cache projection, and downstream settlement projection.

## 2026-09-03 cMarket six-slot child registry has only two indexed writers

The cMarket child registry was checked as a write-site question rather than
inferred from the reader helpers. `FUN_00544A00 @ 0x544A00` reads
`market + 0x15C + slot * 4`, and `FUN_00544F10 @ 0x544F10` serializes exactly
six DWORDs at `market + 0x15C` through `+0x170`. A direct instruction scan of
the canonical EN and CH `.text` sections found only two indexed stores of the
form `mov [receiver + index*4 + 0x15C], childRecord`:

* `0x540F01` inside `FUN_00540E70 @ 0x540E70`; the replacement path obtains
  the former child's slot index from its `+0x150`, creates/reinitializes a
  model-`0x3E` Empty Shop, copies the new child's record ID from `+0xB4`, and
  stores that ID into `parent + 0x15C[slot]`. The source body and the
  `FUN_004B1250 @ 0x4B1250` create/replace caller are `identical` EN/CH.
* `0x544C7D` inside `FUN_00544B30 @ 0x544B30`; the cleanup/relink path creates
  the replacement Empty Shop at the former coordinates, writes its
  `+0x154` parent ID and `+0x150` slot index, and mirrors the replacement
  record ID into the same `parent + 0x15C[slot]`. The body is `identical` EN/CH
  and its only direct call is the already documented `0x541106` edge from the
  `0x5410C0` cleanup path.

The two complete PE slices are byte-identical across the canonical builds:
`0x540E70…0x540F7A` is 267 bytes with SHA-256
`aa684e563a8e33f6c6d525dbed3b5ee2168468b5f861b61892d5f458971af229`, and
`0x544B30…0x544D22` is 499 bytes with SHA-256
`e3ca4519a79f83f937ba273f66bd8d1020fbf0db321a3d8c249749575e48ac4f`.
The unindexed `FUN_005DDCA0 @ 0x5DDCA0` store to an unindexed `+0x15C`
field is a separate scalar setter called by the `0x4FCB…` city-state paths;
it has no indexed child-slot access and is not a cMarket registry writer.

This closes the direct population/relink write-site inventory for the six-slot
registry. It does **not** recover the initial cMarket record key/quantity
producer, the semantic meaning of the child `+0x44` value, or the provider →
market → household route/coverage/settlement projection. The Qin market
bridge therefore remains fail-closed; no Native runtime wiring follows from
the census.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00540e70.c`,
`FUN_00544A00.c`, `FUN_00544B30.c`, `FUN_00544F10.c`,
`local/source/split-merged/code/0x040000/FUN_004B1250.c`,
`local/source/compare-report.tsv`, and direct EN/CH PE instruction scans for
`+0x15C + index*4` stores.

**Evidence class:** **confirmed** for the two indexed registry writers,
receiver/slot fields, replacement/relink call edges, six-slot serialization,
and EN/CH parity; **confirmed negative** for any third indexed writer in the
canonical `.text`; **unknown** for initial record key/quantity production,
child `+0x44` semantics, provider identity, and downstream settlement.

## 2026-09-03 Qin venue state-7 route-mode attribution correction

The entertainment route evidence is now attributed to the actual venue FSM
state rather than only to the shared mode-`0x12` branch. Direct EN/CH PE bytes
for `0x48A9A0…0x48AD1F` show that venue state `7` writes figure `+0x80 = 1`
before `0x4E9620(..., 1)`, `0x48A340`, and `0x48A520`. The shared dispatcher
`FUN_004E7FD0` therefore takes switch case `1`, forwards the candidate target
array and `n×2` side-weight array from `FUN_0048A520`, and calls
`FUN_005B0620` with its literal final mode `1` when the weight pointer is
non-zero. That selects `FUN_005B0360`'s four-cardinal-neighbour flood with
mask `0x0B0C`, then the confirmed weighted record walk and one-based result.
The zero-weight-pointer branch remains `FUN_005B04A0` mode `1`.

This corrects the context of the existing weighted chooser note: the generic
`+0x80 == 0x12` case shares the dispatcher but is not the venue state-7
assignment. The generated four-parameter C prototype omits the additional
stack arguments; the direct call-site bytes and six-argument
`FUN_005B0620.c` body preserve them. The state/mode/weight forwarding and
EN/CH parity are **confirmed**; provider registry projection, route/collision
effects, occupancy mutation, and provider-to-house settlement remain
**unknown**. Qin venue figures remain fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0048a520.c`,
`FUN_004e7fd0.c`, `local/source/split-merged/code/0x050000/FUN_005b0620.c`,
`FUN_005b0360.c`, `local/source/compare-report.tsv`, and the direct
hash-identified EN/CH PE slice `0x48A9A0…0x48AD1F`.

**Evidence class:** **confirmed** for the venue state assignment, dispatcher
case, literal mode, candidate/weight forwarding, four-way `0x0B0C` flood, and
EN/CH identity; **unknown** for registry, collision, occupancy, and settlement
effects.

## 2026-09-03 Qin market `+0x44` global-writer false lead excluded

The market `+0x44` census found one additional indexed writer,
`FUN_004AD850`, but its object loop admits only model IDs `0x82/0x83` through
the literal predicates `FUN_0042B720`/`FUN_0042B730`. cStall/Empty Shop and
named shop models are `0x3E` and `0x40…0x46`, so the monthly global writer
cannot populate cStall `+0x44`. Its caller is `FUN_004AD4A0` from the monthly
dispatcher, and the EN/CH rows are `identical`.

This is a confirmed negative for reusing that global field assignment as Qin
market stock or staffing. The cStall-specific `+0x18C → 0x51E310` writer and
its table/provider inputs remain the only relevant positive writer boundary;
their semantic and settlement projection remain **unknown**, so Qin market
behavior stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ad850.c`,
`FUN_004ad4a0.c`, `FUN_0042b720.c`, `FUN_0042b730.c`,
`local/source/split-merged/code/0x050000/FUN_005418d0.c`,
`local/source/compare-report.tsv`, and `GameData/Model/EmperorBuildingModels.txt`.

**Evidence class:** **confirmed** for the writer's model filter, monthly call
edge, EN/CH parity, and disjoint model sets; **unknown** for cStall stock
semantics, provider inputs, and downstream settlement.

## 2026-09-03 Qin baseline regression gate (verification only)

After the market false-lead exclusion, the canonical macOS test command
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` was run
to verify that the research-only changes did not alter the Native simulation
gate. The suite completed with **580 tests passed, 0 failures, and 5 tests
skipped**. The Qin-3 playthrough remains intentionally skipped by
`Qin3PlayerPlaythroughTests`: its guard reports that the 120-month command run
still reaches only 27/40 initial houses and remains below level 6 because the
music, water dual-house fields, market-peddler coverage, and desirability
contracts are unresolved. The focused market family run (`--filter
EmperorCoreTests/testOriginalMarket`) completed with 48 passed and 0 failures.

This entry is verification evidence only; no runtime provider, market, or
migration wiring was enabled by the preceding commits. The unresolved
contracts and fail-closed policy therefore remain unchanged.

**Evidence class:** **confirmed** for the local build/test outcomes and the
reported Qin skip guard; **unknown** for the same provider/settlement
boundaries listed above.

## 2026-09-03 generic Building constructor is distinct from the factory fallback (confirmed)

The constructor names in the decompiler output must not be collapsed into one
"generic Building" path.  `FUN_0042D0E0 @ 0x42D0E0` asks
`FUN_0077FD90` for the authored `Building` class descriptor at `0x817890`.
The descriptor's constructor is `FUN_0042D050 @ 0x42D050`: it allocates the
`0xC8`-byte base object through `FUN_0040AE80`, calls
`FUN_00426C90 @ 0x426C90`, and that base initializer installs vtable
`0x7AB59C`.  This is the object type that `FUN_0042D790` inserts before its
`+0xC0` load-callback dispatch.

`FUN_0051C9A0 @ 0x51C9A0` is a separate fallthrough constructor reached from
`FUN_0051C660 @ 0x51C660` only after its preceding model predicates fail.  It
also calls `FUN_00426C90`, but then calls `FUN_0051C2E0` and overwrites the
vtable with `0x7B65E4`; the recovered factory table identifies that table as
`cIndustrialBldg`, and the direct factory census does not admit Qin service
IDs through this fallback.  Therefore `0x7B65E4` cannot be used as the
archive loader's base `Building` vtable, and the presence of
`FUN_0051C9A0` in the service factory does not recover the missing
generic-record specialization or provider-registry write.

The EN/CH split rows for `0x42D050`, `0x42D0E0`, `0x42D790`, `0x51C660`, and
`0x51C9A0` are unchanged/identical where indexed.  This correction removes a
constructor-label ambiguity only; the pre-callback vtable replacement,
serialized provider-index source, and post-load `+0x2D` registration remain
**unknown**, so Qin stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042D050.c`,
`FUN_0042D0E0.c`, `FUN_0042D790.c`, `FUN_00426C90.c`,
`local/source/split-merged/code/0x050000/FUN_0051C660.c`,
`FUN_0051C9A0.c`, `FUN_0051C2E0.c`, `local/source/compare-report.tsv`,
`docs/exe-research/residential-service-roamer-lifecycle.md` §7.3l, and
`docs/exe-research/migration-popularity-producer.md` §5.8.

**Evidence class:** **confirmed** for the two constructor call chains, vtable
installations, and their separation; **unknown** for any indirect/table-driven
archive replacement and provider registration.

## 2026-09-03 `FUN_0044CC50` returns the raw Feng Shue model field for placement (confirmed)

The placement producer's model-value input can be closed beyond the
decompiler's incomplete `void` prototype.  The canonical EN PE bytes at
`FUN_0044CC50 @ 0x44CC50` are:

```text
mov ecx,[esp+4]
mov edx,[esp+8]
lea eax,[ecx+ecx*2]
lea esi,[edx+ecx]
lea eax,[esi+eax*4]
mov eax,[eax*4+0x00A5B398]
if edx == 0: call FUN_0044C380(ecx, eax)
ret
```

The effective return is therefore
`DAT_00A5B398[modelID * 13 + selector]`.  Selector `0` additionally applies
the difficulty/runtime adjustment in `FUN_0044C380`; every non-zero selector
returns the raw table word unchanged.  `FUN_0042B250 @ 0x42B250` calls this
wrapper with selector `0xC`, so its placement `modelValue` is exactly table
column 12, the authored `m - Feng Shue Value` field in
`GameData/Model/EmperorBuildingModels.txt` (the Native parser's
`BuildingModel.fengShuiValue`).  This removes the previous inference that the
wrapper might adjust or reinterpret the placement field.

The result closes only the model-field source.  `FUN_0042B250` still depends
on the custom/ordinary geometry callback and dynamic map-word layer, and
`FUN_00591670` still consumes object `+0xA0` only after the unresolved archive
projection/registration path.  Qin migration/desirability therefore remains
fail-closed; no Native terrain summary is substituted for the source object
weight.

**Sources:** direct canonical EN PE disassembly at `0x44CC50…0x44CC78`,
`local/source/split-merged/code/0x040000/FUN_0044CC50.c`,
`FUN_0044C380.c`, `FUN_0042B250.c`, `FUN_00591670.c`,
`GameData/Model/EmperorBuildingModels.txt`,
`Sources/EmperorCore/LegacyModelParser.swift`, and the identical EN/CH rows
for `0x42B250`/`0x44CC50` in `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the 13-column table indexing, the
selector-0-only adjustment branch, selector `0xC`, and the model-field
identity; **unknown** for callback geometry, dynamic map-word projection,
archive recomputation, and provider/house settlement.

## 2026-09-03 Entertainment-school `+0x1BC` staffing input is now explicit

The Qin music blocker has one narrower input boundary. The Music, Acrobat, and
Drama School vtables (`0x7ACEDC`, `0x7AD140`, and `0x7AD3A4`) all point at the
same `+0x1B0/+0x1B8/+0x1BC` helper chain in both canonical PE variants. The
`+0x1BC` result is zero when provider byte `+0x6E` is non-zero; otherwise it is
the signed object word `+0x44` multiplied by 100 and divided by
`FUN_0044CC50(modelID, 5)`, the authored employee field. The manager's
`FUN_0048F140` accepts a school only when this result is positive.

Native now records that arithmetic in
`OriginalResidentialServiceCatalog.entertainmentProviderStaffingPercent` with
raw fields as explicit inputs and regression coverage for the zero guard,
signed numerator, and integer truncation. This does **not** identify the
producer of object `+0x44`, the serialized/provider registry projection, or the
venue route/house settlement; the Qin entertainment bridge therefore remains
fail-closed. The new primitive only prevents a future implementation from
substituting a Native assigned-worker percentage for the executable's raw
staffing input.

**Sources:** canonical EN/CH PE vtable words and direct bodies at
`0x00428EB0`, `0x00416B10`, and `0x00428ED0`; `local/source/split-merged/code/
0x040000/FUN_00428ED0.c`, `FUN_0044CC50.c`, `FUN_0048F140.c`;
`GameData/Model/EmperorBuildingModels.txt`; and
`docs/exe-research/residential-service-roamer-lifecycle.md` §10.6a.

**Evidence class:** **confirmed** for shared vtable targets, fields, selector,
ratio arithmetic, and EN/CH parity; **unknown** for raw-field production,
provider registration, routing, and settlement.

## 2026-09-03 Phase-`0x14` admission-failure path does not unblock Qin migration

The phase-`0x14` fallback from `FUN_0051E4A0 @ 0x51E4A0` was traced through
`FUN_004C0F60 @ 0x4C0F60` and its virtual `+0x25C/+0x260` callbacks in both
hash-identified executables (`8a6d2df1…6753` and `dbdeca1e…15a`).
`FUN_004C11B0` admits only model IDs `0x1A/0x1B/0x1C` and `0xC2…0xC7`;
`GameData/Model/EmperorBuildingModels.txt` identifies these rows as Tea Bush,
Lacquer Tree, Mulberry Tree, and Hemp/Wheat/Millet/Rice/Cabbage/Soybean fields.
The callback table then selects agricultural/status implementations: the
`+0x25C` family returns the model/status values from `FUN_004C2260`,
`FUN_004C2600`, or `FUN_004C2730`, and the field-family predicate
`FUN_004C3440` maps `26→0xED`, `27→0xEE`, `28→0xEF`, `0xC2→0xC0`, and
`0xC3…0xC7→0xC1`.  The paired `+0x260` slots are status/feedback callbacks;
they do not write a provider index or residential coverage.

The caller edge is therefore a confirmed agricultural object-maintenance path,
not the missing Qin migration producer.  It has no recovered edge to the
figure-`#11` arrival/route chain, a residential provider registry, or a house
coverage writer.  Native keeps the raw phase-`0x14` record helper as
research-only and does not turn these model IDs into migration or settlement
objects.  The callback meanings, registry provenance, and any separate
post-load/table-driven provider creation remain unknown.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051E4A0.c`,
`FUN_004C0F60.c`, `FUN_004C11B0.c`, `FUN_004C0600.c`, `FUN_004C0630.c`,
`FUN_004C0640.c`, `FUN_004C2600.c`, `FUN_004C2730.c`, `FUN_004C31F0.c`,
`FUN_004C3440.c`, the canonical EN/CH PE vtable slices for the `+0x25C` and
`+0x260` slots, `local/source/compare-report.tsv`, and
`GameData/Model/EmperorBuildingModels.txt`.

**Evidence class:** **confirmed** for the caller branch, object whitelist,
authored crop/tree/field cross-reference, callback-family mapping, and
EN/CH identity; **unknown** for callback semantics, provider creation,
registry insertion, and downstream Qin migration/coverage settlement.

## 2026-09-03 House population callback projection is explicit, but Native equivalence remains unknown

The source population aggregate has a narrower HouseBldg projection than the
Native `ResidentialUnit` convenience sum.  `FUN_00517DE0 @ 0x517DE0` excludes
object state bytes `0`, `2`, `5`, and `6`, then calls the object's `+0xB8`
callback before adding the signed 16-bit resident word at `+0x20`.  For the
canonical HouseBldg vtable `0x7ABA38`, `+0xB8` is `FUN_0042DD40 @ 0x42DD40`,
whose direct body returns true iff object byte `+0x09` is non-zero.  The same
walk's secondary total calls `+0x204`; HouseBldg maps that slot to
`FUN_00518D90 @ 0x518D90`, whose EN/CH-identical body returns true iff signed
model word `+0x14 >= 11`.

`OriginalHousePopulationCallbackInput` now records these raw fields and
projects them into the existing explicit population aggregate.  Regression
coverage verifies the four excluded state bytes, the `+0x09` population gate,
the signed resident word, and the exact `+0x14 == 11` upper-class boundary.
This closes the callback-to-field mapping for a source HouseBldg object; it
does not claim that a generic map archive record has already become a
HouseBldg, nor that every Native residential unit preserves the source state
byte and `+0x09` lifecycle through vacant conversion, repair, or load.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00517DE0.c`,
`docs/exe-research/migration-popularity-producer.md` §5.8,
`docs/exe-research/desirability-propagation.md` §HouseBldg appeal population
class split, canonical EN/CH PE bodies for `0x42DD40` and `0x518D90`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for the state exclusions, HouseBldg callback
field offsets, signed-width handling, and class threshold; **unknown** for
generic/specialized archive projection, vacant/repair state lifecycle, and
Native object equivalence.  The Qin automatic-migration producer therefore
remains fail-closed.

## 2026-09-03 Map-loader rehydration is an exact model whitelist (confirmed)

The post-load pass that can turn serialized map objects into live runtime
objects is narrower than a generic archive replay.  `FUN_0052F030 @ 0x52F030`
walks the already-created object vector, filters each object's model word at
`+0x14` through `FUN_0052F1D0 @ 0x52F1D0`, and only then calls
`Creating_pctd_type_pctd(model, x, y, ...)`.  The predicate's exact cases are
`0x53, 0x59...0x5B, 0x68...0x6A, 0x7B, 0x81...0x83, 0xD2, 0xE7, 0xE8`, and
the inclusive range `0xFD...0x10C`; all other model IDs take the false branch.
The EN/CH predicate rows are identical.

`OriginalMapLoaderRehydrationCatalog` now records these addresses and the
30-element whitelist.  The Qin generic `Building` archive scanner already
exposes the serialized common `+0x14` word as `baseTypeWord`; the canonical
`Xiangjun`, `Haunxian`, `Xianyang`, and `Badaling` records all carry model `0`,
so regression coverage proves that this rehydration pass selects none of their
3,956/3,962/3,998/3,906 generic records.  Their zero coordinates, zero map
cell, zero load-eligibility byte, and provider slot `-1` therefore cannot be
used as evidence for initial houses, markets, or residential-service
providers.  The specialized wall/gate and invasion records remain separate
archive families and are not admitted by this generic predicate.

This closes a concrete negative startup edge: Native must not synthesize Qin
houses or service providers merely because a generic map archive is present.
It does not recover the unresolved class-specific post-load callback,
provider-registry insertion, route construction, or house/market settlement;
the automatic Qin migration producer and those service bridges remain
fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0052F030.c`,
`FUN_0052F1D0.c`, `local/source/split-merged/code/0x040000/
Creating_pctd_type_pctd.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the caller order, model-word field,
whitelist, EN/CH parity, and four Qin archive counts; **unknown** for any
separate class/table-driven reconstruction path and all downstream provider
settlement.

## 2026-09-03 Herbalist/Acupuncture house coverage writes are explicit

The provider-side callbacks for the two non-water residential services are now
closed at the field-write boundary.  Herbalist model `207` (`0xCF`) uses
vtable `0x7B6114` and `FUN_0051BD00 @ 0x51BD00`; Acupuncture model `208`
(`0xD0`) uses vtable `0x7B6374` and `FUN_0051BD90 @ 0x51BD90`.  In both
canonical EN/CH builds the callback first requires the global gate
`FUN_00426D10(0)`, the target `+0xB8` eligibility result, and signed
`cHouseInfo +0x20 > 0`.  Success resolves the target through `+0x1E4` and
writes `0x60` to `cHouseInfo +0x2D` (Herbalist) or `+0x2A` (Acupuncture);
failure returns zero without a write.  The indexed corpus has no direct `E8`
caller for either body because these entries are reached by provider vtable
dispatch.

Native now exposes this as the pure
`OriginalResidentialServiceCatalog.residentialProviderHouseCoverageWrite`
helper and tests every gate, offset, value, and unknown-model rejection.  This
does not recover provider registry ownership, archive specialization/slot
projection, routing, or settlement; the Qin service and automatic-migration
bridges remain fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051BD00.c`,
`FUN_0051BD90.c`, provider vtable words at `0x7B6114`/`0x7B6374`,
`local/source/compare-report.tsv` rows `0x51BD00`/`0x51BD90`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for model/vtable mapping, gate order,
field/value writes, return behavior, and EN/CH parity; **unknown** for
registry provenance, archive projection, routing, and downstream settlement.

## 2026-09-03 Religion coverage target admission and field mapping are explicit

The religion provider callback `FUN_005AB580 @ 0x5AB580` now has a pure Native
contract.  Its target model gate admits HouseBldg IDs `2...17` through
`FUN_005188B0`, requires target byte `+0x09 != 0`, and allows signed population
`+0x20 < 1` only for elite IDs `11...17` (`FUN_005188D0`).  A non-zero provider
restriction byte `+0x174` imposes the same elite-only condition.  Success
resolves `cHouseInfo` through `+0x1E4` and writes `0x28` to field
`0x0D + religionIndex`; failure returns zero without a write.

`FUN_005AB080` maps provider models `214→0`, `215/216→1`, `217/218→2`, and
`219→3`, so the destination offsets are `0x0D`, `0x0E`, `0x0F`, and `0x10`.
EN/CH rows for the callback and its classifier/index helpers are identical.
Native exposes `OriginalResidentialServiceCatalog.religiousHouseCoverageWrite`
with regression coverage for populated and elite-vacant targets, the provider
restriction, model/index mapping, and every gate.  This closes only the raw
provider-to-house field write; provider registry, archive projection, route,
and settlement remain unknown, so Qin religious service stays fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005AB580.c`,
`FUN_005188B0.c`, `FUN_005188D0.c`, `FUN_00517270.c`, `FUN_005AB080.c`,
`local/source/compare-report.tsv` rows `0x5AB580`, `0x5188B0`, `0x5188D0`,
`0x517270`, `0x5AB080`, `Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for gate order, model/index mapping,
offsets, value, return behavior, and EN/CH parity; **unknown** for provider
registry provenance, archive projection, routing, and downstream settlement.

## 2026-09-03 House service countdown expiry is explicit, but does not project Qin providers

The daily phase-`6` dispatch in `FUN_004AC2B0 @ 0x4AC2B0` calls
`FUN_005185C0 @ 0x5185C0` after the common service setup.  In both
hash-identified executable variants, the EN/CH-identical body walks the live
object vector and requires the global gate `FUN_00426D10(0)`, object virtual
`+0xB8` eligibility, a non-zero resolved `cHouseInfo+0x3C`, and positive object
word `+0x98` before changing state.  With signed resident word `object+0x20 ==
0`, it clears both `cHouseInfo+0x3C` and `object+0x98`.  With any non-zero
resident word it decrements `+0x98`, increments global `DAT_0131289C`, and
clears `cHouseInfo+0x3C` only on the decrement that reaches zero.

`OriginalHouseInfoServiceCountdown.advance` now records this exact raw
transition and preserves the distinction between vacancy-clear and ordinary
countdown expiry.  The helper is research-only: the source of object `+0x98`,
the live Qin object/registry projection, and the provider-to-house settlement
edge remain unknown, so no Qin service or migration behavior is enabled from
this finding.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AC2B0.c`,
`local/source/split-merged/code/0x050000/FUN_005185C0.c`,
`local/source/compare-report.tsv` row `0x5185C0`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for phase/caller order, gate sequence,
field offsets, zero-resident handling, counter increment, expiry clear, and
EN/CH parity; **unknown** for countdown production, object specialization,
provider registration, and downstream `cHouseInfo+0x3C` semantics.

## 2026-09-03 Removal-lock writer width and refresh argument are explicit

The complementary writer `FUN_004681A0 @ 0x4681A0` consumes a count already
converted by the source `__ftol` instruction.  It passes the full integer to
`FUN_00591920`, subtracts only its signed 16-bit form from house `+0x20`,
writes the caller byte to `cHouseInfo+0x3C`, arms house `+0x98` to `0x20`,
clears `+0xA4`, and refreshes through house registry word `+0xB4` via
`FUN_00418770`.  The only indexed caller, `FUN_00468420 @ 0x468420`, passes
byte `2` and attempts three type-`0x12` Disease Carrier figures.  The
EN/CH comparison row for `0x4681A0` is `identical`.

`OriginalHouseInfoRemovalLock.apply` records this exact field/write order and
the distinction between full-width population-ledger input and signed-short
resident arithmetic.  This narrows Qin's removal/settling-lock evidence, but
does not supply the unknown floating-point count producer, figure registry or
route, or a Native disease-object projection; no new Qin incident behavior
is enabled.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004681A0.c`,
`FUN_00468420.c`, `local/source/compare-report.tsv` row `0x4681A0`,
`GameData/Model/EmperorFigureModels.txt`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for call order, offsets, widths, constants,
caller byte `2`, and EN/CH parity; **unknown** for count production, event
frequency, figure allocation/route, and downstream Qin settlement.

## 2026-09-03 City natural-health aggregate arithmetic is now explicit

The health branch has a city-level arithmetic boundary that is separate from
the unresolved Qin service/provider bridge.  `FUN_00518490 @ 0x518490` returns
`100` when its enumerated signed population total is non-positive; otherwise
it computes `(weightedHealthSum * 100) / totalPopulation`, adds the exact
low-population correction `(1000 - totalPopulation) / 10` only below 1,000
residents, adds `10` when the explicit `FUN_005A8420(6)` flag is set, and caps
only the upper result at `100`.  `FUN_00590DB0 @ 0x590DB0` stores this value in
`DAT_0130F978`.  The EN/CH rows for the aggregate and store are identical.

`OriginalNaturalHealthAggregate.aggregate` now records these inputs and every
raw output component as a pure research helper.  It is intentionally not
consumed by `CitySimulation`: the bonus-flag producer, cHouseInfo projection,
disease/incidents, and Qin provider settlement remain unknown, so this does
not unblock automatic migration or enable guessed health effects.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00518490.c`,
`FUN_00590DB0.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/PublicHealthSafetySimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for source arithmetic, correction/bonus
constants, upper clamp, no-population return, and EN/CH parity; **unknown** for
bonus provenance, object projection, and downstream Qin health/settlement.

## 2026-09-03 Nearest-house arbitration is explicit, but the Qin producer edge remains unknown

`FUN_004ADD60 @ 0x4ADD60` walks the active object vector from index `1` and
selects the nearest eligible house. Both canonical executable variants have
the same body (`local/source/compare-report.tsv`), with EN SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
SHA-256 `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
The source requires `FUN_00426D10(0)`, a true house vtable `+0xB8` callback,
signed-short `+0x24 > 0`, signed-short `+0x22 > 0`, and signed-short `+0x32 ==
0`. It ranks with `FUN_00408BC0 @ 0x408BC0` as
`max(abs(dx), abs(dy))` using candidate shorts at `+0x28` and `+0x0C`, starts
from distance `1000`, and updates only on strict `<`; therefore equal-distance
ties keep the first vector row and distance 1000 is not accepted.

Direct machine-level calls to this selector occur at `0x4CAAB3` and
`0x4CAF47` in both PEs. The gap caller consumes a nonzero house ID through
the house link/access writer and figure-state updates, but the corpus does not
recover the enclosing function. `DeterministicMigration.selectOriginalImmigrantHouse`
now mirrors this arbitration as a pure helper with explicit raw inputs and no
runtime wiring.

This closes the selector's gate/order arithmetic only. The object-vector and
house-registry projection (`FUN_00413B40`/`FUN_00554C00`), the semantic mapping
of `+0x28/+0x0C`, the enclosing figure state, route completion, and Qin
automatic-migration producer input remain **unknown**. Automatic migration
therefore stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004add60.c`,
`FUN_00408bc0.c`, `local/source/compare-report.tsv` rows `0x4add60` and
`0x408bc0`, `docs/exe-research/migration-popularity-producer.md`,
`Sources/EmperorCore/MigrationSimulation.swift`, and
`Tests/EmperorCoreTests/MigrationSimulationTests.swift`.

**Evidence class:** **confirmed** for gate order, field offsets, signed widths,
distance metric, sentinel, strict tie behavior, vector start, EN/CH parity,
and direct callsites; **unknown** for registry provenance, raw-field semantics,
caller state identity, and Native projection.

## 2026-09-03 Daily migration pending-word transition is source-accurate

The Qin daily migration seam now uses a pure mirror of the request bookkeeping
inside `FUN_004AD4A0 @ 0x4AD4A0`. Both canonical executable variants are marked
`identical`. Arrival (`DAT_01311F88`) and departure (`DAT_01311F84`) maintain
independent carried words: requests `1…5` accumulate and dispatch only when
the sum exceeds `5`, clearing the carried word on that threshold path;
requests `>=6` dispatch immediately while preserving the prior carried word;
zero/non-positive requests do nothing. The source clears both request words
after the two streams are processed.

`DeterministicMigration.originalDailyMigrationBatch` records this exact
transition and `DeterministicCityState.dailyMigrationAssignment` consumes it.
Arrival still stops at the recovered assignment boundary; departure dispatch
is not invoked because the type-`0xC` exit route and figure settlement remain
unknown. This corrects the previous Native bookkeeping that accumulated every
departure request regardless of the source threshold, without enabling Qin
automatic migration.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ad4a0.c`,
`FUN_004ada10.c`, `FUN_004adc90.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/MigrationSimulation.swift`,
`Sources/EmperorCore/CitySimulation.swift`, and focused migration tests.

**Evidence class:** **confirmed** for the two-stream threshold, strict `>5`
comparison, clear/preserve order, request resets, and EN/CH parity; **unknown**
for departure figure/route/ledger effects and the remaining Qin producer,
registry, food, monument, war, water, market, and desirability mappings.

## 2026-09-03 Theatre Pavilion candidate and venue raw-pair seams bounded

The entertainment blocker now has two additional source-accurate, side-effect-
free seams. `FUN_0048A350 @ 0x48A350` scans model-75 Theatre Pavilion objects,
requires each object's `+0x19C` predicate, accepts only a successful
`FUN_005B00D0` route probe to the candidate `+0x2A/+0x2C` point, and chooses
the first strict minimum of Chebyshev distance from the figure point to the
candidate `+0x0A/+0x0C` origin. Its sole direct caller is `0x4D1BD0` in both
canonical PE images. The neighboring Entertainment Area update entry calls
`FUN_0048BE00 @ 0x48BE00` at four fixed figure cases (`32/34/33`) and for ten
`0x26` slots; all raw output pairs are recorded in
`residential-service-roamer-lifecycle.md` §10.6i and represented by
`OriginalResidentialServiceCatalog` helpers with focused tests.

These closures do not resolve the route-probe implementation, coordinate-pair
meaning, provider registry, venue occupancy, or house settlement. Qin venue
figures `32…34` therefore remain fail-closed in live simulation; no runtime
behavior was enabled from the new primitives.

## 2026-09-03 cMarket endpoint callback return is not a `FUN_004BA370` gate

The endpoint helper was rechecked at the machine-code level because the
neighboring house-access scan has a similar-looking callback contract. In both
canonical PE inputs, `FUN_004BA370 @ 0x4BA370` calls the candidate object's
vtable `+0xD0` with the linear cell index and an adjustment out-parameter, then
immediately reloads the possibly adjusted index and tests only
`(terrainWord & 0x44) == 0x40`. There is no conditional branch on the callback
return register. A callback return of `-1` is therefore not an independent
rejection in this cMarket scan; only the callback-written index can affect the
subsequent terrain/component arbitration. The neighboring `FUN_004BAF40`
house-access routine does test its callback return and remains a distinct
contract.

`OriginalMarketPeddlerEndpointSelection` now removes the synthetic
`objectCallbackAllowed` admission gate and accepts the supplied adjusted point
whenever the post-adjustment terrain and component-rank conditions pass. The
focused regression includes an adjusted point outside the Native test map to
prove that this helper does not infer a return-value rejection. This correction
does not recover the object callback's map projection, cMarket provider
records, route/collision state, or settlement; Qin market and migration remain
fail-closed.

**Sources:** `Exe/ghidra/input/EmperorEN.exe` and
`Exe/extracted/Emperor[CH].exe` machine-code slices at `0x4BA370`,
`local/source/split-merged/code/0x040000/FUN_004ba370.c`,
`FUN_004baf40.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/MarketSimulation.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the missing return-value branch, the
post-adjustment terrain test, and EN/CH parity; **unknown** for callback
side-effects, map/object projection, and all downstream provider/settlement
semantics.

The `0x4BA370…0x4BA575` text slice is 518 bytes and hashes to
`a092d6a87470c2d6df71c9968039e10db70a35e0ce9d2542f7a4a3ed3ede308f` in both
the English build (`8a6d2df1…6753`) and the Chinese build
(`dbdeca1e…15a`).

## 2026-09-03 cMarket post-load callback resolves to a helper/cache path, not provider registration

The cMarket vtable is a separate post-load callback case from the eight
service/entertainment vtables above.  Direct little-endian PE reads in both
canonical images give cMarket vtable `0x7B6F3C` `+0x1C8 → 0x543770`.  The
11-byte body at `0x543770` is a thunk: it loads `cMarket + 0x158`, then jumps
through that helper object's virtual `+0x60` entry.  The EN and CH thunk bytes
are identical; the `0x543770…0x54377B` slice hashes to
`d9aca8134bc222cc370e87f399bef53cb31031ca1bf6b17c40edf13be50acc70`.

The helper vtable is selected by the cMarket constructor
`FUN_00543450 @ 0x543450`: Common Market (`model 59`) uses helper vtable
`0x7AB800`, whose `+0x60` target is the constant-false `FUN_00413A00`; Grand
Market (`model 60`) uses helper vtable `0x7AB878`, whose `+0x60` target is the
230-byte body at `0x543360`.  The EN/CH `0x543360…0x543446` body slice hashes to
`84f64ac5730f455ed4eb30aa3e4cf99e4d168252ca0de8387a388b7330d69dad` in both
images.  The Grand helper loops its layout records, samples map/terrain
state, and writes the derived values into the global `DAT_00FE9880` cache
before returning success.  Its body contains no provider `+0x2D` assignment,
market record insertion, or `cHouseInfo` settlement write.

This closes the cMarket `+0x1C8` dispatch target and the Common/Grand helper
split as **confirmed**.  It does not recover the serialized cMarket object
projection (the Qin archives contain no cMarket class declaration), the
provider-record source, or the market-to-house quality/coverage settlement;
therefore Qin market and automatic migration remain fail-closed.  Native
records the raw addresses in `OriginalMapArchiveRepairCatalog` only and does
not invoke this callback/cache path from map loading or simulation.

**Sources:** direct `.rdata` vtable reads and `.text` slices from
`Exe/ghidra/input/EmperorEN.exe` (hash
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`) and
`Exe/extracted/Emperor[CH].exe` (hash
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`),
`local/source/split-merged/code/0x050000/FUN_00543450.c`,
`local/source/split-merged/code/0x040000/FUN_00413A00.c`, and
`Sources/EmperorCore/HousingEvolution.swift`.

**Evidence class:** **confirmed** for the cMarket thunk, helper-vtable
selection, EN/CH byte identity, and Grand helper's map-cache write; **unknown**
for the cMarket archive/object projection, provider-record population, and
house settlement semantics.

## 2026-09-03 Grand Market cache auxiliary offsets are table-driven (city-stats-dependent tail remains unresolved)

The 230-byte Grand helper body at `0x543360` does not write its selected
image pointer directly.  For layout records whose `kind` is `1` or `4`, it
first branches on `record+0x0C >= 100`, then calls
`FUN_00542450 @ 0x542450` for the auxiliary-dependent offset.  The EN/CH
compare report marks `0x542450` **identical**.  Its `param_2` is zero at the
Grand-helper call site, so the relevant direction modes are the global
`DAT_0101D0D0` values `0…6` (modes `>=7` return zero without consulting the
auxiliary word).

For authored auxiliary values `100…123`, the deterministic tables are:

```
mode 0: 23,19,15,20,16,12,22,18,14,21,17,13,0,6,9,3,1,7,10,4,2,8,11,5
mode 1/3/5: all zero
mode 2: same sequence as mode 0
mode 4: 5,4,3,2,1,0,11,10,9,8,7,6,23,22,21,20,19,18,17,16,15,14,13,12
mode 6: 12,16,20,15,19,23,13,17,21,14,18,22,5,11,8,2,4,10,7,1,3,9,6,0
```

For modes `0`, `2`, `4`, and `6`, auxiliaries `124…135` jump to labels that
add `FUN_00413BC0()`'s result multiplied by 12.  Direct machine code at each
of these call sites first loads `ECX = DAT_0130F960`; the accessor body at
`0x413BC0` returns `*(cityStats + 0x263C)`.  The offset bases are, in aux
order `124…135`:

```
mode 0/2: 35,33,31,34,32,30,24,27,25,28,26,29
mode 4:   29,28,26,27,25,24,35,34,33,32,31,30
mode 6:   30,32,34,31,33,35,29,26,28,25,27,24
```

Native therefore exposes the full arithmetic through an explicit
`cityStatsOffsetValue` parameter; omitting that unresolved field returns
`nil`.  The helper is not wired to the runtime map cache, image archive,
provider registry, or house settlement.  The field's semantic name and
gameplay writer remain unknown even though the offset read itself is now
confirmed.

This closes the auxiliary→offset arithmetic used by the Grand post-load cache
writer as **confirmed**, including the mode-0/2/4/6 tables and the `>=7`
zero path.  It does not close the cache's image-pointer base, dynamic map
state, or any Qin market/provider behavior; those blockers remain
fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00542450.c`,
`FUN_00543360` direct EN/CH machine-code slices, the EN/CH
`local/source/compare-report.tsv` row for `0x542450`, and
`Sources/EmperorCore/MarketSimulation.swift` with focused assertions in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

The checked PE inputs are the canonical English build
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and
Chinese build `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`;
the `0x542450` function row and relevant helper bytes are identical.

**Evidence class:** **confirmed** for the call-site argument, mode guards,
deterministic tables, `cityStats + 0x263C` read, and `>=7` return; **unknown**
for the `+0x263C` semantic/writer, image-pointer semantics, cache consumers,
provider registration, and house settlement.
## 2026-09-03 Food-term caller census does not close Qin market settlement

The canonical EN/CH PE `.text` direct-call census for
`FUN_00590F30 @ 0x590F30` found exactly two callsites in both binaries: `0x59126A` from the
monthly popularity producer `FUN_00591200`, and `0x5B8B4A` from the
string-bearing advisor renderer `Popularity_pctd @ 0x5B8740`.  The latter
formats the return with the authored `"food effect %d"` string and has no
state-writing edge.  The indexed EN/CH rows for all three functions are
`identical`.

This closes a false lead: the advisor display is not a second food producer,
and no additional direct callsite supplies a cHouseInfo or cMarket write.
Indirect/table calls and the complete live `cHouseInfo +0x36` writer set
remain **unknown**, so Native keeps Qin market-quality projection, peddler
route, and automatic migration fail-closed.

**Sources:** canonical EN/CH PE direct-call census; `local/source/split-merged/
code/0x050000/FUN_00590f30.c`, `FUN_00591200.c`, `Popularity_pctd.c`;
`local/source/compare-report.tsv` rows `0x590F30`, `0x591200`, `0x5B8740`; and
string-table entry `0x85E9F0`.

**Evidence class:** **confirmed** for caller identities, producer/UI context,
resource string, and EN/CH parity; **confirmed negative** for another direct
food-state caller/writer; **unknown** for indirect aliases and complete
market/house settlement.

## 2026-09-03 cStall pool category is fixed at raw slot `2`

The next cStall input boundary is now closed at the table level.  The
cStall model gate `FUN_005418D0 @ 0x5418D0` admits Empty Shop `62` and shop
models `64…70`.  Their `FUN_004271D0 @ 0x4271D0` callback reads the first
dword at `DAT_008235A8 + modelID * 0x18`; canonical EN and CH PE bytes show
that value is `2` for every one of those models.  `FUN_004AE220` uses that
value as the category-array index, and `FUN_004F19A0` forwards the resulting
category-selected pools to cStall `+0x18C` with selectors `1` then `2`.

This is a confirmed narrowing of the cStall `+0x44` producer: all accepted
shop children consume raw pool slot `2`.  The five-dword row values, their
resource meaning, provider registry projection, peddler route, and household
settlement remain **unknown**; Qin market behavior stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004271D0.c`,
`FUN_004AE220.c`, `FUN_004F1590.c`, `FUN_004F19A0.c`,
`local/source/split-merged/code/0x050000/FUN_005418D0.c`,
`local/source/compare-report.tsv`, and canonical EN/CH table bytes at
`DAT_008235A8` (identical table hash recorded in
`migration-popularity-producer.md`).

**Evidence class:** **confirmed** for model admission, category `2`, pool
selection/order, and EN/CH parity; **unknown** for pool semantics, row
production, Native projection, routing, and settlement.

## 2026-09-03 Qin generic records do not carry a population-callback byte

The generic `Building` archive scanner now exposes the packed stream byte that
corresponds to `HouseBldg +0x09`, the byte read by the source `+0xB8`
population callback.  All generic records in Haunxian (3,962), Xianyang
(3,998), Xiangjun (3,956), and Badaling (3,906) contain `0` at both this
offset and the common object `+0x04` state byte.  The source serializer order
and offsets come from `FUN_00427430 @ 0x427430`; the map-loader whitelist is
`FUN_0052F030 → FUN_0052F1D0`.

This closes a useful negative: a Qin generic record cannot be treated as a
ready population-eligible `HouseBldg` merely by reading its packed payload.
Indirect specialization/alias writes and their timing remain unknown, so the
automatic migration path stays fail-closed.

**Evidence class:** **confirmed negative** for the four authored generic runs;
**unknown** for post-load specialization and Native object equivalence.

## 2026-09-03 HouseBldg explicit factory does not close Qin map rehydration

`FUN_0042D360 → FUN_005188B0` accepts exactly model IDs `2...17` and creates
the `HouseBldg` vtable `0x7ABA38` through `FUN_0042D480`.  However,
`FUN_0052F030 → FUN_0052F1D0`, the recovered map post-load whitelist, contains
none of those model IDs, while the four Qin generic archive runs carry base
type word `0`.  The new `OriginalHouseBldgFactoryCatalog` records this
factory-only fact and keeps it separate from map rehydration.

This confirms why the factory range cannot be used as a shortcut for Qin
population input: the archive-to-HouseBldg specialization trigger and timing
remain unknown, so automatic migration stays fail-closed.

**Evidence class:** **confirmed** for the factory range and whitelist
exclusion; **unknown** for archive specialization, registry assignment, and
callback timing.

## 2026-09-03 Entertainment venue common-tail frame arithmetic is explicit

The direct EN/CH PE slice `0x48A9A0…0x48AD1F` also closes the frame-selection
tail that runs after every recovered venue-FSM state. The source first uses
figure heading byte `+0x19` as a signed value, but switches to saved heading
byte `+0x1A` only when that signed value is at least `8` (`jl` is signed). It
subtracts the shared direction word `DAT_0101D0D0` and adds `8` once when the
result is negative. The model byte
selects these resource-key pairs before the shared `FUN_00408170` resolver:

| figure model | first key | state-4 alternate key |
| ---: | ---: | ---: |
| 32 (acrobat) and other models | `19604` | `19608` |
| 33 (actor) | `19627` | `19631` |
| 34 (musician) | `19559` | `19562` |

For state `4`, the resolver receives the alternate key and the saved word
`+0x3E` as frame offset, except that a value `>= 8` is capped to `7`. Every
other venue state resolves the first key and adds `normalizedHeading +
tick×8` to the returned image offset. The EN and CH bytes are identical;
`FUN_00408170 @ 0x408170` and `FUN_004081D0 @ 0x4081D0` provide the shared
resource-page lookup but are not invoked by the Native helper.

`OriginalResidentialServiceCatalog.entertainmentVenueFrameSelection` records
these inputs and arithmetic as a side-effect-free value. It does not resolve
the live sprite archive, mutate a figure, or enable Qin venue figures. The
resource archive base, frame-image ownership, venue route/collision state,
provider registry, and house settlement remain **unknown**, so this closure
improves only the future presentation boundary and does not change the
fail-closed Qin simulation.

**Sources:** canonical EN/CH PE bytes at `0x48A9A0…0x48AD1F`,
`local/source/split-merged/code/0x040000/FUN_00408170.c`,
`FUN_004081D0.c`, and the direct venue-FSM recovery in
`docs/exe-research/residential-service-roamer-lifecycle.md` §7.2a;
`Sources/EmperorCore/HousingEvolution.swift` and focused regression coverage
in `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for heading fallback, direction
normalization, model-key pairs, state-4 cap, non-state-4 tick arithmetic, and
EN/CH byte identity; **unknown** for sprite archive resolution and every
runtime route/registry/settlement effect.

## 2026-09-03 Generic map insertion does not synthesize the `+0xB4` object slot

The remaining registry ambiguity can be separated at the write-site level.
The explicit create/replace helper `Creating_pctd_type_pctd @ 0x42D540` calls
`FUN_0042D360` for the model, then writes the selected object-vector slot into
`p[0x2D]` (object `+0xB4`) before invoking the object's coordinate setter at
vtable `+0x94`. This is the confirmed `+0x2D` assignment used by player
construction and the known replacement callers.

The generic map-load path is different: `FUN_0042D790` obtains a `Building`
through `FUN_0042D0E0 → FUN_0077FD90`, then calls
`FUN_0042B590 → FUN_005F01F0 → FUN_005C1670` to insert the pointer into the
object vector. None of these recovered insertion bodies writes object
`+0xB4`; the only field access is the common serializer's direct read of the
archive tail. The alternate object-reference helper
`FUN_0077FD11` likewise dispatches the object's serializer and does not assign
a vector slot into the object record.

This is a confirmed negative for an insertion-time “repair” of the generic
record's raw `+0xB4`. Together with the four-map scan (`3,956/3,962/3,998/3,906`
generic records, all raw `+0xB4 == -1`) it shows that the missing Qin provider
identity cannot be recovered by assuming the generic insertion index equals
the specialized provider slot. The remaining unknown is the unobserved
generic-to-specialized projection/table alias itself; Native must not infer it
from object-vector order.

**Sources:** `local/source/split-merged/code/0x040000/Creating_pctd_type_pctd.c`,
`FUN_0042D360.c`, `FUN_0042D790.c`, `FUN_0042D0E0.c`, `FUN_0042B590.c`,
`local/source/split-merged/code/0x050000/FUN_005F01F0.c`,
`FUN_005C1670.c`, `local/source/split-merged/code/0x070000/FUN_0077FD90.c`,
`FUN_0077FD11.c`, and the four-map generic archive regression in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the specialized `+0x2D` write,
generic insertion call order, absence of an insertion-time `+0xB4` write in
the recovered bodies, and four-map `-1` records; **unknown** for indirect
table aliases, specialized projection timing, and provider/house settlement.
## 2026-09-03 Complete `FUN_0077FD90` class-token census finds no hidden Qin service stream

The indexed corpus was scanned for every direct `FUN_0077FD90` class-token
request, then each request was followed to its direct caller.  The complete
set is:

| class token | accessor | direct consumer | role in the recovered load graph |
| --- | --- | --- | --- |
| `Building` (`0x817890`) | `FUN_0042D0E0` | `FUN_0042D790`; nested `FUN_0056F700` | map object archive; also an embedded worker-item field |
| `Figure` (`0x84DEA8`) | `FUN_004E1190` | `FUN_004E1E40`, `FUN_0056F700` | figure-vector enumeration / embedded worker-item field |
| `WorkerCommodityItem` (`0x859E00`) | `FUN_0056F300` | `FUN_0056AB00 → FUN_00564E30` | fixed worker/commodity records |
| `cMonInfo` (`0x859DC0`) | `FUN_00561D40` | `FUN_0056F700` | embedded worker-item field |
| `SubBuilding` / `SubBuildingInfo` (`0x85A398` / `0x85A380`) | `FUN_00570290` / `FUN_00570100` | `FUN_0056F700` | embedded worker-item fields |
| `cGoalBase` (`0x8590D8`) | `FUN_005591A0` | `FUN_00560040` | goal/event records |
| `FigureFSA` (`0x84D2F8`) | `FUN_004D72F0` | `FUN_004C75C0` | figure state-machine records |
| `cPlayerInvadeData` (`0x82C520`) | `FUN_00491180` | `FUN_00491760` | invasion records |
| `FSAState`, `FSAAction`, `FSAContext`, `FSAActionContext`, `FSATransition`, `FSAMatch` | `FUN_004F1D60`…`FUN_004F2420` | FSA parser helpers | state-machine scratch records |

The relevant map path is therefore precise: `FUN_0052FDA0` calls the object
archive loader `FUN_0042D790`, which requests only the `Building` descriptor
through `FUN_0042D0E0`; the resulting object is inserted into the common object
vector.  The other class-token calls are either figure/state/goal data or the
`WorkerCommodityItem` serializer's embedded fields.  In particular,
`FUN_00564E30` repeatedly calls `FUN_0056AB00`, and that path inserts
`WorkerCommodityItem` records, not residential providers.

Every accessor and the nested serializers in this census have `identical`
EN/CH rows in `local/source/compare-report.tsv`.  No direct class-token request
for Well `72/73`, Herbalist `207`, Acupuncture `208`, or entertainment
providers `211…213` exists outside the explicit model factory already traced
through `FUN_0042D360 → FUN_0051C660`.  This is a confirmed negative for a
second, hidden specialized-object archive stream in the recovered map-load
graph.  It does not exclude an unindexed indirect/table alias, so the generic
record's post-load specialization and provider-registry projection remain
**unknown** and Native stays fail-closed.

**Sources:** complete `rg` census of `local/source/split-merged/code` for
`FUN_0077FD90`; `FUN_0042D0E0.c`, `FUN_0042D790.c`, `FUN_0052FDA0.c`,
`FUN_0056F700.c`, `FUN_0056AB00.c`, `FUN_0056F300.c`, `FUN_00564E30.c`,
`FUN_004E1E40.c`, `FUN_004E1190.c`, `FUN_00561D40.c`, `FUN_00570100.c`,
`FUN_00570290.c`, `FUN_005591A0.c`, `FUN_004D72F0.c`, `FUN_00491180.c`,
and `FUN_004F1D60.c`…`FUN_004F2420.c`; plus the corresponding
`local/source/compare-report.tsv` rows.

**Evidence class:** **confirmed** for the complete indexed direct-call census,
class-token roles, map-load call order, and EN/CH parity; **confirmed
negative** for a direct hidden service-object stream; **unknown** for
unindexed indirect dispatch, archive specialization, provider registration,
and household settlement.

## 2026-09-03 Provider runtime-class records are registration metadata, not a Qin archive projection

The canonical EN/CH PE `.data` slice at `0x00854330…0x008544B7` contains five
MFC-style runtime-class records.  Decoding the record fields (name pointer,
`0x150`/`0x84` object size, create-object callback, and base-class pointer)
gives the following direct mapping:

| record | class name | size | create-object callback | base-class pointer |
| ---: | --- | ---: | ---: | ---: |
| `0x854330` | `cAcupuncturistBldg` (`0x854394`) | `0x150` | `FUN_0051B8A0` | `0x854438` |
| `0x854348` | `cHerbalistBldg` (`0x854384`) | `0x150` | `FUN_0051B930` | `0x854438` |
| `0x854360` | `cWellBldg` (`0x854378`) | `0x150` | `FUN_0051B9C0` | `0x854438` |
| `0x854438` | `cIndustrialBldg` (`0x8544A8`) | `0x150` | `FUN_0051C140` | `0x817890` |
| `0x854450` | `cNonHouseInfo` (`0x854498`) | `0x84` | `FUN_0051C220` | `0x7CD140` |

The three Qin service records therefore share the `cIndustrialBldg` base
descriptor.  Their constructor callbacks allocate `0x150` bytes and run the
indexed initializer chain `FUN_0051B8A0/930/9C0 → FUN_0051C0D0/0B0/090 →
FUN_0051BA50 → FUN_0051C9A0 → FUN_0051C2E0`; the final vtable writes are
`0x7B6374` (Acupuncturist), `0x7B6114` (Herbalist), and `0x7B5EB4` (Well).
The adjacent short accessors at `0x51B900`, `0x51B990`, `0x51BA20`,
`0x51C1A0`, and `0x51C280` return the corresponding record pointers.  The
registration wrappers push those records through `FUN_0040AA80 →
FUN_0077BB9A`; the indexed `FUN_0040AA80` body only enters the generic runtime
registry chain and performs no map/object-vector insertion.

The record slice and the constructor/accessor bytes are identical between the
canonical English build (`8a6d2df1…9d6753`) and Chinese build
(`dbdeca1e…7ac15a`); the indexed constructor rows and `FUN_0040AA80` row are
`identical` in `local/source/compare-report.tsv`.  This is positive evidence
that the original executable registers concrete provider classes, and that
they inherit the industrial-building family.  It is not evidence that the
generic map loader rehydrates those classes: the recovered
`FUN_0052F030 → FUN_0052F1D0 → FUN_0042D790 → FUN_0042D0E0` path still requests
only the `Building` class token and inserts the returned generic object.  No
indexed caller connects the runtime-class records to the missing
generic-to-specialized archive projection or provider registry slot.

`OriginalResidentialServiceCatalog.providerRuntimeClassDescriptors` now keeps
this mapping as a research-only, test-locked catalog.  It is intentionally not
consulted by map loading, object-vector insertion, or Qin simulation; a future
projection implementation must recover its trigger and registry slot
independently.

**Sources:** canonical EN/CH PE bytes at `0x0051B8A0…0x0051C2C0` and
`0x00854330…0x008544B7`; `local/source/split-merged/code/0x050000/`
`FUN_0051B8A0.c`, `FUN_0051B930.c`, `FUN_0051B9C0.c`, `FUN_0051C090.c`,
`FUN_0051C0B0.c`, `FUN_0051C0D0.c`, `FUN_0051BA50.c`, `FUN_0051C9A0.c`,
`FUN_0051C2E0.c`; `local/source/split-merged/code/0x040000/FUN_0040AA80.c`,
`local/source/split-merged/code/0x070000/FUN_0077BB9A.c`; and the complete
`FUN_0077FD90` token census above.

**Evidence class:** **confirmed** for record names, sizes, constructor and
base-descriptor pointers, constructor/vtable chain, registration call chain,
and EN/CH byte identity; **confirmed negative** for a map-loader insertion
edge in the recovered registration body; **unknown** for archive
specialization timing, indirect/table aliases, provider-registry projection,
and household settlement.

## 2026-09-03 Remaining indexed dynamic-creation callers are placement or lazy-object paths

The indexed caller graph adds one more negative boundary around the missing
Qin provider projection.  `FUN_004C1320 @ 0x4C1320` and
`FUN_00414F70 @ 0x414F70` each have only one direct indexed caller:
`FUN_004B1250 @ 0x4B1250`.  Both bodies scan currently available map cells,
apply the terrain/occupancy predicates, and call
`Creating_pctd_type_pctd @ 0x42D540` with the caller-supplied model ID and
coordinates.  The first path then invokes the created object's virtual
`+0x260`; the second computes and stores the placement value at object `+0xA0`
before its virtual `+0x100` callback.  Neither body reads an archive record,
requests the `Building` class token, or inserts a loaded object.

`FUN_004B1250` is reached from the placement/update path
`FUN_00538160 → FUN_004052A0`; the latter consumes the pending placement
globals (`DAT_0088EBD4/CC/D0/C8/DC`) and dispatches the selected model.  For
provider IDs `0x48/0x49/0xCF/0xD0` the explicit model factory's gate is
`FUN_0051BE30 → FUN_0051BEF0`, which is the already-catalogued Well,
Herbalist, and Acupuncture construction path.  This expands the positive
factory evidence without creating an archive-to-provider bridge.

The remaining indexed creator-shaped helper,
`FUN_00420EF0 @ 0x420EF0`, has only the direct caller
`FUN_00421ED0 @ 0x421ED0`.  It lazily creates the object whose model ID is
stored at the caller object's `+0x08`, then caches the returned handle at
`+0x04`; the body has no map-cell, archive, object-vector, provider-slot, or
house-service edge.  The direct caller census is therefore complete for these
three dynamic-looking helpers.  EN/CH rows for `0x414F70`, `0x4157D0`,
`0x415D30`, `0x420EF0`, `0x421ED0`, `0x4B1250`, and `0x4C1320` are
`identical`.

This is a **confirmed negative** for an additional indexed dynamic creator
route that could repair Qin map records.  It does not rule out an unindexed
indirect/table alias; serialized provider identity, provider-list insertion,
and household settlement remain **unknown**, so Native remains fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/`
`FUN_00414F70.c`, `FUN_004157D0.c`, `FUN_00415D30.c`, `FUN_00420EF0.c`,
`FUN_00421ED0.c`, `FUN_0042D360.c`, `FUN_004052A0.c`, `FUN_004B1250.c`,
`FUN_004C1320.c`; `local/source/split-merged/code/0x050000/`
`FUN_0051BE30.c`, `FUN_0051BEF0.c`, `FUN_00538160.c`; the complete indexed
caller search for these addresses; and their `identical` rows in
`local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for the indexed direct-caller sets, cell
scan/placement side effects, lazy-object field writes, explicit provider
factory gate, and EN/CH parity; **confirmed negative** for another indexed
archive-load/provider-registration route; **unknown** for indirect aliases,
serialized provider identity, registry ordering, and household settlement.

## 2026-09-03 cMarket access-refresh callback is a direct `+0x18` byte setter

The previously unresolved callback in `FUN_00543DC0 @ 0x543DC0` can be closed
at the raw PE/vtable boundary.  Both canonical images map cMarket vtable
`0x7B6F3C` slot `+0x1AC` to `FUN_00427410 @ 0x427410`.  The identical EN/CH
instruction bytes are:

```text
mov eax, dword ptr [esp+4]
mov byte ptr [ecx+0x18], al
and eax, 0xff
ret 4
```

Thus `FUN_00543DC0` does not call an opaque provider predicate at this slot:
after selecting its linear cell through `+0x194`, it passes
`DAT_00EC5A10[selected]` to a setter that stores the low byte in the cMarket
backing object at `+0x18`, then stores the flood/cache word from
`DAT_01391FE0[selected]` at the market object's `+0x24`.  The field is live in
the surrounding market code: `FUN_00540F80` chooses the `400` versus `800`
resource increment from it, `FUN_00541220` branches on `0`/`1` while selecting
provider records, and `FUN_00544B30` applies the corresponding `-800`/`-400`
refund when rebuilding a market child.  These consumers are direct evidence
of a market-state byte, but do not establish its higher-level semantic name.

`OriginalMarketAccessRefresh.callbackAddress` and
`callbackDestinationOffset` now preserve the exact target and destination as
research metadata; the value helper still keeps object mutation outside its
pure projection.  A second raw gate is now recorded as
`OriginalMarketProviderSelectionComponentGate`: the tail of
`FUN_00541220` continues provider selection only when the stored component
label is `0` or `1`; labels `2…255` return without selecting a provider.
This is a confirmed byte-value gate, not an interpretation of what either
label means.  The producer of `DAT_00EC5A10`, cMarket `+0x194` selection,
route-buffer construction, and provider-to-house settlement remain unknown,
so this closure does not enable Qin campaign market behavior.

**Sources:** canonical EN/CH PE vtable words at `0x7B6F3C + 0x1AC`, raw
`.text` bytes at `0x427410…0x42741C`, and
`local/source/split-merged/code/0x050000/`
`FUN_00543DC0.c`, `FUN_00540F80.c`, `FUN_00541220.c`, `FUN_00544B30.c`;
`local/source/compare-report.tsv` rows `0x543DC0` and `0x543E70`; plus
`Sources/EmperorCore/MarketSimulation.swift` and its focused regression.

**Evidence class:** **confirmed** for the vtable target, byte-level setter,
destination offset, downstream `0`/`1` consumers, and EN/CH parity; **unknown**
for the auxiliary-byte producer, helper/provider selection, route construction,
and household settlement.

## 2026-09-03 cStall buyer scheduler has a bounded model-24 spawn seam

The cStall buyer path is now separated from the cMarket access-refresh result.
`FUN_00541B80 @ 0x541B80` is the cStall think entry: after the allocator guard
`FUN_004AFDB0(0xAC)` and the cStall `+0xC8(-1)` predicate pass, it enters
`FUN_00540B40 @ 0x540B40`.  The scheduler increments its caller-supplied tick
word, derives the strict spawn threshold from the cStall `+0x1B4` result
(`1…24 → 10`, `25…49 → 5`, `50…74 → 4`, `75…99 → 3`, `≥100 → 2`; zero does
not enter the spawn branch), increments the cStall `+0x36` counter, and requires
the incremented counter to be strictly greater than that threshold.  It then
requires the market-helper readiness byte returned through `FUN_005448F0`
(`!= 1`) and the cStall's own `+0x25C` gate before calling
`FUN_00541220`; the separate cMarket `+0x268` stock predicate belongs to the
provider-selection/refill paths and is not a direct call in this scheduler.

When `FUN_00541220` returns no provider, the scheduler writes one of the raw
status bytes `1`, `2`, `3`, or `4` to cStall `+0x1E`, selected by the helper
availability calls and its out-byte.  The corpus does not give stable semantic
names to those four values; they must remain raw status codes.  When a provider
is returned, the scheduler allocates figure model `0x18` (Marketplace buyer)
through `FUN_004EA050`, writes figure state `6`, stores the destination handle
and market ID, copies seven dwords of the helper's cargo plan, and accepts the
destination through the figure `+0xEC` callback.  A failed destination check
changes the figure to state `7` and preserves the source destination fallback;
the existing child handle at cStall `+0x0C` is separately validated and cleared
when its status/model pair no longer matches.

`FUN_00541220`'s provider scan is the same EN/CH-identical body recorded above:
its tail continues only for cMarket backing byte `+0x18` labels `0` or `1`, and
its candidate arrays carry raw object handles, model words, and distance scores.
Neither the buyer scheduler nor this selector writes the missing provider
registry slot, populates the six cMarket records, constructs the route buffer,
or settles a household.  `OriginalMarketProviderSelectionComponentGate` thus
remains a raw label predicate only; no buyer or Qin campaign behavior is wired
from this seam.

**Sources:** `local/source/split-merged/code/0x050000/`
`FUN_00541B80.c`, `FUN_00540B40.c`, `FUN_00541220.c`, `FUN_00544190.c`,
`FUN_00544000.c`, `FUN_005448F0.c`, and `FUN_00544480.c`; identical EN/CH rows
`0x541B80`, `0x540B40`, `0x541220`, `0x544190`, `0x544000`, `0x5448F0`, and
`0x544480` in `local/source/compare-report.tsv`; and the model-24 spawn/think
boundary in `docs/exe-research/migration-popularity-producer.md` §3.

**Evidence class:** **confirmed** for the caller order, threshold bands,
strict counter comparison, model/state/destination/cargo writes, raw status-byte
locations, and EN/CH parity; **unknown** for the four status meanings,
`+0x1B4`/`+0x44` producers, provider-record population, route/collision state,
and provider-to-house settlement.

## 2026-09-03 campaign buyer bridge remains fail-closed (implementation boundary)

The recovered cStall scheduler does not authorize the Native
`DeterministicMarketState.scheduleBuyers` path for a Qin campaign.  The source
buyer (`FUN_00540B40 @ 0x540B40`) receives its helper argument from the cStall
object at `+0x158 + 0x0C` after resolving the object referenced by `+0x154`
(`FUN_0047F1B0`); it does not consume Native warehouse state.  Its successful
branch then copies the helper's seven raw cargo dwords into a newly allocated
model-24 figure and routes through figure/object callbacks whose provider
registry and map-cache inputs are still unknown.  The Native buyer scheduler,
by contrast, targets `ResidentialUnit` needs and `DeterministicLogisticsState`
warehouses directly.  That is a compatibility fixture behavior, not a recovered
Qin projection.

`DeterministicCityState.advanceOneDay` therefore runs buyer scheduling and
selector-8 buyer movement only when `missionSettingsState == nil`.  Campaign
cities retain their market records for persistence and construction bookkeeping,
but no Native buyer is spawned or advanced until the provider-record → map
endpoint → route → household-settlement chain is recovered.  This also keeps the
already documented campaign month-end settlement guard effective; the unscoped
sandbox path remains available for isolated arithmetic/timing tests.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00540B40.c`,
`FUN_00541B80.c`, `FUN_00541220.c`, and `FUN_005448F0.c`; identical EN/CH rows
`0x540B40`, `0x541B80`, `0x541220`, and `0x5448F0` in
`local/source/compare-report.tsv`; `Sources/EmperorCore/MarketSimulation.swift`;
and the guarded call site in `Sources/EmperorCore/CitySimulation.swift`.

**Evidence class:** **confirmed** for the cStall argument provenance, raw
model-24 cargo handoff, and Native campaign guard; **unknown** for provider
registry population, endpoint/route reconstruction, collision state, and
household settlement.  No Qin market behavior is enabled by this boundary.

## 2026-09-03 Provider `+0x1FC` callback only refreshes an existing auxiliary object

The provider-load callback's final virtual dispatch is now bounded at the raw
vtable/interior-function level.  The Well, Herbalist, Acupuncture,
Entertainment Area, Music School, Acrobat School, and Drama School vtables
all contain
`0x0051CC10` at slot `+0x1FC` in both canonical PE images.  The exact 16-byte
EN/CH slice at that address is identical (`8B 89 4C 01 00 00 85 C9 74 05 E9
71 C1 EF FF C3`): it reads provider object `+0x14C`, returns immediately when
that pointer is null, and otherwise tail-jumps to `FUN_00418D90 @ 0x418D90`.

`FUN_00418D90` resets the auxiliary object's `+0x0C`, invokes its vtable
`+0x14` and `+0x08` methods, stores the latter result at auxiliary `+0x08`,
then calls its common `+0xE80` finalizer.  It does not touch provider `+0xB4`,
the object vector, a map archive record, or a `cHouseInfo` field.  Therefore
the provider callback's `+0x1FC` dispatch is an **existing-auxiliary-object
refresh gate**, not the missing Qin provider registration or map-load
specialization.  The new addresses are retained in
`OriginalResidentialServiceCatalog.providerLoadAuxiliaryDescriptor` as raw
lifecycle metadata; Native does not allocate or refresh this auxiliary object
for campaign maps.

This closes the callback's null/non-null control flow while leaving the
auxiliary vtable's semantic methods, the source of provider `+0x14C`/`+0xB4`,
any indirect specialization, and provider-to-house settlement **unknown**.
Qin water, entertainment, and market bridges remain fail-closed.

**Sources:** canonical EN/CH PE vtable words at the listed service vtables,
the raw `.text` slice at `0x51CC10…0x51CC1F`,
`local/source/split-merged/code/0x050000/FUN_0051CB80.c`,
`FUN_00526830.c`, `local/source/split-merged/code/0x040000/FUN_00418D90.c`,
and identical EN/CH function rows where indexed.

**Evidence class:** **confirmed** for the six service-vtable targets, exact
null gate, `FUN_00418D90` tail call, auxiliary field offsets, and EN/CH byte
identity; **unknown** for auxiliary method semantics, archive/provider input
provenance, indirect specialization, registry ownership, and settlement.

## 2026-09-03 campaign residential-provider construction gate

The player-facing campaign construction path now rejects residential-service
models whose original provider lifecycle is not represented in Native. This is
an integration fail-closed boundary, not a claim that the original build menu
omitted the items: `OriginalCampaignBuildingPermissionCatalog` still maps
Inspector `#124`, Constable `#127`, Music School `#211`, Acrobat School `#212`,
and Drama School `#213` to authored menu entries `29`, `30`, and `17…19`.
When a campaign menu permits one of these entries,
`DeterministicCityState.isBuildingAvailableInCampaign` nevertheless keeps it
disabled for the entertainment schools `#211…#213`, so their placement
previews and direct construction return no footprint or object and cannot debit
the treasury. Inspector/Constable construction remains menu-authorized while
their own unsupported roamer handlers stay fail-closed. Sandbox cities remain
available for isolated catalog/state fixtures.

The source boundary is complete for the decision to refuse these classes:
`FUN_0048A520 @ 0x48A520` admits only figure model bytes `0x20…0x22`
(`32…34`) and requires provider virtual predicates at `+0x264`, `+0x78`,
`+0x1B4`, and `+0x25C` before the venue provider chooser; the recovered
`0x48A9A0` body is a separate venue FSM. The generic residential lifecycle is
dispatched only for figures `#27/#28/#30/#31/#35`, while guard `#29` and
inspector `#39` use their own handlers. The post-load repair switch
`FUN_0052F1D0 @ 0x52F1D0`, called by `FUN_0052F030`, has no cases for service
models `72`, `207`, `208`, `211…219`; in particular it does not create or
specialize the missing entertainment provider records. Existing source
evidence also leaves provider registry assignment, route/collision state,
coverage callbacks, and household settlement unknown for these classes.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0048A520.c`,
`local/source/split-merged/code/0x050000/FUN_0052F1D0.c`,
`local/source/split-merged/code/0x050000/FUN_0052F030.c`, the EN/CH-identical
rows for `0x48A520`, `0x52F1D0`, and `0x52F030` in
`local/source/compare-report.tsv`,
`docs/exe-research/residential-service-roamer-lifecycle.md` §§7.2–7.3ak,
and `GameData/Model/EmperorFigureModels.txt` rows `29`, `32…34`, and `39`.

**Evidence class:** **confirmed** for the separate handler dispatch,
provider-admission predicates, post-load switch exclusion, authored menu IDs,
and the existing Native roam support set; **unknown** for the original
archive-side provider creation/registry and all unresolved provider-to-house
effects. The replacement condition is a recovered provider registry →
route/collision → coverage/settlement projection for each model. Until then,
campaign construction remains fail-closed and no player-visible fallback text
or synthetic service effect is added.

## 2026-09-03 Newly constructed Well starts with provider water predicate clear

The shared residential-provider constructor path provides one more bounded
initial-state fact. `FUN_0051BEF0` dispatches Well models `72/73` to
`FUN_0051C090`, which calls the shared base `FUN_0051BA50` and then
`FUN_0051C2E0`. The latter clears the provider record range containing the
signed word read as `+0x16` and explicitly clears command byte `+0x6F` before
the Well vtable is installed. Therefore a newly allocated Well starts with
the provider `+0x224` predicate false. The other `FUN_0051BC00` branch calls
`FUN_0048DF30` and tests the independent global object through
`FUN_0048E110`; its `+0x50/+0x54/+0x58` state is not initialized by the Well
constructor. If that external context is inactive, the callback selects
`cHouseInfo +0x32`; otherwise it selects `+0x34`.

This is only an initial constructor state. `FUN_00511080`/`FUN_0042AE30` can
later write provider `+0x6F`, and the callback's global context branch depends
on state that is not projected from Qin archives. Native records only the
provider zero initialization in
`OriginalWaterProviderState.NewlyConstructedProviderState`; callers must
supply the external context and it does not claim a permanent water
destination or enable the unresolved Qin provider bridge.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0051BEF0.c`,
`FUN_0051C090.c`, `FUN_0051BA50.c`, `FUN_0051C2E0.c`,
`local/source/split-merged/code/0x050000/FUN_0051BC00.c`,
`local/source/split-merged/code/0x050000/FUN_00511080.c`,
`local/source/split-merged/code/0x040000/FUN_0042AE30.c`,
`local/source/split-merged/code/0x040000/FUN_0048DF30.c`,
`local/source/split-merged/code/0x040000/FUN_0048E110.c`,
`local/source/compare-report.tsv`,
`Sources/EmperorCore/HousingEvolution.swift`, and the focused water test.

**Evidence class:** **confirmed** for the Well constructor dispatch, cleared
provider field offsets, and the conditional destination rule when the
external context is supplied; **unknown** for later command/context writers,
archive-side specialization, provider registry ownership, route, and
household settlement.

## 2026-09-03 EmperorMap now retains the exact generic Building archive rows

The Native map parser now stores the validated generic `Building` records it
already knew how to scan, instead of forcing later Qin work to reopen the map
file. For format-v5 maps, `EmperorMap` computes the same variable-archive
range used by `OriginalGenericBuildingArchiveCatalog`: the fixed transition
offset `EmperorMap.buildingArchiveTransitionOffset` through the decoded-length
boundary immediately before the trailing `DAT_00F2B290` byte grid. The parser
then retains only records with the serializer token/schema and zero base-type
word accepted by `OriginalGenericBuildingArchiveCatalog.records`.

The four authored Qin maps used by the existing regression (`Xiangjun`,
`Haunxian`, `Xianyang`, and `Badaling`) expose exactly `3,956`, `3,962`,
`3,998`, and `3,906` retained records respectively. A focused test compares
the map-owned rows byte-for-byte at the decoded-field level with the direct
scanner and reasserts the existing facts: schema lengths `181/183`, raw
provider slot `-1`, zero coordinates/placement value, and exclusion from the
`FUN_0052F030` rehydration whitelist.

This is data plumbing only. The rows are not inserted into `CitySimulation`,
are not converted into houses or service providers, and do not repair the
generic `+0xB4 == -1` field. The executable still has no recovered
generic-record → specialized-provider replacement caller or registry
projection, so Qin map-loaded providers and their route/coverage/settlement
effects remain **unknown** and fail-closed.

**Sources:** `Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`,
`local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_0042D0E0.c`, `FUN_0042B590.c`, `local/source/split-merged/code/0x050000/`
`FUN_005F01F0.c`, `FUN_005C1670.c`, and the focused regression in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the map-owned archive range, parser
reuse, four-map counts, and preservation of raw fields; **unknown** for all
runtime object registration, specialization, and provider-to-house effects.

## 2026-09-03 EmperorMap retains the Qin archive class inventory

`EmperorMap` now retains `OriginalMapArchiveClassCatalog`'s declarations for
the same variable-size archive range used by the generic `Building` scanner.
The retained values are the exact class name, schema word, and first raw type
word; they remain archive evidence and never construct or register a runtime
object.  The four authored Qin maps are byte-for-byte regression checked
through this map-owned property:

| map | retained declarations (`class`, first type word) |
| --- | --- |
| `Xiangjun.map` | `Building/0`, `cResWall/90`, `cResGate/105` |
| `Haunxian.map` | `Building/0`, `cMonumentBldg/83`, `cIndustrialBldg/173` |
| `Xianyang.map` | `Building/0`, `cIndustrialBldg/173` |
| `Badaling.map` | `Building/0`, `cMonumentBldg/257`, `cFillBldg/94` |

No declaration is `Well`, `Herbalist`, `Acupuncturist`, `cMarket`, or any
other residential-service provider class.  Together with the generic rows'
raw `baseTypeWord == 0` and provider slot `-1`, this closes the authored-map
side of the “initial provider/object” question: these map archives do not
carry a directly specialized Qin provider object.  The remaining blocker is
therefore strictly the executable's indirect post-load specialization or
runtime construction/registry path, plus the provider-to-house route and
settlement effects; Native still does not synthesize those from declarations.

**Sources:** `Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/MapArchiveClassCatalog.swift`,
`local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_0042D0E0.c`, `FUN_0042B590.c`, the class inventory and generic-record
scans in `Tests/EmperorCoreTests/EmperorCoreTests.swift`, and the canonical
Qin map archives under `GameData/Cities/`.

**Evidence class:** **confirmed** for the four class inventories, schema/type
words, and absence of service-provider declarations; **unknown** for any
indirect post-load specialization, registry assignment, route, coverage, and
household settlement.

## 2026-09-03 Qin blocker audit verification after archive-class retention

After the `EmperorMap.archiveClassDeclarations` regression was added, the
canonical local verification was rerun from the repository root with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
The current suite completes with **635 tests passed, 0 failures, and 5
expected skips**.  The skips remain the pre-existing fail-closed player
playthrough guards: Qin-1 and Qin-2 automatic migration, Qin-3's unresolved
music/water/market/desirability contracts, and the Xia migration continuation.
The focused archive-class test also passes and compares the map-owned
declarations byte-for-byte with the direct `local/source`-derived scanner.

This supersedes the earlier 580-test verification count recorded before the
archive-class regression.  It is verification evidence only: no provider,
market, water, desirability, or automatic-migration behavior was enabled by
the change, and the unresolved indirect registry/route/coverage/settlement
boundary remains unchanged.

**Sources:** `git show 766c95de`, `git show 74162c9d`,
`Tests/EmperorCoreTests/EmperorCoreTests.swift` test
`testQinEmperorMapRetainsArchiveClassDeclarationsWithoutSpecializingObjects`,
and the local `swift test` output from 2026-09-03.

**Evidence class:** **confirmed** for the current test count, zero failures,
expected skip set, and focused byte-for-byte regression; **unknown** for the
same unresolved Qin runtime projection and service-settlement contracts.

## 2026-09-03 EmperorMap retains the Qin archive preamble

The map parser now also retains the fixed object-stream preamble that precedes
the variable records.  For each authored Qin map, the bytes at
`EmperorMap.buildingArchiveTransitionOffset` decode as archive schema `1`,
object-slot count `4,000`, and an MFC `Building` declaration beginning six
bytes later.  `OriginalMapArchivePreambleCatalog` performs only this bounded
byte decode; malformed or legacy streams return no class identity rather than
guessing one.

This is evidence plumbing, not runtime object creation.  The preamble does
not supply a provider registry slot or a specialized service class, and the
existing generic-record/class-inventory guards remain unchanged.  The
map-loaded Qin provider bridge therefore remains fail-closed pending an
indirect specialization/registry and route/coverage/settlement recovery.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_0042DC20.c`, `local/source/split-merged/code/0x070000/FUN_0077FD90.c`,
the identical EN/CH comparison rows, decoded bytes from the four maps under
`GameData/Cities`, `Sources/EmperorCore/MapArchiveClassCatalog.swift`,
`Sources/EmperorCore/EmperorMap.swift`, and
`testQinEmperorMapRetainsArchivePreambleEvidence`.

**Evidence class:** **confirmed** for schema `1`, 4,000 slots, six-byte class
tag offset, `Building` identity, and the parser regression; **unknown** for
per-record provider identity, indirect specialization, registry ownership,
and downstream service settlement.

## 2026-09-04 cMarket state is factory/serializer-owned, not Qin archive state

The market object has a complete explicit model-factory path, but the Qin map
loader does not enter it. `FUN_0051C660 @ 0x51C660` dispatches model IDs through
`FUN_005D36E0 @ 0x5D36E0`; that branch admits `53`, `54`, `56`, `58`, `59`, and
`60`, and `FUN_005D3580 @ 0x5D3580` selects the corresponding mill/market
allocators. For market models `59` (Common Market Square) and `60` (Grand
Market Square), `FUN_00543450 @ 0x543450` installs the `cMarket` vtable,
sets the shop-range word `+0x184` to `3` or `5`, sets `+0x188 = 1`, allocates
the six 16-byte provider records, and initializes `+0x180 = 0`.

The same object's save/load boundary is separate: `FUN_00544F10 @ 0x544F10`
restores `+0x15C/+0x174…+0x188` after `FUN_005D4810/FUN_005D4890` walk the
provider-record array. All inspected rows are `identical` in EN/CH
(`compare-report.tsv`). In contrast, the Qin archive path
`FUN_0042D790 → FUN_0042D0E0 → FUN_0042B590` resolves the MFC `Building`
declaration and inserts the returned generic object; its body has no direct
`FUN_0042D360`, `FUN_0051C660`, `FUN_005D3580`, or cMarket provider-record
allocation edge. The four canonical Qin maps also contain no `cMarket`
declaration, as recorded above.

This closes a tempting but invalid shortcut: cMarket's confirmed defaults and
persisted six-slot state cannot be projected into Qin merely because market
models exist in the executable. The remaining indirect post-load
specialization/registry edge, peddler route, and provider-to-house quality or
coverage settlement are still **unknown**; Native must keep the Qin market
bridge fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/`
`FUN_0051c660.c`, `FUN_005d36e0.c`, `FUN_005d3580.c`, `FUN_00543450.c`,
`FUN_00544f10.c`, `FUN_005d4810.c`, `FUN_005d4890.c`,
`local/source/split-merged/code/0x040000/FUN_0042d790.c`,
`FUN_0042d0e0.c`, `FUN_0042b590.c`, `local/source/compare-report.tsv`,
and the Qin archive class inventory in this document.

**Evidence class:** **confirmed** for the explicit factory model set,
cMarket initialization/serialization order, EN/CH parity, and the map-loader
direct-call negative; **unknown** for any indirect post-load specialization,
registry projection, route, and household settlement.

## 2026-09-04 Common-market allocation wrapper is not a Qin map-load edge

The cMarket constructor family has one additional constructor-shaped helper
that must not be mistaken for map rehydration. `FUN_00540680 @ 0x540680`
allocates `0x18c` bytes through `FUN_0040AE80` and immediately calls
`FUN_00543450(0)`. The zero constructor argument selects the common-market
branch of `FUN_00543450` (shop-range word `3`), rather than naming a serialized
building model. The helper therefore belongs to the explicit construction
family alongside the model-factory path through `FUN_005D3580`.

The indexed split corpus and both complete generated EN/CH decompilations
contain no direct caller of `FUN_00540680`; its only emitted call edge is the
internal `FUN_00543450(0)` construction call. The EN/CH comparison row for
`0x540680` is `identical`. This is a confirmed direct-call negative, not proof
that a data-table or indirect function-pointer reference cannot exist. In
particular, it does not create a caller from
`FUN_0042D790 → FUN_0042D0E0 → FUN_0042B590`, whose body still has no direct
edge to this wrapper, the model factory, or cMarket record allocation.

Native records the wrapper address, allocation size, and constructor argument
in `OriginalMarketCatalog` as research metadata only. It does not use the
wrapper to instantiate Qin map objects or to populate provider records. The
remaining indirect post-load specialization/registry edge, peddler route,
and provider-to-house quality or coverage settlement therefore remain
**unknown** and Qin market behavior stays fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00540680.c`,
`FUN_00543450.c`, `FUN_005D3580.c`, `local/source/split-merged/functions-index.csv`,
the generated `local/source/decompiled-en.c` and `decompiled-ch.c` direct
symbol searches, `local/source/compare-report.tsv` rows `0x540680`,
`0x543450`, and `0x5D3580`, and
`Sources/EmperorCore/MarketSimulation.swift`.

**Evidence class:** **confirmed** for the wrapper allocation size, zero
constructor argument, common-market branch, EN/CH body identity, and absence
of an indexed direct caller; **unknown** for indirect/table references,
archive specialization, registry projection, route, and household
settlement.

## 2026-09-04 Entertainment Area lookup preserves the rotating object-vector scan

The music/entertainment branch has another bounded selector input. In
`FUN_0048A420 @ 0x48A420`, the source obtains the active object-vector count,
chooses a caller-supplied random start index, wraps at the count, and scans
exactly one full pass. A candidate is accepted only when the global
`FUN_00426D10(0)` gate is open, the object model word is `0x47` (authored
Entertainment Area `71`), its vtable `+0x78` predicate is non-zero, and its
vtable `+0x1BC` result is strictly positive. The first accepted row is
returned; vector order and the selected provider `+0x2D` value are preserved.

The indexed callers are `FUN_0048E930 @ 0x48E930` and
`FUN_0048F140 @ 0x48F140`. The first uses a missing result as an explicit
failure code; the second stores the selected provider registry value before
building the entertainment rotation state. EN/CH comparison rows for
`0x48A420`, `0x48E930`, and `0x48F140` are `identical`. This closes the
Entertainment Area candidate gate and rotating scan, but not the provider
registry projection that supplies the vector rows, the route/collision probe,
or the subsequent venue/house settlement.

Native now exposes this exact one-pass selection as the pure
`OriginalResidentialServiceCatalog.entertainmentAreaSelection` helper. It
takes the already-produced start index and raw `+0x78`/`+0x1BC` inputs; it
does not create providers, invent an RNG stream, or enable Qin entertainment
figures. The campaign music bridge therefore remains fail-closed pending
registry, route, and coverage/settlement evidence.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0048A420.c`,
`FUN_0048E930.c`, `FUN_0048F140.c`, `FUN_00426D10.c`,
`local/source/compare-report.tsv` rows `0x48A420`, `0x48E930`, and
`0x48F140`, `GameData/Model/EmperorBuildingModels.txt` row `71`,
`Sources/EmperorCore/HousingEvolution.swift`, and the focused
`EmperorCoreTests` regression.

**Evidence class:** **confirmed** for the model filter, global/provider gates,
strict-positive staffing check, random-start wrap, one-pass vector order,
caller identities, and EN/CH parity; **unknown** for registry provenance,
route/collision, and downstream venue/house settlement.

## 2026-09-04 Well phase-0x24 scheduler admits providers in live-vector order

The water-provider update phase has a narrower, source-backed admission
boundary than a blanket “update every Well” rule. `FUN_004AC2B0 @ 0x4AC2B0`
dispatches phase `0x24` to `FUN_00517AD0 @ 0x517AD0`. That function obtains the
live provider vector and count, then iterates indices from zero upward. For
each row it first requires the shared `FUN_00426D10(0)` gate and then calls the
row object's virtual `+0xB8` eligibility predicate; only an eligible row
reaches virtual `+0x218`. The EN/CH body is `identical` in
`local/source/compare-report.tsv`.

This is distinct from the phase-`0x23` house-byte decay pass: it does not
resolve a house, write `cHouseInfo`, or itself select the `+0x32`/`+0x34`
water destination. It only establishes the provider update call order and
the two gates. Native now records that exact pure admission as
`OriginalWaterProviderState.phase24ProviderUpdateIndices`, preserving vector
order and returning no rows when the global gate is closed. The helper is
research-only; the live provider vector, registry projection, `+0x218` state
transition inputs, and downstream water settlement remain unresolved, so the
Qin water bridge stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AC2B0.c`,
`local/source/split-merged/code/0x050000/FUN_00517AD0.c`,
`local/source/compare-report.tsv` row `0x517AD0`,
`Sources/EmperorCore/HousingEvolution.swift`, and the focused
`EmperorCoreTests` regression.

**Evidence class:** **confirmed** for phase dispatch, live-vector iteration
order, global and `+0xB8` gates, and EN/CH parity; **unknown** for provider
registry ownership, `+0x218` input production, and provider-to-house
settlement.

## 2026-09-04 Provider spawn aggregate has a separate three-gate reduction

The indexed corpus exposes one additional bounded consumer of the provider
vector. `FUN_00517A40 @ 0x517A40` walks the same live vector in stored order.
For each row it requires, in sequence, the shared `FUN_00426D10(0)` gate, the
provider virtual `+0xB8` eligibility callback, and the provider virtual `+0x204`
capacity/availability callback. Only then does it invoke virtual `+0x234` and
add that method's integer return to the aggregate. The function returns zero
for an empty vector. The EN/CH comparison row is `identical`.

Its direct indexed caller is `FUN_004F05F0 @ 0x4F05F0`. That caller first
counts active model `0xD1` (Administrative City, authored row 209) and model
`0x6E` (Palace, authored row 110) whose virtual `+0x1B4` result is strictly
greater than one. It invokes `0x517A40` only when at least one model `0xD1`
row passed, adds the returned aggregate, and caps the combined count at
`0x0C`. `FUN_004EF560` and the `FUN_004B1250` placement path consume
`FUN_004F05F0`; their surrounding state fields and user-facing meaning are
not inferred here.

Native now records this arithmetic as the pure
`OriginalResidentialServiceCatalog.providerSpawnAggregate` helper. It accepts the
already-resolved per-row `+0xB8`, `+0x204`, and `+0x234` values, preserves the
admitted vector indices, and rejects mismatched input lengths instead of
silently truncating the source walk. It does not invoke provider callbacks,
create figures, or change Qin placement. Therefore this closes only the
three-gate reduction boundary; provider registry ownership, callback side
effects, and the Administrative City/Palace placement contract remain
**unknown** and the associated Qin path remains fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00517A40.c`,
`FUN_005177B0.c`, `local/source/split-merged/code/0x040000/FUN_004F05F0.c`,
`FUN_004EF560.c`, `FUN_004B1250.c`, `Placing_admin_city_at_pctd.c`,
`GameData/Model/EmperorBuildingModels.txt` rows 110 and 209,
`local/source/compare-report.tsv` rows `0x517A40`, `0x4F05F0`, `0x4EF560`,
and `0x4B1250`, `Sources/EmperorCore/HousingEvolution.swift`, and the focused
`EmperorCoreTests` regression.

**Evidence class:** **confirmed** for vector order, all three admission gates,
the `+0x234` reduction, caller arithmetic, model IDs, cap `0x0C`, and EN/CH
parity; **unknown** for the callback return semantics, provider registry
projection, and placement/UI meaning.

## 2026-09-04 Migration request words have one indexed producer and one daily handoff

The indexed global-write census for the two migration request words is now
complete. Exact searches for `DAT_01311F7C` (arrival request) and
`DAT_01311F80` (departure request) across `local/source/split-merged/code`
return only `FUN_005917E0 @ 0x5917E0` and `FUN_004AD4A0 @ 0x4AD4A0`. Apart from
the consumer's end-of-day clears, the producer is therefore the sole indexed
writer of non-zero request values. It clears both words at the start of each
pass, then writes the arrival word from
`FUN_0059A1B0(0x0C, pressure)` or the departure word from
`FUN_0059A1B0(0x0C, -pressure)`. `FUN_0059A1B0 @ 0x59A1B0` is the exact integer
scale `ceil(12 × amount / 100)` via `FUN_0043B860`: the helper performs
integer division and adds one whenever the remainder is non-zero. The
producer only passes positive amounts (`pressure` for arrivals and
`-pressure` for departures), so this is not a signed-rounding approximation.

`FUN_004AD4A0` is the daily consumer and reset boundary. It calls
`FUN_005917E0` first, carries arrival requests through `DAT_01311F88`, and
dispatches only at the source's strict six-person threshold to
`FUN_004ADA10 @ 0x4ADA10`; departure uses `DAT_01311F84` and
`FUN_004ADC90 @ 0x4ADC90` with the same threshold, then both request words are
cleared. The direct call order and EN/CH decompiled bodies are `identical` in
`compare-report.tsv` for the canonical executables. This closes the
producer-to-pending-request handoff;
it does not close the downstream object-vector walk, provider registry
projection, HouseBldg settlement, or figure creation.

Native records only these source addresses and raw stream roles in
`OriginalMigrationRequestProducerCatalog`; the catalog is metadata and is not
used to enable automatic migration. The Qin bridge therefore remains
`unsupportedOriginalProducer` until the unresolved object and settlement
inputs are recovered.

**Executable builds:** canonical EN
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and CH
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005917e0.c`,
`FUN_0059a1b0.c`, `local/source/split-merged/code/0x040000/FUN_0043b860.c`,
`FUN_004ad4a0.c`,
`FUN_004ada10.c`, `FUN_004adc90.c`, `local/source/compare-report.tsv` rows
`0x43b860`, `0x5917e0`, `0x59a1b0`, and `0x4ad4a0`, and the exact negative search for
`DAT_01311F7C|DAT_01311F80` over `local/source/split-merged/code`.

**Evidence class:** **confirmed** for the sole indexed non-zero request-word
producer (apart from consumer resets),
producer/consumer order, scale arguments, pending-word handoff, six-person
threshold, reset boundary, and EN/CH parity; **unknown** for popularity-factor
input production, war-count projection, provider/object registry ownership,
and downstream arrival/departure settlement.

## 2026-09-04 Qin mission 3 does not contain the request-fulfillment event

The authored Qin campaign event archive provides a direct negative for a
tempting migration shortcut.  `GameData/Campaigns/4 Qin Dynasty.pak` is a
version-9 archive with the fixed event layout (`263` serialized bytes per row,
`40,935` bytes per mission slot).  The third zero-based mission slot (the
Land of Annam mission used by `Qin3PlayerPlaythroughTests`) has 18 active
records whose raw `kind` bytes are:

```text
22, 1, 1, 26, 26, 22, 22, 10, 22, 22, 22, 22, 22, 22, 22, 14, 14, 16
```

The set is `{1, 10, 14, 16, 22, 26}`; in particular it contains no kind `32`,
`requestFulfillment`.  The executable's separate request-generation path
(`FUN_004A9D30` calling `FUN_0054F8D0`) therefore has no authored Qin-3
kind-`32` event-table entry.  This rules out using the event table as evidence
for the missing automatic migration/arrival producer; it does not establish
that the request-generation path itself is the migration producer.  The
unresolved provider, HouseBldg, figure-registry, and settlement paths remain,
so the Qin migration bridge stays `unsupportedOriginalProducer`.

The regression is `testLocalQinMissionThreeHasNoRequestFulfillmentEvent` in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Sources:** `GameData/Campaigns/4 Qin Dynasty.pak`,
`Sources/EmperorCore/CampaignEvents.swift` (fixed-table decoder),
`local/source/split-merged/code/0x040000/FUN_004A9D30.c`,
`local/source/split-merged/code/0x050000/FUN_0054F8D0.c`,
`local/source/compare-report.tsv` rows `0x4A9D30` and `0x54F8D0`, and the
focused XCTest above.

**Evidence class:** **confirmed** for the archive schema, mission-slot index,
active-record count, raw kind sequence, and absence of kind `32`; **unknown**
for any indirect event dispatch and all automatic-migration object/settlement
projections.

## 2026-09-04 Generic map-load callback is inert before specialization

The remaining Qin archive question can be narrowed one step further by
following the callback that `FUN_0042D790` invokes after each generic record.
`FUN_0042D0E0` constructs the MFC `Building` class through
`FUN_0077FD90`, and `FUN_00426C90` installs the generic vtable at
`0x007AB59C`. In both canonical PE images that vtable's `+0xC0` slot points
to `FUN_004271B0 @ 0x4271B0`, while its `+0x150` predicate slot points to
`FUN_00413A00 @ 0x413A00`. The latter is the two-byte body `xor eax,eax;
ret`, so it always returns false. `FUN_004271B0` therefore returns before
its `FUN_0042B6B0`/`FUN_0042B580` tail for a freshly loaded generic record;
there is no provider/HouseBldg specialization hidden in this callback.

This does not prove that no later table or indirect dispatch exists. It does
remove the generic record callback itself from the list of viable Qin provider
creation edges. The only recovered later conversion remains the explicit
`FUN_0052F030` model whitelist, which excludes house models `2…17` and
residential-service providers `72/73/207/208`; provider registry assignment,
route, coverage, and settlement therefore remain unknown and the Qin bridge
stays fail-closed.

Native records the vtable/slot/predicate addresses in
`OriginalMapLoadRehydrationChain` as evidence metadata only; no runtime object
is synthesized from them.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_0042D0E0.c`, `FUN_00426C90.c`, `FUN_004271B0.c`, `FUN_00413A00.c`,
`local/source/compare-report.tsv` row `0x4271B0`, and direct read-only PE
vtable/byte checks in `Exe/ghidra/input/EmperorEN.exe` and
`Exe/ghidra/input/EmperorCH.exe` for both canonical hashes.

**Evidence class:** **confirmed** for generic constructor/vtable identity,
callback slot, always-false default predicate, callback early return, and
EN/CH parity; **unknown** for indirect/table dispatch after the explicit
rehydration pass and all provider registry/route/settlement projections.

## 2026-09-04 Entertainment manager counters read only five admitted model classes

The entertainment manager's object-count input is now bounded independently
of the venue/provider factories. `FUN_00410620 @ 0x410620` clears five counter
words, walks the active object vector from `FUN_00413B40(1)` to
`FUN_004F8200()`, and admits a row only when the shared global
`FUN_00426D10(0)` gate and `FUN_0048A7E0(modelID)` predicate both pass.
`FUN_0048A7E0` admits school models `0xD3/0xD4/0xD5` (authored IDs
`211/212/213`) directly and delegates the remaining cases to
`FUN_0048B540`, whose EN/CH body admits only `0x47` (Entertainment Area,
authored row `71`) and `0x4B` (Theatre Pavilion, authored row `75`). The
manager increments one separate word for each of those five exact model IDs;
all other active objects are ignored. The EN/CH comparison row for
`0x410620` is `identical`, as is the predicate row for `0x48B540`.

The four canonical Qin map archives contain thousands of generic `Building`
records whose serialized model word (`+0x14`, stream offset `+18`) is zero,
and the generic map-load callback is inert before specialization (the
preceding section). Therefore these archive records cannot supply any of the
five admitted model classes to `FUN_00410620`; the manager's entertainment
school/venue counters remain zero unless a separate, still-unrecovered
post-load object-vector projection inserts specialized objects. This is a
confirmed narrowing of the Qin entertainment blocker, not evidence for
constructing or registering a provider.

Native records the exact five-model counter rebuild as
`EntertainmentProviderObjectCounts`; its helper is pure metadata and is not
used to enable Qin entertainment figures. Provider registry ownership,
staffing-word production, route/collision, and venue-to-house settlement
remain **unknown**, so the campaign music bridge stays fail-closed.

## 2026-09-05 Six service families share the provider spawn vtable target

The provider figure-spawn edge is now bounded at the vtable level.  Direct
little-endian reads from the canonical English and Chinese PE `.rdata`
sections show that vtable slot `+0x234` points to the same
`FUN_0051CF90 @ 0x51CF90` target for all six service families:

| provider model(s) | vtable | `+0x234` target |
| --- | ---: | ---: |
| Well `72/73` | `0x7B5EB4` | `0x51CF90` |
| Herbalist `207` | `0x7B6114` | `0x51CF90` |
| Acupuncture `208` | `0x7B6374` | `0x51CF90` |
| Music `211` | `0x7ACEDC` | `0x51CF90` |
| Acrobat `212` | `0x7AD140` | `0x51CF90` |
| Drama `213` | `0x7AD3A4` | `0x51CF90` |

The bytes at each of these sixteen-byte locations are identical between the
hash-identified EN and CH inputs.  The target is present in the indexed split
corpus and is the common provider generator already described in §10.17b and
the provider-spawn aggregate section above.  Its body still applies the
provider/global/worker gates and then dispatches the provider-specific
threshold through virtual `+0x230`; the shared `+0x234` target does not itself
allocate a figure, populate the provider registry, construct a route, or
write house coverage.

Native records this exact six-family mapping in
`OriginalResidentialServiceCatalog.providerVTableSlot234Descriptors` and
locks the model/vtable/slot/target tuples in
`testProviderVTableSlot234DescriptorsShareCanonicalSpawnTarget`.  This is
research metadata only.  It confirms that Music/Acrobat/Drama use the same
spawn-generator entry as Well/Herbalist/Acupuncture, but it does not recover
the missing provider-object projection, callback inputs, figure route, or
house/market settlement; Qin automatic migration and entertainment coverage
therefore remain fail-closed.

**Sources:** canonical `Exe/ghidra/input/EmperorEN.exe` and
`EmperorCH.exe` vtable words at the six bases and offset `+0x234`,
`local/source/split-merged/code/0x050000/FUN_0051CF90.c`,
`local/source/compare-report.tsv` row `0x51CF90`,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the six direct vtable targets, slot
offset, EN/CH parity, and common generator identity; **unknown** for provider
registry ownership, callback input production, figure routing, and all
downstream coverage/settlement semantics.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00410620.c`,
`FUN_0048A7E0.c`, `FUN_0048B540.c`, `local/source/compare-report.tsv` rows
`0x410620` and `0x48B540`, `GameData/Model/EmperorBuildingModels.txt` rows
`71`, `75`, and `211…213`, `Sources/EmperorCore/HousingEvolution.swift`, and
the Qin generic-record regressions
`testQinGenericBuildingArchiveRecordsKeepZeroBaseTypeWord` and
`testQinGenericBuildingArchiveCatalogMatchesRecoveredRecordLayout`.

**Evidence class:** **confirmed** for the vector walk, global/predicate gates,
the five model IDs, separate counter updates, EN/CH parity, and the zero-model
Qin archive input; **unknown** for any indirect post-load insertion into the
active object vector and all provider/route/settlement side effects.

## 2026-09-04 Entertainment venue registration has placement and load edges

The entertainment manager's concrete registration edges are now separated
from the unresolved archive projection. The shared base constructor
`FUN_00490370 @ 0x490370` installs vtable `0x007ADE08`. Direct PE reads from
the canonical EN and CH images show that this base vtable's `+0x90` slot is
`FUN_0048B6D0 @ 0x48B6D0`, while its `+0xC0` slot is `FUN_0048B670 @
0x48B670`. The two admitted venue classes override those slots: vtable
`0x007AD878` (Entertainment Area, model `71`) uses `FUN_0048D6D0 @ 0x48D6D0`
at `+0x90` and `FUN_0048D780 @ 0x48D780` at `+0xC0`; vtable `0x007AD608`
(Theatre Pavilion, model `75`) uses `FUN_0048C270 @ 0x48C270` at `+0x90`
and `FUN_0048BCB0 @ 0x48BCB0` at `+0xC0`.

The placement callbacks `0x48D6D0` and `0x48C270` both call the shared base
`0x48B6D0` first. The venue load callbacks `0x48D780` and `0x48BCB0` both
call base `0x48B670`; that bridge dispatches `FUN_0051CB80 @ 0x51CB80`,
checks the shared global gate, and then performs the same manager insertion
when the gate is open. In either route, the insertion obtains the global
manager from `FUN_0048A340 @ 0x48A340` (returned global
`DAT_00C702C0`), then calls `FUN_00490300 @ 0x490300`. The wrapper passes the
venue pointer to `FUN_00490310 @ 0x490310`, which obtains the manager's vector
endpoint through `FUN_004F8200 @ 0x4F8200` and appends that pointer with
`FUN_005F01F0 @ 0x5F01F0`. EN/CH comparison rows for the indexed functions
`0x48A340`, `0x48B6D0`, `0x48B670`, `0x48C270`, `0x48D6D0`, `0x490300`,
`0x490310`, and `0x490370` are all `identical`; direct PE bytes show the same
venue load-entry targets and call order in both canonical images.

The same callbacks expose the venue object storage shape. Model `71` allocates
an object of `0x230` bytes and stores two `0x20`-byte auxiliary objects at
`+0x228` and `+0x22C`, constructed by `FUN_0048DC20` and `FUN_0048DB40`;
its final refresh dispatch is vtable `+0x27C → 0x48CE40`, which refreshes
those two auxiliary objects through `FUN_00418D90`. Model `75` allocates
`0x184` bytes, stores three `0x20`-byte auxiliaries at `+0x150/+0x154/+0x158`
using `0x48DC20/0x48DB40/0x48DD70`, and keeps a ten-entry pointer array at
`+0x15C` (four-byte stride). Each entry is created by `FUN_00490450` as a
`0x10`-byte wrapper with a `0x24`-byte payload from `FUN_0048DBC0`; its final
refresh dispatch is `+0x268 → 0x48C230`, which refreshes the three auxiliaries
and all ten entries. The allocation and refresh branches are identical in
the canonical EN/CH PE bytes; the auxiliary field meanings and record
semantics remain unresolved.

This is confirmed evidence that an already-created venue object enters the
entertainment manager during both placement and venue-load callbacks. It is
**not** evidence that the Qin generic archive creates either venue: the
archive's generic `Building` record still has model word `0`, and its own
`+0xC0` callback is the separate generic/load path already shown inert before
specialization. It also does not recover the archive registry index, the call
that constructs or places a venue for Qin, staffing production, route/collision,
or house settlement. Native therefore records this edge as metadata only and
keeps the Qin entertainment bridge fail-closed.

`OriginalResidentialServiceCatalog.entertainmentManagerRegistrationDescriptor`
records the exact model/vtable/slot/call sequence; the regression
`testEntertainmentManagerRegistrationDescriptorSeparatesPlacementFromLoad`
locks both registration entries, the two venue load targets, and the
`0x48B670 → 0x51CB80 → manager append` bridge.
`OriginalResidentialServiceCatalog.entertainmentVenueLifecycleDescriptors`
and `testEntertainmentVenueLifecycleDescriptorsMatchVenueCallbacks` record
the two object sizes, auxiliary offsets, Theatre's ten-entry array, and final
refresh slots without constructing any runtime object.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00490370.c`,
`FUN_0048B6D0.c`, `FUN_0048B670.c`, `FUN_0048C270.c`, `FUN_0048D6D0.c`,
`FUN_0048A340.c`, `FUN_00490300.c`, `FUN_00490310.c`,
`local/source/compare-report.tsv`, and direct read-only vtable words from
`Exe/ghidra/input/EmperorEN.exe` and `EmperorCH.exe`.

**Evidence class:** **confirmed** for the venue vtable slots, placement/load
registration order, manager accessor, vector append chain, object sizes,
auxiliary/record layout, refresh slots, and EN/CH parity;
**unknown** for Qin archive construction/placement, registry provenance,
staffing, route, and settlement.

## 2026-09-04 Migration assignment writers close the figure/house handoff

The request words' downstream assignment callbacks are now recorded as a
separate, source-backed boundary.  Once `FUN_004AD4A0 @ 0x4AD4A0` carries a
pending request across its strict six-person threshold, arrival assignment
uses `FUN_004ADA10 @ 0x4ADA10`, which calls `FUN_004ADE10 @ 0x4ADE10` for each
selected house batch.  On a successful `FUN_004EA050(1, 0x0B, ...)` allocation,
the writer initializes figure state `+0x40 = 6`, stores the destination house
ID at `figure +0x64`, stores the requested people count as a byte at
`figure +0x6E`, and links the figure ID into `house +0x32`.  It does not
increment `house +0x20`; that resident/population effect belongs to the
later type-`0x0B` arrival think.  A failed allocator returns without any of
these figure/house writes, while the assignment caller still accounts the
requested batch around the call.

Departure assignment uses `FUN_004ADC90 @ 0x4ADC90` and
`FUN_004ADED0 @ 0x4ADED0`.  The writer first calls
`FUN_00591900(-peopleCount)`, then clamps/decrements `house +0x20` and may
run the exhausted-house cleanup.  It attempts a type-`0x0C` figure allocation;
on success the figure receives state `+0x40 = 6`, wait word `+0x3E = 0`, and
the signed people byte at `+0x6E`.  This path has no recovered
`house +0x32` in-flight link.  The population callback and the two writer
addresses are identical in the canonical EN/CH indexed bodies.

`OriginalMigrationRequestProducerCatalog` now preserves these exact writer
addresses, figure model IDs, raw field offsets, and the population callback as
metadata; no runtime migration producer, object-registry projection, or route
was enabled by this finding.  The unresolved popularity input, archive
provider/house projection, walker movement/arrival timing, and settlement
remain **unknown**, so Qin automatic migration stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004ADA10.c`,
`FUN_004ADC90.c`, `FUN_004ADE10.c`, `FUN_004ADED0.c`,
`local/source/compare-report.tsv` rows `0x4ADA10`, `0x4ADC90`,
`0x4ADE10`, and `0x4ADED0`, plus `Sources/EmperorCore/MigrationSimulation.swift`
and `Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the six-person handoff boundary,
figure types `0x0B/0x0C`, state/field writes, resident-count ordering,
population callback, failed-arrival allocation edge, and EN/CH parity;
**unknown** for producer inputs, registry ownership, route/arrival timing,
and downstream settlement.

## 2026-09-04 `FUN_0052F030` has one indexed caller and a fixed object-field input tuple

The direct-call census for the generic-object rehydration pass is now
explicit. Exact symbol searches across both generated decompilations contain
one call outside the function definition: `FUN_0053D100 @ 0x53D100` invokes
`FUN_0052F030 @ 0x52F030` in the map/post-load sequence. The canonical EN/CH
`compare-report.tsv` row for `0x53D100` is `identical`. This is a direct
`E8`-edge result only; a function-pointer or table-driven edge is not ruled
out by the indexed corpus.

Inside that pass, `FUN_00413B40(1)` supplies the active object-vector start and
the loop advances one pointer at a time until `FUN_004F8200()`; it therefore
starts at vector index `1`, not at the archive byte stream. Each candidate must
have a non-zero object byte at `+0x04`, and the model word read at `+0x14` must
pass `FUN_0052F1D0`. For an admitted candidate, the source reads signed
coordinates at object `+0x0A` and `+0x0C` and dispatches the common creation
entry `FUN_0042D540(model, x, y, 0, 0)`. The pass then links the created
object through `FUN_004B11F0` and refreshes the map cell with
`FUN_004EAC50`; neither call consumes the generic archive's provider tail.

This closes the input tuple and caller order for the known rehydration path:
it is an active-vector/object-field transform followed by a model whitelist,
not a blanket conversion of serialized `Building` records. It strengthens the
existing Qin negative because the four canonical generic archives expose zero
at the corresponding model, activity, and coordinate fields. The remaining
indirect/table-driven specialization edge, provider registry ownership, and
house/service settlement remain **unknown**; Native must keep automatic Qin
projection fail-closed.

`OriginalMapLoadRehydrationChain` now records the direct-caller census, vector
start, object offsets, and common creation address as metadata-only constants;
the regression test locks each value without constructing a runtime object.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0052F030.c`,
`FUN_0053D100.c`, `local/source/decompiled-en.c`,
`local/source/decompiled-ch.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the one indexed direct caller, EN/CH
identity, vector start, activity/model/coordinate offsets, creation entry,
and post-create link/refresh calls; **unknown** for any indirect/table edge,
archive-to-vector population, provider registry assignment, and downstream
settlement.

## 2026-09-04 Qin mission startup keeps generic archive rows fail-closed

The recovered startup boundary is now covered at the gameplay entry point.
`GameSessionController.startCampaignMission` loads the authored map into
`EmperorMap`, then constructs `DeterministicCityState` from the mission
settings and terrain.  The initializer restores terrain, roads, and authored
monument state; it does not copy `genericBuildingArchiveRecords` into
`houses`, `placedBuildings`, or `residentialServiceBuildings`.

This is intentional source-first behavior, not an assumption that the maps
contain no objects.  The canonical Qin `Haunxian.map` archive has a non-empty
generic `Building` stream, but its scanned rows have common base model word
`0`; `OriginalMapLoaderRehydrationCatalog.rehydrates(genericRecord:)` rejects
all of them because `FUN_0052F030` admits only its separate model whitelist.
The generic-load callback also returns through the always-false base
`+0x150` predicate before any specialization.  Since the corpus still does
not expose an indirect archive-to-HouseBldg/provider projection, the startup
test asserts that these rows remain archive evidence and that the live Qin
city starts with no synthesized houses, service providers, or placed
buildings.  This prevents a later playthrough tweak from turning serialized
generic rows into guessed gameplay state.

The new regression is
`testQinMissionOneDoesNotPromoteGenericMapRowsIntoLiveObjects` in
`Tests/EmperorGameplayTests/QinCampaignBaselineTests.swift`.  It does not
enable migration or change the player-visible startup; it fixes the current
fail-closed contract while the indirect specialization, provider registry,
route, and settlement edges remain **unknown**.

**Sources:** `Sources/EmperorGameplay/GameSessionController.swift`,
`Sources/EmperorCore/CitySimulation.swift`,
`Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`,
`local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_0042D0E0.c`, `FUN_004271B0.c`,
`local/source/split-merged/code/0x050000/FUN_0052F030.c`,
`FUN_0052F1D0.c`, and the canonical Qin archive regressions.

**Evidence class:** **confirmed** for the Native startup call order, the
non-empty zero-model archive input, whitelist rejection, and the explicit
fail-closed state; **unknown** for indirect/table-driven specialization,
archive-to-vector population, provider registration, routing, and settlement.

## 2026-09-04 Entertainment spawn-threshold method addresses are explicit

The indexed `local/source/split-merged/functions-index.csv` corpus has no
standalone function file for `0x005AB330`; the negative search is recorded so
the threshold table is not mistaken for recovered C source. After exhausting
that corpus, read-only `objdump` inspection of the canonical EN and CH PE
images recovered the exact method body at `0x005AB330`: worker percentages
`>=100`, `75…99`, `50…74`, `25…49`, `1…24`, and `0` return thresholds
`3, 6, 12, 24, 32, 64`, respectively. The corresponding Drama School method
at `0x0048B380` returns `6, 12, 24, 32, 48, 96`. The two byte ranges are
identical between the hash-identified EN and CH images. `FUN_0051CF90` calls
the selected virtual method only after its access/worker gates, advances the
provider counter with UInt8 semantics, and requests a figure on strict
`counter > threshold`; the existing pure counter helper preserves that order.

Native now exposes the address mapping as
`OriginalResidentialServiceCatalog.entertainmentSpawnThresholdMethodAddress`
and locks it with the threshold regression. This is a source-backed research
boundary only. The indexed-source gap, provider registry/object projection,
figure allocation, route/collision, and house settlement remain **unknown**;
秦音乐人物仍保持 fail-closed。

**Sources:** negative search of
`local/source/split-merged/functions-index.csv` and
`local/source/split-merged/code/`; `local/source/split-merged/code/0x050000/
FUN_0051cf90.c`; direct read-only disassembly of
`Exe/ghidra/input/EmperorEN.exe` and `EmperorCH.exe` at `0x005AB330` and
`0x0048B380`; `docs/exe-research/residential-service-roamer-lifecycle.md`
§7.2b; `Sources/EmperorCore/HousingEvolution.swift`; and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for method addresses, threshold rows,
strict counter gate, and EN/CH byte parity; **unknown** for the missing indexed
function body, provider registration, figure allocation, routing, and
provider-to-house settlement.

## 2026-09-04 MFC map object dispatch is class-name driven

The generic map loader's class boundary was rechecked against the indexed
`local/source` bodies rather than relying on a decompiler heuristic.  In
`FUN_0042D0E0 @ 0x42D0E0`, the loader passes the `Building` runtime-class
descriptor at `0x00817890` to `FUN_0077FD90 @ 0x77FD90`.  That reader delegates
the object tag to `FUN_0077FFC8 @ 0x77FFC8`.  The latter reads the tag through
`FUN_0041FCB0`; a serialized `0xFFFF` tag enters
`FUN_007802FE @ 0x7802FE`, which reads the class-name length and bytes and
walks the registered runtime-class list using exact `lstrcmpA` comparison.
The selected runtime-class record is then inserted into the MFC reference
table and its virtual `+0x08` constructor/serializer entry is invoked before
`FUN_0077FD90` returns the object.  Non-`0xFFFF` tags instead resolve an
existing reference-table entry.  The EN/CH comparison rows for
`0x42D0E0`, `0x77FD90`, `0x77FFC8`, and `0x7802FE` are all `identical`.

This closes the previously easy-to-misread point: passing the `Building`
descriptor is an expected-base-class check, not proof that every Qin archive
object receives the base `Building` vtable.  Qin archives still expose only
the authored class declarations already cataloged (for example `Building`,
`cResWall`, `cResGate`, `cMonumentBldg`, `cIndustrialBldg`, and `cFillBldg`);
they expose no `Well`/`Herbalist`/`Acupuncturist` service-class declaration.
The dynamic class resolver therefore explains the specialized barrier and
monument runs, but it does not recover their `+0xC0` registration side effects,
the generic-record-to-provider conversion caller, a provider registry index,
or route/settlement state.  Native must continue to retain the archive class
inventory as evidence only and keep Qin service/migration projection
fail-closed.

`OriginalMapArchiveRuntimeClassCatalog` records the exact reader, tag decoder,
class-name resolver, new-class marker, expected base descriptor, and direct
loader caller; `testMapArchiveRuntimeClassDispatchMatchesMFCReaderBoundary`
locks these constants without constructing or registering a runtime object.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042d0e0.c`,
`local/source/split-merged/code/0x070000/FUN_0077fd90.c`,
`FUN_0077ffc8.c`, `FUN_007802fe.c`, `FUN_0077b497.c`,
`FUN_0077bb54.c`,
`local/source/compare-report.tsv` rows `0x42d0e0`, `0x77fd90`, `0x77ffc8`,
and `0x7802fe`, plus the Qin map class-inventory regressions in
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the MFC new-class/reference branch,
exact-name resolver, selected constructor/serializer dispatch, direct map
caller, and EN/CH parity; **unknown** for callback side effects, archive
record-to-vector population, provider registration, and house/service
settlement.

## 2026-09-04 Xiangjun barrier records enter the specialized load callback

The Xiangjun `cResWall`/`cResGate` runs were checked against the same loader
gate instead of being treated as presentation-only records.  In
`FUN_0042D790 @ 0x42D790`, the object byte at `+0x04` is tested for nonzero
before the current object's virtual `+0xC0` call.  For both class runs, the
common serializer places that byte 16 bytes before the serialized model word;
all 27 `cResWall` records and all 16 `cResGate` records store the exact value
`3`.  Therefore these 43 specialized objects do enter the original load
callback, unlike the four Qin generic `Building` runs whose corresponding
byte is `0`.

Direct little-endian vtable reads from both canonical PE files show
`0x7AAAB8` (`cResWall`) and `0x7AAFB0` (`cResGate`) both point at
`FUN_0051CB80 @ 0x51CB80` in slot `+0xC0` and at
`FUN_0051CC10 @ 0x51CC10` in slot `+0x1FC`.  The indexed callback body first
executes `FUN_004271B0`, then accepts only an object `+0x04` state of `1` or
`3`, allocates a `0x20`-byte auxiliary, constructs it with
`FUN_00526830(object + 0xB4)`, stores the pointer at object `+0x14C`, and
dispatches `+0x1FC`.  `FUN_0051CC10` only refreshes an already-present
auxiliary through `FUN_00418D90`; its `FUN_00418E80` refresh path calls
`FUN_0047F1B0(auxiliary + 0x14)` and dereferences that object-vector entry.
Because `FUN_00418D70` stores the callback's input at auxiliary `+0x14`, this
is a direct read chain proving that the barrier object's `+0xB4` value is an
object-vector slot for this lifecycle.  The refresh does not write `+0xB4`,
append a new building-vector entry, or establish a provider/house link.  The class
constructors are the indexed `FUN_00416CB0 @ 0x416CB0` and
`FUN_00416D00 @ 0x416D00`, which install those two vtables for model families
`89/90/91/231` and `104/105/106/232` respectively.  All indexed EN/CH rows
and the four vtable words are identical between the canonical builds.

The same objects also pass through the map post-load walk
`FUN_0042DA10 @ 0x42DA10`: the raw `cResWall`/`cResGate` vtables use
`+0x1C8 → 0x415AD0`, and the direct PE body calls the object's `+0x270`
callback (`FUN_004153B0`) with `(0, 0)` before returning `1`.  The indexed
`FUN_004153B0` body recomputes four neighbor slots, selects the connected
barrier image, and writes selected map-cell state through
`FUN_004B72B0`; its EN/CH row is `identical`.  This closes two previously
broad unknowns: Xiangjun barrier objects are active at the map-loader
callback boundary, and their serialized `+0xB4` values (`1…43`) are proven
object-vector slots consumed by the auxiliary refresh chain.  It still does
not identify the auxiliary's semantic consumer, collision-grid writes,
orientation/footprint registration, or any conversion into a Qin residential
service provider.  Native therefore records the load lifecycle and byte
boundary only; it must not instantiate the auxiliary or promote the barrier
slots into live provider/house state.

`OriginalResidentialBarrierMapState.serializedLoadEligibilityByte` preserves
the recovered byte, and `OriginalResidentialBarrierLoadLifecycleCatalog`
records the vtable/callback, post-load `+0x1C8 → +0x270` edge, and auxiliary
offsets.  Regressions
`testXiangjunResidentialBarrierArchiveRecordsUseSpecializedRuns` and
`testResidentialBarrierLoadCallbacksMatchCanonicalVtables` lock the values
without creating runtime objects.

The connected callback's model branch is also now explicit for this archive:
model `90` (`FUN_00415740`) writes overlay `0x48`, while model `105`
(`FUN_00415770`) writes overlay `0x08`.  Both specialized vtables use
`+0x268 → FUN_004E1C40`, whose EN/CH body returns `1`; the callback therefore
ORs raw state bit `0x04` into `DAT_00F37DA0[object+0x10]` after the writer
call; `+0x10` is the serialized map-cell index, not the `+0xB4` object-vector
slot.
These constants close the original writer boundary but do not name the bit or
authorize Native route/collision mutation.  The catalog exposes them as
research metadata and returns no overlay for untraced model families.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042D790.c`,
`FUN_00416CB0.c`, `FUN_00416D00.c`, `FUN_00426D10.c`,
`local/source/split-merged/code/0x050000/FUN_0051CB80.c`,
the raw EN/CH PE bytes at `0x51CC10`, `FUN_00526830.c`,
`FUN_00418D90.c`, `FUN_00418E80.c`, `FUN_0047F1B0.c`,
`FUN_004153B0.c`, `FUN_004B72B0.c`,
`local/source/compare-report.tsv` rows `0x42d790`,
`0x416cb0`, `0x416d00`, `0x426d10`, `0x51cb80`, and the decoded
`GameData/Cities/Xiangjun.map` barrier records.

**Evidence class:** **confirmed** for the serialized eligibility byte,
vtable slots, callback allocation/store/refresh order, post-load connected
callback/grid-writer edge, object-vector slot read chain, model-family
constructors, registry input field, and EN/CH parity;
**unknown** for
auxiliary semantics, collision/object-grid registration, provider registry
projection, and house/service settlement.

## 2026-09-04 Entertainment-school coverage dispatch is closed

The Qin entertainment blocker now has a complete callback dispatch boundary.
At a figure crossing, `FUN_004EACD0` calls the provider `+0x28` method; the
Music, Acrobat, and Drama school vtables (`0x7ACEDC`, `0x7AD140`, and
`0x7AD3A4`) all route that slot to `FUN_00429DF0`, which forwards radius `2`
to `FUN_00429E10`.  The provider `+0x2C` slot then reaches the distinct
`FUN_0048AD20` house-coverage callback.  The indexed EN/CH rows for the
crossing and scanner are `identical`, and the corresponding vtable words plus
the unsplit callback body are byte-identical in the two canonical PE files.

Native records this as `EntertainmentCoverageDispatchDescriptor.canonical`
and adds a regression that locks all addresses, offsets, and the radius.  It
does not enable Qin music/acrobat/drama figures: provider registry projection,
venue route/collision results, and terminal settlement remain unresolved and
the player-command test remains fail-closed.

**Evidence class:** **confirmed** for callback dispatch, radius, vtable slots,
addresses, and EN/CH parity; **unknown** for provider registry, route/collision,
and provider-to-house settlement.

## 2026-09-04 cMarket peddler links are attached-info slots, not commodity records

The cMarket peddler-slot fields were rechecked against the direct vtable
pointer rather than the offset-only shorthand used by earlier notes.  In the
canonical EN and CH images, the common cMarket vtable at `0x7B6F3C + 0x1E8`
points to `FUN_00416B50 @ 0x416B50`; the complete body is
`8D 81 C8 00 00 00 C3` (7 bytes, SHA-256
`2783f77e759c990df3d7ae85040ccc1b0885a0285cf1d92254fab5af72f754e8` in both
builds).  It returns `this + 0xC8`.  Therefore the object read at offsets
`+0x6A/+0x6C` by the cMarket peddler validators is the market's attached
information object, not one of the six contiguous 16-byte commodity records
starting at `market + 0x154`.  The latter array is still the storage used by
`+0x2CC/+0x2D8/+0x264/+0x268` quantity paths.

The three cMarket link validators are EN/CH-identical indexed functions:

| cMarket slot | address | stored link | recovered check |
| --- | --- | --- | --- |
| `+0x3C` | `FUN_00429700 @ 0x429700` | market `+0x2E` | active figure, model equals either supplied argument, figure parent `+0x62 == market +0xB4`; failure clears `+0x2E` |
| `+0x40` | `FUN_00429780 @ 0x429780` | attached info `+0x6A` | same active/model/parent checks; inactive or mismatch clears `+0x6A` |
| `+0x44` | `FUN_00429810 @ 0x429810` | attached info `+0x6C` | same active/model/parent checks; inactive or mismatch clears `+0x6C` |

`FUN_004272A0 @ 0x4272A0` is the registration writer at cMarket
`+0x50`.  It fills the primary market slot first, then the attached-info
`+0x6C` slot for market type `3` when that slot is empty, and otherwise writes
the attached-info `+0x6A` slot; stale primary/tertiary figures are replaced
only after the corresponding active-byte check fails.  The capacity gate
`FUN_00429670` consumes the same validators: Common Market type `2` checks
`+0x3C/+0x40`, while Grand Market type `3` checks all three.  This is the
confirmed peddler-link lifecycle and explains the recovered `2`/`3` live
peddler capacities without treating the six commodity records as figure
slots.

The pure `OriginalMarketPeddlerLinkStorage` descriptor in
`Sources/EmperorCore/MarketSimulation.swift` records the getter, attached-info
offset, slot offsets, validator addresses, and figure fields.  Its regression
only locks these source boundaries; it does not allocate figures, attach a
provider registry, or project links into Native market inventory.  A Qin
campaign still cannot enable peddler route/coverage/settlement from this
link-storage evidence: provider registration, route/collision consumers, and
house quality writers remain **unknown**.

**Sources:** direct canonical EN/CH PE bytes at `0x416B50` and vtable word
`0x7B6F3C + 0x1E8`; `local/source/split-merged/code/0x040000/`
`FUN_004272a0.c`, `FUN_00429700.c`, `FUN_00429780.c`, `FUN_00429810.c`,
`FUN_00429670.c`; `local/source/compare-report.tsv` rows `0x4272a0`,
`0x429700`, `0x429780`, `0x429810`, and the focused
`testOriginalMarketPeddlerLinkStorageIsSeparateFromCommodityRecords`.

**Evidence class:** **confirmed** for the getter body, EN/CH parity, attached
info offset, link-slot offsets, registration/validator call edges, failure
clears, and type-2/type-3 validator sets; **unknown** for provider registry
population, route/collision settlement, and the Native projection.

## 2026-09-04 House vacant-type dispatch preserves the cHouseInfo/provider gate

The shared house-evolution/migration method `FUN_00519F30 @ 0x519F30` has a
small but exact branch that must not be replaced with a generic “vacant house”
heuristic. It first resolves `cHouseInfo` through the current object's
virtual `+0x1E4` getter, then checks `cHouseInfo +0x3C == 0` and the house
resident word at object `+0x20 == 0`. Only when both are zero does it call the
same object's virtual `+0x204` predicate. A false predicate dispatches
`FUN_00519060 @ 0x519060` with the object's `+0x2D` registry index and returns;
all other cases invoke the current object's virtual `+0x230` with the caller's
argument. Both branches return the literal success value `1`.

`FUN_00519060` then selects its common/elite vacant conversion from the
current model (`FUN_005188F0` / `FUN_005188D0`), writes `(object +0x14,
+0x16) = (3,0)` or `(0x0C,9)`, and rebuilds the map cell through
`FUN_004B72B0`. Those writes are source facts; their complete Native
residential lifecycle remains unresolved. The indexed EN/CH rows for
`0x519F30` and `0x519060` are `identical`.

Native records only the dispatch boundary as
`OriginalHouseVacantTypeTransition.action`, including the getter/field/slot
offsets and both target addresses. It does not mutate houses or enable Qin
migration: object-vector registry projection, the meaning of the `+0x204`
predicate, and the downstream vacant-type/arrival settlement remain
**unknown**.

**Sources:** `local/source/split-merged/code/0x050000/FUN_00519f30.c`,
`FUN_00519060.c`, `FUN_005188f0.c`, `FUN_005188d0.c`,
`local/source/compare-report.tsv` rows `0x519f30`, `0x519060`, `0x5188f0`,
and `0x5188d0`, plus the focused
`testHouseVacantTypeTransitionPreservesSourceGateOrder` regression.

**Evidence class:** **confirmed** for gate ordering, field/virtual offsets,
dispatch targets, return value, vacant conversion writes, and EN/CH parity;
**unknown** for callback semantics, registry ownership, and downstream Qin
arrival/house settlement.

## 2026-09-04 Housing-status scan and event bridge are raw, separate boundaries

The second half of the 16-slice boundary `FUN_004AC650 @ 0x4AC650` calls
`FUN_0053BB30 @ 0x53BB30` immediately after `FUN_00591200` and the assignment
`DAT_00D6241C = DAT_013128C0`.  `FUN_0053BB30` starts at active-object vector
index `1` (not `0`), and for each entry requires both the global
`FUN_00426D10(0)` gate and the object's virtual `+0xB8` predicate.  An admitted
entry always increments the denominator, while its signed object word at
`+0x8C` contributes only to the middle bucket `0x47…0x50` or high bucket
`>=0x51`; values below `0x47` remain denominator-only.  The two bucket counts
are converted by `FUN_00408BA0 @ 0x408BA0`, exactly
`(numerator * 100) / denominator` with integer truncation and zero for a zero
denominator.

The writer then emits raw composition byte `DAT_01312898`: no admitted entry
`0x17`; otherwise middle percentage `<0x33` and high percentage `<0x1A`
select `0x16` for high `<0x0B`, `0x15` otherwise, `0x13` for high `>=0x1A`,
and `0x12` for middle `>=0x33`.  It separately emits advisor byte
`DAT_013128C0`: no admitted entry `0x98`; middle `>0x32` gives `0x93`, high
`>0x19` gives `0x94`, and the remaining bands give `0x97` for high `<0x0B`
or `0x95` otherwise.  The later phase-3 call
`FUN_00548B70(DAT_00D6241C)` maps current advisor bytes `0x93…0x98` to event
IDs `0xD6…0xDB`; only `0x97` and `0x98` suppress a repeat when the previous
status is unchanged.  The indexed EN/CH rows for `0x53BB30`, `0x548B70`, and
`0x408BA0` are all `identical`.

Native records this exact raw input/output boundary as
`OriginalHousingStatusScan.scan`, `integerPercent`, and `eventID`, with
regressions for vector-index skipping, denominator-only entries, strict
percentage edges, and repeat suppression.  It is research-only: the active
object-vector projection, the meaning of the `+0x8C` statuses, and any Qin
house/provider settlement consumer remain **unknown**, so this does not
enable Qin automatic migration or desirability.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0053bb30.c`,
`FUN_00548b70.c`, `local/source/split-merged/code/0x040000/FUN_00408ba0.c`,
`FUN_004ac650.c`; `local/source/compare-report.tsv` rows `0x53bb30`,
`0x548b70`, and `0x408ba0`; and the focused
`testOriginalHousingStatusScanPreservesVectorStartAndIntegerBoundaries` /
`testOriginalHousingStatusEventBridgePreservesRepeatSuppression` regressions.

**Evidence class:** **confirmed** for scan order, gate ordering, bucket
boundaries, integer ratio, raw status/event bytes, phase-3 call order, and
EN/CH parity; **unknown** for status semantics, object registration, and
Native projection into Qin houses or providers.

## 2026-09-04 Residential spawn request clears its counter before allocation (confirmed boundary)

The tail of `FUN_0051CF90 @ 0x51CF90` is now separated from the threshold
counter itself. After the incremented provider byte `+0x36` is strictly above
the virtual `+0x230` threshold, the executable writes zero to `+0x36` *before*
calling `FUN_004EA050`. The allocator's return value is then tested: a
non-zero figure registry ID enters the `FUN_0047F1B0` lookup, provider vtable
`+0x50` attachment, figure parent write `figure +0x62 = provider +0x2D`, and
figure vtable `+0x22C` initializer. Only after those calls does it advance the
provider heading byte `+0x38` by four modulo eight and copy that value to
figure `+0x1A`, then call `FUN_004E6A70`. A zero allocator result still leaves
the counter reset and returns from the threshold branch; it does not restore
the previous counter.

`OriginalResidentialServiceCatalog.ResidentialSpawnCounterTransition` now
names its Boolean `didRequestFigure` rather than implying allocation success
(`didSpawn` remains a deprecated compatibility view). The new
`residentialSpawnFigureHandoff` helper records the exact post-allocation
field/slot offsets and modulo-eight heading result without resolving the
figure registry, invoking route construction, or projecting coverage. The
focused regression covers signed-short parent-index truncation and the
provider/figure heading copy.

**Sources:** canonical EN
`local/source/split-merged/code/0x050000/FUN_0051cf90.c`, its identical CH
row in `local/source/compare-report.tsv`,
`local/source/split-merged/code/0x040000/FUN_004e6a70.c`, and the direct
call/field sequence in both generated decompilations; implementation and
regression in `Sources/EmperorCore/HousingEvolution.swift` and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for counter-clear ordering, allocator-result
branch, provider/figure slots and offsets, heading arithmetic, bootstrap call,
and EN/CH parity; **unknown** for allocator registry ownership, provider
attachment side effects, route/collision, and house settlement. Qin campaign
spawning remains fail-closed.

## 2026-09-04 Entertainment performance callback closes actor auxiliary-counter arithmetic

The venue performance callback at `0x48B710` was checked at machine-code level
in both canonical PE inputs. For figure models `32`, `33`, and `34` it writes
`0x20` to provider-record bytes `+0x5D`, `+0x5F`, and `+0x5E` respectively.
Only model `33` then reads record `+0x64`, increments the byte with ordinary
UInt8 wrap, stores the incremented value, and clears the byte when the value is
`>= 5`; values `0…3` therefore become `1…4`, value `4` becomes `0`, and
`0xFF` wraps to `0` without taking the reset branch. Models `32` and `34` do
not touch `+0x64`. The EN/CH slices are byte-identical.

`OriginalResidentialServiceCatalog.entertainmentVenuePerformanceTransition`
now preserves this complete write/transition boundary, including the
pre/post auxiliary byte and reset flag. It remains a pure research helper:
the venue provider registry, route/collision path, figure dispatch, and house
settlement are still unresolved, so Qin music figures remain fail-closed.

**Sources:** canonical EN/CH `.text` at `0x48B710…0x48B77C`,
`local/source/compare-report.tsv` venue rows, `GameData/Model/
EmperorFigureModels.txt`, and the focused
`testEntertainmentVenuePerformanceTransitionPreservesActorCounterReset`.

**Evidence class:** **confirmed** for model-to-byte writes, UInt8 increment/
wrap, `>=5` reset, and EN/CH parity; **unknown** for the counter's semantic
meaning, provider registration, route/collision, figure dispatch timing, and
downstream house settlement.

## 2026-09-04 Well command global has a recoverable input-record envelope

The upstream writer of the command global used by the external Well-byte path
is now bounded one layer earlier. `FUN_005C0E80 @ 0x5C0E80` first rejects an
inactive input record (`record +0x0C == 0`). When the global controller gate
`DAT_010DE070` is open, it copies the record command/payload fields
`+0x158/+0x15C` into `DAT_010C6F60/DAT_010C6F5C`, marks `record +0x155` handled,
and invokes callback slot `+0x14C`. If that gate is closed, the only alternate
dispatches are record mode `+0x157 == 1` with `DAT_010DE063` or mode `== 3`
with `DAT_010DE064`; those copy the same two fields and invoke slot `+0x150`.
The primary branch has precedence when both conditions are true.

`FUN_005C0F10 @ 0x5C0F10` is the spatial caller: it evaluates the record's
rectangular bounds through `FUN_005C0E10`, toggles its active byte, and invokes
`0x5C0E80` only on an entered hit. `FUN_005C11A0 @ 0x5C11A0` initializes the
same mode, command, payload, callback slots, and handled byte; the indexed
EN/CH rows for all three bodies are `identical`. The pure
`OriginalWaterProviderState.controllerCommandDispatch` helper and regression
preserve this gate order and callback selection, including command `0x69` as
an opaque value.

This closes the command-global input envelope but not its human-facing source:
the `0x69` meaning, callback implementations, spatial record producer, and
whether a Qin-3 record ever targets a live Well remain **unknown**. The helper
does not invoke `FUN_00511860` or raise provider `+0x6F`, so the Qin water
bridge remains fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_005c0e80.c`,
`FUN_005c0f10.c`, `FUN_005c0e10.c`, `FUN_005c11a0.c`, and
`local/source/compare-report.tsv` rows `0x5c0e80`, `0x5c0f10`, and
`0x5c11a0`; implementation and focused regression in
`Sources/EmperorCore/HousingEvolution.swift` and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for active/mode/global gate order, copied
fields, handled flag, callback slots, hit-test caller, and EN/CH parity;
**unknown** for the command meaning, upstream record producer, callback side
effects, Qin reachability, and provider/house settlement.

## 2026-09-04 Linked-object `+0x100` dispatch separates generic Building from HouseBldg

The map-repair wrapper `FUN_004B11F0 @ 0x4B11F0` does not call a fixed
building routine. It resolves the object from `FUN_0047F1B0(objectID)` and
dispatches the object's virtual slot `+0x100`; only a callback returning true
with the wrapper's `param_6` set emits the follow-up `FUN_005C4500(6)` event.
The indexed corpus contains exactly seven direct wrapper callers:
`FUN_004157D0`, `FUN_00415D30`, `FUN_004AFEF0`, `FUN_004B1250`,
`FUN_0052F030`, and `FUN_005428B0` (the two placement functions are separate
call sites). The known generic-object rehydration pass therefore reaches this
virtual boundary only after its whitelist and `Creating(...)` call; the map
loader's generic `+0xC0` callback is a different slot.

Direct little-endian reads of the canonical EN and CH vtables at
`vtable + 0x100` are byte-identical. The recovered dispatch table is:

| runtime class | vtable | `+0x100` target | source fact |
| --- | ---: | ---: | --- |
| `Building` | `0x7AB59C` | `0x428F10` | 5-byte `xor al,al; ret 24`, always false |
| `HouseBldg` | `0x7ABA38` | `0x519F30` | vacant-house/provider gate |
| Well | `0x7B5EB4` | `0x51DD20` | service-object map callback |
| Herbalist | `0x7B6114` | `0x51DD20` | shared service callback |
| Acupuncture | `0x7B6374` | `0x51DD20` | shared service callback |
| Music/Acrobat/Drama School | `0x7ACEDC`/`0x7AD140`/`0x7AD3A4` | `0x51DD20` | shared entertainment callback |
| Entertainment Area | `0x7AD878` | `0x48D230` | distinct entertainment callback |

The `HouseBldg` target is the already-recovered `FUN_00519F30`: it obtains
`cHouseInfo` through `+0x1E4`, checks `+0x3C` and resident word `+0x20`, then
chooses the vacant conversion (`FUN_00519060`) or the object's `+0x230`
handler. By contrast, a generic Qin `Building` row enters `0x428F10` and
cannot take this HouseBldg branch through `FUN_004B11F0`. The static result
narrows the unresolved edge to the absent class-specialization/object-vector
projection rather than to a hidden generic callback; it still does not prove
that any Qin archive row is registered as `HouseBldg`, a Well, or a provider.

Native records the addresses and class table in
`OriginalMapArchiveRepairCatalog.linkedObjectCallbackVTableDescriptors` and
keeps it metadata-only. The focused regression
`testMapLinkedObjectCallbackVTableBoundaryKeepsGenericQinRowsFailClosed`
locks the table and the generic false return without invoking any callback.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004b11f0.c`,
`FUN_004157d0.c`, `FUN_00415d30.c`, `FUN_004afef0.c`, `FUN_004b1250.c`,
`local/source/split-merged/code/0x050000/FUN_0052f030.c`,
`FUN_005428b0.c`, `FUN_00519f30.c`, `FUN_0051dd20.c`; direct EN/CH PE
vtable words at `0x7AB59C`, `0x7ABA38`, `0x7B5EB4`, `0x7B6114`, `0x7B6374`,
`0x7ACEDC`, `0x7AD140`, `0x7AD3A4`, `0x7AD878`; and the focused test above.

**Evidence class:** **confirmed** for wrapper dispatch, direct caller set,
vtable slot, class-to-target mapping, generic false stub, and EN/CH byte
identity; **unknown** for archive class specialization, registry ownership,
route/collision, provider coverage, and Qin settlement.

## 2026-09-04 Explicit `Creating` assigns the object-vector slot to `+0xB4`

The common creation entry has one additional registry-index fact that must be
kept separate from archive rehydration.  `FUN_00413B40 @ 0x413B40` returns the
pointer-table entry at `base + slot * 4` (after the source's capacity check).
In `Creating_pctd_type_pctd @ 0x42D540`, after that entry is replaced with the
new object returned by `FUN_0042D360`, the source writes the same selected slot
to the object's dword at `+0xB4` before invoking vtable `+0x94`.  This is a
confirmed explicit-creation assignment, not a provider-specific semantic.

Native records the boundary as
`OriginalMapLoadRehydrationChain.creationRegistryFieldOffset` and its source
address, with regression coverage in
`testQinMapLoadRehydrationChainMatchesCanonicalCallOrder`.  It does not copy
this value from the generic Qin archive tail: the authored generic rows carry
`-1`, and the recovered map/post-load path still does not send their model `0`
through `Creating`.  Consequently the provider registry, indirect archive
specialization, route, and house settlement remain **unknown** and Qin stays
fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/Creating_pctd_type_pctd.c`,
`FUN_00413B40.c`, `local/source/compare-report.tsv` rows `0x42D540` and
`0x413B40`, canonical EN/CH instruction sequence at `0x42D72E…0x42D736`,
`Sources/EmperorCore/GenericBuildingArchiveCatalog.swift`, and the focused
regression above.

**Evidence class:** **confirmed** for pointer-table slot arithmetic and the
`+0xB4 = slot` write in the explicit creation path; **unknown** for whether
any Qin archive/provider row reaches that path and for provider registry,
route, coverage, and settlement projection.

## 2026-09-04 Generic archive insertion is append-only and does not assign the provider slot

The generic object-loader edge is now bounded one step below the class
callback.  `FUN_0042D790 @ 0x42D790` passes the address of its decoded local
object pointer to `FUN_0042B590 @ 0x42B590`; that helper reads the current
object-vector end with `FUN_004F8200 @ 0x4F8200` and delegates to
`FUN_005F01F0 @ 0x5F01F0`.  The helper calls `FUN_005C1670 @ 0x5C1670` with
that end pointer as insertion position and count `1`, so each decoded object
is appended in stream order.  The three insertion bodies contain no write to
object `+0xB4`; the generic archive's `-1` tail is therefore not replaced by
the stream ordinal during this load step.

Native records the addresses and append/no-write flags in
`OriginalMapArchiveRuntimeClassCatalog`, with regression coverage in
`testMapArchiveRuntimeClassDispatchMatchesMFCReaderBoundary`.  This is a
confirmed separation between archive stream order and the explicit
`Creating(...)` registry-index write at `+0xB4`; it does not recover a later
archive specialization or provider registration edge.  Provider registry,
route/collision, coverage, and settlement remain **unknown**, so Qin stays
fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042d790.c`,
`FUN_0042b590.c`, `FUN_004f8200.c`,
`local/source/split-merged/code/0x050000/FUN_005f01f0.c`,
`FUN_005c1670.c`, canonical EN/CH instruction slice
`0x42D8E7…0x42D91A`, and
`Sources/EmperorCore/MapArchiveClassCatalog.swift`.

**Evidence class:** **confirmed** for append-at-end, one-element insertion,
and the no-`+0xB4` assignment in this chain; **unknown** for any later
indirect specialization and provider registry projection.

## 2026-09-04 MFC reference tokens are separate from the Qin provider slot

The archive-reference writer was traced one level beyond the generic object
append. `FUN_0042DC60 @ 0x42DC60` forwards each already-resolved object to
`FUN_0077FD11 @ 0x77FD11`. For a new reference, that writer stores a token from
the archive object's own `+0x30` counter into the MFC reference table and
increments that counter; existing references only emit the previously stored
token. Its body reads the object vtable/reference bookkeeping, not the
Building model word `+0x14` or provider registry slot `+0xB4`. EN/CH comparison
rows for both addresses are `identical`.

This closes another identity confusion: an MFC token (or the stream ordinal
used to append an object) cannot be reused as the missing Qin provider index.
The object's separate serializer may still write its raw fields, but no
provider specialization, registry insertion, route, coverage, or settlement
edge is present in this reference-token chain. Native records the token writer,
bridge, counter offset, and no-model/no-provider-read flags in
`OriginalMapArchiveRuntimeClassCatalog`; it does not synthesize live providers
from archive references. Indirect class-factory or post-load specialization
remains **unknown**, so Qin stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_0042dc60.c`,
`local/source/split-merged/code/0x070000/FUN_0077fd11.c`,
`FUN_0077b9ea.c`, `FUN_0077fcfd.c`, `FUN_0077ff37.c`,
`local/source/compare-report.tsv` rows `0x42dc60` and `0x77fd11`, and
`Sources/EmperorCore/MapArchiveClassCatalog.swift` with
`testMapArchiveRuntimeClassDispatchMatchesMFCReaderBoundary`.

**Evidence class:** **confirmed** for MFC token allocation/counter ownership,
the map bridge, no direct model/provider-field reads, and EN/CH parity;
**unknown** for any separate indirect specialization and provider-registry
projection.

## 2026-09-04 `DAT_00FC3750` sanitation is a 228×228 object-index pass, not provider registration

The object-grid cleanup at `FUN_0053D630 @ 0x53D630` is now bounded at the
field and extent level.  Its `short *` walk starts at `DAT_00FC3750` and stops
before `DAT_00FDCD70`; the byte span is `0x19620`, exactly `51984 = 228×228`
16-bit cells.  For each entry the body rejects zero and negative signed-short
IDs, then compares the positive ID strictly below the live object-vector
count returned by `FUN_00554C00 @ 0x554C00` (`(end - begin) >> 2`).  Only an
in-range ID whose `FUN_0047F1B0 @ 0x47F1B0` target has a non-zero model word at
`+0x14` is retained; every other entry is written back as zero.  The pass
then refreshes map/grid display state.  It never constructs a model, writes
provider slot `+0xB4`, or assigns a parent/object link.

This is a confirmed negative for treating the map grid itself as the missing
Qin Well/Herbalist/Acupuncture registry.  It proves that `DAT_00FC3750` is a
stale-object-index cache with strict live-vector/model validity, not a
provider-slot table.  Native records the addresses, cell count, field offset,
and predicate in `OriginalMapObjectRegistrySanitization`; the pure predicate
is covered by `testQinMapObjectRegistrySanitizationKeepsOnlyLiveModeledIDs`.
No live Qin path consumes this helper.  The map-grid-to-object projection,
provider specialization, route, coverage, and settlement remain **unknown**,
so Qin stays fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0053d630.c`,
`local/source/split-merged/code/0x050000/FUN_00554c00.c`,
`local/source/split-merged/code/0x040000/FUN_0047f1b0.c`,
`local/source/compare-report.tsv` rows `0x53D630`, `0x554C00`, and
`0x47F1B0`, and `Sources/EmperorCore/MapArchiveClassCatalog.swift` with
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the grid extent, 16-bit storage, strict
ID/vector/model predicate, zeroing behavior, and EN/CH parity; **unknown** for
any separate table-driven projection or later provider registration.

## 2026-09-04 Well `+0x6F` callback caller is an eHIB command dispatcher

The direct-caller boundary for the Well-family byte writer was rechecked at
the PE level because `0x515800` is an omitted/interior function in the split
corpus.  The canonical EN and CH `.text` images each contain exactly one
relative `E8` call to `FUN_00511860 @ 0x511860`, at `0x515913`.  The enclosing
instruction slice starts at `0x515800`: it resolves a table entry from
`0x010BFB30 + objectIndex * 0x38`, reads command global `DAT_010C6F60`, and
dispatches the six values `100...105` through a jump table.  The branch at
`0x515911` calls `FUN_00511860`; therefore the callback is reached only when
the global command value is `0x69` (`0x69 - 100 = 5`).

The five adjacent branches push the string-table tokens `0x853F58`,
`0x853F48`, `0x853F2C`, `0x853F10`, and `0x853EF8`, respectively labelled
`Hit eHIB_Patrol`, `Hit eHIB_Halt`, `TBD: Hit eHIB_CallTroops`,
`Hit eHIB_CaptureAnimals`, and `TBD : Hit eHIB_Dismiss`.  The labels do not
assign a human-facing meaning to command `0x69`; they only identify this as
the eHIB command family.  The command handler then performs the same
selection/UI virtual calls as its neighbouring branches after a successful
`FUN_00511860` return.

This closes a previously omitted direct-caller detail but is a confirmed
negative for using the callback as a Qin monthly service producer or a map-load
hook.  The upstream controller-record producer, command meaning, callback
category, provider registry linkage, and downstream water settlement remain
**unknown**.  Native records the boundary in
`OriginalWaterProviderState.WellCommandStateTrigger` and explicitly keeps its
`isAutomaticSimulationProducer` flag false; no Qin simulation path invokes
`FUN_00511860` or promotes the resulting `+0x6F = 0x60` write into water
coverage.

**Sources:** canonical `Exe/ghidra/input/EmperorEN.exe` and
`EmperorCH.exe` PE slices `0x515800...0x515961`, the exact EN/CH direct-call
census for `0x511860`,
`local/source/split-merged/code/0x050000/FUN_00511860.c`,
`local/source/split-merged/code/0x050000/FUN_00511080.c`,
`local/source/split-merged/code/0x050000/FUN_00511710.c`,
`local/source/split-merged/strings-index.csv`, and
`local/source/compare-report.tsv`; implementation and regression are in
`Sources/EmperorCore/HousingEvolution.swift` and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the sole direct PE callsite,
command-global/jump-table structure, command value, string-family identity,
and EN/CH parity; **confirmed negative** for a monthly/map-load caller;
**unknown** for the command's semantic category, upstream record source,
provider projection, and settlement.

## 2026-09-04 Shared destination-selector table is six strategy objects, not a Qin provider bridge

The object-destination chooser used by the figure/update chain has a complete
six-slot dispatch boundary in the indexed corpus. `FUN_00521DF0 @ 0x521DF0`
obtains one global strategy object from `FUN_0051EB00 @ 0x51EB00`, invokes
that object's first vtable word as the candidate-admission callback, and
scans the active object vector. `FUN_00521C90 @ 0x521C90` retries by advancing
the selector and wrapping from `5` to `0`; `FUN_00521D20 @ 0x521D20` stores
the selected object coordinates/registry index for its caller. The direct
callers are `FUN_00522D30` (creation path), `FUN_00520080` (figure/update
path), and `FUN_005E8920` (state/update path), with the retry wrapper itself
also called from `FUN_00522D30`. EN/CH comparison rows for `0x51EB00`,
`0x521C90`, `0x521D20`, and `0x521DF0` are `identical`.

Direct PE reads of the six constructor thunks and their vtable first words
give this exact selector inventory (the default branch of `FUN_0051EB00` is
selector `0`):

| selector | global object | constructor | vtable | first admission callback |
| ---: | ---: | ---: | ---: | ---: |
| 0 | `0x010BFFB8` | `0x0051EA60` | `0x007B6AF8` | `0x0051FCE0` |
| 1 | `0x010BFFB4` | `0x0051EAA0` | `0x007B6B0C` | `0x0051F870` |
| 2 | `0x010BFFB0` | `0x0051EAE0` | `0x007B6B20` | `0x0051F690` |
| 3 | `0x010BFFBC` | `0x0051EA20` | `0x007B6AE4` | `0x0051F1A0` |
| 4 | `0x010BFFC0` | `0x0051E9E0` | `0x007B6AD0` | `0x0051EF80` |
| 5 | `0x010BFFC4` | `0x0051E990` | `0x007B6AA8` | `0x0051EBA0` |

The EN/CH constructor slice `0x51E990…0x51EAF1` hashes to
`7c38e155baaab55ff9ea0083c294e09ca9a96815b51c4701b97a81394622288f` in both
PEs; the vtable slice `0x7B6AA8…0x7B6B5F` hashes to
`c3c95fa9182bb344f41dd8add36bc27bc3b8e4baaa73bd37a0a86a90135d5cf8` in both.
These hashes are direct byte comparisons, while the semantic names of the
six strategy objects remain intentionally unset.

The split bodies for callbacks `0x51EBA0`, `0x51EF80`, `0x51F1A0`, and
`0x51FCE0` expose model switches and output ranges, but those switches are
strategy admission predicates, not a serialized provider identity. The other
three callback bodies are interior/omitted entries; their vtable targets are
still directly present in both hash-matched PE images. This table therefore
closes the selector/object/vtable/caller boundary only. It does not recover
which strategy is chosen for a Qin peddler, how the active object vector is
populated from a Qin archive, or how a selected object becomes a market
route, coverage write, or household settlement. Native records the table in
`OriginalMarketCatalog.destinationSelectorDescriptors` as research metadata
and keeps the Qin market bridge fail-closed.

**Sources:** `local/source/split-merged/code/0x050000/`
`FUN_0051eb00.c`, `FUN_00521df0.c`, `FUN_00521c90.c`, `FUN_00521d20.c`,
`FUN_00522d30.c`, `FUN_00520080.c`, `FUN_005e8920.c`,
`local/source/compare-report.tsv` rows `0x51EB00`, `0x521C90`, `0x521D20`,
`0x521DF0`, and direct EN/CH PE vtable/constructor slices around
`0x51E990…0x51EAEF` and `0x7B6AA8…0x7B6B20`.

**Evidence class:** **confirmed** for the six selector values, global-object
addresses, constructor/vtable assignments, first callback words, retry wrap,
caller chain, and EN/CH parity; **unknown** for strategy semantics,
archive/provider projection, route/collision behavior, and settlement.

## 2026-09-04 Destination-selector direct-call census excludes the archive loader

The six-slot table was checked again at the raw PE callsite level. Scanning
all relative `E8` instructions in both canonical images for
`FUN_00521DF0 @ 0x521DF0` gives the identical three-site set:
`0x521CBA` and `0x521CFB` inside `FUN_00521C90 @ 0x521C90`, plus
`0x521DDC` inside `FUN_00521D20 @ 0x521D20`. No direct call originates in the
archive/map-loader family (`FUN_0042D790` and its eleven indexed callers), and
the selector consumer has no direct `FUN_00521DF0` edge from the generic
Building insertion path. This is a direct-call negative only; an indirect
table or virtual edge is not ruled out.

Native records the three callsites in
`OriginalMarketCatalog.destinationSelectorDirectCallSites` and covers the
set with a pure regression. The result tightens the Qin blocker boundary:
the shared selector cannot be treated as a recovered map-load provider
registration hook. Strategy meaning, archive/provider projection, route and
collision behavior, and household settlement remain **unknown**, so the Qin
market bridge remains fail-closed.

**Sources:** canonical `Exe/ghidra/input/EmperorEN.exe` and `EmperorCH.exe`
(complete relative-`E8` census, image base `0x00400000`),
`local/source/split-merged/code/0x050000/FUN_00521df0.c`,
`FUN_00521c90.c`, `FUN_00521d20.c`, `FUN_00521eb00.c`,
`local/source/split-merged/functions-index.csv`, and
`Sources/EmperorCore/MarketSimulation.swift` with
`testOriginalDestinationSelectorDirectCallsitesExcludeMapLoaders`.

**Evidence class:** **confirmed** for the three direct callsites, caller
identity, EN/CH parity, and the absence of a direct archive-loader edge;
**unknown** for indirect/table-driven dispatch, strategy semantics,
provider projection, route, and settlement.

## 2026-09-04 Qin routing census: Iron Smelter and Ruin +0xCC predicates

The first supported-producer experiment exposed a concrete cache boundary,
`missingGenericFootprintPredicate(..., buildingID: 40)`, before any house
perimeter or migration arithmetic ran. Static tracing closes the two
Qin-relevant missing classes without generalizing an unknown default.

For authored building IDs `39...41`, the object factory path is exact in both
executables: `FUN_00559010 @ 0x559010` accepts only `0x24` (36),
`FUN_0042DD60 @ 0x42DD60` accepts only `0x30` (48), and
`FUN_00558570 @ 0x558570` accepts `0x27...0x29` (39, 40, 41).
That branch allocates `0x150` bytes and calls `FUN_005590A0 @ 0x5590A0`,
which calls `FUN_00558F70 @ 0x558F70` and installs vtable `0x007B7E24`.
Direct little-endian reads of the canonical EN and CH PE images at
`0x007B7E24 + 0xCC` return `0x00416A50` in both builds. The target body is
the already recovered two-argument constant-false callback
(`xor al, al; ret 8`). These rows therefore take the `+0xCC == false`
branch: primary occupied cells are class `2`, and generic fallback cells are
class `4` (subject to their separate explicit building-ID branches).

The archived Qin map also carries building ID `161` (Ruin). Its generic object
factory classification is direct: `FUN_005188B0 @ 0x5188B0`,
`FUN_0051C620 @ 0x51C620`, `FUN_00562E80 @ 0x562E80`,
`FUN_00562E90 @ 0x562E90`, and the special-class predicates in
`FUN_0051C660 @ 0x51C660` reject `0xA1`; `FUN_00426C90 @ 0x426C90` therefore
constructs the base object and installs vtable `0x007AB59C`.
Direct EN/CH PE reads of `0x007AB59C + 0xCC` again return `0x00416A50`.
The map's Ruin occupancy consequently has the same confirmed constant-false
predicate and is safe to project as class `2`/`4`.

The EN/CH comparison report marks all selector/constructor functions above
(`0x426C90`, `0x42DD60`, `0x558570`, `0x558F70`, `0x559010`, `0x5590A0`)
`identical`; vtable words and the callback body were read directly from both
hash-matched PE files. Native now includes IDs `39`, `40`, `41`, and `161` in
`BuildingFootprintPredicateCatalog.constantFalseBuildingIDs`, with a pure
regression that preserves `nil` for an unrelated unsupported ID.

This closes the first observed routing-cache error only. It does **not** prove
the unresolved map-object projection, `FUN_004BA6F0` house perimeter object
callbacks, road-component derivation, or the migration arrival writer; the Qin
automatic-migration producer remains fail-closed until those boundaries are
recovered.

**Sources:** `local/source/split-merged/code/0x050000/`
`FUN_00559010.c`, `FUN_0042DD60.c`, `FUN_00558570.c`, `FUN_005590A0.c`,
`FUN_00558F70.c`, `FUN_005188B0.c`, `FUN_0051C620.c`, `FUN_00562E80.c`,
`FUN_00562E90.c`, `FUN_0051C660.c`; `local/source/split-merged/code/0x040000/`
`FUN_00426C90.c`; `local/source/compare-report.tsv`; direct reads from
`Exe/ghidra/input/EmperorEN.exe` and `EmperorCH.exe` at vtable slots
`0x7B7EF0` and `0x7AB668`.

**Evidence class:** **confirmed** for the factory predicates, constructor/vtable
assignments, `+0xCC` target, callback body, EN/CH parity, and routing output
classes; **unknown** for all remaining object/grid and migration-writer
semantics listed above.

## 2026-09-04 House-perimeter object callbacks are shared, with one auxiliary-layer input

`FUN_004BA6F0 @ 0x4BA6F0` and its collector sibling
`FUN_004BA870 @ 0x4BA870` do not reject every perimeter cell carrying source
bit `0x8`. They load the live object ID from `DAT_00FC3750[cell]`, resolve the
object vtable, and then apply three virtual callbacks before reusing the same
road/terrain admission test. Direct EN/CH PE reads show the canonical base,
HouseBldg, Qin production (`39...41`), warehouse `54`, Well `72`, and
Inspector `124` vtables all share these entries:

| slot | target | recovered body | effect in `FUN_004BA6F0` |
| ---: | ---: | --- | --- |
| `+0xE4` | `0x00416A60` | `xor eax,eax; cmp word [ecx+0x14],0x7e; sete al; ret` | reject only object type `0x7E` (Road Block) |
| `+0x190` | `0x00426D30` | returns true only for object types `0x6F`/`0x71` (Grand/Imperial Way) | enables the directional-offset adjustment branch |
| `+0x194` | `0x00426D50` | returns its input unchanged except for types `0x6F`/`0x71`, which call `0x420EB0` | adjusts a Way cell using the auxiliary direction byte |

`FUN_00420EB0 @ 0x420EB0` is exact: if `DAT_00F6A9E0[cell]` lacks bit
`0x40`, it reads `DAT_00FDCD70[cell]`; low bits `1`/other move one column,
and direction groups `0x08`/otherwise move one row, while bit `0x40` leaves
the index unchanged. The callbacks and their callers are identical in the
English and Chinese builds (`compare-report.tsv` rows `0x4BA6F0`,
`0x4BA870`, `0x426D50`; the two omitted callback bodies are verified by direct
PE bytes). This closes the callback control flow and the ordinary-object
identity/no-adjustment case; the Way adjustment still depends on the authored
or runtime `DAT_00FDCD70` layer and a complete `DAT_00FC3750` object registry.

Native intentionally does not yet reinterpret every raw `0x8` perimeter cell
as passable. The missing registry ownership and object-to-building/model
projection are still required to know which object callback applies at each
cell; treating `0x8` as globally clear would admit Road Blocks and would be
incorrect. The temporary Qin1 supported-producer probe, after the confirmed
`39...41`/`161` `+0xCC` rows were added, produced `grandCanalWorkerRoutingGrids`
success and completed its Native mission fixture (population `161`; 8/24
houses received access words, 17/24 received capacity words). This is a
Native diagnostic only, not evidence that the original automatic producer or
arrival writer is complete, so production remains fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004BA6F0.c`,
`FUN_004BA870.c`, `FUN_00420EB0.c`, `FUN_00426D50.c`, direct EN/CH vtable
words at `0x7AB680`, `0x7ABB1C`, `0x7B7F08`, `0x7BE2A0`, `0x7B5F98`, and
`0x7B61F8`, plus `local/source/compare-report.tsv`.

**Evidence class:** **confirmed** for callback targets, type tests, ordinary
object no-adjustment behavior, Way adjustment formula, and EN/CH parity;
**diagnostic/inferred** for the Native probe result; **unknown** for object
registry ownership, per-cell object projection, and the remaining migration
writer/arrival semantics.

## 2026-09-04 Narrow Native perimeter projection for confirmed ordinary objects

The callback closure above permits a limited Native improvement without
pretending that `DAT_00FC3750` has been recovered. `CitySimulation` now keeps a
per-cell set of authored building IDs while refreshing house access. A
perimeter cell occupied by exactly one directly catalogued ordinary class
(`3...17`, `39...41`, `54`, `72`, `124`, or `161`) is allowed to continue to
the source terrain-bit test, matching the confirmed `+0xE4`/`+0x190` ordinary
callback path. Overlaps, unknown classes, Road Block `126`, post-secondary
classes, and Grand/Imperial Way `111/113` remain rejected. The old blanket
`occupiedBuildingPoints` rejection is therefore removed only for this explicit
set; no global `0x8` admission or inferred model registry is introduced.

The pure `HouseAccessPerimeterObjectCatalog` regression asserts the positive
set, Road Block rejection, and unresolved Way/City Gate nil cases. With the
temporary supported-producer switch, the same Qin1 replay still completes; the
switch and all diagnostics were removed afterward. This verifies that the
narrow projection does not regress the fixture, but it remains Native-only
diagnostic evidence and does not authorize enabling the original automatic
migration producer.

**Evidence class:** **confirmed** for the selected building-ID callback cases
and fail-closed decisions; **diagnostic** for replay completion; **unknown** for
the runtime object-registry owner, unlisted class/model mapping, Way auxiliary
layer, and arrival writer.

## 2026-09-04 Serialized `DAT_00FDCD70` is preserved for Way offset replay

The serializer order in `FUN_0052E7C0 @ 0x52E7C0` places the byte grid
`DAT_00FDCD70` immediately after the image-word grid and before terrain
`DAT_00F6A9E0`, with extent `0xCB10 = 228×228`. `EmperorMap.edgeValues` is
already parsed from exactly that physical position (`edgeGridOffset`), so this
is a direct identity rather than a name-based inference. The mission-sized
Native terrain projection now preserves that layer as optional
`roadDirectionRawValues` and exposes `roadDirection(at:)`; old saves and
synthetic terrains without the layer remain decodable and return `nil`.

For an occupied Grand/Imperial Way perimeter cell (`111`/`113`), Native now
mirrors `FUN_00426D50`/`FUN_00420EB0`: when the cell lacks road bit `0x40`, a
non-zero low direction (`1` moves one column forward; any other non-zero low
value moves one column backward) wins first; otherwise direction group `0x08`
moves one row forward and all other groups one row backward. The adjusted cell
must remain in bounds and pass the source road-bit `0x40` / blocked-bit `0x04`
test. If the serialized direction layer is absent, the Way candidate is still
rejected. Ordinary objects keep the previously recovered no-adjustment path;
dynamic writes to `DAT_00FDCD70` and the complete object registry remain outside
this contract.

The focused regression verifies mission-array validation and exact byte access.
This closes the authored direction-layer input and Way adjustment arithmetic,
but does not claim that all Qin map objects are registered or that automatic
migration is ready to enable.

**Sources:** `local/source/split-merged/code/0x050000/FUN_0052E7C0.c`,
`local/source/split-merged/code/0x040000/FUN_00420EB0.c`,
`FUN_00426D50.c`, `local/source/compare-report.tsv`,
`Sources/EmperorCore/EmperorMap.swift`,
`Sources/EmperorCore/DeterministicTerrainState.swift`, and the focused
`GrandCanalSimulationTests` regression.

**Evidence class:** **confirmed** for serialized layer identity, extent/order,
byte-access behavior, callback arithmetic, and fail-closed absence handling;
**unknown** for dynamic layer mutation, object-registry ownership, and the
remaining migration arrival writer.

## 2026-09-04 `DAT_00FDCD70` dynamic-writer census leaves Way direction production open

The indexed corpus and both canonical PE images were searched for every
reference to the serialized direction layer `DAT_00FDCD70`.  The recovered
writers separate into three classes:

* Geometry placement helpers (`FUN_004B72B0`, `FUN_004B84B0`, and the sibling
  `FUN_004B87E0`) copy the low six bits from the fixed footprint-offset table
  `DAT_0081FF1C` and optionally add bit `0x40` to the terminal cell.  Their
  callers are building/terrain placement and repair routines; none is called
  by the generic map-record insertion path `FUN_0042D790`, whose load callback
  is `FUN_004271B0`.
* The only recovered full-byte generator writes are in `FUN_00421ED0 @
  0x421ED0`, whose vtable is `CBGRand` (`0x007AB42C`, RTTI
  `.?AVCBGRand@@`).  Its four explicit cases emit `0x42`, `0x50`, `0xC2`, and
  `0xD0` while creating random/generated map objects.  A complete relative-
  `E8` scan of both canonical PEs finds no direct caller of `0x421ED0`; the
  edge is virtual/table-driven and is not a Qin archive-load hook in the
  recovered map chain.  The EN/CH function row is `identical`.
* All other recovered stores in the inspected Qin-relevant paths are flag
  maintenance: terrain/repair passes set
  or preserve `0x40` (`FUN_004B2D00`, `FUN_004B67B0`, `FUN_004B8B80`,
  `FUN_004EDC30`, `FUN_005251D0`, `FUN_0053EE00`, `FUN_0053F240`,
  `FUN_0053F840`, and related helpers), while `FUN_004B5290` toggles only
  `0x80`.  None introduces a new low-direction value; serializer functions
  only copy/clear the 228×228 byte array.

This is a confirmed negative for treating a generic post-load callback or a
road-bit refresh as the missing Way-direction producer.  It also narrows the
remaining dynamic question: a virtual/table-driven `CBGRand` edge or an
unindexed editor/runtime path could still mutate the layer, but no such edge
is established for Qin map loading.  Native therefore keeps the authored
`roadDirectionRawValues` optional and rejects Way perimeter candidates when
that layer is absent; it must not synthesize direction bytes from current
road bits.  Provider/object registry projection and the immigrant arrival
writer remain unresolved, so automatic migration stays fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00421ED0.c`,
`FUN_004B72B0.c`, `FUN_004B84B0.c`, `FUN_004B87E0.c`, `FUN_004B8B80.c`,
`FUN_004B5290.c`, `FUN_004B67B0.c`, `FUN_004B2D00.c`, `FUN_004EDC30.c`,
`local/source/split-merged/code/0x050000/FUN_0052E7C0.c`,
`FUN_0053EE00.c`, `FUN_0053F240.c`, `FUN_0053F840.c`,
`FUN_005251D0.c`, `local/source/compare-report.tsv` row `0x421ED0`, and
direct EN/CH relative-call/vtable scans around `0x421ED0` and
`0x007AB42C`.

**Evidence class:** **confirmed** for the enumerated writer classes,
fixed-byte values, serializer/placement separation, and EN/CH parity;
**unknown** for any indirect `CBGRand` caller, editor-only mutation, complete
object registry, and downstream migration/arrival semantics.

## 2026-09-04 Well provider state scheduler has one calendar entry

The canonical English and Chinese PE `.text` sections were scanned with a
relative-`E8` decoder using image base `0x00400000`.  `FUN_00517AD0 @
0x00517AD0` has exactly one direct call in each image: call site `0x004AC473`,
from `FUN_004AC2B0 @ 0x004AC2B0`.  The call bytes and target are identical in
both variants.  In the caller's calendar-phase switch, case `0x24` invokes
`FUN_005177B0` and then `FUN_00517AD0`, after which the phase advances; no
second direct `E8` caller was found.

`FUN_00517AD0` is a provider-state update boundary, not a house-coverage
writer.  It walks the live provider vector through `FUN_004F8210` /
`FUN_00554C00`, first requiring the global gate at `FUN_00426D10(0)` and each
provider's virtual eligibility slot `+0xB8`, then dispatching the provider
update slot `+0x218`.  The separate Well coverage path remains virtual
dispatch at provider slot `+0x2C` into `FUN_0051BC00`; that function has no
direct relative call sites in either image.

Negative result: no direct map-load, monthly-popularity, migration-assignment,
or generic water-visit entry reaches this scheduler.  Indirect/table-driven
edges, the provider object-vector projection, writers for the Well predicate
inputs (`+0x16` / `+0x6F`), and downstream house settlement remain unknown.
Native therefore records the calendar boundary but keeps the Qin provider
registry and water bridge fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004AC2B0.c`,
`local/source/split-merged/code/0x050000/FUN_00517AD0.c`, the EN/CH rows for
`0x4AC2B0` and `0x517AD0` in `local/source/compare-report.tsv`, canonical PE
relative-call scans, `Sources/EmperorCore/HousingEvolution.swift`, and
`testOriginalWaterProviderSchedulerBoundaryMatchesCanonicalCallCensus`.

**Evidence class:** **confirmed** for the sole direct call site, phase/order,
global and virtual-slot gates, and EN/CH parity; **confirmed negative** for a
second direct `E8` caller; **unknown** for indirect dispatch, object-vector
projection, predicate-input writers, and house settlement.

## 2026-09-04 Qin-3 player-flow diagnostic separates construction gating from migration

The Qin-3 player-command test was run once with its explicit skip gate removed
and once with both Music School placements made optional.  This was a
temporary diagnostic only; the test skip and required placements were restored
afterward, and no diagnostic switch was committed.  With the original required
placement, the flow stops before simulation because campaign construction
rejects building `211` (Music School).  That rejection is deliberate in
`CitySimulation.isBuildingAvailableInCampaign`: the campaign bridge excludes
models `211…213` while their provider registry, venue route/collision, and
coverage/settlement contracts remain unrecovered.

With Music School construction omitted, the same player-command sequence runs
through the full 120-month diagnostic.  The recorded terminal state is
`population=0`, `water=0`, food quality `0`, `buyers=0`, `peddlers=0`, and
`level6=0`; the migration state remains
`.unsupportedOriginalProducer`.  The trace starts with 40 houses and
`reach=27/40`, then loses houses and eventually its mill and jade workshop as
the resident/production systems have no population to staff them.  This is a
Native diagnostic, not evidence of original executable values, but it
establishes that the current observed failure occurs before any entertainment
figure FSM or peddler settlement can be evaluated.

The source-backed cause remains the same: the original generic archive rows
carry no live provider projection, while the actual migration producer and
arrival writer are still fail-closed.  The diagnostic therefore must not be
“fixed” by changing the Qin-3 layout, forcing Music School placement, or
inventing residents/worker counts.  The next required evidence is the
archive/object-vector projection and the source-backed migration producer
inputs; until then the skip is the faithful result.

**Sources:** `Tests/EmperorGameplayTests/Qin3PlayerPlaythroughTests.swift`
(temporary diagnostic run, restored afterward),
`Sources/EmperorCore/HousingEvolution.swift`
(`campaignConstructionUnsupportedBuildingIDs`),
`Sources/EmperorCore/CitySimulation.swift`
(`isBuildingAvailableInCampaign` and fail-closed migration branch),
`local/source/split-merged/code/0x040000/FUN_0042D360.c`,
`FUN_0051C660.c`, and the 120-month test stderr trajectory.

**Evidence class:** **confirmed** for the Native campaign gate and recorded
diagnostic output; **source-backed/confirmed** for the entertainment provider
factory dispatch; **unknown** for the original archive-to-provider projection,
migration input producer, route, and settlement.

## 2026-09-04 Supported-producer diagnostic isolates downstream Qin-3 blockers

To separate the unrecovered original migration producer from downstream
settlement, a second reversible Native-only diagnostic was run.  The test
temporarily set the existing availability enum to
`.supportedOriginalProducer`, set migration popularity to `60`, omitted the
two campaign-rejected Music School placements, and then restored the test and
removed the temporary controller hook.  No diagnostic switch is committed.

The 120-month player-command run reached `343` population early in the trace,
with `40` houses and `231` water; the early housing reach was `27/40`.
Population then plateaued and declined, ending at `203` with `24` houses, `119` water, and
housing reach `14/24`.  Buyers and peddlers stayed at `0`, food quality stayed
at `0`, and no level-6 house was reached.  The terminal goal snapshot was
population `203/1800`, level-6 housing `0/1000`, lacquer `1200/1600`, and jade
`1200/1200`; the remaining unmet checks were food quality (`0` versus `20`)
and water service (`12` houses).  This is a controlled Native diagnostic, not
an original-executable value claim, but it demonstrates that the current
supported-producer path can enter the Qin map and that the next observable
failure is downstream water/food-market settlement rather than the migration
availability enum itself.

The result does not authorize a layout change, forced provider placement, fake
residents, or a guessed peddler rule.  Source-first work is still required for
the provider/object-vector projection, Well predicate inputs and coverage
writer, food-quality inputs, and market/peddler settlement before Qin-3 can be
unskipped.

**Sources:** `Tests/EmperorGameplayTests/Qin3PlayerPlaythroughTests.swift`
(temporary diagnostic run, restored afterward), the temporary
`GameSessionController` diagnostic hook (removed afterward), the captured
120-month stderr trajectory, `Sources/EmperorCore/CitySimulation.swift`,
`Sources/EmperorCore/HousingEvolution.swift`, and the original-source
contracts recorded in `FUN_0051BC00.c`, `FUN_00517AD0.c`, and
`migration-popularity-producer.md`.

**Evidence class:** **confirmed** for the Native diagnostic setup and recorded
terminal trajectory; **unknown** for the original producer, provider
projection, water/food settlement ordering, and peddler algorithm.

## 2026-09-04 Provider `+0x200` callbacks expose fixed output envelopes, not registration

The previous revision of this section called the slot `+0x1FC`; that was an
offset error and is corrected here. Direct vtable-word reads show that the
provider `+0x1FC` slot is `FUN_0051CC10` (the existing auxiliary refresh), while
the fixed-output callbacks below are in the adjacent `+0x200` slot. The
`+0x200` targets in the canonical English executable are Well `0x51BB60`,
Herbalist `0x51BCD0`, Acupuncture `0x51BDE0`, Music School `0x48B030`, Acrobat
School `0x48B1E0`, and Drama School `0x48B3D0`. The corresponding 76-byte (the
first three) or 106-byte (the last three) code slices at the same addresses
are byte-for-byte identical in the Chinese executable; this was checked
directly against `Exe/ghidra/input/EmperorEN.exe` and
`Exe/ghidra/input/EmperorCH.exe`.

The first three callbacks unconditionally write three caller-provided output
words and return `1`:

| provider | output word 0 | output word 1 | output word 2 |
| --- | ---: | ---: | ---: |
| Well | `0x4C55` | `4` | `100` |
| Herbalist | `0x4C1E` | `4` | `88` |
| Acupuncture | `0x4C03` | `4` | `80` |

The school callbacks branch on their object word at `+0x2E`, then write the
following fixed envelopes and return `1`:

| provider | `word +0x2E != 0` | `word +0x2E == 0` |
| --- | --- | --- |
| Music School | `0x4C67, 4, 100` | `0x4C69, 0, 100` |
| Acrobat School | `0x4C94, 4, 80` | `0x4C96, 0, 80` |
| Drama School | `0x4C6B, 4, 100` | `0x4C6D, 0, 100` |

These bytes establish the targets, output order, constants, return value, and
the school branch input. They do **not** establish the semantic names of the
three output words: neither `0x4Cxx` nor the values `4/0`, `80/88/100` may be
treated as a capacity, quality, figure ID, coverage radius, or provider-slot
index without a caller that consumes them. The callbacks also do not write the
object `+0xB4` provider index, the global object vector, map cells, or
`cHouseInfo`.

The indexed consumers are separate from the load-time `+0x1FC` refresh.
Calendar dispatcher case `0x27` calls `FUN_00519120.c`, which iterates its
source object vector and invokes each object's vtable `+0x200`. The generic
object update path `FUN_0051d4a0.c` delegates to `FUN_0051d560.c`; the latter
invokes the same slot with three local output addresses and, on success, feeds
the returned values into subsequent resource/notification calculations. The
raw callsite at `0x51D73C` confirms the three pointer arguments. The provider
load overrides `FUN_0051CB80.c` and `FUN_0051CAD0.c`
still allocate `0x20` bytes, construct the auxiliary object through
`FUN_00526830.c`, store it at provider `+0x14C`, and invoke `+0x1FC`
(`FUN_0051CC10`), not `+0x200`; `FUN_00418D90.c` refreshes that existing
auxiliary object on a later pass. Thus this callback family is a fixed
descriptor/notification surface, not evidence that the Qin archive rows have
been projected into live provider objects. The provider projection, registry
bridge, and downstream migration/coverage/settlement consumers remain unknown
and Native remains fail-closed.

**Sources:** canonical English executable SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
executable SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, direct
PE slices at the addresses above, `local/source/split-merged/code/0x050000/`
`FUN_0051cb80.c`, `FUN_0051cad0.c`, the direct PE body at
`FUN_0051CC10 @ 0x51CC10`, `FUN_004AC2B0.c`, `FUN_00519120.c`,
`FUN_0051d4a0.c`, `FUN_0051d560.c`, `FUN_00526830.c`, and
`local/source/split-merged/code/0x040000/FUN_00418D90.c`; provider vtable words
and `local/source/compare-report.tsv` (the shared auxiliary constructor at
`0x526830` is marked `identical`).

**Evidence class:** **confirmed** for the corrected `+0x200` targets, the
`+0x1FC → FUN_0051CC10` distinction, EN/CH byte parity, constants, branch
input, return value, and indexed callsites; **unknown** for the three
output-word semantics, provider registration/projection, and any Qin migration
or settlement effect.

## 2026-09-05 Provider `+0x230` census separates Well, Herbalist, and Acupuncture

The provider vtable census was extended from the shared spawn slot `+0x234`
to the threshold slot `+0x230`. Direct little-endian reads of the canonical
English and Chinese PE `.rdata` words are byte-identical and produce this
mapping:

| provider model(s) | vtable | `+0x230` target | raw method slice SHA-256 (EN = CH) | extra raw input |
| ---: | ---: | ---: | --- | --- |
| 72/73 Well | `0x007B5EB4` | `0x0051BAE0` | `db017f30d81a2c977d1e2f9ce9f45292a93ce245c4bc17854ef3f1447ba2d05b` (95 bytes) | calls provider `+0x224`; non-zero doubles input |
| 207 Herbalist | `0x007B6114` | `0x00507E40` | `aeeceba2acf86e445d34631ec3c8c6b35dea1eb22fcaac09fc91588599b7f680` (77 bytes) | none in method slice |
| 208 Acupuncture | `0x007B6374` | `0x0051CF40` | `4fd8ba43f29e3b45cb041805bbf61a3efc50befe9093bfa9d53b60f470ae003c` (76 bytes) | none in method slice |
| 211 Music | `0x007ACEDC` | `0x005AB330` | `9df2164bb7ae0ee6aa407cf410edf6087d7d02eb83e94ab945b4f6dcd7603d68` (76 bytes) | none in method slice |
| 212 Acrobat | `0x007AD140` | `0x005AB330` | same as Music | none in method slice |
| 213 Drama | `0x007AD3A4` | `0x0048B380` | `3ac2b12d8c9799e9c5e10131b6261ab287181d9428a451de342af4823d87747e` (76 bytes) | none in method slice |

The direct method bodies are threshold selectors over the worker input. Well
and Herbalist return the `1/3/5/10/15` non-zero bands; Acupuncture returns
`1/3/7/15/29`; Music/Acrobat return `3/6/12/24/32`; Drama returns
`6/12/24/32/48`. As with the existing strict `counter > threshold` contract,
the zero-worker branch is not a reachable spawn path because `FUN_0051CF90`
rejects non-positive workers before advancing its counter. The Well callback
result is preserved as an explicit input; its predicate meaning is not
recovered.

This corrects the earlier Native grouping that treated Well, Herbalist, and
Acupuncture as all using `0x51CF40`. Native now records the six vtable rows in
`OriginalResidentialServiceCatalog.providerVTableSlot230Descriptors` and
uses the Well-specific threshold row only when the unresolved `+0x224` result
is supplied. No provider registry, map-object projection, route/collision,
coverage writer, figure allocation, or house settlement is enabled by this
metadata; Qin playthrough gates therefore remain fail-closed.

**Sources:** canonical English PE SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
PE SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, direct
`.rdata` vtable reads and `.text` slices at the five unique targets,
`local/source/split-merged/code/0x050000/FUN_0051cf90.c`,
`docs/exe-research/residential-service-roamer-lifecycle.md` §§4.1–4.3,
`Sources/EmperorCore/HousingEvolution.swift`, and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for all six `+0x230` target words, method
slice parity, threshold rows, and the Well `+0x224` call/doubling branch;
**unknown** for the callback's semantic state, provider registration and
archive projection, routing, coverage, and settlement.

## 2026-09-05 `FUN_005B4BD0` `+0xB4` writes are population-statistics state, not provider registry

The remaining broad `+0xB4` store scan contains a misleading candidate at
`FUN_005B4BD0 @ 0x5B4BD0`. The canonical English and Chinese bodies are
`identical` in `local/source/compare-report.tsv`, but the function is a
`__thiscall`: its object arrives in `ECX`, while the stack argument is the
mode byte. The direct PE body first copies a 64-dword scratch record into
`this + 0x30`, clears twelve dwords at `this + 0xB4`, and, for an object-vector
entry whose category word is zero, calls `FUN_00517CC0` and stores its return
value at `this + 0xB4`.

All four direct relative calls in both hash-matched PEs load the same object
address `0x013F7F50` into `ECX` immediately before the call:

| call site | caller | stack mode | `ECX` before call |
| ---: | --- | ---: | ---: |
| `0x44B3BA` | `FUN_0044B2A0` | `0` | `0x013F7F50` |
| `0x4FF0A6` | `FUN_004FF020` | `0` | `0x013F7F50` |
| `0x55B7F6` | `FUN_0055B6A0` | `0` | `0x013F7F50` |
| `0x55D081` | `FUN_0055CEE0` | caller-held `EBX` | `0x013F7F50` |

The call-site bytes and addresses are the same in EN and CH. `FUN_00517CC0`
is not a provider constructor: it refreshes the object-vector population
aggregate through `FUN_00517DE0`, whose confirmed filters invoke existing
objects' `+0xB8` and `+0x204` callbacks and write totals to the aggregate
object. The surrounding `FUN_005B4BD0` fields (`+0xC0/+0xC4/+0xC8/+0xCC/…`)
are likewise category/population statistics, and its callers are campaign
summary, game-state, and goal/result paths. No call edge from this method
reaches `FUN_0051C660`, `FUN_0051BEF0`, a provider vtable, or an object-list
insertion routine.

Therefore the `FUN_005B4BD0` `+0xB4` store is a **confirmed negative** for
the Well/Herbalist/Acupuncture/entertainment provider registry index. It must
not be used to derive provider `+0x2D`/`+0xB4` from a statistics-object field.
The actual provider-index producer and map/archive projection remain
**unknown**; Qin service projection and automatic migration stay fail-closed.

**Sources:** canonical English PE SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
PE SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`, direct
PE body/call-site disassembly for `0x5B4BD0`, `0x44B3BA`, `0x4FF0A6`,
`0x55B7F6`, and `0x55D081`, `local/source/split-merged/code/0x050000/`
`FUN_005b4bd0.c`, `FUN_00517cc0.c`, `FUN_00517de0.c`, callers
`FUN_0044b2a0.c`, `FUN_004ff020.c`, `FUN_0055b6a0.c`, `FUN_0055cee0.c`, and
`local/source/compare-report.tsv` row `0x5b4bd0`.

**Evidence class:** **confirmed** for the calling convention, shared
`0x013F7F50` object, four direct call sites, population-aggregate callee,
and negative provider-factory edge; **unknown** for the real provider-index
producer, archive projection, and final registry insertion order.

## 2026-09-05 cMarket peddler registration slot order is explicit

The peddler-link writer `FUN_004272A0 @ 0x4272A0` is now represented as a
side-effect-free slot selector. Its source order is exact: market type `1`
always targets market `+0x2E`; otherwise a primary link below `1` also targets
`+0x2E`. With a non-empty attached-info second link (`+0x6A`), a Grand Market
(type `3`) whose third link (`+0x6C`) is below `1` targets `+0x6C` before any
primary-figure activity check. If that check finds the primary figure
inactive, the writer targets `+0x2E`; a Grand Market with an inactive third
figure then targets `+0x6C`. Every remaining branch falls back to attached
info `+0x6A`. The writer's lookup of the second attached figure is not used
for a branch decision; its active/model/parent validation is a separate
`FUN_00429780` path.

`OriginalMarketPeddlerLinkStorage.registrationSlot` preserves this order and
the signed-short `< 1`/`> 0` polarity without resolving figures or mutating a
market. Focused regression coverage exercises type-1, empty-primary,
empty-third, inactive-primary, inactive-third, and final-fallback branches.
This closes only peddler-link storage selection. It does not populate the six
commodity records, create a route, project a provider registry, or write house
food quality; Qin campaign peddlers therefore remain fail-closed.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004272a0.c`,
`FUN_00429670.c`, `FUN_00429700.c`, `FUN_00429780.c`, `FUN_00429810.c`,
`local/source/compare-report.tsv` rows `0x4272a0`, `0x429670`, `0x429700`,
`0x429780`, and `0x429810`, `Sources/EmperorCore/MarketSimulation.swift`,
and `testOriginalMarketPeddlerRegistrationPreservesSourceSlotOrder`.

**Evidence class:** **confirmed** for branch order, slot offsets, signed link
tests, and EN/CH parity; **unknown** for provider registration,
commodity/route projection, and household settlement.

## 2026-09-05 cMarket peddler-link validators preserve slot-specific clearing

The three validators following registration are now represented separately
from the writer. `FUN_00429700` (market `+0x2E`) rejects a link below `1`, and
`FUN_00429780` (attached-info `+0x6A`) rejects a link at or below `0`; their
empty branches return failure without a clear. `FUN_00429810` (attached-info
`+0x6C`) also rejects below `1` without a clear. For a non-empty link, all
three require a resolvable figure whose active byte `+0x16` is non-zero, whose
model byte `+0x12` equals either supplied model argument, and whose parent
`+0x62` equals the market registry value (`market +0xB4`). Any failed check
clears that validator's stored short link and returns failure.

`OriginalMarketPeddlerLinkStorage.validateLink` keeps the signed empty-test
polarity, explicit lookup existence, two-model acceptance, parent comparison,
and clear-on-stale behavior as a pure result. It does not mutate cMarket,
resolve a figure registry, or infer commodity/coverage meaning. The Qin
campaign peddler path therefore remains fail-closed at provider projection,
route/collision, and house food-quality settlement.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00429700.c`,
`FUN_00429780.c`, `FUN_00429810.c`, `local/source/compare-report.tsv` rows
`0x429700`, `0x429780`, and `0x429810`, `Sources/EmperorCore/MarketSimulation.swift`,
and `testOriginalMarketPeddlerValidatorsPreserveEmptyAndClearBranches`.

**Evidence class:** **confirmed** for slot-specific empty polarity, active/model/
parent gates, clear-on-stale writes, and EN/CH parity; **unknown** for
registry population, route, commodity records, and household settlement.

## 2026-09-05 cMarket peddler capacity gate preserves checked-slot cardinality

`FUN_00429670 @ 0x429670` is the cMarket `+0x4C` predicate consumed before a
model-`0x17` peddler allocation. It calls the market type accessor (`+0x54`)
and then treats validator results as an all-occupied test: type `1` checks
only the primary `+0x3C` slot; type `2` checks primary then attached-info
`+0x40`; every other type takes the source's `else` branch and checks all
three (`+0x3C`, `+0x40`, `+0x44`). The result is true only when every checked
validator returns non-zero, so the caller interprets false as at least one
free slot. The EN/CH indexed bodies are `identical`; no semantic name is
assigned to the market-type byte beyond the separate type-2/type-3 evidence.

`OriginalMarketCatalog.peddlerSlotsFullyOccupied` records this pure checked-
slot cardinality, including the source's raw default branch for unknown type
values. It is not wired to Native peddler counts, route construction, provider
registration, or household settlement; the Qin market bridge remains
fail-closed at those unresolved boundaries.

**Sources:** `local/source/split-merged/code/0x040000/FUN_00429670.c`,
`local/source/compare-report.tsv` row `0x429670`, the adjacent cMarket
validator rows `0x429700`, `0x429780`, and `0x429810`, and
`testOriginalMarketPeddlerCapacityGateChecksSourceSlotSet`.

**Evidence class:** **confirmed** for branch/cardinality/order and EN/CH parity;
**unknown** for provider registry population, route/coverage, commodity
projection, and household settlement.

## 2026-09-05 cMarket peddler membership matcher preserves raw type branches

`FUN_004295C0 @ 0x4295C0` is the cMarket `+0x48` matcher used by the peddler
update wrapper. It compares a target figure ID against the primary market
link (`+0x2E`) for type `1`; type `2` additionally checks attached-info
`+0x6A`; and type `3` additionally checks attached-info `+0x6C`. A matching
slot returns `1`, otherwise `0`. Its source `else` branch re-reads the type
and returns `type & 0xFFFFFF00` for any value other than `3`; that raw result
is preserved rather than silently converting unknown market types to false.
The indexed EN/CH rows are `identical`.

`OriginalMarketPeddlerLinkStorage.registeredFigureMatchRaw` records this
membership boundary as an integer result. It remains separate from validator
activity/model/parent checks and is not wired to Native peddler IDs, provider
registration, route construction, or household settlement; Qin remains
fail-closed at those unresolved boundaries.

**Sources:** `local/source/split-merged/code/0x040000/FUN_004295C0.c`,
`local/source/compare-report.tsv` row `0x4295C0`, the cMarket getter at
`FUN_00416B50.c`, and `testOriginalMarketPeddlerMembershipMatcherPreservesRawTypeBranches`.

**Evidence class:** **confirmed** for slot comparison order, raw unknown-type
return, and EN/CH parity; **unknown** for provider registry population,
route/coverage, commodity projection, and household settlement.

## 2026-09-05 cMarket model-23 allocation tail is success-gated

The final branch of `FUN_00543ED0 @ 0x543ED0` is now separated from the
unresolved route and provider projection. After the wrapper has reset cMarket
`+0x36` and called `FUN_00544910`, it calls
`FUN_004EA050(..., model 0x17, ...)`. Only a non-zero allocator handle enters
the tail: `FUN_0047F1B0` resolves the new figure, figure `+0x40` is set to
`1`, the market method at `+0x50` receives the handle, figure `+0x62` receives
the signed-short market registry value from market `+0x2D`, and the market
direction byte `+0x0E` is advanced by `(signed old byte + 4) & 7`. The same
direction is copied to figure `+0x1A`, then `FUN_004E6A70` is entered. A zero
allocator handle performs none of these writes, so threshold crossing alone
does not rotate the market or initialize a figure.

`OriginalMarketPeddlerAllocationTail.resolve` records the raw success/failure
boundary, signed-short parent-ID truncation, signed-byte direction arithmetic,
and the final roam-initialization edge as a pure result. It is intentionally
not wired to Native peddler allocation: the allocator registry handle and
resolved figure object, the resulting live registry population, selected
endpoint, route buffer, and household settlement remain unresolved. The
market `+0x50` writer's slot order is independently confirmed in the
registration section above. The focused regression
`testOriginalMarketPeddlerAllocationTailWritesOnlyAfterLiveFigure` covers both
the no-write failure path and the success/write path, including raw `0xFF`
direction and `0xFFFF` parent values.

**Sources:** canonical English executable SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
executable SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`,
`local/source/split-merged/code/0x050000/FUN_00543ed0.c`,
`FUN_00544910.c`, `local/source/split-merged/code/0x040000/FUN_004e6a70.c`,
`local/source/compare-report.tsv` rows
`0x543ED0`, `0x544910`, and `0x4E6A70`, and
`Sources/EmperorCore/MarketSimulation.swift`.

**Evidence class:** **confirmed** for allocator-success ordering, offsets,
signed truncation, direction update, and EN/CH parity; **unknown** for
allocator-handle registry ownership and resolved object, live registry
population, endpoint / route consumption, coverage, and settlement.

## 2026-09-05 cMarket shop removal is gated before quantity mutation

`FUN_00544B30 @ 0x544B30` is the source boundary for removing a selected
market shop. Its first three checks are strict early returns: market status
byte `+0x01` equal to `2` or `6`, a null child link at `child+0x158`, or a
negative child bay ordinal at `child+0x150`. Only after those checks does the
function call the market ordinal callback and subtract the selected provider
row's capacity (`800` when the row flag at `+0x18` is zero, otherwise `400`),
clamping the raw quantity to zero. It then clears the child state byte and
creates an Empty Shop model `0x3E` (GameData building ID `62`) at the former
coordinates, preserving the market registry ID and bay ordinal in the new
child. The later object-vector/provider callbacks are not a recovered Native
provider projection.

Native now records the admission and known quantity result in
`OriginalMarketShopRemovalBoundary.remove(...)`. Invalid raw quantities or
the Empty Shop model return `nil`; source early returns return an explicit
non-admitted result without synthesizing mutation. The helper is research-only
and is not wired to the live Qin market path because object-vector removal,
provider record ownership, route/coverage, and household settlement remain
unresolved.

**Sources:** canonical English executable SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
executable SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`,
`local/source/split-merged/code/0x050000/FUN_00544b30.c`,
`FUN_00540f80.c`, `FUN_005428b0.c`, `local/source/compare-report.tsv` row
`0x544B30`, `GameData/Model/EmperorBuildingModels.txt` (building IDs 59–62),
and `Sources/EmperorCore/MarketSimulation.swift` with
`testOriginalMarketShopRemovalBoundaryPreservesSourceEarlyReturns`.

**Evidence class:** **confirmed** for the early-return order, status values,
link/ordinal offsets, 400/800 subtraction and clamp, Empty Shop model ID, and
replacement-field writes; **unknown** for indirect callback effects, provider
registry ownership, route/coverage, and household settlement.

## 2026-09-05 cMarket peddler availability keeps the Dinners-only threshold

`FUN_00540970 @ 0x540970` is a separate admission predicate used by the
cMarket peddler path. It returns false immediately when the child has no
parent link at `child+0x158`. Otherwise it asks the market vtable at byte
offset `+0x2D8` for the child bay ordinal (`child+0x150`), reads the selected
record's commodity word at `record+0x0C`, and calls
`FUN_00540710 @ 0x540710`. That predicate is exact: it returns true only for
commodity ID `0x1C` (Dinners). The active-figure count from `FUN_004F8200` is
then compared strictly against `400` for Dinners and `200` for every other
commodity; equality is rejected.

`OriginalMarketPeddlerAvailabilityBoundary.admitsNextPeddler(...)` preserves
that source gate with the commodity ID and parent-link state as explicit
inputs. It is intentionally not connected to Native figure allocation: the
vtable's provider-record lookup, active-vector ownership, peddler endpoint and
route, coverage, and settlement effects remain unresolved.

**Sources:** canonical English executable SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, Chinese
executable SHA-256
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`,
`local/source/split-merged/code/0x050000/FUN_00540970.c`,
`FUN_00540710.c`, `local/source/compare-report.tsv` rows `0x540970` and
`0x540710`, and `Sources/EmperorCore/MarketSimulation.swift` with
`testOriginalMarketPeddlerAvailabilityBoundaryPreservesSourceThresholds`.

**Evidence class:** **confirmed** for the parent-link early return, Dinners
commodity predicate, strict `400`/`200` thresholds, and EN/CH parity;
**unknown** for the selected provider record's runtime meaning and all
downstream allocation, route, coverage, and settlement behavior.
