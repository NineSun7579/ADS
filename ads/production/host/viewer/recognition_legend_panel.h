#pragma once
#include "panel_frame.h"
#include <QPainter>
#include <QFontMetricsF>
#include <QVector>
#include <QRectF>
#include <QString>
#include <QColor>

// Geometry is shared by painting and semantic visibility checks. No paging state.
namespace recognition_legend_panel {
struct Entry {
    int sourceIndex;
    QString text;
    QColor color;
    QRectF rect, swatch, label;
    int fontSize;
};
struct Layout {
    QRectF bounds, title, subtitle;
    QVector<QRectF> panels, headings;
    QVector<Entry> entries;
    bool compact=false;
    int columns=3, titleFontSize=22, headingFontSize=14;
};
template<class Entries> inline Layout layout(const QRectF& rect,const Entries& source) {
    Layout l;l.bounds=rect;l.compact=rect.height()<220;
    const qreal x=rect.x(),y=rect.y(),w=rect.width();
    l.columns=l.compact?4:3;
    l.titleFontSize=l.compact?16:22;l.headingFontSize=l.compact?10:14;
    l.title={x+6,y+(l.compact?3:6),w-12,l.compact?20.:32.};
    const qreal margin=l.compact?6:10;
    const qreal sectionTop=l.title.bottom()+(l.compact?1:5);
    const qreal headingHeight=l.compact?12:20;
    const qreal sectionGap=l.compact?1:5;
    const qreal rowHeight=(rect.bottom()-(l.compact?2:margin)-sectionTop-2*headingHeight-sectionGap)/(l.compact?5:7);
    for(int section=0;section<2;++section) {
        const int count=section?7:11,columns=l.columns;
        const int rows=(count+columns-1)/columns;
        const qreal top=sectionTop+(section?headingHeight+(l.compact?3:4)*rowHeight+sectionGap:0);
        const QRectF panel(x+margin,top,w-2*margin,headingHeight+rows*rowHeight);
        const QRectF heading(panel.x(),top,panel.width(),headingHeight);
        const qreal rowTop=heading.bottom(),columnWidth=panel.width()/columns;
        l.panels.push_back(panel);l.headings.push_back(heading);
        for(int i=0;i<count;++i) {
            const int index=(section?13:1)+i;
            const QRectF row(panel.x()+(i%columns)*columnWidth,
                             rowTop+(i/columns)*rowHeight,columnWidth-2,rowHeight-0.1);
            const qreal sw=l.compact?7:11,gap=l.compact?3:5;
            const qreal swatchHeight=l.compact?7:11;
            const QRectF swatch(row.x()+1,row.center().y()-swatchHeight/2,sw,swatchHeight);
            const QRectF label(swatch.right()+gap,row.y(),row.right()-swatch.right()-gap-1,row.height());
            l.entries.push_back({index,source[index].text,source[index].color,row,swatch,label,l.compact?10:15});
        }
    }
    return l;
}
inline void paint(QPainter& p,const Layout& l) {
    p.save();p.setClipRect(l.bounds,Qt::IntersectClip);
    const QColor blue("#5573ff"),ink("#253148");
    const auto box=[&](QRectF r,QColor fill,QColor line,qreal radius,qreal width=1) {
        p.setBrush(fill);p.setPen(QPen(line,width));p.drawRoundedRect(r,radius,radius);
    };
    const auto text=[&](QRectF r,const QString& value,int size,bool bold=false) {
        QFont f("Noto Sans CJK SC");f.setPixelSize(size);f.setWeight(bold?QFont::Bold:QFont::Medium);
        p.setFont(f);p.setPen(ink);
        const auto inkRect=QFontMetricsF(f).tightBoundingRect(value);
        p.drawText(QPointF(r.left(),r.center().y()-inkRect.center().y()),value);
    };
    // Erase the parent's older outline, including its antialiased corner pixels.
    p.fillRect(l.bounds,Qt::white);
    panel_frame::drawFrame(p,l.bounds,10,Qt::white);
    box(l.title,QColor("#f8faff"),Qt::transparent,5);
    box({l.title.x(),l.title.y(),3,l.title.height()},blue,Qt::transparent,1);
    text(l.title.adjusted(8,0,-2,0),QStringLiteral("识别对照框"),l.titleFontSize,true);
    for(int i=0;i<2;++i) {
        box(l.headings[i],QColor("#f8faff"),Qt::transparent,3);
        text(l.headings[i].adjusted(4,0,0,0),i?QStringLiteral("道路标线"):QStringLiteral("目标类别"),l.headingFontSize,true);
    }
    for(int i=0;i<l.entries.size();++i) {
        const auto& e=l.entries[i];
        box(e.swatch,e.color,QColor("#aebbd0"),2);
        text(e.label,e.text,e.fontSize);
    }
    p.restore();
}
}
