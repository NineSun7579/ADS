#pragma once

#include <QImage>
#include <QPointF>
#include <QString>
#include <QtGlobal>
#include <array>
#include <memory>

namespace surround {

constexpr int CameraCount = 6;
constexpr int SourceWidth = 640;
constexpr int SourceHeight = 480;
constexpr int HdSourceWidth = 1280;
constexpr int HdSourceHeight = 720;
constexpr bool avmUsesHd(int cameraIndex) {
    return cameraIndex == 0 || cameraIndex == 2 || cameraIndex == 3 || cameraIndex == 4;
}
// VGA calibration coordinates -> native OV5640 720P sensor window. This is
// the same geometry as the proven C1 bird LUT derivation, not image stretching.
QPointF avmHdPoint(const QPointF &point);
int avmSourceWidth(bool hd = false);
int avmSourceHeight(bool hd = false);

enum class LensModel { Pinhole, Fisheye };
enum class ViewMode { Panorama, Birdseye };

struct CameraCalibration {
    int id = 1; // Stable physical identity: C1..C6, never reordered by yaw.
    double yawDeg = 0.0; // Positive yaw points right; zero is forward.
    double pitchDeg = 0.0; // Positive pitch points up.
    double rollDeg = 0.0;
    double hfovDeg = 110.0;
    LensModel lens = LensModel::Pinhole;
    std::array<double, 9> K{{0, 0, 0, 0, 0, 0, 0, 0, 1}};
    // OpenCV order. Pinhole accepts 4/5/8 coefficients; fisheye uses 4.
    std::array<double, 8> D{};
    int distortionCount = 4;
    bool intrinsicCalibrated = false;
    bool yawCalibrated = false;
    bool groundCalibrated = false;
    // Fitted visual correction, including borrowed opposite-direction quads.
    // This enables the warp without claiming measured ground or lens calibration.
    bool groundPreviewEnabled = false;
    // TL, TR, BR, BL in the rectified 640x480 image and bird output pixels.
    // Generated illustrative quads are used when neither ground flag is enabled.
    std::array<QPointF, 4> groundSrc{};
    std::array<QPointF, 4> groundDst{};
    // OV5640 fixed-focus modules often show barrel distortion before a full
    // K/D calibration is available. This single radial k1 preview is deliberately
    // approximate: it uses hfov-estimated K with this k1 only, and it never
    // marks the camera calibrated. Fisheye preview uses k1 as its first
    // equidistant coefficient.
    bool distortionTuned = false;
    double k1Preview = 0.0;
};

struct Configuration {
    int version = 1;
    std::array<CameraCalibration, CameraCount> cameras;
    int panoramaWidth = 1536;
    int panoramaHeight = 480;
    int birdSize = 512;
    // Display-only raw bottom 30% (rows 336..479), stretched to the bird sector.
    // Stored lens/ground calibration and the logical 640x480 capture stay intact.
    bool birdBottomOnly = false;
    // Opt-in projection masks for the historical ground preview worker.
    bool birdTemporalGround = false;
    int birdHistoryMaxAgeMs = 2500; // Valid interval: 250..10000 ms.
    // Display-only outer boundary; fractions of the bird canvas half-side.
    bool birdCircular = true;
    double birdRadiusFraction = 0.80;
    double birdFeatherFraction = 0.12;
    bool birdFarStyle = true;
    double birdNearFraction = 0.45; // Protected near radius, fraction of canvas half-side.
    double birdFarStretch = 0.30;   // Radial display-only stretch, 0..0.45 (monotonic).
    double birdFarBlurPx = 3.0;     // Maximum blur sample offset in the bird texture.
    double verticalFovDeg = 70.0;
    bool exposureBalance = true;
    // Per-channel bounded seam gains for cameras with independent AWB (OV5640).
    // Display-side matching only; not a colorimetric calibration.
    bool colorBalance = true;
    // Bird overlays use pixel units until birdPixelsPerMeter is measured.
    // A measured scale with groundCalibrated enables metric grid labels.
    double footprintWidthPx = 50.0;
    double footprintLengthPx = 92.0;
    double gridSpacingPx = 64.0;
    double birdPixelsPerMeter = 0.0;
    qint64 freshMs = 250;
    qint64 staleMs = 1000;

    Configuration();
    bool validate(QString *error = nullptr) const;
    bool save(const QString &path, QString *error = nullptr) const;
    // Failure leaves out unchanged; missing files do not imply calibration.
    static bool load(const QString &path, Configuration &out, QString *error = nullptr);
};

struct FrameInput {
    std::array<QImage, CameraCount> images;
    // Monotonic milliseconds, from the same clock as nowMs. Zero is valid.
    std::array<qint64, CameraCount> capturedMs{};
    std::array<quint64, CameraCount> sequence{};
    std::array<quint64, CameraCount> generation{};
};

struct ProcessResult {
    QImage output; // Owned RGB888 pixels, safe after the next render.
    // Owned Grayscale8 masks, present only for birdTemporalGround bird renders.
    // Geometry/observations are 0 or 255 and ignore the display circle fade.
    QImage birdObservedMask; // Fresh valid selected samples with weight > 0.05.
    QImage birdGeometryMask; // Selected projected support, including dead cameras.
    QImage birdOwnerMask; // Dominant static weight: 1 front, 2 left, 3 right, 4 rear; 0 gap.
    QString status;
    std::array<bool, CameraCount> active{};
    // Projection choices, independent of the raw six-camera availability.
    std::array<bool, CameraCount> projectionSelected{{true, false, true, true, true, false}};
    std::array<qint64, CameraCount> ageMs{}; // -1 for missing/future/invalid input.
    qint64 captureSkewMs = 0;
    bool approximateGeometry = true;
};

class Engine {
public:
    explicit Engine(const Configuration &config = Configuration(),bool avmHd = false);
    ~Engine();
    Engine(const Engine &) = delete;
    Engine &operator=(const Engine &) = delete;
    const Configuration &config() const;
    // Builds maps before replacing the current valid configuration.
    bool setConfig(const Configuration &config, QString *error = nullptr);
    ProcessResult render(const FrameInput &frames, ViewMode mode, qint64 nowMs);
    ProcessResult composePanorama(const FrameInput &frames, qint64 nowMs);
    ProcessResult composeBird(const FrameInput &frames, qint64 nowMs);
    // Convenience entry points for capture/UI code with separate arrays.
    QImage panorama(const std::array<QImage, CameraCount> &images,
                    const std::array<qint64, CameraCount> &capturedMs, qint64 nowMs);
    QImage birdseye(const std::array<QImage, CameraCount> &images,
                   const std::array<qint64, CameraCount> &capturedMs, qint64 nowMs);

private:
    struct Impl;
    std::unique_ptr<Impl> d;
    bool avmHd_ = false;
};

// CPU only; no QApplication, window, capture device or board required.
int runEngineSelfTest();

} // namespace surround
