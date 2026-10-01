package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceSurface;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.BaseTorchBlock;
import net.minecraft.world.level.block.state.BlockState;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(BaseTorchBlock.class)
public abstract class SourceTorchMixin {
    @Inject(method = "canSurvive", at = @At("RETURN"), cancellable = true)
    private void garrycraft$floor(BlockState state, LevelReader level, BlockPos pos, CallbackInfoReturnable<Boolean> result) {
        if (!result.getReturnValue() && SourceSurface.supportsFace(pos.below(), Direction.UP)) result.setReturnValue(true);
    }
}
