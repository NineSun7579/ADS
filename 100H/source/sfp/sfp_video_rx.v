`timescale 1ns / 1ps
//===========================================================================
//  sfp_video_rx.v  --  SFP 光口视频接收解包器 (100H 侧)
//
//  链路协议 (与 50K 侧 sfp_video_tx.v 配套, 见其头注释):
//    HSST/HSSTLP CH2, 5Gbps, 8B10B, fabric 32bit @ 125MHz。
//    数据字 (rxk==4'b0000) = 2 个有效像素: rxd = {pix1[15:0], pix0[15:0]}
//      byte0/1 = 先发像素 pix0, byte2/3 = 后发像素 pix1。
//    控制字 (rxk==4'b1001) = {8'hBC, {1'b0,hs,vs,5'b0}, 8'h28, 8'hBC}
//      => vs = rxd[21], hs = rxd[22] (电平随控制字连续更新, de 恒 0)。
//    帧边界 = vs 上升沿, 每帧 1280x480 (双摄合成流, 前640=cam1/后640=cam2)。
//
//  设计要点 -- 符号流 FIFO 保序:
//    数据字拆成 2 个像素符号、控制字作为 vs/hs 事件符号, 共用一个同步 FIFO
//    排队输出。这样即使 RX 侧像素弹出落后于后续控制字到达(链路突发积压),
//    vs/hs 电平更新也不会越过未输出的像素 -- 行/帧标记严格保序。
//
//  输出为标准摄像头式像素流 {vs, hs, de, rgb565}, 与 ov5640 通路同构,
//  下游 splitter 按列拆 cam5/cam6, 本模块不关心行宽。
//
//  时钟域: i_clk = HSST o_p_clk2core_rx_2 (125MHz)。
//===========================================================================
module sfp_video_rx #(
    parameter FIFO_AW = 11                   // 符号 FIFO 深度 2^11 = 2048
)(
    input  wire        i_clk,                // 125MHz RX fabric 时钟
    input  wire        i_rst_n,
    input  wire        i_en,                 // 链路同步有效(pcs_lsm_synced & rxlane_done), 0=清状态
    input  wire [31:0] i_rxd,
    input  wire [3:0]  i_rxk,
    output reg         o_vs,                 // 锁存电平输出
    output reg         o_hs,
    output reg         o_de,
    output reg  [15:0] o_pix,
    output wire        o_overflow            // 符号 FIFO 溢出指示(调试用)
);

    //-----------------------------------------------------------------------
    // 字型判别与控制字电平抽取
    //-----------------------------------------------------------------------
    wire        w_vs      = i_rxd[21];
    wire        w_hs      = i_rxd[22];
    wire        w_is_data = (i_rxk == 4'b0000);
    wire        w_is_ctrl = (i_rxk == 4'b1001);

    //-----------------------------------------------------------------------
    // 同步符号 FIFO (simple dual-port, 2048 x 19bit)
    //   符号 = {tag, vs, hs, pix[15:0]}; tag=1 控制符号, tag=0 数据符号。
    //   数据字 -> 压 2 个数据符号; 电平变化的控制字 -> 压 1 个控制符号。
    //
    //   关键: 电平未变的控制/idle 字【不入队直接丢弃】。TX 侧每个 fab 拍
    //   都有字(idle 携带当前电平, 见 sfp_video_tx Rev3.1fix2), 若全部入队,
    //   符号入队率 ~125M/s 超过出队率必然溢出; 只有电平变化才影响输出,
    //   用 shadow 电平判变即可, 保序性不受影响 (变化点仍严格排队)。
    //-----------------------------------------------------------------------
    reg [18:0] mem0 [0:(1<<(FIFO_AW-1))-1];   // even symbol slots
    reg [18:0] mem1 [0:(1<<(FIFO_AW-1))-1];   // odd symbol slots
    reg [FIFO_AW:0] wptr, rptr;
    reg        shadow_vs, shadow_hs;   // 已入队的最新电平

    wire        empty = (wptr == rptr);
    wire [FIFO_AW:0] used = wptr - rptr;

    wire ctrl_chg = w_is_ctrl && ((w_vs != shadow_vs) || (w_hs != shadow_hs));

    wire push2 = i_en & w_is_data & (used <= ((1<<FIFO_AW) - 3));
    wire push1 = i_en & ctrl_chg  & (used <= ((1<<FIFO_AW) - 2));
    wire pushA = push2 | push1;

    wire [FIFO_AW-1:0] wa = wptr[FIFO_AW-1:0];
    wire [FIFO_AW-1:0] wb = wptr[FIFO_AW-1:0] + 1'b1;

    // 写口 A: 数据字时为 pix0, 电平变化控制字时为 vs/hs 事件符号
    wire [18:0] symA = push2 ? {1'b0, 2'b00, i_rxd[15:0]}
                             : {1'b1, w_vs, w_hs, 16'b0};

    // [BANK 2026-09-30] PDS cannot infer a RAM with two writes per cycle
    // (Sdm-2010). Split by symbol parity so each bank sees one write.
    wire [18:0] symB  = {1'b0, 2'b00, i_rxd[31:16]};
    wire        wodd  = wptr[0];
    wire        we0   = push2 | (push1 & ~wodd);
    wire        we1   = push2 | (push1 &  wodd);
    wire [FIFO_AW-2:0] wa0 = wodd ? wb[FIFO_AW-1:1] : wa[FIFO_AW-1:1];
    wire [FIFO_AW-2:0] wa1 = wa[FIFO_AW-1:1];
    wire [18:0] wd0   = wodd ? symB : symA;
    wire [18:0] wd1   = wodd ? symA : symB;
    always @(posedge i_clk) begin
        if (we0) mem0[wa0] <= wd0;
        if (we1) mem1[wa1] <= wd1;
    end

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            wptr <= 0; shadow_vs <= 1'b0; shadow_hs <= 1'b0;
        end
        else if (!i_en) begin
            wptr <= 0; shadow_vs <= 1'b0; shadow_hs <= 1'b0;
        end
        else begin
            wptr <= wptr + (push2 ? 2'd2 : (push1 ? 1'd1 : 1'd0));
            if (push1) begin
                shadow_vs <= w_vs;
                shadow_hs <= w_hs;
            end
        end
    end

    //-----------------------------------------------------------------------
    // 读侧: 每拍最多弹 1 个符号, 重建像素流
    //-----------------------------------------------------------------------
    wire        pop  = ~empty & i_en;
    wire [18:0] rsym = rptr[0] ? mem1[rptr[FIFO_AW-1:1]] : mem0[rptr[FIFO_AW-1:1]];

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rptr <= 0; o_vs <= 1'b0; o_hs <= 1'b0; o_de <= 1'b0; o_pix <= 16'b0;
        end
        else if (!i_en) begin
            rptr <= 0; o_vs <= 1'b0; o_hs <= 1'b0; o_de <= 1'b0;
        end
        else if (pop) begin
            rptr <= rptr + 1'b1;
            if (rsym[18]) begin                  // 控制符号: 更新电平, 无像素
                o_de <= 1'b0;
                o_vs <= rsym[17];
                o_hs <= rsym[16];
            end
            else begin                           // 数据符号: 输出像素
                o_de <= 1'b1;
                o_pix <= rsym[15:0];
            end
        end
        else begin
            o_de <= 1'b0;                        // FIFO 空: 消隐保持电平
        end
    end

    // 溢出脉冲(应恒为 0: 稳态符号率 ~74M/s << 125M/s; 电平不变的 ctrl 不入队属正常)
    reg ovf_q;
    assign o_overflow = ovf_q;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) ovf_q <= 1'b0;
        else          ovf_q <= (i_en & w_is_data & ~push2) | (i_en & ctrl_chg & ~push1);
    end

endmodule
