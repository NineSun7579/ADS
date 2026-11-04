#pragma once
#include "lane_arbitration.h"
#include "lane_style.h"
#include <QImage>
#include <QMetaType>
Q_DECLARE_METATYPE(lane_arbitration::Observation)

namespace lane_arbitration {
// Compatibility for sources without logits. Confidence is explicitly absent;
// lane6 inference supplies its true softmax observation through the signal.
inline Observation fromMask(const QImage& mask) {
    if(mask.isNull())return {};
    const QRect source=mask.height()>=560?QRect(0,272,std::min(640,mask.width()),288):mask.rect();
    const QImage rgb=mask.copy(source).scaled(432,144,Qt::IgnoreAspectRatio,Qt::FastTransformation)
        .convertToFormat(QImage::Format_ARGB32);
    std::vector<unsigned char> labels(432*144);
    for(int y=0;y<144;++y) {
        const auto* row=reinterpret_cast<const QRgb*>(rgb.constScanLine(y));
        for(int x=0;x<432;++x) {
            if(qAlpha(row[x])<24)continue;
            int best=0,error=1600;
            for(int c=1;c<=6;++c) {
                const QRgb color=lane_style::rgba(c);
                const int r=qRed(row[x])-qRed(color),g=qGreen(row[x])-qGreen(color),b=qBlue(row[x])-qBlue(color);
                const int value=r*r+g*g+b*b;if(value<error){error=value;best=c;}
            }
            labels[y*432+x]=static_cast<unsigned char>(best);
        }
    }
    return trace(labels.data(),432,144);
}
}
