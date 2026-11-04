#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <vector>
#include "seg_post_c.h"

namespace ads_post {
// All storage is caller-owned or returned by value; no Qt, RKNN, DMA or globals.
struct Box { float x1, y1, x2, y2, score; int cls; };
struct DetectionConfig {
    float threshold = 0.05f, nms_iou = 0.6f;
    std::size_t pre_topk = 3000, max_det = 200;
    bool containment = false;
    float containment_threshold = 0.7f;
};
inline float overlap(const Box &a, const Box &b, bool containment) {
    const float intersection = std::max(0.f, std::min(a.x2,b.x2)-std::max(a.x1,b.x1)) *
                               std::max(0.f, std::min(a.y2,b.y2)-std::max(a.y1,b.y1));
    const float aa=(a.x2-a.x1)*(a.y2-a.y1), bb=(b.x2-b.x1)*(b.y2-b.y1);
    const float denominator=containment ? std::min(aa,bb) : aa+bb-intersection;
    return denominator > 0 ? intersection/denominator : 0;
}
inline std::vector<Box> detections(const std::vector<Box> &input, const DetectionConfig &cfg = {}) {
    auto probability=[](float x) { return std::isfinite(x) && x>=0 && x<=1; };
    if (!probability(cfg.threshold) || !probability(cfg.nms_iou) ||
        !probability(cfg.containment_threshold)) throw std::invalid_argument("invalid detection thresholds");
    std::vector<Box> candidates;
    for (const auto &b: input) {
        if (!probability(b.score) || b.cls<0 || b.cls>=11 ||
            !std::isfinite(b.x1) || !std::isfinite(b.y1) || !std::isfinite(b.x2) || !std::isfinite(b.y2) ||
            b.x2<=b.x1 || b.y2<=b.y1) throw std::invalid_argument("invalid box");
        if (b.score>cfg.threshold) candidates.push_back(b);
    }
    // Equal scores retain caller candidate order, including at pre_topk boundary.
    std::stable_sort(candidates.begin(), candidates.end(), [](const Box &a,const Box &b){return a.score>b.score;});
    if (candidates.size()>cfg.pre_topk) candidates.resize(cfg.pre_topk);
    std::vector<Box> nms, kept;
    for (const auto &b:candidates) {
        bool suppress=false;
        for (const auto &a:nms) if (a.cls==b.cls && overlap(a,b,false)>cfg.nms_iou) {suppress=true;break;}
        if (!suppress) nms.push_back(b);
    }
    for (const auto &b:nms) {
        bool suppress=false;
        if (cfg.containment && b.cls>=3 && b.cls<=6)
            for (const auto &a:kept) if (a.cls==b.cls && overlap(a,b,true)>=cfg.containment_threshold) {suppress=true;break;}
        if (!suppress) kept.push_back(b);
    }
    if (kept.size()>cfg.max_det) kept.resize(cfg.max_det);
    return kept;
}

struct LaneConfig {
    // Units are OUTPUT grid pixels, not input or display pixels.
    std::array<int,9> min_area{};
    std::array<float,9> min_width{};
    std::array<float,9> bias{{1,.6f,.6f,1,1,.25f,1,1,1}};
    bool filter=false;
};
struct LaneResult { std::vector<std::uint8_t> labels; int removed=0; };
template<class Read> inline LaneResult laneRead(Read logits, std::size_t count, int width, int height,
                       const LaneConfig &cfg = {}) {
    if (width<=0 || height<=0 || width>4096 || height>4096 ||
        count!=std::size_t(width)*height*9) throw std::invalid_argument("invalid NCHW lane tensor");
    std::array<float,9> bias{};
    for (int c=0;c<9;++c) {
        if (!(cfg.bias[c]>0) || !std::isfinite(cfg.bias[c]) || cfg.min_area[c]<0 ||
            cfg.min_width[c]<0 || !std::isfinite(cfg.min_width[c])) throw std::invalid_argument("invalid lane configuration");
        bias[c]=std::log(cfg.bias[c]);
    }
    const std::size_t plane=std::size_t(width)*height;
    LaneResult result; result.labels.resize(plane);
    // Validate every raw value, including losing classes, during decoding.
    // Ascending classes and strict comparison preserve first-class ties.
    for (std::size_t p=0;p<plane;++p) {
        const float value=logits(p);
        if (!std::isfinite(value)) throw std::invalid_argument("nonfinite lane logits");
        int best=0; float score=value+bias[0];
        for (int c=1;c<9;++c) {
            const float candidate=logits(c*plane+p);
            if (!std::isfinite(candidate)) throw std::invalid_argument("nonfinite lane logits");
            const float adjusted=candidate+bias[c];
            if (adjusted>score) {best=c;score=adjusted;}
        }
        result.labels[p]=best==7 ? 0 : static_cast<std::uint8_t>(best);
    }
    if (cfg.filter) {
        result.removed=seg_shape_filter_area_classes(result.labels.data(),width,height,cfg.min_width.data(),9,cfg.min_area.data());
        if (result.removed<0) throw std::bad_alloc();
    }
    return result;
}
inline LaneResult lane(const float* logits,std::size_t count,int width,int height,const LaneConfig& cfg={}) {
    if(!logits)throw std::invalid_argument("null lane logits");
    return laneRead([&](size_t i){return logits[i];},count,width,height,cfg);
}
inline std::vector<float> dequantize(const std::int8_t *data, std::size_t bytes,
                                    std::size_t elements, int zero_point, float scale) {
    if (!data || bytes<elements || zero_point < -128 || zero_point>127 || !(scale>0) || !std::isfinite(scale))
        throw std::invalid_argument("invalid INT8 tensor");
    std::vector<float> out(elements);
    for (std::size_t i=0;i<elements;++i) out[i]=(int(data[i])-zero_point)*scale;
    return out;
}
} // namespace ads_post
