
//`timescale 1ns/1ps
// Module iteration
// This module performs one iteration of a division operation using shift and add/subtract operations.
module ipsxe_divider_iteration_auto_v1_0(
    dividend_2n, // Dividend input
    divisor_2n, // Divisor input
    dividend_2n_final, // Final dividend output
    dividend_2n_sign
    );

// Width of the dividend and divisor inputs
parameter    DIVI_ADDQ_W = 128;
parameter    DIVISOR_W = 64;
// parameter    DIVIDEND_W = 4;

input  [DIVI_ADDQ_W:0] dividend_2n; // Dividend input, with width twice the DIVI_ADDQ_W
input  [DIVI_ADDQ_W+1:0] divisor_2n; // Divisor input, with width twice the DIVI_ADDQ_W plus one for sign bit
output [DIVI_ADDQ_W:0] dividend_2n_final; // Final dividend output, with width twice the DIVI_ADDQ_W
output dividend_2n_sign;
// Wire for the dividend after shifting
wire   [DIVI_ADDQ_W+1:0] dividend_2n_shift;
wire   [DIVI_ADDQ_W+1:0] dividend_2n_addsub;
// Wire for the dividend after add/sub operation
// wire   [DIVI_ADDQ_W+1:0] divisor_2n;
// assign divisor_2n={{(2){1'b0}},divisor,{DIVIDEND_W{1'b0}}};  
// Shift dividend to left by one
assign  dividend_2n_shift = {dividend_2n, 1'b0};   
// Perform add/sub operation based on the sign bit
assign  dividend_2n_addsub[DIVI_ADDQ_W+1:DIVI_ADDQ_W-DIVISOR_W] = dividend_2n_shift[DIVI_ADDQ_W+1]?
    (dividend_2n_shift[DIVI_ADDQ_W+1:DIVI_ADDQ_W-DIVISOR_W] + divisor_2n[DIVI_ADDQ_W+1:DIVI_ADDQ_W-DIVISOR_W]) : (dividend_2n_shift[DIVI_ADDQ_W+1:DIVI_ADDQ_W-DIVISOR_W] - divisor_2n[DIVI_ADDQ_W+1:DIVI_ADDQ_W-DIVISOR_W]);
// Extract final dividend and its sign
assign  dividend_2n_addsub[DIVI_ADDQ_W-1-DIVISOR_W:0] = dividend_2n_shift[DIVI_ADDQ_W-1-DIVISOR_W:0];
assign  {dividend_2n_sign,dividend_2n_final} = {dividend_2n_addsub[DIVI_ADDQ_W+1:1],~dividend_2n_addsub[DIVI_ADDQ_W+1]};
//assign  {dividend_2n_sign,dividend_2n_final} = {~dividend_2n_addsub[DIVI_ADDQ_W+1],dividend_2n_addsub[DIVI_ADDQ_W+1:1]};

endmodule
