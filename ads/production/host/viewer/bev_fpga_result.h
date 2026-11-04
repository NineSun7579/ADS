#pragma once
// ABI for the lane result page produced by the PG2L100H (100H) BEV engine.
// The host only reads these registers; it never performs BEV or lane fitting.
#include <cstdint>

namespace bev_lane {
struct FpgaResult {
    bool present=false;
    uint32_t generation=0;
    uint32_t sequence=0;
    uint16_t valid=0;       // bit0 any, bit1 left, bit2 right
    uint16_t half=0;        // 0=left native half, 1=right native half
    uint16_t candidates=0;
    uint16_t strength=0;
    int32_t a=0,b=0,c=0;    // Q8, v(dm)=a*u^2+b*u+c, u=bird_col-125
    uint32_t samples=0;
};

// words[] follows the 0x20021200 page at 16-byte strides:
// 0 magic, 1 status, 2 generation, 3 sequence, 4 valid/half,
// 5 strength/candidates, 6 a, 7 b, 8 c, 9 schema, 10 samples,
// 11 roi width/height, 12 roi x/y.
inline bool decodeFpgaResult(const uint32_t* w, FpgaResult& r) {
    if (w[0] != 0x4e424c32u) return false;              // NBL2
    if ((w[9] >> 16) != 1u || (w[9] & 0xffffu) != 8u) return false;
    if ((w[11] >> 16) != 480u || (w[11] & 0xffffu) != 360u) return false;
    if ((w[12] >> 16) != 80u || (w[12] & 0xffffu) != 600u) return false;
    r.generation = w[2];
    r.sequence = w[3];
    r.valid = uint16_t(w[4] & 0xffffu);
    r.half = uint16_t(w[4] >> 16);
    r.strength = uint16_t(w[5] >> 16);
    r.candidates = uint16_t(w[5] & 0xffffu);
    r.a = int32_t(w[6]);
    r.b = int32_t(w[7]);
    r.c = int32_t(w[8]);
    r.samples = w[10];
    // The page is a last-completed snapshot; it remains readable while the
    // engine is already working on the opposite half.
    r.present = true;
    return true;
}
} // namespace bev_lane
