// One outstanding write/read independently. AW and W may arrive in either order.
// The FULL 256-byte 0x20020000 page, and the native HDMI descriptor page
// 0x20021000-0x200211ff (read-only), and the native BEV lane page
// 0x20021200-0x200213ff are intercepted before legacy low-bit decode.
module c5_axil_page_router(
 input wire clk,rst,
 input wire [31:0] s_awaddr,input wire s_awvalid,output wire s_awready,
 input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wvalid,output wire s_wready,
 output wire [1:0] s_bresp,output wire s_bvalid,input wire s_bready,
 input wire [31:0] s_araddr,input wire s_arvalid,output wire s_arready,
 output wire [31:0] s_rdata,output wire [1:0] s_rresp,output wire s_rvalid,input wire s_rready,
 output wire [63:0] m_awaddr,output wire [1:0] m_awvalid,input wire [1:0] m_awready,
 output wire [63:0] m_wdata,output wire [7:0] m_wstrb,output wire [1:0] m_wvalid,input wire [1:0] m_wready,
 input wire [3:0] m_bresp,input wire [1:0] m_bvalid,output wire [1:0] m_bready,
 output wire [63:0] m_araddr,output wire [1:0] m_arvalid,input wire [1:0] m_arready,
 input wire [63:0] m_rdata,input wire [3:0] m_rresp,input wire [1:0] m_rvalid,output wire [1:0] m_rready
);
 reg ah,wh,asent,wsent,wsel,ractive,rsent,rsel;
 reg [31:0] aa,wd,ra;reg [3:0] st;
 assign s_awready=!ah; assign s_wready=!wh;
 assign m_awaddr={aa,aa};assign m_wdata={wd,wd};assign m_wstrb={st,st};
 assign m_awvalid=(ah && wh && !asent)?(wsel?2'b10:2'b01):0;
 assign m_wvalid=(ah && wh && !wsent)?(wsel?2'b10:2'b01):0;
 assign s_bvalid=ah && wh && asent && wsent && m_bvalid[wsel];
 assign s_bresp=m_bresp[wsel*2+:2];
 assign m_bready=(ah && wh && asent && wsent && s_bready)?(wsel?2'b10:2'b01):0;
 assign s_arready=!ractive;
 assign m_araddr={ra,ra};assign m_arvalid=(ractive && !rsent)?(rsel?2'b10:2'b01):0;
 assign s_rvalid=ractive && rsent && m_rvalid[rsel];
 assign s_rdata=m_rdata[rsel*32+:32];assign s_rresp=m_rresp[rsel*2+:2];
 assign m_rready=(ractive && rsent && s_rready)?(rsel?2'b10:2'b01):0;
 always @(posedge clk) begin
  if(rst) begin ah<=0;wh<=0;asent<=0;wsent<=0;aa<=0;wd<=0;st<=0;wsel<=0;ractive<=0;rsent<=0;ra<=0;rsel<=0;end
  else begin
   if(s_awvalid && s_awready) begin ah<=1;aa<=s_awaddr;wsel<=(s_awaddr[31:8]==24'h200200 || s_awaddr[31:9]==23'h100109);end
   if(s_wvalid && s_wready) begin wh<=1;wd<=s_wdata;st<=s_wstrb;end
   if(|(m_awvalid&m_awready)) asent<=1;
   if(|(m_wvalid&m_wready)) wsent<=1;
   if(s_bvalid && s_bready) begin ah<=0;wh<=0;asent<=0;wsent<=0;end
    if(s_arvalid && s_arready) begin ractive<=1;rsent<=0;ra<=s_araddr;rsel<=(s_araddr[31:8]==24'h200200 || s_araddr[31:9]==23'h100108 || s_araddr[31:9]==23'h100109);end
   if(|(m_arvalid&m_arready)) rsent<=1;
   if(s_rvalid && s_rready) begin ractive<=0;rsent<=0;end
  end
 end
endmodule
