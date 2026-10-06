#pragma once
#include "platform.hpp"
#include <array>
#include <atomic>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

// Each lane has one writer. Readers never wait for a writer or call into either game.
// The file layout matches fabric's Mailbox: 128 MiB, nine lanes, 64-byte headers,
// odd/even sequence publication with acquire/release ordering.
class Mailbox {
public:
    static constexpr size_t fileSize = 128 * 1024 * 1024;
    static constexpr std::array<size_t, 9> capacities{64 * 1024, 4 * 1024 * 1024,
        16 * 1024 * 1024, 8 * 1024 * 1024, 16 * 1024 * 1024, 8 * 1024 * 1024, 64 * 1024 * 1024, 8 * 1024 * 1024, 64 * 1024};
    Mailbox() = default;
    ~Mailbox();
    Mailbox(const Mailbox&) = delete;
    Mailbox& operator=(const Mailbox&) = delete;
    void open(const platform::BridgePath& path);
    void close();
    void send(unsigned lane, std::string_view payload);
    std::optional<std::string> receive(unsigned lane);
private:
    char* header(unsigned lane);
#ifdef _WIN32
    HANDLE file_ = INVALID_HANDLE_VALUE;
    HANDLE mapping_ = nullptr;
#else
    int file_ = -1;
#endif
    char* data_ = nullptr;
    std::array<std::int32_t, capacities.size()> seen_{};
};
