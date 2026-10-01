package dev.garrycraft.mixin;

import dev.garrycraft.GarryCraftClient;
import dev.garrycraft.testing.PhysicsOracle;
import dev.garrycraft.physics.SourceCollider;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * After vanilla has collided the local player's movement with Minecraft blocks, collide it with
 * Source's exact triangles (smooth slopes instead of voxel stair-steps).
 */
@Mixin(Entity.class)
public abstract class EntityCollisionMixin {
	@Inject(method = "collide", at = @At("RETURN"), cancellable = true)
	private void garrycraft$smoothSourceCollision(Vec3 movement, CallbackInfoReturnable<Vec3> cir) {
		if ((Object) this instanceof LocalPlayer player && GarryCraftClient.linked() && !PhysicsOracle.reference && !player.noPhysics) {
			cir.setReturnValue(SourceCollider.collide(player, cir.getReturnValue()));
		}
	}
}
