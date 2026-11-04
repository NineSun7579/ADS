
//`timescale 1ns/1ps
module iteration(
    dividend_2n,
    divisor_2n,
    dividend_2n_final,
    dividend_2n_sign
    );
parameter    DIVI_ADDQ_W = 7;

input  [2*DIVI_ADDQ_W:0] dividend_2n;
input  [2*DIVI_ADDQ_W+1:0] divisor_2n;
output [2*DIVI_ADDQ_W:0] dividend_2n_final;
output dividend_2n_sign;

wire   [2*DIVI_ADDQ_W+1:0] dividend_2n_shift;
wire   [2*DIVI_ADDQ_W+1:0] dividend_2n_addsub;


assign  dividend_2n_shift = {dividend_2n, 1'b0};   //shift left
assign  dividend_2n_addsub = dividend_2n_shift[2*DIVI_ADDQ_W+1]?//S:0 +divsor;s:1 -divisor
    (dividend_2n_shift + divisor_2n) : (dividend_2n_shift - divisor_2n);
assign  {dividend_2n_sign,dividend_2n_final} = {dividend_2n_addsub[2*DIVI_ADDQ_W+1:1],~dividend_2n_addsub[2*DIVI_ADDQ_W+1]} ; //quotient1]} ; //quotient
endmodule