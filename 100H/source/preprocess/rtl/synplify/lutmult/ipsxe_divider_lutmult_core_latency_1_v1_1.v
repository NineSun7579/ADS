module ipsxe_divider_lutmult_core_latency_1_v1_1#(
    parameter DIVIDEND_WIDTH = 8,
    parameter SIGNED = 0,
    parameter DIVISOR_WIDTH = 8
)
(
    input wire clk,
    input wire rstn,
    input wire clk_en,
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

// pure combinational logic, for 1 latency configuration

    generate
    if (SIGNED == 1) begin
        wire [DIVIDEND_WIDTH+15:0] product_signed ;
        wire [DIVIDEND_WIDTH-1:0] quotient_stage3_signed ;
        wire [DIVIDEND_WIDTH-1:0] remainder_stage4_signed;
        reg [DIVIDEND_WIDTH-1:0] quotient_stage3_signed_reg={DIVIDEND_WIDTH{1'b0}};
        reg [DIVIDEND_WIDTH-1:0] dividend_signed_stage3_reg={DIVIDEND_WIDTH{1'b0}};
        reg [DIVISOR_WIDTH-1:0] divisor_signed_stage3_reg={DIVISOR_WIDTH{1'b0}};
        reg dividend_sign_bit_pass_signed_reg=0;
        reg divisor_sign_bit_pass_signed_reg=0;

        assign product_signed = dividend_signed * reciprocal_table;
        assign quotient_stage3_signed = product_signed[DIVIDEND_WIDTH+15:17];
        assign remainder_stage4_signed = dividend_signed_stage3_reg - (divisor_signed_stage3_reg * quotient_stage3_signed_reg);
        assign quotient_stage5_signed = (remainder_stage4_signed >= divisor_signed_stage3_reg && divisor_signed_stage3_reg != 1'b0) ? quotient_stage3_signed_reg + 1 : quotient_stage3_signed_reg;
        assign remainder_stage5_signed = (remainder_stage4_signed >= divisor_signed_stage3_reg) ? remainder_stage4_signed - divisor_signed_stage3_reg : remainder_stage4_signed;
        assign dividend_sign_bit_out_signed = dividend_sign_bit_pass_signed_reg;
        assign divisor_sign_bit_out_signed = divisor_sign_bit_pass_signed_reg;
        
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                quotient_stage3_signed_reg <= 0;
                dividend_signed_stage3_reg <= 0;
                divisor_signed_stage3_reg <= 0;
                dividend_sign_bit_pass_signed_reg <= 0;
                divisor_sign_bit_pass_signed_reg <= 0;
            end
            else if (clk_en) begin //update the mediate reg
                quotient_stage3_signed_reg <= quotient_stage3_signed;
                dividend_signed_stage3_reg <= dividend_signed;
                divisor_signed_stage3_reg <= divisor_signed;
                dividend_sign_bit_pass_signed_reg <= dividend_sign_bit_pass_signed;
                divisor_sign_bit_pass_signed_reg <= divisor_sign_bit_pass_signed;
            end
            else begin //update the mediate reg
                quotient_stage3_signed_reg <= quotient_stage3_signed_reg;
                dividend_signed_stage3_reg <= dividend_signed_stage3_reg;
                divisor_signed_stage3_reg <= divisor_signed_stage3_reg;
                dividend_sign_bit_pass_signed_reg <= dividend_sign_bit_pass_signed_reg;
                divisor_sign_bit_pass_signed_reg <= divisor_sign_bit_pass_signed_reg;
            end
        end

    end else begin
        wire [DIVIDEND_WIDTH+16:0] product_unsigned ;
        wire [DIVIDEND_WIDTH-1:0] quotient_stage3_unsigned;
        wire [DIVIDEND_WIDTH-1:0] remainder_stage4_unsigned ;

        reg [DIVIDEND_WIDTH-1:0] quotient_stage3_unsigned_reg={DIVIDEND_WIDTH{1'b0}};    
        reg [DIVIDEND_WIDTH-1:0] dividend_unsigned_stage3_reg={DIVIDEND_WIDTH{1'b0}};
        reg [DIVISOR_WIDTH-1:0] divisor_unsigned_stage3_reg={DIVISOR_WIDTH{1'b0}};    

        assign product_unsigned = dividend_unsigned * reciprocal_table;
        assign quotient_stage3_unsigned = product_unsigned[DIVIDEND_WIDTH+16:17];
        assign remainder_stage4_unsigned = dividend_unsigned_stage3_reg - (divisor_unsigned_stage3_reg * quotient_stage3_unsigned_reg);
        assign quotient_stage5_unsigned = (remainder_stage4_unsigned >= divisor_unsigned_stage3_reg && divisor_unsigned_stage3_reg != 1'b0) ? quotient_stage3_unsigned_reg + 1 : quotient_stage3_unsigned_reg;
        assign remainder_stage5_unsigned = (remainder_stage4_unsigned >= divisor_unsigned_stage3_reg) ? remainder_stage4_unsigned - divisor_unsigned_stage3_reg : remainder_stage4_unsigned;
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                quotient_stage3_unsigned_reg <= 0;
                dividend_unsigned_stage3_reg <= 0;
                divisor_unsigned_stage3_reg <= 0;
            end
            else if (clk_en) begin //update the mediate reg
                quotient_stage3_unsigned_reg <= quotient_stage3_unsigned;
                dividend_unsigned_stage3_reg <= dividend_unsigned;
                divisor_unsigned_stage3_reg <= divisor_unsigned;
            end
            else begin //update the mediate reg
                quotient_stage3_unsigned_reg <= quotient_stage3_unsigned_reg;
                dividend_unsigned_stage3_reg <= dividend_unsigned_stage3_reg;
                divisor_unsigned_stage3_reg <= divisor_unsigned_stage3_reg;
            end
        end
    end
    endgenerate
endmodule