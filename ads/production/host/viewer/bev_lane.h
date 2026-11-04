#pragma once
#include "bev_lane_calibration.h"
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <numeric>

namespace bev_lane {
struct Result {
    cv::Mat birdGray, birdMask;
    Lane left,right;
};
inline cv::Mat makeBird(const cv::Mat& rgb,const Transform& t,const Calibration& c) {
    const cv::Matx33d vehicleToImage(
        309.4306,-309.4362,168.1709,
        166.6119,0.0,863.8434,
        0.9703,0.0,0.5273);
    const cv::Matx33d inverseMatrix(vehicleToImage*t.birdToVehicle);
    cv::Mat inverse(inverseMatrix),bird;
    cv::warpPerspective(rgb,bird,inverse,cv::Size(c.birdWidth,c.birdHeight),
        cv::INTER_LINEAR|cv::WARP_INVERSE_MAP,cv::BORDER_CONSTANT,cv::Scalar(0));
    return bird;
}
inline cv::Mat ridgeMask(const cv::Mat& gray,const Transform& t,const Calibration& c) {
    CV_Assert(gray.type()==CV_8UC1);
    cv::Mat mask(gray.size(),CV_8UC1,cv::Scalar(0));
    const double meterX=(c.xMax-c.xMin)/(c.birdWidth-1);
    const double meterY=(c.yMax-c.yMin)/(c.birdHeight-1);
    const int radius=std::max(1,int(std::round(c.laneWidthMeters/meterX/2.0)));
    // A lane ridge is brighter than both sides at the physical marker width.
    // This is deliberately a local signed contrast, not a white pixel threshold.
    for(int y=0;y<gray.rows;++y)for(int x=0;x<gray.cols;++x) {
        const auto world=apply(t.birdToVehicle,{(double)x,(double)y});
        if(world.x<4||world.x>11||std::abs(world.y)>3)continue;
        const int center=gray.at<unsigned char>(y,x);
        const int l=gray.at<unsigned char>(y,std::max(0,x-radius));
        const int r=gray.at<unsigned char>(y,std::min(gray.cols-1,x+radius));
        const int ll=gray.at<unsigned char>(y,std::max(0,x-2*radius));
        const int rr=gray.at<unsigned char>(y,std::min(gray.cols-1,x+2*radius));
        const int contrast=std::min(center-std::max(l,r),center-std::max(ll,rr));
        if(contrast>=int(3+24*c.sensitivity))mask.at<unsigned char>(y,x)=255;
    }
    return mask;
}
inline Lane fitRidge(const cv::Mat& mask,const Transform& t,const Calibration& c) {
    std::vector<cv::Point> points;
    cv::findNonZero(mask,points);
    std::vector<cv::Point2d> samples;
    for(const auto& p:points)samples.push_back(apply(t.birdToVehicle,{(double)p.x+1,(double)p.y+1}));
    Lane best;
    // Robust iterative parabola fit. Remove outlying residuals and refit;
    // unlike longest-white-run selection, unrelated white objects cannot
    // become valid solely because sixteen rows contain bright pixels.
    std::vector<cv::Point2d> subset;
    for(const auto& p:samples)if(std::abs(p.y)<3.2)subset.push_back(p);
    samples.swap(subset);
    for(int iteration=0;iteration<4&&samples.size()>=20;++iteration) {
        cv::Mat x(samples.size(),3,CV_64F),y(samples.size(),1,CV_64F),coeff;
        for(size_t i=0;i<samples.size();++i) {
            const double v=samples[i].x;
            x.at<double>(i,0)=v*v;x.at<double>(i,1)=v;x.at<double>(i,2)=1;
            y.at<double>(i,0)=samples[i].y;
        }
        if(!cv::solve(x,y,coeff,cv::DECOMP_QR))break;
        std::vector<std::pair<double,cv::Point2d>> residual;
        for(const auto& p:samples) {
            const double estimate=coeff.at<double>(0)*p.x*p.x+coeff.at<double>(1)*p.x+coeff.at<double>(2);
            residual.push_back({std::abs(p.y-estimate),p});
        }
        std::sort(residual.begin(),residual.end(),[](const auto& a,const auto& b){return a.first<b.first;});
        std::vector<cv::Point2d> inliers;
        for(size_t i=0;i<residual.size()*85/100;++i)inliers.push_back(residual[i].second);
        samples.swap(inliers);
        if(iteration==3) {
            auto mm=std::minmax_element(samples.begin(),samples.end(),[](auto a,auto b){return a.x<b.x;});
            const double a=coeff.at<double>(0),b=coeff.at<double>(1),d=coeff.at<double>(2);
            const double coverage=(*mm.second).x-(*mm.first).x;
            const double strength=double(samples.size())*c.sensitivity;
            if(std::abs(a)<0.003&&coverage>=4.2&&strength>0.5) {
                best.valid=true;best.a=a;best.b=b;best.c=d;
                best.xMin=(*mm.first).x;best.xMax=(*mm.second).x;best.strength=strength;
            }
        }
    }
    return best;
}
inline Result detect(const cv::Mat& rgb,const Calibration& calibration={}) {
    Result result;
    if(rgb.empty()||rgb.channels()!=3)return result;
    const auto t=makeTransform(calibration,rgb.cols,rgb.rows);
    cv::Mat bird=makeBird(rgb,t,calibration);
    cv::cvtColor(bird,result.birdGray,cv::COLOR_BGR2GRAY);
    result.birdMask=ridgeMask(result.birdGray,t,calibration);
    for(int side=0;side<2;++side) {
        cv::Mat part(result.birdMask.size(),CV_8UC1,cv::Scalar(0));
        for(int y=0;y<result.birdMask.rows;++y)for(int x=0;x<result.birdMask.cols;++x) {
            const auto world=apply(t.birdToVehicle,{(double)x,(double)y});
            if((side==0&&world.y>0)||(side==1&&world.y<=0))
                part.at<unsigned char>(y,x)=result.birdMask.at<unsigned char>(y,x);
        }
        auto lane=fitRidge(part,t,calibration);
        if(lane.valid)(side==0?result.left:result.right)=lane;
    }
    return result;
}
} // namespace bev_lane
