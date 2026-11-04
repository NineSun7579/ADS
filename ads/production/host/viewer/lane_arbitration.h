#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>
#include "lane_type_temporal.h"

namespace lane_arbitration {
constexpr int SlotCount=6;
constexpr int FreshMs=500,ReserveMs=1000;
constexpr int DisplayKeepMs=700;
struct Point {double x=0,y=0;};
struct Segment {
    int type=0,samples=0;double support=0,margin=0;bool conflict=false;
    std::array<double,9> probability{};
};
struct Boundary {
    std::vector<Point> points;
    std::array<Segment,3> segments{}; // near >=.65, middle >=.35, far
    Segment visibleNear; // 每条边界自身最靠近车的可见部分，仅用于符号显示。
    Segment appearance; // 几何明确的整条可见边界，仅作显示类别的辅助证据。
    bool farAmbiguous=false;
    double x=0,slope=0,minY=1,maxY=0;
    double at(double y) const{return x+slope*(y-1);}
};
struct Observation {std::vector<Boundary> boundaries;bool hasProbabilities=false;};
enum class DisplayState {Acquiring,Confirmed,Coasting,Conflicting,Hidden};
struct Track : Boundary {
    std::uint64_t id=0;int slot=-1;bool observed=false;std::int64_t lastSeen=0;
    int displayType=0;DisplayState displayState=DisplayState::Acquiring;
    std::int64_t displaySupportedMs=-1;
    double layoutX=.5; // 平滑仅用于车道关系/示意图，不进入跨线许可。
};
struct Snapshot {
    std::vector<Track> tracks;std::int64_t capturedMs=-1;int generation=0;
    std::uint64_t egoLeftId=0,egoRightId=0;
};
inline int band(double y){return y>=.65?0:y>=.35?1:2;}
inline double predict(const std::vector<Point>& points,double y) {
    const size_t begin=points.size()>10?points.size()-10:0;
    double sx=0,sy=0,sxy=0,syy=0,n=double(points.size()-begin);
    if(!n)return 0;
    for(size_t i=begin;i<points.size();++i){const auto p=points[i];sx+=p.x;sy+=p.y;sxy+=p.x*p.y;syy+=p.y*p.y;}
    const double denominator=n*syy-sy*sy;
    const double slope=denominator>1e-8?(n*sxy-sx*sy)/denominator:0;
    return (sx-slope*sy)/n+slope*y;
}
struct Run {
    int first=0,last=0,type=0;double x=0;
    std::array<double,9> probabilities{};
};
inline Segment decide(Segment segment) {
    if(segment.samples<3)return segment;
    for(auto& p:segment.probability)p/=segment.samples;
    int best=1,second=2;
    for(int c=1;c<=6;++c)if(segment.probability[c]>segment.probability[best])best=c;
    second=best==1?2:1;
    for(int c=1;c<=6;++c)if(c!=best && segment.probability[c]>segment.probability[second])second=c;
    segment.support=segment.probability[best];
    segment.margin=segment.support-segment.probability[second];
    double solid=0,dashed=0;
    for(int c=1;c<=4;++c)solid+=segment.probability[c];
    dashed=segment.probability[5]+segment.probability[6];
    segment.conflict=(solid>.22 && dashed>.22) || segment.margin<.12;
    if(segment.support>=.5 && !segment.conflict)segment.type=best;
    return segment;
}
// Geometry uses binary runs across all six line classes, so a color change
// does not create a second identity. Inputs are the filtered OUTPUT grid and
// optional class probabilities in NCHW, not display colors.
inline Observation trace(const unsigned char* labels,int width,int height,const float* probabilities=nullptr) {
    Observation output;output.hasProbabilities=probabilities!=nullptr;
    if(!labels || width<8 || height<8)return output;
    const size_t plane=size_t(width)*height;
    struct Candidate {Boundary boundary;bool blocked=false;};
    std::vector<Candidate> candidates;
    const int step=std::max(1,height/72);
    for(int row=height-1;row>=height/12;row-=step) {
        const double y=double(row)/(height-1);
        std::vector<Run> runs;
        for(int column=0;column<width;) {
            const int cls=labels[size_t(row)*width+column];
            if(cls<1 || cls>6){++column;continue;}
            Run run;run.first=column;std::array<int,7> counts{};
            while(column<width) {
                const size_t p=size_t(row)*width+column;const int type=labels[p];
                if(type<1||type>6)break;
                ++counts[type];
                for(int c=0;c<9;++c)run.probabilities[c]+=probabilities?probabilities[size_t(c)*plane+p]:(c==type?1.:0.);
                ++column;
            }
            run.last=column-1;run.x=(run.first+run.last)*.5/width;
            run.type=int(std::max_element(counts.begin()+1,counts.end())-counts.begin());
            for(auto& p:run.probabilities)p/=column-run.first;
            // Double-class runs are paired only in the near field. Far-end
            // convergence cannot create a double-line identity.
            if(!runs.empty() && y>=.55 && (run.type==1 || run.type==2) && runs.back().type==run.type &&
               (run.first-runs.back().last)<width*.025) {
                auto& previous=runs.back();
                for(int c=0;c<9;++c)previous.probabilities[c]=(previous.probabilities[c]+run.probabilities[c])*.5;
                previous.last=run.last;previous.x=(previous.first+previous.last)*.5/width;
            } else runs.push_back(run);
        }
        std::vector<std::vector<int>> eligible(runs.size());
        std::vector<int> hitCount(candidates.size(),0);
        for(size_t r=0;r<runs.size();++r)for(size_t c=0;c<candidates.size();++c) {
            const auto& candidate=candidates[c];const auto& points=candidate.boundary.points;
            if(candidate.blocked || points.empty() || points.back().y-y>.28)continue;
            const double expected=predict(points,y);
            // At the first point slope is unknown: side-exiting lines can move
            // >.025 per scan step. Once established use the tighter fit gate.
            const double gate=points.size()==1?.065:.025;
            if(std::abs(expected-runs[r].x) < gate+double(runs[r].last-runs[r].first+1)/width*.5) {
                eligible[r].push_back(int(c));++hitCount[c];
            }
        }
        std::vector<bool> used(candidates.size(),false);
        for(size_t r=0;r<runs.size();++r) {
            const auto& run=runs[r];const auto& ids=eligible[r];
            if(ids.size()>1) {
                for(int c:ids){candidates[size_t(c)].blocked=true;candidates[size_t(c)].boundary.farAmbiguous=true;}
                continue; // shared pixels cannot vote for either boundary
            }
            int selected=ids.empty()?-1:ids[0];
            if(selected>=0 && (used[size_t(selected)] || hitCount[size_t(selected)]>1)) {
                candidates[size_t(selected)].blocked=true;candidates[size_t(selected)].boundary.farAmbiguous=true;continue;
            }
            if(selected<0) {
                // A visible boundary can end at an image side or above the near
                // field (letterboxed video, occlusion, dashed gap). Keep it for
                // the schematic; ADAS separately requires actual near support.
                if(y<.40 || candidates.size()>=12 || run.last-run.first>width*.08)continue;
                candidates.emplace_back();used.push_back(false);selected=int(candidates.size()-1);
            }
            auto& candidate=candidates[size_t(selected)];
            if(candidate.blocked)continue;
            used[size_t(selected)]=true;
            auto& boundary=candidate.boundary;
            boundary.points.push_back({run.x,y});boundary.minY=std::min(boundary.minY,y);boundary.maxY=std::max(boundary.maxY,y);
            auto& segment=boundary.segments[band(y)];++segment.samples;
            for(int c=0;c<9;++c)segment.probability[c]+=run.probabilities[c];
            ++boundary.appearance.samples;
            for(int c=0;c<9;++c)boundary.appearance.probability[c]+=run.probabilities[c];
            if(y>=boundary.maxY-.12) {
                ++boundary.visibleNear.samples;
                for(int c=0;c<9;++c)boundary.visibleNear.probability[c]+=run.probabilities[c];
            }
        }
    }
    for(auto& candidate:candidates) {
        auto& b=candidate.boundary;
        if(b.points.size()<5 || b.maxY-b.minY<.10 || b.maxY<.45)continue;
        // Near-only regression is used for lateral ordering and ego membership;
        // far convergence and far curves cannot drag the near intercept.
        std::vector<Point> near;for(auto p:b.points)if(p.y>=.60)near.push_back(p);
        if(near.size()<4){near.clear();for(auto p:b.points)if(p.y>=b.maxY-.20)near.push_back(p);}
        if(near.size()<4)continue;
        b.x=predict(near,1);b.slope=(predict(near,1)-predict(near,.8))/.2;
        for(auto& segment:b.segments)segment=decide(segment);
        b.visibleNear=decide(b.visibleNear);
        b.appearance=decide(b.appearance);
        output.boundaries.push_back(std::move(b));
    }
    std::sort(output.boundaries.begin(),output.boundaries.end(),[](const Boundary& a,const Boundary& b){return a.x<b.x;});
    return output;
}

// Interpolate the actual common visible curve instead of comparing two long
// extrapolations to the image bottom. Geometry never depends on marking color.
inline double visibleAt(const Boundary& b,double y) {
    for(size_t i=1;i<b.points.size();++i) {
        const auto a=b.points[i-1],c=b.points[i];
        if(y<=a.y && y>=c.y && a.y-c.y>1e-6)
            return c.x+(a.x-c.x)*(y-c.y)/(a.y-c.y);
    }
    return b.at(y);
}
inline double associationCost(const Boundary& a,const Boundary& b) {
    double low=std::max({a.minY,b.minY,.35}),high=std::min(a.maxY,b.maxY);
    if(high<low) {
        if(low-high>.16)return 1e6;
        low=high=(low+high)*.5;
    }
    double mean=0,worst=0;
    for(double f:{.15,.5,.85}) {
        const double y=low+(high-low)*f,d=std::abs(visibleAt(a,y)-visibleAt(b,y));
        mean+=d/3.;worst=std::max(worst,d);
    }
    if(mean>=.10 || worst>=.14)return 1e6;
    return mean+.015*std::min(3.,std::abs(a.slope-b.slope));
}
class Engine {
    struct State {
        Track track;std::array<int,4> pending{},count{};
        std::array<std::int64_t,4> since{};
        lane_type_temporal::Filter displayFilter;
    };
    std::vector<State> states;
    std::uint64_t nextId=1;
    std::int64_t captured=-1;int generation=0;
    std::uint64_t egoLeftId=0,egoRightId=0;
    static void updateDisplay(State& state,const Boundary& b,std::int64_t time) {
        auto& t=state.track;
        // Real local evidence, rather than a six-way winning class, feeds the
        // two attribute filters. Other bands cannot vote across a transition.
        const auto result=state.displayFilter.update(b.visibleNear.probability,b.visibleNear.samples,time,b.visibleNear.conflict);
        if(result.type) {
            t.displayType=result.type;t.displayState=DisplayState::Confirmed;t.displaySupportedMs=time;
        } else t.displayState=b.visibleNear.conflict || (result.conflict && t.displayType)?
            DisplayState::Conflicting:DisplayState::Acquiring;
    }
    void layout() {
        std::vector<State*> ordered;for(auto& state:states)ordered.push_back(&state);
        std::sort(ordered.begin(),ordered.end(),[](const State* a,const State* b){return a->track.layoutX<b->track.layoutX;});
        size_t pivot=0;while(pivot<ordered.size() && ordered[pivot]->track.layoutX<.5)++pivot;
        // Small lateral jitter around the vehicle center cannot swap an
        // established ego boundary to the other side. Real crossing releases it.
        for(size_t i=0;i<ordered.size();++i) {
            const auto& t=ordered[i]->track;
            if(t.id==egoLeftId && t.layoutX>=.5 && t.layoutX<.54)pivot=i+1;
            if(t.id==egoRightId && t.layoutX<.5 && t.layoutX>.46)pivot=i;
        }
        for(size_t i=0;i<ordered.size();++i) {
            const int slot=3+int(i)-int(pivot);
            ordered[i]->track.slot=slot>=0 && slot<SlotCount?slot:-1;
        }
        egoLeftId=pivot?ordered[pivot-1]->track.id:0;
        egoRightId=pivot<ordered.size()?ordered[pivot]->track.id:0;
    }
public:
    void reset(){states.clear();captured=-1;generation=0;egoLeftId=egoRightId=0;}
    Snapshot snapshot(std::int64_t now) const {
        Snapshot out;out.capturedMs=captured;out.generation=generation;
        out.egoLeftId=egoLeftId;out.egoRightId=egoRightId;
        for(const auto& state:states) {
            if(now<state.track.lastSeen || now-state.track.lastSeen>ReserveMs)continue;
            Track track=state.track;
            if(!track.observed || now-track.lastSeen>FreshMs) {
                track.observed=false;for(auto& segment:track.segments)segment.type=0;
                track.visibleNear.type=0;
                track.displayState=now-track.lastSeen<=DisplayKeepMs?DisplayState::Coasting:DisplayState::Hidden;
            }
            out.tracks.push_back(std::move(track));
        }
        std::sort(out.tracks.begin(),out.tracks.end(),[](const Track& a,const Track& b){return a.x<b.x;});
        return out;
    }
    Snapshot update(const Observation& observation,std::int64_t time,int epoch) {
        if(epoch!=generation){reset();generation=epoch;}
        if(time<=captured)return snapshot(std::max(captured,time));
        captured=time;
        states.erase(std::remove_if(states.begin(),states.end(),[&](const State& s){return time-s.track.lastSeen>ReserveMs;}),states.end());
        for(auto& state:states)state.track.observed=false;
        // Small monotone sequence alignment gives a global association, keeping
        // neighboring boundaries ordered through dashed gaps and partial views.
        std::vector<size_t> oldOrder,newOrder;
        for(size_t i=0;i<states.size();++i)oldOrder.push_back(i);
        for(size_t i=0;i<observation.boundaries.size();++i)newOrder.push_back(i);
        std::sort(oldOrder.begin(),oldOrder.end(),[&](size_t a,size_t b){return visibleAt(states[a].track,.65)<visibleAt(states[b].track,.65);});
        std::sort(newOrder.begin(),newOrder.end(),[&](size_t a,size_t b){return visibleAt(observation.boundaries[a],.65)<visibleAt(observation.boundaries[b],.65);});
        const size_t n=oldOrder.size(),m=newOrder.size();
        std::vector<double> dp((n+1)*(m+1),1e6);std::vector<char> step(dp.size());dp[0]=0;
        const auto improve=[&](size_t i,size_t j,double value,char action) {
            const size_t p=i*(m+1)+j;if(value<dp[p]){dp[p]=value;step[p]=action;}
        };
        for(size_t i=0;i<=n;++i)for(size_t j=0;j<=m;++j) {
            const double cost=dp[i*(m+1)+j];
            if(i<n)improve(i+1,j,cost+.085,'s');
            if(j<m)improve(i,j+1,cost+.085,'o');
            if(i<n && j<m)improve(i+1,j+1,cost+associationCost(states[oldOrder[i]].track,observation.boundaries[newOrder[j]]),'m');
        }
        std::vector<int> assigned(observation.boundaries.size(),-1);
        for(size_t i=n,j=m;i || j;) {
            const char action=step[i*(m+1)+j];
            if(action=='m'){assigned[newOrder[j-1]]=int(oldOrder[i-1]);--i;--j;}
            else if(action=='s')--i;
            else --j;
        }
        std::vector<size_t> order;
        for(size_t o=0;o<observation.boundaries.size();++o)order.push_back(o);
        std::stable_sort(order.begin(),order.end(),[&](size_t a,size_t b){return std::abs(observation.boundaries[a].x-.5)<std::abs(observation.boundaries[b].x-.5);});
        for(size_t o:order) {
            const auto& b=observation.boundaries[o];int s=assigned[o];
            if(s<0) {
                if(states.size()>=12)continue;
                states.emplace_back();s=int(states.size()-1);states.back().track.id=nextId++;
                states.back().track.layoutX=b.x;
            }
            auto& state=states[size_t(s)];auto& track=state.track;
            const bool gap=track.lastSeen>0 && time-track.lastSeen>FreshMs;
            const auto previous=track.segments;
            const auto previousVisible=track.visibleNear;
            static_cast<Boundary&>(track)=b;track.lastSeen=time;track.observed=true;
            track.layoutX=.6*track.layoutX+.4*b.x;
            updateDisplay(state,b,time);
            for(int k=0;k<4;++k) {
                const int candidate=k==3?b.visibleNear.type:b.segments[size_t(k)].type;
                if(gap || candidate!=state.pending[size_t(k)]) {
                    state.pending[size_t(k)]=candidate;state.count[size_t(k)]=1;state.since[size_t(k)]=time;
                } else ++state.count[size_t(k)];
                const int before=k==3?previousVisible.type:previous[size_t(k)].type;
                const bool confirmed=candidate && ((before==candidate && !gap) ||
                    (state.count[size_t(k)]>=2 && time-state.since[size_t(k)]>=80));
                if(k==3)track.visibleNear.type=confirmed?candidate:0;
                else track.segments[size_t(k)].type=confirmed?candidate:0;
            }
        }
        // Permission uses measured segments only. Display reserves a gray
        // position briefly; history never supplies crossing-region evidence.
        for(auto& state:states)if(!state.track.observed) {
            for(auto& segment:state.track.segments)segment.type=0;
            state.track.visibleNear.type=0;
            state.track.displayState=DisplayState::Coasting;
            state.pending={};state.count={};
            state.displayFilter.missing();
        }
        layout();
        return snapshot(time);
    }
};
}
