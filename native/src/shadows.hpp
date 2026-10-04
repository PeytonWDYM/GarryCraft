#pragma once
namespace GarrysMod::Lua { class ILuaBase; }

// Submit owned mesh silhouettes to Source's native shadow passes.
// Unregister entities before explicit mesh destruction. Source owns projection and receivers.
void registerShadows(GarrysMod::Lua::ILuaBase* lua);
void releaseShadows(GarrysMod::Lua::ILuaBase* lua);
