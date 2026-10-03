#include <GarrysMod/Lua/Interface.h>
#include <mathlib/vector.h>
#include "lighting.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
    struct Box { std::array<float, 3> min, max; bool operator==(const Box&) const = default; };
    struct Node { Box bounds; int first, count, left = -1, right = -1; };
    std::unordered_map<std::string, std::vector<Box>> sections;
    std::vector<Box> boxes;
    std::vector<Node> tree;
    bool dirty = true;
    unsigned long long rays = 0, boxTests = 0;
    std::uint64_t revision = 0;

    Box bounds(int first, int count) {
        Box result{{INFINITY, INFINITY, INFINITY}, {-INFINITY, -INFINITY, -INFINITY}};
        for (int i = first; i < first + count; ++i) for (int axis = 0; axis < 3; ++axis) {
            result.min[axis] = std::min(result.min[axis], boxes[i].min[axis]);
            result.max[axis] = std::max(result.max[axis], boxes[i].max[axis]);
        }
        return result;
    }
    int build(int first, int count) {
        int index = static_cast<int>(tree.size());
        auto box = bounds(first, count);
        tree.push_back({box, first, count});
        if (count <= 8) return index;
        int axis = 0;
        for (int a = 1; a < 3; ++a) if (box.max[a] - box.min[a] > box.max[axis] - box.min[axis]) axis = a;
        int half = count / 2;
        std::nth_element(boxes.begin() + first, boxes.begin() + first + half, boxes.begin() + first + count,
            [axis](const Box& a, const Box& b) { return a.min[axis] + a.max[axis] < b.min[axis] + b.max[axis]; });
        int left = build(first, half), right = build(first + half, count - half);
        tree[index].left = left; tree[index].right = right;
        return index;
    }
    void rebuild() {
        if (!dirty) return;
        boxes.clear(); tree.clear();
        for (const auto& [key, section] : sections) boxes.insert(boxes.end(), section.begin(), section.end());
        if (!boxes.empty()) build(0, static_cast<int>(boxes.size()));
        dirty = false;
    }
    bool intersects(const Box& box, const Vector& start, const Vector& end) {
        float enter = 0, exit = 1;
        for (int axis = 0; axis < 3; ++axis) {
            float delta = end[axis] - start[axis];
            if (std::abs(delta) < 0.00001f) {
                // A ray on a block face remains outside its opaque volume.
                if (start[axis] <= box.min[axis] + .02f || start[axis] >= box.max[axis] - .02f) return false;
            } else {
                float a = (box.min[axis] - start[axis]) / delta;
                float b = (box.max[axis] - start[axis]) / delta;
                enter = std::max(enter, std::min(a, b)); exit = std::min(exit, std::max(a, b));
                if (exit <= enter) return false;
            }
        }
        return exit > .001f && enter < .999f;
    }
    bool visit(int index, const Vector& start, const Vector& end) {
        const auto& node = tree[index];
        if (!intersects(node.bounds, start, end)) return false;
        if (node.left >= 0) return visit(node.left, start, end) || visit(node.right, start, end);
        for (int i = node.first; i < node.first + node.count; ++i) {
            ++boxTests;
            const auto& box = boxes[i];
            bool emitter = true;
            for (int axis = 0; axis < 3; ++axis) emitter = emitter && end[axis] > box.min[axis] && end[axis] < box.max[axis];
            if (emitter) continue;
            if (intersects(boxes[i], start, end)) return true;
        }
        return false;
    }
    bool occluded(const Vector& start, const Vector& end) {
        rebuild(); ++rays;
        return !tree.empty() && visit(0, start, end);
    }

    // A vertical receiver query shares the box index. Reject the caster's own top above the start point.
    void ground(int index, const Vector& start, float& height) {
        const auto& node = tree[index];
        const auto& bounds = node.bounds;
        if (start.x < bounds.min[0] || start.x > bounds.max[0]
                || start.y < bounds.min[1] || start.y > bounds.max[1]
                || bounds.min[2] > start.z || bounds.max[2] <= height) return;
        if (node.left >= 0) { ground(node.left, start, height); ground(node.right, start, height); return; }
        for (int i = node.first; i < node.first + node.count; ++i) {
            const auto& box = boxes[i];
            if (start.x >= box.min[0] && start.x <= box.max[0] && start.y >= box.min[1] && start.y <= box.max[1]
                    && box.max[2] <= start.z && box.max[2] > height) height = box.max[2];
        }
    }

    // Lua passes Minecraft light occlusion boxes. The index uses the renderer's coordinate transform.
    LUA_FUNCTION_STATIC(setSection) {
        std::string key = LUA->CheckString(1);
        LUA->CheckType(2, GarrysMod::Lua::Type::Table);
        float height = static_cast<float>(LUA->CheckNumber(3));
        std::vector<Box> result;
        int count = LUA->ObjLen(2);
        result.reserve(count);
        for (int i = 1; i <= count; ++i) {
            LUA->PushNumber(i); LUA->RawGet(2);
            std::array<float, 6> value;
            for (int j = 1; j <= 6; ++j) {
                LUA->PushNumber(j); LUA->RawGet(-2);
                value[j - 1] = static_cast<float>(LUA->CheckNumber(-1)); LUA->Pop();
            }
            LUA->Pop();
            result.push_back({{value[0] * 32, -value[5] * 32, value[1] * 32 + height},
                {value[3] * 32, -value[2] * 32, value[4] * 32 + height}});
        }
        const auto existing = sections.find(key);
        if (result.empty()) {
            if (existing == sections.end()) return 0;
            sections.erase(existing);
        } else {
            if (existing != sections.end() && existing->second == result) return 0;
            sections.insert_or_assign(key, std::move(result));
        }
        dirty = true; ++revision;
        return 0;
    }
    LUA_FUNCTION_STATIC(clear) { releaseLighting(); return 0; }
    LUA_FUNCTION_STATIC(blocked) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector); LUA->CheckType(2, GarrysMod::Lua::Type::Vector);
        LUA->PushBool(occluded(LUA->GetVector(1), LUA->GetVector(2)));
        return 1;
    }
    LUA_FUNCTION_STATIC(exposure) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector);
        const auto start = LUA->GetVector(1);
        const std::array<Vector, 6> directions = {Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0), Vector(0,0,1), Vector(0,0,-1)};
        LUA->CreateTable();
        for (int i = 0; i < 6; ++i) {
            LUA->PushNumber(i + 1); LUA->PushNumber(occluded(start, start + directions[i] * 2048) ? 0 : 1); LUA->RawSet(-3);
        }
        return 1;
    }
    LUA_FUNCTION_STATIC(receiver) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector);
        const auto start = LUA->GetVector(1);
        rebuild();
        float height = start.z - 1024;
        if (!tree.empty()) ground(0, start, height);
        if (height == start.z - 1024) LUA->PushNil(); else LUA->PushVector(Vector(start.x, start.y, height));
        return 1;
    }
    LUA_FUNCTION_STATIC(report) {
        LUA->CreateTable();
        LUA->PushNumber(boxes.size()); LUA->SetField(-2, "boxes");
        LUA->PushNumber(static_cast<double>(rays)); LUA->SetField(-2, "rays");
        LUA->PushNumber(static_cast<double>(boxTests)); LUA->SetField(-2, "boxTests");
        LUA->PushNumber(static_cast<double>(revision)); LUA->SetField(-2, "revision");
        return 1;
    }
}

void registerLighting(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(setSection); lua->SetField(-2, "set_light_occluders");
    lua->PushCFunction(clear); lua->SetField(-2, "clear_light_occluders");
    lua->PushCFunction(blocked); lua->SetField(-2, "light_occluded");
    lua->PushCFunction(exposure); lua->SetField(-2, "light_exposure");
    lua->PushCFunction(report); lua->SetField(-2, "lighting_report");
    lua->PushCFunction(receiver); lua->SetField(-2, "shadow_receiver");
}
void releaseLighting() { sections.clear(); boxes.clear(); tree.clear(); dirty = true; rays = boxTests = 0; ++revision; }
bool lightOccluded(const Vector& start, const Vector& end) { return occluded(start, end); }
std::uint64_t lightingOccluderRevision() { return revision; }
