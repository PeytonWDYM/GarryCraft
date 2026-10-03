#include "source_lightmaps_internal.hpp"
#include "lighting.hpp"
#include "source_sun_lighting.hpp"
#include "voxel_lighting.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <optional>
#include <utility>

namespace sourceLightmaps {
    namespace {
        using Clock = std::chrono::steady_clock;
        using Revisions = std::array<std::uint64_t, 4>;
        constexpr double budgetMilliseconds = 2;
        struct Work {
            std::array<std::vector<float>, 4> original, target;
            size_t pixel = 0;
            bool changed = false;
        };
        std::optional<Work> work;
        size_t receiverCursor = 0;
        bool running = false, repeat = false, requested = true;
        Revisions observed{};
        double cpuMilliseconds = 0, uploadMilliseconds = 0, updateMilliseconds = 0, maximumMilliseconds = 0;
        std::uint64_t passes = 0, interruptedTiles = 0;
        Revisions revisions() { return {voxelLightingRevision(), captureRevision.load(), sourceSunRevision(), lightingOccluderRevision()}; }
        double elapsed(Clock::time_point start) { return std::chrono::duration<double, std::milli>(Clock::now() - start).count(); }
        size_t pendingReceivers() {
            if (!active) return 0;
            if (requested || (!running && revisions() != observed)) return receivers.size();
            return running ? receivers.size() - receiverCursor + (repeat ? receivers.size() : 0) : 0;
        }
        void finishPass() {
            ++passes;
            if (repeat) { receiverCursor = 0; repeat = false; mappedLuxels = 0; return; }
            running = false;
            lastVoxelRevision = observed[0]; lastCaptureRevision = observed[1]; lastSunRevision = observed[2];
        }
    }

    void resetLightmapWork() {
        work.reset(); receiverCursor = 0; running = repeat = false; requested = true;
        cpuMilliseconds = uploadMilliseconds = updateMilliseconds = maximumMilliseconds = 0;
        passes = interruptedTiles = 0;
    }
    void invalidateLightmapWork() { requested = true; }
    void reportLightmapWork(ILuaBase* lua) {
        number(lua, "pending_receivers", pendingReceivers()); boolean(lua, "pending", pendingReceivers() != 0);
        number(lua, "budget_ms", budgetMilliseconds); number(lua, "update_ms", updateMilliseconds);
        number(lua, "cpu_ms", cpuMilliseconds); number(lua, "upload_ms", uploadMilliseconds);
        number(lua, "max_update_ms", maximumMilliseconds); number(lua, "completed_passes", passes);
        number(lua, "receiver_cursor", receiverCursor); number(lua, "partial_luxels", work ? work->pixel : 0);
        number(lua, "interrupted_tiles", interruptedTiles); number(lua, "occluder_revision", observed[3]);
    }

    LUA_FUNCTION(update) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Update Source lightmaps on the client thread"), 0;
        if (!active || !currentWorld()) { LUA->PushNumber(0); LUA->PushNumber(0); return 2; }
        const auto start = Clock::now();
        const auto latest = revisions();
        const bool force = LUA->IsType(1, GarrysMod::Lua::Type::Bool) && LUA->GetBool(1);
        if (force && !running) requested = true;
        if (!running && (requested || latest != observed)) {
            running = true; requested = repeat = false; receiverCursor = 0; observed = latest; mappedLuxels = 0;
        } else if (running && (requested || latest != observed)) {
            // Keep the receiver cursor: already-finished tiles get a follow-up
            // pass, rather than restarting the whole map for every new packet.
            if (work) ++interruptedTiles;
            work.reset(); repeat |= receiverCursor != 0; requested = false; observed = latest;
        }
        if (!running) { LUA->PushNumber(0); LUA->PushNumber(0); return 2; }
        const auto deadline = start + std::chrono::milliseconds(2);
        std::vector<Upload> batch;
        size_t batchPixels = 0;
        {
            std::lock_guard lock(tileMutex);
            while (running && Clock::now() < deadline && batch.size() < 4 && batchPixels < 4096) {
                if (receiverCursor == receivers.size()) { finishPass(); continue; }
                const auto& receiver = receivers[receiverCursor];
                if (receiver.displacement && receiver.positions.empty()) { ++receiverCursor; continue; }
                const auto found = originals.find(receiver.tile);
                if (found == originals.end() || found->second.width != receiver.width || found->second.height != receiver.height) {
                    ++receiverCursor; continue;
                }
                auto& tile = found->second;
                if (!work) {
                    const bool intersects = voxelLightingIntersects(receiver.minimum, receiver.maximum, gridHeight)
                        || sourceSunLightingIntersects(receiver.minimum, receiver.maximum, gridHeight);
                    if (!intersects) {
                        if (tile.modified) {
                            batch.push_back({receiver.tile, tile.width, tile.height, tile.pixels});
                            batchPixels += size_t(tile.width) * tile.height; tile.modified = false; tile.applied = {};
                        }
                        ++receiverCursor; continue;
                    }
                    work.emplace(Work{tile.pixels, tile.pixels});
                }
                auto& pending = *work;
                const size_t pixels = size_t(receiver.width) * receiver.height;
                const size_t until = std::min(pixels, pending.pixel + 64);
                for (; pending.pixel < until; ++pending.pixel) {
                    const auto pixel = pending.pixel;
                    const Vector position = receiver.displacement ? receiver.positions[pixel]
                        : receiver.origin + receiver.stepS * int(pixel % receiver.width) + receiver.stepT * int(pixel / receiver.width);
                    const Vector normal = receiver.displacement ? receiver.normals[pixel] : receiver.normal;
                    float sky = 1, block = 0;
                    const auto receiverPosition = position + normal;
                    const bool mapped = sampleVoxelLighting(receiverPosition, gridHeight, sky, block);
                    const float irradiance = sourceSkyFactor(receiverPosition, normal, sky, gridHeight);
                    if (!mapped && irradiance == 1) continue;
                    ++mappedLuxels;
                    constexpr std::array<float, 3> blockColor{1, .87f, .67f};
                    for (int layer = 0; layer < 4; ++layer) if (!pending.target[layer].empty())
                        for (int channel = 0; channel < 3; ++channel) {
                            const size_t component = pixel * 4 + channel;
                            const float value = pending.original[layer][component] * irradiance + block * blockColor[channel];
                            pending.target[layer][component] = value;
                            pending.changed |= std::abs(value - pending.original[layer][component]) > .000001f;
                        }
                }
                if (pending.pixel != pixels) continue;
                if ((pending.changed || tile.modified) && (!tile.modified || tile.applied != pending.target)) {
                    tile.modified = pending.changed; tile.applied = pending.changed ? pending.target : std::array<std::vector<float>, 4>{};
                    batch.push_back({receiver.tile, tile.width, tile.height, std::move(pending.target)});
                    batchPixels += pixels;
                }
                work.reset(); ++receiverCursor;
            }
            if (running && receiverCursor == receivers.size()) finishPass();
        }
        cpuMilliseconds = elapsed(start);
        // Lock drains the render queue; submit only a few completed tiles, never
        // a partly processed receiver. The snapshot mutex is released first.
        const auto uploadStart = Clock::now(); uploadBatch(batch);
        uploadMilliseconds = elapsed(uploadStart); uploads += batch.size();
        updateMilliseconds = elapsed(start); maximumMilliseconds = std::max(maximumMilliseconds, updateMilliseconds);
        // A capture on the render worker may have arrived while uploading.
        if (!running && revisions() != observed) requested = true;
        LUA->PushNumber(batch.size()); LUA->PushNumber(pendingReceivers()); return 2;
    }
}
