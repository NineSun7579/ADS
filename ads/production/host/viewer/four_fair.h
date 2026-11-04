#pragma once
#include <array>
#include <cstdint>
// Least-served ready channel, rotating ties. Move the tie origin once per
// complete four-job round to avoid aliasing two rotating models to even cameras.
struct FourFair {
    static constexpr std::array<int,4> cameras{{0,2,3,4}};
    std::array<uint64_t,4> issued{};
    unsigned cursor=0, total=0;
    int choose(unsigned ready) const {
        int best=-1;
        for(unsigned n=0;n<4;++n) {
            const unsigned i=(cursor+n)%4;
            if((ready&(1u<<i)) && (best<0 || issued[i]<issued[best])) best=int(i);
        }
        return best;
    }
    void commit(int i) {
        ++issued[i]; ++total; cursor=(unsigned(i)+(total%4==0?0:1))%4;
    }
};
