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

- Keep the game logic in pure modules in `src/shared`. These modules do not call Roblox APIs.
- Test the logic with Jest Lua (`@jsdotlua/jest`).
- Give each chance roll a random source as a parameter, for example `Random.new(seed)`. A seeded source makes each test give the same result each time.
- Use Studio MCP for UI checks and exploratory QA.
- Later, run the tests in CI through the Open Cloud Luau Execution API.

Jest Lua is not set up yet. Set it up before you write the first test.
