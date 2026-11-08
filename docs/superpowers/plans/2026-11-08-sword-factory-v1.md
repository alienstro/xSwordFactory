# Sword Factory v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable version of Sword Factory: forge, upgrades, enhance, enchant, repair, salvage, fights, guide, and saved data.

**Architecture:** All game rules are pure Luau modules in `src/shared`. They take a random source as a parameter and do not call Roblox services. The server owns the state, runs the rules, and saves with ProfileStore. The client sends a button name through one `RemoteFunction` and draws the state that comes back.

**Tech Stack:** Luau, Rojo 7.7.1, Lune (unit tests), ProfileStore (vendored), plain UI Instances.

**Spec:** `docs/superpowers/specs/2026-11-08-sword-factory-design.md`

## Global Constraints

- The server makes all rolls, damage, and rewards. The client never sends a result.
- The screen shows the real odds after all upgrades, as "1 in N".
- A lost fight does not remove the sword.
- All numbers are in `src/shared/Config.luau`.
- Pure modules take `rng` with `rng:NextNumber(): number` (0 to 1). In Roblox, this is `Random.new()`.
- Pure modules require siblings with `require("./Name")` at the top of the file.
- The UI works on phones and on computers.

## Decisions for the open questions

- A failed enhance keeps the level (spec default).
- No server-wide announcement of rare swords in v1.

## Review Focus

1. The player has too little gold → the action fails and the data does not change. (Task 6)
2. The sword list has 50 swords → forge fails. (Task 6)
3. Salvage of the equipped sword, or a fight with a broken sword → the action fails. (Task 6)
4. Enchant on a sword with no empty slot → the action fails. Enchant when all enchants are excluded → the action fails. (Task 4, Task 6)
5. A request comes before the profile loads → the server returns an error and does not crash. (Task 7)

---

### Task 1: Test tool and config

**Files:** `rokit.toml`, `tests/Harness.luau`, `tests/run.luau`, `src/shared/Config.luau`

- [ ] Add Lune with `rokit add lune-org/lune`.
- [ ] Write `Harness` with `describe(name, fn)`, `it(name, fn)`, `expect(v).toBe/toEqual/toBeCloseTo/toBeTruthy`, and `summary()` that exits with code 1 on a failure.
- [ ] Write `Config` with every table and number from the spec, sections 7 to 11.
- [ ] Test `Config: the material table has one "rest" entry`.
- [ ] Check: `lune run tests/run` → all pass.

### Task 2: Odds

**Files:** `src/shared/Odds.luau`, `tests/Odds.spec.luau`

**Produces:** `Odds.build(entries, mult, minRest) -> {{entry, p}}`, `Odds.roll(tbl, rng) -> (entry, p)`, `Odds.format(n) -> string`, `Odds.tier(n) -> 1..6`.

- [ ] Tests: `build sums to 1`, `mult raises rare entries`, `rest never below minRest`, `no rest entry normalizes`, `roll picks by p`, `format "1 in 2,500,000"`, `tier of 1000 is 4`.
- [ ] Check: `lune run tests/run`.

### Task 3: Sword

**Files:** `src/shared/Sword.luau`, `tests/Sword.spec.luau`

**Produces:** `Sword.name(s)`, `Sword.damage(s)`, `Sword.rarity(s)`, `Sword.enhanceCost(toLevel)`, `Sword.enchantCost(s)`, `Sword.repairCost(s)`, `Sword.salvageValue(s)`, `Sword.emptySlots(s)`.

- [ ] Tests: `name "Mithril Sword +3"`, `+10 adds 100 % damage`, `rarity is the product of parts`, `repair cost 0 at full durability`.
- [ ] Check: `lune run tests/run`.

### Task 4: Forge

**Files:** `src/shared/Forge.luau`, `tests/Forge.spec.luau`

**Produces:** `Forge.tables(upgrades)`, `Forge.enchantTable(upgrades, exclude)`, `Forge.roll(upgrades, pity, rng, id) -> (sword, newPity)`, `Forge.rollEnchant(upgrades, sword, rng) -> enchant?`.

- [ ] Tests: `pity forces Steel or better at 60`, `pity resets on a rare material`, `enchant roll excludes owned enchants`, `all excluded returns nil`, `slots 0..5`, `the sword stores the odds of each roll`.
- [ ] Check: `lune run tests/run`.

### Task 5: Fight

**Files:** `src/shared/Fight.luau`, `tests/Fight.spec.luau`

**Produces:** `Fight.new(sword, monsterIndex) -> state`, `Fight.turn(state, action, rng) -> {log: {string}, outcome: "win"|"lose"|"fled"|nil}`.

- [ ] Tests: `attack lowers monster health`, `defend halves the next hit`, `special has a 3-turn cooldown`, `flee ends with no reward`, `Execute kills at low health`, `fitting sword wins in 5 to 10 turns`.
- [ ] Check: `lune run tests/run`.

### Task 6: Actions and rate limit

**Files:** `src/shared/Actions.luau`, `src/shared/RateLimit.luau`, `tests/Actions.spec.luau`

**Produces:** `Actions.newData()`, `Actions.run(data, session, name, args, rng) -> {ok, err?, ...}` for `Forge`, `Equip`, `Enhance`, `Enchant`, `Repair`, `Salvage`, `Upgrade`, `StartFight`, `FightTurn`, `FinishGuide`. `RateLimit.new(rate, burst)`, `RateLimit.allow(bucket, now) -> boolean`.

- [ ] Tests: the five Review Focus cases, `win gives gold and unlocks the next monster`, `fight uses 1 durability`, `rate limit blocks a burst`.
- [ ] Check: `lune run tests/run`.

### Task 7: Server

**Files:** `src/server/ProfileStore.luau` (vendored), `src/server/init.server.luau`; delete `src/shared/Hello.luau`.

- [ ] Load the profile with `StartSessionAsync`, `Reconcile`, and `EndSession` on leave.
- [ ] Create `ReplicatedStorage.Remotes.Request` (`RemoteFunction`). Return `{result, state}`.
- [ ] Check: Studio playtest → console shows no errors.

### Task 8: Client shell

**Files:** `src/client/init.client.luau`, `src/client/Ui/Theme.luau`, `src/client/Ui/Widgets.luau`

- [ ] Top bar with gold and **Help**. Four tabs. `UIScale` for small screens.
- [ ] Check: Studio playtest → screenshot shows the menu.

### Task 9: Forge and Swords tabs

**Files:** `src/client/Ui/ForgeTab.luau`, `src/client/Ui/SwordsTab.luau`

- [ ] Forge: odds list, cost, pity text, roll animation, flash at 1 in 1,000 or rarer.
- [ ] Swords: list, details, Equip, Enhance, Enchant, Repair, Salvage.
- [ ] Check: playtest → forge a sword, equip it.

### Task 10: Upgrades and Fight tabs

**Files:** `src/client/Ui/UpgradesTab.luau`, `src/client/Ui/FightTab.luau`

- [ ] Upgrades: three rows with level, effect, cost, **Buy**.
- [ ] Fight: monster list, health bars, log, Attack, Defend, Special, Flee.
- [ ] Check: playtest → win against the Slime.

### Task 11: Guide and final check

**Files:** `src/client/Ui/Guide.luau`, `CLAUDE.md`, `README.md`

- [ ] Five steps, a **Skip** button, **Help** starts it again, `FinishGuide` saves it.
- [ ] Update `CLAUDE.md` and `README.md`: tests use Lune.
- [ ] Check: `lune run tests/run`, then a full playtest of the guide.
