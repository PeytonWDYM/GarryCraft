# Opaque block batching

Use a fresh area in the owned single-player lab. Root owns game input, builds, and fixture cleanup.
Save paired screenshots, Source model reports, mesh reports, and frame timings outside tracked source.

Failure cases before implementation:

- Different face normals merge into a mesh with one normal, changing directional lighting or shadow silhouettes.
- A large merged lighting origin crosses a room boundary and changes Source ambient or native dynamic lighting.
- Merging changes vertex positions, UVs, Minecraft tint bytes, triangle winding, or measured bounds.
- Lit and emissive geometry share a batch and select the wrong material.
- Transparent faces merge and lose their individual sorting, water tint, or manual light samples.
- A block edit removes a stable model before its replacement binds, leaving a color or shadow gap.
- Video reset or disable leaves retired models, native registrations, or invalid mesh references.
- A dense mesh exceeds the existing 65,532-vertex packet limit.

## Compare the same fixture

1. Before changing the build, create two small Minecraft rooms with the same block texture.
   Include floors, roofs, walls, a pillar, and stairs inside the same four-block tiles.
   Save the fixture commands and player pose with the artifacts.
2. Capture the settled world vertex count, `SourceModelReport()`, `garrycraft_bridge.mesh_stats()`,
   and `garrycraft_bridge.shadow_stats()`. Capture screenshots from inside and outside both rooms.
3. Record frame timings with the default queued renderer, first with RTT shadows and then with the existing perspective projector probe.
   Preserve camera, resolution, lights, and geometry for the comparison.
4. Rebuild and restart the owned runtime with opaque batching changes. Reload the same saved world and camera pose.
5. Repeat the reports, screenshots, and timing captures after transfers settle.

The new opaque keys retain texture, emissive state, and four-block spatial tile.
They omit face direction and plane. The settled world vertex count must remain unchanged.
The fixture must use fewer world model entities and native shadow registrations.
Packet splitting can still create multiple meshes when one key exceeds the vertex limit.
Report median and p99 frame time. Counts alone do not prove a performance improvement.

## Verify rendering and replacement

1. Compare directional light on floors, walls, roofs, stairs, and the pillar.
   Each surface must retain its normal, silhouette, UV orientation, and bounds.
2. Add tinted grass, leaves, a torch, and lava. Compare their colors and materials with the previous build.
   Record existing tint limitations separately from changes introduced by batching.
3. Add water and overlapping glass. Move through the same camera path in both builds.
   Transparent face counts, ordering, water tint, and manual lighting must remain unchanged.
4. Load `tests/source-model-rebind.lua`. Place and break blocks repeatedly in one opaque tile.
   Save its per-frame binding artifact. No settled frame may lose a required color mesh or use a retired mesh.
5. Run the existing perspective projector comparison at the same pose.
   Compare actual pixels and silhouettes. Depth counters alone do not prove self-shadowing.
6. Resize and restore the owned window, then disable and re-enable the bridge.
   Save reports showing valid model bindings and no stale native registrations after cleanup.
7. Export a dense section with many exposed same-texture faces.
   Confirm that packet meshes stay within 65,532 vertices and all faces remain visible.

Remove only the owned fixture. Save the final cleanup reports with the comparison artifacts.
