#include <GarrysMod/Lua/Interface.h>
#include <cstring>
#include "framerate.hpp"

namespace {
    LUA_FUNCTION_STATIC(cap) {
        LUA->CheckType(1, GarrysMod::Lua::Type::ConVar);
        void* variable = LUA->GetUserType<void>(1, GarrysMod::Lua::Type::ConVar);
        auto** methods = *static_cast<void***>(variable);
        using Name = const char* (__fastcall*)(void*);
        using SetInt = void (__fastcall*)(void*, int);
        // GMod x86-64 adds RemoveFlags, GetFlags, GetFloat and GetInt to the SDK layout.
        // These slots were checked against engine.dll's ConVar dispatch table.
        const char* name = reinterpret_cast<Name>(methods[6])(variable);
        if (std::strcmp(name, "fps_max") != 0 && std::strcmp(name, "fps_max_nofocus") != 0)
            return LUA->ThrowError("The frame limiter accepts only fps_max and fps_max_nofocus"), 0;
        int target = static_cast<int>(LUA->CheckNumber(2));
        if (target < -1 || target > 1000) return LUA->ThrowError("Frame cap must be between -1 and 1000"), 0;
        reinterpret_cast<SetInt>(methods[16])(variable, target);
        return 0;
    }
}

void registerFramerate(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(cap);
    lua->SetField(-2, "cap");
}
