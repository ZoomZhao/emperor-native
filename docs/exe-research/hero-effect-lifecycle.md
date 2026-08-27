# Hero-effect slot lifecycle — runtime latch vs save/load migration

Read-only static inspection of the hash-identified originals and the merged EN/CH
decompilation corpus. Every function cited below is `identical` in
`local/source/compare-report.tsv` (rows 3707/3709/4725–4748/4771/4812–4829/
5011/5282/5303/7128/7154/7160/7164/7645/7656/8176–8180; no EN/CH divergence in
any function referenced here).

- Builds: EN `Emperor[EN].exe`
  `8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`
  (canonical `1024 × 768` behavior/geometry build);
  processed alongside CH `dbdeca1e…15a` for cross-check only.
- Purpose: decide whether a native "hero in city" signal can drive the
  already-confirmed hero-effect `3` (Xi Wang Mu) semantics. It still cannot yet;
  see **Decision**.
- **This note supersedes the previous draft.** The prior reading of
  `FUN_00510E60` as a *live staged-to-active activation gate* and of slots
  `1…11` as *staged candidates* is withdrawn: `FUN_00511EA0` is a
  `__thiscall` per-record save/load (de)serializer, and the `ret < 4` branch in
  `FUN_00510E60` is an **old-save migration path**, not a runtime transition.

## 1. Record storage — confirmed

- **Array**: 12 `cHero` objects at `DAT_010BFB30`, stride `0x38`. Constructed at
  `FUN_00510AF0 @ 0x510AF0` via
  `FUN_00765629(&DAT_010BFB30, 0x38, 0xC, FUN_00510D30, FUN_00510DE0)`
  (element size `0x38`, count `0xC`). Per-record constructor
  `FUN_00510D30 @ 0x510D30` installs vtable `PTR_LAB_007B5B20` /
  `PTR_FUN_007B5AD0`, zeroes the body and calls the class ctor
  `cHero @ 0x512230` (class string `"cHero"` at `0x00853C64`). Destructor
  `FUN_00510DE0 @ 0x510DE0`.
- **Serializable record layout** (recovered from the serializer `0x511EA0`,
  the creator `0x510F50`, the init-clear `0x535510` and the migration body in
  `0x510E60`; offsets relative to record base):
  - `+0x00` vtable*, `+0x04` second vtable*
  - `+0x08` int — hero figure/object ID (the created figure; gate field)
  - `+0x0C` int — serialized, semantics unknown
  - `+0x10` int — **hero/effect index** (compared by the latch predicate
    `0x5A8420` to `2/3/5/8/10`; returned by `0x5A8450`)
  - `+0x14…+0x18` five serialized `0/1` bytes — semantics unknown
  - `+0x19` byte — flag written by the creator (`param_3`), serialized
  - `+0x1C` int — serialized, semantics unknown
  - `+0x20` byte — **ACTIVE** (latch)
  - `+0x24` int — serialized; init-clear writes `0xFFFFFFFF`
  - `+0x28` byte `0/1`, `+0x29` byte, `+0x2A` byte — init-clear writes `0`
  - `+0x2C` int, `+0x30` int — serialized, semantics unknown
- **Latch predicate** `FUN_005A8420 @ 0x5A8420(effect)` reads **only slot 0**:
  returns `1` iff `DAT_010BFB40 == effect && DAT_010BFB50 != 0`
  (`DAT_010BFB40` = slot-0 `+0x10`, `DAT_010BFB50` = slot-0 `+0x20`).
  `FUN_005A8450` returns slot-0 `+0x10`, `FUN_005A8470` returns slot-0 `+0x20`
  raw. The numeric namespace is closed twice: `0x5EBDA0` tests effects
  `2/5/8/10`; `FUN_00564E80 @ 0x564E80 → FUN_005A8420(3)` is Xi Wang Mu
  (already documented in `grand-canal-map-state.md`; not repeated here).
- **Figure ↔ slot link**: the creator stamps each hero figure object with its
  record index at figure `+0x134` (`p[0x4d]`); every "indexed" reader walks the
  array through that field (`FUN_005100F0 @ 0x5100F0`,
  `FUN_00515A40 @ 0x515A40`, `FUN_00515DF0 @ 0x515DF0`,
  `FUN_005C6DA0 @ 0x5C6DA0` case `0x4F`, `FUN_005C80E0 @ 0x5C80E0`,
  `FUN_004E6280 @ 0x4E6280`). These are queries/predicates, not writers of the
  record's active byte.

## 2. Save/load serializer — `FUN_00511EA0 @ 0x511EA0`

`int __thiscall FUN_00511EA0(record, stream)`. Confirmed serializer:
- Opens with `FUN_0040CF80` (no-op begin), `FUN_0041FC10(stream)` which in load
  mode reads a **2-byte block header** into `stream+0x04` (via
  `FUN_0041FCA0`) and in save mode writes `*(short*)stream+0x04` (via
  `FUN_0041FC50`). `ret = FUN_0041FBF0()` returns that header; the whole
  function returns it.
- Mode byte at `stream+0x14` (`FUN_0040CF90`: `~*(uint*)(stream+0x14) & 1`):
  non-zero ⇒ write; zero ⇒ read.
- **Read path** switches on the header, record-schema versions **1…4**:
  `v1` reads `+0x08/+0x0C/+0x10` + flag byte + five `+0x14…+0x18` bytes;
  `v2` also reads `+0x2C` and the trailing figure-flag/deserialized figure;
  `v3` also reads `+0x1C`, and **derives `+0x20 = 1` when `+0x08 != 0`**;
  `v4` reads the active byte `+0x20` **directly from the file**, plus `+0x24`,
  `+0x28`, the trailing figure-flag and the linked figure object (via
  collection pointer in `stream+0x30`). Field types via the serializer
  primitives: ints `FUN_004C95E0/93E0 → FUN_0042DC20/DBF0`,
  bytes `FUN_00503D50/3D80` (loads normalize to `0/1`).
- **Write path** (header left at 4) writes `+0x08,+0x0C,+0x10`,
  byte `+0x19`, `+0x2C`, `+0x1C`, byte `+0x20`, `+0x24`, byte `+0x28`,
  five bytes `+0x14…+0x18`, then a figure-presence flag and (if present) the
  linked figure object; if the figure at `+0x08` is dead it is dropped and
  `+0x08` zeroed.
- So `v4` is the **current** schema (its read order matches the write order and
  persists `+0x20`); `v1…v3` are old schemas. The header value `4` is left in
  `stream+0x04` by the tail `FUN_0041FC00(4)` of every read, which is what
  subsequent saves write. (Exact outer save-wrapper plumbing of `stream+0x04` is
  `inferred`, not traced to the top-level save entry point.)

## 3. Save/load block + migration — `FUN_00510E60 @ 0x510E60`

`FUN_00510E60` is **only ever called from the full-save dispatcher
`FUN_0052FDA0 @ 0x52FDA0`** — once in the write branch (`0x52FE8A`) and in the
read branch on file-version cases `0xD…0x13` (`0x5335E2`, `0x53068A`,
`0x530C7F`, `0x531285`, `0x531A6D`, `0x532077`, `0x532666`, `0x532E14`). It is
**not** reached from any per-frame/per-event runtime path
(`FUN_0052FDA0`'s own callers are the save/load chain: `0x42E6A0`,
`save_…0x4FD2A0`, `0x534880`, `0x4FC040`).

- **Outer scan**: `src` steps `0x38` over the 12 records, calling
  `FUN_00511EA0` once per record. The decompiled call shows only the stream
  argument; the record is passed as the `__thiscall` ECX and the decompiler
  lost the register update (`inferred`, but semantically required — otherwise
  the loop would (de)serialize one record twelve times while also stepping
  `src`). Each return is the record's just-read header; if **any** returned
  `< 4`, `flag = true`.
- **Migration body** (when `flag`): for each record `1…11` with a non-zero
  `+0x08` figure ID, copy its fields into slot 0 —
  `+0x08/+0x0C/+0x10/+0x19(+0x49 byte)/+0x1C/+0x24/+0x2C` and
  swap `+0x30` — set `DAT_010BFB50` (slot-0 `+0x20`) `= 1`, re-stamp the
  promoted figure and its companion figure back to slot index `0`
  (`p[0x4d] = 0`, `*(*p2 + 0x134) = 0`), then clear the source record's
  `+0x20` and `+0x08`.
- **Interpretation (`inferred`, strongly supported)**: a record header `< 4`
  only occurs when loading an old-format save file; the later copy is therefore
  **old-save compatibility migration** that promotes the (last non-empty)
  record `1…11` into the slot-0 latch that all effect consumers read. On save
  the write path returns header `4` for every record, so the migration never
  fires during save. It is **not** a runtime "stage → active" promotion gate
  and records `1…11` are **not** "staged candidates" — they are ordinary
  employable-hero records (see §5).

## 4. Init-clear — `FUN_00535510 @ 0x535510`

Walks all 12 records (`dst` from `&DAT_010BFB54` = slot-0 `+0x24`, stepping
`0x38`, ending before `0x10BFDF4`): clears `+0x20` (via byte at
`dst[-1]`), writes `+0x24 = 0xFFFFFFFF`, clears `+0x28`, `+0x29`, `+0x2A`.
Does **not** clear `+0x08`/`+0x10` (those survive from the just-loaded
serializer and are consumed by the figure restore). Runs at city load
(`FUN_0042E6A0`, immediately after `FUN_0054E920(0xFFFFFFFF,1)` restores
figure state) and from `FUN_005355F0` (init).
**Confirmed immediate post-call state**: right after `FUN_00535510`, `+0x20`
of every record is `0` regardless of the save value, while `+0x08`/`+0x10`
still hold the values the serializer just loaded. Whether/how the loaded figure
IDs are subsequently re-linked and `+0x20` is re-set for an already-active hero
(exact post-load respawn/reactivation sequencing and ordering) is **not
recovered**; there is no evidence of any automatic post-clear re-set, so do not
claim the active byte is re-derived after the clear. The active byte is only
ever *proven* set by the runtime creator `FUN_00510F50`, cleared by
`FUN_00514470`, and cleared by this init-clear.

## 5. Runtime lifecycle — writers of the indexed active/effect fields

Two runtime transition writers were found (via full-breadth read
of the merged corpus; see negative search in §7).

- **ENTER — `FUN_00510F50 @ 0x510F50` (cHero arrive)**. Sets record `+0x10`
  to the hero/effect identity passed through `FUN_00510C70`, sets `+0x20 = 1`,
  creates the hero figure with `FUN_004EA050` (model `0x4E`/`0x4F` by a variant
  flag, plus a second model-`9` companion figure for the "free/global"
  variant), stores the figure ID at `+0x08`, links the employer object to the
  figure, and marks the figure (state `6`, `+0x13 = (byte)hero-identity`).
  Slot selection happens in `FUN_00510C70 @ 0x510C70`: `FUN_00510E30 @ 0x510E30`
  returns slot `0` when its `param_1` is non-zero, else the **first record
  `1…11` whose `+0x20 == 0`** (`src` from `&DAT_010BFB88` = slot-1 `+0x20`,
  else `-1`); `FUN_00510F50` is then applied to the chosen record and both
  figures are stamped with the chosen slot at `+0x134`. The recovered callers
  fix the wiring:
  - `FUN_00522D30 @ 0x522D30` (monument/temple hero figure at a work site):
    passes `param_6 = 0` ⇒ slots `1…11`;
  - `FUN_005A7440 @ 0x5A7440` (global pantheon spawn): passes `param_6 = 1`
    ⇒ **slot 0**, with `param_1` = the selected pantheon entry's authored
    hero/effect identity.
- **Runtime slot-0 producer chain — `confirmed` (direct disassembly recorded by
  the primary reviewer at `FUN_005A7440`; the generated decompiler garbles the
  argument attribution here, so the machine-code reading is authoritative)**.
  At entry ECX holds the pantheon/controller object (saved to EDI); stack
  `param_1` is the selected pantheon index and `ESI = EDI + 0x28 + index*0x18`.
  `FUN_004F8260` is the `__fastcall` getter returning `*(arg+0x10)` (matches
  the recovered body `FUN_004F8260(x) = *(x+0x10)`); called on ESI it returns
  `*(ESI+0x10)`, the authored hero/effect identity. The push order for
  `FUN_00510C70` is `&slotOut, 1, y, x, employerID, 0, *(ESI+0x10)`: so
  `param_6 = 1` forces `FUN_00510E30` to return slot `0`, and `param_1` is the
  hero/effect identity. `FUN_005A8370 @ 0x5A8370` (controller `__fastcall`)
  rejects whenever `FUN_005A8470` reports slot-0 `+0x20` active, selects the
  eligible pantheon index `n` (highest `FUN_004DF630` score among entries that
  pass `FUN_00426AF0`), and calls `FUN_005A7440(n)`. Therefore the runtime
  slot-0 writer chain is:
  `FUN_005A8370 → FUN_005A7440 → FUN_00510C70 → FUN_00510F50`,
  which places the selected hero's identity into slot-0 `+0x10` and sets
  `+0x20`. **When the selected pantheon entry's identity is `3`, that is how Xi
  Wang Mu enters the slot-0 latch that `0x564E80 → 0x5A8420(3)` reads.**
- **Spawn gating — `FUN_005A8370 @ 0x5A8370`**: returns early whenever slot-0
  `+0x20` is non-zero (`FUN_005A8470`), else selects and spawns. Confirms
  **slot exclusivity**: at most one globally-active (slot-0) hero.
- **EXIT — `FUN_00514470 @ 0x514470` (cHero leave/death)**. When the passed
  figure ID equals record `+0x08`: calls the global collection remove
  (`FUN_005122C0` virtual `+0x28`), and **for slot-0 heroes only**
  (`p[0x4d] == 0`) runs the effect teardown
  `FUN_00426A60(record+0x10)` + `FUN_005A8810(record+0x10)`; kills/marks the
  figure (state `4`, clears `+0x3E`, `+5`, kills the companion via
  `+0x16 = 2`), then **clears record `+0x20 = 0`**. Reached from the Hero
  Interface Bar **Dismiss** button (`FUN_00515800 case 0x68 → FUN_00516260`),
  figure-death/action-complete handlers (`FUN_004E5A60`, `FUN_00510190`,
  `FUN_0054E920 @ 0x54E920`), and scenario/disaster cleanup
  (`FUN_005A7C40`, `FUN_00523940`, `FUN_005A8620`).

## 6. Consumers of the latch (all read-only on the records)

`0x5A8420` and its callers (effects `2/5/8/10` in `0x5EBDA0`, effect `3` in
`0x564E80`, and many more: `0x4014xx…0x5F0xxx` rule bodies); `0x5A8450/70`;
`0x4C…/0x4E…/0x5C…` indexed queries above. None write `+0x20` or `+0x10`.

## 7. Negative search — why xref-only misses the writers

Recovered literal-reference set for the hero-record globals across
`local/source/merged.c` (grouping accessor families below): `0x510AF0` (ctor),
`0x5100F0`, `0x4E6280`, `0x510C70`
(via `&DAT_010BFB38`), `0x510E60`, `0x511E20` (via `&DAT_010BFB38`),
`0x515A40`, `0x515DF0`, `0x535510`, `0x54E920` (slot-0 `+0x08` only),
`0x5A7440`, `0x5A8420/8450/8470`, `0x5C6DA0`, `0x5C80E0`. Runtime writes to
`+0x20`/`+0x10` therefore live **only in functions that address records through
computed/ECX record pointers** — `0x510F50`, `0x514470`, `0x511EA0` — so a
literal-xref search for `DAT_010BFB30` (or `DAT_010BFB40/50`) cannot find them.
This is a negative-search *result*, not an absolute proof: **no additional
writer of any record's `+0x20` or `+0x10` was found** in the recoverable merged
corpus and in the targeted vtable/predicate inspection of the record consumers;
an indirect writer reached only through code outside the recoverable corpus
cannot be strictly excluded.

## 8. Evidence classification

- **confirmed** (direct code / recorded disassembly): 12×0x38 `cHero` array +
  stride + constructor/destructor/class string; record offsets used by
  serializer/creator/clear; `FUN_00511EA0` serializer on a byte stream
  (read/write modes) whose return is the 2-byte record-header version with read
  cases `1…4` (current `4` persists `+0x20,+0x24,+0x28`, old `v3` derives
  `+0x20` from `+0x08 != 0`); `FUN_00510E60` invoked only from the save/load
  dispatcher `FUN_0052FDA0`; the migration body (records `1…11 → slot 0`,
  slot-0 `+0x20 = 1`, source `+0x20/+0x08` cleared, figure slot-stamps reset);
  `FUN_00535510` init-clear at load/`0x5355F0`; slot-0-only latch predicate
  `0x5A8420`, accessors `0x5A8450/70`; **runtime slot-0 producer chain
  `FUN_005A8370 → FUN_005A7440 → FUN_00510C70 → FUN_00510F50`** with identity
  from `*(controller + 0x28 + index*0x18 + 0x10)` via the `FUN_004F8260`
  getter, `param_6 = 1` forcing slot 0, and identity `3` ⇒ Xi Wang Mu in the
  latch (reviewer-recorded machine code; decompiler garbles these argument
  attributions); runtime enter/exit writers `FUN_00510F50` (sets `+0x20=1`)
  and `FUN_00514470` (clears `+0x20=0`, slot-0 effect teardown only, Dismiss
  path `0x515800 → 0x516260`); slot chooser `FUN_00510E30` (slot `0` forced or
  first free of `1…11` by `+0x20`); spawn gating `FUN_005A8370` rejecting a
  second slot-0 hero; figure `+0x134` slot stamps; EN/CH identical.
- **inferred** (supported but not recovered exactly): ECX record argument in
  the `FUN_00510E60` loop; `ret < 4` fires only for old-format files and the
  copy is old-save migration that promotes into slot 0; save path never
  migrates (header `4`); slot 0 is the single world-effect hero latch and slots
  `1…11` are ordinary employable-hero records; `+0x20` is the live-active latch
  (persisted by schema 4, then cleared in the recovered load chain; only proven
  set at runtime by the creator).
- **unknown**: exact trigger/gating state that makes `FUN_005A8370` select the
  pantheon entry whose identity is `3` (the worship/desire scoring in
  `FUN_004DF630`, the `FUN_00426AF0` eligibility gate, and the authored
  pantheon configuration feeding them); **post-load sequence** — what happens to
  a loaded save's already-active hero figures and their `+0x20` after
  `FUN_00535510` clears it (no path re-setting `+0x20` after the clear was
  found, so the exact reactivation/respawn ordering is unknown); mid-scenario
  clear/replacement rules beyond the recovered dismiss/death paths; exact
  semantics of `+0x0C/+0x1C/+0x24/+0x28…0x2A/+0x2C/+0x30`, the five
  `+0x14…+0x18` bytes, and the cHero vtable predicates queried at
  `+0x14…0x48`; whether any per-step boundary re-derives slot-0 `+0x20` from
  figure presence (none found).

## 9. Decision — `BLOCKED BY UNKNOWN` (no longer producer identity)

The live record-level lifecycle and the slot-0 spawn chain are now recovered:
`FUN_005A8370 → FUN_005A7440 → FUN_00510C70 → FUN_00510F50` writes the selected
hero's identity into slot-0 `+0x10` and sets `+0x20`, `FUN_00510E30` chooses the
slot, `FUN_00514470` clears the active byte on dismiss/death, `FUN_00535510`
clears it at load, and `FUN_00511EA0`/`FUN_00510E60` persist and migrate it.
The blocker is **no longer "who writes slot 0"** — it is the **native
source/state contract for actual physical live hero presence**: Native's
`activeHeroIDs` is a monotonically-growing `Set<Int>` with no hero figure
object (no `FUN_004EA050` figure, no `+0x134` slot stamp, no employer link), no
slot exclusivity (the original enforces a single slot-0 hero through
`FUN_005A8370`'s `FUN_005A8470` gate plus a first-free scan for slots
`1…11`), no dismiss/death exit transition, and no load-clear lifecycle.
Exact post-load respawn/reactivation sequencing (what happens to a loaded
active hero's `+0x20` after `FUN_00535510`) and any remaining mid-scenario
clear/replacement rules are also unknown. The live city-presence bridge
therefore stays **fail-closed**: Native must keep `activeHeroIDs` out of the
effect path and must not synthesize the physical-lifecycle pieces it does not
model. Only a physical figure-based source of state that reproduces the
recovered lifecycle contracts (enter/exit, slot exclusivity, load-clear)
would lift the block.
