module ipsxe_divider_lutmult_axi_v1_1
#(
    parameter DIVIDEND_WIDTH = 8,       //the width of dividend
    parameter DIVISOR_WIDTH = 8,        //the width of divisor
    parameter DIVIDEND_TUSER_WIDTH = 8, //the width of tuser in dividend channel
    parameter DIVISOR_TUSER_WIDTH = 8,  //the width of tuser in divisor channel
    parameter OUTPUT_TLAST = 3,         //the mode of tlast in dout channel
    parameter DOUT_TDATA_QUOTIENT = 8,  //the width of quotient axi channel
    parameter DOUT_TDATA_REMAINDER = 8, //the width of integer remainder axi channel
    parameter TUSER_WIDTH = 32,         //the width of tuser in dout channel
    parameter DIVIDEND_TUSER = 0,       //1 means tuser of dividend channel is enabled; 0 means not
    parameter DIVISOR_TUSER = 0,        //1 means tuser of divisor channel is enabled; 0 means not
    parameter DIVIDEND_TLAST = 0,       //1 means tlast of dividend channel is enabled; 0 means not
    parameter DIVISOR_TLAST = 0,        //1 means tlast of divisor channel is enabled; 0 means not
    parameter TUSER = 0,                //1 means tuser of dout channel is enabled; 0 means not
    parameter TLAST = 0,                //1 means tlast of dout channel is enabled; 0 means not
    parameter OUTPUT_TREADY = 0,        //1 means tready of dout channel is enabled; 0 means not
    parameter ZERO_DETECT = 0,          //1 means zero detection is enabled; 0 means not
    parameter ARESETN = 0,              //1 means reset function is enabled; 0 means not
    parameter ACLKEN = 0,               //1 means clk enable function is enabled; 0 means not
    parameter SIGNED = 0,               //1 means signed mode; 0 means unsigned mode
    parameter BLOCKING = 0,              //1 means blocking mode; 0 means non blocking mode
    parameter LATENCY = 4              //1 means blocking mode; 0 means non blocking mode
)
(
    input aclk,     //clk
    input aresetn,  //reset
    input aclken,   //clk enable
    input  [DIVISOR_TUSER_WIDTH-1:0]s_axis_divisor_tuser, //divisor_tuser
    input  s_axis_divisor_tlast,   //  divisor_tlast, 
    input  [DIVISOR_WIDTH-1:0]s_axis_divisor_tdata,   //  divisor_tdata,
    input  s_axis_dividend_tvalid, //  dividend_tvadlid,
    input  [DIVIDEND_TUSER_WIDTH-1:0]s_axis_dividend_tuser,  
    input  s_axis_dividend_tlast,  // divident_tlast
    input  [DIVIDEND_WIDTH-1:0]s_axis_dividend_tdata,  //  dividend_tdata,
    input  s_axis_divisor_tvalid, //  divisor_tvalid,
    input  m_axis_dout_tready,//dout_tready

    // output reg s_axis_divisor_tready=0,  //  divisor_tready
    // output reg s_axis_dividend_tready=0, //  dividend_tready,
    output m_axis_dout_tvalid,     // dout_tvalid,
    output wire [TUSER_WIDTH-1:0]m_axis_dout_tuser,  //dout_tuser  
    output reg m_axis_dout_tlast=0,     //dout_tlast
    output [DOUT_TDATA_QUOTIENT+DOUT_TDATA_REMAINDER-1:0] m_axis_dout_tdata //dout_tdata
);   

    //parameter LATENCY = 5;// The latency of lutmutl algorithm under AUTO mode is 5 clks

    wire clk;     
    wire rst_n;
    wire clk_en;
    wire dout_tready;
    wire [DIVIDEND_WIDTH-1:0]quotient;
    wire [DIVISOR_WIDTH-1:0]remainder;
    reg m_axis_dout_tvalid_r = 0; 
    assign m_axis_dout_tvalid = m_axis_dout_tvalid_r & clk_en;


generate//dout tdata consists of quotient and remainder, adding padding to form the axi tdata channel
    if ((DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH == 0) && (DOUT_TDATA_REMAINDER - DIVISOR_WIDTH == 0)) begin
        assign m_axis_dout_tdata = {quotient, remainder};
    end
    else if ((DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH == 0) && (DOUT_TDATA_REMAINDER - DIVISOR_WIDTH != 0)) begin
        assign m_axis_dout_tdata = {quotient, {DOUT_TDATA_REMAINDER - DIVISOR_WIDTH{remainder[DIVISOR_WIDTH-1]}}, remainder};
    end
    else if ((DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH != 0) && (DOUT_TDATA_REMAINDER - DIVISOR_WIDTH == 0)) begin
        assign m_axis_dout_tdata = {{DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH{quotient[DIVIDEND_WIDTH-1]}}, quotient, remainder};
    end
    else if ((DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH != 0) && (DOUT_TDATA_REMAINDER - DIVISOR_WIDTH != 0)) begin
        assign m_axis_dout_tdata = {{DOUT_TDATA_QUOTIENT - DIVIDEND_WIDTH{quotient[DIVIDEND_WIDTH-1]}}, quotient, {DOUT_TDATA_REMAINDER - DIVISOR_WIDTH{remainder[DIVISOR_WIDTH-1]}}, remainder};
    end
endgenerate

    assign clk = aclk; //global clk
    assign clk_en = aclken; 
    assign rst_n = aresetn;  


//********************************************************************************************
//                                          DOUT_TVALID
//********************************************************************************************=

wire dout_tvalid;

assign dout_tvalid = (clk_en) && (s_axis_dividend_tvalid) && (s_axis_divisor_tvalid);

generate
    if (LATENCY == 1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) m_axis_dout_tvalid_r <= 1'b0;
            else if (clk_en) m_axis_dout_tvalid_r <= dout_tvalid ;
            else  m_axis_dout_tvalid_r <= m_axis_dout_tvalid_r;
        end
    end
    else if (LATENCY == 2) begin
        reg dout_tvalid_itr_1bit=0;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                dout_tvalid_itr_1bit <= 1'b0;
                m_axis_dout_tvalid_r <= 1'b0;
            end
            else if (clk_en) begin
                dout_tvalid_itr_1bit <= dout_tvalid  ;
                m_axis_dout_tvalid_r <= dout_tvalid_itr_1bit;
            end
            else  begin
                dout_tvalid_itr_1bit <= dout_tvalid_itr_1bit;
                m_axis_dout_tvalid_r <= m_axis_dout_tvalid_r;
            end
        end
    end
    else if (LATENCY >= 3) begin
        reg [LATENCY-2:0] dout_tvalid_itr = {LATENCY-1{1'b0}};

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                dout_tvalid_itr <= {LATENCY-1{1'b0}};
                m_axis_dout_tvalid_r <= 1'b0;
            end
            else if (clk_en) begin
                dout_tvalid_itr[0] <= dout_tvalid;
                dout_tvalid_itr[LATENCY-2:1] <= dout_tvalid_itr[LATENCY-3:0]; 
                m_axis_dout_tvalid_r <= dout_tvalid_itr[LATENCY-2];
            end
            else begin
                dout_tvalid_itr[0] <= dout_tvalid_itr[0];
                dout_tvalid_itr[LATENCY-2:1] <= dout_tvalid_itr[LATENCY-2:1]; 
                m_axis_dout_tvalid_r <= m_axis_dout_tvalid_r;
            end
        end
    end
endgenerate

//********************************************************************************************
//                                          DIN_TREADY
//********************************************************************************************
    
    // always@(posedge clk or negedge rst_n)begin
    //     if(!rst_n) begin
    //         s_axis_dividend_tready <= 1'b0; //reset to 0
    //         s_axis_divisor_tready  <= 1'b0; //reset to 0
    //     end
    //     else if(clk_en) begin
    //         s_axis_dividend_tready <= 1'b1; //lutmult is fully pipelined, which is always ready for input
    //         s_axis_divisor_tready  <= 1'b1; //lutmult is fully pipelined, which is always ready for input

    //     end   
    //     else begin
    //         s_axis_dividend_tready <= 1'b0; //0 means not ready for input
    //         s_axis_divisor_tready  <= 1'b0; //0 means not ready for input
    //     end
    // end


//********************************************************************************************
//                                          TLAST
//********************************************************************************************
generate
    if (TLAST == 1) begin 
        reg dout_tlast = 0;

        always@(*)
        begin
            case(OUTPUT_TLAST)
                3'b010: dout_tlast = s_axis_dividend_tlast;
                3'b001: dout_tlast = s_axis_divisor_tlast;
                3'b000: dout_tlast = (s_axis_divisor_tlast) || (s_axis_dividend_tlast);
                3'b011: dout_tlast = (s_axis_divisor_tlast) && (s_axis_dividend_tlast);
                default: dout_tlast = 1'b0;
            endcase
        end

        if (LATENCY == 1) begin
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) m_axis_dout_tlast <= 1'b0;
                else if (clk_en) m_axis_dout_tlast <= dout_tlast;
                else m_axis_dout_tlast <= m_axis_dout_tlast;
            end
        end
        else if (LATENCY == 2) begin
            reg dout_tlast_r_1bit=0;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    dout_tlast_r_1bit <= 1'b0;
                    m_axis_dout_tlast <= 1'b0;
                end
                else if (clk_en) begin
                    dout_tlast_r_1bit <= dout_tlast;
                    m_axis_dout_tlast <= dout_tlast_r_1bit;
                end
                else begin
                    dout_tlast_r_1bit <= dout_tlast_r_1bit;
                    m_axis_dout_tlast <= m_axis_dout_tlast;
                end
            end
        end
        else if (LATENCY >= 3) begin
            reg [LATENCY-2:0] dout_tlast_r={LATENCY-1{1'b0}};

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    dout_tlast_r <= {LATENCY-1{1'b0}};
                    m_axis_dout_tlast <= 1'b0;
                end
                else if (clk_en) begin
                    dout_tlast_r[0] <= dout_tlast;
                    dout_tlast_r[LATENCY-2:1] <= dout_tlast_r[LATENCY-3:0];
                    m_axis_dout_tlast <= dout_tlast_r[LATENCY-2];
                end
                else  begin
                    dout_tlast_r[0] <= dout_tlast_r[0];
                    dout_tlast_r[LATENCY-2:1] <= dout_tlast_r[LATENCY-2:1];
                    m_axis_dout_tlast <= m_axis_dout_tlast;
                end
            end
        end
    end
endgenerate

//********************************************************************************************
//                                          TUSER
//********************************************************************************************

    generate 
    if (TUSER == 1) begin//a generate if block. circuit is generated only when TUSER is 1
            wire divisor_by_zero; 
        if (ZERO_DETECT == 1) begin//a generate if block. circuit is generated only when ZERO_DETECT is 1
            assign divisor_by_zero = (s_axis_divisor_tdata == 0)? 1'b1 : 1'b0;
        end
        ipsxe_divider_lutmult_tuser_v1_0  
        #(
            .LATENCY(LATENCY), 
            .TUSER_WIDTH(TUSER_WIDTH),
            .DIVIDEND_TUSER(DIVIDEND_TUSER),
            .DIVISOR_TUSER(DIVISOR_TUSER),
            .ZERO_DETECT(ZERO_DETECT),
            .DIVIDEND_TUSER_WIDTH(DIVIDEND_TUSER_WIDTH),
            .DIVISOR_TUSER_WIDTH(DIVISOR_TUSER_WIDTH)
        )
        u_lutmult_tuser_tuser(
            .clk(clk),               
            .rst_n(rst_n),             
            .clk_en(clk_en),
            .dividend_tuser(s_axis_dividend_tuser),
            .divisor_tuser(s_axis_divisor_tuser),
            .divisor_by_zero(divisor_by_zero),
            .m_axis_dout_tuser(m_axis_dout_tuser)
        );
    end
    endgenerate

//********************************************************************************************
//                                          IP_CODE
//********************************************************************************************
    generate 
        if (SIGNED == 1) begin
            ipsxe_divider_lutmult_top_v1_1
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .LATENCY(LATENCY), 
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            u_lutmult_top
            (
                .clk(clk),
                .rstn(rst_n),         
                .clk_en(clk_en), 
                .dividend(s_axis_dividend_tdata),
                .divisor(s_axis_divisor_tdata),
                .quotient(quotient),
                .remainder(remainder)
            );
        end else begin
            ipsxe_divider_lutmult_top_v1_1
            #(
                .DIVIDEND_WIDTH(DIVIDEND_WIDTH),
                .SIGNED(SIGNED),
                .LATENCY(LATENCY-1), 
                .DIVISOR_WIDTH(DIVISOR_WIDTH)
            )
            u_lutmult_top
            (
                .clk(clk),
                .rstn(rst_n),         
                .clk_en(clk_en), 
                .dividend(s_axis_dividend_tdata),
                .divisor(s_axis_divisor_tdata),
                .quotient(quotient),
                .remainder(remainder)
            );
        end
    endgenerate

endmodule
