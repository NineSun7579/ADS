`timescale 1ns/1ps
// FPGA 2x2 mean reduction of an accepted RGB565 raster, before DDR writes.
// Rows are counted from pixel-valid events; CDC HS timing is deliberately not
// used to index the line store. Ignore camera tail dummy after IN_W*IN_H.
module cam34_downsample_2x2 #(
 parameter integer IN_W=640, parameter integer IN_H=480
)(
 input wire clk,rst,in_valid,input wire[15:0]in_pixel,
 input wire in_hsync,in_vsync,
 input wire bypass,
 output reg out_valid,output reg[15:0]out_pixel,
 output wire out_hsync,out_vsync
);
 localparam integer XW=$clog2(IN_W), YW=$clog2(IN_H);
 reg[XW:0]x;reg[YW:0]y;
 reg started,vs_q;reg[1:0]vs_pipe,hs_pipe;
 // Mode belongs to the source SOF. Both paths have two clock stages,
 // including markers; a live request can never change a partial raster.
 reg bypass_frame,bypass_valid_q;
 reg[15:0]bypass_pixel_q;
 reg[15:0]left;
 reg[29:0]row_pair_sum[0:IN_W/2-1];
 reg[29:0]top_q,bottom_q;
 reg pair_valid_q;
 function[9:0]r8(input[15:0]p);begin r8={p[15:11],p[15:13]};end endfunction
 function[9:0]g8(input[15:0]p);begin g8={p[10:5],p[10:9]};end endfunction
 function[9:0]b8(input[15:0]p);begin b8={p[4:0],p[4:2]};end endfunction
 function[29:0]pair_sum(input[15:0]a,input[15:0]b);
  begin pair_sum={r8(a)+r8(b),g8(a)+g8(b),b8(a)+b8(b)};end
 endfunction
 function[15:0]mean(input[29:0]a,input[29:0]b);
  reg[11:0]r,g,bl;begin
   r=({2'b0,a[29:20]}+{2'b0,b[29:20]}+12'd2)>>2;
   g=({2'b0,a[19:10]}+{2'b0,b[19:10]}+12'd2)>>2;
   bl=({2'b0,a[9:0]}+{2'b0,b[9:0]}+12'd2)>>2;
   mean={r[7:3],g[7:2],bl[7:3]};
  end
 endfunction
 assign out_vsync=vs_pipe[1];assign out_hsync=hs_pipe[1];
 always @(posedge clk)begin
  if(rst)begin x<=0;y<=0;started<=0;vs_q<=0;vs_pipe<=0;hs_pipe<=0;
    left<=0;top_q<=0;bottom_q<=0;pair_valid_q<=0;out_pixel<=0;out_valid<=0;
    bypass_frame<=0;bypass_valid_q<=0;bypass_pixel_q<=0;
  end else begin
   vs_q<=in_vsync;vs_pipe<={vs_pipe[0],in_vsync};hs_pipe<={hs_pipe[0],in_hsync};
    out_valid<=bypass_frame ? bypass_valid_q : pair_valid_q;
    pair_valid_q<=0;bypass_valid_q<=0;
    if(bypass_frame)out_pixel<=bypass_pixel_q;
    else if(pair_valid_q)out_pixel<=mean(top_q,bottom_q);
   if(in_vsync)begin
     x<=0;y<=0;started<=1;pair_valid_q<=0;bypass_valid_q<=0;out_valid<=0;
     if(!vs_q)bypass_frame<=bypass;
    end else if(in_valid && started && bypass_frame)begin
     bypass_pixel_q<=in_pixel;bypass_valid_q<=1;
    end else if(in_valid && started && y<IN_H)begin
    if(!x[0])left<=in_pixel;
    else if(!y[0])row_pair_sum[x>>1]<=pair_sum(left,in_pixel);
    else begin
     top_q<=row_pair_sum[x>>1];bottom_q<=pair_sum(left,in_pixel);pair_valid_q<=1;
    end
    if(x==IN_W-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
   end
  end
 end
endmodule
