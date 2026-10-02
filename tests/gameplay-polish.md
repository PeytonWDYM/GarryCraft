# Map gameplay E2E

Use a fresh owned Minecraft world and the separate Source lab. Save paired traces and screenshots outside source.
Write these failure cases before changing physics:

1. Idle iron golems, villagers, and cows reject all destinations because the mirror contains no floor blocks.
2. A solid map prop has no exported collision, or loses collision when the player moves away from its origin.
3. A fast gliding player crosses a thin wall or lands beyond a ledge during one tick.
4. A player walks on native terrain without Source footsteps, or hears footsteps while flying or swimming.
5. Enchanted armor disappears because its combined base-and-glint render type is discarded.
6. Water sprites stop changing after their first upload, or a skipped tick misses the next frame.
7. Fluid crosses a native wall, sinks through a floor, or loses biome tint, torch lighting, or transparency order.
8. Collision export scans all entities or rebuilds unchanged prop meshes on every snapshot.
9. Downhill ramp contact compares the center height with the footprint height and makes the player hop.
10. A jump starts while the prior tick remains grounded. Downhill snapping cancels its upward movement.
11. A map reload reuses an old procedural texture name. HUD tiles and hands draw a pink checkerboard.

Run `garrycraft_test polish` on native flat terrain. Observe idle mobs for at least 600 server ticks.
Compare walking, sprinting, wall contact, and fast descending movement against vanilla on equivalent box geometry.
Include ascending and descending movement across the edge of a low wall, thin walls, and diagonal wall contact.
Exercise SOLID_VPHYSICS and SOLID_OBB props, including frozen and rotating props. Use exact Source collision meshes.
Equip ordinary armor, then enchanted armor. Capture both third-person views and exported armor vertices.
Place still and flowing water. Record uploaded pixel hashes over a full animation cycle and Source material tint.
Run the existing lighting and terrain scenarios after the water changes.
On Downtown, survey the light poles and fountain with Source traces before and after export.
Record frame percentiles and export time on small and large maps. Restore test entities and player equipment afterward.

For the Downtown probes, copy `tests/map-props.lua` to the owned lab's `garrysmod/data/gc-map-props.lua`.
Run `lua_run RunString(file.Read('gc-map-props.lua','DATA'))`, then `garrycraft_test_props`.
Collect the matching traces with `tools/Collect-MapProbes.ps1 -RunRoot <run-directory> -LabPath <owned-lab>`.
The test compares seven real engine rays with imported rays. It checks that the body collider stops movement.
Source's swept box and the triangle collider's cylinder can stop at different fractions on curved or rotated surfaces.
The test removes its temporary frozen, rotated, and OBB props after 20 seconds.

Copy `tests/footsteps.lua` to DATA and load it with `RunString`. Run walk, sprint, crouch, and jump replays on flat native ground.
Stop recording with `garrycraft_test_footsteps_stop`. Save `garrycraft-footsteps.json` beside the Minecraft movement traces.

For export timing, copy `origin/main`'s `sv_geometry.lua` to DATA as `gc-old-geometry.lua`.
Load `tests/export-benchmark.lua` and run `garrycraft_test_export`. It saves 100 warmed samples for each implementation.
Compare triangle counts before comparing times. These query timings do not measure total frame time.

For native ramp descent, load `tests/slope.lua` from the owned lab's DATA directory.
Run `garrycraft_test_slope`. It records 60 Minecraft ticks against Source's actual swept hull contact.
After acceleration, all 50 samples must remain grounded within 0.01 blocks of that contact.
Require at least 128 Source units of downhill travel and 32 units of height loss.
Repeat with `garrycraft_test_slope jump`. The player must leave the ramp and rise more than 0.5 blocks above contact.
The script releases forward input and restores the player pose. It removes its temporary ramp.
Save `garrycraft-slope.json` with the build's other traces.

Load `tests/textures.lua` with `lua_run_cl` in the owned lab. Run `garrycraft_test_textures`.
Save its GPU pixel report. Reload the map with `changelevel`, load the script again, and repeat.
The same logical texture name must draw red in both runs. Capture a normal HUD and hand screenshot after the reload.
