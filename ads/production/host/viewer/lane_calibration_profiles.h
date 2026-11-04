#pragma once
#include "ads_postprocess.h"
#include <cstring>
namespace lane_calibration {
// Experimental profile sealed by the boundary-first cloud search. Default
// production settings remain in LaneConfig. No automatic candidate selection.
inline bool apply(const char* name,ads_post::LaneConfig& cfg) {
    if(!name || std::strcmp(name,"boundary-strict-20261029"))return false;
    cfg.bias={{1,.6000000238418579f,.4000000059604645f,.8999999761581421f,1,1.25f,1,1,1}};
    cfg.min_area={{0,5,0,35,50,10,50,0,100}};
    cfg.min_width={{0,0,2,0,0,0,0,0,0}};
    return true;
}
} // namespace lane_calibration
