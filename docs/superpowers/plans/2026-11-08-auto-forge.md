# Auto forge and auto delete: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an auto forge with a Stop at tier, and an auto delete with Delete and Keep filters that the server applies.

**Architecture:** A new pure module `Shared/AutoDelete.luau` checks rules and cleans rules from the client. `Actions` stores the rules in the player data, and the `Forge` action applies them to the new sword. The client runs the auto forge loop and edits the rules in a sheet.

**Tech Stack:** Luau, Roblox, Lune tests, Studio MCP for UI checks.

**Spec:** `docs/superpowers/specs/2026-11-08-auto-forge-design.md`

## Global constraints

- The server rolls each sword and decides each deletion.
- Keep always wins over Delete. An empty Delete filter deletes nothing.
- Never auto delete a sword at or above the Stop at tier, or of 1 in 1,000 or rarer (`Config.RareFlashOneIn`).
- Write all text in ASD-STE100 Simplified Technical English.
- Tests: `lune run tests/run`. Add each new spec file to `tests/run.luau`.

## Review focus

- A client sends rules that are too big, have unknown ids, or have bad numbers. The server must ignore the bad parts and must not error.
- The Stop at sword also matches a Delete filter. The server must keep it.
- The gold runs out, or the list is full, in the middle of a run. The run must stop with a clear message.
- The player leaves the Forge tab, or opens a sheet, during a run. The run must stop.
- Old saved data has no `autoForge` field. `Reconcile` must fill it, and `Forge` must still work.

---

### Task 1: The AutoDelete module

**Files:** create `src/Shared/AutoDelete.luau`, create `tests/AutoDelete.spec.luau`, modify `tests/run.luau`.

**Interfaces (produces):**
- `export type Filter = { tiers: { number }, materials: { string }, qualities: { string }, enchants: { string }, slots: number, damage: number }`. `slots = -1` and `damage = 0` mean "not used".
- `export type Rules = { stopTier: number, deleteOn: boolean, delete: Filter, keep: Filter }`. `stopTier = 0` means "Never". Tiers are 1 (Common) to 6 (Mythic), from `Odds.tier`.
- `AutoDelete.newRules(): Rules` — `stopTier = 0`, `deleteOn = false`, empty filters.
- `AutoDelete.clean(input: any): Rules` — keeps only known ids, integers in range, and at most 40 items for each list. It never errors.
- `AutoDelete.shouldDelete(rules: Rules, sword: Sword.Sword): boolean`.
- `AutoDelete.reachesStop(rules: Rules, sword: Sword.Sword): boolean`.

**Tests:**
- `deletes nothing when auto delete is off`
- `deletes nothing when the Delete filter is empty`
- `deletes a sword that matches a Delete material`
- `deletes a sword that matches a Delete tier`
- `deletes a sword with damage below the Delete damage`
- `deletes a sword with slots at most the Delete slots`
- `keeps a sword that matches a Keep enchant even if it matches Delete`
- `keeps a sword with damage at least the Keep damage`
- `keeps a sword at or above the Stop at tier`
- `keeps a sword of 1 in 1,000 or rarer`
- `reachesStop is false when Stop at is Never`
- `clean drops unknown ids and bad numbers`
- `clean limits each list to 40 items`
- `clean of a non-table returns new rules`

**Check:** `lune run tests/run`

### Task 2: Store the rules and apply them in Forge

**Files:** modify `src/Shared/Actions.luau`, modify `tests/Actions.spec.luau`.

**Interfaces:**
- Consumes: Task 1.
- Produces: `Data.autoForge: AutoDelete.Rules`. Action `SetAutoForge` with args `{ rules = <Rules> }` saves `AutoDelete.clean(args.rules)`. `Forge` returns `{ ok, sword, autoDeleted = { gold: number }? }`. When the sword is deleted, the server removes it and adds `Sword.salvageValue(sword)` gold.

**Tests:**
- `a new player has auto delete off and Stop at Never`
- `SetAutoForge saves clean rules`
- `Forge auto deletes a matching sword and gives salvage gold`
- `Forge keeps a sword that does not match`
- `Forge with old data that has no autoForge still works`

**Check:** `lune run tests/run`

### Task 3: The auto forge loop in the Forge tab

**Files:** modify `src/Client/Ui/ForgeTab.luau`.

**Interfaces:** consumes `SetAutoForge`, `Forge.autoDeleted`, `AutoDelete.reachesStop`.

- An **Auto** switch next to FORGE. FORGE shows **STOP** while a run goes.
- Reel stop times are half the normal times in a run.
- Stop conditions as in the spec. Show the reason in a short line.
- Show "Auto deleted: <name> (+N gold)" and a run count of deleted swords.

**Check:** Studio playtest: start a run, see it stop at the Stop at tier, and read the console.

### Task 4: The Auto forge sheet

**Files:** create `src/Client/Ui/AutoForgeSheet.luau`, modify `src/Client/Ui/ForgeTab.luau` (one button that opens the sheet).

- Stop at: Never, Uncommon, Rare, Epic, Legendary, Mythic.
- Auto delete on or off.
- Delete and Keep sections, each with chips for tiers, materials, qualities, and enchantments, and steppers for slots and damage.
- Each change sends `SetAutoForge`.

**Check:** Studio playtest: set rules, forge, and see the auto deleted line. Read the console.

### Task 5: Update the main design

**Files:** modify `docs/superpowers/specs/2026-11-08-sword-factory-design.md` (screens and saved data).

**Check:** `lune run tests/run`, then one full playtest of all tabs.
