#pragma once
#include "mailbox.hpp"
#include <memory>
#include <mutex>
#include <thread>

// The worker copies render packets. The client only takes completed snapshots and never waits for a copy.
class Receiver {
public:
    ~Receiver() { stop(); }
    void start(const platform::BridgePath& path);
    void stop();
    std::unique_ptr<std::string> take(unsigned lane);
private:
    struct Lane {
        std::mutex mutex;
        std::unique_ptr<std::string> payload;
    };
    Mailbox mailbox_;
    std::array<Lane, Mailbox::capacities.size()> lanes_;
    std::jthread worker_;
    std::mutex errorMutex_;
    std::string error_;
};
