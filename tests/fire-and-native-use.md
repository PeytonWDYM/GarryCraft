# Fire, fluids, and block effects on Source terrain

Run this scenario only in the marked single-player lab and a fresh Minecraft mirror world.
Use `garrycraft_test terrain` after the bridge has loaded Source geometry.

1. Use a water bucket on bare native ground. Check that the source cell contains water after server delivery.
2. Use flint and steel on bare native ground under an owned, stationary Source citizen.
3. Check that fire survives, the citizen loses health repeatedly, and Source receives burn damage.
4. Remove the owned fire. Use a lava bucket on the same bare ground.
5. Check that lava remains in the selected cell and the citizen loses health repeatedly through burn damage.
6. Place stone on native ground. Mine it in Survival with an empty hand.
7. Record destruction stages and terrain fragments from Minecraft, then record meshes drawn with loaded textures in Source.
8. Capture a Source screenshot during mining. Save paired traces outside tracked source.

Fail if an item needs a Minecraft support block, placement adds an extra grid cell, fire disappears before contact,
damage occurs only once, or Source never draws the crack and terrain-fragment meshes.
Restore the player's mode and inventory. Remove only entities and blocks owned by this scenario.

Repeat in the same two game processes. A new bridge session must resend textures and block sections.
An old acknowledgment must not remove the new session's texture or section packets.
