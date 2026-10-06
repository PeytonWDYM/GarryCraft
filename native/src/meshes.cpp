#include <GarrysMod/Lua/Interface.h>
#include "platform.hpp"
#ifdef _WIN32
#include <emmintrin.h>
#endif
#include <cstring>

#ifdef _WIN32
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
#endif
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
#ifdef _WIN32
    static_assert(sizeof(MeshDesc_t) == 0x108);
    struct MeshHandle { std::uint32_t magic; IMesh* mesh; };
#else
    // The Linux build uses GMod's public mesh calls until the native buffer
    // layout is verified against real Linux binaries. The handle keeps the
    // same Lua-visible shape; the mesh pointer is never dereferenced here.
    struct MeshHandle { std::uint32_t magic; void* mesh; };
#endif
    // sizeof/alignof instead of offsetof: the SDK redefines offsetof as a
    // non-constant expression on GCC builds. {u32, pointer} can only lay out
    // as magic@0, mesh@8 with these size and alignment values.
    static_assert(sizeof(MeshHandle) == 16 && alignof(MeshHandle) == 8);
#ifdef _WIN32
    using GetContext = void* (GCALL*)(void*);
    using RenderOperation = void (GCALL*)(void*);
    void* materialSystem;
    GetContext getContext;
#else
    void* materialSystem = nullptr;
#endif
    std::uint32_t ownerThread;
    std::uint64_t nativeBuilds, publicBuilds, builtVertices;
    double buildMilliseconds;

#ifdef _WIN32
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
#endif

    // Minimal vector math on the Lua Vector layout (three floats). Used on
    // Linux, where the SDK's mathlib headers are unavailable; Windows keeps
    // the SDK operators through the same helper names.
    struct Point { float x, y, z; };
    inline Point toPoint(const Vector& v) { return {v.x, v.y, v.z}; }
    inline Vector toVector(const Point& p) { Vector v; v.x = p.x; v.y = p.y; v.z = p.z; return v; }
    inline Point sub(const Point& a, const Point& b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
    inline Point add(const Point& a, const Point& b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
    inline Point scale(const Point& a, float s) { return {a.x * s, a.y * s, a.z * s}; }
    inline Point divn(const Point& a, float s) { return {a.x / s, a.y / s, a.z / s}; }
    inline Point cross(const Point& a, const Point& b) {
        return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x};
    }
    inline float lengthSquared(const Point& a) { return a.x * a.x + a.y * a.y + a.z * a.z; }

    Vector position(const Vertex& v, int space, float height) {
        return space == 2 ? toVector({-v.z * 32, -v.x * 32, v.y * 32})
            : toVector({v.x * 32, -v.z * 32, v.y * 32 + (space == 1 ? height : 0)});
    }

    template<class Write> void writeTriangles(const char* bytes, int count, int space, float height, Write write) {
        for (int first = 0; first < count; first += 3) {
            std::array<Vertex, 3> vertices;
            std::array<Point, 3> positions;
            for (int i = 0; i < 3; ++i) {
                std::memcpy(&vertices[i], bytes + (first + i) * sizeof(Vertex), sizeof(Vertex));
                positions[i] = toPoint(position(vertices[i], space, height));
            }
            auto a = sub(positions[1], positions[0]);
            auto b = sub(positions[2], positions[0]);
            double nx = double(a.y) * b.z - double(a.z) * b.y;
            double ny = double(a.z) * b.x - double(a.x) * b.z;
            double nz = double(a.x) * b.y - double(a.y) * b.x;
            double length = std::sqrt(nx * nx + ny * ny + nz * nz);
            Point normal{0, 0, 0};
            if (length > 0)
                normal = {static_cast<float>(nx / length), static_cast<float>(ny / length), static_cast<float>(nz / length)};
            for (int i : {0, 2, 1}) write(vertices[i], toVector(positions[i]), toVector(normal));
        }
    }

#ifdef _WIN32
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
#endif

    LUA_FUNCTION_STATIC(backend) {
#ifdef _WIN32
        LUA->PushString(getContext ? "native" : "public");
#else
        LUA->PushString("public");
#endif
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
        if (platform::currentThreadId() != ownerThread) return LUA->ThrowError("Build meshes on the client thread"), 0;
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
        Point minimum{largest, largest, largest}, maximum{-largest, -largest, -largest};
        for (int i = 0; i < count; ++i) {
            Vertex v;
            std::memcpy(&v, bytes + i * sizeof(Vertex), sizeof(Vertex));
            auto point = toPoint(position(v, space, height));
            if (!std::isfinite(point.x) || !std::isfinite(point.y) || !std::isfinite(point.z)
                || std::abs(point.x) > std::numeric_limits<float>::max() / 4
                || std::abs(point.y) > std::numeric_limits<float>::max() / 4
                || std::abs(point.z) > std::numeric_limits<float>::max() / 4
                || !std::isfinite(v.u) || !std::isfinite(v.v))
                return LUA->ThrowError("Packed mesh contains nonfinite vertices"), 0;
            minimum.x = std::min(minimum.x, point.x); minimum.y = std::min(minimum.y, point.y); minimum.z = std::min(minimum.z, point.z);
            maximum.x = std::max(maximum.x, point.x); maximum.y = std::max(maximum.y, point.y); maximum.z = std::max(maximum.z, point.z);
        }
#ifdef _WIN32
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
#else
        buildPublic(LUA, bytes, count, space, height);
        ++publicBuilds;
#endif
        builtVertices += count;
        buildMilliseconds += std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
        LUA->PushVector(toVector(minimum));
        LUA->PushVector(toVector(maximum));
        std::array<Point, 3> firstTriangle;
        for (int i = 0; i < 3; ++i) {
            Vertex vertex;
            std::memcpy(&vertex, bytes + i * sizeof(Vertex), sizeof(Vertex));
            firstTriangle[i] = toPoint(position(vertex, space, height));
        }
        Point normal = cross(sub(firstTriangle[1], firstTriangle[0]), sub(firstTriangle[2], firstTriangle[0]));
        float length = std::sqrt(lengthSquared(normal));
        if (length > 0) normal = divn(normal, length);
        LUA->PushVector(toVector(normal));
        // Choose a point on an actual face. A concave batch's bounds center can lie inside another block.
        const Point center = divn(add(minimum, maximum), 2.0f);
        Point surfaceOrigin = divn(add(add(firstTriangle[0], firstTriangle[1]), firstTriangle[2]), 3.0f);
        Point surfaceNormal = normal;
        float nearest = lengthSquared(sub(surfaceOrigin, center));
        for (int first = 3; first < count; first += 3) {
            Point candidate{0, 0, 0};
            std::array<Point, 3> triangle;
            for (int i = 0; i < 3; ++i) {
                Vertex vertex;
                std::memcpy(&vertex, bytes + (first + i) * sizeof(Vertex), sizeof(Vertex));
                triangle[i] = toPoint(position(vertex, space, height));
                candidate = add(candidate, divn(triangle[i], 3.0f));
            }
            const float distance = lengthSquared(sub(candidate, center));
            if (distance < nearest) {
                surfaceNormal = cross(sub(triangle[1], triangle[0]), sub(triangle[2], triangle[0]));
                const float surfaceLength = std::sqrt(lengthSquared(surfaceNormal));
                if (surfaceLength > 0) surfaceNormal = divn(surfaceNormal, surfaceLength);
                nearest = distance;
                surfaceOrigin = candidate;
            }
        }
        LUA->PushVector(toVector(add(surfaceOrigin, scale(surfaceNormal, .5f))));
        return 4;
    }
}

void registerMeshes(GarrysMod::Lua::ILuaBase* lua) {
    ownerThread = platform::currentThreadId();
#ifdef _WIN32
    findNativeBackend();
#endif
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
#ifdef _WIN32
    getContext = nullptr;
#endif
    nativeBuilds = publicBuilds = builtVertices = 0;
    buildMilliseconds = 0;
}
