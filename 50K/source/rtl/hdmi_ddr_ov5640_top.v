`timescale 1ns/1ps
// Isolated fullfield 50K candidate. C5=CMOS1, C6=CMOS2. VGA uses the
// unmodified donor FIR/merger/DDR temporal modules. HD bypasses C5's 640-wide
// FIR and the 1280x480 temporal module; C6 still uses its native VGA FIR.
module hdmi_ddr_ov5640_top #(
    parameter COLOR_BAR_TEST=0, KEY_DEBOUNCE_CYCLES=500000,
    parameter DIAGNOSTIC_HDMI_BOOT=0
)(
    input sys_clk,output [1:0] cmos_init_done,
    inout cmos1_scl,cmos1_sda,input cmos1_vsync,cmos1_href,cmos1_pclk,
    input [7:0] cmos1_data,output cmos1_reset,
    inout cmos2_scl,cmos2_sda,input cmos2_vsync,cmos2_href,cmos2_pclk,
    input [7:0] cmos2_data,output cmos2_reset,output reg heart_beat_led,
    input pixclk_in,vs_in,hs_in,de_in,input [7:0] r_in,g_in,b_in,
    output rstn_in,iic_scl,inout iic_sda,output hdmi_int_led,
    input sfp_refckp,sfp_refckn,sfp0_rxp,sfp0_rxn,
    output sfp0_txp,sfp0_txn,input sfp1_rxp,sfp1_rxn,
    output sfp1_txp,sfp1_txn,output sfp0_tx_disable,input sfp0_los,
    output led_sfp_pll,led_sfp_ready,led_sfp_rxsync,led_sfp_pcs,
    output sfp1_tx_disable,input key1,key2,key3,key4,
    output mem_rst_n,mem_ck,mem_ck_n,mem_cke,mem_cs_n,mem_ras_n,
    output mem_cas_n,mem_we_n,mem_odt,output [14:0] mem_a,
    output [2:0] mem_ba,inout [3:0] mem_dqs,mem_dqs_n,
    inout [31:0] mem_dq,output [3:0] mem_dm
);
    wire cfg_clk,clk_25M,pix_unused,locked;
    pll u_pll(.clkin1(sys_clk),.clkout0(pix_unused),.clkout1(cfg_clk),
        .clkout2(clk_25M),.pll_lock(locked));
    reg [15:0] startup_count=0;
    reg startup_ready=0;
    always @(posedge cfg_clk or negedge locked)
        if(!locked) begin startup_count<=0;startup_ready<=0;end
        else if(startup_count==10000) startup_ready<=1;
        else startup_count<=startup_count+1'b1;
    wire rstn_int=locked && startup_ready;
    wire sys_rst_n,fab_rst_n,mrg_rst_n,cfg_rst_n,clk2core_tx;
    reg mrg_clk=0;
    always @(negedge clk2core_tx) mrg_clk<=~mrg_clk;
    video_reset_sync u_sys_reset(sys_clk,rstn_int,sys_rst_n);
    video_reset_sync u_fab_reset(clk2core_tx,rstn_int,fab_rst_n);
    video_reset_sync u_mrg_reset(mrg_clk,rstn_int,mrg_rst_n);
    video_reset_sync u_cfg_reset(clk_25M,rstn_int,cfg_rst_n);
    wire hdmi_request,hdmi_active;
    wire [1:0] cmos_cfg_ok;
    wire [3:0] dbg_p_tog,dbg_o_tog;wire [2:0] dbg_p_lvl;
    wire [12:0] dbg_v0,dbg_v1,dbg_v2,dbg_v3;
    wire [5:0] dbg_flags;
    // Numeric HDMI diagnostics are read by the host over SFP/PCIe.
    assign cmos_init_done=cmos_cfg_ok;
    // Fabric-domain copy of the source select. hdmi_active changes only in
    // the mode switch's DRAIN state, while both packetizers are held in
    // reset, so a registered copy cannot select a live stream mid-word.
    (* ASYNC_REG="TRUE" *)reg [1:0] hdmi_active_sync;
    always @(posedge clk2core_tx or negedge fab_rst_n)
        if(!fab_rst_n)hdmi_active_sync<=0;
        else hdmi_active_sync<={hdmi_active_sync[0],hdmi_active};
    wire hdmi_active_tx=hdmi_active_sync[1];
    wire diag_press;
    generate if(DIAGNOSTIC_HDMI_BOOT) begin:g_diag
        reg [23:0] counter;reg press_q;
        always @(posedge sys_clk or negedge sys_rst_n)
            if(!sys_rst_n) begin counter<=0;press_q<=0;end
            else begin
                if(counter<15000000)counter<=counter+1'b1;
                press_q<=counter>=10000000 && counter<15000000;
            end
        assign diag_press=press_q;
    end else begin:g_normal assign diag_press=0;end endgenerate
    video_mode_keys #(.DEBOUNCE_CYCLES(KEY_DEBOUNCE_CYCLES)) u_keys(
        .clk(sys_clk),.rst_n(sys_rst_n),.key1_n(key1),.key2_n(key2 && !diag_press),
        .hdmi_request(hdmi_request));
    wire source_cam_request_n,source_hdmi_request_n,tx_request_n;
    wire [18:0] selected_video,hdmi_video;
    wire [18:0] native_video;
    wire native_hdmi_fault,native_hdmi_format_ok,native_meta_valid,native_meta_ready;
    wire [159:0] native_meta_payload;
    wire [1:0] native_geometry_mode;
    wire [31:0] native_generation;
    wire hdmi_fault,hdmi_format_ok;
    wire [15:0] camera_data;wire camera_de,camera_vs;
    wire camera_mode720;
    // Native HDMI bypasses this switch's video path (it is in another clock
    // domain); idle input lets a source change proceed at once in HDMI mode.
    video_mode_switch_c5 u_mode(.clk(mrg_clk),.rst_n(mrg_rst_n),.cam_mode720(camera_mode720),
        .hdmi_request(hdmi_request),.cam_video({camera_vs,1'b0,camera_de,camera_data}),
        .hdmi_video(19'd0),.hdmi_fault(native_hdmi_fault),.hdmi_active(hdmi_active),
        .source_cam_request_n(source_cam_request_n),
        .source_hdmi_request_n(source_hdmi_request_n),
        .tx_request_n(tx_request_n),.video(selected_video));
    wire camera_sys_rst_n,initial_en;
    video_reset_sync u_camera_sys_reset(sys_clk,sys_rst_n && !hdmi_active,camera_sys_rst_n);
    power_on_delay power_on_delay_inst(.clk_50M(sys_clk),.reset_n(camera_sys_rst_n),
        .camera1_rstn(cmos1_reset),.camera2_rstn(cmos2_reset),.camera_pwnd(),.initial_en(initial_en));
    wire camera_cfg_rst_n,runtime_fab_rst_n;
    video_reset_sync u_camera_cfg_reset(clk_25M,
        cfg_rst_n && cmos1_reset && cmos2_reset,camera_cfg_rst_n);
    video_reset_sync u_runtime_fab_reset(clk2core_tx,
        rstn_int && cmos1_reset && cmos2_reset,runtime_fab_rst_n);
    // Power sequencer is sys_clk; configuration consumes this level only
    // after a two-stage clk_25M transfer. Stage two and bus_start stay timed.
    (* ASYNC_REG="TRUE" *)reg [1:0] initial_en_sync;
    always @(posedge clk_25M or negedge camera_cfg_rst_n)
        if(!camera_cfg_rst_n)initial_en_sync<=0;
        else initial_en_sync<={initial_en_sync[0],initial_en};
    wire [31:0] rxdata,control_data,protocol_errors;
    wire [3:0] rxk,control_k;
    wire rxpcs,rxsig,hsst_pll_lock,txdone2,txdone3;
    wire [3:0] rxdisper,rxdecer;
    wire link_ok=rxpcs && !sfp0_los && !(|rxdisper) && !(|rxdecer);
    wire capture_hold,mode720_cfg,control_valid,control_ready,epoch_active_cfg;
    wire stream_fault,meta_ready,meta_valid,framing_fault,packetizer_fault;
    wire [2:0] stream_detail;
    wire [3:0] merge_phase_code;
    wire [31:0] frame_sequence;
    cam5_runtime runtime(.fab_clk(clk2core_tx),.fab_rst_n(runtime_fab_rst_n),.link_ok(link_ok),
        .rx_data(rxdata),.rx_k(rxk),.cfg_clk(clk_25M),.cfg_rst_n(camera_cfg_rst_n),
        .initial_en(initial_en_sync[1]),.c5_scl(cmos1_scl),.c5_sda(cmos1_sda),
        .c6_scl(cmos2_scl),.c6_sda(cmos2_sda),.capture_hold(capture_hold),
        .mode720(mode720_cfg),.epoch_active(epoch_active_cfg),.config_ok(cmos_cfg_ok),.stream_fault(stream_fault),.stream_detail(stream_detail),.phase_code(merge_phase_code),
        .meta_valid(meta_valid),.meta_ready(meta_ready),.frame_sequence(frame_sequence),
        .control_valid(control_valid),.control_ready(hdmi_active_tx?1'b0:control_ready),
        .control_data(control_data),.control_k(control_k),.protocol_errors(protocol_errors));
    // A single mode bit settles during held capture; no live multibit bus.
    (* ASYNC_REG="TRUE" *) reg [1:0] mode_mrg,mode_a,mode_b;
    assign camera_mode720=mode_mrg[1];
    always @(posedge mrg_clk or negedge mrg_rst_n)
        if(!mrg_rst_n)mode_mrg<=0;else mode_mrg<={mode_mrg[0],mode720_cfg};
    wire p1,p2,de1,de2,vs1,vs2;
    wire [15:0] d1,d2;
    wire byte_rst1,byte_rst2;
    wire capture_req=rstn_int && cmos1_reset && cmos2_reset &&
        source_cam_request_n && (&cmos_cfg_ok) && !capture_hold;
    video_reset_sync u_byte1(cmos1_pclk,capture_req,byte_rst1);
    video_reset_sync u_byte2(cmos2_pclk,capture_req,byte_rst2);
    reg [7:0] byte1,byte2;reg href1,href2,vsync1,vsync2;
    always @(posedge cmos1_pclk)begin byte1<=cmos1_data;href1<=cmos1_href;vsync1<=cmos1_vsync;end
    always @(posedge cmos2_pclk)begin byte2<=cmos2_data;href2<=cmos2_href;vsync2<=cmos2_vsync;end
    cmos_8_16bit cmos1_8_16bit(.pclk(cmos1_pclk),.rst_n(byte_rst1),.pdata_i(byte1),
        .de_i(href1),.vs_i(vsync1),.pixel_clk(p1),.pdata_o(d1),.de_o(de1),.vs_o(vs1));
    cmos_8_16bit cmos2_8_16bit(.pclk(cmos2_pclk),.rst_n(byte_rst2),.pdata_i(byte2),
        .de_i(href2),.vs_i(vsync2),.pixel_clk(p2),.pdata_o(d2),.de_o(de2),.vs_o(vs2));
    // Mode synchronizers have independent destination-local reset release.
    // Do NOT use ar/br: those resets depend on capture_hold, and divided
    // camera clocks can stop while held. The sensor/global source asserts
    // immediately and releases through each destination's own reset chain.
    wire mode_a_rst_n,mode_b_rst_n;
    video_reset_sync u_mode_a_reset(p1,rstn_int && cmos1_reset,mode_a_rst_n);
    video_reset_sync u_mode_b_reset(p2,rstn_int && cmos2_reset,mode_b_rst_n);
    always @(posedge p1 or negedge mode_a_rst_n)
        if(!mode_a_rst_n)mode_a<=0;else mode_a<={mode_a[0],mode720_cfg};
    always @(posedge p2 or negedge mode_b_rst_n)
        if(!mode_b_rst_n)mode_b<=0;else mode_b<={mode_b[0],mode720_cfg};
    wire ar,br,orr;
    cam5_capture_release u_ar(.clk(p1),.local_mode_rst_n(mode_a_rst_n),
        .capture_request_n(capture_req),.capture_rst_n(ar));
    cam5_capture_release u_br(.clk(p2),.local_mode_rst_n(mode_b_rst_n),
        .capture_request_n(capture_req),.capture_rst_n(br));
    video_reset_sync u_orr(mrg_clk,capture_req,orr);
    wire [15:0] f1,f2;wire fd1,fd2,fv1,fv2;
    cam_fir2d u_cam1_fir(.clk(p1),.rst(!ar || mode_a[1]),.in_valid(de1),.in_pixel(d1),
        .in_vsync(vs1),.out_valid(fd1),.out_pixel(f1),.out_vsync(fv1));
    cam_fir2d u_cam2_fir(.clk(p2),.rst(!br),.in_valid(de2),.in_pixel(d2),
        .in_vsync(vs2),.out_valid(fd2),.out_pixel(f2),.out_vsync(fv2));
    wire [15:0] vga_data,hd_data;wire vga_de,vga_vs,hd_de,hd_vs,hd_fault;
    cam2_merge #(.LINE_PIX(640),.LINES(480)) u_cam2_merge(
        .a_clk(p1),.a_rst_n(ar && !mode_a[1]),.a_data(f1),.a_de(fd1),.a_vs(fv1),.corr_mode(4'd0),
        .b_clk(p2),.b_rst_n(br && !mode_b[1]),.b_data(f2),.b_de(fd2),.b_vs(fv2),
        .o_clk(mrg_clk),.o_rst_n(orr && !mode_mrg[1]),.c_data(vga_data),.c_de(vga_de),.c_vs(vga_vs));
    wire cache_request,cache_ready,cache_release,cache_row_ready,cache_consume;
    wire [31:0] cache_sequence;wire [15:0] cache_epoch,cache_pixel;
    wire [9:0] cache_row,cache_x;
    wire cache_fault,merge_fault,merge_hd_de,merge_hd_vs;
    wire cache_s_rst_n,cache_m_rst_n;
    wire [31:0] cache_published,cache_rejected;
    cam5_cached_merge u_hd_merge(.a_clk(p1),.a_rst_n(ar && mode_a[1]),
        .a_data(d1),.a_de(de1),.a_vs(vs1),.o_clk(mrg_clk),.o_rst_n(cache_m_rst_n),
        .frame_request(cache_request),.frame_ready(cache_ready),
        .frame_sequence(cache_sequence),.frame_epoch({16'd0,cache_epoch}),
        .frame_release(cache_release),.row_index(cache_row),.pixel_address(cache_x),
        .row_ready(cache_row_ready),.pixel_data(cache_pixel),.row_consume(cache_consume),
        .c_data(hd_data),.c_de(merge_hd_de),.c_vs(merge_hd_vs),.fault(merge_fault),
        .frame_complete(),.fault_src(merge_phase_code));
    (* ASYNC_REG="TRUE" *) reg [1:0] cache_fault_m;
    reg [23:0] cache_wait;reg cache_missing;
    always @(posedge mrg_clk or negedge cache_m_rst_n)
        if(!cache_m_rst_n)begin cache_fault_m<=0;cache_wait<=0;cache_missing<=0;end
        else begin
            cache_fault_m<={cache_fault_m[0],cache_fault};
            // PRIME also needs a watchdog: no SOF cannot start the core timer.
            if(cache_request && !cache_ready)begin
                if(&cache_wait)cache_missing<=1;
                else cache_wait<=cache_wait+1'b1;
            end else cache_wait<=0;
        end
    assign hd_fault=merge_fault || cache_fault_m[1] || cache_missing;
    assign hd_de=merge_hd_de && !hd_fault;
    assign hd_vs=merge_hd_vs && !hd_fault;
    assign stream_fault=(mode_mrg[1] && hd_fault) || framing_fault || packetizer_fault;
    assign stream_detail={hd_fault,framing_fault,packetizer_fault};
    // Diagnostic: C5->C6 frame phase offset in active lines.
    wire core_clk,ddr_init_done,ddr_pll_lock,ddr_rst,temporal_rst,temporal_ddr_rst;
    // HOLD/config loss flushes controller AND both clients. Never depend on
    // DDR init here: byte clocks must run before DDR client reset can release.
    video_reset_sync u_ddr_reset(sys_clk,capture_req,ddr_rst);
    (* ASYNC_REG="TRUE" *) reg [1:0] mode_ddr;
    wire mode_ddr_rst_n;
    video_reset_sync u_mode_ddr_reset(core_clk,rstn_int && cmos1_reset && cmos2_reset,mode_ddr_rst_n);
    always @(posedge core_clk or negedge mode_ddr_rst_n)
        if(!mode_ddr_rst_n)mode_ddr<=0;else mode_ddr<={mode_ddr[0],mode720_cfg};
    // One raw request reaches all core reset entry stages. Never AND
    // pre-released resets from different clock domains inside the core.
    wire cache_reset_req_n=capture_req && mode720_cfg && ddr_init_done;
    video_reset_sync u_cache_s_reset(p2,cache_reset_req_n,cache_s_rst_n);
    video_reset_sync u_cache_m_reset(mrg_clk,cache_reset_req_n,cache_m_rst_n);
    video_reset_sync u_temp_reset(mrg_clk,orr && !mode_mrg[1] && ddr_init_done,temporal_rst);
    video_reset_sync u_temp_ddr_reset(core_clk,orr && !mode_mrg[1] && ddr_init_done,temporal_ddr_rst);
    wire [15:0] tmp_data;wire tmp_de,tmp_vs;
    assign camera_data=mode_mrg[1] ? hd_data : tmp_data;
    assign camera_de=mode_mrg[1] ? hd_de : tmp_de;
    assign camera_vs=mode_mrg[1] ? hd_vs : tmp_vs;
    wire [27:0] awaddr,araddr;wire [3:0] awid,arid,awlen,arlen,rid;
    wire [2:0] awsize,arsize;wire [1:0] awburst,arburst;
    wire awvalid,awready,arvalid,arready,wvalid,wready,rvalid,rready,wlast,rlast;
    wire [255:0] wdata,rdata;wire [31:0] wstrb;
    wire [27:0] t_awaddr,t_araddr,c_awaddr,c_araddr;
    wire [3:0] t_awid,t_arid,t_awlen,t_arlen,c_awid,c_arid,c_awlen,c_arlen;
    wire t_awvalid,t_arvalid,c_awvalid,c_arvalid;
    wire [255:0] t_wdata,c_wdata;wire [31:0] t_wstrb,c_wstrb;
    assign awaddr=mode_ddr[1]?c_awaddr:t_awaddr;
    assign araddr=mode_ddr[1]?c_araddr:t_araddr;
    assign awid=mode_ddr[1]?c_awid:t_awid;
    assign arid=mode_ddr[1]?c_arid:t_arid;
    assign awlen=mode_ddr[1]?c_awlen:t_awlen;
    assign arlen=mode_ddr[1]?c_arlen:t_arlen;
    assign awvalid=ddr_init_done && (mode_ddr[1]?c_awvalid:t_awvalid);
    assign arvalid=ddr_init_done && (mode_ddr[1]?c_arvalid:t_arvalid);
    assign wdata=mode_ddr[1]?c_wdata:t_wdata;
    assign wstrb=mode_ddr[1]?c_wstrb:t_wstrb;
    temporal_filter2 #(.H_NUM(1280),.V_NUM(480)) u_temporal(
        .clk(mrg_clk),.rstn(temporal_rst),.in_data(vga_data),.in_de(vga_de),.in_vs(vga_vs),
        .out_data(tmp_data),.out_de(tmp_de),.out_vs(tmp_vs),.ddr_clk(core_clk),.ddr_rstn(temporal_ddr_rst),
        .axi_awaddr(t_awaddr),.axi_awid(t_awid),.axi_awlen(t_awlen),.axi_awsize(awsize),.axi_awburst(awburst),
        .axi_awready(awready && !mode_ddr[1]),.axi_awvalid(t_awvalid),.axi_wdata(t_wdata),.axi_wstrb(t_wstrb),
        .axi_wlast(wlast && !mode_ddr[1]),.axi_wvalid(wvalid),.axi_wready(wready && !mode_ddr[1]),.axi_araddr(t_araddr),
        .axi_arid(t_arid),.axi_arlen(t_arlen),.axi_arsize(arsize),.axi_arburst(arburst),
        .axi_arvalid(t_arvalid),.axi_arready(arready && !mode_ddr[1]),.axi_rready(rready),.axi_rdata(rdata),
        .axi_rvalid(rvalid && !mode_ddr[1]),.axi_rlast(rlast && !mode_ddr[1]),.axi_rid(rid));
    // Filtered native C6 framing. EOF is the cycle AFTER the 480th EOL,
    // never the next SOF. Sequence belongs to C6, independent of C5 output.
    reg c6_vs_q,c6_de_q,c6_eof;reg [9:0] c6_rows;reg [31:0] c6_native_sequence;
    wire c6_sof=fv2 && !c6_vs_q;
    wire c6_eol=c6_de_q && !fd2;
    always @(posedge p2 or negedge cache_s_rst_n)
        if(!cache_s_rst_n)begin
            c6_vs_q<=0;c6_de_q<=0;c6_eof<=0;c6_rows<=0;c6_native_sequence<=0;
        end else begin
            c6_vs_q<=fv2;c6_de_q<=fd2;c6_eof<=0;
            if(c6_sof)begin c6_rows<=0;c6_native_sequence<=c6_native_sequence+1'b1;end
            else if(c6_eol)begin
                if(c6_rows<480)c6_rows<=c6_rows+1'b1;
                if(c6_rows==479)c6_eof<=1;
            end
        end
    // Constant local epoch is valid only because every runtime reconfiguration
    // holds capture and clears controller/client/sequence together. It is NOT
    // the wire protocol's 32-bit epoch or its one-bit epoch_active indication.
    c6_coherent_framebuffer u_c6_cache(
        .s_clk(p2),.s_rst_n(cache_reset_req_n),.s_sof(c6_sof),.s_eof(c6_eof),
        .s_de(fd2),.s_eol(c6_eol),.s_pixel(f2),.s_sequence(c6_native_sequence+32'd1),.s_epoch(16'd1),
        .d_clk(core_clk),.d_rst_n(cache_reset_req_n),.config_epoch(16'd1),
        .m_clk(mrg_clk),.m_rst_n(cache_reset_req_n),
        .frame_request(cache_request),.frame_ready(cache_ready),.frame_release(cache_release),
        .frame_sequence(cache_sequence),.frame_epoch(cache_epoch),.row_index(cache_row),
        .pixel_address(cache_x),.row_consume(cache_consume),.row_ready(cache_row_ready),.pixel_data(cache_pixel),
        .awaddr(c_awaddr),.awid(c_awid),.awlen(c_awlen),.awvalid(c_awvalid),.awready(awready && mode_ddr[1]),
        .wdata(c_wdata),.wstrb(c_wstrb),.wready(wready && mode_ddr[1]),.wlast(wlast && mode_ddr[1]),
        .araddr(c_araddr),.arid(c_arid),.arlen(c_arlen),.arvalid(c_arvalid),.arready(arready && mode_ddr[1]),
        .rdata(rdata),.rvalid(rvalid && mode_ddr[1]),.rlast(rlast && mode_ddr[1]),.rid(rid),
        .fault(cache_fault),.published_count(cache_published),.rejected_count(cache_rejected));
    wire hdmi_cfg_rst_n,hdmi_init_done;
    video_reset_sync u_hdmi_cfg_reset(cfg_clk,rstn_int && hdmi_active,hdmi_cfg_rst_n);
    assign rstn_in=hdmi_cfg_rst_n;
    ms7200_config u_hdmi_config(.clk(cfg_clk),.reset_n(hdmi_cfg_rst_n),
        .init_done(hdmi_init_done),.scl(iic_scl),.sda(iic_sda));
    wire native_por_n,native_ctl_rst_n,native_meta_sent;
    video_reset_sync u_native_por(pixclk_in,rstn_int,native_por_n);
    cam5_native_capture u_native_capture(.pclk(pixclk_in),.out_clk(clk2core_tx),
        .por_n(native_por_n),.request_n(source_hdmi_request_n),.capture_ready(hdmi_init_done),
        .meta_sent(native_meta_sent),
        .vs_pin(vs_in),.hs_pin(hs_in),.de_pin(de_in),.r_pin(r_in),.g_pin(g_in),.b_pin(b_in),
        .video(native_video),.fault(native_hdmi_fault),.format_ok(native_hdmi_format_ok),
        .meta_valid(native_meta_valid),.meta_ready(native_meta_ready),.meta_payload(native_meta_payload),
        .geometry_mode(native_geometry_mode),.generation(native_generation),
        .dbg_p_tog(dbg_p_tog),.dbg_p_lvl(dbg_p_lvl),.dbg_o_tog(dbg_o_tog),
        .dbg_v0(dbg_v0),.dbg_v1(dbg_v1),.dbg_v2(dbg_v2),.dbg_v3(dbg_v3),.dbg_flags(dbg_flags));
    wire tx_vid_rst_n,tx_fab_rst_n;
    wire native_control_valid,native_control_ready;

    wire [31:0] native_control_data;
    wire [3:0] native_control_k;
    wire native_diag_valid,native_diag_ready;
    wire [159:0] native_diag_payload;
    (* ASYNC_REG="TRUE" *) reg [7:0] native_status_meta,native_status_sync;
    always @(posedge clk2core_tx or negedge fab_rst_n)
        if(!fab_rst_n)begin native_status_meta<=0;native_status_sync<=0;end
        else begin
            native_status_meta<={2'b0,dbg_p_lvl,native_hdmi_format_ok,hdmi_init_done,hdmi_active};
            native_status_sync<=native_status_meta;
        end
    cam5_native_diag_sender u_native_diag_sender(.pclk(pixclk_in),.out_clk(clk2core_tx),.rst_n(fab_rst_n),
        .request(hdmi_active_tx),.status(native_status_sync),
        .dbg_vs_toggle(dbg_p_tog[0]),
        .dbg_v0(dbg_v0),.dbg_v1(dbg_v1),.dbg_v2(dbg_v2),.dbg_v3(dbg_v3),.dbg_flags(dbg_flags),
        .diag_valid(native_diag_valid),.diag_ready(native_diag_ready),.diag_payload(native_diag_payload));
    // Same lifetime as the capture: a FLUSH drops any queued META with its SOF.
    video_reset_sync u_native_ctl_reset(clk2core_tx,rstn_int && source_hdmi_request_n,native_ctl_rst_n);
    cam5_native_control_mux u_native_control(.clk(clk2core_tx),.rst_n(native_ctl_rst_n),
        .diag_valid(native_diag_valid),.diag_ready(native_diag_ready),.diag_payload(native_diag_payload),
        .meta_valid(native_meta_valid),.meta_ready(native_meta_ready),.meta_payload(native_meta_payload),
        .control_ready(native_control_ready),.control_valid(native_control_valid),
        .control_data(native_control_data),.control_k(native_control_k),.meta_sent(native_meta_sent));
    // Native HDMI packetizer runs entirely in the 125 MHz fabric domain; the
    // legacy camera packetizer keeps its original mrg_clk input domain.
    wire tx_req=tx_request_n && hdmi_active;
    wire legacy_tx_req=tx_request_n && !hdmi_active && !capture_hold;
    video_reset_sync u_tx_vid_reset(clk2core_tx,tx_req,tx_vid_rst_n);
    video_reset_sync u_tx_fab_reset(clk2core_tx,tx_req,tx_fab_rst_n);
    wire legacy_tx_vid_rst_n,legacy_tx_fab_rst_n;
    video_reset_sync u_legacy_tx_vid_reset(mrg_clk,legacy_tx_req,legacy_tx_vid_rst_n);
    video_reset_sync u_legacy_tx_fab_reset(clk2core_tx,legacy_tx_req,legacy_tx_fab_rst_n);
    wire [31:0] video_txd,sfp_tx_d;wire [3:0] video_txk,sfp_tx_k;
    wire [31:0] legacy_video_txd;wire [3:0] legacy_video_txk;
    wire native_packetizer_fault,legacy_packetizer_fault;
    wire [18:0] framed_video;
    cam5_video_tx u_sfp_video_tx(.vid_clk(clk2core_tx),.vid_rst_n(tx_vid_rst_n),.vid_data(native_video),
        .fab_clk(clk2core_tx),.fab_rst_n(tx_fab_rst_n),.link_ready(hsst_pll_lock && txdone2),
        .txd(video_txd),.txk(video_txk),.fault(native_packetizer_fault));
    cam5_video_tx u_legacy_video_tx(.vid_clk(mrg_clk),.vid_rst_n(legacy_tx_vid_rst_n),.vid_data(framed_video),
        .fab_clk(clk2core_tx),.fab_rst_n(legacy_tx_fab_rst_n),.link_ready(hsst_pll_lock && txdone2),
        .txd(legacy_video_txd),.txk(legacy_video_txk),.fault(legacy_packetizer_fault));
    assign packetizer_fault=hdmi_active_tx?native_packetizer_fault:legacy_packetizer_fault;
    wire [31:0] selected_control_data=hdmi_active_tx?native_control_data:control_data;
    wire [3:0] selected_control_k=hdmi_active_tx?native_control_k:control_k;
    wire selected_control_valid=hdmi_active_tx?native_control_valid:control_valid;
    wire [31:0] selected_video_txd=hdmi_active_tx?video_txd:legacy_video_txd;
    wire [3:0] selected_video_txk=hdmi_active_tx?video_txk:legacy_video_txk;
    cam5_forward_mux u_forward(.clk(clk2core_tx),.rst_n(fab_rst_n),
        .video_data(selected_video_txd),.video_k(selected_video_txk),.control_valid(selected_control_valid),
        .control_ready(control_ready),.control_data(selected_control_data),.control_k(selected_control_k),
        .tx_data(sfp_tx_d),.tx_k(sfp_tx_k));
    assign native_control_ready=hdmi_active_tx && control_ready;
    wire meta_mrg_rst_n,meta_fab_rst_n;
    wire meta_request=rstn_int && !capture_hold && !hdmi_active;
    video_reset_sync u_meta_mrg_reset(mrg_clk,meta_request,meta_mrg_rst_n);
    video_reset_sync u_meta_fab_reset(clk2core_tx,meta_request,meta_fab_rst_n);
    wire meta_source_ready,metadata_pending;wire [31:0] meta_source_data;
    (* ASYNC_REG="TRUE" *)reg [1:0] epoch_active_mrg;
    always @(posedge mrg_clk or negedge mrg_rst_n)
        if(!mrg_rst_n)epoch_active_mrg<=0;
        else epoch_active_mrg<={epoch_active_mrg[0],epoch_active_cfg};
    cam5_wire_framing framing(.clk(mrg_clk),.rst_n(mrg_rst_n),
        .enable(meta_mrg_rst_n),.bypass(hdmi_active),.mode720(mode_mrg[1]),
        .metadata_enable(epoch_active_mrg[1]),.in_video(selected_video),.out_video(framed_video),
        .meta_valid(metadata_pending),.meta_ready(meta_source_ready),.frame_id(meta_source_data),
        .fault(framing_fault));
    cam5_bundle_cdc #(.WIDTH(32)) metadata(.s_clk(mrg_clk),.s_rst_n(meta_mrg_rst_n),
        .s_data(meta_source_data),.s_valid(metadata_pending),.s_ready(meta_source_ready),
        .d_clk(clk2core_tx),.d_rst_n(meta_fab_rst_n),.d_data(frame_sequence),
        .d_valid(meta_valid),.d_ready(meta_ready));
    assign sfp0_tx_disable=0;assign sfp1_tx_disable=1;
    assign led_sfp_pll=hsst_pll_lock;assign led_sfp_ready=hsst_pll_lock && txdone2;
    assign led_sfp_rxsync=rxpcs && !sfp0_los;assign led_sfp_pcs=rxsig;
    assign hdmi_int_led=hdmi_init_done;
    reg [25:0] heartbeat_count;
    always @(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)begin heartbeat_count<=0;heart_beat_led<=0;end
        else if(heartbeat_count==24999999)begin heartbeat_count<=0;heart_beat_led<=!heart_beat_led;end
        else heartbeat_count<=heartbeat_count+1'b1;
    hsst_test u_hsst(.i_free_clk(sys_clk),.i_p_refckp_0(sfp_refckp),.i_p_refckn_0(sfp_refckn),
        .i_wtchdg_clr_0(!sys_rst_n),.o_wtchdg_st_0(),.o_pll_done_0(),
        .o_txlane_done_2(txdone2),.o_txlane_done_3(txdone3),.o_rxlane_done_2(),.o_rxlane_done_3(),
        .o_p_clk2core_tx_2(clk2core_tx),.i_p_tx2_clk_fr_core(clk2core_tx),.i_p_tx3_clk_fr_core(clk2core_tx),
        .i_p_rx2_clk_fr_core(clk2core_tx),.i_p_rx3_clk_fr_core(clk2core_tx),.o_p_pll_lock_0(hsst_pll_lock),
        .o_p_rx_sigdet_sta_2(rxsig),.o_p_rx_sigdet_sta_3(),.o_p_lx_cdr_align_2(),.o_p_lx_cdr_align_3(),
        .o_p_pcs_lsm_synced_2(rxpcs),.o_p_pcs_lsm_synced_3(),
        .i_p_l2rxn(sfp0_rxn),.i_p_l2rxp(sfp0_rxp),.i_p_l3rxn(sfp1_rxn),.i_p_l3rxp(sfp1_rxp),
        .o_p_l2txn(sfp0_txn),.o_p_l2txp(sfp0_txp),.o_p_l3txn(sfp1_txn),.o_p_l3txp(sfp1_txp),
        .i_txd_2(sfp_tx_d),.i_tdispsel_2(4'b0),.i_tdispctrl_2(4'b0),.i_txk_2(sfp_tx_k),
        .i_txd_3(32'hbc0028bc),.i_tdispsel_3(4'b0),.i_tdispctrl_3(4'b0),.i_txk_3(4'b1001),
        .o_rxstatus_2(),.o_rxd_2(rxdata),.o_rdisper_2(rxdisper),.o_rdecer_2(rxdecer),.o_rxk_2(rxk),
        .o_rxstatus_3(),.o_rxd_3(),.o_rdisper_3(),.o_rdecer_3(),.o_rxk_3(),.i_pll_rst_0(!sys_rst_n));
    DDR3_50H u_DDR3_50H(.ref_clk(sys_clk),.resetn(ddr_rst),.ddr_init_done(ddr_init_done),
        .ddrphy_clkin(core_clk),.pll_lock(ddr_pll_lock),.axi_awaddr(awaddr),.axi_awuser_ap(1'b0),
        .axi_awuser_id(awid),.axi_awlen(awlen),.axi_awready(awready),.axi_awvalid(awvalid),
        .axi_wdata(wdata),.axi_wstrb(wstrb),.axi_wready(wready),.axi_wusero_id(),.axi_wusero_last(wlast),
        .axi_araddr(araddr),.axi_aruser_ap(1'b0),.axi_aruser_id(arid),.axi_arlen(arlen),
        .axi_arready(arready),.axi_arvalid(arvalid),.axi_rdata(rdata),.axi_rid(rid),.axi_rlast(rlast),
        .axi_rvalid(rvalid),.apb_clk(1'b0),.apb_rst_n(1'b1),.apb_sel(1'b0),.apb_enable(1'b0),
        .apb_addr(8'b0),.apb_write(1'b0),.apb_ready(),.apb_wdata(16'b0),.apb_rdata(),.apb_int(),
        .mem_rst_n(mem_rst_n),.mem_ck(mem_ck),.mem_ck_n(mem_ck_n),.mem_cke(mem_cke),.mem_cs_n(mem_cs_n),
        .mem_ras_n(mem_ras_n),.mem_cas_n(mem_cas_n),.mem_we_n(mem_we_n),.mem_odt(mem_odt),
        .mem_a(mem_a),.mem_ba(mem_ba),.mem_dqs(mem_dqs),.mem_dqs_n(mem_dqs_n),.mem_dq(mem_dq),.mem_dm(mem_dm),
        .debug_data(),.debug_slice_state(),.debug_calib_ctrl(),.ck_dly_set_bin(),.ck_dly_en(1'b0),
        .init_ck_dly_step(8'h05),.wl_step_ov_warning(),.dll_step(),.dll_lock(),.init_read_clk_ctrl(8'b0),
        .init_slip_step(16'b0),.force_read_clk_ctrl(1'b0),.ddrphy_gate_update_en(1'b0),
        .update_com_val_err_flag(),.rd_fake_stop(1'b0));
endmodule
