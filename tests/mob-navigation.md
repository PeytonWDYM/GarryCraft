# Mob navigation and combat

Use an owned single-player world and native Source terrain.

Record these failures before implementation:

1. Minecraft's pathfinder sees air below a mob on a Source floor.
2. A path crosses a Source wall or sends a mob through a slope.
3. A Minecraft monster cannot select a friendly Source NPC as its target.
4. A Source NPC cannot select or damage a Minecraft mob.
5. A target mirror feeds back into Source collision or creates another Minecraft stand-in.
6. A repeated packet applies Source damage twice.
7. A dead mob retains a Source target, or a new session receives old damage.
8. Target scans consume every render frame instead of the server tick.
9. The navigator adjusts a target through empty mirror-world blocks and chooses a distant goal instead of the Source floor.

Extend the entity scenario with a Minecraft zombie and an armed friendly Source citizen.
Start them several blocks apart on native terrain. Record the zombie's path and displacement.
Record damage in both games and the acknowledged Source hit IDs.
Require movement, a selected target, and health changes in both directions.
Remove the mob and stop the bridge. Check that its invisible Source target disappears.
Retain the JSON traces outside tracked source.
