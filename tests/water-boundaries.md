# Source water boundaries

Run in gm_construct. Sample native water columns without moving the player.

1. Check every wet column in the pond at four-unit spacing. Its exported surface must match Source's water boundary.
2. Repeat the same columns with the query position above and below the pond. Surface height must remain unchanged.
3. Swim through the reported boundary while Source records position, PointContents, WaterLevel, and the Minecraft water state.
4. Leave the pond. No column outside the brush may report water.

Failure modes: a downward trace starts inside water, vertical cache misses alter the result, and a grid edge drops a wet column.
