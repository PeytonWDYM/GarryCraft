// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.mixin;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import dev.garrycraft.physics.SourceClip;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.BlockHitResult;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

/**
 * The crosshair targets Source surfaces: blocks can be placed on terrain and walls, and NPCs behind a
 * wall can't be hit through it. A Source hit points at the cell a placed block would occupy.
 */
@Mixin(Entity.class)
public abstract class SourceEntityPickMixin {
	@WrapOperation(
		method = "pick",
		at = @At(value = "INVOKE", target = "Lnet/minecraft/world/level/Level;clip(Lnet/minecraft/world/level/ClipContext;)Lnet/minecraft/world/phys/BlockHitResult;")
	)
	private BlockHitResult garrycraft$pickSource(Level level, ClipContext context, Operation<BlockHitResult> original) {
		return SourceClip.refine(context.getFrom(), context.getTo(), original.call(level, context), SourceClip.Use.PICK);
	}
}
