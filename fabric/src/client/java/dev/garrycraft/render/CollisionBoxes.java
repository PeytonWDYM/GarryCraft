package dev.garrycraft.render;

import java.util.ArrayList;
import java.util.List;

/** Joins touching boxes with identical spans. Their union retains Minecraft's exact collision volume. */
final class CollisionBoxes {
    private CollisionBoxes() {}

    static List<double[]> merge(List<double[]> boxes) {
        var result = boxes;
        for (int axis = 0; axis < 3; axis++) result = mergeAxis(result, axis);
        return result;
    }

    private static List<double[]> mergeAxis(List<double[]> boxes, int axis) {
        int a = (axis + 1) % 3, b = (axis + 2) % 3;
        int[] components = {a, a + 3, b, b + 3, axis, axis + 3};
        var sorted = new ArrayList<>(boxes);
        sorted.sort((left, right) -> {
            for (int component : components) {
                int order = Double.compare(left[component], right[component]);
                if (order != 0) return order;
            }
            return 0;
        });
        var merged = new ArrayList<double[]>();
        for (var box : sorted) {
            if (!merged.isEmpty()) {
                var previous = merged.getLast();
                if (previous[a] == box[a] && previous[a + 3] == box[a + 3]
                        && previous[b] == box[b] && previous[b + 3] == box[b + 3]
                        && previous[axis + 3] == box[axis]) {
                    var joined = previous.clone();
                    joined[axis + 3] = box[axis + 3];
                    merged.set(merged.size() - 1, joined);
                    continue;
                }
            }
            merged.add(box);
        }
        return merged;
    }
}
