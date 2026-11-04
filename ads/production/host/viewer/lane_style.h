#pragma once
#include <QColor>
#include <QString>
#include <array>
namespace lane_style {
// Shared by the lane decoder and the legend. Class 0 and 7 are hidden.
inline QRgb rgba(int id) {
    static const std::array<QRgb,9> colors{{0,qRgba(255,255,0,120),qRgba(0,255,255,120),
        qRgba(255,128,0,120),qRgba(0,200,0,120),qRgba(255,0,255,120),
        qRgba(0,128,255,120),0,qRgba(255,255,255,120)}};
    return id>=0 && id<int(colors.size())?colors[id]:0;
}
inline QString label(int id) {
    static const char* names[]={"背景","双黄线","双白线","单黄线",
        "单白线","黄虚线","白虚线","其他标线","斑马线"};
    return id>=0 && id<9?QString::fromUtf8(names[id]):QString();
}
}
