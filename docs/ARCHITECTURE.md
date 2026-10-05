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
| Native model lighting and shadow projection | Source engine | Source client thread |
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

Block batches group by texture, emissive state, and four-block spatial tile. Receiving face directions and planes stay separate.
Lighting probes use the outward face normal to sample nearby air, rather than a combined mesh center inside a wall.
Native construction chooses an actual triangle near the face center, including disconnected and concave batches.
The native builder computes normals per triangle and measures bounds across every vertex. Packet meshes retain the 65,532-vertex limit.
Transparent grouping remains unchanged. Source still sorts its individual block faces and applies their manual lighting.

Geometry updates build new meshes, then rebind existing opaque entity slots and native shadow registrations before retiring old meshes.
The transport thread hashes section mesh metadata and vertex bytes with SHA-256, before appending voxel lighting.
Matching geometry retains GPU meshes, model proxies, and shadow registrations. Separate voxel and occluder revisions still invalidate lighting.
Minecraft caches nearby geometry for light-only callbacks and evicts that cache outside the export range.
Native sun rays and lightmap receivers invalidate only when recorded change regions can affect their samples.
The native change history is bounded. Older cache entries receive full invalidation when their history expires.
Unchanged entities keep their shadow handles. Missing or additional slots retire or create entities through `Think`.
Removal first hides the entity, disables its callbacks, unregisters its native mesh, and destroys its shadow.
The public `IMesh:Destroy` path orders underlying mesh deletion after queued draws. Actual entity removal waits for `Think`.
Temporary link loss keeps mesh bindings for recreation. Session changes and video resets replace the render ownership.

Native compatibility checks pin the Windows x64 PE identities in `native/src/sdkcompat.hpp` and the expected render dispatch addresses.
Mesh construction can use GMod's public calls on an unknown client build. Texture creation requires the pinned material-system build.
Custom render-to-texture (RTT) shadows require the pinned client, engine, and studio-renderer builds, with unmodified render interfaces.
Native model ambient and brush lightmap adapters also verify their engine layouts and dispatch before use.
An unsupported shadow layout reports an error. There is no planar fallback.
An engine update can require a module update. An interface name alone does not certify its dispatch layout.

Video resets retire invalid texture handles and request a fresh render instance.
Retired callbacks retain their small objects, while their RGBA buffers release storage. Late callbacks cannot read retired pixels.
Off-range edits to previously exported sections retain their dirty state. Returning to that section exports its current contents, including air.

## Lighting and shadows

Source owns visual lighting and shadows. Minecraft exports geometry, textures, raw material and biome colors, collision shapes, and poses.
The bridge does not export propagated sky or block light, emitters, light attenuation, or shadow occluders.
Minecraft retains its internal light engine for gameplay and vanilla tessellation interfaces.

Opaque meshes use Source model entities and the engine's normal lighting. A shared hidden model submits sorted water faces, hands, and arms through `DrawModel`.
Source applies native map lighting and dynamic lamps. Glow materials retain self-illumination without lighting neighboring surfaces.
A geometry-derived surface origin gives each face batch a valid native model lighting origin.

The minimal native mesh adapter supplies actual silhouettes to Source's RTT caster draw. Source owns shadow direction, projection, clipping, atlas allocation, and receivers.
The bridge does not override ambient cubes, update BSP or displacement lightmaps, trace sun rays, or register custom RTT model receivers.
The first-person avatar casts native shadows while its color draw stays hidden. The linked native player shadow stays suppressed.

Source's baked map lighting remains unchanged when blocks appear. Native RTT shadows do not recalculate room ambient light or map lamp occlusion.
The native engine's material, dynamic light, shadow atlas, and receiver limits still apply. Transparent surfaces retain native material limitations.
Water keeps Minecraft's geometry, flow, textures, and biome tint. It does not acquire the map water shader's reflection and refraction pipeline.

Block edits no longer wait for Minecraft light propagation. Geometry and pose delivery, mesh construction, and engine shadow scheduling still take time.
Unchanged batch and collision hashes retain their Source ownership. No light-only section packets remain.
Tests use separate single-player labs, fresh worlds, saved pixels, and frame traces. Bounded results do not certify every map or stable 240 FPS.

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
The hand hook suppresses Source hands during mesh delivery and resets, including frames when Minecraft arms are not ready yet.
Minecraft publishes its camera-relative first-person bob/hurt matrix. The gun and both arms share that transform.
Source's additional bob and sway are omitted. Bone animation, targeting, beam, pickup, rotation, and freezing remain native.
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
