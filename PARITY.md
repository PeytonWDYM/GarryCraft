# SkyCraft feature coverage

Reference: [SkyCraft](https://github.com/chasmlol/SkyCraft), commit `bfcaf178524b92c2cdeb88e4ce0f13ef9ded6f32`.
Minecraft owns gameplay. Source owns its map, NPCs, props, and renderer.
The port uses Minecraft game APIs and keeps both games in separate processes.

| Feature | Current support | Verification or limit |
| --- | --- | --- |
| Player movement on Source geometry | Vertical-first triangle collision, native crouch support, Source footsteps | Fifteen vanilla comparisons include ledges, walls, ceilings, crouch edges, and fast elytra landings. Native ramp descent and jumping tested. More slopes and shore transitions need coverage. |
| Skin, armor, held items, cameras, HUD | Rendered from Minecraft; enchanted armor base layers retained | Both third-person armor views tested. Animated enchantment glint overlays, custom renderers, death poses, and all menu controls need coverage. |
| Placed blocks and collision | Exported Minecraft models and collision shapes | Placement and mining on native ground tested. Source NPCs collide with blocks, but their navmesh does not update. |
| Water and lava | Vanilla grid simulation, native-wall flow blocking, fair animated texture transfers, Source-lit water | Still/flowing animation, native-wall blocking, biome tint, torch lighting, and single-surface export tested. Large floods and curved shorelines need coverage. |
| Transparent blocks | Opaque depth pass and sorted transparent faces | Transparent faces sort across sections. Native Source glass interleaving still needs coverage. |
| Mining effects and particles | Selection shapes, destruction stages, vanilla particle quads | Crack and debris exports checked against actual Source draws. Native map geometry cannot be mined. |
| Torches and block lights | Source world lights, local mesh lights, and self-lit materials | Native floor and wall placement tested. Dark-room lighting holds at both camera distances. Sloped attachment offsets need coverage. |
| Minecraft attacks on Source NPCs and props | Acknowledged attacks through server stand-ins | Repeated sword hits, arrows, and TNT impulses tested. Damage uses configurable conversion scales. |
| Source attacks on Minecraft entities | Player damage bridge and mob bullseyes | Eight damage directions tested. Vanilla armor and damage rules remain active. |
| Source NPC fire and lava damage | Vanilla environmental checks on stand-ins | Repeated native NPC damage tested. Fire can start on native ground. |
| Minecraft mobs and dropped items | Vanilla entity rendering, Source collision, and native destination support | Idle golem, villager, and cow movement tested. Complex brains, flying mobs, and bosses need coverage. |
| Combat between Minecraft mobs and Source NPCs | Minecraft target goals and Source relationships; bounded native sight scans | Zombie approaches a citizen. Both games register damage. A 24-NPC, 15-mob target scan stays within budget. Native NPC behavior varies by class. |
| Projectiles and TNT | Source triangle ray casts and Minecraft entity hits | Arrow and TNT scenarios tested. Tridents, potions, and modded projectiles need individual checks. |
| Block entities and moving blocks | Minecraft renderer export | Chest rendered in the test scene. Pistons and all block entities need gameplay coverage. |
| Pressure plates and tripwires | Stand-ins participate in block effects | Not yet tested. |
| Saved settings and FPS limits | Persistent mirror options, Minecraft Unlimited default, GMod 240 cap | The hidden renderer uses Source's target or a lower saved limit. Stable 240 FPS is not achieved in GMod. |
| Video resolution changes | Native texture reset and render resynchronization | Repeated changes tested in the isolated installation. Cache storage lasts until restart. |
| Local installation and tests | Prepared one-click launcher, automatic map startup, saved enable switch, trace collectors | Windows x64, Minecraft 26.3, isolated single-player only. Separate worlds per map. Each addon combination needs testing. |

Remaining major work: mine and save native map changes, update Source navigation around placed blocks, classify moving prop tops for mob paths,
and complete doors and vehicle handoff. Multiplayer support is outside the current test scope.
Skyrim quests, skills, furniture, and horses have no direct GMod equivalent.

See [test results](tests/RESULTS.md) for measured behavior and saved evidence.
Build success does not prove complete gameplay or perfect physics.

Source mesh draws use up to four nearby point lights. Source world lighting uses the nearest 16 emitters.
This budget leaves room for native lights. It does not provide unlimited simultaneous world lights or shadows.
