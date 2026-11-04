#pragma once
// 按钮快捷键注册表。
//
// 职责边界：
//   - 本文件只知道「哪个控件 id 对应哪个键」以及帮助层要显示的文本；
//   - 不依赖 exact_ui 的布局、绘制、命中测试，也不合成 Action；
//   - 键位分发在 main.cpp（键 → id → exact_ui::activateControl），
//     ? 帮助浮层只向这里要显示文本。
// 改键只改这一张表，UI 与窗口代码都不用动。
#include <QString>
#include <Qt>

namespace shortcut_registry {

struct Binding {
    const char* id;      // 对应 exact_ui::Control::id（布局里的按钮 id）
    int key;             // Qt::Key_*
    unsigned mods;       // Qt::KeyboardModifiers 的位值，0 = 无修饰
    const char* text;    // 帮助浮层显示
};

inline const Binding* table(int* count) {
    static const Binding rows[] = {
        {"nav-settings", Qt::Key_F1, 0, "F1"},
        {"display-settings", Qt::Key_F2, 0, "F2"},
        {"cpu-settings", Qt::Key_F3, 0, "F3"},
        {"home-legend", Qt::Key_F4, 0, "F4"},
        {"drive-go", Qt::Key_W, 0, "W"},
        {"drive-stop", Qt::Key_X, 0, "X"},
        {"drive-change-left", Qt::Key_A, 0, "A"},
        {"drive-change-right", Qt::Key_D, 0, "D"},
        {"drive-lane-0", Qt::Key_1, 0, "1"},
        {"drive-lane-1", Qt::Key_2, 0, "2"},
        {"drive-lane-2", Qt::Key_3, 0, "3"},
        {"local-video-pause", Qt::Key_Space, 0, "Space"},
        {"local-video-loop", Qt::Key_L, 0, "L"},
        {"local-video-select", Qt::Key_V, 0, "V"},
        {"local-video-camera", Qt::Key_C, 0, "C"},
        {"toggle-panorama", Qt::Key_Z, 0, "Z"},
        {"hdmi-panorama", Qt::Key_H, 0, "H"},
        {"conf-minus", Qt::Key_Minus, 0, "-"},
        {"conf-plus", Qt::Key_Equal, 0, "="},
        {"toggle-ranging", Qt::Key_R, 0, "R"},
        {"apply-config", Qt::Key_P, 0, "P"},
        {"model-dropdown-btn", Qt::Key_M, 0, "M"},
        {"rule-light-count", Qt::Key_L, unsigned(Qt::ShiftModifier), "Shift+L"},
        {"rule-light-region", Qt::Key_O, unsigned(Qt::ShiftModifier), "Shift+O"},
        {"rule-light-clear", Qt::Key_K, unsigned(Qt::ShiftModifier), "Shift+K"},
        {"nav-toggle", Qt::Key_N, 0, "N"},
        {"nav-region", Qt::Key_N, unsigned(Qt::ShiftModifier), "Shift+N"},
        {"nav-source", Qt::Key_N, unsigned(Qt::ControlModifier), "Ctrl+N"},
        {"cpu-toggle", Qt::Key_U, 0, "U"},
        {"cpu-mark", Qt::Key_U, unsigned(Qt::ShiftModifier), "Shift+U"},
        {"cpu-road", Qt::Key_U, unsigned(Qt::ControlModifier), "Ctrl+U"},
        {"cpu-standard", Qt::Key_Y, unsigned(Qt::ControlModifier), "Ctrl+Y"},
        {"cpu-source", Qt::Key_S, unsigned(Qt::ControlModifier), "Ctrl+S"},
    };
    *count = int(sizeof(rows) / sizeof(rows[0]));
    return rows;
}

// 带上下文的键位解析（删除/返回/每路放大不是固定映射）。
// cpuPanel/navPanel/zoomed 只是"当前界面状态"，由调用方传入，注册表不反向依赖 UI。
inline QString idForKey(int key, Qt::KeyboardModifiers mods,
                        bool cpuPanel, bool navPanel, bool zoomed) {
    const bool shift = mods.testFlag(Qt::ShiftModifier);
    const bool alt = mods.testFlag(Qt::AltModifier);
    const bool ctrl = mods.testFlag(Qt::ControlModifier);
    if (alt && !shift && !ctrl && key >= Qt::Key_1 && key <= Qt::Key_6)
        return QStringLiteral("zoom-ch%1").arg(key - Qt::Key_1 + 1);
    if (shift && !alt && !ctrl && key >= Qt::Key_1 && key <= Qt::Key_7)
        return QStringLiteral("display-toggle-%1").arg(key - Qt::Key_1);
    if (key == Qt::Key_Delete)
        return cpuPanel ? QStringLiteral("cpu-clear")
                        : navPanel ? QStringLiteral("nav-clear") : QString();
    if (key == Qt::Key_Backspace)
        return zoomed ? QStringLiteral("zoom-back") : QStringLiteral("back-home");
    int count = 0;
    const Binding* rows = table(&count);
    for (int i = 0; i < count; ++i)
        if (rows[i].key == key && unsigned(mods) == rows[i].mods)
            return QString::fromLatin1(rows[i].id);
    return QString();
}

// 控件 id → 键位文本；没有绑定的控件返回空。
inline QString labelFor(const QString& id) {
    if (id.startsWith(QStringLiteral("display-toggle-")))
        return QStringLiteral("Shift+") + QString::number(id.mid(15).toInt() + 1);
    if (id.startsWith(QStringLiteral("zoom-ch")))
        return QStringLiteral("Alt+") + id.mid(7);
    int count = 0;
    const Binding* rows = table(&count);
    for (int i = 0; i < count; ++i)
        if (id == QLatin1String(rows[i].id)) return QString::fromLatin1(rows[i].text);
    return QString();
}

}  // namespace shortcut_registry
