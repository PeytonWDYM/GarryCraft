package dev.garrycraft.physics;

import java.util.ArrayList;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.phys.AABB;

/** Surface queries use the imported collision mesh. They do not create a second movement implementation. */
public final class SourceSurface {
    private SourceSurface() {}
    public static boolean active() { return SourceWorld.active; }
    public static boolean isKnown(int x, int y, int z) { return SourceWorld.COLLISION.acknowledged() >= 0; }
    public static boolean hasGeometry(BlockPos pos) {
        var triangles = new ArrayList<Triangle>();
        SourceWorld.COLLISION.trianglesNear(new AABB(pos), triangles);
        return !triangles.isEmpty();
    }
    public static float groundTop(BlockPos pos) {
        var triangles = new ArrayList<Triangle>();
        SourceWorld.COLLISION.trianglesNear(new AABB(pos), triangles);
        double top = pos.getY();
        for (var triangle : triangles) top = Math.max(top,
            triangle.highestWithin(pos.getX(), pos.getX() + 1, pos.getZ(), pos.getZ() + 1, pos.getY() + 1));
        return (float) Math.clamp(top - pos.getY(), 0, 1);
    }
    /** Tests the actual supporting face near a grid boundary. Navigation and attachment use this query. */
    public static boolean supportsFace(BlockPos cell, Direction face) {
        if (!active()) return false;
        var center = Vec3.atCenterOf(cell).add(face.getStepX() * .5, face.getStepY() * .5, face.getStepZ() * .5);
        // Native walls can cross the placement cell instead of its grid boundary.
        var offset = new Vec3(face.getStepX() * 1.001, face.getStepY() * 1.001, face.getStepZ() * 1.001);
        var from = center.add(offset); var to = center.subtract(offset);
        var triangles = new ArrayList<Triangle>();
        SourceWorld.COLLISION.trianglesNear(new AABB(from, to).inflate(.02), triangles);
        var hit = SourceRay.cast(triangles, from.x, from.y, from.z, to.x, to.y, to.z);
        return hit != null && hit.nx() * face.getStepX() + hit.ny() * face.getStepY() + hit.nz() * face.getStepZ() > .5;
    }
    public static float fluidHeight(BlockPos pos, float height) {
        float ground = Math.min(.999f, groundTop(pos) + .002f);
        return ground + height * (1 - ground);
    }
}
