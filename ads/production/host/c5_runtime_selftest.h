#pragma once
#include "c5_transaction.h"
#include <iostream>
#include <map>
#include <stdexcept>
namespace c5_test {
inline void require(bool ok,const char* reason) { if(!ok) throw std::runtime_error(reason); }
struct Fake {
    std::map<uint32_t,uint32_t> regs;
    unsigned writes=0, stops=0, ticks=0;
    uint64_t clock=0;
    int fault=0;
    bool submitted=false;
    bool hd=true;
    Fake() {
        regs[c5::base]=c5::magic; regs[c5::base+0x10]=0x301;
        regs[c5::base+0xf0]=2;
    }
    c5::Board board() {
        return {
            [&](uint32_t a,uint32_t& v){require((a&15u)==0,"unaligned slot read");v=regs[a];return true;},
            [&](uint32_t a,uint32_t v){
                require((writes==0 && a==c5::base+0x20 && v==uint32_t(hd)) ||
                       (writes==1 && a==c5::base+0x30 && v==7),"doorbell write order/mode/epoch");
                ++writes;regs[a]=v;if(a==c5::base+0x30)submitted=true;return true;},
            [&]{return clock;},
            [&]{clock+=10;++ticks;if(!submitted || fault==1)return;
                regs[c5::base+0x40]=fault==2?5:4;
                regs[c5::base+0x50]=fault==3?99:7;
                regs[c5::base+0x60]=fault==4?0x028001e0:hd?0x050002d0:0x028001e0;
                regs[c5::base+0x70]=fault==5?614400:hd?1843200:614400;
                regs[c5::base+0x80]=fault==13?1:hd?2560:1280;
                regs[c5::base+0x90]=fault==6?6:7;
                regs[c5::base+0xa0]=fault==12?0x050002d0:0x028001e0;
                regs[c5::base+0xc0]=fault==14?0:42;
                regs[c5::base+0xd0]=fault==7?6:7;
                if(fault==8)regs[c5::base+0xf0]=3;
            },
            [&]{++stops;return fault!=11;},
            [&](uint32_t address,uint32_t& v){v=(ticks && fault!=9 &&
                !(fault==10 && address==0x01a00000u+1843200))?42:12;return true;}
        };
    }
};
inline int run() {
    try {
    for(uint32_t mask=0;mask<64;++mask)
        require(c5::captureAdmitted(mask)==((mask&0x30u)==0x30u),"optical producer mask admission");
    for(uint32_t mask:{0u,0x0du,0x10u,0x20u,0x40u,0x70u,0x130u,UINT32_MAX}) {
        Fake f;auto b=f.board();
        require(!c5::captureAdmitted(mask),"invalid/parked optical mask admitted");
        // Mirror the GUI's upfront guard: a rejection never enters transact.
        if(c5::captureAdmitted(mask)) (void)c5::transact(b,true,7,runtime_camera::geometry(4),80);
        require(!f.writes && !f.stops && !f.submitted,"mask rejection drained or wrote request");
    }
    require(c5::captureAdmitted(0x30u) && c5::captureAdmitted(0x3fu),"HDMI/overview mask rejected");
    const auto original=runtime_camera::geometry(4);
    require(original.valid() && original.width==640 && original.height==480,"C5 default geometry");
    require(!runtime_camera::supportsHd(5),"C6 gained HD support");
    for(int fault=0;fault<=14;++fault) {
        Fake f;f.fault=fault;auto b=f.board();
        const auto result=c5::transact(b,true,7,original,80);
        require(result.ok==(fault==0),"transaction fault result");
        require(result.readersStopped && f.stops==1,"host stop/drain not retained");
        require(original.generation==1 && original.pixelBytes==614400,"committed input changed");
        if(!result.ok) require(!result.geometry.valid(),"failure published target geometry");
        if(result.ok)require(result.geometry.generation==2 && result.geometry.pixelBytes==1843200,"HD result geometry");
    }
    {Fake f;f.regs[c5::base]=0;auto b=f.board();require(!c5::transact(b,true,7,original).ok,"old hardware accepted");require(!f.writes&&!f.stops,"old hardware side effect");}
    for(uint32_t caps:{0x101u,0x302u,0u}) {
        Fake f;f.regs[c5::base+0x10]=caps;auto b=f.board();
        require(!c5::transact(b,true,7,original).ok,"bad caps accepted");require(!f.writes&&!f.stops,"bad caps side effect");
    }
    {Fake f;f.regs[c5::base+0x40]=1;auto b=f.board();require(!c5::transact(b,true,7,original).ok,"busy accepted");require(!f.writes&&!f.stops,"busy overwritten");}
    {Fake f;f.regs[c5::base+0x50]=7;auto b=f.board();require(!c5::transact(b,true,7,original).ok,"reused epoch accepted");require(!f.writes,"reused epoch written");}
    {Fake f;f.hd=false;auto b=f.board();const auto r=c5::transact(b,false,7,
        runtime_camera::geometry(4,runtime_camera::Mode::Hd720),80);
     require(r.ok && r.geometry.pixelBytes==614400 && r.geometry.width==640,"VGA return failed");}
    {Fake f;auto b=f.board();unsigned reads=0;
     b.read=[&](uint32_t a,uint32_t& v){v=a==c5::base+0xf0?2*(++reads):f.regs[a];return true;};
     require(!c5::transact(b,true,7,original).ok,"incoherent snapshot accepted");require(!f.writes&&!f.stops,"incoherent snapshot side effect");}
    {Fake f;auto b=f.board();c5::Snapshot s;unsigned generationReads=0,valuesReads=0;
     b.read=[&](uint32_t a,uint32_t& v){
         if(a==c5::base+0xf0) {
             ++generationReads;
             // First fenced read: gen=2 then gen=4 (torn); second: gen=6/6.
             v=generationReads<=2?generationReads*2u:6u;
         } else {++valuesReads;v=f.regs[a];}
         return true;
     };
     require(c5::snapshotWithRetry(b,s,8)==2,"coherent startup snapshot not retried");
     require(generationReads==4 && valuesReads==22,"startup retry reused a partial snapshot");
     require(f.ticks==1 && !f.writes && !f.stops,"startup retry wrote or drained");
    }
    {Fake f;auto b=f.board();c5::Snapshot s;unsigned generationReads=0;
     b.read=[&](uint32_t a,uint32_t& v){if(a==c5::base+0xf0){v=2*(++generationReads);return true;}v=f.regs[a];return true;};
     require(c5::snapshotWithRetry(b,s,8)==0,"persistent torn startup snapshot accepted");
     require(generationReads==16 && f.ticks==7 && !f.writes && !f.stops,"startup retry bound/failure side effects");
    }
    for(bool resetCounters:{false,true}) {
        Fake f;auto b=f.board();
        const auto target=runtime_camera::geometry(4,runtime_camera::Mode::Hd720,2);
        b.tag=[&](uint32_t address,uint32_t& value) {
            // Old VGA and target-HD locations are fenced before the command.
            // After publication, distinguish the new ping/pong tags explicitly.
            if(!f.ticks) value=10000;
            else if(address==target.tagAddress(0)) value=resetCounters?1u:10001u;
            else if(address==target.tagAddress(1)) value=resetCounters?2u:10002u;
            else return false;
            return true;
        };
        const auto result=c5::transact(b,true,7,original,80);
        require(result.ok==!resetCounters,"local flush counter continuity contract");
        require(f.writes==2 && f.stops==1,"counter continuity case did not exercise command");
        if(resetCounters) {
            require(result.error=="C5 completion timeout" && !result.geometry.valid() &&
                    result.readersStopped,"reset tags bypassed fresh-bank fences");
        } else {
            require(result.tags[0]==10001 && result.tags[1]==10002 &&
                    result.geometry.generation==2,"monotonic high-counter publication failed");
        }
        require(original.generation==1 && original.pixelBytes==614400,"counter case changed committed input");
    }
    std::cout << "C5_RUNTIME_SELFTEST_PASS\n";
    return 0;
    } catch(const std::exception& error) {
        std::cerr << "C5_RUNTIME_SELFTEST_FAIL: " << error.what() << '\n';return 1;
    }
}
} // namespace c5_test
