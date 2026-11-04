//============================================================================
// ovreg_axil_decode.v : AXI-Lite 5-way address decoder for the M01 window
//   (0x2000_0000, reached via axi_to_axi_lite from crossbar M01)
//
//   addr[11:10]=00, addr[9:8]=00 : ov5640_reg  (0x2000_0000~0x00FF)  CAM1
//   addr[11:10]=00, addr[9:8]=01 : prep_regs   (0x2000_0100~0x01FF, doc
//                                              +0x100 ~ +0x17C)
//   addr[11:10]=00, addr[9:8]=10 : ov5640_reg  (0x2000_0200~0x02FF)  CAM2
//   addr[11:10]=00, addr[9:8]=11 : prep_regs (default, legacy addr[8]=1)
//   addr[11:10]=01, addr[9]=0    : ov5640_reg  (0x2000_0400~0x05FF)  CAM3
//   addr[11:10]=01, addr[9]=1    : ov5640_reg  (0x2000_0600~0x07FF)  CAM4
//     (CAM3/CAM4 windows are 0x200 each: main regs +0x000 and SCCB +0x100)
//
//   AW/W and AR are steered by the address captured at handshake; B/R are
//   routed back by the same captured value. Single-outstanding per channel
//   (AXI-Lite semantics).
//============================================================================
module ovreg_axil_decode #(
    parameter ADDR_SEL_LSB = 8          // addr[LSB+1:LSB] selects the slave
)(
    input          clk,
    input          rst,                 // active high, synchronous to axi_clk

    // upstream (from axi_to_axi_lite, M01)
    input          s_awvalid,
    output         s_awready,
    input  [31:0]  s_awaddr,
    input          s_wvalid,
    output         s_wready,
    input  [31:0]  s_wdata,
    input  [3:0]   s_wstrb,
    output         s_bvalid,
    input          s_bready,
    output  [1:0]  s_bresp,
    input          s_arvalid,
    output         s_arready,
    input  [31:0]  s_araddr,
    output         s_rvalid,
    input          s_rready,
    output  [31:0] s_rdata,
    output  [1:0]  s_rresp,

    // downstream slave 0 : ov5640_reg segment (CAM1)
    output         m0_awvalid,
    input          m0_awready,
    output [31:0]  m0_awaddr,
    output         m0_wvalid,
    input          m0_wready,
    output [31:0]  m0_wdata,
    output [3:0]   m0_wstrb,
    input          m0_bvalid,
    output         m0_bready,
    input   [1:0]  m0_bresp,
    output         m0_arvalid,
    input          m0_arready,
    output [31:0]  m0_araddr,
    input          m0_rvalid,
    output         m0_rready,
    input  [31:0]  m0_rdata,
    input   [1:0]  m0_rresp,

    // downstream slave 1 : prep_regs segment
    output         m1_awvalid,
    input          m1_awready,
    output [31:0]  m1_awaddr,
    output         m1_wvalid,
    input          m1_wready,
    output [31:0]  m1_wdata,
    output [3:0]   m1_wstrb,
    input          m1_bvalid,
    output         m1_bready,
    input   [1:0]  m1_bresp,
    output         m1_arvalid,
    input          m1_arready,
    output [31:0]  m1_araddr,
    input          m1_rvalid,
    output         m1_rready,
    input  [31:0]  m1_rdata,
    input   [1:0]  m1_rresp,

    // downstream slave 2 : ov5640_reg segment (CAM2, 0x2000_0200~0x02FF)
    output         m2_awvalid,
    input          m2_awready,
    output [31:0]  m2_awaddr,
    output         m2_wvalid,
    input          m2_wready,
    output [31:0]  m2_wdata,
    output [3:0]   m2_wstrb,
    input          m2_bvalid,
    output         m2_bready,
    input   [1:0]  m2_bresp,
    output         m2_arvalid,
    input          m2_arready,
    output [31:0]  m2_araddr,
    input          m2_rvalid,
    output         m2_rready,
    input  [31:0]  m2_rdata,
    input   [1:0]  m2_rresp,

    // downstream slave 3 : ov5640_reg segment (CAM3, 0x2000_0400~0x04FF)
    //   selected by addr[ADDR_SEL_LSB+3 : ADDR_SEL_LSB+2] == 01
    output         m3_awvalid,
    input          m3_awready,
    output [31:0]  m3_awaddr,
    output         m3_wvalid,
    input          m3_wready,
    output [31:0]  m3_wdata,
    output [3:0]   m3_wstrb,
    input          m3_bvalid,
    output         m3_bready,
    input   [1:0]  m3_bresp,
    output         m3_arvalid,
    input          m3_arready,
    output [31:0]  m3_araddr,
    input          m3_rvalid,
    output         m3_rready,
    input  [31:0]  m3_rdata,
    input   [1:0]  m3_rresp,

    // downstream slave 4 : ov5640_reg segment (CAM4, 0x2000_0600~0x07FF)
    //   selected by addr[11:10]==01 and addr[9]==1 (0x600 main + 0x700 SCCB)
    output         m4_awvalid,
    input          m4_awready,
    output [31:0]  m4_awaddr,
    output         m4_wvalid,
    input          m4_wready,
    output [31:0]  m4_wdata,
    output [3:0]   m4_wstrb,
    input          m4_bvalid,
    output         m4_bready,
    input   [1:0]  m4_bresp,
    output         m4_arvalid,
    input          m4_arready,
    output [31:0]  m4_araddr,
    input          m4_rvalid,
    output         m4_rready,
    input  [31:0]  m4_rdata,
    input   [1:0]  m4_rresp
);

    // [REGSLICE 2026-10-28] Registered decode. AW/W and AR are captured into
    // local registers, the route is decoded once at capture, and every
    // downstream valid/address/data comes straight from a flop (one private
    // copy per slave). The old combinational s_awaddr -> route -> m*_awvalid
    // -> slave register CE path failed ddrphy_sysclk setup by 1.5 ns.
    // Each transaction costs one extra cycle; ordering and payload are
    // unchanged. Single outstanding write and read, as before.
    function [3:0] runtime_route(input [31:0] addr);
        begin
            // Explicit full-address aliases: no low-page accidental collision.
            if(addr[31:8] == 24'h20000b) runtime_route = 4'h1;
            else if(addr[31:8] == 24'h20000c) runtime_route = 4'h0;
            else if(addr[31:8] == 24'h20000d) runtime_route = 4'h4;
            else if(addr[31:8] == 24'h20000e) runtime_route = 4'h6;
            else if(addr[31:8] == 24'h200009) runtime_route = 4'h4;
            else if(addr[31:8] == 24'h20000a) runtime_route = 4'h6;
            else runtime_route = addr[ADDR_SEL_LSB+3 : ADDR_SEL_LSB];
        end
    endfunction

    // 4-bit route -> one-hot {m4,m3,m2,m1,m0}. Within the camera page
    // sel[1] splits CAM3 from CAM4; sel==11 in page 0 is legacy prep (m1).
    function [4:0] onehot(input [3:0] sel);
        begin
            if (sel[3:2] == 2'b01) onehot = sel[1] ? 5'b10000 : 5'b01000;
            else if (sel[1:0] == 2'b00) onehot = 5'b00001;
            else if (sel[1:0] == 2'b10) onehot = 5'b00100;
            else onehot = 5'b00010;
        end
    endfunction

    // CDC host diagnostics: four unused, 16-byte aligned reads per 0x200 stride.
    // Route by the 3-bit camera index addr[11:9] (cam1=000, cam2=001,
    // cam3=010, cam4=011); sel code = {index, 1'b0}.
    wire cdc_read = (s_araddr[31:11] == (32'h20000000 >> 11)) &&
                   (s_araddr[11:9] < 4) &&
                   ((s_araddr[8:0] == 9'h190) || (s_araddr[8:0] == 9'h1a0) ||
                    (s_araddr[8:0] == 9'h1b0) || (s_araddr[8:0] == 9'h1c0));
    wire [3:0] ar_route = cdc_read ? {s_araddr[11:9], 1'b0} :
                         runtime_route(s_araddr);

    integer i;

    //----------------------------------------
    // write path
    //----------------------------------------
    reg aw_have, w_have, w_issued;
    reg [4:0] w_sel;                     // one-hot target of the held write
    reg [4:0] awv_q, wv_q;               // per-slave valids, cleared on accept
    (* syn_preserve=1 *) reg [31:0] awaddr_q [0:4];
    (* syn_preserve=1 *) reg [31:0] wdata_q  [0:4];
    (* syn_preserve=1 *) reg [3:0]  wstrb_q  [0:4];
    wire [4:0] m_awready_v = {m4_awready, m3_awready, m2_awready, m1_awready, m0_awready};
    wire [4:0] m_wready_v  = {m4_wready,  m3_wready,  m2_wready,  m1_wready,  m0_wready};
    wire [4:0] m_bvalid_v  = {m4_bvalid,  m3_bvalid,  m2_bvalid,  m1_bvalid,  m0_bvalid};

    assign s_awready = !aw_have;
    assign s_wready  = !w_have;
    // B is offered upstream only after both AW and W were accepted downstream.
    wire w_accepted = w_issued && !(|awv_q) && !(|wv_q);
    assign s_bvalid = w_accepted && |(m_bvalid_v & w_sel);
    assign s_bresp  = w_sel[4] ? m4_bresp : w_sel[3] ? m3_bresp :
                      w_sel[0] ? m0_bresp : (w_sel[2] ? m2_bresp : m1_bresp);
    wire [4:0] m_bready_v = (w_accepted && s_bready) ? w_sel : 5'b00000;

    always @(posedge clk) begin
        if (rst) begin
            aw_have <= 1'b0; w_have <= 1'b0; w_issued <= 1'b0;
            w_sel <= 5'b00001; awv_q <= 5'b0; wv_q <= 5'b0;
        end else begin
            if (s_awvalid && !aw_have) begin
                aw_have <= 1'b1;
                w_sel <= onehot(runtime_route(s_awaddr));
            end
            if (s_wvalid && !w_have)
                w_have <= 1'b1;
            // Present AW and W together: ov5640_reg only accepts both at once.
            if (aw_have && w_have && !w_issued) begin
                w_issued <= 1'b1;
                awv_q <= w_sel;
                wv_q <= w_sel;
            end else begin
                awv_q <= awv_q & ~m_awready_v;
                wv_q <= wv_q & ~m_wready_v;
            end
            if (s_bvalid && s_bready) begin
                aw_have <= 1'b0; w_have <= 1'b0; w_issued <= 1'b0;
            end
        end
    end
    always @(posedge clk) begin
        for (i = 0; i < 5; i = i + 1) begin
            if (s_awvalid && !aw_have) awaddr_q[i] <= s_awaddr;
            if (s_wvalid && !w_have) begin
                wdata_q[i] <= s_wdata;
                wstrb_q[i] <= s_wstrb;
            end
        end
    end

    assign {m4_awvalid, m3_awvalid, m2_awvalid, m1_awvalid, m0_awvalid} = awv_q;
    assign {m4_wvalid,  m3_wvalid,  m2_wvalid,  m1_wvalid,  m0_wvalid}  = wv_q;
    assign {m4_bready,  m3_bready,  m2_bready,  m1_bready,  m0_bready}  = m_bready_v;
    assign m0_awaddr = awaddr_q[0]; assign m0_wdata = wdata_q[0]; assign m0_wstrb = wstrb_q[0];
    assign m1_awaddr = awaddr_q[1]; assign m1_wdata = wdata_q[1]; assign m1_wstrb = wstrb_q[1];
    assign m2_awaddr = awaddr_q[2]; assign m2_wdata = wdata_q[2]; assign m2_wstrb = wstrb_q[2];
    assign m3_awaddr = awaddr_q[3]; assign m3_wdata = wdata_q[3]; assign m3_wstrb = wstrb_q[3];
    assign m4_awaddr = awaddr_q[4]; assign m4_wdata = wdata_q[4]; assign m4_wstrb = wstrb_q[4];

    //----------------------------------------
    // read path
    //----------------------------------------
    reg ar_have, ar_issue;
    reg [4:0] r_sel, arv_q;
    (* syn_preserve=1 *) reg [31:0] araddr_q [0:4];
    wire [4:0] m_arready_v = {m4_arready, m3_arready, m2_arready, m1_arready, m0_arready};
    wire [4:0] m_rvalid_v  = {m4_rvalid,  m3_rvalid,  m2_rvalid,  m1_rvalid,  m0_rvalid};

    assign s_arready = !ar_have;
    wire r_accepted = ar_have && !ar_issue && !(|arv_q);
    // R is buffered: the selected slave's data/resp are registered here and
    // offered upstream from flops, so the 5-way read mux no longer feeds the
    // crossbar R register in the same clock (setup -0.29 ns).
    reg r_buf_valid;
    reg [31:0] r_buf_data;
    reg [1:0] r_buf_resp;
    wire [31:0] r_mux_data = r_sel[4] ? m4_rdata : r_sel[3] ? m3_rdata :
                             r_sel[0] ? m0_rdata : (r_sel[2] ? m2_rdata : m1_rdata);
    wire [1:0] r_mux_resp = r_sel[4] ? m4_rresp : r_sel[3] ? m3_rresp :
                            r_sel[0] ? m0_rresp : (r_sel[2] ? m2_rresp : m1_rresp);
    wire [4:0] m_rready_v = (r_accepted && !r_buf_valid) ? r_sel : 5'b00000;
    wire r_take = r_accepted && !r_buf_valid && |(m_rvalid_v & r_sel);
    assign s_rvalid = r_buf_valid;
    assign s_rdata  = r_buf_data;
    assign s_rresp  = r_buf_resp;

    always @(posedge clk) begin
        if (rst) begin
            ar_have <= 1'b0; ar_issue <= 1'b0; r_sel <= 5'b00001; arv_q <= 5'b0;
            r_buf_valid <= 1'b0; r_buf_data <= 32'd0; r_buf_resp <= 2'b00;
        end else begin
            if (r_take) begin
                r_buf_valid <= 1'b1;
                r_buf_data <= r_mux_data;
                r_buf_resp <= r_mux_resp;
            end
            ar_issue <= 1'b0;
            if (s_arvalid && !ar_have) begin
                ar_have <= 1'b1;
                ar_issue <= 1'b1;
                r_sel <= onehot(ar_route);
            end
            if (ar_issue) arv_q <= r_sel;
            else arv_q <= arv_q & ~m_arready_v;
            if (s_rvalid && s_rready) begin
                ar_have <= 1'b0;
                r_buf_valid <= 1'b0;
            end
        end
    end
    always @(posedge clk) begin
        for (i = 0; i < 5; i = i + 1)
            if (s_arvalid && !ar_have) araddr_q[i] <= s_araddr;
    end

    assign {m4_arvalid, m3_arvalid, m2_arvalid, m1_arvalid, m0_arvalid} = arv_q;
    assign {m4_rready,  m3_rready,  m2_rready,  m1_rready,  m0_rready}  = m_rready_v;
    assign m0_araddr = araddr_q[0];
    assign m1_araddr = araddr_q[1];
    assign m2_araddr = araddr_q[2];
    assign m3_araddr = araddr_q[3];
    assign m4_araddr = araddr_q[4];

endmodule
