`timescale 1ns/1ps
// Isolated single-outstanding AXI4 DDR preprocessing endpoint. ASCII RTL.
// All AXI ports use the same clock. Reset must include the connected fabric.
module delivery_rgb_ddr #(
    parameter integer WIDTH=640, HEIGHT=480, OUT_HEIGHT=640,
    parameter integer TOP_ROWS=80, FILL_VALUE=114
) (
    input wire clk, rst_n,
    input wire cmd_valid,
    output wire cmd_ready,
    input wire [31:0] cmd_src, cmd_dst,
    output reg busy, done, error,
    output wire config_error,
    output reg [31:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,
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
    localparam integer SRC_BYTES=((PIXELS+7)/8)*16;
    localparam integer DST_BYTES=((WIDTH*OUT_HEIGHT*3+15)/16)*16;
    // Bounded counts and the current 256 MiB DDR aperture.
    localparam GEOMETRY_OK=WIDTH>=1 && WIDTH<=2048 && HEIGHT>=1 &&
        HEIGHT<=2048 && OUT_HEIGHT>=HEIGHT && OUT_HEIGHT<=2048 &&
        TOP_ROWS>=0 && TOP_ROWS<=OUT_HEIGHT-HEIGHT &&
        FILL_VALUE>=0 && FILL_VALUE<=255;
    wire [32:0] src_end={1'b0,cmd_src}+SRC_BYTES;
    wire [32:0] dst_end={1'b0,cmd_dst}+DST_BYTES;
    wire address_ok=(cmd_src[7:0]==0) && (cmd_dst[7:0]==0) &&
        src_end<=33'h010000000 && dst_end<=33'h010000000 &&
        ((src_end<={1'b0,cmd_dst}) || (dst_end<={1'b0,cmd_src}));
    reg launch, failed;
    reg [1:0] rd_state;
    localparam RD_IDLE=0, RD_ADDR=1, RD_DATA=2, RD_HOLD=3;
    reg [127:0] rd_word;
    reg [127:0] rd_buffer[0:15];
    reg [3:0] rd_receive, rd_index;
    reg [127:0] wr_buffer[0:15];
    reg [15:0] wr_keep[0:15];
    reg [4:0] wr_count;
    reg [3:0] wr_index;
    reg [2:0] rd_lane;
    reg [31:0] pixels_taken;
    reg wr_active, aw_pending, w_pending, wr_final;
    wire pipeline_rst_n=rst_n && busy && !failed;
    wire lb_start_ready, lb_busy, lb_done, lb_error, lb_config_error;
    wire pixel_ready, rgb_valid, rgb_ready, rgb_last;
    wire [23:0] rgb_data;
    wire packed_valid, packed_ready, packed_last;
    wire [127:0] packed_data;
    wire [15:0] packed_keep;
    assign config_error=!GEOMETRY_OK || lb_config_error;
    assign cmd_ready=rst_n && !busy && !failed && !config_error;
    // The deployed camera/PCIe layout uses 16-beat bursts and a 256-unit
    // stride. HMIC addresses are DDR words (vendor BIST increments by 8
    // per 128-bit beat), not bytes. Do not replace these bursts by sixteen
    // single-beat addresses: that leaves alternate physical beats untouched.
    wire [31:0] remaining_words=(PIXELS-pixels_taken+7)/8;
    assign m_axi_arlen=remaining_words>=16 ? 15 : remaining_words-1;
    assign m_axi_arsize=4;
    assign m_axi_arburst=1;
    // Once asserted, requests are never withdrawn, even after another fault.
    assign m_axi_arvalid=rst_n && rd_state==RD_ADDR;
    assign m_axi_rready=rst_n && rd_state==RD_DATA;
    assign m_axi_awsize=4;
    assign m_axi_awburst=1;
    assign m_axi_awvalid=rst_n && aw_pending;
    assign m_axi_wvalid=rst_n && w_pending;
    assign m_axi_wlast=wr_index==m_axi_awlen;
    assign m_axi_bready=rst_n && wr_active && !aw_pending && !w_pending;
    assign packed_ready=busy && !failed && !wr_active;

    delivery_raw_letterbox #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),
        .OUT_HEIGHT(OUT_HEIGHT),.TOP_ROWS(TOP_ROWS),.FILL_VALUE(FILL_VALUE)) lb (
        .clk(clk),.rst_n(pipeline_rst_n),.start_valid(launch),
        .start_ready(lb_start_ready),.busy(lb_busy),.done(lb_done),
        .frame_error(lb_error),.config_error(lb_config_error),
        .s_data(rd_word[rd_lane*16 +: 16]),
        .s_valid(rd_state==RD_HOLD && !failed),.s_ready(pixel_ready),
        .s_last(pixels_taken==PIXELS-1),.m_data(rgb_data),
        .m_valid(rgb_valid),.m_ready(rgb_ready),.m_last(rgb_last));
    delivery_rgb888_pack128 packer (
        .clk(clk),.rst_n(pipeline_rst_n),.s_data(rgb_data),
        .s_valid(rgb_valid),.s_ready(rgb_ready),.s_last(rgb_last),
        .m_data(packed_data),.m_keep(packed_keep),.m_valid(packed_valid),
        .m_ready(packed_ready),.m_last(packed_last));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy<=0; done<=0; error<=0; failed<=0; launch<=0;
            rd_state<=RD_IDLE; rd_word<=0; rd_lane<=0; pixels_taken<=0;
            m_axi_araddr<=0; m_axi_awaddr<=0; m_axi_wdata<=0;
            m_axi_wstrb<=0; wr_active<=0; aw_pending<=0;
            w_pending<=0; wr_final<=0;
            rd_receive<=0; rd_index<=0; wr_count<=0; wr_index<=0;
            m_axi_awlen<=0;
        end else begin
            done<=0;
            if (cmd_valid && cmd_ready) begin
                error<=!address_ok; failed<=0;
                if (!address_ok) begin
                    done<=1;
                end else begin
                    busy<=1; launch<=1;
                    m_axi_araddr<=cmd_src; m_axi_awaddr<=cmd_dst;
                    pixels_taken<=0; rd_lane<=0;
                end
            end
            if (launch && lb_start_ready) launch<=0;
            if (busy) begin
                if (rd_state==RD_IDLE && !failed && !launch && pixels_taken<PIXELS)
                    rd_state<=RD_ADDR;
                if (m_axi_arvalid && m_axi_arready) begin
                    rd_state<=RD_DATA; rd_receive<=0;
                end
                if (m_axi_rvalid && m_axi_rready) begin
                    rd_buffer[rd_receive]<=m_axi_rdata;
                    if (m_axi_rresp!=0 || m_axi_rlast!=(rd_receive==m_axi_arlen)) begin
                        failed<=1; error<=1;
                    end
                    if (rd_receive==m_axi_arlen || m_axi_rlast) begin
                        if (failed || m_axi_rresp!=0 || !m_axi_rlast)
                            rd_state<=RD_IDLE;
                        else begin
                            rd_word<=rd_receive==0 ? m_axi_rdata : rd_buffer[0];
                            rd_lane<=0; rd_index<=0; rd_state<=RD_HOLD;
                        end
                    end else rd_receive<=rd_receive+1;
                end
                if (rd_state==RD_HOLD) begin
                    if (failed) rd_state<=RD_IDLE;
                    else if (pixel_ready) begin
                        pixels_taken<=pixels_taken+1;
                        if (rd_lane==7 || pixels_taken==PIXELS-1) begin
                            if (rd_index==rd_receive || pixels_taken==PIXELS-1) begin
                                rd_state<=RD_IDLE; m_axi_araddr<=m_axi_araddr+256;
                            end else begin
                                rd_index<=rd_index+1; rd_lane<=0;
                                rd_word<=rd_buffer[rd_index+1];
                            end
                        end else rd_lane<=rd_lane+1;
                    end
                end
                if (packed_valid && packed_ready) begin
                    wr_buffer[wr_count]<=packed_data; wr_keep[wr_count]<=packed_keep;
                    wr_count<=wr_count+1;
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
                        wr_index<=wr_index+1;
                        m_axi_wdata<=wr_buffer[wr_index+1];
                        m_axi_wstrb<=wr_keep[wr_index+1];
                    end
                end
                if (m_axi_bvalid && m_axi_bready) begin
                    wr_active<=0; wr_count<=0; m_axi_awaddr<=m_axi_awaddr+256;
                    if (m_axi_bresp!=0) begin failed<=1; error<=1; end
                    else if (wr_final && !failed) begin busy<=0; done<=1; end
                end
                // Fault completion drains already-issued AXI transactions.
                // Missing responses require coordinated fabric reset, not retry.
                if (failed && rd_state==RD_IDLE && !wr_active) begin
                    busy<=0; done<=1; launch<=0;
                end
            end
        end
    end
endmodule
