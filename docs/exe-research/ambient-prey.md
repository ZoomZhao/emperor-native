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

This pass uses only the repository's `local/source/` corpus. It targets the
canonical English executable SHA-256
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` and
cross-checks the Chinese executable
`dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
The English and Chinese decompilations are identical for the relevant
functions in `local/source/compare-report.tsv`; the following is therefore
shared control-flow evidence, not a runtime observation.

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

## `BUILD_MAP_PREY_POINT` closure pass (2026-08-27)

The editor-side contract is now closed at the coordinate-slot level:

- `FUN_00404990` handles model `0xB7` (`BUILD_MAP_PREY_POINT`). It accepts a
  cell only when `FUN_0059CBB0(mapFlags, 1)` accepts the prey category, submits
  the old coordinate for replacement through `FUN_0053E520`, and stages the
  new coordinate in the editor's pending fields. The pending index is the
  current prey-point slot.
- `FUN_0053E560` commits the pending `x/y` pair for `0xB7` into
  `DAT_00C5CE3C[index]` and `DAT_00C5CE4C[index]`, then clears all pending
  fields. `FUN_0053CEC0` resets both arrays to `-1` when the map/session is
  initialized. `FUN_00403900` and `FUN_00403EA0` expose the same four slots
  for “has any point” and editor-cell visualization/erase behavior.
- The four-slot limit is direct from the loops ending at `0xC5CE4C`/`0xC5CE5C`.
  `FUN_0059C930(param_1=0, ...)`, `FUN_0059C8A0`, `FUN_0059C7F0`, and
  `FUN_0059CE80(param_3!=0)` all treat this family as exactly four prey
  coordinate pairs. These are map cells, not a closed route or a rendered
  gray/red marker asset.

The live setup contract is also more precise than the previous summary:

- `FUN_0059CAD0` selects one of three regional table bases based on
  `DAT_00C5CD58`; `FUN_0059CA80(0)` selects the corresponding prey-family
  table. In `FUN_004EB010`, the selected table's third field is used as the
  loop bound for every valid prey point, so it is the configured number of
  prey figures per point. The table bytes and the semantic meaning of the
  region selector remain unknown.
- For each valid prey pair (`x > 0`, `y > 0`), `FUN_004EB010` allocates one
  point record, copies the pair as its anchor, sets behavior range `0x18` and
  category byte `3`, then attempts up to sixteen prey-compatible neighboring
  cells for each figure. It creates the figure with a random direction, state
  `0x13`, point index `+0x6A`, ordinal `+0x6C`, and timer `random() % 0x19`.
  The relevant English/Chinese functions are marked `identical` in
  `local/source/compare-report.tsv`.

The remaining storage boundary is deliberately not closed. `FUN_0052E7C0`
restores the map grids and Building vector during deserialization, but the
indexed C corpus contains no direct load-time assignment to
`DAT_00C5CE3C/4C`; the visible assignments are the session reset and the
editor commit above. The actual MFC/dynamic deserialization edge, or an
unrecovered map record that feeds it, is therefore `unknown`. Raw `0xB7`
occurrences in decoded `.map` data are not sufficient evidence for a layer.

The important correction is that the original bird route is not a pre-authored
closed loop. The supported model is a prey point plus bounded, stateful,
random local movement. The exact Pheasant vtable edge into `FUN_0059AD60`, the
serialized map-grid/record field that feeds `DAT_00C5CE3C/4C`, and the
timer-to-render-frame conversion remain `unknown`. Native must stay fail-closed
until those fields are closed.

The current map parser preserves the thirteen legacy byte grids but has not
yet proved which grid or object records store `BUILD_MAP_PREY_POINT` records.
Until that layer is decoded, no player-visible bird route is synthesized; a
guessed route must not be treated as an exact reproduction of authored spawn
coordinates.

## Remaining fidelity work

1. Trace the MFC/dynamic deserialization edge, or identify the map record that
   feeds `DAT_00C5CE3C/4C`; do not select a byte-grid by raw `0xB7` frequency.
2. Persist those points in `EmperorMapAuthoredPoints` and use them as the
   spawn/roaming anchors.
3. Recover the prey logic's movement cadence and route state before enabling
   the authored bird figures.
4. Resolve the other prey/predator figure families (wild pig, saiga,
   vulture, and regional predators) before adding them to the native catalog.
