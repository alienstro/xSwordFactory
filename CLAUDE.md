# Sword Factory: rules for agents

Sword Factory is a Roblox game that uses only text and buttons.
The design is in `docs/superpowers/specs/2026-11-08-sword-factory-design.md`.
Read the design before you change game behavior.

## Tools

- **Studio Script Sync** syncs the scripts in Studio with the files in `src/`, in both directions. It is built into Studio. No server runs.
- **Roblox Studio MCP** connects the agent to the open Studio place "Sword Factory".
- **Rokit** pins Lune in `rokit.toml`.
- Script Sync and MCP do different jobs. Use both.

## Source of truth

- The repo is the source of truth for all scripts. Git tracks them.
- Script Sync maps the folders. Each instance is synced into `src/`, and Script Sync adds the instance name as a folder (see `README.md`):
  - `src/Shared` → `ReplicatedStorage.Shared`
  - `src/Server` → `ServerScriptService.Server`
  - `src/Client` → `StarterPlayer.StarterPlayerScripts.Client`
- The file name sets the script type. Do not change these names:
  - `Name.luau` → `ModuleScript`
  - `src/Server/init.legacy.luau` → `Script` with `RunContext` = `Legacy`
  - `src/Client/init.local.luau` → `LocalScript`
- Write and change scripts only in the repo files with the file tools.
- Do not edit scripts in Studio through MCP. Script Sync copies that edit to disk, but large MCP edits fail more often and are hard to review.
- Do not give a synced script an attribute or a tag. Script Sync ignores them, and data can get lost.
- Do not put non-script instances in a synced folder. Script Sync syncs only `Script`, `LocalScript`, `ModuleScript`, and `Folder`.

## Workflow

1. Change the code in `src/`.
2. Make sure that Script Sync is on. With MCP, compare one changed script in the Edit data model with the file on disk.
3. If Script Sync is off, ask the user to start it. If Studio shows the conflict dialog, tell the user to click **Keep Disk**.
4. A running playtest keeps the old code. Stop it, then use Studio MCP to start a new playtest, click the UI, take screenshots, and read the console.
5. Stop the playtest and stop each process that you started.

## Studio MCP

- Call `list_roblox_studios` first to get the `studio_id`.
- Use MCP to inspect, to playtest, and to check results.
- Ask the user before you change instances in the place.

## Tests

- Keep the game logic in pure modules in `src/Shared`. These modules do not call Roblox services.
- Pure modules require siblings with `require("./Name")`. The same path works in Roblox and in Lune.
- Give each chance roll a random source with `NextNumber()`. In Roblox, use `Random.new()`. In tests, use `Harness.rng(seed)` or `Harness.fixedRng({...})`.
- Run the unit tests with Lune: `lune run tests/run`. Add each new spec file to `tests/run.luau`.
- Use Studio MCP for UI checks and exploratory QA.
- Later, run the tests in CI through the Open Cloud Luau Execution API.

## Studio MCP clicks

- `user_mouse_input` uses GUI coordinates: `AbsolutePosition + AbsoluteSize / 2` of the button.
- Screenshots use a different scale. Do not take click coordinates from a screenshot.
- Some clicks do not reach the game. If a click fails, test the server with `Remotes.Request:InvokeServer(...)` from the Client data model.

## Saved data in Studio

Studio does not save data until **Game Settings → Security → Enable Studio Access to API Services** is on. Without it, ProfileStore uses a mock store, and data resets after each playtest.
