module nextpreprocess #(parameter DIVIDEND_WIDTH = 24, DIVISOR_WIDTH = 24, FRACTION_WIDTH = 25)
(
     input [DIVISOR_WIDTH+2'd2:1'b0] i_d_shift
    ,input [DIVIDEND_WIDTH+3'd4:1'b0] i_x_shift
    ,output [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_d_shift_2
    ,output [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_x_shift_2
    ,output o_max
);
reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_d_shift_2_r;
reg [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_x_shift_2_r;
reg o_max_r;

assign o_d_shift_2=o_d_shift_2_r;
assign o_x_shift_2=o_x_shift_2_r;
assign o_max=o_max_r;

generate
    case((DIVISOR_WIDTH+2'd2) > (DIVIDEND_WIDTH+3'd4))
    1'b1:begin
        always @(*) 
        begin
        o_d_shift_2_r= i_d_shift;
        o_x_shift_2_r = {i_x_shift,{(DIVISOR_WIDTH- DIVIDEND_WIDTH-2'd2){1'b0}}};
        o_max_r=1'b1;
        end
        end
    1'b0:begin
        always @(*) 
	    begin
        o_d_shift_2_r=  {i_d_shift,{(DIVIDEND_WIDTH-DIVISOR_WIDTH+2'd2){1'b0}}};
        o_x_shift_2_r =i_x_shift;
        o_max_r=1'b0;
        end
        end
    default:begin
        always @(*) 
        begin
        o_d_shift_2_r= i_d_shift;
        o_x_shift_2_r = i_x_shift ;
        o_max_r=1'b0;
        end
        end
    endcase
endgenerate
endmodule
