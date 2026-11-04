#pragma once

// 未知镜头参数的在线标定融合：只消费 road/lane 量测，不做图像检测。
// 与 src/online_calib.py 同一原则：短窗地平线、长窗尺度；未收敛绝不给米数。
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <deque>
#include <limits>
#include <string>
#include <vector>

namespace online_calib {

struct Est {
    bool ok = false;
    double value = 0;
};

struct Observation {
    bool has_vp = false;
    int n_marks = 0;
    double y_h = 0;
    Est hc_paint, hc_lane, a_dash, a_gap, a_period;
};

struct State {
    bool ok = false;          // 地面尺度可用：A/y_h 已收敛
    bool frame_ok = false;    // 本帧观测也可信；ok且frame_ok才能发布本帧距离
    bool size_ok = false;     // f/h_c 也可信，才允许框高法
    double y_h = 0, A = 0, h_c = 0, f_px = 0, hfov_deg = 0;
    int n_seen = 0, n_used = 0;
    int n_yh = 0, n_A = 0, n_hc_paint = 0, n_hc_lane = 0;
    std::string why;
};

struct Config {
    int window = 480;
    int window_fast = 24;
    int min_samples = 10;
    int min_vp_marks = 3;       // 两条线求交没有冗余，不能进地平线窗口
    int stale_limit = 90;       // 连续失效后清空旧标定，不拿旧镜头硬套新场景
    double yh_gate_1080 = 60.0; // 孤立跳变门，按源帧高度缩放
    double tol_se_yh = 0.015;
    double tol_se_A = 0.150;
    double tol_se_hc = 0.060;
    double tol_A_pair = 0.50;
};

class OnlineCalib {
public:
    explicit OnlineCalib(Config cfg = {}) : cfg_(cfg) {
        acc_[YH].set_limit(cfg_.window_fast);
        acc_[YH_LONG].set_limit(cfg_.window_fast);
        for (int k = HC_PAINT; k < N_ROUTE; ++k) acc_[k].set_limit(cfg_.window);
    }

    // 每次调用必须恰好对应一个新视频帧；调用方负责同帧不重复喂入。
    State observe(const Observation& o, int img_w, int img_h) {
        ++seen_;
        frame_ok_current_ = true;
        const bool road_seen = o.has_vp && o.n_marks >= cfg_.min_vp_marks && o.y_h > 0;
        if (!road_seen) {
            frame_ok_current_ = false;
            ++stale_;
            if (stale_ >= cfg_.stale_limit) {
                clear_history();
                stale_ = 0;
                return state(img_w, "连续无有效标线，已撤回并清空旧标定", false);
            }
            return state(img_w, "本次观测无可靠地平线，跳过测距", false);
        }
        stale_ = 0;

        const double scale = img_h > 0 ? double(img_h) / 1080.0 : 1.0;
        if (!accept_yh(o.y_h, cfg_.yh_gate_1080 * scale)) {
            frame_ok_current_ = false;
            return state(img_w, "地平线孤立跳变，跳过测距", false);
        }
        acc_[YH].push(o.y_h);
        push(HC_PAINT, o.hc_paint);
        push(HC_LANE, o.hc_lane);
        push(A_DASH, o.a_dash);
        push(A_GAP, o.a_gap);
        push(A_PERIOD, o.a_period);
        return state(img_w);
    }

    State current(int img_w) const { return state(img_w); }

    void reset() {
        clear_history();
        seen_ = 0;
        stale_ = 0;
    }

private:
    enum Route { YH = 0, YH_LONG, HC_PAINT, HC_LANE, A_DASH, A_GAP, A_PERIOD, N_ROUTE };
    struct Window {
        std::deque<double> v;
        size_t limit = 1;
        void set_limit(int n) { limit = size_t(std::max(1, n)); }
        void push(double x) {
            if (!std::isfinite(x) || x <= 0) return;
            v.push_back(x);
            if (v.size() > limit) v.pop_front();
        }
        double median(bool additive = false) const {
            if (v.empty()) return 0;
            std::vector<double> t(v.begin(), v.end());
            if (!additive) {
                t.erase(std::remove_if(t.begin(), t.end(), [](double x) { return x <= 0; }), t.end());
                if (t.empty()) return 0;
                for (double& x : t) x = std::log(x);
            }
            std::sort(t.begin(), t.end());
            const double m = t[t.size() / 2];
            return additive ? m : std::exp(m);
        }
        double standard_error() const {
            if (v.size() < 3) return std::numeric_limits<double>::infinity();
            std::vector<double> t(v.begin(), v.end());
            std::sort(t.begin(), t.end());
            const double m = t[t.size() / 2];
            std::vector<double> d;
            for (double x : t) d.push_back(std::abs(x - m));
            std::sort(d.begin(), d.end());
            const double sigma = 1.4826 * d[d.size() / 2];
            return 1.253 * sigma / std::sqrt(double(t.size())) / std::max(std::abs(m), 1e-9);
        }
    };

    static bool valid(const Est& e) { return e.ok && std::isfinite(e.value) && e.value > 0; }
    void push(int k, const Est& e) { if (valid(e)) acc_[k].push(e.value); }

    void clear_history() {
        for (auto& w : acc_) w.v.clear();
        yh_reject_ = 0;
    }

    bool accept_yh(double v, double gate) {
        const auto& h = acc_[YH].v;
        if (h.size() < 5) return true;
        std::vector<double> t(h.begin(), h.end());
        std::sort(t.begin(), t.end());
        const double m = t[t.size() / 2];
        if (std::abs(v - m) <= gate) {
            yh_reject_ = 0;
            return true;
        }
        if (++yh_reject_ >= 10) {
            acc_[YH].v.clear();
            yh_reject_ = 0;
            return true;
        }
        return false;
    }

    State state(int img_w, const std::string& why = "", bool allow_ready = true) const {
        State s;
        s.n_seen = seen_;
        for (const auto& w : acc_) s.n_used = std::max(s.n_used, int(w.v.size()));
        s.n_yh = int(acc_[YH].v.size());
        s.n_A = int(acc_[A_DASH].v.size());
        s.n_hc_paint = int(acc_[HC_PAINT].v.size());
        s.n_hc_lane = int(acc_[HC_LANE].v.size());
        if (!why.empty()) { s.why = why; return s; }
        if (!allow_ready) { s.why = "等待可靠观测"; return s; }
        if (!frame_ok_current_) { s.why = "本帧已有无效观测"; return s; }
        if ((int)acc_[YH].v.size() < cfg_.min_samples ||
            (int)acc_[A_DASH].v.size() < cfg_.min_samples) {
            s.why = "主链样本不足";
            return s;
        }
        const double se_yh = acc_[YH].standard_error();
        const double se_A = acc_[A_DASH].standard_error();
        const double se_hc = acc_[HC_LANE].standard_error();
        if (se_yh > cfg_.tol_se_yh || se_A > cfg_.tol_se_A) {
            char buf[192];
            std::snprintf(buf, sizeof buf,
                          "中位数尚未收敛 se(yh=%.1f%%/%.1f%% A=%.1f%%/%.1f%% hc=%.1f%%/%.1f%%)",
                          100 * se_yh, 100 * cfg_.tol_se_yh, 100 * se_A, 100 * cfg_.tol_se_A,
                          100 * se_hc, 100 * cfg_.tol_se_hc);
            s.why = buf;
            return s;
        }

        const double yh = acc_[YH].median(true);
        const double ad = acc_[A_DASH].median();
        // 直测为主，间隙/周期只校验；它们来自同一对虚线，不能当两票独立证据。
        for (int k : {A_GAP, A_PERIOD}) {
            if (acc_[k].v.size() < 3) continue;
            const double a = acc_[k].median();
            if (std::abs(a - ad) > cfg_.tol_A_pair * std::max(ad, 1e-9)) {
                s.why = "虚线段长与间隙/周期互校失败";
                return s;
            }
        }
        const int min_hc = std::max(3, cfg_.min_samples / 3);
        const bool have_hc = (int)acc_[HC_PAINT].v.size() >= min_hc &&
                             (int)acc_[HC_LANE].v.size() >= min_hc;
        const double hp = have_hc ? acc_[HC_PAINT].median() : 0;
        const double hl = have_hc ? acc_[HC_LANE].median() : 0;
        const double hc = have_hc ? 0.5 * (hp + hl) : 0;
        const double A = ad;
        const double f = hc > 0 ? A / hc : 0;
        const double hfov = f > 0 ? 2.0 * std::atan(img_w / (2.0 * f)) * 180.0 / 3.14159265358979323846 : 0;
        const bool size_ok = have_hc && se_hc <= cfg_.tol_se_hc &&
                             hc >= 0.8 && hc <= 2.6 && hfov >= 25.0 && hfov <= 160.0;
        if (!(yh > 0) || !(A > 0)) {
            s.why = "地平线/地面尺度超出物理范围";
            return s;
        }
        s.ok = true;
        s.frame_ok = true;
        s.size_ok = size_ok;
        s.y_h = yh;
        s.A = A;
        s.h_c = hc;
        s.f_px = f;
        s.hfov_deg = hfov;
        if (!size_ok) s.why = "仅地面尺度可用；f/h_c未收敛，框高法禁用";
        return s;
    }

    Config cfg_;
    Window acc_[N_ROUTE];
    int seen_ = 0, stale_ = 0, yh_reject_ = 0;
    bool frame_ok_current_ = false;
};

}  // namespace online_calib
