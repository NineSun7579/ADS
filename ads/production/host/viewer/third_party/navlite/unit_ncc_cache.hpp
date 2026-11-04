// Adapted from OpenCV 4.6.0 modules/imgproc/src/templmatch.cpp.
// Copyright (C) 2000, Intel Corporation, all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * The name of Intel Corporation may not be used to endorse or promote
//   products derived from this software without specific prior written permission.
// This software is provided by the copyright holders and contributors "as is"
// and any express or implied warranties, including, but not limited to, the
// implied warranties of merchantability and fitness for a particular purpose
// are disclaimed. In no event shall the Intel Corporation or contributors be
// liable for any direct, indirect, incidental, special, exemplary, or
// consequential damages (including, but not limited to, procurement of
// substitute goods or services; loss of use, data, or profits; or business
// interruption) however caused and on any theory of liability, whether in
// contract, strict liability, or tort (including negligence or otherwise)
// arising in any way out of the use of this software, even if advised of the
// possibility of such damage.
#pragma once
#include <opencv2/opencv.hpp>
#include <opencv2/core/hal/hal.hpp>
#include <map>
#include <tuple>
#include <cstdint>
#include <cfloat>
#include <cmath>
#include <vector>

namespace navperf {
// Single-channel CV_8U, one-block OpenCV4.6 CCOEFF_NORMED path only.
// Template identity and dimensions must identify immutable pixels for this
// instance. beginInput() invalidates ALL image-derived data before analyze().
class UnitNccCache {
 using TemplateKey=std::tuple<int,int,int>;
 using SpectrumKey=std::tuple<int,int,int,int,int>;
 using ImageKey=std::tuple<int,uintptr_t,size_t,int,int>;
 using ImageSpectrumKey=std::tuple<ImageKey,int,int>;
 struct Stats {double mean=0,norm=0,invArea=0;bool constant=false;};
 struct Integral {cv::Mat sum,square;bool binary=false;};
 std::map<std::pair<int,int>,std::vector<double>> binaryRoots;
 size_t binaryRootBytes=0;
 std::map<TemplateKey,Stats> statistics;
 std::map<SpectrumKey,cv::Mat> templates;
 std::map<ImageSpectrumKey,cv::Mat> images;
 std::map<ImageKey,Integral> integrals;
 using WindowKey=std::tuple<ImageKey,int,int>;
 struct Window {cv::Mat sum,root;};
 std::map<WindowKey,Window> windows;
 size_t windowBytes=0;
 static constexpr size_t windowLimit=8*1024*1024;
 using PlanKey=std::tuple<int,int,int,int>;
 std::map<PlanKey,cv::Ptr<cv::hal::DFT2D>> plans;
 size_t templateBytes=0,imageBytes=0,integralBytes=0;
 static constexpr size_t templateLimit=32*1024*1024,imageLimit=24*1024*1024,integralLimit=16*1024*1024;
 static size_t bytes(const cv::Mat&m){return m.total()*m.elemSize();}
 void transform(cv::Mat&data,int flags,int nonzero){
   // Plans own mutable work buffers: keep them per Reader, never global.
   // nonzero and inverse/scale flags are part of the execution contract.
   auto key=PlanKey(data.cols,data.rows,flags,nonzero);
   cv::Ptr<cv::hal::DFT2D> plan;
   auto found=plans.find(key);
   if(reusePlans&&found!=plans.end()){plan=found->second;planHits++;}
   else {plan=cv::hal::DFT2D::create(data.cols,data.rows,CV_32F,1,1,CV_HAL_DFT_IS_INPLACE|flags,nonzero);planCreates++;
    if(reusePlans){if(plans.size()>=256){plans.clear();planEvictions++;}plans.emplace(key,plan);}}
   plan->apply(data.data,int(data.step),data.data,int(data.step));
 }
public:
 bool reusePlans=false;
 bool reuseWindows=false;
 bool binaryRootLookup=false;
 size_t binaryRequests=0,binaryHits=0,binaryBuilds=0,binaryCells=0,binaryPeakBytes=0;
 size_t windowRequests=0,windowHits=0,windowBuilds=0,windowEvictions=0,windowCells=0,windowSavedCells=0,windowPeakBytes=0;
 size_t planHits=0,planCreates=0,planEvictions=0;
 size_t calls=0,templateHits=0,imageHits=0,integralHits=0,fallbacks=0;
 void beginInput(){images.clear();integrals.clear();windows.clear();imageBytes=integralBytes=windowBytes=0;}
 void clear(){beginInput();templates.clear();statistics.clear();plans.clear();binaryRoots.clear();binaryRootBytes=0;templateBytes=0;}
  size_t retainedBytes()const{return templateBytes+imageBytes+integralBytes+windowBytes+binaryRootBytes;}
 bool match(const cv::Mat&image,const cv::Mat&templ,int templateId,int inputToken,cv::Mat&result){
  calls++;
  if(CV_VERSION_MAJOR!=4||CV_VERSION_MINOR!=6||image.type()!=CV_8UC1||templ.type()!=CV_8UC1||image.cols>256||image.rows>256||templ.cols>image.cols||templ.rows>image.rows||templ.empty()){fallbacks++;return false;}
  cv::Size size(image.cols-templ.cols+1,image.rows-templ.rows+1),dftSize(std::max(2,cv::getOptimalDFTSize(image.cols)),cv::getOptimalDFTSize(image.rows));
  auto templateKey=TemplateKey(templateId,templ.cols,templ.rows);
  auto statistic=statistics.find(templateKey);
  if(statistic==statistics.end()){
   if(statistics.size()>=10000)statistics.clear();
   cv::Scalar mean,deviation;cv::meanStdDev(templ,mean,deviation);Stats s;s.invArea=1./(double(templ.rows)*templ.cols);s.mean=mean[0];
   double norm=deviation[0]*deviation[0]+deviation[1]*deviation[1]+deviation[2]*deviation[2]+deviation[3]*deviation[3];s.constant=norm<DBL_EPSILON;s.norm=std::sqrt(norm);s.norm/=std::sqrt(s.invArea);statistic=statistics.emplace(templateKey,s).first;
  }
  Stats stats=statistic->second;result.create(size,CV_32F);
  if(stats.constant){result.setTo(1);return true;}
  auto spectrumKey=SpectrumKey(templateId,templ.cols,templ.rows,dftSize.width,dftSize.height);auto it=templates.find(spectrumKey);cv::Mat templateSpectrum;
  if(it!=templates.end()){templateSpectrum=it->second;templateHits++;}else{
   templateSpectrum=cv::Mat::zeros(dftSize,CV_32F);cv::Mat tile=templateSpectrum(cv::Rect(0,0,templ.cols,templ.rows));templ.convertTo(tile,CV_32F);transform(templateSpectrum,0,templ.rows);
   if(templateBytes+bytes(templateSpectrum)>templateLimit){templates.clear();templateBytes=0;}templates.emplace(spectrumKey,templateSpectrum);templateBytes+=bytes(templateSpectrum);
  }
  ImageKey imageKey(inputToken,reinterpret_cast<uintptr_t>(image.data),image.step,image.cols,image.rows);auto imageSpectrumKey=ImageSpectrumKey(imageKey,dftSize.width,dftSize.height);auto found=images.find(imageSpectrumKey);cv::Mat product;
  if(found!=images.end()){product=found->second.clone();imageHits++;}else{
   product=cv::Mat::zeros(dftSize,CV_32F);cv::Mat tile=product(cv::Rect(0,0,image.cols,image.rows));image.convertTo(tile,CV_32F);transform(product,0,image.rows);
   if(imageBytes+bytes(product)>imageLimit){images.clear();imageBytes=0;}images.emplace(imageSpectrumKey,product.clone());imageBytes+=bytes(product);
  }
  cv::mulSpectrums(product,templateSpectrum,product,0,true);transform(product,CV_HAL_DFT_INVERSE|CV_HAL_DFT_SCALE,size.height);product(cv::Rect(0,0,size.width,size.height)).copyTo(result);
  auto integral=integrals.find(imageKey);
  if(integral==integrals.end()){
    Integral value;cv::integral(image,value.sum,value.square,CV_64F);size_t cost=bytes(value.sum)+bytes(value.square);
    if(binaryRootLookup){value.binary=true;for(int y=0;y<image.rows&&value.binary;y++){const uchar*p=image.ptr<uchar>(y);for(int x=0;x<image.cols;x++)if(p[x]!=0&&p[x]!=255){value.binary=false;break;}}}
   if(integralBytes+cost>integralLimit){integrals.clear();integralBytes=0;}integral=integrals.emplace(imageKey,value).first;integralBytes+=cost;
  }else integralHits++;
  const auto&sum=integral->second.sum;const auto&square=integral->second.square;
  const double*p0=sum.ptr<double>(),*p1=p0+templ.cols,*p2=sum.ptr<double>(templ.rows),*p3=p2+templ.cols;
  const double*q0=square.ptr<double>(),*q1=q0+templ.cols,*q2=square.ptr<double>(templ.rows),*q3=q2+templ.cols;
   int sumstep=int(sum.step/sizeof(double)),sqstep=int(square.step/sizeof(double));
    if(binaryRootLookup&&integral->second.binary)return normalizeBinary(result,stats,sum,templ.size());
    if(reuseWindows){
    ++windowRequests;WindowKey key(imageKey,templ.cols,templ.rows);auto foundWindow=windows.find(key);
    if(foundWindow==windows.end()){
     Window value;value.sum.create(result.size(),CV_64F);value.root.create(result.size(),CV_64F);
     for(int y=0;y<result.rows;y++){double*s=value.sum.ptr<double>(y),*r=value.root.ptr<double>(y);int idx=y*sumstep,idx2=y*sqstep;
      for(int x=0;x<result.cols;x++,idx++,idx2++){
       double t=p0[idx]-p1[idx]-p2[idx]+p3[idx],mean2=t*t;mean2*=stats.invArea;
       double sum2=q0[idx2]-q1[idx2]-q2[idx2]+q3[idx2],diff=std::max(sum2-mean2,0.);
       s[x]=t;r[x]=diff<=std::min(.5,10*FLT_EPSILON*sum2)?0:std::sqrt(diff);
      }
     }
      size_t cost=bytes(value.sum)+bytes(value.root);if(cost>windowLimit)return normalizeUncached(result,stats,sum,square,templ.size());
     if(windowBytes+cost>windowLimit){windows.clear();windowBytes=0;++windowEvictions;}
     foundWindow=windows.emplace(key,std::move(value)).first;windowBytes+=cost;windowPeakBytes=std::max(windowPeakBytes,windowBytes);++windowBuilds;windowCells+=result.total();
    }else {++windowHits;windowSavedCells+=result.total();}
    for(int y=0;y<result.rows;y++){float*row=result.ptr<float>(y);const double*s=foundWindow->second.sum.ptr<double>(y),*r=foundWindow->second.root.ptr<double>(y);
     for(int x=0;x<result.cols;x++){double num=row[x],t=r[x]*stats.norm;num-=s[x]*stats.mean;
      if(std::fabs(num)<t)num/=t;else if(std::fabs(num)<t*1.125)num=num>0?1:-1;else num=0;row[x]=float(num);
     }
    }return true;
   }
    return normalizeUncached(result,stats,sum,square,templ.size());
  }
 private:
   static bool normalizeUncached(cv::Mat&result,const Stats&stats,const cv::Mat&sum,const cv::Mat&square,cv::Size templ){
   // Same operation order as OpenCV's original CV_8U single-channel path.
    const double*p0=sum.ptr<double>(),*p1=p0+templ.width,*p2=sum.ptr<double>(templ.height),*p3=p2+templ.width;
    const double*q0=square.ptr<double>(),*q1=q0+templ.width,*q2=square.ptr<double>(templ.height),*q3=q2+templ.width;
    int sumstep=int(sum.step/sizeof(double)),sqstep=int(square.step/sizeof(double));
  for(int y=0;y<result.rows;y++){float*row=result.ptr<float>(y);int idx=y*sumstep,idx2=y*sqstep;for(int x=0;x<result.cols;x++,idx++,idx2++){
   double num=row[x],t=p0[idx]-p1[idx]-p2[idx]+p3[idx],mean2=t*t;num-=t*stats.mean;mean2*=stats.invArea;
   double sum2=q0[idx2]-q1[idx2]-q2[idx2]+q3[idx2];double diff=std::max(sum2-mean2,0.);
   if(diff<=std::min(.5,10*FLT_EPSILON*sum2))t=0;else t=std::sqrt(diff)*stats.norm;
   if(std::fabs(num)<t)num/=t;else if(std::fabs(num)<t*1.125)num=num>0?1:-1;else num=0;row[x]=float(num);
   }}return true;
  }
  bool normalizeBinary(cv::Mat&result,const Stats&stats,const cv::Mat&sum,cv::Size templ){
   ++binaryRequests;auto key=std::make_pair(templ.width,templ.height);auto root=binaryRoots.find(key);
   if(root==binaryRoots.end()){
    std::vector<double> table(size_t(templ.area())+1);
    for(size_t k=0;k<table.size();k++){
     double t=double(k)*255,mean2=t*t;mean2*=stats.invArea;
     double sum2=double(k)*65025,diff=std::max(sum2-mean2,0.);
     table[k]=diff<=std::min(.5,10*FLT_EPSILON*sum2)?0:std::sqrt(diff);
    }
    size_t cost=table.size()*sizeof(double);constexpr size_t limit=4*1024*1024;
    if(binaryRootBytes+cost>limit){binaryRoots.clear();binaryRootBytes=0;}
    root=binaryRoots.emplace(key,std::move(table)).first;binaryRootBytes+=cost;binaryPeakBytes=std::max(binaryPeakBytes,binaryRootBytes);++binaryBuilds;
   }else ++binaryHits;
   const double*p0=sum.ptr<double>(),*p1=p0+templ.width,*p2=sum.ptr<double>(templ.height),*p3=p2+templ.width;int step=int(sum.step/sizeof(double));
   for(int y=0;y<result.rows;y++){float*row=result.ptr<float>(y);int idx=y*step;for(int x=0;x<result.cols;x++,idx++){
    double num=row[x],s=p0[idx]-p1[idx]-p2[idx]+p3[idx];
    // Binary CV_8U, <=256x256: s is an exact nonnegative multiple of 255,
    // <=16711680. Integer constant division avoids a scalar FP divide.
    double t=root->second[static_cast<unsigned>(s)/255u]*stats.norm;num-=s*stats.mean;
    if(std::fabs(num)<t)num/=t;else if(std::fabs(num)<t*1.125)num=num>0?1:-1;else num=0;row[x]=float(num);
   }}binaryCells+=result.total();return true;
  }
 };
}
