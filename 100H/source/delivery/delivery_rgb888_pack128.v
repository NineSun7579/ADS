`timescale 1ns/1ps
// Adapted from migration raw_preprocess/fpga_v8_rgb888_pack128.v.
module delivery_rgb888_pack128 (
    input wire clk, rst_n,
    input wire [23:0] s_data,
    input wire s_valid,
    output wire s_ready,
    input wire s_last,
    output reg [127:0] m_data,
    output reg [15:0] m_keep,
    output reg m_valid,
    input wire m_ready,
    output reg m_last
);
    reg [127:0] carry_bytes;
    reg [4:0] byte_count;
    reg flush_pending;
    wire output_slot = !m_valid || m_ready;
    wire [143:0] appended = {16'd0, carry_bytes} |
        ({120'd0, s_data} << (byte_count * 8));
    wire [5:0] appended_count = {1'b0, byte_count} + 6'd3;
    wire [15:0] partial_keep = (16'hffff >> (16 - appended_count));
    assign s_ready = rst_n && output_slot && !flush_pending && !(m_valid && m_last);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            carry_bytes<=0; byte_count<=0; flush_pending<=0;
            m_data<=0; m_keep<=0; m_valid<=0; m_last<=0;
        end else if (output_slot) begin
            m_valid<=0; m_last<=0; m_keep<=0;
            if (flush_pending) begin
                m_data<=carry_bytes; m_keep<=(16'hffff >> (16-byte_count));
                m_valid<=1; m_last<=1; carry_bytes<=0; byte_count<=0;
                flush_pending<=0;
            end else if (s_valid && s_ready) begin
                if (appended_count>=16) begin
                    m_data<=appended[127:0]; m_keep<=16'hffff; m_valid<=1;
                    m_last<=s_last && (appended_count==16);
                    carry_bytes<={112'd0,appended[143:128]};
                    byte_count<=appended_count-16;
                    flush_pending<=s_last && (appended_count!=16);
                end else if (s_last) begin
                    m_data<=appended[127:0]; m_keep<=partial_keep;
                    m_valid<=1; m_last<=1; carry_bytes<=0; byte_count<=0;
                end else begin
                    carry_bytes<=appended[127:0]; byte_count<=appended_count[4:0];
                end
            end
        end
    end
endmodule
