# Cursor animal sprite-group pass

This note records a read-only pass over the shipped `SprMain.sg3` and
`SprMain2.sg3` archives. It does not add animal behavior or copy an original
executable into the repository. The executable/runtime lookup remains a
separate, unresolved evidence track.

## Evidence and commands

The group and bitmap boundaries below were produced from the repository build
of `emperor-inspect`:

```text
./.build/arm64-apple-macosx/debug/emperor-inspect \
  sg3-bitmap-map GameData/DATA/SprMain.sg3
./.build/arm64-apple-macosx/debug/emperor-inspect \
  sg3-bitmap-map GameData/DATA/SprMain2.sg3
./.build/arm64-apple-macosx/debug/emperor-inspect \
  sg3-figure GameData/DATA/SprMain.sg3 <bitmap-name>
```

`SG3Archive` reads each archive's authored bitmap name and logical-group
start IDs. The groups below are therefore **confirmed archive geometry**. The
species association is a data crosswalk between those names and
`GameData/Model/EmperorFigureModels.txt`; no original runtime selector table
was recovered in this pass.

## Hash-matched executable cross-reference

The installed executable is available outside the repository at
`/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]/Emperor[EN].exe`.
Its SHA-256 is
`8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`, matching
the hash recorded in `DESIGN.md`. A read-only string scan confirms that the
original program has distinct figure classes and resource labels:

```text
FIG_GOBI_BEAR       cGobiBearFig
FIG_VULTURE         cVultureFig
FIG_PANDA_BEAR      cPandaBearFig
FIG_SALAMANDER      cSalamanderFig
FIG_TIGER           cTigerFig
FIG_ALLIGATOR       cAlligatorFig
FIG_WILD_PIG        cWildPigFig
FIG_PHEASANT        cPheasantFig
FIG_ANTELOPE        cAntelopeFig
SprMain3            SprMain2            SprMain
```

These names are **confirmed executable evidence that the species are distinct
original figure classes**. The PE contains no readable `gobi_bear`/
`wildpig`/`salamander` SG3 bitmap-name strings, and the class table's internal
type values are not the authored model IDs 69–77. Therefore this scan does
not promote the archive-family crosswalk or any animation state to
`confirmed`; the exact class/resource selector remains `unknown`.

One useful selector boundary was recovered even though the final SG3 lookup
is still unresolved. At PE `.text` address `0x59A4E0`, the original code
subtracts 69 from its argument, accepts the inclusive range 69…77, and returns
indices 0…8 (one case per authored animal figure ID). Values outside that
range return `-1`. A nearby `.data` table at `0x85CD20` contains nine
56-byte records whose first dwords are exactly `75, 76, 77, 69, 70, 71, 72,
73, 74`; this is **confirmed figure-ID dispatch/metadata layout**, not a
building or Bbutton table. The remaining record fields include animation
parameters, but no field equals the SG3 logical-group IDs in a way that can be
proven from this static pass. Keep the final `figureID → archive/group/state`
selector `unknown`.

The same code path exposes a second, stronger table boundary. `0x59CB40`
searches the nine pointers initialized by `0x59A420` and returns the matching
animal-record index. `0x59A480` computes `recordIndex * 10 + state` and reads
one dword from `.data:0x85CF38`. The table is therefore nine rows of ten
global image IDs, not five columns shared by adjacent records. The complete
rows are:

| authored figure ID (record order) | ten values at `.data:0x85CF38` |
| ---: | --- |
| 75 | 19977, 19979, 19978, 19978, 19977, 19977, 19977, 19977, 19977, 19977 |
| 76 | 19500, 19501, 19499, 19500, 19499, 19499, 19499, 19499, 19499, 19499 |
| 77 | 19636, 19637, 19635, 19636, 19635, 19635, 19635, 19635, 19635, 19635 |
| 69 | 19642, 19643, 19641, 19641, 19640, 19640, 19640, 19640, 19640, 19640 |
| 70 | 20164, 20165, 20167, 20167, 20166, 20166, 20166, 20166, 20166, 20166 |
| 71 | 19557, 19558, 19556, 19556, 19555, 19555, 19555, 19555, 19555, 19555 |
| 72 | 20121, 20124, 20123, 20123, 20121, 20121, 20121, 20172, 20121, 20121 |
| 73 | 19974, 19976, 19975, 19975, 19973, 19973, 19973, 19973, 19973, 19973 |
| 74 | 19969, 19972, 19971, 19971, 19969, 19969, 19969, 19980, 19969, 19969 |

The dispatch and these 90 integer entries are **confirmed executable data**.
They look like global image-table IDs (the adjacent call is the original
`0x408170` image lookup), but the state's meaning and the global-ID→SG3-local
offset are not recovered. Do not treat these values as local `SprMain*.sg3`
IDs or copy them into a native catalog until that offset and state contract is
proven.

As a sanity check, the largest value (`20164`) is greater than both local SG3
entry counts (`SprMain` 11,877; `SprMain2` 12,888). This rules out a direct
local-image interpretation and is why the table is retained as EXE research
evidence only.

### State-call evidence

The argument read at `[esp+0x14]` in `0x59A480` is supplied by the original
figure renderer. Read-only call-site inspection shows:

- `state=0` is used by the generic figure-update path (`0x59C5D0`), then the
  returned global ID is passed to `0x408170` and stored in the figure object.
- `state=1` is used by ordinary directional rendering (`0x59D14E` and the
  matching `0x59D55x` path). The call site clamps the object's direction field
  to `0…7` and adds it to the returned global image record.
- `state=2`, `3`, `4`, `5`, `6`, `8`, and `9` occur in specialized branches.
  Several branches increment the object frame byte `[object+5]` and wrap it
  at 8 or 12 before adding a direction/frame stride. This confirms that the
  ten table entries are a state/action family selector, not ten fixed compass
  directions.

The exact labels (walk, attack, shadow, swim, death, and so on) remain
`unknown`; no tooltips or live figure state were available in the bounded Wine
probe.

### Global image-table lookup boundary

The adjacent `0x408170` lookup does not treat the table values as local SG3
indices. Static tracing shows a paged global table: the lookup selects a large
page with `imageID >> 14`, a sub-page with `imageID >> 9`, and the low nine bits
as the entry within that sub-page. The root pointer is the runtime global at
`0x01C42130`. This explains why the animal values around 19k–20k exceed the
local archive entry counts. The root/sub-page contents are runtime-initialized
and were not recoverable from the bounded Wine launch, so the global-ID to
`SprMain*.sg3` mapping remains `unknown`.

## Species crosswalk

| figure ID / authored model | archive family and logical groups | first…last image IDs | evidence class |
| --- | --- | --- | --- |
| 69 `Gobi Bear` | `SprMain:gobi_bear`, groups 183–186 | #11175…#11471 | `inferred` species crosswalk; `confirmed` family bounds |
| 70 `Bearded Vulture` | `SprMain2:vulture`, groups 195–197; `vulture_shadow`, groups 198–202 | #12095…#12790 | `inferred` species crosswalk; `confirmed` family bounds |
| 71 `Panda Bear` | `SprMain:panda`, groups 95–100 | #6550…#7065 | `inferred` species crosswalk; `confirmed` family bounds |
| 72 `Giant Salamander` | `SprMain2:salamander`, groups 152–153; `salamander_swim`, groups 203 onward in the archive range | #8366…#8557; #12791… | `inferred` species crosswalk; swim range boundary needs selector closure |
| 73 `Tiger` | `SprMain2:tiger`, groups 3–7 | #289…#633 | `inferred` species crosswalk; `confirmed` family bounds |
| 74 `Chinese Alligator` | `SprMain2:alligator`, groups 0–2; `alligator_swim`, groups 9–11 | #1…#288; #730…#929 | `inferred` species crosswalk; `confirmed` family bounds |
| 75 `Wild Pig` | `SprMain2:wildpig`, group 8 | #634…#729 | `inferred` species crosswalk; `confirmed` family bounds |
| 76 `Pheasant` | `SprMain:pheasant`, group 42 | #2657…#2752 | `confirmed` by existing source/data crosswalk |
| 77 `Saiga Antelope` | `SprMain:antelope`, groups 178–180 | #10791…#10990 | `inferred` species crosswalk; `confirmed` family bounds |

The model names and archive bitmap names make the rows above strong candidates
(for example, `Gobi Bear`/`gobi_bear` and `Saiga Antelope`/`antelope`), but they
do not prove which group is walking, attack, death, shadow, or swimming. Some
families deliberately contain several state groups and/or a shadow family.
The exact `figureID → logicalGroupID → state` selector is therefore still
`unknown` for every row except the existing Pheasant animation contract.

## Exact group records recovered

Selected `sg3-figure` output, useful for a future selector implementation:

```text
SprMain:panda
  95 #6550 sprites=15, 96 #6670 sprites=12, 97 #6766 sprites=12,
  98 #6778 sprites=12, 99 #6874 sprites=12, 100 #6970 sprites=12

SprMain:gobi_bear
  183 #11175 sprites=12, 184 #11271 sprites=12,
  185 #11367 sprites=12, 186 #11463 sprites=9

SprMain:antelope
  178 #10791 sprites=12, 179 #10887 sprites=12,
  180 #10983 sprites=8

SprMain2:tiger
  3 #289 sprites=8, 4 #297 sprites=12, 5 #393 sprites=17,
  6 #529 sprites=12, 7 #625 sprites=9

SprMain2:vulture
  195 #12095 sprites=10, 196 #12175 sprites=12,
  197 #12187 sprites=12
SprMain2:vulture_shadow
  198 #12283 sprites=20, 199 #12443 sprites=10,
  200 #12523 sprites=12, 201 #12535 sprites=12,
  202 #12631 sprites=20
```

The `salamander_swim` bitmap record is an archive-level range whose inferred
logical end is the SG3 group-table sentinel (`203..<300`); only logical group
203 has a populated group-start record in the current archive. Treat the
remaining range as `unknown`, not as 97 confirmed animations.

## What was not recovered

- The hash-matched EN executable is installed outside the repository (the path
  and digest are recorded above); no CH executable was found in the current
  workspace search. The static scan confirms figure classes but still finds no
  class/resource selector that names the SG3 logical groups.
- `uname -m` reports `arm64`; the app-bundled
  `Contents/SharedSupport/wine/bin/wine32on64 --version` returns `wine-5.0`.
  A fresh temporary-prefix launch was attempted read-only, but it did not
  reach a usable city/tooltip state before the bounded probe timed out (Wine
  emitted address-reservation warnings). Consequently no live capture can
  promote the crosswalk to `confirmed` in this pass.
- A later bundled-Wine probe launched the original Chinese executable through
  `wine32on64-preloader`; the observed window title was `龙之崛起`, version
  `1.0.1.0`, with the Chinese main menu visible. This is `confirmed runtime
  launch` only. Entering single-player/city was blocked by a macOS prompt
  asking whether ChatGPT could access files on a network volume; permission
  was not granted, so no city tooltip, process memory, or runtime global-image
  pages were captured. The external CH executable SHA-256 is
  `0ca8fc07199ea319bc7e83b9f603a2f7b1225fcfd9b609e4e73c1a86cdc3c658`.
- A follow-up Computer Use attempt was explicitly authorized to choose
  `允许`, but the automation accessibility layer resolved the same display
  name to the native reimplementation (`dist/EmperorNative.app`) and could
  not obtain an AX window handle for the Wineskin `wine32on64-preloader`
  window. Coordinate and keyboard actions were therefore rejected before
  reaching the system prompt; the prompt remains visible and no accidental
  `不允许` action was taken. This is an automation limitation, not evidence
  that the original executable failed to launch.
- `BUILD_MAP_PREY_POINT` remains an authored map marker in
  `EmperorBuildingModels.txt`. `EmperorMap` preserves all 13 legacy byte grids,
  but this pass did not establish which grid stores prey points or whether its
  values are anchors, counts, or other editor metadata. The deterministic
  Pheasant loop described in `ambient-prey.md` remains an explicitly temporary
  bridge.
- A fresh `strings` scan of the hash-matched EN executable adds a stronger
  class-level boundary: the binary contains the independent `cPredatorLogic`
  and `cPreyLogic` RTTI names, all nine animal figure classes, and the hunting
  building/resource names (`BUILD_HUNTERS_TENT`, `BUILD_HUNTING_SEA`,
  `HUNTING`). This confirms that prey/predator movement is a dedicated logic
  subsystem and that the nine `FIG_*` records are not merely decorative
  sprites. It still does not expose the map-grid selector, spawn cadence, or
  species-specific state groups, so no new behavior mapping is promoted from
  this evidence alone.
- `emperor-inspect map-point-score GameData/Cities` only scores the known
  scenario-header coordinate pairs (land/sea entry and invasion/disaster
  candidates); its 167-map output does not expose a prey-grid index. A direct
  `map-image-range ... 183 183` probe on `Banpo.map` returns zero cells, which
  is consistent with 183 being a model/building type rather than a world image
  ID and does not locate the marker.
- No implementation change is authorized by these asset boundaries alone;
  adding predator/salamander/vulture/saiga rendering before recovering the
  selector and spawn rules would turn an `inferred` mapping into unsupported
  gameplay behavior.

## Next evidence needed

1. Run the original executable in the hash-matched EN/CH installation and
   capture a figure's sprite/animation state while logging its figure ID.
2. Compare the editor's `BUILD_MAP_PREY_POINT` placement with decoded map byte
   grids across several maps, preserving coordinates and grid index.
3. Only after those observations, add a catalog entry with the exact state
   groups and authored spawn semantics; keep unclosed families in this note.
