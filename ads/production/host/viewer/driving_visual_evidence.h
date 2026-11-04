#pragma once
#include "vision_types.h"
#include "lane_preview.h"
#include <QJsonObject>
#include <QJsonArray>

namespace driving_visual {
struct LaneEvidence {
    std::vector<lane_arbitration::Boundary> lines;
    int left=-1,right=-1,leftOuter=-1,rightOuter=-1;
    bool egoValid=false,centered=false,leftAdjacent=false,rightAdjacent=false;
    bool usable(int index) const {
        if(index<0 || index>=int(lines.size()))return false;
        const auto& line=lines[size_t(index)];
        // Display-side hysteresis must not grant a crossing permission after
        // the measured boundary has already crossed the vehicle center.
        if((index==left && line.at(1)>=.5) || (index==right && line.at(1)<=.5))return false;
        return line.points.size()>=5 && line.maxY>=.7 && line.maxY-line.minY>=.10 &&
            line.segments[0].type>0;
    }
    int category(int index) const {return usable(index)?lines[size_t(index)].segments[0].type:0;}
    // The user-facing line-type hint is independent of full maneuver safety.
    // A dashed gap / image clipping may leave the fixed bottom band empty.
    int hintCategory(int index) const {
        if(index<0 || index>=int(lines.size()))return 0;
        const auto& line=lines[size_t(index)];
        if((index==left && line.at(1)>=.5) || (index==right && line.at(1)<=.5))return 0;
        const auto& near=line.segments[0];
        // Never substitute visible-end evidence for conflicting or unconfirmed
        // actual bottom-band evidence (including a true solid/dashed change).
        if(near.samples>=3)return category(index);
        if(line.points.size()<5 || line.maxY<.55 || line.maxY-line.minY<.10 ||
           line.visibleNear.samples<5 || line.visibleNear.conflict)return 0;
        const double visibleX=lane_arbitration::visibleAt(line,line.maxY);
        if((index==left && visibleX>=.5) || (index==right && visibleX<=.5))return 0;
        return line.visibleNear.type;
    }
};
inline LaneEvidence lanes(const lane_arbitration::Snapshot& scene) {
    LaneEvidence out;
    // A reserved missing boundary must prevent substitution by an outer line.
    // Snapshot clears its type immediately, so it cannot grant permission.
    for(const auto& track:scene.tracks)out.lines.push_back(track);
    const bool structured=scene.egoLeftId || scene.egoRightId;
    for(int i=0;i<int(out.lines.size());++i) {
        // Pick the nearest physical boundary even when its class is unknown;
        // never replace a conflicting near boundary with a farther dashed one.
        if(structured) {
            const auto& track=scene.tracks[size_t(i)];
            if(track.id==scene.egoLeftId)out.left=i;
            if(track.id==scene.egoRightId)out.right=i;
            if(track.slot==1)out.leftOuter=i;
            if(track.slot==4)out.rightOuter=i;
            continue;
        }
        if(out.lines[size_t(i)].maxY<.7)continue;
        const double x=out.lines[size_t(i)].at(1);
        if(x<.5)out.left=i;
        else if(out.right<0)out.right=i;
    }
    if(!structured){out.leftOuter=out.left-1;out.rightOuter=out.right+1;}
    if(out.left<0 || out.right<0)return out;
    const auto& left=out.lines[size_t(out.left)];const auto& right=out.lines[size_t(out.right)];
    if(left.maxY<.7 || right.maxY<.7)return out;
    const double width=right.at(1)-left.at(1);
    if(width<.08 || width>.85 || left.at(1)>=.5 || right.at(1)<=.5 || left.at(.7)>=right.at(.7))return out;
    out.egoValid=true;
    out.centered=std::abs((left.at(1)+right.at(1))*.5-.5)<=width*.25;
    out.leftAdjacent=out.usable(out.leftOuter) && left.at(1)-out.lines[size_t(out.leftOuter)].at(1)>.06;
    out.rightAdjacent=out.usable(out.rightOuter) && out.lines[size_t(out.rightOuter)].at(1)-right.at(1)>.06;
    return out;
}
inline LaneEvidence lanes(const QImage& mask) {
    if(mask.size()!=QSize(640,640))return {};
    lane_arbitration::Engine engine;const auto observation=lane_arbitration::fromMask(mask);
    engine.update(observation,1,1);return lanes(engine.update(observation,101,1));
}
inline bool occupied(const LaneEvidence& lane,const QVector<Detection>& detections,bool left) {
    if(!lane.egoValid || (left?!lane.leftAdjacent:!lane.rightAdjacent))return false;
    const auto& inner=lane.lines[size_t(left?lane.left:lane.right)];
    const auto& outer=lane.lines[size_t(left?lane.leftOuter:lane.rightOuter)];
    for(const auto& d:detections) {
        if(d.cls<0 || d.cls>6 || d.predicted || !std::isfinite(d.score) || d.score<.5 ||
           !std::isfinite(d.x1) || !std::isfinite(d.x2) || !std::isfinite(d.y2) || d.x2<=d.x1)continue;
        const double y=(d.y2-272.)/288.;
        if(y<.45 || y>1.)continue;
        const double low=std::min(inner.at(y),outer.at(y))*640.;
        const double high=std::max(inner.at(y),outer.at(y))*640.;
        if(std::min(double(d.x2),high)>std::max(double(d.x1),low))return true;
    }
    return false;
}
}
