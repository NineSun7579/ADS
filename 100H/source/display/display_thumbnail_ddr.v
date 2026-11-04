`timescale 1ns/1ps
// Isolated display endpoint. Same command/AXI interface as delivery_rgb_ddr.
// HMIC native 16-bit-word addresses; burst16 and bus-address stride256.
// Reset must include the connected fabric; any fault quarantines until reset.
module display_thumbnail_ddr #(
    parameter integer WIDTH=640, HEIGHT=480
) (
    input wire clk, rst_n,
    input wire cmd_valid,
    output wire cmd_ready,
    input wire [31:0] cmd_src, cmd_dst,
    output reg busy, done, error,
    output wire config_error,
    output reg [31:0] m_axi_araddr,
    output reg [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    input wire [127:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast, m_axi_rvalid,
    output wire m_axi_rready,
    output reg [31:0] m_axi_awaddr,
    output reg [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst,
    output wire m_axi_awvalid,
    input wire m_axi_awready,
    output reg [127:0] m_axi_wdata,
    output reg [15:0] m_axi_wstrb,
    output wire m_axi_wlast, m_axi_wvalid,
    input wire m_axi_wready,
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready
);
    localparam integer PIXELS=WIDTH*HEIGHT;
    localparam integer OUT_PIXELS=(WIDTH/2)*(HEIGHT/2);
    // Reserve entire native-address slots, including unused half-slot space.
    localparam integer SRC_SPAN=((PIXELS+127)/128)*256;
    localparam integer DST_SPAN=((OUT_PIXELS+127)/128)*256;
    localparam GEOMETRY_OK=WIDTH>=2 && WIDTH<=2048 && HEIGHT>=2 &&
        HEIGHT<=2048 && WIDTH%2==0 && HEIGHT%2==0;
    // Validate captured addresses one cycle after admission. This keeps the
    // range/overlap carry chain off the AXI address register enables.
    wire [32:0] src_end={1'b0,m_axi_araddr}+SRC_SPAN;
    wire [32:0] dst_end={1'b0,m_axi_awaddr}+DST_SPAN;
    wire address_ok=m_axi_araddr[7:0]==0 && m_axi_awaddr[7:0]==0 &&
        src_end<=33'h010000000 && dst_end<=33'h010000000 &&
        (src_end<={1'b0,m_axi_awaddr} || dst_end<={1'b0,m_axi_araddr});
    reg failed, checking;
    localparam RD_IDLE=0, RD_ADDR=1, RD_DATA=2, RD_HOLD=3;
    reg [1:0] rd_state;
    reg [127:0] rd_buffer[0:15];
    reg [3:0] rd_receive, rd_index;
    reg rd_overrun;
    reg [2:0] rd_lane;
    reg [31:0] pixels_taken;
    reg [127:0] wr_buffer[0:15];
    reg [15:0] wr_keep[0:15];
    reg [4:0] wr_count;
    reg [3:0] wr_index;
    reg wr_active, aw_pending, w_pending, wr_final, final_b_seen;
    wire pipeline_rst_n=rst_n && busy && !failed;
    wire pixel_ready, thumb_valid, thumb_ready, thumb_sof, thumb_eof;
    wire [15:0] thumb_pixel;
    wire packed_valid, packed_ready, packed_last;
    wire [127:0] packed_data;
    wire [15:0] packed_keep;
    wire [31:0] remaining_words=(PIXELS-pixels_taken+7)/8;
    wire read_bad=(m_axi_rresp!=0) || rd_overrun ||
        (m_axi_rlast!=(rd_receive==m_axi_arlen));

    assign config_error=!GEOMETRY_OK;
    assign cmd_ready=rst_n && !busy && !failed && !config_error;
    assign m_axi_arsize=4;
    assign m_axi_arburst=1;
    // Never withdraw requests after a fault: all announced transactions drain.
    assign m_axi_arvalid=rst_n && rd_state==RD_ADDR;
    assign m_axi_rready=rst_n && rd_state==RD_DATA;
    assign m_axi_awsize=4;
    assign m_axi_awburst=1;
    assign m_axi_awvalid=rst_n && aw_pending;
    assign m_axi_wvalid=rst_n && w_pending;
    assign m_axi_wlast=wr_index==m_axi_awlen;
    assign m_axi_bready=rst_n && wr_active && !aw_pending && !w_pending;
    assign packed_ready=busy && !failed && !wr_active;

    rgb565_display_decimator #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) scaler (
        .clk(clk),.rst_n(pipeline_rst_n),
        .s_pixel(rd_buffer[rd_index][rd_lane*16 +: 16]),
        .s_valid(rd_state==RD_HOLD && !failed),.s_ready(pixel_ready),
        .m_pixel(thumb_pixel),.m_valid(thumb_valid),.m_ready(thumb_ready),
        .m_sof(thumb_sof),.m_eof(thumb_eof));
    display_rgb565_pack128 packer (
        .clk(clk),.rst_n(pipeline_rst_n),.s_data(thumb_pixel),
        .s_valid(thumb_valid),.s_ready(thumb_ready),.s_last(thumb_eof),
        .m_data(packed_data),.m_keep(packed_keep),.m_valid(packed_valid),
        .m_ready(packed_ready),.m_last(packed_last));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy<=0; done<=0; error<=0; failed<=0; checking<=0;
            rd_state<=RD_IDLE; rd_lane<=0; pixels_taken<=0;
            rd_receive<=0; rd_index<=0; rd_overrun<=0;
            m_axi_araddr<=0; m_axi_arlen<=0; m_axi_awaddr<=0;
            m_axi_awlen<=0; m_axi_wdata<=0; m_axi_wstrb<=0;
            wr_count<=0; wr_index<=0; wr_active<=0;
            aw_pending<=0; w_pending<=0; wr_final<=0; final_b_seen<=0;
        end else begin
            done<=0;
            if (cmd_valid && cmd_ready) begin
                busy<=1; checking<=1; error<=0; pixels_taken<=0;
                m_axi_araddr<=cmd_src; m_axi_awaddr<=cmd_dst;
                final_b_seen<=0; wr_final<=0;
            end
            if (checking) begin
                checking<=0;
                error<=!address_ok;
                if (!address_ok) begin
                    busy<=0; failed<=1; done<=1;
                end
            end
            if (busy && !checking) begin
                if (rd_state==RD_IDLE && !failed && pixels_taken<PIXELS) begin
                    rd_state<=RD_ADDR;
                    m_axi_arlen<=remaining_words>=16 ? 15 : remaining_words-1;
                end
                if (m_axi_arvalid && m_axi_arready) begin
                    rd_state<=RD_DATA; rd_receive<=0; rd_overrun<=0;
                end
                if (m_axi_rvalid && m_axi_rready) begin
                    if (!rd_overrun) rd_buffer[rd_receive]<=m_axi_rdata;
                    if (read_bad) begin failed<=1; error<=1; end
                    // RLAST retires the read transaction. A missing RLAST at
                    // the expected beat is a fault, but keep draining until
                    // actual RLAST (or coordinated fabric reset if absent).
                    if (m_axi_rlast) begin
                        if (failed || read_bad) rd_state<=RD_IDLE;
                        else begin rd_lane<=0; rd_index<=0; rd_state<=RD_HOLD; end
                    end else if (rd_receive==m_axi_arlen) rd_overrun<=1;
                    else if (!rd_overrun) rd_receive<=rd_receive+1'b1;
                end
                if (rd_state==RD_HOLD) begin
                    if (failed) rd_state<=RD_IDLE;
                    else if (pixel_ready) begin
                        pixels_taken<=pixels_taken+1;
                        if (rd_lane==7 || pixels_taken==PIXELS-1) begin
                            rd_lane<=0;
                            if (rd_index==m_axi_arlen || pixels_taken==PIXELS-1) begin
                                rd_state<=RD_IDLE;
                                m_axi_araddr<=m_axi_araddr+256;
                            end else rd_index<=rd_index+1'b1;
                        end else rd_lane<=rd_lane+1'b1;
                    end
                end
                if (packed_valid && packed_ready) begin
                    wr_buffer[wr_count]<=packed_data;
                    wr_keep[wr_count]<=packed_keep;
                    wr_count<=wr_count+1'b1;
                    if (wr_count==15 || packed_last) begin
                        m_axi_wdata<=wr_count==0 ? packed_data : wr_buffer[0];
                        m_axi_wstrb<=wr_count==0 ? packed_keep : wr_keep[0];
                        m_axi_awlen<=wr_count; wr_index<=0;
                        wr_final<=packed_last; wr_active<=1;
                        aw_pending<=1; w_pending<=1;
                    end
                end
                if (m_axi_awvalid && m_axi_awready) aw_pending<=0;
                if (m_axi_wvalid && m_axi_wready) begin
                    if (m_axi_wlast) w_pending<=0;
                    else begin
                        wr_index<=wr_index+1'b1;
                        m_axi_wdata<=wr_buffer[wr_index+1'b1];
                        m_axi_wstrb<=wr_keep[wr_index+1'b1];
                    end
                end
                if (m_axi_bvalid && m_axi_bready) begin
                    wr_active<=0; wr_count<=0;
                    m_axi_awaddr<=m_axi_awaddr+256;
                    if (m_axi_bresp!=0) begin failed<=1; error<=1; end
                    else if (wr_final) final_b_seen<=1;
                end
                // EOF occurs before the last odd row has drained. Require
                // both independent barriers, never completion on EOF alone.
                if (!failed && final_b_seen && pixels_taken==PIXELS &&
                    rd_state==RD_IDLE && !wr_active) begin
                    busy<=0; done<=1;
                end
                if (failed && rd_state==RD_IDLE && !wr_active) begin
                    busy<=0; done<=1; wr_count<=0;
                end
            end
        end
    end
endmodule
