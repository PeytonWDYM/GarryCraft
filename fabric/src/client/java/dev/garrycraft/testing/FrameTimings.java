package dev.garrycraft.testing;

import com.google.gson.Gson;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;

/** Measures complete frame intervals, including stalls and pacing, during the bounded game scenario. */
public final class FrameTimings {
    private record Sample(double milliseconds, String phase) {}
    private record Summary(int count, double p50, double p95, double p99, double maximum, boolean stable240) {}
    private static final List<Sample> SAMPLES = new ArrayList<>();
    private static final LinkedHashMap<String, Distribution> PHASES = new LinkedHashMap<>();
    private static final class Distribution {
        final int[] microseconds = new int[100001];
        int count;
        double maximum;
        void add(double milliseconds) {
            microseconds[Math.min(100000, (int) Math.ceil(milliseconds * 1000))]++;
            count++;
            maximum = Math.max(maximum, milliseconds);
        }
        double percentile(double fraction) {
            int required = (int) Math.ceil(count * fraction), total = 0;
            for (int i = 0; i < microseconds.length; i++) {
                total += microseconds[i];
                if (total >= required) return i == 100000 ? maximum : i / 1000.0;
            }
            throw new IllegalStateException("Empty frame distribution");
        }
    }
    private static long previous;
    public static double lastMs;
    private FrameTimings() {}
    public static void reset() { SAMPLES.clear(); PHASES.clear(); previous = 0; }
    public static void frame() {
        long now = System.nanoTime();
        if (previous != 0) {
            lastMs = (now - previous) / 1_000_000.0;
            if (ParityOracle.running()) {
                String phase = ParityOracle.phase();
                PHASES.computeIfAbsent(phase, ignored -> new Distribution()).add(lastMs);
                if (SAMPLES.size() < 20000) SAMPLES.add(new Sample(lastMs, phase));
            }
        }
        previous = now;
    }
    public static void save(Path directory) {
        var summaries = new LinkedHashMap<String, Summary>();
        PHASES.forEach((phase, values) -> {
            double p99 = values.percentile(.99);
            summaries.put(phase, new Summary(values.count, values.percentile(.5), values.percentile(.95),
                p99, values.maximum, p99 <= 1000.0 / 240));
        });
        var json = new Gson();
        var result = new com.google.gson.JsonObject();
        result.addProperty("percentileResolutionMicroseconds", 1);
        result.addProperty("framesTruncated", PHASES.values().stream().mapToInt(values -> values.count).sum() > SAMPLES.size());
        result.add("summaries", json.toJsonTree(summaries)); result.add("frames", json.toJsonTree(SAMPLES));
        try { Files.writeString(directory.resolve("minecraft-frame-times.json"), json.toJson(result)); }
        catch (IOException failure) { throw new IllegalStateException("Cannot save Minecraft frame times", failure); }
    }
}
