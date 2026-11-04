#pragma once

#include <opencv2/calib3d.hpp>
#include <opencv2/core.hpp>

#include <string>

namespace stereo {

struct MatcherOptions {
    int numDisparities = 64;
    int blockSize = 5;
    double scale = 0.5;
    int uniquenessRatio = 10;
    double lrMaxDiff = 1.5;
};

struct Calibration {
    cv::Size imageSize;
    cv::Mat K1, D1, K2, D2, R, T;
    // Throws std::invalid_argument (including malformed/missing YAML fields).
    // In-memory Calibration values use the same convention: T is in meters.
    static Calibration load(const std::string& path);
};

struct DepthResult {
    cv::Mat left, right;       // Resized, rectified if calibrated; original pixel type.
    cv::Mat disparity;        // CV_32FC1, processed-image pixels; invalid values are NaN.
    cv::Mat validMask;        // CV_8UC1, 255 = accepted, 0 = rejected.
    double fxPixels = 0, baselineMeters = 0, cxOffsetPixels = 0;
    bool calibrated = false;
};

struct RangeEstimate {
    bool valid = false;
    double meters = 0, medianDisparity = 0;
    int validPixels = 0, totalPixels = 0;
    std::string reason;
};

class DepthEngine {
public:
    // Owns a deep copy of calibration. Throws on invalid options/calibration.
    explicit DepthEngine(MatcherOptions options, const Calibration* calibration = nullptr);
    // Equal-size, equal-type CV_8UC1/BGR/BGRA pairs only. Calibrated input must
    // match imageSize exactly. One engine instance must not be used concurrently.
    DepthResult compute(const cv::Mat& left, const cv::Mat& right);
    // ROI coordinates refer to result.left. Outside/empty ROIs are rejected,
    // not clipped. Returns median optical-axis Z, not Euclidean range.
    static RangeEstimate estimate(const DepthResult&, const cv::Rect&,
                                  int minimumValidPixels = 20,
                                  double minimumValidFraction = 0.2);

private:
    void prepareGeometry(const cv::Size& inputSize, const cv::Size& outputSize);

    MatcherOptions options_;
    Calibration calibration_;
    bool calibrated_ = false;
    cv::Ptr<cv::StereoSGBM> leftMatcher_, rightMatcher_;
    cv::Size preparedInputSize_, preparedOutputSize_;
    cv::Mat leftMapX_, leftMapY_, rightMapX_, rightMapY_;
    cv::Mat leftGeometryMask_, rightGeometryMask_;
    cv::Rect matchingRoi_;
    double fxPixels_ = 0, baselineMeters_ = 0, cxOffsetPixels_ = 0;
};

// Offline only: synthetic fixtures, no hardware or filesystem writes. 0 = pass.
int runSelfTest();

} // namespace stereo
