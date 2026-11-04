#pragma once
#include "motion_abi.h"
#include <algorithm>
#include <cstdint>

namespace motion {
// Latest source-frame hint, never an association to a DDR tag/image.
struct Evidence {
    Record record;
    bool have=false, failed=false, sequenceFault=false;
    int sourceGeneration=-1;
    int64_t observedMs=-1, advancedMs=-1, motionUntilMs=-1;
};
inline bool consistent(const Record& r) {
    if (r.reservedInvalid || r.blocks>192 || r.samples>19200) return false;
    unsigned count=0, minX=16, minY=12, maxX=0, maxY=0;
    for (unsigned bit=0;bit<192;++bit) if (r.bitmap[bit/32]&(uint32_t(1)<<(bit%32))) {
        ++count; minX=std::min(minX,bit%16); maxX=std::max(maxX,bit%16);
        minY=std::min(minY,bit/16); maxY=std::max(maxY,bit/16);
    }
    if (count!=r.blocks || r.samples<count*8 || r.bboxValid!=(count!=0)) return false;
    return !count || (r.minX==minX && r.maxX==maxX && r.minY==minY && r.maxY==maxY);
}
class Observer {
public:
    Evidence evidence;
    uint64_t gaps=0, resets=0;
    void reset(int generation) { evidence=Evidence{}; evidence.sourceGeneration=generation; }
    void failure() { evidence.failed=true; }
    void observe(const Record& record, int64_t now, int generation) {
        if (evidence.sourceGeneration!=generation) reset(generation);
        bool fault=false;
        bool newlyObserved=!evidence.have;
        if (!evidence.have) evidence.advancedMs=-1; // require an observed advance before static gating
        else {
            const uint32_t delta=record.seq-evidence.record.seq;
            if (delta && delta<0x80000000u) {
                newlyObserved=true;
                evidence.advancedMs=now; gaps+=delta-1;
            } else if (delta) {
                fault=true; ++resets; evidence.advancedMs=-1;
                evidence.motionUntilMs=-1;
            } else fault=evidence.sequenceFault;
        }
        evidence.record=record; evidence.have=true; evidence.failed=false;
        evidence.observedMs=now; evidence.sequenceFault=fault;
        if (newlyObserved && !fault && record.referenceValid && !record.error && consistent(record) && record.blocks)
            evidence.motionUntilMs=now+500;
    }
};
enum class Reason { Legacy, StaticDeferred, Motion, Fallback, Periodic, Minimum };
struct Decision { bool request; Reason reason; };
// Deadline-aware worker wait; retain a 20ms maintenance/lease-retirement poll.
// This only shortens sleep and never grants inference admission.
inline int retryDelayMs(Reason reason, int64_t now, int64_t lastRequest,
        bool tracking, bool urgent, int detectionInterval, int minimumInterval,
        int refreshInterval) {
    if (lastRequest<0) return 20;
    const int minimum=std::max(1,minimumInterval);
    const int interval=reason==Reason::Minimum ? minimum :
        reason==Reason::StaticDeferred ? std::max(minimum,std::clamp(refreshInterval,100,tracking ? 250 : 500)) :
        urgent ? minimum : std::max(minimum,detectionInterval);
    return int(std::clamp<int64_t>(lastRequest+interval-now,1,20));
}
inline bool fresh(const Evidence& e, int64_t now, int generation) {
    return e.have && !e.failed && !e.sequenceFault && e.sourceGeneration==generation &&
        e.observedMs>=0 && e.advancedMs>=0 && now>=e.observedMs && now>=e.advancedMs &&
        now-e.observedMs<=300 && now-e.advancedMs<=300 &&
        e.record.referenceValid && !e.record.error && consistent(e.record);
}
inline Decision decide(bool enabled, bool tracking, bool lane, int camera, int generation,
        const Evidence& e, int64_t now, int64_t lastRequest, bool urgent,
        int detectionInterval=250, int minimumInterval=100, int refreshInterval=250) {
    const int minimum=std::max(1,minimumInterval);
    // Missing/stale hints must not bypass the configured inference minimum,
    // including no-tracking fallback and virtual HDMI analytics.
    if (enabled && !lane && lastRequest>=0 && now-lastRequest<minimum) return {false,Reason::Minimum};
    const bool eligible=enabled && !lane && camera>=0 && camera<4;
    const bool valid=eligible && fresh(e,now,generation);
    if (!valid) {
        const bool due=lane || !tracking || lastRequest<0 ||
            now-lastRequest>= (urgent ? minimum : std::max(minimum,detectionInterval));
        return {due, enabled ? Reason::Fallback : Reason::Legacy};
    }
    if (lastRequest>=0 && now-lastRequest<minimum) return {false,Reason::Minimum};
    if (urgent || e.record.blocks || now<e.motionUntilMs) return {true,Reason::Motion};
    // Refresh covers stationary objects and unobserved between-poll events.
    if (lastRequest<0 || now-lastRequest>=std::max(minimum,std::clamp(refreshInterval,100,tracking ? 250 : 500)))
        return {true,Reason::Periodic};
    return {false,Reason::StaticDeferred};
}
} // namespace motion
