# Sword Factory

A Roblox game that uses only text and buttons. The player forges swords by chance,
makes them stronger, and fights monsters with them.

The design is in `docs/superpowers/specs/2026-11-08-sword-factory-design.md`.

## Tools

Rokit installs the pinned tools from `rokit.toml`:

```bash
rokit install
```

## Sync the scripts with Studio

Studio Script Sync syncs the scripts in Studio with the files in `src/`, in both
directions. Set it up one time for each computer:

1. Stop the playtest, so that Studio is in Edit mode.
2. In the Explorer, select only one of the instances below. Do not select its
   service.
   - `ReplicatedStorage.Shared` → `src/Shared`
   - `ServerScriptService.Server` → `src/Server`
   - `StarterPlayer.StarterPlayerScripts.Client` → `src/Client`
3. Right-click it, select **Script Sync → Sync to…**, and choose the `src` folder
   itself. Script Sync makes a folder with the name of the instance inside the
   folder that you choose.
4. Do steps 2 and 3 again for the other two instances.
5. If Studio shows the conflict dialog, read the list, then click **Keep Disk**.
   Git holds the newest code.

Studio resumes the sync each time that you open the place.

## Run the game in Studio

Click **Play**.

## Run the unit tests

```bash
lune run tests/run
```

## Layout

| Folder | Studio location | What it has |
|---|---|---|
| `src/Shared` | `ReplicatedStorage.Shared` | The game rules and the config. Pure modules, tested with Lune. |
| `src/Server` | `ServerScriptService.Server` | The server, saved data (ProfileStore), and the request remote. |
| `src/Client` | `StarterPlayerScripts.Client` | The menu UI. |
| `tests` | (not synced) | Unit tests. |

The file names tell Script Sync the script type:

| File name | Studio instance |
|---|---|
| `Name.luau` | `ModuleScript` |
| `init.legacy.luau` | The `Script` that holds the folder (`RunContext` = `Legacy`) |
| `init.local.luau` | The `LocalScript` that holds the folder |

All tuning numbers are in `src/Shared/Config.luau`.

ProfileStore is vendored in `src/Server/ProfileStore.luau`. Its license is in `vendor-licenses/`.
