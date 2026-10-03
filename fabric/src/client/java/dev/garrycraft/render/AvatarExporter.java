package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.FirstPersonHandsAndItemsRenderer;
import net.minecraft.client.renderer.state.level.FirstPersonHandsAndItemsRenderState;
import net.minecraft.client.renderer.state.level.PlayerRenderState;

/** Port of SkyCraft's player capture. Mesh positions remain relative to the interpolated player feet. */
public final class AvatarExporter {
    record Scene(String session, String instance, int camera, float handFov,
                         MeshSnapshots.Snapshot avatar, MeshSnapshots.Snapshot hands,
                         MeshSnapshots.Snapshot particles, MeshSnapshots.Snapshot entities,
                         MeshSnapshots.Snapshot cracks, List<double[]> selection,
                         List<ItemInstances.Model> itemModels, List<ItemInstances.Instance> items,
                         List<NativeItems.Item> nativeItems, MeshSnapshots.Snapshot leftArm,
                         MeshSnapshots.Snapshot rightArm, PhysicsBlockMeshes.Models physicsBlocks) {}
    private static List<ModelCollector.Batch> hands = List.of();
    private AvatarExporter() {}

    public static void hands(FirstPersonHandsAndItemsRenderer renderer, float partial, PoseStack pose,
                             PlayerRenderState player, FirstPersonHandsAndItemsRenderState state) {
        if (!dev.garrycraft.GarryCraftClient.captureScene()) return;
        var collector = new ModelCollector();
        renderer.submitHandsWithItems(partial, pose, collector, player, state);
        hands = collector.finish();
    }

    public static void frame(Minecraft mc, String session, String instance) {
        Textures.tick(mc.level.getGameTime());
        var camera = mc.gameRenderer.mainCamera();
        mc.getEntityRenderDispatcher().prepare(camera, mc.crosshairPickEntity);
        var particles = MeshSnapshots.changed("particles", ParticleExporter.frame(mc));
        var world = EntityExporter.frame(mc);
        var entities = MeshSnapshots.changed("entities", world.batches());
        var cracks = MeshSnapshots.changed("cracks", BlockEffects.cracks(mc));
        var selection = BlockEffects.selection(mc);
        int mode = mc.options.getCameraType().ordinal();
        PhysicsBlockMeshes.frame(mc, session, instance);
        if (mc.player.isDeadOrDying()) {
            RenderTransport.scene(new Scene(session, instance, mode, mc.options.fov().get(), MeshSnapshots.changed("avatar", List.of()),
                MeshSnapshots.changed("hands", mc.player.isDeadOrDying() ? List.of() : hands), particles, entities, cracks, selection,
                world.models(), world.items(), List.of(), MeshSnapshots.changed("leftArm", List.of()),
                MeshSnapshots.changed("rightArm", List.of()), PhysicsBlockMeshes.snapshot()));
            hands = List.of();
            return;
        }
        var collector = new ModelCollector(dev.garrycraft.item.PhysicsGun.equipped(mc.player));
        var dispatcher = mc.getEntityRenderDispatcher();
        dispatcher.prepare(camera, mc.crosshairPickEntity);
        float partial = mc.getDeltaTracker().getGameTimeDeltaPartialTick(false);
        var state = dispatcher.extractEntity(mc.player, partial);
        var cameraState = mc.gameRenderer.gameRenderState().levelRenderState.cameraRenderState;
        dispatcher.submit(state, cameraState, 0, 0, 0, new PoseStack(), collector);
        var avatar = collector.finish();
        dev.garrycraft.testing.GameplayOracle.avatar(avatar.stream().mapToInt(batch -> batch.vertices().size()).sum());
        RenderTransport.scene(new Scene(session, instance, mode, mc.options.fov().get(), MeshSnapshots.changed("avatar", avatar),
            MeshSnapshots.changed("hands", camera.isDetached() ? List.of() : hands), particles, entities, cracks, selection, world.models(), world.items(),
            collector.nativeItems(), MeshSnapshots.changed("leftArm", collector.nativeArms().left()),
            MeshSnapshots.changed("rightArm", collector.nativeArms().right()), PhysicsBlockMeshes.snapshot()));
        hands = List.of();
    }
}
