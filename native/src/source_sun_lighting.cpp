#include "source_sun_lighting.hpp"
#include "voxel_lighting.hpp"
#include "lighting.hpp"
#include "lighting_changes.hpp"
#include <GarrysMod/Lua/Interface.h>
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <map>

namespace {
    constexpr float rayLength = 2048;
    Vector direction(0, 0, 1);
    float strength = 0, luaGridHeight = 0;
    std::uint64_t revision = 0;
    std::uint64_t rays = 0, cacheHits = 0;
    // Exact positions preserve partial-block boundaries. The key also includes
    // grid translation; stationary models and BSP luxels reuse a single ray.
    struct CachedTransmission { float value; std::uint64_t revision; };
    std::map<std::array<std::uint32_t, 4>, CachedTransmission> transmissionCache;

    bool finite(const Vector& value) {
        return std::isfinite(value.x) && std::isfinite(value.y) && std::isfinite(value.z);
    }
    void invalidate(bool clearRays = true) { if (clearRays) transmissionCache.clear(); ++revision; }

    LUA_FUNCTION_STATIC(setLighting) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector);
        auto nextDirection = LUA->GetVector(1);
        const float nextStrength = static_cast<float>(LUA->CheckNumber(2));
        const float nextHeight = static_cast<float>(LUA->CheckNumber(3));
        if (!finite(nextDirection) || !std::isfinite(nextStrength) || nextStrength < 0 || nextStrength > 1
                || !std::isfinite(nextHeight)) return LUA->ThrowError("Source sun requires finite direction/grid height and strength from zero to one"), 0;
        const float length = std::sqrt(nextDirection.LengthSqr());
        if (nextStrength > 0 && (!std::isfinite(length) || length < .000001f))
            return LUA->ThrowError("Active Source sun requires a nonzero direction toward the sun"), 0;
        if (length > .000001f && std::isfinite(length)) nextDirection /= length;
        else nextDirection = direction;
        if (nextDirection != direction || nextStrength != strength || nextHeight != luaGridHeight) {
            // Opacity/toggle changes do not change transmission through the world.
            const bool changedRay = nextDirection != direction || nextHeight != luaGridHeight;
            direction = nextDirection; strength = nextStrength; luaGridHeight = nextHeight; invalidate(changedRay);
        }
        LUA->PushNumber(static_cast<double>(revision)); return 1;
    }

    LUA_FUNCTION_STATIC(skyFactor) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector); LUA->CheckType(2, GarrysMod::Lua::Type::Vector);
        const auto position = LUA->GetVector(1), normal = LUA->GetVector(2);
        const float sky = static_cast<float>(LUA->CheckNumber(3));
        if (!finite(position) || !finite(normal) || !std::isfinite(sky))
            return LUA->ThrowError("Source sky requires finite receiver position, normal and sky irradiance"), 0;
        LUA->PushNumber(sourceSkyFactor(position, normal, sky, luaGridHeight)); return 1;
    }

    LUA_FUNCTION_STATIC(report) {
        LUA->CreateTable();
        LUA->PushVector(direction); LUA->SetField(-2, "direction");
        LUA->PushNumber(strength); LUA->SetField(-2, "strength");
        LUA->PushNumber(luaGridHeight); LUA->SetField(-2, "grid_height");
        LUA->PushNumber(static_cast<double>(revision)); LUA->SetField(-2, "revision");
        LUA->PushNumber(static_cast<double>(rays)); LUA->SetField(-2, "rays");
        LUA->PushNumber(static_cast<double>(cacheHits)); LUA->SetField(-2, "cache_hits");
        LUA->PushNumber(transmissionCache.size()); LUA->SetField(-2, "cached_positions");
        return 1;
    }
}

SourceSunSample sampleSourceSunLighting(const Vector& position, float height) {
    SourceSunSample sample{direction, strength, 1};
    if (strength == 0) return sample;
    const std::array key{std::bit_cast<std::uint32_t>(position.x), std::bit_cast<std::uint32_t>(position.y),
        std::bit_cast<std::uint32_t>(position.z), std::bit_cast<std::uint32_t>(height)};
    const auto found = transmissionCache.find(key);
    if (found != transmissionCache.end() && !sourceSunLightingChanged(position, position, height, found->second.revision)) {
        ++cacheHits; found->second.revision = lightingChangeRevision(); sample.transmission = found->second.value; return sample;
    }
    sample.transmission = voxelLightTransmission(position, position + direction * rayLength, height);
    ++rays;
    if (transmissionCache.size() >= 32768) transmissionCache.clear();
    transmissionCache.insert_or_assign(key, CachedTransmission{sample.transmission, lightingChangeRevision()});
    return sample;
}

float sourceSkyIrradiance(const SourceSunSample& sample, const Vector& normal, float sky) {
    const float direct = sample.strength * std::clamp(DotProduct(normal, sample.direction), 0.f, 1.f);
    return sky * (1 - direct) + direct * sample.transmission;
}

float sourceSkyFactor(const Vector& position, const Vector& normal, float sky, float height) {
    if (strength == 0 || DotProduct(normal, direction) <= 0) return sky;
    return sourceSkyIrradiance(sampleSourceSunLighting(position, height), normal, sky);
}

bool sourceSunLightingIntersects(const Vector& minimum, const Vector& maximum, float height) {
    if (strength == 0) return false;
    const auto offset = direction * rayLength;
    return voxelLightingIntersects(minimum + Vector(std::min(0.f, offset.x), std::min(0.f, offset.y), std::min(0.f, offset.z)),
        maximum + Vector(std::max(0.f, offset.x), std::max(0.f, offset.y), std::max(0.f, offset.z)), height);
}

std::uint64_t sourceSunRevision() { return revision; }
bool sourceSunLightingChanged(const Vector& minimum, const Vector& maximum, float height, std::uint64_t since) {
    const auto offset = direction * (strength > 0 ? rayLength : 0);
    return lightingChanged(minimum + Vector(std::min(0.f, offset.x), std::min(0.f, offset.y), std::min(0.f, offset.z)),
        maximum + Vector(std::max(0.f, offset.x), std::max(0.f, offset.y), std::max(0.f, offset.z)), height, since);
}
void registerSourceSunLighting(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(setLighting); lua->SetField(-2, "source_sun_lighting");
    lua->PushCFunction(skyFactor); lua->SetField(-2, "source_sky_factor");
    lua->PushCFunction(report); lua->SetField(-2, "source_sun_report");
}
void releaseSourceSunLighting() { strength = 0; invalidate(); }
