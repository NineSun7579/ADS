#pragma once
#include "input_scale.h"
#include "hdmi_view.h"
#include "vision_pipeline.h"
#include "runtime_camera_geometry.h"
#include <condition_variable>
#include <mutex>
#include <thread>
#include <chrono>
#include <cstdio>

namespace hdmi_preprocess {
struct Input {
    QByteArray left,right;
    runtime_camera::Geometry leftGeometry,rightGeometry;
    input480::Mode scale=input480::Mode::Off;
    VisionFrame packet;
    uint64_t selection=0;
    qint64 leftCapturedMs=0,rightCapturedMs=0;
    uint32_t rightTag=0;
    uint64_t leftSequence=0,rightSequence=0;
    std::chrono::steady_clock::time_point queued;
};
inline QImage compose(const Input& input) {
    if(input.scale==input480::Mode::Off)return tdm::hdmiAnalyticsImage(input.left,input.right);
    const auto& l=input.leftGeometry;const auto& r=input.rightGeometry;
    if(!l.valid()||!r.valid()||uint32_t(input.left.size())!=l.pixelBytes||uint32_t(input.right.size())!=r.pixelBytes)return {};
    const QImage left(reinterpret_cast<const uchar*>(input.left.constData()),int(l.width),int(l.height),int(l.stride),QImage::Format_RGB16);
    const QImage right(reinterpret_cast<const uchar*>(input.right.constData()),int(r.width),int(r.height),int(r.stride),QImage::Format_RGB16);
    return input480::composePair(left,right,input.scale);
}
inline bool fresh(const Input& input,qint64 now) {
    return input.packet.acquisition.mask==0x30u && acquisition::current(input.packet.acquisition) &&
        input.leftCapturedMs>0 && input.rightCapturedMs>0 && now>=input.leftCapturedMs && now>=input.rightCapturedMs &&
        now-input.leftCapturedMs<=100 && now-input.rightCapturedMs<=100 &&
        qAbs(input.leftCapturedMs-input.rightCapturedMs)<=40;
}
// One in-progress and one replaceable pending immutable packet. Never a DMA,
// QWidget, GL or device owner. Conversion and callbacks run outside queue lock.
class Worker {
public:
    using Valid=std::function<bool(const Input&)>;
    using Compose=std::function<QImage(const Input&)>;
    Worker(Valid valid,Compose processor=compose):valid_(std::move(valid)),processor_(std::move(processor)),thread_([this]{run();}){}
    ~Worker(){stop();}
    void submit(Input input) {
        input.queued=std::chrono::steady_clock::now();
        std::lock_guard<std::mutex> lock(mutex_);
        if(stopped_)return;
        ++submitted_;if(pending_)++coalesced_;
        input_=std::move(input);pending_=true;cv_.notify_one();
    }
    void stop() {
        {std::lock_guard<std::mutex> lock(mutex_);stopped_=true;pending_=false;completed_=false;input_={};output_={};cv_.notify_all();}
        if(thread_.joinable())thread_.join();
    }
    bool take(Input& result) {
        std::lock_guard<std::mutex> lock(mutex_);
        if(!completed_)return false;
        result=std::move(output_);completed_=false;return true;
    }
private:
    void run() {
        for(;;) {
            Input input;
            {std::unique_lock<std::mutex> lock(mutex_);cv_.wait(lock,[this]{return stopped_||pending_;});
             if(stopped_)break;input=std::move(input_);pending_=false;}
            if(!valid_(input)){++invalid_;continue;}
            const auto began=std::chrono::steady_clock::now();
            queueMs_+=std::chrono::duration<double,std::milli>(began-input.queued).count();
            input.packet.image=processor_(input);
            preprocessMs_+=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-began).count();
            ++processed_;
            if(input.packet.image.isNull()||!valid_(input)){++invalid_;continue;}
            {std::lock_guard<std::mutex> lock(mutex_);if(stopped_)break;
             if(completed_)++coalescedOutput_;
             output_=std::move(input);completed_=true;}
            if(processed_%120==1)report();
        }
        report();
    }
    void report() {
        uint64_t submitted,coalesced,outputs;
        {std::lock_guard<std::mutex> lock(mutex_);submitted=submitted_;coalesced=coalesced_;outputs=coalescedOutput_;}
        std::fprintf(stderr,"[hdmi-preprocess] fresh_submissions=%llu processed=%llu coalesced_pending=%llu coalesced_completed=%llu invalidated=%llu queue_wait_sum_ms=%.3f preprocess_sum_ms=%.3f capture_drops=not_measured\n",
            (unsigned long long)submitted,(unsigned long long)processed_,(unsigned long long)coalesced,(unsigned long long)outputs,(unsigned long long)invalid_,queueMs_,preprocessMs_);
    }
    Valid valid_;Compose processor_;
    std::mutex mutex_;std::condition_variable cv_;Input input_,output_;bool pending_=false,completed_=false,stopped_=false;
    uint64_t coalescedOutput_=0;
    uint64_t submitted_=0,coalesced_=0,processed_=0,invalid_=0;
    double queueMs_=0,preprocessMs_=0;
    std::thread thread_;
};
}
