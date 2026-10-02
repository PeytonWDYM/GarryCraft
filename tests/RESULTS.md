# Local test record

## Creative NPC targeting: October 2, 2026

Evidence: `%LOCALAPPDATA%\GarryCraft\creative-targeting\20261002-final\artifacts`.
`tools/Test-NpcTargeting.ps1` passed all 13 checks in a fresh owned Minecraft world on single-player `gm_construct`.
Source PID 5992 and Minecraft PID 44524 ran in the separate responsiveness lab, with isolated Minecraft preferences.
The baseline in `creative-targeting/20261002-red` reproduced targeting by hostile and fearful NPCs in creative mode.

The final run checked creative neutralization, existing enemy cleanup, a newly spawned zombie, and injected stale enemy memory.
An allied citizen retained `D_LI`, priority 71, and visibility of the player. Source did not apply `FL_NOTARGET`.
Minecraft's damage command applied a player attack through the bridge. The combine soldier lost health without targeting the creative player.
A frozen control soldier retained its other NPC enemy. Hostile soldiers retained hate toward Minecraft cow bullseyes.
Adventure, survival, and bridge stop restored all saved dispositions and priorities, including the soldier's priority 137.

The script saves per-phase Source and Minecraft snapshots and `npc-targeting-result.json`.
It removes its owned NPCs and tagged cow, reattaches the bridge, and restores the previous Minecraft mode.
The other-enemy control freezes native scheduling so AI cannot select a different enemy between snapshots.
The initial unfrozen control changed its enemy before sampling. A reused test world also retained an earlier cow.
Neither partial run counts as the final passing result. The final run started with a fresh world and includes cow cleanup.

`tools/Build.ps1` built both native modules and the Fabric mod with the explicit Java 25 path.
These tests cover combine soldiers, citizens, and zombies. They do not certify NextBots or every addon's target-selection rules.

October 1, 2026. Windows x64 GMod `2026.09.22 (10174)`, `gm_construct`, Minecraft Java 26.3, and Java 25.
Fabric Loader 0.19.5 and Fabric API 0.161.0+26.3.
Both games ran in owned, isolated single-player installations.

`tools/Build.ps1` built both native modules and the Fabric mod successfully.
The test scripts used game APIs and the local bridge. They did not send keyboard or mouse input.
Generated worlds, screenshots, traces, and game assets remain outside tracked source.

## Managed Minecraft stall recovery

The 20:48 Downtown shutdown followed Source's five-second state timeout. Minecraft completed a normal save.
The original logs remain under `runtime/diagnostics/20261001-204820` outside tracked source.
An eight-second Java process pause reproduced the shutdown in a fresh `gm_construct` world before the fix.

After the fix, `tools/Test-Stall.ps1` passed six checks in `stall/20261001-210153/stall-result.json`.
Source retained the bridge during the pause. The shutdown control stayed false.
Java PID 35180 resumed the same Source session, then saved and exited after Disable.
Source PID 54268 also exited at test cleanup. The test saved Source snapshots before, during, and after the pause.
This test proves recovery from the injected pause. It does not identify what caused Minecraft's original stall.

## Gameplay

Evidence directory: `%LOCALAPPDATA%\GarryCraft\parity-lab33\artifacts`.
Request: `entities:21.6133892`.
`tools/Collect-Lab.ps1` matched the completed Source and Minecraft requests.

| Check | Result |
| --- | --- |
| Same-input vanilla and Source collision comparison | Passed. 24 samples each. Maximum position error: 0.0001 blocks. |
| Repeated native NPC and prop melee | Seven requests found seven crosshair targets. Source applied 18 attack/environment events during the full scenario. |
| Native ground placement, mining, floor torch, wall torch | Passed. The native wall torch survived with `facing=west`. |
| TNT particles and loose Source prop impulse | 3,270 exported explosion vertices. Peak prop speed: 546.76 Source units/second. Displacement: 647.21 units. |
| Minecraft zombie navigation and native NPC combat | Zombie traveled 7.89 blocks and targeted the citizen. Source registered 240 damage. Zombie health decreased from 100 to 97.462. |
| Fifteen cows, death drops, and pickup | Completed. Frame intervals appear below. |

These collision samples cover a narrow scenario. They do not establish perfect physics on every Source surface.
The full scenario uses a fixed open courtyard position on `gm_construct`.

## Native ground use and mining effects

Request: `terrain:120.8510916`. All nine collector checks passed.
Water and lava buckets, flint and steel, stone placement, and mining worked on bare native ground.
Source drew 36 crack vertices and at least 468 debris vertices during mining.
The Minecraft trace recorded 36 crack vertices and 456 debris vertices.
The peak counts can differ because each game samples a different frame.

The pinned native citizen took six fire damage events: health 10,000 to 9,940.
It then took eight lava damage events: health 9,940 to 9,620.
Repeated fire and lava damage passed.

`tools/Collect-Terrain.ps1` checks matching requests and actual Source crack/debris draws.
The terrain test uses the courtyard position so a nearby building cannot block its item-use rays.

## Damage scales

Request: `damage:176.4571805`. All eight directions passed with the temporary test multiplier.
`tools/Collect-Damage.ps1` compares both games' measured damage with the expected values.
The test restores the archived settings afterward.

| Direction | Expected and measured damage |
| --- | ---: |
| Minecraft mob to player | 6 |
| Minecraft player to mob | 6 |
| Minecraft mob to mob | 6 |
| Environment to Minecraft entity | 6 |
| Minecraft player to native NPC | 140 |
| Minecraft mob to native NPC | 60 |
| Native NPC to Minecraft player | 4 |
| Native NPC to Minecraft mob | 2 |

## Torch lighting

Evidence directory: `%LOCALAPPDATA%\GarryCraft\lighting-lab34\artifacts`.
Request: `lighting:157.3964081`. All six checks passed after the final intensity adjustment.
Screenshots cover `dark`, `floor`, `wall`, `far`, `budget`, and `removed` phases.

The dark room had zero active emitters. The floor torch allocated one world light and one local mesh light.
The wall torch added a second light. Moving the camera from 37.5 to 39.5 blocks preserved both lights at the stone probe.
The measured native floor light stayed unchanged across those two views.
The 42-emitter phase allocated 16 world lights. The stone probe used four nearby local lights.
Removal returned both light counts to zero. Screenshots show the nearby stone illuminate and then return to darkness.

Ambient samples now use each mesh's world position. Local point lights replace the previous camera-dependent lighting.
Torch light origins follow the flame and stay above the native floor.
The renderer caches ambient queries briefly and bounds Source light allocation.

Source supports four local lights per draw through [SetLocalModelLights](https://wiki.facepunch.com/gmod/render.SetLocalModelLights).
Ambient samples subtract dynamic lighting as described in [ComputeLighting](https://wiki.facepunch.com/gmod/render.ComputeLighting).
This avoids counting each torch twice.

## Video resets and options

Six video changes between 1920×1080 and 1280×720 passed in `parity-lab33`.
GMod PID 42240 and Minecraft PID 29356 survived all changes. Minecraft kept publishing new frames.
`resolution-changes.json` records each mode and render instance. Six screenshots show the recovered renderer.

Fresh runs 33 and 34 retained FOV 0.875, `maxFps:260` (Minecraft Unlimited), all particles, and disabled VSync.
The shared options file retained SHA-256 `4309093FAAE54E1830B416D07699DF1E63573C902E5CB16559E4300880CF1441`.
GMod used its 240 FPS cap. Minecraft retained the user's Unlimited setting.

## Frame intervals

The table uses the completed run 33. Each game records full intervals, including stalls.
Minecraft keeps a one-microsecond histogram for every frame. Its saved raw frame list has a separate length limit.
Source keeps a 25,000-frame ring. The collector saved it immediately after completion, before it lost the earlier phases.

| Phase | Source p50 / p99 / max, ms | Minecraft p50 / p99 / max, ms |
| --- | --- | --- |
| Fifteen cows | 4.846 / 11.048 / 20.248 | 0.350 / 1.348 / 16.751 |
| Cow drops | 4.597 / 10.742 / 16.696 | 0.362 / 1.637 / 15.416 |
| After pickup | 4.271 / 7.588 / 10.736 | 0.353 / 1.253 / 7.982 |
| TNT fuse | 4.304 / 9.477 / 13.047 | 0.357 / 1.416 / 11.539 |
| TNT explosion | 4.329 / 10.264 / 17.370 | 0.364 / 1.204 / 3.177 |
| TNT recovery | 4.316 / 8.240 / 11.979 | 0.352 / 1.250 / 2.566 |
| Mob combat | 4.293 / 7.686 / 13.606 | 0.327 / 1.201 / 7.116 |

GMod fails the 4.167 ms p99 budget in each listed phase. Stable 240 FPS remains unfinished.
Minecraft passes that percentile budget, but some maximum intervals still exceed it.
A passing `stable240` field means only that p99 passed. It does not mean every frame passed.

## Repeat the tests

Build and launch with `tools/Play-Lab.ps1 -FreshWorld -Test`. Save the printed run directory.
Collect the full scenario immediately with `tools/Collect-Lab.ps1 -RunRoot <directory>`.
Run `garrycraft_test terrain` and `garrycraft_test damage`, then use their matching collector scripts.
Run `tools/Test-Resolution.ps1 -RunRoot <directory> -Screenshots` for the six video changes.
Use a separate fresh `gm_construct` world for `garrycraft_test lighting`, then run `tools/Collect-Lighting.ps1`.
The lighting scenario owns its fixed fixture cells. Do not run it in an existing world.

See [feature coverage](../PARITY.md) for untested gameplay and remaining work.

## Input, menu, and water follow-up

Evidence directory: `%LOCALAPPDATA%\GarryCraft\polish-run8\artifacts`.
This run used one isolated GMod process and one owned Minecraft world at 1920×1080.
Each restart closed the previous test pair. Test settings used a separate directory.

Request `responsiveness:77.3336226` passed all five correctness checks.
Direct client input age was 6.007 ms at p99. HUD capture-to-Source age was 35.979 ms at p99.
These measure different parts of delivery. Neither measures complete physical mouse-to-display latency.
The video list moved 216 pixels. The creative-search scroll offset reached 0.076923.
The largest consecutive yaw change was 8.511 degrees across repeated wrap boundaries.
Minecraft disabled its movement tutorial and retained `maxFps:260` in the saved options.
Its linked renderer ran near the Source target instead of producing thousands of unused hidden frames.

| Phase | Source p50 / p99 / max, ms |
| --- | --- |
| Look | 4.182 / 5.750 / 43.029 |
| Video options | 4.212 / 7.082 / 81.855 |
| Creative search | 4.198 / 7.167 / 60.736 |
| Fifteen cows | 4.660 / 10.211 / 15.506 |
| Cow drops | 4.575 / 9.896 / 16.593 |
| After pickup | 4.240 / 6.661 / 13.148 |
| Mob combat | 4.269 / 7.540 / 22.941 |

The menu scenarios include automatic screenshots, which can produce long frames.
Source still exceeds the 4.167 ms p99 budget. These results do not prove stable 240 FPS.
The earlier run 33 measured 11.048 ms p99 for fifteen cows. The new run measured 10.211 ms.
That comparison used separate worlds and renderer settings. It does not isolate each optimization.

Request `lighting:7.8870289` passed all nine lighting checks.
The basin exported one lit, two-sided water surface instead of two coincident reverse surfaces.
Its local light count changed from zero to two with the torches and returned to zero after removal.
Dark, floor, wall, far, budget, and removed screenshots accompany the paired traces.
The screenshots do not measure temporal flicker during a large flowing-water flood.
That build still rendered gray water because VertexLitGeneric ignored the exported vertex tint.
The follow-up tint check uses `%LOCALAPPDATA%\GarryCraft\polish-run9\artifacts`.
Request `lighting:13.8078448` passed all ten lighting checks, including the material tint check.
Source received Minecraft's RGB tint of 63, 118, 228. Torch screenshots show blue, transparent water.
The user confirmed that the water color and stability now work.
The terrain follow-up passed all nine checks after the tint change.

Request `entities:171.372266` completed the vanilla comparison and combat scenario.
Maximum position error was 0.0001 blocks. Placement, removal, floor torches, and wall torches passed.
The zombie targeted the Source NPC and traveled 8.661 blocks. Source return fire reduced its health to 97.462.
The Source NPC took 240 damage during mob combat.
Native targeting examined at most 15 pairs and issued one sight trace per update in this scene.
The code limits each update to 32 pairs and 12 traces.
The follow-up crowd request `entities:308.8281582` exercised 24 native NPCs against 15 Minecraft cows.
It reached both limits, completed its scan, and gave all 24 NPCs a mob target.
The test removed all 24 NPCs after the crowd phase. Its traces remain in the run 9 artifact directory.
This fixture freezes unarmed NPCs and removes their solid collision. It measures target selection and bounded bridge work.
The separate zombie combat phase measures live movement and damage.
The repeated run 9 world failed one placement check. That result does not count as a passing placement comparison.
Fresh-world request `entities:40.9725973` repeated the crowd and combat tests in `polish-run10\artifacts`.
Collision, placement, mining, both torch attachments, mob targeting, and damage in both directions passed.
Maximum position error was 0.0001 blocks. The zombie traveled 8.891 blocks and ended with 97.208 health.
The native NPC took 240 damage. All 24 crowd NPCs selected mobs, and the final cleanup found zero owned bullseyes or test NPCs.
With 24 additional native NPCs, Source frame intervals were 5.083 / 11.304 / 16.829 ms at p50 / p99 / maximum.
The combat phase measured 4.287 / 7.473 / 18.882 ms. Stable 240 FPS remains unproven.

All eight damage directions passed. The terrain scenario passed all nine checks, including water, lava, and visible mining effects.
Six windowed video changes between 1920×1080 and 1280×720 passed.
GMod PID 40020 and Minecraft PID 20164 survived every change. Both games continued to publish frames.
The six screenshots show the recovered HUD, held item, placed blocks, and glass at the requested dimensions.

## Normal-play mouse override

The user reported that slow mouse movement stayed locked after the test returned to normal play.
An empty lighting request matched normal play's empty test ID. The server therefore reset the view angle on each update.
A temporary Source API probe recorded 134 `SetEyeAngles` calls during two seconds of normal play.
The fix restricts that camera override to a matching `lighting:` test request.
The same probe then recorded zero calls during two seconds. Minecraft remained linked with an empty lighting request.
Both captures remain in `polish-run10\artifacts`. Each capture restored the original API afterward.
The fix was loaded into the running isolated Source build. No camera-locking scenario ran during this check.

## Managed startup and crash follow-up

The original October 1 18:26 dump records a null citizen squad access at `server.dll+0x2A126F`.
The later Windows dump records a secondary failure in crash reporting. The original call chain matches citizen player-squad recruitment.
Test citizens now cannot join player squads. Completed scenarios remove their owned NPCs and props.
The repeat request `entities:125.4207581` passed collision, placement, mining, both torch attachments, and mob targeting.
Its crowd test targeted all 24 native NPCs within the 32-pair and 12-trace budgets.
Cleanup found zero owned NPCs, props, or bullseyes. Normal play remained active afterward without another crash.
Evidence remains under `%LOCALAPPDATA%\GarryCraft\startup-lab\artifacts` and its map artifact directory.
This addresses the observed test-citizen crash path. It does not certify all native NPC classes.

`startup-final\artifacts\startup-result.json` passed all 16 managed startup checks.
The map cycle used `gm_construct`, `gm_flatgrass`, and the installed custom map `backrooms_main`.
Each map loaded collision geometry and linked. Repeated enable requests retained one Java process.
A diamond block placed through Minecraft chat survived save, exit, and reopening.
Minecraft's saved 180 FPS limit survived the complete map cycle. Temporary bridge options restored before saving.
Disable restored Source movement, health, armor, collision group, and the previous addon weapon, `weapon_projectile` from `crossbowboltgun`.
It removed bridge entities and client state, restored Source limits to the test's 144/72 FPS values, and left no owned Java process.
The addon check covers loading and weapon restoration. It does not certify every addon hook or native weapon behavior while attached.

`startup-final\artifacts\lifecycle-result.json` passed all four lifecycle checks.
Missing configuration left the bridge inactive and showed setup instructions.
Disconnecting during Minecraft startup saved and stopped Java. Reconnecting started and linked automatically.
An abrupt stop of owned Source PID 64464 also caused Java PID 38120 to save and exit.
These tests used isolated preferences and owned worlds. Their JSON reports and persistence log provide repeatable evidence.
Build.ps1 compiled both native modules and the Fabric mod successfully.

The root `GarryCraft.cmd` launcher opened the prepared installation with Workshop support enabled.
Reopening it retained one host. Normal exit saved and stopped its Minecraft process.
The shortcut uses the tested 1920×1080 windowed mode. A default-video launch stalled in Source's material-system initialization.
The follow-up video test passed six mode changes with Source PID 44700 and Java PID 54896.
Source paused longer than the collector's original three-second wait. Recovery took about ten seconds per changed mode.
The helper now permits a 120-second heartbeat gap during video initialization and never restarts an expired request against an open mapping.
A 25-second heartbeat pause retained Java PID 54896 and recovered the same linked session.
The final video trace remains in the normal runtime's `worlds/gm_construct/artifacts` directory.
Launcher, heartbeat, and normal-exit reports remain in `startup-final\artifacts`.

## Runtime file-sharing failure

The user reported that GarryCraft stopped on `rp_downtown_tits_v2` at 20:16. GMod PID 30524 remained responsive.
The launcher log records a Windows file-sharing error in `File.Replace`. Minecraft then saved and exited normally.
A held reader reproduced Windows sharing violation 32. Source can deny replacement while reading its status file.
The old launcher rewrote its ready status every 500 milliseconds, creating repeated opportunities for this race.

`tools/Test-RuntimeSharing.ps1` passed all seven checks with launcher PID 60880 and real Minecraft PID 21984.
The test used a fresh owned world and separate 60 FPS preferences. It held status open through the ready transition.
Both processes survived. The old JSON remained complete. Releasing the reader published ready status with the same Java PID.
Unchanged ready status retained its modification time. A locked shutdown control retained launcher ownership until the reader closed.
Minecraft then saved and exited without an orphan. The test did not open the user's Downtown world.
Evidence remains in `%LOCALAPPDATA%\GarryCraft\runtime-sharing\20261001-202444`.
The failed session's original logs remain in the prepared runtime's `diagnostics/20261001-201626` directory.
