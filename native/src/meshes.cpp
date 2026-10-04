#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <emmintrin.h>
#include <cstring>

// The pinned SDK declares an unused MMX helper. MSVC x64 only supplies the SSE2 conversion.
inline __m64 sourceSdkTruncatePair(__m128 value) {
    __m128i converted = _mm_cvttps_epi32(value);
    __m64 pair;
    std::memcpy(&pair, &converted, sizeof(pair));
    return pair;
}
#pragma push_macro("_mm_cvttps_pi32")
#pragma push_macro("_mm_empty")
#define _mm_cvttps_pi32 sourceSdkTruncatePair
#define _mm_empty() ((void)0)
#include <materialsystem/imesh.h>
#pragma pop_macro("_mm_empty")
#pragma pop_macro("_mm_cvttps_pi32")
#include <mathlib/vector.h>
#include "meshes.hpp"
#include "packets.hpp"
#include "sdkcompat.hpp"
#include <array>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <cstdint>
#include <chrono>
#include <limits>

namespace {
    enum Function { Begin, Position, Normal, Color, TexCoord, Advance, End };
    std::array<int, 7> functions{};
    int triangles;
    struct Vertex { float x, y, z, u, v; unsigned char rgba[4]; };
    static_assert(sizeof(Vertex) == 24);
    static_assert(sizeof(MeshDesc_t) == 0x108);
    struct MeshHandle { std::uint32_t magic; IMesh* mesh; };
    static_assert(offsetof(MeshHandle, mesh) == 8);
    using GetContext = void* (__fastcall*)(void*);
    using RenderOperation = void (__fastcall*)(void*);
    void* materialSystem;
    GetContext getContext;
    DWORD ownerThread;
    std::uint64_t nativeBuilds, publicBuilds, builtVertices;
    double buildMilliseconds;

    // These Windows x64 dispatch slots were checked against the isolated September 23, 2026 binaries.
    // Keep creation, Draw, Destroy, and video-reset bookkeeping in GMod's public IMesh API.
    void findNativeBackend() {
        if (!sdkcompat::supportedClient()) return;
        materialSystem = sdkcompat::materialSystem();
        if (materialSystem) getContext = reinterpret_cast<GetContext>((*static_cast<void***>(materialSystem))[102]);
    }

    class RenderScope {
        void* context;
    public:
        explicit RenderScope(void* value) : context(value) {
            reinterpret_cast<RenderOperation>((*static_cast<void***>(context))[0])(context);
        }
        ~RenderScope() {
            reinterpret_cast<RenderOperation>((*static_cast<void***>(context))[1])(context);
        }
    };

    Vector position(const Vertex& v, int space, float height) {
        return space == 2 ? Vector(-v.z * 32, -v.x * 32, v.y * 32)
            : Vector(v.x * 32, -v.z * 32, v.y * 32 + (space == 1 ? height : 0));
    }

    template<class Write> void writeTriangles(const char* bytes, int count, int space, float height, Write write) {
        for (int first = 0; first < count; first += 3) {
            std::array<Vertex, 3> vertices;
            std::array<Vector, 3> positions;
            for (int i = 0; i < 3; ++i) {
                std::memcpy(&vertices[i], bytes + (first + i) * sizeof(Vertex), sizeof(Vertex));
                positions[i] = position(vertices[i], space, height);
            }
            auto a = positions[1] - positions[0], b = positions[2] - positions[0];
            double nx = double(a.y) * b.z - double(a.z) * b.y;
            double ny = double(a.z) * b.x - double(a.x) * b.z;
            double nz = double(a.x) * b.y - double(a.y) * b.x;
            double length = std::sqrt(nx * nx + ny * ny + nz * nz);
            Vector normal(0, 0, 0);
            if (length > 0) normal = Vector(static_cast<float>(nx / length), static_cast<float>(ny / length), static_cast<float>(nz / length));
            for (int i : {0, 2, 1}) write(vertices[i], positions[i], normal);
        }
    }

    // Only the verified SetPrimitiveType, LockMesh, and UnlockMesh SDK methods are used here.
    const char* buildNative(IMesh* mesh, const char* bytes, int count, int space, float height) {
        auto* context = getContext(materialSystem);
        if (!context) return "Native mesh render context unavailable";
        RenderScope render(context);
        MeshDesc_t desc{};
        mesh->SetPrimitiveType(MATERIAL_TRIANGLES);
        mesh->LockMesh(count, count, desc);
        if (!desc.m_pPosition || !desc.m_pNormal || !desc.m_pColor || !desc.m_pTexCoord[0]
            || !desc.m_pIndices || desc.m_nIndexSize != 1 || desc.m_nFirstVertex != 0
            || desc.m_CompressionType != VERTEX_COMPRESSION_NONE) {
            mesh->UnlockMesh(0, 0, desc);
            return "Native mesh buffer unavailable or unsupported";
        }
        int output = 0;
        writeTriangles(bytes, count, space, height, [&](const Vertex& vertex, const Vector& point, const Vector& normal) {
            std::memcpy(OffsetFloatPointer(desc.m_pPosition, output, desc.m_VertexSize_Position), &point.x, 12);
            std::memcpy(OffsetFloatPointer(desc.m_pNormal, output, desc.m_VertexSize_Normal), &normal.x, 12);
            unsigned char bgra[] = {vertex.rgba[2], vertex.rgba[1], vertex.rgba[0], vertex.rgba[3]};
            std::memcpy(desc.m_pColor + output * desc.m_VertexSize_Color, bgra, 4);
            float uv[] = {vertex.u, vertex.v};
            std::memcpy(OffsetFloatPointer(desc.m_pTexCoord[0], output, desc.m_VertexSize_TexCoord[0]), uv, 8);
            desc.m_pIndices[output] = static_cast<unsigned short>(desc.m_nFirstVertex + output);
            ++output;
        });
        mesh->UnlockMesh(count, count, desc);
        return nullptr;
    }

    LUA_FUNCTION_STATIC(backend) {
        LUA->PushString(getContext ? "native" : "public");
        return 1;
    }
    LUA_FUNCTION_STATIC(stats) {
        LUA->CreateTable();
        LUA->PushNumber(static_cast<double>(nativeBuilds)); LUA->SetField(-2, "nativeBuilds");
        LUA->PushNumber(static_cast<double>(publicBuilds)); LUA->SetField(-2, "publicBuilds");
        LUA->PushNumber(static_cast<double>(builtVertices)); LUA->SetField(-2, "vertices");
        LUA->PushNumber(buildMilliseconds); LUA->SetField(-2, "milliseconds");
        return 1;
    }

    void buildPublic(GarrysMod::Lua::ILuaBase* lua, const char* bytes, int count, int space, float height) {
        lua->ReferencePush(functions[Begin]); lua->Push(1); lua->PushNumber(triangles); lua->PushNumber(count / 3); lua->Call(3, 0);
        writeTriangles(bytes, count, space, height, [&](const Vertex& v, const Vector& point, const Vector& normal) {
            lua->ReferencePush(functions[Position]); lua->PushVector(point); lua->Call(1, 0);
            lua->ReferencePush(functions[Normal]); lua->PushVector(normal); lua->Call(1, 0);
            lua->ReferencePush(functions[Color]); for (auto color : v.rgba) lua->PushNumber(color); lua->Call(4, 0);
            lua->ReferencePush(functions[TexCoord]); lua->PushNumber(0); lua->PushNumber(v.u); lua->PushNumber(v.v); lua->Call(3, 0);
            lua->ReferencePush(functions[Advance]); lua->Call(0, 0);
        });
        lua->ReferencePush(functions[End]); lua->Call(0, 0);
    }

    LUA_FUNCTION_STATIC(buildMesh) {
        LUA->CheckType(1, GarrysMod::Lua::Type::IMesh);
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Build meshes on the client thread"), 0;
        auto start = std::chrono::steady_clock::now();
        auto body = packetBytes(LUA, 2);
        double offsetNumber = LUA->CheckNumber(3), countNumber = LUA->CheckNumber(4), spaceNumber = LUA->CheckNumber(5);
        if (!std::isfinite(offsetNumber) || !std::isfinite(countNumber) || !std::isfinite(spaceNumber)
            || offsetNumber < 0 || offsetNumber > body.size() || offsetNumber != std::floor(offsetNumber)
            || countNumber <= 0 || countNumber > 65532 || countNumber != std::floor(countNumber)
            || spaceNumber < 0 || spaceNumber > 2 || spaceNumber != std::floor(spaceNumber))
            return LUA->ThrowError("Invalid packed mesh range"), 0;
        size_t offset = static_cast<size_t>(offsetNumber);
        int count = static_cast<int>(countNumber), space = static_cast<int>(spaceNumber);
        double heightNumber = LUA->CheckNumber(6);
        if (!std::isfinite(heightNumber) || std::abs(heightNumber) > std::numeric_limits<float>::max()
            || count % 3 != 0 || count * sizeof(Vertex) > body.size() - offset)
            return LUA->ThrowError("Invalid packed mesh range"), 0;
        float height = static_cast<float>(heightNumber);
        const char* bytes = body.data() + offset;
        float largest = std::numeric_limits<float>::max();
        Vector minimum(largest, largest, largest), maximum(-largest, -largest, -largest);
        for (int i = 0; i < count; ++i) {
            Vertex v;
            std::memcpy(&v, bytes + i * sizeof(Vertex), sizeof(Vertex));
            auto point = position(v, space, height);
            if (!std::isfinite(point.x) || !std::isfinite(point.y) || !std::isfinite(point.z)
                || std::abs(point.x) > std::numeric_limits<float>::max() / 4
                || std::abs(point.y) > std::numeric_limits<float>::max() / 4
                || std::abs(point.z) > std::numeric_limits<float>::max() / 4
                || !std::isfinite(v.u) || !std::isfinite(v.v))
                return LUA->ThrowError("Packed mesh contains nonfinite vertices"), 0;
            for (int axis = 0; axis < 3; ++axis) {
                minimum[axis] = std::min(minimum[axis], point[axis]);
                maximum[axis] = std::max(maximum[axis], point[axis]);
            }
        }
        bool publicBackend = LUA->IsType(7, GarrysMod::Lua::Type::Bool) && LUA->GetBool(7);
        if (getContext && !publicBackend) {
            auto* handle = LUA->GetUserType<MeshHandle>(1, GarrysMod::Lua::Type::IMesh);
            if (!handle || handle->magic != 1 || !handle->mesh) return LUA->ThrowError("Invalid native mesh handle"), 0;
            if (const char* error = buildNative(handle->mesh, bytes, count, space, height)) return LUA->ThrowError(error), 0;
            ++nativeBuilds;
        } else {
            buildPublic(LUA, bytes, count, space, height);
            ++publicBuilds;
        }
        builtVertices += count;
        buildMilliseconds += std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
        LUA->PushVector(minimum);
        LUA->PushVector(maximum);
        std::array<Vector, 3> firstTriangle;
        for (int i = 0; i < 3; ++i) {
            Vertex vertex;
            std::memcpy(&vertex, bytes + i * sizeof(Vertex), sizeof(Vertex));
            firstTriangle[i] = position(vertex, space, height);
        }
        Vector normal = (firstTriangle[1] - firstTriangle[0]).Cross(firstTriangle[2] - firstTriangle[0]);
        const float length = std::sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z);
        if (length > 0) normal /= length;
        LUA->PushVector(normal);
        Vector probeNormal = normal;
        // Keep the probe near the face's center, but on actual geometry. The first
        // triangle can lie below native flooring, and a batch centroid can lie in a hole.
        const Vector center = (minimum + maximum) / 2.f;
        Vector probe = (firstTriangle[0] + firstTriangle[1] + firstTriangle[2]) / 3.f;
        float nearest = (probe - center).LengthSqr();
        for (int first = 3; first < count; first += 3) {
            Vector candidate(0, 0, 0);
            std::array<Vector, 3> triangle;
            for (int i = 0; i < 3; ++i) {
                Vertex vertex;
                std::memcpy(&vertex, bytes + (first + i) * sizeof(Vertex), sizeof(Vertex));
                triangle[i] = position(vertex, space, height);
                candidate += triangle[i] / 3.f;
            }
            const float distance = (candidate - center).LengthSqr();
            if (distance < nearest) {
                probeNormal = (triangle[1] - triangle[0]).Cross(triangle[2] - triangle[0]);
                const float probeLength = std::sqrt(probeNormal.LengthSqr());
                if (probeLength > 0) probeNormal /= probeLength;
                nearest = distance;
                probe = candidate;
            }
        }
        LUA->PushVector(probe + probeNormal * .5f);
        return 4;
    }
}

void registerMeshes(GarrysMod::Lua::ILuaBase* lua) {
    ownerThread = GetCurrentThreadId();
    findNativeBackend();
    lua->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
    lua->GetField(-1, "MATERIAL_TRIANGLES"); triangles = static_cast<int>(lua->GetNumber(-1)); lua->Pop();
    lua->GetField(-1, "mesh");
    const char* names[] = {"Begin", "Position", "Normal", "Color", "TexCoord", "AdvanceVertex", "End"};
    for (int i = 0; i < 7; ++i) { lua->GetField(-1, names[i]); functions[i] = lua->ReferenceCreate(); }
    lua->Pop(2);
    lua->PushCFunction(buildMesh); lua->SetField(-2, "build_mesh");
    lua->PushCFunction(backend); lua->SetField(-2, "mesh_backend");
    lua->PushCFunction(stats); lua->SetField(-2, "mesh_stats");
}
void releaseMeshes(GarrysMod::Lua::ILuaBase* lua) {
    for (int reference : functions) lua->ReferenceFree(reference);
    materialSystem = nullptr;
    getContext = nullptr;
    nativeBuilds = publicBuilds = builtVertices = 0;
    buildMilliseconds = 0;
}
