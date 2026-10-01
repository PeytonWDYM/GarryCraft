# Local test record

October 1, 2026. Windows x64 GMod `2026.09.22 (10174)`, `gm_construct`, Minecraft Java 26.3, and Java 25.
Fabric Loader 0.19.5 and Fabric API 0.161.0+26.3.
Both games ran in owned, isolated single-player installations.

`tools/Build.ps1` built both native modules and the Fabric mod successfully.
The test scripts used game APIs and the local bridge. They did not send keyboard or mouse input.
Generated worlds, screenshots, traces, and game assets remain outside tracked source.

## Gameplay

Evidence directory: `%LOCALAPPDATA%\GarryCraft\parity-lab33\artifacts`.
Request: `entities:21.6133892`.
`tools/Collect-Lab.ps1` matched the completed Source and Minecraft requests.

| Check | Result |
| --- | --- |
| Same-input vanilla and Source collision comparison | Passed. 24 samples each. Maximum position error: 0.0001 blocks. |
| Repeated native NPC and prop melee | Seven requests found seven crosshair targets. Source applied 18 attack/environment events during the full scenario. |
| Native ground placement, mining, floor torch, wall torch | Passed. The native wall torch survived with `facing=west`. |
| TNT particles and loose Source prop impulse | 3,270 exported explosion vertices. Peak prop speed: 546.76 Source units/second. Displacement: 647.21 units. |
| Minecraft zombie navigation and native NPC combat | Zombie traveled 7.89 blocks and targeted the citizen. Source registered 240 damage. Zombie health decreased from 100 to 97.462. |
| Fifteen cows, death drops, and pickup | Completed. Frame intervals appear below. |

These collision samples cover a narrow scenario. They do not establish perfect physics on every Source surface.
The full scenario uses a fixed open courtyard position on `gm_construct`.

## Native ground use and mining effects

Request: `terrain:120.8510916`. All nine collector checks passed.
Water and lava buckets, flint and steel, stone placement, and mining worked on bare native ground.
Source drew 36 crack vertices and at least 468 debris vertices during mining.
The Minecraft trace recorded 36 crack vertices and 456 debris vertices.
The peak counts can differ because each game samples a different frame.

The pinned native citizen took six fire damage events: health 10,000 to 9,940.
It then took eight lava damage events: health 9,940 to 9,620.
Repeated fire and lava damage passed.

`tools/Collect-Terrain.ps1` checks matching requests and actual Source crack/debris draws.
The terrain test uses the courtyard position so a nearby building cannot block its item-use rays.

## Damage scales

Request: `damage:176.4571805`. All eight directions passed with the temporary test multiplier.
`tools/Collect-Damage.ps1` compares both games' measured damage with the expected values.
The test restores the archived settings afterward.

| Direction | Expected and measured damage |
| --- | ---: |
| Minecraft mob to player | 6 |
| Minecraft player to mob | 6 |
| Minecraft mob to mob | 6 |
| Environment to Minecraft entity | 6 |
| Minecraft player to native NPC | 140 |
| Minecraft mob to native NPC | 60 |
| Native NPC to Minecraft player | 4 |
| Native NPC to Minecraft mob | 2 |

## Torch lighting

Evidence directory: `%LOCALAPPDATA%\GarryCraft\lighting-lab34\artifacts`.
Request: `lighting:157.3964081`. All six checks passed after the final intensity adjustment.
Screenshots cover `dark`, `floor`, `wall`, `far`, `budget`, and `removed` phases.

The dark room had zero active emitters. The floor torch allocated one world light and one local mesh light.
The wall torch added a second light. Moving the camera from 37.5 to 39.5 blocks preserved both lights at the stone probe.
The measured native floor light stayed unchanged across those two views.
The 42-emitter phase allocated 16 world lights. The stone probe used four nearby local lights.
Removal returned both light counts to zero. Screenshots show the nearby stone illuminate and then return to darkness.

Ambient samples now use each mesh's world position. Local point lights replace the previous camera-dependent lighting.
Torch light origins follow the flame and stay above the native floor.
The renderer caches ambient queries briefly and bounds Source light allocation.

Source supports four local lights per draw through [SetLocalModelLights](https://wiki.facepunch.com/gmod/render.SetLocalModelLights).
Ambient samples subtract dynamic lighting as described in [ComputeLighting](https://wiki.facepunch.com/gmod/render.ComputeLighting).
This avoids counting each torch twice.

## Video resets and options

Six video changes between 1920×1080 and 1280×720 passed in `parity-lab33`.
GMod PID 42240 and Minecraft PID 29356 survived all changes. Minecraft kept publishing new frames.
`resolution-changes.json` records each mode and render instance. Six screenshots show the recovered renderer.

Fresh runs 33 and 34 retained FOV 0.875, `maxFps:260` (Minecraft Unlimited), all particles, and disabled VSync.
The shared options file retained SHA-256 `4309093FAAE54E1830B416D07699DF1E63573C902E5CB16559E4300880CF1441`.
GMod used its 240 FPS cap. Minecraft retained the user's Unlimited setting.

## Frame intervals

The table uses the completed run 33. Each game records full intervals, including stalls.
Minecraft keeps a one-microsecond histogram for every frame. Its saved raw frame list has a separate length limit.
Source keeps a 25,000-frame ring. The collector saved it immediately after completion, before it lost the earlier phases.

| Phase | Source p50 / p99 / max, ms | Minecraft p50 / p99 / max, ms |
| --- | --- | --- |
| Fifteen cows | 4.846 / 11.048 / 20.248 | 0.350 / 1.348 / 16.751 |
| Cow drops | 4.597 / 10.742 / 16.696 | 0.362 / 1.637 / 15.416 |
| After pickup | 4.271 / 7.588 / 10.736 | 0.353 / 1.253 / 7.982 |
| TNT fuse | 4.304 / 9.477 / 13.047 | 0.357 / 1.416 / 11.539 |
| TNT explosion | 4.329 / 10.264 / 17.370 | 0.364 / 1.204 / 3.177 |
| TNT recovery | 4.316 / 8.240 / 11.979 | 0.352 / 1.250 / 2.566 |
| Mob combat | 4.293 / 7.686 / 13.606 | 0.327 / 1.201 / 7.116 |

GMod fails the 4.167 ms p99 budget in each listed phase. Stable 240 FPS remains unfinished.
Minecraft passes that percentile budget, but some maximum intervals still exceed it.
A passing `stable240` field means only that p99 passed. It does not mean every frame passed.

## Repeat the tests

Build and launch with `tools/Play-Lab.ps1 -FreshWorld -Test`. Save the printed run directory.
Collect the full scenario immediately with `tools/Collect-Lab.ps1 -RunRoot <directory>`.
Run `garrycraft_test terrain` and `garrycraft_test damage`, then use their matching collector scripts.
Run `tools/Test-Resolution.ps1 -RunRoot <directory> -Screenshots` for the six video changes.
Use a separate fresh `gm_construct` world for `garrycraft_test lighting`, then run `tools/Collect-Lighting.ps1`.
The lighting scenario owns its fixed fixture cells. Do not run it in an existing world.

See [feature coverage](../PARITY.md) for untested gameplay and remaining work.
