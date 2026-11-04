#pragma once
#include "nav_tracker.hpp"
#include <condition_variable>
#include <deque>
#include <mutex>
#include <memory>
#include <thread>
#include <array>
#include <future>
#include "normalization_window.hpp"

namespace navasync {
// Position state deliberately contains NO text, distance, unit class or direction.
struct Geometry {
 cv::Rect digit,unit;std::vector<cv::Rect>arrows;
 static Geometry from(const navlite::Row&r){Geometry g;g.digit=r.box;g.unit=r.unit.box;for(auto a:r.arrows)g.arrows.push_back(a.box);return g;}
 Geometry transformed(const cv::Mat&a)const{Geometry g;g.digit=navtrack::moved(digit,a);g.unit=navtrack::moved(unit,a);for(auto b:arrows)g.arrows.push_back(navtrack::moved(b,a));return g;}
 cv::Rect bounds()const{cv::Rect b=digit|unit;for(auto a:arrows)b|=a;return b;}
};
// UI text reflows when the number of digits changes. A continuously tracked
// icon and baseline can identify that same row without demanding the old
// unit rectangle remain under the new one. Only geometry enters this test.
inline bool sameReflowedPrompt(const Geometry&old,const Geometry&now){
 double h=std::max(1,old.digit.height);
 if(now.digit.height<.65*h||now.digit.height>1.5*h||std::abs(now.digit.y-old.digit.y)>.5*h||std::abs(now.digit.br().y-old.digit.br().y)>.4*h||std::abs(now.digit.x-old.digit.x)>2.2*h||navlite::overlap(now.digit,old.digit)<.3)return false;
 if(std::abs((now.unit.x+now.unit.width*.5)-(old.unit.x+old.unit.width*.5))>1.25*h||std::abs(now.unit.br().y-old.unit.br().y)>.4*h)return false;
 for(auto a:old.arrows)for(auto b:now.arrows){if(navlite::overlap(a,b)<.7||double((a&b).area())/std::max(1,std::max(a.area(),b.area()))<.5)continue;
  auto before=navlite::relation(a,old.digit|old.unit),after=navlite::relation(b,now.digit|now.unit);for(auto side:before)if(std::find(after.begin(),after.end(),side)!=after.end())return true;
 }
 return false;
}
  struct Config {int minPoints=6,refreshJobs=30;double maxAge=1.5,historySeconds=2.,maxFrameGap=.35;bool contrast=true,lineUnits=false,jointRoles=false,sampledArrows=false,completeDigits=false,coherentRows=false,regionIdentity=false,rowScale=false,strictEvidence=false,refinedTurns=false,stableUnits=false,recoverIdentity=false,splitDigits=false,denseDigits=false,lazyRejectedUnits=false,contextConsistency=false,sourceTimeCadence=false,verifyWeakContent=false,publicationContext=false,retainNumericGeometry=false;bool retainOnReadFailure=false;int localMissLimit=2;double geometryGrace=1.5;std::string digitRejectModel;bool stopInvalidChains=false;double localMissInterval=0;bool reusePreprocessing=true,reuseUnitPreparation=false,verifyUnitPreparation=false;bool exactLegacyArrows=false,mergeArrowPasses=false,parallelFullSearch=false,shareContrastBlur=false,unitHeightGate=false,parallelArrowBuild=false,localUnitWindow=false;};
struct Frame {cv::Mat image,gray;int id=-1;double source=0;};
inline Frame frame(const cv::Mat&image,int id,double source){Frame f;f.image=image.clone();cv::cvtColor(f.image,f.gray,cv::COLOR_BGR2GRAY);f.id=id;f.source=source;return f;}
class Motion {
 Geometry anchor;cv::Mat affine=cv::Mat::eye(3,3,CV_64F),previous;std::vector<cv::Point2f>points;Config cfg;
 void features(const cv::Mat&gray){
  auto g=geometry();int h=std::max(1,g.digit.height);cv::Mat mask=cv::Mat::zeros(gray.size(),CV_8U);
  auto area=navtrack::expand(g.bounds(),navlite::rnd(.65*h),navlite::rnd(.65*h),gray.size());mask(area).setTo(255);
  mask(navtrack::expand(g.digit,3,3,gray.size())).setTo(0);
  // A changed turn symbol must not move the tracked card. Use its surrounding
  // stable features, rather than the symbol strokes, along with unit context.
  for(auto a:g.arrows)mask(navtrack::expand(a,2,2,gray.size())).setTo(0);
  cv::goodFeaturesToTrack(gray,points,100,.01,3,mask,3);
 }
public:
 bool active=false;int lastId=-1;double lastSource=0;int inliers=0;std::string why;
 explicit Motion(Config c={}):cfg(c){}
 Geometry geometry()const{return anchor.transformed(affine(cv::Rect(0,0,3,2)));}
 bool seed(const Frame&f,Geometry g){anchor=g;affine=cv::Mat::eye(3,3,CV_64F);previous=f.gray.clone();lastId=f.id;lastSource=f.source;active=true;features(f.gray);active=points.size()>=size_t(cfg.minPoints);why=active?"":"insufficient_stable_features";return active;}
 void clear(){active=false;points.clear();previous.release();}
 bool step(const Frame&f){
  if(!active)return false;if(f.id==lastId)return true;
  auto fail=[&](const char*s){why=s;clear();return false;};
  if(f.id<lastId||f.source-lastSource>cfg.maxFrameGap||f.gray.size()!=previous.size())return fail("motion_frame_gap");
  std::vector<cv::Point2f>next,back,a,b;std::vector<unsigned char>s1,s2;std::vector<float>e1,e2;
  cv::calcOpticalFlowPyrLK(previous,f.gray,points,next,s1,e1,{21,21},3);cv::calcOpticalFlowPyrLK(f.gray,previous,next,back,s2,e2,{21,21},3);
  for(size_t i=0;i<points.size();i++)if(s1[i]&&s2[i]&&cv::norm(points[i]-back[i])<=1.5&&next[i].x>=0&&next[i].y>=0&&next[i].x<f.gray.cols&&next[i].y<f.gray.rows){a.push_back(points[i]);b.push_back(next[i]);}
  if(a.size()<size_t(cfg.minPoints))return fail("motion_forward_backward");cv::Mat mask;auto m=cv::estimateAffinePartial2D(a,b,mask,cv::RANSAC,2.,1000,.99,10);if(m.empty())return fail("motion_affine");
  inliers=cv::countNonZero(mask);double scale=std::hypot(m.at<double>(0,0),m.at<double>(1,0));
  if(inliers<cfg.minPoints||double(inliers)/a.size()<.6||scale<.9||scale>1.1||std::abs(m.at<double>(0,2))>std::max(12.,f.gray.cols*.12)||std::abs(m.at<double>(1,2))>std::max(12.,f.gray.rows*.12))return fail("motion_geometry");
  cv::Mat h=cv::Mat::eye(3,3,CV_64F);m.copyTo(h(cv::Rect(0,0,3,2)));affine=h*affine;
  auto g=geometry();cv::Rect bounds(0,0,f.gray.cols,f.gray.rows);if((g.bounds()&bounds)!=g.bounds())return fail("motion_outside_nav");
  points.clear();for(size_t i=0;i<b.size();i++)if(mask.at<unsigned char>(int(i)))points.push_back(b[i]);
  previous=f.gray;lastId=f.id;lastSource=f.source;if(points.size()<20)features(f.gray);if(points.size()<size_t(cfg.minPoints))return fail("motion_too_few_points");why.clear();return true;
 }
};
struct Job {Frame source;unsigned long version=0;bool full=true;Geometry predicted;int mode=-1;bool trusted=false;};
struct Outcome {Job job;bool valid=false,contentConflict=false,numericGeometry=false;navlite::Row row;int mode=-1;std::string why;double computeMs=0,startedTick=0,finishedTick=0;size_t matches=0;};
inline bool alignedNumericGeometry(const navlite::Row&r,const Geometry&g,cv::Point offset={}){
 if(!r.unit.found||r.unit.partial||r.unit.conflict||r.arrows.empty())return false;
 auto b=r.box+offset,u=r.unit.box+offset;double h=std::max(1,g.digit.height);
 if(std::abs(b.x-g.digit.x)>.75*h||std::abs(b.y-g.digit.y)>.5*h||b.height<h*.65||b.height>h*1.5||navlite::overlap(b,g.digit)<.6||navlite::overlap(u,g.unit)<.7)return false;
 for(auto a:r.arrows)for(auto old:g.arrows)if(navlite::overlap(a.box+offset,old)>.7&&double(((a.box+offset)&old).area())/std::max(1,std::max(a.box.area(),old.area()))>.5)return true;
 return false;
}
class Recognizer {
  navlite::Reader reader;Config cfg;std::shared_ptr<navlite::Reader>rejector;
  std::unique_ptr<navlite::Reader> fullPeer;std::string modelPath;
  std::array<double,3> modeMs{};
  std::array<std::vector<navlite::Row>,3> lastModeRows;
  cv::Mat input(const cv::Mat&im,int m){return m==0?im:navgate::normalize(im,m==2);}
  bool supportedSmallRow(const cv::Mat&original,const cv::Mat&processed,const navlite::Row&r,int mode){
   if(!cfg.stableUnits||r.glyphs.size()!=1)return true;
   cv::Mat raw,gray;cv::cvtColor(original,raw,cv::COLOR_BGR2GRAY);cv::cvtColor(processed,gray,cv::COLOR_BGR2GRAY);return navgate::verify(raw,gray,r,mode==2?-1:1).accepted();
  }
  bool rejectedAsNoise(const cv::Mat&processed,const navlite::Row&r){
   if(!rejector)return false;cv::Mat gray;cv::cvtColor(processed,gray,cv::COLOR_BGR2GRAY);
   // Closed-set digit confidence cannot establish that a lone stroke is a
   // digit. Multi-glyph rows retain the tighter weak-class AND weak-shape
   // requirement; the auxiliary never supplies a replacement numeric class.
   bool single=r.glyphs.size()==1;
   for(auto g:r.glyphs)if(single||(g.p<.8&&g.shape<.55)){auto box=cv::Rect(g.box.x-2,g.box.y-2,g.box.width+4,g.box.height+4)&cv::Rect(0,0,gray.cols,gray.rows);auto vote=rejector->predict(gray(box));if(vote.text=='?'&&vote.p>=(single?.9:.99)&&vote.margin>=(single?.5:.9))return true;}
   return false;
  }
  bool publicationConflict(const cv::Mat&processed,const navlite::Row&r){if(!cfg.publicationContext)return false;cv::Mat gray;cv::cvtColor(processed,gray,cv::COLOR_BGR2GRAY);for(auto g:r.glyphs)if(reader.publicationConflict(gray,g,r.threshold))return true;return false;}
 public:
  void parallelFullSearch(bool enabled){cfg.parallelFullSearch=enabled;if(!enabled||!cfg.contrast){fullPeer.reset();return;}if(!fullPeer)fullPeer.reset(new navlite::Reader(modelPath));}
  std::array<double,3> fullModeTimes()const{return modeMs;}
  const std::array<std::vector<navlite::Row>,3>& fullModeRows()const{return lastModeRows;}
  void reuseUnitPlans(bool enabled){reader.reuseUnitPlans=enabled;}
  void reuseUnitWindows(bool enabled){reader.reuseUnitWindows(enabled);}
  void reuseThresholdComponents(bool enabled,bool verify=false){reader.reuseThresholdComponents=enabled;reader.verifyThresholdComponents=verify;}
  std::array<size_t,3> componentLayerCounts()const{return {reader.componentLayerBuilds,reader.componentLayerHits,reader.componentLayerPixelsSaved};}
  void binaryUnitRoots(bool enabled){reader.binaryUnitRoots(enabled);}
  std::array<size_t,5> binaryUnitRootCounts()const{return reader.binaryUnitRootCounts();}
  std::array<size_t,7> unitWindowCounts()const{return reader.unitWindowCounts();}
  void batchUnitSearch(bool enabled,bool verify=false){reader.batchUnitSearch=enabled;reader.verifyUnitBatch=verify;}
  std::array<size_t,8> unitBatchCounts()const{return reader.unitBatchCounts();}
  double unitBatchPeakError()const{return reader.unitBatchPeakError();}
  void arrowAlgorithms(bool exact,bool merged,bool verify=false){reader.exactLegacyArrows=exact;reader.mergeArrowPasses=merged;reader.verifyArrowAlgorithms=verify;}
  std::array<size_t,6> arrowAlgorithmCounts()const{return reader.arrowAlgorithmCounts();}
  void boundUnitNcc(bool enabled,bool verify=false){reader.boundUnitNcc=enabled;reader.verifyUnitBound=verify;}
  void earlyUnitBlocks(bool enabled){reader.earlyUnitBlocks(enabled);}
  std::array<size_t,2> unitBlockCounts()const{return reader.unitBlockCounts();}
  std::array<size_t,3> unitBoundCounts()const{return reader.unitBoundCounts();}
  void reuseArrowPreparation(bool enabled,bool verify=false){reader.reuseArrowPreparation(enabled,verify);}
  std::array<size_t,4> arrowPreparationCounts()const{return reader.arrowPreparationCounts();}
  void reuseArrowScores(bool enabled,bool verify=false){reader.reuseArrowScores(enabled,verify);}
  std::array<size_t,3> arrowScoreCounts()const{return reader.arrowScoreCounts();}
  // 主Reader与全区peer累计的箭头参考库生成次数（缓存未命中），用于判断离线/共享参考库是否值得做
  void verifyUnitGate(bool enabled){reader.verifyUnitGate=enabled;}
  void unitWindowFallback(bool enabled){reader.unitWindowFallback=enabled;}
  std::array<size_t,4> localUnitWindowCounts()const{return {reader.unitWindowHits,reader.unitWindowMisses,reader.unitWindowFallbacks,reader.unitWindowFallbackFound};}
  void unitGateTolerance(double t){reader.unitGateTolerance=t;}
  const std::vector<navlite::Reader::UnitGateMiss>& unitGateMisses()const{return reader.unitGateMisses;}
  std::array<size_t,3> unitGateCounts()const{return {reader.unitGateSkips+(fullPeer?fullPeer->unitGateSkips:0),reader.unitGateScalesKept+(fullPeer?fullPeer->unitGateScalesKept:0),reader.unitGateScalesTotal+(fullPeer?fullPeer->unitGateScalesTotal:0)};}
  size_t arrowReferenceBuilds()const{return reader.arrowReferenceBuilds()+(fullPeer?fullPeer->arrowReferenceBuilds():0);}
  std::array<size_t,3> unitPlanCounts()const{return reader.unitPlanCounts();}
   Recognizer(const std::string&model,Config c={}):reader(model),cfg(c),modelPath(model){reader.exactLegacyArrows=cfg.exactLegacyArrows;reader.mergeArrowPasses=cfg.mergeArrowPasses;reader.segmentSmallUnits=cfg.lineUnits;reader.jointRoles=cfg.jointRoles;reader.sampledArrows=cfg.sampledArrows;reader.completeDigits=cfg.completeDigits;reader.coherentRows=cfg.coherentRows;reader.regionCandidates=cfg.regionIdentity;reader.rowScaleOnly=cfg.rowScale;reader.strictEvidenceOnly=cfg.strictEvidence;reader.refinedTurnsOnly=cfg.refinedTurns;reader.stableUnits=cfg.stableUnits;reader.splitDigits=cfg.splitDigits;reader.denseDigitThresholds=cfg.denseDigits;reader.lazyRejectedUnits=cfg.lazyRejectedUnits;reader.stopInvalidChains=cfg.stopInvalidChains;reader.contextConsistency=cfg.contextConsistency;reader.unitHeightGate=cfg.unitHeightGate;reader.localUnitWindow=cfg.localUnitWindow;reader.parallelArrowBuild(cfg.parallelArrowBuild);if(!cfg.digitRejectModel.empty())rejector=std::make_shared<navlite::Reader>(cfg.digitRejectModel);parallelFullSearch(cfg.parallelFullSearch);}
  Outcome run(const Job&job){
   reader.reuseUnitPreparation=cfg.reuseUnitPreparation;reader.verifyUnitPreparation=cfg.verifyUnitPreparation;
    Outcome o;o.job=job;double start=navtrack::now();reader.templateCalls=0;modeMs={};for(auto&r:lastModeRows)r.clear();size_t peerMatches=0;
   // These inputs belong only to this job. No pixels or readings survive to
   // another source frame; original-pixel gates see the same normalized image.
   std::array<cv::Mat,3> inputs;
   // 全区搜索的亮/暗字共用一份三档模糊（逐位等价）。并行时在分叉前异步启动，
   // 两条识别路径各自持有shared_future副本再get，不并发写同一对象。
   std::shared_future<navgate::ContrastBackground> background;
   const bool shareBlur=job.full&&cfg.contrast&&cfg.reusePreprocessing&&cfg.shareContrastBlur;
   auto frameInput=[&](int mode){if(!cfg.reusePreprocessing)return input(job.source.image,mode);CV_Assert(mode>=0&&mode<3);if(inputs[mode].empty()){
     if(mode&&shareBlur){if(!background.valid())background=std::async(std::launch::deferred,[&](){return navgate::contrastBackground(job.source.image,false);}).share();auto shared=background;inputs[mode]=navgate::normalize(shared.get(),mode==2);}
     else inputs[mode]=input(job.source.image,mode);}
    return inputs[mode];};
   o.startedTick=start;auto finish=[&](){o.finishedTick=navtrack::now();o.computeMs=o.finishedTick-start;o.matches=reader.templateCalls+peerMatches;return o;};
  if(job.full){
     struct Found {navlite::Row r;int mode;};std::vector<Found>found,incomplete;auto&modeRows=lastModeRows;
     auto analyzeMode=[&](navlite::Reader&r,int m){double tick=navtrack::now();modeRows[m]=r.analyze(frameInput(m));modeMs[m]=navtrack::now()-tick;};
     if(cfg.parallelFullSearch&&cfg.contrast){
      // A freshly constructed peer owns its own MLP, templates and mutable
      // caches. Only options are copied; no cv::Mat workspaces cross lanes.
      reader.copyConfigurationTo(*fullPeer);fullPeer->templateCalls=0;
      // 模糊与peer的原图模式0同时开始；sigma15和sigma3/7再各占一条线程
      if(shareBlur)background=std::async(std::launch::async,[&](){return navgate::contrastBackground(job.source.image,true);}).share();
      auto work=std::async(std::launch::async,[&](){analyzeMode(*fullPeer,0);analyzeMode(*fullPeer,1);});
      analyzeMode(reader,2);work.get();peerMatches=fullPeer->templateCalls;
     }else for(int m=0;m<(cfg.contrast?3:1);m++)analyzeMode(reader,m);
      // Completion order must never choose the winning mode or suppress a
      // conflicting candidate. Merge exactly in the original 0,1,2 order.
      for(int m=0;m<(cfg.contrast?3:1);m++){for(auto r:modeRows[m]){if(r.accepted)found.push_back({r,m});
     if(cfg.regionIdentity&&cfg.stableUnits&&r.glyphs.size()>=2&&!r.arrows.empty()&&(r.reasons==std::set<std::string>{"missing_unit"}||r.reasons==std::set<std::string>{"partial_unit_shape"})){
      bool reliable=true;for(auto g:r.glyphs)if(!g.good||g.p<.8||g.shape<.55)reliable=false;if(reliable)incomplete.push_back({r,m});
     }
    }}
   if(found.empty()){o.why="no_complete_reading";return finish();}
    if(cfg.regionIdentity){
     // Cluster distinct prompt rows before resolving identity. Contradictory
     // values at the same position remain a conflict; unrelated map text no
     // longer vetoes every prompt in the manual search rectangle.
     std::vector<Found>groups;for(auto f:found){int match=-1;for(int i=0;i<int(groups.size());i++)if(navlite::overlap(f.r.box,groups[i].r.box)>.7){match=i;break;}
      if(match<0)groups.push_back(f);else if(std::abs(f.r.meters-groups[match].r.meters)>1e-6){o.why="acquisition_conflict";return finish();}
     }
     if(groups.size()>1){int chosen=-1;
      if(job.trusted)for(int i=0;i<int(groups.size());i++){auto b=groups[i].r.box,p=job.predicted.digit;double h=std::max(1,p.height);if(std::abs(b.x-p.x)<=.75*h&&std::abs(b.y-p.y)<=.5*h&&navlite::overlap(groups[i].r.unit.box,job.predicted.unit)>.5){if(chosen>=0){o.why="acquisition_conflict";return finish();}chosen=i;}}
      if(chosen<0){
       // UI emphasis is geometry, never numeric magnitude. Require a clearly
       // larger numeric font AND a side arrow on the same baseline. If that
       // hierarchy is absent, keep the ambiguity and reject.
       for(int i=0;i<int(groups.size());i++){const auto&r=groups[i].r;bool side=false,dominates=true;for(auto a:r.arrows)for(auto rel:a.relations)if(rel=="left"||rel=="right")side=true;
        for(int j=0;j<int(groups.size());j++)if(j!=i&&r.box.height<1.35*groups[j].r.box.height)dominates=false;
        if(side&&dominates){if(chosen>=0){o.why="acquisition_conflict";return finish();}chosen=i;}
       }
      }
      if(chosen<0){o.why="acquisition_conflict";return finish();}found={groups[chosen]};
     }else found=groups;
    }
    for(size_t i=0;i<found.size();i++)for(size_t k=0;k<i;k++)if(std::abs(found[i].r.meters-found[k].r.meters)>1e-6||navlite::overlap(found[i].r.box,found[k].r.box)<.7){o.why="acquisition_conflict";return finish();}
      if(cfg.stableUnits&&found[0].r.glyphs.size()==1&&!supportedSmallRow(job.source.image,frameInput(found[0].mode),found[0].r,found[0].mode)){o.why="unsupported_small_prompt";return finish();}
    if(cfg.regionIdentity&&cfg.stableUnits)for(auto other:incomplete)if(other.r.box.height>=1.35*found[0].r.box.height&&navlite::overlap(other.r.box,found[0].r.box)<.1){o.why="incomplete_primary_prompt";return finish();}
      if(rejector&&rejectedAsNoise(frameInput(found[0].mode),found[0].r)){o.why="digit_reject_class_evidence";return finish();}
      o.row=found[0].r;o.mode=found[0].mode;o.valid=true;if(cfg.publicationContext)o.contentConflict=publicationConflict(frameInput(o.mode),o.row);
  }else{
   auto g=job.predicted;int h=std::max(1,g.digit.height);auto tile=navtrack::expand(g.bounds(),navlite::rnd(.8*h),navlite::rnd(.55*h),job.source.image.size());
   navlite::SearchHint hint;int x=std::max(0,g.digit.x-navlite::rnd(.4*h)),right=std::min(job.source.image.cols,std::max(g.digit.br().x,g.unit.br().x)+navlite::rnd(1.5*h));
    hint.digitBand=(cv::Rect(x,g.digit.y-navlite::rnd(.3*h),right-x,navlite::rnd(1.6*h))&tile)-tile.tl();hint.digitHeight=h;hint.unitHeight=g.unit.height;hint.trusted=job.trusted;if(!g.unit.empty())hint.unitBox=g.unit-tile.tl();
   // Preserve the full Gaussian support around the tile, including the
   // original image boundary. A tight crop would change weak unit evidence.
   cv::Mat normalizedTile=cfg.reusePreprocessing?(job.mode==0?job.source.image(tile):navperf::normalizeWindow(job.source.image,job.mode==2,tile)):input(job.source.image,job.mode)(tile);
      std::vector<navlite::Row>found;bool rejectedConflict=false,numericEvidence=false,unsafeNumeric=false;for(auto r:reader.analyze(normalizedTile,&hint)){
       if(r.accepted&&supportedSmallRow(job.source.image(tile),normalizedTile,r,job.mode))found.push_back(r);
       if(cfg.retainOnReadFailure&&r.unit.found)for(const char*reason:{"multiple_distance_conflict","threshold_number_conflict","joint_number_conflict","digit_arrow_role_conflict","unit_conflict","numeric_evidence_conflict"})if(r.reasons.count(reason))rejectedConflict=true;
       if(cfg.retainNumericGeometry){static const std::set<std::string>numericReasons={"threshold_number_conflict","joint_number_conflict","numeric_evidence_conflict","digit_template_contradiction","threshold_stroke_loss_conflict"};bool numeric=false,onlyNumeric=!r.reasons.empty();for(auto reason:r.reasons){if(numericReasons.count(reason))numeric=true;else onlyNumeric=false;}
        if(numeric){rejectedConflict=true;if(onlyNumeric&&alignedNumericGeometry(r,g,tile.tl()))numericEvidence=true;else unsafeNumeric=true;}
        if((r.unit.partial||r.unit.conflict)&&navlite::overlap(r.box+tile.tl(),g.digit)>.6)unsafeNumeric=true;
       }
    }
     if(found.size()!=1){o.why=found.empty()&&!rejectedConflict?"local_read_failed":"local_read_conflict";o.numericGeometry=cfg.retainNumericGeometry&&job.trusted&&found.empty()&&numericEvidence&&!unsafeNumeric;return finish();}
     if(rejectedAsNoise(normalizedTile,found[0])){o.why="digit_reject_class_evidence";return finish();}
     o.contentConflict=publicationConflict(normalizedTile,found[0]);o.row=found[0];navtrack::offset(o.row,tile.tl());o.mode=job.mode;
    bool reflow=cfg.regionIdentity&&sameReflowedPrompt(g,Geometry::from(o.row));
    if(!reflow&&(std::abs(o.row.box.x-g.digit.x)>.75*h||std::abs(o.row.box.y-g.digit.y)>.5*h||o.row.box.height<h*.55||o.row.box.height>h*1.6)){o.why="local_layout_changed";return finish();}o.valid=true;
  }
  return finish();
 }
};
struct Event {Outcome outcome;std::string status,readout,why;bool published=false;double age=0;};
// Separate from positional state. Stores only a short-lived confirmation
// hypothesis, never a numeric value to display or to fill a failed frame.
class ContentVerifier {
 bool enabled;std::string previous;unsigned long epoch=0;int frame=-1;double source=-1;
 void clear(){previous.clear();frame=-1;source=-1;}
public:
 explicit ContentVerifier(Config c={}):enabled(c.verifyWeakContent){}
 void apply(Event&e,unsigned long currentEpoch,bool trustedPosition=false){
  if(!enabled)return;
  if(e.status=="DISCARDED"||(e.status=="REJECT"&&e.why!="geometry_only_local_read_failed")){clear();return;}
  if(!e.outcome.valid)return;
  if(e.outcome.contentConflict){clear();if(e.published||e.status=="PROVISIONAL"){e.published=false;e.readout.clear();e.status="PROVISIONAL";e.why="current_digit_context_conflict";}return;}
  const auto&row=e.outcome.row;const auto&now=e.outcome.job.source;
  bool consistent=frame>=0&&epoch==currentEpoch&&now.id!=frame&&now.source>source&&now.source-source<=.5&&previous==row.raw();
  bool weak=false;for(auto g:row.glyphs)if(g.p<.95||g.shape<.55)weak=true;
  previous=row.raw();epoch=currentEpoch;frame=now.id;source=now.source;
  // The geometry may remain established through an empty recognition event,
  // even though State's consecutive content counter reset. Two fresh matching
  // numeric observations provide the missing CONTENT confirmation here; a new
  // positional identity never receives this promotion.
  if(!e.published&&e.status=="PROVISIONAL"&&trustedPosition&&consistent){e.published=true;e.readout=row.raw();e.status="VERIFIED";e.why="fresh_content_in_confirmed_geometry";}
  if(e.published&&weak&&!consistent){e.published=false;e.readout.clear();e.status="PROVISIONAL";e.why="await_current_numeric_confirmation";}
 }
};
class State {
   Config cfg;std::deque<Frame>history;Frame current;Motion motion;unsigned long version=0;int mode=-1,confirmed=0,sinceRefresh=0,localMisses=0;double lastEvidenceSource=-1,lastStrongGeometry=-1,lastFullSource=-1,lastCountedMiss=-1;bool identityConfirmed=false;
   bool refreshDue()const{return cfg.sourceTimeCadence?lastFullSource>=0&&current.source-lastFullSource>=cfg.refreshJobs*.1-1e-6:sinceRefresh>=cfg.refreshJobs;}
   void lose(const std::string&why){motion.clear();confirmed=0;identityConfirmed=false;lastStrongGeometry=-1;lastFullSource=-1;lastCountedMiss=-1;mode=-1;sinceRefresh=0;localMisses=0;lastEvidenceSource=-1;++version;lastWhy=why;}
public:
  size_t flowSteps=0,losses=0;double flowMs=0;std::string lastWhy;
  size_t retainedMisses=0,graceExpirations=0,retrySearches=0;
 explicit State(Config c={}):cfg(c),motion(c){}
  bool locked()const{return motion.active&&confirmed>=2;}
  bool trustedPosition()const{return motion.active&&identityConfirmed;}
  bool localReadEligible()const{return trustedPosition()&&!refreshDue()&&!(cfg.retainOnReadFailure&&localMisses>=cfg.localMissLimit);}
  bool provisional()const{return motion.active&&!locked();}
  bool geometryOnly()const{return motion.active&&localMisses>0;}
 unsigned long epoch()const{return version;}
 Geometry geometry()const{return motion.geometry();}
 void reset(){lose("explicit_reset");history.clear();}
 void advance(Frame f){
  if(current.id>=0&&f.id<=current.id)throw std::runtime_error("frames must increase");
  double t=navtrack::now();if(motion.active){flowSteps++;if(!motion.step(f)){losses++;lose(motion.why);}}
   if(cfg.retainOnReadFailure&&motion.active&&lastEvidenceSource>=0&&f.source-lastEvidenceSource>cfg.geometryGrace){graceExpirations++;lose("geometry_evidence_expired");}
   flowMs+=navtrack::now()-t;current=f;history.push_back(f);while(history.size()>1&&f.source-history.front().source>cfg.historySeconds)history.pop_front();
 }
   Job job(){if(current.id<0)throw std::runtime_error("no input frame");Job j;j.source=current;j.version=version;bool retry=cfg.retainOnReadFailure&&motion.active&&localMisses>=cfg.localMissLimit;j.full=!motion.active||refreshDue()||retry;j.mode=mode;j.trusted=cfg.regionIdentity?identityConfirmed:locked();if(motion.active)j.predicted=motion.geometry();if(j.full){sinceRefresh=0;lastFullSource=current.source;if(retry)retrySearches++;}return j;}
 Event complete(Outcome o){
  Event e;e.outcome=o;e.age=std::max(current.source-o.job.source.source,o.computeMs/1000);
  if(o.job.version!=version){e.status="DISCARDED";e.why="obsolete_position_version";return e;}
  if(e.age<0||e.age>cfg.maxAge){e.status="DISCARDED";e.why="expired_source_frame";return e;}
   if(!o.valid){e.status="REJECT";e.why=o.why;
    // Only an ordinary LOCAL no-reading can retain geometry. Conflicts,
    // layout changes, failed global refreshes and invalid motion clear it.
    // No Row/text is reused; the event remains empty and unpublished.
     bool numericOnly=cfg.retainNumericGeometry&&o.numericGeometry&&o.job.trusted&&o.why=="local_read_conflict";
     if(cfg.retainOnReadFailure&&motion.active&&!o.job.full&&(o.why=="local_read_failed"||numericOnly)&&lastEvidenceSource>=0&&current.source-lastEvidenceSource<=cfg.geometryGrace){
     double missInterval=cfg.sourceTimeCadence?std::max(.1,cfg.localMissInterval):cfg.localMissInterval;
     confirmed=0;if(missInterval<=0||localMisses==0||o.job.source.source-lastCountedMiss>=missInterval-1e-6){localMisses++;lastCountedMiss=o.job.source.source;}sinceRefresh++;retainedMisses++;lastWhy=numericOnly?"geometry_only_numeric_conflict":"geometry_only_local_read_failed";e.why=lastWhy;return e;
    }
    if(motion.active)lose(e.why);return e;
   }
  Motion replay(cfg);if(!replay.seed(o.job.source,Geometry::from(o.row))){e.status="REJECT";e.why="candidate_has_no_stable_context";if(motion.active)lose(e.why);return e;}
  for(auto f:history)if(f.id>o.job.source.id&&!replay.step(f)){e.status="DISCARDED";e.why="cannot_reconcile_result_motion";if(motion.active)lose(e.why);return e;}
  if(replay.lastId!=current.id){e.status="DISCARDED";e.why="missing_frame_history";return e;}
  auto g=replay.geometry();bool same=false;
   if(motion.active){auto old=motion.geometry();double h=std::max(1,old.digit.height);same=(std::abs(g.digit.x-old.digit.x)<=.75*h&&std::abs(g.digit.y-old.digit.y)<=.5*h&&navlite::overlap(g.unit,old.unit)>=.5)||(cfg.regionIdentity&&sameReflowedPrompt(old,g));}
   if(motion.active&&!same){
    bool replace=cfg.regionIdentity&&o.job.full&&!o.job.trusted&&!identityConfirmed;lose("candidate_position_changed");
    if(!replace){e.status="DISCARDED";e.why=lastWhy;return e;}
    // An unconfirmed identity has no veto over a new complete full-search
    // candidate. It may start fresh confirmation, never publish immediately.
   }
    bool strongCurrent=o.row.reasons.empty()&&o.row.unit.found&&!o.row.unit.partial&&!o.row.unit.conflict&&!o.row.arrows.empty();for(auto g:o.row.glyphs)if(!g.good||g.p<.9||g.shape<.55)strongCurrent=false;
    bool freshPair=cfg.recoverIdentity&&same&&!identityConfirmed&&strongCurrent&&lastStrongGeometry>=0&&current.source-lastStrongGeometry<=.6;
    bool recover=cfg.recoverIdentity&&same&&identityConfirmed&&strongCurrent;
    motion=replay;mode=o.mode;confirmed=recover||freshPair?std::max(2,confirmed+1):(same?confirmed+1:1);sinceRefresh++;localMisses=0;lastCountedMiss=-1;if(o.job.full)lastFullSource=o.job.source.source;
    // Successful replay verifies GEOMETRY on the current frame. The numeric
    // event still keeps its original source/age, checked above. Starting the
    // geometry deadline at a slow job's old source immediately expires a new
    // identity before its local confirmation can finish.
    lastEvidenceSource=cfg.recoverIdentity?current.source:o.job.source.source;lastStrongGeometry=strongCurrent?current.source:-1;lastWhy.clear();if(confirmed>=2)identityConfirmed=true;
  e.status=locked()?"VERIFIED":"PROVISIONAL";e.why=locked()?"fresh_read_in_tracked_region":"await_second_layout_confirmation";
  // This result still belongs to its logged source frame. Publication never
  // implies that its numeric content is valid for the current live frame.
  if(locked()){e.published=true;e.readout=o.row.raw();}return e;
 }
};
class Pipeline {
  Recognizer reader;State state;ContentVerifier content;std::mutex mutex;std::condition_variable ready;std::thread worker;bool closing=false,hasJob=false,hasResult=false,outstanding=false;Job work;Outcome result;std::string error;
 void loop(){try{while(true){Job j;{std::unique_lock<std::mutex>lock(mutex);ready.wait(lock,[&]{return closing||hasJob;});if(closing&&!hasJob)return;j=work;hasJob=false;}
   auto r=reader.run(j);{std::lock_guard<std::mutex>lock(mutex);result=std::move(r);hasResult=true;}
  }}catch(const std::exception&e){std::lock_guard<std::mutex>lock(mutex);error=e.what();}}
public:
  Pipeline(const std::string&model,Config c={}):reader(model,c),state(c),content(c){worker=std::thread([this]{loop();});}
 ~Pipeline(){close();}
 void close(){if(worker.joinable()){{std::lock_guard<std::mutex>lock(mutex);closing=true;}ready.notify_one();worker.join();}}
 bool busy()const{return outstanding;}
 State&positions(){return state;}
  bool receive(Event&event){Outcome r;{std::lock_guard<std::mutex>lock(mutex);if(!error.empty())throw std::runtime_error(error);if(!hasResult)return false;r=std::move(result);hasResult=false;}outstanding=false;event=state.complete(std::move(r));content.apply(event,state.epoch(),state.trustedPosition());return true;}
   bool update(const cv::Mat&im,int id,double source,Event&event,bool submit=true,bool submitTrustedLocal=false){
  state.advance(frame(im,id,source));bool completed=receive(event);
   if((submit||(submitTrustedLocal&&state.localReadEligible()))&&!outstanding){auto j=state.job();{std::lock_guard<std::mutex>lock(mutex);work=std::move(j);hasJob=true;}outstanding=true;ready.notify_one();}
  return completed;
 }
};
} // namespace navasync
