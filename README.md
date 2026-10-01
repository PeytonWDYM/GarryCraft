# GarryCraft

Minecraft Java physics inside 64-bit Garry's Mod. Minecraft runs as a separate process and controls the player.
Garry's Mod supplies the map, props, input, and camera.

The movement bridge ports [SkyCraft](https://github.com/chasmlol/SkyCraft)'s collision, input, camera, and water methods.
This is experimental. Complete Source feature support, block drawing, and lighting remain in development.

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

[Universal Modder](https://github.com/rehan-remade/universal-modder) supplies game research and test tools. No FAL key is required.
This repository contains source code only. See [third-party notices](THIRD_PARTY_NOTICES.md) for upstream licenses.
