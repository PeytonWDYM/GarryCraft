package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import net.minecraft.client.renderer.LevelRenderer;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Source draws the world. Minecraft retains its transparent hand, HUD, and screen render passes. */
@Mixin(LevelRenderer.class)
public abstract class LevelRendererMixin {
    @Inject(method = "render(Lcom/mojang/blaze3d/resource/GraphicsResourceAllocator;ZLnet/minecraft/client/renderer/state/level/CameraRenderState;Lcom/mojang/renderpearl/api/buffers/GpuBufferSlice;Lorg/joml/Vector4f;ZZ)V",
        at = @At("HEAD"), cancellable = true)
    private void garrycraft$hostWorld(CallbackInfo callback) {
        if (GarryCraftClient.linked()) callback.cancel();
    }
}
