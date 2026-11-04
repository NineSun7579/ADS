#include "four_fair.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
int main() {
    for(unsigned ready=1;ready<16;++ready) {
        FourFair fair;unsigned models[4][2]{};
        for(int n=0;n<800;++n) {
            const int i=fair.choose(ready);assert(i>=0 && (ready&(1u<<i)));
            ++models[i][n%2];fair.commit(i);
            uint64_t lo=800,hi=0;
            for(int c=0;c<4;++c)if(ready&(1u<<c)){lo=std::min(lo,fair.issued[c]);hi=std::max(hi,fair.issued[c]);}
            assert(hi-lo<=1);
        }
        for(int c=0;c<4;++c)if(ready&(1u<<c))assert(models[c][0]>0 && models[c][1]>0);
        assert(fair.choose(0)==-1);
    }
    FourFair fair;
    for(int n=0;n<200;++n){const int i=fair.choose(7);fair.commit(i);}
    for(int n=0;n<200;++n){const int i=fair.choose(15);fair.commit(i);}
    const auto mm=std::minmax_element(fair.issued.begin(),fair.issued.end());assert(*mm.second-*mm.first<=1);
    std::puts("four-fair PASS: all 15 availability masks, bounded skew, both alternating models, disconnect/rejoin, empty input");
}
