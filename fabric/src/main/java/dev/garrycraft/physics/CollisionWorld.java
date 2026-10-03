package dev.garrycraft.physics;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import dev.garrycraft.combat.SourceCombat;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import net.minecraft.world.phys.AABB;

/** Publishes immutable collision generations. The geometry worker owns decoding and index construction. */
public final class CollisionWorld {
    private static final TriangleIndex EMPTY = new TriangleIndex(List.of());
    private record Body(int entity, int creation, int part) {}
    private record BodyMesh(int shape, float[] local, float[] matrix, double gridHeight,
                            TriangleIndex index, List<Triangle> triangles) {}
    private record Snapshot(String session, TriangleIndex terrain, MovingGeometry moving, int acknowledged, long revision) {}
    public record StaticGeometry(String session, TriangleIndex terrain, int acknowledged) {}
    public record BodyTrace(int entity, int creation, int part, List<float[]> triangles) {}
    public record MovingTrace(int instances, int triangles, int rebuilt, double milliseconds,
                              List<BodyTrace> bodies, List<SourceCombat.Actor> actors) {}
    public record MovingGeometry(String session, Map<Body, BodyMesh> bodies, List<SourceCombat.Actor> actors,
                                 JsonObject water, int acknowledged, MovingTrace trace) {}
    private volatile Snapshot snapshot = new Snapshot("", EMPTY, null, -1, 0);

    public void reset(String session) {
        snapshot = new Snapshot(session, EMPTY, null, -1, snapshot.revision() + 1);
        SourceWater.clear();
    }

    public int acknowledged() { return snapshot.acknowledged(); }
    public long revision() { return snapshot.revision(); }
    public int shapeAcknowledged() { var moving = snapshot.moving(); return moving == null ? 0 : moving.acknowledged(); }
    public MovingTrace movingTrace() { var moving = snapshot.moving(); return moving == null ? null : moving.trace(); }
    public List<SourceCombat.Actor> actors() { var moving = snapshot.moving(); return moving == null ? List.of() : moving.actors(); }

    public void accept(StaticGeometry geometry) {
        var current = snapshot;
        if (!current.session().equals(geometry.session())) return;
        snapshot = new Snapshot(current.session(), geometry.terrain(), current.moving(), geometry.acknowledged(),
            current.revision() + (current.terrain() == geometry.terrain() ? 0 : 1));
    }

    public void accept(MovingGeometry geometry) {
        var current = snapshot;
        if (!current.session().equals(geometry.session())) return;
        snapshot = new Snapshot(current.session(), current.terrain(), geometry, current.acknowledged(), current.revision());
        SourceWater.refresh(geometry.water());
    }

    public void trianglesNear(AABB region, List<Triangle> output) {
        var current = snapshot;
        var found = new LinkedHashSet<Triangle>();
        current.terrain().nearby(region, found);
        if (current.moving() != null) for (var body : current.moving().bodies().values()) body.index().nearby(region, found);
        output.addAll(found);
    }

    public void staticTrianglesNear(AABB region, List<Triangle> output) {
        var current = snapshot;
        var found = new LinkedHashSet<Triangle>();
        current.terrain().nearby(region, found);
        output.addAll(found);
    }

    /** One worker retains only shapes and instances from its latest complete snapshot. */
    public static final class Decoder {
        private String session = "";
        private final Map<Integer, float[]> shapes = new HashMap<>();
        private Map<Body, BodyMesh> bodies = Map.of();
        private final List<Triangle> pendingStatic = new ArrayList<>();
        private int nextBatch;
        private TriangleIndex terrain = EMPTY;

        private void session(String next) {
            if (session.equals(next)) return;
            session = next;
            shapes.clear();
            bodies = Map.of();
            pendingStatic.clear();
            nextBatch = 0;
            terrain = EMPTY;
        }

        public StaticGeometry staticGeometry(JsonObject message) {
            session(message.get("session").getAsString());
            int batch = message.get("batch").getAsInt();
            if (batch != nextBatch) return new StaticGeometry(session, terrain, nextBatch - 1);
            for (var element : message.getAsJsonArray("triangles")) {
                var values = element.getAsJsonArray();
                float[] vertices = new float[9];
                for (int i = 0; i < 9; i++) vertices[i] = values.get(i).getAsFloat();
                pendingStatic.add(new Triangle(vertices, 0, 0));
            }
            nextBatch++;
            if (batch == message.get("total").getAsInt() - 1) {
                terrain = new TriangleIndex(pendingStatic);
                pendingStatic.clear();
            }
            return new StaticGeometry(session, terrain, batch);
        }

        public MovingGeometry movingGeometry(byte[] payload, String expectedSession) {
            long started = System.nanoTime();
            int boundary = 0;
            while (boundary < payload.length && payload[boundary] != '\n') boundary++;
            // A previous installation can leave a JSON-only mailbox snapshot.
            if (boundary == payload.length) return null;
            var header = JsonParser.parseString(new String(payload, 0, boundary, StandardCharsets.UTF_8)).getAsJsonObject();
            if (!header.get("session").getAsString().equals(expectedSession)) return null;
            if (header.get("movingGeometry").getAsInt() != 2) throw new IllegalStateException("Unsupported moving geometry protocol");
            session(header.get("session").getAsString());
            double gridHeight = header.get("gridHeight").getAsDouble();
            var bytes = ByteBuffer.wrap(payload, boundary + 1, payload.length - boundary - 1).slice().order(ByteOrder.LITTLE_ENDIAN);
            int shapeCount = bytes.getInt(), instanceCount = bytes.getInt(), acknowledged = bytes.getInt();
            int actorCount = bytes.getInt();
            if (shapeCount < 0 || instanceCount < 0 || instanceCount > bytes.remaining() / 64
                || actorCount < 0 || actorCount > bytes.remaining() / 49)
                throw new IllegalStateException("Invalid moving geometry counts");
            for (int index = 0; index < shapeCount; index++) {
                int id = bytes.getInt(), count = bytes.getInt();
                if (count < 0 || count % 3 != 0 || count > bytes.remaining() / 12)
                    throw new IllegalStateException("Invalid collision shape length");
                float[] vertices = new float[count * 3];
                for (int vertex = 0; vertex < vertices.length; vertex++) vertices[vertex] = bytes.getFloat();
                var previous = shapes.get(id);
                if (previous == null || !Arrays.equals(previous, vertices)) shapes.put(id, vertices);
            }
            Map<Body, BodyMesh> next = new HashMap<>();
            var activeShapes = new HashSet<Integer>();
            int rebuilt = 0, triangleCount = 0;
            for (int index = 0; index < instanceCount; index++) {
                var key = new Body(bytes.getInt(), bytes.getInt(), bytes.getInt());
                int shape = bytes.getInt();
                float[] matrix = new float[12];
                for (int component = 0; component < matrix.length; component++) matrix[component] = bytes.getFloat();
                var local = shapes.get(shape);
                if (local == null) throw new IllegalStateException("Missing collision shape " + shape);
                activeShapes.add(shape);
                var body = bodies.get(key);
                if (body == null || body.shape() != shape || body.local() != local || body.gridHeight() != gridHeight
                    || !Arrays.equals(body.matrix(), matrix)) {
                    var triangles = transform(local, matrix, gridHeight, key.entity());
                    body = new BodyMesh(shape, local, matrix, gridHeight, new TriangleIndex(triangles), triangles);
                    rebuilt++;
                }
                triangleCount += body.triangles().size();
                next.put(key, body);
            }
            List<SourceCombat.Actor> actors = new ArrayList<>(actorCount);
            for (int index = 0; index < actorCount; index++) {
                int id = bytes.getInt(), generation = bytes.getInt();
                double x = bytes.getDouble(), y = bytes.getDouble(), z = bytes.getDouble();
                float yaw = bytes.getFloat(), width = bytes.getFloat(), height = bytes.getFloat();
                boolean npc = bytes.get() != 0;
                int nameLength = bytes.getInt();
                if (nameLength < 0 || nameLength > bytes.remaining()) throw new IllegalStateException("Invalid actor name length");
                var name = new String(payload, bytes.position() + boundary + 1, nameLength, StandardCharsets.UTF_8);
                bytes.position(bytes.position() + nameLength);
                actors.add(new SourceCombat.Actor(id, generation, name, x, y, z, yaw, width, height, npc));
            }
            if (bytes.hasRemaining()) throw new IllegalStateException("Unexpected moving geometry bytes");
            shapes.keySet().retainAll(activeShapes);
            bodies = Map.copyOf(next);
            actors = List.copyOf(actors);
            List<BodyTrace> traceBodies = new ArrayList<>();
            if (header.get("geometryTrace").getAsBoolean()) for (var entry : bodies.entrySet()) {
                var key = entry.getKey();
                var triangles = entry.getValue().triangles().stream().map(triangle -> new float[]{
                    (float)triangle.ax, (float)triangle.ay, (float)triangle.az,
                    (float)triangle.bx, (float)triangle.by, (float)triangle.bz,
                    (float)triangle.cx, (float)triangle.cy, (float)triangle.cz}).toList();
                traceBodies.add(new BodyTrace(key.entity(), key.creation(), key.part(), triangles));
            }
            var trace = new MovingTrace(instanceCount, triangleCount, rebuilt, (System.nanoTime() - started) / 1e6,
                List.copyOf(traceBodies), header.get("geometryTrace").getAsBoolean() ? actors : List.of());
            return new MovingGeometry(session, bodies, actors, header.getAsJsonObject("water"), acknowledged, trace);
        }

        private static List<Triangle> transform(float[] local, float[] matrix, double gridHeight, int entity) {
            List<Triangle> triangles = new ArrayList<>(local.length / 9);
            for (int offset = 0; offset < local.length; offset += 9) {
                float[] vertices = new float[9];
                for (int vertex = 0; vertex < 9; vertex += 3) {
                    float x = local[offset + vertex], y = local[offset + vertex + 1], z = local[offset + vertex + 2];
                    float sx = matrix[0]*x + matrix[1]*y + matrix[2]*z + matrix[3];
                    float sy = matrix[4]*x + matrix[5]*y + matrix[6]*z + matrix[7];
                    float sz = matrix[8]*x + matrix[9]*y + matrix[10]*z + matrix[11];
                    vertices[vertex] = sx / 32;
                    vertices[vertex + 1] = (float)((sz - gridHeight) / 32);
                    vertices[vertex + 2] = -sy / 32;
                }
                triangles.add(new Triangle(vertices, 0, 0, entity));
            }
            return List.copyOf(triangles);
        }
    }
}
