#include "source_lightmaps_internal.hpp"
#include "source_lightmaps.hpp"
#include <algorithm>
#include <cmath>
#include <utility>
#include "sdkcompat.hpp"
namespace sourceLightmaps {
    // Probe runtime data only after the PE identity and dispatch targets match the owned lab build.
    bool readable(const void* pointer, size_t length) {
        auto address = reinterpret_cast<std::uintptr_t>(pointer);
        if (!address || length > UINTPTR_MAX - address) return false;
        const auto end = address + length;
        while (address < end) {
            MEMORY_BASIC_INFORMATION region{};
            if (!VirtualQuery(reinterpret_cast<void*>(address), &region, sizeof(region))
                    || region.State != MEM_COMMIT || (region.Protect & (PAGE_NOACCESS | PAGE_GUARD))
                    || !(region.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY
                        | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY))) return false;
            address = reinterpret_cast<std::uintptr_t>(region.BaseAddress) + region.RegionSize;
        }
        return true;
    }

    void number(ILuaBase* lua, const char* key, double value) { lua->PushNumber(value); lua->SetField(-2, key); }
    void string(ILuaBase* lua, const char* key, const char* value) { lua->PushString(value); lua->SetField(-2, key); }
    void vector(ILuaBase* lua, const char* key, const Vector& value) { lua->PushVector(value); lua->SetField(-2, key); }
    void boolean(ILuaBase* lua, const char* key, bool value) { lua->PushBool(value); lua->SetField(-2, key); }

    void findBackend() {
        materialSystem = nullptr; modelInfo = nullptr; worldBrush = nullptr; worldSortInfo = nullptr;
        unsupported = "Unsupported engine/client/material-system build";
        if (!sdkcompat::supportedEngine() || !sdkcompat::supportedClient()) return;
        materialSystem = sdkcompat::materialSystem();
        if (!materialSystem) return;
        auto module = GetModuleHandleW(L"engine.dll");
        auto factory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(module, "CreateInterface"));
        modelInfo = factory("VModelInfoClient006", nullptr);
        if (!modelInfo) { unsupported = "VModelInfoClient006 is unavailable"; return; }
        auto* engine = reinterpret_cast<unsigned char*>(module);
        auto* material = reinterpret_cast<unsigned char*>(GetModuleHandleW(L"materialsystem.dll"));
        auto** modelTable = *static_cast<void***>(modelInfo);
        auto** materialTable = *static_cast<void***>(materialSystem);
        if (modelTable[60] != engine + 0x1e2dc0 || modelTable[61] != engine + 0x1e2e10
                || materialTable[96] != material + 0x25b10 || materialTable[97] != material + 0x1dca0
                || materialTable[98] != material + 0x1df70 || materialTable[99] != material + 0x1db00
                || materialTable[104] != material + 0x18e80 || materialTable[105] != material + 0x1c050
                || materialTable[106] != material + 0x1e900 || materialTable[107] != material + 0x257c0) {
            unsupported = "Pinned lightmap/surface dispatch differs"; return;
        }
        worldBrush = reinterpret_cast<unsigned char**>(engine + 0x8af198);
        worldSortInfo = reinterpret_cast<SortInfo**>(engine + 0x7e3138);
        unsupported = nullptr;
    }

    bool currentWorld() {
        return sessionWorld && *worldBrush == sessionWorld && readable(sessionWorld, 0x110)
            && read<unsigned char*>(sessionWorld + 0xe8) == sessionSurfaces;
    }

    void expandBounds(Receiver& receiver, const Vector& point) {
        for (int axis = 0; axis < 3; ++axis) {
            receiver.minimum[axis] = std::min(receiver.minimum[axis], point[axis] - 1);
            receiver.maximum[axis] = std::max(receiver.maximum[axis], point[axis] + 1);
        }
    }

    bool buildReceivers() {
        auto* world = *worldBrush;
        if (!readable(world, 0x110)) return false;
        const int count = read<int>(world + 0xd8), texCount = read<int>(world + 0xa8);
        auto* surfaces = read<unsigned char*>(world + 0xe8);
        const auto* lights = read<unsigned char*>(world + 0xf0);
        const auto* textures = read<unsigned char*>(world + 0xb0);
        auto** table = *static_cast<void***>(materialSystem);
        const int sortCount = reinterpret_cast<SortCount>(table[97])(materialSystem);
        const auto* sorts = *worldSortInfo;
        if (count < 1 || count > 1000000 || texCount < 1 || texCount > 65536 || sortCount < 1 || sortCount > 1000000
                || !readable(surfaces, static_cast<size_t>(count) * 40)
                || !readable(lights, static_cast<size_t>(count) * 40)
                || !readable(textures, static_cast<size_t>(texCount) * 88)
                || !readable(sorts, static_cast<size_t>(sortCount) * sizeof(SortInfo))) return false;
        receivers.clear(); skippedDisplacements = 0;
        for (int id = 0; id < count; ++id) {
            const auto* surface = surfaces + static_cast<size_t>(id) * 40;
            const auto* light = lights + static_cast<size_t>(id) * 40;
            const int sort = read<std::int16_t>(surface + 0x16), texIndex = read<std::uint16_t>(surface + 0x1a) >> 1;
            if (sort < 0 || sort >= sortCount || texIndex >= texCount || sorts[sort].page < 0) continue;
            const auto* plane = read<const unsigned char*>(surface + 4);
            if (!readable(plane, 16)) continue;
            const auto* tex = textures + static_cast<size_t>(texIndex) * 88;
            const Vector s = read<Vector>(tex + 32), t = read<Vector>(tex + 48), n = read<Vector>(plane);
            const Vector tn = CrossProduct(t, n), ns = CrossProduct(n, s), st = CrossProduct(s, t);
            const float determinant = DotProduct(s, tn);
            if (!std::isfinite(determinant) || std::abs(determinant) < 0.000001f) continue;
            const int width = read<std::int16_t>(light + 4) + 1, height = read<std::int16_t>(light + 6) + 1;
            const int x = read<std::int16_t>(light + 8), y = read<std::int16_t>(light + 10);
            int pageWidth, pageHeight;
            reinterpret_cast<PageSize>(table[99])(materialSystem, sorts[sort].page, &pageWidth, &pageHeight);
            if (width < 1 || height < 1 || x < 0 || y < 0 || x + width > pageWidth || y + height > pageHeight) continue;
            Receiver receiver{};
            receiver.handle = id; receiver.width = width; receiver.height = height;
            receiver.tile = {sorts[sort].page, x, y};
            receiver.origin = (tn * (read<std::int16_t>(light) - read<float>(tex + 44))
                + ns * (read<std::int16_t>(light + 2) - read<float>(tex + 60)) + st * read<float>(plane + 12)) / determinant;
            receiver.stepS = tn / determinant; receiver.stepT = ns / determinant;
            const auto flags = read<std::uint32_t>(surface);
            receiver.normal = (flags & 0x40) ? -n : n;
            receiver.displacement = (flags & 0x800) != 0;
            if (receiver.displacement) ++skippedDisplacements;
            receiver.minimum = Vector(INFINITY, INFINITY, INFINITY); receiver.maximum = -receiver.minimum;
            for (int corner = 0; corner < 4; ++corner)
                expandBounds(receiver, receiver.origin + receiver.stepS * ((corner & 1) ? width - 1 : 0)
                    + receiver.stepT * ((corner & 2) ? height - 1 : 0));
            receivers.push_back(std::move(receiver));
        }
        sessionWorld = world; sessionSurfaces = surfaces;
        return !receivers.empty();
    }

    LUA_FUNCTION(probe) {
        if (GetCurrentThreadId() != ownerThread) LUA->ThrowError("Probe Source lightmaps on the client thread");
        if (LUA->IsType(1, GarrysMod::Lua::Type::Entity)) {
            LUA->GetField(1, "GetBrushSurfaces"); LUA->Push(1); LUA->Call(1, 1); LUA->Remove(1); LUA->Insert(1);
        }
        LUA->CheckType(1, GarrysMod::Lua::Type::Table);
        int limit = LUA->IsType(2, GarrysMod::Lua::Type::Number)
            ? std::clamp(static_cast<int>(LUA->GetNumber(2)), 1, 256) : 32;
        LUA->CreateTable();
        boolean(LUA, "mutable", false);
        if (unsupported) { boolean(LUA, "supported", false); string(LUA, "unsupported", unsupported); return 1; }
        auto* world = *worldBrush;
        if (!readable(world, 0x110)) { boolean(LUA, "supported", false); string(LUA, "unsupported", "No loaded worldbrush data"); return 1; }
        const int count = read<int>(world + 0xd8);
        const int texInfoCount = read<int>(world + 0xa8);
        auto* surfaces = read<unsigned char*>(world + 0xe8);
        auto* lighting = read<unsigned char*>(world + 0xf0);
        auto* texInfos = read<unsigned char*>(world + 0xb0);
        if (count < 0 || count > 1000000 || texInfoCount < 0 || texInfoCount > 65536
                || !readable(surfaces, static_cast<size_t>(count) * 40)
                || !readable(lighting, static_cast<size_t>(count) * 40)
                || !readable(texInfos, static_cast<size_t>(texInfoCount) * 88)) {
            boolean(LUA, "supported", false); string(LUA, "unsupported", "Worldbrush arrays failed pinned-layout bounds"); return 1;
        }
        auto** mt = *static_cast<void***>(materialSystem);
        const int sortCount = reinterpret_cast<SortCount>(mt[97])(materialSystem);
        if (sortCount < 0 || sortCount > 1000000) { boolean(LUA, "supported", false); string(LUA, "unsupported", "Invalid material sort count"); return 1; }
        // Engine world sort records are the map's fixed allocation result. GetSortInfo enumerates
        // current materials and can outgrow GetNumSortIDs after runtime material creation.
        const auto* sortInfo = *worldSortInfo;
        if (!readable(sortInfo, static_cast<size_t>(sortCount) * sizeof(SortInfo))) {
            boolean(LUA, "supported", false); string(LUA, "unsupported", "No readable engine world sort records"); return 1;
        }
        boolean(LUA, "supported", true);
        string(LUA, "mode", "Read-only probe; irradiance updates require explicit start/update calls");
        number(LUA, "world_surfaces", count); number(LUA, "sort_count", sortCount);
        number(LUA, "input_surfaces", LUA->ObjLen(1));
        {
            std::lock_guard lock(tileMutex);
            number(LUA, "captured_tiles", originals.size());
        }
        boolean(LUA, "capturing", observedSlot != nullptr);
        LUA->CreateTable();
        int accepted = 0, rejected = 0;
        const int inputCount = LUA->ObjLen(1);
        for (int index = 1; index <= inputCount && accepted < limit; ++index) {
            LUA->PushNumber(index); LUA->RawGet(1);
            auto* handle = LUA->GetUserType<int>(-1, GarrysMod::Lua::Type::SurfaceInfo);
            if (!handle || *handle < 0 || *handle >= count) { ++rejected; LUA->Pop(); continue; }
            const int id = *handle;
            LUA->Pop();
            const auto* surface = surfaces + static_cast<size_t>(id) * 40;
            const auto* light = lighting + static_cast<size_t>(id) * 40;
            const auto flags = read<std::uint32_t>(surface);
            const int sort = read<std::int16_t>(surface + 0x16);
            const int texInfo = read<std::uint16_t>(surface + 0x1a) >> 1;
            if ((flags & 0x800) || sort < 0 || sort >= sortCount || texInfo >= texInfoCount
                    || sortInfo[sort].page < 0) { ++rejected; continue; }
            const auto* plane = read<const unsigned char*>(surface + 4);
            if (!readable(plane, 16)) { ++rejected; continue; }
            const int width = read<std::int16_t>(light + 4) + 1, height = read<std::int16_t>(light + 6) + 1;
            const int x = read<std::int16_t>(light + 8), y = read<std::int16_t>(light + 10);
            int pageWidth, pageHeight;
            reinterpret_cast<PageSize>(mt[99])(materialSystem, sortInfo[sort].page, &pageWidth, &pageHeight);
            if (width < 1 || height < 1 || x < 0 || y < 0 || x + width > pageWidth || y + height > pageHeight) { ++rejected; continue; }
            int vertexCount = 0;
            auto** modelTable = *static_cast<void***>(modelInfo);
            const auto* vertices = reinterpret_cast<SurfaceVertices>(modelTable[61])(modelInfo, id, &vertexCount);
            const auto* indices = reinterpret_cast<SurfaceIndices>(modelTable[60])(modelInfo, id);
            if (!vertices || !indices || vertexCount < 3 || vertexCount > 255) { ++rejected; continue; }
            LUA->PushNumber(++accepted); LUA->CreateTable();
            number(LUA, "handle", id); number(LUA, "flags", flags); number(LUA, "sort", sort);
            number(LUA, "texinfo", texInfo); number(LUA, "page", sortInfo[sort].page);
            number(LUA, "x", x); number(LUA, "y", y); number(LUA, "width", width); number(LUA, "height", height);
            number(LUA, "page_width", pageWidth); number(LUA, "page_height", pageHeight);
            {
                std::lock_guard lock(tileMutex);
                auto captured = originals.find({sortInfo[sort].page, x, y});
                const bool matched = captured != originals.end() && captured->second.width == width && captured->second.height == height;
                boolean(LUA, "capture_matches_rect", matched);
                if (matched) {
                    const auto& pixels = captured->second.pixels;
                    number(LUA, "captured_layers", 1 + static_cast<int>(!pixels[1].empty()) * 3);
                    number(LUA, "original_r", pixels[0][0]); number(LUA, "original_g", pixels[0][1]); number(LUA, "original_b", pixels[0][2]);
                }
            }
            const Vector normal = read<Vector>(plane);
            vector(LUA, "plane_normal", normal); number(LUA, "plane_distance", read<float>(plane + 12));
            boolean(LUA, "plane_back", (flags & 0x40) != 0);
            vector(LUA, "receiver_normal", (flags & 0x40) ? -normal : normal);
            LUA->CreateTable();
            for (int vertex = 0; vertex < vertexCount; ++vertex) {
                LUA->PushNumber(vertex + 1); LUA->PushVector(vertices[indices[vertex]]); LUA->RawSet(-3);
            }
            LUA->SetField(-2, "vertices");
            // The owned lab probe matched these runtime matrices/minima to the BSP face records before writes were enabled.
            const auto* tex = texInfos + static_cast<size_t>(texInfo) * 88;
            const Vector s = read<Vector>(tex + 32), t = read<Vector>(tex + 48);
            const float so = read<float>(tex + 44), to = read<float>(tex + 60);
            vector(LUA, "lightmap_s", s); vector(LUA, "lightmap_t", t);
            number(LUA, "lightmap_s_offset", so); number(LUA, "lightmap_t_offset", to);
            number(LUA, "candidate_min_s", read<std::int16_t>(light));
            number(LUA, "candidate_min_t", read<std::int16_t>(light + 2));
            const Vector tn = CrossProduct(t, normal), ns = CrossProduct(normal, s), st = CrossProduct(s, t);
            const float determinant = DotProduct(s, tn);
            boolean(LUA, "mapping_candidate", std::isfinite(determinant) && std::abs(determinant) > 0.000001f);
            if (std::isfinite(determinant) && std::abs(determinant) > 0.000001f) {
                const float minS = read<std::int16_t>(light) - so, minT = read<std::int16_t>(light + 2) - to;
                const Vector origin = (tn * minS + ns * minT + st * read<float>(plane + 12)) / determinant;
                vector(LUA, "candidate_luxel_origin", origin);
                vector(LUA, "candidate_luxel_step_s", tn / determinant);
                vector(LUA, "candidate_luxel_step_t", ns / determinant);
            }
            LUA->RawSet(-3);
        }
        LUA->SetField(-2, "surfaces"); number(LUA, "returned", accepted); number(LUA, "rejected", rejected);
        return 1;
    }

}
