# ParkPark

A Roblox tycoon about restoring an abandoned amusement park.

## Development setup

- VS Code and OpenCode are the source of truth for project structure and Luau code.
- Rojo builds the local project and synchronizes it with Roblox Studio.
- Roblox Studio is used to view the game, playtest, edit 3D content, and publish.
- Git tracks source code and design notes. Keep local place backups in `local_backups/`.

### Rojo service mapping

| Local folder | Studio location |
| --- | --- |
| `src/server` | `ServerScriptService/ParkReborn` |
| `src/client` | `StarterPlayer/StarterPlayerScripts/ParkRebornClient` |
| `src/shared` | `ReplicatedStorage/ParkRebornShared` |

The project mapping is in `default.project.json`. Keep gameplay code in VS Code; use Studio for visual work and runtime testing.

## Game design

See [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).
