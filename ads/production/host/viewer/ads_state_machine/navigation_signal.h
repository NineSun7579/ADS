#pragma once
#include <QString>
#include <cmath>

namespace navigation_signal {
// Advisory indicator only. Missing OCR never becomes a zero-metre reading.
class Engine {
public:
    static constexpr double TriggerM=20.0;
    static constexpr double ExitDistanceM=30.0;
    void reset(){signal_=0;nextStageStartM_=-1;lastCapture_=-1;lastNow_=-1;source_.clear();generation_=-1;continuity_=0;}
    int update(const QString& source,int generation,quint64 continuity,bool enabled,
               bool published,qint64 captured,double meters,const QString& directions,qint64 now) {
        if(!enabled){reset();return 0;}
        if(source!=source_||generation!=generation_||continuity!=continuity_||
           (lastNow_>=0&&now<lastNow_)) {
            reset();source_=source;generation_=generation;continuity_=continuity;
        }
        lastNow_=now;
        const bool valid=published&&captured>0&&now>=captured&&now-captured<=1500&&
            std::isfinite(meters)&&meters>=0;
        if(valid&&captured>lastCapture_) {
            lastCapture_=captured;
            const auto d=directions.trimmed().toLower();
            // Require one unambiguous recognised direction, never both lamps.
            const bool left=d=="left"||d=="uturn"||d=="u-turn"||d=="left_uturn";
            const bool right=d=="right";
            if(signal_) {
                // The current recognizer has no maneuver ID. A fresh distance
                // outside the approach range marks the next prompt. Keep the
                // original lamp until that prompt counts down at least 30 m.
                // Use a fixed baseline, never sum jittering distance deltas.
                if(nextStageStartM_<0) {
                    if(meters>=TriggerM)nextStageStartM_=meters;
                } else if(nextStageStartM_-meters>=ExitDistanceM) {
                    signal_=0;nextStageStartM_=-1;
                }
            } else if(meters<TriggerM&&(left||right)) {
                signal_=left?1:2;nextStageStartM_=-1;
            }
        }
        return signal_;
    }
private:
    int signal_=0,generation_=-1;quint64 continuity_=0;
    double nextStageStartM_=-1;
    qint64 lastCapture_=-1,lastNow_=-1;QString source_;
};
}
