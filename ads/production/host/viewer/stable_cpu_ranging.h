#pragma once
#include "third_party/ranging_cpu/ranging.hpp"
#include <deque>
#include "cpu_lateral_evidence.h"
#include "cpu_distance_quality.h"

namespace stable_cpu_ranging {
struct Widths {double lane=3.5,paint=.15;};
// Fixed-mount parameter lifecycle; target boxes are never retained here.
class Engine {
    struct Sample {double y,A;long long at;bool paired;double lateralHeight=0;double weight=1;};
    ranging::Config config_;
    Widths widths_;
    std::deque<Sample> samples_;
    online_calib::State locked_;
    online_calib::State provisional_;
    long long provisionalAt_=-1,confirmationLast_=-1;
    int confirmations_=0,confirmationCorroborated_=0,provisionalConflicts_=0;
    double candidateYError_=2,candidateAError_=.05;
    long long lastTime_=-1,lastVerified_=-1;
    int lastFrame_=-1,recovery_=0;
    unsigned recoveryNeeds_=0,recoverySeen_=0; // horizon=1, scale=2, height=4
    cv::Size size_;
    bool suspended_=false;
    static double median(std::vector<double> v) {std::sort(v.begin(),v.end());return v[v.size()/2];}
    bool acquire(online_calib::State& state) {
        if(samples_.size()<12)return false;
        // Sparse usable frames need not be consecutive. Find a joint y/A
        // consensus, requiring dominant support rather than averaging incompatible
        // planes or letting sample count alone hide outlier spread.
        std::vector<Sample> consensus;
        double bestWeight=0;
        for(auto center:samples_) {
            std::vector<Sample> group;double weight=0;
            for(auto s:samples_)if(std::abs(s.y-center.y)<=4.*size_.height/480.&&std::abs(s.A-center.A)<=.15*center.A){group.push_back(s);weight+=s.weight;}
            if(group.size()>=12&&weight>bestWeight){bestWeight=weight;consensus=std::move(group);}
        }
        double allWeight=0,groupWeight=0;
        for(auto s:samples_)allWeight+=s.weight;for(auto s:consensus)groupWeight+=s.weight;
        if(consensus.size()<12||groupWeight<.4*allWeight||consensus.back().at-consensus.front().at<500)return false;
        std::vector<double> centerY,centerA;for(auto s:consensus){centerY.push_back(s.y);centerA.push_back(s.A);}
        const double cy=median(centerY),ca=median(centerA);
        size_t rival=0;
        for(auto center:samples_) {
            if(std::abs(center.y-cy)<=8.*size_.height/480.&&std::abs(center.A-ca)<=.30*ca)continue;
            size_t n=0;for(auto s:samples_)if(std::abs(s.y-center.y)<=4.*size_.height/480.&&std::abs(s.A-center.A)<=.15*center.A)++n;
            rival=std::max(rival,n);
        }
        if(rival*5>=consensus.size()*4)return false;
        std::vector<double> ys,as,heights,focals;int corroborated=0;
        for(auto s:consensus){ys.push_back(s.y);as.push_back(s.A);corroborated+=s.paired||s.lateralHeight>0;
            if(s.lateralHeight>0){heights.push_back(s.lateralHeight);focals.push_back(s.A/s.lateralHeight);}}
        if(corroborated<3)return false;
        const double y=median(ys),A=median(as);
        std::sort(ys.begin(),ys.end());std::sort(as.begin(),as.end());
        // Check actual sample spread, not just standard error shrinking with N.
        const size_t lo=ys.size()/10,hi=ys.size()-1-lo;
        if(ys[hi]-ys[lo]>8.*size_.height/480. || as[hi]-as[lo]>.25*A)return false;
        candidateYError_=std::max(2.*size_.height/480.,std::max(y-ys[lo],ys[hi]-y));
        candidateAError_=std::max(.05,std::max(A-as[lo],as[hi]-A)/A);
        state={};state.ok=state.frame_ok=true;state.y_h=y;state.A=A;
        if(heights.size()>=3) {
            const double hc=median(heights),f=median(focals);
            std::sort(heights.begin(),heights.end());std::sort(focals.begin(),focals.end());
            const size_t l=heights.size()/10,u=heights.size()-1-l;
            if(heights[u]-heights[l]<=.25*hc&&focals[u]-focals[l]<=.25*f) {
                state.h_c=hc;state.f_px=f;state.hfov_deg=2*std::atan(size_.width/(2*f))*180/CV_PI;
                state.n_hc_lane=state.n_hc_paint=int(heights.size());
                // Ground projection remains unchanged; do not enable an
                // unvalidated box-height distance fallback.
            }
        }
        state.n_yh=state.n_A=int(consensus.size());return true;
    }
public:
    bool held=false,suspended=false;
    std::string phase="acquiring";
    cpu_lateral::Evidence lateral;
    cpu_distance_quality::Bounds distanceBounds;
    explicit Engine(ranging::Config config,Widths widths={}):config_(std::move(config)),widths_(widths) {
        if(!std::isfinite(widths.lane)||!std::isfinite(widths.paint)||widths.lane<2||widths.lane>5.5||
           widths.paint<.05||widths.paint>.5)throw std::invalid_argument("invalid lane/paint width assumptions");
        // Reuse the original constructor's configuration validation.
        ranging::Engine validate(config_);
    }
    void reset(){samples_.clear();locked_={};provisional_={};provisionalAt_=confirmationLast_=-1;
        confirmations_=confirmationCorroborated_=provisionalConflicts_=0;candidateYError_=2;candidateAError_=.05;
        distanceBounds={};lateral={};lastTime_=lastVerified_=-1;lastFrame_=-1;recovery_=0;recoveryNeeds_=recoverySeen_=0;suspended_=false;held=suspended=false;phase="acquiring";size_={};}
    // Same source/configuration/geometry only. Keep the confirmed plane and
    // any unresolved conflict, never samples or target results across a gap.
    void interrupt() {
        samples_.clear();provisional_={};provisionalAt_=confirmationLast_=-1;
        confirmations_=confirmationCorroborated_=provisionalConflicts_=0;
        lastTime_=-1;lastFrame_=-1;recovery_=0;recoverySeen_=0;lateral={};
        held=locked_.ok&&!suspended_;suspended=suspended_;
        phase=!locked_.ok?"acquiring":suspended_?"conflict_reconfirm":"locked_unobserved";
    }
    ranging::Result process(const cv::Mat& image,int frame,const std::vector<ranging::Box>& boxes,long long at) {
        if(image.empty()||image.type()!=CV_8UC3||frame<0||frame<=lastFrame_||at<0||
           (lastTime_>=0&&at<lastTime_)||(lastFrame_>=0&&image.size()!=size_))throw std::invalid_argument("new monotone frame/time and unchanged image size required");
        const cv::Rect bounds(0,0,image.cols,image.rows);
        if((config_.mark&bounds)!=config_.mark||(config_.road&bounds)!=config_.road)throw std::invalid_argument("ROI outside frame");
        size_=image.size();lastFrame_=frame;lastTime_=at;
        const auto r=config_.mark;
        const auto measured=lane_calib::measure(image,{r.x,r.y,r.br().x,r.br().y},*lane_calib::find_standard(config_.standard),widths_.lane,widths_.paint);
        return finish(measured,frame,boxes,at);
    }
    // Observation seam exercises the same lifecycle with known geometry in tests.
    ranging::Result observeForTest(const lane_calib::FrameMeas& m,int frame,long long at,cv::Size size={640,480}) {
        size_=size;return finish(m,frame,{},at);
    }
private:
    ranging::Result finish(const lane_calib::FrameMeas&m,int frame,const std::vector<ranging::Box>& boxes,long long at) {
        held=false;
        lateral=cpu_lateral::assess(m,size_.width);
        const bool horizon=m.has_vp&&m.vp.n>=3&&std::isfinite(m.y_h)&&m.y_h>0&&m.y_h<size_.height&&
            std::isfinite(m.vp.rms)&&m.vp.rms<=1.5*size_.height/480.;
        bool scale=horizon&&m.A_dash.ok&&std::isfinite(m.A_dash.value)&&m.A_dash.value>0&&
            std::isfinite(m.A_dash.spread)&&m.A_dash.spread<=.15;
        bool paired=false,pairConflict=false;
        for(auto e:{m.A_gap,m.A_period})if(e.ok) {
            if(!std::isfinite(e.value)||e.value<=0||std::abs(e.value-m.A_dash.value)>.5*m.A_dash.value) {pairConflict=true;scale=false;}
            else paired=true;
        }
        // A narrow spread alone is insufficient: the paint-width and
        // lane-width heights must agree before replacing a missing gap check.
        if(lateral.conflict)scale=false;
        const bool lateralCorroborates=scale&&lateral.agreement&&lateral.focal>0;
        const bool observationConflict=pairConflict||lateral.conflict;
        const bool jointVerified=scale&&(paired||lateralCorroborates)&&!observationConflict;
        // Only joint scale verification renews this ten-minute lifetime.
        if(locked_.ok&&lastVerified_>=0&&at-lastVerified_>=600000) {
            locked_={};provisional_={};samples_.clear();suspended_=false;
            recovery_=0;recoveryNeeds_=recoverySeen_=0;lastVerified_=-1;
        }
        const bool horizonChanged=locked_.ok&&horizon&&std::abs(m.y_h-locked_.y_h)>8.*size_.height/480.;
        const bool scaleChanged=locked_.ok&&scale&&std::abs(m.A_dash.value-locked_.A)>.25*locked_.A;
        const bool heightChanged=locked_.ok&&horizon&&lateral.agreement&&locked_.h_c>0&&std::abs(lateral.height-locked_.h_c)>.25*locked_.h_c;
        const bool inconsistent=horizonChanged||scaleChanged||heightChanged;
        // Three mutually intersecting fragments caused the diagnosed false
        // horizons. Treat those as unverified, not authoritative contradictions.
        const bool conflict=inconsistent&&m.vp.n>=4&&
            ((scale&&(paired||lateralCorroborates))||
             (lateral.agreement&&locked_.h_c>0));
        if(conflict) {
            if(!suspended_){samples_.clear();provisional_={};}
            suspended_=true;recovery_=0;recoverySeen_=0;
            recoveryNeeds_|=(horizonChanged?1u:0u)|(scaleChanged?2u:0u)|(heightChanged?4u:0u);
        }
        if(locked_.ok&&horizon&&!inconsistent&&jointVerified) {
            lastVerified_=at;
        }
        if(suspended_&&horizon&&m.vp.n>=4&&!inconsistent&&!observationConflict) {
            ++recovery_;recoverySeen_|=1;
            if(jointVerified)recoverySeen_|=2;
            if(lateral.agreement&&locked_.h_c>0)recoverySeen_|=4;
            // Five fresh matching horizons plus a new reliable observation of
            // EVERY disputed parameter. Sparse scales are not five new votes,
            // and a missing scale can never clear a scale conflict.
            if(recovery_>=5&&(recoverySeen_&recoveryNeeds_)==recoveryNeeds_) {
                suspended_=false;samples_.clear();provisional_={};recovery_=0;recoveryNeeds_=recoverySeen_=0;
            }
        }
        if(observationConflict||inconsistent){recovery_=0;recoverySeen_=0;}
        if(provisional_.ok&&at-provisionalAt_>10000){provisional_={};confirmations_=0;}
        if(provisional_.ok&&horizon&&at>provisionalAt_) {
            const bool consistent=std::abs(m.y_h-provisional_.y_h)<=4.*size_.height/480.&&
                (!scale||std::abs(m.A_dash.value-provisional_.A)<=.15*provisional_.A)&&!observationConflict;
            if(!consistent&&scale&&(paired||lateralCorroborates)) {
                if(++provisionalConflicts_>=3){provisional_={};confirmations_=0;samples_.clear();}
            } else if(consistent&&(scale||m.vp.n>=4)&&
                      (confirmationLast_<0||at-confirmationLast_>=100)) {
                ++confirmations_;confirmationLast_=at;provisionalConflicts_=0;
                confirmationCorroborated_+=scale&&(paired||lateralCorroborates);
                // Fresh horizon support may be plentiful even when full paint
                // lengths are sparse; at least one NEW corroborated scale
                // measurement is still mandatory before releasing distances.
                if(confirmations_>=5&&confirmationCorroborated_>=1&&at-provisionalAt_>=500) {
                    locked_=provisional_;provisional_={};suspended_=false;lastVerified_=at;recovery_=0;recoveryNeeds_=recoverySeen_=0;samples_.clear();
                    distanceBounds={candidateYError_,candidateAError_,2.*size_.height/480.};
                }
            }
        }
        if((!locked_.ok||suspended_)&&scale) {
            if(!samples_.empty()&&at-samples_.back().at>10000)samples_.clear();
            const double weight=1./(1.+m.vp.rms/(size_.height/480.)+m.A_dash.spread*5);
            samples_.push_back({m.y_h,m.A_dash.value,at,paired,lateralCorroborates?lateral.height:0,weight});
            while(samples_.size()>120||at-samples_.front().at>30000)samples_.pop_front();
            if(!provisional_.ok) {
                online_calib::State candidate;
                if(acquire(candidate)){provisional_=candidate;provisionalAt_=at;confirmationLast_=-1;confirmations_=0;confirmationCorroborated_=0;provisionalConflicts_=0;}
            }
        }
        ranging::Result result;result.frame=frame;result.marks=m.n_marks;
        result.calibration=locked_;
        result.calibration.frame_ok=locked_.ok&&!suspended_;
        suspended=suspended_;
        if(!locked_.ok)phase=provisional_.ok?"provisional":"acquiring";
        else if(suspended_)phase="conflict_reconfirm";
        else {held=!jointVerified||inconsistent;phase=held?"locked_unobserved":"locked_verified";}
        result.calibration.why=phase=="acquiring"?"等待可靠参数收敛":phase=="provisional"?"参数暂定，等待后续观测独立复核":
            phase=="conflict_reconfirm"?"道路参数冲突，暂停并重新确认":
            phase=="locked_unobserved"?(observationConflict?"道路参数已锁定，本帧标线互校冲突，沿用锁定参数":"使用已锁定道路参数，按当前目标框测距"):"道路参数已锁定，本帧标线复核通过";
        for(auto b:boxes)result.objects.push_back(cpu_distance_quality::project(b,result.calibration,size_,config_.road,distanceBounds,config_.score_min));
        return result;
    }
};
}
