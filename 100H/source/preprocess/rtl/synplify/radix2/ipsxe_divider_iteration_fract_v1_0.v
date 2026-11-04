
//`timescale 1ns/1ps
// Module iteration
// This module performs one iteration of a division operation using shift and add/subtract operations.
module ipsxe_divider_iteration_fract_v1_0(
    dividend_2n, // Dividend input
    divisor_2n, // Divisor input
    dividend_2n_final, // Final dividend output
    quotient_bit 
    );

// Width of the dividend and divisor inputs
parameter    DIVI_ADDQ_W = 7;
// parameter    DIVISOR_W = 4;
// parameter    DIVIDEND_W = 4;

input  [DIVI_ADDQ_W:0] dividend_2n; // Dividend input, with width twice the DIVI_ADDQ_W
input  [DIVI_ADDQ_W+1:0] divisor_2n; // Divisor input, with width twice the DIVI_ADDQ_W plus one for sign bit
output [DIVI_ADDQ_W:0] dividend_2n_final; // Final dividend output, with width twice the DIVI_ADDQ_W
output quotient_bit;
// Wire for the dividend after shifting
wire   [DIVI_ADDQ_W+1:0] dividend_2n_shift;
wire   [DIVI_ADDQ_W+1:0] dividend_2n_addsub;
// Wire for the dividend after add/sub operation
// wire   [DIVI_ADDQ_W+1:0] divisor_2n;
// assign divisor_2n={{(2){1'b0}},divisor,{DIVIDEND_W{1'b0}}};  
// Shift dividend to left by one
assign  dividend_2n_shift = {dividend_2n, 1'b0};   
// Perform add/sub operation based on the sign bit
assign  dividend_2n_addsub = dividend_2n_shift[DIVI_ADDQ_W+1]?
    (dividend_2n_shift + divisor_2n) : (dividend_2n_shift - divisor_2n);
// Extract final dividend and its sign
assign  {dividend_2n_final,quotient_bit} = {dividend_2n_addsub[DIVI_ADDQ_W:0],~dividend_2n_addsub[DIVI_ADDQ_W+1]};

endmodule
