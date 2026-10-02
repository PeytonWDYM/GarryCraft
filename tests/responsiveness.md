# Input and menu responsiveness

Use an isolated single-player installation and an owned Minecraft world.
Keep the same viewport, FPS caps, map, and mob count for each comparison.

Record these failures before implementation:

1. Camera input waits for the Source server tick before Minecraft updates the held item.
2. Yaw wraps across 180 degrees and sends the held item through a large rotation.
3. A short menu click disappears between input snapshots.
4. The wheel changes a hotbar slot while a Minecraft screen is open.
5. The video settings list or creative inventory does not receive wheel events.
6. A skipped HUD packet leaves a tile from an older screen.
7. A video reset or new session displays pixels from the previous render instance.
8. The movement tutorial stays visible because host mouse input bypasses its callback.
9. Menu uploads stall Source when most of the screen is visible.
10. NPC target scans issue an unbounded number of sight traces in one server tick.
11. The render camera reuses a movement-command angle instead of Source's current render angle.
12. An empty lighting-test request matches normal play and repeatedly resets the player's look angle.

Run `garrycraft_test responsiveness` at 1920 by 1080.
The Source client publishes a repeating yaw sweep through the direct input lane.
Minecraft records input age and consecutive yaw changes across the wrap boundary.
Open video settings, scroll the options list, and then scroll the creative inventory.
Record each list position before and after the wheel events.
Compare the tutorial step with `NONE` while attached.
Save paired JSON traces and frame reports outside tracked source.
Require matching sessions, completed phases, changed scroll positions, and bounded yaw steps.
Report measured frame intervals separately from the correctness checks.

Run the existing entity and damage scenarios after mob target changes.
Confirm damage in both directions and cleanup after a session change.
Record the maximum sight traces per server tick.

Return to normal play after the lighting test. Require zero test-driven `SetEyeAngles` calls while the lighting request is empty.
Record calls before and after the fix in the owned Source process. Restore the temporary probe after each capture.
Confirm that an active lighting test still fixes its camera and that normal play stops that override afterward.
