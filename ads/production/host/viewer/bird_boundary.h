#pragma once

#include "surround_engine.h"
#include <QColor>
#include <cmath>
#include <algorithm>

namespace surround {

inline QPointF birdFarSamplePoint(double x,double y,int size,const Configuration&config,double*blur=nullptr){
    const double half=size*.5,dx=x-half,dy=y-half,r=std::hypot(dx,dy)/half;
    const double near=config.birdNearFraction,extent=config.birdCircular?config.birdRadiusFraction:1.;
    const double span=extent-near;
    if(blur)*blur=0;
    if(!config.birdFarStyle||span<=0||r<=near)return QPointF(x,y);
    const double t=std::clamp((r-near)/span,0.,1.);
    const double sourceRadius=r-config.birdFarStretch*span*t*t;
    if(blur)*blur=config.birdFarBlurPx*t*t;
    return QPointF(half+dx*sourceRadius/r,half+dy*sourceRadius/r);
}

// Frozen visual preview only. Edit-mode coordinates remain in the original plane.
inline void applyBirdFarStyle(QImage&image,const Configuration&config){
    if(!config.birdFarStyle||image.isNull())return;
    const auto format=image.format();const QImage source=image.convertToFormat(QImage::Format_RGB32);
    QImage output=source.copy();const int size=source.width();
    const auto sample=[&](double x,double y){
        x=std::clamp(x,0.,double(source.width()-1));y=std::clamp(y,0.,double(source.height()-1));
        const int x0=int(x),y0=int(y),x1=std::min(x0+1,source.width()-1),y1=std::min(y0+1,source.height()-1);
        const double fx=x-x0,fy=y-y0;
        const QRgb pixels[]={source.pixel(x0,y0),source.pixel(x1,y0),source.pixel(x0,y1),source.pixel(x1,y1)};
        const double weights[]={(1-fx)*(1-fy),fx*(1-fy),(1-fx)*fy,fx*fy};
        std::array<double,3>rgb{};
        for(int i=0;i<4;++i){rgb[0]+=qRed(pixels[i])*weights[i];rgb[1]+=qGreen(pixels[i])*weights[i];rgb[2]+=qBlue(pixels[i])*weights[i];}
        return rgb;
    };
    for(int y=0;y<source.height();++y){
        auto*row=reinterpret_cast<QRgb*>(output.scanLine(y));
        for(int x=0;x<source.width();++x){
            double blur=0;const auto point=birdFarSamplePoint(x+.5,y+.5,size,config,&blur);
            if(point==QPointF(x+.5,y+.5)&&blur==0)continue;
            auto rgb=sample(point.x()-.5,point.y()-.5);
            if(blur>0){
                for(auto&channel:rgb)channel*=.4;
                for(const auto&offset:{QPointF(blur,0),QPointF(-blur,0),QPointF(0,blur),QPointF(0,-blur)}){
                    const auto other=sample(point.x()-.5+offset.x(),point.y()-.5+offset.y());
                    for(int c=0;c<3;++c)rgb[c]+=.15*other[c];
                }
            }
            row[x]=qRgb(qRound(rgb[0]),qRound(rgb[1]),qRound(rgb[2]));
        }
    }
    image=output.convertToFormat(format);
}

// Pixel-space coordinates, with the canvas center at (size*.5, size*.5).
// Configuration::validate enforces the radius/feather ranges.
inline double birdBoundaryAlpha(double x, double y, int size, bool enabled,
                                double radiusFraction, double featherFraction) {
    if (!enabled) return 1.0;
    if (size <= 0) return 0.0;
    const double half = size * .5;
    const double radius = half * radiusFraction;
    const double feather = half * featherFraction;
    const double distance = std::hypot(x - half, y - half);
    if (distance >= radius) return 0.0;
    if (feather <= 0.0 || distance <= radius - feather) return 1.0;
    const double t = (distance - (radius - feather)) / feather;
    return 1.0 - t * t * (3.0 - 2.0 * t);
}

// Preserve format: opaque images fade RGB to black; images with an alpha
// channel fade only alpha (straight RGB stays unchanged, avoiding double fade).
// QImage handles premultiplied storage through pixelColor/setPixelColor.
// Square canvas size comes from image.width(), independent of config.birdSize.
// Sample pixel centers, matching fragment coordinates.
inline void applyBirdBoundary(QImage &image, const Configuration &config) {
    if (!config.birdCircular || image.isNull()) return;
    const int size = image.width();
    const bool hasAlpha = image.hasAlphaChannel();
    for (int y = 0; y < image.height(); ++y) {
        if (image.format() == QImage::Format_RGB888) {
            uchar *row = image.scanLine(y);
            for (int x = 0; x < image.width(); ++x) {
                const double alpha = birdBoundaryAlpha(x + .5, y + .5, size, true,
                    config.birdRadiusFraction, config.birdFeatherFraction);
                for (int c = 0; c < 3; ++c)
                    row[3 * x + c] = uchar(std::lround(row[3 * x + c] * alpha));
            }
        } else {
            for (int x = 0; x < image.width(); ++x) {
                const double alpha = birdBoundaryAlpha(x + .5, y + .5, size, true,
                    config.birdRadiusFraction, config.birdFeatherFraction);
                if (alpha == 1.0) continue;
                QColor color = image.pixelColor(x, y);
                if (hasAlpha)
                    color.setAlpha(int(std::lround(color.alpha() * alpha)));
                else
                    color.setRgb(int(std::lround(color.red() * alpha)),
                                 int(std::lround(color.green() * alpha)),
                                 int(std::lround(color.blue() * alpha)));
                image.setPixelColor(x, y, color);
            }
        }
    }
}

} // namespace surround
