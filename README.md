# Sword Factory

A Roblox game that uses only text and buttons. The player forges swords by chance,
makes them stronger, and fights monsters with them.

The design is in `docs/superpowers/specs/2026-11-08-sword-factory-design.md`.

## Tools

Rokit installs the pinned tools from `rokit.toml`:

```bash
rokit install
```

## Run the game in Studio

1. Start the Rojo server: `rojo serve`
2. In Studio, open the **Plugins** tab, click **Rojo**, then click **Connect**.
3. Click **Play**.

## Run the unit tests

```bash
lune run tests/run
```

## Layout

| Folder | Studio location | What it has |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | The game rules and the config. Pure modules, tested with Lune. |
| `src/server` | `ServerScriptService.Server` | The server, saved data (ProfileStore), and the request remote. |
| `src/client` | `StarterPlayerScripts.Client` | The menu UI. |
| `tests` | (not synced) | Unit tests. |

All tuning numbers are in `src/shared/Config.luau`.

ProfileStore is vendored in `src/server/ProfileStore.luau`. Its license is in `vendor-licenses/`.
