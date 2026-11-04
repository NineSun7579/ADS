
//The simulaiton data signal updating time should be modified manually to be greater than calculating period of algorithm to get a correct result
//It defaults to 40 which is one period of clk
`timescale 1ns/1ns
module ipsxe_divider_onboard_top_tb();
 
    localparam ARESETN = 1;
    
    localparam ACLKEN = 0;
    
    localparam DIVIDEND_WIDTH = 64;
    
    localparam ROUNDED_DIVIDEND_WIDTH = (DIVIDEND_WIDTH + 7) / 8 * 8;
    
    localparam DIVISOR_WIDTH = 64;
    
    localparam ROUNDED_DIVISOR_WIDTH = (DIVISOR_WIDTH + 7) / 8 * 8;
    
    localparam DIVIDEND_TUSER_WIDTH = 1;
    
    localparam DIVISOR_TUSER_WIDTH = 1;
    
    localparam QUOTIENT_FRACTIONAL_WIDTH = 0;
    
        localparam ZERO_DETECT = 0 ;
    
        localparam SIGNED = 0 ;
    
        localparam CLK_PER_DIVISION = 8 ;
    
        localparam Algorithm_Type = 1 ;
    
        localparam DIVIDEND_TUSER = 0 ;
    
        localparam DIVISOR_TUSER = 0 ;
    
        localparam DIVIDEND_TLAST = 0 ;
    
        localparam DIVISOR_TLAST = 0 ;
    
        localparam TUSER = 0 ;
    
        localparam TLAST = 0 ;
    
        localparam OUTPUT_TREADY = 0 ;
    
        localparam LATENCY = 5 ;
    
        localparam BLOCKING = 0 ;
    
        localparam Remainder_Type = 0 ;
     
        localparam LATENCY_MODE = 0 ;
    
    localparam TUSER_WIDTH = DIVIDEND_TUSER_WIDTH + DIVISOR_TUSER_WIDTH + ZERO_DETECT;
    
    parameter   DOUT_TDATA_QUOTIENT = (DIVIDEND_WIDTH<=8)?8:((DIVIDEND_WIDTH>(DIVIDEND_WIDTH>>3)*8)?
    ((DIVIDEND_WIDTH>>3)+1)*8:(DIVIDEND_WIDTH>>3)*8);
    parameter  DOUT_TDATA_REMAINDER = (DIVISOR_WIDTH<=8)?8:((DIVISOR_WIDTH>(DIVISOR_WIDTH>>3)*8)?
    ((DIVISOR_WIDTH>>3)+1)*8:(DIVISOR_WIDTH>>3)*8);
    
    reg aclk = 0;
    reg aresetn = 0;
    
    wire s_axis_dividend_tready;
    wire s_axis_divisor_tready;
    wire m_axis_dout_tvalid;
    
    wire [DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1:0] m_axis_dout_tdata;
    
    wire o_led;
    
    assign    s_axis_dividend_tready = ipsxe_divider_onboard_top_tb.u_ipsxe_divider_onboard_top.o_axi4s_dividend_tready;
    
    assign    s_axis_divisor_tready = ipsxe_divider_onboard_top_tb.u_ipsxe_divider_onboard_top.o_axi4s_divisor_tready;
    
assign    m_axis_dout_tvalid = ipsxe_divider_onboard_top_tb.u_ipsxe_divider_onboard_top.o_axi4s_dout_tvalid;
assign    m_axis_dout_tdata = ipsxe_divider_onboard_top_tb.u_ipsxe_divider_onboard_top.o_axi4s_dout_tdata;
ipsxe_divider_onboard_top u_ipsxe_divider_onboard_top(
    .i_aclk(aclk),
    .i_aresetn(aresetn),

    .o_led(o_led)
);
    
        wire [DOUT_TDATA_QUOTIENT-1:0]dout_tdata_quotient;
        wire [DOUT_TDATA_REMAINDER-1:0]dout_tdata_remainder;
        assign dout_tdata_quotient = m_axis_dout_tdata[(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1):DOUT_TDATA_REMAINDER] ;
        assign dout_tdata_remainder = m_axis_dout_tdata[DOUT_TDATA_REMAINDER-1:0];
        
        reg [DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1:0] expected_outputs_quotient;
        reg [DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1:0] expected_outputs_remainder;
        initial begin
            expected_outputs_quotient = 0;
        end
        initial begin
            expected_outputs_remainder = 0;
        end
        always @(posedge aclk) begin
            if (m_axis_dout_tvalid) begin
                if (dout_tdata_quotient != expected_outputs_quotient || dout_tdata_remainder != expected_outputs_remainder) begin
                    $display("Error at time %t: Expected data quotient: %h remainder: %h, but got quotient: %h remainder: %h", $time, expected_outputs_quotient, expected_outputs_remainder, dout_tdata_quotient, dout_tdata_remainder);

                end else begin
                    $display("Results successfully match at time %t: Expected data quotient: %h remainder: %h, and got quotient: %h remainder: %h", $time, expected_outputs_quotient, expected_outputs_remainder, dout_tdata_quotient, dout_tdata_remainder);

                end
            end
        end
    

initial begin
    aclk = 0;
    forever begin
        #20 aclk = ~aclk;
    end
end
integer i;
initial begin
    aresetn = 1; 
 
#120
     aresetn = 0;
#120
     aresetn = 1;
 
    #14000
    aresetn = 0;
    #80
    $finish; 
end
    
//initial
//begin
//    $fsdbDumpfile("wave.fsdb");
//    $fsdbDumpvars(0,ipsxe_divider_onboard_tb_lane_divider);  
//    $vcdpluson;   
//    $vcdplusmemon;
//end

endmodule
