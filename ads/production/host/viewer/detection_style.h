#pragma once
#include <QColor>
#include <QString>
namespace detection_style {
inline QString key(QString name) { return name.section(':',-1).trimmed().toLower(); }
inline QString depthLabel(const QString& status) {
    return status;
}
inline bool signal(const QString& name) {
    const auto k=key(name);
    return k.startsWith("tl_") || k.startsWith("traffic_light") || k.startsWith("tlr") ||
        k.startsWith("tly") || k.startsWith("tlg") || k.startsWith("tsr") ||
        k.startsWith("tsy") || k.startsWith("tsg") || k.startsWith("trr") ||
        k.startsWith("try") || k.startsWith("trg") || k.startsWith("tur") ||
        k.startsWith("tuy") || k.startsWith("tug") || k.startsWith("tln") || k=="traffic_sign";
}
inline QColor color(const QString& name) {
    const auto k=key(name);
    QColor c;
    if(k=="car") c=QColor("#2588ed");
    else if(k=="vehicle") c=QColor("#237de0");
    else if(k=="bus") c=QColor("#31a9df");
    else if(k=="truck") c=QColor("#485dd9");
    else if(k=="person") c=QColor("#ef982c");
    else if(k=="rider") c=QColor("#e5bb35");
    else if(k=="bike" || k=="bicycle") c=QColor("#9b6bdf");
    else if(k=="motor" || k=="motorcycle") c=QColor("#c16cd3");
    else if(k=="traffic_sign") c=QColor("#dc488d");
    else if(k=="tl_red" || k.contains("red")) c=QColor("#ee5248");
    else if(k=="tl_yellow" || k.contains("yellow") || k.contains("amber")) c=QColor("#ec992c");
    else if(k=="tl_green" || k.contains("green")) c=QColor("#40b878");
    else if(k=="traffic_light") c=QColor("#e2a640");
    else if(k=="zebra") c=QColor("#37b8a4");
    else {
        uint hash=2166136261u;
        for(const auto character:k) {hash^=character.unicode();hash*=16777619u;}
        c=QColor::fromHsv(int(hash%360),170,220);
    }
    // Direction-specific signal classes share a hue family, with distinct shades.
    if(signal(k) && k!="tl_red" && k!="tl_yellow" && k!="tl_green" &&
       k!="traffic_light" && k!="traffic_sign") {
        uint shade=2166136261u;
        for(const auto character:k) {shade^=character.unicode();shade*=16777619u;}
        c=QColor::fromHsv(c.hsvHue(),150+int(shade%71),205+int((shade/71)%46));
    }
    c.setAlphaF(.90);return c;
}
inline QString label(const QString& name) {
    const auto k=key(name);
    if(k=="car") return "小汽车";
    if(k=="vehicle") return "车辆";
    if(k=="bus") return "公交车";
    if(k=="truck") return "卡车";
    if(k=="person") return "行人";
    if(k=="rider") return "骑行者";
    if(k=="bike" || k=="bicycle") return "自行车";
    if(k=="motor" || k=="motorcycle") return "摩托车";
    if(k=="tl_red" || k=="traffic_light_red") return "红灯";
    if(k=="tl_yellow" || k=="traffic_light_yellow") return "黄灯";
    if(k=="tl_green" || k=="traffic_light_green") return "绿灯";
    if(k=="traffic_sign") return "交通标志";
    if(k=="traffic_light") return "信号灯";
    if(k=="zebra") return "斑马线";
    return k;
}
}
