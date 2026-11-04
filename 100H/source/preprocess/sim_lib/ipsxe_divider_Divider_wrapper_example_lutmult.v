

module Divider_wrapper_example_lutmult
(
    aclk,

    
        aresetn,
    
        aclken,
    
        s_axis_divisor_tuser,   // input reg s_axis_divisor_tuser,
    
        s_axis_divisor_tlast,   // input reg s_axis_divisor_tlast, 
     
    
    s_axis_divisor_tdata,
    s_axis_dividend_tvalid,

    
        s_axis_dividend_tuser,  // input reg s_axis_dividend_tuser,
    
        s_axis_dividend_tlast,  // input reg s_axis_dividend_tlast,
    

    s_axis_dividend_tdata,
    s_axis_divisor_tvalid,

    s_axis_divisor_tready,
    s_axis_dividend_tready,
    m_axis_dout_tvalid,

    
        m_axis_dout_tuser,      // output reg m_axis_dout_tuser
    
        m_axis_dout_tlast,      // output reg m_axis_dout_tlast
    

    m_axis_dout_tdata

);

    
    localparam DIVIDEND_WIDTH = 11;
    
    localparam DIVISOR_WIDTH = 11;
    
    localparam DIVIDEND_TUSER_WIDTH = 10;
    
    localparam DIVISOR_TUSER_WIDTH = 10;
    
    localparam QUOTIENT_FRACTIONAL_WIDTH = 11;
    
    localparam OUTPUT_TLAST = 3'b011;
    
        localparam ZERO_DETECT = 1 ;
    
        localparam CLK_PER_DIVISION = 8 ;
    
        localparam Algorithm_Type = 2 ;
    
        localparam TUSER = 1 ;
    




    localparam TUSER_WIDTH = DIVIDEND_TUSER_WIDTH + DIVISOR_TUSER_WIDTH + ZERO_DETECT;
    
    
    parameter   DOUT_TDATA_QUOTIENT = (DIVIDEND_WIDTH<=8)?8:((DIVIDEND_WIDTH>(DIVIDEND_WIDTH>>3)*8)?
    ((DIVIDEND_WIDTH>>3)+1)*8:(DIVIDEND_WIDTH>>3)*8);
    
    parameter  DOUT_TDATA_REMAINDER = (DIVISOR_WIDTH<=8)?8:((DIVISOR_WIDTH>(DIVISOR_WIDTH>>3)*8)?
    ((DIVISOR_WIDTH>>3)+1)*8:(DIVISOR_WIDTH>>3)*8);
    

    input aclk;
    
    // `ifdef ARESETN
        input aresetn;
    // `endif
    
        // `ifdef ACLKEN
        input aclken;
        // `endif 
    
        // `ifdef DIVISOR_TUSER
        input  [DIVISOR_TUSER_WIDTH-1:0]s_axis_divisor_tuser;   // input reg s_axis_divisor_tuser,
        // `endif
    
        // `ifdef DIVISOR_TLAST
        input  s_axis_divisor_tlast;   // input reg s_axis_divisor_tlast, 
        // `endif 
    

    input  [DIVISOR_WIDTH-1:0]s_axis_divisor_tdata;   // input reg s_axis_divisor_tdata,
    input  s_axis_dividend_tvalid; // input reg s_axis_dividend_tvadlid,

    
        // `ifdef DIVIDEND_TUSER
        input  [DIVIDEND_TUSER_WIDTH-1:0]s_axis_dividend_tuser;  // input reg s_axis_dividend_tuser,
        // `endif
    
        // `ifdef DIVIDEND_TLAST
        input  s_axis_dividend_tlast;  // input reg s_axis_dividend_tlast,
        // `endif
    

    input  [DIVIDEND_WIDTH-1:0]s_axis_dividend_tdata;  // input reg s_axis_dividend_tdata,
    input  s_axis_divisor_tvalid; // input reg s_axis_divisor_tvalid,

    output  s_axis_divisor_tready;  // output  s_axis_divisor_tready
    output  s_axis_dividend_tready; // output  s_axis_dividend_tready,
    output  m_axis_dout_tvalid;     // output  m_axis_dout_tvalid,

    
        // `ifdef TUSER
        output  [TUSER_WIDTH-1:0]m_axis_dout_tuser;      // output reg m_axis_dout_tuser
        // `endif
    
        // `ifdef TLAST
        output  m_axis_dout_tlast;      // output reg m_axis_dout_tlast
        // `endif
    
    output [(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1):0]m_axis_dout_tdata;// output reg m_axis_dout_tdata

//********************************************************************************************
//                                          IP_Lutmult_AXI
//********************************************************************************************
generate
if (Algorithm_Type == 2) begin
    Lutmult_axi_example_lutmult
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT(DOUT_TDATA_QUOTIENT),
    .DOUT_TDATA_REMAINDER(DOUT_TDATA_REMAINDER),
    
    .TUSER(TUSER),
    .TUSER_WIDTH(TUSER_WIDTH)
    )
    u_Lutmult_axi_example_lutmult
    (
    .aclk(aclk),

    
    // `ifdef ARESETN
    .aresetn(aresetn),
    // `endif
    
    // `ifdef ACLKEN
    .aclken(aclken),
    // `endif 
    
    // `ifdef DIVISOR_TUSER
    .s_axis_divisor_tuser(s_axis_divisor_tuser),   // input reg s_axis_divisor_tuser,
    // `endif
    
    // `ifdef DIVISOR_TLAST
    .s_axis_divisor_tlast(s_axis_divisor_tlast),   // input reg s_axis_divisor_tlast, 
    // `endif 
    

    .s_axis_divisor_tdata(s_axis_divisor_tdata),   // input reg s_axis_divisor_tdata,
    .s_axis_dividend_tvalid(s_axis_dividend_tvalid), // input reg s_axis_dividend_tvadlid,

    
    // `ifdef DIVIDEND_TUSER
    .s_axis_dividend_tuser(s_axis_dividend_tuser),  // input reg s_axis_dividend_tuser,
    // `endif
    
    // `ifdef DIVIDEND_TLAST
    .s_axis_dividend_tlast(s_axis_dividend_tlast),  // input reg s_axis_dividend_tlast,
    // `endif
    

    .s_axis_dividend_tdata(s_axis_dividend_tdata),  // input reg s_axis_dividend_tdata,
    .s_axis_divisor_tvalid(s_axis_divisor_tvalid), // input reg s_axis_divisor_tvalid,

    .s_axis_divisor_tready(s_axis_divisor_tready),  // output  s_axis_divisor_tready
    .s_axis_dividend_tready(s_axis_dividend_tready), // output  s_axis_dividend_tready,
    .m_axis_dout_tvalid(m_axis_dout_tvalid),     // output  m_axis_dout_tvalid,

    
    // `ifdef TUSER
    .m_axis_dout_tuser(m_axis_dout_tuser),      // output reg m_axis_dout_tuser
    // `endif
    
    // `ifdef TLAST
    .m_axis_dout_tlast(m_axis_dout_tlast),      // output reg m_axis_dout_tlast
    // `endif
    

    .m_axis_dout_tdata(m_axis_dout_tdata)
    );
end

//********************************************************************************************
//                                          IP_Radix2_AXI
//********************************************************************************************
else if (Algorithm_Type == 1) begin
divider_radix2_axi_example_lutmult
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT(DOUT_TDATA_QUOTIENT),
    .DOUT_TDATA_REMAINDER(DOUT_TDATA_REMAINDER),
    
    .CLK_PER_DIVISION(CLK_PER_DIVISION),
    .TUSER(TUSER),
    .TUSER_WIDTH(TUSER_WIDTH)
    )
    u_radix2_axi_example_lutmult
    (
    .aclk(aclk),

    
    // `ifdef ARESETN
    .aresetn(aresetn),
    // `endif
    
    // `ifdef ACLKEN
    .aclken(aclken),
    // `endif 
    
    // `ifdef DIVISOR_TUSER
    .s_axis_divisor_tuser(s_axis_divisor_tuser),   // input reg s_axis_divisor_tuser,
    // `endif
    
    // `ifdef DIVISOR_TLAST
    .s_axis_divisor_tlast(s_axis_divisor_tlast),   // input reg s_axis_divisor_tlast, 
    // `endif 
    

    .s_axis_divisor_tdata(s_axis_divisor_tdata),   // input reg s_axis_divisor_tdata,
    .s_axis_dividend_tvalid(s_axis_dividend_tvalid), // input reg s_axis_dividend_tvadlid,

    
    // `ifdef DIVIDEND_TUSER
    .s_axis_dividend_tuser(s_axis_dividend_tuser),  // input reg s_axis_dividend_tuser,
    // `endif
    
    // `ifdef DIVIDEND_TLAST
    .s_axis_dividend_tlast(s_axis_dividend_tlast),  // input reg s_axis_dividend_tlast,
    // `endif
    

    .s_axis_dividend_tdata(s_axis_dividend_tdata),  // input reg s_axis_dividend_tdata,
    .s_axis_divisor_tvalid(s_axis_divisor_tvalid), // input reg s_axis_divisor_tvalid,

    .s_axis_divisor_tready(s_axis_divisor_tready),  // output  s_axis_divisor_tready
    .s_axis_dividend_tready(s_axis_dividend_tready), // output  s_axis_dividend_tready,
    .m_axis_dout_tvalid(m_axis_dout_tvalid),     // output  m_axis_dout_tvalid,

    
    // `ifdef TUSER
    .m_axis_dout_tuser(m_axis_dout_tuser),      // output reg m_axis_dout_tuser
    // `endif
    
    // `ifdef TLAST
    .m_axis_dout_tlast(m_axis_dout_tlast),      // output reg m_axis_dout_tlast
    // `endif
    

    .m_axis_dout_tdata(m_axis_dout_tdata)
    );
end
//********************************************************************************************
//                                          IP_HighRadix_AXI
//********************************************************************************************
else begin
divider_highradix_axi_example_lutmult
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .FRACTION_WIDTH(QUOTIENT_FRACTIONAL_WIDTH),
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT_FRACT(0),
    
    .TUSER(TUSER),
    .TUSER_WIDTH(TUSER_WIDTH)
    )
    u_divider_highradix_axi_example_lutmult
    (
    .aclk(aclk),

    
    // `ifdef ARESETN
    .aresetn(aresetn),
    // `endif
    
    // `ifdef ACLKEN
    .aclken(aclken),
    // `endif 
    
    // `ifdef DIVISOR_TUSER
    .s_axis_divisor_tuser(s_axis_divisor_tuser),   // input reg s_axis_divisor_tuser,
    // `endif
    
    // `ifdef DIVISOR_TLAST
    .s_axis_divisor_tlast(s_axis_divisor_tlast),   // input reg s_axis_divisor_tlast, 
    // `endif 
    

    .s_axis_divisor_tdata(s_axis_divisor_tdata),   // input reg s_axis_divisor_tdata,
    .s_axis_dividend_tvalid(s_axis_dividend_tvalid), // input reg s_axis_dividend_tvadlid,

    
    // `ifdef DIVIDEND_TUSER
    .s_axis_dividend_tuser(s_axis_dividend_tuser),  // input reg s_axis_dividend_tuser,
    // `endif
    
    // `ifdef DIVIDEND_TLAST
    .s_axis_dividend_tlast(s_axis_dividend_tlast),  // input reg s_axis_dividend_tlast,
    // `endif
    

    .s_axis_dividend_tdata(s_axis_dividend_tdata),  // input reg s_axis_dividend_tdata,
    .s_axis_divisor_tvalid(s_axis_divisor_tvalid), // input reg s_axis_divisor_tvalid,

    .s_axis_divisor_tready(s_axis_divisor_tready),  // output  s_axis_divisor_tready
    .s_axis_dividend_tready(s_axis_dividend_tready), // output  s_axis_dividend_tready,
    .m_axis_dout_tvalid(m_axis_dout_tvalid),     // output  m_axis_dout_tvalid,

    
    // `ifdef TUSER
    .m_axis_dout_tuser(m_axis_dout_tuser),      // output reg m_axis_dout_tuser
    // `endif
    
    // `ifdef TLAST
    .m_axis_dout_tlast(m_axis_dout_tlast),      // output reg m_axis_dout_tlast
    // `endif
    

    .m_axis_dout_tdata(m_axis_dout_tdata)
    );
end
endgenerate

endmodule
