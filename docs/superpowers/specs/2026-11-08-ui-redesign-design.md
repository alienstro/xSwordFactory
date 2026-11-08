# Sword Factory: UI redesign (casino style)

Date: 2026-11-08
Status: Approved by the owner ("just proceed").

Source marks: **(Owner)** the owner decided it. **(My call)** the designer decided it.

## Intent

The first version works, but the menu looks plain and has UX problems.
The redesign makes each forge feel like a gacha pull, and it makes the
game easy to use on a phone. **(Owner: clean casino / gacha style)**

## Goals

1. A bright casino look: dark background, vivid rarity colours, card-style results.
2. A forge reveal with three reels that stop one at a time. **(My call)**
3. A bigger reveal for rare results:
   - 1 in 100 or rarer: a tier banner.
   - 1 in 1,000 or rarer: the screen dims, light rays turn, the card shakes, a sound plays.
   - 1 in 100,000 or rarer: a rainbow flash.
4. A common forge takes less than 1 second. A tap skips the animation. **(My call)**
5. A bottom tab bar with icons, in the thumb zone. A gold pill at the top. **(My call, Roblox guidance)**
6. The odds open in a sheet with a compact table, not a wall of text.
7. The Swords tab shows a grid of cards. A tap opens a detail sheet with the actions.
8. Salvage asks for confirmation.
9. Upgrades show 10 level dots for each upgrade.
10. Fights show a monster portrait, damage numbers that float up, a shake on each hit, and only the last 3 log lines.
11. The guide is a small tooltip next to its target. It does not cover a list.
12. One column that works in portrait and in landscape.
13. Correct plurals, for example "1 slot".

## Non-goals

- An AUTO forge button. It is a new feature. **(My call)**
- Image assets. All art uses UI shapes, gradients, strokes, and emoji. **(My call)**
- Changes to game rules or to the server.

## Anti-goals

- The client decides a result. The reveal only shows what the server sent.
- The animation makes many forges in a row slow or boring.
- A tap target smaller than about 44 px.

## Rarity tiers (My call)

| Tier | 1 in N | Name |
|---|---|---|
| 1 | below 10 | Common |
| 2 | 10 to 99 | Uncommon |
| 3 | 100 to 999 | Rare |
| 4 | 1,000 to 9,999 | Epic |
| 5 | 10,000 to 99,999 | Legendary |
| 6 | 100,000 and more | Mythic |

## Left to the builder

The exact colours, sizes, tween times, emoji for monsters, and the sound files
from the Studio content folder.
