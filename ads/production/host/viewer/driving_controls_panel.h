#pragma once
#include "panel_frame.h"
#include <QPainter>
#include <QPainterPath>
#include <QStringList>
#include <QTransform>
#include <QFontMetricsF>
#include <array>
#include <algorithm>

// Drawing and input share a layout in actual rail coordinates.
namespace driving_controls_panel {
inline QColor ink(){return QColor("#253148");}
inline QColor gray(){return QColor("#7c899e");}
inline QColor blue(){return QColor("#5573ff");}
inline QColor green(){return QColor("#249d6a");}
inline void box(QPainter& p,QRectF r,QColor fill,QColor stroke=Qt::transparent,double radius=14,double width=1){
    p.setPen(QPen(stroke,width));p.setBrush(fill);p.drawRoundedRect(r,radius,radius);
}
inline void label(QPainter& p,QRectF r,const QString& s,int size,QColor color=ink(),bool bold=false,int flags=Qt::AlignLeft|Qt::AlignVCenter){
    QFont font(QStringLiteral("Noto Sans CJK SC"));font.setPixelSize(size);font.setWeight(bold?QFont::Bold:QFont::Normal);
    p.setFont(font);p.setPen(color);p.drawText(r,flags,s);
}
inline void title(QPainter& p,QRectF r,const QString& s,int size){
    box(p,r.translated(5,6),QColor("#e8eefb"),Qt::transparent,12);
    box(p,r,QColor("#f2f5ff"),QColor("#b9c9ff"),12);
    box(p,{r.x(),r.y(),7,r.height()},blue(),Qt::transparent,2);
    label(p,r.adjusted(26,0,-8,0),s,size,ink(),true);
}
inline void ring(QPainter& p,QRectF r,QColor color,QColor fill=Qt::white,double width=5){box(p,r,fill,color,r.width()/2,width);}
inline void arrow(QPainter& p,QRectF r,int kind,QColor color,double width){
    p.save();p.translate(r.x(),r.y());p.scale(r.width()/100.,r.height()/100.);
    p.setPen(QPen(color,width,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));p.setBrush(Qt::NoBrush);
    QPainterPath a;
    if(kind==1){a.moveTo(50,88);a.lineTo(50,10);a.moveTo(20,40);a.lineTo(50,10);a.lineTo(80,40);}
    if(kind==3){a.moveTo(85,50);a.lineTo(15,50);a.moveTo(40,25);a.lineTo(15,50);a.lineTo(40,75);}
    if(kind==4){a.moveTo(15,50);a.lineTo(85,50);a.moveTo(60,25);a.lineTo(85,50);a.lineTo(60,75);}
    if(kind==5){a.moveTo(82,82);a.lineTo(18,18);a.moveTo(18,60);a.lineTo(18,18);a.lineTo(60,18);}
    if(kind==6){a.moveTo(18,82);a.lineTo(82,18);a.moveTo(40,18);a.lineTo(82,18);a.lineTo(82,60);}
    p.drawPath(a);p.restore();
}
constexpr double panelWidth=940, panelHeight=2000, toolsHeight=24;
inline QRectF artworkArea(QRectF rail) {
    rail.setHeight(std::max(0.,rail.height()-toolsHeight));return rail;
}
inline QRectF fitted(QRectF target) {
    return target;
}
inline QTransform transform(QRectF target) {
    const auto r=fitted(target);QTransform t;
    t.translate(r.x(),r.y());t.scale(r.width()/panelWidth,r.height()/panelHeight);return t;
}
inline QRectF controlCircle(int value) {
    if(value<2)return {value?514.:212.,422,210,210};
    if(value<5)return {96.+(value-2)*270,932,200,200};
    return {value==5?212.:514.,1408,210,210};
}
struct Layout {
    QRectF frame,title,status,footer;
    std::array<QRectF,3> groups,headings;
    std::array<QRectF,7> circles,tags;
    int titleFont=22,statusFont=14,headingFont=14,labelFont=15,footerFont=12;
    double scale=1;
};
inline QFont font(int size,bool bold=false) {
    QFont f(QStringLiteral("Noto Sans CJK SC"));f.setPixelSize(size);
    f.setWeight(bold?QFont::Bold:QFont::Normal);return f;
}
inline Layout layout(QRectF target) {
    Layout l;
    if(target.isEmpty())return l;
    const double s=std::min(target.width()/340.,target.height()/518.);
    l.scale=s;
    const double responsive=std::max(0.,std::min(1.,(target.height()-306.)/212.));
    l.titleFont=qRound((16+6*responsive)*std::max(1.,s));
    l.statusFont=qRound((10+4*responsive)*std::max(1.,s));
    l.headingFont=l.statusFont;
    l.labelFont=qRound((11+4*responsive)*std::max(1.,s));
    l.footerFont=qRound((10+2*responsive)*std::max(1.,s));
    const double pad=10*s,gap=6*s;
    l.frame=target.adjusted(1,1,-1,-1);
    const QRectF content=target.adjusted(pad,pad,-pad,-pad);
    const double titleH=l.titleFont+8*s;
    l.title={content.x(),content.y(),content.width(),titleH};
    const double statusH=2*l.statusFont+4*s;
    l.status={content.x(),l.title.bottom()+4*s,content.width(),statusH};
    const double footerH=l.footerFont+12*s;
    l.footer={content.x(),content.bottom()-footerH,content.width(),footerH};
    const double start=l.status.bottom()+gap;
    const double groupH=(l.footer.top()-gap-start-2*gap)/3.;
    for(int g=0;g<3;++g) {
        l.groups[g]={content.x(),start+g*(groupH+gap),content.width(),groupH};
        const double headingH=l.headingFont+6*s;
        l.headings[g]=l.groups[g].adjusted(8*s,2*s,-8*s,0);
        l.headings[g].setHeight(headingH);
        const int count=g==1?3:2,first=g==0?0:g==1?2:5;
        const double tagH=l.labelFont+5*s;
        const double cellW=(content.width()-12*s)/count;
        const double top=l.headings[g].bottom()+4*s;
        const double diameter=std::max(0.,std::min({84*s,cellW-12*s,groupH-headingH-tagH-12*s}));
        for(int j=0;j<count;++j) {
            const double cx=content.x()+6*s+(j+.5)*cellW;
            l.circles[first+j]={cx-diameter/2,top,diameter,diameter};
            l.tags[first+j]={cx-cellW/2+2*s,top+diameter+3*s,cellW-4*s,tagH};
        }
    }
    return l;
}
inline QRectF mapControl(QRectF target,int value) {
    return value>=0&&value<7?layout(target).circles[value]:QRectF();
}
inline void paint(QPainter& p,QRectF target,int lane,int change,bool running,
                  const QString& pressed,bool aeb=false,bool blinkOn=true) {
    if(target.isEmpty())return;
    const auto l=layout(target);const double s=l.scale;
    p.save();p.setClipRect(target,Qt::IntersectClip);
    p.setRenderHint(QPainter::Antialiasing);
    panel_frame::drawFrame(p,target,8*s);
    box(p,l.title,QColor("#f2f5ff"),QColor("#b9c9ff"),5*s);
    box(p,{l.title.x(),l.title.y(),3*s,l.title.height()},blue(),Qt::transparent,1*s);
    label(p,l.title.adjusted(12*s,0,-4*s,0),"控制区",l.titleFont,ink(),true);
    box(p,l.status,QColor(aeb?"#fff5f6":"#f0faf5"),QColor(aeb?"#f2c5cb":"#c5e8d8"),5*s);
    const QColor statusColor=aeb?QColor("#e44855"):QColor("#218752");
    p.setBrush(statusColor);p.setPen(Qt::NoPen);p.drawEllipse(QPointF(l.status.x()+9*s,l.status.center().y()),3*s,3*s);
    QString state=QStringList{"左转车道","直行车道","右转车道"}[std::max(-1,std::min(1,lane))+1]
        +(running?" · 已请求行驶":" · 停止请求");
    if(aeb)state="急刹/避碰提醒 · "+state;
    label(p,l.status.adjusted(18*s,0,-5*s,0),aeb?state:"当前："+state,l.statusFont,statusColor,true,Qt::AlignLeft|Qt::AlignVCenter|Qt::TextWordWrap);
    const QStringList headings={"行驶与停止控制按键","切换左、右、直行车道控制按键","左右变道控制按键"};
    for(int i=0;i<3;++i) {
        box(p,l.groups[i],Qt::white,QColor("#d7e2f6"),6*s);
        label(p,l.headings[i],headings[i],l.headingFont,ink(),true);
        p.setPen(QPen(QColor("#e0e8fa"),s));p.drawLine(l.headings[i].bottomLeft(),l.headings[i].bottomRight());
    }
    const QStringList ids={"drive-go","drive-stop","drive-lane-0","drive-lane-1","drive-lane-2","drive-change-left","drive-change-right"};
    const QStringList names={"请求行驶","停止","左转车道","直行车道","右转车道","向左变道","向右变道"};
    for(int i=0;i<7;++i) {
        const auto original=l.circles[i];
        const bool down=pressed==ids[i];
        const bool selected=i>=2&&i<=4?lane==i-3:i==5?change<0:i==6?change>0:false;
        const bool lit=selected&&(i<5||blinkOn);
        const QColor c=i==1?QColor("#e44855"):i==0||lit?green():gray();
        p.save();
        if(down){p.translate(original.center());p.scale(.88,.88);p.translate(-original.center());}
        if(i<2||lit)ring(p,original.adjusted(-2*s,-2*s,2*s,2*s),i==1?QColor("#e7edf7"):QColor("#e0f2e8"),Qt::white,s);
        ring(p,original,c,i<2||lit?QColor(i==1?"#fff5f6":"#f0faf5"):QColor(Qt::white),2*s);
        if(i==0) {
            const double d=original.width();const auto center=original.center();
            QPainterPath play;play.moveTo(center+QPointF(-.13*d,-.22*d));play.lineTo(center+QPointF(.22*d,0));play.lineTo(center+QPointF(-.13*d,.22*d));play.closeSubpath();p.fillPath(play,c);
        } else if(i==1) {
            const double d=original.width()*.35;
            box(p,{original.center().x()-d/2,original.center().y()-d/2,d,d},c,Qt::transparent,3*s);
        } else arrow(p,original.adjusted(original.width()*.22,original.height()*.22,-original.width()*.22,-original.height()*.22),i==2?3:i==3?1:i==4?4:i,c,10);
        p.restore();
        box(p,l.tags[i],QColor("#f1f5fc"),Qt::transparent,4*s);label(p,l.tags[i],names[i],l.labelFont,ink(),true,Qt::AlignCenter);
    }
    box(p,l.footer,QColor("#f1f5fc"),Qt::transparent,5*s);
    label(p,l.footer,"按下缩放 · 松开回弹 · 虚线时可变道",l.footerFont,gray(),false,Qt::AlignCenter);p.restore();
}
} // namespace driving_controls_panel
