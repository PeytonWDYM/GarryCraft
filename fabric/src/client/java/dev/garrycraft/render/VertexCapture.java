package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.VertexConsumer;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.client.renderer.texture.OverlayTexture;

/** Captures Minecraft model quads after its pose transforms, following SkyCraft's collector. */
final class VertexCapture implements VertexConsumer {
    record Vertex(float x, float y, float z, float u, float v, int color) {}
    private List<Vertex> destination;
    private boolean pending;
    private float x, y, z, u, v;
    private int color, overlay;

    void begin(List<Vertex> vertices) { flush(); destination = vertices; }
    void flush() {
        if (pending) {
            int tint = color;
            if (((overlay >>> 16) & 0xFFFF) < 8) {
                int green = (int) (((tint >> 8) & 255) * .55f), blue = (int) ((tint & 255) * .55f);
                tint = (tint & 0xFFFF0000) | (green << 8) | blue;
            }
            destination.add(new Vertex(x, y, z, u, v, tint));
        }
        pending = false;
    }
    static List<float[]> triangles(List<Vertex> quads) {
        var result = new ArrayList<float[]>();
        for (int start = 0; start + 4 <= quads.size(); start += 4) {
            for (int index : new int[]{0, 1, 2, 0, 2, 3}) {
                var vertex = quads.get(start + index);
                int color = vertex.color();
                result.add(new float[]{vertex.x(), vertex.y(), vertex.z(), vertex.u(), vertex.v(),
                    (color >> 16) & 255, (color >> 8) & 255, color & 255, color >>> 24});
            }
        }
        return result;
    }
    @Override public VertexConsumer addVertex(float x, float y, float z) {
        flush(); this.x = x; this.y = y; this.z = z; u = v = 0; color = -1;
        overlay = OverlayTexture.NO_OVERLAY; pending = true; return this;
    }
    @Override public VertexConsumer setColor(int r, int g, int b, int a) { color = a << 24 | r << 16 | g << 8 | b; return this; }
    @Override public VertexConsumer setColor(int color) { this.color = color; return this; }
    @Override public VertexConsumer setUv(float u, float v) { this.u = u; this.v = v; return this; }
    @Override public VertexConsumer setUv1(int u, int v) { overlay = u | v << 16; return this; }
    @Override public VertexConsumer setUv2(int u, int v) { return this; }
    @Override public VertexConsumer setUv3(float u, float v) { return this; }
    @Override public VertexConsumer setNormal(float x, float y, float z) { return this; }
    @Override public VertexConsumer setLineWidth(float width) { return this; }
}
