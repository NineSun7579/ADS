//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2023 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//               
// Library:
// Filename:ipsxe_divider_reset_sync.v                 
//////////////////////////////////////////////////////////////////////////////
module ipsxe_divider_reset_sync(
    input          i_clk,
    input          i_rst,
    output  wire    o_sync_rst
);

reg  rst_n_ff1 = 0;
reg  rst_n_ff2 = 0;

always@(posedge i_clk or negedge i_rst)
begin
    if(~i_rst)
    begin
        rst_n_ff1 <= 1'b0;
        rst_n_ff2 <= 1'b0;
    end
    else
    begin
        rst_n_ff1 <= 1;
        rst_n_ff2 <= rst_n_ff1;
    end
end
    
assign o_sync_rst = rst_n_ff2;

endmodule