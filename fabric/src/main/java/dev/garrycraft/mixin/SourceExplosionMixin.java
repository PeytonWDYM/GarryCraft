package dev.garrycraft.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import dev.garrycraft.physics.SourceClip;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.ServerExplosion;
import net.minecraft.world.phys.BlockHitResult;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

/** Source walls also block Minecraft explosion damage. */
@Mixin(ServerExplosion.class)
public abstract class SourceExplosionMixin {
    @WrapOperation(method = "getSeenPercent", at = @At(value = "INVOKE",
        target = "Lnet/minecraft/world/level/Level;clip(Lnet/minecraft/world/level/ClipContext;)Lnet/minecraft/world/phys/BlockHitResult;"))
    private static BlockHitResult garrycraft$wall(Level level, ClipContext context, Operation<BlockHitResult> original) {
        return SourceClip.refine(context.getFrom(), context.getTo(), original.call(level, context), SourceClip.Use.PROJECTILE);
    }
}
