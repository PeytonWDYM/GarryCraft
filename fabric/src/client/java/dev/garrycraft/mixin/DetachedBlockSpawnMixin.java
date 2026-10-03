package dev.garrycraft.mixin;

import dev.garrycraft.physicsblocks.DetachedBlockView;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ServerLevel.class)
abstract class DetachedBlockSpawnMixin {
    @Inject(method = "addFreshEntity", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedLoot(Entity entity, CallbackInfoReturnable<Boolean> callback) {
        var view = DetachedBlockView.active((ServerLevel) (Object) this);
        if (view != null) callback.setReturnValue(view.spawn(entity));
    }
    @Inject(method = "levelEvent", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedEffects(Entity excluded, int event, BlockPos point, int data, CallbackInfo callback) {
        var view = DetachedBlockView.active((ServerLevel) (Object) this);
        if (view != null) { view.levelEvent(event, point, data); callback.cancel(); }
    }
}
