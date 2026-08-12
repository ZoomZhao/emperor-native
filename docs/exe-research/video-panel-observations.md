# Construction panel observations from `BV1uau26gEVV.mp4`

These observations come from local video frames, not from the executable's
writer path. They are therefore `videoObserved`: useful for reproducing the
visible panel, but not sufficient to promote a `buildingId → imageId` row to
`confirmed`.

The video is 1920×1076. The right-panel grid was sampled at local panel slots
corresponding to three 54×53 button columns. Template matching against
`GameData/DATA_IMAGES/China_Interface/008_China_Interface_New_Bbuttons` was
done at the native frame size; hover/selected state can shift the reported id
within a three-frame family.

## Observed category snapshots

| Video time | Visible category | Observed button frames by row (left → right) | Notes |
| ---: | --- | --- | --- |
| 00:02:50 | 住宅 | `1492, 1494` | `1492` is a state of the house family; the normal family starts at `1491` |
| 00:03:40 | 农业 | `1499, 1500, 1503` / `1512` | Distinct crop families are visible; `1512` is fishing-quay art in the next row |
| 00:04:40 | 美化 | `1626, 1629, 1632` / `1635, 1638, 1641` | Six decorative entries visible in a 3×2 grid |
| 00:05:00 | 工业 | `1516, 1519` / `1524, 1527` | Clay/stone families plus furnace and logging families |
| 00:05:10 | 安全 | `1552, 1554, 1557` / `1560, 1563` | Water/health/security entries; availability is mission-specific |
| 00:05:30 | 行政 | `1569, 1572` / `1575, 1578` | Civic entries; `1578` is a previously orphaned family start |
| 00:05:50 | 娱乐 | `1585, 1587, 1590` / `1593` | Music/acrobat/drama and an additional entertainment entry |
| 00:06:10 | 宗教 | `1596, 1599, 1602` / `1606` | Religious family states; `1606` is the academy/elder portrait family state |

An independent agriculture snapshot from
`local/BV1Au4y1T78t.mp4` at approximately `00:03:00` shows the same right
panel with six visible entries: ordinary field (`#1497` family), rice (`#1500`),
hemp (`#1503`), hunting camp (`#1506`), orchard (`#1509`), and fishing quay
(`#1512`). This second
source is the reason the hemp-family assignment is now medium confidence
rather than a single-video guess.

Times are representative samples from the local file and should be treated
as approximate because the source video changes categories while the cursor
and hover state are active.

## What this changes

1. The visible grid is mission-filtered. A category can show only four to six
   entries even though the native catalog contains more possible tools.
2. The agriculture panel disproves a blanket “all non-rice crops use #1497”
   rule for video fidelity: the video visibly includes the `#1503` family.
   The exact crop/building ID behind each frame still needs a source data row or
   runtime writer capture.
3. Button state matters. A frame such as `#1492` or `#1516` can be the
   hover/selected member of a family; matching only the first sheet frame will
   produce a visually wrong icon while the cursor is over the button.
4. The category rail and panel remain stable while the advisor/status text
   changes above the grid. This supports keeping category selection, mission
   availability, and button-state rendering as separate state machines.

## Implementation guardrails

- Keep the existing three-state family model, but expose the family start and
  state offset explicitly rather than treating every catalog `imageId` as a
  normal frame.
- The high-confidence crop-family correction is now centralized in
  `OriginalConstructionButtonSpriteCatalog.cropImageID(for:state:)`: field
  crops use `#1497`, rice uses `#1500`, hemp uses `#1503`, and orchard crops
  use `#1509`. This fixes the observed hemp icon without claiming that the
  entire mission list has been recovered.
- Do not fill the agriculture list from `NativeConstructionTool` alone. Add a
  mission/data-driven crop entry list when the underlying source row is found.
- Preserve the original panel's stable 3-column geometry and allow rows to be
  absent; do not synthesize empty buttons for unavailable mission entries.
- Use the video only to validate visible ordering and state transitions. The
  `BUILD_*` table and executable/runtime traces remain the authority for
  semantics and IDs.
