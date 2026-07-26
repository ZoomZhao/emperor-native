# Repository Instructions

## UI design source of truth

Before making any user-facing UI change, read the repository-root `DESIGN.md` in full. This applies to SwiftUI views, AppKit bridges, layout, styling, colors, typography, icons, animations, assets, copy hierarchy, loading/empty/error states, and accessibility presentation.

- Treat the YAML design tokens in `DESIGN.md` as normative. Reuse or extend centralized theme values instead of adding one-off colors, radii, spacing, or component styles inside individual views.
- Preserve the distinction between the classic player-facing game shell and the native diagnostic/library surfaces described in `DESIGN.md`.
- Prefer existing classic components and interaction patterns before introducing a new visual pattern.
- Preserve stable accessibility identifiers and keyboard workflows used by UI smoke tests.
- Original game files live in repository-root `GameData` for local development/tests, and `package-app.sh` copies that tree into the app bundle Resources so installed builds can launch directly.
- If a UI task intentionally changes the design system, update `DESIGN.md` in the same change and explain the deviation. Accessibility, platform conventions, and functional correctness take priority when they conflict with a visual rule.
- For material UI changes, build the macOS target and perform proportionate visual verification. Use the existing UI smoke/release scripts when the affected flow is covered by them.
