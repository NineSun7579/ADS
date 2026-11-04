// cam_fir2d.v -- 2D separable FIR for the camera RGB565 stream, tuned for the
// measured cam2 noise (horizontal correlation ~3px, sub-LSB temporal speckle).
//
//   horizontal: [1 6 15 20 15 6 1] / 64   (spans the 3px noise correlation)
//   vertical:   [1 6 15 20 15 6 1] / 64   (spans the 1-line vertical correlation)
//
// Noise analysis (noise_analysis_20261007): flat-area temporal flip rate
// 70.3% -> 54.3% (22.8% removal, 11x the old 3-tap kernel), strong-edge
// Sobel energy retained 33%. Cascaded rounding per stage, matching the
// golden model exactly:
//   h = round6(x[n]+6x[n-1]+..+x[n-6]) per R5/G6/B5, then
//   y = round6(h[n]+6h[n-1]+..+h[n-6]) per R5/G6/B5.
//
// Black-line fix (2026-10-08): missing window lines at startup or after a
// mid-stream reset fall back to the current h value (horizontal-only
// passthrough) instead of zero, so a reset can never darken output rows.
//
// Contract identical to cam_fir3: one output beat per input beat, taps shift
// only on valid beats (gap-robust within the DVP contract: de contiguous per
// line), single output register. Vertical history lives in 6 rotating line
// buffers (distributed RAM).
module cam_fir2d #(
    parameter DATA_WIDTH = 16,
    parameter LINE_PIX   = 640
)(
    input  wire                    clk,
    input  wire                    rst,

    input  wire                    in_valid,
    input  wire [DATA_WIDTH-1:0]   in_pixel,
    input  wire                    in_vsync,

    output reg                     out_valid,
    output reg  [DATA_WIDTH-1:0]   out_pixel,
    output reg                     out_vsync
);

    // ---------------- horizontal stage: 7 taps, shift on valid only ----------------
    reg [15:0] h1, h2, h3, h4, h5, h6;

    function [10:0] h5x(input [4:0] p0, input [4:0] p1, input [4:0] p2,
                        input [4:0] p3, input [4:0] p4, input [4:0] p5,
                        input [4:0] p6);
        // 1+6+15+20+15+6+1 = 64 taps sum; max 31*64 = 1984 fits 11 bits
        h5x = {6'b0, p0} + 6*p1 + 15*p2 + 20*p3 + 15*p4 + 6*p5 + {6'b0, p6};
    endfunction

    function [11:0] h6x(input [5:0] p0, input [5:0] p1, input [5:0] p2,
                        input [5:0] p3, input [5:0] p4, input [5:0] p5,
                        input [5:0] p6);
        // max 63*64 = 4032 fits 12 bits
        h6x = {6'b0, p0} + 6*p1 + 15*p2 + 20*p3 + 15*p4 + 6*p5 + {6'b0, p6};
    endfunction

    wire [4:0] hr = h5x(in_pixel[15:11], h1[15:11], h2[15:11], h3[15:11],
                        h4[15:11], h5[15:11], h6[15:11]) >> 6;
    wire [5:0] hg = h6x(in_pixel[10:5], h1[10:5], h2[10:5], h3[10:5],
                        h4[10:5], h5[10:5], h6[10:5]) >> 6;
    wire [4:0] hb = h5x(in_pixel[4:0], h1[4:0], h2[4:0], h3[4:0],
                        h4[4:0], h5[4:0], h6[4:0]) >> 6;
    wire [15:0] h_pix = {hr, hg, hb};

    // ---------------- vertical stage: 7 taps over 6 rotating line buffers ----------------
    reg [15:0] lb0 [0:LINE_PIX-1];
    reg [15:0] lb1 [0:LINE_PIX-1];
    reg [15:0] lb2 [0:LINE_PIX-1];
    reg [15:0] lb3 [0:LINE_PIX-1];
    reg [15:0] lb4 [0:LINE_PIX-1];
    reg [15:0] lb5 [0:LINE_PIX-1];
    reg [11:0] lines_done;      // full lines completed since reset (not cleared at vs)
    reg [2:0]  slot;            // slot of the line currently being written
    reg [11:0] x;

    reg in_valid_d;
    wire line_start = in_valid && !in_valid_d;
    wire line_end   = in_valid_d && !in_valid;
    // address of the pixel being consumed this edge: 0 at line start, else x
    wire [11:0] x_cur = line_start ? 12'd0 : x;

    // Slot layout while processing line y: slot(y%6) still holds line y-6
    // (read-before-write keeps the old value this cycle), slot(y-1)%6 holds
    // y-1, and so on. Modulo-6 offsets (3-bit wrap would be mod 8).
    function [2:0] slot_minus(input [2:0] s, input [2:0] k);
        slot_minus = (s >= k) ? (s - k) : (s + 3'd6 - k);
    endfunction

    wire [2:0] s_cur = slot;                       // y-6 slot (being overwritten by y)
    wire [2:0] s_p1 = slot_minus(slot, 3'd1);      // y-1
    wire [2:0] s_p2 = slot_minus(slot, 3'd2);      // y-2
    wire [2:0] s_p3 = slot_minus(slot, 3'd3);      // y-3
    wire [2:0] s_p4 = slot_minus(slot, 3'd4);      // y-4
    wire [2:0] s_p5 = slot_minus(slot, 3'd5);      // y-5

    reg [15:0] v_cur, v_p1, v_p2, v_p3, v_p4, v_p5, v_p6;

    always @(*) begin
        case (s_p1)
            3'd0: v_p1 = lb0[x_cur]; 3'd1: v_p1 = lb1[x_cur];
            3'd2: v_p1 = lb2[x_cur]; 3'd3: v_p1 = lb3[x_cur];
            3'd4: v_p1 = lb4[x_cur]; default: v_p1 = lb5[x_cur];
        endcase
        case (s_p2)
            3'd0: v_p2 = lb0[x_cur]; 3'd1: v_p2 = lb1[x_cur];
            3'd2: v_p2 = lb2[x_cur]; 3'd3: v_p2 = lb3[x_cur];
            3'd4: v_p2 = lb4[x_cur]; default: v_p2 = lb5[x_cur];
        endcase
        case (s_p3)
            3'd0: v_p3 = lb0[x_cur]; 3'd1: v_p3 = lb1[x_cur];
            3'd2: v_p3 = lb2[x_cur]; 3'd3: v_p3 = lb3[x_cur];
            3'd4: v_p3 = lb4[x_cur]; default: v_p3 = lb5[x_cur];
        endcase
        case (s_p4)
            3'd0: v_p4 = lb0[x_cur]; 3'd1: v_p4 = lb1[x_cur];
            3'd2: v_p4 = lb2[x_cur]; 3'd3: v_p4 = lb3[x_cur];
            3'd4: v_p4 = lb4[x_cur]; default: v_p4 = lb5[x_cur];
        endcase
        case (s_p5)
            3'd0: v_p5 = lb0[x_cur]; 3'd1: v_p5 = lb1[x_cur];
            3'd2: v_p5 = lb2[x_cur]; 3'd3: v_p5 = lb3[x_cur];
            3'd4: v_p5 = lb4[x_cur]; default: v_p5 = lb5[x_cur];
        endcase
        case (s_cur)
            3'd0: v_p6 = lb0[x_cur]; 3'd1: v_p6 = lb1[x_cur];
            3'd2: v_p6 = lb2[x_cur]; 3'd3: v_p6 = lb3[x_cur];
            3'd4: v_p6 = lb4[x_cur]; default: v_p6 = lb5[x_cur];
        endcase
        v_cur = h_pix;
    end

    // Missing window lines (before enough lines completed after reset) fall
    // back to the current h value: horizontal-only passthrough, never dark.
    wire [15:0] z_p1 = (lines_done >= 12'd1) ? v_p1 : v_cur;
    wire [15:0] z_p2 = (lines_done >= 12'd2) ? v_p2 : v_cur;
    wire [15:0] z_p3 = (lines_done >= 12'd3) ? v_p3 : v_cur;
    wire [15:0] z_p4 = (lines_done >= 12'd4) ? v_p4 : v_cur;
    wire [15:0] z_p5 = (lines_done >= 12'd5) ? v_p5 : v_cur;
    wire [15:0] z_p6 = (lines_done >= 12'd6) ? v_p6 : v_cur;

    function [10:0] v5x(input [4:0] p0, input [4:0] p1, input [4:0] p2,
                        input [4:0] p3, input [4:0] p4, input [4:0] p5,
                        input [4:0] p6);
        // 1+6+15+20+15+6+1 = 64 taps sum; max 31*64 = 1984 fits 11 bits
        v5x = {6'b0, p0} + 6*p1 + 15*p2 + 20*p3 + 15*p4 + 6*p5 + {6'b0, p6};
    endfunction

    function [11:0] v6x(input [5:0] p0, input [5:0] p1, input [5:0] p2,
                        input [5:0] p3, input [5:0] p4, input [5:0] p5,
                        input [5:0] p6);
        // max 63*64 = 4032 fits 12 bits
        v6x = {6'b0, p0} + 6*p1 + 15*p2 + 20*p3 + 15*p4 + 6*p5 + {6'b0, p6};
    endfunction

    wire [4:0] vr = v5x(v_cur[15:11], z_p1[15:11], z_p2[15:11], z_p3[15:11],
                        z_p4[15:11], z_p5[15:11], z_p6[15:11]) >> 6;
    wire [5:0] vg = v6x(v_cur[10:5], z_p1[10:5], z_p2[10:5], z_p3[10:5],
                        z_p4[10:5], z_p5[10:5], z_p6[10:5]) >> 6;
    wire [4:0] vb = v5x(v_cur[4:0], z_p1[4:0], z_p2[4:0], z_p3[4:0],
                        z_p4[4:0], z_p5[4:0], z_p6[4:0]) >> 6;
    wire [15:0] y_pix = {vr, vg, vb};

    // ---------------- stream bookkeeping (valid-gated, gap-robust) ----------------
    always @(posedge clk) begin
        if (rst) begin
            h1 <= 16'h0; h2 <= 16'h0; h3 <= 16'h0;
            h4 <= 16'h0; h5 <= 16'h0; h6 <= 16'h0;
            lines_done <= 12'd0;
            slot <= 3'd0;
            x <= 12'd0;
            in_valid_d <= 1'b0;
            out_valid <= 1'b0;
            out_vsync <= 1'b0;
            out_pixel <= 16'h0;
        end
        else begin
            in_valid_d <= in_valid;
            out_valid <= in_valid;
            out_vsync <= in_vsync;
            out_pixel <= y_pix;

            if (in_valid) begin
                h1 <= in_pixel; h2 <= h1; h3 <= h2;
                h4 <= h3; h5 <= h4; h6 <= h5;
                // write this line's h-filtered value; the y-6 slot read above
                // consumed the old content in this same cycle
                case (slot)
                    3'd0: lb0[x_cur] <= h_pix;
                    3'd1: lb1[x_cur] <= h_pix;
                    3'd2: lb2[x_cur] <= h_pix;
                    3'd3: lb3[x_cur] <= h_pix;
                    3'd4: lb4[x_cur] <= h_pix;
                    default: lb5[x_cur] <= h_pix;
                endcase
            end

            if (in_valid) x <= x_cur + 12'd1;

            // rotate to the next line slot after the last pixel of a line
            if (line_end) begin
                slot <= (slot == 3'd5) ? 3'd0 : slot + 3'd1;
                lines_done <= lines_done + 12'd1;
            end

            if (in_vsync) begin
                slot <= 3'd0;
                x <= 12'd0;
            end
        end
    end

endmodule
