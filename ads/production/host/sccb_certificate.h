#pragma once
#include <array>
#include <cstdint>
#include <functional>
#include <string>

// Native equivalent of host_readonly_probe.py SCC2 aligned ABI contracts.
// Passive reads only; no mutex here: transport owns the shared DMA lock.
namespace sccb {
struct Snapshot {
    std::array<uint32_t,16> w{};
};
inline bool snapshot(const std::function<bool(uint32_t,uint32_t&)>& read,
                     uint32_t page,Snapshot& s,std::string& error) {
    for(unsigned i=0;i<16;++i) if(!read(page+16*i,s.w[i])) {
        error="mailbox transport-read failed";return false;
    }
    uint32_t accepted=0,generation=0;
    if(!read(page+0x20,accepted)||!read(page+0x10,generation)) {
        error="mailbox guard-read failed";return false;
    }
    if(s.w[0]!=0x53430202u) {error="wrong SCC2 diagnostic signature";return false;}
    if(s.w[1]!=generation||s.w[2]!=accepted) {error="mailbox generation/accepted changed during reads";return false;}
    return true;
}
inline uint8_t sampled(const Snapshot& s) {
    uint8_t byte=0;
    for(unsigned n=0;n<8;++n) byte|=((s.w[11]>>(n+1))&1u)<<(7-n);
    return byte;
}
inline bool quiescent(const Snapshot& s) {
    return s.w[2]==s.w[4]&&s.w[4]==s.w[7]&&!(s.w[8]&0x80000000u);
}
inline bool validate(const Snapshot& before,const Snapshot& after,uint32_t command,
                     uint32_t functional,uint32_t status,std::string& error) {
    auto fail=[&](const char* text){error=text;return false;};
    for(unsigned i:{1u,2u,7u}) if(after.w[i]!=before.w[i]+1u)
        return fail("identity/generation did not advance exactly once");
    if(after.w[4]!=after.w[2]||after.w[4]!=before.w[4]+1u)
        return fail("unassociated driver take");
    for(unsigned i:{3u,5u,6u}) if(after.w[i]!=command)
        return fail("requested/accepted/taken/loaded payload mismatch");
    const bool read=(command&(1u<<24))!=0;
    const uint32_t raw=after.w[8];
    if((raw&0x80000000u)||((raw>>21)&255u)!=(read?1u:0u))
        return fail("mailbox overflow or observer interference/context flags");
    if(status!=2u||(raw&256u)||((raw>>17)&15u)) return fail("functional/diagnostic NACK or status mismatch");
    if(((raw>>9)&255u)!=(read?8u:0u)) return fail("sample count mismatch");
    if(read&&sampled(after)!=uint8_t(raw)) return fail("phase2/raw byte mismatch");
    if(uint8_t(functional)!=uint8_t(raw)) return fail("functional/raw byte mismatch");
    if(after.w[15]-after.w[13]!=1u || after.w[14]-after.w[15]==0u ||
       after.w[14]-after.w[15]>=0x80000000u) return fail("invalid take/load/done timestamps");
    return true;
}
}
