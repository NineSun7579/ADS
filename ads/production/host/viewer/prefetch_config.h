#pragma once
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace scheme2 {
struct LeadConfig { int64_t milliseconds; bool valid; };
// Strict ASCII decimal: signs, empty strings and all whitespace are rejected.
// Bound before multiplication so arbitrarily long input cannot overflow.
inline LeadConfig parsePrefetchLead(const char* text) {
    if (!text) return {30, true};
    if (!*text) return {0, false};
    int64_t value = 0;
    for (const char* p = text; *p; ++p) {
        if (*p < '0' || *p > '9') return {0, false};
        const int digit = *p - '0';
        if (value > (120 - digit) / 10) return {0, false};
        value = value * 10 + digit;
    }
    return {value, true};
}
// Call only inside the RGB-enabled branch. Initialization and warning happen once.
inline int64_t prefetchLeadMs() {
    static const LeadConfig value = [] {
        const auto parsed = parsePrefetchLead(std::getenv("DETVIEW_FPGA_PREFETCH_LEAD_MS"));
        if (!parsed.valid) std::fprintf(stderr,
            "[fpga-prefetch] invalid DETVIEW_FPGA_PREFETCH_LEAD_MS; using lead_ms=0 (expected decimal 0..120, no whitespace)\n");
        return parsed;
    }();
    return value.milliseconds;
}
inline bool prefetchTimingEnabled() {
    static const bool value = [] {
        const char* p = std::getenv("DETVIEW_FPGA_PREFETCH_TIMING");
        return p && std::strcmp(p, "1") == 0;
    }();
    return value;
}
struct PrefetchTiming {
    int64_t arm = -1, claim = -1, holdCommand = -1, holdValidated = -1;
    int64_t release = -1, publish = -1, request = -1;
    bool ordered() const {
        return arm >= 0 && arm <= claim && claim <= holdCommand &&
            holdCommand <= holdValidated && holdValidated <= release &&
            release <= publish && publish <= request;
    }
};
}
