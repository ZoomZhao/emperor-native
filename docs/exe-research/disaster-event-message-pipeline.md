# Disaster event-message pipeline

## Scope

This note records the read-only search for the original player-message
selection used by campaign drought (`CampaignEventKind` 4) and flood (5).
It does not authorize a Native player message for either event.

## Confirmed authored phrases

`GameData/Model/EmperorEventmsg.txt` is GB18030. Its disaster families are:

- flood, lines 1476–1483:
  `PHRASE_flood_title`, `PHRASE_flood_initial`,
  `PHRASE_flood_phrase_by_hero`, `PHRASE_flood_phrase_no_reason`, and their
  three `PHRASE_CONDENSED_*` rows;
- drought, lines 1498–1505:
  `PHRASE_drought_title`, `PHRASE_drought_initial`,
  `PHRASE_drought_phrase_by_hero`, `PHRASE_drought_phrase_no_reason`, and
  their three `PHRASE_CONDENSED_*` rows.

`GameData/Model/EmperorEventMessageCategories.txt` assigns the flood and
drought title keys to category 1, City Catastrophes. The key suffixes alone
do not establish when the original selects `initial`, `phrase_by_hero`, or
`phrase_no_reason`.

## Confirmed executable pipeline

The hash-identified executable uses these functions:

- `Model_EmperorEventmsg_txt` / `FUN_004985D0 @ 0x4985D0` calls
  `FUN_00526430 @ 0x526430` to parse
  `Model\\EmperorEventmsg.txt` into the phrase resource;
- `FUN_004987D0 @ 0x4987D0` separately parses
  `EmperorEventMessageCategories.txt`;
- `FUN_004A5960 @ 0x4A5960` dispatches numeric phrase IDs through the
  original phrase-constructor jump table;
- `FUN_00498610/650/720/770 @ 0x498610/0x498650/0x498720/0x498770`
  render the selected phrase into a caller buffer and observe the original
  full/condensed preference;
- `FUN_00526350 @ 0x526350` expands bracketed variables through a registered
  token-resolver table;
- `FUN_00546EA0 @ 0x546EA0` appends one 64-byte message record. Recovered
  fields include value words at `+0x00/+0x04`, date at `+0x08`, message type
  at `+0x0A`, flags/read state at `+0x0C/+0x0D`, twelve `UInt16` phrase IDs at
  `+0x10...+0x27`, and a sorting key at `+0x28`.

The message panel functions consume phrase IDs already present in that
record. The transfer from the record's twelve-ID array to rendered strings is
classified `inferred`: the producer/consumer layouts agree, but this pass did
not recover symbolic types for the complete structure.

## Blocked writer search

The local split decompilation contains no drought/flood phrase-key strings;
the external text file is loaded by numeric ID. Targeted searches of the
message-record writer call sites and the campaign event functions did not
recover the function that maps campaign kind 4 or 5 to the disaster phrase-ID
array. Therefore all of the following remain `unknown`:

- kind 4/5 to full or condensed phrase IDs;
- selection among `initial`, `phrase_by_hero`, and `phrase_no_reason`;
- whether campaign-record flags, month/year, amount, or `timeAllowed` affect
  that selection;
- the complete registered variable set and missing-variable fallback;
- onset, update, and end-message timing.

The result is `BLOCKED`, not a negative claim that the authored phrases are
unused. Native must keep drought and flood player messages fail-closed until
the writer/selector is recovered by runtime tracing or a new control-flow
cross-reference.
