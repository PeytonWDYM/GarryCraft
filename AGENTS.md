# GarryCraft

Build a local Minecraft Java and 64-bit Garry's Mod bridge. Minecraft owns player physics and game rules.
Source owns the host world and renderer. Keep both games in separate processes.

Read `README.md`, `MODLOG.md`, and `protocol/README.md` first.
Use `tools/Build.ps1` to build the native module and Fabric mod.
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
