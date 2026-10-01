package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceSurface;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.material.FluidState;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Bucket rays use the same raised fluid surface as rendering and entity interaction. */
@Mixin(FluidState.class)
public abstract class SourceFluidShapeMixin {
    @Inject(method = "getShape", at = @At("RETURN"), cancellable = true)
    private void garrycraft$surface(BlockGetter level, BlockPos pos, CallbackInfoReturnable<VoxelShape> result) {
        var fluid = (FluidState) (Object) this;
        if (!SourceSurface.active() || fluid.isEmpty()) return;
        float ground = Math.min(.999f, SourceSurface.groundTop(pos) + .002f);
        result.setReturnValue(Shapes.box(0, ground, 0, 1,
            SourceSurface.fluidHeight(pos, fluid.getHeight(level, pos)), 1));
    }
}
