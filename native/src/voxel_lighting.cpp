#include "voxel_lighting.hpp"
#include "lighting.hpp"
#include "packets.hpp"
#include <GarrysMod/Lua/Interface.h>
#include <algorithm>
#include <array>
#include <charconv>
#include <climits>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string_view>
#include <unordered_map>

namespace {
    constexpr int width = 18, byteCount = width * width * width * 3;
    struct CellKey {
        int x, y, z;
        bool operator==(const CellKey&) const = default;
    };
    struct KeyHash {
        size_t operator()(const CellKey& key) const {
            return uint32_t(key.x) * 73856093u ^ uint32_t(key.y) * 19349663u ^ uint32_t(key.z) * 83492791u;
        }
    };
    struct Section {
        std::array<uint8_t, byteCount> cells;
        std::array<float, 16> brightness;
    };
    struct Cell {
        const uint8_t* data;
        const std::array<float, 16>* brightness;
        int sky() const { return data[0] >> 4; }
        int block() const { return data[0] & 15; }
        bool transmitting() const { return !(data[2] & (8 | 16)); }
    };
    std::unordered_map<CellKey, Section, KeyHash> sections;
    std::uint64_t revision = 0;
    unsigned long long samples = 0, transmissions = 0, transmissionCells = 0, unloadedRays = 0;

    CellKey cellAt(const Vector& point, float height) {
        return {int(std::floor(point.x / 32)), int(std::floor((point.z - height) / 32)), int(std::floor(-point.y / 32))};
    }
    std::optional<Cell> inSection(const CellKey& sectionKey, const Section& section, const CellKey& cell) {
        int x = cell.x - sectionKey.x * 16 + 1, y = cell.y - sectionKey.y * 16 + 1, z = cell.z - sectionKey.z * 16 + 1;
        if (x < 0 || x >= width || y < 0 || y >= width || z < 0 || z >= width) return std::nullopt;
        const auto data = section.cells.data() + ((y * width + z) * width + x) * 3;
        if (!(data[2] & 32)) return std::nullopt;
        return Cell{data, &section.brightness};
    }
    std::optional<Cell> inSection(const CellKey& sectionKey, const CellKey& cell) {
        auto section = sections.find(sectionKey);
        return section == sections.end() ? std::nullopt : inSection(sectionKey, section->second, cell);
    }
    std::optional<Cell> lookup(const CellKey& cell) {
        CellKey owner{cell.x >> 4, cell.y >> 4, cell.z >> 4};
        if (auto found = inSection(owner, cell)) return found;
        if (sections.size() < 27) {
            std::optional<Cell> result;
            std::array<int, 3> first{INT_MAX, INT_MAX, INT_MAX};
            for (const auto& [key, section] : sections) {
                if (std::abs(key.x - owner.x) > 1 || std::abs(key.y - owner.y) > 1 || std::abs(key.z - owner.z) > 1) continue;
                const std::array order{key.x, key.y, key.z};
                if (order >= first) continue;
                if (auto found = inSection(key, section, cell)) { result = found; first = order; }
            }
            return result;
        }
        // A halo supplies surface-adjacent air when that neighboring section has no exported geometry or light changes.
        for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++)
            if (auto found = inSection({owner.x + x, owner.y + y, owner.z + z}, cell)) return found;
        return std::nullopt;
    }
    // Unloaded cells transmit fully. Clip work to the last exact intersection
    // with an exported section's one-cell halo, preserving the DDA's cell order.
    float lastFieldExit(const Vector& start, const Vector& end) {
        float last = -1;
        for (const auto& [key, section] : sections) {
            const std::array lower{key.x * 16.f - 1, key.y * 16.f - 1, key.z * 16.f - 1};
            float enter = 0, exit = 1;
            for (int axis = 0; axis < 3; ++axis) {
                const float direction = end[axis] - start[axis];
                if (direction == 0) {
                    if (start[axis] < lower[axis] || start[axis] > lower[axis] + width) { exit = -1; break; }
                } else {
                    const float a = (lower[axis] - start[axis]) / direction, b = (lower[axis] + width - start[axis]) / direction;
                    enter = std::max(enter, std::min(a, b)); exit = std::min(exit, std::max(a, b));
                    if (exit < enter) break;
                }
            }
            if (exit >= enter) last = std::max(last, exit);
        }
        return last;
    }
    CellKey parseKey(GarrysMod::Lua::ILuaBase* lua, int argument) {
        std::string_view text(lua->CheckString(argument));
        std::array<int, 3> axes;
        for (int axis = 0; axis < 3; axis++) {
            auto result = std::from_chars(text.data(), text.data() + text.size(), axes[axis]);
            if (result.ec != std::errc{} || (axis < 2 && (result.ptr == text.data() + text.size() || *result.ptr != ',')))
                lua->ThrowError("Voxel lighting section key must be x,y,z");
            if (axis < 2) text.remove_prefix(result.ptr - text.data() + 1);
            else if (result.ptr != text.data() + text.size()) lua->ThrowError("Voxel lighting section key must be x,y,z");
        }
        return {axes[0], axes[1], axes[2]};
    }
    void number(GarrysMod::Lua::ILuaBase* lua, const char* field, double value) {
        lua->PushNumber(value); lua->SetField(-2, field);
    }
    void boolean(GarrysMod::Lua::ILuaBase* lua, const char* field, bool value) {
        lua->PushBool(value); lua->SetField(-2, field);
    }
    void pushSample(GarrysMod::Lua::ILuaBase* lua, const VoxelLightSample& sample) {
        lua->CreateTable();
        number(lua, "sky", sample.sky); number(lua, "block", sample.block); number(lua, "dampening", sample.dampening);
        number(lua, "skyInterpolated", sample.skyInterpolated); number(lua, "blockInterpolated", sample.blockInterpolated);
        number(lua, "skyBrightness", sample.skyBrightness); number(lua, "blockBrightness", sample.blockBrightness);
        number(lua, "skyBrightnessInterpolated", sample.skyBrightnessInterpolated);
        number(lua, "blockBrightnessInterpolated", sample.blockBrightnessInterpolated);
        boolean(lua, "skylightDown", sample.skylightDown); boolean(lua, "air", sample.air);
        boolean(lua, "shape", sample.shape); boolean(lua, "opaque", sample.opaque); boolean(lua, "centerBlocked", sample.centerBlocked);
    }
    LUA_FUNCTION_STATIC(setSection) {
        auto key = parseKey(LUA, 1);
        LUA->CheckType(2, GarrysMod::Lua::Type::Table);
        LUA->GetField(2, "offset"); auto offset = static_cast<size_t>(LUA->CheckNumber(-1)); LUA->Pop();
        LUA->GetField(2, "count"); auto count = static_cast<size_t>(LUA->CheckNumber(-1)); LUA->Pop();
        LUA->GetField(2, "width"); int suppliedWidth = static_cast<int>(LUA->CheckNumber(-1)); LUA->Pop();
        const auto body = packetBytes(LUA, 3);
        if (suppliedWidth != width || count != byteCount || offset > body.size() || count > body.size() - offset)
            return LUA->ThrowError("Voxel lighting packet must contain 18 cubed three-byte cells"), 0;
        Section section;
        std::memcpy(section.cells.data(), body.data() + offset, count);
        LUA->GetField(2, "brightness"); LUA->CheckType(-1, GarrysMod::Lua::Type::Table);
        if (LUA->ObjLen(-1) != 16) return LUA->ThrowError("Voxel lighting requires Minecraft's 16-level brightness table"), 0;
        for (int level = 0; level < 16; level++) {
            LUA->PushNumber(level + 1); LUA->RawGet(-2);
            section.brightness[level] = static_cast<float>(LUA->CheckNumber(-1)); LUA->Pop();
        }
        LUA->Pop();
        const auto existing = sections.find(key);
        if (existing != sections.end() && existing->second.cells == section.cells && existing->second.brightness == section.brightness) return 0;
        sections.insert_or_assign(key, std::move(section));
        ++revision;
        return 0;
    }
    LUA_FUNCTION_STATIC(removeSection) { if (sections.erase(parseKey(LUA, 1))) ++revision; return 0; }
    LUA_FUNCTION_STATIC(clear) { releaseVoxelLighting(); return 0; }
    LUA_FUNCTION_STATIC(sample) {
        auto value = sampleVoxelLighting(LUA->GetVector(1), static_cast<float>(LUA->CheckNumber(2)));
        if (value) pushSample(LUA, *value); else LUA->PushNil();
        return 1;
    }
    LUA_FUNCTION_STATIC(transmission) {
        LUA->PushNumber(voxelLightTransmission(LUA->GetVector(1), LUA->GetVector(2), static_cast<float>(LUA->CheckNumber(3))));
        return 1;
    }
    LUA_FUNCTION_STATIC(report) {
        LUA->CreateTable(); number(LUA, "sections", sections.size()); number(LUA, "bytes", sections.size() * byteCount);
        number(LUA, "samples", static_cast<double>(samples)); number(LUA, "transmissions", static_cast<double>(transmissions));
        number(LUA, "transmission_cells", static_cast<double>(transmissionCells)); number(LUA, "unloaded_rays", static_cast<double>(unloadedRays));
        number(LUA, "revision", static_cast<double>(revision));
        return 1;
    }
}

std::optional<VoxelLightSample> sampleVoxelLighting(const Vector& position, float height) {
    ++samples;
    auto cell = lookup(cellAt(position, height));
    if (!cell) return std::nullopt;
    int flags = cell->data[2];
    VoxelLightSample sample{cell->sky(), cell->block(), cell->data[1], bool(flags & 1), bool(flags & 2),
        bool(flags & 4), bool(flags & 8), bool(flags & 16), float(cell->sky()), float(cell->block()),
        (*cell->brightness)[cell->sky()], (*cell->brightness)[cell->block()],
        (*cell->brightness)[cell->sky()], (*cell->brightness)[cell->block()]};
    // A receiving luxel inside an opaque cell cannot import nearby exterior air.
    if (!cell->transmitting()) return sample;
    Vector grid(position.x / 32 - .5f, (position.z - height) / 32 - .5f, -position.y / 32 - .5f);
    CellKey base{int(std::floor(grid.x)), int(std::floor(grid.y)), int(std::floor(grid.z))};
    float fx = grid.x - base.x, fy = grid.y - base.y, fz = grid.z - base.z;
    float total = 0, sky = 0, block = 0, skyBrightness = 0, blockBrightness = 0;
    for (int y = 0; y <= 1; y++) for (int z = 0; z <= 1; z++) for (int x = 0; x <= 1; x++) {
        auto adjacent = lookup({base.x + x, base.y + y, base.z + z});
        if (!adjacent || !adjacent->transmitting()) continue;
        float weight = (x ? fx : 1 - fx) * (y ? fy : 1 - fy) * (z ? fz : 1 - fz);
        total += weight; sky += adjacent->sky() * weight; block += adjacent->block() * weight;
        skyBrightness += (*adjacent->brightness)[adjacent->sky()] * weight;
        blockBrightness += (*adjacent->brightness)[adjacent->block()] * weight;
    }
    if (total > 0) {
        sample.skyInterpolated = sky / total; sample.blockInterpolated = block / total;
        sample.skyBrightnessInterpolated = skyBrightness / total; sample.blockBrightnessInterpolated = blockBrightness / total;
    }
    return sample;
}

float voxelLightTransmission(const Vector& start, const Vector& end, float height) {
    ++transmissions;
    if (lightOccluded(start, end)) return 0;
    Vector a(start.x / 32, (start.z - height) / 32, -start.y / 32);
    Vector b(end.x / 32, (end.z - height) / 32, -end.y / 32);
    const float loadedExit = lastFieldExit(a, b);
    if (loadedExit < 0) { ++unloadedRays; return 1; }
    auto cell = cellAt(start, height), emitter = cellAt(end, height);
    std::array<int, 3> current{cell.x, cell.y, cell.z}, last{emitter.x, emitter.y, emitter.z}, step;
    std::array<float, 3> next, delta;
    for (int axis = 0; axis < 3; axis++) {
        float direction = b[axis] - a[axis];
        step[axis] = direction > 0 ? 1 : direction < 0 ? -1 : 0;
        delta[axis] = direction == 0 ? INFINITY : std::abs(1 / direction);
        next[axis] = direction == 0 ? INFINITY : ((current[axis] + (step[axis] > 0 ? 1 : 0)) - a[axis]) / direction;
    }
    float result = 1;
    while (current != last) {
        ++transmissionCells;
        if (auto value = lookup({current[0], current[1], current[2]})) result *= std::max(0.f, (15 - value->data[1]) / 15.f);
        if (result == 0) return 0;
        float at = std::min({next[0], next[1], next[2]});
        if (at >= 1 || at > loadedExit) break;
        // Advance all tied axes. A ray that touches only an edge does not cross either neighboring volume.
        for (int axis = 0; axis < 3; axis++) if (next[axis] <= at + .000001f) {
            current[axis] += step[axis]; next[axis] += delta[axis];
        }
    }
    return result;
}

bool sampleVoxelLighting(const Vector& position, float height, float& skyBrightness, float& blockBrightness) {
    auto sample = sampleVoxelLighting(position, height);
    if (!sample) return false;
    skyBrightness = sample->skyBrightnessInterpolated;
    blockBrightness = sample->blockBrightnessInterpolated;
    return true;
}

bool voxelLightingIntersects(const Vector& minimum, const Vector& maximum, float height) {
    for (const auto& [key, section] : sections) {
        const Vector lower(key.x * 512.f, -(key.z + 1) * 512.f, key.y * 512.f + height);
        const Vector upper((key.x + 1) * 512.f, -key.z * 512.f, (key.y + 1) * 512.f + height);
        if (minimum.x <= upper.x && maximum.x >= lower.x && minimum.y <= upper.y && maximum.y >= lower.y
                && minimum.z <= upper.z && maximum.z >= lower.z) return true;
    }
    return false;
}

std::uint64_t voxelLightingRevision() { return revision; }

void registerVoxelLighting(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(setSection); lua->SetField(-2, "set_voxel_lighting");
    lua->PushCFunction(removeSection); lua->SetField(-2, "remove_voxel_lighting");
    lua->PushCFunction(clear); lua->SetField(-2, "clear_voxel_lighting");
    lua->PushCFunction(sample); lua->SetField(-2, "sample_voxel_lighting");
    lua->PushCFunction(transmission); lua->SetField(-2, "light_transmission");
    lua->PushCFunction(report); lua->SetField(-2, "voxel_lighting_report");
}
void releaseVoxelLighting() { sections.clear(); samples = transmissions = transmissionCells = unloadedRays = 0; ++revision; }
