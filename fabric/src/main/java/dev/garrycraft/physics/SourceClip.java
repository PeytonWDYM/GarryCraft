// Adapted from SkyCraft, Copyright (c) 2026 chasmlol. MIT license.
package dev.garrycraft.physics;

import java.util.ArrayList;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;

/** Refines vanilla ray casts against Source triangles. The nearest surface wins. */
public final class SourceClip {
    public enum Use { PICK, PROJECTILE }
    public static final class HostHit extends BlockHitResult {
        public HostHit(Vec3 location, Direction face, BlockPos cell) { super(location, face, cell, false); }
    }
    private SourceClip() {}
    public static BlockHitResult refine(Vec3 from, Vec3 to, BlockHitResult vanilla, Use use) {
        if (!SourceWorld.active) return vanilla;
        var triangles = new ArrayList<Triangle>();
        SourceWorld.COLLISION.trianglesNear(new AABB(from, to).inflate(0.01), triangles);
        // Stand-ins must receive entity hits before their Source movement hull becomes a wall hit.
        triangles.removeIf(triangle -> triangle.sourceEntity != 0);
        var hit = SourceRay.cast(triangles, from.x, from.y, from.z, to.x, to.y, to.z);
        if (hit == null) return vanilla;
        var point = new Vec3(hit.x(), hit.y(), hit.z());
        if (vanilla.getType() != HitResult.Type.MISS && from.distanceToSqr(vanilla.getLocation()) <= from.distanceToSqr(point)) return vanilla;
        int[] cell = use == Use.PICK ? SourceRay.placementCell(hit) : SourceRay.surfaceCell(hit);
        return new HostHit(point, Direction.values()[SourceRay.dominantFace(hit.nx(), hit.ny(), hit.nz())], new BlockPos(cell[0], cell[1], cell[2]));
    }
}
