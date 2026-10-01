# Native rendering scenarios

Run these checks in the isolated Source installation at map spawn. Save a screenshot and bridge statistics.

1. Change between first person and both third-person views. The Minecraft body follows the interpolated feet without a duplicate Source model.
2. Walk, sprint, crouch, jump, and swim. Minecraft supplies the pose, skin, armor, and held item.
3. Move between sunlight and the dark room. Source lighting changes the body. A Source flashlight also lights it.
4. Open the inventory. The actual Minecraft screen appears and receives input. Close it and regain movement controls.
5. Restart either game. Stale textures, geometry, and UI must disappear until the matching session resumes.
6. Resize the Source window. The overlay retains its aspect ratio and updates its texture dimensions.

Failure modes: dropped texture messages, partial shared-memory frames, old session geometry, incorrect triangle winding, alpha loss, UV distortion, duplicate bodies, and frozen poses.

7. Maximize Minecraft, resize Source, and use a display above 1080p. The HUD must keep drawing at the Source viewport resolution.
8. Press Escape in Source. Minecraft settings must open. Close them and regain mouse control.
9. Hold a Minecraft item while walking and turning. Its Source mesh must remain stable and respond to room lighting.
10. Change between both third-person cameras near a wall. The camera must ignore the hidden Source weapon and stay outside the skin.
11. Start and respawn. No Source physics-gun sprite may appear. A new mirror inventory includes cooked beef.

Additional failures: render capture stops above 1080p, old-size staging buffers appear after resize, camera starts inside a weapon, and transparent hand pixels inherit stale Minecraft world frames.
