module ipsxe_divider_lutmult_core_latency_0_v1_0#(
    parameter DIVIDEND_WIDTH = 8,
    parameter SIGNED = 0,
    parameter DIVISOR_WIDTH = 8
)
(
    input wire [DIVIDEND_WIDTH-1:0] dividend_signed, 
    input wire [DIVISOR_WIDTH-1:0] divisor_signed,
    input wire [DIVIDEND_WIDTH-1:0] dividend_unsigned,
    input wire [DIVISOR_WIDTH-1:0] divisor_unsigned,
    input wire dividend_sign_bit_pass_signed,
    input wire divisor_sign_bit_pass_signed,
    output wire dividend_sign_bit_out_signed,
    output wire divisor_sign_bit_out_signed,
    input wire [16:0] reciprocal_table, 
    output wire [DIVIDEND_WIDTH-1:0] quotient_stage5_signed,
    output wire [DIVISOR_WIDTH-1:0] remainder_stage5_signed,
    output wire [DIVIDEND_WIDTH-1:0] quotient_stage5_unsigned,
    output wire [DIVISOR_WIDTH-1:0] remainder_stage5_unsigned
);

    generate
    if (SIGNED == 1) begin
        wire [DIVIDEND_WIDTH+15:0] product_signed ;
        wire [DIVIDEND_WIDTH-1:0] quotient_stage3_signed ;
        wire [DIVIDEND_WIDTH-1:0] remainder_stage4_signed;
        
        assign product_signed = dividend_signed * reciprocal_table;
        assign quotient_stage3_signed = product_signed[DIVIDEND_WIDTH+15:17];
        assign remainder_stage4_signed = dividend_signed - (divisor_signed * quotient_stage3_signed);
        assign quotient_stage5_signed = (remainder_stage4_signed >= divisor_signed && divisor_signed != 1'b0) ? quotient_stage3_signed + 1 : quotient_stage3_signed;
        assign remainder_stage5_signed = (remainder_stage4_signed >= divisor_signed) ? remainder_stage4_signed - divisor_signed : remainder_stage4_signed;
        assign dividend_sign_bit_out_signed = dividend_sign_bit_pass_signed;
        assign divisor_sign_bit_out_signed = divisor_sign_bit_pass_signed;
        
    end else begin
        wire [DIVIDEND_WIDTH+16:0] product_unsigned ;
        wire [DIVIDEND_WIDTH-1:0] quotient_stage3_unsigned;
        wire [DIVIDEND_WIDTH-1:0] remainder_stage4_unsigned ;

        assign product_unsigned = dividend_unsigned * reciprocal_table;
        assign quotient_stage3_unsigned = product_unsigned[DIVIDEND_WIDTH+16:17];
        assign remainder_stage4_unsigned = dividend_unsigned - (divisor_unsigned * quotient_stage3_unsigned);
        assign quotient_stage5_unsigned = (remainder_stage4_unsigned >= divisor_unsigned && divisor_unsigned != 1'b0) ? quotient_stage3_unsigned + 1 : quotient_stage3_unsigned;
        assign remainder_stage5_unsigned = (remainder_stage4_unsigned >= divisor_unsigned) ? remainder_stage4_unsigned - divisor_unsigned : remainder_stage4_unsigned;
    end
    endgenerate
endmodule
