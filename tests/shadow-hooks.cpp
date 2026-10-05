// Test-only hooks for the owned game lab. This module never enters release payloads.
#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <tier1/interface.h>
#include <cstdint>

namespace {
    using ModelDraw = void(__fastcall*)(void*, const void*, const void*, void*);
    using MeshCount = void(__fastcall*)(void*, int);
    ModelDraw previousModel;
    MeshCount previousCount;
    void* renderer;
    void* studio;
    std::uint64_t modelCalls;

    void* replace(void** slot, void* callback) {
        DWORD protection;
        VirtualProtect(slot, sizeof(void*), PAGE_READWRITE, &protection);
        auto previous = InterlockedExchangePointer(slot, callback);
        DWORD ignored;
        VirtualProtect(slot, sizeof(void*), protection, &ignored);
        return previous;
    }
    void __fastcall model(void* self, const void* state, const void* info, void* bones) {
        ++modelCalls;
        previousModel(self, state, info, bones);
    }
    void __fastcall count(void* self, int value) { previousCount(self, value); }
    LUA_FUNCTION_STATIC(hookModel) {
        auto factory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(GetModuleHandleW(L"engine.dll"), "CreateInterface"));
        renderer = factory("VEngineModel016", nullptr);
        previousModel = reinterpret_cast<ModelDraw>(replace(*static_cast<void***>(renderer) + 20, reinterpret_cast<void*>(model)));
        return 0;
    }
    LUA_FUNCTION_STATIC(hookStudio) {
        auto factory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(GetModuleHandleW(L"studiorender.dll"), "CreateInterface"));
        studio = factory("VStudioRender025", nullptr);
        previousCount = reinterpret_cast<MeshCount>(replace(*static_cast<void***>(studio) + 54, reinterpret_cast<void*>(count)));
        return 0;
    }
    LUA_FUNCTION_STATIC(restore) {
        if (renderer) {
            auto slot = *static_cast<void***>(renderer) + 20;
            if (*slot != reinterpret_cast<void*>(model)) return LUA->ThrowError("The fixture no longer owns the model callback"), 0;
            replace(slot, reinterpret_cast<void*>(previousModel));
            renderer = nullptr;
        }
        if (studio) {
            replace(*static_cast<void***>(studio) + 54, reinterpret_cast<void*>(previousCount));
            studio = nullptr;
        }
        return 0;
    }
    LUA_FUNCTION_STATIC(stats) { LUA->PushNumber(static_cast<double>(modelCalls)); return 1; }
}
GMOD_MODULE_OPEN() {
    LUA->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
    LUA->CreateTable();
    LUA->PushCFunction(hookModel); LUA->SetField(-2, "hook_model");
    LUA->PushCFunction(hookStudio); LUA->SetField(-2, "hook_studio");
    LUA->PushCFunction(restore); LUA->SetField(-2, "restore");
    LUA->PushCFunction(stats); LUA->SetField(-2, "model_calls");
    LUA->SetField(-2, "garrycraft_shadow_test");
    LUA->Pop();
    return 0;
}
GMOD_MODULE_CLOSE() { return 0; }
