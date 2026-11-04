//============================================================================
// [WIP - 批2数据通路, 未出比特流] 已知问题: 打包器 wr_data 的 beat->lane
// 映射与 preprocess bypass 输出时序需波形级校准 (tb_cam_prep_link 当前
// FAIL), RAW 旁路路径已验证正确。bitstream_2026-09-11 不含本模块功能行为
// (top.v 数据通路在该构建编译之后才接入)。
// cam_prep_link.v : camera pixel-stream tap for the preprocess pipeline
//
//   camera raw stream (128b word = 8 RGB565 pixels, frame_sync pulse/frame)
//     -> raw passthrough to the RAW write engine (1 handshake per word,
//        at the word's last pixel)
//     -> mirror into preprocess_top (16b pixels + frame_sync + tail dummy)
//     -> collect processed output, pack to 128b, per-frame write commands
//        into the processed-frame ping-pong region
//
//   Frame contract: camera delivers W*H/8 words per frame (W*H pixels);
//   preprocess receives W*H+1 pixels (one tail dummy) and emits
//   (W-2)*(H-2) processed pixels (bypass: W*H). Write commands are issued
//   at output frame start with the pre-computed byte length. Stray beats
//   outside an active frame (e.g. the bypass echo of the tail dummy) are
//   accepted-and-dropped so the preprocess FIFO never wedges.
//============================================================================
module cam_prep_link #(
    parameter FRAME_H = 720,                    // v1: fixed height
    parameter BUFFER0 = 32'h0A00_0000,          // processed frame ping
    parameter BUFFER1 = 32'h0A1C_2000           // processed frame pong
)(
    input          clk,
    input          rst,

    // config (from prep_regs)
    input  [11:0]  img_width,                   // W (default 1280)
    input          bypass_mode,
    input  [1:0]   mode,

    // camera raw stream in
    input  [127:0] cam_data,
    input          cam_valid,
    output         cam_ready,
    input          cam_frame_sync,              // pulse at frame start

    // raw stream out (to RAW axi_dma_write)
    output [127:0] raw_data,
    output         raw_valid,
    input          raw_ready,

    // preprocess_top input side
    output [15:0]  pp_data,
    output         pp_valid,
    input          pp_ready,
    output         pp_frame_sync,

    // preprocess_top output side
    input  [15:0]  out_data,
    input          out_valid,
    output         out_ready,
    input          out_frame_sync,              // output frame start pulse

    // processed write engine (axi_dma_write)
    output         wr_cmd_valid,
    input          wr_cmd_ready,
    output [31:0]  wr_cmd_addr,
    output [31:0]  wr_cmd_len,
    output [127:0] wr_data,
    output         wr_valid,
    input          wr_ready
);

    //----------------------------------------
    // input stage: word latch + 8-pixel emitter + tail dummy injector
    //----------------------------------------
    reg [127:0] word_hold;                      // full word (raw passthrough)
    reg [127:0] pix_shreg;                      // shifting copy (pixel emit)
    reg [2:0]   icnt;
    reg         ibusy;
    reg         ilast;                          // current word is frame's last
    reg         iinject;                        // tail dummy pixel pending
    reg [16:0]  in_word_cnt;
    reg [16:0]  rd_word_cnt;                 // [EDGE-TAP] popped-word counter (read side)

    wire [16:0] frame_words_m1 = (img_width * FRAME_H) / 8 - 1'b1;
    wire        iemit_last     = ibusy && (icnt == 3'd7) && pp_ready;

    // [EDGE-TAP 2026-09-13] 128-bit word FIFO absorbs camera word bursts so the
    // 8-pixel emitter always unpacks a STABLE copy (a word landing mid-emission
    // would reset icnt and corrupt the unpack). The camera is never back-pressured.
    wire [127:0] wf_data;
    wire         wf_valid;
    wire         wf_full;   // near-full: gate the write so the
                             // circular pointers can never wrap past
                             // each other (analysis: occupancy ~10 max)
    reg          wf_rd;
    // 128b x 32 = 4096 FF (emitter is ~15x faster than the camera word rate)
    prep_sync_fifo #(.DW(128), .DEPTH(32), .AFULL(24)) u_wfifo (
        .clk(clk), .rst_n(~rst),   // [EDGE-TAP] note: `rst` here is ACTIVE HIGH
        .wr_en(cam_valid && !wf_full), .wr_data(cam_data),
        .rd_en(wf_rd), .rd_data(wf_data), .rd_valid(wf_valid),
        .prog_full(wf_full), .cnt()
    );

    assign cam_ready = 1'b1;   // [EDGE-TAP] never back-pressure the camera

    assign pp_data       = iinject ? 16'd0 : pix_shreg[15:0];
    assign pp_valid      = ibusy || iinject;
    // [EDGE-TAP] frame sync must come from the POP side, not from cam_frame_sync:
    // the pixel stream is delayed by the FIFO, so the camera-side pulse would
    // land mid-stream and make sobel reset inside a frame. Assert on the cycle
    // the first word of a frame is popped -> exactly one cycle before pixel 0.
    wire pp_pop  = !ibusy && !iinject && wf_valid;
    wire rd_wrap = (rd_word_cnt == frame_words_m1);
    assign pp_frame_sync = pp_pop && (rd_word_cnt == 17'd0);

    assign raw_data  = cam_data;
    assign raw_valid = cam_valid; // single handshake at last pixel

    always @(posedge clk) begin
        if (rst) begin
            ibusy <= 1'b0; icnt <= 3'd0; iinject <= 1'b0; ilast <= 1'b0;
            in_word_cnt <= 17'd0;
            rd_word_cnt <= 17'd0;
            word_hold <= 128'd0; pix_shreg <= 128'd0;
            wf_rd <= 1'b0;
        end
        else begin
            wf_rd <= 1'b0;                  // default: no pop
            // pixel emission
            if (ibusy && pp_ready) begin
                pix_shreg <= {16'd0, pix_shreg[127:16]};
                icnt      <= icnt + 3'd1;
                if (icnt == 3'd7)
                    ibusy <= 1'b0;
            end
            // dummy injection consume
            if (iinject && pp_ready)
                iinject <= 1'b0;
            // schedule dummy after frame's last word fully emitted
            if (ilast && iemit_last)
                iinject <= 1'b1;
            // [EDGE-TAP] pop one word from the FIFO when the emitter is idle
            if (!ibusy && !iinject && wf_valid) begin
                word_hold <= wf_data;
                pix_shreg <= wf_data;
                wf_rd     <= 1'b1;      // pop it
                // [EDGE-TAP] self-wrapping pop counter: must NOT be reset by the
                // camera-side frame pulse (FIFO backlog would misalign it).
                rd_word_cnt <= rd_wrap ? 17'd0 : (rd_word_cnt + 17'd1);
                ibusy     <= 1'b1;
                icnt      <= 3'd0;
                ilast     <= (rd_word_cnt == frame_words_m1);
            end
            // per-frame word counter
            if (cam_frame_sync)
                in_word_cnt <= 17'd0;
            else if (cam_valid)
                in_word_cnt <= in_word_cnt + 17'd1;
        end
    end

    //----------------------------------------
    // expected processed pixels/words per frame
    //----------------------------------------
    // [EDGE-INT] sobel/align16 now emit full W x H (no edge judgement outside frame), so expected pixel count
    // equals the source, not the cropped (W-2)*(H-2).
    wire [31:0] frame_pixels = img_width * FRAME_H;
    wire [31:0] frame_words  = (frame_pixels + 7) >> 3;
    wire [31:0] frame_bytes  = frame_words << 4;

    //----------------------------------------
    // output stage: 16b beats -> 128b words + partial-word flush
    //----------------------------------------
    reg  [127:0] oshreg;
    reg  [2:0]   ocnt;
    reg  [31:0]  opix;                          // processed pixels accepted
    reg          oactive;                       // inside an output frame
    reg          cmd_pending;
    reg          ping_sel;
    reg          flush_pend;                    // partial word to flush

    wire frame_end = oactive && (opix >= frame_pixels);  // [EDGE-INT] >= tolerant compare

    // accept beats only inside a frame; during flush hold off (protect word)
    assign out_ready = oactive && !flush_pend &&
                       ( (ocnt != 3'd7) || wr_ready );
    wire oaccept = out_valid && out_ready;

    assign wr_cmd_valid = cmd_pending;
    assign wr_cmd_addr  = ping_sel ? BUFFER1 : BUFFER0;
    assign wr_cmd_len   = frame_bytes;
    // assembled word: beats 0..6 at [111:0], 8th beat comes from out_data
    assign wr_data      = (ocnt == 3'd7) ? {out_data, oshreg[111:0]} : oshreg;
    assign wr_valid     = oactive && wr_ready &&
                          ( (oaccept && (ocnt == 3'd7)) || flush_pend );

    always @(posedge clk) begin
        if (rst) begin
            oshreg <= 128'd0; ocnt <= 3'd0; opix <= 32'd0;
            oactive <= 1'b0; cmd_pending <= 1'b0; ping_sel <= 1'b0;
            flush_pend <= 1'b0;
        end
        else begin
            // frame start: prepare write command
            if (out_frame_sync && !oactive) begin
                oactive     <= 1'b1;
                ocnt        <= 3'd0;
                opix        <= 32'd0;
                ping_sel    <= ~ping_sel;
                cmd_pending <= 1'b1;
                flush_pend  <= 1'b0;
            end
            if (cmd_pending && wr_cmd_ready)
                cmd_pending <= 1'b0;

            // beat packing (only inside an active frame; strays dropped)
            if (oaccept) begin
                oshreg <= {out_data, oshreg[127:16]};
                opix   <= opix + 32'd1;
                if (ocnt == 3'd7)
                    ocnt <= 3'd0;
                else
                    ocnt <= ocnt + 3'd1;
            end

            // frame end: flush partial word or close a whole-word frame
            if (frame_end) begin
                if (ocnt != 3'd0)
                    flush_pend <= 1'b1;
                else if (!flush_pend)
                    oactive <= 1'b0;
            end
            if (flush_pend && wr_ready) begin
                flush_pend <= 1'b0;
                ocnt       <= 3'd0;
                oactive    <= 1'b0;
            end
        end
    end

endmodule
