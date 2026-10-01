# Source damage checks

Failure cases before implementation:

1. A retransmitted input snapshot applies one Source hit more than once.
2. Source and Minecraft health diverge after an NPC, prop, or explosion hit.
3. Both engines apply drowning or fall damage for the same event.
4. Old damage applies after a respawn or a new bridge session.

At Source spawn, apply one fixed nonlethal Source hit. Record both health values until they settle.
The Source health scale is five health points per Minecraft heart point.
Repeat Source death twice. Both players must return to Source spawn with full health and a new teleport acknowledgement.
Save the trace and Source observation as JSON. Do not move the Minecraft player to a test world.
