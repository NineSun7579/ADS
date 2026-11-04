// The radix2 module is a configurable radix-2 division module. This module performs the division of two numbers. 
// It supports both signed and unsigned division with various parameters to set the width of the inputs/outputs and control signals.
module ipsxe_divider_radix2_v1_0
#(
    parameter DIVIDEND_WIDTH = 8,                    // Width of the dividend
    parameter DIVISOR_WIDTH = 8,                     // Width of the divisor
    parameter QUOTIENT_FRACTIONAL_WIDTH = 2,         // Width of the fractional part of the quotient
    parameter CLK_PER_DIVISION = 1,                  // Clock cycles per division
    parameter CNT_WIDTH = 1,                         // Width of the count signal
    parameter SIGNED = 0,                            // Indicates whether the operation is signed or not
    parameter Remainder_Type = 1,                    // Type of remainder
    parameter DIVI_ADDQ_WIDTH = 10,                   // Width of the adder in the divisor pipeline
    parameter LATENCY_MODE=1,
    parameter MANUAL_LATENCY=10
)
( 
    input clk,                                       // Clock signal
    input rst_n,                                     // Reset signal (active low)
    input clk_en,                                    // Clock enable signal
    input [DIVIDEND_WIDTH-1:0] dividend,             // Dividend input
    input [DIVISOR_WIDTH-1:0] divisor,               // Divisor input
    input [CNT_WIDTH:0] cnt,  
    output wire [QUOTIENT_FRACTIONAL_WIDTH-1:0] quotient_fract, // Fractional part of the quotient output
    output wire [DIVISOR_WIDTH-1:0] remainder,       // Remainder output
    output wire [DIVIDEND_WIDTH-1:0] quotient        // Quotient output
);

    parameter DIVI_ADDQ_WIDTH_PASS = (Remainder_Type == 1) ? (DIVI_ADDQ_WIDTH - 1) : (DIVI_ADDQ_WIDTH);   // Width of the adder, depends on the remainder type
    parameter DIVI_SIGNED_WIDTH = (Remainder_Type == 1) ? (DIVIDEND_WIDTH+QUOTIENT_FRACTIONAL_WIDTH + 1) : (DIVIDEND_WIDTH + 2);

    wire [CNT_WIDTH:0] cnt_logic; // Logic for count signal
    assign cnt_logic = (CLK_PER_DIVISION == 1) ? 1'b0 : 
                       (CLK_PER_DIVISION == 2) ? cnt-1'b1 : 
                       (CLK_PER_DIVISION == 4) ? cnt-1'b1 :
                       (CLK_PER_DIVISION == 8) ? cnt-1'b1 : 
                       1'b0;  // Default to 0

    // Generate logic depending on whether the operation is signed or not
generate
    if (SIGNED == 1) begin
        // Signed division
        wire dividend_sign; // Sign bit of the dividend
        wire divisor_sign;  // Sign bit of the divisor
        wire dividend_sign_r; // Registered sign bit of the dividend
        wire divisor_sign_r; // Registered sign bit of the divisor

        wire [DIVIDEND_WIDTH-1:0] dividend_unsigned; // Unsigned dividend
        wire [DIVISOR_WIDTH-1:0] divisor_unsigned; // Unsigned divisor
        wire [QUOTIENT_FRACTIONAL_WIDTH-2:0] quotient_fract_unsigned; // Unsigned fractional part of the quotient
        wire [DIVISOR_WIDTH-1:0] remainder_unsigned; // Unsigned remainder
        wire [DIVIDEND_WIDTH-1:0] quotient_unsigned; // Unsigned quotient
        reg [DIVIDEND_WIDTH-1:0] dividend_unsigned_r= {(DIVIDEND_WIDTH){1'b0}}; // Registered unsigned dividend
        reg [DIVISOR_WIDTH-1:0] divisor_unsigned_r= {(DIVISOR_WIDTH){1'b0}}; // Registered unsigned divisor
        assign dividend_sign = dividend[DIVIDEND_WIDTH-1]; // Extract sign bit of the dividend
        assign divisor_sign =  divisor[DIVISOR_WIDTH-1]; // Extract sign bit of the divisor
        assign dividend_unsigned = (dividend_sign)?(~dividend+1):dividend;
//                                   ((!(|dividend[DIVIDEND_WIDTH-2:0]))?dividend:{1'b0,((~dividend[DIVIDEND_WIDTH-2:0])+1)}):
//                                    dividend[DIVIDEND_WIDTH-1:0]; // Convert dividend to unsigned
        assign divisor_unsigned = (divisor_sign)? (~divisor+1) : divisor;
//                                  ((!(|divisor[DIVISOR_WIDTH-2:0]))?divisor:{1'b0,((~divisor[DIVISOR_WIDTH-2:0])+1)}):
//                                   divisor[DIVISOR_WIDTH-1:0]; // Convert divisor to unsigned
        // Clock process for register update
        always@(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                dividend_unsigned_r <= {(DIVIDEND_WIDTH){1'b0}};
                divisor_unsigned_r <= {(DIVISOR_WIDTH) {1'b0}};
            end
            else
             if(clk_en) begin
                dividend_unsigned_r <= dividend_unsigned;
                divisor_unsigned_r <= divisor_unsigned;
            end
            else begin
                dividend_unsigned_r <= dividend_unsigned_r;
                divisor_unsigned_r <= divisor_unsigned_r;
            end
        end
        // Instance of radix2_process module for signed division
      
        if(LATENCY_MODE == 1)begin
            reg    [MANUAL_LATENCY-1:0]dividend_sign_itr_r= {(MANUAL_LATENCY) {1'b0}};
            reg    [MANUAL_LATENCY-1:0]divisor_sign_itr_r= {(MANUAL_LATENCY) {1'b0}};
            always @(posedge clk or negedge rst_n)
                if(!rst_n)begin
                    dividend_sign_itr_r <= {(MANUAL_LATENCY) {1'b0}};
                    divisor_sign_itr_r <= {MANUAL_LATENCY {1'b0}};
                end
                else if(clk_en) begin
                    if(MANUAL_LATENCY == 2)begin
                        divisor_sign_itr_r[1] <= divisor_sign_itr_r[0];
                        divisor_sign_itr_r[0] <= divisor_sign;
                        dividend_sign_itr_r[1] <=  dividend_sign_itr_r[0];
                        dividend_sign_itr_r[0] <= dividend_sign;
                    end
                    else begin
                        divisor_sign_itr_r[MANUAL_LATENCY-1 : 1] <= divisor_sign_itr_r[MANUAL_LATENCY-2:0];
                        divisor_sign_itr_r[0] <= divisor_sign;
                        dividend_sign_itr_r[MANUAL_LATENCY-1: 1] <=  dividend_sign_itr_r[MANUAL_LATENCY-2:0];
                        dividend_sign_itr_r[0] <= dividend_sign;
                    end
                end
  
            assign dividend_sign_r = dividend_sign_itr_r[MANUAL_LATENCY-1];
            assign divisor_sign_r  = divisor_sign_itr_r[MANUAL_LATENCY-1];
 
            ipsxe_divider_radix2_process_manual_latency_v1_0 #(.DIVIDEND_W(DIVIDEND_WIDTH),
                .DIVISOR_W(DIVISOR_WIDTH),
                //fract
                .QUOTIENT_FRACT_W(QUOTIENT_FRACTIONAL_WIDTH-1),
                 //quotient_fract_width is useless
                .Remainder_Type(Remainder_Type),
                .DIVI_ADDQ_W(DIVI_ADDQ_WIDTH_PASS),
                .MANUAL_LATENCY(MANUAL_LATENCY)
            )  U_ipsxe_divider_radix2_process_manual_latency_v1_0(
                .clk(clk),
                .rst_n(rst_n),
                .clk_en(clk_en),
                .dividend(dividend_unsigned),
                .divisor(divisor_unsigned),
                .quotient_fract_out(quotient_fract_unsigned),
                .remainder_out(remainder_unsigned),
                .quotient_out(quotient_unsigned)
                );
        end 
        else begin //auto
            reg   [DIVI_SIGNED_WIDTH-1:0] dividend_sign_bit = {DIVI_SIGNED_WIDTH{1'b0}};
            reg   [DIVI_SIGNED_WIDTH-1:0] divisor_sign_bit = {DIVI_SIGNED_WIDTH{1'b0}};
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    dividend_sign_bit <= {{DIVI_SIGNED_WIDTH}{1'b0}};
                    divisor_sign_bit  <= {{DIVI_SIGNED_WIDTH}{1'b0}};
                end
                else if(clk_en) begin
                    dividend_sign_bit[0] <= dividend_sign;
                    divisor_sign_bit[0]  <= divisor_sign;
//                end
//                else begin
                    dividend_sign_bit[DIVI_SIGNED_WIDTH-1:1]<= dividend_sign_bit[DIVI_SIGNED_WIDTH-2:0];
                    divisor_sign_bit[DIVI_SIGNED_WIDTH-1:1] <= divisor_sign_bit[DIVI_SIGNED_WIDTH-2:0];
                end
            end

            assign dividend_sign_r = dividend_sign_bit[DIVI_SIGNED_WIDTH-1];
            assign divisor_sign_r  = divisor_sign_bit[DIVI_SIGNED_WIDTH-1];
            
            ipsxe_divider_radix2_process_v1_0 #(.DIVIDEND_W(DIVIDEND_WIDTH),
                .DIVISOR_W(DIVISOR_WIDTH),
                .CLK_PER_DIVISION(CLK_PER_DIVISION),
                //fract
                .QUOTIENT_FRACT_W(QUOTIENT_FRACTIONAL_WIDTH-1),
                 //quotient_fract_width is useless
                .CNT_WIDTH(CNT_WIDTH),
                //.SIGNED(SIGNED),
                .Remainder_Type(Remainder_Type)
//                .DIVI_ADDQ_W(DIVI_ADDQ_WIDTH_PASS)
            )  U_ipsxe_divider_radix2_process_v1_0(
                .clk(clk),
                .rst_n(rst_n),
                .clk_en(clk_en),
                .cnt(cnt_logic),
                .dividend(dividend_unsigned_r),
                .divisor(divisor_unsigned_r),
                .quotient_fract(quotient_fract_unsigned),
                .remainder(remainder_unsigned),
                .quotient(quotient_unsigned)
                );
        end
            // If Remainder_Type is 1, the following code block will execute
        if (Remainder_Type == 1) begin
            // Depending on the XOR result of dividend_sign_r and divisor_sign_r, the quotient is assigned a value
            assign quotient = (dividend_sign_r^divisor_sign_r)?
//                ((quotient_unsigned[DIVIDEND_WIDTH-1] & (!(|quotient_unsigned[DIVIDEND_WIDTH-2:0])))?{(DIVIDEND_WIDTH){1'b0}}:{1'b1,((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
                ((!(|quotient_unsigned[DIVIDEND_WIDTH-2:0]))?{(DIVIDEND_WIDTH){1'b0}}:{1'b1,((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}): quotient_unsigned[DIVIDEND_WIDTH-1:0]; 
                // If XOR result is true, assign a 2's complement value of quotient_unsigned
//                ((&quotient_unsigned)?{{1'b1},{DIVIDEND_WIDTH{1'b0}}}:{{1'b1},((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
//                // If XOR result is false, assign quotient_unsigned directly
//                {{1'b0},quotient_unsigned[DIVIDEND_WIDTH-2:0]};
            // Same logic is applied to quotient_fract
            assign quotient_fract = (dividend_sign_r^divisor_sign_r)?
                {{1'b1},((~quotient_fract_unsigned[QUOTIENT_FRACTIONAL_WIDTH-2:0])+1)}:
                {{1'b0},quotient_fract_unsigned[QUOTIENT_FRACTIONAL_WIDTH-2:0]};
        end
        else begin // If Remainder_Type is not 1, the following code block will execute
            // Similar to the above, depending on the XOR result, the quotient is assigned a value
            assign quotient = (dividend_sign_r^divisor_sign_r)?
                ((!(|quotient_unsigned[DIVIDEND_WIDTH-2:0]))?{(DIVIDEND_WIDTH){1'b0}}:{1'b1,((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
                quotient_unsigned[DIVIDEND_WIDTH-1:0]; 
//                ((&quotient_unsigned)?{{1'b1},{DIVIDEND_WIDTH{1'b0}}}:{{1'b1},((~quotient_unsigned[DIVIDEND_WIDTH-2:0])+1)}):
//                {{1'b0},quotient_unsigned[DIVIDEND_WIDTH-2:0]};
            // For the remainder, if dividend_sign_r is true, assign a 2's complement value of remainder_unsigned
            assign remainder = (dividend_sign_r)?
                ((remainder_unsigned[DIVISOR_WIDTH-1] & (!(|remainder_unsigned[DIVISOR_WIDTH-2:0])))?remainder_unsigned:{1'b1,((~remainder_unsigned[DIVISOR_WIDTH-2:0])+1)}):
                remainder_unsigned[DIVISOR_WIDTH-1:0]; 
//                ((&remainder_unsigned)?{{1'b1},{DIVISOR_WIDTH{1'b0}}}:{{1'b1},((~remainder_unsigned[DIVISOR_WIDTH-2:0])+1)}):
//                // If dividend_sign_r is false, assign remainder_unsigned directly
//                {{1'b0},remainder_unsigned[DIVISOR_WIDTH-2:0]};
        end
    end
    else begin//unsigned
        if(LATENCY_MODE == 1)begin
            ipsxe_divider_radix2_process_manual_latency_v1_0 #(.DIVIDEND_W(DIVIDEND_WIDTH),
                    .DIVISOR_W(DIVISOR_WIDTH),
                    .DIVI_ADDQ_W(DIVI_ADDQ_WIDTH),
                    .Remainder_Type(Remainder_Type),
                    .QUOTIENT_FRACT_W(QUOTIENT_FRACTIONAL_WIDTH),
                    .MANUAL_LATENCY(MANUAL_LATENCY)
                    ) U_ipsxe_divider_radix2_process_manual_latency_v1_0(
                    .clk(clk),
                    .rst_n(rst_n),
                    .clk_en(clk_en),
                    .dividend(dividend),
                    .divisor(divisor),
                    .quotient_fract_out(quotient_fract),
                    .remainder_out(remainder),
                    .quotient_out(quotient)
                );
        end
        else begin
        //usigned
            ipsxe_divider_radix2_process_v1_0 #(.DIVIDEND_W(DIVIDEND_WIDTH),
                    .DIVISOR_W(DIVISOR_WIDTH),
                    //.DIVI_ADDQ_W(DIVI_ADDQ_WIDTH),
                    .CLK_PER_DIVISION(CLK_PER_DIVISION),
                    .CNT_WIDTH(CNT_WIDTH),
                    .Remainder_Type(Remainder_Type),
                    .QUOTIENT_FRACT_W(QUOTIENT_FRACTIONAL_WIDTH)
                    ) U_ipsxe_divider_radix2_process_v1_0(
                    .clk(clk),
                    .rst_n(rst_n),
                    .clk_en(clk_en),
                    .cnt(cnt),
                    .dividend(dividend),
                    .divisor(divisor),
                    .quotient_fract(quotient_fract),
                    .remainder(remainder),
                    .quotient(quotient)
                );
        end
    end
endgenerate   
    
endmodule
