// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.render;

import dev.garrycraft.mixin.ClientLevelAccessor;
import dev.garrycraft.physics.SourceClip;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.resources.Identifier;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;

/** Shows vanilla destruction stages and the targeted block's actual selection shape. */
final class BlockEffects {
    private static final int[][] FACES = {{0, 1, 3, 2}, {4, 6, 7, 5}, {0, 4, 5, 1}, {2, 3, 7, 6}, {0, 2, 6, 4}, {1, 5, 7, 3}};
    private BlockEffects() {}
    static List<double[]> selection(Minecraft mc) {
        if (mc.gui.screen() != null || !(mc.hitResult instanceof BlockHitResult hit) || hit.getType() != HitResult.Type.BLOCK) return List.of();
        var pos = hit.getBlockPos();
        if (hit instanceof SourceClip.HostHit) {
            if (!(mc.player.getMainHandItem().getItem() instanceof BlockItem)) return List.of();
            return List.of(bounds(new AABB(pos)));
        }
        return mc.level.getBlockState(pos).getShape(mc.level, pos).toAabbs().stream().map(box -> bounds(box.move(pos))).toList();
    }
    static List<ModelCollector.Batch> cracks(Minecraft mc) {
        var result = new ArrayList<ModelCollector.Batch>();
        for (var progress : ((ClientLevelAccessor) mc.level).garrycraft$destroyingBlocks().values()) {
            int stage = progress.getProgress();
            if (stage < 0 || stage > 9) continue;
            var pos = progress.getPos();
            var shape = mc.level.getBlockState(pos).getShape(mc.level, pos);
            if (shape.isEmpty()) continue;
            var box = shape.bounds().move(pos).inflate(.004);
            var corners = new ArrayList<double[]>();
            for (double x : new double[]{box.minX, box.maxX}) for (double y : new double[]{box.minY, box.maxY})
                for (double z : new double[]{box.minZ, box.maxZ}) corners.add(new double[]{x, y, z});
            var vertices = new ArrayList<float[]>();
            float[][] uv = {{0, 0}, {1, 0}, {1, 1}, {0, 1}};
            for (var face : FACES) for (int index : new int[]{0, 1, 2, 0, 2, 3}) {
                var point = corners.get(face[index]);
                vertices.add(new float[]{(float) point[0], (float) point[1], (float) point[2], uv[index][0], uv[index][1], 255, 255, 255, 255});
            }
            int texture = Textures.resource(Identifier.fromNamespaceAndPath("minecraft", "textures/block/destroy_stage_" + stage + ".png"));
            result.add(new ModelCollector.Batch(texture, vertices, true, true));
        }
        dev.garrycraft.testing.TerrainUseOracle.effects(result.stream().mapToInt(batch -> batch.vertices().size()).sum(), 0);
        return result;
    }
    private static double[] bounds(AABB box) { return new double[]{box.minX, box.minY, box.minZ, box.maxX, box.maxY, box.maxZ}; }
}
