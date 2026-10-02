# GarryCraft mod log

## October 2, 2026

Idle Minecraft ground mobs now accept destinations supported by native terrain. Vanilla goals and villager brains still choose their movement.
BSP static props now export their installed models' collision meshes, including Downtown light poles and fountains.
Moving geometry uses Source's spatial partition and cached physics meshes. Minecraft publishes one complete immutable map index after static import.

Collision resolves vertical movement before horizontal movement. Short elytra poses remain in wall tests after landing.
Flat ledges use Minecraft's falling behavior. Crouching uses native support instead of bypassing vanilla edge checks.
Downhill contact uses the supporting footprint sample instead of the ramp's center height.
The physics replay now starts initial velocity after settling. It records actual elytra cases and restores test armor and invulnerability.

Grounded player movement now plays the native Source surface's footstep sounds. Sneaking, flying, gliding, swimming, and open menus suppress them.
Enchanted armor retains its base texture in third person. The separate animated enchantment glint overlay remains unsupported.
Animated sprites retain fair transfer order. Skipped animation boundaries still publish the current frame.
Procedural texture names use a new generation when the client module loads. Map reloads cannot retrieve released texture handles.
Native walls block fluid transfers between adjacent cells. Water retains its Minecraft grid, biome tint, Source lighting, and transparency order.

The owned lab passed 15 vanilla movement comparisons, seven prop probes, native footsteps, idle mob movement, armor, water, lighting, and terrain checks.
See `tests/RESULTS.md` for traces, measured export costs, and limits. These cases do not certify every map surface or improve every FPS bottleneck.
Update the Source addon and Fabric runtime together because static packets now include the complete batch count.

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
