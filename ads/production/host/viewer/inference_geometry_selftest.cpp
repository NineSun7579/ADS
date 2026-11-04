#include "inference_geometry.h"
#include "hdmi_view.h"
#include "vision_types.h"
#include <cstdio>
#include <vector>

int tdm::runInferenceGeometrySelfTest() {
    int failures = 0;
    auto expect = [&](bool ok, const char *name) {
        std::fprintf(stderr, "%s %s\n", ok ? "[ok]" : "[FAIL]", name);
        failures += !ok;
    };
    InferenceGeometry square, rectangular;
    rknn_tensor_attr attr{};
    attr.n_dims = 4; attr.fmt = RKNN_TENSOR_NHWC;
    attr.dims[0] = 1; attr.dims[1] = 480; attr.dims[2] = 640; attr.dims[3] = 3;
    expect(queryInputGeometry(attr, rectangular) && rectangular.rgbBytes() == 921600 &&
           rectangular.canonicalTop() == 80, "RKNN NHWC rectangular dimensions set exact byte count and crop");
    attr.fmt = RKNN_TENSOR_NCHW;
    attr.dims[1] = 3; attr.dims[2] = 640; attr.dims[3] = 640;
    expect(queryInputGeometry(attr, square) && square.rgbBytes() == 1228800 && square.canonicalTop() == 0,
           "RKNN NCHW square dimensions preserve legacy geometry");
    attr.dims[2] = 480;
    InferenceGeometry nchw;
    expect(queryInputGeometry(attr, nchw) && nchw.height == 480, "NCHW rectangular input is also understood");
    attr.dims[1] = 1;
    expect(!queryInputGeometry(attr, nchw), "non RGB input fails closed");
    attr.dims[1] = 3; attr.dims[2] = 320;
    expect(!queryInputGeometry(attr, nchw), "unsupported network height fails closed");
    attr.dims[2] = 480; attr.dims[0] = 2;
    expect(!queryInputGeometry(attr, nchw), "batch greater than one fails closed");
    attr.dims[0] = 1; attr.fmt = RKNN_TENSOR_UNDEFINED;
    expect(!queryInputGeometry(attr, nchw), "unknown tensor format fails closed");

    // External RGB buffers deliberately include extra row bytes. This catches
    // the old raw fallback's implicit tightly-packed assumption.
    const int stride = 640 * 3 + 16;
    QByteArray storage(stride * 480, char(0x7e));
    QImage raw(reinterpret_cast<uchar *>(storage.data()), 640, 480, stride, QImage::Format_RGB888);
    for (int y = 0; y < 480; ++y)
        for (int x = 0; x < 640; ++x) {
            uchar *p = raw.scanLine(y) + x * 3;
            p[0] = uchar(x % 251); p[1] = uchar(y % 251); p[2] = uchar((x + y) % 251);
        }
    const QImage canonical = networkRgbFrame(raw, square);
    const QImage crop = networkRgbFrame(canonical, rectangular);
    const QImage fallback = networkRgbFrame(raw, rectangular);
    bool identical = !crop.isNull() && !fallback.isNull() && crop.size() == QSize(640, 480);
    for (int y = 0; identical && y < 480; ++y)
        identical = std::memcmp(crop.constScanLine(y), raw.constScanLine(y), 640 * 3) == 0 &&
                    std::memcmp(fallback.constScanLine(y), raw.constScanLine(y), 640 * 3) == 0;
    expect(identical, "canonical crop and raw fallback preserve every RGB pixel without resize");
    expect(canonical.pixelColor(0, 79).red() == 114 && canonical.pixelColor(0, 560).red() == 114 &&
           canonical.pixelColor(77, 80) == raw.pixelColor(77, 0) &&
           canonical.pixelColor(77, 559) == raw.pixelColor(77, 479), "square models retain exactly 80 gray rows each side");
    const QImage unchanged = networkRgbFrame(canonical, square);
    expect(unchanged.constBits() == canonical.constBits(), "square RGB fast path keeps shared image buffer");
    const QImage converted = networkRgbFrame(canonical.convertToFormat(QImage::Format_RGB32), rectangular);
    expect(converted == crop, "non RGB888 canonical frames convert then crop correctly");
    expect(networkRgbFrame(QImage(320, 240, QImage::Format_RGB888), rectangular).isNull() &&
           networkRgbFrame({}, square).isNull(), "unexpected source geometry and empty frames fail closed");

    std::vector<Detection> detections(1);
    detections[0].x1 = 300; detections[0].x2 = 340;
    detections[0].y1 = 90; detections[0].y2 = 270;
    restoreCanonicalDetections(detections, rectangular);
    expect(detections[0].y1 == 170 && detections[0].y2 == 350 &&
           detections[0].x1 == 300 && detections[0].x2 == 340,
           "emission restores y+80 exactly once and leaves x unchanged");
    expect(detections[0].y1 - 80 == 90, "camera viewer subtracts canonical 80 to recover capture y");
    restoreCanonicalDetections(detections, square);
    expect(detections[0].y1 == 170, "square model restoration is identity");

    QImage left(320, 240, QImage::Format_RGB16), right(320, 240, QImage::Format_RGB16);
    left.fill(Qt::red); right.fill(Qt::blue);
    const QImage hdmi = hdmiAnalyticsImage(
        QByteArray(reinterpret_cast<const char *>(left.constBits()), left.sizeInBytes()),
        QByteArray(reinterpret_cast<const char *>(right.constBits()), right.sizeInBytes()));
    const QImage hdmiCanonical = networkRgbFrame(hdmi, square);
    const QImage hdmiNetwork = networkRgbFrame(hdmiCanonical, rectangular);
    expect(hdmiNetwork == hdmi && hdmiNetwork.pixelColor(0,119)==QColor(114,114,114) &&
           hdmiNetwork.pixelColor(319,120).red()>240 && hdmiNetwork.pixelColor(320,359).blue()>240 &&
           hdmiNetwork.pixelColor(639,360)==QColor(114,114,114),
           "C3/C4 320x240 pair keeps exactly 120 network padding rows");
    detections[0].x1=40;detections[0].x2=80;
    detections[0].y1=210;detections[0].y2=260;
    restoreCanonicalDetections(detections,rectangular);
    const QRectF display(detections[0].x1*2,(detections[0].y1-hdmiModelPad)*2,
                         (detections[0].x2-detections[0].x1)*2,(detections[0].y2-detections[0].y1)*2);
    expect(display==QRectF(80,180,80,100),
           "200 percent display removes canonical80 and network120 padding then doubles both coordinates");
    std::fprintf(stderr, failures ? "INFERENCE_GEOMETRY_SELFTEST_FAIL\n" : "INFERENCE_GEOMETRY_SELFTEST_PASS\n");
    return failures ? 2 : 0;
}
