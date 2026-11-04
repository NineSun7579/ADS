// Bottom 640x360 lane ROI. White-run candidates -> Q16 x(y) fit -> overlay.
// The two divisions per side use one shared official Pango Radix2 IP through
// lane_divider. enable=0 is an exact pixel/timing bypass.
// src_height selects the frame height at run time (the ROI is always the
// bottom ROI_HEIGHT rows). The fit starts once the frame's last ROI row has
// drained and publishes rec_data/rec_valid for that same frame, so the frame
// writer can attach it to that frame's commit tag (see LANE_REC below).
// LANE_REC (96 bit): [3:0] version 1, [4] present, [5] left valid, [6] right
// valid, [18:8] ROI first row, [30:20]/[41:31] left x at ROI top/bottom row,
// [52:42]/[63:53] right x at ROI top/bottom row (signed, ROI-relative),
// [71:64]/[79:72] left/right candidate rows (saturated), [95:80] sequence.
module lane_roi_overlay #(
    parameter integer CHANNEL_ID = 0,
    parameter integer SRC_WIDTH = 640,
    parameter integer SRC_HEIGHT = 480,
    parameter integer ROI_X = 0,
    parameter integer ROI_Y = 120,
    parameter integer ROI_WIDTH = 640,
    parameter integer ROI_HEIGHT = 360,
    parameter integer MAX_RUN = 80,
    parameter integer HDMI_SEAM = 0
) (
    input wire clk, input wire rst_n, input wire enable,
    input wire [11:0] src_height,
    output reg rec_valid, output reg [95:0] rec_data,
    input wire [7:0] white_min, input wire [7:0] white_span,
    input wire [7:0] min_run, input wire [3:0] line_width,
    input wire [15:0] s_rgb565, input wire s_de, input wire s_hs, input wire s_vs,
    output wire [15:0] m_rgb565, output wire m_de, output wire m_hs, output wire m_vs,
    output reg [15:0] frame_left_count, output reg [15:0] frame_right_count,
    output reg [31:0] frame_sequence,
    output wire model_left_valid, output wire model_right_valid,
    output wire div_req_valid, input wire div_req_ready,
    output wire [63:0] div_req_dividend, output wire [63:0] div_req_divisor,
    input wire div_rsp_valid, input wire [127:0] div_rsp_data
);
    localparam integer HALF_WIDTH = ROI_WIDTH / 2;
    // Local reset: asserted asynchronously, released after two clk edges.
    // rst_n comes from DDR dfi_init_complete across the die; driving every
    // register and APM reset pin from it directly failed recovery timing.
    (* syn_preserve=1 *) reg [1:0] rst_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) rst_sync <= 2'b00;
        else rst_sync <= {rst_sync[0], 1'b1};
    wire rst_n_i = rst_sync[1];
    // Run-time geometry, registered so the compares see a static register.
    reg [11:0] roi_base, last_row;
    always @(posedge clk or negedge rst_n_i)
        if (!rst_n_i) begin roi_base <= ROI_Y; last_row <= SRC_HEIGHT-1; end
        else begin
            roi_base <= src_height > ROI_HEIGHT ? src_height-ROI_HEIGHT : 12'd0;
            last_row <= src_height-1'b1;
        end
    assign m_de = s_de;
    assign m_hs = s_hs;
    assign m_vs = s_vs;

    reg [11:0] pixel_x, pixel_y;
    reg vs_q;
    wire frame_start = s_vs && !vs_q;
    // Last ROI pixel of the frame; snap fires after the row/statistics
    // pipeline (<10 clocks) has drained into the accumulators.
    wire frame_end = s_de && pixel_x == SRC_WIDTH-1 && pixel_y == last_row;
    reg [15:0] snap_pipe;
    wire snap = snap_pipe[15];
    reg [2:0] stats_frame_start_pipe;
    wire stats_frame_start = stats_frame_start_pipe[2];
    reg stats_publish_pending;
    reg stats_tail_seen;
    wire [7:0] red = {s_rgb565[15:11],s_rgb565[15:13]};
    wire [7:0] green = {s_rgb565[10:5],s_rgb565[10:9]};
    wire [7:0] blue = {s_rgb565[4:0],s_rgb565[4:2]};
    wire [7:0] cmax = red >= green && red >= blue ? red : (green >= blue ? green : blue);
    wire [7:0] cmin = red <= green && red <= blue ? red : (green <= blue ? green : blue);
    wire white_pixel = cmin >= white_min && (cmax-cmin) <= white_span;
    wire [11:0] roi_x = pixel_x-ROI_X, roi_y = pixel_y-roi_base;
    // ROI/border position flags are registered from the next pixel_x/pixel_y
    // (same update rule as the counters below), so each flag always equals
    // its old combinational value while keeping the 12-bit compares off the
    // pixel_y -> m_rgb565 -> DDR write-data path.
    wire [11:0] pixel_x_nx = frame_start ? 12'd0 :
                             !s_de ? pixel_x : (pixel_x == SRC_WIDTH-1 ? 12'd0 : pixel_x+1'b1);
    wire [11:0] pixel_y_nx = frame_start ? 12'd0 :
                             !(s_de && pixel_x == SRC_WIDTH-1) ? pixel_y :
                             (pixel_y == last_row ? 12'd0 : pixel_y+1'b1);
    function x_in_f(input [11:0] x); x_in_f = x >= ROI_X && x < ROI_X+ROI_WIDTH; endfunction
    function y_in_f(input [11:0] y); y_in_f = y >= roi_base && y <= last_row; endfunction
    function x_edge_f(input [11:0] x);
        x_edge_f = (x-ROI_X) == 0 || (x-ROI_X) == ROI_WIDTH-1 ||
                   (HDMI_SEAM != 0 && (x-ROI_X) == HALF_WIDTH);
    endfunction
    function y_edge_f(input [11:0] y); y_edge_f = y == roi_base || y == last_row; endfunction
    reg x_in_q, y_in_q, x_edge_q, y_edge_q;
    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            x_in_q <= x_in_f(12'd0); y_in_q <= 1'b0;
            x_edge_q <= x_edge_f(12'd0); y_edge_q <= 1'b0;
        end else begin
            x_in_q <= x_in_f(pixel_x_nx); y_in_q <= y_in_f(pixel_y_nx);
            x_edge_q <= x_edge_f(pixel_x_nx); y_edge_q <= y_edge_f(pixel_y_nx);
        end
    end
    wire in_roi = s_de && x_in_q && y_in_q;
    wire [11:0] roi_x_q = roi_x-1'b1;
    reg white_pixel_q, in_left_q, in_right_q;
    reg [11:0] roi_x_stats_q, roi_y_stats_q;
    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            white_pixel_q <= 0; in_left_q <= 0; in_right_q <= 0;
            roi_x_stats_q <= 0; roi_y_stats_q <= 0;
        end else begin
            white_pixel_q <= white_pixel;
            in_left_q <= in_roi && roi_x < HALF_WIDTH;
            in_right_q <= in_roi && roi_x >= HALF_WIDTH;
            roi_x_stats_q <= roi_x;
            roi_y_stats_q <= roi_y;
        end
    end

    (* syn_maxfan = 8 *) reg [11:0] left_start, left_len, left_best_start, left_best_len;
    (* syn_maxfan = 8 *) reg [11:0] right_start, right_len, right_best_start, right_best_len;
    reg [11:0] left_run_center, right_run_center;
    reg [11:0] left_best_center, right_best_center;
    wire left_end = in_left_q && (!white_pixel_q || roi_x_stats_q == HALF_WIDTH-1);
    wire right_end = in_right_q && (!white_pixel_q || roi_x_stats_q == ROI_WIDTH-1);
    wire [11:0] left_complete = left_len + (white_pixel_q ? 1'b1 : 1'b0);
    wire [11:0] right_complete = right_len + (white_pixel_q ? 1'b1 : 1'b0);
    // ROI boundaries always reset the run before row-end voting. Otherwise
    // the white lane crossing x=320 contaminates the right half.
    wire left_vote = left_end && left_complete >= left_best_len &&
                     left_complete >= min_run && left_complete <= MAX_RUN &&
                     left_start < HALF_WIDTH;
    wire right_vote = right_end && right_complete >= right_best_len &&
                      right_complete >= min_run && right_complete <= MAX_RUN &&
                      right_start >= HALF_WIDTH;
    wire [11:0] left_best_next = left_vote ? left_complete : left_best_len;
    wire [11:0] right_best_next = right_vote ? right_complete : right_best_len;
    wire [11:0] left_best_start_next = left_vote ? left_start : left_best_start;
    wire [11:0] right_best_start_next = right_vote ? right_start : right_best_start;
    wire left_row_vote = in_left_q && roi_x_stats_q == HALF_WIDTH-1 && left_best_next >= min_run;
    wire right_row_vote = in_right_q && roi_x_stats_q == ROI_WIDTH-1 && right_best_next >= min_run;
    // For a valid run (len>=1), floor((len-1)/2) = (len>>1)-!len[0].
    // This avoids a separate 12-bit decrement before the row-center adder.
    wire [11:0] left_center = left_vote ? left_run_center : left_best_center;
    wire [11:0] right_center = right_vote ? right_run_center : right_best_center;

    reg left_row_end_q, right_row_end_q;
    reg [11:0] left_best_start_q, left_best_len_q, right_best_start_q, right_best_len_q;
    reg left_row_vote_q, right_row_vote_q;
    reg [11:0] left_center_q, right_center_q, roi_y_q;
    reg left_row_done_q, right_row_done_q;
    reg [11:0] left_row_center_d, right_row_center_d;
    reg [11:0] left_row_y_d, right_row_y_d;
    reg left_mul_active, right_mul_active;
    reg [3:0] left_mul_bit, right_mul_bit;
    reg [11:0] left_mul_y, right_mul_y;
    reg [11:0] left_mul_center, right_mul_center;
    reg [23:0] left_mul_sxy, right_mul_sxy, left_mul_syy, right_mul_syy;
    reg left_mul_done, right_mul_done;
    reg left_mul_pending_q, right_mul_pending_q;
    reg [11:0] left_mul_y_q, right_mul_y_q, left_mul_center_q, right_mul_center_q;
    reg [17:0] left_sxy_pp0, left_sxy_pp1, left_sxy_pp2, left_sxy_pp3;
    reg [17:0] right_sxy_pp0, right_sxy_pp1, right_sxy_pp2, right_sxy_pp3;
    reg [17:0] left_syy_pp0, left_syy_pp1, left_syy_pp2, left_syy_pp3;
    reg [17:0] right_syy_pp0, right_syy_pp1, right_syy_pp2, right_syy_pp3;
    wire [23:0] left_sxy_product = left_sxy_pp0 + ((left_sxy_pp1+left_sxy_pp2)<<6) + (left_sxy_pp3<<12);
    wire [23:0] right_sxy_product = right_sxy_pp0 + ((right_sxy_pp1+right_sxy_pp2)<<6) + (right_sxy_pp3<<12);
    wire [23:0] left_syy_product = left_syy_pp0 + ((left_syy_pp1+left_syy_pp2)<<6) + (left_syy_pp3<<12);
    wire [23:0] right_syy_product = right_syy_pp0 + ((right_syy_pp1+right_syy_pp2)<<6) + (right_syy_pp3<<12);
    reg left_acc_pending_q, right_acc_pending_q;
    reg [11:0] left_acc_y_q, right_acc_y_q, left_acc_center_q, right_acc_center_q;
    reg [23:0] left_acc_sxy_q, right_acc_sxy_q, left_acc_syy_q, right_acc_syy_q;
    reg [15:0] left_n, right_n;
    reg [31:0] left_sx, left_sy, left_syy, left_sxy;
    reg [31:0] right_sx, right_sy, right_syy, right_sxy;
    reg [15:0] left_n_fit, right_n_fit;
    reg [31:0] left_sx_fit, left_sy_fit, left_syy_fit, left_sxy_fit;
    reg [31:0] right_sx_fit, right_sy_fit, right_syy_fit, right_sxy_fit;

    // Snapshot both sides at SOF, then fit left and right sequentially.
    reg fit_right, fit_left_done;
    // Multiplier operands stay in fabric: absorbed into APM input registers,
    // their enable/FSM load mux and async reset landed on APM X/Y and RST pins
    // (setup -0.14 ns, recovery -0.11 ns).
    (* syn_preserve=1 *) reg [15:0] fit_n;
    (* syn_preserve=1 *) reg [31:0] fit_sx, fit_sy, fit_syy, fit_sxy;
    reg signed [64:0] cov, variance;
    // variance_zero == (variance == 0), registered with variance so the
    // 65-bit compare is off the ST_SLOPE_START load-enable path.
    reg variance_zero;
    reg [47:0] cov_sxy_n, cov_sx_sy, var_syy_n, var_sy_sy;
    reg signed [63:0] intercept_num;
    (* syn_preserve=1 *) reg signed [31:0] slope_result;
    reg signed [64:0] slope_sy_product;
    // Fit products are formed from registered 16x16 partial products and
    // summed in later FSM states. Single-cycle 32x32 products (APM cascade
    // plus adder) missed the 7.619 ns ddrphy_sysclk period.
    reg [31:0] fit_pp_sxy_n_l, fit_pp_sxy_n_h, fit_pp_syy_n_l, fit_pp_syy_n_h;
    reg [31:0] fit_pp_sx_sy_ll, fit_pp_sx_sy_lh, fit_pp_sx_sy_hl, fit_pp_sx_sy_hh;
    reg [31:0] fit_pp_sy_sy_ll, fit_pp_sy_sy_lh, fit_pp_sy_sy_hh;
    reg [32:0] fit_mid_sx_sy;
    reg [31:0] sy_pp_ll, sy_pp_lh;
    reg signed [32:0] sy_pp_hl, sy_pp_hh;
    reg signed [33:0] sy_mid;
    reg [64:0] fit_covariance;
    (* syn_preserve=1 *) reg signed [31:0] fit_slope;
    reg div_start, div_negative;
    reg div_slope_start, div_intercept_start;
    reg [63:0] div_dividend, div_divisor;
    reg [63:0] div_quotient;
    reg div_done;
    assign div_req_valid = div_slope_start || div_intercept_start;
    assign div_req_dividend = div_dividend;
    assign div_req_divisor = div_divisor;
    // Iterative mode accepts operands only when both AXI ready outputs are
    // high. The fit states hold their request until that handshake; completion
    // is signalled by the official IP's output tvalid.
    reg div_result_pending;
    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            div_result_pending <= 0; div_done <= 0; div_quotient <= 0;
        end else begin
            div_done <= 0;
            if ((div_slope_start || div_intercept_start) &&
                div_req_ready)
                div_result_pending <= 1;
            if (div_result_pending && div_rsp_valid) begin
                div_result_pending <= 0;
                div_quotient <= div_rsp_data[127:64];
                div_done <= 1;
            end
        end
    end

    localparam ST_IDLE=0, ST_COV=1, ST_SLOPE_START=2, ST_SLOPE_WAIT=3,
               ST_INTERCEPT_CALC=4, ST_INTERCEPT_START=5, ST_INTERCEPT_WAIT=6,
               ST_RIGHT_CHECK=7, ST_INTERCEPT_PRODUCT=8, ST_PRODUCTS=9,
               ST_PRODUCTS_MID=10, ST_PRODUCTS_SUM=11,
               ST_INTERCEPT_MID=12, ST_INTERCEPT_SUM=13;
    reg [3:0] fit_state;
    reg pending_left_valid, pending_right_valid;
    reg signed [31:0] pending_left_slope, pending_right_slope;
    reg signed [31:0] pending_left_intercept, pending_right_intercept;
    reg display_left_valid, display_right_valid;
    (* syn_preserve=1 *) reg signed [31:0] display_left_slope, display_right_slope;
    reg signed [31:0] display_left_intercept, display_right_intercept;
    assign model_left_valid = display_left_valid;
    assign model_right_valid = display_right_valid;

    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            fit_state <= ST_IDLE; fit_right <= 0; fit_left_done <= 0;
            fit_n <= 0; fit_sx <= 0; fit_sy <= 0; fit_syy <= 0; fit_sxy <= 0;
            fit_covariance <= 0; fit_slope <= 0;
            slope_result <= 0;
            div_start <= 0; div_slope_start <= 0; div_intercept_start <= 0;
            div_negative <= 0;
            div_dividend <= 0; div_divisor <= 0;
            pending_left_valid <= 0; pending_right_valid <= 0;
            pending_left_slope <= 0; pending_right_slope <= 0;
            pending_left_intercept <= 0; pending_right_intercept <= 0;
        end else begin
            div_start <= 0;
            if (div_req_ready) begin
                div_slope_start <= 0;
                div_intercept_start <= 0;
            end
            if (snap) begin
                fit_state <= ST_IDLE;
                if (!enable || left_n < 16) pending_left_valid <= 0;
                if (!enable || right_n < 16) pending_right_valid <= 0;
                left_n_fit <= left_n; left_sx_fit <= left_sx; left_sy_fit <= left_sy;
                left_syy_fit <= left_syy; left_sxy_fit <= left_sxy;
                right_n_fit <= right_n; right_sx_fit <= right_sx; right_sy_fit <= right_sy;
                right_syy_fit <= right_syy; right_sxy_fit <= right_sxy;
                fit_left_done <= 0;
            end else begin
                case (fit_state)
                    ST_IDLE: begin
                        if (enable && !fit_left_done && left_n_fit >= 16) begin
                            fit_right <= 0; fit_n <= left_n_fit; fit_sx <= left_sx_fit;
                            fit_sy <= left_sy_fit; fit_syy <= left_syy_fit; fit_sxy <= left_sxy_fit;
                            fit_state <= ST_PRODUCTS;
                        end else if (enable && !fit_left_done && right_n_fit >= 16) begin
                            fit_right <= 1; fit_n <= right_n_fit; fit_sx <= right_sx_fit;
                            fit_sy <= right_sy_fit; fit_syy <= right_syy_fit; fit_sxy <= right_sxy_fit;
                            fit_state <= ST_PRODUCTS;
                        end
                    end
                    ST_PRODUCTS: begin
                        // fit_pp_* capture here (reset-free block above):
                        // a*b = aL*bL + ((aL*bH + aH*bL) << 16) + (aH*bH << 32),
                        // truncated to the 48-bit product registers as before.
                        fit_state <= ST_PRODUCTS_MID;
                    end
                    // Datapath for MID/SUM/COV is in the fit-datapath block.
                    ST_PRODUCTS_MID: fit_state <= ST_PRODUCTS_SUM;
                    ST_PRODUCTS_SUM: fit_state <= ST_COV;
                    ST_COV: fit_state <= ST_SLOPE_START;
                    ST_SLOPE_START: begin
                        fit_covariance <= cov[64] ? -cov : cov;
                        div_negative <= cov[64];
                        if (variance_zero) begin
                            if (fit_right) pending_right_valid <= 0;
                            else pending_left_valid <= 0;
                            fit_state <= ST_RIGHT_CHECK;
                        end else begin
                            div_dividend <= (cov[64] ? -cov : cov) <<< 16;
                            div_divisor <= variance;
                            div_slope_start <= 1; fit_state <= ST_SLOPE_WAIT;
                        end
                    end
                    ST_SLOPE_WAIT: if (div_done) begin
                        fit_slope <= div_negative ? -$signed(div_quotient) : $signed(div_quotient);
                        slope_result <= div_negative ? -$signed(div_quotient) : $signed(div_quotient);
                        fit_state <= ST_INTERCEPT_PRODUCT;
                    end
                    ST_INTERCEPT_PRODUCT: begin
                        // Q16 slope*sy from registered partial products. The
                        // single-cycle APM cascade into slope_sy_product failed
                        // setup, as did the earlier quotient->multiply path.
                        // slope = sH<<16 + sL (sH signed), sy = yH<<16 + yL;
                        // sy_pp_* capture here (reset-free block above).
                        fit_state <= ST_INTERCEPT_MID;
                    end
                    ST_INTERCEPT_MID: fit_state <= ST_INTERCEPT_SUM;
                    ST_INTERCEPT_SUM: fit_state <= ST_INTERCEPT_CALC;
                    ST_INTERCEPT_CALC: fit_state <= ST_INTERCEPT_START;
                    ST_INTERCEPT_START: begin
                        div_dividend <= intercept_num[63] ? -intercept_num : intercept_num;
                        div_divisor <= fit_n; div_negative <= intercept_num[63];
                        div_intercept_start <= 1; fit_state <= ST_INTERCEPT_WAIT;
                    end
                    ST_INTERCEPT_WAIT: if (div_done) begin
                        if (fit_right) begin
                            pending_right_slope <= fit_slope;
                            pending_right_intercept <= div_negative ? -$signed(div_quotient) : $signed(div_quotient);
                            pending_right_valid <= 1;
                        end else begin
                            pending_left_slope <= fit_slope;
                            pending_left_intercept <= div_negative ? -$signed(div_quotient) : $signed(div_quotient);
                            pending_left_valid <= 1;
                        end
                        fit_state <= ST_RIGHT_CHECK;
                    end
                    ST_RIGHT_CHECK: begin
                        if (!fit_right && right_n_fit >= 16) begin
                            fit_right <= 1; fit_n <= right_n_fit; fit_sx <= right_sx_fit;
                            fit_sy <= right_sy_fit; fit_syy <= right_syy_fit; fit_sxy <= right_sxy_fit;
                            fit_state <= ST_PRODUCTS;
                        end else begin
                            fit_left_done <= 1;
                            fit_state <= ST_IDLE;
                        end
                    end
                    default: fit_state <= ST_IDLE;
                endcase
            end
        end
    end

    // Fit datapath registers are enabled by fit_state alone, not by
    // frame_start: VSYNC -> frame_start -> FSM-gated CE failed setup. Each
    // register is only read in the state that follows its own, which the FSM
    // reaches only through it, so an extra update while frame_start sends the
    // FSM to IDLE is never observed.
    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            fit_mid_sx_sy <= 0; sy_mid <= 0;
            cov_sxy_n <= 0; cov_sx_sy <= 0; var_syy_n <= 0; var_sy_sy <= 0;
            cov <= 0; variance <= 0; variance_zero <= 1'b1; slope_sy_product <= 0; intercept_num <= 0;
        end else begin
            case (fit_state)
                ST_PRODUCTS_MID: fit_mid_sx_sy <= fit_pp_sx_sy_lh + fit_pp_sx_sy_hl;
                ST_PRODUCTS_SUM: begin
                    // ll and hh<<32 do not overlap, so they concatenate.
                    cov_sxy_n <= {16'd0, fit_pp_sxy_n_l} + {fit_pp_sxy_n_h, 16'd0};
                    var_syy_n <= {16'd0, fit_pp_syy_n_l} + {fit_pp_syy_n_h, 16'd0};
                    cov_sx_sy <= {fit_pp_sx_sy_hh[15:0], fit_pp_sx_sy_ll} + {fit_mid_sx_sy[31:0], 16'd0};
                    var_sy_sy <= {fit_pp_sy_sy_hh[15:0], fit_pp_sy_sy_ll} + {fit_pp_sy_sy_lh[30:0], 17'd0};
                end
                ST_COV: begin
                    // Accumulators are unsigned pixel sums. Treating a
                    // sum above 2^31 as signed corrupts the covariance.
                    cov <= $signed({1'b0,cov_sxy_n})-$signed({1'b0,cov_sx_sy});
                    variance <= $signed({1'b0,var_syy_n})-$signed({1'b0,var_sy_sy});
                    variance_zero <= (var_syy_n == var_sy_sy);
                end
                ST_INTERCEPT_MID: sy_mid <= $signed({2'b00,sy_pp_lh}) + $signed({sy_pp_hl[32],sy_pp_hl});
                ST_INTERCEPT_SUM: slope_sy_product <= $signed({sy_pp_hh,sy_pp_ll}) +
                                                      ($signed({{31{sy_mid[33]}},sy_mid}) <<< 16);
                ST_INTERCEPT_CALC: intercept_num <= $signed({1'b0,fit_sx})-($signed(slope_sy_product)>>>16);
                default: ;
            endcase
        end
    end

    // APM partial products carry no reset (reset pins on the multiplier
    // registers failed recovery). They are written in the same cycles as the
    // FSM states that own them and only read in the following states.
    always @(posedge clk) begin
        if (fit_state == ST_PRODUCTS) begin
            fit_pp_sxy_n_l <= fit_sxy[15:0] * fit_n;
            fit_pp_sxy_n_h <= fit_sxy[31:16] * fit_n;
            fit_pp_syy_n_l <= fit_syy[15:0] * fit_n;
            fit_pp_syy_n_h <= fit_syy[31:16] * fit_n;
            fit_pp_sx_sy_ll <= fit_sx[15:0] * fit_sy[15:0];
            fit_pp_sx_sy_lh <= fit_sx[15:0] * fit_sy[31:16];
            fit_pp_sx_sy_hl <= fit_sx[31:16] * fit_sy[15:0];
            fit_pp_sx_sy_hh <= fit_sx[31:16] * fit_sy[31:16];
            fit_pp_sy_sy_ll <= fit_sy[15:0] * fit_sy[15:0];
            fit_pp_sy_sy_lh <= fit_sy[15:0] * fit_sy[31:16];
            fit_pp_sy_sy_hh <= fit_sy[31:16] * fit_sy[31:16];
        end
        if (fit_state == ST_INTERCEPT_PRODUCT) begin
            sy_pp_ll <= slope_result[15:0] * fit_sy[15:0];
            sy_pp_lh <= slope_result[15:0] * fit_sy[31:16];
            sy_pp_hl <= $signed(slope_result[31:16]) * $signed({1'b0,fit_sy[15:0]});
            sy_pp_hh <= $signed(slope_result[31:16]) * $signed({1'b0,fit_sy[31:16]});
        end
    end

    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            pixel_x <= 0; pixel_y <= 0; vs_q <= 0;
            stats_frame_start_pipe <= 0; snap_pipe <= 0;
            left_start <= 0; left_len <= 0; left_best_start <= 0; left_best_len <= 0;
            right_start <= 0; right_len <= 0; right_best_start <= 0; right_best_len <= 0;
            left_run_center <= 0; right_run_center <= 0;
            left_best_center <= 0; right_best_center <= 0;
            left_acc_pending_q <= 0; right_acc_pending_q <= 0;
            left_acc_y_q <= 0; right_acc_y_q <= 0; left_acc_center_q <= 0; right_acc_center_q <= 0;
            left_acc_sxy_q <= 0; right_acc_sxy_q <= 0; left_acc_syy_q <= 0; right_acc_syy_q <= 0;
            left_mul_pending_q <= 0; right_mul_pending_q <= 0;
            left_mul_y_q <= 0; right_mul_y_q <= 0; left_mul_center_q <= 0; right_mul_center_q <= 0;
            left_sxy_pp0 <= 0; left_sxy_pp1 <= 0; left_sxy_pp2 <= 0; left_sxy_pp3 <= 0;
            right_sxy_pp0 <= 0; right_sxy_pp1 <= 0; right_sxy_pp2 <= 0; right_sxy_pp3 <= 0;
            left_syy_pp0 <= 0; left_syy_pp1 <= 0; left_syy_pp2 <= 0; left_syy_pp3 <= 0;
            right_syy_pp0 <= 0; right_syy_pp1 <= 0; right_syy_pp2 <= 0; right_syy_pp3 <= 0;
            left_n <= 0; right_n <= 0; left_sx <= 0; left_sy <= 0; left_syy <= 0; left_sxy <= 0;
            right_sx <= 0; right_sy <= 0; right_syy <= 0; right_sxy <= 0;
            stats_publish_pending <= 0;
            stats_tail_seen <= 0;
            left_row_end_q <= 0; right_row_end_q <= 0;
            left_best_start_q <= 0; left_best_len_q <= 0;
            right_best_start_q <= 0; right_best_len_q <= 0;
            left_row_vote_q <= 0; right_row_vote_q <= 0;
            left_center_q <= 0; right_center_q <= 0; roi_y_q <= 0;
            frame_left_count <= 0; frame_right_count <= 0; frame_sequence <= 0;
            display_left_valid <= 0; display_right_valid <= 0;
            display_left_slope <= 0; display_right_slope <= 0;
            display_left_intercept <= 0; display_right_intercept <= 0;
        end else begin
            vs_q <= s_vs;
            // Row candidates are registered before the statistical multiply/add.
            // This breaks pixel classification -> run center -> SXY accumulation.
            left_row_done_q <= left_row_vote;
            right_row_done_q <= right_row_vote;
            if (in_left_q && roi_x_stats_q == HALF_WIDTH-1) begin
                left_row_center_d <= left_center;
                left_row_y_d <= roi_y_stats_q;
            end
            if (in_right_q && roi_x_stats_q == ROI_WIDTH-1) begin
                right_row_center_d <= right_center;
                right_row_y_d <= roi_y_stats_q;
            end
            left_row_vote_q <= enable && left_row_done_q;
            right_row_vote_q <= enable && right_row_done_q;
            left_center_q <= left_row_center_d;
            right_center_q <= right_row_center_d;
            roi_y_q <= left_row_y_d;
            left_acc_pending_q <= left_mul_pending_q;
            right_acc_pending_q <= right_mul_pending_q;
            left_acc_y_q <= left_mul_y_q;
            right_acc_y_q <= right_mul_y_q;
            left_acc_center_q <= left_mul_center_q;
            right_acc_center_q <= right_mul_center_q;
            left_acc_sxy_q <= left_sxy_product;
            right_acc_sxy_q <= right_sxy_product;
            left_acc_syy_q <= left_syy_product;
            right_acc_syy_q <= right_syy_product;
            left_mul_pending_q <= left_row_vote_q;
            right_mul_pending_q <= right_row_vote_q;
            left_mul_y_q <= roi_y_q;
            right_mul_y_q <= left_row_y_d;
            left_mul_center_q <= left_center_q;
            right_mul_center_q <= right_center_q;
            left_sxy_pp0 <= roi_y_q[5:0] * left_center_q[5:0];
            left_sxy_pp1 <= roi_y_q[5:0] * left_center_q[11:6];
            left_sxy_pp2 <= roi_y_q[11:6] * left_center_q[5:0];
            left_sxy_pp3 <= roi_y_q[11:6] * left_center_q[11:6];
            right_sxy_pp0 <= left_row_y_d[5:0] * right_center_q[5:0];
            right_sxy_pp1 <= left_row_y_d[5:0] * right_center_q[11:6];
            right_sxy_pp2 <= left_row_y_d[11:6] * right_center_q[5:0];
            right_sxy_pp3 <= left_row_y_d[11:6] * right_center_q[11:6];
            left_syy_pp0 <= roi_y_q[5:0] * roi_y_q[5:0];
            left_syy_pp1 <= roi_y_q[5:0] * roi_y_q[11:6];
            left_syy_pp2 <= roi_y_q[11:6] * roi_y_q[5:0];
            left_syy_pp3 <= roi_y_q[11:6] * roi_y_q[11:6];
            right_syy_pp0 <= left_row_y_d[5:0] * left_row_y_d[5:0];
            right_syy_pp1 <= left_row_y_d[5:0] * left_row_y_d[11:6];
            right_syy_pp2 <= left_row_y_d[11:6] * left_row_y_d[5:0];
            right_syy_pp3 <= left_row_y_d[11:6] * left_row_y_d[11:6];
            if (in_left_q && white_pixel_q && left_start < HALF_WIDTH)
                left_run_center <= left_start + (left_len>>1);
            if (in_right_q && white_pixel_q && right_start >= HALF_WIDTH)
                right_run_center <= right_start + (right_len>>1);
            if (left_vote) left_best_center <= left_run_center;
            if (right_vote) right_best_center <= right_run_center;
            left_len <= in_left_q && white_pixel_q && left_start < HALF_WIDTH ? left_len+1'b1 : 0;
            left_start <= in_left_q && white_pixel_q && left_len == 0 ? roi_x_stats_q :
                          (!in_left_q || !white_pixel_q ? 0 : left_start);
            left_best_len <= left_best_next; left_best_start <= left_best_start_next;
            right_len <= in_right_q && white_pixel_q && right_start >= HALF_WIDTH ? right_len+1'b1 : 0;
            right_start <= in_right_q && white_pixel_q && right_len == 0 ? roi_x_stats_q :
                           (!in_right_q || !white_pixel_q ? 0 : right_start);
            right_best_len <= right_best_next; right_best_start <= right_best_start_next;
            if (s_de) begin
                if (pixel_x == SRC_WIDTH-1) begin
                    pixel_x <= 0;
                    pixel_y <= pixel_y == last_row ? 0 : pixel_y+1'b1;
                end else pixel_x <= pixel_x+1'b1;
            end
            snap_pipe <= {snap_pipe[14:0], frame_end && !frame_start};
            if (frame_start) begin
                pixel_x <= 0; pixel_y <= 0;
                // A truncated frame never published: drop its partial sums.
                left_row_vote_q <= 0; right_row_vote_q <= 0;
                left_n <= 0; right_n <= 0; left_sx <= 0; left_sy <= 0; left_syy <= 0; left_sxy <= 0;
                right_sx <= 0; right_sy <= 0; right_syy <= 0; right_sxy <= 0;
            end else if (snap) begin
                frame_left_count <= left_n + ((left_row_vote_q || left_row_done_q || left_mul_pending_q || left_acc_pending_q) ? 1'b1 : 1'b0);
                frame_right_count <= right_n + ((right_row_vote_q || right_row_done_q || right_mul_pending_q || right_acc_pending_q) ? 1'b1 : 1'b0);
                frame_sequence <= frame_sequence+1'b1;
                left_row_vote_q <= 0; right_row_vote_q <= 0;
                left_n <= 0; right_n <= 0; left_sx <= 0; left_sy <= 0; left_syy <= 0; left_sxy <= 0;
                right_sx <= 0; right_sy <= 0; right_syy <= 0; right_sxy <= 0;
                display_left_valid <= pending_left_valid && enable;
                display_right_valid <= pending_right_valid && enable;
                display_left_slope <= pending_left_slope; display_right_slope <= pending_right_slope;
                display_left_intercept <= pending_left_intercept;
                display_right_intercept <= pending_right_intercept;
            end else if (enable) begin
                if (left_acc_pending_q) begin
                    left_n <= left_n+1'b1; left_sx <= left_sx+left_acc_center_q;
                    left_sy <= left_sy+left_acc_y_q; left_syy <= left_syy+left_acc_syy_q;
                    left_sxy <= left_sxy+left_acc_sxy_q;
                end
                if (right_acc_pending_q) begin
                    right_n <= right_n+1'b1; right_sx <= right_sx+right_acc_center_q;
                    right_sy <= right_sy+right_acc_y_q; right_syy <= right_syy+right_acc_syy_q;
                    right_sxy <= right_sxy+right_acc_sxy_q;
                end
            end
        end
    end

    // ---- per-frame lane record (same frame as the pixels just written) ----
    reg rec_pending;
    reg [1:0] rec_stage;
    reg signed [43:0] left_p359, right_p359;
    reg signed [31:0] rec_left_top, rec_right_top, rec_left_bot, rec_right_bot;
    reg rec_left_valid, rec_right_valid;
    wire fit_finished = fit_state == ST_IDLE && !snap &&
        (fit_left_done || !enable || (left_n_fit < 16 && right_n_fit < 16));
    function [10:0] sat11(input signed [31:0] v);
        sat11 = v > 1023 ? 11'h3ff : v < -1024 ? 11'h400 : v[10:0];
    endfunction
    function [7:0] sat8(input [15:0] v); sat8 = v > 255 ? 8'hff : v[7:0]; endfunction
    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            rec_pending <= 0; rec_stage <= 0; rec_valid <= 0; rec_data <= 0;
            left_p359 <= 0; right_p359 <= 0; rec_left_valid <= 0; rec_right_valid <= 0;
            rec_left_top <= 0; rec_right_top <= 0; rec_left_bot <= 0; rec_right_bot <= 0;
        end else begin
            rec_valid <= 0;
            if (snap) begin rec_pending <= 1; rec_stage <= 0; end
            else if (rec_pending) begin
                case (rec_stage)
                    2'd0: if (fit_finished) begin
                        // x(359) = intercept + slope*359 >> 16, 359 = 256+64+32+4+2+1
                        left_p359 <= ($signed(pending_left_slope) <<< 8) + ($signed(pending_left_slope) <<< 6) +
                                     ($signed(pending_left_slope) <<< 5) + ($signed(pending_left_slope) <<< 2) +
                                     ($signed(pending_left_slope) <<< 1) + $signed(pending_left_slope);
                        right_p359 <= ($signed(pending_right_slope) <<< 8) + ($signed(pending_right_slope) <<< 6) +
                                      ($signed(pending_right_slope) <<< 5) + ($signed(pending_right_slope) <<< 2) +
                                      ($signed(pending_right_slope) <<< 1) + $signed(pending_right_slope);
                        rec_left_top <= pending_left_intercept; rec_right_top <= pending_right_intercept;
                        rec_left_valid <= pending_left_valid && enable;
                        rec_right_valid <= pending_right_valid && enable;
                        rec_stage <= 2'd1;
                    end
                    2'd1: begin
                        rec_left_bot <= rec_left_top + (left_p359 >>> 16);
                        rec_right_bot <= rec_right_top + (right_p359 >>> 16);
                        rec_stage <= 2'd2;
                    end
                    default: begin
                        rec_data <= {frame_sequence[15:0], sat8(frame_right_count), sat8(frame_left_count),
                                     sat11(rec_right_bot), sat11(rec_right_top),
                                     sat11(rec_left_bot), sat11(rec_left_top),
                                     1'b0, roi_base[10:0],
                                     1'b0, rec_right_valid, rec_left_valid, 1'b1, 4'd1};
                        rec_valid <= 1; rec_pending <= 0; rec_stage <= 0;
                    end
                endcase
            end
        end
    end

    reg signed [31:0] expected_left, expected_right;
    reg signed [63:0] expected_left_product, expected_right_product;
    wire signed [31:0] next_roi_y = $signed({1'b0,pixel_y})-$signed({1'b0,roi_base})+1;
    // slope*next_roi_y is computed by a free-running 3-stage pipeline and only
    // sampled at row end. Its inputs change only at row end (pixel_y) or
    // frame start (display slopes, pixel_x reset), each followed by at least
    // SRC_WIDTH clocks before the next row end, so the sampled value equals
    // the old same-cycle product. next_roi_y fits 14 bits for ROI_Y <= 4095.
    reg signed [13:0] row_y_q;
    reg signed [30:0] row_pp_left_l, row_pp_right_l;
    reg signed [29:0] row_pp_left_h, row_pp_right_h;
    reg signed [63:0] row_product_left, row_product_right;
    always @(posedge clk) begin
        begin
            row_y_q <= next_roi_y[13:0];
            row_pp_left_l <= $signed({1'b0,display_left_slope[15:0]}) * row_y_q;
            row_pp_right_l <= $signed({1'b0,display_right_slope[15:0]}) * row_y_q;
            row_pp_left_h <= $signed(display_left_slope[31:16]) * row_y_q;
            row_pp_right_h <= $signed(display_right_slope[31:16]) * row_y_q;
            row_product_left <= $signed({{33{row_pp_left_l[30]}},row_pp_left_l}) +
                                ($signed({{34{row_pp_left_h[29]}},row_pp_left_h}) <<< 16);
            row_product_right <= $signed({{33{row_pp_right_l[30]}},row_pp_right_l}) +
                                 ($signed({{34{row_pp_right_h[29]}},row_pp_right_h}) <<< 16);
        end
    end
    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            expected_left <= 0; expected_right <= 0;
            expected_left_product <= 0; expected_right_product <= 0;
        end else if (s_de && pixel_x == SRC_WIDTH-1) begin
            expected_left_product <= row_product_left;
            expected_right_product <= row_product_right;
        end else if (s_de && pixel_x == 0) begin
            expected_left <= display_left_intercept+($signed(expected_left_product)>>>16);
            expected_right <= display_right_intercept+($signed(expected_right_product)>>>16);
        end
    end
    wire signed [31:0] left_delta = $signed({1'b0,roi_x})-expected_left;
    wire signed [31:0] right_delta = $signed({1'b0,roi_x})-expected_right;
    wire [31:0] left_distance = left_delta < 0 ? -left_delta : left_delta;
    wire [31:0] right_distance = right_delta < 0 ? -right_delta : right_delta;
    wire draw_left = enable && display_left_valid && in_roi && left_distance <= line_width;
    wire draw_right = enable && display_right_valid && in_roi && right_distance <= line_width;
    wire border = in_roi && (y_edge_q || x_edge_q);
    // [LANE_REC] Results leave through rec_data; pixels are never modified.
    // The former overlay colours are kept only as an unused reference.
    wire [15:0] overlay_rgb565 = !enable ? s_rgb565 : draw_right ? 16'h07e0 :
                                 draw_left ? 16'hf800 : border ? 16'hffe0 : s_rgb565;
    assign m_rgb565 = s_rgb565;

    wire unused_ok = &{1'b0, div_start, SRC_HEIGHT[0], ROI_Y[0], 1'b0};
endmodule
