module ov5640 #(
    //DVP�����λ��
    parameter [7:0] SENSOR_PLL_MULT = 8'h54,
    parameter   DATA_WIDTH = 16,
    //I2C
    parameter   SLAVE_ADDR = 7'h3c   ,  //I2C�ӻ���ַ
    parameter   BIT_CTRL   = 1'b1           , //OV5640���ֽڵ�ַΪ16λ  0:8λ 1:16λ
    parameter   CLK_FREQ   = 26'd25_000_000, //[CLKFIX] clk_50m = free_clk 25MHz, //ģ�������ʱ��Ƶ��
    parameter   I2C_FREQ   = 18'd250_000,    //IIC_SCL��ʱ��Ƶ��

    //����
    parameter  H_CMOS_DISP = 11'd1280  , //CMOS�ֱ���--��
    parameter  V_CMOS_DISP = 11'd720   , //CMOS�ֱ���--��	
    parameter  TOTAL_H_PIXEL = 12'd2570, //ˮƽ�����ش�С
    parameter  TOTAL_V_PIXEL = 12'd980 , //��ֱ�����ش�С
    //�忨�豸
    parameter integer VSYNC_STABLE_CYCLES = 0,
    parameter DEVICE = "PG"
)(
    

	input              clk_50m            ,  // Clock i2c�Ĳο�ʱ��
	input              rst_n              ,  // Asynchronous reset active low

    output             ov_rst_n           /*synthesis PAP_MARK_DEBUG="1"*/,  //SCCB�������

	input              cam_pclk           /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos ��������ʱ��
    input              cam_vsync          /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos ��ͬ���ź�
    input              cam_href           /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos ��ͬ���ź�
    input   [7:0]      cam_data           /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos ����
    output             cam_rst_n          /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos ��λ�źţ��͵�ƽ��Ч
    output             cam_pwdn           /*synthesis PAP_MARK_DEBUG="1"*/,  //��Դ����ģʽѡ�� 0������ģʽ 1����Դ����ģʽ
    output             cam_scl            /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos SCCB_SCL��
    inout              cam_sda            /*synthesis PAP_MARK_DEBUG="1"*/,  //cmos SCCB_SDA��    

    input                      video_clk          ,  // ��������ͷ����ʱ��
    input                      video_rst          ,
    output                     video_vsync        /*synthesis PAP_MARK_DEBUG="1"*/,  //֡��Ч�ź�    
    output                     video_hsync        /*synthesis PAP_MARK_DEBUG="1"*/,  //����Ч�ź�  //û��
    output                     video_valid        /*synthesis PAP_MARK_DEBUG="1"*/,  //8bitת16bit������Чʹ���ź�
    output [DATA_WIDTH-1:0]    video_data         /*synthesis PAP_MARK_DEBUG="1"*/,  //��Ч����
    output reg [31:0]         dbg_i2c_status     ,  //[31:16]NACK ops [15:8]ID_H [7:0]ID_L
    output reg [31:0]         dbg_pclk_cnt          ,//free-running pclk counter
    output reg [31:0]         dbg_sys_status        ,//[31:16]exec_cnt [5]sda [4]scl [1]lock [0]rst_n
    output reg [31:0]         dbg_href_raw          ,//raw cam_href rising edges (cam_pclk domain)
    output reg [31:0]         dbg_vsync_raw          ,//raw cam_vsync rising edges (cam_pclk domain)

    // [PT 2026-09-26] host SCCB passthrough (handshake on dri_clk)
    output [31:0] dbg_cdc_input,
    output [31:0] dbg_cdc_output,
    output [31:0] dbg_cdc_drop,
    output [31:0] dbg_cdc_seq,
    input [31:0] diag_seq, diag_payload,
    input diag_rst_n,
    output [511:0] diag_snapshot,
    output diag_event, diag_clk,
    input                     pt_req_toggle         ,
    input                     pt_rw                 ,
    input  [15:0]             pt_addr               ,
    input  [ 7:0]             pt_wdata              ,
    output [ 7:0]             pt_rdata              ,
    output                    pt_ack                ,
    output [31:0]             pt_seq,
    output                    pt_done_toggle

    // //�û��ӿ�                              
    // output                      cmos_frame_vsync ,  //֡��Ч�ź�    
    // output                      cmos_frame_href  ,  //����Ч�ź�    //û��
    // output                      cmos_frame_valid ,  //8bitת16bit������Чʹ���ź�
    // output  [DATA_WIDTH-1 : 0]  cmos_frame_data     //��Ч����        
	
);

wire diag_take_observed, diag_busy_observed;
wire            i2c_dri_clk;
wire            i2c_done;
wire   [7:0]    i2c_data_r;
wire            i2c_exec;
wire   [23:0]   i2c_data;
wire            i2c_rh_wl;
wire            cfg_exec;
wire   [23:0]   cfg_data;
wire            cfg_rh_wl;
wire            cam_init_done;
wire            i2c_ack;
wire            dri_clk;
wire                    cmos_frame_vsync;
wire                    cmos_frame_href;
wire                    cmos_frame_valid;
wire [DATA_WIDTH-1 : 0] cmos_frame_data;

// wire cam_pclk_bufg/*synthesis PAP_MARK_DEBUG="1"*/;
// GTP_CLKBUFG u_pclk_bufg (
//     .CLKOUT(cam_pclk_bufg),
//     .CLKIN(cam_pclk)
// );

//=========================================================
// ���㼫��λ���ƣ�ֻ��ǰ 5ms ����������
// 50MHz ʱ���£�5ms = 250,000 ������
//=========================================================
reg [$clog2(CLK_FREQ/1000*7) : 0] power_on_cnt; // 18λ�㹻�� 250,000
reg                               i2c_start_en;

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        power_on_cnt  <= 18'd0;
        i2c_start_en  <= 1'b0; // ǿ�а�ס�ײ�� I2C ģ��
    end 
    else begin
        if (power_on_cnt < CLK_FREQ/1000*7) begin 
            power_on_cnt <= power_on_cnt + 1'b1;
        end 
        else begin
            // 5ms ���ˣ�ͬʱ���֣�
            i2c_start_en  <= 1'b1; // I2C ģ�����ѣ���ʼ���������Լ��� 20ms
        end
    end
end

assign cam_rst_n = i2c_start_en;
assign cam_pwdn  = 1'b0;

//SCCB������ɲ�ץȡ����ͷ
assign ov_rst_n = rst_n & cam_init_done;


    //--------------------------------------------------------------------------
    // cam_pclk reset-release synchronisers (C5 100H repair).
    //
    // `ov_rst_n` de-asserts on cam_init_done (dri_clk domain) and `cam_rst_n`
    // de-asserts on i2c_start_en (clk_50m domain); both were used directly as
    // asynchronous resets inside the cam_pclk domain, so their release edges had
    // no recovery/removal guarantee (worst measured -12.031 ns into
    // cmos_capture/cmos_data_t[*]/RS).
    //
    // Assertion stays fully asynchronous - it must work with a stopped clock -
    // and only the DE-ASSERTION is re-timed into cam_pclk by two flops. Stage 1
    // is reset by stage 0 rather than by the raw request so that assertion still
    // completes with no cam_pclk edge, matching video_reset_sync.v.
    //--------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] ov_rst_n_rel;
    always @(posedge cam_pclk or negedge ov_rst_n)
        if (!ov_rst_n) ov_rst_n_rel[0] <= 1'b0;
        else           ov_rst_n_rel[0] <= 1'b1;
    always @(posedge cam_pclk or negedge ov_rst_n_rel[0])
        if (!ov_rst_n_rel[0]) ov_rst_n_rel[1] <= 1'b0;
        else                  ov_rst_n_rel[1] <= 1'b1;

    (* ASYNC_REG = "TRUE" *) reg [1:0] cam_rst_n_rel;
    always @(posedge cam_pclk or negedge cam_rst_n)
        if (!cam_rst_n) cam_rst_n_rel[0] <= 1'b0;
        else            cam_rst_n_rel[0] <= 1'b1;
    always @(posedge cam_pclk or negedge cam_rst_n_rel[0])
        if (!cam_rst_n_rel[0]) cam_rst_n_rel[1] <= 1'b0;
        else                   cam_rst_n_rel[1] <= 1'b1;

    wire ov_rst_n_cam    = ov_rst_n_rel[1];
    wire cam_rst_n_cam   = cam_rst_n_rel[1];






// declarations moved above first use for ModelSim compatibility






wire pt_rst_n;
i2c_dri #(
    .SLAVE_ADDR(SLAVE_ADDR), //I2C�ӻ���ַ
    .CLK_FREQ  (CLK_FREQ  ), //ģ�������ʱ��Ƶ��
    .I2C_FREQ  (I2C_FREQ  )  //IIC_SCL��ʱ��Ƶ��
)
i2c_dri(                                                            
    .clk  (clk_50m)  ,    
    .rst_n(rst_n)    ,   
                                         
    //i2c interface                      
    .i2c_exec   (i2c_exec  ),  //I2C����ִ���ź�
    .bit_ctrl   (BIT_CTRL  ),  //�ֵ�ַλ����(16b/8b)
    .i2c_rh_wl  (i2c_rh_wl ),  //I2C��д�����ź�
    .i2c_addr   (i2c_data[23:8]),  //I2C�����ڵ�ַ
    .i2c_data_w (i2c_data[7:0]),  //I2CҪд������
    .i2c_data_r (i2c_data_r),  //I2C����������
    .i2c_done   (i2c_done  ),  //I2Cһ�β������
    .i2c_ack    (i2c_ack)     ,            //I2CӦ���־ 0:Ӧ�� 1:δӦ��
    .scl        (cam_scl   ),  //I2C��SCLʱ���ź�
    .sda        (cam_sda   ),  //I2C��SDA�ź�
                                       
    //user interface                   
    .diag_seq(diag_seq), .diag_payload(diag_payload), .diag_take(diag_take_observed),
    .diag_busy(diag_busy_observed), .diag_rst_n(pt_rst_n),
    .diag_snapshot(diag_snapshot), .diag_event(diag_event),
    .dri_clk(dri_clk)       //����I2C����������ʱ��
);



ov5640_i2c_rgb565_cfg #(
    .SENSOR_PLL_MULT(SENSOR_PLL_MULT),
    .I2C_FREQ  (I2C_FREQ  )  //IIC_SCL��ʱ��Ƶ��
)
ov5640_i2c_rgb565_cfg(  
    .clk(dri_clk)    ,     //ʱ���ź� SCL��4��Ƶ
    .rst_n(rst_n & i2c_start_en)    ,     //��λ�źţ��͵�ƽ��Ч
    
    .i2c_data_r   (i2c_data_r),  //I2C����������   
    .i2c_done     (i2c_done),    //I2C�Ĵ�����������ź� 
    .cmos_h_pixel (H_CMOS_DISP),
    .cmos_v_pixel (V_CMOS_DISP),
    .total_h_pixel(TOTAL_H_PIXEL), //ˮƽ�����ش�С
    .total_v_pixel(TOTAL_V_PIXEL),  //��ֱ�����ش�С
    .i2c_exec     (cfg_exec),     //I2C����ִ���ź�   
    .i2c_data     (cfg_data),     //I2CҪ���õĵ�ַ������(��16λ��ַ,��8λ����)
    .i2c_rh_wl    (cfg_rh_wl),     //I2C��д�����ź�
    .init_done    (cam_init_done) //��ʼ������ź�
);




// // �� hdmi_loop.v �����ӵ�һ���Ĵ���
// (* IOB = "TRUE" *)reg         cam_vsync_r, cam_href_r;
// (* IOB = "TRUE" *)reg [7:0]   cam_data_r;
// always @(posedge cam_pclk) begin 
//     cam_vsync_r <= cam_vsync;   
//     cam_href_r  <= cam_href;
//     cam_data_r  <= cam_data;
// end


// [DBG] SCCB health: latch first two read bytes (OV5640 ID 0x56,0x40) + NACK op count
// [PT 2026-09-26] latch read/write at transaction start: i2c_rh_wl flips to 0
// at init_reg_cnt==2 during the 2nd read, so sampling it at i2c_done missed ID_L.
reg i2c_was_read;
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n)        i2c_was_read <= 1'b0;
    else if(i2c_exec) i2c_was_read <= i2c_rh_wl;
end
reg [3:0] dbg_rd_cnt;
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n) begin
        dbg_rd_cnt     <= 4'd0;
        dbg_i2c_status <= 32'd0;
    end
    else if(i2c_done) begin
        if(i2c_ack) dbg_i2c_status[31:16] <= dbg_i2c_status[31:16] + 16'd1;
        if(i2c_was_read && (dbg_rd_cnt < 4'd2)) begin
            dbg_rd_cnt <= dbg_rd_cnt + 4'd1;
            if(dbg_rd_cnt == 4'd0) dbg_i2c_status[15:8] <= i2c_data_r;
            else                   dbg_i2c_status[7:0]  <= i2c_data_r;
        end
    end
end

// [DBG] pclk activity counter (pclk domain, read twice to check delta)
always @(posedge cam_pclk) dbg_pclk_cnt <= dbg_pclk_cnt + 32'd1;
// [PROBE] raw DVP pin edge counters (independent of the CDC FIFO)
reg [2:0] dbg_hr_ff, dbg_vr_ff;
always @(posedge cam_pclk) dbg_hr_ff <= {dbg_hr_ff[1:0], cam_href};
always @(posedge cam_pclk) dbg_vr_ff <= {dbg_vr_ff[1:0], cam_vsync};
always @(posedge cam_pclk) if (dbg_hr_ff[2:1] == 2'b01) dbg_href_raw  <= dbg_href_raw  + 32'd1;
always @(posedge cam_pclk) if (dbg_vr_ff[2:1] == 2'b01) dbg_vsync_raw <= dbg_vsync_raw + 32'd1;
// [DBG] i2c transaction counter + bus level snapshot
wire dbg_sda_lvl = cam_sda;
wire dbg_scl_lvl = cam_scl;
reg [15:0] dbg_exec_cnt;
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n) dbg_exec_cnt <= 16'd0;
    else if(i2c_exec) dbg_exec_cnt <= dbg_exec_cnt + 16'd1;
end
always @(posedge dri_clk) dbg_sys_status <= {dbg_exec_cnt, 2'b00, dbg_sda_lvl, dbg_scl_lvl,
                                            1'b0, cam_rst_n};
// PT_FSM_BEGIN
// [PT 2026-09-26] host SCCB passthrough FSM (dri_clk domain). After sensor
// init completes, a host command issues exactly one transaction on the shared
// master; cfg_* is the autonomous init table. Results are handed back with a
// done-toggle (data held stable; CDC to video_clk lives in ov5640_top).
wire pt_common_rst_n = rst_n && diag_rst_n;
(* ASYNC_REG = "TRUE", syn_srlstyle = "registers" *) reg [2:0] pt_reset_release;
always @(posedge dri_clk or negedge pt_common_rst_n) begin
    if(!pt_common_rst_n) pt_reset_release <= 3'b000;
    else pt_reset_release <= {pt_reset_release[1:0],1'b1};
end
assign pt_rst_n = pt_reset_release[2];
reg         pt_req_s1, pt_req_s2, pt_req_s3;
always @(posedge dri_clk or negedge pt_rst_n) begin
    if(!pt_rst_n) {pt_req_s1, pt_req_s2, pt_req_s3} <= 3'b0;
    else       {pt_req_s1, pt_req_s2, pt_req_s3} <= {pt_req_toggle, pt_req_s1, pt_req_s2};
end
assign diag_clk = dri_clk;
wire pt_req_pulse = pt_req_s2 ^ pt_req_s3;

reg  pt_pending;
reg  pt_busy;
// Keep engine occupancy across a video-only reset. The engine itself is not
// reset by video_rst; an abandoned operation must drain before another take.
(* ASYNC_REG = "TRUE", syn_srlstyle = "registers" *) reg [2:0] pt_engine_reset_release;
always @(posedge dri_clk or negedge rst_n) begin
    if(!rst_n) pt_engine_reset_release<=3'b000;
    else pt_engine_reset_release<={pt_engine_reset_release[1:0],1'b1};
end
wire pt_engine_rst_n=pt_engine_reset_release[2];
reg pt_engine_inflight;
always @(posedge dri_clk or negedge pt_engine_rst_n) begin
    if(!pt_engine_rst_n) pt_engine_inflight<=0;
    else if(i2c_done) pt_engine_inflight<=0;
    else if(i2c_exec) pt_engine_inflight<=1;
end
wire pt_take = pt_pending & cam_init_done & ~pt_busy & ~pt_engine_inflight;
assign diag_take_observed = pt_take;
assign diag_busy_observed = pt_busy;
reg [31:0] pt_take_seq, pt_seq_r;
always @(posedge dri_clk or negedge pt_rst_n) begin
    if(!pt_rst_n) begin pt_take_seq<=0; pt_seq_r<=0; end
    else begin
        if(pt_take) pt_take_seq<=diag_seq;
        if(i2c_done && pt_busy) pt_seq_r<=pt_take_seq;
    end
end
assign pt_seq = pt_seq_r;
always @(posedge dri_clk or negedge pt_rst_n) begin
    if(!pt_rst_n)          pt_pending <= 1'b0;
    else if(pt_req_pulse) pt_pending <= 1'b1;
    else if(pt_take)      pt_pending <= 1'b0;
end
always @(posedge dri_clk or negedge pt_rst_n) begin
    if(!pt_rst_n)        pt_busy <= 1'b0;
    else if(pt_take)  pt_busy <= 1'b1;
    else if(i2c_done) pt_busy <= 1'b0;
end

assign i2c_exec  = cfg_exec | pt_take;
assign i2c_data  = pt_take ? {pt_addr, pt_wdata} : cfg_data;
assign i2c_rh_wl = pt_take ? pt_rw : cfg_rh_wl;

reg [7:0] pt_rdata_r;
reg       pt_ack_r;
reg       pt_done_toggle_r;
always @(posedge dri_clk or negedge pt_rst_n) begin
    if(!pt_rst_n) begin
        pt_rdata_r       <= 8'd0;
        pt_ack_r         <= 1'b0;
        pt_done_toggle_r <= 1'b0;
    end
    else if(i2c_done && pt_busy) begin
        pt_rdata_r       <= i2c_data_r;
        pt_ack_r         <= i2c_ack;
        pt_done_toggle_r <= ~pt_done_toggle_r;
    end
end
assign pt_rdata       = pt_rdata_r;
assign pt_ack         = pt_ack_r;
assign pt_done_toggle = pt_done_toggle_r;
// PT_FSM_END

// VSYNC_FILTER_BEGIN
// 0: combinational bypass. N>0: accept only N consecutive opposite samples.
// Both edges are delayed by N PCLK samples (64/84 MHz = 0.762 us).
// Raw diagnostics above intentionally remain upstream. HREF/data are untouched.
// Requires real VSYNC pulses and edge-to-active-video blanking to exceed N
// samples plus the existing capture latency. No timeout or synthetic frames.
wire capture_vsync;
generate
    if (VSYNC_STABLE_CYCLES == 0) begin : g_vsync_bypass
        assign capture_vsync = cam_vsync;
    end else begin : g_vsync_filter
        localparam COUNT_W = (VSYNC_STABLE_CYCLES <= 1) ? 1 :
                             $clog2(VSYNC_STABLE_CYCLES);
        reg [COUNT_W-1:0] stable_count;
        reg stable_vsync;
        assign capture_vsync = stable_vsync;
        always @(posedge cam_pclk or negedge ov_rst_n_cam) begin
            if (!ov_rst_n_cam) begin
                stable_count <= {COUNT_W{1'b0}};
                stable_vsync <= 1'b0;
            end else if (cam_vsync == stable_vsync) begin
                stable_count <= {COUNT_W{1'b0}};
            end else if (stable_count == VSYNC_STABLE_CYCLES - 1) begin
                stable_count <= {COUNT_W{1'b0}};
                stable_vsync <= cam_vsync;
            end else begin
                stable_count <= stable_count + 1'b1;
            end
        end
    end
endgenerate
// VSYNC_FILTER_END

cmos_capture #(
    .DATA_WIDTH(DATA_WIDTH)
)
cmos_capture(
    .rst_n (ov_rst_n_cam)       ,  //��λ�ź�    
    //����ͷ�ӿ�                           
    .cam_pclk   (cam_pclk) ,   //cmos ��������ʱ��
    .cam_vsync  (capture_vsync),  //cmos ��ͬ���ź�
    .cam_href   (cam_href) ,  //cmos ��ͬ���ź�
    .cam_data   (cam_data) ,                       
    //�û��ӿ�                              
    .cmos_frame_vsync(cmos_frame_vsync),  //֡��Ч�ź�    
    .cmos_frame_href (cmos_frame_href ),  //����Ч�ź�
    .cmos_frame_valid(cmos_frame_valid),  //������Чʹ���ź�
    .cmos_frame_data (cmos_frame_data )   //��Ч����        
);




// wire [23:0]             cmos_frame_datas;

// assign cmos_frame_datas = {
//     cmos_frame_data[15:11], cmos_frame_data[15:13], // R: 5λ + ��3λ
//     cmos_frame_data[10:5] , cmos_frame_data[10:9] , // G: 6λ + ��2λ
//     cmos_frame_data[4:0]  , cmos_frame_data[4:2]    // B: 5λ + ��3λ
// };




reg         cam_vsync_r, cam_href_r;
reg [7:0]   cam_data_r;

reg [DATA_WIDTH-1 : 0] cmos_frame_data_r;
reg cmos_frame_valid_r, cmos_frame_href_r, cmos_frame_vsync_r;
always @(negedge cam_pclk) begin 
    cmos_frame_data_r <= cmos_frame_data ; 
    cmos_frame_valid_r <= cmos_frame_valid;
    cmos_frame_href_r <= cmos_frame_href ;
    cmos_frame_vsync_r <= cmos_frame_vsync;
end


ov5640_cdc #(
    .DATA_WIDTH(DATA_WIDTH),        ////////////////
    .DEVICE(DEVICE)
)
ov5640_cdc(
    .dbg_cdc_input(dbg_cdc_input),
    .dbg_cdc_output(dbg_cdc_output),
    .dbg_cdc_drop(dbg_cdc_drop),
    .dbg_cdc_seq(dbg_cdc_seq),
    .cam_clk(cam_pclk),
    .cam_rst(!cam_rst_n_cam),

    .s_data (cmos_frame_data_r )    , //////////////
    .s_valid(cmos_frame_valid_r)    ,
    .s_hsync(cmos_frame_href_r )    ,
    .s_vsync(cmos_frame_vsync_r)    ,

    .video_clk  (video_clk  ), 
    .video_rst  (video_rst  ),
    .video_data (video_data ),
    .video_valid(video_valid),
    .video_hsync(video_hsync),
    .video_vsync(video_vsync) 
);


endmodule
