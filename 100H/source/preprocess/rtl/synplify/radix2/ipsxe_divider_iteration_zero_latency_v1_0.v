
//`timescale 1ns/1ps
// Module iteration
// This module performs one iteration of a division operation using shift and add/subtract operations.
module ipsxe_divider_iteration_zero_latency_v1_0(
    dividend, // Dividend input
    divisor, // Divisor input
    quotient_fract, // Final dividend output
    quotient, // Sign of the final dividend
    remainder
    );

// Width of the dividend and divisor inputs
parameter DIVIDEND_W = 8;  // Width of the dividend
parameter DIVISOR_W = 8;  // Width of the divisor
parameter QUOTIENT_FRACT_W = 0;  // Width of the fractional part of the quotient
parameter DIVI_ADDQ_W = 8;
parameter Remainder_Type = 0; 
localparam DIVI_ITR=(2*DIVI_ADDQ_W+2)*(DIVI_ADDQ_W-1);

input [DIVIDEND_W-1:0] dividend;             // Dividend input
input [DIVISOR_W-1:0] divisor;               // Divisor input                   
output wire [QUOTIENT_FRACT_W-1:0] quotient_fract; // Fractional part of the quotient output
output wire [DIVISOR_W-1:0] remainder;      // Remainder output
output wire [DIVIDEND_W-1:0] quotient ; 

wire [2*DIVI_ADDQ_W+1:0] dividend_2n; // Dividend input, with width twice the DIVI_ADDQ_W
wire [2*DIVI_ADDQ_W+1:0] divisor_2n; // Divisor input, with width twice the DIVI_ADDQ_W plus one for sign bit
wire [2*DIVI_ADDQ_W+1:0] dividend_2n_final; // Final dividend output, with width twice the DIVI_ADDQ_W
// Wire for the dividend after shifting
reg    [DIVISOR_W:0]   remainder_out= {{DIVISOR_W+1{1'b0}}};
wire   [DIVI_ADDQ_W-1:0] quotient_out;

generate
    if (Remainder_Type == 1) begin
        // If Remainder_Type is 1, shift dividend left by QUOTIENT_FRACT_W bits
        assign dividend_2n={{(2*DIVI_ADDQ_W+2-DIVIDEND_W-QUOTIENT_FRACT_W){1'b0}},dividend,{(QUOTIENT_FRACT_W){1'b0}}};
    end
    else begin
        // If Remainder_Type is not 1, the dividend is not shifted
        assign dividend_2n={{(2*DIVI_ADDQ_W+2-DIVIDEND_W){1'b0}},dividend}; 
    end
endgenerate

// Shift divisor left by DIVI_ADDQ_W bits
assign divisor_2n={{(DIVI_ADDQ_W-DIVISOR_W+2){1'b0}},divisor,{DIVI_ADDQ_W{1'b0}}};  

ipsxe_divider_iteration_nx_v1_0 #(.DIVI_ADDQ_W(DIVI_ADDQ_W),
               .DIVI_ITR_REM(DIVI_ADDQ_W)
              ) u_ipsxe_divider_iteration_nx_v1_0(
               .dividend_2n(dividend_2n),
               .divisor_2n(divisor_2n),
               .dividend_2n_final(dividend_2n_final[2*DIVI_ADDQ_W+1:0])
              );
generate
if (Remainder_Type == 0) begin
    always @(*) 
        if(dividend_2n_final[2*DIVI_ADDQ_W+1]) begin
            remainder_out = dividend_2n_final[DIVI_ADDQ_W+DIVISOR_W-1:DIVI_ADDQ_W]+divisor_2n[DIVI_ADDQ_W+DIVISOR_W-1:DIVI_ADDQ_W]; //r=r+d
        end 
        else begin
            remainder_out ={dividend_2n_final[DIVI_ADDQ_W+DIVISOR_W:DIVI_ADDQ_W]};
        end
    end
    assign quotient_out = dividend_2n_final[DIVI_ADDQ_W-1:0];
endgenerate

generate
    if (Remainder_Type == 1) begin
        assign quotient = quotient_out[(QUOTIENT_FRACT_W+DIVIDEND_W-1):QUOTIENT_FRACT_W];
        assign quotient_fract = quotient_out[QUOTIENT_FRACT_W-1:0];
    end 
    else begin
        assign quotient =  quotient_out[DIVIDEND_W-1:0];
        assign remainder = remainder_out[DIVISOR_W-1:0];
    end
endgenerate

endmodule