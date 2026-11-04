#include "stereo_depth.h"

#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <vector>

namespace stereo {
namespace {

void require(bool condition, const std::string& message) {
    if (!condition) {
        throw std::invalid_argument(message);
    }
}

cv::Mat finiteMatrix(const cv::Mat& input, const char* name) {
    require(!input.empty() && input.dims == 2 && input.channels() == 1,
            std::string(name) + " must be a nonempty single-channel matrix");
    require(input.depth() == CV_32F || input.depth() == CV_64F,
            std::string(name) + " must contain floating-point values");
    cv::Mat output;
    input.convertTo(output, CV_64F);
    for (int y = 0; y < output.rows; ++y) {
        for (int x = 0; x < output.cols; ++x) {
            require(std::isfinite(output.at<double>(y, x)),
                    std::string(name) + " contains a non-finite value");
        }
    }
    return output;
}

cv::Mat intrinsics(const cv::Mat& input, const char* name) {
    cv::Mat k = finiteMatrix(input, name);
    require(k.rows == 3 && k.cols == 3, std::string(name) + " must be 3x3");
    require(k.at<double>(0, 0) > 0 && k.at<double>(1, 1) > 0,
            std::string(name) + " must have positive focal lengths");
    require(std::abs(k.at<double>(0, 1)) < 1e-9 &&
                std::abs(k.at<double>(1, 0)) < 1e-9 &&
                std::abs(k.at<double>(2, 0)) < 1e-9 &&
                std::abs(k.at<double>(2, 1)) < 1e-9 &&
                std::abs(k.at<double>(2, 2) - 1.0) < 1e-9,
            std::string(name) + " must use the OpenCV pinhole intrinsic form");
    return k;
}

cv::Mat distortion(const cv::Mat& input, const char* name) {
    cv::Mat d = finiteMatrix(input, name);
    const size_t n = d.total();
    require((d.rows == 1 || d.cols == 1) &&
                (n == 4 || n == 5 || n == 8 || n == 12 || n == 14),
            std::string(name) + " must be a 4/5/8/12/14-element pinhole distortion vector");
    return d.reshape(1, static_cast<int>(n)).clone();
}

Calibration validatedCalibration(const Calibration& input) {
    require(input.imageSize.width > 0 && input.imageSize.height > 0,
            "calibration image dimensions must be positive");
    Calibration c;
    c.imageSize = input.imageSize;
    c.K1 = intrinsics(input.K1, "K1");
    c.K2 = intrinsics(input.K2, "K2");
    c.D1 = distortion(input.D1, "D1");
    c.D2 = distortion(input.D2, "D2");
    c.R = finiteMatrix(input.R, "R");
    require(c.R.rows == 3 && c.R.cols == 3, "R must be 3x3");
    require(cv::norm(c.R.t() * c.R - cv::Mat::eye(3, 3, CV_64F), cv::NORM_INF) < 1e-5 &&
                std::abs(cv::determinant(c.R) - 1.0) < 1e-5,
            "R must be an orthonormal proper rotation (determinant +1)");
    c.T = finiteMatrix(input.T, "T");
    require((c.T.rows == 3 && c.T.cols == 1) || (c.T.rows == 1 && c.T.cols == 3),
            "T must be 3x1 or 1x3, in meters");
    c.T = c.T.reshape(1, 3).clone();
    const double baseline = cv::norm(c.T);
    require(std::isfinite(baseline) && baseline > 1e-9,
            "T must have a finite nonzero baseline in meters");
    return c;
}

struct Rectification {
    cv::Mat r1, r2, p1, p2;
    cv::Rect roi1, roi2;
    double fx = 0, baseline = 0, cxOffset = 0;
};

Rectification rectify(const Calibration& c, const cv::Size& size) {
    cv::Mat k1 = c.K1.clone(), k2 = c.K2.clone();
    const double sx = static_cast<double>(size.width) / c.imageSize.width;
    const double sy = static_cast<double>(size.height) / c.imageSize.height;
    for (int x = 0; x < 3; ++x) {
        k1.at<double>(0, x) *= sx;
        k1.at<double>(1, x) *= sy;
        k2.at<double>(0, x) *= sx;
        k2.at<double>(1, x) *= sy;
    }
    Rectification result;
    cv::Mat q;
    // Keep separate principal points: depth must account for cxOffset.
    cv::stereoRectify(k1, c.D1, k2, c.D2, size, c.R, c.T,
                      result.r1, result.r2, result.p1, result.p2, q,
                      0, 0.0, size, &result.roi1, &result.roi2);
    result.p1 = finiteMatrix(result.p1, "rectified P1");
    result.p2 = finiteMatrix(result.p2, "rectified P2");
    const double tx = result.p2.at<double>(0, 3);
    const double ty = result.p2.at<double>(1, 3);
    require(std::abs(tx) > 1e-12 && std::abs(ty) <= std::abs(tx) * 1e-8,
            "only horizontal stereo is supported; vertical stereo is rejected");
    require(tx < 0, "left/right order must yield positive disparity (rectified T.x < 0)");
    result.fx = result.p1.at<double>(0, 0);
    const double rightFx = result.p2.at<double>(0, 0);
    require(result.fx > 0 && rightFx > 0, "rectified focal lengths must be positive");
    result.baseline = std::abs(tx / rightFx);
    result.cxOffset = result.p1.at<double>(0, 2) - result.p2.at<double>(0, 2);
    require(std::isfinite(result.baseline) && result.baseline > 0 &&
                std::isfinite(result.cxOffset), "invalid rectified metric geometry");
    return result;
}

cv::Mat mapMask(const cv::Mat& mapX, const cv::Mat& mapY, const cv::Size& inputSize) {
    cv::Mat mask(mapX.size(), CV_8U, cv::Scalar(0));
    for (int y = 0; y < mapX.rows; ++y) {
        for (int x = 0; x < mapX.cols; ++x) {
            const float mx = mapX.at<float>(y, x), my = mapY.at<float>(y, x);
            if (std::isfinite(mx) && std::isfinite(my) && mx >= 0 && my >= 0 &&
                mx <= inputSize.width - 1 && my <= inputSize.height - 1) {
                mask.at<unsigned char>(y, x) = 255;
            }
        }
    }
    return mask;
}

cv::Mat gray(const cv::Mat& input) {
    if (input.channels() == 1) {
        return input;
    }
    cv::Mat output;
    cv::cvtColor(input, output, input.channels() == 3 ? cv::COLOR_BGR2GRAY : cv::COLOR_BGRA2GRAY);
    return output;
}

cv::Mat textureMask(const cv::Mat& image, int blockSize) {
    cv::Mat f, mean, meanSquare, variance, mask;
    image.convertTo(f, CV_32F);
    const cv::Size window(std::max(5, blockSize), std::max(5, blockSize));
    cv::boxFilter(f, mean, CV_32F, window);
    cv::boxFilter(f.mul(f), meanSquare, CV_32F, window);
    variance = meanSquare - mean.mul(mean);
    // A flat patch cannot establish a reliable correspondence.
    cv::compare(variance, 1.0, mask, cv::CMP_GE);
    return mask;
}

double median(std::vector<double>& values) {
    const size_t middle = values.size() / 2;
    std::nth_element(values.begin(), values.begin() + middle, values.end());
    const double upper = values[middle];
    if (values.size() % 2 != 0) {
        return upper;
    }
    const double lower = *std::max_element(values.begin(), values.begin() + middle);
    return lower * 0.5 + upper * 0.5;
}

} // namespace

Calibration Calibration::load(const std::string& path) {
    try {
        cv::FileStorage fs(path, cv::FileStorage::READ);
        require(fs.isOpened(), "cannot open calibration: " + path);
        const cv::FileNode width = fs["image_width"], height = fs["image_height"];
        require(width.isInt() && height.isInt(), "image_width/image_height must be integers");
        const cv::FileNode unit = fs["length_unit"];
        require(unit.isString() && static_cast<std::string>(unit) == "m",
                "length_unit must explicitly be m");
        Calibration c;
        c.imageSize = cv::Size(static_cast<int>(width), static_cast<int>(height));
        const char* names[] = {"K1", "D1", "K2", "D2", "R", "T"};
        cv::Mat* matrices[] = {&c.K1, &c.D1, &c.K2, &c.D2, &c.R, &c.T};
        for (int i = 0; i < 6; ++i) {
            require(fs[names[i]].isMap(), std::string(names[i]) + " must be an OpenCV matrix");
            fs[names[i]] >> *matrices[i];
        }
        c = validatedCalibration(c);
        (void)rectify(c, c.imageSize);
        return c;
    } catch (const cv::Exception& e) {
        throw std::invalid_argument(std::string("invalid calibration YAML: ") + e.what());
    }
}

DepthEngine::DepthEngine(MatcherOptions options, const Calibration* calibration)
    : options_(options) {
    require(options.numDisparities > 0 && options.numDisparities % 16 == 0 &&
                options.numDisparities <= 2032,
            "numDisparities must be a positive multiple of 16, at most 2032");
    require(options.blockSize >= 1 && options.blockSize <= 255 && options.blockSize % 2 == 1,
            "blockSize must be odd, in [1,255]");
    require(std::isfinite(options.scale) && options.scale > 0 && options.scale <= 1,
            "scale must be finite and in (0,1]");
    require(options.uniquenessRatio >= 0 && options.uniquenessRatio <= 100,
            "uniquenessRatio must be in [0,100]");
    require(std::isfinite(options.lrMaxDiff) && options.lrMaxDiff >= 0,
            "lrMaxDiff must be finite and nonnegative");
    if (calibration) {
        try {
            calibration_ = validatedCalibration(*calibration);
            (void)rectify(calibration_, calibration_.imageSize);
            calibrated_ = true;
        } catch (const cv::Exception& e) {
            throw std::invalid_argument(std::string("invalid stereo calibration: ") + e.what());
        }
    }
    const int p1 = 8 * options.blockSize * options.blockSize;
    const int p2 = 32 * options.blockSize * options.blockSize;
    auto matcher = [&](int minDisparity) {
        return cv::StereoSGBM::create(minDisparity, options.numDisparities,
                                      options.blockSize, p1, p2, -1, 31,
                                      options.uniquenessRatio, 0, 0, cv::StereoSGBM::MODE_SGBM);
    };
    leftMatcher_ = matcher(0);
    // Right disparity is x_right - x_left; its invalid sentinel is (-N-1)*16.
    rightMatcher_ = matcher(-options.numDisparities);
}

void DepthEngine::prepareGeometry(const cv::Size& inputSize, const cv::Size& outputSize) {
    if (preparedInputSize_ == inputSize && preparedOutputSize_ == outputSize) {
        return;
    }
    cv::Rect roi1(0, 0, outputSize.width, outputSize.height), roi2 = roi1;
    if (calibrated_) {
        const Rectification r = rectify(calibration_, outputSize);
        // Map directly from full-resolution input to the rectified scaled grid.
        // Distortion stays unchanged; focal lengths/principal points use the
        // actual rounded output dimensions, not just the requested scale.
        cv::initUndistortRectifyMap(calibration_.K1, calibration_.D1, r.r1, r.p1,
                                    outputSize, CV_32FC1, leftMapX_, leftMapY_);
        cv::initUndistortRectifyMap(calibration_.K2, calibration_.D2, r.r2, r.p2,
                                    outputSize, CV_32FC1, rightMapX_, rightMapY_);
        leftGeometryMask_ = mapMask(leftMapX_, leftMapY_, inputSize);
        rightGeometryMask_ = mapMask(rightMapX_, rightMapY_, inputSize);
        roi1 = r.roi1;
        roi2 = r.roi2;
        fxPixels_ = r.fx;
        baselineMeters_ = r.baseline;
        cxOffsetPixels_ = r.cxOffset;
    } else {
        leftGeometryMask_ = cv::Mat(outputSize, CV_8U, cv::Scalar(255));
        rightGeometryMask_ = cv::Mat(outputSize, CV_8U, cv::Scalar(255));
    }
    matchingRoi_ = cv::getValidDisparityROI(roi1, roi2, 0, options_.numDisparities,
                                          options_.blockSize);
    require(!matchingRoi_.empty(), "processed image has no valid SGBM search region");
    preparedInputSize_ = inputSize;
    preparedOutputSize_ = outputSize;
}

DepthResult DepthEngine::compute(const cv::Mat& left, const cv::Mat& right) {
    require(!left.empty() && !right.empty() && left.dims == 2 && right.dims == 2,
            "stereo inputs must be nonempty 2D images");
    require(left.size() == right.size() && left.type() == right.type(),
            "stereo inputs must have matching sizes and types");
    require(left.depth() == CV_8U &&
                (left.channels() == 1 || left.channels() == 3 || left.channels() == 4),
            "stereo inputs must be CV_8UC1, CV_8UC3 (BGR), or CV_8UC4 (BGRA)");
    require(!calibrated_ || left.size() == calibration_.imageSize,
            "input size must exactly match calibration image_width/image_height");
    const cv::Size outputSize(cvRound(left.cols * options_.scale), cvRound(left.rows * options_.scale));
    require(outputSize.width > options_.numDisparities + options_.blockSize &&
                outputSize.height >= options_.blockSize,
            "scaled input is too small for numDisparities/blockSize");
    prepareGeometry(left.size(), outputSize);
    DepthResult result;
    result.calibrated = calibrated_;
    result.fxPixels = fxPixels_;
    result.baselineMeters = baselineMeters_;
    result.cxOffsetPixels = cxOffsetPixels_;
    if (calibrated_) {
        cv::remap(left, result.left, leftMapX_, leftMapY_, cv::INTER_LINEAR, cv::BORDER_CONSTANT);
        cv::remap(right, result.right, rightMapX_, rightMapY_, cv::INTER_LINEAR, cv::BORDER_CONSTANT);
    } else {
        cv::resize(left, result.left, outputSize, 0, 0, cv::INTER_AREA);
        cv::resize(right, result.right, outputSize, 0, 0, cv::INTER_AREA);
    }
    const cv::Mat leftGray = gray(result.left), rightGray = gray(result.right);
    const cv::Mat leftTexture = textureMask(leftGray, options_.blockSize);
    const cv::Mat rightTexture = textureMask(rightGray, options_.blockSize);
    cv::Mat leftFixed, rightFixed;
    leftMatcher_->compute(leftGray, rightGray, leftFixed);
    rightMatcher_->compute(rightGray, leftGray, rightFixed);
    result.disparity = cv::Mat(outputSize, CV_32F,
                               cv::Scalar(std::numeric_limits<float>::quiet_NaN()));
    result.validMask = cv::Mat(outputSize, CV_8U, cv::Scalar(0));
    const int leftInvalid = -16;
    const int rightInvalid = (-options_.numDisparities - 1) * 16;
    for (int y = matchingRoi_.y; y < matchingRoi_.y + matchingRoi_.height; ++y) {
        for (int x = matchingRoi_.x; x < matchingRoi_.x + matchingRoi_.width; ++x) {
            const int dlFixed = leftFixed.at<short>(y, x);
            if (dlFixed <= leftInvalid || !leftGeometryMask_.at<unsigned char>(y, x) ||
                !leftTexture.at<unsigned char>(y, x)) {
                continue;
            }
            const double d = dlFixed / 16.0;
            const double rightX = x - d;
            if (!std::isfinite(d) || d < 0 || d >= options_.numDisparities ||
                rightX < 0 || rightX > outputSize.width - 1) {
                continue;
            }
            const int xr = cvRound(rightX);
            const int drFixed = rightFixed.at<short>(y, xr);
            if (drFixed <= rightInvalid || !rightGeometryMask_.at<unsigned char>(y, xr) ||
                !rightTexture.at<unsigned char>(y, xr)) {
                continue;
            }
            const double dr = drFixed / 16.0;
            if (dr < -options_.numDisparities || dr > 0 ||
                std::abs(d + dr) > options_.lrMaxDiff) {
                continue;
            }
            const double denominator = d - result.cxOffsetPixels;
            if (!(denominator > 0) || !std::isfinite(denominator)) {
                continue;
            }
            if (calibrated_) {
                const double depth = result.fxPixels * result.baselineMeters / denominator;
                if (!(depth > 0) || !std::isfinite(depth)) {
                    continue;
                }
            }
            result.disparity.at<float>(y, x) = static_cast<float>(d);
            result.validMask.at<unsigned char>(y, x) = 255;
        }
    }
    return result;
}

RangeEstimate DepthEngine::estimate(const DepthResult& result, const cv::Rect& roi,
                                    int minimumValidPixels, double minimumValidFraction) {
    require(minimumValidPixels > 0 && std::isfinite(minimumValidFraction) &&
                minimumValidFraction >= 0 && minimumValidFraction <= 1,
            "ROI thresholds require minimumValidPixels > 0 and fraction in [0,1]");
    RangeEstimate estimate;
    if (!result.calibrated) {
        estimate.reason = "calibration required for metric depth";
        return estimate;
    }
    if (!std::isfinite(result.fxPixels) || result.fxPixels <= 0 ||
        !std::isfinite(result.baselineMeters) || result.baselineMeters <= 0 ||
        !std::isfinite(result.cxOffsetPixels)) {
        estimate.reason = "invalid calibrated metric geometry";
        return estimate;
    }
    if (result.disparity.empty() || result.disparity.dims != 2 ||
        result.disparity.type() != CV_32FC1 || result.validMask.type() != CV_8UC1 ||
        result.validMask.dims != 2 || result.validMask.size() != result.disparity.size()) {
        estimate.reason = "missing or inconsistent disparity/valid mask";
        return estimate;
    }
    const int64_t area = static_cast<int64_t>(roi.width) * roi.height;
    if (roi.x < 0 || roi.y < 0 || roi.width <= 0 || roi.height <= 0 ||
        static_cast<int64_t>(roi.x) + roi.width > result.disparity.cols ||
        static_cast<int64_t>(roi.y) + roi.height > result.disparity.rows ||
        area > std::numeric_limits<int>::max()) {
        estimate.reason = "ROI is empty or outside the processed image";
        return estimate;
    }
    estimate.totalPixels = static_cast<int>(area);
    std::vector<double> depths, disparities;
    for (int y = roi.y; y < roi.y + roi.height; ++y) {
        for (int x = roi.x; x < roi.x + roi.width; ++x) {
            if (!result.validMask.at<unsigned char>(y, x)) {
                continue;
            }
            const double d = result.disparity.at<float>(y, x);
            const double denominator = d - result.cxOffsetPixels;
            if (!std::isfinite(d) || !std::isfinite(denominator) || denominator <= 0) {
                continue;
            }
            const double z = result.fxPixels * result.baselineMeters / denominator;
            if (!std::isfinite(z) || z <= 0) {
                continue;
            }
            disparities.push_back(d);
            depths.push_back(z);
        }
    }
    estimate.validPixels = static_cast<int>(depths.size());
    if (estimate.validPixels < minimumValidPixels) {
        estimate.reason = "insufficient valid pixels in ROI";
        return estimate;
    }
    if (static_cast<double>(estimate.validPixels) / estimate.totalPixels < minimumValidFraction) {
        estimate.reason = "valid pixel fraction below ROI threshold";
        return estimate;
    }
    estimate.meters = median(depths);
    estimate.medianDisparity = median(disparities);
    estimate.valid = true;
    return estimate;
}

} // namespace stereo
