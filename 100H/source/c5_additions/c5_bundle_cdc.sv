// Held bundle + toggle handshake. Source holds data until synchronized ack.
// Destination adds a settling cycle after the two request synchronizers.
// Physical implementation must bound held->data0 delay; no blanket false path.
module c5_bundle_cdc #(parameter WIDTH=160)(
 input wire s_clk,s_rst_n,s_valid, output wire s_ready,
 input wire [WIDTH-1:0] s_data,
 input wire d_clk,d_rst_n, output reg d_valid,
 input wire d_ready, output reg [WIDTH-1:0] d_data
);
 reg [WIDTH-1:0] held,data0,data1;
 reg req,ack;
 (* ASYNC_REG="TRUE" *) reg [1:0] ack_sync,req_sync;
 reg req_settled;
 assign s_ready=(req==ack_sync[1]);
 always @(posedge s_clk or negedge s_rst_n) begin
  if(!s_rst_n) begin held<=0;req<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(s_valid && s_ready) begin held<=s_data;req<=~req;end
  end
 end
 always @(posedge d_clk or negedge d_rst_n) begin
  if(!d_rst_n) begin req_sync<=0;req_settled<=0;data0<=0;data1<=0;d_data<=0;d_valid<=0;ack<=0;end
  else begin
   req_sync<={req_sync[0],req};req_settled<=req_sync[1];
   data0<=held;data1<=data0;
   if(!d_valid && req_settled!=ack) begin d_data<=data1;d_valid<=1;end
   if(d_valid && d_ready) begin d_valid<=0;ack<=req_settled;end
  end
 end
endmodule
