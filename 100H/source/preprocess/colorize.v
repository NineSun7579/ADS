//============================================================================
// colorize.v : 标准色化 —— 色度门限 + 色相分界 -> 纯红/黄/绿, 否则灰度
//   红灯 -> 16'hF800   黄灯 -> 16'hFFE0   绿灯 -> 16'h07E0
//   低饱和像素 -> 灰度RGB565 {Y[7:3],Y[7:2],Y[7:3]}
// 色相判定用比较器实现（等价于色相扇区划分，无乘除/无查表）：
//   R dominant: R-G>=THR_HUE 且 R-B>=THR_HUE        -> 红
//   G dominant: G-R>=THR_HUE 且 G-B>=THR_HUE        -> 绿
//   R≈G 且 双高 且 B 低: |R-G|<THR_HUE 且 R>=THR_VAL
//                     且 G>=THR_VAL 且 B<=THR_LOW   -> 黄
//   其余 -> 灰度
// 阈值全部为输入端口（由寄存器组驱动，PCIe 可标定）
//============================================================================
module colorize (
    input  wire        clk,
    input  wire        rst_n,
    // 阈值组（寄存器化）
    input  wire [7:0]  thr_sat,    // 色度门限: max-min < thr_sat 判为灰度
    input  wire [7:0]  thr_hue,    // 色相分界: 通道差 >= thr_hue 才判主色
    input  wire [7:0]  thr_val,    // 黄灯亮度下限
    input  wire [7:0]  thr_low,    // 黄灯蓝分量上限
    // 输入: RGB(延迟对齐后) + 灰度Y
    input  wire [15:0] s_rgb565,
    input  wire [7:0]  s_gray,
    input  wire        s_valid,
    // 输出 (延迟1拍)
    output reg  [15:0] m_rgb565,
    output reg  [1:0]  m_color_id, // 0=gray 1=red 2=yellow 3=green (调试/统计用)
    output reg         m_valid
);

    localparam [15:0] PURE_RED    = 16'hF800;
    localparam [15:0] PURE_YELLOW = 16'hFFE0;
    localparam [15:0] PURE_GREEN  = 16'h07E0;

    wire [4:0] r5 = s_rgb565[15:11];
    wire [5:0] g6 = s_rgb565[10:5];
    wire [4:0] b5 = s_rgb565[4:0];
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};

    wire [7:0] cmax = (r8 >= g8) ? ((r8 >= b8) ? r8 : b8)
                                 : ((g8 >= b8) ? g8 : b8);
    wire [7:0] cmin = (r8 <= g8) ? ((r8 <= b8) ? r8 : b8)
                                 : ((g8 <= b8) ? g8 : b8);
    wire [7:0] chroma = cmax - cmin;

    wire is_gray = (chroma < thr_sat);

    // 无符号减法先判大小再相减, 防回绕 (g8>r8 时 r8-g8 会下溢成大值)
    wire r_dom = (r8 >= g8) && ((r8 - g8) >= {1'b0,thr_hue})
               && (r8 >= b8) && ((r8 - b8) >= {1'b0,thr_hue});          // 红
    wire g_dom = (g8 >= r8) && ((g8 - r8) >= {1'b0,thr_hue})
               && (g8 >= b8) && ((g8 - b8) >= {1'b0,thr_hue});          // 绿
    wire y_dom = (|{r8[7:5]}) && (|{g8[7:5]})                    // R,G 均够亮
               && ((r8 > g8 ? (r8 - g8) : (g8 - r8)) < thr_hue)   // |R-G| 小
               && (b8 <= thr_low);                                // B 低
    // thr_val 由调用方折算进 thr_low 的比较基准（黄灯要求 R,G>=thr_val）
    wire y_dom2 = (r8 >= thr_val) && (g8 >= thr_val);

    reg [15:0] pix;
    reg [1:0]  cid;
    always @* begin
        if (is_gray) begin
            pix = {s_gray[7:3], s_gray[7:2], s_gray[7:3]};
            cid = 2'd0;
        end else if (r_dom) begin
            pix = PURE_RED;    cid = 2'd1;
        end else if (g_dom) begin
            pix = PURE_GREEN;  cid = 2'd3;
        end else if (y_dom && y_dom2) begin
            pix = PURE_YELLOW; cid = 2'd2;
        end else begin
            pix = {s_gray[7:3], s_gray[7:2], s_gray[7:3]};
            cid = 2'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_rgb565  <= 16'd0;
            m_color_id<= 2'd0;
            m_valid   <= 1'b0;
        end else begin
            m_rgb565  <= pix;
            m_color_id<= cid;
            m_valid   <= s_valid;
        end
    end

endmodule
