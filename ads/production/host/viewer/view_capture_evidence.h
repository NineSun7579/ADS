#pragma once
#include <cstddef>
#include <cstdint>

namespace tdm {
// Owned by the capture thread. Call rearm only with accepted geometry tags
// and publication/error counters protected by the caller's existing lock.
template<class Clock, std::size_t Cameras> struct ViewCaptureEvidence {
    Clock clock;
    unsigned transaction=0;
    int64_t lastSample=-500;
    uint32_t tags[Cameras][2]={};
    uint64_t reads[Cameras]={},publications[Cameras]={},errors[Cameras]={};

    void rearm(const uint32_t (&newTags)[Cameras][2],
               const uint64_t (&newReads)[Cameras],
               const uint64_t (&newPublications)[Cameras],
               const uint64_t (&newErrors)[Cameras]) {
        for(std::size_t c=0;c<Cameras;++c) {
            for(int bank=0;bank<2;++bank) tags[c][bank]=newTags[c][bank];
            reads[c]=newReads[c];
            publications[c]=newPublications[c];
            errors[c]=newErrors[c];
        }
        ++transaction;
        lastSample=-500;
        clock.start();
    }
};
}
