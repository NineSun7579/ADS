#pragma once
#include "vehicle_action_state.h"
#include <QSet>
#include <cmath>
#include <stdexcept>

namespace vehicle_action {
// One session per ordered ADS evidence source. Clock rewind/source switch must
// use a new session. JSON never provides the verified-emergency producer API.
class JsonSession {
public:
    QJsonObject update(const QJsonObject& packet) {
        static const QSet<QString> fields={"now_ms","requested","recognition",
            "assumed_lane","change_request","evidence","op"};
        for(auto it=packet.begin();it!=packet.end();++it)
            if(!fields.contains(it.key()))fail("unknown input field");
        Input in;
        in.now=integer(packet,"now_ms",0,9007199254740991LL,true);
        if(lastTime>=0&&in.now<lastTime)fail("clock moved backwards; start a new session");
        in.requested=boolean(packet,"requested",false);
        in.recognition=boolean(packet,"recognition",true);
        in.assumedLane=int(integer(packet,"assumed_lane",-1,1,false));
        in.changeRequest=int(integer(packet,"change_request",-1,1,false));
        if(packet.contains("evidence")&&!packet["evidence"].isObject())fail("evidence must be an object");
        in.evidence=packet["evidence"].toObject();
        if(packet.contains("op")&&!packet["op"].isString())fail("op must be a string");
        const QString op=packet["op"].toString("update");
        if(op!="update"&&op!="stop")fail("op must be update or stop");
        if(op=="stop") {in.requested=false;engine.stop(in);}
        lastTime=in.now;
        auto output=engine.update(in).json();
        output["now_ms"]=double(in.now);
        return output;
    }
private:
    Engine engine;
    qint64 lastTime=-1;
    [[noreturn]] static void fail(const char* message){throw std::invalid_argument(message);}
    static bool boolean(const QJsonObject& obj,const char* key,bool fallback) {
        if(!obj.contains(key))return fallback;
        if(!obj[key].isBool())fail("request/recognition fields must be boolean");
        return obj[key].toBool();
    }
    static qint64 integer(const QJsonObject& obj,const char* key,qint64 low,qint64 high,bool required) {
        if(!obj.contains(key)) {if(required)fail("now_ms is required");return 0;}
        const double value=obj[key].toDouble(std::nan(""));
        if(!std::isfinite(value)||std::floor(value)!=value||value<double(low)||value>double(high))
            fail("invalid integer/time/direction field");
        return qint64(value);
    }
};
} // namespace vehicle_action
