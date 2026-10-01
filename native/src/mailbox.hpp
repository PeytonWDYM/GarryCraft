#pragma once
#include <Windows.h>
#include <array>
#include <optional>
#include <string>
#include <string_view>

// Each lane has one writer. Readers never wait for a writer or call into either game.
class Mailbox {
public:
    static constexpr size_t fileSize = 128 * 1024 * 1024;
    static constexpr std::array<size_t, 8> capacities{64 * 1024, 4 * 1024 * 1024,
        16 * 1024 * 1024, 8 * 1024 * 1024, 16 * 1024 * 1024, 8 * 1024 * 1024, 64 * 1024 * 1024, 8 * 1024 * 1024};
    Mailbox() = default;
    ~Mailbox();
    Mailbox(const Mailbox&) = delete;
    Mailbox& operator=(const Mailbox&) = delete;
    void open(const std::wstring& path);
    void close();
    void send(unsigned lane, std::string_view payload);
    std::optional<std::string> receive(unsigned lane);
private:
    char* header(unsigned lane);
    HANDLE file_ = INVALID_HANDLE_VALUE;
    HANDLE mapping_ = nullptr;
    char* data_ = nullptr;
    std::array<LONG, capacities.size()> seen_{};
};
