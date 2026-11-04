#pragma once
#include <opencv2/core.hpp>

namespace bev_lane {
// Native HDMI geometry: two independent 640x960 halves. Detection is limited
// to each half's bottom-centered 480x360 ROI, not the old full-frame path.
struct NativeRoi {
    static constexpr int halfWidth=640;
    static constexpr int halfHeight=960;
    static constexpr int x=80;
    static constexpr int y=600;
    static constexpr int width=480;
    static constexpr int height=360;
    static constexpr int birdWidth=250;
    static constexpr int birdHeight=209;
    static constexpr int birdImageX(int value) { return x+value; }
    static constexpr int birdImageY(int value) { return y+value; }
    static cv::Rect rect(int half=0) {
        return {half*halfWidth+x,y,width,height};
    }
};
} // namespace bev_lane
