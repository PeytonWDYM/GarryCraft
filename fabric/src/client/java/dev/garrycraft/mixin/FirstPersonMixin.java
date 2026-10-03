package dev.garrycraft.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import com.mojang.blaze3d.vertex.PoseStack;
import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.render.AvatarExporter;
import dev.garrycraft.item.PhysicsGun;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.FirstPersonHandsAndItemsRenderer;
import net.minecraft.client.renderer.GameRenderer;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.client.renderer.state.level.FirstPersonHandsAndItemsRenderState;
import net.minecraft.client.renderer.state.level.PlayerRenderState;
import org.joml.Matrix4f;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

@Mixin(GameRenderer.class)
public abstract class FirstPersonMixin {
    @WrapOperation(method = "renderItemInHand", at = @At(value = "INVOKE",
        target = "Lnet/minecraft/client/renderer/FirstPersonHandsAndItemsRenderer;submitHandsWithItems(FLcom/mojang/blaze3d/vertex/PoseStack;Lnet/minecraft/client/renderer/SubmitNodeCollector;Lnet/minecraft/client/renderer/state/level/PlayerRenderState;Lnet/minecraft/client/renderer/state/level/FirstPersonHandsAndItemsRenderState;)V"))
    private void garrycraft$hands(FirstPersonHandsAndItemsRenderer renderer, float partial, PoseStack pose,
        SubmitNodeCollector collector, PlayerRenderState player, FirstPersonHandsAndItemsRenderState hands,
        Operation<Void> original) {
        if (!GarryCraftClient.linked()) {
            original.call(renderer, partial, pose, collector, player, hands);
            return;
        }
        // Remove camera rotation. Source draws this pose relative to its current view, without transport yaw lag.
        var camera = Minecraft.getInstance().gameRenderer.gameRenderState().levelRenderState.cameraRenderState;
        var local = new PoseStack();
        local.mulPose(new Matrix4f(camera.viewRotationMatrix).mul(pose.last().pose()));
        // Source applies this same vanilla transform to its installed gun and captured skin arms.
        dev.garrycraft.bridge.StatePublisher.nativeViewmodelPose(local.last().pose());
        if (PhysicsGun.equipped(Minecraft.getInstance().player)) return;
        AvatarExporter.hands(renderer, partial, local, player, hands);
    }
}
