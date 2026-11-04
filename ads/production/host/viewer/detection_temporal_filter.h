#ifndef TDM_DETECTION_TEMPORAL_FILTER_H
#define TDM_DETECTION_TEMPORAL_FILTER_H

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <type_traits>
#include <utility>
#include <vector>

namespace tdm {

namespace temporal_detail {
template <class T, class = void> struct HasPredicted : std::false_type {};
template <class T>
struct HasPredicted<T, std::void_t<decltype(std::declval<const T&>().predicted)>>
    : std::true_type {};
template <class T> bool predicted(const T& d) {
    if constexpr (HasPredicted<T>::value) return static_cast<bool>(d.predicted);
    return false;
}
} // namespace temporal_detail

// Call process once per completed inference, including empty results. Call
// visible for timer/render ticks. Clear on source/model changes. Detection must
// have cls, score, x1/y1/x2/y2 and an assignable signed validUntilMs field;
// predicted, when present, marks observations that must not count as evidence.
// The other Detection fields are copied verbatim from the latest observation.
template <class Detection> class TemporalDetectionFilter {
    // Real detector coordinates are float. Their area products fit in double,
    // including subnormal float coordinates. Avoid software float128 arithmetic
    // on ARM in the per-pair loop. Wider generic coordinates keep the guarded
    // implementation below.
    using Overlap = std::conditional_t<
        std::is_same_v<std::decay_t<decltype(std::declval<Detection>().x1)>, float> &&
        std::is_same_v<std::decay_t<decltype(std::declval<Detection>().y1)>, float> &&
        std::is_same_v<std::decay_t<decltype(std::declval<Detection>().x2)>, float> &&
        std::is_same_v<std::decay_t<decltype(std::declval<Detection>().y2)>, float>,
        double, long double>;
public:
    struct Config {
        std::size_t confirmationFrames = 3;
        double minimumIou = 0.25;
        std::int64_t retentionMs = 180;
        std::int64_t maximumObservationGapMs = 600;
        std::size_t maximumTracks = 600;
        std::size_t maximumDetectionsPerFrame = 300;
    };
    struct SampleStats {
        std::size_t inputCount = 0;
        std::size_t acceptedCount = 0;
        std::size_t matchedCount = 0;
        std::size_t promotedCount = 0;
        std::size_t pendingFiltered = 0;
        std::size_t rejectedCount = 0;
        std::size_t capacityDropped = 0;
        std::size_t outputCount = 0;
        bool ignoredFrame = false;
    };
    struct Stats {
        std::uint64_t processedFrames = 0;
        std::uint64_t totalInput = 0;
        std::uint64_t matchedCount = 0;
        std::uint64_t promotedCount = 0;
        std::uint64_t pendingFiltered = 0;
        std::uint64_t rejectedCount = 0;
        std::uint64_t capacityDropped = 0;
        std::uint64_t ignoredFrames = 0;
    };
    struct CurrentStats {
        std::size_t trackCount = 0;
        std::size_t pendingCount = 0;
        std::size_t confirmedCount = 0;
        std::size_t visibleCount = 0;
    };

    SampleStats lastSampleStats;

    TemporalDetectionFilter() = default;
    explicit TemporalDetectionFilter(Config config) : config_(config) {
        config_.confirmationFrames = std::max<std::size_t>(1, config_.confirmationFrames);
        if (!std::isfinite(config_.minimumIou)) config_.minimumIou = 0.25;
        config_.minimumIou = std::clamp(config_.minimumIou, 0.0, 1.0);
        config_.retentionMs = std::max<std::int64_t>(0, config_.retentionMs);
        config_.maximumObservationGapMs = std::max<std::int64_t>(0, config_.maximumObservationGapMs);
        config_.maximumTracks = std::min<std::size_t>(600, config_.maximumTracks);
        config_.maximumDetectionsPerFrame = std::min<std::size_t>(300, config_.maximumDetectionsPerFrame);
    }

    void clear() {
        tracks_.clear();
        hasFrame_ = false;
        hasTime_ = false;
        lastFrame_ = 0;
        lastTime_ = 0;
        totals_ = {};
        lastSampleStats = {};
    }

    const Stats& stats() const { return totals_; }
    CurrentStats current() const {
        CurrentStats result;
        result.trackCount = tracks_.size();
        for (const auto& track : tracks_) {
            if (track.confirmed) {
                ++result.confirmedCount;
                if (hasTime_ && lastTime_ <= track.deadlineMs) ++result.visibleCount;
            } else {
                ++result.pendingCount;
            }
        }
        return result;
    }

    std::vector<Detection> visible(std::int64_t nowMs) {
        observeTime(nowMs);
        expireHistory(nowMs);
        return collectVisible(nowMs);
    }

    std::vector<Detection> process(const std::vector<Detection>& detections,
                                   std::uint64_t frameId, std::int64_t nowMs) {
        observeTime(nowMs);
        expireHistory(nowMs);
        lastSampleStats = {};
        lastSampleStats.inputCount = detections.size();
        if (hasFrame_ && frameId <= lastFrame_) {
            ++totals_.ignoredFrames;
            lastSampleStats.ignoredFrame = true;
            auto output = collectVisible(nowMs);
            lastSampleStats.outputCount = output.size();
            return output;
        }
        hasFrame_ = true;
        lastFrame_ = frameId;
        ++totals_.processedFrames;
        totals_.totalInput += detections.size();

        // Keep only the highest-scoring valid inputs, with bounded working
        // storage even if a caller supplies more than the normal 300 results.
        std::vector<std::size_t> inputs;
        inputs.reserve(std::min(detections.size(), config_.maximumDetectionsPerFrame));
        const auto better = [&](std::size_t a, std::size_t b) {
            if (detections[a].score != detections[b].score)
                return detections[a].score > detections[b].score;
            return a < b;
        };
        for (std::size_t i = 0; i < detections.size(); ++i) {
            if (!valid(detections[i], nowMs)) {
                ++lastSampleStats.rejectedCount;
                continue;
            }
            if (config_.maximumDetectionsPerFrame == 0) {
                ++lastSampleStats.capacityDropped;
                continue;
            }
            if (inputs.size() < config_.maximumDetectionsPerFrame) {
                inputs.push_back(i);
                std::push_heap(inputs.begin(), inputs.end(), better);
            } else {
                ++lastSampleStats.capacityDropped;
                if (better(i, inputs.front())) {
                    std::pop_heap(inputs.begin(), inputs.end(), better);
                    inputs.back() = i;
                    std::push_heap(inputs.begin(), inputs.end(), better);
                }
            }
        }
        std::sort(inputs.begin(), inputs.end(), better);
        lastSampleStats.acceptedCount = inputs.size();

        struct Pair { Overlap overlap; std::size_t track; std::size_t input; };
        std::vector<Pair> pairs;
        for (std::size_t t = 0; t < tracks_.size(); ++t) {
            for (std::size_t d = 0; d < inputs.size(); ++d) {
                const auto& detection = detections[inputs[d]];
                if (tracks_[t].detection.cls != detection.cls) continue;
                const auto overlap = iou(tracks_[t].detection, detection);
                if (overlap > 0 && overlap >= config_.minimumIou)
                    pairs.push_back({overlap, t, d});
            }
        }
        std::sort(pairs.begin(), pairs.end(), [](const Pair& a, const Pair& b) {
            if (a.overlap != b.overlap) return a.overlap > b.overlap;
            if (a.track != b.track) return a.track < b.track;
            return a.input < b.input;
        });
        std::vector<bool> matchedTracks(tracks_.size(), false);
        std::vector<bool> matchedInputs(inputs.size(), false);
        for (const auto& pair : pairs) {
            if (matchedTracks[pair.track] || matchedInputs[pair.input]) continue;
            matchedTracks[pair.track] = true;
            matchedInputs[pair.input] = true;
            update(tracks_[pair.track], detections[inputs[pair.input]], nowMs);
            ++lastSampleStats.matchedCount;
        }

        // A single missing inference breaks a tentative streak completely.
        for (std::size_t t = tracks_.size(); t-- > 0;) {
            if (!matchedTracks[t]) {
                if (!tracks_[t].confirmed)
                    tracks_.erase(tracks_.begin() + static_cast<std::ptrdiff_t>(t));
                else tracks_[t].missed = true;
            }
        }
        for (std::size_t d = 0; d < inputs.size(); ++d) {
            if (matchedInputs[d]) continue;
            if (tracks_.size() >= config_.maximumTracks) {
                ++lastSampleStats.capacityDropped;
                continue;
            }
            Track track{detections[inputs[d]], 0, false, nowMs, nowMs};
            update(track, detections[inputs[d]], nowMs);
            tracks_.push_back(std::move(track));
        }
        for (const auto& track : tracks_)
            if (!track.confirmed) ++lastSampleStats.pendingFiltered;

        totals_.matchedCount += lastSampleStats.matchedCount;
        totals_.promotedCount += lastSampleStats.promotedCount;
        totals_.pendingFiltered += lastSampleStats.pendingFiltered;
        totals_.rejectedCount += lastSampleStats.rejectedCount;
        totals_.capacityDropped += lastSampleStats.capacityDropped;
        auto output = collectVisible(nowMs);
        lastSampleStats.outputCount = output.size();
        return output;
    }

private:
    struct Track {
        Detection detection;
        std::size_t streak;
        bool confirmed;
        std::int64_t lastObservationMs;
        std::int64_t deadlineMs;
        bool missed = false;
    };
    Config config_;
    std::vector<Track> tracks_;
    Stats totals_;
    bool hasFrame_ = false;
    bool hasTime_ = false;
    std::uint64_t lastFrame_ = 0;
    std::int64_t lastTime_ = 0;

    void observeTime(std::int64_t nowMs) {
        // A clock discontinuity invalidates all association and frame history.
        if (hasTime_ && nowMs < lastTime_) clear();
        hasTime_ = true;
        lastTime_ = nowMs;
    }
    void expireHistory(std::int64_t nowMs) {
        tracks_.erase(std::remove_if(tracks_.begin(), tracks_.end(), [&](const Track& t) {
            // A real missed detector result followed by expired grace needs
            // fresh confirmation. Slow but continuously matched models keep
            // their observation history across render-only expiry.
            if (t.confirmed && t.missed && nowMs > t.deadlineMs) return true;
            // Unsigned subtraction avoids overflow across signed time bounds.
            return static_cast<std::uint64_t>(nowMs) - static_cast<std::uint64_t>(t.lastObservationMs)
                > static_cast<std::uint64_t>(config_.maximumObservationGapMs);
        }), tracks_.end());
    }
    static bool valid(const Detection& d, std::int64_t nowMs) {
        return d.cls >= 0 && !temporal_detail::predicted(d)
            && std::isfinite(static_cast<long double>(d.score))
            && std::isfinite(static_cast<long double>(d.x1))
            && std::isfinite(static_cast<long double>(d.y1))
            && std::isfinite(static_cast<long double>(d.x2))
            && std::isfinite(static_cast<long double>(d.y2))
            && d.x2 > d.x1 && d.y2 > d.y1
            && (d.validUntilMs == 0 || (d.validUntilMs > 0 && d.validUntilMs >= nowMs));
    }
    static Overlap iou(const Detection& a, const Detection& b) {
        if constexpr (std::is_same_v<Overlap, double>) {
            const double w = std::max(0.0, std::min(double(a.x2), double(b.x2)) -
                                         std::max(double(a.x1), double(b.x1)));
            const double h = std::max(0.0, std::min(double(a.y2), double(b.y2)) -
                                         std::max(double(a.y1), double(b.y1)));
            const double intersection = w * h;
            const double area = (double(a.x2) - double(a.x1)) * (double(a.y2) - double(a.y1)) +
                                (double(b.x2) - double(b.x1)) * (double(b.y2) - double(b.y1)) - intersection;
            return area > 0 ? intersection / area : 0;
        } else {
        // Normalize first so large finite coordinates cannot overflow areas.
        const long double scale = std::max({1.0L,
            std::abs(static_cast<long double>(a.x1)), std::abs(static_cast<long double>(a.y1)),
            std::abs(static_cast<long double>(a.x2)), std::abs(static_cast<long double>(a.y2)),
            std::abs(static_cast<long double>(b.x1)), std::abs(static_cast<long double>(b.y1)),
            std::abs(static_cast<long double>(b.x2)), std::abs(static_cast<long double>(b.y2))});
        const long double ax1 = a.x1 / scale, ay1 = a.y1 / scale;
        const long double ax2 = a.x2 / scale, ay2 = a.y2 / scale;
        const long double bx1 = b.x1 / scale, by1 = b.y1 / scale;
        const long double bx2 = b.x2 / scale, by2 = b.y2 / scale;
        const auto w = std::max(0.0L, std::min(ax2, bx2) - std::max(ax1, bx1));
        const auto h = std::max(0.0L, std::min(ay2, by2) - std::max(ay1, by1));
        const auto intersection = w * h;
        const auto area = (ax2 - ax1) * (ay2 - ay1) + (bx2 - bx1) * (by2 - by1) - intersection;
        return area > 0 ? intersection / area : 0;
        }
    }
    void update(Track& track, const Detection& detection, std::int64_t nowMs) {
        track.detection = detection;
        track.lastObservationMs = nowMs;
        track.missed = false;
        const auto maximum = std::numeric_limits<std::int64_t>::max();
        track.deadlineMs = nowMs > maximum - config_.retentionMs ? maximum : nowMs + config_.retentionMs;
        if (detection.validUntilMs > 0)
            track.deadlineMs = std::min(track.deadlineMs, static_cast<std::int64_t>(detection.validUntilMs));
        track.detection.validUntilMs = track.deadlineMs;
        if (!track.confirmed) {
            ++track.streak;
            if (track.streak >= config_.confirmationFrames) {
                track.confirmed = true;
                ++lastSampleStats.promotedCount;
            }
        }
    }
    std::vector<Detection> collectVisible(std::int64_t nowMs) const {
        std::vector<Detection> result;
        for (const auto& track : tracks_)
            if (track.confirmed && nowMs <= track.deadlineMs) result.push_back(track.detection);
        return result;
    }
};

// Defined by detection_temporal_filter_selftest.cpp; returns zero on success.
int runDetectionTemporalSelfTest();

} // namespace tdm

#endif // TDM_DETECTION_TEMPORAL_FILTER_H
