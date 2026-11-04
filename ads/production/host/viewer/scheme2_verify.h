#pragma once
#include "fpga_infer_input.h"
#include <vector>
#include <algorithm>
#include <string>

namespace scheme2 {
inline bool verify() {
    static const bool value = [] { const char* p = std::getenv("DETVIEW_FPGA_INFER_VERIFY");
        return p && std::strcmp(p, "1") == 0; }();
    return value;
}
inline unsigned verifyCount() {
    const char* p = std::getenv("DETVIEW_FPGA_INFER_VERIFY_COUNT");
    if (!p || !*p) return 12;
    char* end = nullptr; const unsigned long count = std::strtoul(p, &end, 10);
    return end && !*end && count >= 1 && count <= 10000 ? unsigned(count) : 12;
}
inline std::vector<uint8_t> golden(const void* raw, int height) {
    std::vector<uint8_t> rgb(bytes(height), 114);
    const auto* source = static_cast<const uint8_t*>(raw);
    const size_t top = height == 640 ? 80 * 640 * 3 : 0;
    for (size_t i = 0; i < 640 * 480; ++i) {
        const uint16_t pixel = uint16_t(source[2*i]) | (uint16_t(source[2*i+1]) << 8);
        const uint8_t r = (pixel >> 11) & 31, g = (pixel >> 5) & 63, b = pixel & 31;
        rgb[top+3*i] = (r << 3) | (r >> 2);
        rgb[top+3*i+1] = (g << 2) | (g >> 4);
        rgb[top+3*i+2] = (b << 3) | (b >> 2);
    }
    return rgb;
}
inline size_t mismatch(const void* a, const void* b, size_t size) {
    const auto* x = static_cast<const uint8_t*>(a);
    const auto* y = static_cast<const uint8_t*>(b);
    for (size_t i = 0; i < size; ++i) if (x[i] != y[i]) return i;
    return size;
}
}
