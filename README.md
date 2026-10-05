# GarryCraft

Minecraft gameplay inside Garry's Mod. Minecraft handles movement, blocks, inventory, and mobs. Garry's Mod supplies maps, props, NPCs, and rendering.

## Install V1

**Windows x64 and 64-bit Garry's Mod are required. Single-player only.**
Own Garry's Mod and Minecraft Java Edition. Setup downloads Minecraft Java 26.3, Fabric, and a private Java 25 runtime.
You do not need build tools, a separate Java installation, or PowerShell 7.

1. In Steam, open **Garry's Mod > Properties > Betas**.
2. Select **x86-64** under **Beta Participation**, then wait for the update.
3. Close Garry's Mod.
4. Download **GarryCraft-1.0.0-windows-x64.zip** from [V1 releases](https://github.com/PeytonWDYM/GarryCraft/releases/tag/v1.0.0).
5. Extract the entire ZIP into a folder.
6. Open **Install.cmd**.
7. After setup completes, open the printed **Play.cmd** path.
8. Select **Start New Game > Sandbox > gm_construct > Single Player**.

Setup detects Steam libraries and copies the addon and both x64 modules into Garry's Mod.
If detection fails, select **Properties > Installed Files > Browse** in Steam. Paste that folder path into setup.
The folder must contain both `bin` and `garrysmod`.

Setup creates a separate Minecraft installation under `%LOCALAPPDATA%\GarryCraft\player`.
It installs GarryCraft and Fabric API in `minecraft\mods` and loads them automatically.
Your normal Minecraft mods, launcher profiles, and saves stay in their existing installation.
The local Minecraft player uses the name `GarryCraft`. V1 does not provide account sign-in or multiplayer.

**V1 checks the exact native engine builds before installation.** A Steam update can require a new GarryCraft release.
Read [installation and recovery](docs/INSTALL.md) for supported builds, manual copy paths, logs, and removal instructions.
Use the release ZIP asset. GitHub's **Source code** archives do not contain the built modules.

## Settings and controls

The addon starts Minecraft when you load a map. Each GMod map keeps a separate Minecraft world.
Use **Spawn Menu > Utilities > GarryCraft**, or `garrycraft_menu`, to enable or disable the bridge.
Disable saves the world and restores Source movement. Closing GMod also saves and stops Minecraft.

The launcher selects single-player settings with `sv_lan 1` and `maxplayers 1`.
The bridge uses a 240 FPS Source cap and defaults new Minecraft settings to Unlimited.
These caps do not guarantee 240 FPS. Start with Sandbox and no conflicting Workshop addons.
V1 preserves your video settings and existing Minecraft preferences. No manual graphics or console changes are required.

| Control | Action |
| --- | --- |
| GMod movement keys (defaults: WASD / Space / Ctrl / Shift) | Move / jump / sneak / sprint |
| Left / right mouse | Mine or attack / use or place |
| E / T / number keys | Inventory / chat / hotbar |
| Physics Gun: left / right mouse | Grab / freeze |
| Physics Gun: GMod Use key + mouse | Rotate a held object |
| Physics Gun: Use + Shift | Rotation snap |
| Physics Gun: wheel / Reload | Hold distance / unfreeze |
| Physics Gun: I | Minecraft inventory |

Find **Physics Gun** in Minecraft's **Tools & Utilities**, or use `/give @s garrycraft:physics_gun`.
Unmined detached blocks return to their original cells when the bridge stops. Occupied cells retain a recovery journal.

## Current limits

V1 targets local Windows x64 Sandbox play. Other maps, game modes, and addons need separate compatibility tests.
Physics and rendering have known limits. Source lighting does not reproduce Minecraft lighting.
Read [feature coverage](PARITY.md) and [architecture](docs/ARCHITECTURE.md) before reporting compatibility or complete physics parity.

## Development

Read [AGENTS.md](AGENTS.md) for contributor and coding-agent instructions.
Development requires JDK 25, PowerShell 7, Visual Studio 2022 C++ tools, and CMake.
Use a separate GMod installation with a `.garrycraft-lab` marker.

```powershell
.\tools\Build.ps1
.\tools\Setup-Lab.ps1 -LabPath "$env:LOCALAPPDATA\GarryCraft\gmod-lab"
```

Keep generated game files, account data, logs, and test worlds outside tracked source.
See [release packaging](docs/RELEASING.md) and [installer scenarios](tests/release-install.md).

The bridge builds on [SkyCraft](https://github.com/chasmlol/SkyCraft).
[Protocol](protocol/README.md) · [Change log](MODLOG.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)
