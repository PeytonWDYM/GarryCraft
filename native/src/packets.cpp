#include "packets.hpp"
#include <stdexcept>

namespace {
    int packetType;
    struct Packet { std::string bytes; size_t offset = 0; };

    LUA_FUNCTION_STATIC(collect) {
        auto* packet = LUA->GetUserType<Packet>(1, packetType);
        if (packet) { packet->~Packet(); LUA->SetUserType(1, nullptr); }
        return 0;
    }
    LUA_FUNCTION_STATIC(release) {
        LUA->CheckType(1, packetType);
        auto* packet = LUA->GetUserType<Packet>(1, packetType);
        std::string().swap(packet->bytes);
        packet->offset = 0;
        return 0;
    }
}

void registerPackets(GarrysMod::Lua::ILuaBase* lua) {
    packetType = lua->CreateMetaTable("GarryCraftPacket");
    lua->PushCFunction(collect); lua->SetField(-2, "__gc");
    lua->Pop();
    lua->PushCFunction(release); lua->SetField(-2, "release_packet");
}

// Lua receives only the JSON header. The immutable binary body keeps its worker allocation until Lua releases it.
void pushPacket(GarrysMod::Lua::ILuaBase* lua, std::string&& payload) {
    size_t boundary = payload.find('\n');
    if (boundary == std::string::npos) throw std::runtime_error("Missing render packet header");
    lua->PushString(payload.data(), static_cast<unsigned>(boundary));
    auto* packet = lua->NewUserType<Packet>(packetType);
    packet->bytes = std::move(payload);
    packet->offset = boundary + 1;
    lua->PushMetaTable(packetType); lua->SetMetaTable(-2);
}

std::string_view packetBytes(GarrysMod::Lua::ILuaBase* lua, int index) {
    if (lua->IsType(index, GarrysMod::Lua::Type::String)) {
        unsigned length;
        const char* bytes = lua->GetString(index, &length);
        return {bytes, length};
    }
    lua->CheckType(index, packetType);
    auto* packet = lua->GetUserType<Packet>(index, packetType);
    return std::string_view(packet->bytes).substr(packet->offset);
}
