#pragma once
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QFileInfo>
namespace viewer_controls {
struct Settings {bool recognition=true,confidence=true,distance=true,intent=true,laneOutput=true,objectOutput=true;};
inline QString path(){return qEnvironmentVariable("ADS_VIEWER_CONTROLS",QStringLiteral("/userdata/ads/viewer-controls.json"));}
inline QJsonObject json(const Settings& s){return {{"recognition",s.recognition},{"confidence",s.confidence},{"distance",s.distance},{"intent",s.intent},{"lane_output",s.laneOutput},{"object_output",s.objectOutput}};}
inline Settings load() {
    Settings s;QFile file(path());if(!file.open(QIODevice::ReadOnly))return s;
    const auto o=QJsonDocument::fromJson(file.readAll()).object();
    const auto value=[&](const char* key){return o[key].isBool()?o[key].toBool():true;};
    s.recognition=value("recognition");s.confidence=value("confidence");s.distance=value("distance");s.intent=value("intent");s.laneOutput=value("lane_output");s.objectOutput=value("object_output");return s;
}
inline bool save(const Settings& s,QString& error) {
    if(!QDir().mkpath(QFileInfo(path()).absolutePath())){error="无法创建显示设置目录";return false;}
    QSaveFile file(path());const auto data=QJsonDocument(json(s)).toJson();
    if(!file.open(QIODevice::WriteOnly)||file.write(data)!=data.size()||!file.commit()){error="无法保存识别/显示设置："+file.errorString();return false;}
    return true;
}
inline bool toggle(Settings& s,int index) {
    switch(index){case 0:s.recognition=!s.recognition;break;case 1:s.confidence=!s.confidence;break;
    case 2:s.distance=!s.distance;break;case 3:s.intent=!s.intent;break;case 5:s.laneOutput=!s.laneOutput;break;case 6:s.objectOutput=!s.objectOutput;break;default:return false;}return true;
}
} // namespace viewer_controls
