#include "calibration_capture.h"

#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutexLocker>
#include <QSaveFile>
#include <QStringList>
#include <QTemporaryDir>
#include <QUuid>
#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <utility>
#include <vector>

namespace {
constexpr int width = 640, height = 480, columns = 6, rows = 9;
constexpr double squareMeters = 0.02860;
constexpr qint64 maxAgeMs = 500;

qint64 nowMs() {
    QElapsedTimer clock;
    clock.start();
    return clock.msecsSinceReference();
}

bool validJob(const CalibrationCaptureJob& job, qint64 now) {
    const auto imageOK = [](const QImage& image) {
        return !image.isNull() && image.size() == QSize(width, height) &&
               image.format() == QImage::Format_RGB888;
    };
    // Captures must already exist at the request, not merely at submission.
    return imageOK(job.left) && imageOK(job.right) &&
           job.leftCamera >= 0 && job.leftCamera < 6 &&
           job.rightCamera >= 0 && job.rightCamera < 6 && job.leftCamera != job.rightCamera &&
           job.leftSequence != 0 && job.rightSequence != 0 &&
           job.requestedMs >= 0 && job.requestedMs <= now && now - job.requestedMs <= maxAgeMs &&
           job.leftCapturedMs >= 0 && job.leftCapturedMs <= job.requestedMs &&
           job.rightCapturedMs >= 0 && job.rightCapturedMs <= job.requestedMs &&
           job.requestedMs - job.leftCapturedMs <= maxAgeMs &&
           job.requestedMs - job.rightCapturedMs <= maxAgeMs &&
           std::isfinite(job.distanceMeters) && job.distanceMeters >= 0 &&
           !job.outputRoot.trimmed().isEmpty();
}

QJsonValue numberOrNull(double value) {
    return std::isfinite(value) ? QJsonValue(value) : QJsonValue(QJsonValue::Null);
}

double percentile(std::vector<double> values, double fraction) {
    if (values.empty()) return std::numeric_limits<double>::quiet_NaN();
    std::sort(values.begin(), values.end());
    return values[size_t(std::ceil(fraction * values.size())) - 1];
}

void canonicalize(std::vector<cv::Point2f>& corners) {
    if (corners.size() != size_t(columns * rows)) return;
    // A rectangular board permits a 180-degree reversal. Never transpose or
    // mirror one camera independently; pixels remain in their camera coordinates.
    const auto& first = corners.front();
    const auto& last = corners.back();
    if (first.y > last.y + 1 || (std::abs(first.y - last.y) <= 1 && first.x > last.x))
        std::reverse(corners.begin(), corners.end());
}

std::vector<double> gridSteps(const std::vector<cv::Point2f>& corners) {
    std::vector<double> result;
    if (corners.size() != size_t(columns * rows)) return result;
    for (int y = 0; y < rows; ++y) {
        for (int x = 0; x < columns; ++x) {
            const auto p = corners[size_t(y * columns + x)];
            if (x + 1 < columns) result.push_back(cv::norm(p - corners[size_t(y * columns + x + 1)]));
            if (y + 1 < rows) result.push_back(cv::norm(p - corners[size_t((y + 1) * columns + x)]));
        }
    }
    return result;
}

struct Detection {
    std::vector<cv::Point2f> corners;
    QJsonObject data;
    QStringList reasons, warnings;
    bool usable = false;
};

Detection detect(const QImage& image) {
    Detection result;
    const cv::Size board(columns, rows);
    // Respect QImage stride. This Mat only borrows the worker-owned snapshot.
    const cv::Mat rgb(height, width, CV_8UC3, const_cast<uchar*>(image.constBits()),
                      size_t(image.bytesPerLine()));
    cv::Mat gray;
    cv::cvtColor(rgb, gray, cv::COLOR_RGB2GRAY);
    cv::Scalar mean, deviation;
    cv::meanStdDev(gray, mean, deviation);
    result.data["gray_mean"] = mean[0];
    result.data["gray_stddev"] = deviation[0];
    std::vector<cv::Point2f> classic, sb;
    bool classicFound = false, sbFound = false, exhaustive = false;
    int window = 2;
    QElapsedTimer timer;
    timer.start();
    // Skip only essentially constant images, not normal low contrast captures.
    if (deviation[0] >= 1.0) {
        classicFound = cv::findChessboardCorners(gray, board, classic,
            cv::CALIB_CB_ADAPTIVE_THRESH | cv::CALIB_CB_NORMALIZE_IMAGE | cv::CALIB_CB_FAST_CHECK);
        classicFound = classicFound && classic.size() == size_t(columns * rows);
        if (classicFound) {
            const double step = percentile(gridSteps(classic), 0.5);
            window = std::clamp(int(std::floor(step * 0.20)), 2, 5);
            cv::cornerSubPix(gray, classic, cv::Size(window, window), cv::Size(-1, -1),
                cv::TermCriteria(cv::TermCriteria::EPS | cv::TermCriteria::COUNT, 40, 0.001));
            canonicalize(classic);
        }
        sbFound = cv::findChessboardCornersSB(gray, board, sb,
            cv::CALIB_CB_NORMALIZE_IMAGE | cv::CALIB_CB_ACCURACY);
        sbFound = sbFound && sb.size() == size_t(columns * rows);
        if (!sbFound) {
            // One fallback, on the original pixels; no unbounded retries or upscale.
            exhaustive = true;
            sb.clear();
            sbFound = cv::findChessboardCornersSB(gray, board, sb,
                cv::CALIB_CB_NORMALIZE_IMAGE | cv::CALIB_CB_ACCURACY | cv::CALIB_CB_EXHAUSTIVE);
            sbFound = sbFound && sb.size() == size_t(columns * rows);
        }
        if (sbFound) canonicalize(sb);
    }
    result.data["detection_ms"] = double(timer.elapsed());
    result.data["classic_found"] = classicFound;
    result.data["sb_found"] = sbFound;
    result.data["sb_exhaustive_used"] = exhaustive;
    result.data["subpixel_window_radius_px"] = window;
    QJsonObject consistency;
    consistency["compared"] = classicFound && sbFound;
    consistency["p95_px"] = QJsonValue(QJsonValue::Null);
    consistency["max_px"] = QJsonValue(QJsonValue::Null);
    if (classicFound && sbFound) {
        // Match only the allowed 180-degree ordering before comparing detectors.
        double direct = 0, reversed = 0;
        for (size_t i = 0; i < classic.size(); ++i) {
            direct += cv::norm(classic[i] - sb[i]);
            reversed += cv::norm(classic[i] - sb[sb.size() - 1 - i]);
        }
        if (reversed < direct) std::reverse(sb.begin(), sb.end());
        std::vector<double> errors;
        for (size_t i = 0; i < classic.size(); ++i) errors.push_back(cv::norm(classic[i] - sb[i]));
        const double p95 = percentile(errors, 0.95), maximum = *std::max_element(errors.begin(), errors.end());
        consistency["p95_px"] = p95;
        consistency["max_px"] = maximum;
        if (p95 > 1.0 || maximum > 2.0) result.reasons << "detectors_disagree";
    }
    result.data["detector_consistency"] = consistency;
    result.corners = sbFound ? sb : (classicFound ? classic : std::vector<cv::Point2f>{});
    result.data["method"] = sbFound ? (exhaustive ? "sb_accuracy_exhaustive" : "sb_accuracy") :
                           (classicFound ? "classic_corner_subpix" : "none");
    result.data["corner_count"] = int(result.corners.size());
    if (result.corners.size() != size_t(columns * rows)) {
        result.reasons << "board_not_found_54_corners_required";
    } else {
        bool finite = true, boundary = false;
        for (const auto& p : result.corners) {
            finite = finite && std::isfinite(p.x) && std::isfinite(p.y);
            boundary = boundary || p.x <= window + 1 || p.y <= window + 1 ||
                       p.x >= width - window - 2 || p.y >= height - window - 2;
        }
        if (!finite) result.reasons << "nonfinite_corners";
        if (boundary) result.reasons << "corners_touch_image_boundary";
        const auto steps = gridSteps(result.corners);
        const double minStep = *std::min_element(steps.begin(), steps.end());
        result.data["grid_step_min_px"] = numberOrNull(minStep);
        result.data["grid_step_median_px"] = numberOrNull(percentile(steps, 0.5));
        result.data["grid_step_max_px"] = numberOrNull(*std::max_element(steps.begin(), steps.end()));
        if (minStep < 4) result.reasons << "grid_step_below_4px";
        else if (minStep < 8) result.warnings << "grid_step_below_recommended_8px";
        if (finite) {
            // Report the residual, without rejecting real lens distortion merely
            // because a pinhole homography cannot fit the raw image perfectly.
            std::vector<cv::Point2f> grid, projected;
            for (int y = 0; y < rows; ++y)
                for (int x = 0; x < columns; ++x) grid.emplace_back(float(x), float(y));
            const cv::Mat homography = cv::findHomography(grid, result.corners, 0);
            if (!homography.empty()) {
                cv::perspectiveTransform(grid, projected, homography);
                double squares = 0;
                std::vector<double> errors;
                for (size_t i = 0; i < projected.size(); ++i) {
                    const double error = cv::norm(projected[i] - result.corners[i]);
                    errors.push_back(error); squares += error * error;
                }
                result.data["homography_residual_px"] = QJsonObject{
                    {"rms", numberOrNull(std::sqrt(squares / errors.size()))},
                    {"p95", numberOrNull(percentile(errors, 0.95))},
                    {"max", numberOrNull(*std::max_element(errors.begin(), errors.end()))},
                    {"reject_on_residual", false}};
            }
            // Check the physical board edge, one square beyond its inner corners.
            QJsonArray outer;
            bool outerBoundary = false;
            const int indices[] = {0, columns - 1, columns * rows - 1, columns * (rows - 1)};
            for (int index : indices) {
                const int x = index % columns, y = index / columns;
                const auto p = result.corners[size_t(index)];
                const auto adjacentX = result.corners[size_t(index + (x == 0 ? 1 : -1))];
                const auto adjacentY = result.corners[size_t(index + (y == 0 ? columns : -columns))];
                const auto edge = 3 * p - adjacentX - adjacentY;
                outer.append(QJsonArray{edge.x, edge.y});
                outerBoundary = outerBoundary || edge.x <= 0 || edge.y <= 0 ||
                                edge.x >= width - 1 || edge.y >= height - 1;
            }
            result.data["board_outer_edge_estimate_px"] = outer;
            if (outerBoundary) result.reasons << "board_edge_touches_image_boundary";
            // Native pixel ROI metadata, not a resized or annotated input crop.
            const cv::Rect roi = cv::boundingRect(result.corners) & cv::Rect(0, 0, width, height);
            result.data["corner_roi_native_px"] = QJsonObject{
                {"x", roi.x}, {"y", roi.y}, {"width", roi.width}, {"height", roi.height}};
        }
    }
    if (classicFound != sbFound) result.warnings << "only_one_detector_found_board";
    result.usable = result.reasons.isEmpty();
    return result;
}

void alignRight(const Detection& left, Detection& right) {
    if (left.corners.size() != size_t(columns * rows) || right.corners.size() != left.corners.size()) return;
    const auto axis = [](const std::vector<cv::Point2f>& points, int index) {
        const auto vector = points[size_t(index)] - points[0];
        return vector / float(std::max(cv::norm(vector), 1e-9));
    };
    const double score = axis(left.corners, columns - 1).dot(axis(right.corners, columns - 1)) +
                        axis(left.corners, columns * (rows - 1)).dot(axis(right.corners, columns * (rows - 1)));
    const bool reverse = score < 0;
    if (reverse) std::reverse(right.corners.begin(), right.corners.end());
    right.data["pair_order_reversed_180"] = reverse;
}

QJsonObject detectionJson(Detection& detection) {
    QJsonArray corners;
    for (const auto& point : detection.corners) corners.append(QJsonArray{numberOrNull(point.x), numberOrNull(point.y)});
    detection.data["corners_px"] = corners;
    detection.data["usable"] = detection.usable;
    detection.data["rejection_reasons"] = QJsonArray::fromStringList(detection.reasons);
    detection.data["warnings"] = QJsonArray::fromStringList(detection.warnings);
    return detection.data;
}

QImage annotated(const QImage& image, const Detection& detection) {
    QImage output = image.copy();
    if (output.isNull()) throw std::runtime_error("cannot allocate corner overlay");
    cv::Mat rgb(height, width, CV_8UC3, output.bits(), size_t(output.bytesPerLine()));
    if (!detection.corners.empty()) cv::drawChessboardCorners(rgb, cv::Size(columns, rows), detection.corners,
                                                             detection.corners.size() == size_t(columns * rows));
    return output;
}

void savePng(const QString& path, const QImage& image) {
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) || !image.save(&file, "PNG") || !file.commit())
        throw std::runtime_error(QString("PNG save failed: %1 (%2)").arg(path, file.errorString()).toStdString());
}

struct SaveResult { QString path, message; bool usable = false; };

SaveResult saveCapture(const CalibrationCaptureJob& job, QString& partialPath) {
    if (!validJob(job, nowMs())) throw std::runtime_error("capture expired before processing (500ms limit)");
    const QString pair = QString("C%1_C%2").arg(job.leftCamera + 1).arg(job.rightCamera + 1);
    const QString name = "pair_" + QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz") + "_" +
                         QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString path = QDir(job.outputRoot).absoluteFilePath(pair + "/" + name);
    if (!QDir().mkpath(path)) throw std::runtime_error("cannot create capture directory");
    partialPath = path;
    // Keep original evidence even when board detection or subsequent I/O fails.
    savePng(path + "/left_raw.png", job.left);
    savePng(path + "/right_raw.png", job.right);
    Detection left = detect(job.left), right = detect(job.right);
    alignRight(left, right);
    const bool tagsMatch = job.leftTag == job.rightTag + quint32(job.tagOffset);
    const bool syncOK = !job.synchronizationConfirmed || !job.hasTagOffset || tagsMatch;
    const bool usable = left.usable && right.usable && syncOK;
    QStringList reasons;
    for (const auto& reason : left.reasons) reasons << "left: " + reason;
    for (const auto& reason : right.reasons) reasons << "right: " + reason;
    if (!syncOK) reasons << "confirmed_sync_tag_offset_mismatch";
    savePng(path + "/left_corners.png", annotated(job.left, left));
    savePng(path + "/right_corners.png", annotated(job.right, right));
    const auto cameraJson = [](int camera, quint64 sequence, quint32 tag, qint64 captured,
                               qint64 requested, const QString& raw, const QString& overlay,
                               Detection& detection) {
        return QJsonObject{{"camera_index", camera}, {"camera_name", QString("C%1").arg(camera + 1)},
            // Decimal strings preserve full uint64 frame counters in JSON readers.
            {"frame_sequence", QString::number(sequence)}, {"tag", double(tag)},
            {"captured_ms", double(captured)}, {"request_age_ms", double(requested - captured)},
            {"raw_file", raw}, {"corners_file", overlay}, {"detection", detectionJson(detection)}};
    };
    QJsonObject manifest{
        {"schema_version", 1}, {"complete", true}, {"source", "raw_camera"}, {"length_unit", "m"},
        {"image", QJsonObject{{"width", width}, {"height", height}, {"format", "RGB888"},
                             {"scaled", false}, {"hud", false}, {"pixel_rotation_applied", 0}}},
        {"board", QJsonObject{{"inner_columns", columns}, {"inner_rows", rows},
                             {"square_size_m", squareMeters}, {"corner_order", "row_major_6_columns_9_rows"},
                             {"canonicalization", "180_degree_reversal_only_same_camera_orientation"}}},
        {"distance_m", job.distanceMeters > 0 ? QJsonValue(job.distanceMeters) : QJsonValue(QJsonValue::Null)},
        {"distance_is_label", true}, {"source_generation", job.generation},
        {"requested_ms", double(job.requestedMs)}, {"timestamp_clock", "host_monotonic_ms"},
        {"created_at", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
        {"host_read_gap_ms", double(std::abs(job.leftCapturedMs - job.rightCapturedMs))},
        {"host_read_gap_is_exposure_sync", false},
        {"synchronization_confirmed", job.synchronizationConfirmed}, {"has_tag_offset", job.hasTagOffset},
        {"left_minus_right_tag_offset", job.hasTagOffset ? QJsonValue(job.tagOffset) : QJsonValue(QJsonValue::Null)},
        {"tag_offset_matches", job.hasTagOffset ? QJsonValue(tagsMatch) : QJsonValue(QJsonValue::Null)},
        {"static_scene_required", !(job.synchronizationConfirmed && job.hasTagOffset)},
        {"synchronization_note", "Host DMA read times do not establish exposure synchronization. Unconfirmed sync permits static-scene geometry calibration."},
        {"quality_limits", QJsonObject{{"corners_per_camera", 54}, {"grid_step_hard_min_px", 4},
            {"grid_step_recommended_min_px", 8}, {"detector_p95_max_px", 1}, {"detector_max_max_px", 2},
            {"freshness_max_ms", double(maxAgeMs)}}},
        {"left", cameraJson(job.leftCamera, job.leftSequence, job.leftTag, job.leftCapturedMs, job.requestedMs,
                            "left_raw.png", "left_corners.png", left)},
        {"right", cameraJson(job.rightCamera, job.rightSequence, job.rightTag, job.rightCapturedMs, job.requestedMs,
                             "right_raw.png", "right_corners.png", right)},
        {"pair_usable", usable}, {"rejection_reasons", QJsonArray::fromStringList(reasons)}};
    const QByteArray json = QJsonDocument(manifest).toJson(QJsonDocument::Indented);
    QSaveFile file(path + "/capture.json");
    if (!file.open(QIODevice::WriteOnly) || file.write(json) != json.size() || !file.commit())
        throw std::runtime_error(QString("manifest save failed: %1").arg(file.errorString()).toStdString());
    const QString label = QString("C%1/C%2").arg(job.leftCamera + 1).arg(job.rightCamera + 1);
    return {path, usable ? QString("%1 原图已保存 · 左54/右54角点 · 可用于标定%2").arg(label).arg(
                    job.synchronizationConfirmed && job.hasTagOffset ? "" : " · 棋盘需静止") :
                    QString("%1 原图已保存 · 左%2/右%3角点 · 本对未通过，请调整棋盘").arg(label)
                        .arg(left.corners.size()).arg(right.corners.size()), usable};
}
} // namespace

CalibrationCaptureWorker::CalibrationCaptureWorker(QObject* parent) : QThread(parent) {}

CalibrationCaptureWorker::~CalibrationCaptureWorker() {
    stop();
    // The owner must destroy this QThread in its owning thread, as with Qt workers.
    wait();
}

bool CalibrationCaptureWorker::submit(CalibrationCaptureJob job) {
    QMutexLocker lock(&mutex_);
    if (stopping_ || busy_ || !validJob(job, nowMs())) return false;
    // QImage can wrap DMA/external memory even when it is shared. A deep snapshot
    // here makes ownership independent of a producer reusing its frame buffer.
    job.left = job.left.copy();
    job.right = job.right.copy();
    if (job.left.isNull() || job.right.isNull() || !validJob(job, nowMs())) return false;
    pending_ = std::move(job);
    busy_ = true;
    changed_.wakeOne();
    return true;
}

void CalibrationCaptureWorker::stop() {
    QMutexLocker lock(&mutex_);
    stopping_ = true;
    changed_.wakeAll();
}

void CalibrationCaptureWorker::run() {
    for (;;) {
        CalibrationCaptureJob job;
        {
            QMutexLocker lock(&mutex_);
            while (!pending_ && !stopping_) changed_.wait(&mutex_);
            if (!pending_) return;
            job = std::move(*pending_);
            pending_.reset();
        }
        SaveResult result;
        try {
            result = saveCapture(job, result.path);
        } catch (const std::exception& error) {
            result.message = QString("calibration capture failed: %1; capture.json is the completion marker")
                                 .arg(QString::fromUtf8(error.what()));
            result.usable = false;
        } catch (...) {
            result.message = "calibration capture failed: unknown exception; capture.json is the completion marker";
            result.usable = false;
        }
        emit saved(job.generation, result.path, result.message, result.usable);
        {
            QMutexLocker lock(&mutex_);
            busy_ = false;
        }
    }
}

int runCalibrationCaptureSelfTest() {
    try {
        const auto check = [](bool condition, const char* message) {
            if (!condition) throw std::runtime_error(message);
        };
        QTemporaryDir directory;
        check(directory.isValid(), "temporary directory unavailable");
        const auto boardImage = [](int shift) {
            QImage image(width, height, QImage::Format_RGB888);
            image.fill(Qt::white);
            cv::Mat rgb(height, width, CV_8UC3, image.bits(), size_t(image.bytesPerLine()));
            constexpr int step = 32, originX = 190, originY = 70;
            // 7 x 10 squares yield 6 x 9 inner corners, away from every edge.
            for (int y = 0; y < rows + 1; ++y)
                for (int x = 0; x < columns + 1; ++x)
                    if ((x + y) % 2 == 0)
                        cv::rectangle(rgb, cv::Rect(originX + shift + x * step, originY + y * step, step, step),
                                      cv::Scalar(0, 0, 0), cv::FILLED);
            return image;
        };
        const QImage left = boardImage(0), right = boardImage(-12);
        const auto jobFor = [&](const QImage& a, const QImage& b) {
            CalibrationCaptureJob job;
            job.left = a; job.right = b; job.generation = 17;
            job.leftSequence = std::numeric_limits<quint64>::max(); job.rightSequence = 456;
            job.leftTag = 1; job.rightTag = std::numeric_limits<quint32>::max();
            job.hasTagOffset = true; job.tagOffset = 2;
            job.requestedMs = nowMs(); job.leftCapturedMs = job.requestedMs - 10;
            job.rightCapturedMs = job.requestedMs - 20; job.distanceMeters = 1.25;
            job.outputRoot = directory.path();
            return job;
        };
        CalibrationCaptureWorker validation;
        auto invalid = jobFor(left, right);
        invalid.left = left.convertToFormat(QImage::Format_RGB32);
        check(!validation.submit(invalid), "wrong pixel format accepted");
        invalid = jobFor(left, right); invalid.left = left.copy(0, 0, 320, 240);
        check(!validation.submit(invalid), "wrong shape accepted");
        invalid = jobFor(left, right); invalid.requestedMs -= 501;
        invalid.leftCapturedMs = invalid.rightCapturedMs = invalid.requestedMs;
        check(!validation.submit(invalid), "stale request accepted");
        invalid = jobFor(left, right); invalid.leftCapturedMs = invalid.requestedMs - 501;
        check(!validation.submit(invalid), "stale frame accepted");
        invalid = jobFor(left, right); invalid.rightCapturedMs = invalid.requestedMs + 1;
        check(!validation.submit(invalid), "future frame accepted");
        invalid = jobFor(left, right); invalid.requestedMs += 1000;
        check(!validation.submit(invalid), "future request accepted");
        invalid = jobFor(left, right); invalid.leftSequence = 0;
        check(!validation.submit(invalid), "zero sequence accepted");
        invalid = jobFor(left, right); invalid.rightCamera = invalid.leftCamera;
        check(!validation.submit(invalid), "same camera accepted twice");
        validation.stop();
        check(!validation.submit(jobFor(left, right)), "stopped worker accepted job");

        struct Completed {
            int count = 0, generation = 0;
            QString path, message;
            bool usable = false, notificationBusyRejected = false;
        };
        const auto runOne = [&](CalibrationCaptureJob job, bool mutateBorrowed) {
            CalibrationCaptureWorker worker;
            Completed completed;
            // Direct connection + wait() needs no Qt event loop, and wait joins
            // before the self-test reads data written by the worker thread.
            QObject::connect(&worker, &CalibrationCaptureWorker::saved, &worker,
                [&](int generation, QString path, QString message, bool usable) {
                    ++completed.count; completed.generation = generation;
                    completed.path = path; completed.message = message; completed.usable = usable;
                    // A reservation still exists throughout signal emission.
                    completed.notificationBusyRejected = !worker.submit(job);
                }, Qt::DirectConnection);
            QByteArray pixels;
            if (mutateBorrowed) {
                // Deliberately padded, external memory. Producer reuses it before
                // detection; the saved PNG must still equal the original board.
                const int stride = width * 3 + 16;
                pixels.resize(stride * height);
                for (int y = 0; y < height; ++y)
                    std::copy_n(job.left.constScanLine(y), width * 3,
                                reinterpret_cast<uchar*>(pixels.data()) + y * stride);
                job.left = QImage(reinterpret_cast<uchar*>(pixels.data()), width, height, stride, QImage::Format_RGB888);
            }
            check(worker.submit(job), "valid submission refused");
            check(!worker.submit(job), "pending job failed busy rejection");
            if (mutateBorrowed) pixels.fill(char(0));
            worker.start();
            worker.stop(); // Must drain the one accepted job even when stopped.
            check(worker.wait(60000), "capture did not finish within 60s");
            check(completed.count == 1 && completed.generation == 17, "missing/duplicate/wrong-generation signal");
            check(completed.notificationBusyRejected, "compute/notification accepted queued job");
            check(!worker.submit(job), "worker accepted after stop");
            return completed;
        };
        const auto readManifest = [&](const QString& path) {
            QFile file(path + "/capture.json");
            check(file.open(QIODevice::ReadOnly), "manifest not saved");
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(file.readAll(), &error);
            check(error.error == QJsonParseError::NoError && document.isObject(), "invalid manifest JSON");
            return document.object();
        };
        auto good = runOne(jobFor(left, right), true);
        check(good.usable, good.message.toUtf8().constData());
        check(QDir(good.path).dirName().startsWith("pair_") &&
              QDir(QDir::cleanPath(good.path + "/..")).dirName() == "C1_C2", "wrong pair directory layout");
        check(QImage(good.path + "/left_raw.png").convertToFormat(QImage::Format_RGB888) == left,
              "raw left pixels or external-memory ownership corrupted");
        check(QImage(good.path + "/right_raw.png").convertToFormat(QImage::Format_RGB888) == right,
              "raw right pixels changed");
        check(QImage(good.path + "/left_corners.png").size() == QSize(width, height) &&
              QImage(good.path + "/right_corners.png").size() == QSize(width, height), "overlay shape changed");
        const auto manifest = readManifest(good.path);
        check(manifest["source"].toString() == "raw_camera" && manifest["length_unit"].toString() == "m" &&
              manifest["complete"].toBool() && manifest["pair_usable"].toBool(), "source/schema/quality metadata wrong");
        check(manifest["distance_m"].toDouble() == 1.25 && manifest["source_generation"].toInt() == 17 &&
              !manifest["synchronization_confirmed"].toBool() && manifest["static_scene_required"].toBool() &&
              !manifest["host_read_gap_is_exposure_sync"].toBool() && manifest["tag_offset_matches"].toBool(),
              "distance or unconfirmed sync metadata wrong");
        const auto lm = manifest["left"].toObject(), rm = manifest["right"].toObject();
        check(lm["tag"].toDouble() == 1 && rm["tag"].toDouble() == double(std::numeric_limits<quint32>::max()) &&
              lm["frame_sequence"].toString() == QString::number(std::numeric_limits<quint64>::max()),
              "tag wrap or uint64 sequence precision lost");
        const auto lc = lm["detection"].toObject()["corners_px"].toArray();
        const auto rc = rm["detection"].toObject()["corners_px"].toArray();
        check(lc.size() == 54 && rc.size() == 54, "wrong inner corner count");
        for (int i = 0; i < lc.size(); ++i) {
            const auto a = lc[i].toArray(), b = rc[i].toArray();
            check(std::abs(a[0].toDouble() - b[0].toDouble() - 12) < 0.5 &&
                  std::abs(a[1].toDouble() - b[1].toDouble()) < 0.5, "left/right grid order inconsistent");
        }
        QImage blank(width, height, QImage::Format_RGB888); blank.fill(Qt::gray);
        auto blankJob = jobFor(blank, blank); blankJob.distanceMeters = 0;
        const auto rejected = runOne(blankJob, false);
        const auto blankManifest = readManifest(rejected.path);
        check(!rejected.usable && !blankManifest["pair_usable"].toBool() && blankManifest["distance_m"].isNull(),
              "blank pair or unknown distance accepted");
        check(QImage(rejected.path + "/left_raw.png").convertToFormat(QImage::Format_RGB888) == blank &&
              QImage(rejected.path + "/right_raw.png").convertToFormat(QImage::Format_RGB888) == blank,
              "rejected raw evidence missing");
        check(QImage(rejected.path + "/left_corners.png").size() == QSize(width, height) &&
              QImage(rejected.path + "/right_corners.png").size() == QSize(width, height),
              "rejected overlays missing");
        auto mismatchJob = jobFor(left, right); mismatchJob.synchronizationConfirmed = true; mismatchJob.tagOffset = 3;
        const auto mismatch = runOne(mismatchJob, false);
        check(!mismatch.usable && !readManifest(mismatch.path)["tag_offset_matches"].toBool(),
              "confirmed sync tag mismatch accepted");
        QFile blockedRoot(directory.path() + "/not_a_directory");
        check(blockedRoot.open(QIODevice::WriteOnly), "cannot create I/O failure fixture");
        blockedRoot.close();
        auto ioJob = jobFor(blank, blank); ioJob.outputRoot = blockedRoot.fileName();
        const auto failure = runOne(ioJob, false);
        check(!failure.usable && failure.path.isEmpty() && failure.message.contains("failed"),
              "I/O exception did not produce a safe failure signal");
        std::cout << "CALIBRATION_CAPTURE_SELFTEST_PASS\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "CALIBRATION_CAPTURE_SELFTEST_FAIL: " << error.what() << '\n';
        return 1;
    }
}
