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
family. `CityCanvasEntityRenderer` emits deterministic short loops on clear
land, excluding road cells, houses, and occupied building footprints, so the
bird is rendered by the same sprite/depth path as other walking figures.

The current map parser preserves the thirteen legacy byte grids but has not
yet proved which grid stores `BUILD_MAP_PREY_POINT` records. Until that layer
is decoded, the loop selection is explicitly a temporary bridge; it must not
be treated as an exact reproduction of authored spawn coordinates.

## Remaining fidelity work

1. Identify the prey-point byte-grid index by correlating several original
   `.map` files with the Campaign Creator/editor output.
2. Persist those points in `EmperorMapAuthoredPoints` and use them as the
   spawn/roaming anchors.
3. Resolve the other prey/predator figure families (wild pig, saiga,
   vulture, and regional predators) before adding them to the native catalog.
