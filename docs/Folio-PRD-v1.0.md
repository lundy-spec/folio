# PRD — Folio

**A nested-category, Blizzard-native list view for your WoW inventory**

Version 1.1 — **implementation-ready**
Date: 2026-08-07
Status: ✅ All 18 questions resolved. Ready to hand to Claude Code.

> **Folio** — *n.* a leaf of a manuscript; a sheet folded once. Filesystem *folder* and fantasy *tome*, in one word.
> Addon folder `Folio/` · namespace `Folio` · slash `/folio` · TOC `Folio.toc`

**Changelog v1.1:** Q17 resolved → **(b) drop-target-decides**, chosen over (a) drag-to-move+right-click after live in-game prototype testing (2026-08-07). A single drag gesture expressing either intent — decided by drop location — beat requiring the user to pick a gesture *type* (drag vs. right-click) before knowing which one they wanted. §4.3 and §11 updated; no open questions remain.
**Changelog v1.0:** Q18 confirmed (three sub-groups, bank-context only) · Q14 resolved (plain taxonomy terms) · Q17 defaulted to drag-to-move with a prototype gate · §11 closed out; no blocking questions remain.
**Changelog v0.6:** Q15 resolved → **§4.3 storage sub-groups + drag-to-transfer**, now the product centrepiece (F17) · Q16 resolved → per-category storage opt-in (F18) · Q2 (no import) and Q3 (never grid) resolved into explicit non-goals · Q17 raised as a blocking UX risk · layout diagrams split banker/non-banker · sprint reordered so the gesture model precedes the ListView.
**Changelog v0.5:** Q4/Q12 resolved (bags + bank + warband) → F15/F16, storage scope selector, Q15/Q16 raised · Q9 resolved (multi-column CUT) → UI7–UI12 hardened as the sole height mitigation · Q10/Q11 resolved (pinned footer only) → CUR9 added for pin management · Q5 resolved (CC0).
**Changelog v0.4:** name resolved to **Folio** · Q13 resolved (proceed as specified, full P0 scope) · Q8 resolved (CI-first) → new §7 testing strategy, API adapter layer added to §5, first sprint reordered.
**Changelog v0.3:** competitive landscape rewritten after discovering **Ledger** and **Coffer** (§1) · Q7 → P0 · Q6 resolved.
**Changelog v0.2:** currency tracking P2 → P0 (§4.1) · §6 design direction: native aesthetic + tall/narrow form factor · unified item/currency entry model.

### Resolved so far

| Q | Question | Answer |
|---|---|---|
| Q1 | Name | **Folio.** Verified free on CurseForge. |
| Q6 | Audience | **Ship it, let it find users.** Built for you, published publicly. Polish where it bothers you; no obligation to match competitor feature depth. |
| Q7 | Rule-based auto-assignment | **Promoted to P0.** See §4.2. |
| Q8 | Testing approach | **CI-first, minimal live testing.** See §7 — this is now an architectural constraint, not just a workflow preference. |
| Q13 | Strategy vs. Ledger/Coffer | **Proceed as specified.** Full P0 scope. Competitors validate the thesis; nesting + native look remain unclaimed. |
| Q4/Q12 | Storage scope | **Bags + personal bank (incl. reagent bank) + warband bank.** Native treatment across all three. Guild bank out of scope. |
| Q5 | License | **Public Domain / CC0** — mirrors Baud Manifest's original license. Practical: `CC0-1.0` on GitHub, "Public Domain" on CurseForge. |
| Q9 | Multi-column overflow | **Cut.** Not P0, not P1. See §6.2 — the height budget now rests entirely on the remaining mitigations, which are correspondingly more important. |
| Q10/Q11 | Currency UI | **Pinned footer only.** No in-frame browsable currency list. Pin management lives in Options (§4.1). |
| Q15 | Window model | **One window. Storage sub-groups inside each category, with drag-between-sub-groups performing the physical transfer.** See §4.3 — this is the design centrepiece. |
| Q16 | Category tree scope | **One tree; each category opts into which storages it applies to.** |
| Q2 | Import BaudManifest data | **Explicitly do not.** Clean start, no legacy format reverse-engineering. |
| Q18 | Sub-group count | **Three: Bags · Bank · Warband** — visible only while interacting with a bank or warband bank. |
| Q14 | UI vocabulary | **Common category/taxonomy terms.** "Category", "subcategory", "profile", "move". Folio metaphor lives in the name, icon, and docs only — never as vocabulary the user must learn. |
| Q17 | Drag gesture | **Resolved: (b) drop-target-decides — see §4.3.** Tested live in-game against (a) drag-to-move+right-click; (b) won because one drag gesture can express either intent, decided by where you drop, instead of requiring the user to pre-commit to a gesture type. |
| Q3 | Grid-within-category | **Never.** Full commitment to the list. Anyone wanting a grid has Baganator, BetterBags, or Coffer. |

### Naming notes (branding and docs voice — not UI copy)

**Q14 resolved: none of this appears in the UI.** The interface uses plain taxonomy terms — *category*, *subcategory*, *profile*, *move*. The table below is kept only as branding and documentation voice:

| Concept | Folio term |
|---|---|
| The addon window | the Folio — *this one is fine in the UI; it's the product name* |
| A category | ~~a leaf~~ — **use "category"** (Q14 resolved: plain taxonomy terms in the UI) |
| The category tree | the **binding** — *docs only; UI says "category tree"* |
| Saved layout profile | ~~an *edition*~~ — **UI says "profile"** (direct collision with Q14) |
| Category export string | a **transcript** — *docs only; UI says "export string"* |

✅ **Settled (Q14).** Cute vocabulary users must learn is a tax. Metaphor lives in the name, icon, and docs; the UI uses plain words.

---

## 1. Context

### What Baud Manifest is

[Baud Manifest](https://www.curseforge.com/wow/addons/baud-manifest) (Project ID 4292, Public Domain, ~63K downloads, created ~2006) replaces WoW's grid-of-icons bag UI with a **hierarchical text list**. Its distinguishing bet: inventory is fundamentally a *document you read*, not a *grid you scan*.

Reviewed feature set:

| Feature | Behaviour |
|---|---|
| **List view** | Items rendered as rows (icon + name + count), not a bag grid |
| **User categories** | Manually created, **nestable** — categories can contain categories |
| **Auto-categorize** | One-shot "Categorize by Type" seeds the tree from item type data |
| **Collapse/expand** | Per-category, to manage vertical space |
| **Sort & filter** | Applied across the flattened list |
| **Slot counter** | Used/available slots shown at top |
| **Alt storage** | Persists each character's inventory + bank; viewable from any character |
| **Combined view** | Merged manifest across all known characters |
| **Bag replacement** | Hooks the backpack open; toggleable via "Replace Blizzard's Bags" |
| **Stack modifiers** | plain-drag = largest stack · shift = choose amount · ctrl = smallest stack · alt = single item · shift+ctrl = all stacks |
| **Category management** | Right-click to rename; drag out of frame + click world to delete (mirrors item-deletion gesture) |

### Why it's worth rebuilding rather than forking

- **Public Domain license** — zero legal friction on derivation, naming, or redistribution.
- **~20 years of accumulated code.** The addon predates virtually every modern WoW API surface: `C_Container`, `C_Item`, `ItemMixin`, `Enum.BagIndex`, the 12.0 Secret Values system, and modern taint/secure-frame conventions.
- **The category model is differentiated — but less than it looked.** See the landscape below; this changed materially on 2026-08-06 research.

### Competitive landscape (Retail, 2026)

⚠️ **This section was rewritten in v0.3 after finding two direct competitors that didn't surface in the first pass. Read it before committing to anything.**

| Addon | Model | Downloads | License | Status |
|---|---|---|---|---|
| Baganator | Grid, auto-categories, strong search, cross-character | High | Open | Active, strong |
| BetterBags | Grid, auto-sections (successor to AdiBags) | High | Open | Active |
| Bagnon | One-bag grid | High | Open | Maintenance lapsed |
| BagSync | Data-only cross-character tracker | High | Open | Complementary, not competing |
| Sorted | List view | Moderate | — | Active |
| **Ledger** | **List view, flat categories, hashtag search** | **768** | **All Rights Reserved** | **Active — direct competitor** |
| **Coffer** | **Grid + rules + alts + currencies; list view built-but-disabled** | **6** | **MIT** | **5 days old — direct competitor** |
| Baud Manifest | Nested manual categories + list | 63K | Public Domain | Active but architecturally dated |

#### Ledger (Tekwhipley89) — the closest thing to this PRD already shipping

Created Feb 2026, v2.1.2 as of Jun 2026, Retail only, **All Rights Reserved** (can't read or reuse the source). 768 downloads.

**Has:** list rows (icon + name + count + ilvl) · replaces bags *and* bank · Vault window browsing personal + warband bank from anywhere · fixed auto-categories (Equipment / Reagents / Consumables / Junk) · user-created categories scoped per storage type · collapse/expand · "Recent Items" 5-minute section · hashtag search (`#epic`, `#chest`, `#2h`, `#tww`) · upgrade glow + shift-hover stat comparison · 30+ color themes · Compact Mode · per-character and shared profiles.

**Lacks:** ❌ nested categories (flat only) · ❌ cross-character inventory (only *your* bank/warband) · ❌ currency tracking of any kind · ❌ rule-based auto-assignment (categories are fixed-or-manual) · ❌ drag-and-drop assignment (uses arrow buttons in an Edit Mode) · ❌ native Blizzard aesthetic — it goes hard the *opposite* direction with holiday and rainbow themes.

#### Coffer (BettoGamer) — feature-superset, grid-first, brand new

Created ~Aug 1 2026, v0.81, Retail (12.0.7 / 12.1.0), **MIT** (source readable and reusable). 6 downloads — effectively unlaunched.

**Has:** rule-based categories built from item type, quality, binding, expansion, equip slot, marker, *or any word in the name or tooltip* — with include **and** exclude · drag-item-onto-category pinning · category export/import strings · offline alt caching with per-character breakdown injected into item **and currency** tooltips · currencies as a first-class window · warband gold deposit/withdraw + account-wide total · guild bank · auto-deposit, junk sell, disenchant, stack combining · themes and profiles · a public `Coffer-1.0` LibStub API.

**Lacks:** ❌ nested categories · ❌ native Blizzard aesthetic · ⏳ **list view — "built but disabled while the grid gets finished."** They are explicitly coming for the list-view niche.

#### What this means

Three of the PRD's differentiators were claimed while we weren't looking:

| Differentiator | Status |
|---|---|
| List view | ❌ Claimed by Ledger (shipping) and Sorted; Coffer has it built |
| Rule-based auto-assignment | ❌ Claimed by Coffer, and more thoroughly than this PRD specifies (tooltip-text matching is clever) |
| Cross-character inventory | ❌ Claimed by Coffer and Baganator |
| Cross-character currency rollups | ❌ Claimed by Coffer (in tooltips) |
| **Nested categories** | ✅ **Still unclaimed by every addon reviewed** |
| **Native Blizzard aesthetic** | ✅ **Still unclaimed — every competitor builds custom themed UI** |

**The honest read:** the surviving moat is two things — *nested* categories and *looking like Blizzard built it*. Both are real and neither is trivially copied (nesting is a data-model decision competitors would have to retrofit; native-look is a taste commitment that conflicts with the theme-park direction everyone else has chosen). But this is a narrower position than v0.1 and v0.2 assumed. Q13 resolved to *proceed as specified* — see the resolved-questions table above.

**Update (v0.6):** a third differentiator arrived after this analysis was written. **Drag-to-transfer between storage sub-groups (§4.3)** is unclaimed by every addon reviewed, and it's arguably more distinctive than nesting because it changes what the addon *does*, not just how it displays. Treat the moat as three things: nesting · native look · drag-to-transfer.

**Tactical notes:**
- Coffer is MIT. Its source is legitimately readable — for API patterns, 12.x compatibility, and to see how they solved warband/currency plumbing. Read it before writing the same code.
- Coffer is 5 days old with 6 downloads. It is not yet entrenched. Ledger has 768 downloads in 6 months — real but small.
- Ledger being All Rights Reserved means no source access, but its CurseForge screenshots and description are a free feature spec.

---

## 2. Goals

**G1 — Modernize.** Clean-room Lua against current Retail APIs. No deprecated calls, no global namespace pollution, testable module boundaries.

**G2 — Better UI/UX.** Preserve the list-and-category *model*; discard the 2006 *interaction design*. Discoverable category management, live search, sane defaults out of the box.

**G3 — Performance at scale.** Smooth with a 200+ slot inventory, full reagent bank, warband bank, and 15+ tracked alts. Target: no perceptible frame hitch on bag open or item movement.

**G4 — Native, not skinned-over.** The addon should read as *a Blizzard feature that shipped with the game*, not as a third-party overlay. Blizzard art, Blizzard templates, Blizzard interaction grammar — the only thing that changes is grid → list. See §6.

**G5 — First-class currency tracking.** Gold is one currency among dozens. Currencies live in the Folio window as a peer of items, not as a footnote. See §4.1.

### Explicit non-goals (v1)

- ❌ Classic / MoP Classic / TBC support — Retail only. Design shouldn't *preclude* it, but no compat shims shipped in v1.
- ❌ Auction house / pricing integration
- ❌ Automated selling, vendoring, or destruction
- ❌ Guild bank (Q4)
- ❌ **Grid view of any kind, ever (Q3).** Full commitment to the list. This is a positioning decision, not a scoping one — a grid mode would hedge against the product's own thesis.
- ❌ **Importing BaudManifest saved data (Q2).** Clean start; no legacy format reverse-engineering.
- ❌ Multi-column overflow (Q9)
- ❌ In-frame browsable currency list (Q10/Q11)

---

## 3. Target platform

- **WoW Retail only.** Current live patch is **12.1.0** (released 2026-08-03); Midnight / 12.0.0 is Interface `120001`. ⚠️ *Confirm the exact 12.1.0 interface number before writing the TOC.*
- Single TOC, single flavor. No multi-edition TOC complexity in v1.

### The Midnight constraint (important)

Patch 12.0 introduced **Secret Values** — opaque wrappers around combat-sensitive data that cannot be used in arithmetic — and removed `COMBAT_LOG_EVENT_UNFILTERED`. Blizzard also tightened in-combat/in-instance addon restrictions.

**Assessment: mostly not our problem.** Secret Values target health, power, absorbs, and cooldowns. Static item data (`C_Container.GetContainerItemInfo`, `C_Item.*`) is not wrapped. Two caveats to validate empirically:

1. Some addons (e.g. Pawn) hit **tooltip bugs** as second-order fallout from 12.0's restrictions, specifically around equipped-item comparison tooltips. Our tooltip layer must be defensive.
2. In-combat and in-instance frame restrictions may constrain when we can create or reconfigure frames. Pre-create the widget pool at login; never build frames reactively during combat.

**Recommended tooling:** the [wow-addon-dev](https://github.com/DennysOliveira/wow-addon-dev) Claude Code plugin bundles 12.0+ reference docs (Secret Values, API migration tables, TOC structure, widget framework). Install it before starting implementation — it will save Claude Code from writing pre-12.0 patterns from memory.

---

## 4. Feature scope

### P0 — v1 must ship with

| # | Feature | Notes / delta from original |
|---|---|---|
| F1 | List view of backpack + all equipped bags | Row = icon, name (quality-colored), count, ilvl |
| F2 | Nested user categories with collapse/expand | The core differentiator. Preserve exactly. |
| F3 | Assign item → category | **Drop target decides** (Q17 resolved): drop on a category re-categorizes, drop in a storage sub-group transfers, drop on another category's sub-group does both — see §4.3 |
| F4 | Live incremental search | **New.** Type-to-filter, no submit. Beats the original's static filter. |
| F5 | Sorting within categories | Name / quality / ilvl / recency / count |
| F6 | Stack-move modifiers | Preserve original bindings exactly (see §1 table) — muscle memory |
| F7 | Slot usage indicator | Used / free, per bag type |
| F8 | Bag replacement toggle | Default **on**; must degrade gracefully when off |
| F9 | Cross-character storage + combined view | Per-realm and account-wide toggle |
| F11 | Category auto-seed from item type | Preserve as onboarding; run automatically on first load, not as a hidden menu item |
| F12 | **Multi-currency tracking** | **New, P0.** See §4.1 |
| F13 | **Cross-character currency totals** | **New, P0.** See §4.1 |
| F14 | **Rule-based auto-assignment** | **Promoted P1 → P0 (Q7 resolved).** See §4.2 |
| F15 | **Personal bank** | **Q4.** Native list treatment, same category tree, opens at banker |
| F16 | **Warband bank** | **Q4.** Async data fetch; render stale-with-timestamp when away from a banker |
| F17 | **Storage sub-groups + drag-to-transfer** | **Q15. The design centrepiece.** See §4.3 |
| F18 | **Per-category storage opt-in** | **Q16.** Each category declares which storages it applies to |

*(F10 is intentionally vacant — it was an early duplicate of F16, folded in when Q4 resolved.)*

### 4.1 Currency tracking (P0)

Gold is a special case of a currency, not a separate concept. Blizzard's own backpack shows a handful of "tracked" currencies in a cramped strip; that's the floor, not the ceiling.

**API surface** (verify signatures before use):

| Call | Purpose |
|---|---|
| `C_CurrencyInfo.GetCurrencyListSize()` / `GetCurrencyListInfo(index)` | Walk the full currency list including headers |
| `C_CurrencyInfo.GetCurrencyInfo(currencyID)` | Quantity, max, earned-this-week, account-transferable flags |
| `C_CurrencyInfo.GetBackpackCurrencyInfo(index)` | The user's existing Blizzard-tracked set — **use this to seed defaults** |
| `C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters()` | Warband-wide per-character currency data |
| `C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()` | Triggers `ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED` |
| `GetMoney()` / `PLAYER_MONEY` | Gold |
| `CURRENCY_DISPLAY_UPDATE` | Currency change event |

**Requirements:**

- **CUR1** — Track *any* currency the user pins, not a hardcoded list. Currencies change every patch; a hardcoded list is dead on arrival.
- **CUR2** — Gold rendered as a currency entry, using Blizzard's coin formatting (`GetMoneyString` / `SmallMoneyFrameTemplate`), not a bespoke string.
- **CUR3** — Currencies are **category-assignable**, exactly like items — via the unified entry model (§5). Even though the footer is flat, keeping currencies in the same type means search, sort, and rollups are written once. *(With Q10/Q11 resolved to footer-only, this is now an architectural property rather than a visible feature. Keep the model; defer the UI.)*
- **CUR4** — Per-currency display: quantity · cap (if any) · earned-this-week vs weekly cap · account-transferable indicator. In a footer strip most of this lives in the **tooltip**, not the row.
- **CUR5** — **Cross-character totals** on hover: "4,200 Valorstones across 6 characters" with per-character breakdown. The footer shows your number; the tooltip shows everyone's.
- **CUR6** — Item-based pseudo-currencies (Artisan's Mettle, catalyst charges, bag-resident tokens) pinnable to the same strip. The user's mental model doesn't distinguish these; the API distinction is ours to hide.
- **CUR7** — Cap-approaching visual state (near max or weekly cap). ⚠️ *Verify permitted under 12.0 restrictions — it derives from data Blizzard already displays, so it should be fine, but confirm.*
- **CUR8** — Seed the pinned set from the user's existing Blizzard backpack-tracked currencies on first run. Zero-config continuity.
- **CUR9** — **Pin management lives in Options,** not the main frame. Q10/Q11 resolved to footer-only, which creates a discoverability gap: with no in-frame currency list, there's nowhere obvious to *add* a pin. Resolution: a searchable currency picker in the settings panel, plus CUR8 seeding so most users never need it. Also hook right-click on Blizzard's own currency tab as a shortcut if cheap.

**Placement:** fixed footer strip, pinned currencies only, always visible. Tooltips carry the depth. No expandable in-frame list — see §6.3.


### 4.2 Rule-based auto-assignment (P0)

Categories carry optional predicates; new items self-file. Manual assignment always wins over a rule.

**Rationale for P0:** nobody manually files 200 items twice. Without rules the nested taxonomy decays into an unmaintained mess within a week, which takes the product's one surviving differentiator with it.

**Predicate fields (v1):** item class · subclass · quality · ilvl range · binding (BoE / soulbound / warbound) · equip slot · expansion · `IsEquippableItem` · stack size · item ID (explicit pin).

**Semantics:**
- **R1** — Rules are ordered; first match wins. User can reorder.
- **R2** — Manual assignment sets a sticky override that no rule can move.
- **R3** — Include **and** exclude predicates. ("Consumables, but not Junk.")
- **R4** — Rules evaluate on item-added, not on every render. Cache the item→category resolution; invalidate on rule edit.
- **R5** — Rules on a nested category apply within the parent's scope, not globally. This is the interaction that makes nesting worth having and is the piece competitors can't retrofit cheaply.
- **R6** — Dry-run preview: show what a rule would capture before saving it.

⚠️ **Competitor note:** Coffer already does this, and adds matching on *any word in the item's name or tooltip text* — genuinely clever and worth copying. Consider it for v1.1 (it needs tooltip scraping infrastructure, which is a chunk of work).


### 4.3 Storage sub-groups and drag-to-transfer (P0) — the centrepiece

**Q15 resolved.** One window. When a bank is open, each category subdivides by storage location, and **dragging an item between sub-groups physically moves it between storages.**

```
▼ Consumables                 (18)
  ▼ Bags                       (5)
    ▪ Flask of Alchemical Chaos  5
    ▪ Healing Potion            20
  ▼ Bank                       (9)
    ▪ Feast                      2
  ▼ Warband                     (4)
    ▪ Augment Rune              12
```

Drag `Healing Potion` from **Bags** into **Bank** → the item is deposited. Drag it back → withdrawn.

**Why this is the right idea:** it makes the filesystem metaphor *operational* rather than decorative. Moving between folders moves the file. It's the most Folio-appropriate interaction available, it collapses "find the item, find the destination, drag across two windows" into one gesture, and it's the reason a single window beats the separate-windows model Ledger and Coffer both chose. **This is now the product's most distinctive feature — more so than nesting.**

**Requirements:**

- **S1** — ✅ *Q18 confirmed.* Sub-groups appear **only while interacting with a bank or warband bank.** Everywhere else the frame is a flat single-storage list — subdividing would be noise, and it would cost height for nothing. Away-from-banker bank browsing stays read-only and flat (F15/F16).
- **S2** — ✅ *Q18 confirmed.* **Three sub-groups: Bags · Bank · Warband.** Distinct groups because a drag destination must be unambiguous.
  - *Implementation note:* a banker serves both personal and warband banks from the same interaction, so all three sub-groups appear together on bank open. Don't gate the Warband group behind the warband tab being active — the point is seeing every location for an item at once.
- **S3** — Sub-groups render only when non-empty, and only for storages the category opts into (F18).
- **S4** — Sub-group headers show counts and collapse independently, with state persisted (UI10).
- **S5** — Transfer respects game rules: warband-bank eligibility (no soulbound), free-slot checks, stack merging. **Fail loudly and legibly** — a silently-refused drag is worse than an error.
- **S6** — Stack modifiers (F6) apply to transfers exactly as they do to moves. Consistency of gesture is the whole point.
- **S7** — Transfers are **queued and throttled.** Bulk moves must not trip the server's item-move rate limit. Show progress on multi-item operations.
- **S8** — Never auto-transfer. Every move is user-initiated.

#### The gesture-collision problem — RESOLVED (Q17)

Drag means two different things in the same list:

| Drag | Intent |
|---|---|
| Item → a **different category** | Re-categorize (metadata change, item doesn't move) |
| Item → a **different sub-group in the same category** | Physically transfer between storages |
| Item → a different sub-group **of a different category** | ...both? Ambiguous. |

**Resolution: (b) drop target decides.**

- **(b) Drop target decides. ← BUILD THIS.**
  Category header (or anywhere in its contents, not just the header line itself) → re-categorize; sub-group header/contents → transfer; another category's sub-group → both. One drag gesture expresses whichever intent the drop location implies, instead of forcing the user to pick a gesture *type* (drag vs. right-click) before knowing which one they wanted.
- **(a) Drag = physical move only. Right-click → "Move to category" for taxonomy.** ❌ Rejected after live prototype testing — felt equivalent moment-to-moment, but required committing to an approach (drag or right-click) up front rather than deciding by where you drop.
- **(c) Modifier disambiguates.** ❌ Rejected — shift / ctrl / alt / shift+ctrl are fully allocated to stack modifiers (F6), and breaking that muscle memory costs more than it buys.

**How it was decided:** both (a) and (b) were built as a throwaway prototype (`UI/DragPrototype.lua`, deleted once this was settled) with fake rows and a mode-switch button, tested live in-game. Drop-target hit-testing needed a fix along the way — it originally only matched the thin header line, not the category/sub-group's full content block; a drop anywhere over a block's rows now counts as hitting that block, with the more specific sub-group match checked before the broader category match.

---

### P1 — strong candidates, cut if scope bites

- **Category import/export** as a string — lets users share taxonomies. Cheap to build, high community value. (Coffer has this.)
- **Tooltip-text rule matching** — match on any word in the item's tooltip, not just structured fields. Coffer's best idea. Needs tooltip-scraping infrastructure.
- **Junk / vendor-trash surfacing** — a virtual category, no auto-selling.
- **Tooltip enrichment** — "you have N of this across M characters."
- **Minimap / DataBroker launcher.**

### P2 — deliberately parked

Item-level heatmaps · transmog collection status · bag-slot upgrade prompts · currency *transfer* UI (reading is P0, moving is not) · currency history/graphing · crafting-reagent aggregation · profile sharing across characters.

---

## 5. Architecture sketch

Deliberately loose — Claude Code should be free to argue with this.

```
Folio/
├── Folio.toc
├── Core/
│   ├── Init.lua           -- namespace, SavedVariables bootstrap, migrations
│   ├── API.lua            -- ⭐ adapter: the ONLY file that touches WoW globals
│   ├── Events.lua         -- dispatcher; single frame, one OnEvent
│   └── Config.lua         -- defaults, per-char vs account-wide resolution
├── Logic/                 -- ⭐ pure Lua. Zero WoW API. 100% CI-testable.
│   ├── Tree.lua           -- category tree CRUD, nesting, ordering
│   ├── Rules.lua          -- predicate evaluation, first-match resolution
│   ├── Search.lua         -- query parse → compiled predicate
│   ├── Sort.lua           -- comparators
│   ├── Rollup.lua         -- cross-character aggregation math
│   └── Transfer.lua       -- S5 eligibility rules + S7 queue ordering (pure)
├── Data/
│   ├── Scanner.lua        -- API.lua reads → normalized item records
│   ├── Currency.lua       -- API.lua reads → normalized currency records
│   ├── Cache.lua          -- in-memory current-character state
│   └── Store.lua          -- SavedVariables: alt snapshots, warband bank
├── UI/
│   ├── Frame.lua          -- main window, sizing, anchoring, persistence
│   ├── ListView.lua       -- virtualized scroller (ScrollBoxList)
│   ├── Row.lua            -- pooled row widget + drag handlers
│   ├── CategoryRow.lua    -- header widget, collapse state
│   ├── CurrencyBar.lua    -- pinned currency footer (no expanded list — Q10/Q11)
│   └── Options.lua        -- settings panel
├── Libs/                  -- embedded via .pkgmeta (see §9)
└── Tests/                 -- ⭐ busted specs + fixtures, not shipped
    ├── spec/
    └── fixtures/          -- captured real inventory dumps
```

**Design principles worth arguing about:**

1. **Strict data/UI separation — now load-bearing.** With CI-first testing (§7), this stopped being a code-hygiene preference and became the testability boundary. `Logic/` is pure Lua with zero WoW API references, so it runs under busted on a plain Lua interpreter. `Core/API.lua` is the single chokepoint where WoW globals are touched, so the mock has exactly one seam to substitute. If any `C_Container` call leaks into `Logic/`, the test strategy breaks.
2. **Virtualized list, pooled rows.** Non-negotiable for G3. A 400-row list must only instantiate ~40 frames. Use Blizzard's `ScrollBoxList` / `CreateFramePool` rather than hand-rolling.
3. **Event-driven incremental updates.** `BAG_UPDATE_DELAYED` triggers a diff, not a full rescan-and-rebuild. Debounce and coalesce.
4. **Frames pre-created at `PLAYER_LOGIN`.** Sidesteps 12.0 in-combat frame restrictions entirely.
5. **Versioned SavedVariables schema** from day one, with a migration function. The original almost certainly lacks this and it's the #1 source of "my categories vanished" bug reports.

### Data model sketch

```lua
-- Category node
{ id = "uuid", name = "Consumables", parent = "root",
  children = {...}, collapsed = false, order = 3,
  rules = { {field="itemClass", op="eq", value=0}, ... },
  -- F18 (Q16): which storages this category applies to
  storages = { bags = true, bank = true, warband = false },
  -- S4: per-sub-group collapse, persisted
  subCollapsed = { bags = false, bank = true, warband = false } }

-- Entry record — the unified type. Items and currencies are both entries,
-- which is what makes CUR3 (currencies in categories) fall out for free.
{ kind = "item",     -- "item" | "currency" | "money"
  itemID = 12345, itemLink = "...", count = 20, quality = 3,
  ilvl = 610, bag = 1, slot = 7, bound = "soulbound",
  categoryID = "uuid" or nil }

{ kind = "currency",
  currencyID = 3008, name = "Valorstones", icon = <fileID>,
  quantity = 1200, maxQuantity = 2000,
  earnedThisWeek = 300, weeklyMax = 0,
  quality = 3, isAccountTransferable = true,
  pinned = true, categoryID = "uuid" or nil }

-- Character snapshot
FOLIO_DB.chars["Name-Realm"] = {
  class = "MAGE", lastSeen = <timestamp>,
  bags = {...}, bank = {...}, reagentBank = {...},
  currencies = { [currencyID] = quantity, ... },   -- for CUR5 rollups
  money = 1234567 }

FOLIO_DB.warband = { tabs = {...}, money = 0, lastSeen = <timestamp> }
FOLIO_DB.pinnedCurrencies = { 3008, 2245, ... }  -- ordered
```

**Note on the unified entry type:** this is the single most consequential design decision in the document. If items and currencies share a record shape and a category index, then category assignment, search, sorting, and rendering are all written once. If they diverge, every feature gets built twice. Worth defending in review.

---

## 6. Design direction

### 6.1 Design principle: native by default

**The addon should be indistinguishable from a Blizzard feature.** A player who has never used it should open their bags, see a list instead of a grid, and assume Blizzard shipped it. Everything else follows from this.

This is also *strategically* correct under Midnight. Blizzard's 12.0 direction pushes addons toward reskinning Blizzard-provided elements rather than generating parallel UI — BigWigs adapted by building a skin over Blizzard containers. Leaning on Blizzard's own frames is both the aesthetic choice and the lowest-risk technical path.

**Concrete rules:**

| Rule | Implementation |
|---|---|
| Use Blizzard frame templates | `PortraitFrameTemplate` / `DefaultPanelTemplate` for the window chrome — not a custom backdrop |
| Use Blizzard's scroll widgets | `WowScrollBoxList` + `MinimalScrollBar`, not a hand-rolled scroller |
| Use Blizzard's item buttons | `ContainerFrameItemButtonTemplate` or the closest current equivalent, so cooldown swipes, quality borders, quest markers, and upgrade arrows come free |
| Register with the UI panel system | `UIPanelWindows` / `UISpecialFrames` so ESC closes it and it plays with other panels |
| Blizzard fonts only | `GameFontNormal`, `GameFontHighlightSmall`, `NumberFontNormal` — no custom fonts |
| Blizzard colors | `C_Item.GetItemQualityColor`, `ITEM_QUALITY_COLORS`, standard currency quality colors |
| Blizzard sounds | Bag open/close, item pickup/drop — reuse `SOUNDKIT` constants |
| Blizzard money display | `GetMoneyString` / `SmallMoneyFrameTemplate` |
| Blizzard tooltip | `GameTooltip` with standard anchoring, no custom tooltip frame |
| Blizzard bag slot buttons | Reuse the bag-slot button row from the default container frame |

**Anti-goals:** no custom art, no gradients or glassmorphism, no non-Blizzard iconography, no animated transitions Blizzard wouldn't ship, no theme system in v1.

**Design test:** screenshot the addon next to the default Character panel. If the borders, header, close button, and font weights don't match, it's wrong.

### 6.2 The form factor problem

A grid is roughly square. **A list is tall and narrow**, and this is the single biggest deviation from Blizzard's design language — Blizzard has no precedent for a very tall bag frame. This needs explicit design, not emergent behaviour.

**The problem quantified:** at ~20 px per row, 150 items in 8 categories ≈ 3,200 px of content. A 1440p screen is 1440 px tall. The frame *cannot* simply grow to fit.

**Requirements:**

- **UI1 — Bounded height, always.** Frame height caps at a user-set maximum (default: ~60% of screen height) with internal scrolling. Auto-grow up to the cap, never past it. This is the difference between "usable" and "covers my screen."
- **UI2 — Sensible default width.** Narrow enough to feel like a list (~300–340 px), wide enough for a full item name plus count plus ilvl without truncation. Item names in WoW get long; measure against the worst realistic case, not the average.
- **UI3 — Resizable both axes**, with width and height persisted independently.
- **UI4 — Anchor-aware growth.** Blizzard bags anchor bottom-right and grow up/left. A tall frame anchored bottom-right will collide with the minimap and action bars. Frame should support anchoring to any screen edge and grow *away* from it. Default: right edge, vertically centered, respecting a configurable margin.
- **UI5 — Screen-clamped.** Never allow the frame to be dragged mostly off-screen. `SetClampedToScreen(true)` plus sane clamp insets.
- **UI6 — ~~Multi-column overflow~~. CUT (Q9).** Not P0, not P1, not planned. Consequence: **every remaining mitigation below is now load-bearing rather than nice-to-have.** With columns off the table, scroll + collapse + density are the *entire* answer to a 3,200 px content problem. Spec them properly and don't let them get trimmed later.
- **UI7 — Sticky category headers.** When scrolling inside a long category, the header pins to the viewport top. Standard in every list UI; badly missed when absent. **Now mandatory** — with a single tall column, losing your place is the primary failure mode.
- **UI8 — Collapse-all / expand-all.** **Promoted to a primary, always-visible control** (not a menu item). With columns cut, bulk collapse is the main tool the user has for making a long list tractable.
- **UI9 — Density toggle.** Compact (text-forward, ~16 px rows) ↔ Comfortable (icon-forward, ~26 px rows). Compact nearly halves total height — with columns cut, this is the single biggest lever the user has. **Ship Compact as the default.**
- **UI10 — Remember collapse state per category, persisted.** With columns cut, the user's collapse configuration *is* their layout. Losing it on reload would be a serious regression.
- **UI11 — Default new categories to collapsed.** A freshly auto-seeded taxonomy that opens fully expanded produces exactly the 3,200 px wall we can no longer solve structurally.
- **UI12 — Scroll-to-category jump.** A compact category index (or the search box accepting a category name) to reach a category without scrolling past everything above it. Cheap, and it substitutes for a lot of what columns would have provided.

### 6.3 Layout

**Away from a banker** — one storage, no sub-groups (S1):

```
┌─────────────────────────────┐
│ ⬤ Folio           [⚙] [✕]  │  Blizzard portrait header
├─────────────────────────────┤
│ 🔍 [ search…        ] [⊟]   │  live filter + collapse-all (UI8)
├─────────────────────────────┤
│ ▼ Consumables          (12) │  sticky header (UI7), count
│   ▪ Flask of Alchemical…  5 │
│   ▪ Healing Potion       20 │
│   ▼ Food                (4) │  nested — the differentiator
│     ▪ Feast              2  │
│ ▶ Crafting             (31) │  collapsed (UI10/UI11)
│ ▼ Uncategorized        (47) │
│         [ scrolls ]         │  ← bounded by UI1
├─────────────────────────────┤
│ 🪙 12,345g  ⬥ 1,200  ⬢ 480  │  pinned currencies only (§4.1)
├─────────────────────────────┤
│ [bag][bag][bag][bag]  118/2…│  Blizzard bag buttons + slot count
└─────────────────────────────┘
```

**At a banker** — categories subdivide; drag between sub-groups transfers (§4.3):

```
┌─────────────────────────────┐
│ ⬤ Folio           [⚙] [✕]  │
├─────────────────────────────┤
│ 🔍 [ search…        ] [⊟]   │
├─────────────────────────────┤
│ ▼ Consumables          (18) │
│   ▼ Bags                (5) │  ← drag between these
│     ▪ Healing Potion    20  │     to move items
│   ▼ Bank                (9) │
│     ▪ Feast              2  │
│   ▼ Warband             (4) │
│     ▪ Augment Rune      12  │
│ ▶ Crafting             (31) │
│         [ scrolls ]         │
├─────────────────────────────┤
│ 🪙 12,345g  ⬥ 1,200  ⬢ 480  │
├─────────────────────────────┤
│ [bag][bag][bag]  118/2…     │
└─────────────────────────────┘
```

Notes:

- **No scope selector.** Q15 resolved to storage *sub-groups inside categories* rather than a mode switch — the item stays in its category and you see all its locations at once.
- ⚠️ **Vertical cost.** Sub-groups add a header row per storage per category. A 10-category tree could gain ~30 rows at a banker — against a height budget with no multi-column escape valve (Q9). UI11 (default-collapsed) and S3 (hide empty sub-groups) are doing real work here.
- The **currency footer suits the narrow shape** — a horizontal strip is what a narrow frame has spare room for, and it anchors the bottom of a tall frame visually. Per Q10/Q11 it does **not** expand; depth lives in tooltips (CUR4/CUR5), management lives in Options (CUR9).
- **Collapse-all sits next to search**, not in a menu — UI8 promoted it to a primary control once columns were cut.
- Bag-slot buttons and slot counter at the bottom, mirroring Blizzard's combined-bag layout.

### 6.4 Interaction upgrades over the original

- **Search always visible** at top. Primary interaction in 2026, not a submenu item.
- **Discoverable category management.** Visible "+" affordance, drag-to-nest. The original's *"drag the category out of the window and click on the game world to delete it"* is a hostile gesture — replace with right-click menu plus confirmation for non-empty categories.
- **Sane first-run state.** Auto-seed type categories and pinned currencies on first load. The original ships an empty flat list — bad first impression.
- ~~Optional grid-within-category~~ — **cut permanently (Q3).**

---

## 7. Testing strategy (CI-first)

**Q8 resolved: CI-first, minimal live testing.** This is the most consequential process decision in the document, because it constrains the architecture rather than merely describing a workflow.

### The three tiers

| Tier | Tool | Covers | Runs |
|---|---|---|---|
| **1. Pure logic** | [busted](https://lunarmodules.github.io/busted/) + luassert | Everything in `Logic/` — tree operations, rule evaluation, search parsing, sorting, rollup math | Every push, seconds |
| **2. Frame-level** | [wowless](https://github.com/wowless/wowless) — headless WoW Lua + FrameXML interpreter | Addon loads without error, frames construct, event handlers fire, no nil-index on startup | Every push, slower |
| **3. Live client** | `/reload`, BugSack | Visual correctness, drag-and-drop feel, taint, combat/instance restrictions | Before each release only |

### What this demands of the code

- **T1 — `Logic/` must never reference a WoW global.** No `C_Container`, no `CreateFrame`, no `GetTime`, no `_G`. Enforce with a CI lint step that greps `Logic/` for known WoW globals and fails the build. This is cheap to write and it's the guardrail that keeps the whole strategy honest.
- **T2 — All WoW access flows through `Core/API.lua`.** It exposes plain functions (`API.GetContainerItem(bag, slot) → table`) returning plain tables. Tests inject a fake.
- **T3 — Injected time and randomness.** No direct `GetTime()` in logic; pass a clock. Otherwise timing-dependent tests flake.
- **T4 — Fixtures from real data.** Add a `/folio dump` command that serializes live inventory, currency, and warband state to SavedVariables. Commit the output as test fixtures. Real data catches things synthetic fixtures never will — weird item types, nil fields, 200-slot edge cases.
- **T5 — Pure functions over stateful objects** in `Logic/`. `Rules.resolve(item, rules) → categoryID` tests trivially; a stateful `RuleEngine:apply()` does not.
- **T6 — CI gate.** GitHub Actions runs lint + busted + wowless on every push. The BigWigs packager release job (§9) is *blocked on tests passing* — no green, no release.

### Coverage expectations

| Area | Target |
|---|---|
| `Logic/Tree.lua` (nesting, cycles, orphans, reordering) | High — this is the differentiator and the easiest place to introduce subtle corruption |
| `Logic/Rules.lua` (ordering, overrides, include/exclude, scoping) | High |
| `Logic/Search.lua` | High — pure string→predicate, trivially testable |
| `Data/*` | Moderate, via `API.lua` fakes |
| `UI/*` | Smoke only (wowless: does it construct without erroring) |

### Honest limitations

CI will **not** catch: taint, visual layout problems, drag-and-drop feel, whether the tall frame is actually pleasant to use, or 12.x combat/instance restrictions. §12 step 5 (build the frame shell and *look at it*) remains mandatory despite the CI-first choice — automated tests cannot answer a taste question.

---

## 8. Performance requirements

| Metric | Target |
|---|---|
| Bag open → rendered | < 50 ms with 250 slots |
| Item move → list updated | < 16 ms (one frame) |
| Full rescan (login) | < 200 ms |
| Live frames for a 400-row list | ≤ 60 (virtualized) |
| Memory, 15 alts stored | < 5 MB SavedVariables |
| Search keystroke → filtered | < 16 ms |

Instrument with `GetTimePreciseSec()` behind a `/folio debug` flag from the first commit — retrofitting profiling is miserable.

---

## 9. Deployment

**Pipeline:** GitHub → [BigWigs packager](https://github.com/BigWigsMods/packager) → CurseForge.

1. Public GitHub repo. **License: CC0-1.0** (`LICENSE` file + `CC0-1.0` SPDX identifier); select "Public Domain" on the CurseForge project. Mirrors Baud Manifest's original license — worth a line in the README acknowledging the lineage.
2. `.pkgmeta` declaring embedded libraries and ignore rules. Files beginning with `.` are ignored by the packager automatically.
3. `.github/workflows/ci.yml` — lint + busted + wowless on every push (§7).
4. `.github/workflows/release.yml` — packager on tag push, **`needs: ci`** so a red build cannot ship.
5. Repo secret `CF_API_KEY` (a CurseForge API token — also used to fetch localization). `WOWI_API_TOKEN` / `WAGO_API_TOKEN` available later if distribution expands.
6. New CurseForge project via authors.curseforge.com. Name: Folio. Category: Bags & Inventory.
7. TOC `X-Curse-Project-ID` matching the new project.
8. Tag `v0.1.0` → alpha → dogfood → beta → 1.0.

**Release gate for 1.0:** all P0 features working · CI green · no Lua errors across a full play session · tested with ≥3 characters and a populated warband bank.

---

## 10. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| 12.0/12.1 restrictions break bag interaction in combat or instances | High | Prototype item-moving inside a raid **first**, before building any UI |
| Virtualized list + drag-and-drop is fiddly | Medium | Spike it early; it's the hardest UI problem in the project |
| Reimplementing item drag introduces taint | Medium | Use secure templates for anything touching item movement; test with `/console taintLog 1` |
| Ledger ships the list-view niche today; Coffer has list view built and disabled | Medium | Install both, use them for a week, write down what they don't do. Coffer is MIT — read the source (§12 step 1) |
| Scope creep into a full bag suite | High | P0 list in §4 is the contract. Everything else is v2. |
| Cross-character data grows unbounded | Low | Prune characters unseen for N days; make N configurable |
| **Tall frame is genuinely awkward on screen** | **High** | §6.2 is the mitigation — and with multi-column cut (Q9), UI7–UI12 are the *whole* mitigation. Build the frame shell and live with it for a day *before* building list content |
| **Q9 cut proves wrong under real load** | Medium | Most likely discovery in dogfooding. Keep the ListView layout code column-agnostic so reversing the cut later isn't a rewrite — cheap insurance, no v1 cost |
| Warband bank async fetch | Medium | Render stale-with-timestamp; never block the UI on a fetch. Read Coffer's implementation first |
| **Drag gesture collision (§4.3)** | ✅ Resolved | Q17 resolved to (b) drop-target-decides via live prototype testing. Drop-target hit-testing must cover a block's full contents, not just its header line — see §4.3 |
| **Sub-groups blow the height budget at a banker** | **High** | Sub-group headers add ~30 rows to a 10-category tree — with no multi-column escape (Q9). Mitigations: S3 hide-empty, UI11 default-collapsed, UI9 Compact default. Watch this in dogfooding |
| Bulk transfers trip the item-move rate limit | Medium | S7 — queue and throttle, show progress. Do not fire moves in a tight loop |
| Blizzard templates constrain layout more than expected | Medium | Native look (G4) and custom layout are in tension. Prototype the header + scroll shell using pure Blizzard templates in week 1 and find the walls early |
| Currency IDs churn every patch | Low | CUR1 — never hardcode. Walk the live currency list |
| Warband currency fetch is async | Low | `RequestCurrencyDataForAccountCharacters` → wait for `ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED`. Render stale-with-timestamp, never block |

---

## 11. Open questions

**✅ None blocking. All 18 are resolved — the PRD is ready for Claude Code.**

**Q17** was settled by live prototype testing (2026-08-07): (b) drop-target-decides. **Q9 is decided (cut), not deferred**; it appears here only as a post-v1 trigger to watch:

| # | Status | Revisit when |
|---|---|---|
| **Q9** | ✅ Decided: multi-column **cut**. Listed only as a watch item — keep layout code column-agnostic so reversing stays cheap | Revisit only if dogfooding shows the height budget failing |

### Revisit after v1 ships

- **Does the nested taxonomy actually get used,** or do people make three categories and stop? If the latter, rules (§4.2) matter more than nesting and the positioning should shift.
- **Is the tall frame comfortable in daily play, or merely tolerated?** Watch for users shrinking it toward something grid-shaped — that would be the signal to revisit the Q9 cut.
- **Does drag-to-transfer (§4.3) become the reason people keep Folio?** If yes it deserves top billing on the CurseForge page, above nesting.

---

## 12. Suggested first sprint (for Claude Code)

Ordered by risk, not by dependency. Each step kills the biggest remaining unknown.

1. **Read Coffer's source.** It's MIT and it already solved warband bank, currency, and alt-cache plumbing against 12.x. Read before writing the same code — this is hours saved, legitimately.
2. Install the `wow-addon-dev` plugin; confirm the 12.1.0 interface number and current `C_Container` / `C_CurrencyInfo` signatures.
3. Scaffold `Folio/` + TOC + `.pkgmeta` + **both** GitHub Actions workflows (CI and release, with release gated on CI). Ship a `v0.0.1` alpha that only prints to chat — **prove the pipeline before writing features.**
4. **Stand up the test harness before the first real feature.** busted + a stub `Core/API.lua` + the `Logic/` globals lint. CI-first only works if the harness precedes the code; retrofitting tests onto written Lua is how CI-first quietly becomes CI-never.
5. **Build the empty frame shell and look at it.** Blizzard templates, correct proportions, resizable, anchored, screen-clamped, placeholder rows. Log in, drag it around, decide if the shape works. §6.2 is the highest-risk *design* assumption and no amount of CI can answer it.
6. `Logic/Tree.lua` + specs. Pure logic, fully testable, and it's the differentiator — build it where the tests are strongest.
7. `Core/API.lua` + `Data/Scanner.lua` + `Data/Cache.lua`. Add `/folio dump` and commit real fixtures (T4).
8. **Prototype both drag models in isolation** — a throwaway frame with two lists and a drop target. Do not build the real ListView until the gesture model is settled; it determines the widget's entire event structure.
9. Spike the virtualized ListView with the settled drag model, no categories. Riskiest technical piece.
10. `Logic/Rules.lua` + specs.
11. `Data/Currency.lua` + footer bar. Self-contained, validates the unified entry model (§5) early.
12. Wire categories into the ListView.
13. Bank + warband storages, sub-groups, and transfer (§4.3). The payoff — but it lands late because everything above must be solid first.
14. Cross-character rollups (items and currencies together).

---

## Sources

- [Baud Manifest — CurseForge](https://www.curseforge.com/wow/addons/baud-manifest)
- [wow-addon-dev — Claude Code plugin for Midnight 12.0+](https://github.com/DennysOliveira/wow-addon-dev)
- [Secret Values — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Secret_values)
- [Patch 12.0.0 API changes — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
- [Enum.BagIndex — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Enum.BagIndex)
- [BigWigs packager](https://github.com/BigWigsMods/packager) · [GitHub Actions workflow wiki](https://github.com/BigWigsMods/packager/wiki/GitHub-Actions-workflow)
- [wow-ui-source (Gethe)](https://github.com/Gethe/wow-ui-source)
