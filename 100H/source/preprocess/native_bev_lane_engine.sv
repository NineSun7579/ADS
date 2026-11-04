// Lean native HDMI BEV lane detector (100H, single AXI clock domain).
//
// Pass 1: every committed half is sampled through the signed-Q4 MATLAB LUT
//   (52250 samples). A 15-sample shift window gives a wide row-local ridge
//   test (3px centre vs 3px at +-5..7); results go to a 1-bit mask RAM.
// Pass 2: the mask is summed into 8 bands x 210 columns, smoothed (+-2), and
//   stored in a small histogram RAM.
// Pass 3: per side, the strongest band peak seeds a band-to-band track
//   (+-14 columns per band). The <=8 band peaks are fitted by least squares
//   col = a*u^2 + b*u + c (u = band-centre row - 104, col in Q4, Q8 coeffs).
// Pass 4: a multiplier-free walker samples the mask along the fit and a
//   counter-only classifier reports solid/dashed.
// A busy engine queues one pending commit per half and never mixes frames.
module native_bev_lane_engine #(
    parameter LUT_BASE = 32'h0240_0000,
    parameter FRAME_BYTES = 32'd1228800,
    parameter RIDGE_THRESHOLD = 45,     // on 3-pixel gray sums (~15 gray levels)
    parameter VOTE_MIN = 6
)(
    input wire clk,input wire rst,
    input wire native_active,input wire [1:0] native_mode,
    input wire c5_commit,input wire c5_bank,input wire [31:0] c5_base,
    input wire [31:0] c5_generation,input wire [31:0] c5_sequence,
    input wire c6_commit,input wire c6_bank,input wire [31:0] c6_base,
    input wire [31:0] c6_generation,input wire [31:0] c6_sequence,
    input wire [31:0] control,
    output reg [31:0] status,
    output reg [31:0] result_generation,
    output reg [31:0] result_sequence,
    output reg [15:0] result_valid,
    output reg [15:0] result_half,
    output reg [15:0] result_candidates,
    output reg [15:0] result_strength,
    output reg signed [31:0] result_a,result_b,result_c,
    output reg req_valid,input wire req_ready,output reg [31:0] req_addr,
    input wire rsp_valid,output wire rsp_ready,input wire [127:0] rsp_data,
    output reg [31:0] debug_count,
    output wire [31:0] debug_state,
    // bit0 line seen, bit1 solid, [10:2] present rows, [19:11] span, [28:20] max gap
    output reg [31:0] result_dash_left,result_dash_right,
    // Both lanes of the last completed half (snapshot, valid only with result_valid[1]/[2]).
    output reg signed [31:0] result_left_a,result_left_b,result_left_c,
    output reg signed [31:0] result_right_a,result_right_b,result_right_c,
    output reg [15:0] result_left_n,result_left_strength,
    output reg [15:0] result_right_n,result_right_strength
);
    localparam BIRD_N=52250;
    localparam S_IDLE=0,S_LUT_REQ=1,S_LUT_WAIT=2,S_PIX_PREP=3,
               S_PIX_REQ=4,S_PIX_WAIT=5,S_RIDGE=6,
               S_H_ADDR=8,S_H_ACC=10,S_H_BAND=11,
               S_T_START=12,S_T_BAND=14,S_T_ADDR=15,S_T_WAIT=16,
               S_T_CMP=17,S_T_NEXT=18,
               S_A_ITER=19,S_A_MUL=20,S_A_MUL2=30,S_A_ADD=21,S_F_START=22,S_F_WAIT=23,
               S_D_START=24,S_D_RUN=25,S_D_ACK=26,S_SIDE_DONE=27,S_PUB=28,S_DONE=29;
    reg [4:0] state;
    assign debug_state={27'd0,state};
    reg [16:0] lut_offset;
    reg [15:0] lut_index;
    reg [8:0] bird_col;
    reg [7:0] bird_row;
    reg signed [15:0] lut_x,lut_y;
    reg signed [17:0] source_x,source_y;
    reg signed [31:0] pixel_offset;
    reg [8:0] gray;
    reg half;
    reg [31:0] frame_base,frame_generation,frame_sequence;
    reg [31:0] request_count;
    reg pend5,pend6;
    reg [31:0] pend5_base,pend5_generation,pend5_sequence;
    reg [31:0] pend6_base,pend6_generation,pend6_sequence;
    integer i;

    // ------------------------------------------------------------------ RAMs
    reg ridge_mask [0:52249];
    reg mask_q;
    wire [15:0] mask_addr_mux;
    wire [15:0] wk_mask_addr;
    always @(posedge clk) mask_q<=ridge_mask[mask_addr_mux];
    reg [7:0] hist_mem [0:2047];
    reg [7:0] hist_q;
    reg [10:0] hist_addr;
    always @(posedge clk) hist_q<=hist_mem[hist_addr];

    // ------------------------------------------------------------- front end
    wire [15:0] lut_halfword =
        lut_offset[2:0]==0?rsp_data[15:0]:lut_offset[2:0]==1?rsp_data[31:16]:
        lut_offset[2:0]==2?rsp_data[47:32]:lut_offset[2:0]==3?rsp_data[63:48]:
        lut_offset[2:0]==4?rsp_data[79:64]:lut_offset[2:0]==5?rsp_data[95:80]:
        lut_offset[2:0]==6?rsp_data[111:96]:rsp_data[127:112];
    wire [15:0] lut_halfword_y =
        lut_offset[2:0]==0?rsp_data[31:16]:lut_offset[2:0]==1?rsp_data[47:32]:
        lut_offset[2:0]==2?rsp_data[63:48]:lut_offset[2:0]==3?rsp_data[79:64]:
        lut_offset[2:0]==4?rsp_data[95:80]:lut_offset[2:0]==5?rsp_data[111:96]:
        lut_offset[2:0]==6?rsp_data[127:112]:rsp_data[15:0];
    wire [15:0] pixel_halfword =
        pixel_offset[3:1]==0?rsp_data[15:0]:pixel_offset[3:1]==1?rsp_data[31:16]:
        pixel_offset[3:1]==2?rsp_data[47:32]:pixel_offset[3:1]==3?rsp_data[63:48]:
        pixel_offset[3:1]==4?rsp_data[79:64]:pixel_offset[3:1]==5?rsp_data[95:80]:
        pixel_offset[3:1]==6?rsp_data[111:96]:rsp_data[127:112];
    wire [8:0] pixel_gray={pixel_halfword[15:11],2'b00}+
                          {pixel_halfword[10:5],1'b0}+
                          {4'b0000,pixel_halfword[4:0]};
    wire [31:0] lut_address=LUT_BASE+{11'd0,lut_offset[16:3],4'b0000};
    wire [31:0] unaligned_pixel_address=frame_base+pixel_offset;
    wire start5=c5_commit && native_active && native_mode==2'd3 && control[0];
    wire start6=c6_commit && native_active && native_mode==2'd3 && control[0];
    assign rsp_ready=1'b1;

    // Capture commit metadata in the AXI domain before the engine can finish
    // the other half. A later commit for the same half replaces the older one.
    always @(posedge clk) begin
        if(rst) begin
            pend5<=0;pend6<=0;
            pend5_base<=0;pend5_generation<=0;pend5_sequence<=0;
            pend6_base<=0;pend6_generation<=0;pend6_sequence<=0;
        end else begin
            if(start5) begin
                pend5<=1;pend5_base<=c5_base;
                pend5_generation<=c5_generation;pend5_sequence<=c5_sequence;
            end
            if(start6) begin
                pend6<=1;pend6_base<=c6_base;
                pend6_generation<=c6_generation;pend6_sequence<=c6_sequence;
            end
            if(state==S_IDLE && (pend5||pend6))
                if(pend5) pend5<=0; else pend6<=0;
        end
    end

    // Window of the 14 samples before the current one (sw[0] = previous column).
    // With wn[0]=current gray: centre = wn[6..8], left = wn[12..14], right = wn[0..2].
    reg [8:0] sw [0:13];
    wire [10:0] w_ctr = sw[5]+sw[6]+sw[7];
    wire [10:0] w_l   = sw[11]+sw[12]+sw[13];
    wire [10:0] w_r   = gray+sw[0]+sw[1];
    wire [10:0] w_max = w_l>w_r?w_l:w_r;
    wire ridge_dec = ({1'b0,w_ctr}>={1'b0,w_max}+RIDGE_THRESHOLD);
    wire [15:0] mask_wr_addr = lut_index-16'd7;
    wire mask_wr_en = bird_row<=8'd207 && bird_col>=9'd27 && bird_col<=9'd236;

    // ------------------------------------------------------- histogram scan
    reg [7:0] h_col;
    reg [2:0] h_band;
    reg [4:0] h_r;
    reg [4:0] h_cnt;
    reg [15:0] h_addr,h_band_base;
    reg [4:0] cnt_hist [0:7][0:3];
    reg [7:0] smax_val [0:1];
    reg [2:0] smax_band [0:1];
    reg [7:0] smax_col [0:1];
    wire [7:0] h_scol=h_col-8'd2;
    wire [7:0] h_smooth = {3'd0,h_cnt}+cnt_hist[h_band][0]+cnt_hist[h_band][1]+
                          cnt_hist[h_band][2]+cnt_hist[h_band][3];
    wire h_side = h_scol>=8'd125;
    wire scan_phase = state==S_H_ADDR || state==S_H_ACC || state==S_H_BAND;
    assign mask_addr_mux = scan_phase ? h_addr : wk_mask_addr;

    // -------------------------------------------------------------- tracking
    reg t_side;
    reg [2:0] t_k;
    reg t_dir;                     // 0 = towards band 0, 1 = towards band 7
    reg [7:0] t_cur;
    reg [7:0] t_c,t_ce;
    reg [7:0] t_best_val,t_best_col;
    reg [7:0] peak_col [0:7];
    reg [7:0] peak_val [0:7];
    reg [7:0] peak_ok;
    reg [2:0] t_seed_band;
    wire [7:0] t_win_lo=t_side?8'd125:8'd20;
    wire [7:0] t_win_hi=t_side?8'd230:8'd125;     // exclusive
    wire [8:0] t_a_raw={1'b0,t_cur}-9'd14;
    wire [8:0] t_b_raw={1'b0,t_cur}+9'd15;        // exclusive end
    wire [7:0] t_scan_lo=({1'b0,t_cur}<={1'b0,t_win_lo}+9'd14)?t_win_lo:t_a_raw[7:0];
    wire [7:0] t_scan_hi=(t_b_raw>={1'b0,t_win_hi})?t_win_hi:t_b_raw[7:0];
    wire cmp_better = hist_q>t_best_val;
    wire [7:0] eff_val = cmp_better?hist_q:t_best_val;
    wire [7:0] eff_col = cmp_better?t_c:t_best_col;

    // --------------------------------------------------------------- fitting
    reg signed [39:0] fs_su,fs_su2,fs_su3,fs_su4,fs_sv,fs_suv,fs_su2v;
    reg [15:0] fs_n;
    reg [7:0] fs_umin,fs_umax;
    reg [3:0] a_k;
    reg signed [8:0] a_u;
    reg signed [12:0] a_v;
    reg signed [15:0] a_u2;
    reg signed [19:0] a_uv;
    reg signed [31:0] a_u3,a_u4;
    reg signed [28:0] a_u2v;
    reg [15:0] strength_acc;
    reg fit_start;
    wire fit_busy,fit_done,fit_valid;
    wire signed [31:0] fit_a,fit_b,fit_c;
    wire [31:0] fit_debug_pivot;
    wire [3:0] fit_debug_stage;
    native_bev_lean_fit fitter (
        .clk(clk),.rst(rst),.start(fit_start),.n(fs_n),
        .su(fs_su),.su2(fs_su2),.su3(fs_su3),.su4(fs_su4),
        .sv(fs_sv),.suv(fs_suv),.su2v(fs_su2v),
        .u_min(fs_umin),.u_max(fs_umax),
        .busy(fit_busy),.done(fit_done),.valid(fit_valid),
        .a_q8(fit_a),.b_q8(fit_b),.c_q8(fit_c),
        .debug_pivot(fit_debug_pivot),.debug_stage(fit_debug_stage));
    reg left_valid,right_valid;
    reg signed [31:0] left_a,left_b,left_c,right_a,right_b,right_c;
    reg [15:0] left_str,right_str,left_n,right_n;
    reg [31:0] left_dash,right_dash;
    wire signed [8:0] a_u_next = $signed({1'b0,a_k[2:0],4'd0})+$signed({1'b0,a_k[2:0],3'd0})+
                                 $signed({5'd0,a_k[2:0],1'b0})-9'sd91;   // 26k-91
    wire [7:0] a_row_next = {1'b0,a_k[2:0],4'd0}+{2'b0,a_k[2:0],3'd0}+{4'b0,a_k[2:0],1'b0}+8'd13;

    // ------------------------------------------------------ dash classifier
    reg wk_start,wk_ack;
    reg signed [31:0] wk_a,wk_b,wk_c;
    reg dash_clear,dash_row_valid,dash_row_present;
    wire wk_ev_valid,wk_ev_hit,wk_busy,wk_done;
    wire [7:0] wk_ev_row,wk_ev_col;
    wire [8:0] dash_present,dash_span,dash_maxgap,dash_segments;
    wire dash_solid,dash_seen;
    native_bev_lean_walker walker(
        .clk(clk),.rst(rst),.start(wk_start),.a(wk_a),.b(wk_b),.c(wk_c),
        .tol(4'd3),.mask_addr(wk_mask_addr),.mask_bit(mask_q),
        .ev_valid(wk_ev_valid),.ev_row(wk_ev_row),.ev_hit(wk_ev_hit),
        .ev_col(wk_ev_col),.ev_ack(wk_ack),.busy(wk_busy),.done(wk_done));
    native_bev_dash_classifier dash(
        .clk(clk),.rst(rst),.clear(dash_clear),.row_valid(dash_row_valid),
        .row_present(dash_row_present),.present_rows(dash_present),
        .span_rows(dash_span),.max_gap(dash_maxgap),.segments(dash_segments),
        .solid(dash_solid),.seen(dash_seen));

    always @(posedge clk) begin
        if(rst) begin
            state<=S_IDLE;status<=0;
            result_generation<=0;result_sequence<=0;result_valid<=0;
            result_half<=0;result_candidates<=0;result_strength<=0;
            result_a<=0;result_b<=0;result_c<=0;
            result_dash_left<=0;result_dash_right<=0;
            result_left_a<=0;result_left_b<=0;result_left_c<=0;
            result_right_a<=0;result_right_b<=0;result_right_c<=0;
            result_left_n<=0;result_left_strength<=0;
            result_right_n<=0;result_right_strength<=0;
            req_valid<=0;req_addr<=0;
            debug_count<=0;request_count<=0;
            lut_offset<=0;lut_index<=0;bird_col<=0;bird_row<=0;
            lut_x<=0;lut_y<=0;pixel_offset<=0;
            gray<=0;half<=0;frame_base<=0;frame_generation<=0;frame_sequence<=0;
            for(i=0;i<14;i=i+1) sw[i]<=0;
            left_valid<=0;right_valid<=0;left_a<=0;left_b<=0;left_c<=0;
            right_a<=0;right_b<=0;right_c<=0;left_str<=0;right_str<=0;
            left_n<=0;right_n<=0;left_dash<=0;right_dash<=0;
            fit_start<=0;wk_start<=0;wk_ack<=0;dash_clear<=0;dash_row_valid<=0;
            dash_row_present<=0;wk_a<=0;wk_b<=0;wk_c<=0;
            t_side<=0;t_k<=0;t_dir<=0;t_cur<=0;t_c<=0;t_ce<=0;t_best_val<=0;
            t_best_col<=0;peak_ok<=0;t_seed_band<=0;
            h_col<=0;h_band<=0;h_r<=0;h_cnt<=0;h_addr<=0;h_band_base<=0;hist_addr<=0;
            fs_su<=0;fs_su2<=0;fs_su3<=0;fs_su4<=0;fs_sv<=0;fs_suv<=0;fs_su2v<=0;
            fs_n<=0;fs_umin<=255;fs_umax<=0;a_k<=0;a_u<=0;a_v<=0;a_u2<=0;a_uv<=0;
            a_u3<=0;a_u4<=0;a_u2v<=0;strength_acc<=0;
            for(i=0;i<8;i=i+1) begin
                peak_col[i]<=0;peak_val[i]<=0;
                cnt_hist[i][0]<=0;cnt_hist[i][1]<=0;cnt_hist[i][2]<=0;cnt_hist[i][3]<=0;
            end
            smax_val[0]<=0;smax_val[1]<=0;smax_band[0]<=0;smax_band[1]<=0;
            smax_col[0]<=0;smax_col[1]<=0;
        end else begin
            fit_start<=0;wk_start<=0;wk_ack<=0;dash_clear<=0;dash_row_valid<=0;
            case(state)
                S_IDLE: begin
                    req_valid<=0;
                    if(pend5 || pend6) begin
                        half<=pend5?1'b0:1'b1;
                        frame_base<=pend5?pend5_base:pend6_base;
                        frame_generation<=pend5?pend5_generation:pend6_generation;
                        frame_sequence<=pend5?pend5_sequence:pend6_sequence;
                        status<=32'h1;
                        debug_count<=0;request_count<=0;
                        lut_offset<=0;lut_index<=0;bird_col<=0;bird_row<=0;
                        left_valid<=0;right_valid<=0;
                        state<=S_LUT_REQ;
                    end
                end
                S_LUT_REQ: begin
                    req_addr<=lut_address;req_valid<=1;
                    if(req_valid && req_ready) begin
                        req_valid<=0;request_count<=request_count+1'b1;
                        state<=S_LUT_WAIT;
                    end
                end
                S_LUT_WAIT: if(rsp_valid) begin
                    lut_x<=$signed(lut_halfword);
                    lut_y<=$signed(lut_halfword_y);
                    lut_offset<=lut_offset+2'd2;
                    state<=S_PIX_PREP;
                end
                S_PIX_PREP: begin
                    source_x=$signed(lut_x)>>>4;
                    source_y=$signed(lut_y)>>>4;
                    if(source_x>=0 && source_x<480 && source_y>=0 && source_y<360)
                        pixel_offset<=$signed(
                            (((source_y+600)<<9)+((source_y+600)<<7)+
                              source_x+80)<<1);
                    else pixel_offset<=-1;
                    gray<=0;
                    state<=(source_x>=0 && source_x<480 && source_y>=0 && source_y<360)?
                           S_PIX_REQ:S_RIDGE;
                end
                S_PIX_REQ: begin
                    req_addr<={unaligned_pixel_address[31:4],4'b0000};
                    req_valid<=1;
                    if(req_valid && req_ready) begin
                        req_valid<=0;request_count<=request_count+1'b1;
                        state<=S_PIX_WAIT;
                    end
                end
                S_PIX_WAIT: if(rsp_valid) begin gray<=pixel_gray;state<=S_RIDGE;end
                S_RIDGE: begin
                    if(mask_wr_en) ridge_mask[mask_wr_addr]<=ridge_dec;
                    sw[0]<=gray;
                    for(i=1;i<14;i=i+1) sw[i]<=sw[i-1];
                    if(lut_index==BIRD_N-1) begin
                        h_col<=8'd20;h_band<=0;h_r<=0;h_cnt<=0;
                        h_band_base<=16'd0;h_addr<=16'd20;
                        for(i=0;i<8;i=i+1) begin
                            cnt_hist[i][0]<=0;cnt_hist[i][1]<=0;
                            cnt_hist[i][2]<=0;cnt_hist[i][3]<=0;
                        end
                        smax_val[0]<=0;smax_val[1]<=0;
                        state<=S_H_ADDR;
                    end else begin
                        lut_index<=lut_index+1'b1;
                        debug_count<=debug_count+1'b1;
                        if(bird_col==249) begin bird_col<=0;bird_row<=bird_row+1'b1; end
                        else bird_col<=bird_col+1'b1;
                        state<=S_LUT_REQ;
                    end
                end
                // ---- pass 2: band histogram of the mask (columns beyond 229 count zero)
                S_H_ADDR: begin
                    if(h_col>8'd229) state<=S_H_BAND;   // h_cnt is already 0
                    else state<=S_H_ACC;                // mask_q valid next cycle
                end
                S_H_ACC: begin
                    h_cnt<=h_cnt+{4'd0,mask_q};
                    if(h_r==5'd25) state<=S_H_BAND;
                    else begin h_r<=h_r+5'd1;h_addr<=h_addr+16'd250;state<=S_H_ADDR; end
                end
                S_H_BAND: begin
                    cnt_hist[h_band][3]<=cnt_hist[h_band][2];
                    cnt_hist[h_band][2]<=cnt_hist[h_band][1];
                    cnt_hist[h_band][1]<=cnt_hist[h_band][0];
                    cnt_hist[h_band][0]<=h_cnt;
                    if(h_scol>=8'd20 && h_scol<=8'd229) begin
                        hist_mem[{h_band,h_scol}]<=h_smooth;
                        if(h_smooth>smax_val[h_side]) begin
                            smax_val[h_side]<=h_smooth;smax_band[h_side]<=h_band;
                            smax_col[h_side]<=h_scol;
                        end
                    end
                    h_cnt<=0;h_r<=0;
                    if(h_band==3'd7) begin
                        h_band<=0;h_col<=h_col+8'd1;h_band_base<=16'd0;
                        h_addr<={8'd0,h_col}+16'd1;
                        if(h_col==8'd231) begin t_side<=0;state<=S_T_START; end
                        else state<=S_H_ADDR;
                    end else begin
                        h_band<=h_band+3'd1;
                        h_band_base<=h_band_base+16'd6500;
                        h_addr<=h_band_base+16'd6500+{8'd0,h_col};
                        state<=S_H_ADDR;
                    end
                end
                // ---- pass 3: seed + band-to-band tracking
                S_T_START: begin
                    fs_su<=0;fs_su2<=0;fs_su3<=0;fs_su4<=0;fs_sv<=0;fs_suv<=0;fs_su2v<=0;
                    fs_n<=0;fs_umin<=255;fs_umax<=0;strength_acc<=0;a_k<=0;peak_ok<=0;
                    if(smax_val[t_side]<VOTE_MIN) begin
                        if(t_side) begin right_valid<=0;right_dash<=0;right_n<=0;right_str<=0; end
                        else begin left_valid<=0;left_dash<=0;left_n<=0;left_str<=0; end
                        state<=S_SIDE_DONE;
                    end else begin
                        peak_ok[smax_band[t_side]]<=1;
                        peak_col[smax_band[t_side]]<=smax_col[t_side];
                        peak_val[smax_band[t_side]]<=smax_val[t_side];
                        t_seed_band<=smax_band[t_side];
                        t_k<=smax_band[t_side];t_dir<=0;t_cur<=smax_col[t_side];
                        state<=S_T_NEXT;
                    end
                end
                S_T_NEXT: begin
                    if(!t_dir) begin
                        if(t_k==3'd0) begin
                            t_dir<=1;t_cur<=peak_col[t_seed_band];
                            if(t_seed_band==3'd7) state<=S_A_ITER;
                            else begin t_k<=t_seed_band+3'd1;state<=S_T_BAND; end
                        end else begin t_k<=t_k-3'd1;state<=S_T_BAND; end
                    end else begin
                        if(t_k==3'd7) state<=S_A_ITER;
                        else begin t_k<=t_k+3'd1;state<=S_T_BAND; end
                    end
                end
                S_T_BAND: begin
                    t_c<=t_scan_lo;t_ce<=t_scan_hi;t_best_val<=0;t_best_col<=0;
                    state<=S_T_ADDR;
                end
                S_T_ADDR: begin hist_addr<={t_k,t_c};state<=S_T_WAIT; end
                S_T_WAIT: state<=S_T_CMP;
                S_T_CMP: begin
                    t_best_val<=eff_val;t_best_col<=eff_col;
                    if((t_c+8'd1)>=t_ce) begin
                        if(eff_val>=VOTE_MIN) begin
                            peak_ok[t_k]<=1;peak_col[t_k]<=eff_col;peak_val[t_k]<=eff_val;
                            t_cur<=eff_col;
                        end
                        state<=S_T_NEXT;
                    end else begin t_c<=t_c+8'd1;state<=S_T_ADDR; end
                end
                // ---- accumulate the <=8 band peaks
                S_A_ITER: begin
                    if(a_k==4'd8) begin fit_start<=1;state<=S_F_WAIT; end
                    else if(peak_ok[a_k[2:0]]) begin
                        a_u<=a_u_next;
                        a_v<=($signed({5'd0,peak_col[a_k[2:0]]})-13'sd125)<<<4;
                        state<=S_A_MUL;
                    end else a_k<=a_k+4'd1;
                end
                S_A_MUL: begin
                    a_u2<=a_u*a_u;a_uv<=a_u*a_v;state<=S_A_MUL2;
                end
                S_A_MUL2: begin
                    a_u3<=a_u2*a_u;a_u4<=a_u2*a_u2;a_u2v<=a_u2*a_v;state<=S_A_ADD;
                end
                S_A_ADD: begin
                    fs_n<=fs_n+16'd1;
                    fs_su<=fs_su+a_u;fs_su2<=fs_su2+a_u2;fs_su3<=fs_su3+a_u3;
                    fs_su4<=fs_su4+a_u4;fs_sv<=fs_sv+a_v;fs_suv<=fs_suv+a_uv;
                    fs_su2v<=fs_su2v+a_u2v;
                    if(a_row_next<fs_umin) fs_umin<=a_row_next;
                    if(a_row_next>fs_umax) fs_umax<=a_row_next;
                    strength_acc<=strength_acc+{8'd0,peak_val[a_k[2:0]]};
                    a_k<=a_k+4'd1;state<=S_A_ITER;
                end
                S_F_WAIT: if(fit_done) begin
                    if(t_side) begin
                        right_valid<=fit_valid;right_a<=fit_a;right_b<=fit_b;right_c<=fit_c;
                        right_n<=fs_n;right_str<=strength_acc;right_dash<=0;
                    end else begin
                        left_valid<=fit_valid;left_a<=fit_a;left_b<=fit_b;left_c<=fit_c;
                        left_n<=fs_n;left_str<=strength_acc;left_dash<=0;
                    end
                    if(fit_valid) begin
                        wk_a<=fit_a;wk_b<=fit_b;wk_c<=fit_c;
                        state<=S_D_START;
                    end else state<=S_SIDE_DONE;
                end
                // ---- pass 4: solid/dashed along the fit
                S_D_START: begin wk_start<=1;dash_clear<=1;state<=S_D_RUN; end
                S_D_RUN: begin
                    if(wk_done) begin
                        if(t_side) right_dash<={3'd0,dash_maxgap,dash_span,dash_present,
                                                dash_solid,dash_seen};
                        else left_dash<={3'd0,dash_maxgap,dash_span,dash_present,
                                         dash_solid,dash_seen};
                        state<=S_SIDE_DONE;
                    end else if(wk_ev_valid) begin
                        dash_row_valid<=1;dash_row_present<=wk_ev_hit;
                        wk_ack<=1;state<=S_D_ACK;
                    end
                end
                S_D_ACK: state<=S_D_RUN;
                S_SIDE_DONE: begin
                    if(!t_side) begin t_side<=1;state<=S_T_START; end
                    else state<=S_PUB;
                end
                S_PUB: begin
                    result_generation<=frame_generation;
                    result_sequence<=frame_sequence;
                    result_half<={15'd0,half};
                    result_valid<={13'd0,right_valid,left_valid,(left_valid||right_valid)};
                    result_dash_left<=left_valid?left_dash:32'd0;
                    result_dash_right<=right_valid?right_dash:32'd0;
                    result_left_a<=left_valid?left_a:32'd0;
                    result_left_b<=left_valid?left_b:32'd0;
                    result_left_c<=left_valid?left_c:32'd0;
                    result_right_a<=right_valid?right_a:32'd0;
                    result_right_b<=right_valid?right_b:32'd0;
                    result_right_c<=right_valid?right_c:32'd0;
                    result_left_n<=left_valid?left_n:16'd0;
                    result_left_strength<=left_valid?left_str:16'd0;
                    result_right_n<=right_valid?right_n:16'd0;
                    result_right_strength<=right_valid?right_str:16'd0;
                    if(right_valid && (!left_valid || right_str>left_str)) begin
                        result_a<=right_a;result_b<=right_b;result_c<=right_c;
                        result_candidates<=right_n;result_strength<=right_str;
                        status[8]<=1;
                    end else begin
                        result_a<=left_valid?left_a:32'd0;
                        result_b<=left_valid?left_b:32'd0;
                        result_c<=left_valid?left_c:32'd0;
                        result_candidates<=left_n;result_strength<=left_str;
                        status[8]<=0;
                    end
                    status[1]<=(left_valid||right_valid);
                    status[2]<=left_valid;status[3]<=right_valid;
                    status[31:16]<=request_count[15:0];
                    state<=S_DONE;
                end
                S_DONE: begin
                    debug_count<=BIRD_N;
                    status[0]<=0;
                    state<=S_IDLE;
                end
                default:state<=S_IDLE;
            endcase
        end
    end
endmodule
