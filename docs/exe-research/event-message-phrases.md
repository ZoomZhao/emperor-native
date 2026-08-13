# Event-message phrase source

## Supported slice

This note covers only the player-visible messages emitted for a building fire
or collapse. It does not establish the selection rules for campaign requests,
invasions, natural disasters, gifts, tribute, or strikes.

## Confirmed authored text

`GameData/Model/EmperorEventmsg.txt` is GB18030 text. After decoding, the
relevant authored rows are:

- line 1834: `PHRASE_fire_title` → `城中发生火灾!`
- line 1835: `PHRASE_fire_initial_announcement`
- line 1843: `PHRASE_collapsed_building_title` → `建筑物倒塌!`
- line 1844: `PHRASE_collapsed_building_initial_announcement`

The exact complete values are asserted directly from the shipping file in
`OriginalEventMessageCatalogTests`; they are not duplicated as implementation
constants.

The hash-identified executable loads that authored phrase file through
`FUN_004985D0` at `0x4985D0`, which passes
`Model\\EmperorEventmsg.txt` and the destination phrase table to
`FUN_00526430`.

The separate `GameData/Model/EmperorEventMessageCategories.txt` is loaded by
`FUN_004987D0` at `0x4987D0`, called from the startup function at `0x4761A0`.
That parser records the category assigned to each phrase-title key; the file
places fire and collapse in category `1` (`City Catastrophes`). The current
Native slice does not yet reproduce the original condensed/full preference
state.

## Implementation contract

- `OriginalEventMessageCatalog` decodes and parses the runtime `GameData`
  file, fails closed for missing keys, and leaves unrelated legacy model text
  parsing unchanged.
- Building failure kind `.fire` selects only the two `PHRASE_fire_*` keys.
- Building failure kind `.collapse` selects only the two
  `PHRASE_collapsed_building_*` keys.
- A known selected player account replaces `[player_name]`; without one, the
  authored placeholder remains visible rather than receiving an invented
  name.
- Native coordinate detail is omitted because no original message-field
  contract for it has been recovered.

## Unknown

- The original runtime's complete variable-substitution chain and fallback
  ruler name are not yet recovered.
- The full-versus-condensed preference, sound, auto-open behavior, ordering,
  and message lifetime are not established by this slice.
- Campaign event records require phrase-family, tone, phase, city, commodity,
  amount, and timing selection. They remain unsupported rather than borrowing
  generic Native prose.
