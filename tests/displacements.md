# Native terrain checks

The current world physics mesh omits curved grass displacement surfaces.

Failure cases to check before changing the export:

1. A displacement is absent, mirrored, rotated, or tessellated with the wrong cell diagonal.
2. A removed triangle or non-solid surface blocks the player.
3. A bad BSP offset reads unrelated data or escapes the lump.
4. A seam lets the player fall through while walking diagonally uphill.

Decode the installed gm_construct map. Compare exported triangle heights with Source engine traces across its native grass slopes.
Save the coordinates, expected height, exported height, and maximum error as JSON.
Walk uphill and downhill from Source spawn. Do not create ramps or teleport the Minecraft player for this check.
