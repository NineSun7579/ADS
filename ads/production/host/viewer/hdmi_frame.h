#pragma once
#include <QByteArray>
#include <QImage>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cstdint>
#include <cstring>

namespace surround {
constexpr const char *framePath = "/surround-hdmi-frame";
constexpr int frameWidth = 640;
constexpr int frameHeight = 240;
constexpr uint32_t frameMagic = 0x53484431;
struct FrameHeader {
    uint32_t magic;
    uint32_t width;
    uint32_t height;
    uint64_t sequence;
    int64_t capturedMs;
    uint32_t format;
    uint32_t reserved;
};

inline void publishHdmiFrame(const QImage &source, qint64 capturedMs) {
    static int fd = -1;
    static FrameHeader *header = nullptr;
    static uchar *pixels = nullptr;
    static uint64_t sequence = 0;
    if (fd < 0) {
        fd = shm_open(framePath, O_CREAT | O_RDWR, 0600);
        if (fd < 0) return;
        if (ftruncate(fd, sizeof(FrameHeader) + frameWidth * frameHeight * 3) != 0) { close(fd); fd = -1; return; }
        void *memory = mmap(nullptr, sizeof(FrameHeader) + frameWidth * frameHeight * 3, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (memory == MAP_FAILED) { close(fd); fd = -1; return; }
        header = static_cast<FrameHeader *>(memory);
        pixels = static_cast<uchar *>(memory) + sizeof(FrameHeader);
        *header = {};
    }
    QImage image = source;
    if (image.width() != frameWidth || image.height() != frameHeight)
        image = source.copy(0, 120, frameWidth, frameHeight);
    if (image.format() != QImage::Format_RGB888) image = image.convertToFormat(QImage::Format_RGB888);
    if (image.isNull()) return;
    header->magic = 0;
    header->width = frameWidth;
    header->height = frameHeight;
    header->capturedMs = capturedMs;
    header->format = 888;
    for (int y = 0; y < frameHeight; ++y)
        std::memcpy(pixels + y * frameWidth * 3, image.constScanLine(y), frameWidth * 3);
    __sync_synchronize();
    header->sequence = ++sequence;
    __sync_synchronize();
    header->magic = frameMagic;
}
}
