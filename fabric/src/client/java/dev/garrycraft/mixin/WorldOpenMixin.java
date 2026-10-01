package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.MirrorWorld;
import net.minecraft.client.gui.screens.worldselection.WorldOpenFlows;
import net.minecraft.world.level.storage.LevelStorageSource.LevelStorageAccess;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(WorldOpenFlows.class)
public abstract class WorldOpenMixin {
    @Inject(method = "askForBackup", at = @At("HEAD"), cancellable = true)
    private void garrycraft$acceptMirrorWorld(LevelStorageAccess access, boolean customized,
                                               Runnable proceed, Runnable cancel, CallbackInfo callback) {
        if (!customized && MirrorWorld.autoLoading(access.getLevelId())) {
            GarryCraftClient.LOG.info("GarryCraft accepted its mirror world's experimental data settings");
            callback.cancel();
            proceed.run();
        }
    }
}
