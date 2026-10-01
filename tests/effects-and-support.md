# TNT, fluids, and torches

Use the isolated single-player installation and a fresh Minecraft mirror world.
Record these failures before implementation:

1. Water loses its biome tint in the Source mesh shader.
2. Lava uses blending and reveals its rear faces.
3. Fluid sides and bottoms overlap the Source floor.
4. A raised fluid surface differs from the height used for swimming and bucket targeting.
5. Particle sprite lookup scans thousands of atlas entries during an explosion.
6. An explosion damages a prop but never applies Minecraft's resolved three-dimensional impulse.
7. Primed TNT intersects a Source triangle and jumps when its ground collision resolves.
8. A torch cannot survive on a native floor or wall because Minecraft sees air behind it.
9. An emissive torch uses Source ambient lighting and appears dark.
10. Small HUD changes upload the entire texture and stall Source's render thread.
11. A native wall crosses a grid cell away from its boundary, so a wall torch loses support.
12. A ray hits the end of a native wall on a grid line and selects the cell beyond the wall.
    Replay the gm_construct wall ray from Minecraft `(18,-2.5,28)` toward `(32,-2.5,28)`.
    Choose the cell on the triangle's side of a tangential grid boundary. The wall torch must survive there.

Extend `garrycraft_test entities` before the fixes. Place a floor torch through normal item use.
Place a wall torch against a native wall using the same packet path.
Spawn primed TNT beside a loose test prop. Record its impulse and displacement.
Record smoke and explosion particle vertices. Save both games' frame times during the fuse, explosion, and recovery.
Check water source and flowing cells with bucket rays and fluid interaction heights.
Retain screenshots of water, lava, torches, and particles outside tracked source.
