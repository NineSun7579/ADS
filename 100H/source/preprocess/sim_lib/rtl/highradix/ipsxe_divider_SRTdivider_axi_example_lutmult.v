
module divider_highradix_axi_example_lutmult
#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8,
    parameter FRACTION_WIDTH = 8,
    parameter DIVIDEND_TUSER_WIDTH = 8,
    parameter DIVISOR_TUSER_WIDTH = 8,
    parameter OUTPUT_TLAST = 3,  
    parameter  DOUT_TDATA_QUOTIENT_FRACT = 32,
    parameter  TUSER = 0,
    parameter TUSER_WIDTH = 32
)
( 
 input aclk,

    // `ifdef ARESETN
        input aresetn,
    // `endif
    
    // `ifdef ACLKEN
        input aclken,
    // `endif 
    
    // `ifdef DIVISOR_TUSER
        input  [DIVISOR_TUSER_WIDTH-1:0]s_axis_divisor_tuser,   // input reg s_axis_divisor_tuser,
    // `endif
    
    // `ifdef DIVISOR_TLAST
        input  s_axis_divisor_tlast,   // input reg s_axis_divisor_tlast, 
    // `endif 
    

    input  [DIVISOR_WIDTH-1:0]s_axis_divisor_tdata,   // input reg s_axis_divisor_tdata,
    input  s_axis_dividend_tvalid, // input reg s_axis_dividend_tvadlid,

    
    // `ifdef DIVIDEND_TUSER
        input  [DIVIDEND_TUSER_WIDTH-1:0]s_axis_dividend_tuser,  // input reg s_axis_dividend_tuser,
    // `endif
    
    // `ifdef DIVIDEND_TLAST
        input  s_axis_dividend_tlast,  // input reg s_axis_dividend_tlast,
    // `endif
    

    input  [DIVIDEND_WIDTH-1:0]s_axis_dividend_tdata,  // input reg s_axis_dividend_tdata,
    input  s_axis_divisor_tvalid, // input reg s_axis_divisor_tvalid,

    output  s_axis_divisor_tready,  // output  s_axis_divisor_tready
    output  s_axis_dividend_tready, // output  s_axis_dividend_tready,
    output reg m_axis_dout_tvalid,     // output  m_axis_dout_tvalid,

    
    // `ifdef TUSER
        output wire [TUSER_WIDTH-1:0]m_axis_dout_tuser,      // output reg m_axis_dout_tuser
    // `endif
    
    // `ifdef TLAST
        output reg m_axis_dout_tlast,      // output reg m_axis_dout_tlast
    // `endif
    
         output reg [(DOUT_TDATA_QUOTIENT_FRACT-1):0]m_axis_dout_tdata
   

);   

//********************************************************************************************
//                                          DEFINE(OK)
//********************************************************************************************


 parameter AUTO_LATENCY = ((DIVIDEND_WIDTH+FRACTION_WIDTH)/2+6);

//********************************************************************************************
//                                          DECLARATION(OK)
//********************************************************************************************
  
/*****************************************************************************/
wire clk;     
wire rst_n;
wire clk_en;
wire dout_tready;

wire [DIVIDEND_WIDTH+FRACTION_WIDTH-1'b1:1'b0] quotient;
wire dout_tvalid;

reg  [AUTO_LATENCY-1:0] dout_tvalid_itr; 

wire q_valid;

assign clk = aclk;

 
// `ifdef ARESETN
assign rst_n = aresetn;

// `else
assign dout_tready = 1'b1;
// `endif

// `ifdef ACLKEN

assign clk_en = aclken && dout_tready;

//********************************************************************************************
//                                          TUSER(ok)
//********************************************************************************************
    generate 
    if (TUSER == 1) begin
    
    // `ifdef ZERO_DETECT
        wire divisor_by_zero; 
        assign divisor_by_zero = (s_axis_divisor_tdata == 0)? 1'b1 : 1'b0;
    // `endif
    
        SRTdivider_tuser  
        #(
            .AUTO_LATENCY(AUTO_LATENCY),
            .TUSER_WIDTH(TUSER_WIDTH),
            .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
            .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH)
        )
        u_SRTdivider_tuser(
            .clk(clk),               
            .rst_n(rst_n),             
            .clk_en(clk_en),
        
        // `ifdef DIVIDEND_TUSER
            .dividend_tuser(s_axis_dividend_tuser),
        // `endif
        
        // `ifdef DIVISOR_TUSER
            .divisor_tuser(s_axis_divisor_tuser),
        // `endif
        
        // `ifdef ZERO_DETECT
            .divisor_by_zero(divisor_by_zero),
        // `endif
        
            .m_axis_dout_tuser(m_axis_dout_tuser)
        );
    end
    endgenerate

//********************************************************************************************
//                                          DOUT_TVALID(OK)
//********************************************************************************************

    assign dout_tvalid = (s_axis_dividend_tready) && (s_axis_divisor_tready) && (s_axis_dividend_tvalid) && (s_axis_divisor_tvalid);
       
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
            dout_tvalid_itr <= {AUTO_LATENCY{1'b0}}; 
            m_axis_dout_tvalid <= 1'b0;
        end 
        else if(clk_en) begin  
            //dout_tvalid_itr[0] <= dout_tvalid;
            //dout_tvalid_itr[AUTO_LATENCY-1:1] <= dout_tvalid_itr[AUTO_LATENCY-2:0];
	    dout_tvalid_itr <= {dout_tvalid_itr[AUTO_LATENCY-2:0], dout_tvalid};
            m_axis_dout_tvalid <= dout_tvalid_itr[AUTO_LATENCY-1];
        end
    end
    

//********************************************************************************************
//                                          DIN_TREADY
//********************************************************************************************
assign s_axis_dividend_tready = q_valid;
assign s_axis_divisor_tready = q_valid;
//********************************************************************************************
//                                          TDATA(OK)
//********************************************************************************************
srt4divider #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .FRACTION_WIDTH(FRACTION_WIDTH)
) u_srt4divider(
    .i_clk(clk),
    .i_rst_n(rst_n),
    .i_clken(clk_en),
    .i_f(1'b0),
    .i_x(s_axis_dividend_tdata[DIVIDEND_WIDTH-1'b1:0]),
    .i_d(s_axis_divisor_tdata[DIVISOR_WIDTH-1'b1:0]),
    .o_q(quotient),
    .o_q_valid(q_valid)
    );
     
always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        m_axis_dout_tdata <= {(DOUT_TDATA_QUOTIENT_FRACT-1){1'b0}};
    end
    else if(clk_en) begin 
        m_axis_dout_tdata[DOUT_TDATA_QUOTIENT_FRACT-1:0] <= quotient;
    end
    
//********************************************************************************************
//                                          TLAST(OK)
//********************************************************************************************

    
    // `ifdef TLAST
        reg  dout_tlast;
        reg  [AUTO_LATENCY-1:0] dout_tlast_r;
        
        always@(*)
            begin
            case(OUTPUT_TLAST)
            
            3'b011   :   dout_tlast = (s_axis_divisor_tlast)&&(s_axis_dividend_tlast);
              
            default :   dout_tlast = 1'b0;
            endcase
        end
        
        always@(posedge clk or negedge rst_n)
            if(!rst_n) begin
                dout_tlast_r <= {AUTO_LATENCY{1'b0}};
                m_axis_dout_tlast <= 1'b0;

            end
            else if(clk_en) begin 
                dout_tlast_r[0] <= dout_tlast;
                dout_tlast_r[AUTO_LATENCY-1:1] <= dout_tlast_r[AUTO_LATENCY-2:0];
                m_axis_dout_tlast <= dout_tlast_r[AUTO_LATENCY-1];
            end
        
    // `endif
    

   
endmodule
