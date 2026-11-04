`timescale 1ns/1ps
// Adapted from migration raw_preprocess/fpga_v8_raw_letterbox.v.
module delivery_raw_letterbox #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,
    parameter integer OUT_HEIGHT = 640,
    parameter integer TOP_ROWS = 80,
    parameter integer FILL_VALUE = 114
) (
    input wire clk, rst_n, start_valid,
    output wire start_ready,
    output reg busy, done, frame_error,
    output wire config_error,
    input wire [15:0] s_data,
    input wire s_valid,
    output wire s_ready,
    input wire s_last,
    output reg [23:0] m_data,
    output reg m_valid,
    input wire m_ready,
    output reg m_last
);
    localparam CONFIG_OK = (WIDTH >= 1) && (WIDTH <= 65535) &&
        (HEIGHT >= 1) && (HEIGHT <= 65535) &&
        (OUT_HEIGHT >= HEIGHT) && (OUT_HEIGHT <= 65535) &&
        (TOP_ROWS >= 0) && (TOP_ROWS <= OUT_HEIGHT - HEIGHT) &&
        (FILL_VALUE >= 0) && (FILL_VALUE <= 255);
    reg [15:0] column, row;
    reg generated_all;
    wire body_row = (row >= TOP_ROWS) && (row < TOP_ROWS + HEIGHT);
    wire output_slot = !m_valid || m_ready;
    wire final_source = (column == WIDTH - 1) && (row == TOP_ROWS + HEIGHT - 1);
    wire final_output = (column == WIDTH - 1) && (row == OUT_HEIGHT - 1);
    wire [23:0] expanded = {s_data[4:0], s_data[4:2],
        s_data[10:5], s_data[10:9], s_data[15:11], s_data[15:13]};
    assign config_error = !CONFIG_OK;
    assign start_ready = rst_n && CONFIG_OK && !busy;
    assign s_ready = rst_n && busy && !generated_all && body_row && output_slot;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy<=0; done<=0; frame_error<=0; column<=0; row<=0;
            generated_all<=0; m_data<=0; m_valid<=0; m_last<=0;
        end else begin
            done<=0;
            if (start_valid && start_ready) begin
                busy<=1; frame_error<=0; column<=0; row<=0;
                generated_all<=0; m_valid<=0; m_last<=0;
            end else if (busy) begin
                if (m_valid && m_ready && m_last) begin busy<=0; done<=1; end
                if (output_slot) begin
                    m_valid<=0; m_last<=0;
                    if (!generated_all && (!body_row || s_valid)) begin
                        m_data<=body_row ? expanded : {3{FILL_VALUE[7:0]}};
                        m_valid<=1; m_last<=final_output;
                        if (body_row && (s_last != final_source)) frame_error<=1;
                        if (final_output) generated_all<=1;
                        if (column==WIDTH-1) begin column<=0; row<=row+1; end
                        else column<=column+1;
                    end
                end
            end
        end
    end
endmodule
