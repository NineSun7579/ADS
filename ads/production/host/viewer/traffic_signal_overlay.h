#pragma once
#include <QPainter>
#include <QPainterPath>
#include <QMap>
#include <QVariant>
#include <cmath>

// Presentation only: these bindings never feed the driving state machine.
class TrafficSignalOverlay {
public:
    void layout(const QRectF &video, qreal scale) {
        bounds=video;
        constexpr qreal compactScale=.7071067811865476; // Half the area, same aspect ratio.
        const QSizeF extent(qMin(video.width(),300*scale*compactScale),qMin(video.height(),180*scale*compactScale));
        if(!placed) { rect=QRectF(video.topLeft()+QPointF(20*scale,58*scale),extent);placed=true; }
        else rect.setSize(extent);
        clamp();
    }
    bool press(const QPointF &point) {
        if(!visible || !rect.contains(point))return false;
        dragging=true;offset=point-rect.topLeft();return true;
    }
    bool move(const QPointF &point) {
        if(!dragging)return false;
        rect.moveTopLeft(point-offset);clamp();return true;
    }
    bool release() { const bool active=dragging;dragging=false;return active; }
    void paint(QPainter &p) const {
        if(!visible || rect.isEmpty())return;
        p.save();p.setClipRect(bounds);p.setRenderHint(QPainter::Antialiasing);
        p.translate(rect.topLeft());p.scale(rect.width()/300,rect.height()/180);
        p.setPen(QPen(QColor("#45d9c4"),2));p.setBrush(QColor(5,24,31,225));
        p.drawRoundedRect(QRectF(1,1,298,178),3,3);
        auto text=[&](const QRectF &r,const QString &s,int pixels,const QColor &ink,int flags=Qt::AlignLeft|Qt::AlignVCenter) {
            QFont f=p.font();f.setPixelSize(pixels);p.setFont(f);p.setPen(ink);p.drawText(r,flags,s);
        };
        const bool navigation=bindings.value(QStringLiteral("navigation.active")).toBool();
        const bool navValid=bindings.value(QStringLiteral("navigation.valid")).toBool();
        QString light=value("traffic.light",QStringLiteral("--"));
        if(light==QStringLiteral("未提供灯色")||light==QStringLiteral("未识别")||light==QStringLiteral("未知"))
            light=QStringLiteral("未识别到红绿灯");
        QColor ink("#a7c5c8");
        // A mixed set stays neutral and is displayed in full; never choose green.
        if(light==QStringLiteral("红灯"))ink=QColor("#ff7777");
        else if(light==QStringLiteral("黄灯"))ink=QColor("#ffcf67");
        else if(light==QStringLiteral("绿灯"))ink=QColor("#58e7b0");
        QString selectedDirection=value("traffic.assumedDirection",QString()).toLower();
        if(selectedDirection=="up")selectedDirection="straight";
        const QString directionLabel=selectedDirection=="left"?QStringLiteral("左转"):selectedDirection=="right"?QStringLiteral("右转"):
            selectedDirection=="straight"?QStringLiteral("直行"):
            (selectedDirection=="uturn"||selectedDirection=="u-turn"||selectedDirection=="left_uturn")?QStringLiteral("掉头"):QStringLiteral("--");
        {
            const auto lamps=light.split(QStringLiteral(" / "));QString matched;
            for(const auto& lamp:lamps)if(lamp.startsWith(directionLabel))matched=lamp.mid(directionLabel.size());
            if(lamps.size()>1||light.startsWith(QStringLiteral("左转"))||light.startsWith(QStringLiteral("直行"))||light.startsWith(QStringLiteral("右转")))light=matched;
            if(light!=QStringLiteral("红灯")&&light!=QStringLiteral("黄灯")&&light!=QStringLiteral("绿灯"))light=QStringLiteral("--");
        }
        ink=light==QStringLiteral("红灯")?QColor("#ff7777"):light==QStringLiteral("绿灯")?QColor("#58e7b0"):
            light==QStringLiteral("黄灯")?QColor("#ffcf67"):QColor("#a7c5c8");
        text(QRectF(16,22,128,32),QStringLiteral("信号灯识别"),20,QColor("#e4f6f4"));
        text(QRectF(146,22,60,32),directionLabel,20,QColor("#e4f6f4"),Qt::AlignCenter);
        p.setPen(QPen(ink,1));p.setBrush(QColor(10,59,60,220));
        const bool multiLight=light.contains(QStringLiteral(" / "));
        const QRectF badge(211,22,78,32);
        p.drawRoundedRect(badge,4,4);
        if(multiLight) {
            const auto lamps=light.split(QStringLiteral(" / "));
            const qreal rowHeight=badge.height()/lamps.size();
            for(int i=0;i<lamps.size();++i) {
                const auto lamp=lamps[i];const QColor color=lamp.contains(QStringLiteral("红灯"))?QColor("#ff7777"):
                    lamp.contains(QStringLiteral("绿灯"))?QColor("#58e7b0"):
                    lamp.contains(QStringLiteral("黄灯"))?QColor("#ffcf67"):ink;
                text(QRectF(badge.left()+4,badge.top()+i*rowHeight,badge.width()-8,rowHeight),lamp,16,color,Qt::AlignCenter);
            }
        } else text(badge.adjusted(3,0,-3,0),light,light.size()>4?13:18,ink,Qt::AlignCenter);
        QString direction=value(navigation?"navigation.direction":"traffic.direction",QString()).toLower();
        const QString displayDirection=value("navigation.displayDirection",QString());
        if(navigation&&!displayDirection.isEmpty())direction=displayDirection.toLower();
        if(bindings.value(QStringLiteral("navigation.secondCaptureStraight")).toBool())direction=QStringLiteral("straight");
        if(direction=="up"||direction==QStringLiteral("直行"))direction="straight";
        else if(direction==QStringLiteral("左转"))direction="left";
        else if(direction==QStringLiteral("右转"))direction="right";
        else if(direction=="u-turn"||direction=="left_uturn"||direction==QStringLiteral("掉头"))direction="uturn";
        // The slot beside the distance is the observed next-maneuver icon.
        // Missing/ambiguous recognition leaves it empty, never a default straight.
        p.save();p.translate(18,88);p.setPen(QPen(QColor("#45d9c4"),3.5,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
        p.setBrush(Qt::NoBrush);QPainterPath maneuver;
        if(direction=="straight") {
            maneuver.moveTo(27,44);maneuver.lineTo(27,9);
            maneuver.moveTo(14,22);maneuver.lineTo(27,9);maneuver.lineTo(40,22);
        } else if(direction=="left"||direction=="right") {
            if(direction=="right"){p.translate(54,0);p.scale(-1,1);}
            maneuver.moveTo(39,44);maneuver.lineTo(39,26);maneuver.quadTo(39,16,29,16);maneuver.lineTo(10,16);
            maneuver.moveTo(21,5);maneuver.lineTo(10,16);maneuver.lineTo(21,27);
        } else if(direction=="uturn") {
            maneuver.moveTo(42,44);maneuver.lineTo(42,19);maneuver.cubicTo(42,1,14,1,14,19);maneuver.lineTo(14,37);
            maneuver.moveTo(4,27);maneuver.lineTo(14,37);maneuver.lineTo(24,27);
        }
        p.drawPath(maneuver);p.restore();
        if(maneuver.isEmpty())text(QRectF(18,88,54,54),QStringLiteral("--"),30,QColor("#45d9c4"),Qt::AlignCenter);
        QString distance=value(navigation?"navigation.distance":"traffic.distance",QStringLiteral("-- 米"));
        QString number=distance;number.remove(QStringLiteral("米"));number.remove('m');
        bool valid=false;const double meters=number.trimmed().toDouble(&valid);
        if(!valid || !std::isfinite(meters) || meters<0)distance=QStringLiteral("-- 米");
        else distance=number.trimmed()+QStringLiteral(" 米");
        text(QRectF(86,78,180,58),distance,44,QColor("#45d9c4"));
        p.restore();
    }
    bool visible=false,dragging=false;
    QMap<QString,QVariant> bindings;
private:
    QString value(const char *key,const QString &fallback) const {
        const QString s=bindings.value(QString::fromLatin1(key)).toString().trimmed();
        return s.isEmpty() || s==QStringLiteral("--")?fallback:s;
    }
    void clamp() {
        rect.moveLeft(qBound(bounds.left(),rect.left(),qMax(bounds.left(),bounds.right()-rect.width())));
        rect.moveTop(qBound(bounds.top(),rect.top(),qMax(bounds.top(),bounds.bottom()-rect.height())));
    }
    QRectF rect,bounds;
    QPointF offset;
    bool placed=false;
};
