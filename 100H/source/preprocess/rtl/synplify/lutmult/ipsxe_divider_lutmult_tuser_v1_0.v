module ipsxe_divider_lutmult_tuser_v1_0
#(
    parameter LATENCY = 5,
    parameter TUSER_WIDTH = 2,
    parameter DIVIDEND_TUSER = 0,
    parameter DIVISOR_TUSER = 0,
    parameter ZERO_DETECT = 0,
    parameter DIVIDEND_TUSER_WIDTH = 1,
    parameter DIVISOR_TUSER_WIDTH = 1
)
( 
    input clk,
    input rst_n,
    input clk_en,
    input [DIVIDEND_TUSER_WIDTH-1:0] dividend_tuser,
    input [DIVISOR_TUSER_WIDTH-1:0] divisor_tuser,
    input  divisor_by_zero,
    output reg [TUSER_WIDTH-1:0] m_axis_dout_tuser={(TUSER_WIDTH){1'b0}}
    ); 

    wire [TUSER_WIDTH-1:0] dout_tuser;

    generate
    if (DIVIDEND_TUSER == 1) begin
        assign dout_tuser[TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH] = dividend_tuser;
    end
    endgenerate

    generate
    if (DIVISOR_TUSER == 1) begin
        assign dout_tuser[TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-DIVISOR_TUSER_WIDTH] = divisor_tuser;
    end
    endgenerate

    generate
    if (ZERO_DETECT == 1) begin
        assign dout_tuser[0] = divisor_by_zero;
    end
    endgenerate

    generate
        case(LATENCY)
            1: begin
                always@(posedge clk or negedge rst_n) begin
                    if(!rst_n) m_axis_dout_tuser <= {(TUSER_WIDTH){1'b0}};
                    else if(clk_en) m_axis_dout_tuser <= dout_tuser;
                    else  m_axis_dout_tuser <= m_axis_dout_tuser;
                end
            end
            2: begin
                reg [TUSER_WIDTH-1:0] dout_tuser_itr={(TUSER_WIDTH){1'b0}}; // Single register for LATENCY=2
                
                always@(posedge clk or negedge rst_n) begin
                    if(!rst_n) begin
                        dout_tuser_itr <= {(TUSER_WIDTH){1'b0}};
                        m_axis_dout_tuser <= {(TUSER_WIDTH){1'b0}};
                    end
                    else if(clk_en) begin
                        m_axis_dout_tuser <= dout_tuser_itr;
                        dout_tuser_itr <= dout_tuser;
                    end
                    else begin
                        m_axis_dout_tuser <= m_axis_dout_tuser;
                        dout_tuser_itr <= dout_tuser_itr;
                    end
                end
            end
            default: begin // Handle the cases when LATENCY >= 3
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
        ipsxe_divider_lutmult_distributed_shiftregister_wrapper_v1_3  #(
			.FIXED_DEPTH(LATENCY-1),
			.DATA_WIDTH(TUSER_WIDTH)
		) u_ipm_distributed_shiftregister_wrapper_v1_3 (
			.din(dout_tuser),
			.clk(clk),
			.i_aclken(clk_en),
			.rst(!rst_n),
			.dout(m_axis_dout_tuser_wire)
		);
            end
        endcase
    endgenerate

endmodule

