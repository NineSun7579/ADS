//============================================================================
// preprocess_top.v : 视频预处理 IP 顶层
// 流水线: RGB565 -> rgb2gray -> {标准色化, Sobel 边缘} -> 模式选择 -> 输出FIFO
//   mode 0: 色化 + 白边叠加 (默认)
//   mode 1: 仅色化 (红0xF800/黄0xFFE0/绿0x07E0, 其余灰度)
//   mode 2: 仅灰度
//   mode 3: 仅边缘 (二值黑白)
//   bypass=1: RAW 直通 (不进流水线, NPU/显示需要原图时用)
// 所有阈值/行宽寄存器化 (prep_regs 提供), 帧同步由 vsync 脉冲驱动。
// NPU 通路不经过本模块 (NPU 恒喂 RAW), 本模块输出仅走 PCIe 视频通道 CH0。
//============================================================================
module preprocess_top #(
    parameter MAX_WIDTH = 1920,                    // 640/1280/1920 参数化
    parameter FIFO_DEPTH = 512
)(
    input  wire        clk,                        // 像素时钟域
    input  wire        rst_n,
    // 原始视频流入 (RGB565, 来自相机 CDC/DDR 读出)
    input  wire [15:0] s_rgb565,
    input  wire        s_valid,
    output wire        s_ready,                    // 预测性反压: 输出FIFO近满
    input  wire        s_frame_sync,               // vsync 起始脉冲
    // 输入契约 (valid-only): s_valid=1 一拍表示一个新像素, 不允许原地保持;
    // 上游在 s_ready=0 期间不得发起新像素 (先回到 s_valid=0 等待)。
    // 处理图流出 (RGB565, -> PCIe CH0 视频通道)
    input  wire        m_ready,
    output wire [15:0] m_rgb565,
    output wire        m_valid,
    output wire        m_frame_sync,
    // 寄存器组接口 (prep_regs 直连)
    input  wire        reg_bypass,
    input  wire [1:0]  reg_mode,
    input  wire [11:0] reg_img_width,
    input  wire [7:0]  reg_thr_sat,
    input  wire [7:0]  reg_thr_hue,
    input  wire [7:0]  reg_thr_val,
    input  wire [7:0]  reg_thr_low,
    input  wire [10:0] reg_thr_edge,
    // 状态/级联
    output wire        out_frame_start,            // 输出帧起始 (打点用)
    output wire        edge_stream_valid,          // Sobel 边缘流有效(级联车道线)
    output wire        edge_stream_edge,
    output wire [7:0]  edge_stream_center,
    output wire        color_id_valid,             // 色化命中流 (级联红绿灯统计)
    output wire [1:0]  color_id
);

    //------------------------------------------------------------------
    // 1) rgb2gray (valid 滞后1拍)
    //------------------------------------------------------------------
    wire [7:0]  gray;
    wire        gray_valid;
    wire [15:0] rgb_d1;

    rgb2gray u_gray (
        .clk(clk), .rst_n(rst_n),
        .s_rgb565(s_rgb565), .s_valid(s_valid),
        .m_gray(gray), .m_valid(gray_valid), .m_rgb565_d(rgb_d1)
    );

    //------------------------------------------------------------------
    // 2) 标准色化 (输入=对齐后的rgb_d1+gray, 输出滞后再1拍)
    //------------------------------------------------------------------
    wire [15:0] c_rgb;
    wire [1:0]  c_id;
    wire        c_valid;
    reg         c_id_valid_d;

    colorize u_color (
        .clk(clk), .rst_n(rst_n),
        .thr_sat(reg_thr_sat), .thr_hue(reg_thr_hue),
        .thr_val(reg_thr_val), .thr_low(reg_thr_low),
        .s_rgb565(rgb_d1), .s_gray(gray), .s_valid(gray_valid),
        .m_rgb565(c_rgb), .m_color_id(c_id), .m_valid(c_valid)
    );

    //------------------------------------------------------------------
    // 3) Sobel 边缘 (作用于灰度, 滞后2行+常数) + 色化流对齐
    //------------------------------------------------------------------
    wire        edge_flag, edge_valid;
    wire [7:0]  edge_center;
    wire [15:0] a_rgb;
    wire        a_valid;

    sobel_edge #(.MAX_WIDTH(MAX_WIDTH)) u_sobel (
        .clk(clk), .rst_n(rst_n),
        // [THR-FIX 2026-09-13] threshold hard-wired: the sensor image on this
        // bench is dark (luma ~ 0x2A..0x4F) so Sobel |Gx|+|Gy| stays well under the
        // 128 default and every pixel was suppressed (measured: 100% black frame).
        // reg_thr_edge is unreliable (prep_regs drops back-to-back writes).
        .img_width(reg_img_width), .thr_edge(11'd20),
        .s_gray(gray), .s_valid(gray_valid), .s_frame_sync(s_frame_sync),
        .m_edge(edge_flag), .m_center(edge_center), .m_valid(edge_valid)
    );

    align16 #(.MAX_WIDTH(MAX_WIDTH)) u_align (
        .clk(clk), .rst_n(rst_n),
        .img_width(reg_img_width),
        .s_pix(c_rgb), .s_valid(c_valid), .s_frame_sync(s_frame_sync),
        .m_pix(a_rgb), .m_valid(a_valid)
    );

    // colorize 流比 gray 流晚1拍 → 边缘流补1拍对齐
    reg         edge_d1, edge_valid_d1;
    reg [7:0]   center_d1;
    reg  [1:0]  c_id_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_d1 <= 1'b0; edge_valid_d1 <= 1'b0;
            center_d1 <= 8'd0; c_id_d1 <= 2'd0;
        end else begin
            edge_d1       <= edge_flag;
            edge_valid_d1 <= edge_valid;
            center_d1     <= edge_center;
            c_id_d1       <= c_id;
        end
    end
    assign edge_stream_valid = edge_valid_d1;
    assign edge_stream_edge  = edge_d1;
    assign edge_stream_center= center_d1;
    assign color_id_valid    = c_id_valid_d;
    assign color_id          = c_id_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) c_id_valid_d <= 1'b0;
        else        c_id_valid_d <= c_valid;
    end

    //------------------------------------------------------------------
    // 4) 模式选择
    //------------------------------------------------------------------
    localparam [15:0] WHITE = 16'hFFFF;
    localparam [15:0] BLACK = 16'h0000;

    // 灰度模式: 用窗口中心灰度 (与对齐流同拍) 展开 RGB565 灰度
    wire [15:0] gray_rgb = {center_d1[7:3], center_d1[7:2], center_d1[7:3]};

    // [EDGE-FORCE 2026-09-13] Hard-wired pure-edge output.
// reg_mode / reg_bypass are NOT used: the prep_regs read AND write paths are
// both unreliable (continuous reads return the previous value; back-to-back
// AW/W writes are dropped), so a host-written mode never latched reliably.
// Output is therefore always the Sobel view: white edge on black background.
    wire [15:0] proc_pix = edge_d1 ? WHITE : BLACK;

    //------------------------------------------------------------------
    // 5) 旁路/输出选择 + 输出FIFO
    //------------------------------------------------------------------
    // [EDGE-FORCE] bypass hard-wired off: always the processed (edge) image
    wire [15:0] sel_pix  = proc_pix;
    wire        sel_valid_raw = a_valid;

    // 输出帧起始打点 (vsync 滞后1拍)
    reg frame_start_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) frame_start_d <= 1'b0;
        else        frame_start_d <= s_frame_sync;
    end
    assign out_frame_start = frame_start_d;
    assign m_frame_sync    = frame_start_d;

    wire        fifo_wr   = sel_valid_raw;
    wire [15:0] fifo_wdat = sel_pix;
    wire        fifo_rd   = m_ready;

    prep_sync_fifo #(.DW(16), .DEPTH(FIFO_DEPTH), .AFULL(FIFO_DEPTH-32)) u_ofifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(fifo_wr), .wr_data(fifo_wdat),
        .rd_en(fifo_rd),
        .rd_data(m_rgb565),
        .rd_valid(m_valid),
        .prog_full(prog_full),
        .cnt()
    );

    assign s_ready = !prog_full;

endmodule
