#pragma once
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRectF>
#include <cmath>
namespace driving_config {
inline QString path(){return qEnvironmentVariable("ADS_RULE_CONFIG","/userdata/ads/rules-config.json");}
inline bool valid(const QRectF& r){return std::isfinite(r.x())&&std::isfinite(r.y())&&
    std::isfinite(r.width())&&std::isfinite(r.height())&&r.width()>=4&&r.height()>=4&&
    QRectF(0,0,640,640).contains(r);}
inline QRectF load(const QString& source){
    QFile file(path());if(!file.open(QIODevice::ReadOnly))return {};
    const auto a=QJsonDocument::fromJson(file.readAll()).object()["light_regions"].toObject()[source].toArray();
    if(a.size()!=4)return {};
    const QRectF r(a[0].toDouble(-1),a[1].toDouble(-1),a[2].toDouble(-1),a[3].toDouble(-1));
    return valid(r)?r:QRectF();
}
inline bool save(const QString& source,const QRectF& region,QString& error){
    if(source.isEmpty()||(!region.isEmpty()&&!valid(region))){error="灯组区域无效";return false;}
    QFile previous(path());QJsonObject config;
    if(previous.exists()) {
        if(!previous.open(QIODevice::ReadOnly)){error=previous.errorString();return false;}
        QJsonParseError parse{};const auto doc=QJsonDocument::fromJson(previous.readAll(),&parse);
        if(parse.error!=QJsonParseError::NoError||!doc.isObject()){error="规则配置损坏，未覆盖";return false;}
        config=doc.object();
    }
    auto entries=config["light_regions"].toObject();
    if(region.isEmpty())entries.remove(source);
    else entries[source]=QJsonArray{region.x(),region.y(),region.width(),region.height()};
    config["light_regions"]=entries;
    if(!QDir().mkpath(QFileInfo(path()).absolutePath())){error="无法创建规则配置目录";return false;}
    QSaveFile file(path());
    if(!file.open(QIODevice::WriteOnly)){error=file.errorString();return false;}
    const auto bytes=QJsonDocument(config).toJson();
    if(file.write(bytes)!=bytes.size()||!file.commit()){error=file.errorString();return false;}
    return true;
}
inline int loadExpected(const QString& source){
    QFile f(path());if(!f.open(QIODevice::ReadOnly))return 0;
    const int n=QJsonDocument::fromJson(f.readAll()).object()["light_group_counts"].toObject()[source].toInt();
    return n>=1&&n<=3?n:0;
}
inline bool saveExpected(const QString& source,int count,QString& error){
    if(source.isEmpty()||count<0||count>3){error="灯组数无效";return false;}
    QFile previous(path());QJsonObject config;
    if(previous.exists()){
        if(!previous.open(QIODevice::ReadOnly)){error=previous.errorString();return false;}
        QJsonParseError parse;const auto doc=QJsonDocument::fromJson(previous.readAll(),&parse);
        if(parse.error!=QJsonParseError::NoError||!doc.isObject()){error="规则配置损坏，未覆盖";return false;}
        config=doc.object();
    }
    auto counts=config["light_group_counts"].toObject();counts[source]=count;config["light_group_counts"]=counts;
    if(!QDir().mkpath(QFileInfo(path()).absolutePath())){error="无法创建规则配置目录";return false;}
    QSaveFile file(path());if(!file.open(QIODevice::WriteOnly)){error=file.errorString();return false;}
    const auto bytes=QJsonDocument(config).toJson();
    if(file.write(bytes)!=bytes.size()||!file.commit()){error=file.errorString();return false;}return true;
}
}
