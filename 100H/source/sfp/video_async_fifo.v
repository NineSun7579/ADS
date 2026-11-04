`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company : Meyesemi demo modified
// Module  : video_async_fifo
// Description : 双时钟域异步 FIFO (独立读写时钟, 格雷码指针两级同步)
//   结构参照 Cummings 异步 FIFO: full/empty 为寄存器输出, 判空/判满在
//   各自时钟域用同步后的格雷码指针比较, 无组合环路。组合式异步读 (LUTRAM)。
//////////////////////////////////////////////////////////////////////////////////
`define UD #1

module video_async_fifo #(
    parameter WIDTH = 19,                 // 数据位宽
    parameter DEPTH = 512                 // 必须为 2 的幂
)(
    // 写侧
    input                    wr_clk     ,
    input                    wr_rst_n   ,
    input                    wr_en      ,
    input  [WIDTH-1:0]       wr_data    ,
    output reg               full       ,
    // 读侧
    input                    rd_clk     ,
    input                    rd_rst_n   ,
    input                    rd_en      ,
    output     [WIDTH-1:0]   rd_data    ,
    output reg               empty
);
    localparam AW = $clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // 二进制指针 (含回卷位, 位宽 AW+1) 及其次态
    reg  [AW:0] wbin, rbin;
    reg  [AW:0] wbin_next, rbin_next;
    reg  [AW:0] wgray_next, rgray_next;
    // 格雷码指针及跨域两级同步寄存器
    reg  [AW:0] wptr, rptr;               // 本域格雷码指针
    reg  [AW:0] wptr_rd1, wptr_rd2;       // 写指针 -> 读侧同步
    reg  [AW:0] rptr_wr1, rptr_wr2;       // 读指针 -> 写侧同步

    wire [AW-1:0] waddr = wbin[AW-1:0];
    wire [AW-1:0] raddr = rbin[AW-1:0];

    assign rd_data = mem[raddr];          // 组合异步读 (LUTRAM)

    // 格雷码转换
    function [AW:0] bin2gray;
        input [AW:0] b;
        bin2gray = (b >> 1) ^ b;
    endfunction

    //--------------------------------------------------------------------------
    // 写侧
    //--------------------------------------------------------------------------
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wbin <= `UD {(AW+1){1'b0}};
            wptr <= `UD {(AW+1){1'b0}};
            full <= `UD 1'b0;
        end
        else begin
            wbin_next  = wbin + (wr_en & ~full);
            wbin       <= `UD wbin_next;
            wgray_next = bin2gray(wbin_next);
            wptr       <= `UD wgray_next;
            full       <= `UD (wgray_next == {~rptr_wr2[AW:AW-1], rptr_wr2[AW-2:0]});
        end
    end

    always @(posedge wr_clk) begin
        if (wr_en & ~full)
            mem[waddr] <= `UD wr_data;
    end

    // 读指针 -> 写侧同步 (2 级)
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rptr_wr1 <= `UD {(AW+1){1'b0}};
            rptr_wr2 <= `UD {(AW+1){1'b0}};
        end
        else begin
            rptr_wr1 <= `UD rptr;
            rptr_wr2 <= `UD rptr_wr1;
        end
    end

    //--------------------------------------------------------------------------
    // 读侧
    //--------------------------------------------------------------------------
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rbin  <= `UD {(AW+1){1'b0}};
            rptr  <= `UD {(AW+1){1'b0}};
            empty <= `UD 1'b1;
        end
        else begin
            rbin_next  = rbin + (rd_en & ~empty);
            rbin       <= `UD rbin_next;
            rgray_next = bin2gray(rbin_next);
            rptr       <= `UD rgray_next;
            empty      <= `UD (rgray_next == wptr_rd2);
        end
    end

    // 写指针 -> 读侧同步 (2 级)
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wptr_rd1 <= `UD {(AW+1){1'b0}};
            wptr_rd2 <= `UD {(AW+1){1'b0}};
        end
        else begin
            wptr_rd1 <= `UD wptr;
            wptr_rd2 <= `UD wptr_rd1;
        end
    end

endmodule
