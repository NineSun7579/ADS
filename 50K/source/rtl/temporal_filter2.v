// temporal_filter2.v -- adaptive temporal IIR, 100H vip_kf scheme verbatim.
//
// KF report contract (4-tier fixed-gain IIR, per channel):
//   d = |z - x|  (z = current pixel, x = previous frame's FILTERED pixel)
//   d < T0            K=1/4  y = (3x + z) >> 2
//   T0 <= d < T1      K=1/2  y = (x + z) >> 1
//   T1 <= d < T2      K=3/4  y = (x + 3z) >> 2
//   d >= T2           K=1    y = z           (motion passthrough)
// Thresholds on the 6-bit channel scale: T0/T1/T2 = 3 / 8 / 20.
// Pure unsigned integer + shifts, no division, bit-exact reproducible.
//
// First frame after reset is full passthrough (state page not yet written).
// Missing state line (rd_valid=0) falls back to passthrough per beat -- the
// output NEVER stalls and never darkens.
//
// State storage is frame_state.v (100H-style line prefetch + column indexing).
module temporal_filter2 #(
    parameter H_NUM = 1280,
    parameter V_NUM = 480,
    parameter PIX_WIDTH = 16,
    parameter CTRL_ADDR_WIDTH = 28,
    parameter MEM_DQ_WIDTH = 32
)(
    input                     clk,
    input                     rstn,
    input  [PIX_WIDTH-1:0]    in_data,
    input                     in_de,
    input                     in_vs,
    output reg [PIX_WIDTH-1:0] out_data,
    output reg                out_de,
    output reg                out_vs,
    input                     ddr_clk,
    input                     ddr_rstn,
    output [CTRL_ADDR_WIDTH-1:0] axi_awaddr,
    output [3:0]              axi_awid,
    output [3:0]              axi_awlen,
    output [2:0]              axi_awsize,
    output [1:0]              axi_awburst,
    input                     axi_awready,
    output                    axi_awvalid,
    output [MEM_DQ_WIDTH*8-1:0] axi_wdata,
    output [MEM_DQ_WIDTH-1:0] axi_wstrb,
    input                     axi_wlast,
    output                    axi_wvalid,
    input                     axi_wready,
    output [CTRL_ADDR_WIDTH-1:0] axi_araddr,
    output [3:0]              axi_arid,
    output [3:0]              axi_arlen,
    output [2:0]              axi_arsize,
    output [1:0]              axi_arburst,
    output                    axi_arvalid,
    input                     axi_arready,
    output                    axi_rready,
    input  [MEM_DQ_WIDTH*8-1:0] axi_rdata,
    input                     axi_rvalid,
    input                     axi_rlast,
    input  [3:0]              axi_rid
);
    localparam [2:0] T0 = 3'd3;
    localparam [3:0] T1 = 4'd8;
    localparam [4:0] T2 = 5'd20;

    // frame bookkeeping: passthrough until one state frame has been stored.
    // state_ok becomes true from the SECOND frame on (the first frame's writes
    // complete at its end) and stays true; a counter would wrap and glitch.
    reg       vs_d, vs_seen, state_ready;
    wire      vs_edge = in_vs && !vs_d;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            vs_d <= 1'b0; vs_seen <= 1'b0; state_ready <= 1'b0;
        end
        else begin
            vs_d <= in_vs;
            if (vs_edge) begin
                if (vs_seen) state_ready <= 1'b1;
                vs_seen <= 1'b1;
            end
        end
    end
    wire state_ok = state_ready;

    // previous-frame pixel from frame_state (structural alignment)
    wire [PIX_WIDTH-1:0] prev_px;
    wire                 prev_valid;
    frame_state #(
        .H_NUM(H_NUM), .V_NUM(V_NUM), .PIX_WIDTH(PIX_WIDTH),
        .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH), .MEM_DQ_WIDTH(MEM_DQ_WIDTH)
    ) u_state (
        .clk(clk), .rstn(rstn),
        .wr_data(out_data), .wr_de(out_de), .wr_vs(out_vs),
        .rd_data(prev_px), .rd_valid(prev_valid), .rd_de(in_de), .rd_vs(in_vs),
        .ddr_clk(ddr_clk), .ddr_rstn(ddr_rstn),
        .axi_awaddr(axi_awaddr), .axi_awid(axi_awid), .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize), .axi_awburst(axi_awburst),
        .axi_awready(axi_awready), .axi_awvalid(axi_awvalid),
        .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb), .axi_wlast(axi_wlast),
        .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_araddr(axi_araddr), .axi_arid(axi_arid), .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize), .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_rready(axi_rready), .axi_rdata(axi_rdata), .axi_rvalid(axi_rvalid),
        .axi_rlast(axi_rlast), .axi_rid(axi_rid)
    );

    // ---------------- 4-tier adaptive IIR, per channel ----------------
    function [4:0] tier5(input [4:0] z, input [4:0] x, input use_s);
        reg [4:0] d;
        reg [6:0] s;
        begin
            d = (z > x) ? (z - x) : (x - z);
            if (!use_s)        tier5 = z;
            else if (d < T0) begin s = {2'b00, x}*3 + {2'b00, z}; tier5 = s[6:2]; end
            else if (d < T1) begin s = {2'b00, x} + {2'b00, z};   tier5 = s[5:1]; end
            else if (d < T2) begin s = {2'b00, x} + {2'b00, z}*3; tier5 = s[6:2]; end
            else             tier5 = z;
        end
    endfunction

    function [5:0] tier6(input [5:0] z, input [5:0] x, input use_s);
        reg [5:0] d;
        reg [7:0] s;
        begin
            d = (z > x) ? (z - x) : (x - z);
            if (!use_s)        tier6 = z;
            else if (d < T0) begin s = {2'b00, x}*3 + {2'b00, z}; tier6 = s[7:2]; end
            else if (d < T1) begin s = {2'b00, x} + {2'b00, z};   tier6 = s[6:1]; end
            else if (d < T2) begin s = {2'b00, x} + {2'b00, z}*3; tier6 = s[7:2]; end
            else             tier6 = z;
        end
    endfunction

    // The state line buffer read is registered (BRAM, 100H LAT=1): rd_data for
    // beat k appears one cycle after it. Delay the current stream by one so the
    // tier computation pairs z(k) with state(k); total in->out latency = 2.
    reg [PIX_WIDTH-1:0] z_d1;
    reg                 de_d1, vs_d1;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            z_d1 <= 0; de_d1 <= 0; vs_d1 <= 0;
        end
        else begin
            z_d1 <= in_data; de_d1 <= in_de; vs_d1 <= in_vs;
        end
    end

    wire use_state = state_ok && prev_valid;   // aligned with prev_px at evaluation
    wire [4:0] yr = tier5(z_d1[15:11], prev_px[15:11], use_state);
    wire [5:0] yg = tier6(z_d1[10:5],  prev_px[10:5],  use_state);
    wire [4:0] yb = tier5(z_d1[4:0],   prev_px[4:0],   use_state);
    wire [15:0] y_pix = {yr, yg, yb};

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            out_data <= 16'h0; out_de <= 1'b0; out_vs <= 1'b0;
        end
        else begin
            out_data <= y_pix;
            out_de   <= de_d1;
            out_vs   <= vs_d1;
        end
    end
endmodule
