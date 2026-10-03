package dev.garrycraft.render;

import java.util.ArrayList;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.state.level.QuadParticleRenderState;
import net.minecraft.client.renderer.texture.TextureAtlas;
import dev.garrycraft.testing.ParityOracle;

/** Captures Minecraft's particle billboards after interpolation and camera rotation. */
final class ParticleExporter {
    private ParticleExporter() {}
    static List<ModelCollector.Batch> frame(Minecraft mc) {
        var state = mc.gameRenderer.gameRenderState().levelRenderState;
        var origin = state.cameraRenderState.pos;
        var result = new ArrayList<ModelCollector.Batch>();
        // Upload the complete particle atlas before an explosion needs its short-lived sprite frames.
        int particleTexture = Textures.resource(TextureAtlas.LOCATION_PARTICLES);
        int debris = 0;
        for (var group : state.particlesRenderState.particles) {
            if (!(group instanceof QuadParticleRenderState quads)) continue;
            for (var layer : quads.layers()) {
                var vertices = new ArrayList<VertexCapture.Vertex>();
                var capture = new VertexCapture();
                capture.begin(vertices);
                quads.buildLayer(layer, capture);
                capture.flush();
                if (layer.textureAtlasLocation().equals(TextureAtlas.LOCATION_PARTICLES)) {
                    var absolute = new ArrayList<VertexCapture.Vertex>(vertices.size());
                    for (var vertex : vertices) absolute.add(new VertexCapture.Vertex(
                        vertex.x() + (float) origin.x, vertex.y() + (float) origin.y, vertex.z() + (float) origin.z,
                        vertex.u(), vertex.v(), vertex.color()));
                    result.add(new ModelCollector.Batch(particleTexture, VertexCapture.triangles(absolute), layer.translucent(), true));
                } else {
                    var terrain = AtlasQuads.convert(vertices, layer.textureAtlasLocation(),
                        (float) origin.x, (float) origin.y, (float) origin.z, layer.translucent());
                    for (var batch : terrain) result.add(new ModelCollector.Batch(batch.texture(), batch.vertices(), batch.translucent(), true));
                    if (layer.textureAtlasLocation().equals(TextureAtlas.LOCATION_BLOCKS)) debris += terrain.stream().mapToInt(batch -> batch.vertices().size()).sum();
                }
            }
        }
        ParityOracle.particles(result.stream().mapToInt(batch -> batch.vertices().size()).sum());
        dev.garrycraft.testing.ParticleReloadOracle.particles(debris);
        dev.garrycraft.testing.TerrainUseOracle.effects(0, debris);
        return result;
    }
}
