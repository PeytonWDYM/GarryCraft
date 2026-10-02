package dev.garrycraft.render;

import java.util.ArrayList;
import java.util.List;

/** Minecraft emits adjacent reverse quads. Source's two-sided material needs only the outward surface. */
final class WaterFaces {
    private WaterFaces() {}
    static List<VertexCapture.Vertex> surfaces(List<VertexCapture.Vertex> quads) {
        var result = new ArrayList<VertexCapture.Vertex>();
        for (int first = 0; first + 4 <= quads.size(); first += 4) {
            result.addAll(quads.subList(first, first + 4));
            if (first + 8 <= quads.size() && reverse(quads, first)) first += 4;
        }
        return result;
    }
    private static boolean reverse(List<VertexCapture.Vertex> quads, int first) {
        for (int i = 0; i < 4; i++) {
            var front = quads.get(first + i);
            var back = quads.get(first + 4 + (4 - i) % 4);
            if (front.x() != back.x() || front.y() != back.y() || front.z() != back.z()) return false;
        }
        return true;
    }
}
