#pragma once
#include "physical_pair_owner.h"

namespace physical_pair {
// Boot permits passive adoption only; only an explicit action can request VGA.
class CameraRequest {
public:
    explicit CameraRequest(uint64_t now) : began_(now) {}
    // Explicit OV5640/six action confirms the physical switch is on CAM.
    // Boot construction never carries this authorization.
    void request(uint64_t now) { pending_=true; confirmed_=true; began_=now; }
    bool confirmed() const { return confirmed_; }
    bool pending() const { return pending_; }
    bool passiveBoot() const { return pending_ && !confirmed_; }
    bool take(uint64_t now, unsigned wantedMask, unsigned appliedMask, bool capable,
              const Observation& observation, bool transitioning) {
        if(!pending_) return false;
        if(now<began_ || now-began_>8000 || wantedMask!=0x3fu ||
           (!confirmed_ && observation.coherent && runtime_camera::nativeMode(observation.descriptor.mode))) {
            log("expire",now,wantedMask,appliedMask,capable,observation,transitioning);
            pending_=false; return false;
        }
        if(!confirmed_ || transitioning || appliedMask!=0x3fu || !capable || !observation.coherent ||
           !observation.known) {
            log("wait",now,wantedMask,appliedMask,capable,observation,transitioning);return false;
        }
        log("take",now,wantedMask,appliedMask,capable,observation,transitioning);
        pending_=false;
        return true; // Owner revalidates source, mailbox, epochs and tag fences.
    }
private:
    void log(const char* event,uint64_t now,unsigned wanted,unsigned applied,bool capable,
             const Observation& observation,bool transitioning) {
        if(logged_ && now>=lastLog_ && now-lastLog_<1000)return;
        logged_=true;lastLog_=now;
        std::fprintf(stderr,"PHYSICAL_CAMERA_REQUEST event=%s elapsed_ms=%llu confirmed=%u wanted=0x%x applied=0x%x capable=%u transitioning=%u coherent=%u known=%u link=%u failure=%u\n",
            event,static_cast<unsigned long long>(now>=began_?now-began_:0),unsigned(confirmed_),wanted,applied,
            unsigned(capable),unsigned(transitioning),unsigned(observation.coherent),unsigned(observation.known),unsigned(observation.link),observation.failure);
        std::fflush(stderr);
    }
    bool logged_=false;
    uint64_t lastLog_=0;
    bool pending_=true;
    bool confirmed_=false;
    uint64_t began_;
};
} // namespace physical_pair
