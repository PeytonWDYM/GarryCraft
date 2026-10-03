#pragma once
namespace GarrysMod::Lua { class ILuaBase; }

// Register only GarryCraft model proxies. Remove registrations and entity shadows before destroying meshes.
// Failed scenarios to check in the owned lab: wrong ABI, recycled handles, destroyed meshes, bad matrices,
// more than four batches, changed bounds/pose, other entity draws, video reset, map exit, and module unload.
void registerShadows(GarrysMod::Lua::ILuaBase* lua);
void releaseShadows(GarrysMod::Lua::ILuaBase* lua);
// Minecraft proxies already supply their voxel ambient cube through the public model lighting API.
bool isDrawingSourceMesh();
