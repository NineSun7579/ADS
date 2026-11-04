

module radix2_tuser
#(
    parameter AUTO_LATENCY = 6,
    parameter TUSER_WIDTH = 2,
    parameter DIVIDEND_TUSER_WIDTH = 1,
    parameter DIVISOR_TUSER_WIDTH = 1
)
( 
    clk,
    rst_n,
    clk_en,
    
    // `ifdef DIVIDEND_TUSER
        dividend_tuser,
    // `endif
    
    // `ifdef DIVISOR_TUSER
        divisor_tuser,
    // `endif
    
    divisor_by_zero,
    
    
    m_axis_dout_tuser 
    );
    input clk;
    input rst_n;
    input clk_en;
    
    // `ifdef DIVIDEND_TUSER
        input [DIVIDEND_TUSER_WIDTH-1:0] dividend_tuser;
    // `endif
    
    // `ifdef DIVISOR_TUSER
        input [DIVISOR_TUSER_WIDTH-1:0] divisor_tuser;
    // `endif
    
    input  divisor_by_zero;
    

    output reg [TUSER_WIDTH-1:0]m_axis_dout_tuser; 

    wire [TUSER_WIDTH-1:0] dout_tuser;

    reg  [TUSER_WIDTH*(AUTO_LATENCY)-1:0] dout_tuser_itr;

    
    // `ifdef DIVIDEND_TUSER
        assign dout_tuser[TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH] = dividend_tuser;
    // `endif 
    
    // `ifdef DIVISOR_TUSER
        assign dout_tuser[TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-1:TUSER_WIDTH-DIVIDEND_TUSER_WIDTH-DIVISOR_TUSER_WIDTH] = divisor_tuser;
    // `endif 
    
    // `ifdef DETECT_DIVIDE_BY_ZERO
        assign dout_tuser[0] = divisor_by_zero;
    // `endif
    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            dout_tuser_itr <= {(TUSER_WIDTH*AUTO_LATENCY){1'b0}};
            m_axis_dout_tuser <= {(TUSER_WIDTH){1'b0}};
        end
        else if(clk_en) begin
            dout_tuser_itr[TUSER_WIDTH-1:0] <= dout_tuser;
            dout_tuser_itr[TUSER_WIDTH*AUTO_LATENCY-1:TUSER_WIDTH] <= dout_tuser_itr[(TUSER_WIDTH)*(AUTO_LATENCY-1)-1:0];
            m_axis_dout_tuser <= dout_tuser_itr[TUSER_WIDTH*AUTO_LATENCY-1:(TUSER_WIDTH)*(AUTO_LATENCY-1)];
        end
    end
    

endmodule

