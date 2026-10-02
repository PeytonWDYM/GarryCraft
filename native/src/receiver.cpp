#include "receiver.hpp"
#include <chrono>
#include <stdexcept>

void Receiver::start(const std::wstring& path) {
    stop();
    mailbox_.open(path);
    worker_ = std::jthread([this](std::stop_token stop) {
        try {
            while (!stop.stop_requested()) {
                for (unsigned lane : {1u, 4u, 5u, 6u, 7u}) {
                    auto packet = mailbox_.receive(lane);
                    if (!packet) continue;
                    auto payload = std::make_unique<std::string>(std::move(*packet));
                    // Destroy the previous packet outside the lock, including large HUD allocations.
                    { std::lock_guard lock(lanes_[lane].mutex); payload.swap(lanes_[lane].payload); }
                }
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            }
        } catch (const std::exception& error) {
            std::lock_guard lock(errorMutex_);
            error_ = error.what();
        }
    });
}

void Receiver::stop() {
    if (worker_.joinable()) { worker_.request_stop(); worker_.join(); }
    mailbox_.close();
    for (auto& lane : lanes_) lane.payload.reset();
    error_.clear();
}

std::unique_ptr<std::string> Receiver::take(unsigned lane) {
    if (lane >= lanes_.size()) throw std::out_of_range("Invalid bridge lane");
    {
        std::unique_lock lock(errorMutex_, std::try_to_lock);
        if (lock && !error_.empty()) throw std::runtime_error(error_);
    }
    std::unique_lock lock(lanes_[lane].mutex, std::try_to_lock);
    return lock ? std::move(lanes_[lane].payload) : nullptr;
}
