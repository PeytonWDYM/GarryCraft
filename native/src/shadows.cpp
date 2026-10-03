#include <GarrysMod/Lua/Interface.h>
#include <basehandle.h>
#include <icliententitylist.h>
#include <iclientunknown.h>
#include "sdkcompat.hpp"
#include "shadows.hpp"
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <vector>

namespace {
    struct Matrix { float values[16]; };
    struct MeshHandle { std::uint32_t magic; void* mesh; };
    struct Batch { void* mesh; void* material; Matrix matrix; };
    struct Proxy {
        CBaseHandle entity;
        void* renderable;
        std::vector<Batch> batches;
        std::vector<int> references;
    };
    struct Receiver { CBaseHandle entity; int reference; };
    using ReceiveQuery = bool(__fastcall*)(void*, int);
    using ReceiverAdd = void(__fastcall*)(void*, unsigned short, void*, int);
    using ReceiverCull = bool(__fastcall*)(void*, unsigned short, void*, void*);
    using ModelInstance = unsigned short(__fastcall*)(void*);
    using ModelShadowAdd = void(__fastcall*)(void*, unsigned short, unsigned short);
    using ModelShadowRemove = void(__fastcall*)(void*, unsigned short);
    using ShadowDraw = void(__fastcall*)(void*, void*, const void*, void*);
    using ModelDraw = void(__fastcall*)(void*, const void*, const void*, void*);
    using MeshCount = void(__fastcall*)(void*, int);
    using MeshOverride = void(__fastcall*)(void*, int, void*, void*, const Matrix*);
    std::unordered_map<void*, Proxy> proxies;
    std::unordered_map<void*, Receiver> receivers;
    IClientEntityList* entities;
    void* clientShadows;
    void* engineShadows;
    void* materialSystem;
    using GetContext = void*(__fastcall*)(void*);
    GetContext getContext;
    void** originalReceiverTable;
    std::array<void*, 44> receiverHookTable;
    void** originalRenderableTable;
    std::array<void*, 47> renderableHookTable;
    ReceiveQuery originalReceiveQuery;
    ReceiverAdd originalReceiverAdd;
    ReceiverCull cullReceiver;
    ModelShadowAdd addModelShadow;
    ModelShadowRemove removeModelShadows;
    void* studio;
    void* modelRenderer;
    void** originalTable;
    std::array<void*, 27> hookTable;
    ShadowDraw originalShadow;
    ModelDraw originalModel;
    MeshCount setMeshCount;
    MeshOverride setMesh;
    DWORD ownerThread;
    bool installed;
    bool pinned;
    const char* closeMode = "none";
    std::uint64_t castDraws, castGroups, modelDraws, invalidMeshes, staleEntities;
    std::uint64_t depthDraws, customDepthDraws, invalidDepthMeshState;
    unsigned int modelDrawFlags;
    std::uint64_t receiverLinks, receiverCulled, receiverQueries, receiverForwarding;
    std::uint64_t receiverDraws, receiverInstanceMismatch, receiverMissingMaterial, receiverProxyMismatch;
    unsigned int receiverDrawFlags;
    std::atomic<std::uint64_t> wrongThread;
    static_assert(sizeof(CBaseHandle) == 4 && offsetof(MeshHandle, mesh) == 8 && sizeof(Matrix) == 64);

    // Studio AddShadow rejects a nonnull material proxy whenever a call queue is active.
    // These are the same verified GetRenderContext/GetCallQueue dispatches used by Source's check.
    bool queueSafeReceivers() {
        if (!getContext) return false;
        void* context = getContext(materialSystem);
        if (!context) return false;
        auto* table = *static_cast<void***>(context);
        using RefOperation = void(__fastcall*)(void*);
        reinterpret_cast<RefOperation>(table[0])(context);
        bool immediate = !reinterpret_cast<GetContext>(table[145])(context);
        reinterpret_cast<RefOperation>(table[1])(context);
        return immediate;
    }

    Matrix identity() { return {{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1}}; }

    // GMod's GetRenderMesh uses these same studio extension slots. The engine queues a copy of this state.
    // Preserve active overrides so the next model draw cannot inherit a GarryCraft mesh.
    class OverrideScope {
        struct Saved { void* mesh; void* material; Matrix matrix; };
        std::array<Saved, 4> saved{};
        int count;
    public:
        OverrideScope() {
            auto* bytes = static_cast<const unsigned char*>(studio);
            std::memcpy(&count, bytes + 0x388, sizeof(count));
            for (int i = 0; i < count; ++i) {
                std::memcpy(&saved[i].mesh, bytes + 0x390 + i * 8, 8);
                std::memcpy(&saved[i].material, bytes + 0x3b0 + i * 8, 8);
                std::memcpy(&saved[i].matrix, bytes + 0x3d0 + i * 64, 64);
            }
        }
        ~OverrideScope() {
            for (int i = 0; i < count; ++i) setMesh(studio, i, saved[i].mesh, saved[i].material, &saved[i].matrix);
            setMeshCount(studio, count);
        }
    };

    Proxy* findProxy(void* renderable) {
        auto found = proxies.find(renderable);
        if (found == proxies.end()) return nullptr;
        auto* entity = entities->GetClientUnknownFromHandle(found->second.entity);
        if (!entity || entity->GetClientRenderable() != renderable) { ++staleEntities; return nullptr; }
        return &found->second;
    }

    void __fastcall drawShadow(void* renderer, void* renderable, const void* info, void* bones) {
        if (GetCurrentThreadId() != ownerThread) {
            ++wrongThread;
            originalShadow(renderer, renderable, info, bones);
            return;
        }
        auto* proxy = findProxy(renderable);
        if (!proxy) { originalShadow(renderer, renderable, info, bones); return; }
        OverrideScope restore;
        for (size_t first = 0; first < proxy->batches.size(); first += 4) {
            int count = static_cast<int>(std::min(size_t(4), proxy->batches.size() - first));
            setMeshCount(studio, count);
            for (int i = 0; i < count; ++i) {
                const auto& batch = proxy->batches[first + i];
                // Lua references prevent collection. The owner unregisters before explicit IMesh:Destroy.
                setMesh(studio, i, batch.mesh, batch.material, &batch.matrix);
            }
            // Source keeps its shadow atlas target, projection, alpha-test material and receiver bookkeeping.
            originalShadow(renderer, renderable, info, bones);
            ++castGroups;
        }
        ++castDraws;
    }

    void __fastcall drawModel(void* renderer, const void* state, const void* info, void* bones) {
        if (GetCurrentThreadId() == ownerThread) {
            void* renderable;
            // ModelRenderInfo_t::pRenderable follows the two 12-byte vectors in the verified x64 layout.
            std::memcpy(&renderable, static_cast<const unsigned char*>(info) + 24, 8);
            if (findProxy(renderable)) {
                ++modelDraws;
                unsigned int flags;
                // These are raw ModelRenderInfo_t flags at engine slot 20, not Lua RenderOverride flags.
                std::memcpy(&flags, static_cast<const unsigned char*>(info) + 0x40, sizeof(flags));
                modelDrawFlags |= flags;
                if (flags & 0x40000000u) {
                    ++depthDraws;
                    int count;
                    std::memcpy(&count, static_cast<const unsigned char*>(studio) + 0x388, sizeof(count));
                    if (count >= 1 && count <= 4) ++customDepthDraws;
                    else if (count < 0 || count > 4) ++invalidDepthMeshState;
                }
            }
            auto found = receivers.find(renderable);
            if (found != receivers.end()) {
                auto* entity = entities->GetClientUnknownFromHandle(found->second.entity);
                if (entity && entity->GetClientRenderable() == renderable) {
                    ++receiverDraws;
                    if (!queueSafeReceivers()) {
                        const auto instance = reinterpret_cast<ModelInstance>(originalRenderableTable[33])(renderable);
                        if (instance != 0xffff) removeModelShadows(engineShadows, instance);
                    }
                    unsigned short instance;
                    unsigned int flags;
                    std::memcpy(&instance, static_cast<const unsigned char*>(info) + 0x54, 2);
                    std::memcpy(&flags, static_cast<const unsigned char*>(info) + 0x40, 4);
                    receiverDrawFlags |= flags;
                    if (instance != reinterpret_cast<ModelInstance>(originalRenderableTable[33])(renderable)) ++receiverInstanceMismatch;
                }
            }
        } else ++wrongThread;
        originalModel(renderer, state, info, bones);
    }

    // C_SENT_anim rejects ordinary studio receivers before leaf enumeration. Preserve its effect gates
    // and all flashlight queries. Only registered instances receive the ordinary-shadow opt-in.
    bool __fastcall receiveQuery(void* renderable, int flags) {
        if (GetCurrentThreadId() != ownerThread) {
            ++wrongThread;
            return originalReceiveQuery(renderable, flags);
        }
        if ((flags & 3) != 2) return originalReceiveQuery(renderable, flags);
        auto found = receivers.find(renderable);
        if (found == receivers.end()) return originalReceiveQuery(renderable, flags);
        auto* entity = entities->GetClientUnknownFromHandle(found->second.entity);
        if (!entity || entity->GetClientRenderable() != renderable) {
            ++staleEntities;
            // This virtual callback proves the instance is live. Restore only our table on a stale registration.
            InterlockedCompareExchangePointer(reinterpret_cast<void* volatile*>(renderable),
                originalRenderableTable, renderableHookTable.data() + 1);
            return originalReceiveQuery(renderable, flags);
        }
        ++receiverQueries;
        if (!queueSafeReceivers()) return false;
        const auto effects = *reinterpret_cast<const unsigned int*>(static_cast<const unsigned char*>(renderable) + 0xbc);
        return !(effects & (32 | 64 | 8192));
    }

    bool supportedReceiver(const CBaseHandle& handle, void* renderable) {
        auto* table = *static_cast<void***>(renderable);
        if (table == originalRenderableTable) return true;
        auto found = receivers.find(renderable);
        return table == renderableHookTable.data() + 1 && found != receivers.end() && found->second.entity == handle;
    }

    // Source's client gate admits only flashlight shadows on studio models. The engine API and
    // studio shadow material support ordinary RTT shadows. Extend that gate only for owned receivers.
    void __fastcall addReceiver(void* manager, unsigned short shadow, void* renderable, int type) {
        originalReceiverAdd(manager, shadow, renderable, type);
        if (GetCurrentThreadId() != ownerThread) { ++wrongThread; return; }
        auto found = receivers.find(renderable);
        if (found == receivers.end() || type != 2 || !queueSafeReceivers()) return;
        auto* receiver = entities->GetClientUnknownFromHandle(found->second.entity);
        if (!receiver || receiver->GetClientRenderable() != renderable) { ++staleEntities; return; }
        auto* bytes = static_cast<const unsigned char*>(manager);
        if (shadow >= *reinterpret_cast<const int*>(bytes + 0x40)
            || shadow > *reinterpret_cast<const unsigned short*>(bytes + 0x52)) return;
        auto* records = *reinterpret_cast<const unsigned char* const*>(bytes + 0x38);
        auto* record = records + static_cast<size_t>(shadow) * 0xb0;
        if (*reinterpret_cast<const unsigned short*>(record + 0xa8) == shadow
            && *reinterpret_cast<const unsigned short*>(record + 0xaa) != shadow) return;
        const auto flags = *reinterpret_cast<const unsigned int*>(record + 8);
        if ((flags & 1) || !(flags & 2)) return; // Flashlights keep Source's original registration path.
        CBaseHandle casterHandle;
        std::memcpy(&casterHandle, record, sizeof(casterHandle));
        auto* caster = entities->GetClientUnknownFromHandle(casterHandle);
        if (!caster || caster->GetClientRenderable() == renderable) return;
        auto* table = *static_cast<void***>(renderable);
        using Receive = bool(__fastcall*)(void*, int);
        if (!reinterpret_cast<Receive>(table[23])(renderable, 3)) return;
        if (cullReceiver(manager, shadow, renderable, caster->GetClientRenderable())) { ++receiverCulled; return; }
        using CreateInstance = void(__fastcall*)(void*);
        reinterpret_cast<CreateInstance>(table[32])(renderable);
        const auto instance = reinterpret_cast<ModelInstance>(table[33])(renderable);
        const auto engineHandle = *reinterpret_cast<const unsigned short*>(record + 4);
        if (instance == 0xffff || engineHandle == 0xffff) return;
        auto* engineRecords = *reinterpret_cast<const unsigned char* const*>(static_cast<const unsigned char*>(engineShadows) + 0x10);
        auto* engineRecord = engineRecords + static_cast<size_t>(engineHandle) * 0x160;
        if (!*reinterpret_cast<void* const*>(engineRecord + 0x78)) ++receiverMissingMaterial;
        if (*reinterpret_cast<const std::uintptr_t*>(engineRecord + 0x80) != shadow) ++receiverProxyMismatch;
        addModelShadow(engineShadows, engineHandle, instance);
        ++receiverLinks;
    }

    void removeReceiver(GarrysMod::Lua::ILuaBase* lua, void* renderable, const Receiver& receiver) {
        auto* entity = entities->GetClientUnknownFromHandle(receiver.entity);
        if (entity && entity->GetClientRenderable() == renderable) {
            auto* previous = InterlockedCompareExchangePointer(reinterpret_cast<void* volatile*>(renderable),
                originalRenderableTable, renderableHookTable.data() + 1);
            if (previous != renderableHookTable.data() + 1) ++receiverForwarding;
            const auto instance = reinterpret_cast<ModelInstance>(originalRenderableTable[33])(renderable);
            if (instance != 0xffff) removeModelShadows(engineShadows, instance);
        }
        // Source owns the model instance and destroys it with the entity.
        lua->ReferenceFree(receiver.reference);
    }

    void registerReceiver(GarrysMod::Lua::ILuaBase* lua, const CBaseHandle& handle, void* renderable) {
        if (!queueSafeReceivers()) return;
        auto found = receivers.find(renderable);
        if (found != receivers.end()) {
            if (found->second.entity == handle) return;
            // A recycled C_SENT_anim has its constructor's original table. Do not write through the stale handle.
            removeReceiver(lua, renderable, found->second);
            receivers.erase(found);
        }
        lua->Push(1);
        receivers.emplace(renderable, Receiver{handle, lua->ReferenceCreate()});
        InterlockedExchangePointer(reinterpret_cast<void* volatile*>(renderable), renderableHookTable.data() + 1);
    }

    bool install() {
        if (installed) return true;
        if (!sdkcompat::supportedClient() || !sdkcompat::supportedEngine()) return false;
        studio = sdkcompat::studioRender();
        if (!studio) return false;
        auto clientFactory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(GetModuleHandleW(L"client.dll"), "CreateInterface"));
        auto engineFactory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(GetModuleHandleW(L"engine.dll"), "CreateInterface"));
        if (!clientFactory || !engineFactory) return false;
        entities = static_cast<IClientEntityList*>(clientFactory("VClientEntityList003", nullptr));
        modelRenderer = engineFactory("VEngineModel016", nullptr);
        engineShadows = engineFactory("VEngineShadowMgr002", nullptr);
        materialSystem = sdkcompat::materialSystem();
        if (materialSystem) getContext = reinterpret_cast<GetContext>((*static_cast<void***>(materialSystem))[102]);
        if (!entities || !modelRenderer || !engineShadows) return false;
        auto* clientBase = reinterpret_cast<unsigned char*>(GetModuleHandleW(L"client.dll"));
        // The verified static constructor initializes this CClientShadowMgr instance and its 43-method table.
        clientShadows = clientBase + 0xa208a0;
        originalReceiverTable = *static_cast<void***>(clientShadows);
        originalRenderableTable = reinterpret_cast<void**>(clientBase + 0x661740);
        auto* engineShadowTable = *static_cast<void***>(engineShadows);
        originalTable = *static_cast<void***>(modelRenderer);
        auto* studioTable = *static_cast<void***>(studio);
        auto* engineBase = reinterpret_cast<unsigned char*>(GetModuleHandleW(L"engine.dll"));
        auto* studioBase = reinterpret_cast<unsigned char*>(GetModuleHandleW(L"studiorender.dll"));
        // Reject other hooks as well as changed ABI before cloning the instance's verified 26-method table.
        if (originalTable[13] != engineBase + 0xfbf10 || originalTable[20] != engineBase + 0xff1c0
            || studioTable[54] != studioBase + 0x627d0 || studioTable[55] != studioBase + 0x62780
            || originalReceiverTable != reinterpret_cast<void**>(clientBase + 0x6ba438)
            || originalReceiverTable[25] != clientBase + 0x214050
            || originalRenderableTable[23] != clientBase + 0x1ba670
            || originalRenderableTable[32] != clientBase + 0x1b15f0
            || originalRenderableTable[33] != clientBase + 0x65910
            || engineShadowTable[10] != engineBase + 0x13b0e0
            || engineShadowTable[11] != engineBase + 0x141b10) return false;
        // A later hook can retain our callback address. Keep its forwarding code and table alive until process exit.
        HMODULE module;
        if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<LPCWSTR>(&drawShadow), &module)) return false;
        pinned = true;
        originalReceiveQuery = reinterpret_cast<ReceiveQuery>(originalRenderableTable[23]);
        std::copy_n(originalRenderableTable - 1, renderableHookTable.size(), renderableHookTable.begin());
        renderableHookTable[24] = reinterpret_cast<void*>(receiveQuery);
        originalReceiverAdd = reinterpret_cast<ReceiverAdd>(originalReceiverTable[25]);
        cullReceiver = reinterpret_cast<ReceiverCull>(clientBase + 0x218990);
        addModelShadow = reinterpret_cast<ModelShadowAdd>(engineShadowTable[10]);
        removeModelShadows = reinterpret_cast<ModelShadowRemove>(engineShadowTable[11]);
        std::copy_n(originalReceiverTable - 1, receiverHookTable.size(), receiverHookTable.begin());
        receiverHookTable[26] = reinterpret_cast<void*>(addReceiver);
        originalShadow = reinterpret_cast<ShadowDraw>(originalTable[13]);
        originalModel = reinterpret_cast<ModelDraw>(originalTable[20]);
        setMeshCount = reinterpret_cast<MeshCount>(studioTable[54]);
        setMesh = reinterpret_cast<MeshOverride>(studioTable[55]);
        std::copy_n(originalTable - 1, hookTable.size(), hookTable.begin());
        hookTable[14] = reinterpret_cast<void*>(drawShadow);
        hookTable[21] = reinterpret_cast<void*>(drawModel);
        InterlockedExchangePointer(reinterpret_cast<void* volatile*>(modelRenderer), hookTable.data() + 1);
        InterlockedExchangePointer(reinterpret_cast<void* volatile*>(clientShadows), receiverHookTable.data() + 1);
        installed = true;
        closeMode = "active";
        return true;
    }

    void freeProxy(GarrysMod::Lua::ILuaBase* lua, Proxy& proxy) {
        for (int reference : proxy.references) lua->ReferenceFree(reference);
    }
    void clear(GarrysMod::Lua::ILuaBase* lua) {
        for (auto& [renderable, proxy] : proxies) freeProxy(lua, proxy);
        proxies.clear();
        for (const auto& [renderable, receiver] : receivers) removeReceiver(lua, renderable, receiver);
        receivers.clear();
    }

    LUA_FUNCTION_STATIC(update) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Update Source shadows on the client thread"), 0;
        LUA->CheckType(1, GarrysMod::Lua::Type::Entity);
        LUA->CheckType(2, GarrysMod::Lua::Type::Table);
        if (!install()) return LUA->ThrowError("Source mesh shadows require the verified Windows x64 engine build and unmodified render interfaces"), 0;
        auto* handle = LUA->GetUserType<CBaseHandle>(1, GarrysMod::Lua::Type::Entity);
        auto* entity = handle ? entities->GetClientUnknownFromHandle(*handle) : nullptr;
        if (!entity) return LUA->ThrowError("Source shadow proxy has no live entity handle"), 0;
        void* renderable = entity->GetClientRenderable();
        if (!supportedReceiver(*handle, renderable))
            return LUA->ThrowError("Source receivers require an unmodified C_SENT_anim renderable"), 0;
        using GetModel = const void*(__fastcall*)(void*);
        auto getModel = reinterpret_cast<GetModel>((*static_cast<void***>(renderable))[9]);
        auto* model = static_cast<const unsigned char*>(getModel(renderable));
        if (!model || *reinterpret_cast<const int*>(model + 0x48) != 3)
            return LUA->ThrowError("Source shadow proxy requires a studio model"), 0;
        unsigned count = LUA->ObjLen(2);
        if (!count || count > 256) return LUA->ThrowError("Source shadow proxy requires 1 through 256 mesh batches"), 0;
        std::array<Batch, 256> validated;
        // Validate the complete update before taking references or replacing an existing registration.
        for (unsigned i = 1; i <= count; ++i) {
            LUA->PushNumber(i); LUA->GetTable(2); LUA->CheckType(-1, GarrysMod::Lua::Type::Table);
            LUA->GetField(-1, "mesh"); LUA->CheckType(-1, GarrysMod::Lua::Type::IMesh);
            auto* mesh = LUA->GetUserType<MeshHandle>(-1, GarrysMod::Lua::Type::IMesh); LUA->Pop();
            LUA->GetField(-1, "material"); LUA->CheckType(-1, GarrysMod::Lua::Type::Material);
            void* material = LUA->GetUserType<void>(-1, GarrysMod::Lua::Type::Material); LUA->Pop();
            Matrix matrix = identity();
            LUA->GetField(-1, "matrix");
            if (!LUA->IsType(-1, GarrysMod::Lua::Type::Nil)) {
                LUA->CheckType(-1, GarrysMod::Lua::Type::Matrix);
                auto* value = LUA->GetUserType<Matrix>(-1, GarrysMod::Lua::Type::Matrix);
                if (!value) return LUA->ThrowError("Source shadow matrix is unavailable"), 0;
                matrix = *value;
            }
            LUA->Pop(2);
            if (!mesh || mesh->magic != 1 || !mesh->mesh || !material) {
                ++invalidMeshes;
                return LUA->ThrowError("Source shadow mesh or material is unavailable"), 0;
            }
            for (float value : matrix.values) if (!std::isfinite(value)) return LUA->ThrowError("Source shadow matrix must be finite"), 0;
            validated[i - 1] = {mesh->mesh, material, matrix};
        }
        Proxy replacement{*handle, renderable};
        replacement.batches.assign(validated.begin(), validated.begin() + count);
        replacement.references.reserve(1 + count * 2);
        LUA->Push(1); replacement.references.push_back(LUA->ReferenceCreate());
        for (unsigned i = 1; i <= count; ++i) {
            LUA->PushNumber(i); LUA->GetTable(2);
            LUA->GetField(-1, "mesh"); replacement.references.push_back(LUA->ReferenceCreate());
            LUA->GetField(-1, "material"); replacement.references.push_back(LUA->ReferenceCreate());
            LUA->Pop();
        }
        auto found = proxies.find(renderable);
        if (found != proxies.end()) freeProxy(LUA, found->second);
        proxies.insert_or_assign(renderable, std::move(replacement));
        registerReceiver(LUA, *handle, renderable);
        return 0;
    }

    LUA_FUNCTION_STATIC(remove) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Remove Source shadows on the client thread"), 0;
        LUA->CheckType(1, GarrysMod::Lua::Type::Entity);
        auto* handle = LUA->GetUserType<CBaseHandle>(1, GarrysMod::Lua::Type::Entity);
        if (!handle) return 0;
        for (auto found = proxies.begin(); found != proxies.end(); ++found) {
            if (found->second.entity != *handle) continue;
            freeProxy(LUA, found->second); proxies.erase(found); break;
        }
        for (auto found = receivers.begin(); found != receivers.end(); ++found) {
            if (found->second.entity != *handle) continue;
            removeReceiver(LUA, found->first, found->second); receivers.erase(found); break;
        }
        return 0;
    }
    LUA_FUNCTION_STATIC(receive) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Update Source receivers on the client thread"), 0;
        LUA->CheckType(1, GarrysMod::Lua::Type::Entity);
        LUA->CheckType(2, GarrysMod::Lua::Type::Bool);
        if (!install()) return LUA->ThrowError("Source receivers require the verified Windows x64 engine build and unmodified interfaces"), 0;
        auto* handle = LUA->GetUserType<CBaseHandle>(1, GarrysMod::Lua::Type::Entity);
        auto* entity = handle ? entities->GetClientUnknownFromHandle(*handle) : nullptr;
        if (!entity) return LUA->ThrowError("Source receiver has no live entity handle"), 0;
        void* renderable = entity->GetClientRenderable();
        auto found = receivers.find(renderable);
        if (!LUA->GetBool(2)) {
            if (found != receivers.end()) { removeReceiver(LUA, renderable, found->second); receivers.erase(found); }
            return 0;
        }
        if (!queueSafeReceivers())
            return LUA->ThrowError("Source RTT model receivers do not support queued rendering"), 0;
        if (!supportedReceiver(*handle, renderable))
            return LUA->ThrowError("Source receivers require an unmodified C_SENT_anim renderable"), 0;
        using GetModel = const void*(__fastcall*)(void*);
        auto* table = *static_cast<void***>(renderable);
        auto* model = static_cast<const unsigned char*>(reinterpret_cast<GetModel>(table[9])(renderable));
        if (!model || *reinterpret_cast<const int*>(model + 0x48) != 3)
            return LUA->ThrowError("Source receiver requires a studio model"), 0;
        registerReceiver(LUA, *handle, renderable);
        return 0;
    }
    LUA_FUNCTION_STATIC(clearAll) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Clear Source shadows on the client thread"), 0;
        clear(LUA); return 0;
    }
    LUA_FUNCTION_STATIC(stats) {
        LUA->CreateTable();
        LUA->PushBool(installed); LUA->SetField(-2, "installed");
        LUA->PushBool(pinned); LUA->SetField(-2, "pinned");
        LUA->PushBool(installed && queueSafeReceivers()); LUA->SetField(-2, "rttReceiversSupported");
        LUA->PushString(closeMode); LUA->SetField(-2, "closeMode");
        const std::pair<const char*, std::uint64_t> values[] = {{"registered", proxies.size()}, {"castDraws", castDraws},
            {"registeredReceivers", receivers.size()}, {"receiverLinks", receiverLinks}, {"receiverCulled", receiverCulled},
            {"receiverQueries", receiverQueries}, {"receiverForwarding", receiverForwarding},
            {"receiverDraws", receiverDraws}, {"receiverInstanceMismatch", receiverInstanceMismatch},
            {"receiverMissingMaterial", receiverMissingMaterial}, {"receiverProxyMismatch", receiverProxyMismatch},
            {"receiverDrawFlags", receiverDrawFlags},
            {"castGroups", castGroups}, {"modelDraws", modelDraws}, {"modelDrawFlags", modelDrawFlags},
            {"depthDraws", depthDraws}, {"customDepthDraws", customDepthDraws}, {"invalidDepthMeshState", invalidDepthMeshState},
            {"invalidMeshes", invalidMeshes},
            {"staleEntities", staleEntities}, {"wrongThread", wrongThread.load()}};
        for (const auto& [name, value] : values) { LUA->PushNumber(static_cast<double>(value)); LUA->SetField(-2, name); }
        LUA->CreateTable();
        unsigned index = 0;
        for (const auto& [renderable, proxy] : proxies) {
            if (!findProxy(renderable)) continue;
            using ShadowHandle = unsigned short(__fastcall*)(void*);
            using CastType = int(__fastcall*)(void*);
            auto* table = *static_cast<void***>(renderable);
            LUA->PushNumber(++index); LUA->CreateTable();
            LUA->PushNumber(proxy.entity.ToInt()); LUA->SetField(-2, "entityHandle");
            LUA->PushNumber(reinterpret_cast<ShadowHandle>(table[7])(renderable)); LUA->SetField(-2, "shadowHandle");
            LUA->PushNumber(reinterpret_cast<CastType>(table[31])(renderable)); LUA->SetField(-2, "castType");
            LUA->PushNumber(static_cast<double>(proxy.batches.size())); LUA->SetField(-2, "batches");
            LUA->SetTable(-3);
        }
        LUA->SetField(-2, "proxies");
        return 1;
    }
}

void registerShadows(GarrysMod::Lua::ILuaBase* lua) {
    ownerThread = GetCurrentThreadId();
    lua->PushCFunction(update); lua->SetField(-2, "shadow_update");
    lua->PushCFunction(receive); lua->SetField(-2, "shadow_receive");
    lua->PushCFunction(remove); lua->SetField(-2, "shadow_remove");
    lua->PushCFunction(clearAll); lua->SetField(-2, "shadow_clear");
    lua->PushCFunction(stats); lua->SetField(-2, "shadow_stats");
}
void releaseShadows(GarrysMod::Lua::ILuaBase* lua) {
    clear(lua);
    if (installed) {
        auto* previous = InterlockedCompareExchangePointer(
            reinterpret_cast<void* volatile*>(modelRenderer), originalTable, hookTable.data() + 1);
        auto* receiverPrevious = InterlockedCompareExchangePointer(
            reinterpret_cast<void* volatile*>(clientShadows), originalReceiverTable, receiverHookTable.data() + 1);
        closeMode = previous == hookTable.data() + 1 && receiverPrevious == receiverHookTable.data() + 1 ? "restored" : "forwarding";
        installed = false;
    }
}
