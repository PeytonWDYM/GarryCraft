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
The native path checks the tested Windows x64 engine identities before using their dispatch layout.
Unknown client builds use the public mesh path. Unknown material-system builds stop texture creation with a clear error.
An engine update can require a module update. The interface name alone does not certify its dispatch layout.

Video resets retire invalid texture handles and request a fresh render instance.
Retired callbacks retain their small objects, while their RGBA buffers release storage. Late callbacks cannot read retired pixels.
Off-range edits to previously exported sections retain their dirty state. Returning to that section exports its current contents, including air.

## Lighting and shadows

Minecraft exports vanilla occlusion shapes separately from collision shapes. Glass collision does not become an opaque lighting wall.
A native spatial index tests ambient rays and torch visibility. Source mesh lighting uses these results with Source's sampled ambient light.
Mesh lights use the nearest four visible emitters. Source world lights retain a separate limit of 16.

The avatar remains available as a shadow caster in first person. The addon suppresses the native Source player shadow while attached.
Planar shadows use the actual Minecraft mesh silhouette and a traced Source plane or an indexed Minecraft floor surface.
They have a bounded caster budget and use one receiver plane per caster. Silhouettes do not clip across receiver height changes or wrap arbitrary walls.
These shadows do not replace Source's baked map lighting.
Their direction follows the map sun, with a fixed fallback. The planar pass does not test whether a roof blocks that directional light.
Source world point lights do not gain per-pixel shadows from the occlusion index.

## Evidence and limits

Use the owned lab and fresh worlds. The test scripts save paired traces, frame intervals, and rendered pixels outside tracked source.
See [the test record](../tests/RESULTS.md) for measurements and accepted cases.
Build success alone does not prove gameplay, stable 240 FPS, or complete addon compatibility.

Long exploration sessions can retain previously exported Source sections. A residency limit requires separate removal packets and long-session tests.
Block entity candidates still need profiling before another cache is justified.
Moving collision queries visit each nearby body index. One captured state reported 236 Minecraft FPS with 192 props.
Larger movement, fluid, and projectile loads need profiling before another index is added.
