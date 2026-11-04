#include "surround_engine.h"
#include "bird_boundary.h"
#include "stereo_selection.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QSaveFile>
#include <QStringList>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <vector>

namespace surround {
QPointF avmHdPoint(const QPointF &point) {
    const double hx=(point.x()+.5)*(2624.0/640.0)*1280.0/2624.0-.5;
    const double hy=(4.0+(point.y()+.5)*(1944.0/480.0)-250.0)*720.0/1456.0-.5;
    return QPointF(hx,hy);
}
int avmSourceWidth(bool hd) { return hd?HdSourceWidth:SourceWidth; }
int avmSourceHeight(bool hd) { return hd?HdSourceHeight:SourceHeight; }
namespace {
constexpr double Pi = 3.14159265358979323846;
double radians(double degrees) { return degrees * Pi / 180.0; }
bool fail(QString *error, const QString &message) {
    if (error) *error = message;
    return false;
}

std::array<QPointF, 4> defaultSource() {
    return {{QPointF(128, 280), QPointF(512, 280), QPointF(630, 475), QPointF(10, 475)}};
}
std::array<QPointF, 4> bottomSource() {
    return {{QPointF(0, 336), QPointF(639, 336), QPointF(639, 479), QPointF(0, 479)}};
}
std::array<QPointF, 4> defaultDestination(double yaw, int size) {
    // Four directional modules need quadrant-sized support. Slight overlap
    // around the diagonal leaves room for feathering; these remain explicitly
    // illustrative ground coordinates until measured control points exist.
    const std::array<QPointF, 4> local{{QPointF(-205, -205), QPointF(205, -205),
                                     QPointF(80, -65), QPointF(-80, -65)}};
    std::array<QPointF, 4> result;
    const double c = std::cos(radians(yaw)), s = std::sin(radians(yaw));
    const double scale = size / 512.0;
    for (int i = 0; i < 4; ++i)
        result[i] = QPointF(size * .5 + scale * (c * local[i].x() - s * local[i].y()),
                            size * .5 + scale * (s * local[i].x() + c * local[i].y()));
    return result;
}

bool validQuad(const std::array<QPointF, 4> &quad, int width, int height) {
    double winding = 0;
    for (int i = 0; i < 4; ++i) {
        const QPointF a = quad[i], b = quad[(i + 1) % 4], c = quad[(i + 2) % 4];
        if (!std::isfinite(a.x()) || !std::isfinite(a.y()) || a.x() < 0 || a.y() < 0 ||
            a.x() > width - 1 || a.y() > height - 1) return false;
        const double cross = (b.x() - a.x()) * (c.y() - b.y()) -
                             (b.y() - a.y()) * (c.x() - b.x());
        if (std::abs(cross) < 1.0 || (i && cross * winding <= 0)) return false;
        winding = cross;
    }
    return true;
}

cv::Mat homography(const std::array<QPointF, 4> &src, const std::array<QPointF, 4> &dst) {
    cv::Point2f a[4], b[4];
    for (int i = 0; i < 4; ++i) {
        a[i] = cv::Point2f(float(src[i].x()), float(src[i].y()));
        b[i] = cv::Point2f(float(dst[i].x()), float(dst[i].y()));
    }
    return cv::getPerspectiveTransform(a, b);
}

struct Intrinsics { double fx, fy, skew, cx, cy; };
Intrinsics intrinsics(const CameraCalibration &cam,bool avmHd=false) {
    const double width=avmSourceWidth(avmHd),height=avmSourceHeight(avmHd);
    if (cam.intrinsicCalibrated) {
        const QPointF center=avmHd?avmHdPoint(QPointF(cam.K[2],cam.K[5])):QPointF(cam.K[2],cam.K[5]);
        const double scaleX=avmHd?2.0:1.0,scaleY=avmHd?720.0/1456.0*1944.0/480.0:1.0;
        return {cam.K[0]*scaleX,cam.K[4]*scaleY,cam.K[1]*scaleX,center.x(),center.y()};
    }
    const double fx = cam.lens == LensModel::Fisheye ? width / radians(cam.hfovDeg)
                         : width / (2.0 * std::tan(radians(cam.hfovDeg) * .5));
    return {fx, fx, 0, width * .5, height * .5};
}

// Maps a rectilinear camera ray to the original (possibly distorted) sensor.
// Brown-Conrady and OpenCV's equidistant model use OpenCV coefficient order.
cv::Point2d project(double x, double y, const CameraCalibration &cam, const Intrinsics &k) {
    const double r2 = x * x + y * y;
    if (cam.lens == LensModel::Fisheye) {
        const double r = std::sqrt(r2), theta = std::atan(r), t2 = theta * theta;
        double td = theta;
        if (cam.intrinsicCalibrated)
            td *= 1 + cam.D[0] * t2 + cam.D[1] * t2 * t2 + cam.D[2] * t2 * t2 * t2 +
                  cam.D[3] * t2 * t2 * t2 * t2;
        else if (cam.distortionTuned)
            // 未标定畸变预调：k1Preview 仅作等距模型 theta 首项系数，且不构成标定。
            td *= 1 + cam.k1Preview * t2;
        const double factor = r > 1e-12 ? td / r : 1;
        x *= factor; y *= factor;
    } else if (cam.intrinsicCalibrated) {
        const double r4 = r2 * r2, r6 = r4 * r2;
        const double numerator = 1 + cam.D[0] * r2 + cam.D[1] * r4 +
                                 (cam.distortionCount >= 5 ? cam.D[4] * r6 : 0);
        const double denominator = cam.distortionCount == 8
            ? 1 + cam.D[5] * r2 + cam.D[6] * r4 + cam.D[7] * r6 : 1;
        if (std::abs(denominator) < 1e-12)
            return {std::numeric_limits<double>::quiet_NaN(), 0};
        const double radial = numerator / denominator;
        const double xd = x * radial + 2 * cam.D[2] * x * y + cam.D[3] * (r2 + 2 * x * x);
        const double yd = y * radial + cam.D[2] * (r2 + 2 * y * y) + 2 * cam.D[3] * x * y;
        x = xd; y = yd;
    } else if (cam.distortionTuned) {
        // 未标定畸变预调：仅径向 1 + k1*r2，无切向/高阶项；畸变方向与 GPU 路径保持一致。
        const double radial = 1 + cam.k1Preview * r2;
        x *= radial; y *= radial;
    }
    return {k.fx * x + k.skew * y + k.cx, k.fy * y + k.cy};
}

cv::Matx33d rotation(const CameraCalibration &cam) {
    const double y = radians(cam.yawDeg), p = radians(cam.pitchDeg), r = radians(cam.rollDeg);
    const cv::Matx33d yaw(std::cos(y), 0, std::sin(y), 0, 1, 0, -std::sin(y), 0, std::cos(y));
    // Camera coordinates have Y down; positive rotation about X points up.
    const cv::Matx33d pitch(1, 0, 0, 0, std::cos(p), -std::sin(p), 0, std::sin(p), std::cos(p));
    const cv::Matx33d roll(std::cos(r), -std::sin(r), 0, std::sin(r), std::cos(r), 0, 0, 0, 1);
    return yaw * pitch * roll;
}

float imageFeather(const cv::Point2d &p, double border,bool avmHd=false) {
    const int width=avmSourceWidth(avmHd),height=avmSourceHeight(avmHd);
    if(avmHd)border*=2.0;
    if (!std::isfinite(p.x) || !std::isfinite(p.y) || p.x < 0 || p.y < 0 ||
        p.x >= width - 1 || p.y >= height - 1) return 0;
    const double edge = std::min({p.x, p.y, width - 1 - p.x, height - 1 - p.y});
    const double t = std::clamp(edge / border, 0.0, 1.0);
    return float(t * t * (3 - 2 * t));
}

struct MapTile {
    cv::Rect roi;
    cv::Mat map1, map2; // OpenCV's packed bilinear maps.
    cv::Mat weight; // Single channel; repeated channels are created per frame.
};
struct FullMap { cv::Mat x, y, weight; };
FullMap emptyMap(int width, int height) {
    return {cv::Mat(height, width, CV_32F, cv::Scalar(-1)),
            cv::Mat(height, width, CV_32F, cv::Scalar(-1)),
            cv::Mat::zeros(height, width, CV_32F)};
}

// Split at empty columns, notably the rear cameras crossing the +/-180 seam.
std::vector<MapTile> packMap(const FullMap &map) {
    std::vector<MapTile> result;
    int start = -1, top = map.weight.rows, bottom = -1;
    const auto flush = [&](int end) {
        if (start < 0 || bottom < top) return;
        MapTile tile;
        tile.roi = cv::Rect(start, top, end - start, bottom - top + 1);
        cv::convertMaps(map.x(tile.roi), map.y(tile.roi), tile.map1, tile.map2, CV_16SC2);
        tile.weight = map.weight(tile.roi).clone();
        result.push_back(std::move(tile));
    };
    for (int x = 0; x <= map.weight.cols; ++x) {
        int colTop = map.weight.rows, colBottom = -1;
        if (x < map.weight.cols)
            for (int y = 0; y < map.weight.rows; ++y)
                if (map.weight.at<float>(y, x) > 0) { colTop = std::min(colTop, y); colBottom = y; }
        if (colBottom >= 0) {
            if (start < 0) start = x;
            top = std::min(top, colTop); bottom = std::max(bottom, colBottom);
        } else if (start >= 0) {
            flush(x); start = -1; top = map.weight.rows; bottom = -1;
        }
    }
    return result;
}

FullMap panoramaMap(const Configuration &cfg, const CameraCalibration &cam,bool avmHd=false) {
    FullMap map = emptyMap(cfg.panoramaWidth, cfg.panoramaHeight);
    const Intrinsics k = intrinsics(cam,avmHd);
    const cv::Matx33d inverse = rotation(cam).t();
    for (int y = 0; y < cfg.panoramaHeight; ++y) {
        const double elevation = radians(cfg.verticalFovDeg) * (.5 - (y + .5) / cfg.panoramaHeight);
        const double ce = std::cos(elevation), se = std::sin(elevation);
        for (int x = 0; x < cfg.panoramaWidth; ++x) {
            const double yaw = 2 * Pi * ((x + .5) / cfg.panoramaWidth - .5);
            const cv::Vec3d ray = inverse * cv::Vec3d(ce * std::sin(yaw), -se, ce * std::cos(yaw));
            if (ray[2] <= 1e-6) continue;
            const cv::Point2d src = project(ray[0] / ray[2], ray[1] / ray[2], cam, k);
            const float weight = imageFeather(src, 48, avmHd);
            if (weight <= 0) continue;
            map.x.at<float>(y, x) = float(src.x); map.y.at<float>(y, x) = float(src.y);
            map.weight.at<float>(y, x) = weight;
        }
    }
    return map;
}

FullMap birdMap(const Configuration &cfg, const CameraCalibration &cam,bool avmHd=false) {
    FullMap map = emptyMap(cfg.birdSize, cfg.birdSize);
    const bool useGroundQuad = cam.groundCalibrated || cam.groundPreviewEnabled;
    auto src = cfg.birdBottomOnly ? bottomSource()
                                      : (useGroundQuad ? cam.groundSrc : defaultSource());
    if(avmHd)for(auto &point:src)point=avmHdPoint(point);
    const auto dst = useGroundQuad ? cam.groundDst : defaultDestination(cam.yawDeg, cfg.birdSize);
    const cv::Mat h = homography(dst, src);
    cv::Matx33d inverse;
    for (int row = 0; row < 3; ++row)
        for (int col = 0; col < 3; ++col) inverse(row, col) = h.at<double>(row, col);
    std::vector<cv::Point2f> polygon;
    for (const auto &p : src) polygon.emplace_back(float(p.x()), float(p.y()));
    const Intrinsics k = intrinsics(cam,avmHd);
    for (int y = 0; y < cfg.birdSize; ++y)
        for (int x = 0; x < cfg.birdSize; ++x) {
            // A masked vehicle footprint; the UI can draw a vehicle on top.
            if (std::abs(x - cfg.birdSize * .5) < cfg.birdSize * (40.0 / 512) &&
                std::abs(y - cfg.birdSize * .5) < cfg.birdSize * (65.0 / 512)) continue;
            const cv::Vec3d p = inverse * cv::Vec3d(x, y, 1);
            if (std::abs(p[2]) < 1e-12) continue;
            const cv::Point2d rectified(p[0] / p[2], p[1] / p[2]);
            if (!std::isfinite(rectified.x) || !std::isfinite(rectified.y)) continue;
            const double distance = cv::pointPolygonTest(polygon,
                cv::Point2f(float(rectified.x), float(rectified.y)), true);
            if (distance <= 0) continue;
            cv::Point2d raw = rectified;
            if (cfg.birdBottomOnly) {
                // This display crop is in sensor pixels, independent of lens K/D.
                // Check before packing bilinear maps so no sample can include row 335.
                const auto bottom=avmHd?avmHdPoint(QPointF(0,336)):QPointF(0,336);
                const auto end=avmHd?avmHdPoint(QPointF(0,479)):QPointF(0,479);
                if (raw.y < bottom.y() || raw.y > end.y()) continue;
            } else {
                const double ny = (rectified.y - k.cy) / k.fy;
                const double nx = (rectified.x - k.cx - k.skew * ny) / k.fx;
                raw = project(nx, ny, cam, k);
            }
            // A 144-row ROI needs a narrow feather rather than a large vertical fade.
            const double border = cfg.birdBottomOnly ? 12.0 : 24.0;
            const double t = std::clamp(distance / border, 0.0, 1.0);
            const float weight = imageFeather(raw, border,avmHd) * float(t * t * (3 - 2 * t));
            if (weight <= 0) continue;
            map.x.at<float>(y, x) = float(raw.x); map.y.at<float>(y, x) = float(raw.y);
            map.weight.at<float>(y, x) = weight;
        }
    return map;
}

struct OverlapSample { int ax, ay, bx, by; };
struct Overlap { int a, b; std::vector<OverlapSample> samples; };
double luminance(const QImage &img, int x, int y) {
    const uchar *p = img.constScanLine(y) + 3 * x;
    return .2126 * p[0] + .7152 * p[1] + .0722 * p[2];
}

QJsonArray pointsJson(const std::array<QPointF, 4> &points) {
    QJsonArray a;
    for (const auto &p : points) a.append(QJsonArray{p.x(), p.y()});
    return a;
}
template<size_t N> QJsonArray numbersJson(const std::array<double, N> &values) {
    QJsonArray a;
    for (double value : values) a.append(value);
    return a;
}

// Optional fields retain defaults, but a present field must have the right type.
bool number(const QJsonObject &o, const QString &key, double &out) {
    if (!o.contains(key)) return true;
    if (!o.value(key).isDouble() || !std::isfinite(o.value(key).toDouble())) return false;
    out = o.value(key).toDouble(); return true;
}
bool integer(const QJsonObject &o, const QString &key, int &out) {
    double n = out;
    if (!number(o, key, n) || n != std::floor(n) || n < std::numeric_limits<int>::min() ||
        n > std::numeric_limits<int>::max()) return false;
    out = int(n); return true;
}
bool milliseconds(const QJsonObject &o, const QString &key, qint64 &out) {
    double n = double(out);
    if (!number(o, key, n) || n != std::floor(n) || n < 0 || n > 60000) return false;
    out = qint64(n); return true;
}
bool boolean(const QJsonObject &o, const QString &key, bool &out) {
    if (!o.contains(key)) return true;
    if (!o.value(key).isBool()) return false;
    out = o.value(key).toBool(); return true;
}
template<size_t N> bool numbers(const QJsonObject &o, const QString &key, std::array<double, N> &out) {
    if (!o.contains(key)) return true;
    if (!o.value(key).isArray()) return false;
    const QJsonArray a = o.value(key).toArray();
    if (a.size() != int(N)) return false;
    for (int i = 0; i < int(N); ++i) {
        if (!a[i].isDouble() || !std::isfinite(a[i].toDouble())) return false;
        out[i] = a[i].toDouble();
    }
    return true;
}
bool points(const QJsonObject &o, const QString &key, std::array<QPointF, 4> &out) {
    if (!o.contains(key)) return true;
    if (!o.value(key).isArray()) return false;
    const QJsonArray a = o.value(key).toArray();
    if (a.size() != 4) return false;
    for (int i = 0; i < 4; ++i) {
        if (!a[i].isArray()) return false;
        const QJsonArray pair = a[i].toArray();
        if (pair.size() != 2 || !pair[0].isDouble() || !pair[1].isDouble() ||
            !std::isfinite(pair[0].toDouble()) || !std::isfinite(pair[1].toDouble())) return false;
        out[i] = QPointF(pair[0].toDouble(), pair[1].toDouble());
    }
    return true;
}
} // namespace

Configuration::Configuration() {
    const double yaws[CameraCount] = {0, 0, -90, 90, 180, 180};
    for (int i = 0; i < CameraCount; ++i) {
        cameras[i].id = i + 1;
        cameras[i].yawDeg = yaws[i];
        cameras[i].groundSrc = defaultSource();
        cameras[i].groundDst = defaultDestination(yaws[i], birdSize);
    }
}

bool Configuration::validate(QString *error) const {
    if (error) error->clear();
    if (version != 1) return fail(error, "Unsupported configuration version (expected 1)");
    if (panoramaWidth < 480 || panoramaWidth > 3072 || panoramaHeight < 120 || panoramaHeight > 480 ||
        birdSize < 128 || birdSize > 512)
        return fail(error, "Output size outside limits: panorama 480..3072 x 120..480; bird 128..512");
    if (!std::isfinite(verticalFovDeg) || verticalFovDeg < 20 || verticalFovDeg > 120)
        return fail(error, "verticalFovDeg must be 20..120 degrees");
    if (!std::isfinite(birdRadiusFraction) || birdRadiusFraction < .25 || birdRadiusFraction > 1)
        return fail(error, "birdRadiusFraction must be finite within 0.25..1");
    if (!std::isfinite(birdFeatherFraction) || birdFeatherFraction < 0 || birdFeatherFraction > .5 ||
        birdFeatherFraction > birdRadiusFraction)
        return fail(error, "birdFeatherFraction must be finite within 0..0.5 and <= birdRadiusFraction");
    if(!std::isfinite(birdNearFraction)||birdNearFraction<.10||birdNearFraction>.80||
       !std::isfinite(birdFarStretch)||birdFarStretch<0||birdFarStretch>.45||
       !std::isfinite(birdFarBlurPx)||birdFarBlurPx<0||birdFarBlurPx>8)
        return fail(error,"Bird near radius/stretch/blur outside limits");
    if (freshMs < 0 || staleMs <= freshMs || staleMs > 60000)
        return fail(error, "Require 0 <= freshMs < staleMs <= 60000");
    if (birdHistoryMaxAgeMs < 250 || birdHistoryMaxAgeMs > 10000)
        return fail(error, "birdHistoryMaxAgeMs must be 250..10000 ms");
    if (!std::isfinite(footprintWidthPx) || footprintWidthPx < 10 || footprintWidthPx > 400 ||
        !std::isfinite(footprintLengthPx) || footprintLengthPx < 10 || footprintLengthPx > 400)
        return fail(error, "footprintWidthPx/footprintLengthPx must be finite within 10..400 px");
    if (!std::isfinite(gridSpacingPx) || gridSpacingPx < 8 || gridSpacingPx > 512)
        return fail(error, "gridSpacingPx must be finite within 8..512 px");
    if (!std::isfinite(birdPixelsPerMeter) || birdPixelsPerMeter < 0 || birdPixelsPerMeter > 1000)
        return fail(error, "birdPixelsPerMeter must be finite within 0..1000 (0 = unmeasured)");
    for (int i = 0; i < CameraCount; ++i) {
        const auto &c = cameras[i];
        const QString label = QString("C%1: ").arg(i + 1);
        if (c.id != i + 1) return fail(error, label + "camera IDs must stay in C1..C6 order");
        if (!std::isfinite(c.yawDeg) || std::abs(c.yawDeg) > 180 || !std::isfinite(c.pitchDeg) ||
            std::abs(c.pitchDeg) > 89 || !std::isfinite(c.rollDeg) || std::abs(c.rollDeg) > 180 ||
            !std::isfinite(c.hfovDeg) || c.hfovDeg < 30 || c.hfovDeg > 170)
            return fail(error, label + "invalid yaw/pitch/roll/FOV");
        if (c.lens != LensModel::Pinhole && c.lens != LensModel::Fisheye)
            return fail(error, label + "unknown lens model");
        for (double n : c.K) if (!std::isfinite(n)) return fail(error, label + "non-finite K");
        for (double n : c.D) if (!std::isfinite(n)) return fail(error, label + "non-finite D");
        if (!std::isfinite(c.k1Preview) || std::abs(c.k1Preview) > 1)
            return fail(error, label + "k1Preview must be finite within -1..1");
        for (const auto &quad : {c.groundSrc, c.groundDst})
            for (const auto &point : quad)
                if (!std::isfinite(point.x()) || !std::isfinite(point.y()))
                    return fail(error, label + "non-finite ground point");
        if ((c.lens == LensModel::Fisheye && c.distortionCount != 4) ||
            (c.lens == LensModel::Pinhole && c.distortionCount != 4 &&
             c.distortionCount != 5 && c.distortionCount != 8))
            return fail(error, label + "distortionCount must be 4 (fisheye) or 4/5/8 (pinhole)");
        if (c.intrinsicCalibrated && (c.K[0] <= 0 || c.K[4] <= 0 || std::abs(c.K[3]) > 1e-9 ||
            std::abs(c.K[6]) > 1e-9 || std::abs(c.K[7]) > 1e-9 || std::abs(c.K[8] - 1) > 1e-9 ||
            c.K[2] < 0 || c.K[2] >= SourceWidth || c.K[5] < 0 || c.K[5] >= SourceHeight))
            return fail(error, label + "K must be a valid 640x480 intrinsic matrix");
        if (c.groundCalibrated || c.groundPreviewEnabled) {
            if (!validQuad(c.groundSrc, SourceWidth, SourceHeight) ||
                !validQuad(c.groundDst, birdSize, birdSize))
                return fail(error, label + "ground quads must be convex, ordered and inside their images");
            try {
                const cv::Mat h = homography(c.groundSrc, c.groundDst);
                cv::Mat inverse;
                if (!cv::checkRange(h) || std::abs(cv::determinant(h)) < 1e-12 ||
                    !cv::invert(h, inverse) || !cv::checkRange(inverse))
                    return fail(error, label + "singular ground homography");
            } catch (const cv::Exception &) { return fail(error, label + "invalid ground homography"); }
        }
    }
    return true;
}

bool Configuration::save(const QString &path, QString *error) const {
    if (!validate(error)) return false;
    QJsonObject root{{"version", version}, {"panoramaWidth", panoramaWidth},
        {"panoramaHeight", panoramaHeight}, {"birdSize", birdSize},
        {"birdBottomOnly", birdBottomOnly},
        {"birdTemporalGround", birdTemporalGround}, {"birdHistoryMaxAgeMs", birdHistoryMaxAgeMs},
        {"birdCircular", birdCircular}, {"birdRadiusFraction", birdRadiusFraction},
        {"birdFeatherFraction", birdFeatherFraction},
        {"birdFarStyle",birdFarStyle},{"birdNearFraction",birdNearFraction},
        {"birdFarStretch",birdFarStretch},{"birdFarBlurPx",birdFarBlurPx},
        {"verticalFovDeg", verticalFovDeg}, {"exposureBalance", exposureBalance},
        {"colorBalance", colorBalance}, {"footprintWidthPx", footprintWidthPx},
        {"footprintLengthPx", footprintLengthPx}, {"gridSpacingPx", gridSpacingPx},
        {"birdPixelsPerMeter", birdPixelsPerMeter},
        {"freshMs", double(freshMs)}, {"staleMs", double(staleMs)}};
    QJsonArray array;
    for (const auto &c : cameras) {
        QJsonObject o{{"id", c.id}, {"yawDeg", c.yawDeg}, {"pitchDeg", c.pitchDeg},
            {"rollDeg", c.rollDeg}, {"hfovDeg", c.hfovDeg},
            {"lens", c.lens == LensModel::Pinhole ? "pinhole" : "fisheye"},
            {"K", numbersJson(c.K)}, {"D", numbersJson(c.D)}, {"distortionCount", c.distortionCount},
            {"intrinsicCalibrated", c.intrinsicCalibrated}, {"yawCalibrated", c.yawCalibrated},
            {"groundCalibrated", c.groundCalibrated}, {"groundPreviewEnabled", c.groundPreviewEnabled},
            {"groundSrc", pointsJson(c.groundSrc)},
            {"groundDst", pointsJson(c.groundDst)},
            {"distortionTuned", c.distortionTuned}, {"k1Preview", c.k1Preview}};
        array.append(o);
    }
    root.insert("cameras", array);
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) return fail(error, file.errorString());
    const QByteArray bytes = QJsonDocument(root).toJson(QJsonDocument::Indented);
    if (file.write(bytes) != bytes.size()) return fail(error, file.errorString());
    if (!file.commit()) return fail(error, file.errorString());
    return true;
}

bool Configuration::load(const QString &path, Configuration &out, QString *error) {
    if (error) error->clear();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return fail(error, file.errorString());
    if (file.size() > 1024 * 1024) return fail(error, "Configuration exceeds 1 MiB");
    QJsonParseError parse;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parse);
    if (parse.error != QJsonParseError::NoError || !doc.isObject())
        return fail(error, "Invalid JSON object: " + parse.errorString());
    const QJsonObject root = doc.object();
    Configuration next;
    if (!root.contains("version") || !integer(root, "version", next.version) ||
        !integer(root, "panoramaWidth", next.panoramaWidth) ||
         !integer(root, "panoramaHeight", next.panoramaHeight) || !integer(root, "birdSize", next.birdSize) ||
          !boolean(root, "birdBottomOnly", next.birdBottomOnly) ||
         !boolean(root, "birdTemporalGround", next.birdTemporalGround) ||
         !integer(root, "birdHistoryMaxAgeMs", next.birdHistoryMaxAgeMs) ||
        !boolean(root, "birdCircular", next.birdCircular) ||
        !number(root, "birdRadiusFraction", next.birdRadiusFraction) ||
        !number(root, "birdFeatherFraction", next.birdFeatherFraction) ||
        !boolean(root,"birdFarStyle",next.birdFarStyle)||!number(root,"birdNearFraction",next.birdNearFraction)||
        !number(root,"birdFarStretch",next.birdFarStretch)||!number(root,"birdFarBlurPx",next.birdFarBlurPx)||
        !number(root, "verticalFovDeg", next.verticalFovDeg) ||
        !boolean(root, "exposureBalance", next.exposureBalance) ||
        !boolean(root, "colorBalance", next.colorBalance) ||
        !number(root, "footprintWidthPx", next.footprintWidthPx) ||
        !number(root, "footprintLengthPx", next.footprintLengthPx) ||
        !number(root, "gridSpacingPx", next.gridSpacingPx) ||
        !number(root, "birdPixelsPerMeter", next.birdPixelsPerMeter) ||
        !milliseconds(root, "freshMs", next.freshMs) || !milliseconds(root, "staleMs", next.staleMs))
        return fail(error, "Invalid configuration field type or missing version");
    if (root.contains("cameras")) {
        if (!root.value("cameras").isArray() || root.value("cameras").toArray().size() != CameraCount)
            return fail(error, "cameras must contain exactly six objects in C1..C6 order");
        const QJsonArray cams = root.value("cameras").toArray();
        for (int i = 0; i < CameraCount; ++i) {
            if (!cams[i].isObject()) return fail(error, "Camera must be an object");
            const QJsonObject o = cams[i].toObject();
            auto &c = next.cameras[i];
            if (!integer(o, "id", c.id) || !number(o, "yawDeg", c.yawDeg) ||
                !number(o, "pitchDeg", c.pitchDeg) || !number(o, "rollDeg", c.rollDeg) ||
                !number(o, "hfovDeg", c.hfovDeg) || !numbers(o, "K", c.K) || !numbers(o, "D", c.D) ||
                !integer(o, "distortionCount", c.distortionCount) ||
                !boolean(o, "intrinsicCalibrated", c.intrinsicCalibrated) ||
                !boolean(o, "yawCalibrated", c.yawCalibrated) ||
                 !boolean(o, "groundCalibrated", c.groundCalibrated) ||
                 !boolean(o, "groundPreviewEnabled", c.groundPreviewEnabled) ||
                !boolean(o, "distortionTuned", c.distortionTuned) ||
                !number(o, "k1Preview", c.k1Preview) ||
                !points(o, "groundSrc", c.groundSrc) || !points(o, "groundDst", c.groundDst))
                return fail(error, QString("C%1: invalid JSON field type/length").arg(i + 1));
            if (o.contains("lens")) {
                if (!o.value("lens").isString()) return fail(error, "lens must be a string");
                const QString lens = o.value("lens").toString();
                if (lens != "pinhole" && lens != "fisheye") return fail(error, "Unknown lens model");
                c.lens = lens == "pinhole" ? LensModel::Pinhole : LensModel::Fisheye;
            }
            if (c.intrinsicCalibrated && (!o.contains("K") || !o.contains("D")))
                return fail(error, QString("C%1: intrinsicCalibrated requires explicit K and D").arg(i + 1));
            if (c.yawCalibrated && !o.contains("yawDeg"))
                return fail(error, QString("C%1: yawCalibrated requires explicit yawDeg").arg(i + 1));
            if (c.groundCalibrated && (!o.contains("groundSrc") || !o.contains("groundDst")))
                return fail(error, QString("C%1: groundCalibrated requires explicit source/destination quads").arg(i + 1));
            if (c.groundPreviewEnabled && (!o.contains("groundSrc") || !o.contains("groundDst")))
                return fail(error, QString("C%1: groundPreviewEnabled requires explicit source/destination quads").arg(i + 1));
        }
    }
    if (!next.validate(error)) return false;
    out = next;
    return true;
}

struct Engine::Impl {
    Configuration configuration;
    std::array<std::vector<MapTile>, CameraCount> panorama, bird;
    std::vector<Overlap> overlaps;
    std::array<double, CameraCount> gains{{1, 1, 1, 1, 1, 1}};
    std::array<qint64, CameraCount> lastCapture{};
    std::array<quint64, CameraCount> lastSequence{}, lastGeneration{};
    std::array<bool, CameraCount> lastActive{};
    bool hasExposureState = false;
    bool avmHd = false;

    explicit Impl(const Configuration &config,bool hd) : configuration(config),avmHd(hd) {
        // Temporary full maps are released after packing. They are never remade per frame.
        std::array<FullMap, CameraCount> full;
        for (int i = 0; i < CameraCount; ++i) {
            full[i] = panoramaMap(config, config.cameras[i],avmHd);
            panorama[i] = packMap(full[i]);
        }
        for (int a = 0; a < CameraCount; ++a)
            for (int b = a + 1; b < CameraCount; ++b) {
                if ((a == 0 && b == 1) || (a == 4 && b == 5)) continue;
                Overlap overlap{a, b, {}};
                for (int y = 8; y < config.panoramaHeight; y += 16)
                    for (int x = 8; x < config.panoramaWidth; x += 16) {
                        if (full[a].weight.at<float>(y, x) < .2f || full[b].weight.at<float>(y, x) < .2f)
                            continue;
                        overlap.samples.push_back({int(full[a].x.at<float>(y, x)),
                            int(full[a].y.at<float>(y, x)), int(full[b].x.at<float>(y, x)),
                            int(full[b].y.at<float>(y, x))});
                    }
                if (!overlap.samples.empty()) overlaps.push_back(std::move(overlap));
            }
        for (auto &map : full) map = FullMap{};
        for (int i = 0; i < CameraCount; ++i) bird[i] = packMap(birdMap(config, config.cameras[i],avmHd));
    }

    void balance(const std::array<QImage, CameraCount> &images, const ProcessResult &result,
                 const FrameInput &frames) {
        // CPU 路径保持标量亮度增益；colorBalance（OV5640 逐通道接缝匹配）由显示侧
        // GPU 路径实现，此处接受但忽略该标志，避免两路增益叠加。
        if (!configuration.exposureBalance) { gains.fill(1); return; }
        // Rendering the same capture in both HUD modes must not advance the filter twice.
        bool changed = !hasExposureState || lastActive != result.active;
        for (int i = 0; i < CameraCount; ++i)
            if (result.active[i] && (lastCapture[i] != frames.capturedMs[i] ||
                lastSequence[i] != frames.sequence[i] || lastGeneration[i] != frames.generation[i])) changed = true;
        if (!changed) return;
        lastCapture = frames.capturedMs; lastSequence = frames.sequence;
        lastGeneration = frames.generation; lastActive = result.active; hasExposureState = true;
        cv::Mat a = cv::Mat::eye(CameraCount, CameraCount, CV_64F) * .05;
        cv::Mat b = cv::Mat::zeros(CameraCount, 1, CV_64F);
        for (const auto &overlap : overlaps) {
            if (!result.active[overlap.a] || !result.active[overlap.b]) continue;
            double ma = 0, mb = 0;
            int count = 0;
            for (const auto &s : overlap.samples) {
                const double va = luminance(images[overlap.a], s.ax, s.ay);
                const double vb = luminance(images[overlap.b], s.bx, s.by);
                if (va < 15 || vb < 15 || va > 240 || vb > 240) continue;
                ma += va; mb += vb; ++count;
            }
            if (count < 8) continue;
            const double target = std::clamp(std::log(mb / ma), -.4, .4);
            a.at<double>(overlap.a, overlap.a) += 1;
            a.at<double>(overlap.b, overlap.b) += 1;
            a.at<double>(overlap.a, overlap.b) -= 1;
            a.at<double>(overlap.b, overlap.a) -= 1;
            b.at<double>(overlap.a) += target;
            b.at<double>(overlap.b) -= target;
        }
        cv::Mat solution;
        if (!cv::solve(a, b, solution, cv::DECOMP_CHOLESKY) || !cv::checkRange(solution)) return;
        for (int i = 0; i < CameraCount; ++i) {
            const double target = std::clamp(std::exp(solution.at<double>(i)), .85, 1.15);
            gains[i] = .85 * gains[i] + .15 * target;
        }
    }
};

Engine::Engine(const Configuration &config,bool hd):avmHd_(hd) {
    QString error;
    if (!setConfig(config, &error)) throw std::invalid_argument(error.toStdString());
}
Engine::~Engine() = default;
const Configuration &Engine::config() const { return d->configuration; }
bool Engine::setConfig(const Configuration &config, QString *error) {
    if (!config.validate(error)) return false;
    try {
        std::unique_ptr<Impl> next(new Impl(config,avmHd_));
        d.swap(next);
        return true;
    } catch (const std::exception &exception) {
        return fail(error, QString("Map construction failed: ") + QString::fromLocal8Bit(exception.what()));
    }
}

ProcessResult Engine::render(const FrameInput &frames, ViewMode mode, qint64 nowMs) {
    ProcessResult result;
    result.ageMs.fill(-1);
    const auto &cfg = d->configuration;
    const bool isBird = mode == ViewMode::Birdseye;
    const int width = isBird ? cfg.birdSize : cfg.panoramaWidth;
    const int height = isBird ? cfg.birdSize : cfg.panoramaHeight;
    result.output = QImage(width, height, QImage::Format_RGB888);
    if (result.output.isNull()) { result.status = "Output allocation failed"; return result; }
    result.output.fill(Qt::black);
    std::array<QImage, CameraCount> images;
    std::array<double, CameraCount> freshness{};
    QStringList invalid, missing, stale, future, fading;
    qint64 earliest = std::numeric_limits<qint64>::max(), latest = std::numeric_limits<qint64>::min();
    bool calibrated = true;
    for (int i = 0; i < CameraCount; ++i) {
        // AVM always has four physical inputs. C2/C6 remain available to the
        // six-camera monitor but are not missing or fallback AVM cameras.
        if(avmHd_ && (i==1 || i==5)) continue;
        const auto &cal = cfg.cameras[i];
        calibrated &= isBird ? (cal.intrinsicCalibrated && cal.groundCalibrated)
                             : (cal.intrinsicCalibrated && cal.yawCalibrated);
        const QString name = QString("C%1").arg(i + 1);
        if (frames.images[i].isNull()) { missing.append(name); continue; }
        const QSize expected(avmSourceWidth(avmHd_&&avmUsesHd(i)),avmSourceHeight(avmHd_&&avmUsesHd(i)));
        if (frames.images[i].size() != expected) {
            invalid.append(name); continue;
        }
        // Nonnegative monotonic times avoid subtraction overflow and clock ambiguity.
        if (nowMs < 0 || frames.capturedMs[i] < 0 || frames.capturedMs[i] > nowMs) {
            future.append(name); continue;
        }
        const qint64 age = nowMs - frames.capturedMs[i];
        result.ageMs[i] = age;
        if (age >= cfg.staleMs) { stale.append(name); continue; }
        freshness[i] = age <= cfg.freshMs ? 1.0
            : double(cfg.staleMs - age) / double(cfg.staleMs - cfg.freshMs);
        if (age > cfg.freshMs) fading.append(name);
        images[i] = frames.images[i].format() == QImage::Format_RGB888 ? frames.images[i]
                   : frames.images[i].convertToFormat(QImage::Format_RGB888);
        if (images[i].isNull()) { freshness[i] = 0; invalid.append(name); continue; }
        result.active[i] = true;
        earliest = std::min(earliest, frames.capturedMs[i]); latest = std::max(latest, frames.capturedMs[i]);
    }
    result.captureSkewMs = earliest <= latest ? latest - earliest : 0;
    result.projectionSelected = selectStereoEyes(freshness);
    if(avmHd_) result.projectionSelected={{true,false,true,true,true,false}};
    const bool bottomCrop = isBird && cfg.birdBottomOnly;
    result.approximateGeometry = bottomCrop || !calibrated;
    QStringList status;
    status.append(bottomCrop ? "Bird view: raw bottom 30% crop/stretch, approximate geometry"
                            : calibrated ? (isBird ? "Calibrated ground warp" : "Calibrated panorama")
                            : (isBird ? "DEMO bird view: uncalibrated, approximate geometry"
                                      : "Panorama: uncalibrated, approximate geometry"));
    if (!missing.isEmpty()) status.append("Missing " + missing.join(','));
    if (!invalid.isEmpty()) status.append("Invalid size/image " + invalid.join(','));
    if (!future.isEmpty()) status.append("Invalid capture time " + future.join(','));
    if (!stale.isEmpty()) status.append("Stale " + stale.join(','));
    if (!fading.isEmpty()) status.append("Fading " + fading.join(','));
    status.append(QString("Capture skew %1 ms").arg(result.captureSkewMs));
    status.append(QString("Front C1 (C2 backup; selected C%1), rear C5 (C6 backup; selected C%2)")
        .arg(result.projectionSelected[0] ? 1 : 2).arg(result.projectionSelected[4] ? 5 : 6));
    result.status = status.join(" | ");
    try {
        ProcessResult balanceResult = result;
        for (int i = 0; i < CameraCount; ++i)
            balanceResult.active[i] = result.active[i] && result.projectionSelected[i];
        if (!bottomCrop) d->balance(images, balanceResult, frames);
        cv::Mat sum = cv::Mat::zeros(height, width, CV_32FC3);
        cv::Mat normalization = cv::Mat::zeros(height, width, CV_32F);
        cv::Mat coverage = cv::Mat::zeros(height, width, CV_32F);
        const bool collectBirdMasks = isBird && cfg.birdTemporalGround;
        cv::Mat dominantWeight;
        if (collectBirdMasks) {
            result.birdObservedMask = QImage(width, height, QImage::Format_Grayscale8);
            result.birdGeometryMask = QImage(width, height, QImage::Format_Grayscale8);
            result.birdOwnerMask = QImage(width, height, QImage::Format_Grayscale8);
            if (result.birdObservedMask.isNull() || result.birdGeometryMask.isNull() ||
                result.birdOwnerMask.isNull()) {
                result.birdObservedMask = result.birdGeometryMask = result.birdOwnerMask = QImage();
                result.status += " | Bird mask allocation failed";
                return result;
            }
            result.birdObservedMask.fill(0);
            result.birdGeometryMask.fill(0);
            result.birdOwnerMask.fill(0);
            dominantWeight = cv::Mat::zeros(height, width, CV_32F);
        }
        const auto &maps = isBird ? d->bird : d->panorama;
        for (int i = 0; i < CameraCount; ++i) {
            if (!result.projectionSelected[i]) continue;
            // One eye per stereo module supplies geometry, including when both
            // eyes are dead. Never count duplicate stereo support or colors.
            for (const auto &tile : maps[i]) {
                coverage(tile.roi) += tile.weight;
                if (!collectBirdMasks) continue;
                // Static support and owners never depend on pixel color, capture
                // availability, freshness, exposure gain or the display boundary.
                const uchar owner = i < 2 ? 1 : i == 2 ? 2 : i == 3 ? 3 : 4;
                const bool observed = result.active[i] && freshness[i] >= .99;
                for (int y = 0; y < tile.roi.height; ++y) {
                    const float *weight = tile.weight.ptr<float>(y);
                    const int outputY = tile.roi.y + y;
                    uchar *geometry = result.birdGeometryMask.scanLine(outputY) + tile.roi.x;
                    uchar *observation = result.birdObservedMask.scanLine(outputY) + tile.roi.x;
                    uchar *owners = result.birdOwnerMask.scanLine(outputY) + tile.roi.x;
                    float *dominant = dominantWeight.ptr<float>(outputY) + tile.roi.x;
                    for (int x = 0; x < tile.roi.width; ++x) {
                        if (weight[x] <= 1e-8f) continue;
                        geometry[x] = 255;
                        if (weight[x] > dominant[x]) {
                            dominant[x] = weight[x]; owners[x] = owner;
                        }
                        if (observed && weight[x] > .05f) observation[x] = 255;
                    }
                }
            }
            if (!result.active[i]) continue;
            cv::Mat source(images[i].height(), images[i].width(), CV_8UC3,
                           const_cast<uchar *>(images[i].constBits()), images[i].bytesPerLine());
            for (const auto &tile : maps[i]) {
                cv::Mat warped, floatPixels, weighted;
                cv::remap(source, warped, tile.map1, tile.map2, cv::INTER_LINEAR, cv::BORDER_CONSTANT);
                warped.convertTo(floatPixels, CV_32FC3, bottomCrop ? 1.0 : d->gains[i]);
                cv::Mat effective = tile.weight * freshness[i];
                cv::Mat channels[] = {effective, effective, effective};
                cv::Mat weight3;
                cv::merge(channels, 3, weight3);
                cv::multiply(floatPixels, weight3, weighted);
                sum(tile.roi) += weighted;
                normalization(tile.roi) += effective;
            }
        }
        // Normalize overlaps, then attenuate incomplete support. Pixel loops
        // avoid three more full-size floating-point normalization temporaries.
        for (int y = 0; y < height; ++y) {
            const auto *pixels = sum.ptr<cv::Vec3f>(y);
            const float *norm = normalization.ptr<float>(y), *support = coverage.ptr<float>(y);
            uchar *out = result.output.scanLine(y);
            for (int x = 0; x < width; ++x) {
                if (norm[x] <= 1e-8f || support[x] <= 1e-8f) continue;
                const float opacity = std::min(1.f, norm[x] / support[x]);
                const float scale = opacity / norm[x];
                for (int c = 0; c < 3; ++c) out[3 * x + c] = cv::saturate_cast<uchar>(pixels[x][c] * scale);
            }
        }
        // Apply after normalization: putting the boundary in blend weights
        // would cancel its attenuation when those weights are normalized.
        if (isBird) applyBirdBoundary(result.output, cfg);
    } catch (const cv::Exception &exception) {
        result.output.fill(Qt::black);
        result.birdObservedMask = result.birdGeometryMask = result.birdOwnerMask = QImage();
        result.status += " | Processing failed: " + QString::fromLocal8Bit(exception.what());
    }
    return result;
}

ProcessResult Engine::composePanorama(const FrameInput &frames, qint64 nowMs) {
    return render(frames, ViewMode::Panorama, nowMs);
}
ProcessResult Engine::composeBird(const FrameInput &frames, qint64 nowMs) {
    return render(frames, ViewMode::Birdseye, nowMs);
}
QImage Engine::panorama(const std::array<QImage, CameraCount> &images,
                       const std::array<qint64, CameraCount> &capturedMs, qint64 nowMs) {
    FrameInput frames; frames.images = images; frames.capturedMs = capturedMs;
    return composePanorama(frames, nowMs).output;
}
QImage Engine::birdseye(const std::array<QImage, CameraCount> &images,
                      const std::array<qint64, CameraCount> &capturedMs, qint64 nowMs) {
    FrameInput frames; frames.images = images; frames.capturedMs = capturedMs;
    return composeBird(frames, nowMs).output;
}

} // namespace surround
