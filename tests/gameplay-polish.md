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
12. Stop the bridge during polish setup, replace its session, or disconnect transport. Each path must remove mobs and blocks and restore armor.
13. Restart polish while cleanup is queued. The old run must finish cleanup before the new run replaces its state.
14. Cancel the first vanilla physics pass before preparation finishes. Its saved armor must still be captured and restored.
15. Click a creative inventory tab, then type in search. Source must retain text-entry focus after each click.
16. Search for `stone` and edit it with Backspace. Vanilla must filter items after each change.

Run `garrycraft_test responsiveness` for the creative search cases. The paired traces must contain the query and matching items.
This scripted check covers Source text callbacks and focus after mouse release. Also check tab clicks and physical typing during manual play.

Load `tests/cancel-polish.lua` from the owned lab's DATA directory.
Run `garrycraft_test_cancel_polish`, then repeat with `replace` and `restart`.
Save each incomplete Minecraft report before the next run overwrites it. Its cleanup fields must pass with zero remaining mobs.
The restart must subsequently complete the ordinary polish scenario.

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
