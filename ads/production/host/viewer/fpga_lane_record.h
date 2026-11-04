#pragma once
// Same-frame FPGA lane record in commit tag bytes 4..15 (little endian).
//
// LANE_REC v3. The 100H runs ONE ground-plane lane detector over the left
// (c5) half of the merged 1280x960 native HDMI picture and publishes TWO
// records from the same measurement:
//
//   c5 commit tag -> v3 record carrying the LEFT  boundary of the ego lane
//   c6 commit tag -> v3 record carrying the RIGHT boundary (same left model,
//                    shifted by one 3.5 m lane width in bird's-eye space)
//
// Both records use PICTURE columns 0..1279, so a consumer decodes the two and
// builds a single quad over the joined picture. The video pixel stream is never
// modified; this record is the only channel by which the lane region reaches
// the host.
//
// 96-bit layout, bit 0 = first byte after the 4-byte commit tag:
//   [3:0]   version = 3
//   [4]     present  (a model exists and is younger than 8 frames)
//   [5]     valid    (mirrors present)
//   [6]     zero
//   [17:7]  x at the near row      (picture column, 11 bits, unsigned)
//   [28:18] x at the mid  row
//   [39:29] x at the far  row
//   [47:40] accepted rows this frame (saturated at 255)
//   [63:48] sequence
//   [66:64] age in frames since the last accepted fit (0..7)
//   [78:67] roi_base: absolute picture row of ROI-relative row 0
//   [95:79] zero
//
// The ROI is the bottom 360 rows of the picture CONTENT, not of the raster: the
// source is letterboxed (its last picture row is 839 in a 960-row frame), so
// the host must use roi_base from the record rather than deriving it from the
// frame height.
#include <array>
#include <cstdint>
#include <cstring>

namespace fpga_lane {
constexpr uint32_t version = 3;
// ROI-relative rows the three fitted samples belong to.
constexpr int nearRow = 333, midRow = 255, farRow = 190;
// Published record goes stale after this many frames without a fit.
constexpr int ageExpire = 8;

struct Line {
    bool valid = false;
    int xNear = 0, xMid = 0, xFar = 0;
};
struct Record {
    bool present = false;
    int roiY = 0;        // absolute picture row of ROI-relative row 0
    int age = 0;         // 0 = fitted this frame
    int rows = 0;        // rows accepted this frame
    uint16_t sequence = 0;
    Line left, right;    // only the side named by decode()'s isLeft is filled
};
using Words = std::array<uint32_t, 3>;

inline uint32_t bits(const Words& w, int lsb, int width) {
    uint64_t v = 0;
    for (int i = 0; i < width; ++i) {
        const int b = lsb + i;
        v |= uint64_t((w[b / 32] >> (b % 32)) & 1u) << i;
    }
    return uint32_t(v);
}
inline Words fromTagBytes(const uint8_t* tag16) {
    Words w{};
    std::memcpy(w.data(), tag16 + 4, 12);
    return w;
}
// isLeft selects which boundary this record carries: true for the c5 tag
// (left marking), false for the c6 tag (right marking).
inline Record decode(const Words& w, int imageWidth, int imageHeight, bool isLeft) {
    Record r;
    if (imageWidth <= 0 || imageHeight <= 0) return r;
    if (bits(w, 0, 4) != version || !bits(w, 4, 1)) return r;
    r.roiY = int(bits(w, 78, 12));
    r.present = true;
    r.age = int(bits(w, 66, 3));
    r.rows = int(bits(w, 47, 8));
    r.sequence = uint16_t(bits(w, 63, 16));
    Line& side = isLeft ? r.left : r.right;
    side.valid = true;
    side.xNear = int(bits(w, 7, 11));
    side.xMid = int(bits(w, 18, 11));
    side.xFar = int(bits(w, 29, 11));
    return r;
}
} // namespace fpga_lane
