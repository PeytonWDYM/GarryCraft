package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import net.minecraft.client.MouseHandler;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Host yaw and pitch are authoritative. Native mouse motion must not turn the mirror player again. */
@Mixin(MouseHandler.class)
public abstract class MouseTurnMixin {
    @Inject(method = "turnPlayer", at = @At("HEAD"), cancellable = true)
    private void garrycraft$hostTurn(double elapsed, CallbackInfo callback) {
        if (GarryCraftClient.linked()) callback.cancel();
    }
}
