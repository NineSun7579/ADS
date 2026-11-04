

module Lutmult_core#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8
)
    (
    input wire clk,
    input wire rstn,
    // `ifdef SIGNED
    
    // `else
    
    input wire [DIVIDEND_WIDTH-1:0] dividend,
    input wire [DIVISOR_WIDTH-1:0] divisor,
    // `endif
    
    input wire [10:0] reciprocal_table,
    // `ifdef SIGNED
    
    // `else
    
    output reg [DIVIDEND_WIDTH-1:0] quotient_stage5,
    output reg [DIVISOR_WIDTH-1:0] remainder_stage5
    // `endif
    
    );

    // Declare registers
    // `ifdef SIGNED
    
    //`else
    
    reg [DIVIDEND_WIDTH-1:0] dividend_stage1, dividend_stage2, dividend_stage3;
    reg [DIVISOR_WIDTH-1:0] divisor_stage1, divisor_stage2, divisor_stage3, divisor_stage4;
    reg [DIVIDEND_WIDTH+10:0] product_stage2;
    reg [DIVIDEND_WIDTH-1:0] quotient_stage3, quotient_stage4;
    reg [DIVISOR_WIDTH-1:0] remainder_stage4;
    // `endif
    
    
    reg [10:0] reciprocal_stage1;

    
    // Stage 1
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            dividend_stage1 <= 0;
            divisor_stage1 <= 0;
            reciprocal_stage1 <= 0;
        end
        else begin
            dividend_stage1 <= dividend;
            divisor_stage1 <= divisor;
            reciprocal_stage1 <= reciprocal_table;
        end
    end

   // Stage 2
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            product_stage2 <= 0;
            dividend_stage2 <= 0;
            divisor_stage2 <= 0;
        end
        else begin
            product_stage2 <= dividend_stage1 * reciprocal_stage1;
            dividend_stage2 <= dividend_stage1;
            divisor_stage2 <= divisor_stage1;
        end
    end

    // Stage 3
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            quotient_stage3 <= 0;
            dividend_stage3 <= 0;
            divisor_stage3 <= 0;
        end
        else begin
            //quotient_stage3 <= product_stage2 >> 11;
            quotient_stage3 <= product_stage2[DIVIDEND_WIDTH+10:11];
            dividend_stage3 <= dividend_stage2;
            divisor_stage3 <= divisor_stage2;
        end
    end

    // Stage 4
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            remainder_stage4 <= 0;
            //dividend_stage4 <= 0;
            divisor_stage4 <= 0;
            quotient_stage4 <= 0;
        end
        else begin
            remainder_stage4 <= dividend_stage3 - (divisor_stage3 * quotient_stage3);
            //dividend_stage4 <= dividend_stage3;
            divisor_stage4 <= divisor_stage3;
            quotient_stage4 <= quotient_stage3;
        end
    end


    // Stage 5
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            quotient_stage5 <= 0;
            remainder_stage5 <= 0;
        end
        else begin

            if (remainder_stage4 >= divisor_stage4) begin
                quotient_stage5 <= quotient_stage4 + 1;
                remainder_stage5 <= remainder_stage4 - divisor_stage4;
            end
            else begin
                quotient_stage5 <= quotient_stage4;
                remainder_stage5 <= remainder_stage4;
            end
        end
    end

   
endmodule
