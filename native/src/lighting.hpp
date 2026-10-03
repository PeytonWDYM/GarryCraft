#pragma once
#include <cstdint>
namespace GarrysMod::Lua { class ILuaBase; }
class Vector;
void registerLighting(GarrysMod::Lua::ILuaBase* lua);
void releaseLighting();
bool lightOccluded(const Vector& start, const Vector& end);
std::uint64_t lightingOccluderRevision();
