#pragma once

#include <array>
#include <cstdint>

namespace stereo {
struct PairSlots {
    int left = -1;
    int right = -1;
};

// Requires a verified common exposure counter relation: left = right + offset.
// Stable independent camera counters do not satisfy this contract by themselves.
inline PairSlots correspondingSlots(const std::array<uint32_t, 2>& left,
                                    const std::array<uint32_t, 2>& previousLeft,
                                    const std::array<uint32_t, 2>& right,
                                    const std::array<uint32_t, 2>& previousRight,
                                    int32_t offset) {
    PairSlots result;
    for (int l = 0; l < 2; ++l) {
        for (int r = 0; r < 2; ++r) {
            if (left[l] == previousLeft[l] || right[r] == previousRight[r] ||
                left[l] != right[r] + static_cast<uint32_t>(offset)) continue;
            const uint32_t difference = result.left < 0 ? 0 : left[l] - left[result.left];
            if (result.left < 0 || (difference != 0 && difference < 0x80000000U))
                result = {l, r};
        }
    }
    return result;
}
} // namespace stereo
