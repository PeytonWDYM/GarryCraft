package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceSurface;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.WallTorchBlock;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(WallTorchBlock.class)
public abstract class SourceWallTorchMixin {
    @Inject(method = "canSurvive(Lnet/minecraft/world/level/LevelReader;Lnet/minecraft/core/BlockPos;Lnet/minecraft/core/Direction;)Z",
        at = @At("RETURN"), cancellable = true)
    private static void garrycraft$wall(LevelReader level, BlockPos pos, Direction facing, CallbackInfoReturnable<Boolean> result) {
        if (!result.getReturnValue() && SourceSurface.supportsFace(pos.relative(facing.getOpposite()), facing)) result.setReturnValue(true);
    }
}
