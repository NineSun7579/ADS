#pragma once
// 单目部分解算 · 估计层（mono_estimator）
// 由离线验证版 enginep.py 逐行移植，只保留报告第 13 节建议接入的部分：
//   P1 地平线三来源融合 + 12px/2s 时间闸
//   P2 h_c 车道宽斜率 → 标线宽斜率 → 车宽，2s 中位
//   P3 单段完整虚线即可给 A（截顶跨度为权重、加权中位）
//   P4 f=A/h_c，车宽法接力
//   P5 只保留 e1（近处 L/G，两段跨度都 ≥S_min）
//   P6 车道归属
// e2（漆宽/车道宽比）、e3（俯仰先验）、黄线直接判档一律不实现，也不提供开关。
// 无镜头常量、无标定文件、无持久化；状态全在内存，切源/改几何由调用方 reset()。
#include "mono_measure.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <deque>
#include <map>
#include <set>
#include <string>
#include <vector>
#ifdef MONO_PARTIAL_DEBUG
#include <cstdio>
#endif

namespace mono_partial {

struct Config {
    // P1
    bool useVp = true, useWidthY = true, usePaintVh = true;
    double paintMinWidth = 3., paintMinRows = 6., paintMinSpan = 40.;
    // P2
    bool useLaneH = true, usePaintH = true, useVehicleH = true;
    double laneWidth = 3.5, paintWidth = .15, vehicleWidth = 1.8;
    double hcMin = .5, hcMax = 4., hcWindow = 2.;
    // P3 / P4
    bool singleSegment = true, relay = true;
    double window = 5.;  // 尺度窗口（秒），与 enginep.py CFG 一致
    // P3' 长窗口稳健估计（本任务新增）：
    //   A 取 AWindow 秒内各时间桶 A 的加权中位；偏离 ADeviate 的桶进挑战集，
    //   同方向持续 AChallengeSeconds 且数量 ≥ AChallengeMin 才替换主值。
    double AWindow = 60.;
    double ADeviate = .30;
    double AChallengeSeconds = 10.;
    int AChallengeMin = 6;
    //   v_h 同理：vhWindow 秒中位，偏离 vhDeviate 像素进挑战集，
    //   持续 vhChallengeSeconds 且数量 ≥ vhChallengeMin 才替换。
    double vhWindow = 20.;
    double vhDeviate = 8.;
    double vhChallengeSeconds = 5.;
    int vhChallengeMin = 4;
    // P5
    bool e1 = true;
    double sMin = 20., pFirst = .9, tContra = 5., tau = 20., delta = 2., pHi = .9, ratioSigma = .18;
    // P1：ratioSigma 的来源。0 = 固定常数（现状）；1 = 由误差模型逐帧给出，并用 floor 兜底。
    // floor 代表无法建模的系统性截断偏置（0 = 完全由误差模型决定）。
    int ratioSigmaMode = 0;
    double ratioSigmaFloor = 0.;
    int K = 4;
    // E2（证据形式）：三端点 pair —— 近段两端完整 + 下一段"近端"可信即可成 pair，
    // 下一段的远端允许被截断。关闭时与改动前逐位一致。
    bool threeEndpointPair = false;
    // P0：远段长度可信性检查（A 空间跨度 vs 近段）；0 = 关闭。
    // 默认 0：实测无效且有害 —— 合成里在失败工况（cut=6/rate=0.6）触发 0 次，
    // 在 6_9 干净场景却每帧拒 2 个合法 pair；实拍路口 A 的 IQR 72.6 → 353.7。
    // 原因是远场碎片本身就会产生"完整但很短"的段，无法与真截断区分。保留代码供复现。
    double farLengthZ = 0.0;
    // E1（证据形式）：掩码断口的灰度桥接，断口行数上限；0 = 关闭。
    int bridgeRows = 0;
    // C3 档位自洽性（阈值全部来自 fixed_defaults.json 的误差模型推导，不含任何素材量）：
    //   三类观测（dash/gap/period）各自换算出 A；正确档位下三者须在端点误差允许范围内一致。
    bool tierConsistency = false;
    double consistTauC = 3.5;      // max|z| 上限（χ²(2) 族错误率 0.14% 对应的 3.5σ）
    double consistRho = 2.0;       // 次佳档位的离散度至少是最佳的 rho 倍
    double endpointSigma = 1.0;    // 端点随机误差 b（px）：掩码 1 行量化 + 剖面插值的主导项
    double endpointBias = 1.5;     // 每段跨度的系统偏差（px）：合成真值实测，dash 类相对偏差 13.5%@11px
    double endpointBiasSigma = 0.5;  // 该偏差本身的离散（px）：只用于把 σ 抬到一个不再随样本数收缩的地板
    // 保持 / 分级
    double holdLimit = 120., freshSeconds = 2., dispersion = .25;
    double horizonLimit = 12., horizonSeconds = 2.;
    double bucket = .5;
    // P6
    bool laneAssign = true;
    int laneMaxOffset = 1;
    // 线对"米宽"合理性门限（相对 cfg.laneWidth）：<0.6 或 >1.45 判为该线对不是一条车道。
    // 依据：hc 按 laneWidth 从自车道那对边界拟合，自车道的换算宽度必然≈laneWidth；
    // 同一条路上相邻车道的宽度差远小于 40%，而漏一条边界≈2×、把双线当车道≈0.1×。
    double laneWidthRatioLo = 0.6, laneWidthRatioHi = 1.45;
    // P7 框滤波（本任务新增）：
    //   空间闸门——脚点 1px 抖动会被 Z/A 放大成 Z/A 的比例误差（20m 3.5%、60m 10.5%），
    //   所以框太小或脚点离地平线太近时直接不出数（框仍画、只是没有米数）。
    //   时间滤波——同一目标（IoU 关联）取最近 trackMedian 帧的脚点/框高中位，
    //   抗单帧跳点；新目标没有历史时用本帧原值，保证立即出数。
    double gateMinH = 6.;         // px，框高下限（实测 12 会把 lane77 出数率砍到 40%）
    double gateMinGap = 8.;       // px，foot - v_h 下限（仅约束 ground，width 不用脚点）
    double gateMaxMeters = 100.;  // m，两种方法的统一距离上限（>100m 一律不出数）
    int trackMedian = 3;          // 中位窗口帧数（偶数取中间两值均值；1=关闭平滑）
    double trackIou = .5;         // 关联阈值
    double trackHoldSeconds = .5; // 轨迹丢失多久后丢弃
    // 对拍/诊断：把进入长窗口的原始观测记录下来（默认关闭，正常路径只多一次 if）
    bool recordObservations = false;
};

enum Tier { TierWhite24 = 0, TierWhite39 = 1, TierWhite69 = 2, TierYellow46 = 3 };
enum Mode { ModeDefault24 = 0, ModeDecided = 1, ModeReEvaluating = 2 };
enum Grade { GradeNone = 0, GradeUncertain = 1, GradeApprox = 2 };
enum Method { MethodNone = 0, MethodGround = 1, MethodWidth = 2 };
enum HorizonSource { SrcVp = 0, SrcLaneWidth = 1, SrcPaintWidth = 2, SrcCount = 3 };

inline double specL(Tier t) { return t == TierWhite24 ? 2. : t == TierWhite39 ? 3. : t == TierWhite69 ? 6. : 4.; }
inline double specG(Tier t) { return t == TierWhite24 ? 4. : t == TierWhite39 ? 9. : t == TierWhite69 ? 9. : 6.; }
inline const char* tierName(Tier t) {
    switch (t) {
        case TierWhite24: return "white_2_4";
        case TierWhite39: return "white_3_9";
        case TierWhite69: return "white_6_9";
        default: return "yellow_4_6";
    }
}
inline const char* modeName(Mode m) {
    return m == ModeDecided ? "decided" : m == ModeReEvaluating ? "re_evaluating" : "default_2_4";
}
inline const char* gradeName(Grade g) {
    return g == GradeApprox ? "approx" : g == GradeUncertain ? "uncertain" : "none";
}

namespace detail {
inline double median(std::vector<double> v) {
    if (v.empty()) return NAN;
    std::sort(v.begin(), v.end());
    const size_t n = v.size();
    return n % 2 ? v[n / 2] : .5 * (v[n / 2 - 1] + v[n / 2]);
}
inline double ptp(const std::vector<double>& v) {
    if (v.empty()) return 0.;
    const auto mm = std::minmax_element(v.begin(), v.end());
    return *mm.second - *mm.first;
}
// numpy.ndarray.sum() 对连续 float64 用成对求和，与逐项累加在最后一位上不同。
// 这里复刻它（<8 顺序；≤128 先 8 路再配对；更大则二分），以便与 Python 位级一致。
inline double numpySum(const double* a, size_t n) {
    if (n < 8) {
        double res = 0;
        for (size_t i = 0; i < n; ++i) res += a[i];
        return res;
    }
    if (n <= 128) {
        double r[8] = {a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]};
        size_t i = 8;
        for (; i < n - (n % 8); i += 8)
            for (int j = 0; j < 8; ++j) r[j] += a[i + j];
        double res = ((r[0] + r[1]) + (r[2] + r[3])) + ((r[4] + r[5]) + (r[6] + r[7]));
        for (; i < n; ++i) res += a[i];
        return res;
    }
    const size_t half = n / 2;
    return numpySum(a, half) + numpySum(a + half, n - half);
}
inline double numpySum(const std::vector<double>& v) { return numpySum(v.data(), v.size()); }
// 一维最小二乘拟合（numpy.polyfit deg=1 的闭式解）
inline bool fitLine1(const std::vector<double>& x, const std::vector<double>& y, double& slope, double& inter) {
    const size_t n = x.size();
    if (n < 2) return false;
    double mx = 0, my = 0;
    for (size_t i = 0; i < n; ++i) { mx += x[i]; my += y[i]; }
    mx /= n; my /= n;
    double num = 0, den = 0;
    for (size_t i = 0; i < n; ++i) { num += (x[i] - mx) * (y[i] - my); den += (x[i] - mx) * (x[i] - mx); }
    if (!(std::abs(den) > 1e-12)) return false;
    slope = num / den;
    inter = my - slope * mx;
    return true;
}
}  // namespace detail

struct Horizon {
    double vpX = NAN, vpY = NAN, widthY = NAN, slope = NAN;
};

inline Horizon computeHorizon(const std::vector<Line>& lines) {
    Horizon h;
    std::vector<const Line*> central;
    for (const auto& l : lines) {  // 只有落在中央 50% 的线参与消失点
        const double lo = std::max(l.y0, 205.), hi = std::min(l.y1, 416.);
        if (!(hi > lo)) continue;
        std::vector<double> ys, xs;
        for (int i = 0; i < 12; ++i) {
            const double y = lo + (hi - lo) * i / 11.;
            const double x = l.a * y + l.b;
            ys.push_back(y);
            if (x >= 160 && x <= 480) xs.push_back(y);
        }
        if (xs.size() >= 3 && detail::ptp(xs) >= 8) central.push_back(&l);
    }
    std::vector<double> vpx, vpy;
    for (size_t i = 0; i < central.size(); ++i)
        for (size_t j = i + 1; j < central.size(); ++j) {
            const double den = central[i]->a - central[j]->a;
            if (std::abs(den) < .05) continue;
            const double y = (central[j]->b - central[i]->b) / den;
            const double x = central[i]->a * y + central[i]->b;
            if (y > 60 && y < 400 && x > 80 && x < 560) { vpx.push_back(x); vpy.push_back(y); }
        }
    std::vector<const Line*> sorted;
    for (const auto& l : lines) sorted.push_back(&l);
    std::stable_sort(sorted.begin(), sorted.end(), [](const Line* a, const Line* b) {
        return a->a * 380 + a->b < b->a * 380 + b->b;
    });
    std::vector<double> wy, sl;
    for (size_t i = 0; i + 1 < sorted.size(); ++i) {
        const auto* l = sorted[i];
        const auto* r = sorted[i + 1];
        const double lo = std::max({l->y0, r->y0, 210.}), hi = std::min({l->y1, r->y1, 416.});
        const double slope = r->a - l->a, inter = r->b - l->b;
        if (hi - lo >= 10 && slope > .08 && 15 < slope * (hi + lo) / 2 + inter && slope * (hi + lo) / 2 + inter < 450) {
            const double y = -inter / slope;
            if (y > 60 && y < 400) { wy.push_back(y); sl.push_back(slope); }
        }
    }
    h.vpX = detail::median(vpx);
    h.vpY = detail::median(vpy);
    h.widthY = detail::median(wy);
    h.slope = detail::median(sl);
    return h;
}

class Estimator {
public:
    // 框滤波后的目标轨迹快照（随 Frame 一起进快照；annotate 线程只读，不做状态写）。
    //   x/y/w/h 是最近 trackMedian 帧的中位，foot = y + h 也是中位——
    //   脚点是距离公式的唯一几何输入，平滑它就是平滑距离。
    struct Track {
        double x = 0, y = 0, w = 0, h = 0;
        double foot = NAN;
        double rawFoot = NAN;  // 本帧被关联的那个原始框的脚点（用于和 evaluate 的框一一对应）
        int hits = 0;
    };

    struct Frame {
        bool hasVh = false;
        double vh = NAN, hc = NAN, A = NAN, f = NAN, aAge = NAN, fAge = NAN, dispersion = NAN;
        int hcSource = 0;  // 0 none,1 lane,2 paint,3 vehicle
        int hcAggregateSourceMask = 0; // finite window candidates: lane=1, paint=2, vehicle=4
        int hcAggregateSupport = 0;
        double hcNewestAge = NAN, hcOldestAge = NAN;
        int vhSourceMask = 0;
        const char* vhGate = "none";
        Mode mode = ModeDefault24;
        Tier tier = TierWhite24;
        double posterior[4] = {0, 0, 0, 0};
        double p = 0;
        Grade grade = GradeNone;
        bool fresh = false, holding = false;
        int kBuckets = 0;
        int e1Hits = 0;  // 本帧参与 e1 的 pair 数（用于上板判断 e1 能否触发）
        // E1/E2 诊断（关闭开关时恒为 0）：桥接合并的段数 / 三端点 pair 里"远段远端被截断"的比例
        int bridgedSegs = 0, halfPairs = 0, pairsTotal = 0;
        int farRejected = 0;   // P0：本帧被长度可信性检查拒掉的 pair 数
        // C3 诊断：三个白色候选档位的类间离散度 D(k)（σ 单位，未开启时全为 inf）与本帧是否被拒
        double consistD[3] = {1e9, 1e9, 1e9};
        double consistA[3] = {NAN, NAN, NAN};        // dash / gap / period 三类 A 的加权均值
        double consistSig[3] = {NAN, NAN, NAN};      // 各自的标准误（误差模型给出）
        int consistRejected = 0;
        // P1 诊断：本帧似然实际使用的 log(ratio) 标准差
        double ratioSigmaUsed = NAN;
        // 长窗口稳健尺度（本任务）：A 与 A_main 同值；A_challenge 是挑战集中位；
        // aStable=false 表示正处于挑战期或首次估计后不足 W_A/2（此时一律带"?"）。
        double A_main = NAN, A_challenge = NAN, challenge_age = NAN;
        bool aStable = false, vhStable = false;
        std::vector<Line> lines;  // 本帧线几何（自持有，annotate 跨线程用不能留悬空指针）
        std::vector<Track> tracks;  // 本帧目标的平滑框（同上，annotate 只读）
    };

    explicit Estimator(Config cfg = {}) : cfg_(cfg) {}

    const Config& config() const { return cfg_; }
    void reset() { *this = Estimator(cfg_); }

    // 对拍/诊断：长窗口的原始观测流（按发生顺序）。
    //   kind=0：v_h 候选（value=候选像素，weight=1）
    //   kind=1：A 的**原始观测**（P3'' 之后不再存 A）：
    //           value = Δq，weight = 权重，aux = 观测类型（0 dash / 1 gap / 2 period），
    //           yellow = 该桶的颜色（0 白 / 1 黄），idx = 时间桶号，bid = 桶实例序号。
    //           换算成 A 由消费端用"当时档位"的规格完成：A = specOf(aux, tier) / value。
    struct Observation {
        double seq = 0, t = 0, value = 0, weight = 0;
        int kind = 0, idx = -1;   // idx = 时间桶号
        int bid = -1;             // bid = 桶实例序号（同一 idx 上每条线各一个桶）
        int aux = 0;              // kind==1 时：0 dash / 1 gap / 2 period
        int yellow = 0;           // kind==1 时：桶颜色
    };
    const std::vector<Observation>& observations() const { return obs_; }
    void clearObservations() { obs_.clear(); }

    // t：秒（可以用 capturedMs/1000 的差值口径，只要单调）；source：切源标识。
    Frame step(double t, const Measurement& m, const std::vector<Box>& boxes) {
        Frame out;
        out.lines = m.lines;
        const Horizon hz = computeHorizon(m.lines);
        // v3 双地平线兜底：2s 窗内 vp 与车道宽截距的中位，二者相差 ≤12px 才采用。
        const double fallback = doubleHorizon(t, hz);
        // ---- P1 三来源 -> v_h 的“长窗口中位 + 挑战集” ----
        // 旧实现是「12px 时间闸 + 2s 中位」：一帧坏证据就能把 vh 拉走 12px，
        // 再靠 2s 的宽限把它洗掉；一旦坏证据连续出现就会被接受，并被
        // policy() 的 anchor 漂移判定清掉整个尺度。现在改成：
        //   主值 = 最近 vhWindow 秒内所有候选的中位；偏离 vhDeviate 的候选进挑战集，
        //   同方向持续 vhChallengeSeconds 且数量够才替换主值（俯仰允许慢变，不允许跳变）。
        double src[SrcCount] = {NAN, NAN, NAN};
        if (cfg_.useVp) src[SrcVp] = hz.vpY;
        if (cfg_.useWidthY) src[SrcLaneWidth] = hz.widthY;
        const auto paintFits = paintFitsOf(m.rows);
        if (cfg_.usePaintVh) src[SrcPaintWidth] = paintVhOf(paintFits);
        for (int i = 0; i < SrcCount; ++i)
            if (std::isfinite(src[i])) out.vhSourceMask |= (1 << i);
        double candidate = fusedVh(src);
        if (!std::isfinite(candidate)) {
            // 三来源全缺：退回 v3 双地平线（2s 中位），作为普通候选参与同一套裁决。
            candidate = fallback;
            out.vhGate = "fallback";
        }
        if (std::isfinite(candidate)) {
            if (cfg_.recordObservations) obs_.push_back({++seq_, t, candidate, 1., 0, -1, -1});
            vhMainSel_.emplace_back(t, candidate);
            while (!vhMainSel_.empty() && vhMainSel_.front().first < t - cfg_.vhWindow)
                vhMainSel_.pop_front();
            if (!std::isfinite(vhMain_)) {
                vhMain_ = candidate;          // 首帧直接采纳，保证尽快出数
                out.vhGate = "bootstrap";
                vhChal_.clear();
                vhChalSign_ = 0;
            } else {
                const double dev = candidate - vhMain_;
                if (std::abs(dev) <= cfg_.vhDeviate) {
                    vhChal_.clear();
                    vhChalSign_ = 0;
                    if (std::string(out.vhGate) != "fallback") out.vhGate = "ok";
                } else {
                    const double sign = dev > 0 ? 1. : -1.;
                    if (sign != vhChalSign_) { vhChal_.clear(); vhChalSign_ = sign; }
                    vhChal_.emplace_back(t, candidate);
                    const double age = t - vhChal_.front().first;
                    if (age >= cfg_.vhChallengeSeconds && int(vhChal_.size()) >= cfg_.vhChallengeMin) {
                        // 挑战成功：连续同方向的新值取代主值，主窗口从挑战集重开。
                        std::vector<double> v;
                        for (const auto& e : vhChal_) v.push_back(e.second);
                        vhMain_ = detail::median(v);
                        vhMainSel_ = vhChal_;
                        vhChal_.clear();
                        vhChalSign_ = 0;
                        out.vhGate = "challenge_accepted";
                    } else {
                        out.vhGate = "challenge";
                    }
                }
                // 主窗口按时间裁剪后重新取中位
                while (!vhMainSel_.empty() && vhMainSel_.front().first < t - cfg_.vhWindow)
                    vhMainSel_.pop_front();
                if (!vhMainSel_.empty()) {
                    std::vector<double> v;
                    for (const auto& e : vhMainSel_) v.push_back(e.second);
                    vhMain_ = detail::median(v);
                }
            }
        }
        out.vhStable = vhChal_.empty() && std::isfinite(vhMain_);
        const double vh = vhMain_;
        out.hasVh = std::isfinite(vh);
        out.vh = vh;
        // ---- P2 h_c：车道宽斜率 → 标线宽斜率 → 车宽，2s 中位 ----
        double raw = NAN;
        int hcSource = 0;
        if (cfg_.useLaneH && std::isfinite(hz.slope) && hz.slope > 1e-3) {
            const double v = cfg_.laneWidth / hz.slope;
            if (v >= cfg_.hcMin && v <= cfg_.hcMax) { raw = v; hcSource = 1; }
        }
        if (!std::isfinite(raw) && cfg_.usePaintH) {
            const double v = paintHcOf(paintFits);
            if (std::isfinite(v)) { raw = v; hcSource = 2; }
        }
        if (!std::isfinite(raw) && cfg_.useVehicleH) {
            const double v = vehicleHcOf(boxes, vh);
            if (std::isfinite(v)) { raw = v; hcSource = 3; }
        }
        hcHistory_.push_back({t, raw, hcSource});
        while (!hcHistory_.empty() && hcHistory_.front().first < t - cfg_.hcWindow) hcHistory_.pop_front();
        std::vector<double> hcValues;
        for (const auto& e : hcHistory_) {
            if (!std::isfinite(e.second)) continue;
            hcValues.push_back(e.second);
            out.hcAggregateSourceMask |= e.source > 0 ? 1 << (e.source - 1) : 0;
            const double age = t - e.first;
            if (!out.hcAggregateSupport) out.hcNewestAge = out.hcOldestAge = age;
            out.hcNewestAge = std::min(out.hcNewestAge, age);
            out.hcOldestAge = std::max(out.hcOldestAge, age);
            ++out.hcAggregateSupport;
        }
        const double hc = detail::median(hcValues);
        out.hc = hc;
        out.hcSource = hcSource;
        // ---- 0.5s 时间桶结算 ----
        const int idx = int(std::floor((t + 1e-8) / cfg_.bucket));
        std::vector<Bucket> closed;
        if (haveIndex_ && idx != bucketIndex_) {
            for (const auto& key : pendingOrder_) {  // 与 Python dict 的插入顺序一致
                auto it = pending_.find(key);
                if (it != pending_.end()) closed.push_back(medianBucket(it->first, it->second));
            }
            pending_.clear();
            pendingOrder_.clear();
        }
        haveIndex_ = true;
        bucketIndex_ = idx;
#ifdef MONO_PARTIAL_DEBUG
        dbgBeginFrame(m);
#endif
        const auto groups = measureEvent(m, vh);
        // 证据形式诊断：桥接合并段数 / 本帧 pair 总数与其中半完整 pair 数
        out.bridgedSegs = m.bridged;
        for (const auto& g : groups) {
            out.pairsTotal += int(g.pairs.size());
            out.halfPairs += g.halfPairs;
            out.farRejected += g.farRejected;
            PendingKey key{idx, g.name, g.yellow};
            auto found = pending_.find(key);
            if (found == pending_.end()) {
                pendingOrder_.push_back(key);
                pending_[key].push_back(g);
            } else {
                found->second.push_back(g);
            }
        }
        // ---- P5 与状态机 ----
        Frame fin = policy(t, out, closed, boxes);
        // ---- P7 框滤波：更新轨迹，把平滑框挂到快照上 ----
        updateTracks(t, boxes, fin);
        last_ = fin;  // policy 里已赋过一次；这里覆盖，保证 tracks 也进 state()
        return fin;
    }

    Frame state() const { return last_; }

#ifdef MONO_PARTIAL_DEBUG
    // 调试用：导出窗口内的桶摘要（idx/线名/段数/间隔数）与每段端点。
    void debugBuckets() const {
        for (const auto& b : window_) {
            std::fprintf(stderr, "BKT %d %s yellow=%d frames=%d nd=%zu np=%zu\n", b.idx, b.line.c_str(),
                         int(b.yellow), b.frames, b.dashes.size(), b.pairs.size());
            for (const auto& d : b.dashes)
                std::fprintf(stderr, "  D %.17g %.17g %.17g\n", d.top, d.bottom, d.span);
            for (const auto& p : b.pairs)
                std::fprintf(stderr, "  P %.17g %.17g %.17g %.17g\n", p.top, p.bottom, p.nexttop, p.gapspan);
        }
    }
    // 调试用：导出当前档位下的尺度观测 (A 值, 权重)，用于与 Python 逐项对齐。
    std::vector<std::pair<double, double>> debugScale(double vh, Tier tier) const {
        std::vector<std::pair<double, double>> out;
        const double L = specL(tier), G = specG(tier);
        const bool wantYellow = tier == TierYellow46;
        for (const auto& b : window_) {
            if (b.yellow != wantYellow) continue;
            std::vector<std::pair<double, double>> obs;
            for (const auto& d : b.dashes) {
                const double dq = std::abs(1. / (d.top - vh) - 1. / (d.bottom - vh));
                if (dq > 1e-9) obs.push_back({L / dq, std::min(d.span, 80.)});
            }
            for (const auto& p : b.pairs) {
                const double dl = std::abs(1. / (p.top - vh) - 1. / (p.bottom - vh));
                const double dg = std::abs(1. / (p.bottom - vh) - 1. / (p.nexttop - vh));
                if (dg > 1e-9) {
                    obs.push_back({G / dg, std::min(p.gapspan, 80.)});
                    obs.push_back({(L + G) / (dl + dg), .5 * std::min(p.span + p.gapspan, 80.)});
                }
            }
            double norm = 0;
            for (const auto& o : obs) norm += o.second;
            for (const auto& o : obs) out.push_back({o.first, o.second / std::max(norm, 1.)});
        }
        return out;
    }

    // ---- 上板采集用的调试输出（只在 MONO_PARTIAL_DEBUG 下编译） ----
    // 逐闭合桶一行 + 每秒一行汇总；单行长度与每秒行数都有上限，超出只计数不写。
    // 这里用模板参数接桶类型：Bucket 的定义在本段之后，模板体在调用点实例化才需要完整类型。
    static constexpr int DbgLineMax = 1000;   // 单行字符上限（含 '\0'）
    static constexpr int DbgPerSec = 40;      // 每秒最多几行桶记录（2Hz 桶，余量充足）
    static constexpr int DbgRawSegMax = 6;    // 每行最多列几段"未完整"原始线段
    struct DbgSeg { double top = 0, bottom = 0, span = 0; bool complete = false; const char* reason = "ok"; };
    std::vector<DbgSeg> dbgSeg_;              // 本帧原始线段（含未完整原因）
    std::map<std::string, int> dbgInc_;       // 本桶累计：未完整原因 → 帧数
    int dbgSec_ = -1;                         // 当前统计秒
    int dbgLines_ = 0, dbgTrunc_ = 0;         // 本秒已写行数 / 被截断行数
    int dbgHist_[5] = {0, 0, 0, 0, 0};        // pair 跨度直方图
    int dbgBuckets_ = 0, dbgDashNoPair_ = 0, dbgNoDash_ = 0;

    void dbgBeginFrame(const Measurement& m) {
        dbgSeg_.clear();
        for (const auto& s : m.segments) {
            dbgSeg_.push_back({s.top, s.bottom, s.bottom - s.top, s.complete, s.reason});
            if (!s.complete) ++dbgInc_[std::string(s.reason)];
        }
    }
    // 秒边界：把上一秒的直方图打出来（行数/截断计数一并给出）
    void dbgTick(double t) {
        const int sec = int(std::floor(t));
        if (sec == dbgSec_) return;
        if (dbgSec_ >= 0)
            std::fprintf(stderr,
                         "[cpu-mono-dbg-sum] t=%d buckets=%d hist0_5=%d hist5_10=%d hist10_15=%d "
                         "hist15_20=%d hist20p=%d single_no_pair=%d no_dash=%d lines=%d truncated=%d\n",
                         dbgSec_, dbgBuckets_, dbgHist_[0], dbgHist_[1], dbgHist_[2], dbgHist_[3],
                         dbgHist_[4], dbgDashNoPair_, dbgNoDash_, dbgLines_, dbgTrunc_);
        dbgSec_ = sec;
        dbgLines_ = 0;
        dbgTrunc_ = 0;
        dbgBuckets_ = dbgDashNoPair_ = dbgNoDash_ = 0;
        for (int& v : dbgHist_) v = 0;
    }
    // 逐桶一行：段/间隔的像素跨度、行号、完整性、未完整原因、按当前 A 的距离、是否进 e1
    template <class B>
    void dbgBucket(double t, const B& b, double vh) {
        if (dbgLines_ >= DbgPerSec) { ++dbgTrunc_; return; }
        ++dbgLines_;
        ++dbgBuckets_;
        char buf[DbgLineMax];
        int n = 0;
        auto add = [&](const char* fmt, auto... args) {
            if (n < 0 || n >= DbgLineMax - 1) return;
            const int w = std::snprintf(buf + n, size_t(DbgLineMax - n), fmt, args...);
            if (w > 0) n = std::min(DbgLineMax - 1, n + w);
        };
        const double A = A_;
        add("[cpu-mono-dbg] t=%.2f col=%s grp=%s idx=%d nd=%zu np=%zu A=%.1f",
            t, b.yellow ? "yellow" : "white", b.line.c_str(), b.idx, b.dashes.size(), b.pairs.size(), A);
        // 桶内的完整 dash（这些才会进 A 与 e1）
        for (const auto& d : b.dashes)
            add(" d{span=%.1f row=%.0f..%.0f ok=1}", d.span, d.top, d.bottom);
        // 每对：dash 跨度、gap 跨度、按当前 A 的远近端距离
        for (const auto& p : b.pairs) {
            const int bin = p.span < 5 ? 0 : p.span < 10 ? 1 : p.span < 15 ? 2 : p.span < 20 ? 3 : 4;
            ++dbgHist_[bin];
            if (std::isfinite(A) && std::isfinite(vh) && p.bottom > vh + 2 && p.nexttop > vh + 2)
                add(" p{span=%.1f gap=%.1f Z=%.1f..%.1f}", p.span, p.gapspan, A / (p.bottom - vh),
                    A / (p.nexttop - vh));
            else
                add(" p{span=%.1f gap=%.1f Z=?}", p.span, p.gapspan);
        }
        // 本桶累计的"未完整"原因统计 + 本帧明细（未完整的段不进桶，但正因为它们才没有第二段）
        if (!dbgInc_.empty()) {
            add("%s", " inc");
            for (const auto& kv : dbgInc_) add("{%s=%d}", kv.first.c_str(), kv.second);
        }
        int shown = 0, incNow = 0;
        for (const auto& s : dbgSeg_)
            if (!s.complete) ++incNow;
        for (const auto& s : dbgSeg_) {
            if (s.complete) continue;
            if (shown++ >= DbgRawSegMax) break;
            add(" x{span=%.1f row=%.0f..%.0f why=%s}", s.span, s.top, s.bottom, s.reason);
        }
        if (incNow > DbgRawSegMax) add(" x+%d", incNow - DbgRawSegMax);
        // e1 判定：用与 e1 完全相同的门槛复算一遍，只用于解释
        const char* why = "进e1";
        if (b.yellow) {
            why = "黄色";
        } else if (b.dashes.empty()) {
            why = "无完整段";
            ++dbgNoDash_;
        } else if (b.pairs.empty()) {
            why = "无第二段";
            ++dbgDashNoPair_;
        } else if (!std::isfinite(vh)) {
            why = "无vh";
        } else {
            double best = -1;
            for (const auto& p : b.pairs) best = std::max(best, std::min(p.span, p.gapspan));
            if (best < cfg_.sMin) {
                add(" why=跨度不足(%.1f<%.1f)", best, cfg_.sMin);
                why = nullptr;
            }
        }
        if (why) add(" why=%s", why);
        if (n < DbgLineMax - 1) { buf[n++] = '\n'; buf[n] = '\0'; }
        std::fputs(buf, stderr);
    }
#endif

    // 车道内横向位置：目标所在车道的左右边界，在该行求值。
    // 归一化约定：车道中心 0，左边界 -0.5，右边界 +0.5（左负右正）。
    struct LaneOffset {
        bool known = false;
        double norm = NAN;
        int lane = 0;          // 相对自车道的序号（与 laneOf 同义）
        double widthPx = NAN;
        const char* reason = "no_pair";
    };
    // 逐目标：返回 ground/width 米数与分级（P6 车道归属在这里生效）
    struct Target {
        double ground = NAN, width = NAN, meters = NAN;
        Grade grade = GradeNone;
        Method method = MethodNone;
        int lane = 0;
        bool laneKnown = false;
        // 车道内横向位置（M2）：左右边界在原始脚点行求值，中心=0、左负右正，
        // 归一化到 [-0.5, +0.5]。米制值只用配置里的车道宽假设换算，不是实测。
        double laneOffset = NAN;        // 归一化
        double laneOffsetMeters = NAN;  // 米（= laneOffset * cfg.laneWidth，假设值）
        double laneWidthPx = NAN;       // 该行上两侧边界的像素间距（诊断）
        bool laneOffsetKnown = false;
        bool laneOffsetLocalKnown = false;
        double laneOffsetLocal = NAN;
        double offsetValidationFoot = NAN, offsetValidationGap = NAN;
        double offsetValidationHc = NAN, offsetValidationWidthM = NAN;
        const char* offsetValidation = "no_pair"; // unknown / checked_reject / checked_pass
        const char* laneReason = "no_pair";
    };
    // 逐框换算只依赖“本帧状态 + 配置”，因此做成静态函数：GUI 的 annotate 线程
    // 可以直接拿 Sample 里的 Frame 快照调用，不必把整个估计器搬过去。
    static Target evaluate(const Frame& f, const Box& box, const Config& cfg) {
        Target r;
        // P7 时间滤波：**只**把平滑后的脚点与框高用在测距和闸门上。
        // 车道归属、宽高比、width 接力仍用本帧原始框——改动的行为面最小，
        // 换框不会因为轨迹滞后把数字挪到别的车道而消失。
        const Track* tr = matchTrack(f, box, cfg);
        const double foot = tr ? tr->foot : box.y + box.h;   // 平滑脚点（中位 y+h）
        const double gateH = tr ? tr->h : box.h;             // 平滑框高（中位 h）
        // P7 空间闸门：框太小、或脚点离地平线太近时，脚点 1px 的抖动会被 Z/A 放大成
        // 几十个百分点的误差（实测 60m 处 10.5%/px），出数只会误导。
        // 这里同时挡掉 width 接力，避免"ground 被挡、width 又给出一个数"。
        const bool gateHOk = gateH >= cfg.gateMinH;
        const bool gateGapOk = !f.hasVh || foot - f.vh >= cfg.gateMinGap;
        if (gateHOk && gateGapOk && std::isfinite(f.A) && f.hasVh && foot > f.vh + 2.)
            r.ground = f.A / (foot - f.vh);
        // width 接力不用脚点，所以只受"框太小"这一条约束（脚点闸门对它无意义）。
        const bool rear = gateHOk && (box.cls >= 0 && box.cls <= 2) && box.h > 0 &&
                          box.w / std::max(box.h, 1.) >= .8 && box.w / std::max(box.h, 1.) <= 2.2 &&
                          std::abs(box.x + box.w / 2 - 320) <= 200 && box.x > 1 && box.x + box.w < 639;
        if (std::isfinite(f.f) && rear && box.w > 1.)
            r.width = f.f * (box.cls == 0 ? cfg.vehicleWidth : 2.5) / box.w;
        if (std::isfinite(r.ground)) {
            r.meters = r.ground;
            r.method = MethodGround;
            r.grade = f.grade;
        } else if (std::isfinite(r.width) && std::isfinite(f.f) && cfg.relay) {
            r.meters = r.width;
            r.method = MethodWidth;
            r.grade = GradeUncertain;  // 接力一律带问号
        }
        // P7 统一距离上限：不论 ground 还是 width，超过 gateMaxMeters 一律不出数。
        // （远端 1px 脚点就是几十 %，width 接力在同样尺度的框上更差。）
        if (std::isfinite(r.meters) && r.meters > cfg.gateMaxMeters) {
            r.meters = NAN;
            r.method = MethodNone;
            r.grade = GradeNone;
        }
        if (cfg.laneAssign) {
            r.lane = laneOf(f.lines, box.y + box.h, box.x + box.w / 2, r.laneKnown);
            const LaneOffset lo = laneOffsetOf(f.lines, box.y + box.h, box.x + box.w / 2);
            r.laneOffsetLocalKnown = lo.known;
            r.laneOffsetLocal = lo.norm;
            r.laneWidthPx = lo.widthPx;
            r.laneReason = lo.reason;
            r.offsetValidationFoot = box.y + box.h;
            r.offsetValidationGap = r.offsetValidationFoot - f.vh;
            r.offsetValidationHc = f.hc;
            if (lo.known) {
                // Validate the raw-row pair using the same raw-row denominator.
                // Mixed-source medians have no single lane-width calibration basis.
                if (f.hcAggregateSupport <= 0 || !std::isfinite(f.hc) ||
                    !std::isfinite(f.hcNewestAge) || !std::isfinite(f.hcOldestAge) ||
                    f.hcNewestAge < 0 || f.hcNewestAge > f.hcOldestAge || f.hcOldestAge > cfg.hcWindow) {
                    r.offsetValidation = r.laneReason = "hc_unavailable";
                } else if (f.hcAggregateSourceMask != 1) {
                    r.offsetValidation = r.laneReason = "hc_source_unknown";
                } else if (!f.hasVh || !std::isfinite(r.offsetValidationGap) || r.offsetValidationGap <= 2.) {
                    r.offsetValidation = r.laneReason = "geometry_unknown";
                } else {
                    const double w = lo.widthPx * f.hc / r.offsetValidationGap;
                    r.offsetValidationWidthM = w;
                    r.laneOffsetKnown = std::isfinite(w) && w >= cfg.laneWidth * cfg.laneWidthRatioLo &&
                                        w <= cfg.laneWidth * cfg.laneWidthRatioHi;
                    r.offsetValidation = r.laneOffsetKnown ? "checked_pass" : "checked_reject";
                    if (r.laneOffsetKnown) {
                        r.laneOffset = lo.norm;
                        r.laneOffsetMeters = lo.norm * cfg.laneWidth;
                    } else r.laneReason = "lane_width";
                }
            }
            if (r.laneKnown && std::abs(r.lane) > cfg.laneMaxOffset) {
                r.meters = NAN;
                r.grade = GradeNone;
                r.method = MethodNone;
            }
        }
        return r;
    }
    Target target(const Frame& f, const Box& box) const { return evaluate(f, box, cfg_); }

private:
    // ---- P7 框滤波 ----
    static double iouOf(const Box& a, const Box& b) {
        const double x0 = std::max(a.x, b.x), y0 = std::max(a.y, b.y);
        const double x1 = std::min(a.x + a.w, b.x + b.w), y1 = std::min(a.y + a.h, b.y + b.h);
        const double inter = std::max(0., x1 - x0) * std::max(0., y1 - y0);
        const double uni = a.w * a.h + b.w * b.h - inter;
        return uni > 0 ? inter / uni : 0.;
    }
    // 快照里的轨迹只读；找不到就返回空（退化为本帧原值）。
    // 除了 IoU，还要求"这条轨迹本帧观测到的脚点"和传入框的脚点相差 ≤1px：
    // 相邻目标 IoU 也能过阈值，光看 IoU 会把 A 车的平滑脚点用到 B 车上。
    static const Track* matchTrack(const Frame& f, const Box& box, const Config& cfg) {
        const Track* best = nullptr;
        double bestIou = cfg.trackIou;
        const double foot = box.y + box.h;
        for (const auto& tr : f.tracks) {
            if (std::abs(tr.rawFoot - foot) > 1.) continue;
            Box cand{tr.x, tr.y, tr.w, tr.h, box.cls};
            const double v = iouOf(cand, box);
            if (v >= bestIou) {
                bestIou = v;
                best = &tr;
            }
        }
        return best;
    }
    struct LiveTrack {
        double lastT = 0;
        int hits = 0;
        std::deque<Box> recent;  // 最近几帧的原始框（中位窗口）
    };
    void updateTracks(double t, const std::vector<Box>& boxes, Frame& out) {
        const size_t keep = size_t(std::max(1, cfg_.trackMedian));
        // 全局最优优先的贪心关联：把所有 (轨迹, 框) 候选按 IoU 降序排，逐个认领。
        // 逐轨迹各挑自己最好的框会互相抢（先遍历到的轨迹把好框拿走），
        // 结果轨迹里存着别人的框，脚点平滑就张冠李戴——实测过这一点，
        // 所以这里改成"最好的配对先定"。
        struct Cand {
            double iou;
            size_t tr, bx;
        };
        std::vector<Cand> cands;
        for (size_t i = 0; i < tracks_.size(); ++i) {
            for (size_t j = 0; j < boxes.size(); ++j) {
                const double v = iouOf(tracks_[i].recent.back(), boxes[j]);
                if (v >= cfg_.trackIou) cands.push_back({v, i, j});
            }
        }
        std::sort(cands.begin(), cands.end(), [](const Cand& a, const Cand& b) { return a.iou > b.iou; });
        std::vector<char> usedBox(boxes.size(), 0), usedTr(tracks_.size(), 0);
        for (const auto& c : cands) {
            if (usedTr[c.tr] || usedBox[c.bx]) continue;
            usedTr[c.tr] = usedBox[c.bx] = 1;
            LiveTrack& tr = tracks_[c.tr];
            tr.recent.push_back(boxes[c.bx]);
            while (tr.recent.size() > keep) tr.recent.pop_front();
            ++tr.hits;
            tr.lastT = t;
        }
        for (size_t i = 0; i < boxes.size(); ++i) {
            if (usedBox[i]) continue;
            LiveTrack tr;
            tr.lastT = t;
            tr.hits = 1;
            tr.recent.push_back(boxes[i]);
            tracks_.push_back(std::move(tr));
        }
        // 停更超过 hold 秒的轨迹丢弃（切源时 reset() 会整体清空）
        tracks_.erase(std::remove_if(tracks_.begin(), tracks_.end(),
                                     [&](const LiveTrack& tr) {
                                         return t - tr.lastT > cfg_.trackHoldSeconds;
                                     }),
                      tracks_.end());
        out.tracks.clear();
        out.tracks.reserve(tracks_.size());
        for (const auto& tr : tracks_) {
            Track tk;
            tk.x = medianOf(tr.recent, &Box::x);
            tk.y = medianOf(tr.recent, &Box::y);
            tk.w = medianOf(tr.recent, &Box::w);
            tk.h = medianOf(tr.recent, &Box::h);
            // foot 用中位 (y + h) 而不是中位 y 加中位 h：脚点才是距离公式的输入。
            std::vector<double> feet;
            feet.reserve(tr.recent.size());
            for (const auto& b : tr.recent) feet.push_back(b.y + b.h);
            tk.foot = detail::median(feet);
            tk.rawFoot = tr.recent.back().y + tr.recent.back().h;
            tk.hits = tr.hits;
            out.tracks.push_back(tk);
        }
    }
    static double medianOf(const std::deque<Box>& v, double Box::*member) {
        std::vector<double> a;
        a.reserve(v.size());
        for (const auto& b : v) a.push_back(b.*member);
        return detail::median(a);
    }
    std::deque<LiveTrack> tracks_;

    struct Dash {
        double span = 0, top = 0, bottom = 0;
    };
    struct Pair {
        double span = 0, gapspan = 0, top = 0, bottom = 0, nexttop = 0;
    };
    struct Bucket {
        int idx = 0;
        std::string line;
        bool yellow = false;
        int frames = 0;
        std::vector<Dash> dashes;
        std::vector<Pair> pairs;
    };
    struct PendingKey {
        int idx;
        std::string line;
        bool yellow;
        bool operator<(const PendingKey& o) const {
            if (idx != o.idx) return idx < o.idx;
            if (line != o.line) return line < o.line;
            return yellow < o.yellow;
        }
    };
    // 长窗口尺度上的一个时间桶（P3' / P3''）：
    //   不再存 A，而是存"原始量"——因为 A 依赖档位规格（L、G），档位一换，同一段几何对应的 A
    //   必须整体按新规格重算。存 A 会出现"状态显示 6/9、米数还按 2/4 算"的错误。
    //   dq   = |1/(v1−vh) − 1/(v2−vh)|（与 scaleTier 同口径）
    //   kind = 0 dash（规格 L）/ 1 gap（规格 G）/ 2 period（规格 L+G）
    struct RawObs {
        double dq = NAN;
        int kind = 0;
        double weight = 0;
    };
    struct ABucket {
        int idx = 0;
        double t = NAN;
        bool yellow = false;
        std::vector<RawObs> obs;
    };
    struct Sample {
        std::string name;
        bool yellow = false;
        std::vector<Dash> dashes;
        std::vector<Pair> pairs;
        int halfPairs = 0;   // E2：其中"远段远端被截断"的 pair 数
        int farRejected = 0; // P0：因远段近端长度不可信被拒的 pair 数
    };

    Config cfg_;
    std::deque<std::pair<double, double>> vhHistory_;  // 旧 2s 中位（保留但不再用于闸门）
    std::deque<std::pair<double, Horizon>> doubleHistory_;  // (t, 原始 horizon) 供 v3 兜底
    // v_h 长窗口：主窗口候选 + 挑战集
    std::deque<std::pair<double, double>> vhMainSel_, vhChal_;
    double vhMain_ = NAN, vhChalSign_ = 0;
    // A 长窗口：已接受桶 + 挑战桶
    std::deque<ABucket> aMain_, aChallenge_;
    double aChallengeSign_ = 0, AFirstAt_ = NAN;
    // 对拍/诊断用的观测流（默认不动，空 vector）
    std::vector<Observation> obs_;
    double seq_ = 0;
    int consistRejects_ = 0;   // C3：自洽性把已攒够证据的档位判据拒掉的次数（诊断）
    int bucketSerial_ = 0;
    double vhRejectSince_ = NAN;
    struct HcCandidate { double first, second; int source; }; // timestamp, value, provenance
    std::deque<HcCandidate> hcHistory_;
    bool haveIndex_ = false;
    int bucketIndex_ = 0;
    std::map<PendingKey, std::vector<Sample>> pending_;
    std::vector<PendingKey> pendingOrder_;
    std::deque<Bucket> window_;
    std::set<int> supportWhite_, supportYellow_;
    double logs_[4] = {0, 0, 0, 0};
    Mode mode_ = ModeDefault24;
    Tier tier_ = TierWhite24;
    double A_ = NAN, AAt_ = NAN, anchor_ = NAN, dispersion_ = NAN, f_ = NAN, fAt_ = NAN;
    double contraStart_ = NAN, lastEvidence_ = NAN;
    Frame last_;

    // ---- P1/P2 辅助 ----
    struct PaintFit {
        double slope = 0, inter = 0;
        int n = 0;
    };
    std::vector<PaintFit> paintFitsOf(const std::vector<Row>& rows) const {
        std::map<int, std::vector<std::pair<double, double>>> byLine;
        for (const auto& r : rows)
            if (r.width >= 3.) byLine[r.line].push_back({r.y, r.width});
        std::vector<PaintFit> fits;
        for (auto& entry : byLine) {
            auto& pts = entry.second;
            if (pts.size() < size_t(cfg_.paintMinRows)) continue;
            std::vector<double> ys, ysSel, wsSel;
            for (auto& p : pts) ys.push_back(p.first);
            const double cut = *std::min_element(ys.begin(), ys.end()) + .5 * detail::ptp(ys);
            for (auto& p : pts)
                if (p.first >= cut) { ysSel.push_back(p.first); wsSel.push_back(p.second); }
            if (ysSel.size() < size_t(cfg_.paintMinRows) || detail::ptp(ysSel) < cfg_.paintMinSpan) continue;
            double slope = 0, inter = 0;
            if (!detail::fitLine1(ysSel, wsSel, slope, inter)) continue;
            fits.push_back({slope, inter, int(ysSel.size())});
        }
        return fits;
    }
    static double paintVhOf(const std::vector<PaintFit>& fits) {
        std::vector<double> est;
        for (const auto& f : fits) {
            if (f.slope <= 2e-3) continue;
            const double v = -f.inter / f.slope;
            if (v > 60 && v < 400) est.push_back(v);
        }
        return detail::median(est);
    }
    double paintHcOf(const std::vector<PaintFit>& fits) const {
        std::vector<double> est;
        for (const auto& f : fits) {
            if (f.slope <= 2e-3) continue;
            const double v = cfg_.paintWidth / f.slope;
            if (v >= cfg_.hcMin && v <= cfg_.hcMax) est.push_back(v);
        }
        return detail::median(est);
    }
    double vehicleHcOf(const std::vector<Box>& boxes, double vh) const {
        if (!std::isfinite(vh)) return NAN;
        std::vector<double> est;
        for (const auto& b : boxes) {
            if (b.cls < 0 || b.cls > 2) continue;
            if (b.w <= 1 || !(b.w / std::max(b.h, 1.) >= .8 && b.w / std::max(b.h, 1.) <= 2.2)) continue;
            if (std::abs(b.x + b.w / 2 - 320) > 200 || b.x <= 1 || b.x + b.w >= 639) continue;
            const double foot = b.y + b.h;
            if (foot <= vh + 4) continue;
            const double W = b.cls == 0 ? cfg_.vehicleWidth : 2.5;
            const double v = W * (foot - vh) / b.w;
            if (v >= cfg_.hcMin && v <= cfg_.hcMax) est.push_back(v);
        }
        return detail::median(est);
    }
    // v3 双地平线兜底：2s 窗内 vp 与车道宽截距各自取中位，差 ≤horizonLimit 才采用。
    double doubleHorizon(double t, const Horizon& hz) {
        doubleHistory_.emplace_back(t, hz);
        while (!doubleHistory_.empty() && doubleHistory_.front().first < t - 2.0) doubleHistory_.pop_front();
        std::vector<double> vp, wy;
        for (const auto& e : doubleHistory_) {
            if (std::isfinite(e.second.vpY)) vp.push_back(e.second.vpY);
            if (std::isfinite(e.second.widthY)) wy.push_back(e.second.widthY);
        }
        const double vpm = detail::median(vp), wym = detail::median(wy);
        if (!std::isfinite(vpm) || !std::isfinite(wym) || std::abs(vpm - wym) > cfg_.horizonLimit) return NAN;
        return (vpm + wym) / 2;
    }
    static double fusedVh(const double src[SrcCount]) {
        std::vector<double> v;
        for (int i = 0; i < SrcCount; ++i)
            if (std::isfinite(src[i])) v.push_back(src[i]);
        return detail::median(v);
    }
    // ---- 观测：把线段按“左右+远近名次+颜色”分组，取桶内中位 ----
    std::vector<Sample> measureEvent(const Measurement& m, double vh) const {
        std::vector<Sample> out;
        if (!std::isfinite(vh)) return out;
        std::map<std::pair<std::string, std::string>, std::vector<const Segment*>> groups;
        for (const auto& s : m.segments) {
            const Line* line = nullptr;
            for (const auto& l : m.lines)
                if (l.id == s.line) { line = &l; break; }
            if (!line) continue;
            const double x = line->a * 330 + line->b;
            const bool left = x < 320;
            std::vector<const Line*> same;
            for (const auto& q : m.lines)
                if ((q.a * 330 + q.b < 320) == left) same.push_back(&q);
            std::stable_sort(same.begin(), same.end(), [](const Line* a, const Line* b) {
                return std::abs(a->a * 330 + a->b - 320) < std::abs(b->a * 330 + b->b - 320);
            });
            int rank = 0;
            for (size_t i = 0; i < same.size(); ++i)
                if (same[i] == line) { rank = int(i); break; }
            const std::string name = (left ? "left" : "right") + std::to_string(rank);
            const std::string color = s.cls == 5 ? "yellow" : "white";
            groups[{name, color}].push_back(&s);
        }
        for (auto& entry : groups) {
            auto segs = entry.second;
            std::stable_sort(segs.begin(), segs.end(), [](const Segment* a, const Segment* b) { return a->top < b->top; });
            Sample sample;
            sample.name = entry.first.first;
            sample.yellow = entry.first.second == "yellow";
            for (size_t i = 0; i < segs.size(); ++i) {
                const auto& s = *segs[i];
                if (!s.complete || s.top <= vh + 4) continue;
                const double span = s.bottom - s.top;
                if (span <= 0) continue;
                sample.dashes.push_back({span, s.top, s.bottom});
                if (!cfg_.threeEndpointPair) {
                    // 原口径：本段（较远）完整 dash + 到更近一段的间隔
                    if (i + 1 >= segs.size()) continue;
                    const auto& nxt = *segs[i + 1];
                    if (!nxt.complete || nxt.top - s.bottom < 5) continue;
                    sample.pairs.push_back({span, nxt.top - s.bottom, s.top, s.bottom, nxt.top});
                    continue;
                }
                // E2 口径：本段是“近段”，要求两端完整（上面已判）；下一段更远，
                // 只要求它的近端（bottom，紧邻断口那一端）可信，远端允许被截断。
                // L 取近段长度，G 取近段远端（top）到下一段近端（bottom）的间隔。
                if (i == 0) continue;
                const auto& farSeg = *segs[i - 1];
                if (!farSeg.complete && !farSeg.botOk) continue;
                // P0：远段近端可信性。同车道虚线等长 ⇒ 各段在 A 空间的跨度应当相等。
                // 若远段的 top 本身是真实端点（topOk）却明显短于近段，说明它的 bottom 是
                // 被截断/遮挡"造"出来的假端点，用它量间隔会把 G 系统性放大（合成实测 6px 截断
                // → G +5px、L/G −19%）。这种情况不成 pair；若远段的 top 本就被截断（topOk=false），
                // 段短是正常的，bottom 仍是真实端点 —— 那正是三端点 pair 要用的情形。
                if (cfg_.farLengthZ > 0 && farSeg.complete && farSeg.topOk) {
                    const double dlN = std::abs(1. / (s.top - vh) - 1. / (s.bottom - vh));
                    const double dlF = std::abs(1. / (farSeg.top - vh) - 1. / (farSeg.bottom - vh));
                    if (dlN > 1e-9 && dlF > 1e-9) {
                        const double sN = relSigmaOf(s.top, s.bottom, vh);
                        const double sF = relSigmaOf(farSeg.top, farSeg.bottom, vh);
                        const double z = std::abs(std::log(dlF / dlN)) / std::sqrt(sN * sN + sF * sF);
                        if (z > cfg_.farLengthZ) {
                            ++sample.farRejected;
                            continue;
                        }
                    }
                }
                const double gap = s.top - farSeg.bottom;
                if (gap < 5) continue;
                // 注意字段语义：下游的 dl 用 |1/top - 1/bottom|，dg 用 |1/bottom - 1/nexttop|，
                // 即 "bottom" 必须是**紧邻间隔**的那个端点。近段的近间隔端点是它的 top，
                // 所以这里把 top/bottom 交换写入（span/gapspan 不变）。
                sample.pairs.push_back({span, gap, s.bottom, s.top, farSeg.bottom});
                if (!farSeg.complete) ++sample.halfPairs;
            }
            if (!sample.dashes.empty()) out.push_back(sample);
        }
        return out;
    }
    static Bucket medianBucket(const PendingKey& key, const std::vector<Sample>& samples) {
        Bucket b;
        b.idx = key.idx;
        b.line = key.line;
        b.yellow = key.yellow;
        b.frames = int(samples.size());
        // 逐字段中位（与 Python 的 bucket_median 一致：按 top 排序后同序号聚合）
        {
            std::vector<std::vector<const Dash*>> lists;
            for (const auto& s : samples) {
                std::vector<const Dash*> arr;
                for (const auto& d : s.dashes) arr.push_back(&d);
                std::stable_sort(arr.begin(), arr.end(), [](const Dash* a, const Dash* b) { return a->top < b->top; });
                lists.push_back(arr);
            }
            size_t n = 0;
            {
                std::vector<double> counts;
                for (const auto& l : lists) counts.push_back(double(l.size()));
                n = size_t(detail::median(counts));
            }
            for (size_t i = 0; i < n; ++i) {
                std::vector<double> span, top, bottom;
                for (const auto& l : lists)
                    if (l.size() > i) { span.push_back(l[i]->span); top.push_back(l[i]->top); bottom.push_back(l[i]->bottom); }
                if (double(span.size()) >= std::max(1.0, samples.size() / 2.0))
                    b.dashes.push_back({detail::median(span), detail::median(top), detail::median(bottom)});
            }
        }
        {
            std::vector<std::vector<const Pair*>> lists;
            for (const auto& s : samples) {
                std::vector<const Pair*> arr;
                for (const auto& p : s.pairs) arr.push_back(&p);
                std::stable_sort(arr.begin(), arr.end(), [](const Pair* a, const Pair* b) { return a->top < b->top; });
                lists.push_back(arr);
            }
            size_t n = 0;
            {
                std::vector<double> counts;
                for (const auto& l : lists) counts.push_back(double(l.size()));
                n = size_t(detail::median(counts));
            }
            for (size_t i = 0; i < n; ++i) {
                std::vector<double> span, gap, top, bottom, next;
                for (const auto& l : lists)
                    if (l.size() > i) {
                        span.push_back(l[i]->span);
                        gap.push_back(l[i]->gapspan);
                        top.push_back(l[i]->top);
                        bottom.push_back(l[i]->bottom);
                        next.push_back(l[i]->nexttop);
                    }
                if (double(span.size()) >= std::max(1.0, samples.size() / 2.0))
                    b.pairs.push_back({detail::median(span), detail::median(gap), detail::median(top),
                                       detail::median(bottom), detail::median(next)});
            }
        }
        return b;
    }
    // ---- P3 尺度 ----
    struct ScaleResult {
        double A = NAN, dispersion = NAN;
        int count = 0;
    };
    ScaleResult scaleTier(const std::deque<Bucket>& buckets, Tier tier, double vh) const {
        ScaleResult r;
        if (!std::isfinite(vh)) return r;
        const double L = specL(tier), G = specG(tier);
        const bool wantYellow = tier == TierYellow46;
        std::vector<double> values, weights;
        for (const auto& b : buckets) {
            if (b.yellow != wantYellow) continue;
            std::vector<std::pair<double, double>> obs;  // (A, weight)
            if (cfg_.singleSegment) {
                for (const auto& d : b.dashes) {
                    const double dq = std::abs(1. / (d.top - vh) - 1. / (d.bottom - vh));
                    if (dq > 1e-9) obs.push_back({L / dq, std::min(d.span, 80.)});
                }
                for (const auto& p : b.pairs) {
                    const double dl = std::abs(1. / (p.top - vh) - 1. / (p.bottom - vh));
                    const double dg = std::abs(1. / (p.bottom - vh) - 1. / (p.nexttop - vh));
                    if (dg > 1e-9) {
                        obs.push_back({G / dg, std::min(p.gapspan, 80.)});
                        obs.push_back({(L + G) / (dl + dg), .5 * std::min(p.span + p.gapspan, 80.)});
                    }
                }
            } else {
                for (const auto& p : b.pairs) {
                    if (std::min(p.span, p.gapspan) < cfg_.sMin) continue;
                    const double dl = std::abs(1. / (p.top - vh) - 1. / (p.bottom - vh));
                    const double dg = std::abs(1. / (p.bottom - vh) - 1. / (p.nexttop - vh));
                    if (dl > 1e-9 && dg > 1e-9) {
                        obs.push_back({L / dl, std::min(p.span, 80.)});
                        obs.push_back({G / dg, std::min(p.gapspan, 80.)});
                        obs.push_back({(L + G) / (dl + dg), .5 * std::min(p.span + p.gapspan, 80.)});
                    }
                }
            }
            double norm = 0;
            for (const auto& o : obs) norm += o.second;
            for (const auto& o : obs) {
                if (o.first > 0 && std::isfinite(o.first)) {
                    values.push_back(o.first);
                    weights.push_back(o.second / std::max(norm, 1.));
                }
            }
        }
        if (values.empty()) return r;
        std::vector<size_t> order(values.size());
        for (size_t i = 0; i < order.size(); ++i) order[i] = i;
        std::sort(order.begin(), order.end(), [&](size_t a, size_t b) { return values[a] < values[b]; });
        std::vector<double> vs, ws;
        for (size_t i : order) { vs.push_back(values[i]); ws.push_back(weights[i]); }
        double total = detail::numpySum(ws);
        double acc = 0;
        size_t pick = vs.size() - 1;
        for (size_t i = 0; i < vs.size(); ++i) {
            acc += ws[i];
            if (acc >= total / 2) { pick = i; break; }
        }
        r.A = vs[pick];
        r.count = int(vs.size());
        if (r.count > 1) {  // 单样本不报离散度
            std::vector<size_t> dev(vs.size());
            for (size_t i = 0; i < dev.size(); ++i) dev[i] = i;
            std::vector<double> absDev(vs.size());
            for (size_t i = 0; i < vs.size(); ++i) absDev[i] = std::abs(vs[i] - r.A);
            std::sort(dev.begin(), dev.end(), [&](size_t a, size_t b) { return absDev[a] < absDev[b]; });
            const double half = detail::numpySum(weights) / 2;  // Python 用原始顺序的 w.sum()
            double sum = 0, mad = 0;
            for (size_t i : dev) {
                sum += ws[i];
                mad = absDev[i];
                if (sum >= half) break;
            }
            r.dispersion = mad / r.A;
        }
        return r;
    }
    // ---- P3' 长窗口：单桶 A、桶集合的加权中位 ----
    struct BucketStat {
        double A = NAN, dispersion = NAN;
    };
    // 档位规格：dash→L、gap→G、period→L+G（P3''）
    static double specOf(int kind, Tier t) {
        const double L = specL(t), G = specG(t);
        return kind == 0 ? L : (kind == 1 ? G : L + G);
    }
    // 单个时间桶的原始观测（与档位无关）：观测口径与 scaleTier 完全一致
    // （单段：dash + gap + period；成对：只取合格 pair 的三种观测）。
    void bucketObs(const Bucket& b, double vh, std::vector<RawObs>& out) const {
        out.clear();
        if (!std::isfinite(vh)) return;
        auto push = [&](double dq, int kind, double w) {
            if (dq > 1e-9 && std::isfinite(dq) && w > 0) out.push_back({dq, kind, w});
        };
        if (cfg_.singleSegment) {
            for (const auto& d : b.dashes) {
                const double dq = std::abs(1. / (d.top - vh) - 1. / (d.bottom - vh));
                push(dq, 0, std::min(d.span, 80.));
            }
            for (const auto& p : b.pairs) {
                const double dl = std::abs(1. / (p.top - vh) - 1. / (p.bottom - vh));
                const double dg = std::abs(1. / (p.bottom - vh) - 1. / (p.nexttop - vh));
                push(dg, 1, std::min(p.gapspan, 80.));
                push(dl + dg, 2, .5 * std::min(p.span + p.gapspan, 80.));
            }
        } else {
            for (const auto& p : b.pairs) {
                if (std::min(p.span, p.gapspan) < cfg_.sMin) continue;
                const double dl = std::abs(1. / (p.top - vh) - 1. / (p.bottom - vh));
                const double dg = std::abs(1. / (p.bottom - vh) - 1. / (p.nexttop - vh));
                if (dl > 1e-9 && dg > 1e-9) {
                    push(dl, 0, std::min(p.span, 80.));
                    push(dg, 1, std::min(p.gapspan, 80.));
                    push(dl + dg, 2, .5 * std::min(p.span + p.gapspan, 80.));
                }
            }
        }
    }
    // 桶内按"当前档位"换算后取加权中位（等价于旧 bucketScaleA 在同一档位下的结果）
    static double Aof(const ABucket& b, Tier tier) {
        std::vector<std::pair<double, double>> v;  // (A, weight)
        v.reserve(b.obs.size());
        for (const auto& o : b.obs) {
            const double a = specOf(o.kind, tier) / o.dq;
            if (std::isfinite(a) && a > 0 && o.weight > 0) v.push_back({a, o.weight});
        }
        if (v.empty()) return NAN;
        std::sort(v.begin(), v.end(), [](const auto& x, const auto& y) { return x.first < y.first; });
        double total = 0;
        for (const auto& o : v) total += o.second;
        double acc = 0;
        for (const auto& o : v) {
            acc += o.second;
            if (acc >= total / 2) return o.first;
        }
        return v.back().first;
    }
    static double weightOf(const ABucket& b) {
        double w = 0;
        for (const auto& o : b.obs) w += std::max(o.weight, 0.);
        return w;
    }
    // 桶集合的加权中位 + 相对 MAD（按当前档位换算；只用当前颜色的桶）
    static BucketStat medianOfBuckets(const std::deque<ABucket>& in, Tier tier, bool wantYellow) {
        BucketStat r;
        std::vector<std::pair<double, double>> v;  // (A, weight)
        for (const auto& b : in) {
            if (b.yellow != wantYellow) continue;
            const double a = Aof(b, tier);
            if (std::isfinite(a) && a > 0) v.push_back({a, std::max(weightOf(b), 1e-9)});
        }
        if (v.empty()) return r;
        std::stable_sort(v.begin(), v.end(), [](const auto& x, const auto& y) { return x.first < y.first; });
        double total = 0;
        for (const auto& x : v) total += x.second;
        double acc = 0;
        for (const auto& x : v) {
            acc += x.second;
            if (acc >= total / 2) { r.A = x.first; break; }
        }
        if (!std::isfinite(r.A)) r.A = v.back().first;
        if (v.size() > 1) {
            std::vector<std::pair<double, double>> dev;  // (|A-A_med|, weight)
            for (const auto& x : v) dev.push_back({std::abs(x.first - r.A), x.second});
            std::stable_sort(dev.begin(), dev.end(),
                             [](const auto& x, const auto& y) { return x.first < y.first; });
            double sum = 0, mad = 0;
            for (const auto& d : dev) {
                sum += d.second;
                mad = d.first;
                if (sum >= total / 2) break;
            }
            r.dispersion = mad / r.A;
        }
        return r;
    }
    // 车道内横向位置：目标所在车道的左右边界在该行的位置。
    //   * 边界集合与 laneOf 完全同源（同一 ±15px 端点松弛、同一 x 范围），保证"车道序号"
    //     使用相同的边界支持范围；局部偏移不要求知道自车道编号。
    //     车道编号仍由 laneOf 独立确定，不能由偏移有效推断 laneKnown。
    //   * 左右顺序由排序保证；线对窄于该行所有相邻间距中位的 0.5 倍时判为不可用——
    //     双线/毛刺会造出窄缝，这种判据不依赖任何绝对像素常数。
    //   * 缺边、目标不在任何相邻边界之间、窄缝：一律 known=false 并给出原因，不外推。
    static LaneOffset laneOffsetOf(const std::vector<Line>& lines, double y, double x) {
        LaneOffset r;
        std::vector<double> raw;
        for (const auto& l : lines) {
            if (l.y0 - 15 <= y && y <= l.y1 + 15) {
                const double xv = l.a * y + l.b;
                if (xv > -200 && xv < 840) raw.push_back(xv);
            }
        }
        if (raw.size() < 2) { r.reason = "no_boundaries"; return r; }
        std::sort(raw.begin(), raw.end());
        int ego = -1;
        for (size_t i = 0; i + 1 < raw.size(); ++i)
            if (raw[i] <= 320 && 320 <= raw[i + 1]) { ego = int(i); break; }
        int k = -1;
        for (size_t i = 0; i + 1 < raw.size(); ++i)
            if (raw[i] <= x && x <= raw[i + 1]) { k = int(i); break; }
        if (k < 0) { r.reason = "out_of_pair"; return r; }
        std::vector<double> gaps;
        gaps.reserve(raw.size() - 1);
        for (size_t i = 0; i + 1 < raw.size(); ++i) gaps.push_back(raw[i + 1] - raw[i]);
        std::sort(gaps.begin(), gaps.end());
        const double typical = gaps[gaps.size() / 2];
        const double left = raw[size_t(k)], right = raw[size_t(k) + 1];
        const double width = right - left;
        if (!(width > 0) || !(typical > 0) || width < 0.5 * typical) {
            r.reason = "narrow_pair";
            return r;
        }
        r.known = true;
        r.lane = ego >= 0 ? k - ego : 0;  // 无自车道时仅局部偏移有效；evaluate 不消费此编号
        r.widthPx = width;
        r.norm = (x - 0.5 * (left + right)) / width;
        r.reason = "ok";
        return r;
    }
    // ---- P6 车道归属（既有语义：自车道 = 相机轴所在的那一对边界）----
    static int laneOf(const std::vector<Line>& lines, double y, double x, bool& known) {
        known = false;
        std::vector<double> bs;
        for (const auto& l : lines) {
            if (l.y0 - 15 <= y && y <= l.y1 + 15) {
                const double xv = l.a * y + l.b;
                if (xv > -200 && xv < 840) bs.push_back(xv);
            }
        }
        if (bs.size() < 2) return 0;
        std::sort(bs.begin(), bs.end());
        int ego = -1;
        for (size_t i = 0; i + 1 < bs.size(); ++i)
            if (bs[i] <= 320 && 320 <= bs[i + 1]) { ego = int(i); break; }
        if (ego < 0) return 0;
        known = true;
        for (size_t i = 0; i + 1 < bs.size(); ++i)
            if (bs[i] <= x && x <= bs[i + 1]) return int(i) - ego;
        if (x < bs.front()) {
            const double w = bs[1] - bs[0];
            return x >= bs[0] - w ? -1 : -2;
        }
        if (x > bs.back()) {
            const double w = bs[bs.size() - 1] - bs[bs.size() - 2];
            return x <= bs.back() + w ? int(bs.size()) - 1 - ego : 2;
        }
        return 2;
    }
    // ---- 状态机 ----
    void clearScale() {
        A_ = NAN;
        AAt_ = NAN;
        f_ = NAN;
        fAt_ = NAN;
        anchor_ = NAN;
        dispersion_ = NAN;
        window_.clear();
        aMain_.clear();
        aChallenge_.clear();
        aChallengeSign_ = 0;
        AFirstAt_ = NAN;
    }
    void returnDefault() {
        mode_ = ModeDefault24;
        tier_ = TierWhite24;
        for (double& v : logs_) v = 0;
        supportWhite_.clear();
        supportYellow_.clear();
        contraStart_ = NAN;
        lastEvidence_ = NAN;
        clearScale();
    }
    // ---- C3 档位自洽性 ----
    // 一个"区间 → A"观测的相对标准差（与 A 无关，只用 vh 与两个端点行）：
    //   σ_Δ = b*sqrt((y_f-vh)^-4 + (y_n-vh)^-4)，σ_A/A = σ_Δ/Δ
    double relSigmaOf(double yFar, double yNear, double vh) const {
        const double uf = 1. / (yFar - vh), un = 1. / (yNear - vh);
        const double d = std::abs(un - uf);
        if (!(d > 1e-12)) return 1e9;
        return cfg_.endpointSigma * std::sqrt(std::pow(uf, 4) + std::pow(un, 4)) / d;
    }
    struct ConsistStat {
        double D = 1e9;
        double d[3] = {1e9, 1e9, 1e9};
        double a[3] = {NAN, NAN, NAN};   // 三类 A 的加权均值（诊断）
        double s[3] = {NAN, NAN, NAN};   // 对应标准误
    };
    // dash / gap / period 三类 A 的类间离散度（σ 单位）。任何一类没有观测则不可判定（D=inf）。
    ConsistStat tierConsistency(double vh, Tier tier) const {
        ConsistStat r;
        if (!std::isfinite(vh)) return r;
        const double L = specL(tier), G = specG(tier);
        double sw[3] = {0, 0, 0}, swx[3] = {0, 0, 0}, sw2[3] = {0, 0, 0}, swi[3] = {0, 0, 0};
        int n[3] = {0, 0, 0};
        auto add = [&](int c, double A, double rel, double w, double spanPx) {
            if (!(A > 0) || !std::isfinite(A) || !(rel < 1e8) || !(w > 0) || !(spanPx > 1.)) return;
            // 统计误差（会随样本数收缩）
            const double s = A * rel;
            sw[c] += w;
            swx[c] += w * A;
            sw2[c] += w * w * s * s;
            swi[c] += w / spanPx;      // 用于聚合"相对系统偏差 ~ 1/span"
            ++n[c];
        };
        for (const auto& b : window_) {
            if (b.yellow) continue;
            // 端点系统偏差（合成真值实测：每端向外 +0.5px）在证据层先扣掉：
            // dash 缩短 b、gap 加长 b、period 宽度不变（两端同向平移）。
            const double h = .5 * cfg_.endpointBias;
            for (const auto& d : b.dashes) {
                const double t = d.top + h, bt = d.bottom - h;
                if (bt - t < 2) continue;
                const double dq = std::abs(1. / (t - vh) - 1. / (bt - vh));
                if (dq > 1e-9) add(0, L / dq, relSigmaOf(t, bt, vh), std::min(bt - t, 80.), bt - t);
            }
            for (const auto& p : b.pairs) {
                const double gFar = p.nexttop - h, gNear = p.bottom + h;   // gap：加长 b
                const double dg = std::abs(1. / (gNear - vh) - 1. / (gFar - vh));
                if (dg > 1e-9)
                    add(1, G / dg, relSigmaOf(gFar, gNear, vh), std::min(gNear - gFar, 80.), gNear - gFar);
                const double pFar = p.nexttop - h, pNear = p.top - h;      // period：宽度不变
                const double dp = std::abs(1. / (pNear - vh) - 1. / (pFar - vh));
                if (dp > 1e-9)
                    add(2, (L + G) / dp, relSigmaOf(pFar, pNear, vh), .5 * std::min(pNear - pFar, 80.),
                        pNear - pFar);
            }
        }
        for (int c = 0; c < 3; ++c)
            if (n[c] < 1) return r;
        double mean[3], sig[3], spanMean[3] = {0, 0, 0};
        for (int c = 0; c < 3; ++c) {
            mean[c] = swx[c] / sw[c];
            sig[c] = std::sqrt(sw2[c]) / sw[c];
            spanMean[c] = sw[c] / std::max(1e-9, swi[c]);   // 调和式平均跨度：聚合 1/span 型相对偏差
            if (!(sig[c] > 0)) return r;
            // 系统偏差的不确定性不随样本数收缩 → 给类标准误一个地板（块内即上式的 1/√n 不再起作用）
            const double sys = spanMean[c] > 1. ? mean[c] * cfg_.endpointBiasSigma / spanMean[c] : 0.;
            sig[c] = std::sqrt(sig[c] * sig[c] + sys * sys);
        }
        for (int c = 0; c < 3; ++c) {
            r.a[c] = mean[c];
            r.s[c] = sig[c];
        }
        // 系统偏差已在观测层扣除，这里只用统计误差 + 偏差修正的残余不确定性
        const int pr[3][2] = {{0, 1}, {0, 2}, {1, 2}};
        for (int k = 0; k < 3; ++k) {
            const int i = pr[k][0], j = pr[k][1];
            r.d[k] = std::abs(mean[i] - mean[j]) / std::sqrt(sig[i] * sig[i] + sig[j] * sig[j]);
        }
        r.D = std::max({r.d[0], r.d[1], r.d[2]});
        return r;
    }

    Frame policy(double t, Frame& out, const std::vector<Bucket>& closed, const std::vector<Box>&) {        const double dt = std::isfinite(lastTime_) ? std::max(0., t - lastTime_) : 0.;
        lastTime_ = t;
        const double decay = std::exp(-dt / cfg_.tau);
        for (double& v : logs_) v *= decay;
        if (std::isfinite(A_) && std::isfinite(AAt_) && t - AAt_ > cfg_.holdLimit) returnDefault();
        // 旧的 anchor 漂移判定已删除：v_h 现在由“长窗口中位 + 挑战集”自己收敛，
        // 不再因为 vh 偏离锚点就清空 A（那正是新素材上 A 反复重置的原因）。
        while (!window_.empty() && window_.front().idx * cfg_.bucket < t - cfg_.window) window_.pop_front();
        for (const auto& b : closed) window_.push_back(b);

        bool yellowSeen = false, evidence = false;
        int e1Hits = 0;
#ifdef MONO_PARTIAL_DEBUG
        dbgTick(t);
#endif
        for (const auto& b : closed) {
#ifdef MONO_PARTIAL_DEBUG
            dbgBucket(t, b, out.vh);
#endif
            if (b.yellow && !b.dashes.empty()) {
                yellowSeen = true;
                supportYellow_.insert(b.idx);
                continue;
            }
            if (b.yellow) continue;
            struct NearObs {
                double ratio, duty, sigma;
            };
            std::vector<NearObs> near;
            for (const auto& p : b.pairs) {
                if (!std::isfinite(out.vh)) break;
                const double dl = std::abs(1. / (p.top - out.vh) - 1. / (p.bottom - out.vh));
                const double dg = std::abs(1. / (p.bottom - out.vh) - 1. / (p.nexttop - out.vh));
                if (!(dg > 1e-9) || std::min(p.span, p.gapspan) < cfg_.sMin) continue;
                // P1：该观测 log(ratio) 的标准差由误差模型给出（端点误差 b 传到两条区间再合成）
                const double sL = relSigmaOf(p.top, p.bottom, out.vh);
                const double sG = relSigmaOf(p.nexttop, p.bottom, out.vh);
                near.push_back({dl / dg, dl / (dl + dg), std::sqrt(sL * sL + sG * sG)});
            }
            e1Hits += int(near.size());
            if (!near.empty()) { supportWhite_.insert(b.idx); evidence = true; }
            if (cfg_.e1 && !near.empty()) {
                std::vector<double> ratios, duties, sigmas;
                for (auto& n : near) {
                    ratios.push_back(n.ratio);
                    duties.push_back(n.duty);
                    sigmas.push_back(n.sigma);
                }
                const double ratio = detail::median(ratios), duty = detail::median(duties);
                // P1：σ 取"误差模型给出的逐帧典型值"，并用 floor 兜底（floor 代表无法建模的
                // 系统性截断偏置；0 = 完全由误差模型决定）。
                double sigmaUsed = cfg_.ratioSigma;
                double dutySigma = .05;
                if (cfg_.ratioSigmaMode == 1) {
                    sigmaUsed = std::max(detail::median(sigmas), cfg_.ratioSigmaFloor);
                    dutySigma = std::max(.01, duty * (1. - duty) * sigmaUsed);
                }
                out.ratioSigmaUsed = sigmaUsed;
                double loss[3] = {0, 0, 0};
                for (int k = 0; k < 3; ++k) {
                    const double rr = specL(Tier(k)) / specG(Tier(k));
                    loss[k] = .5 * (std::pow(std::log(ratio / rr) / sigmaUsed, 2) +
                                    std::pow((duty - rr / (1 + rr)) / dutySigma, 2));
                }
                const double mn = std::min({loss[0], loss[1], loss[2]});
                for (int k = 0; k < 3; ++k) logs_[k] -= std::min((loss[k] - mn) / 2., 8.);
            }
        }
        out.e1Hits = e1Hits;
#ifdef MONO_PARTIAL_DEBUG
        if (!closed.empty()) dbgInc_.clear();
#endif
        for (auto it = supportWhite_.begin(); it != supportWhite_.end();)
            it = (*it * cfg_.bucket >= t - cfg_.tau) ? std::next(it) : supportWhite_.erase(it);
        for (auto it = supportYellow_.begin(); it != supportYellow_.end();)
            it = (*it * cfg_.bucket >= t - cfg_.tau) ? std::next(it) : supportYellow_.erase(it);

        const bool colorYellow = yellowSeen || (tier_ == TierYellow46 && !evidence);
        const int first = colorYellow ? TierYellow46 : TierWhite24;
        const int count = colorYellow ? 1 : 3;
        double ll[3], mx = -1e300;
        for (int i = 0; i < count; ++i) { ll[i] = logs_[first + i]; mx = std::max(mx, ll[i]); }
        double sum = 0;
        for (int i = 0; i < count; ++i) { ll[i] = std::exp(ll[i] - mx); sum += ll[i]; }
        for (int i = 0; i < 4; ++i) out.posterior[i] = 0;
        for (int i = 0; i < count; ++i) out.posterior[first + i] = ll[i] / sum;
        int best = first;
        for (int i = 1; i < count; ++i)
            if (out.posterior[first + i] > out.posterior[best]) best = first + i;
        const double pbest = out.posterior[best];
        const bool hasEvidence = colorYellow ? yellowSeen : evidence;
        // C3：档位自洽性（只对白线三档生效；黄线直接判档保持关闭）
        bool consistOk = true;
        if (cfg_.tierConsistency && !colorYellow) {
            for (int k = 0; k < 3; ++k) {
                const auto st = tierConsistency(out.vh, Tier(k));
                out.consistD[k] = st.D;
                if (k == best)
                    for (int c = 0; c < 3; ++c) {
                        out.consistA[c] = st.a[c];
                        out.consistSig[c] = st.s[c];
                    }
            }
            const double dBest = out.consistD[best];
            double d2 = 1e9;
            for (int k = 0; k < 3; ++k)
                if (k != best) d2 = std::min(d2, out.consistD[k]);
            consistOk = dBest <= cfg_.consistTauC &&
                        d2 >= std::max(cfg_.consistRho * dBest, cfg_.consistTauC);
            if (!consistOk) {
                ++consistRejects_;
                out.consistRejected = 1;
            }
        }
        // e2/e3/黄线直接判档在本文件里根本不实现：黄色也必须攒够 K 个时间桶。
        const bool ok = hasEvidence && int(colorYellow ? supportYellow_.size() : supportWhite_.size()) >= cfg_.K &&
                        pbest >= cfg_.pFirst && consistOk;
        const Tier tierBefore = tier_;   // P3''：用于判定"本帧档位是否切换"
        if (mode_ == ModeDefault24 && ok) {
            tier_ = Tier(best);
            mode_ = ModeDecided;
        } else if (mode_ == ModeDecided) {
            const double advantage = logs_[best] - logs_[tier_];
            if (hasEvidence && Tier(best) != tier_ && advantage >= cfg_.delta) {
                if (!std::isfinite(contraStart_)) contraStart_ = t;
                lastEvidence_ = t;
                if (t - contraStart_ >= cfg_.tContra) {
                    mode_ = ModeReEvaluating;
                    for (double& v : logs_) v = 0;
                    supportWhite_.clear();
                    supportYellow_.clear();
                    contraStart_ = NAN;
                }
            } else if (hasEvidence) {
                contraStart_ = NAN;
                lastEvidence_ = t;
            } else if (std::isfinite(lastEvidence_) && t - lastEvidence_ > 1.05) {
                contraStart_ = NAN;
            }
        } else if (mode_ == ModeReEvaluating && ok) {
            tier_ = Tier(best);
            mode_ = ModeDecided;
        }
        // ---- P3''：档位切换 → 用新规格把窗口里的 Δq 重新换算成 A ----
        // 窗口里存的是原始量，不清空；只有"换算口径"随档位变。
        // 若新颜色在窗口里没有任何观测（例如白→黄但 60s 内没有黄线证据），保持上一个 A
        // 但不刷新 AAt_（=> aAge 变大、一律带问号），不凭空造一个新数值。
        bool fresh = false;
        const bool wantYellow = tier_ == TierYellow46;
        if (tier_ != tierBefore) {
            const auto st = medianOfBuckets(aMain_, tier_, wantYellow);
            if (std::isfinite(st.A) && std::isfinite(out.vh)) {
                A_ = st.A;
                dispersion_ = st.dispersion;
                AAt_ = t;
                fresh = true;
                if (std::isfinite(out.hc)) { f_ = A_ / out.hc; fAt_ = t; }
            }
        }
        // ---- P3'/P4：每个“当前色完整段”的新桶给一个 A 观测，再走长窗口 + 挑战集 ----
        if (!closed.empty() && std::isfinite(out.vh)) {
            for (const auto& b : closed) {
                if (b.yellow != wantYellow || b.dashes.empty()) continue;
                ABucket ab;
                ab.idx = b.idx;
                ab.t = t;
                ab.yellow = b.yellow;
                bucketObs(b, out.vh, ab.obs);
                const double obsA = Aof(ab, tier_);   // 用当前档位换算
                if (!std::isfinite(obsA)) continue;
                if (cfg_.recordObservations) {
                    const int bid = ++bucketSerial_;
                    for (const auto& o : ab.obs)
                        obs_.push_back({++seq_, t, o.dq, o.weight, 1, b.idx, bid, o.kind,
                                        ab.yellow ? 1 : 0});
                }
                if (!std::isfinite(A_)) {
                    // 首次获取：沿用旧的“5s 池化”口径，保证尽快出数（首判不变）。
                    const auto pooled = scaleTier(window_, tier_, out.vh);
                    if (!std::isfinite(pooled.A)) continue;
                    A_ = pooled.A;
                    dispersion_ = pooled.dispersion;
                    aMain_.push_back(std::move(ab));
                    AFirstAt_ = t;
                    AAt_ = t;
                    fresh = true;
                    if (std::isfinite(out.hc)) { f_ = A_ / out.hc; fAt_ = t; }
                    continue;
                }
                const double dev = (obsA - A_) / A_;
                if (std::abs(dev) <= cfg_.ADeviate) {
                    aMain_.push_back(std::move(ab));
                    aChallenge_.clear();
                    aChallengeSign_ = 0;
                } else {
                    // 偏离主值：只记挑战集，不参与主窗口
                    const double sign = dev > 0 ? 1. : -1.;
                    if (sign != aChallengeSign_) { aChallenge_.clear(); aChallengeSign_ = sign; }
                    aChallenge_.push_back(std::move(ab));
                    const double age = t - aChallenge_.front().t;
                    if (age >= cfg_.AChallengeSeconds && int(aChallenge_.size()) >= cfg_.AChallengeMin) {
                        // 挑战成功：整段替换主值，主窗口从挑战集重开（之后 W_A/2 内带"?"）
                        aMain_ = aChallenge_;
                        aChallenge_.clear();
                        aChallengeSign_ = 0;
                        AFirstAt_ = t;
                        AAt_ = t;
                        fresh = true;
                    }
                }
                while (!aMain_.empty() && aMain_.front().t < t - cfg_.AWindow) aMain_.pop_front();
                if (!aMain_.empty()) {
                    const auto st = medianOfBuckets(aMain_, tier_, wantYellow);
                    if (std::isfinite(st.A)) {
                        A_ = st.A;
                        dispersion_ = st.dispersion;
                        AAt_ = t;      // 主窗口有刷新 -> A 视为“新鲜”
                        fresh = true;
                    }
                }
                if (std::isfinite(A_) && std::isfinite(out.hc)) { f_ = A_ / out.hc; fAt_ = t; }
            }
        }
        out.A = A_;
        out.A_main = A_;
        if (!aChallenge_.empty()) {
            const auto cs = medianOfBuckets(aChallenge_, tier_, wantYellow);
            out.A_challenge = cs.A;
            out.challenge_age = t - aChallenge_.front().t;
        }
        // 稳定 = 有 A、当前没有挑战桶、且距首次估计已过 W_A/2
        // C3：档位自洽性不通过时（仍保持 default_2_4），距离一律带 "?"。
        out.aStable = std::isfinite(A_) && aChallenge_.empty() && std::isfinite(AFirstAt_) &&
                      (t - AFirstAt_ >= cfg_.AWindow / 2.) && !out.consistRejected;
        out.dispersion = dispersion_;
        out.f = f_;
        out.aAge = (std::isfinite(A_) && std::isfinite(AAt_)) ? t - AAt_ : NAN;
        out.fAge = (std::isfinite(f_) && std::isfinite(fAt_)) ? t - fAt_ : NAN;
        if (std::isfinite(f_) && std::isfinite(out.fAge) && out.fAge > cfg_.holdLimit) f_ = out.f = NAN;
        out.mode = mode_;
        out.tier = tier_;
        out.p = (mode_ == ModeReEvaluating) ? 1. / count : out.posterior[tier_];
        if (mode_ == ModeReEvaluating)
            for (int i = 0; i < count; ++i) out.posterior[first + i] = 1. / count;
        out.fresh = fresh;
        out.holding = std::isfinite(A_) && !fresh;
        out.kBuckets = int(colorYellow ? supportYellow_.size() : supportWhite_.size());
        out.grade = GradeNone;
        if (std::isfinite(out.vh) && std::isfinite(A_)) {
            const bool high = mode_ == ModeDecided && out.p >= cfg_.pHi && std::isfinite(out.aAge) &&
                              out.aAge <= cfg_.freshSeconds && std::isfinite(dispersion_) &&
                              dispersion_ <= cfg_.dispersion && out.aStable;
            out.grade = high ? GradeApprox : GradeUncertain;
        }
        last_ = out;
        return out;
    }

    double lastTime_ = NAN, drift_ = NAN;
};

// 便捷包装：annotate 线程只有 Frame 快照与配置，不需要构造估计器。
inline Estimator::Target target(const Estimator::Frame& f, const Box& box, const Config& cfg) {
    return Estimator::evaluate(f, box, cfg);
}

}  // namespace mono_partial
