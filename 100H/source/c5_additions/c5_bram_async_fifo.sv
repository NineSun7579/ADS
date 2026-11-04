`timescale 1ns/1ps
// Synchronous-read dual-clock inferred BRAM, registered FWFT output.
// RAM has no reset. Common async assertion + local synchronized release are
// mandatory; valid/pointers flush storage identity without clearing RAM bits.
module c5_bram_async_fifo #(parameter WIDTH=85,DEPTH=1024)(
 input wire wr_clk,wr_rst_n,wr_en,input wire [WIDTH-1:0] wr_data,output reg full,
 input wire rd_clk,rd_rst_n,rd_en,output reg [WIDTH-1:0] rd_data,output wire empty
);
 localparam AW=$clog2(DEPTH);
 (* syn_ramstyle="block_ram" *) reg [WIDTH-1:0] mem[0:DEPTH-1];
 reg [AW:0] wbin,wptr,rbin,rptr;
 (* ASYNC_REG="TRUE" *) reg [AW:0] rptr_wr1,rptr_wr2,wptr_rd1,wptr_rd2;
 reg head_valid;
 wire push=wr_en && !full;
 wire [AW:0] wnext=wbin+push;
 wire [AW:0] wgray_next=(wnext>>1)^wnext;
 wire fetch=(!head_valid || rd_en) && rptr!=wptr_rd2;
 wire [AW:0] rnext=rbin+1'b1;
 assign empty=!head_valid;
 // Pointer credit returns only after the read word is captured in rd_data.
 // rd_data stays stable while valid and downstream is stalled.
 always @(posedge wr_clk) if(wr_rst_n && push)mem[wbin[AW-1:0]]<=wr_data;
 always @(posedge rd_clk) if(rd_rst_n && fetch)rd_data<=mem[rbin[AW-1:0]];
 always @(posedge wr_clk or negedge wr_rst_n) begin
  if(!wr_rst_n)begin wbin<=0;wptr<=0;full<=0;rptr_wr1<=0;rptr_wr2<=0;end
  else begin
   rptr_wr1<=rptr;rptr_wr2<=rptr_wr1;
   wbin<=wnext;wptr<=wgray_next;
   full<=wgray_next=={~rptr_wr2[AW:AW-1],rptr_wr2[AW-2:0]};
  end
 end
 always @(posedge rd_clk or negedge rd_rst_n)begin
  if(!rd_rst_n)begin rbin<=0;rptr<=0;head_valid<=0;wptr_rd1<=0;wptr_rd2<=0;end
  else begin
   wptr_rd1<=wptr;wptr_rd2<=wptr_rd1;
   if(fetch)begin rbin<=rnext;rptr<=(rnext>>1)^rnext;head_valid<=1;end
   else if(rd_en)head_valid<=0;
  end
 end
endmodule
