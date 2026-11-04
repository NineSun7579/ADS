#pragma once
#include "bev_lane_calibration.h"
#include "bev_native_roi.h"
#include <QByteArray>
#include <QDataStream>
#include <QFile>
#include <QIODevice>
#include <QMutex>
#include <QMutexLocker>
#include <opencv2/imgproc.hpp>
#include <vector>

namespace bev_lane {
inline Transform makeNativeRoiTransform(const Calibration& c) {
    // Calibrate for the complete native 640x960 frame first, then translate
    // its principal point into the bottom-centered 480x360 ROI.
    Transform t;t.inputWidth=NativeRoi::width;t.inputHeight=NativeRoi::height;
    const double sx=double(NativeRoi::halfWidth)/640.0;
    const double sy=double(NativeRoi::halfHeight)/360.0;
    const double fx=c.fx*sx,fy=c.fy*sy;
    const double cx=c.cx*sx-NativeRoi::x,cy=c.cy*sy-NativeRoi::y;
    const double a=c.pitchDegrees*3.14159265358979323846/180.0;
    const double ca=std::cos(a),sa=std::sin(a),h=c.cameraHeight;
    const cv::Matx33d rotation(-1.0,0.0,0.0,0.0,sa,ca,0.0,ca,-sa);
    const cv::Matx33d intrinsics(fx,0.0,0.0,0.0,fy,0.0,cx,cy,1.0);
    const cv::Matx33d cameraRotation=rotation*intrinsics;
    const cv::Matx33d vehicleToImage(
        cameraRotation(0,0),cameraRotation(0,1),cameraRotation(0,2),
        cameraRotation(1,0),cameraRotation(1,1),cameraRotation(1,2),
        h*intrinsics(0,0),h*intrinsics(1,0),h);
    t.imageToVehicle=vehicleToImage.inv();
    const double scale=(c.birdWidth-1)/(c.yMax-c.yMin);
    t.birdToVehicle=cv::Matx33d(0.0,-1.0/scale,c.xMax+1.0/scale,
        -1.0/scale,0.0,c.yMax+1.0/scale,0.0,0.0,1.0);
    t.vehicleToBird=t.birdToVehicle.inv();
    return t;
}

class NativeBirdLut {
public:
    bool load(const QString& path,QString* error=nullptr) {
        QMutexLocker lock(&m_mutex);
        QFile file(path);
        if(!file.open(QIODevice::ReadOnly)) {
            if(error)*error=QStringLiteral("cannot open native BEV LUT: %1").arg(path);
            m_valid=false;return false;
        }
        const QByteArray bytes=file.readAll();
        constexpr int expected=NativeRoi::birdWidth*NativeRoi::birdHeight*2*2;
        if(bytes.size()!=expected) {
            if(error)*error=QStringLiteral("native BEV LUT size %1, expected %2").arg(bytes.size()).arg(expected);
            m_valid=false;return false;
        }
        std::vector<cv::Point> points;
        points.reserve(NativeRoi::birdWidth*NativeRoi::birdHeight);
        QDataStream stream(bytes);stream.setByteOrder(QDataStream::LittleEndian);
        for(int i=0;i<NativeRoi::birdWidth*NativeRoi::birdHeight;++i) {
            qint16 x=0,y=0;stream>>x>>y;
            if(stream.status()!=QDataStream::Ok) {
                if(error)*error=QStringLiteral("native BEV LUT read failed");
                m_valid=false;return false;
            }
            points.emplace_back(int(x),int(y));
        }
        m_points=std::move(points);m_valid=true;m_path=path;return true;
    }
    bool valid() const {QMutexLocker lock(&m_mutex);return m_valid;}
    QString path() const {QMutexLocker lock(&m_mutex);return m_path;}
    cv::Mat warp(const cv::Mat& roi) const {
        std::vector<cv::Point> points;
        {QMutexLocker lock(&m_mutex);if(!m_valid)return {};points=m_points;}
        cv::Mat bird(NativeRoi::birdHeight,NativeRoi::birdWidth,roi.type(),cv::Scalar(0));
        if(roi.cols!=NativeRoi::width||roi.rows!=NativeRoi::height||points.empty())return bird;
        for(int y=0;y<bird.rows;++y)for(int x=0;x<bird.cols;++x) {
            const auto& p=points[size_t(y)*NativeRoi::birdWidth+x];
            const int sx=p.x>>4,sy=p.y>>4;
            if(sx>=0&&sx<roi.cols&&sy>=0&&sy<roi.rows)
                bird.at<cv::Vec3b>(y,x)=roi.at<cv::Vec3b>(sy,sx);
        }
        return bird;
    }
private:
    mutable QMutex m_mutex;
    std::vector<cv::Point> m_points;
    QString m_path;
    bool m_valid=false;
};
} // namespace bev_lane
