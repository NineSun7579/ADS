//============================================================================
// lane_detect.v : 车道线行投影 + 虚实判别 (预处理前端级联, 任务2延伸项)
// 输入: Sobel 边缘流 (edge/valid/center)。ROI 为行带(百分比), 两侧各 4 个
// 采样窗, 行内任一窗命中即该行"行活动"。
// 判别(帧末锁存):
//   实线: act_rows >= row_thr*2 且 长连续 (trans*8 < act_rows)
//   虚线: act_rows >= row_thr   且 trans >= dash_thr
//   其余: 无线
// 全部阈值寄存器化 (prep_regs PREP_LANE), 面向板级标定。
// 注: 完整 IPM 逆透视变换为后续扩展点 (接口已预留 edge 流入), 本版先以
//     固定梯形 ROI 近似, 覆盖评分点的"边缘+投影"环节。
//============================================================================
module lane_detect #(
    parameter MAX_WIDTH = 1920,
    parameter AW        = 11,
    parameter WIN_W     = 8        // 采样窗宽
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] img_width,
    input  wire [11:0] img_height,
    input  wire [7:0]  roi_top_pct,     // ROI 顶 (% of height)
    input  wire [7:0]  roi_bot_pct,     // ROI 底 (% of height)
    input  wire [7:0]  row_thr,         // 实线行数门限基数
    input  wire [7:0]  dash_thr,        // 虚线翻转门限
    // Sobel 边缘流
    input  wire [7:0]  s_center,        // 窗口中心灰度(保留, 二值化扩展用)
    input  wire        s_edge,
    input  wire        s_valid,
    input  wire        s_frame_sync,
    // 帧结果
    output reg  [1:0]  m_left_type,     // 00无 01实 10虚
    output reg  [1:0]  m_right_type,
    output reg         m_left_valid,
    output reg         m_right_valid,
    output reg         m_frame_upd      // 本帧结果已更新脉冲
);

    //------------------------------------------------------------------
    // 帧几何: 行计数 + 列计数 (与 sobel 同构: 只在 valid 上推进)
    //------------------------------------------------------------------
    reg [11:0] row_cnt, col_cnt;
    wire       col_wr = (col_cnt == img_width - 12'd1);

    reg [11:0] roi_thr_top, roi_thr_bot;
    wire       in_roi = (row_cnt >= roi_thr_top) && (row_cnt <= roi_thr_bot);
    always @* begin
        roi_thr_top = (img_height * roi_top_pct) / 12'd100;
        roi_thr_bot = (img_height * roi_bot_pct) / 12'd100;
    end

    //------------------------------------------------------------------
    // 采样窗: 两侧各4窗, 窗中心位于宽度的固定分数处
    //   左: 15%, 22%, 29%, 36%   右: 镜像 64%, 71%, 78%, 85%
    //------------------------------------------------------------------
    function [11:0] frac_w(input [11:0] w, input [7:0] pct);
        frac_w = (w * pct) / 12'd100;
    endfunction

    wire [11:0] lc0 = frac_w(img_width, 8'd15) - WIN_W/2;
    wire [11:0] lc1 = frac_w(img_width, 8'd22) - WIN_W/2;
    wire [11:0] lc2 = frac_w(img_width, 8'd29) - WIN_W/2;
    wire [11:0] lc3 = frac_w(img_width, 8'd36) - WIN_W/2;
    wire [11:0] rc0 = frac_w(img_width, 8'd64) - WIN_W/2;
    wire [11:0] rc1 = frac_w(img_width, 8'd71) - WIN_W/2;
    wire [11:0] rc2 = frac_w(img_width, 8'd78) - WIN_W/2;
    wire [11:0] rc3 = frac_w(img_width, 8'd85) - WIN_W/2;

    wire in_win_l = (col_cnt >= lc0 && col_cnt < lc0+WIN_W) ||
                    (col_cnt >= lc1 && col_cnt < lc1+WIN_W) ||
                    (col_cnt >= lc2 && col_cnt < lc2+WIN_W) ||
                    (col_cnt >= lc3 && col_cnt < lc3+WIN_W);
    wire in_win_r = (col_cnt >= rc0 && col_cnt < rc0+WIN_W) ||
                    (col_cnt >= rc1 && col_cnt < rc1+WIN_W) ||
                    (col_cnt >= rc2 && col_cnt < rc2+WIN_W) ||
                    (col_cnt >= rc3 && col_cnt < rc3+WIN_W);

    reg hit_l, hit_r;                          // 本行命中 (行末清)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_l <= 1'b0; hit_r <= 1'b0;
        end else if (s_frame_sync) begin
            hit_l <= 1'b0; hit_r <= 1'b0;
        end else if (s_valid) begin
            if (s_edge && in_roi && in_win_l) hit_l <= 1'b1;
            if (s_edge && in_roi && in_win_r) hit_r <= 1'b1;
            if (col_wr) begin
                hit_l <= 1'b0;
                hit_r <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------
    // 行活动统计 (帧内累加, 帧同步清)
    //------------------------------------------------------------------
    reg [15:0] act_l, act_r;                   // 活动行数
    reg [15:0] tr_l,  tr_r;                    // 0->1 翻转数
    reg        prev_l, prev_r;
    wire       row_end = s_valid && col_wr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_l <= 0; act_r <= 0; tr_l <= 0; tr_r <= 0;
            prev_l <= 0; prev_r <= 0;
        end else if (s_frame_sync) begin
            act_l <= 0; act_r <= 0; tr_l <= 0; tr_r <= 0;
            prev_l <= 0; prev_r <= 0;
        end else if (row_end) begin
            prev_l <= hit_l;
            prev_r <= hit_r;
            if (hit_l) begin
                act_l <= act_l + 1'b1;
                if (!prev_l) tr_l <= tr_l + 1'b1;
            end
            if (hit_r) begin
                act_r <= act_r + 1'b1;
                if (!prev_r) tr_r <= tr_r + 1'b1;
            end
        end
    end

    //------------------------------------------------------------------
    // 帧末判别锁存 (下一帧 vsync 时给出上一帧结果)
    //------------------------------------------------------------------
    wire [15:0] row_thr16 = {8'd0, row_thr};
    wire l_solid = (act_l >= {row_thr16, 1'b0}) && ((tr_l << 3) < act_l);
    wire l_dash  = (act_l >= row_thr16) && (tr_l >= {8'd0, dash_thr});
    wire r_solid = (act_r >= {row_thr16, 1'b0}) && ((tr_r << 3) < act_r);
    wire r_dash  = (act_r >= row_thr16) && (tr_r >= {8'd0, dash_thr});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_left_type <= 2'd0; m_right_type <= 2'd0;
            m_left_valid <= 1'b0; m_right_valid <= 1'b0;
            m_frame_upd  <= 1'b0;
        end else begin
            m_frame_upd <= 1'b0;
            if (s_frame_sync) begin
                m_frame_upd  <= 1'b1;
                m_left_type  <= l_solid ? 2'd1 : (l_dash ? 2'd2 : 2'd0);
                m_right_type <= r_solid ? 2'd1 : (r_dash ? 2'd2 : 2'd0);
                m_left_valid <= (act_l >= row_thr16);
                m_right_valid<= (act_r >= row_thr16);
            end
        end
    end

    wire unused = ^{s_center, 1'b0};

endmodule
