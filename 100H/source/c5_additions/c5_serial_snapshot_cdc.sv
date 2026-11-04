// Snapshot transfer with a single data wire across the clock boundary.
// The source freezes a WIDTH-bit snapshot, then sends it one bit per toggle
// handshake (LSB first). The destination assembles the bits locally and
// publishes the whole vector in one d_clk cycle (d_valid pulses, d_data holds).
//
// Only two kinds of signal cross: the request/acknowledge toggles (two-flop
// synchronizers) and ONE data bit that is stable before req toggles and does
// not change again until the acknowledge returns. No multi-bit bus crosses, so
// no inter-bit skew bound is needed and the clock-group cut stays correct.
// Latency is roughly 10 destination cycles per bit; this is for slow-changing
// read-only state, not streams. Both resets must assert together.
module c5_serial_snapshot_cdc #(parameter WIDTH=704)(
 input wire s_clk,s_rst_n,s_valid, output wire s_ready,
 input wire [WIDTH-1:0] s_data,
 input wire d_clk,d_rst_n, output reg d_valid,
 input wire d_ready, output reg [WIDTH-1:0] d_data
);
 localparam CW=$clog2(WIDTH+1);
 // source domain
 reg [WIDTH-1:0] sh;
 reg [CW-1:0] scnt;
 reg busy,armed,req,sbit;
 (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync;
 reg ack;
 assign s_ready=!busy;
 always @(posedge s_clk or negedge s_rst_n) begin
  if(!s_rst_n) begin sh<=0;scnt<=0;busy<=0;armed<=0;req<=0;sbit<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(!busy) begin
    if(s_valid) begin sh<=s_data;scnt<=0;busy<=1;end
   end else if(!armed) begin
    // Previous bit acknowledged (or first bit): present the next one.
    if(req==ack_sync[1]) begin
     if(scnt==WIDTH) busy<=0;
     else begin sbit<=sh[0];sh<={1'b0,sh[WIDTH-1:1]};armed<=1;end
    end
   end else begin
    // sbit has been stable for a full source cycle; now announce it.
    req<=~req;armed<=0;scnt<=scnt+1'b1;
   end
  end
 end
 // destination domain
 // [v10] The bit shift and the final publish are issued from registered
 // strobes one clock after the synchronized request edge, so the WIDTH-wide
 // clock enables of asm/d_data are driven straight from flip-flops instead of
 // from the synchronizer compare + counter decode.
 (* ASYNC_REG="TRUE" *) reg [1:0] req_sync;
 (* ASYNC_REG="TRUE" *) reg bit_q;
 reg req_seen;
 reg [WIDTH-1:0] asm;
 reg [CW-1:0] dcnt;
 reg bit_s;
 (* syn_maxfan=64 *) reg step;
 (* syn_maxfan=64 *) reg publish;
 wire new_bit=req_sync[1]!=req_seen;
 always @(posedge d_clk or negedge d_rst_n) begin
  if(!d_rst_n) begin req_sync<=0;bit_q<=0;req_seen<=0;asm<=0;dcnt<=0;ack<=0;d_valid<=0;d_data<=0;
   bit_s<=0;step<=0;publish<=0;end
  else begin
   req_sync<={req_sync[0],req};
   bit_q<=sbit;
   d_valid<=0;
   step<=new_bit;
   publish<=new_bit && dcnt==WIDTH-1;
   if(new_bit) begin
    req_seen<=req_sync[1];
    ack<=req_sync[1];
    bit_s<=bit_q;
    if(dcnt==WIDTH-1) dcnt<=0;
    else dcnt<=dcnt+1'b1;
   end
   if(step) asm<={bit_s,asm[WIDTH-1:1]};
   if(publish) begin d_data<={bit_s,asm[WIDTH-1:1]};d_valid<=1;end
  end
 end
endmodule
