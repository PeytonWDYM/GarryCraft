#include "geometry.hpp"
#include <array>
#include <cmath>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace {
    std::unordered_map<std::uint32_t, std::vector<float>> shapes;
    std::uint32_t nextShape = 1;

    template<class T> void append(std::string& bytes, T value) {
        bytes.append(reinterpret_cast<const char*>(&value), sizeof(value));
    }
    double number(GarrysMod::Lua::ILuaBase* lua, int table, int index) {
        lua->PushNumber(index); lua->RawGet(table);
        double value = lua->GetNumber(-1); lua->Pop();
        return value;
    }
    double field(GarrysMod::Lua::ILuaBase* lua, int table, const char* name) {
        lua->GetField(table, name);
        double value = lua->GetNumber(-1); lua->Pop();
        return value;
    }
    std::uint32_t store(std::vector<float>&& vertices) {
        auto id = nextShape++;
        shapes.emplace(id, std::move(vertices));
        return id;
    }

    LUA_FUNCTION_STATIC(mesh) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Table);
        int count = LUA->ObjLen(1);
        if (count % 3 != 0) LUA->ThrowError("Collision mesh must contain complete triangles");
        std::vector<float> vertices;
        vertices.reserve(count * 3);
        for (int index = 1; index <= count; index++) {
            LUA->PushNumber(index); LUA->RawGet(1);
            LUA->GetField(-1, "pos");
            const auto& point = LUA->GetVector(-1);
            vertices.insert(vertices.end(), {point.x, point.y, point.z});
            LUA->Pop(2);
        }
        LUA->PushNumber(store(std::move(vertices)));
        LUA->PushNumber(count / 3);
        return 2;
    }

    LUA_FUNCTION_STATIC(box) {
        LUA->CheckType(1, GarrysMod::Lua::Type::Vector);
        LUA->CheckType(2, GarrysMod::Lua::Type::Vector);
        const auto minimum = LUA->GetVector(1), maximum = LUA->GetVector(2);
        std::array<std::array<float, 3>, 8> corners;
        int index = 0;
        for (float x : {minimum.x, maximum.x})
            for (float y : {minimum.y, maximum.y})
                for (float z : {minimum.z, maximum.z}) corners[index++] = {x, y, z};
        constexpr int faces[][4] = {{0,2,3,1},{4,5,7,6},{0,1,5,4},{2,6,7,3},{0,4,6,2},{1,3,7,5}};
        constexpr int orders[][3] = {{0,1,2},{0,2,3}};
        std::vector<float> vertices;
        vertices.reserve(108);
        for (const auto& face : faces)
            for (const auto& order : orders)
                for (int corner : order) {
                    const auto& point = corners[face[corner]];
                    vertices.insert(vertices.end(), point.begin(), point.end());
                }
        LUA->PushNumber(store(std::move(vertices)));
        LUA->PushNumber(12);
        return 2;
    }

    // Source's public position and angles define its local-to-world matrix.
    std::array<float, 12> matrix(const Vector& position, const QAngle& angles) {
        constexpr float radians = 3.14159265358979323846f / 180.0f;
        float sp = std::sin(angles.x * radians), cp = std::cos(angles.x * radians);
        float sy = std::sin(angles.y * radians), cy = std::cos(angles.y * radians);
        float sr = std::sin(angles.z * radians), cr = std::cos(angles.z * radians);
        return {cp*cy, sr*sp*cy-cr*sy, cr*sp*cy+sr*sy, position.x,
                cp*sy, sr*sp*sy+cr*cy, cr*sp*sy-sr*cy, position.y,
                -sp, sr*cp, cr*cp, position.z};
    }

    LUA_FUNCTION_STATIC(packet) {
        LUA->CheckType(1, GarrysMod::Lua::Type::String);
        LUA->CheckType(2, GarrysMod::Lua::Type::Table);
        LUA->CheckType(4, GarrysMod::Lua::Type::Table);
        auto acknowledged = static_cast<std::uint32_t>(LUA->CheckNumber(3));
        int count = LUA->ObjLen(2);
        std::unordered_set<std::uint32_t> active;
        std::string instances;
        instances.reserve(count * 64);
        std::uint32_t triangles = 0;
        for (int index = 1; index <= count; index++) {
            LUA->PushNumber(index); LUA->RawGet(2);
            int table = LUA->Top();
            auto entity = static_cast<std::uint32_t>(number(LUA, table, 1));
            auto creation = static_cast<std::uint32_t>(number(LUA, table, 2));
            auto part = static_cast<std::uint32_t>(static_cast<std::int32_t>(number(LUA, table, 3)));
            auto shape = static_cast<std::uint32_t>(number(LUA, table, 4));
            auto found = shapes.find(shape);
            if (found == shapes.end()) LUA->ThrowError("Unknown collision shape");
            active.insert(shape);
            triangles += static_cast<std::uint32_t>(found->second.size() / 9);
            LUA->PushNumber(5); LUA->RawGet(table); const auto position = LUA->GetVector(-1); LUA->Pop();
            LUA->PushNumber(6); LUA->RawGet(table); const auto angles = LUA->GetAngle(-1); LUA->Pop();
            append(instances, entity); append(instances, creation); append(instances, part); append(instances, shape);
            for (float value : matrix(position, angles)) append(instances, value);
            LUA->Pop();
        }
        std::string body;
        std::uint32_t pending = 0;
        for (auto id : active) if (id > acknowledged) pending++;
        append(body, pending); append(body, static_cast<std::uint32_t>(count));
        append(body, nextShape - 1);
        int actorCount = LUA->ObjLen(4);
        append(body, static_cast<std::uint32_t>(actorCount));
        for (auto id : active) if (id > acknowledged) {
            const auto& vertices = shapes.at(id);
            append(body, id); append(body, static_cast<std::uint32_t>(vertices.size() / 3));
            body.append(reinterpret_cast<const char*>(vertices.data()), vertices.size() * sizeof(float));
        }
        body += instances;
        for (int index = 1; index <= actorCount; index++) {
            LUA->PushNumber(index); LUA->RawGet(4);
            int table = LUA->Top();
            append(body, static_cast<std::uint32_t>(field(LUA, table, "id")));
            append(body, static_cast<std::uint32_t>(field(LUA, table, "generation")));
            for (const char* name : {"x", "y", "z"}) append(body, field(LUA, table, name));
            for (const char* name : {"yaw", "width", "height"}) append(body, static_cast<float>(field(LUA, table, name)));
            LUA->GetField(table, "npc");
            append(body, static_cast<std::uint8_t>(LUA->GetBool(-1))); LUA->Pop();
            LUA->GetField(table, "name");
            unsigned nameLength;
            const char* name = LUA->GetString(-1, &nameLength);
            append(body, static_cast<std::uint32_t>(nameLength));
            body.append(name, nameLength);
            LUA->Pop(2);
        }
        unsigned headerLength;
        const char* header = LUA->GetString(1, &headerLength);
        std::string payload(header, headerLength);
        payload += '\n'; payload += body;
        for (auto iterator = shapes.begin(); iterator != shapes.end();) {
            if (!active.contains(iterator->first)) iterator = shapes.erase(iterator);
            else ++iterator;
        }
        LUA->PushString(payload.data(), static_cast<unsigned>(payload.size()));
        LUA->PushNumber(triangles);
        LUA->PushNumber(pending);
        return 3;
    }

    LUA_FUNCTION_STATIC(clear) { releaseGeometry(); return 0; }
}

void releaseGeometry() { shapes.clear(); nextShape = 1; }

void registerGeometry(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(mesh); lua->SetField(-2, "geometry_mesh");
    lua->PushCFunction(box); lua->SetField(-2, "geometry_box");
    lua->PushCFunction(packet); lua->SetField(-2, "geometry_packet");
    lua->PushCFunction(clear); lua->SetField(-2, "geometry_clear");
}
