# UI Redesign Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Rebuild the client menu in a casino style with a reel reveal, sheets, and a phone-friendly layout.

**Architecture:** The server and the rules do not change. Pure text helpers go in `src/shared/Odds.luau` and get Lune tests. The client gets new UI modules for the sheet, the reveal, and the guide tooltip.

**Tech Stack:** Luau, plain UI Instances, TweenService, Lune tests.

**Spec:** `docs/superpowers/specs/2026-11-08-ui-redesign-design.md`

## Global Constraints

- The client never decides a result.
- A common forge reveal takes less than 1 second. A tap skips it.
- Tap targets are at least 44 px high.
- No image assets.

## Review Focus

1. A tap during the reveal → the reveal ends at once and shows the server result.
2. Salvage → a confirmation sheet, and Cancel changes nothing.
3. A portrait phone (390 × 844) → no text overlaps and no button is off screen.
4. The guide target is on a hidden tab → the tooltip points to the tab button.
5. The fight ends during a floating damage number → no error.

---

### Task 1: Text helpers

**Files:** `src/shared/Odds.luau`, `tests/Odds.spec.luau`

**Produces:** `Odds.tierName(n) -> string`, `Odds.plural(count, word) -> string`.

- [ ] Tests: `tierName of 1000 is Epic`, `plural 1 slot, 2 slots`.
- [ ] Check: `lune run tests/run`.

### Task 2: Theme, widgets, and the sheet

**Files:** `src/client/Ui/Theme.luau`, `src/client/Ui/Widgets.luau`, `src/client/Ui/Sheet.luau`

**Produces:** `Sheet.open(ctx, title, build) -> close()`, `Sheet.confirm(ctx, title, text, okText, onOk)`, `W.card`, `W.pill`, `W.dots`, `W.gradient`, `W.pop`, `W.shake`.

### Task 3: App shell

**Files:** `src/client/init.client.luau`

- [ ] Gold pill, Help button, bottom tab bar with icons, page area, toast, sheet layer.

### Task 4: Forge tab and reveal

**Files:** `src/client/Ui/ForgeTab.luau`, `src/client/Ui/Reveal.luau`

- [ ] Three reels, result card, FORGE button, pity text, Odds button that opens a sheet.
- [ ] Tier banner, dim, rays, shake, rainbow flash.

### Task 5: Swords and Upgrades tabs

**Files:** `src/client/Ui/SwordsTab.luau`, `src/client/Ui/UpgradesTab.luau`

- [ ] Card grid, detail sheet, Salvage confirmation.
- [ ] Upgrade cards with 10 dots.

### Task 6: Fight tab and guide

**Files:** `src/client/Ui/FightTab.luau`, `src/client/Ui/Guide.luau`, `src/shared/Config.luau`

- [ ] Monster portraits (emoji in `Config.Monsters[i].icon`), floating damage, shake, last 3 log lines.
- [ ] Guide tooltip next to its target.
- [ ] Check: Studio playtest screenshots of each tab, landscape and portrait.
