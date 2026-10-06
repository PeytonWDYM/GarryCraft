#include <GarrysMod/Lua/Interface.h>
#include "platform.hpp"
#include "sdkcompat.hpp"
#include <tier1/interface.h>
#ifdef _WIN32
#include <vtf/vtf.h>
#else
#include <bitmap/imageformat.h>
#include <tier0/basetypes.h>
#include <cstddef>
// Linux declarations matching vtf/vtf.h from the pinned garrysmod_common SDK.
// The real vtf.h pulls in mathlib/vector.h, whose threadtools.h dependency is
// not LP64-clean in this SDK snapshot (CInterlockedIntT assumes 4-byte long).
// Only pure-virtual interfaces and enums are repeated here, in exact vtable
// order, so calls into engine objects use the verified dispatch slots. Byte
// layout is unaffected: Vector is 12 bytes on both sides and only appears in
// const-reference parameters of methods the bridge never calls.
class CUtlBuffer;
struct VtfProcessingOptions;
enum LookDir_t
{
	LOOK_DOWN_X = 0,
	LOOK_DOWN_NEGX,
	LOOK_DOWN_Y,
	LOOK_DOWN_NEGY,
	LOOK_DOWN_Z,
	LOOK_DOWN_NEGZ,
};
enum CompiledVtfFlags
{
	TEXTUREFLAGS_POINTSAMPLE	               = 0x00000001,
	TEXTUREFLAGS_TRILINEAR		               = 0x00000002,
	TEXTUREFLAGS_CLAMPS			               = 0x00000004,
	TEXTUREFLAGS_CLAMPT			               = 0x00000008,
	TEXTUREFLAGS_ANISOTROPIC	               = 0x00000010,
	TEXTUREFLAGS_HINT_DXT5		               = 0x00000020,
	TEXTUREFLAGS_SRGB						   = 0x00000040,
	TEXTUREFLAGS_NORMAL			               = 0x00000080,
	TEXTUREFLAGS_NOMIP			               = 0x00000100,
	TEXTUREFLAGS_NOLOD			               = 0x00000200,
	TEXTUREFLAGS_ALL_MIPS			           = 0x00000400,
	TEXTUREFLAGS_PROCEDURAL		               = 0x00000800,
	TEXTUREFLAGS_ONEBITALPHA	               = 0x00001000,
	TEXTUREFLAGS_EIGHTBITALPHA	               = 0x00002000,
	TEXTUREFLAGS_ENVMAP			               = 0x00004000,
	TEXTUREFLAGS_RENDERTARGET	               = 0x00008000,
	TEXTUREFLAGS_DEPTHRENDERTARGET	           = 0x00010000,
	TEXTUREFLAGS_NODEBUGOVERRIDE               = 0x00020000,
	TEXTUREFLAGS_SINGLECOPY		               = 0x00040000,
	TEXTUREFLAGS_STAGING_MEMORY                = 0x00080000,
	TEXTUREFLAGS_IMMEDIATE_CLEANUP			   = 0x00100000,
	TEXTUREFLAGS_IGNORE_PICMIP				   = 0x00200000,
	TEXTUREFLAGS_UNUSED_00400000               = 0x00400000,
	TEXTUREFLAGS_NODEPTHBUFFER                 = 0x00800000,
	TEXTUREFLAGS_UNUSED_01000000               = 0x01000000,
	TEXTUREFLAGS_CLAMPU                        = 0x02000000,
	TEXTUREFLAGS_VERTEXTEXTURE                 = 0x04000000,
	TEXTUREFLAGS_SSBUMP                        = 0x08000000,
	TEXTUREFLAGS_UNUSED_10000000               = 0x10000000,
	TEXTUREFLAGS_BORDER						   = 0x20000000,
	TEXTUREFLAGS_UNUSED_40000000		       = 0x40000000,
	TEXTUREFLAGS_UNUSED_80000000		       = 0x80000000,
};
class IVTFTexture
{
public:
	virtual ~IVTFTexture() {}
	virtual bool Init( int nWidth, int nHeight, int nDepth, ImageFormat fmt, int nFlags, int iFrameCount, int nForceMipCount = -1 ) = 0;
	virtual void SetBumpScale( float flScale ) = 0;
	virtual void SetReflectivity( const Vector &vecReflectivity ) = 0;
	virtual void InitLowResImage( int nWidth, int nHeight, ImageFormat fmt ) = 0;
	virtual void *SetResourceData( uint32 eType, void const *pData, size_t nDataSize ) = 0;
	virtual void *GetResourceData( uint32 eType, size_t *pDataSize ) const = 0;
	virtual bool HasResourceEntry( uint32 eType ) const = 0;
	virtual unsigned int GetResourceTypes( uint32 *arrTypesBuffer, int numTypesBufferElems ) const = 0;
	virtual bool Unserialize( CUtlBuffer &buf, bool bHeaderOnly = false, int nSkipMipLevels = 0 ) = 0;
	virtual bool Serialize( CUtlBuffer &buf ) = 0;
	virtual void LowResFileInfo( int *pStartLocation, int *pSizeInBytes) const = 0;
	virtual void ImageFileInfo( int nFrame, int nFace, int nMip, int *pStartLocation, int *pSizeInBytes) const = 0;
	virtual int FileSize( int nMipSkipCount = 0 ) const = 0;
	virtual int Width() const = 0;
	virtual int Height() const = 0;
	virtual int Depth() const = 0;
	virtual int MipCount() const = 0;
	virtual int RowSizeInBytes( int nMipLevel ) const = 0;
	virtual int FaceSizeInBytes( int nMipLevel ) const = 0;
	virtual ImageFormat Format() const = 0;
	virtual int FaceCount() const = 0;
	virtual int FrameCount() const = 0;
	virtual int Flags() const = 0;
	virtual float BumpScale() const = 0;
	virtual int LowResWidth() const = 0;
	virtual int LowResHeight() const = 0;
	virtual ImageFormat LowResFormat() const = 0;
	virtual const Vector &Reflectivity() const = 0;
	virtual bool IsCubeMap() const = 0;
	virtual bool IsNormalMap() const = 0;
	virtual bool IsVolumeTexture() const = 0;
	virtual void ComputeMipLevelDimensions( int iMipLevel, int *pMipWidth, int *pMipHeight, int *pMipDepth ) const = 0;
	virtual int ComputeMipSize( int iMipLevel ) const = 0;
	virtual void ComputeMipLevelSubRect( Rect_t* pSrcRect, int nMipLevel, Rect_t *pSubRect ) const = 0;
	virtual int ComputeFaceSize( int iStartingMipLevel = 0 ) const = 0;
	virtual int ComputeTotalSize() const = 0;
	virtual unsigned char *ImageData() = 0;
	virtual unsigned char *ImageData( int iFrame, int iFace, int iMipLevel ) = 0;
	virtual unsigned char *ImageData( int iFrame, int iFace, int iMipLevel, int x, int y, int z = 0 ) = 0;
	virtual unsigned char *LowResImageData() = 0;
	virtual	void ConvertImageFormat( ImageFormat fmt, bool bNormalToDUDV ) = 0;
	virtual void GenerateSpheremap( LookDir_t lookDir = LOOK_DOWN_Z ) = 0;
	virtual void GenerateHemisphereMap( unsigned char *pSphereMapBitsRGBA, int targetWidth,
		int targetHeight, LookDir_t lookDir, int iFrame ) = 0;
	virtual void FixCubemapFaceOrientation( ) = 0;
	virtual void GenerateMipmaps() = 0;
	virtual void PutOneOverMipLevelInAlpha() = 0;
	virtual void ComputeReflectivity( ) = 0;
	virtual void ComputeAlphaFlags() = 0;
	virtual bool ConstructLowResImage() = 0;
	virtual void PostProcess(bool bGenerateSpheremap, LookDir_t lookDir = LOOK_DOWN_Z, bool bAllowFixCubemapOrientation = true) = 0;
	virtual void MatchCubeMapBorders( int iStage, ImageFormat finalFormat, bool bSkybox ) = 0;
	virtual void SetAlphaTestThreshholds( float flBase, float flHighFreq ) = 0;
	virtual void SetPostProcessingSettings( VtfProcessingOptions const *pOptions ) = 0;
};
#endif
#include <texture_group_names.h>
#include <materialsystem/itexture.h>
#include "textures.hpp"
#include "packets.hpp"
#include <cstdint>
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
    std::uint32_t ownerThread;
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
    std::uint64_t textureGeneration = 0;
    void* materialSystem = nullptr;
    using CreateTexture = ITexture* (GCALL*)(void*, const char*, const char*, int, int, ImageFormat, int);
    CreateTexture createTexture = nullptr;

    void retireTextures() {
        for (auto& [name, entry] : textures) {
            entry.pixels->retire();
            retired.push_back(std::move(entry.pixels));
        }
        textures.clear();
    }

    LUA_FUNCTION_STATIC(resetVideo) {
        if (platform::currentThreadId() != ownerThread) return LUA->ThrowError("Reset textures on the client thread"), 0;
        bool reset = needsReset.exchange(false);
        LUA->PushBool(reset);
        if (!reset) return 1;
        retireTextures();
        ++textureGeneration;
        return 1;
    }

    LUA_FUNCTION_STATIC(upload) {
        if (platform::currentThreadId() != ownerThread) return LUA->ThrowError("Upload textures on the client thread"), 0;
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
    ownerThread = platform::currentThreadId();
    // Source retains texture names across map reloads, even when the client Lua module reloads.
    // A new lifetime must not retrieve its predecessor's released procedural texture.
    textureGeneration = platform::tickCount64();
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
