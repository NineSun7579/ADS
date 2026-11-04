#pragma once
#include <functional>
#include <memory>
#include <atomic>
#include "vision_pipeline.h"

// Copies share the slot: camera workers keep observing GUI replacements.
class VisionSinkSlot {
    using Fn=std::function<void(const VisionFrame&)>;
    struct State {std::shared_ptr<const Fn> callback;};
    std::shared_ptr<State> state=std::make_shared<State>();
public:
    VisionSinkSlot()=default;
    VisionSinkSlot& operator=(Fn fn){
        std::shared_ptr<const Fn> next;
        if(fn)next=std::make_shared<const Fn>(std::move(fn));
        std::atomic_store(&state->callback,std::move(next));return *this;
    }
    explicit operator bool()const{return bool(std::atomic_load(&state->callback));}
    void operator()(const VisionFrame& frame)const{
        const auto fn=std::atomic_load(&state->callback);if(fn)(*fn)(frame);
        else if(frame.fpgaInput)frame.fpgaInput->complete();
    }
};
