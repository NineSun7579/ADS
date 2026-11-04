// Exact-cycle synchronous reset distribution. No register or reset stretching.
// A retained identity boundary is a mapping experiment, not a fanout guarantee.
// ADS may ignore maxfan on classified reset nets: inspect mapped loads/RSCO.
module native_bev_reset_branch (
    input wire global_reset,
    output wire local_reset
) /* synthesis syn_hier="fixed" */;
    wire reset_control /* synthesis syn_keep=1 syn_maxfan=16 */;
    assign reset_control=global_reset;
    assign local_reset=reset_control;
endmodule
