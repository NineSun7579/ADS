// lane_calib.h —— 纯路面标线标定（五路量测）的 C++ 移植，对应 Python 的 src/road_marks.py。
//
// 依赖 OpenCV（连通域、颜色转换）：板上有 OpenCV 4.6，vidview 本来就链着它。
// 与 Python 的口径逐条对齐；数值对照见 tools/bench_calib.cpp 的输出（每帧 y_h/A/h_c）
// 与 Python 侧 `tools/measure_frames.py` 的输出，逐行 diff 即可。
//
// 刻意**不**移植的部分：
//   - `y_h_from_longitudinal`（纵向一致性反解）：Python 里只作为诊断值输出、不参与估计，
//     它的搜参是 90 次 `_long_terms` 调用，纯粹为了打印一个参考数，板上不需要。
//   - `suggest_standard` 的 auto 判定：板上由 `--road-type` 显式给，避免两档几何不可分辨时误选。
//
// 一处实现差异（不影响结果，只影响速度）：Python 对每个连通块做一次 `(lab == i)` 全图扫描，
// 这里改成**一次遍历把所有像素按标签分桶**，总代价从 O(像素×块数) 降到 O(像素)。
// 这也是这次移植在板上有望比 Python 快一个量级的主要原因。
#pragma once

#include <opencv2/opencv.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

#include "lane_dist.h"   // kPi

namespace lane_calib {

// ---------------------------------------------------------------- 标准与 ROI

struct Standard {
    const char* key;
    double L;   // 虚线段长 (m)
    double G;   // 间隔 (m)
};

inline const std::vector<Standard>& standards() {
    static const std::vector<Standard> v = {
        {"city", 2.0, 4.0}, {"city-fast", 4.0, 6.0}, {"highway", 6.0, 9.0}};
    return v;
}

inline const Standard* find_standard(const std::string& key) {
    for (const auto& s : standards())
        if (key == s.key) return &s;
    return nullptr;
}

inline double std_ratio(const Standard& s) { return s.L / (s.L + s.G); }

// 默认量测区：画面下 40%、中间 70% 宽
inline std::array<int, 4> auto_roi(int w, int h) {
    return {(int)(0.15 * w), (int)(0.60 * h), (int)(0.85 * w), h};
}

// ---------------------------------------------------------------- 检测

struct Mark {
    double cx = 0, cy = 0;
    double y1 = 0;      // 近端行号（大）
    double y2 = 0;      // 远端行号（小）
    double dy = 0;
    double theta = 0;   // 长轴与水平夹角（弧度，[-pi/2, pi/2)）
    double len_px = 0;
    double wid_px = 0;  // 平均宽度（面积/长度）
    int area = 0;
    bool clipped = false;   // 贴 ROI 边界：dy 被截断，不能进纵向三路
};

inline bool touches_border(const cv::Rect& bb, int roi_w, int roi_h) {
    return bb.x <= 0 || bb.y <= 0 || bb.x + bb.width >= roi_w || bb.y + bb.height >= roi_h;
}

// 找白色虚线。返回按 cy 从小到大（远端在前）排序的 Mark 列表。
inline std::vector<Mark> find_marks(const cv::Mat& bgr, const std::array<int, 4>& roi,
                                    int v_thr = 110, int s_thr = 90, int min_area = 50,
                                    double min_aspect = 2.2, double min_len = 12.0,
                                    double max_len = 300.0, double max_wid = 45.0,
                                    double scale = 1.0) {
    // 像素类阈值随分辨率缩：面积按 scale^2、长度与宽度按 scale。
    // 颜色阈值与 min_aspect（无量纲）不缩。
    min_area = std::max(1, (int)std::lround(min_area * scale * scale));
    min_len *= scale; max_len *= scale; max_wid *= scale;
    const int x0 = roi[0], y0 = roi[1], x1 = roi[2], y1 = roi[3];
    // ROI 必须先夹到画面内：越界时 cv::Rect 会抛异常（Python 的切片是自动截断的）
    const int cx0 = std::max(0, std::min(x0, bgr.cols)), cy0 = std::max(0, std::min(y0, bgr.rows));
    const int cx1 = std::max(cx0, std::min(x1, bgr.cols));
    const int cy1 = std::max(cy0, std::min(y1, bgr.rows));
    const int rw = cx1 - cx0, rh = cy1 - cy0;
    std::vector<Mark> out;
    if (rw <= 0 || rh <= 0) return out;

    cv::Mat hsv, mask;
    // 先裁 ROI 再转 HSV：Python 是整幅转换再切片，ROI（默认 70%宽 × 40%高）
    // 只占 28% 面积，先裁能省掉 ~72% 的颜色转换开销，结果完全等价。
    const cv::Mat bgr_roi = bgr(cv::Rect(cx0, cy0, rw, rh));
    cv::cvtColor(bgr_roi, hsv, cv::COLOR_BGR2HSV);
    // Python 是严格不等号：V > v_thr、S < s_thr。inRange 是闭区间，
    // 所以下界要 +1、上界要 -1，差这一格就会把阈值上的像素算进来。
    cv::inRange(hsv, cv::Scalar(0, 0, v_thr + 1), cv::Scalar(179, s_thr - 1, 255), mask);

    cv::Mat lab, stats, cent;
    const int n = cv::connectedComponentsWithStats(mask, lab, stats, cent, 8, CV_32S);
    if (n <= 1) return out;

    // 包围盒直扫：虚线是细长的，所有包围盒的总面积远小于整幅 ROI；
    // 噪声块只有几个像素，盒也极小。省掉 vector<vector<Point>>（每帧近千次
    // 小分配）和整幅大小的行累加器。
    std::vector<int> rcnt;
    std::vector<double> rsum;
    for (int i = 1; i < n; ++i) {
        const int area = (int)stats.at<int>(i, cv::CC_STAT_AREA);
        if (area < min_area || area < 3) continue;
        const int bx = stats.at<int>(i, cv::CC_STAT_LEFT);
        const int by = stats.at<int>(i, cv::CC_STAT_TOP);
        const int bw = stats.at<int>(i, cv::CC_STAT_WIDTH);
        const int bh = stats.at<int>(i, cv::CC_STAT_HEIGHT);
        if ((size_t)bh > rcnt.size()) {
            rcnt.resize((size_t)bh);
            rsum.resize((size_t)bh);
        }
        std::fill_n(rcnt.begin(), bh, 0);
        std::fill_n(rsum.begin(), bh, 0.0);

        long cnt = 0, sx = 0, sy = 0;
        int lo = rh, hi = -1, nrow = 0;
        for (int r = by; r < by + bh; ++r) {
            const int* row = lab.ptr<int>(r);
            int c0 = 0;
            long s0 = 0;
            for (int c = bx; c < bx + bw; ++c)
                if (row[c] == i) { ++c0; s0 += c; }
            if (!c0) continue;
            rcnt[(size_t)(r - by)] = c0;
            rsum[(size_t)(r - by)] = (double)s0;
            ++nrow;
            cnt += c0;
            sx += s0;
            sy += (long)c0 * r;
            lo = std::min(lo, r);
            hi = std::max(hi, r);
        }
        if (nrow < 3 || cnt < 3) continue;

        // 每行质心再拟合 x = a + b*y（只遍历有像素的行，顺序与逐像素版一致）
        double mY = 0, mX = 0;
        for (int r = by; r < by + bh; ++r) {
            if (!rcnt[(size_t)(r - by)]) continue;
            mY += r;
            mX += rsum[(size_t)(r - by)] / rcnt[(size_t)(r - by)];
        }
        mY /= nrow;
        mX /= nrow;
        double sxy = 0, syy = 0;
        for (int r = by; r < by + bh; ++r) {
            if (!rcnt[(size_t)(r - by)]) continue;
            const double xx = rsum[(size_t)(r - by)] / rcnt[(size_t)(r - by)];
            sxy += (r - mY) * (xx - mX);
            syy += (r - mY) * (r - mY);
        }
        if (syy <= 1e-12) continue;
        const double b = sxy / syy;

        double theta = std::atan2(1.0, b);
        theta = std::fmod(theta + lane_dist::kPi / 2.0, lane_dist::kPi);
        if (theta < 0) theta += lane_dist::kPi;
        theta -= lane_dist::kPi / 2.0;
        const double sa = std::abs(std::sin(theta));
        if (sa < 0.05) continue;

        const double dy = (double)(hi - lo);
        if (dy < 3.0 * scale) continue;
        const double L_px = dy / sa;
        const double w_px = (double)area / std::max(L_px, 1.0);
        if (L_px / std::max(w_px, 0.5) < min_aspect) continue;
        if (!(L_px >= min_len && L_px <= max_len) || w_px > max_wid) continue;

        Mark m;
        m.cx = (double)sx / (double)cnt + cx0;
        m.cy = (double)sy / (double)cnt + cy0;
        m.y1 = (double)hi + cy0;
        m.y2 = (double)lo + cy0;
        m.dy = dy;
        m.theta = theta;
        m.len_px = L_px;
        m.wid_px = w_px;
        m.area = area;
        m.clipped = touches_border(cv::Rect(bx, by, bw, bh), rw, rh);
        out.push_back(m);
    }
    std::sort(out.begin(), out.end(), [](const Mark& a, const Mark& b) { return a.cy < b.cy; });
    return out;
}

// ---------------------------------------------------------------- 消失点

inline double vp_resid_deg(const Mark& m, double vx, double vy) {
    const double ang = std::atan2(vy - m.cy, vx - m.cx);
    double diff = std::fmod(m.theta - ang + lane_dist::kPi / 2.0, lane_dist::kPi);
    if (diff < 0) diff += lane_dist::kPi;
    diff -= lane_dist::kPi / 2.0;
    return std::abs(diff) * 180.0 / lane_dist::kPi;
}

struct Vp {
    bool ok = false;
    double vx = 0, vy = 0, rms = 0;
    int n = 0;
};

// RANSAC 求消失点。Python 用固定种子的随机抽对；这里**枚举所有对**——
// 虚线通常不超过十几条，C(N,2) 很小，枚举比随机抽样更稳且可复现。
inline Vp estimate_vp(const std::vector<Mark>& marks, double y_limit, double y_floor = 0.0,
                      double tol_px = 1.5, double scale = 1.0) {
    // tol_px 是**残差容差**，随分辨率缩（与 Python 保持一致）。实测缩与不缩
    // 对结果没有区别，保留缩放只为两套实现逐值对齐。
    tol_px *= scale;
    Vp res;
    const int nm = (int)marks.size();
    if (nm < 2) return res;

    struct Line { double nx, ny, b; };
    std::vector<Line> lines;
    lines.reserve(nm);
    for (const auto& m : marks)
        lines.push_back({-std::sin(m.theta), std::cos(m.theta),
                         -std::sin(m.theta) * m.cx + std::cos(m.theta) * m.cy});

    double bx = 0, by = 0;
    int best_n = -1;
    double best_len = -1.0;
    bool found = false;
    for (int i = 0; i < nm; ++i) {
        for (int j = i + 1; j < nm; ++j) {
            const double det = lines[i].nx * lines[j].ny - lines[i].ny * lines[j].nx;
            if (std::abs(det) < 1e-6) continue;
            const double px = (lines[i].b * lines[j].ny - lines[i].ny * lines[j].b) / det;
            const double py = (lines[i].nx * lines[j].b - lines[i].b * lines[j].nx) / det;
            if (!std::isfinite(px) || !std::isfinite(py)) continue;
            if (!(py > y_floor && py < y_limit)) continue;
            int cnt = 0;
            for (const auto& ln : lines)
                if (std::abs(ln.nx * px + ln.ny * py - ln.b) < tol_px) ++cnt;
            const double pair_len = marks[i].len_px + marks[j].len_px;
            if (cnt > best_n || (cnt == best_n && pair_len > best_len)) {
                bx = px; by = py; best_n = cnt; best_len = pair_len; found = true;
            }
        }
    }
    if (!found || best_n < 2) return res;

    // 用内点做加权最小二乘（权重 = len^2）
    std::vector<int> keep;
    for (int k = 0; k < nm; ++k)
        if (std::abs(lines[k].nx * bx + lines[k].ny * by - lines[k].b) < tol_px) keep.push_back(k);
    if ((int)keep.size() < 2) {
        std::vector<double> r(nm);
        for (int k = 0; k < nm; ++k) r[k] = std::abs(lines[k].nx * bx + lines[k].ny * by - lines[k].b);
        std::vector<int> ord(nm);
        for (int k = 0; k < nm; ++k) ord[k] = k;
        std::sort(ord.begin(), ord.end(), [&](int a, int b2) { return r[a] < r[b2]; });
        keep = {ord[0], ord[1]};
    }
    double maxw = 0;
    for (int k : keep) maxw = std::max(maxw, marks[k].len_px);
    double s11 = 0, s12 = 0, s22 = 0, t1 = 0, t2 = 0, wsum = 0, wrms = 0;
    for (int k : keep) {
        const double w = std::pow(std::max(marks[k].len_px, 1.0) / std::max(maxw, 1e-9), 2.0);
        const double nx = lines[k].nx, ny = lines[k].ny, b = lines[k].b;
        s11 += w * nx * nx; s12 += w * nx * ny; s22 += w * ny * ny;
        t1 += w * nx * b; t2 += w * ny * b;
        wsum += w;
    }
    const double det = s11 * s22 - s12 * s12;
    if (std::abs(det) < 1e-12) return res;
    const double px = (t1 * s22 - t2 * s12) / det;
    const double py = (s11 * t2 - s12 * t1) / det;
    if (!std::isfinite(px) || !std::isfinite(py) || !(py > y_floor && py < y_limit)) return res;
    for (int k : keep) {
        const double w = std::pow(std::max(marks[k].len_px, 1.0) / std::max(maxw, 1e-9), 2.0);
        const double rr = lines[k].nx * px + lines[k].ny * py - lines[k].b;
        wrms += w * rr * rr;
    }
    res.ok = true;
    res.vx = px;
    res.vy = py;
    res.rms = std::sqrt(wrms / std::max(wsum, 1e-9));
    res.n = (int)keep.size();
    return res;
}

// 以消失点为原点按方向角归组
inline std::vector<std::vector<Mark>> group_lines(const std::vector<Mark>& marks, double vx,
                                                  double vy, double tol_deg = 5.0) {
    std::vector<std::pair<double, const Mark*>> keyed;
    keyed.reserve(marks.size());
    for (const auto& m : marks)
        keyed.emplace_back(std::atan2(m.cy - vy, m.cx - vx) * 180.0 / lane_dist::kPi, &m);
    std::sort(keyed.begin(), keyed.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    std::vector<std::vector<Mark>> out;
    double prev = 0;
    bool has_prev = false;
    for (const auto& kv : keyed) {
        if (!out.empty() && has_prev && std::abs(kv.first - prev) <= tol_deg) out.back().push_back(*kv.second);
        else out.push_back({*kv.second});
        prev = kv.first;
        has_prev = true;
    }
    return out;
}

// ---------------------------------------------------------------- 几何核与量测

// 与 lane_dist 里同一个精确核：Z = A·G(y)。geo 未收敛时退化为 1/(y-y_h)。
inline double gvec(double y, double y_h, bool has_geo, double cy, double f) {
    const double d = y - y_h;
    if (!has_geo || d <= 1e-9) return 1.0 / d;
    const double corr = 1.0 - (cy - y_h) * (y - cy) / (f * f);
    if (!(corr >= 0.3 && corr <= 3.0)) return 1.0 / d;
    return corr / d;
}

struct Est {
    bool ok = false;
    double value = 0;
    int n = 0;
    double spread = 0;
};

inline double wmedian(const std::vector<double>& v, const std::vector<double>& w) {
    if (v.empty()) return 0.0;
    std::vector<size_t> idx(v.size());
    for (size_t i = 0; i < idx.size(); ++i) idx[i] = i;
    std::sort(idx.begin(), idx.end(), [&](size_t a, size_t b) { return v[a] < v[b]; });
    double tot = 0;
    for (double x : w) tot += x;
    double acc = 0;
    for (size_t i : idx) {
        acc += (i < w.size() ? w[i] : 1.0);
        if (acc >= 0.5 * tot) return v[i];
    }
    return v[idx.back()];
}

inline Est median_est(const std::vector<double>& v) {
    Est e;
    if (v.empty()) return e;
    std::vector<double> s = v;
    std::sort(s.begin(), s.end());
    const size_t n = s.size();
    e.ok = true;
    e.value = (n % 2) ? s[n / 2] : 0.5 * (s[n / 2 - 1] + s[n / 2]);
    e.n = (int)n;
    std::vector<double> dev(n);
    for (size_t i = 0; i < n; ++i) dev[i] = std::abs(v[i] - e.value);
    std::sort(dev.begin(), dev.end());
    const double mad = (n % 2) ? dev[n / 2] : 0.5 * (dev[n / 2 - 1] + dev[n / 2]);
    e.spread = mad / std::max(std::abs(e.value), 1e-9);
    return e;
}

struct LongTerms {
    std::vector<double> Ad, Ag, Ap;   // 每帧每路最多一个元素
    std::vector<double> ratios;       // L/P
};

// 纵向三式（y1 近、行号更大）：
//   线段 A = L/(G(y2)-G(y1))；间隙 A = G/(G(far.y1)-G(near.y2))；周期 A = (L+G)/(G(far.y1)-G(near.y1))
inline LongTerms long_terms(const std::vector<std::vector<Mark>>& lines, double y_h,
                            double L_std, double G_std, double min_dy,
                            bool has_geo = false, double cy = 0, double f = 0,
                            double px_scale = 1.0) {
    LongTerms out;
    auto g = [&](double y) { return gvec(y, y_h, has_geo, cy, f); };

    std::vector<double> a_val, a_w;
    std::vector<double> g_val, g_w;
    std::vector<double> p_val, p_w;

    for (const auto& line : lines) {
        std::vector<const Mark*> gg;
        for (const auto& m : line)
            if (m.y2 - y_h > 5 * px_scale) gg.push_back(&m);
        std::sort(gg.begin(), gg.end(),
                  [&](const Mark* a, const Mark* b) { return a->y1 > b->y1; });

        for (const auto* m : gg) {
            if (m->dy < min_dy) continue;
            const double d = g(m->y2) - g(m->y1);
            if (d > 1e-12) {
                a_val.push_back(L_std / d);
                a_w.push_back(m->dy * m->dy);
            }
        }
        for (size_t k = 0; k + 1 < gg.size(); ++k) {
            const Mark *nr = gg[k], *fr = gg[k + 1];
            if (nr->y2 <= fr->y1 || nr->y2 - y_h <= 5 || fr->y1 - y_h <= 5) continue;
            if ((nr->y2 - fr->y1) < 0.5 * nr->dy) continue;
            if ((nr->y1 - fr->y1) < 1.3 * nr->dy) continue;
            const double dg = g(fr->y1) - g(nr->y2);
            const double dp = g(fr->y1) - g(nr->y1);
            if (dg > 1e-12) {
                g_val.push_back(G_std / dg);
                g_w.push_back((nr->y2 - fr->y1) * (nr->y2 - fr->y1));
            }
            if (dp > 1e-12) {
                p_val.push_back((L_std + G_std) / dp);
                p_w.push_back((nr->y1 - fr->y1) * (nr->y1 - fr->y1));
            }
            if (nr->dy >= min_dy && dp > 1e-12 && dg > 1e-12)
                out.ratios.push_back((g(nr->y2) - g(nr->y1)) / dp);
        }
    }

    if (a_val.size() < 2) return out;      // 单条虚线没有第二者可以证伪
    const double mid = wmedian(a_val, a_w);
    std::vector<double> keep;
    for (double a : a_val)
        if (std::abs(a - mid) <= 0.25 * std::max(std::abs(mid), 1e-9)) keep.push_back(a);
    if (keep.size() < 2) return out;

    const Est ad = median_est(keep);
    out.Ad.push_back(ad.value);
    if (!g_val.empty()) out.Ag.push_back(wmedian(g_val, g_w));
    if (!p_val.empty()) out.Ap.push_back(wmedian(p_val, p_w));
    return out;
}

// 锚定 y_h、只拟合 h_c：h_c = scale / (观测量 · G(y))
inline Est h_c_one_param(const std::vector<std::pair<double, double>>& samples, double y_h,
                         double scale, bool has_geo = false, double cy = 0, double f = 0,
                         double px_scale = 1.0) {
    std::vector<double> v;
    for (const auto& s : samples) {
        if (s.first - y_h <= 3 * px_scale || s.second <= 1e-6) continue;
        v.push_back(scale / (s.second * gvec(s.first, y_h, has_geo, cy, f)));
    }
    if (v.size() < 3) return Est{};
    Est e = median_est(v);
    std::vector<double> keep;
    for (double x : v)
        if (std::abs(x - e.value) <= std::max(0.35 * std::abs(e.value), 1e-9)) keep.push_back(x);
    if (keep.size() >= 3) e = median_est(keep);
    return e;
}

// ∫ dy/G(y)（y2 -> y1），标线宽度那一路用面积式
inline double integ_inv_g(double y1, double y2, double y_h, bool has_geo, double cy, double f) {
    if (y1 <= y2) return 0.0;
    const int K = 16;
    const double hstep = (y1 - y2) / K;
    double s = 0;
    for (int i = 0; i <= K; ++i) {
        const double y = y2 + i * hstep;
        const double v = 1.0 / gvec(y, y_h, has_geo, cy, f);
        s += (i == 0 || i == K) ? 0.5 * v : v;
    }
    return s * hstep;
}

inline Est h_c_from_area(const std::vector<Mark>& marks, double y_h, double paint_w,
                         bool has_geo = false, double cy = 0, double f = 0,
                         double px_scale = 1.0) {
    std::vector<double> v;
    for (const auto& m : marks) {
        const double sa = std::abs(std::sin(m.theta));
        if (sa < 0.1 || m.wid_px <= 0 || m.dy < 12 * px_scale) continue;
        const double I = integ_inv_g(m.y1, m.y2, y_h, has_geo, cy, f);
        if (I <= 1e-9) continue;
        v.push_back(paint_w * I / (m.wid_px * m.dy / sa));
    }
    if (v.size() < 3) return Est{};
    Est e = median_est(v);
    std::vector<double> keep;
    for (double x : v)
        if (std::abs(x - e.value) <= std::max(0.35 * std::abs(e.value), 1e-9)) keep.push_back(x);
    if (keep.size() >= 3) e = median_est(keep);
    return e;
}

inline void fill_lateral(double y_h, const std::vector<Mark>& marks,
                         const std::vector<std::vector<Mark>>& lines, double lane_w,
                         double paint_w, bool has_geo, double cy, double f,
                         Est* hc_paint, Est* hc_lane, double px_scale = 1.0) {
    *hc_paint = h_c_from_area(marks, y_h, paint_w, has_geo, cy, f, px_scale);

    // 车道宽度：每条车道线用一条代表性直线 x = cx + k(y-cy)，再按行取相邻间距
    struct Rep { double cx, cy, k; };
    std::vector<Rep> reps;
    for (const auto& g : lines) {
        std::vector<const Mark*> g2;
        for (const auto& m : g)
            if (m.dy > 0) g2.push_back(&m);
        if (g2.empty()) continue;
        if (g2.size() >= 2) {
            std::sort(g2.begin(), g2.end(), [](const Mark* a, const Mark* b) { return a->cy < b->cy; });
            double my = 0, mx = 0;
            for (const auto* m : g2) { my += m->cy; mx += m->cx; }
            my /= (double)g2.size();
            mx /= (double)g2.size();
            double sxy = 0, syy = 0;
            for (const auto* m : g2) { sxy += (m->cy - my) * (m->cx - mx); syy += (m->cy - my) * (m->cy - my); }
            if (syy > 1e-9) reps.push_back({mx, my, sxy / syy});
        } else {
            const Mark* m = g2[0];
            const double sa = std::abs(std::sin(m->theta));
            if (sa > 0.05) reps.push_back({m->cx, m->cy, 1.0 / std::tan(m->theta)});
        }
    }
    if (reps.size() < 2) return;
    std::sort(reps.begin(), reps.end(), [](const Rep& a, const Rep& b) { return a.cx < b.cx; });

    double y_bot = 0;
    for (const auto& m : marks) y_bot = std::max(y_bot, m.y1);
    const double lo = y_h + 0.45 * (y_bot - y_h);
    if (lo >= y_bot) return;

    std::vector<std::pair<double, double>> pairs;
    std::vector<double> meds;
    const int NS = 14;
    for (int i = 0; i < NS; ++i) {
        const double y = lo + (y_bot - lo) * i / (NS - 1);
        std::vector<double> xs;
        for (const auto& r : reps) xs.push_back(r.cx + r.k * (y - r.cy));
        std::sort(xs.begin(), xs.end());
        std::vector<double> d;
        for (size_t k = 0; k + 1 < xs.size(); ++k)
            if (xs[k + 1] - xs[k] > 5 * px_scale) d.push_back(xs[k + 1] - xs[k]);
        if (!d.empty()) {
            std::sort(d.begin(), d.end());
            meds.push_back(d[d.size() / 2]);
            for (double v : d) pairs.emplace_back(y, v);
        }
    }
    if (meds.size() < 3) return;
    std::sort(meds.begin(), meds.end());
    const double gm = meds[meds.size() / 2];
    std::vector<std::pair<double, double>> keep;
    for (const auto& p : pairs)
        if (p.second > 0.5 * gm && p.second < 2.0 * gm) keep.push_back(p);
    *hc_lane = h_c_one_param(keep, y_h, lane_w, has_geo, cy, f, px_scale);
}

struct FrameMeas {
    bool has_vp = false;
    Vp vp;
    double y_h = 0;
    Est h_c_paint, h_c_lane, A_dash, A_gap, A_period;
    double L_over_P = 0;
    bool has_lp = false;
    int n_marks = 0, n_lines = 0;
    bool has_hc = false;
    double h_c = 0;
    // 自标定焦距：迭代里由 f = A_dash/h_c 反解出来的（A_dash 来自虚线段长 + 道路标准），
    // 不依赖相机标称值。收敛条件见 measure() 末尾的 2% 判据。
    bool has_f_est = false;
    double f_est = 0;
    bool has_A = false;
    double A = 0;
};

// 量一帧。standard 必须显式给（auto 判定在板上由 --road-type 代替）。
// v_thr / s_thr 是「白色路面标线」的全局 HSV 判据，默认 110/90 与 Python 侧一致。
// 放到尾部带默认值，是为了在过曝路面（路面本身就 V>110 且低饱和）的视频上能从
// 命令行抬阈值做实验，默认路径逐位不变。
inline FrameMeas measure(const cv::Mat& bgr, const std::array<int, 4>& roi,
                         const Standard& std_, double lane_w = 3.50, double paint_w = 0.15,
                         double min_dy = 60.0, double vp_tol = 8.0,
                         int v_thr = 110, int s_thr = 90, int src_h = 0,
                         double fixed_yh = 0.0,
                         std::vector<Mark>* marks_out = nullptr) {
    FrameMeas fm;
    const int h = bgr.rows;
    // 以 1080p 为标称分辨率；480p 输入时 scale≈0.444
    //
    // src_h 是「源帧高度」，只有 bgr 是 ROIs 裁剪图时才需要显式给。
    // 不给（=0）就退回按 bgr.rows 算，与 Python 侧逐位一致。
    // 融合到 navread 时必须给：那里传的是路面 ROI 裁剪图（约 190 行），
    // 按它算 scale 会得到 0.17，min_area 从 50 掉到 1.5 px，噪声全被当成标线。
    const double scale = (double)(src_h > 0 ? src_h : h) / 1080.0;
    min_dy = std::max(1.0, min_dy * scale);
    auto marks = find_marks(bgr, roi, v_thr, s_thr, 50, 2.2, 12.0, 300.0, 45.0, scale);
    fm.n_marks = (int)marks.size();
    if (marks.size() < 2) return fm;

    // 路 1：倾角 -> 消失点（两轮：先粗求，再用内点重求）
    std::vector<Mark> vp_marks = marks;
    std::sort(vp_marks.begin(), vp_marks.end(),
              [](const Mark& a, const Mark& b) { return a.len_px > b.len_px; });
    if (vp_marks.size() > 8) vp_marks.resize(8);
    const double floor_y = std::max(0.15 * h, roi[1] - 0.5 * h);
    Vp vp = estimate_vp(vp_marks, roi[1] + 150.0 * scale, floor_y, 1.5, scale);
    if (!vp.ok) return fm;

    std::vector<Mark> keep;
    for (const auto& m : marks)
        if (vp_resid_deg(m, vp.vx, vp.vy) <= vp_tol) keep.push_back(m);
    if (keep.size() >= 2) {
        std::vector<Mark> sub = keep;
        std::sort(sub.begin(), sub.end(), [](const Mark& a, const Mark& b) { return a.len_px > b.len_px; });
        if (sub.size() > 12) sub.resize(12);
        Vp vp2 = estimate_vp(sub, roi[1] + 150.0 * scale, floor_y, 1.5, scale);
        if (vp2.ok) {
            vp = vp2;
            marks.swap(keep);
            fm.n_marks = (int)marks.size();
        }
    }
    if (marks_out) *marks_out = marks;   // 内点标线：段级拟合用
    fm.has_vp = true;
    fm.vp = vp;
    fm.y_h = vp.vy;
    // 段级地平线（fixed_yh > 0 时生效）。
    //
    // 为什么必须能固定：单帧 VP 只由一两条短线定出来，vy 的噪声可达几十像素；
    // 而 h_c 对 (行号 − y_h) 极其敏感——y_h 偏高几十像素就足以让 h_c 小一半以上，
    // 因为 h_c_one_param 里 `row - y_h <= 3` 会把地平线以上的样本**全部丢掉**，
    // 只剩最靠近相机那一小片，估计严重欠条件。地平线是这个片段的**场景常数**，
    // 不该逐帧估。这里只替换 vy，分组与纵向三路仍用逐帧 vp。
    if (fixed_yh > 0.0) fm.y_h = fixed_yh;
    fm.n_lines = (int)group_lines(marks, vp.vx, vp.vy).size();

    // 纵向三路只用没贴边的块（贴边 dy 被截断，A 一定偏大）
    std::vector<std::vector<Mark>> lines_long;
    for (auto& g : group_lines(marks, vp.vx, vp.vy)) {
        std::vector<Mark> f;
        for (const auto& m : g)
            if (!m.clipped) f.push_back(m);
        if (!f.empty()) lines_long.push_back(std::move(f));
    }

    const double cy = 0.5 * h;
    bool has_geo = false;
    double f_est = 0;
    for (int it = 0; it < 3; ++it) {
        fill_lateral(fm.y_h, marks, group_lines(marks, vp.vx, vp.vy), lane_w, paint_w,
                     has_geo, cy, f_est, &fm.h_c_paint, &fm.h_c_lane, scale);
        LongTerms lt = long_terms(lines_long, fm.y_h, std_.L, std_.G, min_dy, has_geo, cy, f_est,
                                  scale);
        fm.has_lp = !lt.ratios.empty();
        if (fm.has_lp) {
            std::sort(lt.ratios.begin(), lt.ratios.end());
            fm.L_over_P = lt.ratios[lt.ratios.size() / 2];
        }
        fm.A_dash = median_est(lt.Ad);
        fm.A_gap = median_est(lt.Ag);
        fm.A_period = median_est(lt.Ap);
        if (!fm.A_dash.ok) break;
        // f_est 必须用**与 Python 相同的合并口径**（含剔除自身过散的一路），
        // 否则核在迭代里走的是另一条路，最后 h_c 会差零点几个百分点。
        double hc = 0.0;
        {
            std::vector<const Est*> u;
            if (fm.h_c_paint.ok && fm.h_c_paint.spread <= 0.15) u.push_back(&fm.h_c_paint);
            if (fm.h_c_lane.ok && fm.h_c_lane.spread <= 0.15) u.push_back(&fm.h_c_lane);
            if (u.empty()) {
                if (fm.h_c_paint.ok) u.push_back(&fm.h_c_paint);
                if (fm.h_c_lane.ok) u.push_back(&fm.h_c_lane);
            }
            if (!u.empty()) hc = u.size() == 1 ? u[0]->value : 0.5 * (u[0]->value + u[1]->value);
        }
        if (hc <= 0) break;
        const double f_new = fm.A_dash.value / hc;
        if (!(f_new > 80.0 && f_new < 20000.0)) break;
        if (has_geo && std::abs(f_new - f_est) <= 0.02 * f_est) {
            fm.has_f_est = true;
            fm.f_est = f_new;
            break;
        }
        has_geo = true;
        f_est = f_new;
    }
    // 迭代没到 2% 收敛也可能已经稳定，把最后一次的估计留下来（标 has_f_est 只表示收敛）
    if (!fm.has_f_est && f_est > 0) fm.f_est = f_est;

    // h_c 两路：与 Python 的 _combine 一致 —— **先剔除自身 spread > 15% 的那一路**，
    // 剩下的取中位（两路时即均值）；两路都被剔除时才退回用原始两路。
    // 漏掉这一步会在「一路很散」的帧上差出一个因子（实测第 5 帧 0.85 vs 1.26）。
    std::vector<const Est*> hc_use;
    if (fm.h_c_paint.ok && fm.h_c_paint.spread <= 0.15) hc_use.push_back(&fm.h_c_paint);
    if (fm.h_c_lane.ok && fm.h_c_lane.spread <= 0.15) hc_use.push_back(&fm.h_c_lane);
    if (hc_use.empty()) {
        if (fm.h_c_paint.ok) hc_use.push_back(&fm.h_c_paint);
        if (fm.h_c_lane.ok) hc_use.push_back(&fm.h_c_lane);
    }
    if (!hc_use.empty()) {
        fm.has_hc = true;
        fm.h_c = hc_use.size() == 1 ? hc_use[0]->value
                                    : 0.5 * (hc_use[0]->value + hc_use[1]->value);
    }

    // A 两票：直测优先，配对只作校验
    if (fm.A_dash.ok) {
        fm.has_A = true;
        fm.A = fm.A_dash.value;
    } else if (fm.A_gap.ok || fm.A_period.ok) {
        std::vector<double> v;
        if (fm.A_gap.ok) v.push_back(fm.A_gap.value);
        if (fm.A_period.ok) v.push_back(fm.A_period.value);
        std::sort(v.begin(), v.end());
        fm.has_A = true;
        fm.A = v[v.size() / 2];
    }
    return fm;
}

}  // namespace lane_calib
