#pragma once

#include <QImage>
#include <QRectF>
#include <Qt>
#include <array>
#include <cmath>

// Display copies only. Acquisition/publication and fusion always retain originals.
namespace hdmi_display_gamma {
inline double normalized(double value) {
    if (!std::isfinite(value)) return 1.0;
    return std::round(qBound(0.3, value, 3.0) * 10.0) / 10.0;
}

class Lut {
public:
    explicit Lut(double value = 1.0) { set(value); }
    bool set(double value) {
        value = normalized(value);
        if (value == m_gamma) return false;
        m_gamma = value;
        for (int i = 0; i < 256; ++i)
            m_bytes[size_t(i)] = static_cast<uchar>(std::lround(255.0 * std::pow(i / 255.0, 1.0 / value)));
        return true;
    }
    double value() const { return m_gamma; }
    uchar operator[](int value) const { return m_bytes[size_t(value)]; }
private:
    double m_gamma = 0.0;
    std::array<uchar, 256> m_bytes{};
};

class ImageCache {
public:
    const QImage& image(const QImage& original, const Lut& lut) {
        if (original.isNull() || lut.value() == 1.0) {
            clear();
            return original;
        }
        if (m_key == original.cacheKey() && m_gamma == lut.value()) return m_image;
        // RGB888 is the native/fusion path. Other formats normalize once per
        // frame to straight-alpha RGBA, avoiding premultiplied-alpha corruption.
        const bool rgb = original.format() == QImage::Format_RGB888;
        m_image = rgb ? original.copy() : original.convertToFormat(QImage::Format_RGBA8888);
        const int channels = rgb ? 3 : 4;
        for (int y = 0; y < m_image.height(); ++y) {
            uchar* pixel = m_image.scanLine(y);
            for (int x = 0; x < m_image.width(); ++x, pixel += channels) {
                pixel[0] = lut[pixel[0]];
                pixel[1] = lut[pixel[1]];
                pixel[2] = lut[pixel[2]];
            }
        }
        m_key = original.cacheKey();
        m_gamma = lut.value();
        ++m_transforms;
        return m_image;
    }
    void clear() { m_key = 0; m_gamma = 0; m_image = {}; }
    unsigned transforms() const { return m_transforms; }
private:
    qint64 m_key = 0;
    double m_gamma = 0;
    QImage m_image;
    unsigned m_transforms = 0;
};

enum Action { None, Decrease, Increase, Reset };
inline Action keyAction(int key) {
    if (key == Qt::Key_BracketLeft) return Decrease;
    if (key == Qt::Key_BracketRight) return Increase;
    if (key == Qt::Key_Backslash) return Reset;
    return None;
}
inline double adjusted(double value, Action action) {
    return normalized(action == Reset ? 1.0 : value + (action == Increase ? 0.1 : action == Decrease ? -0.1 : 0.0));
}

// Coordinates are relative to the authoritative fusion frame (1032 px wide).
// The controls occupy its unused header, never frame pixels or raw labels.
struct Controls {
    QRectF minus, value, plus, reset;
    explicit Controls(const QRectF& frame) {
        const qreal scale = frame.width() / 1032.0;
        const qreal left = frame.right() - 312 * scale;
        const qreal top = frame.top() - 37.5 * scale;
        minus = QRectF(left, top, 48 * scale, 32 * scale);
        value = QRectF(left + 52 * scale, top, 116 * scale, 32 * scale);
        plus = QRectF(left + 172 * scale, top, 48 * scale, 32 * scale);
        reset = QRectF(left + 224 * scale, top, 76 * scale, 32 * scale);
    }
    Action hit(const QPointF& point) const {
        if (minus.contains(point)) return Decrease;
        if (plus.contains(point)) return Increase;
        if (reset.contains(point)) return Reset;
        return None;
    }
};
} // namespace hdmi_display_gamma
