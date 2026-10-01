package dev.garrycraft.render;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import net.minecraft.resources.Identifier;

/** Splits atlas UVs into small sprite textures, including terrain and particle fragments. */
final class AtlasQuads {
    private AtlasQuads() {}
    static List<ModelCollector.Batch> convert(List<VertexCapture.Vertex> quads, Identifier atlas,
            float x, float y, float z, boolean translucent) {
        var batches = new LinkedHashMap<Integer, List<VertexCapture.Vertex>>();
        for (int first = 0; first + 4 <= quads.size(); first += 4) {
            float u = 0, v = 0;
            for (int i = 0; i < 4; i++) { u += quads.get(first + i).u() / 4; v += quads.get(first + i).v() / 4; }
            var sprite = Textures.spriteAt(atlas, u, v);
            var vertices = batches.computeIfAbsent(Textures.sprite(sprite), ignored -> new ArrayList<>());
            for (int i = 0; i < 4; i++) {
                var vertex = quads.get(first + i);
                vertices.add(new VertexCapture.Vertex(vertex.x() + x, vertex.y() + y, vertex.z() + z,
                    (vertex.u() - sprite.getU0()) / (sprite.getU1() - sprite.getU0()),
                    (vertex.v() - sprite.getV0()) / (sprite.getV1() - sprite.getV0()), vertex.color()));
            }
        }
        var result = new ArrayList<ModelCollector.Batch>();
        batches.forEach((texture, vertices) -> result.add(new ModelCollector.Batch(texture, VertexCapture.triangles(vertices), translucent)));
        return result;
    }
}
