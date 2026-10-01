package dev.garrycraft.mixin;

import dev.garrycraft.render.WorldExporter;
import net.minecraft.client.renderer.extract.LevelExtractor;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(LevelExtractor.class)
public abstract class WorldChangesMixin {
    @Inject(method = "setSectionDirty(IIIZ)V", at = @At("HEAD"))
    private void garrycraft$section(int x, int y, int z, boolean urgent, CallbackInfo callback) { WorldExporter.dirty(x, y, z); }
    @Inject(method = "setBlockDirty", at = @At("HEAD"))
    private void garrycraft$block(net.minecraft.core.BlockPos pos, boolean neighbors, CallbackInfo callback) { WorldExporter.urgent(pos); }
}
