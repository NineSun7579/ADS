#pragma once
// Host side of the 100H native BEV lane detector. The FPGA performs the ROI
// sampling, ridge extraction and parabola fit; this file only turns the
// returned Q8 coefficients into an overlay on the untouched HDMI image.
#include "bev_fpga_result.h"
#include "bev_native_lut.h"
#include "bev_native_roi.h"
#include <QImage>
#include <QMutex>
#include <QSize>
#include <QThread>
#include <QWaitCondition>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <functional>

namespace bev_lane {
struct Overlay {
    quint64 sequence=0;
    int sourceGeneration=0;
    QSize sourceSize;
    QVector<QPointF> left,right;
};

class Worker : public QThread {
public:
    using Callback=std::function<void(const Overlay&)>;
    void setCallback(Callback callback){QMutexLocker lock(&m_mutex);m_callback=std::move(callback);}
    void submit(const QImage& image,quint64 sequence,int sourceGeneration,const FpgaResult& result) {
        if(image.isNull())return;
        QMutexLocker lock(&m_mutex);
        m_size=image.size();m_sequence=sequence;m_sourceGeneration=sourceGeneration;
        m_result=result;m_busy=true;
        if(!isRunning())start();else m_condition.wakeOne();
    }
    void stop(){m_stopping=true;{QMutexLocker lock(&m_mutex);m_condition.wakeAll();}wait();}
protected:
    void run() override {
        const auto transform=makeNativeRoiTransform({});
        const auto cameraToImage=transform.imageToVehicle.inv();
        fprintf(stderr,"NATIVE_BEV_FPGA_READY base=0x20021200 schema=NBL2 roi=480x360@80,600\n");
        for(;;) {
            QSize size;quint64 sequence;int generation;FpgaResult result;
            {QMutexLocker lock(&m_mutex);
                if(m_stopping)return;
                if(!m_busy){m_condition.wait(&m_mutex);continue;}
                size=m_size;sequence=m_sequence;generation=m_sourceGeneration;
                result=m_result;m_busy=false;
            }
            if(result.present) {
                const int half=result.half&1;
                m_last[half]=result;
            }
            Overlay overlay;overlay.sequence=sequence;overlay.sourceGeneration=generation;
            overlay.sourceSize=size;
            for(int half=0;half<2;++half) {
                const auto& r=m_last[half];
                const bool valid=(half==0)?(r.valid&2):(r.valid&4);
                auto& points=half==0?overlay.left:overlay.right;
                if(!r.present||!valid)continue;
                for(int u=-125;u<=124;++u) {
                    const int64_t vq=int64_t(r.a)*u*u+int64_t(r.b)*u+r.c;
                    const double vdm=double(vq)/256.0;
                    const double row=(60.0-vdm)*(208.0/120.0);
                    if(row<0.0||row>208.0)continue;
                    const double col=double(u+125);
                    const auto vehicle=apply(transform.birdToVehicle,{col,row});
                    const auto point=apply(cameraToImage,vehicle);
                    const double x=NativeRoi::x+half*NativeRoi::halfWidth+point.x-1.0;
                    const double y=NativeRoi::y+point.y-1.0;
                    if(!std::isfinite(x)||!std::isfinite(y))continue;
                    if(x<NativeRoi::x+half*NativeRoi::halfWidth||
                       x>=NativeRoi::x+half*NativeRoi::halfWidth+NativeRoi::width||
                       y<NativeRoi::y||y>=NativeRoi::y+NativeRoi::height)continue;
                    points.append(QPointF(x,y));
                }
            }
            if(sequence==1||sequence%60==0) {
                fprintf(stderr,"NATIVE_BEV_FPGA sequence=%llu left_points=%d right_points=%d "
                        "last_half=%d valid=%04x Q8=(%d,%d,%d) strength=%u\n",
                        (unsigned long long)sequence,overlay.left.size(),overlay.right.size(),
                        int(result.half),unsigned(result.valid),result.a,result.b,result.c,
                        unsigned(result.strength));
            }
            Callback callback;{QMutexLocker lock(&m_mutex);callback=m_callback;}
            if(callback)callback(overlay);
        }
    }
private:
    QMutex m_mutex;QWaitCondition m_condition;Callback m_callback;
    QSize m_size;quint64 m_sequence=0;int m_sourceGeneration=0;
    FpgaResult m_result;FpgaResult m_last[2];
    bool m_busy=false;std::atomic<bool>m_stopping{false};
};
} // namespace bev_lane
