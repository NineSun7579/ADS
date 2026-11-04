
//`timescale 1ns/1ps
// Module iteration
// This module performs one iteration of a division operation using shift and add/subtract operations.
module ipsxe_divider_iteration_v1_0(
    dividend_2n, // Dividend input
    divisor_2n, // Divisor input
    dividend_2n_final, // Final dividend output
    dividend_2n_sign
    );

// Width of the dividend and divisor inputs
parameter    DIVI_ADDQ_W = 7;

input  [2*DIVI_ADDQ_W:0] dividend_2n; // Dividend input, with width twice the DIVI_ADDQ_W
input  [2*DIVI_ADDQ_W+1:0] divisor_2n; // Divisor input, with width twice the DIVI_ADDQ_W plus one for sign bit
output [2*DIVI_ADDQ_W:0] dividend_2n_final; // Final dividend output, with width twice the DIVI_ADDQ_W
output dividend_2n_sign;
// Wire for the dividend after shifting
wire   [2*DIVI_ADDQ_W+1:0] dividend_2n_shift;
// Wire for the dividend after add/sub operation
wire   [2*DIVI_ADDQ_W+1:0] dividend_2n_addsub;

// Shift dividend to left by one
assign  dividend_2n_shift = {dividend_2n, 1'b0};   
// Perform add/sub operation based on the sign bit
assign  dividend_2n_addsub = dividend_2n_shift[2*DIVI_ADDQ_W+1]?
    (dividend_2n_shift + divisor_2n) : (dividend_2n_shift - divisor_2n);
// Extract final dividend and its sign
assign  {dividend_2n_sign,dividend_2n_final} = {dividend_2n_addsub[2*DIVI_ADDQ_W+1:1],~dividend_2n_addsub[2*DIVI_ADDQ_W+1]};

endmodule
