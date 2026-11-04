#pragma once
#include "driving_lane_change.h"
#include "driving_traffic_permission.h"
#include "driving_visual_evidence.h"
#include "intersection_evidence.h"
#include "traffic_light_temporal.h"
#include "lane6_d3a_view.h"
#include "ads_state_machine/navigation_signal.h"
#include "nav_ranging.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QRectF>
#include <limits>

// GUI-thread owner. Captured timestamps, actual image geometry and detection
// coordinates are retained; the renderer's fixed lane slots never enter rules.
class AdsDrivingAdapter {
public:
    using Callback=std::function<void(const QJsonObject&)>;
    void setAebTrajectoryConfig(const QJsonObject& config){aebConfig=config;}
    // 灯位门（需求）：只输出画面内容区上半 50%、水平 60%~80% 的红绿灯。
    // 检测框/候选都是 640x640 canonical，内容区从 y=80 起、高 480。
    static bool lightInRoi(double x1,double y1,double x2,double y2) {
        constexpr double xMin=640.0*0.60,xMax=640.0*0.80,yBottom=480.0*0.50;
        const double cx=(x1+x2)*.5,cy=((y1-80.0)+(y2-80.0))*.5;
        return cy<=yBottom && cx>=xMin && cx<=xMax;
    }
    void setCallback(Callback cb){callback=std::move(cb);}
    void setAheadRegion(QRectF region){aheadRegion=region;reset();}
    void reset(){
        aebBatch={};navigationSignal.reset();navSignal=0;
        laneAt=lightAt=motionAt=-1;stableCount=0;markingCounts={};
        lights.clear();groups.clear();previousGroups.clear();objects.clear();laneEvidence={};
        laneEngine.reset();
        lightEngine.reset();lightTopology.reset();lightScene={};lightMapping=false;
        intersection.reset();crosswalkSpanPx=0;
        signalController.stop();signalState=ads_lane_rules::Signal::OFF;
    }
    void enableTemporalLights(bool enabled){temporalLights=enabled;reset();}
    void setExpectedLights(int count){expectedLights=std::clamp(count,0,3);lightTopology.reset();}
    void lightCandidates(std::vector<tl_temporal::Candidate> candidates,quint64 frame,int generation,quint64 continuity,qint64 captured){
        // 只把落在灯位门内的候选送进时序跟踪：门外的灯既不显示也不参与决策。
        std::vector<tl_temporal::Candidate> kept;
        kept.reserve(candidates.size());
        for(const auto& c:candidates) if(lightInRoi(c.x1,c.y1,c.x2,c.y2)) kept.push_back(c);
        lightScene=lightEngine.update(std::move(kept),frame,generation,continuity,captured);
        std::vector<tl_temporal::Track> ahead;
        for(const auto& t:lightScene.tracks)if(aheadRegion.contains(QPointF((t.x1+t.x2)*.5,(t.y1+t.y2)*.5)))ahead.push_back(t);
        lightMapping=lightTopology.update(ahead,expectedLights,captured);
    }
    tl_temporal::Scene trafficScene(qint64 now) const{return lightEngine.snapshot(now);}
    void vehicleState(bool valid,bool changing,bool crossed,bool reached,qint64 captured){
        motionAt=captured;vehicleValid=valid;changingLane=changing;crossingTracked=crossed;targetReached=reached;
    }
    void lane(const QImage& mask,qint64 captured,int generation=1,
              const lane_arbitration::Observation* observation=nullptr,const lane6::LaneMarkingCounts* counts=nullptr){
        if(captured<laneAt)return;
        markingCounts={};laneAt=captured;
        const auto scene=laneEngine.update(observation?*observation:lane_arbitration::fromMask(mask),captured,generation);
        laneEvidence=driving_visual::lanes(scene);
        if(counts){markingCounts=*counts;return;}
        const QImage rgb=mask.convertToFormat(QImage::Format_ARGB32_Premultiplied);
        // 斑马线横向跨度：类 8 在 x 方向的最小/最大像素（不是纵向长度），供路口接近判定。
        int crosswalkMinX=-1,crosswalkMaxX=-1;
        for(int y=0;y<rgb.height();++y) {
            const auto* row=reinterpret_cast<const QRgb*>(rgb.constScanLine(y));
            for(int x=0;x<rgb.width();++x)if(qAlpha(row[x]))
                for(int c=1;c<=8;++c)if(c!=7 && row[x]==qPremultiply(lane_style::rgba(c))) {
                    ++markingCounts[c];
                    if(c==8) {
                        if(crosswalkMinX<0||x<crosswalkMinX)crosswalkMinX=x;
                        if(x>crosswalkMaxX)crosswalkMaxX=x;
                    }
                }
        }
        crosswalkSpanPx=crosswalkMinX>=0?double(crosswalkMaxX-crosswalkMinX+1):0.0;
    }
    lane_arbitration::Snapshot laneScene(qint64 now) const{return laneEngine.snapshot(now);}
    void trajectoryDetections(const QVector<Detection>& boxes,qint64 captured,
                              const QString& source,int generation,quint64 continuity) {
        if(captured<aebBatch["captured_ms"].toDouble(-1))return;
        QJsonArray targets;
        for(const auto& d:boxes) {
            if(!((d.cls>=0&&d.cls<=2)||d.cls==6))continue;
            targets.append(QJsonObject{{"id",QString::number(d.trackId)},{"class_id",d.cls},
                {"observed_ms",double(d.observedMs)},{"geometry_ms",double(d.motionGeometryMs)},
                {"predicted",d.predicted},{"distance_grade",d.monoGrade},{"distance_method",d.monoMethod},
                {"cx_px",(d.x1+d.x2)*.5},{"foot_px",d.y2-80.},
                {"A",d.motionA},{"vh",d.motionVh},{"hc",d.motionHc},
                {"velocity_valid",d.motionValid},{"vz_mps",d.motionVz},{"score",d.score}});
        }
        aebBatch={{"captured_ms",double(captured)},{"source",source},{"generation",generation},
            {"continuity",double(continuity)},{"config",aebConfig},{"targets",targets}};
    }
    void detections(const QVector<Detection>& boxes,qint64 captured){
        if(captured<lightAt)return;
        if(lightAt>=0 && captured-lightAt>500){stableCount=0;previousGroups.clear();}
        lightAt=captured;lights.clear();objects.clear();rejectedLights=0;
        std::vector<ads_traffic_rules::TrafficLight> selected;
        for(const auto& d:boxes) {
            const bool valid=std::isfinite(d.score) && d.score>=.5 && !d.predicted &&
                std::isfinite(d.x1) && std::isfinite(d.x2) && std::isfinite(d.y1) && std::isfinite(d.y2) &&
                d.x2>d.x1 && d.y2>d.y1 && d.x1>=0 && d.y1>=0 && d.x2<=640 && d.y2<=640;
            if(d.cls>=0 && d.cls<=6 && valid)objects.push_back(d);
            if(d.cls<7 || d.cls>9)continue;
            if(!valid){++rejectedLights;continue;}
            // 灯位门：不在上半 50% / 水平 60%~80% 的灯不进入输出与决策。
            if(!lightInRoi(d.x1,d.y1,d.x2,d.y2)){++rejectedLights;continue;}
            ads_traffic_rules::TrafficLight light;
            light.box={d.x1,d.y1,d.x2-d.x1,d.y2-d.y1};
            light.color=d.cls==7?ads_traffic_rules::LightColor::Red:
                d.cls==8?ads_traffic_rules::LightColor::Yellow:ads_traffic_rules::LightColor::Green;
            light.confidence=d.score;light.timestamp_ms=captured;
            light.is_ahead=!aheadRegion.isEmpty() && aheadRegion.contains(QPointF((d.x1+d.x2)/2,(d.y1+d.y2)/2));
            light.distance_m=std::numeric_limits<double>::quiet_NaN();
            lights.push_back(light);if(light.is_ahead)selected.push_back(light);
        }
        groups=group(selected);
        std::sort(lights.begin(),lights.end(),[](const auto& a,const auto& b){return a.box.x+a.box.width/2<b.box.x+b.box.width/2;});
        bool same=!groups.empty() && groups.size()==previousGroups.size();
        for(size_t i=0;same && i<groups.size();++i) {
            const auto& a=groups[i].box;const auto& b=previousGroups[i].box;
            const double displacement=std::hypot(a.x+a.width/2-b.x-b.width/2,a.y+a.height/2-b.y-b.height/2);
            same=displacement<=std::max(8.,std::max(std::hypot(a.width,a.height),std::hypot(b.width,b.height))*.6);
        }
        stableCount=same?stableCount+1:groups.empty()?0:1;previousGroups=groups;
    }
    void requestSignal(ads_lane_rules::Signal signal,qint64 now){
        signalController.set_callback([this](ads_lane_rules::Signal value){signalState=value;});
        signalController.request(signal,5000,std::uint64_t(now));
    }
    int navigation(const ads_nav::Sample& sample,const QString& source,bool enabled,qint64 now) {
        navSignal=navigationSignal.update(source,sample.generation,sample.continuity,enabled,
            sample.published,sample.captured,sample.meters,sample.directions,now);
        return navSignal;
    }
    const lane_arbitration::Snapshot& lastLaneScene()const{return cachedLane;}
    const tl_temporal::Scene& lastTrafficScene()const{return cachedTraffic;}
    QString update(qint64 now,bool wantJson=true){
        signalController.update(std::uint64_t(now));
        const auto fresh=[now](qint64 at){return at>=0 && now>=at && now-at<=500;};
        const bool laneFresh=fresh(laneAt),detFresh=fresh(lightAt),motionFresh=fresh(motionAt)&&vehicleValid;
        cachedLane=laneEngine.snapshot(now);const auto& structured=cachedLane;
        laneEvidence=driving_visual::lanes(structured);
        const bool geometry=laneFresh&&laneEvidence.egoValid;
        const bool coherent=laneFresh&&detFresh&&std::abs(laneAt-lightAt)<=250;
        // 路口接近证据：前方标线刚消失，或斑马线横向宽度骤降（阈值见 intersection_evidence.h）。
        bool laneMarksPresent=false;
        if(laneFresh)for(int c=1;c<=6;++c)if(markingCounts[c]>0){laneMarksPresent=true;break;}
        const auto& junction=intersection.update(now,laneFresh&&laneMarksPresent,
                                                 laneFresh?crosswalkSpanPx:0.0);
        QJsonArray visible,rawLights,groupLights;
        if(wantJson&&laneFresh)for(int c=1;c<=8;++c)if(markingCounts[c]>0)visible.append(c);
        if(wantJson&&detFresh)for(const auto& light:lights)rawLights.append(lightJson(light));
        if(wantJson&&detFresh)for(const auto& light:groups)groupLights.append(lightJson(light));
        const bool setConfirmed=!aheadRegion.isEmpty() && stableCount>=3 && detFresh && groups.size()<=3;
        auto permission=traffic.evaluateCount(detFresh?groups:std::vector<ads_traffic_rules::TrafficLight>{},now,setConfirmed);
        QJsonArray temporalJson,temporalDisplay,temporalGroups;bool temporalComplete=false;int temporalAhead=0;
        cachedTraffic=lightEngine.snapshot(now);
        if(temporalLights) {
            const auto& scene=cachedTraffic;std::vector<ads_traffic_rules::ConfirmedGroup> evidence(static_cast<size_t>(expectedLights));
            for(const auto& t:scene.tracks) {
                const bool ahead=aheadRegion.contains(QPointF((t.x1+t.x2)*.5,(t.y1+t.y2)*.5));
                int slot=-1;for(int i=0;i<expectedLights;++i)if(lightTopology.groupIds[size_t(i)]==t.id)slot=i;
                if(wantJson)temporalJson.append(QJsonObject{{"id",QString::number(t.id)},{"x",t.x1},{"y",t.y1},
                    {"w",t.x2-t.x1},{"h",t.y2-t.y1},{"scores",QJsonArray{t.scores[0],t.scores[1],t.scores[2]}},
                    {"confirmed",t.confirmed},{"observed",t.observed},{"color",t.color},{"conflict",t.conflict},
                    {"age_ms",double(now-t.lastSeen)},{"ahead",ahead},{"slot",slot}});
                if(t.confirmed) {
                    if(wantJson)temporalDisplay.append(QJsonObject{{"id",QString::number(t.id)},{"color",t.color},
                        {"is_ahead",ahead},{"current",t.observed&&t.color>0},{"conflict",t.conflict},
                        {"confidence",t.score()},{"timestamp_ms",double(t.lastSeen)}});
                    if(ahead)++temporalAhead;
                }
                if(slot>=0&&ahead)evidence[size_t(slot)]={{t.x1,t.y1,t.x2-t.x1,t.y2-t.y1},
                    static_cast<ads_traffic_rules::LightColor>(t.color),t.confirmed,t.observed,t.lastColor};
            }
            temporalComplete=lightMapping&&!aheadRegion.isEmpty()&&expectedLights>0;
            permission=traffic.evaluateConfirmed(evidence,now,temporalComplete);
            if(wantJson)for(int i=0;i<expectedLights;++i) {
                const auto& e=evidence[size_t(i)];
                temporalGroups.append(QJsonObject{{"slot",i},{"id",QString::number(lightTopology.groupIds[size_t(i)])},
                    {"color",e.current?int(e.color):0},{"current",e.current},{"confirmed",e.confirmed},
                    {"mapping_confirmed",temporalComplete},{"timestamp_ms",double(e.captured_ms)}});
            }
        }
        // 提前决策：接近路口时，用当前已确认的灯色给出"停/行"。
        // 灯色未知时保持 unknown，绝不因为"接近路口"而假设可以通行。
        QString stopPlan=QStringLiteral("unknown"),stopPlanReason;
        if(junction.approach) {
            const int lightColor=int(permission.traffic_light_color);
            if(lightColor==int(ads_traffic_rules::LightColor::Red)||
               lightColor==int(ads_traffic_rules::LightColor::Yellow)) {
                stopPlan=QStringLiteral("stop");
                stopPlanReason=QStringLiteral("接近路口，前方信号禁止通行");
            } else if(lightColor==int(ads_traffic_rules::LightColor::Green)) {
                stopPlan=QStringLiteral("go");
                stopPlanReason=QStringLiteral("接近路口，前方信号允许通行");
            } else {
                stopPlanReason=QStringLiteral("接近路口，信号未确认");
            }
        }
        struct Side {int decision;QString reason;QJsonObject json;};
        const auto laneSide=[&](bool isLeft)->Side{
            using namespace ads_lane_rules;
            const int index=isLeft?laneEvidence.left:laneEvidence.right;
            const int type=laneFresh?laneEvidence.hintCategory(index):0;
            const bool sideGeometry=type>0;
            const bool crossingNear=laneFresh&&laneEvidence.usable(index);
            const auto boundaryRule=assess_boundary(sideGeometry,static_cast<LaneMarking>(type));
            const bool adjacent=geometry&&(isLeft?laneEvidence.leftAdjacent:laneEvidence.rightAdjacent);
            const bool occupied=coherent&&driving_visual::occupied(laneEvidence,objects,isLeft);
            LaneChangeInput input;input.request=isLeft?Request::LEFT:Request::RIGHT;
            input.left={laneEvidence.leftAdjacent,geometry,static_cast<LaneMarking>(geometry?laneEvidence.category(laneEvidence.left):0)};
            input.right={laneEvidence.rightAdjacent,geometry,static_cast<LaneMarking>(geometry?laneEvidence.category(laneEvidence.right):0)};
            input.vehicle_state_valid=motionFresh;input.lane_centered=geometry&&laneEvidence.centered;
            input.changing_lane=changingLane;input.crossing_tracked=crossingTracked;input.target_lane_reached=targetReached;
            // Seeing a blocking object is positive evidence. No object in a
            // forward-only frame cannot establish that side/rear traffic is clear.
            input.traffic_known=occupied;input.traffic_clear=false;
            const auto fullDecision=evaluate(input);
            // Temporary user-selected display rule: each side is independent.
            // Keep fullDecision separately; the display hint is line-type only.
            const auto summary=boundaryRule==BoundaryPermission::SOLID_FORBIDDEN?Decision::SOLID_FORBIDDEN:
                boundaryRule==BoundaryPermission::DASHED_CONDITIONAL?Decision::ALLOWED:Decision::UNKNOWN;
            QString reason;
            if(!laneFresh)reason="车道证据过期";
            else if(!sideGeometry)reason="本侧边界缺失、线型待确认或冲突";
            else if(boundaryRule==BoundaryPermission::SOLID_FORBIDDEN)reason="本侧实线禁止跨越";
            else if(boundaryRule==BoundaryPermission::DASHED_CONDITIONAL)reason="本侧虚线，可变道（线型提示，交通未确认）";
            else reason="边界类别不明确";
            if(!wantJson)return {int(summary),reason,{}};
            return {int(summary),reason,QJsonObject{{"category",type},{"boundary_permission",int(boundaryRule)},
                {"crossing_near_valid",crossingNear},{"crossing_category",crossingNear?laneEvidence.category(index):0},
                {"evidence_region",!sideGeometry?"unknown":crossingNear?"fixed_near":"nearest_visible"},
                {"geometry_valid",sideGeometry},{"adjacent_lane_observed",adjacent},{"front_occupied",occupied},
                {"traffic_clear_known",false},{"full_decision",int(fullDecision)},{"decision",int(summary)},
                {"display_policy","line_type_only"},
                {"reason",reason}}};
        };
        const auto left=laneSide(true),right=laneSide(false);
        QString lightReason;
        if(!detFresh)lightReason="灯检测证据过期";
        else if(aheadRegion.isEmpty())lightReason=QString("已识别%1盏灯，正前方归属未确认").arg(lights.size());
        else if(groups.empty())lightReason="正前方区域内未检测到有效灯组";
        else if(groups.size()>3)lightReason="超过三组，计数规则无法判定";
        else if(stableCount<3)lightReason="灯组位置及数量尚未稳定";
        else lightReason="按正前方灯组计数规则评估";
        if(temporalLights)lightReason=aheadRegion.isEmpty()?QStringLiteral("请设置正前方灯区"):
            expectedLights==0?QStringLiteral("请确认实际灯组数，颜色仅作观测"):
            !temporalComplete?QStringLiteral("灯组身份/数量待确认"):
            QStringLiteral("按固定灯组与当前灯色评估，暂失/冲突为未知");
        QJsonArray structuredLines;
        if(wantJson)for(const auto& track:structured.tracks) {
            QJsonArray segments;
            for(const auto& segment:track.segments)segments.append(QJsonObject{{"category",segment.type},
                {"support",segment.support},{"margin",segment.margin},{"conflict",segment.conflict}});
            structuredLines.append(QJsonObject{{"id",QString::number(track.id)},{"slot",track.slot},
                {"observed",track.observed},{"far_ambiguous",track.farAmbiguous},{"near_x",track.x},{"segments",segments},
                {"visible_near",QJsonObject{{"category",track.visibleNear.type},{"samples",track.visibleNear.samples},
                    {"support",track.visibleNear.support},{"conflict",track.visibleNear.conflict}}},
                {"display_category",track.displayType},{"display_state",int(track.displayState)},
                {"min_y",track.minY},{"max_y",track.maxY},{"near_samples",track.segments[0].samples},
                {"layout_x",track.layoutX},{"display_supported_ms",double(track.displaySupportedMs)}});
        }
        if(wantJson){
        QJsonObject state{{"left_change",left.decision},{"right_change",right.decision},
            {"traffic_temporal",temporalLights},{"traffic_tracks",temporalJson},{"expected_light_groups",expectedLights},
            {"traffic_mapping_confirmed",temporalComplete},
            {"lane_tracks",structuredLines},{"lane_arbitration","near_seed_segmented_temporal"},
            {"lane_change_policy","line_type_only"},
            {"left_boundary",left.json},{"right_boundary",right.json},
            {"left",int(permission.left)},{"straight",int(permission.straight)},
            {"right",int(permission.right)},{"uturn",int(permission.uturn)},
            {"visible_markings",visible},{"crosswalk_observed",laneFresh&&markingCounts[8]>0},
            {"crosswalk_span_px",junction.crosswalkSpanPx},{"crosswalk_peak_px",junction.crosswalkPeakPx},
            {"intersection_approach",junction.approach},
            {"intersection_markings_lost",junction.markingsLost},
            {"intersection_crosswalk_narrowed",junction.crosswalkNarrowed},
            {"intersection_reason",junction.reason},
            {"stop_plan",stopPlan},{"stop_plan_reason",stopPlanReason},
            {"detected_lights",temporalLights?temporalDisplay.size():detFresh?int(lights.size()):0},{"rejected_lights",detFresh?rejectedLights:0},
            {"observed_lights",temporalLights?temporalAhead:detFresh?int(groups.size()):0},
            {"light_detections",temporalLights?temporalDisplay:rawLights},{"raw_model_lights",rawLights},
            {"light_groups",temporalLights?temporalGroups:groupLights},{"raw_model_light_groups",groupLights},
            {"aeb_trajectory",aebBatch},
            {"signal",navSignal?navSignal:int(signalState)},{"navigation_signal",navSignal},{"timestamp_ms",double(now)},
            {"ahead_roi_configured",!aheadRegion.isEmpty()},{"lights_stable",temporalLights?temporalComplete:setConfirmed},
            {"lane_fresh",laneFresh},{"lights_fresh",detFresh},{"lane_geometry_valid",geometry},
            {"lane_centered_observed",geometry&&laneEvidence.centered},{"objects_coherent",coherent},
            {"lane_age_ms",laneAt<0?-1:double(now-laneAt)},{"detection_age_ms",lightAt<0?-1:double(now-lightAt)},
            {"light_reason",lightReason},{"vehicle_state_valid",motionFresh},{"evidence_complete",false}};
        if(callback)callback(state);
        }
        const auto label=[](ads_traffic_rules::Permission p){return p==ads_traffic_rules::Permission::Allowed?"允许":p==ads_traffic_rules::Permission::Stop?"停止":"未知";};
        return QString("ADAS：左%1 / 直%2 / 右%3 · 灯%4/前方组%5 · 左%6 / 右%7")
            .arg(label(permission.left)).arg(label(permission.straight)).arg(label(permission.right))
            .arg(detFresh?int(lights.size()):0).arg(detFresh?int(groups.size()):0)
            .arg(left.reason,right.reason);
    }
private:
    QJsonObject aebBatch,aebConfig;
    navigation_signal::Engine navigationSignal;int navSignal=0;
    static QJsonObject lightJson(const ads_traffic_rules::TrafficLight& light){
        return {{"x",light.box.x},{"y",light.box.y},{"w",light.box.width},{"h",light.box.height},
            {"color",int(light.color)},{"confidence",light.confidence},{"is_ahead",light.is_ahead},
            {"timestamp_ms",double(light.timestamp_ms)}};
    }
    static double iou(const ads_traffic_rules::Box& a,const ads_traffic_rules::Box& b){
        const double width=std::max(0.,std::min(a.x+a.width,b.x+b.width)-std::max(a.x,b.x));
        const double height=std::max(0.,std::min(a.y+a.height,b.y+b.height)-std::max(a.y,b.y));
        const double overlap=width*height;return overlap/std::max(1.,a.width*a.height+b.width*b.height-overlap);
    }
    static std::vector<ads_traffic_rules::TrafficLight> group(const std::vector<ads_traffic_rules::TrafficLight>& input){
        std::vector<ads_traffic_rules::TrafficLight> result;
        for(const auto& light:input){
            auto match=std::find_if(result.begin(),result.end(),[&](const auto& item){return iou(item.box,light.box)>=.5;});
            if(match==result.end())result.push_back(light);
            else if(match->color!=light.color)match->color=ads_traffic_rules::LightColor::Unknown;
        }
        std::sort(result.begin(),result.end(),[](const auto& a,const auto& b){return a.box.x+a.box.width/2<b.box.x+b.box.width/2;});
        return result;
    }
    lane_arbitration::Snapshot cachedLane;tl_temporal::Scene cachedTraffic;
    Callback callback;QRectF aheadRegion;
    int stableCount=0,rejectedLights=0;
    qint64 laneAt=-1,lightAt=-1,motionAt=-1;
    bool vehicleValid=false,changingLane=false,crossingTracked=false,targetReached=false;
    std::array<int,9> markingCounts{};driving_visual::LaneEvidence laneEvidence;
    intersection_evidence::Engine intersection;double crosswalkSpanPx=0;
    lane_arbitration::Engine laneEngine;
    tl_temporal::Engine lightEngine;tl_temporal::Topology lightTopology;tl_temporal::Scene lightScene;
    bool temporalLights=false,lightMapping=false;int expectedLights=0;
    QVector<Detection> objects;
    std::vector<ads_traffic_rules::TrafficLight> lights,groups,previousGroups;
    ads_traffic_rules::TrafficPermission traffic;ads_lane_rules::SignalController signalController;
    ads_lane_rules::Signal signalState=ads_lane_rules::Signal::OFF;
};
