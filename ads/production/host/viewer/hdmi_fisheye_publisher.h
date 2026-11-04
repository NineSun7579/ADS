#pragma once
#include "hdmi_fisheye_contract.h"
#include <fcntl.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

namespace hdmi_fisheye {
// One GUI-side publisher of already acquired pairs. Never opens DMA/camera devices.
// flock protects the complete header+pixels transaction; the Python consumer
// takes LOCK_SH for its copy. An independent lifetime lock rejects a second ADS owner.
class Publisher {
    int fd_=-1,owner_=-1;
    uint64_t sequence_=0;
    static bool writeAll(int fd,const uint8_t* data,size_t bytes,off_t offset) {
        while(bytes){const auto count=pwrite(fd,data,bytes,offset);if(count<=0)return false;
            data+=count;bytes-=size_t(count);offset+=count;}return true;
    }
public:
    Publisher()=default;
    Publisher(const Publisher&)=delete;
    Publisher& operator=(const Publisher&)=delete;
    ~Publisher(){invalidate();if(fd_>=0)close(fd_);if(owner_>=0)close(owner_);}
    bool open() {
        if(fd_>=0)return true;
        owner_=::open("/dev/shm/ads-hdmi-fisheye-v2.owner",O_CREAT|O_RDWR|O_CLOEXEC|O_NOFOLLOW,0600);
        if(owner_<0)return false;
        if(flock(owner_,LOCK_EX|LOCK_NB)!=0){close(owner_);owner_=-1;return false;}
        fd_=::open(path,O_CREAT|O_RDWR|O_CLOEXEC|O_NOFOLLOW,0600);
        if(fd_<0){close(owner_);owner_=-1;return false;}
        if(ftruncate(fd_,headerBytes+pixelBytes)!=0){close(fd_);fd_=-1;close(owner_);owner_=-1;return false;}
        invalidate();return true;
    }
    void invalidate() {
        if(fd_<0 || flock(fd_,LOCK_EX)!=0)return;
        const std::array<uint8_t,headerBytes> empty{};writeAll(fd_,empty.data(),empty.size(),0);
        flock(fd_,LOCK_UN);
    }
    bool publish(const std::vector<uint8_t>& pixels,const Pair& pair,int64_t now) {
        if(pixels.size()!=pixelBytes || !fresh(pair,now) || !open())return false;
        if(flock(fd_,LOCK_EX)!=0)return false;
        const auto metadata=header(pair,++sequence_);
        // Reader holds the same lock, so no magic-before-copy or unchecked memcpy race.
        const bool ok=writeAll(fd_,pixels.data(),pixels.size(),headerBytes) &&
            writeAll(fd_,metadata.data(),metadata.size(),0);
        if(!ok){const std::array<uint8_t,headerBytes> empty{};writeAll(fd_,empty.data(),empty.size(),0);}
        flock(fd_,LOCK_UN);return ok;
    }
};
}
