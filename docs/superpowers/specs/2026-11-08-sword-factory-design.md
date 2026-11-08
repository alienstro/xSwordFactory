# Sword Factory: Design (first version)

Date: 2026-11-08
Status: Draft. The owner must approve this document before the build starts.

The text marks each decision with its source:

- **(Owner)**: the owner decided it.
- **(My call)**: the designer decided it. The owner can change it.
- **(Tuning)**: a number to start with. Playtests will change it.

## 1. Intent

Sword Factory is a Roblox game that uses only text and buttons. The player
does not move a character, and the game does not use the 3D world. **(Owner)**

The player forges swords by chance, makes them stronger, and fights monsters
with them. **(Owner)** The fun comes from three things:

- The chance of each roll, shown as "1 in N" odds. A rare roll feels special.
- Large total rarity numbers that players want to share, for example
  "1 in 2,500,000".
- A sword build that changes how a fight goes.

The game loop is: **forge → upgrade → enhance → enchant → fight → gold → forge**.

## 2. Goals of the first version

1. A guide teaches a new player how to play. **(Owner)**
2. The player forges a sword. All parts of the sword come from chance rolls. **(Owner)**
3. The player upgrades the forge to get better chances. **(Owner)**
4. The player enhances a sword from +0 to +10. **(My call)**
5. The player adds enchantments to a sword. **(Owner)**
6. The player fights monsters in a turn-based fight. **(Owner, from a suggestion)**
7. The game saves all progress.

## 3. Non-goals of the first version

These items can come later. Do not build them now. **(My call)**

- Reforge (roll one part of a sword again).
- A collection book.
- Robux purchases.
- Trading between players.
- Leaderboards.
- Use of the 3D world or of a player character.
- Typed commands. The player uses only buttons. **(Owner)**

## 4. Anti-goals

The first version fails if one of these is true, even if it works:

- The client calculates a roll, damage, or a reward. Cheaters can then change
  the result.
- The game hides the real odds of a roll.
- A player loses progress, for example after a server crash or a quick rejoin.
- A player loses a sword because they lose a fight.
- A fight takes so many clicks that it is boring. The target is 5 to 10 clicks
  when the sword fits the monster.

## 5. Constraints

- The platform is Roblox. The language is Luau. **(Owner)**
- The code is in files in `~/Projects/xSwordFactory`. Rojo 7.7.1 syncs the
  files into Studio, and git tracks them. **(Owner)**
- Rojo syncs only `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and
  `StarterPlayerScripts.Client`. Rojo must not change the Workspace or the
  Lighting. **(My call)**
- The server owns all game state and all random rolls. The client only sends
  the button that the player clicked, and it shows the result. **(My call,
  recommended practice)**
- The forge screen shows the real odds of each roll. **(Owner, from a
  recommendation)** Roblox rules require this if Robux purchases come later.
- The UI works on phones and on computers. Most Roblox players use a phone.
  **(My call)**

## 6. Screens

**(My call)** One full-screen menu with:

- A top bar that shows the gold and a **Help** button.
- Four tabs: **Forge**, **Swords**, **Upgrades**, and **Fight**.

### 6.1 The guide

- On the first join, the guide shows one step at a time over the menu. It
  points to the button that the player must click next.
- The steps are: forge a sword → equip it → fight the first monster →
  enhance the sword → enchant the sword.
- The player can skip the guide. The **Help** button starts it again.
- The game saves that the player finished the guide.

## 7. The forge

### 7.1 One forge roll

The player clicks **Forge**. The forge costs gold. The server rolls these parts
of the sword, each part with its own odds: **(Owner)**

1. **Material**: it sets the base damage and the base durability.
2. **Durability quality**: it multiplies the base durability.
3. **Enchantment slots**: the number of slots, from 0 to 5.
4. **Enchantments**: each slot can roll an enchantment, or it stays empty.
   **(My call)** The player fills empty slots later with **Enchant**
   (section 9).

The client then plays a short roll animation, like a slot machine, and shows
the result. The server decides the result before the animation starts. A roll
of 1 in 1,000 or rarer gets a special flash and a sound. **(My call)**

### 7.2 How the odds work

- Each entry in a roll table has a "1 in N" chance. **(Owner)**
- The most common entry in each table gets the remaining chance, so that the
  sum of all chances is 1. The screen shows it as "the rest".
- The screen shows the odds as "1 in N", with N rounded to a readable number.
- The colour of a result comes from its N, for example grey, green, blue,
  purple, gold, and red. **(My call)**

### 7.3 Roll tables (Tuning)

**Material**

| Material | Chance | Note |
|---|---|---|
| Wood | the rest | Weakest |
| Stone | 1 in 4 | |
| Iron | 1 in 10 | |
| Steel | 1 in 25 | |
| Silver | 1 in 100 | |
| Gold | 1 in 250 | |
| Mithril | 1 in 1,000 | |
| Obsidian | 1 in 2,500 | |
| Dragonbone | 1 in 10,000 | |
| Starmetal | 1 in 100,000 | Strongest |

**Durability quality**

| Quality | Chance | Durability multiplier |
|---|---|---|
| Worn | the rest | ×0.8 |
| Normal | 1 in 2 | ×1.0 |
| Sturdy | 1 in 10 | ×1.5 |
| Masterwork | 1 in 100 | ×2.5 |

**Enchantment slots**

| Slots | Chance |
|---|---|
| 0 | the rest |
| 1 | 1 in 3 |
| 2 | 1 in 10 |
| 3 | 1 in 50 |
| 4 | 1 in 500 |
| 5 | 1 in 5,000 |

The chance that the forge puts an enchantment in a slot is 1 in 4 for each
slot. **(Tuning)**

### 7.4 Total rarity

The sword shows a total rarity. The total rarity is the product of the "1 in N"
values of all its rolled parts. For example, Mithril (1 in 1,000) with Lifesteal
(1 in 40) gives "1 in 40,000". **(My call)**

Enchantments that the player adds later with **Enchant** also count in the
total rarity. **(My call)**

### 7.5 Sword names

The name is the material and the enhance level, for example
"Mithril Sword +3". The enchantments show under the name. **(Owner: keep names
simple)**

### 7.6 Pity counter

- If the player forges 60 times without a material of 1 in 25 or rarer, the
  next forge gives a material of 1 in 25 or rarer. **(Tuning)**
- The forge screen shows the counter, for example "Steel or better in 12
  forges". **(Owner, from a recommendation)**
- The game saves the counter.

## 8. Forge upgrades

The player buys forge upgrades with gold. Each upgrade has levels, and each
level costs more. **(Owner: upgrades give better chances)**

| Upgrade | Effect |
|---|---|
| Luck | Makes the rare entries of all roll tables more likely. This includes the material, the slots, the enchantments, and the enchantment levels. |
| Enchant Slots | Makes more slots more likely. |
| Durability | Makes better durability quality more likely. |

- The odds on the screen always show the real odds after all upgrades.
- The builder chooses the formula. A common formula multiplies the chance of
  each rare entry by a number that grows with the level. Then "the rest" gets
  the remaining chance. "The rest" must never fall below a minimum.

## 9. Changes to a sword

### 9.1 Enhance

- The player clicks **Enhance** to raise the sword from +N to +N+1. The
  maximum is +10. Each level adds 10 % to the base damage. **(Tuning)**
- Each attempt costs gold. The cost grows with the level.
- Each attempt can fail. The success chances are: **(Tuning)**

| To | +1 | +2 | +3 | +4 | +5 | +6 | +7 | +8 | +9 | +10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Success | 100 % | 95 % | 90 % | 80 % | 70 % | 60 % | 50 % | 40 % | 30 % | 20 % |

- If an attempt fails, the player loses the gold and the sword keeps its
  level. **(My call, open question 1)**

### 9.2 Enchant

- The player clicks **Enchant** to roll an enchantment into an empty slot.
  The cost grows with the number of filled slots. **(Owner: add enchantments)**
- One sword cannot have the same enchantment two times. The roll leaves out
  the enchantments that the sword already has. The odds on the screen must
  show this. **(My call)**
- The player cannot replace an enchantment in the first version. Reforge comes
  later.

### 9.3 Enchantment list (Tuning)

| Enchantment | Chance | Effect in a fight |
|---|---|---|
| Sharpness | the rest | Adds flat damage to each hit. |
| Fire | 1 in 8 | Burns the monster for some turns. |
| Frost | 1 in 15 | Can make the monster lose its next turn. |
| Lifesteal | 1 in 40 | Heals the player by a part of the damage. |
| Critical | 1 in 40 | Can make a hit do double damage. |
| Lightning | 1 in 100 | Can add a second hit. |
| Guard | 1 in 100 | Reduces the damage that the player takes. |
| Fortune | 1 in 250 | Gives more gold after a win. |
| Unbreaking | 1 in 250 | Can stop a fight from using durability. |
| Execute | 1 in 2,500 | Kills the monster at once when its health is low. |

Each enchantment also rolls a level: **(Tuning)**

| Level | I | II | III | IV | V |
|---|---|---|---|---|---|
| Chance | the rest | 1 in 4 | 1 in 20 | 1 in 200 | 1 in 2,000 |

A higher level gives a stronger effect.

### 9.4 Durability and repair

- Each fight uses 1 durability, at the start of the fight. **(My call)**
- A sword with 0 durability is broken. A broken sword cannot fight.
- The player clicks **Repair** to restore all durability. The cost grows with
  the missing durability and the rarity of the material.

### 9.5 Equip and salvage

- The player can equip one sword. Only the equipped sword fights.
- The player clicks **Salvage** to break a sword for gold. Rarer swords give
  more gold. The player cannot salvage the equipped sword.
- The player can keep a maximum of 50 swords. When the list is full, the
  player cannot forge. **(Tuning)**

## 10. Fights

### 10.1 Monsters

- The **Fight** tab shows a list of 10 monsters in order of strength. The last
  monster is a boss. **(My call)**
- The player wins against a monster to unlock the next one.
- The builder sets the monster stats so that a fitting sword wins in 5 to 10
  clicks. **(Tuning)**

### 10.2 One fight

**(Owner agreed to this flow.)**

1. The screen shows the monster's name, level, and health bar, and the
   player's health bar.
2. A text log shows each event, for example
   "You hit the Goblin for 24 damage. Fire burns it for 6 more."
3. On each turn, the player clicks one button:
   - **Attack**: a normal hit.
   - **Defend**: the next monster hit does half damage.
   - **Special**: double damage. The player can use it again after 3 turns.
   - **Flee**: the player leaves the fight and gets no reward.
4. Then the monster attacks, and the log shows the result.
5. Enchantments trigger by themselves and show in the log.
6. A win gives gold. A loss gives no reward. The player keeps the sword in
   both cases.

- The player has 100 health. The first version has no player levels. The
  sword is the only way to become stronger. **(My call)**
- The server runs the fight and keeps its state. The client sends only the
  button.

## 11. Gold

- Gold is the only currency in the first version. **(My call)**
- A new player starts with 200 gold. **(Tuning)**
- Fights and salvage give gold. Forge, enhance, enchant, repair, and upgrades
  cost gold.
- All costs and rewards are in one config module, so that tuning is easy.

## 12. Saved data

The game saves, for each player:

- The gold.
- All swords: material, durability quality, maximum and current durability,
  slots, enchantments with levels, enhance level, and the odds of each roll.
- The equipped sword.
- The upgrade levels.
- The pity counter.
- The unlocked monsters.
- Whether the player finished the guide.

**(My call, recommended practice)** Use ProfileStore. ProfileStore locks a
session, so a quick rejoin to a second server cannot overwrite the data.

**Caution:** Studio tests need **Game Settings → Security → Enable Studio Access
to API Services**. If this setting is off, saved data does not work in Studio.

## 13. Security

- The server checks each request: the player has the gold, owns the sword, is
  in a fight, and so on.
- The server limits how fast a player can send requests.
- The server uses `Random.new()` for all rolls.
- The client never tells the server a result.

## 14. Left to the builder

- The UI library, or plain Instances.
- The module layout.
- The test tool. The recommended practice is to keep the game rules in pure
  modules that do not use Roblox services. Then a tool such as Lune can run
  unit tests on a Mac without Studio.
- The exact formulas and the exact numbers, within the tuning values above.
- The roll animation, the colours, and the sounds.

## 15. Open questions for the owner

1. If an enhance attempt fails, does the sword keep its level? This design
   says yes. Many games drop the level, or break the sword, at high levels.
2. When a player forges a very rare sword, does the game tell all players in
   the server? Many chance-based games do this, for example
   "Alex forged a 1 in 1,000,000 sword!"
