#pragma once

#ifdef _WIN32
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

#else
// Linux x86-64 engine guards. The x86-64 beta ships client and engine
// libraries as ELF shared objects (for example bin/linux64/engine_client.so
// and garrysmod/bin/linux64/client.so, depending on branch layout).
// Exact build pins (file size and SHA-256) are recorded in release.json after
// the first verified Linux game build and enforced by install.sh; the native
// guard below verifies that the loaded modules are 64-bit x86-64 ELF images
// exporting the required versioned interfaces. Dispatch slots are shared with
// the Windows x64 build from the same GMod x86-64 codebase until Linux
// measurements prove otherwise. Raw-offset shadow hooks stay disabled on
// Linux until their offsets are verified against real Linux binaries.
#include <dlfcn.h>
#include <elf.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <tier1/interface.h>

namespace sdkcompat {
    namespace detail {
        // Find a loaded module whose path contains one of the candidate names.
        inline std::string findModule(const char* const* names) {
            FILE* maps = std::fopen("/proc/self/maps", "r");
            if (!maps) return {};
            char line[8192];
            std::string found;
            while (std::fgets(line, sizeof(line), maps)) {
                const char* path = std::strchr(line, '/');
                if (!path) continue;
                std::string entry(path);
                while (!entry.empty() && (entry.back() == '\n' || entry.back() == ' ')) entry.pop_back();
                for (const char* const* name = names; *name; ++name) {
                    if (entry.find(*name) != std::string::npos) { found = entry; break; }
                }
                if (!found.empty()) break;
            }
            std::fclose(maps);
            return found;
        }
        inline bool isElf64X86(const std::string& path) {
            FILE* file = std::fopen(path.c_str(), "rb");
            if (!file) return false;
            Elf64_Ehdr header{};
            size_t read = std::fread(&header, 1, sizeof(header), file);
            std::fclose(file);
            if (read != sizeof(header)) return false;
            if (std::memcmp(header.e_ident, ELFMAG, SELFMAG) != 0) return false;
            if (header.e_ident[EI_CLASS] != ELFCLASS64) return false;
            return header.e_machine == EM_X86_64;
        }
        inline void* factoryFor(const char* const* names) {
            std::string path = findModule(names);
            if (path.empty() || !isElf64X86(path)) return nullptr;
            void* handle = ::dlopen(path.c_str(), RTLD_NOLOAD | RTLD_LAZY);
            if (!handle) return nullptr;
            return ::dlsym(handle, "CreateInterface");
        }
    }

    inline bool supportedClient() {
        static const char* names[] = {"client_client.so", "client.so", nullptr};
        std::string path = detail::findModule(names);
        return !path.empty() && detail::isElf64X86(path);
    }

    inline bool supportedEngine() {
        static const char* names[] = {"engine_client.so", "engine.so", nullptr};
        std::string path = detail::findModule(names);
        return !path.empty() && detail::isElf64X86(path);
    }

    inline void* studioRender() {
        static const char* names[] = {"studiorender_client.so", "studiorender.so", nullptr};
        auto factory = reinterpret_cast<CreateInterfaceFn>(detail::factoryFor(names));
        return factory ? factory("VStudioRender025", nullptr) : nullptr;
    }

    inline void* materialSystem() {
        static const char* names[] = {"materialsystem_client.so", "materialsystem.so", nullptr};
        auto factory = reinterpret_cast<CreateInterfaceFn>(detail::factoryFor(names));
        return factory ? factory("VMaterialSystem080", nullptr) : nullptr;
    }
}

#endif
