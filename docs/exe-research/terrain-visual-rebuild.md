# Original terrain visual rebuild vs native authored-image rendering (mountain look)

Read-only inspection of the hash-identified original executables
(`Emperor[EN].exe` `8a6d2df1…6753`) and shipping `GameData`.

## 1. Problem (user report)

"感觉山地部分的贴图不正确" — the mountainous area on the city map looks
different from the original: rock/bare/grass cells around the elevation look
wrong and the flat colour bed under sprites shows through the semi-transparent
sprite corners.

## 2. Recovered original control flow (confirmed)

- `FUN_0053EAA0` (city-load) **clears the authored per-cell image** for
  non-elevation cells after loading (`DAT_00FE9880`), so the original does not
  render most terrain from the .map's authored image IDs.
- `FUN_0053EAC0` re-derives the visual from the terrain flag word + variation
  bytes + multi-cell footprints:
  - rock `0x2` → rock family key `0x606`
  - sand `0x80000000` → key `0x60e`
  - bare → key `0x603`
  - grass → `0x602` / `0x604`
  - water → `0x605` / `0x61a…0x61c`
  - elevation `0x200` keeps the authored `China_Elevation` sprite (native
    already matches this).
- `FUN_0053F090` (bare) rejects mask `0xaefede6f`; `FUN_0053F660` is the rock
  family; dispatch order `FUN_0053EC90`: rock before grass before bare.
- The key rule (`0x408170`): `archiveIndex = key >> 9`,
  `logicalGroup = (key & 0x1FF) - 1` (DESIGN.md line 345, canal contract).

## 3. Native behaviour today

`CityCanvasTerrainRenderer.drawOriginalTerrain` draws the authored per-cell
image directly for non-fertile, non-elevation cells
(`LibraryModel.RenderedMap.sprite(x:y:)`), and paints a flat colour diamond
bed under every sprite (`drawGround`). Fertile cells already use the grass
bed (`isPlainFertileLand` + `drawFertileGrass`), so the visible divergence is
concentrated in rock/sand/bare cells and the flat bed under elevation/rock
sprites.

## 4. Status

- `confirmed`: the clear-and-rebuild pipeline, the flag→family keys, dispatch
  order, and the "keep elevation authored sprite" rule.
- `unknown`: the exact archive-index table that resolves keys `0x602…0x61c` to
  `China_Terrain` image IDs in native coordinates; the variation-byte mapping
  for multi-cell families; the height-slope overwrite (`FUN_0053EAE0` sets
  `0x200` + vegetation `0x601` on lower cells adjacent to higher ground).

Implementation of the flag→family dispatch is deferred until the archive-index
table and variation mapping are recovered; native keeps authored-image
rendering (fail-closed) rather than approximating the families.
