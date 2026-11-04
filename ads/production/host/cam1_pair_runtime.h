#pragma once
#include <cstdint>
#include <cstdio>
#include <functional>
#include <map>
#include <mutex>
#include <string>
#include <vector>
#include "sccb_certificate.h"
#include "sccb_completion_witness.h"
#include "runtime_camera_geometry.h"

// Separately audited pair-recovery revision; cam1_runtime.h stays immutable.
namespace cam1_pair {
using Mode = runtime_camera::Mode;
inline bool sensorHd(Mode mode) { return mode==Mode::Hd720; }
inline const char* modeName(Mode mode) {
    return mode==Mode::Default?"A":mode==Mode::FullVga?"B":"C";
}
struct Geometry {
    uint32_t width, height;
    uint32_t bytes() const { return width * height * 2; }
    uint32_t stride() const { return width * 2; }
};
inline Geometry geometry(bool hd) { return hd ? Geometry{1280,720} : Geometry{640,480}; }
inline Geometry geometry(Mode mode) { return geometry(sensorHd(mode)); }
constexpr uint32_t maxHostBytes = 1843216;
// DDR survives image changes: exclude the held value at the new tag offset,
// as well as sequences older than the previous geometry's committed floor.
inline bool freshTargetSequence(uint32_t sequence,uint32_t previous,uint32_t staleAtTargetOffset) {
    const uint32_t advance=sequence-previous;
    return advance>0 && advance<0x80000000u && sequence!=staleAtTargetOffset;
}
// Physical probe_20261011T191229Z: HTS1892 stalls raw VSYNC with the
// preserved 84 MHz/8-bit RGB565 DVP profile; HTS3784 restores 30 fps,
// 921600 offered pixels, zero CDC drops and alternating bank commits.
constexpr uint32_t hdHts = 3784;
// [VTS-MARGIN 2026-10-21] AEC maximum exposure is written below as 0x02e4=740
// (0x3a02/0x3a03 and 0x3a14/0x3a15), so VTS=740 left exactly zero vertical
// blanking at the frame end: the last active line lost its final DVP byte clock
// and 0x190 reported 921599 instead of 1280*720. VTS=741 puts the AEC maximum
// at VTS-1 and gives that line one whole line (3784 byte clocks) of margin.
constexpr uint32_t hdVts = 741;
// No PLL, PCLK divider, format, reset or byte-order registers are changed.
inline std::vector<std::pair<uint16_t,uint8_t>> hdRegisters() {
    return {{0x3800,0},{0x3801,0},{0x3802,0},{0x3803,0xfa},
        {0x3804,0x0a},{0x3805,0x3f},{0x3806,0x06},{0x3807,0xa9},
        {0x3808,5},{0x3809,0},{0x380a,2},{0x380b,0xd0},
        {0x380c,uint8_t(hdHts>>8)},{0x380d,uint8_t(hdHts)},
        {0x380e,uint8_t(hdVts>>8)},{0x380f,uint8_t(hdVts)},
        {0x3810,0},{0x3811,0x10},{0x3812,0},{0x3813,4},
        {0x3814,0x31},{0x3815,0x31},
        {0x3a02,2},{0x3a03,0xe4},{0x3a14,2},{0x3a15,0xe4}};
}
struct Io {
    std::function<bool(uint32_t,uint32_t&)> read;
    std::function<bool(uint32_t,uint32_t)> write;
    // Production tick has nominal duration 1 ms; SCCB guards and the 100 ms
    // live-configuration settle both use this same transport timing contract.
    std::function<void()> tick;
    std::function<bool(bool)> prepare;
    std::function<void(const std::string&)> diagnostic;
    bool completionWitness=false;
    // Explicit mode callback takes precedence. Legacy prepare is valid for A/C
    // only: passing B as false would snapshot the wrong DDR tag offset.
    std::function<bool(Mode)> prepareMode={};
    uint32_t transactionSeed=0; // Continue the same camera's startup audit sequence.
};
// Called with the target reader joined and analytics consumers drained.
// Each instance owns one sensor's originals; failure never restarts capture.
class Switch {
    Io io;
    int camera_=0;
    uint32_t base_=0x20000800, savedMask_=0x3f;
    Geometry transportGeometry(Mode mode) const {
        const auto g=runtime_camera::geometry(camera_,mode);
        return Geometry{g.width,g.height};
    }
    std::map<uint16_t,uint8_t> originals;
    std::map<uint16_t,uint8_t> rollbackSensor;
    std::map<uint16_t,uint8_t> rollbackPreserved;
    Mode rollbackMode=Mode::Default;
    bool rollbackSensorChanged=false;
    uint32_t transaction=0;
    sccb::Snapshot lastCertificate;
    bool certificateSeen=false,certificateFault=false;
    std::string lastFailure;
    void report(const std::string& text,bool failure=false) {
        if(failure) lastFailure=text;
        if(io.diagnostic) io.diagnostic(text);
        else { std::fprintf(stderr,"CAM1_RUNTIME %s\n",text.c_str()); std::fflush(stderr); }
    }
    bool poll(uint32_t addr, uint32_t mask, uint32_t expected) {
        uint32_t v=0;
        for (int i=0;i<3000;++i) {
            if (!io.read(addr,v)) {
                char text[192];std::snprintf(text,sizeof(text),"poll transport-read failed addr=0x%08x mask=0x%08x expected=0x%08x last=0x%08x polls=%d",addr,mask,expected,v,i);
                report(text,true);return false;
            }
            if ((v&mask)==expected) return true;
            io.tick();
        }
        char text[192];std::snprintf(text,sizeof(text),"poll timeout addr=0x%08x mask=0x%08x expected=0x%08x actual=0x%08x polls=3000",addr,mask,expected,v);
        report(text,true);return false;
    }
    bool writeChecked(uint32_t addr,uint32_t value) {
        uint32_t actual=0;
        const bool written=io.write(addr,value);
        const bool read=written&&io.read(addr,actual);
        if(written&&read&&actual==value) return true;
        char text[192];std::snprintf(text,sizeof(text),"MMIO verify failed addr=0x%08x expected=0x%08x actual=0x%08x write-ok=%d read-ok=%d",addr,value,actual,written,read);
        report(text,true);return false;
    }
    bool sensor(uint16_t addr, uint8_t& value, bool read) {
        // One owner across all cameras until certificate AND witnesses finish.
        static std::mutex ownership;
        std::lock_guard<std::mutex> operation(ownership);
        if(certificateFault) {report("SCCB blocked after correlation/transport failure; external recovery required",true);return false;}
        const uint32_t id=++transaction;
        const uint32_t command=(read?1u<<24:0u)|(uint32_t(addr)<<8)|value;
        uint32_t status=0,first=0,data=0;int polls=0;bool sawBusy=false;
        const char* result="ok";
        const uint32_t page=camera_==0?0x20000c00u:camera_==2?0x20000d00u:0x20000e00u;
        sccb::Snapshot before,after;std::string certificateError;
        auto logSnapshot=[&](const char* stage,const sccb::Snapshot& s) {
            char text[768];
            std::snprintf(text,sizeof(text),"SCCB_CERT tx=%u stage=%s requested=0x%08x page=0x%08x signature=%08x generation=%u accepted=%u accepted-payload=%08x taken=%u take-payload=%08x loaded=%08x completed=%u raw=%08x phase0=%08x phase1=%08x phase2=%08x phase3=%08x take-ticks=%u done-ticks=%u load-ticks=%u functional=%08x status=%08x",
                id,stage,command,page,s.w[0],s.w[1],s.w[2],s.w[3],s.w[4],s.w[5],s.w[6],s.w[7],s.w[8],s.w[9],s.w[10],s.w[11],s.w[12],s.w[13],s.w[14],s.w[15],data,status);
            report(text);
        };
        if(!sccb::snapshot(io.read,page,before,certificateError)||!sccb::quiescent(before)||
           (certificateSeen&&before.w!=lastCertificate.w)) {
            certificateFault=true;
            logSnapshot("before-rejected",before);
            report("SCCB certificate before submission failed: "+certificateError,true);return false;
        }
        logSnapshot("before",before);
        // The request crosses a slow SCCB clock as a toggle, with no queue or
        // command id. Drain the previous transfer and give the new command a
        // full 1 ms (runtime tick) before trusting its terminal status. Actual
        // SCCB transactions take ~0.16/0.20 ms; immediate done can be stale.
        io.tick();
         if(!io.write(base_+0x10,command)) result="command-write-failed";
        else {
            io.tick();
            for(;polls<3000;++polls) {
                if(!io.read(base_+0x30,status)) {result="status-read-failed";break;}
                if(polls==0) first=status;
                if(status&2) break;
                sawBusy=true;io.tick();
            }
            if(polls==3000) result="completion-timeout";
            if(result==std::string("ok")) {
                if(!io.read(base_+0x30,status)) result="final-status-read-failed";
                else if(status&1) result="nack";
                else {
                    if(!io.read(base_+0x20,data)) result="data-read-failed";
                     else if(read) value=uint8_t(data);
                }
            }
        }
        // Terminal status alone is not a completion certificate. Wait only for
        // passive publication within the original 3000-poll budget; never retry
        // a sensor command or accept a torn mailbox/contradictory byte.
        bool associatedNack=false;
        if(std::string(result)=="ok"||std::string(result)=="nack") {
            bool published=false;
            for(;polls<3000;++polls) {
                if(!sccb::snapshot(io.read,page,after,certificateError)) break;
                if(after.w[1]!=before.w[1]) {published=true;break;}
                if(after.w[2]!=before.w[2]&&after.w[2]!=before.w[2]+1u) {
                    certificateError="unexpected accepted sequence";break;
                }
                io.tick();
            }
            auto checked=after;
            const bool nack=std::string(result)=="nack";
            if(nack) {
                // A fresh, explicitly NACKed command may retain the existing
                // held geometry rollback behavior. Identity is still required.
                if(!io.read(base_+0x20,data)) published=false;
                associatedNack=(after.w[8]&256u)!=0;
                checked.w[8]&=~(256u|(15u<<17));
            }
            logSnapshot("after",after);
            if(!published||(nack&&!associatedNack)||!sccb::validate(before,checked,command,data,nack?2u:status,certificateError)) {
                result="certificate-failed";
                report("SCCB certificate failed: "+certificateError,true);
            }
        }
        if(io.completionWitness && !sccb::completionWitness(io.read,
            [&](const std::string& text){report(text);},base_,page,id,command,before,data,status)) {
            certificateFault=true;
            if(std::string(result)=="ok"||std::string(result)=="nack") result="witness-failed";
        }
        const bool ok=std::string(result)=="ok";
        if(ok||(std::string(result)=="nack"&&associatedNack)) {lastCertificate=after;certificateSeen=true;}
        else if(std::string(result)!="nack") certificateFault=true;
        char text[320];std::snprintf(text,sizeof(text),"SCCB tx=%u op=%s sensor=0x%04x command=0x%08x status-first=0x%08x status=0x%08x busy-seen=%d polls=%d data=0x%08x result=%s",id,read?"read":"write",addr,command,first,status,sawBusy,polls,data,result);
        if(ok) lastFailure.clear();
        report(text,!ok);return ok;
    }
    bool put(uint16_t addr,uint8_t value) {
        // Only geometry/AEC addresses from the explicit tables reach put().
        // Runtime sensor power, PLL, format and reset writes are forbidden.
        if(addr==0x3008) {report("Runtime sensor power write forbidden",true);return false;}
        if (!sensor(addr,value,false)) return false;
        uint8_t actual=0;
        if(!sensor(addr,actual,true)) return false;
        if(actual==value) return true;
        char text[192];std::snprintf(text,sizeof(text),"SCCB verify mismatch sensor=0x%04x expected=0x%02x actual=0x%02x tx=%u",addr,value,actual,transaction);
        report(text,true);return false;
    }
    bool metadata(Mode mode) {
        const auto g=transportGeometry(mode); uint32_t d=0,b=0,s=0,m=0;
        return io.read(base_,m) && m==uint32_t(mode) &&
            io.read(base_+0x40,d) && d==(g.width<<16|g.height) &&
            io.read(base_+0x50,b) && b==g.bytes() &&
            io.read(base_+0x60,s) && s==g.stride();
    }
    bool verifyPreserved(const std::map<uint16_t,uint8_t>& baseline,const char* stage) {
        std::string firstFailure;
        for(auto r:baseline) {
            uint8_t actual=0;
            const bool read=sensor(r.first,actual,true);
            char text[256];
            std::snprintf(text,sizeof(text),"preserved stage=%s sensor=0x%04x expected=0x%02x actual=0x%02x read-ok=%d tx=%u result=%s",
                stage,r.first,r.second,actual,read,transaction,!read?"read-failed":actual==r.second?"ok":"mismatch");
            const std::string detail=std::string(text)+(read?"":" transport=["+lastFailure+"]");
            report(detail);
            if((!read || actual!=r.second) && firstFailure.empty()) firstFailure=detail;
        }
        // Read the whole set so the log distinguishes a lone divider difference
        // from a wider reset. Successful later reads must not hide the first diff.
        if(!firstFailure.empty()) {report(firstFailure,true);return false;}
        return true;
    }
    void settleLive() {
        report("live settle ticks=100 nominal-ms=100 capture=held target-producer=disabled");
        for(int i=0;i<100;++i) io.tick();
    }
    bool restoreHeld(const std::map<uint16_t,uint8_t>& snapshot,
                     const std::map<uint16_t,uint8_t>& preserved,Mode mode,bool sensorChanged) {
        // Record any existing drift, but still attempt every geometry/AEC
        // restore. Never repair preserved registers with runtime writes.
        bool ok=verifyPreserved(preserved,"rollback-pre-table");
        if(sensorChanged) for(auto r:snapshot) ok=put(r.first,r.second)&&ok;
        ok=io.write(base_,uint32_t(mode))&&metadata(mode)&&ok;
        ok=verifyPreserved(preserved,"rollback-table")&&ok;
        settleLive();
        ok=verifyPreserved(preserved,"rollback-settle")&&ok;
        return ok;
    }
public:
    explicit Switch(Io transport,int camera=0):io(transport),camera_(camera),
        base_(camera==0?0x20000800u:camera==2?0x20000900u:0x20000a00u),transaction(transport.transactionSeed) {}
    // Proposed v2 capability: C3/C4 signatures end in '2'. C1 remains v1
    // and never admits wire mode 2. Both endpoints are admitted before writes.
    bool supported(Mode mode) {
        if(!runtime_camera::supportsMode(camera_,mode) ||
           !(camera_==0 || camera_==2 || camera_==3)) return false;
        uint32_t v=0;
        if(!io.read(base_+0x70,v)) return false;
        const uint32_t v1=camera_==0?0x43314d31u:camera_==2?0x43334d31u:0x43344d31u;
        const bool v2=camera_!=0 && v==v1+1u;
        return mode==Mode::FullVga?v2:(v==v1 || v2);
    }
    bool supported() { return supported(Mode::Default); }
    uint32_t base() const { return base_; }
    bool hasOriginals() const { return !originals.empty(); }
    // Startup only: no readers/analytics have launched. Read the physical VGA
    // output under the same lease/drain/SCCB guards as a mode transition, with
    // no sensor or runtime geometry writes. A failure retains the safe hold.
    bool readStartupGeometry(uint8_t (&output)[4],std::string& error) {
        lastFailure.clear();
        error.clear();
        uint32_t mask=0,selector=0;
        bool leaseRequested=false;
        auto fail=[&](const char* reason) {
            error=reason;
            if(!lastFailure.empty()) error+=" ["+lastFailure+"]";
            if(leaseRequested) {
                const bool safe=holdSafe();
                error+=safe?"; capture held safe; external recovery required":
                    "; capture hold unverified; external recovery required";
            }
            report("startup readback failed: "+error,true);
            return false;
        };
        if(!supported()) return fail("Startup runtime signature unavailable");
        if(!poll(0x400200b0,0xffffffff,0) || !poll(0x40020010,0x77,0))
            return fail("Startup converter did not drain");
        if(!io.read(0x20000880,mask) || !io.read(0x400200c0,selector))
            return fail("Startup capture state snapshot failed");
        if(!writeChecked(0x400200c0,uint32_t(camera_)))
            return fail("Startup lease selector failed");
        leaseRequested=true; // A failed MMIO write may already have reached HW.
        if(!io.write(0x40020020,1) || !poll(0x40020010,2,2))
            return fail("Startup camera freeze failed");
        if(!writeChecked(0x20000880,mask & ~(1u<<camera_)) ||
           !poll(0x20000890,1u<<camera_,1u<<camera_))
            return fail("Startup producer did not drain");
        if(!metadata(Mode::Default)) return fail("Startup runtime geometry mismatch");
        uint8_t power=0;
        if(!sensor(0x3008,power,true)) return fail("Startup sensor power read failed");
        if(power&0xc0) return fail("Startup sensor inactive");
        for(uint16_t a=0x3808;a<=0x380b;++a) {
            output[a-0x3808]=0;
            if(!sensor(a,output[a-0x3808],true))
                return fail("Startup sensor geometry read failed");
        }
        const uint32_t width=uint32_t(output[0])<<8|output[1];
        const uint32_t height=uint32_t(output[2])<<8|output[3];
        if(width!=640 || height!=480) return fail("Startup sensor output mismatch");
        // Do not admit the producer or release its lease until every read and
        // validation above succeeded. Restore the exact prior view and selector.
        if(!writeChecked(0x20000880,mask) || !io.write(0x40020020,0) ||
           !poll(0x40020010,0x77,0) || !writeChecked(0x400200c0,selector))
            return fail("Startup capture restore failed");
        return true;
    }
    bool holdSafe() {
        uint32_t mask=0;
        const bool frozen=writeChecked(0x400200c0,uint32_t(camera_)) && io.write(0x40020020,1) && poll(0x40020010,2,2);
        const bool disabled=io.read(0x20000880,mask) && writeChecked(0x20000880,mask & ~(1u<<camera_));
        return frozen && disabled && poll(0x20000890,1u<<camera_,1u<<camera_);
    }
    bool rollbackSafe() {
        if(rollbackSensor.empty()) return false;
        if(!holdSafe()) return false;
        return restoreHeld(rollbackSensor,rollbackPreserved,rollbackMode,rollbackSensorChanged);
    }
    // Explicit integration operation, never called by apply(). Both consumers
    // must remain stopped and the caller must own the global converter lease.
    // Release requires exact rollback and a mode-aware publication baseline.
    bool recoverPriorAndRelease(Mode expected,uint32_t priorMask,std::string& error) {
        auto fail=[&](const char* why) {
            error=why;
            if(!lastFailure.empty()) error+=" ["+lastFailure+"]";
            if(!holdSafe()) error+="; selected hold unverified";
            return false;
        };
        if(expected!=rollbackMode || !supported(expected) || rollbackSensor.empty())
            return fail("Prior recovery snapshot unavailable");
        if(!rollbackSafe()) return fail("Prior recovery rollback unverified");
        if(!verifyPreserved(rollbackPreserved,"pair-recovery"))
            return fail("Prior recovery preserved bytes changed");
        for(auto r:rollbackSensor) {
            uint8_t actual=0;
            if(!sensor(r.first,actual,true) || actual!=r.second)
                return fail("Prior recovery exact sensor snapshot mismatch");
        }
        for(uint16_t a:{0x300a,0x300b}) {
            uint8_t actual=0;
            if(!sensor(a,actual,true) || actual!=(a==0x300a?0x56:0x40))
                return fail("Prior recovery chip ID mismatch");
        }
        if(!metadata(expected)) return fail("Prior recovery metadata mismatch");
        if(!io.prepareMode || !io.prepareMode(expected))
            return fail("Prior recovery publication baseline failed");
        uint32_t mask=0;
        if(!io.read(0x20000880,mask) ||
           (mask & ~(1u<<camera_))!=(priorMask & ~(1u<<camera_)))
            return fail("Prior recovery unrelated producer mask changed");
        if(!writeChecked(0x20000880,priorMask) || !io.write(0x40020020,0) ||
           !poll(0x40020010,0x77,0) || !writeChecked(0x400200c0,4))
            return fail("Prior recovery release failed");
        return true;
    }
    bool apply(bool hd,bool previous,std::string& error) {
        return apply(hd?Mode::Hd720:Mode::Default,previous?Mode::Hd720:Mode::Default,error);
    }
    bool apply(Mode mode,Mode previous,std::string& error) {
        lastFailure.clear();
        error.clear();
        rollbackSensor.clear();rollbackPreserved.clear();
        report(std::string("apply target=")+modeName(mode)+" previous="+modeName(previous));
        if (!supported(mode) || !supported(previous)) { error="Camera runtime mode unavailable: unsupported mode or old FPGA signature"; return false; }
        if(mode==Mode::FullVga && io.prepare && !io.prepareMode) {
            error="FullVga requires explicit prepareMode callback; Boolean publication callback is ambiguous";return false;
        }
        const bool hd=sensorHd(mode),sensorChanged=hd!=sensorHd(previous);
        if(sensorHd(previous) && originals.empty()) {error="HD sensor has no saved VGA originals; external recovery required";return false;}
        bool held=false, disabled=false, changed=false;
        std::map<uint16_t,uint8_t> previousSensor;
        std::map<uint16_t,uint8_t> preserved;
        auto fail=[&](const char* reason) {
            error=reason;
            if(!lastFailure.empty()) error+=" ["+lastFailure+"]";
            report("transition failed: "+error);
            // Roll back geometry and every saved sensor register, but retain the
            // lease/mask and joined readers until an explicit successful retry.
            if (held && disabled && changed) {
                const bool restored=restoreHeld(previousSensor,preserved,previous,sensorChanged);
                if (!restored) error+="; rollback unverified, capture held safe";
                else error+="; prior sensor restored, capture held safe";
            }
            return false;
        };
        if (!poll(0x400200b0,0xffffffff,0) || !poll(0x40020010,0x77,0)) return fail("Converter did not drain");
        if (!writeChecked(0x400200c0,uint32_t(camera_)) || !io.write(0x40020020,1)) return fail("Camera lease request failed");
        held=true;
        if (!poll(0x40020010,2,2)) return fail("Cam1 freeze timeout");
        if (!io.read(0x20000880,savedMask_) || !writeChecked(0x20000880,savedMask_ & ~(1u<<camera_))) return fail("Producer disable failed");
        disabled=true;
        if (!poll(0x20000890,1u<<camera_,1u<<camera_)) return fail("Target producer did not drain");
        if(!metadata(previous)) return fail("Prior runtime geometry mismatch");
        report("snapshot stage=initial capture=held target-producer=disabled runtime-safe=lease-drained");
        for(uint16_t a:{0x300a,0x300b}) {
            uint8_t control=0;
            if(!sensor(a,control,true)||control!=(a==0x300a?0x56:0x40)) return fail("Initial chip ID control mismatch");
        }
        uint8_t power=0;
        if(!sensor(0x3008,power,true)) return fail("Active sensor snapshot failed");
        if(power&0xc0) {
            char text[128];std::snprintf(text,sizeof(text),"Sensor must already stream sensor=0x3008 actual=0x%02x standby/reset bits must be clear",power);
            report(text,true);return fail("Sensor inactive; capture held safe");
        }
        preserved[0x3008]=power;
        uint8_t independent=0;
        if(!sensor(0x3008,independent,true)||independent!=power) {
            char text[192];std::snprintf(text,sizeof(text),"initial independent full-byte3008 expected=0x%02x actual=0x%02x tx=%u",power,independent,transaction);
            report(text,true);return fail("Independent initial power snapshot disagreement; capture held safe");
        }
        if (originals.empty()) {
            std::map<uint16_t,uint8_t> snapshot;
            for (auto r:hdRegisters()) { uint8_t v=0; if(!sensor(r.first,v,true)) return fail("Sensor snapshot failed"); snapshot[r.first]=v; }
            for(uint16_t a:{0x3a08,0x3a09,0x3a0a,0x3a0b,0x3a0d,0x3a0e}) {
                uint8_t v=0; if(!sensor(a,v,true)) return fail("AEC snapshot failed"); snapshot[a]=v;
            }
            originals=std::move(snapshot);
        }
        for(auto r:originals) {
            uint8_t v=0; if(!sensor(r.first,v,true)) return fail("Prior mode snapshot failed");
            previousSensor[r.first]=v;
        }
        const auto priorOutput=geometry(previous); // Default C3/C4 sensor remains VGA, despite compressed transport.
        if((uint32_t(previousSensor.at(0x3808))<<8|previousSensor.at(0x3809))!=priorOutput.width ||
           (uint32_t(previousSensor.at(0x380a))<<8|previousSensor.at(0x380b))!=priorOutput.height)
            return fail("Prior sensor output mismatch; external recovery required");
        for(uint16_t a:{0x3034,0x3035,0x3036,0x3037,0x3108,0x3820,0x3821,0x3824,0x460c,0x4300,0x501f,0x5001}) {
            uint8_t v=0; if(!sensor(a,v,true)) return fail("Clock/format snapshot failed"); preserved[a]=v;
        }
        rollbackSensor=previousSensor;rollbackPreserved=preserved;rollbackMode=previous;
        rollbackSensorChanged=sensorChanged;
        report("snapshot stage=pre-table capture=held target-producer=disabled");
        if(!verifyPreserved(preserved,"pre-table")) return fail("Preserved clock/format or sensor power changed before table");
        changed=true;
        if(sensorChanged && hd) {
            for(auto r:hdRegisters()) if(!put(r.first,r.second)) return fail("720P sensor readback failed");
            const uint32_t oldHts=uint32_t(originals.at(0x380c))*256+originals.at(0x380d);
            for(uint16_t a:{0x3a08,0x3a0a}) {
                const uint32_t oldStep=uint32_t(originals.at(a))*256+originals.at(a+1);
                const uint32_t step=(oldStep*oldHts+hdHts/2)/hdHts;
                if(step && (!put(a,uint8_t(step>>8)) || !put(a+1,uint8_t(step)) ||
                    !put(a==0x3a08?0x3a0e:0x3a0d,uint8_t(hdVts/step)))) return fail("AEC readback failed");
            }
        }
        else if(sensorChanged) { for(auto r:originals) if(!put(r.first,r.second)) return fail("480P exact restore failed"); }
        if(!verifyPreserved(preserved,"post-table")) return fail("Preserved clock/format readback changed after table");
        if(!io.write(base_,uint32_t(mode)) || !metadata(mode)) return fail("Runtime geometry mismatch");
        settleLive();
        if(!verifyPreserved(preserved,"post-settle")) return fail("Preserved clock/format or sensor power changed after settle");
        for(uint16_t a:{0x300a,0x300b}) {
            uint8_t control=0;
            if(!sensor(a,control,true)||control!=(a==0x300a?0x56:0x40)) return fail("Settled chip ID control mismatch");
        }
        const auto target=geometry(hd);
        for(uint16_t a=0x3808;a<=0x380b;++a) {
            uint8_t actual=0;
            const uint32_t dimension=a<0x380a?target.width:target.height;
            const uint8_t expected=uint8_t((a&1)?dimension:dimension>>8);
            if(!sensor(a,actual,true)) return fail("Settled sensor output read failed");
            if(actual!=expected) {
                char text[192];std::snprintf(text,sizeof(text),"Settled sensor output mismatch sensor=0x%04x expected=0x%02x actual=0x%02x",a,expected,actual);
                report(text,true);return fail("Settled sensor geometry mismatch");
            }
        }
        if(io.prepareMode ? !io.prepareMode(mode) : (io.prepare && !io.prepare(hd)))
            return fail("Target publication snapshot failed");
        if(!writeChecked(0x20000880,savedMask_) || !io.write(0x40020020,0) || !poll(0x40020010,0x77,0)) {
            const bool restored=rollbackSafe();
            error=restored ? "Lease release failed; prior mode restored, capture held safe" :
                "Lease release failed; rollback unverified, capture held safe";
            return false;
        }
        if(!writeChecked(0x400200c0,4)) {
            const bool restored=rollbackSafe();
            error=restored ? "Capture restart failed; prior mode restored, capture held safe" :
                "Capture restart failed; rollback unverified, capture held safe";
            return false;
        }
        return true;
    }
};
}
