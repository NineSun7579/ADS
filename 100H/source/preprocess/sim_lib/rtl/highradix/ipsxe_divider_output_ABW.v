module output_ABW #(parameter DIVIDEND_WIDTH = 24, DIVISOR_WIDTH = 24, FRACTION_WIDTH = 25)
(
    //input
    i_w0,
    i_d,
    i_lut_d,
    i_a,
    i_b,
    i_temp_1,
    i_max,
    //output
    o_output_a,
    o_output_b,
    o_output_w
);
    input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_w0;
    input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] i_d;
    input        [2'd3:1'b0]        i_lut_d;
    input [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] i_a;
    input [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] i_b;
    input [9:1'b0] i_temp_1;
    input i_max;
    output [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] o_output_a;
    output [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] o_output_b;
    output [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] o_output_w;

    //LUT
    wire [2'd2:1'b0] q1;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] w_temp1;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] w_temp1_0;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd4:1'b0] w_temp1_1;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd6:1'b0] w_temp2;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd6:1'b0] w_temp3;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd6:1'b0] w_temp3_0;
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd6:1'b0] w_temp3_1;
    //output_abw
    wire [DIVISOR_WIDTH+DIVIDEND_WIDTH+4:1'b0] w1;
    wire [2'd2:1'b0] a1;
    wire [2'd2:1'b0] b1;
    assign w_temp1_0=i_w0[DIVIDEND_WIDTH+3'd4]?{~i_w0[DIVIDEND_WIDTH+3'd3:1'b0]+1'b1}:{i_w0};
    assign w_temp1_1=i_w0[DIVISOR_WIDTH+2]?{~i_w0[DIVISOR_WIDTH+1:1'b0]+1'b1}:{i_w0};
    assign w_temp1=i_max?w_temp1_1:w_temp1_0;
    assign w_temp2=w_temp1*3'd4;
    assign w_temp3_0=i_w0[DIVIDEND_WIDTH+3'd4]?{1'b1,w_temp2[DIVIDEND_WIDTH+3:0]}:{1'b0,w_temp2[DIVIDEND_WIDTH+3:0]};
    assign w_temp3_1=i_w0[DIVISOR_WIDTH+2]?{1'b1,w_temp2[DIVISOR_WIDTH+1:0]}:{1'b0,w_temp2[DIVISOR_WIDTH+1:0]};
    assign w_temp3=i_max?w_temp3_1:w_temp3_0;
    //assign q1 = i_max ? (q_temp1({w_temp1[DIVISOR_WIDTH+2],2'b00,w_temp1[DIVISOR_WIDTH-1:0]},i_lut_d):(q_temp({w_temp1[DIVIDEND_WIDTH+4],2'b00,w_temp1[DIVIDEND_WIDTH+1:0]},i_lut_d));
    assign q1= i_max?q_temp1(w_temp3[DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd5:1'b0],i_lut_d):q_temp(w_temp3[DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd5:1'b0],i_lut_d);
   // wire [8:0] w_temp_debug;
    //assign w_temp_debug=w_temp3[DIVIDEND_WIDTH+4:DIVIDEND_WIDTH-4];
    
     function [2'd2:1'b0] q_temp(input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3'd5:1'b0] w_temp,input [2'd3:1'b0] d);
    case(d)
    4'b1000:q_temp=((w_temp[DIVIDEND_WIDTH+4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+4]==1'd0) && (8'b0001_0000 <= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) &&( w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0011_0100))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+4]==1'd1) && (8'b0001_0000<w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0011_0100))?{3'b111}:{3'b000};
    4'b1001:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0001_0000<= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0001_0000< w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1010:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0001_0000<= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0001_1000< w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0001_0000 <= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0001_1000<w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0001_1000 <= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0100_1000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0001_1000<w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1101:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0001_1000 <= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0010_0000<w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0010_0000<= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) &&(w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0010_0000< w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp=((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4] >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd0) && (8'b0010_0000 <= w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVIDEND_WIDTH+3'd4]==1'd1) && (8'b0010_0000< w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]) && (w_temp[DIVIDEND_WIDTH+3:DIVIDEND_WIDTH-4]<=8'b0110_0000))?{3'b111}:{3'b000};
            default:q_temp=3'b100;
endcase
endfunction
/*
             function [2'd2:1'b0] q_temp1(input [DIVISOR_WIDTH+DIVIDEND_WIDTH+3:1'b0] w_temp,input [2'd3:1'b0] d);
    case(d)
    4'b1000:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:0] >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) &&( w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0011_0100))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0011_0100))?{3'b111}:{3'b000};
    4'b1001:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1010:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1101:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000<= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) &&(w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0110_0000))?{3'b111}:{3'b000};
            default:q_temp1=3'b100;
endcase
endfunction*/
generate
 function [2:1'b0] q_temp1(input [DIVISOR_WIDTH+DIVIDEND_WIDTH+4:1'b0] w_temp,input [3:1'b0] d);

case(DIVISOR_WIDTH)
4'd2:
case(d)
    4'b1000:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= {w_temp[DIVISOR_WIDTH+1:0],4'd0}) &&( {w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000<{w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1001:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0011_1100))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0011_1100))?{3'b111}:{3'b000};
    4'b1010:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<={w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <={w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<{w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0100_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0100_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1101:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000<= {w_temp[DIVISOR_WIDTH+1:0],4'd0}) &&({w_temp[DIVISOR_WIDTH+1:0],4'd0} < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0} >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000 <= {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],4'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],4'd0}<=8'b0110_0000))?{3'b111}:{3'b000};
    default:q_temp1=3'b100;
    endcase
4'd3:
case(d)
    4'b1000:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= {w_temp[DIVISOR_WIDTH+1:0],3'd0}) &&( {w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000<{w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1001:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0011_1100))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0011_1100))?{3'b111}:{3'b000};
    4'b1010:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<={w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <={w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<{w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0100_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0100_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1101:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000<= {w_temp[DIVISOR_WIDTH+1:0],3'd0}) &&({w_temp[DIVISOR_WIDTH+1:0],3'd0} < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0} >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000 <= {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],3'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],3'd0}<=8'b0110_0000))?{3'b111}:{3'b000};
    default:q_temp1=3'b100;
    endcase
4'd4:
case(d)
    4'b1000:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= {w_temp[DIVISOR_WIDTH+1:0],2'd0}) &&( {w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000<{w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1001:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0011_1100))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0011_1100))?{3'b111}:{3'b000};
    4'b1010:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<={w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <={w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<{w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0100_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0100_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1101:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000<= {w_temp[DIVISOR_WIDTH+1:0],2'd0}) &&({w_temp[DIVISOR_WIDTH+1:0],2'd0} < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0} >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000 <= {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],2'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],2'd0}<=8'b0110_0000))?{3'b111}:{3'b000};
    default:q_temp1=3'b100;
    endcase
4'd5:
case(d)
    4'b1000:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= {w_temp[DIVISOR_WIDTH+1:0],1'd0}) &&( {w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000<{w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1001:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0011_1100))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0011_1100))?{3'b111}:{3'b000};
    4'b1010:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<={w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <={w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<{w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0100_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0100_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1101:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<{w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000<= {w_temp[DIVISOR_WIDTH+1:0],1'd0}) &&({w_temp[DIVISOR_WIDTH+1:0],1'd0} < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0} >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000 <= {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< {w_temp[DIVISOR_WIDTH+1:0],1'd0}) && ({w_temp[DIVISOR_WIDTH+1:0],1'd0}<=8'b0110_0000))?{3'b111}:{3'b000};
    default:q_temp1=3'b100;
    endcase
default:
    case(d)
    4'b1000:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0011_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) &&( w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0011_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0011_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_0000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0011_1000))?{3'b111}:{3'b000};
    4'b1001:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0011_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0011_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0011_1100))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0011_1100))?{3'b111}:{3'b000};
    4'b1010:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0011_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000<= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0011_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0100_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0100_0000))?{3'b111}:{3'b000};
    4'b1011:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0100_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_0000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0100_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] > 8'b0100_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0001_1000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0100_1000))?{3'b111}:{3'b000};
    4'b1100:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0100_1000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0100_1000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1101:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0100_1100))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0001_1000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0100_1100))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0101_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000<w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0101_0000))?{3'b111}:{3'b000};
    4'b1110:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0101_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000<= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) &&(w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] < 8'b0101_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0101_1000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0101_1000))?{3'b111}:{3'b000};
    4'b1111:q_temp1=((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6] >= 8'b0110_0000))?{3'b010} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd0) && (8'b0010_0000 <= w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]< 8'b0110_0000))?{3'b001} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]>8'b0110_0000))?{3'b110} :
            ((w_temp[DIVISOR_WIDTH+2'd2]==1'd1) && (8'b0010_0000< w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]) && (w_temp[DIVISOR_WIDTH+1:DIVISOR_WIDTH-6]<=8'b0110_0000))?{3'b111}:{3'b000};
    default:q_temp1=3'b100;
    endcase
endcase

endfunction
endgenerate

//LUT end

assign w1 = i_max ? ((q1 == 3'b010)?{{i_w0[DIVISOR_WIDTH+2'd2],i_w0[DIVISOR_WIDTH-1:1'b0],2'b0}-{i_d[DIVISOR_WIDTH+1:1'b0],1'b0}} :
    (q1 == 3'b001)?{{i_w0[DIVISOR_WIDTH+2'd2],i_w0[DIVISOR_WIDTH-1:1'b0],2'b0}-{i_d[DIVISOR_WIDTH+2:1'b0]}}:(q1 == 3'b000)?{i_w0[DIVISOR_WIDTH+2'd2],i_w0[DIVISOR_WIDTH-1:1'b0],2'b0} :
    (q1 == 3'b111)?{{i_w0[DIVISOR_WIDTH+2'd2],i_w0[DIVISOR_WIDTH-1:1'b0],2'b0}+{i_d[DIVISOR_WIDTH+2:1'b0]}}:{{i_w0[DIVISOR_WIDTH+2'd2],i_w0[DIVISOR_WIDTH-1:1'b0],2'b0}+{i_d[DIVISOR_WIDTH-1:1'b0],1'b0}}) : ((q1 == 3'b010)?{{i_w0[DIVIDEND_WIDTH+3'd4],i_w0[DIVIDEND_WIDTH+1:1'b0],2'b0}-{i_d[DIVIDEND_WIDTH+3:1'b0],1'b0}} :
    (q1 == 3'b001)?{{i_w0[DIVIDEND_WIDTH+3'd4],i_w0[DIVIDEND_WIDTH+1:1'b0],2'b0}-{i_d[DIVIDEND_WIDTH+4:1'b0]}}:(q1 == 3'b000)?{i_w0[DIVIDEND_WIDTH+3'd4],i_w0[DIVIDEND_WIDTH+1:1'b0],2'b0} :
    (q1 == 3'b111)?{{i_w0[DIVIDEND_WIDTH+3'd4],i_w0[DIVIDEND_WIDTH+1:1'b0],2'b0}+{i_d[DIVIDEND_WIDTH+4:1'b0]}}:{{i_w0[DIVIDEND_WIDTH+3'd4],i_w0[DIVIDEND_WIDTH+1:1'b0],2'b0}+{i_d[DIVIDEND_WIDTH+3:1'b0],1'b0}});


    assign a1= (q1[2])?{3'b100+q1} :{3'b000};
    assign b1= (q1[2])?{3'b011+q1} :(q1==3'b000)?{3'b011+q1} :{3'b000};


    reg [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] a_next;
    reg [DIVIDEND_WIDTH+FRACTION_WIDTH+3'd5:1'b0] b_next;

always @(*)
begin
case(DIVIDEND_WIDTH+FRACTION_WIDTH)
    10'd1:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[6:5], q1[1:0], i_a[2:0]} : {i_b[6:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[6:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[6:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd2:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[7:6], q1[1:0], i_a[3:0]} : {i_b[7:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[7:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[7:6], b1[1:0], i_b[3:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[7:4], q1[1:0], i_a[1:0]} : {i_b[7:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[7:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[7:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd3:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[8:7], q1[1:0], i_a[4:0]} : {i_b[8:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[8:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[8:7], b1[1:0], i_b[4:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[8:5], q1[1:0], i_a[2:0]} : {i_b[8:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[8:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[8:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd4:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[9:8], q1[1:0], i_a[5:0]} : {i_b[9:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[9:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[9:8], b1[1:0], i_b[5:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[9:6], q1[1:0], i_a[3:0]} : {i_b[9:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[9:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[9:6], b1[1:0], i_b[3:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[9:4], q1[1:0], i_a[1:0]} : {i_b[9:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[9:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[9:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd5:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[10:9], q1[1:0], i_a[6:0]} : {i_b[10:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[10:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[10:9], b1[1:0], i_b[6:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[10:7], q1[1:0], i_a[4:0]} : {i_b[10:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[10:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[10:7], b1[1:0], i_b[4:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[10:5], q1[1:0], i_a[2:0]} : {i_b[10:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[10:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[10:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd6:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[11:10], q1[1:0], i_a[7:0]} : {i_b[11:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[11:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[11:10], b1[1:0], i_b[7:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[11:8], q1[1:0], i_a[5:0]} : {i_b[11:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[11:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[11:8], b1[1:0], i_b[5:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[11:6], q1[1:0], i_a[3:0]} : {i_b[11:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[11:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[11:6], b1[1:0], i_b[3:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[11:4], q1[1:0], i_a[1:0]} : {i_b[11:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[11:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[11:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd7:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[12:11], q1[1:0], i_a[8:0]} : {i_b[12:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[12:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[12:11], b1[1:0], i_b[8:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[12:9], q1[1:0], i_a[6:0]} : {i_b[12:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[12:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[12:9], b1[1:0], i_b[6:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[12:7], q1[1:0], i_a[4:0]} : {i_b[12:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[12:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[12:7], b1[1:0], i_b[4:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[12:5], q1[1:0], i_a[2:0]} : {i_b[12:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[12:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[12:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd8:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[13:12], q1[1:0], i_a[9:0]} : {i_b[13:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[13:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[13:12], b1[1:0], i_b[9:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[13:10], q1[1:0], i_a[7:0]} : {i_b[13:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[13:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[13:10], b1[1:0], i_b[7:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[13:8], q1[1:0], i_a[5:0]} : {i_b[13:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[13:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[13:8], b1[1:0], i_b[5:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[13:6], q1[1:0], i_a[3:0]} : {i_b[13:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[13:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[13:6], b1[1:0], i_b[3:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[13:4], q1[1:0], i_a[1:0]} : {i_b[13:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[13:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[13:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd9:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[14:13], q1[1:0], i_a[10:0]} : {i_b[14:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[14:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[14:13], b1[1:0], i_b[10:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[14:11], q1[1:0], i_a[8:0]} : {i_b[14:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[14:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[14:11], b1[1:0], i_b[8:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[14:9], q1[1:0], i_a[6:0]} : {i_b[14:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[14:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[14:9], b1[1:0], i_b[6:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[14:7], q1[1:0], i_a[4:0]} : {i_b[14:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[14:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[14:7], b1[1:0], i_b[4:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[14:5], q1[1:0], i_a[2:0]} : {i_b[14:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[14:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[14:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd10:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[15:14], q1[1:0], i_a[11:0]} : {i_b[15:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[15:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[15:14], b1[1:0], i_b[11:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[15:12], q1[1:0], i_a[9:0]} : {i_b[15:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[15:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[15:12], b1[1:0], i_b[9:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[15:10], q1[1:0], i_a[7:0]} : {i_b[15:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[15:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[15:10], b1[1:0], i_b[7:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[15:8], q1[1:0], i_a[5:0]} : {i_b[15:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[15:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[15:8], b1[1:0], i_b[5:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[15:6], q1[1:0], i_a[3:0]} : {i_b[15:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[15:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[15:6], b1[1:0], i_b[3:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[15:4], q1[1:0], i_a[1:0]} : {i_b[15:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[15:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[15:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd11:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[16:15], q1[1:0], i_a[12:0]} : {i_b[16:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[16:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[16:15], b1[1:0], i_b[12:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[16:13], q1[1:0], i_a[10:0]} : {i_b[16:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[16:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[16:13], b1[1:0], i_b[10:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[16:11], q1[1:0], i_a[8:0]} : {i_b[16:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[16:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[16:11], b1[1:0], i_b[8:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[16:9], q1[1:0], i_a[6:0]} : {i_b[16:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[16:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[16:9], b1[1:0], i_b[6:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[16:7], q1[1:0], i_a[4:0]} : {i_b[16:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[16:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[16:7], b1[1:0], i_b[4:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[16:5], q1[1:0], i_a[2:0]} : {i_b[16:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[16:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[16:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd12:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[17:16], q1[1:0], i_a[13:0]} : {i_b[17:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[17:16], b1[1:0], i_b[13:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[17:14], q1[1:0], i_a[11:0]} : {i_b[17:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[17:14], b1[1:0], i_b[11:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[17:12], q1[1:0], i_a[9:0]} : {i_b[17:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[17:12], b1[1:0], i_b[9:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[17:10], q1[1:0], i_a[7:0]} : {i_b[17:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[17:10], b1[1:0], i_b[7:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[17:8], q1[1:0], i_a[5:0]} : {i_b[17:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[17:8], b1[1:0], i_b[5:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[17:6], q1[1:0], i_a[3:0]} : {i_b[17:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[17:6], b1[1:0], i_b[3:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[17:4], q1[1:0], i_a[1:0]} : {i_b[17:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[17:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[17:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd13:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[18:17], q1[1:0], i_a[14:0]} : {i_b[18:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[18:17], b1[1:0], i_b[14:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[18:15], q1[1:0], i_a[12:0]} : {i_b[18:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[18:15], b1[1:0], i_b[12:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[18:13], q1[1:0], i_a[10:0]} : {i_b[18:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[18:13], b1[1:0], i_b[10:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[18:11], q1[1:0], i_a[8:0]} : {i_b[18:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[18:11], b1[1:0], i_b[8:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[18:9], q1[1:0], i_a[6:0]} : {i_b[18:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[18:9], b1[1:0], i_b[6:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[18:7], q1[1:0], i_a[4:0]} : {i_b[18:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[18:7], b1[1:0], i_b[4:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[18:5], q1[1:0], i_a[2:0]} : {i_b[18:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[18:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[18:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd14:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[19:18], q1[1:0], i_a[15:0]} : {i_b[19:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[19:18], b1[1:0], i_b[15:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[19:16], q1[1:0], i_a[13:0]} : {i_b[19:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[19:16], b1[1:0], i_b[13:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[19:14], q1[1:0], i_a[11:0]} : {i_b[19:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[19:14], b1[1:0], i_b[11:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[19:12], q1[1:0], i_a[9:0]} : {i_b[19:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[19:12], b1[1:0], i_b[9:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[19:10], q1[1:0], i_a[7:0]} : {i_b[19:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[19:10], b1[1:0], i_b[7:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[19:8], q1[1:0], i_a[5:0]} : {i_b[19:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[19:8], b1[1:0], i_b[5:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[19:6], q1[1:0], i_a[3:0]} : {i_b[19:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[19:6], b1[1:0], i_b[3:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[19:4], q1[1:0], i_a[1:0]} : {i_b[19:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[19:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[19:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd15:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[20:19], q1[1:0], i_a[16:0]} : {i_b[20:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[20:19], b1[1:0], i_b[16:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[20:17], q1[1:0], i_a[14:0]} : {i_b[20:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[20:17], b1[1:0], i_b[14:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[20:15], q1[1:0], i_a[12:0]} : {i_b[20:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[20:15], b1[1:0], i_b[12:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[20:13], q1[1:0], i_a[10:0]} : {i_b[20:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[20:13], b1[1:0], i_b[10:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[20:11], q1[1:0], i_a[8:0]} : {i_b[20:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[20:11], b1[1:0], i_b[8:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[20:9], q1[1:0], i_a[6:0]} : {i_b[20:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[20:9], b1[1:0], i_b[6:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[20:7], q1[1:0], i_a[4:0]} : {i_b[20:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[20:7], b1[1:0], i_b[4:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[20:5], q1[1:0], i_a[2:0]} : {i_b[20:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[20:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[20:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd16:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[21:20], q1[1:0], i_a[17:0]} : {i_b[21:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[21:20], b1[1:0], i_b[17:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[21:18], q1[1:0], i_a[15:0]} : {i_b[21:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[21:18], b1[1:0], i_b[15:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[21:16], q1[1:0], i_a[13:0]} : {i_b[21:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[21:16], b1[1:0], i_b[13:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[21:14], q1[1:0], i_a[11:0]} : {i_b[21:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[21:14], b1[1:0], i_b[11:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[21:12], q1[1:0], i_a[9:0]} : {i_b[21:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[21:12], b1[1:0], i_b[9:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[21:10], q1[1:0], i_a[7:0]} : {i_b[21:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[21:10], b1[1:0], i_b[7:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[21:8], q1[1:0], i_a[5:0]} : {i_b[21:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[21:8], b1[1:0], i_b[5:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[21:6], q1[1:0], i_a[3:0]} : {i_b[21:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[21:6], b1[1:0], i_b[3:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[21:4], q1[1:0], i_a[1:0]} : {i_b[21:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[21:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[21:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd17:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[22:21], q1[1:0], i_a[18:0]} : {i_b[22:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[22:21], b1[1:0], i_b[18:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[22:19], q1[1:0], i_a[16:0]} : {i_b[22:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[22:19], b1[1:0], i_b[16:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[22:17], q1[1:0], i_a[14:0]} : {i_b[22:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[22:17], b1[1:0], i_b[14:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[22:15], q1[1:0], i_a[12:0]} : {i_b[22:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[22:15], b1[1:0], i_b[12:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[22:13], q1[1:0], i_a[10:0]} : {i_b[22:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[22:13], b1[1:0], i_b[10:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[22:11], q1[1:0], i_a[8:0]} : {i_b[22:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[22:11], b1[1:0], i_b[8:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[22:9], q1[1:0], i_a[6:0]} : {i_b[22:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[22:9], b1[1:0], i_b[6:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[22:7], q1[1:0], i_a[4:0]} : {i_b[22:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[22:7], b1[1:0], i_b[4:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[22:5], q1[1:0], i_a[2:0]} : {i_b[22:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[22:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[22:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd18:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[23:22], q1[1:0], i_a[19:0]} : {i_b[23:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[23:22], b1[1:0], i_b[19:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[23:20], q1[1:0], i_a[17:0]} : {i_b[23:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[23:20], b1[1:0], i_b[17:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[23:18], q1[1:0], i_a[15:0]} : {i_b[23:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[23:18], b1[1:0], i_b[15:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[23:16], q1[1:0], i_a[13:0]} : {i_b[23:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[23:16], b1[1:0], i_b[13:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[23:14], q1[1:0], i_a[11:0]} : {i_b[23:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[23:14], b1[1:0], i_b[11:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[23:12], q1[1:0], i_a[9:0]} : {i_b[23:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[23:12], b1[1:0], i_b[9:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[23:10], q1[1:0], i_a[7:0]} : {i_b[23:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[23:10], b1[1:0], i_b[7:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[23:8], q1[1:0], i_a[5:0]} : {i_b[23:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[23:8], b1[1:0], i_b[5:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[23:6], q1[1:0], i_a[3:0]} : {i_b[23:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[23:6], b1[1:0], i_b[3:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[23:4], q1[1:0], i_a[1:0]} : {i_b[23:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[23:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[23:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd19:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[24:23], q1[1:0], i_a[20:0]} : {i_b[24:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[24:23], b1[1:0], i_b[20:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[24:21], q1[1:0], i_a[18:0]} : {i_b[24:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[24:21], b1[1:0], i_b[18:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[24:19], q1[1:0], i_a[16:0]} : {i_b[24:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[24:19], b1[1:0], i_b[16:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[24:17], q1[1:0], i_a[14:0]} : {i_b[24:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[24:17], b1[1:0], i_b[14:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[24:15], q1[1:0], i_a[12:0]} : {i_b[24:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[24:15], b1[1:0], i_b[12:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[24:13], q1[1:0], i_a[10:0]} : {i_b[24:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[24:13], b1[1:0], i_b[10:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[24:11], q1[1:0], i_a[8:0]} : {i_b[24:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[24:11], b1[1:0], i_b[8:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[24:9], q1[1:0], i_a[6:0]} : {i_b[24:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[24:9], b1[1:0], i_b[6:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[24:7], q1[1:0], i_a[4:0]} : {i_b[24:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[24:7], b1[1:0], i_b[4:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[24:5], q1[1:0], i_a[2:0]} : {i_b[24:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[24:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[24:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd20:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[25:24], q1[1:0], i_a[21:0]} : {i_b[25:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[25:24], b1[1:0], i_b[21:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[25:22], q1[1:0], i_a[19:0]} : {i_b[25:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[25:22], b1[1:0], i_b[19:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[25:20], q1[1:0], i_a[17:0]} : {i_b[25:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[25:20], b1[1:0], i_b[17:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[25:18], q1[1:0], i_a[15:0]} : {i_b[25:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[25:18], b1[1:0], i_b[15:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[25:16], q1[1:0], i_a[13:0]} : {i_b[25:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[25:16], b1[1:0], i_b[13:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[25:14], q1[1:0], i_a[11:0]} : {i_b[25:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[25:14], b1[1:0], i_b[11:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[25:12], q1[1:0], i_a[9:0]} : {i_b[25:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[25:12], b1[1:0], i_b[9:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[25:10], q1[1:0], i_a[7:0]} : {i_b[25:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[25:10], b1[1:0], i_b[7:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[25:8], q1[1:0], i_a[5:0]} : {i_b[25:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[25:8], b1[1:0], i_b[5:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[25:6], q1[1:0], i_a[3:0]} : {i_b[25:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[25:6], b1[1:0], i_b[3:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[25:4], q1[1:0], i_a[1:0]} : {i_b[25:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[25:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[25:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd21:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[26:25], q1[1:0], i_a[22:0]} : {i_b[26:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[26:25], b1[1:0], i_b[22:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[26:23], q1[1:0], i_a[20:0]} : {i_b[26:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[26:23], b1[1:0], i_b[20:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[26:21], q1[1:0], i_a[18:0]} : {i_b[26:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[26:21], b1[1:0], i_b[18:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[26:19], q1[1:0], i_a[16:0]} : {i_b[26:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[26:19], b1[1:0], i_b[16:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[26:17], q1[1:0], i_a[14:0]} : {i_b[26:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[26:17], b1[1:0], i_b[14:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[26:15], q1[1:0], i_a[12:0]} : {i_b[26:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[26:15], b1[1:0], i_b[12:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[26:13], q1[1:0], i_a[10:0]} : {i_b[26:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[26:13], b1[1:0], i_b[10:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[26:11], q1[1:0], i_a[8:0]} : {i_b[26:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[26:11], b1[1:0], i_b[8:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[26:9], q1[1:0], i_a[6:0]} : {i_b[26:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[26:9], b1[1:0], i_b[6:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[26:7], q1[1:0], i_a[4:0]} : {i_b[26:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[26:7], b1[1:0], i_b[4:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[26:5], q1[1:0], i_a[2:0]} : {i_b[26:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[26:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[26:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd22:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[27:26], q1[1:0], i_a[23:0]} : {i_b[27:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[27:26], b1[1:0], i_b[23:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[27:24], q1[1:0], i_a[21:0]} : {i_b[27:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[27:24], b1[1:0], i_b[21:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[27:22], q1[1:0], i_a[19:0]} : {i_b[27:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[27:22], b1[1:0], i_b[19:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[27:20], q1[1:0], i_a[17:0]} : {i_b[27:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[27:20], b1[1:0], i_b[17:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[27:18], q1[1:0], i_a[15:0]} : {i_b[27:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[27:18], b1[1:0], i_b[15:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[27:16], q1[1:0], i_a[13:0]} : {i_b[27:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[27:16], b1[1:0], i_b[13:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[27:14], q1[1:0], i_a[11:0]} : {i_b[27:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[27:14], b1[1:0], i_b[11:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[27:12], q1[1:0], i_a[9:0]} : {i_b[27:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[27:12], b1[1:0], i_b[9:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[27:10], q1[1:0], i_a[7:0]} : {i_b[27:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[27:10], b1[1:0], i_b[7:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[27:8], q1[1:0], i_a[5:0]} : {i_b[27:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[27:8], b1[1:0], i_b[5:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[27:6], q1[1:0], i_a[3:0]} : {i_b[27:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[27:6], b1[1:0], i_b[3:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[27:4], q1[1:0], i_a[1:0]} : {i_b[27:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[27:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[27:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd23:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[28:27], q1[1:0], i_a[24:0]} : {i_b[28:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[28:27], b1[1:0], i_b[24:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[28:25], q1[1:0], i_a[22:0]} : {i_b[28:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[28:25], b1[1:0], i_b[22:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[28:23], q1[1:0], i_a[20:0]} : {i_b[28:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[28:23], b1[1:0], i_b[20:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[28:21], q1[1:0], i_a[18:0]} : {i_b[28:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[28:21], b1[1:0], i_b[18:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[28:19], q1[1:0], i_a[16:0]} : {i_b[28:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[28:19], b1[1:0], i_b[16:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[28:17], q1[1:0], i_a[14:0]} : {i_b[28:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[28:17], b1[1:0], i_b[14:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[28:15], q1[1:0], i_a[12:0]} : {i_b[28:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[28:15], b1[1:0], i_b[12:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[28:13], q1[1:0], i_a[10:0]} : {i_b[28:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[28:13], b1[1:0], i_b[10:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[28:11], q1[1:0], i_a[8:0]} : {i_b[28:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[28:11], b1[1:0], i_b[8:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[28:9], q1[1:0], i_a[6:0]} : {i_b[28:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[28:9], b1[1:0], i_b[6:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[28:7], q1[1:0], i_a[4:0]} : {i_b[28:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[28:7], b1[1:0], i_b[4:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[28:5], q1[1:0], i_a[2:0]} : {i_b[28:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[28:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[28:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd24:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[29:28], q1[1:0], i_a[25:0]} : {i_b[29:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[29:28], b1[1:0], i_b[25:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[29:26], q1[1:0], i_a[23:0]} : {i_b[29:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[29:26], b1[1:0], i_b[23:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[29:24], q1[1:0], i_a[21:0]} : {i_b[29:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[29:24], b1[1:0], i_b[21:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[29:22], q1[1:0], i_a[19:0]} : {i_b[29:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[29:22], b1[1:0], i_b[19:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[29:20], q1[1:0], i_a[17:0]} : {i_b[29:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[29:20], b1[1:0], i_b[17:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[29:18], q1[1:0], i_a[15:0]} : {i_b[29:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[29:18], b1[1:0], i_b[15:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[29:16], q1[1:0], i_a[13:0]} : {i_b[29:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[29:16], b1[1:0], i_b[13:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[29:14], q1[1:0], i_a[11:0]} : {i_b[29:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[29:14], b1[1:0], i_b[11:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[29:12], q1[1:0], i_a[9:0]} : {i_b[29:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[29:12], b1[1:0], i_b[9:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[29:10], q1[1:0], i_a[7:0]} : {i_b[29:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[29:10], b1[1:0], i_b[7:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[29:8], q1[1:0], i_a[5:0]} : {i_b[29:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[29:8], b1[1:0], i_b[5:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[29:6], q1[1:0], i_a[3:0]} : {i_b[29:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[29:6], b1[1:0], i_b[3:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[29:4], q1[1:0], i_a[1:0]} : {i_b[29:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[29:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[29:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd25:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[30:29], q1[1:0], i_a[26:0]} : {i_b[30:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[30:29], b1[1:0], i_b[26:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[30:27], q1[1:0], i_a[24:0]} : {i_b[30:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[30:27], b1[1:0], i_b[24:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[30:25], q1[1:0], i_a[22:0]} : {i_b[30:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[30:25], b1[1:0], i_b[22:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[30:23], q1[1:0], i_a[20:0]} : {i_b[30:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[30:23], b1[1:0], i_b[20:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[30:21], q1[1:0], i_a[18:0]} : {i_b[30:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[30:21], b1[1:0], i_b[18:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[30:19], q1[1:0], i_a[16:0]} : {i_b[30:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[30:19], b1[1:0], i_b[16:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[30:17], q1[1:0], i_a[14:0]} : {i_b[30:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[30:17], b1[1:0], i_b[14:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[30:15], q1[1:0], i_a[12:0]} : {i_b[30:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[30:15], b1[1:0], i_b[12:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[30:13], q1[1:0], i_a[10:0]} : {i_b[30:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[30:13], b1[1:0], i_b[10:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[30:11], q1[1:0], i_a[8:0]} : {i_b[30:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[30:11], b1[1:0], i_b[8:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[30:9], q1[1:0], i_a[6:0]} : {i_b[30:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[30:9], b1[1:0], i_b[6:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[30:7], q1[1:0], i_a[4:0]} : {i_b[30:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[30:7], b1[1:0], i_b[4:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[30:5], q1[1:0], i_a[2:0]} : {i_b[30:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[30:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[30:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd26:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[31:30], q1[1:0], i_a[27:0]} : {i_b[31:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[31:30], b1[1:0], i_b[27:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[31:28], q1[1:0], i_a[25:0]} : {i_b[31:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[31:28], b1[1:0], i_b[25:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[31:26], q1[1:0], i_a[23:0]} : {i_b[31:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[31:26], b1[1:0], i_b[23:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[31:24], q1[1:0], i_a[21:0]} : {i_b[31:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[31:24], b1[1:0], i_b[21:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[31:22], q1[1:0], i_a[19:0]} : {i_b[31:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[31:22], b1[1:0], i_b[19:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[31:20], q1[1:0], i_a[17:0]} : {i_b[31:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[31:20], b1[1:0], i_b[17:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[31:18], q1[1:0], i_a[15:0]} : {i_b[31:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[31:18], b1[1:0], i_b[15:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[31:16], q1[1:0], i_a[13:0]} : {i_b[31:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[31:16], b1[1:0], i_b[13:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[31:14], q1[1:0], i_a[11:0]} : {i_b[31:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[31:14], b1[1:0], i_b[11:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[31:12], q1[1:0], i_a[9:0]} : {i_b[31:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[31:12], b1[1:0], i_b[9:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[31:10], q1[1:0], i_a[7:0]} : {i_b[31:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[31:10], b1[1:0], i_b[7:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[31:8], q1[1:0], i_a[5:0]} : {i_b[31:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[31:8], b1[1:0], i_b[5:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[31:6], q1[1:0], i_a[3:0]} : {i_b[31:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[31:6], b1[1:0], i_b[3:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[31:4], q1[1:0], i_a[1:0]} : {i_b[31:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[31:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[31:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd27:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[32:31], q1[1:0], i_a[28:0]} : {i_b[32:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[32:31], b1[1:0], i_b[28:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[32:29], q1[1:0], i_a[26:0]} : {i_b[32:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[32:29], b1[1:0], i_b[26:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[32:27], q1[1:0], i_a[24:0]} : {i_b[32:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[32:27], b1[1:0], i_b[24:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[32:25], q1[1:0], i_a[22:0]} : {i_b[32:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[32:25], b1[1:0], i_b[22:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[32:23], q1[1:0], i_a[20:0]} : {i_b[32:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[32:23], b1[1:0], i_b[20:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[32:21], q1[1:0], i_a[18:0]} : {i_b[32:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[32:21], b1[1:0], i_b[18:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[32:19], q1[1:0], i_a[16:0]} : {i_b[32:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[32:19], b1[1:0], i_b[16:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[32:17], q1[1:0], i_a[14:0]} : {i_b[32:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[32:17], b1[1:0], i_b[14:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[32:15], q1[1:0], i_a[12:0]} : {i_b[32:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[32:15], b1[1:0], i_b[12:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[32:13], q1[1:0], i_a[10:0]} : {i_b[32:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[32:13], b1[1:0], i_b[10:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[32:11], q1[1:0], i_a[8:0]} : {i_b[32:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[32:11], b1[1:0], i_b[8:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[32:9], q1[1:0], i_a[6:0]} : {i_b[32:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[32:9], b1[1:0], i_b[6:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[32:7], q1[1:0], i_a[4:0]} : {i_b[32:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[32:7], b1[1:0], i_b[4:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[32:5], q1[1:0], i_a[2:0]} : {i_b[32:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[32:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[32:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd28:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[33:32], q1[1:0], i_a[29:0]} : {i_b[33:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[33:32], b1[1:0], i_b[29:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[33:30], q1[1:0], i_a[27:0]} : {i_b[33:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[33:30], b1[1:0], i_b[27:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[33:28], q1[1:0], i_a[25:0]} : {i_b[33:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[33:28], b1[1:0], i_b[25:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[33:26], q1[1:0], i_a[23:0]} : {i_b[33:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[33:26], b1[1:0], i_b[23:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[33:24], q1[1:0], i_a[21:0]} : {i_b[33:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[33:24], b1[1:0], i_b[21:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[33:22], q1[1:0], i_a[19:0]} : {i_b[33:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[33:22], b1[1:0], i_b[19:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[33:20], q1[1:0], i_a[17:0]} : {i_b[33:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[33:20], b1[1:0], i_b[17:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[33:18], q1[1:0], i_a[15:0]} : {i_b[33:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[33:18], b1[1:0], i_b[15:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[33:16], q1[1:0], i_a[13:0]} : {i_b[33:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[33:16], b1[1:0], i_b[13:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[33:14], q1[1:0], i_a[11:0]} : {i_b[33:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[33:14], b1[1:0], i_b[11:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[33:12], q1[1:0], i_a[9:0]} : {i_b[33:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[33:12], b1[1:0], i_b[9:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[33:10], q1[1:0], i_a[7:0]} : {i_b[33:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[33:10], b1[1:0], i_b[7:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[33:8], q1[1:0], i_a[5:0]} : {i_b[33:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[33:8], b1[1:0], i_b[5:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[33:6], q1[1:0], i_a[3:0]} : {i_b[33:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[33:6], b1[1:0], i_b[3:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[33:4], q1[1:0], i_a[1:0]} : {i_b[33:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[33:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[33:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd29:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[34:33], q1[1:0], i_a[30:0]} : {i_b[34:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[34:33], b1[1:0], i_b[30:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[34:31], q1[1:0], i_a[28:0]} : {i_b[34:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[34:31], b1[1:0], i_b[28:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[34:29], q1[1:0], i_a[26:0]} : {i_b[34:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[34:29], b1[1:0], i_b[26:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[34:27], q1[1:0], i_a[24:0]} : {i_b[34:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[34:27], b1[1:0], i_b[24:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[34:25], q1[1:0], i_a[22:0]} : {i_b[34:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[34:25], b1[1:0], i_b[22:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[34:23], q1[1:0], i_a[20:0]} : {i_b[34:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[34:23], b1[1:0], i_b[20:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[34:21], q1[1:0], i_a[18:0]} : {i_b[34:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[34:21], b1[1:0], i_b[18:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[34:19], q1[1:0], i_a[16:0]} : {i_b[34:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[34:19], b1[1:0], i_b[16:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[34:17], q1[1:0], i_a[14:0]} : {i_b[34:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[34:17], b1[1:0], i_b[14:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[34:15], q1[1:0], i_a[12:0]} : {i_b[34:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[34:15], b1[1:0], i_b[12:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[34:13], q1[1:0], i_a[10:0]} : {i_b[34:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[34:13], b1[1:0], i_b[10:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[34:11], q1[1:0], i_a[8:0]} : {i_b[34:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[34:11], b1[1:0], i_b[8:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[34:9], q1[1:0], i_a[6:0]} : {i_b[34:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[34:9], b1[1:0], i_b[6:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[34:7], q1[1:0], i_a[4:0]} : {i_b[34:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[34:7], b1[1:0], i_b[4:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[34:5], q1[1:0], i_a[2:0]} : {i_b[34:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[34:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[34:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd30:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[35:34], q1[1:0], i_a[31:0]} : {i_b[35:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[35:34], b1[1:0], i_b[31:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[35:32], q1[1:0], i_a[29:0]} : {i_b[35:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[35:32], b1[1:0], i_b[29:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[35:30], q1[1:0], i_a[27:0]} : {i_b[35:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[35:30], b1[1:0], i_b[27:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[35:28], q1[1:0], i_a[25:0]} : {i_b[35:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[35:28], b1[1:0], i_b[25:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[35:26], q1[1:0], i_a[23:0]} : {i_b[35:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[35:26], b1[1:0], i_b[23:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[35:24], q1[1:0], i_a[21:0]} : {i_b[35:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[35:24], b1[1:0], i_b[21:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[35:22], q1[1:0], i_a[19:0]} : {i_b[35:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[35:22], b1[1:0], i_b[19:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[35:20], q1[1:0], i_a[17:0]} : {i_b[35:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[35:20], b1[1:0], i_b[17:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[35:18], q1[1:0], i_a[15:0]} : {i_b[35:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[35:18], b1[1:0], i_b[15:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[35:16], q1[1:0], i_a[13:0]} : {i_b[35:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[35:16], b1[1:0], i_b[13:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[35:14], q1[1:0], i_a[11:0]} : {i_b[35:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[35:14], b1[1:0], i_b[11:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[35:12], q1[1:0], i_a[9:0]} : {i_b[35:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[35:12], b1[1:0], i_b[9:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[35:10], q1[1:0], i_a[7:0]} : {i_b[35:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[35:10], b1[1:0], i_b[7:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[35:8], q1[1:0], i_a[5:0]} : {i_b[35:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[35:8], b1[1:0], i_b[5:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[35:6], q1[1:0], i_a[3:0]} : {i_b[35:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[35:6], b1[1:0], i_b[3:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[35:4], q1[1:0], i_a[1:0]} : {i_b[35:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[35:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[35:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd31:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[36:35], q1[1:0], i_a[32:0]} : {i_b[36:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[36:35], b1[1:0], i_b[32:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[36:33], q1[1:0], i_a[30:0]} : {i_b[36:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[36:33], b1[1:0], i_b[30:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[36:31], q1[1:0], i_a[28:0]} : {i_b[36:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[36:31], b1[1:0], i_b[28:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[36:29], q1[1:0], i_a[26:0]} : {i_b[36:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[36:29], b1[1:0], i_b[26:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[36:27], q1[1:0], i_a[24:0]} : {i_b[36:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[36:27], b1[1:0], i_b[24:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[36:25], q1[1:0], i_a[22:0]} : {i_b[36:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[36:25], b1[1:0], i_b[22:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[36:23], q1[1:0], i_a[20:0]} : {i_b[36:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[36:23], b1[1:0], i_b[20:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[36:21], q1[1:0], i_a[18:0]} : {i_b[36:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[36:21], b1[1:0], i_b[18:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[36:19], q1[1:0], i_a[16:0]} : {i_b[36:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[36:19], b1[1:0], i_b[16:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[36:17], q1[1:0], i_a[14:0]} : {i_b[36:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[36:17], b1[1:0], i_b[14:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[36:15], q1[1:0], i_a[12:0]} : {i_b[36:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[36:15], b1[1:0], i_b[12:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[36:13], q1[1:0], i_a[10:0]} : {i_b[36:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[36:13], b1[1:0], i_b[10:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[36:11], q1[1:0], i_a[8:0]} : {i_b[36:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[36:11], b1[1:0], i_b[8:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[36:9], q1[1:0], i_a[6:0]} : {i_b[36:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[36:9], b1[1:0], i_b[6:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[36:7], q1[1:0], i_a[4:0]} : {i_b[36:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[36:7], b1[1:0], i_b[4:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[36:5], q1[1:0], i_a[2:0]} : {i_b[36:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[36:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[36:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd32:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[37:36], q1[1:0], i_a[33:0]} : {i_b[37:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[37:36], b1[1:0], i_b[33:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[37:34], q1[1:0], i_a[31:0]} : {i_b[37:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[37:34], b1[1:0], i_b[31:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[37:32], q1[1:0], i_a[29:0]} : {i_b[37:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[37:32], b1[1:0], i_b[29:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[37:30], q1[1:0], i_a[27:0]} : {i_b[37:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[37:30], b1[1:0], i_b[27:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[37:28], q1[1:0], i_a[25:0]} : {i_b[37:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[37:28], b1[1:0], i_b[25:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[37:26], q1[1:0], i_a[23:0]} : {i_b[37:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[37:26], b1[1:0], i_b[23:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[37:24], q1[1:0], i_a[21:0]} : {i_b[37:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[37:24], b1[1:0], i_b[21:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[37:22], q1[1:0], i_a[19:0]} : {i_b[37:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[37:22], b1[1:0], i_b[19:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[37:20], q1[1:0], i_a[17:0]} : {i_b[37:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[37:20], b1[1:0], i_b[17:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[37:18], q1[1:0], i_a[15:0]} : {i_b[37:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[37:18], b1[1:0], i_b[15:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[37:16], q1[1:0], i_a[13:0]} : {i_b[37:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[37:16], b1[1:0], i_b[13:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[37:14], q1[1:0], i_a[11:0]} : {i_b[37:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[37:14], b1[1:0], i_b[11:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[37:12], q1[1:0], i_a[9:0]} : {i_b[37:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[37:12], b1[1:0], i_b[9:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[37:10], q1[1:0], i_a[7:0]} : {i_b[37:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[37:10], b1[1:0], i_b[7:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[37:8], q1[1:0], i_a[5:0]} : {i_b[37:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[37:8], b1[1:0], i_b[5:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[37:6], q1[1:0], i_a[3:0]} : {i_b[37:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[37:6], b1[1:0], i_b[3:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[37:4], q1[1:0], i_a[1:0]} : {i_b[37:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[37:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[37:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd33:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[38:37], q1[1:0], i_a[34:0]} : {i_b[38:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[38:37], b1[1:0], i_b[34:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[38:35], q1[1:0], i_a[32:0]} : {i_b[38:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[38:35], b1[1:0], i_b[32:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[38:33], q1[1:0], i_a[30:0]} : {i_b[38:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[38:33], b1[1:0], i_b[30:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[38:31], q1[1:0], i_a[28:0]} : {i_b[38:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[38:31], b1[1:0], i_b[28:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[38:29], q1[1:0], i_a[26:0]} : {i_b[38:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[38:29], b1[1:0], i_b[26:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[38:27], q1[1:0], i_a[24:0]} : {i_b[38:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[38:27], b1[1:0], i_b[24:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[38:25], q1[1:0], i_a[22:0]} : {i_b[38:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[38:25], b1[1:0], i_b[22:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[38:23], q1[1:0], i_a[20:0]} : {i_b[38:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[38:23], b1[1:0], i_b[20:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[38:21], q1[1:0], i_a[18:0]} : {i_b[38:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[38:21], b1[1:0], i_b[18:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[38:19], q1[1:0], i_a[16:0]} : {i_b[38:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[38:19], b1[1:0], i_b[16:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[38:17], q1[1:0], i_a[14:0]} : {i_b[38:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[38:17], b1[1:0], i_b[14:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[38:15], q1[1:0], i_a[12:0]} : {i_b[38:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[38:15], b1[1:0], i_b[12:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[38:13], q1[1:0], i_a[10:0]} : {i_b[38:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[38:13], b1[1:0], i_b[10:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[38:11], q1[1:0], i_a[8:0]} : {i_b[38:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[38:11], b1[1:0], i_b[8:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[38:9], q1[1:0], i_a[6:0]} : {i_b[38:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[38:9], b1[1:0], i_b[6:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[38:7], q1[1:0], i_a[4:0]} : {i_b[38:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[38:7], b1[1:0], i_b[4:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[38:5], q1[1:0], i_a[2:0]} : {i_b[38:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[38:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[38:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd34:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[39:38], q1[1:0], i_a[35:0]} : {i_b[39:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[39:38], b1[1:0], i_b[35:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[39:36], q1[1:0], i_a[33:0]} : {i_b[39:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[39:36], b1[1:0], i_b[33:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[39:34], q1[1:0], i_a[31:0]} : {i_b[39:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[39:34], b1[1:0], i_b[31:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[39:32], q1[1:0], i_a[29:0]} : {i_b[39:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[39:32], b1[1:0], i_b[29:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[39:30], q1[1:0], i_a[27:0]} : {i_b[39:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[39:30], b1[1:0], i_b[27:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[39:28], q1[1:0], i_a[25:0]} : {i_b[39:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[39:28], b1[1:0], i_b[25:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[39:26], q1[1:0], i_a[23:0]} : {i_b[39:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[39:26], b1[1:0], i_b[23:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[39:24], q1[1:0], i_a[21:0]} : {i_b[39:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[39:24], b1[1:0], i_b[21:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[39:22], q1[1:0], i_a[19:0]} : {i_b[39:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[39:22], b1[1:0], i_b[19:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[39:20], q1[1:0], i_a[17:0]} : {i_b[39:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[39:20], b1[1:0], i_b[17:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[39:18], q1[1:0], i_a[15:0]} : {i_b[39:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[39:18], b1[1:0], i_b[15:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[39:16], q1[1:0], i_a[13:0]} : {i_b[39:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[39:16], b1[1:0], i_b[13:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[39:14], q1[1:0], i_a[11:0]} : {i_b[39:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[39:14], b1[1:0], i_b[11:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[39:12], q1[1:0], i_a[9:0]} : {i_b[39:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[39:12], b1[1:0], i_b[9:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[39:10], q1[1:0], i_a[7:0]} : {i_b[39:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[39:10], b1[1:0], i_b[7:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[39:8], q1[1:0], i_a[5:0]} : {i_b[39:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[39:8], b1[1:0], i_b[5:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[39:6], q1[1:0], i_a[3:0]} : {i_b[39:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[39:6], b1[1:0], i_b[3:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[39:4], q1[1:0], i_a[1:0]} : {i_b[39:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[39:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[39:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd35:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[40:39], q1[1:0], i_a[36:0]} : {i_b[40:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[40:39], b1[1:0], i_b[36:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[40:37], q1[1:0], i_a[34:0]} : {i_b[40:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[40:37], b1[1:0], i_b[34:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[40:35], q1[1:0], i_a[32:0]} : {i_b[40:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[40:35], b1[1:0], i_b[32:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[40:33], q1[1:0], i_a[30:0]} : {i_b[40:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[40:33], b1[1:0], i_b[30:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[40:31], q1[1:0], i_a[28:0]} : {i_b[40:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[40:31], b1[1:0], i_b[28:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[40:29], q1[1:0], i_a[26:0]} : {i_b[40:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[40:29], b1[1:0], i_b[26:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[40:27], q1[1:0], i_a[24:0]} : {i_b[40:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[40:27], b1[1:0], i_b[24:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[40:25], q1[1:0], i_a[22:0]} : {i_b[40:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[40:25], b1[1:0], i_b[22:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[40:23], q1[1:0], i_a[20:0]} : {i_b[40:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[40:23], b1[1:0], i_b[20:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[40:21], q1[1:0], i_a[18:0]} : {i_b[40:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[40:21], b1[1:0], i_b[18:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[40:19], q1[1:0], i_a[16:0]} : {i_b[40:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[40:19], b1[1:0], i_b[16:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[40:17], q1[1:0], i_a[14:0]} : {i_b[40:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[40:17], b1[1:0], i_b[14:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[40:15], q1[1:0], i_a[12:0]} : {i_b[40:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[40:15], b1[1:0], i_b[12:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[40:13], q1[1:0], i_a[10:0]} : {i_b[40:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[40:13], b1[1:0], i_b[10:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[40:11], q1[1:0], i_a[8:0]} : {i_b[40:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[40:11], b1[1:0], i_b[8:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[40:9], q1[1:0], i_a[6:0]} : {i_b[40:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[40:9], b1[1:0], i_b[6:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[40:7], q1[1:0], i_a[4:0]} : {i_b[40:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[40:7], b1[1:0], i_b[4:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[40:5], q1[1:0], i_a[2:0]} : {i_b[40:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[40:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[40:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd36:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[41:40], q1[1:0], i_a[37:0]} : {i_b[41:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[41:40], b1[1:0], i_b[37:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[41:38], q1[1:0], i_a[35:0]} : {i_b[41:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[41:38], b1[1:0], i_b[35:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[41:36], q1[1:0], i_a[33:0]} : {i_b[41:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[41:36], b1[1:0], i_b[33:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[41:34], q1[1:0], i_a[31:0]} : {i_b[41:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[41:34], b1[1:0], i_b[31:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[41:32], q1[1:0], i_a[29:0]} : {i_b[41:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[41:32], b1[1:0], i_b[29:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[41:30], q1[1:0], i_a[27:0]} : {i_b[41:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[41:30], b1[1:0], i_b[27:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[41:28], q1[1:0], i_a[25:0]} : {i_b[41:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[41:28], b1[1:0], i_b[25:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[41:26], q1[1:0], i_a[23:0]} : {i_b[41:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[41:26], b1[1:0], i_b[23:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[41:24], q1[1:0], i_a[21:0]} : {i_b[41:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[41:24], b1[1:0], i_b[21:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[41:22], q1[1:0], i_a[19:0]} : {i_b[41:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[41:22], b1[1:0], i_b[19:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[41:20], q1[1:0], i_a[17:0]} : {i_b[41:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[41:20], b1[1:0], i_b[17:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[41:18], q1[1:0], i_a[15:0]} : {i_b[41:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[41:18], b1[1:0], i_b[15:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[41:16], q1[1:0], i_a[13:0]} : {i_b[41:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[41:16], b1[1:0], i_b[13:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[41:14], q1[1:0], i_a[11:0]} : {i_b[41:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[41:14], b1[1:0], i_b[11:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[41:12], q1[1:0], i_a[9:0]} : {i_b[41:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[41:12], b1[1:0], i_b[9:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[41:10], q1[1:0], i_a[7:0]} : {i_b[41:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[41:10], b1[1:0], i_b[7:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[41:8], q1[1:0], i_a[5:0]} : {i_b[41:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[41:8], b1[1:0], i_b[5:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[41:6], q1[1:0], i_a[3:0]} : {i_b[41:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[41:6], b1[1:0], i_b[3:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[41:4], q1[1:0], i_a[1:0]} : {i_b[41:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[41:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[41:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd37:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[42:41], q1[1:0], i_a[38:0]} : {i_b[42:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[42:41], b1[1:0], i_b[38:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[42:39], q1[1:0], i_a[36:0]} : {i_b[42:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[42:39], b1[1:0], i_b[36:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[42:37], q1[1:0], i_a[34:0]} : {i_b[42:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[42:37], b1[1:0], i_b[34:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[42:35], q1[1:0], i_a[32:0]} : {i_b[42:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[42:35], b1[1:0], i_b[32:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[42:33], q1[1:0], i_a[30:0]} : {i_b[42:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[42:33], b1[1:0], i_b[30:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[42:31], q1[1:0], i_a[28:0]} : {i_b[42:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[42:31], b1[1:0], i_b[28:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[42:29], q1[1:0], i_a[26:0]} : {i_b[42:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[42:29], b1[1:0], i_b[26:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[42:27], q1[1:0], i_a[24:0]} : {i_b[42:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[42:27], b1[1:0], i_b[24:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[42:25], q1[1:0], i_a[22:0]} : {i_b[42:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[42:25], b1[1:0], i_b[22:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[42:23], q1[1:0], i_a[20:0]} : {i_b[42:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[42:23], b1[1:0], i_b[20:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[42:21], q1[1:0], i_a[18:0]} : {i_b[42:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[42:21], b1[1:0], i_b[18:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[42:19], q1[1:0], i_a[16:0]} : {i_b[42:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[42:19], b1[1:0], i_b[16:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[42:17], q1[1:0], i_a[14:0]} : {i_b[42:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[42:17], b1[1:0], i_b[14:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[42:15], q1[1:0], i_a[12:0]} : {i_b[42:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[42:15], b1[1:0], i_b[12:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[42:13], q1[1:0], i_a[10:0]} : {i_b[42:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[42:13], b1[1:0], i_b[10:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[42:11], q1[1:0], i_a[8:0]} : {i_b[42:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[42:11], b1[1:0], i_b[8:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[42:9], q1[1:0], i_a[6:0]} : {i_b[42:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[42:9], b1[1:0], i_b[6:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[42:7], q1[1:0], i_a[4:0]} : {i_b[42:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[42:7], b1[1:0], i_b[4:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[42:5], q1[1:0], i_a[2:0]} : {i_b[42:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[42:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[42:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd38:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[43:42], q1[1:0], i_a[39:0]} : {i_b[43:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[43:42], b1[1:0], i_b[39:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[43:40], q1[1:0], i_a[37:0]} : {i_b[43:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[43:40], b1[1:0], i_b[37:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[43:38], q1[1:0], i_a[35:0]} : {i_b[43:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[43:38], b1[1:0], i_b[35:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[43:36], q1[1:0], i_a[33:0]} : {i_b[43:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[43:36], b1[1:0], i_b[33:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[43:34], q1[1:0], i_a[31:0]} : {i_b[43:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[43:34], b1[1:0], i_b[31:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[43:32], q1[1:0], i_a[29:0]} : {i_b[43:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[43:32], b1[1:0], i_b[29:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[43:30], q1[1:0], i_a[27:0]} : {i_b[43:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[43:30], b1[1:0], i_b[27:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[43:28], q1[1:0], i_a[25:0]} : {i_b[43:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[43:28], b1[1:0], i_b[25:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[43:26], q1[1:0], i_a[23:0]} : {i_b[43:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[43:26], b1[1:0], i_b[23:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[43:24], q1[1:0], i_a[21:0]} : {i_b[43:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[43:24], b1[1:0], i_b[21:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[43:22], q1[1:0], i_a[19:0]} : {i_b[43:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[43:22], b1[1:0], i_b[19:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[43:20], q1[1:0], i_a[17:0]} : {i_b[43:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[43:20], b1[1:0], i_b[17:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[43:18], q1[1:0], i_a[15:0]} : {i_b[43:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[43:18], b1[1:0], i_b[15:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[43:16], q1[1:0], i_a[13:0]} : {i_b[43:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[43:16], b1[1:0], i_b[13:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[43:14], q1[1:0], i_a[11:0]} : {i_b[43:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[43:14], b1[1:0], i_b[11:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[43:12], q1[1:0], i_a[9:0]} : {i_b[43:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[43:12], b1[1:0], i_b[9:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[43:10], q1[1:0], i_a[7:0]} : {i_b[43:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[43:10], b1[1:0], i_b[7:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[43:8], q1[1:0], i_a[5:0]} : {i_b[43:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[43:8], b1[1:0], i_b[5:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[43:6], q1[1:0], i_a[3:0]} : {i_b[43:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[43:6], b1[1:0], i_b[3:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[43:4], q1[1:0], i_a[1:0]} : {i_b[43:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[43:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[43:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd39:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[44:43], q1[1:0], i_a[40:0]} : {i_b[44:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[44:43], b1[1:0], i_b[40:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[44:41], q1[1:0], i_a[38:0]} : {i_b[44:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[44:41], b1[1:0], i_b[38:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[44:39], q1[1:0], i_a[36:0]} : {i_b[44:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[44:39], b1[1:0], i_b[36:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[44:37], q1[1:0], i_a[34:0]} : {i_b[44:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[44:37], b1[1:0], i_b[34:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[44:35], q1[1:0], i_a[32:0]} : {i_b[44:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[44:35], b1[1:0], i_b[32:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[44:33], q1[1:0], i_a[30:0]} : {i_b[44:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[44:33], b1[1:0], i_b[30:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[44:31], q1[1:0], i_a[28:0]} : {i_b[44:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[44:31], b1[1:0], i_b[28:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[44:29], q1[1:0], i_a[26:0]} : {i_b[44:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[44:29], b1[1:0], i_b[26:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[44:27], q1[1:0], i_a[24:0]} : {i_b[44:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[44:27], b1[1:0], i_b[24:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[44:25], q1[1:0], i_a[22:0]} : {i_b[44:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[44:25], b1[1:0], i_b[22:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[44:23], q1[1:0], i_a[20:0]} : {i_b[44:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[44:23], b1[1:0], i_b[20:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[44:21], q1[1:0], i_a[18:0]} : {i_b[44:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[44:21], b1[1:0], i_b[18:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[44:19], q1[1:0], i_a[16:0]} : {i_b[44:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[44:19], b1[1:0], i_b[16:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[44:17], q1[1:0], i_a[14:0]} : {i_b[44:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[44:17], b1[1:0], i_b[14:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[44:15], q1[1:0], i_a[12:0]} : {i_b[44:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[44:15], b1[1:0], i_b[12:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[44:13], q1[1:0], i_a[10:0]} : {i_b[44:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[44:13], b1[1:0], i_b[10:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[44:11], q1[1:0], i_a[8:0]} : {i_b[44:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[44:11], b1[1:0], i_b[8:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[44:9], q1[1:0], i_a[6:0]} : {i_b[44:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[44:9], b1[1:0], i_b[6:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[44:7], q1[1:0], i_a[4:0]} : {i_b[44:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[44:7], b1[1:0], i_b[4:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[44:5], q1[1:0], i_a[2:0]} : {i_b[44:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[44:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[44:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd40:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[45:44], q1[1:0], i_a[41:0]} : {i_b[45:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[45:44], b1[1:0], i_b[41:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[45:42], q1[1:0], i_a[39:0]} : {i_b[45:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[45:42], b1[1:0], i_b[39:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[45:40], q1[1:0], i_a[37:0]} : {i_b[45:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[45:40], b1[1:0], i_b[37:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[45:38], q1[1:0], i_a[35:0]} : {i_b[45:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[45:38], b1[1:0], i_b[35:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[45:36], q1[1:0], i_a[33:0]} : {i_b[45:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[45:36], b1[1:0], i_b[33:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[45:34], q1[1:0], i_a[31:0]} : {i_b[45:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[45:34], b1[1:0], i_b[31:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[45:32], q1[1:0], i_a[29:0]} : {i_b[45:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[45:32], b1[1:0], i_b[29:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[45:30], q1[1:0], i_a[27:0]} : {i_b[45:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[45:30], b1[1:0], i_b[27:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[45:28], q1[1:0], i_a[25:0]} : {i_b[45:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[45:28], b1[1:0], i_b[25:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[45:26], q1[1:0], i_a[23:0]} : {i_b[45:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[45:26], b1[1:0], i_b[23:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[45:24], q1[1:0], i_a[21:0]} : {i_b[45:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[45:24], b1[1:0], i_b[21:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[45:22], q1[1:0], i_a[19:0]} : {i_b[45:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[45:22], b1[1:0], i_b[19:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[45:20], q1[1:0], i_a[17:0]} : {i_b[45:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[45:20], b1[1:0], i_b[17:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[45:18], q1[1:0], i_a[15:0]} : {i_b[45:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[45:18], b1[1:0], i_b[15:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[45:16], q1[1:0], i_a[13:0]} : {i_b[45:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[45:16], b1[1:0], i_b[13:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[45:14], q1[1:0], i_a[11:0]} : {i_b[45:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[45:14], b1[1:0], i_b[11:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[45:12], q1[1:0], i_a[9:0]} : {i_b[45:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[45:12], b1[1:0], i_b[9:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[45:10], q1[1:0], i_a[7:0]} : {i_b[45:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[45:10], b1[1:0], i_b[7:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[45:8], q1[1:0], i_a[5:0]} : {i_b[45:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[45:8], b1[1:0], i_b[5:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[45:6], q1[1:0], i_a[3:0]} : {i_b[45:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[45:6], b1[1:0], i_b[3:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[45:4], q1[1:0], i_a[1:0]} : {i_b[45:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[45:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[45:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd41:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[46:45], q1[1:0], i_a[42:0]} : {i_b[46:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[46:45], b1[1:0], i_b[42:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[46:43], q1[1:0], i_a[40:0]} : {i_b[46:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[46:43], b1[1:0], i_b[40:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[46:41], q1[1:0], i_a[38:0]} : {i_b[46:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[46:41], b1[1:0], i_b[38:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[46:39], q1[1:0], i_a[36:0]} : {i_b[46:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[46:39], b1[1:0], i_b[36:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[46:37], q1[1:0], i_a[34:0]} : {i_b[46:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[46:37], b1[1:0], i_b[34:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[46:35], q1[1:0], i_a[32:0]} : {i_b[46:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[46:35], b1[1:0], i_b[32:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[46:33], q1[1:0], i_a[30:0]} : {i_b[46:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[46:33], b1[1:0], i_b[30:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[46:31], q1[1:0], i_a[28:0]} : {i_b[46:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[46:31], b1[1:0], i_b[28:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[46:29], q1[1:0], i_a[26:0]} : {i_b[46:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[46:29], b1[1:0], i_b[26:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[46:27], q1[1:0], i_a[24:0]} : {i_b[46:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[46:27], b1[1:0], i_b[24:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[46:25], q1[1:0], i_a[22:0]} : {i_b[46:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[46:25], b1[1:0], i_b[22:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[46:23], q1[1:0], i_a[20:0]} : {i_b[46:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[46:23], b1[1:0], i_b[20:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[46:21], q1[1:0], i_a[18:0]} : {i_b[46:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[46:21], b1[1:0], i_b[18:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[46:19], q1[1:0], i_a[16:0]} : {i_b[46:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[46:19], b1[1:0], i_b[16:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[46:17], q1[1:0], i_a[14:0]} : {i_b[46:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[46:17], b1[1:0], i_b[14:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[46:15], q1[1:0], i_a[12:0]} : {i_b[46:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[46:15], b1[1:0], i_b[12:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[46:13], q1[1:0], i_a[10:0]} : {i_b[46:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[46:13], b1[1:0], i_b[10:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[46:11], q1[1:0], i_a[8:0]} : {i_b[46:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[46:11], b1[1:0], i_b[8:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[46:9], q1[1:0], i_a[6:0]} : {i_b[46:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[46:9], b1[1:0], i_b[6:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[46:7], q1[1:0], i_a[4:0]} : {i_b[46:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[46:7], b1[1:0], i_b[4:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[46:5], q1[1:0], i_a[2:0]} : {i_b[46:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[46:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[46:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd42:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[47:46], q1[1:0], i_a[43:0]} : {i_b[47:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[47:46], b1[1:0], i_b[43:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[47:44], q1[1:0], i_a[41:0]} : {i_b[47:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[47:44], b1[1:0], i_b[41:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[47:42], q1[1:0], i_a[39:0]} : {i_b[47:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[47:42], b1[1:0], i_b[39:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[47:40], q1[1:0], i_a[37:0]} : {i_b[47:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[47:40], b1[1:0], i_b[37:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[47:38], q1[1:0], i_a[35:0]} : {i_b[47:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[47:38], b1[1:0], i_b[35:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[47:36], q1[1:0], i_a[33:0]} : {i_b[47:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[47:36], b1[1:0], i_b[33:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[47:34], q1[1:0], i_a[31:0]} : {i_b[47:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[47:34], b1[1:0], i_b[31:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[47:32], q1[1:0], i_a[29:0]} : {i_b[47:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[47:32], b1[1:0], i_b[29:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[47:30], q1[1:0], i_a[27:0]} : {i_b[47:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[47:30], b1[1:0], i_b[27:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[47:28], q1[1:0], i_a[25:0]} : {i_b[47:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[47:28], b1[1:0], i_b[25:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[47:26], q1[1:0], i_a[23:0]} : {i_b[47:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[47:26], b1[1:0], i_b[23:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[47:24], q1[1:0], i_a[21:0]} : {i_b[47:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[47:24], b1[1:0], i_b[21:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[47:22], q1[1:0], i_a[19:0]} : {i_b[47:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[47:22], b1[1:0], i_b[19:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[47:20], q1[1:0], i_a[17:0]} : {i_b[47:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[47:20], b1[1:0], i_b[17:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[47:18], q1[1:0], i_a[15:0]} : {i_b[47:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[47:18], b1[1:0], i_b[15:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[47:16], q1[1:0], i_a[13:0]} : {i_b[47:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[47:16], b1[1:0], i_b[13:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[47:14], q1[1:0], i_a[11:0]} : {i_b[47:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[47:14], b1[1:0], i_b[11:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[47:12], q1[1:0], i_a[9:0]} : {i_b[47:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[47:12], b1[1:0], i_b[9:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[47:10], q1[1:0], i_a[7:0]} : {i_b[47:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[47:10], b1[1:0], i_b[7:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[47:8], q1[1:0], i_a[5:0]} : {i_b[47:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[47:8], b1[1:0], i_b[5:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[47:6], q1[1:0], i_a[3:0]} : {i_b[47:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[47:6], b1[1:0], i_b[3:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[47:4], q1[1:0], i_a[1:0]} : {i_b[47:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[47:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[47:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd43:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[48:47], q1[1:0], i_a[44:0]} : {i_b[48:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[48:47], b1[1:0], i_b[44:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[48:45], q1[1:0], i_a[42:0]} : {i_b[48:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[48:45], b1[1:0], i_b[42:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[48:43], q1[1:0], i_a[40:0]} : {i_b[48:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[48:43], b1[1:0], i_b[40:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[48:41], q1[1:0], i_a[38:0]} : {i_b[48:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[48:41], b1[1:0], i_b[38:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[48:39], q1[1:0], i_a[36:0]} : {i_b[48:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[48:39], b1[1:0], i_b[36:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[48:37], q1[1:0], i_a[34:0]} : {i_b[48:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[48:37], b1[1:0], i_b[34:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[48:35], q1[1:0], i_a[32:0]} : {i_b[48:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[48:35], b1[1:0], i_b[32:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[48:33], q1[1:0], i_a[30:0]} : {i_b[48:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[48:33], b1[1:0], i_b[30:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[48:31], q1[1:0], i_a[28:0]} : {i_b[48:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[48:31], b1[1:0], i_b[28:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[48:29], q1[1:0], i_a[26:0]} : {i_b[48:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[48:29], b1[1:0], i_b[26:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[48:27], q1[1:0], i_a[24:0]} : {i_b[48:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[48:27], b1[1:0], i_b[24:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[48:25], q1[1:0], i_a[22:0]} : {i_b[48:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[48:25], b1[1:0], i_b[22:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[48:23], q1[1:0], i_a[20:0]} : {i_b[48:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[48:23], b1[1:0], i_b[20:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[48:21], q1[1:0], i_a[18:0]} : {i_b[48:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[48:21], b1[1:0], i_b[18:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[48:19], q1[1:0], i_a[16:0]} : {i_b[48:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[48:19], b1[1:0], i_b[16:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[48:17], q1[1:0], i_a[14:0]} : {i_b[48:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[48:17], b1[1:0], i_b[14:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[48:15], q1[1:0], i_a[12:0]} : {i_b[48:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[48:15], b1[1:0], i_b[12:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[48:13], q1[1:0], i_a[10:0]} : {i_b[48:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[48:13], b1[1:0], i_b[10:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[48:11], q1[1:0], i_a[8:0]} : {i_b[48:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[48:11], b1[1:0], i_b[8:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[48:9], q1[1:0], i_a[6:0]} : {i_b[48:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[48:9], b1[1:0], i_b[6:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[48:7], q1[1:0], i_a[4:0]} : {i_b[48:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[48:7], b1[1:0], i_b[4:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[48:5], q1[1:0], i_a[2:0]} : {i_b[48:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[48:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[48:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd44:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[49:48], q1[1:0], i_a[45:0]} : {i_b[49:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[49:48], b1[1:0], i_b[45:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[49:46], q1[1:0], i_a[43:0]} : {i_b[49:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[49:46], b1[1:0], i_b[43:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[49:44], q1[1:0], i_a[41:0]} : {i_b[49:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[49:44], b1[1:0], i_b[41:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[49:42], q1[1:0], i_a[39:0]} : {i_b[49:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[49:42], b1[1:0], i_b[39:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[49:40], q1[1:0], i_a[37:0]} : {i_b[49:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[49:40], b1[1:0], i_b[37:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[49:38], q1[1:0], i_a[35:0]} : {i_b[49:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[49:38], b1[1:0], i_b[35:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[49:36], q1[1:0], i_a[33:0]} : {i_b[49:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[49:36], b1[1:0], i_b[33:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[49:34], q1[1:0], i_a[31:0]} : {i_b[49:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[49:34], b1[1:0], i_b[31:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[49:32], q1[1:0], i_a[29:0]} : {i_b[49:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[49:32], b1[1:0], i_b[29:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[49:30], q1[1:0], i_a[27:0]} : {i_b[49:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[49:30], b1[1:0], i_b[27:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[49:28], q1[1:0], i_a[25:0]} : {i_b[49:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[49:28], b1[1:0], i_b[25:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[49:26], q1[1:0], i_a[23:0]} : {i_b[49:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[49:26], b1[1:0], i_b[23:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[49:24], q1[1:0], i_a[21:0]} : {i_b[49:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[49:24], b1[1:0], i_b[21:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[49:22], q1[1:0], i_a[19:0]} : {i_b[49:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[49:22], b1[1:0], i_b[19:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[49:20], q1[1:0], i_a[17:0]} : {i_b[49:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[49:20], b1[1:0], i_b[17:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[49:18], q1[1:0], i_a[15:0]} : {i_b[49:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[49:18], b1[1:0], i_b[15:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[49:16], q1[1:0], i_a[13:0]} : {i_b[49:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[49:16], b1[1:0], i_b[13:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[49:14], q1[1:0], i_a[11:0]} : {i_b[49:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[49:14], b1[1:0], i_b[11:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[49:12], q1[1:0], i_a[9:0]} : {i_b[49:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[49:12], b1[1:0], i_b[9:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[49:10], q1[1:0], i_a[7:0]} : {i_b[49:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[49:10], b1[1:0], i_b[7:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[49:8], q1[1:0], i_a[5:0]} : {i_b[49:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[49:8], b1[1:0], i_b[5:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[49:6], q1[1:0], i_a[3:0]} : {i_b[49:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[49:6], b1[1:0], i_b[3:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[49:4], q1[1:0], i_a[1:0]} : {i_b[49:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[49:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[49:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd45:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[50:49], q1[1:0], i_a[46:0]} : {i_b[50:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[50:49], b1[1:0], i_b[46:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[50:47], q1[1:0], i_a[44:0]} : {i_b[50:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[50:47], b1[1:0], i_b[44:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[50:45], q1[1:0], i_a[42:0]} : {i_b[50:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[50:45], b1[1:0], i_b[42:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[50:43], q1[1:0], i_a[40:0]} : {i_b[50:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[50:43], b1[1:0], i_b[40:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[50:41], q1[1:0], i_a[38:0]} : {i_b[50:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[50:41], b1[1:0], i_b[38:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[50:39], q1[1:0], i_a[36:0]} : {i_b[50:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[50:39], b1[1:0], i_b[36:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[50:37], q1[1:0], i_a[34:0]} : {i_b[50:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[50:37], b1[1:0], i_b[34:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[50:35], q1[1:0], i_a[32:0]} : {i_b[50:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[50:35], b1[1:0], i_b[32:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[50:33], q1[1:0], i_a[30:0]} : {i_b[50:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[50:33], b1[1:0], i_b[30:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[50:31], q1[1:0], i_a[28:0]} : {i_b[50:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[50:31], b1[1:0], i_b[28:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[50:29], q1[1:0], i_a[26:0]} : {i_b[50:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[50:29], b1[1:0], i_b[26:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[50:27], q1[1:0], i_a[24:0]} : {i_b[50:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[50:27], b1[1:0], i_b[24:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[50:25], q1[1:0], i_a[22:0]} : {i_b[50:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[50:25], b1[1:0], i_b[22:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[50:23], q1[1:0], i_a[20:0]} : {i_b[50:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[50:23], b1[1:0], i_b[20:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[50:21], q1[1:0], i_a[18:0]} : {i_b[50:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[50:21], b1[1:0], i_b[18:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[50:19], q1[1:0], i_a[16:0]} : {i_b[50:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[50:19], b1[1:0], i_b[16:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[50:17], q1[1:0], i_a[14:0]} : {i_b[50:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[50:17], b1[1:0], i_b[14:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[50:15], q1[1:0], i_a[12:0]} : {i_b[50:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[50:15], b1[1:0], i_b[12:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[50:13], q1[1:0], i_a[10:0]} : {i_b[50:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[50:13], b1[1:0], i_b[10:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[50:11], q1[1:0], i_a[8:0]} : {i_b[50:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[50:11], b1[1:0], i_b[8:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[50:9], q1[1:0], i_a[6:0]} : {i_b[50:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[50:9], b1[1:0], i_b[6:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[50:7], q1[1:0], i_a[4:0]} : {i_b[50:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[50:7], b1[1:0], i_b[4:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[50:5], q1[1:0], i_a[2:0]} : {i_b[50:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[50:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[50:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd46:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[51:50], q1[1:0], i_a[47:0]} : {i_b[51:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[51:50], b1[1:0], i_b[47:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[51:48], q1[1:0], i_a[45:0]} : {i_b[51:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[51:48], b1[1:0], i_b[45:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[51:46], q1[1:0], i_a[43:0]} : {i_b[51:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[51:46], b1[1:0], i_b[43:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[51:44], q1[1:0], i_a[41:0]} : {i_b[51:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[51:44], b1[1:0], i_b[41:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[51:42], q1[1:0], i_a[39:0]} : {i_b[51:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[51:42], b1[1:0], i_b[39:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[51:40], q1[1:0], i_a[37:0]} : {i_b[51:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[51:40], b1[1:0], i_b[37:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[51:38], q1[1:0], i_a[35:0]} : {i_b[51:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[51:38], b1[1:0], i_b[35:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[51:36], q1[1:0], i_a[33:0]} : {i_b[51:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[51:36], b1[1:0], i_b[33:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[51:34], q1[1:0], i_a[31:0]} : {i_b[51:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[51:34], b1[1:0], i_b[31:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[51:32], q1[1:0], i_a[29:0]} : {i_b[51:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[51:32], b1[1:0], i_b[29:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[51:30], q1[1:0], i_a[27:0]} : {i_b[51:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[51:30], b1[1:0], i_b[27:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[51:28], q1[1:0], i_a[25:0]} : {i_b[51:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[51:28], b1[1:0], i_b[25:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[51:26], q1[1:0], i_a[23:0]} : {i_b[51:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[51:26], b1[1:0], i_b[23:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[51:24], q1[1:0], i_a[21:0]} : {i_b[51:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[51:24], b1[1:0], i_b[21:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[51:22], q1[1:0], i_a[19:0]} : {i_b[51:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[51:22], b1[1:0], i_b[19:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[51:20], q1[1:0], i_a[17:0]} : {i_b[51:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[51:20], b1[1:0], i_b[17:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[51:18], q1[1:0], i_a[15:0]} : {i_b[51:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[51:18], b1[1:0], i_b[15:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[51:16], q1[1:0], i_a[13:0]} : {i_b[51:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[51:16], b1[1:0], i_b[13:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[51:14], q1[1:0], i_a[11:0]} : {i_b[51:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[51:14], b1[1:0], i_b[11:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[51:12], q1[1:0], i_a[9:0]} : {i_b[51:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[51:12], b1[1:0], i_b[9:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[51:10], q1[1:0], i_a[7:0]} : {i_b[51:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[51:10], b1[1:0], i_b[7:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[51:8], q1[1:0], i_a[5:0]} : {i_b[51:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[51:8], b1[1:0], i_b[5:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[51:6], q1[1:0], i_a[3:0]} : {i_b[51:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[51:6], b1[1:0], i_b[3:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[51:4], q1[1:0], i_a[1:0]} : {i_b[51:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[51:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[51:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd47:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[52:51], q1[1:0], i_a[48:0]} : {i_b[52:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[52:51], b1[1:0], i_b[48:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[52:49], q1[1:0], i_a[46:0]} : {i_b[52:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[52:49], b1[1:0], i_b[46:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[52:47], q1[1:0], i_a[44:0]} : {i_b[52:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[52:47], b1[1:0], i_b[44:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[52:45], q1[1:0], i_a[42:0]} : {i_b[52:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[52:45], b1[1:0], i_b[42:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[52:43], q1[1:0], i_a[40:0]} : {i_b[52:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[52:43], b1[1:0], i_b[40:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[52:41], q1[1:0], i_a[38:0]} : {i_b[52:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[52:41], b1[1:0], i_b[38:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[52:39], q1[1:0], i_a[36:0]} : {i_b[52:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[52:39], b1[1:0], i_b[36:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[52:37], q1[1:0], i_a[34:0]} : {i_b[52:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[52:37], b1[1:0], i_b[34:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[52:35], q1[1:0], i_a[32:0]} : {i_b[52:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[52:35], b1[1:0], i_b[32:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[52:33], q1[1:0], i_a[30:0]} : {i_b[52:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[52:33], b1[1:0], i_b[30:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[52:31], q1[1:0], i_a[28:0]} : {i_b[52:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[52:31], b1[1:0], i_b[28:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[52:29], q1[1:0], i_a[26:0]} : {i_b[52:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[52:29], b1[1:0], i_b[26:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[52:27], q1[1:0], i_a[24:0]} : {i_b[52:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[52:27], b1[1:0], i_b[24:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[52:25], q1[1:0], i_a[22:0]} : {i_b[52:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[52:25], b1[1:0], i_b[22:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[52:23], q1[1:0], i_a[20:0]} : {i_b[52:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[52:23], b1[1:0], i_b[20:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[52:21], q1[1:0], i_a[18:0]} : {i_b[52:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[52:21], b1[1:0], i_b[18:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[52:19], q1[1:0], i_a[16:0]} : {i_b[52:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[52:19], b1[1:0], i_b[16:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[52:17], q1[1:0], i_a[14:0]} : {i_b[52:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[52:17], b1[1:0], i_b[14:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[52:15], q1[1:0], i_a[12:0]} : {i_b[52:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[52:15], b1[1:0], i_b[12:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[52:13], q1[1:0], i_a[10:0]} : {i_b[52:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[52:13], b1[1:0], i_b[10:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[52:11], q1[1:0], i_a[8:0]} : {i_b[52:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[52:11], b1[1:0], i_b[8:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[52:9], q1[1:0], i_a[6:0]} : {i_b[52:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[52:9], b1[1:0], i_b[6:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[52:7], q1[1:0], i_a[4:0]} : {i_b[52:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[52:7], b1[1:0], i_b[4:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[52:5], q1[1:0], i_a[2:0]} : {i_b[52:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[52:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[52:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd48:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[53:52], q1[1:0], i_a[49:0]} : {i_b[53:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[53:52], b1[1:0], i_b[49:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[53:50], q1[1:0], i_a[47:0]} : {i_b[53:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[53:50], b1[1:0], i_b[47:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[53:48], q1[1:0], i_a[45:0]} : {i_b[53:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[53:48], b1[1:0], i_b[45:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[53:46], q1[1:0], i_a[43:0]} : {i_b[53:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[53:46], b1[1:0], i_b[43:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[53:44], q1[1:0], i_a[41:0]} : {i_b[53:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[53:44], b1[1:0], i_b[41:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[53:42], q1[1:0], i_a[39:0]} : {i_b[53:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[53:42], b1[1:0], i_b[39:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[53:40], q1[1:0], i_a[37:0]} : {i_b[53:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[53:40], b1[1:0], i_b[37:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[53:38], q1[1:0], i_a[35:0]} : {i_b[53:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[53:38], b1[1:0], i_b[35:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[53:36], q1[1:0], i_a[33:0]} : {i_b[53:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[53:36], b1[1:0], i_b[33:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[53:34], q1[1:0], i_a[31:0]} : {i_b[53:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[53:34], b1[1:0], i_b[31:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[53:32], q1[1:0], i_a[29:0]} : {i_b[53:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[53:32], b1[1:0], i_b[29:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[53:30], q1[1:0], i_a[27:0]} : {i_b[53:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[53:30], b1[1:0], i_b[27:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[53:28], q1[1:0], i_a[25:0]} : {i_b[53:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[53:28], b1[1:0], i_b[25:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[53:26], q1[1:0], i_a[23:0]} : {i_b[53:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[53:26], b1[1:0], i_b[23:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[53:24], q1[1:0], i_a[21:0]} : {i_b[53:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[53:24], b1[1:0], i_b[21:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[53:22], q1[1:0], i_a[19:0]} : {i_b[53:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[53:22], b1[1:0], i_b[19:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[53:20], q1[1:0], i_a[17:0]} : {i_b[53:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[53:20], b1[1:0], i_b[17:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[53:18], q1[1:0], i_a[15:0]} : {i_b[53:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[53:18], b1[1:0], i_b[15:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[53:16], q1[1:0], i_a[13:0]} : {i_b[53:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[53:16], b1[1:0], i_b[13:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[53:14], q1[1:0], i_a[11:0]} : {i_b[53:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[53:14], b1[1:0], i_b[11:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[53:12], q1[1:0], i_a[9:0]} : {i_b[53:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[53:12], b1[1:0], i_b[9:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[53:10], q1[1:0], i_a[7:0]} : {i_b[53:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[53:10], b1[1:0], i_b[7:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[53:8], q1[1:0], i_a[5:0]} : {i_b[53:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[53:8], b1[1:0], i_b[5:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[53:6], q1[1:0], i_a[3:0]} : {i_b[53:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[53:6], b1[1:0], i_b[3:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[53:4], q1[1:0], i_a[1:0]} : {i_b[53:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[53:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[53:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd49:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[54:53], q1[1:0], i_a[50:0]} : {i_b[54:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[54:53], b1[1:0], i_b[50:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[54:51], q1[1:0], i_a[48:0]} : {i_b[54:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[54:51], b1[1:0], i_b[48:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[54:49], q1[1:0], i_a[46:0]} : {i_b[54:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[54:49], b1[1:0], i_b[46:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[54:47], q1[1:0], i_a[44:0]} : {i_b[54:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[54:47], b1[1:0], i_b[44:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[54:45], q1[1:0], i_a[42:0]} : {i_b[54:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[54:45], b1[1:0], i_b[42:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[54:43], q1[1:0], i_a[40:0]} : {i_b[54:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[54:43], b1[1:0], i_b[40:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[54:41], q1[1:0], i_a[38:0]} : {i_b[54:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[54:41], b1[1:0], i_b[38:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[54:39], q1[1:0], i_a[36:0]} : {i_b[54:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[54:39], b1[1:0], i_b[36:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[54:37], q1[1:0], i_a[34:0]} : {i_b[54:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[54:37], b1[1:0], i_b[34:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[54:35], q1[1:0], i_a[32:0]} : {i_b[54:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[54:35], b1[1:0], i_b[32:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[54:33], q1[1:0], i_a[30:0]} : {i_b[54:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[54:33], b1[1:0], i_b[30:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[54:31], q1[1:0], i_a[28:0]} : {i_b[54:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[54:31], b1[1:0], i_b[28:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[54:29], q1[1:0], i_a[26:0]} : {i_b[54:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[54:29], b1[1:0], i_b[26:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[54:27], q1[1:0], i_a[24:0]} : {i_b[54:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[54:27], b1[1:0], i_b[24:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[54:25], q1[1:0], i_a[22:0]} : {i_b[54:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[54:25], b1[1:0], i_b[22:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[54:23], q1[1:0], i_a[20:0]} : {i_b[54:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[54:23], b1[1:0], i_b[20:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[54:21], q1[1:0], i_a[18:0]} : {i_b[54:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[54:21], b1[1:0], i_b[18:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[54:19], q1[1:0], i_a[16:0]} : {i_b[54:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[54:19], b1[1:0], i_b[16:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[54:17], q1[1:0], i_a[14:0]} : {i_b[54:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[54:17], b1[1:0], i_b[14:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[54:15], q1[1:0], i_a[12:0]} : {i_b[54:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[54:15], b1[1:0], i_b[12:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[54:13], q1[1:0], i_a[10:0]} : {i_b[54:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[54:13], b1[1:0], i_b[10:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[54:11], q1[1:0], i_a[8:0]} : {i_b[54:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[54:11], b1[1:0], i_b[8:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[54:9], q1[1:0], i_a[6:0]} : {i_b[54:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[54:9], b1[1:0], i_b[6:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[54:7], q1[1:0], i_a[4:0]} : {i_b[54:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[54:7], b1[1:0], i_b[4:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[54:5], q1[1:0], i_a[2:0]} : {i_b[54:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[54:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[54:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd50:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[55:54], q1[1:0], i_a[51:0]} : {i_b[55:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[55:54], b1[1:0], i_b[51:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[55:52], q1[1:0], i_a[49:0]} : {i_b[55:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[55:52], b1[1:0], i_b[49:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[55:50], q1[1:0], i_a[47:0]} : {i_b[55:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[55:50], b1[1:0], i_b[47:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[55:48], q1[1:0], i_a[45:0]} : {i_b[55:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[55:48], b1[1:0], i_b[45:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[55:46], q1[1:0], i_a[43:0]} : {i_b[55:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[55:46], b1[1:0], i_b[43:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[55:44], q1[1:0], i_a[41:0]} : {i_b[55:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[55:44], b1[1:0], i_b[41:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[55:42], q1[1:0], i_a[39:0]} : {i_b[55:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[55:42], b1[1:0], i_b[39:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[55:40], q1[1:0], i_a[37:0]} : {i_b[55:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[55:40], b1[1:0], i_b[37:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[55:38], q1[1:0], i_a[35:0]} : {i_b[55:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[55:38], b1[1:0], i_b[35:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[55:36], q1[1:0], i_a[33:0]} : {i_b[55:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[55:36], b1[1:0], i_b[33:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[55:34], q1[1:0], i_a[31:0]} : {i_b[55:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[55:34], b1[1:0], i_b[31:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[55:32], q1[1:0], i_a[29:0]} : {i_b[55:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[55:32], b1[1:0], i_b[29:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[55:30], q1[1:0], i_a[27:0]} : {i_b[55:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[55:30], b1[1:0], i_b[27:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[55:28], q1[1:0], i_a[25:0]} : {i_b[55:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[55:28], b1[1:0], i_b[25:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[55:26], q1[1:0], i_a[23:0]} : {i_b[55:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[55:26], b1[1:0], i_b[23:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[55:24], q1[1:0], i_a[21:0]} : {i_b[55:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[55:24], b1[1:0], i_b[21:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[55:22], q1[1:0], i_a[19:0]} : {i_b[55:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[55:22], b1[1:0], i_b[19:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[55:20], q1[1:0], i_a[17:0]} : {i_b[55:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[55:20], b1[1:0], i_b[17:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[55:18], q1[1:0], i_a[15:0]} : {i_b[55:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[55:18], b1[1:0], i_b[15:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[55:16], q1[1:0], i_a[13:0]} : {i_b[55:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[55:16], b1[1:0], i_b[13:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[55:14], q1[1:0], i_a[11:0]} : {i_b[55:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[55:14], b1[1:0], i_b[11:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[55:12], q1[1:0], i_a[9:0]} : {i_b[55:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[55:12], b1[1:0], i_b[9:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[55:10], q1[1:0], i_a[7:0]} : {i_b[55:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[55:10], b1[1:0], i_b[7:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[55:8], q1[1:0], i_a[5:0]} : {i_b[55:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[55:8], b1[1:0], i_b[5:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[55:6], q1[1:0], i_a[3:0]} : {i_b[55:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[55:6], b1[1:0], i_b[3:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[55:4], q1[1:0], i_a[1:0]} : {i_b[55:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[55:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[55:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd51:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[56:55], q1[1:0], i_a[52:0]} : {i_b[56:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[56:55], b1[1:0], i_b[52:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[56:53], q1[1:0], i_a[50:0]} : {i_b[56:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[56:53], b1[1:0], i_b[50:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[56:51], q1[1:0], i_a[48:0]} : {i_b[56:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[56:51], b1[1:0], i_b[48:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[56:49], q1[1:0], i_a[46:0]} : {i_b[56:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[56:49], b1[1:0], i_b[46:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[56:47], q1[1:0], i_a[44:0]} : {i_b[56:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[56:47], b1[1:0], i_b[44:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[56:45], q1[1:0], i_a[42:0]} : {i_b[56:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[56:45], b1[1:0], i_b[42:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[56:43], q1[1:0], i_a[40:0]} : {i_b[56:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[56:43], b1[1:0], i_b[40:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[56:41], q1[1:0], i_a[38:0]} : {i_b[56:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[56:41], b1[1:0], i_b[38:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[56:39], q1[1:0], i_a[36:0]} : {i_b[56:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[56:39], b1[1:0], i_b[36:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[56:37], q1[1:0], i_a[34:0]} : {i_b[56:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[56:37], b1[1:0], i_b[34:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[56:35], q1[1:0], i_a[32:0]} : {i_b[56:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[56:35], b1[1:0], i_b[32:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[56:33], q1[1:0], i_a[30:0]} : {i_b[56:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[56:33], b1[1:0], i_b[30:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[56:31], q1[1:0], i_a[28:0]} : {i_b[56:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[56:31], b1[1:0], i_b[28:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[56:29], q1[1:0], i_a[26:0]} : {i_b[56:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[56:29], b1[1:0], i_b[26:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[56:27], q1[1:0], i_a[24:0]} : {i_b[56:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[56:27], b1[1:0], i_b[24:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[56:25], q1[1:0], i_a[22:0]} : {i_b[56:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[56:25], b1[1:0], i_b[22:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[56:23], q1[1:0], i_a[20:0]} : {i_b[56:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[56:23], b1[1:0], i_b[20:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[56:21], q1[1:0], i_a[18:0]} : {i_b[56:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[56:21], b1[1:0], i_b[18:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[56:19], q1[1:0], i_a[16:0]} : {i_b[56:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[56:19], b1[1:0], i_b[16:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[56:17], q1[1:0], i_a[14:0]} : {i_b[56:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[56:17], b1[1:0], i_b[14:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[56:15], q1[1:0], i_a[12:0]} : {i_b[56:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[56:15], b1[1:0], i_b[12:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[56:13], q1[1:0], i_a[10:0]} : {i_b[56:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[56:13], b1[1:0], i_b[10:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[56:11], q1[1:0], i_a[8:0]} : {i_b[56:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[56:11], b1[1:0], i_b[8:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[56:9], q1[1:0], i_a[6:0]} : {i_b[56:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[56:9], b1[1:0], i_b[6:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[56:7], q1[1:0], i_a[4:0]} : {i_b[56:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[56:7], b1[1:0], i_b[4:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[56:5], q1[1:0], i_a[2:0]} : {i_b[56:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[56:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[56:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd52:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[57:56], q1[1:0], i_a[53:0]} : {i_b[57:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[57:56], b1[1:0], i_b[53:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[57:54], q1[1:0], i_a[51:0]} : {i_b[57:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[57:54], b1[1:0], i_b[51:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[57:52], q1[1:0], i_a[49:0]} : {i_b[57:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[57:52], b1[1:0], i_b[49:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[57:50], q1[1:0], i_a[47:0]} : {i_b[57:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[57:50], b1[1:0], i_b[47:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[57:48], q1[1:0], i_a[45:0]} : {i_b[57:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[57:48], b1[1:0], i_b[45:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[57:46], q1[1:0], i_a[43:0]} : {i_b[57:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[57:46], b1[1:0], i_b[43:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[57:44], q1[1:0], i_a[41:0]} : {i_b[57:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[57:44], b1[1:0], i_b[41:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[57:42], q1[1:0], i_a[39:0]} : {i_b[57:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[57:42], b1[1:0], i_b[39:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[57:40], q1[1:0], i_a[37:0]} : {i_b[57:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[57:40], b1[1:0], i_b[37:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[57:38], q1[1:0], i_a[35:0]} : {i_b[57:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[57:38], b1[1:0], i_b[35:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[57:36], q1[1:0], i_a[33:0]} : {i_b[57:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[57:36], b1[1:0], i_b[33:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[57:34], q1[1:0], i_a[31:0]} : {i_b[57:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[57:34], b1[1:0], i_b[31:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[57:32], q1[1:0], i_a[29:0]} : {i_b[57:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[57:32], b1[1:0], i_b[29:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[57:30], q1[1:0], i_a[27:0]} : {i_b[57:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[57:30], b1[1:0], i_b[27:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[57:28], q1[1:0], i_a[25:0]} : {i_b[57:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[57:28], b1[1:0], i_b[25:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[57:26], q1[1:0], i_a[23:0]} : {i_b[57:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[57:26], b1[1:0], i_b[23:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[57:24], q1[1:0], i_a[21:0]} : {i_b[57:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[57:24], b1[1:0], i_b[21:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[57:22], q1[1:0], i_a[19:0]} : {i_b[57:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[57:22], b1[1:0], i_b[19:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[57:20], q1[1:0], i_a[17:0]} : {i_b[57:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[57:20], b1[1:0], i_b[17:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[57:18], q1[1:0], i_a[15:0]} : {i_b[57:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[57:18], b1[1:0], i_b[15:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[57:16], q1[1:0], i_a[13:0]} : {i_b[57:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[57:16], b1[1:0], i_b[13:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[57:14], q1[1:0], i_a[11:0]} : {i_b[57:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[57:14], b1[1:0], i_b[11:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[57:12], q1[1:0], i_a[9:0]} : {i_b[57:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[57:12], b1[1:0], i_b[9:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[57:10], q1[1:0], i_a[7:0]} : {i_b[57:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[57:10], b1[1:0], i_b[7:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[57:8], q1[1:0], i_a[5:0]} : {i_b[57:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[57:8], b1[1:0], i_b[5:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[57:6], q1[1:0], i_a[3:0]} : {i_b[57:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[57:6], b1[1:0], i_b[3:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[57:4], q1[1:0], i_a[1:0]} : {i_b[57:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[57:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[57:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd53:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[58:57], q1[1:0], i_a[54:0]} : {i_b[58:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[58:57], b1[1:0], i_b[54:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[58:55], q1[1:0], i_a[52:0]} : {i_b[58:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[58:55], b1[1:0], i_b[52:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[58:53], q1[1:0], i_a[50:0]} : {i_b[58:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[58:53], b1[1:0], i_b[50:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[58:51], q1[1:0], i_a[48:0]} : {i_b[58:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[58:51], b1[1:0], i_b[48:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[58:49], q1[1:0], i_a[46:0]} : {i_b[58:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[58:49], b1[1:0], i_b[46:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[58:47], q1[1:0], i_a[44:0]} : {i_b[58:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[58:47], b1[1:0], i_b[44:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[58:45], q1[1:0], i_a[42:0]} : {i_b[58:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[58:45], b1[1:0], i_b[42:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[58:43], q1[1:0], i_a[40:0]} : {i_b[58:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[58:43], b1[1:0], i_b[40:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[58:41], q1[1:0], i_a[38:0]} : {i_b[58:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[58:41], b1[1:0], i_b[38:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[58:39], q1[1:0], i_a[36:0]} : {i_b[58:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[58:39], b1[1:0], i_b[36:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[58:37], q1[1:0], i_a[34:0]} : {i_b[58:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[58:37], b1[1:0], i_b[34:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[58:35], q1[1:0], i_a[32:0]} : {i_b[58:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[58:35], b1[1:0], i_b[32:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[58:33], q1[1:0], i_a[30:0]} : {i_b[58:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[58:33], b1[1:0], i_b[30:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[58:31], q1[1:0], i_a[28:0]} : {i_b[58:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[58:31], b1[1:0], i_b[28:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[58:29], q1[1:0], i_a[26:0]} : {i_b[58:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[58:29], b1[1:0], i_b[26:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[58:27], q1[1:0], i_a[24:0]} : {i_b[58:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[58:27], b1[1:0], i_b[24:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[58:25], q1[1:0], i_a[22:0]} : {i_b[58:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[58:25], b1[1:0], i_b[22:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[58:23], q1[1:0], i_a[20:0]} : {i_b[58:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[58:23], b1[1:0], i_b[20:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[58:21], q1[1:0], i_a[18:0]} : {i_b[58:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[58:21], b1[1:0], i_b[18:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[58:19], q1[1:0], i_a[16:0]} : {i_b[58:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[58:19], b1[1:0], i_b[16:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[58:17], q1[1:0], i_a[14:0]} : {i_b[58:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[58:17], b1[1:0], i_b[14:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[58:15], q1[1:0], i_a[12:0]} : {i_b[58:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[58:15], b1[1:0], i_b[12:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[58:13], q1[1:0], i_a[10:0]} : {i_b[58:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[58:13], b1[1:0], i_b[10:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[58:11], q1[1:0], i_a[8:0]} : {i_b[58:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[58:11], b1[1:0], i_b[8:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[58:9], q1[1:0], i_a[6:0]} : {i_b[58:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[58:9], b1[1:0], i_b[6:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[58:7], q1[1:0], i_a[4:0]} : {i_b[58:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[58:7], b1[1:0], i_b[4:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[58:5], q1[1:0], i_a[2:0]} : {i_b[58:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[58:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[58:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd54:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[59:58], q1[1:0], i_a[55:0]} : {i_b[59:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[59:58], b1[1:0], i_b[55:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[59:56], q1[1:0], i_a[53:0]} : {i_b[59:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[59:56], b1[1:0], i_b[53:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[59:54], q1[1:0], i_a[51:0]} : {i_b[59:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[59:54], b1[1:0], i_b[51:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[59:52], q1[1:0], i_a[49:0]} : {i_b[59:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[59:52], b1[1:0], i_b[49:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[59:50], q1[1:0], i_a[47:0]} : {i_b[59:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[59:50], b1[1:0], i_b[47:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[59:48], q1[1:0], i_a[45:0]} : {i_b[59:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[59:48], b1[1:0], i_b[45:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[59:46], q1[1:0], i_a[43:0]} : {i_b[59:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[59:46], b1[1:0], i_b[43:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[59:44], q1[1:0], i_a[41:0]} : {i_b[59:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[59:44], b1[1:0], i_b[41:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[59:42], q1[1:0], i_a[39:0]} : {i_b[59:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[59:42], b1[1:0], i_b[39:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[59:40], q1[1:0], i_a[37:0]} : {i_b[59:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[59:40], b1[1:0], i_b[37:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[59:38], q1[1:0], i_a[35:0]} : {i_b[59:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[59:38], b1[1:0], i_b[35:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[59:36], q1[1:0], i_a[33:0]} : {i_b[59:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[59:36], b1[1:0], i_b[33:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[59:34], q1[1:0], i_a[31:0]} : {i_b[59:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[59:34], b1[1:0], i_b[31:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[59:32], q1[1:0], i_a[29:0]} : {i_b[59:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[59:32], b1[1:0], i_b[29:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[59:30], q1[1:0], i_a[27:0]} : {i_b[59:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[59:30], b1[1:0], i_b[27:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[59:28], q1[1:0], i_a[25:0]} : {i_b[59:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[59:28], b1[1:0], i_b[25:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[59:26], q1[1:0], i_a[23:0]} : {i_b[59:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[59:26], b1[1:0], i_b[23:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[59:24], q1[1:0], i_a[21:0]} : {i_b[59:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[59:24], b1[1:0], i_b[21:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[59:22], q1[1:0], i_a[19:0]} : {i_b[59:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[59:22], b1[1:0], i_b[19:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[59:20], q1[1:0], i_a[17:0]} : {i_b[59:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[59:20], b1[1:0], i_b[17:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[59:18], q1[1:0], i_a[15:0]} : {i_b[59:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[59:18], b1[1:0], i_b[15:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[59:16], q1[1:0], i_a[13:0]} : {i_b[59:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[59:16], b1[1:0], i_b[13:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[59:14], q1[1:0], i_a[11:0]} : {i_b[59:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[59:14], b1[1:0], i_b[11:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[59:12], q1[1:0], i_a[9:0]} : {i_b[59:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[59:12], b1[1:0], i_b[9:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[59:10], q1[1:0], i_a[7:0]} : {i_b[59:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[59:10], b1[1:0], i_b[7:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[59:8], q1[1:0], i_a[5:0]} : {i_b[59:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[59:8], b1[1:0], i_b[5:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[59:6], q1[1:0], i_a[3:0]} : {i_b[59:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[59:6], b1[1:0], i_b[3:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[59:4], q1[1:0], i_a[1:0]} : {i_b[59:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[59:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[59:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd55:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[60:59], q1[1:0], i_a[56:0]} : {i_b[60:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[60:59], b1[1:0], i_b[56:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[60:57], q1[1:0], i_a[54:0]} : {i_b[60:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[60:57], b1[1:0], i_b[54:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[60:55], q1[1:0], i_a[52:0]} : {i_b[60:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[60:55], b1[1:0], i_b[52:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[60:53], q1[1:0], i_a[50:0]} : {i_b[60:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[60:53], b1[1:0], i_b[50:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[60:51], q1[1:0], i_a[48:0]} : {i_b[60:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[60:51], b1[1:0], i_b[48:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[60:49], q1[1:0], i_a[46:0]} : {i_b[60:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[60:49], b1[1:0], i_b[46:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[60:47], q1[1:0], i_a[44:0]} : {i_b[60:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[60:47], b1[1:0], i_b[44:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[60:45], q1[1:0], i_a[42:0]} : {i_b[60:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[60:45], b1[1:0], i_b[42:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[60:43], q1[1:0], i_a[40:0]} : {i_b[60:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[60:43], b1[1:0], i_b[40:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[60:41], q1[1:0], i_a[38:0]} : {i_b[60:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[60:41], b1[1:0], i_b[38:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[60:39], q1[1:0], i_a[36:0]} : {i_b[60:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[60:39], b1[1:0], i_b[36:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[60:37], q1[1:0], i_a[34:0]} : {i_b[60:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[60:37], b1[1:0], i_b[34:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[60:35], q1[1:0], i_a[32:0]} : {i_b[60:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[60:35], b1[1:0], i_b[32:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[60:33], q1[1:0], i_a[30:0]} : {i_b[60:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[60:33], b1[1:0], i_b[30:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[60:31], q1[1:0], i_a[28:0]} : {i_b[60:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[60:31], b1[1:0], i_b[28:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[60:29], q1[1:0], i_a[26:0]} : {i_b[60:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[60:29], b1[1:0], i_b[26:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[60:27], q1[1:0], i_a[24:0]} : {i_b[60:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[60:27], b1[1:0], i_b[24:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[60:25], q1[1:0], i_a[22:0]} : {i_b[60:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[60:25], b1[1:0], i_b[22:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[60:23], q1[1:0], i_a[20:0]} : {i_b[60:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[60:23], b1[1:0], i_b[20:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[60:21], q1[1:0], i_a[18:0]} : {i_b[60:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[60:21], b1[1:0], i_b[18:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[60:19], q1[1:0], i_a[16:0]} : {i_b[60:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[60:19], b1[1:0], i_b[16:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[60:17], q1[1:0], i_a[14:0]} : {i_b[60:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[60:17], b1[1:0], i_b[14:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[60:15], q1[1:0], i_a[12:0]} : {i_b[60:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[60:15], b1[1:0], i_b[12:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[60:13], q1[1:0], i_a[10:0]} : {i_b[60:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[60:13], b1[1:0], i_b[10:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[60:11], q1[1:0], i_a[8:0]} : {i_b[60:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[60:11], b1[1:0], i_b[8:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[60:9], q1[1:0], i_a[6:0]} : {i_b[60:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[60:9], b1[1:0], i_b[6:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[60:7], q1[1:0], i_a[4:0]} : {i_b[60:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[60:7], b1[1:0], i_b[4:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[60:5], q1[1:0], i_a[2:0]} : {i_b[60:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[60:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[60:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd56:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[61:60], q1[1:0], i_a[57:0]} : {i_b[61:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[61:60], b1[1:0], i_b[57:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[61:58], q1[1:0], i_a[55:0]} : {i_b[61:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[61:58], b1[1:0], i_b[55:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[61:56], q1[1:0], i_a[53:0]} : {i_b[61:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[61:56], b1[1:0], i_b[53:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[61:54], q1[1:0], i_a[51:0]} : {i_b[61:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[61:54], b1[1:0], i_b[51:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[61:52], q1[1:0], i_a[49:0]} : {i_b[61:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[61:52], b1[1:0], i_b[49:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[61:50], q1[1:0], i_a[47:0]} : {i_b[61:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[61:50], b1[1:0], i_b[47:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[61:48], q1[1:0], i_a[45:0]} : {i_b[61:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[61:48], b1[1:0], i_b[45:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[61:46], q1[1:0], i_a[43:0]} : {i_b[61:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[61:46], b1[1:0], i_b[43:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[61:44], q1[1:0], i_a[41:0]} : {i_b[61:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[61:44], b1[1:0], i_b[41:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[61:42], q1[1:0], i_a[39:0]} : {i_b[61:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[61:42], b1[1:0], i_b[39:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[61:40], q1[1:0], i_a[37:0]} : {i_b[61:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[61:40], b1[1:0], i_b[37:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[61:38], q1[1:0], i_a[35:0]} : {i_b[61:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[61:38], b1[1:0], i_b[35:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[61:36], q1[1:0], i_a[33:0]} : {i_b[61:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[61:36], b1[1:0], i_b[33:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[61:34], q1[1:0], i_a[31:0]} : {i_b[61:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[61:34], b1[1:0], i_b[31:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[61:32], q1[1:0], i_a[29:0]} : {i_b[61:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[61:32], b1[1:0], i_b[29:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[61:30], q1[1:0], i_a[27:0]} : {i_b[61:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[61:30], b1[1:0], i_b[27:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[61:28], q1[1:0], i_a[25:0]} : {i_b[61:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[61:28], b1[1:0], i_b[25:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[61:26], q1[1:0], i_a[23:0]} : {i_b[61:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[61:26], b1[1:0], i_b[23:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[61:24], q1[1:0], i_a[21:0]} : {i_b[61:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[61:24], b1[1:0], i_b[21:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[61:22], q1[1:0], i_a[19:0]} : {i_b[61:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[61:22], b1[1:0], i_b[19:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[61:20], q1[1:0], i_a[17:0]} : {i_b[61:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[61:20], b1[1:0], i_b[17:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[61:18], q1[1:0], i_a[15:0]} : {i_b[61:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[61:18], b1[1:0], i_b[15:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[61:16], q1[1:0], i_a[13:0]} : {i_b[61:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[61:16], b1[1:0], i_b[13:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[61:14], q1[1:0], i_a[11:0]} : {i_b[61:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[61:14], b1[1:0], i_b[11:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[61:12], q1[1:0], i_a[9:0]} : {i_b[61:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[61:12], b1[1:0], i_b[9:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[61:10], q1[1:0], i_a[7:0]} : {i_b[61:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[61:10], b1[1:0], i_b[7:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[61:8], q1[1:0], i_a[5:0]} : {i_b[61:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[61:8], b1[1:0], i_b[5:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[61:6], q1[1:0], i_a[3:0]} : {i_b[61:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[61:6], b1[1:0], i_b[3:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[61:4], q1[1:0], i_a[1:0]} : {i_b[61:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[61:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[61:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd57:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[62:61], q1[1:0], i_a[58:0]} : {i_b[62:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[62:61], b1[1:0], i_b[58:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[62:59], q1[1:0], i_a[56:0]} : {i_b[62:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[62:59], b1[1:0], i_b[56:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[62:57], q1[1:0], i_a[54:0]} : {i_b[62:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[62:57], b1[1:0], i_b[54:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[62:55], q1[1:0], i_a[52:0]} : {i_b[62:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[62:55], b1[1:0], i_b[52:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[62:53], q1[1:0], i_a[50:0]} : {i_b[62:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[62:53], b1[1:0], i_b[50:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[62:51], q1[1:0], i_a[48:0]} : {i_b[62:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[62:51], b1[1:0], i_b[48:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[62:49], q1[1:0], i_a[46:0]} : {i_b[62:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[62:49], b1[1:0], i_b[46:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[62:47], q1[1:0], i_a[44:0]} : {i_b[62:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[62:47], b1[1:0], i_b[44:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[62:45], q1[1:0], i_a[42:0]} : {i_b[62:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[62:45], b1[1:0], i_b[42:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[62:43], q1[1:0], i_a[40:0]} : {i_b[62:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[62:43], b1[1:0], i_b[40:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[62:41], q1[1:0], i_a[38:0]} : {i_b[62:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[62:41], b1[1:0], i_b[38:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[62:39], q1[1:0], i_a[36:0]} : {i_b[62:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[62:39], b1[1:0], i_b[36:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[62:37], q1[1:0], i_a[34:0]} : {i_b[62:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[62:37], b1[1:0], i_b[34:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[62:35], q1[1:0], i_a[32:0]} : {i_b[62:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[62:35], b1[1:0], i_b[32:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[62:33], q1[1:0], i_a[30:0]} : {i_b[62:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[62:33], b1[1:0], i_b[30:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[62:31], q1[1:0], i_a[28:0]} : {i_b[62:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[62:31], b1[1:0], i_b[28:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[62:29], q1[1:0], i_a[26:0]} : {i_b[62:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[62:29], b1[1:0], i_b[26:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[62:27], q1[1:0], i_a[24:0]} : {i_b[62:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[62:27], b1[1:0], i_b[24:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[62:25], q1[1:0], i_a[22:0]} : {i_b[62:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[62:25], b1[1:0], i_b[22:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[62:23], q1[1:0], i_a[20:0]} : {i_b[62:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[62:23], b1[1:0], i_b[20:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[62:21], q1[1:0], i_a[18:0]} : {i_b[62:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[62:21], b1[1:0], i_b[18:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[62:19], q1[1:0], i_a[16:0]} : {i_b[62:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[62:19], b1[1:0], i_b[16:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[62:17], q1[1:0], i_a[14:0]} : {i_b[62:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[62:17], b1[1:0], i_b[14:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[62:15], q1[1:0], i_a[12:0]} : {i_b[62:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[62:15], b1[1:0], i_b[12:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[62:13], q1[1:0], i_a[10:0]} : {i_b[62:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[62:13], b1[1:0], i_b[10:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[62:11], q1[1:0], i_a[8:0]} : {i_b[62:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[62:11], b1[1:0], i_b[8:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[62:9], q1[1:0], i_a[6:0]} : {i_b[62:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[62:9], b1[1:0], i_b[6:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[62:7], q1[1:0], i_a[4:0]} : {i_b[62:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[62:7], b1[1:0], i_b[4:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[62:5], q1[1:0], i_a[2:0]} : {i_b[62:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[62:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[62:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd58:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[63:62], q1[1:0], i_a[59:0]} : {i_b[63:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[63:62], b1[1:0], i_b[59:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[63:60], q1[1:0], i_a[57:0]} : {i_b[63:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[63:60], b1[1:0], i_b[57:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[63:58], q1[1:0], i_a[55:0]} : {i_b[63:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[63:58], b1[1:0], i_b[55:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[63:56], q1[1:0], i_a[53:0]} : {i_b[63:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[63:56], b1[1:0], i_b[53:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[63:54], q1[1:0], i_a[51:0]} : {i_b[63:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[63:54], b1[1:0], i_b[51:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[63:52], q1[1:0], i_a[49:0]} : {i_b[63:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[63:52], b1[1:0], i_b[49:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[63:50], q1[1:0], i_a[47:0]} : {i_b[63:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[63:50], b1[1:0], i_b[47:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[63:48], q1[1:0], i_a[45:0]} : {i_b[63:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[63:48], b1[1:0], i_b[45:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[63:46], q1[1:0], i_a[43:0]} : {i_b[63:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[63:46], b1[1:0], i_b[43:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[63:44], q1[1:0], i_a[41:0]} : {i_b[63:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[63:44], b1[1:0], i_b[41:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[63:42], q1[1:0], i_a[39:0]} : {i_b[63:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[63:42], b1[1:0], i_b[39:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[63:40], q1[1:0], i_a[37:0]} : {i_b[63:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[63:40], b1[1:0], i_b[37:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[63:38], q1[1:0], i_a[35:0]} : {i_b[63:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[63:38], b1[1:0], i_b[35:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[63:36], q1[1:0], i_a[33:0]} : {i_b[63:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[63:36], b1[1:0], i_b[33:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[63:34], q1[1:0], i_a[31:0]} : {i_b[63:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[63:34], b1[1:0], i_b[31:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[63:32], q1[1:0], i_a[29:0]} : {i_b[63:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[63:32], b1[1:0], i_b[29:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[63:30], q1[1:0], i_a[27:0]} : {i_b[63:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[63:30], b1[1:0], i_b[27:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[63:28], q1[1:0], i_a[25:0]} : {i_b[63:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[63:28], b1[1:0], i_b[25:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[63:26], q1[1:0], i_a[23:0]} : {i_b[63:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[63:26], b1[1:0], i_b[23:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[63:24], q1[1:0], i_a[21:0]} : {i_b[63:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[63:24], b1[1:0], i_b[21:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[63:22], q1[1:0], i_a[19:0]} : {i_b[63:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[63:22], b1[1:0], i_b[19:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[63:20], q1[1:0], i_a[17:0]} : {i_b[63:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[63:20], b1[1:0], i_b[17:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[63:18], q1[1:0], i_a[15:0]} : {i_b[63:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[63:18], b1[1:0], i_b[15:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[63:16], q1[1:0], i_a[13:0]} : {i_b[63:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[63:16], b1[1:0], i_b[13:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[63:14], q1[1:0], i_a[11:0]} : {i_b[63:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[63:14], b1[1:0], i_b[11:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[63:12], q1[1:0], i_a[9:0]} : {i_b[63:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[63:12], b1[1:0], i_b[9:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[63:10], q1[1:0], i_a[7:0]} : {i_b[63:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[63:10], b1[1:0], i_b[7:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[63:8], q1[1:0], i_a[5:0]} : {i_b[63:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[63:8], b1[1:0], i_b[5:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[63:6], q1[1:0], i_a[3:0]} : {i_b[63:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[63:6], b1[1:0], i_b[3:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[63:4], q1[1:0], i_a[1:0]} : {i_b[63:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[63:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[63:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd59:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[64:63], q1[1:0], i_a[60:0]} : {i_b[64:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[64:63], b1[1:0], i_b[60:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[64:61], q1[1:0], i_a[58:0]} : {i_b[64:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[64:61], b1[1:0], i_b[58:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[64:59], q1[1:0], i_a[56:0]} : {i_b[64:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[64:59], b1[1:0], i_b[56:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[64:57], q1[1:0], i_a[54:0]} : {i_b[64:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[64:57], b1[1:0], i_b[54:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[64:55], q1[1:0], i_a[52:0]} : {i_b[64:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[64:55], b1[1:0], i_b[52:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[64:53], q1[1:0], i_a[50:0]} : {i_b[64:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[64:53], b1[1:0], i_b[50:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[64:51], q1[1:0], i_a[48:0]} : {i_b[64:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[64:51], b1[1:0], i_b[48:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[64:49], q1[1:0], i_a[46:0]} : {i_b[64:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[64:49], b1[1:0], i_b[46:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[64:47], q1[1:0], i_a[44:0]} : {i_b[64:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[64:47], b1[1:0], i_b[44:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[64:45], q1[1:0], i_a[42:0]} : {i_b[64:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[64:45], b1[1:0], i_b[42:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[64:43], q1[1:0], i_a[40:0]} : {i_b[64:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[64:43], b1[1:0], i_b[40:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[64:41], q1[1:0], i_a[38:0]} : {i_b[64:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[64:41], b1[1:0], i_b[38:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[64:39], q1[1:0], i_a[36:0]} : {i_b[64:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[64:39], b1[1:0], i_b[36:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[64:37], q1[1:0], i_a[34:0]} : {i_b[64:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[64:37], b1[1:0], i_b[34:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[64:35], q1[1:0], i_a[32:0]} : {i_b[64:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[64:35], b1[1:0], i_b[32:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[64:33], q1[1:0], i_a[30:0]} : {i_b[64:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[64:33], b1[1:0], i_b[30:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[64:31], q1[1:0], i_a[28:0]} : {i_b[64:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[64:31], b1[1:0], i_b[28:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[64:29], q1[1:0], i_a[26:0]} : {i_b[64:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[64:29], b1[1:0], i_b[26:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[64:27], q1[1:0], i_a[24:0]} : {i_b[64:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[64:27], b1[1:0], i_b[24:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[64:25], q1[1:0], i_a[22:0]} : {i_b[64:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[64:25], b1[1:0], i_b[22:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[64:23], q1[1:0], i_a[20:0]} : {i_b[64:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[64:23], b1[1:0], i_b[20:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[64:21], q1[1:0], i_a[18:0]} : {i_b[64:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[64:21], b1[1:0], i_b[18:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[64:19], q1[1:0], i_a[16:0]} : {i_b[64:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[64:19], b1[1:0], i_b[16:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[64:17], q1[1:0], i_a[14:0]} : {i_b[64:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[64:17], b1[1:0], i_b[14:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[64:15], q1[1:0], i_a[12:0]} : {i_b[64:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[64:15], b1[1:0], i_b[12:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[64:13], q1[1:0], i_a[10:0]} : {i_b[64:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[64:13], b1[1:0], i_b[10:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[64:11], q1[1:0], i_a[8:0]} : {i_b[64:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[64:11], b1[1:0], i_b[8:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[64:9], q1[1:0], i_a[6:0]} : {i_b[64:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[64:9], b1[1:0], i_b[6:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[64:7], q1[1:0], i_a[4:0]} : {i_b[64:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[64:7], b1[1:0], i_b[4:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[64:5], q1[1:0], i_a[2:0]} : {i_b[64:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[64:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[64:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd60:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[65:64], q1[1:0], i_a[61:0]} : {i_b[65:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[65:64], b1[1:0], i_b[61:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[65:62], q1[1:0], i_a[59:0]} : {i_b[65:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[65:62], b1[1:0], i_b[59:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[65:60], q1[1:0], i_a[57:0]} : {i_b[65:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[65:60], b1[1:0], i_b[57:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[65:58], q1[1:0], i_a[55:0]} : {i_b[65:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[65:58], b1[1:0], i_b[55:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[65:56], q1[1:0], i_a[53:0]} : {i_b[65:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[65:56], b1[1:0], i_b[53:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[65:54], q1[1:0], i_a[51:0]} : {i_b[65:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[65:54], b1[1:0], i_b[51:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[65:52], q1[1:0], i_a[49:0]} : {i_b[65:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[65:52], b1[1:0], i_b[49:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[65:50], q1[1:0], i_a[47:0]} : {i_b[65:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[65:50], b1[1:0], i_b[47:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[65:48], q1[1:0], i_a[45:0]} : {i_b[65:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[65:48], b1[1:0], i_b[45:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[65:46], q1[1:0], i_a[43:0]} : {i_b[65:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[65:46], b1[1:0], i_b[43:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[65:44], q1[1:0], i_a[41:0]} : {i_b[65:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[65:44], b1[1:0], i_b[41:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[65:42], q1[1:0], i_a[39:0]} : {i_b[65:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[65:42], b1[1:0], i_b[39:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[65:40], q1[1:0], i_a[37:0]} : {i_b[65:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[65:40], b1[1:0], i_b[37:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[65:38], q1[1:0], i_a[35:0]} : {i_b[65:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[65:38], b1[1:0], i_b[35:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[65:36], q1[1:0], i_a[33:0]} : {i_b[65:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[65:36], b1[1:0], i_b[33:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[65:34], q1[1:0], i_a[31:0]} : {i_b[65:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[65:34], b1[1:0], i_b[31:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[65:32], q1[1:0], i_a[29:0]} : {i_b[65:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[65:32], b1[1:0], i_b[29:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[65:30], q1[1:0], i_a[27:0]} : {i_b[65:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[65:30], b1[1:0], i_b[27:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[65:28], q1[1:0], i_a[25:0]} : {i_b[65:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[65:28], b1[1:0], i_b[25:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[65:26], q1[1:0], i_a[23:0]} : {i_b[65:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[65:26], b1[1:0], i_b[23:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[65:24], q1[1:0], i_a[21:0]} : {i_b[65:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[65:24], b1[1:0], i_b[21:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[65:22], q1[1:0], i_a[19:0]} : {i_b[65:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[65:22], b1[1:0], i_b[19:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[65:20], q1[1:0], i_a[17:0]} : {i_b[65:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[65:20], b1[1:0], i_b[17:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[65:18], q1[1:0], i_a[15:0]} : {i_b[65:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[65:18], b1[1:0], i_b[15:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[65:16], q1[1:0], i_a[13:0]} : {i_b[65:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[65:16], b1[1:0], i_b[13:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[65:14], q1[1:0], i_a[11:0]} : {i_b[65:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[65:14], b1[1:0], i_b[11:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[65:12], q1[1:0], i_a[9:0]} : {i_b[65:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[65:12], b1[1:0], i_b[9:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[65:10], q1[1:0], i_a[7:0]} : {i_b[65:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[65:10], b1[1:0], i_b[7:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[65:8], q1[1:0], i_a[5:0]} : {i_b[65:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[65:8], b1[1:0], i_b[5:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[65:6], q1[1:0], i_a[3:0]} : {i_b[65:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[65:6], b1[1:0], i_b[3:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[65:4], q1[1:0], i_a[1:0]} : {i_b[65:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[65:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[65:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd61:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[66:65], q1[1:0], i_a[62:0]} : {i_b[66:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[66:65], b1[1:0], i_b[62:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[66:63], q1[1:0], i_a[60:0]} : {i_b[66:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[66:63], b1[1:0], i_b[60:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[66:61], q1[1:0], i_a[58:0]} : {i_b[66:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[66:61], b1[1:0], i_b[58:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[66:59], q1[1:0], i_a[56:0]} : {i_b[66:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[66:59], b1[1:0], i_b[56:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[66:57], q1[1:0], i_a[54:0]} : {i_b[66:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[66:57], b1[1:0], i_b[54:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[66:55], q1[1:0], i_a[52:0]} : {i_b[66:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[66:55], b1[1:0], i_b[52:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[66:53], q1[1:0], i_a[50:0]} : {i_b[66:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[66:53], b1[1:0], i_b[50:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[66:51], q1[1:0], i_a[48:0]} : {i_b[66:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[66:51], b1[1:0], i_b[48:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[66:49], q1[1:0], i_a[46:0]} : {i_b[66:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[66:49], b1[1:0], i_b[46:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[66:47], q1[1:0], i_a[44:0]} : {i_b[66:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[66:47], b1[1:0], i_b[44:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[66:45], q1[1:0], i_a[42:0]} : {i_b[66:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[66:45], b1[1:0], i_b[42:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[66:43], q1[1:0], i_a[40:0]} : {i_b[66:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[66:43], b1[1:0], i_b[40:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[66:41], q1[1:0], i_a[38:0]} : {i_b[66:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[66:41], b1[1:0], i_b[38:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[66:39], q1[1:0], i_a[36:0]} : {i_b[66:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[66:39], b1[1:0], i_b[36:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[66:37], q1[1:0], i_a[34:0]} : {i_b[66:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[66:37], b1[1:0], i_b[34:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[66:35], q1[1:0], i_a[32:0]} : {i_b[66:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[66:35], b1[1:0], i_b[32:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[66:33], q1[1:0], i_a[30:0]} : {i_b[66:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[66:33], b1[1:0], i_b[30:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[66:31], q1[1:0], i_a[28:0]} : {i_b[66:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[66:31], b1[1:0], i_b[28:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[66:29], q1[1:0], i_a[26:0]} : {i_b[66:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[66:29], b1[1:0], i_b[26:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[66:27], q1[1:0], i_a[24:0]} : {i_b[66:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[66:27], b1[1:0], i_b[24:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[66:25], q1[1:0], i_a[22:0]} : {i_b[66:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[66:25], b1[1:0], i_b[22:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[66:23], q1[1:0], i_a[20:0]} : {i_b[66:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[66:23], b1[1:0], i_b[20:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[66:21], q1[1:0], i_a[18:0]} : {i_b[66:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[66:21], b1[1:0], i_b[18:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[66:19], q1[1:0], i_a[16:0]} : {i_b[66:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[66:19], b1[1:0], i_b[16:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[66:17], q1[1:0], i_a[14:0]} : {i_b[66:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[66:17], b1[1:0], i_b[14:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[66:15], q1[1:0], i_a[12:0]} : {i_b[66:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[66:15], b1[1:0], i_b[12:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[66:13], q1[1:0], i_a[10:0]} : {i_b[66:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[66:13], b1[1:0], i_b[10:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[66:11], q1[1:0], i_a[8:0]} : {i_b[66:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[66:11], b1[1:0], i_b[8:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[66:9], q1[1:0], i_a[6:0]} : {i_b[66:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[66:9], b1[1:0], i_b[6:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[66:7], q1[1:0], i_a[4:0]} : {i_b[66:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[66:7], b1[1:0], i_b[4:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[66:5], q1[1:0], i_a[2:0]} : {i_b[66:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[66:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[66:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd62:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[67:66], q1[1:0], i_a[63:0]} : {i_b[67:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[67:66], b1[1:0], i_b[63:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[67:64], q1[1:0], i_a[61:0]} : {i_b[67:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[67:64], b1[1:0], i_b[61:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[67:62], q1[1:0], i_a[59:0]} : {i_b[67:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[67:62], b1[1:0], i_b[59:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[67:60], q1[1:0], i_a[57:0]} : {i_b[67:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[67:60], b1[1:0], i_b[57:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[67:58], q1[1:0], i_a[55:0]} : {i_b[67:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[67:58], b1[1:0], i_b[55:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[67:56], q1[1:0], i_a[53:0]} : {i_b[67:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[67:56], b1[1:0], i_b[53:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[67:54], q1[1:0], i_a[51:0]} : {i_b[67:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[67:54], b1[1:0], i_b[51:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[67:52], q1[1:0], i_a[49:0]} : {i_b[67:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[67:52], b1[1:0], i_b[49:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[67:50], q1[1:0], i_a[47:0]} : {i_b[67:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[67:50], b1[1:0], i_b[47:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[67:48], q1[1:0], i_a[45:0]} : {i_b[67:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[67:48], b1[1:0], i_b[45:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[67:46], q1[1:0], i_a[43:0]} : {i_b[67:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[67:46], b1[1:0], i_b[43:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[67:44], q1[1:0], i_a[41:0]} : {i_b[67:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[67:44], b1[1:0], i_b[41:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[67:42], q1[1:0], i_a[39:0]} : {i_b[67:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[67:42], b1[1:0], i_b[39:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[67:40], q1[1:0], i_a[37:0]} : {i_b[67:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[67:40], b1[1:0], i_b[37:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[67:38], q1[1:0], i_a[35:0]} : {i_b[67:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[67:38], b1[1:0], i_b[35:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[67:36], q1[1:0], i_a[33:0]} : {i_b[67:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[67:36], b1[1:0], i_b[33:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[67:34], q1[1:0], i_a[31:0]} : {i_b[67:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[67:34], b1[1:0], i_b[31:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[67:32], q1[1:0], i_a[29:0]} : {i_b[67:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[67:32], b1[1:0], i_b[29:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[67:30], q1[1:0], i_a[27:0]} : {i_b[67:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[67:30], b1[1:0], i_b[27:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[67:28], q1[1:0], i_a[25:0]} : {i_b[67:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[67:28], b1[1:0], i_b[25:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[67:26], q1[1:0], i_a[23:0]} : {i_b[67:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[67:26], b1[1:0], i_b[23:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[67:24], q1[1:0], i_a[21:0]} : {i_b[67:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[67:24], b1[1:0], i_b[21:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[67:22], q1[1:0], i_a[19:0]} : {i_b[67:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[67:22], b1[1:0], i_b[19:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[67:20], q1[1:0], i_a[17:0]} : {i_b[67:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[67:20], b1[1:0], i_b[17:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[67:18], q1[1:0], i_a[15:0]} : {i_b[67:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[67:18], b1[1:0], i_b[15:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[67:16], q1[1:0], i_a[13:0]} : {i_b[67:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[67:16], b1[1:0], i_b[13:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[67:14], q1[1:0], i_a[11:0]} : {i_b[67:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[67:14], b1[1:0], i_b[11:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[67:12], q1[1:0], i_a[9:0]} : {i_b[67:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[67:12], b1[1:0], i_b[9:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[67:10], q1[1:0], i_a[7:0]} : {i_b[67:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[67:10], b1[1:0], i_b[7:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[67:8], q1[1:0], i_a[5:0]} : {i_b[67:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[67:8], b1[1:0], i_b[5:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[67:6], q1[1:0], i_a[3:0]} : {i_b[67:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[67:6], b1[1:0], i_b[3:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[67:4], q1[1:0], i_a[1:0]} : {i_b[67:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[67:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[67:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd63:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[68:67], q1[1:0], i_a[64:0]} : {i_b[68:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[68:67], b1[1:0], i_b[64:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[68:65], q1[1:0], i_a[62:0]} : {i_b[68:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[68:65], b1[1:0], i_b[62:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[68:63], q1[1:0], i_a[60:0]} : {i_b[68:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[68:63], b1[1:0], i_b[60:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[68:61], q1[1:0], i_a[58:0]} : {i_b[68:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[68:61], b1[1:0], i_b[58:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[68:59], q1[1:0], i_a[56:0]} : {i_b[68:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[68:59], b1[1:0], i_b[56:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[68:57], q1[1:0], i_a[54:0]} : {i_b[68:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[68:57], b1[1:0], i_b[54:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[68:55], q1[1:0], i_a[52:0]} : {i_b[68:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[68:55], b1[1:0], i_b[52:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[68:53], q1[1:0], i_a[50:0]} : {i_b[68:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[68:53], b1[1:0], i_b[50:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[68:51], q1[1:0], i_a[48:0]} : {i_b[68:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[68:51], b1[1:0], i_b[48:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[68:49], q1[1:0], i_a[46:0]} : {i_b[68:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[68:49], b1[1:0], i_b[46:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[68:47], q1[1:0], i_a[44:0]} : {i_b[68:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[68:47], b1[1:0], i_b[44:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[68:45], q1[1:0], i_a[42:0]} : {i_b[68:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[68:45], b1[1:0], i_b[42:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[68:43], q1[1:0], i_a[40:0]} : {i_b[68:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[68:43], b1[1:0], i_b[40:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[68:41], q1[1:0], i_a[38:0]} : {i_b[68:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[68:41], b1[1:0], i_b[38:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[68:39], q1[1:0], i_a[36:0]} : {i_b[68:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[68:39], b1[1:0], i_b[36:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[68:37], q1[1:0], i_a[34:0]} : {i_b[68:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[68:37], b1[1:0], i_b[34:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[68:35], q1[1:0], i_a[32:0]} : {i_b[68:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[68:35], b1[1:0], i_b[32:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[68:33], q1[1:0], i_a[30:0]} : {i_b[68:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[68:33], b1[1:0], i_b[30:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[68:31], q1[1:0], i_a[28:0]} : {i_b[68:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[68:31], b1[1:0], i_b[28:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[68:29], q1[1:0], i_a[26:0]} : {i_b[68:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[68:29], b1[1:0], i_b[26:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[68:27], q1[1:0], i_a[24:0]} : {i_b[68:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[68:27], b1[1:0], i_b[24:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[68:25], q1[1:0], i_a[22:0]} : {i_b[68:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[68:25], b1[1:0], i_b[22:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[68:23], q1[1:0], i_a[20:0]} : {i_b[68:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[68:23], b1[1:0], i_b[20:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[68:21], q1[1:0], i_a[18:0]} : {i_b[68:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[68:21], b1[1:0], i_b[18:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[68:19], q1[1:0], i_a[16:0]} : {i_b[68:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[68:19], b1[1:0], i_b[16:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[68:17], q1[1:0], i_a[14:0]} : {i_b[68:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[68:17], b1[1:0], i_b[14:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[68:15], q1[1:0], i_a[12:0]} : {i_b[68:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[68:15], b1[1:0], i_b[12:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[68:13], q1[1:0], i_a[10:0]} : {i_b[68:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[68:13], b1[1:0], i_b[10:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[68:11], q1[1:0], i_a[8:0]} : {i_b[68:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[68:11], b1[1:0], i_b[8:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[68:9], q1[1:0], i_a[6:0]} : {i_b[68:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[68:9], b1[1:0], i_b[6:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[68:7], q1[1:0], i_a[4:0]} : {i_b[68:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[68:7], b1[1:0], i_b[4:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[68:5], q1[1:0], i_a[2:0]} : {i_b[68:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[68:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[68:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd64:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[69:68], q1[1:0], i_a[65:0]} : {i_b[69:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[69:68], b1[1:0], i_b[65:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[69:66], q1[1:0], i_a[63:0]} : {i_b[69:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[69:66], b1[1:0], i_b[63:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[69:64], q1[1:0], i_a[61:0]} : {i_b[69:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[69:64], b1[1:0], i_b[61:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[69:62], q1[1:0], i_a[59:0]} : {i_b[69:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[69:62], b1[1:0], i_b[59:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[69:60], q1[1:0], i_a[57:0]} : {i_b[69:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[69:60], b1[1:0], i_b[57:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[69:58], q1[1:0], i_a[55:0]} : {i_b[69:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[69:58], b1[1:0], i_b[55:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[69:56], q1[1:0], i_a[53:0]} : {i_b[69:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[69:56], b1[1:0], i_b[53:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[69:54], q1[1:0], i_a[51:0]} : {i_b[69:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[69:54], b1[1:0], i_b[51:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[69:52], q1[1:0], i_a[49:0]} : {i_b[69:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[69:52], b1[1:0], i_b[49:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[69:50], q1[1:0], i_a[47:0]} : {i_b[69:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[69:50], b1[1:0], i_b[47:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[69:48], q1[1:0], i_a[45:0]} : {i_b[69:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[69:48], b1[1:0], i_b[45:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[69:46], q1[1:0], i_a[43:0]} : {i_b[69:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[69:46], b1[1:0], i_b[43:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[69:44], q1[1:0], i_a[41:0]} : {i_b[69:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[69:44], b1[1:0], i_b[41:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[69:42], q1[1:0], i_a[39:0]} : {i_b[69:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[69:42], b1[1:0], i_b[39:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[69:40], q1[1:0], i_a[37:0]} : {i_b[69:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[69:40], b1[1:0], i_b[37:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[69:38], q1[1:0], i_a[35:0]} : {i_b[69:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[69:38], b1[1:0], i_b[35:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[69:36], q1[1:0], i_a[33:0]} : {i_b[69:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[69:36], b1[1:0], i_b[33:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[69:34], q1[1:0], i_a[31:0]} : {i_b[69:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[69:34], b1[1:0], i_b[31:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[69:32], q1[1:0], i_a[29:0]} : {i_b[69:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[69:32], b1[1:0], i_b[29:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[69:30], q1[1:0], i_a[27:0]} : {i_b[69:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[69:30], b1[1:0], i_b[27:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[69:28], q1[1:0], i_a[25:0]} : {i_b[69:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[69:28], b1[1:0], i_b[25:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[69:26], q1[1:0], i_a[23:0]} : {i_b[69:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[69:26], b1[1:0], i_b[23:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[69:24], q1[1:0], i_a[21:0]} : {i_b[69:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[69:24], b1[1:0], i_b[21:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[69:22], q1[1:0], i_a[19:0]} : {i_b[69:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[69:22], b1[1:0], i_b[19:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[69:20], q1[1:0], i_a[17:0]} : {i_b[69:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[69:20], b1[1:0], i_b[17:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[69:18], q1[1:0], i_a[15:0]} : {i_b[69:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[69:18], b1[1:0], i_b[15:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[69:16], q1[1:0], i_a[13:0]} : {i_b[69:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[69:16], b1[1:0], i_b[13:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[69:14], q1[1:0], i_a[11:0]} : {i_b[69:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[69:14], b1[1:0], i_b[11:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[69:12], q1[1:0], i_a[9:0]} : {i_b[69:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[69:12], b1[1:0], i_b[9:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[69:10], q1[1:0], i_a[7:0]} : {i_b[69:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[69:10], b1[1:0], i_b[7:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[69:8], q1[1:0], i_a[5:0]} : {i_b[69:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[69:8], b1[1:0], i_b[5:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[69:6], q1[1:0], i_a[3:0]} : {i_b[69:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[69:6], b1[1:0], i_b[3:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[69:4], q1[1:0], i_a[1:0]} : {i_b[69:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[69:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[69:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd65:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[70:69], q1[1:0], i_a[66:0]} : {i_b[70:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[70:69], b1[1:0], i_b[66:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[70:67], q1[1:0], i_a[64:0]} : {i_b[70:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[70:67], b1[1:0], i_b[64:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[70:65], q1[1:0], i_a[62:0]} : {i_b[70:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[70:65], b1[1:0], i_b[62:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[70:63], q1[1:0], i_a[60:0]} : {i_b[70:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[70:63], b1[1:0], i_b[60:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[70:61], q1[1:0], i_a[58:0]} : {i_b[70:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[70:61], b1[1:0], i_b[58:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[70:59], q1[1:0], i_a[56:0]} : {i_b[70:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[70:59], b1[1:0], i_b[56:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[70:57], q1[1:0], i_a[54:0]} : {i_b[70:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[70:57], b1[1:0], i_b[54:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[70:55], q1[1:0], i_a[52:0]} : {i_b[70:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[70:55], b1[1:0], i_b[52:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[70:53], q1[1:0], i_a[50:0]} : {i_b[70:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[70:53], b1[1:0], i_b[50:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[70:51], q1[1:0], i_a[48:0]} : {i_b[70:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[70:51], b1[1:0], i_b[48:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[70:49], q1[1:0], i_a[46:0]} : {i_b[70:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[70:49], b1[1:0], i_b[46:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[70:47], q1[1:0], i_a[44:0]} : {i_b[70:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[70:47], b1[1:0], i_b[44:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[70:45], q1[1:0], i_a[42:0]} : {i_b[70:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[70:45], b1[1:0], i_b[42:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[70:43], q1[1:0], i_a[40:0]} : {i_b[70:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[70:43], b1[1:0], i_b[40:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[70:41], q1[1:0], i_a[38:0]} : {i_b[70:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[70:41], b1[1:0], i_b[38:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[70:39], q1[1:0], i_a[36:0]} : {i_b[70:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[70:39], b1[1:0], i_b[36:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[70:37], q1[1:0], i_a[34:0]} : {i_b[70:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[70:37], b1[1:0], i_b[34:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[70:35], q1[1:0], i_a[32:0]} : {i_b[70:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[70:35], b1[1:0], i_b[32:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[70:33], q1[1:0], i_a[30:0]} : {i_b[70:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[70:33], b1[1:0], i_b[30:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[70:31], q1[1:0], i_a[28:0]} : {i_b[70:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[70:31], b1[1:0], i_b[28:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[70:29], q1[1:0], i_a[26:0]} : {i_b[70:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[70:29], b1[1:0], i_b[26:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[70:27], q1[1:0], i_a[24:0]} : {i_b[70:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[70:27], b1[1:0], i_b[24:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[70:25], q1[1:0], i_a[22:0]} : {i_b[70:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[70:25], b1[1:0], i_b[22:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[70:23], q1[1:0], i_a[20:0]} : {i_b[70:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[70:23], b1[1:0], i_b[20:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[70:21], q1[1:0], i_a[18:0]} : {i_b[70:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[70:21], b1[1:0], i_b[18:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[70:19], q1[1:0], i_a[16:0]} : {i_b[70:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[70:19], b1[1:0], i_b[16:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[70:17], q1[1:0], i_a[14:0]} : {i_b[70:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[70:17], b1[1:0], i_b[14:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[70:15], q1[1:0], i_a[12:0]} : {i_b[70:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[70:15], b1[1:0], i_b[12:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[70:13], q1[1:0], i_a[10:0]} : {i_b[70:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[70:13], b1[1:0], i_b[10:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[70:11], q1[1:0], i_a[8:0]} : {i_b[70:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[70:11], b1[1:0], i_b[8:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[70:9], q1[1:0], i_a[6:0]} : {i_b[70:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[70:9], b1[1:0], i_b[6:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[70:7], q1[1:0], i_a[4:0]} : {i_b[70:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[70:7], b1[1:0], i_b[4:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[70:5], q1[1:0], i_a[2:0]} : {i_b[70:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[70:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[70:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd66:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[71:70], q1[1:0], i_a[67:0]} : {i_b[71:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[71:70], b1[1:0], i_b[67:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[71:68], q1[1:0], i_a[65:0]} : {i_b[71:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[71:68], b1[1:0], i_b[65:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[71:66], q1[1:0], i_a[63:0]} : {i_b[71:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[71:66], b1[1:0], i_b[63:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[71:64], q1[1:0], i_a[61:0]} : {i_b[71:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[71:64], b1[1:0], i_b[61:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[71:62], q1[1:0], i_a[59:0]} : {i_b[71:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[71:62], b1[1:0], i_b[59:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[71:60], q1[1:0], i_a[57:0]} : {i_b[71:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[71:60], b1[1:0], i_b[57:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[71:58], q1[1:0], i_a[55:0]} : {i_b[71:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[71:58], b1[1:0], i_b[55:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[71:56], q1[1:0], i_a[53:0]} : {i_b[71:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[71:56], b1[1:0], i_b[53:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[71:54], q1[1:0], i_a[51:0]} : {i_b[71:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[71:54], b1[1:0], i_b[51:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[71:52], q1[1:0], i_a[49:0]} : {i_b[71:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[71:52], b1[1:0], i_b[49:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[71:50], q1[1:0], i_a[47:0]} : {i_b[71:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[71:50], b1[1:0], i_b[47:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[71:48], q1[1:0], i_a[45:0]} : {i_b[71:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[71:48], b1[1:0], i_b[45:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[71:46], q1[1:0], i_a[43:0]} : {i_b[71:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[71:46], b1[1:0], i_b[43:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[71:44], q1[1:0], i_a[41:0]} : {i_b[71:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[71:44], b1[1:0], i_b[41:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[71:42], q1[1:0], i_a[39:0]} : {i_b[71:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[71:42], b1[1:0], i_b[39:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[71:40], q1[1:0], i_a[37:0]} : {i_b[71:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[71:40], b1[1:0], i_b[37:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[71:38], q1[1:0], i_a[35:0]} : {i_b[71:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[71:38], b1[1:0], i_b[35:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[71:36], q1[1:0], i_a[33:0]} : {i_b[71:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[71:36], b1[1:0], i_b[33:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[71:34], q1[1:0], i_a[31:0]} : {i_b[71:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[71:34], b1[1:0], i_b[31:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[71:32], q1[1:0], i_a[29:0]} : {i_b[71:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[71:32], b1[1:0], i_b[29:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[71:30], q1[1:0], i_a[27:0]} : {i_b[71:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[71:30], b1[1:0], i_b[27:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[71:28], q1[1:0], i_a[25:0]} : {i_b[71:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[71:28], b1[1:0], i_b[25:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[71:26], q1[1:0], i_a[23:0]} : {i_b[71:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[71:26], b1[1:0], i_b[23:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[71:24], q1[1:0], i_a[21:0]} : {i_b[71:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[71:24], b1[1:0], i_b[21:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[71:22], q1[1:0], i_a[19:0]} : {i_b[71:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[71:22], b1[1:0], i_b[19:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[71:20], q1[1:0], i_a[17:0]} : {i_b[71:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[71:20], b1[1:0], i_b[17:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[71:18], q1[1:0], i_a[15:0]} : {i_b[71:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[71:18], b1[1:0], i_b[15:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[71:16], q1[1:0], i_a[13:0]} : {i_b[71:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[71:16], b1[1:0], i_b[13:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[71:14], q1[1:0], i_a[11:0]} : {i_b[71:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[71:14], b1[1:0], i_b[11:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[71:12], q1[1:0], i_a[9:0]} : {i_b[71:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[71:12], b1[1:0], i_b[9:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[71:10], q1[1:0], i_a[7:0]} : {i_b[71:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[71:10], b1[1:0], i_b[7:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[71:8], q1[1:0], i_a[5:0]} : {i_b[71:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[71:8], b1[1:0], i_b[5:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[71:6], q1[1:0], i_a[3:0]} : {i_b[71:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[71:6], b1[1:0], i_b[3:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[71:4], q1[1:0], i_a[1:0]} : {i_b[71:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[71:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[71:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd67:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[72:71], q1[1:0], i_a[68:0]} : {i_b[72:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[72:71], b1[1:0], i_b[68:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[72:69], q1[1:0], i_a[66:0]} : {i_b[72:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[72:69], b1[1:0], i_b[66:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[72:67], q1[1:0], i_a[64:0]} : {i_b[72:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[72:67], b1[1:0], i_b[64:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[72:65], q1[1:0], i_a[62:0]} : {i_b[72:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[72:65], b1[1:0], i_b[62:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[72:63], q1[1:0], i_a[60:0]} : {i_b[72:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[72:63], b1[1:0], i_b[60:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[72:61], q1[1:0], i_a[58:0]} : {i_b[72:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[72:61], b1[1:0], i_b[58:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[72:59], q1[1:0], i_a[56:0]} : {i_b[72:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[72:59], b1[1:0], i_b[56:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[72:57], q1[1:0], i_a[54:0]} : {i_b[72:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[72:57], b1[1:0], i_b[54:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[72:55], q1[1:0], i_a[52:0]} : {i_b[72:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[72:55], b1[1:0], i_b[52:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[72:53], q1[1:0], i_a[50:0]} : {i_b[72:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[72:53], b1[1:0], i_b[50:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[72:51], q1[1:0], i_a[48:0]} : {i_b[72:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[72:51], b1[1:0], i_b[48:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[72:49], q1[1:0], i_a[46:0]} : {i_b[72:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[72:49], b1[1:0], i_b[46:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[72:47], q1[1:0], i_a[44:0]} : {i_b[72:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[72:47], b1[1:0], i_b[44:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[72:45], q1[1:0], i_a[42:0]} : {i_b[72:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[72:45], b1[1:0], i_b[42:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[72:43], q1[1:0], i_a[40:0]} : {i_b[72:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[72:43], b1[1:0], i_b[40:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[72:41], q1[1:0], i_a[38:0]} : {i_b[72:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[72:41], b1[1:0], i_b[38:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[72:39], q1[1:0], i_a[36:0]} : {i_b[72:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[72:39], b1[1:0], i_b[36:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[72:37], q1[1:0], i_a[34:0]} : {i_b[72:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[72:37], b1[1:0], i_b[34:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[72:35], q1[1:0], i_a[32:0]} : {i_b[72:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[72:35], b1[1:0], i_b[32:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[72:33], q1[1:0], i_a[30:0]} : {i_b[72:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[72:33], b1[1:0], i_b[30:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[72:31], q1[1:0], i_a[28:0]} : {i_b[72:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[72:31], b1[1:0], i_b[28:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[72:29], q1[1:0], i_a[26:0]} : {i_b[72:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[72:29], b1[1:0], i_b[26:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[72:27], q1[1:0], i_a[24:0]} : {i_b[72:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[72:27], b1[1:0], i_b[24:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[72:25], q1[1:0], i_a[22:0]} : {i_b[72:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[72:25], b1[1:0], i_b[22:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[72:23], q1[1:0], i_a[20:0]} : {i_b[72:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[72:23], b1[1:0], i_b[20:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[72:21], q1[1:0], i_a[18:0]} : {i_b[72:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[72:21], b1[1:0], i_b[18:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[72:19], q1[1:0], i_a[16:0]} : {i_b[72:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[72:19], b1[1:0], i_b[16:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[72:17], q1[1:0], i_a[14:0]} : {i_b[72:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[72:17], b1[1:0], i_b[14:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[72:15], q1[1:0], i_a[12:0]} : {i_b[72:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[72:15], b1[1:0], i_b[12:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[72:13], q1[1:0], i_a[10:0]} : {i_b[72:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[72:13], b1[1:0], i_b[10:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[72:11], q1[1:0], i_a[8:0]} : {i_b[72:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[72:11], b1[1:0], i_b[8:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[72:9], q1[1:0], i_a[6:0]} : {i_b[72:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[72:9], b1[1:0], i_b[6:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[72:7], q1[1:0], i_a[4:0]} : {i_b[72:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[72:7], b1[1:0], i_b[4:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[72:5], q1[1:0], i_a[2:0]} : {i_b[72:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[72:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[72:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd68:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[73:72], q1[1:0], i_a[69:0]} : {i_b[73:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[73:72], b1[1:0], i_b[69:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[73:70], q1[1:0], i_a[67:0]} : {i_b[73:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[73:70], b1[1:0], i_b[67:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[73:68], q1[1:0], i_a[65:0]} : {i_b[73:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[73:68], b1[1:0], i_b[65:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[73:66], q1[1:0], i_a[63:0]} : {i_b[73:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[73:66], b1[1:0], i_b[63:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[73:64], q1[1:0], i_a[61:0]} : {i_b[73:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[73:64], b1[1:0], i_b[61:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[73:62], q1[1:0], i_a[59:0]} : {i_b[73:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[73:62], b1[1:0], i_b[59:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[73:60], q1[1:0], i_a[57:0]} : {i_b[73:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[73:60], b1[1:0], i_b[57:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[73:58], q1[1:0], i_a[55:0]} : {i_b[73:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[73:58], b1[1:0], i_b[55:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[73:56], q1[1:0], i_a[53:0]} : {i_b[73:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[73:56], b1[1:0], i_b[53:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[73:54], q1[1:0], i_a[51:0]} : {i_b[73:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[73:54], b1[1:0], i_b[51:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[73:52], q1[1:0], i_a[49:0]} : {i_b[73:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[73:52], b1[1:0], i_b[49:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[73:50], q1[1:0], i_a[47:0]} : {i_b[73:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[73:50], b1[1:0], i_b[47:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[73:48], q1[1:0], i_a[45:0]} : {i_b[73:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[73:48], b1[1:0], i_b[45:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[73:46], q1[1:0], i_a[43:0]} : {i_b[73:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[73:46], b1[1:0], i_b[43:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[73:44], q1[1:0], i_a[41:0]} : {i_b[73:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[73:44], b1[1:0], i_b[41:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[73:42], q1[1:0], i_a[39:0]} : {i_b[73:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[73:42], b1[1:0], i_b[39:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[73:40], q1[1:0], i_a[37:0]} : {i_b[73:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[73:40], b1[1:0], i_b[37:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[73:38], q1[1:0], i_a[35:0]} : {i_b[73:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[73:38], b1[1:0], i_b[35:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[73:36], q1[1:0], i_a[33:0]} : {i_b[73:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[73:36], b1[1:0], i_b[33:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[73:34], q1[1:0], i_a[31:0]} : {i_b[73:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[73:34], b1[1:0], i_b[31:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[73:32], q1[1:0], i_a[29:0]} : {i_b[73:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[73:32], b1[1:0], i_b[29:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[73:30], q1[1:0], i_a[27:0]} : {i_b[73:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[73:30], b1[1:0], i_b[27:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[73:28], q1[1:0], i_a[25:0]} : {i_b[73:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[73:28], b1[1:0], i_b[25:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[73:26], q1[1:0], i_a[23:0]} : {i_b[73:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[73:26], b1[1:0], i_b[23:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[73:24], q1[1:0], i_a[21:0]} : {i_b[73:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[73:24], b1[1:0], i_b[21:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[73:22], q1[1:0], i_a[19:0]} : {i_b[73:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[73:22], b1[1:0], i_b[19:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[73:20], q1[1:0], i_a[17:0]} : {i_b[73:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[73:20], b1[1:0], i_b[17:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[73:18], q1[1:0], i_a[15:0]} : {i_b[73:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[73:18], b1[1:0], i_b[15:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[73:16], q1[1:0], i_a[13:0]} : {i_b[73:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[73:16], b1[1:0], i_b[13:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[73:14], q1[1:0], i_a[11:0]} : {i_b[73:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[73:14], b1[1:0], i_b[11:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[73:12], q1[1:0], i_a[9:0]} : {i_b[73:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[73:12], b1[1:0], i_b[9:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[73:10], q1[1:0], i_a[7:0]} : {i_b[73:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[73:10], b1[1:0], i_b[7:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[73:8], q1[1:0], i_a[5:0]} : {i_b[73:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[73:8], b1[1:0], i_b[5:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[73:6], q1[1:0], i_a[3:0]} : {i_b[73:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[73:6], b1[1:0], i_b[3:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[73:4], q1[1:0], i_a[1:0]} : {i_b[73:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[73:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[73:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd69:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[74:73], q1[1:0], i_a[70:0]} : {i_b[74:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[74:73], b1[1:0], i_b[70:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[74:71], q1[1:0], i_a[68:0]} : {i_b[74:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[74:71], b1[1:0], i_b[68:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[74:69], q1[1:0], i_a[66:0]} : {i_b[74:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[74:69], b1[1:0], i_b[66:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[74:67], q1[1:0], i_a[64:0]} : {i_b[74:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[74:67], b1[1:0], i_b[64:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[74:65], q1[1:0], i_a[62:0]} : {i_b[74:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[74:65], b1[1:0], i_b[62:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[74:63], q1[1:0], i_a[60:0]} : {i_b[74:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[74:63], b1[1:0], i_b[60:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[74:61], q1[1:0], i_a[58:0]} : {i_b[74:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[74:61], b1[1:0], i_b[58:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[74:59], q1[1:0], i_a[56:0]} : {i_b[74:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[74:59], b1[1:0], i_b[56:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[74:57], q1[1:0], i_a[54:0]} : {i_b[74:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[74:57], b1[1:0], i_b[54:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[74:55], q1[1:0], i_a[52:0]} : {i_b[74:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[74:55], b1[1:0], i_b[52:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[74:53], q1[1:0], i_a[50:0]} : {i_b[74:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[74:53], b1[1:0], i_b[50:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[74:51], q1[1:0], i_a[48:0]} : {i_b[74:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[74:51], b1[1:0], i_b[48:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[74:49], q1[1:0], i_a[46:0]} : {i_b[74:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[74:49], b1[1:0], i_b[46:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[74:47], q1[1:0], i_a[44:0]} : {i_b[74:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[74:47], b1[1:0], i_b[44:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[74:45], q1[1:0], i_a[42:0]} : {i_b[74:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[74:45], b1[1:0], i_b[42:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[74:43], q1[1:0], i_a[40:0]} : {i_b[74:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[74:43], b1[1:0], i_b[40:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[74:41], q1[1:0], i_a[38:0]} : {i_b[74:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[74:41], b1[1:0], i_b[38:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[74:39], q1[1:0], i_a[36:0]} : {i_b[74:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[74:39], b1[1:0], i_b[36:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[74:37], q1[1:0], i_a[34:0]} : {i_b[74:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[74:37], b1[1:0], i_b[34:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[74:35], q1[1:0], i_a[32:0]} : {i_b[74:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[74:35], b1[1:0], i_b[32:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[74:33], q1[1:0], i_a[30:0]} : {i_b[74:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[74:33], b1[1:0], i_b[30:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[74:31], q1[1:0], i_a[28:0]} : {i_b[74:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[74:31], b1[1:0], i_b[28:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[74:29], q1[1:0], i_a[26:0]} : {i_b[74:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[74:29], b1[1:0], i_b[26:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[74:27], q1[1:0], i_a[24:0]} : {i_b[74:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[74:27], b1[1:0], i_b[24:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[74:25], q1[1:0], i_a[22:0]} : {i_b[74:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[74:25], b1[1:0], i_b[22:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[74:23], q1[1:0], i_a[20:0]} : {i_b[74:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[74:23], b1[1:0], i_b[20:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[74:21], q1[1:0], i_a[18:0]} : {i_b[74:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[74:21], b1[1:0], i_b[18:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[74:19], q1[1:0], i_a[16:0]} : {i_b[74:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[74:19], b1[1:0], i_b[16:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[74:17], q1[1:0], i_a[14:0]} : {i_b[74:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[74:17], b1[1:0], i_b[14:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[74:15], q1[1:0], i_a[12:0]} : {i_b[74:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[74:15], b1[1:0], i_b[12:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[74:13], q1[1:0], i_a[10:0]} : {i_b[74:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[74:13], b1[1:0], i_b[10:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[74:11], q1[1:0], i_a[8:0]} : {i_b[74:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[74:11], b1[1:0], i_b[8:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[74:9], q1[1:0], i_a[6:0]} : {i_b[74:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[74:9], b1[1:0], i_b[6:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[74:7], q1[1:0], i_a[4:0]} : {i_b[74:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[74:7], b1[1:0], i_b[4:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[74:5], q1[1:0], i_a[2:0]} : {i_b[74:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[74:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[74:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd70:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[75:74], q1[1:0], i_a[71:0]} : {i_b[75:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[75:74], b1[1:0], i_b[71:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[75:72], q1[1:0], i_a[69:0]} : {i_b[75:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[75:72], b1[1:0], i_b[69:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[75:70], q1[1:0], i_a[67:0]} : {i_b[75:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[75:70], b1[1:0], i_b[67:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[75:68], q1[1:0], i_a[65:0]} : {i_b[75:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[75:68], b1[1:0], i_b[65:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[75:66], q1[1:0], i_a[63:0]} : {i_b[75:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[75:66], b1[1:0], i_b[63:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[75:64], q1[1:0], i_a[61:0]} : {i_b[75:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[75:64], b1[1:0], i_b[61:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[75:62], q1[1:0], i_a[59:0]} : {i_b[75:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[75:62], b1[1:0], i_b[59:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[75:60], q1[1:0], i_a[57:0]} : {i_b[75:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[75:60], b1[1:0], i_b[57:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[75:58], q1[1:0], i_a[55:0]} : {i_b[75:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[75:58], b1[1:0], i_b[55:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[75:56], q1[1:0], i_a[53:0]} : {i_b[75:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[75:56], b1[1:0], i_b[53:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[75:54], q1[1:0], i_a[51:0]} : {i_b[75:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[75:54], b1[1:0], i_b[51:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[75:52], q1[1:0], i_a[49:0]} : {i_b[75:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[75:52], b1[1:0], i_b[49:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[75:50], q1[1:0], i_a[47:0]} : {i_b[75:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[75:50], b1[1:0], i_b[47:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[75:48], q1[1:0], i_a[45:0]} : {i_b[75:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[75:48], b1[1:0], i_b[45:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[75:46], q1[1:0], i_a[43:0]} : {i_b[75:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[75:46], b1[1:0], i_b[43:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[75:44], q1[1:0], i_a[41:0]} : {i_b[75:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[75:44], b1[1:0], i_b[41:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[75:42], q1[1:0], i_a[39:0]} : {i_b[75:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[75:42], b1[1:0], i_b[39:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[75:40], q1[1:0], i_a[37:0]} : {i_b[75:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[75:40], b1[1:0], i_b[37:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[75:38], q1[1:0], i_a[35:0]} : {i_b[75:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[75:38], b1[1:0], i_b[35:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[75:36], q1[1:0], i_a[33:0]} : {i_b[75:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[75:36], b1[1:0], i_b[33:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[75:34], q1[1:0], i_a[31:0]} : {i_b[75:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[75:34], b1[1:0], i_b[31:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[75:32], q1[1:0], i_a[29:0]} : {i_b[75:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[75:32], b1[1:0], i_b[29:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[75:30], q1[1:0], i_a[27:0]} : {i_b[75:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[75:30], b1[1:0], i_b[27:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[75:28], q1[1:0], i_a[25:0]} : {i_b[75:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[75:28], b1[1:0], i_b[25:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[75:26], q1[1:0], i_a[23:0]} : {i_b[75:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[75:26], b1[1:0], i_b[23:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[75:24], q1[1:0], i_a[21:0]} : {i_b[75:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[75:24], b1[1:0], i_b[21:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[75:22], q1[1:0], i_a[19:0]} : {i_b[75:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[75:22], b1[1:0], i_b[19:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[75:20], q1[1:0], i_a[17:0]} : {i_b[75:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[75:20], b1[1:0], i_b[17:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[75:18], q1[1:0], i_a[15:0]} : {i_b[75:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[75:18], b1[1:0], i_b[15:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[75:16], q1[1:0], i_a[13:0]} : {i_b[75:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[75:16], b1[1:0], i_b[13:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[75:14], q1[1:0], i_a[11:0]} : {i_b[75:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[75:14], b1[1:0], i_b[11:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[75:12], q1[1:0], i_a[9:0]} : {i_b[75:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[75:12], b1[1:0], i_b[9:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[75:10], q1[1:0], i_a[7:0]} : {i_b[75:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[75:10], b1[1:0], i_b[7:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[75:8], q1[1:0], i_a[5:0]} : {i_b[75:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[75:8], b1[1:0], i_b[5:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[75:6], q1[1:0], i_a[3:0]} : {i_b[75:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[75:6], b1[1:0], i_b[3:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[75:4], q1[1:0], i_a[1:0]} : {i_b[75:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[75:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[75:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd71:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[76:75], q1[1:0], i_a[72:0]} : {i_b[76:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[76:75], b1[1:0], i_b[72:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[76:73], q1[1:0], i_a[70:0]} : {i_b[76:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[76:73], b1[1:0], i_b[70:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[76:71], q1[1:0], i_a[68:0]} : {i_b[76:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[76:71], b1[1:0], i_b[68:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[76:69], q1[1:0], i_a[66:0]} : {i_b[76:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[76:69], b1[1:0], i_b[66:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[76:67], q1[1:0], i_a[64:0]} : {i_b[76:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[76:67], b1[1:0], i_b[64:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[76:65], q1[1:0], i_a[62:0]} : {i_b[76:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[76:65], b1[1:0], i_b[62:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[76:63], q1[1:0], i_a[60:0]} : {i_b[76:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[76:63], b1[1:0], i_b[60:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[76:61], q1[1:0], i_a[58:0]} : {i_b[76:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[76:61], b1[1:0], i_b[58:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[76:59], q1[1:0], i_a[56:0]} : {i_b[76:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[76:59], b1[1:0], i_b[56:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[76:57], q1[1:0], i_a[54:0]} : {i_b[76:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[76:57], b1[1:0], i_b[54:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[76:55], q1[1:0], i_a[52:0]} : {i_b[76:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[76:55], b1[1:0], i_b[52:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[76:53], q1[1:0], i_a[50:0]} : {i_b[76:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[76:53], b1[1:0], i_b[50:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[76:51], q1[1:0], i_a[48:0]} : {i_b[76:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[76:51], b1[1:0], i_b[48:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[76:49], q1[1:0], i_a[46:0]} : {i_b[76:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[76:49], b1[1:0], i_b[46:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[76:47], q1[1:0], i_a[44:0]} : {i_b[76:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[76:47], b1[1:0], i_b[44:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[76:45], q1[1:0], i_a[42:0]} : {i_b[76:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[76:45], b1[1:0], i_b[42:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[76:43], q1[1:0], i_a[40:0]} : {i_b[76:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[76:43], b1[1:0], i_b[40:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[76:41], q1[1:0], i_a[38:0]} : {i_b[76:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[76:41], b1[1:0], i_b[38:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[76:39], q1[1:0], i_a[36:0]} : {i_b[76:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[76:39], b1[1:0], i_b[36:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[76:37], q1[1:0], i_a[34:0]} : {i_b[76:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[76:37], b1[1:0], i_b[34:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[76:35], q1[1:0], i_a[32:0]} : {i_b[76:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[76:35], b1[1:0], i_b[32:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[76:33], q1[1:0], i_a[30:0]} : {i_b[76:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[76:33], b1[1:0], i_b[30:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[76:31], q1[1:0], i_a[28:0]} : {i_b[76:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[76:31], b1[1:0], i_b[28:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[76:29], q1[1:0], i_a[26:0]} : {i_b[76:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[76:29], b1[1:0], i_b[26:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[76:27], q1[1:0], i_a[24:0]} : {i_b[76:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[76:27], b1[1:0], i_b[24:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[76:25], q1[1:0], i_a[22:0]} : {i_b[76:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[76:25], b1[1:0], i_b[22:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[76:23], q1[1:0], i_a[20:0]} : {i_b[76:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[76:23], b1[1:0], i_b[20:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[76:21], q1[1:0], i_a[18:0]} : {i_b[76:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[76:21], b1[1:0], i_b[18:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[76:19], q1[1:0], i_a[16:0]} : {i_b[76:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[76:19], b1[1:0], i_b[16:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[76:17], q1[1:0], i_a[14:0]} : {i_b[76:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[76:17], b1[1:0], i_b[14:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[76:15], q1[1:0], i_a[12:0]} : {i_b[76:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[76:15], b1[1:0], i_b[12:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[76:13], q1[1:0], i_a[10:0]} : {i_b[76:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[76:13], b1[1:0], i_b[10:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[76:11], q1[1:0], i_a[8:0]} : {i_b[76:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[76:11], b1[1:0], i_b[8:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[76:9], q1[1:0], i_a[6:0]} : {i_b[76:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[76:9], b1[1:0], i_b[6:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[76:7], q1[1:0], i_a[4:0]} : {i_b[76:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[76:7], b1[1:0], i_b[4:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[76:5], q1[1:0], i_a[2:0]} : {i_b[76:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[76:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[76:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd72:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[77:76], q1[1:0], i_a[73:0]} : {i_b[77:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[77:76], b1[1:0], i_b[73:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[77:74], q1[1:0], i_a[71:0]} : {i_b[77:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[77:74], b1[1:0], i_b[71:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[77:72], q1[1:0], i_a[69:0]} : {i_b[77:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[77:72], b1[1:0], i_b[69:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[77:70], q1[1:0], i_a[67:0]} : {i_b[77:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[77:70], b1[1:0], i_b[67:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[77:68], q1[1:0], i_a[65:0]} : {i_b[77:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[77:68], b1[1:0], i_b[65:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[77:66], q1[1:0], i_a[63:0]} : {i_b[77:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[77:66], b1[1:0], i_b[63:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[77:64], q1[1:0], i_a[61:0]} : {i_b[77:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[77:64], b1[1:0], i_b[61:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[77:62], q1[1:0], i_a[59:0]} : {i_b[77:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[77:62], b1[1:0], i_b[59:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[77:60], q1[1:0], i_a[57:0]} : {i_b[77:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[77:60], b1[1:0], i_b[57:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[77:58], q1[1:0], i_a[55:0]} : {i_b[77:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[77:58], b1[1:0], i_b[55:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[77:56], q1[1:0], i_a[53:0]} : {i_b[77:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[77:56], b1[1:0], i_b[53:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[77:54], q1[1:0], i_a[51:0]} : {i_b[77:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[77:54], b1[1:0], i_b[51:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[77:52], q1[1:0], i_a[49:0]} : {i_b[77:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[77:52], b1[1:0], i_b[49:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[77:50], q1[1:0], i_a[47:0]} : {i_b[77:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[77:50], b1[1:0], i_b[47:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[77:48], q1[1:0], i_a[45:0]} : {i_b[77:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[77:48], b1[1:0], i_b[45:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[77:46], q1[1:0], i_a[43:0]} : {i_b[77:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[77:46], b1[1:0], i_b[43:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[77:44], q1[1:0], i_a[41:0]} : {i_b[77:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[77:44], b1[1:0], i_b[41:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[77:42], q1[1:0], i_a[39:0]} : {i_b[77:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[77:42], b1[1:0], i_b[39:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[77:40], q1[1:0], i_a[37:0]} : {i_b[77:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[77:40], b1[1:0], i_b[37:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[77:38], q1[1:0], i_a[35:0]} : {i_b[77:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[77:38], b1[1:0], i_b[35:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[77:36], q1[1:0], i_a[33:0]} : {i_b[77:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[77:36], b1[1:0], i_b[33:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[77:34], q1[1:0], i_a[31:0]} : {i_b[77:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[77:34], b1[1:0], i_b[31:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[77:32], q1[1:0], i_a[29:0]} : {i_b[77:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[77:32], b1[1:0], i_b[29:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[77:30], q1[1:0], i_a[27:0]} : {i_b[77:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[77:30], b1[1:0], i_b[27:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[77:28], q1[1:0], i_a[25:0]} : {i_b[77:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[77:28], b1[1:0], i_b[25:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[77:26], q1[1:0], i_a[23:0]} : {i_b[77:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[77:26], b1[1:0], i_b[23:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[77:24], q1[1:0], i_a[21:0]} : {i_b[77:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[77:24], b1[1:0], i_b[21:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[77:22], q1[1:0], i_a[19:0]} : {i_b[77:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[77:22], b1[1:0], i_b[19:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[77:20], q1[1:0], i_a[17:0]} : {i_b[77:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[77:20], b1[1:0], i_b[17:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[77:18], q1[1:0], i_a[15:0]} : {i_b[77:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[77:18], b1[1:0], i_b[15:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[77:16], q1[1:0], i_a[13:0]} : {i_b[77:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[77:16], b1[1:0], i_b[13:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[77:14], q1[1:0], i_a[11:0]} : {i_b[77:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[77:14], b1[1:0], i_b[11:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[77:12], q1[1:0], i_a[9:0]} : {i_b[77:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[77:12], b1[1:0], i_b[9:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[77:10], q1[1:0], i_a[7:0]} : {i_b[77:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[77:10], b1[1:0], i_b[7:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[77:8], q1[1:0], i_a[5:0]} : {i_b[77:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[77:8], b1[1:0], i_b[5:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[77:6], q1[1:0], i_a[3:0]} : {i_b[77:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[77:6], b1[1:0], i_b[3:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[77:4], q1[1:0], i_a[1:0]} : {i_b[77:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[77:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[77:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd73:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[78:77], q1[1:0], i_a[74:0]} : {i_b[78:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[78:77], b1[1:0], i_b[74:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[78:75], q1[1:0], i_a[72:0]} : {i_b[78:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[78:75], b1[1:0], i_b[72:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[78:73], q1[1:0], i_a[70:0]} : {i_b[78:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[78:73], b1[1:0], i_b[70:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[78:71], q1[1:0], i_a[68:0]} : {i_b[78:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[78:71], b1[1:0], i_b[68:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[78:69], q1[1:0], i_a[66:0]} : {i_b[78:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[78:69], b1[1:0], i_b[66:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[78:67], q1[1:0], i_a[64:0]} : {i_b[78:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[78:67], b1[1:0], i_b[64:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[78:65], q1[1:0], i_a[62:0]} : {i_b[78:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[78:65], b1[1:0], i_b[62:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[78:63], q1[1:0], i_a[60:0]} : {i_b[78:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[78:63], b1[1:0], i_b[60:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[78:61], q1[1:0], i_a[58:0]} : {i_b[78:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[78:61], b1[1:0], i_b[58:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[78:59], q1[1:0], i_a[56:0]} : {i_b[78:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[78:59], b1[1:0], i_b[56:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[78:57], q1[1:0], i_a[54:0]} : {i_b[78:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[78:57], b1[1:0], i_b[54:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[78:55], q1[1:0], i_a[52:0]} : {i_b[78:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[78:55], b1[1:0], i_b[52:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[78:53], q1[1:0], i_a[50:0]} : {i_b[78:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[78:53], b1[1:0], i_b[50:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[78:51], q1[1:0], i_a[48:0]} : {i_b[78:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[78:51], b1[1:0], i_b[48:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[78:49], q1[1:0], i_a[46:0]} : {i_b[78:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[78:49], b1[1:0], i_b[46:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[78:47], q1[1:0], i_a[44:0]} : {i_b[78:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[78:47], b1[1:0], i_b[44:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[78:45], q1[1:0], i_a[42:0]} : {i_b[78:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[78:45], b1[1:0], i_b[42:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[78:43], q1[1:0], i_a[40:0]} : {i_b[78:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[78:43], b1[1:0], i_b[40:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[78:41], q1[1:0], i_a[38:0]} : {i_b[78:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[78:41], b1[1:0], i_b[38:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[78:39], q1[1:0], i_a[36:0]} : {i_b[78:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[78:39], b1[1:0], i_b[36:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[78:37], q1[1:0], i_a[34:0]} : {i_b[78:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[78:37], b1[1:0], i_b[34:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[78:35], q1[1:0], i_a[32:0]} : {i_b[78:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[78:35], b1[1:0], i_b[32:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[78:33], q1[1:0], i_a[30:0]} : {i_b[78:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[78:33], b1[1:0], i_b[30:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[78:31], q1[1:0], i_a[28:0]} : {i_b[78:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[78:31], b1[1:0], i_b[28:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[78:29], q1[1:0], i_a[26:0]} : {i_b[78:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[78:29], b1[1:0], i_b[26:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[78:27], q1[1:0], i_a[24:0]} : {i_b[78:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[78:27], b1[1:0], i_b[24:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[78:25], q1[1:0], i_a[22:0]} : {i_b[78:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[78:25], b1[1:0], i_b[22:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[78:23], q1[1:0], i_a[20:0]} : {i_b[78:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[78:23], b1[1:0], i_b[20:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[78:21], q1[1:0], i_a[18:0]} : {i_b[78:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[78:21], b1[1:0], i_b[18:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[78:19], q1[1:0], i_a[16:0]} : {i_b[78:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[78:19], b1[1:0], i_b[16:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[78:17], q1[1:0], i_a[14:0]} : {i_b[78:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[78:17], b1[1:0], i_b[14:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[78:15], q1[1:0], i_a[12:0]} : {i_b[78:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[78:15], b1[1:0], i_b[12:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[78:13], q1[1:0], i_a[10:0]} : {i_b[78:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[78:13], b1[1:0], i_b[10:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[78:11], q1[1:0], i_a[8:0]} : {i_b[78:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[78:11], b1[1:0], i_b[8:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[78:9], q1[1:0], i_a[6:0]} : {i_b[78:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[78:9], b1[1:0], i_b[6:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[78:7], q1[1:0], i_a[4:0]} : {i_b[78:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[78:7], b1[1:0], i_b[4:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[78:5], q1[1:0], i_a[2:0]} : {i_b[78:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[78:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[78:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd74:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[79:78], q1[1:0], i_a[75:0]} : {i_b[79:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[79:78], b1[1:0], i_b[75:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[79:76], q1[1:0], i_a[73:0]} : {i_b[79:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[79:76], b1[1:0], i_b[73:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[79:74], q1[1:0], i_a[71:0]} : {i_b[79:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[79:74], b1[1:0], i_b[71:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[79:72], q1[1:0], i_a[69:0]} : {i_b[79:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[79:72], b1[1:0], i_b[69:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[79:70], q1[1:0], i_a[67:0]} : {i_b[79:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[79:70], b1[1:0], i_b[67:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[79:68], q1[1:0], i_a[65:0]} : {i_b[79:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[79:68], b1[1:0], i_b[65:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[79:66], q1[1:0], i_a[63:0]} : {i_b[79:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[79:66], b1[1:0], i_b[63:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[79:64], q1[1:0], i_a[61:0]} : {i_b[79:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[79:64], b1[1:0], i_b[61:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[79:62], q1[1:0], i_a[59:0]} : {i_b[79:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[79:62], b1[1:0], i_b[59:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[79:60], q1[1:0], i_a[57:0]} : {i_b[79:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[79:60], b1[1:0], i_b[57:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[79:58], q1[1:0], i_a[55:0]} : {i_b[79:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[79:58], b1[1:0], i_b[55:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[79:56], q1[1:0], i_a[53:0]} : {i_b[79:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[79:56], b1[1:0], i_b[53:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[79:54], q1[1:0], i_a[51:0]} : {i_b[79:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[79:54], b1[1:0], i_b[51:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[79:52], q1[1:0], i_a[49:0]} : {i_b[79:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[79:52], b1[1:0], i_b[49:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[79:50], q1[1:0], i_a[47:0]} : {i_b[79:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[79:50], b1[1:0], i_b[47:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[79:48], q1[1:0], i_a[45:0]} : {i_b[79:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[79:48], b1[1:0], i_b[45:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[79:46], q1[1:0], i_a[43:0]} : {i_b[79:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[79:46], b1[1:0], i_b[43:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[79:44], q1[1:0], i_a[41:0]} : {i_b[79:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[79:44], b1[1:0], i_b[41:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[79:42], q1[1:0], i_a[39:0]} : {i_b[79:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[79:42], b1[1:0], i_b[39:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[79:40], q1[1:0], i_a[37:0]} : {i_b[79:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[79:40], b1[1:0], i_b[37:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[79:38], q1[1:0], i_a[35:0]} : {i_b[79:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[79:38], b1[1:0], i_b[35:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[79:36], q1[1:0], i_a[33:0]} : {i_b[79:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[79:36], b1[1:0], i_b[33:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[79:34], q1[1:0], i_a[31:0]} : {i_b[79:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[79:34], b1[1:0], i_b[31:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[79:32], q1[1:0], i_a[29:0]} : {i_b[79:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[79:32], b1[1:0], i_b[29:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[79:30], q1[1:0], i_a[27:0]} : {i_b[79:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[79:30], b1[1:0], i_b[27:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[79:28], q1[1:0], i_a[25:0]} : {i_b[79:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[79:28], b1[1:0], i_b[25:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[79:26], q1[1:0], i_a[23:0]} : {i_b[79:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[79:26], b1[1:0], i_b[23:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[79:24], q1[1:0], i_a[21:0]} : {i_b[79:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[79:24], b1[1:0], i_b[21:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[79:22], q1[1:0], i_a[19:0]} : {i_b[79:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[79:22], b1[1:0], i_b[19:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[79:20], q1[1:0], i_a[17:0]} : {i_b[79:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[79:20], b1[1:0], i_b[17:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[79:18], q1[1:0], i_a[15:0]} : {i_b[79:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[79:18], b1[1:0], i_b[15:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[79:16], q1[1:0], i_a[13:0]} : {i_b[79:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[79:16], b1[1:0], i_b[13:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[79:14], q1[1:0], i_a[11:0]} : {i_b[79:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[79:14], b1[1:0], i_b[11:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[79:12], q1[1:0], i_a[9:0]} : {i_b[79:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[79:12], b1[1:0], i_b[9:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[79:10], q1[1:0], i_a[7:0]} : {i_b[79:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[79:10], b1[1:0], i_b[7:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[79:8], q1[1:0], i_a[5:0]} : {i_b[79:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[79:8], b1[1:0], i_b[5:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[79:6], q1[1:0], i_a[3:0]} : {i_b[79:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[79:6], b1[1:0], i_b[3:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[79:4], q1[1:0], i_a[1:0]} : {i_b[79:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[79:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[79:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd75:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[80:79], q1[1:0], i_a[76:0]} : {i_b[80:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[80:79], b1[1:0], i_b[76:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[80:77], q1[1:0], i_a[74:0]} : {i_b[80:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[80:77], b1[1:0], i_b[74:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[80:75], q1[1:0], i_a[72:0]} : {i_b[80:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[80:75], b1[1:0], i_b[72:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[80:73], q1[1:0], i_a[70:0]} : {i_b[80:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[80:73], b1[1:0], i_b[70:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[80:71], q1[1:0], i_a[68:0]} : {i_b[80:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[80:71], b1[1:0], i_b[68:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[80:69], q1[1:0], i_a[66:0]} : {i_b[80:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[80:69], b1[1:0], i_b[66:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[80:67], q1[1:0], i_a[64:0]} : {i_b[80:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[80:67], b1[1:0], i_b[64:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[80:65], q1[1:0], i_a[62:0]} : {i_b[80:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[80:65], b1[1:0], i_b[62:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[80:63], q1[1:0], i_a[60:0]} : {i_b[80:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[80:63], b1[1:0], i_b[60:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[80:61], q1[1:0], i_a[58:0]} : {i_b[80:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[80:61], b1[1:0], i_b[58:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[80:59], q1[1:0], i_a[56:0]} : {i_b[80:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[80:59], b1[1:0], i_b[56:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[80:57], q1[1:0], i_a[54:0]} : {i_b[80:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[80:57], b1[1:0], i_b[54:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[80:55], q1[1:0], i_a[52:0]} : {i_b[80:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[80:55], b1[1:0], i_b[52:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[80:53], q1[1:0], i_a[50:0]} : {i_b[80:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[80:53], b1[1:0], i_b[50:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[80:51], q1[1:0], i_a[48:0]} : {i_b[80:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[80:51], b1[1:0], i_b[48:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[80:49], q1[1:0], i_a[46:0]} : {i_b[80:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[80:49], b1[1:0], i_b[46:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[80:47], q1[1:0], i_a[44:0]} : {i_b[80:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[80:47], b1[1:0], i_b[44:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[80:45], q1[1:0], i_a[42:0]} : {i_b[80:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[80:45], b1[1:0], i_b[42:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[80:43], q1[1:0], i_a[40:0]} : {i_b[80:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[80:43], b1[1:0], i_b[40:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[80:41], q1[1:0], i_a[38:0]} : {i_b[80:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[80:41], b1[1:0], i_b[38:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[80:39], q1[1:0], i_a[36:0]} : {i_b[80:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[80:39], b1[1:0], i_b[36:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[80:37], q1[1:0], i_a[34:0]} : {i_b[80:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[80:37], b1[1:0], i_b[34:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[80:35], q1[1:0], i_a[32:0]} : {i_b[80:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[80:35], b1[1:0], i_b[32:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[80:33], q1[1:0], i_a[30:0]} : {i_b[80:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[80:33], b1[1:0], i_b[30:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[80:31], q1[1:0], i_a[28:0]} : {i_b[80:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[80:31], b1[1:0], i_b[28:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[80:29], q1[1:0], i_a[26:0]} : {i_b[80:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[80:29], b1[1:0], i_b[26:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[80:27], q1[1:0], i_a[24:0]} : {i_b[80:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[80:27], b1[1:0], i_b[24:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[80:25], q1[1:0], i_a[22:0]} : {i_b[80:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[80:25], b1[1:0], i_b[22:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[80:23], q1[1:0], i_a[20:0]} : {i_b[80:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[80:23], b1[1:0], i_b[20:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[80:21], q1[1:0], i_a[18:0]} : {i_b[80:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[80:21], b1[1:0], i_b[18:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[80:19], q1[1:0], i_a[16:0]} : {i_b[80:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[80:19], b1[1:0], i_b[16:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[80:17], q1[1:0], i_a[14:0]} : {i_b[80:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[80:17], b1[1:0], i_b[14:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[80:15], q1[1:0], i_a[12:0]} : {i_b[80:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[80:15], b1[1:0], i_b[12:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[80:13], q1[1:0], i_a[10:0]} : {i_b[80:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[80:13], b1[1:0], i_b[10:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[80:11], q1[1:0], i_a[8:0]} : {i_b[80:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[80:11], b1[1:0], i_b[8:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[80:9], q1[1:0], i_a[6:0]} : {i_b[80:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[80:9], b1[1:0], i_b[6:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[80:7], q1[1:0], i_a[4:0]} : {i_b[80:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[80:7], b1[1:0], i_b[4:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[80:5], q1[1:0], i_a[2:0]} : {i_b[80:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[80:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[80:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd76:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[81:80], q1[1:0], i_a[77:0]} : {i_b[81:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[81:80], b1[1:0], i_b[77:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[81:78], q1[1:0], i_a[75:0]} : {i_b[81:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[81:78], b1[1:0], i_b[75:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[81:76], q1[1:0], i_a[73:0]} : {i_b[81:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[81:76], b1[1:0], i_b[73:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[81:74], q1[1:0], i_a[71:0]} : {i_b[81:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[81:74], b1[1:0], i_b[71:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[81:72], q1[1:0], i_a[69:0]} : {i_b[81:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[81:72], b1[1:0], i_b[69:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[81:70], q1[1:0], i_a[67:0]} : {i_b[81:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[81:70], b1[1:0], i_b[67:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[81:68], q1[1:0], i_a[65:0]} : {i_b[81:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[81:68], b1[1:0], i_b[65:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[81:66], q1[1:0], i_a[63:0]} : {i_b[81:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[81:66], b1[1:0], i_b[63:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[81:64], q1[1:0], i_a[61:0]} : {i_b[81:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[81:64], b1[1:0], i_b[61:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[81:62], q1[1:0], i_a[59:0]} : {i_b[81:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[81:62], b1[1:0], i_b[59:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[81:60], q1[1:0], i_a[57:0]} : {i_b[81:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[81:60], b1[1:0], i_b[57:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[81:58], q1[1:0], i_a[55:0]} : {i_b[81:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[81:58], b1[1:0], i_b[55:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[81:56], q1[1:0], i_a[53:0]} : {i_b[81:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[81:56], b1[1:0], i_b[53:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[81:54], q1[1:0], i_a[51:0]} : {i_b[81:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[81:54], b1[1:0], i_b[51:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[81:52], q1[1:0], i_a[49:0]} : {i_b[81:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[81:52], b1[1:0], i_b[49:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[81:50], q1[1:0], i_a[47:0]} : {i_b[81:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[81:50], b1[1:0], i_b[47:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[81:48], q1[1:0], i_a[45:0]} : {i_b[81:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[81:48], b1[1:0], i_b[45:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[81:46], q1[1:0], i_a[43:0]} : {i_b[81:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[81:46], b1[1:0], i_b[43:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[81:44], q1[1:0], i_a[41:0]} : {i_b[81:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[81:44], b1[1:0], i_b[41:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[81:42], q1[1:0], i_a[39:0]} : {i_b[81:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[81:42], b1[1:0], i_b[39:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[81:40], q1[1:0], i_a[37:0]} : {i_b[81:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[81:40], b1[1:0], i_b[37:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[81:38], q1[1:0], i_a[35:0]} : {i_b[81:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[81:38], b1[1:0], i_b[35:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[81:36], q1[1:0], i_a[33:0]} : {i_b[81:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[81:36], b1[1:0], i_b[33:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[81:34], q1[1:0], i_a[31:0]} : {i_b[81:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[81:34], b1[1:0], i_b[31:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[81:32], q1[1:0], i_a[29:0]} : {i_b[81:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[81:32], b1[1:0], i_b[29:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[81:30], q1[1:0], i_a[27:0]} : {i_b[81:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[81:30], b1[1:0], i_b[27:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[81:28], q1[1:0], i_a[25:0]} : {i_b[81:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[81:28], b1[1:0], i_b[25:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[81:26], q1[1:0], i_a[23:0]} : {i_b[81:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[81:26], b1[1:0], i_b[23:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[81:24], q1[1:0], i_a[21:0]} : {i_b[81:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[81:24], b1[1:0], i_b[21:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[81:22], q1[1:0], i_a[19:0]} : {i_b[81:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[81:22], b1[1:0], i_b[19:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[81:20], q1[1:0], i_a[17:0]} : {i_b[81:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[81:20], b1[1:0], i_b[17:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[81:18], q1[1:0], i_a[15:0]} : {i_b[81:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[81:18], b1[1:0], i_b[15:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[81:16], q1[1:0], i_a[13:0]} : {i_b[81:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[81:16], b1[1:0], i_b[13:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[81:14], q1[1:0], i_a[11:0]} : {i_b[81:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[81:14], b1[1:0], i_b[11:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[81:12], q1[1:0], i_a[9:0]} : {i_b[81:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[81:12], b1[1:0], i_b[9:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[81:10], q1[1:0], i_a[7:0]} : {i_b[81:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[81:10], b1[1:0], i_b[7:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[81:8], q1[1:0], i_a[5:0]} : {i_b[81:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[81:8], b1[1:0], i_b[5:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[81:6], q1[1:0], i_a[3:0]} : {i_b[81:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[81:6], b1[1:0], i_b[3:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[81:4], q1[1:0], i_a[1:0]} : {i_b[81:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[81:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[81:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd77:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[82:81], q1[1:0], i_a[78:0]} : {i_b[82:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[82:81], b1[1:0], i_b[78:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[82:79], q1[1:0], i_a[76:0]} : {i_b[82:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[82:79], b1[1:0], i_b[76:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[82:77], q1[1:0], i_a[74:0]} : {i_b[82:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[82:77], b1[1:0], i_b[74:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[82:75], q1[1:0], i_a[72:0]} : {i_b[82:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[82:75], b1[1:0], i_b[72:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[82:73], q1[1:0], i_a[70:0]} : {i_b[82:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[82:73], b1[1:0], i_b[70:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[82:71], q1[1:0], i_a[68:0]} : {i_b[82:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[82:71], b1[1:0], i_b[68:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[82:69], q1[1:0], i_a[66:0]} : {i_b[82:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[82:69], b1[1:0], i_b[66:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[82:67], q1[1:0], i_a[64:0]} : {i_b[82:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[82:67], b1[1:0], i_b[64:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[82:65], q1[1:0], i_a[62:0]} : {i_b[82:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[82:65], b1[1:0], i_b[62:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[82:63], q1[1:0], i_a[60:0]} : {i_b[82:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[82:63], b1[1:0], i_b[60:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[82:61], q1[1:0], i_a[58:0]} : {i_b[82:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[82:61], b1[1:0], i_b[58:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[82:59], q1[1:0], i_a[56:0]} : {i_b[82:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[82:59], b1[1:0], i_b[56:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[82:57], q1[1:0], i_a[54:0]} : {i_b[82:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[82:57], b1[1:0], i_b[54:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[82:55], q1[1:0], i_a[52:0]} : {i_b[82:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[82:55], b1[1:0], i_b[52:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[82:53], q1[1:0], i_a[50:0]} : {i_b[82:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[82:53], b1[1:0], i_b[50:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[82:51], q1[1:0], i_a[48:0]} : {i_b[82:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[82:51], b1[1:0], i_b[48:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[82:49], q1[1:0], i_a[46:0]} : {i_b[82:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[82:49], b1[1:0], i_b[46:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[82:47], q1[1:0], i_a[44:0]} : {i_b[82:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[82:47], b1[1:0], i_b[44:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[82:45], q1[1:0], i_a[42:0]} : {i_b[82:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[82:45], b1[1:0], i_b[42:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[82:43], q1[1:0], i_a[40:0]} : {i_b[82:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[82:43], b1[1:0], i_b[40:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[82:41], q1[1:0], i_a[38:0]} : {i_b[82:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[82:41], b1[1:0], i_b[38:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[82:39], q1[1:0], i_a[36:0]} : {i_b[82:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[82:39], b1[1:0], i_b[36:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[82:37], q1[1:0], i_a[34:0]} : {i_b[82:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[82:37], b1[1:0], i_b[34:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[82:35], q1[1:0], i_a[32:0]} : {i_b[82:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[82:35], b1[1:0], i_b[32:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[82:33], q1[1:0], i_a[30:0]} : {i_b[82:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[82:33], b1[1:0], i_b[30:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[82:31], q1[1:0], i_a[28:0]} : {i_b[82:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[82:31], b1[1:0], i_b[28:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[82:29], q1[1:0], i_a[26:0]} : {i_b[82:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[82:29], b1[1:0], i_b[26:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[82:27], q1[1:0], i_a[24:0]} : {i_b[82:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[82:27], b1[1:0], i_b[24:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[82:25], q1[1:0], i_a[22:0]} : {i_b[82:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[82:25], b1[1:0], i_b[22:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[82:23], q1[1:0], i_a[20:0]} : {i_b[82:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[82:23], b1[1:0], i_b[20:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[82:21], q1[1:0], i_a[18:0]} : {i_b[82:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[82:21], b1[1:0], i_b[18:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[82:19], q1[1:0], i_a[16:0]} : {i_b[82:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[82:19], b1[1:0], i_b[16:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[82:17], q1[1:0], i_a[14:0]} : {i_b[82:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[82:17], b1[1:0], i_b[14:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[82:15], q1[1:0], i_a[12:0]} : {i_b[82:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[82:15], b1[1:0], i_b[12:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[82:13], q1[1:0], i_a[10:0]} : {i_b[82:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[82:13], b1[1:0], i_b[10:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[82:11], q1[1:0], i_a[8:0]} : {i_b[82:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[82:11], b1[1:0], i_b[8:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[82:9], q1[1:0], i_a[6:0]} : {i_b[82:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[82:9], b1[1:0], i_b[6:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[82:7], q1[1:0], i_a[4:0]} : {i_b[82:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[82:7], b1[1:0], i_b[4:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[82:5], q1[1:0], i_a[2:0]} : {i_b[82:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[82:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[82:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd78:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[83:82], q1[1:0], i_a[79:0]} : {i_b[83:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[83:82], b1[1:0], i_b[79:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[83:80], q1[1:0], i_a[77:0]} : {i_b[83:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[83:80], b1[1:0], i_b[77:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[83:78], q1[1:0], i_a[75:0]} : {i_b[83:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[83:78], b1[1:0], i_b[75:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[83:76], q1[1:0], i_a[73:0]} : {i_b[83:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[83:76], b1[1:0], i_b[73:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[83:74], q1[1:0], i_a[71:0]} : {i_b[83:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[83:74], b1[1:0], i_b[71:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[83:72], q1[1:0], i_a[69:0]} : {i_b[83:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[83:72], b1[1:0], i_b[69:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[83:70], q1[1:0], i_a[67:0]} : {i_b[83:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[83:70], b1[1:0], i_b[67:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[83:68], q1[1:0], i_a[65:0]} : {i_b[83:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[83:68], b1[1:0], i_b[65:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[83:66], q1[1:0], i_a[63:0]} : {i_b[83:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[83:66], b1[1:0], i_b[63:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[83:64], q1[1:0], i_a[61:0]} : {i_b[83:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[83:64], b1[1:0], i_b[61:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[83:62], q1[1:0], i_a[59:0]} : {i_b[83:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[83:62], b1[1:0], i_b[59:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[83:60], q1[1:0], i_a[57:0]} : {i_b[83:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[83:60], b1[1:0], i_b[57:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[83:58], q1[1:0], i_a[55:0]} : {i_b[83:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[83:58], b1[1:0], i_b[55:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[83:56], q1[1:0], i_a[53:0]} : {i_b[83:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[83:56], b1[1:0], i_b[53:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[83:54], q1[1:0], i_a[51:0]} : {i_b[83:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[83:54], b1[1:0], i_b[51:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[83:52], q1[1:0], i_a[49:0]} : {i_b[83:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[83:52], b1[1:0], i_b[49:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[83:50], q1[1:0], i_a[47:0]} : {i_b[83:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[83:50], b1[1:0], i_b[47:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[83:48], q1[1:0], i_a[45:0]} : {i_b[83:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[83:48], b1[1:0], i_b[45:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[83:46], q1[1:0], i_a[43:0]} : {i_b[83:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[83:46], b1[1:0], i_b[43:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[83:44], q1[1:0], i_a[41:0]} : {i_b[83:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[83:44], b1[1:0], i_b[41:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[83:42], q1[1:0], i_a[39:0]} : {i_b[83:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[83:42], b1[1:0], i_b[39:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[83:40], q1[1:0], i_a[37:0]} : {i_b[83:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[83:40], b1[1:0], i_b[37:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[83:38], q1[1:0], i_a[35:0]} : {i_b[83:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[83:38], b1[1:0], i_b[35:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[83:36], q1[1:0], i_a[33:0]} : {i_b[83:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[83:36], b1[1:0], i_b[33:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[83:34], q1[1:0], i_a[31:0]} : {i_b[83:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[83:34], b1[1:0], i_b[31:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[83:32], q1[1:0], i_a[29:0]} : {i_b[83:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[83:32], b1[1:0], i_b[29:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[83:30], q1[1:0], i_a[27:0]} : {i_b[83:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[83:30], b1[1:0], i_b[27:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[83:28], q1[1:0], i_a[25:0]} : {i_b[83:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[83:28], b1[1:0], i_b[25:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[83:26], q1[1:0], i_a[23:0]} : {i_b[83:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[83:26], b1[1:0], i_b[23:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[83:24], q1[1:0], i_a[21:0]} : {i_b[83:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[83:24], b1[1:0], i_b[21:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[83:22], q1[1:0], i_a[19:0]} : {i_b[83:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[83:22], b1[1:0], i_b[19:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[83:20], q1[1:0], i_a[17:0]} : {i_b[83:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[83:20], b1[1:0], i_b[17:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[83:18], q1[1:0], i_a[15:0]} : {i_b[83:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[83:18], b1[1:0], i_b[15:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[83:16], q1[1:0], i_a[13:0]} : {i_b[83:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[83:16], b1[1:0], i_b[13:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[83:14], q1[1:0], i_a[11:0]} : {i_b[83:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[83:14], b1[1:0], i_b[11:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[83:12], q1[1:0], i_a[9:0]} : {i_b[83:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[83:12], b1[1:0], i_b[9:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[83:10], q1[1:0], i_a[7:0]} : {i_b[83:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[83:10], b1[1:0], i_b[7:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[83:8], q1[1:0], i_a[5:0]} : {i_b[83:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[83:8], b1[1:0], i_b[5:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[83:6], q1[1:0], i_a[3:0]} : {i_b[83:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[83:6], b1[1:0], i_b[3:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[83:4], q1[1:0], i_a[1:0]} : {i_b[83:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[83:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[83:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd79:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[84:83], q1[1:0], i_a[80:0]} : {i_b[84:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[84:83], b1[1:0], i_b[80:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[84:81], q1[1:0], i_a[78:0]} : {i_b[84:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[84:81], b1[1:0], i_b[78:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[84:79], q1[1:0], i_a[76:0]} : {i_b[84:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[84:79], b1[1:0], i_b[76:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[84:77], q1[1:0], i_a[74:0]} : {i_b[84:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[84:77], b1[1:0], i_b[74:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[84:75], q1[1:0], i_a[72:0]} : {i_b[84:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[84:75], b1[1:0], i_b[72:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[84:73], q1[1:0], i_a[70:0]} : {i_b[84:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[84:73], b1[1:0], i_b[70:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[84:71], q1[1:0], i_a[68:0]} : {i_b[84:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[84:71], b1[1:0], i_b[68:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[84:69], q1[1:0], i_a[66:0]} : {i_b[84:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[84:69], b1[1:0], i_b[66:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[84:67], q1[1:0], i_a[64:0]} : {i_b[84:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[84:67], b1[1:0], i_b[64:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[84:65], q1[1:0], i_a[62:0]} : {i_b[84:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[84:65], b1[1:0], i_b[62:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[84:63], q1[1:0], i_a[60:0]} : {i_b[84:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[84:63], b1[1:0], i_b[60:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[84:61], q1[1:0], i_a[58:0]} : {i_b[84:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[84:61], b1[1:0], i_b[58:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[84:59], q1[1:0], i_a[56:0]} : {i_b[84:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[84:59], b1[1:0], i_b[56:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[84:57], q1[1:0], i_a[54:0]} : {i_b[84:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[84:57], b1[1:0], i_b[54:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[84:55], q1[1:0], i_a[52:0]} : {i_b[84:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[84:55], b1[1:0], i_b[52:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[84:53], q1[1:0], i_a[50:0]} : {i_b[84:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[84:53], b1[1:0], i_b[50:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[84:51], q1[1:0], i_a[48:0]} : {i_b[84:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[84:51], b1[1:0], i_b[48:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[84:49], q1[1:0], i_a[46:0]} : {i_b[84:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[84:49], b1[1:0], i_b[46:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[84:47], q1[1:0], i_a[44:0]} : {i_b[84:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[84:47], b1[1:0], i_b[44:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[84:45], q1[1:0], i_a[42:0]} : {i_b[84:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[84:45], b1[1:0], i_b[42:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[84:43], q1[1:0], i_a[40:0]} : {i_b[84:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[84:43], b1[1:0], i_b[40:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[84:41], q1[1:0], i_a[38:0]} : {i_b[84:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[84:41], b1[1:0], i_b[38:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[84:39], q1[1:0], i_a[36:0]} : {i_b[84:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[84:39], b1[1:0], i_b[36:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[84:37], q1[1:0], i_a[34:0]} : {i_b[84:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[84:37], b1[1:0], i_b[34:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[84:35], q1[1:0], i_a[32:0]} : {i_b[84:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[84:35], b1[1:0], i_b[32:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[84:33], q1[1:0], i_a[30:0]} : {i_b[84:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[84:33], b1[1:0], i_b[30:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[84:31], q1[1:0], i_a[28:0]} : {i_b[84:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[84:31], b1[1:0], i_b[28:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[84:29], q1[1:0], i_a[26:0]} : {i_b[84:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[84:29], b1[1:0], i_b[26:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[84:27], q1[1:0], i_a[24:0]} : {i_b[84:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[84:27], b1[1:0], i_b[24:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[84:25], q1[1:0], i_a[22:0]} : {i_b[84:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[84:25], b1[1:0], i_b[22:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[84:23], q1[1:0], i_a[20:0]} : {i_b[84:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[84:23], b1[1:0], i_b[20:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[84:21], q1[1:0], i_a[18:0]} : {i_b[84:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[84:21], b1[1:0], i_b[18:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[84:19], q1[1:0], i_a[16:0]} : {i_b[84:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[84:19], b1[1:0], i_b[16:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[84:17], q1[1:0], i_a[14:0]} : {i_b[84:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[84:17], b1[1:0], i_b[14:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[84:15], q1[1:0], i_a[12:0]} : {i_b[84:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[84:15], b1[1:0], i_b[12:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[84:13], q1[1:0], i_a[10:0]} : {i_b[84:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[84:13], b1[1:0], i_b[10:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[84:11], q1[1:0], i_a[8:0]} : {i_b[84:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[84:11], b1[1:0], i_b[8:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[84:9], q1[1:0], i_a[6:0]} : {i_b[84:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[84:9], b1[1:0], i_b[6:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[84:7], q1[1:0], i_a[4:0]} : {i_b[84:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[84:7], b1[1:0], i_b[4:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[84:5], q1[1:0], i_a[2:0]} : {i_b[84:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[84:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[84:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd80:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[85:84], q1[1:0], i_a[81:0]} : {i_b[85:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[85:84], b1[1:0], i_b[81:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[85:82], q1[1:0], i_a[79:0]} : {i_b[85:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[85:82], b1[1:0], i_b[79:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[85:80], q1[1:0], i_a[77:0]} : {i_b[85:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[85:80], b1[1:0], i_b[77:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[85:78], q1[1:0], i_a[75:0]} : {i_b[85:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[85:78], b1[1:0], i_b[75:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[85:76], q1[1:0], i_a[73:0]} : {i_b[85:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[85:76], b1[1:0], i_b[73:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[85:74], q1[1:0], i_a[71:0]} : {i_b[85:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[85:74], b1[1:0], i_b[71:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[85:72], q1[1:0], i_a[69:0]} : {i_b[85:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[85:72], b1[1:0], i_b[69:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[85:70], q1[1:0], i_a[67:0]} : {i_b[85:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[85:70], b1[1:0], i_b[67:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[85:68], q1[1:0], i_a[65:0]} : {i_b[85:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[85:68], b1[1:0], i_b[65:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[85:66], q1[1:0], i_a[63:0]} : {i_b[85:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[85:66], b1[1:0], i_b[63:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[85:64], q1[1:0], i_a[61:0]} : {i_b[85:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[85:64], b1[1:0], i_b[61:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[85:62], q1[1:0], i_a[59:0]} : {i_b[85:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[85:62], b1[1:0], i_b[59:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[85:60], q1[1:0], i_a[57:0]} : {i_b[85:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[85:60], b1[1:0], i_b[57:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[85:58], q1[1:0], i_a[55:0]} : {i_b[85:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[85:58], b1[1:0], i_b[55:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[85:56], q1[1:0], i_a[53:0]} : {i_b[85:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[85:56], b1[1:0], i_b[53:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[85:54], q1[1:0], i_a[51:0]} : {i_b[85:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[85:54], b1[1:0], i_b[51:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[85:52], q1[1:0], i_a[49:0]} : {i_b[85:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[85:52], b1[1:0], i_b[49:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[85:50], q1[1:0], i_a[47:0]} : {i_b[85:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[85:50], b1[1:0], i_b[47:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[85:48], q1[1:0], i_a[45:0]} : {i_b[85:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[85:48], b1[1:0], i_b[45:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[85:46], q1[1:0], i_a[43:0]} : {i_b[85:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[85:46], b1[1:0], i_b[43:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[85:44], q1[1:0], i_a[41:0]} : {i_b[85:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[85:44], b1[1:0], i_b[41:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[85:42], q1[1:0], i_a[39:0]} : {i_b[85:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[85:42], b1[1:0], i_b[39:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[85:40], q1[1:0], i_a[37:0]} : {i_b[85:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[85:40], b1[1:0], i_b[37:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[85:38], q1[1:0], i_a[35:0]} : {i_b[85:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[85:38], b1[1:0], i_b[35:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[85:36], q1[1:0], i_a[33:0]} : {i_b[85:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[85:36], b1[1:0], i_b[33:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[85:34], q1[1:0], i_a[31:0]} : {i_b[85:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[85:34], b1[1:0], i_b[31:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[85:32], q1[1:0], i_a[29:0]} : {i_b[85:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[85:32], b1[1:0], i_b[29:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[85:30], q1[1:0], i_a[27:0]} : {i_b[85:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[85:30], b1[1:0], i_b[27:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[85:28], q1[1:0], i_a[25:0]} : {i_b[85:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[85:28], b1[1:0], i_b[25:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[85:26], q1[1:0], i_a[23:0]} : {i_b[85:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[85:26], b1[1:0], i_b[23:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[85:24], q1[1:0], i_a[21:0]} : {i_b[85:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[85:24], b1[1:0], i_b[21:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[85:22], q1[1:0], i_a[19:0]} : {i_b[85:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[85:22], b1[1:0], i_b[19:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[85:20], q1[1:0], i_a[17:0]} : {i_b[85:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[85:20], b1[1:0], i_b[17:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[85:18], q1[1:0], i_a[15:0]} : {i_b[85:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[85:18], b1[1:0], i_b[15:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[85:16], q1[1:0], i_a[13:0]} : {i_b[85:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[85:16], b1[1:0], i_b[13:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[85:14], q1[1:0], i_a[11:0]} : {i_b[85:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[85:14], b1[1:0], i_b[11:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[85:12], q1[1:0], i_a[9:0]} : {i_b[85:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[85:12], b1[1:0], i_b[9:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[85:10], q1[1:0], i_a[7:0]} : {i_b[85:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[85:10], b1[1:0], i_b[7:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[85:8], q1[1:0], i_a[5:0]} : {i_b[85:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[85:8], b1[1:0], i_b[5:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[85:6], q1[1:0], i_a[3:0]} : {i_b[85:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[85:6], b1[1:0], i_b[3:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[85:4], q1[1:0], i_a[1:0]} : {i_b[85:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[85:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[85:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd81:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[86:85], q1[1:0], i_a[82:0]} : {i_b[86:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[86:85], b1[1:0], i_b[82:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[86:83], q1[1:0], i_a[80:0]} : {i_b[86:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[86:83], b1[1:0], i_b[80:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[86:81], q1[1:0], i_a[78:0]} : {i_b[86:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[86:81], b1[1:0], i_b[78:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[86:79], q1[1:0], i_a[76:0]} : {i_b[86:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[86:79], b1[1:0], i_b[76:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[86:77], q1[1:0], i_a[74:0]} : {i_b[86:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[86:77], b1[1:0], i_b[74:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[86:75], q1[1:0], i_a[72:0]} : {i_b[86:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[86:75], b1[1:0], i_b[72:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[86:73], q1[1:0], i_a[70:0]} : {i_b[86:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[86:73], b1[1:0], i_b[70:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[86:71], q1[1:0], i_a[68:0]} : {i_b[86:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[86:71], b1[1:0], i_b[68:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[86:69], q1[1:0], i_a[66:0]} : {i_b[86:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[86:69], b1[1:0], i_b[66:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[86:67], q1[1:0], i_a[64:0]} : {i_b[86:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[86:67], b1[1:0], i_b[64:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[86:65], q1[1:0], i_a[62:0]} : {i_b[86:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[86:65], b1[1:0], i_b[62:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[86:63], q1[1:0], i_a[60:0]} : {i_b[86:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[86:63], b1[1:0], i_b[60:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[86:61], q1[1:0], i_a[58:0]} : {i_b[86:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[86:61], b1[1:0], i_b[58:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[86:59], q1[1:0], i_a[56:0]} : {i_b[86:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[86:59], b1[1:0], i_b[56:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[86:57], q1[1:0], i_a[54:0]} : {i_b[86:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[86:57], b1[1:0], i_b[54:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[86:55], q1[1:0], i_a[52:0]} : {i_b[86:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[86:55], b1[1:0], i_b[52:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[86:53], q1[1:0], i_a[50:0]} : {i_b[86:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[86:53], b1[1:0], i_b[50:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[86:51], q1[1:0], i_a[48:0]} : {i_b[86:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[86:51], b1[1:0], i_b[48:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[86:49], q1[1:0], i_a[46:0]} : {i_b[86:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[86:49], b1[1:0], i_b[46:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[86:47], q1[1:0], i_a[44:0]} : {i_b[86:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[86:47], b1[1:0], i_b[44:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[86:45], q1[1:0], i_a[42:0]} : {i_b[86:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[86:45], b1[1:0], i_b[42:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[86:43], q1[1:0], i_a[40:0]} : {i_b[86:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[86:43], b1[1:0], i_b[40:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[86:41], q1[1:0], i_a[38:0]} : {i_b[86:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[86:41], b1[1:0], i_b[38:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[86:39], q1[1:0], i_a[36:0]} : {i_b[86:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[86:39], b1[1:0], i_b[36:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[86:37], q1[1:0], i_a[34:0]} : {i_b[86:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[86:37], b1[1:0], i_b[34:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[86:35], q1[1:0], i_a[32:0]} : {i_b[86:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[86:35], b1[1:0], i_b[32:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[86:33], q1[1:0], i_a[30:0]} : {i_b[86:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[86:33], b1[1:0], i_b[30:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[86:31], q1[1:0], i_a[28:0]} : {i_b[86:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[86:31], b1[1:0], i_b[28:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[86:29], q1[1:0], i_a[26:0]} : {i_b[86:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[86:29], b1[1:0], i_b[26:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[86:27], q1[1:0], i_a[24:0]} : {i_b[86:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[86:27], b1[1:0], i_b[24:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[86:25], q1[1:0], i_a[22:0]} : {i_b[86:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[86:25], b1[1:0], i_b[22:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[86:23], q1[1:0], i_a[20:0]} : {i_b[86:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[86:23], b1[1:0], i_b[20:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[86:21], q1[1:0], i_a[18:0]} : {i_b[86:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[86:21], b1[1:0], i_b[18:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[86:19], q1[1:0], i_a[16:0]} : {i_b[86:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[86:19], b1[1:0], i_b[16:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[86:17], q1[1:0], i_a[14:0]} : {i_b[86:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[86:17], b1[1:0], i_b[14:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[86:15], q1[1:0], i_a[12:0]} : {i_b[86:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[86:15], b1[1:0], i_b[12:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[86:13], q1[1:0], i_a[10:0]} : {i_b[86:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[86:13], b1[1:0], i_b[10:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[86:11], q1[1:0], i_a[8:0]} : {i_b[86:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[86:11], b1[1:0], i_b[8:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[86:9], q1[1:0], i_a[6:0]} : {i_b[86:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[86:9], b1[1:0], i_b[6:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[86:7], q1[1:0], i_a[4:0]} : {i_b[86:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[86:7], b1[1:0], i_b[4:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[86:5], q1[1:0], i_a[2:0]} : {i_b[86:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[86:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[86:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd82:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[87:86], q1[1:0], i_a[83:0]} : {i_b[87:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[87:86], b1[1:0], i_b[83:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[87:84], q1[1:0], i_a[81:0]} : {i_b[87:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[87:84], b1[1:0], i_b[81:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[87:82], q1[1:0], i_a[79:0]} : {i_b[87:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[87:82], b1[1:0], i_b[79:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[87:80], q1[1:0], i_a[77:0]} : {i_b[87:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[87:80], b1[1:0], i_b[77:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[87:78], q1[1:0], i_a[75:0]} : {i_b[87:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[87:78], b1[1:0], i_b[75:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[87:76], q1[1:0], i_a[73:0]} : {i_b[87:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[87:76], b1[1:0], i_b[73:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[87:74], q1[1:0], i_a[71:0]} : {i_b[87:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[87:74], b1[1:0], i_b[71:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[87:72], q1[1:0], i_a[69:0]} : {i_b[87:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[87:72], b1[1:0], i_b[69:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[87:70], q1[1:0], i_a[67:0]} : {i_b[87:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[87:70], b1[1:0], i_b[67:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[87:68], q1[1:0], i_a[65:0]} : {i_b[87:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[87:68], b1[1:0], i_b[65:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[87:66], q1[1:0], i_a[63:0]} : {i_b[87:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[87:66], b1[1:0], i_b[63:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[87:64], q1[1:0], i_a[61:0]} : {i_b[87:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[87:64], b1[1:0], i_b[61:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[87:62], q1[1:0], i_a[59:0]} : {i_b[87:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[87:62], b1[1:0], i_b[59:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[87:60], q1[1:0], i_a[57:0]} : {i_b[87:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[87:60], b1[1:0], i_b[57:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[87:58], q1[1:0], i_a[55:0]} : {i_b[87:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[87:58], b1[1:0], i_b[55:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[87:56], q1[1:0], i_a[53:0]} : {i_b[87:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[87:56], b1[1:0], i_b[53:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[87:54], q1[1:0], i_a[51:0]} : {i_b[87:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[87:54], b1[1:0], i_b[51:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[87:52], q1[1:0], i_a[49:0]} : {i_b[87:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[87:52], b1[1:0], i_b[49:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[87:50], q1[1:0], i_a[47:0]} : {i_b[87:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[87:50], b1[1:0], i_b[47:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[87:48], q1[1:0], i_a[45:0]} : {i_b[87:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[87:48], b1[1:0], i_b[45:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[87:46], q1[1:0], i_a[43:0]} : {i_b[87:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[87:46], b1[1:0], i_b[43:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[87:44], q1[1:0], i_a[41:0]} : {i_b[87:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[87:44], b1[1:0], i_b[41:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[87:42], q1[1:0], i_a[39:0]} : {i_b[87:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[87:42], b1[1:0], i_b[39:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[87:40], q1[1:0], i_a[37:0]} : {i_b[87:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[87:40], b1[1:0], i_b[37:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[87:38], q1[1:0], i_a[35:0]} : {i_b[87:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[87:38], b1[1:0], i_b[35:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[87:36], q1[1:0], i_a[33:0]} : {i_b[87:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[87:36], b1[1:0], i_b[33:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[87:34], q1[1:0], i_a[31:0]} : {i_b[87:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[87:34], b1[1:0], i_b[31:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[87:32], q1[1:0], i_a[29:0]} : {i_b[87:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[87:32], b1[1:0], i_b[29:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[87:30], q1[1:0], i_a[27:0]} : {i_b[87:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[87:30], b1[1:0], i_b[27:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[87:28], q1[1:0], i_a[25:0]} : {i_b[87:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[87:28], b1[1:0], i_b[25:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[87:26], q1[1:0], i_a[23:0]} : {i_b[87:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[87:26], b1[1:0], i_b[23:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[87:24], q1[1:0], i_a[21:0]} : {i_b[87:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[87:24], b1[1:0], i_b[21:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[87:22], q1[1:0], i_a[19:0]} : {i_b[87:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[87:22], b1[1:0], i_b[19:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[87:20], q1[1:0], i_a[17:0]} : {i_b[87:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[87:20], b1[1:0], i_b[17:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[87:18], q1[1:0], i_a[15:0]} : {i_b[87:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[87:18], b1[1:0], i_b[15:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[87:16], q1[1:0], i_a[13:0]} : {i_b[87:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[87:16], b1[1:0], i_b[13:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[87:14], q1[1:0], i_a[11:0]} : {i_b[87:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[87:14], b1[1:0], i_b[11:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[87:12], q1[1:0], i_a[9:0]} : {i_b[87:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[87:12], b1[1:0], i_b[9:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[87:10], q1[1:0], i_a[7:0]} : {i_b[87:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[87:10], b1[1:0], i_b[7:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[87:8], q1[1:0], i_a[5:0]} : {i_b[87:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[87:8], b1[1:0], i_b[5:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[87:6], q1[1:0], i_a[3:0]} : {i_b[87:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[87:6], b1[1:0], i_b[3:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[87:4], q1[1:0], i_a[1:0]} : {i_b[87:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[87:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[87:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd83:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[88:87], q1[1:0], i_a[84:0]} : {i_b[88:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[88:87], b1[1:0], i_b[84:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[88:85], q1[1:0], i_a[82:0]} : {i_b[88:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[88:85], b1[1:0], i_b[82:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[88:83], q1[1:0], i_a[80:0]} : {i_b[88:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[88:83], b1[1:0], i_b[80:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[88:81], q1[1:0], i_a[78:0]} : {i_b[88:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[88:81], b1[1:0], i_b[78:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[88:79], q1[1:0], i_a[76:0]} : {i_b[88:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[88:79], b1[1:0], i_b[76:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[88:77], q1[1:0], i_a[74:0]} : {i_b[88:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[88:77], b1[1:0], i_b[74:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[88:75], q1[1:0], i_a[72:0]} : {i_b[88:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[88:75], b1[1:0], i_b[72:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[88:73], q1[1:0], i_a[70:0]} : {i_b[88:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[88:73], b1[1:0], i_b[70:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[88:71], q1[1:0], i_a[68:0]} : {i_b[88:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[88:71], b1[1:0], i_b[68:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[88:69], q1[1:0], i_a[66:0]} : {i_b[88:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[88:69], b1[1:0], i_b[66:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[88:67], q1[1:0], i_a[64:0]} : {i_b[88:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[88:67], b1[1:0], i_b[64:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[88:65], q1[1:0], i_a[62:0]} : {i_b[88:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[88:65], b1[1:0], i_b[62:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[88:63], q1[1:0], i_a[60:0]} : {i_b[88:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[88:63], b1[1:0], i_b[60:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[88:61], q1[1:0], i_a[58:0]} : {i_b[88:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[88:61], b1[1:0], i_b[58:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[88:59], q1[1:0], i_a[56:0]} : {i_b[88:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[88:59], b1[1:0], i_b[56:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[88:57], q1[1:0], i_a[54:0]} : {i_b[88:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[88:57], b1[1:0], i_b[54:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[88:55], q1[1:0], i_a[52:0]} : {i_b[88:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[88:55], b1[1:0], i_b[52:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[88:53], q1[1:0], i_a[50:0]} : {i_b[88:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[88:53], b1[1:0], i_b[50:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[88:51], q1[1:0], i_a[48:0]} : {i_b[88:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[88:51], b1[1:0], i_b[48:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[88:49], q1[1:0], i_a[46:0]} : {i_b[88:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[88:49], b1[1:0], i_b[46:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[88:47], q1[1:0], i_a[44:0]} : {i_b[88:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[88:47], b1[1:0], i_b[44:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[88:45], q1[1:0], i_a[42:0]} : {i_b[88:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[88:45], b1[1:0], i_b[42:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[88:43], q1[1:0], i_a[40:0]} : {i_b[88:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[88:43], b1[1:0], i_b[40:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[88:41], q1[1:0], i_a[38:0]} : {i_b[88:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[88:41], b1[1:0], i_b[38:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[88:39], q1[1:0], i_a[36:0]} : {i_b[88:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[88:39], b1[1:0], i_b[36:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[88:37], q1[1:0], i_a[34:0]} : {i_b[88:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[88:37], b1[1:0], i_b[34:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[88:35], q1[1:0], i_a[32:0]} : {i_b[88:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[88:35], b1[1:0], i_b[32:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[88:33], q1[1:0], i_a[30:0]} : {i_b[88:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[88:33], b1[1:0], i_b[30:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[88:31], q1[1:0], i_a[28:0]} : {i_b[88:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[88:31], b1[1:0], i_b[28:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[88:29], q1[1:0], i_a[26:0]} : {i_b[88:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[88:29], b1[1:0], i_b[26:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[88:27], q1[1:0], i_a[24:0]} : {i_b[88:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[88:27], b1[1:0], i_b[24:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[88:25], q1[1:0], i_a[22:0]} : {i_b[88:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[88:25], b1[1:0], i_b[22:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[88:23], q1[1:0], i_a[20:0]} : {i_b[88:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[88:23], b1[1:0], i_b[20:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[88:21], q1[1:0], i_a[18:0]} : {i_b[88:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[88:21], b1[1:0], i_b[18:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[88:19], q1[1:0], i_a[16:0]} : {i_b[88:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[88:19], b1[1:0], i_b[16:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[88:17], q1[1:0], i_a[14:0]} : {i_b[88:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[88:17], b1[1:0], i_b[14:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[88:15], q1[1:0], i_a[12:0]} : {i_b[88:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[88:15], b1[1:0], i_b[12:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[88:13], q1[1:0], i_a[10:0]} : {i_b[88:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[88:13], b1[1:0], i_b[10:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[88:11], q1[1:0], i_a[8:0]} : {i_b[88:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[88:11], b1[1:0], i_b[8:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[88:9], q1[1:0], i_a[6:0]} : {i_b[88:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[88:9], b1[1:0], i_b[6:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[88:7], q1[1:0], i_a[4:0]} : {i_b[88:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[88:7], b1[1:0], i_b[4:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[88:5], q1[1:0], i_a[2:0]} : {i_b[88:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[88:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[88:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd84:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[89:88], q1[1:0], i_a[85:0]} : {i_b[89:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[89:88], b1[1:0], i_b[85:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[89:86], q1[1:0], i_a[83:0]} : {i_b[89:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[89:86], b1[1:0], i_b[83:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[89:84], q1[1:0], i_a[81:0]} : {i_b[89:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[89:84], b1[1:0], i_b[81:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[89:82], q1[1:0], i_a[79:0]} : {i_b[89:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[89:82], b1[1:0], i_b[79:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[89:80], q1[1:0], i_a[77:0]} : {i_b[89:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[89:80], b1[1:0], i_b[77:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[89:78], q1[1:0], i_a[75:0]} : {i_b[89:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[89:78], b1[1:0], i_b[75:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[89:76], q1[1:0], i_a[73:0]} : {i_b[89:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[89:76], b1[1:0], i_b[73:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[89:74], q1[1:0], i_a[71:0]} : {i_b[89:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[89:74], b1[1:0], i_b[71:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[89:72], q1[1:0], i_a[69:0]} : {i_b[89:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[89:72], b1[1:0], i_b[69:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[89:70], q1[1:0], i_a[67:0]} : {i_b[89:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[89:70], b1[1:0], i_b[67:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[89:68], q1[1:0], i_a[65:0]} : {i_b[89:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[89:68], b1[1:0], i_b[65:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[89:66], q1[1:0], i_a[63:0]} : {i_b[89:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[89:66], b1[1:0], i_b[63:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[89:64], q1[1:0], i_a[61:0]} : {i_b[89:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[89:64], b1[1:0], i_b[61:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[89:62], q1[1:0], i_a[59:0]} : {i_b[89:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[89:62], b1[1:0], i_b[59:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[89:60], q1[1:0], i_a[57:0]} : {i_b[89:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[89:60], b1[1:0], i_b[57:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[89:58], q1[1:0], i_a[55:0]} : {i_b[89:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[89:58], b1[1:0], i_b[55:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[89:56], q1[1:0], i_a[53:0]} : {i_b[89:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[89:56], b1[1:0], i_b[53:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[89:54], q1[1:0], i_a[51:0]} : {i_b[89:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[89:54], b1[1:0], i_b[51:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[89:52], q1[1:0], i_a[49:0]} : {i_b[89:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[89:52], b1[1:0], i_b[49:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[89:50], q1[1:0], i_a[47:0]} : {i_b[89:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[89:50], b1[1:0], i_b[47:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[89:48], q1[1:0], i_a[45:0]} : {i_b[89:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[89:48], b1[1:0], i_b[45:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[89:46], q1[1:0], i_a[43:0]} : {i_b[89:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[89:46], b1[1:0], i_b[43:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[89:44], q1[1:0], i_a[41:0]} : {i_b[89:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[89:44], b1[1:0], i_b[41:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[89:42], q1[1:0], i_a[39:0]} : {i_b[89:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[89:42], b1[1:0], i_b[39:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[89:40], q1[1:0], i_a[37:0]} : {i_b[89:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[89:40], b1[1:0], i_b[37:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[89:38], q1[1:0], i_a[35:0]} : {i_b[89:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[89:38], b1[1:0], i_b[35:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[89:36], q1[1:0], i_a[33:0]} : {i_b[89:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[89:36], b1[1:0], i_b[33:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[89:34], q1[1:0], i_a[31:0]} : {i_b[89:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[89:34], b1[1:0], i_b[31:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[89:32], q1[1:0], i_a[29:0]} : {i_b[89:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[89:32], b1[1:0], i_b[29:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[89:30], q1[1:0], i_a[27:0]} : {i_b[89:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[89:30], b1[1:0], i_b[27:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[89:28], q1[1:0], i_a[25:0]} : {i_b[89:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[89:28], b1[1:0], i_b[25:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[89:26], q1[1:0], i_a[23:0]} : {i_b[89:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[89:26], b1[1:0], i_b[23:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[89:24], q1[1:0], i_a[21:0]} : {i_b[89:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[89:24], b1[1:0], i_b[21:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[89:22], q1[1:0], i_a[19:0]} : {i_b[89:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[89:22], b1[1:0], i_b[19:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[89:20], q1[1:0], i_a[17:0]} : {i_b[89:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[89:20], b1[1:0], i_b[17:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[89:18], q1[1:0], i_a[15:0]} : {i_b[89:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[89:18], b1[1:0], i_b[15:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[89:16], q1[1:0], i_a[13:0]} : {i_b[89:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[89:16], b1[1:0], i_b[13:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[89:14], q1[1:0], i_a[11:0]} : {i_b[89:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[89:14], b1[1:0], i_b[11:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[89:12], q1[1:0], i_a[9:0]} : {i_b[89:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[89:12], b1[1:0], i_b[9:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[89:10], q1[1:0], i_a[7:0]} : {i_b[89:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[89:10], b1[1:0], i_b[7:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[89:8], q1[1:0], i_a[5:0]} : {i_b[89:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[89:8], b1[1:0], i_b[5:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[89:6], q1[1:0], i_a[3:0]} : {i_b[89:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[89:6], b1[1:0], i_b[3:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[89:4], q1[1:0], i_a[1:0]} : {i_b[89:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[89:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[89:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd85:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[90:89], q1[1:0], i_a[86:0]} : {i_b[90:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[90:89], b1[1:0], i_b[86:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[90:87], q1[1:0], i_a[84:0]} : {i_b[90:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[90:87], b1[1:0], i_b[84:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[90:85], q1[1:0], i_a[82:0]} : {i_b[90:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[90:85], b1[1:0], i_b[82:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[90:83], q1[1:0], i_a[80:0]} : {i_b[90:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[90:83], b1[1:0], i_b[80:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[90:81], q1[1:0], i_a[78:0]} : {i_b[90:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[90:81], b1[1:0], i_b[78:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[90:79], q1[1:0], i_a[76:0]} : {i_b[90:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[90:79], b1[1:0], i_b[76:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[90:77], q1[1:0], i_a[74:0]} : {i_b[90:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[90:77], b1[1:0], i_b[74:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[90:75], q1[1:0], i_a[72:0]} : {i_b[90:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[90:75], b1[1:0], i_b[72:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[90:73], q1[1:0], i_a[70:0]} : {i_b[90:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[90:73], b1[1:0], i_b[70:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[90:71], q1[1:0], i_a[68:0]} : {i_b[90:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[90:71], b1[1:0], i_b[68:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[90:69], q1[1:0], i_a[66:0]} : {i_b[90:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[90:69], b1[1:0], i_b[66:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[90:67], q1[1:0], i_a[64:0]} : {i_b[90:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[90:67], b1[1:0], i_b[64:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[90:65], q1[1:0], i_a[62:0]} : {i_b[90:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[90:65], b1[1:0], i_b[62:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[90:63], q1[1:0], i_a[60:0]} : {i_b[90:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[90:63], b1[1:0], i_b[60:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[90:61], q1[1:0], i_a[58:0]} : {i_b[90:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[90:61], b1[1:0], i_b[58:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[90:59], q1[1:0], i_a[56:0]} : {i_b[90:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[90:59], b1[1:0], i_b[56:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[90:57], q1[1:0], i_a[54:0]} : {i_b[90:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[90:57], b1[1:0], i_b[54:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[90:55], q1[1:0], i_a[52:0]} : {i_b[90:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[90:55], b1[1:0], i_b[52:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[90:53], q1[1:0], i_a[50:0]} : {i_b[90:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[90:53], b1[1:0], i_b[50:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[90:51], q1[1:0], i_a[48:0]} : {i_b[90:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[90:51], b1[1:0], i_b[48:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[90:49], q1[1:0], i_a[46:0]} : {i_b[90:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[90:49], b1[1:0], i_b[46:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[90:47], q1[1:0], i_a[44:0]} : {i_b[90:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[90:47], b1[1:0], i_b[44:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[90:45], q1[1:0], i_a[42:0]} : {i_b[90:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[90:45], b1[1:0], i_b[42:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[90:43], q1[1:0], i_a[40:0]} : {i_b[90:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[90:43], b1[1:0], i_b[40:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[90:41], q1[1:0], i_a[38:0]} : {i_b[90:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[90:41], b1[1:0], i_b[38:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[90:39], q1[1:0], i_a[36:0]} : {i_b[90:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[90:39], b1[1:0], i_b[36:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[90:37], q1[1:0], i_a[34:0]} : {i_b[90:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[90:37], b1[1:0], i_b[34:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[90:35], q1[1:0], i_a[32:0]} : {i_b[90:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[90:35], b1[1:0], i_b[32:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[90:33], q1[1:0], i_a[30:0]} : {i_b[90:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[90:33], b1[1:0], i_b[30:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[90:31], q1[1:0], i_a[28:0]} : {i_b[90:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[90:31], b1[1:0], i_b[28:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[90:29], q1[1:0], i_a[26:0]} : {i_b[90:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[90:29], b1[1:0], i_b[26:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[90:27], q1[1:0], i_a[24:0]} : {i_b[90:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[90:27], b1[1:0], i_b[24:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[90:25], q1[1:0], i_a[22:0]} : {i_b[90:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[90:25], b1[1:0], i_b[22:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[90:23], q1[1:0], i_a[20:0]} : {i_b[90:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[90:23], b1[1:0], i_b[20:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[90:21], q1[1:0], i_a[18:0]} : {i_b[90:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[90:21], b1[1:0], i_b[18:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[90:19], q1[1:0], i_a[16:0]} : {i_b[90:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[90:19], b1[1:0], i_b[16:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[90:17], q1[1:0], i_a[14:0]} : {i_b[90:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[90:17], b1[1:0], i_b[14:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[90:15], q1[1:0], i_a[12:0]} : {i_b[90:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[90:15], b1[1:0], i_b[12:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[90:13], q1[1:0], i_a[10:0]} : {i_b[90:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[90:13], b1[1:0], i_b[10:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[90:11], q1[1:0], i_a[8:0]} : {i_b[90:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[90:11], b1[1:0], i_b[8:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[90:9], q1[1:0], i_a[6:0]} : {i_b[90:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[90:9], b1[1:0], i_b[6:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[90:7], q1[1:0], i_a[4:0]} : {i_b[90:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[90:7], b1[1:0], i_b[4:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[90:5], q1[1:0], i_a[2:0]} : {i_b[90:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[90:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[90:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd86:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[91:90], q1[1:0], i_a[87:0]} : {i_b[91:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[91:90], b1[1:0], i_b[87:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[91:88], q1[1:0], i_a[85:0]} : {i_b[91:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[91:88], b1[1:0], i_b[85:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[91:86], q1[1:0], i_a[83:0]} : {i_b[91:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[91:86], b1[1:0], i_b[83:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[91:84], q1[1:0], i_a[81:0]} : {i_b[91:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[91:84], b1[1:0], i_b[81:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[91:82], q1[1:0], i_a[79:0]} : {i_b[91:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[91:82], b1[1:0], i_b[79:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[91:80], q1[1:0], i_a[77:0]} : {i_b[91:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[91:80], b1[1:0], i_b[77:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[91:78], q1[1:0], i_a[75:0]} : {i_b[91:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[91:78], b1[1:0], i_b[75:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[91:76], q1[1:0], i_a[73:0]} : {i_b[91:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[91:76], b1[1:0], i_b[73:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[91:74], q1[1:0], i_a[71:0]} : {i_b[91:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[91:74], b1[1:0], i_b[71:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[91:72], q1[1:0], i_a[69:0]} : {i_b[91:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[91:72], b1[1:0], i_b[69:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[91:70], q1[1:0], i_a[67:0]} : {i_b[91:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[91:70], b1[1:0], i_b[67:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[91:68], q1[1:0], i_a[65:0]} : {i_b[91:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[91:68], b1[1:0], i_b[65:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[91:66], q1[1:0], i_a[63:0]} : {i_b[91:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[91:66], b1[1:0], i_b[63:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[91:64], q1[1:0], i_a[61:0]} : {i_b[91:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[91:64], b1[1:0], i_b[61:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[91:62], q1[1:0], i_a[59:0]} : {i_b[91:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[91:62], b1[1:0], i_b[59:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[91:60], q1[1:0], i_a[57:0]} : {i_b[91:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[91:60], b1[1:0], i_b[57:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[91:58], q1[1:0], i_a[55:0]} : {i_b[91:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[91:58], b1[1:0], i_b[55:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[91:56], q1[1:0], i_a[53:0]} : {i_b[91:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[91:56], b1[1:0], i_b[53:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[91:54], q1[1:0], i_a[51:0]} : {i_b[91:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[91:54], b1[1:0], i_b[51:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[91:52], q1[1:0], i_a[49:0]} : {i_b[91:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[91:52], b1[1:0], i_b[49:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[91:50], q1[1:0], i_a[47:0]} : {i_b[91:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[91:50], b1[1:0], i_b[47:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[91:48], q1[1:0], i_a[45:0]} : {i_b[91:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[91:48], b1[1:0], i_b[45:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[91:46], q1[1:0], i_a[43:0]} : {i_b[91:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[91:46], b1[1:0], i_b[43:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[91:44], q1[1:0], i_a[41:0]} : {i_b[91:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[91:44], b1[1:0], i_b[41:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[91:42], q1[1:0], i_a[39:0]} : {i_b[91:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[91:42], b1[1:0], i_b[39:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[91:40], q1[1:0], i_a[37:0]} : {i_b[91:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[91:40], b1[1:0], i_b[37:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[91:38], q1[1:0], i_a[35:0]} : {i_b[91:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[91:38], b1[1:0], i_b[35:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[91:36], q1[1:0], i_a[33:0]} : {i_b[91:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[91:36], b1[1:0], i_b[33:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[91:34], q1[1:0], i_a[31:0]} : {i_b[91:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[91:34], b1[1:0], i_b[31:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[91:32], q1[1:0], i_a[29:0]} : {i_b[91:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[91:32], b1[1:0], i_b[29:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[91:30], q1[1:0], i_a[27:0]} : {i_b[91:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[91:30], b1[1:0], i_b[27:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[91:28], q1[1:0], i_a[25:0]} : {i_b[91:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[91:28], b1[1:0], i_b[25:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[91:26], q1[1:0], i_a[23:0]} : {i_b[91:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[91:26], b1[1:0], i_b[23:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[91:24], q1[1:0], i_a[21:0]} : {i_b[91:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[91:24], b1[1:0], i_b[21:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[91:22], q1[1:0], i_a[19:0]} : {i_b[91:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[91:22], b1[1:0], i_b[19:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[91:20], q1[1:0], i_a[17:0]} : {i_b[91:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[91:20], b1[1:0], i_b[17:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[91:18], q1[1:0], i_a[15:0]} : {i_b[91:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[91:18], b1[1:0], i_b[15:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[91:16], q1[1:0], i_a[13:0]} : {i_b[91:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[91:16], b1[1:0], i_b[13:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[91:14], q1[1:0], i_a[11:0]} : {i_b[91:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[91:14], b1[1:0], i_b[11:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[91:12], q1[1:0], i_a[9:0]} : {i_b[91:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[91:12], b1[1:0], i_b[9:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[91:10], q1[1:0], i_a[7:0]} : {i_b[91:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[91:10], b1[1:0], i_b[7:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[91:8], q1[1:0], i_a[5:0]} : {i_b[91:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[91:8], b1[1:0], i_b[5:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[91:6], q1[1:0], i_a[3:0]} : {i_b[91:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[91:6], b1[1:0], i_b[3:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[91:4], q1[1:0], i_a[1:0]} : {i_b[91:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[91:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[91:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd87:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[92:91], q1[1:0], i_a[88:0]} : {i_b[92:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[92:91], b1[1:0], i_b[88:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[92:89], q1[1:0], i_a[86:0]} : {i_b[92:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[92:89], b1[1:0], i_b[86:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[92:87], q1[1:0], i_a[84:0]} : {i_b[92:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[92:87], b1[1:0], i_b[84:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[92:85], q1[1:0], i_a[82:0]} : {i_b[92:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[92:85], b1[1:0], i_b[82:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[92:83], q1[1:0], i_a[80:0]} : {i_b[92:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[92:83], b1[1:0], i_b[80:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[92:81], q1[1:0], i_a[78:0]} : {i_b[92:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[92:81], b1[1:0], i_b[78:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[92:79], q1[1:0], i_a[76:0]} : {i_b[92:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[92:79], b1[1:0], i_b[76:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[92:77], q1[1:0], i_a[74:0]} : {i_b[92:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[92:77], b1[1:0], i_b[74:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[92:75], q1[1:0], i_a[72:0]} : {i_b[92:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[92:75], b1[1:0], i_b[72:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[92:73], q1[1:0], i_a[70:0]} : {i_b[92:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[92:73], b1[1:0], i_b[70:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[92:71], q1[1:0], i_a[68:0]} : {i_b[92:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[92:71], b1[1:0], i_b[68:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[92:69], q1[1:0], i_a[66:0]} : {i_b[92:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[92:69], b1[1:0], i_b[66:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[92:67], q1[1:0], i_a[64:0]} : {i_b[92:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[92:67], b1[1:0], i_b[64:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[92:65], q1[1:0], i_a[62:0]} : {i_b[92:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[92:65], b1[1:0], i_b[62:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[92:63], q1[1:0], i_a[60:0]} : {i_b[92:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[92:63], b1[1:0], i_b[60:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[92:61], q1[1:0], i_a[58:0]} : {i_b[92:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[92:61], b1[1:0], i_b[58:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[92:59], q1[1:0], i_a[56:0]} : {i_b[92:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[92:59], b1[1:0], i_b[56:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[92:57], q1[1:0], i_a[54:0]} : {i_b[92:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[92:57], b1[1:0], i_b[54:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[92:55], q1[1:0], i_a[52:0]} : {i_b[92:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[92:55], b1[1:0], i_b[52:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[92:53], q1[1:0], i_a[50:0]} : {i_b[92:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[92:53], b1[1:0], i_b[50:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[92:51], q1[1:0], i_a[48:0]} : {i_b[92:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[92:51], b1[1:0], i_b[48:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[92:49], q1[1:0], i_a[46:0]} : {i_b[92:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[92:49], b1[1:0], i_b[46:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[92:47], q1[1:0], i_a[44:0]} : {i_b[92:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[92:47], b1[1:0], i_b[44:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[92:45], q1[1:0], i_a[42:0]} : {i_b[92:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[92:45], b1[1:0], i_b[42:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[92:43], q1[1:0], i_a[40:0]} : {i_b[92:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[92:43], b1[1:0], i_b[40:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[92:41], q1[1:0], i_a[38:0]} : {i_b[92:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[92:41], b1[1:0], i_b[38:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[92:39], q1[1:0], i_a[36:0]} : {i_b[92:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[92:39], b1[1:0], i_b[36:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[92:37], q1[1:0], i_a[34:0]} : {i_b[92:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[92:37], b1[1:0], i_b[34:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[92:35], q1[1:0], i_a[32:0]} : {i_b[92:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[92:35], b1[1:0], i_b[32:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[92:33], q1[1:0], i_a[30:0]} : {i_b[92:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[92:33], b1[1:0], i_b[30:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[92:31], q1[1:0], i_a[28:0]} : {i_b[92:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[92:31], b1[1:0], i_b[28:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[92:29], q1[1:0], i_a[26:0]} : {i_b[92:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[92:29], b1[1:0], i_b[26:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[92:27], q1[1:0], i_a[24:0]} : {i_b[92:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[92:27], b1[1:0], i_b[24:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[92:25], q1[1:0], i_a[22:0]} : {i_b[92:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[92:25], b1[1:0], i_b[22:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[92:23], q1[1:0], i_a[20:0]} : {i_b[92:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[92:23], b1[1:0], i_b[20:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[92:21], q1[1:0], i_a[18:0]} : {i_b[92:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[92:21], b1[1:0], i_b[18:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[92:19], q1[1:0], i_a[16:0]} : {i_b[92:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[92:19], b1[1:0], i_b[16:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[92:17], q1[1:0], i_a[14:0]} : {i_b[92:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[92:17], b1[1:0], i_b[14:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[92:15], q1[1:0], i_a[12:0]} : {i_b[92:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[92:15], b1[1:0], i_b[12:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[92:13], q1[1:0], i_a[10:0]} : {i_b[92:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[92:13], b1[1:0], i_b[10:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[92:11], q1[1:0], i_a[8:0]} : {i_b[92:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[92:11], b1[1:0], i_b[8:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[92:9], q1[1:0], i_a[6:0]} : {i_b[92:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[92:9], b1[1:0], i_b[6:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[92:7], q1[1:0], i_a[4:0]} : {i_b[92:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[92:7], b1[1:0], i_b[4:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[92:5], q1[1:0], i_a[2:0]} : {i_b[92:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[92:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[92:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd88:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[93:92], q1[1:0], i_a[89:0]} : {i_b[93:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[93:92], b1[1:0], i_b[89:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[93:90], q1[1:0], i_a[87:0]} : {i_b[93:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[93:90], b1[1:0], i_b[87:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[93:88], q1[1:0], i_a[85:0]} : {i_b[93:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[93:88], b1[1:0], i_b[85:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[93:86], q1[1:0], i_a[83:0]} : {i_b[93:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[93:86], b1[1:0], i_b[83:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[93:84], q1[1:0], i_a[81:0]} : {i_b[93:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[93:84], b1[1:0], i_b[81:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[93:82], q1[1:0], i_a[79:0]} : {i_b[93:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[93:82], b1[1:0], i_b[79:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[93:80], q1[1:0], i_a[77:0]} : {i_b[93:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[93:80], b1[1:0], i_b[77:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[93:78], q1[1:0], i_a[75:0]} : {i_b[93:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[93:78], b1[1:0], i_b[75:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[93:76], q1[1:0], i_a[73:0]} : {i_b[93:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[93:76], b1[1:0], i_b[73:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[93:74], q1[1:0], i_a[71:0]} : {i_b[93:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[93:74], b1[1:0], i_b[71:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[93:72], q1[1:0], i_a[69:0]} : {i_b[93:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[93:72], b1[1:0], i_b[69:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[93:70], q1[1:0], i_a[67:0]} : {i_b[93:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[93:70], b1[1:0], i_b[67:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[93:68], q1[1:0], i_a[65:0]} : {i_b[93:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[93:68], b1[1:0], i_b[65:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[93:66], q1[1:0], i_a[63:0]} : {i_b[93:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[93:66], b1[1:0], i_b[63:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[93:64], q1[1:0], i_a[61:0]} : {i_b[93:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[93:64], b1[1:0], i_b[61:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[93:62], q1[1:0], i_a[59:0]} : {i_b[93:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[93:62], b1[1:0], i_b[59:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[93:60], q1[1:0], i_a[57:0]} : {i_b[93:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[93:60], b1[1:0], i_b[57:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[93:58], q1[1:0], i_a[55:0]} : {i_b[93:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[93:58], b1[1:0], i_b[55:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[93:56], q1[1:0], i_a[53:0]} : {i_b[93:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[93:56], b1[1:0], i_b[53:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[93:54], q1[1:0], i_a[51:0]} : {i_b[93:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[93:54], b1[1:0], i_b[51:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[93:52], q1[1:0], i_a[49:0]} : {i_b[93:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[93:52], b1[1:0], i_b[49:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[93:50], q1[1:0], i_a[47:0]} : {i_b[93:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[93:50], b1[1:0], i_b[47:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[93:48], q1[1:0], i_a[45:0]} : {i_b[93:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[93:48], b1[1:0], i_b[45:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[93:46], q1[1:0], i_a[43:0]} : {i_b[93:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[93:46], b1[1:0], i_b[43:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[93:44], q1[1:0], i_a[41:0]} : {i_b[93:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[93:44], b1[1:0], i_b[41:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[93:42], q1[1:0], i_a[39:0]} : {i_b[93:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[93:42], b1[1:0], i_b[39:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[93:40], q1[1:0], i_a[37:0]} : {i_b[93:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[93:40], b1[1:0], i_b[37:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[93:38], q1[1:0], i_a[35:0]} : {i_b[93:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[93:38], b1[1:0], i_b[35:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[93:36], q1[1:0], i_a[33:0]} : {i_b[93:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[93:36], b1[1:0], i_b[33:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[93:34], q1[1:0], i_a[31:0]} : {i_b[93:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[93:34], b1[1:0], i_b[31:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[93:32], q1[1:0], i_a[29:0]} : {i_b[93:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[93:32], b1[1:0], i_b[29:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[93:30], q1[1:0], i_a[27:0]} : {i_b[93:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[93:30], b1[1:0], i_b[27:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[93:28], q1[1:0], i_a[25:0]} : {i_b[93:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[93:28], b1[1:0], i_b[25:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[93:26], q1[1:0], i_a[23:0]} : {i_b[93:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[93:26], b1[1:0], i_b[23:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[93:24], q1[1:0], i_a[21:0]} : {i_b[93:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[93:24], b1[1:0], i_b[21:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[93:22], q1[1:0], i_a[19:0]} : {i_b[93:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[93:22], b1[1:0], i_b[19:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[93:20], q1[1:0], i_a[17:0]} : {i_b[93:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[93:20], b1[1:0], i_b[17:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[93:18], q1[1:0], i_a[15:0]} : {i_b[93:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[93:18], b1[1:0], i_b[15:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[93:16], q1[1:0], i_a[13:0]} : {i_b[93:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[93:16], b1[1:0], i_b[13:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[93:14], q1[1:0], i_a[11:0]} : {i_b[93:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[93:14], b1[1:0], i_b[11:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[93:12], q1[1:0], i_a[9:0]} : {i_b[93:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[93:12], b1[1:0], i_b[9:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[93:10], q1[1:0], i_a[7:0]} : {i_b[93:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[93:10], b1[1:0], i_b[7:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[93:8], q1[1:0], i_a[5:0]} : {i_b[93:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[93:8], b1[1:0], i_b[5:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[93:6], q1[1:0], i_a[3:0]} : {i_b[93:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[93:6], b1[1:0], i_b[3:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[93:4], q1[1:0], i_a[1:0]} : {i_b[93:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[93:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[93:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd89:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[94:93], q1[1:0], i_a[90:0]} : {i_b[94:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[94:93], b1[1:0], i_b[90:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[94:91], q1[1:0], i_a[88:0]} : {i_b[94:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[94:91], b1[1:0], i_b[88:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[94:89], q1[1:0], i_a[86:0]} : {i_b[94:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[94:89], b1[1:0], i_b[86:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[94:87], q1[1:0], i_a[84:0]} : {i_b[94:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[94:87], b1[1:0], i_b[84:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[94:85], q1[1:0], i_a[82:0]} : {i_b[94:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[94:85], b1[1:0], i_b[82:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[94:83], q1[1:0], i_a[80:0]} : {i_b[94:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[94:83], b1[1:0], i_b[80:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[94:81], q1[1:0], i_a[78:0]} : {i_b[94:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[94:81], b1[1:0], i_b[78:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[94:79], q1[1:0], i_a[76:0]} : {i_b[94:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[94:79], b1[1:0], i_b[76:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[94:77], q1[1:0], i_a[74:0]} : {i_b[94:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[94:77], b1[1:0], i_b[74:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[94:75], q1[1:0], i_a[72:0]} : {i_b[94:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[94:75], b1[1:0], i_b[72:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[94:73], q1[1:0], i_a[70:0]} : {i_b[94:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[94:73], b1[1:0], i_b[70:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[94:71], q1[1:0], i_a[68:0]} : {i_b[94:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[94:71], b1[1:0], i_b[68:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[94:69], q1[1:0], i_a[66:0]} : {i_b[94:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[94:69], b1[1:0], i_b[66:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[94:67], q1[1:0], i_a[64:0]} : {i_b[94:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[94:67], b1[1:0], i_b[64:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[94:65], q1[1:0], i_a[62:0]} : {i_b[94:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[94:65], b1[1:0], i_b[62:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[94:63], q1[1:0], i_a[60:0]} : {i_b[94:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[94:63], b1[1:0], i_b[60:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[94:61], q1[1:0], i_a[58:0]} : {i_b[94:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[94:61], b1[1:0], i_b[58:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[94:59], q1[1:0], i_a[56:0]} : {i_b[94:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[94:59], b1[1:0], i_b[56:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[94:57], q1[1:0], i_a[54:0]} : {i_b[94:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[94:57], b1[1:0], i_b[54:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[94:55], q1[1:0], i_a[52:0]} : {i_b[94:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[94:55], b1[1:0], i_b[52:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[94:53], q1[1:0], i_a[50:0]} : {i_b[94:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[94:53], b1[1:0], i_b[50:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[94:51], q1[1:0], i_a[48:0]} : {i_b[94:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[94:51], b1[1:0], i_b[48:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[94:49], q1[1:0], i_a[46:0]} : {i_b[94:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[94:49], b1[1:0], i_b[46:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[94:47], q1[1:0], i_a[44:0]} : {i_b[94:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[94:47], b1[1:0], i_b[44:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[94:45], q1[1:0], i_a[42:0]} : {i_b[94:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[94:45], b1[1:0], i_b[42:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[94:43], q1[1:0], i_a[40:0]} : {i_b[94:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[94:43], b1[1:0], i_b[40:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[94:41], q1[1:0], i_a[38:0]} : {i_b[94:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[94:41], b1[1:0], i_b[38:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[94:39], q1[1:0], i_a[36:0]} : {i_b[94:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[94:39], b1[1:0], i_b[36:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[94:37], q1[1:0], i_a[34:0]} : {i_b[94:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[94:37], b1[1:0], i_b[34:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[94:35], q1[1:0], i_a[32:0]} : {i_b[94:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[94:35], b1[1:0], i_b[32:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[94:33], q1[1:0], i_a[30:0]} : {i_b[94:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[94:33], b1[1:0], i_b[30:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[94:31], q1[1:0], i_a[28:0]} : {i_b[94:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[94:31], b1[1:0], i_b[28:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[94:29], q1[1:0], i_a[26:0]} : {i_b[94:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[94:29], b1[1:0], i_b[26:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[94:27], q1[1:0], i_a[24:0]} : {i_b[94:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[94:27], b1[1:0], i_b[24:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[94:25], q1[1:0], i_a[22:0]} : {i_b[94:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[94:25], b1[1:0], i_b[22:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[94:23], q1[1:0], i_a[20:0]} : {i_b[94:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[94:23], b1[1:0], i_b[20:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[94:21], q1[1:0], i_a[18:0]} : {i_b[94:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[94:21], b1[1:0], i_b[18:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[94:19], q1[1:0], i_a[16:0]} : {i_b[94:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[94:19], b1[1:0], i_b[16:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[94:17], q1[1:0], i_a[14:0]} : {i_b[94:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[94:17], b1[1:0], i_b[14:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[94:15], q1[1:0], i_a[12:0]} : {i_b[94:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[94:15], b1[1:0], i_b[12:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[94:13], q1[1:0], i_a[10:0]} : {i_b[94:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[94:13], b1[1:0], i_b[10:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[94:11], q1[1:0], i_a[8:0]} : {i_b[94:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[94:11], b1[1:0], i_b[8:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[94:9], q1[1:0], i_a[6:0]} : {i_b[94:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[94:9], b1[1:0], i_b[6:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[94:7], q1[1:0], i_a[4:0]} : {i_b[94:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[94:7], b1[1:0], i_b[4:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[94:5], q1[1:0], i_a[2:0]} : {i_b[94:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[94:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[94:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd90:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[95:94], q1[1:0], i_a[91:0]} : {i_b[95:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[95:94], b1[1:0], i_b[91:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[95:92], q1[1:0], i_a[89:0]} : {i_b[95:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[95:92], b1[1:0], i_b[89:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[95:90], q1[1:0], i_a[87:0]} : {i_b[95:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[95:90], b1[1:0], i_b[87:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[95:88], q1[1:0], i_a[85:0]} : {i_b[95:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[95:88], b1[1:0], i_b[85:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[95:86], q1[1:0], i_a[83:0]} : {i_b[95:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[95:86], b1[1:0], i_b[83:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[95:84], q1[1:0], i_a[81:0]} : {i_b[95:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[95:84], b1[1:0], i_b[81:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[95:82], q1[1:0], i_a[79:0]} : {i_b[95:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[95:82], b1[1:0], i_b[79:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[95:80], q1[1:0], i_a[77:0]} : {i_b[95:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[95:80], b1[1:0], i_b[77:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[95:78], q1[1:0], i_a[75:0]} : {i_b[95:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[95:78], b1[1:0], i_b[75:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[95:76], q1[1:0], i_a[73:0]} : {i_b[95:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[95:76], b1[1:0], i_b[73:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[95:74], q1[1:0], i_a[71:0]} : {i_b[95:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[95:74], b1[1:0], i_b[71:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[95:72], q1[1:0], i_a[69:0]} : {i_b[95:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[95:72], b1[1:0], i_b[69:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[95:70], q1[1:0], i_a[67:0]} : {i_b[95:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[95:70], b1[1:0], i_b[67:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[95:68], q1[1:0], i_a[65:0]} : {i_b[95:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[95:68], b1[1:0], i_b[65:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[95:66], q1[1:0], i_a[63:0]} : {i_b[95:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[95:66], b1[1:0], i_b[63:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[95:64], q1[1:0], i_a[61:0]} : {i_b[95:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[95:64], b1[1:0], i_b[61:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[95:62], q1[1:0], i_a[59:0]} : {i_b[95:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[95:62], b1[1:0], i_b[59:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[95:60], q1[1:0], i_a[57:0]} : {i_b[95:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[95:60], b1[1:0], i_b[57:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[95:58], q1[1:0], i_a[55:0]} : {i_b[95:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[95:58], b1[1:0], i_b[55:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[95:56], q1[1:0], i_a[53:0]} : {i_b[95:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[95:56], b1[1:0], i_b[53:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[95:54], q1[1:0], i_a[51:0]} : {i_b[95:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[95:54], b1[1:0], i_b[51:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[95:52], q1[1:0], i_a[49:0]} : {i_b[95:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[95:52], b1[1:0], i_b[49:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[95:50], q1[1:0], i_a[47:0]} : {i_b[95:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[95:50], b1[1:0], i_b[47:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[95:48], q1[1:0], i_a[45:0]} : {i_b[95:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[95:48], b1[1:0], i_b[45:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[95:46], q1[1:0], i_a[43:0]} : {i_b[95:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[95:46], b1[1:0], i_b[43:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[95:44], q1[1:0], i_a[41:0]} : {i_b[95:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[95:44], b1[1:0], i_b[41:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[95:42], q1[1:0], i_a[39:0]} : {i_b[95:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[95:42], b1[1:0], i_b[39:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[95:40], q1[1:0], i_a[37:0]} : {i_b[95:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[95:40], b1[1:0], i_b[37:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[95:38], q1[1:0], i_a[35:0]} : {i_b[95:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[95:38], b1[1:0], i_b[35:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[95:36], q1[1:0], i_a[33:0]} : {i_b[95:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[95:36], b1[1:0], i_b[33:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[95:34], q1[1:0], i_a[31:0]} : {i_b[95:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[95:34], b1[1:0], i_b[31:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[95:32], q1[1:0], i_a[29:0]} : {i_b[95:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[95:32], b1[1:0], i_b[29:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[95:30], q1[1:0], i_a[27:0]} : {i_b[95:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[95:30], b1[1:0], i_b[27:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[95:28], q1[1:0], i_a[25:0]} : {i_b[95:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[95:28], b1[1:0], i_b[25:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[95:26], q1[1:0], i_a[23:0]} : {i_b[95:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[95:26], b1[1:0], i_b[23:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[95:24], q1[1:0], i_a[21:0]} : {i_b[95:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[95:24], b1[1:0], i_b[21:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[95:22], q1[1:0], i_a[19:0]} : {i_b[95:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[95:22], b1[1:0], i_b[19:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[95:20], q1[1:0], i_a[17:0]} : {i_b[95:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[95:20], b1[1:0], i_b[17:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[95:18], q1[1:0], i_a[15:0]} : {i_b[95:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[95:18], b1[1:0], i_b[15:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[95:16], q1[1:0], i_a[13:0]} : {i_b[95:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[95:16], b1[1:0], i_b[13:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[95:14], q1[1:0], i_a[11:0]} : {i_b[95:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[95:14], b1[1:0], i_b[11:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[95:12], q1[1:0], i_a[9:0]} : {i_b[95:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[95:12], b1[1:0], i_b[9:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[95:10], q1[1:0], i_a[7:0]} : {i_b[95:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[95:10], b1[1:0], i_b[7:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[95:8], q1[1:0], i_a[5:0]} : {i_b[95:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[95:8], b1[1:0], i_b[5:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[95:6], q1[1:0], i_a[3:0]} : {i_b[95:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[95:6], b1[1:0], i_b[3:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[95:4], q1[1:0], i_a[1:0]} : {i_b[95:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[95:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[95:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd91:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[96:95], q1[1:0], i_a[92:0]} : {i_b[96:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[96:95], b1[1:0], i_b[92:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[96:93], q1[1:0], i_a[90:0]} : {i_b[96:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[96:93], b1[1:0], i_b[90:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[96:91], q1[1:0], i_a[88:0]} : {i_b[96:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[96:91], b1[1:0], i_b[88:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[96:89], q1[1:0], i_a[86:0]} : {i_b[96:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[96:89], b1[1:0], i_b[86:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[96:87], q1[1:0], i_a[84:0]} : {i_b[96:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[96:87], b1[1:0], i_b[84:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[96:85], q1[1:0], i_a[82:0]} : {i_b[96:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[96:85], b1[1:0], i_b[82:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[96:83], q1[1:0], i_a[80:0]} : {i_b[96:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[96:83], b1[1:0], i_b[80:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[96:81], q1[1:0], i_a[78:0]} : {i_b[96:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[96:81], b1[1:0], i_b[78:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[96:79], q1[1:0], i_a[76:0]} : {i_b[96:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[96:79], b1[1:0], i_b[76:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[96:77], q1[1:0], i_a[74:0]} : {i_b[96:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[96:77], b1[1:0], i_b[74:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[96:75], q1[1:0], i_a[72:0]} : {i_b[96:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[96:75], b1[1:0], i_b[72:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[96:73], q1[1:0], i_a[70:0]} : {i_b[96:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[96:73], b1[1:0], i_b[70:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[96:71], q1[1:0], i_a[68:0]} : {i_b[96:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[96:71], b1[1:0], i_b[68:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[96:69], q1[1:0], i_a[66:0]} : {i_b[96:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[96:69], b1[1:0], i_b[66:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[96:67], q1[1:0], i_a[64:0]} : {i_b[96:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[96:67], b1[1:0], i_b[64:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[96:65], q1[1:0], i_a[62:0]} : {i_b[96:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[96:65], b1[1:0], i_b[62:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[96:63], q1[1:0], i_a[60:0]} : {i_b[96:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[96:63], b1[1:0], i_b[60:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[96:61], q1[1:0], i_a[58:0]} : {i_b[96:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[96:61], b1[1:0], i_b[58:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[96:59], q1[1:0], i_a[56:0]} : {i_b[96:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[96:59], b1[1:0], i_b[56:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[96:57], q1[1:0], i_a[54:0]} : {i_b[96:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[96:57], b1[1:0], i_b[54:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[96:55], q1[1:0], i_a[52:0]} : {i_b[96:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[96:55], b1[1:0], i_b[52:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[96:53], q1[1:0], i_a[50:0]} : {i_b[96:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[96:53], b1[1:0], i_b[50:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[96:51], q1[1:0], i_a[48:0]} : {i_b[96:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[96:51], b1[1:0], i_b[48:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[96:49], q1[1:0], i_a[46:0]} : {i_b[96:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[96:49], b1[1:0], i_b[46:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[96:47], q1[1:0], i_a[44:0]} : {i_b[96:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[96:47], b1[1:0], i_b[44:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[96:45], q1[1:0], i_a[42:0]} : {i_b[96:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[96:45], b1[1:0], i_b[42:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[96:43], q1[1:0], i_a[40:0]} : {i_b[96:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[96:43], b1[1:0], i_b[40:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[96:41], q1[1:0], i_a[38:0]} : {i_b[96:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[96:41], b1[1:0], i_b[38:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[96:39], q1[1:0], i_a[36:0]} : {i_b[96:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[96:39], b1[1:0], i_b[36:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[96:37], q1[1:0], i_a[34:0]} : {i_b[96:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[96:37], b1[1:0], i_b[34:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[96:35], q1[1:0], i_a[32:0]} : {i_b[96:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[96:35], b1[1:0], i_b[32:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[96:33], q1[1:0], i_a[30:0]} : {i_b[96:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[96:33], b1[1:0], i_b[30:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[96:31], q1[1:0], i_a[28:0]} : {i_b[96:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[96:31], b1[1:0], i_b[28:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[96:29], q1[1:0], i_a[26:0]} : {i_b[96:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[96:29], b1[1:0], i_b[26:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[96:27], q1[1:0], i_a[24:0]} : {i_b[96:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[96:27], b1[1:0], i_b[24:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[96:25], q1[1:0], i_a[22:0]} : {i_b[96:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[96:25], b1[1:0], i_b[22:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[96:23], q1[1:0], i_a[20:0]} : {i_b[96:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[96:23], b1[1:0], i_b[20:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[96:21], q1[1:0], i_a[18:0]} : {i_b[96:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[96:21], b1[1:0], i_b[18:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[96:19], q1[1:0], i_a[16:0]} : {i_b[96:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[96:19], b1[1:0], i_b[16:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[96:17], q1[1:0], i_a[14:0]} : {i_b[96:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[96:17], b1[1:0], i_b[14:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[96:15], q1[1:0], i_a[12:0]} : {i_b[96:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[96:15], b1[1:0], i_b[12:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[96:13], q1[1:0], i_a[10:0]} : {i_b[96:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[96:13], b1[1:0], i_b[10:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[96:11], q1[1:0], i_a[8:0]} : {i_b[96:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[96:11], b1[1:0], i_b[8:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[96:9], q1[1:0], i_a[6:0]} : {i_b[96:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[96:9], b1[1:0], i_b[6:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[96:7], q1[1:0], i_a[4:0]} : {i_b[96:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[96:7], b1[1:0], i_b[4:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[96:5], q1[1:0], i_a[2:0]} : {i_b[96:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[96:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[96:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd92:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[97:96], q1[1:0], i_a[93:0]} : {i_b[97:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[97:96], b1[1:0], i_b[93:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[97:94], q1[1:0], i_a[91:0]} : {i_b[97:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[97:94], b1[1:0], i_b[91:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[97:92], q1[1:0], i_a[89:0]} : {i_b[97:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[97:92], b1[1:0], i_b[89:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[97:90], q1[1:0], i_a[87:0]} : {i_b[97:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[97:90], b1[1:0], i_b[87:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[97:88], q1[1:0], i_a[85:0]} : {i_b[97:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[97:88], b1[1:0], i_b[85:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[97:86], q1[1:0], i_a[83:0]} : {i_b[97:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[97:86], b1[1:0], i_b[83:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[97:84], q1[1:0], i_a[81:0]} : {i_b[97:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[97:84], b1[1:0], i_b[81:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[97:82], q1[1:0], i_a[79:0]} : {i_b[97:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[97:82], b1[1:0], i_b[79:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[97:80], q1[1:0], i_a[77:0]} : {i_b[97:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[97:80], b1[1:0], i_b[77:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[97:78], q1[1:0], i_a[75:0]} : {i_b[97:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[97:78], b1[1:0], i_b[75:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[97:76], q1[1:0], i_a[73:0]} : {i_b[97:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[97:76], b1[1:0], i_b[73:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[97:74], q1[1:0], i_a[71:0]} : {i_b[97:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[97:74], b1[1:0], i_b[71:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[97:72], q1[1:0], i_a[69:0]} : {i_b[97:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[97:72], b1[1:0], i_b[69:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[97:70], q1[1:0], i_a[67:0]} : {i_b[97:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[97:70], b1[1:0], i_b[67:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[97:68], q1[1:0], i_a[65:0]} : {i_b[97:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[97:68], b1[1:0], i_b[65:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[97:66], q1[1:0], i_a[63:0]} : {i_b[97:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[97:66], b1[1:0], i_b[63:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[97:64], q1[1:0], i_a[61:0]} : {i_b[97:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[97:64], b1[1:0], i_b[61:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[97:62], q1[1:0], i_a[59:0]} : {i_b[97:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[97:62], b1[1:0], i_b[59:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[97:60], q1[1:0], i_a[57:0]} : {i_b[97:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[97:60], b1[1:0], i_b[57:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[97:58], q1[1:0], i_a[55:0]} : {i_b[97:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[97:58], b1[1:0], i_b[55:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[97:56], q1[1:0], i_a[53:0]} : {i_b[97:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[97:56], b1[1:0], i_b[53:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[97:54], q1[1:0], i_a[51:0]} : {i_b[97:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[97:54], b1[1:0], i_b[51:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[97:52], q1[1:0], i_a[49:0]} : {i_b[97:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[97:52], b1[1:0], i_b[49:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[97:50], q1[1:0], i_a[47:0]} : {i_b[97:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[97:50], b1[1:0], i_b[47:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[97:48], q1[1:0], i_a[45:0]} : {i_b[97:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[97:48], b1[1:0], i_b[45:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[97:46], q1[1:0], i_a[43:0]} : {i_b[97:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[97:46], b1[1:0], i_b[43:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[97:44], q1[1:0], i_a[41:0]} : {i_b[97:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[97:44], b1[1:0], i_b[41:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[97:42], q1[1:0], i_a[39:0]} : {i_b[97:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[97:42], b1[1:0], i_b[39:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[97:40], q1[1:0], i_a[37:0]} : {i_b[97:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[97:40], b1[1:0], i_b[37:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[97:38], q1[1:0], i_a[35:0]} : {i_b[97:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[97:38], b1[1:0], i_b[35:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[97:36], q1[1:0], i_a[33:0]} : {i_b[97:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[97:36], b1[1:0], i_b[33:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[97:34], q1[1:0], i_a[31:0]} : {i_b[97:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[97:34], b1[1:0], i_b[31:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[97:32], q1[1:0], i_a[29:0]} : {i_b[97:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[97:32], b1[1:0], i_b[29:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[97:30], q1[1:0], i_a[27:0]} : {i_b[97:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[97:30], b1[1:0], i_b[27:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[97:28], q1[1:0], i_a[25:0]} : {i_b[97:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[97:28], b1[1:0], i_b[25:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[97:26], q1[1:0], i_a[23:0]} : {i_b[97:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[97:26], b1[1:0], i_b[23:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[97:24], q1[1:0], i_a[21:0]} : {i_b[97:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[97:24], b1[1:0], i_b[21:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[97:22], q1[1:0], i_a[19:0]} : {i_b[97:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[97:22], b1[1:0], i_b[19:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[97:20], q1[1:0], i_a[17:0]} : {i_b[97:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[97:20], b1[1:0], i_b[17:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[97:18], q1[1:0], i_a[15:0]} : {i_b[97:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[97:18], b1[1:0], i_b[15:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[97:16], q1[1:0], i_a[13:0]} : {i_b[97:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[97:16], b1[1:0], i_b[13:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[97:14], q1[1:0], i_a[11:0]} : {i_b[97:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[97:14], b1[1:0], i_b[11:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[97:12], q1[1:0], i_a[9:0]} : {i_b[97:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[97:12], b1[1:0], i_b[9:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[97:10], q1[1:0], i_a[7:0]} : {i_b[97:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[97:10], b1[1:0], i_b[7:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[97:8], q1[1:0], i_a[5:0]} : {i_b[97:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[97:8], b1[1:0], i_b[5:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[97:6], q1[1:0], i_a[3:0]} : {i_b[97:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[97:6], b1[1:0], i_b[3:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[97:4], q1[1:0], i_a[1:0]} : {i_b[97:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[97:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[97:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd93:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[98:97], q1[1:0], i_a[94:0]} : {i_b[98:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[98:97], b1[1:0], i_b[94:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[98:95], q1[1:0], i_a[92:0]} : {i_b[98:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[98:95], b1[1:0], i_b[92:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[98:93], q1[1:0], i_a[90:0]} : {i_b[98:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[98:93], b1[1:0], i_b[90:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[98:91], q1[1:0], i_a[88:0]} : {i_b[98:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[98:91], b1[1:0], i_b[88:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[98:89], q1[1:0], i_a[86:0]} : {i_b[98:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[98:89], b1[1:0], i_b[86:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[98:87], q1[1:0], i_a[84:0]} : {i_b[98:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[98:87], b1[1:0], i_b[84:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[98:85], q1[1:0], i_a[82:0]} : {i_b[98:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[98:85], b1[1:0], i_b[82:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[98:83], q1[1:0], i_a[80:0]} : {i_b[98:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[98:83], b1[1:0], i_b[80:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[98:81], q1[1:0], i_a[78:0]} : {i_b[98:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[98:81], b1[1:0], i_b[78:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[98:79], q1[1:0], i_a[76:0]} : {i_b[98:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[98:79], b1[1:0], i_b[76:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[98:77], q1[1:0], i_a[74:0]} : {i_b[98:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[98:77], b1[1:0], i_b[74:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[98:75], q1[1:0], i_a[72:0]} : {i_b[98:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[98:75], b1[1:0], i_b[72:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[98:73], q1[1:0], i_a[70:0]} : {i_b[98:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[98:73], b1[1:0], i_b[70:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[98:71], q1[1:0], i_a[68:0]} : {i_b[98:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[98:71], b1[1:0], i_b[68:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[98:69], q1[1:0], i_a[66:0]} : {i_b[98:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[98:69], b1[1:0], i_b[66:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[98:67], q1[1:0], i_a[64:0]} : {i_b[98:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[98:67], b1[1:0], i_b[64:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[98:65], q1[1:0], i_a[62:0]} : {i_b[98:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[98:65], b1[1:0], i_b[62:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[98:63], q1[1:0], i_a[60:0]} : {i_b[98:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[98:63], b1[1:0], i_b[60:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[98:61], q1[1:0], i_a[58:0]} : {i_b[98:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[98:61], b1[1:0], i_b[58:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[98:59], q1[1:0], i_a[56:0]} : {i_b[98:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[98:59], b1[1:0], i_b[56:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[98:57], q1[1:0], i_a[54:0]} : {i_b[98:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[98:57], b1[1:0], i_b[54:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[98:55], q1[1:0], i_a[52:0]} : {i_b[98:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[98:55], b1[1:0], i_b[52:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[98:53], q1[1:0], i_a[50:0]} : {i_b[98:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[98:53], b1[1:0], i_b[50:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[98:51], q1[1:0], i_a[48:0]} : {i_b[98:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[98:51], b1[1:0], i_b[48:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[98:49], q1[1:0], i_a[46:0]} : {i_b[98:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[98:49], b1[1:0], i_b[46:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[98:47], q1[1:0], i_a[44:0]} : {i_b[98:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[98:47], b1[1:0], i_b[44:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[98:45], q1[1:0], i_a[42:0]} : {i_b[98:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[98:45], b1[1:0], i_b[42:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[98:43], q1[1:0], i_a[40:0]} : {i_b[98:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[98:43], b1[1:0], i_b[40:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[98:41], q1[1:0], i_a[38:0]} : {i_b[98:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[98:41], b1[1:0], i_b[38:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[98:39], q1[1:0], i_a[36:0]} : {i_b[98:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[98:39], b1[1:0], i_b[36:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[98:37], q1[1:0], i_a[34:0]} : {i_b[98:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[98:37], b1[1:0], i_b[34:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[98:35], q1[1:0], i_a[32:0]} : {i_b[98:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[98:35], b1[1:0], i_b[32:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[98:33], q1[1:0], i_a[30:0]} : {i_b[98:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[98:33], b1[1:0], i_b[30:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[98:31], q1[1:0], i_a[28:0]} : {i_b[98:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[98:31], b1[1:0], i_b[28:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[98:29], q1[1:0], i_a[26:0]} : {i_b[98:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[98:29], b1[1:0], i_b[26:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[98:27], q1[1:0], i_a[24:0]} : {i_b[98:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[98:27], b1[1:0], i_b[24:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[98:25], q1[1:0], i_a[22:0]} : {i_b[98:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[98:25], b1[1:0], i_b[22:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[98:23], q1[1:0], i_a[20:0]} : {i_b[98:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[98:23], b1[1:0], i_b[20:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[98:21], q1[1:0], i_a[18:0]} : {i_b[98:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[98:21], b1[1:0], i_b[18:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[98:19], q1[1:0], i_a[16:0]} : {i_b[98:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[98:19], b1[1:0], i_b[16:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[98:17], q1[1:0], i_a[14:0]} : {i_b[98:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[98:17], b1[1:0], i_b[14:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[98:15], q1[1:0], i_a[12:0]} : {i_b[98:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[98:15], b1[1:0], i_b[12:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[98:13], q1[1:0], i_a[10:0]} : {i_b[98:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[98:13], b1[1:0], i_b[10:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[98:11], q1[1:0], i_a[8:0]} : {i_b[98:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[98:11], b1[1:0], i_b[8:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[98:9], q1[1:0], i_a[6:0]} : {i_b[98:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[98:9], b1[1:0], i_b[6:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[98:7], q1[1:0], i_a[4:0]} : {i_b[98:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[98:7], b1[1:0], i_b[4:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[98:5], q1[1:0], i_a[2:0]} : {i_b[98:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[98:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[98:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd94:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[99:98], q1[1:0], i_a[95:0]} : {i_b[99:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[99:98], b1[1:0], i_b[95:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[99:96], q1[1:0], i_a[93:0]} : {i_b[99:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[99:96], b1[1:0], i_b[93:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[99:94], q1[1:0], i_a[91:0]} : {i_b[99:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[99:94], b1[1:0], i_b[91:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[99:92], q1[1:0], i_a[89:0]} : {i_b[99:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[99:92], b1[1:0], i_b[89:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[99:90], q1[1:0], i_a[87:0]} : {i_b[99:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[99:90], b1[1:0], i_b[87:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[99:88], q1[1:0], i_a[85:0]} : {i_b[99:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[99:88], b1[1:0], i_b[85:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[99:86], q1[1:0], i_a[83:0]} : {i_b[99:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[99:86], b1[1:0], i_b[83:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[99:84], q1[1:0], i_a[81:0]} : {i_b[99:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[99:84], b1[1:0], i_b[81:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[99:82], q1[1:0], i_a[79:0]} : {i_b[99:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[99:82], b1[1:0], i_b[79:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[99:80], q1[1:0], i_a[77:0]} : {i_b[99:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[99:80], b1[1:0], i_b[77:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[99:78], q1[1:0], i_a[75:0]} : {i_b[99:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[99:78], b1[1:0], i_b[75:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[99:76], q1[1:0], i_a[73:0]} : {i_b[99:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[99:76], b1[1:0], i_b[73:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[99:74], q1[1:0], i_a[71:0]} : {i_b[99:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[99:74], b1[1:0], i_b[71:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[99:72], q1[1:0], i_a[69:0]} : {i_b[99:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[99:72], b1[1:0], i_b[69:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[99:70], q1[1:0], i_a[67:0]} : {i_b[99:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[99:70], b1[1:0], i_b[67:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[99:68], q1[1:0], i_a[65:0]} : {i_b[99:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[99:68], b1[1:0], i_b[65:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[99:66], q1[1:0], i_a[63:0]} : {i_b[99:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[99:66], b1[1:0], i_b[63:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[99:64], q1[1:0], i_a[61:0]} : {i_b[99:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[99:64], b1[1:0], i_b[61:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[99:62], q1[1:0], i_a[59:0]} : {i_b[99:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[99:62], b1[1:0], i_b[59:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[99:60], q1[1:0], i_a[57:0]} : {i_b[99:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[99:60], b1[1:0], i_b[57:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[99:58], q1[1:0], i_a[55:0]} : {i_b[99:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[99:58], b1[1:0], i_b[55:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[99:56], q1[1:0], i_a[53:0]} : {i_b[99:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[99:56], b1[1:0], i_b[53:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[99:54], q1[1:0], i_a[51:0]} : {i_b[99:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[99:54], b1[1:0], i_b[51:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[99:52], q1[1:0], i_a[49:0]} : {i_b[99:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[99:52], b1[1:0], i_b[49:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[99:50], q1[1:0], i_a[47:0]} : {i_b[99:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[99:50], b1[1:0], i_b[47:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[99:48], q1[1:0], i_a[45:0]} : {i_b[99:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[99:48], b1[1:0], i_b[45:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[99:46], q1[1:0], i_a[43:0]} : {i_b[99:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[99:46], b1[1:0], i_b[43:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[99:44], q1[1:0], i_a[41:0]} : {i_b[99:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[99:44], b1[1:0], i_b[41:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[99:42], q1[1:0], i_a[39:0]} : {i_b[99:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[99:42], b1[1:0], i_b[39:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[99:40], q1[1:0], i_a[37:0]} : {i_b[99:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[99:40], b1[1:0], i_b[37:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[99:38], q1[1:0], i_a[35:0]} : {i_b[99:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[99:38], b1[1:0], i_b[35:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[99:36], q1[1:0], i_a[33:0]} : {i_b[99:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[99:36], b1[1:0], i_b[33:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[99:34], q1[1:0], i_a[31:0]} : {i_b[99:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[99:34], b1[1:0], i_b[31:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[99:32], q1[1:0], i_a[29:0]} : {i_b[99:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[99:32], b1[1:0], i_b[29:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[99:30], q1[1:0], i_a[27:0]} : {i_b[99:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[99:30], b1[1:0], i_b[27:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[99:28], q1[1:0], i_a[25:0]} : {i_b[99:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[99:28], b1[1:0], i_b[25:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[99:26], q1[1:0], i_a[23:0]} : {i_b[99:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[99:26], b1[1:0], i_b[23:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[99:24], q1[1:0], i_a[21:0]} : {i_b[99:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[99:24], b1[1:0], i_b[21:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[99:22], q1[1:0], i_a[19:0]} : {i_b[99:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[99:22], b1[1:0], i_b[19:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[99:20], q1[1:0], i_a[17:0]} : {i_b[99:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[99:20], b1[1:0], i_b[17:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[99:18], q1[1:0], i_a[15:0]} : {i_b[99:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[99:18], b1[1:0], i_b[15:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[99:16], q1[1:0], i_a[13:0]} : {i_b[99:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[99:16], b1[1:0], i_b[13:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[99:14], q1[1:0], i_a[11:0]} : {i_b[99:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[99:14], b1[1:0], i_b[11:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[99:12], q1[1:0], i_a[9:0]} : {i_b[99:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[99:12], b1[1:0], i_b[9:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[99:10], q1[1:0], i_a[7:0]} : {i_b[99:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[99:10], b1[1:0], i_b[7:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[99:8], q1[1:0], i_a[5:0]} : {i_b[99:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[99:8], b1[1:0], i_b[5:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[99:6], q1[1:0], i_a[3:0]} : {i_b[99:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[99:6], b1[1:0], i_b[3:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[99:4], q1[1:0], i_a[1:0]} : {i_b[99:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[99:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[99:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd95:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[100:99], q1[1:0], i_a[96:0]} : {i_b[100:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[100:99], b1[1:0], i_b[96:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[100:97], q1[1:0], i_a[94:0]} : {i_b[100:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[100:97], b1[1:0], i_b[94:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[100:95], q1[1:0], i_a[92:0]} : {i_b[100:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[100:95], b1[1:0], i_b[92:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[100:93], q1[1:0], i_a[90:0]} : {i_b[100:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[100:93], b1[1:0], i_b[90:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[100:91], q1[1:0], i_a[88:0]} : {i_b[100:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[100:91], b1[1:0], i_b[88:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[100:89], q1[1:0], i_a[86:0]} : {i_b[100:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[100:89], b1[1:0], i_b[86:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[100:87], q1[1:0], i_a[84:0]} : {i_b[100:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[100:87], b1[1:0], i_b[84:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[100:85], q1[1:0], i_a[82:0]} : {i_b[100:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[100:85], b1[1:0], i_b[82:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[100:83], q1[1:0], i_a[80:0]} : {i_b[100:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[100:83], b1[1:0], i_b[80:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[100:81], q1[1:0], i_a[78:0]} : {i_b[100:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[100:81], b1[1:0], i_b[78:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[100:79], q1[1:0], i_a[76:0]} : {i_b[100:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[100:79], b1[1:0], i_b[76:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[100:77], q1[1:0], i_a[74:0]} : {i_b[100:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[100:77], b1[1:0], i_b[74:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[100:75], q1[1:0], i_a[72:0]} : {i_b[100:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[100:75], b1[1:0], i_b[72:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[100:73], q1[1:0], i_a[70:0]} : {i_b[100:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[100:73], b1[1:0], i_b[70:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[100:71], q1[1:0], i_a[68:0]} : {i_b[100:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[100:71], b1[1:0], i_b[68:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[100:69], q1[1:0], i_a[66:0]} : {i_b[100:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[100:69], b1[1:0], i_b[66:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[100:67], q1[1:0], i_a[64:0]} : {i_b[100:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[100:67], b1[1:0], i_b[64:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[100:65], q1[1:0], i_a[62:0]} : {i_b[100:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[100:65], b1[1:0], i_b[62:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[100:63], q1[1:0], i_a[60:0]} : {i_b[100:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[100:63], b1[1:0], i_b[60:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[100:61], q1[1:0], i_a[58:0]} : {i_b[100:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[100:61], b1[1:0], i_b[58:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[100:59], q1[1:0], i_a[56:0]} : {i_b[100:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[100:59], b1[1:0], i_b[56:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[100:57], q1[1:0], i_a[54:0]} : {i_b[100:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[100:57], b1[1:0], i_b[54:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[100:55], q1[1:0], i_a[52:0]} : {i_b[100:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[100:55], b1[1:0], i_b[52:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[100:53], q1[1:0], i_a[50:0]} : {i_b[100:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[100:53], b1[1:0], i_b[50:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[100:51], q1[1:0], i_a[48:0]} : {i_b[100:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[100:51], b1[1:0], i_b[48:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[100:49], q1[1:0], i_a[46:0]} : {i_b[100:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[100:49], b1[1:0], i_b[46:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[100:47], q1[1:0], i_a[44:0]} : {i_b[100:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[100:47], b1[1:0], i_b[44:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[100:45], q1[1:0], i_a[42:0]} : {i_b[100:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[100:45], b1[1:0], i_b[42:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[100:43], q1[1:0], i_a[40:0]} : {i_b[100:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[100:43], b1[1:0], i_b[40:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[100:41], q1[1:0], i_a[38:0]} : {i_b[100:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[100:41], b1[1:0], i_b[38:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[100:39], q1[1:0], i_a[36:0]} : {i_b[100:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[100:39], b1[1:0], i_b[36:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[100:37], q1[1:0], i_a[34:0]} : {i_b[100:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[100:37], b1[1:0], i_b[34:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[100:35], q1[1:0], i_a[32:0]} : {i_b[100:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[100:35], b1[1:0], i_b[32:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[100:33], q1[1:0], i_a[30:0]} : {i_b[100:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[100:33], b1[1:0], i_b[30:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[100:31], q1[1:0], i_a[28:0]} : {i_b[100:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[100:31], b1[1:0], i_b[28:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[100:29], q1[1:0], i_a[26:0]} : {i_b[100:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[100:29], b1[1:0], i_b[26:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[100:27], q1[1:0], i_a[24:0]} : {i_b[100:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[100:27], b1[1:0], i_b[24:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[100:25], q1[1:0], i_a[22:0]} : {i_b[100:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[100:25], b1[1:0], i_b[22:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[100:23], q1[1:0], i_a[20:0]} : {i_b[100:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[100:23], b1[1:0], i_b[20:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[100:21], q1[1:0], i_a[18:0]} : {i_b[100:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[100:21], b1[1:0], i_b[18:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[100:19], q1[1:0], i_a[16:0]} : {i_b[100:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[100:19], b1[1:0], i_b[16:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[100:17], q1[1:0], i_a[14:0]} : {i_b[100:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[100:17], b1[1:0], i_b[14:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[100:15], q1[1:0], i_a[12:0]} : {i_b[100:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[100:15], b1[1:0], i_b[12:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[100:13], q1[1:0], i_a[10:0]} : {i_b[100:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[100:13], b1[1:0], i_b[10:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[100:11], q1[1:0], i_a[8:0]} : {i_b[100:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[100:11], b1[1:0], i_b[8:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[100:9], q1[1:0], i_a[6:0]} : {i_b[100:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[100:9], b1[1:0], i_b[6:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[100:7], q1[1:0], i_a[4:0]} : {i_b[100:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[100:7], b1[1:0], i_b[4:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[100:5], q1[1:0], i_a[2:0]} : {i_b[100:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[100:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[100:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd96:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[101:100], q1[1:0], i_a[97:0]} : {i_b[101:100], a1[1:0], i_b[97:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:100], q1[1:0]-2'b1, i_a[97:0]} : {i_b[101:100], b1[1:0], i_b[97:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[101:98], q1[1:0], i_a[95:0]} : {i_b[101:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[101:98], b1[1:0], i_b[95:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[101:96], q1[1:0], i_a[93:0]} : {i_b[101:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[101:96], b1[1:0], i_b[93:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[101:94], q1[1:0], i_a[91:0]} : {i_b[101:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[101:94], b1[1:0], i_b[91:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[101:92], q1[1:0], i_a[89:0]} : {i_b[101:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[101:92], b1[1:0], i_b[89:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[101:90], q1[1:0], i_a[87:0]} : {i_b[101:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[101:90], b1[1:0], i_b[87:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[101:88], q1[1:0], i_a[85:0]} : {i_b[101:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[101:88], b1[1:0], i_b[85:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[101:86], q1[1:0], i_a[83:0]} : {i_b[101:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[101:86], b1[1:0], i_b[83:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[101:84], q1[1:0], i_a[81:0]} : {i_b[101:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[101:84], b1[1:0], i_b[81:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[101:82], q1[1:0], i_a[79:0]} : {i_b[101:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[101:82], b1[1:0], i_b[79:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[101:80], q1[1:0], i_a[77:0]} : {i_b[101:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[101:80], b1[1:0], i_b[77:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[101:78], q1[1:0], i_a[75:0]} : {i_b[101:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[101:78], b1[1:0], i_b[75:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[101:76], q1[1:0], i_a[73:0]} : {i_b[101:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[101:76], b1[1:0], i_b[73:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[101:74], q1[1:0], i_a[71:0]} : {i_b[101:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[101:74], b1[1:0], i_b[71:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[101:72], q1[1:0], i_a[69:0]} : {i_b[101:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[101:72], b1[1:0], i_b[69:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[101:70], q1[1:0], i_a[67:0]} : {i_b[101:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[101:70], b1[1:0], i_b[67:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[101:68], q1[1:0], i_a[65:0]} : {i_b[101:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[101:68], b1[1:0], i_b[65:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[101:66], q1[1:0], i_a[63:0]} : {i_b[101:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[101:66], b1[1:0], i_b[63:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[101:64], q1[1:0], i_a[61:0]} : {i_b[101:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[101:64], b1[1:0], i_b[61:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[101:62], q1[1:0], i_a[59:0]} : {i_b[101:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[101:62], b1[1:0], i_b[59:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[101:60], q1[1:0], i_a[57:0]} : {i_b[101:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[101:60], b1[1:0], i_b[57:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[101:58], q1[1:0], i_a[55:0]} : {i_b[101:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[101:58], b1[1:0], i_b[55:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[101:56], q1[1:0], i_a[53:0]} : {i_b[101:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[101:56], b1[1:0], i_b[53:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[101:54], q1[1:0], i_a[51:0]} : {i_b[101:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[101:54], b1[1:0], i_b[51:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[101:52], q1[1:0], i_a[49:0]} : {i_b[101:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[101:52], b1[1:0], i_b[49:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[101:50], q1[1:0], i_a[47:0]} : {i_b[101:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[101:50], b1[1:0], i_b[47:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[101:48], q1[1:0], i_a[45:0]} : {i_b[101:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[101:48], b1[1:0], i_b[45:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[101:46], q1[1:0], i_a[43:0]} : {i_b[101:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[101:46], b1[1:0], i_b[43:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[101:44], q1[1:0], i_a[41:0]} : {i_b[101:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[101:44], b1[1:0], i_b[41:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[101:42], q1[1:0], i_a[39:0]} : {i_b[101:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[101:42], b1[1:0], i_b[39:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[101:40], q1[1:0], i_a[37:0]} : {i_b[101:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[101:40], b1[1:0], i_b[37:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[101:38], q1[1:0], i_a[35:0]} : {i_b[101:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[101:38], b1[1:0], i_b[35:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[101:36], q1[1:0], i_a[33:0]} : {i_b[101:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[101:36], b1[1:0], i_b[33:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[101:34], q1[1:0], i_a[31:0]} : {i_b[101:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[101:34], b1[1:0], i_b[31:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[101:32], q1[1:0], i_a[29:0]} : {i_b[101:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[101:32], b1[1:0], i_b[29:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[101:30], q1[1:0], i_a[27:0]} : {i_b[101:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[101:30], b1[1:0], i_b[27:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[101:28], q1[1:0], i_a[25:0]} : {i_b[101:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[101:28], b1[1:0], i_b[25:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[101:26], q1[1:0], i_a[23:0]} : {i_b[101:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[101:26], b1[1:0], i_b[23:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[101:24], q1[1:0], i_a[21:0]} : {i_b[101:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[101:24], b1[1:0], i_b[21:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[101:22], q1[1:0], i_a[19:0]} : {i_b[101:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[101:22], b1[1:0], i_b[19:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[101:20], q1[1:0], i_a[17:0]} : {i_b[101:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[101:20], b1[1:0], i_b[17:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[101:18], q1[1:0], i_a[15:0]} : {i_b[101:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[101:18], b1[1:0], i_b[15:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[101:16], q1[1:0], i_a[13:0]} : {i_b[101:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[101:16], b1[1:0], i_b[13:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[101:14], q1[1:0], i_a[11:0]} : {i_b[101:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[101:14], b1[1:0], i_b[11:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[101:12], q1[1:0], i_a[9:0]} : {i_b[101:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[101:12], b1[1:0], i_b[9:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[101:10], q1[1:0], i_a[7:0]} : {i_b[101:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[101:10], b1[1:0], i_b[7:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[101:8], q1[1:0], i_a[5:0]} : {i_b[101:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[101:8], b1[1:0], i_b[5:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[101:6], q1[1:0], i_a[3:0]} : {i_b[101:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[101:6], b1[1:0], i_b[3:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[101:4], q1[1:0], i_a[1:0]} : {i_b[101:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[101:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[101:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd97:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[102:101], q1[1:0], i_a[98:0]} : {i_b[102:101], a1[1:0], i_b[98:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:101], q1[1:0]-2'b1, i_a[98:0]} : {i_b[102:101], b1[1:0], i_b[98:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[102:99], q1[1:0], i_a[96:0]} : {i_b[102:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[102:99], b1[1:0], i_b[96:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[102:97], q1[1:0], i_a[94:0]} : {i_b[102:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[102:97], b1[1:0], i_b[94:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[102:95], q1[1:0], i_a[92:0]} : {i_b[102:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[102:95], b1[1:0], i_b[92:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[102:93], q1[1:0], i_a[90:0]} : {i_b[102:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[102:93], b1[1:0], i_b[90:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[102:91], q1[1:0], i_a[88:0]} : {i_b[102:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[102:91], b1[1:0], i_b[88:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[102:89], q1[1:0], i_a[86:0]} : {i_b[102:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[102:89], b1[1:0], i_b[86:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[102:87], q1[1:0], i_a[84:0]} : {i_b[102:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[102:87], b1[1:0], i_b[84:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[102:85], q1[1:0], i_a[82:0]} : {i_b[102:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[102:85], b1[1:0], i_b[82:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[102:83], q1[1:0], i_a[80:0]} : {i_b[102:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[102:83], b1[1:0], i_b[80:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[102:81], q1[1:0], i_a[78:0]} : {i_b[102:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[102:81], b1[1:0], i_b[78:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[102:79], q1[1:0], i_a[76:0]} : {i_b[102:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[102:79], b1[1:0], i_b[76:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[102:77], q1[1:0], i_a[74:0]} : {i_b[102:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[102:77], b1[1:0], i_b[74:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[102:75], q1[1:0], i_a[72:0]} : {i_b[102:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[102:75], b1[1:0], i_b[72:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[102:73], q1[1:0], i_a[70:0]} : {i_b[102:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[102:73], b1[1:0], i_b[70:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[102:71], q1[1:0], i_a[68:0]} : {i_b[102:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[102:71], b1[1:0], i_b[68:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[102:69], q1[1:0], i_a[66:0]} : {i_b[102:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[102:69], b1[1:0], i_b[66:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[102:67], q1[1:0], i_a[64:0]} : {i_b[102:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[102:67], b1[1:0], i_b[64:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[102:65], q1[1:0], i_a[62:0]} : {i_b[102:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[102:65], b1[1:0], i_b[62:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[102:63], q1[1:0], i_a[60:0]} : {i_b[102:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[102:63], b1[1:0], i_b[60:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[102:61], q1[1:0], i_a[58:0]} : {i_b[102:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[102:61], b1[1:0], i_b[58:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[102:59], q1[1:0], i_a[56:0]} : {i_b[102:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[102:59], b1[1:0], i_b[56:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[102:57], q1[1:0], i_a[54:0]} : {i_b[102:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[102:57], b1[1:0], i_b[54:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[102:55], q1[1:0], i_a[52:0]} : {i_b[102:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[102:55], b1[1:0], i_b[52:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[102:53], q1[1:0], i_a[50:0]} : {i_b[102:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[102:53], b1[1:0], i_b[50:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[102:51], q1[1:0], i_a[48:0]} : {i_b[102:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[102:51], b1[1:0], i_b[48:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[102:49], q1[1:0], i_a[46:0]} : {i_b[102:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[102:49], b1[1:0], i_b[46:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[102:47], q1[1:0], i_a[44:0]} : {i_b[102:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[102:47], b1[1:0], i_b[44:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[102:45], q1[1:0], i_a[42:0]} : {i_b[102:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[102:45], b1[1:0], i_b[42:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[102:43], q1[1:0], i_a[40:0]} : {i_b[102:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[102:43], b1[1:0], i_b[40:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[102:41], q1[1:0], i_a[38:0]} : {i_b[102:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[102:41], b1[1:0], i_b[38:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[102:39], q1[1:0], i_a[36:0]} : {i_b[102:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[102:39], b1[1:0], i_b[36:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[102:37], q1[1:0], i_a[34:0]} : {i_b[102:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[102:37], b1[1:0], i_b[34:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[102:35], q1[1:0], i_a[32:0]} : {i_b[102:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[102:35], b1[1:0], i_b[32:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[102:33], q1[1:0], i_a[30:0]} : {i_b[102:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[102:33], b1[1:0], i_b[30:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[102:31], q1[1:0], i_a[28:0]} : {i_b[102:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[102:31], b1[1:0], i_b[28:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[102:29], q1[1:0], i_a[26:0]} : {i_b[102:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[102:29], b1[1:0], i_b[26:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[102:27], q1[1:0], i_a[24:0]} : {i_b[102:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[102:27], b1[1:0], i_b[24:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[102:25], q1[1:0], i_a[22:0]} : {i_b[102:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[102:25], b1[1:0], i_b[22:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[102:23], q1[1:0], i_a[20:0]} : {i_b[102:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[102:23], b1[1:0], i_b[20:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[102:21], q1[1:0], i_a[18:0]} : {i_b[102:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[102:21], b1[1:0], i_b[18:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[102:19], q1[1:0], i_a[16:0]} : {i_b[102:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[102:19], b1[1:0], i_b[16:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[102:17], q1[1:0], i_a[14:0]} : {i_b[102:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[102:17], b1[1:0], i_b[14:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[102:15], q1[1:0], i_a[12:0]} : {i_b[102:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[102:15], b1[1:0], i_b[12:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[102:13], q1[1:0], i_a[10:0]} : {i_b[102:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[102:13], b1[1:0], i_b[10:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[102:11], q1[1:0], i_a[8:0]} : {i_b[102:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[102:11], b1[1:0], i_b[8:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[102:9], q1[1:0], i_a[6:0]} : {i_b[102:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[102:9], b1[1:0], i_b[6:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[102:7], q1[1:0], i_a[4:0]} : {i_b[102:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[102:7], b1[1:0], i_b[4:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[102:5], q1[1:0], i_a[2:0]} : {i_b[102:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[102:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[102:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd98:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[103:102], q1[1:0], i_a[99:0]} : {i_b[103:102], a1[1:0], i_b[99:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:102], q1[1:0]-2'b1, i_a[99:0]} : {i_b[103:102], b1[1:0], i_b[99:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[103:100], q1[1:0], i_a[97:0]} : {i_b[103:100], a1[1:0], i_b[97:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:100], q1[1:0]-2'b1, i_a[97:0]} : {i_b[103:100], b1[1:0], i_b[97:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[103:98], q1[1:0], i_a[95:0]} : {i_b[103:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[103:98], b1[1:0], i_b[95:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[103:96], q1[1:0], i_a[93:0]} : {i_b[103:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[103:96], b1[1:0], i_b[93:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[103:94], q1[1:0], i_a[91:0]} : {i_b[103:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[103:94], b1[1:0], i_b[91:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[103:92], q1[1:0], i_a[89:0]} : {i_b[103:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[103:92], b1[1:0], i_b[89:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[103:90], q1[1:0], i_a[87:0]} : {i_b[103:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[103:90], b1[1:0], i_b[87:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[103:88], q1[1:0], i_a[85:0]} : {i_b[103:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[103:88], b1[1:0], i_b[85:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[103:86], q1[1:0], i_a[83:0]} : {i_b[103:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[103:86], b1[1:0], i_b[83:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[103:84], q1[1:0], i_a[81:0]} : {i_b[103:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[103:84], b1[1:0], i_b[81:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[103:82], q1[1:0], i_a[79:0]} : {i_b[103:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[103:82], b1[1:0], i_b[79:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[103:80], q1[1:0], i_a[77:0]} : {i_b[103:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[103:80], b1[1:0], i_b[77:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[103:78], q1[1:0], i_a[75:0]} : {i_b[103:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[103:78], b1[1:0], i_b[75:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[103:76], q1[1:0], i_a[73:0]} : {i_b[103:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[103:76], b1[1:0], i_b[73:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[103:74], q1[1:0], i_a[71:0]} : {i_b[103:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[103:74], b1[1:0], i_b[71:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[103:72], q1[1:0], i_a[69:0]} : {i_b[103:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[103:72], b1[1:0], i_b[69:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[103:70], q1[1:0], i_a[67:0]} : {i_b[103:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[103:70], b1[1:0], i_b[67:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[103:68], q1[1:0], i_a[65:0]} : {i_b[103:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[103:68], b1[1:0], i_b[65:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[103:66], q1[1:0], i_a[63:0]} : {i_b[103:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[103:66], b1[1:0], i_b[63:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[103:64], q1[1:0], i_a[61:0]} : {i_b[103:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[103:64], b1[1:0], i_b[61:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[103:62], q1[1:0], i_a[59:0]} : {i_b[103:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[103:62], b1[1:0], i_b[59:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[103:60], q1[1:0], i_a[57:0]} : {i_b[103:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[103:60], b1[1:0], i_b[57:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[103:58], q1[1:0], i_a[55:0]} : {i_b[103:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[103:58], b1[1:0], i_b[55:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[103:56], q1[1:0], i_a[53:0]} : {i_b[103:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[103:56], b1[1:0], i_b[53:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[103:54], q1[1:0], i_a[51:0]} : {i_b[103:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[103:54], b1[1:0], i_b[51:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[103:52], q1[1:0], i_a[49:0]} : {i_b[103:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[103:52], b1[1:0], i_b[49:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[103:50], q1[1:0], i_a[47:0]} : {i_b[103:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[103:50], b1[1:0], i_b[47:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[103:48], q1[1:0], i_a[45:0]} : {i_b[103:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[103:48], b1[1:0], i_b[45:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[103:46], q1[1:0], i_a[43:0]} : {i_b[103:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[103:46], b1[1:0], i_b[43:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[103:44], q1[1:0], i_a[41:0]} : {i_b[103:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[103:44], b1[1:0], i_b[41:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[103:42], q1[1:0], i_a[39:0]} : {i_b[103:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[103:42], b1[1:0], i_b[39:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[103:40], q1[1:0], i_a[37:0]} : {i_b[103:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[103:40], b1[1:0], i_b[37:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[103:38], q1[1:0], i_a[35:0]} : {i_b[103:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[103:38], b1[1:0], i_b[35:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[103:36], q1[1:0], i_a[33:0]} : {i_b[103:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[103:36], b1[1:0], i_b[33:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[103:34], q1[1:0], i_a[31:0]} : {i_b[103:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[103:34], b1[1:0], i_b[31:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[103:32], q1[1:0], i_a[29:0]} : {i_b[103:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[103:32], b1[1:0], i_b[29:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[103:30], q1[1:0], i_a[27:0]} : {i_b[103:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[103:30], b1[1:0], i_b[27:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[103:28], q1[1:0], i_a[25:0]} : {i_b[103:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[103:28], b1[1:0], i_b[25:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[103:26], q1[1:0], i_a[23:0]} : {i_b[103:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[103:26], b1[1:0], i_b[23:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[103:24], q1[1:0], i_a[21:0]} : {i_b[103:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[103:24], b1[1:0], i_b[21:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[103:22], q1[1:0], i_a[19:0]} : {i_b[103:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[103:22], b1[1:0], i_b[19:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[103:20], q1[1:0], i_a[17:0]} : {i_b[103:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[103:20], b1[1:0], i_b[17:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[103:18], q1[1:0], i_a[15:0]} : {i_b[103:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[103:18], b1[1:0], i_b[15:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[103:16], q1[1:0], i_a[13:0]} : {i_b[103:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[103:16], b1[1:0], i_b[13:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[103:14], q1[1:0], i_a[11:0]} : {i_b[103:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[103:14], b1[1:0], i_b[11:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[103:12], q1[1:0], i_a[9:0]} : {i_b[103:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[103:12], b1[1:0], i_b[9:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[103:10], q1[1:0], i_a[7:0]} : {i_b[103:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[103:10], b1[1:0], i_b[7:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[103:8], q1[1:0], i_a[5:0]} : {i_b[103:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[103:8], b1[1:0], i_b[5:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[103:6], q1[1:0], i_a[3:0]} : {i_b[103:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[103:6], b1[1:0], i_b[3:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[103:4], q1[1:0], i_a[1:0]} : {i_b[103:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[103:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[103:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd99:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[104:103], q1[1:0], i_a[100:0]} : {i_b[104:103], a1[1:0], i_b[100:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:103], q1[1:0]-2'b1, i_a[100:0]} : {i_b[104:103], b1[1:0], i_b[100:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[104:101], q1[1:0], i_a[98:0]} : {i_b[104:101], a1[1:0], i_b[98:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:101], q1[1:0]-2'b1, i_a[98:0]} : {i_b[104:101], b1[1:0], i_b[98:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[104:99], q1[1:0], i_a[96:0]} : {i_b[104:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[104:99], b1[1:0], i_b[96:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[104:97], q1[1:0], i_a[94:0]} : {i_b[104:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[104:97], b1[1:0], i_b[94:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[104:95], q1[1:0], i_a[92:0]} : {i_b[104:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[104:95], b1[1:0], i_b[92:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[104:93], q1[1:0], i_a[90:0]} : {i_b[104:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[104:93], b1[1:0], i_b[90:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[104:91], q1[1:0], i_a[88:0]} : {i_b[104:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[104:91], b1[1:0], i_b[88:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[104:89], q1[1:0], i_a[86:0]} : {i_b[104:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[104:89], b1[1:0], i_b[86:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[104:87], q1[1:0], i_a[84:0]} : {i_b[104:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[104:87], b1[1:0], i_b[84:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[104:85], q1[1:0], i_a[82:0]} : {i_b[104:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[104:85], b1[1:0], i_b[82:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[104:83], q1[1:0], i_a[80:0]} : {i_b[104:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[104:83], b1[1:0], i_b[80:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[104:81], q1[1:0], i_a[78:0]} : {i_b[104:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[104:81], b1[1:0], i_b[78:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[104:79], q1[1:0], i_a[76:0]} : {i_b[104:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[104:79], b1[1:0], i_b[76:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[104:77], q1[1:0], i_a[74:0]} : {i_b[104:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[104:77], b1[1:0], i_b[74:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[104:75], q1[1:0], i_a[72:0]} : {i_b[104:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[104:75], b1[1:0], i_b[72:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[104:73], q1[1:0], i_a[70:0]} : {i_b[104:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[104:73], b1[1:0], i_b[70:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[104:71], q1[1:0], i_a[68:0]} : {i_b[104:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[104:71], b1[1:0], i_b[68:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[104:69], q1[1:0], i_a[66:0]} : {i_b[104:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[104:69], b1[1:0], i_b[66:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[104:67], q1[1:0], i_a[64:0]} : {i_b[104:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[104:67], b1[1:0], i_b[64:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[104:65], q1[1:0], i_a[62:0]} : {i_b[104:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[104:65], b1[1:0], i_b[62:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[104:63], q1[1:0], i_a[60:0]} : {i_b[104:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[104:63], b1[1:0], i_b[60:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[104:61], q1[1:0], i_a[58:0]} : {i_b[104:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[104:61], b1[1:0], i_b[58:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[104:59], q1[1:0], i_a[56:0]} : {i_b[104:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[104:59], b1[1:0], i_b[56:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[104:57], q1[1:0], i_a[54:0]} : {i_b[104:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[104:57], b1[1:0], i_b[54:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[104:55], q1[1:0], i_a[52:0]} : {i_b[104:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[104:55], b1[1:0], i_b[52:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[104:53], q1[1:0], i_a[50:0]} : {i_b[104:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[104:53], b1[1:0], i_b[50:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[104:51], q1[1:0], i_a[48:0]} : {i_b[104:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[104:51], b1[1:0], i_b[48:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[104:49], q1[1:0], i_a[46:0]} : {i_b[104:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[104:49], b1[1:0], i_b[46:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[104:47], q1[1:0], i_a[44:0]} : {i_b[104:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[104:47], b1[1:0], i_b[44:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[104:45], q1[1:0], i_a[42:0]} : {i_b[104:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[104:45], b1[1:0], i_b[42:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[104:43], q1[1:0], i_a[40:0]} : {i_b[104:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[104:43], b1[1:0], i_b[40:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[104:41], q1[1:0], i_a[38:0]} : {i_b[104:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[104:41], b1[1:0], i_b[38:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[104:39], q1[1:0], i_a[36:0]} : {i_b[104:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[104:39], b1[1:0], i_b[36:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[104:37], q1[1:0], i_a[34:0]} : {i_b[104:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[104:37], b1[1:0], i_b[34:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[104:35], q1[1:0], i_a[32:0]} : {i_b[104:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[104:35], b1[1:0], i_b[32:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[104:33], q1[1:0], i_a[30:0]} : {i_b[104:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[104:33], b1[1:0], i_b[30:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[104:31], q1[1:0], i_a[28:0]} : {i_b[104:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[104:31], b1[1:0], i_b[28:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[104:29], q1[1:0], i_a[26:0]} : {i_b[104:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[104:29], b1[1:0], i_b[26:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[104:27], q1[1:0], i_a[24:0]} : {i_b[104:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[104:27], b1[1:0], i_b[24:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[104:25], q1[1:0], i_a[22:0]} : {i_b[104:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[104:25], b1[1:0], i_b[22:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[104:23], q1[1:0], i_a[20:0]} : {i_b[104:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[104:23], b1[1:0], i_b[20:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[104:21], q1[1:0], i_a[18:0]} : {i_b[104:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[104:21], b1[1:0], i_b[18:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[104:19], q1[1:0], i_a[16:0]} : {i_b[104:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[104:19], b1[1:0], i_b[16:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[104:17], q1[1:0], i_a[14:0]} : {i_b[104:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[104:17], b1[1:0], i_b[14:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[104:15], q1[1:0], i_a[12:0]} : {i_b[104:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[104:15], b1[1:0], i_b[12:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[104:13], q1[1:0], i_a[10:0]} : {i_b[104:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[104:13], b1[1:0], i_b[10:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[104:11], q1[1:0], i_a[8:0]} : {i_b[104:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[104:11], b1[1:0], i_b[8:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[104:9], q1[1:0], i_a[6:0]} : {i_b[104:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[104:9], b1[1:0], i_b[6:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[104:7], q1[1:0], i_a[4:0]} : {i_b[104:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[104:7], b1[1:0], i_b[4:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[104:5], q1[1:0], i_a[2:0]} : {i_b[104:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[104:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[104:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd100:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[105:104], q1[1:0], i_a[101:0]} : {i_b[105:104], a1[1:0], i_b[101:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:104], q1[1:0]-2'b1, i_a[101:0]} : {i_b[105:104], b1[1:0], i_b[101:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[105:102], q1[1:0], i_a[99:0]} : {i_b[105:102], a1[1:0], i_b[99:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:102], q1[1:0]-2'b1, i_a[99:0]} : {i_b[105:102], b1[1:0], i_b[99:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[105:100], q1[1:0], i_a[97:0]} : {i_b[105:100], a1[1:0], i_b[97:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:100], q1[1:0]-2'b1, i_a[97:0]} : {i_b[105:100], b1[1:0], i_b[97:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[105:98], q1[1:0], i_a[95:0]} : {i_b[105:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[105:98], b1[1:0], i_b[95:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[105:96], q1[1:0], i_a[93:0]} : {i_b[105:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[105:96], b1[1:0], i_b[93:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[105:94], q1[1:0], i_a[91:0]} : {i_b[105:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[105:94], b1[1:0], i_b[91:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[105:92], q1[1:0], i_a[89:0]} : {i_b[105:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[105:92], b1[1:0], i_b[89:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[105:90], q1[1:0], i_a[87:0]} : {i_b[105:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[105:90], b1[1:0], i_b[87:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[105:88], q1[1:0], i_a[85:0]} : {i_b[105:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[105:88], b1[1:0], i_b[85:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[105:86], q1[1:0], i_a[83:0]} : {i_b[105:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[105:86], b1[1:0], i_b[83:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[105:84], q1[1:0], i_a[81:0]} : {i_b[105:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[105:84], b1[1:0], i_b[81:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[105:82], q1[1:0], i_a[79:0]} : {i_b[105:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[105:82], b1[1:0], i_b[79:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[105:80], q1[1:0], i_a[77:0]} : {i_b[105:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[105:80], b1[1:0], i_b[77:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[105:78], q1[1:0], i_a[75:0]} : {i_b[105:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[105:78], b1[1:0], i_b[75:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[105:76], q1[1:0], i_a[73:0]} : {i_b[105:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[105:76], b1[1:0], i_b[73:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[105:74], q1[1:0], i_a[71:0]} : {i_b[105:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[105:74], b1[1:0], i_b[71:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[105:72], q1[1:0], i_a[69:0]} : {i_b[105:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[105:72], b1[1:0], i_b[69:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[105:70], q1[1:0], i_a[67:0]} : {i_b[105:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[105:70], b1[1:0], i_b[67:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[105:68], q1[1:0], i_a[65:0]} : {i_b[105:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[105:68], b1[1:0], i_b[65:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[105:66], q1[1:0], i_a[63:0]} : {i_b[105:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[105:66], b1[1:0], i_b[63:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[105:64], q1[1:0], i_a[61:0]} : {i_b[105:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[105:64], b1[1:0], i_b[61:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[105:62], q1[1:0], i_a[59:0]} : {i_b[105:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[105:62], b1[1:0], i_b[59:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[105:60], q1[1:0], i_a[57:0]} : {i_b[105:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[105:60], b1[1:0], i_b[57:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[105:58], q1[1:0], i_a[55:0]} : {i_b[105:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[105:58], b1[1:0], i_b[55:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[105:56], q1[1:0], i_a[53:0]} : {i_b[105:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[105:56], b1[1:0], i_b[53:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[105:54], q1[1:0], i_a[51:0]} : {i_b[105:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[105:54], b1[1:0], i_b[51:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[105:52], q1[1:0], i_a[49:0]} : {i_b[105:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[105:52], b1[1:0], i_b[49:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[105:50], q1[1:0], i_a[47:0]} : {i_b[105:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[105:50], b1[1:0], i_b[47:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[105:48], q1[1:0], i_a[45:0]} : {i_b[105:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[105:48], b1[1:0], i_b[45:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[105:46], q1[1:0], i_a[43:0]} : {i_b[105:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[105:46], b1[1:0], i_b[43:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[105:44], q1[1:0], i_a[41:0]} : {i_b[105:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[105:44], b1[1:0], i_b[41:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[105:42], q1[1:0], i_a[39:0]} : {i_b[105:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[105:42], b1[1:0], i_b[39:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[105:40], q1[1:0], i_a[37:0]} : {i_b[105:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[105:40], b1[1:0], i_b[37:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[105:38], q1[1:0], i_a[35:0]} : {i_b[105:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[105:38], b1[1:0], i_b[35:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[105:36], q1[1:0], i_a[33:0]} : {i_b[105:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[105:36], b1[1:0], i_b[33:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[105:34], q1[1:0], i_a[31:0]} : {i_b[105:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[105:34], b1[1:0], i_b[31:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[105:32], q1[1:0], i_a[29:0]} : {i_b[105:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[105:32], b1[1:0], i_b[29:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[105:30], q1[1:0], i_a[27:0]} : {i_b[105:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[105:30], b1[1:0], i_b[27:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[105:28], q1[1:0], i_a[25:0]} : {i_b[105:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[105:28], b1[1:0], i_b[25:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[105:26], q1[1:0], i_a[23:0]} : {i_b[105:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[105:26], b1[1:0], i_b[23:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[105:24], q1[1:0], i_a[21:0]} : {i_b[105:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[105:24], b1[1:0], i_b[21:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[105:22], q1[1:0], i_a[19:0]} : {i_b[105:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[105:22], b1[1:0], i_b[19:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[105:20], q1[1:0], i_a[17:0]} : {i_b[105:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[105:20], b1[1:0], i_b[17:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[105:18], q1[1:0], i_a[15:0]} : {i_b[105:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[105:18], b1[1:0], i_b[15:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[105:16], q1[1:0], i_a[13:0]} : {i_b[105:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[105:16], b1[1:0], i_b[13:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[105:14], q1[1:0], i_a[11:0]} : {i_b[105:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[105:14], b1[1:0], i_b[11:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[105:12], q1[1:0], i_a[9:0]} : {i_b[105:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[105:12], b1[1:0], i_b[9:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[105:10], q1[1:0], i_a[7:0]} : {i_b[105:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[105:10], b1[1:0], i_b[7:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[105:8], q1[1:0], i_a[5:0]} : {i_b[105:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[105:8], b1[1:0], i_b[5:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[105:6], q1[1:0], i_a[3:0]} : {i_b[105:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[105:6], b1[1:0], i_b[3:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[105:4], q1[1:0], i_a[1:0]} : {i_b[105:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[105:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[105:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd101:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[106:105], q1[1:0], i_a[102:0]} : {i_b[106:105], a1[1:0], i_b[102:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:105], q1[1:0]-2'b1, i_a[102:0]} : {i_b[106:105], b1[1:0], i_b[102:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[106:103], q1[1:0], i_a[100:0]} : {i_b[106:103], a1[1:0], i_b[100:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:103], q1[1:0]-2'b1, i_a[100:0]} : {i_b[106:103], b1[1:0], i_b[100:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[106:101], q1[1:0], i_a[98:0]} : {i_b[106:101], a1[1:0], i_b[98:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:101], q1[1:0]-2'b1, i_a[98:0]} : {i_b[106:101], b1[1:0], i_b[98:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[106:99], q1[1:0], i_a[96:0]} : {i_b[106:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[106:99], b1[1:0], i_b[96:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[106:97], q1[1:0], i_a[94:0]} : {i_b[106:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[106:97], b1[1:0], i_b[94:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[106:95], q1[1:0], i_a[92:0]} : {i_b[106:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[106:95], b1[1:0], i_b[92:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[106:93], q1[1:0], i_a[90:0]} : {i_b[106:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[106:93], b1[1:0], i_b[90:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[106:91], q1[1:0], i_a[88:0]} : {i_b[106:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[106:91], b1[1:0], i_b[88:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[106:89], q1[1:0], i_a[86:0]} : {i_b[106:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[106:89], b1[1:0], i_b[86:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[106:87], q1[1:0], i_a[84:0]} : {i_b[106:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[106:87], b1[1:0], i_b[84:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[106:85], q1[1:0], i_a[82:0]} : {i_b[106:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[106:85], b1[1:0], i_b[82:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[106:83], q1[1:0], i_a[80:0]} : {i_b[106:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[106:83], b1[1:0], i_b[80:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[106:81], q1[1:0], i_a[78:0]} : {i_b[106:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[106:81], b1[1:0], i_b[78:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[106:79], q1[1:0], i_a[76:0]} : {i_b[106:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[106:79], b1[1:0], i_b[76:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[106:77], q1[1:0], i_a[74:0]} : {i_b[106:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[106:77], b1[1:0], i_b[74:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[106:75], q1[1:0], i_a[72:0]} : {i_b[106:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[106:75], b1[1:0], i_b[72:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[106:73], q1[1:0], i_a[70:0]} : {i_b[106:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[106:73], b1[1:0], i_b[70:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[106:71], q1[1:0], i_a[68:0]} : {i_b[106:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[106:71], b1[1:0], i_b[68:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[106:69], q1[1:0], i_a[66:0]} : {i_b[106:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[106:69], b1[1:0], i_b[66:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[106:67], q1[1:0], i_a[64:0]} : {i_b[106:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[106:67], b1[1:0], i_b[64:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[106:65], q1[1:0], i_a[62:0]} : {i_b[106:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[106:65], b1[1:0], i_b[62:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[106:63], q1[1:0], i_a[60:0]} : {i_b[106:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[106:63], b1[1:0], i_b[60:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[106:61], q1[1:0], i_a[58:0]} : {i_b[106:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[106:61], b1[1:0], i_b[58:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[106:59], q1[1:0], i_a[56:0]} : {i_b[106:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[106:59], b1[1:0], i_b[56:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[106:57], q1[1:0], i_a[54:0]} : {i_b[106:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[106:57], b1[1:0], i_b[54:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[106:55], q1[1:0], i_a[52:0]} : {i_b[106:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[106:55], b1[1:0], i_b[52:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[106:53], q1[1:0], i_a[50:0]} : {i_b[106:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[106:53], b1[1:0], i_b[50:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[106:51], q1[1:0], i_a[48:0]} : {i_b[106:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[106:51], b1[1:0], i_b[48:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[106:49], q1[1:0], i_a[46:0]} : {i_b[106:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[106:49], b1[1:0], i_b[46:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[106:47], q1[1:0], i_a[44:0]} : {i_b[106:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[106:47], b1[1:0], i_b[44:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[106:45], q1[1:0], i_a[42:0]} : {i_b[106:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[106:45], b1[1:0], i_b[42:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[106:43], q1[1:0], i_a[40:0]} : {i_b[106:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[106:43], b1[1:0], i_b[40:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[106:41], q1[1:0], i_a[38:0]} : {i_b[106:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[106:41], b1[1:0], i_b[38:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[106:39], q1[1:0], i_a[36:0]} : {i_b[106:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[106:39], b1[1:0], i_b[36:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[106:37], q1[1:0], i_a[34:0]} : {i_b[106:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[106:37], b1[1:0], i_b[34:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[106:35], q1[1:0], i_a[32:0]} : {i_b[106:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[106:35], b1[1:0], i_b[32:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[106:33], q1[1:0], i_a[30:0]} : {i_b[106:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[106:33], b1[1:0], i_b[30:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[106:31], q1[1:0], i_a[28:0]} : {i_b[106:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[106:31], b1[1:0], i_b[28:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[106:29], q1[1:0], i_a[26:0]} : {i_b[106:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[106:29], b1[1:0], i_b[26:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[106:27], q1[1:0], i_a[24:0]} : {i_b[106:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[106:27], b1[1:0], i_b[24:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[106:25], q1[1:0], i_a[22:0]} : {i_b[106:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[106:25], b1[1:0], i_b[22:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[106:23], q1[1:0], i_a[20:0]} : {i_b[106:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[106:23], b1[1:0], i_b[20:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[106:21], q1[1:0], i_a[18:0]} : {i_b[106:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[106:21], b1[1:0], i_b[18:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[106:19], q1[1:0], i_a[16:0]} : {i_b[106:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[106:19], b1[1:0], i_b[16:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[106:17], q1[1:0], i_a[14:0]} : {i_b[106:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[106:17], b1[1:0], i_b[14:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[106:15], q1[1:0], i_a[12:0]} : {i_b[106:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[106:15], b1[1:0], i_b[12:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[106:13], q1[1:0], i_a[10:0]} : {i_b[106:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[106:13], b1[1:0], i_b[10:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[106:11], q1[1:0], i_a[8:0]} : {i_b[106:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[106:11], b1[1:0], i_b[8:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[106:9], q1[1:0], i_a[6:0]} : {i_b[106:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[106:9], b1[1:0], i_b[6:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[106:7], q1[1:0], i_a[4:0]} : {i_b[106:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[106:7], b1[1:0], i_b[4:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[106:5], q1[1:0], i_a[2:0]} : {i_b[106:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[106:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[106:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd102:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[107:106], q1[1:0], i_a[103:0]} : {i_b[107:106], a1[1:0], i_b[103:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:106], q1[1:0]-2'b1, i_a[103:0]} : {i_b[107:106], b1[1:0], i_b[103:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[107:104], q1[1:0], i_a[101:0]} : {i_b[107:104], a1[1:0], i_b[101:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:104], q1[1:0]-2'b1, i_a[101:0]} : {i_b[107:104], b1[1:0], i_b[101:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[107:102], q1[1:0], i_a[99:0]} : {i_b[107:102], a1[1:0], i_b[99:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:102], q1[1:0]-2'b1, i_a[99:0]} : {i_b[107:102], b1[1:0], i_b[99:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[107:100], q1[1:0], i_a[97:0]} : {i_b[107:100], a1[1:0], i_b[97:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:100], q1[1:0]-2'b1, i_a[97:0]} : {i_b[107:100], b1[1:0], i_b[97:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[107:98], q1[1:0], i_a[95:0]} : {i_b[107:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[107:98], b1[1:0], i_b[95:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[107:96], q1[1:0], i_a[93:0]} : {i_b[107:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[107:96], b1[1:0], i_b[93:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[107:94], q1[1:0], i_a[91:0]} : {i_b[107:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[107:94], b1[1:0], i_b[91:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[107:92], q1[1:0], i_a[89:0]} : {i_b[107:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[107:92], b1[1:0], i_b[89:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[107:90], q1[1:0], i_a[87:0]} : {i_b[107:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[107:90], b1[1:0], i_b[87:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[107:88], q1[1:0], i_a[85:0]} : {i_b[107:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[107:88], b1[1:0], i_b[85:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[107:86], q1[1:0], i_a[83:0]} : {i_b[107:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[107:86], b1[1:0], i_b[83:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[107:84], q1[1:0], i_a[81:0]} : {i_b[107:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[107:84], b1[1:0], i_b[81:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[107:82], q1[1:0], i_a[79:0]} : {i_b[107:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[107:82], b1[1:0], i_b[79:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[107:80], q1[1:0], i_a[77:0]} : {i_b[107:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[107:80], b1[1:0], i_b[77:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[107:78], q1[1:0], i_a[75:0]} : {i_b[107:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[107:78], b1[1:0], i_b[75:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[107:76], q1[1:0], i_a[73:0]} : {i_b[107:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[107:76], b1[1:0], i_b[73:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[107:74], q1[1:0], i_a[71:0]} : {i_b[107:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[107:74], b1[1:0], i_b[71:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[107:72], q1[1:0], i_a[69:0]} : {i_b[107:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[107:72], b1[1:0], i_b[69:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[107:70], q1[1:0], i_a[67:0]} : {i_b[107:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[107:70], b1[1:0], i_b[67:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[107:68], q1[1:0], i_a[65:0]} : {i_b[107:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[107:68], b1[1:0], i_b[65:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[107:66], q1[1:0], i_a[63:0]} : {i_b[107:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[107:66], b1[1:0], i_b[63:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[107:64], q1[1:0], i_a[61:0]} : {i_b[107:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[107:64], b1[1:0], i_b[61:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[107:62], q1[1:0], i_a[59:0]} : {i_b[107:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[107:62], b1[1:0], i_b[59:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[107:60], q1[1:0], i_a[57:0]} : {i_b[107:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[107:60], b1[1:0], i_b[57:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[107:58], q1[1:0], i_a[55:0]} : {i_b[107:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[107:58], b1[1:0], i_b[55:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[107:56], q1[1:0], i_a[53:0]} : {i_b[107:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[107:56], b1[1:0], i_b[53:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[107:54], q1[1:0], i_a[51:0]} : {i_b[107:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[107:54], b1[1:0], i_b[51:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[107:52], q1[1:0], i_a[49:0]} : {i_b[107:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[107:52], b1[1:0], i_b[49:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[107:50], q1[1:0], i_a[47:0]} : {i_b[107:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[107:50], b1[1:0], i_b[47:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[107:48], q1[1:0], i_a[45:0]} : {i_b[107:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[107:48], b1[1:0], i_b[45:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[107:46], q1[1:0], i_a[43:0]} : {i_b[107:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[107:46], b1[1:0], i_b[43:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[107:44], q1[1:0], i_a[41:0]} : {i_b[107:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[107:44], b1[1:0], i_b[41:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[107:42], q1[1:0], i_a[39:0]} : {i_b[107:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[107:42], b1[1:0], i_b[39:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[107:40], q1[1:0], i_a[37:0]} : {i_b[107:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[107:40], b1[1:0], i_b[37:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[107:38], q1[1:0], i_a[35:0]} : {i_b[107:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[107:38], b1[1:0], i_b[35:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[107:36], q1[1:0], i_a[33:0]} : {i_b[107:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[107:36], b1[1:0], i_b[33:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[107:34], q1[1:0], i_a[31:0]} : {i_b[107:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[107:34], b1[1:0], i_b[31:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[107:32], q1[1:0], i_a[29:0]} : {i_b[107:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[107:32], b1[1:0], i_b[29:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[107:30], q1[1:0], i_a[27:0]} : {i_b[107:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[107:30], b1[1:0], i_b[27:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[107:28], q1[1:0], i_a[25:0]} : {i_b[107:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[107:28], b1[1:0], i_b[25:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[107:26], q1[1:0], i_a[23:0]} : {i_b[107:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[107:26], b1[1:0], i_b[23:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[107:24], q1[1:0], i_a[21:0]} : {i_b[107:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[107:24], b1[1:0], i_b[21:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[107:22], q1[1:0], i_a[19:0]} : {i_b[107:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[107:22], b1[1:0], i_b[19:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[107:20], q1[1:0], i_a[17:0]} : {i_b[107:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[107:20], b1[1:0], i_b[17:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[107:18], q1[1:0], i_a[15:0]} : {i_b[107:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[107:18], b1[1:0], i_b[15:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[107:16], q1[1:0], i_a[13:0]} : {i_b[107:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[107:16], b1[1:0], i_b[13:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[107:14], q1[1:0], i_a[11:0]} : {i_b[107:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[107:14], b1[1:0], i_b[11:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[107:12], q1[1:0], i_a[9:0]} : {i_b[107:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[107:12], b1[1:0], i_b[9:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[107:10], q1[1:0], i_a[7:0]} : {i_b[107:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[107:10], b1[1:0], i_b[7:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[107:8], q1[1:0], i_a[5:0]} : {i_b[107:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[107:8], b1[1:0], i_b[5:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[107:6], q1[1:0], i_a[3:0]} : {i_b[107:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[107:6], b1[1:0], i_b[3:0]};
            end
            10'd52:begin
                a_next = ~q1[2] ? {i_a[107:4], q1[1:0], i_a[1:0]} : {i_b[107:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[107:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[107:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd103:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[108:107], q1[1:0], i_a[104:0]} : {i_b[108:107], a1[1:0], i_b[104:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:107], q1[1:0]-2'b1, i_a[104:0]} : {i_b[108:107], b1[1:0], i_b[104:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[108:105], q1[1:0], i_a[102:0]} : {i_b[108:105], a1[1:0], i_b[102:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:105], q1[1:0]-2'b1, i_a[102:0]} : {i_b[108:105], b1[1:0], i_b[102:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[108:103], q1[1:0], i_a[100:0]} : {i_b[108:103], a1[1:0], i_b[100:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:103], q1[1:0]-2'b1, i_a[100:0]} : {i_b[108:103], b1[1:0], i_b[100:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[108:101], q1[1:0], i_a[98:0]} : {i_b[108:101], a1[1:0], i_b[98:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:101], q1[1:0]-2'b1, i_a[98:0]} : {i_b[108:101], b1[1:0], i_b[98:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[108:99], q1[1:0], i_a[96:0]} : {i_b[108:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[108:99], b1[1:0], i_b[96:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[108:97], q1[1:0], i_a[94:0]} : {i_b[108:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[108:97], b1[1:0], i_b[94:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[108:95], q1[1:0], i_a[92:0]} : {i_b[108:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[108:95], b1[1:0], i_b[92:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[108:93], q1[1:0], i_a[90:0]} : {i_b[108:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[108:93], b1[1:0], i_b[90:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[108:91], q1[1:0], i_a[88:0]} : {i_b[108:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[108:91], b1[1:0], i_b[88:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[108:89], q1[1:0], i_a[86:0]} : {i_b[108:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[108:89], b1[1:0], i_b[86:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[108:87], q1[1:0], i_a[84:0]} : {i_b[108:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[108:87], b1[1:0], i_b[84:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[108:85], q1[1:0], i_a[82:0]} : {i_b[108:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[108:85], b1[1:0], i_b[82:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[108:83], q1[1:0], i_a[80:0]} : {i_b[108:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[108:83], b1[1:0], i_b[80:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[108:81], q1[1:0], i_a[78:0]} : {i_b[108:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[108:81], b1[1:0], i_b[78:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[108:79], q1[1:0], i_a[76:0]} : {i_b[108:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[108:79], b1[1:0], i_b[76:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[108:77], q1[1:0], i_a[74:0]} : {i_b[108:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[108:77], b1[1:0], i_b[74:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[108:75], q1[1:0], i_a[72:0]} : {i_b[108:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[108:75], b1[1:0], i_b[72:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[108:73], q1[1:0], i_a[70:0]} : {i_b[108:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[108:73], b1[1:0], i_b[70:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[108:71], q1[1:0], i_a[68:0]} : {i_b[108:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[108:71], b1[1:0], i_b[68:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[108:69], q1[1:0], i_a[66:0]} : {i_b[108:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[108:69], b1[1:0], i_b[66:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[108:67], q1[1:0], i_a[64:0]} : {i_b[108:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[108:67], b1[1:0], i_b[64:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[108:65], q1[1:0], i_a[62:0]} : {i_b[108:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[108:65], b1[1:0], i_b[62:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[108:63], q1[1:0], i_a[60:0]} : {i_b[108:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[108:63], b1[1:0], i_b[60:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[108:61], q1[1:0], i_a[58:0]} : {i_b[108:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[108:61], b1[1:0], i_b[58:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[108:59], q1[1:0], i_a[56:0]} : {i_b[108:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[108:59], b1[1:0], i_b[56:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[108:57], q1[1:0], i_a[54:0]} : {i_b[108:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[108:57], b1[1:0], i_b[54:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[108:55], q1[1:0], i_a[52:0]} : {i_b[108:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[108:55], b1[1:0], i_b[52:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[108:53], q1[1:0], i_a[50:0]} : {i_b[108:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[108:53], b1[1:0], i_b[50:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[108:51], q1[1:0], i_a[48:0]} : {i_b[108:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[108:51], b1[1:0], i_b[48:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[108:49], q1[1:0], i_a[46:0]} : {i_b[108:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[108:49], b1[1:0], i_b[46:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[108:47], q1[1:0], i_a[44:0]} : {i_b[108:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[108:47], b1[1:0], i_b[44:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[108:45], q1[1:0], i_a[42:0]} : {i_b[108:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[108:45], b1[1:0], i_b[42:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[108:43], q1[1:0], i_a[40:0]} : {i_b[108:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[108:43], b1[1:0], i_b[40:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[108:41], q1[1:0], i_a[38:0]} : {i_b[108:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[108:41], b1[1:0], i_b[38:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[108:39], q1[1:0], i_a[36:0]} : {i_b[108:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[108:39], b1[1:0], i_b[36:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[108:37], q1[1:0], i_a[34:0]} : {i_b[108:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[108:37], b1[1:0], i_b[34:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[108:35], q1[1:0], i_a[32:0]} : {i_b[108:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[108:35], b1[1:0], i_b[32:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[108:33], q1[1:0], i_a[30:0]} : {i_b[108:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[108:33], b1[1:0], i_b[30:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[108:31], q1[1:0], i_a[28:0]} : {i_b[108:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[108:31], b1[1:0], i_b[28:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[108:29], q1[1:0], i_a[26:0]} : {i_b[108:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[108:29], b1[1:0], i_b[26:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[108:27], q1[1:0], i_a[24:0]} : {i_b[108:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[108:27], b1[1:0], i_b[24:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[108:25], q1[1:0], i_a[22:0]} : {i_b[108:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[108:25], b1[1:0], i_b[22:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[108:23], q1[1:0], i_a[20:0]} : {i_b[108:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[108:23], b1[1:0], i_b[20:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[108:21], q1[1:0], i_a[18:0]} : {i_b[108:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[108:21], b1[1:0], i_b[18:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[108:19], q1[1:0], i_a[16:0]} : {i_b[108:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[108:19], b1[1:0], i_b[16:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[108:17], q1[1:0], i_a[14:0]} : {i_b[108:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[108:17], b1[1:0], i_b[14:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[108:15], q1[1:0], i_a[12:0]} : {i_b[108:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[108:15], b1[1:0], i_b[12:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[108:13], q1[1:0], i_a[10:0]} : {i_b[108:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[108:13], b1[1:0], i_b[10:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[108:11], q1[1:0], i_a[8:0]} : {i_b[108:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[108:11], b1[1:0], i_b[8:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[108:9], q1[1:0], i_a[6:0]} : {i_b[108:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[108:9], b1[1:0], i_b[6:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[108:7], q1[1:0], i_a[4:0]} : {i_b[108:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[108:7], b1[1:0], i_b[4:0]};
            end
            10'd52:begin
                a_next = ~q1[2] ? {i_a[108:5], q1[1:0], i_a[2:0]} : {i_b[108:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[108:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[108:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd104:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[109:108], q1[1:0], i_a[105:0]} : {i_b[109:108], a1[1:0], i_b[105:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:108], q1[1:0]-2'b1, i_a[105:0]} : {i_b[109:108], b1[1:0], i_b[105:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[109:106], q1[1:0], i_a[103:0]} : {i_b[109:106], a1[1:0], i_b[103:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:106], q1[1:0]-2'b1, i_a[103:0]} : {i_b[109:106], b1[1:0], i_b[103:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[109:104], q1[1:0], i_a[101:0]} : {i_b[109:104], a1[1:0], i_b[101:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:104], q1[1:0]-2'b1, i_a[101:0]} : {i_b[109:104], b1[1:0], i_b[101:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[109:102], q1[1:0], i_a[99:0]} : {i_b[109:102], a1[1:0], i_b[99:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:102], q1[1:0]-2'b1, i_a[99:0]} : {i_b[109:102], b1[1:0], i_b[99:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[109:100], q1[1:0], i_a[97:0]} : {i_b[109:100], a1[1:0], i_b[97:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:100], q1[1:0]-2'b1, i_a[97:0]} : {i_b[109:100], b1[1:0], i_b[97:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[109:98], q1[1:0], i_a[95:0]} : {i_b[109:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[109:98], b1[1:0], i_b[95:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[109:96], q1[1:0], i_a[93:0]} : {i_b[109:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[109:96], b1[1:0], i_b[93:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[109:94], q1[1:0], i_a[91:0]} : {i_b[109:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[109:94], b1[1:0], i_b[91:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[109:92], q1[1:0], i_a[89:0]} : {i_b[109:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[109:92], b1[1:0], i_b[89:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[109:90], q1[1:0], i_a[87:0]} : {i_b[109:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[109:90], b1[1:0], i_b[87:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[109:88], q1[1:0], i_a[85:0]} : {i_b[109:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[109:88], b1[1:0], i_b[85:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[109:86], q1[1:0], i_a[83:0]} : {i_b[109:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[109:86], b1[1:0], i_b[83:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[109:84], q1[1:0], i_a[81:0]} : {i_b[109:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[109:84], b1[1:0], i_b[81:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[109:82], q1[1:0], i_a[79:0]} : {i_b[109:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[109:82], b1[1:0], i_b[79:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[109:80], q1[1:0], i_a[77:0]} : {i_b[109:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[109:80], b1[1:0], i_b[77:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[109:78], q1[1:0], i_a[75:0]} : {i_b[109:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[109:78], b1[1:0], i_b[75:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[109:76], q1[1:0], i_a[73:0]} : {i_b[109:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[109:76], b1[1:0], i_b[73:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[109:74], q1[1:0], i_a[71:0]} : {i_b[109:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[109:74], b1[1:0], i_b[71:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[109:72], q1[1:0], i_a[69:0]} : {i_b[109:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[109:72], b1[1:0], i_b[69:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[109:70], q1[1:0], i_a[67:0]} : {i_b[109:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[109:70], b1[1:0], i_b[67:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[109:68], q1[1:0], i_a[65:0]} : {i_b[109:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[109:68], b1[1:0], i_b[65:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[109:66], q1[1:0], i_a[63:0]} : {i_b[109:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[109:66], b1[1:0], i_b[63:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[109:64], q1[1:0], i_a[61:0]} : {i_b[109:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[109:64], b1[1:0], i_b[61:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[109:62], q1[1:0], i_a[59:0]} : {i_b[109:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[109:62], b1[1:0], i_b[59:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[109:60], q1[1:0], i_a[57:0]} : {i_b[109:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[109:60], b1[1:0], i_b[57:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[109:58], q1[1:0], i_a[55:0]} : {i_b[109:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[109:58], b1[1:0], i_b[55:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[109:56], q1[1:0], i_a[53:0]} : {i_b[109:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[109:56], b1[1:0], i_b[53:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[109:54], q1[1:0], i_a[51:0]} : {i_b[109:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[109:54], b1[1:0], i_b[51:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[109:52], q1[1:0], i_a[49:0]} : {i_b[109:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[109:52], b1[1:0], i_b[49:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[109:50], q1[1:0], i_a[47:0]} : {i_b[109:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[109:50], b1[1:0], i_b[47:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[109:48], q1[1:0], i_a[45:0]} : {i_b[109:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[109:48], b1[1:0], i_b[45:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[109:46], q1[1:0], i_a[43:0]} : {i_b[109:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[109:46], b1[1:0], i_b[43:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[109:44], q1[1:0], i_a[41:0]} : {i_b[109:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[109:44], b1[1:0], i_b[41:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[109:42], q1[1:0], i_a[39:0]} : {i_b[109:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[109:42], b1[1:0], i_b[39:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[109:40], q1[1:0], i_a[37:0]} : {i_b[109:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[109:40], b1[1:0], i_b[37:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[109:38], q1[1:0], i_a[35:0]} : {i_b[109:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[109:38], b1[1:0], i_b[35:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[109:36], q1[1:0], i_a[33:0]} : {i_b[109:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[109:36], b1[1:0], i_b[33:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[109:34], q1[1:0], i_a[31:0]} : {i_b[109:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[109:34], b1[1:0], i_b[31:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[109:32], q1[1:0], i_a[29:0]} : {i_b[109:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[109:32], b1[1:0], i_b[29:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[109:30], q1[1:0], i_a[27:0]} : {i_b[109:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[109:30], b1[1:0], i_b[27:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[109:28], q1[1:0], i_a[25:0]} : {i_b[109:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[109:28], b1[1:0], i_b[25:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[109:26], q1[1:0], i_a[23:0]} : {i_b[109:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[109:26], b1[1:0], i_b[23:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[109:24], q1[1:0], i_a[21:0]} : {i_b[109:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[109:24], b1[1:0], i_b[21:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[109:22], q1[1:0], i_a[19:0]} : {i_b[109:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[109:22], b1[1:0], i_b[19:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[109:20], q1[1:0], i_a[17:0]} : {i_b[109:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[109:20], b1[1:0], i_b[17:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[109:18], q1[1:0], i_a[15:0]} : {i_b[109:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[109:18], b1[1:0], i_b[15:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[109:16], q1[1:0], i_a[13:0]} : {i_b[109:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[109:16], b1[1:0], i_b[13:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[109:14], q1[1:0], i_a[11:0]} : {i_b[109:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[109:14], b1[1:0], i_b[11:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[109:12], q1[1:0], i_a[9:0]} : {i_b[109:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[109:12], b1[1:0], i_b[9:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[109:10], q1[1:0], i_a[7:0]} : {i_b[109:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[109:10], b1[1:0], i_b[7:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[109:8], q1[1:0], i_a[5:0]} : {i_b[109:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[109:8], b1[1:0], i_b[5:0]};
            end
            10'd52:begin
                a_next = ~q1[2] ? {i_a[109:6], q1[1:0], i_a[3:0]} : {i_b[109:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[109:6], b1[1:0], i_b[3:0]};
            end
            10'd53:begin
                a_next = ~q1[2] ? {i_a[109:4], q1[1:0], i_a[1:0]} : {i_b[109:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[109:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[109:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd105:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[110:109], q1[1:0], i_a[106:0]} : {i_b[110:109], a1[1:0], i_b[106:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:109], q1[1:0]-2'b1, i_a[106:0]} : {i_b[110:109], b1[1:0], i_b[106:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[110:107], q1[1:0], i_a[104:0]} : {i_b[110:107], a1[1:0], i_b[104:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:107], q1[1:0]-2'b1, i_a[104:0]} : {i_b[110:107], b1[1:0], i_b[104:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[110:105], q1[1:0], i_a[102:0]} : {i_b[110:105], a1[1:0], i_b[102:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:105], q1[1:0]-2'b1, i_a[102:0]} : {i_b[110:105], b1[1:0], i_b[102:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[110:103], q1[1:0], i_a[100:0]} : {i_b[110:103], a1[1:0], i_b[100:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:103], q1[1:0]-2'b1, i_a[100:0]} : {i_b[110:103], b1[1:0], i_b[100:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[110:101], q1[1:0], i_a[98:0]} : {i_b[110:101], a1[1:0], i_b[98:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:101], q1[1:0]-2'b1, i_a[98:0]} : {i_b[110:101], b1[1:0], i_b[98:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[110:99], q1[1:0], i_a[96:0]} : {i_b[110:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[110:99], b1[1:0], i_b[96:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[110:97], q1[1:0], i_a[94:0]} : {i_b[110:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[110:97], b1[1:0], i_b[94:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[110:95], q1[1:0], i_a[92:0]} : {i_b[110:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[110:95], b1[1:0], i_b[92:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[110:93], q1[1:0], i_a[90:0]} : {i_b[110:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[110:93], b1[1:0], i_b[90:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[110:91], q1[1:0], i_a[88:0]} : {i_b[110:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[110:91], b1[1:0], i_b[88:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[110:89], q1[1:0], i_a[86:0]} : {i_b[110:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[110:89], b1[1:0], i_b[86:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[110:87], q1[1:0], i_a[84:0]} : {i_b[110:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[110:87], b1[1:0], i_b[84:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[110:85], q1[1:0], i_a[82:0]} : {i_b[110:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[110:85], b1[1:0], i_b[82:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[110:83], q1[1:0], i_a[80:0]} : {i_b[110:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[110:83], b1[1:0], i_b[80:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[110:81], q1[1:0], i_a[78:0]} : {i_b[110:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[110:81], b1[1:0], i_b[78:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[110:79], q1[1:0], i_a[76:0]} : {i_b[110:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[110:79], b1[1:0], i_b[76:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[110:77], q1[1:0], i_a[74:0]} : {i_b[110:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[110:77], b1[1:0], i_b[74:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[110:75], q1[1:0], i_a[72:0]} : {i_b[110:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[110:75], b1[1:0], i_b[72:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[110:73], q1[1:0], i_a[70:0]} : {i_b[110:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[110:73], b1[1:0], i_b[70:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[110:71], q1[1:0], i_a[68:0]} : {i_b[110:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[110:71], b1[1:0], i_b[68:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[110:69], q1[1:0], i_a[66:0]} : {i_b[110:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[110:69], b1[1:0], i_b[66:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[110:67], q1[1:0], i_a[64:0]} : {i_b[110:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[110:67], b1[1:0], i_b[64:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[110:65], q1[1:0], i_a[62:0]} : {i_b[110:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[110:65], b1[1:0], i_b[62:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[110:63], q1[1:0], i_a[60:0]} : {i_b[110:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[110:63], b1[1:0], i_b[60:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[110:61], q1[1:0], i_a[58:0]} : {i_b[110:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[110:61], b1[1:0], i_b[58:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[110:59], q1[1:0], i_a[56:0]} : {i_b[110:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[110:59], b1[1:0], i_b[56:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[110:57], q1[1:0], i_a[54:0]} : {i_b[110:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[110:57], b1[1:0], i_b[54:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[110:55], q1[1:0], i_a[52:0]} : {i_b[110:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[110:55], b1[1:0], i_b[52:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[110:53], q1[1:0], i_a[50:0]} : {i_b[110:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[110:53], b1[1:0], i_b[50:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[110:51], q1[1:0], i_a[48:0]} : {i_b[110:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[110:51], b1[1:0], i_b[48:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[110:49], q1[1:0], i_a[46:0]} : {i_b[110:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[110:49], b1[1:0], i_b[46:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[110:47], q1[1:0], i_a[44:0]} : {i_b[110:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[110:47], b1[1:0], i_b[44:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[110:45], q1[1:0], i_a[42:0]} : {i_b[110:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[110:45], b1[1:0], i_b[42:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[110:43], q1[1:0], i_a[40:0]} : {i_b[110:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[110:43], b1[1:0], i_b[40:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[110:41], q1[1:0], i_a[38:0]} : {i_b[110:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[110:41], b1[1:0], i_b[38:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[110:39], q1[1:0], i_a[36:0]} : {i_b[110:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[110:39], b1[1:0], i_b[36:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[110:37], q1[1:0], i_a[34:0]} : {i_b[110:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[110:37], b1[1:0], i_b[34:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[110:35], q1[1:0], i_a[32:0]} : {i_b[110:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[110:35], b1[1:0], i_b[32:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[110:33], q1[1:0], i_a[30:0]} : {i_b[110:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[110:33], b1[1:0], i_b[30:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[110:31], q1[1:0], i_a[28:0]} : {i_b[110:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[110:31], b1[1:0], i_b[28:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[110:29], q1[1:0], i_a[26:0]} : {i_b[110:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[110:29], b1[1:0], i_b[26:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[110:27], q1[1:0], i_a[24:0]} : {i_b[110:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[110:27], b1[1:0], i_b[24:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[110:25], q1[1:0], i_a[22:0]} : {i_b[110:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[110:25], b1[1:0], i_b[22:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[110:23], q1[1:0], i_a[20:0]} : {i_b[110:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[110:23], b1[1:0], i_b[20:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[110:21], q1[1:0], i_a[18:0]} : {i_b[110:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[110:21], b1[1:0], i_b[18:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[110:19], q1[1:0], i_a[16:0]} : {i_b[110:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[110:19], b1[1:0], i_b[16:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[110:17], q1[1:0], i_a[14:0]} : {i_b[110:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[110:17], b1[1:0], i_b[14:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[110:15], q1[1:0], i_a[12:0]} : {i_b[110:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[110:15], b1[1:0], i_b[12:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[110:13], q1[1:0], i_a[10:0]} : {i_b[110:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[110:13], b1[1:0], i_b[10:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[110:11], q1[1:0], i_a[8:0]} : {i_b[110:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[110:11], b1[1:0], i_b[8:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[110:9], q1[1:0], i_a[6:0]} : {i_b[110:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[110:9], b1[1:0], i_b[6:0]};
            end
            10'd52:begin
                a_next = ~q1[2] ? {i_a[110:7], q1[1:0], i_a[4:0]} : {i_b[110:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[110:7], b1[1:0], i_b[4:0]};
            end
            10'd53:begin
                a_next = ~q1[2] ? {i_a[110:5], q1[1:0], i_a[2:0]} : {i_b[110:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[110:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[110:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd106:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[111:110], q1[1:0], i_a[107:0]} : {i_b[111:110], a1[1:0], i_b[107:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:110], q1[1:0]-2'b1, i_a[107:0]} : {i_b[111:110], b1[1:0], i_b[107:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[111:108], q1[1:0], i_a[105:0]} : {i_b[111:108], a1[1:0], i_b[105:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:108], q1[1:0]-2'b1, i_a[105:0]} : {i_b[111:108], b1[1:0], i_b[105:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[111:106], q1[1:0], i_a[103:0]} : {i_b[111:106], a1[1:0], i_b[103:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:106], q1[1:0]-2'b1, i_a[103:0]} : {i_b[111:106], b1[1:0], i_b[103:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[111:104], q1[1:0], i_a[101:0]} : {i_b[111:104], a1[1:0], i_b[101:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:104], q1[1:0]-2'b1, i_a[101:0]} : {i_b[111:104], b1[1:0], i_b[101:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[111:102], q1[1:0], i_a[99:0]} : {i_b[111:102], a1[1:0], i_b[99:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:102], q1[1:0]-2'b1, i_a[99:0]} : {i_b[111:102], b1[1:0], i_b[99:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[111:100], q1[1:0], i_a[97:0]} : {i_b[111:100], a1[1:0], i_b[97:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:100], q1[1:0]-2'b1, i_a[97:0]} : {i_b[111:100], b1[1:0], i_b[97:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[111:98], q1[1:0], i_a[95:0]} : {i_b[111:98], a1[1:0], i_b[95:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:98], q1[1:0]-2'b1, i_a[95:0]} : {i_b[111:98], b1[1:0], i_b[95:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[111:96], q1[1:0], i_a[93:0]} : {i_b[111:96], a1[1:0], i_b[93:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:96], q1[1:0]-2'b1, i_a[93:0]} : {i_b[111:96], b1[1:0], i_b[93:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[111:94], q1[1:0], i_a[91:0]} : {i_b[111:94], a1[1:0], i_b[91:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:94], q1[1:0]-2'b1, i_a[91:0]} : {i_b[111:94], b1[1:0], i_b[91:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[111:92], q1[1:0], i_a[89:0]} : {i_b[111:92], a1[1:0], i_b[89:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:92], q1[1:0]-2'b1, i_a[89:0]} : {i_b[111:92], b1[1:0], i_b[89:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[111:90], q1[1:0], i_a[87:0]} : {i_b[111:90], a1[1:0], i_b[87:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:90], q1[1:0]-2'b1, i_a[87:0]} : {i_b[111:90], b1[1:0], i_b[87:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[111:88], q1[1:0], i_a[85:0]} : {i_b[111:88], a1[1:0], i_b[85:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:88], q1[1:0]-2'b1, i_a[85:0]} : {i_b[111:88], b1[1:0], i_b[85:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[111:86], q1[1:0], i_a[83:0]} : {i_b[111:86], a1[1:0], i_b[83:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:86], q1[1:0]-2'b1, i_a[83:0]} : {i_b[111:86], b1[1:0], i_b[83:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[111:84], q1[1:0], i_a[81:0]} : {i_b[111:84], a1[1:0], i_b[81:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:84], q1[1:0]-2'b1, i_a[81:0]} : {i_b[111:84], b1[1:0], i_b[81:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[111:82], q1[1:0], i_a[79:0]} : {i_b[111:82], a1[1:0], i_b[79:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:82], q1[1:0]-2'b1, i_a[79:0]} : {i_b[111:82], b1[1:0], i_b[79:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[111:80], q1[1:0], i_a[77:0]} : {i_b[111:80], a1[1:0], i_b[77:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:80], q1[1:0]-2'b1, i_a[77:0]} : {i_b[111:80], b1[1:0], i_b[77:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[111:78], q1[1:0], i_a[75:0]} : {i_b[111:78], a1[1:0], i_b[75:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:78], q1[1:0]-2'b1, i_a[75:0]} : {i_b[111:78], b1[1:0], i_b[75:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[111:76], q1[1:0], i_a[73:0]} : {i_b[111:76], a1[1:0], i_b[73:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:76], q1[1:0]-2'b1, i_a[73:0]} : {i_b[111:76], b1[1:0], i_b[73:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[111:74], q1[1:0], i_a[71:0]} : {i_b[111:74], a1[1:0], i_b[71:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:74], q1[1:0]-2'b1, i_a[71:0]} : {i_b[111:74], b1[1:0], i_b[71:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[111:72], q1[1:0], i_a[69:0]} : {i_b[111:72], a1[1:0], i_b[69:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:72], q1[1:0]-2'b1, i_a[69:0]} : {i_b[111:72], b1[1:0], i_b[69:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[111:70], q1[1:0], i_a[67:0]} : {i_b[111:70], a1[1:0], i_b[67:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:70], q1[1:0]-2'b1, i_a[67:0]} : {i_b[111:70], b1[1:0], i_b[67:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[111:68], q1[1:0], i_a[65:0]} : {i_b[111:68], a1[1:0], i_b[65:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:68], q1[1:0]-2'b1, i_a[65:0]} : {i_b[111:68], b1[1:0], i_b[65:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[111:66], q1[1:0], i_a[63:0]} : {i_b[111:66], a1[1:0], i_b[63:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:66], q1[1:0]-2'b1, i_a[63:0]} : {i_b[111:66], b1[1:0], i_b[63:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[111:64], q1[1:0], i_a[61:0]} : {i_b[111:64], a1[1:0], i_b[61:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:64], q1[1:0]-2'b1, i_a[61:0]} : {i_b[111:64], b1[1:0], i_b[61:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[111:62], q1[1:0], i_a[59:0]} : {i_b[111:62], a1[1:0], i_b[59:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:62], q1[1:0]-2'b1, i_a[59:0]} : {i_b[111:62], b1[1:0], i_b[59:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[111:60], q1[1:0], i_a[57:0]} : {i_b[111:60], a1[1:0], i_b[57:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:60], q1[1:0]-2'b1, i_a[57:0]} : {i_b[111:60], b1[1:0], i_b[57:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[111:58], q1[1:0], i_a[55:0]} : {i_b[111:58], a1[1:0], i_b[55:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:58], q1[1:0]-2'b1, i_a[55:0]} : {i_b[111:58], b1[1:0], i_b[55:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[111:56], q1[1:0], i_a[53:0]} : {i_b[111:56], a1[1:0], i_b[53:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:56], q1[1:0]-2'b1, i_a[53:0]} : {i_b[111:56], b1[1:0], i_b[53:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[111:54], q1[1:0], i_a[51:0]} : {i_b[111:54], a1[1:0], i_b[51:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:54], q1[1:0]-2'b1, i_a[51:0]} : {i_b[111:54], b1[1:0], i_b[51:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[111:52], q1[1:0], i_a[49:0]} : {i_b[111:52], a1[1:0], i_b[49:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:52], q1[1:0]-2'b1, i_a[49:0]} : {i_b[111:52], b1[1:0], i_b[49:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[111:50], q1[1:0], i_a[47:0]} : {i_b[111:50], a1[1:0], i_b[47:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:50], q1[1:0]-2'b1, i_a[47:0]} : {i_b[111:50], b1[1:0], i_b[47:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[111:48], q1[1:0], i_a[45:0]} : {i_b[111:48], a1[1:0], i_b[45:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:48], q1[1:0]-2'b1, i_a[45:0]} : {i_b[111:48], b1[1:0], i_b[45:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[111:46], q1[1:0], i_a[43:0]} : {i_b[111:46], a1[1:0], i_b[43:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:46], q1[1:0]-2'b1, i_a[43:0]} : {i_b[111:46], b1[1:0], i_b[43:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[111:44], q1[1:0], i_a[41:0]} : {i_b[111:44], a1[1:0], i_b[41:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:44], q1[1:0]-2'b1, i_a[41:0]} : {i_b[111:44], b1[1:0], i_b[41:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[111:42], q1[1:0], i_a[39:0]} : {i_b[111:42], a1[1:0], i_b[39:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:42], q1[1:0]-2'b1, i_a[39:0]} : {i_b[111:42], b1[1:0], i_b[39:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[111:40], q1[1:0], i_a[37:0]} : {i_b[111:40], a1[1:0], i_b[37:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:40], q1[1:0]-2'b1, i_a[37:0]} : {i_b[111:40], b1[1:0], i_b[37:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[111:38], q1[1:0], i_a[35:0]} : {i_b[111:38], a1[1:0], i_b[35:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:38], q1[1:0]-2'b1, i_a[35:0]} : {i_b[111:38], b1[1:0], i_b[35:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[111:36], q1[1:0], i_a[33:0]} : {i_b[111:36], a1[1:0], i_b[33:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:36], q1[1:0]-2'b1, i_a[33:0]} : {i_b[111:36], b1[1:0], i_b[33:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[111:34], q1[1:0], i_a[31:0]} : {i_b[111:34], a1[1:0], i_b[31:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:34], q1[1:0]-2'b1, i_a[31:0]} : {i_b[111:34], b1[1:0], i_b[31:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[111:32], q1[1:0], i_a[29:0]} : {i_b[111:32], a1[1:0], i_b[29:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:32], q1[1:0]-2'b1, i_a[29:0]} : {i_b[111:32], b1[1:0], i_b[29:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[111:30], q1[1:0], i_a[27:0]} : {i_b[111:30], a1[1:0], i_b[27:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:30], q1[1:0]-2'b1, i_a[27:0]} : {i_b[111:30], b1[1:0], i_b[27:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[111:28], q1[1:0], i_a[25:0]} : {i_b[111:28], a1[1:0], i_b[25:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:28], q1[1:0]-2'b1, i_a[25:0]} : {i_b[111:28], b1[1:0], i_b[25:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[111:26], q1[1:0], i_a[23:0]} : {i_b[111:26], a1[1:0], i_b[23:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:26], q1[1:0]-2'b1, i_a[23:0]} : {i_b[111:26], b1[1:0], i_b[23:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[111:24], q1[1:0], i_a[21:0]} : {i_b[111:24], a1[1:0], i_b[21:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:24], q1[1:0]-2'b1, i_a[21:0]} : {i_b[111:24], b1[1:0], i_b[21:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[111:22], q1[1:0], i_a[19:0]} : {i_b[111:22], a1[1:0], i_b[19:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:22], q1[1:0]-2'b1, i_a[19:0]} : {i_b[111:22], b1[1:0], i_b[19:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[111:20], q1[1:0], i_a[17:0]} : {i_b[111:20], a1[1:0], i_b[17:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:20], q1[1:0]-2'b1, i_a[17:0]} : {i_b[111:20], b1[1:0], i_b[17:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[111:18], q1[1:0], i_a[15:0]} : {i_b[111:18], a1[1:0], i_b[15:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:18], q1[1:0]-2'b1, i_a[15:0]} : {i_b[111:18], b1[1:0], i_b[15:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[111:16], q1[1:0], i_a[13:0]} : {i_b[111:16], a1[1:0], i_b[13:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:16], q1[1:0]-2'b1, i_a[13:0]} : {i_b[111:16], b1[1:0], i_b[13:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[111:14], q1[1:0], i_a[11:0]} : {i_b[111:14], a1[1:0], i_b[11:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:14], q1[1:0]-2'b1, i_a[11:0]} : {i_b[111:14], b1[1:0], i_b[11:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[111:12], q1[1:0], i_a[9:0]} : {i_b[111:12], a1[1:0], i_b[9:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:12], q1[1:0]-2'b1, i_a[9:0]} : {i_b[111:12], b1[1:0], i_b[9:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[111:10], q1[1:0], i_a[7:0]} : {i_b[111:10], a1[1:0], i_b[7:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:10], q1[1:0]-2'b1, i_a[7:0]} : {i_b[111:10], b1[1:0], i_b[7:0]};
            end
            10'd52:begin
                a_next = ~q1[2] ? {i_a[111:8], q1[1:0], i_a[5:0]} : {i_b[111:8], a1[1:0], i_b[5:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:8], q1[1:0]-2'b1, i_a[5:0]} : {i_b[111:8], b1[1:0], i_b[5:0]};
            end
            10'd53:begin
                a_next = ~q1[2] ? {i_a[111:6], q1[1:0], i_a[3:0]} : {i_b[111:6], a1[1:0], i_b[3:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:6], q1[1:0]-2'b1, i_a[3:0]} : {i_b[111:6], b1[1:0], i_b[3:0]};
            end
            10'd54:begin
                a_next = ~q1[2] ? {i_a[111:4], q1[1:0], i_a[1:0]} : {i_b[111:4], a1[1:0], i_b[1:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[111:4], q1[1:0]-2'b1, i_a[1:0]} : {i_b[111:4], b1[1:0], i_b[1:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
    10'd107:begin
        case(i_temp_1)
            10'd1:begin
                a_next = ~q1[2] ? {i_a[112:111], q1[1:0], i_a[108:0]} : {i_b[112:111], a1[1:0], i_b[108:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:111], q1[1:0]-2'b1, i_a[108:0]} : {i_b[112:111], b1[1:0], i_b[108:0]};
            end
            10'd2:begin
                a_next = ~q1[2] ? {i_a[112:109], q1[1:0], i_a[106:0]} : {i_b[112:109], a1[1:0], i_b[106:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:109], q1[1:0]-2'b1, i_a[106:0]} : {i_b[112:109], b1[1:0], i_b[106:0]};
            end
            10'd3:begin
                a_next = ~q1[2] ? {i_a[112:107], q1[1:0], i_a[104:0]} : {i_b[112:107], a1[1:0], i_b[104:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:107], q1[1:0]-2'b1, i_a[104:0]} : {i_b[112:107], b1[1:0], i_b[104:0]};
            end
            10'd4:begin
                a_next = ~q1[2] ? {i_a[112:105], q1[1:0], i_a[102:0]} : {i_b[112:105], a1[1:0], i_b[102:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:105], q1[1:0]-2'b1, i_a[102:0]} : {i_b[112:105], b1[1:0], i_b[102:0]};
            end
            10'd5:begin
                a_next = ~q1[2] ? {i_a[112:103], q1[1:0], i_a[100:0]} : {i_b[112:103], a1[1:0], i_b[100:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:103], q1[1:0]-2'b1, i_a[100:0]} : {i_b[112:103], b1[1:0], i_b[100:0]};
            end
            10'd6:begin
                a_next = ~q1[2] ? {i_a[112:101], q1[1:0], i_a[98:0]} : {i_b[112:101], a1[1:0], i_b[98:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:101], q1[1:0]-2'b1, i_a[98:0]} : {i_b[112:101], b1[1:0], i_b[98:0]};
            end
            10'd7:begin
                a_next = ~q1[2] ? {i_a[112:99], q1[1:0], i_a[96:0]} : {i_b[112:99], a1[1:0], i_b[96:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:99], q1[1:0]-2'b1, i_a[96:0]} : {i_b[112:99], b1[1:0], i_b[96:0]};
            end
            10'd8:begin
                a_next = ~q1[2] ? {i_a[112:97], q1[1:0], i_a[94:0]} : {i_b[112:97], a1[1:0], i_b[94:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:97], q1[1:0]-2'b1, i_a[94:0]} : {i_b[112:97], b1[1:0], i_b[94:0]};
            end
            10'd9:begin
                a_next = ~q1[2] ? {i_a[112:95], q1[1:0], i_a[92:0]} : {i_b[112:95], a1[1:0], i_b[92:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:95], q1[1:0]-2'b1, i_a[92:0]} : {i_b[112:95], b1[1:0], i_b[92:0]};
            end
            10'd10:begin
                a_next = ~q1[2] ? {i_a[112:93], q1[1:0], i_a[90:0]} : {i_b[112:93], a1[1:0], i_b[90:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:93], q1[1:0]-2'b1, i_a[90:0]} : {i_b[112:93], b1[1:0], i_b[90:0]};
            end
            10'd11:begin
                a_next = ~q1[2] ? {i_a[112:91], q1[1:0], i_a[88:0]} : {i_b[112:91], a1[1:0], i_b[88:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:91], q1[1:0]-2'b1, i_a[88:0]} : {i_b[112:91], b1[1:0], i_b[88:0]};
            end
            10'd12:begin
                a_next = ~q1[2] ? {i_a[112:89], q1[1:0], i_a[86:0]} : {i_b[112:89], a1[1:0], i_b[86:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:89], q1[1:0]-2'b1, i_a[86:0]} : {i_b[112:89], b1[1:0], i_b[86:0]};
            end
            10'd13:begin
                a_next = ~q1[2] ? {i_a[112:87], q1[1:0], i_a[84:0]} : {i_b[112:87], a1[1:0], i_b[84:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:87], q1[1:0]-2'b1, i_a[84:0]} : {i_b[112:87], b1[1:0], i_b[84:0]};
            end
            10'd14:begin
                a_next = ~q1[2] ? {i_a[112:85], q1[1:0], i_a[82:0]} : {i_b[112:85], a1[1:0], i_b[82:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:85], q1[1:0]-2'b1, i_a[82:0]} : {i_b[112:85], b1[1:0], i_b[82:0]};
            end
            10'd15:begin
                a_next = ~q1[2] ? {i_a[112:83], q1[1:0], i_a[80:0]} : {i_b[112:83], a1[1:0], i_b[80:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:83], q1[1:0]-2'b1, i_a[80:0]} : {i_b[112:83], b1[1:0], i_b[80:0]};
            end
            10'd16:begin
                a_next = ~q1[2] ? {i_a[112:81], q1[1:0], i_a[78:0]} : {i_b[112:81], a1[1:0], i_b[78:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:81], q1[1:0]-2'b1, i_a[78:0]} : {i_b[112:81], b1[1:0], i_b[78:0]};
            end
            10'd17:begin
                a_next = ~q1[2] ? {i_a[112:79], q1[1:0], i_a[76:0]} : {i_b[112:79], a1[1:0], i_b[76:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:79], q1[1:0]-2'b1, i_a[76:0]} : {i_b[112:79], b1[1:0], i_b[76:0]};
            end
            10'd18:begin
                a_next = ~q1[2] ? {i_a[112:77], q1[1:0], i_a[74:0]} : {i_b[112:77], a1[1:0], i_b[74:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:77], q1[1:0]-2'b1, i_a[74:0]} : {i_b[112:77], b1[1:0], i_b[74:0]};
            end
            10'd19:begin
                a_next = ~q1[2] ? {i_a[112:75], q1[1:0], i_a[72:0]} : {i_b[112:75], a1[1:0], i_b[72:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:75], q1[1:0]-2'b1, i_a[72:0]} : {i_b[112:75], b1[1:0], i_b[72:0]};
            end
            10'd20:begin
                a_next = ~q1[2] ? {i_a[112:73], q1[1:0], i_a[70:0]} : {i_b[112:73], a1[1:0], i_b[70:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:73], q1[1:0]-2'b1, i_a[70:0]} : {i_b[112:73], b1[1:0], i_b[70:0]};
            end
            10'd21:begin
                a_next = ~q1[2] ? {i_a[112:71], q1[1:0], i_a[68:0]} : {i_b[112:71], a1[1:0], i_b[68:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:71], q1[1:0]-2'b1, i_a[68:0]} : {i_b[112:71], b1[1:0], i_b[68:0]};
            end
            10'd22:begin
                a_next = ~q1[2] ? {i_a[112:69], q1[1:0], i_a[66:0]} : {i_b[112:69], a1[1:0], i_b[66:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:69], q1[1:0]-2'b1, i_a[66:0]} : {i_b[112:69], b1[1:0], i_b[66:0]};
            end
            10'd23:begin
                a_next = ~q1[2] ? {i_a[112:67], q1[1:0], i_a[64:0]} : {i_b[112:67], a1[1:0], i_b[64:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:67], q1[1:0]-2'b1, i_a[64:0]} : {i_b[112:67], b1[1:0], i_b[64:0]};
            end
            10'd24:begin
                a_next = ~q1[2] ? {i_a[112:65], q1[1:0], i_a[62:0]} : {i_b[112:65], a1[1:0], i_b[62:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:65], q1[1:0]-2'b1, i_a[62:0]} : {i_b[112:65], b1[1:0], i_b[62:0]};
            end
            10'd25:begin
                a_next = ~q1[2] ? {i_a[112:63], q1[1:0], i_a[60:0]} : {i_b[112:63], a1[1:0], i_b[60:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:63], q1[1:0]-2'b1, i_a[60:0]} : {i_b[112:63], b1[1:0], i_b[60:0]};
            end
            10'd26:begin
                a_next = ~q1[2] ? {i_a[112:61], q1[1:0], i_a[58:0]} : {i_b[112:61], a1[1:0], i_b[58:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:61], q1[1:0]-2'b1, i_a[58:0]} : {i_b[112:61], b1[1:0], i_b[58:0]};
            end
            10'd27:begin
                a_next = ~q1[2] ? {i_a[112:59], q1[1:0], i_a[56:0]} : {i_b[112:59], a1[1:0], i_b[56:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:59], q1[1:0]-2'b1, i_a[56:0]} : {i_b[112:59], b1[1:0], i_b[56:0]};
            end
            10'd28:begin
                a_next = ~q1[2] ? {i_a[112:57], q1[1:0], i_a[54:0]} : {i_b[112:57], a1[1:0], i_b[54:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:57], q1[1:0]-2'b1, i_a[54:0]} : {i_b[112:57], b1[1:0], i_b[54:0]};
            end
            10'd29:begin
                a_next = ~q1[2] ? {i_a[112:55], q1[1:0], i_a[52:0]} : {i_b[112:55], a1[1:0], i_b[52:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:55], q1[1:0]-2'b1, i_a[52:0]} : {i_b[112:55], b1[1:0], i_b[52:0]};
            end
            10'd30:begin
                a_next = ~q1[2] ? {i_a[112:53], q1[1:0], i_a[50:0]} : {i_b[112:53], a1[1:0], i_b[50:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:53], q1[1:0]-2'b1, i_a[50:0]} : {i_b[112:53], b1[1:0], i_b[50:0]};
            end
            10'd31:begin
                a_next = ~q1[2] ? {i_a[112:51], q1[1:0], i_a[48:0]} : {i_b[112:51], a1[1:0], i_b[48:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:51], q1[1:0]-2'b1, i_a[48:0]} : {i_b[112:51], b1[1:0], i_b[48:0]};
            end
            10'd32:begin
                a_next = ~q1[2] ? {i_a[112:49], q1[1:0], i_a[46:0]} : {i_b[112:49], a1[1:0], i_b[46:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:49], q1[1:0]-2'b1, i_a[46:0]} : {i_b[112:49], b1[1:0], i_b[46:0]};
            end
            10'd33:begin
                a_next = ~q1[2] ? {i_a[112:47], q1[1:0], i_a[44:0]} : {i_b[112:47], a1[1:0], i_b[44:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:47], q1[1:0]-2'b1, i_a[44:0]} : {i_b[112:47], b1[1:0], i_b[44:0]};
            end
            10'd34:begin
                a_next = ~q1[2] ? {i_a[112:45], q1[1:0], i_a[42:0]} : {i_b[112:45], a1[1:0], i_b[42:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:45], q1[1:0]-2'b1, i_a[42:0]} : {i_b[112:45], b1[1:0], i_b[42:0]};
            end
            10'd35:begin
                a_next = ~q1[2] ? {i_a[112:43], q1[1:0], i_a[40:0]} : {i_b[112:43], a1[1:0], i_b[40:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:43], q1[1:0]-2'b1, i_a[40:0]} : {i_b[112:43], b1[1:0], i_b[40:0]};
            end
            10'd36:begin
                a_next = ~q1[2] ? {i_a[112:41], q1[1:0], i_a[38:0]} : {i_b[112:41], a1[1:0], i_b[38:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:41], q1[1:0]-2'b1, i_a[38:0]} : {i_b[112:41], b1[1:0], i_b[38:0]};
            end
            10'd37:begin
                a_next = ~q1[2] ? {i_a[112:39], q1[1:0], i_a[36:0]} : {i_b[112:39], a1[1:0], i_b[36:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:39], q1[1:0]-2'b1, i_a[36:0]} : {i_b[112:39], b1[1:0], i_b[36:0]};
            end
            10'd38:begin
                a_next = ~q1[2] ? {i_a[112:37], q1[1:0], i_a[34:0]} : {i_b[112:37], a1[1:0], i_b[34:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:37], q1[1:0]-2'b1, i_a[34:0]} : {i_b[112:37], b1[1:0], i_b[34:0]};
            end
            10'd39:begin
                a_next = ~q1[2] ? {i_a[112:35], q1[1:0], i_a[32:0]} : {i_b[112:35], a1[1:0], i_b[32:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:35], q1[1:0]-2'b1, i_a[32:0]} : {i_b[112:35], b1[1:0], i_b[32:0]};
            end
            10'd40:begin
                a_next = ~q1[2] ? {i_a[112:33], q1[1:0], i_a[30:0]} : {i_b[112:33], a1[1:0], i_b[30:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:33], q1[1:0]-2'b1, i_a[30:0]} : {i_b[112:33], b1[1:0], i_b[30:0]};
            end
            10'd41:begin
                a_next = ~q1[2] ? {i_a[112:31], q1[1:0], i_a[28:0]} : {i_b[112:31], a1[1:0], i_b[28:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:31], q1[1:0]-2'b1, i_a[28:0]} : {i_b[112:31], b1[1:0], i_b[28:0]};
            end
            10'd42:begin
                a_next = ~q1[2] ? {i_a[112:29], q1[1:0], i_a[26:0]} : {i_b[112:29], a1[1:0], i_b[26:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:29], q1[1:0]-2'b1, i_a[26:0]} : {i_b[112:29], b1[1:0], i_b[26:0]};
            end
            10'd43:begin
                a_next = ~q1[2] ? {i_a[112:27], q1[1:0], i_a[24:0]} : {i_b[112:27], a1[1:0], i_b[24:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:27], q1[1:0]-2'b1, i_a[24:0]} : {i_b[112:27], b1[1:0], i_b[24:0]};
            end
            10'd44:begin
                a_next = ~q1[2] ? {i_a[112:25], q1[1:0], i_a[22:0]} : {i_b[112:25], a1[1:0], i_b[22:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:25], q1[1:0]-2'b1, i_a[22:0]} : {i_b[112:25], b1[1:0], i_b[22:0]};
            end
            10'd45:begin
                a_next = ~q1[2] ? {i_a[112:23], q1[1:0], i_a[20:0]} : {i_b[112:23], a1[1:0], i_b[20:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:23], q1[1:0]-2'b1, i_a[20:0]} : {i_b[112:23], b1[1:0], i_b[20:0]};
            end
            10'd46:begin
                a_next = ~q1[2] ? {i_a[112:21], q1[1:0], i_a[18:0]} : {i_b[112:21], a1[1:0], i_b[18:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:21], q1[1:0]-2'b1, i_a[18:0]} : {i_b[112:21], b1[1:0], i_b[18:0]};
            end
            10'd47:begin
                a_next = ~q1[2] ? {i_a[112:19], q1[1:0], i_a[16:0]} : {i_b[112:19], a1[1:0], i_b[16:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:19], q1[1:0]-2'b1, i_a[16:0]} : {i_b[112:19], b1[1:0], i_b[16:0]};
            end
            10'd48:begin
                a_next = ~q1[2] ? {i_a[112:17], q1[1:0], i_a[14:0]} : {i_b[112:17], a1[1:0], i_b[14:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:17], q1[1:0]-2'b1, i_a[14:0]} : {i_b[112:17], b1[1:0], i_b[14:0]};
            end
            10'd49:begin
                a_next = ~q1[2] ? {i_a[112:15], q1[1:0], i_a[12:0]} : {i_b[112:15], a1[1:0], i_b[12:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:15], q1[1:0]-2'b1, i_a[12:0]} : {i_b[112:15], b1[1:0], i_b[12:0]};
            end
            10'd50:begin
                a_next = ~q1[2] ? {i_a[112:13], q1[1:0], i_a[10:0]} : {i_b[112:13], a1[1:0], i_b[10:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:13], q1[1:0]-2'b1, i_a[10:0]} : {i_b[112:13], b1[1:0], i_b[10:0]};
            end
            10'd51:begin
                a_next = ~q1[2] ? {i_a[112:11], q1[1:0], i_a[8:0]} : {i_b[112:11], a1[1:0], i_b[8:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:11], q1[1:0]-2'b1, i_a[8:0]} : {i_b[112:11], b1[1:0], i_b[8:0]};
            end
            10'd52:begin
                a_next = ~q1[2] ? {i_a[112:9], q1[1:0], i_a[6:0]} : {i_b[112:9], a1[1:0], i_b[6:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:9], q1[1:0]-2'b1, i_a[6:0]} : {i_b[112:9], b1[1:0], i_b[6:0]};
            end
            10'd53:begin
                a_next = ~q1[2] ? {i_a[112:7], q1[1:0], i_a[4:0]} : {i_b[112:7], a1[1:0], i_b[4:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:7], q1[1:0]-2'b1, i_a[4:0]} : {i_b[112:7], b1[1:0], i_b[4:0]};
            end
            10'd54:begin
                a_next = ~q1[2] ? {i_a[112:5], q1[1:0], i_a[2:0]} : {i_b[112:5], a1[1:0], i_b[2:0]};
                b_next = ~q1[2] & (|q1[1:0]) ? {i_a[112:5], q1[1:0]-2'b1, i_a[2:0]} : {i_b[112:5], b1[1:0], i_b[2:0]};
            end
            default: begin a_next = 0; b_next = 0; end
    endcase
    end
endcase

end

    assign o_output_a=a_next;
    assign o_output_b=b_next;
    assign o_output_w=w1;

endmodule
