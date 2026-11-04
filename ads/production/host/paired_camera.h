#pragma once
#include <array>
#include <limits>
#include <memory>
#include "cam1_pair_runtime.h"

namespace cam34_pair {
using Mode=runtime_camera::Mode;
using Geometry=runtime_camera::Geometry;
enum class State { Pending, Committed, Recovered, HeldSafe, Rejected };
struct Current { Mode mode=Mode::Default; uint64_t generation=0; uint32_t sequence=0; };
struct Baseline { uint32_t floor=0; std::array<uint32_t,2> stale{{0,0}}; };
struct Publication {
    int camera=-1,bank=-1;
    Mode mode=Mode::Default;
    uint64_t generation=0;
    uint32_t sequence=0,bytes=0;
    // Hook must validate the entire commit tag (including stable reread), then
    // copy pixels under DMA ownership. No RX pointer may escape that ownership.
    bool verifiedCommit=false;
};
struct Result { State state=State::Rejected; std::string error; };
struct Hooks {
    // Caller serializes all global converter/mode operations for this call.
    std::function<bool()> acquire;
    std::function<void()> unlock;
    // Must stop/join BOTH readers and drain all pair/analytics consumers.
    std::function<bool()> stopJoin;
    std::function<bool(int,Current&)> current;
    // Snapshot BOTH exact descriptor tag addresses. held=false is the unchanged
    // mode path; stable tag reads are still required, followed by a newer frame.
    std::function<bool(const Geometry&,bool,Baseline&)> prepare;
    // Bounded wait/copy using a private reader while ordinary consumers stay off.
    // Successive calls must advance to a newer frame. Both banks must be seen
    // within four calls; repeating the same publication cannot prove readiness.
    std::function<bool(const Geometry&,Publication&)> publication;
    // Atomically install both descriptors/current floors and UI selection only
    // after both proofs; keep A's existing rendering/pairing policy unchanged.
    std::function<void(const std::array<Geometry,2>&,const std::array<Publication,2>&,bool)> commit;
    std::function<void()> resume;
    std::function<void(State)> state;
};
class Coordinator {
    Hooks hooks;
    std::array<cam1_pair::Io,2> io;
    std::array<std::unique_ptr<cam1_pair::Switch>,2> controller;
    std::array<Geometry,2> candidate;
    std::array<Baseline,2> baseline;
    std::array<Publication,2> proof;
    std::array<Current,2> prior;
    uint64_t generation=0;
    bool stopped=false,blocked=false,shuttingDown=false;
    bool metadata(int i,Mode mode) {
        auto g=runtime_camera::geometry(i+2,mode);uint32_t v=0;
        const uint32_t base=controller[i]->base();
        return io[i].read(base,v)&&v==uint32_t(mode)&&
            io[i].read(base+0x40,v)&&v==(g.width<<16|g.height)&&
            io[i].read(base+0x50,v)&&v==g.pixelBytes&&
            io[i].read(base+0x60,v)&&v==g.stride;
    }
    bool arm(int i,Mode mode,bool held) {
        if(generation==std::numeric_limits<uint64_t>::max()) return false;
        candidate[i]=runtime_camera::geometry(i+2,mode,++generation);
        baseline[i]={};proof[i]={};
        if(!hooks.prepare(candidate[i],held,baseline[i])) return false;
        // A hook cannot weaken the previous committed sequence floor.
        if(baseline[i].floor!=prior[i].sequence &&
           !cam1_pair::freshTargetSequence(baseline[i].floor,prior[i].sequence,prior[i].sequence)) return false;
        return true;
    }
    bool fresh(int i) {
        if(!metadata(i,candidate[i].mode)) return false;
        const auto& g=candidate[i];
        uint32_t floor=baseline[i].floor;unsigned banks=0;
        for(int sample=0;sample<4;++sample) {
            Publication p;
            if(!hooks.publication(g,p)) return false;
            if(!p.verifiedCommit || p.camera!=i+2 || p.mode!=g.mode || p.bank<0 || p.bank>1 ||
               !g.acceptsPublication(p.generation,p.bytes) ||
               !cam1_pair::freshTargetSequence(p.sequence,floor,baseline[i].stale[p.bank])) return false;
            floor=p.sequence;banks|=1u<<p.bank;proof[i]=p;
            if(banks==3)return true;
        }
        return false;
    }
    bool idle() {
        uint32_t status=0,pending=0;
        return io[0].read(0x40020010,status)&&(status&0x77)==0&&
               io[0].read(0x400200b0,pending)&&pending==0;
    }
    Result finish(State state,const std::string& error) {
        if(state==State::HeldSafe) blocked=true;
        if(hooks.state) hooks.state(state);
        return {state,error};
    }
public:
    Coordinator(std::array<cam1_pair::Io,2> transports,Hooks integration):hooks(integration),io(transports) {
        for(int i=0;i<2;++i) {
            // Override ambiguous/foreign callbacks: all pair publication baselines
            // are owned by this coordinator with its explicit mode/generation.
            io[i].prepare={};
            io[i].prepareMode=[this,i](Mode mode){return shuttingDown || arm(i,mode,true);};
            controller[i].reset(new cam1_pair::Switch(io[i],i+2));
        }
    }
    Coordinator(const Coordinator&)=delete;
    Coordinator& operator=(const Coordinator&)=delete;
    // Caller has joined every reader and drained analytics. Use the SAME Switch
    // instances which saved the exact VGA originals during pair transitions.
    // Shutdown has no publication consumer and must never invoke hooks.resume().
    bool restoreForShutdown(const std::array<Mode,2>& modes,std::string& error) {
        if(blocked || !idle()) {error="Pair shutdown requires healthy drained hardware";return false;}
        shuttingDown=true;
        struct Reset { bool& value; ~Reset(){value=false;} } reset{shuttingDown};
        for(int i=0;i<2;++i) {
            if(!metadata(i,modes[i])) {error="Pair shutdown prior geometry mismatch";return false;}
            if(modes[i]!=Mode::Default && !controller[i]->apply(Mode::Default,modes[i],error)) {
                controller[i]->holdSafe();return false;
            }
            if(!metadata(i,Mode::Default)) {error="Pair shutdown default geometry unverified";return false;}
        }
        return true;
    }
    Result apply(Mode target) {
        return apply(std::array<Mode,2>{{target,target}});
    }
    Result apply(const std::array<Mode,2>& targets) {
        if(blocked) return finish(State::HeldSafe,"External recovery required after held pair failure");
        if(!hooks.acquire||!hooks.unlock||!hooks.stopJoin||!hooks.current||!hooks.prepare||
           !hooks.publication||!hooks.commit||!hooks.resume) return finish(State::Rejected,"Missing integration hook");
        if(!hooks.acquire()) return finish(State::Rejected,"Global runtime ownership unavailable");
        struct Unlock { Hooks& h; ~Unlock(){h.unlock();} } unlock{hooks};
        // Preflight both before stop or any hardware mutation, even if first fails.
        bool admitted=true;
        for(int i=0;i<2;++i) {
            const bool known=hooks.current(i+2,prior[i]);
            const bool targetOk=controller[i]->supported(targets[i]);
            const bool priorOk=known && controller[i]->supported(prior[i].mode);
            admitted=known&&targetOk&&priorOk&&prior[i].generation&&
                !(prior[i].mode==Mode::Hd720&&!controller[i]->hasOriginals())&&admitted;
            if(known && prior[i].generation>generation) generation=prior[i].generation;
        }
        if(!admitted || !idle()) return finish(State::Rejected,"Pair preflight or global idle check failed");
        stopped=true;
        if(!hooks.stopJoin()) return finish(State::HeldSafe,"Both consumers could not be proven stopped");
        if(hooks.state) hooks.state(State::Pending);
        uint32_t mask=0;
        if(!io[0].read(0x20000880,mask) || (mask&0xcu)!=0xcu)
            return finish(State::HeldSafe,"Both producers must be admitted for fresh verification");
        std::array<bool,2> changed{{false,false}};
        std::string error;
        int failed=-1;
        for(int i=0;i<2;++i) {
            const Mode target=targets[i];
            if(target==prior[i].mode) {
                if(!arm(i,target,false)||!fresh(i)) {failed=i;error="Unchanged camera lacks fresh evidence";break;}
            } else {
                changed[i]=true; // Even a rejected MMIO may have reached HW.
                if(!controller[i]->apply(target,prior[i].mode,error)||!fresh(i)) {
                    failed=i;if(error.empty())error="Target fresh publication rejected";break;
                }
            }
        }
        if(failed<0) {
            hooks.commit(candidate,proof,true);hooks.resume();stopped=false;
            return finish(State::Committed,"");
        }
        // Descending order is essential: selected failed camera owns the ONE
        // global lease. Restore/release/verify it before touching the first.
        for(int i=failed;i>=0;--i) {
            if(changed[i]) {
                std::string cleanup;
                if(!controller[i]->recoverPriorAndRelease(prior[i].mode,mask,cleanup) || !idle())
                    return finish(State::HeldSafe,error+"; cleanup: "+cleanup);
            } else if(!arm(i,prior[i].mode,false))
                return finish(State::HeldSafe,error+"; prior baseline failed");
            if(!fresh(i)) return finish(State::HeldSafe,error+"; prior publication unverified");
        }
        // Cameras not attempted still require fresh evidence/new generations.
        for(int i=failed+1;i<2;++i)
            if(!arm(i,prior[i].mode,false)||!fresh(i))
                return finish(State::HeldSafe,error+"; untouched prior publication unverified");
        hooks.commit(candidate,proof,false);hooks.resume();stopped=false;
        return finish(State::Recovered,error);
    }
    bool consumersStopped() const {return stopped;}
};
} // namespace cam34_pair
