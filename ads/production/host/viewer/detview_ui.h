#pragma once

#include <QPainter>
#include <QPainterPath>
#include <QRect>
#include <QString>
#include <QStringList>
#include <QSize>
#include <algorithm>

// Presentation only. No camera, model or device state is owned by this module.
namespace detview_ui {
constexpr int kMargin = 20;
constexpr int kHeaderHeight = 64;
constexpr int kToolbarHeight = 100;
constexpr int kSignalSize = 32;
constexpr int kSignalGap = 12;
constexpr int kSignalFrameWidth = 255;
constexpr int kSignalFrameHeight = 51;

struct Layout {
    QRect header;
    QRect content;
    QRect toolbar;
    QRect signalFrame;
    QRect laneCard;
    QRect infoCard;
    QRect statusCard;
    QRect backButton;
};

inline int popcount(int mask) {
    int count = 0;
    for (; mask; mask &= mask - 1) ++count;
    return count;
}

inline Layout layout(const QSize& size, int paneMask, bool hdmiFull, bool settings) {
    Q_UNUSED(paneMask);
    const int margin = size.width() < 600 ? 12 : kMargin;
    const int header = size.height() < 640 ? 56 : kHeaderHeight;
    const int toolbar = size.width() < 840 ? 168 : kToolbarHeight;
    const int contentTop = header + margin;
    const int bottomReserved = std::max(toolbar, 72) + margin;
    const int contentHeight = std::max(1, size.height() - contentTop - bottomReserved);
    const bool landscape = size.width() >= 900 && size.height() >= 560;
    const int sideWidth = landscape && !settings && hdmiFull ? 116 : 0;
    const bool sidePanels = sideWidth > 0;
    const int sideGap = sideWidth ? 12 : 0;
    QRect content(margin, contentTop,
                  std::max(1, size.width() - 2 * margin - sideWidth - sideGap), contentHeight);
    Layout result{QRect(0, 0, size.width(), header), content,
                  QRect(0, size.height() - toolbar, size.width(), toolbar), {}, {}, {}, {}, {}};
    if (sidePanels) {
        const int x = size.width() - margin - sideWidth;
        const int gap = 12;
        const int h = (contentHeight - gap) / 2;
        result.infoCard = QRect(x, content.y(), sideWidth, h);
        result.statusCard = QRect(x, content.y() + h + gap, sideWidth, contentHeight - h - gap);
    }
    if (hdmiFull && content.width() >= 375) {
        result.laneCard = QRect(content.left() + 8, content.top() + 8, 88, 51);
        result.signalFrame = QRect(result.laneCard.right() + 9, content.top() + 8,
                                   kSignalFrameWidth, kSignalFrameHeight);
        result.backButton = QRect(margin, 8, 76, 48);
    } else {
        result.backButton = QRect(margin, (header - 48) / 2, 76, 48);
    }
    return result;
}

inline bool contains(const Layout& l, const QPoint& point) {
    return l.signalFrame.isValid() && l.signalFrame.contains(point);
}

inline QColor foreground() { return QColor("#0e1115"); }
inline QColor muted() { return QColor("#64748b"); }
inline QColor primary() { return QColor("#4285f4"); }
inline QColor border() { return QColor("#dbe4f0"); }
inline QColor surface() { return QColor("#f1f6fd"); }

inline void text(QPainter& p, const QRect& rect, const QString& value,
                 int pixels = 16, const QColor& color = foreground(), bool bold = false,
                 int alignment = Qt::AlignLeft | Qt::AlignVCenter) {
    p.save();
    QFont font;
    font.setPixelSize(pixels);
    font.setBold(bold);
    p.setFont(font);
    p.setPen(color);
    if (alignment & Qt::TextWordWrap)
        p.drawText(rect, alignment, value);
    else
        p.drawText(rect, alignment | Qt::TextSingleLine,
                   QFontMetrics(font).elidedText(value, Qt::ElideRight, std::max(0, rect.width())));
    p.restore();
}

inline void card(QPainter& p, const QRect& rect, const QColor& fill = QColor(255, 255, 255, 225),
                 const QColor& stroke = border(), int radius = 8) {
    p.save();
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(QPen(stroke, 1));
    p.setBrush(fill);
    p.drawRoundedRect(rect, radius, radius);
    p.restore();
}

inline void arrow(QPainter& p, const QRectF& rect, bool right, const QColor& color) {
    p.save();
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(QPen(color, 2, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    const QPointF center = rect.center();
    const double sign = right ? 1 : -1;
    p.drawLine(QPointF(center.x() - sign * 6, center.y()),
               QPointF(center.x() + sign * 6, center.y()));
    p.drawLine(QPointF(center.x() + sign * 2, center.y() - 4),
               QPointF(center.x() + sign * 6, center.y()));
    p.drawLine(QPointF(center.x() + sign * 2, center.y() + 4),
               QPointF(center.x() + sign * 6, center.y()));
    p.restore();
}

inline void signal(QPainter& p, const QRect& rect, bool right, bool on) {
    p.save();
    p.setRenderHint(QPainter::Antialiasing);
    const QColor inactive("#b7c0cb");
    p.setPen(QPen(on ? QColor("#f59e0b") : QColor("#d5dce5"), 2));
    p.setBrush(on ? QColor("#fbbc05") : QColor(222, 228, 236, 170));
    p.drawEllipse(rect);
    arrow(p, rect, right, on ? QColor("#ffffff") : inactive);
    p.restore();
}

inline QRect signalRect(const Layout& l, bool right) {
    const int left = l.signalFrame.left() + 22;
    return QRect(left + (right ? kSignalSize + kSignalGap : 0),
                 l.signalFrame.top() + (l.signalFrame.height() - kSignalSize) / 2,
                 kSignalSize, kSignalSize);
}

inline bool selfTest() {
    const auto l = layout(QSize(1920, 1080), 0x3f, true, false);
    const auto left = signalRect(l, false);
    const auto right = signalRect(l, true);
    if (left.size() != QSize(32, 32) || right.size() != QSize(32, 32)) return false;
    if (right.left() - left.right() - 1 != 12) return false;
    if (left.x() - l.signalFrame.x() != 22) return false;
    if (left.isNull() || right.isNull()) return false;
    if (l.signalFrame.width() != 255 || l.signalFrame.height() != 51) return false;
    if (l.infoCard.isNull() || l.statusCard.isNull()) return false;
    if (l.infoCard.left() <= l.content.right() || std::abs(l.infoCard.height() - l.statusCard.height()) > 1) return false;
    if (l.backButton.width() < 48 || l.backButton.height() < 48) return false;
    const auto six = layout(QSize(1920, 1080), 0x3f, false, false);
    if (six.signalFrame.isValid()) return false;
    if (six.infoCard.isValid()) return false;
    const auto portrait = layout(QSize(720, 1280), 0x3f, true, false);
    if (portrait.signalFrame.size() != QSize(255, 51) || portrait.infoCard.isValid()) return false;
    const auto shortScreen = layout(QSize(1920, 540), 0x3f, true, false);
    if (!shortScreen.signalFrame.isValid() || shortScreen.infoCard.isValid()) return false;
    if (shortScreen.backButton.width() < 48 || shortScreen.backButton.height() < 48) return false;
    for (const QSize screen : {QSize(1280,720), QSize(1920,1080), QSize(720,1280), QSize(1920,540)}) {
        const auto candidate = layout(screen, 0x3f, true, false);
        const QRect bounds(QPoint(), screen);
        if (!bounds.contains(candidate.content) || candidate.content.intersects(candidate.toolbar)) return false;
        if (!candidate.content.contains(candidate.laneCard) || !candidate.content.contains(candidate.signalFrame)) return false;
        if (candidate.laneCard.intersects(candidate.signalFrame)) return false;
        if (!candidate.signalFrame.contains(signalRect(candidate, false)) ||
            !candidate.signalFrame.contains(signalRect(candidate, true))) return false;
        const int columns = screen.width() < 840 ? 5 : 9;
        const int cell = screen.width() / columns;
        const QRect footer(20, candidate.toolbar.y() + (columns == 5 ? 144 : 76), screen.width() - 40, 18);
        if (!candidate.toolbar.contains(footer)) return false;
        for (int index = 0; index < 9; ++index) {
            const QRect button((index % columns) * cell + 6, candidate.toolbar.y() + 8 + (index / columns) * 68, cell - 12, 60);
            if (!candidate.toolbar.contains(button) || button.intersects(footer)) return false;
        }
    }
    fprintf(stderr, "DETVIEW_UI_LAYOUT_SELFTEST_PASS\n");
    return true;
}

struct MonitorState {
    QString title;
    QString source;
    QString model;
    QString status;
    QString detail;
    QString channel;
    int detectionCount = 0;
    bool leftSignal = false;
    bool rightSignal = false;
    bool paused = false;
    bool error = false;
    bool hdmiFull = false;
};

inline void paintMonitor(QPainter& p, const QSize& size, const Layout& l,
                         const MonitorState& state, bool help) {
    p.save();
    p.fillRect(l.header, Qt::white);
    p.fillRect(l.toolbar, Qt::white);
    p.setPen(border());
    p.drawLine(l.header.bottomLeft(), l.header.bottomRight());
    p.drawLine(l.toolbar.topLeft(), l.toolbar.topRight());
    const bool backArrow = state.hdmiFull;
    if (backArrow) {
        card(p, l.backButton);
        arrow(p, QRect(l.backButton.left() + 12, l.backButton.top(), 20, l.backButton.height()), false, foreground());
        text(p, l.backButton.adjusted(34, 0, -6, 0), "返回", 16);
    }
    const int titleX = l.backButton.right() + 16;
    text(p, QRect(titleX, 6, size.width() - titleX - 20, 28), state.title, 24, foreground(), true);
    text(p, QRect(titleX, 34, size.width() - titleX - 20, 24), state.source, 13, muted());
    card(p, l.content.adjusted(-1, -1, 1, 1), QColor(0, 0, 0, 0));
    if (state.hdmiFull) {
        if (l.laneCard.isValid()) {
            card(p, l.laneCard, QColor(255, 255, 255, 235));
            text(p, l.laneCard.adjusted(8, 7, -8, -24), "方向", 13, muted());
            text(p, l.laneCard.adjusted(8, 26, -8, -5), "未接入", 14, muted(), true);
        }
        if (l.signalFrame.isValid()) {
            card(p, l.signalFrame, QColor(255, 255, 255, 60), QColor(66, 133, 244, 140));
            signal(p, signalRect(l, false), false, state.leftSignal);
            signal(p, signalRect(l, true), true, state.rightSignal);
        }
    }
    if (l.infoCard.isValid()) {
        card(p, l.infoCard, QColor(255, 255, 255, 230));
        text(p, QRect(l.infoCard.x()+10, l.infoCard.y()+12, l.infoCard.width()-20, 22), "识别", 14, muted());
        text(p, QRect(l.infoCard.x()+10, l.infoCard.y()+46, l.infoCard.width()-20, 26), QString("%1 个目标").arg(state.detectionCount), 16, foreground(), true);
        card(p, l.statusCard, QColor(255, 255, 255, 230));
        text(p, QRect(l.statusCard.x()+10, l.statusCard.y()+12, l.statusCard.width()-20, 22), "画面", 14, muted());
        text(p, QRect(l.statusCard.x()+10, l.statusCard.y()+46, l.statusCard.width()-20, 26), state.channel, 15, foreground(), true);
    }
    const int footerY = size.height() - l.toolbar.height();
    text(p, QRect(20, footerY + (size.width() < 840 ? 144 : 76), size.width() - 40, 18),
         help ? "V 切换相机  G 总览  F HDMI  P 暂停  S 截屏  Tab 设置  H 关闭帮助" : state.detail,
         12, muted());
    p.restore();
}

struct SettingsState {
    QStringList values;
    QStringList models;
    int modelIndex = 0;
    int row = 0;
    QString pipeline;
    QString throughput;
    QString status;
    QString diagnostics;
};

inline void paintSettings(QPainter& p, const QSize& size, const SettingsState& state,
                          const QVector<QPair<QRect, QString>>& buttons, int selectedRow) {
    p.fillRect(QRect(QPoint(), size), QColor("#f8fafc"));
    const bool narrow = size.width() < 840;
    if (narrow) {
        text(p, QRect(20, 16, size.width() - 230, 60), "算法与画面设置", 24, foreground(), true);
        const QStringList labels{"检测模型", "画面", "置信度", "模型轮换", "坐标格式", "运行状态", "分辨率相机", "分辨率"};
        for (int row = 0; row < 8; ++row) {
            const QRect r(16, 100 + row * 66, size.width() - 32, 62);
            card(p, r, row == selectedRow ? QColor("#eff6ff") : Qt::white,
                 row == selectedRow ? primary() : border());
            text(p, r.adjusted(14, 4, -210, -31), labels[row], 16);
            text(p, r.adjusted(14, 30, -210, -5), state.values.value(row), 15, primary(), true);
        }
        text(p, QRect(20, 640, size.width() - 40, 50), state.status, 13, muted());
    } else {
        const double scale = std::min(size.width() / 1280.0, size.height() / 720.0);
        p.translate((size.width() - 1280 * scale) / 2, (size.height() - 720 * scale) / 2);
        p.scale(scale, scale);
        text(p, QRect(32, 18, 850, 38), "算法与画面设置", 27, foreground(), true);
        text(p, QRect(32, 58, 920, 30), "配置检测模型与推理参数 · 修改即时生效", 16, muted());
        const QRect main(32, 106, 594, 426);
        card(p, main);
        text(p, main.adjusted(20, 12, -20, -386), "识别与显示", 18, foreground(), true);
        const QStringList labels{"检测模型", "画面", "置信度", "模型轮换", "坐标格式", "运行状态", "分辨率相机", "分辨率"};
        for (int row = 0; row < 8; ++row) {
            const QRect r(48, 162 + row * 46, 562, 42);
            if (row == selectedRow) card(p, r, QColor("#eff6ff"), primary());
            text(p, r.adjusted(14, 0, -378, 0), labels[row], 16, muted());
            text(p, QRect(226, r.y(), 200, r.height()), state.values.value(row), 16, foreground(), true);
        }
        const QRect right(650, 106, 598, 196);
        card(p, right);
        text(p, right.adjusted(20, 12, -20, -154), "识别策略", 18, foreground(), true);
        text(p, QRect(670, 160, 558, 128), state.pipeline, 15, foreground(), false,
             Qt::AlignLeft | Qt::AlignTop | Qt::TextWordWrap);
        const QRect metrics(650, 318, 598, 96);
        card(p, metrics);
        text(p, metrics.adjusted(20, 10, -20, -58), "实时性能", 18, foreground(), true);
        text(p, QRect(670, 366, 558, 36), state.throughput, 14, muted());
        const QRect models(650, 430, 598, 166);
        card(p, models);
        text(p, models.adjusted(20, 10, -20, -160), "模型列表", 18, foreground(), true);
        const int first = std::max(0, std::min(state.modelIndex - 2, state.models.size() - 3));
        for (int i = first; i < std::min(first + 3, state.models.size()); ++i) {
            const QRect r(666, 478 + (i - first) * 34, 566, 30);
            if (i == state.modelIndex) card(p, r, QColor("#eff6ff"), QColor("#bfdbfe"), 6);
            text(p, r.adjusted(10, 0, -10, 0), state.models[i], 15, i == state.modelIndex ? primary() : muted(), i == state.modelIndex);
        }
        card(p, QRect(32, 548, 594, 80));
        text(p, QRect(52, 558, 554, 60), state.status, 13, muted(), false, Qt::AlignLeft | Qt::AlignVCenter | Qt::TextWordWrap);
        text(p, QRect(32, 674, 1216, 24), state.diagnostics, 12, muted());
    }
    p.resetTransform();
    for (const auto& button : buttons) {
        card(p, button.first, button.second == "返回监看" ? QColor("#eff6ff") : Qt::white);
        text(p, button.first.adjusted(4, 0, -4, 0), button.second, narrow ? 16 : 18,
             button.second == "返回监看" ? primary() : foreground(), true, Qt::AlignCenter);
    }
}

} // namespace detview_ui
