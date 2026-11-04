//============================================================================
// align16.v : 16bit 像素流 2 行延迟对齐线
// 移位/计数结构与 sobel_edge.v 严格一致（同 col 回绕、同 ready 门限、同打点），
// 输出 w11 即 sobel 窗口中心像素的同位置数据 → 两路输出逐像素对齐。
// 用途: 将色化后的 RGB 流延迟到与 Sobel 边缘流同步, 供白边叠加。
//============================================================================
module align16 #(
    parameter MAX_WIDTH = 1920,
    parameter AW        = 11
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] img_width,
    input  wire [15:0] s_pix,
    input  wire        s_valid,
    input  wire        s_frame_sync,
    output reg  [15:0] m_pix,
    output reg         m_valid
);

    reg [15:0] line0 [0:MAX_WIDTH-1];
    reg [15:0] line1 [0:MAX_WIDTH-1];

    reg [21:0]  pix_cnt;
    reg [AW-1:0] col;
    reg [11:0]  row;                      // [EDGE-INT]
    wire [11:0] w_m1   = img_width - 12'd1;
    wire        col_wr = (col >= w_m1[AW-1:0]);
    // 与 sobel_edge.v 完全一致的 fire 条件 (含中心列内部判定)
    wire [AW-1:0] ccol   = (col >= 2) ? (col - 2'd2) : (col + w_m1[AW-1:0] - 1'd1);
    // [EDGE-INT] same structure as sobel_edge: always-on, full W x H
    wire        ready  = 1'b1;

    reg [15:0] w00,w01,w02, w10,w11,w12, w20,w21,w22;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col     <= 0;
            row     <= 0;
            pix_cnt <= 0;
            {w00,w01,w02,w10,w11,w12,w20,w21,w22} <= 144'd0;
        end else if (s_frame_sync) begin
            col     <= 0;
            row     <= 0;
            pix_cnt <= 0;
        end else if (s_valid) begin
            col     <= col_wr ? {AW{1'b0}} : col + 1'b1;
            row     <= col_wr ? (row + 12'd1) : row;
            pix_cnt <= pix_cnt + 1'b1;
            // 与 sobel_edge.v 严格同构 (最新列进右端)
            w00<=w01; w01<=w02; w02<=line0[col];
            w10<=w11; w11<=w12; w12<=line1[col];
            w20<=w21; w21<=w22; w22<=s_pix;
        end
    end

    always @(posedge clk) begin
        if (s_valid) begin
            line0[col] <= line1[col];
            line1[col] <= s_pix;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_pix   <= 16'd0;
            m_valid <= 1'b0;
        end else if (s_frame_sync) begin
            m_valid <= 1'b0;
        end else begin
            m_valid <= s_valid;                    // [EDGE-INT] 1:1 full frame
            if (s_valid)
                m_pix <= w11;
        end
    end

endmodule
