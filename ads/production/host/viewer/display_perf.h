#pragma once

#include <array>
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace tdm {
// Fixed 0.5ms buckets, last bucket >=127.5ms. Quantiles are bucket upper
// bounds; overflow quantiles use maxMs as a conservative upper bound.
struct TimingDistribution {
    std::array<uint64_t, 256> bins{};
    uint64_t count = 0, overflow = 0;
    double sumMs = 0, maxMs = 0;
    void add(double ms) {
        if (!std::isfinite(ms) || ms < 0) return;
        const auto bin = size_t(std::min(255.0, std::floor(ms * 2)));
        ++bins[bin]; ++count; sumMs += ms; maxMs = std::max(maxMs, ms);
        if (bin == 255) ++overflow;
    }
    double mean() const { return count ? sumMs / count : 0; }
    double percentile(double fraction) const {
        if (!count) return 0;
        const uint64_t target = std::max<uint64_t>(1, uint64_t(std::ceil(count * fraction)));
        uint64_t accumulated = 0;
        for (size_t i = 0; i < bins.size(); ++i) {
            accumulated += bins[i];
            if (accumulated >= target) return i == bins.size() - 1 ? maxMs : (i + 1) * 0.5;
        }
        return 128;
    }
};

enum DisplayStage { CameraUpload, HudRegions, HudRaster, HudPack, HudUpload,
                    CameraDraw, HudDraw, PaintTotal, SettingsPaint, GuiDelay,
                    CaptureToUpload, DisplayStageCount };
struct DisplayPerfWindow {
    std::array<TimingDistribution, DisplayStageCount> time;
    uint64_t takes = 0, replacedSnapshots = 0, uploads = 0, freshPaints = 0, swaps = 0;
    uint64_t hudRebuilds = 0, hudRevision = 0, hudPeriodic = 0, hudExpired = 0, hudLayout = 0;
    uint64_t hudUploadRects = 0, hudUploadBytes = 0, hudDrawRects = 0;
    uint64_t textHits = 0, textMisses = 0, textClears = 0;
    std::array<uint64_t, 6> cameraUploads{}, cameraUploadBytes{};
};
} // namespace tdm
