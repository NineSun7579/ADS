module ipsxe_divider_lutmult_core_latency_5_v1_0#(
    parameter DIVIDEND_WIDTH = 8,
    parameter SIGNED = 0,
    parameter DIVISOR_WIDTH = 8
)
    (
    input wire clk,
    input wire rstn,
    input wire clk_en,
    input wire [DIVIDEND_WIDTH-1:0] dividend_signed, // the absolute value under signed mode
    input wire [DIVISOR_WIDTH-1:0] divisor_signed,// the absolute value under signed mode
    input wire [DIVIDEND_WIDTH-1:0] dividend_unsigned,// input under unsigned mode
    input wire [DIVISOR_WIDTH-1:0] divisor_unsigned,// input under unsigned mode
    input wire dividend_sign_bit_pass_signed,//input signed bit under signed mode
    input wire divisor_sign_bit_pass_signed,//input signed bit under signed mode

    output reg dividend_sign_bit_out_signed=0,// pass the signed bit with its operator
    output reg divisor_sign_bit_out_signed=0,// pass the signed bit with its operator
    input wire [16:0] reciprocal_table, //// the output of bram, used as multiplier in lutmult algorithm
    output reg [DIVIDEND_WIDTH-1:0] quotient_stage5_signed={DIVIDEND_WIDTH{1'b0}},// the register of the final stage in the pipelined, which is the output result
    output reg [DIVISOR_WIDTH-1:0] remainder_stage5_signed={DIVISOR_WIDTH{1'b0}},// the register of the final stage in the pipelined, which is the output result
    output reg [DIVIDEND_WIDTH-1:0] quotient_stage5_unsigned={DIVIDEND_WIDTH{1'b0}},// the register of the final stage in the pipelined, which is the output result
    output reg [DIVISOR_WIDTH-1:0] remainder_stage5_unsigned={DIVISOR_WIDTH{1'b0}}// the register of the final stage in the pipelined, which is the output result
    );

    // Declare registers
    reg [16:0] reciprocal_stage1={17{1'b0}};
    generate
    if (SIGNED == 1) begin//A generate if block. Circuit is generated only when SIGNED is 1
        reg [DIVIDEND_WIDTH-1:0] dividend_stage1={DIVIDEND_WIDTH{1'b0}}, dividend_stage2={DIVIDEND_WIDTH{1'b0}}, dividend_stage3={DIVIDEND_WIDTH{1'b0}}, dividend_stage4={DIVIDEND_WIDTH{1'b0}};//declare the registers of each stage
        reg [DIVISOR_WIDTH-1:0] divisor_stage1={DIVISOR_WIDTH{1'b0}}, divisor_stage2={DIVISOR_WIDTH{1'b0}}, divisor_stage3={DIVISOR_WIDTH{1'b0}}, divisor_stage4={DIVISOR_WIDTH{1'b0}};//declare the registers of each stage
        reg [DIVIDEND_WIDTH+15:0] product_stage2={DIVIDEND_WIDTH+16{1'b0}};//declare the registers of each stage
        reg [DIVIDEND_WIDTH-1:0] quotient_stage3={DIVIDEND_WIDTH{1'b0}}, quotient_stage4={DIVIDEND_WIDTH{1'b0}};//declare the registers of each stage
        reg [DIVIDEND_WIDTH-1:0] remainder_stage4={DIVIDEND_WIDTH{1'b0}};//declare the registers of each stage
        reg dividend_sign_bit_stage1=0, dividend_sign_bit_stage2=0, dividend_sign_bit_stage3 =0, dividend_sign_bit_stage4=0;//declare the registers of each stage
        reg divisor_sign_bit_stage1=0, divisor_sign_bit_stage2=0, divisor_sign_bit_stage3=0, divisor_sign_bit_stage4=0;//declare the registers of each stage
        // Stage 1
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                dividend_stage1 <= 0;
                divisor_stage1 <= 0;
                reciprocal_stage1 <= 0;
                dividend_sign_bit_stage1 <= 0;
                divisor_sign_bit_stage1 <= 0;
            end
            else if (clk_en) begin //initiate the dividend, divisor, multiplier and signed bit in stage 1
                dividend_stage1 <= dividend_signed;
                divisor_stage1 <= divisor_signed;
                reciprocal_stage1 <= reciprocal_table;
                dividend_sign_bit_stage1 <= dividend_sign_bit_pass_signed;
                divisor_sign_bit_stage1 <= divisor_sign_bit_pass_signed;
            end
            else begin //initiate the dividend, divisor, multiplier and signed bit in stage 1
                dividend_stage1 <= dividend_stage1;
                divisor_stage1 <= divisor_stage1;
                reciprocal_stage1 <= reciprocal_stage1;
                dividend_sign_bit_stage1 <= dividend_sign_bit_stage1;
                divisor_sign_bit_stage1 <= divisor_sign_bit_stage1;
            end
        end

        // Stage 2
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                product_stage2 <= 0;
                dividend_stage2 <= 0;
                divisor_stage2 <= 0;
                dividend_sign_bit_stage2 <= 0;
                divisor_sign_bit_stage2 <= 0;
            end
            else if (clk_en) begin // calculate the product of dividend and multiplier, and pass other data
                product_stage2 <= dividend_stage1 * reciprocal_stage1;
                dividend_stage2 <= dividend_stage1;
                divisor_stage2 <= divisor_stage1;
                dividend_sign_bit_stage2 <= dividend_sign_bit_stage1;
                divisor_sign_bit_stage2 <= divisor_sign_bit_stage1;
            end
            else begin // calculate the product of dividend and multiplier, and pass other data
                product_stage2 <= product_stage2;
                dividend_stage2 <= dividend_stage2;
                divisor_stage2 <= divisor_stage2;
                dividend_sign_bit_stage2 <= dividend_sign_bit_stage2;
                divisor_sign_bit_stage2 <= divisor_sign_bit_stage2;
            end
        end

        // Stage 3
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                quotient_stage3 <= 0;
                dividend_stage3 <= 0;
                divisor_stage3 <= 0;
                dividend_sign_bit_stage3 <= 0;
                divisor_sign_bit_stage3 <= 0;
            end
            else if (clk_en) begin// shift the product to get the quotient, pass other data
                //quotient_stage3 <= product_stage2 >> 17;
                quotient_stage3 <= product_stage2[DIVIDEND_WIDTH+15:17];
                dividend_stage3 <= dividend_stage2;
                divisor_stage3 <= divisor_stage2;
                dividend_sign_bit_stage3 <= dividend_sign_bit_stage2;
                divisor_sign_bit_stage3 <= divisor_sign_bit_stage2;
            end
            else begin// shift the product to get the quotient, pass other data
                //quotient_stage3 <= product_stage2 >> 17;
                quotient_stage3 <= quotient_stage3;
                dividend_stage3 <= dividend_stage3;
                divisor_stage3 <= divisor_stage3;
                dividend_sign_bit_stage3 <= dividend_sign_bit_stage3;
                divisor_sign_bit_stage3 <= divisor_sign_bit_stage3;
            end
        end

        // Stage 4
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                remainder_stage4 <= 0;
                //dividend_stage4 <= 0;
                divisor_stage4 <= 0;
                quotient_stage4 <= 0;
                dividend_sign_bit_stage4 <= 0;
                divisor_sign_bit_stage4 <= 0;
            end
            else if (clk_en) begin //calculate remainder, pass othaer data
                remainder_stage4 <= dividend_stage3 - (divisor_stage3 * quotient_stage3);
                //dividend_stage4 <= dividend_stage3;
                divisor_stage4 <= divisor_stage3;
                quotient_stage4 <= quotient_stage3;
                dividend_sign_bit_stage4 <= dividend_sign_bit_stage3;
                divisor_sign_bit_stage4 <= divisor_sign_bit_stage3;
            end
            else begin //calculate remainder, pass othaer data
                remainder_stage4 <= remainder_stage4;
                //dividend_stage4 <= dividend_stage3;
                divisor_stage4 <= divisor_stage4;
                quotient_stage4 <= quotient_stage4;
                dividend_sign_bit_stage4 <= dividend_sign_bit_stage4;
                divisor_sign_bit_stage4 <= divisor_sign_bit_stage4;
            end
        end


        // Stage 5
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                quotient_stage5_signed <= 0;
                remainder_stage5_signed <= 0;
                dividend_sign_bit_out_signed <= 0;
                divisor_sign_bit_out_signed <= 0;
            end
            else if (clk_en) begin //correct the quotient and remainder, which are the outputs
                dividend_sign_bit_out_signed <= dividend_sign_bit_stage4;
                divisor_sign_bit_out_signed <= divisor_sign_bit_stage4;

                if (remainder_stage4 >= divisor_stage4 && divisor_stage4 != 1'b0) begin
                    quotient_stage5_signed <= quotient_stage4 + 1;
                    remainder_stage5_signed <= remainder_stage4 - divisor_stage4;
                end
                else begin
                    quotient_stage5_signed <= quotient_stage4;
                    remainder_stage5_signed <= remainder_stage4;
                end
            end
            else begin //correct the quotient and remainder, which are the outputs
                dividend_sign_bit_out_signed <= dividend_sign_bit_out_signed;
                divisor_sign_bit_out_signed <= divisor_sign_bit_out_signed;
                quotient_stage5_signed <= quotient_stage5_signed;
                remainder_stage5_signed <= remainder_stage5_signed;
            end
        end
    end
    else begin //A generate if block. Circuit is generated only when SIGNED is 0
        reg [DIVIDEND_WIDTH-1:0] dividend_stage1={DIVIDEND_WIDTH{1'b0}}, dividend_stage2={DIVIDEND_WIDTH{1'b0}}, dividend_stage3={DIVIDEND_WIDTH{1'b0}};//decalre registers of each stage in pipelined
        reg [DIVISOR_WIDTH-1:0] divisor_stage1={DIVISOR_WIDTH{1'b0}}, divisor_stage2={DIVISOR_WIDTH{1'b0}}, divisor_stage3={DIVISOR_WIDTH{1'b0}}, divisor_stage4={DIVISOR_WIDTH{1'b0}};//decalre registers of each stage in pipelined
        reg [DIVIDEND_WIDTH+16:0] product_stage2={DIVIDEND_WIDTH+17{1'b0}};//decalre registers of each stage in pipelined
        reg [DIVIDEND_WIDTH-1:0] quotient_stage3={DIVIDEND_WIDTH{1'b0}}, quotient_stage4={DIVIDEND_WIDTH{1'b0}};//decalre registers of each stage in pipelined
        reg [DIVIDEND_WIDTH-1:0] remainder_stage4={DIVIDEND_WIDTH{1'b0}};//decalre registers of each stage in pipelined
        // Stage 1
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                dividend_stage1 <= 0;
                divisor_stage1 <= 0;
                reciprocal_stage1 <= 0;
            end
            else if (clk_en) begin // initiate the data
                dividend_stage1 <= dividend_unsigned;
                divisor_stage1 <= divisor_unsigned;
                reciprocal_stage1 <= reciprocal_table;
            end
            else begin // initiate the data
                dividend_stage1 <= dividend_stage1;
                divisor_stage1 <= divisor_stage1;
                reciprocal_stage1 <= reciprocal_stage1;
            end
        end

         // Stage 2
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                product_stage2 <= 0;
                dividend_stage2 <= 0;
                divisor_stage2 <= 0;
            end
            else if (clk_en) begin // cauculate product and pass all data
                product_stage2 <= dividend_stage1 * reciprocal_stage1;
                dividend_stage2 <= dividend_stage1;
                divisor_stage2 <= divisor_stage1;
            end
            else begin // cauculate product and pass all data
                product_stage2 <= product_stage2;
                dividend_stage2 <= dividend_stage2;
                divisor_stage2 <= divisor_stage2;
            end
        end

        // Stage 3
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                quotient_stage3 <= 0;
                dividend_stage3 <= 0;
                divisor_stage3 <= 0;
            end
            else if (clk_en) begin // cauculate quotient and pass all data
                //quotient_stage3 <= product_stage2 >> 17;
                quotient_stage3 <= product_stage2[DIVIDEND_WIDTH+16:17];
                dividend_stage3 <= dividend_stage2;
                divisor_stage3 <= divisor_stage2;
            end
            else begin // cauculate quotient and pass all data
                //quotient_stage3 <= product_stage2 >> 17;
                quotient_stage3 <= quotient_stage3;
                dividend_stage3 <= dividend_stage3;
                divisor_stage3 <= divisor_stage3;
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
            else if (clk_en) begin // cauculate remainder and pass all data
                remainder_stage4 <= dividend_stage3 - (divisor_stage3 * quotient_stage3);
                //dividend_stage4 <= dividend_stage3;
                divisor_stage4 <= divisor_stage3;
                quotient_stage4 <= quotient_stage3;
            end
            else begin // cauculate remainder and pass all data
                remainder_stage4 <= remainder_stage4;
                //dividend_stage4 <= dividend_stage3;
                divisor_stage4 <= divisor_stage4;
                quotient_stage4 <= quotient_stage4;
            end
        end

        // Stage 5
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                quotient_stage5_unsigned <= 0;
                remainder_stage5_unsigned <= 0;
            end
            else if (clk_en) begin //correct result and output
                if (remainder_stage4 >= divisor_stage4 && divisor_stage4 != 1'b0) begin
                    quotient_stage5_unsigned <= quotient_stage4 + 1;
                    remainder_stage5_unsigned <= remainder_stage4 - divisor_stage4;
                end
                else begin
                    quotient_stage5_unsigned <= quotient_stage4;
                    remainder_stage5_unsigned <= remainder_stage4;
                end
            end
            else begin //correct result and output
                    quotient_stage5_unsigned <= quotient_stage5_unsigned;
                    remainder_stage5_unsigned <= remainder_stage5_unsigned;
            end
        end
    end
    endgenerate
endmodule
