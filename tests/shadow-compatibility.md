# Shadow compatibility scenarios

Use a separate `.garrycraft-lab` game copy. Retain the player's enabled local and Workshop addons.
Keep test worlds and reports outside tracked source. Do not change the player's game or worlds.
Keep the bridge disabled during the source-only shadow probes.

Build the test hook module explicitly with `cmake --build native/build --config Release --target garrycraft_shadow_test`.
Copy `native/build/Release/gmcl_garrycraft_shadow_test_win64.dll` into the lab's `garrysmod/lua/bin` folder.
Load single-player `gm_construct`. Run `tools/Test-ShadowCompatibility.ps1` with `-LabPath`, `-GamePid`, and a new `-RunRoot`.
The test module remains outside the release payload. Remove it before the packaged player test.

1. Reproduce the reported fresh-install error with the packaged native module and copied game settings.
   Save the console log, engine identifiers, enabled addons, and shadow adapter report.
2. Start the corrected module with the same addons. Run `source-shadow-path.lua` on `gm_construct`.
   Require custom shadow draws, a visible shadow pixel change, and zero invalid mesh or thread counts.
3. Disable and enable the bridge in the same process. Repeat the probe and require a successful hook installation.
   Verify that hook restoration retains any callback owned by another module.
4. Simulate a rejected renderer in a separate native test module before GarryCraft loads.
   Require one specific diagnostic. Require visible meshes and active gameplay without repeated Lua errors.
   Do not pass guessed addresses or unsupported object layouts to Source.
5. Extract the final ZIP into a folder with spaces. Use Windows PowerShell 5.1 through `Install.cmd` and `Play.cmd`.
   Record clean runtime and game payload paths before setup. Save the install transcript and live rendering report.
   Run `tools/Test-PlayerAddons.ps1 -RequireAutoStart` with the installed player and extracted package paths.
   The test must link without an Enable command and record actual mesh and shadow draws.

Failure cases include a missing interface, a changed function address, an existing renderer hook,
an unsupported object layout, stale hooks after bridge shutdown, and a scene update aborted by optional shadows.
