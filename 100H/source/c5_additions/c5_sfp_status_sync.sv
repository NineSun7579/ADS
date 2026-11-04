// Diagnostic level only: same zero initialization and two AXI-edge latency as
// the donor sfp_enable_sync[1:0]. No reset tied to video/DDR mode transitions.
// ADS User Guide syn_hier=fixed keeps optimization within this tiny helper;
// syn_preserve/kept nets identify both actual sequential boundaries for mapping.
module c5_sfp_status_sync(
 input wire clk,input wire async_enable,
 output wire enable_sync
) /* synthesis syn_hier="fixed" */;
 wire diagnostic_input /* synthesis syn_keep=1 */;
 assign diagnostic_input=async_enable;
 (* ASYNC_REG="TRUE" *) reg enable_meta=1'b0 /* synthesis syn_preserve=1 */;
 (* ASYNC_REG="TRUE" *) reg enable_stage1=1'b0 /* synthesis syn_preserve=1 */;
 wire meta_q /* synthesis syn_keep=1 */;
 wire stage1_q /* synthesis syn_keep=1 */;
 assign meta_q=enable_meta;
 assign stage1_q=enable_stage1;
 assign enable_sync=stage1_q;
 always @(posedge clk)begin
  enable_meta<=diagnostic_input;
  enable_stage1<=meta_q;
 end
endmodule
