
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

module ipsxe_divider_onboard_top#(

    parameter DIVIDEND_WIDTH = 64,
    
    parameter ROUNDED_DIVIDEND_WIDTH = (DIVIDEND_WIDTH + 7) / 8 * 8,
    
    
    parameter DIVISOR_WIDTH = 64,
    
    parameter ROUNDED_DIVISOR_WIDTH = (DIVISOR_WIDTH + 7) / 8 * 8,
    
    
    parameter DIVIDEND_TUSER_WIDTH = 1,
    
    parameter DIVISOR_TUSER_WIDTH = 1,
    
    parameter DIVIDEND_TUSER_WIDTH_TRUE = 0,
	
    parameter DIVISOR_TUSER_WIDTH_TRUE = 0,
	
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
    

    parameter TUSER_WIDTH = DIVIDEND_TUSER_WIDTH_TRUE + DIVISOR_TUSER_WIDTH_TRUE + DIVISOR_BY_ZERO,

    
    parameter   DOUT_TDATA_QUOTIENT = (DIVIDEND_WIDTH<=8)?8:((DIVIDEND_WIDTH>(DIVIDEND_WIDTH>>3)*8)?
    ((DIVIDEND_WIDTH>>3)+1)*8:(DIVIDEND_WIDTH>>3)*8),
    
    parameter  DOUT_TDATA_REMAINDER = (DIVISOR_WIDTH<=8)?8:((DIVISOR_WIDTH>(DIVISOR_WIDTH>>3)*8)?
    ((DIVISOR_WIDTH>>3)+1)*8:(DIVISOR_WIDTH>>3)*8)
    

)
(
    input         i_aclk,
    input         i_aresetn,
    
    output reg o_led = 0
);

wire        o_axi4s_dividend_tready;

wire        o_axi4s_divisor_tready;

wire [DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1:0] o_axi4s_dout_tdata;

wire o_axi4s_dout_tvalid;


wire o_sync_rst;
wire [ROUNDED_DIVISOR_WIDTH-1:0]i_axi4s_divisor_tdata;
wire [ROUNDED_DIVIDEND_WIDTH-1:0]i_axi4s_dividend_tdata;
wire i_axi4s_divisor_tvalid;
wire i_axi4s_dividend_tvalid;
    
wire [3:0] period_cnt;
    
    
wire [DOUT_TDATA_QUOTIENT-1:0]dout_tdata_quotient;
wire [DOUT_TDATA_REMAINDER-1:0]dout_tdata_remainder;
assign dout_tdata_quotient = o_axi4s_dout_tdata[(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1):DOUT_TDATA_REMAINDER] ;
assign dout_tdata_remainder = o_axi4s_dout_tdata[DOUT_TDATA_REMAINDER-1:0];
    
    //localparam expected_output_data = 538;
    always @(posedge i_aclk or negedge o_sync_rst)begin
        if (~o_sync_rst)
            o_led <= 1'b0;
        else if (o_axi4s_dout_tvalid)begin
            if(dout_tdata_quotient == 'd2 && dout_tdata_remainder == 'd26)begin
                o_led <= 1'b1;
            end
            else begin
                o_led <= 1'b0;
            end
        end
    end
    

ipsxe_divider_reset_sync u_ipsxe_divider_reset_sync(
    .i_clk(i_aclk),
    .i_rst(i_aresetn),
    .o_sync_rst(o_sync_rst)
);

//lutmlt_cfg the_instance_name 
lane_divider u_the_instance_name (
        .i_aclk(i_aclk),
    
        .i_aresetn(o_sync_rst),
    

        .i_axi4s_dividend_tdata(i_axi4s_dividend_tdata),
        .i_axi4s_divisor_tdata(i_axi4s_divisor_tdata),

        .i_axi4s_dividend_tvalid(i_axi4s_dividend_tvalid),
        .i_axi4s_divisor_tvalid(i_axi4s_divisor_tvalid),

    
        .o_axi4s_dividend_tready(o_axi4s_dividend_tready),
    
        .o_axi4s_divisor_tready(o_axi4s_divisor_tready),
    
        
        .o_axi4s_dout_tvalid(o_axi4s_dout_tvalid),

    

        .o_axi4s_dout_tdata(o_axi4s_dout_tdata)

);

ipsxe_rom_cnt u_ipsxe_rom_cnt
(
    .clk(i_aclk),
    .rst_n(o_sync_rst),
    .period_cnt(period_cnt)
);

ipsxe_divider_rom_dividend_tdata #(
    .DIVIDEND_WIDTH(ROUNDED_DIVIDEND_WIDTH)
)u_ipsxe_divider_rom_dividend_tdata
(
    .clk(i_aclk),
    .rstn(o_sync_rst),
    .rd_addr(period_cnt),
    .i_axi4s_dividend_tdata(i_axi4s_dividend_tdata)
);

ipsxe_divider_rom_divisor_tdata #(
    .DIVISOR_WIDTH(ROUNDED_DIVISOR_WIDTH)
) u_ipsxe_divider_rom_divisor_tdata
(
    .clk(i_aclk),
    .rstn(o_sync_rst),
    .rd_addr(period_cnt),
    .i_axi4s_divisor_tdata(i_axi4s_divisor_tdata)
);

ipsxe_divider_rom_dividend_tvalid u_ipsxe_divider_rom_dividend_tvalid
(
    .clk(i_aclk),
    .rstn(o_sync_rst),
    .rd_addr(period_cnt),
    .i_axi4s_dividend_tvalid(i_axi4s_dividend_tvalid)
);

ipsxe_divider_rom_divisor_tvalid u_ipsxe_divider_rom_divisor_tvalid
(
    .clk(i_aclk),
    .rstn(o_sync_rst),
    .rd_addr(period_cnt),
    .i_axi4s_divisor_tvalid(i_axi4s_divisor_tvalid)
);
    

endmodule
