package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.QuadInstance;
import com.mojang.blaze3d.vertex.VertexConsumer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import net.minecraft.client.model.geom.builders.UVPair;
import net.minecraft.client.renderer.block.BlockQuadOutput;
import net.minecraft.client.renderer.block.FluidRenderer;
import net.minecraft.client.renderer.chunk.ChunkSectionLayer;
import net.minecraft.client.renderer.texture.TextureAtlas;
import net.minecraft.client.resources.model.geometry.BakedQuad;

/** Minecraft supplies block models, tint, smooth lighting, and fluid surfaces. */
final class BlockMeshBuilder implements BlockQuadOutput, FluidRenderer.Output {
    private record Key(int texture, boolean translucent, boolean unlit) {}
    private final LinkedHashMap<Key, List<VertexCapture.Vertex>> batches = new LinkedHashMap<>();
    private final List<VertexCapture.Vertex> waterVertices = new ArrayList<>(), lavaVertices = new ArrayList<>();
    private final VertexCapture fluids = new VertexCapture() {
        @Override public VertexConsumer addVertex(float x, float y, float z) {
            float height = Math.clamp(y - fluidBaseY, 0, 1);
            y = fluidBaseY + fluidGround + height * (1 - fluidGround);
            return super.addVertex(x, y, z);
        }
    };
    private final float ox, oy, oz;
    private float fluidGround;
    private int fluidBaseY;
    private boolean emissive;
    BlockMeshBuilder(int x, int y, int z) { ox = x; oy = y; oz = z; }
    void emissive(boolean value) { emissive = value; }

    @Override public void put(float x, float y, float z, BakedQuad quad, QuadInstance instance) {
        var sprite = quad.materialInfo().sprite();
        var key = new Key(Textures.sprite(sprite), quad.materialInfo().layer().translucent(), emissive);
        var vertices = batches.computeIfAbsent(key, ignored -> new ArrayList<>());
        for (int i = 0; i < 4; i++) {
            var pos = quad.position(i);
            long uv = quad.packedUV(i);
            vertices.add(new VertexCapture.Vertex(ox + x + pos.x(), oy + y + pos.y(), oz + z + pos.z(),
                (UVPair.unpackU(uv) - sprite.getU0()) / (sprite.getU1() - sprite.getU0()),
                (UVPair.unpackV(uv) - sprite.getV0()) / (sprite.getV1() - sprite.getV0()), instance.getColor(i)));
        }
    }
    @Override public VertexConsumer getBuilder(ChunkSectionLayer layer) { return fluids; }
    void fluidGround(float ground, int baseY, boolean lava) {
        fluids.begin(lava ? lavaVertices : waterVertices);
        fluidGround = Math.min(.999f, ground + .002f); fluidBaseY = baseY;
    }
    List<ModelCollector.Batch> finish() {
        fluids.flush();
        var result = new ArrayList<ModelCollector.Batch>();
        batches.forEach((key, vertices) -> result.add(new ModelCollector.Batch(key.texture(), VertexCapture.triangles(vertices), key.translucent(), key.unlit())));
        for (var batch : AtlasQuads.convert(waterVertices, TextureAtlas.LOCATION_BLOCKS, ox, oy, oz, true))
            result.add(new ModelCollector.Batch(batch.texture(), batch.vertices(), true, true));
        for (var batch : AtlasQuads.convert(lavaVertices, TextureAtlas.LOCATION_BLOCKS, ox, oy, oz, false))
            result.add(new ModelCollector.Batch(batch.texture(), batch.vertices(), false, true));
        return result;
    }
}
