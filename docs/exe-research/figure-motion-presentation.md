# Figure motion presentation: interpolate only on an actual route transition

## Evidence

- `GameData/Model/EmperorFigureModels.txt` defines figure `28` as the water
  carrier with speed `8` and behavior range `40`.
- `docs/exe-research/residential-service-roamer-lifecycle.md` records the
  recovered water-carrier movement contract: selector `8` executes the exact
  `1/1/2` substep cadence, and a route position advances only after the
  movement substep reaches `20`.
- `CityCanvasEntityRenderer` previously supplied `route[routeIndex - 1]` to
  every service figure whenever that value existed. The canvas then applied
  the global between-tick interpolation progress even on simulation updates
  where `routeIndex` did not change. That repeatedly interpolated a stationary
  figure from its prior tile and presented as jitter or an abnormal slide.
- The former temporary pheasant bridge selected arbitrary clear-land anchors
  and advanced a guessed route once every three simulation ticks. That route
  was removed after comparison because neither its spawn point nor its
  movement cadence is source-backed.
- Authored figure pixels use RGB555 value `0x7C00` as a pure-red marker in the
  water-carrier frames. Native's only confirmed transparent RGB555 marker is
  `0xF81F`. The exact original runtime shadow compositor for `0x7C00` has not
  been recovered; converting it to semi-transparent black produced a visible
  grey block on the native terrain.

## Implementation contract

- `RoadServiceWalker` records whether its route position changed during the
  most recent simulation step. The field is optional-backed so older Native
  saves remain decodable; it is presentation state, not gameplay state.
- The player canvas passes a previous point only when that flag is true. A
  service figure that remains on the same route point is rendered in place.
- No pheasant route is emitted until `BUILD_MAP_PREY_POINT` and the prey logic
  movement state are recovered. This prevents an invented route from becoming
  player-visible behavior.
- The figure decoder removes the unresolved pure-red shadow marker by making
  those exact pixels transparent. It does not invent a replacement shadow
  shape or tint.

Classification: the water movement cadence and authored marker values are
`confirmed`; the interpolation defect is directly reproduced from the native
control flow; the prey spawn layer and movement cadence remain `unknown`; the
absence of a replacement shadow shape remains `unknown`.

## Delivery-cart motion contract (2026-08-26)

The meat-cart report exposed a separate delivery-walker presentation gap.
Read-only static evidence for the hash-matched English/Chinese executables is
consistent:

- Delivery figure `#22` is handled by `FUN_0051D0C0`. Its outbound state calls
  `FUN_004E6B70(..., 6)` rather than directly advancing a route cell.
- `FUN_004E6B70` case `6` calls `FUN_004E6D80(..., 1, 0)`. The latter increments
  the figure's movement substep and only updates the map cell after the
  recovered 20-substep boundary. This is not a one-road-cell-per-day rule.
- The Native day bridge already distributes the authored 816 original monthly
  steps across 30 days as 27/28-step updates (`MigrationSimulation`), so a
  delivery cart must accumulate those original substeps and cross route cells
  at the 20-substep boundary.
- The renderer previously always supplied `route[routeIndex - 1]` to delivery
  carts. That made an inactive or otherwise non-moving cart appear to slide
  during the presentation interval. Delivery state now exposes an optional
  `movedOnLastSimulationStep` flag, and the renderer interpolates only when it
  is true.

Classification: the delivery call chain and 20-substep boundary are
`confirmed`; exact delivery return-state side effects outside the existing
physical route model remain `unknown`. The implementation contract is limited
to the recovered microstep cadence, route-cell transition, and presentation
interpolation gate.
