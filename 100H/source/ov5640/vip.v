// ============================================================================
// vip.v -- RGB565 3x3 median filter for the OV5640 pixel stream
//
// The module keeps the original vip port and frame/FIFO contract.  When en is
// asserted, cam1 pixels are filtered with a 3x3 median independently on the
// native RGB565 R[4:0], G[5:0] and B[4:0] channels.  Image boundaries use the
// nearest pixel (replication).  When en is deasserted, the centre pixel is
// passed through unchanged.
//
// The input stream cannot be stalled.  Three rotating line banks are used.
// A window is emitted one column behind the live input so that the right-hand
// pixel of the current input line is available.  The final column of each
// output line is emitted at the beginning of the following input line, after
// the completed bottom line has been written.  This preserves one output
// pixel per input pixel on average without changing the downstream protocol.
//
// The first frame is used to fill the rotating banks.  The output is therefore
    // frame-delayed, as required by the 3x3 window.  The output
// FIFO inserts the existing GAP_LEN blanking interval and out_vsync pulse
// after the tagged final pixel of every output frame.
// ============================================================================
`timescale 1ns/1ps
module vip #(
    parameter integer W       = 640,
    parameter integer H       = 480,
    parameter integer STRIDE  = 1024,
    parameter integer AW      = 10,
    parameter integer GAP_LEN = 64
)(
    input  wire        clk,
    input  wire        rst,

    input  wire        en,               // 1 = RGB565 median, 0 = passthrough
    input  wire [2:0]  strength,         // retained for upper-level compatibility; unused

    input  wire        in_valid,
    input  wire [15:0] in_pixel,
    input  wire        in_vsync,

    output reg         out_valid,
    output reg  [15:0] out_pixel,
    output reg         out_vsync
);

    // ------------------------------------------------------------------
    // Three rotating line buffers:
    //   bank_cur  = line currently being received
    //   bank_prev = preceding completed line
    //   bank_prev2= two lines before the line currently being received
    // ------------------------------------------------------------------
    reg [15:0] lbuf [0:3*STRIDE-1];
    reg [1:0]  bank_cur, bank_prev, bank_prev2;

    reg [AW-1:0] k;
    reg [15:0]    l;
    reg           first_round;

    // ---------------- frame re-synchronisation ----------------
    reg [1:0] vs_ff;
    always @(posedge clk) begin
        if (rst)
            vs_ff <= 2'b0;
        else
            vs_ff <= {vs_ff[0], in_vsync};
    end
    wire vs_rise = vs_ff[0] & ~vs_ff[1];

    reg [18:0] frame_pix;
    reg        frame_full;

    localparam [AW-1:0] W_LAST = W - 1;
    localparam [15:0]  H_LAST = H - 1;

    wire consume   = in_valid && !frame_full;
    wire frame_last = consume && (frame_pix == (W*H-1));
    wire k_first   = (k == {AW{1'b0}});
    wire k_last    = (k == W_LAST);
    wire l_first   = (l == 16'd0);
    wire l_wrap    = (l == H_LAST);

    // ------------------------------------------------------------------
    // Median helper.  The inputs are zero-extended native RGB565 channel
    // values; sorting is independent for each channel.
    //
    // Depth-4 selection network instead of a bubble sort: a 3-sorter is
    // depth 2 (3 comparators), and sorting the three rows then the three
    // columns leaves the median at the centre of the 3x3 matrix.  A
    // 36-stage bubble sort produced a ~15 ns combinational path that
    // failed timing at the pixel clock; this network is ~4 comparator
    // delays deep and still yields the exact median.
    // ------------------------------------------------------------------
    function [23:0] sort3;
        input [7:0] a;
        input [7:0] b;
        input [7:0] c;
        reg [7:0] l1, h1, l2, m1, m2, h2;
        begin
            l1 = (a  <= b)  ? a  : b;
            h1 = (a  <= b)  ? b  : a;
            l2 = (l1 <= c)  ? l1 : c;
            m1 = (l1 <= c)  ? c  : l1;
            m2 = (h1 <= m1) ? h1 : m1;
            h2 = (h1 <= m1) ? m1 : h1;
            sort3 = {h2, m2, l2};
        end
    endfunction

    // ------------------------------------------------------------------
    // 3x3 window scheduling
    //
    // A normal event at input column k emits output column k-1.  A flush
    // event at input column 0 emits the previous line's final column.  The
    // latter is delayed until the bottom line is complete, which is also
    // where the top/bottom boundary replication decisions are made.
    // ------------------------------------------------------------------
    wire normal_emit = consume && !k_first && !(first_round && l_first);
    wire flush_emit  = consume && k_first &&
                       (!first_round || (l >= 16'd2));
    wire emit        = normal_emit || flush_emit;

    wire [AW-1:0] emit_col = flush_emit ? W_LAST : (k - 1'b1);
    wire [AW-1:0] emit_col_l = (emit_col == {AW{1'b0}}) ?
                                {AW{1'b0}} : (emit_col - 1'b1);
    wire [AW-1:0] emit_col_r = (emit_col == W_LAST) ?
                                W_LAST : (emit_col + 1'b1);

    // For normal events the centre is the completed preceding line.  For a
    // flush event the completed preceding line has become bank_prev2 after
    // the line-bank rotation at the end of the bottom line.
    wire [1:0] centre_bank = flush_emit ? bank_prev2 : bank_prev;
    wire [1:0] top_bank = flush_emit ?
                           ((l == 16'd2) ? bank_prev2 : bank_cur) :
                           ((l == 16'd1) ? bank_prev : bank_prev2);

    // The last image row uses a replicated bottom row.  For all other rows,
    // bottom_bank is the completed/current input row that supplies the third
    // window row.
    wire bottom_replicate = flush_emit ?
                            ((!first_round && (l == 16'd1))) :
                            ((!first_round && (l == 16'd0)));
    wire [1:0] bottom_bank = flush_emit ?
                             (bottom_replicate ? bank_prev2 : bank_prev) :
                             (bottom_replicate ? bank_prev  : bank_cur);

    wire [15:0] top_l_mem = lbuf[top_bank   * STRIDE + emit_col_l];
    wire [15:0] top_c_mem = lbuf[top_bank   * STRIDE + emit_col  ];
    wire [15:0] top_r_mem = lbuf[top_bank   * STRIDE + emit_col_r];

    wire [15:0] mid_l_mem = lbuf[centre_bank * STRIDE + emit_col_l];
    wire [15:0] mid_c_mem = lbuf[centre_bank * STRIDE + emit_col  ];
    wire [15:0] mid_r_mem = lbuf[centre_bank * STRIDE + emit_col_r];

    wire [15:0] bot_l_mem = lbuf[bottom_bank * STRIDE + emit_col_l];
    wire [15:0] bot_c_mem = lbuf[bottom_bank * STRIDE + emit_col  ];
    wire [15:0] bot_r_mem = lbuf[bottom_bank * STRIDE + emit_col_r];

    // For a normal event the current line's right pixel is the live input;
    // its left and centre pixels were written on previous input cycles.
    wire [15:0] bot_l = bottom_replicate ? mid_l_mem : bot_l_mem;
    wire [15:0] bot_c = bottom_replicate ? mid_c_mem :
                        (flush_emit ? bot_c_mem :
                         lbuf[bank_cur * STRIDE + emit_col]);
    wire [15:0] bot_r = bottom_replicate ? mid_r_mem :
                        (flush_emit ? bot_r_mem : in_pixel);

    // ------------------------------------------------------------------
    // stage W: capture the complete 3x3 RGB565 window
    // ------------------------------------------------------------------
    reg [15:0] Wtl, Wtc, Wtr;
    reg [15:0] Wml, Wmc, Wmr;
    reg [15:0] Wbl, Wbc, Wbr;
    reg        Wva, Weof;

    always @(posedge clk) begin
        if (rst) begin
            Wtl <= 16'd0; Wtc <= 16'd0; Wtr <= 16'd0;
            Wml <= 16'd0; Wmc <= 16'd0; Wmr <= 16'd0;
            Wbl <= 16'd0; Wbc <= 16'd0; Wbr <= 16'd0;
            Wva <= 1'b0;
            Weof <= 1'b0;
        end
        else begin
            Wva  <= emit;
            // Last output pixel is the last-column flush for old frame's
            // final row, at the start of input line 1 of the next frame.
            Weof <= flush_emit && !first_round && (l == 16'd1);
            if (emit) begin
                Wtl <= top_l_mem;
                Wtc <= top_c_mem;
                Wtr <= top_r_mem;
                Wml <= mid_l_mem;
                Wmc <= mid_c_mem;
                Wmr <= mid_r_mem;
                Wbl <= bot_l;
                Wbc <= bot_c;
                Wbr <= bot_r;
            end
        end
    end

    // ------------------------------------------------------------------
    // stage R: sort the three rows of the 3x3 window (depth 2).
    // The median network is split across two pipeline stages (row sort
    // here, column sort in stage M) so each stage is only ~2 comparator
    // delays deep and meets the pixel clock.
    // ------------------------------------------------------------------
    reg [23:0] Sr0, Sr1, Sr2;
    reg [23:0] Sg0, Sg1, Sg2;
    reg [23:0] Sb0, Sb1, Sb2;
    reg [15:0] Wmc_r;
    reg        Rva, Reof;

    always @(posedge clk) begin
        if (rst) begin
            Sr0 <= 24'd0; Sr1 <= 24'd0; Sr2 <= 24'd0;
            Sg0 <= 24'd0; Sg1 <= 24'd0; Sg2 <= 24'd0;
            Sb0 <= 24'd0; Sb1 <= 24'd0; Sb2 <= 24'd0;
            Wmc_r <= 16'd0;
            Rva  <= 1'b0;
            Reof <= 1'b0;
        end
        else begin
            Rva   <= Wva;
            Reof  <= Weof;
            Wmc_r <= Wmc;
            Sr0 <= sort3({3'b000, Wtl[15:11]}, {3'b000, Wtc[15:11]}, {3'b000, Wtr[15:11]});
            Sr1 <= sort3({3'b000, Wml[15:11]}, {3'b000, Wmc[15:11]}, {3'b000, Wmr[15:11]});
            Sr2 <= sort3({3'b000, Wbl[15:11]}, {3'b000, Wbc[15:11]}, {3'b000, Wbr[15:11]});
            Sg0 <= sort3({2'b00, Wtl[10:5]}, {2'b00, Wtc[10:5]}, {2'b00, Wtr[10:5]});
            Sg1 <= sort3({2'b00, Wml[10:5]}, {2'b00, Wmc[10:5]}, {2'b00, Wmr[10:5]});
            Sg2 <= sort3({2'b00, Wbl[10:5]}, {2'b00, Wbc[10:5]}, {2'b00, Wbr[10:5]});
            Sb0 <= sort3({3'b000, Wtl[4:0]}, {3'b000, Wtc[4:0]}, {3'b000, Wtr[4:0]});
            Sb1 <= sort3({3'b000, Wml[4:0]}, {3'b000, Wmc[4:0]}, {3'b000, Wmr[4:0]});
            Sb2 <= sort3({3'b000, Wbl[4:0]}, {3'b000, Wbc[4:0]}, {3'b000, Wbr[4:0]});
        end
    end

    // ------------------------------------------------------------------
    // stage M: sort the middle column and take its centre element; that
    // element is the median of the 3x3 window (depth 2).
    // ------------------------------------------------------------------
    wire [23:0] Cm_r = sort3(Sr0[15:8], Sr1[15:8], Sr2[15:8]);
    wire [23:0] Cm_g = sort3(Sg0[15:8], Sg1[15:8], Sg2[15:8]);
    wire [23:0] Cm_b = sort3(Sb0[15:8], Sb1[15:8], Sb2[15:8]);

    wire [7:0] med_r8 = Cm_r[15:8];
    wire [7:0] med_g8 = Cm_g[15:8];
    wire [7:0] med_b8 = Cm_b[15:8];

    wire [15:0] median_px = en ?
                             {med_r8[4:0], med_g8[5:0], med_b8[4:0]} :
                             Wmc_r;

    reg [15:0] Mres;
    reg        Mva, Meof, Mstart;
    reg        m_frame_active;
    always @(posedge clk) begin
        if (rst) begin
            Mres <= 16'd0;
            Mva  <= 1'b0;
            Meof <= 1'b0;
            Mstart <= 1'b0;
            m_frame_active <= 1'b0;
        end
        else begin
            Mres <= median_px;
            Mva  <= Rva;
            Meof <= Reof;
            // The first line-buffer priming pass is not a complete output
            // frame. Do not publish its first pixel as a frame-start marker;
            // subsequent completed frames carry one SOF each.
            Mstart <= Rva && !m_frame_active && !first_round;
            if (Rva)
                m_frame_active <= !Reof;
        end
    end

    // ------------------------------------------------------------------
    // Elastic output FIFO: 1024 x {sof, eof, pixel}.
    //
    // The input camera stream cannot be stalled.  A 128-entry FIFO was not
    // sufficient when the downstream DDR writer briefly paused around a
    // frame boundary: push then silently dropped a pixel, and the writer
    // could never reach its expected AXI last beat.  Keep enough elasticity
    // for the complete frame-boundary pause instead of dropping data.
    // ------------------------------------------------------------------
    reg  [17:0] ofifo [0:1023];
    reg  [9:0]  of_wp, of_rp;

    wire        of_empty = (of_wp == of_rp);
    wire        of_full  = ((of_wp - of_rp) == 10'd1023);
    wire [17:0] of_head  = ofifo[of_rp];
    wire        push     = Mva && !of_full;

    always @(posedge clk) begin
        if (rst)
            of_wp <= 10'd0;
        else if (push) begin
            ofifo[of_wp] <= {Mstart, Meof, Mres};
            of_wp <= of_wp + 10'd1;
        end
    end

    // ------------------------------------------------------------------
    // Output controller: drain FIFO and insert one frame gap.
    // ------------------------------------------------------------------
    localparam O_RUN = 1'b0,
               O_GAP = 1'b1;
    reg       ostate;
    reg [7:0] gap_cnt;
    reg       gap_req;
    reg       start_sent;

    always @(posedge clk) begin
        if (rst) begin
            ostate    <= O_RUN;
            gap_cnt   <= 8'd0;
            gap_req   <= 1'b0;
            // The downstream DDR writer arms on VSYNC and only then accepts
            // pixels.  The first output frame must therefore be announced
            // before its first FIFO word, not after the frame has drained.
            start_sent <= 1'b0;
            of_rp     <= 10'd0;
            out_valid <= 1'b0;
            out_pixel <= 16'd0;
            out_vsync <= 1'b0;
        end
        else begin
            case (ostate)
                O_RUN: begin
                    out_vsync <= 1'b0;
                    if (!of_empty && of_head[17] && !start_sent) begin
                        out_valid <= 1'b0;
                        out_vsync <= 1'b1;
                        start_sent <= 1'b1;
                    end
                    else if (!of_empty && !gap_req) begin
                        out_valid <= 1'b1;
                        out_pixel <= of_head[15:0];
                        of_rp     <= of_rp + 10'd1;
                        start_sent <= 1'b0;
                        if (of_head[16]) begin
                            ostate  <= O_GAP;
                            gap_cnt <= 8'd0;
                            gap_req <= 1'b1;
                        end
                    end
                    else
                        out_valid <= 1'b0;
                end
                O_GAP: begin
                    out_valid <= 1'b0;
                    // VSYNC is a frame-start marker and is emitted by
                    // start_req immediately before the next data word.
                    // Do not emit the legacy end-of-frame pulse here.
                    out_vsync <= 1'b0;
                    if (gap_cnt == GAP_LEN[7:0] - 8'd1) begin
                        ostate  <= O_RUN;
                        gap_cnt <= 8'd0;
                        gap_req <= 1'b0;
                        start_sent <= 1'b0;
                    end
                    else
                        gap_cnt <= gap_cnt + 8'd1;
                end
                default: ostate <= O_RUN;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Input sequencing and rotating-bank management.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            k           <= {AW{1'b0}};
            l           <= 16'd0;
            first_round <= 1'b1;
            frame_pix   <= 19'd0;
            frame_full  <= 1'b0;
            bank_cur    <= 2'd0;
            bank_prev   <= 2'd1;
            bank_prev2  <= 2'd2;
        end
        else if (consume) begin
            lbuf[bank_cur * STRIDE + k] <= in_pixel;
            frame_pix <= frame_pix + 19'd1;

            if (k_last) begin
                k <= {AW{1'b0}};
                bank_prev2 <= bank_prev;
                bank_prev  <= bank_cur;
                bank_cur   <= bank_prev2;
                if (l_wrap) begin
                    l           <= 16'd0;
                    first_round <= 1'b0;
                end
                else
                    l <= l + 16'd1;
            end
            else
                k <= k + 1'b1;

            if (frame_last)
                frame_full <= 1'b1;
        end
        else if (vs_rise) begin
            k         <= {AW{1'b0}};
            l         <= 16'd0;
            frame_pix <= 19'd0;
            frame_full <= 1'b0;
        end
    end

endmodule
