#include "cam1_runtime.h"
#include "cam1_runtime_safety.h"
#include "camera_dma.h"
#include <algorithm>
#include <array>
#include <cstdio>
#include <memory>
#include <stdexcept>

namespace {
void check(bool ok,const char* text) { if(!ok) throw std::runtime_error(text); }
const std::vector<uint16_t> clocks={0x3034,0x3035,0x3036,0x3037,0x3108,0x3820,0x3821,0x3824,0x460c,0x4300,0x501f,0x5001};
const std::vector<uint16_t> aec={0x3a08,0x3a09,0x3a0a,0x3a0b,0x3a0d,0x3a0e};
struct Board {
    uint32_t signature=0x43314d31,mode=0,mask=1,selector=4,status=0,data=0;
    int camera=0;
    uint32_t alias() const { return camera==0?0x20000800u:camera==2?0x20000900u:0x20000a00u; }
    uint32_t bit() const { return 1u<<camera; }
    cam1::Geometry transport() const { return mode || camera==0 ? cam1::geometry(mode) : cam1::Geometry{320,240}; }
    bool held=false,drained=false,freezeFail=false,idleFail=false,ignoreMask=false,ignoreMode=false;
    int ticks=0,commands=0,failRegister=-1,readMismatch=-1,completionDelay=0,pendingTicks=0;
    bool deferredLaunch=false,commandPending=false,retiring=false;
    uint32_t pendingCommand=0;
    int overlappingCommands=0,coalescedCommands=0;
    std::vector<uint32_t> submitted,launched,retired;
    sccb::Snapshot mailbox;
    int changeStage=0,changeAddress=0x3034,preservedReads=0;
    bool changeSecondClock=false,failPreservedRead=false,geometryWritten=false;
    int settleRemaining=0,settleTicks=0,settlePhases=0,prepared=0;
    std::vector<std::string> diagnostics;
    std::map<uint16_t,uint8_t> sensor,initial;
    std::vector<std::pair<uint32_t,uint32_t>> writes;
    std::array<uint64_t,6> offered{};
    Board() {
        for(auto r:cam1::hdRegisters()) sensor[r.first]=uint8_t(r.first*13+7);
        sensor[0x3808]=2;sensor[0x3809]=0x80;sensor[0x380a]=1;sensor[0x380b]=0xe0;
        sensor[0x380c]=7;sensor[0x380d]=0x68;sensor[0x3008]=2;
        for(uint16_t a:{0x3a08,0x3a0a}) {sensor[a]=1;sensor[a+1]=32;}
        sensor[0x3a0d]=3;sensor[0x3a0e]=4;
        for(auto a:clocks) sensor[a]=uint8_t(a*7);
        sensor[0x3034]=0x18;initial=sensor;
        sensor[0x300a]=0x56;sensor[0x300b]=0x40;initial=sensor;
    }
    void disturb() {
        sensor[changeAddress]^=2;
        if(changeSecondClock) sensor[0x3035]^=1;
        changeStage=0;
    }
    bool read(uint32_t a,uint32_t& v) {
        const uint32_t page=camera==0?0x20000c00u:camera==2?0x20000d00u:0x20000e00u;
        if(a>=page&&a<page+0x100) {v=mailbox.w[(a-page)/16];if(a==page)v=0x53430202u;return true;}
        if(a>=alias() && a<=alias()+0x70) a=0x20000800u+(a-alias());
        switch(a) {
        case 0x20000870:v=signature;break;
        case 0x400200b0:v=0;break;
        case 0x40020010:v=held&&!freezeFail?3:0;break;
        case 0x400200c0:v=selector;break;
        case 0x20000880:v=mask;break;
        case 0x20000890:v=!idleFail?(0x3f^mask):0;drained=(v&bit())!=0;break;
        case 0x20000830:v=pendingTicks?0:status;break;
        case 0x20000820:v=data;break;
        case 0x20000800:v=mode;break;
        case 0x20000840:{auto g=transport();v=g.width<<16|g.height;break;}
        case 0x20000850:v=transport().bytes();break;
        case 0x20000860:v=transport().stride();break;
        default:return false;
        }
        return true;
    }
    void executeCommand(uint32_t v) {
        launched.push_back(v);
        const uint16_t addr=uint16_t(v>>8);status=2;pendingTicks=completionDelay;
        if(v&(1u<<24)) {
            if(addr==0x3034 && ++preservedReads==2 && changeStage==1) disturb();
            data=sensor[addr];
            if(addr==0x3034&&geometryWritten&&failPreservedRead) status=3;
            if(addr==readMismatch&&geometryWritten) {data^=1;readMismatch=-1;}
        } else {
            check(addr!=0x3008,"any sensor power/standby/resume/reset write forbidden");
            check(std::find(clocks.begin(),clocks.end(),addr)==clocks.end(),"all clock/format writes forbidden");
            const auto table=cam1::hdRegisters();
            check(std::any_of(table.begin(),table.end(),[&](const std::pair<uint16_t,uint8_t>& r){return r.first==addr;})||
                std::find(aec.begin(),aec.end(),addr)!=aec.end(),"only geometry/AEC may be written");
            geometryWritten=true;
            if(addr==failRegister) {status=3;failRegister=-1;} // A real NACK; rollback then ACKs.
            else sensor[addr]=uint8_t(v);
            if(changeStage==2&&addr==0x3808) disturb();
        }
        auto& w=mailbox.w;
        ++w[1];++w[2];w[3]=v;w[4]=w[2];w[5]=v;w[6]=v;++w[7];
        const bool reading=(v&(1u<<24))!=0;
        // Writes retain the engine's prior read latch, as FPGA173752 does.
        w[8]=uint8_t(data)|(status&1?256u|(1u<<17):0u)|(reading?(8u<<9)|(1u<<21):0u);
        w[11]=0;
        if(reading) for(unsigned n=0;n<8;++n) w[11]|=((data>>(7-n))&1u)<<(n+1);
        w[13]=uint32_t(ticks*1000);w[15]=w[13]+1;w[14]=w[15]+100;
    }
    void tick() {
        ++ticks;
        for(int c=0;c<6;++c) if(mask & (1u<<c)) ++offered[c];
        if(settleRemaining) {
            check(held&&drained&&!(mask&bit()),"settle must hold target lease and producer/DMA drained");
            ++settleTicks;
            if(--settleRemaining==0&&changeStage==3) disturb();
        }
        if(pendingTicks) --pendingTicks;
        if(retiring&&!pendingTicks) {retired.push_back(launched.back());retiring=false;}
        if(commandPending) {executeCommand(pendingCommand);commandPending=false;retiring=true;}
    }
    bool write(uint32_t a,uint32_t v) {
        writes.push_back({a,v});
        if(a>=alias() && a<=alias()+0x70) a=0x20000800u+(a-alias());
        if(a==0x400200c0) selector=v;
        else if(a==0x40020020) {
            check(selector==uint32_t(camera)||!v,"wrong lease camera");
            check(v||settleRemaining==0,"lease release before settle completed");held=v!=0;
        } else if(a==0x20000880) {
            check(!(v&bit())||settleRemaining==0,"producer admission before settle completed");
            if(!ignoreMask) mask=v;
        } else if(a==0x20000800) {
            check(held&&drained&&!(mask&bit()),"mode changed before freeze/drain");if(!ignoreMode)mode=v;
        } else if(a==0x20000810) {
            check(held&&drained&&!(mask&bit()),"SCCB before freeze/drain");
            check(settleRemaining==0,"settle must contain 100 consecutive ticks without SCCB");
            ++commands;submitted.push_back(v);
            if(deferredLaunch) {
                if(commandPending) ++coalescedCommands;
                if(retiring) ++overlappingCommands;
                pendingCommand=v;commandPending=true;
            } else executeCommand(v);
        } else return false;
        return true;
    }
    cam1::Io io() {return {[this](uint32_t a,uint32_t& v){return read(a,v);},
        [this](uint32_t a,uint32_t v){return write(a,v);},[this]{tick();},
        [this](bool){check(held&&drained&&!(mask&bit())&&settleRemaining==0&&settleTicks>=100,"tag baseline before held settle");++prepared;return true;},
        [this](const std::string& text){
            diagnostics.push_back(text);
            if(text.find("live settle ticks=100")==0) {
                check(held&&drained&&!(mask&bit())&&geometryWritten,"settle starts under hold after live geometry writes");
                settleRemaining=100;++settlePhases;
            }
        }};}
    int sensorWrites() const {
        return int(std::count_if(submitted.begin(),submitted.end(),[](uint32_t c){return !(c&(1u<<24));}));
    }
};
}
int runCam1RuntimeSelfTest() {
    try {
        check(cam1::geometry(true).bytes()==1843200&&cam1::geometry(true).stride()==2560,"720 geometry");
        check(!cam1::freshTargetSequence(500,100,500),"new tag offset stale DDR cannot masquerade as fresh sequence");
        check(!cam1::freshTargetSequence(99,100,0) && !cam1::freshTargetSequence(100,100,0),"older/equal previous geometry sequence rejected");
        check(cam1::freshTargetSequence(101,100,500) && cam1::freshTargetSequence(0,0xffffffffu,500),"fresh sequence and uint32 wrap accepted");
        check(cam1::maxHostBytes==1843216&&cam1::maxHostBytes<tdm::cameraScratchOffset,"exclusive RX/scratch");
        std::vector<uint8_t> rx(tdm::cameraAllocationBytes,0xa7),pixels(1843200);
        std::fill_n(rx.data(),pixels.size(),0x51);tdm::copyCameraPixels(pixels.data(),rx.data(),pixels.size());
        check(pixels.front()==0x51&&pixels.back()==0x51&&rx[tdm::cameraScratchOffset]==0xa7,"720 copy bounds");
        std::string error;
        for(int fault=0;fault<10;++fault) {
            Board b;auto transport=b.io();transport.completionWitness=true;
            unsigned witnesses=0;
            transport.read=[&](uint32_t a,uint32_t& v){
                if(a>=b.alias()+0xa0&&a<=b.alias()+0xf0) {
                    ++witnesses;const unsigned index=(a-b.alias()-0xa0)/16;
                    const uint32_t id=b.mailbox.w[2];
                    const uint32_t words[]={b.data,id,b.data|0x800u,id,b.data,id};v=words[index];
                    if(fault>=1&&fault<=6&&index==unsigned(fault-1))v^=1;
                    if(fault==7&&index==2)v|=0x200;
                    if(fault==8&&index==2)v&=~0x800u;
                    return !(fault==9&&index==1);
                }
                return b.read(a,v);
            };
            cam1::Switch runtime(transport);uint8_t output[4]={};
            const bool ok=runtime.readStartupGeometry(output,error);
            check(ok==(fault==0),"completion witness gate");
            check(witnesses==(fault==0?30u:6u),"collect every witness before return");
            if(fault) {
                check(b.commands==1,"witness failure prevents next command");
                check(!runtime.readStartupGeometry(output,error)&&b.commands==1,"witness failure remains sticky");
            }
        }
        std::puts("SCCB_COMPLETION_SELFTEST_PASS: collection, identity, valid/fault, byte and transport failures block commands");
        // Correlation failures must stop before table writes and remain sticky.
        for(unsigned field:{1u,2u,3u,4u,5u,6u,7u,8u,11u,15u}) {
            Board fault;auto io=fault.io();
            io.read=[&](uint32_t a,uint32_t& v){
                const bool ok=fault.read(a,v);
                if(fault.commands&&a==0x20000c00u+16*field) v^=field==8?0x80000000u:field==11?2u:1u;
                return ok;
            };
            cam1::Switch s(io);
            check(!s.apply(true,false,error)&&fault.held&&fault.mask==0&&fault.sensorWrites()==0,"correlation fault fails closed before writes");
            const int commands=fault.commands;
            check(!s.apply(true,false,error)&&fault.commands==commands,"correlation failure blocks subsequent commands");
        }
        {
            Board fault;auto io=fault.io();
            io.read=[&](uint32_t a,uint32_t& v){const bool ok=fault.read(a,v);if(a==fault.alias()+0x20)v^=0x10;return ok;};
            cam1::Switch s(io);
            check(!s.apply(true,false,error)&&fault.sensorWrites()==0&&fault.held,"functional byte mismatch fails closed");
        }
        std::puts("SCCB_CERTIFICATE_SELFTEST_PASS: stale identity, payload/take/load/completion, overflow, phase/data and mailbox generation faults fail closed and block commands");
        {
            Board fault;auto io=fault.io();int generations=0;
            io.read=[&](uint32_t a,uint32_t& v){const bool ok=fault.read(a,v);if(a==0x20000c10u&&++generations==2)++v;return ok;};
            cam1::Switch s(io);
            check(!s.apply(true,false,error)&&fault.commands==0&&fault.held,"torn generation rejects before submission");
        }
        {
            Board fault;auto io=fault.io();int powerReads=0;
            io.write=[&](uint32_t a,uint32_t v){
                if(a==fault.alias()+0x10&&v==0x01300800u&&++powerReads==2)fault.sensor[0x3008]^=0x10;
                return fault.write(a,v);
            };
            cam1::Switch s(io);
            check(!s.apply(true,false,error)&&fault.sensorWrites()==0&&fault.held&&fault.mask==0&&
                error.find("Independent initial power snapshot disagreement")!=std::string::npos,"full byte bit4 initial disagreement never masked/retried");
        }
        for(int camera:{0,2,3}) for(uint32_t mask:{0x3fu,0x30u,1u<<camera}) {
            Board startup;startup.camera=camera;startup.mask=mask;
            startup.selector=mask==0x30u?5u:4u;
            const uint32_t priorSelector=startup.selector;
            startup.signature=camera==0?0x43314d31u:camera==2?0x43334d31u:0x43344d31u;
            startup.deferredLaunch=true;startup.status=2;startup.data=0xa5;
            cam1::Switch s(startup.io(),camera);uint8_t output[4]={};
            check(s.readStartupGeometry(output,error),"startup guarded readback");
            startup.tick();
            check(output[0]==2&&output[1]==0x80&&output[2]==1&&output[3]==0xe0,"startup physical dimensions");
            check(startup.mask==mask&&startup.selector==priorSelector&&!startup.held,"startup restores prior view and selector");
            check(startup.sensor==startup.initial&&!startup.geometryWritten&&startup.sensorWrites()==0&&!s.hasOriginals(),"startup writes no sensor or geometry and creates no restore snapshot");
            check(startup.commands==5&&startup.submitted==startup.launched&&startup.launched==startup.retired&&
                !startup.coalescedCommands&&!startup.overlappingCommands,"startup serial guards defeat stale done");
            for(auto w:startup.writes) {
                if(w.first==0x20000880) check((w.second&~startup.bit())==(mask&~startup.bit()),"startup preserves other producers");
                if(w.first==startup.alias()+0x10) check(w.second&(1u<<24),"startup SCCB read commands only");
                check(w.first!=startup.alias(),"startup never writes runtime mode");
            }
            for(int i=0;i<4;++i) check(startup.submitted[i+1]==((1u<<24)|((0x3808u+i)<<8)),"startup true read command registers3808..b");
        }
        for(int fault=0;fault<5;++fault) {
            Board startup;
            auto io=startup.io();
            if(fault==0) startup.sensor[0x3809]=0x81;
            if(fault==1) startup.sensor[0x3008]=0x42;
            if(fault==2) io.read=[&](uint32_t a,uint32_t& v){const bool ok=startup.read(a,v);if(a==startup.alias()+0x30)v=3;return ok;};
            if(fault==3) io.read=[&](uint32_t a,uint32_t& v){return a!=startup.alias()+0x20&&startup.read(a,v);};
            if(fault==4) io.read=[&](uint32_t a,uint32_t& v){const bool ok=startup.read(a,v);if(a==startup.alias()+0x30)v=0;return ok;};
            cam1::Switch s(io);uint8_t output[4]={};
            check(!s.readStartupGeometry(output,error)&&startup.held&&startup.mask==0,"startup mismatch/NACK/data failure/timeout retains hold");
            if(fault==0) check(output[1]==0x81,"startup reports actual mismatched bytes rather than requested VGA constants");
            check(startup.sensorWrites()==0&&!startup.geometryWritten,"startup failure never repairs sensor geometry");
            check(error.find("external recovery required")!=std::string::npos,"startup failure requires external recovery");
            for(auto w:startup.writes) check(w.first!=0x40020020||w.second!=0,"startup failure never releases before validation");
        }
        // Fail every MMIO operation once, including mask and lease restoration.
        // Recovery may only re-establish the hold; it never retries sensor writes.
        Board startupReference;int startupOperations=0;
        auto referenceIo=startupReference.io();
        referenceIo.read=[&](uint32_t a,uint32_t& v){++startupOperations;return startupReference.read(a,v);};
        referenceIo.write=[&](uint32_t a,uint32_t v){++startupOperations;return startupReference.write(a,v);};
        cam1::Switch reference(referenceIo);uint8_t referenceOutput[4]={};
        check(reference.readStartupGeometry(referenceOutput,error),"startup fault reference");
        for(int failure=1;failure<=startupOperations;++failure) {
            Board startup;int operation=0;bool attemptedLease=false;
            auto io=startup.io();
            io.read=[&](uint32_t a,uint32_t& v){return ++operation!=failure&&startup.read(a,v);};
            io.write=[&](uint32_t a,uint32_t v){if(a==0x40020020&&v)attemptedLease=true;return ++operation!=failure&&startup.write(a,v);};
            cam1::Switch s(io);uint8_t output[4]={};
            check(!s.readStartupGeometry(output,error),"startup rejects each MMIO failure");
            if(attemptedLease) check(startup.held&&startup.mask==0,"startup MMIO failure re-establishes hold");
            check(startup.sensorWrites()==0&&!startup.geometryWritten,"startup MMIO failure writes no geometry");
        }
        std::printf("CAM134_STARTUP_SENSOR_SELFTEST_PASS: C1/C3/C4 aliases, true reads, prior masks, serialized stale-done guards, mismatch/NACK/timeout and %d MMIO failure points; no geometry writes\n",startupOperations);
        for(int camera:{0,2,3}) for(uint32_t mask:{0x3fu,0x30u,1u<<camera}) {
            Board target;target.camera=camera;target.mask=mask;
            target.signature=camera==0?0x43314d31u:camera==2?0x43334d31u:0x43344d31u;
            target.sensor[0x380c]=uint8_t(7+camera);target.initial=target.sensor;
            cam1::Switch controller(target.io(),camera);
            check(controller.apply(true,false,error),"targeted HD apply");
            check(target.mask==mask && target.selector==4 && !target.held,"restore original view mask");
            check(target.transport().bytes()==1843200,"target HD metadata");
            const uint32_t ownHts=uint32_t(target.initial.at(0x380c))*256+target.initial.at(0x380d);
            for(uint16_t a:{0x3a08,0x3a0a}) {
                const uint32_t ownStep=uint32_t(target.initial.at(a))*256+target.initial.at(a+1);
                const uint32_t expected=(ownStep*ownHts+cam1::hdHts/2)/cam1::hdHts;
                check((uint32_t(target.sensor.at(a))*256+target.sensor.at(a+1))==expected,"AEC uses this sensor's original HTS and step");
                check(target.sensor.at(a==0x3a08?0x3a0e:0x3a0d)==cam1::hdVts/expected,"own AEC bank limit follows HD VTS");
            }
            for(auto w:target.writes) if(w.first==0x20000880)
                check((w.second & ~target.bit())==(mask & ~target.bit()),"other five mask bits preserved");
            for(int c=0;c<6;++c) if(c!=camera && (mask & (1u<<c)))
                check(target.offered[c]>100,"other admitted producers advance during target held settle");
            for(auto w:target.writes) {
                if(w.first>=0x20000800u && w.first<=0x20000a70u && w.first!=0x20000880u)
                    check(w.first==target.alias() || w.first==target.alias()+0x10,"only selected mode/SCCB aliases written");
                if(w.first==0x400200c0u) check(w.second==uint32_t(camera) || w.second==4,"selected lease and neutral selector only");
            }
            check(std::any_of(target.writes.begin(),target.writes.end(),[&](std::pair<uint32_t,uint32_t> w){return w.first==target.alias()+0x10;}),"own SCCB alias");
            check(controller.apply(false,true,error) && target.sensor==target.initial && target.mask==mask,"own exact VGA/AEC restore");
            check(target.transport().bytes()==(camera==0?614400u:153600u),"compressed default metadata with VGA sensor");
            target.failRegister=0x3808;
            const auto priorOffered=target.offered;
            check(!controller.apply(true,false,error) && target.held && target.mask==(mask & ~target.bit()) && target.sensor==target.initial,"target NACK held rollback preserves other producers");
            for(int c=0;c<6;++c) if(c!=camera && (mask & (1u<<c)))
                check(target.offered[c]>priorOffered[c],"other producers advance through failed switch and held rollback");
        }
        std::puts("CAM134_RUNTIME_TARGET_SELFTEST_PASS: aliases C1/C3/C4, selected leases, prior masks, HD/compressed metadata, per-target AEC and NACK rollback");
        for(unsigned modes=0;modes<8;++modes) {
            std::array<Board,3> targets;
            std::array<std::unique_ptr<cam1::Switch>,3> controllers;
            uint32_t sharedMask=0x3f;
            const int cameras[]={0,2,3};
            for(int i=0;i<3;++i) {
                targets[i].camera=cameras[i];targets[i].mask=sharedMask;
                targets[i].signature=i==0?0x43314d31u:i==1?0x43334d31u:0x43344d31u;
                targets[i].sensor[0x380c]=uint8_t(7+i);
                targets[i].sensor[0x3035]=uint8_t(0x20+i);
                targets[i].initial=targets[i].sensor;
                auto io=targets[i].io();
                io.read=[&,i](uint32_t a,uint32_t& value) {targets[i].mask=sharedMask;return targets[i].read(a,value);};
                io.write=[&,i](uint32_t a,uint32_t value) {
                    targets[i].mask=sharedMask;
                    const bool ok=targets[i].write(a,value);sharedMask=targets[i].mask;return ok;
                };
                controllers[i].reset(new cam1::Switch(io,cameras[i]));
            }
            for(int i=0;i<3;++i) if(modes & (1u<<i)) {
                check(controllers[i]->apply(true,false,error),"mode matrix targeted apply on shared mask");
                check(sharedMask==0x3f,"mode matrix never replaces overview with exclusive HD mask");
                for(int j=0;j<3;++j) if(j!=i) {
                    const unsigned earlier=modes & ((1u<<i)-1);
                    check(targets[j].mode==unsigned((earlier & (1u<<j))!=0),"target apply preserves every other mode");
                }
            }
            for(int i=0;i<3;++i) {
                check(targets[i].mode==unsigned((modes & (1u<<i))!=0),"all eight independent mode combinations");
                if(modes & (1u<<i)) check(controllers[i]->apply(false,true,error),"mode matrix exact restore");
                check(targets[i].sensor==targets[i].initial && sharedMask==0x3f,"mode matrix separate originals and preserved clock bytes");
            }
        }
        std::puts("CAM134_RUNTIME_MATRIX_SELFTEST_PASS: eight combinations on a shared producer mask, independent sensors/modes/originals and exact restores");
        Board physical;
        physical.sensor[0x3a08]=1;physical.sensor[0x3a09]=0x27;
        physical.sensor[0x3a0a]=0;physical.sensor[0x3a0b]=0xf6;
        physical.initial=physical.sensor;
        cam1::Switch physicalSwitch(physical.io());
        check(physicalSwitch.apply(true,false,error),"physical VGA profile to HD");
        check(physical.sensor[0x380c]==0x0e && physical.sensor[0x380d]==0xc8,"board-proven HD line length");
        check(physical.sensor[0x3a08]==0 && physical.sensor[0x3a09]==148 &&
              physical.sensor[0x3a0a]==0 && physical.sensor[0x3a0b]==123 &&
              physical.sensor[0x3a0e]==5 && physical.sensor[0x3a0d]==6,"physical profile antibanding line counts");
        check(physicalSwitch.apply(false,true,error) && physical.sensor==physical.initial,"physical profile exact VGA restore");
        Board posted;posted.deferredLaunch=true;posted.status=2;posted.data=0xa5;
        posted.held=posted.drained=true;posted.mask=0;
        const uint32_t first=(0x3808u<<8)|5,second=(0x380bu<<8)|0xd0;
        check(posted.write(0x20000810,first),"post first");uint32_t stale=0;
        check(posted.read(0x20000830,stale)&&stale==2&&posted.data==0xa5&&posted.launched.empty(),"old done visible before launch");
        check(posted.write(0x20000810,second),"post second");posted.tick();
        check(posted.coalescedCommands==1&&posted.launched==std::vector<uint32_t>{second}&&posted.sensor[0x3808]==posted.initial[0x3808],"unguarded payload loss reproduced");
        Board guarded;guarded.deferredLaunch=true;guarded.status=2;cam1::Switch sw(guarded.io());
        for(int round=0;round<3;++round) {
            check(sw.apply(true,false,error),"live HD entry");
            check(guarded.mode==1&&guarded.mask==1&&!guarded.held&&guarded.sensor[0x3008]==2,"HD restart with streaming sensor unchanged");
            check(guarded.sensor[0x3808]==5&&guarded.sensor[0x380b]==0xd0&&guarded.sensor[0x3803]==0xfa&&guarded.sensor[0x3807]==0xa9,"real crop/output");
            for(auto a:aec) guarded.sensor[a]^=0x5a; // Returning to VGA must restore all six exact baseline bytes.
            check(sw.apply(false,true,error),"live VGA return");
            check(guarded.sensor==guarded.initial&&guarded.mask==1&&guarded.mode==0&&!guarded.held,"all geometry/AEC exact VGA restore");
        }
        guarded.tick();
        check(!guarded.commandPending&&!guarded.retiring&&!guarded.coalescedCommands&&!guarded.overlappingCommands&&
            guarded.submitted==guarded.launched&&guarded.launched==guarded.retired,"guards launch/retire every command exactly once in order");
        check(guarded.settlePhases==6&&guarded.settleTicks==600&&guarded.prepared==6,"every transition settles 100 consecutive held ticks before tag snapshot");
        std::puts("CAM1_RUNTIME_SERIAL_GUARD_SELFTEST_PASS: stale done and fast payload loss reproduced; guarded live commands exactly once");
        for(uint8_t power:{uint8_t(0x42),uint8_t(0x82),uint8_t(0xc2)}) {
            Board inactive;inactive.sensor[0x3008]=power;cam1::Switch s(inactive.io());
            check(!s.apply(true,false,error)&&inactive.held&&inactive.mask==0&&inactive.sensorWrites()==0,"inactive sensor fails held before any sensor writes");
        }
        Board delayed;delayed.completionDelay=3;cam1::Switch ds(delayed.io());
        check(ds.apply(true,false,error),"delayed SCCB ACK accepted");
        check(std::any_of(delayed.diagnostics.begin(),delayed.diagnostics.end(),[](const std::string& s){return s.find("busy-seen=1 polls=2")!=std::string::npos;}),"busy completion diagnostic");
        auto changed=cam1::hdRegisters();for(auto a:aec) changed.push_back({a,0});
        for(auto r:changed) {
            Board f;f.deferredLaunch=true;f.failRegister=r.first;cam1::Switch s(f.io());
            check(!s.apply(true,false,error)&&f.held&&f.mask==0&&f.mode==0&&f.sensor==f.initial,"NACK exact held rollback at every changed register");
            check(error.find("result=nack")!=std::string::npos,"primary NACK retained after successful rollback");
        }
        Board mismatch;mismatch.readMismatch=0x3808;cam1::Switch ms(mismatch.io());
        check(!ms.apply(true,false,error)&&mismatch.sensor==mismatch.initial&&mismatch.held&&mismatch.mask==0&&error.find("verify mismatch")!=std::string::npos,"ACK alone cannot satisfy exact readback");
        for(int stage:{1,2,3}) {
            Board f;f.changeStage=stage;f.changeSecondClock=true;cam1::Switch s(f.io());
            check(!s.apply(true,false,error)&&f.held&&f.mask==0&&f.mode==0,"clock difference remains held");
            const std::string phase=stage==1?"pre-table":stage==2?"post-table":"post-settle";
            check(error.find("stage="+phase+" sensor=0x3034 expected=0x18 actual=0x1a")!=std::string::npos,"exact full byte primary clock diagnostic");
            check(std::any_of(f.diagnostics.begin(),f.diagnostics.end(),[&](const std::string& s){return s.find("stage="+phase+" sensor=0x3035")!=std::string::npos&&s.find("result=mismatch")!=std::string::npos;}),"scan records multiple differences");
            if(stage==1) check(f.sensorWrites()==0,"pre-table difference prevents geometry writes");
            else check(error.find("rollback unverified")!=std::string::npos&&f.sensor[0x3808]==f.initial[0x3808],"persistent clock diff cannot mask exact geometry rollback failure");
            check(!s.rollbackSafe()&&f.held&&f.mask==0,"explicit rollback cannot claim clock repaired");
        }
        for(auto addr:clocks) {
            Board f;f.changeStage=2;f.changeAddress=addr;cam1::Switch s(f.io());
            check(!s.apply(true,false,error)&&error.find("rollback unverified")!=std::string::npos&&f.held&&f.mask==0,"each of 12 full-byte preserved values checked");
        }
        Board powerDiff;powerDiff.changeStage=3;powerDiff.changeAddress=0x3008;cam1::Switch ps(powerDiff.io());
        check(!ps.apply(true,false,error)&&powerDiff.held&&powerDiff.mask==0&&error.find("sensor=0x3008 expected=0x02 actual=0x00")!=std::string::npos&&error.find("rollback unverified")!=std::string::npos,"power snapshot preserved exactly, never repaired by write");
        Board geometryDrift;geometryDrift.changeStage=3;geometryDrift.changeAddress=0x3808;cam1::Switch gs(geometryDrift.io());
        check(!gs.apply(true,false,error)&&geometryDrift.held&&geometryDrift.mask==0&&geometryDrift.prepared==0&&error.find("Settled sensor output mismatch")!=std::string::npos,"output geometry re-read after settling before publication snapshot");
        Board readFail;readFail.failPreservedRead=true;cam1::Switch rs(readFail.io());
        check(!rs.apply(true,false,error)&&error.find("stage=post-table sensor=0x3034")!=std::string::npos&&error.find("read-ok=0")!=std::string::npos&&readFail.held&&readFail.mask==0,"preserved read transport failure retains primary stage");
        std::puts("CAM1_RUNTIME_LIVE_HELD_SELFTEST_PASS: no power/clock/format writes; active gate; exact ACK/readback; 100 held settle ticks; all six AEC bytes restored; full 12-byte clock and power checks");
        std::puts("CAM1_RUNTIME_PRESERVED_SELFTEST_PASS: every preserved byte and power control checked; persistent drift fails held rollback");
        Board old;old.signature=0;cam1::Switch os(old.io());check(!os.apply(true,false,error)&&old.writes.empty(),"old signature no writes");
        Board frozen;frozen.freezeFail=true;cam1::Switch fs(frozen.io());check(!fs.apply(true,false,error)&&frozen.commands==0,"freeze timeout prevents SCCB");
        Board idle;idle.idleFail=true;cam1::Switch is(idle.io());check(!is.apply(true,false,error)&&idle.commands==0&&idle.mask==0,"drain timeout holds");
        Board ignored;ignored.ignoreMask=true;cam1::Switch ims(ignored.io());check(!ims.apply(true,false,error)&&ignored.commands==0,"ignored mask detected");
        Board wrong;wrong.ignoreMode=true;cam1::Switch ws(wrong.io());check(!ws.apply(true,false,error)&&wrong.held&&wrong.mask==0&&wrong.sensor==wrong.initial,"metadata failure exact rollback");
        Board prepare;auto io=prepare.io();io.prepare=[](bool){return false;};cam1::Switch prep(io);
        check(!prep.apply(true,false,error)&&prepare.sensor==prepare.initial&&prepare.held&&prepare.mask==0&&error.find("result=nack")==std::string::npos,"publication snapshot failure has no stale SCCB failure");
        for(bool prior:{false,true}) {
            Board p;cam1::Switch s(p.io());if(prior) check(s.apply(true,false,error),"prior HD setup");
            const auto priorSensor=p.sensor;
            p.failRegister=0x3808;
            check(!s.apply(!prior,prior,error)&&p.sensor==priorSensor&&p.mode==uint32_t(prior)&&p.held&&p.mask==0,"failed return restores exact prior geometry");
        }
        for(bool prior:{false,true}) {
            Board p;cam1::Switch s(p.io());if(prior) check(s.apply(true,false,error),"publication prior HD setup");
            const auto priorSensor=p.sensor;check(s.apply(!prior,prior,error),"publication target configuration");
            const bool verified=s.rollbackSafe();
            check(verified&&cam1::modeAfterRollback(prior,!prior,verified)==prior&&p.mode==uint32_t(prior)&&p.sensor==priorSensor&&p.mask==0&&p.held,"publication failure exact hardware/software rollback");
        }
        Board watchdog;cam1::Switch w(watchdog.io());check(w.apply(true,false,error),"watchdog HD setup");const auto hd=watchdog.sensor;
        check(cam1::watchdogAction(false,false,false,true,60000,60000)==cam1::WatchdogAction::HoldRuntime&&w.holdSafe()&&watchdog.sensor==hd&&watchdog.mode==1&&watchdog.held&&watchdog.mask==0,"watchdog holds streaming HD without reconfiguration");
        check(cam1::watchdogAction(false,false,true,true,120000,60000)==cam1::WatchdogAction::Wait&&cam1::watchdogAction(false,true,false,true,60000,60000)==cam1::WatchdogAction::Wait,"held/switching watchdog stays in process");
        check(cam1::watchdogAction(false,false,false,false,60000,60000)==cam1::WatchdogAction::RestartProcess,"legacy VGA recovery");
        Board uncertain;cam1::Switch u(uncertain.io());check(u.apply(true,false,error),"uncertain HD setup");uncertain.freezeFail=true;
        const bool verified=u.rollbackSafe();check(!verified&&cam1::modeAfterRollback(false,true,verified)&&uncertain.mode==1&&uncertain.mask==0,"unverified rollback cannot report VGA");
        std::puts("CAM1_RUNTIME_FAILURE_SELFTEST_PASS: held rollback in both directions; publication failures; watchdog; uncertain rollback");
        std::puts("CAM1_RUNTIME_SELFTEST_PASS: live geometry, exact VGA baseline, exclusive RX, serial guards, held settle and failure safety");
        return 0;
    } catch(const std::exception& e) {std::fprintf(stderr,"CAM1_RUNTIME_SELFTEST_FAIL: %s\n",e.what());return 1;}
}
#ifdef CAM1_RUNTIME_TEST_MAIN
int main() {return runCam1RuntimeSelfTest();}
#endif
