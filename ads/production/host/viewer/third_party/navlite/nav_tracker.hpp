#pragma once
#include "structure_gate.hpp" // reuses only deterministic contrast preprocessing

namespace navtrack {
struct Config {
 cv::Rect nav;bool contrast=true;
 int refreshEvery=30; // number of analyzed frames, not source frames
 int minPoints=6;double maxForwardBackward=1.5,maxResidual=2.,minInlierRatio=.6;
};
struct Result {
 std::string phase="SEARCH",why,readout,direction;bool valid=false;
 navlite::Row row;cv::Rect search;int mode=-1,features=0,inliers=0;
 double flowMs=0,readMs=0,totalMs=0;size_t matches=0;
};
inline double now(){return double(cv::getTickCount())*1000/cv::getTickFrequency();}
inline cv::Rect expand(cv::Rect b,int x,int y,cv::Size size){return cv::Rect(b.x-x,b.y-y,b.width+2*x,b.height+2*y)&cv::Rect(0,0,size.width,size.height);}
inline cv::Rect moved(cv::Rect b,const cv::Mat&a){
 std::vector<cv::Point2f>src{{float(b.x),float(b.y)},{float(b.br().x),float(b.y)},{float(b.br().x),float(b.br().y)},{float(b.x),float(b.br().y)}},dst;
 cv::transform(src,dst,a);float x=dst[0].x,y=dst[0].y,X=x,Y=y;for(auto p:dst){x=std::min(x,p.x);y=std::min(y,p.y);X=std::max(X,p.x);Y=std::max(Y,p.y);}return {int(std::floor(x)),int(std::floor(y)),int(std::ceil(X))-int(std::floor(x)),int(std::ceil(Y))-int(std::floor(y))};
}
inline void offset(navlite::Row&r,cv::Point d){r.box+=d;r.unit.box+=d;for(auto&g:r.glyphs)g.box+=d;for(auto&b:r.dots)b+=d;for(auto&a:r.arrows)a.box+=d;}
class Tracker {
 navlite::Reader reader;Config cfg;bool locked=false;int mode=-1,age=0;
 navlite::Row geometry;cv::Mat previous;std::vector<cv::Point2f>points;
 cv::Mat input(const cv::Mat&im,int m){return m==0?im:navgate::normalize(im,m==2);}
 void seed(const cv::Mat&gray,const navlite::Row&r){
  cv::Mat mask=cv::Mat::zeros(gray.size(),CV_8U);int pad=std::max(2,navlite::rnd(r.box.height*.3));
  auto fill=[&](cv::Rect b){auto e=expand(b,pad,pad,gray.size());mask(e).setTo(255);};fill(r.unit.box);for(auto a:r.arrows)fill(a.box);
  // Changing digit strokes must never be used as stable optical-flow anchors.
  mask(expand(r.box,2,2,gray.size())).setTo(0);
  cv::goodFeaturesToTrack(gray,points,80,.01,3,mask,3);gray.copyTo(previous);
 }
 bool predict(const cv::Mat&gray,navlite::Row&g,Result&out){
  out.features=points.size();if(points.size()<size_t(cfg.minPoints)){out.why="too_few_stable_points";return false;}
  std::vector<cv::Point2f>next,back,a,b;std::vector<unsigned char>ok1,ok2;std::vector<float>err1,err2;
  cv::calcOpticalFlowPyrLK(previous,gray,points,next,ok1,err1,{21,21},3);
  cv::calcOpticalFlowPyrLK(gray,previous,next,back,ok2,err2,{21,21},3);
  for(size_t i=0;i<points.size();i++)if(ok1[i]&&ok2[i]&&cv::norm(points[i]-back[i])<=cfg.maxForwardBackward&&next[i].x>=0&&next[i].y>=0&&next[i].x<gray.cols&&next[i].y<gray.rows){a.push_back(points[i]);b.push_back(next[i]);}
  if(a.size()<size_t(cfg.minPoints)){out.why="flow_forward_backward_failed";return false;}
  cv::Mat inlier;auto affine=cv::estimateAffinePartial2D(a,b,inlier,cv::RANSAC,cfg.maxResidual,1000,.99,10);
  if(affine.empty()){out.why="affine_failed";return false;}
  out.inliers=cv::countNonZero(inlier);double scale=std::hypot(affine.at<double>(0,0),affine.at<double>(1,0));
  if(out.inliers<cfg.minPoints||double(out.inliers)/a.size()<cfg.minInlierRatio||scale<.9||scale>1.1||std::abs(affine.at<double>(0,2))>std::max(12.,gray.cols*.12)||std::abs(affine.at<double>(1,2))>std::max(12.,gray.rows*.12)){out.why="motion_geometry_rejected";return false;}
  double residual=0;int n=0;for(size_t i=0;i<a.size();i++)if(inlier.at<unsigned char>(int(i))){cv::Point2d p(affine.at<double>(0,0)*a[i].x+affine.at<double>(0,1)*a[i].y+affine.at<double>(0,2),affine.at<double>(1,0)*a[i].x+affine.at<double>(1,1)*a[i].y+affine.at<double>(1,2));residual+=cv::norm(p-cv::Point2d(b[i]));n++;}
  if(residual/std::max(1,n)>cfg.maxResidual){out.why="motion_residual_rejected";return false;}
  g=geometry;g.box=moved(g.box,affine);g.unit.box=moved(g.unit.box,affine);for(auto&ar:g.arrows)ar.box=moved(ar.box,affine);
  cv::Rect bounds(0,0,gray.cols,gray.rows);if((g.box&bounds)!=g.box||(g.unit.box&bounds)!=g.unit.box){out.why="predicted_region_outside_nav";return false;}
  return true;
 }
 std::vector<navlite::Row> read(const cv::Mat&im,int m,const navlite::SearchHint*hint){auto processed=input(im,m);auto rows=reader.analyze(processed,hint);std::vector<navlite::Row>accepted;for(auto r:rows)if(r.accepted)accepted.push_back(r);return accepted;}
public:
 explicit Tracker(const std::string&model,Config config):reader(model),cfg(config){if(cfg.nav.empty()||cfg.refreshEvery<1)throw std::runtime_error("manual nav ROI and positive refresh interval required");}
 void reset(){locked=false;mode=-1;age=0;points.clear();previous.release();geometry=navlite::Row{};}
 Result step(const cv::Mat&frame){
  Result out;double begin=now();reader.templateCalls=0;
  auto finish=[&](){out.matches=reader.templateCalls;out.totalMs=now()-begin;return out;};
  cv::Rect frameBounds(0,0,frame.cols,frame.rows);if(frame.empty()||(cfg.nav&frameBounds)!=cfg.nav){reset();out.why="invalid_manual_nav_region";return finish();}
  cv::Mat im=frame(cfg.nav),gray;cv::cvtColor(im,gray,cv::COLOR_BGR2GRAY);
  bool full=!locked||age>=cfg.refreshEvery;navlite::Row predicted;
  if(!full){double t=now();bool ok=predict(gray,predicted,out);out.flowMs=now()-t;if(!ok){reset();out.phase="LOST";return finish();}}
  if(full){out.phase=locked?"REFRESH":"SEARCH";out.search=cfg.nav;double t=now();
   struct Found{navlite::Row row;int mode;};std::vector<Found>found;
   for(int m=0;m<(cfg.contrast?3:1);m++)for(auto r:read(im,m,nullptr))found.push_back({r,m});
   out.readMs=now()-t;bool conflict=false;for(size_t i=0;i<found.size();i++)for(size_t j=0;j<i;j++)if(std::abs(found[i].row.meters-found[j].row.meters)>1e-6||navlite::overlap(found[i].row.box,found[j].row.box)<.7)conflict=true;
   if(found.empty()||conflict){reset();out.why=conflict?"acquisition_conflict":"no_complete_reading";return finish();}
   geometry=found.front().row;mode=found.front().mode;age=0;
  }else{
   out.phase="TRACK";int h=std::max(1,predicted.box.height);cv::Rect tile=predicted.box|predicted.unit.box;for(auto a:predicted.arrows)tile|=a.box;tile=expand(tile,navlite::rnd(.8*h),navlite::rnd(.55*h),gray.size());
   out.search=tile+cfg.nav.tl();navlite::SearchHint hint;int x=std::max(0,predicted.box.x-navlite::rnd(.4*h)),right=std::min(gray.cols,std::max(predicted.box.br().x,predicted.unit.box.br().x)+navlite::rnd(1.5*h));
   hint.digitBand=(cv::Rect(x,predicted.box.y-navlite::rnd(.3*h),right-x,navlite::rnd(1.6*h))&tile)-tile.tl();hint.digitHeight=h;hint.unitHeight=predicted.unit.box.height;
   double t=now();auto found=read(im(tile),mode,&hint);out.readMs=now()-t;
   if(found.size()!=1){reset();out.phase="LOST";out.why=found.empty()?"local_read_failed":"local_read_conflict";return finish();}
   auto r=found.front();offset(r,tile.tl());
   if(std::abs(r.box.y-predicted.box.y)>.5*h||std::abs(r.box.x-predicted.box.x)>.75*h||r.box.height<h*.55||r.box.height>h*1.6){reset();out.phase="LOST";out.why="local_layout_changed";return finish();}
   // Always take fresh row/arrow/unit results, never use predicted text or value.
   geometry=r;
  }
  locked=true;age++;seed(gray,geometry);out.features=points.size();out.mode=mode;out.valid=true;out.readout=geometry.raw();out.row=geometry;offset(out.row,cfg.nav.tl());
  std::set<std::string>ds;for(auto a:geometry.arrows)ds.insert(a.direction);if(ds.size()==1)out.direction=*ds.begin();else out.direction="AMBIGUOUS";
  if(points.size()<size_t(cfg.minPoints)){locked=false;out.why="read_ok_but_track_unavailable";}
  return finish();
 }
};
} // namespace navtrack
