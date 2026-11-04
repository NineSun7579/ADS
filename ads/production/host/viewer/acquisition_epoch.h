#pragma once
#include <array>
#include <atomic>
#include <cstdint>
#include <limits>
#include <map>
#include <mutex>
#include <utility>

// Separate from the global UI sourceGeneration. Odd states are fenced; even
// states are running. A producer snapshots ONCE per worker run, never at reply.
namespace acquisition {
struct Ticket {
    unsigned mask = 0, metricUnsafeMask = 0;
    std::array<uint64_t,6> epochs{};
};
class Registry {
    std::array<std::atomic<uint64_t>,6> epochs_{{2,2,2,2,2,2}};
public:
    Ticket snapshot(unsigned mask, bool native = false) const {
        Ticket out;out.mask=mask;out.metricUnsafeMask=native?mask:0;
        for(unsigned camera=0;camera<6;++camera) if(mask&(1u<<camera))out.epochs[camera]=epochs_[camera].load();
        return out;
    }
    bool current(const Ticket& ticket) const {
        if(ticket.mask&~0x3fu)return false;
        for(unsigned camera=0;camera<6;++camera)if(ticket.mask&(1u<<camera)) {
            const auto value=ticket.epochs[camera];
            if(!value||(value&1u)||value!=epochs_[camera].load())return false;
        }
        return true;
    }
    // Owner-thread only writes; never wrap exhaustion into an old valid token.
    bool fence(unsigned mask) {
        for(unsigned camera=0;camera<6;++camera)if(mask&(1u<<camera)) {
            auto value=epochs_[camera].load();
            if(!(value&1u))epochs_[camera].store(value+1);
        }
        return true;
    }
    bool activate(unsigned mask) {
        for(unsigned camera=0;camera<6;++camera)if(mask&(1u<<camera))
            if(epochs_[camera].load()==std::numeric_limits<uint64_t>::max())return false;
        for(unsigned camera=0;camera<6;++camera)if(mask&(1u<<camera)) {
            const auto value=epochs_[camera].load();if(value&1u)epochs_[camera].store(value+1);
        }
        return true;
    }
};
inline Registry& registry(){static Registry value;return value;}
inline bool current(const Ticket& value){return registry().current(value);}
inline Ticket combine(const Ticket& left,const Ticket& right) {
    Ticket out=left;out.mask|=right.mask;out.metricUnsafeMask|=right.metricUnsafeMask;
    for(unsigned camera=0;camera<6;++camera)if(right.mask&(1u<<camera)) {
        if((left.mask&(1u<<camera))&&left.epochs[camera]!=right.epochs[camera])out.epochs[camera]=0;
        else out.epochs[camera]=right.epochs[camera];
    }
    return out;
}
inline bool metricAllowed(const Ticket& ticket){return current(ticket)&&!ticket.metricUnsafeMask;}

// Raw NPU signals retain their existing ABI. Their identity joins this bounded
// immutable producer ledger; missing/evicted identity FAILS CLOSED, never stamped
// using today's selected camera. Frame IDs are globally monotonic in CameraThread.
class Ledger {
    std::mutex mutex_;
    std::map<std::pair<int,uint64_t>,Ticket> tickets_;
public:
    bool bind(int generation,uint64_t frame,const Ticket& ticket) {
        std::lock_guard<std::mutex> lock(mutex_);
        if(!current(ticket))return false;
        const auto inserted=tickets_.emplace(std::make_pair(generation,frame),ticket);
        if(!inserted.second)return false; // never relabel/rebind an existing ID
        while(tickets_.size()>4096)tickets_.erase(tickets_.begin());
        return true;
    }
    bool live(int generation,uint64_t frame) {
        std::lock_guard<std::mutex> lock(mutex_);
        const auto found=tickets_.find({generation,frame});
        return found!=tickets_.end()&&current(found->second);
    }
    Ticket ticket(int generation,uint64_t frame) {
        std::lock_guard<std::mutex> lock(mutex_);
        const auto found=tickets_.find({generation,frame});
        if(found!=tickets_.end())return found->second;
        Ticket invalid;invalid.mask=0x40;return invalid;
    }
};
inline Ledger& ledger(){static Ledger value;return value;}
} // namespace acquisition
