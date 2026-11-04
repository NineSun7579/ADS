#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <deque>
#include <limits>
#include <utility>
#include <vector>

namespace tl_temporal {
constexpr int CandidateLimit=64,TrackLimit=16,ColorAgeMs=500,ReserveMs=900;
struct Candidate {
    float x1=0,y1=0,x2=0,y2=0;
    std::array<float,3> scores{}; // independent model sigmoid scores: red/yellow/green
    float score() const{return *std::max_element(scores.begin(),scores.end());}
};
inline double iou(const Candidate& a,const Candidate& b) {
    const double area=std::max(0.f,std::min(a.x2,b.x2)-std::max(a.x1,b.x1))*
        std::max(0.f,std::min(a.y2,b.y2)-std::max(a.y1,b.y1));
    const double total=(a.x2-a.x1)*(a.y2-a.y1)+(b.x2-b.x1)*(b.y2-b.y1)-area;
    return total>0?area/total:0;
}
inline bool valid(const Candidate& c) {
    return std::isfinite(c.x1)&&std::isfinite(c.x2)&&std::isfinite(c.y1)&&std::isfinite(c.y2)&&
        c.x1>=0&&c.x2<=640&&c.y1>=80&&c.y2<=560&&c.x2>c.x1&&c.y2>c.y1&&
        std::all_of(c.scores.begin(),c.scores.end(),[](float v){return std::isfinite(v)&&v>=0&&v<=1;});
}
// Bounded caller preselection (<=512). High-overlap duplicates contribute one
// observation and preserve conflicting scores instead of voting twice.
inline std::vector<Candidate> deduplicate(std::vector<Candidate> candidates) {
    candidates.erase(std::remove_if(candidates.begin(),candidates.end(),[](const Candidate& c){return !valid(c)||c.score()<.05f;}),candidates.end());
    std::stable_sort(candidates.begin(),candidates.end(),[](const Candidate& a,const Candidate& b){return a.score()>b.score();});
    if(candidates.size()>512)candidates.resize(512);
    std::vector<Candidate> output;
    for(const auto& c:candidates) {
        auto found=std::find_if(output.begin(),output.end(),[&](const Candidate& a){return iou(a,c)>.6;});
        if(found!=output.end()){for(int k=0;k<3;++k)found->scores[k]=std::max(found->scores[k],c.scores[k]);}
        else if(output.size()<CandidateLimit)output.push_back(c);
    }
    return output;
}
struct Track : Candidate {
    std::uint64_t id=0;bool confirmed=false,observed=false,conflict=false;
    int color=0; // 0 unknown,1 red,2 yellow,3 green; history never authorizes
    std::int64_t lastSeen=-1,lastColor=-1;
};
struct Scene {std::vector<Track> tracks;std::uint64_t frame=0;int generation=0;std::int64_t captured=-1;};
class Engine {
    struct Vote {int color=0;float score=0;std::int64_t at=0;};
    struct State {Track track;std::deque<Vote> votes;std::deque<std::pair<std::int64_t,bool>> hits;int pending=0;double vx=0,vy=0;};
    std::vector<State> states;std::uint64_t nextId=1,frame=0,continuity=0;
    std::int64_t captured=-1;int generation=0;
    std::deque<std::int64_t> intervals;
    static double cost(const State& s,const Candidate& c,std::int64_t time) {
        const auto& p=s.track;
        const double dt=std::clamp(double(time-p.lastSeen)/1000.,0.,.5);
        const double dx=(c.x1+c.x2-p.x1-p.x2)*.5-s.vx*dt,dy=(c.y1+c.y2-p.y1-p.y2)*.5-s.vy*dt;
        const double aw=p.x2-p.x1,ah=p.y2-p.y1,bw=c.x2-c.x1,bh=c.y2-c.y1;
        if(std::max(aw/bw,bw/aw)>2.5 || std::max(ah/bh,bh/ah)>2.5)return 1e6;
        const double gate=std::min(32.,std::max(5.,.65*std::hypot(aw,ah)+dt*12));
        if(std::hypot(dx,dy)>gate)return 1e6;
        return std::hypot(dx,dy)/gate+.15*(1-iou(p,c));
    }
public:
    void reset(){states.clear();intervals.clear();frame=0;captured=-1;generation=0;continuity=0;}
    Scene snapshot(std::int64_t now) const {
        Scene out;out.frame=frame;out.generation=generation;out.captured=captured;
        for(const auto& state:states) {
            Track t=state.track;
            if(now<t.lastSeen || now-t.lastSeen>ReserveMs)continue;
            if(now-t.lastSeen>ColorAgeMs){t.observed=false;t.color=0;}
            out.tracks.push_back(t);
        }
        return out;
    }
    Scene update(std::vector<Candidate> input,std::uint64_t id,int epoch,std::uint64_t sequence,std::int64_t time) {
        if(epoch==generation && (sequence<continuity || id<=frame || time<=captured))return snapshot(std::max(time,captured));
        if(epoch!=generation || sequence!=continuity){reset();generation=epoch;continuity=sequence;}
        if(id<=frame || time<=captured)return snapshot(std::max(time,captured));
        if(captured>=0){intervals.push_back(time-captured);if(intervals.size()>7)intervals.pop_front();}
        std::vector<std::int64_t> sorted(intervals.begin(),intervals.end());std::sort(sorted.begin(),sorted.end());
        const auto period=sorted.empty()?200:sorted[sorted.size()/2];
        const auto window=std::clamp<std::int64_t>(3*std::min<std::int64_t>(period,800),800,2400);
        frame=id;captured=time;
        states.erase(std::remove_if(states.begin(),states.end(),[&](const State& s){return time-s.track.lastSeen>ReserveMs;}),states.end());
        const auto candidates=deduplicate(std::move(input));
        struct Pair {double cost;size_t state,candidate;};std::vector<Pair> pairs;
        std::vector<bool> ambiguous(candidates.size(),false),used(states.size(),false);
        for(size_t c=0;c<candidates.size();++c) {
            double first=1e6,second=1e6;
            for(size_t s=0;s<states.size();++s) {
                const double value=cost(states[s],candidates[c],time);
                if(value<first){second=first;first=value;}else second=std::min(second,value);
                if(value<1.2)pairs.push_back({value,s,c});
            }
            ambiguous[c]=second<1.2 && second-first<.18;
        }
        // Also reject one old identity competing equally for two nearby lamps.
        std::vector<bool> blocked(states.size(),false);
        for(size_t s=0;s<states.size();++s) {
            double first=1e6,second=1e6;
            for(const auto& p:pairs)if(p.state==s){if(p.cost<first){second=first;first=p.cost;}else second=std::min(second,p.cost);}
            if(second<1.2 && second-first<.18)blocked[s]=true;
        }
        std::sort(pairs.begin(),pairs.end(),[](const Pair& a,const Pair& b){return a.cost<b.cost;});
        std::vector<int> assignment(candidates.size(),-1);
        for(const auto& p:pairs)if(!ambiguous[p.candidate]&&!blocked[p.state]&&!used[p.state]&&assignment[p.candidate]<0) {
            assignment[p.candidate]=int(p.state);used[p.state]=true;
        }
        for(auto& state:states){state.track.observed=false;state.track.color=0;}
        for(size_t c=0;c<candidates.size();++c) {
            if(ambiguous[c])continue;
            int index=assignment[c];
            if(index<0) {
                // Ambiguous old/new assignment must not create another ID nearby.
                bool competition=false;for(const auto& p:pairs)if(p.candidate==c)competition=true;
                if(competition || states.size()>=TrackLimit)continue;
                states.emplace_back();index=int(states.size()-1);states.back().track.id=nextId++;
            }
            auto& s=states[size_t(index)];auto& t=s.track;const auto& v=candidates[c];
            const double dt=double(time-t.lastSeen)/1000.;
            if(t.lastSeen>=0 && dt>0 && dt<=.5) {
                s.vx=.5*s.vx+.5*std::clamp((v.x1+v.x2-t.x1-t.x2)*.5/dt,-64.,64.);
                s.vy=.5*s.vy+.5*std::clamp((v.y1+v.y2-t.y1-t.y2)*.5/dt,-64.,64.);
            }
            static_cast<Candidate&>(t)=v;t.lastSeen=time;t.observed=true;t.conflict=false;
            while(!s.hits.empty() && time-s.hits.front().first>window)s.hits.pop_front();
            s.hits.push_back({time,true});if(s.hits.size()>3)s.hits.pop_front();
            // At least one nontrivial anchor is needed; repeated .05 noise is not a light.
            if(std::count_if(s.hits.begin(),s.hits.end(),[](const auto& hit){return hit.second;})>=2 && v.score()>=.15f)t.confirmed=true;
            int best=int(std::max_element(v.scores.begin(),v.scores.end())-v.scores.begin());
            float second=0;for(int k=0;k<3;++k)if(k!=best)second=std::max(second,v.scores[k]);
            const bool colorClear=v.scores[best]>=.15f && v.scores[best]-second>=.08f;
            if(!colorClear){t.conflict=second>=.1f;s.pending=0;s.votes.clear();continue;}
            const int color=best+1;
            if(s.pending!=color){s.pending=color;s.votes.clear();}
            while(!s.votes.empty() && time-s.votes.front().at>window)s.votes.pop_front();
            s.votes.push_back({color,v.score(),time});if(s.votes.size()>3)s.votes.pop_front();
            const size_t needed=color==3?3:2;
            if(t.confirmed && s.votes.size()>=needed && time-s.votes.front().at>=80) {
                t.color=color;t.lastColor=time;
            }
        }
        // Insert a negative sample so two hits survive one miss but not a long sequence.
        for(auto& s:states)if(!s.track.observed) {
            s.hits.push_back({time,false});if(s.hits.size()>3)s.hits.pop_front();
            while(!s.hits.empty()&&time-s.hits.front().first>window)s.hits.pop_front();
            while(!s.votes.empty()&&time-s.votes.front().at>window)s.votes.pop_front();
            // Two consecutive missed model observations require new color proof.
            if(s.hits.size()>=2&&!s.hits.back().second&&!s.hits[s.hits.size()-2].second){s.votes.clear();s.pending=0;}
        }
        return snapshot(time);
    }
};
struct Topology {
    std::array<std::uint64_t,3> groupIds{};int expected=0;std::int64_t since=-1;
    std::array<std::uint64_t,3> pending{};
    void reset(){groupIds={};pending={};since=-1;}
    // Expected count is explicitly configured, never inferred from missing lamps.
    bool update(const std::vector<Track>& visible,int count,std::int64_t time) {
        if(expected!=count){reset();expected=count;}
        if(count<1||count>3){reset();return false;}
        for(const auto& t:visible)if(!t.confirmed&&t.observed&&t.score()>=.15f){since=-1;return false;}
        std::vector<Track> confirmed;
        for(const auto& t:visible)if(t.confirmed)confirmed.push_back(t);
        std::sort(confirmed.begin(),confirmed.end(),[](const Track& a,const Track& b){return a.x1+a.x2<b.x1+b.x2;});
        for(size_t i=1;i<confirmed.size();++i) {
            const auto& a=confirmed[i-1];const auto& b=confirmed[i];
            const double separation=(b.x1+b.x2-a.x1-a.x2)*.5;
            if(separation<=std::max(2.,.25*std::min(double(a.x2-a.x1),double(b.x2-b.x1)))){reset();return false;}
        }
        if(groupIds[0]) {
            // Keep slots on short misses. Extra/expired identities require new topology.
            bool validSet=confirmed.size()==size_t(count);
            for(size_t i=0;validSet&&i<confirmed.size();++i)validSet=confirmed[i].id==groupIds[i];
            if(validSet)return true;
            // A strict subset with surviving IDs retains unknown holes.
            bool subset=confirmed.size()<size_t(count);
            for(const auto& t:confirmed)subset=subset&&std::find(groupIds.begin(),groupIds.begin()+count,t.id)!=groupIds.begin()+count;
            if(subset)return true;
            reset();return false;
        }
        if(confirmed.size()!=size_t(count) || std::any_of(confirmed.begin(),confirmed.end(),[](const Track& t){return !t.observed;})){since=-1;return false;}
        std::array<std::uint64_t,3> ids{};for(int i=0;i<count;++i)ids[size_t(i)]=confirmed[size_t(i)].id;
        if(since<0||pending!=ids){pending=ids;since=time;return false;}
        if(time-since<200)return false;
        for(int i=0;i<count;++i)groupIds[i]=confirmed[size_t(i)].id;
        return true;
    }
};
}
