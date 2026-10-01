package dev.garrycraft.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import dev.garrycraft.physics.SourceSurface;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.block.FireBlock;
import net.minecraft.world.level.block.state.BlockState;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

/** Native floors support vanilla fire placement, neighbor updates, and scheduled fire ticks. */
@Mixin(FireBlock.class)
public abstract class SourceFireSupportMixin {
    @WrapOperation(method = {"getStateForPlacement", "canSurvive", "tick"}, at = @At(value = "INVOKE",
        target = "Lnet/minecraft/world/level/block/state/BlockState;isFaceSturdy(Lnet/minecraft/world/level/BlockGetter;Lnet/minecraft/core/BlockPos;Lnet/minecraft/core/Direction;)Z"))
    private boolean garrycraft$fireSupport(BlockState state, BlockGetter level, BlockPos pos, Direction face, Operation<Boolean> original) {
        return original.call(state, level, pos, face) || SourceSurface.supportsFace(pos, face);
    }
}
