#pragma once
// lane6_d3a：864x288@0.6 的 9 类掩码与 detview 640x480 内容区之间的几何契约。
#include <QImage>
#include <QPainter>
#include <cstring>
#include <cmath>
#include <cstdio>
#include <vector>
#include "ads_postprocess.h"
#include "inference_geometry.h"
#include "lane_style.h"
#include "lane_scene.h"
#include "lane_calibration_profiles.h"

namespace lane6 {
using LaneMarkingCounts=std::array<int,9>;
constexpr int Width = 864, Height = 288, Classes = 9;
constexpr int CanvasWidth = 640, CanvasHeight = 480;
constexpr int ContentTop = CanvasHeight - Height; // 底部60%：192..479
constexpr int OutputWidth = Width / 2, OutputHeight = Height / 2; // out_stride=2

inline bool queryInputGeometry(const rknn_tensor_attr &attr, tdm::InferenceGeometry &geometry) {
    if (attr.n_dims != 4 || attr.dims[0] != 1 || attr.fmt != RKNN_TENSOR_NHWC ||
        attr.dims[1] != Height || attr.dims[2] != Width || attr.dims[3] != 3) return false;
    geometry.width = Width;
    geometry.height = Height;
    return true;
}

inline QImage networkRgbFrame(const QImage &source) {
    if (source.isNull() || source.width() != CanvasWidth ||
        (source.height() != CanvasHeight && source.height() != 640)) return {};
    const QImage rgb = source.format() == QImage::Format_RGB888
        ? source : source.convertToFormat(QImage::Format_RGB888);
    const QImage content = source.height() == 640 ? rgb.copy(0, 80, CanvasWidth, CanvasHeight) : rgb;
    // 与 make_input(..., "864x288@0.6") 一致：先裁底部60%，再拉伸至网络输入。
    return content.copy(0, ContentTop, CanvasWidth, Height)
        .scaled(Width, Height, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
        .convertToFormat(QImage::Format_RGB888); // Qt smooth scaling can return RGB32.
}

// Fixed 640x288 -> 864x288 enlargement, matching Qt Smooth's 16.16
// sample positions and 8-bit horizontal interpolation. No vertical resize.
inline QImage networkRgbFrameDirect(const QImage& source) {
    if(source.width()!=640 || (source.height()!=480 && source.height()!=640))return {};
    const auto rgb=source.format()==QImage::Format_RGB888?source:source.convertToFormat(QImage::Format_RGB888);
    QImage out(Width,Height,QImage::Format_RGB888);
    const int top=source.height()==640?272:192;
    for(int y=0;y<Height;++y){
        const auto* in=rgb.constScanLine(y+top);auto* dst=out.scanLine(y);
        qint64 position=0x8000*640/Width-0x8000;
        constexpr qint64 step=(qint64(640)<<16)/Width;
        for(int x=0;x<Width;++x,position+=step){
            const int raw=int(position>>16),sx=std::max(0,raw);
            const int weight=raw<0 || raw>=639?0:int((position>>8)&255);
            for(int c=0;c<3;++c)dst[x*3+c]=uchar((in[sx*3+c]*(256-weight)+in[std::min(639,sx+1)*3+c]*weight)>>8);
        }
    }
    return out;
}

inline QImage labelsToCanvas(const std::vector<uint8_t>& labels,LaneMarkingCounts* counts=nullptr) {
    if(labels.size()!=size_t(OutputWidth*OutputHeight))return {};
    if(counts)*counts={};
    QImage out(640,640,QImage::Format_ARGB32_Premultiplied);out.fill(Qt::transparent);
    std::array<QRgb,Classes> colors{};
    for(int c=1;c<Classes;++c)colors[c]=qPremultiply(lane_style::rgba(c));
    for(int y=0;y<Height;++y){auto* row=reinterpret_cast<QRgb*>(out.scanLine(y+272));
        for(int x=0;x<640;++x){const int sx=((2*x+1)*Width/(2*640))/2;
            const int c=labels[(y/2)*OutputWidth+sx];row[x]=colors[c];if(counts&&c)++(*counts)[c];}
    }
    return out;
}

template<class Read> inline QImage decodeRead(Read logits, int aminLane = 0, int aminZebra = 0,
                     lane_arbitration::Observation* observation=nullptr,LaneMarkingCounts* counts=nullptr,bool canvas=false,
                     std::vector<uint8_t>* classesOut=nullptr) {
    ads_post::LaneConfig cfg;
    cfg.filter = aminLane > 0 || aminZebra > 0;
    cfg.min_width[1] = cfg.min_width[2] = 2.0f;
    for (int c = 1; c <= 6; ++c) cfg.min_area[c] = aminLane / 4;
    cfg.min_area[8] = aminZebra / 4;
    static const QByteArray experiment=qgetenv("ADS_LANE_EXPERIMENT");
    const bool candidate=lane_calibration::apply(experiment.constData(),cfg);
    static bool reported=false;
    if(!reported){reported=true;std::fprintf(stderr,"[lane-temporal] attributes=1 profile=%s\n",candidate?experiment.constData():"production");}
    const auto result = ads_post::laneRead(logits, size_t(Classes) * OutputWidth * OutputHeight,
                                      OutputWidth, OutputHeight, cfg);
    const auto &labels = result.labels;
    // 单目部分解算需要原始类别网格（432x144，一像素一类），不能从彩色 QImage 反推。
    if(classesOut)*classesOut=labels;
    if(observation) {
        const size_t plane=size_t(OutputWidth)*OutputHeight;
        thread_local std::vector<float> probabilities;probabilities.assign(plane*Classes,0);
        std::array<float,Classes> offset{};
        for(int c=0;c<Classes;++c)offset[c]=std::log(cfg.bias[c]);
        for(size_t p=0;p<plane;++p)if(labels[p]>=1 && labels[p]<=6) {
            float maximum=-std::numeric_limits<float>::infinity();
            for(int c=0;c<Classes;++c)maximum=std::max(maximum,logits(c*plane+p)+offset[c]);
            float sum=0;
            for(int c=0;c<Classes;++c){const float value=std::exp(logits(c*plane+p)+offset[c]-maximum);probabilities[c*plane+p]=value;sum+=value;}
            for(int c=0;c<Classes;++c)probabilities[c*plane+p]/=sum;
        }
        *observation=lane_arbitration::trace(labels.data(),OutputWidth,OutputHeight,probabilities.data());
    }
    if(canvas)return labelsToCanvas(labels,counts);
    QImage mask(OutputWidth, OutputHeight, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < OutputHeight; ++y) {
        QRgb *row = reinterpret_cast<QRgb *>(mask.scanLine(y));
        for (int x = 0; x < OutputWidth; ++x) row[x] = qPremultiply(lane_style::rgba(labels[(size_t)y * OutputWidth + x]));
    }
    // 最近邻放大保持类别边界；不插值出新类别。
    return mask.scaled(Width, Height, Qt::IgnoreAspectRatio, Qt::FastTransformation);
}

inline QImage decode(const float* logits,int minArea=0,int zebraArea=0,lane_arbitration::Observation* scene=nullptr,
                     std::vector<uint8_t>* classesOut=nullptr) {
    if(!logits)return {};
    return decodeRead([&](size_t i){return logits[i];},minArea,zebraArea,scene,nullptr,false,classesOut);
}
inline QImage decodeCanvas(const void* data,bool isFloat,int zp,float scale,int minArea,int zebraArea,
                          lane_arbitration::Observation* scene,LaneMarkingCounts* counts,
                          std::vector<uint8_t>* classesOut=nullptr) {
    if(isFloat)return decodeRead([&](size_t i){return static_cast<const float*>(data)[i];},minArea,zebraArea,scene,counts,true,classesOut);
    return decodeRead([&](size_t i){return float(int(static_cast<const int8_t*>(data)[i])-zp)*scale;},minArea,zebraArea,scene,counts,true,classesOut);
}

inline QImage toCanvas(const QImage &networkMask) {
    if (networkMask.width() != Width || networkMask.height() != Height) return {};
    // 与 det640 检测框共享 640x640 canonical：640x480 内容从 y=80 开始。
    QImage canvas(CanvasWidth, 640, QImage::Format_ARGB32_Premultiplied);
    canvas.fill(Qt::transparent);
    QPainter painter(&canvas);
    painter.drawImage(QRect(0, 80 + ContentTop, CanvasWidth, Height), networkMask);
    return canvas;
}
} // namespace lane6
