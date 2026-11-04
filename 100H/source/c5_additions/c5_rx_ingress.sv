// Same-clock full-word/status boundary, never delay link without its data/K.
module c5_rx_ingress(
 input wire clk,rst_n,link_ok,clear_loss,input wire [31:0] data,input wire [3:0] k,
 output reg [31:0] word_data /* synthesis syn_preserve=1 */,
 output reg [3:0] word_k /* synthesis syn_preserve=1 */,
 output reg word_valid /* synthesis syn_preserve=1 syn_maxfan=16 */,
 output reg word_link /* synthesis syn_preserve=1 */,
 output reg direct_loss /* synthesis syn_preserve=1 */,
 output wire pending_activity
);
 // Identity-preserved local nets: maxfan is a data-net guide, not a reset cut.
 wire local_valid /* synthesis syn_keep=1 syn_maxfan=16 */;
 assign local_valid=word_valid;
 assign pending_activity=local_valid && !(word_k==9 && (word_data & 32'hff9fffff)==32'hbc0028bc) &&
  !(word_k==5 && (word_data==32'hc5bcc5bc || word_data==32'h28bc28bc || word_data==32'h50bc50bc || word_data==32'hffbcffbc));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin word_data<=0;word_k<=15;word_valid<=0;word_link<=0;direct_loss<=0;end
  else begin
   word_data<=data;word_k<=k;word_valid<=1;word_link<=link_ok;
   // Sticky by design: a raw loss must stay visible until the protocol takes
   // responsibility for it. The only sanctioned clearance is a mode-switch
   // settle window (the remote stream legitimately restarts) or the HOLD-time
   // codec reset; steady-state loss keeps latching.
   if(!link_ok)direct_loss<=1;
   else if(clear_loss)direct_loss<=0;
  end
 end
endmodule
