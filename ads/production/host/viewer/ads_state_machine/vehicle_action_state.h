#pragma once
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <array>
#include <algorithm>
#include <cmath>
#include "aeb_trajectory.h"

// Request/advisory state only; never a physical vehicle command. Raw objects,
// navigation, rough ranges and aeb_warning cannot verify an emergency.
namespace vehicle_action {
enum class Color { Gray, Yellow, Green, Red };
struct Card { Color color=Color::Gray; QString reason=QStringLiteral("未请求"); };
struct Result {
    QJsonObject aeb;
    std::array<Card,5> cards;
    QString state=QStringLiteral("Stopped"),reason=QStringLiteral("停止请求"),action=QStringLiteral("none");
    QJsonObject json() const {
        QJsonArray values;
        for(const auto& c:cards)values.append(QJsonObject{{"color",int(c.color)},{"reason",c.reason}});
        return {{"state",state},{"action",action},{"reason",reason},{"cards",values},{"aeb",aeb}};
    }
};
struct Input {
    bool requested=false,recognition=true;
    int assumedLane=0,changeRequest=0;
    qint64 now=0;
    QJsonObject evidence;
    // Future verified producer API; deliberately never read from JSON.
    bool verifiedRisk=false;
    QString riskEvidence;
};
inline qint64 age(const Input& in,const char* field) {
    const double base=in.evidence[field].toDouble(-1);
    const double update=in.evidence["timestamp_ms"].toDouble(-1);
    if(base<0||update<0||in.now<update)return -1;
    return qint64(base)+in.now-qint64(update);
}
inline bool fresh(qint64 value){return value>=0&&value<=500;}
constexpr double LaneChangeLimitM=4.0;
inline bool laneChangeDistanceBlocked(double meters){return std::isfinite(meters)&&meters>0&&meters<=LaneChangeLimitM;}
// Detection freshness cannot refresh the captured color of a mapped group.
inline bool permissionEvidenceFresh(const Input& in) {
    const auto groups=in.evidence["light_groups"].toArray();
    const bool temporal=in.evidence["traffic_temporal"].toBool();
    const int count=groups.size();
    if(count<1||count>3)return false;
    std::array<QJsonObject,3> mappedGroups;
    if(temporal) {
        if(!in.evidence["traffic_mapping_confirmed"].toBool()||
           in.evidence["expected_light_groups"].toInt()!=count)return false;
        for(const auto& value:groups) {
            const auto group=value.toObject();const int slot=group["slot"].toInt(-1);
            if(slot<0||slot>=count||!mappedGroups[slot].isEmpty())return false;
            mappedGroups[slot]=group;
        }
    } else for(int i=0;i<count;++i)mappedGroups[i]=groups[i].toObject();
    const auto valid=[&](int slot) {
        const auto& g=mappedGroups[slot];const double stamp=g["timestamp_ms"].toDouble(-1);
        const int color=g["color"].toInt();
        if(stamp<0||in.now<stamp||in.now-stamp>500||color<1||color>3)return false;
        return temporal?g["confirmed"].toBool()&&g["current"].toBool()&&g["mapping_confirmed"].toBool():
            g["is_ahead"].toBool();
    };
    // A confirmed one/two-group topology leaves right turns unrestricted by
    // these lights. Missing colors do not invent a third right-turn signal.
    if(in.assumedLane>0&&count<3)return true;
    if(!temporal) {
        for(int i=0;i<count;++i)if(!valid(i))return false;
        return true;
    }
    return valid(in.assumedLane<0?0:in.assumedLane>0?2:count==1?0:1);
}
class Engine {
public:
    void stop(const Input& in) {
        const auto risk=trajectory.update(in.evidence["aeb_trajectory"].toObject(),in.now,in.recognition);
        if(!(in.verifiedRisk&&!in.riskEvidence.isEmpty())&&!risk.risk)latched=false;
    }
    Result update(const Input& in) {
        if(in.verifiedRisk&&!in.riskEvidence.isEmpty())latched=true;
        const auto risk=trajectory.update(in.evidence["aeb_trajectory"].toObject(),in.now,in.recognition);
        if(in.requested&&risk.risk)latched=true;
        Result out;
        out.aeb=risk.audit;
        if(latched) {
            out.state="EmergencyLatched";out.action="stop";
            out.reason=QStringLiteral("紧急风险锁存，风险解除后按停止复位，再请求行驶");
            out.cards[4]={Color::Red,out.reason};return out;
        }
        if(!in.requested)return out;
        const int direction=std::max(-1,std::min(1,in.changeRequest?in.changeRequest:in.assumedLane));
        const int card=direction+1;
        out.action=in.changeRequest?(direction<0?"change_left":"change_right"):
            direction<0?"turn_left":direction>0?"turn_right":"straight";
        auto finish=[&](Color color,const QString& reason,bool violation=false) {
            out.state=violation?"RuleBlocked":color==Color::Green?"Allowed":"Waiting";
            out.reason=reason;out.cards[card]={color,reason};
            if(violation)out.cards[3]={Color::Red,reason};
            return out;
        };
        if(!in.recognition)return finish(Color::Yellow,QStringLiteral("识别已停止，等待有效证据"));
        // Stop advice is selected by the intended direction's confirmed signal,
        // independently of intersection position or a cached aggregate stop plan.
        const bool laneFresh=in.evidence["lane_fresh"].toBool()&&fresh(age(in,"lane_age_ms"));
        if(in.changeRequest) {
            const auto side=in.evidence[in.changeRequest<0?"left_boundary":"right_boundary"].toObject();
            if(!laneFresh||!side["crossing_near_valid"].toBool())
                return finish(Color::Yellow,QStringLiteral("等待待跨越边界线型证据"));
            const int category=side["crossing_category"].toInt();
            if(category>=1&&category<=4)return finish(Color::Yellow,QStringLiteral("请求跨越实线，禁止变道"),true);
            if(category!=5&&category!=6)return finish(Color::Yellow,QStringLiteral("等待可跨越边界确认"));
            if(!fresh(age(in,"detection_age_ms")))return finish(Color::Yellow,QStringLiteral("等待新鲜车辆距离证据"));
            const double meters=side["nearest_vehicle_m"].toDouble(-1);
            if(laneChangeDistanceBlocked(meters))return finish(Color::Yellow,QStringLiteral("目标车道车辆距离小于等于4米，禁止变道"));
            if(side["front_occupied"].toBool()&&!(std::isfinite(meters)&&meters>0))
                return finish(Color::Yellow,QStringLiteral("目标车道有车，等待有效距离"));
            return finish(Color::Green,QStringLiteral("虚线且无4米内车辆，允许变道（规则许可）"));
        }
        const bool lightFresh=in.evidence["lights_fresh"].toBool()&&fresh(age(in,"detection_age_ms"));
        // Turn/straight requests use signals; lane changes returned above.
        const char* permission=in.assumedLane<0?"left":in.assumedLane>0?"right":"straight";
        const int light=in.evidence[permission].toInt(0);
        const bool confirmed=lightFresh&&in.evidence["ahead_roi_configured"].toBool()&&
            in.evidence["lights_stable"].toBool()&&permissionEvidenceFresh(in);
        if(confirmed&&light==2) {
            out.action="stop";
            const QString name=in.assumedLane<0?QStringLiteral("左转"):in.assumedLane>0?QStringLiteral("右转"):QStringLiteral("直行");
            return finish(Color::Red,name+QStringLiteral("意图与信号冲突，提示停车"),true);
        }
        if(!laneFresh||!in.evidence["lane_geometry_valid"].toBool())
            return finish(Color::Yellow,QStringLiteral("等待有效车道几何证据"));
        if(!confirmed||light!=1)return finish(Color::Yellow,QStringLiteral("等待当前方向信号许可"));
        return finish(Color::Green,QStringLiteral("请求方向规则许可（非车辆运动状态）"));
    }
private:
    aeb_trajectory::Engine trajectory;
    bool latched=false;
};
} // namespace vehicle_action
