package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.QuadInstance;
import com.mojang.blaze3d.vertex.VertexConsumer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import net.minecraft.client.model.geom.builders.UVPair;
import net.minecraft.client.color.block.BlockColors;
import net.minecraft.client.renderer.block.BlockAndTintGetter;
import net.minecraft.client.renderer.block.BlockQuadOutput;
import net.minecraft.client.renderer.block.FluidRenderer;
import net.minecraft.client.renderer.chunk.ChunkSectionLayer;
import net.minecraft.client.renderer.texture.TextureAtlas;
import net.minecraft.client.resources.model.geometry.BakedQuad;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;

/** Minecraft supplies block models, material tint, and fluid surfaces. Source supplies lighting. */
final class BlockMeshBuilder implements BlockQuadOutput, FluidRenderer.Output {
    private record Key(int texture, boolean translucent, boolean unlit, int tint, int tileX, int tileY, int tileZ, int face, int plane) {}
    private final LinkedHashMap<Key, List<VertexCapture.Vertex>> batches = new LinkedHashMap<>();
    private final List<VertexCapture.Vertex> waterVertices = new ArrayList<>(), lavaVertices = new ArrayList<>();
    private final VertexCapture fluids = new VertexCapture() {
        @Override public VertexConsumer setColor(int r, int g, int b, int a) {
            return super.setColor((a << 24) | (fluidTint & 0xFFFFFF));
        }
        @Override public VertexConsumer setColor(int color) {
            return super.setColor((color & 0xFF000000) | (fluidTint & 0xFFFFFF));
        }
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
    private int fluidTint;
    private BlockState state;
    private BlockAndTintGetter level;
    private BlockPos position;
    private BlockColors colors;
    BlockMeshBuilder(int x, int y, int z) { ox = x; oy = y; oz = z; }
    void block(BlockState state, BlockAndTintGetter level, BlockPos position, BlockColors colors) {
        emissive = state.getLightEmission() > 0;
        this.state = state; this.level = level; this.position = position; this.colors = colors;
    }

    @Override public void put(float x, float y, float z, BakedQuad quad, QuadInstance instance) {
        var sprite = quad.materialInfo().sprite();
        boolean translucent = quad.materialInfo().layer().translucent();
        int face = 0, plane = 0;
        // Keep face batches local so Source can light them and reuse unchanged geometry.
        {
            var a = quad.position(0); var b = quad.position(1); var c = quad.position(2);
            float nx = (b.y() - a.y()) * (c.z() - a.z()) - (b.z() - a.z()) * (c.y() - a.y());
            float ny = (b.z() - a.z()) * (c.x() - a.x()) - (b.x() - a.x()) * (c.z() - a.z());
            float nz = (b.x() - a.x()) * (c.y() - a.y()) - (b.y() - a.y()) * (c.x() - a.x());
            int axis = Math.abs(nx) > Math.abs(ny) ? 0 : 1;
            if (Math.abs(nz) > (axis == 0 ? Math.abs(nx) : Math.abs(ny))) axis = 2;
            float component = axis == 0 ? nx : axis == 1 ? ny : nz;
            float coordinate = axis == 0 ? ox + x + a.x() : axis == 1 ? oy + y + a.y() : oz + z + a.z();
            face = axis * 2 + (component < 0 ? 1 : 0);
            plane = Math.round(coordinate * 16);
        }
        var tintSource = quad.materialInfo().isTinted() ? colors.getTintSource(state, quad.materialInfo().tintIndex()) : null;
        int tint = tintSource == null ? -1 : tintSource.colorInWorld(state, level, position);
        var key = new Key(Textures.sprite(sprite), translucent, emissive, tint & 0xFFFFFF,
            (int) x / 4, (int) y / 4, (int) z / 4, face, plane);
        var vertices = batches.computeIfAbsent(key, ignored -> new ArrayList<>());
        for (int i = 0; i < 4; i++) {
            var pos = quad.position(i);
            long uv = quad.packedUV(i);
            vertices.add(new VertexCapture.Vertex(ox + x + pos.x(), oy + y + pos.y(), oz + z + pos.z(),
                (UVPair.unpackU(uv) - sprite.getU0()) / (sprite.getU1() - sprite.getU0()),
                (UVPair.unpackV(uv) - sprite.getV0()) / (sprite.getV1() - sprite.getV0()), tint));
        }
    }
    @Override public VertexConsumer getBuilder(ChunkSectionLayer layer) { return fluids; }
    void fluidGround(float ground, int baseY, boolean lava, int tint) {
        fluids.begin(lava ? lavaVertices : waterVertices);
        fluidGround = Math.min(.999f, ground + .002f); fluidBaseY = baseY; fluidTint = tint;
    }
    List<ModelCollector.Batch> finish() {
        fluids.flush();
        var result = new ArrayList<ModelCollector.Batch>();
        batches.forEach((key, vertices) -> result.add(new ModelCollector.Batch(key.texture(), VertexCapture.triangles(vertices), key.translucent(), key.unlit(), true)));
        for (var batch : AtlasQuads.convert(WaterFaces.surfaces(waterVertices), TextureAtlas.LOCATION_BLOCKS, ox, oy, oz, true))
            result.add(new ModelCollector.Batch(batch.texture(), batch.vertices(), true, false, true));
        for (var batch : AtlasQuads.convert(lavaVertices, TextureAtlas.LOCATION_BLOCKS, ox, oy, oz, false))
            result.add(new ModelCollector.Batch(batch.texture(), batch.vertices(), false, true));
        return result;
    }
}
