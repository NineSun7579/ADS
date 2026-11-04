#pragma once
#include <opencv2/opencv.hpp>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <string>
#include <vector>
namespace navperf {
// Full-resolution pixels, never the 32x32 sampled representation.
class ExactArrowBank {
 struct Packed {std::vector<uint64_t> words;int count=0;};
 struct Template {std::string label;cv::Mat mask;};
 std::vector<Template> bank;
 std::map<std::pair<int,int>,std::vector<Packed>> prepared;
 size_t bytes=0;
 static Packed pack(const cv::Mat&m){Packed p;p.words.resize((m.total()+63)/64);size_t k=0;for(int y=0;y<m.rows;y++){const uchar*r=m.ptr<uchar>(y);for(int x=0;x<m.cols;x++,k++)if(r[x]>100){p.words[k/64]|=uint64_t(1)<<(k%64);++p.count;}}return p;}
 public:
 size_t calls=0,hits=0,builds=0,pruned=0,compared=0,peakBytes=0;
 void add(const std::string&label,const cv::Mat&m){bank.push_back({label,m});prepared.clear();bytes=0;}
 bool scores(const cv::Mat&crop,std::map<std::string,double>&out){
  // Bound packing work/storage; larger inputs retain the original algorithm.
  if(crop.type()!=CV_8UC1||crop.empty()||crop.total()>65536)return false;
  constexpr size_t limit=8*1024*1024;size_t cost=bank.size()*((crop.total()+63)/64)*sizeof(uint64_t);
  if(cost>limit)return false;
  ++calls;auto key=std::make_pair(crop.cols,crop.rows);auto found=prepared.find(key);
  if(found==prepared.end()){
   std::vector<Packed> refs;refs.reserve(bank.size());
   for(const auto&t:bank){
    if(crop.size()==t.mask.size())refs.push_back(pack(t.mask));
    else {double ratio=std::min(double(crop.cols)/t.mask.cols,double(crop.rows)/t.mask.rows);int w=std::max(1,int(std::nearbyint(t.mask.cols*ratio))),h=std::max(1,int(std::nearbyint(t.mask.rows*ratio)));cv::Mat z,placed=cv::Mat::zeros(crop.size(),CV_8U);cv::resize(t.mask,z,{w,h},0,0,cv::INTER_AREA);z.copyTo(placed(cv::Rect((crop.cols-w)/2,(crop.rows-h)/2,w,h)));refs.push_back(pack(placed));}
   }
   if(bytes+cost>limit||prepared.size()>=256){prepared.clear();bytes=0;}
   found=prepared.emplace(key,std::move(refs)).first;bytes+=cost;peakBytes=std::max(peakBytes,bytes);++builds;
  }else ++hits;
  auto observed=pack(crop);out.clear();
  for(size_t j=0;j<bank.size();j++){
   const auto&ref=found->second[j];double&best=out[bank[j].label];
   double upper=double(std::min(observed.count,ref.count))/std::max(1,std::max(observed.count,ref.count));
   if(upper<=best){++pruned;continue;}
   int intersection=0;for(size_t i=0;i<observed.words.size();i++)intersection+=__builtin_popcountll(observed.words[i]&ref.words[i]);++compared;
   double score=double(intersection)/std::max(1,observed.count+ref.count-intersection);best=std::max(best,score);
  }
  return true;
 }
};
}
