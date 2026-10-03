# GarryCraft

Minecraft Java inside Garry's Mod. Minecraft owns movement, inventory, and game rules.
Source supplies the map, native props and NPCs, input, camera, lighting, and final rendering.
Both games run as separate processes. The bridge builds on [SkyCraft](https://github.com/chasmlol/SkyCraft).

## Requirements

- Windows x64 and single-player 64-bit Garry's Mod.
- Java 25, PowerShell 7, Visual Studio 2022 C++ tools, and CMake.
- Minecraft Java 26.3, pinned by the Fabric build. Gradle downloads its dependencies.
- An isolated GMod installation with a `.garrycraft-lab` marker at its root.

Native textures and mesh shadows require the exact engine builds listed in [the architecture](docs/ARCHITECTURE.md).
Other maps, game modes, and Workshop addons need separate compatibility tests.

## Setup and play

Close the isolated GMod installation, then run this from the repository root:

```powershell
.\tools\Setup-Lab.ps1 -LabPath "$env:LOCALAPPDATA\GarryCraft\gmod-lab"
```

Pass `-JavaHome <JDK-25-directory>` if Java is installed elsewhere.
Setup builds both modules and prepares a local runtime. Rerun it after code updates.

Open [GarryCraft.cmd](GarryCraft.cmd), then load a single-player map.
The addon starts Minecraft automatically. Normal launches do not rebuild code.
Each Source map keeps its own Minecraft world. Inventory and settings persist between sessions.

Use **Spawn Menu > Utilities > GarryCraft**, or `garrycraft_menu`, to enable or disable the bridge.
Disable saves Minecraft, releases held props, and restores Source movement and the previous weapon.
Disconnecting or closing GMod also saves and stops the owned Minecraft process.
Startup errors appear in the control panel. Read the runtime's launcher log and the map's Minecraft logs for details.

## Controls

Normal play uses Minecraft movement, mouse actions, number-key hotbar selection, E inventory, and T chat.
Find **Physics Gun** in Minecraft's **Tools & Utilities**, or use `/give @s garrycraft:physics_gun`.
Selecting it equips Source's installed physics gun, with its native beam, viewmodel, and prop behavior.

| While holding the Physics Gun | Action |
| --- | --- |
| Primary / secondary fire | Grab / freeze |
| GMod's bound **Use** key + mouse | Rotate the held object |
| Use + Shift | Native rotation snap |
| Mouse wheel | Change hold distance |
| Reload | Native unfreeze behavior |
| I / number keys | Open Minecraft inventory / change hotbar slot |

The gun controls native props and detachable Minecraft blocks. Section collision mirrors stay fixed.
Unmined detached blocks return to their original cells when the bridge stops or Minecraft restarts.
An occupied original cell prevents restoration. Recovery retains the saved block and reports the conflict.
Mining uses Minecraft's block rules. A committed break recovers loot instead of restoring the block.
Read [block recovery scenarios](tests/physics-blocks.md) for current limits. Addon pickup permissions still apply.

## Development

```powershell
.\tools\Build.ps1
```

See [test commands](tests/README.md) for fresh-world runs and repeatable artifacts.
One nearby Source sun projector adds depth shadows to Minecraft meshes, including self-shadowing within its footprint.
Native mesh shadows cast onto the Source map. Queued rendering uses the sun projector for shadowed Minecraft surfaces.
Runtime blocks preserve Source ambient lighting and do not rebake BSP lighting. See the architecture for limits.

Keep generated game files, extracted assets, account data, and test worlds outside this repository.

[Architecture](docs/ARCHITECTURE.md) · [Protocol](protocol/README.md) · [Feature coverage](PARITY.md)
[Test results](tests/RESULTS.md) · [Change log](MODLOG.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)
