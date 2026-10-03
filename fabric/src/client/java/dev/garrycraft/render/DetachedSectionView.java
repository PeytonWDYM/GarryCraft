package dev.garrycraft.render;

import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.renderer.block.BlockAndTintGetter;
import net.minecraft.core.BlockPos;
import net.minecraft.core.SectionPos;
import net.minecraft.world.level.CardinalLighting;
import net.minecraft.world.level.ColorResolver;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.lighting.LevelLightEngine;
import net.minecraft.world.level.material.FluidState;

/** Keep a section and its one-cell border valid while a detach transaction awaits disk and network delivery. */
final class DetachedSectionView implements BlockAndTintGetter {
    private static final int WIDTH = 18;
    private final BlockPos origin;
    private final BlockState[] states = new BlockState[WIDTH * WIDTH * WIDTH];
    private final BlockEntity[] entities = new BlockEntity[states.length];
    private final Biome[] biomes = new Biome[states.length];
    private final CardinalLighting cardinal;
    private final LevelLightEngine light;
    private final int minimum, height;

    DetachedSectionView(ClientLevel level, BlockPos removed, java.util.Set<BlockPos> omitted) {
        origin = SectionPos.of(removed).origin().offset(-1, -1, -1);
        cardinal = level.cardinalLighting(); light = level.getLightEngine();
        minimum = level.getMinY(); height = level.getHeight();
        var cursor = new BlockPos.MutableBlockPos();
        for (int y = 0; y < WIDTH; y++) for (int z = 0; z < WIDTH; z++) for (int x = 0; x < WIDTH; x++) {
            cursor.set(origin.getX() + x, origin.getY() + y, origin.getZ() + z);
            int index = (y * WIDTH + z) * WIDTH + x;
            boolean air = omitted.contains(cursor);
            states[index] = air ? Blocks.AIR.defaultBlockState() : level.getBlockState(cursor);
            entities[index] = air ? null : level.getBlockEntity(cursor);
            biomes[index] = level.getBiome(cursor).value();
        }
    }
    private int index(BlockPos pos) {
        int x = pos.getX() - origin.getX(), y = pos.getY() - origin.getY(), z = pos.getZ() - origin.getZ();
        return x >= 0 && x < WIDTH && y >= 0 && y < WIDTH && z >= 0 && z < WIDTH ? (y * WIDTH + z) * WIDTH + x : -1;
    }
    @Override public BlockState getBlockState(BlockPos pos) {
        int index = index(pos); return index < 0 ? Blocks.AIR.defaultBlockState() : states[index];
    }
    @Override public BlockEntity getBlockEntity(BlockPos pos) { int index = index(pos); return index < 0 ? null : entities[index]; }
    @Override public FluidState getFluidState(BlockPos pos) { return getBlockState(pos).getFluidState(); }
    @Override public CardinalLighting cardinalLighting() { return cardinal; }
    @Override public LevelLightEngine getLightEngine() { return light; }
    @Override public int getHeight() { return height; }
    @Override public int getMinY() { return minimum; }
    @Override public int getBlockTint(BlockPos pos, ColorResolver resolver) {
        int index = index(pos);
        return resolver.getColor(biomes[index < 0 ? 0 : index], pos.getX(), pos.getZ());
    }
}
