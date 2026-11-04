
module divider_radix2_axi_example_lutmult
#(
    parameter DIVIDEND_WIDTH = 8,
    parameter DIVISOR_WIDTH = 8,
    parameter QUOTIENT_FRACTIONAL_WIDTH = 8,
    parameter DIVIDEND_TUSER_WIDTH = 8,
    parameter DIVISOR_TUSER_WIDTH = 8,
    parameter OUTPUT_TLAST = 3,  
    
    parameter  DOUT_TDATA_QUOTIENT = 32,
    parameter  DOUT_TDATA_REMAINDER = 32,
    
    parameter  CLK_PER_DIVISION = 1,
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
    
    // `ifdef DIVIDEND_TUSER
        input  [DIVIDEND_TUSER_WIDTH-1:0]s_axis_dividend_tuser,  // input reg s_axis_dividend_tuser,
    // `endif
    
    // `ifdef DIVIDEND_TLAST
        input  s_axis_dividend_tlast,  // input reg s_axis_dividend_tlast,
    // `endif
    

    input  [DIVIDEND_WIDTH-1:0]s_axis_dividend_tdata,  
    input  s_axis_divisor_tvalid, 
    input  [DIVISOR_WIDTH-1:0]s_axis_divisor_tdata,  
    input  s_axis_dividend_tvalid, 

    output reg s_axis_divisor_tready,  // output  s_axis_divisor_tready
    output reg s_axis_dividend_tready, // output  s_axis_dividend_tready,
    output reg m_axis_dout_tvalid,     // output  m_axis_dout_tvalid,

    
    // `ifdef TUSER
        output wire [TUSER_WIDTH-1:0]m_axis_dout_tuser,      // output reg m_axis_dout_tuser
    // `endif
    
    // `ifdef TLAST
        output reg m_axis_dout_tlast,      // output reg m_axis_dout_tlast
    // `endif
    
            output reg [(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1):0]m_axis_dout_tdata // output reg m_axis_dout_tdata
     
    );


    parameter DIVI_ADDQ_WIDTH = (DIVISOR_WIDTH >= DIVIDEND_WIDTH) ? (DIVISOR_WIDTH) : (DIVIDEND_WIDTH);

    parameter AUTO_LATENCY = DIVI_ADDQ_WIDTH+1;


// `ifdef DETECT_DIVIDE_BY_ZERO
//     parameter DIVISOR_BY_ZERO = 1;
// `else
//     parameter DIVISOR_BY_ZERO = 0;
// `endif

// `ifdef TUSER
//     parameter TUSER_WIDTH = DIVIDEND_TUSER_WIDTH + DIVISOR_TUSER_WIDTH + DIVISOR_BY_ZERO;
// `endif



wire clk;
wire rst_n;
wire clk_en;
wire dout_tready;

// `ifdef CLK_PER_DIVISION_USE  //clk per division count output
//    wire  [$clog2(CLK_PER_DIVISION)-1:0]cnt;
// `else
//    wire   cnt;
// `endif


wire [2:0]cnt;

wire [DIVISOR_WIDTH-1:0]remainder;

wire [DIVIDEND_WIDTH-1:0]quotient;
wire dout_tvalid;

assign clk = aclk;

 
    // `ifdef ARESETN
        assign rst_n = aresetn;
    
    // `else
        assign dout_tready = 1'b1;
    // `endif
    
    // `ifdef ACLKEN
        
        assign clk_en = aclken && dout_tready;
        

    // data packing of TDATA
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) begin
        
            m_axis_dout_tdata <= {(DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1){1'b0}};
             
        end
        else if(clk_en) begin
        
            m_axis_dout_tdata <= {{(DOUT_TDATA_QUOTIENT-DIVIDEND_WIDTH){1'b0}},quotient,{(DOUT_TDATA_REMAINDER-DIVISOR_WIDTH){1'b0}},remainder};
        end
    end


//********************************************************************************************
//                                          TUSER
//********************************************************************************************
    generate 
    if (TUSER == 1) begin
    
    // `ifdef ZERO_DETECT
        wire divisor_by_zero; 
        assign divisor_by_zero = (s_axis_divisor_tdata == 0)? 1'b1 : 1'b0;
    // `endif
    
        radix2_tuser  
        #(
            .AUTO_LATENCY(AUTO_LATENCY),
            .TUSER_WIDTH(TUSER_WIDTH),
            .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
            .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH)
        )
        u_radix2_tuser(
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
//                                          DOUT_TVALID
//********************************************************************************************
    
    
    reg  [AUTO_LATENCY-1:0] dout_tvalid_itr; 
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
    
    
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        s_axis_dividend_tready <= 1'b0;
        s_axis_divisor_tready  <= 1'b0;
    end
    else if(clk_en) begin
            if(cnt == CLK_PER_DIVISION-1'b1)begin
                s_axis_dividend_tready <= 1'b1;
                s_axis_divisor_tready  <= 1'b1;
            end
            else begin
                s_axis_dividend_tready <= 1'b0;
                s_axis_divisor_tready  <= 1'b0;
            end
    end
    else begin
        s_axis_dividend_tready <= 1'b0;
        s_axis_divisor_tready  <= 1'b0;
    end
    end
    
//********************************************************************************************
//                                          IP_CODE
//********************************************************************************************
 
radix2_clk_per_division
#(.CLK_PER_DIVISION(CLK_PER_DIVISION))
u_radix2_clk_per_division(
    .clk(clk),
    .rst_n(rst_n),
    .clk_en(clk_en),
    .cnt(cnt)
);

radix2 #(
    .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
    .DIVISOR_WIDTH(DIVISOR_WIDTH),
    .QUOTIENT_FRACTIONAL_WIDTH(QUOTIENT_FRACTIONAL_WIDTH),
    .CLK_PER_DIVISION(CLK_PER_DIVISION),
    .DIVI_ADDQ_WIDTH(DIVI_ADDQ_WIDTH)
) u_radix2 (
    .clk(clk),
    .rst_n(rst_n),
    .clk_en(clk_en),
    .dividend(s_axis_dividend_tdata[DIVIDEND_WIDTH-1:0]),
    .divisor(s_axis_divisor_tdata[DIVISOR_WIDTH-1:0]),
    .cnt(cnt),
    
    .remainder(remainder),
    
    .quotient(quotient)
    );


//********************************************************************************************
//                                          TLAST
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

