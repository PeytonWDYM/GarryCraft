# Native physics gun controls

Write this scenario before the bridge routing changes. Use an isolated single-player Sandbox lab and a fresh Minecraft world.
Save Source commands, engine hooks, prop transforms, physics motion flags, selected Minecraft slots, and screenshots outside tracked source.

The reference is the installed GMod `weapon_physgun`, with the bridge disabled. Repeat the same inputs with the Minecraft physics gun selected.
Use identical props, camera position, timing, and the installed physgun convars. Compare native engine hooks and resulting motion.

| Scenario | Required result | Failure to detect |
| --- | --- | --- |
| Select the Minecraft gun, then hold left mouse on an owned loose prop | Source equips `weapon_physgun`. `OnPhysgunPickup` reports that prop. Its native physics body follows the aim. | A custom constraint, Minecraft attack, duplicate damage, or missing pickup |
| Release left mouse | `PhysgunDrop` fires and the prop retains native release velocity | A stuck hold or a bridge force replaces native release |
| Hold left mouse, then press right mouse | `OnPhysgunFreeze` fires and native motion disables | Freeze uses a second physics implementation or Minecraft places a block |
| Press R at the frozen prop | The installed gamemode reload behavior unfreezes its physics body | Reload disappears into Minecraft input |
| Freeze two owned props, then double press R | The installed gamemode unfreezes the player's frozen objects | The bridge changes the game's frozen-object list |
| Hold the Source Use key and move the mouse | The prop rotates through the native physgun. Minecraft inventory stays closed. | Mouse rotates only the view or Use opens inventory |
| Hold Use and Shift, then move the mouse | Native `gm_snapangles` controls rotation | Copied snap constants ignore engine settings |
| Hold Use and press W, then S | Native hold distance changes. Minecraft does not walk. | Clearing analog movement disables engine distance controls |
| Scroll both directions while holding | Native hold distance changes. The Minecraft hotbar does not change. | Wheel selects a different item or reaches a custom distance solver |
| Select another numbered slot during a hold | The prop drops and Source returns to `weapon_garrycraft` | The previous gun remains active after the item changes |
| Press I while equipped, then use mouse and wheel in inventory | Inventory opens. The hold drops. Mouse and wheel reach the Minecraft screen. | A menu click grabs a prop or menu wheel changes hold distance |
| Close inventory and resume play | Native gun routing resumes without stale attack buttons | A held menu click becomes a pickup |
| Delete the held prop, die, respawn, disable, or replace the session | Native hold releases and no bridge-granted Source gun survives Disable | An old entity index or weapon routes inputs into the next session |
| Pause Minecraft state publication for more than 250 ms | The hold drops and gun actions stop until fresh state arrives | A managed 120-second state timeout leaves a prop held |
| Select a frozen ragdoll bone and constrained props | Native pickup permissions, bone selection, constraints, and reload behavior match the reference | The bridge treats each entity as one rigid body |
| Aim at Minecraft section collision | The native gun cannot move `gc_block` collision mirrors | Collision separates from the Minecraft block section |

Do not change native pickup permissions or physgun convars for the bridge pass.
This scenario controls native Source props through the real GMod weapon. Detached Minecraft blocks require a separate feature and scenario.
Passing these cases does not certify every gamemode or Workshop addon.

Copy `tests/physgun-native.lua` into the owned lab's DATA directory. Load it on the server with `RunString(file.Read(..., "DATA"))`.
The fixture does not change player controls, position, aim, weapons, Minecraft inventory, or native physgun settings.

1. Stop the bridge and select the installed Source physics gun.
2. Call `GarryCraft.PhysgunNativeTest.Begin("source")` on the server.
3. Call `Mark("grab")` through the same API before each input step.
4. Use real Windows keyboard and mouse input for the scenario.
5. Call `Snapshot("grab-result")` after the prop settles.
6. Call `Finish()` after the reference pass.
7. Enable the bridge and select the Minecraft physics gun.
8. Return the player to the same camera position and aim with the test driver.
9. Call `Begin("minecraft")` and repeat the same real input sequence.
10. Call `Finish()` after the Minecraft pass.

`Begin` reuses the first pass's prop geometry. An optional second argument accepts that geometry after a fixture reload.
The fixture creates a gravity-disabled crate 160 Source units along the first aim.
It also creates an owned welded crate pair 240 units ahead and to the right.
Freeze those props with the actual gun before the reload checks. The fixture never adds entries to the player's frozen-object list.
`Finish` removes only fixture entities and observer hooks.

Read DATA's `garrycraft-physgun-source.json` and `garrycraft-physgun-minecraft.json` before reporting results.
Both traces contain native events, command fields, transforms, motion flags, engine hold state, and marked snapshots.
The StartCommand observer records the hook state. Hook ordering can place it before or after bridge routing.
Trace truncation appears explicitly if the recording exceeds its bounds. Screenshots must verify the native viewmodel and beam separately.

Before extending the observer or driver, use these bounded comparison cases:

| Comparison | Required evidence | Failure to detect |
| --- | --- | --- |
| Replay the common controls | Both completed passes show the same native pickup, freeze, reload, release, rotation, and distance semantics | One passing Minecraft run replaces the native reference |
| Initial conditions | The Minecraft pass reuses reference fixture geometry, eye, aim, configured Use key, and native convars | Different camera height, bindings, or engine settings hide a mismatch |
| Wheel directions | Compare each observed direction against the native reference | An assumed linear inverse incorrectly rejects native wheel behavior |
| Freeze the target and both welded bodies through real clicks | Native freeze events identify each owned body | Fixture setup inserts fake frozen-object entries |
| Move only unheld fixture bodies off the ray, then double press R | Real reload events unfreeze all three native bodies | An aimed single reload masquerades as unfreeze-all |
| Hold the target, then press another number slot | Minecraft routing switches to the bridge weapon and releases the native hold | Number selection leaves the previous gun active |
| Reselect the gun slot and open inventory with I during a hold | The hold drops and the native weapon cannot act while the menu is open | Menu clicks become native pickups |
| Close inventory after releasing mouse buttons | The native gun resumes and no pickup appears before a new real click | A menu click survives screen closure |
| Scroll both directions with the Minecraft gun idle | The gun and Minecraft slot remain selected. The Source weapon selection HUD stays hidden. | Idle wheel input opens Source's weapon menu |
| Scroll both directions while holding a native prop | The real physgun changes hold distance and keeps the Source selection HUD hidden | A bind filter consumes the native hold-distance path |
| Walk and jump with the gun | Real input moves the player horizontally and vertically. The native viewmodel follows the interpolated Minecraft camera while native sway remains relative to that camera. | Missing jump input or a viewmodel that follows raw Source tick positions against the smooth world |
| Tap Space for 60 ms with clear ground and headroom | Source records the press. Minecraft applies it on its next movement tick, even when Source processes the down commands together. | A 19.53 ms server input state disappears between Minecraft's 50 ms movement ticks |
| Release Space before Minecraft consumes the press | One movement tick receives the press. Later ticks receive the current released state. | Render frames clear the press early or the bridge repeats a released jump |
| Stop the bridge or replace its session with a jump pending | The next session has no pending press from the previous session | An old press causes a jump after attachment |
| Press and release Space, run a physics or parity oracle, then resume on the ground | Released Space stays released. The earlier production press does not cause another jump. | Synthetic oracle input resets the production counter and replays an old press |

`tools/Test-Physgun.ps1` requires the configured Source Use key as a Windows virtual-key value.
For a Source `+use` binding of F, pass `-UseKey 0x46` for both passes. I opens Minecraft inventory while the gun is equipped.
The fixture setup may translate unheld owned bodies. It never changes motion flags or the native frozen-object list after spawning.

For wheel routing, record real `invnext`/`invprev` bind callbacks and native command wheel fields.
Observe `CHudWeaponSelection` decisions during idle and held scroll phases. Save the client trace with screenshots.
Compare held-wheel distance against the Source reference. Idle scrolling in Minecraft must keep one inventory and one equipped gun.
