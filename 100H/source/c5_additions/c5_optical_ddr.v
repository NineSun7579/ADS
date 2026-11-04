module c5_optical_ddr #(
    parameter DATA_WIDTH = 16,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_LEN_WIDTH  = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter CAM_DATA_LEN   = 172800, //1280*720*3/16
    parameter DEVICE = "PG"
)(
        output wire [31:0] lease_prev_base, lease_bank0, lease_bank1, lease_sequence,
    output wire [1:0] lease_published,
    output wire lease_writer_idle, lease_pending, lease_flush,
    input          axi_clk        ,
    input          axi_rst        , 
    input          dma_abort,
    output         dma_abort_req,
    output [15:0] axi_data_available,
    input          dma_done       ,  // [LEDGER 2026-09-19] DMA transaction-done pulse
    input wire c5_counter_reset,
    // [LANE_REC] per-frame lane record attached to the commit tag (axi_clk)
    input wire lane_wait, input wire lane_rec_valid, input wire [95:0] lane_rec,
    input [31:0] c5_epoch,c5_frame_sequence,
    output wire c5_commit,c5_bank,
    output wire [AXI_ADDR_WIDTH-1:0] c5_commit_base,
    output reg [31:0] c5_commit_epoch,c5_commit_sequence,
    input          axi_cam_en     ,      //����ͷ�����ź�

    input  [AXI_ADDR_WIDTH-1 : 0]      cam_data_addr_1,
    input  [AXI_ADDR_WIDTH-1 : 0]      cam_data_addr_2,
    input  [$clog2(CAM_DATA_LEN) : 0]  cam_data_len   , //��16�ֽ�Ϊ��λ

    input  [DATA_WIDTH-1 : 0]  s_data         /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_data_valid   /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_hsync        /*synthesis PAP_MARK_DEBUG="1"*/,
    input                      s_vsync        /*synthesis PAP_MARK_DEBUG="1"*/,

    output [AXI_DATA_WIDTH-1 : 0] axi_data       /*synthesis PAP_MARK_DEBUG="1"*/,
    output                        axi_data_valid /*synthesis PAP_MARK_DEBUG="1"*/,
    output                        axi_data_last  /*synthesis PAP_MARK_DEBUG="1"*/, 
    input                         axi_data_ready /*synthesis PAP_MARK_DEBUG="1"*/,

    output [AXI_ADDR_WIDTH-1 : 0]  axi_cmd_addr   /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_LEN_WIDTH-1 : 0]   axi_cmd_len    /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         axi_cmd_valid  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          axi_cmd_ready  /*synthesis PAP_MARK_DEBUG="1"*/,

    output [1 : 0]   xdma_req       ,
    output reg [31:0] dbg_fault_snapshot,
    output [31:0] dbg_reject_counts,
    output reg [31:0] dbg_input_pixels,
    output [31:0]    dbg_axi_cnt    ,
    output [31:0]    dbg_axi_num    ,
    output [31:0]    dbg_zdin       ,
    output [31:0]    dbg_zout       ,
    output [31:0]    dbg_state      ,
    output [31:0]    dbg_last_cnt   ,
    output [31:0]    dbg_wd_cnt     ,
    input  [1 : 0]   xdma_ack        ,
    output [AXI_ADDR_WIDTH-1:0] prev_frame_base  // [VKFS] previous frame's ping-pong bank
);

    wire [DATA_WIDTH-1 : 0]  m_data      /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                     m_data_valid/*synthesis PAP_MARK_DEBUG="1"*/;
    wire                     m_hsync     /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                     m_vsync     /*synthesis PAP_MARK_DEBUG="1"*/;

    // [FRTAG 2026-09-14] frame-tag plumbing: the packer stream is detoured through
    // w_* and the ctrl can substitute one counter beat during its DATA_TAG state.
    wire [AXI_DATA_WIDTH-1 : 0] w_data  ;
    wire [15:0] w_available;
    wire                        w_valid ;
    wire                        w_last  ;
    wire                        w_ready ;
    wire                        frame_active;
    wire                        tag_active;
    wire [AXI_DATA_WIDTH-1 : 0] tag_data  ;
    wire                    engine_busy;   // [IDLEGATE 2026-09-19]
    wire                    w_ping_o;
    wire ctrl_pending;


// Capture validity belongs to the admitted SOF, never to a DMA timeout.
// Flush only on DMA retirement (all external W/B obligations are finished).
reg [2:0] flush_count;
// Registered next-state nonzero flag: exact cycle parity with flush_count.
reg capture_flush;
reg capture_open, capture_bad;
// cam_data_len has clog2(CAM_DATA_LEN)+1 bits. Preserve its entire
// representable range, including nonphysical quotas, plus a terminal margin.
// RGB565/128-bit runtime instances need 21 bits (720P itself needs 20).
localparam MAX_PORT_BEATS = (64'd1 << ($clog2(CAM_DATA_LEN)+1)) - 1;
localparam COUNT_BITS_NEEDED = $clog2((MAX_PORT_BEATS * AXI_DATA_WIDTH) / DATA_WIDTH + 2);
localparam PIXEL_COUNT_WIDTH = (COUNT_BITS_NEEDED < 32) ? COUNT_BITS_NEEDED : 32;
reg [PIXEL_COUNT_WIDTH-1:0] pixel_count, pixel_limit;
// Preserve the diagnostic ABI: flags [31:28], zero-extended count [27:0].
wire [31:0] diagnostic_pixel_count = pixel_count;
reg [$clog2(CAM_DATA_LEN):0] admitted_beats;
always @(posedge axi_clk) begin
    if(axi_rst) admitted_beats <= 0;
    else if(m_vsync) admitted_beats <= cam_data_len;
end
always @(posedge axi_clk) begin
 if(axi_rst) begin c5_commit_epoch<=0;c5_commit_sequence<=0;end
 else if(m_vsync) begin c5_commit_epoch<=c5_epoch;c5_commit_sequence<=c5_frame_sequence;end
end
reg raw_vsync_q;
wire raw_sof = s_vsync && !raw_vsync_q;
wire capture_overflow;
reg pixel_count_equal;
wire [PIXEL_COUNT_WIDTH-1:0] pixel_count_next = pixel_count + 1'b1;
wire [PIXEL_COUNT_WIDTH-1:0] pixel_limit_next = (cam_data_len * AXI_DATA_WIDTH) / DATA_WIDTH;
wire capture_complete = capture_open && pixel_count_equal;
wire frame_good = capture_complete && !capture_bad && !capture_overflow;
wire capture_stop = capture_flush || capture_bad || capture_complete;
assign dma_abort_req = capture_bad;
// Idle capture metadata must not permanently block all future SOFs. Allow
// the admitted-SOF/controller pipeline to settle before treating it as stale.
// A busy engine or offered command always retains ownership of its AXI work.
reg [3:0] idle_stop_count;
wire idle_capture_stale = (idle_stop_count == 4'd8);
always @(posedge axi_clk) begin
    if(axi_rst || capture_flush || engine_busy || axi_cmd_valid ||
       m_vsync || !capture_open || !(capture_complete || capture_bad))
        idle_stop_count <= 0;
    else if(!idle_capture_stale) idle_stop_count <= idle_stop_count + 1'b1;
end
// Read-only evidence, retained across local flush. First source fault wins.
// Snapshot [31]=overflow, [30]=short, [29]=DMA abort without source fault,
// [28]=tag phase, [27:0]=accepted pixel count at that event.
reg [15:0] diag_overflows, diag_shorts;
reg [31:0] diag_input_count;
wire diag_short = raw_sof && !capture_complete;
wire diag_fault = capture_open && !capture_flush && !capture_bad &&
                  !m_vsync && (capture_overflow || diag_short);
assign dbg_reject_counts = {diag_overflows, diag_shorts};
always @(posedge axi_clk) begin
    if(axi_rst) begin
        dbg_fault_snapshot <= 0;
        diag_overflows <= 0;
        diag_shorts <= 0;
        diag_input_count <= 0;
        dbg_input_pixels <= 0;
    end else begin
        // Count every offered pixel, independently of admission/quota/flush.
        if(raw_sof) begin
            dbg_input_pixels <= diag_input_count;
            diag_input_count <= s_data_valid ? 1 : 0;
        end else if(s_data_valid) diag_input_count <= diag_input_count + 1'b1;
        if(diag_fault) begin
            dbg_fault_snapshot <= {capture_overflow, diag_short, 1'b0,
                                   !frame_active, diagnostic_pixel_count[27:0]};
            if(capture_overflow) diag_overflows <= diag_overflows + 1'b1;
            if(diag_short) diag_shorts <= diag_shorts + 1'b1;
        end else if(dma_abort && !capture_bad) begin
            dbg_fault_snapshot <= {2'b00, 1'b1, !frame_active, diagnostic_pixel_count[27:0]};
        end
    end
end
always @(posedge axi_clk) begin
    if(axi_rst) begin
        flush_count <= 4;
        capture_flush <= 1'b1;
        raw_vsync_q <= 0;
    end else begin
        raw_vsync_q <= s_vsync;
        if(dma_abort || (dma_done && (!frame_active || !frame_good)) || idle_capture_stale) begin
            flush_count <= 4;
            capture_flush <= 1'b1;
        end else if(capture_flush) begin
            flush_count <= flush_count - 1'b1;
            capture_flush <= (flush_count != 3'd1);
        end
    end
end
always @(posedge axi_clk) begin
    if(axi_rst || capture_flush) begin
        capture_open <= 0;
        capture_bad <= 0;
        pixel_count <= 0;
        pixel_limit <= 0;
        pixel_count_equal <= 1'b1;
    end else if(m_vsync) begin
        capture_open <= 1;
        capture_bad <= (cam_data_len == 0);
        pixel_count <= 0;
        pixel_limit <= pixel_limit_next;
        pixel_count_equal <= (pixel_limit_next == 0);
    end else if(capture_open) begin
        if(m_data_valid) begin
            pixel_count <= pixel_count_next;
            pixel_count_equal <= (pixel_count_next == pixel_limit);
        end
        if(capture_overflow || (raw_sof && !capture_complete)) capture_bad <= 1;
    end
end

ov5640_ddr_w_en #(
    .DATA_WIDTH(DATA_WIDTH)
)
ov5640_ddr_w_en(
    .capture_stop  (capture_stop),
    .engine_busy   (engine_busy | capture_flush),   // [IDLEGATE 2026-09-19] gate admission on write-engine idle
    .axi_clk       (axi_clk        ),
    .axi_rst       (axi_rst        ),

    .axi_cam_en    (axi_cam_en),
    .frame_pending (xdma_req),

    .s_data        (s_data         ),
    .s_data_valid  (s_data_valid   ),
    .s_hsync       (s_hsync        ),
    .s_vsync       (s_vsync        ),

    .m_data        (m_data         ),
    .m_data_valid  (m_data_valid   ),
    .m_hsync       (m_hsync        ),
    .m_vsync       (m_vsync        )
);



ov5640_ddr_w #(
    .DATA_WIDTH(DATA_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .CAM_DATA_LEN(CAM_DATA_LEN),
    .DEVICE(DEVICE)
) 
ov5640_ddr_w(
    .axi_clk        (axi_clk        ),
    .axi_rst        (axi_rst        ),

    .capture_flush (capture_flush),
    .capture_overflow(capture_overflow),
    .axi_data_available(w_available),
    .data_len       (cam_data_len   ), //��16�ֽ�Ϊ��λ

    .s_data         (m_data         ),
    .s_data_valid   (m_data_valid   ),
    .s_hsync        (m_hsync        ),
    .s_vsync        (m_vsync        ),

    .axi_data       (w_data         ),
    .axi_data_valid (w_valid        ),
    .axi_data_last  (w_last         ),
    .axi_data_ready (w_ready        ),
    .dbg_axi_cnt    (dbg_axi_cnt    ),
    .dbg_axi_num    (dbg_axi_num    ),
    .dbg_zdin       (dbg_zdin       ),
    .dbg_zout       (dbg_zout       )
);

    // Only DATA may consume camera FIFO words. DATA_TAG presents one tag
    // beat; WAIT_TAG_DONE presents no data and retains engine ownership.
    assign axi_data_available = tag_active ? 16'd1 : (frame_active ? w_available : 16'd0);
    assign axi_data       = tag_active ? tag_data : w_data;
    assign axi_data_valid = tag_active | (frame_active & w_valid);
    assign axi_data_last  = w_last;
    assign w_ready        = axi_data_ready & frame_active;




c5_optical_ddr_w_ctrl #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_LEN_WIDTH (AXI_LEN_WIDTH ),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .CAM_DATA_LEN  (CAM_DATA_LEN  )  //1280*720*3/16
)
c5_optical_ddr_w_ctrl(
    .c5_counter_reset(c5_counter_reset),
    .axi_clk        (axi_clk        ),
    .axi_rst        (axi_rst        ),

    .cam_data_addr_1(cam_data_addr_1),
    .cam_data_addr_2(cam_data_addr_2),
    .cam_data_len   (admitted_beats ),
    .c5_commit(c5_commit),.c5_bank(c5_bank),.c5_commit_base(c5_commit_base),
    
    .s_vsync        (m_vsync        ),

    .dma_abort      (dma_abort),
    .frame_good     (frame_good),
    .dma_done       (dma_done       ),  // [LEDGER 2026-09-19]

    .axi_cmd_addr   (axi_cmd_addr   ),
    .axi_cmd_len    (axi_cmd_len    ),
    .axi_cmd_valid  (axi_cmd_valid  ),
    .axi_cmd_ready  (axi_cmd_ready  ),

    .frame_active   (frame_active   ),
    .tag_active     (tag_active     ),
    .tag_data       (tag_data       ),
    .tag_ready      (axi_data_ready ),
    .lane_wait(lane_wait),.lane_rec_valid(lane_rec_valid),.lane_rec(lane_rec),

    .lease_pending(ctrl_pending),
    .engine_busy    (engine_busy    ),
    .w_ping_o       (w_ping_o       ),
    .dbg_state      (dbg_state      ),
    .dbg_last_cnt   (dbg_last_cnt   ),
    .dbg_wd_cnt     (dbg_wd_cnt     ),
    .xdma_req       (xdma_req       ),
    .xdma_ack       (xdma_ack       )
);


    
    // [VKFS 2026-09-25] prev frame base = the bank NOT currently being written
    assign prev_frame_base = w_ping_o ? cam_data_addr_1 : cam_data_addr_2;

assign lease_prev_base=prev_frame_base;
    assign lease_bank0=cam_data_addr_1;
    assign lease_bank1=cam_data_addr_2;
    assign lease_published=xdma_req;
    assign lease_sequence=dbg_last_cnt;
    assign lease_pending=ctrl_pending || m_vsync;
    assign lease_flush=capture_flush;
    assign lease_writer_idle=!engine_busy && !axi_cmd_valid && (!capture_open || capture_complete || capture_bad);
endmodule
