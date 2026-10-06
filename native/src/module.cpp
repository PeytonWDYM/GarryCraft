#include <GarrysMod/Lua/Interface.h>
#include "mailbox.hpp"
#include "platform.hpp"
#include <exception>
#ifndef GARRYCRAFT_CLIENT
#include "runtime.hpp"
#include "geometry.hpp"
#endif
#ifdef GARRYCRAFT_CLIENT
#include "textures.hpp"
#include "framerate.hpp"
#include "meshes.hpp"
#include "receiver.hpp"
#include "packets.hpp"
#include "shadows.hpp"
#endif

namespace {
    Mailbox bridge;
#ifdef GARRYCRAFT_CLIENT
    Receiver receiver;
    LUA_FUNCTION_STATIC(receiveRender) {
        unsigned lane = static_cast<unsigned>(LUA->CheckNumber(1));
        if (lane < 4 || lane > 7) return LUA->ThrowError("Render lane must be 4 through 7"), 0;
        try {
            auto payload = receiver.take(lane);
            if (!payload) { LUA->PushNil(); return 1; }
            pushPacket(LUA, std::move(*payload));
        } catch (const std::exception& error) { return LUA->ThrowError(error.what()), 0; }
        return 2;
    }
#endif

    LUA_FUNCTION_STATIC(refresh) {
        try {
            LUA->PushNumber(platform::displayRefreshHz());
        } catch (const std::exception& error) { return LUA->ThrowError(error.what()), 0; }
        return 1;
    }

    LUA_FUNCTION_STATIC(clock) {
        try {
            LUA->PushNumber(platform::nowSeconds());
        } catch (const std::exception& error) { return LUA->ThrowError(error.what()), 0; }
        return 1;
    }

    LUA_FUNCTION_STATIC(open) {
        const char* path = LUA->CheckString(1);
        platform::BridgePath native;
        try {
            native = platform::utf8ToPath(path);
        } catch (const std::exception& error) { return LUA->ThrowError(error.what()), 0; }
        const platform::BridgePath& wide = native;
        try {
#ifdef GARRYCRAFT_CLIENT
            receiver.stop();
#else
            releaseGeometry();
#endif
            bridge.open(wide);
#ifdef GARRYCRAFT_CLIENT
            receiver.start(wide);
#endif
        }
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

    LUA_FUNCTION_STATIC(close) {
#ifdef GARRYCRAFT_CLIENT
        receiver.stop();
        releaseShadows(LUA);
#else
        releaseGeometry();
#endif
        bridge.close();
        return 0;
    }

    LUA_FUNCTION_STATIC(receive) {
        unsigned lane = static_cast<unsigned>(LUA->CheckNumber(1));
        try {
#ifdef GARRYCRAFT_CLIENT
            auto payload = receiver.take(lane);
#else
            auto payload = bridge.receive(lane);
#endif
            if (payload) LUA->PushString(payload->data(), static_cast<unsigned>(payload->size()));
            else LUA->PushNil();
        } catch (const std::exception& error) { LUA->ThrowError(error.what()); }
        return 1;
    }
}

GMOD_MODULE_OPEN() {
    LUA->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
    LUA->CreateTable();
#ifndef GARRYCRAFT_CLIENT
    registerRuntime(LUA);
    registerGeometry(LUA);
#endif
    LUA->PushCFunction(refresh);
    LUA->SetField(-2, "refresh");
#ifdef GARRYCRAFT_CLIENT
    registerPackets(LUA);
    LUA->PushCFunction(receiveRender); LUA->SetField(-2, "receive_render");
    registerTextures(LUA);
    registerFramerate(LUA);
    registerMeshes(LUA);
    registerShadows(LUA);
#endif
    LUA->PushCFunction(clock);
    LUA->SetField(-2, "clock");
    LUA->PushCFunction(open);
    LUA->SetField(-2, "open");
    LUA->PushCFunction(close);
    LUA->SetField(-2, "close");
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
    receiver.stop();
    releaseShadows(LUA);
    releaseTextures();
    releaseMeshes(LUA);
#else
    releaseGeometry();
#endif
    bridge.close();
    return 0;
}
