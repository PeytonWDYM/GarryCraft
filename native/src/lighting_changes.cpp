#include "lighting_changes.hpp"
#include <deque>

namespace {
    struct Change { Vector minimum, maximum; std::uint64_t revision; };
    std::deque<Change> changes;
    std::uint64_t revision = 0;
}

void recordLightingChange(const Vector& minimum, const Vector& maximum) {
    changes.push_back({minimum, maximum, ++revision});
    if (changes.size() > 128) changes.pop_front();
}
void clearLightingChanges() { changes.clear(); ++revision; }
std::uint64_t lightingChangeRevision() { return revision; }

bool lightingChanged(const Vector& minimum, const Vector& maximum, float height, std::uint64_t since) {
    if (since == revision) return false;
    if (changes.empty() || since + 1 < changes.front().revision) return true;
    for (const auto& change : changes) {
        if (change.revision <= since) continue;
        // Include adjacent cell interpolation and surface probe offsets.
        const Vector lower = change.minimum - Vector(32, 32, 32) + Vector(0, 0, height);
        const Vector upper = change.maximum + Vector(32, 32, 32) + Vector(0, 0, height);
        if (minimum.x <= upper.x && maximum.x >= lower.x && minimum.y <= upper.y && maximum.y >= lower.y
                && minimum.z <= upper.z && maximum.z >= lower.z) return true;
    }
    return false;
}
