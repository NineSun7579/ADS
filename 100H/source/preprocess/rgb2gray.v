//============================================================================
// rgb2gray.v : RGB565 -> 8bit 灰度 (BT.601 整数近似 Y=(77R+150G+29B)>>8)
// 纯组合+1级寄存器，随valid流水，无反压
//============================================================================
module rgb2gray (
    input  wire        clk,
    input  wire        rst_n,
    // 像素流入 (RGB565)
    input  wire [15:0] s_rgb565,
    input  wire        s_valid,
    // 灰度流出 (延迟1拍)
    output reg  [7:0]  m_gray,
    output reg         m_valid,
    // 原始像素同步延迟1拍输出（供色化级做RGB对齐）
    output reg  [15:0] m_rgb565_d
);

    wire [4:0] r5 = s_rgb565[15:11];
    wire [5:0] g6 = s_rgb565[10:5];
    wire [4:0] b5 = s_rgb565[4:0];

    // 扩展到8bit (高位复制惯例): R = {r5,r5[4:2]}, G = {g6,g6[5:4]}, B = {b5,b5[4:2]}
    wire [7:0] r8 = {r5, r5[4:2]};
    wire [7:0] g8 = {g6, g6[5:4]};
    wire [7:0] b8 = {b5, b5[4:2]};

    // Y = (77*R + 150*G + 29*B) >> 8, 系数和=256 保证不饱和
    wire [15:0] y_sum = 8'd77 * r8 + 8'd150 * g8 + 8'd29 * b8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_gray    <= 8'd0;
            m_valid   <= 1'b0;
            m_rgb565_d<= 16'd0;
        end else begin
            m_gray    <= y_sum[15:8];
            m_valid   <= s_valid;
            m_rgb565_d<= s_rgb565;
        end
    end

endmodule
