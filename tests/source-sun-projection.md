# Perspective Source sunlight probe

Run this scenario only in the owned single-player lab. Root owns game input and fixture cleanup.
Use a fresh fixture area. The commands replace blocks inside `34..40, 4..10, -3..3`.

Failure cases: a hidden Source brush blocks the projector, custom meshes miss the depth pass,
the backing model casts instead of Minecraft geometry, one mesh fails to shadow itself,
the roof leaks direct light, first-person avatar color appears, viewmodel lighting diverges,
camera or HDR changes obscure the comparison, or cleanup leaves the projector active.

Also check disable, disconnect, video reset, session change, and missing Source sun data.
Check the roof and pillar while the camera moves within the projector footprint.
Keep the projector inside useful Source map PVS coverage. An off-map projector can lose model light association.
Check that transparent water receives its additive flashlight pass and that first-person avatar color stays hidden.
Compare frame cost with the single sun projector enabled and disabled.
Use the engine's shadow-map resolution. The public projector API has no separate resolution control.

## Build the real Minecraft fixture

Use Minecraft chat in the lab. Keep the player in first person.

```text
/fill 34 4 -3 40 10 3 minecraft:air
/fill 34 4 -3 40 4 3 minecraft:dirt
/fill 34 5 -3 34 6 3 minecraft:dirt
/fill 40 5 -3 40 6 3 minecraft:dirt
/fill 35 5 -3 39 6 -3 minecraft:dirt
/setblock 35 5 1 minecraft:dirt
/setblock 35 6 1 minecraft:dirt
/tp @s 37.5 5 0.5
/item replace entity @s weapon.offhand with minecraft:totem_of_undying
```

The floor top is 144 Source units when GridHeight is -16. The Source roof beneath it is at 64 units.
The walls and central pillar are two blocks high. Exported vertical faces can share one IMesh across both heights.
Clear through Y10 to remove old lab roofs above the new roof at Y7.
Wait until mesh and texture transfers settle. Save the original offhand item before replacing it.

## Capture open and roofed rooms

Set `garrycraft_sun_shadows 0` before the probe so the production projector does not change the comparison.
Load `source-sun-projection.lua` on the Source client. Start the open-room capture:

```lua
print(GarryCraft.SourceSunProjectionTest.Begin("open"))
```

Each run takes about five seconds. It captures the unchanged ambient scene, unshadowed projector,
shadowed projector, and scene after projector removal. It restores the existing camera hook and entity methods.
It changes no global shadow, ambient, HDR, or rendering settings.

Add the real Minecraft roof after the first run completes:

```text
/fill 34 7 -3 40 7 3 minecraft:dirt
```

Wait for transfers. Capture the same view again:

```lua
print(GarryCraft.SourceSunProjectionTest.Begin("roofed"))
```

The default camera is `ToSource(37.5, 6.62, .5)` with Source angles `(12.060, -174.509, 0)`.
Optional second-argument fields are `view`, `angles`, `target`, `distance`, `fov`, `brightness`, `settle`, and `attenuation`.
The default projector uses Source sun direction and sun color, perspective FOV 45, distance 768, and brightness 0.75.
Its white texture avoids flashlight beam artwork. One projector covers this small room.
Omit `attenuation` to preserve Source's default profile. Use `attenuation="constant"` for constant 1, linear 0, and quadratic 0.
The JSON records all three attenuation values returned by the projector.
Compare the profiles at the same pose before attributing weak shadows to the material or depth pass.

```lua
print(GarryCraft.SourceSunProjectionTest.Begin("open-constant", {attenuation="constant"}))
```

## Read the artifacts

The returned path identifies the DATA JSON. Four PNGs share its prefix.
The JSON contains a 96-by-54 pixel grid, camera pose, world sequence, native reports, and draw dispatch counts.
The observer wraps each proxy's public `RenderOverride` callback and calls its original draw callback unchanged.
It restores each previous callback, including an absent callback, after the probe.
Callback counts include suppressed draws. Draw counts use the production counter delta across the original callback.
That counter advances immediately before `DrawModel`, after the production visibility guards.
Raw `STUDIO_` flags identify each observed pass. These counts do not prove that the GPU writes a shadow map.
It reports pixel differences separately for world, left-hand, and right-hand screen regions.
These regions can contain background pixels. Inspect the totem and hand silhouettes in the PNGs.

Check these results:

1. All four captures have the same pose and resolution.
2. The native brush trace does not block the projector before it reaches the fixture.
3. The shadowed phase draws custom world meshes in the projected depth pass.
4. A two-height world batch has positive `tallWorldDepth` calls.
5. The first-person avatar has depth draws and zero color draws after its production visibility guards.
6. Open-room screenshots show an identifiable pillar or wall shadow inside the room.
7. The roof blocks the added direct light on visible interior surfaces.
8. Hand and totem images retain Source ambient lighting and show no black ambient cutoff.
9. The final capture restores the scene after the owned projector is removed.
10. Place water and glass beside the fixture. Their transparent surfaces must receive the same projected light.
    Lava and particles must retain their emitted colors. The light must not duplicate their ordinary draw.

Draw counters alone do not establish self-shadow support. A darker frame alone does not identify the responsible caster.
Inspect paired PNGs for the actual silhouette and roof boundary. Source tone mapping can change other pixels.

## Cleanup and production limits

Remove this fixture only after the captures finish:

```text
/fill 34 4 -3 40 10 3 minecraft:air
```

Restore the saved offhand item and player position. Root owns these Minecraft state changes.
Restore the previous `garrycraft_sun_shadows` value.

Production uses one bounded perspective sun projector around the player.
It keeps Source ambient intact. Projector shadows block their own added direct light.
They cannot subtract sunlight already stored in Source's baked ambient or lightmaps.
This adds direct illumination and consumes a shadow map. It is not a replacement for baked map lighting.
Read `RESULTS.md` for the paired image evidence and measured frame intervals.

The public [SunInfo structure](https://wiki.facepunch.com/gmod/Structures/SunInfo) provides direction and sun color.
The public [RenderOverride callback](https://wiki.facepunch.com/gmod/ENTITY:RenderOverride) supports this temporary observer.
The public [linear attenuation API](https://wiki.facepunch.com/gmod/ProjectedTexture:SetLinearAttenuation) documents the default value of 100.
Use perspective projection. The public [orthographic API](https://wiki.facepunch.com/gmod/ProjectedTexture:SetOrthographic)
documents broken shadows for dynamic models and many map brushes.
