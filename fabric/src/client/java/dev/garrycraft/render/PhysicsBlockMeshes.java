package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import dev.garrycraft.physicsblocks.PhysicsBlocks;
import java.util.LinkedHashMap;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.block.ModelBlockRenderer;
import net.minecraft.client.renderer.block.MovingBlockRenderState;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;

/** Capture complete vanilla block models before removal. Source supplies the body's transform afterward. */
public final class PhysicsBlockMeshes {
    public record Model(long id, List<ModelCollector.Batch> batches) {}
    public record Models(long revision, List<Model> models, List<Integer> destructionTextures) {}
    private static final LinkedHashMap<Long, Model> models = new LinkedHashMap<>();
    private static String session = "", instance = "";
    private static long revision, generation = -1;
    private static Models snapshot = new Models(0, List.of(), List.of());
    private record Preparation(PhysicsBlocks.BlockSnapshot block, WorldExporter.DetachSection section) {}
    private static final java.util.ArrayDeque<Preparation> preparations = new java.util.ArrayDeque<>();

    public static void frame(Minecraft mc, String nextSession, String nextInstance) {
        boolean changed = false;
        if (!session.equals(nextSession) || !instance.equals(nextInstance) || generation != PhysicsBlocks.generation()) {
            if (session.equals(nextSession) && generation == PhysicsBlocks.generation()) {
                for (var pending : preparations) PhysicsBlocks.reject(mc, pending.block(), "render instance changed before block capture");
            }
            session = nextSession; instance = nextInstance;
            generation = PhysicsBlocks.generation();
            models.clear(); preparations.clear();
            changed = true;
        }
        for (var block = PhysicsBlocks.capture(); block != null; block = PhysicsBlocks.capture()) {
            if (!block.session().equals(session)) continue;
            if (!block.instance().equals(instance)) {
                PhysicsBlocks.reject(mc, block, "stale render instance");
                continue;
            }
            if (mc.level.getChunkSource().getChunk(block.position().getX() >> 4, block.position().getZ() >> 4,
                net.minecraft.world.level.chunk.status.ChunkStatus.FULL, false) == null) {
                PhysicsBlocks.reject(mc, block, "Minecraft client chunk is not loaded");
                continue;
            }
            var model = capture(mc, block);
            models.put(block.id(), model);
            if (model.batches().isEmpty()) PhysicsBlocks.captured(mc, block, false);
            else preparations.add(new Preparation(block, WorldExporter.prepareDetach(mc, block.id(), block.position())));
            changed = true;
        }
        if (!preparations.isEmpty() && preparations.peek().section().step()) {
            var prepared = preparations.remove();
            PhysicsBlocks.captured(mc, prepared.block(), true);
        }
        var active = PhysicsBlocks.blocks();
        for (var block : active) {
            if (!models.containsKey(block.id())) { models.put(block.id(), capture(mc, block)); changed = true; }
        }
        var failures = PhysicsBlocks.results();
        for (var failure : failures) if (failure.status().equals("rejected")) {
            changed |= models.remove(failure.id()) != null;
            WorldExporter.cancelDetach(failure.id());
        }
        for (long consumed : dev.garrycraft.physicsblocks.DetachedBlockMining.consumed()) changed |= models.remove(consumed) != null;
        if (changed) snapshot = new Models(++revision, List.copyOf(models.values()), models.isEmpty() ? List.of() :
            java.util.stream.IntStream.range(0, 10).mapToObj(stage -> Textures.resource(net.minecraft.resources.Identifier.fromNamespaceAndPath(
                "minecraft", "textures/block/destroy_stage_" + stage + ".png"))).toList());
    }

    private static Model capture(Minecraft mc, PhysicsBlocks.BlockSnapshot block) {
        var moving = new MovingBlockRenderState();
        moving.blockPos = block.position(); moving.randomSeedPos = block.position(); moving.blockState = block.state();
        moving.biome = mc.level.getBiome(block.position());
        moving.cardinalLighting = mc.level.cardinalLighting();
        moving.lightEngine = mc.level.getLightEngine();
        var mesh = new BlockMeshBuilder(0, 0, 0);
        mesh.block(block.state(), moving, block.position(), mc.getBlockColors());
        if (block.state().getRenderShape() == RenderShape.MODEL) {
            new ModelBlockRenderer(false, true, mc.getBlockColors()).tesselateBlock(mesh, -.5f, -.5f, -.5f,
                moving, block.position(), block.state(), mc.getModelManager().getBlockStateModelSet().get(block.state()), block.state().getSeed(block.position()));
        }
        var batches = new java.util.ArrayList<>(mesh.finish());
        if (block.blockEntity() != null) {
            var entity = BlockEntity.loadStatic(block.position(), block.state(), block.blockEntity(), mc.level.registryAccess());
            if (entity != null) {
                entity.setLevel(mc.level);
                var dispatcher = mc.getBlockEntityRenderDispatcher();
                var renderer = dispatcher.getRenderer(entity);
                if (renderer != null) {
                    // Capture the complete detached model without the world's distance/offscreen filters.
                    var state = renderer.createRenderState();
                    renderer.extractRenderState(entity, state, 0, mc.gameRenderer.mainCamera().position(), null);
                    var pose = new PoseStack(); pose.translate(-.5, -.5, -.5);
                    var collector = new ModelCollector();
                    renderer.submit(state, pose, collector, mc.gameRenderer.gameRenderState().levelRenderState.cameraRenderState);
                    batches.addAll(collector.finish());
                }
            }
        }
        return new Model(block.id(), List.copyOf(batches));
    }
    public static Models snapshot() { return snapshot; }
    private PhysicsBlockMeshes() {}
}
