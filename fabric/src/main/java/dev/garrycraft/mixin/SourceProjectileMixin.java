// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceClip;
import net.minecraft.world.entity.projectile.Projectile;
import net.minecraft.world.entity.projectile.ProjectileDeflection;
import net.minecraft.world.phys.HitResult;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * Minecraft ignores projectile hits on air, and to Minecraft a Source wall is air. Treat a hit on
 * Source geometry as a real hit: arrows stick in it, snowballs and eggs break on it.
 */
@Mixin(Projectile.class)
public abstract class SourceProjectileMixin {
	@Shadow
	protected abstract void onHit(HitResult hitResult);

	@Inject(method = "hitTargetOrDeflectSelf", at = @At("HEAD"), cancellable = true)
	private void garrycraft$hitSource(HitResult hitResult, CallbackInfoReturnable<ProjectileDeflection> cir) {
		if (hitResult instanceof SourceClip.HostHit) {
			this.onHit(hitResult);
			cir.setReturnValue(ProjectileDeflection.NONE);
		}
	}
}
