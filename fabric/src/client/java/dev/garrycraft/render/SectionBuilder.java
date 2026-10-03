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
import net.minecraft.world.level.block.BaseTorchBlock;
import net.minecraft.world.level.block.WallTorchBlock;

/** Builds a section over several render frames. Minecraft renderer calls remain on its render thread. */
final class SectionBuilder {
    final long key;
    private final Minecraft mc;
    private final BlockPos origin;
    private final BlockMeshBuilder mesh;
    private final ModelBlockRenderer blocks;
    private final FluidRenderer fluids;
    private final ArrayList<double[]> boxes = new ArrayList<>();
    private final ArrayList<double[]> occluders = new ArrayList<>();
    private final ArrayList<WorldExporter.Light> lights = new ArrayList<>();
    private final BlockPos.MutableBlockPos position = new BlockPos.MutableBlockPos();
    private int cursor;

    SectionBuilder(Minecraft mc, long key) {
        this.mc = mc; this.key = key;
        origin = SectionPos.of(SectionPos.x(key), SectionPos.y(key), SectionPos.z(key)).origin();
        mesh = new BlockMeshBuilder(origin.getX(), origin.getY(), origin.getZ());
        blocks = new ModelBlockRenderer(mc.options.ambientOcclusion().get(), true, mc.getBlockColors());
        fluids = new FluidRenderer(mc.getModelManager().getFluidStateModelSet());
    }

    boolean step() {
        long deadline = System.nanoTime() + 1_000_000L;
        while (cursor < 4096) {
            int index = cursor++;
            int x = index & 15, z = (index >> 4) & 15, y = index >> 8;
            position.set(origin.getX() + x, origin.getY() + y, origin.getZ() + z);
            var state = mc.level.getBlockState(position);
            if (!state.isAir()) {
                var pos = position.immutable();
                var fluid = state.getFluidState();
                if (!fluid.isEmpty()) {
                    mesh.fluidGround(SourceSurface.groundTop(pos), y, fluid.is(FluidTags.LAVA));
                    fluids.tesselate(mc.level, pos, mesh, state, fluid);
                }
                mesh.emissive(state.getLightEmission() > 0);
                if (state.getRenderShape() == RenderShape.MODEL) blocks.tesselateBlock(mesh, x, y, z, mc.level, pos, state,
                    mc.getModelManager().getBlockStateModelSet().get(state), state.getSeed(pos));
                for (var box : state.getCollisionShape(mc.level, pos).toAabbs()) boxes.add(new double[]{
                    pos.getX() + box.minX, pos.getY() + box.minY, pos.getZ() + box.minZ,
                    pos.getX() + box.maxX, pos.getY() + box.maxY, pos.getZ() + box.maxZ});
                // Glass can collide without blocking light. Use Minecraft's separate occlusion contract.
                if (state.canOcclude()) for (var box : state.getOcclusionShape().toAabbs()) occluders.add(new double[]{
                    pos.getX() + box.minX, pos.getY() + box.minY, pos.getZ() + box.minZ,
                    pos.getX() + box.maxX, pos.getY() + box.maxY, pos.getZ() + box.maxZ});
                int emission = state.getLightEmission();
                if (emission > 0) {
                    float lx = pos.getX() + .5f, ly = pos.getY() + .5f, lz = pos.getZ() + .5f;
                    if (state.getBlock() instanceof WallTorchBlock) {
                        var facing = state.getValue(WallTorchBlock.FACING);
                        lx += facing.getStepX() * .27f; lz += facing.getStepZ() * .27f; ly += .42f;
                    } else if (state.getBlock() instanceof BaseTorchBlock) ly += .2f;
                    ly = Math.max(ly, pos.getY() + SourceSurface.groundTop(pos) + .05f);
                    lights.add(new WorldExporter.Light(lx, ly, lz, emission, fluid.is(FluidTags.LAVA) ? 0xFF7B20 : 0xFFDDAA));
                }
            }
            if ((cursor & 15) == 0 && System.nanoTime() >= deadline) break;
        }
        return cursor == 4096;
    }

    WorldExporter.Section finish(String session, String instance, long sequence) {
        return new WorldExporter.Section(session, instance, sequence,
            SectionPos.x(key) + "," + SectionPos.y(key) + "," + SectionPos.z(key), false, mesh.finish(), boxes, lights, occluders);
    }
}
