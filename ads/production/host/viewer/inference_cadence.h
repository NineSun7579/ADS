#pragma once
#include <algorithm>
#include <cstdint>

namespace tdm {
// Prefetch changes only input preparation. Submission still uses the original
// timestamp of the last emitted request, including urgent and bypass policies.
struct InferenceCadence {
    static bool due(int64_t now, int64_t lastRequest, int64_t interval, bool bypass) {
        return bypass || lastRequest < 0 || now - lastRequest >= interval;
    }
    static bool mayArm(int64_t now, int64_t lastRequest, int64_t interval, bool bypass,
                       int64_t leadMs = 30) {
        return bypass || lastRequest < 0 ||
            now - lastRequest >= interval - std::min(interval, std::max(int64_t(0), leadMs));
    }
};
}
