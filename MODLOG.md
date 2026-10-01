# GarryCraft mod log

## October 1, 2026

GarryCraft keeps Minecraft Java 26.3 and Windows x64 Garry's Mod in separate processes.
The Fabric mod owns player movement, game rules, fluids, projectiles, and mob AI.
Source supplies collision geometry, native NPCs, props, input, lighting, and final rendering.

The port extends the existing SkyCraft triangle collider to server entities and exact surface ray casts.
An immutable triangle index bounds nearby queries. Source navigation supplies floor heights to Minecraft ground paths.
Vanilla movement constants stay in Minecraft.

Minecraft exports placed sections, block collision shapes, animated fluid textures, entities, items, particles, and mining effects.
Source builds meshes through its public Lua mesh API. Transparent block faces sort across sections.
Torches and lava use self-lit materials. Source model lighting must be prepared before ordinary mesh draws.
Each mesh samples ambient light at its world position. Torch point lights illuminate meshes independently of camera distance.
Floor and wall torches export their flame positions. Source reserves 16 world lights and supplies four local lights per mesh draw.
Minecraft lighting updates invalidate exported sections through the complete section-dirty API.

Source entity stand-ins resolve Minecraft attacks and environmental effects.
Acknowledgments retain hits until Source applies them. Creation IDs prevent recycled entity indices from receiving stale hits.
Damage controls cover player, mob, native NPC, and environmental damage directions.
Minecraft mobs have invisible Source bullseyes for native target selection and return fire.

Transport work runs outside game threads. Game API calls remain on their owning threads.
Cached item geometry, bounded section work, asynchronous HUD readback, and changed texture uploads reduce repeated work.
Both games record frame times. The current Source scenario still fails the stable 240 FPS budget.

Video resets retire invalid texture handles and request fresh render state.
Every attachment has a fresh render instance. Texture acknowledgments include that instance to reject late replies.
Minecraft options persist outside fresh world directories. New profiles default to Unlimited FPS.
GMod uses a 240 FPS cap while the bridge runs.

Tests use `%LOCALAPPDATA%\GarryCraft\gmod-lab`, which has the required `.garrycraft-lab` marker.
Minecraft test worlds and all generated evidence stay under owned run directories outside tracked source.
The installer refuses to replace modules in a running test installation.
The user's Steam installation and existing Minecraft worlds remain outside these tests.

The source repository is [PeytonWDYM/GarryCraft](https://github.com/PeytonWDYM/GarryCraft).
SkyCraft source attribution and its MIT license appear in [third-party notices](THIRD_PARTY_NOTICES.md).
[Universal Modder](https://github.com/rehan-remade/universal-modder) supplies game research and screenshot tools.
See [feature coverage](PARITY.md) and [test results](tests/RESULTS.md) for current limits.
