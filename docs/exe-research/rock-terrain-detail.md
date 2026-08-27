# Rock terrain rebuild and resource-family detail

Read-only static inspection of the hash-identified executables recorded in
`DESIGN.md` and the shipping `GameData`. This note is the current source of
truth for the non-elevation map-rock rendering path. It does not authorize
copying the executable into the repository or treating decompiler names as
original symbols.

## 1. Scope and evidence

- Canonical behavior build: English `Emperor[EN].exe`, SHA-256
  `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`.
- Chinese executable: `dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`.
  The relevant functions below are marked `identical` in
  `local/source/compare-report.tsv`.
- Static corpus: `local/source/split-merged/`; authored resources:
  `GameData/Model/EmperorBuildingModels.txt`,
  `GameData/Audio/BuildingSounds.txt`, and
  `GameData/DATA/China_Terrain.sg3` / `.555`.

The control-flow conclusions in this note are `confirmed` by identical EN/CH
decompilation and the corresponding resource records. Exact meanings of
some generic cache bytes and the editor's write path remain `unknown`.

## 2. Authored rock IDs and terrain bits

`GameData/Model/EmperorBuildingModels.txt` contains the map/editor model rows:

| model ID | authored name | evidence |
| ---: | --- | --- |
| 168 | `BUILD_MAP_ROCKS` | confirmed authored model row |
| 185 | `BUILD_MAP_ORDINARY_ROCK` | confirmed authored model row |
| 186 | `BUILD_MAP_COPPER_ROCK` | confirmed authored model row |
| 187 | `BUILD_MAP_SILVER_ROCK` | confirmed authored model row |
| 188 | `BUILD_MAP_CLIFF_ROCK` | confirmed authored model row |

These rows have zero building footprint/data fields. They are map terrain
records, not ordinary placeable buildings. The same names are present in the
building sound table, but that table does not establish the terrain rebuild
algorithm.

The executable rock renderer tests terrain bit `0x2`. It distinguishes the
two ore variants from the plain rock by the masked value:

```text
(terrainFlags[cell] & 0x300002) == 0x100002  -> key 0x607
(terrainFlags[cell] & 0x300002) == 0x200002  -> key 0x608
otherwise                                  -> key 0x606, match value 0x2
```

The Native names `TerrainFlags.copperOre` (`1 << 20`) and `ironOre`
(`1 << 21`) match the two raw bit positions, but the authored model calls the
second variant **silver**. The semantic rename/alias is still `unknown`; do
not use the Native spelling as proof that the original resource was iron.

## 3. Rebuild and dispatch chain

The relevant callers/callees are:

```text
FUN_0053E870 @ 0x53E870
  -> FUN_0053EAA0 @ 0x53EAA0  clear/rederive cell state
  -> FUN_0053EC90 @ 0x53EC90  visual dispatch
     -> FUN_0053F660 @ 0x53F660  rock family
```

`FUN_005403C0 @ 0x5403C0` performs the same full-map clear/dispatch sweep.
The load/update helper `FUN_00467680 @ 0x467680` can call
`FUN_004B3BD0 @ 0x4B3BD0`, which contains a second rock rebuild loop with the
same 3×3 → 2×2 → single-cell structure. Both paths are identical between the
English and Chinese executables.

`FUN_0053EAA0` first clears the cached per-cell image for eligible cells, then
calls `FUN_0053EAE0 @ 0x53EAE0`, which can mutate terrain flags and establish
elevation state. `FUN_0053EC90` only reaches the rock branch after earlier
special terrain branches have declined and the cached image is still zero.
Therefore an authored map image ID is not the final source of truth for an
ordinary non-elevation rock cell.

## 4. Exact rock layout algorithm

`FUN_0053F660` receives the current terrain word, cell index, and candidate
map coordinates. It:

1. selects key `0x606`, `0x607`, or `0x608` using the masked value above;
2. resolves the key with `FUN_00408170 @ 0x408170`;
3. tests an exact 3×3 region with `FUN_004B8000 @ 0x4B8000`;
4. if that fails, tests an exact 2×2 region;
5. if that also fails, stores a single-cell image derived from the variation
   byte.

The frame offsets are confirmed from the call arguments:

| accepted shape | `FUN_004B8000` match value | forbidden mask argument | frame offset |
| --- | ---: | ---: | --- |
| 3×3 | selected `2` / `0x100002` / `0x200002` | `0x100` | `0xC + (variation & 1)` |
| 2×2 | selected `2` / `0x100002` / `0x200002` | `0x100` | `8 + (variation & 3)` |
| single cell fallback | not revalidated by the rectangle helper | — | `variation & 7` |

`FUN_004B8000` checks map bounds, every cell in the rectangle, the masked
terrain value `terrainFlags & 0xAFFEDE6F`, and (when requested) the cached
image value. In the normal `FUN_0053F660` path, the cached image must be zero
and bit `0x100` must not be set. Bit `0x100` corresponds to the Native
`TerrainFlags.flood` position; the raw mask is the confirmed part of this
conclusion.

When a 2×2 or 3×3 region is accepted, `FUN_004B72B0 @ 0x4B72B0` writes the
resolved image and related per-cell cache bytes to the whole rectangle. It
also writes a shape-size code (`1` for width 2, `2` for width 3) and an edge
marker whose position depends on the map rotation byte `DAT_0115F720`. This
is why the original output is one contiguous multi-tile rock image rather
than several independently selected cell sprites.

The alternate `FUN_004B3BD0` path calls the same helper with forbidden-mask
argument zero. That load/rebuild distinction is confirmed, but its exact
player-visible flood-state timing is not yet recovered.

## 5. China_Terrain resource structure

`FUN_00408170` resolves the three rock keys to the following authored local
image families in `China_Terrain` (archive index 3):

| key | logical group | local IDs | bitmap record | shape represented |
| ---: | ---: | --- | --- | --- |
| `0x606` | 6 | `#458…#471` | `China_land1.bmp` | plain rock |
| `0x607` | 7 | `#472…#485` | `China_land1.bmp` | copper variant |
| `0x608` | 8 | `#486…#499` | `China_land1.bmp` | silver/second ore variant |

Each family has the same structural partition, corroborated by the SG3 image
dimensions and the call offsets:

```text
offset 0…7   : 8 single-cell frames, width 78
offset 8…11  : 4 two-by-two frames, width 158
offset 12…13 : 2 three-by-three frames, width 238
```

The frame heights vary by the authored drawing, so width—not a fabricated
fixed height—is the reliable shape discriminator. The current Native preload
of `458..<472` therefore covers only the plain family and the current catalog
method can only select its 14 frames. The ore families `472..<500` are also
required by the recovered control flow.

## 6. Current Native discrepancies

The following are confirmed gaps in the current implementation, based on
`Sources/EmperorCore/BuildingSpriteCatalog.swift`,
`Sources/EmperorNative/CityCanvasTerrainRenderer.swift`, and
`Sources/EmperorNative/LibraryModel.swift`:

- `chinaTerrainRockFamilyImageID` always returns `458 + variation % 14`; it
  ignores the `0x607` and `0x608` families.
- The renderer draws one sprite at one cell center. It does not perform the
  original 3×3/2×2 region test, write a contiguous footprint, or suppress
  duplicate draws for the other cells covered by that footprint.
- A single `% 14` choice hides the original shape partition. It can select a
  158- or 238-pixel-wide resource while still using single-cell placement
  geometry, which is a direct explanation for oversized blocks and broken
  neighboring terrain.
- `LibraryModel` preloads only `458..<472`; the copper and silver/second-ore
  families can be absent even after the plain family is fixed.
- `drawGround` paints a hard-coded gray diamond for rock before the sprite.
  If a sprite is missing or is drawn with the wrong footprint, that bed is
  exposed between/under transparent pixels and presents as a gray block. This
  is a confirmed Native presentation path and a high-confidence explanation
  for the reported symptom, but the exact original bed/compositing color is
  not yet recovered.
- The current renderer does not apply the recovered rotation-dependent edge
  marker/shape-cache state. The visual consequence is expected to show at
  rotated views or at the boundary of a multi-cell rock cluster.

## 7. Remaining unknowns and implementation contract blockers

The following must be resolved before changing player-visible rock behavior:

- the actual values/order of `DAT_0081FF18` and `DAT_0081FF1C`, which determine
  the rectangle's cell offsets and the exact anchor convention;
- the complete duplicate/ownership rule when a multi-cell region is visited
  again during the sweep;
- the exact semantic meaning of the other cache bytes written by
  `FUN_004B72B0`, beyond the confirmed shape-size and rotation-edge effects;
- the editor/map deserializer path that turns model IDs 168 and 185…188 into
  terrain bits and variation bytes;
- the final source and composition of the gray/land bed beneath transparent
  rock pixels.

Until those points are closed, the supported fix scope is research/resource
mapping only: do not replace the current per-cell rendering with an inferred
cluster algorithm or invent an anchor/rotation rule.

