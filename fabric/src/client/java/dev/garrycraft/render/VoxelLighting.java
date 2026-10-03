package dev.garrycraft.render;

import net.minecraft.client.renderer.block.BlockAndTintGetter;
import net.minecraft.core.BlockPos;
import net.minecraft.core.SectionPos;
import net.minecraft.world.level.LightLayer;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.DataLayer;
import net.minecraft.client.renderer.Lightmap;
import net.minecraft.world.level.dimension.DimensionType;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.world.level.chunk.status.ChunkStatus;

/** Export completed vanilla light storage and material rules, including one neighboring cell on each side. */
final class VoxelLighting {
    static final int WIDTH = 18;
    static final int BYTES = WIDTH * WIDTH * WIDTH * 3;
    private VoxelLighting() {}

    static boolean affectsAir(BlockAndTintGetter level, long key) {
        var section = SectionPos.of(key);
        var engine = level.getLightEngine();
        var block = engine.getLayerListener(LightLayer.BLOCK).getDataLayerData(section);
        if (block != null && !filled(block, 0)) return true;
        var sky = engine.getLayerListener(LightLayer.SKY).getDataLayerData(section);
        return sky != null && !filled(sky, 15);
    }

    private static boolean filled(DataLayer data, int value) {
        if (data.isDefinitelyFilledWith(value)) return true;
        byte packed = (byte) (value << 4 | value);
        for (byte cell : data.getData()) if (cell != packed) return false;
        return true;
    }

    static float[] brightness(DimensionType dimension) {
        float[] result = new float[16];
        for (int level = 0; level < result.length; level++) result[level] = Lightmap.getBrightness(dimension, level);
        return result;
    }

    static byte[] capture(BlockAndTintGetter level, BlockPos sectionOrigin, ClientLevel world) {
        var sky = level.getLightEngine().getLayerListener(LightLayer.SKY);
        var block = level.getLightEngine().getLayerListener(LightLayer.BLOCK);
        var bytes = new byte[BYTES];
        var position = new BlockPos.MutableBlockPos();
        boolean[] loaded = new boolean[9];
        int sx = sectionOrigin.getX() >> 4, sz = sectionOrigin.getZ() >> 4;
        for (int z = -1; z <= 1; z++) for (int x = -1; x <= 1; x++)
            loaded[(z + 1) * 3 + x + 1] = world.getChunkSource().getChunk(sx + x, sz + z, ChunkStatus.FULL, false) != null;
        int cursor = 0;
        for (int y = -1; y <= 16; y++) for (int z = -1; z <= 16; z++) for (int x = -1; x <= 16; x++) {
            position.set(sectionOrigin.getX() + x, sectionOrigin.getY() + y, sectionOrigin.getZ() + z);
            var state = level.getBlockState(position);
            int dampening = state.getLightDampening();
            int flags = (state.propagatesSkylightDown() ? 1 : 0) | (state.isAir() ? 2 : 0)
                | (state.useShapeForLightOcclusion() ? 4 : 0) | (dampening >= 15 ? 8 : 0)
                | (centerBlocked(state) ? 16 : 0)
                | (loaded[((position.getZ() >> 4) - sz + 1) * 3 + (position.getX() >> 4) - sx + 1] ? 32 : 0);
            bytes[cursor++] = (byte) (sky.getLightValue(position) << 4 | block.getLightValue(position));
            bytes[cursor++] = (byte) dampening;
            bytes[cursor++] = (byte) flags;
        }
        return bytes;
    }

    private static boolean centerBlocked(BlockState state) {
        if (!state.useShapeForLightOcclusion()) return false;
        for (var box : state.getOcclusionShape().toAabbs())
            if (box.minX < .5 && box.maxX > .5 && box.minY < .5 && box.maxY > .5 && box.minZ < .5 && box.maxZ > .5)
                return true;
        return false;
    }
}
