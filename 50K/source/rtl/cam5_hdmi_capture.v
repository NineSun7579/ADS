`timescale 1ns/1ps
// Candidate-local copy of donor hdmi_720p_capture. Only FIFO module changes
// to cam5_hdmi_fifo; PLL/sample phase, geometry and event semantics retained.
module cam5_hdmi_capture #(
    parameter INPUT_WIDTH=1280,INPUT_HEIGHT=720,OUTPUT_HEIGHT=480,FIFO_DEPTH=2048,
    parameter AUTO_FORMAT=(INPUT_WIDTH==1280 && INPUT_HEIGHT==720 && OUTPUT_HEIGHT==480)
)(
    input pclk,out_clk,request_n,capture_ready,vs_in,hs_in,de_in,
    input [7:0]r_in,g_in,b_in,
    output reg [18:0]video,output fault,output reg format_ok
);
    wire pll_sample,pll_feedback,sample_clk,feedback_clk,input_locked;
    GTP_PLL_E3 #(.CLKIN_FREQ(148.5),.STATIC_RATIOI(1),.STATIC_RATIOM(1),
        .STATIC_RATIOF(8),.STATIC_RATIO0(8),.STATIC_RATIO1(8),
        .STATIC_DUTY0(8),.STATIC_DUTY1(8),.STATIC_PHASE0(3),
        .STATIC_CPHASE0(5),.STATIC_PHASE1(0),.STATIC_CPHASE1(0),
        .INTERNAL_FB("DISABLE"),.EXTERNAL_FB("CLKOUT1"),.BANDWIDTH("HIGH")) u_input_pll(
        .CLKIN1(pclk),.CLKIN2(1'b0),.CLKIN_SEL(1'b0),.CLKIN_SEL_EN(1'b0),
        .CLKFB(feedback_clk),.CLKOUT0(pll_sample),.CLKOUT1(pll_feedback),
        .LOCK(input_locked),.PLL_PWD(1'b0),.RST(!request_n),.RSTODIV(1'b0),
        .PFDEN(1'b1),.ICP_BASE(1'b0),.ICP_SEL(4'b0),.LPFRES_SEL(3'b0),
        .CRIPPLE_SEL(1'b0),.PHASE_SEL(3'b0),.PHASE_DIR(1'b0),
        .PHASE_STEP_N(1'b1),.LOAD_PHASE(1'b0),.RATIOI(10'b0),.RATIOM(7'b0),
        .RATIOF(10'b0),.RATIO0(10'b0),.RATIO1(10'b0),.RATIO2(10'b0),
        .RATIO3(10'b0),.RATIO4(10'b0),.DUTY0(10'b0),.DUTY1(10'b0),
        .DUTY2(10'b0),.DUTY3(10'b0),.DUTY4(10'b0),.CLKOUT0_SYN(1'b1),
        .CLKOUT0_EXT_SYN(1'b1),.CLKOUT1_SYN(1'b1),.CLKOUT2_SYN(1'b1),
        .CLKOUT3_SYN(1'b1),.CLKOUT4_SYN(1'b1),.CLKOUT5_SYN(1'b1));
    GTP_CLKBUFG u_input_clock(.CLKIN(pll_sample),.CLKOUT(sample_clk));
    GTP_CLKBUFG u_feedback_clock(.CLKIN(pll_feedback),.CLKOUT(feedback_clk));
    (* syn_useioff=1 *)reg vs,hs,de;
    (* syn_useioff=1 *)reg [7:0]r,g,b;
    always @(posedge sample_clk){vs,hs,de,r,g,b}<={vs_in,hs_in,de_in,r_in,g_in,b_in};
    wire wr_rst_n,rd_rst_n;
    video_reset_sync u_wr_reset(sample_clk,request_n && input_locked,wr_rst_n);
    video_reset_sync u_rd_reset(out_clk,request_n && input_locked,rd_rst_n);
    wire lock_rst_n;
    video_reset_sync u_lock_reset(out_clk,request_n,lock_rst_n);
    (* ASYNC_REG="TRUE" *)reg [1:0]lock_sync;
    reg lock_seen,capture_fault;
    always @(posedge out_clk or negedge lock_rst_n)
        if(!lock_rst_n)begin lock_sync<=0;lock_seen<=0;end
        else begin lock_sync<={lock_sync[0],input_locked};if(lock_sync[1])lock_seen<=1;end
    assign fault=capture_fault || (lock_seen && !lock_sync[1]);
    (* ASYNC_REG="TRUE" *)reg [1:0]ready_sync;
    reg vs_d,de_d,seen_frame,bad_frame,admit;
    reg [12:0]x,lines;
    reg [3:0]row_phase;reg [1:0]col_phase;
    reg measured_known,measured_1080,active_1080;
    reg row_keep,column_limit,row_limit,event_en;
    reg [18:0]event_data;
    wire full,empty;wire [18:0]head;
    wire vs_start=vs && !vs_d,line_end=!de && de_d;
    wire width_720=x==INPUT_WIDTH,width_1080=AUTO_FORMAT && x==1920;
    wire measured_width_ok=measured_1080 ? width_1080:width_720;
    wire height_ok=measured_1080 ?
        ((!line_end && lines==1080) || (line_end && lines==1079 && measured_width_ok)):
        ((!line_end && lines==INPUT_HEIGHT) || (line_end && lines==INPUT_HEIGHT-1 && measured_width_ok));
    wire frame_ok=seen_frame && measured_known && !bad_frame && height_ok;
    wire crop_pixel=de && !vs && admit && ready_sync[1] && row_keep && !row_limit &&
        !column_limit && (!active_1080 || col_phase!=2);
    always @(posedge sample_clk or negedge wr_rst_n)
        if(!wr_rst_n)begin
            ready_sync<=0;vs_d<=0;de_d<=0;x<=0;lines<=0;row_phase<=0;col_phase<=0;
            measured_known<=0;measured_1080<=0;active_1080<=0;
            row_keep<=1;column_limit<=0;row_limit<=0;seen_frame<=0;bad_frame<=0;
            admit<=0;capture_fault<=0;format_ok<=0;event_en<=0;event_data<=0;
        end else begin
            ready_sync<={ready_sync[0],capture_ready};vs_d<=vs;de_d<=de;event_en<=0;
            if(event_en && full)begin capture_fault<=1;admit<=0;format_ok<=0;end
            else if(!ready_sync[1])begin
                seen_frame<=0;admit<=0;format_ok<=0;bad_frame<=0;
                x<=0;lines<=0;row_phase<=0;col_phase<=0;measured_known<=0;
                measured_1080<=0;active_1080<=0;row_keep<=1;column_limit<=0;row_limit<=0;
            end else if(vs_start)begin
                format_ok<=frame_ok && !capture_fault;admit<=frame_ok && !capture_fault;
                active_1080<=measured_1080;
                if(admit && !frame_ok)begin capture_fault<=1;admit<=0;format_ok<=0;end
                event_en<=!capture_fault && !(admit && !frame_ok);
                event_data<={1'b1,1'b0,1'b0,16'b0};
                seen_frame<=1;bad_frame<=0;measured_known<=0;measured_1080<=0;
                x<=0;lines<=0;row_phase<=0;col_phase<=0;row_keep<=1;column_limit<=0;row_limit<=0;
            end else if(!vs)begin
                if(de)begin
                    if(x<8191)x<=x+1'b1;
                    col_phase<=col_phase==2 ? 0:col_phase+1'b1;
                    if(active_1080 ? x==1919:x==INPUT_WIDTH-1)column_limit<=1;
                    if((admit && (column_limit || row_limit)) ||
                        (AUTO_FORMAT ? x>=1920 || lines>=1080:x>=INPUT_WIDTH || lines>=INPUT_HEIGHT))begin
                        bad_frame<=1;admit<=0;format_ok<=0;if(admit)capture_fault<=1;
                    end
                end
                if(line_end)begin
                    x<=0;col_phase<=0;column_limit<=0;if(lines<8191)lines<=lines+1'b1;
                    if(active_1080)begin
                        row_phase<=row_phase==8 ? 0:row_phase+1'b1;
                        row_keep<=row_phase==8 || row_phase==1 || row_phase==3 || row_phase==6;
                    end else begin row_phase<=row_phase==2 ? 0:row_phase+1'b1;row_keep<=row_phase!=1;end
                    if(active_1080 ? lines==1079:lines==INPUT_HEIGHT-1)row_limit<=1;
                    if(!measured_known)begin measured_known<=width_720 || width_1080;measured_1080<=width_1080;end
                    if((!measured_known && !width_720 && !width_1080) ||
                        (measured_known && !measured_width_ok) ||
                        (admit && !(active_1080 ? width_1080:width_720)))begin
                        bad_frame<=1;admit<=0;format_ok<=0;if(admit)capture_fault<=1;
                    end
                end
                if(vs_d || line_end)begin event_en<=!capture_fault;event_data<=0;end
                else if(crop_pixel && !capture_fault)begin
                    event_en<=1;event_data<={1'b0,1'b0,1'b1,r[7:3],g[7:2],b[7:3]};
                end
            end
        end
    cam5_hdmi_fifo #(.WIDTH(19),.DEPTH(FIFO_DEPTH)) u_fifo(
        .wr_clk(sample_clk),.wr_rst_n(wr_rst_n),.wr_en(event_en && !capture_fault),
        .wr_data(event_data),.full(full),.rd_clk(out_clk),.rd_rst_n(rd_rst_n),
        .rd_en(!empty),.rd_data(head),.empty(empty));
    always @(posedge out_clk or negedge rd_rst_n)
        if(!rd_rst_n)video<=0;
        else if(!empty)video<=head;
        else video<={video[18:17],1'b0,16'b0};
endmodule
