package dev.garrycraft.mixin;

import dev.garrycraft.physics.SourceWorld;
import dev.garrycraft.physics.Triangle;
import dev.garrycraft.physics.TriCollider;
import java.util.ArrayList;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.Vec3;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/** Extends the existing triangle collision to mobs, items, falling blocks, and server entities. */
@Mixin(Entity.class)
public abstract class HostEntityCollisionMixin {
    @Inject(method = "collide", at = @At("RETURN"), cancellable = true)
    private void garrycraft$hostCollision(Vec3 movement, CallbackInfoReturnable<Vec3> callback) {
        var entity = (Entity) (Object) this;
        // The local player already uses SourceCollider, including its Minecraft-block collision pass.
        if (!SourceWorld.active || entity.noPhysics || (entity.level().isClientSide() && entity instanceof net.minecraft.world.entity.player.Player)) return;
        var box = entity.getBoundingBox();
        var move = callback.getReturnValue();
        var triangles = new ArrayList<Triangle>();
        SourceWorld.COLLISION.trianglesNear(box.expandTowards(move).inflate(1, 1 + entity.maxUpStep(), 1), triangles);
        if (triangles.isEmpty()) return;
        var result = TriCollider.resolve(triangles, (box.minX + box.maxX) / 2, box.minY, (box.minZ + box.maxZ) / 2,
            box.getXsize() / 2, box.getYsize(), entity.maxUpStep(), entity.onGround(), move.x, move.y, move.z);
        callback.setReturnValue(Entity.collideBoundingBox(entity, new Vec3(result[0], result[1], result[2]), box, entity.level(), java.util.List.of()));
    }
}
