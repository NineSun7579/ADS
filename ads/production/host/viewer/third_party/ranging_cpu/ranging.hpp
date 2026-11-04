#pragma once
#include "lane_calib.h"
#include "online_calib.h"
#include <limits>
#include <stdexcept>

namespace ranging {
struct Box {int cls=0;double score=0;cv::Rect2d rect;};
struct Measurement {Box box;bool valid=false;double depth_m=std::numeric_limits<double>::quiet_NaN();std::string reason;};
struct Config {
 cv::Rect mark,road;std::string standard;double score_min=.25;
 online_calib::Config calibration;
};
inline Measurement project(const Box&b,const online_calib::State&s,cv::Size size,cv::Rect road,double score_min=.25){
 Measurement m;m.box=b;auto reject=[&](const char*why){m.reason=why;return m;};auto r=b.rect;
 if(!std::isfinite(b.score)||b.score<0||b.score>1||b.score<score_min)return reject("score_rejected");
 if(b.cls<0||b.cls>6)return reject("unsupported_class");
 if(!std::isfinite(r.x)||!std::isfinite(r.y)||!std::isfinite(r.width)||!std::isfinite(r.height)||r.width<=0||r.height<=0||r.x<0||r.y<0||r.br().x>size.width||r.br().y>size.height)return reject("invalid_or_clipped_box");
 if(!s.ok||!s.frame_ok||!std::isfinite(s.A)||s.A<=0||!std::isfinite(s.y_h))return reject("calibration_unavailable");
 double x=r.x+r.width*.5,y=r.br().y;
 if(x<road.x||x>=road.br().x||y<road.y||y>=road.br().y)return reject("outside_road");
 if(y-s.y_h<=3)return reject("near_or_above_horizon");
 double z=s.A/(y-s.y_h);if(!std::isfinite(z)||z<=0)return reject("invalid_depth");
 if(z>100)return reject("beyond_100m");
 m.valid=true;m.depth_m=z;m.reason="ok";return m;
}
struct Result {int frame=-1;online_calib::State calibration;int marks=0;std::vector<Measurement> objects;};
class Engine {
 Config cfg_;online_calib::OnlineCalib calibration_;int last_=-1;cv::Size size_;
public:
 explicit Engine(Config cfg):cfg_(cfg),calibration_(cfg.calibration){
  if(!lane_calib::find_standard(cfg.standard)||cfg.mark.width<=0||cfg.mark.height<=0||cfg.road.width<=0||cfg.road.height<=0||!std::isfinite(cfg.score_min)||cfg.score_min<0||cfg.score_min>1)throw std::invalid_argument("explicit mark/road ROIs, road standard and valid score threshold required");
 }
 // Call on every new source frame, including frames with no boxes. All boxes
 // must belong to this frame and be in SOURCE pixels, not detector pixels.
 Result process(const cv::Mat&frame,int frame_id,const std::vector<Box>&boxes){
  if(frame.empty()||frame.type()!=CV_8UC3||frame_id<0||frame_id<=last_)throw std::invalid_argument("new increasing frame ID and BGR8 frame required");
  cv::Rect bounds(0,0,frame.cols,frame.rows);
  if((cfg_.mark&bounds)!=cfg_.mark||(cfg_.road&bounds)!=cfg_.road)throw std::invalid_argument("ROI outside frame");
  if(last_>=0&&frame.size()!=size_)throw std::invalid_argument("image size changed: reset calibration and update ROIs");
  auto r=cfg_.mark;auto measured=lane_calib::measure(frame,{r.x,r.y,r.br().x,r.br().y},*lane_calib::find_standard(cfg_.standard));
  online_calib::Observation o;o.has_vp=measured.has_vp;o.n_marks=measured.has_vp?measured.vp.n:0;o.y_h=measured.y_h;
  auto est=[](const lane_calib::Est&e){return online_calib::Est{e.ok,e.value};};
  o.hc_paint=est(measured.h_c_paint);o.hc_lane=est(measured.h_c_lane);o.a_dash=est(measured.A_dash);o.a_gap=est(measured.A_gap);o.a_period=est(measured.A_period);
  Result result;result.frame=frame_id;result.marks=measured.n_marks;result.calibration=calibration_.observe(o,frame.cols,frame.rows);
  for(auto b:boxes)result.objects.push_back(project(b,result.calibration,frame.size(),cfg_.road,cfg_.score_min));
  last_=frame_id;size_=frame.size();return result;
 }
 // Mandatory on camera/lens replacement or a discontinuous source jump.
 void reset(){calibration_.reset();last_=-1;size_={};}
};
}
