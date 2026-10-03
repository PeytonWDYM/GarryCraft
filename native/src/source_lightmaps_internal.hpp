#pragma once
#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <mathlib/vector.h>
#include <array>
#include <atomic>
#include <cstdint>
#include <cstring>
#include <map>
#include <mutex>
#include <vector>
namespace sourceLightmaps {
using GarrysMod::Lua::ILuaBase;
struct SortInfo { void* material; int page; int padding; };
static_assert(sizeof(SortInfo) == 16);
using SortCount = int (__fastcall*)(void*);
using PageSize = void (__fastcall*)(void*, int, int*, int*);
using SurfaceIndices = const std::uint16_t* (__fastcall*)(void*, int);
using SurfaceVertices = const Vector* (__fastcall*)(void*, int, int*);
using UpdateLightmap = void (__fastcall*)(void*, int, int*, int*, float*, float*, float*, float*);
using TileKey = std::array<int, 3>;
struct Tile {
    int width, height;
    std::array<std::vector<float>, 4> pixels, applied;
    bool modified = false;
};
struct Receiver {
    int handle, width, height;
    TileKey tile;
    Vector origin, stepS, stepT, normal, minimum, maximum;
    bool displacement;
    std::vector<Vector> positions, normals;
};
struct Upload { TileKey tile; int width, height; std::array<std::vector<float>, 4> pixels; };
template<class T> T read(const unsigned char* address) {
    T value; std::memcpy(&value, address, sizeof(value)); return value;
}
extern void* materialSystem;
extern void* modelInfo;
extern unsigned char** worldBrush;
extern SortInfo** worldSortInfo;
extern DWORD ownerThread;
extern const char* unsupported;
extern std::map<TileKey, Tile> originals;
extern std::mutex tileMutex;
extern UpdateLightmap originalUpdate;
extern void** observedSlot;
extern std::atomic_bool capturing;
extern std::atomic<std::uint64_t> captureRevision;
extern std::vector<Receiver> receivers;
extern bool active;
extern float gridHeight;
extern unsigned char* sessionWorld;
extern unsigned char* sessionSurfaces;
extern std::uint64_t lastVoxelRevision, lastCaptureRevision, lastSunRevision, uploads, restoredTiles, mappedLuxels, skippedDisplacements;
extern const char* closeMode;
bool readable(const void*, size_t);
void number(ILuaBase*, const char*, double);
void string(ILuaBase*, const char*, const char*);
void vector(ILuaBase*, const char*, const Vector&);
void boolean(ILuaBase*, const char*, bool);
void findBackend();
bool currentWorld();
void expandBounds(Receiver&, const Vector&);
bool buildReceivers();
bool startCapture();
void uploadBatch(const std::vector<Upload>&);
void restoreIrradiance();
void resetLightmapWork();
void invalidateLightmapWork();
void reportLightmapWork(ILuaBase*);
void stopCapture();
int probe(lua_State*);
int receiverAt(lua_State*);
int update(lua_State*);
int captureStart(lua_State*);
int captureStop(lua_State*);
}
