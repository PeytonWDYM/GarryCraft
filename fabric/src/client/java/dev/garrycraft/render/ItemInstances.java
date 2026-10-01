package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import net.minecraft.client.renderer.item.ItemStackRenderState;
import net.minecraft.client.resources.model.geometry.ItemQuads;
import net.minecraft.world.item.ItemDisplayContext;

/** Captures Minecraft's item transforms while retaining one host mesh for each unchanged item model. */
final class ItemInstances extends ModelCollector {
    record Model(int id, List<ModelCollector.Batch> batches) {}
    record Instance(int model, float[] transform) {}
    private record Key(ItemQuads quads, List<Integer> tints) {}
    private static final Map<Key, Model> MODELS = new LinkedHashMap<>();
    private static int sequence;
    private final Map<Integer, Model> used = new LinkedHashMap<>();
    private final List<Instance> instances = new ArrayList<>();
    static void reset() { MODELS.clear(); sequence = 0; }
    List<Model> models() { return List.copyOf(used.values()); }
    List<Instance> instances() { return List.copyOf(instances); }

    @Override public void submitItem(PoseStack pose, ItemDisplayContext context, int light, int overlay, int outline,
            int[] tints, ItemQuads quads, ItemStackRenderState.FoilType foil) {
        var key = new Key(quads, Arrays.stream(tints).boxed().toList());
        var model = MODELS.computeIfAbsent(key, ignored -> {
            var collector = new ModelCollector();
            collector.submitItem(new PoseStack(), context, light, overlay, outline, tints, quads, foil);
            return new Model(++sequence, collector.finish());
        });
        used.put(model.id(), model);
        var matrix = pose.last().pose();
        float[] transform = new float[12];
        int[] axes = {0, 2, 1}, signs = {1, -1, 1};
        for (int row = 0; row < 3; row++) {
            for (int column = 0; column < 3; column++)
                transform[row * 4 + column] = signs[row] * signs[column] * matrix.get(axes[column], axes[row]);
            transform[row * 4 + 3] = 32 * signs[row] * matrix.get(3, axes[row]);
        }
        instances.add(new Instance(model.id(), transform));
    }
}
