#include "vision_pipeline.h"
#include "template_tracker.h"
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QMutex>
#include <QMutexLocker>
#include <QTextStream>
#include <QTemporaryFile>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <functional>
#include <stdexcept>
#include <time.h>

namespace {
qint64 testNow() {
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return qint64(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
}
bool until(const std::function<bool()>& predicate, int timeout = 1000) {
    QElapsedTimer timer; timer.start();
    while (!predicate()) {
        if (timer.elapsed() >= timeout) return false;
        QThread::msleep(2);
    }
    return true;
}
QImage fixture(int shift = 0, bool blank = false) {
    QImage image(640, 480, QImage::Format_RGB888);
    image.fill(Qt::black);
    if (blank) return image;
    // Stable, textured, distinctive target translated in original camera pixels.
    quint32 seed = 739391;
    for (int y = 150; y < 230; ++y) {
        auto* row = image.scanLine(y);
        for (int x = 200 + shift; x < 280 + shift; ++x) {
            seed = seed * 1664525U + 1013904223U;
            const uchar value = uchar(30 + (seed >> 24) % 210);
            row[x * 3] = row[x * 3 + 1] = row[x * 3 + 2] = value;
        }
    }
    return image;
}
VisionFrame frame(quint64 id, int generation = 1, int camera = 0, int shift = 0, bool blank = false) {
    VisionFrame f;
    f.image = fixture(shift, blank); f.frameId = id; f.sourceGeneration = generation;
    f.camera = camera; f.tag = quint32(id); f.capturedMs = testNow();
    return f;
}
Detection target() {
    Detection d;
    d.cls = 0; d.score = 0.95f;
    d.x1 = 200; d.x2 = 280; d.y1 = 230; d.y2 = 310;
    return d;
}
void writeCalibration(const QString& path, double baseline) {
    const cv::Mat K = (cv::Mat_<double>(3, 3) << 400, 0, 320, 0, 400, 240, 0, 0, 1);
    cv::FileStorage file(path.toStdString(), cv::FileStorage::WRITE | cv::FileStorage::FORMAT_YAML);
    file << "image_width" << 640 << "image_height" << 480 << "length_unit" << "m"
         << "K1" << K << "K2" << K << "D1" << cv::Mat::zeros(1, 5, CV_64F)
         << "D2" << cv::Mat::zeros(1, 5, CV_64F) << "R" << cv::Mat::eye(3, 3, CV_64F)
         << "T" << (cv::Mat_<double>(3, 1) << -baseline, 0, 0);
}
struct Log {
    QMutex mutex;
    QVector<VisionFrame> requests;
    QVector<qint64> requestedAt;
    struct Output { QString model; int generation; quint64 id; QVector<Detection> boxes; };
    QVector<Output> outputs;
    QVector<Output> accepted;
    QStringList stereo;
    struct StereoOutput { int generation; quint64 id; bool preview; QString status; qint64 at; };
    QVector<StereoOutput> stereoOutputs;
    QStringList diagnostics;
    int stereoPreviews = 0;
    void connect(VisionPipeline& p) {
        QObject::connect(&p, &VisionPipeline::inferenceRequested, &p, [this](VisionFrame f, quint64) {
            QMutexLocker lock(&mutex); requests.push_back(f); requestedAt.push_back(testNow());
        }, Qt::DirectConnection);
        QObject::connect(&p, &VisionPipeline::acceptedDetectorResult, &p,
            [this](QString m, int gen, quint64 id, QVector<Detection> boxes, qint64) {
                QMutexLocker lock(&mutex); accepted.push_back({m, gen, id, boxes});
            }, Qt::DirectConnection);
        QObject::connect(&p, &VisionPipeline::tracksReady, &p,
            [this](QString m, int gen, quint64 id, QVector<Detection> boxes, double) {
                QMutexLocker lock(&mutex); outputs.push_back({m, gen, id, boxes});
            }, Qt::DirectConnection);
        QObject::connect(&p, &VisionPipeline::stereoReady, &p,
            [this](int gen, quint64 id, QImage image, QString s) {
                QMutexLocker lock(&mutex); stereo.push_back(s);
                stereoOutputs.push_back({gen, id, !image.isNull(), s, testNow()});
                if (!image.isNull()) ++stereoPreviews;
            }, Qt::DirectConnection);
        QObject::connect(&p, &VisionPipeline::diagnostics, &p, [this](QString s) {
            QMutexLocker lock(&mutex); diagnostics.push_back(s);
        }, Qt::DirectConnection);
    }
    int count() { QMutexLocker lock(&mutex); return requests.size(); }
    VisionFrame request(int i) { QMutexLocker lock(&mutex); return requests[i]; }
    int outputCount() { QMutexLocker lock(&mutex); return outputs.size(); }
    int acceptedCount() { QMutexLocker lock(&mutex); return accepted.size(); }
    bool hasOutput(const QString& model, int generation, quint64 id, bool requireTarget = false) {
        QMutexLocker lock(&mutex);
        for (const auto& o : outputs) if (o.model == model && o.generation == generation && o.id == id &&
            (!requireTarget || !o.boxes.isEmpty())) return true;
        return false;
    }
    bool latest(const QString& model, int generation, Output& value) {
        QMutexLocker lock(&mutex);
        for (auto it = outputs.crbegin(); it != outputs.crend(); ++it)
            if (it->model == model && it->generation == generation) { value = *it; return true; }
        return false;
    }
    bool hasDepth(int generation, quint64 id, double meters, qint64 captured) {
        QMutexLocker lock(&mutex);
        for (const auto& o : outputs) if (o.generation == generation && o.id == id)
            for (const auto& box : o.boxes)
                if (std::isfinite(box.depthMeters) && std::abs(box.depthMeters - meters) < 0.08 &&
                    box.depthCapturedMs == captured) return true;
        return false;
    }
    bool hasPreview(int generation, quint64 id) {
        QMutexLocker lock(&mutex);
        for (const auto& o : stereoOutputs)
            if (o.generation == generation && o.id == id && o.preview) return true;
        return false;
    }
};
}

bool VisionPipeline::selfTest() {
    QTextStream out(stdout), err(stderr);
    auto check = [&](bool condition, const char* name) {
        if (!condition) { err << "VISION_SELFTEST_FAIL: " << name << '\n'; err.flush(); }
        return condition;
    };
    bool ok = true;
    {
        // Prove admission-to-emission delay cannot shorten the actual cooldown.
        // All times use one injected clock; no wall-clock scheduling tolerance.
        VisionOptions options; options.tracking=true; options.motionEnabled=false;
        options.detectionIntervalMs=700; options.minimumDetectionIntervalMs=300;
        const qint64 base=testNow();
        std::atomic<qint64> fixtureClock{base};
        std::atomic<int> emitted{0};
        std::atomic<qint64> firstEmission{-1}, secondEmission{-1};
        std::atomic<bool> blockedAtOldDeadline{false};
        VisionPipeline pipeline(options);
        pipeline.setSelfTestClock([&] { return fixtureClock.load(); });
        QObject::connect(&pipeline, &VisionPipeline::inferenceRequested, &pipeline,
            [&](VisionFrame) {
                if (emitted.fetch_add(1)==0) firstEmission=fixtureClock.load();
                else secondEmission=fixtureClock.load();
            }, Qt::DirectConnection);
        int iteration=0;
        pipeline.setSelfTestHook([&](int stage) {
            if (stage==3 && emitted.load()==0) fixtureClock=base+40;
            if (stage!=2) return;
            if (++iteration==1) {
                pipeline.inferenceFailed(1,1);
                fixtureClock=base+700;
                auto next=frame(2); next.capturedMs=fixtureClock.load();
                pipeline.submitFrame(next);
            } else if (iteration==2) {
                blockedAtOldDeadline=emitted.load()==1;
                fixtureClock=base+740;
                auto next=frame(3); next.capturedMs=fixtureClock.load();
                pipeline.submitFrame(next);
            }
        });
        pipeline.configure(1,0,false,{QStringLiteral("cadence-clock")});
        auto initial=frame(1); initial.capturedMs=base;
        pipeline.submitFrame(initial); pipeline.start();
        ok &= check(until([&] { return secondEmission.load()>=0; }),"delayed emission reaches actual cooldown deadline");
        pipeline.stop(); pipeline.wait();
        ok &= check(blockedAtOldDeadline.load(),"pre-emission work cannot consume request cooldown");
        ok &= check(firstEmission.load()==base+40 && secondEmission.load()-firstEmission.load()>=700,
                    "injected clock preserves full actual emission cooldown");
    }
    {
        const QByteArray previous=qgetenv("ADS_EVENT_SCHEDULE");
        const bool hadVariable=qEnvironmentVariableIsSet("ADS_EVENT_SCHEDULE");
        qputenv("ADS_EVENT_SCHEDULE","1");
        VisionOptions options; options.tracking=false; options.motionEnabled=false;
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        std::atomic<bool> injected{false};
        // Deliver a failure and a burst while the worker is outside its wait.
        // No queued per-frame callbacks: only the latest two ingress slots survive.
        pipeline.setSelfTestHook([&](int stage) {
            if (stage!=2 || log.count()!=1 || injected.exchange(true)) return;
            pipeline.inferenceFailed(1,1);
            for (quint64 id=2;id<=100;++id) pipeline.submitFrame(frame(id));
        });
        pipeline.configure(1,0,false,{QStringLiteral("a")});
        pipeline.submitFrame(frame(1)); pipeline.start();
        ok &= check(until([&] { return log.count()>=2; }),"event during processing resumes latest mailbox");
        if (log.count()>=2) ok &= check(log.request(1).frameId==100,"event burst submits latest frame only");
        pipeline.submitDetections(QStringLiteral("a"),1,1,{target()},1);
        pipeline.configure(2,0,false,{QStringLiteral("a")});
        pipeline.submitFrame(frame(101,2));
        ok &= check(until([&] { return log.count()>=3; }),"event configuration resumes new generation");
        pipeline.stop(); pipeline.wait();
        ok &= check(log.acceptedCount()==0,"event mode rejects retired reply identity");
        if (hadVariable) qputenv("ADS_EVENT_SCHEDULE",previous); else qunsetenv("ADS_EVENT_SCHEDULE");
    }
    {
        // Retained baseline actual-worker regression: static deferral and an
        // observed motion pulse survive replacement of the source mailbox.
        VisionOptions options; options.tracking=false; options.motionEnabled=true;
        options.motionRefreshIntervalMs=500; options.minimumDetectionIntervalMs=250;
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(1,0,false,{QStringLiteral("a")}); pipeline.start();
        motion::Observer observer; motion::Record quiet; quiet.referenceValid=true; quiet.samples=15;
        const qint64 start=testNow(); quiet.seq=1; observer.observe(quiet,start-100,1);
        quiet.seq=2; observer.observe(quiet,start,1);
        auto first=frame(1); first.motion=observer.evidence; pipeline.submitFrame(first);
        ok &= check(until([&] { return log.count()==1; }), "motion static initial full-frame request");
        if (log.count()!=1) { pipeline.stop(); pipeline.wait(); return false; }
        pipeline.submitDetections(QStringLiteral("a"),1,1,{},1);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("a"),1,1); }), "motion completion releases controller gate");
        QThread::msleep(255);
        quiet.seq=3; observer.observe(quiet,testNow(),1);
        auto still=frame(2); still.motion=observer.evidence; pipeline.submitFrame(still);
        QThread::msleep(10);
        ok &= check(log.count()==1,"fresh static full-frame defers without stopping ingress");
        auto moving=quiet; moving.seq=4; moving.blocks=1; moving.samples=8;
        moving.bitmap[0]=1; moving.bboxValid=true;
        observer.observe(moving,testNow(),1);
        quiet.seq=5; observer.observe(quiet,testNow(),1);
        auto latest=frame(4); latest.motion=observer.evidence; pipeline.submitFrame(latest);
        ok &= check(until([&] { return log.count()==2; },150),"overwritten observed motion triggers before 500ms static refresh");
        if (log.count()>=2) ok &= check(log.request(1).frameId==4 && log.request(1).image.size()==QSize(640,480),
            "motion requests latest owned full frame without ROI");
        pipeline.configure(2,0,false,{QStringLiteral("a")});
        auto changed=frame(5,2); changed.motion=observer.evidence; pipeline.submitFrame(changed);
        ok &= check(until([&] { return log.count()==3; }),"generation reset rejects old motion and requests fallback");
        pipeline.configure(3,5,false,{QStringLiteral("a")});
        auto unsupported=frame(6,3,5); unsupported.motion=observer.evidence; pipeline.submitFrame(unsupported);
        ok &= check(until([&] { return log.count()==4; }),"CAM6 motion option retains inference fallback");
        pipeline.configure(4,0,true,{QStringLiteral("a")});
        auto lane=frame(7,4); lane.motion=observer.evidence; pipeline.submitFrame(lane);
        ok &= check(until([&] { return log.count()==5; }),"lane reconfiguration retains inference fallback");
        pipeline.stop(); pipeline.wait();
    }
    if (!scheme2::enabled()) {
        // Deterministically inject into the real worker after its ingress copy
        // has been processed, before request() re-reads the live retained input.
        const QString model = QStringLiteral("checked-race");
        VisionOptions options; options.trackingIntervalMs = 0;
        options.detectionIntervalMs = options.minimumDetectionIntervalMs = 1;
        options.trackingMaxDetectionAgeMs = 1400;
        auto old = frame(1, 90);
        auto exact = frame(2, 90); exact.tag = 321;
        exact.fpgaInput = std::make_shared<scheme2::Input>();
        exact.fpgaInput->camera = 0; exact.fpgaInput->sourceGeneration = 90; exact.fpgaInput->tag = exact.tag;
        auto newer = frame(3, 90, 0, 12);
        // Distinct captured milliseconds ensure tracker replay performs a real
        // update even on hosts that construct all three QImages within 1ms.
        const qint64 captured = testNow();
        old.capturedMs = captured - 10; exact.capturedMs = captured - 5; newer.capturedMs = captured;
        Log log;
        std::atomic<bool> noEarlyEmit{false}, sourceBeforeEmit{false}, injected{false};
        VisionPipeline pipeline(options); log.connect(pipeline);
        int iteration = 0;
        pipeline.setSelfTestHook([&](int stage) {
            if (stage == 1 && !injected && pipeline.selfTestHasProcessedFrame(old)) {
                ++iteration;
                pipeline.submitFrame(exact); // absent from this iteration's copied ingress
                injected = true;
            } else if (stage == 2 && iteration == 1) {
                noEarlyEmit = log.count() == 0 && !exact.fpgaInput->dispatched.load();
                pipeline.submitFrame(newer); // newest mailbox frame before the next copy
                ++iteration;
            }
        });
        QObject::connect(&pipeline, &VisionPipeline::inferenceRequested, &pipeline, [&](VisionFrame sent, quint64) {
            sourceBeforeEmit = sent.frameId == exact.frameId && sent.tag == exact.tag &&
                sent.fpgaInput == exact.fpgaInput && pipeline.selfTestHasProcessedFrame(exact) &&
                pipeline.selfTestHasProcessedFrame(newer);
        }, Qt::DirectConnection);
        pipeline.configure(90, 0, false, {model}, {{model, {0}}});
        pipeline.submitFrame(old); pipeline.start();
        const bool emitted = until([&] { return sourceBeforeEmit.load(); });
        ok &= check(emitted && noEarlyEmit.load(), "late ingress cannot emit before exact source and newer RAW are processed");
        if (emitted) {
            exact.fpgaInput->complete();
            pipeline.submitDetections(model, 90, 2, {target()}, 1);
            ok &= check(until([&] {
                Log::Output value;
                return log.latest(model, 90, value) && value.id == 3 && value.boxes.size() == 1 &&
                    value.boxes[0].trackId != 0 && std::abs(value.boxes[0].x1 - 212) < 3;
            }, 300), "late ingress reply corrects exact source and replays newer RAW");
        }
        pipeline.stop(); pipeline.wait();
    }
    if (!scheme2::enabled()) for (int dispatched = 0; dispatched < 2; ++dispatched) {
        // Stress 65 processed samples in the source suffix, not dropped ingress.
        // Retirement/rejection must replace gap replay while current tracks live.
        const QString model = QStringLiteral("checked-overflow");
        const int generation = 91 + dispatched;
        VisionOptions options; options.trackingIntervalMs = 0;
        options.detectionIntervalMs = options.minimumDetectionIntervalMs = dispatched ? 1 : 1000;
        options.trackingMaxDetectionAgeMs = 1400;
        Log log;
        std::atomic<bool> overflow{false}, bounded{true};
        // Deterministic source/worker clock isolates capacity retirement from
        // ARM scheduling/strace cost. Production keeps its actual monotonic TTL.
        std::atomic<qint64> fixtureClock{testNow()};
        VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.setSelfTestClock([&] { return fixtureClock.load(); });
        pipeline.setSelfTestHook([&](int stage) {
            if (stage != 2) return;
            const auto state = pipeline.selfTestReplayState();
            if (state.first > 64) bounded = false;
            if (state.second > 0 && state.first <= 8) overflow = true;
        });
        pipeline.configure(generation, 0, false, {model}, {{model, {0}}}); pipeline.start();
        auto initial = frame(1, generation); initial.capturedMs = fixtureClock.load();
        pipeline.submitFrame(initial);
        ok &= check(until([&] { return log.count() == 1; }), "overflow initial request");
        if (dispatched) {
            pipeline.submitDetections(model, generation, 1, {target()}, 1);
            ok &= check(until([&] { return log.hasOutput(model, generation, 1, true); }), "overflow starts with healthy live tracks");
        } // otherwise hold initial CPU request so the exact input stays unsubmitted
        auto exact = frame(2, generation);
        fixtureClock += 2; exact.capturedMs = fixtureClock.load();
        exact.fpgaInput = std::make_shared<scheme2::Input>();
        exact.fpgaInput->camera = 0; exact.fpgaInput->sourceGeneration = generation; exact.fpgaInput->tag = exact.tag;
        pipeline.submitFrame(exact);
        ok &= check(until([&] { return log.hasOutput(model, generation, 2); }), "overflow exact source processed");
        if (dispatched) ok &= check(until([&] { return exact.fpgaInput->dispatched.load(); }), "overflow pending exact source emitted");
        for (quint64 id = 3; id <= 66; ++id) {
            VisionFrame sample = exact; sample.fpgaInput.reset(); sample.frameId = id;
            fixtureClock += 2;
            sample.tag = quint32(id); sample.capturedMs = fixtureClock.load(); // share the textured QImage
            pipeline.submitFrame(sample);
            ok &= check(until([&] { return log.hasOutput(model, generation, id); }, 150), "overflow processes every RAW sample");
        }
        ok &= check(fixtureClock.load() - exact.capturedMs < 1000, "overflow fixture reaches capacity before source TTL");
        ok &= check(until([&] { return overflow.load(); }, 150) && bounded.load(), "overflow is measured and restores eight-entry history without gap replay");
        if (!dispatched) {
            std::lock_guard<std::mutex> lock(exact.fpgaInput->mutex);
            ok &= check(exact.fpgaInput->retired, "overflow completes unsubmitted source despite shared image ownership");
        } else {
            exact.fpgaInput->complete();
            pipeline.submitDetections(model, generation, 2, {}, 1); // empty stale correction would clear tracks if accepted
            fixtureClock += 2;
            auto after = exact; after.fpgaInput.reset(); after.frameId = 67; after.tag = 67; after.capturedMs = fixtureClock.load();
            pipeline.submitFrame(after);
            ok &= check(until([&] { return log.hasOutput(model, generation, 67, true); }, 150), "overflow late empty reply cannot clear latest live tracks");
            ok &= check(log.acceptedCount() == 1, "overflow source is rejected before accepted detector publication");
        }
        pipeline.stop(); pipeline.wait();
    }
    if (!scheme2::enabled()) {
        // Real VisionPipeline worker, synthetic owned Input: no board operations.
        // More than eight RAW frames must not evict the exact correction source.
        VisionOptions options; options.trackingIntervalMs = 0;
        options.detectionIntervalMs = 700; options.minimumDetectionIntervalMs = 300;
        options.trackingMaxDetectionAgeMs = 1400;
        const QString model = QStringLiteral("live-prefetch");
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(70, 0, false, {model}, {{model, {0}}}); pipeline.start();
        pipeline.submitFrame(frame(1, 70));
        const bool initial = until([&] { return log.count() == 1; });
        ok &= check(initial, "live initial cadence reservation");
        if (initial) pipeline.inferenceFailed(70, 1);
        auto exact = frame(2, 70);
        exact.tag = 987;
        exact.fpgaInput = std::make_shared<scheme2::Input>();
        exact.fpgaInput->camera = 0; exact.fpgaInput->sourceGeneration = 70; exact.fpgaInput->tag = exact.tag;
        pipeline.submitFrame(exact);
        ok &= check(until([&] { return log.hasOutput(model, 70, 2); }), "prefetch source snapshot processed");
        pipeline.submitFrame(exact); // duplicate must not retire a healthy retained input
        for (quint64 id = 3; id <= 12; ++id) {
            pipeline.submitFrame(frame(id, 70, 0, int(id - 2) * 2));
            ok &= check(until([&] { return log.hasOutput(model, 70, id); }, 150),
                        "new RAW continues during prefetch cooldown");
        }
        { std::lock_guard<std::mutex> lock(exact.fpgaInput->mutex);
          ok &= check(!exact.fpgaInput->retired, "duplicate and newer RAW preserve healthy input"); }
        const bool requested = until([&] { return log.count() >= 2; }, 900);
        ok &= check(requested, "prefetch submits after unchanged cooldown");
        if (requested) {
            const auto sent = log.request(1);
            ok &= check(sent.frameId == 2 && sent.tag == 987 && sent.camera == 0 &&
                sent.sourceGeneration == 70 && sent.fpgaInput == exact.fpgaInput &&
                sent.image.constBits() == exact.image.constBits(), "exact prefetch identity and QImage sharing");
            { QMutexLocker lock(&log.mutex);
              ok &= check(log.requestedAt[1] - log.requestedAt[0] >= 700, "actual request cooldown unchanged"); }
            exact.fpgaInput->complete(); // synchronous fake consumer finished
            pipeline.submitDetections(model, 70, 2, {target()}, 1);
            ok &= check(until([&] {
                Log::Output value;
                return log.latest(model, 70, value) && value.id == 12 && value.boxes.size() == 1 &&
                    value.boxes[0].trackId != 0 && std::abs(value.boxes[0].x1 - 220) < 3;
            }, 250), "retained source corrected and replayed to latest RAW beyond eight frames");
        }
        pipeline.stop(); pipeline.wait();
        {
            // A fresh detector source excludes periodic detector-age urgency.
            // Only newer blank RAW weakens/loses this target during cooldown.
            Log lossLog; VisionPipeline lossPipeline(options); lossLog.connect(lossPipeline);
            lossPipeline.configure(71, 0, false, {model}, {{model, {0}}}); lossPipeline.start();
            const auto recent = frame(1, 71); lossPipeline.submitFrame(recent);
            ok &= check(until([&] { return lossLog.count() == 1; }), "loss fixture initial request");
            lossPipeline.submitDetections(model, 71, 1, {target()}, 1);
            ok &= check(until([&] { return lossLog.hasOutput(model, 71, 1, true); }, 250), "loss fixture fresh target correction");
            auto next = frame(2, 71);
            next.fpgaInput = std::make_shared<scheme2::Input>();
            next.fpgaInput->camera = 0; next.fpgaInput->sourceGeneration = 71; next.fpgaInput->tag = next.tag;
            lossPipeline.submitFrame(next);
            ok &= check(until([&] { return lossLog.hasOutput(model, 71, 2); }, 150), "loss retained source processed");
            for (quint64 id = 3; id <= 7; ++id) {
                lossPipeline.submitFrame(frame(id, 71, 0, 0, true));
                ok &= check(until([&] { return lossLog.hasOutput(model, 71, id); }, 150), "latest blank RAW processed during prefetch");
            }
            ok &= check(testNow() - recent.capturedMs < 250, "blank RAW loss precedes periodic detector age urgency");
            Log::Output lostOutput;
            ok &= check(lossLog.latest(model, 71, lostOutput) && lostOutput.id == 7 && lostOutput.boxes.isEmpty(),
                        "latest RAW target loss published while exact textured source waits");
            ok &= check(until([&] { return lossLog.count() >= 2; }, 650), "latest RAW loss triggers urgent cadence");
            if (lossLog.count() >= 2) {
                QMutexLocker lock(&lossLog.mutex);
                ok &= check(lossLog.requests[1].frameId == 2 && lossLog.requestedAt[1] - lossLog.requestedAt[0] >= 300 &&
                    lossLog.requestedAt[1] - lossLog.requestedAt[0] < 700, "urgent request keeps exact input and minimum interval");
            }
            next.fpgaInput->complete();
            lossPipeline.stop(); lossPipeline.wait();
        }
        for (int transition = 0; transition < 3; ++transition) {
            VisionPipeline idle(options);
            idle.configure(80, 0, false, {model}, {{model, {0}}});
            auto owned = frame(1, 80); owned.fpgaInput = std::make_shared<scheme2::Input>();
            idle.submitFrame(owned);
            std::weak_ptr<scheme2::Input> lifetime = owned.fpgaInput;
            if (transition == 0) idle.configure(81, 1, false, {model}, {{model, {0}}});
            else if (transition == 1) idle.stop();
            else idle.configure(80, 0, false, {});
            { std::lock_guard<std::mutex> lock(owned.fpgaInput->mutex);
              ok &= check(owned.fpgaInput->retired, "switch stop and empty models complete unsubmitted input"); }
            owned.fpgaInput.reset();
            ok &= check(lifetime.expired(), "transition releases retained ownership without worker start");
        }
    }
    {
        VisionOptions options; options.maxTracks = 1; options.trackingIntervalMs = 0;
        options.trackingMaxDetectionAgeMs = 1400;
        const QString first = QStringLiteral("vehicle1"), second = QStringLiteral("vehicle2");
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(30, 0, false, {first, second}, {{first, {0}}, {second, {0}}}); pipeline.start();
        const auto source = frame(1, 30); pipeline.submitFrame(source);
        ok &= check(until([&] { return log.count() == 1; }), "zero-budget model request reserved");
        pipeline.submitDetections(second, 30, 1, {target()}, 1);
        ok &= check(until([&] { return log.hasOutput(second, 30, 1, true); }), "zero-budget vehicle detection remains visible");
        Log::Output value;
        if (log.latest(second, 30, value))
            ok &= check(value.boxes.size() == 1 && value.boxes[0].cls == 0 && value.boxes[0].trackId == 0 &&
                !value.boxes[0].predicted && value.boxes[0].matchScore == 0 && !std::isfinite(value.boxes[0].depthMeters) &&
                value.boxes[0].x1 == 200 && value.boxes[0].y1 == 230 &&
                value.boxes[0].validUntilMs == source.capturedMs + 1400, "zero-budget raw vehicle has source TTL and no template metadata");
        pipeline.submitFrame(frame(2, 30, 0, 12));
        ok &= check(until([&] { return log.hasOutput(second, 30, 2, true); }), "zero-budget vehicle survives next frame");
        if (log.latest(second, 30, value))
            ok &= check(value.boxes[0].trackId == 0 && value.boxes[0].x1 == 200 &&
                value.boxes[0].validUntilMs == source.capturedMs + 1400, "zero-budget vehicle neither follows image nor renews TTL");
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& text : log.diagnostics)
                if (text.contains(QStringLiteral("vehicle_tracks=0 nonvehicle_outputs=0 vehicle_only=1")) &&
                    text.contains(QStringLiteral("tracker_models=1 raw_outputs=1"))) return true;
            return false;
        }, 1200), "raw vehicle diagnostics do not count it as nonvehicle or allocate second tracker");
        pipeline.stop(); pipeline.wait();
    }
    for (int mode = 0; mode < 3; ++mode) {
        // mode 0: tracked model nonvehicle; 1: --no-tracking; 2: vehicle
        // source snapshot evicted. Eight later frames arrive at 40ms cadence.
        VisionOptions options; options.trackingIntervalMs = 0; options.tracking = mode != 1;
        options.trackingMaxDetectionAgeMs = 650;
        options.detectionIntervalMs = options.minimumDetectionIntervalMs = 1000;
        const int generation = 31 + mode;
        const QString model = QStringLiteral("evicted");
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(generation, 0, false, {model}, {{model, {0}}}); pipeline.start();
        const auto source = frame(1, generation); pipeline.submitFrame(source);
        ok &= check(until([&] { return log.count() == 1; }), "history eviction source request reserved");
        for (quint64 id = 2; id <= 9; ++id) {
            QThread::msleep(40); pipeline.submitFrame(frame(id, generation, 0, int(id - 1) * 2));
            if (options.tracking)
                ok &= check(until([&] { return log.hasOutput(model, generation, id); }, 100), "history eviction processes every later frame");
        }
        QThread::msleep(25);
        ok &= check(testNow() - source.capturedMs < 1000, "history eviction reply remains under maximum source age");
        Detection raw = target(); if (mode == 0) raw.cls = 7;
        raw.trackId = 999; raw.predicted = true; raw.matchScore = 0.9f; raw.depthMeters = 3;
        pipeline.submitDetections(model, generation, 1, {raw}, 1);
        ok &= check(until([&] {
            Log::Output value;
            return log.latest(model, generation, value) && value.boxes.size() == 1;
        }, 150), "evicted source reply still publishes raw detection");
        Log::Output value;
        if (log.latest(model, generation, value) && value.boxes.size() == 1) {
            const auto& d = value.boxes[0];
            ok &= check(d.cls == raw.cls && d.trackId == 0 && !d.predicted && d.matchScore == 0 &&
                !std::isfinite(d.depthMeters) && d.depthCapturedMs == 0 && d.x1 == raw.x1 && d.y1 == raw.y1 &&
                d.validUntilMs == source.capturedMs + 650, "evicted raw reply preserves source TTL and clears tracking/depth");
        }
        {
            QMutexLocker lock(&log.mutex);
            ok &= check(log.accepted.size() == 1 && log.accepted[0].id == source.frameId &&
                log.accepted[0].boxes.size() == 1 && !log.accepted[0].boxes[0].predicted &&
                log.accepted[0].boxes[0].validUntilMs == source.capturedMs + 650,
                "accepted detector evidence is emitted once with authoritative source TTL");
        }
        if (options.tracking) {
            pipeline.submitFrame(frame(10, generation, 0, 24));
            ok &= check(until([&] { return log.hasOutput(model, generation, 10, true); }, 100), "history fallback persists on subsequent tracking frame");
            if (log.latest(model, generation, value) && value.boxes.size() == 1)
                ok &= check(value.boxes[0].trackId == 0 && value.boxes[0].x1 == raw.x1 &&
                    value.boxes[0].validUntilMs == source.capturedMs + 650, "history-missing vehicle never creates current-image template or renews TTL");
        }
        ok &= check(until([&] {
            Log::Output expired;
            return log.latest(model, generation, expired) && expired.boxes.isEmpty();
        }, 450), "evicted raw reply expires while capture freezes including no-tracking");
        ok &= check(log.acceptedCount() == 1,
            "tracking frames and timer expiry never emit detector confirmation evidence");
        pipeline.stop(); pipeline.wait();
    }
    {
        const VisionOptions defaults;
        ok &= check(defaults.trackingIntervalMs == 33 && defaults.maxTemplateSide == 48,
                    "bounded template and tracking interval defaults");
        for (int invalid : {-1, 201}) {
            VisionOptions options; options.trackingIntervalMs = invalid;
            bool rejected = false;
            try { VisionPipeline pipeline(options); }
            catch (const std::invalid_argument&) { rejected = true; }
            ok &= check(rejected, "invalid tracking interval rejected");
        }
        for (int valid : {0, 33, 200}) {
            VisionOptions options; options.trackingIntervalMs = valid;
            try { VisionPipeline pipeline(options); }
            catch (...) { ok &= check(false, "tracking interval boundary accepted"); }
        }
    }
    {
        VisionOptions options;
        options.trackingIntervalMs = 0;
        options.detectionIntervalMs = 500; options.minimumDetectionIntervalMs = 100;
        options.trackingMaxDetectionAgeMs = 360;
        options.maxTracks = 1;
        const QString model = QStringLiteral("mixed");
        const QString signsModel = QStringLiteral("signs");
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(20, 0, false, {signsModel, model}, {{signsModel, {}}, {model, {0}}}); pipeline.start();
        const auto source = frame(1, 20);
        pipeline.submitFrame(source);
        ok &= check(until([&] { return log.count() == 1; }), "mixed model initial request");
        Detection sign = target(); sign.cls = 7;
        sign.x1 = 20; sign.x2 = 60; sign.y1 = 100; sign.y2 = 140;
        // A reused detector value must have every tracking/depth field scrubbed.
        sign.trackId = 999; sign.matchScore = 0.9f; sign.predicted = true;
        sign.depthMeters = 3; sign.depthAgeMs = 10; sign.depthCapturedMs = source.capturedMs;
        pipeline.submitDetections(model, 20, 1, {target(), sign}, 1);
        ok &= check(until([&] {
            Log::Output value;
            return log.latest(model, 20, value) && value.boxes.size() == 2;
        }), "mixed reply preserves nonvehicle alongside tracked vehicle");
        Log::Output first;
        if (log.latest(model, 20, first) && first.boxes.size() == 2) {
            for (const auto& d : first.boxes) {
                if (d.cls == 0) ok &= check(d.trackId != 0, "sign-only model does not consume the sole vehicle track budget");
                else ok &= check(d.cls == 7 && d.trackId == 0 && !d.predicted && d.matchScore == 0 &&
                    !std::isfinite(d.depthMeters) && d.depthAgeMs == 0 && d.depthCapturedMs == 0 &&
                    d.x1 == sign.x1 && d.y1 == sign.y1 && d.x2 == sign.x2 && d.y2 == sign.y2 &&
                    d.validUntilMs == source.capturedMs + 360, "nonvehicle raw coordinates metadata and source TTL");
            }
        }
        QThread::msleep(45);
        pipeline.submitFrame(frame(2, 20, 0, 4));
        ok &= check(until([&] { return log.hasOutput(model, 20, 2, true); }), "mixed publish on tracking frame");
        Log::Output second;
        if (log.latest(model, 20, second)) {
            bool retained = false;
            for (const auto& d : second.boxes) if (d.cls == 7) {
                retained = true;
                ok &= check(d.x1 == sign.x1 && d.y1 == sign.y1 && d.trackId == 0 &&
                    d.validUntilMs == source.capturedMs + 360, "tracking does not move or renew nonvehicle");
            }
            ok &= check(retained, "nonvehicle retained within TTL");
        }
        ok &= check(until([&] {
            Log::Output value;
            return log.latest(model, 20, value) && value.id == 2 && value.boxes.isEmpty();
        }, 700), "frozen capture expires both vehicle and nonvehicle output");
        const auto replacementSource = frame(3, 20);
        pipeline.submitFrame(replacementSource);
        ok &= check(until([&] { return log.count() == 2; }, 600), "mixed model periodic refresh after expiry");
        if (log.count() >= 2) {
            const auto request = log.request(1);
            sign.cls = 8;
            pipeline.submitDetections(model, 20, request.frameId, {sign}, 1);
            ok &= check(until([&] {
                Log::Output value;
                return log.latest(model, 20, value) && value.boxes.size() == 1 &&
                    value.boxes[0].cls == 8 && value.boxes[0].trackId == 0;
            }), "nonvehicle-only correction replaces raw classes and clears vehicle tracker");
        }
        pipeline.stop(); pipeline.wait();
    }
    {
        // No whitelist: detections remain raw, with periodic discovery and no
        // tracker state. Later model replies replace the entire raw list.
        VisionOptions options; options.trackingIntervalMs = 0;
        options.detectionIntervalMs = 180; options.minimumDetectionIntervalMs = 50;
        options.trackingMaxDetectionAgeMs = 1500;
        const QString model = QStringLiteral("tt100k");
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(21, 0, false, {model}); // exercise the default empty map
        pipeline.start(); const auto source = frame(1, 21); pipeline.submitFrame(source);
        ok &= check(until([&] { return log.count() == 1; }), "no-whitelist model still requests detection");
        Detection sign = target(); sign.cls = 7;
        pipeline.submitDetections(model, 21, 1, {sign}, 1);
        ok &= check(until([&] { return log.hasOutput(model, 21, 1, true); }), "no-whitelist raw result visible");
        QThread::msleep(65); pipeline.submitFrame(frame(2, 21, 0, 0, true));
        ok &= check(until([&] { return log.hasOutput(model, 21, 2, true); }), "sign survives blank vehicle tracker image");
        ok &= check(log.count() == 1, "nonvehicle does not trigger minimum-interval urgency");
        Log::Output raw;
        if (log.latest(model, 21, raw)) {
            ok &= check(raw.boxes.size() == 1 && raw.boxes[0].trackId == 0 &&
                raw.boxes[0].validUntilMs == source.capturedMs + 1500, "absent whitelist forbids all template IDs");
        }
        ok &= check(until([&] { return log.count() == 2; }, 300), "nonvehicle periodic discovery continues");
        if (log.count() >= 2) {
            const auto request = log.request(1);
            Detection replacement = sign; replacement.cls = 8; replacement.x1 = 40;
            pipeline.submitDetections(model, 21, request.frameId, {replacement}, 1);
            ok &= check(until([&] {
                Log::Output value;
                return log.latest(model, 21, value) && value.boxes.size() == 1 && value.boxes[0].cls == 8 &&
                    value.boxes[0].trackId == 0 && value.boxes[0].validUntilMs == request.capturedMs + 1500;
            }), "new nonvehicle classes replace previous raw list");
        }
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& text : log.diagnostics)
                if (text.contains(QStringLiteral("tracker_models=0")) &&
                    text.contains(QStringLiteral("vehicle_tracks=0 nonvehicle_outputs=1 vehicle_only=1"))) return true;
            return false;
        }, 1200), "no whitelist allocates no tracker state and diagnostics confirm vehicle-only policy");
        const int before = log.count();
        pipeline.configure(22, 1, false, {model}, {{model, {}}});
        pipeline.submitFrame(frame(1, 22, 1));
        ok &= check(until([&] { return log.count() == before + 1; }), "raw model source switch requests independently");
        Log::Output switched;
        ok &= check(log.latest(model, 22, switched) && switched.boxes.isEmpty(), "nonvehicle list does not cross source or camera");
        pipeline.submitDetections(model, 21, 2, {sign}, 1);
        pipeline.submitDetections(model, 22, 1, {sign}, 1);
        ok &= check(until([&] { return log.hasOutput(model, 22, 1, true); }), "explicit empty class list preserves raw detection");
        const int beforeModel = log.count();
        const QString nextModel = QStringLiteral("signs2");
        pipeline.configure(22, 1, false, {nextModel}, {});
        pipeline.submitFrame(frame(2, 22, 1));
        ok &= check(until([&] { return log.count() == beforeModel + 1; }), "model switch clears raw model state");
        Log::Output modelSwitched;
        ok &= check(log.latest(nextModel, 22, modelSwitched) && modelSwitched.boxes.isEmpty(), "raw detections do not cross models");
        const int beforeWhitelist = log.count();
        pipeline.configure(22, 1, false, {nextModel}, {{nextModel, {0}}});
        pipeline.submitFrame(frame(3, 22, 1));
        ok &= check(until([&] { return log.count() == beforeWhitelist + 1; }), "whitelist-only configuration advances epoch");
        pipeline.submitDetections(nextModel, 22, 2, {sign}, 1);
        pipeline.inferenceFailed(22, 2);
        QThread::msleep(25);
        Log::Output whitelistSwitched;
        ok &= check(log.count() == beforeWhitelist + 1 && log.latest(nextModel, 22, whitelistSwitched) &&
            whitelistSwitched.boxes.isEmpty(), "old whitelist reply cannot populate or unlock new epoch");
        pipeline.submitDetections(nextModel, 22, 3, {target(), sign}, 1);
        ok &= check(until([&] {
            Log::Output value;
            if (!log.latest(nextModel, 22, value) || value.boxes.size() != 2) return false;
            for (const auto& d : value.boxes) if (d.cls == 0 && d.trackId != 0) return true;
            return false;
        }), "updated whitelist enables only newly corrected vehicles");
        pipeline.stop(); pipeline.wait();
    }
    {
        // Hold a reply across a skipped frame and one processed frame. Compare
        // delayed correction to the same direct tracker sequence and ensure a
        // newer skipped ingress frame cannot suppress the next NPU request.
        VisionOptions options; options.trackingIntervalMs = 120;
        options.detectionIntervalMs = 100; options.minimumDetectionIntervalMs = 100;
        const QString model = QStringLiteral("cadence");
        Log log; VisionPipeline pipeline(options); log.connect(pipeline);
        pipeline.configure(23, 0, false, {model}, {{model, {0}}}); pipeline.start();
        const auto source = frame(1, 23); pipeline.submitFrame(source);
        ok &= check(until([&] { return log.count() == 1; }), "limited tracking initial request");
        auto skipped = frame(2, 23, 0, 4); skipped.capturedMs = source.capturedMs + 10;
        ok &= check(until([&] { return testNow() >= skipped.capturedMs; }, 100), "skipped fixture capture time reached");
        pipeline.submitFrame(skipped); QThread::msleep(25);
        ok &= check(!log.hasOutput(model, 23, 2), "tracking interval skips newer frame without publish");
        ok &= check(until([&] { return testNow() >= source.capturedMs + 135; }, 200), "processed fixture cadence reached");
        const auto processed = frame(3, 23, 0, 12); pipeline.submitFrame(processed);
        ok &= check(until([&] { return log.hasOutput(model, 23, 3); }), "tracking cadence advances processed frame");
        auto newer = frame(4, 23, 0, 16); newer.capturedMs = processed.capturedMs + 10;
        ok &= check(until([&] { return testNow() >= newer.capturedMs; }, 100), "newer ingress capture time reached");
        pipeline.submitFrame(newer); QThread::msleep(25);
        pipeline.submitDetections(model, 23, 1, {target()}, 1);
        ok &= check(until([&] { return log.hasOutput(model, 23, 3, true); }), "delayed reply replays only processed history");
        tdm::TrackerOptions referenceOptions;
        referenceOptions.maxTemplateSide = options.maxTemplateSide;
        referenceOptions.maxDetectionAgeMs = options.trackingMaxDetectionAgeMs;
        tdm::TemplateTracker reference(referenceOptions);
        auto toGray = [](const VisionFrame& f) {
            cv::Mat rgb(f.image.height(), f.image.width(), CV_8UC3,
                const_cast<uchar*>(f.image.constBits()), f.image.bytesPerLine());
            cv::Mat result; cv::cvtColor(rgb, result, cv::COLOR_RGB2GRAY); return result;
        };
        reference.update(toGray(source), source.capturedMs);
        reference.correct(toGray(source), {{0, 0.95f, cv::Rect2f(200, 150, 80, 80)}}, source.capturedMs);
        const auto expected = reference.update(toGray(processed), processed.capturedMs);
        Log::Output corrected;
        if (log.latest(model, 23, corrected)) {
            ok &= check(expected.size() == 1 && corrected.id == 3 && corrected.boxes.size() == 1 &&
                corrected.boxes[0].trackId != 0 &&
                std::abs(corrected.boxes[0].x1 - expected[0].box.x) < 0.01f &&
                std::abs(corrected.boxes[0].y1 - expected[0].box.y - 80) < 0.01f &&
                std::abs(corrected.boxes[0].matchScore - expected[0].matchScore) < 0.001f &&
                corrected.boxes[0].validUntilMs == source.capturedMs + options.trackingMaxDetectionAgeMs,
                "limited history replay equals direct tracker and preserves source TTL");
        }
        ok &= check(until([&] { return log.count() == 2; }, 100), "newer skipped input does not starve snapshot NPU request");
        if (log.count() >= 2) {
            ok &= check(log.request(1).frameId == 3, "request uses processed snapshot despite newer input");
            pipeline.inferenceFailed(23, log.request(1).frameId);
        }
        ok &= check(until([&] { return testNow() >= processed.capturedMs + 140; }, 200), "next cadence frame time reached");
        const auto next = frame(5, 23, 0, 20); pipeline.submitFrame(next);
        ok &= check(until([&] { return log.count() == 3; }, 200), "fixed cadence requests continue after skipped frames");
        {
            QMutexLocker lock(&log.mutex);
            if (log.requestedAt.size() >= 3)
                ok &= check(log.requestedAt[1] - log.requestedAt[0] >= 100 &&
                    log.requestedAt[2] - log.requestedAt[1] >= 100, "snapshot request cadence honors minimum interval");
            for (const auto& value : log.outputs)
                ok &= check(value.id != 2 && value.id != 4, "skipped frames never become current output frame");
        }
        pipeline.stop(); pipeline.wait();
    }
    {
        VisionOptions options; options.trackingIntervalMs = 0;
        ok &= check(!options.stereoEnabled() && options.stereoCameraMask() == 0 &&
                    options.primaryStereoLeft() == -1, "stereo requires explicit configuration");
        options.stereoLeft = 0; options.stereoRight = 1;
        options.calibrationPath = QStringLiteral("legacy.yml");
        options.synchronizationConfirmed = options.hasTagOffset = true; options.tagOffset = -2;
        const auto legacy = options.stereoPairs();
        ok &= check(legacy.size() == 1 && legacy.front().calibrationPath == options.calibrationPath &&
                    legacy.front().tagOffset == -2 && legacy.front().synchronizationConfirmed &&
                    legacy.front().hasTagOffset && legacy.front().intervalMs == 0,
                    "legacy pair retains calibration and synchronization with inherited interval");
        options.stereoGroups = {{0, 1, {}, false, false, 0}, {4, 5, {}, true, true, 3}};
        ok &= check(options.stereoPairs().size() == 2 && options.stereoCameraMask() == 0x33 &&
                    options.primaryStereoLeft() == 0 && options.stereoSummary().contains(QStringLiteral("C5/C6")) &&
                     options.stereoPairs().front().calibrationPath.isEmpty(), "explicit groups override legacy without leaking calibration");
        ok &= check(options.stereoGroups[0].intervalMs == 0 && options.stereoGroups[1].intervalMs == 0,
                    "six-field aggregate initialization inherits global interval");
        for (int invalid : {-1, 1, 99, 5001}) {
            options.stereoGroups[1].intervalMs = invalid;
            ok &= check(options.stereoConfigurationError().contains(QStringLiteral("intervalMs")) &&
                        options.stereoPairs().empty() && options.stereoCameraMask() == 0,
                        "invalid group interval rejects entire configuration");
        }
        for (int valid : {0, 100, 5000}) {
            options.stereoGroups[1].intervalMs = valid;
            ok &= check(options.stereoConfigurationError().isEmpty() && options.stereoPairs().size() == 2 &&
                        options.stereoPairs()[1].intervalMs == valid, "group interval boundaries accepted and retained");
        }
        options.stereoGroups[1].intervalMs = 0;
        options.stereoGroups[1].left = 1;
        ok &= check(!options.stereoConfigurationError().isEmpty() && !options.stereoEnabled(),
                    "overlapping stereo cameras rejected");
        options.stereoGroups[1].left = 6;
        ok &= check(!options.stereoConfigurationError().isEmpty() && options.stereoCameraMask() == 0,
                    "out of range stereo camera rejected before mask shift");
        options.stereoGroups = {{0, 1, {}, false, false, 0}, {2, 3, {}, false, false, 0}, {4, 5, {}, false, false, 0}};
        ok &= check(!options.stereoConfigurationError().isEmpty() && !options.stereoEnabled(),
                    "more than two stereo groups rejected");
    }
    {
        // A real worker, direct observation of Qt signals: no event loop, NPU,
        // display server, PCIe or model files are needed.
        VisionOptions options; options.trackingIntervalMs = 0;
        options.detectionIntervalMs = 220; options.minimumDetectionIntervalMs = 80;
        Log log;
        VisionPipeline pipeline(options);
        log.connect(pipeline); pipeline.configure(1, 0, false, {QStringLiteral("a"), QStringLiteral("b")},
            {{QStringLiteral("a"), {0}}, {QStringLiteral("b"), {0}}});
        pipeline.start();
        pipeline.submitFrame(frame(1));
        ok &= check(until([&] { return log.count() == 1; }), "initial request");
        if (log.count() != 1) { pipeline.stop(); pipeline.wait(); return false; }
        // Hold detection while later frames arrive. Only the source snapshot
        // can be corrected; replay must move the original x=200 target.
        for (int i = 2; i <= 4; ++i) {
            QThread::msleep(22); pipeline.submitFrame(frame(i, 1, 0, (i - 1) * 4));
        }
        ok &= check(log.count() == 1, "one outstanding request");
        pipeline.submitDetections(QStringLiteral("a"), 1, 1, {target()}, 12);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("a"), 1, 4, true); }), "frameId history replay");
        uint64_t id = 0;
        {
            QMutexLocker lock(&log.mutex);
            bool moved = false;
            for (const auto& o : log.outputs) if (o.model == QStringLiteral("a") && o.id == 4 && !o.boxes.isEmpty()) {
                const auto& d = o.boxes.front(); id = d.trackId;
                moved = d.x1 > 207 && d.x1 < 219 && d.y1 > 225 && d.y1 < 235 && d.matchScore >= 0.65f;
            }
            ok &= check(moved && id != 0, "replay moves box and restores model padding");
        }
        pipeline.submitFrame(frame(5, 1, 0, 16));
        QThread::msleep(30);
        ok &= check(log.count() == 1, "strong tracking low frequency");
        // Weak/lost tracking may request earlier, but never before minimum.
        pipeline.submitFrame(frame(6, 1, 0, 0, true));
        ok &= check(until([&] { return log.count() >= 2; }, 190), "weak early request");
        if (log.count() >= 2) {
            QMutexLocker lock(&log.mutex);
            ok &= check(log.requestedAt[1] - log.requestedAt[0] >= 80 &&
                        log.requestedAt[1] - log.requestedAt[0] < 220, "early minimum interval");
        }
        // A full empty detection result clears a model without stopping
        // periodic discovery of new objects.
        if (log.count() >= 2) {
            const auto req = log.request(1);
            pipeline.submitDetections(QStringLiteral("a"), 1, req.frameId, {}, 10);
            ok &= check(until([&] { return log.hasOutput(QStringLiteral("a"), 1, req.frameId); }), "empty correction");
        }
        QThread::msleep(90); pipeline.submitFrame(frame(7, 1, 0, 0, true));
        QThread::msleep(25);
        ok &= check(log.count() == 2, "empty scene uses periodic interval");
        QThread::msleep(130); pipeline.submitFrame(frame(8, 1, 0, 0, true));
        ok &= check(until([&] { return log.count() >= 3; }), "empty scene periodic discovery");
        pipeline.stop(); pipeline.wait();
    }
    {
        VisionOptions options; options.tracking = false;
        // This fixture deliberately checks the single-slot request counts.
        const bool hadCapacity=qEnvironmentVariableIsSet("ADS_ASYNC_INFLIGHT");
        const QByteArray savedCapacity=qgetenv("ADS_ASYNC_INFLIGHT");
        qputenv("ADS_ASYNC_INFLIGHT","1");
        Log log; VisionPipeline pipeline(options);
        if(hadCapacity) qputenv("ADS_ASYNC_INFLIGHT",savedCapacity);
        else qunsetenv("ADS_ASYNC_INFLIGHT");
        log.connect(pipeline); pipeline.configure(1, 0, false, {QStringLiteral("a")}, {{QStringLiteral("a"), {0}}});
        pipeline.start(); pipeline.submitFrame(frame(1));
        ok &= check(until([&] { return log.count() == 1; }), "unthrottled first request");
        // Burst frames are overwritten in two slots. Once the ack arrives the
        // worker requests the newest frame, never drains a FIFO of 100 images.
        const QImage shared = fixture();
        for (quint64 i = 2; i <= 101; ++i) {
            auto f = frame(i); f.image = shared; pipeline.submitFrame(f);
        }
        ok &= check(log.count() == 1, "bounded mailbox while outstanding");
        pipeline.inferenceFailed(1, 1);
        ok &= check(until([&] { return log.count() == 2; }), "failed inference releases request");
        if (log.count() >= 2) ok &= check(log.request(1).frameId == 101, "latest frame replaces burst");
        // Source/model reconfiguration must reject the old callback even when
        // it arrives while another request is outstanding.
        pipeline.configure(2, 1, false, {QStringLiteral("b")}, {{QStringLiteral("b"), {0}}});
        pipeline.submitFrame(frame(1, 2, 1));
        ok &= check(until([&] { return log.count() == 3; }), "source reset requests new camera");
        const int before = log.outputCount();
        pipeline.submitDetections(QStringLiteral("a"), 1, 101, {target()}, 10);
        pipeline.inferenceFailed(1, 101);
        QThread::msleep(30);
        ok &= check(log.outputCount() == before && log.count() == 3, "old source cannot release new request");
        pipeline.submitDetections(QStringLiteral("b"), 2, 1, {}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("b"), 2, 1); }), "new source result accepted");
        pipeline.submitFrame(frame(2, 2, 1));
        ok &= check(until([&] { return log.count() == 4; }), "no tracking bypasses interval");
        pipeline.configure(2, 1, false, {QStringLiteral("c")}, {{QStringLiteral("c"), {0}}});
        pipeline.submitFrame(frame(3, 2, 1));
        ok &= check(until([&] { return log.count() == 5; }), "model reset within source");
        pipeline.submitDetections(QStringLiteral("b"), 2, 2, {target()}, 10);
        pipeline.inferenceFailed(2, 2);
        QThread::msleep(25);
        ok &= check(log.count() == 5, "old model frame does not unlock new frame");
        // Wait for the 2s watchdog, then prove an old frame cannot acknowledge
        // the newer request from this same epoch.
        pipeline.submitFrame(frame(4, 2, 1));
        QThread::msleep(2050);
        // Refresh host age; the old retained image is deliberately not reused.
        pipeline.submitFrame(frame(5, 2, 1));
        ok &= check(until([&] { return log.count() == 6; }), "timeout releases outstanding");
        pipeline.submitDetections(QStringLiteral("c"), 2, 3, {target()}, 10);
        pipeline.inferenceFailed(2, 3); pipeline.submitFrame(frame(6, 2, 1));
        QThread::msleep(30);
        ok &= check(log.count() == 6, "late timed out frame cannot unlock newer request");
        if (log.count() >= 6) {
            const auto req = log.request(5);
            pipeline.inferenceFailed(2, req.frameId);
            ok &= check(until([&] { return log.count() == 7; }), "current ack releases newer request");
        }
        pipeline.stop(); pipeline.wait();
    }
    if (qgetenv("ADS_TRUE_ASYNC") == "1") {
        VisionOptions options; options.tracking=false; options.motionEnabled=false;
        const bool hadCapacity=qEnvironmentVariableIsSet("ADS_ASYNC_INFLIGHT");
        const QByteArray savedCapacity=qgetenv("ADS_ASYNC_INFLIGHT");
        qputenv("ADS_ASYNC_INFLIGHT","2");
        Log log; VisionPipeline pipeline(options);
        if(hadCapacity) qputenv("ADS_ASYNC_INFLIGHT",savedCapacity);
        else qunsetenv("ADS_ASYNC_INFLIGHT");
        log.connect(pipeline);
        pipeline.configure(90,0,false,{QStringLiteral("a")});
        pipeline.start(); pipeline.submitFrame(frame(1,90));
        ok &= check(until([&]{return log.count()==1;}),"async first slot");
        pipeline.submitFrame(frame(2,90));
        ok &= check(until([&]{return log.count()==2;}),"async second slot before first completes");
        pipeline.submitFrame(frame(3,90));
        QThread::msleep(40);
        ok &= check(log.count()==2,"async capacity bounds submissions");
        pipeline.inferenceFailed(89,1);
        pipeline.submitDetections(QStringLiteral("a"),89,1,{},1);
        QThread::msleep(40);
        ok &= check(log.count()==2,"async wrong generation cannot retire a slot");
        pipeline.inferenceFailed(90,1);
        ok &= check(until([&]{return log.count()==3;}),"async matching ack frees exactly one slot");
        pipeline.submitFrame(frame(4,90));
        pipeline.inferenceFailed(90,1);
        pipeline.submitDetections(QStringLiteral("a"),90,1,{},1);
        QThread::msleep(40);
        ok &= check(log.count()==3,"async late retired reply cannot unlock newer frames");
        pipeline.inferenceFailed(90,2);
        ok &= check(until([&]{return log.count()==4;}),"async second ack releases next frame");
        // 异步回调必须显式携带epoch；相同数字帧不能跨epoch回收。
        pipeline.configure(90,0,false,{QStringLiteral("a")});
        pipeline.submitFrame(frame(5,90));
        ok &= check(until([&]{return log.count()==5;}),"async new epoch first slot");
        pipeline.inferenceFailed(90,5);
        QThread::msleep(40);
        ok &= check(log.count()==5,"async missing epoch failure cannot retire slot");
        pipeline.submitDetections(QStringLiteral("a"),90,5,{},1,1);
        QThread::msleep(40);
        ok &= check(log.count()==5,"async missing epoch result cannot retire slot");
        pipeline.configure(90,0,false,{QStringLiteral("a")});
        pipeline.submitFrame(frame(6,90));
        ok &= check(until([&]{return log.count()==6;}),"async same frame new epoch");
        pipeline.inferenceFailed(90,6,2);
        pipeline.submitDetections(QStringLiteral("a"),90,6,{},1,2);
        QThread::msleep(40);
        ok &= check(log.count()==6,"async old epoch failure and result isolated");
        pipeline.inferenceFailed(90,6,3);
        pipeline.submitFrame(frame(7,90));
        ok &= check(until([&]{return log.count()==7;}),"async explicit current epoch releases");
        pipeline.stop(); pipeline.wait();
    }
    {
        VisionOptions options; options.trackingIntervalMs = 0;
        options.stereoLeft = 2; options.stereoRight = 4;
        options.stereoIntervalMs = 40;
        Log log; VisionPipeline pipeline(options);
        log.connect(pipeline); pipeline.configure(3, 2, true, {QStringLiteral("lane")}, {});
        pipeline.start(); pipeline.submitFrame(frame(1, 3, 2)); pipeline.submitFrame(frame(1, 3, 4));
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            return log.stereoPreviews > 0 && std::any_of(log.stereo.begin(), log.stereo.end(), [](const QString& s) {
                return s.contains(QStringLiteral("not calibrated")) && s.contains(QStringLiteral("sync unconfirmed"));
            });
        }), "uncalibrated and unconfirmed stereo forbids meters");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereo) ok &= check(!s.contains(QStringLiteral(" m;")), "no metric status without calibration");
        }
        ok &= check(until([&] { return log.count() == 1; }), "lane request");
        pipeline.inferenceFailed(3, 1); pipeline.submitFrame(frame(2, 3, 2));
        ok &= check(until([&] { return log.count() == 2; }), "lane ack and unthrottled request");
        pipeline.stop(); pipeline.wait();
    }
    {
        // Simulation only: fx=400px, baseline=0.1m, disparity=20px => Z=2m.
        // Two independent calibrations: identical pixels, baselines 0.1/0.2m
        // must produce 2/4m respectively. All calibration is synthetic.
        QTemporaryFile calibrationFile, secondCalibration;
        if (!check(calibrationFile.open() && secondCalibration.open(), "temporary simulated calibrations")) return false;
        calibrationFile.close(); secondCalibration.close();
        writeCalibration(calibrationFile.fileName(), 0.1);
        writeCalibration(secondCalibration.fileName(), 0.2);
        cv::Mat leftPixels(480, 640, CV_8UC1), rightPixels(480, 640, CV_8UC1);
        cv::RNG random(99271);
        random.fill(leftPixels, cv::RNG::UNIFORM, 0, 256);
        cv::GaussianBlur(leftPixels, leftPixels, {3, 3}, 0.7);
        rightPixels.setTo(0);
        leftPixels(cv::Rect(20, 0, 620, 480)).copyTo(rightPixels(cv::Rect(0, 0, 620, 480)));
        auto pixels = [](const cv::Mat& image) {
            cv::Mat rgb; cv::cvtColor(image, rgb, cv::COLOR_GRAY2RGB);
            return QImage(rgb.data, rgb.cols, rgb.rows, int(rgb.step), QImage::Format_RGB888).copy();
        };
        // Vehicle near the top is at 2m; the center diagnostic is a separate
        // 1m plane. A center-derived label on the vehicle must fail this test.
        cv::Mat twoPlanes(480, 640, CV_8UC1, cv::Scalar(0));
        leftPixels(cv::Rect(40, 0, 600, 480)).copyTo(twoPlanes(cv::Rect(0, 0, 600, 480)));
        leftPixels(cv::Rect(20, 0, 620, 160)).copyTo(twoPlanes(cv::Rect(0, 0, 620, 160)));
        Detection vehicle = target();
        vehicle.x1 = 200; vehicle.x2 = 360; vehicle.y1 = 110; vehicle.y2 = 230;
        Detection weaker = vehicle; weaker.score = 0.5f; weaker.y1 = 260; weaker.y2 = 400;
        Detection person = vehicle; person.cls = 7; person.score = 0.99f;
        person.depthMeters = 99; person.depthTrial = true; person.depthStatus = QStringLiteral("injected");
        Detection zebra = person; zebra.cls = 8;
        const QString trialModel = QStringLiteral("vehicle-trial");
        for (int scenario = 0; scenario < 8; ++scenario) {
            // 0: disparity after raw reply; 1: disparity before delayed reply,
            // pending source no longer in ingress slots; 2: normal unsynced;
            // 3: vehicle flag alone; 4: expired disparity before reply;
            // 5: source history evicted, raw fallback; 6: tracking correction;
            // 7: blank pair has insufficient disparity.
            VisionOptions diagnostic;
            diagnostic.tracking = scenario == 6; diagnostic.trackingIntervalMs = 0;
            diagnostic.maxTracks = 1; diagnostic.stereoLeft = 0; diagnostic.stereoRight = 1;
            diagnostic.calibrationPath = calibrationFile.fileName();
            diagnostic.stereoIntervalMs = 40;
            diagnostic.stereoTrialMeters = scenario != 3;
            diagnostic.stereoVehicleTrial = scenario != 2;
            diagnostic.detectionIntervalMs = diagnostic.minimumDetectionIntervalMs = 1000;
            if (scenario == 6) diagnostic.detectionIntervalMs = diagnostic.minimumDetectionIntervalMs = 1;
            const int generation = 100 + scenario;
            Log trialLog; VisionPipeline probe(diagnostic); trialLog.connect(probe);
            probe.configure(generation, 0, false, {trialModel}, {{trialModel, {0}}}); probe.start();
            auto a = frame(1, generation, 0); a.image = pixels(leftPixels);
            auto b = frame(1, generation, 1); b.image = pixels(twoPlanes);
            if (scenario == 7) { a.image.fill(Qt::black); b.image.fill(Qt::black); }
            probe.submitFrame(a);
            ok &= check(until([&] { return trialLog.count() == 1; }), "vehicle trial source request");
            if (scenario == 0 || scenario == 2 || scenario == 3) {
                probe.submitDetections(trialModel, generation, 1, {weaker, person, vehicle, zebra}, 1);
                ok &= check(until([&] { return trialLog.hasOutput(trialModel, generation, 1, true); }),
                            "vehicle raw reply before disparity");
            }
            if (scenario == 1) {
                // Keep the original source in bounded history, but evict it
                // from both ingress slots before the right camera arrives.
                for (quint64 id = 2; id <= 3; ++id) {
                    auto newer = frame(id, generation, 0); newer.image = a.image;
                    probe.submitFrame(newer); QThread::msleep(22);
                }
            }
            probe.submitFrame(b);
            ok &= check(until([&] { return trialLog.hasPreview(generation, 1); }),
                        "stereo prefers exact pending source over newer ingress");
            if (scenario != 2 && scenario != 3 && scenario != 7) {
                QMutexLocker lock(&trialLog.mutex);
                bool centerIsOne = false;
                for (const auto& preview : trialLog.stereoOutputs)
                    centerIsOne |= preview.preview && preview.status.contains(QStringLiteral("试用 Z=1.00 米"));
                ok &= check(centerIsOne, "two-plane fixture center independently measures 1m");
            }
            if (scenario == 4)
                ok &= check(until([&] { return testNow() - a.capturedMs > 330; }, 400), "trial result expires before NPU reply");
            if (scenario == 5) {
                for (quint64 id = 2; id <= 9; ++id) {
                    auto newer = frame(id, generation, 0); newer.image = a.image;
                    probe.submitFrame(newer); QThread::msleep(12);
                }
            }
            if (scenario != 0 && scenario != 2 && scenario != 3)
                probe.submitDetections(trialModel, generation, 1, {weaker, person, vehicle, zebra}, 1);
            const bool expectDepth = scenario == 0 || scenario == 1 || scenario == 5 || scenario == 6;
            ok &= check(until([&] {
                Log::Output value;
                if (!trialLog.latest(trialModel, generation, value) || value.boxes.isEmpty()) return false;
                for (const auto& d : value.boxes) if (d.cls == 0)
                    return std::isfinite(d.depthMeters) == expectDepth;
                return false;
            }, 200), "vehicle depth requires both trial flags and unexpired exact source");
            Log::Output value;
            if (trialLog.latest(trialModel, generation, value)) {
                int vehicleCount = 0;
                for (const auto& d : value.boxes) {
                    if (d.cls == 0) {
                        ++vehicleCount;
                        if (expectDepth)
                            ok &= check(std::abs(d.depthMeters - 2.0) < 0.08 && d.depthTrial &&
                                d.depthStatus.contains(QStringLiteral("试用")) &&
                                d.depthStatus.contains(QStringLiteral("车辆ROI")) &&
                                d.depthCapturedMs == a.capturedMs && d.validUntilMs == a.capturedMs + 2000,
                                "vehicle uses 2m ROI rather than 1m center and source TTL");
                        else ok &= check(!std::isfinite(d.depthMeters) && !d.depthTrial && d.depthCapturedMs == 0 &&
                            !d.depthStatus.isEmpty(), "invalid vehicle clears metric and trial marker");
                        if (scenario == 7) ok &= check(d.depthStatus == QStringLiteral("有效视差不足"),
                            "same-frame blank ROI reports insufficient disparity");
                    } else ok &= check(!std::isfinite(d.depthMeters) && !d.depthTrial && d.depthCapturedMs == 0 &&
                        d.depthStatus.isEmpty(), "person and zebra never receive vehicle depth");
                }
                if (diagnostic.stereoVehicleTrial)
                    ok &= check(vehicleCount == 1, "trial selects highest score whitelisted vehicle only");
                if (!diagnostic.tracking) ok &= check(value.id == 1, "raw publication retains exact detection source frame");
            }
            if (scenario == 6) {
                auto nextLeft = frame(2, generation, 0); nextLeft.image = a.image;
                auto nextRight = frame(2, generation, 1); nextRight.image = b.image;
                probe.submitFrame(nextLeft); probe.submitFrame(nextRight);
                ok &= check(until([&] { return trialLog.count() == 2 && trialLog.hasPreview(generation, 2); }),
                            "tracking correction source has cached disparity");
                // The previous track was measured at 2m on this same source.
                // An authoritative reply moves it onto the 1m plane.
                Detection moved = vehicle; moved.y1 = 270; moved.y2 = 410;
                probe.submitDetections(trialModel, generation, 2, {moved}, 1);
                ok &= check(until([&] {
                    Log::Output corrected;
                    return trialLog.latest(trialModel, generation, corrected) && corrected.id == 2 &&
                        corrected.boxes.size() == 1 && std::abs(corrected.boxes[0].depthMeters - 1.0) < 0.08 &&
                        corrected.boxes[0].depthTrial && corrected.boxes[0].y1 == moved.y1 &&
                        corrected.boxes[0].validUntilMs == nextLeft.capturedMs + 2000;
                }, 200), "authoritative correction remeasures original ROI before replay instead of carrying old depth");
            }
            if (scenario == 1) {
                ok &= check(until([&] { return trialLog.count() == 2; }), "new raw source requested after delayed reply");
                if (trialLog.count() >= 2) {
                    const auto unpairedSource = trialLog.request(1);
                    probe.submitDetections(trialModel, generation, unpairedSource.frameId, {vehicle}, 1);
                    ok &= check(until([&] {
                        Log::Output unpaired;
                        return trialLog.latest(trialModel, generation, unpaired) && unpaired.id == unpairedSource.frameId &&
                            unpaired.boxes.size() == 1 && !std::isfinite(unpaired.boxes[0].depthMeters) &&
                            !unpaired.boxes[0].depthTrial && unpaired.boxes[0].depthStatus == QStringLiteral("等待同帧双目");
                    }, 150), "fresh disparity for old source cannot label newer raw detection");
                }
            }
            if (scenario == 0 || scenario == 6) {
                ok &= check(until([&] {
                    Log::Output expired;
                    if (!trialLog.latest(trialModel, generation, expired) || expired.boxes.isEmpty()) return false;
                    for (const auto& d : expired.boxes) if (d.cls == 0)
                        return !std::isfinite(d.depthMeters) && !d.depthTrial && d.depthCapturedMs == 0 &&
                               d.depthStatus == QStringLiteral("等待同帧双目");
                    return false;
                }, 400), "frozen capture actively clears vehicle depth at 300ms while keeping raw TTL");
            }
            if (scenario == 0) {
                auto nextLeft = frame(2, generation, 0); nextLeft.image = a.image;
                probe.submitFrame(nextLeft);
                ok &= check(until([&] { return trialLog.count() == 2; }), "unpaired next source request");
                probe.submitDetections(trialModel, generation, 2, {vehicle}, 1);
                ok &= check(until([&] {
                    Log::Output unpaired;
                    return trialLog.latest(trialModel, generation, unpaired) && unpaired.id == 2 &&
                        unpaired.boxes.size() == 1 && !std::isfinite(unpaired.boxes[0].depthMeters) &&
                        !unpaired.boxes[0].depthTrial && unpaired.boxes[0].depthStatus == QStringLiteral("等待同帧双目");
                }), "new detection source cannot sample old left disparity or renew its depth TTL");
            }
            // Reconfigure within the same source generation. Restarting frame
            // numbering is deliberately avoided; old disparity must still be
            // invalidated even when the selected camera and model stay equal.
            const int beforeReset = trialLog.count();
            probe.configure(generation, 0, false, {trialModel}, {{trialModel, {0}}});
            auto replacement = frame(20, generation, 0); replacement.image = a.image;
            probe.submitFrame(replacement);
            ok &= check(until([&] { return trialLog.count() == beforeReset + 1; }), "vehicle source epoch reset request");
            probe.submitDetections(trialModel, generation, 20, {vehicle}, 1);
            ok &= check(until([&] {
                Log::Output fresh;
                return trialLog.latest(trialModel, generation, fresh) && fresh.id == 20 && fresh.boxes.size() == 1 &&
                    !std::isfinite(fresh.boxes[0].depthMeters) && !fresh.boxes[0].depthTrial &&
                    fresh.boxes[0].depthStatus == (scenario == 2 || scenario == 3 ?
                        QStringLiteral("双目同步未确认") : QStringLiteral("等待同帧双目"));
            }), "source or correction never inherits previous vehicle depth");
            probe.stop(); probe.wait();
        }
        for (bool trial : {false, true}) {
            VisionOptions diagnostic;
            diagnostic.stereoLeft = 0; diagnostic.stereoRight = 1;
            diagnostic.calibrationPath = calibrationFile.fileName();
            diagnostic.stereoTrialMeters = trial; diagnostic.stereoIntervalMs = 40;
            Log trialLog; VisionPipeline probe(diagnostic);
            trialLog.connect(probe); probe.configure(90, 0, false, {}); probe.start();
            auto a = frame(1, 90, 0); auto b = frame(2, 90, 1);
            a.image = pixels(leftPixels); b.image = pixels(rightPixels);
            probe.submitFrame(a); probe.submitFrame(b);
            ok &= check(until([&] { return trialLog.hasPreview(90, 1); }), "trial preview on calibrated static pair");
            {
                QMutexLocker lock(&trialLog.mutex);
                bool marked = false;
                for (const auto& output : trialLog.stereoOutputs) {
                    marked |= output.status.contains(QStringLiteral("试用 Z=2.00 米")) &&
                              output.status.contains(QStringLiteral("同步未确认"));
                    if (!trial) ok &= check(!output.status.contains(QStringLiteral(" m;")) &&
                        !output.status.contains(QStringLiteral("试用 Z=")), "normal mode still requires synchronization for meters");
                }
                if (trial) ok &= check(marked, "trial meters explicitly marked without confirming sync");
            }
            if (trial) ok &= check(until([&] {
                QMutexLocker lock(&trialLog.mutex);
                for (const auto& output : trialLog.stereoOutputs)
                    if (!output.preview && output.status.contains(QStringLiteral("no fresh corresponding pair"))) return true;
                return false;
            }, 1500), "frozen trial pair clears its previous measurement");
            probe.stop(); probe.wait();
        }
        VisionOptions options; options.trackingIntervalMs = 0;
        options.stereoGroups = {
            {0, 1, calibrationFile.fileName(), true, true, 0},
            {4, 5, secondCalibration.fileName(), true, true, 3}};
        options.stereoIntervalMs = 40;
        options.detectionIntervalMs = 500;
        Log log; VisionPipeline pipeline(options);
        log.connect(pipeline); pipeline.configure(4, 0, false, {QStringLiteral("sim")}, {{QStringLiteral("sim"), {0}}});
        auto left = frame(10, 4, 0); left.image = pixels(leftPixels); left.tag = 77;
        pipeline.start(); pipeline.submitFrame(left);
        ok &= check(until([&] { return log.count() == 1; }), "simulated left detection request");
        Detection d = target(); d.x1 = 200; d.x2 = 360; d.y1 = 240; d.y2 = 400;
        pipeline.submitDetections(QStringLiteral("sim"), 4, 10, {d}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("sim"), 4, 10, true); }), "simulated target initialized");
        auto right = frame(11, 4, 1); right.image = pixels(rightPixels); right.tag = 78;
        pipeline.submitFrame(right);
        QThread::msleep(30);
        {
            QMutexLocker lock(&log.mutex);
            ok &= check(log.stereoPreviews == 0, "mismatched exposure IDs do not produce calibrated depth");
        }
        right.frameId = 12; right.tag = 77; right.capturedMs = testNow();
        pipeline.submitFrame(right);
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& o : log.outputs)
                for (const auto& box : o.boxes)
                    if (o.model == QStringLiteral("sim") && o.id == 10 && std::isfinite(box.depthMeters) &&
                        std::abs(box.depthMeters - 2.0) < 0.05 && box.depthCapturedMs == left.capturedMs)
                        return true;
            return false;
        }), "simulated 2m target depth and original capture timestamp");
        // C5/C6 use lower frame IDs than C1/C2, and a nonzero tag offset.
        // A shared pair watermark or group-1 offset would suppress this pair.
        auto secondLeft = frame(2, 4, 4); secondLeft.image = left.image; secondLeft.tag = 7;
        auto secondRight = frame(3, 4, 5); secondRight.image = right.image; secondRight.tag = 4;
        pipeline.submitFrame(secondLeft); pipeline.submitFrame(secondRight);
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.diagnostics)
                if (s.contains(QStringLiteral("C1/C2:10/12")) && s.contains(QStringLiteral("C5/C6:2/3"))) return true;
            return false;
        }, 1600), "both groups independently pair while only selected group previews");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereoOutputs)
                ok &= check(s.status.startsWith(QStringLiteral("C1/C2:")), "background group cannot overwrite selected preview");
            for (const auto& req : log.requests)
                ok &= check(req.camera == 0, "background stereo cameras never enter selected tracker or NPU");
        }
        // Switch to the second left with frame IDs below its previous watermark.
        // No tracks or depth may cross cameras; old generation replies are stale.
        const int beforeSwitch = log.count();
        pipeline.configure(5, 4, false, {QStringLiteral("sim")}, {{QStringLiteral("sim"), {0}}});
        secondLeft = frame(1, 5, 4); secondLeft.image = left.image; secondLeft.tag = 1;
        pipeline.submitFrame(secondLeft);
        ok &= check(until([&] { return log.count() == beforeSwitch + 1; }), "camera switch resets selected tracking and request watermarks");
        {
            QMutexLocker lock(&log.mutex);
            bool empty = false;
            for (const auto& o : log.outputs) if (o.generation == 5) {
                empty = true;
                ok &= check(o.boxes.isEmpty(), "camera switch does not inherit previous tracks or depth");
            }
            ok &= check(empty, "new selected camera publishes empty tracker before detection");
        }
        pipeline.submitDetections(QStringLiteral("sim"), 4, 10, {d}, 10);
        pipeline.submitDetections(QStringLiteral("sim"), 5, 1, {d}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("sim"), 5, 1, true); }), "second camera target initialized independently");
        secondRight = frame(2, 5, 5); secondRight.image = right.image;
        secondRight.tag = 1; // group 1's offset would incorrectly accept this
        pipeline.submitFrame(secondRight);
        QThread::msleep(60);
        ok &= check(!log.hasPreview(5, 1), "second group refuses group-1 tag offset");
        secondRight.frameId = 3; secondRight.tag = 0xfffffffeU; // +3 wraps to 1
        secondRight.capturedMs = testNow(); pipeline.submitFrame(secondRight);
        ok &= check(until([&] { return log.hasDepth(5, 1, 4.0, secondLeft.capturedMs); }),
                    "second calibration produces 4m with its own wrapping tag offset");
        // A fresh first-group pair computes in the background without changing
        // the selected second-group preview or second-group target cache.
        auto backgroundLeft = frame(100, 5, 0); backgroundLeft.image = left.image; backgroundLeft.tag = 50;
        auto backgroundRight = frame(101, 5, 1); backgroundRight.image = right.image; backgroundRight.tag = 50;
        pipeline.submitFrame(backgroundLeft); pipeline.submitFrame(backgroundRight);
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.diagnostics)
                if (s.contains(QStringLiteral("C1/C2:100/101")) && s.contains(QStringLiteral("C5/C6:1/3"))) return true;
            return false;
        }, 1600), "switch resets all groups and background group continues fairly");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereoOutputs) if (s.generation == 5)
                ok &= check(s.status.startsWith(QStringLiteral("C5/C6:")), "selected second group preview remains isolated");
            for (const auto& o : log.outputs) if (o.generation == 5)
                for (const auto& box : o.boxes) if (std::isfinite(box.depthMeters))
                    ok &= check(std::abs(box.depthMeters - 4.0) < 0.08, "group-1 calibration never seeds group-2 cache");
        }
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereoOutputs) if (s.generation == 5 && !s.preview &&
                    s.status.contains(QStringLiteral("no fresh corresponding pair")) &&
                    s.status.startsWith(QStringLiteral("C5/C6:")) && s.id == 1) return true;
            return false;
        }, 1400), "selected group independently expires preview when its pair freezes");
        // Selecting a right camera keeps its own boxes and can show that pair's
        // preview, but left-image ROI depths must never label its targets.
        const int beforeRight = log.count();
        pipeline.configure(6, 5, false, {QStringLiteral("sim")}, {{QStringLiteral("sim"), {0}}});
        auto selectedRight = frame(1, 6, 5); selectedRight.image = right.image; selectedRight.tag = 10;
        pipeline.submitFrame(selectedRight);
        ok &= check(until([&] { return log.count() == beforeRight + 1; }), "right camera inference stays on selected route");
        pipeline.submitDetections(QStringLiteral("sim"), 6, 1, {d}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("sim"), 6, 1, true); }), "right camera tracks its own targets");
        auto unselectedLeft = frame(2, 6, 4); unselectedLeft.image = left.image; unselectedLeft.tag = 13;
        pipeline.submitFrame(unselectedLeft);
        ok &= check(until([&] { return log.hasPreview(6, 2); }), "right selected camera displays its stereo group");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& o : log.outputs) if (o.generation == 6)
                for (const auto& box : o.boxes)
                    ok &= check(!std::isfinite(box.depthMeters), "right camera cannot inherit left ROI depth");
        }
        // Return to primary left with no paired image. Reset must clear both the
        // old targets and all disparity/depth state, even if track IDs restart.
        const int beforeReturn = log.count();
        pipeline.configure(7, 0, false, {QStringLiteral("sim")}, {{QStringLiteral("sim"), {0}}});
        left = frame(1, 7, 0); left.image = pixels(leftPixels); left.tag = 77;
        pipeline.submitFrame(left);
        ok &= check(until([&] { return log.count() == beforeReturn + 1; }), "return to primary left accepts lower frame IDs in new source");
        pipeline.submitDetections(QStringLiteral("sim"), 7, 1, {d}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("sim"), 7, 1, true); }), "returned camera target freshly initialized");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& o : log.outputs) if (o.generation == 7)
                for (const auto& box : o.boxes)
                    ok &= check(!std::isfinite(box.depthMeters), "switch clears cached depths before any new corresponding pair");
        }
        right = frame(2, 7, 1); right.image = pixels(rightPixels); right.tag = 77;
        pipeline.submitFrame(right);
        ok &= check(until([&] { return log.hasDepth(7, 1, 2.0, left.capturedMs); }), "primary calibration remains independent after round-trip camera switch");
        // Retain two left frames, track the newer one, then deliver a right
        // exposure matching only the older left. Center preview is allowed;
        // using that disparity for the newer target is forbidden.
        const int beforeOlder = log.count();
        pipeline.configure(8, 0, false, {QStringLiteral("sim")}, {{QStringLiteral("sim"), {0}}});
        auto olderLeft = frame(1, 8, 0); olderLeft.image = pixels(leftPixels); olderLeft.tag = 20;
        pipeline.submitFrame(olderLeft);
        ok &= check(until([&] { return log.count() == beforeOlder + 1; }), "older exposure request reserved");
        auto newerLeft = frame(2, 8, 0); newerLeft.image = olderLeft.image; newerLeft.tag = 21;
        pipeline.submitFrame(newerLeft);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("sim"), 8, 2); }), "newer left enters selected history");
        pipeline.submitDetections(QStringLiteral("sim"), 8, 1, {d}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("sim"), 8, 2, true); }), "target correction replays to newer exposure");
        auto olderRight = frame(3, 8, 1); olderRight.image = pixels(rightPixels); olderRight.tag = 20;
        pipeline.submitFrame(olderRight);
        ok &= check(until([&] { return log.hasPreview(8, 1); }), "older matching pair still has a stereo preview");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& o : log.outputs) if (o.generation == 8)
                for (const auto& box : o.boxes)
                    ok &= check(!std::isfinite(box.depthMeters), "older stereo frame never seeds newer target depth");
        }
        olderRight.frameId = 4; olderRight.tag = 21; olderRight.capturedMs = testNow();
        pipeline.submitFrame(olderRight);
        ok &= check(until([&] { return log.hasDepth(8, 2, 2.0, newerLeft.capturedMs); }), "only same-frame target and disparity seed cache");
        pipeline.stop(); pipeline.wait();
    }
    {
        // A slow selected group must not impose its attempt interval, frame IDs
        // or tag offset on a fast background group. Deliberately retain a slow
        // pair until its 500ms freshness expires before the next 2000ms attempt.
        VisionOptions options; options.trackingIntervalMs = 0;
        options.stereoGroups = {{0, 1, {}, true, true, -2, 100}, {4, 5, {}, true, true, 3, 2000}};
        options.stereoIntervalMs = 40;
        Log log; VisionPipeline pipeline(options);
        log.connect(pipeline); pipeline.configure(12, 4, false, {}, {}); pipeline.start();
        auto slowLeft = frame(100, 12, 4); slowLeft.tag = 13;
        auto slowRight = frame(101, 12, 5); slowRight.tag = 10;
        const qint64 firstSubmittedMs = testNow();
        pipeline.submitFrame(slowLeft); pipeline.submitFrame(slowRight);
        const bool firstPreview = until([&] { return log.hasPreview(12, 100); });
        ok &= check(firstPreview, "slow group initially computes its own matching pair");
        const qint64 firstObservedMs = testNow();
        slowLeft = frame(102, 12, 4); slowLeft.tag = 23;
        slowRight = frame(103, 12, 5); slowRight.tag = 20;
        pipeline.submitFrame(slowLeft); pipeline.submitFrame(slowRight);
        auto fastLeft = frame(1, 12, 0); fastLeft.tag = 7;
        auto fastRight = frame(2, 12, 1); fastRight.tag = 9;
        pipeline.submitFrame(fastLeft); pipeline.submitFrame(fastRight);
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.diagnostics)
                if (s.contains(QStringLiteral("C1/C2:1/2")) && s.contains(QStringLiteral("C5/C6:100/101")))
                    return true;
            return false;
        }, 1500), "fast group progresses while slow group interval holds its independent watermark");
        ok &= check(!log.hasPreview(12, 102), "slow group does not compute queued pair before its interval");
        fastLeft = frame(3, 12, 0); fastLeft.tag = 17;
        fastRight = frame(4, 12, 1); fastRight.tag = 19;
        pipeline.submitFrame(fastLeft); pipeline.submitFrame(fastRight);
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.diagnostics)
                if (s.contains(QStringLiteral("C1/C2:3/4")) && s.contains(QStringLiteral("C5/C6:100/101")))
                    return true;
            return false;
        }, 1600), "fast group repeats within slow interval without borrowing its offset or watermarks");
        if (firstPreview) {
            // Observing completion provides a conservative wait beyond the
            // attempt deadline. Submit newly captured frames only after that.
            ok &= check(until([&] { return testNow() - firstObservedMs >= 2000; }, 2200),
                        "slow group attempt interval elapses");
            slowLeft = frame(104, 12, 4); slowLeft.tag = 33;
            slowRight = frame(105, 12, 5); slowRight.tag = 30;
            pipeline.submitFrame(slowLeft); pipeline.submitFrame(slowRight);
            ok &= check(until([&] { return log.hasPreview(12, 104); }), "slow group resumes with a fresh own-offset pair");
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereoOutputs) if (s.preview) {
                ok &= check(s.status.startsWith(QStringLiteral("C5/C6:")), "different intervals retain selected preview isolation");
                ok &= check(s.id != 102, "interval never reuses an expired host pair");
                if (s.id == 104)
                    ok &= check(s.at - firstSubmittedMs >= 2000, "slow group honors configured attempt interval");
            }
        }
        pipeline.stop(); pipeline.wait();
    }
    {
        // Both groups have confirmed tags, but neither has a usable calibration.
        // A malformed file in group 2 must not turn group 1's preview into metric
        // depth, nor kill the worker or its independent matcher.
        QTemporaryFile malformed;
        if (!check(malformed.open(), "temporary malformed calibration")) return false;
        malformed.write("invalid calibration fixture\n"); malformed.close();
        VisionOptions options; options.trackingIntervalMs = 0;
        options.stereoGroups = {{0, 1, {}, true, true, 0}, {4, 5, malformed.fileName(), true, true, -2}};
        options.stereoIntervalMs = 80;
        Log log; VisionPipeline pipeline(options);
        log.connect(pipeline); pipeline.configure(9, 0, false, {QStringLiteral("uncal")}, {{QStringLiteral("uncal"), {0}}}); pipeline.start();
        pipeline.submitFrame(frame(10, 9, 0));
        ok &= check(until([&] { return log.count() == 1; }), "uncalibrated first group detection request");
        pipeline.submitDetections(QStringLiteral("uncal"), 9, 10, {target()}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("uncal"), 9, 10, true); }), "uncalibrated target initialized");
        pipeline.submitFrame(frame(10, 9, 1));
        ok &= check(until([&] { return log.hasPreview(9, 10); }), "uncalibrated synchronized pair has disparity preview");
        auto bgLeft = frame(1, 9, 4); bgLeft.tag = 20;
        auto bgRight = frame(2, 9, 5); bgRight.tag = 22;
        pipeline.submitFrame(bgLeft); pipeline.submitFrame(bgRight);
        pipeline.submitFrame(frame(11, 9, 0)); pipeline.submitFrame(frame(11, 9, 1));
        ok &= check(until([&] { return log.hasPreview(9, 11); }), "two groups respect aggregate throttle while progressing");
        {
            QMutexLocker lock(&log.mutex);
            qint64 firstAt = -1, secondAt = -1;
            for (const auto& s : log.stereoOutputs) if (s.generation == 9 && s.preview) {
                if (s.id == 10) firstAt = s.at;
                if (s.id == 11) secondAt = s.at;
                ok &= check(s.status.contains(QStringLiteral("not calibrated")) && !s.status.contains(QStringLiteral(" m;")),
                            "confirmed tags without calibration never advertise meters");
            }
            ok &= check(firstAt >= 0 && secondAt - firstAt >= options.stereoIntervalMs,
                        "stereo computation enforces cooldown after prior completion");
            for (const auto& o : log.outputs) if (o.generation == 9)
                for (const auto& box : o.boxes)
                    ok &= check(!std::isfinite(box.depthMeters), "uncalibrated target cache never contains trusted meters");
        }
        const int beforeMalformed = log.count();
        pipeline.configure(10, 4, false, {QStringLiteral("uncal")}, {{QStringLiteral("uncal"), {0}}});
        bgLeft = frame(1, 10, 4); bgLeft.tag = 20; pipeline.submitFrame(bgLeft);
        ok &= check(until([&] { return log.count() == beforeMalformed + 1; }), "malformed group still tracks selected camera");
        pipeline.submitDetections(QStringLiteral("uncal"), 10, 1, {target()}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("uncal"), 10, 1, true); }), "malformed group target initialized");
        bgRight = frame(2, 10, 5); bgRight.tag = 22; pipeline.submitFrame(bgRight);
        ok &= check(until([&] { return log.hasPreview(10, 1); }), "malformed second calibration falls back to disparity only");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereoOutputs) if (s.generation == 10)
                ok &= check(s.status.startsWith(QStringLiteral("C5/C6:")) &&
                            s.status.contains(QStringLiteral("not calibrated")) && !s.status.contains(QStringLiteral(" m;")),
                            "malformed calibration stays isolated and cannot report meters");
            for (const auto& o : log.outputs) if (o.generation == 10)
                for (const auto& box : o.boxes)
                    ok &= check(!std::isfinite(box.depthMeters), "malformed calibration cannot seed target depth");
        }
        // C3 belongs to neither pair: it tracks independently while the four
        // stereo camera slots stay active, with no unrelated preview exposed.
        const int beforeUnpaired = log.count();
        pipeline.configure(11, 2, false, {QStringLiteral("uncal")}, {{QStringLiteral("uncal"), {0}}});
        pipeline.submitFrame(frame(1, 11, 2));
        ok &= check(until([&] { return log.count() == beforeUnpaired + 1; }), "camera outside stereo groups requests its own inference");
        pipeline.submitDetections(QStringLiteral("uncal"), 11, 1, {target()}, 10);
        ok &= check(until([&] { return log.hasOutput(QStringLiteral("uncal"), 11, 1, true); }), "camera outside stereo groups tracks independently");
        pipeline.submitFrame(frame(8, 11, 0)); pipeline.submitFrame(frame(8, 11, 1));
        bgLeft = frame(2, 11, 4); bgLeft.tag = 20;
        bgRight = frame(3, 11, 5); bgRight.tag = 22;
        pipeline.submitFrame(bgLeft); pipeline.submitFrame(bgRight);
        ok &= check(until([&] {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.diagnostics)
                if (s.contains(QStringLiteral("C1/C2:8/8")) && s.contains(QStringLiteral("C5/C6:2/3"))) return true;
            return false;
        }, 1600), "four stereo cameras continue bounded pairing with unrelated camera selected");
        {
            QMutexLocker lock(&log.mutex);
            for (const auto& s : log.stereoOutputs)
                ok &= check(s.generation != 11, "unrelated selected camera receives no other-group preview");
            for (const auto& o : log.outputs) if (o.generation == 11)
                for (const auto& box : o.boxes)
                    ok &= check(!std::isfinite(box.depthMeters), "unrelated selected camera has no stereo target cache");
            for (const auto& req : log.requests) if (req.sourceGeneration == 11)
                ok &= check(req.camera == 2, "unrelated selection never tracks a stereo input camera");
        }
        pipeline.stop(); pipeline.wait();
    }
    if (ok) { out << "VISION_SELFTEST_PASS\n"; out.flush(); }
    return ok;
}

#ifdef TDM_VISION_SELFTEST_MAIN
int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    // Match the application's OpenCV worker budget. The desktop default can
    // otherwise spawn one worker per host core and consume the 300ms TTL.
    cv::setNumThreads(2);
    return VisionPipeline::selfTest() ? 0 : 1;
}
#endif
