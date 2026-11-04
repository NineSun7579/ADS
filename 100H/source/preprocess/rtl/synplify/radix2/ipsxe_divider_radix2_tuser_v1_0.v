// Module radix2_tuser
// This module generates tuser signals based on the parameters provided. The tuser signals are generated for the dividend, divisor, and the zero detection.
module ipsxe_divider_radix2_tuser_v1_0
#(
    parameter LATENCY = 5, // Auto latency parameter
    parameter TUSER_WIDTH = 2, // Width of the tuser signal
    parameter DIVIDEND_TUSER = 0, // Flag to decide if tuser for dividend is required
    parameter DIVISOR_TUSER = 0, // Flag to decide if tuser for divisor is required
    parameter ZERO_DETECT = 0, // Flag to decide if zero detection is required
    parameter DIVIDEND_TUSER_WIDTH = 1, // Width of the tuser signal for dividend
    parameter DIVISOR_TUSER_WIDTH = 1 // Width of the tuser signal for divisor
)
( 
    input clk, // Input clock signal
    input rst_n, // Input reset signal
    input clk_en, // Input clock enable signal
    input [DIVIDEND_TUSER_WIDTH-1:0] dividend_tuser, // Input tuser signal for dividend
    input [DIVISOR_TUSER_WIDTH-1:0] divisor_tuser, // Input tuser signal for divisor
    input  divisor_by_zero, // Input signal for zero divisor
    output reg [TUSER_WIDTH-1:0] m_axis_dout_tuser= {TUSER_WIDTH{1'b0}} // Output tuser signal
);

// Intermediary wire for tuser signal
wire [TUSER_WIDTH-1:0] dout_tuser;

// Register to store tuser signal with auto latency
reg  [TUSER_WIDTH*(LATENCY)-1:0] dout_tuser_itr= {TUSER_WIDTH*(LATENCY){1'b0}};

// The generate block is used to create assign statements for tuser signals for dividend and divisor based on parameters
generate
    // When DIVIDEND_TUSER is 1, assign part of dout_tuser to dividend_tuser
    if (DIVIDEND_TUSER == 1) begin
        assign dout_tuser[TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH] = dividend_tuser;
    end
endgenerate

generate
    // When DIVISOR_TUSER is 1, assign part of dout_tuser to divisor_tuser
    if (DIVISOR_TUSER == 1) begin
        assign dout_tuser[TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-DIVISOR_TUSER_WIDTH] = divisor_tuser;
    end
endgenerate

generate
    // When ZERO_DETECT is 1, assign least significant bit of dout_tuser to divisor_by_zero
    if (ZERO_DETECT == 1) begin
        assign dout_tuser[0] = divisor_by_zero;
    end
endgenerate

// Always block for generating the final tuser signal with auto latency
wire [TUSER_WIDTH-1:0] m_axis_dout_tuser_wire;
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        m_axis_dout_tuser <= {(TUSER_WIDTH){1'b0}};
    end
    else if(clk_en) begin
        m_axis_dout_tuser <= m_axis_dout_tuser_wire;
    end
    else begin
        m_axis_dout_tuser <= m_axis_dout_tuser;
    end
end
ipsxe_divider_radix2_distributed_shiftregister_wrapper_v1_3  #(
	.FIXED_DEPTH(LATENCY),
	.DATA_WIDTH(TUSER_WIDTH)
) u_ipm_distributed_shiftregister_wrapper_v1_3 (
	.din(dout_tuser),
	.clk(clk),
	.i_aclken(clk_en),
	.rst(!rst_n),
	.dout(m_axis_dout_tuser_wire)
);

endmodule
