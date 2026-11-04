#pragma once
#include "vision_types.h"
#include <QMap>
#include <QRect>
#include <QString>
#include <memory>

namespace ads_nav {
constexpr qint64 LifetimeMs=1500;
struct Settings {bool enabled=false;QRect region;bool ready()const{return region.width()>=24&&region.height()>=24&&QRect(0,0,640,480).contains(region);}};
struct Configuration {int camera=6;QMap<QString,Settings> sources;}; // 6 = virtual combined HDMI input
QString configPath();
Configuration load(QString* error=nullptr);
bool save(const Configuration&,QString& error);
struct Sample {
    QString source,status,number,unit,directions;
    qint64 captured=0;quint64 frame=0,continuity=0;int generation=-1;
    double meters=-1,computeMs=0;bool published=false;
    bool fresh(qint64 now)const{return published&&captured>0&&now>=captured&&now-captured<=LifetimeMs;}
};
// All recognition, optical flow and model lifetime work stays off the GUI thread.
class Worker {
    struct Impl;std::unique_ptr<Impl> impl;
public:
    explicit Worker(QString modelDirectory={});~Worker();
    Worker(const Worker&)=delete;Worker& operator=(const Worker&)=delete;
    void configure(Configuration);
    void reset();
    void submit(const VisionFrame&,const QString& source);
    Sample latest(const QString& source)const;
};
QString display(const Sample&,qint64 now);
QString displayKey(const Sample&,qint64 now);
}
