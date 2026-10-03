package dev.garrycraft.mixin;

import dev.garrycraft.physicsblocks.DetachedBlockView;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.ExperienceOrb;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(ExperienceOrb.class)
abstract class DetachedBlockExperienceMixin {
    @Inject(method = "tryMergeToExisting", at = @At("HEAD"), cancellable = true)
    private static void garrycraft$detachedExperience(ServerLevel level, Vec3 point, int value, CallbackInfoReturnable<Boolean> callback) {
        // Existing orbs remain untouched until the complete loot transaction reaches its durable commit.
        if (DetachedBlockView.active(level) != null) callback.setReturnValue(false);
    }
}
