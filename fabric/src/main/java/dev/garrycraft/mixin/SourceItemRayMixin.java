package dev.garrycraft.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import dev.garrycraft.physics.SourceClip;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.BlockHitResult;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

/** Buckets ray cast independently of the crosshair and offset their hit cell before placement. */
@Mixin(Item.class)
public abstract class SourceItemRayMixin {
    @WrapOperation(method = "getPlayerPOVHitResult", at = @At(value = "INVOKE",
        target = "Lnet/minecraft/world/level/Level;clip(Lnet/minecraft/world/level/ClipContext;)Lnet/minecraft/world/phys/BlockHitResult;"))
    private static BlockHitResult garrycraft$itemRay(Level level, ClipContext context, Operation<BlockHitResult> original) {
        var hit = SourceClip.refine(context.getFrom(), context.getTo(), original.call(level, context), SourceClip.Use.PICK);
        if (hit instanceof SourceClip.HostHit) return new SourceClip.HostHit(hit.getLocation(), hit.getDirection(),
            hit.getBlockPos().relative(hit.getDirection().getOpposite()));
        return hit;
    }
}
