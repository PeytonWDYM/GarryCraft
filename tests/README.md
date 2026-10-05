# Local tests

Use an owned single-player GMod lab and fresh Minecraft worlds. Read [results](RESULTS.md) before treating coverage as complete.
The lab requires a `.garrycraft-lab` marker. Close it before build or installation.
Traces, screenshots, journals, and generated game files stay outside tracked source.

## Start a manual run

Run PowerShell 7 from the repository root:

```powershell
$lab = "$env:LOCALAPPDATA\GarryCraft\gmod-lab"
.\tools\Play-Lab.ps1 -LabPath $lab -FreshWorld
```

Pass `-JavaHome <JDK-25-directory>` if needed. Add `-Test` for the bounded entity, world, TNT, and AI scenario.
Use the printed run directory and the owned GMod PID in the commands below:

```powershell
$run = "C:\path\to\printed-run-directory"
$gamePid = 12345
$manual = @{GamePid = $gamePid; LabPath = $lab; RunRoot = $run}
.\tools\Collect-Lab.ps1 -RunRoot $run -LabPath $lab
```

Manual runs disable automatic Minecraft startup. Rerun `Setup-Lab.ps1` afterward to restore the managed runtime.
Use `-SettingsPath` during setup for isolated preferences. Fresh worlds otherwise retain shared Minecraft settings.
Use `-PgarrycraftSettings=<directory>` with Gradle `runClient` for separate mirror settings.

## Paired gameplay scenarios

Enter the scenario command in Source's console. Wait for completion, then run its collector from the repository root.
Collectors reject incomplete or mismatched traces. Read the saved JSON and screenshots before reporting results.

| Source command | PowerShell collector | Coverage |
| --- | --- | --- |
| `garrycraft_test` | Read `$run/artifacts/results.json` and each scenario trace | Same-input vanilla movement comparisons |
| `garrycraft_test entities` | `Collect-Lab.ps1 -RunRoot $run -LabPath $lab` | Entity combat, block interactions, TNT, and AI |
| `garrycraft_test terrain` | `Collect-Terrain.ps1 -RunRoot $run -LabPath $lab` | Buckets, fire, mining, native environmental damage |
| `garrycraft_test damage` | `Collect-Damage.ps1 -RunRoot $run -LabPath $lab` | Eight damage directions |
| `garrycraft_test polish` | `Collect-Gameplay.ps1 -RunRoot $run -LabPath $lab` | Mobs, armor, fluids, native-wall flow |
| `garrycraft_test responsiveness` | `Collect-Responsiveness.ps1 -RunRoot $run -LabPath $lab` | Menus, creative search, input delivery |
| `garrycraft_test_mob_budget`, then `garrycraft_test_mob_cleanup` | `Collect-MobBudget.ps1 -RunRoot $run -LabPath $lab` | Bounded NPC targeting and cleanup |

Collector paths start with `.\tools\`. See [gameplay fixtures](gameplay-polish.md) and [movement scenarios](movement.md) for geometry and limits.

## Source rendering and frame comparisons

Run `Test-SourceRendering.ps1`, `Test-RenderEdits.ps1`, `Test-CollisionEdits.ps1`, and `Test-FrameHitches.ps1` with the manual arguments above.
Run `Test-Performance.ps1 -PropCounts 0,32 -Seconds 8` for native prop frame samples.
Select Physics Gun in slot 1 and another item in slot 2, then run `Test-PhysgunViewmodel.ps1`.

The Source rendering fixture captures native red lamp response on Minecraft geometry and a native prop. It captures flowing water, draining, and refilling.
The edit fixture captures removal, replacement, section boundaries, and retained native model ownership.
The collision fixture checks floor, hole, slab, and stair geometry. Frame fixtures save complete intervals during idle, edits, and torch geometry changes.
Read JSON traces and PNGs before reporting a pass. Compare the same map, resolution, frame cap, and input sequence with the unchanged build.
Artifacts remain outside tracked source. Results do not certify stable 240 FPS or every Source map and material.

## Intermittent shutdown and block hitches

Run `Test-RuntimeSharing.ps1 -RuntimeRoot <prepared-runtime>` with a new owned run directory.
It starts real Minecraft in a fresh world. It tests empty, partial, missing, and locked heartbeat reads, then explicit shutdown.
It copies the launcher and its configuration. It does not modify the supplied runtime or its worlds.
Read `runtime-sharing-result.json` and the launcher transcript.

Run `Test-FrameHitches.ps1` and `Test-CollisionEdits.ps1` with the manual lab arguments above.
The hitch fixture records idle frames, twelve block edits, and torch transitions.
Its commands use Minecraft chat, so timings include that UI activity.
The collision fixture checks an elevated floor, a removed cell, replacement, a slab, a stair, and unchanged bodies during lighting updates.
Both scripts save JSON traces and results under the run's artifact directory.

`garrycraft_navigation_test` runs 600 Minecraft ticks of Warden navigation against imported native terrain.
Read `warden-navigation.json`. Require paths, movement, and owned mob removal before treating the run as complete.
This stress case does not establish the cause of an unrelated intermittent shutdown.

`Test-RapidEdits.ps1 -FloorY <native-floor-height-in-Minecraft>` tests real placement and mining input.
Choose the floor height for the fresh lab's grid alignment. Its JSON and PNG must both exist before collection.

## Source mesh and resource probes

Copy the selected Lua probe into the lab's `garrysmod/data` directory.
Load server probes with `lua_run RunString(file.Read('probe.lua','DATA'))`.
Load client probes with `lua_run_cl RunString(file.Read('probe.lua','DATA'))`.
Use the copied filename. Read each probe's header for its fixture requirements and output names.

| Probe | Realm / follow-up |
| --- | --- |
| [Moving geometry](moving-geometry.lua) | Server; `Collect-MovingGeometry.ps1 -RunRoot $run -LabPath $lab` |
| [Native meshes](native-meshes.lua) | Client; compare public/native pixels and construction costs |
| [Source shadow path](source-shadow-path.lua) | Client; actual custom silhouette and native counters |
| [Stable mesh rebind](source-model-rebind.lua) | Client observer; call `GarryCraft.SourceModelRebindTest.Begin(EyePos(), EyeAngles(), 15)` before animation and edits |
| [Particle reload](particle-reload.lua) | Client observer before `garrycraft_test reload`; `Collect-ParticleReload.ps1 -RunRoot $run -LabPath $lab` |

## Native physics gun and detached blocks

Compare the installed Source gun with the Minecraft item using the same props, input sequence, view, and native settings.
Use [control scenarios](physgun-controls.md), [visual checks](physics-gun-visuals.md), and [detached-block recovery cases](physics-blocks.md).

```powershell
.\tools\Test-Physgun.ps1 @manual -Mode source
.\tools\Test-Physgun.ps1 @manual -Mode minecraft
```

Prepare the appropriate equipped weapon before each pass. `-UseKey` accepts the Windows virtual-key code for GMod's actual Use binding.
Save native events, block journals, paired state, and pixels. Prop-only results do not prove block recovery or inventory controls.

## Managed startup and lifecycle

After `Setup-Lab.ps1`, use the prepared runtime and its owned GMod PID:

```powershell
$runtime = "$env:LOCALAPPDATA\GarryCraft\runtime"
$managed = @{LabPath = $lab; RuntimeRoot = $runtime; GamePid = $gamePid}
.\tools\Test-Startup.ps1 @managed
.\tools\Test-Lifecycle.ps1 @managed
.\tools\Test-RuntimeSharing.ps1 -RuntimeRoot $runtime
```

Startup checks map changes and saved worlds. Lifecycle checks startup disconnect, reconnect, and host exit, and closes the owned GMod process.
Add `-AbruptExit` for abrupt host cleanup. Runtime sharing checks locked status and shutdown files with a fresh world.
These scripts write their results beside the runtime. For failures, read the launcher log and the map's Minecraft logs.
