//============================================================================
// sobel_edge.v : 3x3 Sobel 边缘检测（作用于灰度分量）+ 门限二值化
//   Gx = |-1 0 1; -2 0 2; -1 0 1|  Gy = |-1 -2 -1; 0 0 0; 1 2 1|
//   mag = |Gx| + |Gy| (近似梯度幅值, 上限 1020)
//   edge = (mag >= thr_edge)
// 像素按栅格顺序 valid 打点流入，行消隐间隔被计数器自然吸收。
// 窗口数据流: line0(最旧行)->line1->当前输入。col 独立回绕计数。
// 输出 (m_edge, m_center) 对应当前窗口中心像素 w11，帧首尾各留 1 行/1 列边界。
// 注意: 本模块的移位/计数结构与 align16.v 严格一致，二者输出天然逐像素对齐。
//============================================================================
module sobel_edge #(
    parameter MAX_WIDTH = 1920,
    parameter AW        = 11                           // 列地址位宽 (2048>1920)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] img_width,                     // 寄存器化: 有效行宽
    input  wire [10:0] thr_edge,                      // 寄存器化: 二值化门限
    // 灰度流输入
    input  wire [7:0]  s_gray,
    input  wire        s_valid,
    input  wire        s_frame_sync,                  // 帧起始脉冲, 清窗口
    // 输出: 与输入一一对应 (整流滞后 2行+常数拍)
    output reg         m_edge,
    output reg  [7:0]  m_center,                      // 窗口中心灰度(级联用)
    output reg         m_valid
);

    reg [7:0] line0 [0:MAX_WIDTH-1];
    reg [7:0] line1 [0:MAX_WIDTH-1];

    reg [21:0] pix_cnt;                               // 本帧像素累计
    reg [AW-1:0] col;                                 // 列计数, 独立回绕

    wire [11:0] w_m1   = img_width - 12'd1;
    wire        col_wr = (col >= w_m1[AW-1:0]);
    reg  [11:0] row;                       // [EDGE-INT] input row index
    // 中心像素列 = (col - 2) mod W (中心滞后当前像素 W+2 个)
    wire [AW-1:0] ccol   = (col >= 2) ? (col - 2'd2) : (col + w_m1[AW-1:0] - 1'd1);
    // 窗口数据就绪 + 中心列在内部区域 (排除跨行边界窗口)
    // [EDGE-INT] full-frame output: emit one beat per input pixel; window centre=(row-1,col-1),
    // edge only when window fully inside frame (row>=2 and col>=2), else black.
    wire        win_ok = (row >= 12'd2) && (col >= 2'd2);
    wire        ready  = 1'b1;                    // keep legacy ready semantics: always 1

    reg [7:0] w00,w01,w02, w10,w11,w12, w20,w21,w22;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col      <= 0;
            row      <= 0;
            pix_cnt  <= 0;
            {w00,w01,w02,w10,w11,w12,w20,w21,w22} <= 96'd0;
        end else if (s_frame_sync) begin
            col      <= 0;
            row      <= 0;
            pix_cnt  <= 0;
        end else if (s_valid) begin
            col      <= col_wr ? {AW{1'b0}} : col + 1'b1;
            row      <= col_wr ? (row + 12'd1) : row;
            pix_cnt  <= pix_cnt + 1'b1;
            // 行内左移, 最新列进入右端 w02/w12/w22 (窗口=中心±1列)
            w00<=w01; w01<=w02; w02<=line0[col];
            w10<=w11; w11<=w12; w12<=line1[col];
            w20<=w21; w21<=w22; w22<=s_gray;
        end
    end

    always @(posedge clk) begin
        if (s_valid) begin
            line0[col] <= line1[col];
            line1[col] <= s_gray;
        end
    end

    // 卷积: 窗口移位同拍组合计算 (ready 为移位前判断, 对应移位前窗口)
    // 注意: 2倍项用显式乘法 (Verilog 里 {2'b0,w} 是拼接不是乘2!)
    wire signed [10:0] gx = -( $signed({1'b0,w00}) ) + ( $signed({1'b0,w02}) )
                           - 2*( $signed({1'b0,w10}) ) + 2*( $signed({1'b0,w12}) )
                           - ( $signed({1'b0,w20}) ) + ( $signed({1'b0,w22}) );
    wire signed [10:0] gy = -( $signed({1'b0,w00}) ) - 2*( $signed({1'b0,w01}) )
                           - ( $signed({1'b0,w02}) )
                           + ( $signed({1'b0,w20}) ) + 2*( $signed({1'b0,w21}) )
                           + ( $signed({1'b0,w22}) );

    // 取绝对值(11bit 位模式取反加一, 恒为正)后升 12bit 无符号相加: 上限 2040 不溢出
    wire [10:0] gx_abs = gx[10] ? (~gx + 1'b1) : gx;
    wire [10:0] gy_abs = gy[10] ? (~gy + 1'b1) : gy;
    wire [11:0] mag = {1'b0, gx_abs} + {1'b0, gy_abs};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_edge   <= 1'b0;
            m_center <= 8'd0;
            m_valid  <= 1'b0;
        end else if (s_frame_sync) begin
            m_valid  <= 1'b0;
        end else begin
            m_valid <= s_valid;                       // [EDGE-INT] 1:1 full-frame output              // 输出与窗口移位同步打点
            if (s_valid) begin
                m_edge   <= win_ok && (mag >= {1'b0,thr_edge});  // [EDGE-INT] no edge outside frame
                m_center <= w11;
            end
        end
    end

endmodule
