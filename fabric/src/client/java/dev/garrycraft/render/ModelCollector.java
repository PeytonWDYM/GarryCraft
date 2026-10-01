package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import dev.garrycraft.mixin.RenderSetupAccessor;
import dev.garrycraft.mixin.RenderTypeAccessor;
import dev.garrycraft.mixin.TextureBindingAccessor;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import net.fabricmc.fabric.api.client.renderer.v1.mesh.MeshView;
import net.fabricmc.fabric.api.client.renderer.v1.mesh.QuadAtlas;
import net.minecraft.client.model.Model;
import net.minecraft.client.model.geom.builders.UVPair;
import net.minecraft.client.renderer.block.dispatch.BlockStateModelPart;
import net.minecraft.client.renderer.chunk.ChunkSectionLayer;
import net.minecraft.client.renderer.item.ItemStackRenderState;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.texture.TextureAtlas;
import net.minecraft.client.renderer.texture.UvMapping;
import net.minecraft.client.resources.model.geometry.BakedQuad;
import net.minecraft.client.resources.model.geometry.ItemQuads;
import net.minecraft.core.Direction;
import net.minecraft.world.item.ItemDisplayContext;
import org.joml.Matrix4f;
import org.joml.Vector3f;
import org.jspecify.annotations.Nullable;

/** Minecraft's renderers supply animation, skin, armor, and held-item geometry. */
class ModelCollector extends EmptyCollector {
    record Batch(int texture, List<float[]> vertices, boolean translucent, boolean unlit) {
        Batch(int texture, List<float[]> vertices, boolean translucent) { this(texture, vertices, translucent, false); }
        Batch(int texture, List<float[]> vertices) { this(texture, vertices, false); }
    }
    private final Map<Integer, List<VertexCapture.Vertex>> batches = new LinkedHashMap<>();
    private final VertexCapture capture = new VertexCapture();
    private static final Direction[] FACES = {null, Direction.DOWN, Direction.UP, Direction.NORTH, Direction.SOUTH, Direction.WEST, Direction.EAST};

    List<Batch> finish() {
        capture.flush();
        var result = new ArrayList<Batch>();
        batches.forEach((texture, quads) -> {
            var triangles = VertexCapture.triangles(quads);
            if (!triangles.isEmpty()) result.add(new Batch(texture, triangles));
        });
        return result;
    }
    private List<VertexCapture.Vertex> batch(int id) { return batches.computeIfAbsent(id, ignored -> new ArrayList<>()); }

    @Override public <S> void submitModel(Model<? super S> model, S state, PoseStack pose, RenderType renderType,
        int light, int overlay, int tint, @Nullable UvMapping mapping, int outline) {
        var type = (RenderTypeAccessor) renderType;
        String name = type.garrycraft$name();
        if (name.contains("glint") || name.contains("outline") || name.contains("shadow")) return;
        var binding = ((RenderSetupAccessor) (Object) type.garrycraft$state()).garrycraft$textures().get("Sampler0");
        if (binding == null) return;
        int texture = Textures.resource(((TextureBindingAccessor) binding).garrycraft$location());
        if (texture < 0) return;
        capture.begin(batch(texture));
        VertexConsumer consumer = mapping == null ? capture : mapping.wrap(capture);
        model.setupAnim(state);
        model.renderToBuffer(pose, consumer, light, overlay, tint);
        capture.flush();
    }

    private void quad(Matrix4f pose, BakedQuad quad, int[] tints) {
        var material = quad.materialInfo();
        var sprite = material.sprite();
        var vertices = batch(Textures.sprite(sprite));
        int layer = material.isTinted() ? material.tintIndex() : -1;
        int color = layer >= 0 && layer < tints.length ? tints[layer] : -1;
        var position = new Vector3f();
        for (int i = 0; i < 4; i++) {
            pose.transformPosition(quad.position(i), position);
            long uv = quad.packedUV(i);
            float u = (UVPair.unpackU(uv) - sprite.getU0()) / (sprite.getU1() - sprite.getU0());
            float v = (UVPair.unpackV(uv) - sprite.getV0()) / (sprite.getV1() - sprite.getV0());
            vertices.add(new VertexCapture.Vertex(position.x, position.y, position.z, u, v, color));
        }
    }

    @Override public void submitItem(PoseStack pose, ItemDisplayContext context, int light, int overlay, int outline,
        int[] tints, ItemQuads quads, ItemStackRenderState.FoilType foil) {
        capture.flush();
        for (var quad : quads.all()) quad(pose.last().pose(), quad, tints);
    }
    @Override public void submitBlockModel(PoseStack pose, RenderType renderType, List<BlockStateModelPart> parts,
        int[] tints, int light, int overlay, int outline) {
        capture.flush();
        for (var part : parts) for (var face : FACES) for (var quad : part.getQuads(face)) quad(pose.last().pose(), quad, tints);
    }
    @Override public void submitBlockModel(PoseStack pose, Function<ChunkSectionLayer, RenderType> types, boolean translucent,
        List<BlockStateModelPart> parts, net.fabricmc.fabric.api.client.renderer.v1.mesh.@Nullable Mesh mesh,
        int[] tints, int light, int overlay, int outline) {
        submitBlockModel(pose, (RenderType) null, parts, tints, light, overlay, outline);
        mesh(pose.last().pose(), mesh);
    }
    @Override public void submitItem(PoseStack pose, ItemDisplayContext context, int light, int overlay, int outline,
        int[] tints, ItemQuads quads, @Nullable MeshView mesh, ItemStackRenderState.FoilType foil) {
        submitItem(pose, context, light, overlay, outline, tints, quads, foil);
        mesh(pose.last().pose(), mesh);
    }
    private void mesh(Matrix4f pose, @Nullable MeshView mesh) {
        if (mesh == null) return;
        mesh.forEach(quad -> {
            var atlas = quad.atlas() == QuadAtlas.ITEM ? TextureAtlas.LOCATION_ITEMS : TextureAtlas.LOCATION_BLOCKS;
            float centerU = 0, centerV = 0;
            for (int i = 0; i < 4; i++) { centerU += quad.u(i) / 4; centerV += quad.v(i) / 4; }
            var sprite = Textures.spriteAt(atlas, centerU, centerV);
            var vertices = batch(Textures.sprite(sprite));
            var position = new Vector3f();
            for (int i = 0; i < 4; i++) {
                pose.transformPosition(quad.x(i), quad.y(i), quad.z(i), position);
                float u = (quad.u(i) - sprite.getU0()) / (sprite.getU1() - sprite.getU0());
                float v = (quad.v(i) - sprite.getV0()) / (sprite.getV1() - sprite.getV0());
                vertices.add(new VertexCapture.Vertex(position.x, position.y, position.z, u, v, quad.color(i)));
            }
        });
    }

    @Override public void submitCustomGeometry(PoseStack pose, RenderType renderType, net.minecraft.client.renderer.SubmitNodeCollector.CustomGeometryRenderer renderer) {
        capture.flush();
        var binding = ((RenderSetupAccessor) (Object) ((RenderTypeAccessor) renderType).garrycraft$state()).garrycraft$textures().get("Sampler0");
        if (binding == null) return;
        int texture = Textures.resource(((TextureBindingAccessor) binding).garrycraft$location());
        if (texture < 0) return;
        capture.begin(batch(texture));
        renderer.render(pose.last(), capture);
        capture.flush();
    }

    @Override public void submitMovingBlock(PoseStack pose, net.minecraft.client.renderer.block.MovingBlockRenderState state, int outline) {
        var mc = net.minecraft.client.Minecraft.getInstance();
        var renderer = new net.minecraft.client.renderer.block.ModelBlockRenderer(false, true, mc.getBlockColors());
        renderer.tesselateBlock((x, y, z, baked, instance) -> {
            int[] tint = {instance.getColor(0)};
            quad(pose.last().pose(), baked, baked.materialInfo().isTinted() ? tint : new int[0]);
        }, 0, 0, 0, state, state.blockPos, state.blockState,
            mc.getModelManager().getBlockStateModelSet().get(state.blockState), state.blockState.getSeed(state.randomSeedPos));
    }
}
