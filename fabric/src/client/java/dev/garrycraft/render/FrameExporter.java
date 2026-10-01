package dev.garrycraft.render;

import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.renderpearl.api.buffers.GpuBuffer;
import net.minecraft.client.Minecraft;
import java.util.Arrays;

/** SkyCraft's asynchronous triple readback, published as raw RGBA for the native Source texture uploader. */
public final class FrameExporter {
    private static final Staging[] STAGING = {new Staging(), new Staging(), new Staging()};
    private static long frame;
    private static byte[] previous;
    private static int previousWidth, previousHeight;
    private static final int FREE = 0, PENDING = 1, READY = 2;
    private static final class Staging {
        GpuBuffer buffer;
        int width, height;
        long frame;
        volatile int state;
    }
    private FrameExporter() {}
    public static void reset() { previous = null; }

    public static void capture(Minecraft mc) {
        Staging newest = null;
        for (var slot : STAGING) if (slot.state == READY && (newest == null || slot.frame > newest.frame)) newest = slot;
        if (newest != null) {
            try (var mapped = newest.buffer.map(true, false)) {
                byte[] rgba = new byte[newest.width * newest.height * 4];
                mapped.data().get(rgba);
                if (newest.width != previousWidth || newest.height != previousHeight || !Arrays.equals(previous, rgba)) {
                    RenderTransport.overlay(newest.width, newest.height, newest.frame, rgba);
                    previous = rgba;
                    previousWidth = newest.width;
                    previousHeight = newest.height;
                }
            }
            for (var slot : STAGING) if (slot.state == READY && slot.frame <= newest.frame) slot.state = FREE;
        }
        var target = mc.gameRenderer.mainRenderTarget();
        var color = target.getColorTexture();
        if (color == null || (long) target.width * target.height * 4 > 64 * 1024 * 1024 - 4096) return;
        Staging free = null;
        for (var slot : STAGING) if (slot.state == FREE) { free = slot; break; }
        if (free == null) return;
        if (free.buffer == null || free.width != target.width || free.height != target.height) {
            if (free.buffer != null) free.buffer.close();
            free.width = target.width;
            free.height = target.height;
            free.buffer = RenderSystem.getDevice().createBuffer(() -> "GarryCraft overlay readback", 9, (long) free.width * free.height * 4);
        }
        final Staging captured = free;
        captured.state = PENDING;
        captured.frame = ++frame;
        RenderSystem.getDevice().createCommandEncoder().copyTextureToBuffer(color, captured.buffer, 0, () -> captured.state = READY, 0);
    }
}
