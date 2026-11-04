`timescale 1ns / 1ps
//===========================================================================
//  sfp_rx_cam_if.v -- 光口视频流拆分 + 跨时钟域 (100H 侧)
//
//  输入: sfp_video_rx 解包出的 1280 宽合成像素流 (125M RX fabric 域),
//        = 50K 双摄 cam2_merge 逐行拼接 (前 640 列 = CMOS1, 后 640 列 = CMOS2)
//  输出: 两路标准 {vs,hs,de,pix} 摄像头式流 (axi_clk 域), 各 640x480,
//        分别喂 ov5640_ddr 写引擎 (cam5 / cam6)
//
//  拆分: vs 上升沿清列计数, de 期间计数; x < SPLIT_W 走 ch5, 其余走 ch6。
//        以帧首对齐而非行首, 行内 de 断续(gap)不会错位。
//  CDC : 每路一个 19bit {vs,hs,de,pix} 格雷码异步 FIFO (video_async_fifo,
//        50K 侧同款已验证), 写 rx_clk 读 axi_clk。
//        稳态符号率 ~37M/s << 两域时钟, 峰值受上游 2048 深度限幅, 1024 深
//        CDC FIFO 足够 (最坏积压 = 上游排空 + 读侧迟滞)。
//===========================================================================
module sfp_rx_cam_if #(
    parameter IMG_W  = 1280,     // 合成行宽
    parameter SPLIT_W = 640,     // 每路宽
    parameter FIFO_D = 1024      // CDC FIFO 深 (2 的幂)
)(
    input  wire        i_rx_clk,     // 125M RX fabric
    input  wire        i_rx_rst_n,
    input  wire        i_vs,
    input  wire        i_hs,
    input  wire        i_de,
    input  wire [15:0] i_pix,

    input  wire        i_axi_clk,    // DDR3 用户时钟 (ov5640_ddr 侧)
    input  wire        i_axi_rst_n,

    output wire        o_vs5,  output wire        o_hs5,
    output wire        o_de5,  output wire [15:0] o_pix5,
    output wire        o_vs6,  output wire        o_hs6,
    output wire        o_de6,  output wire [15:0] o_pix6
);

    //-----------------------------------------------------------------------
    // 列拆分 (rx_clk 域): vs 上升沿清 x; de 时 x++ 并按 x<SPLIT_W 分流
    //-----------------------------------------------------------------------
    reg  [10:0] x_cnt;
    reg         vs_q;
    wire        vs_rise = i_vs & ~vs_q;
    always @(posedge i_rx_clk or negedge i_rx_rst_n) begin
        if (!i_rx_rst_n) begin
            x_cnt <= 11'd0;
            vs_q  <= 1'b0;
        end
        else begin
            vs_q <= i_vs;
            if (vs_rise)
                x_cnt <= 11'd0;
            else if (i_de)
                x_cnt <= (x_cnt == IMG_W-1) ? 11'd0 : x_cnt + 11'd1;
        end
    end

    wire sel5 = (x_cnt < SPLIT_W);

    wire [18:0] sym5_w = {i_vs, i_hs, i_de &  sel5, i_pix};
    wire [18:0] sym6_w = {i_vs, i_hs, i_de & ~sel5, i_pix};

    //-----------------------------------------------------------------------
    // 两路 CDC (video_async_fifo, 格雷码指针; 读法与 sfp_video_tx 中一致:
    // rd_data 为弹出当前字, rd_en 由 empty 门控, 空闲时保持)
    //-----------------------------------------------------------------------
    wire        fif5_empty, fif6_empty;
    wire        fif5_full,  fif6_full;
    wire [18:0] fif5_rdata, fif6_rdata;

    video_async_fifo #(.WIDTH(19), .DEPTH(FIFO_D)) u_fifo5 (
        .wr_clk   (i_rx_clk),
        .wr_rst_n (i_rx_rst_n),
        .wr_en    (1'b1),
        .wr_data  (sym5_w),
        .full     (fif5_full),
        .rd_clk   (i_axi_clk),
        .rd_rst_n (i_axi_rst_n),
        .rd_en    (~fif5_empty),
        .rd_data  (fif5_rdata),
        .empty    (fif5_empty)
    );

    video_async_fifo #(.WIDTH(19), .DEPTH(FIFO_D)) u_fifo6 (
        .wr_clk   (i_rx_clk),
        .wr_rst_n (i_rx_rst_n),
        .wr_en    (1'b1),
        .wr_data  (sym6_w),
        .full     (fif6_full),
        .rd_clk   (i_axi_clk),
        .rd_rst_n (i_axi_rst_n),
        .rd_en    (~fif6_empty),
        .rd_data  (fif6_rdata),
        .empty    (fif6_empty)
    );

    // full 悬空处理: 稳态速率分析保证不会满; 综合器会给出未使用警告, 可接受

    //-----------------------------------------------------------------------
    // 读侧输出 (axi_clk 域): FIFO 空闲时 rd_data 保持, de=0 期间自然消隐
    //-----------------------------------------------------------------------
    // The FIFO head is combinational and may contain stale data when empty.
    // Keep head timing while valid; retain the last popped syncs when empty.
    reg vs5_hold, hs5_hold, vs6_hold, hs6_hold;
    always @(posedge i_axi_clk or negedge i_axi_rst_n) begin
        if (!i_axi_rst_n) begin
            vs5_hold <= 1'b0; hs5_hold <= 1'b0;
            vs6_hold <= 1'b0; hs6_hold <= 1'b0;
        end
        else begin
            if (!fif5_empty) begin
                vs5_hold <= fif5_rdata[18];
                hs5_hold <= fif5_rdata[17];
            end
            if (!fif6_empty) begin
                vs6_hold <= fif6_rdata[18];
                hs6_hold <= fif6_rdata[17];
            end
        end
    end

    assign o_vs5  = fif5_empty ? vs5_hold : fif5_rdata[18];
    assign o_hs5  = fif5_empty ? hs5_hold : fif5_rdata[17];
    assign o_de5  = !fif5_empty & fif5_rdata[16];
    assign o_pix5 = fif5_rdata[15:0];

    assign o_vs6  = fif6_empty ? vs6_hold : fif6_rdata[18];
    assign o_hs6  = fif6_empty ? hs6_hold : fif6_rdata[17];
    assign o_de6  = !fif6_empty & fif6_rdata[16];
    assign o_pix6 = fif6_rdata[15:0];

endmodule
