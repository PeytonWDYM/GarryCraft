package dev.garrycraft.physics;

import com.google.gson.JsonObject;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import net.minecraft.world.phys.AABB;

/** Source triangles share the same coordinates as the Minecraft mirror world. */
public final class CollisionWorld {
    private volatile Map<Integer, List<Triangle>> batches = Map.of();
    private volatile List<Triangle> dynamic = List.of();
    private String session = "";
    private volatile int acknowledged = -1;

    public void reset(String nextSession) {
        batches = Map.of();
        dynamic = List.of();
        acknowledged = -1;
        session = nextSession;
        SourceWater.clear();
    }

    public int acknowledged() { return acknowledged; }

    public void accept(JsonObject message, boolean moving) {
        if (!message.get("session").getAsString().equals(session)) return;
        List<Triangle> triangles = new ArrayList<>();
        for (var element : message.getAsJsonArray("triangles")) {
            var values = element.getAsJsonArray();
            float[] vertices = new float[9];
            for (int i = 0; i < 9; i++) vertices[i] = values.get(i).getAsFloat();
            triangles.add(new Triangle(vertices, 0, false));
        }
        if (moving) {
            dynamic = List.copyOf(triangles);
            // Old mailbox snapshots can survive a bridge upgrade.
            if (message.has("water")) SourceWater.refresh(message.getAsJsonObject("water"));
            else SourceWater.clear();
        }
        else {
            int batch = message.get("batch").getAsInt();
            Map<Integer, List<Triangle>> next = new HashMap<>(batches);
            next.put(batch, List.copyOf(triangles));
            batches = Map.copyOf(next);
            acknowledged = batch;
        }
    }

    private void nearby(List<Triangle> source, AABB box, List<Triangle> output) {
        for (Triangle t : source) {
            if (t.maxX >= box.minX && t.minX <= box.maxX && t.maxY >= box.minY && t.minY <= box.maxY
                    && t.maxZ >= box.minZ && t.minZ <= box.maxZ) output.add(t);
        }
    }

    public void trianglesNear(AABB region, List<Triangle> output) {
        batches.values().forEach(batch -> nearby(batch, region, output));
        nearby(dynamic, region, output);
    }
}
