# Folio

A nested-category, Blizzard-native list view for your WoW inventory.

Folio replaces the default bag grid with a hierarchical text list — nested
user categories, rule-based auto-assignment, and drag-to-transfer between
bags, personal bank, and warband bank. Native Blizzard look and feel
throughout; no custom art, no theme system.

Spiritually descended from [Baud Manifest](https://www.curseforge.com/wow/addons/baud-manifest)
(Public Domain), rebuilt clean-room against current Retail APIs.

**Status:** early alpha, not yet functional.

## Development

- Retail only, Interface `120100` (patch 12.1.0).
- `Logic/` is pure Lua with zero WoW API references — testable under
  [busted](https://lunarmodules.github.io/busted/) without a WoW client.
- `Core/API.lua` is the only file allowed to touch WoW globals.
- CI runs lint + busted on every push; releases are gated on a green build
  and packaged via the [BigWigs packager](https://github.com/BigWigsMods/packager).

## License

[CC0 1.0 Universal](LICENSE) — public domain. Mirrors Baud Manifest's
original license.
