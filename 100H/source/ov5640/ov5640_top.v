module ov5640_top #(
    parameter CAM1_RUNTIME = 1'b0,
    // [ROUTING 2026-10-31] 1: instantiate the per-camera motion tap (~1.5k LUT,
    // ~2.6k FF, 8 DRM each). 0: record/metadata read as zero (host treats the
    // optional motion hint as unavailable). Default off to relieve routing.
    parameter MOTION_TAP_EN = 1'b0,
    // Eligibility is independent of the legacy C1 global-mask owner.
    parameter RUNTIME_ENABLE = CAM1_RUNTIME,
    parameter [31:0] RUNTIME_BASE = 32'h20000800,
    parameter [31:0] RUNTIME_SIGNATURE = 32'h43314d31,
    // Mode 2 is advertised only by the C3/C4 v2 ABI.
    parameter RUNTIME_VGA_BYPASS = (RUNTIME_SIGNATURE == 32'h43334d32 ||
                                    RUNTIME_SIGNATURE == 32'h43344d32),
    //DVP�����λ��
    parameter [7:0] SENSOR_PLL_MULT = 8'h54,
    parameter DATA_WIDTH = 16,

    //AXI
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_LEN_WIDTH  = 32,
    parameter AXI_DATA_WIDTH = 128,

    //I2C
    parameter   SLAVE_ADDR = 7'h3c   ,  //I2C�ӻ���ַ
    parameter   BIT_CTRL   = 1'b1           , //OV5640���ֽڵ�ַΪ16λ  0:8λ 1:16λ
    parameter   CLK_FREQ   = 26'd25_000_000, //[CLKFIX] clk_50m = free_clk 25MHz, //ģ�������ʱ��Ƶ��
    parameter   I2C_FREQ   = 18'd250_000,    //IIC_SCL��ʱ��Ƶ��

    //����
    parameter  H_CMOS_DISP = 11'd640    , //CMOS�ֱ���--��
    parameter  V_CMOS_DISP = 11'd480    , //CMOS�ֱ���--��	
    parameter  TOTAL_H_PIXEL = 12'd1896, //ˮƽ�����ش�С (28.58֡)
    parameter  TOTAL_V_PIXEL = 12'd984 , // [56M/30fps]��ֱ�����ش�С (28.58֡)
    parameter  CAM_DATA_LEN  = H_CMOS_DISP * V_CMOS_DISP * DATA_WIDTH/8 / 16, //1280*720 * 2 /16

    //����ͷ������ƻ���ַ
    parameter BASE_ADDR = 32'h2000_0000,
    parameter [31:0] CAM_ADDR_1_DEF = 32'h0080_0000,
    parameter [31:0] CAM_ADDR_2_DEF = 32'h00A0_0000,
    parameter        CAM_EN_DEF     = 1'b1,

    //�忨�豸
    //IODELAY step for DVP sampling phase (0..255)
    parameter [7:0] IODELAY_STEP = 8'd40,
    parameter integer VSYNC_STABLE_CYCLES = 0,

    parameter DEVICE = "PG",

    // [VIP 2026-09-20] cam1 RGB565 median filtering.
    //   MEDIAN_EN=0 -> the stream is bypassed bit-exactly (cam2 default)
    //   MEDIAN_EN=1 -> 3x3 median independently on R/G/B, with replicated
    //                  image boundaries and one pixel accepted per clock.
    parameter        MEDIAN_EN      = 1'b0,
    parameter [2:0]  MEDIAN_RSVD    = 3'd0,
    // [VKFS 2026-09-25] cam1 temporal Kalman/IIR after the median stage.
    //   KF_EN=0 -> pure bypass (cam2 default). The previous-frame state is
    //   read back from the other DDR ping-pong bank via kf_* (a free
    //   crossbar slave port), so no on-chip full-frame buffer is needed.
    parameter        KF_EN          = 1'b0,
    parameter [5:0]  KF_THR0        = 6'd3,
    parameter [5:0]  KF_THR1        = 6'd8,
    parameter [5:0]  KF_THR2        = 6'd20,
parameter        KF_RD_EN = 1'b1,
    parameter        DOWNSAMPLE_2X2 = 1'b0
)(
    // input         pl_clk                ,  //��ʱ��
    output wire [319:0] motion_record,
    output wire [191:0] motion_frame_metadata,
    output wire [31:0] lease_prev_base, lease_bank0, lease_bank1, lease_sequence,
    output wire [1:0] lease_published,
    output wire lease_writer_idle, lease_pending, lease_flush,
    input wire capture_hold,
    input wire runtime_dma_idle,
    input wire [5:0] runtime_idle_raw,
    output wire [5:0] runtime_allowed_mask,
    input         clk_50m               ,
    input         dbg_locked            ,
    input         dbg_btn_rst_n         ,
    input         dbg_axi_awvalid       ,
    input         dbg_axi_awready       ,
    input         dbg_axi_wvalid        ,
    input         dbg_axi_wready        ,
    input         dbg_axi_bvalid        ,
    input         dbg_axi_bready        ,
    input         clk_50m_rst_n         ,
    input         lane_enable           ,
    input  [7:0]  lane_white_min        ,
    input  [7:0]  lane_white_span       ,
    input  [7:0]  lane_min_run          ,
    input  [3:0]  lane_line_width       ,
    output [15:0] lane_left_count       ,
    output [15:0] lane_right_count      ,
    output [31:0] lane_frame_sequence   ,
    output        lane_left_valid       ,
    output        lane_right_valid      ,
    output wire   lane_div_req_valid    ,
    input  wire   lane_div_req_ready    ,
    output wire [63:0] lane_div_req_dividend,
    output wire [63:0] lane_div_req_divisor,
    input  wire   lane_div_rsp_valid    ,
    input  wire [127:0] lane_div_rsp_data,
    //����ͷ�ӿ�
    input         cam_pclk              ,  //cmos ��������ʱ��
    input         cam_vsync             ,  //cmos ��ͬ����
    input         cam_href              ,  //cmos ��ͬ����
    input [7 : 0] cam_data              ,  //cmos ����
    output        cam_rst_n             ,  //cmos ��λ�źţ��͵�ƽ��Ч
    output        cam_pwdn              ,  //��Դ����ģʽѡ�� 0������ģ 1����Դ����ģ
    output        cam_scl               ,  //cmos SCCB_SCL
    inout         cam_sda               ,  //cmos SCCB_SDA   


    //����ͷ���ƼĴ���
    input                             s_axi_awvalid         /*synthesis PAP_MARK_DEBUG="1"*/,
    output                            s_axi_awready         /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_awaddr          /*synthesis PAP_MARK_DEBUG="1"*/,

    input                             s_axi_wvalid          /*synthesis PAP_MARK_DEBUG="1"*/,
    output                            s_axi_wready          /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_wdata           /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH/8-1 : 0]   s_axi_wstrb           /*synthesis PAP_MARK_DEBUG="1"*/,

    output                            s_axi_bvalid          /*synthesis PAP_MARK_DEBUG="1"*/,
    input                             s_axi_bready          /*synthesis PAP_MARK_DEBUG="1"*/,
    output [ 1 : 0]                   s_axi_bresp           /*synthesis PAP_MARK_DEBUG="1"*/,

    input                             s_axi_arvalid         /*synthesis PAP_MARK_DEBUG="1"*/,
    output                            s_axi_arready         /*synthesis PAP_MARK_DEBUG="1"*/,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_araddr          /*synthesis PAP_MARK_DEBUG="1"*/,

    output                            s_axi_rvalid          /*synthesis PAP_MARK_DEBUG="1"*/,
    input                             s_axi_rready          /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_ADDR_WIDTH-1 : 0]     s_axi_rdata           /*synthesis PAP_MARK_DEBUG="1"*/,
    output [ 1 : 0]                   s_axi_rresp           /*synthesis PAP_MARK_DEBUG="1"*/,



    //����ͷAXI_stream����
    input                          video_clk      /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          video_rst      /*synthesis PAP_MARK_DEBUG="1"*/,
    input                         cam_dma_abort,
    output                        cam_dma_abort_req,
    output [15:0]                 cam_s_data_available,
    input                         cam_dma_done   ,  // [LEDGER 2026-09-19] DMA transaction-done pulse
    output [AXI_ADDR_WIDTH-1 : 0]  cam_cmd_addr    /*synthesis PAP_MARK_DEBUG="1"*/,
    output [AXI_LEN_WIDTH-1 : 0]   cam_cmd_len     /*synthesis PAP_MARK_DEBUG="1"*/,
    output                         cam_cmd_valid   /*synthesis PAP_MARK_DEBUG="1"*/,
    input                          cam_cmd_ready   /*synthesis PAP_MARK_DEBUG="1"*/,

    output [AXI_DATA_WIDTH-1 : 0] cam_s_data       /*synthesis PAP_MARK_DEBUG="1"*/,
    output                        cam_s_data_valid /*synthesis PAP_MARK_DEBUG="1"*/,
    output                        cam_s_data_last  /*synthesis PAP_MARK_DEBUG="1"*/,
    input                         cam_s_data_ready /*synthesis PAP_MARK_DEBUG="1"*/,

    //����DMA����������
    input                         xdma_clk  ,
    output  [1 : 0]               xdma_irq   /*synthesis PAP_MARK_DEBUG="1"*/,

    // [VKFS 2026-09-25] previous-frame DDR read master (driven when KF_EN=1)
    output                        kf_arvalid,
    input                         kf_arready,
    output [AXI_ADDR_WIDTH-1 : 0] kf_araddr,
    output [7 : 0]                kf_arlen,
    output [2 : 0]                kf_arsize,
    output [1 : 0]                kf_arburst,
    output                        kf_arlock,
    output [3 : 0]                kf_arcache,
    output [2 : 0]                kf_arprot,
    output [3 : 0]                kf_arid,
    output                        kf_rready,
    input  [3 : 0]                kf_rid,
    input  [AXI_DATA_WIDTH-1 : 0] kf_rdata,
    input  [1 : 0]                kf_rresp,
    input                         kf_rlast,
    input                         kf_rvalid
);


    // wire clk_50m;
    // wire video_clk;
    // wire locked;
    // wire clk_50m_rst_n = locked     ;
// generate
//     if(DEVICE == "PG") begin
//         ov5640_clk ov5640_clk(
//           .clkout0(clk_50m),      // output 50M
//         //   .clkout1(video_clk),    // output 200M
//           .lock(locked),          // output
//           .clkin1(pl_clk)         // input
//         );
//     end
//     else if(DEVICE == "Xilinx") begin
//         ov5640_clk ov5640_clk
//         (
//             // Clock out ports
//             .clk_out1(clk_50m ),    // output 50M
//             // .clk_out2(video_clk ),  // output 200M
//             // Status and control signals
//             .locked(locked),        // output locked
//            // Clock in ports
//             .clk_in1(pl_clk)        // input clk_in1
//         );  
//     end
// endgenerate


    
    wire                    video_vsync ;
    wire                    video_hsync ;
    wire                    video_valid ;
    wire [DATA_WIDTH-1 : 0] video_data  ;
    wire [31:0] dbg_cdc_input;
    wire [31:0] dbg_cdc_output;
    wire [31:0] dbg_cdc_drop;
    wire [31:0] dbg_cdc_seq;
    wire [31:0]   dbg_i2c_status;
    wire [31:0]   dbg_pclk_cnt;
    wire [31:0]   dbg_sys_status;
    wire [31:0]   dbg_href_raw;
    wire [31:0]   dbg_vsync_raw;

// ---------------- �����޸�����ʹ�� GTP_IODELAY_E2 ���о�ϸ�ӳٵ��� ----------------
    
    // ���������ӳٵ�������ź�
    wire         cam_vsync_dly;
    wire         cam_href_dly;
    wire [7 : 0] cam_data_dly;
    // [CAM3DLY 2026-09-27] runtime DVP sampling delay (from ov5640_reg).
    wire [7 : 0] reg_dly_step;
    
    // �����ӳٲ���ֵ (0~255)
    // IODELAY_STEP is a header parameter now (overridable per instance)

    // --- �����ź��ӳ����� ---
    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PORT"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_vsync (
        .DO         (cam_vsync_dly),  
        .DELAY_SEL  (1'b0),
        .DI         (cam_vsync),     
        .EN_N       (1'b0),
        .DELAY_STEP (reg_dly_step)  
    );

    GTP_IODELAY_E2 #(
        .DELAY_STEP_VALUE(IODELAY_STEP),
        .DELAY_STEP_SEL("PORT"),
        .TDELAY_EN("FALSE") 
    ) u_iodelay_href (
        .DO         (cam_href_dly),  
        .DELAY_SEL  (1'b0),
        .DI         (cam_href),     
        .EN_N       (1'b0),
        .DELAY_STEP (reg_dly_step)  
    );

    // --- �����ź�(cam_data)�ӳ����� ---
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : cam_data_iodelay
            GTP_IODELAY_E2 #(
                .DELAY_STEP_VALUE(IODELAY_STEP),
                .DELAY_STEP_SEL("PORT"),
                .TDELAY_EN("FALSE") 
            ) u_iodelay_data (
                .DO         (cam_data_dly[i]),  
                .DELAY_SEL  (1'b0),
                .DI         (cam_data[i]),     
                .EN_N       (1'b0),
                .DELAY_STEP (reg_dly_step)  
            );
        end
    endgenerate
// ---------------- �����޸����� ���� ----------------


    // [PT 2026-09-26] host SCCB passthrough: video_clk (ov5640_reg) <-> dri_clk
    // (ov5640/i2c_dri). Command path is data+toggle (stable data; the toggle is
    // synchronized in dri_clk inside ov5640). Result uses an acknowledged bundle.
    wire [31:0] diag_accepted_seq, diag_accepted_payload;
    wire [511:0] diag_native_snapshot, diag_host_snapshot;
    wire [31:0] diag_generation;
    wire diag_event, diag_clk;
    wire diag_rst_n = clk_50m_rst_n && !video_rst;
    (* ASYNC_REG = "TRUE", syn_srlstyle = "registers" *) reg [2:0] host_diag_release;
    always @(posedge video_clk or negedge diag_rst_n) begin
        if(!diag_rst_n) host_diag_release<=3'b000;
        else host_diag_release<={host_diag_release[1:0],1'b1};
    end
    wire host_diag_rst_n=host_diag_release[2];
    sccb_diag_mailbox diag_mailbox (
        .src_clk(diag_clk), .dst_clk(video_clk), .rst_n(diag_rst_n),
        .src_event(diag_event), .src_snapshot(diag_native_snapshot),
        .dst_snapshot(diag_host_snapshot), .dst_generation(diag_generation));
    wire        pt_req_toggle;
    wire        pt_rw;
    wire [15:0] pt_addr;
    wire [ 7:0] pt_wdata;
    wire [ 7:0] pt_rdata;
    wire        pt_ack;
    wire        pt_done_toggle;
    wire [31:0] pt_seq, pt_seq_dst;
    wire [7:0] pt_rdata_dst;
    wire pt_ack_dst, pt_done_dst, pt_fault_dst;
    sccb_functional_mailbox functional_mailbox (
        .src_clk(diag_clk), .dst_clk(video_clk), .rst_n(diag_rst_n),
        .src_done_toggle(pt_done_toggle), .src_data(pt_rdata),
        .src_ack(pt_ack), .src_seq(pt_seq), .dst_data(pt_rdata_dst),
        .dst_ack(pt_ack_dst), .dst_seq(pt_seq_dst),
        .dst_done_toggle(pt_done_dst), .dst_fault(pt_fault_dst));

    ov5640 #(
        .SENSOR_PLL_MULT(SENSOR_PLL_MULT),
        //DVP����
        .DATA_WIDTH(DATA_WIDTH),
        //I2C
        .VSYNC_STABLE_CYCLES(VSYNC_STABLE_CYCLES),
        .SLAVE_ADDR(SLAVE_ADDR)   ,      //I2C�ӻ���ַ
        .BIT_CTRL  (BIT_CTRL)     ,      //OV5640���ֽڵ�ַΪ16λ  0:8λ 1:16λ
        .CLK_FREQ  (CLK_FREQ)     ,      //ģ�������ʱ��Ƶ��
        .I2C_FREQ  (I2C_FREQ)     ,      //IIC_SCL��ʱ��Ƶ��

        //����
        .H_CMOS_DISP(H_CMOS_DISP), //CMOS�ֱ���--��
        .V_CMOS_DISP(V_CMOS_DISP), //CMOS�ֱ���--��	
        .TOTAL_H_PIXEL(TOTAL_H_PIXEL), //ˮƽ�����ش�С
        .TOTAL_V_PIXEL(TOTAL_V_PIXEL), //��ֱ�����ش�С

        //�忨�豸
        .DEVICE(DEVICE)
    )
    ov5640(
        .clk_50m            (clk_50m      ),  // i2c�Ĳο�ʱ��Clock
        .rst_n              (clk_50m_rst_n),  // Asynchronous reset active low

        .ov_rst_n           (ov_rst_n ),
        .cam_pclk           (cam_pclk ),  //cmos ��������ʱ��
        // ʹ�þ����ӳٴ������ź��滻ԭʼ�ܽ��ź�
        .cam_vsync          (cam_vsync_dly),  //cmos ��ͬ���ź� 
        .cam_href           (cam_href_dly ),  //cmos ��ͬ���ź�
        .cam_data           (cam_data_dly ),  //cmos ����
        
        .cam_rst_n          (cam_rst_n),  //cmos ��λ�źţ��͵�ƽ��Ч
        .cam_pwdn           (cam_pwdn ),  //��Դ����ģʽѡ�� 0������ģʽ 1����Դ����ģʽ
        .cam_scl            (cam_scl  ),  //cmos SCCB_SCL��
        .cam_sda            (cam_sda  ),  //cmos SCCB_SDA��     

        .video_clk          (video_clk  ),  // ���Ϻ��RGB��ȡʱ��
        .video_rst          (video_rst  ),
        .video_vsync        (video_vsync),  //֡��Ч�ź�    
        .video_hsync        (video_hsync),  //����Ч�ź�
        .video_valid        (video_valid),  //������Чʹ���ź�
        .video_data         (video_data ),  //��Ч����
    .dbg_cdc_input(dbg_cdc_input),
    .dbg_cdc_output(dbg_cdc_output),
    .dbg_cdc_drop(dbg_cdc_drop),
    .dbg_cdc_seq(dbg_cdc_seq),
        .dbg_i2c_status     (dbg_i2c_status),
        .dbg_pclk_cnt       (dbg_pclk_cnt ),
        .dbg_sys_status     (dbg_sys_status),
        .dbg_href_raw       (dbg_href_raw  ),
        .dbg_vsync_raw      (dbg_vsync_raw ),

        // [PT 2026-09-26] host SCCB passthrough
        .diag_seq(diag_accepted_seq), .diag_payload(diag_accepted_payload),
        .diag_rst_n(diag_rst_n), .diag_snapshot(diag_native_snapshot),
        .diag_event(diag_event), .diag_clk(diag_clk),
        .pt_req_toggle      (pt_req_toggle),
        .pt_rw              (pt_rw        ),
        .pt_addr            (pt_addr      ),
        .pt_wdata           (pt_wdata     ),
        .pt_seq             (pt_seq       ),
        .pt_rdata           (pt_rdata     ),
        .pt_ack             (pt_ack       ),
        .pt_done_toggle     (pt_done_toggle)

    
    );

    // ------------- VIP: RGB565 3x3 median filter, cam1 only -------------
    // Taps the 16-bit RGB565 stream produced by the capture block and hands it to
    // the DDR write packer. The module owns 2 line buffers (~2 lines of latency),
    // re-times vsync and drops the camera tail dummy beat, so ov5640_ddr still sees
    // exactly W*H pixels per frame. MEDIAN_EN=0 selects a pure wire bypass, so a
    // camera without filtering keeps its original timing and uses no BRAM.
    wire                    sh_video_valid;
    wire [DATA_WIDTH-1 : 0] sh_video_data ;
    wire                    sh_video_vsync;

    generate
        if (MEDIAN_EN) begin : g_median
            vip #(
                .W       (H_CMOS_DISP),
                .H       (V_CMOS_DISP),
                .STRIDE  (1024),
                .AW      (10),
                // Keep the retimed frame marker separate from data without
                // creating a large producer/consumer backlog at frame end.
                .GAP_LEN (8)
            ) u_vip (
                .clk       (video_clk      ),
                .rst       (video_rst      ),
                .en        (1'b1           ),
                .strength  (MEDIAN_RSVD    ),
                .in_valid  (video_valid    ),
                .in_pixel  (video_data     ),
                .in_vsync  (video_vsync    ),
                .out_valid (sh_video_valid ),
                .out_pixel (sh_video_data  ),
                .out_vsync (sh_video_vsync )
            );
        end
        else begin : g_bypass
            assign sh_video_valid = video_valid;
            assign sh_video_data  = video_data ;
            assign sh_video_vsync = video_vsync;
        end
    endgenerate

    // [FIR3 2026-09-26] cam1 FIR filter: hand-written transparent 3-tap
    // [1 2 1]/4 core (cam_fir3.v) replacing the Pango ipsxe FIR IP whose
    // encrypted core dropped beats on the live camera stream and wedged the
    // DDR write packer. Unsigned per-channel math, 1-cycle latency, one
    // output beat per input beat.
    wire                      fir_video_valid;
    wire [DATA_WIDTH-1 : 0]   fir_video_data ;
    wire                      fir_video_vsync;

    cam_fir3 #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_cam_fir3 (
        .clk       (video_clk      ),
        .rst       (video_rst      ),
        .in_valid  (sh_video_valid ),
        .in_pixel  (sh_video_data  ),
        .in_vsync  (sh_video_vsync ),
        .out_valid (fir_video_valid),
        .out_pixel (fir_video_data ),
        .out_vsync (fir_video_vsync)
    );

    // [VKFS 2026-09-25] legacy temporal-filter path follows the FIR output.
    // Keeps W*H pixels/frame and the single-beat s_valid contract; only pixel
    // values change. Previous frame comes from the other ping-pong bank.
    wire                      kf_video_valid;
    wire [DATA_WIDTH-1 : 0]   kf_video_data ;
    wire                      kf_video_vsync;
    wire [AXI_ADDR_WIDTH-1:0] kf_prev_base;

    generate
        if (KF_EN) begin : g_kf
            vip_kf_stream #(
                .W (H_CMOS_DISP),
                .H (V_CMOS_DISP),
                .AW (19),
                .AXI_ID_WIDTH (4),
                .AXI_DATA_W   (AXI_DATA_WIDTH),
                .BURST_LEN    (8),
                .RD_EN        (KF_RD_EN)
            ) u_kf_stream (
                .clk        (video_clk),
                .rst        (video_rst),
                .en         (1'b1),
                .thr0       (KF_THR0),
                .thr1       (KF_THR1),
                .thr2       (KF_THR2),
                .in_valid   (fir_video_valid),
                .in_pixel   (fir_video_data ),
                .in_vsync   (fir_video_vsync),
                .prev_base  (kf_prev_base),
                .m_axi_arid    (kf_arid),
                .m_axi_araddr  (kf_araddr),
                .m_axi_arlen   (kf_arlen),
                .m_axi_arsize  (kf_arsize),
                .m_axi_arburst (kf_arburst),
                .m_axi_arlock  (kf_arlock),
                .m_axi_arcache (kf_arcache),
                .m_axi_arprot  (kf_arprot),
                .m_axi_arvalid (kf_arvalid),
                .m_axi_arready (kf_arready),
                .m_axi_rid     (kf_rid),
                .m_axi_rdata   (kf_rdata),
                .m_axi_rresp   (kf_rresp),
                .m_axi_rlast   (kf_rlast),
                .m_axi_rvalid  (kf_rvalid),
                .m_axi_rready  (kf_rready),
                .out_valid  (kf_video_valid),
                .out_pixel  (kf_video_data ),
                .out_vsync  (kf_video_vsync)
            );
        end
        else begin : g_kf_bypass
            assign kf_video_valid = fir_video_valid;
            assign kf_video_data  = fir_video_data ;
            assign kf_video_vsync = fir_video_vsync;
            assign kf_arvalid = 1'b0;
            assign kf_araddr  = {AXI_ADDR_WIDTH{1'b0}};
            assign kf_arlen   = 8'd0;
            assign kf_arsize  = 3'd0;
            assign kf_arburst = 2'b01;
            assign kf_arlock  = 1'b0;
            assign kf_arcache = 4'd0;
            assign kf_arprot  = 3'd0;
            assign kf_arid    = 4'd0;
            assign kf_rready  = 1'b1;
        end
    endgenerate

    // wire video_rst = !locked;

    // Reduce only C3/C4 before the existing DDR packer and tag publisher.
    wire [DATA_WIDTH-1:0] store_video_data;
    wire store_video_valid, store_video_hsync, store_video_vsync;
    wire [1:0] runtime_mode;
    wire runtime_safe;
    generate
        if (DOWNSAMPLE_2X2) begin : g_cam34_downsample
            cam34_downsample_2x2 #(.IN_W(H_CMOS_DISP), .IN_H(V_CMOS_DISP)) u_downsample (
                .clk(video_clk), .rst(video_rst || runtime_safe),
                .bypass(RUNTIME_ENABLE && (runtime_mode == 2'd1 || runtime_mode == 2'd2)), .in_valid(kf_video_valid),
                .in_pixel(kf_video_data), .in_hsync(video_hsync), .in_vsync(kf_video_vsync),
                .out_valid(store_video_valid), .out_pixel(store_video_data),
                .out_hsync(store_video_hsync), .out_vsync(store_video_vsync));
        end else begin : g_cam_full_frame
            assign store_video_data=kf_video_data;
            assign store_video_valid=kf_video_valid;
            assign store_video_hsync=video_hsync;
            assign store_video_vsync=kf_video_vsync;
        end
    endgenerate
    wire [DATA_WIDTH-1:0] lane_video_data;
    wire lane_video_valid, lane_video_vsync;
    // [LANE_REC] lane results travel in the frame tag; pixels stay raw.
    wire lane_rec_valid;
    wire [95:0] lane_rec_data;
    wire lane_rec_wait = CAM1_RUNTIME && !DOWNSAMPLE_2X2 &&
                         (!RUNTIME_ENABLE || runtime_mode != 2'd2);
    lane_roi_overlay #(
        .CHANNEL_ID(0),
        .SRC_WIDTH(H_CMOS_DISP), .SRC_HEIGHT(V_CMOS_DISP),
        .ROI_Y(V_CMOS_DISP > 360 ? V_CMOS_DISP-360 : 0),
        .ROI_WIDTH(H_CMOS_DISP), .ROI_HEIGHT(V_CMOS_DISP > 360 ? 360 : V_CMOS_DISP)
    ) u_lane_roi_overlay (
        .clk(video_clk), .rst_n(!video_rst),
        .enable(lane_enable && lane_rec_wait),
        .src_height(V_CMOS_DISP), .rec_valid(lane_rec_valid), .rec_data(lane_rec_data),
        .white_min(lane_white_min), .white_span(lane_white_span),
        .min_run(lane_min_run), .line_width(lane_line_width),
        .s_rgb565(store_video_data), .s_de(store_video_valid),
        .s_hs(store_video_hsync), .s_vs(store_video_vsync),
        .m_rgb565(lane_video_data), .m_de(lane_video_valid),
        .m_hs(), .m_vs(lane_video_vsync),
        .frame_left_count(lane_left_count), .frame_right_count(lane_right_count),
        .frame_sequence(lane_frame_sequence),
        .model_left_valid(lane_left_valid), .model_right_valid(lane_right_valid),
        .div_req_valid(lane_div_req_valid), .div_req_ready(lane_div_req_ready),
        .div_req_dividend(lane_div_req_dividend), .div_req_divisor(lane_div_req_divisor),
        .div_rsp_valid(lane_div_rsp_valid), .div_rsp_data(lane_div_rsp_data)
    );
    wire                        cam_en    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_ADDR_WIDTH-1 : 0] cam_addr_1/*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_ADDR_WIDTH-1 : 0] cam_addr_2/*synthesis PAP_MARK_DEBUG="1"*/;
    wire [1 : 0]  xdma_req  ;  
    reg  [31:0]   dbg_beat_cnt;
    reg  [31:0]   dbg_beat_last;
    reg  [31:0]   dbg_cmd_cnt;
wire [31:0]   dbg_axi_cnt;
wire [31:0]   dbg_axi_num;
wire [31:0]   dbg_zdin;
wire [31:0]   dbg_zout;
    wire [31:0]   dbg_state;
    wire [31:0]   dbg_last_cnt;
    wire [31:0]   dbg_wd_cnt;
    reg  [15:0]   dbg_axi_sticky;
    reg  [15:0]   dbg_b_cnt;
    reg  [15:0]   dbg_aw_cnt;
    reg  [15:0]   dbg_w_cnt;
    wire [15:0]   dbg_axi_stat;
    reg  [31:0]   dbg_clk_status;
    wire [1 : 0]  xdma_ack  ; 
    wire [31:0] diag_fault_snapshot, diag_reject_counts, diag_input_pixels;
    generate if (MOTION_TAP_EN) begin : g_motion_tap
    motion_runtime_tap #(.WIDTH(H_CMOS_DISP), .HEIGHT(V_CMOS_DISP),
        .FRAME_BYTES(CAM_DATA_LEN*32'd16),
        .TRANSPORT_GEOMETRY(DOWNSAMPLE_2X2 ? 32'h014000f0 : 32'h028001e0)) u_motion_tap (
        .clk(video_clk), .rst_n(!video_rst),
        .hd_mode(RUNTIME_ENABLE && runtime_mode == 2'd1),
        .vga_mode(RUNTIME_ENABLE && runtime_mode == 2'd2), .parked(capture_hold),
        .pixel_rgb565(kf_video_data), .pixel_valid(kf_video_valid),
        .vsync(kf_video_vsync), .raw_retired_tag(lease_sequence),
        .published_banks(lease_published), .motion_record(motion_record),
        .frame_metadata(motion_frame_metadata));
    end else begin : g_no_motion_tap
        assign motion_record = 320'd0;
        assign motion_frame_metadata = 192'd0;
    end endgenerate
    localparam MAX_FRAME_BEATS = RUNTIME_ENABLE ? 115200 : CAM_DATA_LEN;
    // MMIO and writer share video_clk. Host holds the lease until SCCB
    // completes; capture/FIFO/control pipelines drain before mode changes.
    assign runtime_safe = capture_hold && runtime_dma_idle && lease_writer_idle && !lease_pending && !lease_flush;
    wire [$clog2(MAX_FRAME_BEATS):0] runtime_beats = RUNTIME_ENABLE ?
        (runtime_mode == 2'd1 ? 115200 :
         (runtime_mode == 2'd2 ? 38400 : CAM_DATA_LEN)) : CAM_DATA_LEN;
    ov5640_ddr #(
        .DATA_WIDTH(DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_LEN_WIDTH(AXI_LEN_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .CAM_DATA_LEN(MAX_FRAME_BEATS),
        .DEVICE(DEVICE)
    )
    ov5640_ddr(
        .axi_clk        (video_clk),
        .axi_rst        (video_rst), 

        .axi_cam_en     (cam_en && !capture_hold),
        .dbg_fault_snapshot(diag_fault_snapshot),
        .dbg_reject_counts(diag_reject_counts),
        .dbg_input_pixels(diag_input_pixels),
        .dma_abort      (cam_dma_abort),
        .dma_abort_req  (cam_dma_abort_req),
        .axi_data_available(cam_s_data_available),
        .dma_done       (cam_dma_done),  // [LEDGER 2026-09-19]
        .cam_data_addr_1(cam_addr_1),
        .cam_data_addr_2(cam_addr_2),
        .prev_frame_base(kf_prev_base),
        .lease_prev_base(lease_prev_base),.lease_bank0(lease_bank0),.lease_bank1(lease_bank1),
        .lease_published(lease_published),.lease_sequence(lease_sequence),
        .lease_writer_idle(lease_writer_idle),.lease_pending(lease_pending),.lease_flush(lease_flush),
        .cam_data_len   (runtime_beats), // 16-byte beats, video_clk domain

        .s_data(store_video_data),
        .s_data_valid(store_video_valid),
        .s_hsync(store_video_hsync),
        .s_vsync(store_video_vsync),
        .lane_wait(lane_rec_wait), .lane_rec_valid(lane_rec_valid), .lane_rec(lane_rec_data),

        //AXIЭ���
        .axi_data       (cam_s_data      ),
        .axi_data_valid (cam_s_data_valid),
        .axi_data_last  (cam_s_data_last ), 
        .axi_data_ready (cam_s_data_ready),

        .axi_cmd_addr   (cam_cmd_addr  ),
        .axi_cmd_len    (cam_cmd_len   ),
        .axi_cmd_valid  (cam_cmd_valid ),
        .axi_cmd_ready  (cam_cmd_ready ),

        .dbg_axi_cnt    (dbg_axi_cnt   ),
        .dbg_axi_num    (dbg_axi_num   ),
        .dbg_zdin       (dbg_zdin      ),
        .dbg_zout       (dbg_zout      ),
        .dbg_state      (dbg_state     ),
        .dbg_last_cnt   (dbg_last_cnt  ),
        .dbg_wd_cnt     (dbg_wd_cnt    ),
        .xdma_req       (xdma_req      ),
        .xdma_ack       (xdma_ack      ) 
    );




    // VSYNC high widths in video_clk cycles (pre-FIR), saturating at 65535.
    // Minimum ignores reset's initial partial pulse; first complete pulse seeds it.
    reg diag_vs_q;
    reg [15:0] diag_vs_width, diag_vs_last, diag_vs_min;
    always @(posedge video_clk) begin
        if(video_rst) begin
            diag_vs_q <= 0;
            diag_vs_width <= 0;
            diag_vs_last <= 0;
            diag_vs_min <= 16'hffff;
        end else begin
            diag_vs_q <= video_vsync;
            if(video_vsync) begin
                if(!diag_vs_q) diag_vs_width <= 1;
                else if(diag_vs_width != 16'hffff) diag_vs_width <= diag_vs_width + 1'b1;
            end else if(diag_vs_q) begin
                diag_vs_last <= diag_vs_width;
                if(diag_vs_width < diag_vs_min) diag_vs_min <= diag_vs_width;
            end
        end
    end
    // [DBG] camera activity counters (read via ov5640_reg +0x30/+0x34)
    reg [31:0] dbg_cam_words;
    always @(posedge video_clk) begin
        if (video_rst) dbg_cam_words <= 32'd0;
        else if (cam_s_data_valid) dbg_cam_words <= dbg_cam_words + 32'd1;
    end
    reg [31:0] dbg_vsyncs;
    reg [2:0]  dbg_vs_ff;
    always @(posedge video_clk) dbg_vs_ff <= {dbg_vs_ff[1:0], video_vsync};
    always @(posedge video_clk) begin
        if (video_rst) dbg_vsyncs <= 32'd0;
        else if (dbg_vs_ff[2:1] == 2'b01) dbg_vsyncs <= dbg_vsyncs + 32'd1;
    end
    // [DBG] href (hsync) activity counter -> ov5640_reg +0x50
    reg [31:0] dbg_hsyncs;
    reg [2:0]  dbg_hs_ff;
    always @(posedge video_clk) dbg_hs_ff <= {dbg_hs_ff[1:0], video_hsync};
    always @(posedge video_clk) begin
        if (video_rst) dbg_hsyncs <= 32'd0;
        else if (dbg_hs_ff[2:1] == 2'b01) dbg_hsyncs <= dbg_hsyncs + 32'd1;
    end
    // [DIAG] AXI beat accounting: how many beats does the engine actually see
    // per camera frame? If this != CAM_DATA_LEN the write FSM deadlocks.
    reg [2:0] dbg_fs_ff;
    always @(posedge video_clk) dbg_fs_ff <= {dbg_fs_ff[1:0], video_vsync};
    wire dbg_frame_edge = (dbg_fs_ff[2:1] == 2'b01);
    always @(posedge video_clk) begin
        if (video_rst) begin
            dbg_beat_cnt  <= 32'd0;
            dbg_beat_last <= 32'd0;
        end
        else if (dbg_frame_edge) begin
            dbg_beat_last <= dbg_beat_cnt;
            dbg_beat_cnt  <= 32'd0;
        end
        else if (cam_s_data_valid & cam_s_data_ready) begin
            dbg_beat_cnt <= dbg_beat_cnt + 32'd1;
        end
    end
    // [DIAG] AXI write handshake visibility (which stage ever happened?)
    // [DIAG2] numeric handshake counters (sticky only says "ever", not "how many")
    always @(posedge video_clk) begin
        if (video_rst) begin
            dbg_b_cnt  <= 16'd0;
            dbg_aw_cnt <= 16'd0;
            dbg_w_cnt  <= 16'd0;
        end
        else begin
            if (dbg_axi_bvalid & dbg_axi_bready) dbg_b_cnt  <= dbg_b_cnt  + 16'd1;
            if (dbg_axi_awvalid & dbg_axi_awready) dbg_aw_cnt <= dbg_aw_cnt + 16'd1;
            if (dbg_axi_wvalid & dbg_axi_wready)  dbg_w_cnt  <= dbg_w_cnt  + 16'd1;
        end
    end
    assign dbg_axi_stat = {5'd0,
        dbg_axi_bready, dbg_axi_bvalid,
        (cam_s_data_valid & cam_s_data_ready),
        cam_s_data_ready, cam_s_data_valid,
        (dbg_axi_wvalid & dbg_axi_wready), dbg_axi_wready, dbg_axi_wvalid,
        (dbg_axi_awvalid & dbg_axi_awready), dbg_axi_awready, dbg_axi_awvalid};
    always @(posedge video_clk) begin
        if (video_rst) dbg_axi_sticky <= 16'd0;
        else           dbg_axi_sticky <= dbg_axi_sticky | dbg_axi_stat;
    end
    // [DIAG] frame commands issued by ov5640_ddr_w_ctrl (idle->addr transitions)
    reg dbg_cmd_d;
    always @(posedge video_clk) begin
        if (video_rst) begin
            dbg_cmd_d   <= 1'b0;
            dbg_cmd_cnt <= 32'd0;
        end
        else begin
            dbg_cmd_d <= cam_cmd_valid;
            if (cam_cmd_valid & ~dbg_cmd_d)
                dbg_cmd_cnt <= dbg_cmd_cnt + 32'd1;
        end
    end

// [DBG] clk_50m activity counter + lock/button snapshot (sampled in video_clk)
reg [15:0] dbg_clk50_cnt;
always @(posedge clk_50m) dbg_clk50_cnt <= dbg_clk50_cnt + 16'd1;
always @(posedge video_clk) dbg_clk_status <= {dbg_clk50_cnt, dbg_locked, dbg_btn_rst_n};
    ov5640_reg #(
        .CAM1_RUNTIME(CAM1_RUNTIME),
        .RUNTIME_ENABLE(RUNTIME_ENABLE), .RUNTIME_BASE(RUNTIME_BASE),
        .RUNTIME_SIGNATURE(RUNTIME_SIGNATURE), .RUNTIME_VGA_BYPASS(RUNTIME_VGA_BYPASS),

        .BASE_ADDR(BASE_ADDR),
        .FRAME_W(DOWNSAMPLE_2X2 ? H_CMOS_DISP/2 : H_CMOS_DISP),
        .FRAME_H(DOWNSAMPLE_2X2 ? V_CMOS_DISP/2 : V_CMOS_DISP),
        .FRAME_BYTES(CAM_DATA_LEN*16),
        .CAM_ADDR_1_DEF(CAM_ADDR_1_DEF),
        .CAM_ADDR_2_DEF(CAM_ADDR_2_DEF),
        .CAM_EN_DEF   (CAM_EN_DEF   ),
        .DLY_STEP_DEF (IODELAY_STEP),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) 
    ov5640_reg(
        .runtime_idle_raw(runtime_idle_raw), .runtime_allowed_mask(runtime_allowed_mask),
        .runtime_safe(runtime_safe), .runtime_mode(runtime_mode),
        .clk                   (video_clk    ),
        .rst                   (video_rst    ),

        .s_axi_awvalid         (s_axi_awvalid),
        .s_axi_awready         (s_axi_awready),
        .s_axi_awaddr          (s_axi_awaddr ),

        .s_axi_wvalid          (s_axi_wvalid ),
        .s_axi_wready          (s_axi_wready ),
        .s_axi_wdata           (s_axi_wdata  ),
        .s_axi_wstrb           (s_axi_wstrb  ),

        .s_axi_bvalid          (s_axi_bvalid ),
        .s_axi_bready          (s_axi_bready ),
        .s_axi_bresp           (s_axi_bresp  ),

        .s_axi_arvalid         (s_axi_arvalid),
        .s_axi_arready         (s_axi_arready),
        .s_axi_araddr          (s_axi_araddr ),

        .s_axi_rvalid          (s_axi_rvalid ),
        .s_axi_rready          (s_axi_rready ),
        .s_axi_rdata           (s_axi_rdata  ),
        .s_axi_rresp           (s_axi_rresp  ),

        .xdma_ack              (xdma_ack     ),
        .cam_en                (cam_en       ),
        .dly_step              (reg_dly_step ),
        .cam_addr_1            (cam_addr_1   ), 
        .cam_addr_2            (cam_addr_2   ),
    .dbg_cdc_input(dbg_cdc_input),
    .dbg_cdc_output(dbg_cdc_output),
    .dbg_cdc_drop(dbg_cdc_drop),
    .dbg_cdc_seq(dbg_cdc_seq),
        .dbg_fault_snapshot    (diag_fault_snapshot),
        .dbg_reject_counts     (diag_reject_counts),
        .dbg_input_pixels      (diag_input_pixels),
        .dbg_vsync_widths      ({diag_vs_min, diag_vs_last}),
        .dbg_cam_words         (dbg_cam_words),
        .dbg_vsyncs            (dbg_vsyncs   ),
        .dbg_hsyncs            (dbg_hsyncs   ),
        .dbg_xdma_req          (xdma_req     ),
        .dbg_i2c_status        (dbg_i2c_status),
        .dbg_pclk_cnt          (dbg_pclk_cnt ),
        .dbg_sys_status        (dbg_sys_status),
        .dbg_href_raw          (dbg_href_raw ),
        .dbg_beat_cnt          (dbg_beat_cnt ),
        .dbg_axi_sticky        (dbg_axi_sticky),
        .dbg_b_cnt             (dbg_b_cnt     ),
        .dbg_aw_cnt            (dbg_aw_cnt    ),
        .dbg_w_cnt             (dbg_w_cnt     ),
    .dbg_axi_cnt           (dbg_axi_cnt   ),
    .dbg_axi_num           (dbg_axi_num   ),
    .dbg_zdin              (dbg_zdin      ),
    .dbg_zout              (dbg_zout      ),
        .dbg_state             (dbg_state     ),
        .dbg_last_cnt          (dbg_last_cnt  ),
        .dbg_wd_cnt            (dbg_wd_cnt    ),
        .dbg_axi_stat          (dbg_axi_stat  ),
        .dbg_beat_last         (dbg_beat_last),
        .dbg_cmd_cnt           (dbg_cmd_cnt  ),
        .dbg_vsync_raw         (dbg_vsync_raw),
        .dbg_clk_status        (dbg_clk_status),

        // [PT 2026-09-26] host SCCB passthrough
        .diag_rst_n(host_diag_rst_n), .diag_snapshot(diag_host_snapshot),
        .diag_generation(diag_generation), .diag_accepted_seq(diag_accepted_seq),
        .diag_accepted_payload(diag_accepted_payload),
        .pt_req_toggle         (pt_req_toggle ),
        .pt_addr               (pt_addr       ),
        .pt_wdata              (pt_wdata      ),
        .pt_rw                 (pt_rw         ),
        .pt_seq                (pt_seq_dst    ),
        .pt_fault              (pt_fault_dst  ),
        .pt_rdata              (pt_rdata_dst  ),
        .pt_ack                (pt_ack_dst    ),
        .pt_done_toggle        (pt_done_dst   )
    );




    // RGB����ȡʱ��video_clk �� xdmaʱ����
    pipe_cdc #(
        .DATA_WIDTH   (2), // �������޸ġ����������õ�����λ��
        .DEST_SYNC_FF (4), // Ŀ��ʱ����ͬ������������ (��Χ: 2-10)
        .INIT_SYNC_FF (0), // �������ϵ��ʼֵ (0��1)
        .SRC_INPUT_REG(1)  // Դʱ���������Ƿ��ȴ�һ�ļĴ� (0=��, 1=��)
    )
    pipe_cdc(
        .src_clk(video_clk),  // Դʱ��
        .src_in(xdma_req),   // ����ǰ�Ķ��������
        .dest_clk(xdma_clk), // Ŀ��ʱ��
        .dest_out(xdma_irq)  // �����İ�ȫ���������
    );



endmodule

// Functional completion only. Independent phase observer/mailbox is unchanged.
// Common reset must assert in both domains; reset abandons in-flight commands.
module sccb_functional_mailbox (
    input src_clk, dst_clk, rst_n, src_done_toggle,
    input [7:0] src_data,
    input src_ack,
    input [31:0] src_seq,
    output reg [7:0] dst_data,
    output reg dst_ack,
    output reg [31:0] dst_seq,
    output reg dst_done_toggle,
    output wire dst_fault
);
    reg [40:0] held;
    reg req, ack, announce, seen, overflow;
    (* ASYNC_REG = "TRUE" *) reg [2:0] req_sync, ack_sync, fault_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] src_release, dst_release;
    reg settling;
    assign dst_fault = fault_sync[2];
    always @(posedge src_clk or negedge rst_n) begin
        if(!rst_n) src_release<=0;
        else src_release<={src_release[0],1'b1};
    end
    always @(posedge dst_clk or negedge rst_n) begin
        if(!rst_n) dst_release<=0;
        else dst_release<={dst_release[0],1'b1};
    end
    always @(posedge src_clk or negedge src_release[1]) begin
        if(!src_release[1]) begin
            held<=0; req<=0; ack_sync<=0; announce<=0; seen<=0; overflow<=0;
        end else if(src_release[1]) begin
            ack_sync<={ack_sync[1:0],ack};
            // Record first. Announce on the FOLLOWING source edge.
            if(announce) begin req<=~req; announce<=0; end
            if(src_done_toggle != seen) begin
                seen<=src_done_toggle;
                if(req == ack_sync[2] && !announce && !overflow) begin
                    held<={src_seq,src_ack,src_data}; announce<=1;
                end else overflow<=1;
            end
        end
    end
    always @(posedge dst_clk or negedge dst_release[1]) begin
        if(!dst_release[1]) begin
            req_sync<=0; fault_sync<=0; ack<=0; settling<=0;
            dst_data<=0; dst_ack<=0; dst_seq<=0; dst_done_toggle<=0;
        end else if(dst_release[1]) begin
            req_sync<={req_sync[1:0],req};
            fault_sync<={fault_sync[1:0],overflow};
            if(req_sync[2] != ack) begin
                if(!settling) settling<=1;
                else begin
                    {dst_seq,dst_ack,dst_data}<=held;
                    dst_done_toggle<=~dst_done_toggle;
                    ack<=req_sync[2]; settling<=0;
                end
            end else settling<=0;
        end
    end
endmodule
