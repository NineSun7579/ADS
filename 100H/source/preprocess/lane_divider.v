

module lane_divider
(
    i_aclk,

    
        i_aresetn,
     
    
    i_axi4s_divisor_tdata,
    i_axi4s_dividend_tvalid,

    

    i_axi4s_dividend_tdata,
    i_axi4s_divisor_tvalid,

    
    o_axi4s_dividend_tready,
    
    o_axi4s_divisor_tready,
    
    o_axi4s_dout_tvalid,

    

    o_axi4s_dout_tdata

);
    
    localparam ARESETN = 1;
    
    localparam ACLKEN = 0;
    
    localparam DIVIDEND_WIDTH = 64;
    
    localparam ROUNDED_DIVIDEND_WIDTH = (DIVIDEND_WIDTH + 7) / 8 * 8;
    
    
    localparam DIVISOR_WIDTH = 64;
    
    localparam ROUNDED_DIVISOR_WIDTH = (DIVISOR_WIDTH + 7) / 8 * 8;

    
    
    localparam DIVIDEND_TUSER_WIDTH = 1;
    
    localparam DIVISOR_TUSER_WIDTH = 1;
    
    localparam DIVIDEND_TUSER_WIDTH_TRUE = 0;
	
    localparam DIVISOR_TUSER_WIDTH_TRUE = 0;
	
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
    

    // PDS ip_generate omits this constant when TLAST is disabled.
    // NULL is the official Divider template's disabled-TLAST encoding.
    localparam OUTPUT_TLAST = 3'b100;

    localparam TUSER_WIDTH = DIVIDEND_TUSER_WIDTH + DIVISOR_TUSER_WIDTH + ZERO_DETECT;
    localparam TUSER_WIDTH_TRUE = DIVIDEND_TUSER_WIDTH_TRUE + DIVISOR_TUSER_WIDTH_TRUE + ZERO_DETECT;
    
    
    parameter   DOUT_TDATA_QUOTIENT = (DIVIDEND_WIDTH<=8)?8:((DIVIDEND_WIDTH>(DIVIDEND_WIDTH>>3)*8)?
    ((DIVIDEND_WIDTH>>3)+1)*8:(DIVIDEND_WIDTH>>3)*8);
    
    parameter  DOUT_TDATA_REMAINDER = (DIVISOR_WIDTH<=8)?8:((DIVISOR_WIDTH>(DIVISOR_WIDTH>>3)*8)?
    ((DIVISOR_WIDTH>>3)+1)*8:(DIVISOR_WIDTH>>3)*8);
    

  input i_aclk;
    
    // `ifdef ARESETN
        input i_aresetn;
    // `endif
    

    input  [ROUNDED_DIVISOR_WIDTH-1:0]i_axi4s_divisor_tdata;   // input reg i_axi4s_divisor_tdata,
    input  i_axi4s_dividend_tvalid; // input reg s_axis_dividend_tvadlid,

    

    input  [ROUNDED_DIVIDEND_WIDTH-1:0]i_axi4s_dividend_tdata;  // input reg i_axi4s_dividend_tdata,
    input  i_axi4s_divisor_tvalid; // input reg i_axi4s_divisor_tvalid,

    
    output  o_axi4s_dividend_tready; // output  o_axi4s_dividend_tready,
    
    output  o_axi4s_divisor_tready;  // output  o_axi4s_divisor_tready
    
    output  o_axi4s_dout_tvalid;     // output  o_axi4s_dout_tvalid,

    
    output [(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1):0]o_axi4s_dout_tdata;// output reg o_axi4s_dout_tdata


generate
if (BLOCKING == 1) begin
// **********************************************************
//             Global wires
// **********************************************************
    wire                            m_core_tready;
    wire                            m_fifo_a_tvalid;
    wire                            m_fifo_b_tvalid;

//Input Stream
    wire [DIVIDEND_WIDTH-1:0]        m_fifo_a_tdata;
    wire [DIVISOR_WIDTH-1:0]        m_fifo_b_tdata;

//Output Stream
    
    wire [(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1):0]s_fifo_tdata;// output reg o_axi4s_dout_tdata
    
    wire                            s_fifo_tvalid;
    wire                            s_fifo_tready;
    
    
    wire                            s_axis_divisor_tready;    
    wire                            s_axis_dividend_tready;   
    
// **********************************************************
//             Input Stream Buffer
// **********************************************************
    ipsxe_divider_axi_buffer_in_v1_0 #( //parameters
        .TDATA_A_WIDTH              (DIVIDEND_WIDTH),
        .TDATA_B_WIDTH              (DIVISOR_WIDTH),
        .DIVIDEND_TUSER              (DIVIDEND_TUSER),
        .DIVIDEND_TLAST              (DIVIDEND_TLAST),
        .DIVISOR_TUSER              (DIVISOR_TUSER),
        .DIVISOR_TLAST              (DIVISOR_TLAST),
        .TUSER_A_WIDTH              (DIVIDEND_TUSER_WIDTH), //0 for no use
        .TUSER_B_WIDTH              (DIVISOR_TUSER_WIDTH) //0 for no use
    ) u_fifo_in(
        .aclk                       (i_aclk),
    
        .aresetn                    (i_aresetn),
     
        .s_a_tdata                  (i_axi4s_dividend_tdata[DIVIDEND_WIDTH-1:0]),
    
        .s_a_tready                 (o_axi4s_dividend_tready),
    
        .s_b_tready                 (o_axi4s_divisor_tready),
    

        .s_b_tdata                  (i_axi4s_divisor_tdata[DIVISOR_WIDTH-1:0]),

    
    
        .s_a_tlast                  (1'b0),
        .m_a_tlast                  (),
    
        .s_b_tlast                  (1'b0),
        .m_b_tlast                  (),
    
        .s_a_tuser                  (2'b0),
        .m_a_tuser                  (),
    
        .s_b_tuser                  (1'b0),
        .m_b_tuser                  (),
    
        .s_a_tvalid                 (i_axi4s_dividend_tvalid),
        .s_b_tvalid                 (i_axi4s_divisor_tvalid),
        .m_tready                   (s_fifo_tready & s_axis_divisor_tready),
        
        .m_a_tvalid                  (m_fifo_a_tvalid),
        .m_b_tvalid                  (m_fifo_b_tvalid),
        .m_a_tdata                  (m_fifo_a_tdata),
        .m_b_tdata                  (m_fifo_b_tdata)
    );



//********************************************************************************************
//                                          IP_Lutmult_AXI
//********************************************************************************************
if (Algorithm_Type == 2) begin
    ipsxe_divider_lutmult_axi_v1_1
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT(DOUT_TDATA_QUOTIENT),
    .DOUT_TDATA_REMAINDER(DOUT_TDATA_REMAINDER),
    
    .TUSER_WIDTH(TUSER_WIDTH),
    .DIVIDEND_TUSER(DIVIDEND_TUSER),
    .DIVISOR_TUSER(DIVISOR_TUSER),
    .DIVIDEND_TLAST(DIVIDEND_TLAST),
    .DIVISOR_TLAST(DIVISOR_TLAST),
    .TUSER(TUSER),
    .TLAST(TLAST),
    .OUTPUT_TREADY(OUTPUT_TREADY),
    .ZERO_DETECT(ZERO_DETECT),
    .ARESETN(ARESETN),
    .ACLKEN(ACLKEN),
    .SIGNED(SIGNED),
    .LATENCY(LATENCY-1),
    .BLOCKING(BLOCKING)
    )
    u_lutmult_axi_
    (
    .aclk(i_aclk),

    
    .aresetn(i_aresetn),
    
        .aclken(1),
        
    .s_axis_divisor_tuser(1'b0),   // input reg i_axi4s_divisor_tuser,
    
    .s_axis_divisor_tlast(1'b0),   // input reg i_axi4s_divisor_tlast, 
    

    .s_axis_divisor_tdata(m_fifo_b_tdata),   // input reg i_axi4s_divisor_tdata,
    .s_axis_dividend_tvalid(m_fifo_a_tvalid), // input reg s_axis_dividend_tvadlid,

    
    .s_axis_dividend_tuser(1'b0),  // input reg i_axi4s_dividend_tuser,
    
    .s_axis_dividend_tlast(1'b0),  // input reg i_axi4s_dividend_tlast,
    

    .s_axis_dividend_tdata(m_fifo_a_tdata),  // input reg i_axi4s_dividend_tdata,
    .s_axis_divisor_tvalid(m_fifo_b_tvalid), // input reg i_axi4s_divisor_tvalid,

    
    .m_axis_dout_tvalid(o_axi4s_dout_tvalid),     // output  o_axi4s_dout_tvalid,

    
    .m_axis_dout_tuser(),      // output reg o_axi4s_dout_tuser_true
    
    .m_axis_dout_tlast(),      // output reg o_axi4s_dout_tlast
    
        .m_axis_dout_tready(),
    

    .m_axis_dout_tdata(o_axi4s_dout_tdata)
    );
end

//********************************************************************************************
//                                          IP_Radix2_AXI
//********************************************************************************************
else if (Algorithm_Type == 1) begin
ipsxe_divider_radix2_axi_v1_1
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT(DOUT_TDATA_QUOTIENT),
    .DOUT_TDATA_REMAINDER(DOUT_TDATA_REMAINDER),
    
    .Remainder_Type(Remainder_Type),
    .CLK_PER_DIVISION(CLK_PER_DIVISION),
    .TUSER_WIDTH(TUSER_WIDTH),
    .DIVIDEND_TUSER(DIVIDEND_TUSER),
    .DIVISOR_TUSER(DIVISOR_TUSER),
    .DIVIDEND_TLAST(DIVIDEND_TLAST),
    .DIVISOR_TLAST(DIVISOR_TLAST),
    .TUSER(TUSER),
    .TLAST(TLAST),
    .OUTPUT_TREADY(OUTPUT_TREADY),
    .ZERO_DETECT(ZERO_DETECT),
    .ARESETN(ARESETN),
    .ACLKEN(ACLKEN),
    .SIGNED(SIGNED),
    .BLOCKING(BLOCKING),
    .LATENCY_MODE(LATENCY_MODE),
    .LATENCY(LATENCY-2)
    )
    u_radix2_axi
    (
    .aclk(i_aclk),

    
    .aresetn(i_aresetn),
    
    .aclken(1'b1),
    
    .s_axis_divisor_tuser(1'b0),   // input reg i_axi4s_divisor_tuser,
    
    .s_axis_divisor_tlast(1'b0),   // input reg i_axi4s_divisor_tlast, 
    

    .s_axis_divisor_tdata(m_fifo_b_tdata),   // input reg i_axi4s_divisor_tdata,
    .s_axis_dividend_tvalid(m_fifo_a_tvalid), // input reg s_axis_dividend_tvadlid,

    
    .s_axis_dividend_tuser(1'b0),  // input reg i_axi4s_dividend_tuser,
    
    .s_axis_dividend_tlast(1'b0),  // input reg i_axi4s_dividend_tlast,
    

    .s_axis_dividend_tdata(m_fifo_a_tdata),  // input reg i_axi4s_dividend_tdata,
    .s_axis_divisor_tvalid(m_fifo_b_tvalid), // input reg i_axi4s_divisor_tvalid,

    
    .s_axis_divisor_tready(s_axis_divisor_tready), 
    .s_axis_dividend_tready(s_axis_dividend_tready),  
    
    .m_axis_dout_tvalid(s_fifo_tvalid),     // output  o_axi4s_dout_tvalid,

    
    .m_axis_dout_tuser(),      // output reg o_axi4s_dout_tuser_true
    
    .m_axis_dout_tlast(),      // output reg o_axi4s_dout_tlast
    
        .m_axis_dout_tready(),
    

    .m_axis_dout_tdata(s_fifo_tdata)
    );
end
//********************************************************************************************
//                                          IP_HighRadix_AXI
//********************************************************************************************
else begin
ipsxe_divider_highradix_axi
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .FRACTION_WIDTH(QUOTIENT_FRACTIONAL_WIDTH),
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT_FRACT(0),
    
    .TUSER_WIDTH(TUSER_WIDTH),
    .DIVIDEND_TUSER(DIVIDEND_TUSER),
    .DIVISOR_TUSER(DIVISOR_TUSER),
    .DIVIDEND_TLAST(DIVIDEND_TLAST),
    .DIVISOR_TLAST(DIVISOR_TLAST),
    .TUSER(TUSER),
    .TLAST(TLAST),
    .OUTPUT_TREADY(OUTPUT_TREADY),
    .ZERO_DETECT(ZERO_DETECT),
    .ARESETN(ARESETN),
    .ACLKEN(ACLKEN),
    .SIGNED(SIGNED),
    .BLOCKING(BLOCKING),
    .LATENCY(LATENCY-2)
    )
    u_divider_highradix_axi
    (
    .aclk(i_aclk),

    
    .aresetn(i_aresetn),
    
    .aclken(1'b1),
    
    .s_axis_divisor_tuser(1'b0),   // input reg i_axi4s_divisor_tuser,
    
    .s_axis_divisor_tlast(1'b0),   // input reg i_axi4s_divisor_tlast, 
    

    .s_axis_divisor_tdata(m_fifo_b_tdata),   // input reg i_axi4s_divisor_tdata,
    .s_axis_dividend_tvalid(m_fifo_a_tvalid), // input reg s_axis_dividend_tvadlid,

    
    .s_axis_dividend_tuser(1'b0),  // input reg i_axi4s_dividend_tuser,
    
    .s_axis_dividend_tlast(1'b0),  // input reg i_axi4s_dividend_tlast,
    

    .s_axis_dividend_tdata(m_fifo_a_tdata),  // input reg i_axi4s_dividend_tdata,
    .s_axis_divisor_tvalid(m_fifo_b_tvalid), // input reg i_axi4s_divisor_tvalid,

    .s_axis_divisor_tready(m_core_tready),  // output  o_axi4s_divisor_tready
    .s_axis_dividend_tready(), // output  o_axi4s_dividend_tready,
    .m_axis_dout_tvalid(s_fifo_tvalid),     // output  o_axi4s_dout_tvalid,

    
    .m_axis_dout_tuser(),      // output reg o_axi4s_dout_tuser_true
    
    .m_axis_dout_tlast(),      // output reg o_axi4s_dout_tlast
    
        .m_axis_dout_tready(),
    

    .m_axis_dout_tdata(s_fifo_tdata)
    );
end

// **********************************************************
//             Output Stream
// **********************************************************

    ipsxe_divider_axi_buffer_out_v1_0 #( //parameters
    
        .TDATA_A_WIDTH              (DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER),
    
        .USE_TUSER              (TUSER),
        .USE_TLAST              (TLAST),
        .TUSER_A_WIDTH              (TUSER_WIDTH) //0 for no use
    ) u_fifo_out(
        .aclk                       (i_aclk),
    
        .aresetn                    (i_aresetn),
     
        .s_a_tdata                  (s_fifo_tdata),
        .s_a_tvalid                 (s_fifo_tvalid),
        .s_a_tready                 (s_fifo_tready),
    
        .s_a_tuser                  (2'b0),
        .m_a_tuser                  (),
    
        .s_a_tlast                  (1'b0),
        .m_a_tlast                  (),
    
        .m_tready                   (1),
    

        .m_tvalid                   (o_axi4s_dout_tvalid),
        .m_a_tdata                  (o_axi4s_dout_tdata)
    );


end 
else begin //NON_BLOCKING
//********************************************************************************************
//                                          IP_Lutmult_AXI
//********************************************************************************************

if (Algorithm_Type == 2) begin

    assign o_axi4s_divisor_tready = 1;
    assign o_axi4s_dividend_tready = 1;

    ipsxe_divider_lutmult_axi_v1_1
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT(DOUT_TDATA_QUOTIENT),
    .DOUT_TDATA_REMAINDER(DOUT_TDATA_REMAINDER),
    
    .TUSER_WIDTH(TUSER_WIDTH),
    .DIVIDEND_TUSER(DIVIDEND_TUSER),
    .DIVISOR_TUSER(DIVISOR_TUSER),
    .DIVIDEND_TLAST(DIVIDEND_TLAST),
    .DIVISOR_TLAST(DIVISOR_TLAST),
    .TUSER(TUSER),
    .TLAST(TLAST),
    .OUTPUT_TREADY(OUTPUT_TREADY),
    .ZERO_DETECT(ZERO_DETECT),
    .ARESETN(ARESETN),
    .ACLKEN(ACLKEN),
    .SIGNED(SIGNED),
    .LATENCY(LATENCY),
    .BLOCKING(BLOCKING)
    )
    u_lutmult_axi_lane_divider
    (
    .aclk(i_aclk),

    
    .aresetn(i_aresetn),
    
    .aclken(1'b1),
    
    .s_axis_divisor_tuser(1'b0),   // input reg i_axi4s_divisor_tuser,
    
    .s_axis_divisor_tlast(1'b0),   // input reg i_axi4s_divisor_tlast, 
    

    .s_axis_divisor_tdata(i_axi4s_divisor_tdata[DIVISOR_WIDTH-1:0]),   // input reg i_axi4s_divisor_tdata,
    .s_axis_dividend_tvalid(i_axi4s_dividend_tvalid), // input reg s_axis_dividend_tvadlid,

    
    .s_axis_dividend_tuser(1'b0),  // input reg i_axi4s_dividend_tuser,
    
    .s_axis_dividend_tlast(1'b0),  // input reg i_axi4s_dividend_tlast,
    

    .s_axis_dividend_tdata(i_axi4s_dividend_tdata[DIVIDEND_WIDTH-1:0]),  // input reg i_axi4s_dividend_tdata,
    .s_axis_divisor_tvalid(i_axi4s_divisor_tvalid), // input reg i_axi4s_divisor_tvalid,

    
    .m_axis_dout_tvalid(o_axi4s_dout_tvalid),     // output  o_axi4s_dout_tvalid,

    
    .m_axis_dout_tuser(),      // output reg o_axi4s_dout_tuser_true
    
    .m_axis_dout_tlast(),      // output reg o_axi4s_dout_tlast
    
        .m_axis_dout_tready(),
    

    .m_axis_dout_tdata(o_axi4s_dout_tdata)
    );
end

//********************************************************************************************
//                                          IP_Radix2_AXI
//********************************************************************************************
else if (Algorithm_Type == 1) begin
ipsxe_divider_radix2_axi_v1_1
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT(DOUT_TDATA_QUOTIENT),
    .DOUT_TDATA_REMAINDER(DOUT_TDATA_REMAINDER),
    
    .Remainder_Type(Remainder_Type),
    .CLK_PER_DIVISION(CLK_PER_DIVISION),
    .TUSER_WIDTH(TUSER_WIDTH),
    .DIVIDEND_TUSER(DIVIDEND_TUSER),
    .DIVISOR_TUSER(DIVISOR_TUSER),
    .DIVIDEND_TLAST(DIVIDEND_TLAST),
    .DIVISOR_TLAST(DIVISOR_TLAST),
    .TUSER(TUSER),
    .TLAST(TLAST),
    .OUTPUT_TREADY(OUTPUT_TREADY),
    .ZERO_DETECT(ZERO_DETECT),
    .ARESETN(ARESETN),
    .ACLKEN(ACLKEN),
    .SIGNED(SIGNED),
    .BLOCKING(BLOCKING),
    .LATENCY_MODE(LATENCY_MODE),
    .LATENCY(LATENCY)
    )
    u_radix2_axi_lane_divider
    (
    .aclk(i_aclk),

    
    .aresetn(i_aresetn),
    
    .aclken(1'b1),
    
    .s_axis_divisor_tuser(1'b0),   // input reg i_axi4s_divisor_tuser,
    
    .s_axis_divisor_tlast(1'b0),   // input reg i_axi4s_divisor_tlast, 
    

    .s_axis_divisor_tdata(i_axi4s_divisor_tdata[DIVISOR_WIDTH-1:0]),   // input reg i_axi4s_divisor_tdata,
    .s_axis_dividend_tvalid(i_axi4s_dividend_tvalid), // input reg s_axis_dividend_tvadlid,

    
    .s_axis_dividend_tuser(1'b0),  // input reg i_axi4s_dividend_tuser,
    
    .s_axis_dividend_tlast(1'b0),  // input reg i_axi4s_dividend_tlast,
    

    .s_axis_dividend_tdata(i_axi4s_dividend_tdata[DIVIDEND_WIDTH-1:0]),  // input reg i_axi4s_dividend_tdata,
    .s_axis_divisor_tvalid(i_axi4s_divisor_tvalid), // input reg i_axi4s_divisor_tvalid,

    
    .s_axis_divisor_tready(o_axi4s_divisor_tready),  // output  o_axi4s_divisor_tready
    
    .s_axis_dividend_tready(o_axi4s_dividend_tready), // output  o_axi4s_dividend_tready,
    
    .m_axis_dout_tvalid(o_axi4s_dout_tvalid),     // output  o_axi4s_dout_tvalid,

    
    .m_axis_dout_tuser(),      // output reg o_axi4s_dout_tuser_true
    
    .m_axis_dout_tlast(),      // output reg o_axi4s_dout_tlast
    
        .m_axis_dout_tready(),
    

    .m_axis_dout_tdata(o_axi4s_dout_tdata)
    );
end
//********************************************************************************************
//                                          IP_HighRadix_AXI
//********************************************************************************************
else begin
ipsxe_divider_highradix_axi
    #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .FRACTION_WIDTH(QUOTIENT_FRACTIONAL_WIDTH),
    .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
    .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH),
    .OUTPUT_TLAST(OUTPUT_TLAST),
    
    .DOUT_TDATA_QUOTIENT_FRACT(0),
    
    .TUSER_WIDTH(TUSER_WIDTH),
    .DIVIDEND_TUSER(DIVIDEND_TUSER),
    .DIVISOR_TUSER(DIVISOR_TUSER),
    .DIVIDEND_TLAST(DIVIDEND_TLAST),
    .DIVISOR_TLAST(DIVISOR_TLAST),
    .TUSER(TUSER),
    .TLAST(TLAST),
    .OUTPUT_TREADY(OUTPUT_TREADY),
    .ZERO_DETECT(ZERO_DETECT),
    .ARESETN(ARESETN),
    .ACLKEN(ACLKEN),
    .SIGNED(SIGNED),
    .BLOCKING(BLOCKING),
    .LATENCY(LATENCY)
    )
    u_divider_highradix_axi_lane_divider
    (
    .aclk(i_aclk),

    
    .aresetn(i_aresetn),
    
    .aclken(1'b1),
    
    .s_axis_divisor_tuser(1'b0),   // input reg i_axi4s_divisor_tuser,
    
    .s_axis_divisor_tlast(1'b0),   // input reg i_axi4s_divisor_tlast, 
    

    .s_axis_divisor_tdata(i_axi4s_divisor_tdata[DIVISOR_WIDTH-1:0]),   // input reg i_axi4s_divisor_tdata,
    .s_axis_dividend_tvalid(i_axi4s_dividend_tvalid), // input reg s_axis_dividend_tvadlid,

    
    .s_axis_dividend_tuser(1'b0),  // input reg i_axi4s_dividend_tuser,
    
    .s_axis_dividend_tlast(1'b0),  // input reg i_axi4s_dividend_tlast,
    

    .s_axis_dividend_tdata(i_axi4s_dividend_tdata[DIVIDEND_WIDTH-1:0]),  // input reg i_axi4s_dividend_tdata,
    .s_axis_divisor_tvalid(i_axi4s_divisor_tvalid), // input reg i_axi4s_divisor_tvalid,

    
    .s_axis_divisor_tready(o_axi4s_divisor_tready),  // output  o_axi4s_divisor_tready
    
    .s_axis_dividend_tready(o_axi4s_dividend_tready), // output  o_axi4s_dividend_tready,
    
    .m_axis_dout_tvalid(o_axi4s_dout_tvalid),     // output  o_axi4s_dout_tvalid,

    
    .m_axis_dout_tuser(),      // output reg o_axi4s_dout_tuser_true
    
    .m_axis_dout_tlast(),      // output reg o_axi4s_dout_tlast
    
        .m_axis_dout_tready(),
    

    .m_axis_dout_tdata(o_axi4s_dout_tdata)
    );
end

end
endgenerate


endmodule
