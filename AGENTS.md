# GarryCraft

Build a local Minecraft Java and 64-bit Garry's Mod bridge. Minecraft owns player physics and game rules.
Source owns the host world and renderer. Keep both games in separate processes.

Read `README.md`, `MODLOG.md`, and `protocol/README.md` first.
Keep player installation steps in `README.md` and `docs/INSTALL.md`. Keep agent instructions in this file.
Use `tools/Build.ps1` to build the native module and Fabric mod.
On Linux use `tools/Build.sh`. Use `tools/Package-Release.ps1` for release archives
(`tools/Package-Release.sh` on Linux, with `--gmod-path` to pin Linux engine builds).
Do not package a developer runtime.
Use its generated release notes for every release. Keep the five installation steps and omit change logs from release descriptions.
Write installer end-to-end scenarios before changing installation behavior.
Test the extracted ZIP with Windows PowerShell 5.1 and a separate, marked game installation.
For clean-install tests, record the exact folders and confirm the runtime and GarryCraft game files are absent before setup.
Disable external download caches for first-download tests. Save deletion records for requested wipes and label clean and repeat installs separately.
Keep release payload versions matched across Fabric, Lua, and both native modules.
Preserve normal Minecraft installations, existing worlds, preferences, and unrelated addons.
Read installation transcripts and runtime traces before reporting a release as verified.
Run physics comparisons through `garrycraft_test` in a separate local game installation.
Read the generated traces before you report a result.

Keep changes small and split code by responsibility.
Use game APIs before binary hooks. Do not copy movement constants into a second physics implementation.
Write end-to-end scenarios before you implement a physics change.
Compare the same input sequence against vanilla Minecraft on equivalent geometry.

Do not commit game files, extracted textures, Minecraft jars, account data, or decompiled source.
Keep local test worlds, screenshots, and logs outside tracked source.
Test only in single-player. Do not change a user's existing worlds or another project's game installation.
Document limitations. Do not call physics perfect from a few passing cases.
