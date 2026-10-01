#include <GarrysMod/Lua/Interface.h>
#include "mailbox.hpp"
#include <exception>
#ifdef GARRYCRAFT_CLIENT
#include "textures.hpp"
#include "framerate.hpp"
#include "meshes.hpp"
#endif

namespace {
    Mailbox bridge;

    LUA_FUNCTION_STATIC(refresh) {
        DEVMODEW mode{};
        mode.dmSize = sizeof(mode);
        if (!EnumDisplaySettingsW(nullptr, ENUM_CURRENT_SETTINGS, &mode))
            return LUA->ThrowError("Cannot read display refresh rate"), 0;
        LUA->PushNumber(mode.dmDisplayFrequency);
        return 1;
    }

    LUA_FUNCTION_STATIC(clock) {
        LARGE_INTEGER counter, frequency;
        QueryPerformanceCounter(&counter);
        QueryPerformanceFrequency(&frequency);
        LUA->PushNumber(static_cast<double>(counter.QuadPart) / frequency.QuadPart);
        return 1;
    }

    LUA_FUNCTION_STATIC(open) {
        const char* path = LUA->CheckString(1);
        int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, nullptr, 0);
        if (!count) return LUA->ThrowError("Bridge path must be UTF-8"), 0;
        std::wstring wide(count, L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide.data(), count);
        wide.pop_back();
        try { bridge.open(wide); }
        catch (const std::exception& error) { LUA->ThrowError(error.what()); }
        return 0;
    }

    LUA_FUNCTION_STATIC(send) {
        unsigned lane = static_cast<unsigned>(LUA->CheckNumber(1));
        LUA->CheckType(2, GarrysMod::Lua::Type::String);
        unsigned length;
        const char* payload = LUA->GetString(2, &length);
        try { bridge.send(lane, std::string_view(payload, length)); }
        catch (const std::exception& error) { LUA->ThrowError(error.what()); }
        return 0;
    }

    LUA_FUNCTION_STATIC(receive) {
        unsigned lane = static_cast<unsigned>(LUA->CheckNumber(1));
        try {
            auto payload = bridge.receive(lane);
            if (payload) LUA->PushString(payload->data(), static_cast<unsigned>(payload->size()));
            else LUA->PushNil();
        } catch (const std::exception& error) { LUA->ThrowError(error.what()); }
        return 1;
    }
}

GMOD_MODULE_OPEN() {
    LUA->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
    LUA->CreateTable();
    LUA->PushCFunction(refresh);
    LUA->SetField(-2, "refresh");
#ifdef GARRYCRAFT_CLIENT
    registerTextures(LUA);
    registerFramerate(LUA);
    registerMeshes(LUA);
#endif
    LUA->PushCFunction(clock);
    LUA->SetField(-2, "clock");
    LUA->PushCFunction(open);
    LUA->SetField(-2, "open");
    LUA->PushCFunction(send);
    LUA->SetField(-2, "send");
    LUA->PushCFunction(receive);
    LUA->SetField(-2, "receive");
    LUA->SetField(-2, "garrycraft_bridge");
    LUA->Pop();
    return 0;
}

GMOD_MODULE_CLOSE() {
#ifdef GARRYCRAFT_CLIENT
    releaseTextures();
    releaseMeshes(LUA);
#endif
    bridge.close();
    return 0;
}
