# GarryCraft

Minecraft Java physics inside 64-bit Garry's Mod. Minecraft runs as a separate process and controls the player.
Garry's Mod supplies the map, props, input, and camera.

The bridge ports [SkyCraft](https://github.com/chasmlol/SkyCraft)'s collision, input, camera, water, and rendering methods.
Placed blocks, fluids, projectiles, particles, torches, and Minecraft mobs now render in Source.
Minecraft weapons can hit Source NPCs and props. Source NPCs can target and damage Minecraft mobs.
See [feature coverage and remaining work](PARITY.md) before treating a feature as complete.

## Give your agent this instruction

> Set up GarryCraft with my installed Minecraft Java and 64-bit Garry's Mod.
> Read AGENTS.md and the protocol first. Use a separate Minecraft Launcher profile and an isolated Source test installation.
> Build with tools/Build.ps1. Install both native modules and the Lua addon into the test installation.
> Install the Fabric mod and Fabric API into the new Minecraft profile.
> Start a local map, set garrycraft_bridge to the shared bridge.bin path, then run garrycraft_start.
> Test at the map spawn and use the map's own slopes and water. Save traces before reporting results.
> Extract any required assets from my installation locally. Never upload game files or account data.

Build requirements: Windows x64, Visual Studio 2022 C++ tools, CMake, and Java 25.
The Fabric build pins Minecraft 26.3. The Gradle wrapper downloads its own dependencies.

## Local play and tests

Use an isolated copy of 64-bit GMod. Add a `.garrycraft-lab` marker at that installation's root.
`tools/Install-Lab.ps1` requires this marker and refuses to replace DLLs while that installation runs.

Build, install, and start an owned Minecraft world with:

```powershell
.\tools\Play-Lab.ps1 -LabPath "$env:LOCALAPPDATA\GarryCraft\gmod-lab" -FreshWorld
```

The script requires Java 25 at its configured path. Pass `-JavaHome` to use another Java 25 installation.
Add `-Test` to run the bounded entity, world, TNT, and AI scenario.
Collect paired JSON traces with `tools/Collect-Lab.ps1 -RunRoot <printed-run-directory>`.
The collector rejects incomplete or mismatched Source and Minecraft traces.
Tests and screenshots stay outside tracked source.

Run `garrycraft_test terrain` to check buckets, fire, native NPC environmental damage, and visible mining effects.
Collect that scenario with `tools/Collect-Terrain.ps1 -RunRoot <run-directory>`.
Run `garrycraft_test damage` and `tools/Collect-Damage.ps1 -RunRoot <run-directory>` for eight damage directions.
Use `tools/Test-Resolution.ps1 -RunRoot <run-directory>` for owned video-mode changes.
Run `garrycraft_test lighting` in a fresh `gm_construct` world, then use `tools/Collect-Lighting.ps1` for torch checks.

Minecraft mirror profiles share `%LOCALAPPDATA%\GarryCraft\settings\options.txt`.
Fresh worlds retain your saved settings. New profiles default to Unlimited FPS.
GMod defaults to 240 FPS while the bridge runs. Frame reports record percentiles and long frames in both games.
Current measurements do not prove stable 240 FPS. See [the test record](tests/RESULTS.md).

The native texture uploader targets the tested Windows x64 GMod material-system interface.
Install matching versions of both DLLs, the Lua addon, and the Fabric mod.
Use an isolated single-player game and a separate Minecraft profile.

[Universal Modder](https://github.com/rehan-remade/universal-modder) supplies game research and test tools. No FAL key is required.
This repository contains source code only. See [third-party notices](THIRD_PARTY_NOTICES.md) for upstream licenses.
