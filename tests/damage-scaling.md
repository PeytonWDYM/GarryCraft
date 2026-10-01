# Damage scaling

Use a fresh, owned Minecraft world and the isolated Source installation.
Write these failures before the implementation:

1. Sword or projectile damage bypasses the player-to-Source multiplier.
2. Minecraft mob attacks use the player's multiplier against a Source NPC.
3. Minecraft mob attacks on the player ignore the configured multiplier.
4. Player-to-mob, mob-to-mob, and environmental Minecraft damage ignore their multipliers.
5. Source damage uses one conversion for players and another undocumented conversion for mobs.
6. Already converted Source damage receives a second Minecraft multiplier.
7. Armor scales final health loss instead of receiving scaled incoming damage.
8. A stopped bridge changes ordinary Minecraft combat.
9. A repeated bridge event applies a hit twice.

Run `garrycraft_test damage` after the entity scenario.
Temporarily double each damage direction and restore the saved convars after the test.
Use the real integrated-server player, a Minecraft cow, and an owned Source citizen.
Send native hits through Source's damage API and Minecraft hits through Minecraft's damage API.
Record health before and after each hit in both processes.
Require the expected health loss in every direction and one application per event.
Save paired JSON artifacts outside tracked source.
