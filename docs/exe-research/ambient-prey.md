# Ambient prey / map birds

## Confirmed from shipped data

- `GameData/Model/EmperorFigureModels.txt` defines figure `76,Pheasant` with
  unit type `PREY` and movement speed `11`.
- `GameData/Model/EmperorBuildingModels.txt` defines
  `183,BUILD_MAP_PREY_POINT`; this is a map-authored spawn marker, not a
  player construction button.
- `GameData/DATA/SprMain.sg3` resolves bitmap `pheasant` to logical group `42`,
  image IDs `#2657…#2752`, eight directions and twelve frames per direction.
- The same figure has ambient audio entries in `GameData/Audio/sound_fxU.txt`
  and hit/death entries in `GameData/Audio/FigureSounds.txt`.

## Native implementation status

`OriginalFigureSpriteCatalog.pheasantAnimation` now uses that exact source
family. The previous deterministic clear-land loop was removed after visual
comparison: it invented both the spawn anchor and the route. Until the
authored prey-point layer is decoded, the player canvas emits no synthetic
bird route; the sprite catalog remains ready for the source-backed bridge.

## Static original-control-flow pass (2026-08-27)

This pass uses only the repository's `local/source/` corpus. The English and
Chinese decompilations are identical for the relevant functions in
`local/source/compare-report.tsv`; the following is therefore shared control
flow evidence, not a runtime observation.

- `local/source/split-merged/code/0x050000/FUN_0053d100.c` (`0x53D100`) is
  reached from the map/session load path at `FUN_0043ABF0` and calls
  `Creating_fort_pctd_for_killer_type` (`0x4EB010`) before rebuilding the
  simulation grids. This is the setup boundary at which map-authored animal
  points become live animal records.
- `local/source/split-merged/code/0x050000/FUN_0053cec0.c` (`0x53CEC0`)
  initializes the prey-point coordinate arrays at `DAT_00C5CE3C` and
  `DAT_00C5CE4C` to `-1`. The editor input path
  `FUN_00404990` stores `BUILD_MAP_PREY_POINT` (`0xB7`, model ID 183) into
  those arrays, and `FUN_0053e560` commits a pending edit. The arrays hold
  four `(x,y)` slots, not an arbitrary-length route.
- `Creating_fort_pctd_for_killer_type` reads each valid prey slot, calls
  `FUN_0054C4F0` to allocate a point record, and then creates the configured
  number of prey figures with `FUN_004EA050`. Each created figure is assigned
  state `0x13`, the point-record index at object offset `+0x6A`, a per-point
  ordinal at `+0x6C`, and an initial timer of `random() % 0x19` at `+0x3E`.
  The preceding killer-point loop uses the same structure but writes
  `(random() % 0x19) << 2` to that timer, which is a confirmed prey-versus-
  killer initialization difference.
- `FUN_0059a6a0` classifies figure types `0x4B…0x4D` (authored IDs 75–77:
  wild pig, pheasant, saiga) as prey; `FUN_0059a6c0` classifies
  `0x45…0x4A` (IDs 69–74) as predators. `FUN_0059a4E0` maps all nine
  authored IDs to the animal dispatch records, with prey records first.
- `FUN_0059ad60` is the recovered common animal roaming handler. It reads the
  point record's anchor coordinates from `DAT_011A2B3E/40` using the figure's
  `+0x6A` index. If the figure is within six map steps of that anchor, it
  chooses nearby random coordinates and retries up to sixteen candidates. If
  farther away, it chooses a random direction candidate around the anchor;
  an invalid candidate falls back to the anchor itself. It then updates the
  figure's packed movement nibbles through `FUN_0059A9F0`/`FUN_0059AA20` and
  enters state `0x10` when the chosen cell is not accepted by
  `FUN_0059CBB0`.

The important correction is that the original bird route is not a pre-authored
closed loop. The supported model is a prey point plus bounded, stateful,
random local movement. The exact Pheasant vtable edge into `FUN_0059AD60`, the
configured per-point count in the `0x85CD20` records, the serialized map-grid
field that feeds `DAT_00C5CE3C/4C`, and the timer-to-render-frame conversion
remain `unknown`. Native must stay fail-closed until those fields are closed.

The current map parser preserves the thirteen legacy byte grids but has not
yet proved which grid or object records store `BUILD_MAP_PREY_POINT` records.
Until that layer is decoded, no player-visible bird route is synthesized; a
guessed route must not be treated as an exact reproduction of authored spawn
coordinates.

## Remaining fidelity work

1. Identify the prey-point byte-grid index by correlating several original
   `.map` files with the Campaign Creator/editor output.
2. Persist those points in `EmperorMapAuthoredPoints` and use them as the
   spawn/roaming anchors.
3. Recover the prey logic's movement cadence and route state before enabling
   the authored bird figures.
4. Resolve the other prey/predator figure families (wild pig, saiga,
   vulture, and regional predators) before adding them to the native catalog.
