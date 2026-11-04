#pragma once
#include <opencv2/opencv.hpp>
#include <algorithm>
#include <map>
#include <tuple>
#include <vector>
#include <cstdint>
namespace navperf {
// Binary image pixels are 0/255. For k white pixels in a block the largest
// possible dot product is the sum of the k largest template pixels. Summing
// these independent block maxima gives an upper bound, with no assumed layout.
class UnitNccBound {
 struct Block {cv::Rect box;std::vector<int> largest;};
 struct Prepared {cv::Mat owner;std::vector<Block> blocks;std::vector<int> required;double sum=0,energy=0;};
 using Key=std::tuple<uintptr_t,size_t,int,int>;
 std::map<Key,Prepared> prepared;
 public:
 bool earlyBlocks=true;
 size_t blockVisits=0,earlyStops=0;
 size_t calls=0,rejected=0,positions=0;
 bool possible(const cv::Mat&integral,const cv::Mat&t,int width,int height){
  ++calls;Key key(reinterpret_cast<uintptr_t>(t.data),t.step[0],t.cols,t.rows);auto it=prepared.find(key);
  if(it==prepared.end()){
   Prepared p;p.owner=t;double sq=0;std::vector<int> allPixels;allPixels.reserve(t.total());
   for(int by=0;by<4;by++)for(int bx=0;bx<4;bx++){
    cv::Rect b(bx*t.cols/4,by*t.rows/4,(bx+1)*t.cols/4-bx*t.cols/4,(by+1)*t.rows/4-by*t.rows/4);if(b.empty())continue;
    Block block;block.box=b;std::vector<int> pixels;pixels.reserve(b.area());
    for(int y=b.y;y<b.br().y;y++)for(int x=b.x;x<b.br().x;x++){int v=t.at<uchar>(y,x);pixels.push_back(v);allPixels.push_back(v);p.sum+=v;sq+=v*v;}
    std::sort(pixels.rbegin(),pixels.rend());block.largest.push_back(0);for(int v:pixels)block.largest.push_back(block.largest.back()+v);p.blocks.push_back(std::move(block));
   }
   p.energy=std::max(0.,sq-p.sum*p.sum/t.total());
   std::sort(allPixels.rbegin(),allPixels.rend());p.required.resize(t.total()+1,-1);int upper=0;double n=t.total();
   for(int k=1;k<int(t.total());k++){upper+=allPixels[k-1];double variance=k-k*double(k)/n;int needed=int(std::ceil(k*p.sum/n+.569*std::sqrt(variance*p.energy)));if(needed<=upper)p.required[k]=needed;}
   // Count cap bounds ownership/metadata; only Reader immutable scaled masks.
   if(prepared.size()>=4096)prepared.clear();it=prepared.emplace(key,std::move(p)).first;
  }
  const auto&p=it->second;if(p.energy<1e-12)return true;
  auto ink=[&](int x,int y,int w,int h){const int*a=integral.ptr<int>(y),*b=integral.ptr<int>(y+h);return (b[x+w]-b[x]-a[x+w]+a[x])/255;};
  for(int y=0;y<=height-t.rows;y++)for(int x=0;x<=width-t.cols;x++){
   ++positions;int k=ink(x,y,t.cols,t.rows);int needed=p.required[k];if(needed<0)continue;
    int upper=0,remainingInk=k,remainingSum=int(p.sum);bool stopped=false;
    for(const auto&b:p.blocks){int count=ink(x+b.box.x,y+b.box.y,b.box.width,b.box.height);upper+=b.largest[count];++blockVisits;
     if(earlyBlocks){remainingInk-=count;remainingSum-=b.largest.back();
      // Both bounds dominate the remaining intersection: each white pixel
      // contributes at most 255, and no subset exceeds total template ink.
      if(upper+std::min(255*remainingInk,remainingSum)<needed){++earlyStops;stopped=true;break;}
     }
    }
   // .001 below the unchanged .57 acceptance boundary protects against the
   // float DFT rounding of OpenCV; borderline inputs keep the original path.
    if(!stopped&&upper>=needed)return true;
  }
  ++rejected;return false;
 }
};
}
