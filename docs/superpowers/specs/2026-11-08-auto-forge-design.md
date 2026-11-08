# Auto forge and auto delete: design

Date: 2026-11-08. Owner request: "add an auto forge, and an auto delete feature. For the auto delete, we can choose what it includes: material, enchant, damage, rarity, and others."

## Intent

A player wants many swords, or one sword of the rarity they are after, without a tap on FORGE for each roll. Auto delete removes the swords that the player does not want, so that a long run does not fill the 50 slots.

## Goals

- Auto forge forges again and again until a stop condition is true.
- Auto delete salvages each new sword that matches the player's rules.
- The player chooses the rules with filters: rarity tier, material, durability quality, enchantment, slots, and damage. **(Owner)**
- The player can write rules for swords to delete and for swords to keep. **(Owner)**

## Non-goals

- Auto delete does not clean up swords that the player already has. "Salvage all" does that. **(My call)** A rule change can then never remove an old sword by surprise.
- Offline forging, or forging while the player is not in the game.

## Anti-goals

The feature fails if one of these is true, even if it works:

- The client rolls a sword or decides a deletion. The server does both. (Design section 4.)
- Auto delete removes a favorite, the equipped sword, or a sword that matches a Keep rule.
- A player misses a very rare roll because auto forge runs past it.

## Auto forge

- An **Auto** switch sits next to the FORGE button. **(My call)**
- Each step is a normal `Forge` request. The cost, the odds, and the pity counter do not change.
- The reels turn faster in auto mode: about half the normal time. **(My call)**
- **Stop at:** the player picks a minimum rarity tier (Uncommon to Mythic) or "Never". **(My call)** This is a separate setting. It does not use the Keep rules.
- The run stops when one of these is true:
  - The player taps Stop, or leaves the Forge tab.
  - The sword reaches the Stop at tier.
  - The roll is 1 in 1,000 or rarer, so the reveal shows. **(My call)**
  - The player does not have enough gold.
  - The sword list is full.
  - A request fails.
- The Stop at choice is saved with the player data. The Auto switch itself is not saved: each visit starts with auto forge off. **(My call)**

## Auto delete

- The player turns auto delete on or off. It is off for a new player. **(My call)**
- Two rule lists: **Delete** and **Keep**. **(Owner)**
- Filters in each list **(Owner, the exact set is my call)**:
  - Rarity tiers (a set).
  - Materials (a set).
  - Durability qualities (a set).
  - Enchantments (a set). A sword matches if it has one of them.
  - Slots: in Delete, "at most N". In Keep, "at least N".
  - Damage: in Delete, "below N". In Keep, "at least N".
- A new sword is deleted when it matches **any** Delete filter and **no** Keep filter. **Keep always wins.** **(My call, the safe practice for a delete feature)**
- An empty Delete list deletes nothing.
- The server never auto deletes a sword that auto forge stops for. **(My call)** These are:
  - A sword at or above the Stop at tier.
  - A sword of 1 in 1,000 or rarer (the reveal shows it).
- The server runs auto delete inside the `Forge` action, on the new sword only. The player gets the normal salvage gold.
- The `Forge` result tells the client that the sword was auto deleted. The Forge tab shows a short line, for example "Auto deleted: Wood Sword (+20 gold)", and a count for the run.
- The rules are saved with the player data. The server checks each rule from the client: only known ids, numbers in range, and a size limit.

## Economy note

A deleted sword gives its salvage gold back. That gold is usually less than the forge cost, so a long run still uses up gold slowly. No change to the numbers. **(My call)**

## Left to the builder

- The layout of the Auto delete sheet and of the Stop at control.
- The exact text of the messages.
