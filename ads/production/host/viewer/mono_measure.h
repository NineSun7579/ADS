#pragma once
// 单目部分解算 · 测量层（mono_measure）
// 目的：在 ADS 里把 d3a 的 432x144 标签网格与同帧 640x480 灰度/彩色图，变成与离线
// measure.cpp 完全同源的“线 / 线段 / 逐行宽度”三张表，供 mono_estimator.h 使用。
// 该文件只做图像测量，不含任何镜头参数常量、不读写标定文件。
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <string>
#include <vector>

namespace mono_partial {

constexpr int ContentTop = 192;   // canvas 640x480 中 d3a 覆盖的起始行
constexpr int MaskW = 432, MaskH = 144;

struct Box {  // 640x480 内容坐标（已去掉检测模型的 80px padding）
    double x = 0, y = 0, w = 0, h = 0;
    int cls = 0;
};

struct Line {  // 一条拟合直线 x = a*y + b，y 在 [y0,y1] 内有掩码支撑
    int id = 0;    // 与 Segment.line 对应；CSV 的 id 可能不连续
    int cls = 0;
    double a = 0, b = 0, y0 = 0, y1 = 0, rms = 0, width = 0;
};

struct Segment {  // 一段“完整”虚线（端点由灰度剖面精修得到）
    int line = 0, cls = 0;
    double top = 0, bottom = 0, xTop = 0, xBottom = 0;
    bool complete = false;
    const char* reason = "ok";
    double coarseTop = 0, coarseBottom = 0, contrast = 0;
    // E2：端点级有效性（与 complete 独立）。complete 为整体判据，这里逐端给出，
    // 供"三端点 pair"使用：远段允许远端截断，只要近端（bottom）可信。
    bool topOk = true, botOk = true;
};

struct Row {  // 某一行上沿该线的梯度测宽
    int line = 0, cls = 0;
    double y = 0, x = 0, width = 0, contrast = 0;
    bool left = true;
};

struct Measurement {
    std::vector<Line> lines;
    std::vector<Segment> segments;
    std::vector<Row> rows;
    void clear() { lines.clear(); segments.clear(); rows.clear(); }
    bool empty() const { return lines.empty() && segments.empty() && rows.empty(); }
    // E1 诊断：合并成功次数 / 因断口内出现暗平台被拒 / 因断口过长被拒 / 合并段中掩码全缺的次数
    int bridged = 0, bridgeDark = 0, bridgeLong = 0, bridgeMaskGap = 0;
};

namespace detail {
// 端点外侧/断口内的"暗平台"阈值：沿用 no_off_plateau 判据里已有的 8，不另设新阈值。
inline constexpr double kOffPlateau = 8.;
inline double sampleAt(const cv::Mat& g, double x, double y) {
    x = std::clamp(x, 1., 638.);
    y = std::clamp(y, 1., 478.);
    const int ix = int(x), iy = int(y);
    const double dx = x - ix, dy = y - iy;
    return (1 - dy) * ((1 - dx) * g.at<uchar>(iy, ix) + dx * g.at<uchar>(iy, ix + 1)) +
           dy * ((1 - dx) * g.at<uchar>(iy + 1, ix) + dx * g.at<uchar>(iy + 1, ix + 1));
}
struct Piece {
    int cls = 0;
    double a = 0, b = 0, y0 = 0, y1 = 0, width = 0;
};
}  // namespace detail

// labels：432x144，每像素一个类别号（0..8，与 lane6 解码一致）。
// bgr：640x480 分析坐标图像（与检测框同一坐标系）。boxes 仅用于遮挡剔除。
inline Measurement measure(const cv::Mat& bgr, const unsigned char* labels,
                           const std::vector<Box>& boxes, double endpointMargin = 8.,
                           double profileThreshold = 12., int bridgeRows = 0) {
    Measurement m;
    if (bgr.empty() || bgr.cols != 640 || bgr.rows != 480 || !labels) return m;
    cv::Mat gray;
    cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(gray, gray, cv::Size(3, 3), .6);

    // ---- 1. 每个类别做连通域，逐行取左右边界点，Huber 拟合出小片 ----
    std::vector<detail::Piece> parts;
    // 掩码列 -> 画布像素：运算顺序必须与离线 measure.cpp 完全一致（先乘后除），
    // 否则末位 1ulp 的差异会在 int(x)/int(w) 的边界上翻出 1 像素的窗口差异。
    for (int cls : {3, 4, 5, 6}) {
        cv::Mat bin(MaskH, MaskW, CV_8U);
        for (int i = 0; i < MaskW * MaskH; ++i) bin.data[i] = labels[i] == cls ? 255 : 0;
        cv::Mat lab, stats, cent;
        const int count = cv::connectedComponentsWithStats(bin, lab, stats, cent, 8);
        for (int k = 1; k < count; ++k) {
            const int top = stats.at<int>(k, cv::CC_STAT_TOP), hh = stats.at<int>(k, cv::CC_STAT_HEIGHT);
            if (hh < 3) continue;
            std::vector<cv::Point2f> pts;
            std::vector<double> ws;
            for (int y = top; y < top + hh; ++y) {
                int l = MaskW, r = -1;
                const int* row = lab.ptr<int>(y);
                for (int x = 0; x < MaskW; ++x)
                    if (row[x] == k) { l = std::min(l, x); r = std::max(r, x); }
                if (r < l) continue;
                const double yy = ContentTop + 2. * y + 1.;
                if (yy > 416) continue;
                pts.push_back({float((l + r + 1) * 320. / MaskW), float(yy)});
                ws.push_back((r - l + 1) * 640. / MaskW);
            }
            if (pts.size() < 3 || pts.back().y - pts.front().y < 4) continue;
            cv::Vec4f fit;
            cv::fitLine(pts, fit, cv::DIST_HUBER, 0, .01, .01);
            if (std::abs(fit[1]) < .05) continue;
            const double a = fit[0] / fit[1], b = fit[2] - a * fit[3];
            if (std::abs(a) > 3) continue;
            parts.push_back({cls, a, b, pts.front().y, pts.back().y,
                             std::accumulate(ws.begin(), ws.end(), 0.) / ws.size()});
        }
    }
    // ---- 2. 同侧同色的小片合并成轨道 ----
    std::sort(parts.begin(), parts.end(),
              [](const auto& a, const auto& b) { return a.y1 - a.y0 > b.y1 - b.y0; });
    struct Track {
        int cls;
        std::vector<detail::Piece> pieces;
        double a, b, w;
    };
    std::vector<Track> tracks;
    for (auto& p : parts) {
        auto t = std::find_if(tracks.begin(), tracks.end(), [&](const Track& t) {
            return (p.cls == 3 || p.cls == 5) == (t.cls == 3 || t.cls == 5) &&
                   std::abs((p.a - t.a) * 330 + p.b - t.b) < 12 && std::abs(p.a - t.a) < .35;
        });
        if (t == tracks.end()) tracks.push_back({p.cls, {p}, p.a, p.b, p.width});
        else t->pieces.push_back(p);
    }
    // ---- 3. 轨道整体重拟合，再沿灰度剖面找虚线段 ----
    // 注意：id 用“轨道序号”而不是输出序号——被 rms/斜率过滤掉的轨道会留下空号，
    // 与离线 measure.cpp 的 CSV id 完全一致（估计层按 id 关联 Segment）。
    for (std::size_t trackIndex = 0; trackIndex < tracks.size(); ++trackIndex) {
        auto& t = tracks[trackIndex];
        std::vector<cv::Point2f> pts;
        double ylo = 420, yhi = 192;
        for (auto& p : t.pieces) {
            pts.push_back({float(p.a * p.y0 + p.b), float(p.y0)});
            pts.push_back({float(p.a * p.y1 + p.b), float(p.y1)});
            ylo = std::min(ylo, p.y0);
            yhi = std::max(yhi, p.y1);
        }
        cv::Vec4f fit;
        cv::fitLine(pts, fit, cv::DIST_HUBER, 0, .01, .01);
        if (std::abs(fit[1]) < .05) continue;
        t.a = fit[0] / fit[1];
        t.b = fit[2] - t.a * fit[3];
        double rms = 0;
        for (auto& p : pts) rms += std::pow(p.x - (t.a * p.y + t.b), 2);
        rms = std::sqrt(rms / pts.size());
        if (rms > 5) continue;
        const int lineId = int(trackIndex);
        m.lines.push_back({lineId, t.cls, t.a, t.b, ylo, yhi, rms, t.w});

        std::vector<double> profile(480, 0);
        std::vector<bool> support(480, false);
        for (int y = 200; y < 418; ++y) {
            const double x = t.a * y + t.b;
            if (x < 10 || x > 630) continue;
            const double w = std::clamp(t.w * .5, 1., 9.);
            const double c = detail::sampleAt(gray, x, y);
            const double bg = .5 * (detail::sampleAt(gray, x - w - 4, y) + detail::sampleAt(gray, x + w + 4, y));
            profile[y] = std::max(0., c - bg);
            const int my = (y - ContentTop) / 2, mx = std::clamp(int(x * MaskW / 640), 0, MaskW - 1);
            for (int dx = -3; dx <= 3; ++dx) {
                const int xx = mx + dx;
                if (xx >= 0 && xx < MaskW) {
                    const int cl = labels[my * MaskW + xx];
                    if (cl == t.cls || (cl >= 3 && (cl % 2) == (t.cls % 2))) support[y] = true;
                }
            }
            if (y >= ylo && y <= yhi) {  // 逐行测宽：两侧最大梯度点的距离
                double gl = -1, gr = -1;
                int xl = 0, xr = 0;
                for (int off = -int(w) - 4; off <= 0; ++off) {
                    const int xx = int(x) + off;
                    const double g = detail::sampleAt(gray, xx + 1, y) - detail::sampleAt(gray, xx - 1, y);
                    if (g > gl) { gl = g; xl = xx; }
                }
                for (int off = 0; off <= int(w) + 4; ++off) {
                    const int xx = int(x) + off;
                    const double g = detail::sampleAt(gray, xx - 1, y) - detail::sampleAt(gray, xx + 1, y);
                    if (g > gr) { gr = g; xr = xx; }
                }
                if (xr > xl && gl > 3 && gr > 3)
                    m.rows.push_back({lineId, t.cls, double(y), (xl + xr) * .5, double(xr - xl),
                                      std::min(gl, gr), x < 320});
            }
        }
        if (t.cls < 5) continue;  // 只有黄(5)/白(6)才是同色车道线，其余只做诊断行

        std::vector<double> prof = profile;
        for (int y = 202; y < 416; ++y) prof[y] = (profile[y - 1] + 2 * profile[y] + profile[y + 1]) / 4;
        // ---- 3b. E1：先收集亮段，再按断口桥接 ----
        // 断口判据复用现有 off-plateau 阈值 8：断口内每行 prof>8 说明仍是亮平台，
        // 只是平滑后低于 profileThreshold → 属于掩码断口；出现 prof<=8 的暗平台则是真实间隔。
        struct Run { int start, end; };
        std::vector<Run> runs;
        for (int y = 201; y < 416;) {
            if (prof[y] < profileThreshold) { ++y; continue; }
            const int start = y;
            while (y < 417 && prof[y] >= profileThreshold) ++y;
            if (y - 1 - start >= 5) runs.push_back({start, y - 1});
        }
        if (bridgeRows > 0 && runs.size() > 1) {
            std::vector<Run> merged;
            merged.push_back(runs[0]);
            for (std::size_t i = 1; i < runs.size(); ++i) {
                Run& prev = merged.back();
                const int gap = runs[i].start - prev.end - 1;
                if (gap > 0 && gap <= bridgeRows) {
                    double mn = 1e9;
                    bool noSup = true;
                    for (int y = prev.end + 1; y < runs[i].start; ++y) {
                        mn = std::min(mn, prof[y]);
                        noSup = noSup && !support[y];
                    }
                    // 断口内必须始终是“亮平台”（沿用现有 off-plateau 阈值 8）；出现暗平台即为真实间隔。
                    // 注：完全缺失的掩码断口会把线拆成两个连通域（两个轨道），进不到这里；
                    // 因此这里覆盖的是“掩码支撑变弱 / 图像对比度变软”的短断口。掩码是否全缺只作诊断计数。
                    if (mn > detail::kOffPlateau) {
                        prev.end = runs[i].end;
                        ++m.bridged;
                        if (noSup) ++m.bridgeMaskGap;
                        continue;
                    }
                    ++m.bridgeDark;
                } else if (gap > bridgeRows) {
                    ++m.bridgeLong;
                }
                merged.push_back(runs[i]);
            }
            runs.swap(merged);
        }
        for (const Run& run : runs) {
            const int start = run.start;
            const int end = run.end;
            int sup = 0;
            double peak = 0;
            for (int j = start; j <= end; ++j) { sup += support[j]; peak = std::max(peak, prof[j]); }
            auto gradient = [&](int j, int sign) { return sign * (prof[j + 1] - prof[j - 1]); };
            auto refine = [&](int around, int sign) {
                int best = around;
                double val = -1e9;
                for (int j = std::max(203, around - 3); j <= std::min(414, around + 3); ++j) {
                    const double g = gradient(j, sign);
                    if (g > val) { val = g; best = j; }
                }
                const double a = gradient(best - 1, sign), b = gradient(best, sign), c = gradient(best + 1, sign);
                const double den = a - 2 * b + c;
                return best + (std::abs(den) > 1e-8 ? std::clamp(.5 * (a - c) / den, -.5, .5) : 0.);
            };
            const double top = refine(start, 1), bot = refine(end, -1);
            bool complete = true;
            const char* reason = "ok";
            auto reject = [&](const char* r) { complete = false; if (std::string(reason) == "ok") reason = r; };
            if (sup < 2 || double(sup) / (end - start + 1) < .08) reject("mask_break");
            if (top < 200 + endpointMargin || bot > 419 - endpointMargin) reject("content_boundary");
            for (double v : {top, bot}) {
                const double x = t.a * v + t.b;
                if (x < 8 || x > 632) reject("image_boundary");
                for (auto box : boxes) {
                    if (x >= box.x - 4 && x <= box.x + box.w + 4 && v >= box.y - 4 && v <= box.y + box.h + 4)
                        reject("occlusion");
                }
                const int vv = std::clamp(int(v), 205, 412);
                bool inside = false;
                for (int j = vv - 3; j <= vv + 3; ++j) inside = inside || support[j];
                if (!inside) reject("mask_break");
            }
            if (prof[std::max(200, int(top) - 5)] > 8 || prof[std::min(417, int(bot) + 5)] > 8) reject("no_off_plateau");
            if (peak < 20) reject("low_contrast");
            double ct = 1e9, cb = -1e9;
            for (auto& p : t.pieces)
                if (p.y1 >= top - 12 && p.y0 <= bot + 12) { ct = std::min(ct, p.y0); cb = std::max(cb, p.y1); }
            if (ct == 1e9) { ct = top; cb = bot; }
            // E2：逐端有效性（与 complete 独立，判据与上面同源，但只针对该端点）
            bool topOk = true, botOk = true;
            if (top < 200 + endpointMargin) topOk = false;
            if (bot > 419 - endpointMargin) botOk = false;
            auto endOk = [&](double v, bool& ok) {
                const double x = t.a * v + t.b;
                if (x < 8 || x > 632) ok = false;
                for (auto box : boxes)
                    if (x >= box.x - 4 && x <= box.x + box.w + 4 && v >= box.y - 4 && v <= box.y + box.h + 4)
                        ok = false;
                const int vv = std::clamp(int(v), 205, 412);
                bool inside = false;
                for (int j = vv - 3; j <= vv + 3; ++j) inside = inside || support[j];
                if (!inside) ok = false;
            };
            endOk(top, topOk);
            endOk(bot, botOk);
            if (prof[std::max(200, int(top) - 5)] > detail::kOffPlateau) topOk = false;
            if (prof[std::min(417, int(bot) + 5)] > detail::kOffPlateau) botOk = false;
            m.segments.push_back({lineId, t.cls, top, bot, t.a * top + t.b, t.a * bot + t.b, complete, reason, ct,
                                  cb, peak, topOk, botOk});
        }
    }
    return m;
}
}  // namespace mono_partial
