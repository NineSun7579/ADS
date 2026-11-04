#pragma once
#include <array>
#include <cstdint>
namespace motion {
constexpr uint32_t Selector=0x20000800u, Data=0x20000810u, Generation=0x20000820u;
constexpr uint32_t MagicAddress=0x20000830u, GeometryAddress=0x20000840u;
constexpr uint32_t Magic=0x4d4f5431u, Geometry=(480u<<16)|640u, Scratch=0x3fe000u;
constexpr unsigned WordCount=10;
constexpr unsigned SupportedCameras=4; // Six ABI slots remain; slots 4/5 are reserved zero records.
struct Record {
    bool reservedInvalid=false;
    uint32_t seq=0, generation=0;
    bool referenceValid=false, bboxValid=false, error=false;
    unsigned blocks=0, samples=0, minX=0, maxX=0, minY=0, maxY=0;
    std::array<uint32_t,6> bitmap{};
};
struct Snapshot { Record record; bool have=false, failed=false; };
inline uint32_t selector(unsigned camera, unsigned word, bool capture) {
    return (camera<<8)|word|(capture ? 0x80000000u : 0u);
}
inline Record decode(const std::array<uint32_t,WordCount> &w) {
    Record r; r.seq=w[0];
    r.reservedInvalid=(w[1]&~7u)||(w[2]&0xff000000u)||(w[3]&0xffff0000u);
    r.referenceValid=(w[1]&1u)!=0; r.bboxValid=(w[1]&2u)!=0; r.error=(w[1]&4u)!=0;
    r.blocks=w[2]&255u; r.samples=(w[2]>>8)&65535u;
    r.minX=w[3]&15u; r.maxX=(w[3]>>4)&15u; r.minY=(w[3]>>8)&15u; r.maxY=(w[3]>>12)&15u;
    for(unsigned i=0;i<6;++i) r.bitmap[i]=w[4+i];
    return r;
}
// Caller holds the device DMA mutex. Capture once, then read the frozen words.
// Publish only after all single-word reads and a stable generation.
template<class Write,class Read>
bool capture(unsigned camera, Record &out, Write write, Read read) {
    if(camera>=SupportedCameras || !write(Selector,selector(camera,0,true))) return false;
    uint32_t before=0,after=0;
    if(!read(Generation,before)) return false;
    std::array<uint32_t,WordCount> words{};
    for(unsigned i=0;i<WordCount;++i) {
        if(!write(Selector,selector(camera,i,false)) || !read(Data,words[i])) return false;
    }
    if(!read(Generation,after) || before!=after) return false;
    Record r=decode(words);
    // The bitmap is a 16x12 block grid. Reject malformed counts/coordinates;
    // raw words remain available to decode-only tests of reserved bit masks.
    if (r.blocks > 192 || r.samples > 19200 || (r.bboxValid &&
        (r.minX > r.maxX || r.minY > r.maxY || r.maxY >= 12))) return false;
    r.generation=after; out=r; return true;
}
}
