
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2014 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//
// THE SOURCE CODE CONTAINED HEREIN IS PROPRIETARY TO PANGO MICROSYSTEMS, INC.
// IT SHALL NOT BE REPRODUCED OR DISCLOSED IN WHOLE OR IN PART OR USED BY
// PARTIES WITHOUT WRITTEN AUTHORIZATION FROM THE OWNER.
//
//////////////////////////////////////////////////////////////////////////////
//
// Library:
// Filename:TB example_lutmult_tb.v
//////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps
module example_lutmult_tb();
	reg[9:0] dividend;
	reg[9:0] divisor;
	wire [9:0] quotient;
	wire [9:0] remainder;
	reg rst,clk;
	
	example_lutmult  U_example_lutmult(.rstn(rst),.clk(clk),.dividend(dividend),.divisor(divisor),.quotient(quotient),.remainder(remainder));


	initial begin
		clk = 1;
		forever begin
			#5 clk = ~clk;
		end
	end

	// initial begin
	// 	clk_bram = 0;
	// 	forever begin
	// 		#5 clk_bram = ~clk_bram;
	// 	end
	// end

initial begin
	dividend=10'd0; divisor=10'd0; rst = 0;
	#200
	rst=1'b1;
	// #600  dividend=-11'd32;divisor=11'd3;
	// #600  dividend=-11'd32;divisor=-11'd3;
	// #600  dividend=11'd32;divisor=-11'd3;
	// #600  dividend=11'd32;divisor=11'd3;
	// #600  dividend=11'd16;divisor=11'd2;
	// #600  dividend=11'd10;divisor=11'd4;
	// #600  dividend=11'd6;divisor=11'd1;
	// #600  dividend=11'd24;divisor=11'd16;
	// #600  dividend=11'd2000;divisor=11'd2000;
	#10  dividend=10'd255;divisor=10'd1;
	#10  dividend=10'd255;divisor=10'd255;
	#10  dividend=10'd153;divisor=10'd39;
	#10  dividend=10'd225;divisor=10'd162;
	#10  dividend=-10'd347;divisor=10'd199;
	#10  dividend=10'd510;divisor=-10'd39;
	#800
	rst=0;
	$finish;
end

endmodule
