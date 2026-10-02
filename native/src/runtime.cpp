#include <GarrysMod/Lua/Interface.h>
#include <Windows.h>
#include <filesystem>
#include <string>
#include "runtime.hpp"

namespace {
    std::wstring wide(const char* value) {
        int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, nullptr, 0);
        if (!size) throw std::runtime_error("Runtime path must be UTF-8");
        std::wstring result(size, L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1, result.data(), size);
        result.pop_back();
        return result;
    }

    // Quote one Windows argv item, including trailing backslashes.
    std::wstring quote(const std::wstring& value) {
        std::wstring result = L"\"";
        unsigned slashes = 0;
        for (auto c : value) {
            if (c == L'\\') { ++slashes; continue; }
            result.append(c == L'"' ? slashes * 2 + 1 : slashes, L'\\');
            result += c;
            slashes = 0;
        }
        result.append(slashes * 2, L'\\');
        return result + L'"';
    }

    LUA_FUNCTION_STATIC(startRuntime) {
        try {
            auto root = std::filesystem::path(wide(LUA->CheckString(1)));
            wchar_t gamePath[32768], systemPath[MAX_PATH];
            auto length = GetModuleFileNameW(nullptr, gamePath, 32768);
            if (!length || length == 32768) throw std::runtime_error("Cannot locate GMod");
            GetSystemDirectoryW(systemPath, MAX_PATH);
            auto shell = std::filesystem::path(systemPath) / L"WindowsPowerShell/v1.0/powershell.exe";
            auto data = std::filesystem::path(gamePath).parent_path().parent_path().parent_path() / L"garrysmod/data";
            auto command = quote(shell.wstring()) + L" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "
                + quote((root / L"Runtime.ps1").wstring()) + L" -Config " + quote((root / L"config.json").wstring())
                + L" -DataPath " + quote(data.wstring()) + L" -HostPid " + std::to_wstring(GetCurrentProcessId());
            STARTUPINFOW startup{};
            startup.cb = sizeof(startup);
            startup.dwFlags = STARTF_USESHOWWINDOW;
            startup.wShowWindow = SW_HIDE;
            PROCESS_INFORMATION process{};
            if (!CreateProcessW(shell.c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW,
                    nullptr, root.c_str(), &startup, &process))
                throw std::runtime_error("Cannot start Minecraft launcher: Windows error " + std::to_string(GetLastError()));
            CloseHandle(process.hThread);
            CloseHandle(process.hProcess);
        } catch (const std::exception& error) { return LUA->ThrowError(error.what()), 0; }
        return 0;
    }
}

void registerRuntime(GarrysMod::Lua::ILuaBase* lua) {
    lua->PushCFunction(startRuntime);
    lua->SetField(-2, "runtime_start");
}
