#pragma once
#include <GarrysMod/Lua/Interface.h>
#include <string>
#include <string_view>

void registerPackets(GarrysMod::Lua::ILuaBase* lua);
void pushPacket(GarrysMod::Lua::ILuaBase* lua, std::string&& payload);
std::string_view packetBytes(GarrysMod::Lua::ILuaBase* lua, int index);
