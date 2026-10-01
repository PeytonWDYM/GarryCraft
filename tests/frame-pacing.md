# Shared frame target

1. Read the Source window's monitor refresh rate. Both games use this rate as their initial frame ceiling.
2. Run at map spawn. Save each game's measured FPS and the shared target over 30 seconds.
3. Open Minecraft inventory, then close it. The target must not collapse during a temporary screen transition.
4. Force one game below the target for several seconds. Lower the shared target once, then probe upward after recovery.
5. Stop the bridge. Restore Source's previous cap and Minecraft's previous vertical-sync option.

Failure modes: a fixed 60 FPS limit, continuous cap changes, downward feedback from already capped FPS, stale peer statistics, and caps left changed after disconnect.

6. Leave the HUD unchanged while turning and walking. Source must reuse its existing HUD texture. Health, food, inventory, chat, and hover changes must still update.
7. Load a map and keep Source in the background briefly. Startup and focus throttling must not lock both games at a low cap.
