package dev.garrycraft.render;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.List;
import java.util.ArrayList;

/** Packs RGBA vertices on the transport thread. Lua reads only the small metadata header. */
final class MeshPackets {
    private record Mesh(int texture, boolean translucent, boolean unlit, int tint, int offset, int count, float x, float y, float z) {}
    private record Group(long revision, List<Mesh> batches) {}
    private record ItemModel(int id, List<Mesh> batches) {}
    private record PhysicsBlockModel(long id, List<Mesh> batches) {}
    private record PhysicsBlocks(long revision, List<PhysicsBlockModel> models, List<Integer> destructionTextures) {}
    private record SceneHeader(String session, String instance, int camera, float handFov,
        Group avatar, Group hands, Group particles, Group entities, Group cracks, List<double[]> selection,
        List<ItemModel> itemModels, List<ItemInstances.Instance> items, List<NativeItems.Item> nativeItems,
        Group leftArm, Group rightArm, PhysicsBlocks physicsBlocks) {}
    private record SectionHeader(String session, String instance, long sequence, String key, boolean clear,
        List<Mesh> meshes, List<double[]> boxes, List<WorldExporter.Light> lights, List<double[]> occluders) {}
    private final ByteBuffer body;
    private MeshPackets(int vertices) { body = ByteBuffer.allocate(Math.multiplyExact(vertices, 24)).order(ByteOrder.LITTLE_ENDIAN); }
    private static int count(List<ModelCollector.Batch> batches) { return batches.stream().mapToInt(batch -> batch.vertices().size()).sum(); }
    private List<Mesh> meshes(List<ModelCollector.Batch> batches) {
        return meshes(batches, false);
    }
    private List<Mesh> meshes(List<ModelCollector.Batch> batches, boolean sortFaces) {
        var result = new ArrayList<Mesh>();
        for (var batch : batches) {
            // Persistent face meshes let Source sort glass and water without rebuilding geometry during camera movement.
            int limit = sortFaces && batch.translucent() ? 6 : 65532;
            for (int first = 0; first < batch.vertices().size(); first += limit) {
                int end = Math.min(first + limit, batch.vertices().size()), offset = body.position();
                float x = 0, y = 0, z = 0;
                for (int index = first; index < end; index++) {
                    var vertex = batch.vertices().get(index);
                    x += vertex[0]; y += vertex[1]; z += vertex[2];
                    for (int i = 0; i < 5; i++) body.putFloat(vertex[i]);
                    for (int i = 5; i < 9; i++) body.put((byte) vertex[i]);
                }
                int count = end - first;
                // VertexLitGeneric ignores vertex colors. Each water face supplies its Minecraft biome tint as a material color.
                var color = batch.vertices().get(first);
                int tint = batch.materialTint() ? (int) color[5] << 16 | (int) color[6] << 8 | (int) color[7] : 0xFFFFFF;
                result.add(new Mesh(batch.texture(), batch.translucent(), batch.unlit(), tint, offset, count, x / count, y / count, z / count));
            }
        }
        return result;
    }
    private Group group(MeshSnapshots.Snapshot snapshot) { return new Group(snapshot.revision(), meshes(snapshot.batches())); }
    static byte[] scene(AvatarExporter.Scene scene) {
        var groups = List.of(scene.avatar(), scene.hands(), scene.particles(), scene.entities(), scene.cracks(), scene.leftArm(), scene.rightArm());
        var packet = new MeshPackets(groups.stream().mapToInt(group -> count(group.batches())).sum()
            + scene.itemModels().stream().mapToInt(model -> count(model.batches())).sum()
            + scene.physicsBlocks().models().stream().mapToInt(model -> count(model.batches())).sum());
        var header = new SceneHeader(scene.session(), scene.instance(), scene.camera(), scene.handFov(),
            packet.group(scene.avatar()), packet.group(scene.hands()), packet.group(scene.particles()),
            packet.group(scene.entities()), packet.group(scene.cracks()), scene.selection(),
            scene.itemModels().stream().map(model -> new ItemModel(model.id(), packet.meshes(model.batches()))).toList(), scene.items(),
            scene.nativeItems(), packet.group(scene.leftArm()), packet.group(scene.rightArm()),
            new PhysicsBlocks(scene.physicsBlocks().revision(), scene.physicsBlocks().models().stream()
                .map(model -> new PhysicsBlockModel(model.id(), packet.meshes(model.batches()))).toList(),
                scene.physicsBlocks().destructionTextures()));
        return RenderTransport.packet(header, packet.body.array());
    }
    static byte[] section(WorldExporter.Section section) {
        var packet = new MeshPackets(count(section.meshes()));
        var header = new SectionHeader(section.session(), section.instance(), section.sequence(), section.key(), section.clear(),
            packet.meshes(section.meshes(), true), section.boxes(), section.lights(), section.occluders());
        return RenderTransport.packet(header, packet.body.array());
    }
}
