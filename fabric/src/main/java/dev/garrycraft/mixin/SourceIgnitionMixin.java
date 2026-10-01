package dev.garrycraft.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import dev.garrycraft.physics.SourceSurface;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.item.FlintAndSteelItem;
import net.minecraft.world.item.FireChargeItem;
import net.minecraft.world.item.context.UseOnContext;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

/** A Source crosshair already names the outside placement cell, including after packet serialization. */
@Mixin({FlintAndSteelItem.class, FireChargeItem.class})
public abstract class SourceIgnitionMixin {
    @WrapOperation(method = "useOn", at = @At(value = "INVOKE",
        target = "Lnet/minecraft/core/BlockPos;relative(Lnet/minecraft/core/Direction;)Lnet/minecraft/core/BlockPos;"))
    private BlockPos garrycraft$fireCell(BlockPos pos, Direction face, Operation<BlockPos> original, UseOnContext context) {
        if (context.getLevel().getBlockState(pos).isAir() && SourceSurface.supportsFace(pos.relative(face.getOpposite()), face)) return pos;
        return original.call(pos, face);
    }
}
