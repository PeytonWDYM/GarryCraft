package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import net.minecraft.client.Minecraft;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** The Source window supplies input while the Minecraft window runs in the background. */
@Mixin(Minecraft.class)
public abstract class WindowFocusMixin {
    @Inject(method = "isWindowActive", at = @At("HEAD"), cancellable = true)
    private void garrycraft$hostFocus(CallbackInfoReturnable<Boolean> callback) {
        if (GarryCraftClient.linked()) callback.setReturnValue(true);
    }
}
