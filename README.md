# GarryCraft

Minecraft gameplay inside Garry's Mod. Minecraft handles movement, blocks, inventory, and mobs. Garry's Mod supplies maps, props, NPCs, and rendering.

![Minecraft player with an elytra above a Garry's Mod beach](docs/images/showcase.png)

## Install V1

**Windows x64 or Linux x64 with 64-bit Garry's Mod is required. Single-player only.**
Own Garry's Mod and Minecraft Java Edition. Setup downloads Minecraft Java 26.3, Fabric, and a private Java 25 runtime.
You do not need build tools, a separate Java installation, or PowerShell 7.

1. In Steam, select **Garry's Mod > Properties > Betas > x86-64**.
2. Wait for the update, then close Garry's Mod.
3. Download **GarryCraft-1.0.4-windows-x64.zip** from [the latest release](https://github.com/PeytonWDYM/GarryCraft/releases/latest). Use this asset, not the Source code archives.
4. Extract the entire ZIP and open **Install.cmd**.
5. Open the printed **Play.cmd** path and select **Sandbox > gm_construct > Single Player**.

On Linux x64, download **GarryCraft-1.0.4-linux-x64.zip** instead, extract it, and open
**install.sh**. It needs only `bash`, `curl`, `python3`, `tar`, and `unzip`. The private player
folder defaults to `~/.local/share/GarryCraft/player`. See [installation help](docs/INSTALL.md).

Setup finds Garry's Mod in your Steam libraries and installs GarryCraft.
If asked for the game folder, use Steam's **Properties > Installed Files > Browse** and paste that path.

Minecraft gets its own installation and required mods at `%LOCALAPPDATA%\GarryCraft\player`.
Your existing Minecraft installation stays separate. Your enabled GMod addons load as usual.

Setup stops if your GMod engine build is unsupported. Steam updates can require a new GarryCraft release.
See [installation help](docs/INSTALL.md) for fixes, logs, and manual installation.

Open `Play.cmd` to start a GarryCraft session. Minecraft starts when you load a single-player map.
Launch GMod through Steam for normal play. GarryCraft's bridge code and native modules stay inactive in that session.
Each GarryCraft map keeps a separate Minecraft world.
Use **Spawn Menu > Utilities > GarryCraft**, or `garrycraft_menu`, to enable or disable the bridge.

Open `Uninstall.cmd` to remove GarryCraft. It preserves worlds and settings by default.
Use `Uninstall.cmd -Purge` for a complete reset, including those worlds and settings.

From a source checkout, `Install.cmd` downloads and runs the matching compiled release installer automatically.
If `release` contains the matching ZIP and checksum, setup verifies and uses that local package.

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

On Linux x64:

```bash
./tools/Build.sh
```

Keep generated game files, account data, logs, and test worlds outside tracked source.
See [release packaging](docs/RELEASING.md) and [installer scenarios](tests/release-install.md).

The bridge builds on [SkyCraft](https://github.com/chasmlol/SkyCraft).
[Protocol](protocol/README.md) · [Change log](MODLOG.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)
