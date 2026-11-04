#include "frame_metrics.h"
#include "display_perf.h"

#include <cmath>
#include <iostream>
#include <limits>

// Host-only build:
// g++ -std=c++17 -Wall -Wextra -pedantic -DTDM_FRAME_METRICS_SELFTEST_MAIN frame_metrics_selftest.cpp -o frame_metrics_selftest
namespace {
struct Checks {
    int failures = 0;
    int total = 0;

    void check(bool condition, const char* name) {
        ++total;
        if (!condition) {
            ++failures;
            std::cerr << "FRAME_METRICS_SELFTEST_FAIL: " << name << '\n';
        }
    }

    void near(double actual, double expected, const char* name) {
        const bool equal = std::isfinite(actual) &&
            std::abs(actual - expected) <= 1e-10 * (1.0 + std::abs(expected));
        check(equal, name);
        if (!equal) std::cerr << "  got " << actual << ", expected " << expected << '\n';
    }
};
} // namespace

int runFrameMetricsSelfTest() {
    Checks c;
    {
        tdm::TimingDistribution sample;
        sample.add(-1); sample.add(std::numeric_limits<double>::quiet_NaN());
        c.check(sample.count == 0, "timing ignores invalid samples");
        for (int i = 0; i < 100; ++i) sample.add(i);
        c.near(sample.mean(), 49.5, "timing exact sum");
        c.near(sample.percentile(.5), 49.5, "timing p50 bucket upper bound");
        c.near(sample.percentile(.95), 94.5, "timing p95 bucket upper bound");
        c.near(sample.percentile(.99), 98.5, "timing p99 bucket upper bound");
        sample.add(300);
        c.check(sample.overflow == 1 && sample.maxMs == 300, "timing overflow preserved");
        c.near(sample.percentile(1), 300, "overflow quantile uses conservative maximum");
        sample = {};
        c.check(sample.count == 0 && sample.percentile(.99) == 0, "timing window reset");
    }
    {
        tdm::FrameRate fps;
        c.near(fps.rate(0), 0, "uninitialized query");
        fps.add(5000);
        c.near(fps.rate(5000), 0, "first add has zero observation time");
        c.near(fps.rate(5001), 1, "first millisecond cannot inflate one event to 1000 FPS");
        c.near(fps.rate(5100), 1, "first event counted during warm-up");
        c.near(fps.rate(5999), 1, "first event inside window");
        c.near(fps.rate(6000), 0, "first event expires at exactly one second");
    }
    {
        tdm::FrameRate fps;
        fps.reset(10000);
        for (int i = 1; i <= 100; ++i) {
            fps.add(10000 + i * 40);
            if (i % 5 == 0) c.near(fps.rate(10000 + i * 40), i < 25 ? i : 25, "25 Hz across windows");
        }
        c.near(fps.rate(14000), 25, "25 Hz exact one-second count");
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        int nextEvent = 33;
        // GUI reads every 100ms, independent of 33ms frame delivery.
        for (int now = 100; now <= 6000; now += 100) {
            while (nextEvent <= now) {
                fps.add(nextEvent);
                nextEvent += 33;
            }
            const double measured = fps.rate(now);
            if (now >= 1000) c.check(std::abs(measured - 1000.0 / 33) < 1.0,
                                    "33ms stream remains about 30 FPS at GUI cadence");
        }
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        for (int i = 0; i < 30; ++i) fps.add(1000);
        c.near(fps.rate(1000), 30, "same-ms burst uses full elapsed window");
        c.near(fps.rate(1001), 30, "burst is not reciprocal inter-event time");
        c.near(fps.rate(1999), 30, "burst retained before expiry");
        c.near(fps.rate(2000), 0, "burst expires at left boundary");

        tdm::FrameRate initialBurst;
        initialBurst.add(5000, 30);
        c.near(initialBurst.rate(5000), 0, "implicit burst does not divide by zero time");
        c.near(initialBurst.rate(5001), 30, "startup burst uses full-second denominator");
        c.near(initialBurst.rate(5500), 30, "startup does not amplify a burst");
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        for (int now = 40; now <= 1000; now += 40) fps.add(now);
        c.near(fps.rate(1000), 25, "active before interruption");
        c.near(fps.rate(2000), 0, "GUI query alone ages stopped stream to zero");
        fps.add(10000);
        c.near(fps.rate(10000), 1, "idle restart retains mature denominator");
        fps.add(12000);
        c.near(fps.rate(12000), 1, "idle expiry also occurs on add without queries");
        fps.add(13000, 0);
        c.near(fps.rate(13000), 0, "zero count ages without adding event");
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        fps.add(1000, 25);
        c.near(fps.rate(1000), 25, "rate before pause");
        fps.reset(1000);
        c.near(fps.rate(1000), 0, "reset at same time discards old count");
        fps.reset(5000);
        c.near(fps.rate(5100), 0, "resume does not reuse old FPS");
        fps.add(5200, 5);
        c.near(fps.rate(5200), 5, "reset starts a fresh full-second window");
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        std::uint64_t lastSequence = 100;
        for (std::uint64_t sequence : {103ULL, 110ULL}) {
            fps.add(1000, sequence - lastSequence);
            lastSequence = sequence;
        }
        fps.add(1000, 0);
        c.near(fps.rate(1000), 10, "weighted sequence advance counts delta, not ID");
        fps.add(1500, 2);
        c.near(fps.rate(1999), 12, "weighted batches coexist in sliding window");
        c.near(fps.rate(2000), 2, "weighted batch expires independently");
    }
    {
        tdm::FrameRate fps;
        fps.add(-1, 100);
        fps.reset(-1);
        c.near(fps.rate(-1), 0, "negative inputs rejected before initialization");
        fps.reset(1000);
        fps.add(1100, 2);
        fps.add(1099, 100);
        fps.add(-5, 100);
        fps.reset(1099);
        fps.reset(-5);
        c.near(fps.rate(1099), 0, "backward query rejected");
        c.near(fps.rate(-5), 0, "negative query rejected");
        c.near(fps.rate(1200), 2, "invalid calls preserve accepted history");
        fps.add(1199, 100);
        fps.reset(1199);
        c.near(fps.rate(1200), 2, "query advances monotonic validation watermark");
        fps.add(1200, 2);
        c.near(fps.rate(1200), 4, "equal timestamp accepted after query");
        fps.add(1300, 0);
        fps.add(1299, 100);
        c.near(fps.rate(1400), 4, "age-only call also rejects later backward add");
    }
    {
        tdm::FrameRate fps;
        fps.add(5000, 0);
        fps.add(5100, 2);
        c.near(fps.rate(5200), 2, "first zero-count add establishes observation base");
        fps.add(6100, 0);
        c.near(fps.rate(6100), 0, "age-only exact boundary");
    }
    {
        tdm::FrameRate left, right, composite;
        left.reset(0);
        right.reset(0);
        composite.reset(0);
        // Both panes change in the same GUI update: one composite, two captures.
        for (int now = 40; now <= 1000; now += 40) {
            left.add(now);
            right.add(now);
            const bool anyFreshCamera = true;
            if (anyFreshCamera) composite.add(now);
        }
        c.near(left.rate(1000), 25, "left camera capture FPS");
        c.near(right.rate(1000), 25, "right camera capture FPS");
        c.near(composite.rate(1000), 25, "union updates counted once per composite");
        c.check(composite.rate(1000) != left.rate(1000) + right.rate(1000),
                "composite FPS must not sum per-camera labels");
    }
    {
        tdm::FrameRate fast, slow, composite;
        fast.reset(0);
        slow.reset(0);
        composite.reset(0);
        for (int now = 20; now <= 1000; now += 20) {
            const bool fastFresh = now % 40 == 0;
            const bool slowFresh = now % 100 == 0;
            if (fastFresh) fast.add(now);
            if (slowFresh) slow.add(now);
            if (fastFresh || slowFresh) composite.add(now);
        }
        c.near(fast.rate(1000), 25, "different-camera fast rate");
        c.near(slow.rate(1000), 10, "different-camera slow rate");
        c.near(composite.rate(1000), 30, "union removes five overlapping camera updates");
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        // Many same-ms events plus all millisecond buckets exercise merging and
        // ongoing eviction. Full windows always contain exactly 2000 events.
        for (int now = 0; now <= 10000; ++now) {
            fps.add(now);
            fps.add(now);
            if (now >= 1000 && now % 100 == 0)
                c.near(fps.rate(now), 2000, "dense long stream retains only current window");
        }
        c.near(fps.rate(11000), 0, "dense stream fully expires");
    }
    {
        tdm::FrameRate fps;
        fps.reset(0);
        const auto maxCount = std::numeric_limits<std::uint64_t>::max();
        fps.add(1000, maxCount);
        fps.add(1000, maxCount);
        c.near(fps.rate(1000), static_cast<double>(maxCount) * 2,
               "same-ms weighted merge does not wrap uint64");
        fps.add(1999, 1);
        c.near(fps.rate(2000), 1, "huge expired count does not cancel surviving small count");

        tdm::FrameRate late;
        const auto maxTime = std::numeric_limits<std::int64_t>::max();
        late.reset(maxTime - 1000);
        late.add(maxTime, 25);
        c.near(late.rate(maxTime), 25, "large nonnegative monotonic timestamps");
    }

    if (c.failures != 0) return 1;
    std::cout << "FRAME_METRICS_SELFTEST_PASS (" << c.total << " checks)\n";
    return 0;
}

#ifdef TDM_FRAME_METRICS_SELFTEST_MAIN
int main() {
    return runFrameMetricsSelfTest();
}
#endif
