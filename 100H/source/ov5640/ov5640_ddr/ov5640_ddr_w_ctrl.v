//����CMD����
module ov5640_ddr_w_ctrl #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_LEN_WIDTH  = 32,
    parameter AXI_DATA_WIDTH = 128,
    parameter CAM_DATA_LEN   = 172800 //1280*720*3/16
)(
    input          axi_clk        ,
    input          axi_rst        ,

    input  [AXI_ADDR_WIDTH-1 : 0]      cam_data_addr_1,
    input  [AXI_ADDR_WIDTH-1 : 0]      cam_data_addr_2,
    input  [$clog2(CAM_DATA_LEN) : 0]  cam_data_len   , //��16�ֽ�Ϊ��λ
    
    input          s_vsync        ,

    input          dma_abort,
    input          frame_good,
    input          dma_done       ,  // [LEDGER 2026-09-19] DMA transaction-done pulse (authoritative beat ledger)

    output [AXI_ADDR_WIDTH-1 : 0]  axi_cmd_addr   /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_LEN_WIDTH-1 : 0]   axi_cmd_len    /*synthesis PAP_MARK_DEBUG="1"*/,
    output reg                     axi_cmd_valid  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          axi_cmd_ready  /*synthesis PAP_MARK_DEBUG="1"*/,

    output [1 : 0]   xdma_req       ,
    input  [1 : 0]   xdma_ack       ,

    // [FRTAG 2026-09-14] frame-tag injection. After each frame's last stream beat the
    // FSM issues a SECOND 16-byte AXI command writing a 32-bit frame counter to
    // frame_base + CAM_DATA_LEN*16. The wrapper (ov5640_ddr.v) muxes tag_data onto
    // the data stream while tag_active is high. The transaction must complete:
    // only its successful B response publishes the buffer and success counters.
    output                           frame_active   , // camera stream only during DATA
    output                           tag_active     , // one pending tag input beat
    output [AXI_DATA_WIDTH-1 : 0]    tag_data       ,
    input                            tag_ready,
    // [LANE_REC 2026-10-30] lane_wait: this channel produces one lane record
    // per frame (lane_rec_valid pulse, axi_clk). After the frame's last data
    // beat the writer waits for that record, bounded by LANE_WAIT_CYCLES, and
    // places it in tag[127:32]; tag[31:0] stays the frame counter.
    input                            lane_wait,
    input                            lane_rec_valid,
    input  [95:0]                    lane_rec,
    output [31:0]                    dbg_state,
    output wire lease_pending,
    output                           engine_busy,     // [IDLEGATE 2026-09-19] FSM not IDLE (frame or tag in flight)
    output [31:0]                    dbg_last_cnt,
    output [31:0]                    dbg_wd_cnt,
    output                           w_ping_o      // [VKFS] current write bank (0=buf1,1=buf2)
);

    localparam IDLE      = 3'b001;
    localparam ADDR      = 3'b010;
    localparam DATA      = 3'b100;
    // [FRTAG 2026-09-14] tag states: second (16B) command after the frame completes
    localparam ADDR_TAG  = 3'b011;
    localparam DATA_TAG  = 3'b101;
    localparam WAIT_TAG_DONE = 3'b110;
    localparam WAIT_LANE = 3'b111;
    localparam LANE_WAIT_CYCLES = 65535; // 0.5 ms at 131 MHz, << vertical blank

    reg [2 : 0] curr_state/*synthesis PAP_MARK_DEBUG="1"*/;
    // [LEDGER 2026-09-19] both the frame command and the 16B tag command pulse
    // dma_done; only the frame command's completion may advance frame state.
    wire frame_done = dma_done && frame_good && (curr_state == DATA);
    wire frame_failed = (dma_abort || (dma_done && !frame_good)) && (curr_state == DATA);
    wire publish = dma_done && (curr_state == WAIT_TAG_DONE);
    reg [2 : 0] next_state;
    // [LANE_REC] record of the frame currently being written (cleared at SOF)
    reg         lane_have;
    reg [95:0]  lane_word;
    reg [15:0]  lane_age;
    wire        lane_timeout = lane_age == LANE_WAIT_CYCLES;

    // [FRTAG 2026-09-14] frame-tag declarations (forward, before first use)
    reg                          vsync_pending;
    reg  [AXI_ADDR_WIDTH-1 : 0]  frame_base;
    reg  [AXI_LEN_WIDTH-1 : 0] frame_bytes;
    reg  [31 : 0]                frame_cnt;
    wire [AXI_ADDR_WIDTH-1 : 0]  tag_addr;
    wire                         tag_fire;

    reg [1 : 0] axi_vsync_ff/*synthesis PAP_MARK_DEBUG="1"*/;
    reg axi_vsync_rise/*synthesis PAP_MARK_DEBUG="1"*/;

    
    reg [AXI_ADDR_WIDTH-1 : 0] cmd_addr;
    reg [AXI_LEN_WIDTH-1 : 0] cmd_len;


    //״̬��
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            curr_state <= IDLE;
        end
        else begin
            curr_state <= next_state;
        end
    end

    always @(*) begin
        case (curr_state)
            IDLE: begin
                if(vsync_pending)begin
                    next_state = ADDR;
                end
                else begin
                    next_state = IDLE;
                end
            end
            ADDR: begin
                if(axi_cmd_ready & axi_cmd_valid)begin
                    next_state = DATA;
                end
                else begin
                    next_state = ADDR;
                end
            end
            DATA: begin
                if(frame_failed) next_state = IDLE;
                else if(frame_done)begin
                    // [FRTAG] frame complete, go write the tag (after its lane record)
                    next_state = (lane_wait && !lane_have) ? WAIT_LANE : ADDR_TAG;
                end
                else begin
                    next_state = DATA;
                end
            end
            ADDR_TAG: begin
                if(axi_cmd_ready & axi_cmd_valid)begin
                    next_state = DATA_TAG;
                end
                else begin
                    next_state = ADDR_TAG;
                end
            end
            DATA_TAG: begin
                if(dma_abort) next_state = IDLE;
                else if(tag_fire)begin
                    next_state = WAIT_TAG_DONE;
                end
                else begin
                    next_state = DATA_TAG;
                end
            end
            WAIT_LANE: begin
                if(lane_have || lane_timeout) next_state = ADDR_TAG;
                else                          next_state = WAIT_LANE;
            end
            WAIT_TAG_DONE: begin
                if(dma_done || dma_abort) next_state = IDLE;
                else         next_state = WAIT_TAG_DONE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    

    always @(posedge axi_clk) begin
        if(axi_rst)begin
            axi_vsync_ff <= 2'b0;
        end
        else begin
            axi_vsync_ff <= {axi_vsync_ff[0], s_vsync};
        end
    end

    always @(posedge axi_clk) begin
        if(axi_rst)begin
            axi_vsync_rise <= 1'b0;
        end
        else begin
            axi_vsync_rise <= axi_vsync_ff[0] & (~axi_vsync_ff[1]);
        end
    end

    reg w_ping;
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            w_ping <= 1'b0;
        end
        else begin
            if(publish)begin
                w_ping <= ~w_ping;
            end
        end
    end


    // Only latch admitted SOF while idle. Busy-frame markers are discarded;
    // replaying one after retirement would restart in the middle of a frame.
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            vsync_pending <= 1'b0;
        end
        else if(axi_vsync_rise && (curr_state == IDLE))begin
            vsync_pending <= 1'b1;
        end
        else if((curr_state == IDLE) && vsync_pending)begin
            vsync_pending <= 1'b0;
        end
    end

    always @(posedge axi_clk) begin
        if(axi_rst)begin
            axi_cmd_valid <= 1'b0;
        end
        else begin
            if((curr_state == IDLE) && vsync_pending)begin
                axi_cmd_valid <= 1'b1;
            end
            else if(frame_done && !(lane_wait && !lane_have))begin
                axi_cmd_valid <= 1'b1;      // [FRTAG] frame done -> present the tag command
            end
            else if((curr_state == WAIT_LANE) && (lane_have || lane_timeout))begin
                axi_cmd_valid <= 1'b1;      // [LANE_REC] record arrived (or timed out)
            end
            else if(axi_cmd_valid & axi_cmd_ready)begin
                axi_cmd_valid <= 1'b0;
            end
        end
    end


    // Latch each command when presented; hold payload through backpressure.
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            cmd_addr <= {AXI_ADDR_WIDTH{1'b0}};
            cmd_len  <= {AXI_LEN_WIDTH{1'b0}};
        end
        else if((curr_state == IDLE) && vsync_pending)begin
            cmd_addr <= w_ping ? cam_data_addr_2 : cam_data_addr_1;
            cmd_len  <= {cam_data_len, 4'b0};
        end
        // The frame command was accepted before DATA. Prepare its tag payload
        // while command-valid is low; only successful retirement raises valid.
        // This avoids a late frame_good/overflow predicate on the address CE.
        else if(curr_state == DATA)begin
            cmd_addr <= tag_addr;
            cmd_len  <= 16;
        end
    end

    assign axi_cmd_addr = cmd_addr;
    assign axi_cmd_len  = cmd_len;

    // [FRTAG 2026-09-14] frame counter + tag beat generation --------------------
    // frame_base is latched when the FRAME command is accepted (cmd_addr still
    // points at the buffer being written at that moment; w_ping flips later).
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            frame_base <= {AXI_ADDR_WIDTH{1'b0}};
            frame_bytes <= 0;
        end
        else if((curr_state == ADDR) && axi_cmd_valid && axi_cmd_ready)begin
            frame_base <= cmd_addr;
            frame_bytes <= cmd_len;
        end
    end

    assign tag_addr = frame_base + frame_bytes;

    always @(posedge axi_clk) begin
        if(axi_rst)begin
            frame_cnt <= 32'd0;
        end
        else if(publish)begin
            frame_cnt <= frame_cnt + 32'd1;
        end
    end

    assign frame_active = (curr_state == DATA);
    assign tag_active  = (curr_state == DATA_TAG);
    assign tag_data    = {{(AXI_DATA_WIDTH-128){1'b0}}, (lane_have ? lane_word : 96'd0), (frame_cnt + 32'd1)};
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            lane_have <= 1'b0; lane_word <= 96'd0; lane_age <= 16'd0;
        end
        else begin
            // A new frame command opens a new record window.
            if((curr_state == ADDR) && axi_cmd_valid && axi_cmd_ready)begin
                lane_have <= 1'b0; lane_word <= 96'd0;
            end
            else if(lane_rec_valid && (curr_state == DATA || curr_state == WAIT_LANE))begin
                lane_have <= 1'b1; lane_word <= lane_rec;
            end
            if(curr_state != WAIT_LANE) lane_age <= 16'd0;
            else if(!lane_timeout)      lane_age <= lane_age + 16'd1;
        end
    end
    assign tag_fire    = tag_active & tag_ready;
    // ---------------------------------------------------------------------------


    //XDMAƹ������
    reg [1 : 0] s_xdma_req;
    always @(posedge axi_clk) begin
        if(axi_rst)begin
            s_xdma_req <= 2'b0;
        end
        else begin
            if(publish)begin
                if(w_ping)begin
                    s_xdma_req[1] <= 1'b1;
                end
                else begin
                    s_xdma_req[0] <= 1'b1;
                end
            end
            else begin
                if(xdma_ack[0] || ((curr_state == IDLE) && vsync_pending && !w_ping)) begin
                    s_xdma_req[0] <= 1'b0;
                end
                if(xdma_ack[1] || ((curr_state == IDLE) && vsync_pending && w_ping)) begin
                    s_xdma_req[1] <= 1'b0;
                end
            end
        end
    end

    assign xdma_req = s_xdma_req;
    assign dbg_state = {29'd0, curr_state};
    assign engine_busy = (curr_state != IDLE);
    assign lease_pending = vsync_pending || axi_vsync_rise || (|axi_vsync_ff);

    // Diagnostic state-age counter only. A timeout cannot cancel a command
    // or release ownership of an outstanding DMA AW/W/B transaction.
    reg [31:0] wd_cnt;
    reg [2:0] wd_prev_state;
    always @(posedge axi_clk) begin
        if(axi_rst) wd_prev_state <= IDLE;
        else        wd_prev_state <= curr_state;
    end
    always @(posedge axi_clk) begin
        if(axi_rst || (curr_state == IDLE) || (curr_state != wd_prev_state)) wd_cnt <= 32'd0;
        else if(wd_cnt != 32'hffffffff)     wd_cnt <= wd_cnt + 32'd1;
    end
    assign dbg_wd_cnt = wd_cnt;

    reg [31:0] last_cnt;
    always @(posedge axi_clk) begin
        if(axi_rst) last_cnt <= 32'd0;
        else if(publish) last_cnt <= last_cnt + 32'd1;
    end
    assign dbg_last_cnt = last_cnt;




    // [VKFS 2026-09-25] other ping-pong bank = where the previous frame lives
    assign w_ping_o = w_ping;

endmodule
