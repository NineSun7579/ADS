#pragma once
#include <QImage>
#include <cstring>
#include "rknn_api.h"

namespace tdm {
// Producers and every viewer/analytics consumer use a canonical 640-square.
// A rectangular network sees its central 480 rows, without scaling content.
struct InferenceGeometry {
    int width = 640;
    int height = 640;
    int canonicalTop() const { return (640 - height) / 2; }
    int rgbBytes() const { return width * height * 3; }
    float canonicalY(float networkY) const { return networkY + canonicalTop(); }
};

inline bool queryInputGeometry(const rknn_tensor_attr &attr, InferenceGeometry &geometry) {
    if (attr.n_dims != 4 || attr.dims[0] != 1) return false;
    int w = 0, h = 0, c = 0;
    if (attr.fmt == RKNN_TENSOR_NHWC) {
        h = attr.dims[1]; w = attr.dims[2]; c = attr.dims[3];
    } else if (attr.fmt == RKNN_TENSOR_NCHW) {
        c = attr.dims[1]; h = attr.dims[2]; w = attr.dims[3];
    } else return false;
    if (w != 640 || (h != 640 && h != 480) || c != 3) return false;
    geometry.width = w; geometry.height = h;
    return true;
}

inline QImage networkRgbFrame(const QImage &src, const InferenceGeometry &geometry) {
    if (src.isNull() || src.width() != 640 ||
        (src.height() != 480 && src.height() != 640) ||
        geometry.width != 640 || (geometry.height != 480 && geometry.height != 640)) return {};
    const QImage rgb = src.format() == QImage::Format_RGB888
        ? src : src.convertToFormat(QImage::Format_RGB888);
    if (src.height() == geometry.height) return rgb;
    if (src.height() == 640) return rgb.copy(0, geometry.canonicalTop(), 640, 480);
    // Raw 640x480 fallback: the inverse of the crop, with no resize. Respect
    // QImage row stride (external RGB888 images need not be tightly packed).
    QImage canonical(640, 640, QImage::Format_RGB888);
    canonical.fill(qRgb(114, 114, 114));
    for (int y = 0; y < 480; ++y)
        std::memcpy(canonical.scanLine(y + 80), rgb.constScanLine(y), 640 * 3);
    return canonical;
}

template<class Detections>
inline void restoreCanonicalDetections(Detections &detections, const InferenceGeometry &geometry) {
    for (auto &d : detections) {
        d.y1 = geometry.canonicalY(d.y1);
        d.y2 = geometry.canonicalY(d.y2);
    }
}

int runInferenceGeometrySelfTest();
} // namespace tdm
