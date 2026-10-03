#pragma once
namespace GarrysMod::Lua { class ILuaBase; }

// Native studio models receive voxel ambient lighting after Source prepares their lights.
void registerSourceModelLighting(GarrysMod::Lua::ILuaBase* lua);
void releaseSourceModelLighting();
