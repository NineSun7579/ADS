#ifndef TDM_FRAME_METRICS_H
#define TDM_FRAME_METRICS_H

#include <cstdint>
#include <deque>

namespace tdm {

// A one-second sliding event-count window, using monotonic milliseconds supplied
// by the caller (e.g. steady_clock, never frame duration or wall-clock time).
// Events at exactly nowMs - 1000 are excluded; events at nowMs are included.
// FPS = events in the last 1000ms / one second. At zero elapsed time FPS is zero.
// Startup/resume uses the same full denominator, so the first few milliseconds
// cannot inflate a single frame into hundreds of FPS. Rates fill in over a second.
// Idle does not restart warm-up. Call reset when starting/resuming a measurement.
//
// Negative timestamps and timestamps before the last accepted observation are
// ignored, including reset. An invalid rate query returns zero without changing
// state. Equal timestamps are valid. Before initialization, rate returns zero;
// the first valid add (including count == 0) implicitly resets the time base.
// count == 0 only advances time/expiry. All valid methods age the window.
//
// Counts are events or sequence advances, not sequence IDs. To measure composite
// display FPS, add once per composite update with any fresh camera; summing the
// per-camera counters measures different work. This class does not deduplicate
// camera/frame identities. Use separate instances for separate measurements,
// with external synchronization if an instance is shared across threads.
class FrameRate {
public:
    void reset(std::int64_t nowMs) {
        if (!accepts(nowMs)) return;
        events_.clear();
        startMs_ = lastMs_ = nowMs;
        initialized_ = true;
    }

    void add(std::int64_t nowMs, std::uint64_t count = 1) {
        if (!accepts(nowMs)) return;
        if (!initialized_) reset(nowMs);
        age(nowMs);
        if (count == 0) return;
        if (!events_.empty() && events_.back().timestampMs == nowMs) {
            events_.back().count += static_cast<long double>(count);
        } else {
            events_.push_back({nowMs, static_cast<long double>(count)});
        }
    }

    double rate(std::int64_t nowMs) {
        if (!initialized_ || !accepts(nowMs)) return 0.0;
        age(nowMs);
        const std::int64_t elapsedMs = nowMs - startMs_;
        if (elapsedMs == 0) return 0.0;
        // Re-sum at most 1000 buckets. This avoids integer count overflow and
        // subtractive cancellation when a large weighted batch expires.
        long double count = 0.0L;
        for (const auto& event : events_) count += event.count;
        return static_cast<double>(count);
    }

private:
    struct Event {
        std::int64_t timestampMs;
        long double count;
    };

    bool accepts(std::int64_t nowMs) const {
        return nowMs >= 0 && (!initialized_ || nowMs >= lastMs_);
    }

    void age(std::int64_t nowMs) {
        lastMs_ = nowMs;
        while (!events_.empty() && nowMs - events_.front().timestampMs >= 1000) {
            events_.pop_front();
        }
        // Integer-millisecond timestamps plus same-ms merging bound storage
        // to 1000 buckets, independently of event count and runtime.
    }

    bool initialized_ = false;
    std::int64_t startMs_ = 0;
    std::int64_t lastMs_ = 0;
    std::deque<Event> events_;
};

} // namespace tdm

int runFrameMetricsSelfTest();

#endif // TDM_FRAME_METRICS_H
