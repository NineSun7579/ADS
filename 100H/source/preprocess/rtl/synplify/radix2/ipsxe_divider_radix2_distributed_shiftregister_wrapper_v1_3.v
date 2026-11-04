//////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:ipm_distributed_shiftregister_wrapper_v1_3.v
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ps
module ipsxe_divider_radix2_distributed_shiftregister_wrapper_v1_3 #(parameter FIXED_DEPTH = 1, DATA_WIDTH = 1)
     (
      din       ,
      clk       ,
      i_aclken  ,
      rst       ,
      dout
     );
   localparam OUT_REG = 1 ; //@IPC bool
    localparam VARIABLE_MAX_DEPTH = FIXED_DEPTH ; // @IPC int 1,1024
    localparam SHIFT_REG_TYPE = "fixed_latency" ; // @IPC enum fixed_latency,dynamic_latency
    localparam RST_TYPE = "ASYNC" ; // @IPC enum ASYNC,SYNC

    localparam  DEPTH   = (SHIFT_REG_TYPE=="fixed_latency"  ) ? FIXED_DEPTH :
                          (SHIFT_REG_TYPE=="dynamic_latency") ? VARIABLE_MAX_DEPTH : 0;

    localparam  ADDR_WIDTH = (DEPTH<=16)   ? 4 :
                             (DEPTH<=32)   ? 5 :
                             (DEPTH<=64)   ? 6 :
                             (DEPTH<=128)  ? 7 :
                             (DEPTH<=256)  ? 8 :
                             (DEPTH<=512)  ? 9 : 10 ;

     input  wire     [DATA_WIDTH-1:0]       din     ;
     input  wire                            clk     ;
     input  wire                            i_aclken;
     input  wire                            rst     ;
     output wire     [DATA_WIDTH-1:0]       dout    ;


ipsxe_divider_radix2_distributed_shiftregister_v1_3
   #(
    .FIXED_DEPTH         (FIXED_DEPTH        )  ,
    .VARIABLE_MAX_DEPTH  (VARIABLE_MAX_DEPTH )  ,
    .DATA_WIDTH          (DATA_WIDTH         )  
    )u_ipsxe_distributed_shiftregister_v1_4
    (
    .din                 (din                )  ,
    .clk                 (clk                )  ,
    .clken            	 (i_aclken           )  ,
	.addr				 ({ADDR_WIDTH{1'b0}} )  ,
    .rst                 (rst                )  ,
    .dout                (dout               )
    );

endmodule
