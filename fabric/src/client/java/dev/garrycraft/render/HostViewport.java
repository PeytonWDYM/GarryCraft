package dev.garrycraft.render;

import dev.garrycraft.GarryCraftClient;
import net.minecraft.client.Minecraft;

/** Render the HUD at the host's resolution without resizing the physical Minecraft window. */
public final class HostViewport {
    private static boolean active;
    private HostViewport() {}

    public static void update(Minecraft mc) {
        boolean linked = GarryCraftClient.linked();
        if (!linked && !active) return;
        var window = mc.getWindow();
        var physical = window.queryFramebufferSize();
        int width = linked ? GarryCraftClient.viewportWidth() : physical.width();
        int height = linked ? GarryCraftClient.viewportHeight() : physical.height();
        var target = mc.gameRenderer.mainRenderTarget();
        boolean changed = window.getWidth() != width || window.getHeight() != height;
        window.setWidth(width);
        window.setHeight(height);
        if (target.width != width || target.height != height) mc.gameRenderer.resize(width, height);
        if (changed) mc.resizeGui();
        active = linked;
    }
}
