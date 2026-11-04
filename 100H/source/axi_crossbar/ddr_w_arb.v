// ============================================================================
// ddr_w_arb.v -- [WARB 2026-09-19] minimal DDR write arbiter.
// [CAM3 2026-09-26] extended to 3 masters (cam3 engine joins as master 2).
// [CAM4 2026-09-27] extended to 4 masters (cam4 engine joins as master 3).
// [SFP  2026-09-29] extended to 6 masters (SFP fiber cam5/cam6 join as 4/5).
//
// WHY: the Forencich axi_crossbar's M00 write path leaks its per-master W-channel
// select across handoffs (bench-proven in sim/wedge: after S01's burst tail the
// M00 w_select_valid latches forever, S04's beats are never released, and both
// camera engines wedge after 1-2 bursts). This module replaces the crossbar on
// the DDR write path for the camera engines.
//
// DESIGN: single-outstanding end-to-end, matching the DDR3 IP user-port contract
// (no wvalid, unthrottleable wready, one burst processed at a time):
//   IDLE  : register one master (round-robin tie-break), then present its AW;
//           the accept from the port glue locks OWNER for the whole burst.
//   BUSY  : only OWNER's W stream reaches the glue; the fabric-minted B (from
//           wusero_last) is routed back to OWNER; its accept frees the slot and
//           advances the round-robin.
// AXI-legal: awvalid/wvalid are held with stable payload until accepted; the
// non-owner masters' awready/wready stay low, so their bursts cannot start.
// ============================================================================
`timescale 1ns/1ps
module ddr_w_arb (
    input  wire         clk,
    input  wire         rst,

    // ---- master 0 (cam1 DMA) ----
    input  wire [3:0]   m0_awid,
    input  wire [31:0]  m0_awaddr,
    input  wire [7:0]   m0_awlen,
    input  wire [2:0]   m0_awsize,
    input  wire [1:0]   m0_awburst,
    input  wire         m0_awlock,
    input  wire [3:0]   m0_awcache,
    input  wire [2:0]   m0_awprot,
    input  wire         m0_awvalid,
    output wire         m0_awready,
    input  wire [127:0] m0_wdata,
    input  wire [15:0]  m0_wstrb,
    input  wire         m0_wlast,
    input  wire         m0_wvalid,
    output wire         m0_wready,
    output wire [3:0]   m0_bid,
    output wire [1:0]   m0_bresp,
    output wire         m0_bvalid,
    input  wire         m0_bready,

    // ---- master 1 (cam2 DMA) ----
    input  wire [3:0]   m1_awid,
    input  wire [31:0]  m1_awaddr,
    input  wire [7:0]   m1_awlen,
    input  wire [2:0]   m1_awsize,
    input  wire [1:0]   m1_awburst,
    input  wire         m1_awlock,
    input  wire [3:0]   m1_awcache,
    input  wire [2:0]   m1_awprot,
    input  wire         m1_awvalid,
    output wire         m1_awready,
    input  wire [127:0] m1_wdata,
    input  wire [15:0]  m1_wstrb,
    input  wire         m1_wlast,
    input  wire         m1_wvalid,
    output wire         m1_wready,
    output wire [3:0]   m1_bid,
    output wire [1:0]   m1_bresp,
    output wire         m1_bvalid,
    input  wire         m1_bready,

    // ---- master 2 (cam3 DMA) ----
    input  wire [3:0]   m2_awid,
    input  wire [31:0]  m2_awaddr,
    input  wire [7:0]   m2_awlen,
    input  wire [2:0]   m2_awsize,
    input  wire [1:0]   m2_awburst,
    input  wire         m2_awlock,
    input  wire [3:0]   m2_awcache,
    input  wire [2:0]   m2_awprot,
    input  wire         m2_awvalid,
    output wire         m2_awready,
    input  wire [127:0] m2_wdata,
    input  wire [15:0]  m2_wstrb,
    input  wire         m2_wlast,
    input  wire         m2_wvalid,
    output wire         m2_wready,
    output wire [3:0]   m2_bid,
    output wire [1:0]   m2_bresp,
    output wire         m2_bvalid,
    input  wire         m2_bready,

    // ---- master 3 (cam4 DMA) ----
    input  wire [3:0]   m3_awid,
    input  wire [31:0]  m3_awaddr,
    input  wire [7:0]   m3_awlen,
    input  wire [2:0]   m3_awsize,
    input  wire [1:0]   m3_awburst,
    input  wire         m3_awlock,
    input  wire [3:0]   m3_awcache,
    input  wire [2:0]   m3_awprot,
    input  wire         m3_awvalid,
    output wire         m3_awready,
    input  wire [127:0] m3_wdata,
    input  wire [15:0]  m3_wstrb,
    input  wire         m3_wlast,
    input  wire         m3_wvalid,
    output wire         m3_wready,
    output wire [3:0]   m3_bid,
    output wire [1:0]   m3_bresp,
    output wire         m3_bvalid,
    input  wire         m3_bready,

    // ---- master 4 (SFP cam5 DMA) [SFP 2026-09-29] ----
    input  wire [3:0]   m4_awid,
    input  wire [31:0]  m4_awaddr,
    input  wire [7:0]   m4_awlen,
    input  wire [2:0]   m4_awsize,
    input  wire [1:0]   m4_awburst,
    input  wire         m4_awlock,
    input  wire [3:0]   m4_awcache,
    input  wire [2:0]   m4_awprot,
    input  wire         m4_awvalid,
    output wire         m4_awready,
    input  wire [127:0] m4_wdata,
    input  wire [15:0]  m4_wstrb,
    input  wire         m4_wlast,
    input  wire         m4_wvalid,
    output wire         m4_wready,
    output wire [3:0]   m4_bid,
    output wire [1:0]   m4_bresp,
    output wire         m4_bvalid,
    input  wire         m4_bready,

    // ---- master 5 (SFP cam6 DMA) [SFP 2026-09-29] ----
    input  wire [3:0]   m5_awid,
    input  wire [31:0]  m5_awaddr,
    input  wire [7:0]   m5_awlen,
    input  wire [2:0]   m5_awsize,
    input  wire [1:0]   m5_awburst,
    input  wire         m5_awlock,
    input  wire [3:0]   m5_awcache,
    input  wire [2:0]   m5_awprot,
    input  wire         m5_awvalid,
    output wire         m5_awready,
    input  wire [127:0] m5_wdata,
    input  wire [15:0]  m5_wstrb,
    input  wire         m5_wlast,
    input  wire         m5_wvalid,
    output wire         m5_wready,
    output wire [3:0]   m5_bid,
    output wire [1:0]   m5_bresp,
    output wire         m5_bvalid,
    input  wire         m5_bready,

    // ---- master 6 (delivery) (SFP cam6 DMA) [SFP 2026-09-29] ----
    input  wire [3:0]   m6_awid,
    input  wire [31:0]  m6_awaddr,
    input  wire [7:0]   m6_awlen,
    input  wire [2:0]   m6_awsize,
    input  wire [1:0]   m6_awburst,
    input  wire         m6_awlock,
    input  wire [3:0]   m6_awcache,
    input  wire [2:0]   m6_awprot,
    input  wire         m6_awvalid,
    output wire         m6_awready,
    input  wire [127:0] m6_wdata,
    input  wire [15:0]  m6_wstrb,
    input  wire         m6_wlast,
    input  wire         m6_wvalid,
    output wire         m6_wready,
    output wire [3:0]   m6_bid,
    output wire [1:0]   m6_bresp,
    output wire         m6_bvalid,
    input  wire         m6_bready,

    // ---- slave (DDR3 port glue) ----
    output wire [3:0]   s_awid,
    output wire [31:0]  s_awaddr,
    output wire [7:0]   s_awlen,
    output wire [2:0]   s_awsize,
    output wire [1:0]   s_awburst,
    output wire         s_awlock,
    output wire [3:0]   s_awcache,
    output wire [2:0]   s_awprot,
    output wire         s_awvalid,
    input  wire         s_awready,
    output wire [127:0] s_wdata,
    output wire [15:0]  s_wstrb,
    output wire         s_wlast,
    output wire         s_wvalid,
    input  wire         s_wready,
    input  wire [3:0]   s_bid,
    input  wire [1:0]   s_bresp,
    input  wire         s_bvalid,
    output wire         s_bready
);

    reg        busy;    // an AW is locked in (waiting for its B)
    reg  [2:0] owner;    // which master owns the slot (0..5)
    reg  [2:0] rr;       // round-robin preference for the next idle grant

    // [WARBFIX 2026-09-26] AW selection is latched. The previous version drove
    // the slave AW payload from purely combinational grants, so when a higher
    // priority master asserted AWVALID during downstream AWREADY backpressure,
    // the shared AWVALID stayed high while AWADDR/AWID changed mid-handshake.
    // The slave (DDR3 IP) could then latch a torn/wrong descriptor, dropping or
    // misrouting an integer number of beats -> cam2 frame rotation, cam3 tearing.
    // Register every winner before asserting AWVALID/AWREADY, removing the
    // fresh round-robin pick from the source AWREADY path. The winner stays
    // frozen until AWREADY accepts it; the source holds its AW payload stable.
    reg        sel_valid;
    reg  [2:0] sel;
    reg  [7:0] selected_awlen;

    // grant decision: only when idle; round-robin among the requesting masters.
    // rr points at the master that gets the slot when several request at once.
    // Rotate-mask round-robin: prefer requesters at/after rr, else wrap to 0.
    wire [6:0] req_v   = {m6_awvalid, m5_awvalid, m4_awvalid, m3_awvalid, m2_awvalid, m1_awvalid, m0_awvalid};
    wire [6:0] rr_mask = 7'b1111111 << rr;
    wire [6:0] req_hi  = req_v & rr_mask;
    wire [2:0] pick_pref = req_hi[0] ? 3'd0 : req_hi[1] ? 3'd1 :
                           req_hi[2] ? 3'd2 : req_hi[3] ? 3'd3 :
                           req_hi[4] ? 3'd4 : req_hi[5] ? 3'd5 : 3'd6;
    wire [2:0] pick_wrap = req_v[0] ? 3'd0 : req_v[1] ? 3'd1 :
                           req_v[2] ? 3'd2 : req_v[3] ? 3'd3 :
                           req_v[4] ? 3'd4 : req_v[5] ? 3'd5 : 3'd6;
    wire pick_v = |req_v;
    wire [2:0] pick_sel = (|req_hi) ? pick_pref : pick_wrap;

    // effective selection: only the registered winner can present an AW
    wire eff_valid = ~busy & sel_valid;
    wire [2:0] eff_sel = sel;

    // AW datapath (latched winner's request)
    assign s_awid = ({4{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awid) |
                        ({4{(eff_sel == 3'd1)}} & m1_awid) |
                        ({4{(eff_sel == 3'd2)}} & m2_awid) |
                        ({4{(eff_sel == 3'd3)}} & m3_awid) |
                        ({4{(eff_sel == 3'd4)}} & m4_awid) |
                        ({4{(eff_sel == 3'd5)}} & m5_awid) |
                        ({4{(eff_sel == 3'd6)}} & m6_awid);
    assign s_awaddr = ({32{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awaddr) |
                        ({32{(eff_sel == 3'd1)}} & m1_awaddr) |
                        ({32{(eff_sel == 3'd2)}} & m2_awaddr) |
                        ({32{(eff_sel == 3'd3)}} & m3_awaddr) |
                        ({32{(eff_sel == 3'd4)}} & m4_awaddr) |
                        ({32{(eff_sel == 3'd5)}} & m5_awaddr) |
                        ({32{(eff_sel == 3'd6)}} & m6_awaddr);
    // Capture alongside the winner, before AWVALID. A requesting AXI master
    // holds AWLEN until its handshake; no extra AW presentation cycle is added.
    assign s_awlen = selected_awlen;
    assign s_awsize = ({3{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awsize) |
                        ({3{(eff_sel == 3'd1)}} & m1_awsize) |
                        ({3{(eff_sel == 3'd2)}} & m2_awsize) |
                        ({3{(eff_sel == 3'd3)}} & m3_awsize) |
                        ({3{(eff_sel == 3'd4)}} & m4_awsize) |
                        ({3{(eff_sel == 3'd5)}} & m5_awsize) |
                        ({3{(eff_sel == 3'd6)}} & m6_awsize);
    assign s_awburst = ({2{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awburst) |
                        ({2{(eff_sel == 3'd1)}} & m1_awburst) |
                        ({2{(eff_sel == 3'd2)}} & m2_awburst) |
                        ({2{(eff_sel == 3'd3)}} & m3_awburst) |
                        ({2{(eff_sel == 3'd4)}} & m4_awburst) |
                        ({2{(eff_sel == 3'd5)}} & m5_awburst) |
                        ({2{(eff_sel == 3'd6)}} & m6_awburst);
    assign s_awlock = ({1{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awlock) |
                        ({1{(eff_sel == 3'd1)}} & m1_awlock) |
                        ({1{(eff_sel == 3'd2)}} & m2_awlock) |
                        ({1{(eff_sel == 3'd3)}} & m3_awlock) |
                        ({1{(eff_sel == 3'd4)}} & m4_awlock) |
                        ({1{(eff_sel == 3'd5)}} & m5_awlock) |
                        ({1{(eff_sel == 3'd6)}} & m6_awlock);
    assign s_awcache = ({4{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awcache) |
                        ({4{(eff_sel == 3'd1)}} & m1_awcache) |
                        ({4{(eff_sel == 3'd2)}} & m2_awcache) |
                        ({4{(eff_sel == 3'd3)}} & m3_awcache) |
                        ({4{(eff_sel == 3'd4)}} & m4_awcache) |
                        ({4{(eff_sel == 3'd5)}} & m5_awcache) |
                        ({4{(eff_sel == 3'd6)}} & m6_awcache);
    assign s_awprot = ({3{(eff_sel == 3'd0 || eff_sel == 3'd7)}} & m0_awprot) |
                        ({3{(eff_sel == 3'd1)}} & m1_awprot) |
                        ({3{(eff_sel == 3'd2)}} & m2_awprot) |
                        ({3{(eff_sel == 3'd3)}} & m3_awprot) |
                        ({3{(eff_sel == 3'd4)}} & m4_awprot) |
                        ({3{(eff_sel == 3'd5)}} & m5_awprot) |
                        ({3{(eff_sel == 3'd6)}} & m6_awprot);
    assign s_awvalid = eff_valid;

    assign m0_awready = eff_valid & (eff_sel == 3'd0) & s_awready;
    assign m1_awready = eff_valid & (eff_sel == 3'd1) & s_awready;
    assign m2_awready = eff_valid & (eff_sel == 3'd2) & s_awready;
    assign m3_awready = eff_valid & (eff_sel == 3'd3) & s_awready;
    assign m4_awready = eff_valid & (eff_sel == 3'd4) & s_awready;
    assign m5_awready = eff_valid & (eff_sel == 3'd5) & s_awready;
    assign m6_awready = eff_valid & (eff_sel == 3'd6) & s_awready;

    // W datapath (only the owner's beats can flow)
    assign s_wdata  = owner == 3'd6 ? m6_wdata : owner == 3'd5 ? m5_wdata : owner == 3'd4 ? m4_wdata :
                      owner == 3'd3 ? m3_wdata : owner == 3'd2 ? m2_wdata :
                      owner == 3'd1 ? m1_wdata : m0_wdata;
    assign s_wstrb  = owner == 3'd6 ? m6_wstrb : owner == 3'd5 ? m5_wstrb : owner == 3'd4 ? m4_wstrb :
                      owner == 3'd3 ? m3_wstrb : owner == 3'd2 ? m2_wstrb :
                      owner == 3'd1 ? m1_wstrb : m0_wstrb;
    assign s_wlast  = owner == 3'd6 ? m6_wlast : owner == 3'd5 ? m5_wlast : owner == 3'd4 ? m4_wlast :
                      owner == 3'd3 ? m3_wlast : owner == 3'd2 ? m2_wlast :
                      owner == 3'd1 ? m1_wlast : m0_wlast;
    assign s_wvalid = busy & (owner == 3'd6 ? m6_wvalid : owner == 3'd5 ? m5_wvalid : owner == 3'd4 ? m4_wvalid :
                              owner == 3'd3 ? m3_wvalid : owner == 3'd2 ? m2_wvalid :
                              owner == 3'd1 ? m1_wvalid : m0_wvalid);

    assign m0_wready = busy & (owner == 3'd0) & s_wready;
    assign m1_wready = busy & (owner == 3'd1) & s_wready;
    assign m2_wready = busy & (owner == 3'd2) & s_wready;
    assign m3_wready = busy & (owner == 3'd3) & s_wready;
    assign m4_wready = busy & (owner == 3'd4) & s_wready;
    assign m5_wready = busy & (owner == 3'd5) & s_wready;
    assign m6_wready = busy & (owner == 3'd6) & s_wready;

    // B path: single outstanding -> the owner gets the fabric-minted response
    assign m0_bvalid = busy & (owner == 3'd0) & s_bvalid;
    assign m1_bvalid = busy & (owner == 3'd1) & s_bvalid;
    assign m2_bvalid = busy & (owner == 3'd2) & s_bvalid;
    assign m3_bvalid = busy & (owner == 3'd3) & s_bvalid;
    assign m4_bvalid = busy & (owner == 3'd4) & s_bvalid;
    assign m5_bvalid = busy & (owner == 3'd5) & s_bvalid;
    assign m6_bvalid = busy & (owner == 3'd6) & s_bvalid;
    assign m0_bid    = s_bid;
    assign m1_bid    = s_bid;
    assign m2_bid    = s_bid;
    assign m3_bid    = s_bid;
    assign m4_bid    = s_bid;
    assign m5_bid    = s_bid;
    assign m6_bid    = s_bid;
    assign m0_bresp  = s_bresp;
    assign m1_bresp  = s_bresp;
    assign m2_bresp  = s_bresp;
    assign m3_bresp  = s_bresp;
    assign m4_bresp  = s_bresp;
    assign m5_bresp  = s_bresp;
    assign m6_bresp  = s_bresp;
    assign s_bready  = busy & (owner == 3'd6 ? m6_bready : owner == 3'd5 ? m5_bready : owner == 3'd4 ? m4_bready :
                               owner == 3'd3 ? m3_bready : owner == 3'd2 ? m2_bready :
                               owner == 3'd1 ? m1_bready : m0_bready);

    always @(posedge clk) begin
        if (rst) begin
            busy      <= 1'b0;
            owner     <= 3'd0;
            rr        <= 3'd0;
            sel_valid <= 1'b0;
            sel       <= 3'd0;
            selected_awlen <= 8'd0;
        end
        else begin
            if (!busy && eff_valid && s_awready) begin
                // lock the slot to the accepted master; next idle grant favors
                // the following master in round-robin order
                busy      <= 1'b1;
                owner     <= eff_sel;
                rr        <= (eff_sel == 3'd6) ? 3'd0 : (eff_sel + 3'd1);
                sel_valid <= 1'b0;
            end
            else if (!busy && !sel_valid && pick_v) begin
                // register the winner before presenting AW, even if ready;
                // keep it frozen throughout downstream backpressure
                sel_valid <= 1'b1;
                sel       <= pick_sel;
                case(pick_sel)
                    3'd0:selected_awlen<=m0_awlen;
                    3'd1:selected_awlen<=m1_awlen;
                    3'd2:selected_awlen<=m2_awlen;
                    3'd3:selected_awlen<=m3_awlen;
                    3'd4:selected_awlen<=m4_awlen;
                    3'd5:selected_awlen<=m5_awlen;
                    default:selected_awlen<=m6_awlen;
                endcase
            end
            else if (busy && s_bvalid && s_bready) begin
                busy <= 1'b0;
            end
        end
    end

endmodule
