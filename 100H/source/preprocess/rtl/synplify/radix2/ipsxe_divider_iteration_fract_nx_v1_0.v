
//`timescale 1ns/1ps
// Module iteration
// This module performs one iteration of a division operation using shift and add/subtract operations.
module ipsxe_divider_iteration_fract_nx_v1_0(
    dividend_2n, // Dividend input
    divisor_2n, // Divisor input
    dividend_2n_final,// Final dividend output
    quotient_bit
    );

// Width of the dividend and divisor inputs
parameter    DIVI_ADDQ_W = 7;
parameter    DIVI_ITR_REM =2;
localparam   DIVI_ITR=(DIVI_ADDQ_W + 1)*(DIVI_ITR_REM-1);

input  [DIVI_ADDQ_W:0] dividend_2n; // Dividend input, with width twice the DIVI_ADDQ_W
input  [DIVI_ADDQ_W+1:0] divisor_2n; // Divisor input, with width twice the DIVI_ADDQ_W plus one for sign bit
output [DIVI_ADDQ_W:0] dividend_2n_final; // Final dividend output, with width twice the DIVI_ADDQ_W
output [DIVI_ITR_REM-1:0]quotient_bit; // Final dividend output, with width twice the DIVI_ADDQ_W

// Wire for the dividend after shifting

// Wire for the dividend after add/sub operation
// Shift dividend to left by one
generate
    if(DIVI_ITR_REM==1)begin
        ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_ipsxe_divider_iteration_fract_v1_0(
                .dividend_2n(dividend_2n),
                .divisor_2n(divisor_2n),
                .dividend_2n_final(dividend_2n_final),
                .quotient_bit(quotient_bit[0]));
    end
    else begin
        wire   [DIVI_ITR-1:0] dividend_2n_shift;
        genvar i;
            // Unroll the iteration for DIVI_ADDQ_W times using generate for loop
            for (i=0;i<DIVI_ITR_REM;i=i+1) begin: iteration_n
                if(i==0)begin
                    // For the first iteration, use the initial dividend and divisor inputs
                    ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_ipsxe_divider_iteration_fract_v1_0(
                        .dividend_2n(dividend_2n),
                        .divisor_2n(divisor_2n),
                        .dividend_2n_final(dividend_2n_shift[DIVI_ADDQ_W:0]),
                        .quotient_bit(quotient_bit[DIVI_ITR_REM-1]));
                end
                else begin
                    // For all other iterations, use the outputs from previous iterations
                    if(i==(DIVI_ITR_REM-1))begin
                        // For the last iteration, also account for the sign of the dividend
                        ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_ipsxe_divider_iteration_fract_v1_0(
                            .dividend_2n(dividend_2n_shift[i*(DIVI_ADDQ_W+1)-1:(i-1)*(DIVI_ADDQ_W+1)]),
                            .divisor_2n(divisor_2n),
                            .dividend_2n_final(dividend_2n_final),
                            .quotient_bit(quotient_bit[0]));
                    end
                    else begin
                        ipsxe_divider_iteration_fract_v1_0 #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_ipsxe_divider_iteration_fract_v1_0(
                            .dividend_2n(dividend_2n_shift[i*(DIVI_ADDQ_W+1)-1:(i-1)*(DIVI_ADDQ_W+1)]),
                            .divisor_2n(divisor_2n),
                            .dividend_2n_final(dividend_2n_shift[(i+1)*(DIVI_ADDQ_W+1)-1:i*(DIVI_ADDQ_W+1)]),
                            .quotient_bit(quotient_bit[DIVI_ITR_REM-1-i]));
                    end
                end
            end
    end
endgenerate
endmodule
