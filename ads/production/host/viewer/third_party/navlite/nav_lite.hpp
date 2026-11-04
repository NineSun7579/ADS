#pragma once
#include <functional>
#include <opencv2/opencv.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <cfloat>
#include <map>
#include <set>
#include <string>
#include <vector>
#include "arrow_shapes.hpp"
#include "unit_ncc_cache.hpp"
#include "unit_ncc_bound.hpp"
#include "exact_arrow_bank.hpp"
#include "unit_batch_search.hpp"

namespace navlite {
inline int rnd(double x){return int(std::nearbyint(x));}
inline double overlap(cv::Rect a,cv::Rect b){return double((a&b).area())/std::max(1,std::min(a.area(),b.area()));}
struct Template {std::string label,source;cv::Mat mask;};
struct Glyph {cv::Rect box;int id=0;double p=0,margin=0,shape=0;char text='?';bool good=false,topologySupported=false;};
struct DigitComparison {cv::Rect box;int threshold=0;Glyph mlp,localTemplate;double mlpMs=0,templateMs=0;};
struct Arrow {cv::Rect box;std::string direction;double score=0,margin=0;int threshold=0;std::vector<std::string> relations;};
struct Unit {bool found=false,partial=false,conflict=false;std::string label;cv::Rect box;double score=0,iou=0;int threshold=0;bool segmented=false;};
struct Row {cv::Rect box;std::string number;Unit unit;std::vector<Glyph> glyphs;std::vector<cv::Rect> dots;std::set<std::string> reasons;std::vector<Arrow> arrows;int threshold=0;bool accepted=false;double meters=-1;std::string raw()const{return number+(unit.found?unit.label:"");}};
struct Component {cv::Rect box;int area,id;};
inline bool strokeLossConflict(const Glyph&low,int lowerThreshold,const Glyph&high,int higherThreshold,double rowHeight){
 if(lowerThreshold>=higherThreshold||!low.topologySupported||low.text==high.text||high.box.height>18||overlap(low.box,high.box)<.85)return false;
 // Ordinary antialias shrink is not evidence of a different digit. Require
 // a substantial horizontal collapse, as in a 3 reduced to its right stroke.
 bool lost=low.box.area()>=2.5*high.box.area()&&low.box.width>=1.8*high.box.width;
 return lost&&std::abs(low.box.br().y-high.box.br().y)<=.3*rowHeight;
}
// Compare complete hypotheses only after symbols have received their context.
// Return extra glyph indices when `whole` spatially contains `part` in order.
inline bool containsGlyphs(const Row&whole,const Row&part,std::vector<size_t>&extra){
 extra.clear();size_t j=0;
 for(size_t i=0;i<whole.glyphs.size();i++){
  auto g=whole.glyphs[i];if(!g.good)return false;
  if(j<part.glyphs.size()&&g.text==part.glyphs[j].text&&overlap(g.box,part.glyphs[j].box)>.8)j++;else extra.push_back(i);
 }
 return j==part.glyphs.size();
}
inline bool sameUnitLine(const Row&a,const Row&b){
 return a.unit.found&&b.unit.found&&a.unit.label==b.unit.label&&overlap(a.unit.box,b.unit.box)>.8&&
  std::abs(a.box.br().y-b.box.br().y)<.3*std::max(a.box.height,b.box.height)&&(a.box&b.box).area()>0;
}
// Distinct connected components may have slightly overlapping bounding boxes
// because italic/diagonal strokes interleave without touching.
inline bool nextDigitBox(cv::Rect previous,cv::Rect next,double height,bool complete){
 if(next.x>=previous.br().x)return true;
 return complete&&next.x>previous.x&&next.br().x>previous.br().x&&
  previous.br().x-next.x<=.15*height&&
  double(previous.br().x-next.x)<=.25*std::min(previous.width,next.width);
}
inline void rejectIncompleteDigitEvidence(std::vector<Row>&rows){
 for(auto&r:rows){if(!r.accepted)continue;
  for(const auto&other:rows){
   if(&other==&r||other.threshold==r.threshold||other.number==r.number||other.glyphs.size()!=r.glyphs.size()||other.glyphs.empty()||other.arrows.empty())continue;
   // Only a clean numeric row missing its unit can veto. Arbitrary noisy
   // hypotheses and shifted suffixes do not compete with a complete line.
   if(other.reasons!=std::set<std::string>{"missing_unit"})continue;
   bool aligned=true;for(size_t k=0;k<r.glyphs.size();k++){
    const auto&a=r.glyphs[k];const auto&b=other.glyphs[k];
    if(!b.good||overlap(a.box,b.box)<.8||std::abs(a.box.br().y-b.box.br().y)>.3*r.box.height)aligned=false;
   }
   if(aligned){r.reasons.insert("numeric_evidence_conflict");r.accepted=false;break;}
  }
 }
}
inline void resolveJointRows(std::vector<Row>&rows){
 // Snapshot validity: iteration order must not allow a rejected interpretation
 // to disappear and turn a conflicting short string into a confident result.
 std::vector<bool>complete;for(const auto&r:rows)complete.push_back(r.reasons.empty()&&!r.arrows.empty());
 for(size_t i=0;i<rows.size();i++)for(size_t j=0;j<rows.size();j++){
  if(i==j||!complete[i]||!complete[j])continue;auto&part=rows[i];auto&whole=rows[j];
  if(!sameUnitLine(part,whole)||part.number==whole.number)continue;
  std::vector<size_t>extra;if(!containsGlyphs(whole,part,extra))continue;
  bool dotsContained=true;for(auto d:part.dots)if(!std::any_of(whole.dots.begin(),whole.dots.end(),[&](cv::Rect z){return overlap(d,z)>.8;}))dotsContained=false;
  if(!dotsContained)continue;
  bool moreDots=whole.dots.size()>part.dots.size();if(extra.empty()&&!moreDots)continue;
  // A shorter interpretation must explain ALL omitted glyphs as its external
  // arrow(s). E.g. in 717 -> [1 as arrow]+7, the first 7 is still unaccounted
  // for, so that is an incomplete suffix, not a complete competing layout.
  bool competingArrow=!extra.empty();for(auto k:extra){bool covered=false;for(auto a:part.arrows)if(overlap(whole.glyphs[k].box,a.box)>.7)covered=true;if(!covered)competingArrow=false;}
  if(competingArrow){part.reasons.insert("digit_arrow_role_conflict");whole.reasons.insert("digit_arrow_role_conflict");}
  else part.reasons.insert(extra.empty()?"supported_decimal_in_other_threshold":"supported_complete_line_in_other_threshold");
 }
 for(auto&r:rows)r.accepted=r.reasons.empty()&&!r.arrows.empty();
 for(size_t i=0;i<rows.size();i++)for(size_t j=i+1;j<rows.size();j++)if(rows[i].accepted&&rows[j].accepted&&sameUnitLine(rows[i],rows[j])&&rows[i].number!=rows[j].number){
  rows[i].reasons.insert("joint_number_conflict");rows[j].reasons.insert("joint_number_conflict");
 }
 for(auto&r:rows)r.accepted=r.reasons.empty()&&!r.arrows.empty();
}
// Optional tracking geometry only. No previous text/value enters recognition.
struct SearchHint {cv::Rect digitBand;double digitHeight=0,unitHeight=0;bool trusted=false;cv::Rect unitBox;}; // unitBox：预测单位框（输入图坐标），仅几何
// Threshold masks are binary. Summed row spans compute the same normalized
// correlation without repeatedly multiplying every template/background pixel.
struct Span {int y,x0,x1;double weight;};
struct PreparedUnit {std::vector<Span>spans;double sum=0,norm=0;};
inline PreparedUnit prepareUnit(const cv::Mat&t){PreparedUnit p;double sq=0;for(int y=0;y<t.rows;y++){const auto*r=t.ptr<unsigned char>(y);for(int x=0;x<t.cols;){int end=x+1;while(end<t.cols&&r[end]==r[x])end++;if(r[x])p.spans.push_back({y,x,end,double(r[x])});p.sum+=(end-x)*double(r[x]);sq+=(end-x)*double(r[x])*r[x];x=end;}}p.norm=std::sqrt(std::max(0.,sq-p.sum*p.sum/t.total()));return p;}
inline void binaryCorrelation(const cv::Mat&integral,const cv::Mat&rowPrefix,const cv::Mat&t,const PreparedUnit&p,cv::Rect search,double&best,cv::Point&loc){
 best=-2;loc={0,0};double n=double(t.total());
 for(int y=0;y<=search.height-t.rows;y++)for(int x=0;x<=search.width-t.cols;x++){
  int X=search.x+x,Y=search.y+y;const double*up=integral.ptr<double>(Y);const double*down=integral.ptr<double>(Y+t.rows);double sum=down[X+t.cols]-down[X]-up[X+t.cols]+up[X];
  double variance=std::max(0.,sum*255.-sum*sum/n),den=std::sqrt(variance)*p.norm,cross=0,score=0;
  if(p.norm<1e-12)score=1;
  else if(variance>std::min(.5,10*double(FLT_EPSILON)*sum*255.)){
   for(auto s:p.spans){const int*r=rowPrefix.ptr<int>(Y+s.y);cross+=s.weight*(r[X+s.x1]-r[X+s.x0]);}
   double num=cross-sum*p.sum/n;
   if(std::abs(num)<den)score=num/den;else if(std::abs(num)<den*1.125)score=num>0?1:-1;
  }
  // OpenCV emits float scores; preserve its row-major tie handling.
  score=float(score);if(score>best){best=score;loc={x,y};}
 }
}
inline double multiplier(const std::string&s){return s=="km"||s=="公里"||s=="千米"?1000:1;}
inline std::vector<std::string> relation(cv::Rect a,cv::Rect d){
 double h=d.height,dx=(a.x+a.width*.5-d.x-d.width*.5)/h,dy=(a.y+a.height*.5-d.y-d.height*.5)/h;
 double vertical=double(std::max(0,std::min(d.y+d.height,a.y+a.height)-std::max(d.y,a.y)))/std::max(1,std::min(d.height,a.height));
 double gap=std::max({0,d.x-a.x-a.width,a.x-d.x-d.width});std::vector<std::string> r;
 if(dx>0&&a.x-d.x-d.width>=-.15*h&&a.x-d.x-d.width<=1.25*h&&vertical>=.4)r.push_back("right");
 if(dx<0&&d.x-a.x-a.width>=-.15*h&&d.x-a.x-a.width<=1.25*h&&vertical>=.4)r.push_back("left");
 if(dy<0&&d.y-a.y-a.height>=-.15*h&&d.y-a.y-a.height<=1.25*h&&gap<=.5*h)r.push_back("above");return r;
}
inline double shapeScore(const cv::Mat&crop,const cv::Mat&t){
 if(crop.size()==t.size()){
  int inter=0,uni=0;for(int y=0;y<crop.rows;y++){const auto*a=crop.ptr<unsigned char>(y);const auto*b=t.ptr<unsigned char>(y);for(int x=0;x<crop.cols;x++){bool aa=a[x]>100,bb=b[x]>100;inter+=aa&&bb;uni+=aa||bb;}}return double(inter)/std::max(1,uni);
 }
 double ratio=std::min(double(crop.cols)/t.cols,double(crop.rows)/t.rows);int w=std::max(1,rnd(t.cols*ratio)),h=std::max(1,rnd(t.rows*ratio));
 cv::Mat z,placed=cv::Mat::zeros(crop.size(),CV_8U),fg,inter,uni;cv::resize(t,z,{w,h},0,0,cv::INTER_AREA);z.copyTo(placed(cv::Rect((crop.cols-w)/2,(crop.rows-h)/2,w,h)));cv::compare(placed,100,placed,cv::CMP_GT);cv::compare(crop,100,fg,cv::CMP_GT);cv::bitwise_and(fg,placed,inter);cv::bitwise_or(fg,placed,uni);return double(cv::countNonZero(inter))/std::max(1,cv::countNonZero(uni));
}
// Only immutable Reader template-bank masks may enter this cache.
class ShapePreparation {
 using Key=std::tuple<uintptr_t,size_t,int,int,int,int>;
 struct Entry {cv::Mat source,placed;};
 std::map<Key,Entry> cache;
 size_t bytes=0;
 public:
 bool enabled=false,verify=false;
 size_t calls=0,hits=0,flushes=0,peakBytes=0;
 double score(const cv::Mat&crop,const cv::Mat&t){
  if(!enabled||crop.size()==t.size())return shapeScore(crop,t);
  ++calls;Key key(reinterpret_cast<uintptr_t>(t.data),t.step[0],t.cols,t.rows,crop.cols,crop.rows);
  auto found=cache.find(key);cv::Mat placed;
  if(found!=cache.end()){++hits;placed=found->second.placed;}
  else {
   double ratio=std::min(double(crop.cols)/t.cols,double(crop.rows)/t.rows);int w=std::max(1,rnd(t.cols*ratio)),h=std::max(1,rnd(t.rows*ratio));
   cv::Mat z;placed=cv::Mat::zeros(crop.size(),CV_8U);cv::resize(t,z,{w,h},0,0,cv::INTER_AREA);z.copyTo(placed(cv::Rect((crop.cols-w)/2,(crop.rows-h)/2,w,h)));cv::compare(placed,100,placed,cv::CMP_GT);
   constexpr size_t limit=8*1024*1024;size_t n=placed.total();
   if(n<=limit){if(bytes+n>limit||cache.size()>=4096){cache.clear();bytes=0;++flushes;}cache.emplace(key,Entry{t,placed});bytes+=n;peakBytes=std::max(peakBytes,bytes);}
  }
  cv::Mat fg,inter,uni;cv::compare(crop,100,fg,cv::CMP_GT);cv::bitwise_and(fg,placed,inter);cv::bitwise_or(fg,placed,uni);
  double result=double(cv::countNonZero(inter))/std::max(1,cv::countNonZero(uni));if(verify)CV_Assert(result==shapeScore(crop,t));return result;
 }
};
inline std::vector<Component> components(const cv::Mat&m,cv::Mat&labels){
 cv::Mat stats,cent;int n=cv::connectedComponentsWithStats(m,labels,stats,cent,8);std::vector<Component>cs;
 for(int i=1;i<n;i++)if(stats.at<int>(i,4)>=2)cs.push_back({cv::Rect(stats.at<int>(i,0),stats.at<int>(i,1),stats.at<int>(i,2),stats.at<int>(i,3)),stats.at<int>(i,4),i});return cs;
}
class Reader {
 navperf::UnitBatchSearch unitBatch;
 navperf::ExactArrowBank exactArrows;
 navperf::UnitNccBound unitBound;
 ShapePreparation arrowPreparation;
 navarrow::Matcher arrowMatcher;
 navarrow::Matcher coherentArrowMatcher{true};
 cv::Mat W1,b1,W2,b2;std::string classes;std::vector<Template>units,digits,arrows;
  std::map<std::tuple<int,int,int>,cv::Mat> scaled;
 std::map<std::tuple<int,int,int>,Unit> unitTrialCache;
 const SearchHint* activeHint=nullptr;
 navperf::UnitNccCache unitPreparation;
 int unitInputToken=0;
 static std::vector<Template> bank(cv::FileNode n){std::vector<Template>r;for(auto v:n){Template t;v["label"]>>t.label;v["source"]>>t.source;v["mask"]>>t.mask;r.push_back(t);}return r;}
public:
 // Copy options only. Models and all mutable caches remain instance-owned.
 void copyConfigurationTo(Reader&dst)const{
  dst.fastUnits=fastUnits;dst.unitHeightGate=unitHeightGate;dst.localUnitWindow=localUnitWindow;dst.unitWindowFallback=unitWindowFallback;dst.unitWindowSmallPixels=unitWindowSmallPixels;dst.parallelArrowBuild(arrowMatcher.parallelBuild);dst.verifyUnitGate=verifyUnitGate;dst.templateDigits=templateDigits;dst.compareDigits=compareDigits;
  dst.segmentSmallUnits=segmentSmallUnits;dst.jointRoles=jointRoles;dst.sampledArrows=sampledArrows;dst.completeDigits=completeDigits;
  dst.coherentRows=coherentRows;dst.rowScaleOnly=rowScaleOnly;dst.strictEvidenceOnly=strictEvidenceOnly;dst.refinedTurnsOnly=refinedTurnsOnly;
  dst.stableUnits=stableUnits;dst.splitDigits=splitDigits;dst.denseDigitThresholds=denseDigitThresholds;dst.regionCandidates=regionCandidates;
  dst.lazyRejectedUnits=lazyRejectedUnits;dst.stopInvalidChains=stopInvalidChains;dst.contextConsistency=contextConsistency;
  dst.reuseUnitPreparation=reuseUnitPreparation;dst.verifyUnitPreparation=verifyUnitPreparation;dst.reuseUnitPlans=reuseUnitPlans;
  dst.boundUnitNcc=boundUnitNcc;dst.verifyUnitBound=verifyUnitBound;dst.unitBound.earlyBlocks=unitBound.earlyBlocks;
  dst.batchUnitSearch=batchUnitSearch;dst.verifyUnitBatch=verifyUnitBatch;
  dst.reuseThresholdComponents=reuseThresholdComponents;dst.verifyThresholdComponents=verifyThresholdComponents;
  dst.exactLegacyArrows=exactLegacyArrows;dst.mergeArrowPasses=mergeArrowPasses;dst.verifyArrowAlgorithms=verifyArrowAlgorithms;
  dst.unitPreparation.reuseWindows=unitPreparation.reuseWindows;dst.unitPreparation.binaryRootLookup=unitPreparation.binaryRootLookup;
  dst.arrowPreparation.enabled=arrowPreparation.enabled;dst.arrowPreparation.verify=arrowPreparation.verify;
  dst.arrowMatcher.reuseScores=arrowMatcher.reuseScores;dst.arrowMatcher.verifyScores=arrowMatcher.verifyScores;
  dst.coherentArrowMatcher.reuseScores=coherentArrowMatcher.reuseScores;dst.coherentArrowMatcher.verifyScores=coherentArrowMatcher.verifyScores;
 }
 void reuseUnitWindows(bool enabled){unitPreparation.reuseWindows=enabled;}
 void binaryUnitRoots(bool enabled){unitPreparation.binaryRootLookup=enabled;}
 std::array<size_t,5> binaryUnitRootCounts()const{return {unitPreparation.binaryRequests,unitPreparation.binaryHits,unitPreparation.binaryBuilds,unitPreparation.binaryCells,unitPreparation.binaryPeakBytes};}
 std::array<size_t,7> unitWindowCounts()const{return {unitPreparation.windowRequests,unitPreparation.windowHits,unitPreparation.windowBuilds,unitPreparation.windowCells,unitPreparation.windowSavedCells,unitPreparation.windowPeakBytes,unitPreparation.windowEvictions};}
 bool batchUnitSearch=false,verifyUnitBatch=false;
 bool reuseThresholdComponents=false,verifyThresholdComponents=false;
 size_t componentLayerBuilds=0,componentLayerHits=0,componentLayerPixelsSaved=0;
 std::array<size_t,8> unitBatchCounts()const{return {unitBatch.requests,unitBatch.builds,unitBatch.reuses,unitBatch.rejected,unitBatch.ungrouped,unitBatch.planned,unitBatch.peakBytes,unitBatch.exactChecks};}
 double unitBatchPeakError()const{return unitBatch.maxPeakError;}
 bool exactLegacyArrows=false,mergeArrowPasses=false,verifyArrowAlgorithms=false;
 std::array<size_t,6> arrowAlgorithmCounts()const{return {exactArrows.calls,exactArrows.builds,exactArrows.hits,exactArrows.pruned,exactArrows.compared,exactArrows.peakBytes};}
 bool boundUnitNcc=false,verifyUnitBound=false;
 void earlyUnitBlocks(bool enabled){unitBound.earlyBlocks=enabled;}
 std::array<size_t,2> unitBlockCounts()const{return {unitBound.blockVisits,unitBound.earlyStops};}
 std::array<size_t,3> unitBoundCounts()const{return {unitBound.calls,unitBound.rejected,unitBound.positions};}
 void reuseArrowPreparation(bool enabled,bool verify=false){arrowPreparation.enabled=enabled;arrowPreparation.verify=verify;}
 std::array<size_t,4> arrowPreparationCounts()const{return {arrowPreparation.calls,arrowPreparation.hits,arrowPreparation.flushes,arrowPreparation.peakBytes};}
 void reuseArrowScores(bool enabled,bool verify=false){arrowMatcher.reuseScores=coherentArrowMatcher.reuseScores=enabled;arrowMatcher.verifyScores=coherentArrowMatcher.verifyScores=verify;}
 void parallelArrowBuild(bool enabled){arrowMatcher.parallelBuild=coherentArrowMatcher.parallelBuild=enabled;}
 size_t arrowReferenceBuilds()const{return arrowMatcher.referenceBuilds+coherentArrowMatcher.referenceBuilds;}
 std::array<size_t,3> arrowScoreCounts()const{return {arrowMatcher.scoreCalls+coherentArrowMatcher.scoreCalls,arrowMatcher.scoreHits+coherentArrowMatcher.scoreHits,arrowMatcher.scoreFlushes+coherentArrowMatcher.scoreFlushes};}
 bool reuseUnitPreparation=false,verifyUnitPreparation=false,reuseUnitPlans=false;
 std::array<size_t,3> unitPlanCounts()const{return {unitPreparation.planHits,unitPreparation.planCreates,unitPreparation.planEvictions};}
  bool fastUnits=false;
  // B档实验：按单位起点附近连通域高度限定单位模板尺度，附近无合适高度则跳过NCC；非逐位等价，默认关闭
  bool unitHeightGate=false;size_t unitGateSkips=0,unitGateScalesKept=0,unitGateScalesTotal=0;
  // 验证模式：同时跑完整搜索，门控漏掉完整结果时记录现场（单位框、观察高度、附近连通域），只用于诊断
  struct UnitGateMiss {int end,top,height;Unit full,gated;std::vector<int>observed;std::vector<cv::Rect>nearby;};
  double unitGateSmallScale=.7,unitGateTolerance=.12;
  bool verifyUnitGate=false;std::vector<UnitGateMiss>unitGateMisses;
  bool segmentSmallUnits=false;
  // Opt-in experiment only. Same connected-component candidates, shape bank,
  // number grouping and joint navigation rules as the MLP path.
  bool templateDigits=false,compareDigits=false;
  bool jointRoles=false; // Experimental complete-row role arbitration.
  bool sampledArrows=false; // Opt-in sampled geometry + original arrow bank.
  bool completeDigits=false; // Opt-in overlapping boxes + incomplete-row veto.
  bool coherentRows=false; // Opt-in row-scale units and touching-glyph splits.
  bool rowScaleOnly=false; // Ablation: whole-row unit geometry only.
  bool strictEvidenceOnly=false; // Ablation: veto digit/unit role contradictions.
  bool refinedTurnsOnly=false; // Ablation: supplemental U-turn geometry only.
  bool stableUnits=false; // Opt-in halo/core segmentation consensus.
  bool splitDigits=false; // Opt-in thin-bridge segmentation independently.
  bool denseDigitThresholds=false; // Rejected diagnostic ablation; never enabled in video configs.
  bool regionCandidates=false; // Caller must resolve competing spatial rows.
  bool lazyRejectedUnits=false; // Skip final unit search on already invalid rows.
  bool stopInvalidChains=false; // Diagnostic: stop extending a permanently invalid chain.
  bool contextConsistency=false; // Opt-in veto for border-sensitive digit classes.
  std::vector<DigitComparison> digitComparisons;
  std::vector<Row> jointCandidates; // Diagnostic hypotheses before deduplication.
  size_t unitCalls=0,templateCalls=0,fastHits=0,fastFallbacks=0,lazyUnitSkips=0;
  // 局部重读单位窗口（非逐位等价，默认关闭）：链延伸只查窗口；整行确认窗口无完整单位时回退完整搜索
  std::map<int,std::pair<cv::Mat,cv::Mat>>windowPrefixes;std::map<std::tuple<int,int,int>,PreparedUnit>windowUnits;bool localUnitWindow=false,finalUnitCall=false;size_t unitWindowHits=0,unitWindowFallbacks=0,unitWindowMisses=0,unitWindowFallbackFound=0;bool unitWindowFallback=true;double unitWindowSmallPixels=14;
    explicit Reader(const std::string&path){cv::FileStorage f(path,cv::FileStorage::READ);if(!f.isOpened())throw std::runtime_error("cannot load model");f["W1"]>>W1;f["b1"]>>b1;f["W2"]>>W2;f["b2"]>>b2;f["classes"]>>classes;units=bank(f["units"]);digits=bank(f["digits"]);arrows=bank(f["arrows"]);for(auto&t:arrows){arrowMatcher.add(t.label,t.mask);coherentArrowMatcher.add(t.label,t.mask);exactArrows.add(t.label,t.mask);}}
 cv::Mat vector(const cv::Mat&patch){
   cv::Mat c;patch.convertTo(c,CV_32F);if(cv::mean(c)[0]>127)c=255-c;
  std::vector<float>v;for(int y=0;y<c.rows;y++)for(int x=0;x<c.cols;x++)v.push_back(c.at<float>(y,x));std::sort(v.begin(),v.end());double q=.05*(v.size()-1);float low=v[int(q)]*(1-(q-int(q)))+v[std::min(int(q)+1,int(v.size()-1))]*(q-int(q));cv::max(c-low,0,c);
  int w=std::max(1,std::min(32,rnd(double(c.cols)*32/c.rows)));cv::Mat z,im=cv::Mat::zeros(32,32,CV_32F);cv::resize(c,z,{w,32},0,0,cv::INTER_AREA);z.copyTo(im(cv::Rect((32-w)/2,0,w,32)));double peak;cv::minMaxLoc(im,nullptr,&peak);if(peak>1e-6)im/=peak;im/=255;
  cv::Mat gx,gy;cv::Sobel(im,gx,CV_32F,1,0,3);cv::Sobel(im,gy,CV_32F,0,1,3);cv::Mat feat=cv::Mat::zeros(1,576,CV_32F);
  for(int y=0;y<32;y++)for(int x=0;x<32;x++){float a=gx.at<float>(y,x),b=gy.at<float>(y,x);float deg=std::atan2(b,a)*float(180/CV_PI);deg=std::fmod(deg+180.f,180.f);int bin=int(deg/20)%9;feat.at<float>(0,((y/4)*8+x/4)*9+bin)+=std::hypot(a,b);}
  for(int i=0;i<64;i++){float n=0;for(int k=0;k<9;k++)n+=std::pow(feat.at<float>(0,i*9+k),2);n=std::sqrt(n)+1e-6f;for(int k=0;k<9;k++)feat.at<float>(0,i*9+k)/=n;}feat/=cv::norm(feat)+1e-6;return feat;
 }
  Glyph predict(const cv::Mat&patch){cv::Mat h=vector(patch)*W1+b1;cv::max(h,0,h);cv::Mat logits=h*W2+b2;double max;cv::minMaxLoc(logits,nullptr,&max);cv::exp(logits-max,logits);logits/=cv::sum(logits)[0];if(classes.size()<2||logits.total()!=classes.size())throw std::runtime_error("digit model class mismatch");std::vector<int>order(classes.size());for(int i=0;i<int(classes.size());i++)order[i]=i;std::sort(order.begin(),order.end(),[&](int a,int b){return logits.at<float>(a)>logits.at<float>(b);});Glyph g;g.text=classes[order[0]];g.p=logits.at<float>(order[0]);g.margin=g.p-logits.at<float>(order[1]);return g;}
  Glyph predictTemplate(const cv::Mat&binary){
  std::map<char,double>byClass;for(auto&t:digits)byClass[t.label[0]]=std::max(byClass[t.label[0]],shapeScore(binary,t.mask));
  std::vector<std::pair<double,char>>scores;for(auto s:byClass)scores.push_back({s.second,s.first});std::sort(scores.rbegin(),scores.rend());Glyph g;
  if(scores.size()<2)return g;g.text=scores[0].second;g.p=g.shape=scores[0].first;g.margin=g.p-scores[1].first;
  // IoU and runner-up gap are shape scores, NOT probabilities. Fixed before
  // external evaluation; arbitrary symbols can still resemble a digit.
  g.good=g.shape>=.65&&g.margin>=.08;return g;
 }
  std::vector<Arrow> findArrows(const std::vector<Component>&cs,const cv::Mat&labels,int threshold){
    std::vector<Arrow>found;for(auto c:cs){auto b=c.box;double fill=double(c.area)/b.area();if(std::min(b.width,b.height)<8||fill<=.12||fill>=.83)continue;cv::Mat crop=labels(b)==c.id;std::map<std::string,double>scores;bool packed=exactLegacyArrows&&exactArrows.scores(crop,scores);if(!packed||verifyArrowAlgorithms){std::map<std::string,double>original;for(auto&t:arrows)original[t.label]=std::max(original[t.label],shapeScore(crop,t.mask));if(packed)CV_Assert(original==scores);else scores=std::move(original);}std::vector<std::pair<double,std::string>>s;for(auto&t:scores)s.push_back({t.second,t.first});std::sort(s.rbegin(),s.rend());bool legacy=s[0].first>=.58&&s[0].first-s[1].first>=.035;
    if(legacy)found.push_back({b,s[0].second,s[0].first,s[0].first-s[1].first,threshold,{}});
   }return found;
  }
  bool contextConflict(const cv::Mat&gray,const Glyph&glyph,int threshold){
   if(glyph.p>=.95)return false;std::set<char>interpretations{glyph.text};cv::Mat ink=gray(glyph.box)>=threshold;
   for(int pad:{0,1,3}){auto box=cv::Rect(glyph.box.x-pad,glyph.box.y-pad,glyph.box.width+2*pad,glyph.box.height+2*pad)&cv::Rect(0,0,gray.cols,gray.rows);auto vote=predict(gray(box));if(vote.text==glyph.text||vote.p<.4)continue;
    double shape=0;for(auto&t:digits)if(t.label[0]==vote.text)shape=std::max(shape,shapeScore(ink,t.mask));if(shape<.48)continue;
    interpretations.insert(vote.text);if(vote.p>=.9&&vote.margin>=.5)return true;
   }
   return interpretations.size()>=3;
  }
  bool publicationConflict(const cv::Mat&gray,const Glyph&glyph,int threshold){
   if(contextConflict(gray,glyph,threshold))return true;
   if(glyph.p>=.9)return false;
   cv::Mat ink=gray(glyph.box)>=threshold;auto best=predictTemplate(ink);if(best.text==glyph.text||best.shape<.7)return false;
   double selected=0;for(auto&t:digits)if(t.label[0]==glyph.text)selected=std::max(selected,shapeScore(ink,t.mask));
   // The top two shapes may both disagree with the MLP. A tie between 8/9
   // does not make the substantially worse interpretation 3 reliable. This
   // only vetoes the MLP class; it cannot choose either competing digit.
   return best.shape-selected>=.08;
  }
  std::vector<Arrow> sampledArrowCandidates(const std::vector<Component>&cs,const cv::Mat&labels,int threshold,const std::vector<Row>&rows,double minimum=.68){
   std::vector<Arrow>out;for(auto c:cs){auto b=c.box;double fill=double(c.area)/b.area();if(std::min(b.width,b.height)<8||std::max(b.width,b.height)>192||fill<=.12||fill>=.83)continue;
    bool near=false;for(const auto&r:rows){if(!r.reasons.empty()||!r.unit.found)continue;auto h=r.box.height;auto group=r.box|r.unit.box;
     if(overlap(b,r.box)>.05||overlap(b,r.unit.box)>.05||b.height<.45*h||b.height>3.5*h)continue;
     auto rel=relation(b,r.box),relGroup=relation(b,group);if(!rel.empty()||std::find(relGroup.begin(),relGroup.end(),"right")!=relGroup.end()){near=true;break;}}
    if(!near)continue;cv::Mat crop=labels(b)==c.id;bool extended=false;
    bool trackedIdentity=activeHint&&activeHint->trusted;
    if((coherentRows||refinedTurnsOnly)&&b.width>=12&&b.height>=(trackedIdentity?14:20)&&b.width>=.55*b.height&&b.width<=1.4*b.height)for(const auto&r:rows)if(r.reasons.empty()&&r.unit.found&&b.height>=(trackedIdentity?1.05:1.15)*r.box.height&&overlap(b,r.box)<.05&&!relation(b,r.box).empty())extended=true;
    auto scores=extended?coherentArrowMatcher.scores(crop):arrowMatcher.scores(crop);for(auto&t:arrows)scores[t.label]=std::max(scores[t.label],arrowPreparation.score(crop,t.mask));
    std::vector<std::pair<double,std::string>>ranked;for(auto s:scores)ranked.push_back({s.second,s.first});std::sort(ranked.rbegin(),ranked.rend());
    if(ranked.size()>1&&ranked[0].first>=minimum&&ranked[0].first-ranked[1].first>=.08){
     if((coherentRows||refinedTurnsOnly)&&ranked[0].second=="UTURN"){
      // Two legs, arch and arrowhead cannot be established from a narrow
      // 8px glyph that merely resembles a U. Preserve the spatial evidence
      // budget needed to distinguish a turn icon from text on this path.
      if(b.width<12||b.height<20||b.width<.65*b.height||b.width>1.25*b.height)continue;
      bool iconScale=false;for(const auto&r:rows)if(r.reasons.empty()&&r.unit.found&&b.height>=1.4*r.box.height&&overlap(b,r.box)<.05&&!relation(b,r.box).empty())iconScale=true;
      if(!iconScale)continue;
     }
     out.push_back({b,ranked[0].second,ranked[0].first,ranked[0].first-ranked[1].first,threshold,{}});
    }
   }return out;
  }
  Unit segmentedUnit(const cv::Mat&gray,int end,int top,int height,int cutoffOverride=-1){
  // Only infer segmentation statistics from the current number's adjacent
  // unit strip. Font bank is frozen; no video-specific templates or scales.
  cv::Rect bounds(0,0,gray.cols,gray.rows),region=cv::Rect(end,std::max(0,top),std::max(1,rnd(3.5*height)),std::max(1,rnd(1.3*height)))&bounds;
  if(region.width<3||region.height<3)return {};
   cv::Mat strip=gray(region),mask;double cutoff=cutoffOverride<0?cv::threshold(strip,mask,0,255,cv::THRESH_BINARY|cv::THRESH_OTSU):cv::threshold(strip,mask,cutoffOverride,255,cv::THRESH_BINARY);cv::Mat labels;auto cs=components(mask,labels);
  // The digit bbox was measured at another cutoff. One-pixel antialias tails
  // on the LEFT image boundary are incomplete fragments, not a skipped unit.
  cs.erase(std::remove_if(cs.begin(),cs.end(),[](const Component&c){return c.box.x==0&&c.box.width<=1;}),cs.end());
  // Support disconnected character strokes and multi-character units without
  // selecting a convenient suffix inside another component.
  std::vector<cv::Rect>boxes;for(auto c:cs){auto b=c.box;if(b.x<=.8*height&&b.height>=2&&b.br().y>=.4*height&&b.br().y<=1.25*height&&b.height<=1.2*height)boxes.push_back(b);}
  std::stable_sort(boxes.begin(),boxes.end(),[](cv::Rect a,cv::Rect b){return a.x<b.x;});
  struct Hit{Unit u;};std::vector<Hit>hits;std::set<std::tuple<int,int,int,int>>seen;
  for(size_t start=0;start<boxes.size();start++){
   auto joined=boxes[start];for(size_t j=start;j<std::min(boxes.size(),start+size_t(6));j++){
    if(j>start&&boxes[j].x-joined.br().x>.4*height)break;joined|=boxes[j];
    auto b=joined;if(b.height<4||b.height<.18*height||b.height>=.65*height||b.width<2||b.width>3.2*height)continue;
    // Disconnected strokes lying inside/along a word must be consumed too.
    bool incomplete=false;for(auto c:cs){auto z=c.box;if((z&b).area()>0&&(z&b)!=z)incomplete=true;}if(incomplete)continue;
    if(!seen.emplace(b.x,b.y,b.width,b.height).second)continue;
    auto crop=mask(b);int nonzero=cv::countNonZero(crop);double fill=double(nonzero)/b.area();if(fill<.12||fill>.85)continue;
    int canonicalHeight=32,canonicalWidth=std::max(1,rnd(double(b.width)*canonicalHeight/b.height));if(canonicalWidth>128)continue;cv::Mat c;cv::resize(crop,c,{canonicalWidth,canonicalHeight},0,0,cv::INTER_LINEAR);
    for(auto&t:units){double ar=double(t.mask.cols)/t.mask.rows,observed=double(b.width)/b.height;if(observed/ar<.72||observed/ar>1.38)continue;
     // Compare at matching information resolution: downsample the frozen font
     // to the observed pixel height FIRST. Fixed mild blur variants model
     // sampling/defocus, not new templates extracted from test videos.
     double score=-1,iou=0;int smallW=std::max(1,rnd(ar*b.height));cv::Mat sampled;cv::resize(t.mask,sampled,{smallW,b.height},0,0,cv::INTER_AREA);
     for(double blur:{0.,.5,1.}){
      cv::Mat low,binary,z;if(blur>0)cv::GaussianBlur(sampled,low,{},blur,blur);else low=sampled;cv::threshold(low,binary,0,255,cv::THRESH_BINARY|cv::THRESH_OTSU);
      int tw=std::max(1,rnd(binary.cols*32./binary.rows));cv::resize(binary,z,{tw,32},0,0,cv::INTER_LINEAR);
      int width=std::max(tw,canonicalWidth);cv::Mat a=cv::Mat::zeros(36,width+4,CV_8U),ref=a.clone();c.copyTo(a(cv::Rect((a.cols-c.cols)/2,2,c.cols,32)));z.copyTo(ref(cv::Rect((a.cols-tw)/2,2,tw,32)));
      cv::Mat correlation;cv::matchTemplate(a,ref,correlation,cv::TM_CCOEFF_NORMED);double s=correlation.at<float>(0),intersection=shapeScore(a,ref);if(intersection>=.48&&s>score){score=s;iou=intersection;}
     }
     if(score<.57||iou<.48)continue;Unit u;u.found=true;u.label=t.label;u.box=b+region.tl();u.score=score;u.iou=iou;u.threshold=int(cutoff)+1;u.segmented=true;
     bool skipped=false;for(auto comp:cs){auto z=comp.box;if(z.br().x<=b.x&&z.area()>=2&&std::abs(z.br().y-b.br().y)<.4*height)skipped=true;}if(skipped)continue;
     hits.push_back({u});
    }
   }
  }
  if(hits.empty())return {};std::stable_sort(hits.begin(),hits.end(),[](const Hit&a,const Hit&b){return a.u.score>b.u.score;});auto best=hits.front().u;
  for(auto h:hits)if(multiplier(h.u.label)!=multiplier(best.label)&&h.u.score>=best.score-.06&&overlap(h.u.box,best.box)>.6)best.conflict=true;
  return best;
 }
 // 单位可能起点（end-1..end+0.8h）处的墨迹高度。低分辨率下“米/公里”会碎成数个2-3px小块，
 // 因此除单个连通域外，再把链末端右侧、间距不超过2px的小连通域聚成簇，用簇高度。
 // 只聚末端右侧且不高于1.25h的连通域：排除数字本身与整屏背景大块。竖直带/高度范围沿用quick路径。
 static std::vector<int> unitHeights(const std::vector<Component>&cs,int end,int top,int height){
  std::vector<cv::Rect>near;for(const auto&c:cs){auto b=c.box;if(b.x>=end-1&&b.x<=end+3.6*height&&b.height<=1.25*height&&b.y>=top-.35*height&&b.br().y<=top+1.4*height)near.push_back(b);}
  auto plausible=[&](cv::Rect b){return b.height>=.35*height&&b.height<=1.25*height;};
  std::vector<int>out;for(auto b:near)if(b.x<=end+.8*height&&plausible(b))out.push_back(b.height);
  // 并查集按外扩2px相交聚簇；near通常只有几个到几十个
  std::vector<int>parent(near.size());for(size_t i=0;i<near.size();i++)parent[i]=int(i);
  std::function<int(int)>root=[&](int i){return parent[i]==i?i:parent[i]=root(parent[i]);};
  for(size_t i=0;i<near.size();i++)for(size_t k=i+1;k<near.size();k++){auto a=near[i];a.x-=2;a.y-=2;a.width+=4;a.height+=4;if((a&near[k]).area()>0)parent[root(int(i))]=root(int(k));}
  std::map<int,cv::Rect>clusters;std::map<int,int>members;for(size_t i=0;i<near.size();i++){int r=root(int(i));auto it=clusters.find(r);if(it==clusters.end())clusters[r]=near[i];else it->second|=near[i];members[r]++;}
  for(auto&[r,b]:clusters)if(members[r]>1&&b.x<=end+.8*height&&plausible(b))out.push_back(b.height);
  return out;
 }
 // 局部重读的单位窗口：单位应在预测单位框附近（左右各留1.3倍字高容纳位数变化的横移，上下0.5倍字高），
 // 尺度接近预测单位高度（±15%，至少2px）。只用位置/尺寸先验，不携带上次单位种类：17个模板全部参与，
 // 保留米/公里竞争与冲突判定。起点与纵向约束同matchUnit（end-1..end+0.8h，top-0.35h..top+1.4h）。
 Unit matchUnitWindow(const cv::Mat&mask,const cv::Mat&labels,const std::vector<Component>&cs,int end,int top,int height){
  const auto&hnt=*activeHint;double dh=std::max(1.,hnt.digitHeight);
  cv::Rect window(rnd(hnt.unitBox.x-1.3*dh),rnd(hnt.unitBox.y-.5*dh),rnd(hnt.unitBox.width+2.6*dh),rnd(hnt.unitBox.height+dh));
  int x0=std::max({0,end-1,window.x}),xLast=std::min(rnd(end+.8*height),window.br().x),y0=std::max({0,rnd(top-.35*height),window.y}),y1=std::min({mask.rows,rnd(top+1.4*height),window.br().y});
  if(xLast<x0||y1<=y0)return {};
  const double scales[]={.42,.5,.55,.6,.65,.7,.75,.82,.9,1.,1.16};std::vector<Unit>hits;std::set<std::tuple<int,int,int>>visited;
  // 窗口区域在一次analyze内固定：每个阈值的掩膜只对窗口区域建一次积分图与行前缀和；二值掩膜上用
  // binaryCorrelation直接按模板行段计算TM_CCOEFF_NORMED（含方差下限、截断、float化与行优先平局），
  // 只扫描本次调用允许的起点范围。小窗口上比DFT路径的固定开销小得多，仅有浮点舍入差
  cv::Rect region=window&cv::Rect(0,0,mask.cols,mask.rows);if(region.empty())return {};
  auto prefix=windowPrefixes.find(unitInputToken);
  if(prefix==windowPrefixes.end()){cv::Mat local=mask(region),integral,rows(local.rows,local.cols+1,CV_32S);cv::integral(local,integral,CV_64F);
   for(int y=0;y<local.rows;y++){const auto*src=local.ptr<unsigned char>(y);int*dst=rows.ptr<int>(y);dst[0]=0;for(int x=0;x<local.cols;x++)dst[x+1]=dst[x]+src[x];}
   prefix=windowPrefixes.emplace(unitInputToken,std::make_pair(integral,rows)).first;}
  for(int i=0;i<int(units.size());i++)for(double scale:scales){auto&t=units[i];int th=std::max(4,rnd(height*scale)),tw=std::max(2,rnd(double(t.mask.cols)*th/t.mask.rows));
   if(std::abs(th-hnt.unitHeight)>std::max(2.,.15*hnt.unitHeight))continue;auto key=std::make_tuple(i,tw,th);if(!visited.insert(key).second)continue;
   cv::Rect search=cv::Rect(x0-region.x,y0-region.y,xLast+tw-x0,y1-y0)&cv::Rect(0,0,region.width,region.height);if(search.width<tw||search.height<th)continue;
   if(!scaled.count(key))cv::resize(t.mask,scaled[key],{tw,th},0,0,cv::INTER_AREA);auto z=scaled[key];
   auto prepared=windowUnits.find(key);if(prepared==windowUnits.end())prepared=windowUnits.emplace(key,prepareUnit(z)).first;
   double score;cv::Point loc;++templateCalls;binaryCorrelation(prefix->second.first,prefix->second.second,z,prepared->second,search,score,loc);
   loc.x+=search.x+region.x-x0;loc.y+=search.y+region.y-y0;
   int xx=x0+loc.x,yy=y0+loc.y;if(score<.57)continue;cv::Rect box(xx,yy,tw,th);double iou=shapeScore(mask(box),z);if(iou<.48)continue;
   // 以下部分完整性与选优/冲突判定与matchUnit逐行相同
   cv::Mat inside=labels(box);int maxId=cs.empty()?0:cs.back().id;std::vector<int>counts(maxId+1,0);int ink=0;for(int y=0;y<inside.rows;y++){const int*ptr=inside.ptr<int>(y);for(int x=0;x<inside.cols;x++){int k=ptr[x];if(k<=maxId)counts[k]++;if(k)ink++;}}bool partial=false;for(auto c:cs)if(double(counts[c.id])/std::max(1,std::min(c.area,ink))>.35&&(c.box.x<xx-2||c.box.br().x>xx+tw+2||c.box.br().y>yy+th+2))partial=true;
   Unit u;u.found=true;u.partial=partial;u.label=t.label;u.box=box;u.score=score;u.iou=iou;hits.push_back(u);
  }
  if(hits.empty())return {};std::stable_sort(hits.begin(),hits.end(),[](const Unit&a,const Unit&b){return a.partial!=b.partial?!a.partial:a.score>b.score;});Unit best=hits[0];for(auto h:hits)if(h.partial==best.partial&&h.label.size()>best.label.size()&&h.score>=best.score-.07&&overlap(h.box,best.box)>.6){best=h;break;}for(auto h:hits)if(h.partial==best.partial&&multiplier(h.label)!=multiplier(best.label)&&h.score>=best.score-.035&&std::abs(h.box.x-best.box.x)<.25*height&&overlap(h.box,best.box)>.6)best.conflict=true;return best;
 }
 Unit matchUnit(const cv::Mat&mask,const cv::Mat&labels,const std::vector<Component>&cs,int end,int top,int height,bool quick=false){
  ++unitCalls;
  if(localUnitWindow&&!quick&&activeHint&&!activeHint->unitBox.empty()){Unit w=matchUnitWindow(mask,labels,cs,end,top,height);
   if(w.found&&!w.partial){++unitWindowHits;return w;}{const auto&hnt=*activeHint;double dh=std::max(1.,hnt.digitHeight);cv::Rect win(rnd(hnt.unitBox.x-1.3*dh),rnd(hnt.unitBox.y-.5*dh),rnd(hnt.unitBox.width+2.6*dh),rnd(hnt.unitBox.height+dh));cv::Rect reach(end-1,rnd(top-.35*height),std::max(1,rnd(.8*height)+1),std::max(1,rnd(1.75*height)));// 回退只留给小单位：小字形在阈值图中碎块化是像素级现象，按预测单位绝对高度判断（默认<14px）。
   // 大字号单位（回放中22-25px）在窗口内总能找到，其回退在回放中从未找到单位
   bool smallUnit=hnt.unitHeight<unitWindowSmallPixels;
   if(!unitWindowFallback||!smallUnit||!finalUnitCall||(reach&win).empty()){++unitWindowMisses;return w;}}++unitWindowFallbacks;// 回退：关闭窗口执行原完整搜索，并统计回退是否真正找到完整单位
   localUnitWindow=false;Unit full;try{full=matchUnit(mask,labels,cs,end,top,height);}catch(...){localUnitWindow=true;throw;}localUnitWindow=true;if(full.found&&!full.partial)++unitWindowFallbackFound;return full;}
  if(!quick)unitTrialCache.clear();
  if(fastUnits&&!quick){Unit candidate=matchUnit(mask,labels,cs,end,top,height,true);if(candidate.found&&!candidate.partial&&!candidate.conflict&&candidate.score>=.80&&candidate.iou>=.65){++fastHits;return candidate;}++fastFallbacks;}
  int x0=std::max(0,end-1),x1=std::min(mask.cols,rnd(end+3.6*height)),y0=std::max(0,rnd(top-.35*height)),y1=std::min(mask.rows,rnd(top+1.4*height));if(x1<=x0||y1<=y0)return {};
   cv::Mat roi=mask(cv::Rect(x0,y0,x1-x0,y1-y0));std::vector<Unit>hits;cv::Mat boundIntegral;
   if(boundUnitNcc&&roi.total()<1000000)cv::integral(roi,boundIntegral,CV_32S);
  const double scales[]={.42,.5,.55,.6,.65,.7,.75,.82,.9,1.,1.16};
  std::vector<int>observedHeights;
  if(quick){for(auto c:cs){auto b=c.box;if(b.x>=end-1&&b.x<=end+.8*height&&b.y>=top-.35*height&&b.br().y<=top+1.4*height&&b.height>=.35*height&&b.height<=1.25*height)observedHeights.push_back(b.height);}if(observedHeights.empty())return {};}
  else if(unitHeightGate&&verifyUnitGate){
   verifyUnitGate=unitHeightGate=false;Unit full=matchUnit(mask,labels,cs,end,top,height);unitHeightGate=true;Unit gated=matchUnit(mask,labels,cs,end,top,height);verifyUnitGate=true;
   if(full.found&&!full.partial&&!(gated.found&&gated.box==full.box&&gated.label==full.label)){UnitGateMiss miss{end,top,height,full,gated,unitHeights(cs,end,top,height),{}};
    for(const auto&c:cs)if((c.box&cv::Rect(full.box.x-height,full.box.y-height,full.box.width+2*height,full.box.height+2*height)).area()>0)miss.nearby.push_back(c.box);unitGateMisses.push_back(miss);}
   return gated;
  }
  // 小尺寸档（<=0.7h）的单位字形在阈值图中常碎块或与背景相连，连通域高度不可靠：始终全搜，只门控大尺寸档
  else if(unitHeightGate)observedHeights=unitHeights(cs,end,top,height);
  std::set<std::tuple<int,int,int>>visited;
  for(int i=0;i<int(units.size());i++)for(double scale:scales){auto&t=units[i];int th=std::max(4,rnd(height*scale)),tw=std::max(2,rnd(double(t.mask.cols)*th/t.mask.rows));if(th>roi.rows||tw>roi.cols)continue;auto key=std::make_tuple(i,tw,th);
   if(activeHint&&activeHint->unitHeight>0&&(th<activeHint->unitHeight*.6||th>activeHint->unitHeight*1.5))continue;
   if(!visited.insert(key).second)continue;
   if(unitHeightGate&&!quick)++unitGateScalesTotal;
   // quick保持原12%容差；门控容差可调：NCC最佳尺度常比墨迹高1-3px（抗锯齿边）
   if(quick&&!std::any_of(observedHeights.begin(),observedHeights.end(),[&](int h){return std::abs(h-th)<=std::max(2.,h*.12);}))continue;
   if(!quick&&unitHeightGate&&scale>unitGateSmallScale&&!std::any_of(observedHeights.begin(),observedHeights.end(),[&](int h){return std::abs(h-th)<=std::max(2.,h*unitGateTolerance);}))continue;
   if(unitHeightGate&&!quick)++unitGateScalesKept;
   if(fastUnits){auto cached=unitTrialCache.find(key);if(cached!=unitTrialCache.end()){if(cached->second.found)hits.push_back(cached->second);continue;}unitTrialCache[key]=Unit{};}
     if(!scaled.count(key))cv::resize(t.mask,scaled[key],{tw,th},0,0,cv::INTER_AREA);auto z=scaled[key];int cw=std::min(roi.cols,tw+std::max(0,int(end+.8*height-x0))+1);double score;cv::Point loc;cv::Mat result;++templateCalls;
       auto query=roi(cv::Rect(0,0,cw,roi.rows));
       if(batchUnitSearch&&!quick&&unitBatch.rejectWith(mask,z,unitInputToken,i,{x0,y0,cw,roi.rows},[&](const cv::Mat&group,cv::Mat&scores){
        bool prepared=(reuseUnitPreparation||verifyUnitPreparation)&&unitPreparation.match(group,z,i,unitInputToken,scores);
        if(!prepared)cv::matchTemplate(group,z,scores,cv::TM_CCOEFF_NORMED);
        if(verifyUnitPreparation&&prepared){cv::Mat expected;cv::matchTemplate(group,z,expected,cv::TM_CCOEFF_NORMED);CV_Assert(cv::norm(expected,scores,cv::NORM_INF)==0);}
       }))continue;
      if(!boundIntegral.empty()&&!unitBound.possible(boundIntegral,z,cw,roi.rows)){
       if(verifyUnitBound){cv::Mat expected;cv::matchTemplate(query,z,expected,cv::TM_CCOEFF_NORMED);double peak;cv::minMaxLoc(expected,nullptr,&peak);CV_Assert(peak<.57);}continue;
      }
      bool cached=(reuseUnitPreparation||verifyUnitPreparation)&&unitPreparation.match(query,z,i,unitInputToken,result);
     if(!cached)cv::matchTemplate(query,z,result,cv::TM_CCOEFF_NORMED);
     if(verifyUnitPreparation&&cached){cv::Mat expected;cv::matchTemplate(query,z,expected,cv::TM_CCOEFF_NORMED);CV_Assert(cv::norm(expected,result,cv::NORM_INF)==0);}
     cv::minMaxLoc(result,nullptr,&score,nullptr,&loc);int xx=x0+loc.x,yy=y0+loc.y;if(score<.57||xx-end>height*.8)continue;cv::Rect box(xx,yy,tw,th);double iou=shapeScore(mask(box),z);if(iou<.48)continue;
   cv::Mat inside=labels(box);int maxId=cs.empty()?0:cs.back().id;std::vector<int>counts(maxId+1,0);int ink=0;for(int y=0;y<inside.rows;y++){const int*ptr=inside.ptr<int>(y);for(int x=0;x<inside.cols;x++){int k=ptr[x];if(k<=maxId)counts[k]++;if(k)ink++;}}bool partial=false;for(auto c:cs)if(double(counts[c.id])/std::max(1,std::min(c.area,ink))>.35&&(c.box.x<xx-2||c.box.br().x>xx+tw+2||c.box.br().y>yy+th+2))partial=true;
   Unit u;u.found=true;u.partial=partial;u.label=t.label;u.box=box;u.score=score;u.iou=iou;hits.push_back(u);if(fastUnits)unitTrialCache[key]=u;
  }
  if(hits.empty())return {};std::stable_sort(hits.begin(),hits.end(),[](const Unit&a,const Unit&b){return a.partial!=b.partial?!a.partial:a.score>b.score;});Unit best=hits[0];for(auto h:hits)if(h.partial==best.partial&&h.label.size()>best.label.size()&&h.score>=best.score-.07&&overlap(h.box,best.box)>.6){best=h;break;}for(auto h:hits)if(h.partial==best.partial&&multiplier(h.label)!=multiplier(best.label)&&h.score>=best.score-.035&&std::abs(h.box.x-best.box.x)<.25*height&&overlap(h.box,best.box)>.6)best.conflict=true;return best;
 }
  void splitTouchingDigits(const cv::Mat&gray,cv::Mat&labels,std::vector<Component>&cs){
   // Split only a thin bridge. Every original foreground pixel is assigned
   // once, and BOTH pieces must independently satisfy digit evidence. No
   // convenient suffix, erase/dilate, test-derived glyph or old text is used.
   std::vector<Component>out;int nextId=cs.empty()?1:cs.back().id+1;
   for(auto c:cs){auto b=c.box;double ar=double(b.width)/b.height;
    if(b.height<12||b.height>80||ar<=1.05||ar>2.1||double(c.area)/b.area()<.15){out.push_back(c);continue;}
    cv::Mat binary=labels(b)==c.id;double best=-1;int cutBest=-1;std::string textBest;cv::Rect bestA,bestB;bool ambiguous=false;
    for(int cut=std::max(2,rnd(.25*b.height));cut<b.width-std::max(2,rnd(.25*b.height));cut++){
     int bridge=std::min(cv::countNonZero(binary.col(cut-1)),cv::countNonZero(binary.col(cut)));if(bridge>std::max(2.,.18*b.height))continue;
     cv::Rect ra(0,0,cut,b.height),rb(cut,0,b.width-cut,b.height);std::vector<cv::Point>pa,pb;cv::findNonZero(binary(ra),pa);cv::findNonZero(binary(rb),pb);if(pa.empty()||pb.empty())continue;
     ra=cv::boundingRect(pa)+ra.tl();rb=cv::boundingRect(pb)+rb.tl();bool good=true;std::string text;double score=1;
     for(auto z:{ra,rb}){if(z.height<.75*b.height||z.width<.22*b.height||double(z.width)/z.height>1.05){good=false;break;}auto global=z+b.tl();auto patch=cv::Rect(global.x-2,global.y-2,global.width+4,global.height+4)&cv::Rect(0,0,gray.cols,gray.rows);auto g=predict(gray(patch));for(auto&t:digits)if(t.label[0]==g.text)g.shape=std::max(g.shape,shapeScore(binary(z),t.mask));if(g.p<.9||g.margin<.5||g.shape<.48){good=false;break;}text+=g.text;score=std::min(score,g.shape);}
     if(!good)continue;score-=.05*bridge/b.height;
     if(score>best){ambiguous=!textBest.empty()&&text!=textBest&&score-best<.04;best=score;cutBest=cut;textBest=text;bestA=ra;bestB=rb;}
     else if(text!=textBest&&best-score<.04)ambiguous=true;
    }
    if(cutBest<0||ambiguous){out.push_back(c);continue;}
    int ida=nextId++,idb=nextId++;auto crop=labels(b);for(int y=0;y<crop.rows;y++)for(int x=0;x<crop.cols;x++)if(crop.at<int>(y,x)==c.id)crop.at<int>(y,x)=x<cutBest?ida:idb;
    out.push_back({bestA+b.tl(),cv::countNonZero(binary(bestA)),ida});out.push_back({bestB+b.tl(),cv::countNonZero(binary(bestB)),idb});
   }std::sort(out.begin(),out.end(),[](const Component&a,const Component&b){return a.id<b.id;});cs=std::move(out);
  }
   std::vector<Row> analyze(const cv::Mat&image,const SearchHint*hint=nullptr){
   unitPreparation.reusePlans=reuseUnitPlans;
   windowPrefixes.clear(); // 单位窗口积分图只在本次analyze内复用（掩膜随输入变化）
   unitPreparation.beginInput();
   struct InputGuard{navperf::UnitNccCache&cache;~InputGuard(){cache.beginInput();}} inputGuard{unitPreparation};
  digitComparisons.clear();
  jointCandidates.clear();
  struct HintGuard{const SearchHint*&dst;const SearchHint*old;~HintGuard(){dst=old;}} guard{activeHint,activeHint};activeHint=hint;
   cv::Mat gray;cv::cvtColor(image,gray,cv::COLOR_BGR2GRAY);int H=gray.rows,W=gray.cols;std::vector<Row>rows;std::vector<Arrow>all;
   struct TopologyEvidence{int threshold;Glyph glyph;cv::Mat pixels;};std::vector<TopologyEvidence>glyphTopology;
   struct ComponentLayer {cv::Mat mask,labels;std::vector<Component> cs;};std::map<int,ComponentLayer> rawLayers;
   auto layer=[&](int threshold){
    if(reuseThresholdComponents){auto it=rawLayers.find(threshold);if(it!=rawLayers.end()){
     ++componentLayerHits;componentLayerPixelsSaved+=gray.total();
     if(verifyThresholdComponents){cv::Mat checkMask=gray>=threshold,checkLabels;auto check=components(checkMask,checkLabels);CV_Assert(cv::norm(it->second.mask,checkMask,cv::NORM_INF)==0&&cv::norm(it->second.labels,checkLabels,cv::NORM_INF)==0&&it->second.cs.size()==check.size());for(size_t k=0;k<check.size();k++)CV_Assert(it->second.cs[k].id==check[k].id&&it->second.cs[k].area==check[k].area&&it->second.cs[k].box==check[k].box);}
     return it->second;
    }}
    ComponentLayer fresh;fresh.mask=gray>=threshold;fresh.cs=components(fresh.mask,fresh.labels);++componentLayerBuilds;if(reuseThresholdComponents)rawLayers.emplace(threshold,fresh);return fresh;
   };
   auto firstLayer=layer(150);cv::Mat umask=firstLayer.mask,ulabels=firstLayer.labels;auto ucs=std::move(firstLayer.cs);std::map<std::tuple<int,int,int,int,int>,Unit>searchCache;
   // 单位窗口启用时，整行确认（可回退完整搜索）与链延伸（仅窗口）的结果分开缓存；未启用时标记恒为0，缓存行为不变
   const bool unitWindowActive=localUnitWindow&&hint&&!hint->unitBox.empty();
   std::vector<int>thresholds={150,190,220};if(denseDigitThresholds&&hint&&hint->trusted)thresholds={110,130,150,170,190,200,210,220};
    for(int threshold:thresholds){cv::Mat mask,labels;std::vector<Component>cs;if(threshold==150){mask=umask;labels=ulabels;cs=ucs;}else{auto raw=layer(threshold);mask=raw.mask;labels=raw.labels;cs=std::move(raw.cs);}
    if(coherentRows||splitDigits){labels=labels.clone();splitTouchingDigits(gray,labels,cs);}
    auto as=findArrows(cs,labels,threshold);all.insert(all.end(),as.begin(),as.end());std::map<std::tuple<int,int,int,int>,Unit>cache;
    auto search=[&](int t,int end,int top,int h){auto key=std::make_tuple(t,end,top,h,int(unitWindowActive&&finalUnitCall));auto it=searchCache.find(key);if(it!=searchCache.end())return it->second;unitInputToken=t;Unit u=t==150?matchUnit(umask,ulabels,ucs,end,top,h):matchUnit(mask,labels,cs,end,top,h);u.threshold=t;return searchCache[key]=u;};
    auto readUnit=[&](int end,int top,int h){auto key=std::make_tuple(end,top,h,int(unitWindowActive&&finalUnitCall));if(cache.count(key))return cache[key];Unit a=search(threshold,end,top,h);if(a.found&&!a.partial)return cache[key]=a;Unit b;if(threshold!=150)b=search(150,end,top,h);Unit legacy=b.found&&!b.partial?b:(a.found?a:b);
    if(segmentSmallUnits&&(!legacy.found||legacy.partial)){Unit local=segmentedUnit(gray,end,top,h);bool digitFragment=false;
     if(local.found)for(auto c:cs){auto b=c.box;double aspect=double(b.width)/std::max(1,b.height);if(b.height>=.65*h&&b.height<=1.4*h&&aspect>=.12&&aspect<=1.05&&overlap(b,local.box)>.5)digitFragment=true;}
      if(local.found&&!local.conflict&&!digitFragment)return cache[key]=local;}
     if(stableUnits&&(!legacy.found||legacy.partial)){
      // Tight low-resolution strokes can be surrounded by a bright blur halo.
      // A single Otsu cutoff merges them. Test a fixed topology ladder, require
      // two adjacent masks to agree on unit class and location. No new fonts.
      Unit prior;for(int cutoff:{100,120,140,160,180,200}){auto current=segmentedUnit(gray,end,top,h,cutoff);
       if(current.found&&!current.conflict&&prior.found&&!prior.conflict&&current.label==prior.label&&overlap(current.box,prior.box)>.8&&double((current.box&prior.box).area())/std::max(current.box.area(),prior.box.area())>.65){
        bool digitFragment=false;for(auto c:cs)if(c.box.height>=.65*h&&c.box.height<=1.4*h&&overlap(c.box,current.box)>.5)digitFragment=true;
        if(!digitFragment)return cache[key]=current;
       }prior=current;
      }
     }
    return cache[key]=legacy;};
   std::vector<Glyph>gs;for(auto c:cs){auto b=c.box;double fill=double(c.area)/b.area();if(b.height<9||b.height>H*.65||double(b.width)/b.height<.12||double(b.width)/b.height>1.05||fill<=.13||fill>=.92)continue;
    if(hint&&(!hint->digitBand.contains(cv::Point(b.x+b.width/2,b.y+b.height/2))||b.height<hint->digitHeight*.55||b.height>hint->digitHeight*1.6))continue;
     bool ar=false;for(auto a:as)if(overlap(b,a.box)>.5)ar=true;if(ar&&!jointRoles)continue;cv::Rect patch= cv::Rect(b.x-2,b.y-2,b.width+4,b.height+4)&cv::Rect(0,0,W,H);cv::Mat crop=labels(b)==c.id;Glyph mlp,templ;double mlpMs=0,templateMs=0;
     if(!templateDigits||compareDigits){int64 start=compareDigits?cv::getTickCount():0;mlp=predict(gray(patch));for(auto&t:digits)if(t.label[0]==mlp.text)mlp.shape=std::max(mlp.shape,shapeScore(crop,t.mask));mlp.good=mlp.p>=.65&&mlp.margin>=.25&&mlp.shape>=.48;if(compareDigits)mlpMs=1000.*(cv::getTickCount()-start)/cv::getTickFrequency();}
    if(templateDigits||compareDigits){int64 start=compareDigits?cv::getTickCount():0;templ=predictTemplate(crop);if(compareDigits)templateMs=1000.*(cv::getTickCount()-start)/cv::getTickFrequency();}
     Glyph g=templateDigits?templ:mlp;
     if(coherentRows&&!templateDigits){auto evidence=predictTemplate(crop);
      if(evidence.text!=g.text&&evidence.shape>=.65&&evidence.margin>=.08&&g.p<.9)g.good=false;
     }
     g.box=b;g.id=c.id;
     if(stableUnits&&strictEvidenceOnly&&g.p>=.6&&g.shape>=.55){auto candidate=g;candidate.topologySupported=true;glyphTopology.push_back({threshold,candidate,crop});}
     gs.push_back(g);if(compareDigits)digitComparisons.push_back({b,threshold,mlp,templ,mlpMs,templateMs});}
   std::stable_sort(gs.begin(),gs.end(),[](const Glyph&a,const Glyph&b){return a.box.x<b.box.x;});std::set<int>used;
   if(batchUnitSearch){unitBatch.begin();unitBatch.verify=verifyUnitBatch;
    // Superset of possible chain endpoints. Unit evidence still determines
    // which of these paths the original chain builder actually takes.
    if(gs.size()<=64)for(const auto&seed:gs)if(seed.good){int y=seed.box.y,h=seed.box.height;std::vector<cv::Rect>reachable{seed.box};unitBatch.plan(seed.box.br().x,y,h);
     for(const auto&g:gs){auto b=g.box;if(double(b.height)/h<.65||double(b.height)/h>1.4||std::abs(b.br().y-y-h)>h*.28)continue;
      bool linked=false;for(auto previous:reachable)if(nextDigitBox(previous,b,h,completeDigits)&&b.x-previous.br().x<=h*.85){linked=true;break;}
      if(linked){unitBatch.plan(b.br().x,y,h);if(!(stopInvalidChains&&jointRoles&&!g.good))reachable.push_back(b);}
     }
    }
   }
       for(auto seed:gs){if((!jointRoles&&used.count(seed.id))||!seed.good)continue;int x=seed.box.x,y=seed.box.y,h=seed.box.height,end=seed.box.br().x;std::vector<Glyph>chain{seed};for(auto g:gs){auto b=g.box;if(!nextDigitBox(chain.back().box,b,h,completeDigits)||b.x-end>h*.85||double(b.height)/h<.65||double(b.height)/h>1.4||std::abs(b.br().y-y-h)>h*.28)continue;Unit u=readUnit(end,y,h);bool digitOccupiesUnit=coherentRows&&g.good&&b.height>=.75*h&&overlap(b,u.box)>.5;if(u.found&&!u.partial&&u.box.x<=b.x+b.width*.3&&u.score>=.68&&!digitOccupiesUnit)break;chain.push_back(g);end=b.br().x;if(stopInvalidChains&&jointRoles&&!g.good)break;}
    Row r;r.glyphs=chain;r.threshold=threshold;int miny=y,maxy=y+h;std::set<int>ids;for(size_t j=0;j<chain.size();j++){auto g=chain[j];used.insert(g.id);ids.insert(g.id);miny=std::min(miny,g.box.y);maxy=std::max(maxy,g.box.br().y);r.number+=g.text;if(!g.good)r.reasons.insert("uncertain_digit_or_non_digit");if(j+1<chain.size()){std::vector<cv::Rect>points;for(auto c:cs){auto b=c.box;if(b.x>=g.box.br().x&&b.x<chain[j+1].box.x&&b.width>=1&&b.width<=.3*h&&b.height>=1&&b.height<=.3*h&&b.y>=y+.65*h&&b.y<=y+1.12*h)points.push_back(b);}if(points.size()==1){r.number+='.';r.dots.push_back(points[0]);}else if(points.size()>1)r.reasons.insert("ambiguous_decimal");}}
     r.box={x,miny,end-x,maxy-miny};if(std::count(r.number.begin(),r.number.end(),'.')>1)r.reasons.insert("invalid_complete_number");
     if(x<=1||y<=1||end>=W-1||y+h>=H-1)r.reasons.insert("clipped_boundary");
     if(lazyRejectedUnits&&jointRoles){
      // These prefix checks do not depend on unit class/score. Row glyphs are
      // still retained as contradiction evidence for other complete rows.
      for(auto c:cs){auto b=c.box;bool arrow=false;for(auto a:as)if(overlap(b,a.box)>.5)arrow=true;bool prefix=x-b.br().x>=0&&x-b.br().x<.55*h;if(coherentRows&&b.x<x&&b.br().x>x&&b.br().x-x<=.25*std::min(b.width,r.box.width))prefix=true;
       if(!ids.count(c.id)&&!arrow&&prefix&&std::abs(b.br().y-y-h)<.3*h&&b.height>.45*h)r.reasons.insert("unconsumed_prefix");
      }
     }
     bool skipUnit=lazyRejectedUnits&&jointRoles&&!r.reasons.empty();
     if(skipUnit){++lazyUnitSkips;r.reasons.insert("unit_not_evaluated_for_rejected_row");}
     else {finalUnitCall=true;r.unit=coherentRows||rowScaleOnly?readUnit(end,miny,maxy-miny):readUnit(end,y,h);finalUnitCall=false;if(!r.unit.found)r.reasons.insert("missing_unit");else if(r.unit.conflict)r.reasons.insert("unit_conflict");}
     for(auto c:cs){auto b=c.box;bool ar=false;for(auto a:as)if(overlap(b,a.box)>.5)ar=true;bool nearPrefix=x-b.br().x>=0&&x-b.br().x<.55*h;if(coherentRows&&b.x<x&&b.br().x>x&&b.br().x-x<=.25*std::min(b.width,r.box.width))nearPrefix=true;if(!ids.count(c.id)&&!ar&&nearPrefix&&std::abs(b.br().y-y-h)<.3*h&&b.height>.45*h){r.reasons.insert("unconsumed_prefix");if(b.x<=1)r.reasons.insert("clipped_boundary");}bool dot=std::find(r.dots.begin(),r.dots.end(),b)!=r.dots.end();bool consumedUnit=segmentSmallUnits&&r.unit.found&&(r.unit.box.height>.3*h||r.unit.box.width>.6*h)&&double((b&r.unit.box).area())/std::max(1,b.area())>=.9;
      if(jointRoles&&!ids.count(c.id)&&!dot&&!consumedUnit&&b.x>=x&&b.br().x<=end&&b.height>.45*h&&std::abs(b.br().y-y-h)<.3*h){bool contained=false;for(auto g:chain)if((b&g.box)==b)contained=true;if(!contained)r.reasons.insert("unconsumed_internal_stroke");}
      if(!dot&&!consumedUnit&&b.width<=.3*h&&b.height<=.3*h&&b.y>=y+.65*h&&b.y<=y+1.12*h&&((x-b.br().x>=0&&x-b.br().x<=.4*h)||(b.x-end>=0&&b.x-end<=.4*h)))r.reasons.insert("unconsumed_decimal_or_punctuation");}
    if(r.unit.found){auto b=r.unit.box;if(b.br().x>=W-1)r.reasons.insert("clipped_unit");int right=std::max(end,b.x-1);cv::Mat unitMask;if(r.unit.segmented)unitMask=gray>=r.unit.threshold;else unitMask=r.unit.threshold==threshold?mask:umask;
     if(right>end&&cv::countNonZero(unitMask(cv::Rect(end,std::max(0,y),right-end,std::min(H,y+h)-std::max(0,y))))>.045*h*h)r.reasons.insert("unconsumed_number_unit_gap");if(r.unit.partial)r.reasons.insert("partial_unit_shape");try{r.meters=std::stod(r.number)*multiplier(r.unit.label);}catch(...){r.meters=-1;}}
    rows.push_back(r);
   }
  }
    if(segmentSmallUnits)for(auto&r:rows)if(r.unit.segmented||coherentRows)for(auto&other:rows)for(auto g:other.glyphs)if(g.good&&g.box.height>=(coherentRows?.75:.65)*r.box.height&&overlap(g.box,r.unit.box)>.5)r.reasons.insert("unit_overlaps_digit_evidence");
   if(sampledArrows){
    // Supplemental matching is conditioned on complete local number+unit
    // hypotheses, not a global search for arbitrary arrow-like scenery.
    // Check stability at nearby thresholds: the old 150/190/220 masks can
    // turn a clean shape into a merged blob or a broken skeleton. Agreement
    // is stability evidence for the SAME shape, not independent validation.
     std::vector<Arrow>extra,mergedSeeds;
     bool merged=mergeArrowPasses&&(coherentRows||refinedTurnsOnly);
     auto sameArrows=[](const std::vector<Arrow>&a,const std::vector<Arrow>&b){if(a.size()!=b.size())return false;for(size_t i=0;i<a.size();i++)if(a[i].box!=b[i].box||a[i].direction!=b[i].direction||a[i].score!=b[i].score||a[i].margin!=b[i].margin||a[i].threshold!=b[i].threshold||a[i].relations!=b[i].relations)return false;return true;};
      for(int threshold:{150,190,220}){auto raw=layer(threshold);auto candidates=sampledArrowCandidates(raw.cs,raw.labels,threshold,rows,merged?.60:.68);std::vector<Arrow>high;
       for(auto a:candidates){if(!merged||a.score>=.68){extra.push_back(a);if(merged&&verifyArrowAlgorithms)high.push_back(a);}if(merged&&a.direction=="UTURN")mergedSeeds.push_back(a);}
       if(merged&&verifyArrowAlgorithms)CV_Assert(sameArrows(high,sampledArrowCandidates(raw.cs,raw.labels,threshold,rows,.68)));
      }
     if(coherentRows||refinedTurnsOnly){
      // Only refine a pre-existing U-turn-shaped component. An unrestricted
      // adaptive search invented arrows in map texture in the first trial.
       std::set<std::tuple<int,int,int,int>>visited;std::vector<Arrow>seeds=mergedSeeds;
       if(!merged||verifyArrowAlgorithms){std::vector<Arrow>original;for(int th:{150,190,220}){auto raw=layer(th);for(auto a:sampledArrowCandidates(raw.cs,raw.labels,th,rows,.60))if(a.direction=="UTURN")original.push_back(a);}if(merged)CV_Assert(sameArrows(seeds,original));else seeds=std::move(original);}
      for(auto seed:seeds){auto b=seed.box;int pad=std::max(3,rnd(.2*std::max(b.width,b.height)));cv::Rect tile=(cv::Rect(b.x-pad,b.y-pad,b.width+2*pad,b.height+2*pad)&cv::Rect(0,0,W,H));if(!visited.emplace(tile.x,tile.y,tile.width,tile.height).second)continue;
       cv::Mat mask,labels;int cutoff=int(cv::threshold(gray(tile),mask,0,255,cv::THRESH_BINARY|cv::THRESH_OTSU))+1;if(cutoff<40||cutoff>230)continue;auto cs=components(mask,labels);auto localRows=rows;for(auto&r:localRows){r.box-=tile.tl();r.unit.box-=tile.tl();}
       for(auto a:sampledArrowCandidates(cs,labels,cutoff,localRows)){a.box+=tile.tl();if(a.direction=="UTURN"&&overlap(a.box,seed.box)>.8&&double((a.box&seed.box).area())/std::max(a.box.area(),seed.box.area())>.65)extra.push_back(a);}
      }
     }
    for(auto a:extra){bool stable=false;for(auto b:extra)if(a.threshold!=b.threshold&&a.direction==b.direction&&overlap(a.box,b.box)>.8&&double((a.box&b.box).area())/std::max(a.box.area(),b.box.area())>.65)stable=true;
     if(!stable){int pad=std::max(3,rnd(.2*std::max(a.box.width,a.box.height)));cv::Rect tile=(cv::Rect(a.box.x-pad,a.box.y-pad,a.box.width+2*pad,a.box.height+2*pad)&cv::Rect(0,0,W,H));
      for(int delta:{-10,10}){cv::Mat mask=gray(tile)>=a.threshold+delta,labels;auto cs=components(mask,labels);
       for(auto c:cs){auto b=c.box+tile.tl();if(c.box.x==0||c.box.y==0||c.box.br().x>=tile.width||c.box.br().y>=tile.height)continue;
        if(overlap(a.box,b)<.8||double((a.box&b).area())/std::max(a.box.area(),b.area())<.65)continue;
        auto scores=coherentRows||refinedTurnsOnly?coherentArrowMatcher.scores(labels(c.box)==c.id):arrowMatcher.scores(labels(c.box)==c.id);std::vector<std::pair<double,std::string>>ranked;for(auto s:scores)ranked.push_back({s.second,s.first});std::sort(ranked.rbegin(),ranked.rend());
        if(ranked.size()>1&&ranked[0].second==a.direction&&ranked[0].first>=.68&&ranked[0].first-ranked[1].first>=.08)stable=true;
       }if(stable)break;
      }
     }
     if(!stable)continue;bool conflict=false;for(auto b:all)if(a.direction!=b.direction&&overlap(a.box,b.box)>.8)conflict=true;
     if(!conflict)all.push_back(a);
    }
   }
   if(!jointRoles)for(auto&r:rows)for(auto g:r.glyphs)for(auto a:all)if(overlap(g.box,a.box)>.7)r.reasons.insert("glyph_overlaps_arrow");
  for(auto&r:rows){for(auto a:all){if(overlap(a.box,r.box)>.05||(r.unit.found&&overlap(a.box,r.unit.box)>.05)||a.box.height<.45*r.box.height||a.box.height>3.5*r.box.height)continue;auto rel=relation(a.box,r.box);rel.erase(std::remove(rel.begin(),rel.end(),"right"),rel.end());cv::Rect rb=r.box;if(r.unit.found)rb.width=std::max(rb.br().x,r.unit.box.br().x)-rb.x;auto rr=relation(a.box,rb);if(std::find(rr.begin(),rr.end(),"right")!=rr.end())rel.push_back("right");if(!rel.empty()){a.relations=rel;r.arrows.push_back(a);}}
    if(!jointRoles)for(auto&f:rows){if(&f==&r||!f.reasons.empty()||!r.unit.found||!f.unit.found||r.unit.label!=f.unit.label||overlap(r.unit.box,f.unit.box)<.8||f.glyphs.size()<=r.glyphs.size()||f.number.size()<r.number.size()||f.number.compare(f.number.size()-r.number.size(),r.number.size(),r.number)!=0)continue;bool valid=true;size_t off=f.glyphs.size()-r.glyphs.size();for(size_t i=0;i<r.glyphs.size();i++)if(r.glyphs[i].text!=f.glyphs[off+i].text||overlap(r.glyphs[i].box,f.glyphs[off+i].box)<=.8)valid=false;for(auto g:f.glyphs)if(!g.good)valid=false;if(valid){r.reasons.insert("supported_prefix_in_other_threshold");break;}}
   r.accepted=r.reasons.empty()&&!r.arrows.empty();
  }
    if(jointRoles)resolveJointRows(rows);
    if(completeDigits)rejectIncompleteDigitEvidence(rows);
    if(jointRoles)jointCandidates=rows;
   std::stable_sort(rows.begin(),rows.end(),[&](const Row&a,const Row&b){if(jointRoles&&a.accepted!=b.accepted)return a.accepted;if(a.reasons.size()!=b.reasons.size())return a.reasons.size()<b.reasons.size();if(a.number.size()!=b.number.size())return a.number.size()>b.number.size();double x=0,y=0;for(auto g:a.glyphs)x+=g.shape;for(auto g:b.glyphs)y+=g.shape;return x/a.glyphs.size()>y/b.glyphs.size();});
   std::vector<Row>selected;for(auto r:rows){int old=-1;for(int i=0;i<int(selected.size());i++)if(double((r.box&selected[i].box).area())/std::max(1,std::max(r.box.area(),selected[i].box.area()))>.7){old=i;break;}if(old<0)selected.push_back(r);else if(selected[old].number!=r.number&&(jointRoles?r.accepted:r.reasons.empty())){selected[old].accepted=false;selected[old].reasons.insert("threshold_number_conflict");}}
   std::set<double>values;for(auto&r:selected)if(r.accepted)values.insert(r.meters);if(!regionCandidates&&values.size()>1)for(auto&r:selected)if(r.accepted){r.accepted=false;r.reasons.insert("multiple_distance_conflict");}
    std::map<std::tuple<int,int,int,int,int>,Glyph>shapeVotes;
    auto shapeVote=[&](cv::Rect b,int threshold){auto key=std::make_tuple(b.x,b.y,b.width,b.height,threshold);auto it=shapeVotes.find(key);if(it==shapeVotes.end())it=shapeVotes.emplace(key,predictTemplate(gray(b)>=threshold)).first;return it->second;};
    std::vector<Glyph>contradictions;
    if(stableUnits&&strictEvidenceOnly)for(const auto&candidate:rows)for(auto g:candidate.glyphs){if(!g.good||g.p>=.9)continue;auto t=shapeVote(g.box,candidate.threshold);if(t.text!=g.text&&t.shape>=.65&&t.margin>=.04)contradictions.push_back(g);}
   if(strictEvidenceOnly)for(auto&r:selected)if(r.accepted){
     auto raw=layer(r.threshold);cv::Mat mask=raw.mask,labels=raw.labels;auto cs=std::move(raw.cs);
    for(auto g:r.glyphs){if(g.p<.9){auto t=shapeVote(g.box,r.threshold);if(t.text!=g.text&&t.shape>=.65&&t.margin>=(stableUnits?.04:.08))r.reasons.insert("digit_template_contradiction");}
     if(contextConsistency&&contextConflict(gray,g,r.threshold))r.reasons.insert("digit_context_conflict");
     if(stableUnits)for(const auto&e:glyphTopology)if(strokeLossConflict(e.glyph,e.threshold,g,r.threshold,r.box.height)){
      auto vote=predictTemplate(e.pixels);if(vote.text==e.glyph.text&&vote.shape>=.55&&vote.margin>=.01)r.reasons.insert("threshold_stroke_loss_conflict");
     }
    }
    for(auto g:r.glyphs)for(auto evidence:contradictions)if(g.text==evidence.text&&overlap(g.box,evidence.box)>.8)r.reasons.insert("digit_template_contradiction");
    for(auto&other:rows)for(auto g:other.glyphs)if(g.good&&g.box.height>=.75*r.box.height&&overlap(g.box,r.unit.box)>.5)r.reasons.insert("unit_overlaps_digit_evidence");
    for(auto c:cs){auto b=c.box;bool prefix=b.x<r.box.x&&b.br().x>r.box.x&&b.br().x-r.box.x<=.25*std::min(b.width,r.box.width)&&b.height>.45*r.box.height&&std::abs(b.br().y-r.box.br().y)<.3*r.box.height;bool arrow=false;for(auto a:r.arrows)if(overlap(a.box,b)>.7)arrow=true;if(prefix&&!arrow)r.reasons.insert("unconsumed_prefix");}
    if(!r.reasons.empty())r.accepted=false;
   }
   return selected;
 }
};
} // namespace navlite
