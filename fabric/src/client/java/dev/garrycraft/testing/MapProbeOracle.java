package dev.garrycraft.testing;

import com.google.gson.Gson;
import dev.garrycraft.bridge.HostInput;
import dev.garrycraft.bridge.InputBridge;
import dev.garrycraft.physics.SourceRay;
import dev.garrycraft.physics.SourceWorld;
import dev.garrycraft.physics.Triangle;
import dev.garrycraft.physics.TriCollider;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import net.minecraft.client.Minecraft;
import net.minecraft.world.phys.AABB;

/** Compares imported map props with the Source engine's real ray and player-hull traces. */
public final class MapProbeOracle {
    private record Probe(String name, double[] from, double[] to, double rayFraction, double hullFraction) {}
    private record Request(String request, List<Probe> probes) {}
    private record Result(String name, double sourceRay, double importedRay, double sourceHull,
                          double importedHull, boolean rayHit, boolean bodyStopped) {}
    private static String request = "";
    private MapProbeOracle() {}

    public static boolean beforeTick(Minecraft mc, HostInput host) {
        if (!host.test().startsWith("probe:")) return false;
        InputBridge.apply(mc, HostInput.idle());
        if (host.test().equals(request)) return true;
        request = host.test();
        var plan = new Gson().fromJson(request.substring(6), Request.class);
        var results = new ArrayList<Result>();
        for (var probe : plan.probes()) {
            var a = probe.from(); var b = probe.to();
            var triangles = new ArrayList<Triangle>();
            var region = new AABB(Math.min(a[0], b[0]), Math.min(a[1], b[1]), Math.min(a[2], b[2]),
                Math.max(a[0], b[0]), Math.max(a[1], b[1]) + 1.8, Math.max(a[2], b[2])).inflate(.31);
            SourceWorld.COLLISION.trianglesNear(region, triangles);
            var hit = SourceRay.cast(triangles, a[0], a[1], a[2], b[0], b[1], b[2]);
            var move = TriCollider.resolve(triangles, a[0], a[1], a[2], mc.player.getBbWidth() / 2,
                mc.player.getBbHeight(), mc.player.maxUpStep(), true,
                b[0] - a[0], 0, b[2] - a[2]);
            double fraction = Math.hypot(move[0], move[2]) / Math.hypot(b[0] - a[0], b[2] - a[2]);
            results.add(new Result(probe.name(), probe.rayFraction(), hit == null ? 1 : hit.t(), probe.hullFraction(),
                fraction, hit != null, fraction < .95));
        }
        try {
            Files.writeString(Path.of(System.getProperty("garrycraft.artifacts"), "map-probes.json"),
                new Gson().toJson(java.util.Map.of("request", plan.request(), "results", results)));
        } catch (IOException failure) { throw new IllegalStateException("Could not save map collision probes", failure); }
        return true;
    }
}
