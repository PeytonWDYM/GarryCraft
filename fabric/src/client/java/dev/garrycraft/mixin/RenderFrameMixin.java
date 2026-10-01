package dev.garrycraft.mixin;

import dev.garrycraft.bridge.StatePublisher;
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
        HostViewport.update((Minecraft) (Object) this);
    }

    @Inject(method = "renderFrame", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/renderer/GameRenderer;render()V", shift = At.Shift.AFTER))
    private void garrycraft$cameraFrame(boolean advanceGameTime, CallbackInfo callback) {
        GarryCraftClient.renderFrame((Minecraft) (Object) this);
    }
}
