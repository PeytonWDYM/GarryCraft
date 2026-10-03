# Native aim origin

Use an owned single-player lab. Load `source-aim-origin.lua` in both Source realms.
The observer reads real eye and shooting positions. It does not change input or movement.

1. Select Minecraft's Physics Gun. Call `GarryCraft.AimOriginTest.Begin("standing")` in both realms.
2. Save lane 1 and both DATA traces. Applied eye height must match Minecraft's published height.
3. Hold sneak through Windows keyboard input. Repeat with the label `sneaking` after the eye transition.
4. Release sneak. Verify pickup on a block face and a native prop at the same visible crosshair.
5. Disable the bridge. Verify that Source restores the previous desired, crouched, and applied eye offsets.

Failure cases: desired eye height changes while applied height stays at Source's default,
client and server aiming from different heights, and stale Minecraft offsets after Disable.
