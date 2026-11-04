#pragma once
#include <condition_variable>
#include <cstdint>
#include <mutex>

namespace tdm {
// Normal callers enter FIFO. A completed consumer retires before the next
// transfer, but never passes a transfer already executing. The sole converter
// admission guarantees at most one retirement caller in the viewer.
class FairDmaMutex {
public:
    // Optional metadata cannot pass queued image transfers or retirements.
    bool tryLock() {
        std::lock_guard<std::mutex> lock(state_);
        if (held_ || retirements_ || issued_ != serving_) return false;
        held_ = true;
        return true;
    }
    void lock(bool retirement = false) {
        std::unique_lock<std::mutex> lock(state_);
        if (retirement) {
            ++retirements_;
            changed_.wait(lock, [&] { return !held_; });
            --retirements_;
        } else {
            const uint64_t ticket = issued_++;
            changed_.wait(lock, [&] { return !held_ && !retirements_ && ticket == serving_; });
            ++serving_;
        }
        held_ = true;
    }
    void unlock() {
        std::lock_guard<std::mutex> lock(state_);
        held_ = false;
        changed_.notify_all();
    }
private:
    friend struct FairDmaSelfTestAccess;
    std::mutex state_;
    std::condition_variable changed_;
    uint64_t issued_ = 0, serving_ = 0;
    unsigned retirements_ = 0;
    bool held_ = false;
};

class FairDmaGuard {
public:
    explicit FairDmaGuard(FairDmaMutex* mutex, bool retirement = false)
        : mutex_(mutex), retirement_(retirement) { relock(); }
    ~FairDmaGuard() { unlock(); }
    FairDmaGuard(const FairDmaGuard&) = delete;
    FairDmaGuard& operator=(const FairDmaGuard&) = delete;
    void unlock() { if (held_) { held_ = false; mutex_->unlock(); } }
    void relock() { if (!held_) { mutex_->lock(retirement_); held_ = true; } }
private:
    FairDmaMutex* mutex_;
    bool retirement_, held_ = false;
};
} // namespace tdm
