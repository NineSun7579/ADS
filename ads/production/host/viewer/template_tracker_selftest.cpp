#include "template_tracker.h"

#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cmath>
#include <chrono>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>

// Host example (OpenCV 4, C++17):
// c++ -std=c++17 -O2 -DTDM_TRACKER_SELFTEST_MAIN template_tracker.cpp
//     template_tracker_selftest.cpp $(pkg-config --cflags --libs opencv4) -o tracker_selftest
// (Join the two command lines above.)
// This validates behavior only. CPU cost on RK3568 needs measurement with real
// frames, track counts and concurrent workloads; no sub-0.2ms claim is made.

namespace tdm {
namespace {

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

template <typename Action>
void invalid(Action action, const std::string& message) {
    bool threw = false;
    try { action(); } catch (const std::invalid_argument&) { threw = true; }
    require(threw, message);
}

cv::Mat texture(uint64_t seed, cv::Size size = {80, 64}) {
    cv::RNG rng(seed);
    cv::Mat coarse(size.height / 2, size.width / 2, CV_8UC1);
    rng.fill(coarse, cv::RNG::UNIFORM, 65, 170);
    cv::Mat result;
    cv::resize(coarse, result, size, 0, 0, cv::INTER_NEAREST);
    return result;
}

cv::Mat frame(const cv::Mat& patch, cv::Point position, int brightness = 0,
              cv::Size size = {640, 480}) {
    cv::Mat image(size, CV_8UC1, cv::Scalar(30));
    cv::Mat lit;
    patch.convertTo(lit, CV_8UC1, 1, brightness);
    lit.copyTo(image(cv::Rect(position, patch.size())));
    return image;
}

ObjectDetection detection(cv::Point position, cv::Size size = {80, 64},
                          int cls = 1, float score = 0.9f) {
    return {cls, score, cv::Rect2f(cv::Rect(position, size))};
}

void near(const Track& track, cv::Point position, const std::string& message) {
    require(std::abs(track.box.x - position.x) <= 2 &&
            std::abs(track.box.y - position.y) <= 2 && !track.predicted &&
            track.weakFrames == 0 && track.matchScore >= 0.65f,
            message + " (x=" + std::to_string(track.box.x) +
            ", y=" + std::to_string(track.box.y) + ", NCC=" +
            std::to_string(track.matchScore) + ", weak=" +
            std::to_string(track.weakFrames) + ")");
    require(track.box.x >= 0 && track.box.y >= 0 &&
            track.box.x + track.box.width <= 640.01f &&
            track.box.y + track.box.height <= 480.01f, "box escaped image");
}

void movementAndLight() {
    const cv::Mat patch = texture(17);
    TemplateTracker tracker;
    require(tracker.needsDetection(0), "fresh tracker must request detection");
    tracker.correct(frame(patch, {100, 100}), {detection({100, 100})}, 0);
    const uint64_t id = tracker.tracks(0).at(0).id;
    require(!tracker.needsDetection(0), "correction should satisfy refresh");
    for (int n = 1; n <= 12; ++n) {
        const cv::Point p(100 + n * 4, 100 + n * 2);
        const auto tracks = tracker.update(frame(patch, p, n * 2), n * 33);
        require(tracks.size() == 1 && tracks[0].id == id, "moving track lost its ID");
        near(tracks[0], p, "moving/illuminated template did not actually match");
        require(tracks[0].detectionScore == 0.9f, "NCC changed detection confidence");
    }
    require(tracker.needsDetection(500), "strong matches indefinitely postponed detection");
    std::cout << "  moving texture, light changes, periodic refresh: PASS\n";
}

void scaleSearch() {
    const cv::Mat patch = texture(32);
    TemplateTracker tracker;
    tracker.correct(frame(patch, {200, 100}), {detection({200, 100})}, 0);
    cv::Mat larger;
    cv::resize(patch, larger, {84, 68}, 0, 0, cv::INTER_LINEAR);
    const auto found = tracker.update(frame(larger, {202, 100}), 33);
    require(found.size() == 1, "scale search lost target");
    near(found[0], {202, 100}, "scale search missed location");
    require(std::abs(found[0].box.width - 84) <= 2 &&
            std::abs(found[0].box.height - 68) <= 2, "three-scale search missed size change");
    std::cout << "  three-scale template search: PASS\n";
}

void rejectFlatAndAmbiguous() {
    TrackerOptions options;
    options.minimumTextureStdDev = 0; // Mandatory constant-template floor remains.
    TemplateTracker flat(options);
    const cv::Mat constant(480, 640, CV_8UC1, cv::Scalar(100));
    flat.correct(constant, {detection({100, 100})}, 0);
    require(flat.tracks(0).empty() && flat.needsDetection(0), "constant template accepted");
    const cv::Mat patch = texture(42, {24, 24});
    TemplateTracker ambiguous;
    const auto det = detection({100, 100}, patch.size());
    ambiguous.correct(frame(patch, {100, 100}), {det}, 0);
    cv::Mat twins = frame(patch, {100, 100});
    patch.copyTo(twins(cv::Rect(124, 100, 24, 24)));
    const auto tracks = ambiguous.update(twins, 33);
    require(tracks.size() == 1 && tracks[0].predicted && tracks[0].weakFrames == 1,
            "equal distant NCC peaks accepted as a unique target");
    require(ambiguous.needsDetection(33), "ambiguous match did not request correction");
    std::cout << "  constant-template and duplicate-peak rejection: PASS\n";
}

void occlusionAndTTL() {
    const cv::Mat patch = texture(64);
    TemplateTracker tracker;
    tracker.correct(frame(patch, {100, 100}), {detection({100, 100})}, 0);
    near(tracker.update(frame(patch, {108, 100}), 33).at(0), {108, 100}, "initial motion failed");
    const cv::Mat blank(480, 640, CV_8UC1, cv::Scalar(30));
    for (int n = 1; n <= 3; ++n) {
        const auto weak = tracker.update(blank, 33 + n * 33);
        require(weak.size() == 1 && weak[0].predicted && weak[0].weakFrames == n,
                "weak-frame budget incorrect");
        require(weak[0].box.x > 108, "weak frame did not use measured velocity");
        require(tracker.needsDetection(33 + n * 33), "weak track did not request detection");
        const auto same = tracker.update(blank, 33 + n * 33);
        require(same.at(0).weakFrames == n, "same-time update consumed weak budget twice");
    }
    require(tracker.update(blank, 165).empty(), "occluded track exceeded weak budget");
    TrackerOptions immediate;
    immediate.maxWeakFrames = 0;
    TemplateTracker noPrediction(immediate);
    noPrediction.correct(frame(patch, {100, 100}), {detection({100, 100})}, 0);
    require(noPrediction.update(blank, 33).empty(), "zero prediction budget ignored");

    TemplateTracker ttl;
    ttl.correct(frame(patch, {100, 100}), {detection({100, 100})}, 100);
    for (int t = 133; t <= 2080; t += 33)
        near(ttl.update(frame(patch, {100, 100}), t).at(0), {100, 100}, "stable TTL match failed");
    require(ttl.tracks(2100).size() == 1, "TTL boundary expired too early");
    require(ttl.tracks(2100).at(0).validUntilMs == 2100,
            "render deadline must come from NPU confirmation, not latest match");
    require(ttl.tracks(2101).empty() && ttl.needsDetection(2101), "const TTL filtering failed");
    require(ttl.update(frame(patch, {100, 100}), 2101).empty(), "matching extended detection TTL");
    std::cout << "  predicted-frame limit, occlusion loss, immutable detection TTL: PASS\n";
}

void associationAndCorrection() {
    const cv::Mat a = texture(71), b = texture(72);
    cv::Mat image = frame(a, {100, 100});
    b.copyTo(image(cv::Rect(300, 100, 80, 64)));
    TemplateTracker tracker;
    tracker.correct(image, {detection({100, 100}), detection({300, 100})}, 0);
    const auto initial = tracker.tracks(0);
    require(initial.size() == 2 && initial[0].id != initial[1].id, "same-class IDs not unique");
    const uint64_t left = initial[0].id, right = initial[1].id;
    cv::Mat moved = frame(a, {104, 102});
    b.copyTo(moved(cv::Rect(296, 102, 80, 64)));
    const auto match = tracker.update(moved, 33);
    require(match.size() == 2, "multi-object actual matching failed");
    near(match[0], {104, 102}, "first same-class target mismatched");
    near(match[1], {296, 102}, "second same-class target mismatched");
    // Reverse detector order; adjust geometry and replace the object's pixels.
    const cv::Mat changed = texture(73);
    cv::Mat corrected = frame(changed, {110, 104});
    b.copyTo(corrected(cv::Rect(292, 104, 80, 64)));
    tracker.correct(corrected, {detection({292, 104}), detection({110, 104})}, 66);
    const auto associated = tracker.tracks(66);
    require(associated.at(0).id == right && associated.at(1).id == left,
            "reordered same-class IoU association changed IDs");
    require(associated[1].box.x == 110 && associated[1].matchScore == 0,
            "correction did not replace geometry/reset NCC score");
    cv::Mat next = frame(changed, {114, 104});
    b.copyTo(next(cv::Rect(288, 104, 80, 64)));
    const auto tracked = tracker.update(next, 99);
    near(tracked.at(1), {114, 104}, "correction did not replace appearance template");

    TemplateTracker oneToOne;
    oneToOne.correct(image, {detection({100, 100})}, 0);
    const uint64_t oldId = oneToOne.tracks(0).at(0).id;
    oneToOne.correct(image, {detection({100, 100}), detection({102, 100})}, 0);
    const auto duplicates = oneToOne.tracks(0);
    require(duplicates.size() == 2 && duplicates[0].id == oldId && duplicates[1].id != oldId,
            "one old ID was associated with two detections");
    oneToOne.correct(image, {detection({100, 100}, {80, 64}, 2)}, 33);
    require(oneToOne.tracks(33).at(0).id != oldId, "different class inherited old ID");
    oneToOne.correct(image, {}, 66);
    require(oneToOne.tracks(66).empty(), "authoritative empty result retained old tracks");
    std::cout << "  same-class one-to-one association, correction, model-local replacement: PASS\n";
}

void copiesReplayAndTime() {
    const cv::Mat patch = texture(91);
    const cv::Mat source = frame(patch, {100, 100});
    TemplateTracker tracker;
    tracker.correct(source, {detection({100, 100})}, 100);
    TemplateTracker snapshot(tracker);
    TemplateTracker assigned;
    assigned = tracker;
    const uint64_t sourceId = snapshot.tracks(100).at(0).id;
    for (int n = 1; n <= 6; ++n)
        tracker.update(frame(patch, {100 + n * 4, 100}, n * 4), 100 + n * 33);
    require(snapshot.tracks(100).at(0).box.x == 100, "copy was mutated with live state");
    require(assigned.tracks(100).at(0).box.x == 100, "assignment was mutated with live state");
    const auto before = tracker.tracks(298);
    invalid([&] { tracker.correct(source, {detection({100, 100})}, 100); },
            "delayed detection applied directly to latest frame");
    invalid([&] { tracker.update(source, 100); }, "backward update accepted");
    require(tracker.tracks(298).at(0).box == before.at(0).box,
            "rejected time mutated tracker state");
    // Restore source snapshot, correct at EXACT source time, replay history.
    tracker = snapshot;
    tracker.correct(source, {detection({100, 100})}, 100);
    for (int n = 1; n <= 6; ++n)
        near(tracker.update(frame(patch, {100 + n * 4, 100}, n * 4), 100 + n * 33).at(0),
             {100 + n * 4, 100}, "source-snapshot replay failed");
    require(tracker.tracks(298).at(0).id == sourceId, "source replay lost existing ID");
    require(tracker.tracks(298).at(0).box == before.at(0).box,
            "snapshot/replay did not reproduce live matching");
    assigned = assigned; // Self-assignment preserves snapshot.
    near(assigned.update(frame(patch, {104, 100}), 133).at(0), {104, 100},
         "assigned template no longer matches original source");
    // Two branches allocate new IDs independently, despite the shared past.
    TemplateTracker branch = snapshot;
    snapshot.correct(source, {detection({100, 100}, {80, 64}, 3)}, 100);
    branch.correct(source, {detection({100, 100}, {80, 64}, 3)}, 100);
    require(snapshot.tracks(100).at(0).id != branch.tracks(100).at(0).id,
            "replay branches reused globally allocated IDs");
    const uint64_t previous = branch.tracks(100).at(0).id;
    branch.clear();
    branch.correct(source, {detection({100, 100})}, 0);
    require(branch.tracks(0).at(0).id > previous, "clear reused an allocated ID");
    std::cout << "  deep-copy isolation, source replay, time guards, global ID uniqueness: PASS\n";
}

void boundsAndValidation() {
    const cv::Mat patch = texture(113);
    TemplateTracker tracker;
    tracker.correct(frame(patch, {556, 412}), {detection({556, 412})}, 0);
    near(tracker.update(frame(patch, {560, 416}), 33).at(0), {560, 416}, "edge matching failed");
    const uint64_t oldId = tracker.tracks(33).at(0).id;
    const cv::Mat small = frame(patch, {100, 100}, 0, {320, 240});
    require(tracker.update(small, 66).empty() && tracker.needsDetection(66),
            "image size change retained old source state");
    tracker.correct(small, {detection({100, 100})}, 66);
    require(tracker.tracks(66).at(0).id != oldId, "image size change reused ID");
    invalid([&] { tracker.update(cv::Mat(), 99); }, "empty input accepted");
    invalid([&] { tracker.correct(cv::Mat(240, 320, CV_8UC3), {}, 99); },
            "color input accepted");
    invalid([&] { tracker.tracks(65); }, "old-time tracks query accepted");
    invalid([&] { tracker.needsDetection(-1); }, "negative time accepted");
    TrackerOptions bad;
    bad.scale = std::numeric_limits<double>::quiet_NaN();
    invalid([&] { TemplateTracker rejected(bad); }, "NaN options accepted");
    bad = {};
    bad.maxTracks = 13;
    invalid([&] { TemplateTracker rejected(bad); }, "track count exceeded hard bound");

    TrackerOptions bounded;
    bounded.maxTracks = 2;
    TemplateTracker cap(bounded);
    cv::Mat image = frame(patch, {100, 100});
    patch.copyTo(image(cv::Rect(300, 100, 80, 64)));
    patch.copyTo(image(cv::Rect(100, 300, 80, 64)));
    auto invalidDet = detection({100, 100});
    invalidDet.box.x = std::numeric_limits<float>::quiet_NaN();
    auto invalidScore = detection({100, 100});
    invalidScore.score = std::numeric_limits<float>::infinity();
    cap.correct(image, {detection({100, 100}, {80, 64}, 1, 0.7f),
                        detection({300, 100}, {80, 64}, 1, 0.8f),
                        detection({100, 300}, {80, 64}, 1, 0.9f),
                        invalidDet, invalidScore, detection({900, 900})}, 0);
    const auto tracks = cap.tracks(0);
    require(tracks.size() == 2 && tracks[0].detectionScore == 0.9f &&
            tracks[1].detectionScore == 0.8f, "track cap/confidence priority/invalid box filtering failed");
    // Caller mutation after correct cannot change the owned templates.
    image.setTo(0);
    cv::Mat owned = frame(patch, {100, 300});
    patch.copyTo(owned(cv::Rect(300, 100, 80, 64)));
    const auto matched = cap.update(owned, 33);
    require(matched.size() == 2 && !matched[0].predicted && !matched[1].predicted,
            "correct retained caller-owned image pixels");
    std::cout << "  image edges/size reset, validation, bounded tracks, owned image pixels: PASS\n";
}

void boundedLargeMotionAndScale() {
    // Odd coordinates/sizes expose floor/ceil inflation. Fine NCC keeps integer
    // translations accurate; only the 1.05 size-change case allows <=2px error.
    const cv::Mat patch = texture(201, {193, 145});
    TemplateTracker tracker;
    tracker.correct(frame(patch, {101, 103}), {detection({101, 103}, patch.size())}, 0);
    const uint64_t id = tracker.tracks(0).at(0).id;
    int n = 0;
    for (const cv::Point& p : {cv::Point(132, 120), cv::Point(163, 137),
         cv::Point(194, 154), cv::Point(225, 171), cv::Point(256, 188),
         cv::Point(287, 205), cv::Point(318, 222), cv::Point(349, 239),
         cv::Point(380, 256), cv::Point(411, 273), cv::Point(447, 290),
         cv::Point(447, 307), cv::Point(447, 335)}) {
        const auto found = tracker.update(frame(patch, p), ++n * 33);
        require(found.size() == 1 && found[0].id == id, "large fast target lost ID");
        near(found[0], p, "bounded large/odd/fast/edge match failed");
        require(std::abs(found[0].box.width - 193) < 0.01f &&
                std::abs(found[0].box.height - 145) < 0.01f,
                "bounded work-size rounding changed logical target dimensions");
    }
    for (int j = 0; j < 20; ++j) {
        const auto found = tracker.update(frame(patch, {447, 335}), ++n * 33);
        near(found.at(0), {447, 335}, "bounded stationary edge drifted");
        require(std::abs(found[0].box.width - 193) < 0.01f &&
                std::abs(found[0].box.height - 145) < 0.01f,
                "stationary large box accumulated scale drift");
    }

    const cv::Mat source = texture(202, {192, 144});
    TemplateTracker scaled;
    scaled.correct(frame(source, {101, 103}), {detection({101, 103}, source.size())}, 0);
    cv::Mat larger;
    cv::resize(source, larger, {202, 152}, 0, 0, cv::INTER_LINEAR);
    const auto found = scaled.update(frame(larger, {132, 120}), 33);
    near(found.at(0), {132, 120}, "bounded three-scale location failed");
    require(std::abs(found[0].box.width - 202) <= 2 &&
            std::abs(found[0].box.height - 152) <= 2,
            "bounded three-scale size search failed");

    TrackerOptions referenceOptions;
    referenceOptions.maxTemplateSide = 0;
    TemplateTracker reference(referenceOptions), bounded;
    for (auto* t : {&reference, &bounded}) {
        t->correct(frame(source, {100, 100}), {detection({100, 100}, source.size())}, 0);
        near(t->update(frame(source, {130, 118}), 33).at(0), {130, 118},
             "cap/reference comparison did not match");
        require(t->tracks(33)[0].box.size() == cv::Size2f(source.size()),
                "cap/reference comparison shrank detection box");
    }
    TemplateTracker oddCanvas;
    oddCanvas.correct(frame(source, {101, 103}, 0, {641, 481}),
                      {detection({101, 103}, source.size())}, 0);
    near(oddCanvas.update(frame(source, {132, 120}, 0, {641, 481}), 33).at(0),
         {132, 120}, "bounded actual x/y resize ratios missed odd canvas");
    const cv::Mat thin = texture(203, {192, 8});
    TemplateTracker thinTarget;
    thinTarget.correct(frame(thin, {100, 100}), {detection({100, 100}, thin.size())}, 0);
    const auto thinFound = thinTarget.update(frame(thin, {130, 102}), 33);
    near(thinFound.at(0), {130, 102}, "capped thin target lost the NCC minimum short side");
    require(thinFound[0].box.size() == cv::Size2f(thin.size()),
            "capped thin target changed logical dimensions");
    std::cout << "  capped large fast/odd/edge motion, stable sizes, scale/reference: PASS\n";
}

void boundedReplayAndRejection() {
    const cv::Mat patch = texture(211, {192, 144});
    const cv::Mat source = frame(patch, {101, 103});
    TemplateTracker live;
    live.correct(source, {detection({101, 103}, patch.size())}, 100);
    TemplateTracker snapshot(live), assigned;
    assigned = live;
    for (int n = 1; n <= 8; ++n)
        near(live.update(frame(patch, {101 + n * 11, 103 + n * 7}, n * 2),
                         100 + n * 33).at(0), {101 + n * 11, 103 + n * 7},
             "bounded live history match failed");
    const auto expected = live.tracks(364).at(0);
    // Correction replaces both coarse and fine pixels only in the live branch.
    const cv::Mat changed = texture(212, patch.size());
    live.correct(frame(changed, {189, 159}), {detection({189, 159}, patch.size())}, 364);
    live = snapshot;
    live.correct(source, {detection({101, 103}, patch.size())}, 100);
    for (int n = 1; n <= 8; ++n)
        live.update(frame(patch, {101 + n * 11, 103 + n * 7}, n * 2), 100 + n * 33);
    const auto replay = live.tracks(364).at(0);
    require(replay.id == expected.id && replay.box == expected.box &&
            replay.matchScore == expected.matchScore, "bounded replay changed matching result");
    near(assigned.update(frame(patch, {112, 110}), 133).at(0), {112, 110},
         "bounded assignment/detail pixels were shared with corrected branch");
    require(snapshot.tracks(100).at(0).box.x == 101, "bounded snapshot state was mutated");
    const cv::Mat blank(480, 640, CV_8UC1, cv::Scalar(30));
    for (int n = 1; n <= 3; ++n) {
        const auto weak = live.update(blank, 364 + n * 33);
        require(weak.size() == 1 && weak[0].predicted && weak[0].weakFrames == n &&
                live.needsDetection(364 + n * 33), "bounded occlusion bypassed weak budget");
    }
    require(live.update(blank, 496).empty(), "bounded occlusion exceeded weak budget");

    // Two complete copies inside the original local search range, separated by
    // half a box. The second overwrites part of the first with periodic pixels.
    cv::Mat periodic(144, 192, CV_8UC1);
    const cv::Mat tile = texture(213, {48, 48});
    for (int y = 0; y < periodic.rows; y += tile.rows)
        for (int x = 0; x < periodic.cols; x += tile.cols)
            tile.copyTo(periodic(cv::Rect(x, y, tile.cols, tile.rows)));
    TemplateTracker repeated;
    repeated.correct(frame(periodic, {100, 100}), {detection({100, 100}, periodic.size())}, 0);
    cv::Mat twins = frame(periodic, {100, 100});
    periodic.copyTo(twins(cv::Rect(196, 100, 192, 144)));
    const auto ambiguous = repeated.update(twins, 33);
    require(ambiguous.size() == 1 && ambiguous[0].predicted && repeated.needsDetection(33),
            "capped periodic texture passed distant-peak rejection");
    std::cout << "  capped deep-copy replay, occlusion and periodic-peak rejection: PASS\n";
}

void observationExclusionAndTiming() {
    const cv::Mat patch = texture(221);
    const cv::Mat source = frame(patch, {100, 100});
    TemplateTracker competing;
    competing.correct(source, {detection({100, 100}), detection({102, 100})}, 0);
    const auto initial = competing.tracks(0);
    const auto result = competing.update(frame(patch, {108, 100}), 33);
    require(result.size() == 2, "observation conflict deleted a track immediately");
    int strong = 0, weak = 0;
    size_t loser = 0;
    for (size_t i = 0; i < result.size(); ++i) {
        if (result[i].predicted) { ++weak; loser = i; }
        else ++strong;
    }
    require(strong == 1 && weak == 1 && competing.needsDetection(33),
            "same-class tracks shared the same observation");
    require(result[loser].box == initial[loser].box && result[loser].weakFrames == 1,
            "conflicting weak match changed measured geometry");
    const auto hidden = competing.update(cv::Mat(480, 640, CV_8UC1, cv::Scalar(30)), 66);
    require(hidden[loser].box == initial[loser].box,
            "conflicting candidate updated the losing track velocity");
    const auto recovered = competing.update(frame(patch, {100, 100}), 99);
    require(std::count_if(recovered.begin(), recovered.end(), [](const Track& t) {
        return !t.predicted;
    }) == 1, "competition lost the unchanged original appearance");

    // Same-class boxes overlap by 87.5%, but have distinct centers and pixels.
    const cv::Mat scenePatch = texture(222, {90, 64});
    const cv::Mat scene = frame(scenePatch, {100, 100});
    TemplateTracker overlapping;
    overlapping.correct(scene, {detection({100, 100}), detection({110, 100})}, 0);
    const auto distinct = overlapping.update(frame(scenePatch, {104, 102}), 33);
    require(distinct.size() == 2 && !distinct[0].predicted && !distinct[1].predicted,
            "genuine overlapping same-class targets were suppressed");
    near(distinct[0], {104, 102}, "first overlapping target missed");
    near(distinct[1], {114, 102}, "second overlapping target missed");

    TemplateTracker different;
    different.correct(source, {detection({100, 100}, {80, 64}, 1),
                               detection({100, 100}, {80, 64}, 2)}, 0);
    const auto classes = different.update(frame(patch, {104, 102}), 33);
    require(classes.size() == 2 && !classes[0].predicted && !classes[1].predicted,
            "observation exclusion crossed class boundaries");

    require(different.lastTiming().prepareMs > 0 && different.lastTiming().matchMs > 0 &&
            different.lastTiming().correctMs == 0, "update timing segments invalid");
    different.update(frame(patch, {104, 102}), 33);
    require(different.lastTiming().prepareMs > 0 && different.lastTiming().matchMs == 0 &&
            different.lastTiming().correctMs == 0, "idempotent update retained stale costs");
    different.correct(source, {detection({100, 100})}, 33);
    require(different.lastTiming().prepareMs > 0 && different.lastTiming().matchMs == 0 &&
            different.lastTiming().correctMs > 0, "correction timing segments invalid");
    invalid([&] { different.update(cv::Mat(), 66); }, "invalid timed input accepted");
    require(different.lastTiming().matchMs == 0 && different.lastTiming().correctMs == 0,
            "invalid input retained old matching/correction timing");
    for (int value : {-1, 1, 15, 129, std::numeric_limits<int>::max()}) {
        TrackerOptions bad;
        bad.maxTemplateSide = value;
        invalid([&] { TemplateTracker rejected(bad); }, "invalid working-template cap accepted");
    }
    for (int value : {0, 16, 48, 128}) {
        TrackerOptions valid;
        valid.maxTemplateSide = value;
        TemplateTracker accepted(valid);
    }
    std::cout << "  same-observation exclusion, real overlap/classes, timing reset, cap validation: PASS\n";
}

void largeLowCapAndDetailPhases() {
    for (int cap : {16, 48, 128}) {
        TrackerOptions options;
        options.maxTemplateSide = cap;
        for (const cv::Size& size : {cv::Size(600, 400), cv::Size(600, 8)}) {
            const cv::Mat patch = texture(231 + size.height, size);
            TemplateTracker tracker(options);
            tracker.correct(frame(patch, {20, 20}), {detection({20, 20}, size)}, 0);
            require(tracker.tracks(0).size() == 1, "low-cap huge texture discarded at correction");
            TemplateTracker snapshot = tracker;
            int n = 0;
            for (const cv::Point& p : {cv::Point(20, 20), cv::Point(37, 29),
                                      cv::Point(3, 47), cv::Point(20, 20)}) {
                const auto found = tracker.update(frame(patch, p), ++n * 33);
                const std::string context = "cap=" + std::to_string(cap) + " size=" +
                    std::to_string(size.width) + "x" + std::to_string(size.height) +
                    " step=" + std::to_string(n) + " expected=" + std::to_string(p.x) +
                    "," + std::to_string(p.y);
                require(found.size() == 1, "low-cap huge/thin target lost " + context);
                near(found[0], p, "low-cap huge/thin phase coverage failed " + context);
                require(found[0].box.size() == cv::Size2f(size),
                        "low-cap huge/thin output size changed");
            }
            tracker = snapshot;
            near(tracker.update(frame(patch, {20, 20}), 33).at(0), {20, 20},
                 "low-cap whole-anchor copy/replay failed");
        }
    }
    // All five potential detail locations contain identical high-contrast
    // period4 pixels. The rest of the whole box is unique random texture.
    // A local equal-score +/-4 or +/-8 phase must not shift the accepted box.
    cv::Mat patch = texture(232, {192, 144});
    for (const cv::Point& p : {cv::Point(80, 56), cv::Point(0, 0),
                             cv::Point(160, 0), cv::Point(0, 112), cv::Point(160, 112)}) {
        for (int y = 0; y < 32; ++y)
            for (int x = 0; x < 32; ++x)
                patch.at<uint8_t>(p.y + y, p.x + x) = ((x / 2 + y / 2) % 2) ? 220 : 50;
    }
    TemplateTracker localPeriod;
    localPeriod.correct(frame(patch, {101, 103}), {detection({101, 103}, patch.size())}, 0);
    const auto found = localPeriod.update(frame(patch, {112, 110}), 33);
    require(found.size() == 1, "local-period target disappeared before weak budget");
    if (found[0].predicted) {
        require(found[0].weakFrames == 1 && localPeriod.needsDetection(33),
                "local detail ambiguity did not request correction");
    } else {
        near(found[0], {112, 110}, "single local detail phase overrode unique whole-box evidence");
    }
    std::cout << "  cap16/48/128 huge/thin phase coverage, whole-box detail verification: PASS\n";
}

// Deterministic computation workload, not an accuracy test on physical objects.
// Five bounded cycles per case: one warmup, four measured, six replay frames each.
constexpr uint64_t benchmarkSeed = 0x3568;
constexpr int benchmarkHistoryFrames = 6;
constexpr int benchmarkMeasuredCycles = 4;

struct BenchmarkCost {
    int samples = 0;
    double totalMs = 0;
    double maxMs = 0;

    void add(double ms) {
        ++samples;
        totalMs += ms;
        maxMs = std::max(maxMs, ms);
    }

    void print(const char* sizeName, int count, const char* operation) const {
        std::cout << "[tracker-benchmark-cost] size=" << sizeName
                  << " requested=" << count << " operation=" << operation
                  << " samples=" << samples << " mean_ms=" << totalMs / samples
                  << " max_ms=" << maxMs << '\n';
    }
};

using BenchmarkClock = std::chrono::steady_clock;

double benchmarkElapsed(BenchmarkClock::time_point start,
                        BenchmarkClock::time_point end) {
    return std::chrono::duration<double, std::milli>(end - start).count();
}

struct BenchmarkFrame {
    cv::Mat gray;
    std::vector<ObjectDetection> detections;
    int64_t timeMs = 0;
};

struct BenchmarkScene {
    cv::Size boxSize;
    cv::Size cellSize;
    cv::Size canvasSize;
    cv::Point padding;
    int columns;
    std::vector<cv::Mat> patches;

    BenchmarkScene(int count, cv::Size box) : boxSize(box) {
        // Reserve the full strong-match search radius plus motion allowance on
        // BOTH sides. Adjacent targets cannot overwrite pixels or enter a local
        // search window. Even coordinates preserve exact 0.5-scale templates.
        const auto margin = [](int extent) {
            const int pixels = cvRound(std::max(24.0, extent * 0.6)) + 16;
            return (pixels + 1) / 2 * 2;
        };
        padding = {margin(box.width), margin(box.height)};
        cellSize = {box.width + padding.x * 2, box.height + padding.y * 2};
        columns = count == 12 ? 4 : count == 4 ? 2 : 1;
        const int rows = (count + columns - 1) / columns;
        canvasSize = {std::max(640, columns * cellSize.width),
                      std::max(480, rows * cellSize.height)};
        require(canvasSize.width <= 1920 && canvasSize.height <= 1080,
                "benchmark canvas exceeded its bounded workload");
        for (int i = 0; i < count; ++i)
            patches.push_back(texture(benchmarkSeed + i, boxSize));
    }

    BenchmarkFrame makeFrame(int n) const {
        // Bounded triangle motion avoids a large discontinuity at wraparound.
        const int x = n % 16, y = n % 12;
        const cv::Point motion(2 * std::min(x, 16 - x),
                               2 * std::min(y, 12 - y));
        BenchmarkFrame result;
        result.gray = cv::Mat(canvasSize, CV_8UC1, cv::Scalar(30));
        result.timeMs = n * 33;
        for (size_t i = 0; i < patches.size(); ++i) {
            const cv::Point position(padding.x + int(i) % columns * cellSize.width + motion.x,
                                     padding.y + int(i) / columns * cellSize.height + motion.y);
            const cv::Rect roi(position, boxSize);
            require((roi & cv::Rect({}, canvasSize)) == roi,
                    "benchmark target clipped by canvas");
            for (const auto& prior : result.detections)
                require((prior.box & cv::Rect2f(roi)).area() == 0,
                        "benchmark targets overlap");
            patches[i].copyTo(result.gray(roi));
            // Same-class objects also exercise the association candidate loop.
            result.detections.push_back(detection(position, boxSize));
        }
        return result;
    }
};

struct BenchmarkPopulation {
    int liveMin = 12, liveMax = 0;
    int matchedMin = 12, matchedMax = 0;

    void observe(const std::vector<Track>& tracks, const BenchmarkFrame& input,
                 bool expectMatch, const std::string& context) {
        const int live = int(tracks.size());
        liveMin = std::min(liveMin, live);
        liveMax = std::max(liveMax, live);
        int matched = 0;
        for (const auto& track : tracks)
            if (!track.predicted && track.weakFrames == 0 && track.matchScore >= 0.65f)
                ++matched;
        if (expectMatch) {
            matchedMin = std::min(matchedMin, matched);
            matchedMax = std::max(matchedMax, matched);
        }
        require(live == int(input.detections.size()) && (!expectMatch || matched == live),
                context + " live=" + std::to_string(live) +
                " matched=" + std::to_string(matched) +
                " requested=" + std::to_string(input.detections.size()));
        for (size_t i = 0; i < tracks.size(); ++i) {
            const auto& actual = tracks[i].box;
            const auto& expected = input.detections[i].box;
            require(std::abs(actual.x - expected.x) <= 2 &&
                    std::abs(actual.y - expected.y) <= 2 &&
                    std::abs(actual.width - expected.width) < 0.5f &&
                    std::abs(actual.height - expected.height) < 0.5f,
                    context + " target geometry/template size diverged");
        }
    }
};

void benchmarkCase(const char* sizeName, cv::Size box, int count, int maxTemplateSide) {
    const BenchmarkScene scene(count, box);
    TrackerOptions options;
    options.maxTemplateSide = maxTemplateSide;
    TemplateTracker tracker(options);
    BenchmarkPopulation population;
    BenchmarkCost updateCost, snapshotCost, restoreCost, correctionCost,
                  replayCost, recoveryCost, prepareCost, matchCost, correctCoreCost;
    const std::string context = std::string("benchmark size=") + sizeName +
                                " requested=" + std::to_string(count);
    for (int cycle = 0; cycle <= benchmarkMeasuredCycles; ++cycle) {
        const bool measured = cycle > 0;
        // Allocate/generate input and history containers outside all timings.
        std::vector<BenchmarkFrame> history;
        history.reserve(benchmarkHistoryFrames + 1);
        for (int n = 0; n <= benchmarkHistoryFrames; ++n)
            history.push_back(scene.makeFrame(cycle * benchmarkHistoryFrames + n));
        tracker.correct(history[0].gray, history[0].detections, history[0].timeMs);
        population.observe(tracker.tracks(history[0].timeMs), history[0], false, context);
        const auto sourceStart = BenchmarkClock::now();
        const TemplateTracker sourceSnapshot(tracker);
        const auto sourceEnd = BenchmarkClock::now();
        if (measured) snapshotCost.add(benchmarkElapsed(sourceStart, sourceEnd));

        std::vector<TemplateTracker> liveSnapshots;
        liveSnapshots.reserve(benchmarkHistoryFrames);
        std::vector<Track> latest;
        for (int n = 1; n <= benchmarkHistoryFrames; ++n) {
            const auto& input = history[n];
            const auto updateStart = BenchmarkClock::now();
            const auto tracks = tracker.update(input.gray, input.timeMs);
            const auto updateEnd = BenchmarkClock::now();
            const auto snapshotStart = BenchmarkClock::now();
            liveSnapshots.emplace_back(tracker);
            const auto snapshotEnd = BenchmarkClock::now();
            if (measured) {
                updateCost.add(benchmarkElapsed(updateStart, updateEnd));
                prepareCost.add(tracker.lastTiming().prepareMs);
                matchCost.add(tracker.lastTiming().matchMs);
                snapshotCost.add(benchmarkElapsed(snapshotStart, snapshotEnd));
            }
            population.observe(tracks, input, true, context + " update");
            population.observe(liveSnapshots.back().tracks(input.timeMs), input, true,
                               context + " deep snapshot");
            latest = tracks;
        }

        // Simulate a delayed authoritative detection. Restore the SOURCE frame,
        // correct at its exact time, then rebuild the later history snapshots.
        // Recovery timing includes deep clones, not just six update() calls.
        std::vector<TemplateTracker> replaySnapshots;
        replaySnapshots.reserve(benchmarkHistoryFrames);
        std::vector<std::vector<Track>> replayTracks(benchmarkHistoryFrames);
        const auto recoveryStart = BenchmarkClock::now();
        tracker = sourceSnapshot;
        const auto restoreEnd = BenchmarkClock::now();
        tracker.correct(history[0].gray, history[0].detections, history[0].timeMs);
        const TrackerTiming correctionTiming = tracker.lastTiming();
        const auto correctionEnd = BenchmarkClock::now();
        for (int n = 1; n <= benchmarkHistoryFrames; ++n) {
            replayTracks[n - 1] = tracker.update(history[n].gray, history[n].timeMs);
            replaySnapshots.emplace_back(tracker);
        }
        const auto recoveryEnd = BenchmarkClock::now();
        if (measured) {
            restoreCost.add(benchmarkElapsed(recoveryStart, restoreEnd));
            correctionCost.add(benchmarkElapsed(restoreEnd, correctionEnd));
            correctCoreCost.add(correctionTiming.correctMs);
            replayCost.add(benchmarkElapsed(correctionEnd, recoveryEnd));
            recoveryCost.add(benchmarkElapsed(recoveryStart, recoveryEnd));
        }
        // Verification and console I/O are excluded from measured costs.
        for (int n = 1; n <= benchmarkHistoryFrames; ++n) {
            population.observe(replayTracks[n - 1], history[n], true, context + " replay");
            population.observe(replaySnapshots[n - 1].tracks(history[n].timeMs),
                               history[n], true, context + " replay snapshot");
        }
        const auto& replayed = replayTracks.back();
        for (size_t i = 0; i < latest.size(); ++i)
            require(latest[i].id == replayed[i].id && latest[i].box == replayed[i].box,
                    context + " replay changed target ID/geometry");
    }
    // Report bounds rather than mistaking uncapped source pixels for the actual
    // owned appearance/anchor. Small reference-path search windows also fit this
    // conservative bound; fine NCC uses <=cap templates and <=24-pixel tile spans.
    std::cout << "[tracker-benchmark-case] size=" << sizeName << " requested=" << count
              << " seed=" << benchmarkSeed
              << " canvas=" << scene.canvasSize.width << 'x' << scene.canvasSize.height
              << " box=" << box.width << 'x' << box.height
              << " source_scaled_box=" << cvRound(box.width * options.scale) << 'x'
              << cvRound(box.height * options.scale) << " scale=" << options.scale
              << " template_cap=" << options.maxTemplateSide
              << " appearance_anchor_side_bound=" << (options.maxTemplateSide ?
                 int(std::floor(options.maxTemplateSide / 1.05)) :
                 cvRound(std::max(box.width, box.height) * options.scale))
              << " fine_tile_side_bound=" << (options.maxTemplateSide ? options.maxTemplateSide + 24 : 0)
              << " fine_phase_range=two_coarse_cells_tiled"
              << " ncc_template_side_bound=" << (options.maxTemplateSide ?
                 options.maxTemplateSide : cvRound(std::max(box.width, box.height) * options.scale * 1.4))
              << " local_search_side_ceil_bound=" << (options.maxTemplateSide ?
                 int(std::ceil(3.4 * options.maxTemplateSide + 104)) : 0)
              << " live_min=" << population.liveMin << " live_max=" << population.liveMax
              << " matched_min=" << population.matchedMin
              << " matched_max=" << population.matchedMax
              << " warmup_cycles=1 measured_cycles=" << benchmarkMeasuredCycles
              << " history_frames=" << benchmarkHistoryFrames << '\n';
    updateCost.print(sizeName, count, "update");
    prepareCost.print(sizeName, count, "update_prepare");
    matchCost.print(sizeName, count, "update_match");
    correctCoreCost.print(sizeName, count, "correct_core");
    snapshotCost.print(sizeName, count, "deep_snapshot");
    restoreCost.print(sizeName, count, "restore_snapshot");
    correctionCost.print(sizeName, count, "correction");
    replayCost.print(sizeName, count, "history_replay_with_snapshots");
    recoveryCost.print(sizeName, count, "restore_correction_replay");
}

} // namespace

int runTrackerSelfTest() {
    try {
        movementAndLight();
        scaleSearch();
        rejectFlatAndAmbiguous();
        occlusionAndTTL();
        associationAndCorrection();
        copiesReplayAndTime();
        boundsAndValidation();
        boundedLargeMotionAndScale();
        boundedReplayAndRejection();
        observationExclusionAndTiming();
        largeLowCapAndDetailPhases();
        std::cout << "TRACKER_SELFTEST_PASS\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "TRACKER_SELFTEST_FAIL: " << e.what() << '\n';
        return 1;
    }
}

} // namespace tdm

int tdm::runTrackerBenchmark(int maxTemplateSide) {
    try {
        TrackerOptions options;
        options.maxTemplateSide = maxTemplateSide;
        const TemplateTracker validated(options);
        std::cout << "[tracker-benchmark] synthetic_compute_only=1 physical_accuracy=unmeasured"
                     " no_camera_npu_dma=1 seed=" << benchmarkSeed
                  << " opencv_threads=" << cv::getNumThreads()
                  << " template_cap=" << maxTemplateSide
                  << " canvas_cap=1920x1080 frame_interval_ms=33"
                     " timings=steady_clock_ms input_generation_validation_io=excluded"
                     " update_includes_gray_resize=1 snapshot_includes_owned_template_clones=1"
                     " replay_includes_history_snapshot_rebuild=1\n";
        for (int count : {1, 4, 12}) {
            benchmarkCase("small", {32, 24}, count, maxTemplateSide);
            benchmarkCase("medium", {80, 64}, count, maxTemplateSide);
            benchmarkCase("large", {192, 144}, count, maxTemplateSide);
        }
        std::cout << "TRACKER_BENCHMARK_PASS\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "TRACKER_BENCHMARK_FAIL: " << e.what() << '\n';
        return 1;
    }
}

#ifdef TDM_TRACKER_SELFTEST_MAIN
int main(int argc, char** argv) {
    cv::setNumThreads(2);
    if (argc >= 2 && (std::string(argv[1]) == "--benchmark" ||
                      std::string(argv[1]) == "--tracker-benchmark")) {
        try {
            size_t used = 0;
            const int cap = argc >= 3 ? std::stoi(argv[2], &used) : 48;
            if (argc > 3 || (argc >= 3 && used != std::string(argv[2]).size()))
                throw std::invalid_argument("invalid benchmark cap argument");
            return tdm::runTrackerBenchmark(cap);
        } catch (const std::exception& e) {
            std::cerr << "TRACKER_BENCHMARK_FAIL: " << e.what() << '\n';
            return 1;
        }
    }
    return tdm::runTrackerSelfTest();
}
#endif
