# GarryCraft mod log

The target is 64-bit Garry's Mod with Minecraft as the physics and gameplay authority.
The user owns both games and authorized local tests, tools, and a public GitHub repository.
The public repository name is GarryCraft.

## Local environment

- Workspace: `C:\Users\plamb\Desktop\project\GarryCraft`.
- Garry's Mod: `C:\Program Files (x86)\Steam\steamapps\common\GarrysMod`.
- Installed Steam branch: `x86-64`, build `25464497`.
- Minecraft: `%APPDATA%\.minecraft`, including Minecraft Java 26.3.
- Visual Studio 2022 Build Tools includes the x64 compiler and CMake.
- Universal Modder plugin and `um` CLI installed. No FAL key is needed.
- SkyCraft reference checkout is outside this repository under `%LOCALAPPDATA%\GaryCraft\research`.

## Architecture

Minecraft runs its own player movement and integrated server in a separate Fabric instance.
A 64-bit C++ Lua module exchanges snapshots through a local memory-mapped file.
Lua exports Source collision meshes and input. Minecraft returns the player pose and world changes.
No binary hooks or game source redistribution are required.

## Acceptance

Compare recorded movement against Minecraft itself on equivalent flat geometry.
Verify Source floor, wall, ceiling, stairs, slopes, and props in a local test map.
Exercise walking, sprinting, jumping, crouching, falling, swimming, block placement, and block removal.
Record trace files and a screenshot. Do not describe untested behavior as verified.

## Isolation

Use a separate Minecraft run directory and a new test world.
Back up the Garry's Mod config before the first modded launch.
Add only the GarryCraft addon and module. Do not change Steam branches or existing saves.


## Current work, October 1

The user reports that the SkyCraft port feels much better. Keep that movement implementation.
The user removed the artificial ramp fixtures. Use native gm_construct slopes for all further play tests.
Keep the visible Source player at spawn during tests. Never publish Minecraft reference-world coordinates to Source.
The user controls the game between bounded test actions. Do not run the old comparison suite by default.

Universal Modder 0.2.0 is installed and enabled in Codex. Its Source playbook and Terraria agent bridge example were reviewed.
The initial voxel-shape adapter passed 11 movement comparisons but did not feel correct. It has been replaced.
The current implementation ports SkyCraft's TriCollider, SourceCollider wrapper, edge behavior, input handlers, QPC clock, and raw-tick camera.
Minecraft's FOV, eye smoothing, and view bob now feed the Source camera.
The native client module reads state directly, avoiding a server-network round trip for the camera.
Minecraft's experimental-world warning is automatically accepted only for the owned GarryCraft mirror world.
Two unattended reopens joined successfully after that fix.

A clear-path run at Source spawn recorded walking near 0.216 blocks/tick and sprinting near 0.281 blocks/tick.
Sprint FOV rose from 70 to 80.5 degrees in Minecraft. Source uses the corresponding 4:3 horizontal FOV.
Trace: artifacts/sprint-clear-path.json. The earlier sprint-port.json run hit a wall and is not a speed comparison.
Artificial Source ramps were removed from the live map and their course command was removed from source.
Native map slopes, swimming, placed blocks, lighting, and the final install process still need verification.
Do not claim complete or perfect physics yet.

Use the isolated Source install at %LOCALAPPDATA%\GarryCraft\gmod-lab.
Current Source process: 48628. Current Minecraft process: 29176. Dev launch session: 96120.
Minecraft runs from fabric/run. The launcher profile uses %LOCALAPPDATA%\GarryCraft\minecraft and still needs the latest jar.
The live client DLL is current. The live server DLL is the previous mailbox-compatible build because its file remained locked at copy time.
After stopping the game, wait for it to exit before replacing both DLLs.

Next: port SkyCraft's water substitution, test native map movement without fixtures, then port block model drawing and lighting.
The public GitHub repository, README, licenses, and general install script are not created yet.
