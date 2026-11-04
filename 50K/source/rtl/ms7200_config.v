`timescale 1ns/1ps
// RX-only wrapper around the supplied demo register sequencer and IIC driver.
// reset_n also holds the physical MS7200 reset pin low in camera mode.
module ms7200_config(input clk, input reset_n, output init_done,
                     output scl, inout sda);
    wire rst_n;
    video_reset_sync u_reset(clk,reset_n,rst_n);
    wire [7:0] device_id, data_in, data_out;
    wire [15:0] addr;
    wire trig, w_r, busy, byte_over, sda_in, sda_out, sda_en;
    ms7200_ctl u_ctl(.clk(clk),.rstn(rst_n),.init_over(init_done),
        .device_id(device_id),.iic_trig(trig),.w_r(w_r),.addr(addr),
        .data_in(data_in),.busy(busy),.data_out(data_out),.byte_over(byte_over));
    iic_dri #(.CLK_FRE(27'd10000000),.IIC_FREQ(20'd400000),.T_WR(10'd1),
              .ADDR_BYTE(2'd2),.LEN_WIDTH(8'd3),.DATA_BYTE(2'd1)) u_iic(
        .clk(clk),.rstn(rst_n),.device_id(device_id),.pluse(trig),.w_r(w_r),
        .byte_len(4'd1),.addr(addr),.data_in(data_in),.busy(busy),
        .byte_over(byte_over),.data_out(data_out),.scl(scl),.sda_in(sda_in),
        .sda_out(sda_out),.sda_out_en(sda_en));
    // Open drain: never drive the SDA wire high.
    assign sda = sda_en && !sda_out ? 1'b0 : 1'bz;
    assign sda_in = sda;
endmodule
