# Canonical executable random-state boundary

## Scope

This note records the shared random primitive recovered from the canonical
English executable (`sha256 8a6d2df1015cb75d797546d117da5f82b86fd08726090c2a13d853b9009d6753`).
The Chinese executable (`sha256 dbdeca1ec2720f2387e1673bfbb901e9bad832179355ea897cfa7536e17ac15a`)
has the same function in `local/source/compare-report.tsv`.  The implementation
is a pure state boundary only; it is not wired into campaign event scheduling,
because the original call order for that scheduler is not recovered.

## Recovered control flow

`FUN_004189b0 @ 0x4189b0` first stores the previously published
`DAT_010c713c` byte into the 100-entry ring at `DAT_010c6f90`, advances
`DAT_010c6f8c` with wrap at 100, and then performs exactly 31 rounds on the
two unsigned 32-bit registers `DAT_010c714c` and `DAT_010c7148`.  Each round
right-shifts both registers; a register receives `0x40000000` when bit 4 and
bit 0 differ before the shift.  The routine then publishes:

* primary `& 0x7fff`, `& 0x7f`, and `& 7` (`DAT_010c7138`, `DAT_010c713c`,
  `_DAT_010c7140`);
* secondary `& 0x7fff`, `& 0x7f`, and `& 7` (`_DAT_010c712c`,
  `_DAT_010c7130`, `_DAT_010c7134`).

`FUN_00529a80 @ 0x529a80` sets the ring index to zero and calls this routine
100 times.  Startup constants are assigned in `FUN_0052b590 @ 0x52b590`:
`DAT_010c714c = 0x54657687`, `DAT_010c7148 = 0x72641663`, and an unrelated
third state `_DAT_010c7144 = 0x34518632`.  The recovered random transition
uses only the first two registers.  Mission save/load code persists the first
two registers (`FUN_0052e7c0` and `campaign/cMissionLoader_serialize_dump_0xpc.c`),
not the derived masked values or the history ring.

## Native boundary and vectors

`Sources/EmperorCore/OriginalExecutableRandomState.swift` mirrors the
31-round transition, masked outputs, 100-byte history ring, and startup
warm-up.  Independent regression vectors in
`Tests/EmperorCoreTests/EmperorCoreTests.swift` assert:

* first transition: `stateA=0x292321ef`, `stateB=0x5d425705`, primary low
  values `8687/111/7`, secondary low-15 `22277`;
* after the exact 100-call warm-up: `stateA=0x0028db70`,
  `stateB=0x298b8960`, primary low values `23408/112/0`, secondary low-15
  `2400`, with ring index wrapped to zero.

## Invasion-point random-start boundary (2026-09-03)

The canonical EN body of `FUN_00522ae0 @ 0x522AE0` was checked in
`local/source/split-merged/code/0x050000/FUN_00522ae0.c` and against the
address-range disassembly of `Exe/ghidra/input/EmperorEN.exe`; the CH/EN row is
`identical` in `compare-report.tsv`.  For `param_1 == 8` it calls
`FUN_004189B0`, reads `DAT_010C7138`, masks with `0x8000000F`, and applies the
signed fallback `(value - 1 | 0xFFFFFFF0) + 1` only when the masked value is
negative.  The same function then scans the eight X-coordinate words in
circular order and returns the final index in `EAX`; the caller stores its low
byte at the selected object's `+0x78` slot.

`FUN_004189B0` publishes `DAT_010C7138 = stateA & 0x7FFF`, so the canonical
random path's masked start is the low nibble `0…15`.  `FUN_0053CEC0`'s paired
initialization loop clears sixteen X/Y words, while `FUN_0049DAF0` and the
`FUN_00522AE0` scan use only the first eight as active slots.  Therefore
starts `8…15` first inspect one initialized tail word and then wrap at eight;
they are not an undefined out-of-bounds read.  The Native
`OriginalMapInvasionPointSlotCatalog.sourceRandomStartIndex` and
`sourceRandomScanIndex` helpers preserve this raw start and eight-iteration
scan, including the post-loop returned index when all checks miss, with
independent regression vectors.  They do not wire campaign scheduling,
formation construction, or object-registry ownership.

**Evidence class:** **confirmed** for the random-call edge, mask,
normalization expression, sixteen-word initialization, eight-slot wrap,
return register, caller store, and EN/CH parity; **unknown** for the full
scheduler RNG order, formation timing, and live registry projection.  The
invasion event bridge therefore remains fail-closed.

**Overall evidence class:** **confirmed** for the transition, masks, startup
constants, 100-call warm-up, ring capacity, persisted register identities,
and the `FUN_00522AE0` random-start expression above. **Unknown** remains for
the random-call sequence used by campaign event scheduling and for the
unmapped event/formation consumers.

## Direct shared-RNG caller census (2026-09-04)

The canonical EN and CH `.text` sections were scanned for direct x86
`CALL rel32` edges targeting `FUN_004189B0 @ 0x4189B0`. The two binaries
produce the same 45 caller addresses, all marked `identical` in
`local/source/compare-report.tsv`:

```text
4189A0 43FF00 440700 441940 4420E0 442200 444490 444D40 444F60
488940 4893F0 4925F0 493530 493B60 494440 4944A0 494EA0 496E60
497670 498F60 499150 49F8B0 4A3280 4A8ED0 4A90A0 4A9300 4B0AC0
4BAB00 4E71D0 509670 522AE0 529A80 52CAF0 535540 5371A0 54DB10
54DF70 54E870 5A0340 5A0550 5C80E0 5C88E0 5C89F0 5E7140 5E7CC0
```

The list includes the event handler (`0x49F8B0`), free-event creation
(`0x4925F0`), per-step simulation (`0x5371A0`), invasion-point selection
(`0x522AE0`), startup warm-up (`0x529A80`), and unrelated trade, plunder,
figure, map, and UI paths. It is a direct-call inventory only:
function-pointer/vtable calls and their runtime branch order are outside the
indexed corpus. Native exposes the addresses as
`OriginalEventManagerRandomState.directCallerAddresses` for regression and
keeps the event scheduler on its explicit fallback stream; this census does
not authorize consuming the shared state from Qin campaign scheduling.

**Sources:** canonical EN/CH direct-call scan, `local/source/split-merged/code`
function files containing `FUN_004189b0();`, `functions-index.csv`, and
`compare-report.tsv`; `Sources/EmperorCore/CampaignEventRandom.swift`; and
`Tests/EmperorCoreTests/EmperorCoreTests.swift`.

**Evidence class:** **confirmed** for the 45 direct caller addresses, EN/CH
parity, and the named event/invasion/startup edges; **unknown** for indirect
consumers, branch-dependent call order, and the complete campaign event RNG
sequence.
