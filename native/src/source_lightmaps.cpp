#include "source_lightmaps_internal.hpp"
#include "source_lightmaps.hpp"
#include <algorithm>
#include <cmath>
#include <utility>
namespace sourceLightmaps {

    void* materialSystem;
    void* modelInfo;
    unsigned char** worldBrush;
    SortInfo** worldSortInfo;
    DWORD ownerThread;
    const char* unsupported = "Engine interfaces have not been checked";
    std::map<TileKey, Tile> originals;
    std::mutex tileMutex;
    UpdateLightmap originalUpdate;
    void** observedSlot;
    std::atomic_bool capturing;
    std::atomic<std::uint64_t> captureRevision;
    std::vector<Receiver> receivers;
    bool active;
    float gridHeight;
    unsigned char* sessionWorld;
    unsigned char* sessionSurfaces;
    std::uint64_t lastVoxelRevision, lastCaptureRevision, lastSunRevision, uploads, restoredTiles, mappedLuxels, skippedDisplacements;
    const char* closeMode = "never-started";
    LUA_FUNCTION_STATIC(start) {
        if (GetCurrentThreadId() != ownerThread) LUA->ThrowError("Start Source lightmaps on the client thread");
        const float height = static_cast<float>(LUA->CheckNumber(1));
        if (!std::isfinite(height)) LUA->ThrowError("Source lightmap grid height must be finite");
        if (unsupported) { LUA->PushBool(false); LUA->PushString(unsupported); return 2; }
        restoreIrradiance();
        if (!startCapture() || !buildReceivers()) { LUA->PushBool(false); LUA->PushString("No verified Source lightmap receivers or observer"); return 2; }
        gridHeight = height; active = true;
        lastVoxelRevision = lastCaptureRevision = lastSunRevision = UINT64_MAX; closeMode = "active";
        resetLightmapWork();
        LUA->PushBool(true); return 1;
    }

    LUA_FUNCTION_STATIC(setDisplacement) {
        if (GetCurrentThreadId() != ownerThread) LUA->ThrowError("Set Source displacement lighting on the client thread");
        const int handle = static_cast<int>(LUA->CheckNumber(1));
        LUA->CheckType(2, GarrysMod::Lua::Type::String);
        unsigned int length;
        const auto* bytes = reinterpret_cast<const unsigned char*>(LUA->GetString(2, &length));
        auto found = std::find_if(receivers.begin(), receivers.end(), [=](const Receiver& receiver) { return receiver.handle == handle; });
        if (found == receivers.end() || !found->displacement) LUA->ThrowError("Source lightmap handle must identify a loaded displacement receiver");
        const size_t pixels = static_cast<size_t>(found->width) * found->height;
        if (length != pixels * 24) LUA->ThrowError("Displacement lighting requires one XYZ position and XYZ outward normal per lightmap luxel");
        for (size_t pixel = 0; pixel < pixels; ++pixel) {
            const auto position = read<Vector>(bytes + pixel * 24), normal = read<Vector>(bytes + pixel * 24 + 12);
            if (!std::isfinite(position.x) || !std::isfinite(position.y) || !std::isfinite(position.z)
                    || !std::isfinite(normal.x) || !std::isfinite(normal.y) || !std::isfinite(normal.z)
                    || normal.LengthSqr() < 0.9f || normal.LengthSqr() > 1.1f) LUA->ThrowError("Displacement luxels require finite positions and unit normals");
        }
        std::vector<Vector> positions(pixels), normals(pixels);
        for (size_t pixel = 0; pixel < pixels; ++pixel) {
            positions[pixel] = read<Vector>(bytes + pixel * 24); normals[pixel] = read<Vector>(bytes + pixel * 24 + 12);
        }
        const bool missing = found->positions.empty();
        found->positions = std::move(positions); found->normals = std::move(normals);
        found->minimum = Vector(INFINITY, INFINITY, INFINITY); found->maximum = -found->minimum;
        for (const auto& position : found->positions) expandBounds(*found, position);
        if (missing) --skippedDisplacements;
        invalidateLightmapWork();
        LUA->PushBool(true); return 1;
    }

    LUA_FUNCTION_STATIC(report) {
        LUA->CreateTable(); boolean(LUA, "active", active); boolean(LUA, "capturing", capturing);
        number(LUA, "receivers", receivers.size()); number(LUA, "missing_displacements", skippedDisplacements);
        int expectedDisplacements = 0;
        for (const auto& receiver : receivers) expectedDisplacements += receiver.displacement;
        number(LUA, "expected_displacements", expectedDisplacements);
        number(LUA, "registered_displacements", expectedDisplacements - skippedDisplacements);
        number(LUA, "uploads", uploads); number(LUA, "restored_tiles", restoredTiles); number(LUA, "mapped_luxels", mappedLuxels);
        reportLightmapWork(LUA);
        number(LUA, "voxel_revision", lastVoxelRevision == UINT64_MAX ? 0 : lastVoxelRevision);
        number(LUA, "sun_revision", lastSunRevision == UINT64_MAX ? 0 : lastSunRevision);
        string(LUA, "close_mode", closeMode);
        std::lock_guard lock(tileMutex); number(LUA, "captured_tiles", originals.size());
        int modified = 0; for (const auto& [key, tile] : originals) modified += tile.modified;
        number(LUA, "modified_tiles", modified);
        return 1;
    }


}
void registerSourceLightmaps(GarrysMod::Lua::ILuaBase* lua) {
    using namespace sourceLightmaps;
    ownerThread = GetCurrentThreadId(); findBackend();
    lua->PushCFunction(probe); lua->SetField(-2, "lightmap_probe");
    lua->PushCFunction(receiverAt); lua->SetField(-2, "source_lightmaps_receiver_at");
    lua->PushCFunction(captureStart); lua->SetField(-2, "lightmap_capture_start");
    lua->PushCFunction(captureStop); lua->SetField(-2, "lightmap_capture_stop");
    lua->PushCFunction(start); lua->SetField(-2, "source_lightmaps_start");
    lua->PushCFunction(update); lua->SetField(-2, "source_lightmaps_update");
    lua->PushCFunction(setDisplacement); lua->SetField(-2, "source_lightmaps_set_displacement");
    lua->PushCFunction(report); lua->SetField(-2, "source_lightmaps_report");
    lua->PushCFunction(captureStop); lua->SetField(-2, "source_lightmaps_stop");
}
void releaseSourceLightmaps() {
    using namespace sourceLightmaps;
    restoreIrradiance(); stopCapture();
}
