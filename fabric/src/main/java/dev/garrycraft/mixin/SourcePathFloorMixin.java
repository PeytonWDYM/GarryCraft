package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceNavigation;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.pathfinder.WalkNodeEvaluator;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(WalkNodeEvaluator.class)
public abstract class SourcePathFloorMixin {
    @Inject(method = "getFloorLevel(Lnet/minecraft/world/level/BlockGetter;Lnet/minecraft/core/BlockPos;)D",
        at = @At("RETURN"), cancellable = true)
    private static void garrycraft$floor(BlockGetter level, BlockPos pos, CallbackInfoReturnable<Double> result) {
        double floor = SourceNavigation.floor(pos);
        if (Double.isFinite(floor)) result.setReturnValue(Math.max(result.getReturnValue(), floor));
    }
}
