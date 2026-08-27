# Emperor[EN].exe research: construction Bbuttons

Read-only static inspection notes for subsequent agents. This file records **confirmed** control-flow and **negative** search results for `buildingID → China_Interface New_Bbuttons base image`. It is research evidence, not a player-facing contract; update `DESIGN.md` if a recovered map changes the UI contract.

> **Resolved 2026-08-12:** the writer and compact mapping were recovered from
> the new Ghidra corpus. Read
> [construction-panel-exe-mapping.md](./construction-panel-exe-mapping.md)
> first. Sections 1–12 below remain useful chronological evidence and explain
> why absolute-image and flat-table scans failed, but their statements that
> the writer/map is still unknown are superseded.

## When to read this

- Before changing `OriginalConstructionButtonSpriteCatalog` / right-panel construction icons.
- Before claiming GameData or the exe already contains a complete button map.
- Before repeating table scans that this note already marks as exhausted.

## Binary identity

| Field | Value |
| --- | --- |
| Name | `Emperor[EN].exe` |
| SHA-256 | `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753` (also in `DESIGN.md`) |
| PE timestamp | `2003-02-15T00:40:52` |
| Typical local path | Wine-skinned app: `/Applications/皇帝龙之崛起.app/Contents/Resources/drive_c/EmperorRotMK[ZeaS]/Emperor[EN].exe` |
| Policy | Development-only, read-only. Never copy into the repo, bundle, or tests. |

### PE layout (confirmed)

| Section | VA | Raw | Size (approx) |
| --- | --- | --- | --- |
| `.text` | `0x1000` | `0x1000` | `0x3A8000` |
| `.rdata` | `0x3A9000` | `0x3A9000` | `0x6B000` |
| `.data` (file-backed) | `0x414000` | `0x414000` | `0x7B000` (BSS much larger) |
| Image base | `0x400000` | | |

For this binary, early `.text` / `.rdata` / initialized `.data` use `file_offset ≈ RVA`, so `VA = 0x400000 + file_offset` in those ranges.

## Confirmed rules

### 1. Sprite resolve helper

- **Address:** `0x408170`
- **Call shape:** `push <imageId>`; `mov ecx, 0x01C42130`; `call 0x408170`
- **Role:** Unpack archive/local bits from the image id and return a sprite record pointer used by later draw helpers.
- **Classification:** `confirmed`

Numeric ids in the China_Interface Bbutton band (`#1488–#1655`) are **not** automatically “UI button draws” when seen next to this call. The same helper serves map/world sprites whose global ids collide with that band. Always disassemble the caller.

### 2. UI graphic-key → image switch

- **Address:** `0x4A5960` (`int __cdecl`, single stack arg)
- **Jump table:** `0x4A6F2C`
- **Domain:** arg `∈ [0, 0x7E6]`; out-of-range / many empty cases return `-1` (`or eax, -1; ret` at `0x4A6F28`)
- **Consumers (examples):** `0x448FE5`, `0x44922F`, `0x4492C6`, `0x50BEC9`, and via `0x498720` → `0x526790`
- **UI records:** BSS base `0x1192B88`, stride `0x40`. Callers typically `movsx` the first `int16` of a record and pass it as the switch key.
- **Record init / copy:** `0x546F00` area copies `0xC` dwords from a template into the record when `ebx ≠ 0`; otherwise fills the first three words with `-1`.
- **Classification:** `confirmed` as a UI-key → image (or validity) mapper.

**Critical rule for agents:**

> Indexing `0x4A5960` with raw `EmperorBuildingModels` / native `buildingID` does **not** recover construction Bbutton bases. For catalog bases `#1491–#1575`, `switch[base]` is typically `-1`. Late keys in the `#1577+` band often map into 3-state China_Interface families (`#1580+`), but the **key is the UI-record field**, not the building id.

### 3. Hardcoded building model table (no graphics)

- **VA:** `0x86D580` (file `0x46D580`)
- **Stride:** `52` bytes = `13 × int32`
- **Content:** Matches `GameData/Model/EmperorBuildingModels.txt` fields **a–m** (cost, desirability, employment, fire/damage increments, etc.)
- **Graphics:** **None** in this blob.
- **Classification:** `confirmed`

`EmperorBuildingModels.txt` itself states values are for hardcoding back into the compiled binary; that comment does **not** imply a parallel button-image table in the same file or adjacent 52-byte records.

### 4. Monument / wall-ish triple writer (not city catalog)

- **Address:** `0x4B0010`
- **Shape:** `arg -= 0x4C`; if `arg > 0xC0` fail; else byte table `0x4B01D0` → jump table `0x4B019C`; writes three `u16` image ids into caller-supplied pointers.
- **Images:** Often `#1631+`, many past city Bbuttons into WorldSide-range ids.
- **Caller:** `0x4B0376`
- **Classification:** `confirmed` as a specialized filler; **not** the housing/industry/commerce build-menu mapper.

### 5. Archive name list (load only)

- String `China_Interface` at file `0x42B19C` / VA `0x82B19C`
- Referenced while building a name list around `0x475C47` (with sibling archive name pointers)
- **No** `Bbuttons` / `New_Bbuttons` string in the exe
- **Classification:** `confirmed` load-path evidence only

### 6. UI-record add / clear (the only writers of `0x1192B88`)

- **Add:** `0x546EA0` (~110 `.text` call sites; **none** in `0x530xxx`)
  - Args (cdecl, bottom→top on stack before call): `type`, `arg1`, `arg2`, `template*`, `extra` (often `-1`)
  - Observed `type` immediates: `0xDC`–`0xE3` (`0xE0=224` most common)
  - Allocates slot index, then `index << 6` (stride `0x40`)
  - Record layout (relative to slot base `index*0x40`):
    - `+0x1192B82`: `type` (`int16`)
    - `+0x1192B88`: start of 48-byte payload (`0xC` dwords)
    - First `int16` of payload = **UI graphic key** consumed by draw via `0x4A5960`
  - If `template == NULL`: writes `0xFFFF` into the first three payload words
  - If `template != NULL`: `rep movsd` copies `0xC` dwords from template → `0x1192B88 + index*0x40`
- **Clear all:** `0x547580`
  - Walks `0x1192B88` … `< 0x11A2588` stride `0x40`; clears type word at `record-6` and sets graphic key to `0xFFFF`
  - Zeroes counts at `0x1192B30` / `0x1192B34`
  - Callers (5): `0x42E973`, `0x42EE61`, `0x535569`, `0x535721`, `0x5475F2`
- **Post-clear at `0x42E973`:** `0x4941E0` → stub `0x40FC20` (`ret`) → `0x495610` → `0x436560`
  - `0x495610` rebuilds an **existing-object** id list at `0xC702E0` (stride 8), filtered by `0x4A0360` — **not** construction-catalog Bbutton fill
- **Classification:** `confirmed` for add/clear mechanics; `confirmed` that `0x42E973` rebuild is not the city build-menu catalog

### 7. `0x4A5960` coverage of the Bbutton band (draw gate)

Draw consumers (`0x448FB0` loop, `0x449213`, `0x50BEC9`, …) do:

1. `movsx` first `int16` of record at `0x1192B88 + n*0x40`
2. `call 0x4A5960` — if return `< 0`, **skip draw**
3. Pass the **key** (not always the mapped image) into helpers such as `0x498720` → `0x526790`

Full jump-table invert (`0..0x7E6`):

| Result | Count / note |
| --- | --- |
| Maps to China_Interface late Bbuttons `#1580–#1654` | 36 keys (`1577→1580`, `1578→1581`, … pattern often **key → image = key+3**) |
| Maps to any early catalog base `#1491–#1575` | **0** |
| Using early base **as key** | returns `-1` (record would not draw on this path) |

**Classification:** `confirmed`

**Agent rule:** A `0x1192B88` record whose graphic key is `#1491` / `#1528` / etc. cannot be how the original paints those construction icons on the `0x4A5960`-gated path. Late entertainment/military-style Bbuttons *can* appear through this path via the key→image+3 map.

### 8. Focused pass: generic record helpers and sprite-id collisions (2026-08-11)

The follow-up xref pass was deliberately limited to the unresolved question: can the generic UI-record helpers be the missing construction-panel path?

- `0x497A00` returns the active record pointer as `0x1192B88 + (0x1192B24 << 6)` (unless the temporary override at `0xC7F85C` is set). It has 35 direct callers. The accessor is shared by text/status and interaction code; it is not a construction-list iterator.
- `0x50D29D` reads the active record's three payload `int16` values (`+0`, `+2`, `+4`) and sends them to `0x498610`, which performs a bounds-checked list lookup followed by `0x526350` bracketed-string expansion. It then draws fixed interface sprites (`#1E15`, `#1E19`). This is a diagnostic/status-text path, not a Bbutton image resolver.
- `0x498720` is likewise not a resolver. Its confirmed sequence is `0x4A5960(key)` → `0x526790(result)` → `0x526350(...)`. `0x526790` only checks `0 <= index < [ecx+0xC]` and returns `[[ecx+4] + index*4]`; `0x526350` parses string substitutions. Neither helper produces a `China_Interface` frame id or a `buildingID → buttonBase` mapping.
- Numeric collisions remain reproducible in the world renderer. For example, `0x4226F0` (`0x422721`) and `0x4237E0` (`0x423811`) push `0x603` (`1539`, inside the Bbutton band) to `0x408170`, immediately read/write per-tile state at `0xF6A9E0` / `0xF6AD70`, mask `0x40`, add terrain-state offsets, and store results in `0xFE9880` / `0xFE9C10`. These are map/world sprite paths, not construction UI draws.

**Conclusion:** this pass rules out three more tempting shortcuts (`0x497A00` active-record access, `0x498720`/`0x526790` list helpers, and the `0x603` world calls). The actual right-panel construction grid draw/writer is still unresolved; no catalog evidence class is upgraded.

### 9. Focused pass: catalog cross-ref, computed ids, panel markers, builder RTTI (2026-08-11)

Scratch outputs (local only): `.agent_scratch/exe_research_cursor/`. Binary SHA-256 re-checked before scans.

#### 9a. Direct `0x408170` chain vs early catalog bases — `confirmed` negative

- `.text` has **3025** `call 0x408170` sites.
- Classifying pre-call immediates in `#1488–#1655` yields many mid-band hits (`#1539`, `#1547`, `#1554`, `#1566`, …), but **zero** `push`/`mov reg, imm` of the early catalog bases `#1491`, `#1494`, `#1528`, `#1531`, `#1534`.
- The sole `.text` imm32 encoding of `#1491` / `0x5D3` is at file bytes decoded near `0x76CCCE` inside CRT-style character classification (`cmp bl, 0x2A` / `'I'` / `'h'` …) — **not** a UI image load. **Classification:** `confirmed` false positive.
- `#1566` (`0x61E`) has multiple `push` → `mov ecx, 0x1C42130` → `call 0x408170` sites (e.g. `0x421F09`, `0x421F9A`, `0x422034`) that immediately touch tile state (`0xF6A9DC` / `0xF6A9E0`). **Classification:** `confirmed` world-sprite collision, not construction-panel draw.
- Sibling helper `0x408100` (same object, different id unpack; **155** callers) has **no** Bbutton-band immediates in the pre-call window.

#### 9b. `0x4A5960` body returns — early vs late — `confirmed`

Disassembling `mov eax, imm; ret` stubs inside `0x4A5960`…`0x4A6F28`:

The shared failure stub at `0x4A6F28` is `or eax, -1; ret`. Every early construction base tested (`#1491–#1575`, including the current catalog candidates) dispatches to that stub, so it returns **`-1`**, not image `0`.

| Input/key band | Valid Bbutton images returned |
| --- | --- |
| Early construction bases `#1491–#1575` | **0**; the key returns `-1` |
| Late keys whose cases return China_Interface Bbuttons | **36**, covering image outputs `#1580–#1654` (the contiguous three-state families) |

Category-rail images **do** appear as switch returns (e.g. `0x4A6B88`: `mov eax, 0x527` → `#1319` monument; nearby `#1311–#1335`-class values). So category tabs can live on the UI-record path while early build-grid icons cannot.

#### 9c. Register/`×3` / category-start hypotheses — not found

| Hypothesis | Result |
| --- | --- |
| `1488+3*i` / `lea r,[r+r*2]` then `add` Bbutton imm | No genuine hit; prior “computed candidates” were CRT / unrelated LEAs |
| File-backed `buildingID → base` as u8 sheet-index, u16 base, `base-1488` delta, xor/neg | No table scored ≥8–10 against `OriginalConstructionButtonSpriteCatalog` |
| Commerce bid run `54,66,53,47,65,67,59` as u8/u16 | Absent from `.rdata`/`.data` |
| Category-start u16/u32 sequence `[1491,1497,1515,1528,1551,…]` | Absent |
| Model blob `0x86D580` ±8K adjacency with catalog bases at strides 2..64 | No score ≥8 |
| Naked `push` of category bases `#1323…#1359` | **0** sites (same “not a flat immediate” pattern as early Bbuttons) |

Catalog-side observation only (**not** exe-confirmed): within each construction category, the *inferred* bases are spaced by multiples of 3 from that category’s minimum — consistent with sheet families, but no matching per-category start table was recovered from the PE.

#### 9d. Panel geometry markers near `0x408170` — false lead

Sites with `push 0x36` (54) near `call 0x408170` (cluster around `0x40B65F`→`0x5288E0` blit, then `push 0x1E15; call 0x408170`) draw **fixed chrome** ids `#0x1E14`/`#0x1E15`/…, not `#1491+`. Width 54 is reused; it does **not** identify the construction Bbutton grid. No `push 0x36` + `push 0x35` (54×53) pair feeds the blit helpers `0x5288E0` / `0x528890`.

#### 9e. String / RTTI cross-ref

| Symbol | VA | Role |
| --- | --- | --- |
| `RightPanel` | `0x88156C` | **WON lobby** (`LoginScreen.cpp` / `WONAPI`) — not city right rail. One `.text` imm xref `0x6B3233`. |
| `China_Interface` | `0x82B19C` | Load-name list only (`0x475C47` → `0x5CCDF0`); still no `Bbuttons` / `New_Bbuttons` string in the exe (name exists in SG3: `China_Interface_New_Bbuttons.BMP`). |
| `cBuildingBuilder` family | TDs e.g. `0x817780` | Recovered vtables (e.g. `0x7AB79C`) are placement/builder methods; scanned slots show **no** early Bbutton immediates (one unrelated `#1224` in `cAdminCityBuilder`). WON `*Button*` RTTI is lobby UI. |

Documented grid at `0x854030` is still a **data** placement/orientation blob (small integers), not a code vtable of image getters.

#### 9f. Runtime

Embedded Wine exists at `…/SharedSupport/wine/bin/wine`, but no in-process dump was taken this pass (avoid Wine prefix persistence). Static negatives above do not depend on runtime.

**Conclusion:** new methods (1)–(3) from the agent brief were executed; none recovered `buildingID → China_Interface_New_Bbuttons base`. Early catalog rows remain `inferred`; full map remains `unknown`. Next work should prioritize **runtime observation** of the live construction grid object after opening a category, or finding a non-`0x1192B88` button-list allocator that stores image ids without embedding `#1491+` as PE immediates.

### 10. Runtime probe — executable starts (2026-08-11)

Cursor's follow-up used the embedded Wine runtime with a temporary prefix outside the repository (`/tmp/emperor-exe-research-13804`) and a cloned game tree whose `Emperor[EN].exe` hash matched the reference hash. This is an environment check only; the prefix and clone are not runtime dependencies.

- `Emperor[EN].exe` reached the original main menu in a `1024 × 768` game window (macOS window bounds were `1024 × 796` including the title bar). `Emperor.ini` was changed only in the temporary clone to set `PlayIntroMovie=no` for the probe.
- After Rosetta 2 was installed, `arch -x86_64 wine32on64 --version` returned `wine-5.0` and the hash-matched executable displayed normally. The Wine window is not exposed as a standard accessibility app, so interaction used the permitted low-level mouse-event path and reached the tutorial city and 商业 page documented in §12.
- A read-only `lldb -p <Wine preloader PID>` attempt stopped at `process attach` and produced no memory reads for `0x1192B30`, `0x1192B88`, or `0x82B19C`. No process memory was patched. `winedbg` is not present in the bundled prefix.

**Classification:** `confirmed` as a runtime-environment result; partial live slot artwork is now `confirmed` for §12, while the full `buildingID → base` map remains `unknown`.

### 11. Runtime remount + asset tables (2026-08-11, later)

Second Cursor pass prioritized LLDB/temp-exe logging and GameData cross-check. Artifacts: `docs/exe-research/construction-panel-mapping.*`, `construction-bbutton-families.*`, `README.md` runtime section.

| Step | Result |
| --- | --- |
| Temp clone + hash check | `confirmed` match `8a6d2df1…6753` under `/tmp/emperor-exe-research-27045/game` |
| `arch -x86_64 wine32on64 --version` | `confirmed`: `wine-5.0` after Rosetta 2 installation |
| Wineskin `open` / launcher | `confirmed`: original main menu visible in a temporary prefix |
| LLDB breakpoints / UI clicks | UI walk reached tutorial 商业 page; no live semantic mapping dump yet |
| Temp trampoline | Recipe + unpatched copy only (`.agent_scratch/exe_re/trampoline-recipe.json`); install exe untouched |
| `China_Interface` INDEX/SG3 | **45** confirmed 54×53 Bbutton families; no `buildingId`/`slot`/`screenRect` |
| `map_panels.555` | `confirmed` map-**editor** panel in `China_Unloaded.sg3` — **not** city construction rail |

**Classification:** asset sheet geometry `confirmed`; authoritative construction mapping still `unknown`; runtime interaction is available under Rosetta/Wine and has produced the partial 商业 capture in §12.

### 12. Runtime construction-panel capture (2026-08-12)

With Rosetta 2 installed and the hash-matched temporary clone running under
Wine 5.0, the tutorial city was entered through the original Chinese front
end. A direct screen capture of the **商业** tab shows three live construction
slots in the first row. Their artwork matches the exported Bbutton families by
pixel structure:

| Runtime slot | Live family | Asset evidence | Semantic building ID |
| --- | --- | --- | --- |
| row 1, col 1 | `#1533–#1535` | direct runtime capture + `China_Interface_New_Bbuttons` | `unknown` |
| row 1, col 2 | `#1536–#1538` | direct runtime capture + `China_Interface_New_Bbuttons` | `unknown` |
| row 1, col 3 | `#1539–#1541` | direct runtime capture + `China_Interface_New_Bbuttons` | `unknown` |

The capture confirms that these families are actually consumed by the live
city construction rail; it does **not** prove the native sheet-order guesses
(`53` mill, `47` weaver, `65` ceramics). The original runtime category is
商业, while the current tutorial only exposes three slots and does not expose
the fourth `#1542–#1544` family observed in the longer video. Keep all three
building associations `unknown` until a slot tooltip, authored menu record, or
additional runtime state identifies the corresponding building IDs. The
temporary screenshot remains outside the repository as required by AGENTS.md.

## Exhausted negative searches (do not re-litigate without a new method)

Unless you have a new encoding hypothesis, treat these as **done**:

1. **GameData** — no `buildingID → buttonBase` table; SG3 `China_Interface_New_Bbuttons` is an unnamed sheet `#1488–#1655` (logical group 183), not a per-building named list.
2. **File-backed PE arrays** — no u8/u16/u32 array indexed by buildingID matching `OriginalConstructionButtonSpriteCatalog` (including a catalog-pair score scan over `.rdata`/initialized `.data` for strides 2..52).
3. **Interleaved pairs** — no `(bid, img)` or `(img, bid)` sequences for the commerce stretch (`54/1528`, `66/1531`, …).
4. **Genuine immediates for early bases** — `#1491`, `#1528`, `#1531`, … have **no** reliable `.text` `push imm32` / `mov r32, imm` / `mov dword [...], imm` loads that feed UI-record templates. Naive `find(u32)` hits are usually:
   - consecutive phrase/message id tables in `.data`,
   - instruction displacements / relative immediates (`0F 8D`, `E8`, `8B 86`, …),
   - **world** `push imm; call 0x408170` paths whose numeric ids collide with the Bbutton band (e.g. `0x601`==1537).
5. **`1488 + 3 * i` init loop** — not found as `imul …, 3` near `1488` / `0x5D0`.
6. **`0x530xxx` and `0x1192B88` fill** — **no** `call 0x546EA0` in `0x530xxx`. Save/load touches nearby header `0x1192B30` (~10 sites), not category menu construction of graphic keys.
7. **Construction-category open → many `0xE0` records with early Bbutton keys** — surveyed all dense `0x546EA0` clusters and type-`0xE0` callers; template keys in those fills are advisor/overlay-style ids (e.g. `0x7A0+`, `1038+`, late `#1577+` / monument `#1631+`), **not** housing/commerce `#1491–#1554`. Combined with §7, treat “build catalog icons live in `0x1192B88`” as a **refuted** hypothesis for early bases.
8. **Register-computed `1488+3*i` / `lea *3` + Bbutton add** — §9c; no genuine construction-panel hit.
9. **Catalog-pair / sheet-index / delta / xor tables** in `.rdata`/initialized `.data` and model-adjacent windows — §9c; no match to `OriginalConstructionButtonSpriteCatalog`.
10. **`RightPanel` / WON `*Button*` RTTI** — lobby only (§9e); not city construction.
11. **`push 0x36` (54) near `0x408170`** — chrome blit path `#0x1E14+`, not Bbuttons (§9d).
12. **Naked category-rail immediates `#1323+`** — also absent; category icons resolve via `0x4A5960` returns instead (§9b).

## Native catalog evidence status

Implementation: `Sources/EmperorCore/InterfaceSpriteCatalog.swift` → `OriginalConstructionButtonSpriteCatalog`.

| Band / rows | Status | Notes |
| --- | --- | --- |
| Sheet family layout (54×53, normal/hover/selected ×3) | `confirmed` | From SG3 export / sheet geometry |
| Direct selector/building rows | `confirmedDirectFromExecutable` | `0x53A760` + table `0x855888` + `0x449C10` draw path |
| Submenu members sharing a selector family | `confirmedSubmenuFamilyFromExecutable` | `0x403C80`, group table `0x821164`, singleton collapse at `0x53A690` |
| Full category/selector/family map | `confirmed` | See `construction-panel-exe-mapping.md`; no absolute image-ID table exists |

**Current agent rule:** Treat only the direct and shared-submenu rows recorded in
`construction-panel-exe-mapping.md` as executable-confirmed. The former warning
not to present the dictionary as recovered applied before `0x53A760` and
`0x449C10` were found; it is superseded. Rows outside the recovered tables must
still remain `unknown` rather than being filled from sheet order.

## Related exe notes already used elsewhere

Fire / collapse maintenance distribution (separate from Bbuttons): native comments in `CityOperationsSimulation.swift` cite `0x42D9A0` / `0x42A3F9` for global slot + `1...Multiplier` scaling. Keep maintenance RE and UI-button RE notes distinct.

Builder RTTI (`cBuildingBuilder`, `cEliteHouseBuilder`, `cFortBuilder`, …) vtable\[9\] tables (e.g. `0x854030`) are **placement/orientation grids**, not Bbutton image maps. Do not confuse them with construction icons.

## Next read-only steps (after mapping recovery)

1. Recover the remaining terrain-fit, material-total, construction-worker,
   and save/replay contracts for the complete Great Wall layout IDs
   `253…268`; their full-layout placement callback is now confirmed in
   `construction-panel-exe-mapping.md`.
2. Verify mission lock/disable feedback and original tooltip text for one
   direct, one singleton-collapsed, and one multi-member submenu state.

## Change log

| Date | Change |
| --- | --- |
| 2026-08-11 | Initial write-up from read-only Capstone/PE scan: `0x408170`, `0x4A5960`, model blob `0x86D580`, `0x4B0010`, negative table searches, catalog evidence classes. |
| 2026-08-11 | Traced `0x546EA0` / `0x547580` as sole `0x1192B88` writers; excluded `0x530xxx` serializers and `0x42E973` object-list rebuild; inverted `0x4A5960` (no early Bbutton images); refuted early-catalog fill via UI records. |
| 2026-08-11 | Focused xref pass ruled out the generic active-record/text helpers (`0x497A00`, `0x498720`, `0x526790`, `0x526350`) and documented concrete `0x603` world-sprite collisions at `0x422721` / `0x423811`; construction-panel draw path remains open. |
| 2026-08-11 | §9 catalog/computed-id/panel/RTTI pass: early bases absent as `0x408170` immediates; `#1491` sole imm32 is CRT false positive; `0x4A5960` routes early bases to `-1` / exposes 36 late Bbutton image outputs; table and `×3` scans negative; `RightPanel` is WON lobby; `push 54` near helper is chrome `#0x1E14+`. Full `buildingID → base` still `unknown`. |
| 2026-08-11 | Runtime probe reached the original main menu in a temporary Wine prefix, but input automation and read-only `lldb` attach did not reach or dump the construction grid; no mapping evidence recovered. |
| 2026-08-11 | §11: remount initially blocked by missing Rosetta; after installation, Wine 5.0 and the original main menu were verified. Interactive category capture continued in §12. |
| 2026-08-12 | §12: entered the tutorial city and directly matched live 商业 slots to `#1533–#1541`; slot semantics remain `unknown` and the screenshot stays outside the repository. |
| 2026-08-12 | New Ghidra corpus recovered `0x53A760` → `0x855888` compact selector/family writer, `0x449C10` draw consumption, `0x403C80` group lookup, and `0x821164` members. Full mapping is recorded in `construction-panel-exe-mapping.md`; prior unknown/inferred conclusions are superseded. |
| 2026-08-13 | Recovered `0x53A640`'s four singleton-collapse groups, `0x53A5D0/0x53A4E0` dynamic monument task matching and `0x53A760` hole/support behavior, plus the `0x5DB960/0x5DB9C0/0x5DBA20` land/sea trade-city selector path. |
| 2026-08-13 | Closed the `253…268` placement callback: these are sixteen complete authored Great Wall layouts, not phases; recorded task `85` earthen versus task `86` stone selection and the remaining unknown construction contract. |
