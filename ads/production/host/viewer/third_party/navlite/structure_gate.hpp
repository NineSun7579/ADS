#pragma once
#include "nav_lite.hpp"
#include <array>
#include <future>

// Verification on ORIGINAL pixels. Constants fixed before external evaluation.
namespace navgate {
inline cv::Mat normalize(const cv::Mat&im,bool dark){
 cv::Mat gray,f,bg,diff;cv::cvtColor(im,gray,cv::COLOR_BGR2GRAY);gray.convertTo(f,CV_32F);
 cv::Mat strength=cv::Mat::zeros(gray.size(),CV_32F);
 for(double sigma:{3.,7.,15.}){cv::GaussianBlur(f,bg,{},sigma,sigma,cv::BORDER_REFLECT101);diff=dark?bg-f:f-bg;cv::max(strength,diff,strength);}
 strength=strength/(strength+12.f)*255.f;cv::Mat out;strength.convertTo(out,CV_8U);cv::cvtColor(out,out,cv::COLOR_GRAY2BGR);return out;
}
// 亮字(1)与暗字(2)两种增强使用完全相同的三档背景模糊，只差减法方向。
// 一次全区搜索只算一份模糊，供两种模式各自派生；逐位结果与上面的normalize相同。
struct ContrastBackground {cv::Mat f;std::array<cv::Mat,3>bg;};
inline ContrastBackground contrastBackground(const cv::Mat&im,bool parallel=false){
 ContrastBackground b;cv::Mat gray;cv::cvtColor(im,gray,cv::COLOR_BGR2GRAY);gray.convertTo(b.f,CV_32F);
 auto blur=[&](int i,double sigma){cv::GaussianBlur(b.f,b.bg[i],{},sigma,sigma,cv::BORDER_REFLECT101);};
 if(!parallel){blur(0,3.);blur(1,7.);blur(2,15.);return b;}
 // sigma15的121点核约占三档工作量的六成，单独占一条线程；各档写入不同矩阵，只读共享f。
 // get()在本作用域内join，异常时也不会让工作线程持有已析构的f。
 auto small=std::async(std::launch::async,[&](){blur(0,3.);blur(1,7.);});blur(2,15.);small.get();return b;
}
inline cv::Mat normalize(const ContrastBackground&b,bool dark){
 cv::Mat diff,strength=cv::Mat::zeros(b.f.size(),CV_32F);
 // 与原逐档顺序一致：max可交换且无舍入，派生结果不依赖模糊完成先后
 for(const auto&bg:b.bg){diff=dark?bg-b.f:b.f-bg;cv::max(strength,diff,strength);}
 strength=strength/(strength+12.f)*255.f;cv::Mat out;strength.convertTo(out,CV_8U);cv::cvtColor(out,out,cv::COLOR_GRAY2BGR);return out;
}
inline double median(std::vector<double>v){if(v.empty())return 0;size_t n=v.size()/2;std::nth_element(v.begin(),v.begin()+n,v.end());double m=v[n];if(v.size()%2==0)m=(m+*std::max_element(v.begin(),v.begin()+n))/2;return m;}
struct Evidence {
 std::string role;cv::Rect box;double contrast=0,background=0,backgroundMAD=0,foreground=0,inkFraction=0;bool ok=false;
};
struct Verdict {std::set<std::string>reasons;std::vector<Evidence>parts;cv::Rect arrow;std::string direction;double backgroundRange=0;bool accepted()const{return reasons.empty();}};
inline Evidence checkPart(const cv::Mat&original,const cv::Mat&processed,cv::Rect box,int threshold,int sign,const std::string&role){
 Evidence e;e.role=role;e.box=box;cv::Rect bounds(0,0,original.cols,original.rows);
 if(box.empty()||(box&bounds)!=box)return e;
 int pad=std::max(2,navlite::rnd(box.height*.18));cv::Rect area=(cv::Rect(box.x-pad,box.y-pad,box.width+2*pad,box.height+2*pad)&bounds);
 cv::Mat local=processed(area),ink=local>=threshold,central=cv::Mat::zeros(area.size(),CV_8U);
 cv::Rect inner(box.x-area.x,box.y-area.y,box.width,box.height);ink(inner).copyTo(central(inner));
 int n=cv::countNonZero(central);e.inkFraction=double(n)/box.area();if(n<3)return e;
 cv::Mat dilated;cv::dilate(central,dilated,cv::getStructuringElement(cv::MORPH_ELLIPSE,{2*pad+1,2*pad+1}));
 cv::Mat ring=dilated&~ink;
 std::vector<double>fg,bg;cv::Mat raw=original(area);
 for(int y=0;y<raw.rows;y++)for(int x=0;x<raw.cols;x++){if(central.at<unsigned char>(y,x))fg.push_back(raw.at<unsigned char>(y,x));if(ring.at<unsigned char>(y,x))bg.push_back(raw.at<unsigned char>(y,x));}
 if(bg.size()<5)return e;
 e.foreground=median(fg);e.background=median(bg);e.contrast=sign*(e.foreground-e.background);
 std::vector<double>dev;for(auto v:bg)dev.push_back(std::abs(v-e.background));e.backgroundMAD=median(dev);
 e.ok=e.contrast>=8&&e.backgroundMAD<=20&&e.inkFraction>=.08&&e.inkFraction<=.9;
 return e;
}
inline Verdict verify(const cv::Mat&originalGray,const cv::Mat&processedGray,const navlite::Row&r,int sign){
 Verdict base;
 if(!r.accepted||!r.unit.found){base.reasons.insert("reader_rejected");return base;}
 double h=r.box.height;auto u=r.unit.box;
 if(u.x-r.box.br().x<-.1*h||u.x-r.box.br().x>.8*h||std::abs(u.br().y-r.box.br().y)>.45*h)base.reasons.insert("unit_line_alignment");
 for(auto g:r.glyphs)base.parts.push_back(checkPart(originalGray,processedGray,g.box,r.threshold,sign,"digit"));
 base.parts.push_back(checkPart(originalGray,processedGray,u,r.unit.threshold,sign,"unit"));
 for(auto&e:base.parts)if(!e.ok)base.reasons.insert(e.role+"_raw_stroke_unsupported");
 if(r.arrows.empty()){base.reasons.insert("missing_arrow");return base;}
 Verdict best;bool first=true;
 for(auto a:r.arrows){
  Verdict v=base;v.arrow=a.box;v.direction=a.direction;
  v.parts.push_back(checkPart(originalGray,processedGray,a.box,a.threshold,sign,"arrow"));
  if(!v.parts.back().ok)v.reasons.insert("arrow_raw_stroke_unsupported");
  double lo=255,hi=0;for(auto e:v.parts){lo=std::min(lo,e.background);hi=std::max(hi,e.background);}v.backgroundRange=hi-lo;
  if(v.backgroundRange>35)v.reasons.insert("inconsistent_local_background");
  if(first||v.reasons.size()<best.reasons.size()){best=v;first=false;}
 }
 return best;
}
} // namespace navgate
