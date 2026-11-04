`timescale 1ns / 1ps
//===========================================================================
//  sfp_rx_link.v -- 100H SFP 光口链路顶层包装 (QR3 / HSSTLP_364_918 CH2)
//
//  - 例化 hsst_sfp IP (CH2 5G/8B10B/32bit@125M/GE_MODE/K28.5/CTC=GE,
//    PLL1@100MHz Diff_REFCK0 -- PLL0 已让给 PCIe x2)
//  - POR ~10ms (free_clk 25M) 驱动 PLL 复位/看门狗清零
//  - TX 方向恒发 idle 有序集 32'hBC0028BC / txk=1001 (对端 LOS 指示用)
//  - 输出 o_p_clk2core_rx_2 域的 {rxd, rxk} 给 sfp_video_rx 解包
//  - rx_en = pcs_lsm_synced & rxlane_done (解包器使能/复位)
//
//  与 project/source/constraints/sfp.fdc 配套:
//    U1_HSSTLP_PLL + U2_HSSTLP_LANE @ HSSTLP_364_918
//    refck = F6/E6 (与 PCIe 共用 100M 差分对), SFP: l2tx D5/C5, l2rx D11/C11
//===========================================================================
module c5_sfp_rx_link (
    input  wire        i_free_clk,       // 25MHz 板载
    input  wire        i_refckp,         // F6 100MHz GT 参考时钟 (与 PCIe 共用)
    input  wire        i_refckn,         // E6
    input  wire        i_l2rxn,          // D11 SFP RX-
    input  wire        i_l2rxp,          // C11 SFP RX+
    output wire        o_l2txn,          // D5  SFP TX-
    output wire        o_l2txp,          // C5  SFP TX+
    output wire        o_sfp_tx_disable, // L16, 恒 0

    output wire        o_rx_clk,         // o_p_clk2core_rx_2 (125M fabric)
    output wire        o_rx_rst_n,       // POR 同步到 rx 时钟域
    output wire [31:0] o_rxd,
    output wire [3:0]  o_rxk,
    output wire        o_rx_en,          // pcs_lsm_synced & rxlane_done
    // 链路状态 (free_clk 域 2FF 同步, 供 LED/寄存器)
    output wire        o_pll_lock,       // PLL1 锁定
    output wire        o_txlane_done,    // [SFP-STATUS] TX lane2 done
    output wire        o_rxlane_done,
    output wire        o_pcs_synced,
    input wire i_cmd_valid, input wire [31:0] i_cmd_data, input wire [3:0] i_cmd_k,
    output wire o_cmd_ready,
    output wire        o_rx_sigdet
);

    //-----------------------------------------------------------------------
    // POR ~10ms @ 25MHz (上电计数, 计满释放; FPGA 寄存器上电为 0)
    //-----------------------------------------------------------------------
    reg [17:0] por_cnt = 18'd0;
    reg        por_rst = 1'b1;
    always @(posedge i_free_clk) begin
        if (por_cnt == 18'd249_999) begin
            por_cnt <= por_cnt;
            por_rst <= 1'b0;
        end
        else begin
            por_cnt <= por_cnt + 18'd1;
            por_rst <= 1'b1;
        end
    end

    //-----------------------------------------------------------------------
    // HSST 信号
    //-----------------------------------------------------------------------
    wire [1:0]  wtchdg_st_0, wtchdg_st_1;
    wire        pll_done_0, pll_done_1;
    wire        txlane_done_2, rxlane_done_2;
    wire        clk2core_tx_2, clk2core_rx_2;
    wire        pll_lock_0, pll_lock_1;
    wire        rx_sigdet_2, cdr_align_2, pcs_synced_2;
    wire [2:0]  rxstatus_2;
    wire [3:0]  rdisper_2, rdecer_2;
    wire [31:0] rxd_raw;
    wire [3:0]  rxk_raw;

    // 核侧参考时钟全部由 TX 核时钟提供 (与 sfp_rx_100h 验证配置一致)
    wire tx2_clk_fr_core = clk2core_tx_2;
    wire tx3_clk_fr_core = clk2core_tx_2;
    wire rx2_clk_fr_core = clk2core_tx_2;
    wire rx3_clk_fr_core = clk2core_tx_2;

    // CH3 (SFP1 cage) 空置: 串行口悬空, 不约束
    wire l3rxn = 1'b0;
    wire l3rxp = 1'b0;
    wire l3txn, l3txp;

    // TX: 08 例程 GE 8 拍序列复刻 [2026-09-30 LED6 修复 R2]
    //   50K RX = GE/2SKIP CTC (SKIP_REG0=K28.5, SKIP_REG1=D28.2, bonding bypass, comma=K28.5),
    //   其 PCS 只认 08 例程 hsst_test_src 的 TX 节奏:
    //     拍0(bonding=全bypass=idle) + 拍1..5 idle + 拍6 skip + 拍7 payload(本设计发 idle 数据)
    //   idle 字   = {D5.6, K28.5, D5.6, K28.5} = 32'hC5BC_C5BC, txk=0101
    //   skip 字   = {D28.2, K28.5, D28.2, K28.5} = 32'h28BC_28BC, txk=0101
    //   (byte0 = 线上第一字节; SKIP_REG0=10'b110111100 -> {1'b1,8'hBC}=K28.5, SKIP_REG1=10'b001010000 -> {1'b0,8'h28}=D28.2)
    localparam [31:0] IDLE_WORD = 32'hC5BC_C5BC;   // K28.5/D5.6 交织
    localparam [3:0]  IDLE_K    = 4'b0101;
    localparam [31:0] SKIP_WORD = 32'h28BC_28BC;   // K28.5/D28.2 (GE skip ordered set)
    localparam [3:0]  SKIP_K    = 4'b0101;
    reg  [2:0] tx_phase;
    reg  [1:0] tx_por_sync = 2'b00;
    always @(posedge clk2core_tx_2) tx_por_sync <= {tx_por_sync[0], ~por_rst};
    always @(posedge clk2core_tx_2 or negedge tx_por_sync[1]) begin
        if (!tx_por_sync[1])
            tx_phase <= 3'd0;
        else
            tx_phase <= tx_phase + 3'd1;           // 8 拍循环 (0..7)
    end
    // 拍0..6: 交替 idle/skip (拍6=skip), 拍7: payload 位置也发 idle (50K chk 未用, 数据字不影响 CTC)
    wire [31:0] txd_2 = (tx_phase==3'd6)?SKIP_WORD:((o_cmd_ready && i_cmd_valid)?i_cmd_data:IDLE_WORD);
    wire [3:0] txk_2 = (tx_phase==3'd6)?SKIP_K:((o_cmd_ready && i_cmd_valid)?i_cmd_k:IDLE_K);
    assign o_cmd_ready=(tx_phase==3'd7) && tx_por_sync[1] && txlane_done_2;
    wire [3:0]  tdispsel_2 = 4'b0000;
    wire [3:0]  tdispctrl_2= 4'b0000;

    assign o_sfp_tx_disable = 1'b0;

    hsst_sfp u_hsst (
        .i_free_clk        (i_free_clk),
        .i_p_refckn_0      (i_refckn),
        .i_p_refckp_0      (i_refckp),
        .i_wtchdg_clr_0    (~por_rst),
        .o_wtchdg_st_0     (wtchdg_st_0),
        .o_pll_done_0      (pll_done_0),
        .o_txlane_done_2   (txlane_done_2),
        .o_rxlane_done_2   (rxlane_done_2),
        .o_p_clk2core_tx_2 (clk2core_tx_2),
        .i_p_tx2_clk_fr_core (tx2_clk_fr_core),
        .i_p_tx3_clk_fr_core (tx3_clk_fr_core),
        .o_p_clk2core_rx_2 (clk2core_rx_2),
        .i_p_rx2_clk_fr_core (rx2_clk_fr_core),
        .i_p_rx3_clk_fr_core (rx3_clk_fr_core),
        .o_p_pll_lock_0    (pll_lock_0),
        .o_p_rx_sigdet_sta_2 (rx_sigdet_2),
        .o_p_lx_cdr_align_2  (cdr_align_2),
        .o_p_pcs_lsm_synced_2(pcs_synced_2),
        .i_p_l2rxn         (i_l2rxn),
        .i_p_l2rxp         (i_l2rxp),
        .i_p_l3rxn         (l3rxn),
        .i_p_l3rxp         (l3rxp),
        .o_p_l2txn         (o_l2txn),
        .o_p_l2txp         (o_l2txp),
        .o_p_l3txn         (l3txn),
        .o_p_l3txp         (l3txp),
        .i_txd_2           (txd_2),
        .i_tdispsel_2      (tdispsel_2),
        .i_tdispctrl_2     (tdispctrl_2),
        .i_txk_2           (txk_2),
        .o_rxstatus_2      (rxstatus_2),
        .o_rxd_2           (rxd_raw),
        .o_rdisper_2       (rdisper_2),
        .o_rdecer_2        (rdecer_2),
        .o_rxk_2           (rxk_raw),
        .i_pll_rst_0       (por_rst),
        // [SFP-PLL1 2026-09-29] PLL1 = CH2 时钟源 (PLL0 让给 PCIe)
        .i_pll_rst_1       (por_rst),
        .i_wtchdg_clr_1    (~por_rst),
        .o_wtchdg_st_1     (wtchdg_st_1),
        .o_pll_done_1      (pll_done_1),
        .o_p_pll_lock_1    (pll_lock_1)
    );

    //-----------------------------------------------------------------------
    // rx 域复位: POR 释放后在 clk2core_rx_2 域 2FF 同步
    // (clk2core_rx_2 在 POR 期间可能未起振, 复位释放依赖时钟已稳定:
    //  PLL lock 后该时钟即有效, 而 por_rst 至少持续 10ms >> PLL 锁定时间)
    //-----------------------------------------------------------------------
    reg [1:0] rx_rst_sync = 2'b11;
    always @(posedge clk2core_tx_2) begin
        rx_rst_sync <= {rx_rst_sync[0], por_rst};
    end
    assign o_rx_rst_n = ~rx_rst_sync[1];

    //-----------------------------------------------------------------------
    // 链路状态输出 (free_clk 域 2FF)
    //-----------------------------------------------------------------------
    reg [1:0] sync_pll, sync_lane, sync_pcs, sync_det, sync_txd;
    always @(posedge i_free_clk) begin
        sync_pll  <= {sync_pll[0],  pll_lock_0};   // [PLL0-SHARE] SFP CH2 uses shared PLL0
        sync_txd  <= {sync_txd[0],  txlane_done_2};
        sync_lane <= {sync_lane[0], rxlane_done_2};
        sync_pcs  <= {sync_pcs[0],  pcs_synced_2};
        sync_det  <= {sync_det[0],  rx_sigdet_2};
    end
    assign o_pll_lock     = sync_pll[1];
    assign o_txlane_done  = sync_txd[1];
    assign o_rxlane_done  = sync_lane[1];
    assign o_pcs_synced   = sync_pcs[1] & sync_lane[1];
    assign o_rx_sigdet    = sync_det[1];

    //-----------------------------------------------------------------------
    // [FORCE-LSM RX 2026-09-30]
    //  - RX bridge FIFO read clock = i_p_rx2_clk_fr_core = clk2core_tx_2,
    //    so rxd/rxk live in clk2core_tx_2 domain (vendor ref does the same).
    //  - force_rxfsm_lsm_2=1: pcs_lsm_synced may never assert (GE LSM needs
    //    commas on even bytes; ctrl word has K28.5 at byte0+byte3).
    //    Enable = rxlane_done_2 only.
    //  - Comma may land on any byte lane: rotate by locating ctrl word
    //    {BC, st, 28, BC} / k=1001 in a 2-word window, re-lock on every hit.
    //-----------------------------------------------------------------------
    reg [31:0] rxd_d0, rxd_d1;
    reg [3:0]  rxk_d0, rxk_d1;
    always @(posedge clk2core_tx_2) begin
        rxd_d0 <= rxd_raw;  rxk_d0 <= rxk_raw;
        rxd_d1 <= rxd_d0;   rxk_d1 <= rxk_d0;
    end
    wire [63:0] win_d = {rxd_d0, rxd_d1};
    wire [7:0]  win_k = {rxk_d0, rxk_d1};
    wire [31:0] cand_d0 = win_d[31:0],  cand_d1 = win_d[39:8],
                cand_d2 = win_d[47:16], cand_d3 = win_d[55:24];
    wire [3:0]  cand_k0 = win_k[3:0],   cand_k1 = win_k[4:1],
                cand_k2 = win_k[5:2],   cand_k3 = win_k[6:3];
    wire hit0 = (cand_k0 == 4'b1001) && (cand_d0[7:0] == 8'hBC) && (cand_d0[15:8] == 8'h28) && (cand_d0[31:24] == 8'hBC);
    wire hit1 = (cand_k1 == 4'b1001) && (cand_d1[7:0] == 8'hBC) && (cand_d1[15:8] == 8'h28) && (cand_d1[31:24] == 8'hBC);
    wire hit2 = (cand_k2 == 4'b1001) && (cand_d2[7:0] == 8'hBC) && (cand_d2[15:8] == 8'h28) && (cand_d2[31:24] == 8'hBC);
    wire hit3 = (cand_k3 == 4'b1001) && (cand_d3[7:0] == 8'hBC) && (cand_d3[15:8] == 8'h28) && (cand_d3[31:24] == 8'hBC);

    reg [1:0] rx_en_sync = 2'b00;
    always @(posedge clk2core_tx_2) begin
        rx_en_sync <= {rx_en_sync[0], rxlane_done_2};
    end

    reg [1:0]  rot;
    reg        rot_vld;
    reg [31:0] rxd_al;
    reg [3:0]  rxk_al;
    always @(posedge clk2core_tx_2) begin
        if (!rx_en_sync[1]) begin
            rot     <= 2'd0;
            rot_vld <= 1'b0;
        end
        else if (hit0) begin rot <= 2'd0; rot_vld <= 1'b1; end
        else if (hit1) begin rot <= 2'd1; rot_vld <= 1'b1; end
        else if (hit2) begin rot <= 2'd2; rot_vld <= 1'b1; end
        else if (hit3) begin rot <= 2'd3; rot_vld <= 1'b1; end
        case (hit0 ? 2'd0 : hit1 ? 2'd1 : hit2 ? 2'd2 : hit3 ? 2'd3 : rot)
            2'd0: begin rxd_al <= cand_d0; rxk_al <= cand_k0; end
            2'd1: begin rxd_al <= cand_d1; rxk_al <= cand_k1; end
            2'd2: begin rxd_al <= cand_d2; rxk_al <= cand_k2; end
            default: begin rxd_al <= cand_d3; rxk_al <= cand_k3; end
        endcase
    end

    assign o_rxd    = rxd_al;
    assign o_rxk    = rxk_al;
    assign o_rx_clk = clk2core_tx_2;
    assign o_rx_en  = rx_en_sync[1] & rot_vld;   // rx 时钟域

endmodule
