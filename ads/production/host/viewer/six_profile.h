#pragma once

// GUI-thread-only, opt-in wall-time diagnostics. No GL synchronization or values
// are logged. Timings are CPU wall time (including driver stalls), not GPU time.
#include <QElapsedTimer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QVariant>
#include <cstdio>

namespace six_profile {
inline bool enabled() {
    static const bool on=qEnvironmentVariableIntValue("ADS_SIX_PROFILE")!=0;
    return on;
}
struct Timing {
    quint64 calls=0;
    double sum=0,max=0;
};
struct Profile {
    QElapsedTimer window;
    QMap<QString,quint64> counters;
    QMap<QString,Timing> stages;
    quint64 sequence=0;
    Profile() { window.start(); }
    void count(const QString& key,quint64 amount=1) { counters[key]+=amount; }
    void add(const QString& key,double ms) {
        auto& timing=stages[key];++timing.calls;timing.sum+=ms;
        timing.max=qMax(timing.max,ms);
    }
    void flush() {
        if(window.elapsed()<5000)return;
        QJsonObject counts,times;
        for(auto it=counters.cbegin();it!=counters.cend();++it)
            counts[it.key()]=double(it.value());
        for(auto it=stages.cbegin();it!=stages.cend();++it) {
            QJsonObject value;
            value["calls"]=double(it->calls);value["sum_ms"]=it->sum;
            value["avg_ms"]=it->calls?it->sum/it->calls:0;value["max_ms"]=it->max;
            times[it.key()]=value;
        }
        QJsonObject record;
        record["schema"]=1;record["seq"]=double(++sequence);
        record["window_ms"]=double(window.elapsed());
        record["counts"]=counts;record["stages"]=times;
        if(stages.contains(QStringLiteral("paint_exact"))) {
            record["paint_unattributed_ms"]=stages.value(QStringLiteral("paint_exact")).sum
                -stages.value(QStringLiteral("inference_raster")).sum
                -stages.value(QStringLiteral("chrome_total")).sum
                -stages.value(QStringLiteral("inference_upload")).sum;
        }
        const QByteArray json=QJsonDocument(record).toJson(QJsonDocument::Compact);
        std::fprintf(stderr,"[six-profile] %s\n",json.constData());
        counters.clear();stages.clear();window.restart();
    }
};
inline Profile& profile() { static Profile value;return value; }
inline void count(const char* key,quint64 amount=1) {
    if(enabled())profile().count(QString::fromLatin1(key),amount);
}
inline void keyed(const char* prefix,const QString& key) {
    if(enabled())profile().count(QString::fromLatin1(prefix)+key);
}
// Report input map changes separately from final visual changes. Perception and
// explicit bindings can overwrite the same key inside one visual transaction.
inline void bindingChanges(const char* prefix,const QMap<QString,QVariant>& before,
                           const QMap<QString,QVariant>& after) {
    if(!enabled())return;
    for(auto it=after.cbegin();it!=after.cend();++it)
        if(!before.contains(it.key())||before.value(it.key())!=it.value())keyed(prefix,it.key());
}
class Scope {
    const char* name_;
    bool running_;
    bool flush_;
    QElapsedTimer timer_;
public:
    explicit Scope(const char* name,bool flush=false):name_(name),running_(enabled()),flush_(flush) {
        if(running_)timer_.start();
    }
    Scope(const Scope&)=delete;
    Scope& operator=(const Scope&)=delete;
    void stop() {
        if(!running_)return;
        profile().add(QString::fromLatin1(name_),timer_.nsecsElapsed()/1e6);running_=false;
    }
    ~Scope() { stop();if(flush_&&enabled())profile().flush(); }
};
}
