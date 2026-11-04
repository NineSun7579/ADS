


module Lutmult_top#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8
)
    (
    input clk,
    input rstn,
    input [DIVIDEND_WIDTH-1:0] dividend,
    input [DIVISOR_WIDTH-1:0] divisor,
    // input [10:0] addr_in,
    output [DIVIDEND_WIDTH-1:0] quotient,
    output [DIVISOR_WIDTH-1:0] remainder 
);


    


        wire [10:0] reciprocal_shift;
        wire [DIVIDEND_WIDTH-1:0] dividend_pass;
        wire [DIVISOR_WIDTH-1:0] divisor_pass;

        Lutmult_core 
        #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH)
        )
        Lutmult_core_m0(
            .clk(clk),
            .rstn(rstn),
            .dividend(dividend_pass),
            .divisor(divisor_pass),
            .reciprocal_table(reciprocal_shift),
            .quotient_stage5(quotient),
            .remainder_stage5(remainder)
        );

        LutBRAM 
        #(
            .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
            .DIVISOR_WIDTH(DIVISOR_WIDTH)
        )
        LutBRAM_m0(
            .clk(clk),
            .rstn(rstn),
            .addr_in(divisor),
            .dividend(dividend),
            //.load(1'b0),
            //.data_in(11'b0),
            .Lut_out(reciprocal_shift),
            .dividend_out(dividend_pass),
            .divisor_out(divisor_pass)
        );


    

endmodule


