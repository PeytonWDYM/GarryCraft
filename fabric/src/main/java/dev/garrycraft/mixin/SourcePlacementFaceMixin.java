package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceSurface;
import net.minecraft.core.Direction;
import net.minecraft.world.item.context.BlockPlaceContext;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Give a virtual Source support face the same placement priority as a Minecraft support block. */
@Mixin(BlockPlaceContext.class)
public abstract class SourcePlacementFaceMixin {
    @Inject(method = "getNearestLookingDirections", at = @At("RETURN"))
    private void garrycraft$attachment(CallbackInfoReturnable<Direction[]> result) {
        var context = (BlockPlaceContext) (Object) this;
        var face = context.getClickedFace(); var pos = context.getClickedPos();
        if (!context.getLevel().getBlockState(pos).isAir() || !SourceSurface.supportsFace(pos.relative(face.getOpposite()), face)) return;
        var directions = result.getReturnValue();
        for (int i = 0; i < directions.length; i++) if (directions[i] == face.getOpposite()) {
            System.arraycopy(directions, 0, directions, 1, i);
            directions[0] = face.getOpposite();
            return;
        }
    }
}
