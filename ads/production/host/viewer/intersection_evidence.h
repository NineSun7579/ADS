#pragma once
// 路口接近证据。
//
// 独立模块：只吃"每帧的标线可见性 + 斑马线横向跨度 + 时间戳"，输出"是否接近路口"。
// 不依赖 UI、推理线程或驾驶状态机，便于单测与替换。
//
// 两条判定（任一成立即触发，带冷却与保持）：
//   1) 前方道路标线刚刚消失：类 1..6 在 marksRecentMs 内出现过，之后连续缺失
//      达到 marksGapMs；
//   2) 斑马线宽度（横向跨度，不是纵向长度）相对 widthWindowMs 内的峰值下降
//      达到 crosswalkDrop（默认 50%）。
#include <QString>
#include <algorithm>
#include <deque>

namespace intersection_evidence {

struct Config {
    double crosswalkDrop = 0.50;   // 宽度相对峰值跌幅阈值（0.5 = 减小 50%）
    qint64 widthWindowMs = 3000;   // 峰值统计窗口
    qint64 marksGapMs = 150;       // 标线连续缺失多久算"消失"
    qint64 marksRecentMs = 2000;   // 标线必须在这个时长内出现过，才叫"刚刚消失"
    qint64 holdMs = 1500;          // 触发后保持 approach 的时长
    qint64 cooldownMs = 3000;      // 两次触发的最小间隔
};

struct State {
    bool approach = false;          // 接近/进入路口的综合判定
    bool markingsLost = false;      // 本次触发原因：标线刚消失
    bool crosswalkNarrowed = false; // 本次触发原因：斑马线宽度骤降
    QString reason;
    double crosswalkSpanPx = 0;     // 当前斑马线横向跨度（像素）
    double crosswalkPeakPx = 0;     // 统计窗口内的峰值跨度
    qint64 triggeredAt = -1;
};

class Engine {
public:
    explicit Engine(Config config = {}) : config_(config) {}

    void reset() { *this = Engine(config_); }
    const Config& config() const { return config_; }
    void setConfig(Config config) { config_ = config; }
    const State& state() const { return state_; }

    // laneMarksPresent：类 1..6 任一可见；crosswalkSpanPx：类 8 的横向跨度，0 表示没有。
    const State& update(qint64 now, bool laneMarksPresent, double crosswalkSpanPx) {
        State next;
        next.crosswalkSpanPx = crosswalkSpanPx > 0 ? crosswalkSpanPx : 0;

        // 斑马线跨度滑窗：只用窗口内的值求峰值。
        if (crosswalkSpanPx > 0) spans_.push_back({now, crosswalkSpanPx});
        while (!spans_.empty() && now - spans_.front().t > config_.widthWindowMs) spans_.pop_front();
        for (const auto& s : spans_) next.crosswalkPeakPx = std::max(next.crosswalkPeakPx, s.px);

        // 标线可见性：只关心"最近出现过、现在连续缺失"。
        if (laneMarksPresent) {
            lastMarksAt_ = now;
            missingSince_ = -1;
        } else if (lastMarksAt_ >= 0 && now - lastMarksAt_ <= config_.marksRecentMs) {
            if (missingSince_ < 0) missingSince_ = now;
        } else {
            missingSince_ = -1;  // 太久没见过，不算"刚刚消失"
        }
        const bool lost = missingSince_ >= 0 && now - missingSince_ >= config_.marksGapMs;
        const bool narrowed = crosswalkSpanPx > 0 && next.crosswalkPeakPx > 0 &&
                              crosswalkSpanPx <= next.crosswalkPeakPx * (1.0 - config_.crosswalkDrop);

        const bool cooled = triggeredAt_ < 0 || now - triggeredAt_ >= config_.cooldownMs;
        if ((lost || narrowed) && cooled) {
            triggeredAt_ = now;
            holdUntil_ = now + config_.holdMs;
            triggerLost_ = lost;
            triggerNarrowed_ = narrowed;
        }

        next.approach = now < holdUntil_;
        next.markingsLost = next.approach && triggerLost_;
        next.crosswalkNarrowed = next.approach && triggerNarrowed_;
        next.triggeredAt = triggeredAt_;
        if (next.markingsLost && next.crosswalkNarrowed) next.reason = QStringLiteral("前方标线消失且斑马线变窄");
        else if (next.markingsLost) next.reason = QStringLiteral("前方道路标线刚消失");
        else if (next.crosswalkNarrowed) next.reason = QStringLiteral("前方斑马线宽度骤降");
        else next.reason.clear();

        state_ = next;
        return state_;
    }

private:
    Config config_;
    State state_;
    qint64 lastMarksAt_ = -1;
    qint64 missingSince_ = -1;
    qint64 triggeredAt_ = -1;
    qint64 holdUntil_ = -1;
    bool triggerLost_ = false;
    bool triggerNarrowed_ = false;
    struct Span { qint64 t; double px; };
    std::deque<Span> spans_;
};

}  // namespace intersection_evidence
