# GarryCraft mod log

## October 3, 2026

Opaque avatars, Minecraft sections, mobs, and dropped items now use Source model entities with their actual mesh, material, transform, and bounds.
The native module supplies custom silhouettes to Source's render-to-texture (RTT) shadow path. Source owns projection, clipping, and the shadow atlas.

Queued rendering preserves casts onto BSP surfaces. The native guard disables RTT model receivers because Source rejects their material proxy in queued draws.
RTT receivers on studio and custom models require an immediate render context. The addon leaves the game's queue mode unchanged.

One public Source `ProjectedTexture` now supplies perspective sun shadows within a nearby footprint, including Minecraft mesh self-shadowing.
It uses Source's sun direction and color, constant attenuation, and the public `GetRenderMesh` depth path under queued rendering.
The projector preserves BSP ambient lighting. A roof blocks its added direct light, without removing light already baked into the map.
The first-person avatar casts RTT and projected depth shadows while its color draw stays hidden. The attached native Source player shadow stays suppressed.

Mesh revisions rebind existing entities and shadow registrations before retiring old meshes.
Entity creation and removal run in `Think`, outside render hooks. Retired entities stop drawing immediately.
Temporary link loss retains mesh bindings for recovery. Session changes and video resets retire the old render ownership.

Opaque block batches now combine planes within four-block tiles, retaining texture and emissive state.
The native builder keeps each triangle's normal. Transparent batches retain their existing manual lighting and face sorting.

Source ambient lighting remains intact. Manual lit meshes preserve native dynamic lights and add visible Minecraft torch lights separately.
Minecraft geometry does not rebake BSP lightmaps. Source point lights retain their engine limits and do not acquire per-pixel shadows.
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
The October 3 rendering correction replaces this revision's custom shadow pass and ambient masking.
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
