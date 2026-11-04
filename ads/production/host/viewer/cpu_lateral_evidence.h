#pragma once
#include "third_party/ranging_cpu/vendor/lane_calib.h"

namespace cpu_lateral {
struct Evidence {
    bool paint=false,lane=false,agreement=false,conflict=false;
    double height=0,focal=0,hfov=0;
};
inline Evidence assess(const lane_calib::FrameMeas& m,int width) {
    Evidence e;
    auto reliable=[](const lane_calib::Est& v) {
        return v.ok&&v.n>=3&&std::isfinite(v.value)&&v.value>=.8&&v.value<=2.6&&
            std::isfinite(v.spread)&&v.spread<=.15;
    };
    e.paint=reliable(m.h_c_paint);e.lane=reliable(m.h_c_lane);
    if(!e.paint||!e.lane)return e;
    const double hp=m.h_c_paint.value,hl=m.h_c_lane.value;
    e.height=(hp+hl)*.5;
    e.conflict=std::abs(hp-hl)>.25*e.height;
    // Two routes are a cross-check, not two independent votes: both depend
    // on the same horizon and extracted marks.
    e.agreement=!e.conflict;
    if(e.agreement&&m.A_dash.ok&&std::isfinite(m.A_dash.value)&&m.A_dash.value>0) {
        e.focal=m.A_dash.value/e.height;
        e.hfov=2*std::atan(width/(2*e.focal))*180/CV_PI;
        if(e.hfov<25||e.hfov>160){e.agreement=false;e.focal=0;}
    }
    return e;
}
}
