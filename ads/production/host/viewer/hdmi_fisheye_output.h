#pragma once
#include <cstddef>
#include <cstdint>

namespace hdmi_fisheye_output {
constexpr int headerBytes = 64;
constexpr int frameBytes = 600 * 800 * 3;
constexpr int packetBytes = headerBytes + frameBytes;
inline uint64_t little(const unsigned char* bytes, int count) {
    uint64_t value = 0;
    for(int index=0;index<count;++index)value |= uint64_t(bytes[index]) << (8*index);
    return value;
}
struct Metadata {
    uint64_t sequence, capturedMs, generation, leftEpoch, rightEpoch;
};
inline bool decode(const unsigned char* bytes, Metadata& result) {
    if(little(bytes,4)!=0x33465348u || little(bytes+4,4)!=3 ||
       little(bytes+8,4)!=600 || little(bytes+12,4)!=800 || little(bytes+56,8)!=888)return false;
    result={little(bytes+16,8),little(bytes+24,8),little(bytes+32,8),
            little(bytes+40,8),little(bytes+48,8)};
    return result.sequence && result.capturedMs && result.leftEpoch && result.rightEpoch &&
        !(result.leftEpoch&1) && !(result.rightEpoch&1);
}
} // namespace hdmi_fisheye_output

#include <QImage>
#include <QObject>
#include <QTemporaryFile>
#include <sys/file.h>
#include <unistd.h>
#include <cerrno>

class HdmiFisheyeMailbox : public QObject {
public:
    explicit HdmiFisheyeMailbox(QObject* parent):QObject(parent),file("/dev/shm/ads-hdmi-output-XXXXXX") {}
    bool initialize() { return file.open() && file.resize(hdmi_fisheye_output::packetBytes); }
    QString path() const { return file.fileName(); }
    bool takeLatest(QImage& image,hdmi_fisheye_output::Metadata& metadata) {
        if(::flock(file.handle(),LOCK_SH|LOCK_NB)!=0)return false;
        bool accepted=false;
        unsigned char header[hdmi_fisheye_output::headerBytes];
        QByteArray pixels;
        // pread bypasses QFile's read-ahead cache: another process updates this
        // same inode in place, so cached header bytes must never be reused.
        if(readAt(reinterpret_cast<char*>(header),sizeof(header),0) &&
           hdmi_fisheye_output::decode(header,metadata) && metadata.sequence>lastSequence) {
            pixels.resize(hdmi_fisheye_output::frameBytes);
            accepted=readAt(pixels.data(),pixels.size(),sizeof(header));
        }
        ::flock(file.handle(),LOCK_UN);
        if(accepted) {
            QImage frame(reinterpret_cast<const uchar*>(pixels.constData()),600,800,600*3,QImage::Format_BGR888);
            image=frame.copy();lastSequence=metadata.sequence;
        }
        return accepted;
    }
private:
    QTemporaryFile file;
    uint64_t lastSequence=0;
    bool readAt(char* bytes,size_t size,off_t offset) {
        size_t copied=0;
        while(copied<size) {
            const ssize_t count=::pread(file.handle(),bytes+copied,size-copied,offset+off_t(copied));
            if(count<0 && errno==EINTR)continue;
            if(count<=0)return false;
            copied+=size_t(count);
        }
        return true;
    }
};
