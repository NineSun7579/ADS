#pragma once
#include "third_party/ranging_cpu/ranging.hpp"

namespace cpu_distance_quality {
// Sensitivity envelope, not a calibrated probability interval. Shared by
// offline replay and the live exact-frame annotation path.
struct Bounds {double horizonPixels=2,scaleRelative=.05,contactPixels=2;};
inline ranging::Measurement project(const ranging::Box& box,const online_calib::State& state,
                                   cv::Size size,cv::Rect road,Bounds bounds,double score=.25) {
    auto result=ranging::project(box,state,size,road,score);
    if(!result.valid)return result;
    const double denominator=box.rect.br().y-state.y_h;
    const double dy=bounds.horizonPixels+bounds.contactPixels;
    const double da=bounds.scaleRelative;
    const double lower=state.A*(1-da)/(denominator+dy);
    const double upper=denominator>dy?state.A*(1+da)/(denominator-dy):INFINITY;
    if(!std::isfinite(dy)||dy<0||!std::isfinite(da)||da<0||da>=1||
       !std::isfinite(upper)||lower<=0||
       std::max(upper-result.depth_m,result.depth_m-lower)>.30*result.depth_m) {
        result.valid=false;result.depth_m=std::numeric_limits<double>::quiet_NaN();
        result.reason="distance_sensitivity_too_high";
    }
    return result;
}
}
