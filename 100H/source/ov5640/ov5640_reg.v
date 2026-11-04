//ov5640дʹ�ܿ��ƺ�д��ַ����
module ov5640_reg #(
    parameter CAM1_RUNTIME = 1'b0,
    // Eligibility is independent of the legacy C1 global-mask owner.
    parameter RUNTIME_ENABLE = CAM1_RUNTIME,
    parameter [31:0] RUNTIME_BASE = 32'h20000800,
    parameter [31:0] RUNTIME_SIGNATURE = 32'h43314d31,
    // Mode 2 is advertised only by the C3/C4 v2 ABI.
    parameter RUNTIME_VGA_BYPASS = (RUNTIME_SIGNATURE == 32'h43334d32 ||
                                    RUNTIME_SIGNATURE == 32'h43344d32),
    parameter integer FRAME_W=640, FRAME_H=480, FRAME_BYTES=640*480*2,
    parameter BASE_ADDR = 32'h2000_0000,
    parameter [31:0] CAM_ADDR_1_DEF = 32'h0080_0000,
    parameter [31:0] CAM_ADDR_2_DEF = 32'h00A0_0000,
    parameter        CAM_EN_DEF     = 1'b1,
    parameter [7:0]  DLY_STEP_DEF   = 8'd40,
    // parameter AXI_REG_WIDTH = 32,
    parameter AXI_ADDR_WIDTH = 32
) (
    input             clk                   ,
    input             rst                   ,
    input diag_rst_n,
    input [511:0] diag_snapshot,
    input [31:0] diag_generation,
    output reg [31:0] diag_accepted_seq,
    output reg [31:0] diag_accepted_payload,
    input             runtime_safe,
    output reg [1:0]  runtime_mode,
    input [5:0]       runtime_idle_raw,
    output wire [5:0] runtime_allowed_mask,

    input                             s_axi_awvalid         ,
    output                            s_axi_awready         ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_awaddr          ,

    input                             s_axi_wvalid          ,
    output                            s_axi_wready          ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_wdata           ,
    input  [AXI_ADDR_WIDTH/8-1 : 0]   s_axi_wstrb           ,

    output                            s_axi_bvalid          ,
    input                             s_axi_bready          ,
    output [ 1 : 0]                   s_axi_bresp           ,

    input                             s_axi_arvalid         ,
    output                            s_axi_arready         ,
    input  [AXI_ADDR_WIDTH-1 : 0]     s_axi_araddr          ,

    output                            s_axi_rvalid          ,
    input                             s_axi_rready          ,
    output [AXI_ADDR_WIDTH-1 : 0]     s_axi_rdata           ,
    output [ 1 : 0]                   s_axi_rresp           ,


    output reg [AXI_ADDR_WIDTH-1 : 0] cam_addr_1            ,
    output reg [AXI_ADDR_WIDTH-1 : 0] cam_addr_2            ,        
    output reg [1 : 0]                xdma_ack              ,
    output reg                        cam_en                        ,
    output reg [7:0]                  dly_step                      ,
    input [31:0] dbg_cdc_input,
    input [31:0] dbg_cdc_output,
    input [31:0] dbg_cdc_drop,
    input [31:0] dbg_cdc_seq,
    input [31:0] dbg_fault_snapshot,
    input [31:0] dbg_reject_counts,
    input [31:0] dbg_input_pixels,
    input [31:0] dbg_vsync_widths,
    input  [31:0]                     dbg_cam_words         ,
    input  [31:0]                     dbg_vsyncs        ,
    input  [31:0]                     dbg_hsyncs        ,
    input  [31:0]                     dbg_href_raw      ,
    input  [31:0]                     dbg_vsync_raw     ,
    input  [31:0]                     dbg_beat_cnt      ,
    input  [31:0]                     dbg_beat_last     ,
    input  [31:0]                     dbg_cmd_cnt       ,
    input  [31:0]                     dbg_axi_sticky    ,
    input  [31:0]                     dbg_axi_stat      ,
    input  [31:0]                     dbg_b_cnt         ,
    input  [31:0]                     dbg_aw_cnt        ,
    input  [31:0]                     dbg_w_cnt         ,
    input  [31:0]                     dbg_axi_cnt       ,
    input  [31:0]                     dbg_zdin          ,
    input  [31:0]                     dbg_zout          ,
    input  [31:0]                     dbg_axi_num       ,
    input  [31:0]                     dbg_state         ,
    input  [31:0]                     dbg_last_cnt      ,
    input  [31:0]                     dbg_wd_cnt        ,
    input  [1:0]                      dbg_xdma_req        ,
    input  [31:0]                     dbg_i2c_status      ,
    input  [31:0]                     dbg_pclk_cnt        ,
    input  [31:0]                     dbg_sys_status      ,
    input  [31:0]                     dbg_clk_status,

    // [PT 2026-09-26] host SCCB passthrough (video_clk domain; CDC in ov5640_top)
    output reg                        pt_req_toggle,
    output reg  [15:0]                pt_addr,
    output reg  [ 7:0]                pt_wdata,
    output reg                        pt_rw,
    input       [ 7:0]                pt_rdata,
    input                             pt_ack,
    input [31:0]                      pt_seq,
    input                             pt_fault,
    input                             pt_done_toggle
);

//�Ĵ�����ַ
localparam REG_ACK       = BASE_ADDR + 32'h00;
localparam REG_CAM_EN    = BASE_ADDR + 32'h40;
// [CAM3DLY 2026-09-27] per-camera DVP sampling delay step (port mode).
// Write-only here: offset 0x30 still READS the CAM_WORDS debug counter, so a
// write to it was previously a no-op.  Lets the phase be swept on-board.
localparam REG_DLY_STEP  = BASE_ADDR + 32'h30;
localparam REG_CAM_ADDR_1= BASE_ADDR + 32'h80;
localparam REG_CAM_ADDR_2= BASE_ADDR + 32'hc0;
// [PROBE 2026-09-18] every offset is 16-byte aligned: the PCIe M01 read
// path ignores addr[3:0], so only *0 offsets are individually readable.
localparam REG_DBG_PCLK_CNT  = BASE_ADDR + 32'h10;
localparam REG_DBG_VSYNCS    = BASE_ADDR + 32'h20;
localparam REG_DBG_CAM_WORDS = BASE_ADDR + 32'h30;
localparam REG_DBG_AXI_STICKY= BASE_ADDR + 32'h50;
localparam REG_DBG_I2C_ID    = BASE_ADDR + 32'h60;
localparam REG_DBG_SYS       = BASE_ADDR + 32'h70;
localparam REG_DBG_HREF_RAW  = BASE_ADDR + 32'h90;
localparam REG_DBG_BEAT_CNT  = BASE_ADDR + 32'ha0;
localparam REG_DBG_BEAT_LAST = BASE_ADDR + 32'hf0;
localparam REG_DBG_XDMA_REQ  = BASE_ADDR + 32'hb0;
localparam REG_DBG_VSYNC_RAW = BASE_ADDR + 32'he0;
localparam REG_DBG_AXI_NOW   = BASE_ADDR + 32'hd0;
// [ZDIAG 2026-09-18] 0x50/0x90 repurposed from the old axi_sticky/href_raw
// probes (kept inside the addr[9:8]=00 CAM1 segment; 0x100+ routes to prep).
localparam REG_DBG_ZDIN      = BASE_ADDR + 32'h50;
localparam REG_DBG_ZOUT      = BASE_ADDR + 32'h90;
// [PT 2026-09-26] host SCCB passthrough (cam3 page: BASE+0x100..0x12F)
localparam REG_I2C_CMD  = BASE_ADDR + 32'h100;
localparam REG_I2C_RD   = BASE_ADDR + 32'h110;
localparam REG_I2C_STAT = BASE_ADDR + 32'h120;

    reg [5:0] allowed_mask;
    wire [5:0] idle_ack;
    assign runtime_allowed_mask = CAM1_RUNTIME ? allowed_mask : 6'h3f;
    always @(posedge clk) begin
        if(rst) allowed_mask <= 6'h3f;
        else if(CAM1_RUNTIME && s_axi_wstrb[0] && s_axi_wdata <= 32'h3f &&
                s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready &&
                s_axi_awaddr == 32'h20000880)
            allowed_mask <= s_axi_wdata[5:0];
    end
    genvar mask_index;
    generate for(mask_index=0; mask_index<6; mask_index=mask_index+1) begin : g_idle_ack
        reg [5:0] quiet_count;
        always @(posedge clk) begin
            if(rst || allowed_mask[mask_index] || !runtime_idle_raw[mask_index]) quiet_count <= 0;
            else if(quiet_count < 32) quiet_count <= quiet_count + 1'b1;
        end
        assign idle_ack[mask_index] = !allowed_mask[mask_index] &&
            runtime_idle_raw[mask_index] && (quiet_count == 32);
    end endgenerate

    // Cam1 aliases avoid the legacy prep page at 0x20000100.
    always @(posedge clk) begin
        if(rst) runtime_mode <= 0;
        else if(RUNTIME_ENABLE && runtime_safe && s_axi_wstrb[0] &&
                (s_axi_wdata == 0 || s_axi_wdata == 1 ||
                 (RUNTIME_VGA_BYPASS && !CAM1_RUNTIME && s_axi_wdata == 2)) &&
                s_axi_awvalid && s_axi_awready && s_axi_wvalid && s_axi_wready &&
                s_axi_awaddr == RUNTIME_BASE)
            runtime_mode <= s_axi_wdata[1:0];
    end

    reg bvalid        ;
    reg data_out_valid;

    reg rvalid;
    reg [AXI_ADDR_WIDTH-1 : 0] rdata ;

    //XDAMӦ��
    always @(posedge clk) begin
        if(rst)begin
            xdma_ack <= 2'b0;
        end
        else if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_ACK))begin
            xdma_ack <= s_axi_wdata[1 : 0];
        end
        else begin
            xdma_ack <= 2'b0;
        end
    end

    //����ͷʹ��
    always @(posedge clk) begin
        if(rst)begin
            cam_en <= CAM_EN_DEF;
        end
        else if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_CAM_EN))begin
            cam_en <= s_axi_wdata[0];
        end
    end

    // [CAM3DLY 2026-09-27] runtime DVP sampling delay for this camera.
    always @(posedge clk) begin
        if(rst)begin
            dly_step <= DLY_STEP_DEF;
        end
        else if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_DLY_STEP))begin
            dly_step <= s_axi_wdata[7:0];
        end
    end

    //ͼƬ��ַ1
    always @(posedge clk) begin
        if(rst)begin
            cam_addr_1 <= CAM_ADDR_1_DEF;
        end
        else if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_CAM_ADDR_1))begin
            cam_addr_1 <= s_axi_wdata;
        end
    end

    //ͼƬ��ַ2
    always @(posedge clk) begin
        if(rst)begin
            cam_addr_2 <= CAM_ADDR_2_DEF;
        end
        else if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) && (s_axi_awaddr == REG_CAM_ADDR_2))begin
            cam_addr_2 <= s_axi_wdata;
        end
    end

    // [PT 2026-09-26] host SCCB passthrough command + result latch.
    //   Any write to REG_I2C_CMD issues one SCCB transaction (after sensor
    //   init). done/ack/rdata are latched back for polling reads.
    // Passive command identity follows exactly the existing acceptance predicate.
    localparam [31:0] DIAG_BASE = BASE_ADDR == 32'h20000000 ? 32'h20000c00 :
                                BASE_ADDR == 32'h20000400 ? 32'h20000d00 : 32'h20000e00;
    wire diag_accept = (s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) &&
        ((s_axi_awaddr == REG_I2C_CMD) ||
         (RUNTIME_ENABLE && runtime_safe && s_axi_wstrb == 4'hf &&
          s_axi_awaddr == RUNTIME_BASE+32'h10));
    always @(posedge clk or negedge diag_rst_n) begin
        if(!diag_rst_n) begin diag_accepted_seq<=0; diag_accepted_payload<=0; end
        else if(diag_accept) begin
            diag_accepted_seq<=diag_accepted_seq+1'b1;
            diag_accepted_payload<=s_axi_wdata;
        end
    end
    reg        pt_done_lat;
    reg [ 7:0] pt_rdata_lat;
    reg        pt_ack_lat;
    reg        pt_done_d;
    reg [31:0] pt_native_word, pt_native_seq, pt_dest_seq;
    reg [31:0] pt_axi_word, pt_axi_seq, pt_response_seq;
    reg pt_identity_fault, pt_axi_valid, pt_outstanding;
    wire pt_completion_bad = pt_fault || (pt_seq != diag_accepted_seq) || diag_accept || !pt_outstanding;

    always @(posedge clk) begin
        if(rst || !diag_rst_n) begin
            pt_native_word<=0; pt_native_seq<=0; pt_dest_seq<=0; pt_identity_fault<=0; pt_outstanding<=0;
            pt_addr       <= 16'd0;
            pt_wdata      <= 8'd0;
            pt_rw         <= 1'b0;
            pt_req_toggle <= 1'b0;
            pt_done_lat   <= 1'b0;
            pt_rdata_lat  <= 8'd0;
            pt_ack_lat    <= 1'b0;
            pt_done_d     <= 1'b0;
        end
        else begin
            pt_done_d <= pt_done_toggle;
            if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready) &&
               ((s_axi_awaddr == REG_I2C_CMD) ||
                (RUNTIME_ENABLE && runtime_safe && s_axi_wstrb == 4'hf &&
                 s_axi_awaddr == RUNTIME_BASE+32'h10))) begin
                pt_addr       <= s_axi_wdata[23:8];
                pt_wdata      <= s_axi_wdata[7:0];
                pt_rw         <= s_axi_wdata[24];
                pt_req_toggle <= ~pt_req_toggle;
                pt_outstanding <= 1'b1;
                pt_done_lat   <= 1'b0;
            end
            if(pt_done_toggle ^ pt_done_d) begin
                pt_native_word <= {23'd0,pt_ack,pt_rdata};
                pt_native_seq <= pt_seq;
                pt_dest_seq <= pt_seq;
                pt_outstanding <= 1'b0;
                pt_identity_fault <= pt_identity_fault | pt_completion_bad;
                pt_rdata_lat <= pt_rdata;
                pt_ack_lat   <= pt_ack | pt_completion_bad | pt_identity_fault;
                pt_done_lat  <= 1'b1;
            end
            // Faults stay visible until common reset, including after publication.
            if(pt_fault || pt_identity_fault) begin
                pt_ack_lat <= 1'b1;
            end
        end
    end

    //��Ϊ��һ�����Ĵ��������������û���ж϶���ַ
    reg r_state;
    always @(posedge clk) begin
        if(rst)begin
            r_state <= 1'b0;
        end
        else begin
            if(s_axi_arvalid & s_axi_arready) begin
                r_state <= 1'b1;
            end
            else if(s_axi_rvalid & s_axi_rready) begin
                r_state <= 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if(rst)begin
            data_out_valid <= 1'b0;
        end
        else begin
            if(s_axi_arvalid & s_axi_arready)begin
                data_out_valid <= 1'b1;
            end
            else begin
                data_out_valid <= 1'b0;
            end
        end
    end


    // ����һ���ݴ����ַ�ļĴ���
    reg [AXI_ADDR_WIDTH-1:0] raddr_reg;
    localparam READ_SELECT_COUNT = 58;
    reg [READ_SELECT_COUNT-1:0] read_select, read_select_next;
    // Decode in the existing AR address-capture stage. Data is still
    // sampled on the original response-construction edge, not early.
    always @* begin
        read_select_next = 0;
        if(RUNTIME_ENABLE && s_axi_araddr[31:8] == DIAG_BASE[31:8]) begin
            case(s_axi_araddr[7:0])
                8'h00: read_select_next[0] = 1'b1;
                8'h10: read_select_next[1] = 1'b1;
                8'h20: read_select_next[2] = 1'b1;
                8'h30: read_select_next[3] = 1'b1;
                8'h40: read_select_next[4] = 1'b1;
                8'h50: read_select_next[5] = 1'b1;
                8'h60: read_select_next[6] = 1'b1;
                8'h70: read_select_next[7] = 1'b1;
                8'h80: read_select_next[8] = 1'b1;
                8'h90: read_select_next[9] = 1'b1;
                8'ha0: read_select_next[10] = 1'b1;
                8'hb0: read_select_next[11] = 1'b1;
                8'hc0: read_select_next[12] = 1'b1;
                8'hd0: read_select_next[13] = 1'b1;
                8'he0: read_select_next[14] = 1'b1;
                8'hf0: read_select_next[15] = 1'b1;
                default: read_select_next[57] = 1'b1;
            endcase
        end else begin
            case(s_axi_araddr)
                32'h20000880: read_select_next[16] = 1'b1;
                32'h20000890: read_select_next[17] = 1'b1;
                RUNTIME_BASE: read_select_next[18] = 1'b1;
                RUNTIME_BASE+32'h20: read_select_next[19] = 1'b1;
                RUNTIME_BASE+32'h30: read_select_next[20] = 1'b1;
                RUNTIME_BASE+32'ha0: read_select_next[21] = 1'b1;
                RUNTIME_BASE+32'hb0: read_select_next[22] = 1'b1;
                RUNTIME_BASE+32'hc0: read_select_next[23] = 1'b1;
                RUNTIME_BASE+32'hd0: read_select_next[24] = 1'b1;
                RUNTIME_BASE+32'he0: read_select_next[25] = 1'b1;
                RUNTIME_BASE+32'hf0: read_select_next[26] = 1'b1;
                RUNTIME_BASE+32'h40: read_select_next[27] = 1'b1;
                RUNTIME_BASE+32'h50: read_select_next[28] = 1'b1;
                RUNTIME_BASE+32'h60: read_select_next[29] = 1'b1;
                RUNTIME_BASE+32'h70: read_select_next[30] = 1'b1;
                REG_ACK: read_select_next[31] = 1'b1;
                REG_CAM_EN: read_select_next[32] = 1'b1;
                REG_CAM_ADDR_1: read_select_next[33] = 1'b1;
                REG_CAM_ADDR_2: read_select_next[34] = 1'b1;
                BASE_ADDR + 32'h190: read_select_next[35] = 1'b1;
                BASE_ADDR + 32'h1a0: read_select_next[36] = 1'b1;
                BASE_ADDR + 32'h1b0: read_select_next[37] = 1'b1;
                BASE_ADDR + 32'h1c0: read_select_next[38] = 1'b1;
                REG_DBG_CAM_WORDS: read_select_next[39] = 1'b1;
                REG_DBG_VSYNCS: read_select_next[40] = 1'b1;
                REG_DBG_ZDIN: read_select_next[41] = 1'b1;
                REG_DBG_ZOUT: read_select_next[42] = 1'b1;
                REG_DBG_BEAT_CNT: read_select_next[43] = 1'b1;
                REG_DBG_BEAT_LAST: read_select_next[44] = 1'b1;
                REG_DBG_XDMA_REQ: read_select_next[45] = 1'b1;
                REG_DBG_VSYNC_RAW: read_select_next[46] = 1'b1;
                REG_DBG_I2C_ID: read_select_next[47] = 1'b1;
                REG_DBG_PCLK_CNT: read_select_next[48] = 1'b1;
                REG_DBG_SYS: read_select_next[49] = 1'b1;
                REG_DBG_AXI_NOW: read_select_next[50] = 1'b1;
                REG_I2C_RD: read_select_next[51] = 1'b1;
                REG_I2C_STAT: read_select_next[52] = 1'b1;
                BASE_ADDR + 32'h140: read_select_next[53] = 1'b1;
                BASE_ADDR + 32'h150: read_select_next[54] = 1'b1;
                BASE_ADDR + 32'h160: read_select_next[55] = 1'b1;
                BASE_ADDR + 32'h170: read_select_next[56] = 1'b1;
                default: read_select_next[57] = 1'b1;
            endcase
        end
    end
    always @(posedge clk) begin
        if(s_axi_arvalid & s_axi_arready) read_select <= read_select_next;
    end
    wire [31:0] read_mux_data =
        ({32{read_select[0]}} & (32'h53430202)) |
        ({32{read_select[1]}} & (diag_generation)) |
        ({32{read_select[2]}} & (diag_accepted_seq)) |
        ({32{read_select[3]}} & (diag_accepted_payload)) |
        ({32{read_select[4]}} & (diag_snapshot[128 +: 32])) |
        ({32{read_select[5]}} & (diag_snapshot[160 +: 32])) |
        ({32{read_select[6]}} & (diag_snapshot[192 +: 32])) |
        ({32{read_select[7]}} & (diag_snapshot[224 +: 32])) |
        ({32{read_select[8]}} & (diag_snapshot[256 +: 32])) |
        ({32{read_select[9]}} & (diag_snapshot[288 +: 32])) |
        ({32{read_select[10]}} & (diag_snapshot[320 +: 32])) |
        ({32{read_select[11]}} & (diag_snapshot[352 +: 32])) |
        ({32{read_select[12]}} & (diag_snapshot[384 +: 32])) |
        ({32{read_select[13]}} & (diag_snapshot[416 +: 32])) |
        ({32{read_select[14]}} & (diag_snapshot[448 +: 32])) |
        ({32{read_select[15]}} & (diag_snapshot[480 +: 32])) |
        ({32{read_select[16]}} & (CAM1_RUNTIME ? {26'd0,allowed_mask} : 32'hffffffff)) |
        ({32{read_select[17]}} & (CAM1_RUNTIME ? {26'd0,idle_ack} : 32'hffffffff)) |
        ({32{read_select[18]}} & (RUNTIME_ENABLE ? {30'd0,runtime_mode} : 32'hffffffff)) |
        ({32{read_select[19]}} & (RUNTIME_ENABLE ? {24'd0,pt_rdata_lat} : 32'hffffffff)) |
        ({32{read_select[20]}} & (RUNTIME_ENABLE ? {30'd0,pt_done_lat,pt_ack_lat} : 32'hffffffff)) |
        ({32{read_select[21]}} & (RUNTIME_ENABLE ? pt_native_word : 32'hffffffff)) |
        ({32{read_select[22]}} & (RUNTIME_ENABLE ? pt_native_seq : 32'hffffffff)) |
        ({32{read_select[23]}} & (RUNTIME_ENABLE ? {20'd0,pt_axi_valid,pt_identity_fault,pt_fault,pt_ack_lat,pt_rdata_lat} : 32'hffffffff)) |
        ({32{read_select[24]}} & (RUNTIME_ENABLE ? pt_dest_seq : 32'hffffffff)) |
        ({32{read_select[25]}} & (RUNTIME_ENABLE ? pt_axi_word : 32'hffffffff)) |
        ({32{read_select[26]}} & (RUNTIME_ENABLE ? pt_axi_seq : 32'hffffffff)) |
        ({32{read_select[27]}} & (RUNTIME_ENABLE ? (runtime_mode == 2'd1 ? 32'h050002d0 :
                        (runtime_mode == 2'd2 ? 32'h028001e0 : ((FRAME_W << 16) | FRAME_H))) : 32'hffffffff)) |
        ({32{read_select[28]}} & (RUNTIME_ENABLE ? (runtime_mode == 2'd1 ? 32'd1843200 :
                        (runtime_mode == 2'd2 ? 32'd614400 : FRAME_BYTES)) : 32'hffffffff)) |
        ({32{read_select[29]}} & (RUNTIME_ENABLE ? (runtime_mode == 2'd1 ? 32'd2560 :
                        (runtime_mode == 2'd2 ? 32'd1280 : (FRAME_W*2))) : 32'hffffffff)) |
        ({32{read_select[30]}} & (RUNTIME_ENABLE ? RUNTIME_SIGNATURE : 32'hffffffff)) |
        ({32{read_select[31]}} & (dbg_fault_snapshot)) |
        ({32{read_select[32]}} & ({{AXI_ADDR_WIDTH-1{1'b0}}, cam_en})) |
        ({32{read_select[33]}} & (cam_addr_1)) |
        ({32{read_select[34]}} & (cam_addr_2)) |
        ({32{read_select[35]}} & (dbg_cdc_input)) |
        ({32{read_select[36]}} & (dbg_cdc_output)) |
        ({32{read_select[37]}} & (dbg_cdc_drop)) |
        ({32{read_select[38]}} & (dbg_cdc_seq)) |
        ({32{read_select[39]}} & (dbg_input_pixels)) |
        ({32{read_select[40]}} & (dbg_vsyncs)) |
        ({32{read_select[41]}} & (dbg_vsync_widths)) |
        ({32{read_select[42]}} & (dbg_href_raw)) |
        ({32{read_select[43]}} & (dbg_reject_counts)) |
        ({32{read_select[44]}} & (dbg_last_cnt)) |
        ({32{read_select[45]}} & ({{(AXI_ADDR_WIDTH-2){1'b0}}, dbg_xdma_req})) |
        ({32{read_select[46]}} & (dbg_vsync_raw)) |
        ({32{read_select[47]}} & ({dbg_wd_cnt[7:0], dbg_state[7:0], dbg_cmd_cnt[15:0]})) |
        ({32{read_select[48]}} & (dbg_pclk_cnt)) |
        ({32{read_select[49]}} & ({dbg_b_cnt[15:0], dbg_aw_cnt[15:0]})) |
        ({32{read_select[50]}} & (dbg_sys_status)) |
        ({32{read_select[51]}} & ({{(AXI_ADDR_WIDTH-8){1'b0}}, pt_rdata_lat})) |
        ({32{read_select[52]}} & ({{(AXI_ADDR_WIDTH-2){1'b0}}, pt_done_lat, pt_ack_lat})) |
        ({32{read_select[53]}} & (32'h43333432)) |
        ({32{read_select[54]}} & ((FRAME_H << 16) | FRAME_W)) |
        ({32{read_select[55]}} & (FRAME_BYTES)) |
        ({32{read_select[56]}} & (FRAME_W*2)) |
        ({32{read_select[57]}} & ({AXI_ADDR_WIDTH{1'b1}}));

    // Witness tags are captured with response construction, then actual R beat.
    always @(posedge clk) begin
        if(rst || !diag_rst_n) begin
            pt_axi_word<=0; pt_axi_seq<=0; pt_response_seq<=0; pt_axi_valid<=0;
        end else begin
            if(data_out_valid) pt_response_seq<=pt_dest_seq;
            if(rvalid && s_axi_rready &&
               (raddr_reg == REG_I2C_RD ||
                (RUNTIME_ENABLE && raddr_reg == RUNTIME_BASE+32'h20))) begin
                pt_axi_word<=rdata; pt_axi_seq<=pt_response_seq; pt_axi_valid<=1;
            end
        end
    end

    always @(posedge clk) begin
        if (s_axi_arvalid & s_axi_arready) begin
            raddr_reg <= s_axi_araddr; // ���ֳɹ�˲�䣬�������������Ķ���ַ
        end
    end


    always @(posedge clk) begin
        if(rst)begin
            rvalid <= 1'b0;
            rdata  <= {AXI_ADDR_WIDTH{1'b0}}; // ע�⣺rdata λ��Ӧ���� 32������ 1
        end
        else begin
            if(data_out_valid) begin
                rvalid <= 1'b1;
                // ���ݸղ�����Ķ���ַ�����ض�Ӧ�Ĵ�������ʵֵ
                rdata <= read_mux_data;
            end
            else if(s_axi_rvalid & s_axi_rready)begin
                rvalid <= 1'b0;
                // rdata ���ֲ��伴�ɣ�ֱ����һ�ζ�����
            end
        end
    end


    always @(posedge clk) begin
        if(rst)begin
            bvalid <= 1'b0;
        end
        else begin
            if((s_axi_awvalid & s_axi_awready) && (s_axi_wvalid & s_axi_wready))begin
                bvalid <= 1'b1;
            end
            else if(bvalid & s_axi_bready)begin
                bvalid <= 1'b0;
            end
        end
    end

    assign s_axi_awready = s_axi_awvalid & s_axi_wvalid;
    assign s_axi_wready  = s_axi_awvalid & s_axi_wvalid;
    
    assign s_axi_arready = s_axi_arvalid & (r_state == 1'b0);
    assign s_axi_rvalid  = rvalid        ;
    assign s_axi_rdata   = rdata         ;
    assign s_axi_rresp   = 2'b00         ;
    
    assign s_axi_bvalid = bvalid;
    assign s_axi_bresp  = 2'b00 ;


endmodule
