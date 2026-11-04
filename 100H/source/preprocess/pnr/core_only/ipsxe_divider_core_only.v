
//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2022 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////

module ipsxe_divider_core_only#(

    parameter DIVIDEND_WIDTH = 64,

    parameter ROUNDED_DIVIDEND_WIDTH = (DIVIDEND_WIDTH + 7) / 8 * 8,

    parameter DIVISOR_WIDTH = 64,

    parameter ROUNDED_DIVISOR_WIDTH = (DIVISOR_WIDTH + 7) / 8 * 8,

    parameter DIVIDEND_TUSER_WIDTH = 1,

    parameter DIVISOR_TUSER_WIDTH = 1,

    parameter QUOTIENT_FRACTIONAL_WIDTH = 0,

    parameter DIVISOR_BY_ZERO = 0 ,

    parameter DIVIDEND_TUSER = 0 ,

    parameter DIVISOR_TUSER = 0 ,

    parameter DIVIDEND_TLAST = 0 ,

    parameter DIVISOR_TLAST = 0 ,

    parameter TUSER = 0 ,

    parameter TLAST = 0 ,

    parameter OUTPUT_TREADY = 0 ,

    parameter BLOCKING = 0 ,

    parameter TUSER_WIDTH = DIVIDEND_TUSER_WIDTH + DIVISOR_TUSER_WIDTH + DIVISOR_BY_ZERO,

    parameter   DOUT_TDATA_QUOTIENT = (DIVIDEND_WIDTH<=8)?8:((DIVIDEND_WIDTH>(DIVIDEND_WIDTH>>3)*8)?
    ((DIVIDEND_WIDTH>>3)+1)*8:(DIVIDEND_WIDTH>>3)*8),

    parameter  DOUT_TDATA_REMAINDER = (DIVISOR_WIDTH<=8)?8:((DIVISOR_WIDTH>(DIVISOR_WIDTH>>3)*8)?
    ((DIVISOR_WIDTH>>3)+1)*8:(DIVISOR_WIDTH>>3)*8)
    
)
(
input                               i_aclk,
input                               i_aresetn,
input [ROUNDED_DIVIDEND_WIDTH-1:0]  i_axi4s_dividend_tdata,
input                               i_axi4s_dividend_tvalid,
//output                            o_axi4s_dividend_tready,
input                               i_axi4s_dividend_tlast,
input                               i_axi4s_divisor_tdata,
input                               i_axi4s_divisor_tvalid,
input                               i_axi4s_divisor_tlast,
output                              o_axi4s_dout_tuser,
output                              o_axi4s_dout_tlast,
output                              o_axi4s_dout_tdata,
output                              o_axi4s_dout_tvalid,
input                               i_axi4s_dout_tready
);
reg    [ROUNDED_DIVIDEND_WIDTH-1:0]                  axi4s_dividend_tdata;
reg                                                  axi4s_dividend_tvalid;
wire                                                 axi4s_dividend_tready;
reg    [DIVIDEND_TUSER_WIDTH-1:0]                    axi4s_dividend_tuser;
reg                                                  axi4s_dividend_tlast;
reg    [ROUNDED_DIVISOR_WIDTH-1:0]                   axi4s_divisor_tdata;
reg                                                  axi4s_divisor_tvalid;
wire                                                 axi4s_divisor_tready;
reg    [DIVISOR_TUSER_WIDTH-1:0]                     axi4s_divisor_tuser;
reg                                                  axi4s_divisor_tlast;
wire   [TUSER_WIDTH-1:0]                             axi4s_dout_tuser;
wire                                                 axi4s_dout_tlast;
wire                                                 axi4s_dout_tvalid;
reg                                                  axi4s_dout_tready;
wire [DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1:0]  axi4s_dout_tdata;

always @(posedge i_aclk) begin
    axi4s_dividend_tdata <= {axi4s_dividend_tdata[ROUNDED_DIVIDEND_WIDTH-2:0], i_axi4s_dividend_tdata};
    axi4s_dividend_tvalid <= i_axi4s_dividend_tvalid;
    axi4s_dividend_tlast <= i_axi4s_dividend_tlast;
    axi4s_divisor_tdata <= {axi4s_divisor_tdata[ROUNDED_DIVISOR_WIDTH-2:0], i_axi4s_divisor_tdata};
    axi4s_divisor_tvalid <= i_axi4s_divisor_tvalid;
    axi4s_divisor_tlast <= i_axi4s_divisor_tlast;
    axi4s_dout_tready <= i_axi4s_dout_tready;
end

assign    o_axi4s_dividend_tready = axi4s_dividend_tready;
assign    o_axi4s_divisor_tready = axi4s_divisor_tready;
assign    o_axi4s_dout_tuser = |axi4s_dout_tuser;
assign    o_axi4s_dout_tlast = axi4s_dout_tlast;
assign    o_axi4s_dout_tdata = |axi4s_dout_tdata;
assign    o_axi4s_dout_tvalid = axi4s_dout_tvalid;
//lutmlt_cfg the_instance_name 
lane_divider u_the_instance_name (
        .i_aclk(i_aclk),
        .i_aresetn(i_aresetn),
        .i_axi4s_dividend_tdata(axi4s_dividend_tdata),
        .i_axi4s_divisor_tdata(i_axi4s_divisor_tdata),
        .i_axi4s_dividend_tvalid(axi4s_dividend_tvalid),
        .i_axi4s_divisor_tvalid(axi4s_divisor_tvalid),
        .o_axi4s_dout_tvalid(axi4s_dout_tvalid),
        .o_axi4s_dout_tdata(axi4s_dout_tdata)
);

endmodule
