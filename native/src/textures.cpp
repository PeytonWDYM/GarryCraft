#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <tier1/interface.h>
#include <vtf/vtf.h>
#include <texture_group_names.h>
#include <materialsystem/itexture.h>
#include "textures.hpp"
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
    class Pixels final : public ITextureRegenerator {
    public:
        std::vector<unsigned char> rgba;
        int width = 0, height = 0;
        bool flip = false;
        void RegenerateTextureBits(ITexture*, IVTFTexture* image, Rect_t*) override {
            // One mip and one frame. The material system owns the destination buffer.
            auto* destination = image->ImageData(0, 0, 0);
            std::memset(destination, 0, static_cast<size_t>(image->Width()) * image->Height() * 4);
            for (int y = 0; y < height; ++y) {
                auto* row = destination + static_cast<size_t>(y) * image->Width() * 4;
                const auto* source = rgba.data() + static_cast<size_t>(flip ? height - y - 1 : y) * width * 4;
                if (image->Format() == IMAGE_FORMAT_BGRA8888) {
                    for (int x = 0; x < width; ++x) {
                        row[x * 4] = source[x * 4 + 2];
                        row[x * 4 + 1] = source[x * 4 + 1];
                        row[x * 4 + 2] = source[x * 4];
                        row[x * 4 + 3] = source[x * 4 + 3];
                    }
                } else std::memcpy(row, source, static_cast<size_t>(width) * 4);
            }
        }
        void Release() override { delete this; }
    };
    struct Texture { ITexture* texture; Pixels* pixels; int width; int height; };
    std::unordered_map<std::string, Texture> textures;
    void* materialSystem = nullptr;
    using CreateTexture = ITexture* (__fastcall*)(void*, const char*, const char*, int, int, ImageFormat, int);
    CreateTexture createTexture = nullptr;

    LUA_FUNCTION_STATIC(upload) {
        const char* name = LUA->CheckString(1);
        int width = static_cast<int>(LUA->CheckNumber(2));
        int height = static_cast<int>(LUA->CheckNumber(3));
        LUA->CheckType(4, GarrysMod::Lua::Type::String);
        unsigned length;
        const char* data = LUA->GetString(4, &length);
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
        if (found == textures.end()) {
            auto* pixels = new Pixels();
            pixels->width = width;
            pixels->height = height;
            pixels->rgba.assign(data, data + length);
            auto* texture = createTexture(materialSystem, name, TEXTURE_GROUP_OTHER, width, height,
                IMAGE_FORMAT_RGBA8888, TEXTUREFLAGS_NOMIP | TEXTUREFLAGS_NOLOD | TEXTUREFLAGS_CLAMPS
                | TEXTUREFLAGS_CLAMPT | TEXTUREFLAGS_POINTSAMPLE | TEXTUREFLAGS_EIGHTBITALPHA);
            pixels->flip = LUA->GetBool(5);
            texture->IncrementReferenceCount();
            texture->SetTextureRegenerator(pixels);
            found = textures.emplace(name, Texture{texture, pixels, width, height}).first;
        } else found->second.pixels->rgba.assign(data, data + length);
        found->second.texture->Download();
        LUA->PushUserType(found->second.texture, GarrysMod::Lua::Type::Texture);
        return 1;
    }
}

void registerTextures(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(upload);
    lua->SetField(-2, "upload");
}

void releaseTextures() {
    for (auto& [name, entry] : textures) {
        entry.texture->SetTextureRegenerator(nullptr);
        entry.texture->DecrementReferenceCount();
    }
    textures.clear();
    materialSystem = nullptr;
}
