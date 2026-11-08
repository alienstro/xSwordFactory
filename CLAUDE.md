# Sword Factory: rules for agents

Sword Factory is a Roblox game that uses only text and buttons.
The design is in `docs/superpowers/specs/2026-11-08-sword-factory-design.md`.
Read the design before you change game behavior.

## Tools

- **Rojo** syncs the repo into Studio. Rokit pins the version in `rokit.toml`.
- **Roblox Studio MCP** connects the agent to the open Studio place "Sword Factory".
- These two tools do different jobs. Use both.

## Source of truth

- The repo is the source of truth for all scripts.
- `default.project.json` maps the folders:
  - `src/shared` → `ReplicatedStorage.Shared`
  - `src/server` → `ServerScriptService.Server`
  - `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
- Write and change scripts only in the repo files.
- Do not edit scripts in Studio through MCP. Git does not record that change, and the next Rojo sync can overwrite it.

## Workflow

1. Change the code in `src/`.
2. Make sure that `rojo serve` runs. Start it only if no process listens on port 34872.
3. Make sure that the Rojo plugin in Studio is connected. If it is not, ask the user to click **Connect**.
4. Use Studio MCP to start a playtest, click the UI, take screenshots, and read the console.
5. Stop the playtest and stop each process that you started.

## Studio MCP

- Call `list_roblox_studios` first to get the `studio_id`.
- Use MCP to inspect, to playtest, and to check results.
- Ask the user before you change instances in the place.

## Tests

- Keep the game logic in pure modules in `src/shared`. These modules do not call Roblox services.
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
