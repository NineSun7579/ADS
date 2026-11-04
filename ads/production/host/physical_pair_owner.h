#pragma once
#include "c5_transaction.h"
#include <algorithm>
#include <array>
#include <functional>
#include <limits>
#include <cstdio>

namespace physical_pair {
constexpr unsigned Mask = 0x30u;
using Geometry = runtime_camera::Geometry;
using Mode = runtime_camera::Mode;
using Tags = std::array<std::array<uint32_t, 2>, 2>;
struct Observation {
    bool coherent = false, known = false, link = false, nativeValid = false;
    unsigned failure = 0;
    bool descriptorCoherent=false, diagnosticCoherent=false;
    runtime_camera::NativeDescriptor descriptor;
    uint32_t diagnosticCount = 0, status = 0;
};
// Literal register layout from s100v10 c5_native_descriptor.sv:59..89;
// status bits from c5_optical_runtime.sv:338 and s50v10c top.v:307,
// cam5_native_diag_sender.v:65. No legacy-selected/connected bit exists.
template<class Read> Observation observeRegistersOnce(Read& read) {
    Observation out;
    uint32_t first[9]{}, second[9]{};
    std::array<uint32_t, 7> diag{}, verify{};
    constexpr uint32_t offsets[] = {0x100, 0x130, 0x140, 0x150, 0x160, 0x170, 0x180};
    for (unsigned i = 0; i < 9; ++i) if (!read(0x20021000u + i * 16u, first[i])) {out.failure=1;return out;}
    for (unsigned i = 0; i < 7; ++i) if (!read(0x20021000u + offsets[i], diag[i])) {out.failure=2;return out;}
    out.diagnosticCount=diag[2];out.status=diag[3];out.link=(diag[1]&(1u<<9))!=0;
    for (unsigned i = 0; i < 9; ++i) if (!read(0x20021000u + i * 16u, second[i])) {out.failure=3;return out;}
    for (unsigned i = 0; i < 7; ++i) if (!read(0x20021000u + offsets[i], verify[i])) {out.failure=4;return out;}
    out.diagnosticCoherent=diag==verify;
    out.descriptorCoherent=runtime_camera::coherentNativeDescriptor(first,second,out.descriptor);
    if(!out.diagnosticCoherent){out.failure=5;return out;}
    if(diag[0]!=0x4e484432u){out.failure=6;return out;}
    if(!out.descriptorCoherent){out.failure=7;return out;}
    out.coherent = true;
    out.known = first[0] == 0x4e484d31u && first[1] == 1;
    out.link = (diag[1] & (1u << 9)) != 0;
    out.diagnosticCount = diag[2]; out.status = diag[3];
    // fresh snapshot, requested, HDMI active, initialized and format-qualified.
    constexpr uint32_t required = (1u << 7) | (1u << 6) | (7u << 8);
    out.nativeValid = out.known && out.link && runtime_camera::nativeMode(out.descriptor.mode) &&
        (out.status & required) == required;
    return out;
}
template<class Read> Observation observeRegisters(Read read) {
    // Retry only torn observations, rereading both complete pages each time.
    // Never reuse evidence or retry a transport/signature failure or source loss.
    for (unsigned attempt = 0; ; ++attempt) {
        const auto out = observeRegistersOnce(read);
        if ((out.failure != 5 && out.failure != 7) || attempt == 2) return out;
    }
}
struct Hooks {
    c5::Board io;
    std::function<Geometry(int)> geometry;
    std::function<bool()> quiesce; // fence, stop/join only pair; drain pair lease
    std::function<bool(const std::array<Geometry, 2>&, const Tags&)> restart;
    std::function<bool(uint32_t)> persist; // must succeed BEFORE command write
    std::function<void(const char*)> held;
};
enum class State { Legacy, Native, WaitingNative, WaitingLegacy, Held };
class Owner {
public:
    Owner(Hooks hooks, uint32_t persisted) : hooks_(std::move(hooks)), high_(std::max(persisted, 0xfffff0a0u)) {}
    State state() const { return state_; }
    bool pairHeld() const { return state_ == State::Held || state_ == State::WaitingNative || state_ == State::WaitingLegacy; }
    const char* reason() const { return reason_; }
    bool transitionPending() const { return state_ == State::WaitingNative || state_ == State::WaitingLegacy; }
    // Called while workers are joined by the existing view transaction, before
    // it is allowed to restart pair readers using committed geometry.
    void verifyViewRestart() {
        if (pairHeld()) return;
        const auto observation=observeRegisters(hooks_.io.read);
        const auto now=hooks_.io.nowMs();
        if (!observation.coherent || !observation.known || (!observation.link && !legacyLinkExempt(observation)) ||
            (state_==State::Native && (!observation.nativeValid || observation.descriptor!=committed_ ||
                !advanced_ || now<lastAdvance_ || now-lastAdvance_>750)) ||
            (state_==State::Legacy && runtime_camera::nativeMode(observation.descriptor.mode) &&
                !frozenConfirmedNative(observation)))
            hold("source changed across view geometry fence",true);
    }
    void tick(bool operatorLegacy, unsigned captureMask, bool confirmedCam = false, bool passiveBoot = false,
              const Observation* sampled = nullptr) {
        const uint64_t now = hooks_.io.nowMs();
        const auto observation = sampled ? *sampled : observeRegisters(hooks_.io.read);
        lastObservation_=observation;
        if (observation.coherent) {
            if (!countSeen_) { countSeen_ = true; count_ = observation.diagnosticCount; }
            else if (observation.diagnosticCount != count_) { count_ = observation.diagnosticCount; advanced_ = true; lastAdvance_ = now; }
        }
        const bool fresh = advanced_ && now >= lastAdvance_ && now - lastAdvance_ <= 750;
        if (!passiveBoot) bootBaselineQualified_=false;
        if (operatorLegacy) {
            // One EXPLICIT operator attempt, not evidence of camera presence.
            if (automaticBlocked_ || legacyAttempted_ || state_ == State::WaitingNative || state_ == State::WaitingLegacy) {
                if(!rejectLogged_ || now<lastRejectLog_ || now-lastRejectLog_>=1000) {
                    rejectLogged_=true;lastRejectLog_=now;
                    logObservation("operator_reject_budget_or_pending",observation,now);
                }
                return;
            }
            if (!observation.coherent || !observation.known || (!observation.link && !confirmedCam) || captureMask != 0x3fu) {
                hold("operator recovery blocked: source/link/mask unknown"); return;
            }
            if (!confirmedCam && runtime_camera::nativeMode(observation.descriptor.mode)) {
                hold("select physical cameras before explicit legacy recovery"); return;
            }
            legacyAttempted_ = true;
            c5::Snapshot initial;
            if (!c5::capable(hooks_.io) || !c5::snapshot(hooks_.io, initial)) {
                hold("operator mailbox unavailable/busy/terminal");return;
            }
            uint32_t capability=0;
            const bool bootRequestRequired=confirmedCam && knownBootRequestRequired(initial) &&
                hooks_.io.read(c5::base+0x10,capability) && capability==0x301u;
            if ((!bootRequestRequired && (initial.error || initial.state == 5)) || initial.state > 5 ||
                (initial.state >= 1 && initial.state <= 3)) {
                logLegacy("operator_reject_mailbox","not eligible for explicit request",initial,true);
                hold("operator mailbox unavailable/busy/terminal"); return;
            }
            if(bootRequestRequired)logLegacy("operator_boot_request_required","exact RTL REQUIRE_REQUEST reset; one new epoch",initial,true);
            for (uint32_t value : {initial.doorbell, initial.epoch, initial.completed, initial.banks}) high_ = std::max(high_, value);
            if (high_ >= 0xfffffffeu) { hold("epoch exhausted: no wrap"); return; }
            if (!prepare(Mode::Default)) return;
            ++high_;
            if (!hooks_.persist(high_) || !hooks_.io.write(c5::base + 0x20, 0) || !hooks_.io.write(c5::base + 0x30, high_)) {
                hold("single operator request failed: no retry"); return;
            }
            confirmedLegacy_ = confirmedCam;
            confirmedObservation_ = observation;
            legacyBaselineQualified_ = false; stale_ = {}; currentTags_ = {};
            began_ = hooks_.io.nowMs(); lastWaitLog_ = began_;
            state_ = State::WaitingLegacy;
            logLegacy("request", "await exact new-epoch publication", initial, true);
            return;
        }
        if (state_ == State::WaitingNative || state_ == State::WaitingLegacy) {
            if (now < began_ || now - began_ > 8000) {
                if(state_==State::WaitingLegacy) {
                    c5::Snapshot deadline;const bool valid=c5::snapshot(hooks_.io,deadline);
                    logLegacy("deadline", "8s terminal; no retry", deadline, valid);
                }
                hold("pair transition deadline: explicit recovery required"); return;
            }
            if (!observation.coherent || !observation.known || (!observation.link && !legacyLinkExempt(observation))) { hold("pair observation/link unknown",state_==State::WaitingNative); return; }
            if (state_ == State::WaitingNative) {
                if (!observation.nativeValid || !fresh || observation.descriptor != pending_) { hold("native changed/invalid during admission",true); return; }
            } else {
                // Legacy diagnostics intentionally need NOT advance: they are
                // absent from the legacy mux. Authorization was explicit above.
                if (captureMask != 0x3fu ||
                    (runtime_camera::nativeMode(observation.descriptor.mode) && !frozenConfirmedNative(observation))) {
                    hold("native publication/mask changed during legacy recovery"); return;
                }
                c5::Snapshot mailbox;
                if (!c5::snapshot(hooks_.io, mailbox)) {
                    if(legacyBaselineQualified_) { hold("qualified legacy snapshot lost: no retry"); return; }
                    waitLegacy("snapshot unavailable before qualification",mailbox,false);return;
                }
                if (mailbox.error || mailbox.state == 5) { hold("legacy remote fault: no retry"); return; }
                if (mailbox.completed != high_ || mailbox.state != 4) {
                    if(legacyBaselineQualified_) { hold("qualified legacy publication lost: no retry"); return; }
                    waitLegacy("await state4/completed epoch",mailbox,true);return;
                }
                if (!qualifiedLegacy(mailbox)) {
                    hold("legacy publication ABI mismatch"); return;
                }
                legacyMailbox_ = mailbox;
            }
            Tags tags{};
            if (!readTags(target_, tags)) { hold("pair tag read failed"); return; }
            currentTags_ = tags;
            // Native keeps its pre-admission fence. Legacy must first fence the
            // acknowledged VGA publication: its future trailer was native pixels.
            if (state_==State::WaitingNative && !freshBanks(tags, stale_)) return;
            // Revalidate descriptor AND diagnostic gate after tag reads. This is
            // an observed fence, not a claim of hardware-atomic multiword reads.
            const auto verify = observeRegisters(hooks_.io.read);
            if (!verify.coherent || !verify.known || (!verify.link && !legacyLinkExempt(verify)) || verify.descriptor != observation.descriptor ||
                (state_ == State::WaitingNative && !verify.nativeValid) ||
                (state_ == State::WaitingLegacy && runtime_camera::nativeMode(verify.descriptor.mode) &&
                    !frozenConfirmedNative(verify))) { hold("descriptor changed across tag fence",state_==State::WaitingNative); return; }
            if (state_ == State::WaitingLegacy) {
                c5::Snapshot verifyMailbox;
                if (!c5::snapshot(hooks_.io, verifyMailbox) || !qualifiedLegacy(verifyMailbox) ||
                    verifyMailbox.publicationGeneration != legacyMailbox_.publicationGeneration ||
                    verifyMailbox.frame != legacyMailbox_.frame) {
                    hold("legacy completion changed across tag fence"); return;
                }
                const auto verifiedAt=hooks_.io.nowMs();
                if(verifiedAt<began_ || verifiedAt-began_>8000) {
                    logLegacy("deadline","8s exhausted during tag fence",verifyMailbox,true);
                    hold("pair transition deadline: explicit recovery required");return;
                }
                if(!legacyBaselineQualified_) {
                    for(const auto& camera:tags) for(const auto value:camera)
                        if(!value || value==0xffffffffu) { hold("invalid acknowledged legacy baseline");return; }
                    stale_=tags;legacyBaselineQualified_=true;
                    logLegacy("qualified_baseline","await all four banks forward",verifyMailbox,true);
                    return;
                }
                if(!freshBanks(tags,stale_)) {
                    waitLegacy("all four banks must advance acknowledged baseline",verifyMailbox,true);return;
                }
                logLegacy("restart","all four banks forward",verifyMailbox,true);
            }
            if (!hooks_.restart(target_, stale_)) { hold("pair geometry/restart failed"); return; }
            const bool native = state_ == State::WaitingNative;
            committed_ = native ? pending_ : runtime_camera::NativeDescriptor{};
            state_ = native ? State::Native : State::Legacy;
            if (native) { legacyAttempted_ = false; confirmedLegacy_ = false; }
            reason_ = ""; return;
        }
        if (state_ == State::Native) {
            if (!observation.coherent || !observation.known || !observation.link || !observation.nativeValid || !fresh) {
                hold("native ended/invalid; fresh stable native may reenter; legacy requires explicit C5 VGA",true); return;
            }
        } else if (!observation.coherent || !observation.known || (!observation.link && !legacyLinkExempt(observation))) {
            hold("source/link unknown; pair held",true); return;
        }
        if(passiveBoot && state_==State::Held && !automaticBlocked_ && !legacyAttempted_ &&
            tryBootLegacy(observation,captureMask)) return;
        if(state_==State::Held && continuityRequired_ && !automaticBlocked_) {
            // An old committed descriptor is not proof of continuity after a hold.
            // Require two distinct diagnostic count changes for the SAME
            // coherent native descriptor, then take fresh target-bank baselines.
            if(!observation.nativeValid || !fresh) { stableCount_=0; stableDescriptor_={}; return; }
            if(observation.diagnosticCount==continuityCount_)return;
            continuityCount_=observation.diagnosticCount;
            if(stableCount_ && observation.descriptor==stableDescriptor_)++stableCount_;
            else {stableDescriptor_=observation.descriptor;stableCount_=1;}
            if(stableCount_<2)return;
        }
        if (!automaticBlocked_ && observation.nativeValid && fresh && !frozenConfirmedNative(observation) &&
            (observation.descriptor != committed_ || (state_==State::Held && continuityRequired_))) {
            if (!prepare(observation.descriptor.mode)) return;
            if(continuityRequired_)logObservation("native_reentry_prepare",observation,now);
            continuityRequired_=false;stableCount_=0;
            pending_ = observation.descriptor; began_ = now; state_ = State::WaitingNative;
        }
    }
    static bool freshBanks(const Tags& tags, const Tags& stale) {
        for (unsigned camera = 0; camera < 2; ++camera) for (unsigned bank = 0; bank < 2; ++bank) {
            const auto value = tags[camera][bank];
            if (!value || value == 0xffffffffu) return false;
            for (unsigned prior = 0; prior < 2; ++prior) {
                const uint32_t distance = value - stale[camera][prior];
                if (!distance || distance >= 0x80000000u) return false;
            }
        }
        return true;
    }
private:
    // c5_additions/c5_mailbox.sv:101-105: REQUIRE_REQUEST cold reset,
    // not a generic FAILED recovery. Never consulted after our request writes.
    static bool knownBootRequestRequired(const c5::Snapshot& mailbox) {
        return mailbox.state==5 && mailbox.error==0x1007u && !mailbox.doorbell &&
            !mailbox.completed && !mailbox.epoch && !mailbox.banks && !mailbox.frame &&
            mailbox.dimensions==0x028001e0u && mailbox.bytes==614400u &&
            mailbox.stride==1280u && mailbox.c6==0x028001e0u;
    }
    bool legacyLinkExempt(const Observation& observation) const {
        return (state_==State::Legacy || state_==State::WaitingLegacy) &&
            confirmedLegacy_ && observation.coherent && observation.known &&
            (!runtime_camera::nativeMode(observation.descriptor.mode) || frozenConfirmedNative(observation));
    }
    // No command, epoch allocation, confirmation exemption or transaction deadline.
    // Missing/stale/torn boot evidence only discards this passive candidate.
    bool tryBootLegacy(const Observation& observation,unsigned captureMask) {
        c5::Snapshot mailbox;
        auto eligible=[&](const Observation& value) {
            return value.coherent && value.known && value.link && value.descriptor.mode==Mode::Default;
        };
        if(captureMask!=0x3fu || !eligible(observation) || !c5::capable(hooks_.io) ||
            !c5::snapshot(hooks_.io,mailbox) || !mailbox.epoch || mailbox.epoch==0xffffffffu ||
            !qualifiedLegacyEpoch(mailbox,mailbox.epoch)) {bootBaselineQualified_=false;return false;}
        std::array<Geometry,2> geometry;
        for(unsigned camera=0;camera<2;++camera) {
            const auto old=hooks_.geometry(int(camera)+4);
            if(!old.valid() || old.generation==std::numeric_limits<uint64_t>::max()) {
                bootBaselineQualified_=false;return false;
            }
            geometry[camera]=runtime_camera::geometry(int(camera)+4,Mode::Default,old.generation+1);
        }
        Tags tags{};
        if(!readTags(geometry,tags)) {bootBaselineQualified_=false;return false;}
        auto fenced=[&]() {
            const auto verify=observeRegisters(hooks_.io.read);
            c5::Snapshot after;
            return eligible(verify) && verify.descriptor==observation.descriptor &&
                verify.diagnosticCount==observation.diagnosticCount && verify.status==observation.status &&
                c5::snapshot(hooks_.io,after) && qualifiedLegacyEpoch(after,mailbox.epoch) &&
                after.publicationGeneration==mailbox.publicationGeneration && after.frame==mailbox.frame;
        };
        if(!fenced()) {bootBaselineQualified_=false;return false;}
        for(const auto& camera:tags) for(const auto value:camera)
            if(!value || value==0xffffffffu) {bootBaselineQualified_=false;return false;}
        const auto now=hooks_.io.nowMs();
        if(!bootBaselineQualified_ || bootEpoch_!=mailbox.epoch || now<bootBaselineAt_ || now-bootBaselineAt_>750) {
            bootEpoch_=mailbox.epoch;bootBaseline_=tags;bootBaselineAt_=now;bootBaselineQualified_=true;return false;
        }
        if(!freshBanks(tags,bootBaseline_)) return false;
        if(!prepare(Mode::Default)) return true; // Real host fence failures remain terminal.
        const bool stable=fenced();
        const auto verifiedAt=hooks_.io.nowMs();
        if(!stable || verifiedAt<bootBaselineAt_ || verifiedAt-bootBaselineAt_>750) {
            bootBaselineQualified_=false;return false;
        }
        if(!hooks_.restart(target_,bootBaseline_)) {hold("boot pair geometry/restart failed");return true;}
        high_=std::max(high_,mailbox.epoch);
        committed_={};state_=State::Legacy;reason_="";continuityRequired_=false;
        bootBaselineQualified_=false;
        std::fprintf(stderr,"PHYSICAL_PAIR_BOOT event=passive_adopt epoch=0x%08x no_command=1 four_banks_forward=1\n",mailbox.epoch);
        std::fflush(stderr);
        return true;
    }
    static bool qualifiedLegacyEpoch(const c5::Snapshot& mailbox,uint32_t epoch) {
        return mailbox.state==4 && !mailbox.error && mailbox.completed==epoch &&
            mailbox.epoch==epoch && mailbox.banks==epoch && mailbox.doorbell==epoch &&
            mailbox.dimensions==0x028001e0u && mailbox.bytes==614400u &&
            mailbox.stride==1280u && mailbox.c6==0x028001e0u && mailbox.frame;
    }
    bool qualifiedLegacy(const c5::Snapshot& mailbox) const {
        return qualifiedLegacyEpoch(mailbox,high_);
    }
    void logLegacy(const char* event,const char* why,const c5::Snapshot& mailbox,bool valid) const {
        const auto now=hooks_.io.nowMs();
        std::fprintf(stderr,"PHYSICAL_PAIR_LEGACY event=%s request=0x%08x reason=%s elapsed_ms=%llu limit_ms=8000 snapshot=%u state=%u completed=0x%08x effective=0x%08x banks=0x%08x doorbell=0x%08x dimensions=0x%08x bytes=%u stride=%u c6=0x%08x error=%u frame=%u publication=%u qualified=%u baseline=%u,%u,%u,%u current=%u,%u,%u,%u\n",
            event,high_,why,static_cast<unsigned long long>(now>=began_?now-began_:0),unsigned(valid),
            mailbox.state,mailbox.completed,mailbox.epoch,mailbox.banks,mailbox.doorbell,
            mailbox.dimensions,mailbox.bytes,mailbox.stride,mailbox.c6,mailbox.error,mailbox.frame,
            mailbox.publicationGeneration,unsigned(legacyBaselineQualified_),stale_[0][0],stale_[0][1],
            stale_[1][0],stale_[1][1],currentTags_[0][0],currentTags_[0][1],currentTags_[1][0],currentTags_[1][1]);
        std::fflush(stderr);
    }
    void waitLegacy(const char* why,const c5::Snapshot& mailbox,bool valid) {
        const auto now=hooks_.io.nowMs();
        if(now>=lastWaitLog_ && now-lastWaitLog_>=1000) {
            lastWaitLog_=now;logLegacy("wait",why,mailbox,valid);
        }
    }
    // Only an explicit physical-CAM confirmation may disregard the exact old
    // native publication. Any new native packet/descriptor ends that exemption.
    bool frozenConfirmedNative(const Observation& observation) const {
        return confirmedLegacy_ && observation.descriptor == confirmedObservation_.descriptor &&
            observation.diagnosticCount == confirmedObservation_.diagnosticCount &&
            observation.status == confirmedObservation_.status;
    }
    bool readTags(const std::array<Geometry, 2>& geometry, Tags& tags) {
        for (unsigned camera = 0; camera < 2; ++camera) for (unsigned bank = 0; bank < 2; ++bank)
            if (!hooks_.io.tag(geometry[camera].tagAddress(bank), tags[camera][bank])) return false;
        return true;
    }
    bool prepare(Mode mode) {
        if (!hooks_.quiesce()) { automaticBlocked_=true;hold("pair quiesce/drain failed"); return false; }
        for (unsigned camera = 0; camera < 2; ++camera) {
            const auto old = hooks_.geometry(int(camera) + 4);
            if (!old.valid() || old.generation == std::numeric_limits<uint64_t>::max()) { automaticBlocked_=true;hold("host geometry generation exhausted"); return false; }
            target_[camera] = runtime_camera::geometry(int(camera) + 4, mode, old.generation + 1);
            if (!target_[camera].valid()) { automaticBlocked_=true;hold("invalid target geometry"); return false; }
        }
        if (mode!=Mode::Default && !readTags(target_, stale_)) { automaticBlocked_=true;hold("target geometry stale fences unavailable"); return false; }
        return true;
    }
    void hold(const char* why,bool sourceObservation=false) {
        if(state_==State::WaitingLegacy) {
            c5::Snapshot mailbox;const bool valid=c5::snapshot(hooks_.io,mailbox);
            logLegacy("terminal_hold",why,mailbox,valid);
            legacyBaselineQualified_=false;
        }
        if(!sourceObservation)automaticBlocked_=true;
        const bool already = state_ == State::Held;
        if(sourceObservation && !automaticBlocked_) {
            continuityRequired_=true;continuityCount_=count_;stableCount_=0;stableDescriptor_={};
        }
        state_ = State::Held; reason_ = why;
        if (!already) {
            if(!hooks_.quiesce()) {automaticBlocked_=true;reason_="pair hold quiesce failed: terminal";}
            logObservation(automaticBlocked_?"terminal_hold":"source_observation_hold",lastObservation_,hooks_.io.nowMs());
            hooks_.held(reason_);
        }
    }
    void logObservation(const char* event,const Observation& observation,uint64_t now) const {
        const auto age=advanced_&&now>=lastAdvance_?now-lastAdvance_:std::numeric_limits<uint64_t>::max();
        std::fprintf(stderr,"PHYSICAL_PAIR_OBSERVATION event=%s reason=%s coherent=%u known=%u link=%u native_valid=%u mode=%u fpga_generation=%u status=0x%08x required=0x000007c0 diag_count=%u last_count=%u age_ms=%llu advanced=%u stable=%u continuity_count=%u blocked=%u committed_mode=%u committed_generation=%u failure=%u descriptor_coherent=%u diagnostic_coherent=%u\n",
            event,reason_,unsigned(observation.coherent),unsigned(observation.known),unsigned(observation.link),
            unsigned(observation.nativeValid),unsigned(observation.descriptor.mode),observation.descriptor.generation,
            observation.status,observation.diagnosticCount,count_,static_cast<unsigned long long>(age),unsigned(advanced_),
            stableCount_,continuityCount_,unsigned(automaticBlocked_),unsigned(committed_.mode),committed_.generation,
            observation.failure,unsigned(observation.descriptorCoherent),unsigned(observation.diagnosticCoherent));
        std::fflush(stderr);
    }
    Hooks hooks_;
    State state_ = State::Held; // Pair never starts on an assumed VGA geometry.
    uint32_t high_, count_ = 0;
    uint64_t lastAdvance_ = 0, began_ = 0;
    bool countSeen_ = false, advanced_ = false, legacyAttempted_ = false, automaticBlocked_ = false;
    bool continuityRequired_=false;
    bool rejectLogged_=false;
    uint64_t lastRejectLog_=0;
    uint32_t continuityCount_=0;
    unsigned stableCount_=0;
    runtime_camera::NativeDescriptor stableDescriptor_{};
    Observation lastObservation_{};
    bool confirmedLegacy_=false;
    Observation confirmedObservation_{};
    runtime_camera::NativeDescriptor committed_{}, pending_{};
    std::array<Geometry, 2> target_{};
    Tags stale_{};
    Tags currentTags_{};
    bool legacyBaselineQualified_=false;
    uint64_t lastWaitLog_=0;
    c5::Snapshot legacyMailbox_{};
    bool bootBaselineQualified_=false;
    uint32_t bootEpoch_=0;
    uint64_t bootBaselineAt_=0;
    Tags bootBaseline_{};
    const char* reason_ = "";
};
} // namespace physical_pair
