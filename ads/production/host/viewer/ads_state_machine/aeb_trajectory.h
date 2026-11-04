#pragma once
#include <QJsonObject>
#include <QJsonArray>
#include <QString>
#include <deque>
#include <map>
#include <algorithm>
#include <cmath>
#include <limits>

// Experimental advisory risk producer. Inputs are measured target kinematics,
// never a caller-supplied collision boolean. Coordinates follow the ego path:
// x rightwards, z forwards; negative vz means closing. Straight camera-aligned
// ego path only. Ground reconstruction is identical to replay_motion BEV.
namespace aeb_trajectory {
inline double number(const QJsonObject& o,const char* key) {
    return o[key].isDouble()?o[key].toDouble():std::numeric_limits<double>::quiet_NaN();
}
struct Config {
    double horizonS=3.,closingMps=3.,halfWidthM=1.2,depthM=3.;
    QJsonObject json()const{return {{"horizon_s",horizonS},{"closing_mps",closingMps},
        {"half_width_m",halfWidthM},{"depth_m",depthM}};}
    static Config read(const QJsonObject& o) {
        Config c;
        if(o.contains("horizon_s"))c.horizonS=number(o,"horizon_s");
        if(o.contains("closing_mps"))c.closingMps=number(o,"closing_mps");
        if(o.contains("half_width_m"))c.halfWidthM=number(o,"half_width_m");
        if(o.contains("depth_m"))c.depthM=number(o,"depth_m");
        return c;
    }
    bool valid()const{return std::isfinite(horizonS)&&horizonS>0&&horizonS<=10&&
        std::isfinite(closingMps)&&closingMps>0&&std::isfinite(halfWidthM)&&halfWidthM>0&&
        std::isfinite(depthM)&&depthM>0;}
};
struct Assessment {bool risk=false;QJsonObject audit;};
class Engine {
    struct Point {double t,cx,foot;};
    struct Track {std::deque<Point> points;};
    std::map<QString,Track> tracks;
    QString activeSource;
    qint64 lastNow=-1;
    static bool interval(double p,double v,double lo,double hi,double& enter,double& leave) {
        if(std::abs(v)<1e-9)return p>=lo&&p<=hi;
        double a=(lo-p)/v,b=(hi-p)/v;
        if(a>b)std::swap(a,b);
        enter=std::max(enter,a);leave=std::min(leave,b);return enter<=leave;
    }
public:
    void reset(){tracks.clear();lastNow=-1;activeSource.clear();}
    Assessment update(const QJsonObject& batch,qint64 now,bool enabled=true) {
        if(lastNow>=0&&now<lastNow)reset();
        lastNow=now;
        Assessment result;const auto cfg=Config::read(batch["config"].toObject());
        result.audit={{"risk",false},{"config",cfg.json()},{"path_model","camera_aligned_straight_constant_velocity"},
            {"targets",QJsonArray{}}};
        if(!enabled){reset();result.audit["reason"]="recognition_disabled";return result;}
        if(!cfg.valid()){reset();result.audit["reason"]="invalid_config";return result;}
        const auto fresh=[now](double stamp){return std::isfinite(stamp)&&stamp>0&&now>=stamp&&now-stamp<=500;};
        for(auto it=tracks.begin();it!=tracks.end();) {
            if(it->second.points.empty()||now-it->second.points.back().t>1500)it=tracks.erase(it);else ++it;
        }
        if(!fresh(number(batch,"captured_ms"))){result.audit["reason"]="missing_or_stale_batch";return result;}
        const QString source=batch["source"].toString();
        const double generation=number(batch,"generation"),continuity=number(batch,"continuity");
        if(source.isEmpty()||!std::isfinite(generation)||!std::isfinite(continuity)) {
            result.audit["reason"]="missing_source_identity";return result;
        }
        const QString currentSource=source+":"+QString::number(generation,'g',17)+":"+QString::number(continuity,'g',17);
        if(currentSource!=activeSource){tracks.clear();activeSource=currentSource;}
        QJsonArray diagnostics;
        for(const auto& value:batch["targets"].toArray()) {
            const auto o=value.toObject();QJsonObject d{{"id",o["id"]},{"risk",false}};
            const QString id=o["id"].toString();
            const QString key=currentSource+":"+id;
            const int cls=o["class_id"].toInt(-1);
            const double at=number(o,"observed_ms"),geometry=number(o,"geometry_ms");
            const double cx=number(o,"cx_px"),foot=number(o,"foot_px");
            const double A=number(o,"A"),vh=number(o,"vh"),hc=number(o,"hc");
            const double z=A/(foot-vh),x=(cx-320.)*hc/(foot-vh),vz=number(o,"vz_mps");
            QString reason;
            if(id.isEmpty()||id=="0"||!((cls>=0&&cls<=2)||cls==6))reason="identity_or_class";
            else if(o["predicted"].toBool()||!fresh(at))reason="not_fresh_observation";
            else if(!fresh(geometry)||!std::isfinite(A)||A<=1||!std::isfinite(hc)||hc<=0||
                !std::isfinite(vh)||!std::isfinite(foot)||foot-vh<=5||!std::isfinite(z)||z<=0||
                o["distance_grade"].toInt()<=0||o["distance_method"].toInt()!=1)reason="ground_geometry_unknown";
            else if(!std::isfinite(cx)||!std::isfinite(x))reason="lateral_position_unknown";
            if(!reason.isEmpty()) {
                tracks.erase(key);d["reason"]=reason;diagnostics.append(d);continue;
            }
            auto& history=tracks[key].points;
            d["x_m"]=x;d["z_m"]=z;
            if(!history.empty()&&(at<history.back().t||at-history.back().t>1000))history.clear();
            if(history.empty()||at>history.back().t)history.push_back({at,cx,foot});
            while(history.size()>1&&at-history.front().t>1500)history.pop_front();
            d["samples"]=int(history.size());
            const double span=history.empty()?0:(at-history.front().t)/1000.;d["span_s"]=span;
            if(!o["velocity_valid"].toBool()||!std::isfinite(vz))reason="relative_velocity_unknown";
            else if(-vz<=cfg.closingMps)reason="closing_speed_below_threshold";
            else if(history.size()<4||span<.6-1e-9)reason="lateral_motion_warmup";
            else {
                double meanT=0,meanX=0;
                bool usable=true;
                for(const auto& p:history){meanT+=(p.t-at)/1000.;
                    if(p.foot-vh<=5){usable=false;break;}
                    meanX+=(p.cx-320.)*hc/(p.foot-vh);}
                if(!usable){history.clear();d["reason"]="history_geometry_invalid";diagnostics.append(d);continue;}
                meanT/=history.size();meanX/=history.size();
                double xx=0,xy=0;
                for(const auto& p:history){const double t=(p.t-at)/1000.-meanT;xx+=t*t;xy+=t*((p.cx-320.)*hc/(p.foot-vh)-meanX);}
                const double vx=xx>0?xy/xx:std::numeric_limits<double>::quiet_NaN();
                d["vx_mps"]=vx;d["vz_mps"]=vz;d["x_m"]=x;d["z_m"]=z;
                d["relative_speed_mps"]=std::hypot(vx,vz);
                double enter=0,leave=cfg.horizonS;
                const bool conflict=std::isfinite(vx)&&
                    interval(x,vx,-cfg.halfWidthM,cfg.halfWidthM,enter,leave)&&
                    interval(z,vz,0,cfg.depthM,enter,leave)&&enter<=leave&&leave>=0;
                if(conflict) {
                    d["risk"]=true;d["conflict_enter_s"]=enter;d["conflict_exit_s"]=leave;
                    result.risk=true;reason="trajectory_conflict_and_fast_closing";
                } else reason="no_simultaneous_path_conflict";
            }
            d["reason"]=reason;diagnostics.append(d);
        }
        result.audit["targets"]=diagnostics;result.audit["risk"]=result.risk;
        result.audit["reason"]=result.risk?"trajectory_conflict_and_fast_closing":"no_confirmed_trajectory_risk";
        return result;
    }
};
}
