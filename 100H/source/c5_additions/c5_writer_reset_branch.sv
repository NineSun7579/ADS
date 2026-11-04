// Synchronous writer-control reset distribution ONLY. No flop or added cycle.
// Global DMA and publication-counter reset never pass through this helper.
// ADS maxfan is ineffective on classified asynchronous reset/clock nets; parent
// must verify actual mapped synchronous control classification and local loads.
module c5_writer_reset_branch(
 input wire global_axi_reset,local_flush,
 output wire writer_reset
) /* synthesis syn_hier="fixed" */;
 wire reset_control /* synthesis syn_keep=1 syn_maxfan=16 */;
 assign reset_control=global_axi_reset | local_flush;
 assign writer_reset=reset_control;
endmodule
