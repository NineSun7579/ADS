#pragma once
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <time.h>

namespace tdm {
struct InferAge {
    uint64_t id = 0;
    int generation = 0, camera = -1;
    uint32_t tag = 0;
    int64_t capturedMs = -1;
};
inline bool inferAgeEnabled() {
    static const bool value = [] {
        const char* env = std::getenv("DETVIEW_INFER_AGE");
        return env && std::strcmp(env, "1") == 0;
    }();
    return value;
}
inline void inferAgeEvent(const char* stage, const InferAge& frame, int64_t now = -1) {
    if (!inferAgeEnabled() || !frame.id || frame.capturedMs < 0) return;
    if (now < 0) {
        timespec ts{}; clock_gettime(CLOCK_MONOTONIC, &ts);
        now = int64_t(ts.tv_sec) * 1000 + ts.tv_nsec / 1000000;
    }
    std::fprintf(stderr, "[infer-age] stage=%s id=%llu generation=%d camera=%d tag=%u captured_ms=%lld event_ms=%lld age_ms=%lld\n",
        stage, (unsigned long long)frame.id, frame.generation, frame.camera, frame.tag,
        (long long)frame.capturedMs, (long long)now, (long long)(now - frame.capturedMs));
}
}
