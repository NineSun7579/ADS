#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include "fair_dma.h"
#include "runtime_camera_geometry.h"

namespace tdm {
constexpr uint32_t cameraFrameBytes = 640u * 480u * 2u;
constexpr uint32_t cameraSlotStride = 0x97000u;
constexpr uint32_t cameraScratchOffset = 0x3ff000u;
constexpr uint32_t cameraAllocationBytes = 4u * 1024u * 1024u;
constexpr uint32_t cameraSlotOffset(int camera) { return uint32_t(camera) * cameraSlotStride; }
static_assert(cameraFrameBytes + 16 <= cameraSlotStride, "Frame and commit tag must fit in one slot");
static_assert(cameraSlotOffset(5) + cameraFrameBytes + 16 <= cameraScratchOffset,
              "Six frame slots must not overlap the shared metadata scratch area");
static_assert(cameraScratchOffset + 16 <= cameraAllocationBytes, "Scratch must fit RX allocation");

// cameraRead validates the exact committed descriptor before selecting RX space.
// HD C5 cannot use its legacy VGA slot: that would exceed the shared RX window.
inline bool cameraLandingOffset(const runtime_camera::Geometry& geometry,uint32_t& offset) {
    if(!geometry.valid()) return false;
    const bool wholeWindow=(geometry.camera==2 || geometry.camera==3 || geometry.camera==4 ||
                            runtime_camera::nativeMode(geometry.mode)) &&
        geometry.mode!=runtime_camera::Mode::Default;
    offset=wholeWindow?0:cameraSlotOffset(geometry.camera);
    return true;
}

inline bool newerCameraTag(uint32_t a, uint32_t b) {
    return a != b && uint32_t(a - b) < 0x80000000u;
}
inline int newestCameraBank(uint32_t a, uint32_t b, bool delivered, uint32_t last) {
    const int bank = newerCameraTag(a, b) ? 0 : 1;
    const uint32_t selected = bank == 0 ? a : b;
    if ((!delivered && a == 0 && b == 0) || (delivered && !newerCameraTag(selected, last))) return -1;
    return bank;
}

inline bool validNativeTag(uint32_t tag) { return tag != 0 && tag != 0xffffffffu; }
inline int newestNativeBank(uint32_t a, uint32_t b, bool delivered, uint32_t last) {
    const bool validA = validNativeTag(a), validB = validNativeTag(b);
    if (!validA && !validB) return -1;
    const int bank = !validB ? 0 : !validA ? 1 : newerCameraTag(a, b) ? 0 : 1;
    const uint32_t selected = bank == 0 ? a : b;
    if (delivered && validNativeTag(last) && !newerCameraTag(selected, last)) return -1;
    return bank;
}

// Ported from the running camview's dma_copy.h. Preserve exact bytes including
// tails; four 128-bit loads reduce narrow-load overhead on coherent mappings.
inline void copyCameraPixels(void* destination, const void* source, size_t size) {
#if defined(__aarch64__)
    auto* dst = static_cast<uint8_t*>(destination);
    const auto* src = static_cast<const uint8_t*>(source);
    while (size >= 64) {
        asm volatile(
            "ldp q0, q1, [%[src]]\n\t"
            "ldp q2, q3, [%[src], #32]\n\t"
            "stp q0, q1, [%[dst]]\n\t"
            "stp q2, q3, [%[dst], #32]\n\t"
            : : [src] "r" (src), [dst] "r" (dst)
            : "v0", "v1", "v2", "v3", "memory");
        src += 64; dst += 64; size -= 64;
    }
    if (size) std::memcpy(dst, src, size);
#else
    std::memcpy(destination, source, size);
#endif
}
// Shared staging can overlap any legacy camera slot. Submit, validate and copy
// within this scope; never return an RX pointer or re-enter the transport mutex.
template<class Work>
inline auto withCameraRxOwnership(FairDmaMutex* mutex, Work work) -> decltype(work()) {
    FairDmaGuard owner(mutex);
    return work();
}
inline bool copyCommittedCameraPixels(void* output, const uint8_t* rx,
                                      uint32_t bytes, uint32_t selected) {
    uint32_t actual = 0;
    std::memcpy(&actual, rx + bytes, sizeof(actual));
    if (actual != selected) return false;
    copyCameraPixels(output, rx, bytes);
    return true;
}
int runCameraDmaSelfTest();
} // namespace tdm
