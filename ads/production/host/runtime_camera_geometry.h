#pragma once
#include <cstddef>
#include <cstdint>

namespace runtime_camera {
// Isolated descendant of motion_viewer/runtime_camera_geometry.h.
// Geometry only: wire mode 2 still requires future capability/ABI admission.
// Camera indices are zero based. This contract assigns no runtime registers.
constexpr int count = 6;
constexpr uint32_t bankBytes = 2u * 1024u * 1024u;
constexpr uint32_t commitBytes = 16;
enum class Mode { Default = 0, Hd720 = 1, FullVga = 2, Native480 = 3, Native960 = 4 };
constexpr bool nativeMode(Mode mode) { return mode == Mode::Native480 || mode == Mode::Native960; }
constexpr bool nativeCamera(int camera) { return camera == 4 || camera == 5; }
constexpr bool supportsHd(int camera) { return camera == 0 || camera == 2 || camera == 3 || camera == 4; }
constexpr bool validCamera(int camera) { return camera >= 0 && camera < count; }
constexpr bool supportsMode(int camera, Mode mode) {
    return validCamera(camera) &&
        (mode == Mode::Default ||
         (mode == Mode::Hd720 && supportsHd(camera)) ||
         (mode == Mode::FullVga && (camera == 2 || camera == 3)) ||
         (nativeMode(mode) && nativeCamera(camera)));
}

// Explicit transport encoding; never infer sensor HD from a nonzero mode.
// On failure the caller's output is unchanged. Camera support is checked separately.
inline bool modeFromWire(uint32_t wire, Mode& mode) {
    switch (wire) {
    case 0: mode = Mode::Default; return true;
    case 1: mode = Mode::Hd720; return true;
    case 2: mode = Mode::FullVga; return true;
    case 3: mode = Mode::Native480; return true;
    case 4: mode = Mode::Native960; return true;
    default: return false;
    }
}
inline bool modeToWire(Mode mode, uint32_t& wire) {
    switch (mode) {
    case Mode::Default: wire = 0; return true;
    case Mode::Hd720: wire = 1; return true;
    case Mode::FullVga: wire = 2; return true;
    case Mode::Native480: wire = 3; return true;
    case Mode::Native960: wire = 4; return true;
    default: return false;
    }
}

struct Geometry {
    int camera = -1;
    Mode mode = Mode::Default;
    uint32_t width = 0, height = 0, stride = 0;
    uint32_t pixelBytes = 0, tagOffset = 0;
    uint32_t ping = 0, pong = 0;
    uint64_t generation = 0;
    uint32_t transferBytes() const { return pixelBytes + commitBytes; }
    uint32_t bank(int index) const { return index == 0 ? ping : pong; }
    uint32_t tagAddress(int index) const { return bank(index) + tagOffset; }
    bool valid() const {
        if (!supportsMode(camera, mode) || !generation) return false;
        const bool compressed = mode == Mode::Default && (camera == 2 || camera == 3);
        const uint32_t w = mode == Mode::Hd720 ? 1280 : compressed ? 320 : 640;
        const uint32_t h = mode == Mode::Native960 ? 960 : mode == Mode::Hd720 ? 720 : compressed ? 240 : 480;
        const uint32_t base = 0x00800000u + uint32_t(camera) * 0x00400000u;
        return width == w && height == h && stride == w * 2 &&
            pixelBytes == stride * height && tagOffset == pixelBytes &&
            uint64_t(pixelBytes) + commitBytes <= bankBytes &&
            ping == base && pong == base + bankBytes;
    }
    bool acceptsPublication(uint64_t frameGeneration, size_t bytes) const {
        return valid() && frameGeneration == generation && bytes == pixelBytes;
    }
};

// A C3/C4 transfer larger than the compressed frame is only ever admitted against
// an exact uncompressed descriptor: HD/VGA mode, contract length, offset 0 and one
// of the two documented banks. The host wire-guard consults this for the target
// descriptor of an in-flight pair transaction as well as for the committed one,
// and its hardware-free regression exercises the same predicate.
inline bool admitsLargeTransfer(const Geometry& geometry, uint32_t address,
                               uint32_t totalLength, uint32_t offset) {
    return geometry.valid() && (geometry.camera == 2 || geometry.camera == 3) &&
        (geometry.mode == Mode::Hd720 || geometry.mode == Mode::FullVga) &&
        totalLength == geometry.transferBytes() && offset == 0 &&
        (address == geometry.ping || address == geometry.pong);
}

inline Geometry geometry(int camera, Mode mode = Mode::Default, uint64_t generation = 1) {
    Geometry g;
    if (!supportsMode(camera, mode) || !generation) return g;
    const bool compressed = mode == Mode::Default && (camera == 2 || camera == 3);
    g.camera = camera; g.mode = mode; g.generation = generation;
    g.width = mode == Mode::Hd720 ? 1280 : compressed ? 320 : 640;
    g.height = mode == Mode::Native960 ? 960 : mode == Mode::Hd720 ? 720 : compressed ? 240 : 480;
    g.stride = g.width * 2; g.pixelBytes = g.stride * g.height; g.tagOffset = g.pixelBytes;
    g.ping = 0x00800000u + uint32_t(camera) * 0x00400000u; g.pong = g.ping + bankBytes;
    return g;
}
// 100H descriptor words at 0x20021000 + 0x10*i. Accept only a consistent
// active descriptor; each C5/C6 bank holds one 640-wide half.
inline Mode nativeDescriptorMode(const uint32_t words[9]) {
    if (words[0] != 0x4e484d31u || words[1] != 1 || !(words[2] & 4u) || !words[3]) return Mode::Default;
    const Mode mode = (words[2] & 3u) == 2 ? Mode::Native480 : (words[2] & 3u) == 3 ? Mode::Native960 : Mode::Default;
    if (!nativeMode(mode)) return Mode::Default;
    const Geometry left = geometry(4, mode), right = geometry(5, mode);
    if (!left.valid() || !right.valid() || left.width * 2 != words[4] || left.height != words[5] ||
        left.width != words[6] || left.pixelBytes != words[7] || left.stride != words[8]) return Mode::Default;
    return mode;
}
inline bool freshNativePair(const Geometry& left, const Geometry& right,
                            uint64_t leftSequence, uint64_t rightSequence,
                            uint64_t priorLeft, uint64_t priorRight) {
    return left.valid() && right.valid() && left.camera == 4 && right.camera == 5 &&
        nativeMode(left.mode) && left.mode == right.mode &&
        left.width == right.width && left.height == right.height &&
        leftSequence != 0 && rightSequence != 0 &&
        leftSequence != priorLeft && rightSequence != priorRight;
}
struct NativeDescriptor {
    Mode mode = Mode::Default;
    uint32_t generation = 0;
    bool operator==(const NativeDescriptor& other) const {
        return mode == other.mode && generation == other.generation;
    }
    bool operator!=(const NativeDescriptor& other) const { return !(*this == other); }
};
inline bool coherentNativeDescriptor(const uint32_t first[9], const uint32_t second[9], NativeDescriptor& out) {
    for (int i = 0; i < 9; ++i) if (first[i] != second[i]) return false;
    const Mode mode = nativeDescriptorMode(first);
    // An active NHM1 page with inconsistent fields is a failed observation,
    // not evidence that the source reverted to legacy mode.
    if (first[0] == 0x4e484d31u && (first[2] & 4u) && !nativeMode(mode)) return false;
    out.mode = mode;
    out.generation = nativeMode(mode) ? first[3] : 0;
    return true;
}
} // namespace runtime_camera
