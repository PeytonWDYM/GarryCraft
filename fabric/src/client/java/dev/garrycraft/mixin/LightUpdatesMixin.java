package dev.garrycraft.mixin;

import dev.garrycraft.render.WorldExporter;
import net.minecraft.client.multiplayer.ClientChunkCache;
import net.minecraft.core.SectionPos;
import net.minecraft.world.level.LightLayer;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/** Keep vanilla's dirty callback while distinguishing propagated light from geometry edits. */
@Mixin(ClientChunkCache.class)
public abstract class LightUpdatesMixin {
    @Inject(method = "onLightUpdate", at = @At("HEAD"))
    private void garrycraft$beginLight(LightLayer layer, SectionPos section, CallbackInfo callback) {
        WorldExporter.lightUpdate(true);
    }
    @Inject(method = "onLightUpdate", at = @At("RETURN"))
    private void garrycraft$endLight(LightLayer layer, SectionPos section, CallbackInfo callback) {
        WorldExporter.lightUpdate(false);
    }
}
