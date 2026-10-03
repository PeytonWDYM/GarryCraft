package dev.garrycraft.render;

import com.mojang.blaze3d.vertex.PoseStack;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.player.PlayerModel;
import net.minecraft.client.resources.model.geometry.ItemQuads;
import org.joml.Matrix4f;

/** Source uses installed item models. Minecraft supplies the held-item pose and the player's actual skin arms. */
final class NativeItems {
    record Item(String model, float[] transform) {}
    record Arms(List<ModelCollector.Batch> left, List<ModelCollector.Batch> right) {}
    private NativeItems() {}

    static boolean physicsGun(ItemQuads quads) {
        return quads.all().stream().anyMatch(quad ->
            quad.materialInfo().sprite().contents().name().toString().equals("garrycraft:item/physics_gun"));
    }

    static Item physicsGun(Matrix4f pose) {
        float[] transform = new float[12];
        int[] axes = {0, 2, 1}, signs = {1, -1, 1};
        for (int row = 0; row < 3; row++) {
            for (int column = 0; column < 3; column++)
                transform[row * 4 + column] = signs[row] * signs[column] * pose.get(axes[column], axes[row]);
            transform[row * 4 + 3] = 32 * signs[row] * pose.get(3, axes[row]);
        }
        return new Item("models/weapons/w_physics.mdl", transform);
    }

    static Arms arms(PlayerModel model, int texture, int light, int overlay, int tint) {
        return new Arms(arm(model.leftArm, texture, light, overlay, tint),
            arm(model.rightArm, texture, light, overlay, tint));
    }

    private static List<ModelCollector.Batch> arm(ModelPart arm, int texture, int light, int overlay, int tint) {
        var vertices = new ArrayList<VertexCapture.Vertex>();
        var capture = new VertexCapture();
        capture.begin(vertices);
        var animation = arm.storePose();
        arm.loadPose(net.minecraft.client.model.geom.PartPose.ZERO);
        // Sleeves are children in this Minecraft version. The arm renders each skin layer once.
        arm.render(new PoseStack(), capture, light, overlay, tint);
        arm.loadPose(animation);
        capture.flush();
        var triangles = VertexCapture.triangles(vertices);
        float minX = Float.POSITIVE_INFINITY, maxX = Float.NEGATIVE_INFINITY;
        float minZ = Float.POSITIVE_INFINITY, maxZ = Float.NEGATIVE_INFINITY, maxY = Float.NEGATIVE_INFINITY;
        for (var vertex : triangles) {
            minX = Math.min(minX, vertex[0]); maxX = Math.max(maxX, vertex[0]);
            minZ = Math.min(minZ, vertex[2]); maxZ = Math.max(maxZ, vertex[2]); maxY = Math.max(maxY, vertex[1]);
        }
        for (var vertex : triangles) {
            float width = vertex[0] - (minX + maxX) / 2;
            vertex[0] = vertex[1] - maxY;
            // Preserve handedness while turning Minecraft's downward arm axis into the native bone's forward axis.
            vertex[1] = -width;
            vertex[2] -= (minZ + maxZ) / 2;
        }
        return List.of(new ModelCollector.Batch(texture, triangles));
    }
}
