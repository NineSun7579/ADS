// Sideband RGB565 detector. Geometry/image semantics: sim/motion/README.md.
// Timing: sample acceptance -> registered decision -> local work update.
// Complete frame results publish two rising edges after frame_end. A next
// frame_start at end+1 is legal; its first pixel at end+2 can coincide with
// publication. The old final update commits before the deferred work clear.
module block_motion_detector #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 480,
    parameter SAMPLE_STEP = 4,
    parameter BLOCK_SAMPLES_X = 10,
    parameter BLOCK_SAMPLES_Y = 10,
    parameter PIXEL_THRESHOLD = 16,
    parameter BLOCK_THRESHOLD = 8,
    // Derived geometry parameters: do not override independently.
    parameter SAMPLE_COLS = (WIDTH + SAMPLE_STEP - 1) / SAMPLE_STEP,
    parameter SAMPLE_ROWS = (HEIGHT + SAMPLE_STEP - 1) / SAMPLE_STEP,
    parameter BLOCK_COLS = (SAMPLE_COLS + BLOCK_SAMPLES_X - 1) / BLOCK_SAMPLES_X,
    parameter BLOCK_ROWS = (SAMPLE_ROWS + BLOCK_SAMPLES_Y - 1) / BLOCK_SAMPLES_Y
) (
    input wire clk,
    input wire rst_n,
    input wire frame_start,
    input wire frame_end,
    input wire pixel_valid,
    input wire [15:0] pixel_rgb565,
    output reg result_strobe,
    output reg result_valid,
    output reg [BLOCK_COLS*BLOCK_ROWS-1:0] block_bitmap,
    output reg [$clog2(BLOCK_COLS*BLOCK_ROWS+1)-1:0] changed_blocks,
    output reg [$clog2(SAMPLE_COLS*SAMPLE_ROWS+1)-1:0] changed_samples,
    output reg bbox_valid,
    output reg [((BLOCK_COLS > 1) ? $clog2(BLOCK_COLS) : 1)-1:0] bbox_min_x,
    output reg [((BLOCK_COLS > 1) ? $clog2(BLOCK_COLS) : 1)-1:0] bbox_max_x,
    output reg [((BLOCK_ROWS > 1) ? $clog2(BLOCK_ROWS) : 1)-1:0] bbox_min_y,
    output reg [((BLOCK_ROWS > 1) ? $clog2(BLOCK_ROWS) : 1)-1:0] bbox_max_y,
    output reg [31:0] frame_sequence
);
    localparam integer TOTAL_PIXELS = WIDTH * HEIGHT;
    localparam TOTAL_SAMPLES = SAMPLE_COLS * SAMPLE_ROWS;
    localparam TOTAL_BLOCKS = BLOCK_COLS * BLOCK_ROWS;
    localparam X_BITS = (WIDTH > 1) ? $clog2(WIDTH) : 1;
    localparam Y_BITS = (HEIGHT > 1) ? $clog2(HEIGHT) : 1;
    localparam ADDR_BITS = (TOTAL_SAMPLES > 1) ? $clog2(TOTAL_SAMPLES) : 1;
    localparam BLOCK_BITS = (TOTAL_BLOCKS > 1) ? $clog2(TOTAL_BLOCKS) : 1;
    localparam BX_BITS = (BLOCK_COLS > 1) ? $clog2(BLOCK_COLS) : 1;
    localparam BY_BITS = (BLOCK_ROWS > 1) ? $clog2(BLOCK_ROWS) : 1;
    localparam COUNT_BITS = $clog2(BLOCK_THRESHOLD + 1);

    reg active, reference_valid;
    reg [$clog2(TOTAL_PIXELS+1)-1:0] pixel_count;
    reg [X_BITS-1:0] x;
    reg [Y_BITS-1:0] y;
    reg [ADDR_BITS-1:0] sample_address;
    // count_room == (pixel_count < TOTAL_PIXELS), kept as a register so the
    // 19-bit compare is off the accept -> history RAM write-enable path.
    reg count_room;
    wire accept_pixel = active && pixel_valid && !frame_start && !frame_end &&
                        count_room;
    wire accept_sample = accept_pixel && ((x % SAMPLE_STEP) == 0) &&
                         ((y % SAMPLE_STEP) == 0);
    wire [BX_BITS-1:0] sample_bx = (x / SAMPLE_STEP) / BLOCK_SAMPLES_X;
    wire [BY_BITS-1:0] sample_by = (y / SAMPLE_STEP) / BLOCK_SAMPLES_Y;
    wire [BLOCK_BITS-1:0] sample_block = sample_by * BLOCK_COLS + sample_bx;

    wire [7:0] red = {pixel_rgb565[15:11], pixel_rgb565[15:13]};
    wire [7:0] green = {pixel_rgb565[10:5], pixel_rgb565[10:9]};
    wire [7:0] blue = {pixel_rgb565[4:0], pixel_rgb565[4:2]};
    wire [9:0] luma_sum = {2'b0, red} + {1'b0, green, 1'b0} + {2'b0, blue};
    wire [7:0] luma = luma_sum[9:2];

    // No reset/clear of this array or read register: synchronous read-first
    // single-port RAM template. Each sampled address is touched once/frame.
    reg [7:0] history [0:TOTAL_SAMPLES-1];
    reg [7:0] history_q;
    always @(posedge clk) begin
        if (rst_n && accept_sample) begin
            history_q <= history[sample_address];
            history[sample_address] <= luma;
        end
    end

    reg compare_pending, compare_enabled;
    reg [7:0] current_q;
    reg [BLOCK_BITS-1:0] block_q;
    reg [BX_BITS-1:0] bx_q;
    reg [BY_BITS-1:0] by_q;
    // |current - history| >= PIXEL_THRESHOLD from two parallel 9-bit
    // subtractions instead of compare -> mux -> subtract after the DRM read
    // (that chain failed setup by 0.07 ns). The result is identical.
    wire [8:0] diff_ch = {1'b0, current_q} - {1'b0, history_q};
    wire [8:0] diff_hc = {1'b0, history_q} - {1'b0, current_q};
    wire changed_now = (!diff_ch[8] && diff_ch[7:0] >= PIXEL_THRESHOLD) ||
                       (!diff_hc[8] && diff_hc[7:0] >= PIXEL_THRESHOLD);
    reg [COUNT_BITS-1:0] block_hits [0:TOTAL_BLOCKS-1];
    reg [TOTAL_BLOCKS-1:0] bitmap_work;
    reg [$clog2(TOTAL_BLOCKS+1)-1:0] blocks_work;
    reg [$clog2(TOTAL_SAMPLES+1)-1:0] samples_work;
    reg bbox_work_valid;
    reg [BX_BITS-1:0] min_x_work, max_x_work;
    reg [BY_BITS-1:0] min_y_work, max_y_work;
    // Compare decision and decoded destination are registered independently.
    // Local counter reads avoid a wide selected-count mux and need no forwarding.
    reg update_pending, changed_q;
    reg [TOTAL_BLOCKS-1:0] select_q;
    reg [BX_BITS-1:0] update_bx;
    reg [BY_BITS-1:0] update_by;
    // per-block threshold flags, one register bit per block. hit7[i] tracks
    // whether block_hits[i] has reached BLOCK_THRESHOLD-1; it is set when the
    // counter increments to BLOCK_THRESHOLD-1 and cleared when the counter
    // leaves that value (frame clear or increment past it), all on the same
    // edges as the counter itself. By induction hit7[i] equals
    // (block_hits[i] == BLOCK_THRESHOLD-1) at every cycle, because the
    // counters only ever increment (saturating at BLOCK_THRESHOLD) or clear
    // to zero, so the mark decision needs no comparator at all.
    reg [TOTAL_BLOCKS-1:0] hit7;
    wire mark_any = update_pending && changed_q && |(hit7 & select_q);
    wire [TOTAL_BLOCKS-1:0] mark_block;
    genvar b;
    generate for (b = 0; b < TOTAL_BLOCKS; b = b + 1) begin : local_hit
        assign mark_block[b] = update_pending && changed_q && hit7[b] && select_q[b];
    end endgenerate
    reg end_pending, publish_pending, publish_comparison_valid;
    reg clear_after_publish;
    // Work/counter clear is applied one clock after its condition, from
    // replicated registers (the combinational condition fanned out to ~800
    // loads and failed setup). In the clock between, update_pending is always
    // low (frame_start forces it, and a deferred clear follows a frame_start
    // one clock earlier), and publication only happens on the condition clock
    // itself, so no update or publish can observe the late clear.
    localparam CLEAR_COPIES = 8;
    wire clear_now = (frame_start && !end_pending) || (publish_pending && clear_after_publish);
    (* syn_preserve=1 *) reg [CLEAR_COPIES-1:0] clear_q;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 0;
            reference_valid <= 0;
            pixel_count <= 0;
            count_room <= (TOTAL_PIXELS > 0);
            x <= 0;
            y <= 0;
            sample_address <= 0;
            compare_pending <= 0;
            compare_enabled <= 0;
            current_q <= 0;
            block_q <= 0;
            bx_q <= 0;
            by_q <= 0;
            update_pending <= 0;
            changed_q <= 0;
            select_q <= 0;
            clear_q <= 0;
            update_bx <= 0;
            update_by <= 0;
            end_pending <= 0;
            publish_pending <= 0;
            clear_after_publish <= 0;
            publish_comparison_valid <= 0;
            bitmap_work <= 0;
            blocks_work <= 0;
            samples_work <= 0;
            bbox_work_valid <= 0;
            min_x_work <= 0;
            max_x_work <= 0;
            min_y_work <= 0;
            max_y_work <= 0;
            result_strobe <= 0;
            result_valid <= 0;
            block_bitmap <= 0;
            changed_blocks <= 0;
            changed_samples <= 0;
            bbox_valid <= 0;
            bbox_min_x <= 0;
            bbox_max_x <= 0;
            bbox_min_y <= 0;
            bbox_max_y <= 0;
            frame_sequence <= 0;
            for (i = 0; i < TOTAL_BLOCKS; i = i + 1) begin
                block_hits[i] <= 0;
                hit7[i] <= (BLOCK_THRESHOLD == 1);
            end
        end else begin
            result_strobe <= 0;
            result_valid <= 0;
            end_pending <= 0;
            publish_pending <= end_pending;
            update_pending <= compare_pending;
            changed_q <= compare_enabled && changed_now;
            for (i = 0; i < TOTAL_BLOCKS; i = i + 1)
                select_q[i] <= (block_q == i);
            update_bx <= bx_q;
            update_by <= by_q;
            compare_pending <= accept_sample;
            if (accept_sample) begin
                current_q <= luma;
                block_q <= sample_block;
                bx_q <= sample_bx;
                by_q <= sample_by;
                compare_enabled <= reference_valid;
            end

            // The last decision commits at end+1; publish the settled work at
            // end+2. A start at end+1 defers its work clear until publication.
            // Its first pixel may arrive at end+2 (updates arrive two edges later).
            if (publish_pending) begin
                result_strobe <= 1;
                result_valid <= publish_comparison_valid;
                block_bitmap <= bitmap_work;
                changed_blocks <= blocks_work;
                changed_samples <= samples_work;
                bbox_valid <= bbox_work_valid;
                bbox_min_x <= min_x_work;
                bbox_max_x <= max_x_work;
                bbox_min_y <= min_y_work;
                bbox_max_y <= max_y_work;
                frame_sequence <= frame_sequence + 1'b1;
            end

            if (frame_start) begin
                // A restart without end may have overwritten part of history.
                if (active)
                    reference_valid <= 0;
                active <= 1;
                pixel_count <= 0;
                count_room <= (TOTAL_PIXELS > 0);
                x <= 0;
                y <= 0;
                sample_address <= 0;
                compare_pending <= 0;
                update_pending <= 0;
                clear_after_publish <= end_pending;
            end

            // Preserve the old frame's last update across the earliest legal
            // next start, but discard both pipeline stages on an active restart.
            clear_q <= {CLEAR_COPIES{clear_now}};
            if (clear_now) clear_after_publish <= 0;
            begin
                if (update_pending && changed_q) begin
                    samples_work <= samples_work + 1'b1;
                    for (i = 0; i < TOTAL_BLOCKS; i = i + 1) begin
                        if (select_q[i] && block_hits[i] < BLOCK_THRESHOLD)
                            block_hits[i] <= block_hits[i] + 1'b1;
                        if (select_q[i])
                            hit7[i] <= (block_hits[i] == BLOCK_THRESHOLD - 2);
                        if (mark_block[i]) bitmap_work[i] <= 1'b1;
                    end
                    if (mark_any) begin
                        blocks_work <= blocks_work + 1'b1;
                        bbox_work_valid <= 1;
                        if (!bbox_work_valid || update_bx < min_x_work) min_x_work <= update_bx;
                        if (!bbox_work_valid || update_bx > max_x_work) max_x_work <= update_bx;
                        if (!bbox_work_valid || update_by < min_y_work) min_y_work <= update_by;
                        if (!bbox_work_valid || update_by > max_y_work) max_y_work <= update_by;
                    end
                end
            end
            // Clear last so it has priority (never coincides with an update).
            if (clear_q[0]) begin
                bitmap_work <= 0;
                blocks_work <= 0;
                samples_work <= 0;
                bbox_work_valid <= 0;
                min_x_work <= 0;
                max_x_work <= 0;
                min_y_work <= 0;
                max_y_work <= 0;
            end
            for (i = 0; i < TOTAL_BLOCKS; i = i + 1)
                if (clear_q[i % CLEAR_COPIES]) begin
                    block_hits[i] <= 0;
                    hit7[i] <= (BLOCK_THRESHOLD == 1);
                end
            if (!frame_start) begin
                if (accept_pixel) begin
                    pixel_count <= pixel_count + 1'b1;
                    if (pixel_count == TOTAL_PIXELS - 1) count_room <= 1'b0;
                    if (x == WIDTH - 1) begin
                        x <= 0;
                        if (y != HEIGHT - 1) y <= y + 1'b1;
                    end else x <= x + 1'b1;
                    if (accept_sample && sample_address != TOTAL_SAMPLES - 1)
                        sample_address <= sample_address + 1'b1;
                end
                if (frame_end && active) begin
                    active <= 0;
                    if (pixel_count == TOTAL_PIXELS) begin
                        end_pending <= 1;
                        publish_comparison_valid <= reference_valid;
                        reference_valid <= 1;
                    end else reference_valid <= 0;
                end
            end
        end
    end
    // synthesis translate_off
    always @(posedge clk)
        if (rst_n && count_room !== (pixel_count < TOTAL_PIXELS))
            $display("DET_COUNT_ROOM_MISMATCH %m t=%0t", $time);
    always @(posedge clk)
        if (rst_n && clear_q[0] && (update_pending || publish_pending))
            $display("DET_CLEAR_OVERLAP %m t=%0t update=%b publish=%b", $time, update_pending, publish_pending);
    // synthesis translate_on
endmodule
