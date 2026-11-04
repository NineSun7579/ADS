#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>

namespace lane_type_temporal {
struct Result {int type=0;bool conflict=false;};
// Display only. Crossing permissions must continue to use current near evidence.
class Filter {
    struct Axis {
        std::array<double,3> probability{};
        int stable=-1,pending=-1,count=0;
        std::int64_t since=-1,last=-1;
        void interrupt(){pending=-1;count=0;since=-1;}
        bool update(const std::array<double,3>& value,int size,std::int64_t now,int changeMs,int changeCount) {
            const double alpha=last<0?1.:1.-std::exp(-double(now-last)/240.);
            for(int i=0;i<size;++i)probability[size_t(i)]+=alpha*(value[size_t(i)]-probability[size_t(i)]);
            last=now;
            int best=0;
            for(int i=1;i<size;++i)if(value[size_t(i)]>value[size_t(best)])best=i;
            double second=0;
            for(int i=0;i<size;++i)if(i!=best)second=std::max(second,value[size_t(i)]);
            const bool decisive=value[size_t(best)]>=.62 && value[size_t(best)]-second>=.18;
            if(!decisive){interrupt();return false;}
            if(best==stable){interrupt();return true;}
            if(pending!=best){pending=best;count=1;since=now;}else ++count;
            const int required=stable<0?2:changeCount,span=stable<0?80:changeMs;
            if(count>=required && now-since>=span && probability[size_t(best)]>=.62) {
                stable=best;interrupt();return true;
            }
            return false;
        }
    };
    Axis color,pattern;
    std::int64_t lastTime=-1,lastEvidence=-1;
    int confirmedType=0,jointPending=0,jointCount=0;
    std::int64_t jointSince=-1;
    Result output;
public:
    void reset(){color={};pattern={};lastTime=lastEvidence=-1;confirmedType=0;missing();}
    void missing(){color.interrupt();pattern.interrupt();jointPending=jointCount=0;jointSince=-1;output={};}
    Result update(const std::array<double,9>& raw,int samples,std::int64_t time,bool conflicted=false) {
        if(time<=lastTime)return output;
        if(lastEvidence>=0 && time-lastEvidence>700){color={};pattern={};missing();}
        lastTime=time;
        if(conflicted){missing();output.conflict=true;return output;}
        double mass=0;
        for(int c=0;c<9;++c)if(!std::isfinite(raw[size_t(c)]) || raw[size_t(c)]<0){missing();return output;}
        for(int c=1;c<=6;++c)mass+=raw[size_t(c)];
        if(samples<3 || mass<.45){missing();return output;}
        int rawType=1;
        for(int c=2;c<=6;++c)if(raw[size_t(c)]>raw[size_t(rawType)])rawType=c;
        double rawSecond=0;
        for(int c=1;c<=6;++c)if(c!=rawType)rawSecond=std::max(rawSecond,raw[size_t(c)]);
        if(raw[size_t(rawType)]>=.5 && raw[size_t(rawType)]-rawSecond>=.12) {
            if(jointPending!=rawType){jointPending=rawType;jointCount=1;jointSince=time;}else ++jointCount;
        }else {jointPending=jointCount=0;jointSince=-1;}
        // Separate color from pattern; neither attribute manufactures a class.
        std::array<double,3> colors{{(raw[1]+raw[3]+raw[5])/mass,(raw[2]+raw[4]+raw[6])/mass,0}};
        std::array<double,3> patterns{{(raw[1]+raw[2])/mass,(raw[3]+raw[4])/mass,(raw[5]+raw[6])/mass}};
        const bool colorOk=color.update(colors,2,time,300,3);
        const bool patternOk=pattern.update(patterns,3,time,400,4);
        lastEvidence=time;
        output={0,!colorOk || !patternOk};
        if(!colorOk || !patternOk)return output;
        const int type=pattern.stable==0?(color.stable==0?1:2):
                       pattern.stable==1?(color.stable==0?3:4):(color.stable==0?5:6);
        // Marginals alone can propose a combination never seen in the pixels.
        // Require joint current probability; reject weak/contradictory paint.
        double other=0;
        for(int c=1;c<=6;++c)if(c!=type)other=std::max(other,raw[size_t(c)]);
        if(raw[size_t(type)]<.5 || raw[size_t(type)]-other<.12){output.conflict=true;return output;}
        if(confirmedType && type!=confirmedType) {
            const auto kind=[](int c){return c<=2?0:c<=4?1:2;};
            const bool patternChanged=kind(type)!=kind(confirmedType);
            if(jointPending!=type || jointCount<(patternChanged?5:4) || time-jointSince<(patternChanged?600:500)) {
                output.conflict=true;return output;
            }
        }
        confirmedType=type;output={type,false};return output;
    }
};
} // namespace lane_type_temporal
