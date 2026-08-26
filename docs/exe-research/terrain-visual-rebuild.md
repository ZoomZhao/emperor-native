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
- `confirmed` (correction to earlier draft): the `0x603 = #247` claim is a
  misreading — DESIGN.md line 345 restores canal phase-0 cells to `China_Terrain
  #247` as a raw image ID, it does not resolve runtime key `0x603`. The road
  anchor `#782` sits in INDEX group 30 and DESIGN.md calls it group 30, so
  INDEX group number == logical group number. Therefore key `0x603` →
  logical group 2 → China_Terrain `#202` (not `#247`); the family keys would
  map to groups 1/2/3/4/5/13/25/26/27 (`#201/#202/#247/#336/#386/#1440/
  #1443/#574/#736`) **only if** China_Terrain is archive index 3 — which is
  still unverified, so the family→image assignment remains `unknown`.
- `unknown`: the exact archive-index table that resolves keys `0x602…0x61c` to
  an archive; the variation-byte mapping for multi-cell families; the
  height-slope overwrite (`FUN_0053EAE0` sets `0x200` + vegetation `0x601` on
  lower cells adjacent to higher ground).

The confirmed rock-family portion is implemented for the player canvas. Other
flag→family branches remain fail-closed until their archive-index and
variation mappings are recovered.

## 5. Rock-family preload correction (2026-08-26)

The player renderer already had the confirmed non-elevation rock dispatch:
`China_Terrain` group 6, local images `#458...#471`, selected by the terrain
variation byte. `LibraryModel.loadRenderedMap` did not preload that family,
however. When a rock cell selected one of those IDs, the renderer returned
`true` without a sprite and the gray terrain-bed diamond from `drawGround`
remained visible. The loader now retains all 14 IDs. This is a confirmed
presentation-only omission; it is separate from the unresolved prey marker and
movement contracts.
