# Folio

A nested-category, Blizzard-native list view for your WoW inventory.

Folio replaces the default bag grid with a hierarchical text list —
nested, user-organized categories you sort items into by hand (drag an
item onto a category to file it there, permanently remembered), plus
drag-to-transfer between bags, personal bank, and warband bank. Native
Blizzard look and feel throughout — no custom art, no theme system.

Spiritually descended from [Baud Manifest](https://www.curseforge.com/wow/addons/baud-manifest)
(Public Domain), rebuilt clean-room against current Retail APIs.

**Status:** early alpha, core loop working and live-verified in-game —
categories, bag/bank/warband browsing, drag-to-recategorize and
drag-to-transfer, category reordering, gold tracking, native bag
replacement (the B key opens Folio). Still missing: cross-character
rollups, stack-move modifiers, an Options panel, and an opt-in
auto-sort helper.

## Development

- Retail only, Interface `120007, 120100` (targets both the live 12.0.7
  client and the upcoming 12.1.0).
- `Logic/` and `Data/` are pure Lua with zero WoW API references —
  testable under [busted](https://lunarmodules.github.io/busted/) without
  a WoW client. `Core/API.lua` is the only file allowed to touch WoW
  globals directly; `Data/` reaches WoW state only through an `api`
  parameter injected by its caller, never directly.
- Run tests locally with `Tests/run.ps1` (Windows) or `busted Tests/spec`
  once Lua/LuaRocks/busted are on `PATH`. Lint with `Tests/lint.ps1` or
  `luacheck Core Data Logic UI Tests` (config in `.luacheckrc` — enforces
  the WoW-globals boundary above far more thoroughly than the CI
  grep-based check alone, which stays as a fast, dependency-free
  first pass).
- CI runs the grep lint + luacheck + busted on every push; releases are
  gated on a green build and packaged via the
  [BigWigs packager](https://github.com/BigWigsMods/packager).

## License

[CC0 1.0 Universal](LICENSE) — public domain. Mirrors Baud Manifest's
original license.
