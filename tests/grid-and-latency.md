# Grid, combat, and update timing

Use a fresh mirror world and the isolated Source installation.

Before implementation, check these failure cases:

1. Source spawn stands on a floor between Minecraft voxel levels. Placed blocks float or sink by half a block.
2. A grid offset changes when the player starts the bridge from a different position.
3. The camera and collision use different grid offsets.
4. A fluid update delays a block that the player just placed or broke.
5. A stationary NPC receives one hit, but later attacks fail until its stand-in updates.
6. A fluid query scans the full map mesh for every cell.
7. A window focus change clears Minecraft's key mappings while the bridge still holds the movement key.
8. A comparison passes because neither replay moves. Require forward input and displacement in both traces.
9. Minecraft waits for its canceled world render pass before it starts player ticks.
10. Water loses its biome tint or draws below a fractional Source floor.
11. An unchanged chest or held item rebuilds its Source meshes for every particle snapshot.
12. A section rebuild consumes the full render frame when fluid changes several cells.

Record the water vertex colors and terrain clearance. Compare both against Minecraft's fluid renderer.
Record frame times during fluid spread and block breaking. Include block particles and mining cracks in the screenshot.

Place and break a block on the native spawn floor. Its bottom must meet the floor.
Record the grid offset and section acknowledgement times.
Attack the same stationary NPC five times through the crosshair, with Minecraft's normal cooldown between attacks.
Move the NPC without removing it. Repeat the attacks and retain its creation ID.
Record Source and Minecraft frame rates before and after fluid placement.
