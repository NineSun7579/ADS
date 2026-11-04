#pragma once
#include "structure_gate.hpp"

namespace navperf {
// OpenCV4.6在CV_32F、sigma15时自动选121点核，目标框外60像素
// 已覆盖最大有限支持域。边界被截到原图时仍使用原有REFLECT101。
inline cv::Mat normalizeWindow(const cv::Mat&image,bool dark,cv::Rect target){
 const cv::Rect bounds(0,0,image.cols,image.rows);
 CV_Assert(!target.empty()&&(target&bounds)==target);
 constexpr int support=60;
 const auto extended=(cv::Rect(target.x-support,target.y-support,target.width+2*support,target.height+2*support)&bounds);
 // normalize内部cvtColor/convertTo创建独立矩阵，滤波不会越过extended
 // 去读取父Mat的数据。目标框的邻域已经显式包含在extended内。
 auto normalized=navgate::normalize(image(extended),dark);
 return normalized(target-extended.tl()).clone();
}
}
