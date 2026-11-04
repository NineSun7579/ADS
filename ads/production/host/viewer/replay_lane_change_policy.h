#pragma once
#include "vehicle_action_state.h"
#include <QMap>
#include <QVariant>

// Display sandbox only. Archive requests and the live 4 m FSM are not inputs.
namespace replay_lane_change {
struct Decision { bool violation=false,emergency=false,allowed=false; };
inline Decision evaluate(const vehicle_action::Input& in,int direction) {
    Decision out;
    if(!in.recognition||(direction!=-1&&direction!=1)||
       in.evidence["timestamp_ms"].toDouble(-1)!=double(in.now))return out;
    const QString name=direction<0?QStringLiteral("left"):QStringLiteral("right");
    QJsonObject owner;
    for(const auto& value:in.evidence["replay_lane_change_sources"].toArray()) {
        const auto origin=value.toObject();
        if(origin["suite"].toString()==QStringLiteral("t2")&&
           origin["variant"].toString()==name&&origin["now_ms"].toDouble(-1)==double(in.now))owner=origin;
    }
    if(owner.isEmpty())return out;
    const auto side=in.evidence[name+QStringLiteral("_boundary")].toObject();
    const auto freshAge=[&](const char* key) {
        const double age=owner[key].toDouble(-1);
        return std::isfinite(age)&&age>=0&&age<=500;
    };
    const bool laneFresh=owner["lane_fresh"].toBool()&&freshAge("lane_age_ms");
    const int category=side["crossing_category"].toInt();
    const bool lineKnown=laneFresh&&side["crossing_near_valid"].toBool();
    out.violation=lineKnown&&category>=1&&category<=4;
    const bool detectionFresh=freshAge("detection_age_ms");
    const double meters=side["nearest_vehicle_m"].toDouble(-1);
    const bool distanceKnown=detectionFresh&&std::isfinite(meters)&&meters>0;
    out.emergency=distanceKnown&&meters<5.0;
    // Explicit scenario context is not inferred from a missing adjacent line.
    const auto topology=in.evidence["replay_lane_topology"].toObject();
    const bool context=topology["source"].toString()==QStringLiteral("user_configured_scenario")&&
        topology["timestamp_ms"].toDouble(-1)==double(in.now);
    const bool leftEdge=context&&topology["leftmost_confirmed"].toBool()&&topology["leftmost"].toBool();
    if(direction<0&&leftEdge)out.emergency=true;
    const bool targetExists=laneFresh&&(side["adjacent_lane_observed"].toBool()||
        (context&&(direction>0?topology["right_emergency_lane"].toBool():
            topology["leftmost_confirmed"].toBool()&&!topology["leftmost"].toBool())));
    const bool trafficClear=detectionFresh&&(distanceKnown?meters>=5.0:
        side["traffic_clear_known"].toBool()&&!side["front_occupied"].toBool());
    out.allowed=!out.violation&&!out.emergency&&targetExists&&lineKnown&&
        (category==5||category==6)&&trafficClear;
    return out;
}
class Policy {
    qint64 violationAt=-1,emergencyAt=-1,allowedAt=-1;
    int allowedDirection=0;
    static bool lit(qint64 start,qint64 wall,int pulses=2) {
        const qint64 elapsed=wall-start;
        // Two 400 ms on intervals, each followed by 400 ms off.
        return start>=0&&elapsed>=0&&elapsed<pulses*800&&(elapsed/400)%2==0;
    }
public:
    qint64 wallNow=0;
    void click(const vehicle_action::Input& in,int direction) {
        const auto result=evaluate(in,direction);
        allowedAt=result.allowed?wallNow:-1;
        allowedDirection=result.allowed?direction:0;
        if(result.violation)violationAt=wallNow;
        if(result.emergency)emergencyAt=wallNow;
    }
    void render(const vehicle_action::Input& in,QMap<QString,QVariant>& values) const {
        const QString keys[]={QStringLiteral("ui.predictionLeft"),QStringLiteral("ui.predictionStraight"),
            QStringLiteral("ui.predictionRight"),QStringLiteral("ui.predictionViolation"),
            QStringLiteral("ui.predictionEmergency"),QStringLiteral("ui.predictionStop")};
        for(const auto& key:keys){values[key]=QStringLiteral("normal");values.remove(key+QStringLiteral(".blink"));}
        if(in.changeRequest==allowedDirection&&evaluate(in,in.changeRequest).allowed&&
           lit(allowedAt,wallNow,3))
            values[keys[in.changeRequest+1]]=QStringLiteral("active");
        if(lit(violationAt,wallNow))values[keys[3]]=QStringLiteral("warning");
        if(lit(emergencyAt,wallNow))values[keys[4]]=QStringLiteral("warning");
    }
};
}
