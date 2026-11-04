#pragma once
#include <cstring>
#include "paired_camera.h"
#include "camera_dma.h"

namespace cam34_pair {
// The transport fills detached storage synchronously under the DMA mutex shared
// by every RX user. Only the sequence word has ABI meaning; compare all 16 bytes
// for stability without inventing meanings for the remaining bytes.
using ReadBytes=std::function<bool(uint32_t,uint8_t*,uint32_t)>;
inline bool snapshotTags(const Geometry& g,const ReadBytes& read,Baseline& b) {
    if(!g.valid()) return false;
    Baseline candidate=b;
    for(int bank=0;bank<2;++bank) {
        std::array<uint8_t,16> first{},second{};
        if(!read(g.tagAddress(bank),first.data(),16) ||
           !read(g.tagAddress(bank),second.data(),16) || first!=second) return false;
        std::memcpy(&candidate.stale[bank],first.data(),4);
    }
    b=candidate;
    return true;
}
inline bool copyFresh(const Geometry& g,const Baseline& b,const ReadBytes& read,
                      std::vector<uint8_t>& pixels,Publication& publication) {
    if(!g.valid()) return false;
    std::array<std::array<uint8_t,16>,2> tags{};
    uint32_t seq[2]={};
    for(int bank=0;bank<2;++bank) {
        if(!read(g.tagAddress(bank),tags[bank].data(),16)) return false;
        std::memcpy(&seq[bank],tags[bank].data(),4);
    }
    const int bank=tdm::newerCameraTag(seq[0],seq[1])?0:1;
    if(!cam1_pair::freshTargetSequence(seq[bank],b.floor,b.stale[bank])) return false;
    std::vector<uint8_t> detached(g.transferBytes());
    std::array<uint8_t,16> after{};
    if(!read(g.bank(bank),detached.data(),g.transferBytes()) ||
       std::memcmp(detached.data()+g.tagOffset,tags[bank].data(),16)!=0 ||
       !read(g.tagAddress(bank),after.data(),16) || after!=tags[bank]) return false;
    std::vector<uint8_t> copied(g.pixelBytes);
    if(!tdm::copyCommittedCameraPixels(copied.data(),detached.data(),g.pixelBytes,seq[bank])) return false;
    pixels.swap(copied);
    publication={g.camera,bank,g.mode,g.generation,seq[bank],g.pixelBytes,true};
    return true;
}
}
