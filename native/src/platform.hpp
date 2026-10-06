#pragma once
// Portable shims for the Windows-only APIs used by the bridge modules.
// Windows builds keep their exact behavior. Linux builds use POSIX equivalents
// with the same wire protocol and Lua surface.
#include <chrono>
#include <cstdint>
#include <string>

#ifdef _WIN32
#include <Windows.h>
namespace platform {
    using BridgePath = std::wstring;
    using ModuleHandle = HMODULE;
    // MSVC x64 fastcall matches the Source SDK dispatch tables.
#define GCALL __fastcall
    inline std::uint32_t currentThreadId() { return GetCurrentThreadId(); }
    inline std::uint64_t tickCount64() { return GetTickCount64(); }
    inline double nowSeconds() {
        LARGE_INTEGER counter, frequency;
        QueryPerformanceCounter(&counter);
        QueryPerformanceFrequency(&frequency);
        return static_cast<double>(counter.QuadPart) / frequency.QuadPart;
    }
    inline double displayRefreshHz() {
        DEVMODEW mode{};
        mode.dmSize = sizeof(mode);
        if (!EnumDisplaySettingsW(nullptr, ENUM_CURRENT_SETTINGS, &mode))
            throw std::runtime_error("Cannot read display refresh rate");
        return static_cast<double>(mode.dmDisplayFrequency);
    }
    inline BridgePath utf8ToPath(const char* value) {
        int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, nullptr, 0);
        if (!size) throw std::runtime_error("Bridge path must be UTF-8");
        BridgePath result(size, L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, result.data(), size);
        result.pop_back();
        return result;
    }
}
#else
#include <ctime>
#include <pthread.h>
#include <stdexcept>
#include <unistd.h>
namespace platform {
    using BridgePath = std::string;
    using ModuleHandle = void*;
    // System V AMD64 passes the first arguments in registers, matching the
    // SDK's Linux dispatch tables. No MSVC-style fastcall keyword exists.
#define GCALL
    inline std::uint32_t currentThreadId() { return static_cast<std::uint32_t>(::gettid()); }
    inline std::uint64_t tickCount64() {
        return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()).count());
    }
    // Shared monotonic clock with the Fabric mod, which reads
    // clock_gettime(CLOCK_MONOTONIC) through BridgeClock.
    inline double nowSeconds() {
        struct timespec value{};
        if (::clock_gettime(CLOCK_MONOTONIC, &value) != 0)
            throw std::runtime_error("Cannot read monotonic clock");
        return static_cast<double>(value.tv_sec) + static_cast<double>(value.tv_nsec) / 1e9;
    }
    // Source owns the frame limiter on Linux; report the common default until a
    // display query is wired up. Matches the 240 FPS cap the addon applies.
    inline double displayRefreshHz() { return 60.0; }
    inline BridgePath utf8ToPath(const char* value) {
        if (!value) throw std::runtime_error("Bridge path must be UTF-8");
        return BridgePath(value);
    }
}
#endif
