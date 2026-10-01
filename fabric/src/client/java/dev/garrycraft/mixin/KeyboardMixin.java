package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.bridge.InputBridge;
import com.mojang.blaze3d.platform.Window;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import com.mojang.blaze3d.platform.InputConstants;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(InputConstants.class)
public abstract class KeyboardMixin {
    @Inject(method = "isKeyDown", at = @At("HEAD"), cancellable = true)
    private static void garrycraft$hostKeys(int key, CallbackInfoReturnable<Boolean> result) {
        if (GarryCraftClient.linked()) result.setReturnValue(InputBridge.isKeyDown(key));
    }
    @Inject(method = "grabMouse", at = @At("HEAD"), cancellable = true)
    private static void garrycraft$grabMouse(Window window, double x, double y, CallbackInfo callback) {
        if (GarryCraftClient.linked()) callback.cancel();
    }
    @Inject(method = "releaseMouse", at = @At("HEAD"), cancellable = true)
    private static void garrycraft$releaseMouse(Window window, double x, double y, CallbackInfo callback) {
        if (GarryCraftClient.linked()) callback.cancel();
    }
}

