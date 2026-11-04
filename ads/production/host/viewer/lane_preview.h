#pragma once
#include "lane_scene.h"
#include <QPainter>
namespace lane_preview {
constexpr int SlotCount=lane_arbitration::SlotCount;
inline QImage build(const lane_arbitration::Snapshot& scene) {
    QImage result(320,120,QImage::Format_ARGB32_Premultiplied);result.fill(QColor("#303234"));
    QPainter p(&result);p.setRenderHint(QPainter::Antialiasing);
    for(int slot=0;slot<SlotCount;++slot){
        p.setPen(QPen(QColor("#424548"),1));const double x=35.+slot*50.;p.drawLine(QPointF(x,8),QPointF(x,112));
    }
    bool tracking=false;
    for(const auto& track:scene.tracks) {
        if(track.slot<0||track.slot>=SlotCount)continue;
        const double x=35.+track.slot*50.;
        {
            // 侧边线/虚线可能不到画面底部，取本条线最近可见端的已确认线型。
            // 此符号提示不改变ADAS对实际近端跨线区的要求。
            const bool confirmed=track.displayState==lane_arbitration::DisplayState::Confirmed && track.observed;
            const int type=confirmed?track.displayType:0;
            if(track.displayState==lane_arbitration::DisplayState::Hidden)continue;
            if(!type) {
                // Gray shows a tracked position only, never a solid/dashed claim.
                p.setPen(QPen(QColor("#858b92"),1.5,Qt::DotLine));
                p.drawLine(QPointF(x,8),QPointF(x,112));tracking=true;continue;
            }
            const bool yellow=type==1||type==3||type==5,doubled=type==1||type==2,dashed=type==5||type==6;
            QPen pen(yellow?QColor("#ffd735"):QColor("#fafafa"),2.5,Qt::SolidLine,Qt::FlatCap);
            if(dashed){pen.setStyle(Qt::CustomDashLine);pen.setDashPattern(QVector<qreal>{4,3});}
            p.setPen(pen);
            const double top=8,bottom=112;
            if(doubled){p.drawLine(QPointF(x-3,top),QPointF(x-3,bottom));p.drawLine(QPointF(x+3,top),QPointF(x+3,bottom));}
            else p.drawLine(QPointF(x,top),QPointF(x,bottom));
        }
    }
    if(tracking){p.setPen(QColor("#aab1b8"));QFont font=p.font();font.setPixelSize(9);p.setFont(font);p.drawText(QRect(2,112,316,8),Qt::AlignRight,QStringLiteral("灰：位置跟踪，线型未确认"));}
    p.setPen(QPen(QColor("#aab1b8"),1));p.setBrush(Qt::white);p.drawRect(QRectF(154,54,12,12));
    return result;
}
inline QImage build(const QImage& mask) {
    // Stateless diagnostic preview only. Production owns a persistent Engine.
    lane_arbitration::Engine engine;const auto observation=lane_arbitration::fromMask(mask);
    engine.update(observation,1,1);return build(engine.update(observation,101,1));
}
}
