#pragma once
#include <cstdint>

namespace source_acceptance {
struct Evidence {
    uint32_t baseline=0,seq=0,input=0,drop=0,before=0,after=0;
    unsigned attempts=0,advances=0;
    bool baselineValid=false,stable=false;
    int64_t baselineMs=-1,settledMs=-1,lastAdvanceMs=-1,lastStableMs=-1;
};
enum class Result { Ok, Reset, BadFrame, Deadline };

// Called only after a coherent snapshot. Time is snapshot completion time;
// neither queue waiting nor a delayed read may extend the source deadline.
inline Result observe(Evidence& source,uint32_t previous,int64_t now,uint32_t expected) {
    const uint32_t delta=uint32_t(source.seq-previous);
    if(delta>=0x80000000u) return Result::Reset;
    if(delta) {
        source.lastAdvanceMs=now;
        if(source.settledMs>=0) {
            if(source.input!=expected || source.drop!=0) return Result::BadFrame;
            ++source.advances;
        } else if(now>=100 && now<=500 && source.input==expected && source.drop==0) {
            source.settledMs=now;
            source.advances=1;
        }
    }
    if(source.settledMs<0 && now>=500) return Result::Deadline;
    return Result::Ok;
}
inline bool readyForRestart(bool fresh,const Evidence& source) {
    return fresh && source.settledMs>=0 && source.advances>=2;
}
} // namespace source_acceptance
