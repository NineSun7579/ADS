#pragma once
#include <opencv2/opencv.hpp>
#include <algorithm>
#include <cmath>
#include <map>
#include <set>
#include <tuple>
#include <vector>
namespace navperf {
// Shared numerical screening only. Surviving queries retain their ORIGINAL
// window, NCC scores, tie order, shape/partial checks and unit arbitration.
class UnitBatchSearch {
 struct Demand {int end,top,height;};
 struct Tile {cv::Rect output;cv::Mat scores;};
 using Key=std::tuple<int,int,int,int>;
 std::vector<Demand> demands;
 std::map<Key,std::vector<Tile>> tiles;
 size_t bytes=0;
 static double cost(cv::Rect output,cv::Size t){int w=cv::getOptimalDFTSize(output.width+t.width-1),h=cv::getOptimalDFTSize(output.height+t.height-1);double area=double(w)*h;return area*std::log2(std::max(2.,area));}
 static cv::Rect region(const Demand&d,cv::Size image,cv::Size t){
  int x0=std::max(0,d.end-1),x1=std::min(image.width,int(std::nearbyint(d.end+3.6*d.height))),y0=std::max(0,int(std::nearbyint(d.top-.35*d.height))),y1=std::min(image.height,int(std::nearbyint(d.top+1.4*d.height)));
  if(y1-y0<t.height||x1-x0<t.width)return {};
  int cw=std::min(x1-x0,t.width+std::max(0,int(d.end+.8*d.height-x0))+1);
  return {x0,y0,cw-t.width+1,y1-y0-t.height+1};
 }
 public:
 bool verify=false;
 size_t requests=0,builds=0,reuses=0,rejected=0,ungrouped=0,planned=0,peakBytes=0,exactChecks=0;
 double maxPeakError=0;
 void begin(){demands.clear();tiles.clear();bytes=0;}
 void plan(int end,int top,int height){for(auto d:demands)if(d.end==end&&d.top==top&&d.height==height)return;demands.push_back({end,top,height});++planned;}
 bool reject(const cv::Mat&mask,const cv::Mat&t,int token,int id,cv::Rect query){
  return rejectWith(mask,t,token,id,query,[&](const cv::Mat&input,cv::Mat&result){cv::matchTemplate(input,t,result,cv::TM_CCOEFF_NORMED);});
 }
 template<class Correlate> bool rejectWith(const cv::Mat&mask,const cv::Mat&t,int token,int id,cv::Rect query,Correlate correlate){
  ++requests;cv::Rect output(query.x,query.y,query.width-t.cols+1,query.height-t.rows+1);Key key(token,id,t.cols,t.rows);auto&stored=tiles[key];
  const Tile*chosen=nullptr;
  for(const auto&tile:stored)if((output&tile.output)==output){chosen=&tile;++reuses;break;}
  if(!chosen){
   std::set<std::tuple<int,int,int,int>> seen;std::vector<cv::Rect> candidates;
   seen.emplace(output.x,output.y,output.width,output.height);
   for(auto d:demands){
    // Do not plan scales that the original template loop cannot request.
    bool scale=false;for(double s:{.42,.5,.55,.6,.65,.7,.75,.82,.9,1.,1.16})if(std::max(4,int(std::nearbyint(d.height*s)))==t.rows)scale=true;
    if(!scale)continue;auto r=region(d,mask.size(),t.size());if(r.empty()||!seen.emplace(r.x,r.y,r.width,r.height).second)continue;
    if((r&output).empty())continue;candidates.push_back(r);
   }
   std::sort(candidates.begin(),candidates.end(),[&](cv::Rect a,cv::Rect b){return (a&output).area()>(b&output).area();});
   cv::Rect combined=output;double separate=cost(output,t.size());int members=1;
   for(auto r:candidates){auto u=combined|r;double sum=separate+cost(r,t.size());
    if(u.width+t.cols-1>256||u.height+t.rows-1>256||cost(u,t.size())>.8*sum)continue;
    combined=u;separate=sum;if(++members>=8)break;
   }
   if(members<2){++ungrouped;return false;}
   cv::Rect input(combined.x,combined.y,combined.width+t.cols-1,combined.height+t.rows-1);cv::Mat result;correlate(mask(input),result);
   size_t n=result.total()*result.elemSize();constexpr size_t limit=16*1024*1024;
   if(bytes+n>limit){tiles.clear();bytes=0;}
   auto&dst=tiles[key];dst.push_back({combined,result});chosen=&dst.back();bytes+=n;peakBytes=std::max(peakBytes,bytes);++builds;
  }
  cv::Rect local=output-chosen->output.tl();double peak;cv::minMaxLoc(chosen->scores(local),nullptr,&peak);
  // Expanded DFT is not bit-identical. .005 guard is an experimental
  // numerical margin, NOT a formal backend error bound. Default remains OFF.
  bool skip=peak<.565;
  if(verify){cv::Mat original;cv::matchTemplate(mask(query),t,original,cv::TM_CCOEFF_NORMED);double exact;cv::minMaxLoc(original,nullptr,&exact);maxPeakError=std::max(maxPeakError,std::abs(exact-peak));++exactChecks;if(skip)CV_Assert(exact<.57);}
  if(skip)++rejected;return skip;
 }
};
}
