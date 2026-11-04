#pragma once
#include <atomic>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <cstdint>
#include <exception>
#include <vector>
#include <string>
#include <optional>
#include "prefetch_config.h"

namespace scheme2 {
constexpr uint32_t Window = 0x800000, Offset = 0x400000;
constexpr uint32_t SquareBytes = 640 * 640 * 3, RawBytes = 640 * 480 * 2;
inline bool enabled() {
    static const bool value = [] { const char* p = std::getenv("DETVIEW_FPGA_INFER_RGB");
        return p && std::strcmp(p, "1") == 0; }();
    return value;
}
inline uint32_t bytes(int height) { return height == 480 ? 921600 : SquareBytes; }
inline uint32_t crop(int height) { return height == 480 ? 153600 : 0; }

// One request from the analytics cadence; one physical shared slot. The gate
// survives GUI queues, source changes and model reloads without frame relabeling.
struct Selection {
    int height = 0;
    std::string model;
    uint64_t revision = 0;
    explicit operator bool() const { return height == 480 || height == 640; }
};
class Admission {
    std::mutex mutex;
    bool armed = false, occupied = false;
    unsigned fencedMask = 0;
    int occupiedCamera = -1;
    int camera = -1, generation = -1;
    Selection next, selected;
    int64_t armedMs = -1;
public:
    void publish(Selection value) {
        std::lock_guard<std::mutex> lock(mutex);
        if (value.revision < next.revision) return;
        next = std::move(value); armed = false;
    }
    bool available() { std::lock_guard<std::mutex> lock(mutex); return bool(next); }
    bool idle() { std::lock_guard<std::mutex> lock(mutex); return !occupied; }
    // Fence acquisition and claims under the SAME mutex. An unrelated front
    // lease neither blocks pair drain nor loses its selection/retirement.
    void fence(unsigned mask) {
        std::lock_guard<std::mutex> lock(mutex);
        fencedMask |= mask;
        if (camera >= 0 && (mask & (1u << unsigned(camera)))) armed = false;
    }
    void unfence(unsigned mask) { std::lock_guard<std::mutex> lock(mutex); fencedMask &= ~mask; }
    bool idle(unsigned mask) {
        std::lock_guard<std::mutex> lock(mutex);
        return !occupied || occupiedCamera < 0 || !(mask & (1u << unsigned(occupiedCamera)));
    }
    bool accepts(const Selection& value) {
        std::lock_guard<std::mutex> lock(mutex);
        return bool(next) && value.revision == next.revision;
    }
    void arm(int c, int g, int64_t timestamp = -1) {
        std::lock_guard<std::mutex> lock(mutex);
        if (c < 0 || c >= 6 || (fencedMask & (1u << unsigned(c))) || occupied || !next) return;
        if (!armed || c != camera || g != generation) armedMs = timestamp;
        armed = true; camera = c; generation = g; selected = next;
    }
    Selection claim(int c, int g, PrefetchTiming* timing = nullptr) {
        std::lock_guard<std::mutex> lock(mutex);
        if (c < 0 || c >= 6 || (fencedMask & (1u << unsigned(c))) || !armed || occupied || c != camera || g != generation) return {};
        if (timing) timing->arm = armedMs;
        armed = false; occupied = true; occupiedCamera = c; return selected;
    }
    void retire(std::optional<Selection> value = {}) {
        std::lock_guard<std::mutex> lock(mutex);
        // A reload published a new revision while this old input was queued.
        // Its cancellation must not restore stale rotation metadata.
        if (value && value->revision == next.revision) next = std::move(*value);
        occupied = false;
        occupiedCamera = -1;
    }
    void disarm() { std::lock_guard<std::mutex> lock(mutex); armed = false; }
};
inline Admission& admission() { static Admission value; return value; }

struct Input {
    // Capture writes before publication; controller writes request before emit.
    PrefetchTiming timing;
    int fd = -1, height = 0, camera = -1, sourceGeneration = 0;
    uint32_t tag = 0, epoch = 0, source = 0;
    Selection selection;
    std::optional<Selection> nextSelection;
    void* base = nullptr; // full RX mapping, never base+Offset
    std::shared_ptr<void> backing; // fd and mmap outlive every context import
    std::atomic<bool> dispatched{false};
    std::mutex mutex;
    bool retired = false;
    bool consumerStarted = false;
    std::function<void()> end;
    std::function<void()> begin;
    std::function<void()> uncertain;
    std::vector<uint8_t> goldenRgb;
    bool begun = false;
    void consume() { std::lock_guard<std::mutex> lock(mutex); if (retired || begun) std::terminate(); begin(); begun = true; }
    void start() { std::lock_guard<std::mutex> lock(mutex); consumerStarted = true; }
    void complete() {
        std::lock_guard<std::mutex> lock(mutex);
        if (retired) return;
        if (begun) end();
        retired = true; admission().retire(nextSelection);
    }
    ~Input() {
        // Stack unwinding must never assert that an uncertain consumer retired.
        if (consumerStarted && !retired) {
            if (uncertain) uncertain();
            std::terminate();
        }
        complete(); // unsubmitted/cancelled input can safely END
    }
};
}
