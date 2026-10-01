# Placed block lighting

Place stone and TNT on native outdoor ground. Keep the camera still until the section arrives.
Capture the first visible block, then move to each side and capture it again.
Repeat indoors, near a torch, and after a bridge reconnect.
Repeat at the gm_construct doorway with a held stone block and a wall torch.
Neither the placed block nor the held block may turn black when the camera rotates.

A newly placed block must use Source lighting immediately. Its color must not depend on the previous model drawn by GMod.
Set all six ambient directions explicitly. Cache Source light queries briefly instead of drawing an invisible model each pass.
Torch and lava meshes remain self-lit. Ordinary blocks retain Minecraft tint and ambient occlusion.
Lighting updates must invalidate exported sections, including updates through the four-argument section-dirty API.
Save screenshots and block/render reports outside tracked source.

Place a floor torch and a wall torch in a dark Source room, beside stone blocks.
Capture the same view before placement, after placement, after removal, and after a video reset.
The flame's light origin must stay outside native walls and floors.
Nearby stone must receive point lighting at its world position, even when the camera is in the dark.
Add more than 32 emitters. Keep the nearest lights stable within Source's fixed light budget.
Record exported lights, allocated lights, and the lights used by Minecraft mesh draws.

Run `garrycraft_test lighting` in an owned, fresh `gm_construct` world.
The scenario holds six views: dark, floor torch, both torches, farther camera, 42 emitters, and removed emitters.
Capture each named phase, then collect paired traces with `tools/Collect-Lighting.ps1 -RunRoot <run-directory>`.
The collector checks model lighting, native floor lighting, camera distance, the 16-light budget, and removal.
