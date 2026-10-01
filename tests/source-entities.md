# Source entity scenarios

Keep tests at the native map spawn. Remove only entities created by these checks.

1. Walk into a solid physics prop from each side. The Minecraft hull must stop at its mesh.
2. Rotate the prop. Collision must follow the physics object transform.
3. Walk into a solid NPC without a physics mesh. Collision must follow its collision bounds.
4. Walk through a trigger and a nonsolid entity. Neither must become a solid mesh.
5. Let a hostile NPC see and attack the native Source player. A 25-point hit must remove five Minecraft health points.
6. Die and respawn. Both players return to Source spawn with full health and a matching teleport acknowledgement.

Failure modes: local/world transform confusion, missing NPC bounds, trigger collisions, duplicated damage, damage during stale respawn frames, and loss of the native player as an AI target.
