`timescale 1ns/1ps
// Full AXI write channels, one transaction from AW through B. W may arrive
// before AW: it is backpressured, never consumed until its address is routed.
// AW is an opaque descriptor (including ID, address and all sidebands).
module pcie_write_demux #(
    parameter AW_WIDTH = 61
) (
    input wire clk, rst,
    input wire s_ddr,
    input wire [AW_WIDTH-1:0] s_aw,
    input wire s_awvalid, output wire s_awready,
    input wire [127:0] s_wdata, input wire [15:0] s_wstrb,
    input wire s_wlast, s_wvalid, output wire s_wready,
    output wire [3:0] s_bid, output wire [1:0] s_bresp,
    output wire s_bvalid, input wire s_bready,
    output wire [2*AW_WIDTH-1:0] m_aw,
    output wire [1:0] m_awvalid, input wire [1:0] m_awready,
    output wire [255:0] m_wdata, output wire [31:0] m_wstrb,
    output wire [1:0] m_wlast, m_wvalid, input wire [1:0] m_wready,
    input wire [7:0] m_bid, input wire [3:0] m_bresp,
    input wire [1:0] m_bvalid, output wire [1:0] m_bready
);
    localparam IDLE=0, ADDR=1, DATA=2, RESP=3;
    reg [1:0] state;
    reg owner;
    reg [AW_WIDTH-1:0] aw;
    assign s_awready = state == IDLE && !rst;
    assign m_aw = {aw, aw};
    assign m_awvalid = state == ADDR ? (2'b01 << owner) : 2'b00;
    assign m_wdata = {s_wdata,s_wdata};
    assign m_wstrb = {s_wstrb,s_wstrb};
    assign m_wlast = {2{s_wlast}};
    assign m_wvalid = state == DATA && s_wvalid ? (2'b01 << owner) : 2'b00;
    assign s_wready = state == DATA && m_wready[owner];
    assign s_bid = m_bid[owner*4 +: 4];
    assign s_bresp = m_bresp[owner*2 +: 2];
    assign s_bvalid = state == RESP && m_bvalid[owner];
    assign m_bready = state == RESP && s_bready ? (2'b01 << owner) : 2'b00;
    always @(posedge clk) begin
        if (rst) begin state <= IDLE; owner <= 0; aw <= 0; end
        else case (state)
            IDLE: if (s_awvalid && s_awready) begin
                aw <= s_aw; owner <= s_ddr; state <= ADDR;
            end
            ADDR: if (m_awready[owner]) state <= DATA;
            DATA: if (s_wvalid && s_wready && s_wlast) state <= RESP;
            RESP: if (s_bvalid && s_bready) state <= IDLE;
        endcase
    end
endmodule

// Two-way round robin AFTER the existing seven-way camera/delivery arbiter.
// Registered grant prevents AW changes under stalls. No crossbar W selector.
module pcie_ddr_write_merge #(
    parameter AW_WIDTH = 61
) (
    input wire clk, rst,
    input wire [2*AW_WIDTH-1:0] m_aw,
    input wire [1:0] m_awvalid, output wire [1:0] m_awready,
    input wire [255:0] m_wdata, input wire [31:0] m_wstrb,
    input wire [1:0] m_wlast, m_wvalid, output wire [1:0] m_wready,
    output wire [7:0] m_bid, output wire [3:0] m_bresp,
    output wire [1:0] m_bvalid, input wire [1:0] m_bready,
    output wire [AW_WIDTH-1:0] s_aw,
    output wire s_awvalid, input wire s_awready,
    output wire [127:0] s_wdata, output wire [15:0] s_wstrb,
    output wire s_wlast, s_wvalid, input wire s_wready,
    input wire [3:0] s_bid, input wire [1:0] s_bresp,
    input wire s_bvalid, output wire s_bready
);
    localparam IDLE=0, ADDR=1, DATA=2, RESP=3;
    reg [1:0] state;
    reg owner, prefer;
    assign s_aw = m_aw[owner*AW_WIDTH +: AW_WIDTH];
    assign s_awvalid = state == ADDR && m_awvalid[owner];
    assign m_awready = state == ADDR && s_awready ? (2'b01 << owner) : 2'b00;
    assign s_wdata = m_wdata[owner*128 +: 128];
    assign s_wstrb = m_wstrb[owner*16 +: 16];
    assign s_wlast = m_wlast[owner];
    assign s_wvalid = state == DATA && m_wvalid[owner];
    assign m_wready = state == DATA && s_wready ? (2'b01 << owner) : 2'b00;
    assign m_bid = {s_bid,s_bid};
    assign m_bresp = {s_bresp,s_bresp};
    assign m_bvalid = state == RESP && s_bvalid ? (2'b01 << owner) : 2'b00;
    assign s_bready = state == RESP && m_bready[owner];
    always @(posedge clk) begin
        if (rst) begin state <= IDLE; owner <= 0; prefer <= 0; end
        else case (state)
            IDLE: if (|m_awvalid) begin
                owner <= m_awvalid[prefer] ? prefer : !prefer;
                state <= ADDR;
            end
            ADDR: if (s_awvalid && s_awready) state <= DATA;
            DATA: if (s_wvalid && s_wready && s_wlast) state <= RESP;
            RESP: if (s_bvalid && s_bready) begin
                prefer <= !owner; state <= IDLE;
            end
        endcase
    end
endmodule
