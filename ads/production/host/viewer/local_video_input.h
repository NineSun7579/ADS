#pragma once
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStringList>

namespace local_video {
struct Selection { QString path; bool loop=true; QString error; };
inline QString directory() {
    return qEnvironmentVariable("ADS_VIDEO_DIR","/userdata/ads/videos");
}
inline QString configPath() {
    return qEnvironmentVariable("ADS_LOCAL_VIDEO_CONFIG","/userdata/ads/local-video.json");
}
inline bool playableFile(const QString& path) {
    const QFileInfo file(path);
    const QStringList extensions={"mp4","mkv","avi","mov","m4v","ts","webm","mpeg","mpg"};
    return file.isFile() && file.isReadable() && extensions.contains(file.suffix().toLower());
}
inline QStringList files() {
    QStringList result;
    const auto entries=QDir(directory()).entryInfoList(QDir::Files|QDir::Readable,QDir::Name|QDir::IgnoreCase);
    for(const auto& file:entries) if(playableFile(file.absoluteFilePath())) {
        result.append(file.absoluteFilePath());
        if(result.size()==200) break;
    }
    return result;
}
inline Selection load() {
    Selection result;
    QFile file(configPath());
    if(!file.exists()) return result;
    if(!file.open(QIODevice::ReadOnly) || file.size()>16384) { result.error="本地视频配置无法读取";return result; }
    QJsonParseError error;
    const auto doc=QJsonDocument::fromJson(file.readAll(),&error);
    if(error.error!=QJsonParseError::NoError || !doc.isObject()) { result.error="本地视频配置格式无效";return result; }
    const auto object=doc.object();
    result.loop=object.value("loop").toBool(true);
    if(!object.value("enabled").toBool(false)) return result;
    const QString path=object.value("path").toString();
    if(!playableFile(path)) { result.error="本地视频不存在或不可读取，已恢复相机输入";return result; }
    result.path=QFileInfo(path).absoluteFilePath();
    return result;
}
inline bool save(const QString& path,bool loop,QString& error) {
    if(!path.isEmpty() && !playableFile(path)) { error="视频不存在或格式不支持";return false; }
    if(!QDir().mkpath(QFileInfo(configPath()).absolutePath())) { error="视频配置目录不可写";return false; }
    QSaveFile file(configPath());
    if(!file.open(QIODevice::WriteOnly)) { error="视频配置不可写";return false; }
    const QByteArray bytes=QJsonDocument(QJsonObject{{"enabled",!path.isEmpty()},
        {"path",path.isEmpty()?QString():QFileInfo(path).absoluteFilePath()},{"loop",loop}}).toJson();
    if(file.write(bytes)!=bytes.size() || !file.commit()) { error="保存视频选择失败";return false; }
    return true;
}
} // namespace local_video
