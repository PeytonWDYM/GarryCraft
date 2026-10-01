#include "mailbox.hpp"
#include <cstring>
#include <stdexcept>

namespace {
    [[noreturn]] void fail(const char* operation) {
        throw std::runtime_error(std::string(operation) + ": Windows error " + std::to_string(GetLastError()));
    }
}

Mailbox::~Mailbox() { close(); }

void Mailbox::close() {
    if (data_) UnmapViewOfFile(data_);
    if (mapping_) CloseHandle(mapping_);
    if (file_ != INVALID_HANDLE_VALUE) CloseHandle(file_);
    data_ = nullptr;
    mapping_ = nullptr;
    file_ = INVALID_HANDLE_VALUE;
    seen_.fill(0);
}

void Mailbox::open(const std::wstring& path) {
    close();
    file_ = CreateFileW(path.c_str(), GENERIC_READ | GENERIC_WRITE,
                        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file_ == INVALID_HANDLE_VALUE) fail("Open bridge");
    LARGE_INTEGER size;
    if (!GetFileSizeEx(file_, &size)) fail("Read bridge size");
    if (size.QuadPart != fileSize) {
        LARGE_INTEGER end;
        end.QuadPart = fileSize;
        if (!SetFilePointerEx(file_, end, nullptr, FILE_BEGIN) || !SetEndOfFile(file_)) fail("Size bridge");
    }
    mapping_ = CreateFileMappingW(file_, nullptr, PAGE_READWRITE, 0, fileSize, nullptr);
    if (!mapping_) fail("Map bridge");
    data_ = static_cast<char*>(MapViewOfFile(mapping_, FILE_MAP_ALL_ACCESS, 0, 0, fileSize));
    if (!data_) fail("View bridge");
}

char* Mailbox::header(unsigned lane) {
    if (!data_) throw std::runtime_error("Bridge is closed");
    if (lane >= capacities.size()) throw std::out_of_range("Bridge lane must be 0 through 6");
    size_t offset = 0;
    for (unsigned i = 0; i < lane; ++i) offset += 64 + capacities[i];
    return data_ + offset;
}

void Mailbox::send(unsigned lane, std::string_view payload) {
    char* slot = header(lane);
    if (payload.size() > capacities[lane]) throw std::length_error("Bridge payload exceeds lane capacity");
    auto* sequence = reinterpret_cast<volatile LONG*>(slot);
    LONG current = InterlockedCompareExchange(sequence, 0, 0);
    LONG writing = (current & ~1L) + 1;
    InterlockedExchange(sequence, writing);
    auto length = static_cast<unsigned>(payload.size());
    std::memcpy(slot + 4, &length, sizeof(length));
    std::memcpy(slot + 64, payload.data(), payload.size());
    InterlockedExchange(sequence, writing + 1);
}

std::optional<std::string> Mailbox::receive(unsigned lane) {
    char* slot = header(lane);
    auto* sequence = reinterpret_cast<volatile LONG*>(slot);
    LONG before = InterlockedCompareExchange(sequence, 0, 0);
    if ((before & 1) || before == seen_[lane]) return std::nullopt;
    unsigned length;
    std::memcpy(&length, slot + 4, sizeof(length));
    if (length > capacities[lane]) throw std::runtime_error("Invalid bridge payload length");
    std::string payload(slot + 64, length);
    LONG after = InterlockedCompareExchange(sequence, 0, 0);
    if (before != after) return std::nullopt;
    seen_[lane] = after;
    return payload;
}
