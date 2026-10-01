package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.FirstPersonHandsAndItemsRenderer;
import net.minecraft.client.renderer.state.level.FirstPersonHandsAndItemsRenderState;
import net.minecraft.client.renderer.state.level.PlayerRenderState;

/** Port of SkyCraft's player capture. Mesh positions remain relative to the interpolated player feet. */
public final class AvatarExporter {
    private record Scene(String session, String instance, int camera, float handFov,
                         List<ModelCollector.Batch> avatar, List<ModelCollector.Batch> hands) {}
    private static List<ModelCollector.Batch> hands = List.of();
    private AvatarExporter() {}

    public static void hands(FirstPersonHandsAndItemsRenderer renderer, float partial, PoseStack pose,
                             PlayerRenderState player, FirstPersonHandsAndItemsRenderState state) {
        var collector = new ModelCollector();
        renderer.submitHandsWithItems(partial, pose, collector, player, state);
        hands = collector.finish();
    }

    public static void frame(Minecraft mc, String session, String instance) {
        var camera = mc.gameRenderer.mainCamera();
        int mode = mc.options.getCameraType().ordinal();
        if (!camera.isDetached() || mc.player.isDeadOrDying()) {
            RenderTransport.scene(new Scene(session, instance, mode, mc.options.fov().get(), List.of(),
                mc.player.isDeadOrDying() ? List.of() : hands));
            hands = List.of();
            return;
        }
        var collector = new ModelCollector();
        var dispatcher = mc.getEntityRenderDispatcher();
        dispatcher.prepare(camera, mc.crosshairPickEntity);
        float partial = mc.getDeltaTracker().getGameTimeDeltaPartialTick(false);
        var state = dispatcher.extractEntity(mc.player, partial);
        var cameraState = mc.gameRenderer.gameRenderState().levelRenderState.cameraRenderState;
        dispatcher.submit(state, cameraState, 0, 0, 0, new PoseStack(), collector);
        RenderTransport.scene(new Scene(session, instance, mode, mc.options.fov().get(), collector.finish(), List.of()));
        hands = List.of();
    }
}
