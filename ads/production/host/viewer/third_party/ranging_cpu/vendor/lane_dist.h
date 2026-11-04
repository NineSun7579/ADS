// lane_dist.h —— 单目测距（框高法 + 地面平面法 + 交叉校验）的 C++ 移植。
//
// 纯头文件、不依赖 OpenCV/rknn，任何机器上都能 g++ 编译并跑数值断言
// （做法同 tools/seg_decide.h）。板上由 vidview 复用它算米数。
//
// 与 Python 侧 `src/distance.py` 的口径**逐条对齐**，对照方法见
// tools/gen_lane_dist_golden.py + tools/test_lane_dist.cpp：
// 生成器用 Python 算出期望值写成一个 C++ 头文件，测试逐项断言。
//
// 刻意**不做**移植的部分（板上用不到，且都是离线分析工具）：
// fit_ground_model / implied_camera_height / ground_sensitivity / budget_table。
//
// 一处刻意的偏离：Python 的 `note` 是中文诊断文本，这里一律用 ASCII。
// 板上 cv2/Hershey 画不了 CJK，且 note 只进日志不进画面；数值与 flags 完全一致。
#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <vector>

namespace lane_dist {

constexpr double kPi = 3.14159265358979323846;
constexpr double kDefaultHfovDeg = 60.0;

// 类别真实高度先验（米）: H, sigma。与 Python 的 CLASS_HEIGHT_M 完全一致。
struct ClassPrior {
    int cls;
    double h_m;
    double sigma;
    std::string name;   // 只用于日志；内表不填
};
inline const std::vector<ClassPrior>& class_priors() {
    static const std::vector<ClassPrior> v = {
        {0, 1.50, 0.15},   // car
        {1, 3.10, 0.12},   // bus
        {2, 3.30, 0.15},   // truck
        {3, 1.70, 0.07},   // person
        {4, 1.65, 0.10},   // rider
        {5, 1.05, 0.25},   // bike
        {6, 1.50, 0.20},   // motor
    };
    return v;
}

// 明确拒绝给距离的类（尺寸先验不成立）。值与 Python 的 NO_PRIOR_REASON 一致。
inline bool is_no_prior(int cls) { return cls >= 7 && cls <= 10; }

inline double focal_px(double width_px, double hfov_deg = kDefaultHfovDeg) {
    if (width_px <= 0.0) throw std::invalid_argument("width_px must be > 0");
    if (!(hfov_deg > 0.0 && hfov_deg < 179.0))
        throw std::invalid_argument("hfov_deg must be in (0,179)");
    return (width_px * 0.5) / std::tan(hfov_deg * kPi / 180.0 * 0.5);
}

// 「模型像素 -> 原图像素」的仿射：x_src = ox + sx*x_model（y 同理）。
struct Geometry {
    double sx = 1.0, sy = 1.0, ox = 0.0, oy = 0.0;
    int src_w = 0, src_h = 0, model_w = 0, model_h = 0;

    std::array<double, 4> to_source(const std::array<double, 4>& b) const {
        return {ox + sx * b[0], oy + sy * b[1], ox + sx * b[2], oy + sy * b[3]};
    }
};

struct Config {
    double hfov_deg = kDefaultHfovDeg;
    bool has_f_px = false;      // Python 用 f_px is None 表达「未标定」
    double f_px = 0.0;
    double prior_scale = 1.0;
    double min_h_px = 6.0;
    double max_m = 100.0;
    double z_offset_m = 0.0;
    double max_radius = 0.0;
    // 类别先验**整套替换**用：非空时不再查内表 class_priors()。
    //
    // 必须有这个口子，因为框可能来自任意模型：内表是「11 类 b2」的约定
    // （0=小汽车），而 COCO 的 0 是 person。套错先验会算出「看起来很正常的错数」，
    // 比不给数字糟得多。映射里高度 <= 0 表示「该类拒绝给距离」。
    const std::vector<ClassPrior>* priors = nullptr;
};

struct GroundConfig {
    double camera_height_m = 1.30;
    double pitch_deg = 0.0;
    bool has_horizon_row = false;
    double horizon_row = 0.0;
    double height_sigma = 0.10;
    double min_rows_below_horizon = 3.0;
    double max_m = 100.0;
};

struct Estimate {
    int cls = 0;
    bool has_depth = false;
    // 未给数字时一律 NaN —— 与 Python 的 None 对应，误读会立刻暴露而不是当成 0m
    double depth_m = NAN, slant_m = NAN, lo_m = NAN, hi_m = NAN, rel_err = NAN;
    double h_src_px = 0.0;
    std::vector<std::string> flags;
    std::string note;
    std::string method = "size";     // "size" | "ground"

    bool ok() const { return has_depth; }
    // 连框都不画：超 100m，或减完取景原点补偿后 <= 0（假阳，见 Python 的 drop 注释）
    bool drop() const {
        return std::find(flags.begin(), flags.end(), "too_far") != flags.end() ||
               std::find(flags.begin(), flags.end(), "near_clip") != flags.end();
    }
};

struct CrossCheck {
    bool has_ratio = false;
    double ratio = 0.0;
    std::string verdict;   // agree / disagree / size_only / ground_only / no_data
    std::string hint;
};

inline std::pair<double, double> horizon_row_of(int src_h, double f_px,
                                                const GroundConfig& g) {
    const double cy = 0.5 * static_cast<double>(src_h);
    if (g.has_horizon_row) {
        const double y_h = g.horizon_row;
        return {y_h, std::atan((cy - y_h) / f_px)};
    }
    const double pitch = g.pitch_deg * kPi / 180.0;
    return {cy - f_px * std::tan(pitch), pitch};
}

inline Estimate estimate(int cls_id, const std::array<double, 4>& box,
                         const Geometry& geom, const Config& cfg) {
    const auto s = geom.to_source(box);
    const double x1 = s[0], y1 = s[1], x2 = s[2], y2 = s[3];
    const double h = y2 - y1, w = x2 - x1;

    Estimate est;
    est.cls = cls_id;

    if (cfg.priors == nullptr && is_no_prior(cls_id)) {  // 先算框高再判类别：框高是事实
        est.h_src_px = h;
        est.flags = {"no_prior"};
        est.note = "class has no usable size prior";
        return est;
    }
    const std::vector<ClassPrior>& tbl = cfg.priors ? *cfg.priors : class_priors();
    const ClassPrior* prior = nullptr;
    for (const auto& p : tbl)
        if (p.cls == cls_id) prior = &p;
    // 外部映射里高度 <= 0：显式声明「这类不给数」（红绿灯、交通标志之类）
    if (prior != nullptr && prior->h_m <= 0.0) {
        est.h_src_px = h;
        est.flags = {"no_prior"};
        est.note = "class marked no-prior by class map";
        return est;
    }
    if (prior == nullptr) {
        est.h_src_px = h;
        est.flags = {"unknown_class"};
        est.note = "class has no size prior";
        return est;
    }
    if (!(h > 0.0 && w > 0.0)) {
        est.h_src_px = h;
        est.flags = {"degenerate"};
        est.note = "non-positive box height/width";
        return est;
    }

    // 像素阈值随分辨率缩（以 1080p 为标称）；米制先验不缩。
    const double px_scale = geom.src_h > 0 ? (double)geom.src_h / 1080.0 : 1.0;
    est.h_src_px = h;
    if (h < cfg.min_h_px * px_scale) {
        est.flags = {"too_small"};
        est.note = "box height below min_h_px";
        return est;
    }

    const double f = cfg.has_f_px ? cfg.f_px : focal_px(geom.src_w, cfg.hfov_deg);
    const double raw = f * (prior->h_m * cfg.prior_scale) / h;
    double depth = raw + cfg.z_offset_m;
    const bool near_clip = depth <= 0.0;
    if (near_clip) depth = 0.0;

    std::vector<std::string> flags;
    // 截断必须用**模型空间**坐标判：拿原图坐标跟 model_h 比会把几乎所有目标误判。
    if (box[1] <= 0.5 || box[3] >= geom.model_h - 0.5) flags.push_back("truncated");
    if (depth > cfg.max_m) flags.push_back("too_far");
    if (!cfg.has_f_px) flags.push_back("f_assumed");

    // 1000px 是 1080p 下的归一化半径；换分辨率必须同比缩，否则 gate 会失效
    const double r_norm = std::hypot(0.5 * (x1 + x2) - 0.5 * geom.src_w,
                                     0.5 * (y1 + y2) - 0.5 * geom.src_h) /
                          (1000.0 * px_scale);
    if (cfg.max_radius > 0.0 && r_norm > cfg.max_radius) {
        est.h_src_px = h;
        est.flags = flags;
        est.flags.push_back("off_axis");
        est.note = "outside max_radius: radial distortion makes meters unreliable";
        return est;
    }
    if (near_clip) flags.push_back("near_clip");

    const double rel = std::hypot(1.0 / h, prior->sigma);
    const double cx = 0.5 * (x1 + x2) - 0.5 * geom.src_w;

    est.has_depth = true;
    est.depth_m = depth;
    est.slant_m = depth * std::sqrt(1.0 + (cx / f) * (cx / f));
    est.rel_err = rel;
    est.lo_m = std::max(0.0, raw * (1.0 - rel) + cfg.z_offset_m);
    est.hi_m = std::max(0.0, raw * (1.0 + rel) + cfg.z_offset_m);
    est.flags = flags;
    return est;
}

inline Estimate ground_distance(int cls_id, const std::array<double, 4>& box,
                                const Geometry& geom, const Config& cfg,
                                const GroundConfig& g) {
    const auto s = geom.to_source(box);
    const double x1 = s[0], y1 = s[1], x2 = s[2], y2 = s[3];

    Estimate est;
    est.cls = cls_id;
    est.method = "ground";

    // 红绿灯/交通标志不在地面平面上。内表按 7~10 判；给了外部映射就按映射判
    // （映射里没有、或高度 <= 0 的类都视为不在地面平面上）。
    bool on_ground = !(cls_id >= 7 && cls_id <= 10);
    if (cfg.priors != nullptr) {
        on_ground = false;
        for (const auto& p : *cfg.priors)
            if (p.cls == cls_id && p.h_m > 0.0) on_ground = true;
    }
    if (!on_ground) {
        est.flags = {"not_on_ground"};
        est.note = "class is not on the ground plane";
        return est;
    }
    if (g.camera_height_m <= 0.0) {
        est.flags = {"bad_geometry"};
        est.note = "camera_height_m must be > 0";
        return est;
    }

    const double f = cfg.has_f_px ? cfg.f_px : focal_px(geom.src_w, cfg.hfov_deg);
    const double cy = 0.5 * static_cast<double>(geom.src_h);
    const auto hz = horizon_row_of(geom.src_h, f, g);
    const double y_h = hz.first, pitch = hz.second;

    est.h_src_px = y2 - y1;
    if (y2 <= y_h + g.min_rows_below_horizon) {
        est.flags = {"above_horizon"};
        est.note = "box bottom is not below the horizon";
        return est;
    }

    const double ang = pitch + std::atan((y2 - cy) / f);
    if (ang <= 1e-6) {
        est.flags = {"above_horizon"};
        est.note = "viewing angle <= 0";
        return est;
    }

    const double raw = g.camera_height_m / std::tan(ang);
    double depth = raw + cfg.z_offset_m;
    const bool near_clip = depth <= 0.0;
    if (near_clip) depth = 0.0;

    std::vector<std::string> flags;
    if (!g.has_horizon_row && std::abs(g.pitch_deg) < 1e-9) flags.push_back("pitch_assumed");
    if (!g.has_horizon_row) flags.push_back("horizon_assumed");
    if (depth > g.max_m) flags.push_back("too_far");
    if (near_clip) flags.push_back("near_clip");

    const double rel = std::hypot(1.0 / std::max(1.0, y2 - y_h), g.height_sigma);
    const double dx = 0.5 * (x1 + x2) - 0.5 * geom.src_w;

    est.has_depth = true;
    est.depth_m = depth;
    est.slant_m = depth * std::sqrt(1.0 + (dx / f) * (dx / f));
    est.rel_err = rel;
    est.lo_m = std::max(0.0, raw * (1.0 - rel) + cfg.z_offset_m);
    est.hi_m = std::max(0.0, raw * (1.0 + rel) + cfg.z_offset_m);
    est.flags = flags;
    return est;
}

// 在线标定的地面尺度核：A=f*h_c 与 y_h 已知时，f/h_c 的拆分会被约掉。
// 与 ground_distance 使用同一个精确针孔关系，但不需要猜测 f 或相机高度。
inline double ground_depth_A(double y_bottom, double A, double y_h,
                             int src_h, double cy, double f_px) {
    if (!(A > 0 && f_px > 0 && y_bottom > y_h)) return NAN;
    const double pitch = std::atan((cy - y_h) / f_px);
    const double ang = pitch + std::atan((y_bottom - cy) / f_px);
    if (!(ang > 1e-6)) return NAN;
    return A / (f_px * std::tan(ang));
}

inline CrossCheck cross_check(const Estimate& size, const Estimate& ground,
                              double tol = 0.25) {
    CrossCheck cc;
    if (!size.ok() && !ground.ok()) {
        cc.verdict = "no_data";
        cc.hint = !size.note.empty() ? size.note : ground.note;
        return cc;
    }
    if (!size.ok()) {
        cc.verdict = "ground_only";
        cc.hint = "size method gave no number";
        return cc;
    }
    if (!ground.ok()) {
        cc.verdict = "size_only";
        cc.hint = "ground method gave no number";
        return cc;
    }
    cc.has_ratio = true;
    cc.ratio = ground.depth_m / size.depth_m;
    if (std::abs(cc.ratio - 1.0) <= tol) {
        cc.verdict = "agree";
        char buf[96];
        std::snprintf(buf, sizeof buf, "methods differ by %.0f%%", std::abs(cc.ratio - 1.0) * 100.0);
        cc.hint = buf;
        return cc;
    }
    cc.verdict = "disagree";
    cc.hint = cc.ratio < 1.0 ? "ground nearer: contact point or size prior off (low)"
                             : "ground farther: contact point or size prior off (high)";
    return cc;
}

// 纯米数：>=10m 取整、1~10m 一位小数、<1m 两位小数（与 Python 的 _num 一致）。
inline std::string num(double d) {
    char buf[32];
    if (d >= 10.0) std::snprintf(buf, sizeof buf, "%.0fm", d);
    else if (d >= 1.0) std::snprintf(buf, sizeof buf, "%.1fm", d);
    else std::snprintf(buf, sizeof buf, "%.2fm", d);
    return buf;
}

inline bool center_m(const Estimate& est, bool has_depth, double depth, double* out) {
    if (has_depth) { *out = depth; return true; }
    if (est.has_depth) {
        *out = 0.5 * (est.lo_m + est.hi_m);
        return true;
    }
    return false;
}

inline std::string fmt(const Estimate& est, bool has_depth = false, double depth = 0.0) {
    double z = 0.0;
    if (!center_m(est, has_depth, depth, &z)) return "";
    return num(z);
}

// 框高法读数 + 一个对照标记：= 一致、! 分歧、? 只有一条方法给得出。
inline std::string fmt_cross(const Estimate& size, const CrossCheck& cc,
                             bool has_depth = false, double depth = 0.0) {
    const std::string base = fmt(size, has_depth, depth);
    if (base.empty()) return "";
    const char mark = cc.verdict == "agree" ? '=' : (cc.verdict == "disagree" ? '!' : '?');
    return base + mark;
}

// 按 IoU 关联的逐类 EMA 平滑（不做跨帧身份管理，够显示用）。
class Smoother {
public:
    struct Track {
        int cls = 0;
        std::array<double, 4> box{};
        double d = 0.0;
        int miss = 0;
    };

    double alpha = 0.35;
    double iou_thr = 0.3;
    int max_miss = 5;
    std::vector<Track> tracks;

    explicit Smoother(double a = 0.35, double thr = 0.3, int miss = 5)
        : alpha(a), iou_thr(thr), max_miss(miss) {
        if (!(a > 0.0 && a <= 1.0)) throw std::invalid_argument("alpha must be in (0,1]");
    }

    static double iou(const std::array<double, 4>& a, const std::array<double, 4>& b) {
        const double ix1 = std::max(a[0], b[0]), iy1 = std::max(a[1], b[1]);
        const double ix2 = std::min(a[2], b[2]), iy2 = std::min(a[3], b[3]);
        const double iw = std::max(0.0, ix2 - ix1), ih = std::max(0.0, iy2 - iy1);
        const double inter = iw * ih;
        if (inter <= 0.0) return 0.0;
        const double area = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter;
        return area > 0.0 ? inter / area : 0.0;
    }

    // 返回与输入等长的平滑深度；has[i]==false 表示这一帧没数字。
    void update(const std::vector<std::array<double, 4>>& boxes,
                const std::vector<int>& labels, const std::vector<Estimate>& ests,
                std::vector<double>& vals, std::vector<char>& has) {
        vals.assign(boxes.size(), 0.0);
        has.assign(boxes.size(), 0);
        std::vector<char> used(tracks.size(), 0);

        for (size_t i = 0; i < boxes.size() && i < ests.size(); ++i) {
            if (!ests[i].ok()) continue;
            int best = -1;
            double best_iou = iou_thr;
            for (size_t j = 0; j < tracks.size(); ++j) {
                if (used[j] || tracks[j].cls != labels[i]) continue;
                const double v = iou(boxes[i], tracks[j].box);
                if (v > best_iou) { best = static_cast<int>(j); best_iou = v; }
            }
            if (best < 0) {
                tracks.push_back({labels[i], boxes[i], ests[i].depth_m, 0});
                used.push_back(1);
                vals[i] = ests[i].depth_m;
                has[i] = 1;
            } else {
                auto& t = tracks[static_cast<size_t>(best)];
                t.d = alpha * ests[i].depth_m + (1.0 - alpha) * t.d;
                t.box = boxes[i];
                t.miss = 0;
                used[static_cast<size_t>(best)] = 1;
                vals[i] = t.d;
                has[i] = 1;
            }
        }
        for (size_t j = 0; j < tracks.size(); ++j)
            if (!used[j]) ++tracks[j].miss;
        std::vector<Track> keep;
        keep.reserve(tracks.size());
        for (auto& t : tracks)
            if (t.miss <= max_miss) keep.push_back(t);
        tracks.swap(keep);
    }
};

}  // namespace lane_dist
