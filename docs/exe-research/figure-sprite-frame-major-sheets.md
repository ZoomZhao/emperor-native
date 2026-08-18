# Original figure sprite sheets are frame-major with a one-step rotation

Read-only inspection of the hash-identified original executables
(`Emperor[EN].exe` `8a6d2df1…6753`, cross-checked `Emperor[CH].exe`
`dbdeca1e…15a`), shipped `GameData`, and the exported figure sheets.

## 1. Problem

The native delivery cart rendered the meat cart (commodity #4) with frames
where the cart pusher is barely visible ("cart with meat, no person"). Root
cause: `FigureSpriteAnimation` indexed the SG3 sheets direction-major
(`firstImageID + direction × framesPerDirection + frame`), while the original
sheets are frame-major.

## 2. Recovered original layout (confirmed)

- Movement direction bytes `0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW`
  (route builder `FUN_005B3160` neighbor deltas `−228/−227/+1/+229/+228/
  +227/−1/−229` on the 228-wide grid).
- Sprite formula in `FUN_004CB910` (type-19) and `FUN_0051D0C0` (generic):
  `image = effectiveDirection + baseImage + frameByte × 8`. Effective
  direction = `figure.direction − DAT_0101d0d0` (camera rotation; 0 default).
- Therefore one animation frame = a block of eight direction images, and
  `imageID = firstImageID + sheetDirection + frame × 8`.
- Sheet rotation: exact horizontal mirrors sit at sheet positions
  `(0,6),(1,5),(2,4)` (pixel-perfect flips in the Peddler sheet, IoU 1.00),
  and `(3,7)` are the near-self-mirror front/back views. Under isometric
  geometry horizontal flips pair `NE↔NW, E↔W, SE↔SW, N↔N, S↔S`; this matches
  `sheetDirection = (directionByte − 1) mod 8` (N→7, NE→0, E→1, SE→2, S→3,
  SW→4, W→5, NW→6), so direction 0 starts at the sheet's last position.
- Every catalog group's image count equals `framesPerDirection × 8`.

Classification: frame-major stride and the eight-direction block structure are
`confirmed` (two executable formulas + group geometry); the exact one-step
rotation is `confirmed` by the pixel-exact horizontal mirrors under isometric
flip rules and consistent for all sampled groups.

## 3. Native fix

`FigureSpriteAnimation.init` now builds:

```swift
let sheetDirection = (direction.rawValue - 1 + 8) % 8
frames = (0..<framesPerDirection).map { firstImageID + sheetDirection + $0 * 8 }
```

Consequences: the meat cart moving south now renders frames `base+3` /
`base+11` (the tall full-pusher frames), and every catalog figure (peddler,
buyer, immigrant, water bearer, inspector, soldiers, pheasant, grand-canal
laborers/carts) uses the original per-direction frames.

## 4. Remaining unknowns

- The SG3 `sprites` field reported `0` for several frames while
  `SpriteDecoder` still decodes real content; the pre-exported
  `GameData/DATA_IMAGES` PNGs for those frames are blank (an export artifact),
  but the runtime decodes from the raw `.sg3/.555` and is unaffected.
- Cart anchor offsets (`spriteOffsetY` well above frame height) and the exact
  on-screen placement of carts vs the pusher still need a same-state original
  screenshot or video frame for final visual confirmation.
