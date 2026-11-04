#pragma once
#include "ui/designview.h"
#include "lane_arbitration.h"
#include <QGraphicsScene>
#include <QGraphicsItem>
#include <QPainter>
#include <QStyleOptionGraphicsItem>
#include <QHash>
#include <array>
#include <cmath>
#include <functional>
#include <vector>
#include <algorithm>
#include <limits>

// Display-only geometry. Never feeds the driving rules or camera state.
namespace perception_bird {
struct Object {
    double x=0,z=0;int category=-1;
    QString id,source;
    bool observed=true;
};
struct Frame {
    std::array<int,6> types{};
    double egoSlot=2.5;
    std::vector<Object> objects;
    bool metric=true;
    QString source,generation;
    double sourceTimeMs=std::numeric_limits<double>::quiet_NaN();
    double sourceFrame=-1;
};
inline Frame fromLanes(const lane_arbitration::Snapshot& scene,double egoX=.5,double previousEgoSlot=2.5) {
    Frame frame;
    frame.egoSlot=previousEgoSlot;
    double n=0,s=0,x=0,ss=0,sx=0;
    for(const auto& track:scene.tracks) {
        if(track.slot<0||track.slot>=6||track.displayState==lane_arbitration::DisplayState::Hidden)continue;
        if(track.observed&&track.displayState==lane_arbitration::DisplayState::Confirmed&&
           track.displayType>=1&&track.displayType<=6)frame.types[size_t(track.slot)]=track.displayType;
        if(std::isfinite(track.layoutX)) {
            ++n;s+=track.slot;x+=track.layoutX;ss+=track.slot*track.slot;sx+=track.slot*track.layoutX;
        }
    }
    const double denominator=n*ss-s*s;
    if(n<2||denominator<=1e-8)return frame;
    const double spacing=(n*sx-s*x)/denominator;
    if(!std::isfinite(spacing)||spacing<=1e-6||!std::isfinite(egoX))return frame;
    frame.egoSlot=(egoX-(x-spacing*s)/n)/spacing;
    return frame;
}
class View {
    struct DisplayObject { Object raw;double x=0,z=0;bool held=false,smoothed=false; };
    struct Track { DisplayObject display;double seen=0,jumpSince=-1; };
    QHash<QString,Track> tracks;
    QString lastSource,lastGeneration;
    double lastTime=-1,lastFrame=-1;
    bool lastMetric=true;
    std::vector<DisplayObject> displayed;
    static bool supported(int c) { return c==0||c==1||c==2||c==4||c==5||c==6; }
    static QString identity(const Object& o) {
        // A source-less measurement is not a persistent identity.
        return o.id.isEmpty()||o.source.isEmpty()?QString():QString::number(o.source.size())+":"+o.source+o.id;
    }
    void updateDisplay(const Frame& frame) {
        const bool clock=!frame.source.isEmpty()&&std::isfinite(frame.sourceTimeMs)&&frame.sourceTimeMs>=0&&
            std::isfinite(frame.sourceFrame)&&frame.sourceFrame>=0;
        const bool reset=!clock||frame.source!=lastSource||frame.generation!=lastGeneration||frame.metric!=lastMetric||
            frame.sourceTimeMs<lastTime||frame.sourceFrame<lastFrame||frame.sourceTimeMs-lastTime>200;
        if(reset){tracks.clear();displayed.clear();}
        if(clock&&!reset&&frame.sourceTimeMs==lastTime&&frame.sourceFrame==lastFrame)return;
        const double dt=reset?0:std::max(0.,frame.sourceTimeMs-lastTime);
        displayed.clear();
        QHash<QString,int> counts;
        for(const auto& o:frame.objects)if(!identity(o).isEmpty())++counts[identity(o)];
        QHash<QString,bool> present;
        for(const auto& o:frame.objects) {
            if(!std::isfinite(o.x)||!std::isfinite(o.z)||!supported(o.category))continue;
            if(clock&&!o.observed)continue; // Only our bounded hold can display an unobserved track.
            DisplayObject d{o,o.x,o.z,!o.observed,false};
            const QString key=identity(o);
            if(clock&&!key.isEmpty()&&counts.value(key)==1&&o.observed) {
                auto it=tracks.find(key);
                double jump=-1;
                if(it!=tracks.end()&&it->display.raw.category==o.category) {
                    const double dx=o.x-it->display.x,dz=o.z-it->display.z;
                    const double distance=std::hypot(dx,dz);
                    double alpha=dt>0?1.-std::exp(-dt/65.):0.;
                    // Suppress one-frame spikes, but follow a persistent relocation within 120ms.
                    if(frame.metric&&distance>2.+35.*dt/1000.) {
                        jump=it->jumpSince<0?frame.sourceTimeMs:it->jumpSince;
                        if(frame.sourceTimeMs-jump>=120)alpha=1.;
                        else if(distance>0)alpha=std::min(alpha,std::max(.25,35.*dt/1000.)/distance);
                    }
                    d.x=it->display.x+dx*alpha;d.z=it->display.z+dz*alpha;
                    d.smoothed=std::hypot(o.x-d.x,o.z-d.z)>.05;
                }
                tracks.insert(key,Track{d,frame.sourceTimeMs,jump});present.insert(key,true);
            } else if(clock&&!key.isEmpty()&&counts.value(key)>1)tracks.remove(key);
            displayed.push_back(d);
        }
        for(auto it=tracks.begin();it!=tracks.end();) {
            const double age=frame.sourceTimeMs-it->seen;
            if(age>200||age<0){it=tracks.erase(it);continue;}
            if(!present.contains(it.key())) {
                auto d=it->display;d.held=true;displayed.push_back(d);
            }
            ++it;
        }
        lastSource=frame.source;lastGeneration=frame.generation;lastTime=frame.sourceTimeMs;
        lastFrame=frame.sourceFrame;lastMetric=frame.metric;
    }
    QHash<QString,QImage> icons;
    QImage icon(DesignView& view,const QString& key,const QColor& ink) {
        Q_UNUSED(view);
        const QString cache=key+ink.name();if(icons.contains(cache))return icons[cache];
        // A bird's-eye panel needs top views. The exported assets are side
        // silhouettes; rotating those would still not make them top views.
        QImage image(64,96,QImage::Format_ARGB32_Premultiplied);image.fill(Qt::transparent);
        QPainter painter(&image);painter.setRenderHint(QPainter::Antialiasing);
        painter.setPen(QPen(ink,3));painter.setBrush(QColor(ink.red(),ink.green(),ink.blue(),40));
        if(key=="two") {
            painter.drawRoundedRect(QRectF(28,5,8,20),3,3);
            painter.drawRoundedRect(QRectF(28,71,8,20),3,3);
            painter.drawRoundedRect(QRectF(23,26,18,43),7,7);
            painter.drawLine(QPointF(17,28),QPointF(47,28));
            painter.drawLine(QPointF(32,17),QPointF(32,26));
        } else {
            const bool bus=key=="bus"||key=="truck";
            const QRectF body(bus?10:13,6,bus?44:38,84);
            painter.drawRoundedRect(body,9,9);
            painter.setBrush(ink);
            painter.drawRoundedRect(QRectF(body.left()+5,18,body.width()-10,12),3,3);
            painter.setBrush(Qt::NoBrush);
            painter.drawRoundedRect(QRectF(body.left()+6,36,body.width()-12,bus?34:26),4,4);
            if(key=="truck")painter.drawLine(QPointF(body.left(),33),QPointF(body.right(),33));
            painter.drawLine(QPointF(body.left()+7,76),QPointF(body.right()-7,76));
            painter.drawLine(QPointF(body.left()-4,29),QPointF(body.left(),29));
            painter.drawLine(QPointF(body.right(),29),QPointF(body.right()+4,29));
        }
        painter.end();
        QRect visible;
        for(int y=0;y<image.height();++y)for(int x=0;x<image.width();++x)
            if(qAlpha(image.pixel(x,y)))visible=visible.united(QRect(x,y,1,1));
        if(!visible.isEmpty())image=image.copy(visible);
        icons.insert(cache,image);return image;
    }
public:
    void paint(QPainter& painter,DesignView& view,const QRectF& source,const QRectF& target,const Frame& frame) {
        updateDisplay(frame);
        // Only the existing single-page perception artwork is replaced.
        if(view.currentPageKey()!=QStringLiteral("single")||source.isEmpty())return;
        QRectF area;
        const double scale=target.width()/source.width();
        const auto r=view.nodeSceneRect(QStringLiteral("3:7711"));
        if(!r.isEmpty()) {
            area=QRectF(target.left()+(r.left()-source.left())*scale,
                target.top()+(r.top()-source.top())*scale,r.width()*scale,r.height()*scale);
        }
        if(area.isEmpty())return;
        area.adjust(2*scale,0,-2*scale,0);
        painter.save();painter.setClipRect(area);painter.fillRect(area,QColor("#303234"));
        painter.setRenderHint(QPainter::Antialiasing);
        const QRectF plot=area.adjusted(4,4*scale,-4,-8*scale);
        painter.setClipRect(plot);
        const double carWidthMeters=1.7,carLengthMeters=4.4;
        const double metersAhead=20.;
        // Display lane width is two sedan widths, a layout convention rather
        // than a measured road width. All geometry uses the same px/m scale.
        const double laneWidthMeters=2.*carWidthMeters;
        const double pixelsPerMeter=qMin(plot.height()/(metersAhead+carLengthMeters),
                                         plot.width()/(3.*laneWidthMeters));
        const double spacing=laneWidthMeters*pixelsPerMeter;
        for(int slot=0;slot<6;++slot) {
            const int type=frame.types[size_t(slot)];if(type<1||type>6)continue;
            const double x=plot.center().x()+(slot-frame.egoSlot)*spacing;
            QPen pen((type==1||type==3||type==5)?QColor("#ffd735"):QColor("#fafafa"),
                qMax(.7,.15*pixelsPerMeter),Qt::SolidLine,Qt::FlatCap);
            if(type==5||type==6){pen.setStyle(Qt::CustomDashLine);pen.setDashPattern({4,3});}
            painter.setPen(pen);
            if(type==1||type==2)for(double offset:{-.15*pixelsPerMeter,.15*pixelsPerMeter})
                painter.drawLine(QPointF(x+offset,plot.top()),QPointF(x+offset,plot.bottom()));
            else painter.drawLine(QPointF(x,plot.top()),QPointF(x,plot.bottom()));
        }
        const double carWidth=carWidthMeters*pixelsPerMeter;
        const double carHeight=carLengthMeters*pixelsPerMeter;
        const double bottom=plot.bottom()-carHeight*.55;
        const double xSpan=plot.width()/(2*pixelsPerMeter);
        painter.setPen(QPen(QColor(180,203,211,60),1,Qt::DotLine));
        QFont rangeFont=painter.font();rangeFont.setPixelSize(qMax(8,qRound(10*scale)));painter.setFont(rangeFont);
        for(int meters:{5,10,15,20}) {
            const double y=bottom-meters*pixelsPerMeter;
            painter.drawLine(QPointF(plot.left(),y),QPointF(plot.right(),y));
            painter.drawText(QRectF(plot.left()+2,y-14*scale,42*scale,14*scale),
                Qt::AlignLeft|Qt::AlignVCenter,QStringLiteral("%1 m").arg(meters));
        }
        painter.setPen(QColor("#b6c7ce"));
        painter.drawText(QRectF(plot.left()+4,plot.top(),plot.width()-8,14*scale),
            Qt::AlignRight|Qt::AlignVCenter,frame.metric?QStringLiteral("米制目标 · 标线示意"):QStringLiteral("距离数据不足 · 标线示意"));
        int edgeIndex=0;
        auto nearest=displayed;
        nearest.erase(std::remove_if(nearest.begin(),nearest.end(),[](const auto& item){
            const auto& o=item.raw;
            return !std::isfinite(o.x)||!std::isfinite(o.z)||o.z<0||
                (o.category!=0&&o.category!=1&&o.category!=2&&o.category!=4&&o.category!=5&&o.category!=6);
        }),nearest.end());
        std::stable_sort(nearest.begin(),nearest.end(),[](const auto& a,const auto& b){
            return std::hypot(a.raw.x,a.raw.z)<std::hypot(b.raw.x,b.raw.z);
        });
        if(nearest.size()>5)nearest.resize(5);
        for(const auto& display:nearest) {
            const auto& object=display.raw;
            if(!frame.metric)break;
            // 几何必须有限且在显示范围内，否则不画。
            if(!std::isfinite(object.x)||!std::isfinite(object.z)||object.z<0)continue;
            // 只画检测结果明确支持的类别。未知类别、以及缺素材的目标一律不画，
            // 不用灰点或其它替代记号冒充已确认目标（行人同样不画）。
            const int category=object.category;
            if(category!=0&&category!=1&&category!=2&&category!=4&&category!=5&&category!=6)continue;
            const QColor ink=display.held?QColor("#aab4bf"):QColor("#fbbf24");
            painter.save();painter.setOpacity(display.held?.38:1.);
            if(std::abs(object.x)>xSpan||object.z>metersAhead) {
                const double edgeX=qBound(plot.left()+30*scale,
                    plot.center().x()+object.x*pixelsPerMeter,plot.right()-30*scale);
                const double y=plot.top()+(12+(edgeIndex++%3)*17)*scale;
                QFont font=painter.font();font.setPixelSize(qMax(10,int(12*scale)));painter.setFont(font);painter.setPen(ink);
                const QString distance=QString::number(std::hypot(object.x,object.z),'f',0)+"m";
                painter.drawText(QRectF(edgeX-40*scale,y-10*scale,80*scale,18*scale),Qt::AlignCenter,
                    QStringLiteral("↑ ")+distance+(display.held?QStringLiteral(" 暂留"):display.smoothed?QStringLiteral(" 平滑"):QString()));
                painter.restore();continue;
            }
            const QImage art=icon(view,category==1?"bus":category==2?"truck":category>=4?"two":"car",ink);
            if(art.isNull()){painter.restore();continue;}
            const QPointF at(plot.center().x()+display.x*pixelsPerMeter,
                bottom-display.z*pixelsPerMeter);
            const double width=carWidth*(category==1||category==2?1.4:category>=4?.65:1.);
            const double height=carHeight*(category==1?2.2:category==2?1.8:category>=4?.5:1.);
            painter.drawImage(QRectF(at.x()-width/2,at.y()-height/2,width,height),art);
            painter.restore();
        }
        painter.drawImage(QRectF(plot.center().x()-carWidth/2,bottom-carHeight/2,carWidth,carHeight),icon(view,"car",Qt::white));
        painter.restore();
    }
};
}
