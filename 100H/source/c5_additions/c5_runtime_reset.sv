// Runtime only: keep the physical reverse SFP link outside this reset tree.
// Either external reset asynchronously clears BOTH domains, including stopped
// clocks. Neither domain releases until the peer has clocked its release chain.
module c5_runtime_reset(
 input wire axi_clk,rx_clk,axi_reset,raw_rx_reset_n,
 output reg axi_reset_n,rx_reset_n,
 output wire epoch_reset_n
);
 wire common_n=raw_rx_reset_n && !axi_reset;
 (* ASYNC_REG="TRUE" *) reg [2:0] axi_release,rx_release;
 (* ASYNC_REG="TRUE" *) reg [1:0] rx_ready_axi,axi_ready_rx;
 (* ASYNC_REG="TRUE" *) reg [2:0] epoch_release;
 // Independent raw-link reset release in DDR domain: DDR calibration reset
 // must not clear the anti-replay high-water mark.
 always @(posedge axi_clk or negedge raw_rx_reset_n) begin
  if(!raw_rx_reset_n) epoch_release<=0;
  else epoch_release<={epoch_release[1:0],1'b1};
 end
 assign epoch_reset_n=epoch_release[2];
 always @(posedge axi_clk or negedge common_n) begin
  if(!common_n) axi_release<=0;
  else axi_release<={axi_release[1:0],1'b1};
 end
 always @(posedge rx_clk or negedge common_n) begin
  if(!common_n) rx_release<=0;
  else rx_release<={rx_release[1:0],1'b1};
 end
 // Peer synchronizers and exported resets use destination-local reset release.
 // Only the three entry release chains above see the raw asynchronous reset.
 always @(posedge axi_clk or negedge axi_release[2]) begin
  if(!axi_release[2])begin rx_ready_axi<=0;axi_reset_n<=0;end
  else begin rx_ready_axi<={rx_ready_axi[0],rx_release[2]};axi_reset_n<=rx_ready_axi[1];end
 end
 always @(posedge rx_clk or negedge rx_release[2]) begin
  if(!rx_release[2])begin axi_ready_rx<=0;rx_reset_n<=0;end
  else begin axi_ready_rx<={axi_ready_rx[0],axi_release[2]};rx_reset_n<=axi_ready_rx[1];end
 end
endmodule
