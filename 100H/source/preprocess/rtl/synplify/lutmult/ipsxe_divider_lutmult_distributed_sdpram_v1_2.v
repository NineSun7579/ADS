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
// Filename:ipm_distributed_sdpram_v1_2.v
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ps

module ipsxe_divider_lutmult_distributed_sdpram_v1_2
    #(
      parameter  ADDR_WIDTH               = 4          ,    //address width   range:4-10
      parameter  DATA_WIDTH               = 4          ,    //data width      range:1-256
      parameter  INIT_FILE                = "NONE"     ,    //legal value:"NONE" or "initial file name"
      parameter  FILE_FORMAT              = "BIN"           //initial data format : "BIN" or "HEX"
     )
     (
      input   wire [DATA_WIDTH-1:0]       wr_data      ,
      input   wire [ADDR_WIDTH-1:0]       wr_addr      ,
      input   wire [ADDR_WIDTH-1:0]       rd_addr      ,
      input   wire                        wr_clk       ,
      input   wire                        wr_en        ,
      output  wire [DATA_WIDTH-1:0]       rd_data
     )/* synthesis syn_ramstyle = "select_ram" */;

wire  [DATA_WIDTH-1:0]                    q            ;

reg   [DATA_WIDTH-1:0]                    mem [2**ADDR_WIDTH-1:0];

//***********************************************************************reset*******************************************************************

//initialize sdpram
generate
    integer i,j;
    if (INIT_FILE != "NONE") begin
        if (FILE_FORMAT == "BIN") begin
            initial begin
                $readmemb(INIT_FILE,mem);
            end
        end
        else if (FILE_FORMAT == "HEX") begin
            initial begin
                $readmemh(INIT_FILE,mem);
            end
        end
    end
    else begin
        initial begin
            for (i=0;i<2**ADDR_WIDTH;i=i+1) begin
                for (j=0;j<DATA_WIDTH;j=j+1) begin
                    mem[i][j] = 1'b0;
                end
            end
        end
    end
endgenerate

//write & read
generate
    always @(posedge wr_clk) begin
        if(wr_en)
            mem[wr_addr] <= wr_data;
    end

    assign q = mem[rd_addr];

endgenerate

assign rd_data = q;

endmodule