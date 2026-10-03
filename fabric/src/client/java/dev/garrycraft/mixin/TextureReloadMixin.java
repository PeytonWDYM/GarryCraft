package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.texture.TextureAtlas;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(TextureAtlas.class)
public abstract class TextureReloadMixin {
    @Inject(method = "upload", at = @At("TAIL"))
    private void garrycraft$reload(CallbackInfo callback) {
        GarryCraftClient.resourcesChanged();
        // Live, queued, and extracted particles must all release the previous atlas coordinates.
        var minecraft = Minecraft.getInstance();
        minecraft.particleEngine.clearParticles();
        minecraft.gameRenderer.gameRenderState().levelRenderState.particlesRenderState.reset();
    }
}
