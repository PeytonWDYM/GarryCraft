# Bridge protocol

The bridge uses a local 128 MiB memory-mapped file with nine single-writer mailboxes.
Each mailbox has a 64-byte header and a fixed payload capacity.

| Lane | Writer | Capacity | Content |
| --- | --- | --- | --- |
| 0 | Source server | 64 KiB | Input, session, viewport, acknowledgments, mob damage |
| 1 | Minecraft | 4 MiB | Player state, camera, combat events, mob states |
| 2 | Source server | 16 MiB | Static collision batches |
| 3 | Source server | 8 MiB | Nearby moving geometry, entity bounds, native water |
| 4 | Minecraft | 16 MiB | Texture header and RGBA pixels |
| 5 | Minecraft | 8 MiB | Scene header and packed meshes |
| 6 | Minecraft | 64 MiB | HUD header and visible RGBA tiles |
| 7 | Minecraft | 8 MiB | Block section header, meshes, collision boxes, lights |
| 8 | Source client | 64 KiB | Render-rate look, cursor, menu buttons, wheel, keys, viewport, and hotbar selection |

All integers use little endian. Each header contains a sequence at byte 0 and payload length at byte 4.
The writer sets an odd sequence, writes the payload, then publishes the next even sequence.
The reader copies an even sequence, copies the payload, and checks the sequence again.
A changed or odd sequence means the reader must retry on the next frame.
Sequence access uses acquire/release ordering across processes.

Lanes 0 through 3 and lane 8 contain UTF-8 JSON. Protocol version 1 rejects other versions.
Render lanes contain one JSON header, a newline, and a binary body.
Each mesh vertex occupies 24 bytes: five float32 values for `x,y,z,u,v`, then four uint8 RGBA values.
Mesh metadata stores byte offsets and vertex counts. Each mesh contains at most 65,532 triangle vertices.

Positions map Source `(x,y,z)` to Minecraft `(x/32,(z-gridHeight)/32,-y/32)`.
Relative vectors omit `gridHeight`. Source units per block are fixed at 32.
Source persists the vertical grid alignment per map with alignment format version 2.
Flat terrain aligns to block faces. Slopes retain their native triangles.
Yaw maps to `-SourceYaw - 90`. Pitch uses the Source pitch.
Minecraft remains the owner of player position after the initial attachment.

Static geometry uses numbered batches and acknowledgments. Input snapshots must not replace geometry batches.
Each static packet includes `batch` and `total`. Minecraft publishes one immutable map index after the last batch.
The static stream includes BSP static props. Update the Source addon and Fabric mod together.
Minecraft releases input after one second without Source. Manual sessions stop after five seconds without Minecraft state.
Managed sessions allow 120 seconds for loading stalls. The launcher detects Minecraft process exit and stops the bridge independently.

Source issues a monotonically increasing `teleportSeq` on attachment and respawn.
Input origin remains the chosen spawn until Minecraft publishes its matching `teleportAck`.
Both Source movement and camera reject poses with an older acknowledgement.
Minecraft sends a cumulative `deaths` counter to trigger the matching Source respawn.

Lane 3 also supplies a 9-by-9 water-surface grid. Minecraft substitutes this water during entity fluid checks.
## Current clock and camera

The native client reads lane 1 directly. Player state includes previous/current raw tick positions, tick period, and a Windows performance-counter timestamp.
The Source camera interpolates the raw tick history on the same clock. It never treats post-gravity velocity as camera displacement.
Minecraft publishes camera FOV and bob after its render frame. Source converts the vertical FOV to the horizontal 4:3 setting.
Minecraft releases bridge controls after one second without Source input. Source restores its player after the session's state timeout.

## Sessions and delivery

Each Source attachment creates a new session. Each Minecraft process has an instance ID.
Texture and scene packets carry a render instance ID, which changes after attachment, resource reload, or Source video reset.
Source rejects render packets from another session or render instance.

Texture transfers use ordered IDs and acknowledgments that include the render instance.
Source accepts acknowledgments only from the attached owner and current instance. Acknowledgments never move backward.
Animated sprites replace pending updates with their latest pixels.
Pending sprite IDs retain arrival order so one busy animation cannot starve other sprites.
Block sections repeat until both Source realms acknowledge them. Their acknowledgment includes the render instance.
Scene and HUD snapshots contain complete current state. Skipped mailbox frames must not leave stale items or HUD tiles.
HUD tiles carry content revisions. Source uploads a tile only when its revision changes.
HUD capture timestamps use the shared performance counter to measure capture-to-Source delivery.
Scenes carry cached item model IDs and twelve matrix values per item instance.
Item transforms come from Minecraft's renderer, including its bob, rotation, and stack offsets.

Combat events retain IDs until acknowledged. Source entity index and creation ID identify a combat target.
Minecraft stand-ins resolve vanilla weapon damage before Source applies `garrycraft_damage_scale`.
The default scale is ten Source health points per Minecraft damage point.
Hits carry environmental damage separately from attacker damage, so lava and fire use the environmental multiplier.
Archived damage controls provide separate player-to-Source, mob-to-Source, Source-to-player, Source-to-mob,
player-to-mob, mob-to-player, mob-to-mob, and environmental multipliers.
Source publishes these controls to Minecraft. Minecraft applies its directional multiplier before vanilla armor calculations.
Explosion events include Minecraft's three-dimensional impulse in blocks per tick.
Source converts that impulse to units per second before it changes a loose prop's velocity.

Minecraft mob states use UUIDs. Invisible Source bullseyes provide native aim targets for Source NPCs.
Bullseyes are excluded from exported bounds and geometry to prevent a feedback loop.
Source damage events include the mob UUID and the Source attacker's creation ID.
Minecraft applies each acknowledged event once through its normal damage API.
Removed mobs, stopped bridges, and new sessions remove their Source bullseyes.

Lane 1's `gameMode` controls native NPC targeting while linked. In creative mode, Source temporarily neutralizes hostile and fearful player relationships.
Source clears the player from enemy memory and cancels a schedule that targets the player. Friendly relationships remain available.
Leaving creative mode or stopping the bridge restores each saved disposition and priority.
Minecraft mob targeting uses the NPC's original player disposition, so creative protection does not change its allegiance toward mobs.

Source increments `renderEpoch` after a video reset. Minecraft changes its render instance and resends textures and sections.
Player state and gameplay continue during render resynchronization.
Mesh metadata includes a center. Source uses that center to sort transparent block faces across sections.
Mesh metadata also includes an RGB material tint. Water passes Minecraft's biome color to the lit material because VertexLitGeneric ignores vertex colors.

## Thread ownership

Minecraft owns movement, attacks, fluids, projectiles, and mob AI.
Source owns its map, NPC health, props, input, lighting, and final rendering.
Minecraft's integrated server and render thread call their own game APIs.
A transport thread packs snapshots and transfers bytes. It does not call game engine APIs.
Minecraft uses separate input and render transfer threads. HUD packing cannot delay an input mailbox read.
The Source client uses a native worker to copy incoming render packets.
Lua receives the JSON header and an immutable native body handle. It releases the body after upload or mesh construction.
Source mesh construction uses GMod's public mesh API on the client thread.

GMod defaults to 240 FPS. Minecraft retains its saved limit and defaults to Unlimited in a new mirror profile.
While linked, the hidden Minecraft renderer stops at the Source target rate or a lower saved limit.
Render exports follow the Source target rate. HUD captures run at 30 Hz. Open menus use the Source target rate.
Lane 8 bypasses the Source server tick for look and menu input. Movement and session authority remain in lane 0.
Client controls require the active session and teleport sequence. Controls expire after 250 milliseconds without an update.
Menu events retain IDs until Minecraft acknowledges them. Each event includes its cursor position.
Wheel events use Minecraft's normal screen handler. Menu wheel input does not change the hotbar.
Yaw stays continuous across the Source wrap boundary so vanilla hand sway cannot make a full turn.
This file layout is incompatible with the original four-lane bridge.
Install matching Fabric, client DLL, server DLL, and Lua versions together.

## Managed local lifecycle

`garrycraft_enabled` persists the single-player enable switch. The server writes a map request and heartbeat to its DATA directory.
The native server module starts the prepared helper without waiting for Java on the game thread.
The helper owns one Java process through a runtime mutex. Each map has its own world, mailbox, and shutdown control file.
Map changes and Disable request a normal Minecraft save and exit before another process opens a world.
The helper also stops Java when the host exits or its map heartbeat expires.
It retains ownership if saving takes too long. It does not kill a saving process or permit a second writer.
Source closes both mappings when disabled. It restores player state, frame limits, and menu input.
Minecraft restores temporary bridge options before saving its shared options file.
Local launch files and assets remain outside the source repository.
