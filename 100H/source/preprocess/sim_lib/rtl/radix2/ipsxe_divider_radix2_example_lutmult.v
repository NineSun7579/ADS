
module radix2
#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8,
    parameter QUOTIENT_FRACTIONAL_WIDTH = 2,
    parameter  CLK_PER_DIVISION = 1,
    
    parameter    DIVI_ADDQ_WIDTH = 10
    
)
(   clk,
    rst_n,
    clk_en,
    dividend,
    divisor,
    cnt,
    
    remainder,
    
    quotient
    );

    input clk;
    input rst_n;
    input clk_en;
    input [DIVIDEND_WIDTH-1:0] dividend;
    input [DIVISOR_WIDTH-1:0] divisor;

    
    input [2:0]cnt;
    
    output wire [DIVISOR_WIDTH-1:0]remainder;
    
    output wire [DIVIDEND_WIDTH-1:0]quotient;
    
       
        //unsigned
        radix2_process #(.DIVIDEND_W(DIVIDEND_WIDTH),
                .DIVISOR_W(DIVISOR_WIDTH),
                .DIVI_ADDQ_W(DIVI_ADDQ_WIDTH),
                .CLK_PER_DIVISION(CLK_PER_DIVISION),
                
        
                .QUOTIENT_FRACT_W(1'b0)
        
                ) U_radix2_process(
                .clk(clk),
                .rst_n(rst_n),
                .clk_en(clk_en),
                
                .cnt(cnt),
                
                .dividend(dividend),
                .divisor(divisor),
                
                .remainder_r(remainder),
                 
                .quotient_r(quotient)
            );
    

endmodule


