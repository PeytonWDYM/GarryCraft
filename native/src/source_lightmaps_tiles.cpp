#include "source_lightmaps_internal.hpp"
#include "source_lightmaps.hpp"
#include <algorithm>
#include <cmath>
#include <utility>
namespace sourceLightmaps {
    void __fastcall observeUpdate(void* system, int page, int* size, int* offset,
            float* image, float* bump1, float* bump2, float* bump3) {
        if (capturing && size[0] > 0 && size[1] > 0 && size[0] <= 4096 && size[1] <= 4096 && image) {
            const size_t floats = static_cast<size_t>(size[0]) * size[1] * 4;
            const std::array<float*, 4> sources{image, bump1, bump2, bump3};
            Tile tile{size[0], size[1], {}};
            for (int layer = 0; layer < 4; ++layer)
                if (sources[layer]) tile.pixels[layer].assign(sources[layer], sources[layer] + floats);
            std::lock_guard lock(tileMutex);
            if (capturing) {
                originals[{page, offset[0], offset[1]}] = std::move(tile);
                ++captureRevision;
            }
        }
        // Observation leaves all irradiance buffers and the engine's queue ownership unchanged.
        originalUpdate(system, page, size, offset, image, bump1, bump2, bump3);
    }

    bool exchangeUpdateSlot(void* expected, void* value) {
        DWORD protection;
        if (!VirtualProtect(observedSlot, sizeof(void*), PAGE_READWRITE, &protection)) return false;
        const bool changed = InterlockedCompareExchangePointer(observedSlot, value, expected) == expected;
        DWORD ignored;
        VirtualProtect(observedSlot, sizeof(void*), protection, &ignored);
        return changed;
    }

    bool startCapture() {
        if (observedSlot) return capturing;
        auto** table = *static_cast<void***>(materialSystem);
        observedSlot = table + 96;
        auto* expected = reinterpret_cast<unsigned char*>(GetModuleHandleW(L"materialsystem.dll")) + 0x25b10;
        if (*observedSlot != expected) { observedSlot = nullptr; return false; }
        originalUpdate = reinterpret_cast<UpdateLightmap>(expected);
        HMODULE pinned;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                reinterpret_cast<LPCWSTR>(observeUpdate), &pinned)) { observedSlot = nullptr; return false; }
        capturing = true;
        if (!exchangeUpdateSlot(expected, reinterpret_cast<void*>(observeUpdate))) {
            capturing = false; observedSlot = nullptr; return false;
        }
        return true;
    }

    // UpdateLightmap rejects queued contexts. Lock drains queued work and restores the previous context on unlock.
    void uploadBatch(const std::vector<Upload>& batch) {
        if (batch.empty()) return;
        using Lock = void* (__fastcall*)(void*);
        using Unlock = void (__fastcall*)(void*, void*);
        using Operation = void (__fastcall*)(void*);
        auto** table = *static_cast<void***>(materialSystem);
        auto* previous = reinterpret_cast<Lock>(table[106])(materialSystem);
        reinterpret_cast<Operation>(table[104])(materialSystem);
        for (const auto& upload : batch) {
            int size[]{upload.width, upload.height}, offset[]{upload.tile[1], upload.tile[2]};
            std::array<float*, 4> images{};
            for (int layer = 0; layer < 4; ++layer)
                if (!upload.pixels[layer].empty()) images[layer] = const_cast<float*>(upload.pixels[layer].data());
            originalUpdate(materialSystem, upload.tile[0], size, offset, images[0], images[1], images[2], images[3]);
        }
        reinterpret_cast<Operation>(table[105])(materialSystem);
        reinterpret_cast<Unlock>(table[107])(materialSystem, previous);
    }

    void restoreIrradiance() {
        resetLightmapWork();
        std::vector<Upload> batch;
        if (active && currentWorld()) {
            {
                std::lock_guard lock(tileMutex);
                for (auto& [key, tile] : originals) if (tile.modified) {
                    batch.push_back({key, tile.width, tile.height, tile.pixels});
                    tile.modified = false; tile.applied = {};
                }
            }
            uploadBatch(batch); restoredTiles += batch.size();
        }
        active = false; receivers.clear(); skippedDisplacements = 0; sessionWorld = sessionSurfaces = nullptr;
    }


    LUA_FUNCTION(captureStart) {
        if (GetCurrentThreadId() != ownerThread) LUA->ThrowError("Capture Source lightmaps on the client thread");
        if (unsupported) { LUA->PushBool(false); LUA->PushString(unsupported); return 2; }
        if (!startCapture()) { LUA->PushBool(false); LUA->PushString("Could not install the verified UpdateLightmap observer"); return 2; }
        LUA->PushBool(true); return 1;
    }
    LUA_FUNCTION(captureStop) { releaseSourceLightmaps(); return 0; }
    void stopCapture() {
        capturing = false;
        if (observedSlot) {
            closeMode = exchangeUpdateSlot(reinterpret_cast<void*>(observeUpdate), reinterpret_cast<void*>(originalUpdate))
                ? "restored-observer" : "chained-observer-retained";
            observedSlot = nullptr;
        }
        std::lock_guard lock(tileMutex); originals.clear();
    }
}
