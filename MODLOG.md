# GarryCraft mod log

## October 6, 2026

Linux x64 support lands beside the Windows build. Native modules compile as
`gmcl_garrycraft_linux64.dll` and `gmsv_garrycraft_linux64.dll` (ELF objects under
GMod's Linux module names) with a POSIX mailbox, monotonic clock, and dlopen-based
engine guards. Setup, play, uninstall, the Minecraft launcher loop, build, packaging,
and release-install checks ship as shell scripts with Steam library detection under
`~/.steam/steam` and `~/.local/share/Steam`. The Fabric clock reads
`clock_gettime(CLOCK_MONOTONIC)` on Linux, and file defaults fall back to
`~/.local/share/GarryCraft` without `LOCALAPPDATA`. The raw-offset mesh-shadow hook
stays disabled on Linux until its offsets are verified against real Linux binaries;
rendering and gameplay continue without custom mesh shadows. Linux engine `.so` pins
are recorded after the first verified Linux game build reports them. No Linux game
run has verified this yet; see `tests/release-install.md` for the Linux scenarios.
Linux modules link libstdc++ and libgcc statically and export only the GMod entry points.
Release packaging rejects modules that need glibc newer than the Steam Runtime's 2.31,
so Linux releases must be built in the sniper SDK.
Setup and play support Flathub Steam. The player folder defaults to a path inside the Steam sandbox,
because GMod starts the Minecraft runtime from inside it.
`play.sh` passes game options through `steam://run`. Steam ran `+` options from `steam -applaunch`
as its own console commands, so the session marker never reached GMod. `play.sh --map <name>`
starts a map directly for Flatpak Steam, whose sandbox stops GMod's HTML main menu from loading.
The server module starts `runtime.sh` with bash and clears GMod's library paths. `/bin/sh` is dash
inside the Steam Runtime container, so the Minecraft launcher previously exited before writing its log.
Linux no longer raises `fps_max` to 240. That call used Windows ConVar dispatch slots, which differ on Linux,
and crashed GMod when Minecraft attached. The player's frame cap stays unchanged until the Linux layout is verified.

## October 5, 2026

V1.0.4 makes Play.cmd opt into GarryCraft for the current process. Normal GMod startup loads no bridge code or native modules.
Uninstall.cmd resolves recorded game and runtime paths. It removes program files while preserving saved data by default.
Its -Purge option removes the selected player installation completely. Locked files and redirected child folders stop cleanup before deletion.

V1.0.3 retains existing model-render callbacks instead of rejecting hooks such as ZXC.
Shadow shutdown retains callbacks installed later and reuses that layer when the bridge starts again.
A rejected shadow adapter reports its exact check once. Mesh rendering and gameplay continue without custom mesh shadows.

The packaged launcher now explains how to run setup when its player configuration is missing.
Player documentation gives the default installed launcher path and recovery steps for the missing `installer/install.json` error.
V1.0.2 puts `Install.cmd` and `Play.cmd` beside each other in the extracted release folder.
Setup records the installed player path so the folder launcher can use a custom runtime location.
Clean-install tests record empty runtime and game payload folders before setup and disable external download caches.

V1.0.1 simplifies the player README and adds the supplied showcase screenshot.
The source checkout's `Install.cmd` downloads and verifies the matching compiled release instead of requiring a local `release.json`.
The CMD entry point isolates Windows PowerShell's module path from an inherited PowerShell 7 environment.
Player setup now suggests any single-player Sandbox map. The normal launcher retains enabled Workshop and local addons.
The player launcher uses the tested 1920×1080 windowed mode to avoid a default-video startup stall.

V1 adds a Windows x64 release installer and player documentation.
The release ZIP contains matching Fabric, Lua, and native modules. Setup downloads private Java and Minecraft dependencies with checksum checks.
Setup detects Steam libraries, checks native engine builds, and installs a separate Minecraft mod directory.
Game copy failures restore previous files and print manual copy paths. Existing worlds, preferences, and unrelated addons remain in place.
Native modules now link their C++ runtime statically. Release packages need no separate C++ runtime installation for these modules.
Installer and production-runtime results remain outside tracked source.

## October 4, 2026

Source now owns all visual lighting and shadows. Section packets contain geometry and collision without Minecraft light fields or emitters.
The voxel sampler, sun rays, ambient overrides, runtime lightmap adapters, custom RTT receivers, and their controls were removed.
Blocks use native model lighting. Sorted water and first-person meshes use one shared native model draw.
Glow materials retain self-illumination. Map lightmaps retain Source's baked lighting.
Block updates no longer wait for light propagation or resend geometry for light-only changes.
The native mesh caster adapter retains the actual block and avatar silhouettes in Source's shadow atlas.


The launcher retains its last complete Source heartbeat through empty, partial, missing, and locked file reads.
Source writes that file in place. A transient read previously ordered Minecraft to save and exit.
Failed reads do not extend the 120-second heartbeat deadline. Disable and host exit still stop Minecraft normally.
Launcher and Minecraft logs now identify requested shutdowns.

The transport worker merges touching collision boxes without changing their combined volume.
Light-only updates retain Source physics bodies. Block edits retain unchanged mesh batches and their model and shadow ownership.
Nearby section scans use a 0.25 ms scheduling target across frames.
Navigation caches belong to their Minecraft thread instead of sharing a mutable fastutil map.

The paired edit fixture reduced its maximum frame interval from 33.152 ms to 9.915 ms.
Frames above 16.667 ms fell from 13 to zero. These measurements do not certify stable 240 FPS.
Read the local test record for artifacts and coverage.

Minecraft physics gun arms now use an owned, installed citizen support skeleton.
They draw with the viewmodel even when the selected Source player model has no hands entity.
The support skeleton remains available during item switches and retires when the bridge stops.

Native mesh construction chooses a real triangle near each face batch's center for its lighting probe.
Concave batches cannot sample a solid block in their missing center.
The probe also avoids the first triangle's preference for low corners below native flooring.
This remains one lighting sample per batch, rather than per-pixel Minecraft lighting.

Block edits prioritize neighboring sections across their shared boundaries.
Geometry completion allows up to two Minecraft ticks for pending light propagation.
Light-only callbacks reuse cached section geometry. The cache retains only nearby sections.

The native lighting module records bounded regions of light and occluder changes.
Sun rays and lightmap receivers retain cached results when those regions cannot affect them.
Native uploads retain the existing frame budgets. They do not update every shadow in one frame.
The direct sun contribution remains an estimate of Source's baked lighting.

See the local test record for measured results and limitations.

## October 3, 2026

Minecraft now exports completed vanilla SKY and BLOCK light for each section, with a one-cell halo.
Each 18 x 18 x 18 snapshot carries material dampening, light-shape metadata, and vanilla's 16-level dimension brightness table.
Light propagation updates invalidate exported sections after the engine publishes its visible storage. Light changes in empty sections also export.

Source applies propagated sky and warm block irradiance to Minecraft meshes, native model ambient cubes, and brush and displacement lightmaps.
The native adapters preserve original runtime irradiance for restoration. Source materials, self-illumination, and dynamic lights retain their rendering paths.
Unknown sections retain the Source baseline. Exported Minecraft casters can still reduce its estimated direct sun contribution.
Surface probes sample adjacent air rather than solid mesh interiors.

The sun uses Source's fixed world direction. Receiver normals estimate its baked contribution with a 0.35 directional weight.
Vanilla SKY supplies indirect light. Direct transmission uses the actual Source sun ray, even when vanilla SKY is zero.
Receiver irradiance is `original * (sky * (1 - share) + share * T) + warmBlock`, with `share = 0.35 * max(0, normal dot sunDirection)`.
`T` is material transmission toward the sun. The renderer applies this calculation before material shading.
Source's baked sun and baked lamps remain inseparable, so this decomposition is approximate.
Native models use a coarse lighting origin. Native luxels can span 64 Source units, so small shadows have soft boundaries.
This estimate cannot recover the map's separate baked global illumination or static lamp contributions.
Minecraft sky propagation does not include native BSP geometry and does not provide physical global illumination.

Clear glass, tinted glass, water, and other materials follow their vanilla light contracts. No material-name rules choose their attenuation.
Direct transmission uses material dampening and separate light shapes. Full dampening blocks even when a material disables face culling.
Opaque-cell samples retain their raw values and skip trilinear interpolation. Nearby exterior air cannot leak into sealed floor and wall probes.

Native lightmap work uses a soft two-millisecond CPU budget and processes 64 luxels at a time.
Only complete tiles upload, with four-tile and 4,096-pixel batch targets. Reports expose unfinished receivers and upload costs.
Lua displacement mapping also uses a soft two-millisecond build budget. Complete-face registration and engine uploads can exceed these CPU targets.
The transport thread hashes section mesh metadata and vertex bytes with SHA-256 before appending voxel light.
Light-only updates retain GPU meshes, model proxies, and shadow registrations. Separate voxel and occluder revisions still invalidate lighting.

Source hand suppression now survives missing Minecraft arm meshes during scene delivery and resets.
The gun and captured skin and sleeve meshes share Minecraft's exact first-person bob and hurt matrix.
Source's additional viewmodel bob and sway are omitted. Native bone animation and gun controls remain native.

Repeatable scenarios capture sealed receivers on a Minecraft wall, a native crate, and native flooring.
They compare roof materials, an open front, inside and outside torches, and fixed world shadow samples during camera movement.
Angled-window cases compare actual sun transmission and native floor pixels through matching and opposite windows.
The hand scenario captures walking, sprinting, stopping, and hotbar changes. See the test record for measured results.

The final receiver run passed 31 checks. The clean directional fixture passed all 11 checks, and the forty-torch density run passed seven.
Density frame intervals had a 5.931 ms baseline P99 and a 6.180 ms steady P99. The largest frame interval was 12.591 ms.
The largest lightmap update during that scenario was 4.040 ms. These values exclude map startup and test-only displacement verification.
Separate production startup mapping reached about 10 ms. Displacement verification passed five checks with 150 rays and a 24.284 ms maximum build.
That verification found no missed surfaces or reversed normals. Maximum position error was 0.000092 Source units.

Opaque avatars, Minecraft sections, mobs, and dropped items now use Source model entities with their actual mesh, material, transform, and bounds.
The native module supplies custom silhouettes to Source's render-to-texture (RTT) shadow path. Source owns projection, clipping, and the shadow atlas.

Queued rendering preserves casts onto BSP surfaces. The native guard disables RTT model receivers because Source rejects their material proxy in queued draws.
RTT receivers on studio and custom models require an immediate render context. The addon leaves the game's queue mode unchanged.

The first-person avatar casts native RTT shadows while its color draw stays hidden. The attached native Source player shadow stays suppressed.

Mesh revisions rebind existing entities and shadow registrations before retiring old meshes.
Entity creation and removal run in `Think`, outside render hooks. Retired entities stop drawing immediately.
Temporary link loss retains mesh bindings for recovery. Session changes and video resets retire the old render ownership.

Block batches retain separate receiving faces and planes within four-block tiles, along with texture and emissive state.
The native builder keeps each triangle's normal. Transparent batches retain their existing manual lighting and face sorting.

Source's ambient irradiance supplies the baseline for propagated sky light. Manual lit meshes preserve native dynamic lights and add propagated block light.
Runtime lightmap adapters preserve the original Source data and leave BSP files unchanged. Source point lights retain their engine limits.
The native shadow path requires the exact Windows x64 engine builds pinned in `native/src/sdkcompat.hpp`. It has no planar fallback.

Source counts jump presses so short keyboard taps survive Minecraft's movement tick. Render frames cannot clear a pending press.
Synthetic physics comparisons preserve the normal input counter instead of replaying historical presses afterward.

Minecraft now registers a Physics Gun item in Tools & Utilities. Selecting it uses Source's installed `weapon_physgun` and native prop behavior.
GMod's bound Use key rotates held objects. I opens Minecraft inventory, and the mouse wheel adjusts hold distance.
Deselection, death, and bridge shutdown release the held object. Section collision mirrors remain fixed.

Source renders the installed gun's native viewmodel and `models/weapons/w_physics.mdl` world model.
Captured Minecraft skin and sleeve meshes attach to the native hand and forearm bones. Valve model files and textures remain in the installed game.

Individual Minecraft blocks detach into Source physics bodies after the client receives their model and section removal.
Recovery journals retain their original cell, block state, and block entity data through `prepared`, `detached`, and `restoring` phases.
Stopping or restarting restores unmined blocks to their original cells. Occupied cells retain the journal and report a conflict, including identical replacement blocks.
Recovery saves restored chunks before deleting completed journal files.

Detached block mining uses Minecraft's tool, progress, and loot rules. A durable `broken` journal replaces block restoration with captured loot recovery.
Recovery reuses saved loot entity UUIDs. After the world save, `delivered` records prevent journal cleanup failures from emitting that loot again.

These entries describe implementation changes. See `tests/RESULTS.md` for runtime evidence.

## October 2, 2026

Moving collision now sends cached local shapes and binary transforms instead of rebuilding JSON world triangles each Source tick.
Actor bounds use typed binary records. Minecraft decodes and indexes collision on a dedicated worker, then publishes an immutable snapshot.
Shape acknowledgments survive skipped packets, range return, and reused entity indices.

The verified native client fills Source mesh buffers directly. Mesh creation and rendering retain GMod's normal ownership.
Render generations move encoding and tile comparison off Minecraft's main thread. Off-range edits retain their dirty state, including last-block removal.
Video-reset retirement releases old RGBA buffers while keeping callback storage safe for late engine calls.

Creative search clicks now retain text focus. Tab completion no longer triggers Source focus traversal.
The Windows keyboard and mouse scenario passed typing, filtering, repeated completion, Enter, and reopening chat.
Physics replay completion now returns both players to the safe fixture origin before restoring protection. Cancellation retains the replacement spawn.

Minecraft exports occlusion shapes separately from collision shapes. Local torch visibility uses these shapes; glass admits light.
Manual mesh lights use all exported emitters, independently of Source's world-light budget.
Their cached visibility refreshes with ambient sampling, so native brush doors can block and reveal stationary torch lights.
The October 3 lighting correction replaces this revision's ambient handling.
See `docs/ARCHITECTURE.md` and `tests/RESULTS.md` for measured performance and rendering limits.

Atlas uploads now clear live, queued, and extracted particles together. Resource reloads cannot reuse the previous atlas coordinates.
The paired resize-and-restore test passed. Cancellation restored saved mipmaps, and all ten lighting checks passed after reload.

Idle Minecraft ground mobs now accept destinations supported by native terrain. Vanilla goals and villager brains still choose their movement.
BSP static props now export their installed models' collision meshes, including Downtown light poles and fountains.
Moving geometry uses Source's spatial partition and cached physics meshes. Minecraft publishes one complete immutable map index after static import.

Collision resolves vertical movement before horizontal movement. Short elytra poses remain in wall tests after landing.
Flat ledges use Minecraft's falling behavior. Crouching uses native support instead of bypassing vanilla edge checks.
Downhill contact uses the supporting footprint sample instead of the ramp's center height.
The physics replay now starts initial velocity after settling. It records actual elytra cases and restores test armor and invulnerability.
Test cancellation now restores gameplay fixtures on link loss or session replacement. Restarts wait for queued cleanup.
Physics preparation retains its captured reference mode when cancellation changes the active pass.

Grounded player movement now plays the native Source surface's footstep sounds. Sneaking, flying, gliding, swimming, and open menus suppress them.
Enchanted armor retains its base texture in third person. The separate animated enchantment glint overlay remains unsupported.
Animated sprites retain fair transfer order. Skipped animation boundaries still publish the current frame.
Procedural texture names use a new generation when the client module loads. Map reloads cannot retrieve released texture handles.
Native walls block fluid transfers between adjacent cells. Water retains its Minecraft grid, biome tint, Source lighting, and transparency order.

The owned lab passed 15 vanilla movement comparisons, seven prop probes, native footsteps, idle mob movement, armor, water, lighting, and terrain checks.
See `tests/RESULTS.md` for traces, measured export costs, and limits. These cases do not certify every map surface or improve every FPS bottleneck.
Creative search passed typing, filtering, Backspace, and text focus checks through the existing input path.
Update the Source addon and Fabric runtime together because static packets now include the complete batch count.
An old manual test request prevented normal Minecraft startup and used a Windows redirected path.
The manual launcher now passes actual filesystem paths to both games.
Source deletes each control request before execution, so map entry cannot replay completed or failed commands.
Six checks passed with both games in a fresh owned world. Paired snapshots confirm attachment and no replay after hook reload.

Native Source NPCs now stop targeting the player while Minecraft publishes creative mode.
Existing enemies lose their player target. Newly spawned NPCs receive the same protection.
Friendly NPCs retain their player relationships and visibility. Native combat with other entities remains available.
Leaving creative mode or stopping the bridge restores the original relationship dispositions and priorities.
Hostile NPCs still treat Minecraft mobs according to their original allegiance.

The isolated fresh-world scenario passed 13 checks through both live games. Minecraft damage did not provoke creative retaliation.
The test records paired snapshots and restores its game mode. It removes its owned NPCs and cow.
Coverage includes combine soldiers, citizens, and a newly spawned zombie. NextBots and addon-specific target logic require separate tests.

## October 1, 2026

The 20:48 Downtown session ended after Source's five-second state timeout requested a normal Minecraft shutdown.
Minecraft saved its world. No Minecraft crash report appeared. An eight-second process pause reproduced the shutdown in a fresh world.
Managed sessions now allow 120 seconds for temporary loading stalls. Manual test sessions retain their five-second timeout.
The launcher still detects process exit. Disable and host exit still request a normal save immediately.
Source logs the session and elapsed time when its state timeout expires.

The 20:16 Downtown session stopped after the launcher could not replace a JSON file held open by a reader.
GMod remained running. Minecraft saved and exited after the launcher reported the error.
Runtime JSON replacement now defers Windows sharing violations (32 and 33) without changing the previous complete snapshot.
Status changes retry on later polls. Unchanged status is not rewritten. Shutdown retains the world mutex while sending its control request.
Seven checks with a real Minecraft process passed while status and control readers denied file replacement.

GMod now starts the prepared local Minecraft runtime after single-player map entry.
A saved enable switch, Spawn Menu panel, and `garrycraft_menu` control startup and normal Source play.
`GarryCraft.cmd` at the repository root opens the prepared installation and reuses an existing host window.
Each map has a separate world. Options remain shared. The launcher uses a mutex, map heartbeat, and host process lifetime.
Disable and map changes ask Minecraft to save and exit before another world starts.
Video initialization can pause the map heartbeat for up to 120 seconds. Expired requests cannot restart against an open Source mapping.
The prepared runtime launches Java directly. It contains local dependency copies and uses the existing asset cache.
Source restores player movement, health, armor, the previous weapon, and frame limits after Disable.
Client workers close their mappings when inactive. Repeated sessions reuse texture names and refresh material bindings after video resets.

The October 1 18:26 Source dump records an access violation at `server.dll+0x2A126F`.
Its caller at `server.dll+0x5D59B5` passes a null citizen squad into the member-count routine.
The instruction sequence matches `CNPC_Citizen::FixupPlayerSquad` and `AddToPlayerSquad` in Valve's Source SDK.
The later Windows `engine.dll` invalid-argument failure occurred in crash reporting, after that original fault.
Owned test citizens now use `SF_CITIZEN_NOT_COMMANDABLE` (1048576), and finished scenarios remove their test entities.
Ordinary addon NPC squad rules remain unchanged. Dump evidence stays outside tracked source.

The Source client now publishes look and menu input directly to Minecraft at the render rate.
Acknowledged cursor events preserve short clicks and deliver wheel input to vanilla menus.
Continuous yaw prevents full-turn hand sway at the Source angle boundary. Attached clients disable the Minecraft movement tutorial.

A native Source worker copies render packets. Lua receives small headers and native handles instead of large binary strings.
Menu captures follow the Source target rate. The Minecraft transport thread compares pixels and assigns tile revisions.
Source reuses unchanged tiles. Source NPC targeting examines at most 32 pairs and issues at most 12 sight traces per update.
Minecraft keeps input transfer separate from render packing. The hidden renderer stops at Source's target rate or a lower saved limit.

Water uses Source ambient and point lighting through its transparent material. Duplicate reverse fluid faces are removed before export,
so each two-sided water surface draws once with one lighting normal. Lava retains its emitted light.
Water also passes Minecraft's biome tint through the lit material, which otherwise ignores vertex colors and renders gray water.
New mirror profiles now apply the Unlimited FPS default even when Minecraft returns early from its options loader.
The camera uses Source's current render angle. The responsiveness and lighting collectors save repeatable evidence.
Responsiveness tests no longer enter the physics oracle's reference replay.
Empty lighting-test requests no longer reset Source's view angle during normal play.
Frame percentiles remain separate from correctness checks.
The crowd scenario verifies target selection for 24 native NPCs against 15 Minecraft mobs, bounded scans, and test cleanup.

GarryCraft keeps Minecraft Java 26.3 and Windows x64 Garry's Mod in separate processes.
The Fabric mod owns player movement, game rules, fluids, projectiles, and mob AI.
Source supplies collision geometry, native NPCs, props, input, lighting, and final rendering.

The port extends the existing SkyCraft triangle collider to server entities and exact surface ray casts.
An immutable triangle index bounds nearby queries. Source navigation supplies floor heights to Minecraft ground paths.
Vanilla movement constants stay in Minecraft.

Minecraft exports placed sections, block collision shapes, animated fluid textures, entities, items, particles, and mining effects.
Source builds meshes through its public Lua mesh API. Transparent block faces sort across sections.
Torches and lava use self-lit materials. Source model lighting must be prepared before ordinary mesh draws.
Each mesh samples ambient light at its world position. Torch point lights illuminate meshes independently of camera distance.
Floor and wall torches export their flame positions. Source reserves 16 world lights and supplies four local lights per mesh draw.
Minecraft lighting updates invalidate exported sections through the complete section-dirty API.

Source entity stand-ins resolve Minecraft attacks and environmental effects.
Acknowledgments retain hits until Source applies them. Creation IDs prevent recycled entity indices from receiving stale hits.
Damage controls cover player, mob, native NPC, and environmental damage directions.
Minecraft mobs have invisible Source bullseyes for native target selection and return fire.

Transport work runs outside game threads. Game API calls remain on their owning threads.
Cached item geometry, bounded section work, asynchronous HUD readback, and changed texture uploads reduce repeated work.
Both games record frame times. The current Source scenario still fails the stable 240 FPS budget.

Video resets retire invalid texture handles and request fresh render state.
Every attachment has a fresh render instance. Texture acknowledgments include that instance to reject late replies.
Minecraft options persist outside fresh world directories. New profiles default to Unlimited FPS.
GMod uses a 240 FPS cap while the bridge runs.

Tests use `%LOCALAPPDATA%\GarryCraft\gmod-lab`, which has the required `.garrycraft-lab` marker.
Minecraft test worlds and all generated evidence stay under owned run directories outside tracked source.
The installer refuses to replace modules in a running test installation.
The user's Steam installation and existing Minecraft worlds remain outside these tests.

The source repository is [PeytonWDYM/GarryCraft](https://github.com/PeytonWDYM/GarryCraft).
SkyCraft source attribution and its MIT license appear in [third-party notices](THIRD_PARTY_NOTICES.md).
[Universal Modder](https://github.com/rehan-remade/universal-modder) supplies game research and screenshot tools.
See [feature coverage](PARITY.md) and [test results](tests/RESULTS.md) for current limits.

PR #9 merged as cfca1bc. Final native input checks pass 24 Source cases and 52 GarryCraft cases.
The zero-displacement map passes six lifecycle checks. The daily runtime and CMD use the merged build.
See tests/RESULTS.md and the owned voxel-lighting-review capture directory for final evidence.

The CMD armor capture fix in PR #11 keeps the skin arms before armor submits its models.
The configured CMD runtime matches the merged build. Armored checks pass with and without Source hands.
The persistent block-hole report remains unresolved. The owned rapid-edit and 47-log opening checks pass.
