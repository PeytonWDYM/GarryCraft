package dev.garrycraft.physics;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import net.minecraft.world.phys.AABB;

/** Indexes immutable mesh snapshots by 16-block cells for movement, fluid, and projectile queries. */
final class TriangleIndex {
    private record Cell(int x, int y, int z) {}
    private final Map<Cell, List<Triangle>> cells = new HashMap<>();
    TriangleIndex(List<Triangle> triangles) {
        for (var triangle : triangles) {
            for (int x = cell(triangle.minX); x <= cell(triangle.maxX); x++)
                for (int y = cell(triangle.minY); y <= cell(triangle.maxY); y++)
                    for (int z = cell(triangle.minZ); z <= cell(triangle.maxZ); z++)
                        cells.computeIfAbsent(new Cell(x, y, z), ignored -> new ArrayList<>()).add(triangle);
        }
    }
    private static int cell(double point) { return (int) Math.floor(point / 16); }
    void nearby(AABB box, Set<Triangle> output) {
        for (int x = cell(box.minX); x <= cell(box.maxX); x++)
            for (int y = cell(box.minY); y <= cell(box.maxY); y++)
                for (int z = cell(box.minZ); z <= cell(box.maxZ); z++) {
                    var triangles = cells.get(new Cell(x, y, z));
                    if (triangles == null) continue;
                    for (var triangle : triangles)
                        if (triangle.maxX >= box.minX && triangle.minX <= box.maxX
                                && triangle.maxY >= box.minY && triangle.minY <= box.maxY
                                && triangle.maxZ >= box.minZ && triangle.minZ <= box.maxZ) output.add(triangle);
                }
    }
}
