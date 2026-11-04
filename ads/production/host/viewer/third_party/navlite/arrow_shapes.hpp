#pragma once
#include <opencv2/opencv.hpp>
#include <array>
#include <map>
#include <string>
#include <vector>
#include <cstdint>
#include <tuple>
#include <future>

namespace navarrow {
struct Shape {std::string label;cv::Mat mask;};
inline cv::Mat tight(const cv::Mat&im){cv::Mat binary=im>100;std::vector<cv::Point>points;cv::findNonZero(binary,points);return points.empty()?cv::Mat():im(cv::boundingRect(points)).clone();}
// Geometry only: no camera image, test-video crop or video coordinate enters
// this bank. Rounded 90-degree turns and U-turns complement the old slanted
// turn shapes. Labels encode direction; mirrored U-turns share UTURN.
inline std::vector<Shape> geometry(bool extendedTurns=false){
 std::vector<Shape>bank;
 for(int thickness:{7,11,17})for(int length:{44,64})for(int radius:{0,14}){
  cv::Mat m=cv::Mat::zeros(128,128,CV_8U);int x=32+length,y=35;
  std::vector<cv::Point>shaft{{x,112},{x,y+radius}};
  if(radius)for(int a=0;a<=90;a+=5){double t=a*CV_PI/180.;shaft.push_back({int(std::lround(x-radius+radius*std::cos(t))),int(std::lround(y+radius-radius*std::sin(t)))});}
  shaft.push_back({30,y});cv::polylines(m,shaft,false,255,thickness,cv::LINE_AA);
  cv::fillConvexPoly(m,std::vector<cv::Point>{{10,y},{34,y-17},{34,y+17}},255,cv::LINE_AA);
  bank.push_back({"LEFT",tight(m)});cv::flip(m,m,1);bank.push_back({"RIGHT",tight(m)});
 }
 for(int thickness:{7,11,17})for(int radius:{19,27}){
  cv::Mat m=cv::Mat::zeros(128,128,CV_8U);int cx=64,cy=38;
  std::vector<cv::Point>shaft{{cx+radius,112},{cx+radius,cy}};
  for(int a=0;a<=180;a+=5){double t=a*CV_PI/180.;shaft.push_back({int(std::lround(cx+radius*std::cos(t))),int(std::lround(cy-radius*std::sin(t)))});}
  shaft.push_back({cx-radius,70});cv::polylines(m,shaft,false,255,thickness,cv::LINE_AA);
  cv::fillConvexPoly(m,std::vector<cv::Point>{{cx-radius,90},{cx-radius-16,66},{cx-radius+16,66}},255,cv::LINE_AA);
  bank.push_back({"UTURN",tight(m)});cv::flip(m,m,1);bank.push_back({"UTURN",tight(m)});
 }
 if(extendedTurns)for(int thickness:{11,17,23})for(int length:{44,64})for(int radius:{14,28})for(int tail:{96,112})for(int head:{17,24}){
  cv::Mat m=cv::Mat::zeros(128,128,CV_8U);int x=32+length,y=35;std::vector<cv::Point>shaft{{x,tail},{x,y+radius}};
  for(int a=0;a<=90;a+=5){double t=a*CV_PI/180.;shaft.push_back({int(std::lround(x-radius+radius*std::cos(t))),int(std::lround(y+radius-radius*std::sin(t)))});}
  shaft.push_back({30,y});cv::polylines(m,shaft,false,255,thickness,cv::LINE_AA);cv::fillConvexPoly(m,std::vector<cv::Point>{{10,y},{34,y-head},{34,y+head}},255,cv::LINE_AA);bank.push_back({"LEFT",tight(m)});cv::flip(m,m,1);bank.push_back({"RIGHT",tight(m)});
 }
 if(extendedTurns)for(int thickness:{11,17,23})for(int radius:{19,27})for(int tip:{70,82,94})for(int head:{16,24}){
  cv::Mat m=cv::Mat::zeros(128,128,CV_8U);int cx=64,cy=38;std::vector<cv::Point>shaft{{cx+radius,112},{cx+radius,cy}};
  for(int a=0;a<=180;a+=5){double t=a*CV_PI/180.;shaft.push_back({int(std::lround(cx+radius*std::cos(t))),int(std::lround(cy-radius*std::sin(t)))});}shaft.push_back({cx-radius,tip-10});cv::polylines(m,shaft,false,255,thickness,cv::LINE_AA);
  cv::fillConvexPoly(m,std::vector<cv::Point>{{cx-radius,tip},{cx-radius-head,tip-24},{cx-radius+head,tip-24}},255,cv::LINE_AA);bank.push_back({"UTURN",tight(m)});cv::flip(m,m,1);bank.push_back({"UTURN",tight(m)});
 }
 // Screen perspective commonly shears vertical shafts. Apply a small fixed
 // shear family to synthetic geometry; still no measured test-video shape.
 auto originals=bank;
 for(const auto&t:originals)for(double shear:{-.18,.18}){
  cv::Mat padded;cv::copyMakeBorder(t.mask,padded,8,8,32,32,cv::BORDER_CONSTANT,0);
  cv::Mat transform=(cv::Mat_<double>(2,3)<<1,shear,-shear*padded.rows*.5,0,1,0),warped;
  cv::warpAffine(padded,warped,transform,padded.size(),cv::INTER_LINEAR,cv::BORDER_CONSTANT,0);bank.push_back({t.label,tight(warped)});
 }
 return bank;
}
using Bits=std::array<uint64_t,16>;
inline Bits pack(const cv::Mat&im){cv::Mat z;cv::resize(im,z,{32,32},0,0,cv::INTER_AREA);Bits b{};for(int y=0;y<32;y++)for(int x=0;x<32;x++)if(z.at<unsigned char>(y,x)>127){int k=y*32+x;b[k/64]|=uint64_t(1)<<(k%64);}return b;}
inline int count(uint64_t n){int c=0;while(n){n&=n-1;c++;}return c;}
inline double iou(const Bits&a,const Bits&b){int intersection=0,united=0;for(int i=0;i<16;i++){intersection+=count(a[i]&b[i]);united+=count(a[i]|b[i]);}return double(intersection)/std::max(1,united);}
struct Reference {std::string label;Bits bits;};
class Matcher {
  std::vector<Shape>bank;std::map<std::pair<int,int>,std::vector<Reference>>cache;
  using ScoreKey=std::tuple<int,int,Bits>;
  std::map<ScoreKey,std::map<std::string,double>> scoreCache;
   public:
  bool reuseScores=false,verifyScores=false;
  size_t scoreCalls=0,scoreHits=0,scoreFlushes=0;
  // 按精确(w,h)首次生成参考库的次数；只计数，不改变匹配
  size_t referenceBuilds=0;
  // 参考库生成拆两线程（逐位等价，默认关闭）
  bool parallelBuild=false;size_t parallelBuilds=0;
  explicit Matcher(bool extendedTurns=false):bank(geometry(extendedTurns)){}
  void add(const std::string&label,const cv::Mat&mask){bank.push_back({label,mask});cache.clear();scoreCache.clear();}
 std::map<std::string,double> scores(const cv::Mat&observed){
   std::map<std::string,double>out;int w=observed.cols,h=observed.rows;if(w<8||h<8||w>192||h>192)return out;
   ++scoreCalls;auto bits=pack(observed);ScoreKey scoreKey(w,h,bits);
   auto previous=reuseScores?scoreCache.find(scoreKey):scoreCache.end();
   if(previous!=scoreCache.end()){++scoreHits;if(!verifyScores)return previous->second;}
  auto key=std::make_pair(w,h);auto it=cache.find(key);
  if(it==cache.end()){
   ++referenceBuilds;if(cache.size()>=512)cache.clear();
   std::vector<const Shape*>eligible;for(const auto&t:bank){double aspect=double(t.mask.cols)/t.mask.rows,ratio=(double(w)/h)/aspect;if(ratio>=.8&&ratio<=1.25)eligible.push_back(&t);}
   // 每个模板独立生成三档参考；按模板顺序写入各自槽位，拼接顺序与串行一致，结果逐位相同
   auto build=[&](size_t begin,size_t end,std::vector<Reference>&refs){
    for(size_t k=begin;k<end;k++){const auto&t=*eligible[k];
     double scale=std::min(double(w)/t.mask.cols,double(h)/t.mask.rows);int tw=std::max(1,int(std::lround(t.mask.cols*scale))),th=std::max(1,int(std::lround(t.mask.rows*scale)));
     cv::Mat sampled;cv::resize(t.mask,sampled,{tw,th},0,0,cv::INTER_AREA);
     for(double sigma:{0.,.6,1.}){cv::Mat low,binary;if(sigma>0)cv::GaussianBlur(sampled,low,{},sigma);else low=sampled;cv::threshold(low,binary,0,255,cv::THRESH_BINARY|cv::THRESH_OTSU);
      cv::Mat placed=cv::Mat::zeros(h,w,CV_8U);binary.copyTo(placed(cv::Rect((w-tw)/2,(h-th)/2,tw,th)));refs.push_back({t.label,pack(placed)});
     }
    }
   };
   std::vector<Reference>refs;
   if(parallelBuild&&eligible.size()>=64){
    // 后半段交给另一线程；get()在本作用域join，异常也不会留下引用局部变量的线程
    size_t half=eligible.size()/2;std::vector<Reference>tail;auto lane=std::async(std::launch::async,[&](){build(half,eligible.size(),tail);});
    build(0,half,refs);lane.get();refs.insert(refs.end(),std::make_move_iterator(tail.begin()),std::make_move_iterator(tail.end()));++parallelBuilds;
   }else build(0,eligible.size(),refs);
   it=cache.emplace(key,std::move(refs)).first;
  }
   for(const auto&t:it->second)out[t.label]=std::max(out[t.label],iou(bits,t.bits));
   if(previous!=scoreCache.end()){CV_Assert(previous->second==out);return previous->second;}
   if(reuseScores){if(scoreCache.size()>=2048){scoreCache.clear();++scoreFlushes;}scoreCache.emplace(std::move(scoreKey),out);}return out;
 }
};
}
