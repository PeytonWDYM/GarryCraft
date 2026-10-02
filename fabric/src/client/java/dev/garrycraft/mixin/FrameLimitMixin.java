package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import com.mojang.blaze3d.platform.FramerateLimitTracker;
import net.minecraft.client.Minecraft;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(FramerateLimitTracker.class)
public abstract class FrameLimitMixin {
    @Inject(method = "getFramerateLimit", at = @At("HEAD"), cancellable = true)
    private void garrycraft$backgroundTick(CallbackInfoReturnable<Integer> result) {
        if (!GarryCraftClient.linked()) return;
        int saved = Minecraft.getInstance().options.framerateLimit().get();
        int target = GarryCraftClient.targetFps();
        // Extra hidden frames cannot reach Source. Keep a lower saved cap, but bound Unlimited to the host rate.
        result.setReturnValue(saved >= net.minecraft.client.Options.UNLIMITED_FRAMERATE_CUTOFF ? target : Math.min(saved, target));
    }
}
