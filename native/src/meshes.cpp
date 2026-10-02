#include <GarrysMod/Lua/Interface.h>
#include <mathlib/vector.h>
#include "meshes.hpp"
#include "packets.hpp"
#include <array>
#include <cmath>
#include <cstring>
#include <cstdint>

namespace {
    enum Function { Begin, Position, Normal, Color, TexCoord, Advance, End };
    std::array<int, 7> functions{};
    int triangles;
    struct Vertex { float x, y, z, u, v; unsigned char rgba[4]; };
    static_assert(sizeof(Vertex) == 24);

    // Use GMod's public mesh API. The current game does not expose a compatible SDK IMesh handle.
    LUA_FUNCTION_STATIC(buildMesh) {
        LUA->CheckType(1, GarrysMod::Lua::Type::IMesh);
        auto body = packetBytes(LUA, 2);
        const char* bytes = body.data();
        size_t length = body.size();
        auto offset = static_cast<std::int64_t>(LUA->CheckNumber(3));
        auto count = static_cast<std::int64_t>(LUA->CheckNumber(4));
        int space = static_cast<int>(LUA->CheckNumber(5));
        float height = static_cast<float>(LUA->CheckNumber(6));
        if (offset < 0 || count <= 0 || count % 3 != 0 || count > 65532
            || offset + count * sizeof(Vertex) > length || space < 0 || space > 2)
            return LUA->ThrowError("Invalid packed mesh range"), 0;
        LUA->ReferencePush(functions[Begin]); LUA->Push(1); LUA->PushNumber(triangles); LUA->PushNumber(count / 3); LUA->Call(3, 0);
        for (std::int64_t first = 0; first < count; first += 3) {
            std::array<Vertex, 3> vertices;
            std::array<Vector, 3> positions;
            for (int i = 0; i < 3; ++i) {
                std::memcpy(&vertices[i], bytes + offset + (first + i) * sizeof(Vertex), sizeof(Vertex));
                const auto& v = vertices[i];
                positions[i] = space == 2 ? Vector(-v.z * 32, -v.x * 32, v.y * 32)
                    : Vector(v.x * 32, -v.z * 32, v.y * 32 + (space == 1 ? height : 0));
            }
            auto a = positions[1] - positions[0], b = positions[2] - positions[0];
            Vector normal(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
            float size = std::sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z);
            if (size > 0) normal *= 1 / size;
            for (int i : {0, 2, 1}) {
                const auto& v = vertices[i];
                LUA->ReferencePush(functions[Position]); LUA->PushVector(positions[i]); LUA->Call(1, 0);
                LUA->ReferencePush(functions[Normal]); LUA->PushVector(normal); LUA->Call(1, 0);
                LUA->ReferencePush(functions[Color]); for (auto color : v.rgba) LUA->PushNumber(color); LUA->Call(4, 0);
                LUA->ReferencePush(functions[TexCoord]); LUA->PushNumber(0); LUA->PushNumber(v.u); LUA->PushNumber(v.v); LUA->Call(3, 0);
                LUA->ReferencePush(functions[Advance]); LUA->Call(0, 0);
            }
        }
        LUA->ReferencePush(functions[End]); LUA->Call(0, 0);
        return 0;
    }
}

void registerMeshes(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
    lua->GetField(-1, "MATERIAL_TRIANGLES"); triangles = static_cast<int>(lua->GetNumber(-1)); lua->Pop();
    lua->GetField(-1, "mesh");
    const char* names[] = {"Begin", "Position", "Normal", "Color", "TexCoord", "AdvanceVertex", "End"};
    for (int i = 0; i < 7; ++i) { lua->GetField(-1, names[i]); functions[i] = lua->ReferenceCreate(); }
    lua->Pop(2);
    lua->PushCFunction(buildMesh); lua->SetField(-2, "build_mesh");
}
void releaseMeshes(GarrysMod::Lua::ILuaBase* lua) { for (int reference : functions) lua->ReferenceFree(reference); }
