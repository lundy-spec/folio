# CurseForge page — Folio

Source text for the CurseForge project page. Not shipped in the addon
(`docs/` is excluded in `.pkgmeta`). Paste the sections below into the
matching CurseForge fields.

---

## Project name

Folio

## Project avatar

`docs/branding/folio-logo-400.png` (400×400, transparent corners). The
source is `docs/branding/folio-logo.svg`; the in-game addon-list icon
is the same art at 64×64 in `Media/Icon.tga`.

## Summary

*(The one-liner shown in search results and on the project card.)*

Your bags as a list. Sort items into nested categories, drag between bags and bank, all with Blizzard's native look.

## Game version / flavor

World of Warcraft: Forever

## Categories

- **Primary:** Bags & Inventory
- **Secondary:** Bank

## License

Public Domain (CC0-1.0)

## Source / issues

https://github.com/lundy-spec/folio

---

## Description

*(The long description — CurseForge's editor accepts Markdown.)*

# Folio

**Your bags, as a list you actually organize.**

The default bags are a grid of icons you have to scan. Folio turns them into
a tidy, readable list grouped into categories you choose. Categories can sit
inside other categories, so your hearthstone, your potions, and that stack of
linen you swear you'll use someday all have a place.

It's built in Blizzard's own window style, so it looks like part of the game.
There are no themes or custom skins.

Folio is inspired by the classic **Baud Manifest**, rebuilt from scratch for
**World of Warcraft: Forever**.

---

## How it works

**Drag an item onto a category to file it there.** That's it. Folio remembers,
so every copy of that item lands in the same place from then on.

Out of the box you get a starter set: *Consumables, Miscellaneous, Trade
Goods, Equipment, Quest Items,* and *Junk*. Add your own from the menu on the
window's portrait icon, and drag one out of the window to delete it. Drag
categories to reorder them, or drop one onto another to nest it inside.

Grey items go straight into **Junk** on their own, and you can turn that off
in settings.

---

## Features

### Organizing
- **Nested categories** as deep as you like
- **Drag to file.** An item stays in its category until you move it.
- **Pin items** to the top of the list with **Ctrl-click**
- **Live search** filters the list as you type
- **Stacks merged** into one row with a total count
- **Collapse or expand** any category. Folio remembers what you collapsed.

### At the bank
- A **bank panel slides out** beside your bags whenever you visit a banker,
  sorted with the same categories
- **Drag between the two windows** to deposit or withdraw. Drop on a
  category to file the item at the same time.

### At a vendor
- **Junk sells itself** when you open a vendor, with a chat summary of the
  gold earned
- **Right-click any item** to sell it

### Everyday
- **Replaces your bags.** Press **B** and Folio opens.
- A **Show Bags** button brings up Blizzard's bags whenever you want them
- **Bag space** at a glance, as slots or a percentage, plus your **gold**
- **Right-click to use** an item
- **Move and resize** the window freely

---

## Commands

| Command | What it does |
|---|---|
| `/folio` | Open or close Folio |
| `/folio options` | Open the settings |
| `/folio collapseall` | Collapse every category |
| `/folio expandall` | Expand every category |
| `/folio bagreplace` | Turn bag replacement on or off |
| `/folio resetcategories` | Reset to the starter categories |

Settings also live under **Options → AddOns → Folio**.

---

## Good to know

- **Right-click use and sell only work out of combat.** WoW blocks addons
  from doing this mid-fight, for every addon, not just Folio.
- If you **move or resize the window during combat**, the Show Bags button
  stays where it was until your next move out of combat.

---

## Feedback

Folio is free and open source (Public Domain). Bug reports and ideas are
welcome on [GitHub](https://github.com/lundy-spec/folio/issues).

---

## Screenshots to take

CurseForge shows these in a gallery. Aim for 4 or 5, cropped to just the
Folio windows, on a plain in-game background.

1. **Main window.** A few categories expanded, one nested, showing item
   rows with counts.
2. **Bank.** At a banker with the bank panel slid out beside the main
   window.
3. **Drag in progress.** An item being dragged onto a category, showing
   the drop highlight.
4. **Settings panel.** Options → AddOns → Folio.
5. **Search.** A search term typed, with the list filtered down.
