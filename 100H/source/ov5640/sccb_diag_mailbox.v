// Stable bundled mailbox. No feedback to the sensor engine or command path.
// A common asynchronous diagnostic reset clears BOTH domains and prevents
// reset-induced toggle transitions from being published as completions.
module sccb_diag_mailbox (
 input src_clk, dst_clk, rst_n, src_event,
 input [511:0] src_snapshot,
 output reg [511:0] dst_snapshot,
 output reg [31:0] dst_generation
);
 reg [511:0] held;
 reg req, ack;
 reg [2:0] req_sync, ack_sync;
 reg overflow;
 reg settling;
 (* ASYNC_REG = "TRUE", syn_srlstyle = "registers" *) reg [2:0] src_reset_release, dst_reset_release;
 always @(posedge src_clk or negedge rst_n) begin
   if(!rst_n) src_reset_release<=0;
   else src_reset_release<={src_reset_release[1:0],1'b1};
 end
 always @(posedge dst_clk or negedge rst_n) begin
   if(!rst_n) dst_reset_release<=0;
   else dst_reset_release<={dst_reset_release[1:0],1'b1};
 end
 always @(posedge src_clk or negedge src_reset_release[2]) begin
   if(!src_reset_release[2]) begin held<=0; req<=0; ack_sync<=0; overflow<=0; end
   else begin
     ack_sync<={ack_sync[1:0],ack};
     if(src_event) begin
       if(req==ack_sync[2]) begin
         held<=src_snapshot;
         held[8*32+31]<=overflow;
         req<=~req;
       end else overflow<=1;
     end
   end
 end
 always @(posedge dst_clk or negedge dst_reset_release[2]) begin
   if(!dst_reset_release[2]) begin req_sync<=0; ack<=0; dst_snapshot<=0; dst_generation<=0; settling<=0; end
   else begin
     req_sync<={req_sync[1:0],req};
     if(req_sync[2]!=ack) begin
       if(!settling) settling<=1;
       else begin
         dst_snapshot<=held;
         dst_generation<=dst_generation+1'b1;
         ack<=req_sync[2]; settling<=0;
       end
     end else settling<=0;
   end
 end
endmodule
