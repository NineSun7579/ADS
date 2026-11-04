// frame_state.v -- previous-frame pixel state in DDR3, 100H vip_kf_stream style.
//
// Alignment contract (100H KF report): STRUCTURAL, never calibrated. The
// consumer's column counter selects the beat word and the 16-bit lane
//   prev = lbuf[line&1][col[11:4]][{col[3:0],4'b0} +: 16]
// exactly like vip_kf_stream's lb_ra / rd_lane. The line buffers are BRAM
// with a registered read (LAT=1, as in the 100H design); the consumer must
// pair the returned pixel with the input beat delayed one cycle.
//
// Request path: (16-bit generation, page, line) tuples through an async FIFO.
// Buffer for line k is k&1. Completion ownership travels through a second
// async FIFO; BOTH generation and full line must match before using history.
// A parity/generation-only tag accepts stale lines when DDR prefetch is late.
//
// Storage units (vendor chunker: commands are 16-beat multiples, address
// unit = 32-bit DQ words, line step = beats*8):
//   H=1280 -> 80 beats/line = 5 segments of 16 beats, line step 640,
//   page step 640*480 = 307200. Writes collect a 16-beat segment in flops
//   (no distributed RAM) and issue one command per segment.
//
// Pages: write frame w stores page w&1 (structural count of V lines); the
// region starting at the Nth vsync reads page (N-2)&1 = prev_page latched
// from the pre-increment frame counter at that vsync.
//
// Latency: rd_data/rd_valid for an input beat appear one cycle after it;
// temporal_filter2 delays its input stream by one cycle to pair them.
module frame_state #(
    parameter H_NUM = 1280,
    parameter V_NUM = 480,
    parameter PIX_WIDTH = 16,
    parameter CTRL_ADDR_WIDTH = 28,
    parameter MEM_DQ_WIDTH = 32
)(
    input                     clk,
    input                     rstn,
    input  [PIX_WIDTH-1:0]    wr_data,
    input                     wr_de,
    input                     wr_vs,
    output [PIX_WIDTH-1:0]    rd_data,
    output                    rd_valid,
    input                     rd_de,
    input                     rd_vs,
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
    localparam BEAT_BITS   = MEM_DQ_WIDTH*8;
    localparam PX_PER_BEAT = BEAT_BITS/PIX_WIDTH;
    localparam LANE_BITS   = $clog2(PX_PER_BEAT);
    localparam LINE_BEATS  = H_NUM/PX_PER_BEAT;
    localparam SEG_BEATS   = 16;
    localparam SEGS_PER_LINE = LINE_BEATS/SEG_BEATS;
    localparam SEG_WORDS   = SEG_BEATS*(BEAT_BITS/32);   // 128
    localparam LINE_STEP   = LINE_BEATS*(BEAT_BITS/32);
    localparam PAGE_STEP   = LINE_STEP*V_NUM;

    // ---------------- vendor command path ----------------
    wire                       wr_cmd_ready, wr_cmd_done, wr_data_re, wr_bac;
    wire                       rd_cmd_ready, rd_cmd_done, read_en;
    wire [BEAT_BITS-1:0]       read_rdata;
    reg                        wr_cmd_en, rd_cmd_en;
    reg [CTRL_ADDR_WIDTH-1:0]  wr_cmd_addr, rd_cmd_addr;
    reg [31:0]                 wr_cmd_len, rd_cmd_len;
    reg [BEAT_BITS-1:0]        wr_ctrl_data;

    wr_rd_ctrl_top #(
        .CTRL_ADDR_WIDTH(CTRL_ADDR_WIDTH), .MEM_DQ_WIDTH(MEM_DQ_WIDTH)
    ) u_cmd (
        .clk(ddr_clk), .rstn(ddr_rstn),
        .wr_cmd_en(wr_cmd_en), .wr_cmd_addr(wr_cmd_addr), .wr_cmd_len(wr_cmd_len),
        .wr_cmd_ready(wr_cmd_ready), .wr_cmd_done(wr_cmd_done),
        .wr_bac(wr_bac), .wr_ctrl_data(wr_ctrl_data), .wr_data_re(wr_data_re),
        .rd_cmd_en(rd_cmd_en), .rd_cmd_addr(rd_cmd_addr), .rd_cmd_len(rd_cmd_len),
        .rd_cmd_ready(rd_cmd_ready), .rd_cmd_done(rd_cmd_done),
        .read_ready(1'b1), .read_rdata(read_rdata), .read_en(read_en),
        .axi_awaddr(axi_awaddr), .axi_awid(axi_awid), .axi_awlen(axi_awlen),
        .axi_awsize(axi_awsize), .axi_awburst(axi_awburst),
        .axi_awready(axi_awready), .axi_awvalid(axi_awvalid),
        .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb), .axi_wlast(axi_wlast),
        .axi_wvalid(axi_wvalid), .axi_wready(axi_wready),
        .axi_bid(4'd0), .axi_bresp(2'd0), .axi_bvalid(1'b0), .axi_bready(),
        .axi_araddr(axi_araddr), .axi_arid(axi_arid), .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize), .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready),
        .axi_rready(axi_rready), .axi_rdata(axi_rdata), .axi_rvalid(axi_rvalid),
        .axi_rlast(axi_rlast), .axi_rid(axi_rid), .axi_rresp(2'd0)
    );

    // ---------------- stream-domain bookkeeping ----------------
    reg [15:0] frame_cnt;
    reg       vs_d;
    wire      vs_edge = rd_vs && !vs_d;
    reg [11:0] col;

    // read line buffers: BRAM-style dual-clock arrays with registered reads
    reg [BEAT_BITS-1:0] lbuf0 [0:LINE_BEATS-1];
    reg [BEAT_BITS-1:0] lbuf1 [0:LINE_BEATS-1];

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin frame_cnt <= 16'd0; vs_d <= 1'b0; end
        else begin vs_d <= rd_vs; if (vs_edge) frame_cnt <= frame_cnt + 16'd1; end
    end
    wire cur_page  = frame_cnt[0];
    wire prev_page = ~cur_page;
    reg  region_page;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) region_page <= 1'b0;
        else if (vs_edge) region_page <= prev_page;
    end

    // ---------------- write path: pixel FIFO -> 16-beat segment -> command ----------------
    // cam2_merge starts with active video BEFORE its first VS. Do not count
    // that unframed startup image as page zero: read generations start at VS.
    // Ignoring it also makes startup partway through a source frame safe.
    reg wr_vs_d, write_armed;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin wr_vs_d <= 1'b0; write_armed <= 1'b0; end
        else begin
            wr_vs_d <= wr_vs;
            if (wr_vs && !wr_vs_d) write_armed <= 1'b1;
        end
    end
    wire [PIX_WIDTH-1:0] wfifo_dout;
    wire wfifo_empty, wfifo_pop, wfifo_full;
    reg storage_fault;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) storage_fault <= 1'b0;
        else if (wr_de && write_armed && wfifo_full) storage_fault <= 1'b1;
    end
    video_async_fifo #(.WIDTH(PIX_WIDTH), .DEPTH(1024)) u_wr_fifo (
        .wr_clk(clk), .wr_rst_n(rstn),
        .wr_en(wr_de && write_armed), .wr_data(wr_data), .full(wfifo_full),
        .rd_clk(ddr_clk), .rd_rst_n(ddr_rstn),
        .rd_en(wfifo_pop), .rd_data(wfifo_dout), .empty(wfifo_empty)
    );

    reg [BEAT_BITS-1:0] seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7;
    reg [BEAT_BITS-1:0] seg8, seg9, seg10, seg11, seg12, seg13, seg14, seg15;
    reg [BEAT_BITS-1:0] beat_acc;
    reg [BEAT_BITS-1:0] seg_wr_data;
    reg [3:0]  seg_wr_idx;
    reg        seg_wr_en;
    reg [3:0]  pack_cnt;
    reg [3:0]  seg_wp, seg_rp;
    reg [11:0] wpx;                              // pixels in current line
    reg [11:0] wline_idx;
    reg [3:0]  wseg;
    reg [1:0]  wstate;
    reg        w_page;
    localparam WS_COLLECT=2'd0, WS_CMD=2'd1, WS_STREAM=2'd2, WS_WAIT=2'd3;

    wire seg_ready = (seg_wp != seg_rp);
    assign wfifo_pop = (wstate == WS_COLLECT) && !wfifo_empty;

    // current segment beat, combinational mux over plain registers
    reg [BEAT_BITS-1:0] seg_q;
    always @(*) begin
        case (seg_rp)
            4'd0: seg_q = seg0;  4'd1: seg_q = seg1;
            4'd2: seg_q = seg2;  4'd3: seg_q = seg3;
            4'd4: seg_q = seg4;  4'd5: seg_q = seg5;
            4'd6: seg_q = seg6;  4'd7: seg_q = seg7;
            4'd8: seg_q = seg8;  4'd9: seg_q = seg9;
            4'd10: seg_q = seg10; 4'd11: seg_q = seg11;
            4'd12: seg_q = seg12; 4'd13: seg_q = seg13;
            4'd14: seg_q = seg14; default: seg_q = seg15;
        endcase
    end
    always @(*) wr_ctrl_data = seg_q;

    // explicit register writes: endpoints are plain FFs (the hold fixer can
    // insert delay; a RAM write port cannot)
    always @(posedge ddr_clk) begin
        if (seg_wr_en) begin
            case (seg_wr_idx)
                4'd0: seg0 <= seg_wr_data;  4'd1: seg1 <= seg_wr_data;
                4'd2: seg2 <= seg_wr_data;  4'd3: seg3 <= seg_wr_data;
                4'd4: seg4 <= seg_wr_data;  4'd5: seg5 <= seg_wr_data;
                4'd6: seg6 <= seg_wr_data;  4'd7: seg7 <= seg_wr_data;
                4'd8: seg8 <= seg_wr_data;  4'd9: seg9 <= seg_wr_data;
                4'd10: seg10 <= seg_wr_data; 4'd11: seg11 <= seg_wr_data;
                4'd12: seg12 <= seg_wr_data; 4'd13: seg13 <= seg_wr_data;
                4'd14: seg14 <= seg_wr_data; default: seg15 <= seg_wr_data;
            endcase
        end
    end

    always @(posedge ddr_clk or negedge ddr_rstn) begin
        if (!ddr_rstn) begin
            wstate <= WS_COLLECT; wpx <= 12'd0; wline_idx <= 12'd0;
            wseg <= 4'd0; w_page <= 1'b0; pack_cnt <= 4'd0; seg_wp <= 4'd0; seg_rp <= 4'd0;
            beat_acc <= 0; seg_wr_en <= 1'b0; seg_wr_idx <= 0; seg_wr_data <= 0;
            wr_cmd_en <= 1'b0; wr_cmd_addr <= 0; wr_cmd_len <= 0;
        end
        else begin
            wr_cmd_en <= 1'b0;
            seg_wr_en <= 1'b0;
            case (wstate)
                WS_COLLECT: begin
                    if (wfifo_pop) begin
                        beat_acc[pack_cnt*PIX_WIDTH +: PIX_WIDTH] <= wfifo_dout;
                        if (pack_cnt == PX_PER_BEAT-1) begin
                            seg_wr_data <= {wfifo_dout, beat_acc[BEAT_BITS-PIX_WIDTH-1:0]};
                            seg_wr_idx  <= seg_wp;
                            seg_wr_en   <= 1'b1;
                            seg_wp <= seg_wp + 4'd1;
                            pack_cnt <= 4'd0;
                            if (wpx == H_NUM-1) begin
                                wpx <= 12'd0;
                                wstate <= WS_CMD;
                            end
                            else begin
                                wpx <= wpx + 12'd1;
                                if (seg_wp == SEG_BEATS-1) wstate <= WS_CMD;
                            end
                        end
                        else begin
                            pack_cnt <= pack_cnt + 4'd1;
                            wpx <= wpx + 12'd1;
                        end
                    end
                end
                WS_CMD: begin
                    if (wr_cmd_ready) begin
                        wr_cmd_en   <= 1'b1;
                        wr_cmd_addr <= (w_page ? PAGE_STEP : 0) + wline_idx*LINE_STEP + wseg*SEG_WORDS;
                        wr_cmd_len  <= SEG_BEATS;
                        seg_rp <= 4'd0;
                        wstate <= WS_STREAM;
                    end
                end
                WS_STREAM: begin
                    if (wr_data_re) begin
                        if (seg_rp == SEG_BEATS-1) begin
                            seg_rp <= 4'd0;
                            seg_wp <= 4'd0;
                            wseg <= wseg + 4'd1;
                            if (wseg == SEGS_PER_LINE-1) begin
                                wseg <= 4'd0;
                                if (wline_idx == V_NUM-1) begin
                                    wline_idx <= 12'd0;
                                    w_page <= ~w_page;
                                end
                                else wline_idx <= wline_idx + 12'd1;
                                wstate <= WS_WAIT;
                            end
                            else wstate <= WS_WAIT;
                        end
                        else seg_rp <= seg_rp + 4'd1;
                    end
                end
                WS_WAIT: begin
                    if (wr_cmd_done) wstate <= WS_COLLECT;
                end
            endcase
        end
    end

    // ---------------- read request path (stream -> ddr) ----------------
    reg [11:0] req_line;
    reg        rq_push;
    reg [28:0] rq_payload;
    wire       rq_full;
    wire [28:0] rq_dout;
    wire        rq_empty, rq_pop;
    video_async_fifo #(.WIDTH(29), .DEPTH(8)) u_rq_fifo (
        .wr_clk(clk), .wr_rst_n(rstn),
        .wr_en(rq_push), .wr_data(rq_payload), .full(rq_full),
        .rd_clk(ddr_clk), .rd_rst_n(ddr_rstn),
        .rd_en(rq_pop), .rd_data(rq_dout), .empty(rq_empty)
    );

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            req_line <= 12'd0; rq_push <= 1'b0; rq_payload <= 29'd0;
        end
        else begin
            rq_push <= 1'b0;
            if (vs_edge) begin
                rq_payload <= {frame_cnt + 16'd1, prev_page, 12'd0};
                rq_push <= 1'b1;
                req_line <= 12'd1;
            end
            else if (rd_de && col == 12'd0 && req_line != 12'd0 && req_line < V_NUM) begin
                rq_payload <= {frame_cnt, region_page, req_line};
                rq_push <= 1'b1;
                req_line <= req_line + 12'd1;
            end
        end
    end

    // ---------------- read engine (ddr domain) ----------------
    reg [1:0] rstate;
    reg [7:0] rbeat;
    reg [11:0] r_line;
    reg        r_page;
    reg [15:0] r_gen;
    localparam RS_CMD=2'd0, RS_RECV=2'd1;
    assign rq_pop = (rstate == RS_CMD) && !rq_empty && rd_cmd_ready;

    always @(posedge ddr_clk or negedge ddr_rstn) begin
        if (!ddr_rstn) begin
            rstate <= RS_CMD; rbeat <= 8'd0; r_line <= 12'd0;
            r_page <= 1'b0; r_gen <= 16'd0;
            rd_cmd_en <= 1'b0; rd_cmd_addr <= 0; rd_cmd_len <= 0;
        end
        else begin
            rd_cmd_en <= 1'b0;
            case (rstate)
                RS_CMD: begin
                    if (rq_pop) begin
                        r_line <= rq_dout[11:0];
                        r_page <= rq_dout[12];
                        r_gen  <= rq_dout[28:13];
                        rd_cmd_en   <= 1'b1;
                        rd_cmd_addr <= (rq_dout[12] ? PAGE_STEP : 0) + rq_dout[11:0]*LINE_STEP;
                        rd_cmd_len  <= LINE_BEATS;
                        rbeat <= 8'd0;
                        rstate <= RS_RECV;
                    end
                end
                RS_RECV: begin
                    if (read_en) begin
                        if (r_line[0]) lbuf1[rbeat] <= read_rdata;
                        else           lbuf0[rbeat] <= read_rdata;
                        if (rbeat == LINE_BEATS-1) begin
                            rstate <= RS_CMD;
                        end
                        else rbeat <= rbeat + 8'd1;
                    end
                end
            endcase
        end
    end

    // Publish ownership only after the final BRAM write. The FIFO transfers a
    // coherent multi-bit token instead of sampling asynchronous tag bits.
    wire completion_push = (rstate == RS_RECV) && read_en && (rbeat == LINE_BEATS-1);
    wire [27:0] completion_data;
    wire completion_empty;
    video_async_fifo #(.WIDTH(28), .DEPTH(8)) u_completion_fifo (
        .wr_clk(ddr_clk), .wr_rst_n(ddr_rstn),
        .wr_en(completion_push), .wr_data({r_gen, r_line}), .full(),
        .rd_clk(clk), .rd_rst_n(rstn),
        .rd_en(!completion_empty), .rd_data(completion_data), .empty(completion_empty)
    );
    reg [27:0] tag0, tag1;
    reg tag0_valid, tag1_valid;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tag0 <= 0; tag1 <= 0; tag0_valid <= 0; tag1_valid <= 0;
        end
        else if (!completion_empty) begin
            if (completion_data[0]) begin tag1 <= completion_data; tag1_valid <= 1'b1; end
            else begin tag0 <= completion_data; tag0_valid <= 1'b1; end
        end
    end

    // ---------------- consumer: column indexing + LAT=1 registered read ----------------
    wire [11:0] beat_idx = col >> LANE_BITS;
    reg [BEAT_BITS-1:0] rd_beat;
    reg                 rd_beat_valid;
    reg [LANE_BITS-1:0] lane_d;
    reg [11:0] cons_line;

    // BRAM-style registered read (one cycle, 100H LAT=1 contract)
    always @(posedge clk) begin
        if (cons_line[0]) rd_beat <= lbuf1[beat_idx];
        else              rd_beat <= lbuf0[beat_idx];
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            col <= 12'd0; cons_line <= 12'd0; rd_beat_valid <= 1'b0; lane_d <= 0;
        end
        else begin
            if (vs_edge) begin
                col <= 12'd0; cons_line <= 12'd0; rd_beat_valid <= 1'b0;
            end
            else if (rd_de) begin
                lane_d <= col[LANE_BITS-1:0];
                rd_beat_valid <= cons_line[0] ? (tag1_valid && (tag1 == {frame_cnt, cons_line}))
                                               : (tag0_valid && (tag0 == {frame_cnt, cons_line}));
                if (col == H_NUM-1) begin
                    col <= 12'd0;
                    cons_line <= cons_line + 12'd1;
                end
                else col <= col + 12'd1;
            end
        end
    end

    // Combinational extraction from the already-registered beat/lane: valid
    // for beat k during the cycle after its sample edge, pairing exactly with
    // the consumer's one-cycle-delayed z(k) (100H LAT=1 contract).
    assign rd_data  = rd_beat[lane_d*PIX_WIDTH +: PIX_WIDTH];
    // An overflow loses coordinates in the pixel-only write FIFO. Never mix
    // its subsequently misindexed state into video; bypass until shared reset.
    assign rd_valid = rd_beat_valid && !storage_fault;

endmodule
