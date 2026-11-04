#pragma once
#include "host_motion_abi.h"
#include "motion_policy.h"
#include "runtime_camera_geometry.h"

namespace integrated_motion {
struct Record {
    motion::Record hint;
    uint32_t rawTag=0, transportGeometry=0, pixelBytes=0, capabilities=0, banks=0, epoch=0;
};
// All probes are read-only and precede every selector write on a new binding.
template<class Read> bool probe(Read read) {
    for (const auto& pair : {
        std::pair<uint32_t,uint32_t>{CAM134_MOTION_MAGIC_ADDR,CAM134_MOTION_MAGIC},
        {CAM134_MOTION_GEOMETRY_ADDR,CAM134_MOTION_GEOMETRY},
        {CAM134_MOTION_CONFIG_ADDR,CAM134_MOTION_CONFIG},
        {CAM134_MOTION_EXTENSION_ADDR,CAM134_MOTION_EXTENSION}}) {
        uint32_t value=0;
        if (!read(pair.first,value) || value!=pair.second) return false;
    }
    return true;
}
template<class Write,class Read>
bool capture(unsigned camera, Record& output, Write write, Read read) {
    if (camera>=6 || !write(CAM134_MOTION_SELECTOR,motion::selector(camera,0,true))) return false;
    uint32_t before=0,after=0;
    if (!read(CAM134_MOTION_GENERATION,before)) return false;
    std::array<uint32_t,CAM134_MOTION_WORDS> words{};
    for (unsigned i=0;i<words.size();++i)
        if (!write(CAM134_MOTION_SELECTOR,motion::selector(camera,i,false)) ||
            !read(CAM134_MOTION_DATA,words[i])) return false;
    if (!read(CAM134_MOTION_GENERATION,after) || before!=after) return false;
    std::array<uint32_t,motion::WordCount> legacy{};
    std::copy_n(words.begin(),legacy.size(),legacy.begin());
    Record next;
    next.hint=motion::decode(legacy); next.hint.generation=after;
    next.rawTag=words[10]; next.transportGeometry=words[11]; next.pixelBytes=words[12];
    next.capabilities=words[13]; next.banks=words[14]; next.epoch=words[15];
    if (!motion::consistent(next.hint) || (next.capabilities&~15u) || (next.banks&~3u)) return false;
    output=next;
    return true;
}
// Version1 advertises SAME_RAW_FRAME=0. Reject any unexpected association bit;
// RAW tag and source-start sequence must never be compared for identity.
inline bool usable(const Record& record,const runtime_camera::Geometry& geometry) {
    return geometry.valid() && geometry.camera<4 &&
        geometry.mode==runtime_camera::Mode::Default && record.capabilities==CAM134_MOTION_AVAILABLE &&
        record.transportGeometry==(geometry.width<<16|geometry.height) &&
        record.pixelBytes==geometry.pixelBytes;
}
class Observer {
public:
    motion::Observer legacy;
    uint32_t epoch=0;
    uint64_t geometryGeneration=0;
    bool bound=false;
    motion::Evidence observe(const Record& record,const runtime_camera::Geometry& geometry,
                             int64_t now,int sourceGeneration) {
        if (!bound || epoch!=record.epoch || geometryGeneration!=geometry.generation ||
            legacy.evidence.sourceGeneration!=sourceGeneration) {
            legacy.reset(sourceGeneration); epoch=record.epoch;
            geometryGeneration=geometry.generation; bound=true;
        }
        if (!usable(record,geometry)) {
            // Never allow an unavailable interval to preserve a static freshness floor.
            legacy.reset(sourceGeneration); legacy.failure(); return legacy.evidence;
        }
        legacy.observe(record.hint,now,sourceGeneration);
        return legacy.evidence;
    }
};
}
