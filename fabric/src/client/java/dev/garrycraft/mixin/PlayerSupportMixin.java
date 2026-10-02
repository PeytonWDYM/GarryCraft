package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceSurface;
import dev.garrycraft.physics.SourceWorld;
import dev.garrycraft.testing.PhysicsOracle;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.AABB;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Keep vanilla's crouch edge logic. Its support query also sees native Source terrain. */
@Mixin(Player.class)
public abstract class PlayerSupportMixin {
	@Inject(method = "canFallAtLeast", at = @At("RETURN"), cancellable = true)
	private void garrycraft$nativeSupport(double x, double z, double distance, CallbackInfoReturnable<Boolean> result) {
		if (!SourceWorld.active || PhysicsOracle.reference || !result.getReturnValue()) return;
		var box = ((Player) (Object) this).getBoundingBox();
		var support = new AABB(box.minX + x + 1e-7, box.minY - distance - 1e-7, box.minZ + z + 1e-7,
			box.maxX + x - 1e-7, box.minY, box.maxZ + z - 1e-7);
		if (SourceSurface.supports(support)) result.setReturnValue(false);
	}
}
