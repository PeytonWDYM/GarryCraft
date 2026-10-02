package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceNavigation;
import dev.garrycraft.physics.SourceWorld;
import net.minecraft.core.BlockPos;
import net.minecraft.world.entity.ai.navigation.PathNavigation;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Random strolls and villager brains use the same support test as commanded ground paths. */
@Mixin(PathNavigation.class)
public abstract class SourceStableDestinationMixin {
    @Inject(method = "isStableDestination", at = @At("RETURN"), cancellable = true)
    private void garrycraft$support(BlockPos pos, CallbackInfoReturnable<Boolean> result) {
        var navigation = (PathNavigation) (Object) this;
        if (SourceWorld.active && navigation.canNavigateGround() && !result.getReturnValue()
                && !SourceNavigation.blocked(pos)) {
            double floor = SourceNavigation.floor(pos);
            if (Double.isFinite(floor) && pos.getY() == (int) Math.ceil(floor - 1e-5)) result.setReturnValue(true);
        }
    }
}
