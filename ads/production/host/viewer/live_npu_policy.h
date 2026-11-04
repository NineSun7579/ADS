#pragma once
#include <QImage>
#include <QString>
#include <cmath>
namespace live_npu {
constexpr unsigned CameraMask=0x1du;
inline bool backgroundCamera(int camera,bool enabled) {
    return enabled&&camera>=0&&camera<6&&(CameraMask&(1u<<camera));
}
inline unsigned captureMask(unsigned displayMask,bool enabled) {return displayMask|(enabled?CameraMask:0u);}
inline bool decodeOutput(bool synthetic){return !synthetic;}
inline bool render(bool fourPage,bool frozenReplay,bool synthetic=false) {
    return fourPage&&!frozenReplay&&!synthetic;
}
inline bool renderView(const QString& designPage,bool exactFour,bool panorama,bool frozenReplay) {
    return render(exactFour&&!panorama&&(designPage.isEmpty()||designPage==QStringLiteral("four")),frozenReplay);
}
inline double completedFps(double completed,qint64 sampleAgeMs) {
    return sampleAgeMs>=0&&sampleAgeMs<1500&&std::isfinite(completed)&&completed>0?completed:0;
}
}
