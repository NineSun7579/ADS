#include "detection_temporal_filter.h"

#include <iostream>
#include <limits>
#include <string>

namespace {
struct Detection {
    int cls = 1;
    float score = 0.9;
    float x1 = 0, y1 = 0, x2 = 10, y2 = 10;
    std::int64_t validUntilMs = 0;
    int trackId = -1;
    bool predicted = false;
    double depth = 0;
    std::int64_t depthTimestampMs = 0;
};
using Filter = tdm::TemporalDetectionFilter<Detection>;

struct Checks {
    int failures = 0;
    int count = 0;
    void check(bool condition, const char* expression, int line) {
        ++count;
        if (!condition) {
            ++failures;
            std::cerr << "temporal filter FAIL line " << line << ": " << expression << '\n';
        }
    }
};
#define CHECK(expression) checks.check((expression), #expression, __LINE__)
}

int tdm::runDetectionTemporalSelfTest() {
    Checks checks;
    Detection box;
    Filter filter;

    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({box}, 1, 50).empty());
    CHECK(filter.visible(60).empty());
    box.trackId = 77;
    box.depth = 4.25;
    box.depthTimestampMs = 42;
    auto output = filter.process({box}, 2, 100);
    CHECK(output.size() == 1);
    CHECK(output.size() == 1 && output[0].validUntilMs == 280);
    CHECK(output.size() == 1 && output[0].trackId == 77 && output[0].depth == 4.25
          && output[0].depthTimestampMs == 42);
    CHECK(filter.lastSampleStats.matchedCount == 1 && filter.lastSampleStats.promotedCount == 1);
    CHECK(filter.stats().processedFrames == 3 && filter.stats().totalInput == 3);
    CHECK(filter.process({}, 3, 150).size() == 1);
    CHECK(filter.visible(280).size() == 1);
    CHECK(filter.visible(281).empty());
    CHECK(filter.current().confirmedCount == 0 && filter.current().visibleCount == 0);

    filter.clear();
    CHECK(filter.current().trackCount == 0 && filter.stats().processedFrames == 0);
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({box}, 1, 10).empty());
    CHECK(filter.process({}, 2, 20).empty());
    CHECK(filter.current().pendingCount == 0);
    CHECK(filter.process({box}, 3, 30).empty());
    CHECK(filter.process({box}, 4, 40).empty());
    CHECK(filter.process({box}, 5, 50).size() == 1);

    filter.clear();
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({box}, 1, 50).empty());
    CHECK(filter.process({box}, 2, 100).size() == 1);
    CHECK(filter.process({}, 3, 150).size() == 1);
    CHECK(filter.visible(281).empty());
    CHECK(filter.process({box}, 4, 300).empty());
    CHECK(filter.process({}, 5, 350).empty());
    CHECK(filter.process({box}, 6, 400).empty());
    CHECK(filter.process({box}, 7, 450).empty());
    CHECK(filter.process({box}, 8, 500).size() == 1);

    filter.clear();
    CHECK(filter.process({box}, 10, 0).empty());
    CHECK(filter.process({box}, 10, 10).empty());
    CHECK(filter.process({box}, 9, 20).empty());
    CHECK(filter.lastSampleStats.ignoredFrame && filter.stats().processedFrames == 1);
    CHECK(filter.process({box}, 11, 20).empty());
    CHECK(filter.process({box}, 12, 20).size() == 1); // Distinct IDs at the same time count.
    CHECK(filter.process({box}, 12, 100).size() == 1);
    CHECK(filter.process({box}, 11, 201).empty()); // Repeats cannot refresh deadline 200.
    CHECK(filter.stats().ignoredFrames == 4 && filter.stats().promotedCount == 1);

    filter.clear();
    Detection far = box;
    far.x1 = 100; far.x2 = 110;
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({far}, 1, 10).empty());
    CHECK(filter.process({box}, 2, 20).empty());
    CHECK(filter.process({far}, 3, 30).empty());
    Detection otherClass = box;
    otherClass.cls = 2;
    CHECK(filter.process({otherClass}, 4, 40).empty());
    CHECK(filter.process({box}, 5, 50).empty());
    CHECK(filter.current().pendingCount == 1);

    // Exactly 0.25 IoU qualifies; slightly less must break the old streak.
    filter.clear();
    Detection threshold = box;
    threshold.x1 = 6; threshold.x2 = 16;
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({threshold}, 1, 10).empty());
    CHECK(filter.lastSampleStats.matchedCount == 1);
    CHECK(filter.process({threshold}, 2, 20).size() == 1);
    filter.clear();
    threshold.x1 = 6.01; threshold.x2 = 16.01;
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({threshold}, 1, 10).empty());
    CHECK(filter.lastSampleStats.matchedCount == 0);
    CHECK(filter.process({threshold}, 2, 20).empty());

    filter.clear();
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({box}, 1, 10).empty());
    CHECK(filter.process({}, 1, 20).empty());
    CHECK(filter.process({box}, 2, 30).size() == 1);
    output = filter.process({far}, 1, 40);
    CHECK(output.size() == 1 && output[0].x1 == box.x1 && output[0].validUntilMs == 210);

    filter.clear();
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({box, box, box}, 1, 10).empty());
    CHECK(filter.lastSampleStats.matchedCount == 1 && filter.lastSampleStats.promotedCount == 0);
    CHECK(filter.process({box}, 2, 20).size() == 1);
    CHECK(filter.lastSampleStats.promotedCount == 1 && filter.current().trackCount == 1);

    // Global descending IoU must beat input-order association. The ambiguous
    // first box also overlaps A, but its strongest match is B; the next is A.
    Filter::Config instant;
    instant.confirmationFrames = 1;
    Filter greedy(instant);
    Detection a = box, b = box, ambiguous = box, exactA = box;
    b.x1 = 6; b.x2 = 16;
    ambiguous.x1 = 4; ambiguous.x2 = 14;
    ambiguous.trackId = 22;
    exactA.trackId = 11;
    CHECK(greedy.process({a, b}, 0, 0).size() == 2);
    output = greedy.process({ambiguous, exactA}, 1, 10);
    CHECK(output.size() == 2 && output[0].trackId == 11 && output[1].trackId == 22);
    CHECK(greedy.lastSampleStats.matchedCount == 2);

    filter.clear();
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.visible(200).empty());
    CHECK(filter.process({box}, 1, 250).empty());
    CHECK(filter.process({box}, 2, 500).size() == 1);
    CHECK(filter.visible(681).empty());
    CHECK(filter.process({box}, 3, 750).size() == 1);
    CHECK(filter.stats().promotedCount == 1); // 4 fps history survives output expiry.
    CHECK(filter.process({}, 4, 800).size() == 1);
    CHECK(filter.visible(930).size() == 1);
    CHECK(filter.visible(931).empty());
    CHECK(filter.process({box}, 5, 1351).empty()); // More than 600 ms needs reconfirmation.
    CHECK(filter.current().pendingCount == 1);

    filter.clear();
    CHECK(filter.process({box}, 0, 0).empty());
    CHECK(filter.process({box}, 1, 601).empty());
    CHECK(filter.process({box}, 2, 602).empty());
    CHECK(filter.process({box}, 3, 603).size() == 1);

    Filter deadlines(instant);
    Detection limited = box;
    limited.validUntilMs = 125;
    output = deadlines.process({limited}, 0, 100);
    CHECK(output.size() == 1 && output[0].validUntilMs == 125);
    CHECK(deadlines.visible(125).size() == 1);
    CHECK(deadlines.process({limited}, 1, 126).empty());
    CHECK(deadlines.lastSampleStats.rejectedCount == 1);
    limited.validUntilMs = 1000;
    output = deadlines.process({limited}, 2, 200);
    CHECK(output.size() == 1 && output[0].validUntilMs == 380);

    Filter invalid;
    Detection nan = box, inverted = box, negative = box, predicted = box, expired = box;
    nan.x1 = std::numeric_limits<double>::quiet_NaN();
    inverted.x2 = -1;
    negative.cls = -1;
    predicted.predicted = true;
    expired.validUntilMs = 1;
    CHECK(invalid.process({nan, inverted, negative, predicted, expired}, 0, 2).empty());
    CHECK(invalid.lastSampleStats.rejectedCount == 5 && invalid.current().trackCount == 0);
    nan = box; nan.score = std::numeric_limits<double>::infinity();
    CHECK(invalid.process({nan}, 1, 3).empty());
    CHECK(invalid.lastSampleStats.rejectedCount == 1);
    CHECK(invalid.process({box}, 2, 10).empty());
    CHECK(invalid.process({box}, 3, 20).empty());
    CHECK(invalid.process({predicted}, 4, 30).empty());
    CHECK(invalid.current().trackCount == 0); // Prediction cannot complete a streak.

    Filter bounded(instant);
    std::vector<Detection> many;
    for (int i = 0; i < 350; ++i) {
        Detection d = box;
        d.x1 = i * 20; d.x2 = d.x1 + 10;
        d.score = i / 350.0; d.trackId = i;
        many.push_back(d);
    }
    output = bounded.process(many, 0, 0);
    CHECK(output.size() == 300 && bounded.current().trackCount == 300);
    CHECK(bounded.lastSampleStats.capacityDropped == 50);
    CHECK(std::all_of(output.begin(), output.end(), [](const Detection& d) { return d.trackId >= 50; }));
    for (auto& d : many) { d.x1 += 10000; d.x2 += 10000; }
    CHECK(bounded.process(many, 1, 10).size() == 600);
    for (auto& d : many) { d.x1 += 10000; d.x2 += 10000; }
    CHECK(bounded.process(many, 2, 20).size() == 600);
    CHECK(bounded.current().trackCount == 600 && bounded.lastSampleStats.capacityDropped == 350);

    Filter::Config smallConfig = instant;
    smallConfig.maximumTracks = 2;
    Filter small(smallConfig);
    CHECK(small.process(many, 0, 0).size() == 2);
    CHECK(small.current().trackCount == 2);

    filter.clear();
    CHECK(filter.process({box}, 10, 100).empty());
    CHECK(filter.process({box}, 11, 110).empty());
    CHECK(filter.process({box}, 12, 120).size() == 1);
    CHECK(filter.visible(119).empty()); // Timer clock rollback clears state too.
    CHECK(filter.current().trackCount == 0);
    CHECK(filter.process({box}, 0, 120).empty());
    CHECK(filter.process({box}, 1, 121).empty());
    CHECK(filter.process({box}, 0, 100).empty()); // Rollback allows a new frame sequence.
    CHECK(filter.current().pendingCount == 1 && filter.stats().processedFrames == 1);

    Filter overflow(instant);
    const auto maximumTime = std::numeric_limits<std::int64_t>::max();
    output = overflow.process({box}, 0, maximumTime - 10);
    CHECK(output.size() == 1 && output[0].validUntilMs == maximumTime);
    CHECK(overflow.visible(maximumTime).size() == 1);

    // Instantiation without optional tracker fields must also compile and work.
    struct Plain {
        int cls; float score, x1, y1, x2, y2; long long validUntilMs;
    };
    tdm::TemporalDetectionFilter<Plain> plain;
    Plain p{0, 1, 0, 0, 10, 10, 0};
    CHECK(plain.process({p}, 0, 0).empty());
    CHECK(plain.process({p}, 1, 1).empty());
    CHECK(plain.process({p}, 2, 2).size() == 1);

    std::cout << "temporal filter self-test: " << checks.count << " checks, "
              << checks.failures << " failures\n";
    return checks.failures == 0 ? 0 : 1;
}

#ifdef TDM_TEMPORAL_SELFTEST_MAIN
int main() { return tdm::runDetectionTemporalSelfTest(); }
#endif
