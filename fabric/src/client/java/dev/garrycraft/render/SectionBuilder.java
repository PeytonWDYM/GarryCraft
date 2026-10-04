package dev.garrycraft.render;

import dev.garrycraft.physics.SourceSurface;
import java.util.ArrayList;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.block.FluidRenderer;
import net.minecraft.client.renderer.block.ModelBlockRenderer;
import net.minecraft.core.BlockPos;
import net.minecraft.core.SectionPos;
import net.minecraft.tags.FluidTags;
import net.minecraft.world.level.block.RenderShape;

/** Builds a section over several render frames. Minecraft renderer calls remain on its render thread. */
final class SectionBuilder {
    final long key;
    private final Minecraft mc;
    private final net.minecraft.client.renderer.block.BlockAndTintGetter level;
    private final BlockPos origin;
    private final BlockMeshBuilder mesh;
    private final ModelBlockRenderer blocks;
    private final FluidRenderer fluids;
    private final ArrayList<double[]> boxes = new ArrayList<>();
    private final BlockPos.MutableBlockPos position = new BlockPos.MutableBlockPos();
    private int cursor;
    SectionBuilder(Minecraft mc, long key) {
        this(mc, key, mc.level);
    }

    SectionBuilder(Minecraft mc, long key, net.minecraft.client.renderer.block.BlockAndTintGetter level) {
        this.mc = mc; this.key = key;
        this.level = level;
        origin = SectionPos.of(SectionPos.x(key), SectionPos.y(key), SectionPos.z(key)).origin();
        mesh = new BlockMeshBuilder(origin.getX(), origin.getY(), origin.getZ());
        blocks = new ModelBlockRenderer(false, true, mc.getBlockColors());
        fluids = new FluidRenderer(mc.getModelManager().getFluidStateModelSet());
    }

    boolean step() {
        long deadline = System.nanoTime() + 1_000_000L;
        while (cursor < 4096) {
            int index = cursor++;
            int x = index & 15, z = (index >> 4) & 15, y = index >> 8;
            position.set(origin.getX() + x, origin.getY() + y, origin.getZ() + z);
            var state = level.getBlockState(position);
            if (!state.isAir()) {
                var pos = position.immutable();
                var fluid = state.getFluidState();
                if (!fluid.isEmpty()) {
                    var tint = fluids.fluidModels.get(fluid).tintSource();
                    mesh.fluidGround(SourceSurface.groundTop(pos), y, fluid.is(FluidTags.LAVA),
                        tint == null ? -1 : tint.colorInWorld(state, level, pos));
                    fluids.tesselate(level, pos, mesh, state, fluid);
                }
                mesh.block(state, level, pos, mc.getBlockColors());
                if (state.getRenderShape() == RenderShape.MODEL) blocks.tesselateBlock(mesh, x, y, z, level, pos, state,
                    mc.getModelManager().getBlockStateModelSet().get(state), state.getSeed(pos));
                for (var box : state.getCollisionShape(level, pos).toAabbs()) boxes.add(new double[]{
                    pos.getX() + box.minX, pos.getY() + box.minY, pos.getZ() + box.minZ,
                    pos.getX() + box.maxX, pos.getY() + box.maxY, pos.getZ() + box.maxZ});
            }
            if ((cursor & 15) == 0 && System.nanoTime() >= deadline) break;
        }
        return cursor == 4096;
    }

    WorldExporter.Section finish(String session, String instance, long sequence) {
        return new WorldExporter.Section(session, instance, sequence,
            SectionPos.x(key) + "," + SectionPos.y(key) + "," + SectionPos.z(key), false, mesh.finish(), boxes);
    }
}
