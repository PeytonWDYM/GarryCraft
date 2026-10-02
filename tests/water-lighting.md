# Water lighting

Use the owned `gm_construct` lighting fixture and a fresh Minecraft mirror world.
Place one water source in a stone basin beside the existing lighting probe.

Record these failures before implementation:

1. Water uses an unlit material while the nearby stone uses Source lighting.
2. Water stays bright in the dark room without a torch.
3. A torch changes stone lighting but does not change water lighting.
4. Water loses transparency when it receives Source lighting.
5. Lava loses its emitted light because the water fix also changes lava.
6. Minecraft's coincident front and back fluid faces both draw with opposite lighting normals, causing tint changes and flicker as the camera moves.
7. Changing the water winding changes other block lighting.
8. Source's lit shader ignores vertex colors, so blue biome water becomes gray.

Run `garrycraft_test lighting` and collect matching traces with `tools/Collect-Lighting.ps1`.
Require visible water faces near the water probe and no unlit faces there.
Record ambient samples and local light counts for the water probe.
Require exactly one two-sided top surface in the isolated basin. Remove Minecraft's reverse copy during export.
Read the two-sided flag from Source's [material flags](https://wiki.facepunch.com/gmod/Material_Flags).
Save dark, torch, distant, and removed screenshots outside tracked source.
Inspect the screenshots before reporting a result.
Compare the exported biome tint with the lit material tint. Require blue water in the torch screenshot.
