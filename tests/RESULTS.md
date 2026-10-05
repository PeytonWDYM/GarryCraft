# Local test record

## October 5: renderer hook compatibility and V1.0.3

The owned game copy reproduced the user's shadow failure with DLib and the enabled Workshop addons.
The failing check was `VEngineModel016` slot 20. Its callback belonged to `gmcl_zxcmodule_win64.dll`, at offset `0x4750`.
The engine build checks passed. The previous error combined this callback conflict with unsupported-build failures.
The requested removal moved 152 ZXC module files and installed backups from the normal game and test copy into the Recycle Bin.
The recorded paths are absent. Other addons remain enabled.

The corrected adapter passed 42 source-only checks in `release/verification/shadow-final-hooks/result.json`.
These checks cover native silhouettes, a hook installed before GarryCraft, a later hook, bridge reopen, and a rejected studio adapter.
The later callback retained calls through shutdown and reopen. Native mesh and thread error counts remained zero.
The rejected studio adapter completed ten real Lua mesh updates, retained visible mesh draws, and emitted one specific warning.
Paired screenshots and native reports support each shadow probe. The fallback probe does not test Minecraft gameplay independently.

The V1.0.3 ZIP passed a clean installation through its actual `Install.cmd` under Windows PowerShell 5.1.
The runtime and GarryCraft game payload were absent before setup. External download caches were disabled.
Setup downloaded and verified 5,232 dependencies. The package folder included spaces and an accented character.
The folder's `Play.cmd` passed nine game checks with `-RequireAutoStart`, without an Enable command.
The bridge linked with map geometry, rendered six world models and two avatar models, and recorded 8,563 custom shadow draws.
Native mesh and thread error counts were zero. Disable saved the test world and stopped Minecraft.
The launcher entry-point and recovery checks also passed all nine cases.

Read `release/verification/shadow-clean-before.json`, `shadow-clean-install.log`, and `shadow-clean-game`.
The Minecraft logs record attachment, player saving, and world saving. Installed game payload hashes matched the tested ZIP.
These tests used Windows 11, the verified x64 engine, and single-player `gm_construct`. Windows 10 needs a separate OS run.
The test copy and its private runtime are disposable. The normal GarryCraft installation was not replaced during these tests.

## October 5: clean installation and launcher recovery

The current desktop shortcut identified the marked `responsiveness-gmod-lab` and its developer runtime.
The requested wipe removed that runtime, its worlds, its shared settings, and its GarryCraft game files.
The deletion record confirms all 97 selected paths were absent before setup.

After another recorded reset, the V1.0.2 ZIP installed into an empty player folder and the wiped game installation.
External download caches were disabled. Setup downloaded and verified all 5,232 dependencies under Windows PowerShell 5.1.
The final folder launcher passed six game checks on single-player `gm_construct`.
The addon loaded, the bridge linked with completed map geometry, and Minecraft stopped after Disable.
The folder game run required a second Enable command after map startup. The saved enable switch was off.
The Minecraft log records player and world saves before exit.

The final extracted-ZIP fixture passed all 24 installer checks and all nine launcher recovery checks.
The source checkout with a local compiled ZIP passed all nine setup and folder launcher checks.
Installer checks cover clean state, repeat installation, preserved files, locked DLL rollback, and failed downloads.
An overlapping game run blocked an earlier installer test. The final installer run completed with GMod closed.
These checks do not certify other engine builds, maps, or Workshop addons.

Read `%LOCALAPPDATA%/GarryCraft/current-clean-install-20261005/wipe-result.json`, `final-clean-before.json`, and `final-clean-install.log`.
Final evidence is saved in the ignored `release/verification` folder before the requested PC cleanup.
Read its installation, launcher, source setup, game, and deletion results.
The final installer uses Windows PowerShell 5.1 on Windows 11. Windows 10 was not available for a separate OS run.

## October 5: V1 installer and production runtime

The extracted V1 ZIP passed all 20 installer checks under Windows PowerShell 5.1.
The fixture used real supported x64 engine files and a package path with spaces and Unicode.
Checks cover fresh installation, runtime-only preparation, repeat installation, preserved files, checksums, locked DLL rollback, and the runtime mutex.
The Steam library detector also found the installed game without duplicate paths.

The production Fabric launch loaded Minecraft 26.3, Fabric Loader 0.19.5, Fabric API, and GarryCraft 1.0.0.
It created a fresh mirror world and passed all 12 heartbeat, ownership, save, and exit checks.
Its local identity produces online-service authentication messages. These messages did not prevent single-player startup or saves.

The separate marked GMod lab passed four lifecycle checks with the release-installed runtime.
Checks cover missing configuration, startup disconnect, automatic reconnect with completed collision import, and host exit.
The lab's saved enable switch required an explicit Enable before the first run.
An early startup snapshot had linked input before geometry import completed. The reconnect check waited for both states.

Read `%LOCALAPPDATA%/GarryCraft/v1-install-check-3/release-install-result.json`, its installation logs, and `artifacts/lifecycle-result.json`.
Read `%LOCALAPPDATA%/GarryCraft/v1-production-runtime-check/runtime-sharing-result.json` and its Minecraft and launcher logs.
These checks do not certify every Steam engine update, Workshop addon, map, or complete physics parity.

## October 4: intermittent shutdown and frame hitches

The reported 10:55 `gm_construct` Minecraft log ends with an orderly shutdown, without an exception report.
A fresh-world launcher test reproduced a matching exit when Source's heartbeat file was temporarily empty.
Source writes that file in place. The old launcher treated an incomplete read as an expired heartbeat.
The candidate retains the last complete request and its timestamp through failed reads.
It passed all 12 sharing and heartbeat checks, retained the same Minecraft process, then saved and closed on explicit Disable.
Read `%LOCALAPPDATA%/GarryCraft/heartbeat-baseline-20261004` and `heartbeat-candidate-20261004`.
Their results and transcripts reproduce a matching failure path. The old log does not identify its precise shutdown trigger.

The paired fresh-world hitch fixture used a 256-block floor, twelve edits, and torch transitions.
Its commands use Minecraft chat, so measured intervals include that UI activity.
Edit P99 changed from 6.137 ms to 5.902 ms. Its maximum changed from 33.152 ms to 9.915 ms.
Frames above 16.667 ms changed from 13 to zero. Idle P99 changed from 5.678 ms to 5.467 ms.
Lighting maximum changed from 32.133 ms to 9.374 ms. Lighting P99 rose from 5.769 ms to 6.135 ms.
These bounded measurements do not certify stable 240 FPS or other maps.

All seven collision checks and seven render edit checks passed.
The floor used one Source convex instead of 256. Maximum measured collision construction was 1.0025 ms.
Holes, replacements, slabs, stairs, neighboring faces, exterior probes, and torch lighting remained correct.
The real placement and mining fixture passed all six checks at the native floor's Minecraft Y -12.
An initial Y -6 fixture was out of reach. Its collector also needed to wait for the PNG.
The Warden stress case completed 600 ticks and 120 paths, traveled 13.844 blocks, and removed its owned mob.
Read `frame-hitches-baseline/20261004-115434/artifacts` and `frame-hitches-candidate/20261004-120406/artifacts` under `%LOCALAPPDATA%/GarryCraft`.
The native and Fabric build passed with Java 25. PowerShell syntax and diff whitespace checks passed.

## October 4 CMD armor capture

PR #11 merged as `e74f103`. The prepared runtime uses the unchanged CMD launcher in a separate Downtown lab.
Full netherite armor reproduced empty arm meshes across 2,118 active baseline frames.
The candidate passes 14 checks across 2,110 frames with armor, and 14 across 2,265 frames without Source hands.
Independent GPT-6.1 SOL review passed 20/20 items. CodeRabbit skipped its automatic review.

Rapid placement and mining pass six checks across negative section boundaries.
An independent 47-log fixture exports its expected 108 faces, including the eight-block opening.
These results do not reproduce or resolve the reported persistent invisible blocks and missing neighboring sides.

Evidence: `%LOCALAPPDATA%/GarryCraft/cmd-render-candidate/20261004-093826`.
The configured CMD installation now matches all 275 tested code files.
Launcher, Minecraft settings, and saved-world hashes remain unchanged.


## October 4 block edits and physics gun arms

Native Release and Fabric builds passed in the owned `gmod-lab` single-player installation.
Artifacts remain under `%LOCALAPPDATA%/GarryCraft/render-edits-verified/20261004-081413/artifacts`.
Independent GPT-6.1 SOL review passed 20 static checks after fixes to cache bounds and the edit fixture.

The edit scenario passed six checks. It captured a concave tower, block removal and replacement, and an exposed section boundary.
Its 5,972 transition frames contained no lighting probe inside a solid Minecraft cell.
The baseline concave fixture sampled solid wood at its batch center and returned zero sky light.
Candidate PNGs show lit top faces around that same gap.
These traces check probe ownership and saved pixels. They do not prove that every visible face stays unchanged during all edits.

The missing-hands scenario passed 14 checks across 2,145 frames.
It removed the Source hands entity and used real walking, sprinting, stopping, and hotbar input.
Minecraft arms remained visible. Maximum gun-pose translation error was 0.0001221 Source units.
The test restored Source hands after completion.

All 31 receiver checks passed, including sealed walls, native crate and floor lighting, roof materials, and angled windows.
The final directional scenario passed 11 checks. The forty-torch scenario passed seven checks.
Density baseline P99 was 5.855 ms. Steady P99 was 5.761 ms, and the maximum frame interval was 11.296 ms.
The largest lightmap update was 4.555 ms, including a 4.528 ms upload.
These timings exclude startup and do not establish a frame budget for every map.

The linked `rp_downtown_tits_v2` lab imported 234,050 collision triangles and 1,836 static props.
Two eight-second performance phases passed with zero and 32 awake test props.
Source frame P99 was 5.899 ms and 6.869 ms. Maximum intervals were 18.660 ms and 29.702 ms.
This candidate check has no matched pre-fix Downtown timing comparison.
The lab lacks assets for 52 static props, which limits its geometry coverage.

Lighting still uses one sample per face batch and estimates the sun's share of baked Source irradiance.
Native lightmap tiles still update over several frames. Shadows do not update instantly everywhere.
The configured daily installation and its saved worlds were not changed.

## October 3 directional lighting and Minecraft gun hands

PR #9 merged as `cfca1bc`. The final candidate ran in the owned `gmod-lab` single-player installation.
Artifacts remain under `%LOCALAPPDATA%/GarryCraft/voxel-lighting-review/20261003-145741/artifacts`.
Native Release and Fabric builds passed. Independent GPT-6.1 SOL review approved all 24 checklist items.

The receiver captures pass 31 checks for sealed Minecraft walls, native floor and crate lighting, roof removal, and emitter visibility.
Clear glass, tinted glass, water, and an open front follow material transport. Sun-facing and opposite windows produce different direct light.
The directional test passes 11 checks at production strength 0.35. Fixed world shadow classifications agree by 99.56% after rotation and 99.42% after walking.
The 40-torch density scenario passes seven checks. Source frame p99 was 6.18 ms and the maximum was 12.59 ms.
These measurements cover this scene and hardware. They do not establish a universal 240 FPS budget.

Viewmodel captures pass 14 checks across 2,093 frames: Minecraft skin and sleeve arms, common bob, sprint, stop, and item switches.
The paired native input scenario passes 24 Source checks and 52 GarryCraft checks.
Angles match exactly. The largest sampled distance error was 0.64004 Source units.
The physical-input driver rejects focus loss. Interrupted runs were not accepted as evidence.

Displacement validation passes five checks against 150 Source collision samples, with no misses or flipped normals.
An actual zero-displacement `nowalls` map passes six lifecycle checks, including production callbacks on startup and after idle.
The cleanup scenario passes 11 checks and restores 34 modified lightmap tiles.
The updated CMD opened the configured daily game. Installed DLL and Lua hashes match the merged build.
The owned Minecraft process saved its test world before exit. Daily saved worlds were not opened during verification.

The direct sun share remains an estimate because Source bakes sun and lamp irradiance together.
Native luxel resolution limits shadow detail, and native prop lighting uses a coarse origin.
The native adapters target the pinned Windows x64 engine interfaces. Static and batched model paths received code review but no runtime fixture coverage.

## October 3 Source shadows and physics gun

The corrective build ran in the owned `source-lighting-fix` single-player `gm_construct` lab at 1920x1080.
Artifacts remain under `%LOCALAPPDATA%\GarryCraft\source-lighting-fix\verified\artifacts`.
The native module and Fabric build passed. This record covers the tested scenes, not all maps or addons.

The Source sun probe used a perspective white projector with constant attenuation and the map's sun direction.
Captures `source-sun-in-world-overhead-2937993` and `source-sun-in-world-roof-down-3233164` show shadows on Minecraft surfaces.
The overhead pair shows the pillar and wall shadow on the floor. The roof pair blocks the added direct light inside the room.
The roofed depth pass drew world meshes 15,729 times, including 7,062 draws of a batch spanning two block heights.
The first-person avatar had 642 depth draws and zero color draws after visibility guards.
The paired views and resolutions match; native brush traces do not obstruct the projector.
The hand and totem retain visible ambient lighting. These probes use elevated brightness to expose the shadow boundary.
Production uses one nearby projector at brightness 0.35. It cannot subtract light already baked into Source ambient.

The final prop fixture kept every requested body awake. Each phase used three seconds of warmup and twelve seconds of measurement,
with production sun shadows enabled and the Source camera stationary throughout this run.

| Awake props | Source p99 | Maximum frame interval | Geometry export p99 |
| --- | ---: | ---: | ---: |
| 0 | 5.51 ms | 7.10 ms | 0.23 ms |
| 32 | 6.00 ms | 11.90 ms | 1.20 ms |
| 96 | 7.14 ms | 14.60 ms | 2.81 ms |
| 192 | 10.35 ms | 19.46 ms | 10.78 ms |

The earlier installed baseline recorded 63.19 ms at 192 props. Its rendered view differed, so the comparison is not an exact paired benchmark.
These are frame intervals, not GPU timestamps. Stable 240 FPS remains unproven.

Windows `SendInput` passed all thirteen UI checks on the final candidate.
Creative search accepted `diamond` and `stone` after reopening. Two real Tab callbacks cycled chat suggestions;
typing, Enter, command execution, and reopening chat all remained usable.
The result records actual VGUI text callbacks and closes the Source input panel.

Real mouse input detached, rotated, froze, and mined a stone block in survival with an iron pickaxe.
The trace records vanilla progress through 0.1333 increments to completion. Tool damage increased by one and cobblestone dropped.
A moved chest retained its three diamonds. Mining it preserved a gold replacement in its original cell and water at its new position.
Holding the chest journal open denied its atomic commit: the body remained and tool damage stayed unchanged.
After releasing the file lock, a fresh attack consumed the body, wore the tool once, and emitted one chest plus three diamonds.
The save-failure log, consumption snapshots, and Minecraft inventory/entity chat observations remain with the run.
This proves the precommit failure case. Postdelivery deletion failure, abrupt process loss, and same-input vanilla break-time comparisons remain separate cases.

The review follow-up repeated the chest failure with player effects deferred until the durable commit.
The denied write kept exhaustion at 0.024999619, the chest mining objective at zero, and a fresh iron pickaxe undamaged.
Retrying changed exhaustion to 0.029999617, the objective to one, and tool damage to one; three diamonds dropped.
Adventure-mode pickup was rejected and retained the original dirt cell. A permission change during the asynchronous capture window remains an unforced timing case.

The clear-corridor native reference passed all 24 checks. The Minecraft item passed all 52 checks using the same Windows inputs.
This includes distance changes, rotation, snap, Use with W/S, freezing, reload, welded-group double reload, slots, menus, walking, and jumping.
The largest compared hold-distance difference was 1.489 Source units; the largest angle difference was 0.0017 degrees.
An earlier fixture was rejected because its reload ray hit a Minecraft collision entity instead of the Source world.
Another comparison hit different obstacles during the wheel snapshots. Those failed comparisons remain in the artifacts.
The final comparison uses the native floor and verifies a world or miss ray before double reload.

A real 60 ms Space press was compressed into 19.53 ms of server-observed jump state and produced no movement before the fix.
The cumulative press counter now survives until Minecraft's movement tick. The same physical key press produced a 1.25220334-block jump.
Synthetic oracle inputs preserve the production counter and do not replay earlier presses.
The final build passed all fifteen vanilla movement comparisons within the 0.000001-block tolerance.
A real Space press during the synthetic walk reference did not cause another jump after the oracle ended.
Fifteen resume samples kept the player grounded at Y 256.5. `oracle-jump-resume.json` records the press and samples.

The mesh-edit observer completed twelve seconds with 1,099 rebindings, no missing slots, and unchanged zero invalid-mesh, stale-entity, and wrong-thread counters.
The first/front third-person captures show the native cyan gun and Minecraft arms; the clone uses the installed weapon's skin 1.
Six changes between 1280x720 and 1920x1080 retained both processes and frame publication with production sun shadows enabled.
The final video report had zero invalid-mesh, invalid-depth, stale-entity, and wrong-thread counters.
This checks video mode changes, not every device-loss path.
After bridge stop, Source reported zero model proxies and receivers, a restored native hook, and no active sun projector.
Minecraft saved and exited normally while the gun was selected. Existing occupied-cell recovery conflicts retained their journals.

## October 2 native performance, lighting, and input

Both games ran in the owned single-player lab on `gm_construct`, with fresh Minecraft worlds and a 1920x1080 Source window.
Evidence remains under `%LOCALAPPDATA%\GarryCraft\native-polish`, outside tracked source.
The baseline is the installed runtime before this run. Its native hashes are recorded, but its exact source revision is not certified.

The same fixture kept 0, 32, 96, and 192 small physics props awake with gravity disabled and repeated forces.
Each count used three seconds of warmup and twelve seconds of frame measurement. Source retained its 240 FPS cap.
The runs used the same machine, map, settings, and fixture. These are frame intervals, not GPU timestamps.
Fresh sessions had different player positions, so this comparison does not hold the exact rendered view constant.

| Awake props | Baseline Source p99 | Candidate3 Source p99 | Baseline maximum | Candidate3 maximum |
| --- | ---: | ---: | ---: | ---: |
| 0 | 5.24 ms | 5.39 ms | 18.60 ms | 20.40 ms |
| 32 | 9.00 ms | 5.81 ms | 15.97 ms | 10.55 ms |
| 96 | 20.02 ms | 6.97 ms | 44.91 ms | 13.78 ms |
| 192 | 63.19 ms | 9.66 ms | 81.09 ms | 17.05 ms |

At 192 props, p99 improved by 84.7%. Frames above 16.667 ms changed from 200 of 1,263 to one of 2,438.
Geometry packing p99 changed from 41.35 ms to 6.64 ms. The candidate read no cached physics meshes during the captured steady state.
Its binary body was 27,250 bytes, with a 653-byte JSON header and 192 actors.
Read `baseline/artifacts/performance/result.json`, `baseline/artifacts/baseline-manifest.json`, and `candidate3/artifacts/performance/result.json`.
The unchanged no-prop case still has occasional hitches. These short runs do not certify stable 240 FPS or every physics addon.
After the final lighting fix, candidate8 repeated the 192-prop case: p99 was 9.37 ms, maximum was 16.07 ms,
and none of 2,608 frames exceeded 16.667 ms. Geometry packing p99 was 7.01 ms, with no cached mesh reads.
Read `candidate8/artifacts/performance/result.json`.

Candidate4 passed 58 moving collision and actor checks against Source's actual APIs.
Coverage includes translation, rotation, physics recreation, collision toggles, range return, entity-index reuse, and three skipped shape packets.
The maximum geometry difference was 0.00000384 blocks, within the 0.00003-block tolerance.
Actor checks include names with quotes and Unicode, NPC flags, dimensions, removal, and replacement generations.
Read `candidate4/artifacts/moving-geometry-result.json` and the paired records.

Candidate4 passed all 12 native mesh checks, including public/native pixel equality in all three coordinate spaces and visible rebuilds.
Six creations of a 12,288-vertex mesh took 17.17 ms through public Lua calls and 1.34 ms through native buffer writes.
This 12.8-fold difference measures mesh construction alone. Read `candidate4/artifacts/native-meshes-result.json`.
Candidate2 retained rendering through six owned video-mode changes. Its texture report recorded zero retired RGBA bytes.
The engine retained the tested texture handles, so this run does not prove every late-callback retirement path.

Candidate3 passed all 13 input checks through Windows `SendInput` into the owned GMod window.
The test used actual emulated keyboard and mouse events for creative-tab clicks, search text, repeated Tab completion, continued typing, and Enter.
It also reopened creative search and chat. Both commands executed, and the Source text callbacks recorded the actual events.
Read `candidate3/artifacts/ui-input-result.json` and its paired input traces.

Candidate4 passed all 25 lighting checks, including a closed room, inside and outside torches, a glass opening, water, and emitter budgets.
Separate pixel probes confirmed both avatar and block shadows on a raised Minecraft floor above the Source map roof.
At the matched pose, avatar brightness changed from 228.78 to 171.20, and block brightness changed from 210.70 to 160.06.
Adjacent floor-seam receiver probes passed. Read `candidate4/artifacts/lighting-results.json` and the `shadowOff` and `shadowOn` screenshots.
Five cancellation checks restored the archived planar-shadow setting and the original Source player shadow flag.
Read `candidate4/artifacts/lighting-cleanup-result.json`.

Final review found a stale local-light cache when a native brush moved while the Minecraft revision and sample position stayed fixed.
The owned Source fixture cloned a map brush, then opened and closed its line of sight to a synthetic torch emitter.
Before the fix, all 144 samples in the settled open window retained zero lights despite a clear engine trace.
Local light visibility now refreshes on the existing 250 ms ambient schedule.
Candidate8 passed all five fixed-position brush checks after the fix, with no settled-window mismatches.
This Source fixture isolates cache invalidation; it does not test Minecraft's emitter export.
The complete paired lighting scenario then repeated all 25 checks successfully.
Read `candidate8/artifacts/native-light-before-brush.json`, `native-light-after-brush.json`, and `lighting-results.json`.

These are bounded planar shadows. They use one receiver plane per caster, without clipping at height changes or wrapping arbitrary walls.
Their direction follows the map sun or a fixed fallback. They do not check whether a roof blocks that directional light.
Source world point lights do not gain per-pixel shadows. The engine projected-texture probe did not prove shadow casting by public IMesh.

Candidate5 passed all 15 same-input vanilla physics comparisons after canceling an active lighting test.
Maximum position error was 0.0000001145 blocks. Velocity and grounded state matched.
Its final case correctly walked off both fixture floors. Shared cleanup then removed protection while the player was still falling.
The resulting death was a test cleanup defect. Normal completion now resets both peers to the safe Source origin before restoring protection.
Cancellation retains the replacement test's spawn.
Candidate5 also passed the live off-range last-block removal check in `artifacts/architecture-result.json`.

Candidate7 repeated all 15 vanilla comparisons. Its five completion checks passed through eight seconds after the final case.
The player remained alive, grounded, connected, and at the Source fixture origin with no delayed death.
The collector uses Source's converted fixture origin, including the map's grid alignment.
Read `candidate7/artifacts/physics-cleanup-result.json` and each paired scenario trace.
All five scenario-handoff checks passed for physics to lighting, lighting to damage, and damage to lighting.
Both complete lighting replacements passed all 25 checks. The damage replacement passed all eight directions.
The interrupted lighting trace records `completed: false`. Each replacement restored the original game mode.
Read `candidate7/artifacts/scenario-handoff-result.json`, `candidate7/handoff`, and `candidate7/artifacts/damage-results.json`.

The prepared candidate runtime passed all 16 startup and persistence checks across `gm_construct`, `gm_flatgrass`, and `backrooms_main`.
The saved diamond block and Minecraft FPS option survived reopening. Source restored its weapon, movement, health, armor, collision group, and FPS limits.
Only one managed Minecraft process remained during the map cycle. Final disable left no orphan.
The first attempt stopped on a Windows sharing violation in the test's status reader, while Minecraft saved normally.
Status collectors now permit atomic replacement while reading an opened file generation. They retry only short Windows sharing conflicts.
Read `artifacts/startup-result.json`, `artifacts/startup-before-sharing-fix.json`, and the paired persistence logs.
Six injected collision-import failure checks left Source inactive and preserved movement, health, weapon, and its original shadow flag.
Read `artifacts/garrycraft-start-failure.json` and `Run-ManagedTests.ps1` for the owned fault scenario.
All four managed lifecycle checks passed, including startup disconnect, automatic reconnect, and normal host exit.
The separate fresh-world sharing scenario passed all seven checks with deliberately open status and shutdown files.
It retained the same Minecraft process, deferred status replacement, and held world ownership until saving finished.
Read `artifacts/lifecycle-result.json` and `sharing-final/runtime-sharing-result.json`.
The normal prepared runtime now matches the final native module, client class, and lighting addon hashes.
Launching `GarryCraft.cmd` twice opened one owned host at the menu. No normal Minecraft world loaded during this launch check.
Existing option and world metadata hashes remained unchanged. Read `cmd-update-result.json` and `normal-files-after.json`.

## October 2 particle resource reload

The managed launcher update exposed a particle crash during a paused resource reload.
`particle-baseline2` reproduced `No sprite at minecraft:textures/atlas/blocks.png` with live terrain particles and changed atlas packing.
Clearing only extracted quads still failed during restoration in `particle-final`.
The fix clears live particles, queued particles, and extracted quads at atlas upload, regardless of bridge input age.

`tools/Build.ps1` passed. `particle-final2` passed all nine paired reload checks.
The block atlas changed from 2048x2048 to 1024x512, then returned to 2048x2048.
Minecraft and Source each recorded 96 particle vertices before reload and 1,152 fresh vertices afterward.
Vanilla reported `T 0` after reload, and the original mipmap setting returned.
Cancellation during the `after` phase saved mipmap level 4 and completed the next lighting scenario.
All ten lighting checks passed, including water tint, torch lighting, and a single transparent surface.
The first post-reload gameplay run passed armor, both water animations, native-wall flow, villager movement, and cow movement.
Its golem moved 0.49 blocks, below the one-block threshold. The full collector therefore failed that run.
Read `polish-first-result.json` and its paired traces. Accepted destinations alone do not prove sustained wandering.
The repeat passed all twelve gameplay checks. Golem, villager, and cow travel reached 18.15, 17.69, and 21.06 blocks.
This difference shows that the fixed-seed setup does not fix every vanilla AI input or measure typical wandering frequency.

Evidence remains under `%LOCALAPPDATA%\GarryCraft\runtime-update\main-a835199`, outside tracked source.
Read `particle-final2/artifacts/particle-reload-result.json`, its paired traces, `particle-reload-cancel.json`, and `lighting-results.json`.
These cases cover vanilla resources and terrain particles. They do not certify third-party resource packs.

## October 2 map gameplay fixes

Both games ran in the owned single-player lab with fresh Minecraft worlds. `tools/Build.ps1` passed.
Evidence remains under `%LOCALAPPDATA%\GarryCraft\gameplay-polish`, outside tracked source.

The baseline rejected all sampled idle destinations. The corrected golem, villager, and cow used their vanilla goals.
Iteration 6 recorded maximum travel of 15.40, 5.46, and 10.85 blocks over 720 ticks.
These fixed-seed observations include destination probes. They do not measure typical wandering frequency on every map.

Iterations 3 and 8 passed all 11 paired gameplay checks. Plain, enchanted, and rear-view chest armor each exported 576 vertices.
Both water texture IDs produced 32 distinct pixel hashes. Source received the animated updates.
The water source remained present, and the cell across the native test wall stayed dry.
The armor base texture now renders. The separate animated enchantment glint overlay remains unsupported.
Iteration 6 repeated the AI and armor checks. Its water placement displayed only the still sprite.

Iteration 6 passed seven paired Downtown prop probes in `artifacts/map-probe-results.json`.
Real Source rays and imported rays hit the fountain, two light pole directions, and frozen, rotated, and OBB props.
The largest ray fraction difference was below 0.001. Every body movement probe stopped at the tested surface.
Source sweeps a box. The imported collider slides a cylinder, so curved and rotated surfaces can produce different stop fractions.

Downtown exported 234,050 total triangles, including 130,248 static prop triangles.
Of 1,836 BSP props, 1,286 requested solid collision. Fifty-two records had no available collision mesh or usable model bounds.
Most unavailable models were foliage or skybox objects. This does not establish complete collision for every installed map model.

Iteration 4 recorded 25 native footstep hook calls and 25 actual sound emissions during walk, sprint, crouch, and jump replays.
The matching native-ground movement traces stayed within 4.3e-13 blocks of vanilla.
Iterations 3 and 8 passed all 10 lighting checks. Iteration 3 passed all nine terrain checks.
These include water tint, torch lighting, material transparency, source removal, native placement, mining, and repeated fire/lava damage.

The native ramp regression used a temporary convex Source ramp and Minecraft's actual player movement.
Before the fix, all 50 descent samples failed, with about 0.053 blocks of separation from native contact.
After the fix, all 50 samples remained grounded. Maximum contact error was 0.00104 blocks.
Read `iteration6/artifacts/slope-before.json` and `iteration7/artifacts/slope-after.json`.
This ramp check is separate from vanilla box comparisons because Minecraft blocks cannot represent the same smooth plane.
The ramp jump replay also reproduced canceled upward movement before its fix.
Iteration 8 preserved the jump: 12 airborne ticks and a peak gap of 1.49 blocks above native contact.
The harness requires actual downhill travel, so stationary samples cannot pass.
Read `iteration7/artifacts/slope-jump-before.json` and `iteration8/artifacts/slope-jump-after.json`.

Iterations 5, 7, 8, and 10 passed all 15 same-input vanilla box comparisons. Maximum position error was 3.17e-13 blocks.
Velocity and grounded state matched in every case. The cases include fast walls, low walls, and actual elytra landings.
Read each scenario's paired tick traces beside `iteration5/artifacts/results.json`.

The export benchmark measured 100 warmed dynamic queries with no nearby solid props.
On `gm_construct`, median query time changed from 0.1385 ms to 0.0050 ms.
On Downtown, median query time changed from 0.4475 ms to 0.0038 ms.
Both implementations returned zero triangles at these positions. Read `iteration5/artifacts/*-export.json` for all samples.
Downtown's complete static export took 570.5 ms in the warmed run. Import occurs once per session.
These measurements cover collision query cost, not total FPS. They do not justify a new native threading architecture.

These cases do not certify every map surface, slope, fluid configuration, or high-speed collision.
Install the Source addon and Fabric runtime together because static packets now carry their full batch count.

The final run exposed pink HUD tiles and a pink hand after repeated map reloads.
A new procedural texture rendered correctly. Uploading to an existing runtime texture name still produced magenta GPU pixels.
The native module now assigns a fresh texture generation when the client module loads.
The real HUD and hand rendered correctly on startup and after another map reload.
Read `iteration8/artifacts/ground.png`, `texture-fresh.png`, and `texture-after-reload.png`.
The small red texture probe passed even before the fix. It alone does not prove recovery of the actual runtime textures.
Its paired reports record the new native generations. The normal HUD screenshots provide the visual recovery evidence.
The same Source and Java processes also retained correct HUD and hand textures through 1280x720 and 1920x1080 video modes.
Read `iteration8/artifacts/texture-video-1280.png` for the smaller mode.

Review found cancellation races in the gameplay and physics harnesses. Gameplay now cancels on link loss or session replacement.
It waits for queued setup and cleanup before another run replaces shared state. Physics preparation captures its reference mode before queuing.
Iteration 10 passed all 12 paired gameplay checks, including final cleanup with zero remaining test mobs.
Stopping, replacing the session, and immediately restarting each produced an incomplete trace with successful mob, block, and armor cleanup.
Read `iteration10/artifacts/cancel-*-minecraft.json` and their matching Source request records.
The subsequent complete run also found zero leftover mobs. These checks do not force the transport thread's exception path.

The user reported that creative search worked during investigation. The existing input path passed all eight responsiveness checks.
Iteration 9 typed `stone` through the Source text-entry callback and received 94 matching vanilla inventory items.
Backspace changed the query to `ston` and returned 96 items. Both mouse-release focus checks passed.
Read `iteration9/artifacts/responsiveness-results.json` and its paired Source and Minecraft traces.
The test selects the search tab through the vanilla API. It does not exercise a physical tab click or operating-system text input.
No production input change was needed.
## Manual bridge paths: October 2, 2026

The reported startup stack came from the manual control hook.
Its saved request pointed at `%LOCALAPPDATA%\GarryCraft\creative-targeting\20261002-final\bridge.bin`.
Windows resolved that file under Codex's `LocalCache\Local` directory. The manual marker also blocked managed startup.

`tools/Test-BridgePaths.ps1` passed six checks in `bridge-paths/20261002-072239/artifacts/bridge-path-result.json`.
Source PID 38768 and Minecraft PID 46936 used separate single-player `gm_construct` and a fresh Minecraft world.
Before the fix, the manual command remained on disk after execution. The saved Source baseline records that pending request.
After the fix, both games linked through the actual path and loaded collision geometry.
A fresh command created a new Source session and disappeared from disk.
Clearing the request ID and reloading the control hook retained that session and the same Minecraft instance.
Paired Source and Minecraft snapshots remain beside the result outside tracked source.
Both test processes exited after Minecraft saved its fresh world. The native and Fabric builds passed with Java 25.

This covers native attachment and command replay. The test does not reproduce the original external launcher's Windows path context.

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

## V1.0.1 installation and README

The release package passed all 20 installation and recovery checks in `readme-patch-install-check/release-install-result.json`.
The source checkout's actual CMD entry point passed all eight checks against the published V1.0.0 installer.
It forwarded game and runtime paths, installed both Minecraft mods, and preserved an unrelated addon.
The incomplete-package case printed extraction instructions. Evidence remains in `readme-source-install-check-2/source-install-result.json`.

The V1.0.1 player launcher passed all three checks in `readme-player-addons-check-3/player-addons-result.json`.
The probe addon loaded on `gm_construct` in single-player. The launch command retained Workshop and local addon support.
The game exited normally. This check does not certify compatibility with every addon.
The launcher used 1920×1080 windowed mode. An earlier default-video launch stalled, and the first map attempt exceeded 90 seconds.
The test now allows 180 seconds for the map. The successful run saved its addon report and launch command.
All evidence directories are under `%LOCALAPPDATA%\GarryCraft`, outside tracked source.
