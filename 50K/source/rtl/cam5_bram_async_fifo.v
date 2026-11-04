`timescale 1ns/1ps
// Dedicated NEW HD capture FIFO. Power-of-two DEPTH >=4. Common reset
// assertion, locally synchronized release required, as for the donor FIFO.
// Dual-clock synchronous-read inference: no asynchronous RAM mux, no 32-word
// LUTRAM banking and no opposite-edge write. A registered output is the FWFT
// head. It remains stable under backpressure. Prefetch advances the RAM read
// pointer only when the RAM word has been captured in that output register;
// thus the writer may reuse that location after the Gray pointer crosses.
module cam5_bram_async_fifo #(parameter WIDTH=36,DEPTH=2048)(
    input wr_clk,wr_rst_n,wr_en,input [WIDTH-1:0] wr_data,output reg full,
    input rd_clk,rd_rst_n,rd_en,output reg [WIDTH-1:0] rd_data,output empty
);
    localparam AW=$clog2(DEPTH);
    (* syn_ramstyle="block_ram" *) reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW:0] wbin,wgray,rbin,rgray;
    (* ASYNC_REG="TRUE" *)reg [AW:0] rgray_w1,rgray_w2,wgray_r1,wgray_r2;
    reg head_valid;
    wire push=wr_en && !full;
    wire [AW:0] wnext=wbin+push;
    wire [AW:0] wgray_next=(wnext>>1)^wnext;
    wire ram_available=rgray!=wgray_r2;
    wire fetch=(!head_valid || rd_en) && ram_available;
    wire [AW:0] rnext=rbin+1'b1;
    assign empty=!head_valid;
    // Keep the memory processes reset-free for portable block-RAM inference.
    always @(posedge wr_clk)
        if(wr_rst_n && push)mem[wbin[AW-1:0]]<=wr_data;
    always @(posedge rd_clk)
        if(rd_rst_n && fetch)rd_data<=mem[rbin[AW-1:0]];
    always @(posedge wr_clk or negedge wr_rst_n)
        if(!wr_rst_n)begin wbin<=0;wgray<=0;full<=0;rgray_w1<=0;rgray_w2<=0;end
        else begin
            rgray_w1<=rgray;rgray_w2<=rgray_w1;
            wbin<=wnext;wgray<=wgray_next;
            full<=wgray_next=={~rgray_w2[AW:AW-1],rgray_w2[AW-2:0]};
        end
    always @(posedge rd_clk or negedge rd_rst_n)
        if(!rd_rst_n)begin rbin<=0;rgray<=0;head_valid<=0;wgray_r1<=0;wgray_r2<=0;end
        else begin
            wgray_r1<=wgray;wgray_r2<=wgray_r1;
            if(fetch)begin
                rbin<=rnext;rgray<=(rnext>>1)^rnext;head_valid<=1;
            end else if(rd_en)head_valid<=0;
        end
endmodule
