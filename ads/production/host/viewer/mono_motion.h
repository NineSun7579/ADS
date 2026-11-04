#pragma once
// 单目目标运动层（mono_motion）：身份 + 观测时间 -> 纵向相对速度 / 接近-远离趋势。
//
// 为什么在图像域滤波
//   Z = A / (foot - vh)，A 与 v_h 都是在线标定量（会漂移、会被挑战集替换）。若直接对 Z
//   做差分，A/v_h 的任何变化都会变成"目标在动"。这里把状态量取成脚点行 foot（px）本身：
//   foot 只由检测框决定，与 A / v_h / 档位 / 测距方法全部无关。速度在输出时用**当前**
//   几何一次性换算：
//       vz = -A / (foot - vh)^2 * d(foot)/dt
//   于是"固定图像观测、只改估计几何"的负控严格得到 0 运动；A 的误差只按比例影响速度
//   的尺度（与距离同源），不会制造伪速度。档位切换、A/v_h 漂移与挑战值接纳都不需要
//   重建运动历史——它们只改变最后一次换算的比例。
//
// 单位与口径
//   t       秒，单调，同一物理时基（由调用方保证；见 Obs::timeBase）
//   footPx  640x480 分析坐标的行号（已去掉检测模型的 80px padding）
//   vz      m/s，负 = 纵向距离变小（接近），正 = 远离
//   sigmaV  m/s，最小二乘斜率的标准误换算值（只描述随机误差，不含 A 的系统误差）
//
// 身份与时间契约
//   * id 来自上游跟踪器（跨源、跨模型全局唯一）；id==0 表示没有身份 -> 只给位置，不给速度。
//   * 同一 (id, 观测时刻) 只消费一次；时刻不前进（重复/乱序）一律丢弃。
//   * 预测框不是新观测，调用方不得传入。
//   * 源 / 视频循环代次变化、时间戳倒退、相邻观测间隔超过 maxGapS：清空对应历史并重新积累。
//
// 本文件不依赖 Qt / OpenCV，可单独编译测试。
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <mutex>
#include <vector>

namespace mono_motion {

inline constexpr double kNaN = std::numeric_limits<double>::quiet_NaN();

// 趋势：Unknown = 无法估计（样本不足/无效），Steady = 有估计但变化不显著。
// 两者必须区分，不能用 0 填补未知。
enum Trend : int { TrendUnknown = 0, TrendApproach = 1, TrendSteady = 2, TrendRecede = 3 };

inline const char* trendName(Trend t) {
    switch (t) {
        case TrendApproach: return "approach";
        case TrendSteady: return "steady";
        case TrendRecede: return "recede";
        default: return "unknown";
    }
}

// t 分布 95% 双侧临界值（dof 1..30；更大按 1.96）。
// 用途：sigmaV 由窗口残差估计，本身带自由度误差；样本少时必须按 t 而不是正态下定门限，
// 否则"静止目标被误判成接近/远离"的比例会显著高于名义 5%。
inline double tCrit95(int dof) {
    static const double table[31] = {0.,     12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365,
                                     2.306, 2.262,  2.228, 2.201, 2.179, 2.160, 2.145, 2.131,
                                     2.120, 2.110,  2.101, 2.093, 2.086, 2.080, 2.074, 2.069,
                                     2.064, 2.060,  2.056, 2.052, 2.048, 2.045, 2.042};
    return (dof >= 1 && dof <= 30) ? table[dof] : 1.96;
}

// 时间基准：0 = 未知（不输出速度）、1 = 相机捕获时刻（DMA 完成/曝光换算后的物理时间）、
// 2 = 按标称帧率节拍的本地视频回放（物理含义依赖播放器能否跟上标称帧率）。
enum TimeBase : int { TimeBaseUnknown = 0, TimeBaseCapture = 1, TimeBasePacedPlayback = 2 };

struct Config {
    // 窗口由**时长**定义（maxSpanS），条数只作为内存/计算上界：
    //   观测来到的频率由跟踪器决定（检测 4 Hz + NCC 每帧更新 → 最高 30-60 Hz），
    //   若把条数当硬上限，30 Hz 下 12 条只有 0.4 s，永远达不到 minSpanS —— 速度会恒为未知。
    //   120 条 = 2 s @ 60 Hz。
    int maxObs = 120;         // 条（内存上界）
    double maxSpanS = 2.0;    // s
    // 首次出速度的门槛：4 条 + 0.6s。4 Hz 下 4 条=0.75s；10 Hz 下 4 条=0.3s 不够，需 7 条。
    int minObs = 4;
    double minSpanS = 0.6;    // s
    // 相邻观测间隔超过它视为中断（4 倍检测周期 250ms）。
    double maxGapS = 1.0;     // s
    // 趋势显著性：|vz| > trendSigma * sigmaV 才判接近/远离（2.5 ≈ 99% 双侧）。
    // 方向判断比"漏判"代价高（会被下游当成行动证据），所以取偏保守的一侧；
    // 实际门限还要按自由度做 t 修正，见 tCrit95。
    double trendSigma = 2.5;
    // 换算闸门：脚点到地平线的像素间距小于它就不换算（与测距层 foot > vh + 2 同源）。
    double minGapPx = 3.0;    // px
    // 同时保留的身份上限。真正淘汰规则是"最久未更新优先"，绝不按 id 大小淘汰；
    // 64 条 × 120 样本 ≈ 几十 KB，给多目标场景留足余量。
    int maxTracks = 64;
};

struct Obs {
    uint64_t id = 0;          // 跟踪器 ID；0 = 无身份
    double t = kNaN;          // s，该框自身的观测时刻（不是车道帧时刻）
    double footPx = kNaN;     // px，640x480 分析坐标的行号
    double zMeters = kNaN;    // m，同一时刻几何下的纵向距离（仅用于输出/诊断，不参与滤波）
    double A = kNaN, vh = kNaN;  // 当前几何快照（只用于换算与几何变化诊断）
    int tier = -1;            // 档位（只作诊断）
    int method = 0;           // 测距方法（只作诊断）
    int timeBase = TimeBaseCapture;
    uint64_t source = 0;      // 源标识（相机序号或视频文件代次）
    uint64_t continuity = 0;  // 视频循环代次；有变化即整库清空
    bool hasContinuity = true;
};

struct Out {
    bool hasPos = false;      // 本帧有位置（Z 有限）
    bool velValid = false;    // 速度估计有效
    double vz = kNaN;         // m/s
    double sigmaV = kNaN;     // m/s
    double spanS = 0;         // s，窗口内观测跨度
    double medianDtS = kNaN;  // s，窗口内相邻观测间隔中位（时基诊断）
    int n = 0;                // 窗口内观测条数
    Trend trend = TrendUnknown;
    const char* reason = "warmup";  // 状态原因（永远有值）
    bool geomChanged = false;       // 与上一条观测相比 A/v_h 是否明显变化（仅诊断，不重置）
    bool pacedTime = false;         // 时基是按标称帧率节拍的视频回放
    double footRatePx = kNaN;       // px/s，图像域斜率（诊断）
};

class Bank {
public:
    explicit Bank(Config cfg = {}) : cfg_(cfg) {}
    const Config& config() const { return cfg_; }

    // 清空全部历史（切源/停用开关/重建时调用；源与循环变化也会自动清空）。
    void clear() {
        std::lock_guard<std::mutex> lock(mu_);
        tracks_.clear();
        started_ = false;
        lastGlobalT_ = kNaN;
    }
    size_t size() const {
        std::lock_guard<std::mutex> lock(mu_);
        return tracks_.size();
    }
    uint64_t resets() const {
        std::lock_guard<std::mutex> lock(mu_);
        return resets_;
    }

    Out update(const Obs& o) {
        std::lock_guard<std::mutex> lock(mu_);
        Out r;
        r.hasPos = std::isfinite(o.zMeters);
        r.pacedTime = o.timeBase == TimeBasePacedPlayback;
        if (o.timeBase == TimeBaseUnknown) {
            r.reason = "time_base";
            return r;
        }
        if (!std::isfinite(o.t)) {
            r.reason = "no_time";
            return r;
        }
        // 全局时基守卫：时间倒退（循环未给 continuity、时基重建）或源/循环代次变化 -> 整库清空。
        bool wiped = false;
        if (started_) {
            const bool srcChanged = o.hasContinuity && (o.source != src_ || o.continuity != cont_);
            const bool timeBack = std::isfinite(lastGlobalT_) && o.t < lastGlobalT_ - 0.5;
            if (srcChanged || timeBack) {
                tracks_.clear();
                ++resets_;
                wiped = true;
            }
        }
        started_ = true;
        src_ = o.source;
        cont_ = o.continuity;
        lastGlobalT_ = o.t;
        if (wiped) r.reason = "reset";
        if (o.id == 0) {
            r.reason = "no_id";
            return r;
        }
        if (!std::isfinite(o.footPx)) {
            r.reason = "no_obs";
            return r;
        }

        auto it = tracks_.find(o.id);
        bool restarted = wiped;
        bool geomChanged = false;
        if (it != tracks_.end()) {
            const double dt = o.t - it->second.lastT;
            if (!(dt > 1e-6)) {
                // 同一观测重复/乱序：**不重复消费**，但也不能把"上一帧已经算出来的估计"抹成未知——
                // 同一个框被第二个调用点再投影一次时，速度读数不该在那一帧消失。
                const char* why = dt == 0. ? "dup" : "order";
                if (it->second.hasLast) {
                    Out cached = it->second.last;
                    cached.hasPos = std::isfinite(o.zMeters);  // 位置用当前帧的
                    cached.reason = why;
                    cached.pacedTime = o.timeBase == TimeBasePacedPlayback;
                    return cached;
                }
                r.reason = why;
                return r;
            }
            if (dt > cfg_.maxGapS) {
                it->second.s.clear();
                restarted = true;
            }
            // 几何变化只作诊断：滤波在图像域，几何不进入状态。
            if (std::isfinite(o.A) && std::isfinite(it->second.lastA) && std::isfinite(o.vh) &&
                std::isfinite(it->second.lastVh)) {
                const double relA = std::abs(o.A - it->second.lastA) / std::max(1e-9, std::abs(it->second.lastA));
                geomChanged = relA > 0.02 || std::abs(o.vh - it->second.lastVh) > 1.0;
            }
        }
        TrackState& st = tracks_[o.id];
        st.s.push_back({o.t, o.footPx});
        st.lastT = o.t;
        st.lastA = o.A;
        st.lastVh = o.vh;
        // 窗口裁剪：条数 + 时长
        while (st.s.size() > size_t(std::max(2, cfg_.maxObs))) st.s.erase(st.s.begin());  // 内存上界，正常由时长裁剪先生效
        while (!st.s.empty() && st.s.front().t < o.t - cfg_.maxSpanS) st.s.erase(st.s.begin());
        // 有界内存：先按"多久没更新"淘汰，再按最久未更新淘汰；**绝不淘汰当前这条**。
        // 旧实现是"直接 erase(begin())"，而 std::map 的 begin() 是最小 id ——
        // 一旦同时活着的身份数超过 maxTracks，长寿命的小 id 会被每帧删一次，
        // 表现为"某条轨迹 n 永远停在 1"（lane77 实测踩到，且当时还引用了被删元素）。
        for (auto e = tracks_.begin(); e != tracks_.end();) {
            if (e->first != o.id && o.t - e->second.lastT > 3.0 * cfg_.maxGapS) e = tracks_.erase(e);
            else ++e;
        }
        const size_t cap = size_t(std::max(2, cfg_.maxTracks));
        if (tracks_.size() > cap) {
            std::vector<std::pair<double, uint64_t>> age;
            age.reserve(tracks_.size());
            for (const auto& kv : tracks_)
                if (kv.first != o.id) age.emplace_back(kv.second.lastT, kv.first);
            std::sort(age.begin(), age.end());
            const size_t excess = tracks_.size() - cap;
            for (size_t i = 0; i < excess && i < age.size(); ++i) tracks_.erase(age[i].second);
        }
        if (restarted) r.reason = "reset";
        r.geomChanged = geomChanged;

        // 逆深度域最小二乘：Z = A/(foot-vh) = A*q，q = 1/(foot-vh)。
        //   * 匀速运动时 q 对 t 严格线性（Z 线性 -> q=Z/A 线性），不像 foot 那样在近距
        //     把双曲线拟成直线而产生偏差；
        //   * 窗口内所有样本都用**当前** vh 重算 q：vh 变了只相当于整体重新标定 q 的
        //     尺度，固定图像观测不会产生斜率（负控严格为 0）；
        //   * A 只在最后乘一次。
        std::vector<double> ts, qs;
        ts.reserve(st.s.size());
        qs.reserve(st.s.size());
        for (const auto& s : st.s) {
            const double g = s.foot - o.vh;
            if (g > cfg_.minGapPx) {  // 与当前 vh 不自洽的旧样本（vh 大幅跳变）直接跳过
                ts.push_back(s.t);
                qs.push_back(1. / g);
            }
        }
        const int m = int(ts.size());
        r.n = m;
        r.spanS = m >= 2 ? ts.back() - ts.front() : 0.;
        if (m >= 2) {
            std::vector<double> dts;
            dts.reserve(size_t(m - 1));
            for (int i = 1; i < m; ++i) dts.push_back(ts[size_t(i)] - ts[size_t(i - 1)]);
            std::nth_element(dts.begin(), dts.begin() + dts.size() / 2, dts.end());
            r.medianDtS = dts[dts.size() / 2];
        }
        if (m < cfg_.minObs || r.spanS < cfg_.minSpanS) {
            if (!restarted) r.reason = "warmup";
            st.last = r; st.hasLast = true;
            return r;
        }
        double tm = 0, qm = 0;
        for (int i = 0; i < m; ++i) { tm += ts[size_t(i)]; qm += qs[size_t(i)]; }
        tm /= m;
        qm /= m;
        double sxx = 0, sxy = 0;
        for (int i = 0; i < m; ++i) {
            const double dt = ts[size_t(i)] - tm;
            sxx += dt * dt;
            sxy += dt * (qs[size_t(i)] - qm);
        }
        if (!(sxx > 1e-12)) {
            r.reason = "degenerate";
            st.last = r; st.hasLast = true;
            return r;
        }
        const double slopeQ = sxy / sxx;  // 1/(s*px)
        double rss = 0;
        for (int i = 0; i < m; ++i) {
            const double d = qs[size_t(i)] - (qm + slopeQ * (ts[size_t(i)] - tm));
            rss += d * d;
        }
        const double var = m > 2 ? rss / double(m - 2) : kNaN;
        const double sigmaQ = std::isfinite(var) ? std::sqrt(var / sxx) : kNaN;
        if (!std::isfinite(o.A) || !std::isfinite(o.vh) || !std::isfinite(o.A * slopeQ)) {
            r.reason = "no_geom";
            st.last = r; st.hasLast = true;
            return r;
        }
        r.vz = o.A * slopeQ;
        r.sigmaV = std::isfinite(sigmaQ) ? o.A * sigmaQ : kNaN;
        // 诊断：换算回脚点速度（dg/dt = -q'/q^2），仅用于日志
        if (qs.back() > 1e-12) r.footRatePx = -slopeQ / (qs.back() * qs.back());
        r.velValid = true;
        r.reason = "ok";
        if (!std::isfinite(r.sigmaV)) {
            r.trend = TrendUnknown;
        } else {
            // sigmaV 来自残差，本身有自由度误差：按 t 分布放大门限（见 tCrit95）。
            const double kEff = cfg_.trendSigma * tCrit95(m - 2) / 1.96;
            if (std::abs(r.vz) <= kEff * r.sigmaV) r.trend = TrendSteady;
            else r.trend = r.vz < 0. ? TrendApproach : TrendRecede;
        }
        st.last = r; st.hasLast = true;
        return r;
    }

private:
    struct Sample { double t, foot; };
    struct TrackState {
        std::vector<Sample> s;
        double lastT = -1;
        double lastA = kNaN, lastVh = kNaN;
        Out last;               // 上一次已经算出来的结果（重复观测时原样返回）
        bool hasLast = false;
    };
    mutable std::mutex mu_;
    Config cfg_;
    std::map<uint64_t, TrackState> tracks_;
    bool started_ = false;
    uint64_t src_ = 0, cont_ = 0, resets_ = 0;
    double lastGlobalT_ = kNaN;
};

}  // namespace mono_motion



