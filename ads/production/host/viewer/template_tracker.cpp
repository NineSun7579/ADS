#include "template_tracker.h"

#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <utility>

namespace tdm {
namespace {

std::atomic<uint64_t> nextId{1};

using Clock = std::chrono::steady_clock;
struct CostScope {
    double& cost;
    Clock::time_point start = Clock::now();
    ~CostScope() {
        cost += std::chrono::duration<double, std::milli>(Clock::now() - start).count();
    }
};

int baseSide(int cap) { return static_cast<int>(std::floor(cap / 1.05)); }

cv::Mat boundedPatch(const cv::Mat& patch, int cap) {
    if (!cap || std::max(patch.cols, patch.rows) <= baseSide(cap)) return patch.clone();
    const double ratio = double(baseSide(cap)) / std::max(patch.cols, patch.rows);
    cv::Mat result;
    // Preserve the NCC minimum on very thin targets with independent axis
    // ratios; the actual local ROI ratios are used again when mapping peaks.
    cv::resize(patch, result, {std::max(4, cvRound(patch.cols * ratio)),
                              std::max(4, cvRound(patch.rows * ratio))}, 0, 0, cv::INTER_AREA);
    return result;
}

uint64_t allocateId() {
    uint64_t id = nextId.load(std::memory_order_relaxed);
    for (;;) {
        if (id == std::numeric_limits<uint64_t>::max())
            throw std::overflow_error("template tracker ID space exhausted");
        if (nextId.compare_exchange_weak(id, id + 1, std::memory_order_relaxed))
            return id;
    }
}

cv::Point2f center(const cv::Rect2f& box) {
    return {box.x + box.width * 0.5f, box.y + box.height * 0.5f};
}

cv::Rect2f clip(cv::Rect2f box, cv::Size size) {
    return box & cv::Rect2f(0, 0, static_cast<float>(size.width),
                          static_cast<float>(size.height));
}

bool validBox(const cv::Rect2f& b) {
    return std::isfinite(b.x) && std::isfinite(b.y) &&
           std::isfinite(b.width) && std::isfinite(b.height) &&
           std::isfinite(b.x + b.width) && std::isfinite(b.y + b.height) &&
           b.width > 0 && b.height > 0;
}

float iou(const cv::Rect2f& a, const cv::Rect2f& b) {
    const float intersection = (a & b).area();
    const float total = a.area() + b.area() - intersection;
    return total > 0 ? intersection / total : 0;
}

bool textured(const cv::Mat& patch, float minimum) {
    if (patch.empty() || patch.cols < 4 || patch.rows < 4) return false;
    cv::Scalar mean, deviation;
    cv::meanStdDev(patch, mean, deviation);
    // A nonzero floor is necessary even when the configured threshold is zero:
    // TM_CCOEFF_NORMED reports 1 for a constant template.
    return deviation[0] >= std::max(0.5f, minimum);
}

cv::Rect scaledRect(const cv::Rect2f& b, cv::Size original, cv::Size small) {
    const double sx = static_cast<double>(small.width) / original.width;
    const double sy = static_cast<double>(small.height) / original.height;
    const int x = std::clamp(static_cast<int>(std::floor(b.x * sx)), 0, small.width);
    const int y = std::clamp(static_cast<int>(std::floor(b.y * sy)), 0, small.height);
    const int r = std::clamp(static_cast<int>(std::ceil((b.x + b.width) * sx)), x, small.width);
    const int d = std::clamp(static_cast<int>(std::ceil((b.y + b.height) * sy)), y, small.height);
    return {x, y, r - x, d - y};
}

struct Peak {
    float score;
    cv::Rect box;
};

struct Observation {
    cv::Rect2f box{};
    float score = 0;
    bool accepted = false;
    cv::Rect sampleBox{}; // exact small-image pixels; preserves the reference path
    cv::Rect2f coarseBox{}; // bounded-path provenance, before phase correction
};

bool distant(const cv::Rect2f& a, const cv::Rect2f& b, float sx, float sy) {
    const cv::Point2f difference = center(a) - center(b);
    return std::abs(difference.x) > std::max(2.f / sx, a.width * 0.25f) ||
           std::abs(difference.y) > std::max(2.f / sy, a.height * 0.25f);
}

bool uniquePeak(const std::vector<Observation>& peaks, float threshold, float sx, float sy) {
    if (peaks.empty() || peaks[0].score < threshold) return false;
    const auto& best = peaks[0];
    for (size_t i = 1; i < peaks.size(); ++i) {
        // Phase correction may pull two competing periodic peaks just inside
        // the quarter-box radius. Preserve their coarse separation as evidence.
        // Candidates that refine to the same original-pixel location are one
        // observation; coarse ambiguity is checked independently before refine.
        const cv::Point2f difference = center(peaks[i].box) - center(best.box);
        const bool distinct = std::abs(difference.x) > 2 || std::abs(difference.y) > 2;
        const bool coarseDistant = best.coarseBox.area() > 0 &&
            peaks[i].coarseBox.area() > 0 && distinct &&
            distant(best.coarseBox, peaks[i].coarseBox, sx, sy);
        // Same-scale fine alternatives must be unique at original-pixel
        // precision, even when a small period lies inside the whole-box radius.
        const bool fineDistant = best.coarseBox.area() > 0 &&
            peaks[i].coarseBox.area() > 0 && distinct &&
            std::abs(best.box.width - peaks[i].box.width) < 0.01f &&
            std::abs(best.box.height - peaks[i].box.height) < 0.01f;
        if ((distant(best.box, peaks[i].box, sx, sy) || coarseDistant || fineDistant) &&
            peaks[i].score >= threshold && best.score - peaks[i].score < 0.05f)
            return false;
    }
    return true;
}

// Keep a distant runner-up from EACH scale so duplicate objects and periodic
// textures cannot pass simply by producing many equally good NCC peaks.
void addPeaks(const cv::Mat& image, cv::Rect window, const cv::Mat& appearance,
              cv::Size size, float minimumTexture, std::vector<Peak>& peaks) {
    if (size.width < 4 || size.height < 4 || size.width > window.width ||
        size.height > window.height) return;
    cv::Mat templ;
    cv::resize(appearance, templ, size, 0, 0, cv::INTER_LINEAR);
    if (!textured(templ, minimumTexture)) return;
    cv::Mat response;
    cv::matchTemplate(image(window), templ, response, cv::TM_CCOEFF_NORMED);
    cv::patchNaNs(response, -1);
    for (int n = 0; n < 2; ++n) {
        double score;
        cv::Point location;
        cv::minMaxLoc(response, nullptr, &score, nullptr, &location);
        if (!std::isfinite(score) || score < -0.5) break;
        peaks.push_back({static_cast<float>(score),
                         cv::Rect(location + window.tl(), size)});
        const int rx = std::max(2, size.width / 4);
        const int ry = std::max(2, size.height / 4);
        const cv::Rect suppress = cv::Rect(location.x - rx, location.y - ry,
                                           rx * 2 + 1, ry * 2 + 1) &
                                  cv::Rect(0, 0, response.cols, response.rows);
        response(suppress).setTo(-1);
    }
}

} // namespace

TemplateTracker::TemplateTracker(TrackerOptions options) : options_(options) {
    if (options.maxTracks <= 0 || options.maxTracks > 12 ||
        !std::isfinite(options.scale) || options.scale <= 0 || options.scale > 1 ||
        !std::isfinite(options.matchThreshold) || options.matchThreshold <= 0 ||
        options.matchThreshold > 1 || !std::isfinite(options.updateThreshold) ||
        options.updateThreshold < options.matchThreshold || options.updateThreshold > 1 ||
        !std::isfinite(options.minimumTextureStdDev) || options.minimumTextureStdDev < 0 ||
        options.maxWeakFrames < 0 || options.maxDetectionAgeMs <= 0 ||
        (options.maxTemplateSide != 0 &&
         (options.maxTemplateSide < 16 || options.maxTemplateSide > 128)))
        throw std::invalid_argument("invalid template tracker options");
}

TemplateTracker::TemplateTracker(const TemplateTracker& other)
    : options_(other.options_), states_(other.states_), imageSize_(other.imageSize_),
      lastFrameMs_(other.lastFrameMs_), lastDetectionMs_(other.lastDetectionMs_),
      timing_(other.timing_) {
    for (auto& state : states_) {
        state.appearance = state.appearance.clone();
        state.anchor = state.anchor.clone();
        state.detail = state.detail.clone();
        state.fullAnchor = state.fullAnchor.clone();
    }
}

TemplateTracker& TemplateTracker::operator=(const TemplateTracker& other) {
    if (this != &other) {
        TemplateTracker copy(other);
        *this = std::move(copy);
    }
    return *this;
}

void TemplateTracker::clear() {
    states_.clear();
    imageSize_ = {};
    lastFrameMs_ = lastDetectionMs_ = -1;
    timing_ = {};
}

void TemplateTracker::validateTime(int64_t timeMs) const {
    if (timeMs < 0 || timeMs < lastFrameMs_)
        throw std::invalid_argument("template tracker time moved backwards");
}

cv::Mat TemplateTracker::prepare(const cv::Mat& gray, int64_t timeMs) {
    CostScope cost{timing_.prepareMs};
    validateTime(timeMs);
    if (gray.empty() || gray.type() != CV_8UC1 || gray.dims != 2)
        throw std::invalid_argument("template tracker requires nonempty CV_8UC1");
    const cv::Size small(std::max(1, cvRound(gray.cols * options_.scale)),
                         std::max(1, cvRound(gray.rows * options_.scale)));
    cv::Mat result;
    cv::resize(gray, result, small, 0, 0, cv::INTER_AREA);
    if (imageSize_ != gray.size()) {
        states_.clear();
        lastDetectionMs_ = -1;
        imageSize_ = gray.size();
    }
    return result;
}

void TemplateTracker::correct(const cv::Mat& gray,
                              const std::vector<ObjectDetection>& detections,
                              int64_t timeMs) {
    timing_ = {};
    const cv::Mat small = prepare(gray, timeMs);
    CostScope cost{timing_.correctMs};
    struct Candidate {
        ObjectDetection det;
        cv::Mat patch, detail, fullAnchor;
        cv::Rect2f region;
    };
    std::vector<ObjectDetection> ordered;
    ordered.reserve(detections.size());
    for (auto det : detections) {
        if (!validBox(det.box) || !std::isfinite(det.score)) continue;
        det.box = clip(det.box, imageSize_);
        if (det.box.area() > 0) ordered.push_back(det);
    }
    std::stable_sort(ordered.begin(), ordered.end(), [](const auto& a, const auto& b) {
        return a.score > b.score;
    });
    std::vector<Candidate> candidates;
    for (const auto& det : ordered) {
        const cv::Rect roi = scaledRect(det.box, imageSize_, small.size());
        if (!textured(small(roi), options_.minimumTextureStdDev)) continue;
        cv::Mat patch = boundedPatch(small(roi), options_.maxTemplateSide);
        // Texture was validated before compression. Area averaging can lower
        // random-texture deviation below the original-image threshold at cap16.
        if (!textured(patch, options_.maxTemplateSide ? 0.5f :
                      options_.minimumTextureStdDev)) continue;
        cv::Mat detail;
        cv::Mat fullAnchor;
        cv::Rect2f region;
        if (options_.maxTemplateSide) {
            const int side = std::min(32, options_.maxTemplateSide * 2 / 3);
            const cv::Rect full = scaledRect(det.box, gray.size(), gray.size());
            cv::resize(gray(full), fullAnchor, patch.size(), 0, 0, cv::INTER_AREA);
            if (!textured(fullAnchor, 0.5f)) continue;
            const cv::Size size(std::min(side, full.width), std::min(side, full.height));
            cv::Rect part(full.x + (full.width - size.width) / 2,
                          full.y + (full.height - size.height) / 2,
                          size.width, size.height);
            // A flat center must not discard an otherwise textured target.
            double strongest = -1;
            for (const cv::Point& p : {part.tl(), full.tl(),
                 cv::Point(full.x + full.width - size.width, full.y),
                 cv::Point(full.x, full.y + full.height - size.height),
                 cv::Point(full.x + full.width - size.width,
                           full.y + full.height - size.height)}) {
                cv::Scalar mean, deviation;
                cv::meanStdDev(gray(cv::Rect(p, size)), mean, deviation);
                if (deviation[0] > strongest) {
                    strongest = deviation[0];
                    part = cv::Rect(p, size);
                }
            }
            detail = gray(part).clone();
            region = {part.x - det.box.x, part.y - det.box.y,
                      static_cast<float>(part.width), static_cast<float>(part.height)};
        }
        candidates.push_back({det, std::move(patch), std::move(detail),
                              std::move(fullAnchor), region});
        if (candidates.size() >= static_cast<size_t>(options_.maxTracks)) break;
    }
    struct Pair { float overlap; size_t oldIndex; size_t newIndex; };
    std::vector<Pair> pairs;
    for (size_t old = 0; old < states_.size(); ++old) {
        const auto& s = states_[old];
        if (timeMs - s.detectionMs > options_.maxDetectionAgeMs) continue;
        cv::Rect2f predicted = s.track.box;
        const float dt = static_cast<float>(std::min<int64_t>(100, timeMs - lastFrameMs_));
        predicted.x += s.velocity.x * dt;
        predicted.y += s.velocity.y * dt;
        predicted = clip(predicted, imageSize_);
        for (size_t n = 0; n < candidates.size(); ++n) {
            if (s.track.cls != candidates[n].det.cls) continue;
            const float overlap = iou(predicted, candidates[n].det.box);
            if (overlap >= 0.2f) pairs.push_back({overlap, old, n});
        }
    }
    std::stable_sort(pairs.begin(), pairs.end(), [](const Pair& a, const Pair& b) {
        return a.overlap > b.overlap;
    });
    std::vector<int> associated(candidates.size(), -1);
    std::vector<bool> used(states_.size(), false);
    for (const auto& p : pairs) {
        if (used[p.oldIndex] || associated[p.newIndex] >= 0) continue;
        used[p.oldIndex] = true;
        associated[p.newIndex] = static_cast<int>(p.oldIndex);
    }
    std::vector<State> corrected;
    for (size_t n = 0; n < candidates.size(); ++n) {
        const auto& c = candidates[n];
        State s;
        if (associated[n] >= 0) s.track.id = states_[associated[n]].track.id;
        else s.track.id = allocateId();
        s.track.cls = c.det.cls;
        s.track.detectionScore = c.det.score;
        s.track.box = c.det.box;
        // A detector observation is not an NCC measurement: matchScore stays 0.
        s.appearance = c.patch;
        s.anchor = c.patch.clone();
        s.detail = c.detail;
        s.fullAnchor = c.fullAnchor;
        s.detailRegion = c.region;
        s.observedCenter = center(c.det.box);
        s.detectedSize = c.det.box.size();
        s.observedMs = s.detectionMs = timeMs;
        corrected.push_back(std::move(s));
    }
    states_ = std::move(corrected);
    lastFrameMs_ = lastDetectionMs_ = timeMs;
}

std::vector<Track> TemplateTracker::update(const cv::Mat& gray, int64_t timeMs) {
    timing_ = {};
    const cv::Mat small = prepare(gray, timeMs);
    if (lastFrameMs_ == timeMs) return tracks(timeMs);
    CostScope cost{timing_.matchMs};
    const float sx = static_cast<float>(small.cols) / gray.cols;
    const float sy = static_cast<float>(small.rows) / gray.rows;
    const float dt = lastFrameMs_ < 0 ? 0 :
        static_cast<float>(std::min<int64_t>(100, timeMs - lastFrameMs_));
    std::vector<Observation> observations(states_.size());
    std::vector<cv::Rect2f> predictions(states_.size());
    for (size_t index = 0; index < states_.size(); ++index) {
        const auto& s = states_[index];
        if (timeMs - s.detectionMs > options_.maxDetectionAgeMs) continue;
        const cv::Rect2f previous = s.track.box;
        cv::Rect2f predicted = previous;
        predicted.x += s.velocity.x * dt;
        predicted.y += s.velocity.y * dt;
        // Clamp the whole box rather than shrinking the prediction at edges.
        predicted.x = std::clamp(predicted.x, 0.f, gray.cols - predicted.width);
        predicted.y = std::clamp(predicted.y, 0.f, gray.rows - predicted.height);
        predictions[index] = predicted;
        const bool bounded = options_.maxTemplateSide &&
            (std::max(previous.width * sx, previous.height * sy) * 1.05f >
             options_.maxTemplateSide ||
             std::max(s.detectedSize.width * sx, s.detectedSize.height * sy) >
             baseSide(options_.maxTemplateSide));
        const cv::Rect expected = scaledRect(predicted, imageSize_, small.size());
        int rx = cvRound(std::max(12.f, expected.width * 0.6f) +
                         std::min(s.track.weakFrames, 3) * 4);
        int ry = cvRound(std::max(12.f, expected.height * 0.6f) +
                         std::min(s.track.weakFrames, 3) * 4);
        if (bounded) {
            // Keep measured motion inside the local search uncertainty envelope
            // when a thin object reverses direction. Extra margins cannot exceed
            // the original local radius, and the coarse image remains capped.
            rx += std::min(rx, static_cast<int>(std::ceil(std::abs(predicted.x - previous.x) * sx)));
            ry += std::min(ry, static_cast<int>(std::ceil(std::abs(predicted.y - previous.y) * sy)));
        }
        const cv::Rect window = cv::Rect(expected.x - rx, expected.y - ry,
                                         expected.width + rx * 2, expected.height + ry * 2) &
                                cv::Rect(0, 0, small.cols, small.rows);
        cv::Mat work;
        float wx = 1, wy = 1;
        if (bounded) {
            const double ratio = std::min(1.0, baseSide(options_.maxTemplateSide) /
                double(std::max(previous.width * sx, previous.height * sy)));
            const double ratioX = std::max(ratio,
                std::min(1.0, 4.0 / (previous.width * sx)));
            const double ratioY = std::max(ratio,
                std::min(1.0, 4.0 / (previous.height * sy)));
            const int workBound = static_cast<int>(std::ceil(3.4 * options_.maxTemplateSide + 104));
            cv::resize(small(window), work,
                       {std::clamp(cvRound(window.width * ratioX), 1, workBound),
                        std::clamp(cvRound(window.height * ratioY), 1, workBound)}, 0, 0, cv::INTER_AREA);
            // Actual rounded ROI dimensions, not the requested nominal ratio.
            wx = static_cast<float>(work.cols) / window.width;
            wy = static_cast<float>(work.rows) / window.height;
        }
        std::vector<Observation> peaks;
        std::vector<Observation> coarsePeaks;
        for (float scale : {1.f, 0.95f, 1.05f}) {
            // Prediction can have subpixel coordinates. floor/ceil of its ROI
            // must not inflate the template size on each frame.
            const cv::Size size(cvRound(previous.width * sx * scale),
                                cvRound(previous.height * sy * scale));
            if (size.width / sx < s.detectedSize.width * 0.7f ||
                size.width / sx > s.detectedSize.width * 1.4f ||
                size.height / sy < s.detectedSize.height * 0.7f ||
                size.height / sy > s.detectedSize.height * 1.4f) continue;
            std::vector<Peak> scalePeaks;
            if (!bounded) {
                addPeaks(small, window, s.appearance, size,
                         options_.minimumTextureStdDev, scalePeaks);
                for (const auto& p : scalePeaks)
                    peaks.push_back({{p.box.x / sx, p.box.y / sy,
                                       p.box.width / sx, p.box.height / sy}, p.score, true, p.box, {}});
                continue;
            }
            const cv::Size workingSize(
                std::min(options_.maxTemplateSide, cvRound(previous.width * sx * wx * scale)),
                std::min(options_.maxTemplateSide, cvRound(previous.height * sy * wy * scale)));
            addPeaks(work, cv::Rect({}, work.size()), s.appearance, workingSize,
                     0.5f, scalePeaks);
            std::vector<Observation> candidates;
            for (const auto& p : scalePeaks) {
                const cv::Rect2f box((window.x + p.box.x / wx) / sx,
                                    (window.y + p.box.y / wy) / sy,
                                    previous.width * scale, previous.height * scale);
                coarsePeaks.push_back({box, p.score, false, {}, {}});
                candidates.push_back({box, p.score, false, {}, {}});
            }
            // A very large random patch at cap16 may average almost flat and
            // mix with background on every coarse-grid phase. Prediction is a
            // proposal only; bounded whole-box verification still decides it.
            candidates.push_back({{predicted.x, predicted.y,
                                    previous.width * scale, previous.height * scale},
                                  0.f, false, {}, {}});
            for (const auto& candidate : candidates) {
                cv::Rect2f box = candidate.box;
                // Verify at most nine coarse/prediction candidates. Low caps
                // on huge boxes have coarse cells wider than a 12px fine halo;
                // cover their phase range with tiles, each <=cap+24 per axis.
                if (s.detail.empty()) continue;
                const cv::Rect2f coarseBox = box;
                const float dx = box.width / s.detectedSize.width;
                const float dy = box.height / s.detectedSize.height;
                const cv::Size detailSize(cvRound(s.detail.cols * dx),
                                          cvRound(s.detail.rows * dy));
                if (detailSize.width < 4 || detailSize.height < 4 ||
                    std::max(detailSize.width, detailSize.height) > options_.maxTemplateSide)
                    continue;
                cv::Mat detail;
                cv::resize(s.detail, detail, detailSize, 0, 0, cv::INTER_LINEAR);
                if (!textured(detail, options_.minimumTextureStdDev)) continue;
                const cv::Point2f offset(s.detailRegion.x * dx, s.detailRegion.y * dy);
                const cv::Point origin(cvRound(box.x + offset.x), cvRound(box.y + offset.y));
                const int hx = static_cast<int>(std::ceil(2.f / (sx * wx))) + 2;
                const int hy = static_cast<int>(std::ceil(2.f / (sy * wy))) + 2;
                // Clip candidate top-left range so the WHOLE output box fits.
                // This also prevents a fine match from shrinking a box at edges.
                const int left = std::max({origin.x - hx, 0,
                                          static_cast<int>(std::ceil(offset.x))});
                const int top = std::max({origin.y - hy, 0,
                                         static_cast<int>(std::ceil(offset.y))});
                const int right = std::min({origin.x + hx, gray.cols - detailSize.width,
                    static_cast<int>(std::floor(gray.cols - box.width + offset.x))});
                const int bottom = std::min({origin.y + hy, gray.rows - detailSize.height,
                    static_cast<int>(std::floor(gray.rows - box.height + offset.y))});
                if (right < left || bottom < top) continue;
                for (int tileY = top; tileY <= bottom; tileY += 25) {
                    for (int tileX = left; tileX <= right; tileX += 25) {
                        const int endX = std::min(right, tileX + 24);
                        const int endY = std::min(bottom, tileY + 24);
                        cv::Mat response;
                        cv::matchTemplate(gray(cv::Rect(tileX, tileY,
                            endX - tileX + detailSize.width, endY - tileY + detailSize.height)),
                            detail, response, cv::TM_CCOEFF_NORMED);
                        cv::patchNaNs(response, -1);
                        for (int n = 0; n < 2; ++n) {
                            double score;
                            cv::Point location;
                            cv::minMaxLoc(response, nullptr, &score, nullptr, &location);
                            if (!std::isfinite(score) || score < -0.5) break;
                            box.x = tileX + location.x - offset.x;
                            box.y = tileY + location.y - offset.y;
                            // Detail proposes locations; the capped whole-box
                            // anchor must independently support acceptance.
                            if (score >= options_.matchThreshold && !s.fullAnchor.empty()) {
                                cv::Mat full, fullScore;
                                cv::resize(gray(scaledRect(box, gray.size(), gray.size())), full,
                                           s.fullAnchor.size(), 0, 0, cv::INTER_AREA);
                                if (textured(full, 0.5f)) {
                                    cv::matchTemplate(full, s.fullAnchor, fullScore,
                                                      cv::TM_CCOEFF_NORMED);
                                    const float support = fullScore.at<float>(0, 0);
                                    if (std::isfinite(support))
                                        peaks.push_back({box, std::min(static_cast<float>(score), support),
                                            true, scaledRect(box, imageSize_, small.size()), coarseBox});
                                }
                            }
                            // Keep distinct detail phases, including period4 +/-8px.
                            const cv::Rect suppress = cv::Rect(location.x - 2, location.y - 2,
                                5, 5) & cv::Rect({}, response.size());
                            response(suppress).setTo(-1);
                        }
                    }
                }
            }
        }
        std::stable_sort(coarsePeaks.begin(), coarsePeaks.end(),
                         [](const Observation& a, const Observation& b) {
            return a.score > b.score;
        });
        // Strong near-equal far coarse peaks are already ambiguous. Detail
        // phase/texture cannot erase this evidence. Lower-scoring compressed
        // random textures still get their bounded fine verification.
        const bool coarseAmbiguous = !coarsePeaks.empty() &&
            coarsePeaks[0].score >= options_.matchThreshold &&
            !uniquePeak(coarsePeaks, options_.matchThreshold, sx, sy);
        std::stable_sort(peaks.begin(), peaks.end(), [](const Observation& a, const Observation& b) {
            return a.score > b.score;
        });
        if (!peaks.empty()) observations[index] = peaks[0];
        observations[index].accepted = !coarseAmbiguous &&
            uniquePeak(peaks, options_.matchThreshold, sx, sy) &&
            textured(small(observations[index].sampleBox),
                     options_.minimumTextureStdDev);
    }
    // A same-class observation may be claimed once. Rank by NCC before any
    // velocity/appearance mutation. High overlap alone is not enough: retain
    // distinct centers (including genuinely overlapping detector targets).
    std::vector<size_t> ranked;
    for (size_t i = 0; i < states_.size(); ++i)
        if (observations[i].accepted) ranked.push_back(i);
    std::stable_sort(ranked.begin(), ranked.end(), [&](size_t a, size_t b) {
        return observations[a].score > observations[b].score;
    });
    for (size_t n = 0; n < ranked.size(); ++n) {
        const size_t winner = ranked[n];
        if (!observations[winner].accepted) continue;
        for (size_t m = n + 1; m < ranked.size(); ++m) {
            const size_t other = ranked[m];
            if (states_[winner].track.cls != states_[other].track.cls) continue;
            const auto& a = observations[winner].box;
            const auto& b = observations[other].box;
            const cv::Point2f distance = center(a) - center(b);
            const float tolerance = std::max(2.f, std::min({a.width, a.height,
                                                           b.width, b.height}) * 0.01f);
            if (iou(a, b) >= 0.85f && std::abs(distance.x) <= tolerance &&
                std::abs(distance.y) <= tolerance)
                observations[other].accepted = false;
        }
    }
    for (size_t index = 0; index < states_.size(); ++index) {
        auto& s = states_[index];
        if (timeMs - s.detectionMs > options_.maxDetectionAgeMs) continue;
        const auto& best = observations[index];
        s.track.matchScore = std::clamp(best.score, 0.f, 1.f);
        if (best.accepted) {
            s.track.box = clip(best.box, imageSize_);
            const cv::Point2f nowCenter = center(s.track.box);
            if (timeMs > s.observedMs) {
                const cv::Point2f measured = (nowCenter - s.observedCenter) *
                    (1.f / static_cast<float>(timeMs - s.observedMs));
                s.velocity = s.velocity * 0.5f + measured * 0.5f;
            }
            s.observedCenter = nowCenter;
            s.observedMs = timeMs;
            s.track.weakFrames = 0;
            s.track.predicted = false;
            s.stableFrames = best.score >= options_.updateThreshold ?
                std::min(3, s.stableFrames + 1) : 0;
            // Only adapt after stable strong matches that also agree with the
            // immutable detection anchor. Replace Mat storage, never alias pixels.
            if (s.stableFrames >= 3) {
                cv::Mat patch, anchorScore;
                cv::resize(small(best.sampleBox), patch,
                           s.anchor.size(), 0, 0, cv::INTER_AREA);
                cv::matchTemplate(patch, s.anchor, anchorScore, cv::TM_CCOEFF_NORMED);
                if (anchorScore.at<float>(0, 0) >= options_.updateThreshold) {
                    cv::Mat adapted, old;
                    cv::resize(s.appearance, old, patch.size(), 0, 0, cv::INTER_LINEAR);
                    cv::addWeighted(old, 0.98, patch, 0.02, 0, adapted);
                    s.appearance = std::move(adapted);
                }
            }
        } else {
            s.track.box = predictions[index];
            s.track.predicted = true;
            ++s.track.weakFrames;
            s.stableFrames = 0;
        }
    }
    states_.erase(std::remove_if(states_.begin(), states_.end(), [&](const State& s) {
        return timeMs - s.detectionMs > options_.maxDetectionAgeMs ||
               s.track.weakFrames > options_.maxWeakFrames;
    }), states_.end());
    lastFrameMs_ = timeMs;
    return tracks(timeMs);
}

std::vector<Track> TemplateTracker::tracks(int64_t timeMs) const {
    validateTime(timeMs);
    std::vector<Track> result;
    for (const auto& s : states_) {
        if (timeMs - s.detectionMs <= options_.maxDetectionAgeMs &&
            s.track.weakFrames <= options_.maxWeakFrames) {
            Track value = s.track;
            value.validUntilMs = s.detectionMs + options_.maxDetectionAgeMs;
            // 该框自身最后一次真实观测的时刻（correct 的检测时刻或 update 的模板匹配时刻），
            // 用于给下游运动估计提供观测时间；预测帧不刷新它。
            value.observedMs = s.observedMs;
            result.push_back(value);
        }
    }
    return result;
}

bool TemplateTracker::needsDetection(int64_t timeMs) const {
    validateTime(timeMs);
    if (lastDetectionMs_ < 0 ||
        timeMs - lastDetectionMs_ >= std::min(500, options_.maxDetectionAgeMs)) return true;
    const auto live = tracks(timeMs);
    return live.empty() || std::any_of(live.begin(), live.end(), [](const Track& t) {
        return t.weakFrames > 0 || t.predicted;
    });
}

} // namespace tdm
