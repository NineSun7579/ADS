#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>

// Presentation only: timestamps always refer to original acquisition, never paint.
namespace range_display {
class Filter {
    struct Sample { double meters; std::int64_t captured; };
    std::array<Sample,3> samples_{};
    unsigned count_=0;
    std::int64_t latest_=-1;
    double displayed_=-1;
    void prune(std::int64_t now) {
        unsigned kept=0;
        for(unsigned i=0;i<count_;++i)
            if(now>=samples_[i].captured && now-samples_[i].captured<=500)
                samples_[kept++]=samples_[i];
        count_=kept;
    }
public:
    void reset() { count_=0;latest_=-1;displayed_=-1; }
    double value(std::int64_t now) {
        if(latest_<=0 || now<latest_ || now-latest_>500) { reset();return -1; }
        prune(now);
        return displayed_;
    }
    void observe(double meters,std::int64_t captured,std::int64_t now,bool usable) {
        if(!usable || !std::isfinite(meters) || meters<=0 || captured<=0 ||
           now<captured || now-captured>500) { reset();return; }
        if(latest_>0 && (now<latest_ || now-latest_>500))reset();
        // Repeated paints/results for the same original capture are not evidence.
        if(captured<=latest_)return;
        prune(now);
        // A real step must show on this sample, not wait for median history.
        const bool step=displayed_>0 && std::abs(meters-displayed_)>0.3;
        if(step)count_=0;
        if(count_==3) { samples_[0]=samples_[1];samples_[1]=samples_[2];--count_; }
        samples_[count_++]={meters,captured};latest_=captured;
        std::array<double,3> sorted{};
        for(unsigned i=0;i<count_;++i)sorted[i]=samples_[i].meters;
        std::sort(sorted.begin(),sorted.begin()+count_);
        const double median=count_==2?(sorted[0]+sorted[1])/2:sorted[count_/2];
        // 65 mm from the displayed decimetre: 0.24/0.26 cannot toggle 0.2/0.3.
        if(displayed_<0 || step || std::abs(median-std::round(displayed_*10)/10)>=0.065)
            displayed_=median;
    }
};
} // namespace range_display
