/* 分割头板端后处理：连通域 + 等效宽度过滤（对齐 src/postproc.py 的 shape_filter）。
 *
 * 算法（与 Python 参考一致）：
 *   1) 8 连通标记（两遍法 + 并查集）
 *   2) 每个连通域统计 area 与包围盒 (bw,bh)
 *   3) 等效宽度 w = area / hypot(bw,bh)：对任意倾角的理想细线，包围盒对角线≈线长，
 *      所以 w ≈ 真实线宽，且与倾角无关
 *   4) 删掉 w < wmin[c] 或 area < amin[c] 的连通域（阈值为 0 的判据不生效）
 *      amin 按类独立，斑马线与细车道线不得共享未经验证的统一阈值。
 *
 * 为什么不用二阶矩：Python 侧实测那一环占端到端 54%（167ms/帧），换包围盒对角线后降到个位数 ms。
 */
#ifndef SEG_POST_C_H
#define SEG_POST_C_H

#include <math.h>
#include <stdlib.h>
#include <string.h>

/* 返回被删掉的像素数；mask 就地修改（被删的连通域置 0）。 */
static int seg_shape_filter_area_classes(unsigned char *mask, int w, int h,
                                          const float *wmin, int n_classes,
                                          const int *amin) {
    int active = 0;
    for (int c = 1; c < n_classes && c < 256; ++c)
        if (!(wmin[c] <= 0.0f && (!amin || amin[c] <= 0))) { active = 1; break; }
    if (!active) return 0;
    const size_t np = (size_t)w * h;
    int *lab = (int *)malloc(np * sizeof(int));
    if (!lab) return -1;
    for (size_t i = 0; i < np; i++) lab[i] = 0;

    int removed = 0;

    /* A class can only lose pixels during filtering. Its initial bounds remain
       valid, and avoid full-frame passes for every sparse foreground class. */
    int left[256], top[256], right[256], bottom[256];
    for (int c = 0; c < 256; ++c) { left[c] = w; top[c] = h; right[c] = -1; bottom[c] = -1; }
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            int c = mask[(size_t)y * w + x];
            if (!c || c >= n_classes || (wmin[c] <= 0.0f && (!amin || amin[c] <= 0))) continue;
            if (x < left[c]) left[c] = x;
            if (x > right[c]) right[c] = x;
            if (y < top[c]) top[c] = y;
            bottom[c] = y;
        }
    }

    for (int c = 1; c < n_classes && c < 256; c++) {
        const int min_area = amin ? amin[c] : 0;
        if (wmin[c] <= 0.0f && min_area <= 0) continue;
        if (right[c] < 0) continue;

        /* 1) Two-pass labeling; at most one label per pixel in this class's bounds. */
        const size_t capacity = (size_t)(right[c] - left[c] + 1) * (bottom[c] - top[c] + 1) + 1;
        int *parent = (int *)malloc(capacity * sizeof(int));
        if (!parent) { free(lab); return -1; }
        /* Each parent is initialized when its label is first assigned. */
        int next = 1;

        for (int y = top[c]; y <= bottom[c]; y++) {
            for (int x = left[c]; x <= right[c]; x++) {
                size_t i = (size_t)y * w + x;
                if (mask[i] != c) continue;
                int best = 0;
                /* 左、上、左上、右上（8 连通在上/左方向上的四个邻域） */
                int nx[4] = {x - 1, x, x - 1, x + 1};
                int ny[4] = {y, y - 1, y - 1, y - 1};
                for (int k = 0; k < 4; k++) {
                    if (nx[k] < 0 || nx[k] >= w || ny[k] < 0) continue;
                    int l = lab[(size_t)ny[k] * w + nx[k]];
                    if (!l) continue;
                    /* union：把 l 挂到 best 上 */
                    if (!best) { best = l; continue; }
                    int a = l, b = best;
                    while (parent[a] != a) a = parent[a];
                    while (parent[b] != b) b = parent[b];
                    if (a != b) parent[a > b ? a : b] = a < b ? a : b;
                    if (l < best) best = l;
                }
                if (!best) { best = next++; parent[best] = best; }
                lab[i] = best;
            }
        }

        /* 2) 汇总每个 root 的 area 与 bbox */
        int *area = (int *)calloc((size_t)next, sizeof(int));
        int *x0 = (int *)malloc((size_t)next * sizeof(int));
        int *y0 = (int *)malloc((size_t)next * sizeof(int));
        int *x1 = (int *)malloc((size_t)next * sizeof(int));
        int *y1 = (int *)malloc((size_t)next * sizeof(int));
        if (!area || !x0 || !y0 || !x1 || !y1) { free(parent); free(area); free(x0); free(y0); free(x1); free(y1); free(lab); return -1; }
        for (int i = 0; i < next; i++) { x0[i] = w; y0[i] = h; x1[i] = -1; y1[i] = -1; }

        for (int y = top[c]; y <= bottom[c]; y++) {
            for (int x = left[c]; x <= right[c]; x++) {
                size_t i = (size_t)y * w + x;
                int l = lab[i];
                if (!l) continue;
                int r = l;
                while (parent[r] != r) r = parent[r];
                lab[i] = r;                       /* 路径压缩 */
                area[r]++;
                if (x < x0[r]) x0[r] = x;
                if (x > x1[r]) x1[r] = x;
                if (y < y0[r]) y0[r] = y;
                if (y > y1[r]) y1[r] = y;
            }
        }

        /* 3) 判定并删除 */
        unsigned char *kill = (unsigned char *)calloc((size_t)next, 1);
        if (!kill) { free(parent); free(area); free(x0); free(y0); free(x1); free(y1); free(lab); return -1; }
        for (int r = 1; r < next; r++) {
            if (area[r] == 0) continue;
            double bw = (double)(x1[r] - x0[r] + 1);
            double bh = (double)(y1[r] - y0[r] + 1);
            double diag = sqrt(bw * bw + bh * bh);
            double wid = diag > 0.0 ? (double)area[r] / diag : 0.0;
            if (area[r] < min_area || wid < (double)wmin[c]) kill[r] = 1;
        }
        for (int y = top[c]; y <= bottom[c]; ++y) {
            for (int x = left[c]; x <= right[c]; ++x) {
                size_t i = (size_t)y * w + x;
                int l = lab[i];
                if (l && l < next && kill[l]) { mask[i] = 0; removed++; }
                lab[i] = 0;                        /* 复用给下一个类 */
            }
        }

        free(kill);
        free(parent); free(area); free(x0); free(y0); free(x1); free(y1);
    }

    free(lab);
    return removed;
}

/* 标量阈值便捷入口；amin=0 表示仅等效宽度过滤。 */
static inline int seg_shape_filter_area(unsigned char *mask, int w, int h,
                                         const float *wmin, int n_classes, int amin) {
    int thresholds[16];
    if (n_classes > 16) return -1;
    for (int c = 0; c < n_classes; ++c) thresholds[c] = amin;
    return seg_shape_filter_area_classes(mask, w, h, wmin, n_classes, thresholds);
}

static inline int seg_shape_filter(unsigned char *mask, int w, int h,
                                   const float *wmin, int n_classes) {
    return seg_shape_filter_area(mask, w, h, wmin, n_classes, 0);
}

#endif /* SEG_POST_C_H */
