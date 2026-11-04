#pragma once
#include <algorithm>
#include <array>
#include <string>

namespace mvp {
struct Round1Policy {
    bool enabled = false;
    std::array<float,5> thresholds{{0.35f,0.45f,0.25f,0.35f,0.40f}};
    static constexpr float candidateFloor = 0.001f;
    static constexpr float nmsIou = 0.7f;
    static constexpr const char* rknnSha = "6cdfe6c8d834e2b99994633b483e048819a79c440562a2ea1ccbc55947be03e2";
    static constexpr const char* floatSha = "b418d1e662e661616866a0961a4401345fca89410fe8797740e79f2905bde272";
    static bool matchesSha(const std::string& recorded, const std::string& actual) {
        return recorded == rknnSha && actual == recorded;
    }
    template<class Detections> void filterAfterNms(Detections& dets) const {
        if (!enabled) return;
        auto end = std::remove_if(dets.begin(),dets.end(),[&](const auto& d) {
            return d.cls < 0 || d.cls >= 5 || d.score < thresholds[d.cls];
        });
        dets.erase(end,dets.end());
    }
};
}
