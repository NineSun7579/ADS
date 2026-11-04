#include "motion_policy_selftest.h"
#include "vision_types.h"
#include <QCoreApplication>
#include <cstdio>
#include <array>

int runMotionPolicySelfTest() {
    int checks=0, failures=0;
    auto check=[&](bool value,const char* label) {
        ++checks; if (!value) { ++failures; fprintf(stderr,"MOTION_FAIL %s\n",label); }
    };
    motion::Record quiet; quiet.referenceValid=true; quiet.seq=100; quiet.samples=15;
    motion::Observer observer;
    observer.observe(quiet,0,1);
    check(!motion::fresh(observer.evidence,0,1),"first observation cannot establish sequence advance");
    quiet.seq=105; observer.observe(quiet,100,1);
    auto decision=[&](const motion::Evidence& e,int64_t now,int64_t last,bool tracking=true,
                      bool lane=false,int camera=0,int generation=1,bool urgent=false) {
        return motion::decide(true,tracking,lane,camera,generation,e,now,last,urgent);
    };
    check(motion::consistent(quiet),"below-block-threshold changed samples are valid static");
    check(observer.gaps==4,"sampled sequence gaps counted without disabling gating");
    check(decision(observer.evidence,200,100).reason==motion::Reason::StaticDeferred,"static frame defers after minimum");
    check(decision(observer.evidence,350,100).reason==motion::Reason::Periodic,"static full-frame refresh at 250ms");
    check(decision(observer.evidence,200,100,false).reason==motion::Reason::StaticDeferred,"nontracking static also defers");
    check(decision(observer.evidence,401,100).reason==motion::Reason::Fallback,"stale source sequence falls back");
    observer.observe(quiet,400,1);
    check(decision(observer.evidence,401,100).reason==motion::Reason::Fallback,"repolling frozen record cannot refresh sequence freshness");

    motion::Observer events;
    auto moving=quiet; moving.seq=1; moving.samples=8; moving.blocks=1;
    moving.bitmap[5]=0x80000000u; moving.bboxValid=true;
    moving.minX=moving.maxX=15; moving.minY=moving.maxY=11;
    {
        motion::Observer repeated;
        repeated.observe(moving,0,1);
        check(repeated.evidence.motionUntilMs==500 && !motion::fresh(repeated.evidence,0,1),
              "initial positive seeds hold but needs sequence advance for freshness");
        auto advanced=moving; advanced.seq=2;
        repeated.observe(advanced,100,1);
        repeated.observe(advanced,200,1);
        repeated.observe(advanced,400,1);
        check(repeated.evidence.motionUntilMs==600 && repeated.evidence.advancedMs==100,
              "duplicate positive observations cannot renew hold or sequence freshness");
        check(decision(repeated.evidence,400,100).reason==motion::Reason::Motion,
              "duplicate positive remains fresh only through 300ms sequence age");
        repeated.observe(advanced,401,1);
        check(repeated.evidence.motionUntilMs>401 &&
              decision(repeated.evidence,401,100).reason==motion::Reason::Fallback,
              "frozen positive falls back beyond 300ms even while original hold active");
        repeated.observe(advanced,700,1);
        check(repeated.evidence.motionUntilMs==600 && !motion::fresh(repeated.evidence,700,1),
              "duplicate positive cannot restart expired hold");
        motion::Observer invalidReference;
        advanced.referenceValid=false;
        invalidReference.observe(advanced,0,1); ++advanced.seq;
        invalidReference.observe(advanced,100,1);
        check(motion::consistent(advanced) && invalidReference.evidence.motionUntilMs<0 &&
              !motion::fresh(invalidReference.evidence,100,1),
              "consistent positive bitmap without reference never authorizes motion hint");
    }
    events.observe(moving,0,1);
    moving.seq=2; events.observe(moving,100,1);
    auto after=quiet; after.seq=3; after.samples=1;
    events.observe(after,200,1); // latest metadata overwrites motion before worker request
    check(decision(events.evidence,250,100).reason==motion::Reason::Motion,"observed motion survives overwritten static metadata");
    check(!decision(events.evidence,250,200).request,"motion respects 100ms minimum");
    check(decision(events.evidence,250,100,true,false,0,1,true).reason==motion::Reason::Motion,"tracking loss triggers through static evidence");
    after.seq=4; events.observe(after,600,1);
    check(decision(events.evidence,600,500).reason==motion::Reason::StaticDeferred,"motion hold ends after 500ms");

    auto good=observer.evidence; good.observedMs=good.advancedMs=500;
    auto bad=good; bad.record.error=true;
    check(decision(bad,600,500).reason==motion::Reason::Fallback,"error flag cannot gate");
    bad=good; bad.record.referenceValid=false;
    check(decision(bad,600,500).reason==motion::Reason::Fallback,"reference initialization cannot gate");
    bad=good; bad.failed=true;
    check(decision(bad,600,500,false).request,"metadata IO failure restores nontracking inference");
    bad=good; bad.record.reservedInvalid=true;
    check(!motion::fresh(bad,600,1),"reserved flag bits cannot gate");
    bad=good; bad.record.blocks=1;
    check(!motion::fresh(bad,600,1),"bitmap popcount mismatch cannot gate");
    bad=good; bad.record.bboxValid=true;
    check(!motion::fresh(bad,600,1),"empty bitmap with valid bbox cannot gate");
    bad=good; bad.record=moving; bad.record.minX=14;
    check(!motion::fresh(bad,600,1),"bbox must match all bitmap bits including word 5");
    bad.record=moving; bad.record.samples=7;
    check(!motion::fresh(bad,600,1),"marked block requires eight changed points");
    bad.record=moving; bad.record.samples=19201;
    check(!motion::fresh(bad,600,1),"changed point count bounded to 19200");
    for (int camera : {4,5,-1}) check(decision(good,600,500,false,false,camera).reason==motion::Reason::Fallback,"CAM5/6 and unsupported source fallback");
    check(decision({},600,500,false).reason==motion::Reason::Fallback,"video packet without evidence fallback");
    for (int camera : {0,3,6}) {
        int64_t lastFallback=-1;
        for (int64_t now=0;now<=1000;now+=17) {
            const auto d=motion::decide(true,false,false,camera,1,{},now,lastFallback,false,100,100,500);
            if (d.request) {
                check(lastFallback<0 || now-lastFallback>=100,"missing metadata nontracking fallback respects minimum");
                lastFallback=now;
            }
        }
    }
    check(decision(good,550,500,true,true).request,"lane retains controller-driven cadence");
    check(decision(good,600,500,true,false,0,2).reason==motion::Reason::Fallback,"source generation cannot reuse old hint");
    check(motion::decide(false,false,false,0,1,good,550,500,false).request,"disabled retains original nontracking cadence");
    // Deadline waits must land on 55ms exactly, without changing admission.
    for (const int minimum : {1,55,100}) {
        int64_t now=500;
        while (now<500+minimum) {
            const auto d=motion::decide(true,false,false,0,1,{},now,500,false,250,minimum,500);
            check(!d.request,"event wait never bypasses configured minimum");
            const int delay=motion::retryDelayMs(d.reason,now,500,false,false,250,minimum,500);
            check(delay>=1 && delay<=20,"event maintenance wait stays bounded");
            now+=delay;
        }
        check(now==500+minimum && motion::decide(true,false,false,0,1,{},now,500,false,250,minimum,500).request,
              "event deadline avoids fixed-poll overshoot including 55ms");
    }
    check(motion::retryDelayMs(motion::Reason::StaticDeferred,993,500,false,false,250,55,500)==7,
          "static refresh retains exact 500ms deadline");
    check(motion::retryDelayMs(motion::Reason::Fallback,743,500,true,false,250,55,500)==7,
          "tracking fallback retains detection interval");

    motion::Observer wrap; quiet.seq=0xfffffffeu; wrap.observe(quiet,0,2);
    quiet.seq=1; wrap.observe(quiet,100,2);
    check(motion::fresh(wrap.evidence,100,2) && wrap.gaps==2,"monotonic 32-bit wrap accepted");
    quiet.seq=0; wrap.observe(quiet,200,2);
    check(!motion::fresh(wrap.evidence,200,2) && wrap.resets==1,"backwards sequence reset falls back");
    wrap.observe(quiet,300,2);
    check(!motion::fresh(wrap.evidence,300,2),"repeated reset sequence cannot recover");
    quiet.seq=1; wrap.observe(quiet,400,2);
    check(motion::fresh(wrap.evidence,400,2),"advance after sequence reset recovers");
    wrap.observe(quiet,500,3);
    check(!motion::fresh(wrap.evidence,500,3) && wrap.evidence.motionUntilMs<0,"generation reset clears history and needs new advance");

    // Feed real VisionFrame identities at 40ms; simulated completed controller
    // advances its four-model round robin only when a request is actually made.
    std::array<int64_t,4> modelLast{-1,-1,-1,-1};
    std::array<int,4> modelCounts{};
    int next=0, submitted=0, deferred=0; int64_t last=-1; quint64 previousId=0;
    motion::Observer periodic;
    for (int64_t now=0;now<=2400;now+=40) {
        quiet.seq=uint32_t(now/40+1);
        if (now%120==0) periodic.observe(quiet,now,7);
        VisionFrame frame; frame.frameId=quint64(now/40+1); frame.sourceGeneration=7;
        frame.camera=0; frame.motion=periodic.evidence;
        auto d=decision(frame.motion,now,last,true,false,frame.camera,7);
        if (!d.request) { if (d.reason==motion::Reason::StaticDeferred) ++deferred; continue; }
        check(frame.frameId>previousId,"refresh uses advancing full-frame identity");
        previousId=frame.frameId; last=now; ++submitted;
        if (modelLast[next]>=0) check(now-modelLast[next]<=1120,"four models refresh below two-second tracking expiration");
        modelLast[next]=now; ++modelCounts[next]; next=(next+1)%4;
    }
    check(submitted>=9 && submitted<=10 && deferred>0,"static work reduced with bounded periodic coverage");
    for (int count : modelCounts) check(count>=2,"every round-robin model gets repeated static-scene refresh");

    // Exercise frozen snapshot protocol through fault injection, not hardware.
    std::array<uint32_t,motion::WordCount> words{};
    words[0]=8; words[1]=1; words[2]=15u<<8;
    for (int fail=-1;fail<23;++fail) {
        int operation=0, selected=-1, captures=0;
        motion::Record out; out.seq=777;
        bool ok=motion::capture(0,out,[&](uint32_t addr,uint32_t word) {
            if (operation++==fail) return false;
            if (addr!=motion::Selector) return false;
            if (word&0x80000000u) ++captures;
            selected=int(word&15u); return true;
        },[&](uint32_t addr,uint32_t& word) {
            if (operation++==fail) return false;
            word=addr==motion::Generation ? 12u : words.at(size_t(selected)); return true;
        });
        check(fail<0 ? ok && captures==1 && operation==23 && out.seq==8 && motion::consistent(out) : !ok && out.seq==777,
              "atomic capture publishes only complete snapshot across all IO failure points");
    }
    {
        unsigned generationReads=0;
        motion::Record out; out.seq=777;
        check(!motion::capture(0,out,[](uint32_t,uint32_t) { return true; },
            [&](uint32_t address,uint32_t& word) {
                word=address==motion::Generation ? ++generationReads : 0; return true;
            }) && out.seq==777,"torn capture generation does not publish");
        unsigned calls=0;
        check(!motion::capture(4,out,[&](uint32_t,uint32_t) { ++calls; return true; },
            [&](uint32_t,uint32_t&) { ++calls; return true; }) && calls==0,
            "unsupported ABI slot performs no DMA");
    }
    fprintf(stderr,"MOTION_POLICY_SELFTEST_%s checks=%d failures=%d\n",failures ? "FAIL" : "PASS",checks,failures);
    return failures ? 2 : 0;
}
#ifdef MOTION_POLICY_STANDALONE
int main(int argc,char** argv) { QCoreApplication app(argc,argv); return runMotionPolicySelfTest(); }
#endif
