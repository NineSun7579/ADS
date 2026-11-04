#include "vision_pipeline.h"
#include "template_tracker.h"
#include "inference_cadence.h"
#include "infer_age.h"
#include "four_fair.h"
#include "stereo_demo/stereo_depth.h"

#include <QElapsedTimer>
#include <QMutex>
#include <QMutexLocker>
#include <QWaitCondition>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <deque>
#include <iterator>
#include <map>
#include <optional>
#include <set>
#include <tuple>
#include <stdexcept>
#include <vector>
#include <time.h>

namespace {
qint64 monotonicMs() {
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return qint64(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
}
cv::Mat gray(const VisionFrame& f) {
    cv::Mat rgb(f.image.height(), f.image.width(), CV_8UC3,
                const_cast<uchar*>(f.image.constBits()), f.image.bytesPerLine());
    cv::Mat result;
    cv::cvtColor(rgb, result, cv::COLOR_RGB2GRAY);
    return result;
}
tdm::TrackerOptions trackerOptions(const VisionOptions& options, int limit) {
    tdm::TrackerOptions result;
    result.maxTracks = std::clamp(limit, 1, 12);
    result.maxDetectionAgeMs = std::max(1, options.trackingMaxDetectionAgeMs);
    result.maxTemplateSide = options.maxTemplateSide;
    return result;
}
cv::Rect2f rawBox(const Detection& v) {
    return cv::Rect2f(v.x1, v.y1 - 80, v.x2 - v.x1, v.y2 - v.y1);
}
bool nearBox(const cv::Rect2f& a, const cv::Rect2f& b) {
    const float area = (a & b).area();
    const float combined = a.area() + b.area() - area;
    return combined > 0 && area / combined >= 0.7f &&
           cv::norm((a.tl() + a.br()) * 0.5f - (b.tl() + b.br()) * 0.5f) <=
               std::max(4.0f, std::min(a.width, a.height) * 0.15f);
}
}

struct VisionPipeline::Impl {
    explicit Impl(VisionPipeline* owner, VisionOptions value)
        : q(owner), options(std::move(value)) {
        if (options.trackingIntervalMs < 0 || options.trackingIntervalMs > 200)
            throw std::invalid_argument("trackingIntervalMs must be 0..200");
        if (options.maxTemplateSide != 0 && (options.maxTemplateSide < 16 || options.maxTemplateSide > 128))
            throw std::invalid_argument("maxTemplateSide must be 0 or 16..128");
        asyncEnabled = qEnvironmentVariableIsSet("ADS_TRUE_ASYNC") &&
            !options.tracking && options.stereoPairs().empty();
        asyncCapacity = std::clamp(qEnvironmentVariableIntValue("ADS_ASYNC_INFLIGHT"), 1, 4);
        if (!asyncEnabled) asyncCapacity = 1;
        stereoMask = options.stereoCameraMask();
        for (const auto& pair : options.stereoPairs()) {
            auto state = std::make_unique<StereoState>();
            state->options = pair;
            stereoStates.push_back(std::move(state));
        }
    }
    VisionPipeline* q;
    VisionOptions options;
    struct Config {
        quint64 epoch = 0;
        int generation = 0, camera = 0;
        bool lane = false;
        bool fourCamera = false;
        bool motionEnabled = false;
        QStringList models;
        QHash<QString, QVector<int>> vehicleClasses;
    } config, active;
    struct Pending {
        quint64 epoch = 0, frameId = 0;
        int generation = 0;
        qint64 sentMs = 0;
        qint64 capturedMs = -1; // source time survives history eviction; never renew TTL on reply
        int camera = -1;
        quint32 tag = 0;
        std::shared_ptr<scheme2::Input> input;
        motion::Reason reason = motion::Reason::Legacy;
        acquisition::Ticket acquisition;
        bool syntheticBlack=false;
    };
    struct Reply {
        Pending request;
        QString model;
        QVector<Detection> detections;
        double inferMs = 0;
    };
    QMutex mutex;
    QWaitCondition changed;
    const bool eventSchedule = qgetenv("ADS_EVENT_SCHEDULE") == "1";
    const bool asyncDebug=qEnvironmentVariableIsSet("ADS_ASYNC_DEBUG");
    quint64 wakeSequence = 0; // protected by mutex; events during work must not be lost
    qint64 retryAtMs = -1; // worker-only policy deadline
    bool stopping = false;
    // Only selected/configured stereo cameras are accepted; at most two owned frames
    // per camera. Replacements never form a queued Qt invocation per frame.
    std::map<int, std::deque<VisionFrame>> frameSlots;
    std::optional<VisionFrame> prefetchedInput; // exact inference identity, independent of latest RAW
    static void cancelUnsubmitted(const VisionFrame& frame) {
        if (frame.fpgaInput && !frame.fpgaInput->dispatched.exchange(true)) frame.fpgaInput->complete();
    }
    void cancelPrefetch() {
        if (prefetchedInput) cancelUnsubmitted(*prefetchedInput);
        prefetchedInput.reset();
    }
    std::map<int, quint64> highWater;
    std::optional<Pending> pending;
    std::optional<Reply> reply;
    FourFair fourFair;
    std::optional<Pending> fourBusy; // Physical job survives page/source invalidation.
    std::array<quint64,4> fourCompleted{}, fourBlackCompleted{};
    qint64 fourLastMs=-1;
    // Camera DMA remains independent from analytics. Owned RAW RGB images use
    // the existing conventional RKNN context, including cameras without coherent
    // FPGA RGB support. This never holds the display/HDMI physical input lease.
    void fourWork(qint64 now) {
        std::optional<VisionFrame> dispatch;
        quint64 epoch=0;
        {
            QMutexLocker lock(&mutex);
            if(stopping || !config.fourCamera || config.models.empty()) return;
            if(pending || fourBusy) return; // Never time out into a second RKNN request.
            if(fourLastMs>=0 && now-fourLastMs<std::max(1,options.minimumDetectionIntervalMs)) return;
            unsigned ready=0;
            for(int i=0;i<4;++i) {
                const auto it=frameSlots.find(FourFair::cameras[i]);
                if(it==frameSlots.end() || it->second.empty()) continue;
                auto& f=it->second.back();
                if(f.fpgaInput && (now<f.capturedMs || now-f.capturedMs>500)) {
                    cancelUnsubmitted(f); f.fpgaInput.reset();
                }
                if(f.sourceGeneration==config.generation && acquisition::current(f.acquisition) &&
                   f.frameId>submittedThrough[{config.generation,f.camera}] &&
                   now>=f.capturedMs && now-f.capturedMs<=500) {
                    ready|=1u<<i;
                }
            }
            const int i=fourFair.choose(ready);
            if(i<0) return; // No fresh physical input: no RKNN job or throughput credit.
            VisionFrame f;
            if(ready&(1u<<i)) {
                f=frameSlots[FourFair::cameras[i]].back();
                cancelUnsubmitted(f);f.fpgaInput.reset();
                submittedThrough[{config.generation,f.camera}]=f.frameId;
                while(submittedThrough.size()>24)submittedThrough.erase(submittedThrough.begin());
            }
            Pending p{config.epoch,f.frameId,config.generation,now,f.capturedMs,f.camera,f.tag,{}};
            p.acquisition=f.acquisition;p.syntheticBlack=f.syntheticBlack;pending=p;fourBusy=p;epoch=config.epoch;
            dispatch=f;fourFair.commit(i);fourLastMs=now;
            fprintf(stderr,"[four-infer] event=request camera=%d generation=%d job=%llu source=%s padding=%d source_tag=%u captured_ms=%lld issued=%llu acquisition_mask=%u epoch=%llu\n",
                f.camera+1,f.sourceGeneration,(unsigned long long)f.frameId,f.syntheticBlack?"synthetic_black":"camera",int(f.syntheticBlack),f.tag,(long long)f.capturedMs,
                (unsigned long long)fourFair.issued[i],f.acquisition.mask,(unsigned long long)epoch);
        }
        // Controller strips this marker to epoch=0 for synchronous RKNN inside
        // its worker; GUI delivery can identify and ignore the same request.
        if(dispatch && live(epoch)) emit q->inferenceRequested(*dispatch,VisionPipeline::FourRequest);
        else if(dispatch) {
            if(dispatch->fpgaInput) dispatch->fpgaInput->complete();
            QMutexLocker lock(&mutex);
            if(fourBusy && fourBusy->frameId==dispatch->frameId && fourBusy->generation==dispatch->sourceGeneration)fourBusy.reset();
        }
    }
    // Opt-in true async: identity-matched requests and one queued reply per
    // frame. The default single-slot path below remains byte-for-byte behavior.
    bool asyncEnabled = false;
    int asyncCapacity = 1;
    std::map<quint64, Pending> inflight;
    std::set<std::tuple<quint64,int,quint64>> expiredAsync;
    std::deque<quint64> submissionOrder;
    std::deque<Reply> replies;
    quint64 replySequence = 0;
    std::optional<Pending> oldestPending() const {
        for (quint64 id : submissionOrder) {
            const auto found = inflight.find(id);
            if (found != inflight.end()) return found->second;
        }
        return {};
    }
    void eraseOldestPending() {
        if (submissionOrder.empty()) return;
        inflight.erase(submissionOrder.front());
        submissionOrder.pop_front();
    }
    void erasePendingId(quint64 id) {
        inflight.erase(id);
        submissionOrder.erase(std::remove(submissionOrder.begin(),submissionOrder.end(),id),submissionOrder.end());
    }
    quint64 lastDeliveredFrame = 0;
    int outstanding() const { return int(inflight.size()); }
    void retireInflight(quint64 frameId) { erasePendingId(frameId); }
    void resetAsync() {
        inflight.clear(); submissionOrder.clear(); replies.clear(); expiredAsync.clear(); lastDeliveredFrame = 0;
    }
    // A frame identity is submitted once even across configure/timeout. This
    // also prevents a late reply from identifying a newer request for that frame.
    std::map<std::pair<int, int>, quint64> submittedThrough; // generation, camera

    struct History {
        VisionFrame frame;
        cv::Mat gray;
        std::map<QString, tdm::TemplateTracker> snapshots;
    };
    std::deque<History> history;
    acquisition::Ticket currentAcquisition;
    quint64 replayRejectedThrough = 0;
    std::function<void(int)> selfTestHook; // null in production; installed before start
    std::function<qint64()> selfTestClock; // private deterministic fixture seam; null in production
    qint64 clockMs() const { return selfTestClock ? selfTestClock() : monotonicMs(); }
    const History* processedSource(const VisionFrame& frame) const {
        for (const auto& h : history) {
            if (h.frame.camera != frame.camera || h.frame.sourceGeneration != frame.sourceGeneration ||
                h.frame.frameId != frame.frameId || h.frame.tag != frame.tag ||
                h.frame.capturedMs != frame.capturedMs || h.frame.fpgaInput != frame.fpgaInput ||
                h.frame.image.constBits() != frame.image.constBits()) continue;
            if (!trackers.empty() && h.gray.empty()) return nullptr;
            for (const auto& tracker : trackers)
                if (h.snapshots.find(tracker.first) == h.snapshots.end()) return nullptr;
            return &h;
        }
        return nullptr;
    }
    std::map<QString, tdm::TemplateTracker> trackers;
    std::map<QString, int> trackBudgets;
    std::map<QString, bool> lost;
    std::map<QString, int> publishedCounts;
    std::map<QString, int> publishedDepthCounts;
    std::map<QString, QStringList> publishedDepthStatuses;
    struct RawState {
        Pending source;
        QVector<Detection> boxes; // raw nonvehicles and untracked vehicle fallbacks
    };
    std::map<QString, RawState> nonvehicles;
    struct Depth {
        double meters = 0;
        qint64 capturedMs = 0;
        cv::Rect2f box;
        bool trial = false;
        QString status;
    };
    struct StereoState {
        StereoPairOptions options;
        std::map<std::pair<QString, uint64_t>, Depth> depths;
        struct CachedResult {
            quint64 frameId = 0;
            int generation = 0;
            qint64 capturedMs = 0, pairCapturedMs = 0, finishedMs = 0;
            stereo::DepthResult result; // compute() returns owned matrices; retain at most two.
            acquisition::Ticket acquisition;
        };
        std::deque<CachedResult> results;
        acquisition::Ticket acquisition;
        quint64 pairedLeft = 0, pairedRight = 0;
        qint64 lastPreviewMs = -1, lastAttemptMs = -1;
        qint64 lastPairCapturedMs = -1; // oldest host capture in the latest attempted pair
        struct Window {
            quint64 computeSuccess = 0, computeFailure = 0, noFreshPairPolls = 0;
            double computeTotalMs = 0, computeMaxMs = 0;
        } window;
        bool staleReported = false;
        stereo::Calibration calibration;
        // The calibration address given to DepthEngine remains stable.
        std::unique_ptr<stereo::DepthEngine> engine;
        cv::Mat roiRotation, roiProjection;
        bool calibrated = false;
        QString calibrationStatus;
        void resetRuntime() {
            depths.clear(); results.clear(); pairedLeft = pairedRight = 0;
            lastPreviewMs = lastAttemptMs = -1; staleReported = false;
            lastPairCapturedMs = -1;
        }
    };
    std::vector<std::unique_ptr<StereoState>> stereoStates;
    quint32 stereoMask = 0;
    size_t nextStereo = 0;
    quint64 currentFrame = 0;
    qint64 currentCapturedMs = -1;
    qint64 lastRequestMs = -1, lastStereoFinishedMs = -1;
    quint64 staticDeferred=0, motionCompleted=0, fallbackCompleted=0, periodicCompleted=0;
    quint64 lastDeferredFrame=0;
    qint64 lastDiagnosticMs = -1;
    qint64 stereoWindowStartMs = -1;
    int requests = 0, matchedFrames = 0;
    double matchTotalMs = 0;
    struct Cost {
        double sumMs = 0;
        quint64 count = 0;
        void add(double ms) { sumMs += ms; ++count; }
        QString text() const { return QStringLiteral("%1/%2").arg(sumMs, 0, 'f', 2).arg(count); }
    };
    struct PerfWindow {
        quint64 rejectUnprocessed = 0, replayOverflowRetirements = 0, historyPeak = 0;
        Cost gray, snapshot, prepare, match, correct, replay;
        quint64 rejectPending = 0, rejectInterval = 0, rejectDuplicate = 0;
        quint64 rejectConfig = 0, rejectStale = 0, rejectNewer = 0;
        quint64 newerSnapshotRequests = 0, skippedTrackingFrames = 0;
    } perf;
    qint64 perfWindowStartMs = -1;
    quint64 lastSkippedFrame = 0;

    void recordTiming(const tdm::TemplateTracker& tracker, bool correction = false) {
        const auto& timing = tracker.lastTiming();
        perf.prepare.add(timing.prepareMs);
        if (correction) perf.correct.add(timing.correctMs);
        else perf.match.add(timing.matchMs);
    }
    cv::Mat measuredGray(const VisionFrame& frame) {
        QElapsedTimer elapsed; elapsed.start();
        auto result = gray(frame);
        perf.gray.add(elapsed.nsecsElapsed() / 1e6);
        return result;
    }
    struct OutputCounts { int vehicles = 0, nonvehicles = 0, raw = 0; };
    OutputCounts outputCounts(qint64 now) const {
        OutputCounts counts;
        if (currentCapturedMs < 0) return counts;
        const qint64 time = std::max(currentCapturedMs, now);
        for (const auto& item : trackers) counts.vehicles += int(item.second.tracks(time).size());
        for (const auto& item : nonvehicles) {
            const auto classes = active.vehicleClasses.value(item.first);
            for (const auto& d : item.second.boxes) if (time <= d.validUntilMs) {
                ++counts.raw;
                if (!classes.contains(d.cls)) ++counts.nonvehicles;
            }
        }
        return counts;
    }

    StereoState* selectedStereo() {
        for (auto& state : stereoStates)
            if (state->options.left == active.camera) return state.get();
        return nullptr; // right cameras never receive left-image target depth
    }
    StereoState* previewStereo() {
        if (active.camera < 0) return stereoStates.empty() ? nullptr : stereoStates.front().get();
        for (auto& state : stereoStates)
            if (state->options.left == active.camera || state->options.right == active.camera)
                return state.get();
        return nullptr;
    }

    bool live(quint64 epoch) {
        QMutexLocker lock(&mutex);
        return !stopping && config.epoch == epoch;
    }
    void reset(const Config& value) {
        // Replies belonging to an older configuration must never reach the
        // new model, tracker or stereo state, including queued replies.
        for (const auto& h : history) cancelUnsubmitted(h.frame);
        active = value;
        // Async is deliberately limited to the pure detector/lane path. The
        // tracker, stereo source replay and their timing contracts stay on the
        // established synchronous state machine.
        asyncEnabled = qEnvironmentVariableIsSet("ADS_TRUE_ASYNC") &&
            !options.tracking && stereoStates.empty();
        replayRejectedThrough = 0;
        trackers.clear(); trackBudgets.clear(); lost.clear(); publishedCounts.clear(); history.clear();
        nonvehicles.clear(); publishedDepthCounts.clear(); publishedDepthStatuses.clear(); lastSkippedFrame = 0;
        for (auto& state : stereoStates) state->resetRuntime();
        currentFrame = 0; currentCapturedMs = -1;
        currentAcquisition={};
        lastRequestMs = lastStereoFinishedMs = -1;
        nextStereo = 0;
        // Start with the displayed pair, then rotate fairly among ready groups.
        for (size_t i = 0; i < stereoStates.size(); ++i)
            if (stereoStates[i].get() == previewStereo()) { nextStereo = i; break; }
        const int total = std::clamp(options.maxTracks, 1, 12);
        QStringList vehicleModels;
        if (options.tracking && !active.lane)
            for (const auto& model : active.models)
                if (!active.vehicleClasses.value(model).isEmpty()) vehicleModels.push_back(model);
        const int count = vehicleModels.size();
        for (int i = 0; i < count; ++i) {
            const int bound = total / count + (i < total % count ? 1 : 0);
            trackBudgets[vehicleModels[i]] = bound;
            if (bound > 0)
                trackers.emplace(vehicleModels[i], tdm::TemplateTracker(trackerOptions(options, bound)));
        }
    }
    void sweepAcquisition() {
        {QMutexLocker lock(&mutex);
         for(auto& entry:frameSlots) {
             auto& frames=entry.second;
             for(auto it=frames.begin();it!=frames.end();) {
                 if(!acquisition::current(it->acquisition)){cancelUnsubmitted(*it);it=frames.erase(it);}else ++it;
             }
         }
         if(prefetchedInput&&!acquisition::current(prefetchedInput->acquisition))cancelPrefetch();
         if(pending&&!acquisition::current(pending->acquisition))pending.reset();
         if(reply&&!acquisition::current(reply->request.acquisition))reply.reset();
         for(auto it=inflight.begin();it!=inflight.end();) {
             if(!acquisition::current(it->second.acquisition)){const auto id=it->first;erasePendingId(id);it=inflight.begin();}else ++it;
         }
         replies.erase(std::remove_if(replies.begin(),replies.end(),[](const Reply& value){return !acquisition::current(value.request.acquisition);}),replies.end());}
        if(!acquisition::current(currentAcquisition)) {
            history.clear();nonvehicles.clear();publishedCounts.clear();publishedDepthCounts.clear();publishedDepthStatuses.clear();
            for(auto& item:trackers)item.second=tdm::TemplateTracker(trackerOptions(options,trackBudgets[item.first]));
            currentFrame=0;currentCapturedMs=-1;currentAcquisition={};lastRequestMs=-1;
        }
        history.erase(std::remove_if(history.begin(),history.end(),[](const History& value){return !acquisition::current(value.frame.acquisition);}),history.end());
        for(auto& state:stereoStates)if(!acquisition::current(state->acquisition))state->resetRuntime();
    }
    void prepareStereo() {
        for (auto& state : stereoStates) prepareStereo(*state);
    }
    void prepareStereo(StereoState& state) {
        stereo::MatcherOptions matcher;
        matcher.scale = options.stereoScale;
        matcher.numDisparities = options.stereoDisparities;
        auto& calibration = state.calibration;
        auto& engine = state.engine;
        auto& calibrated = state.calibrated;
        auto& calibrationStatus = state.calibrationStatus;
        calibrationStatus = QStringLiteral("not calibrated");
        try {
            if (!state.options.calibrationPath.isEmpty()) {
                calibration = stereo::Calibration::load(state.options.calibrationPath.toStdString());
                if (calibration.imageSize != cv::Size(640, 480))
                    throw std::invalid_argument("calibration image size must be 640x480");
                engine.reset(new stereo::DepthEngine(matcher, &calibration));
                const cv::Size size(cvRound(640 * matcher.scale), cvRound(480 * matcher.scale));
                cv::Mat k1 = calibration.K1.clone(), k2 = calibration.K2.clone();
                for (int x = 0; x < 3; ++x) {
                    k1.at<double>(0, x) *= double(size.width) / calibration.imageSize.width;
                    k1.at<double>(1, x) *= double(size.height) / calibration.imageSize.height;
                    k2.at<double>(0, x) *= double(size.width) / calibration.imageSize.width;
                    k2.at<double>(1, x) *= double(size.height) / calibration.imageSize.height;
                }
                cv::Mat r2, p2, Q;
                cv::stereoRectify(k1, calibration.D1, k2, calibration.D2, size,
                    calibration.R, calibration.T, state.roiRotation, r2, state.roiProjection, p2, Q,
                    0, 0.0, size);
                calibrated = true;
                calibrationStatus = QStringLiteral("calibrated");
                return;
            }
        } catch (const std::exception& e) {
            calibrationStatus = QStringLiteral("not calibrated: %1").arg(QString::fromUtf8(e.what()));
        }
        calibrated = false;
        try { engine.reset(new stereo::DepthEngine(matcher)); }
        catch (const std::exception& e) {
            engine.reset();
            calibrationStatus = QStringLiteral("stereo unavailable: %1").arg(QString::fromUtf8(e.what()));
        }
    }
    void prune(qint64 now) {
        perf.historyPeak = std::max(perf.historyPeak, quint64(history.size()));
        // Retain the exact FPGA correction source and its replay suffix for its
        // existing 1s reply TTL. Cap storage even with unusually fast ingress.
        auto retained = history.end();
        for (auto it = history.begin(); it != history.end(); ++it)
            if (it->frame.fpgaInput && it->frame.frameId > replayRejectedThrough &&
                now - it->frame.capturedMs <= 1000) retained = it;
        if (retained != history.end() && std::distance(retained, history.end()) > 64) {
            // Never correct through a deliberately evicted replay sample. Retire
            // an unsubmitted source, or reject its outstanding reply, then resume
            // ordinary bounded history. The live tracker itself is untouched.
            replayRejectedThrough = retained->frame.frameId;
            cancelUnsubmitted(retained->frame);
            QMutexLocker lock(&mutex);
            if (prefetchedInput && prefetchedInput->fpgaInput == retained->frame.fpgaInput) cancelPrefetch();
            if (pending && pending->input == retained->frame.fpgaInput) pending.reset();
            if (reply && reply->request.input == retained->frame.fpgaInput) reply.reset();
            ++perf.replayOverflowRetirements;
            retained = history.end();
        }
        const size_t limit = retained != history.end() ? 64 : 8;
        while (!history.empty() && (history.size() > limit ||
                now - history.front().frame.capturedMs > 1000)) {
            cancelUnsubmitted(history.front().frame); history.pop_front();
        }
        for (auto& state : stereoStates) {
            while (!state->results.empty() && (state->results.size() > 2 ||
                   now - state->results.front().pairCapturedMs > 300)) state->results.pop_front();
            if (state.get() != selectedStereo()) { state->depths.clear(); continue; }
            auto& depths = state->depths;
            for (auto it = depths.begin(); it != depths.end();) {
                if (now - it->second.capturedMs > 300) it = depths.erase(it);
                else ++it;
            }
        }
    }
    QVector<Detection> detectionsFor(const QString& model, qint64 time, qint64 now) {
        QVector<Detection> result;
        auto modelIt = trackers.find(model);
        if (modelIt != trackers.end()) for (const auto& track : modelIt->second.tracks(time)) {
            Detection d;
            d.cls = track.cls; d.score = track.detectionScore;
            d.x1 = track.box.x; d.x2 = track.box.x + track.box.width;
            d.y1 = track.box.y + 80; d.y2 = track.box.y + track.box.height + 80;
            d.trackId = track.id; d.matchScore = track.matchScore; d.predicted = track.predicted;
            d.validUntilMs = track.validUntilMs;
            d.observedMs = track.observedMs;
            auto* state = selectedStereo();
            if (state) {
                d.depthStatus = vehicleDepthStatus(*state);
                auto& depths = state->depths;
                auto depth = depths.find({model, track.id});
                if (depth != depths.end()) {
                    const qint64 age = now - depth->second.capturedMs;
                    if (age >= 0 && age <= 300 && nearBox(track.box, depth->second.box)) {
                        d.depthStatus = depth->second.status;
                        if (std::isfinite(depth->second.meters)) {
                            d.depthMeters = depth->second.meters; d.depthAgeMs = int(age);
                            d.depthCapturedMs = depth->second.capturedMs; d.depthTrial = depth->second.trial;
                        }
                    } else depths.erase(depth);
                }
            }
            result.push_back(d);
        }
        auto raw = nonvehicles.find(model);
        if (raw != nonvehicles.end())
            for (auto& d : raw->second.boxes) if (time <= d.validUntilMs) {
                if (d.depthStatus == QStringLiteral("有效视差不足")) {
                    auto* state = selectedStereo();
                    const auto& source = raw->second.source;
                    if (!state || !sourceResult(*state, source.frameId, source.generation, source.capturedMs, now))
                        d.depthStatus = QStringLiteral("等待同帧双目");
                }
                if (std::isfinite(d.depthMeters)) {
                    const qint64 age = now - d.depthCapturedMs;
                    if (age < 0 || age > 300) {
                        clearDepth(d); d.depthStatus = QStringLiteral("等待同帧双目");
                    } else d.depthAgeMs = int(age);
                }
                result.push_back(d);
            }
        return result;
    }
    int depthCount(const QVector<Detection>& boxes) const {
        return int(std::count_if(boxes.begin(), boxes.end(), [](const Detection& d) {
            return std::isfinite(d.depthMeters);
        }));
    }
    QStringList depthStatuses(const QVector<Detection>& boxes) const {
        QStringList result;
        for (const auto& d : boxes) result.push_back(d.depthStatus);
        return result;
    }
    void publish(const QString& model, double ms, qint64 now) {
        if (currentCapturedMs < 0 || !live(active.epoch) || !acquisition::current(currentAcquisition)) return;
        auto boxes = detectionsFor(model, std::max(currentCapturedMs, now), now);
        publishedCounts[model] = boxes.size();
        publishedDepthCounts[model] = depthCount(boxes);
        publishedDepthStatuses[model] = depthStatuses(boxes);
        const auto raw = nonvehicles.find(model);
        const quint64 outputFrame = (!options.tracking || active.lane) && raw != nonvehicles.end() ?
            raw->second.source.frameId : currentFrame;
        const auto ticket=(!options.tracking || active.lane) && raw!=nonvehicles.end()?raw->second.source.acquisition:currentAcquisition;
        if(acquisition::current(ticket)) emit q->tracksReady(model, active.generation, outputFrame, std::move(boxes), ms,ticket);
    }
    void expireFrozenTracks(qint64 now) {
        if (currentCapturedMs < 0) return;
        const qint64 time = std::max(currentCapturedMs, now);
        for (const auto& model : active.models) {
            auto raw = nonvehicles.find(model);
            if (raw != nonvehicles.end()) {
                auto& boxes = raw->second.boxes;
                boxes.erase(std::remove_if(boxes.begin(), boxes.end(),
                    [time](const Detection& d) { return time > d.validUntilMs; }), boxes.end());
            }
            const auto boxes = detectionsFor(model, time, now);
            if (publishedCounts[model] != boxes.size() || publishedDepthCounts[model] != depthCount(boxes) ||
                publishedDepthStatuses[model] != depthStatuses(boxes))
                publish(model, 0, now);
        }
    }
    void acceptReply(const Reply& value, qint64 now) {
        if(!acquisition::current(value.request.acquisition)) return;
        if (value.request.input && value.request.frameId <= replayRejectedThrough) return;
        if (value.request.epoch != active.epoch || value.request.generation != active.generation ||
            !active.models.contains(value.model) || value.request.capturedMs < 0 ||
             now < value.request.capturedMs || now - value.request.capturedMs > 1000) return;
        auto source = std::find_if(history.begin(), history.end(), [&](const History& h) {
            return h.frame.frameId == value.request.frameId &&
                h.frame.sourceGeneration == value.request.generation &&
                h.frame.capturedMs == value.request.capturedMs &&
                (!value.request.input || (h.frame.camera == value.request.camera &&
                 h.frame.tag == value.request.tag && h.frame.fpgaInput == value.request.input));
        });
        if (value.request.input && (source == history.end() ||
            (trackers.find(value.model) != trackers.end() && source->snapshots.find(value.model) == source->snapshots.end())))
            return; // never accept a retained-input reply without its exact correction snapshot
        const qint64 validUntil = value.request.capturedMs + std::max(1, options.trackingMaxDetectionAgeMs);
        if (value.request.reason == motion::Reason::Motion) ++motionCompleted;
        if (value.request.reason == motion::Reason::Fallback) ++fallbackCompleted;
        if (value.request.reason == motion::Reason::Periodic) ++periodicCompleted;
        auto cleanRaw = [validUntil](Detection d) {
            d.trackId = 0; d.predicted = false; d.matchScore = 0;
            d.depthMeters = std::numeric_limits<double>::quiet_NaN(); d.depthAgeMs = 0;
            d.depthCapturedMs = 0; d.validUntilMs = validUntil;
            d.depthTrial = false; d.depthStatus.clear();
            return d;
        };
        const auto classes = active.vehicleClasses.value(value.model);
        QVector<Detection> detections = value.detections;
        if (options.stereoVehicleTrial) {
            int best = -1;
            for (int i = 0; i < detections.size(); ++i)
                if (classes.contains(detections[i].cls) &&
                    (best < 0 || detections[i].score > detections[best].score)) best = i;
            QVector<Detection> selected;
            for (int i = 0; i < detections.size(); ++i)
                if (!classes.contains(detections[i].cls) || i == best) selected.push_back(detections[i]);
            detections = std::move(selected);
        }
        // Presentation observes sanitized copies only. Tracker correction and
        // depth measurement continue to consume the original detector policy.
        QVector<Detection> observed;
        if (now <= validUntil) {
            observed.reserve(detections.size());
            for (const auto& d : detections) observed.push_back(cleanRaw(d));
        }
        emit q->acceptedDetectorResult(value.model, value.request.generation,
                                       value.request.frameId, observed, now,value.request.acquisition);
        tdm::inferAgeEvent("result_accepted", {value.request.frameId, value.request.generation,
            value.request.camera, value.request.tag, value.request.capturedMs});
        // Every authoritative reply invalidates earlier boxes' depth before
        // attempting an exact-source cache lookup, including no-tracking.
        for (auto& state : stereoStates)
            for (auto it = state->depths.begin(); it != state->depths.end();) {
                if (it->first.first == value.model) it = state->depths.erase(it); else ++it;
            }
        if (!options.tracking || active.lane) {
            nonvehicles[value.model] = RawState{value.request, std::move(observed)};
            if (auto* state = selectedStereo()) measureRaw(*state, value.model, now);
            publish(value.model, 0, now);
            return;
        }
        auto target = trackers.find(value.model);
        const bool canCorrect = target != trackers.end() && source != history.end() &&
            source->snapshots.find(value.model) != source->snapshots.end();
        std::vector<tdm::ObjectDetection> input;
        QVector<Detection> raw;
        for (auto d : detections) {
            if (canCorrect && classes.contains(d.cls)) {
                input.push_back({d.cls, d.score, rawBox(d)});
            } else {
                if (now <= validUntil) raw.push_back(cleanRaw(d));
            }
        }
        nonvehicles[value.model] = RawState{value.request, std::move(raw)};
        if (auto* state = selectedStereo()) measureRaw(*state, value.model, now);
        if (!canCorrect) {
            if (target != trackers.end()) target->second.clear();
            for (auto& h : history) {
                auto snapshot = h.snapshots.find(value.model);
                if (snapshot != h.snapshots.end()) snapshot->second.clear();
            }
            lost[value.model] = false;
            publish(value.model, 0, now); return;
        }
        auto original = source->snapshots.find(value.model);
        QElapsedTimer elapsed; elapsed.start();
        QElapsedTimer clone; clone.start();
        tdm::TemplateTracker corrected = original->second; // deep clone
        perf.snapshot.add(clone.nsecsElapsed() / 1e6);
        corrected.correct(source->gray, input, source->frame.capturedMs);
        recordTiming(corrected, true);
        clone.restart();
        source->snapshots.insert_or_assign(value.model, corrected);
        perf.snapshot.add(clone.nsecsElapsed() / 1e6);
        if (auto* state = selectedStereo()) {
            const auto* cached = sourceResult(*state, value.request.frameId,
                value.request.generation, value.request.capturedMs, now);
            if (cached) measureTracks(*state, value.model, corrected, *cached, now);
        }
        QElapsedTimer replay; replay.start();
        for (auto it = std::next(source); it != history.end(); ++it) {
            corrected.update(it->gray, it->frame.capturedMs);
            recordTiming(corrected);
            clone.restart();
            it->snapshots.insert_or_assign(value.model, corrected);
            perf.snapshot.add(clone.nsecsElapsed() / 1e6);
        }
        perf.replay.add(replay.nsecsElapsed() / 1e6);
        target->second = std::move(corrected);
        lost[value.model] = !input.empty() &&
            target->second.tracks(history.back().frame.capturedMs).empty();
        const double ms = elapsed.nsecsElapsed() / 1e6;
        matchTotalMs += ms; ++matchedFrames;
        publish(value.model, ms, now);
    }
    void processFrame(const VisionFrame& frame, qint64 now) {
        if(!acquisition::current(frame.acquisition)) {cancelUnsubmitted(frame);return;}
        if(!acquisition::current(currentAcquisition))sweepAcquisition();
        if (frame.camera != active.camera || frame.frameId <= currentFrame || frame.sourceGeneration != active.generation ||
            now < frame.capturedMs || now - frame.capturedMs > 1000) return;
        if (currentCapturedMs >= 0 && frame.capturedMs < currentCapturedMs) return;
        if (!frame.fpgaInput && options.tracking && !active.lane && currentCapturedMs >= 0 &&
            frame.capturedMs - currentCapturedMs < options.trackingIntervalMs) {
            if (lastSkippedFrame != frame.frameId) {
                ++perf.skippedTrackingFrames; lastSkippedFrame = frame.frameId;
            }
            return;
        }
        History h; h.frame = frame;
        if (!trackers.empty()) h.gray = measuredGray(frame);
        QElapsedTimer elapsed; elapsed.start();
        if (options.tracking && !active.lane) {
            for (auto& item : trackers) {
                const bool hadTracks = currentCapturedMs >= 0 &&
                    !item.second.tracks(currentCapturedMs).empty();
                const auto tracks = item.second.update(h.gray, frame.capturedMs);
                recordTiming(item.second);
                if (hadTracks && tracks.empty()) lost[item.first] = true;
            }
        }
        QElapsedTimer clone; clone.start();
        if (!trackers.empty()) {
            h.snapshots = trackers;
            perf.snapshot.add(clone.nsecsElapsed() / 1e6);
        }
        history.push_back(std::move(h)); currentFrame = frame.frameId;
        currentAcquisition=frame.acquisition;
        currentCapturedMs = frame.capturedMs;
        prune(now);
        const double ms = elapsed.nsecsElapsed() / 1e6;
        if (options.tracking && !active.lane) {
            matchTotalMs += ms; ++matchedFrames;
            for (const auto& model : active.models) publish(model, ms, now);
        }
    }
    void request(qint64 now) {
        {QMutexLocker lock(&mutex);if(fourBusy)return;}
        // Frame processing and reply replay can be expensive. Cadence must use
        // the time at submission, not the loop timestamp from before that work.
        now = clockMs();
        if (history.empty() || active.models.isEmpty()) {
            if (active.models.isEmpty()) { QMutexLocker lock(&mutex); cancelPrefetch(); }
            return;
        }
        if (asyncEnabled && asyncDebug)
            std::fprintf(stderr,"[async-debug] request_loop inflight=%zu prefetch=%d last=%lld history=%llu current=%llu\n",
                inflight.size(),int(bool(prefetchedInput)),(long long)lastRequestMs,
                (unsigned long long)history.back().frame.frameId,(unsigned long long)currentFrame);
        VisionFrame frame = history.back().frame;
        if(!acquisition::current(frame.acquisition)) {cancelUnsubmitted(frame);return;}
        {
            QMutexLocker lock(&mutex);
            if (prefetchedInput) frame = *prefetchedInput;
        }
        if (frame.camera != active.camera || frame.sourceGeneration != active.generation ||
            now < frame.capturedMs || now - frame.capturedMs > 1000 ||
            (frame.fpgaInput && frame.frameId <= replayRejectedThrough) ||
            (frame.fpgaInput && scheme2::enabled() &&
             (!scheme2::admission().accepts(frame.fpgaInput->selection) ||
              !active.models.contains(QString::fromStdString(frame.fpgaInput->selection.model))))) {
            QMutexLocker lock(&mutex); cancelUnsubmitted(frame);
            if (prefetchedInput && prefetchedInput->fpgaInput == frame.fpgaInput) prefetchedInput.reset();
            ++perf.rejectStale; return;
        }
        if (frame.fpgaInput && !processedSource(frame)) {
            if (asyncEnabled && asyncDebug)
                std::fprintf(stderr,"[async-debug] unprocessed frame=%llu current=%llu\n",
                    (unsigned long long)frame.frameId,(unsigned long long)currentFrame);
            ++perf.rejectUnprocessed;
            // A newly arrived retained input will be processed first on the next
            // worker iteration. An already passed/evicted identity cannot recover.
            if (frame.frameId <= currentFrame) {
                QMutexLocker lock(&mutex); cancelUnsubmitted(frame);
                if (prefetchedInput && prefetchedInput->fpgaInput == frame.fpgaInput) prefetchedInput.reset();
            }
            return;
        }
        bool urgent = false;
        if (options.tracking && !active.lane) {
            for (const auto& item : trackers) {
                // Empty scenes refresh periodically. Weak/lost existing
                // targets can request sooner, with the same minimum limit.
                if (lost[item.first] || (item.second.needsDetection(currentCapturedMs) &&
                    !item.second.tracks(currentCapturedMs).empty())) urgent = true;
            }
        }
        const bool bypass = active.lane || !options.tracking;
        const qint64 interval = urgent ? std::max(1, options.minimumDetectionIntervalMs) :
            std::max({1, options.detectionIntervalMs, options.minimumDetectionIntervalMs});
        const auto decision = motion::decide(active.motionEnabled, options.tracking, active.lane,
            active.camera, active.generation, frame.motion, now, lastRequestMs, urgent,
            options.detectionIntervalMs, options.minimumDetectionIntervalMs, options.motionRefreshIntervalMs);
        if (asyncEnabled && asyncDebug)
            std::fprintf(stderr,"[async-debug] decide frame=%llu request=%d reason=%d\n",
                (unsigned long long)frame.frameId,int(decision.request),int(decision.reason));
        if (!decision.request) {
            if (eventSchedule) retryAtMs = now + motion::retryDelayMs(decision.reason, now,
                lastRequestMs, options.tracking, urgent, options.detectionIntervalMs,
                options.minimumDetectionIntervalMs, options.motionRefreshIntervalMs);
            if (decision.reason == motion::Reason::StaticDeferred && lastDeferredFrame != frame.frameId) {
                ++staticDeferred; lastDeferredFrame=frame.frameId;
            }
            // Claim at most one future input, late in the existing cooldown.
            // Admission keeps the physical slot occupied until retirement;
            // the exact input is retained separately. No early pending
            // request and no model rotation are created by this preparation.
            if (!active.motionEnabled && scheme2::enabled() && frame.cameraAcquisition &&
                (!frame.fpgaInput || frame.fpgaInput->dispatched.load()) &&
                tdm::InferenceCadence::mayArm(now, lastRequestMs, interval, bypass, scheme2::prefetchLeadMs())) {
                QMutexLocker lock(&mutex);
                if (!stopping && config.epoch == active.epoch &&
                    (asyncEnabled ? !prefetchedInput : !pending))
                    scheme2::admission().arm(active.camera, active.generation,
                        scheme2::prefetchTimingEnabled() ? now : -1);
            }
             ++perf.rejectInterval; return;
        }
        {
            QMutexLocker lock(&mutex);
            if (stopping || config.epoch != active.epoch) { ++perf.rejectConfig; return; }
            if (pending || (asyncEnabled && int(inflight.size()) >= asyncCapacity)) { ++perf.rejectPending; return; }
            // A decoded reply is not FPGA retirement. While its single physical
            // lease remains occupied, do not fall through to a RAW request.
            if (eventSchedule && scheme2::enabled() && frame.cameraAcquisition && !frame.fpgaInput) {
                if (scheme2::admission().available())
                    scheme2::admission().arm(active.camera, active.generation,
                        scheme2::prefetchTimingEnabled() ? now : -1);
                return;
            }
            if (scheme2::enabled() && frame.cameraAcquisition &&
                (frame.fpgaInput || scheme2::admission().available())) {
                if (!frame.fpgaInput) {
                    scheme2::admission().arm(active.camera, active.generation,
                        scheme2::prefetchTimingEnabled() ? now : -1);
                    return;
                }
            }
            const auto latest = frameSlots.find(active.camera);
            const bool newer = latest != frameSlots.end() && !latest->second.empty() &&
                latest->second.back().frameId > frame.frameId;
            const auto submissionKey = std::make_pair(active.generation, active.camera);
            auto previous = submittedThrough.find(submissionKey);
            if (previous != submittedThrough.end() && frame.frameId <= previous->second) {
                cancelUnsubmitted(frame); prefetchedInput.reset();
                ++perf.rejectDuplicate; return;
            }
            if (frame.fpgaInput && frame.fpgaInput->dispatched.exchange(true)) return;
            auto request = Pending{active.epoch, frame.frameId, active.generation, now, frame.capturedMs, frame.camera, frame.tag, frame.fpgaInput};
            request.reason = decision.reason;
            request.acquisition = frame.acquisition;
            if (asyncEnabled) {
                if (inflight.find(frame.frameId) != inflight.end()) { cancelUnsubmitted(frame); ++perf.rejectDuplicate; return; }
                inflight.emplace(frame.frameId, std::move(request));
                submissionOrder.push_back(frame.frameId);
                if (asyncDebug)
                    std::fprintf(stderr,"[async-debug] submit frame=%llu epoch=%llu generation=%d pending=%zu\n",
                        (unsigned long long)frame.frameId,(unsigned long long)active.epoch,active.generation,submissionOrder.size());
            } else {
                pending = std::move(request);
            }
            submittedThrough[submissionKey] = frame.frameId;
            while (submittedThrough.size() > 24) submittedThrough.erase(submittedThrough.begin());
            if (newer) ++perf.newerSnapshotRequests;
        }
        lastRequestMs = now; ++requests;
        if (live(active.epoch)) {
            if (frame.fpgaInput && scheme2::prefetchTimingEnabled()) {
                auto& t = frame.fpgaInput->timing;
                t.request = monotonicMs();
                std::fprintf(stderr, "[fpga-prefetch-timing] frame=%llu generation=%d camera=%d tag=%u arm=%lld claim=%lld hold_command=%lld hold_validated=%lld release=%lld publish=%lld request=%lld ordered=%d\n",
                    static_cast<unsigned long long>(frame.frameId), frame.sourceGeneration, frame.camera, frame.tag,
                    static_cast<long long>(t.arm), static_cast<long long>(t.claim),
                    static_cast<long long>(t.holdCommand), static_cast<long long>(t.holdValidated),
                    static_cast<long long>(t.release), static_cast<long long>(t.publish),
                    static_cast<long long>(t.request), int(t.ordered()));
            }
            tdm::inferAgeEvent("request", {frame.frameId, frame.sourceGeneration, frame.camera, frame.tag, frame.capturedMs});
            try {
                if (selfTestHook) selfTestHook(3); // deterministic pre-emission delay fixture
                if(acquisition::current(frame.acquisition)) emit q->inferenceRequested(frame, asyncEnabled ? active.epoch : 0);
                // Admission was checked before validation/locking/diagnostics.
                // Anchor the next cooldown after signal delivery so that work
                // cannot consume the gap between actual request emissions.
                // Queued consumers remain asynchronous; this does not wait for
                // inference completion or alter physical FPGA lease ownership.
                lastRequestMs = clockMs();
            }
            catch (...) {
                if (frame.fpgaInput) frame.fpgaInput->complete();
                QMutexLocker lock(&mutex);
                if (pending && pending->frameId == frame.frameId && pending->epoch == active.epoch) pending.reset();
                if (asyncEnabled) retireInflight(frame.frameId);
                if (prefetchedInput && prefetchedInput->fpgaInput == frame.fpgaInput) prefetchedInput.reset();
                throw;
            }
        }
        else if (frame.fpgaInput) frame.fpgaInput->complete();
        {
            QMutexLocker lock(&mutex);
            if (prefetchedInput && frame.fpgaInput &&
                prefetchedInput->fpgaInput == frame.fpgaInput) prefetchedInput.reset();
        }
    }
    cv::Rect rectifiedRoi(const StereoState& state, const cv::Rect2f& box, const cv::Size& size) const {
        // Sample the central half of the original left ROI, then map it using
        // the exact rounded, scaled rectification geometry used by DepthEngine.
        std::vector<cv::Point2f> points;
        for (int y = 0; y < 3; ++y) for (int x = 0; x < 3; ++x)
            points.emplace_back(box.x + box.width * (0.25f + x * 0.25f),
                                box.y + box.height * (0.25f + y * 0.25f));
        std::vector<cv::Point2f> rectified;
        cv::undistortPoints(points, rectified, state.calibration.K1, state.calibration.D1,
                            state.roiRotation, state.roiProjection);
        for (auto p : rectified) if (!std::isfinite(p.x) || !std::isfinite(p.y)) return {};
        return cv::boundingRect(rectified) & cv::Rect(0, 0, size.width, size.height);
    }
    static void clearDepth(Detection& d) {
        d.depthMeters = std::numeric_limits<double>::quiet_NaN();
        d.depthAgeMs = 0; d.depthCapturedMs = 0; d.depthTrial = false; d.depthStatus.clear();
    }
    bool vehicleTrial() const { return options.stereoVehicleTrial && options.stereoTrialMeters; }
    QString vehicleDepthStatus(const StereoState& state) const {
        if (!state.calibrated) return QStringLiteral("双目未标定");
        if (!(state.options.synchronizationConfirmed && state.options.hasTagOffset) && !vehicleTrial())
            return QStringLiteral("双目同步未确认");
        return QStringLiteral("等待同帧双目");
    }
    const StereoState::CachedResult* sourceResult(const StereoState& state, quint64 id,
            int generation, qint64 captured, qint64 now) const {
        for (const auto& cached : state.results)
            if (acquisition::metricAllowed(cached.acquisition) && cached.frameId == id && cached.generation == generation && cached.capturedMs == captured &&
                now >= cached.finishedMs && now >= cached.pairCapturedMs && now - cached.pairCapturedMs <= 300)
                return &cached;
        return nullptr;
    }
    void measureBox(StereoState& state, Detection& d, const StereoState::CachedResult* cached, qint64 now) {
        clearDepth(d); d.depthStatus = vehicleDepthStatus(state);
        const bool sync = state.options.synchronizationConfirmed && state.options.hasTagOffset;
        if (!cached || !acquisition::metricAllowed(cached->acquisition) || !state.calibrated || !cached->result.calibrated || (!sync && !vehicleTrial())) return;
        const auto range = stereo::DepthEngine::estimate(cached->result,
            rectifiedRoi(state, rawBox(d), cached->result.left.size()));
        if (!range.valid) { d.depthStatus = QStringLiteral("有效视差不足"); return; }
        d.depthMeters = range.meters; d.depthCapturedMs = cached->pairCapturedMs;
        d.depthAgeMs = int(now - d.depthCapturedMs); d.depthTrial = vehicleTrial();
        d.depthStatus = d.depthTrial ? QStringLiteral("试用 · 车辆ROI · 同步%1 · 保持目标静止")
            .arg(sync ? QStringLiteral("已确认") : QStringLiteral("未确认")) : QStringLiteral("车辆ROI · 同步已确认");
    }
    void measureRaw(StereoState& state, const QString& model, qint64 now) {
        auto raw = nonvehicles.find(model);
        if (raw == nonvehicles.end() || active.lane || state.options.left != active.camera) return;
        const auto& source = raw->second.source;
        const auto* cached = sourceResult(state, source.frameId, source.generation, source.capturedMs, now);
        const auto classes = active.vehicleClasses.value(model);
        for (auto& d : raw->second.boxes) {
            if (classes.contains(d.cls)) measureBox(state, d, cached, now);
            else clearDepth(d);
        }
    }
    void measureTracks(StereoState& state, const QString& model, const tdm::TemplateTracker& tracker,
            const StereoState::CachedResult& cached, qint64 now) {
        for (auto it = state.depths.begin(); it != state.depths.end();) {
            if (it->first.first == model) it = state.depths.erase(it); else ++it;
        }
        const auto tracks = tracker.tracks(cached.capturedMs);
        uint64_t best = 0; float score = -1;
        const auto classes = active.vehicleClasses.value(model);
        for (const auto& track : tracks)
            if (classes.contains(track.cls) && track.detectionScore > score) {
                score = track.detectionScore; best = track.id;
            }
        for (const auto& track : tracks) {
            if (!classes.contains(track.cls) || track.predicted || track.weakFrames > 0 ||
                (options.stereoVehicleTrial && track.id != best)) continue;
            Detection d;
            d.x1 = track.box.x; d.x2 = track.box.x + track.box.width;
            d.y1 = track.box.y + 80; d.y2 = track.box.y + track.box.height + 80;
            measureBox(state, d, &cached, now);
            state.depths[{model, track.id}] =
                Depth{d.depthMeters, cached.pairCapturedMs, track.box, d.depthTrial, d.depthStatus};
        }
    }
    std::optional<Pending> preferredStereoSource;
    struct StereoFrames { const VisionFrame* left = nullptr; const VisionFrame* right = nullptr; };
    StereoFrames correspondingFrames(const StereoState& state,
            const std::map<int, std::deque<VisionFrame>>& frames, qint64 now) const {
        auto l = frames.find(state.options.left), r = frames.find(state.options.right);
        const bool sync = state.options.synchronizationConfirmed && state.options.hasTagOffset;
        StereoFrames pair;
        if (l != frames.end() && r != frames.end()) {
            // History keeps the NPU source alive after the two ingress slots
            // have moved on. No extra inference or unbounded image queue.
            std::vector<const VisionFrame*> lefts;
            for (const auto& a : l->second) lefts.push_back(&a);
            const VisionFrame* preferred = nullptr;
            if (preferredStereoSource && active.camera == state.options.left)
                for (const auto& h : history)
                    if (h.frame.frameId == preferredStereoSource->frameId &&
                        h.frame.sourceGeneration == preferredStereoSource->generation &&
                        h.frame.capturedMs == preferredStereoSource->capturedMs) {
                        preferred = &h.frame; lefts.push_back(preferred); break;
                    }
            for (const auto* candidate : lefts) for (const auto& b : r->second) {
                const auto& a = *candidate;
                if (!acquisition::current(a.acquisition) || !acquisition::current(b.acquisition) ||
                    a.frameId <= state.pairedLeft || b.frameId <= state.pairedRight ||
                    a.sourceGeneration != active.generation || b.sourceGeneration != active.generation ||
                    now < a.capturedMs || now < b.capturedMs ||
                    now - a.capturedMs > 500 || now - b.capturedMs > 500) continue;
                if (sync && a.tag != b.tag + quint32(state.options.tagOffset)) continue;
                const bool want = preferred && a.frameId == preferred->frameId;
                const bool have = pair.left && preferred && pair.left->frameId == preferred->frameId;
                if (!pair.left || (want && !have) || (want == have &&
                    (a.frameId > pair.left->frameId || (a.frameId == pair.left->frameId &&
                     (sync ? b.frameId > pair.right->frameId :
                      std::abs(a.capturedMs - b.capturedMs) < std::abs(a.capturedMs - pair.right->capturedMs))))))
                    pair = {&a, &b};
            }
        }
        return pair;
    }
    void stereoPreview(StereoState& state, quint64 id, const QImage& image, const QString& status) {
        if (&state == previewStereo() && live(active.epoch) && acquisition::current(state.acquisition))
            emit q->stereoReady(active.generation, id, image,
                 QStringLiteral("C%1/C%2: %3").arg(state.options.left + 1).arg(state.options.right + 1).arg(status),state.acquisition);
    }
    void reportStereoWindows(qint64 now) {
        if (stereoWindowStartMs < 0) { stereoWindowStartMs = now; return; }
        // Fixed, non-overlapping five-second windows; never emit per-frame logs.
        while (now - stereoWindowStartMs >= 5000) {
            for (auto& owned : stereoStates) {
                auto& state = *owned;
                const auto& window = state.window;
                const quint64 computes = window.computeSuccess + window.computeFailure;
                qint64 cacheAgeMs = -1;
                for (const auto& depth : state.depths)
                    cacheAgeMs = std::max(cacheAgeMs, now - depth.second.capturedMs);
                const qint64 pairAgeMs = state.lastPairCapturedMs < 0 ? -1 :
                    std::max(qint64(0), now - state.lastPairCapturedMs);
                const QString line = QStringLiteral(
                    "[stereo] window=[%1,%2) window_ms=5000 C%3/C%4 "
                    "pair_compute_ok=%5 pair_compute_failed=%6 no_fresh_pair_polls=%7 "
                    "(polls_not_dropped_frames) compute_mean_ms=%8 compute_max_ms=%9 "
                    "latest_host_pair_age_ms=%10 depth_cache_age_ms=%11 depth_cache_items=%12")
                    .arg(stereoWindowStartMs).arg(stereoWindowStartMs + 5000)
                    .arg(state.options.left + 1).arg(state.options.right + 1)
                    .arg(window.computeSuccess).arg(window.computeFailure).arg(window.noFreshPairPolls)
                    .arg(computes ? window.computeTotalMs / computes : 0, 0, 'f', 2)
                    .arg(window.computeMaxMs, 0, 'f', 2).arg(pairAgeMs).arg(cacheAgeMs)
                    .arg(state.depths.size());
                std::fprintf(stderr, "%s\n", line.toUtf8().constData());
                state.window = {};
            }
            stereoWindowStartMs += 5000;
        }
    }
    void stereoWork(const std::map<int, std::deque<VisionFrame>>& frames, qint64 now) {
        if (stereoStates.empty()) return;
        {
            QMutexLocker lock(&mutex);
            preferredStereoSource = asyncEnabled ? oldestPending() : pending;
        }
        if (!preferredStereoSource && (!options.tracking || options.stereoVehicleTrial))
            for (const auto& raw : nonvehicles) {
                if (now - raw.second.source.capturedMs <= 300) {
                    preferredStereoSource = raw.second.source; break;
                }
            }
        reportStereoWindows(now);
        // Expiry is independent per group and does not wait for compute slots.
        for (auto& owned : stereoStates) {
            auto& state = *owned;
            const auto pair = correspondingFrames(state, frames, now);
            // Count each worker poll without a fresh pair, including cooldown.
            // This is not a count of camera frames or mailbox replacements.
            if (!pair.left || !pair.right) ++state.window.noFreshPairPolls;
            const bool sync = state.options.synchronizationConfirmed && state.options.hasTagOffset;
            if ((!pair.left || !pair.right || !state.engine) && !state.staleReported &&
                (state.lastPreviewMs < 0 || now - state.lastPreviewMs > 1000)) {
                state.staleReported = true;
                stereoPreview(state, state.pairedLeft, QImage(),
                    QStringLiteral("Z/ROI invalid: %1; %2; no fresh corresponding pair")
                        .arg(state.calibrationStatus, sync ? QStringLiteral("sync confirmed") : QStringLiteral("sync unconfirmed")));
            }
        }
        const int interval = std::max(1, options.stereoIntervalMs);
        // Cool down after completion, even if compute itself exceeds interval.
        // At most one group computes here; a continuously ready group cannot
        // starve the other group or keep this worker in endless back-to-back SGBM.
        if (lastStereoFinishedMs >= 0 && now - lastStereoFinishedMs < interval) return;
        for (size_t attempt = 0; attempt < stereoStates.size(); ++attempt) {
            const size_t index = (nextStereo + attempt) % stereoStates.size();
            auto& state = *stereoStates[index];
            const int groupInterval = state.options.intervalMs == 0 ? interval : state.options.intervalMs;
            if (!state.engine || (state.lastAttemptMs >= 0 && now - state.lastAttemptMs < groupInterval)) continue;
            const auto pair = correspondingFrames(state, frames, now);
            if (!pair.left || !pair.right) continue;
            state.lastAttemptMs = now;
            state.lastPairCapturedMs = std::min(pair.left->capturedMs, pair.right->capturedMs);
            state.pairedLeft = pair.left->frameId; state.pairedRight = pair.right->frameId;
            nextStereo = (index + 1) % stereoStates.size();
            QElapsedTimer elapsed; elapsed.start();
            bool succeeded = false;
            try { computeStereo(state, *pair.left, *pair.right); succeeded = true; }
            catch (const std::exception& e) {
                state.depths.clear(); state.results.clear();
                if (&state == selectedStereo()) {
                    const qint64 failedMs = monotonicMs();
                    for (const auto& model : active.models) {
                        measureRaw(state, model, failedMs); publish(model, 0, failedMs);
                    }
                }
                stereoPreview(state, state.pairedLeft, QImage(),
                    QStringLiteral("Z/ROI invalid: stereo compute failed: %1").arg(QString::fromUtf8(e.what())));
            }
            const double computeMs = elapsed.nsecsElapsed() / 1e6;
            lastStereoFinishedMs = monotonicMs();
            // Attribute a compute to its completion window, including failures.
            reportStereoWindows(lastStereoFinishedMs);
            if (succeeded) ++state.window.computeSuccess; else ++state.window.computeFailure;
            state.window.computeTotalMs += computeMs;
            state.window.computeMaxMs = std::max(state.window.computeMaxMs, computeMs);
            return;
        }
    }
    void computeStereo(StereoState& state, const VisionFrame& left, const VisionFrame& right) {
        const auto ticket=acquisition::combine(left.acquisition,right.acquisition);
        if(!acquisition::current(ticket))return;
        state.acquisition=ticket;
        if(!acquisition::metricAllowed(ticket)) {
            state.resetRuntime();
            emit q->rangeReady(active.generation,state.options.left,0.0,std::min(left.capturedMs,right.capturedMs),false,false,
                QStringLiteral("Native HDMI: physical-camera calibration not applicable"),ticket);
            stereoPreview(state,left.frameId,QImage(),QStringLiteral("Native HDMI: no calibrated camera depth"));
            return;
        }
        const bool sync = state.options.synchronizationConfirmed && state.options.hasTagOffset;
        const auto leftGray = measuredGray(left), rightGray = measuredGray(right);
        auto result = state.engine->compute(leftGray, rightGray);
        if(!acquisition::current(ticket)) {state.resetRuntime();return;}
        const qint64 finished = monotonicMs();
        state.lastPreviewMs = finished;
        state.staleReported = false;
        const bool fresh = finished >= left.capturedMs && finished >= right.capturedMs &&
                           finished - left.capturedMs <= 500 && finished - right.capturedMs <= 500;
        QImage preview(result.disparity.cols, result.disparity.rows, QImage::Format_RGB888);
        for (int y = 0; y < preview.height(); ++y) {
            auto* row = preview.scanLine(y);
            for (int x = 0; x < preview.width(); ++x) {
                const float v = result.disparity.at<float>(y, x);
                const uchar shade = std::isfinite(v) ? uchar(std::clamp(int(v * 255 / options.stereoDisparities), 0, 255)) : 0;
                row[x * 3] = row[x * 3 + 1] = row[x * 3 + 2] = shade;
            }
        }
        QString status = QStringLiteral("Z/ROI invalid: %1; %2")
            .arg(state.calibrationStatus, sync ? QStringLiteral("sync confirmed") : QStringLiteral("sync unconfirmed"));
        if (!fresh) status += QStringLiteral("; host age >500ms");
        QString rangeStatus = state.calibrated ?
            (fresh ? QStringLiteral("中央区域匹配不足") : QStringLiteral("配对结果已过期")) :
            QStringLiteral("未标定");
        bool rangePublished = false;
        if (result.calibrated && state.calibrated && (sync || options.stereoTrialMeters) && fresh) {
            const cv::Rect center(result.left.cols * 3 / 8, result.left.rows * 3 / 8,
                                  result.left.cols / 4, result.left.rows / 4);
            const auto range = stereo::DepthEngine::estimate(result, center);
            if (range.valid) {
                rangePublished = true;
                rangeStatus = sync ? QStringLiteral("中央ROI · 同步已确认") : QStringLiteral("试用 · 中央ROI · 同步未确认");
                if (live(active.epoch)) emit q->rangeReady(active.generation, state.options.left,
                    range.meters, std::min(left.capturedMs, right.capturedMs), !sync, true, rangeStatus,ticket);
                status = options.stereoTrialMeters ?
                    QStringLiteral("试用 Z=%1 米 · 中央ROI · %2 · 保持目标静止")
                        .arg(range.meters, 0, 'f', 2)
                        .arg(sync ? QStringLiteral("同步已确认") : QStringLiteral("同步未确认")) :
                    QStringLiteral("Z/ROI center %1 m; calibrated; sync confirmed").arg(range.meters, 0, 'f', 2);
            } else status = options.stereoTrialMeters ?
                QStringLiteral("试用米数无效：中央区域匹配不足 · 同步%1 · %2")
                    .arg(sync ? QStringLiteral("已确认") : QStringLiteral("未确认"))
                    .arg(QString::fromStdString(range.reason)) :
                status + QStringLiteral("; %1").arg(QString::fromStdString(range.reason));
        }
        if (active.camera == state.options.left && !active.lane && fresh &&
            finished - std::min(left.capturedMs, right.capturedMs) <= 300) {
            state.results.push_back(StereoState::CachedResult{left.frameId, left.sourceGeneration,
                left.capturedMs, std::min(left.capturedMs, right.capturedMs), finished, std::move(result),ticket});
            while (state.results.size() > 2) state.results.pop_front();
            const auto& cached = state.results.back();
            // A reply arriving later can correct its source snapshot and use
            // this result before replay. A compute arriving later must never
            // sample current tracks on an older left image.
            if (currentFrame == left.frameId && currentCapturedMs == left.capturedMs) {
                for (const auto& item : trackers) measureTracks(state, item.first, item.second, cached, finished);
            } else if (vehicleTrial()) {
                const auto source = std::find_if(history.begin(), history.end(), [&](const History& h) {
                    return h.frame.frameId == left.frameId && h.frame.sourceGeneration == left.sourceGeneration &&
                           h.frame.capturedMs == left.capturedMs;
                });
                if (source != history.end())
                    for (const auto& item : source->snapshots)
                        measureTracks(state, item.first, item.second, cached, finished);
            }
            for (const auto& model : active.models) {
                measureRaw(state, model, finished); publish(model, 0, finished);
            }
        }
        if (!rangePublished && live(active.epoch)) emit q->rangeReady(active.generation,
            state.options.left, 0.0, std::min(left.capturedMs, right.capturedMs), !sync, false, rangeStatus,ticket);
        stereoPreview(state, left.frameId, preview, status);
    }
    void diagnose(qint64 now) {
        reportPerfWindow(now);
        if (lastDiagnosticMs < 0) { lastDiagnosticMs = now; return; }
        if (now - lastDiagnosticMs < 1000) return;
        const double seconds = double(now - lastDiagnosticMs) / 1000;
        const auto counts = outputCounts(now);
        QStringList stereoProgress;
        if (active.motionEnabled) fprintf(stderr,
            "[motion-scheduling] static_deferred_frames=%llu motion_triggered_completed=%llu fallback_completed=%llu periodic_completed=%llu camera=%d generation=%d\n",
            (unsigned long long)staticDeferred, (unsigned long long)motionCompleted,
            (unsigned long long)fallbackCompleted, (unsigned long long)periodicCompleted,
            active.camera+1, active.generation);
        for (const auto& state : stereoStates)
            stereoProgress.push_back(QStringLiteral("C%1/C%2:%3/%4")
                .arg(state->options.left + 1).arg(state->options.right + 1)
                .arg(state->pairedLeft).arg(state->pairedRight));
        if (live(active.epoch)) emit q->diagnostics(
            QStringLiteral("vision vehicle_tracks=%1 nonvehicle_outputs=%7 vehicle_only=1 track/replay=%2 ms "
                           "NPU requests=%3/s history=%4 (limits RAW=8 FPGA=64) stereo=[%5] tracker_models=%6 raw_outputs=%8")
                .arg(counts.vehicles).arg(matchedFrames ? matchTotalMs / matchedFrames : 0, 0, 'f', 2)
                .arg(requests / seconds, 0, 'f', 1).arg(history.size()).arg(stereoProgress.join(QStringLiteral(",")))
                .arg(trackers.size()).arg(counts.nonvehicles).arg(counts.raw));
        requests = matchedFrames = 0; matchTotalMs = 0; lastDiagnosticMs = now;
    }
    void reportPerfWindow(qint64 now) {
        if (perfWindowStartMs < 0) { perfWindowStartMs = now; return; }
        if (now - perfWindowStartMs < 5000) return;
        const auto counts = outputCounts(now);
        const QString line = QStringLiteral(
            "[analysis] window_ms=%1 wall_ms_sum/count gray=%2 snapshot=%3 prepare=%4 match=%5 correct=%6 replay=%7 "
            "request_reject_pending=%8 interval=%9 duplicate=%10 config=%11 stale=%12 newer=%13 "
            "snapshot_requests_with_newer_ingress=%14 skipped_tracking_frames=%15 (not_capture_dropped_frames) "
            "vehicle_tracks=%16 nonvehicle_outputs=%17 vehicle_only=1 tracker_models=%18 started_ms=%19 ended_ms=%20 raw_outputs=%21")
            .arg(now - perfWindowStartMs).arg(perf.gray.text()).arg(perf.snapshot.text())
            .arg(perf.prepare.text()).arg(perf.match.text()).arg(perf.correct.text()).arg(perf.replay.text())
            .arg(perf.rejectPending).arg(perf.rejectInterval).arg(perf.rejectDuplicate)
            .arg(perf.rejectConfig).arg(perf.rejectStale).arg(perf.rejectNewer)
            .arg(perf.newerSnapshotRequests).arg(perf.skippedTrackingFrames)
            .arg(counts.vehicles).arg(counts.nonvehicles).arg(trackers.size()).arg(perfWindowStartMs).arg(now).arg(counts.raw);
        std::fprintf(stderr, "%s\n", line.toUtf8().constData());
        std::fprintf(stderr, "[analysis-replay] history_peak=%llu replay_gap_count=0 overflow_retirements=%llu request_reject_unprocessed=%llu\n",
            (unsigned long long)perf.historyPeak, (unsigned long long)perf.replayOverflowRetirements,
            (unsigned long long)perf.rejectUnprocessed);
        perf = {}; perfWindowStartMs = now;
    }
};

VisionPipeline::VisionPipeline(VisionOptions options, QObject* parent)
    : QThread(parent), d(new Impl(this, std::move(options))) {
    qRegisterMetaType<VisionFrame>("VisionFrame");
    qRegisterMetaType<acquisition::Ticket>("acquisition::Ticket");
    qRegisterMetaType<QVector<Detection>>("QVector<Detection>");
}
VisionPipeline::~VisionPipeline() { stop(); if (QThread::currentThread() != this) wait(); }
void VisionPipeline::setSelfTestHook(std::function<void(int)> hook) { d->selfTestHook = std::move(hook); }
void VisionPipeline::setSelfTestClock(std::function<qint64()> clock) { d->selfTestClock = std::move(clock); }
bool VisionPipeline::selfTestHasProcessedFrame(const VisionFrame& frame) const { return d->processedSource(frame) != nullptr; }
std::pair<size_t, quint64> VisionPipeline::selfTestReplayState() const {
    return {d->history.size(), d->perf.replayOverflowRetirements};
}

void VisionPipeline::configure(int generation, int camera, bool lane, const QStringList& models,
                               const QHash<QString, QVector<int>>& vehicleClasses, bool fourCamera) {
    QMutexLocker lock(&d->mutex);
    ++d->config.epoch;
    d->resetAsync(); // same mutex as submission and reply callbacks
    d->config.generation = generation; d->config.camera = camera; d->config.lane = lane;
    d->config.fourCamera=fourCamera;d->fourFair={};d->fourCompleted={};d->fourBlackCompleted={};
    d->fourLastMs=-1;
    d->config.motionEnabled = d->options.motionEnabled;
    d->config.models = models; d->config.models.removeDuplicates();
    d->config.vehicleClasses = vehicleClasses;
    ++d->wakeSequence;
    d->cancelPrefetch();
    for(const auto& entry:d->frameSlots)for(const auto& frame:entry.second)Impl::cancelUnsubmitted(frame);
    d->frameSlots.clear(); d->highWater.clear(); d->pending.reset(); d->reply.reset();
    if (scheme2::enabled()) scheme2::admission().disarm();
    d->changed.wakeOne();
}
void VisionPipeline::submitFrame(const VisionFrame& frame) {
    if(!acquisition::current(frame.acquisition)) {Impl::cancelUnsubmitted(frame);return;}
    if (frame.image.size() != QSize(640, 480) || frame.image.format() != QImage::Format_RGB888 ||
        frame.frameId == 0 || frame.capturedMs < 0) { Impl::cancelUnsubmitted(frame); return; }
    QMutexLocker lock(&d->mutex);
    if(d->config.fourCamera && frame.sourceGeneration==d->config.generation &&
       (frame.camera==0||frame.camera==2||frame.camera==3||frame.camera==4) && !d->stopping) {
        auto& slot=d->frameSlots[frame.camera];
        if(frame.frameId<=d->highWater[frame.camera]) {Impl::cancelUnsubmitted(frame);return;}
        d->highWater[frame.camera]=frame.frameId;
        // Retain an exact FPGA lease until dispatch; RAW ingress cannot replace it.
        if(!slot.empty() && slot.back().fpgaInput && !slot.back().fpgaInput->dispatched.load()) {
            if(slot.back().fpgaInput!=frame.fpgaInput) Impl::cancelUnsubmitted(frame);
            return;
        }
        slot.clear();slot.push_back(frame);++d->wakeSequence;d->changed.wakeOne();return;
    }
    if (d->stopping || frame.sourceGeneration != d->config.generation ||
        (frame.camera != d->config.camera &&
         (frame.camera < 0 || frame.camera >= 6 || !(d->stereoMask & (quint32(1) << frame.camera))))) {
        Impl::cancelUnsubmitted(frame); return;
    }
    auto previous = d->highWater.find(frame.camera);
    if (previous != d->highWater.end() && frame.frameId <= previous->second) {
        if (!d->prefetchedInput || d->prefetchedInput->fpgaInput != frame.fpgaInput)
            Impl::cancelUnsubmitted(frame);
        return;
    }
    d->highWater[frame.camera] = frame.frameId;
    auto& slot = d->frameSlots[frame.camera];
    if (frame.fpgaInput && frame.camera != d->config.camera) Impl::cancelUnsubmitted(frame);
    else if (frame.fpgaInput && !frame.fpgaInput->dispatched.load()) {
        if (d->prefetchedInput && d->prefetchedInput->fpgaInput != frame.fpgaInput)
            Impl::cancelUnsubmitted(frame); // SingleInput forbids a second owner
        else {
            d->prefetchedInput = frame;
        }
    }
    // VisionFrame contract guarantees an owned image; implicit QImage sharing
    // keeps ingress cheap and ownership alive while worker snapshots use it.
    slot.push_back(frame);
    while (slot.size() > 2) slot.pop_front();
    ++d->wakeSequence; d->changed.wakeOne();
}
void VisionPipeline::submitDetections(QString model, int generation, quint64 frameId,
                                      QVector<Detection> values, double inferMs, quint64 epoch, bool laneOnly) {
    QMutexLocker lock(&d->mutex);
    if (d->stopping) return;
    if(d->fourBusy && d->fourBusy->generation==generation && d->fourBusy->frameId==frameId) {
        const bool live=d->fourBusy->epoch==d->config.epoch;
        d->fourBusy.reset();++d->wakeSequence;d->changed.wakeOne();
        if(!live)return;
    }
    if(d->config.fourCamera) {
        if(!d->pending || d->pending->generation!=generation || d->pending->frameId!=frameId ||
           d->pending->epoch!=d->config.epoch) return;
        const auto p=*d->pending;d->pending.reset();
        if(acquisition::current(p.acquisition) && d->config.models.contains(model)) {
            for(int i=0;i<4;++i) if(FourFair::cameras[i]==p.camera) {
                if(p.syntheticBlack)++d->fourBlackCompleted[i];else ++d->fourCompleted[i];
                fprintf(stderr,"[four-infer] event=complete camera=%d generation=%d job=%llu source=%s padding=%d source_tag=%u captured_ms=%lld model=%s real_completed=%llu black_completed=%llu issued=%llu service_ms=%.2f acquisition_mask=%u\n",
                    p.camera+1,generation,(unsigned long long)frameId,p.syntheticBlack?"synthetic_black":"camera",int(p.syntheticBlack),p.tag,(long long)p.capturedMs,qPrintable(model),
                    (unsigned long long)d->fourCompleted[i],(unsigned long long)d->fourBlackCompleted[i],(unsigned long long)d->fourFair.issued[i],inferMs,p.acquisition.mask);
            }
        }
        ++d->wakeSequence;d->changed.wakeOne();return;
    }
    if(laneOnly) {lock.unlock();inferenceFailed(generation,frameId,epoch);return;}
    if (d->asyncEnabled && d->asyncDebug) {
        std::fprintf(stderr,"[async-debug] reply frame=%llu epoch_config=%llu oldest=%llu replies=%zu inflight=%zu\n",
            (unsigned long long)frameId,(unsigned long long)d->config.epoch,
            d->submissionOrder.empty()?0:(unsigned long long)d->submissionOrder.front(),
            d->replies.size(),d->inflight.size());
    }
    if (d->asyncEnabled) {
        auto found = d->inflight.find(frameId);
        if (found == d->inflight.end()) return;
        const auto request = found->second;
        if(!acquisition::current(request.acquisition)) {d->erasePendingId(frameId);return;}
        // Validate identity BEFORE retiring anything: a stale callback must
        // leave the matching numeric frame in a newer generation untouched.
        if ((epoch && request.epoch != epoch) || request.epoch != d->config.epoch ||
            request.generation != generation || !d->config.models.contains(model)) return;
        d->erasePendingId(frameId);
        if (d->clockMs() - request.sentMs >= 2000) { ++d->wakeSequence; d->changed.wakeOne(); return; }
        d->replies.push_back(Impl::Reply{request,std::move(model),std::move(values),inferMs});
    } else {
        if (!d->pending || !acquisition::current(d->pending->acquisition) || d->reply ||
            d->pending->epoch != d->config.epoch || d->pending->generation != generation ||
            d->pending->frameId != frameId || d->clockMs() - d->pending->sentMs >= 2000) return;
        if (!d->config.models.contains(model)) { d->pending.reset(); ++d->wakeSequence; d->changed.wakeOne(); return; }
        d->reply = Impl::Reply{*d->pending, std::move(model), std::move(values), inferMs};
    }
    ++d->wakeSequence; d->changed.wakeOne();
}
void VisionPipeline::inferenceFailed(int generation, quint64 frameId) {
    QMutexLocker lock(&d->mutex);
    if(d->fourBusy && d->fourBusy->generation==generation && d->fourBusy->frameId==frameId) {
        d->fourBusy.reset();++d->wakeSequence;d->changed.wakeOne();
    }
    if (d->asyncEnabled && !d->config.fourCamera) {
        if (d->expiredAsync.find({d->config.epoch,generation,frameId}) != d->expiredAsync.end()) return;
        auto found = d->inflight.find(frameId);
        if (found == d->inflight.end() || found->second.generation != generation ||
            found->second.epoch != d->config.epoch) return;
        d->erasePendingId(frameId); ++d->wakeSequence; d->changed.wakeOne();
        return;
    }
    if (d->pending && d->pending->epoch == d->config.epoch &&
        d->pending->generation == generation && d->pending->frameId == frameId && !d->reply) {
        if(d->config.fourCamera)fprintf(stderr,"[four-infer] event=failed camera=%d generation=%d frame=%llu\n",d->pending->camera+1,generation,(unsigned long long)frameId);
        d->pending.reset(); ++d->wakeSequence; d->changed.wakeOne();
    }
}
void VisionPipeline::inferenceFailed(int generation, quint64 frameId, quint64 epoch) {
    QMutexLocker lock(&d->mutex);
    if(d->fourBusy && d->fourBusy->generation==generation && d->fourBusy->frameId==frameId &&
       (!epoch || d->fourBusy->epoch==epoch)) {
        d->fourBusy.reset();++d->wakeSequence;d->changed.wakeOne();
    }
    if (d->pending && d->pending->epoch == d->config.epoch &&
        d->pending->generation == generation && d->pending->frameId == frameId && !d->reply) {
        if(d->config.fourCamera)fprintf(stderr,"[four-infer] event=failed camera=%d generation=%d frame=%llu\n",d->pending->camera+1,generation,(unsigned long long)frameId);
        d->pending.reset(); ++d->wakeSequence; d->changed.wakeOne();
    }
    if (d->asyncEnabled) {
        // Explicit epoch is required for async callbacks; epoch=0 belongs to
        // the synchronous API and cannot retire an asynchronous submission.
        auto found = d->inflight.find(frameId);
        if (epoch != 0 && found != d->inflight.end() && found->second.epoch == epoch &&
            found->second.generation == generation) {
            d->erasePendingId(frameId); ++d->wakeSequence; d->changed.wakeOne();
        }
    }
}
void VisionPipeline::stop() {
    QMutexLocker lock(&d->mutex);
    for(const auto& entry:d->frameSlots)for(const auto& frame:entry.second)Impl::cancelUnsubmitted(frame);
    d->stopping = true; d->pending.reset(); d->reply.reset(); d->frameSlots.clear();
    d->resetAsync();
    d->cancelPrefetch();
    if (scheme2::enabled()) scheme2::admission().disarm();
    d->changed.wakeAll();
}
void VisionPipeline::run() {
    if (d->eventSchedule) std::fprintf(stderr, "[event-scheduling] enabled latest_mailbox=2 maintenance_ms=20 minimum_ms=%d\n",
        d->options.minimumDetectionIntervalMs);
    d->prepareStereo();
    for (;;) {
        d->sweepAcquisition();
        Impl::Config config;
        std::map<int, std::deque<VisionFrame>> frames;
        std::optional<Impl::Reply> reply;
        std::optional<VisionFrame> prefetched;
        quint64 observedWake = 0;
        d->retryAtMs = -1;
        {
            QMutexLocker lock(&d->mutex);
            if (d->stopping) break;
            config = d->config; frames = d->frameSlots;
            observedWake = d->wakeSequence;
            prefetched = d->prefetchedInput;
            if (config.fourCamera) {
                // Completion, never a wall-clock timeout, releases this slot.
            } else if (d->asyncEnabled) {
                const qint64 clock = d->clockMs();
                for (auto it = d->inflight.begin(); it != d->inflight.end();) {
                    if (clock - it->second.sentMs >= 2000) {
                        d->expiredAsync.insert({it->second.epoch,it->second.generation,it->first});
                        d->erasePendingId(it->first);
                        it = d->inflight.begin();
                    } else ++it;
                }
                // Consume replies after the prefetched correction snapshot is
                // processed below, matching the synchronous replay order.

            } else if (d->reply) { reply = std::move(d->reply); d->reply.reset(); d->pending.reset(); }
            else if (d->pending && d->clockMs() - d->pending->sentMs >= 2000) d->pending.reset();
        }
        qint64 now = d->clockMs();
        try {
            if(config.fourCamera) {
                d->fourWork(now);
                QMutexLocker lock(&d->mutex);
                if(!d->stopping && d->wakeSequence==observedWake)d->changed.wait(&d->mutex,20);
                continue;
            }
            if (config.epoch != d->active.epoch) {
                d->reset(config);
                // A queued reply from the previous generation is not eligible
                // for the just-reset model or tracker, even if prefetched.
                if (reply && reply->request.epoch != config.epoch) reply.reset();
            }
            d->prune(now);
            if (reply && d->eventSchedule) { d->acceptReply(*reply, now); reply.reset(); }
            if (d->eventSchedule) {
                // Replay may take time. Sample ingress again before choosing
                // the latest RAW, retaining the exact leased FPGA source first.
                QMutexLocker lock(&d->mutex);
                if (d->stopping || d->config.epoch != config.epoch) continue;
                frames = d->frameSlots;
                prefetched = d->prefetchedInput;
                now = d->clockMs();
            }
            if (prefetched) {
                if (now < prefetched->capturedMs || now - prefetched->capturedMs > 1000 ||
                    prefetched->sourceGeneration != config.generation || prefetched->camera != config.camera) {
                    Impl::cancelUnsubmitted(*prefetched);
                    QMutexLocker lock(&d->mutex);
                    if (d->prefetchedInput && d->prefetchedInput->fpgaInput == prefetched->fpgaInput)
                        d->prefetchedInput.reset();
                } else d->processFrame(*prefetched, now);
            }
            auto selected = frames.find(config.camera);
            if (selected != frames.end() && !selected->second.empty()) {
                const auto& candidate = selected->second.back();
                if (candidate.fpgaInput && now - candidate.capturedMs > 1000 &&
                    !candidate.fpgaInput->dispatched.exchange(true)) candidate.fpgaInput->complete();
            }
            if (selected != frames.end() && !selected->second.empty())
                d->processFrame(selected->second.back(), now);
            if (d->asyncEnabled) {
                QMutexLocker lock(&d->mutex);
                while (!d->replies.empty() && d->replies.front().request.epoch != config.epoch)
                    d->replies.pop_front();
                if (!d->replies.empty()) {
                    reply = std::move(d->replies.front());
                    d->replies.pop_front();
                    d->lastDeliveredFrame = reply->request.frameId;
                }
            }
            if (reply) d->acceptReply(*reply, now);
            d->expireFrozenTracks(now);
            if (d->selfTestHook) d->selfTestHook(1); // after copied ingress was processed, before live request selection
            d->request(now);
            if (d->selfTestHook) d->selfTestHook(2); // lets the race fixture observe this iteration's decision
            d->stereoWork(frames, now);
            d->diagnose(monotonicMs());
        } catch (const std::exception& e) {
            { QMutexLocker lock(&d->mutex); d->cancelPrefetch(); }
            // Malformed calibration or a failed OpenCV operation cannot kill
            // capture threads or leave an NPU reservation permanently locked.
            if (d->live(config.epoch)) {
                const qint64 errorNow = monotonicMs();
                if (d->lastDiagnosticMs < 0 || errorNow - d->lastDiagnosticMs >= 1000) {
                    emit diagnostics(QStringLiteral("vision: %1").arg(QString::fromUtf8(e.what())));
                    d->lastDiagnosticMs = errorNow;
                }
            }
        }
        QMutexLocker lock(&d->mutex);
        if (!d->stopping && d->config.epoch == config.epoch && !d->reply &&
            (!d->asyncEnabled || d->replies.empty()) &&
            d->wakeSequence == observedWake) {
            const auto delay = d->eventSchedule && d->retryAtMs >= 0 ?
                std::clamp<qint64>(d->retryAtMs - d->clockMs(), 0, 20) : 20;
            if (delay > 0) d->changed.wait(&d->mutex, static_cast<unsigned long>(delay));
        }
    }
    for (const auto& h : d->history) Impl::cancelUnsubmitted(h.frame);
    d->history.clear();
}
