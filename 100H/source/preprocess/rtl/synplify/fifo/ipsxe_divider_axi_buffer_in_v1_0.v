module ipsxe_divider_axi_buffer_in_v1_0
#(
    parameter TDATA_A_WIDTH     = 32,
    parameter TLAST_A_WIDTH     = 1,
    parameter TUSER_A_WIDTH     = 4,
    parameter TDATA_B_WIDTH     = 32,
    parameter TLAST_B_WIDTH     = 1,
    parameter TUSER_B_WIDTH     = 4,
    parameter DIVIDEND_TUSER    = 1,
    parameter DIVIDEND_TLAST    = 1, 
    parameter DIVISOR_TUSER     = 1, 
    parameter DIVISOR_TLAST     = 1
)
(
    input                              aclk,
    input                              aresetn,

    // Input Stream A
    input      [TDATA_A_WIDTH-1:0]     s_a_tdata,
    input                              s_a_tvalid,
    output                             s_a_tready,
    input      [TUSER_A_WIDTH-1:0]     s_a_tuser,
    input                              s_a_tlast,

    // Input Stream B
    input      [TDATA_B_WIDTH-1:0]     s_b_tdata,
    input                              s_b_tvalid,
    output                             s_b_tready,
    input      [TUSER_B_WIDTH-1:0]     s_b_tuser,
    input                              s_b_tlast,

    // Output Stream A
    output reg                         m_a_tvalid = 0,
    output reg [TDATA_A_WIDTH-1:0]     m_a_tdata = {TDATA_A_WIDTH{1'b0}},
    output reg [TUSER_A_WIDTH-1:0]     m_a_tuser = {TUSER_A_WIDTH{1'b0}},
    output reg                         m_a_tlast = 0,

    // Output Stream B
    output reg                         m_b_tvalid = 0,
    output reg [TDATA_B_WIDTH-1:0]     m_b_tdata = {TDATA_B_WIDTH{1'b0}},
    output reg [TUSER_B_WIDTH-1:0]     m_b_tuser = {TUSER_B_WIDTH{1'b0}},
    output reg                         m_b_tlast = 0,

    input                              m_tready
);

// Parameters for FIFOs
parameter FIFO_ADDR_WIDTH = 1; // Modify as needed for FIFO depth
parameter FIFO_A_DATA_WIDTH = TDATA_A_WIDTH + (DIVIDEND_TUSER ? TUSER_A_WIDTH : 0) + (DIVIDEND_TLAST ? TLAST_A_WIDTH : 0);
parameter FIFO_B_DATA_WIDTH = TDATA_B_WIDTH + (DIVISOR_TUSER ? TUSER_B_WIDTH : 0) + (DIVISOR_TLAST ? TLAST_B_WIDTH : 0);


wire fifo_rd_en;

// FIFO signals for Stream A
wire [FIFO_A_DATA_WIDTH-1:0] fifo_a_wr_data;
wire fifo_a_wr_en;
wire fifo_a_full;

// FIFO signals for Stream B
wire [FIFO_B_DATA_WIDTH-1:0] fifo_b_wr_data;
wire fifo_b_wr_en;
wire fifo_b_full;
//reg rd_addr = 0;

//reg cnta = 0;
//reg cntb = 0;



//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
//        cnta <= 0;
//    end else if (fifo_a_wr_en & !fifo_a_full) begin
//        cnta <= cnta +1;
//    end 
//end

//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
//        cntb <= 0;
//    end else if (fifo_b_wr_en & !fifo_b_full) begin
//        cntb <= cntb +1;
//     end 
//end

reg a_valid = 0;
reg b_valid = 0;
reg [FIFO_A_DATA_WIDTH-1:0]data_a = {FIFO_A_DATA_WIDTH{1'b0}};
reg [FIFO_B_DATA_WIDTH-1:0]data_b = {FIFO_B_DATA_WIDTH{1'b0}};

assign fifo_a_wr_en = s_a_tvalid & (!fifo_a_full || fifo_b_full & m_tready);
assign fifo_b_wr_en = s_b_tvalid & (!fifo_b_full || fifo_a_full & m_tready);
assign fifo_a_full = a_valid;
assign fifo_b_full = b_valid;
assign s_a_tready = !fifo_a_full || fifo_rd_en;
assign s_b_tready = !fifo_b_full || fifo_rd_en;
//assign fifo_rd_en = (m_tready & fifo_a_full & fifo_b_full) || (m_tready & s_a_tvalid & s_b_tvalid);
assign fifo_rd_en = m_tready & fifo_a_full & fifo_b_full;


always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        a_valid <= 0;
    end else if (fifo_a_wr_en) begin
        a_valid <= 1;
     end else if (fifo_rd_en) begin
        a_valid <= 0;
     end
end

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        b_valid <= 0;
    end else if (fifo_b_wr_en) begin
        b_valid <= 1;
     end else if (fifo_rd_en) begin
        b_valid <= 0;
     end
end

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        data_a <= 0; 
    end else if(fifo_a_wr_en) begin
        data_a <= fifo_a_wr_data;
    end else begin
        data_a <= data_a;
    end
end

always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        data_b <= 0; 
    end else if(fifo_b_wr_en) begin
        data_b <= fifo_b_wr_data;
    end else begin
        data_b <= data_b;
    end
end


always@(*) begin
    m_a_tdata = (fifo_rd_en) ? data_a : 0;
    m_b_tdata = (fifo_rd_en) ? data_b : 0;
    m_a_tvalid = fifo_rd_en;
    m_b_tvalid = fifo_rd_en;
end

//assign fifo_a_full = !(rd_addr == cnta);
//assign fifo_b_full = !(rd_addr == cntb);

//assign s_a_tready = !fifo_a_full;
//assign s_b_tready = !fifo_b_full;

//assign fifo_a_wr_en = s_a_tvalid & (!fifo_a_full || fifo_b_full);
//assign fifo_b_wr_en = s_b_tvalid & (!fifo_b_full || fifo_a_full);

//assign fifo_rd_en = (m_tready & fifo_a_full & fifo_b_full) || (m_tready & s_a_tvalid & s_b_tvalid);


//always @(posedge aclk or negedge aresetn) begin
//    case(cnta)
//        1'b0: begin 
//        if(fifo_a_wr_en)begin
//               data_a1 <= fifo_a_wr_data;
//               data_a2 <= data_a2;
//               end
//        else begin
//                data_a1<= data_a1;
//                data_a2 <= data_a2;   
//        end                     
//        end
//        1'b1: begin        
//        if(fifo_a_wr_en)begin
//                data_a2 <= fifo_a_wr_data;
//                data_a1<= data_a1;
//               end
//        else begin
//                data_a1<= data_a1;
//                data_a2 <= data_a2;   
//        end 
//        end
//        default: begin
//                data_a1<= data_a1;
//                data_a2 <= data_a2;                               
//        end
//    endcase
//end


//always @(posedge aclk or negedge aresetn) begin
//    case(cntb)
//        1'b0: begin 
//        if(fifo_b_wr_en)begin
//               data_b1 <= fifo_b_wr_data;
//               data_b2 <= data_b2;
//               end
//        else begin
//                data_b1<= data_b1;
//                data_b2 <= data_b2;   
//        end
//        end
//        1'b1: begin
//        if(fifo_b_wr_en)begin
//                data_b2 <= fifo_b_wr_data;
//                data_b1<= data_b1;
//               end
//        else begin
//                data_b1<= data_b1;
//                data_b2 <= data_b2;   
//        end
//        end
//        default: begin
//                data_b1<= data_b1;
//                data_b2 <= data_b2;                               
//        end
//    endcase
//end

//assign fifo_a_full = !(rd_addr == cnta);
//assign fifo_b_full = !(rd_addr == cntb);

//assign s_a_tready = !fifo_a_full;
//assign s_b_tready = !fifo_b_full;

//assign fifo_a_wr_en = s_a_tvalid & (!fifo_a_full || fifo_b_full);
//assign fifo_b_wr_en = s_b_tvalid & (!fifo_b_full || fifo_a_full);

//assign fifo_rd_en = (m_tready & fifo_a_full & fifo_b_full) || (m_tready & s_a_tvalid & s_b_tvalid);


//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
//        rd_addr <= 0;
//    end else if (fifo_rd_en) begin
//        rd_addr <= rd_addr + 1;
//    end else begin
//        rd_addr <= rd_addr;
//    end
//end


//always@(*) begin
//    m_a_tdata = (rd_addr) ? data_a1 : data_a2;
//    m_b_tdata = (rd_addr) ? data_b1 : data_b2;
//end
// FIFO write logic for Stream A
assign fifo_a_wr_data[TDATA_A_WIDTH-1:0] = s_a_tdata;
generate
    if (DIVIDEND_TUSER) begin
       assign fifo_a_wr_data[TDATA_A_WIDTH+TUSER_A_WIDTH-1:TDATA_A_WIDTH] = s_a_tuser;
    end
endgenerate
generate
    if (DIVIDEND_TLAST) begin
        assign fifo_a_wr_data[FIFO_A_DATA_WIDTH-1] = s_a_tlast;
    end
endgenerate

// FIFO write logic for Stream B
assign fifo_b_wr_data[TDATA_B_WIDTH-1:0] = s_b_tdata;
generate
    if (DIVISOR_TUSER) begin
       assign fifo_b_wr_data[TDATA_B_WIDTH+TUSER_B_WIDTH-1:TDATA_B_WIDTH] = s_b_tuser;
    end
endgenerate
generate
    if (DIVISOR_TLAST) begin
        assign fifo_b_wr_data[FIFO_B_DATA_WIDTH-1] = s_b_tlast;
    end
endgenerate


// Output logic for Stream A
//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
////        m_a_tdata <= 0;
//        m_a_tvalid <= 0;
//    end else if (fifo_rd_en) begin
////        m_a_tdata <= fifo_a_wr_data[TDATA_A_WIDTH-1:0];
//        m_a_tvalid <= fifo_rd_en;
//    end else if (!m_tready) begin
//        m_a_tvalid <= m_a_tvalid;
////        m_a_tdata <= m_a_tdata;
//    end else begin
//        m_a_tvalid <= m_a_tvalid;
////        m_a_tdata <= m_a_tdata;
//    end
//end

generate
if (DIVIDEND_TUSER) begin
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_a_tuser <= 0;
        end else if (fifo_rd_en) begin
            m_a_tuser <= fifo_a_wr_data[TDATA_A_WIDTH+TUSER_A_WIDTH-1:TDATA_A_WIDTH];
        end else begin
            m_a_tuser <= m_a_tuser;
        end
    end
end
endgenerate

generate
if (DIVIDEND_TLAST) begin
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_a_tlast <= 0;
        end else if (fifo_rd_en) begin
            m_a_tlast <= fifo_a_wr_data[FIFO_A_DATA_WIDTH-1];
        end else begin
            m_a_tlast <= m_a_tlast;
        end
    end
end
endgenerate

// Output logic for Stream B
//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
////        m_b_tdata <= 0;
//        m_b_tvalid <= 0;
//    end else if (fifo_rd_en) begin
////        m_b_tdata <= fifo_b_wr_data[TDATA_B_WIDTH-1:0];
//        m_b_tvalid <= fifo_rd_en;
//    end else if (!m_tready) begin
//        m_b_tvalid <= m_b_tvalid;
////        m_b_tdata <= m_b_tdata;
//    end else begin
//        m_b_tvalid <= m_a_tvalid;
////        m_b_tdata <= m_b_tdata;
//    end
//end

generate
if (DIVISOR_TUSER) begin
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_b_tuser <= 0;
        end else if (fifo_rd_en) begin
            m_b_tuser <= fifo_b_wr_data[TDATA_B_WIDTH+TUSER_B_WIDTH-1:TDATA_B_WIDTH];
        end else begin
            m_b_tuser <= m_b_tuser;
        end
    end
end
endgenerate

generate
if (DIVISOR_TLAST) begin
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_b_tlast <= 0;
        end else if (fifo_rd_en) begin
            m_b_tlast <= fifo_b_wr_data[FIFO_B_DATA_WIDTH-1];
        end else begin
            m_b_tlast <= m_b_tlast;
        end
    end
end
endgenerate

endmodule
