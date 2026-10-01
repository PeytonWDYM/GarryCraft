# Resolution changes

Use the isolated Source installation and an owned Minecraft world.
Keep the bridge active with water, particles, animated sprites, and the Minecraft HUD visible.

Record these failure cases before the fix:

1. Source restores a procedural texture after a mode switch with an invalid format or size.
2. The bridge retains a deleted texture regenerator or a stale GPU buffer.
3. A resized HUD tile reuses a texture name with different dimensions.
4. An old asynchronous readback arrives after the viewport changes.
5. Repeated resolution changes exhaust texture memory.

Change Source from 1280 by 720 to 1920 by 1080, then return to 1280 by 720.
Repeat three times with `tools/Test-Resolution.ps1 -RunRoot <run-directory>`.
Save each viewport, both process IDs, the latest state, and screenshots.
Require both processes to stay alive, a resized HUD, and no new crash or Lua error.
The script validates the isolated executable and sends Source's launcher command message to that window only.
