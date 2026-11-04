module ipsxe_divider_axi_buffer_out_v1_0
#(
    parameter TDATA_A_WIDTH  = 32,
    parameter TLAST_A_WIDTH  = 1,
    parameter TUSER_A_WIDTH  = 1,
    parameter USE_TUSER      = 1,
    parameter USE_TLAST      = 1
)
(
    input                             aclk,
    input                             aresetn,

    // Input Stream
    input      [TDATA_A_WIDTH-1:0]    s_a_tdata,
    input                             s_a_tvalid,
    output                            s_a_tready,

    input      [TUSER_A_WIDTH-1:0]    s_a_tuser,
    input                             s_a_tlast,

    // Output Stream
    output                         m_tvalid,
    output  [TDATA_A_WIDTH-1:0]    m_a_tdata,
    output reg [TUSER_A_WIDTH-1:0]    m_a_tuser = {TUSER_A_WIDTH{1'b0}},
    output reg                        m_a_tlast = 0,

    input                             m_tready
);

// Parameters for FIFO
parameter FIFO_ADDR_WIDTH = 4; // Modify as needed for FIFO depth
parameter FIFO_DATA_WIDTH = TDATA_A_WIDTH + (USE_TUSER ? TUSER_A_WIDTH : 0) + (USE_TLAST ? TLAST_A_WIDTH : 0);

// FIFO signals
wire [FIFO_DATA_WIDTH-1:0] fifo_wr_data, fifo_rd_data;
wire fifo_wr_en, fifo_rd_en;
wire fifo_full, fifo_empty;

// FIFO write and read addresses
reg [FIFO_ADDR_WIDTH-1:0] wr_addr = {FIFO_ADDR_WIDTH{1'b0}}, rd_addr = {FIFO_ADDR_WIDTH{1'b0}};
assign m_a_tdata = fifo_rd_data[TDATA_A_WIDTH-1:0];
assign m_tvalid = !fifo_empty;

// Instantiate the FIFO
ipm_distributed_sdpram_v1_2 #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(FIFO_DATA_WIDTH)
) fifo (
    .wr_data(fifo_wr_data),
    .wr_addr(wr_addr),
    .rd_addr(rd_addr),
    .wr_clk(aclk),
    .rd_clk(aclk),
    .wr_en(fifo_wr_en),
    .rst(~aresetn),
    .rd_data(fifo_rd_data)
);

// FIFO write logic
assign fifo_wr_data[TDATA_A_WIDTH-1:0] = s_a_tdata;

generate
    if (USE_TUSER) begin
       assign fifo_wr_data[TDATA_A_WIDTH+TUSER_A_WIDTH-1:TDATA_A_WIDTH] = s_a_tuser;
    end
endgenerate

// Conditional write logic for TLAST
generate
    if (USE_TLAST) begin
        assign fifo_wr_data[FIFO_DATA_WIDTH-1] = s_a_tlast;
    end
endgenerate

assign fifo_wr_en = s_a_tvalid && !fifo_full;

// FIFO read logic
assign fifo_rd_en = m_tready && !fifo_empty;

// FIFO full and empty logic
assign fifo_full = ((wr_addr + 1'b1) == rd_addr);
assign fifo_empty = (rd_addr == wr_addr);

// Ready signal logic for s_a_tready
assign s_a_tready = !fifo_full;

// Update write and read addresses
always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
        wr_addr <= 0;
        rd_addr <= 0;
    end
    else begin
        if (fifo_wr_en) wr_addr <= wr_addr + 1;
        if (fifo_rd_en) rd_addr <= rd_addr + 1;
    end
end

// Output logic
// Read logic
//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
////        m_a_tdata <= 0;  // Corrected parameter name
//        m_tvalid <= 0;
//    end else if (!fifo_empty) begin
////        m_a_tdata <= fifo_rd_data[TDATA_A_WIDTH-1:0];
//        m_tvalid <= 1;
//    end else begin
////        m_a_tdata <= m_a_tdata;  // Corrected parameter name
//        m_tvalid <= m_tvalid;
//    end
//end

generate
if (USE_TUSER) begin
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_a_tuser <= 0;
        end else if (fifo_rd_en) begin
            m_a_tuser <= fifo_rd_data[TDATA_A_WIDTH+TUSER_A_WIDTH-1:TDATA_A_WIDTH];
        end else begin
            m_a_tuser <= m_a_tuser;
        end
    end
end
endgenerate

generate
if (USE_TLAST) begin
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_a_tlast <= 0;
        end else if (fifo_rd_en) begin
            m_a_tlast <= fifo_rd_data[FIFO_DATA_WIDTH-1];
        end else begin
            m_a_tlast <= m_a_tlast;
        end
    end
end
endgenerate

endmodule
