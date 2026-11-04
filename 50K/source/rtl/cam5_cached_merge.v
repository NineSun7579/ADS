`timescale 1ns/1ps
// HD-only merge. Every B row belongs to one pinned, completed native frame.
// B's pixel port is synchronous: all output symbols are delayed one clock.
module cam5_cached_merge #(
 parameter A_WIDTH=1280,A_HEIGHT=720,B_WIDTH=640,B_HEIGHT=480,
 parameter SLOT_WIDTH=1280,OUT_HEIGHT=720,ROW_TIMEOUT=16000000
)(
 input a_clk,a_rst_n,input [15:0] a_data,input a_de,a_vs,
 input o_clk,o_rst_n,
 output frame_request,input frame_ready,input [31:0] frame_sequence,frame_epoch,
 output wire frame_release,
 output [9:0] row_index,output [9:0] pixel_address,input row_ready,
 input [15:0] pixel_data,output wire row_consume,
 output reg [15:0] c_data,output wire c_de,c_vs,
 output wire fault,output reg frame_complete,output [3:0] fault_src
);
 localparam PRIME=0,VSYNC=1,WAIT_ROW=2,PIXELS=3,GAP=4,RELEASE=5,FAILED=6;
 reg [2:0] state;
 reg [11:0] x;reg [9:0] y;reg [31:0] wait_count,pinned_sequence,pinned_epoch;
 reg local_fault,ac;
 wire av,af,aseen;wire [15:0] ad;wire [9:0] ar;
 wire [7:0] ae,alatest;reg [7:0] frame_a;
 // Holding the native A page engine in reset while priming drops input until
 // a later actual SOF. Never retain a partial A frame awaiting DDR completion.
 // This enable drives asynchronous reset pins. Do not decode the binary FSM:
 // skew during PIXELS(011)->GAP(100) can otherwise reset the A page engine.
 // Hold the registered enable throughout capture, including a latched fault.
 reg a_capture;
 (* ASYNC_REG="TRUE" *) reg [1:0] capture_a;
 always @(posedge a_clk or negedge a_rst_n)
  if(!a_rst_n)capture_a<=0;else capture_a<={capture_a[0],a_capture};
 cam5_line_pages #(.WIDTH(A_WIDTH),.HEIGHT(A_HEIGHT)) a_pages(
  .pclk(a_clk),.p_rst_n(a_rst_n && capture_a[1]),
  .pixel({a_data[4:0],a_data[10:5],a_data[15:11]}),.de(a_de),.vs(a_vs),
  .oclk(o_clk),.o_rst_n(o_rst_n && a_capture),.consume(ac),
  .address(x<SLOT_WIDTH?x[10:0]:11'd0),.valid(av),.data(ad),.row(ar),.frame(ae),
  .latest_frame(alatest),.seen_frame(aseen),.fault(af));
 assign frame_request=state==PRIME;
 assign row_consume=state==GAP && y<B_HEIGHT && !fault;
 assign frame_release=state==GAP && y==OUT_HEIGHT-1 && !fault;
 assign row_index=y;
 assign pixel_address=(x>=SLOT_WIDTH && x<SLOT_WIDTH+B_WIDTH)?x-SLOT_WIDTH:12'd0;
 assign fault=local_fault || (a_capture && af);
 assign fault_src={aseen,frame_ready,af,local_fault};
 reg pipe_de,pipe_vs,pipe_b;reg [15:0] pipe_a;
 reg de_q,vs_q;
 assign c_de=de_q && !fault;
 assign c_vs=vs_q && !fault;
 reg complete_pending;
 reg [1:0] vs_count;
 wire b_position=x>=SLOT_WIDTH && x<SLOT_WIDTH+B_WIDTH && y<B_HEIGHT;
 wire emit_pixel=state==PIXELS && !fault;
 always @(posedge o_clk or negedge o_rst_n)begin
  if(!o_rst_n)begin
   a_capture<=0;state<=PRIME;x<=0;y<=0;wait_count<=0;local_fault<=0;ac<=0;
   pinned_sequence<=0;pinned_epoch<=0;frame_a<=0;
   c_data<=0;de_q<=0;vs_q<=0;frame_complete<=0;
   pipe_de<=0;pipe_vs<=0;pipe_b<=0;pipe_a<=0;vs_count<=0;complete_pending<=0;
  end else begin
   ac<=0;frame_complete<=complete_pending && !fault;
   complete_pending<=0;
   // Cache pixel_data is the response to the preceding cycle's address.
   de_q<=pipe_de;vs_q<=pipe_vs;
   c_data<=pipe_b ? {pixel_data[4:0],pixel_data[10:5],pixel_data[15:11]} : pipe_a;
   pipe_de<=emit_pixel;pipe_vs<=state==VSYNC;pipe_b<=emit_pixel && b_position;
   pipe_a<=emit_pixel && x<A_WIDTH && y<A_HEIGHT ? ad:16'd0;
   if(fault)begin state<=FAILED;pipe_de<=0;pipe_vs<=0;de_q<=0;vs_q<=0;end
   else case(state)
    PRIME:begin
     wait_count<=0;
     if(frame_ready)begin
      if(frame_sequence==0 || (pinned_sequence!=0 && frame_sequence<=pinned_sequence))local_fault<=1;
      else begin pinned_sequence<=frame_sequence;pinned_epoch<=frame_epoch;state<=VSYNC;vs_count<=0;y<=0;x<=0;end
     end
    end
    VSYNC:begin
      if(vs_count==2)begin a_capture<=1;state<=WAIT_ROW;wait_count<=0;end
     else vs_count<=vs_count+1'b1;
    end
    WAIT_ROW:begin
     wait_count<=wait_count+1'b1;
     if(wait_count>=ROW_TIMEOUT-1)local_fault<=1;
     if(!frame_ready || frame_sequence!=pinned_sequence || frame_epoch!=pinned_epoch)local_fault<=1;
     if(av && !ac)begin
      if(ar!=y || (y!=0 && ae!=frame_a) || (y<B_HEIGHT && !row_ready))local_fault<=1;
      else begin if(y==0)frame_a<=ae;x<=0;wait_count<=0;state<=PIXELS;end
     end
    end
    PIXELS:begin
     if(!frame_ready || frame_sequence!=pinned_sequence || frame_epoch!=pinned_epoch ||
        (y<B_HEIGHT && !row_ready))local_fault<=1;
     if(x==2*SLOT_WIDTH-1)begin ac<=1;state<=GAP;end
     else x<=x+1'b1;
    end
    GAP:begin
     // The right slot's padding guarantees the last synchronous B read retired.
      if(y==OUT_HEIGHT-1)begin a_capture<=0;complete_pending<=1;state<=RELEASE;end
     else begin y<=y+1'b1;wait_count<=0;state<=WAIT_ROW;end
    end
    RELEASE:begin
     // Do not issue a new request until the old pinned descriptor is revoked.
     if(!frame_ready)state<=PRIME;
    end
    FAILED:begin end
    default:local_fault<=1;
   endcase
  end
 end
endmodule
