#pragma once

#include <QImage>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QMetaType>
#include <cstdint>
#include <limits>
#include <vector>
#include "fpga_infer_input.h"
#include "motion_policy.h"
#include "acquisition_epoch.h"
Q_DECLARE_METATYPE(acquisition::Ticket)

struct Detection {
    int cls = 0;
    float score = 0;
    float x1 = 0, y1 = 0, x2 = 0, y2 = 0; // 640x640 model pixels, 80px vertical padding
    uint64_t trackId = 0;
    float matchScore = 0;
    bool predicted = false;
    double depthMeters = std::numeric_limits<double>::quiet_NaN();
    int depthAgeMs = 0;
    qint64 depthCapturedMs = 0; // monotonic; the renderer independently expires metric labels
    qint64 validUntilMs = 0;
    QString depthStatus; // Empty for nonvehicles; otherwise invalid reason or explicit trial label.
    bool depthTrial = false; // Valid metric is an explicit static-scene diagnostic.
    double cpuDepthMeters = std::numeric_limits<double>::quiet_NaN();
    qint64 cpuDepthCapturedMs = 0; // Independent single-camera road-plane estimate.
    // 单目部分解算（mono_partial）：路面近似米数与分级，状态只在 CPU 测距线程内存里。
    double monoMeters = std::numeric_limits<double>::quiet_NaN();
    qint64 monoCapturedMs = 0;
    int monoGrade = 0;  // 0 none, 1 uncertain("约N米?"), 2 approx("约N米")
    int monoMethod = 0; // 0 none, 1 ground, 2 width
    // ---- 单目目标运动（mono_motion，实验开关默认关闭） ----
    // observedMs：产生这个框的那次观测的时刻（单调 ms），由跟踪器给出；0=未知。
    // 与 capturedMs（本帧）不同：预测框/复用框不能拿当前帧时间冒充观测时间。
    qint64 observedMs = 0;
    // 车道内横向位置：归一化 [-0.5,+0.5]，中心 0、左负右正。
    float laneOffset = std::numeric_limits<float>::quiet_NaN();
    bool laneOffsetKnown = false;
    float laneOffsetLocal = std::numeric_limits<float>::quiet_NaN(); // diagnostic only
    bool laneOffsetLocalKnown = false;
    QString laneOffsetReason;
    // 纵向相对速度（m/s，负=接近；相对本车，不是目标绝对车速）。
    float motionVz = std::numeric_limits<float>::quiet_NaN();
    float motionSigmaV = std::numeric_limits<float>::quiet_NaN();
    int motionTrend = 0; // mono_motion::Trend：0 未知，1 接近，2 平稳，3 远离
    bool motionValid = false;
    // Same-source ground-plane geometry for 2D trajectory projection (640x480).
    double motionA=std::numeric_limits<double>::quiet_NaN();
    double motionVh=std::numeric_limits<double>::quiet_NaN();
    double motionHc=std::numeric_limits<double>::quiet_NaN();
    qint64 motionGeometryMs=0;
};
Q_DECLARE_METATYPE(Detection)
Q_DECLARE_METATYPE(QVector<Detection>)

struct VisionFrame {
    bool syntheticBlack = false; // Padding job, not a camera acquisition or evidence.
    acquisition::Ticket acquisition;
    QImage image; // owned RGB888, 640x480 camera pixels (no model padding)
    quint64 frameId = 0;
    int camera = 0; // zero-based; video source is 0
    int sourceGeneration = 0;
    quint32 tag = 0;
    qint64 capturedMs = 0; // CLOCK_MONOTONIC host DMA read completion, not exposure time
    std::shared_ptr<scheme2::Input> fpgaInput;
    bool cameraAcquisition = false;
    motion::Evidence motion;
    quint64 continuity=0; // Advances when a local video loops to its beginning.
};
Q_DECLARE_METATYPE(VisionFrame)

struct StereoPairOptions {
    int left = -1; // zero-based C1..C6
    int right = -1;
    QString calibrationPath;
    bool synchronizationConfirmed = false;
    bool hasTagOffset = false;
    int tagOffset = 0; // left.tag == right.tag + offset (modulo 2^32)
    int intervalMs = 0; // 0 inherits stereoIntervalMs (default 200ms); otherwise 100..5000
    bool valid() const { return left >= 0 && left < 6 && right >= 0 && right < 6 && left != right; }
};

struct VisionOptions {
    bool motionEnabled = true;
    int motionRefreshIntervalMs = 250;
    bool tracking = true;
    bool stereoTrialMeters = false; // Explicit static-scene diagnostic, never synchronization confirmation.
    bool stereoVehicleTrial = false; // Together with stereoTrialMeters, permits unsynchronized vehicle ROI trials.
    int detectionIntervalMs = 250; // total NPU submissions, models remain round-robin
    int minimumDetectionIntervalMs = 100;
    int trackingMaxDetectionAgeMs = 2000;
    int trackingIntervalMs = 33; // captured-time cadence, 0 processes every new frame; 0..200
    int maxTemplateSide = 48; // 0 reference/unbounded; otherwise 16..128 working pixels
    int maxTracks = 12;
    // Explicit groups replace the legacy fields below. No pair is enabled by default.
    std::vector<StereoPairOptions> stereoGroups;
    int stereoLeft = -1;
    int stereoRight = -1;
    QString calibrationPath;
    bool synchronizationConfirmed = false;
    bool hasTagOffset = false;
    int tagOffset = 0;
    int stereoIntervalMs = 200;
    double stereoScale = 0.25;
    int stereoDisparities = 32;
    QString stereoConfigurationError() const {
        std::vector<StereoPairOptions> pairs = stereoGroups;
        if (pairs.empty()) {
            if (stereoLeft == -1 && stereoRight == -1) return {};
            pairs.push_back({stereoLeft, stereoRight, calibrationPath,
                             synchronizationConfirmed, hasTagOffset, tagOffset});
        }
        if (pairs.size() > 2) return QStringLiteral("at most two stereo groups are supported");
        quint32 used = 0;
        for (const auto& pair : pairs) {
            if (!pair.valid()) return QStringLiteral("stereo cameras must be distinct C1..C6");
            if (pair.intervalMs != 0 && (pair.intervalMs < 100 || pair.intervalMs > 5000))
                return QStringLiteral("stereo group intervalMs must be 0 or 100..5000");
            const quint32 mask = (quint32(1) << pair.left) | (quint32(1) << pair.right);
            if (used & mask) return QStringLiteral("stereo groups must use distinct cameras");
            used |= mask;
        }
        return {};
    }
    std::vector<StereoPairOptions> stereoPairs() const {
        if (!stereoConfigurationError().isEmpty()) return {};
        if (!stereoGroups.empty()) return stereoGroups;
        if (stereoLeft < 0 || stereoRight < 0) return {};
        return {{stereoLeft, stereoRight, calibrationPath,
                 synchronizationConfirmed, hasTagOffset, tagOffset}};
    }
    int stereoCameraMask() const {
        quint32 mask = 0;
        for (const auto& pair : stereoPairs())
            mask |= (quint32(1) << pair.left) | (quint32(1) << pair.right);
        return int(mask);
    }
    int primaryStereoLeft() const {
        const auto pairs = stereoPairs();
        return pairs.empty() ? -1 : pairs.front().left;
    }
    QString stereoSummary() const {
        const auto error = stereoConfigurationError();
        if (!error.isEmpty()) return error;
        QStringList labels;
        for (const auto& pair : stereoPairs())
            labels.push_back(QStringLiteral("C%1/C%2").arg(pair.left + 1).arg(pair.right + 1));
        return labels.isEmpty() ? QStringLiteral("stereo disabled") : labels.join(QStringLiteral(", "));
    }
    bool stereoEnabled() const { return !stereoPairs().empty(); }
};
