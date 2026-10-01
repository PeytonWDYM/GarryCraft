package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceNavigation;
import dev.garrycraft.physics.SourceWorld;
import net.minecraft.core.BlockPos;
import net.minecraft.world.entity.ai.navigation.GroundPathNavigation;
import net.minecraft.world.level.chunk.LevelChunk;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Keep native floor targets in the walkable cell instead of searching the empty mirror world's entire height. */
@Mixin(GroundPathNavigation.class)
public abstract class SourcePathTargetMixin {
    @Inject(method = "findSurfacePosition", at = @At("HEAD"), cancellable = true)
    private void garrycraft$target(LevelChunk chunk, BlockPos pos, int accuracy, CallbackInfoReturnable<BlockPos> result) {
        if (!SourceWorld.active || !chunk.getBlockState(pos).isAir()) return;
        double floor = SourceNavigation.floor(pos.above());
        if (!Double.isFinite(floor)) floor = SourceNavigation.floor(pos);
        if (Double.isFinite(floor)) result.setReturnValue(new BlockPos(pos.getX(), (int) Math.ceil(floor - 1e-5), pos.getZ()));
    }
}
