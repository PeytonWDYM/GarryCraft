# GarryCraft architecture

Minecraft owns player movement, game rules, inventory, and entity behavior. Source owns its map, native entities, and final rendering.
Both games remain separate processes. The bridge transfers snapshots through a local memory mapping.

This boundary is useful. A second physics implementation would drift from Minecraft. A shared process would couple both games' lifetimes.
The performance problems came from repeated work and thread contention within this boundary.

| Work | Owner | Thread |
| --- | --- | --- |
| Source entity and physics API reads | Source server | Source game thread |
| Collision shape cache and binary packing | Native server module | Source game thread |
| Collision decoding, transforms, and immutable index construction | Minecraft geometry worker | Dedicated transfer thread |
| Collision snapshot publication | Minecraft client | Minecraft game thread |
| Minecraft simulation and render extraction | Minecraft | Their normal owning threads |
| Render packet encoding and HUD tile comparison | Minecraft render transfer worker | Dedicated transfer thread |
| Source mailbox copies | Native client receiver | Dedicated worker |
| Native mesh buffer writes and texture uploads | Native client module | Source client thread |
| Lighting queries against exported occlusion shapes | Native client module | Source client thread |
| Render hooks, materials, input focus, and engine draws | Source client addon | Source client thread |
| Model entity creation and removal | Source client addon | Source client `Think` hook |

Engine APIs retain their required thread ownership. Moving an engine call to a worker does not make that call safe.
Workers prepare data. The owning thread publishes or uses the result.

## Collision transport

Static collision uses ordered, acknowledged batches. Minecraft publishes one complete map index after import.
Moving collision uses local shape definitions and complete body transforms. Shape definitions repeat until the game thread acknowledges them.
Entity creation IDs distinguish replacements that reuse a Source entity index.

Source caches shapes while their physics object, model, scale, and bounds remain the same.
Removal, range exit, or shape changes retire that cache entry. Each moving packet describes the complete nearby scene.
Minecraft reuses indexes for unchanged body transforms. Its pending static and moving publications retain the newest snapshot.
Each collision query reads one immutable generation, which includes static terrain and moving bodies.

Source water retains its separate grid publication. Arbitrary addon changes to an existing physics shape still need compatibility testing.

## Rendering and resource lifetime

Each render instance has separate transfer state. Reset replaces that state without waiting for HUD packing.
The transfer worker owns encoding, transfer IDs, and pixel caches. The render thread queues texture pixels and scene snapshots.
Animated texture updates retain their arrival order and newest pixels.

GMod creates, draws, and destroys its meshes. The native module fills their vertex and index buffers in one engine lock.
Opaque meshes bind to client Source model entities. Their studio backing model lets Source use its normal model rendering and shadow lifecycle.
`GetRenderMesh` supplies the exported mesh, material, and local matrix. Measured vertex bounds determine each entity's local bounds.
Actual entity positions determine their lighting origin. The avatar follows the current interpolated camera feet position.

Opaque block batches group by texture, emissive state, and four-block spatial tile. They combine face directions and planes within that tile.
The native builder computes normals per triangle and measures bounds across every vertex. Packet meshes retain the 65,532-vertex limit.
Transparent grouping remains unchanged. Source still sorts its individual block faces and applies their manual lighting.

Geometry updates build new meshes, then rebind existing opaque entity slots and native shadow registrations before retiring old meshes.
Unchanged entities keep their shadow handles. Missing or additional slots retire or create entities through `Think`.
Removal first hides the entity, disables its callbacks, unregisters its native mesh, and destroys its shadow.
The public `IMesh:Destroy` path orders underlying mesh deletion after queued draws. Actual entity removal waits for `Think`.
Temporary link loss keeps mesh bindings for recreation. Session changes and video resets replace the render ownership.

Native compatibility checks pin the Windows x64 PE identities in `native/src/sdkcompat.hpp` and the expected render dispatch addresses.
Mesh construction can use GMod's public calls on an unknown client build. Texture creation requires the pinned material-system build.
Custom render-to-texture (RTT) shadows require the pinned client, engine, and studio-renderer builds, with unmodified render interfaces.
An unsupported shadow layout reports an error. There is no planar fallback.
An engine update can require a module update. An interface name alone does not certify its dispatch layout.

Video resets retire invalid texture handles and request a fresh render instance.
Retired callbacks retain their small objects, while their RGBA buffers release storage. Late callbacks cannot read retired pixels.
Off-range edits to previously exported sections retain their dirty state. Returning to that section exports its current contents, including air.

## Lighting and shadows

Minecraft exports vanilla occlusion shapes separately from collision shapes. Glass collision does not become an opaque lighting wall.
A native spatial index tests local torch visibility. These queries do not scale or erase Source ambient lighting.
Opaque model entities use Source's model lighting. Hands and transparent meshes retain manual lighting passes.
Manual lit meshes sample six Source ambient directions, preserve native dynamic lights, and add the nearest four visible exported emitters.
Source world lights retain a separate limit of 16 Minecraft lights. Other entities can consume the engine's remaining light slots.

Manual ambient and local visibility caches refresh every 250 ms, or sooner after movement or a Minecraft lighting revision.
The timed refresh includes native brush movement, which does not change Minecraft's section revision.

The native RTT hook applies only to registered Minecraft proxies. It supplies their actual meshes to Source's studio shadow draw.
Source owns projection, clipping, and shadow-atlas allocation. The addon does not change global engine shadow settings or the game's queue mode.

Queued rendering preserves custom RTT casts onto BSP surfaces. RTT receivers on studio and custom models require an immediate render context.
Source's queued `CStudioRenderContext::AddShadows` rejects the material proxy required by these model receivers. The native guard disables their registration in queued rendering.
`shadow_stats().rttReceiversSupported` reports this RTT model receiver capability. It does not describe projected depth shadows.

`cl_sun.lua` owns one public Source `ProjectedTexture`. Its perspective depth pass uses the actual meshes returned by `GetRenderMesh` under queued rendering.
This path supports Minecraft self-shadowing within the projector's footprint. Owned lab overhead and roof-down comparisons showed mesh shadows and roof blocking.

It follows Source's sun direction and color, with constant attenuation of 1 and linear and quadratic attenuation of 0.
The projector uses a 45-degree field of view and sits 768 Source units toward the sun.
It covers a bounded area near the player.
It updates before opaque draws and keeps Source's normal frustum and visibility culling. It does not use fake receiver planes.

`garrycraft_sun_shadows` controls this one projector. Disable, death, teleport mismatch, session replacement, video reset, or an unavailable Source sun removes it.
The addon leaves global shadow settings and the game's queue mode unchanged.
The [GMod API documentation](https://wiki.facepunch.com/gmod/ProjectedTexture:SetOrthographic) lists broken orthographic shadows for dynamic props and most map brushes.

The first-person avatar keeps RTT and projected depth draws while its color draw stays hidden.
The addon suppresses the native Source player shadow while attached. `garrycraft_source_shadows` controls the owned RTT casters.

Runtime blocks do not rebuild BSP lightmaps, baked ambient samples, or map visibility data.
A new roof cannot remove ambient light already baked into the map. An emissive block cannot rebake that map lighting.
The sun projector adds direct light. A roof can block that contribution without making every room dark.
Ordinary world point lights do not gain per-pixel shadows from the occlusion index. RTT shadows retain Source's projection and atlas limits.

One sun projector consumes one shadow map and an additional depth pass. CPU update timing does not measure its full GPU cost.
One Source entity per opaque batch still increases model and shadow work as more sections remain resident.
Tiles and merged mob batches share lighting origins. Long scenes, distant shadows, addon lights, and complete torch coverage require separate tests.

## Native physics gun

Minecraft registers `garrycraft:physics_gun` as an inventory item in Tools & Utilities. Main-hand selection publishes `physgunEquipped` to Source.
Source selects its installed `weapon_physgun`. Native weapon code owns prop targeting, pickup, rotation, freezing, permissions, beam, and viewmodel.
Minecraft retains movement and inventory authority. It suppresses gameplay attack and use while the item is selected.
Menu clicks still use Minecraft's screen handlers.

GMod's bound Use key controls native rotation. I opens Minecraft inventory, and the mouse wheel controls hold distance while the gun is equipped.
Other items retain E inventory input and mouse wheel hotbar selection. Number keys still select Minecraft hotbar slots.
Deselection, death, teleport reset, session replacement, and bridge shutdown release the held prop through Source weapon cleanup.
Minecraft section collision entities reject pickup and unfreeze operations because their positions must match the exported world.

Source uses the installed weapon's native viewmodel. Third-person rendering references `models/weapons/w_physics.mdl` from the GMod installation.
Minecraft captures the player's skin and sleeve meshes. Source attaches these meshes to the native animated hand and forearm bones.
The repository contains model references and bridge code. It does not redistribute Valve models or textures.

## Detached Minecraft blocks

A fresh primary press requests an individual Minecraft cell. The integrated server validates permission, range, block state, and session before removal.
Minecraft captures its render geometry and collision boxes. Source creates a separate physics body after model readiness and section removal are acknowledged.
The section collision mirror stays fixed. Source's physics gun controls the detached body, and its moving collision returns to Minecraft through the normal geometry transport.

The recovery journal lives under the Minecraft world's `data/garrycraft-physics-blocks` directory.
It stores the original dimension, cell, block state, and block entity data. Writes reach disk before the corresponding world mutation.

| Journal phase | Recovery behavior |
| --- | --- |
| `prepared` | Capture exists before removal commits. Recovery discards this record. |
| `detached` | Removal intent reached disk. Recovery restores an empty original cell and preserves occupied cells as conflicts. |
| `restoring` | Restore intent reached disk. Recovery can finish an interrupted restore when the saved state and block entity data match. |
| `broken` | Mining committed captured loot entity data and UUIDs. Recovery restores missing loot, without restoring the block. |
| `delivered` | Loot delivery reached the world save. Recovery deletes the journal without emitting loot again. |

Detached block mining uses vanilla progress, tool, and loot rules at the moving body's position through a temporary server view.
The view captures loot without replacing an occupied world cell. The journal records `broken` before loot entities enter the world.
The server saves loot and tool wear before recording `delivered` and deleting the journal. Recovery reuses saved entity UUIDs to avoid duplicate delivery.

Recovery saves restored chunks before deleting completed block records. Disable, session replacement, and Minecraft shutdown request recovery. Startup retries retained records.

A replacement block in the original cell prevents restoration, even when it has the same state as the detached block.
The journal remains and the bridge reports the conflict. Clear the cell and restart to retry recovery.
Missing dimensions and journal errors also retain unresolved data. Loose-body transforms do not become relocated Minecraft block cells.

See [the block scenarios](../tests/physics-blocks.md) for cancellation, video reset, containers, fluids, and crash recovery cases.

## Evidence and limits

Use the owned lab and fresh worlds. The test scripts save paired traces, frame intervals, and rendered pixels outside tracked source.
See [the test record](../tests/RESULTS.md) for measurements and accepted cases.
Build success alone does not prove gameplay, stable 240 FPS, or complete addon compatibility.

Long exploration sessions can retain previously exported Source sections. A residency limit requires separate removal packets and long-session tests.
Block entity candidates still need profiling before another cache is justified.
Moving collision queries visit each nearby body index. One captured state reported 236 Minecraft FPS with 192 props.
Larger movement, fluid, and projectile loads need profiling before another index is added.
