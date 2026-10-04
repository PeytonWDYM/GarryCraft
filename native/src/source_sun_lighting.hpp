#pragma once
#include <cstdint>
#include <mathlib/vector.h>
namespace GarrysMod::Lua { class ILuaBase; }

// Direction points toward the sun. This estimates its share of baked sky light;
// Source's original lightmap/ambient cube does not expose a separate sun channel.
struct SourceSunSample { Vector direction; float strength, transmission; };
SourceSunSample sampleSourceSunLighting(const Vector& position, float gridHeight);
float sourceSkyIrradiance(const SourceSunSample& sample, const Vector& normal, float sky);
float sourceSkyFactor(const Vector& position, const Vector& normal, float sky, float gridHeight);
std::uint64_t sourceSunRevision();
bool sourceSunLightingIntersects(const Vector& minimum, const Vector& maximum, float gridHeight);
bool sourceSunLightingChanged(const Vector& minimum, const Vector& maximum, float gridHeight, std::uint64_t since);
void registerSourceSunLighting(GarrysMod::Lua::ILuaBase* lua);
void releaseSourceSunLighting();
