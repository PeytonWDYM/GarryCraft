# SkyCraft parity scenarios

Run `garrycraft_test entities` in the isolated single-player installation.
Use the native grass test area on gm_construct at Source `(576,-896,-144)`.
This keeps the citizen, prop, and zombie away from the building walls.
On other maps, use an open native floor near the player. Create and remove only entities owned by this test.
Save a JSON trace and a screenshot outside tracked source.

Before implementation, these are the failure cases:

1. An NPC has a physics object, but its mesh does not cover its walking bounds.
2. A rotated prop receives collision in local coordinates instead of world coordinates.
3. Minecraft cannot target a Source entity because it has no server-side stand-in.
4. Duplicate snapshots apply the same hit twice.
5. An entity index is reused, and an old hit damages the replacement.
6. An entity disappears, but its stand-in remains hittable.
7. Source damage bypasses Minecraft attack cooldown, armor, shields, or enchantments.
8. Projectiles pass through Source walls before they reach a target.
9. Minecraft particle coordinates remain relative to its camera instead of the Source world.
10. Particle alpha is lost, or particles draw through walls.
11. A texture, block section, or collision update is lost during a mailbox overwrite.
12. A new session draws meshes or applies hits from the previous session.

The repeatable scenario must compare walking into an NPC with walking into an equivalent vanilla Minecraft obstacle.
Then use Minecraft's attack path to hit the NPC and a physics prop.
Record Source health before and after, the acknowledged hit IDs, and Minecraft particle geometry counts.
Repeat with a stopped bridge and a removed target. Neither case may retain a hittable stand-in.

World checks must cover a stone block, glass, a slab, a chest, a torch, water, and lava.
Break each placed block. Its model, light, and Source collision must disappear.
NPCs must stop at the placed stone block and activate a pressure plate.
Save the exported section counts, collision counts, light counts, and particle vertex counts.
