#pragma once
#include <algorithm>
#include <cstdint>

namespace tdm {
class CapturePacing {
public:
    explicit CapturePacing(int maximumFps = 0)
        : periodNs_(maximumFps > 0 ? (1000000000LL + maximumFps - 1) / maximumFps : 0) {}
    int64_t waitNs(int64_t nowNs) const {
        return periodNs_ ? std::max<int64_t>(0, nextNs_ - nowNs) : 0;
    }
    void delivered(int64_t readStartedNs) {
        nextNs_ = periodNs_ ? readStartedNs + periodNs_ : 0;
    }
    void reset() { nextNs_ = 0; }
private:
    int64_t periodNs_ = 0;
    int64_t nextNs_ = 0;
};
}
