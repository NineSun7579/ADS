#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

// Derived display data only. These directions are NOT physical camera IDs.
namespace hdmi_fisheye {
constexpr int width=1280, height=960, cropWidth=640, cropHeight=480;
constexpr uint32_t magic=0x32465348u; // HSF2, private versioned boundary
constexpr size_t headerBytes=64, pixelBytes=size_t(width)*height*3;
constexpr int64_t maxSkewMs=80;
constexpr const char* path="/dev/shm/ads-hdmi-fisheye-v2";
struct Pair {
    uint64_t leftSequence=0,rightSequence=0,leftEpoch=0,rightEpoch=0;
    int64_t leftMs=0,rightMs=0,sourceGeneration=0;
    bool native960=false,current=false;
};
inline bool fresh(const Pair& pair,int64_t now) {
    const int64_t skew=pair.leftMs>pair.rightMs?pair.leftMs-pair.rightMs:pair.rightMs-pair.leftMs;
    return pair.native960 && pair.current && pair.leftSequence && pair.rightSequence &&
        pair.leftEpoch && pair.rightEpoch && !(pair.leftEpoch&1u) && !(pair.rightEpoch&1u) &&
        pair.leftMs>0 && pair.rightMs>0 && now>=pair.leftMs && now>=pair.rightMs &&
        skew<=maxSkewMs;
}
inline bool sameEpoch(const Pair& left,const Pair& right) {
    return left.sourceGeneration==right.sourceGeneration && left.leftEpoch==right.leftEpoch &&
        left.rightEpoch==right.rightEpoch;
}
inline bool advances(const Pair& next,const Pair& previous) {
    return !sameEpoch(next,previous) ||
        (next.leftSequence>previous.leftSequence && next.rightSequence>previous.rightSequence);
}
// A rejected/duplicate candidate is not evidence that the accepted source died.
// Keep its original capture times until replacement or an actual source/epoch fence.
// This live display contract has no age deadline; native source health is owned upstream.
inline bool accept(const Pair& next,const Pair& previous,int64_t now) {
    return fresh(next,now) && advances(next,previous);
}
// Input transport is little-endian RGB565, irrespective of host byte order.
inline std::vector<uint8_t> joinRgb565(const uint8_t* left,size_t leftBytes,
                                     const uint8_t* right,size_t rightBytes) {
    constexpr size_t halfBytes=size_t(640)*960*2;
    if(!left || !right || leftBytes!=halfBytes || rightBytes!=halfBytes)return {};
    std::vector<uint8_t> output(pixelBytes);
    for(int y=0;y<height;++y)for(int x=0;x<width;++x) {
        const auto* input=(x<640?left:right)+(size_t(y)*640+(x%640))*2;
        const uint16_t value=uint16_t(input[0])|(uint16_t(input[1])<<8);
        auto* pixel=output.data()+(size_t(y)*width+x)*3;
        const unsigned red=(value>>11)&31,green=(value>>5)&63,blue=value&31;
        pixel[0]=uint8_t((red<<3)|(red>>2));pixel[1]=uint8_t((green<<2)|(green>>4));
        pixel[2]=uint8_t((blue<<3)|(blue>>2));
    }
    return output;
}
struct Region {int x,y;};
constexpr std::array<Region,4> regions{{{0,0},{640,0},{0,480},{640,480}}}; // front/back/left/right
inline void put32(uint8_t* output,uint32_t value){for(int i=0;i<4;++i)output[i]=uint8_t(value>>(i*8));}
inline void put64(uint8_t* output,uint64_t value){for(int i=0;i<8;++i)output[i]=uint8_t(value>>(i*8));}
inline std::array<uint8_t,headerBytes> header(const Pair& pair,uint64_t sequence) {
    std::array<uint8_t,headerBytes> output{};
    put32(output.data(),magic);put32(output.data()+4,2);put32(output.data()+8,width);put32(output.data()+12,height);
    put64(output.data()+16,sequence);put64(output.data()+24,uint64_t(pair.leftMs<pair.rightMs?pair.leftMs:pair.rightMs));
    put64(output.data()+32,uint64_t(pair.sourceGeneration));put64(output.data()+40,pair.leftEpoch);
    put64(output.data()+48,pair.rightEpoch);put64(output.data()+56,888);
    return output;
}
}
