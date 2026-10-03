#include "source_lightmaps_internal.hpp"
#include <algorithm>
#include <cmath>

namespace sourceLightmaps {
    // Resolve coordinates in the verified runtime luxel basis, including skewed
    // texture axes. Registered displacement data supplies the actual tap geometry.
    LUA_FUNCTION(receiverAt) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Probe Source lightmap receivers on the client thread"), 0;
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector);
        const auto point = LUA->GetVector(1);
        if (!std::isfinite(point.x) || !std::isfinite(point.y) || !std::isfinite(point.z))
            return LUA->ThrowError("Source lightmap receiver position must be finite"), 0;
        if (!active || !currentWorld()) { LUA->PushNil(); return 1; }
        const Receiver* selected = nullptr;
        const Tile* snapshot = nullptr;
        float selectedU = 0, selectedV = 0, closest = 2.00001f;
        std::lock_guard lock(tileMutex);
        for (const auto& receiver : receivers) {
            if (receiver.displacement && receiver.positions.empty()) continue;
            if (point.x < receiver.minimum.x - 1 || point.x > receiver.maximum.x + 1
                    || point.y < receiver.minimum.y - 1 || point.y > receiver.maximum.y + 1
                    || point.z < receiver.minimum.z - 1 || point.z > receiver.maximum.z + 1) continue;
            const auto offset = point - receiver.origin;
            const float distance = std::abs(DotProduct(offset, receiver.normal));
            if (distance > 2 || distance >= closest) continue;
            const float ss = receiver.stepS.LengthSqr(), tt = receiver.stepT.LengthSqr();
            const float st = DotProduct(receiver.stepS, receiver.stepT), determinant = ss * tt - st * st;
            const float ps = DotProduct(offset, receiver.stepS), pt = DotProduct(offset, receiver.stepT);
            const float u = (ps * tt - pt * st) / determinant, v = (pt * ss - ps * st) / determinant;
            if (!std::isfinite(u) || !std::isfinite(v) || u < -.0001f || v < -.0001f
                    || u > receiver.width - 1 + .0001f || v > receiver.height - 1 + .0001f) continue;
            const auto found = originals.find(receiver.tile);
            if (found == originals.end() || found->second.width != receiver.width || found->second.height != receiver.height) continue;
            selected = &receiver; snapshot = &found->second; closest = distance;
            selectedU = std::clamp(u, 0.f, float(receiver.width - 1)); selectedV = std::clamp(v, 0.f, float(receiver.height - 1));
        }
        if (!selected) { LUA->PushNil(); return 1; }
        const auto& receiver = *selected;
        const int x0 = int(std::floor(selectedU)), y0 = int(std::floor(selectedV));
        const int x1 = std::min(x0 + 1, receiver.width - 1), y1 = std::min(y0 + 1, receiver.height - 1);
        const float fx = selectedU - x0, fy = selectedV - y0;
        const std::array xs{x0, x1, x0, x1}, ys{y0, y0, y1, y1};
        const std::array weights{(1 - fx) * (1 - fy), fx * (1 - fy), (1 - fx) * fy, fx * fy};
        LUA->CreateTable(); boolean(LUA, "mutable", false); boolean(LUA, "displacement", receiver.displacement);
        number(LUA, "handle", receiver.handle); number(LUA, "width", receiver.width); number(LUA, "height", receiver.height);
        number(LUA, "page", receiver.tile[0]); number(LUA, "x", receiver.tile[1]); number(LUA, "y", receiver.tile[2]);
        number(LUA, "u", selectedU); number(LUA, "v", selectedV); number(LUA, "plane_distance", closest);
        number(LUA, "receiver_offset", 1); vector(LUA, "normal", receiver.normal);
        vector(LUA, "origin", receiver.origin); vector(LUA, "step_s", receiver.stepS); vector(LUA, "step_t", receiver.stepT);
        LUA->CreateTable();
        for (int tap = 0; tap < 4; ++tap) {
            const size_t pixel = static_cast<size_t>(ys[tap]) * receiver.width + xs[tap];
            const auto position = receiver.displacement ? receiver.positions[pixel]
                : receiver.origin + receiver.stepS * xs[tap] + receiver.stepT * ys[tap];
            const auto normal = receiver.displacement ? receiver.normals[pixel] : receiver.normal;
            const auto* rgb = snapshot->pixels[0].data() + pixel * 4;
            LUA->PushNumber(tap + 1); LUA->CreateTable();
            number(LUA, "x", xs[tap]); number(LUA, "y", ys[tap]); number(LUA, "weight", weights[tap]);
            vector(LUA, "position", position); vector(LUA, "normal", normal); vector(LUA, "original", Vector(rgb[0], rgb[1], rgb[2]));
            LUA->RawSet(-3);
        }
        LUA->SetField(-2, "taps");
        return 1;
    }
}
