#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <tier1/interface.h>
#include <vtf/vtf.h>
#include <texture_group_names.h>
#include <materialsystem/itexture.h>
#include "textures.hpp"
#include "packets.hpp"
#include "sdkcompat.hpp"
#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <mutex>

namespace {
    std::atomic_bool needsReset = false;
    DWORD ownerThread;
    class Pixels final : public ITextureRegenerator {
        std::mutex mutex;
        std::vector<unsigned char> rgba;
        bool flip = false;
    public:
        int width = 0, height = 0;
        bool update(std::string_view bytes, bool flipImage) {
            std::lock_guard lock(mutex);
            bool changed = rgba.size() != bytes.size() || flip != flipImage
                || std::memcmp(rgba.data(), bytes.data(), bytes.size()) != 0;
            if (changed) rgba.assign(bytes.begin(), bytes.end());
            flip = flipImage;
            return changed;
        }
        void retire() {
            std::lock_guard lock(mutex);
            std::vector<unsigned char>().swap(rgba);
        }
        size_t bytes() {
            std::lock_guard lock(mutex);
            return rgba.size();
        }
        void RegenerateTextureBits(ITexture*, IVTFTexture* image, Rect_t* rectangle) override {
            // Serialize an engine callback with upload and retirement, including a late mode-switch callback.
            std::lock_guard lock(mutex);
            if (rgba.empty()) return;
            // One mip and one frame. The material system owns the destination buffer.
            auto* destination = image->ImageData(0, 0, 0);
            if (!rectangle) std::memset(destination, 0, static_cast<size_t>(image->Width()) * image->Height() * 4);
            int x0 = rectangle ? std::max(0, rectangle->x) : 0, y0 = rectangle ? std::max(0, rectangle->y) : 0;
            int x1 = std::min(width, image->Width()), y1 = std::min(height, image->Height());
            if (rectangle) { x1 = std::min(x1, rectangle->x + rectangle->width); y1 = std::min(y1, rectangle->y + rectangle->height); }
            if (x0 >= x1 || y0 >= y1) return;
            for (int y = y0; y < y1; ++y) {
                auto* row = destination + (static_cast<size_t>(y) * image->Width() + x0) * 4;
                const auto* source = rgba.data() + (static_cast<size_t>(flip ? height - y - 1 : y) * width + x0) * 4;
                if (image->Format() == IMAGE_FORMAT_BGRA8888) {
                    for (int x = 0; x < x1 - x0; ++x) {
                        row[x * 4] = source[x * 4 + 2];
                        row[x * 4 + 1] = source[x * 4 + 1];
                        row[x * 4 + 2] = source[x * 4];
                        row[x * 4 + 3] = source[x * 4 + 3];
                    }
                } else std::memcpy(row, source, static_cast<size_t>(x1 - x0) * 4);
            }
        }
        // GMod releases regenerators during a video mode change. The next client frame retires their pixels.
        void Release() override {
            std::lock_guard lock(mutex);
            if (!rgba.empty()) needsReset = true;
        }
    };
    struct Texture { ITexture* texture; std::unique_ptr<Pixels> pixels; int width; int height; std::string name; };
    std::unordered_map<std::string, Texture> textures;
    // Old mode handles are invalid. Keep callback storage until the module exits without calling those handles again.
    std::vector<std::unique_ptr<Pixels>> retired;
    ULONGLONG textureGeneration = 0;
    void* materialSystem = nullptr;
    using CreateTexture = ITexture* (__fastcall*)(void*, const char*, const char*, int, int, ImageFormat, int);
    CreateTexture createTexture = nullptr;

    void retireTextures() {
        for (auto& [name, entry] : textures) {
            entry.pixels->retire();
            retired.push_back(std::move(entry.pixels));
        }
        textures.clear();
    }

    LUA_FUNCTION_STATIC(resetVideo) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Reset textures on the client thread"), 0;
        bool reset = needsReset.exchange(false);
        LUA->PushBool(reset);
        if (!reset) return 1;
        retireTextures();
        ++textureGeneration;
        return 1;
    }

    LUA_FUNCTION_STATIC(upload) {
        if (GetCurrentThreadId() != ownerThread) return LUA->ThrowError("Upload textures on the client thread"), 0;
        const char* name = LUA->CheckString(1);
        double widthNumber = LUA->CheckNumber(2), heightNumber = LUA->CheckNumber(3);
        if (!std::isfinite(widthNumber) || !std::isfinite(heightNumber)
            || widthNumber <= 0 || heightNumber <= 0 || widthNumber > 4096 || heightNumber > 4096
            || widthNumber != std::floor(widthNumber) || heightNumber != std::floor(heightNumber))
            return LUA->ThrowError("Invalid RGBA texture dimensions"), 0;
        int width = static_cast<int>(widthNumber), height = static_cast<int>(heightNumber);
        auto body = packetBytes(LUA, 4);
        size_t length = body.size();
        const char* data = body.data();
        // Overlay tiles refer directly to their packet. Lua does not make pixel substrings.
        if (LUA->IsType(6, GarrysMod::Lua::Type::Number)) {
            double offset = LUA->CheckNumber(6);
            double count = LUA->CheckNumber(7);
            if (!std::isfinite(offset) || !std::isfinite(count) || offset < 0 || count < 0 || offset > length || count > length - offset
                || offset != std::floor(offset) || count != std::floor(count))
                return LUA->ThrowError("Invalid texture packet range"), 0;
            data += static_cast<size_t>(offset);
            length = static_cast<unsigned>(count);
        }
        if (static_cast<size_t>(width) * height * 4 != length)
            return LUA->ThrowError("Invalid RGBA texture dimensions"), 0;
        if (!materialSystem) {
            materialSystem = sdkcompat::materialSystem();
            if (!materialSystem) return LUA->ThrowError("Native texture upload does not support this GMod material-system build"), 0;
            auto** table = *reinterpret_cast<void***>(materialSystem);
            // GMod x86-64 adds four methods before texture creation in VMaterialSystem080.
            // Slot 85 was checked against this build's material-system dispatch table.
            createTexture = reinterpret_cast<CreateTexture>(table[85]);
        }
        auto found = textures.find(name);
        if (found != textures.end() && (found->second.width != width || found->second.height != height))
            return LUA->ThrowError("Use a new texture name when dimensions change"), 0;
        bool created = found == textures.end();
        bool changed = created;
        if (created) {
            auto pixels = std::make_unique<Pixels>();
            pixels->width = width;
            pixels->height = height;
            pixels->update({data, length}, LUA->GetBool(5));
            auto nativeName = std::string(name) + "/generation" + std::to_string(textureGeneration);
            auto* texture = createTexture(materialSystem, nativeName.c_str(), TEXTURE_GROUP_OTHER, width, height,
                IMAGE_FORMAT_RGBA8888, TEXTUREFLAGS_NOMIP | TEXTUREFLAGS_NOLOD | TEXTUREFLAGS_CLAMPS
                | TEXTUREFLAGS_CLAMPT | TEXTUREFLAGS_POINTSAMPLE | TEXTUREFLAGS_EIGHTBITALPHA);
            if (!texture) {
                pixels.reset();
                std::string().swap(nativeName);
                return LUA->ThrowError("Native texture creation failed"), 0;
            }
            texture->IncrementReferenceCount();
            texture->SetTextureRegenerator(pixels.get());
            found = textures.emplace(name, Texture{texture, std::move(pixels), width, height, std::move(nativeName)}).first;
        } else {
            changed = found->second.pixels->update({data, length}, LUA->GetBool(5));
        }
        // Complete tiles survive skipped mailbox frames. Reuse unchanged tiles without a GPU upload.
        if (changed) found->second.texture->Download();
        // GMod creates its texture userdata through the material API, including its mode-switch bookkeeping.
        LUA->PushString(found->second.name.c_str());
        return 1;
    }

    LUA_FUNCTION_STATIC(stats) {
        size_t activeBytes = 0, retiredBytes = 0;
        for (auto& [name, entry] : textures) activeBytes += entry.pixels->bytes();
        for (auto& pixels : retired) retiredBytes += pixels->bytes();
        LUA->CreateTable();
        LUA->PushNumber(static_cast<double>(activeBytes)); LUA->SetField(-2, "activeBytes");
        LUA->PushNumber(static_cast<double>(retiredBytes)); LUA->SetField(-2, "retiredBytes");
        LUA->PushNumber(static_cast<double>(textures.size())); LUA->SetField(-2, "activeTextures");
        LUA->PushNumber(static_cast<double>(retired.size())); LUA->SetField(-2, "retiredCallbacks");
        return 1;
    }
}

void registerTextures(GarrysMod::Lua::ILuaBase* lua) {
    ownerThread = GetCurrentThreadId();
    // Source retains texture names across map reloads, even when the client Lua module reloads.
    // A new lifetime must not retrieve its predecessor's released procedural texture.
    textureGeneration = GetTickCount64();
    lua->PushCFunction(upload);
    lua->SetField(-2, "upload");
    lua->PushCFunction(resetVideo);
    lua->SetField(-2, "textures_reset");
    lua->PushCFunction(stats);
    lua->SetField(-2, "texture_stats");
}

void releaseTextures() {
    if (needsReset.load()) retireTextures();
    for (auto& [name, entry] : textures) {
        entry.texture->SetTextureRegenerator(nullptr);
        entry.texture->DecrementReferenceCount();
    }
    textures.clear();
    needsReset = false;
    materialSystem = nullptr;
    createTexture = nullptr;
}
