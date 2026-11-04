#pragma once
#include "panel_frame.h"
#include <QPainter>
#include <QPainterPath>
#include <QStringList>
#include <algorithm>
#include <cmath>
#include "vehicle_action_state.h"

// Artwork positions are measured in the supplied 2000 x 500 reference.
// The panel is cropped at (30,112), size 1938 x 351. Always scale uniformly.
namespace status_bar {
constexpr double panelWidth=1938., panelHeight=351.;
inline QColor ink(){return QColor("#253148");}
inline QColor gray(){return QColor("#7c899d");}
inline QColor blue(){return QColor("#5573ff");}
inline void box(QPainter& p,QRectF r,QColor fill,QColor stroke=Qt::transparent,
                double radius=14,double width=1){
    p.setPen(stroke.alpha()?QPen(stroke,width):QPen(Qt::NoPen));p.setBrush(fill);
    // r describes the outer bounds, including the stroke.
    p.drawRoundedRect(r.adjusted(width/2,width/2,-width/2,-width/2),radius,radius);
}
inline void label(QPainter& p,QRectF r,const QString& text,int size,
                  QColor color=ink(),bool bold=false,int flags=Qt::AlignLeft|Qt::AlignVCenter){
    QFont font(QStringLiteral("Noto Sans CJK SC"));font.setPixelSize(size);
    font.setWeight(bold?QFont::Bold:QFont::Normal);p.setFont(font);p.setPen(color);
    p.drawText(r,flags,text);
}
inline void arrow(QPainter& p,QRectF r,int kind,QColor color){
    p.save();p.translate(r.topLeft());p.scale(r.width()/100.,r.height()/100.);
    p.setPen(QPen(color,12,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));p.setBrush(Qt::NoBrush);
    QPainterPath a;
    if(kind==0){a.moveTo(76,93);a.lineTo(76,43);a.lineTo(67,27);a.lineTo(12,27);a.moveTo(39,1);a.lineTo(12,27);a.lineTo(39,53);}
    if(kind==1){a.moveTo(50,97);a.lineTo(50,5);a.moveTo(18,37);a.lineTo(50,5);a.lineTo(82,37);}
    if(kind==2){a.moveTo(24,93);a.lineTo(24,43);a.lineTo(33,27);a.lineTo(88,27);a.moveTo(61,1);a.lineTo(88,27);a.lineTo(61,53);}
    p.drawPath(a);p.restore();
}
inline void source(QPainter& p,QRectF select,QRectF badge,const QString& name,const QString& state){
    p.save();p.setRenderHint(QPainter::Antialiasing);
    const double scale=select.height()/58.;
    box(p,select,QColor("#f7f8fc"),QColor("#d4dff5"),10*scale);
    label(p,select.adjusted(24*scale,0,-55*scale,0),name,std::max(10,int(24*scale)));
    const QPointF c(select.right()-32*scale,select.center().y());
    p.setPen(QPen(QColor("#74839c"),2*scale,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));
    QPainterPath chevron;chevron.moveTo(c+QPointF(-8*scale,-4*scale));chevron.lineTo(c+QPointF(0,4*scale));chevron.lineTo(c+QPointF(8*scale,-4*scale));p.drawPath(chevron);
    box(p,badge,QColor("#f3f8f6"),QColor("#d9e9e3"),10*scale);
    p.setPen(Qt::NoPen);p.setBrush(QColor("#249d6a"));p.drawEllipse(QPointF(badge.left()+21*scale,badge.center().y()),5*scale,5*scale);
    label(p,badge.adjusted(41*scale,0,-8*scale,0),state,std::max(10,int(24*scale)),QColor("#60738c"));
    p.restore();
}
inline bool parking(const vehicle_action::Result& result){
    return result.state==QStringLiteral("Stopped")||result.state==QStringLiteral("EmergencyLatched")||
        result.action==QStringLiteral("stop");
}
inline QString labelForCard(int card,const vehicle_action::Result* result=nullptr){
    const QStringList names={"左转向","直行","右转向","违反交规","紧急刹停"};
    return card==1&&result&&parking(*result)?QStringLiteral("停车"):names.value(card);
}
inline vehicle_action::Color activeColor(const vehicle_action::Result& result,int card,bool intent){
    if(card<3&&!intent)return vehicle_action::Color::Gray;
    if(card==1&&parking(result))return vehicle_action::Color::Red;
    const auto color=result.cards[card].color;
    if(color==vehicle_action::Color::Gray)return color;
    // Green indicates activity; permission and waiting reasons remain in the FSM.
    return card>=3||color==vehicle_action::Color::Red?vehicle_action::Color::Red:vehicle_action::Color::Green;
}
inline bool blinkActive(const vehicle_action::Result& result,bool intent){
    for(int i=0;i<5;++i)if(activeColor(result,i,intent)!=vehicle_action::Color::Gray)return true;
    return false;
}
inline bool blinkPhase(qint64 monotonicMs){return (monotonicMs/500)%2==0;}
inline void paint(QPainter& p,QRectF target,int direction,bool running,bool intent,
                   bool aeb,const QString& navReadout={},const vehicle_action::Result* result=nullptr,bool blinkOn=true){
    if(target.isEmpty())return;
    const double scale=std::min(target.width()/panelWidth,target.height()/panelHeight);
    const QSizeF size(panelWidth*scale,panelHeight*scale);
    panel_frame::drawFrame(p,QRectF(target.center()-QPointF(size.width()/2,size.height()/2),size),14*scale);
    p.save();p.translate(target.center()-QPointF(size.width()/2,size.height()/2));
    p.scale(scale,scale);p.translate(-30,-112);p.setRenderHint(QPainter::Antialiasing);
    const QRectF title(50,132,428,60);
    box(p,title.translated(4,5),QColor("#e8eefb"),Qt::transparent,10);
    box(p,title,QColor("#f2f5ff"),QColor("#b9c9ff"),10);
    box(p,{title.x(),title.y(),6,title.height()},blue(),Qt::transparent,2);
    label(p,title.adjusted(16,0,-4,0),QStringLiteral("车辆下一步行动状态显示表"),32,ink(),true);
    p.setPen(QPen(QColor("#d2ddff"),1));p.drawLine(60,218,478,218);p.drawLine(645,140,645,438);
    p.setPen(QPen(QColor("#8ca5ff"),4));p.drawLine(60,218,140,218);
    // Keep live navigation telemetry in the reference's otherwise blank intro.
    label(p,{60,236,555,70},result?result->reason:QString(),24,ink(),false,Qt::AlignLeft|Qt::AlignTop|Qt::TextWordWrap);
    label(p,{60,310,555,70},navReadout,24,gray(),false,Qt::AlignLeft|Qt::AlignTop|Qt::TextWordWrap);
    label(p,{60,390,575,60},QStringLiteral("当前车辆下一步将要："),54,ink(),true);
    for(int i=0;i<5;++i){
        const QRectF card(667+i*250,134,240,310);
        box(p,card.translated(3,5),QColor("#e8eef9"));
        box(p,card,Qt::white,QColor("#d4dff5"));
        const auto state=result&&blinkOn?activeColor(*result,i,intent):vehicle_action::Color::Gray;
        const bool active=result?state!=vehicle_action::Color::Gray:i<3&&running&&intent&&direction==i-1;
        const QColor color=result?(state==vehicle_action::Color::Red?QColor("#e44855"):
            state==vehicle_action::Color::Yellow?QColor("#d69b24"):state==vehicle_action::Color::Green?QColor("#249d6a"):gray()):
            i==4&&aeb?QColor("#e44855"):active?QColor("#249d6a"):gray();
        const QRectF circle(677+i*250,153,222,222);
        box(p,circle,active?QColor("#f0faf5"):QColor(Qt::white),color,111,10);
        if(i<3)arrow(p,circle.adjusted(43,43,-43,-43),i,color);
        else if(i==3){
            p.setPen(QPen(color,12,Qt::SolidLine,Qt::RoundCap));p.setBrush(Qt::NoBrush);
            p.drawEllipse(circle.adjusted(59,59,-59,-59));
            p.drawLine(circle.topLeft()+QPointF(62,150),circle.topLeft()+QPointF(150,62));
        }else{
            QPainterPath stop;const QPointF center=circle.center()+QPointF(0,-28);
            for(int k=0;k<8;++k){
                const double a=(22.5+k*45)*3.141592653589793/180.;
                const QPointF point=center+QPointF(std::cos(a)*48,std::sin(a)*48);
                if(k)stop.lineTo(point);else stop.moveTo(point);
            }
            stop.closeSubpath();p.setPen(QPen(color,8));p.setBrush(Qt::NoBrush);p.drawPath(stop);
            p.setPen(QPen(color,11,Qt::SolidLine,Qt::RoundCap));
            p.drawLine(center+QPointF(0,-23),center+QPointF(0,1));
            p.setPen(Qt::NoPen);p.setBrush(color);p.drawEllipse(center+QPointF(0,21),5.5,5.5);
            label(p,{circle.x(),285,circle.width(),62},"AEB",54,color,true,Qt::AlignCenter);
        }
        p.setPen(QPen(QColor("#baceff"),2));p.drawLine(card.center().x()-34,386,card.center().x()+34,386);
        const QRectF tag(card.x()+12,391,216,46);
        box(p,tag,QColor("#f1f5fc"),Qt::transparent,10);
        label(p,tag.translated(0,6),labelForCard(i,result),32,ink(),true,Qt::AlignCenter);
    }
    p.restore();
}
} // namespace status_bar
