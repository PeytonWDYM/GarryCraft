package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceNavigation;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.pathfinder.PathfindingContext;
import net.minecraft.world.level.pathfinder.PathType;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(PathfindingContext.class)
public abstract class SourcePathMixin {
    @Inject(method = "getPathTypeFromState", at = @At("RETURN"), cancellable = true)
    private void garrycraft$terrain(int x, int y, int z, CallbackInfoReturnable<PathType> result) {
        if (result.getReturnValue() == PathType.OPEN && SourceNavigation.blocked(new BlockPos(x, y, z))) result.setReturnValue(PathType.BLOCKED);
    }
}
