#pragma once
#include "runtime_camera_geometry.h"
#include <array>

namespace runtime_camera {
// Called only after guarded sensor startup, while every worker is still stopped.
// Return the failed zero-based camera, or count once all six bindings succeed.
template<class Device>
int bindStartupGeometries(Device& device, const std::array<Geometry,count>& geometries) {
    for (int camera=0; camera<count; ++camera) {
        if (geometries[camera].camera!=camera || !geometries[camera].valid() ||
            !device.configureCameraGeometry(geometries[camera])) return camera;
    }
    return count;
}
} // namespace runtime_camera
