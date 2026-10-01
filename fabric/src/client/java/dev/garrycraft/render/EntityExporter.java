package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import dev.garrycraft.combat.SourceActor;
import java.util.List;
import net.minecraft.client.Minecraft;

/** Uses Minecraft's entity renderers for mobs, projectiles, dropped items, and primed TNT. */
final class EntityExporter {
    record Scene(List<ModelCollector.Batch> batches, List<ItemInstances.Model> models, List<ItemInstances.Instance> items) {}
    private EntityExporter() {}
    static Scene frame(Minecraft mc) {
        var collector = new ModelCollector();
        var items = new ItemInstances();
        var dispatcher = mc.getEntityRenderDispatcher();
        var camera = mc.gameRenderer.gameRenderState().levelRenderState.cameraRenderState;
        float partial = mc.getDeltaTracker().getGameTimeDeltaPartialTick(false);
        for (var entity : mc.level.entitiesForRendering()) {
            if (entity == mc.player || entity instanceof SourceActor || entity.isInvisible()
                    || entity.distanceToSqr(mc.player) > 96 * 96) continue;
            var position = entity.getPosition(partial);
            var state = dispatcher.extractEntity(entity, partial);
            dispatcher.submit(state, camera, position.x, position.y, position.z, new PoseStack(),
                entity instanceof net.minecraft.world.entity.item.ItemEntity ? items : collector);
        }
        var blockDispatcher = mc.getBlockEntityRenderDispatcher();
        blockDispatcher.prepare(camera.pos);
        int cx = mc.player.getBlockX() >> 4, cz = mc.player.getBlockZ() >> 4;
        for (int x = cx - 3; x <= cx + 3; x++) for (int z = cz - 3; z <= cz + 3; z++) {
            var chunk = mc.level.getChunkSource().getChunk(x, z, net.minecraft.world.level.chunk.status.ChunkStatus.FULL, false);
            if (chunk == null) continue;
            for (var blockEntity : chunk.getBlockEntities().values()) {
                var state = blockDispatcher.tryExtractRenderState(blockEntity, partial, null, false);
                if (state == null) continue;
                var pose = new PoseStack();
                var pos = blockEntity.getBlockPos();
                pose.translate(pos.getX(), pos.getY(), pos.getZ());
                blockDispatcher.submit(state, pose, collector, camera);
            }
        }
        var batches = new java.util.ArrayList<>(collector.finish());
        batches.addAll(items.finish());
        return new Scene(batches, items.models(), items.instances());
    }
}
