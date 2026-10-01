package dev.garrycraft.render;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Versions full mesh snapshots so mailbox overwrites cannot lose a group update. */
final class MeshSnapshots {
    record Snapshot(long revision, List<ModelCollector.Batch> batches) {}
    private static final Map<String, Snapshot> PREVIOUS = new HashMap<>();
    private MeshSnapshots() {}
    static void reset() { PREVIOUS.clear(); }
    static Snapshot changed(String name, List<ModelCollector.Batch> batches) {
        var before = PREVIOUS.get(name);
        if (before != null && equal(before.batches(), batches)) return before;
        var next = new Snapshot(before == null ? 1 : before.revision() + 1, batches);
        PREVIOUS.put(name, next);
        return next;
    }
    private static boolean equal(List<ModelCollector.Batch> a, List<ModelCollector.Batch> b) {
        if (a.size() != b.size()) return false;
        for (int i = 0; i < a.size(); i++) {
            var x = a.get(i); var y = b.get(i);
            if (x.texture() != y.texture() || x.translucent() != y.translucent() || x.unlit() != y.unlit()
                    || x.vertices().size() != y.vertices().size()) return false;
            for (int v = 0; v < x.vertices().size(); v++) if (!Arrays.equals(x.vertices().get(v), y.vertices().get(v))) return false;
        }
        return true;
    }
}
