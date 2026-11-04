#pragma once

#include <array>

namespace surround {

// One projection per physical stereo module until stereo calibration is known.
// Freshness is 1 for fresh, fades toward 0, and is 0 for invalid/missing/stale.
// Keep a primary selected even when both eyes are dead: geometric coverage
// must remain present so lost inputs fade toward black.
inline std::array<bool, 6> selectStereoEyes(const std::array<double, 6> &freshness) {
    std::array<bool, 6> selected{{true, true, true, true, true, true}};
    for (int primary = 0; primary <= 4; primary += 4) {
        const int backup = primary + 1;
        const bool useBackup = freshness[primary] < 1.0 && freshness[backup] > freshness[primary];
        selected[primary] = !useBackup;
        selected[backup] = useBackup;
    }
    return selected;
}

} // namespace surround
