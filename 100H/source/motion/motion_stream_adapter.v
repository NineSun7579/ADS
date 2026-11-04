// Passive AXI-clock tap. Markers never consume pixels in the detector.
// Camera blanking must provide five idle clocks/frame for marker insertion.
// A 16-event FIFO absorbs coincident VSYNC/pixel0 and continuous image bursts.
// frame_sequence counts source starts (including aborted frames), not DDR tags.
// Short frames produce no record; their error is carried to the next record.
// One trailing dummy is tolerated; further tail beats invalidate the reference
// and set frame_error on the next completed record. All tails bypass history.
// FIFO overflow flushes events, resets detector control (not RAM), suppresses
// pending publication, and waits for a fresh VSYNC. Error survives until completion.
// FIFO issue -> core acceptance adds one clock for the complete event tuple.
// Core updates at sample+2, publishes at end+2; this wrapper captures at end+3.
module motion_stream_adapter #(
    parameter integer WIDTH = 640, HEIGHT = 480,
    parameter SAMPLE_STEP = 4,
    parameter BLOCK_SAMPLES_X = 10, BLOCK_SAMPLES_Y = 10,
    parameter PIXEL_THRESHOLD = 16, BLOCK_THRESHOLD = 8
) (
    input wire clk, rst_n,
    input wire [15:0] pixel_rgb565,
    input wire pixel_valid, vsync,
    output reg [319:0] motion_record
);
    localparam integer TOTAL = WIDTH * HEIGHT;
    localparam SC = (WIDTH + SAMPLE_STEP - 1) / SAMPLE_STEP;
    localparam SR = (HEIGHT + SAMPLE_STEP - 1) / SAMPLE_STEP;
    localparam BC = (SC + BLOCK_SAMPLES_X - 1) / BLOCK_SAMPLES_X;
    localparam BR = (SR + BLOCK_SAMPLES_Y - 1) / BLOCK_SAMPLES_Y;
    reg vs_q, acquired;
    wire rise = vsync && !vs_q;
    reg [17:0] events [0:15]; // {start, valid, pixel}
    reg [31:0] event_sequences [0:15];
    reg [3:0] wr_ptr, rd_ptr;
    reg [4:0] queued;
    reg head_started, active, end_pending, tail_seen, tail_bad;
    // If the last pixel issues at T: core pixel T+1, core end T+2,
    // result T+4, record capture T+5, earliest next core start T+6.
    // Four drain clocks keep publication metadata stable through capture.
    // Only boundaries stall: consecutive image pixels remain one per clock.
    // Fixed four-cycle drain: low bit is the direct busy register.
    reg [3:0] marker_drain;
    wire boundary_busy = marker_drain[0];
    reg [$clog2(TOTAL+1)-1:0] pixels;
    reg [31:0] source_sequence, active_sequence, publish_sequence;
    reg overflow_reset;
    reg [31:0] overflow_count;
    reg error_pending, publish_error;
    // Diagnostic only: never used as a DDR frame tag.
    reg [31:0] short_frame_count;
    wire push = (acquired || rise) && (rise || pixel_valid);
    wire have = queued != 0;
    wire [17:0] head = events[rd_ptr];
    wire start = have && head[17] && !head_started && !boundary_busy;
    wire excess = have && !start && !boundary_busy && head[16] &&
                  !active && tail_seen && !tail_bad;
    wire pop = have && !boundary_busy && (!start || !head[16]);
    wire overflow = push && queued == 16 && !pop;
    wire fire = have && !start && !boundary_busy && head[16] && active &&
                !overflow && !overflow_reset;
    // Keep the complete event together across the register boundary. FIFO
    // accounting occurs when issued; the core consumes it one edge later.
    reg core_start, core_end, core_valid;
    reg [15:0] core_rgb;
    wire strobe, comparison_valid, bbox_valid;
    wire [BC*BR-1:0] bitmap;
    wire [$clog2(BC*BR+1)-1:0] blocks;
    wire [$clog2(SC*SR+1)-1:0] samples;
    wire [((BC > 1) ? $clog2(BC) : 1)-1:0] minx, maxx;
    wire [((BR > 1) ? $clog2(BR) : 1)-1:0] miny, maxy;
    wire [191:0] bitmap_word = bitmap;
    wire [15:0] sample_word = samples;
    wire [7:0] block_word = blocks;
    wire [3:0] minx_word = minx, maxx_word = maxx;
    wire [3:0] miny_word = miny, maxy_word = maxy;
    // Detector reset from one register: equals rst_n && !overflow_reset except
    // that it releases one clock after rst_n (no event reaches the core in
    // that clock). The previous LUT of two registers drove the detector's
    // whole async reset tree and failed recovery.
    (* syn_maxfan = 64 *) reg det_rst_n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) det_rst_n <= 1'b0;
        else det_rst_n <= !overflow;
    end
    block_motion_detector #(
        .WIDTH(WIDTH), .HEIGHT(HEIGHT), .SAMPLE_STEP(SAMPLE_STEP),
        .BLOCK_SAMPLES_X(BLOCK_SAMPLES_X), .BLOCK_SAMPLES_Y(BLOCK_SAMPLES_Y),
        .PIXEL_THRESHOLD(PIXEL_THRESHOLD), .BLOCK_THRESHOLD(BLOCK_THRESHOLD)
    ) u_detector (
        .clk(clk), .rst_n(det_rst_n), .frame_start(core_start),
        .frame_end(core_end), .pixel_valid(core_valid), .pixel_rgb565(core_rgb),
        .result_strobe(strobe), .result_valid(comparison_valid),
        .block_bitmap(bitmap), .changed_blocks(blocks), .changed_samples(samples),
        .bbox_valid(bbox_valid), .bbox_min_x(minx), .bbox_max_x(maxx),
        .bbox_min_y(miny), .bbox_max_y(maxy), .frame_sequence()
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vs_q <= 0; acquired <= 0; wr_ptr <= 0; rd_ptr <= 0; queued <= 0;
            head_started <= 0; active <= 0; end_pending <= 0;
            marker_drain <= 0;
            core_start <= 0; core_end <= 0; core_valid <= 0; core_rgb <= 0;
            tail_seen <= 0; tail_bad <= 0; pixels <= 0;
            source_sequence <= 0; active_sequence <= 0; publish_sequence <= 0;
            overflow_reset <= 0; overflow_count <= 0;
            error_pending <= 0; publish_error <= 0; short_frame_count <= 0;
            motion_record <= 0;
        end else begin
            vs_q <= vsync;
            // Count at the source edge, even if queued starts are later dropped.
            if (rise) source_sequence <= source_sequence + 1'b1;
            overflow_reset <= overflow;
            if (overflow || overflow_reset) begin
                // Flush the tuple and suppress capture on the overflow edge.
                // overflow_reset resets core control locally for one clock;
                // RAM contents remain untouched and the reference is invalid.
                acquired <= 0; wr_ptr <= 0; rd_ptr <= 0; queued <= 0;
                head_started <= 0; active <= 0; end_pending <= 0;
                marker_drain <= 0;
                core_start <= 0; core_end <= 0; core_valid <= 0; core_rgb <= 0;
                pixels <= 0; tail_seen <= 0; tail_bad <= 0;
                error_pending <= 1;
                if (overflow) overflow_count <= overflow_count + 1'b1;
            end else begin
            core_start <= start || excess;
            core_end <= end_pending;
            core_valid <= fire;
            core_rgb <= head[15:0];
            if (boundary_busy) marker_drain <= {1'b0, marker_drain[3:1]};
            if (rise) acquired <= 1;
            if (push) begin
                events[wr_ptr] <= {rise, pixel_valid, pixel_rgb565};
                event_sequences[wr_ptr] <= rise ? source_sequence + 1'b1 : source_sequence;
                wr_ptr <= wr_ptr + 1'b1;
            end
            case ({push,pop})
                2'b10: queued <= queued + 1'b1;
                2'b01: queued <= queued - 1'b1;
                default: queued <= queued;
            endcase
            if (pop) begin rd_ptr <= rd_ptr + 1'b1; head_started <= 0; end
            if (start) begin
                if (head[16]) head_started <= 1;
                if (active) begin
                    error_pending <= 1;
                    short_frame_count <= short_frame_count + 1'b1;
                end
                active_sequence <= event_sequences[rd_ptr];
                active <= 1; pixels <= 0; tail_seen <= 0; tail_bad <= 0;
            end
            if (fire) begin
                pixels <= pixels + 1'b1;
                if (pixels == TOTAL-1) begin
                    active <= 0; end_pending <= 1; marker_drain <= 4'b1111;
                    publish_sequence <= active_sequence;
                    publish_error <= error_pending;
                    error_pending <= 0;
                end
            end
            if (end_pending) end_pending <= 0;
            if (have && !start && !boundary_busy && head[16] && !active) begin
                tail_seen <= 1;
                if (excess) begin tail_bad <= 1; error_pending <= 1; end
            end
            // Detector valid is a pulse; snapshot every field together.
            if (strobe) motion_record <= {
                bitmap_word, 16'b0, maxy_word, miny_word, maxx_word, minx_word,
                8'b0, sample_word, block_word,
                29'b0, publish_error, bbox_valid, comparison_valid, publish_sequence
            };
            end
        end
    end
endmodule
