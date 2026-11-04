#pragma once
#include "acquisition_epoch.h"
#include <QRectF>
#include <QString>

namespace display_source {
enum class Source { Cameras, PhysicalHdmi, Replay };
struct Selection {
    Source source=Source::Cameras;
    quint64 generation=1;
    void select(Source next) { if(source!=next){source=next;++generation;} }
    bool replay(bool active) const { return source==Source::Replay && active; }
    bool physical() const { return source==Source::PhysicalHdmi; }
};
template<class Admit,class Select,class Page>
bool action(const QString& name,Admit admit,Select select,Page page) {
    if(name==QStringLiteral("page:single")) {
        if(admit()) {select(Source::PhysicalHdmi);page(QStringLiteral("single"));}
        return true;
    }
    if(name==QStringLiteral("source:replay")) {
        return true; // Production consumes and rejects the retired action.
    }
    return false;
}
inline bool pairReady(const acquisition::Ticket& ticket,qint64 now,qint64 leftMs,qint64 rightMs,
                      bool native,int leftGeneration,int rightGeneration,bool leftPixels,bool rightPixels) {
    return native && ticket.mask==0x30u && ticket.metricUnsafeMask==0x30u && acquisition::current(ticket) &&
        leftGeneration==rightGeneration && leftPixels && rightPixels &&
        leftMs>0 && rightMs>0 && now>=leftMs && now>=rightMs &&
        now-leftMs<1000 && now-rightMs<1000 && qAbs(leftMs-rightMs)<=100;
}
inline QRectF fit(const QRectF& slot,const QSizeF& size) {
    if(slot.isEmpty()||size.isEmpty())return {};
    const qreal scale=qMin(slot.width()/size.width(),slot.height()/size.height());
    const QSizeF extent=size*scale;
    return QRectF(slot.center()-QPointF(extent.width()/2,extent.height()/2),extent);
}
}
