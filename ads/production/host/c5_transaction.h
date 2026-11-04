#pragma once
#include <cstdint>
#include <functional>
#include <limits>
#include <string>
#include "runtime_camera_geometry.h"

namespace c5 {
constexpr uint32_t base = 0x20020000u;
constexpr uint32_t magic = 0x43355331u;
// Publication requires both optical producers; reject unknown/uninitialized masks.
constexpr bool captureAdmitted(uint32_t mask) {
    return (mask & ~0x3fu)==0 && (mask & 0x30u)==0x30u;
}
// Adapter must transfer exactly one 16-byte slot (scalar in first DWORD).
struct Board {
    std::function<bool(uint32_t,uint32_t&)> read;
    std::function<bool(uint32_t,uint32_t)> write;
    std::function<uint64_t()> nowMs;
    std::function<void()> wait;
    std::function<bool()> stopAndDrain;
    std::function<bool(uint32_t,uint32_t&)> tag;
};
struct Snapshot {
    uint32_t state=0, completed=0, dimensions=0, bytes=0, stride=0;
    uint32_t epoch=0, c6=0, error=0, frame=0, banks=0;
    uint32_t doorbell=0; // last requested transaction epoch; part of the RTL replay floor
    uint32_t publicationGeneration=0; // generation fence identity for cross-read verification
};
inline bool capable(Board& b) {
    uint32_t m=0,c=0;
    return b.read(base,m) && b.read(base+0x10,c) && m==magic &&
        (c & 0xffu)==1 && (c & 0x300u)==0x300u;
}
inline bool snapshot(Board& b,Snapshot& s) {
    uint32_t before=0,after=0;
    if(!b.read(base+0xf0,before) || (before&1u)) return false;
    uint32_t* fields[]={&s.state,&s.completed,&s.dimensions,&s.bytes,&s.stride,
        &s.epoch,&s.c6,&s.error,&s.frame,&s.banks};
    for(unsigned i=0;i<10;++i) if(!b.read(base+0x40+i*16,*fields[i])) return false;
    // The doorbell slot is read inside the same generation fence: it is the
    // epoch the RTL compares against, so a recovery must clear it as well.
    if(!b.read(base+0x30,s.doorbell)) return false;
    if(!b.read(base+0xf0,after) || before!=after || (after&1u)) return false;
    s.publicationGeneration=after;
    return true;
}
// Startup may race the optical mailbox publication while all other cameras are
// being initialized. Retry only complete, generation-fenced reads; a persistent
// failure still disables C5. Transaction snapshots intentionally remain single
// attempts so an actual switch failure is never hidden by a retry loop.
inline unsigned snapshotWithRetry(Board& b,Snapshot& s,unsigned attempts) {
    for(unsigned attempt=1;attempt<=attempts;++attempt) {
        if(snapshot(b,s)) return attempt;
        if(attempt<attempts) b.wait();
    }
    return 0;
}
inline bool fresh(uint32_t value,uint32_t prior) {
    // ABI requirement: local optical flush preserves frame counters; only global
    // reset clears them. A mode switch must advance tags, never reprime at 1/2.
    // Keep serial-number ordering and both-bank fences strict across the switch.
    return value && int32_t(value-prior)>0;
}
struct Result {
    bool ok=false, readersStopped=false; // host state only; never a hardware HOLD ACK
    bool recovery=false;                 // bounded FAILED-mailbox recovery attempt
    std::string error;
    runtime_camera::Geometry geometry;
    uint32_t epoch=0, tags[2]={0,0};
};
// Failures after stopAndDrain deliberately leave workers stopped. No rollback
// or local SCCB writes: optical transport recovery belongs to the remote ABI.
inline Result transact(Board& b,bool hd,uint32_t epoch,
                       const runtime_camera::Geometry& committed,uint64_t timeoutMs=8000) {
    Result r; r.epoch=epoch;
    auto fail=[&](const char* why) { r.error=why; return r; };
    if(!capable(b)) return fail("C5 optical runtime unsupported");
    if(!epoch || !committed.valid() || committed.camera!=4 ||
       committed.generation==std::numeric_limits<uint64_t>::max()) return fail("Invalid C5 transaction token");
    Snapshot initial;
    if(!snapshot(b,initial)) return fail("C5 initial snapshot unavailable");
    if(initial.state==1 || initial.state==2 || initial.state==3) return fail("C5 transaction busy");
    // A FAILED mailbox still accepts a doorbell: rtl100/c5_mailbox.sv admits any
    // request whose epoch exceeds the recorded epoch and the retained anti-replay
    // floor. Only the mailbox side is readable here, so a recovery attempt must
    // clear every epoch value it can see. One attempt per operator request; this
    // never loops and never re-issues by itself.
    if(initial.state==5 || initial.error) {
        const uint32_t recorded=initial.epoch>initial.completed?initial.epoch:initial.completed;
        const uint32_t floor=recorded>initial.banks?recorded:initial.banks;
        const uint32_t highest=floor>initial.doorbell?floor:initial.doorbell;
        if(epoch<=highest) return fail("C5 recovery epoch below retained floor");
        r.recovery=true;
    }
    else if(epoch==initial.completed || epoch==initial.epoch || epoch==initial.banks)
        return fail("C5 epoch already used");
    if(!b.stopAndDrain()) { r.readersStopped=true; return fail("C5/C6 drain failed"); }
    r.readersStopped=true;
    uint32_t prior[2]={0,0};
    for(int bank=0;bank<2;++bank)
        if(!b.tag(committed.tagAddress(bank),prior[bank])) return fail("C5 prior tag read failed");
    const auto target=runtime_camera::geometry(4,hd?runtime_camera::Mode::Hd720:
        runtime_camera::Mode::Default,committed.generation+1);
    uint32_t stale[2]={0,0};
    for(int bank=0;bank<2;++bank)
        if(!b.tag(target.tagAddress(bank),stale[bank])) return fail("C5 target tag fence failed");
    if(!b.write(base+0x20,hd?1u:0u) || !b.write(base+0x30,epoch)) return fail("C5 command write failed");
    const uint64_t start=b.nowMs();
    do {
        Snapshot s;
        if(snapshot(b,s)) {
            if(s.state==5 || s.error) return fail("C5 remote error/NACK");
            if(s.completed && s.completed!=initial.completed && s.completed!=epoch)
                return fail("C5 foreign completion epoch");
            if(s.state==4 && s.completed==epoch) {
                if(s.epoch!=epoch || s.banks!=epoch) return fail("C5 stale effective/bank epoch");
                if(s.dimensions!=((target.width<<16)|target.height) || s.bytes!=target.pixelBytes ||
                   s.stride!=target.stride || s.c6!=0x028001e0u || !s.frame)
                    return fail("C5 published geometry mismatch");
                bool ready=true;
                for(int bank=0;bank<2;++bank) {
                    if(!b.tag(target.tagAddress(bank),r.tags[bank])) return fail("C5 fresh tag read failed");
                    ready=ready && fresh(r.tags[bank],prior[bank]) && r.tags[bank]!=stale[bank];
                }
                Snapshot verify;
                if(ready && snapshot(b,verify) && verify.state==4 && verify.completed==epoch &&
                   verify.epoch==epoch && verify.banks==epoch && !verify.error &&
                   verify.dimensions==s.dimensions && verify.bytes==s.bytes &&
                   verify.stride==s.stride && verify.c6==s.c6) {
                    r.ok=true; r.geometry=target; return r;
                }
            }
        }
        b.wait();
    } while(b.nowMs()-start<timeoutMs);
    return fail("C5 completion timeout");
}
} // namespace c5
