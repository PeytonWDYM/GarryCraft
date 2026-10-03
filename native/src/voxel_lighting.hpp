#pragma once
#include <optional>
#include <cstdint>
#include <mathlib/vector.h>
namespace GarrysMod::Lua { class ILuaBase; }

struct VoxelLightSample {
    int sky, block, dampening;
    bool skylightDown, air, shape, opaque, centerBlocked;
    float skyInterpolated, blockInterpolated;
    float skyBrightness, blockBrightness, skyBrightnessInterpolated, blockBrightnessInterpolated;
};

std::optional<VoxelLightSample> sampleVoxelLighting(const Vector& position, float gridHeight);
bool sampleVoxelLighting(const Vector& position, float gridHeight, float& skyBrightness, float& blockBrightness);
bool voxelLightingIntersects(const Vector& minimum, const Vector& maximum, float gridHeight);
std::uint64_t voxelLightingRevision();
float voxelLightTransmission(const Vector& start, const Vector& end, float gridHeight);
void registerVoxelLighting(GarrysMod::Lua::ILuaBase* lua);
void releaseVoxelLighting();
