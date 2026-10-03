package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.render.HostViewport;
import net.minecraft.client.Minecraft;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Minecraft.class)
public abstract class RenderFrameMixin {
    @Inject(method = "runTick", at = @At("HEAD"))
    private void garrycraft$inputFrame(boolean advanceGameTime, CallbackInfo callback) {
        GarryCraftClient.beginFrame((Minecraft) (Object) this);
    }

    @Inject(method = "renderFrame", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/renderer/GameRenderer;extract(Lnet/minecraft/client/DeltaTracker;Z)V"))
    private void garrycraft$viewport(boolean advanceGameTime, CallbackInfo callback) {
        var minecraft = (Minecraft) (Object) this;
        if (minecraft.isRunning()) HostViewport.update(minecraft);
    }

    @Inject(method = "renderFrame", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/renderer/GameRenderer;render()V", shift = At.Shift.AFTER))
    private void garrycraft$cameraFrame(boolean advanceGameTime, CallbackInfo callback) {
        var minecraft = (Minecraft) (Object) this;
        // Vanilla renders disconnect progress after clearing the level, before releasing the player.
        if (minecraft.isRunning() && minecraft.level != null) GarryCraftClient.renderFrame(minecraft);
    }
}
