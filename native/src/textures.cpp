#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <tier1/interface.h>
#include <vtf/vtf.h>
#include <texture_group_names.h>
#include <materialsystem/itexture.h>
#include "textures.hpp"
#include "packets.hpp"
#include <cstring>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
#include <algorithm>
#include <atomic>
#include <cmath>

namespace {
    std::atomic_bool needsReset = false;
    class Pixels final : public ITextureRegenerator {
    public:
        std::vector<unsigned char> rgba;
        int width = 0, height = 0;
        bool flip = false;
        void RegenerateTextureBits(ITexture*, IVTFTexture* image, Rect_t* rectangle) override {
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
        // GMod releases regenerators during a video mode change. The module cache retains their pixels.
        void Release() override { needsReset = true; }
    };
    struct Texture { ITexture* texture; std::unique_ptr<Pixels> pixels; int width; int height; std::string name; };
    std::unordered_map<std::string, Texture> textures;
    // Old mode handles are invalid. Keep callback storage until the module exits without calling those handles again.
    std::vector<Texture> retired;
    ULONGLONG textureGeneration = 0;
    void* materialSystem = nullptr;
    using CreateTexture = ITexture* (__fastcall*)(void*, const char*, const char*, int, int, ImageFormat, int);
    CreateTexture createTexture = nullptr;

    LUA_FUNCTION_STATIC(resetVideo) {
        bool reset = needsReset.exchange(false);
        LUA->PushBool(reset);
        if (!reset) return 1;
        for (auto& [name, entry] : textures) retired.push_back(std::move(entry));
        textures.clear();
        ++textureGeneration;
        return 1;
    }

    LUA_FUNCTION_STATIC(upload) {
        const char* name = LUA->CheckString(1);
        int width = static_cast<int>(LUA->CheckNumber(2));
        int height = static_cast<int>(LUA->CheckNumber(3));
        auto body = packetBytes(LUA, 4);
        size_t length = body.size();
        const char* data = body.data();
        // Overlay tiles refer directly to their packet. Lua does not make pixel substrings.
        if (LUA->IsType(6, GarrysMod::Lua::Type::Number)) {
            double offset = LUA->CheckNumber(6);
            double count = LUA->CheckNumber(7);
            if (offset < 0 || count < 0 || offset > length || count > length - offset
                || offset != std::floor(offset) || count != std::floor(count))
                return LUA->ThrowError("Invalid texture packet range"), 0;
            data += static_cast<size_t>(offset);
            length = static_cast<unsigned>(count);
        }
        if (width <= 0 || height <= 0 || width > 4096 || height > 4096
            || static_cast<size_t>(width) * height * 4 != length)
            return LUA->ThrowError("Invalid RGBA texture dimensions"), 0;
        if (!materialSystem) {
            auto module = GetModuleHandleW(L"materialsystem.dll");
            auto factory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(module, "CreateInterface"));
            if (!factory) return LUA->ThrowError("Material system factory unavailable"), 0;
            materialSystem = factory("VMaterialSystem080", nullptr);
            if (!materialSystem) return LUA->ThrowError("Material system interface unavailable"), 0;
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
            pixels->rgba.assign(data, data + length);
            auto nativeName = std::string(name) + "/generation" + std::to_string(textureGeneration);
            auto* texture = createTexture(materialSystem, nativeName.c_str(), TEXTURE_GROUP_OTHER, width, height,
                IMAGE_FORMAT_RGBA8888, TEXTUREFLAGS_NOMIP | TEXTUREFLAGS_NOLOD | TEXTUREFLAGS_CLAMPS
                | TEXTUREFLAGS_CLAMPT | TEXTUREFLAGS_POINTSAMPLE | TEXTUREFLAGS_EIGHTBITALPHA);
            pixels->flip = LUA->GetBool(5);
            texture->IncrementReferenceCount();
            texture->SetTextureRegenerator(pixels.get());
            found = textures.emplace(name, Texture{texture, std::move(pixels), width, height, std::move(nativeName)}).first;
        } else {
            auto& pixels = *found->second.pixels;
            changed = std::memcmp(pixels.rgba.data(), data, length) != 0;
            if (changed) pixels.rgba.assign(data, data + length);
        }
        // Complete tiles survive skipped mailbox frames. Reuse unchanged tiles without a GPU upload.
        if (changed) found->second.texture->Download();
        // GMod creates its texture userdata through the material API, including its mode-switch bookkeeping.
        LUA->PushString(found->second.name.c_str());
        return 1;
    }
}

void registerTextures(GarrysMod::Lua::ILuaBase* lua) {
    // Source retains texture names across map reloads, even when the client Lua module reloads.
    // A new lifetime must not retrieve its predecessor's released procedural texture.
    textureGeneration = GetTickCount64();
    lua->PushCFunction(upload);
    lua->SetField(-2, "upload");
    lua->PushCFunction(resetVideo);
    lua->SetField(-2, "textures_reset");
}

void releaseTextures() {
    for (auto& [name, entry] : textures) {
        entry.texture->SetTextureRegenerator(nullptr);
        entry.texture->DecrementReferenceCount();
    }
    textures.clear();
    needsReset = false;
    materialSystem = nullptr;
}
