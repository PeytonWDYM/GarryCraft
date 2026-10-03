#include <GarrysMod/Lua/Interface.h>
#include "source_model_lighting.hpp"
#include "sdkcompat.hpp"
#include "shadows.hpp"
#include "voxel_lighting.hpp"
#include "source_sun_lighting.hpp"
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>

namespace {
    // Pinned StudioRender025: queue code copies 0x1f0 bytes of DrawModelInfo_t.
    // The local-light tail is opaque because this adapter never changes Source lights.
    struct DrawInfo {
        void* studioHeader, *hardwareData, *decals;
        int skin, body, hitboxSet;
        void* clientEntity;
        int lod;
        void* colorMeshes;
        bool staticLighting;
        Vector ambientCube[6];
        int localLightCount;
        std::byte localLights[0x160];
    };
    static_assert(sizeof(DrawInfo) == 0x1f0);
    static_assert(offsetof(DrawInfo, colorMeshes) == 0x38);
    static_assert(offsetof(DrawInfo, staticLighting) == 0x40);
    static_assert(offsetof(DrawInfo, ambientCube) == 0x44);
    static_assert(offsetof(DrawInfo, localLights) == 0x90);
    struct Transform {
        float rows[3][4];
        Vector origin() const { return Vector(rows[0][3], rows[1][3], rows[2][3]); }
    };
    static_assert(sizeof(Transform) == 48);
    struct Color { float x, y, z, w; };
    using Cube = std::array<Color, 6>;
    const std::array<Vector, 6> cubeNormals{Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0),
        Vector(0,-1,0), Vector(0,0,1), Vector(0,0,-1)};
    using SetAmbient = void(__fastcall*)(void*, const Color*);
    using SetLocalLights = void(__fastcall*)(void*, int, const void*);
    using ComputeLighting = void(__fastcall*)(void*, const Vector&, const Vector*, bool, Vector&, Vector*);
    using DrawModel = void(__fastcall*)(void*, void*, const DrawInfo&, void*, float*, float*, const Vector&, int);
    using DrawStatic = void(__fastcall*)(void*, const DrawInfo&, const Transform&, int);
    using DrawArray = void(__fastcall*)(void*, const DrawInfo&, int, void*, int, int);
    constexpr int staticLightingFlag = 8, depthFlags = 0x1200;
    void* studio, *engineClient;
    void** originalTable;
    std::array<void*, 58> hookTable;
    SetAmbient setAmbient;
    SetLocalLights setLocalLights;
    ComputeLighting computeLighting;
    DrawModel originalDraw;
    DrawStatic originalStatic;
    DrawArray originalArray;
    DWORD ownerThread;
    bool installed, pinned, hasOverride;
    Cube overrideCube;
    float gridHeight;
    const char* closeMode = "never-installed";
    std::uint64_t draws, staticDraws, arrayInstances, sampled, unmapped, ownedSkipped, ownedDraws, depthSkipped;
    std::atomic<std::uint64_t> wrongThread;

    bool receives(int flags) {
        if (GetCurrentThreadId() != ownerThread) { ++wrongThread; return false; }
        if (!installed) return false;
        if (isDrawingSourceMesh() && !hasOverride) { ++ownedSkipped; return false; }
        if (flags & depthFlags) { ++depthSkipped; return false; }
        return true;
    }
    struct Light { float sky, block; bool mapped; SourceSunSample sun; };
    Light lighting(const Vector& position) {
        Light light{1, 0, false, {Vector(0,0,1), 0, 1}};
        light.mapped = sampleVoxelLighting(position, gridHeight, light.sky, light.block);
        if (light.mapped) ++sampled; else ++unmapped;
        if (sourceSunLightingIntersects(position, position, gridHeight)) {
            light.sun = sampleSourceSunLighting(position, gridHeight);
            light.mapped |= light.sun.transmission < 1;
        }
        return light;
    }
    bool changesLighting(const Light& light) {
        return light.sky != 1 || light.block != 0 || (light.sun.strength > 0 && light.sun.transmission < 1);
    }
    // SetAmbientLightColors updates both StudioRender and the material render context.
    // Single/static draws snapshot this context for queued rendering before returning.
    struct AmbientScope {
        void* renderer;
        Cube original, adjusted;
        bool overrideLights;
        int originalLightCount;
        alignas(8) std::byte originalLights[0x160];
        AmbientScope(void* renderer_, const DrawInfo& info, const Vector& position, const Light& light, bool owned = false)
            : renderer(renderer_), overrideLights(owned) {
            std::memcpy(original.data(), static_cast<unsigned char*>(renderer) + 0x80, sizeof(original));
            if (owned) {
                adjusted = overrideCube;
                // Verified SetLocalLights stores four 0x58-byte descriptors at +0xe0
                // and count at +0x240, and updates the material render context too.
                std::memcpy(originalLights, static_cast<unsigned char*>(renderer) + 0xe0, sizeof(originalLights));
                std::memcpy(&originalLightCount, static_cast<unsigned char*>(renderer) + 0x240, sizeof(int));
                setLocalLights(renderer, 0, nullptr);
            } else {
                adjusted = original;
                if (info.staticLighting) {
                    std::array<Vector, 6> ambient;
                    Vector unused;
                    // Non-null normal keeps local lights in discarded color output;
                    // pBoxColors recovers the cached ambient missing from baked draws.
                    computeLighting(engineClient, position, &cubeNormals[4], false, unused, ambient.data());
                    for (unsigned face = 0; face < 6; ++face)
                        adjusted[face] = {ambient[face].x, ambient[face].y, ambient[face].z, original[face].w};
                }
                for (unsigned face = 0; face < 6; ++face) {
                    auto& color = adjusted[face];
                    const auto sky = sourceSkyIrradiance(light.sun, cubeNormals[face], light.sky);
                    color.x = color.x * sky + light.block;
                    color.y = color.y * sky + light.block * 0.87f;
                    color.z = color.z * sky + light.block * 0.67f;
                }
            }
            setAmbient(renderer, adjusted.data());
        }
        ~AmbientScope() {
            setAmbient(renderer, original.data());
            if (overrideLights) setLocalLights(renderer, originalLightCount, originalLights);
        }
        DrawInfo receiverInfo(const DrawInfo& info) const {
            DrawInfo copy = info;
            // Baked vertex colors bypass the ambient cube; mapped static props use
            // the normal model lighting shader instead, preserving material shading.
            copy.colorMeshes = nullptr;
            copy.staticLighting = false;
            if (overrideLights) copy.localLightCount = 0;
            for (unsigned face = 0; face < 6; ++face)
                copy.ambientCube[face] = Vector(adjusted[face].x, adjusted[face].y, adjusted[face].z);
            return copy;
        }
    };
    void __fastcall draw(void* renderer, void* results, const DrawInfo& info, void* bones,
        float* flex, float* delayed, const Vector& origin, int flags) {
        if (!receives(flags)) return originalDraw(renderer, results, info, bones, flex, delayed, origin, flags);
        const bool owned = isDrawingSourceMesh();
        const auto light = owned ? Light{0, 0, true} : lighting(origin);
        if (!light.mapped || (!owned && !changesLighting(light)))
            return originalDraw(renderer, results, info, bones, flex, delayed, origin, flags);
        ++draws;
        if (owned) ++ownedDraws;
        AmbientScope ambient(renderer, info, origin, light, owned);
        auto copy = ambient.receiverInfo(info);
        originalDraw(renderer, results, copy, bones, flex, delayed, origin, flags & ~staticLightingFlag);
        // The pinned implementation writes its selected LOD back through the const info.
        const_cast<DrawInfo&>(info).lod = copy.lod;
    }

    void __fastcall drawStatic(void* renderer, const DrawInfo& info, const Transform& transform, int flags) {
        if (!receives(flags)) return originalStatic(renderer, info, transform, flags);
        const auto light = lighting(transform.origin());
        if (!light.mapped || !changesLighting(light)) return originalStatic(renderer, info, transform, flags);
        ++staticDraws;
        AmbientScope ambient(renderer, info, transform.origin(), light);
        auto copy = ambient.receiverInfo(info);
        originalStatic(renderer, copy, transform, flags & ~staticLightingFlag);
        const_cast<DrawInfo&>(info).lod = copy.lod;
    }

    void __fastcall drawArray(void* renderer, const DrawInfo& info, int count, void* instances, int stride, int flags) {
        if (!receives(flags)) return originalArray(renderer, info, count, instances, stride, flags);
        std::vector<Light> lights;
        lights.reserve(count);
        bool anyMapped = false;
        for (int i = 0; i < count; ++i) {
            const auto* transform = reinterpret_cast<const Transform*>(static_cast<unsigned char*>(instances) + i * stride);
            lights.push_back(lighting(transform->origin()));
            anyMapped |= lights.back().mapped && changesLighting(lights.back());
        }
        if (!anyMapped) return originalArray(renderer, info, count, instances, stride, flags);
        // The pinned array path ignores lighting flags. Route mapped instances through
        // the normal static-prop path, which supports disabling baked vertex lighting.
        for (int i = 0; i < count; ++i) {
            auto* instance = static_cast<unsigned char*>(instances) + i * stride;
            if (!lights[i].mapped || !changesLighting(lights[i])) {
                originalArray(renderer, info, 1, instance, stride, flags);
                continue;
            }
            ++arrayInstances;
            AmbientScope ambient(renderer, info, reinterpret_cast<const Transform*>(instance)->origin(), lights[i]);
            auto copy = ambient.receiverInfo(info);
            originalStatic(renderer, copy, *reinterpret_cast<const Transform*>(instance), flags & ~staticLightingFlag);
            const_cast<DrawInfo&>(info).lod = copy.lod;
        }
    }

    bool install() {
        if (installed) return true;
        if (!sdkcompat::supportedClient() || !sdkcompat::supportedEngine()) return false;
        studio = sdkcompat::studioRender();
        if (!studio) return false;
        auto* base = reinterpret_cast<unsigned char*>(GetModuleHandleW(L"studiorender.dll"));
        auto* table = *static_cast<void***>(studio);
        if (table != reinterpret_cast<void**>(base + 0x965d8)
            || table[21] != base + 0x65700 || table[33] != base + 0x61b60
            || table[22] != base + 0x65950 || table[34] != base + 0x62250 || table[50] != base + 0x62210) return false;
        const auto engineModule = GetModuleHandleW(L"engine.dll");
        const auto engineFactory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(engineModule, "CreateInterface"));
        engineClient = engineFactory("VEngineClient015", nullptr);
        const auto* engineBase = reinterpret_cast<unsigned char*>(engineModule);
        if (!engineClient || *static_cast<void***>(engineClient) != reinterpret_cast<void* const*>(engineBase + 0x39cfc8)
            || (*static_cast<void***>(engineClient))[67] != engineBase + 0x777a0) return false;
        computeLighting = reinterpret_cast<ComputeLighting>((*static_cast<void***>(engineClient))[67]);
        HMODULE ownModule;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<LPCWSTR>(&draw), &ownModule)) return false;
        pinned = true;
        originalTable = table;
        setAmbient = reinterpret_cast<SetAmbient>(table[21]);
        setLocalLights = reinterpret_cast<SetLocalLights>(table[22]);
        originalDraw = reinterpret_cast<DrawModel>(table[33]);
        originalStatic = reinterpret_cast<DrawStatic>(table[34]);
        originalArray = reinterpret_cast<DrawArray>(table[50]);
        std::memcpy(hookTable.data(), table - 1, sizeof(hookTable));
        hookTable[34] = reinterpret_cast<void*>(&draw);
        hookTable[35] = reinterpret_cast<void*>(&drawStatic);
        hookTable[51] = reinterpret_cast<void*>(&drawArray);
        installed = true;
        InterlockedExchangePointer(reinterpret_cast<void* volatile*>(studio), hookTable.data() + 1);
        closeMode = "installed";
        return true;
    }
    LUA_FUNCTION_STATIC(start) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Start Source model lighting on the client thread"), 0;
        const auto height = static_cast<float>(LUA->CheckNumber(1));
        if (!std::isfinite(height)) return LUA->ThrowError("Source model lighting requires a finite grid height"), 0;
        if (!install()) return LUA->ThrowError("Source model lighting requires the verified Windows x64 build and unmodified StudioRender025"), 0;
        gridHeight = height;
        return 0;
    }
    LUA_FUNCTION_STATIC(stop) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Stop Source model lighting on the client thread"), 0;
        releaseSourceModelLighting();
        return 0;
    }
    LUA_FUNCTION_STATIC(setOverride) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Override Source model lighting on the client thread"), 0;
        LUA->CheckType(1, GarrysMod::Lua::Type::Table);
        if (LUA->ObjLen(1) != 6) return LUA->ThrowError("Source model lighting override requires six ambient vectors"), 0;
        Cube colors;
        for (int i = 0; i < 6; ++i) {
            LUA->PushNumber(i + 1); LUA->RawGet(1);
            LUA->CheckType(-1, GarrysMod::Lua::Type::Vector);
            const auto color = LUA->GetVector(-1);
            LUA->Pop();
            if (!std::isfinite(color.x) || !std::isfinite(color.y) || !std::isfinite(color.z))
                return LUA->ThrowError("Source model ambient vectors must be finite"), 0;
            colors[i] = {color.x, color.y, color.z, 1};
        }
        overrideCube = colors;
        hasOverride = true;
        return 0;
    }
    LUA_FUNCTION_STATIC(clearOverride) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Clear Source model lighting override on the client thread"), 0;
        hasOverride = false;
        return 0;
    }
    LUA_FUNCTION_STATIC(report) {
        LUA->CreateTable();
        LUA->PushBool(installed); LUA->SetField(-2, "installed");
        LUA->PushBool(pinned); LUA->SetField(-2, "pinned");
        LUA->PushBool(hasOverride); LUA->SetField(-2, "hasOverride");
        LUA->PushString(closeMode); LUA->SetField(-2, "closeMode");
        const std::pair<const char*, std::uint64_t> values[] = {
            {"draws", draws}, {"staticDraws", staticDraws}, {"arrayInstances", arrayInstances},
            {"sampled", sampled}, {"unmapped", unmapped}, {"ownedSkipped", ownedSkipped}, {"ownedDraws", ownedDraws},
            {"depthSkipped", depthSkipped}, {"wrongThread", wrongThread.load()}};
        for (const auto& [name, value] : values) { LUA->PushNumber(static_cast<double>(value)); LUA->SetField(-2, name); }
        return 1;
    }
}
void registerSourceModelLighting(GarrysMod::Lua::ILuaBase* lua) {
    ownerThread = GetCurrentThreadId();
    lua->PushCFunction(start); lua->SetField(-2, "source_model_lighting_start");
    lua->PushCFunction(stop); lua->SetField(-2, "source_model_lighting_stop");
    lua->PushCFunction(report); lua->SetField(-2, "source_model_lighting_report");
    lua->PushCFunction(setOverride); lua->SetField(-2, "source_model_lighting_override");
    lua->PushCFunction(clearOverride); lua->SetField(-2, "source_model_lighting_clear_override");
}
void releaseSourceModelLighting() {
    hasOverride = false;
    if (!installed) return;
    installed = false;
    auto* previous = InterlockedCompareExchangePointer(reinterpret_cast<void* volatile*>(studio),
        originalTable, hookTable.data() + 1);
    closeMode = previous == hookTable.data() + 1 ? "restored" : "forwarding";
}
