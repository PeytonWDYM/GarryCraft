package dev.garrycraft.mixin;

import dev.garrycraft.physicsblocks.DetachedBlockView;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(Level.class)
abstract class DetachedBlockLevelMixin {
    @Inject(method = "getBlockState", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedState(BlockPos position, CallbackInfoReturnable<BlockState> callback) {
        var view = DetachedBlockView.active((Level) (Object) this);
        if (view != null) callback.setReturnValue(view.state(position));
    }
    @Inject(method = "getBlockEntity", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedEntity(BlockPos position, CallbackInfoReturnable<BlockEntity> callback) {
        var view = DetachedBlockView.active((Level) (Object) this);
        if (view != null) callback.setReturnValue(view.entity(position));
    }
    @Inject(method = "setBlock(Lnet/minecraft/core/BlockPos;Lnet/minecraft/world/level/block/state/BlockState;II)Z", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedSet(BlockPos position, BlockState state, int flags, int recursion, CallbackInfoReturnable<Boolean> callback) {
        var view = DetachedBlockView.active((Level) (Object) this);
        if (view != null) callback.setReturnValue(view.set(position, state));
    }
    @Inject(method = "removeBlock", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedRemove(BlockPos position, boolean moving, CallbackInfoReturnable<Boolean> callback) {
        var view = DetachedBlockView.active((Level) (Object) this);
        if (view != null) callback.setReturnValue(view.set(position, Blocks.AIR.defaultBlockState()));
    }
    @Inject(method = "setBlockEntity", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedSetEntity(BlockEntity entity, CallbackInfo callback) {
        if (DetachedBlockView.active((Level) (Object) this) != null) callback.cancel();
    }
    @Inject(method = "removeBlockEntity", at = @At("HEAD"), cancellable = true)
    private void garrycraft$detachedRemoveEntity(BlockPos position, CallbackInfo callback) {
        if (DetachedBlockView.active((Level) (Object) this) != null) callback.cancel();
    }
}
