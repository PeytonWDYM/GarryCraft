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
        if (GarryCraftClient.linked()) result.setReturnValue(Minecraft.getInstance().options.framerateLimit().get());
    }
}
