#pragma once
#include <array>
#include <cstdint>
#include <cstdio>
#include <string>
#include "sccb_certificate.h"

namespace sccb {
constexpr const char* completionCapability = "completion-a0-f0-v1";
// Passive only: never read +20 here because that would replace the AXI witness.
template<class Read, class Report>
bool completionWitness(Read read, Report report, uint32_t base, uint32_t page,
                       uint32_t tx, uint32_t command, const Snapshot& before,
                       uint32_t functional, uint32_t status) {
    Snapshot first,last; std::string error;
    std::array<uint32_t,6> w{};
    bool guarded=snapshot(read,page,first,error);
    unsigned mask=0;
    // Attempt all supplemental reads even on a rejected certificate so a
    // contradiction is retained. Failure never enables another sensor command.
    for(unsigned i=0;i<6;++i)
        if(read(base+0xa0+16*i,w[i])) mask|=1u<<i;
    const bool tail=snapshot(read,page,last,error);
    const uint32_t expected=before.w[2]+1u;
    guarded=guarded&&tail&&first.w==last.w&&
        first.w[0]==0x53430202u&&first.w[1]==before.w[1]+1u&&
        first.w[2]==expected&&first.w[4]==expected&&first.w[7]==expected&&
        first.w[3]==command&&first.w[5]==command&&first.w[6]==command;
    const bool identity=guarded&&mask==63&&w[1]==expected&&w[3]==expected&&w[5]==expected;
    const bool ok=identity&&(w[0]&~511u)==0&&(w[2]&~4095u)==0&&
        (w[2]&0xe00u)==0x800u&&(w[0]&511u)==(w[2]&511u)&&
        (w[2]&255u)==(w[4]&255u)&&w[4]==functional&&
        ((w[2]>>8)&1u)==(status&1u)&&(status&2u);
    char text[640];
    std::snprintf(text,sizeof(text),"SCCB_WITNESS capability=%s tx=%u requested=%08x base=%08x mask=%u guard=%u generation=%u accepted=%u completed=%u expected=%u native=%08x native-id=%u destination=%08x destination-id=%u axi=%08x axi-id=%u functional=%08x status=%08x result=%s",
        completionCapability,tx,command,base,mask,unsigned(guarded),first.w[1],first.w[2],first.w[7],expected,
        w[0],w[1],w[2],w[3],w[4],w[5],functional,status,ok?"ok":"failed");
    report(std::string(text));return ok;
}
}
