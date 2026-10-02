package dev.garrycraft.physics;

import com.google.gson.JsonObject;
import com.google.gson.Gson;
import dev.garrycraft.combat.SourceCombat;
import java.util.ArrayList;
import java.util.List;
import java.util.LinkedHashSet;
import net.minecraft.world.phys.AABB;

/** Source triangles share the same coordinates as the Minecraft mirror world. */
public final class CollisionWorld {
    private volatile TriangleIndex terrain = new TriangleIndex(List.of());
    private final List<Triangle> pendingStatic = new ArrayList<>();
    private volatile TriangleIndex dynamic = new TriangleIndex(List.of());
    private volatile List<SourceCombat.Actor> actors = List.of();
    private String session = "";
    private volatile int acknowledged = -1;
    private volatile long revision;

    public void reset(String nextSession) {
        terrain = new TriangleIndex(List.of());
        pendingStatic.clear();
        dynamic = new TriangleIndex(List.of());
        actors = List.of();
        acknowledged = -1;
        session = nextSession;
        SourceWater.clear();
        revision++;
    }

    public int acknowledged() { return acknowledged; }
    public long revision() { return revision; }
    public List<SourceCombat.Actor> actors() { return actors; }

    public void accept(JsonObject message, boolean moving) {
        if (!message.get("session").getAsString().equals(session)) return;
        if (!moving && message.get("batch").getAsInt() != acknowledged + 1) return;
        List<Triangle> triangles = new ArrayList<>();
        for (var element : message.getAsJsonArray("triangles")) {
            var values = element.getAsJsonArray();
            float[] vertices = new float[9];
            for (int i = 0; i < 9; i++) vertices[i] = values.get(i).getAsFloat();
            triangles.add(new Triangle(vertices, 0, 0, values.size() > 9 ? values.get(9).getAsInt() : 0));
        }
        if (moving) {
            dynamic = new TriangleIndex(triangles);
            actors = List.of(new Gson().fromJson(message.getAsJsonArray("actors"), SourceCombat.Actor[].class));
            // Old mailbox snapshots can survive a bridge upgrade.
            if (message.has("water")) SourceWater.refresh(message.getAsJsonObject("water"));
            else SourceWater.clear();
        }
        else {
            int batch = message.get("batch").getAsInt();
            pendingStatic.addAll(triangles);
            // Publish one immutable map index after the complete, acknowledged stream arrives.
            if (batch == message.get("total").getAsInt() - 1) {
                terrain = new TriangleIndex(pendingStatic);
                pendingStatic.clear();
                revision++;
            }
            acknowledged = batch;
        }
    }

    public void trianglesNear(AABB region, List<Triangle> output) {
        var found = new LinkedHashSet<Triangle>();
        terrain.nearby(region, found);
        dynamic.nearby(region, found);
        output.addAll(found);
    }
    public void staticTrianglesNear(AABB region, List<Triangle> output) {
        var found = new LinkedHashSet<Triangle>();
        terrain.nearby(region, found);
        output.addAll(found);
    }
}
