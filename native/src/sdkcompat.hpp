#pragma once
#include <Windows.h>
#include <tier1/interface.h>

namespace sdkcompat {
    // Verify the exact Windows x64 engine build before using its non-versioned SDK layouts.
    inline bool matchesBuild(HMODULE module, DWORD timestamp, DWORD imageSize, DWORD checksum) {
        if (!module) return false;
        auto* base = reinterpret_cast<const unsigned char*>(module);
        auto* dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(base);
        auto* nt = reinterpret_cast<const IMAGE_NT_HEADERS64*>(base + dos->e_lfanew);
        return nt->FileHeader.Machine == IMAGE_FILE_MACHINE_AMD64 && nt->FileHeader.TimeDateStamp == timestamp
            && nt->OptionalHeader.SizeOfImage == imageSize && nt->OptionalHeader.CheckSum == checksum;
    }

    inline bool supportedClient() {
        return matchesBuild(GetModuleHandleW(L"client.dll"), 0x6ab2b438, 0xb78000, 0x9ba819);
    }

    inline bool supportedEngine() {
        return matchesBuild(GetModuleHandleW(L"engine.dll"), 0x6ab2b381, 0xe52000, 0x572c76);
    }

    inline void* studioRender() {
        auto module = GetModuleHandleW(L"studiorender.dll");
        if (!matchesBuild(module, 0x6aa9c7cb, 0x835000, 0xe281d)) return nullptr;
        auto factory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(module, "CreateInterface"));
        return factory ? factory("VStudioRender025", nullptr) : nullptr;
    }

    inline void* materialSystem() {
        auto module = GetModuleHandleW(L"materialsystem.dll");
        if (!matchesBuild(module, 0x6aa9c7a1, 0x2151000, 0x128def)) return nullptr;
        auto factory = reinterpret_cast<CreateInterfaceFn>(GetProcAddress(module, "CreateInterface"));
        return factory ? factory("VMaterialSystem080", nullptr) : nullptr;
    }
}
