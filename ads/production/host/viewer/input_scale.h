#pragma once

// 统一输入归一化：不管来源是相机、HDMI 拼合还是视频文件，送模型前统一到 480p(640x480)。
//
// 开关：环境变量 ADS_INPUT_480P
//   stretch 拉伸填满目标格（默认，也是旧相机路径 IgnoreAspectRatio 的行为）
//   fit     等比缩放 + 灰边（保留比例，但画面不填满格）
//   crop    等比放大填满后居中裁剪（保留比例，但裁掉边缘）
//   off     不处理，保留旧行为
//
// 默认选 stretch 的原因：叠加层把检测框按"整格 ↔ 整格"线性映射到屏幕
// （见 main-bev.cpp placeDetection 的 hdmiModelPad / hdmiAnalyticsHeight），
// 所以模型格子里必须装下整幅画面，否则框会错位。fit/crop 会改变内容占比，
// 只有在同步改映射表时才能用。
//
// 之所以需要它：HDMI 实际输入的分辨率不一定等于 640x480（相机几何另有 1280x720 档），
// 而模型输入、检测框坐标（640x640 含 80px 垂直补边）、单目测距全按 640x480 内容区约定。

#include <QByteArray>
#include <QImage>
#include <QPainter>
#include <QtGlobal>
#include <cstdio>

namespace input480 {

constexpr int Width = 640;
constexpr int Height = 480;
constexpr QRgb PadColor = qRgb(114, 114, 114); // 与视频路径 ffmpeg pad 的 0x727272 一致

enum class Mode { Off, Fit, Stretch, Crop };

inline const char *name(Mode mode) {
    switch (mode) {
    case Mode::Off: return "off";
    case Mode::Fit: return "fit";
    case Mode::Stretch: return "stretch";
    case Mode::Crop: return "crop";
    }
    return "fit";
}

inline Mode parse(const QByteArray &text, bool *ok = nullptr) {
    const QByteArray value = text.trimmed().toLower();
    if (ok) *ok = true;
    if (value.isEmpty() || value == "stretch") return Mode::Stretch;
    if (value == "off") return Mode::Off;
    if (value == "fit") return Mode::Fit;
    if (value == "crop") return Mode::Crop;
    if (ok) *ok = false;
    return Mode::Stretch;
}

// 进程内只读一次环境变量；启动时另有一行显式日志。
inline Mode mode() {
    static const Mode cached = [] {
        const QByteArray raw = qgetenv("ADS_INPUT_480P");
        bool ok = true;
        const Mode parsed = parse(raw, &ok);
        if (!ok)
            std::fprintf(stderr, "[input480] unknown ADS_INPUT_480P='%s', falling back to fit\n",
                         raw.constData());
        return parsed;
    }();
    return cached;
}

// 首次遇到非 640x480 输入时打一行，便于确认现场实际分辨率。
inline void logOnce(const char *where, const QSize &source) {
    static bool logged = false;
    if (logged) return;
    logged = true;
    std::fprintf(stderr, "[input480] mode=%s where=%s source=%dx%d target=%dx%d\n",
                 name(mode()), where, source.width(), source.height(), Width, Height);
}

inline QImage toRgb888(const QImage &source) {
    return source.format() == QImage::Format_RGB888 ? source
                                                    : source.convertToFormat(QImage::Format_RGB888);
}

inline QImage canvas() {
    QImage result(Width, Height, QImage::Format_RGB888);
    result.fill(PadColor);
    return result;
}

// 单幅图像归一化到 640x480。
inline QImage normalize(const QImage &source, Mode mode) {
    if (source.isNull() || mode == Mode::Off) return source;
    if (source.width() == Width && source.height() == Height) return source;
    logOnce("single", source.size());

    const QImage rgb = toRgb888(source);
    if (mode == Mode::Stretch)
        // Qt's smooth scaler promotes RGB888 to RGB32. Keep the analytics
        // wire format after resizing (notably C3/C4's 320x240 RAW frames).
        return toRgb888(rgb.scaled(Width, Height, Qt::IgnoreAspectRatio, Qt::SmoothTransformation));

    QImage out = canvas();
    QPainter painter(&out);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    if (mode == Mode::Fit) {
        const QImage fitted = rgb.scaled(Width, Height, Qt::KeepAspectRatio,
                                         Qt::SmoothTransformation);
        painter.drawImage((Width - fitted.width()) / 2, (Height - fitted.height()) / 2, fitted);
    } else { // Crop
        const QImage filled = rgb.scaled(Width, Height, Qt::KeepAspectRatioByExpanding,
                                         Qt::SmoothTransformation);
        painter.drawImage(0, 0, filled, (filled.width() - Width) / 2, (filled.height() - Height) / 2,
                          Width, Height);
    }
    return out;
}

// 左右两半（任意分辨率）拼成"HDMI 满屏"的规范版式：640x480 画布，左右各 320x240，
// 从第 120 行起（上下各 120 行灰边）。这个版式是硬约定，不能改成填满整幅：
//   模型输入 = 640x640（640x480 内容上下各补 80 行）→ 内容落在 200..440 行
//   叠加层换算 = (y - (80+120)) / 240，见 main-bev.cpp 的 placeDetection / hdmiModelPad。
// 单幅图像仍然按 normalize() 填满 640x480（那条路径的换算是 (y-80)/480）。
inline QImage composePair(const QImage &left, const QImage &right, Mode mode) {
    if (left.isNull() || right.isNull() || mode == Mode::Off) return {};
    const QImage l = toRgb888(left), r = toRgb888(right);
    if (l.isNull() || r.isNull()) return {};

    constexpr int CellWidth = Width / 2; // 320
    constexpr int CellHeight = 240;      // 两半合起来占 240 行
    constexpr int CellTop = (Height - CellHeight) / 2; // 120

    logOnce("hdmi-pair", QSize(l.width() + r.width(), qMax(l.height(), r.height())));

    QImage out = canvas();
    QPainter painter(&out);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);

    auto drawHalf = [&](const QImage &source, int cellLeft) {
        if (source.isNull()) return;
        if (mode == Mode::Stretch) {
            painter.drawImage(QRect(cellLeft, CellTop, CellWidth, CellHeight),
                              source.scaled(CellWidth, CellHeight, Qt::IgnoreAspectRatio,
                                            Qt::SmoothTransformation));
        } else if (mode == Mode::Crop) {
            const QImage cover = source.scaled(CellWidth, CellHeight,
                                               Qt::KeepAspectRatioByExpanding,
                                               Qt::SmoothTransformation);
            painter.drawImage(QRectF(cellLeft, CellTop, CellWidth, CellHeight), cover,
                              QRectF((cover.width() - CellWidth) / 2.0,
                                     (cover.height() - CellHeight) / 2.0,
                                     CellWidth, CellHeight));
        } else { // Fit：与显示端把整幅半帧等比放进自己那一格的做法保持一致
            const QImage fitted = source.scaled(CellWidth, CellHeight, Qt::KeepAspectRatio,
                                                Qt::SmoothTransformation);
            painter.drawImage(cellLeft + (CellWidth - fitted.width()) / 2,
                              CellTop + (CellHeight - fitted.height()) / 2, fitted);
        }
    };
    drawHalf(l, 0);
    drawHalf(r, CellWidth);
    return out;
}

} // namespace input480
