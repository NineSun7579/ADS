#pragma once
#include "perception_bird.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSocketNotifier>
#include <QTimer>
#include <QElapsedTimer>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <cerrno>

namespace perception_bird {
// Loopback display feed from the network workload service. No rule-engine input.
class ReplayInput final:public QObject {
    int fd=-1;
    bool active=false;
    QElapsedTimer heartbeat;
    std::function<void(bool,const Frame&)> deliver;
public:
    static bool decode(const QJsonObject& scene,Frame& frame) {
        frame=Frame{};
        frame.source=scene["display_source"].toString();
        frame.generation=scene["display_generation"].toVariant().toString();
        if(scene["display_time_ms"].isDouble())frame.sourceTimeMs=scene["display_time_ms"].toDouble();
        if(scene["display_frame"].isDouble())frame.sourceFrame=scene["display_frame"].toDouble();
        if(!scene["lane_group_ego_slot"].isDouble())return false;
        frame.egoSlot=scene["lane_group_ego_slot"].toDouble();
        if(!std::isfinite(frame.egoSlot))return false;
        const auto coordinate=scene["bird_coordinate"].toString();
        frame.metric=coordinate=="vehicle_ground_meters";
        if(!scene["lane_slots"].isArray()||!scene["bird_objects"].isArray())return false;
        const auto lanes=scene["lane_slots"].toArray(),objects=scene["bird_objects"].toArray();
        if(lanes.size()>6||objects.size()>512)return false;
        std::array<bool,6> seen{};
        for(const auto& value:lanes) {
            const auto line=value.toObject();const int slot=line["slot"].toInt(-1),type=line["type"].toInt(-1);
            if(slot<0||slot>=6||type<0||type>6||seen[size_t(slot)])return false;
            seen[size_t(slot)]=true;frame.types[size_t(slot)]=type;
        }
        for(const auto& value:objects) {
            const auto object=value.toObject();
            // 只认明确支持的四种车辆图标。未知类别（行人、未知类型等）直接丢弃，
            // 不能因为一个无法分类的对象让整帧车道数据一起失效。
            const QString key=object["icon_key"].toString();
            const int category=key=="car"?0:key=="bus"?1:key=="truck"?2:key=="motorcycle"?6:key=="bicycle"?5:-1;
            if(category<0)continue;
            if(!object["x"].isDouble()||!object["z"].isDouble())return false;
            const double x=object["x"].toDouble(),z=object["z"].toDouble();
            if(!std::isfinite(x)||!std::isfinite(z))return false;
            Object item{x,z,category};
            const auto id=object["id"];
            if(id.isString()) {
                const auto text=id.toString().trimmed();
                if(!text.isEmpty()&&text!="-1"&&text.toLower()!="unknown"&&text.toLower()!="null"&&text.toLower()!="none")item.id=text;
            }
            else if(id.isDouble()&&std::isfinite(id.toDouble())&&id.toDouble()>=0&&
                    std::floor(id.toDouble())==id.toDouble()&&id.toDouble()<=9007199254740991.)
                item.id=QString::number(id.toDouble(),'f',0);
            item.source=object["source"].toString();
            item.observed=!object["observed"].isBool()||object["observed"].toBool();
            frame.objects.push_back(item);
        }
        return true;
    }
public:
    ReplayInput(QObject* parent,std::function<void(bool,const Frame&)> callback):QObject(parent),deliver(std::move(callback)) {
        fd=::socket(AF_INET,SOCK_DGRAM|SOCK_NONBLOCK|SOCK_CLOEXEC,0);
        sockaddr_in address{};address.sin_family=AF_INET;address.sin_port=htons(18766);
        address.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
        if(fd<0||::bind(fd,reinterpret_cast<sockaddr*>(&address),sizeof(address))<0) {
            qWarning("REPLAY_INPUT bind failed errno=%d",errno);
            if(fd>=0)::close(fd);fd=-1;return;
        }
        auto* notifier=new QSocketNotifier(fd,QSocketNotifier::Read,this);
        connect(notifier,&QSocketNotifier::activated,this,[this](int){
            char data[65536];ssize_t size;
            // Bound work per event to keep the native UI responsive.
            for(int count=0;count<64&&(size=::recv(fd,data,sizeof(data),0))>0;++count) {
                QJsonParseError error;
                const auto document=QJsonDocument::fromJson(QByteArray(data,int(size)),&error);
                if(error.error!=QJsonParseError::NoError||!document.isObject())continue;
                const auto message=document.object();
                if(message["version"].toInt()!=1||!message["active"].isBool())continue;
                if(!message["active"].toBool()) {
                    if(active){active=false;deliver(false,{});}continue;
                }
                Frame frame;if(!decode(message["scene"].toObject(),frame))continue;
                active=true;heartbeat.restart();deliver(true,frame);
            }
        });
        auto* watchdog=new QTimer(this);
        connect(watchdog,&QTimer::timeout,this,[this]{
            if(active&&heartbeat.elapsed()>1500){active=false;deliver(false,{});}
        });watchdog->start(250);
        qInfo("REPLAY_INPUT loopback_port=18766 ready=1");
    }
    ~ReplayInput() override {if(fd>=0)::close(fd);}
};
}
