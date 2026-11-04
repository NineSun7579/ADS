#pragma once
#include <opencv2/core.hpp>
#include <cmath>
#include <cstddef>
#include <vector>

namespace bev_lane {
struct Calibration {
    double fx=309.4362, fy=344.2161, cx=318.9034, cy=257.5352;
    double cameraHeight=2.1798, pitchDegrees=14.0;
    // MATLAB main.m vehicle coordinates: forward 3..13m, lateral -6..6m.
    double xMin=3.0, xMax=13.0, yMin=-6.0, yMax=6.0;
    int birdWidth=250, birdHeight=209;
    double laneWidthMeters=0.25, sensitivity=0.25;
};
struct Transform {
    cv::Matx33d imageToVehicle, birdToVehicle, vehicleToBird;
    int inputWidth=0,inputHeight=0;
};
inline Transform makeTransform(const Calibration& c,int width,int height) {
    Transform t;t.inputWidth=width;t.inputHeight=height;
    const double sx=double(width)/640.0,sy=double(height)/360.0;
    const double fx=c.fx*sx,fy=c.fy*sy,cx=c.cx*sx,cy=c.cy*sy;
    const double a=c.pitchDegrees*3.14159265358979323846/180.0;
    const double ca=std::cos(a),sa=std::sin(a),h=c.cameraHeight;
    // Inverted monoCamera ImageToVehicleTransform, homogeneous vehicle X,Y,1.
    const cv::Matx33d rotation(
        -1.0,0.0,0.0,
        0.0,sa,ca,
        0.0,ca,-sa);
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
inline cv::Point2d apply(const cv::Matx33d& h,cv::Point2d p) {
    const double w=h(2,0)*p.x+h(2,1)*p.y+h(2,2);
    return {(h(0,0)*p.x+h(0,1)*p.y+h(0,2))/w,(h(1,0)*p.x+h(1,1)*p.y+h(1,2))/w};
}
struct Lane {
    bool valid=false;
    double a=0,b=0,c=0,xMin=0,xMax=0,strength=0;
    std::vector<cv::Point2f> imagePoints;
};
} // namespace bev_lane
