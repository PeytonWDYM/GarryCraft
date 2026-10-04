package dev.garrycraft.physics;

import it.unimi.dsi.fastutil.longs.Long2ObjectOpenHashMap;
import java.util.ArrayList;
import net.minecraft.core.BlockPos;
import net.minecraft.world.phys.AABB;

/** Supplies terrain classification and exact floor heights to Minecraft's existing pathfinder. */
public final class SourceNavigation {
    private record Cell(boolean blocked, double floor) {}
    private static final class Cache {
        final Long2ObjectOpenHashMap<Cell> cells = new Long2ObjectOpenHashMap<>();
        long revision = -1;
    }
    // The integrated server and client can query navigation. Fastutil maps need one owner.
    private static final ThreadLocal<Cache> CACHE = ThreadLocal.withInitial(Cache::new);
    private SourceNavigation() {}
    private static Cell cell(BlockPos pos) {
        long current = SourceWorld.COLLISION.revision();
        var cache = CACHE.get();
        if (cache.revision != current) { cache.revision = current; cache.cells.clear(); }
        long key = pos.asLong();
        var cached = cache.cells.get(key);
        if (cached != null) return cached;
        if (cache.cells.size() >= 65536) cache.cells.clear();
        var triangles = new ArrayList<Triangle>();
        SourceWorld.COLLISION.staticTrianglesNear(new AABB(pos).inflate(.01, 1, .01), triangles);
        double x = pos.getX() + .5, z = pos.getZ() + .5;
        var hit = SourceRay.cast(triangles, x, pos.getY() + .5, z, x, pos.getY() - 1.25, z);
        double floor = hit != null && hit.ny() > .5 ? hit.y() : Double.NaN;
        boolean blocked = false;
        for (var triangle : triangles) {
            if (triangle.sourceEntity != 0 || triangle.stairHelper) continue;
            if (Math.abs(triangle.ny) < .5 && triangle.minY < pos.getY() + .9 && triangle.maxY > pos.getY() + .1
                    && triangle.minX < pos.getX() + .9 && triangle.maxX > pos.getX() + .1
                    && triangle.minZ < pos.getZ() + .9 && triangle.maxZ > pos.getZ() + .1) blocked = true;
        }
        // The floor cell is blocked. The cell containing feet remains walkable, including tiny trace offsets.
        var upper = SourceRay.cast(triangles, x, pos.getY() + 1.08, z, x, pos.getY() + .08, z);
        if (upper != null && upper.ny() > .5) blocked = true;
        var result = new Cell(blocked, floor); cache.cells.put(key, result); return result;
    }
    public static boolean blocked(BlockPos pos) {
        if (!SourceWorld.active) return false;
        if (cell(pos).blocked()) return true;
        var volume = new AABB(pos).deflate(.1);
        for (var actor : SourceWorld.COLLISION.actors()) {
            if (actor.npc()) continue;
            double half = actor.width() * .5;
            if (volume.intersects(actor.x() - half, actor.y(), actor.z() - half,
                    actor.x() + half, actor.y() + actor.height(), actor.z() + half)) return true;
        }
        return false;
    }
    public static double floor(BlockPos pos) { return SourceWorld.active ? cell(pos).floor() : Double.NaN; }
}
