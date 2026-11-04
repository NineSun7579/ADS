//============================================================================
// prep_regs.v : 预处理/传输 扩展寄存器组 (AXI-Lite 从机, BAR 0x2000_0000 窗口)
// 字地址低 8 位译码, 基址偏移 +0x100 起:
//   +0x100 PREP_CTRL     RW  [0]旁路 [2:1]模式 [3]边缘叠加使能 [4]色化使能
//   +0x104 PREP_THR      RW  [7:0]边缘门限 [15:8]色度门限 [23:16]色相分界 [31:24]黄灯亮度下限
//   +0x108 PREP_SIZE     RW  [11:0]行宽 [27:16]行高
//   +0x10C PREP_LANE     RW  [7:0]ROI顶 [15:8]ROI底 [23:16]行命中门限 [31:24]虚实判别门限
//   +0x110 INJ_ADDR      W   注入帧 DDR 首址 (CH1)
//   +0x114 INJ_LEN       W   注入帧字节数
//   +0x118 INJ_FRAME_ID  W   注入帧序号 (RK3568 递增)
//   +0x11C INJ_CTRL      W   bit0=启动注入 bit4=清注入完成 (单拍)
//   +0x120 INJ_STATUS    RO  [0]busy [1]done [31:16]最近完成 FRAME_ID
//   +0x130 PIPE_STATUS   RO  [0]帧同步 [1]输出FIFO近满 [2]NPU忙 [15:8]输出帧计数
//   +0x140 BUTTON_STATUS RO   按键粘滞事件 (toggle 置位)
//   +0x144 BUTTON_EDGE   W1C 写1清粘滞位
//   +0x150 LED_CTRL      W   [3:0] LED
//   +0x160 LANE_RESULT   RO  [1:0]左线类型 [3:2]右线类型 [4]左有效 [5]右有效 [6]本帧已更新
//   +0x170~0x17C TS0~3   RO  四节点打点 (最新覆盖; 写 +0x17C 清零全部)
//   +0x1D0~0x1E4 DIAG    RO  [SFP_DIAG_EN] C5/C6 HTS,VTS,PLL (no producer in the 100H build)
//   +0x154~0x158 DIAG    RO  [SFP_DIAG_EN] C6 rows/frame, C6 line period (axi_clk cycles)
// 线型定义: 00=无 01=实线 10=虚线 11=未定
//============================================================================
module prep_regs #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter BTN_NUM        = 4,
    parameter TICK_DIV       = 50,           // 50MHz -> 1us 打点节拍
    parameter SFP_DIAG_EN    = 0
)(
    input  wire                          clk,
    input  wire                          rst_n,
    // AXI-Lite 从机
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,
    input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,
    output wire [1:0]                    s_axi_bresp,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready,
    output reg  [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                    s_axi_rresp,
    // ---- 预处理配置输出 (接 preprocess_top) ----
    output wire                          prep_bypass,
    output wire [1:0]                    prep_mode,
    output wire [11:0]                   prep_img_width,
    output wire [7:0]                    prep_thr_sat,
    output wire [7:0]                    prep_thr_hue,
    output wire [7:0]                    prep_thr_val,
    output wire [7:0]                    prep_thr_low,
    output wire [10:0]                   prep_thr_edge,
    output wire [7:0]                    prep_lane_roi_top,
    output wire [7:0]                    prep_lane_roi_bot,
    output wire [7:0]                    prep_lane_row_thr,
    output wire [7:0]                    prep_lane_dash_thr,
    input  wire                          lane_roi_awvalid,
    output wire                          lane_roi_awready,
    input  wire [31:0]                   lane_roi_awaddr,
    input  wire                          lane_roi_wvalid,
    output wire                          lane_roi_wready,
    input  wire [31:0]                   lane_roi_wdata,
    input  wire [3:0]                    lane_roi_wstrb,
    output wire                          lane_roi_bvalid,
    input  wire                          lane_roi_bready,
    input  wire                          lane_roi_arvalid,
    output wire                          lane_roi_arready,
    input  wire [31:0]                   lane_roi_araddr,
    output wire                          lane_roi_rvalid,
    input  wire                          lane_roi_rready,
    output wire [31:0]                   lane_roi_rdata,
    output wire                          lane_enable,
    output wire [7:0]                    lane_white_min,
    output wire [7:0]                    lane_white_span,
    output wire [7:0]                    lane_min_run,
    output wire [3:0]                    lane_line_width,
    input  wire [15:0]                   cam1_left_count,
    input  wire [15:0]                   cam1_right_count,
    input  wire [31:0]                   cam1_frame_sequence,
    input  wire                          cam1_left_valid,
    input  wire                          cam1_right_valid,
    input  wire [15:0]                   hdmi_left_count,
    input  wire [15:0]                   hdmi_right_count,
    input  wire [31:0]                   hdmi_frame_sequence,
    input  wire                          hdmi_left_valid,
    input  wire                          hdmi_right_valid,
    // ---- 注入通道 (CH1) ----
    output wire [31:0]                   inj_addr,
    output wire [31:0]                   inj_len,
    output wire [31:0]                   inj_frame_id,
    output wire                          inj_start,
    output wire                          inj_done_clr,
    input  wire                          inj_busy,
    input  wire                          inj_done,
    input  wire [15:0]                   inj_done_fid,
    // ---- 状态输入 (外部已同步到 clk 域) ----
    input  wire                          pipe_frame_sync,
    input  wire                          pipe_fifo_afull,
    input  wire                          npu_busy,
    input  wire [7:0]                    out_frame_cnt,
    input  wire [BTN_NUM-1:0]            btn_toggle_evt,
    input  wire [BTN_NUM-1:0]            btn_level_sync,
    output wire [BTN_NUM-1:0]            btn_sticky,
    output wire [BTN_NUM-1:0]            btn_sticky_clr,
    output wire [3:0]                    led_ctrl,
    input  wire [1:0]                    lane_left_type,
    input  wire [1:0]                    lane_right_type,
    input  wire                          lane_left_valid,
    input  wire                          lane_right_valid,
    input  wire                          lane_frame_upd,
    // ---- 四节点打点 ----
    input  wire                          ts_cap_pulse,
    input  wire                          ts_prep_pulse,
    input  wire                          ts_npu_pulse,
    input  wire                          ts_dma_pulse,
    output wire [31:0]                   ts_value0,
    output wire [31:0]                   ts_value1,
    output wire [31:0]                   ts_value2,
    output wire [31:0]                   ts_value3,
    // ---- [EDGE-DBG] read-only debug counters ----
    input  wire [31:0]                   dbg_pp_beats,
    input  wire [31:0]                   dbg_prep_aw,
    input  wire [31:0]                   dbg_prep_w,
    input  wire [31:0]                   dbg_prep_b,
    // Optional SFP diagnostics, already synchronized to clk.
    input  wire [31:0]                   sfp_diag_status,
    input  wire [31:0]                   sfp_diag_fault5,
    input  wire [31:0]                   sfp_diag_fault6,
    input  wire [31:0]                   sfp_diag_pixels5,
    input  wire [31:0]                   sfp_diag_pixels6,
    input  wire [31:0]                   sfp_diag_states,
    input  wire [1919:0]                 motion_records,
    input  wire [1151:0]                 motion_frame_metadata,
    input  wire [31:0]                   sfp_diag_rejects,
    // [DIAG 2026-10-22] Sensor readback + C6 line rate (SFP_DIAG_EN gated).
    // Unconnected inputs are harmless in builds that leave SFP_DIAG_EN=0: the
    // read mux then returns a constant 0, so no X can reach the host.
    input  wire [31:0]                   diag_c5_hts,
    input  wire [31:0]                   diag_c5_vts,
    input  wire [31:0]                   diag_c5_pll,
    input  wire [31:0]                   diag_c6_hts,
    input  wire [31:0]                   diag_c6_vts,
    input  wire [31:0]                   diag_c6_pll,
    input  wire [31:0]                   diag_c6_lines,
    input  wire [31:0]                   diag_c6_line_cycles
);

    //------------------------------------------------------------------
    // 寄存器本体与默认值 (720p, 中等阈值)
    //------------------------------------------------------------------
    reg        r_bypass;
    reg [1:0]  r_mode;
    reg        r_edge_en;
    reg        r_color_en;
    reg [7:0]  r_thr_edge, r_thr_sat, r_thr_hue, r_thr_val;
    reg [11:0] r_img_width, r_img_height;
    reg [7:0]  r_roi_top, r_roi_bot, r_row_thr, r_dash_thr;
    reg [31:0] r_inj_addr, r_inj_len, r_inj_fid;
    reg        r_inj_start, r_inj_clr;
    reg [3:0]  r_led;
    reg [BTN_NUM-1:0] r_btn_sticky_r;
    reg [BTN_NUM-1:0] r_btn_clr;
    reg [31:0] r_ts0, r_ts1, r_ts2, r_ts3;
    reg        r_ts_clr;

    localparam [7:0]  D_THR_EDGE = 8'd128;
    localparam [7:0]  D_THR_SAT  = 8'd96;
    localparam [7:0]  D_THR_HUE  = 8'd64;
    localparam [7:0]  D_THR_VAL  = 8'd160;
    localparam [11:0] D_WIDTH    = 12'd640;   // [EDGE 2026-09-13] VGA
    localparam [11:0] D_HEIGHT   = 12'd480;   // [EDGE 2026-09-13] VGA

    assign prep_bypass    = r_bypass;
    // 色化关 -> 强制灰度; 边缘关 -> 强制仅色化; 都开 -> 主机模式选择
    assign prep_mode      = !r_color_en ? 2'd2 : (!r_edge_en ? 2'd1 : r_mode);
    assign prep_img_width = r_img_width;
    assign prep_thr_sat   = r_thr_sat;
    assign prep_thr_hue   = r_thr_hue;
    assign prep_thr_val   = r_thr_val;
    assign prep_thr_low   = r_thr_val;
    assign prep_thr_edge  = {3'd0, r_thr_edge};
    assign prep_lane_roi_top  = r_roi_top;
    assign prep_lane_roi_bot  = r_roi_bot;
    assign prep_lane_row_thr  = r_row_thr;
    assign prep_lane_dash_thr = r_dash_thr;
    assign inj_addr       = r_inj_addr;
    assign inj_len        = r_inj_len;
    assign inj_frame_id   = r_inj_fid;
    assign inj_start      = r_inj_start;
    assign inj_done_clr   = r_inj_clr;
    assign btn_sticky     = r_btn_sticky_r;
    assign btn_sticky_clr = r_btn_clr;
    assign led_ctrl       = r_led;

    //------------------------------------------------------------------
    // AXI-Lite 写通道: 两地址/数据独立锁存, 双方到齐后执行写
    // (容忍 AW/W 任意先后, ready 单拍脉冲)
    //------------------------------------------------------------------
    reg aw_seen, w_seen;
    reg [AXI_ADDR_WIDTH-1:0] aw_addr;
    wire lane_aw = lane_roi_awaddr[31:8] == 24'h200001 && lane_roi_awaddr[7] &&
                   lane_roi_awaddr[7:4] < 4'hb;
    wire lane_ar = lane_roi_araddr[31:8] == 24'h200001 && lane_roi_araddr[7] &&
                   lane_roi_araddr[7:4] < 4'hb;
    wire wr_fire = aw_seen && w_seen;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            aw_seen       <= 1'b0;
            aw_addr       <= 0;
        end else begin
            s_axi_awready <= 1'b0;
            // if/else 互斥: fire 消费当前对时不接受新 AW, 避免同拍竞争
            // (板级 K/L 实测: 连续写流下同拍清 seen/置 seen 会双次执行或错位)
            if (wr_fire) aw_seen <= 1'b0;
            else if (~s_axi_awready && s_axi_awvalid && !lane_aw && !s_axi_bvalid && !aw_seen) begin
                s_axi_awready <= 1'b1;
                aw_addr       <= s_axi_awaddr;
                aw_seen       <= 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_wready <= 1'b0;
            w_seen       <= 1'b0;
        end else begin
            s_axi_wready <= 1'b0;
            if (wr_fire) w_seen <= 1'b0;
            else if (~s_axi_wready && s_axi_wvalid && !lane_aw && !s_axi_bvalid && !w_seen) begin
                s_axi_wready <= 1'b1;
                w_seen       <= 1'b1;
            end
        end
    end

    reg [AXI_ADDR_WIDTH-1:0] ar_addr;
    reg ar_accepted;
    wire [7:0] woff = aw_addr[7:0];
    wire motion_write_page = aw_addr[31:8] == 24'h20000b;
    wire motion_read_page = ar_addr[31:8] == 24'h20000b;
    reg [31:0] motion_wdata;
    reg [3:0] motion_wstrb;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin motion_wdata<=0; motion_wstrb<=0; end
        else if (~s_axi_wready && s_axi_wvalid && !lane_aw && !s_axi_bvalid && !w_seen) begin
            motion_wdata<=s_axi_wdata; motion_wstrb<=s_axi_wstrb;
        end
    end
    wire [31:0] motion_rdata;
    motion_register_bank u_motion_register_bank (
        .clk(clk), .rst_n(rst_n), .motion_records(motion_records),
        .frame_metadata(motion_frame_metadata),
        .wr_en(wr_fire && motion_write_page), .wr_offset(woff),
        .wr_data(motion_wdata), .wr_strb(motion_wstrb),
        .rd_offset(ar_addr[7:0]), .rd_data(motion_rdata));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_bypass <= 1'b0; r_mode <= 2'd3; r_edge_en <= 1'b1; r_color_en <= 1'b1;  // [EDGE] default = pure edge view
            r_thr_edge <= D_THR_EDGE; r_thr_sat <= D_THR_SAT;
            r_thr_hue  <= D_THR_HUE;  r_thr_val  <= D_THR_VAL;
            r_img_width <= D_WIDTH;   r_img_height <= D_HEIGHT;
            r_roi_top <= 8'd40; r_roi_bot <= 8'd90;
            r_row_thr <= 8'd3;  r_dash_thr <= 8'd6;
            r_inj_addr <= 32'h0600_0000; r_inj_len <= 32'd0; r_inj_fid <= 32'd0;
            r_inj_start <= 1'b0; r_inj_clr <= 1'b0;
            r_led <= 4'd0;
            r_btn_clr <= {BTN_NUM{1'b0}};
            r_ts_clr <= 1'b0;
            s_axi_bvalid <= 1'b0;
        end else begin
            r_inj_start <= 1'b0;                          // 单拍脉冲
            r_inj_clr   <= 1'b0;
            r_btn_clr   <= {BTN_NUM{1'b0}};
            r_ts_clr    <= 1'b0;
            if (wr_fire) begin
                if (!motion_write_page) case (woff)
                    8'h00: if (s_axi_wstrb[0]) begin      // +0x100
                        r_bypass   <= s_axi_wdata[0];
                        r_mode     <= s_axi_wdata[2:1];
                        r_edge_en  <= s_axi_wdata[3];
                        r_color_en <= s_axi_wdata[4];
                    end
                    8'h04: begin                          // +0x104
                        if (s_axi_wstrb[0]) r_thr_edge <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) r_thr_sat  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) r_thr_hue  <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) r_thr_val  <= s_axi_wdata[31:24];
                    end
                    8'h08: begin                          // +0x108
                        if (s_axi_wstrb[1]) r_img_width  <= s_axi_wdata[11:0];
                        if (s_axi_wstrb[3]) r_img_height <= s_axi_wdata[27:16];
                    end
                    8'h0C: begin                          // +0x10C
                        if (s_axi_wstrb[0]) r_roi_top  <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) r_roi_bot  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) r_row_thr  <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) r_dash_thr <= s_axi_wdata[31:24];
                    end
                    8'h10: r_inj_addr <= s_axi_wdata;     // +0x110
                    8'h14: r_inj_len  <= s_axi_wdata;     // +0x114
                    8'h18: r_inj_fid  <= s_axi_wdata;     // +0x118
                    8'h1C: begin                          // +0x11C
                        r_inj_start <= s_axi_wdata[0];
                        r_inj_clr   <= s_axi_wdata[4];
                    end
                    8'h44: r_btn_clr <= s_axi_wdata[BTN_NUM-1:0]; // +0x144
                    8'h50: r_led <= s_axi_wdata[3:0];     // +0x150
                    8'h7C: r_ts_clr <= 1'b1;              // +0x17C 写=清全部打点
                    default: ;
                endcase
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end
    assign s_axi_bresp = 2'b00;

    // 按键粘滞
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            r_btn_sticky_r <= {BTN_NUM{1'b0}};
        else begin
            for (i = 0; i < BTN_NUM; i = i + 1) begin
                if (btn_toggle_evt[i])     r_btn_sticky_r[i] <= 1'b1;
                else if (r_btn_clr[i])     r_btn_sticky_r[i] <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------
    // AXI-Lite 读通道 (地址锁存 -> rvalid 时数据已就绪)
    //------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            ar_addr       <= 0;
            ar_accepted   <= 1'b0;
        end else begin
            s_axi_arready <= 1'b0;
            ar_accepted <= ~s_axi_arready && s_axi_arvalid && !lane_ar && !s_axi_rvalid;
            if (~s_axi_arready && s_axi_arvalid && !lane_ar && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                ar_addr       <= s_axi_araddr;
            end
        end
    end

    // [DIAG 2026-10-22] Keep the C6 rate words alive: without this the read mux
    // folds them to the default value and the whole measurement is deleted.
    wire [31:0] diag_c6_lines_k /* synthesis syn_keep=1 */ = diag_c6_lines;
    wire [31:0] diag_c6_cycles_k /* synthesis syn_keep=1 */ = diag_c6_line_cycles;
    reg [31:0] rdata_mux;
    always @* begin
        if (motion_read_page) rdata_mux = motion_rdata;
        else case (ar_addr[7:0])
            8'h00: rdata_mux = {27'd0, r_color_en, r_edge_en, r_mode, r_bypass};
            8'h04: rdata_mux = {r_thr_val, r_thr_hue, r_thr_sat, r_thr_edge};
            8'h08: rdata_mux = {4'd0, r_img_height, 4'd0, r_img_width};
            8'h0C: rdata_mux = {r_dash_thr, r_row_thr, r_roi_bot, r_roi_top};
            8'h10: rdata_mux = r_inj_addr;
            8'h14: rdata_mux = r_inj_len;
            8'h18: rdata_mux = r_inj_fid;
            // Aligned +0x120..+0x180 reads only; write decode is unchanged.
            8'h20: rdata_mux = SFP_DIAG_EN ? sfp_diag_status : {inj_done_fid, 14'd0, inj_done, inj_busy};
            8'h30: rdata_mux = SFP_DIAG_EN ? sfp_diag_fault5 : {8'd0, out_frame_cnt, 5'd0, npu_busy,
                                pipe_fifo_afull, pipe_frame_sync};
            8'h40: rdata_mux = SFP_DIAG_EN ? sfp_diag_fault6 : {{(32-BTN_NUM){1'b0}}, r_btn_sticky_r};
            8'h44: rdata_mux = {{(32-BTN_NUM){1'b0}}, btn_level_sync};
            8'h50: rdata_mux = SFP_DIAG_EN ? sfp_diag_pixels5 : {28'd0, r_led};
            8'h60: rdata_mux = SFP_DIAG_EN ? sfp_diag_pixels6 : {lane_frame_upd, lane_left_valid, lane_right_valid,
                                2'b00, lane_right_type, lane_left_type};
            8'h70: rdata_mux = SFP_DIAG_EN ? sfp_diag_states : r_ts0;
            // [EDGE-DBG] link observability counters
            8'h80: rdata_mux = SFP_DIAG_EN ? sfp_diag_rejects : dbg_pp_beats;
            8'h84: rdata_mux = dbg_prep_aw;
            8'h88: rdata_mux = dbg_prep_w;
            8'h8C: rdata_mux = dbg_prep_b;
            8'h74: rdata_mux = r_ts1;
            8'h78: rdata_mux = r_ts2;
            8'h7C: rdata_mux = r_ts3;
            // [DIAG 2026-10-22] Sensor slots 0xD0..0xE4 = AXI 0x2000_01D0..0x1E4;
            // One 32-bit value per slot; SFP_DIAG_EN=0 reads back 0.
            8'hD0: rdata_mux = SFP_DIAG_EN ? diag_c5_hts   : 32'd0;
            8'hD4: rdata_mux = SFP_DIAG_EN ? diag_c5_vts   : 32'd0;
            8'hD8: rdata_mux = SFP_DIAG_EN ? diag_c5_pll   : 32'd0;
            8'hDC: rdata_mux = SFP_DIAG_EN ? diag_c6_hts   : 32'd0;
            8'hE0: rdata_mux = SFP_DIAG_EN ? diag_c6_vts   : 32'd0;
            8'hE4: rdata_mux = SFP_DIAG_EN ? diag_c6_pll   : 32'd0;
            8'h54: rdata_mux = SFP_DIAG_EN ? diag_c6_lines_k : 32'd0;
            8'h58: rdata_mux = SFP_DIAG_EN ? diag_c6_cycles_k : 32'd0;
            default: rdata_mux = 32'h0000_0000;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= 32'd0;
        end else begin
            if (ar_accepted && !lane_ar) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rdata  <= rdata_mux;      // ar_addr 已锁存, mux 值正确
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end
    assign s_axi_rresp = 2'b00;

    //------------------------------------------------------------------
    // 打点: 自由计数 (TICK_DIV 分频到 ~us) + 事件最新覆盖 + 主机清零
    //------------------------------------------------------------------
    reg [31:0] free_cnt;
    reg [5:0]  tick_div_cnt;
    wire       tick = (tick_div_cnt == TICK_DIV[5:0]-1'b1);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_div_cnt <= 6'd0;
            free_cnt     <= 32'd0;
        end else if (tick) begin
            tick_div_cnt <= 6'd0;
            free_cnt     <= free_cnt + 1'b1;
        end else begin
            tick_div_cnt <= tick_div_cnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_ts0 <= 32'd0; r_ts1 <= 32'd0; r_ts2 <= 32'd0; r_ts3 <= 32'd0;
        end else begin
            if (r_ts_clr) begin
                r_ts0 <= 32'd0; r_ts1 <= 32'd0; r_ts2 <= 32'd0; r_ts3 <= 32'd0;
            end else begin
                if (ts_cap_pulse)  r_ts0 <= free_cnt;
                if (ts_prep_pulse) r_ts1 <= free_cnt;
                if (ts_npu_pulse)  r_ts2 <= free_cnt;
                if (ts_dma_pulse)  r_ts3 <= free_cnt;
            end
        end
    end
    assign ts_value0 = r_ts0;
    assign ts_value1 = r_ts1;
    assign ts_value2 = r_ts2;
    assign ts_value3 = r_ts3;

    wire lane_awready, lane_wready, lane_bvalid, lane_arready, lane_rvalid;
    wire [31:0] lane_rdata;
    assign lane_roi_awready = lane_aw ? lane_awready : s_axi_awready;
    assign lane_roi_wready = lane_aw ? lane_wready : s_axi_wready;
    assign lane_roi_arready = lane_ar ? lane_arready : s_axi_arready;
    assign lane_roi_bvalid = s_axi_bvalid || lane_bvalid;
    assign lane_roi_rvalid = s_axi_rvalid || lane_rvalid;
    assign lane_roi_rdata = lane_rvalid ? lane_rdata : s_axi_rdata;
    lane_roi_regs u_lane_roi_regs (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awvalid(lane_roi_awvalid && lane_aw), .s_axi_awready(lane_awready),
        .s_axi_awaddr(lane_roi_awaddr), .s_axi_wvalid(lane_roi_wvalid && lane_aw),
        .s_axi_wready(lane_wready), .s_axi_wdata(lane_roi_wdata),
        .s_axi_wstrb(lane_roi_wstrb), .s_axi_bvalid(lane_bvalid),
        .s_axi_bready(lane_roi_bready),
        .s_axi_arvalid(lane_roi_arvalid && lane_ar), .s_axi_arready(lane_arready),
        .s_axi_araddr(lane_roi_araddr), .s_axi_rvalid(lane_rvalid),
        .s_axi_rready(lane_roi_rready), .s_axi_rdata(lane_rdata),
        .lane_enable(lane_enable), .lane_white_min(lane_white_min),
        .lane_white_span(lane_white_span), .lane_min_run(lane_min_run),
        .lane_line_width(lane_line_width),
        .cam1_left_count(cam1_left_count), .cam1_right_count(cam1_right_count),
        .cam1_frame_sequence(cam1_frame_sequence),
        .cam1_left_valid(cam1_left_valid), .cam1_right_valid(cam1_right_valid),
        .hdmi_left_count(hdmi_left_count), .hdmi_right_count(hdmi_right_count),
        .hdmi_frame_sequence(hdmi_frame_sequence),
        .hdmi_left_valid(hdmi_left_valid), .hdmi_right_valid(hdmi_right_valid)
    );

endmodule
