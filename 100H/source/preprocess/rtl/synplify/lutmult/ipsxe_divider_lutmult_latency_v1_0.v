module ipsxe_divider_lutmult_latency_v1_0#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8,
    parameter SIGNED = 0,
    parameter LATENCY = 2
)
(
    input wire clk,
    input wire rstn,
    input wire clk_en,
    input wire [DIVIDEND_WIDTH-1:0] quotient_stage5_signed_in,
    input wire [DIVISOR_WIDTH-1:0] remainder_stage5_signed_in,
    input wire [DIVIDEND_WIDTH-1:0] quotient_stage5_unsigned_in,
    input wire [DIVISOR_WIDTH-1:0] remainder_stage5_unsigned_in,
    input wire dividend_sign_bit_in_signed,
    input wire divisor_sign_bit_in_signed,
    output wire [DIVIDEND_WIDTH-1:0] quotient_stage5_signed_out,
    output wire [DIVISOR_WIDTH-1:0] remainder_stage5_signed_out,
    output wire [DIVIDEND_WIDTH-1:0] quotient_stage5_unsigned_out,
    output wire [DIVISOR_WIDTH-1:0] remainder_stage5_unsigned_out,
    output wire dividend_sign_bit_out_signed,
    output wire divisor_sign_bit_out_signed
);

    generate
        if (LATENCY == 0) begin
            if (SIGNED == 1) begin
                assign quotient_stage5_signed_out = quotient_stage5_signed_in;
                assign remainder_stage5_signed_out = remainder_stage5_signed_in;
                assign dividend_sign_bit_out_signed = dividend_sign_bit_in_signed;
                assign divisor_sign_bit_out_signed = divisor_sign_bit_in_signed;
            end else begin
                assign quotient_stage5_unsigned_out = quotient_stage5_unsigned_in;
                assign remainder_stage5_unsigned_out = remainder_stage5_unsigned_in;
            end
        end else if(LATENCY == 1) begin
        if (SIGNED == 1) begin
            reg [DIVIDEND_WIDTH-1:0] quotient_stage5_signed_reg={DIVIDEND_WIDTH{1'b0}};
            reg [DIVISOR_WIDTH-1:0] remainder_stage5_signed_reg={DIVISOR_WIDTH{1'b0}};
            reg dividend_sign_bit_signed_reg=0;
            reg divisor_sign_bit_signed_reg=0;

            assign quotient_stage5_signed_out = quotient_stage5_signed_reg;
            assign remainder_stage5_signed_out = remainder_stage5_signed_reg;
            assign dividend_sign_bit_out_signed = dividend_sign_bit_signed_reg;
            assign divisor_sign_bit_out_signed = divisor_sign_bit_signed_reg;

            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    quotient_stage5_signed_reg <= 0;
                    remainder_stage5_signed_reg <= 0;
                    dividend_sign_bit_signed_reg <= 0;
                    divisor_sign_bit_signed_reg <= 0;
                end else if (clk_en) begin
                    quotient_stage5_signed_reg <= quotient_stage5_signed_in;
                    remainder_stage5_signed_reg <= remainder_stage5_signed_in;
                    dividend_sign_bit_signed_reg <= dividend_sign_bit_in_signed;
                    divisor_sign_bit_signed_reg <= divisor_sign_bit_in_signed;
                end else begin
                    quotient_stage5_signed_reg <= quotient_stage5_signed_reg;
                    remainder_stage5_signed_reg <= remainder_stage5_signed_reg;
                    dividend_sign_bit_signed_reg <= dividend_sign_bit_signed_reg;
                    divisor_sign_bit_signed_reg <= divisor_sign_bit_signed_reg;
                end
            end
        end else begin
            reg [DIVIDEND_WIDTH-1:0] quotient_stage5_unsigned_reg={DIVIDEND_WIDTH{1'b0}};
            reg [DIVISOR_WIDTH-1:0] remainder_stage5_unsigned_reg={DIVISOR_WIDTH{1'b0}};

            assign quotient_stage5_unsigned_out = quotient_stage5_unsigned_reg;
            assign remainder_stage5_unsigned_out = remainder_stage5_unsigned_reg;

            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    quotient_stage5_unsigned_reg <= 0;
                    remainder_stage5_unsigned_reg <= 0;
                end else if (clk_en) begin
                    quotient_stage5_unsigned_reg <= quotient_stage5_unsigned_in;
                    remainder_stage5_unsigned_reg <= remainder_stage5_unsigned_in;
                end else begin
                    quotient_stage5_unsigned_reg <= quotient_stage5_unsigned_reg;
                    remainder_stage5_unsigned_reg <= remainder_stage5_unsigned_reg;
                end
            end
        end
        end else begin
        if (SIGNED == 1) begin

            reg [DIVIDEND_WIDTH-1:0] quotient_stage5_signed_reg  [0:LATENCY-1];
            reg [DIVISOR_WIDTH-1:0] remainder_stage5_signed_reg [0:LATENCY-1];
            reg dividend_sign_bit_signed_reg [0:LATENCY-1];
            reg divisor_sign_bit_signed_reg [0:LATENCY-1];
            integer i;
            


            assign quotient_stage5_signed_out = quotient_stage5_signed_reg[LATENCY-1];
            assign remainder_stage5_signed_out = remainder_stage5_signed_reg[LATENCY-1];
            assign dividend_sign_bit_out_signed = dividend_sign_bit_signed_reg[LATENCY-1];
            assign divisor_sign_bit_out_signed = divisor_sign_bit_signed_reg[LATENCY-1];

            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    for (i=0; i<LATENCY; i=i+1) begin
                        quotient_stage5_signed_reg[i] <= 0;
                        remainder_stage5_signed_reg[i] <= 0;
                        dividend_sign_bit_signed_reg[i] <= 0;
                        divisor_sign_bit_signed_reg[i] <= 0;
                    end
                end else if (clk_en) begin
                    for (i=LATENCY-1; i>0; i=i-1) begin
                        quotient_stage5_signed_reg[i] <= quotient_stage5_signed_reg[i-1];
                        remainder_stage5_signed_reg[i] <= remainder_stage5_signed_reg[i-1];
                        dividend_sign_bit_signed_reg[i] <= dividend_sign_bit_signed_reg[i-1];
                        divisor_sign_bit_signed_reg[i] <= divisor_sign_bit_signed_reg[i-1];
                    end
                    quotient_stage5_signed_reg[0] <= quotient_stage5_signed_in;
                    remainder_stage5_signed_reg[0] <= remainder_stage5_signed_in;
                    dividend_sign_bit_signed_reg[0] <= dividend_sign_bit_in_signed;
                    divisor_sign_bit_signed_reg[0] <= divisor_sign_bit_in_signed;
                end else begin
                    for (i=LATENCY-1; i>-1; i=i-1) begin
                        quotient_stage5_signed_reg[i] <= quotient_stage5_signed_reg[i];
                        remainder_stage5_signed_reg[i] <= remainder_stage5_signed_reg[i];
                        dividend_sign_bit_signed_reg[i] <= dividend_sign_bit_signed_reg[i];
                        divisor_sign_bit_signed_reg[i] <= divisor_sign_bit_signed_reg[i];
                    end
                end
            end
            
            
            integer j;
            initial begin
            for (j=0;j<LATENCY;j=j+1) begin
                quotient_stage5_signed_reg[j] = {DIVIDEND_WIDTH{1'b0}};
                remainder_stage5_signed_reg[j] = {DIVISOR_WIDTH{1'b0}};
                dividend_sign_bit_signed_reg[j] = 1'b0;
                divisor_sign_bit_signed_reg[j] = 1'b0;
            end
            end
            
        end else begin
            reg [DIVIDEND_WIDTH-1:0] quotient_stage5_unsigned_reg [LATENCY-1:0];
            reg [DIVISOR_WIDTH-1:0] remainder_stage5_unsigned_reg [LATENCY-1:0];

            assign quotient_stage5_unsigned_out = quotient_stage5_unsigned_reg[LATENCY-1];
            assign remainder_stage5_unsigned_out = remainder_stage5_unsigned_reg[LATENCY-1];

            integer i;
            always @(posedge clk or negedge rstn) begin
                if (!rstn) begin
                    for (i=0; i<LATENCY; i=i+1) begin
                        quotient_stage5_unsigned_reg[i] <= 0;
                        remainder_stage5_unsigned_reg[i] <= 0;
                    end
                end else if (clk_en) begin
                    for (i=LATENCY-1; i>0; i=i-1) begin
                        quotient_stage5_unsigned_reg[i] <= quotient_stage5_unsigned_reg[i-1];
                        remainder_stage5_unsigned_reg[i] <= remainder_stage5_unsigned_reg[i-1];
                    end
                    quotient_stage5_unsigned_reg[0] <= quotient_stage5_unsigned_in;
                    remainder_stage5_unsigned_reg[0] <= remainder_stage5_unsigned_in;
                end else begin
                    for (i=LATENCY-1; i>-1; i=i-1) begin
                        quotient_stage5_unsigned_reg[i] <= quotient_stage5_unsigned_reg[i];
                        remainder_stage5_unsigned_reg[i] <= remainder_stage5_unsigned_reg[i];
                    end
                end 
            end
        end
        end
    endgenerate
endmodule
