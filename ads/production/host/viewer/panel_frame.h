#pragma once
#include <QPainter>

// Call in screen coordinates, before applying a panel's reference transform.
namespace panel_frame {
inline void drawFrame(QPainter& p, const QRectF& bounds, qreal radius,
                      QColor fill=QColor("#f8faff")) {
    if(bounds.isEmpty())return;
    p.save();
    p.setRenderHint(QPainter::Antialiasing);
    QPen pen(QColor("#5573ff"),2,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin);
    pen.setCosmetic(true);
    p.setPen(pen);p.setBrush(fill);
    // The centered stroke stays entirely inside the panel's outer bounds.
    p.drawRoundedRect(bounds.adjusted(1,1,-1,-1),radius,radius);
    p.restore();
}
}
