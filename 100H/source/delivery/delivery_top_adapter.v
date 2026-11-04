`timescale 1ns/1ps
module delivery_top_adapter #(parameter WIDTH=640, HEIGHT=480, OUT_HEIGHT=640, TOP_ROWS=80) (
input wire clk, rst,
output wire [5:0] capture_hold,
input wire [191:0] camera_prev_base, camera_bank0, camera_bank1, camera_sequence,
input wire [11:0] camera_published,
input wire [5:0] camera_writer_idle, camera_pending, camera_flush, camera_dma_idle,
input wire [5:0] camera_cmd_valid, camera_awvalid, camera_wvalid, camera_abort,
input wire [6:0] s_axi_awid,
input wire [31:0] s_axi_awaddr,
input wire [7:0] s_axi_awlen,
input wire [2:0] s_axi_awsize,
input wire [1:0] s_axi_awburst,
input wire s_axi_awlock,
input wire [3:0] s_axi_awcache,
input wire [2:0] s_axi_awprot,
input wire [3:0] s_axi_awqos,
input wire [3:0] s_axi_awregion,
input wire s_axi_awvalid,
output wire s_axi_awready,
input wire [127:0] s_axi_wdata,
input wire [15:0] s_axi_wstrb,
input wire s_axi_wlast,
input wire s_axi_wvalid,
output wire s_axi_wready,
output wire [6:0] s_axi_bid,
output wire [1:0] s_axi_bresp,
output wire s_axi_bvalid,
input wire s_axi_bready,
input wire [6:0] s_axi_arid,
input wire [31:0] s_axi_araddr,
input wire [7:0] s_axi_arlen,
input wire [2:0] s_axi_arsize,
input wire [1:0] s_axi_arburst,
input wire s_axi_arlock,
input wire [3:0] s_axi_arcache,
input wire [2:0] s_axi_arprot,
input wire [3:0] s_axi_arqos,
input wire [3:0] s_axi_arregion,
input wire s_axi_arvalid,
output wire s_axi_arready,
output wire [6:0] s_axi_rid,
output wire [127:0] s_axi_rdata,
output wire [1:0] s_axi_rresp,
output wire s_axi_rlast,
output wire s_axi_rvalid,
input wire s_axi_rready,
output wire [31:0] m_axi_araddr,
output wire [7:0] m_axi_arlen,
output wire [2:0] m_axi_arsize,
output wire [1:0] m_axi_arburst,
output wire m_axi_arvalid,
input wire m_axi_arready,
input wire [127:0] m_axi_rdata,
input wire [1:0] m_axi_rresp,
input wire m_axi_rlast,
input wire m_axi_rvalid,
output wire m_axi_rready,
output wire [31:0] m_axi_awaddr,
output wire [7:0] m_axi_awlen,
output wire [2:0] m_axi_awsize,
output wire [1:0] m_axi_awburst,
output wire m_axi_awvalid,
input wire m_axi_awready,
output wire [127:0] m_axi_wdata,
output wire [15:0] m_axi_wstrb,
output wire m_axi_wlast,
output wire m_axi_wvalid,
input wire m_axi_wready,
input wire [1:0] m_axi_bresp,
input wire m_axi_bvalid,
output wire m_axi_bready
);
wire [31:0] l_awaddr;
wire l_awvalid;
wire l_awready;
wire [31:0] l_wdata;
wire [3:0] l_wstrb;
wire l_wvalid;
wire l_wready;
wire [1:0] l_bresp;
wire l_bvalid;
wire l_bready;
wire [31:0] l_araddr;
wire l_arvalid;
wire l_arready;
wire [31:0] l_rdata;
wire [1:0] l_rresp;
wire l_rvalid;
wire l_rready;
wire cmd_valid,cmd_ready,busy,done,error,config_error;
wire [31:0] src,dst;
wire selected_mode;
axi_to_axi_lite #(.AXI_ID_LEN(7)) mmio_bridge (
.axi_clk(clk),.axi_rst(rst),
.s_axi_awid(s_axi_awid),
.s_axi_awaddr(s_axi_awaddr),
.s_axi_awlen(s_axi_awlen),
.s_axi_awsize(s_axi_awsize),
.s_axi_awburst(s_axi_awburst),
.s_axi_awlock({1'b0,s_axi_awlock}),
.s_axi_awcache(s_axi_awcache),
.s_axi_awprot(s_axi_awprot[1:0]),
.s_axi_awqos(s_axi_awqos),
.s_axi_awregion(s_axi_awregion),
.s_axi_awvalid(s_axi_awvalid),
.s_axi_awready(s_axi_awready),
.s_axi_wdata(s_axi_wdata),
.s_axi_wstrb(s_axi_wstrb),
.s_axi_wlast(s_axi_wlast),
.s_axi_wvalid(s_axi_wvalid),
.s_axi_wready(s_axi_wready),
.s_axi_bid(s_axi_bid),
.s_axi_bresp(s_axi_bresp),
.s_axi_bvalid(s_axi_bvalid),
.s_axi_bready(s_axi_bready),
.s_axi_arid(s_axi_arid),
.s_axi_araddr(s_axi_araddr),
.s_axi_arlen(s_axi_arlen),
.s_axi_arsize(s_axi_arsize),
.s_axi_arburst(s_axi_arburst),
.s_axi_arlock(s_axi_arlock),
.s_axi_arcache(s_axi_arcache),
.s_axi_arprot(s_axi_arprot[1:0]),
.s_axi_arqos(s_axi_arqos),
.s_axi_arregion(s_axi_arregion),
.s_axi_arvalid(s_axi_arvalid),
.s_axi_arready(s_axi_arready),
.s_axi_rid(s_axi_rid),
.s_axi_rdata(s_axi_rdata),
.s_axi_rresp(s_axi_rresp),
.s_axi_rlast(s_axi_rlast),
.s_axi_rvalid(s_axi_rvalid),
.s_axi_rready(s_axi_rready),
.m_axil_awaddr(l_awaddr),
.m_axil_awvalid(l_awvalid),
.m_axil_awready(l_awready),
.m_axil_wdata(l_wdata),
.m_axil_wstrb(l_wstrb),
.m_axil_wvalid(l_wvalid),
.m_axil_wready(l_wready),
.m_axil_bresp(l_bresp),
.m_axil_bvalid(l_bvalid),
.m_axil_bready(l_bready),
.m_axil_araddr(l_araddr),
.m_axil_arvalid(l_arvalid),
.m_axil_arready(l_arready),
.m_axil_rdata(l_rdata),
.m_axil_rresp(l_rresp),
.m_axil_rvalid(l_rvalid),
.m_axil_rready(l_rready)
);
delivery_regs #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.OUT_HEIGHT(OUT_HEIGHT)) regs (
.clk(clk),.rst(rst),
.s_awaddr(l_awaddr),
.s_awvalid(l_awvalid),
.s_awready(l_awready),
.s_wdata(l_wdata),
.s_wstrb(l_wstrb),
.s_wvalid(l_wvalid),
.s_wready(l_wready),
.s_bresp(l_bresp),
.s_bvalid(l_bvalid),
.s_bready(l_bready),
.s_araddr(l_araddr),
.s_arvalid(l_arvalid),
.s_arready(l_arready),
.s_rdata(l_rdata),
.s_rresp(l_rresp),
.s_rvalid(l_rvalid),
.s_rready(l_rready),
.capture_hold(capture_hold),
.camera_prev_base(camera_prev_base),.camera_bank0(camera_bank0),.camera_bank1(camera_bank1),
.camera_sequence(camera_sequence),.camera_published(camera_published),
.camera_writer_idle(camera_writer_idle),.camera_pending(camera_pending),.camera_flush(camera_flush),
.camera_dma_idle(camera_dma_idle),.camera_cmd_valid(camera_cmd_valid),
.camera_awvalid(camera_awvalid),.camera_wvalid(camera_wvalid),.camera_abort(camera_abort),
.cmd_valid(cmd_valid),.cmd_ready(cmd_ready),.cmd_src(src),.cmd_dst(dst),
.selected_mode(selected_mode),
.core_busy(busy),.core_done(done),.core_error(error),.core_config_error(config_error));
// Mode is fixed throughout the cam5 lease, including fault quarantine.
wire rgb_ready, rgb_busy, rgb_done, rgb_error, rgb_config_error;
wire [31:0] rgb_araddr;
wire [7:0] rgb_arlen;
wire [2:0] rgb_arsize;
wire [1:0] rgb_arburst;
wire rgb_arvalid;
wire rgb_rready;
wire [31:0] rgb_awaddr;
wire [7:0] rgb_awlen;
wire [2:0] rgb_awsize;
wire [1:0] rgb_awburst;
wire rgb_awvalid;
wire [127:0] rgb_wdata;
wire [15:0] rgb_wstrb;
wire rgb_wlast;
wire rgb_wvalid;
wire rgb_bready;
wire thumb_ready, thumb_busy, thumb_done, thumb_error, thumb_config_error;
wire [31:0] thumb_araddr;
wire [7:0] thumb_arlen;
wire [2:0] thumb_arsize;
wire [1:0] thumb_arburst;
wire thumb_arvalid;
wire thumb_rready;
wire [31:0] thumb_awaddr;
wire [7:0] thumb_awlen;
wire [2:0] thumb_awsize;
wire [1:0] thumb_awburst;
wire thumb_awvalid;
wire [127:0] thumb_wdata;
wire [15:0] thumb_wstrb;
wire thumb_wlast;
wire thumb_wvalid;
wire thumb_bready;
assign cmd_ready=selected_mode ? thumb_ready : rgb_ready;
assign done=selected_mode ? thumb_done : rgb_done;
assign error=selected_mode ? thumb_error : rgb_error;
assign config_error=selected_mode ? thumb_config_error : rgb_config_error;
assign busy=rgb_busy || thumb_busy;
assign m_axi_araddr=selected_mode ? thumb_araddr : rgb_araddr;
assign m_axi_arlen=selected_mode ? thumb_arlen : rgb_arlen;
assign m_axi_arsize=selected_mode ? thumb_arsize : rgb_arsize;
assign m_axi_arburst=selected_mode ? thumb_arburst : rgb_arburst;
assign m_axi_arvalid=selected_mode ? thumb_arvalid : rgb_arvalid;
assign m_axi_rready=selected_mode ? thumb_rready : rgb_rready;
assign m_axi_awaddr=selected_mode ? thumb_awaddr : rgb_awaddr;
assign m_axi_awlen=selected_mode ? thumb_awlen : rgb_awlen;
assign m_axi_awsize=selected_mode ? thumb_awsize : rgb_awsize;
assign m_axi_awburst=selected_mode ? thumb_awburst : rgb_awburst;
assign m_axi_awvalid=selected_mode ? thumb_awvalid : rgb_awvalid;
assign m_axi_wdata=selected_mode ? thumb_wdata : rgb_wdata;
assign m_axi_wstrb=selected_mode ? thumb_wstrb : rgb_wstrb;
assign m_axi_wlast=selected_mode ? thumb_wlast : rgb_wlast;
assign m_axi_wvalid=selected_mode ? thumb_wvalid : rgb_wvalid;
assign m_axi_bready=selected_mode ? thumb_bready : rgb_bready;
delivery_rgb_ddr #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.OUT_HEIGHT(OUT_HEIGHT),.TOP_ROWS(TOP_ROWS)) rgb_core (
.clk(clk),.rst_n(!rst),.cmd_valid(cmd_valid && !selected_mode),.cmd_ready(rgb_ready),
.cmd_src(src),.cmd_dst(dst),.busy(rgb_busy),.done(rgb_done),
.error(rgb_error),.config_error(rgb_config_error),
.m_axi_araddr(rgb_araddr),
.m_axi_arlen(rgb_arlen),
.m_axi_arsize(rgb_arsize),
.m_axi_arburst(rgb_arburst),
.m_axi_arvalid(rgb_arvalid),
.m_axi_arready((!selected_mode) ? m_axi_arready : 1'd0),
.m_axi_rdata((!selected_mode) ? m_axi_rdata : 128'd0),
.m_axi_rresp((!selected_mode) ? m_axi_rresp : 2'd0),
.m_axi_rlast((!selected_mode) ? m_axi_rlast : 1'd0),
.m_axi_rvalid((!selected_mode) ? m_axi_rvalid : 1'd0),
.m_axi_rready(rgb_rready),
.m_axi_awaddr(rgb_awaddr),
.m_axi_awlen(rgb_awlen),
.m_axi_awsize(rgb_awsize),
.m_axi_awburst(rgb_awburst),
.m_axi_awvalid(rgb_awvalid),
.m_axi_awready((!selected_mode) ? m_axi_awready : 1'd0),
.m_axi_wdata(rgb_wdata),
.m_axi_wstrb(rgb_wstrb),
.m_axi_wlast(rgb_wlast),
.m_axi_wvalid(rgb_wvalid),
.m_axi_wready((!selected_mode) ? m_axi_wready : 1'd0),
.m_axi_bresp((!selected_mode) ? m_axi_bresp : 2'd0),
.m_axi_bvalid((!selected_mode) ? m_axi_bvalid : 1'd0),
.m_axi_bready(rgb_bready)
);
display_thumbnail_ddr #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) thumb_core (
.clk(clk),.rst_n(!rst),.cmd_valid(cmd_valid && selected_mode),.cmd_ready(thumb_ready),
.cmd_src(src),.cmd_dst(dst),.busy(thumb_busy),.done(thumb_done),
.error(thumb_error),.config_error(thumb_config_error),
.m_axi_araddr(thumb_araddr),
.m_axi_arlen(thumb_arlen),
.m_axi_arsize(thumb_arsize),
.m_axi_arburst(thumb_arburst),
.m_axi_arvalid(thumb_arvalid),
.m_axi_arready((selected_mode) ? m_axi_arready : 1'd0),
.m_axi_rdata((selected_mode) ? m_axi_rdata : 128'd0),
.m_axi_rresp((selected_mode) ? m_axi_rresp : 2'd0),
.m_axi_rlast((selected_mode) ? m_axi_rlast : 1'd0),
.m_axi_rvalid((selected_mode) ? m_axi_rvalid : 1'd0),
.m_axi_rready(thumb_rready),
.m_axi_awaddr(thumb_awaddr),
.m_axi_awlen(thumb_awlen),
.m_axi_awsize(thumb_awsize),
.m_axi_awburst(thumb_awburst),
.m_axi_awvalid(thumb_awvalid),
.m_axi_awready((selected_mode) ? m_axi_awready : 1'd0),
.m_axi_wdata(thumb_wdata),
.m_axi_wstrb(thumb_wstrb),
.m_axi_wlast(thumb_wlast),
.m_axi_wvalid(thumb_wvalid),
.m_axi_wready((selected_mode) ? m_axi_wready : 1'd0),
.m_axi_bresp((selected_mode) ? m_axi_bresp : 2'd0),
.m_axi_bvalid((selected_mode) ? m_axi_bvalid : 1'd0),
.m_axi_bready(thumb_bready)
);
endmodule
