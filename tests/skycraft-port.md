# SkyCraft port checks

Use the upstream cylinder collision and ground-following behavior. Preserve Minecraft's own velocity integration.

1. Record Source input, Minecraft sprint state, Minecraft tick displacement, Source pose, and Source camera displacement.
2. Walk and sprint along the same clear path at Garry's Mod spawn. Sprint must increase distance in both games.
3. Traverse Source ramps in both directions at 15, 30, and 45 degrees. Capture no-penetration, uninterrupted progress, and ground contact.
4. Walk diagonally into a Source wall and along it. Test ceilings and jumps.
5. Compare camera positions with Minecraft's previous/current tick positions on the shared performance-counter clock.
6. Verify Minecraft's experimental-world warning no longer blocks automatic startup.

Save the JSON traces under artifacts. Keep control with the human unless a bounded replay is explicitly running at spawn.
Previous differential results describe the earlier box adapter. They do not verify this cylinder port.

- Enter the map's pond from shore. Minecraft and Source must agree on surface entry and player position.
- Hold jump in water. Swim at the water surface. Sprint-swim underwater and verify forward speed increases.
- Submerge until Minecraft's air counter falls, then surface before drowning. Save the bridge trace.
- Stand on dry ground below the pond's elevation outside its bounds. Water substitution must remain absent.

- Use Source's kill command. Both players must return to the map spawn with full health and zero velocity.
- Repeat death while moving. Old bridge frames must never return the player to the death position.
- Drown in the map pond. Minecraft death must trigger Source respawn once, without a death-screen loop.
- Stop and restart the bridge. A previous session's respawn acknowledgement must never accept a new session's position.
