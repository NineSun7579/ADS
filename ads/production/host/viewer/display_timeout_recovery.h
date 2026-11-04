#pragma once
#include "acquisition_epoch.h"
#include "../runtime_camera_geometry.h"
#include <cstdint>

namespace display_timeout {
constexpr const char* reason = "CAMERA ERROR (NO_FRAME_TIMEOUT)";
constexpr int64_t freshnessMs = 1000;
inline bool fresh(int64_t captured, int64_t now) {
    return captured > 0 && now >= captured && now - captured < freshnessMs;
}

// Shared by the controller and hardware-free tests. Empty tickets are not
// evidence: each admitted channel must carry its producer's own current epoch.
template<class Frame>
unsigned liveDisplayFrame(const Frame& frame, int generation, unsigned requestedMask, int64_t now) {
    if(frame.video || frame.generation != generation || (unsigned(frame.paneMask) & ~0x3fu)) return 0;
    const unsigned visible = unsigned(frame.paneMask) & requestedMask & (frame.hdmiFull ? 0x30u : 0x3fu);
    unsigned live = 0;
    for(int camera = 0; camera < runtime_camera::count; ++camera) {
        const unsigned bit = 1u << camera;
        if(!(visible & bit)) continue;
        const auto& geometry = frame.geometries[camera];
        const auto& ticket = frame.cameraAcquisitions[camera];
        if(geometry.camera != camera || frame.cameraGenerations[camera] != generation ||
           !frame.cameraSequences[camera] || frame.cameraPixels[camera].size() == 0 ||
           !geometry.acceptsPublication(geometry.generation, size_t(frame.cameraPixels[camera].size())) ||
           !fresh(frame.capturedMs[camera], now) || !fresh(frame.rawCapturedMs[camera], now) ||
           ticket.mask != bit || !acquisition::current(ticket)) continue;
        live |= bit;
    }
    return live;
}

inline bool canRecover(bool reported, bool accepted, unsigned liveMask,
                       bool paused, bool switching, bool resolutionError, bool runtimeHold,
                       bool timeoutError) {
    return reported && accepted && liveMask && !paused && !switching &&
        !resolutionError && !runtimeHold && timeoutError;
}
} // namespace display_timeout
