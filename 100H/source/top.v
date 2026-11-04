// ==========================================
// ��ƵԴ����ѡ���뱣������һ����ע�͵���һ��
// ==========================================
 `define USE_OV5640
//`define USE_HDMI


module top #(
    parameter   MSI_NUM = 5,
    parameter   AXI_ID_LEN      = 4, 
                AXI_ID_M_LEN    = $clog2(7) + AXI_ID_LEN,
		        AXI_DATA_LEN    = 128, 
		        AXI_DATA_SIZE   = $clog2(AXI_DATA_LEN/8), 	        
		        AXI_STRB_LEN    = AXI_DATA_LEN / 8, 
                AXI_ADDR_WIDTH  = 32,  
                BURST_LEN = 16, // [ZEROFIX 2026-09-19] 16-beat bursts = IP max awlen+1 = FIFO depth;
                                // the staging gate then requires a FULL FIFO before the AW
                                // is presented, so the IP can never consume an empty slot
                                // (that produced the 8-on/8-off zero blocks in DDR).
                                // prior: BURST_LEN = 8,  // [WATERFIX2 2026-09-19] 16-beat bursts into the 16-deep ddr_fifo16_w
                                // had zero slack: one stalled drain cycle dropped a W beat and
                                // the DDR3 IP (never seeing awlen+1 beats) killed the whole M00
                                // write path. 8-beat bursts + the free-space AW gate leave 2x room.
                                // with single-beat bursts (every beat needs its own B
                                // before the next is issued). 16-beat bursts cut the B
                                // demand 16x and keep one outstanding txn per master.
                                // [ZDIAG 2026-09-18] old '=16 stripes unchanged' verdict
                                // predates the ledger fix and is not applicable.

    //DDR3
    parameter  MEM_ROW_WIDTH    = 15         ,
               MEM_COLUMN_WIDTH = 10         ,
               MEM_BANK_WIDTH   = 3          ,
               MEM_DQ_WIDTH     = 16         ,
               MEM_DQS_WIDTH    = 2          ,
               CTRL_ADDR_WIDTH  = MEM_ROW_WIDTH + MEM_BANK_WIDTH + MEM_COLUMN_WIDTH
)(

    input                       free_clk         /* synthesis PAP_MARK_DEBUG="<3/c0/0>" */,       //25MHZ
    input                       button_rst_n    ,

    ////////////////// PCIE ////////////////
    input                       perst_n         ,
    input                       ref_clk_n       ,      
    input                       ref_clk_p       ,      
    input           [1:0]       rxn             ,
    input           [1:0]       rxp             ,
    output  wire    [1:0]       txn             ,
    output  wire    [1:0]       txp             ,
    output wire                 ref_led         ,
    output wire                 pclk_led        ,

    ////////////////// SFP fiber RX (QR3 HSST CH2) [SFP 2026-09-29] ////////////////
    // ref clock shared with PCIe (ref_clk_p/n F6/E6, 100MHz)
    input                       sfp_l2rxn       ,
    input                       sfp_l2rxp       ,
    output wire                 sfp_l2txn       ,
    output wire                 sfp_l2txp       ,
    output wire                 sfp_tx_disable  ,
    // output wire                 smlh_link_up     ,
    // output wire                 rdlh_link_up     ,



    ////////////DDR3
    output                               mem_cs_n                  ,  
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_WIDTH-1:0]      mem_a                     ,
    output      [MEM_BANK_WIDTH-1:0]     mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,

    output reg                           heart_beat_led            ,

`ifdef USE_OV5640
    /////////////CAM
    input                                cmos1_pclk               /* synthesis PAP_MARK_DEBUG="<1/c0/0>,<3/t0/0>" */, 
    input                                cmos1_vsync              /* synthesis PAP_MARK_DEBUG="<1/t0/0>,<3/t0/1>" */, 
    input                                cmos1_href               /* synthesis PAP_MARK_DEBUG="<1/t0/1>,<3/t0/2>" */, 
    input       [7 : 0]                  cmos1_data              , 
    output                               cmos1_rst_n             , 
    // output                               cmos1_pwdn              , 
    output                               cmos1_scl               , 
    inout                                cmos1_sda               ,                 



    /////////////CAM2 (FMC 2nd DVP camera)
    input                                cmos2_pclk               /* synthesis PAP_MARK_DEBUG="<2/c0/0>,<3/t0/3>" */, 
    input                                cmos2_vsync              /* synthesis PAP_MARK_DEBUG="<2/t0/0>,<3/t0/4>" */, 
    input                                cmos2_href               /* synthesis PAP_MARK_DEBUG="<2/t0/1>,<3/t0/5>" */, 
    input       [7 : 0]                  cmos2_data              , 
    output                               cmos2_rst_n             , 
    output                               cmos2_scl               , 
    inout                                cmos2_sda                 , 

    // ---- CAM3 (FMC 3rd OV5640) ----
    input                                cmos3_pclk               , 
    input                                cmos3_vsync              , 
    input                                cmos3_href               , 
    input       [7 : 0]                  cmos3_data              , 
    output                               cmos3_rst_n             , 
    output                               cmos3_scl               , 
    inout                                cmos3_sda               , 
    ///////////// CAM4 (FMC 4th DVP camera)
    input                                cmos4_pclk               , 
    input                                cmos4_vsync              , 
    input                                cmos4_href               , 
    input       [7 : 0]                  cmos4_data              , 
    output                               cmos4_rst_n             , 
    output                               cmos4_scl               , 
    inout                                cmos4_sda
`elsif USE_HDMI
    /////////////////////////  HDMI
    //ms72XX
    output            rstn_out,

    // FMC I2C 
    output            iic_scl,
    inout             iic_sda, 

    // output            iic_tx_scl,
    // inout             iic_tx_sda, 

    //HDMI IN
    input             pixclk_in ,                            
    input             vs_in     , 
    input             hs_in     , 
    input             de_in     ,
    input     [7:0]   r_in      , 
    input     [7:0]   g_in      , 
    input     [7:0]   b_in      
`endif
);

    wire clk_50m, clk_150m, clk_10m, locked;


///////////////////////////// AXI wires between crossbar and DDR3 ///////////////////////////
wire [27:0]                 ddr_axi_awaddr     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awuser_ap  ;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_awuser_id  /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                  ddr_axi_awlen      /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awready    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awvalid    /* synthesis PAP_MARK_DEBUG="true" */;
wire [2:0]                  ddr_axi_awsize     /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0]                  ddr_axi_awburst    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_awlock     ;
wire [3:0]                  ddr_axi_awcache    ;
wire [2:0]                  ddr_axi_awprot     ;
wire [3:0]                  ddr_axi_awqos      ;

wire [15:0] cam_s_data_available, cam2_s_data_available, cam3_s_data_available, cam4_s_data_available;
wire [AXI_DATA_LEN-1:0]     ddr_axi_wdata      /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_DATA_LEN-1:0]     ddr_axi_wdata_ddr3      ;
wire [AXI_STRB_LEN-1:0]     ddr_axi_wstrb      /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_STRB_LEN-1:0]     ddr_axi_wstrb_ddr3      ;
wire                        ddr_axi_fifo_full/* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_wvalid     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_wready_ddr3    ;
wire [AXI_ID_LEN-1:0]       ddr_axi_wusero_id  /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_wusero_last_ddr3;
wire                        ddr_axi_wlast      /* synthesis PAP_MARK_DEBUG="true" */;

wire [1:0]                  ddr_axi_bresp      /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_bvalid     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_bready     /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_bid        /* synthesis PAP_MARK_DEBUG="true" */;



wire [27:0]                 ddr_axi_araddr     ;
wire                        ddr_axi_aruser_ap  ;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_aruser_id  ;
wire [AXI_DATA_LEN-1:0]     ddr_axi_aruser     ;
wire [3:0]                  ddr_axi_arlen      ;
wire                        ddr_axi_arready    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_arvalid    ;

wire [AXI_DATA_LEN-1:0]     ddr_axi_rdata      /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_DATA_LEN-1:0]     ddr_axi_rdata_ddr3;
wire [AXI_ID_M_LEN-1:0]     ddr_axi_rid        /* synthesis PAP_MARK_DEBUG="true" */;
wire [AXI_ID_LEN-1:0]       ddr_axi_rid_ddr3;
wire                        ddr_axi_rlast      /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_rlast_ddr3;
wire                        ddr_axi_rvalid     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_rvalid_ddr3;
wire                        ddr_axi_rready     /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_fifo_empty;





wire [2:0]                  ddr_axi_arsize     /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0]                  ddr_axi_arburst    /* synthesis PAP_MARK_DEBUG="true" */;
wire                        ddr_axi_arlock     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                  ddr_axi_arcache    /* synthesis PAP_MARK_DEBUG="true" */;
wire [2:0]                  ddr_axi_arprot     /* synthesis PAP_MARK_DEBUG="true" */;
wire [3:0]                  ddr_axi_arqos      /* synthesis PAP_MARK_DEBUG="true" */;
wire [1:0]                  ddr_axi_rresp      /* synthesis PAP_MARK_DEBUG="true" */;


wire [1:0]                  ddr_axi_buser      ;
wire [1:0]                  ddr_axi_ruser      ;
wire [1:0]                  ddr_axi_awuser     ;
wire [1:0]                  ddr_axi_wuser      ;


/////////////////////////////     DDR3   ///////////////////////////////////////////////////
parameter TH_1S = 27'd33000000;
reg  [26:0]                 cnt                        ;
always@(posedge core_clk or negedge ddr_init_done) begin
   if (!ddr_init_done)
      cnt <= 27'd0;
   else if ( cnt >= TH_1S )
      cnt <= 27'd0;
   else
      cnt <= cnt + 27'd1;
end

always @(posedge core_clk or negedge ddr_init_done) begin
   if (!ddr_init_done)
      heart_beat_led <= 1'd1;
   else if ( cnt >= TH_1S )
      heart_beat_led <= ~heart_beat_led;
end

wire [4:0] wr_water_level;
wire       w_fifo_empty;   // [AWFIX 2026-09-19] declared early: used by the FIFO port map below
ddr_fifo16_w ddr_fifo16_w (
  .wr_data({ddr_axi_wstrb, ddr_axi_wdata}),              // input [143:0]
  .wr_en(ddr_axi_wvalid),                  // input
  .wr_water_level(wr_water_level),    // output [4:0]
  .full(ddr_axi_fifo_full),                    // output
  .almost_full(),      // output
  .rd_data({ddr_axi_wstrb_ddr3, ddr_axi_wdata_ddr3}),              // output [143:0]
  .rd_en(ddr_axi_wready_ddr3),                  // input
  .empty(w_fifo_empty),      // output  [AWFIX 2026-09-19]
  .almost_empty(),    // output
  .clk(axi_clk),                      // input
  .rst(axi_rst)                       // input
);



ddr_fifo16_r ddr_fifo16_r (
  .wr_data({ddr_axi_rid_ddr3, ddr_axi_rlast_ddr3, ddr_axi_rdata_ddr3}),              // input [132:0]
  .wr_en(ddr_axi_rvalid_ddr3),                  // input
  .full(),                    // output
  .almost_full(),      // output
  .rd_data({ddr_axi_rid[AXI_ID_LEN-1 : 0], ddr_axi_rlast, ddr_axi_rdata}),              // output [132:0]
  .rd_en(ddr_axi_rready),                  // input
  .empty(ddr_axi_fifo_empty),                  // output
  .almost_empty(),    // output
  .clk(axi_clk),                      // input
  .rst(axi_rst)                       // input
);
assign ddr_axi_rid[AXI_ID_M_LEN-1 : AXI_ID_LEN] = ddr_axi_ar_sid[AXI_ID_M_LEN-1 : AXI_ID_LEN];

// [AWFIX 2026-09-19] the old water-gate REGISTER re-evaluated awvalid every cycle
// while waiting for the IP's awready: a closing gate RETRACTED an already-asserted
// awvalid (AXI violation). Worse, the crossbar's awready was tied straight to the
// IP's awready, so whenever the gate blocked while the IP idled ready-high, the
// crossbar retired the AW into the void: the IP never saw the burst, its W beats
// drained unpaired, wusero_last never came and the fabric-minted B (below) never
// rose -- the permanent M00 write wedge. Replaced by latch-and-hold shims defined
// after the B-channel bridge.


wire [4:0] ddr_observe_locks;
wire ddr_observe_fail;
wire [3:0] ddr_observe_reset, ddr_observe_cpd;
wire [2:0] ddr_observe_dps;
wire [5:0] ddr_observe_errors;
wire [33:0] ddr_observe_calib;
wire [43:0] ddr_observe_slice;
ddr3 #(
    .MEM_ROW_WIDTH              (MEM_ROW_WIDTH                ),
    .MEM_COLUMN_WIDTH           (MEM_COLUMN_WIDTH             ),
    .MEM_BANK_WIDTH             (MEM_BANK_WIDTH               ),
    .MEM_DQ_WIDTH               (MEM_DQ_WIDTH                 ),
    .MEM_DM_WIDTH               (MEM_DQS_WIDTH                ),
    .MEM_DQS_WIDTH              (MEM_DQS_WIDTH                ),
    .CTRL_ADDR_WIDTH            (CTRL_ADDR_WIDTH              )
  )
ddr3(
    .ref_clk                    (free_clk                     ),
    .resetn                     (button_rst_n                 ),

    .core_clk                   (core_clk                     ),
    .ddr_init_done              (ddr_init_done                ),

    .pll_lock (ddr_observe_locks[0]),
    .phy_pll_lock (ddr_observe_locks[1]),
    .gpll_lock (ddr_observe_locks[2]),
    .rst_gpll_lock (ddr_observe_locks[3]),
    .ddrphy_cpd_lock (ddr_observe_locks[4]),

    .axi_awaddr                 (ddr3_aw_addr                  ), // [AWFIX]
    .axi_awuser_ap              (ddr3_aw_ap                    ),
    .axi_awuser_id              (ddr3_aw_id                    ),
    .axi_awlen                  (ddr3_aw_len                   ),
    .axi_awready                (ddr_axi_awready               ),
    .axi_awvalid                (ddr3_aw_v                     ),

    .axi_wdata                  (ddr_axi_wdata_ddr3            ),
    .axi_wstrb                  (ddr_axi_wstrb_ddr3            ),
    .axi_wready                 (ddr_axi_wready_ddr3           ),
    .axi_wusero_id              (ddr_axi_wusero_id             ),
    .axi_wusero_last            (ddr_axi_wusero_last_ddr3      ),

    .axi_araddr                 (ddr3_ar_addr                  ), // [ARFIX]
    .axi_aruser_ap              (ddr3_ar_ap                    ),
    .axi_aruser_id              (ddr3_ar_id                    ),
    .axi_arlen                  (ddr3_ar_len                   ),
    .axi_arready                (ddr_axi_arready               ),
    .axi_arvalid                (ddr3_ar_v                     ),

    .axi_rdata                  (ddr_axi_rdata_ddr3                 ),
    .axi_rid                    (ddr_axi_rid_ddr3                   ),
    .axi_rlast                  (ddr_axi_rlast_ddr3                 ),
    .axi_rvalid                 (ddr_axi_rvalid_ddr3                ),

    .apb_clk                    (1'b0                         ),
    .apb_rst_n                  (1'b0                         ),
    .apb_sel                    (1'b0                         ),
    .apb_enable                 (1'b0                         ),
    .apb_addr                   (8'd0                         ),
    .apb_write                  (1'b0                         ),
    .apb_ready                  (                             ),
    .apb_wdata                  (16'd0                        ),
    .apb_rdata                  (                             ),

    .mem_cs_n                   (mem_cs_n                     ),
    .mem_rst_n                  (mem_rst_n                    ),
    .mem_ck                     (mem_ck                       ),
    .mem_ck_n                   (mem_ck_n                     ),
    .mem_cke                    (mem_cke                      ),
    .mem_ras_n                  (mem_ras_n                    ),
    .mem_cas_n                  (mem_cas_n                    ),
    .mem_we_n                   (mem_we_n                     ),
    .mem_odt                    (mem_odt                      ),
    .mem_a                      (mem_a                        ),
    .mem_ba                     (mem_ba                       ),
    .mem_dqs                    (mem_dqs                      ),
    .mem_dqs_n                  (mem_dqs_n                    ),
    .mem_dq                     (mem_dq                       ),
    .mem_dm                     (mem_dm                       ),

    .dbg_gate_start             (1'b0                         ),
    .dbg_cpd_start              (1'b0                         ),
    .dbg_ddrphy_rst_n           (1'b1                         ),
    .dbg_gpll_scan_rst          (1'b0                         ),

    .samp_position_dyn_adj      (1'b0                         ),
    .init_samp_position_even    (16'd0                        ),
    .init_samp_position_odd     (16'd0                        ),

    .wrcal_position_dyn_adj     (1'b0                         ),
    .init_wrcal_position        (16'd0                        ),

    .force_read_clk_ctrl        (1'b0                         ),
    .init_slip_step             (8'd0                         ),
    .init_read_clk_ctrl         (6'd0                         ),

    .debug_calib_ctrl (ddr_observe_calib),
    .dbg_dll_upd_state          (                             ),
    .dbg_slice_status           (                             ),
    .dbg_slice_state (ddr_observe_slice),
    .debug_data                 (                             ),
    .debug_gpll_dps_phase       (                             ),

    .dbg_rst_dps_state (ddr_observe_dps),
    .dbg_tran_err_rst_cnt (ddr_observe_errors),
    .dbg_ddrphy_init_fail (ddr_observe_fail),

    .debug_cpd_offset_adj       (1'b0                         ),
    .debug_cpd_offset_dir       (1'b0                         ),
    .debug_cpd_offset           (10'd0                        ),
    .debug_dps_cnt_dir0         (                             ),
    .debug_dps_cnt_dir1         (                             ),

    .ck_dly_en                  (1'b0                         ),
    .init_ck_dly_step           (8'd0                         ),
    .ck_dly_set_bin             (                             ),

    .align_error                (                             ),
    .debug_rst_state (ddr_observe_reset),
    .debug_cpd_state (ddr_observe_cpd)
  );

wire axi_clk;
wire axi_rst;
assign axi_clk = core_clk;
assign axi_rst = ~ddr_init_done;

/////////////////////////////////////// [WARB 2026-09-19] camera write arbiter ///////
// Single-outstanding 2-master arbiter replacing the crossbar M00 write path.
// Bench-proven: 9741 consecutive bursts, zero wedge (sim/wedge/tb_wedge.v).
wire [3:0]   arb_s_awid;
wire [31:0]  arb_s_awaddr;
wire [7:0]   arb_s_awlen;
wire [2:0]   arb_s_awsize, arb_s_awprot;
wire [1:0]   arb_s_awburst;
wire         arb_s_awlock;
wire [3:0]   arb_s_awcache;
wire         arb_s_awvalid, arb_s_awready;
wire [127:0] arb_s_wdata;
wire [15:0]  arb_s_wstrb;
wire         arb_s_wlast, arb_s_wvalid, arb_s_wready;
wire [3:0]   arb_s_bid;
wire [1:0]   arb_s_bresp;
wire         arb_s_bvalid, arb_s_bready;
// parked crossbar M00 write ports
wire [6:0]   arb2x_awid;
wire [31:0]  arb2x_awaddr;
wire [7:0]   arb2x_awlen;
wire [2:0]   arb2x_awsize, arb2x_awprot;
wire [1:0]   arb2x_awburst;
wire         arb2x_awlock;
wire [3:0]   arb2x_awcache;
wire [3:0]   arb2x_awqos;
wire [1:0]   arb2x_awuser;
wire         arb2x_awvalid;
wire [127:0] arb2x_wdata;
wire [15:0]  arb2x_wstrb;
wire         arb2x_wlast, arb2x_wvalid;
wire [1:0]   arb2x_wuser;

// DELIVERY: isolated cam5 DDR preprocessing integration.
wire [5:0] six_hold, six_writer_idle, six_pending, six_flush, six_dma_idle;
wire [5:0] runtime_allowed_mask, runtime_idle_raw;
wire [191:0] six_prev, six_bank0, six_bank1, six_sequence;
wire [11:0] six_published;
wire delivery_hold;
// While native HDMI is active the four CMOS cameras (cam1..cam4) are parked so
// their writers and DMA stop competing for DDR bandwidth with the HDMI halves.
wire cam_native_park;
assign delivery_hold=six_hold[4];
wire [31:0] delivery_prev;
wire [1:0] delivery_published;
wire [31:0] delivery_araddr;
wire [7:0] delivery_arlen;
wire [2:0] delivery_arsize;
wire [1:0] delivery_arburst;
wire delivery_arvalid;
wire delivery_arready;
wire [127:0] delivery_rdata;
wire [1:0] delivery_rresp;
wire delivery_rlast;
wire delivery_rvalid;
wire delivery_rready;
wire [31:0] delivery_awaddr;
wire [7:0] delivery_awlen;
wire [2:0] delivery_awsize;
wire [1:0] delivery_awburst;
wire delivery_awvalid;
wire delivery_awready;
wire [127:0] delivery_wdata;
wire [15:0] delivery_wstrb;
wire delivery_wlast;
wire delivery_wvalid;
wire delivery_wready;
wire [1:0] delivery_bresp;
wire delivery_bvalid;
wire delivery_bready;
wire [3:0] npu_reg_axi_awqos;
wire [3:0] npu_reg_axi_awregion;
wire [6:0] npu_reg_axi_arid;
wire [31:0] npu_reg_axi_araddr;
wire [7:0] npu_reg_axi_arlen;
wire [2:0] npu_reg_axi_arsize;
wire [1:0] npu_reg_axi_arburst;
wire npu_reg_axi_arlock;
wire [3:0] npu_reg_axi_arcache;
wire [2:0] npu_reg_axi_arprot;
wire [3:0] npu_reg_axi_arqos;
wire [3:0] npu_reg_axi_arregion;
wire npu_reg_axi_arvalid;
wire npu_reg_axi_rready;


// Isolated C5 AW descriptor slot; W/B and bridge admission are unchanged.
wire [3:0] c5_queued_awid;
wire [31:0] c5_queued_awaddr;
wire [7:0] c5_queued_awlen;
wire [2:0] c5_queued_awsize;
wire [1:0] c5_queued_awburst;
wire c5_queued_awlock;
wire [3:0] c5_queued_awcache;
wire [2:0] c5_queued_awprot;
wire c5_queued_awvalid;
wire c5_queued_awready;
wire c5_aw_pending;
c5_aw_descriptor_buffer c5_aw_descriptor_buffer_u (
 .clk(axi_clk), .rst(axi_rst),
 .u_payload({cam5_axi_awid, cam5_axi_awaddr, 4'b0000, cam5_axi_awlen, cam5_axi_awsize, cam5_axi_awburst, cam5_axi_awlock, cam5_axi_awcache, cam5_axi_awprot}), .u_valid(cam5_axi_awvalid), .u_ready(cam5_axi_awready),
 .d_payload({c5_queued_awid, c5_queued_awaddr, c5_queued_awlen, c5_queued_awsize, c5_queued_awburst, c5_queued_awlock, c5_queued_awcache, c5_queued_awprot}), .d_valid(c5_queued_awvalid), .d_ready(c5_queued_awready),
 .pending(c5_aw_pending)
);
// PCIe DDR bypass: port 0 is the unchanged camera/delivery write arbiter.
wire [60:0] camarb_aw;
wire camarb_awvalid, camarb_awready;
wire [127:0] camarb_wdata;
wire [15:0] camarb_wstrb;
wire camarb_wlast, camarb_wvalid, camarb_wready;
wire [3:0] camarb_bid;
wire [1:0] camarb_bresp;
wire camarb_bvalid, camarb_bready;
ddr_w_arb u_ddr_w_arb (
    .clk(axi_clk), .rst(axi_rst),
    .m0_awid    (ov5640_axi_awid    ), .m0_awaddr (ov5640_axi_awaddr ),
    .m0_awlen   (ov5640_axi_awlen   ), .m0_awsize (ov5640_axi_awsize ),
    .m0_awburst (ov5640_axi_awburst ), .m0_awlock (ov5640_axi_awlock ),
    .m0_awcache (ov5640_axi_awcache ), .m0_awprot (ov5640_axi_awprot ),
    .m0_awvalid (ov5640_axi_awvalid ), .m0_awready(ov5640_axi_awready),
    .m0_wdata   (ov5640_axi_wdata   ), .m0_wstrb  (ov5640_axi_wstrb  ),
    .m0_wlast   (ov5640_axi_wlast   ), .m0_wvalid (ov5640_axi_wvalid ),
    .m0_wready  (ov5640_axi_wready  ),
    .m0_bid     (ov5640_axi_bid     ), .m0_bresp  (ov5640_axi_bresp  ),
    .m0_bvalid  (ov5640_axi_bvalid  ), .m0_bready (ov5640_axi_bready ),
    .m1_awid    (cam2_axi_awid      ), .m1_awaddr (cam2_axi_awaddr   ),
    .m1_awlen   (cam2_axi_awlen     ), .m1_awsize (cam2_axi_awsize   ),
    .m1_awburst (cam2_axi_awburst   ), .m1_awlock (cam2_axi_awlock   ),
    .m1_awcache (cam2_axi_awcache   ), .m1_awprot (cam2_axi_awprot   ),
    .m1_awvalid (cam2_axi_awvalid   ), .m1_awready(cam2_axi_awready  ),
    .m1_wdata   (cam2_axi_wdata     ), .m1_wstrb  (cam2_axi_wstrb    ),
    .m1_wlast   (cam2_axi_wlast     ), .m1_wvalid (cam2_axi_wvalid   ),
    .m1_wready  (cam2_axi_wready    ),
    .m1_bid     (cam2_axi_bid       ), .m1_bresp  (cam2_axi_bresp    ),
    .m1_bvalid  (cam2_axi_bvalid    ), .m1_bready (cam2_axi_bready   ),
    // [CAM3-FIX 2026-09-26] cam3 write channel reconnected (was tied off for bisect)
    .m2_awid    (cam3_axi_awid      ), .m2_awaddr (cam3_axi_awaddr   ),
    .m2_awlen   (cam3_axi_awlen     ), .m2_awsize (cam3_axi_awsize   ),
    .m2_awburst (cam3_axi_awburst   ), .m2_awlock (cam3_axi_awlock   ),
    .m2_awcache (cam3_axi_awcache   ), .m2_awprot (cam3_axi_awprot   ),
    .m2_awvalid (cam3_axi_awvalid   ), .m2_awready(cam3_axi_awready  ),
    .m2_wdata   (cam3_axi_wdata     ), .m2_wstrb  (cam3_axi_wstrb    ),
    .m2_wlast   (cam3_axi_wlast     ), .m2_wvalid (cam3_axi_wvalid   ),
    .m2_wready  (cam3_axi_wready    ),
    .m2_bid     (cam3_axi_bid       ), .m2_bresp  (cam3_axi_bresp    ),
    .m2_bvalid  (cam3_axi_bvalid    ), .m2_bready (cam3_axi_bready   ),
    // [CAM4 2026-09-27] cam4 write channel joins the arbiter as master 3
    .m3_awid    (cam4_axi_awid      ), .m3_awaddr (cam4_axi_awaddr   ),
    .m3_awlen   (cam4_axi_awlen     ), .m3_awsize (cam4_axi_awsize   ),
    .m3_awburst (cam4_axi_awburst   ), .m3_awlock (cam4_axi_awlock   ),
    .m3_awcache (cam4_axi_awcache   ), .m3_awprot (cam4_axi_awprot   ),
    .m3_awvalid (cam4_axi_awvalid   ), .m3_awready(cam4_axi_awready  ),
    .m3_wdata   (cam4_axi_wdata     ), .m3_wstrb  (cam4_axi_wstrb    ),
    .m3_wlast   (cam4_axi_wlast     ), .m3_wvalid (cam4_axi_wvalid   ),
    .m3_wready  (cam4_axi_wready    ),
    .m3_bid     (cam4_axi_bid     ), .m3_bresp  (cam4_axi_bresp  ),
    .m3_bvalid  (cam4_axi_bvalid  ), .m3_bready (cam4_axi_bready ),
    // [SFP 2026-09-30] fiber cam5/cam6 join as masters 4/5
    .m4_awid    (c5_queued_awid    ), .m4_awaddr (c5_queued_awaddr ),
    .m4_awlen   (c5_queued_awlen   ), .m4_awsize (c5_queued_awsize ),
    .m4_awburst (c5_queued_awburst ), .m4_awlock (c5_queued_awlock ),
    .m4_awcache (c5_queued_awcache ), .m4_awprot (c5_queued_awprot ),
    .m4_awvalid (c5_queued_awvalid ), .m4_awready(c5_queued_awready),
    .m4_wdata   (cam5_axi_wdata   ), .m4_wstrb  (cam5_axi_wstrb  ),
    .m4_wlast   (cam5_axi_wlast   ), .m4_wvalid (cam5_axi_wvalid ),
    .m4_wready  (cam5_axi_wready  ),
    .m4_bid     (cam5_axi_bid     ), .m4_bresp  (cam5_axi_bresp  ),
    .m4_bvalid  (cam5_axi_bvalid  ), .m4_bready (cam5_axi_bready ),
    .m5_awid    (cam6_axi_awid    ), .m5_awaddr (cam6_axi_awaddr ),
    .m5_awlen   (cam6_axi_awlen   ), .m5_awsize (cam6_axi_awsize ),
    .m5_awburst (cam6_axi_awburst ), .m5_awlock (cam6_axi_awlock ),
    .m5_awcache (cam6_axi_awcache ), .m5_awprot (cam6_axi_awprot ),
    .m5_awvalid (cam6_axi_awvalid ), .m5_awready(cam6_axi_awready),
    .m5_wdata   (cam6_axi_wdata   ), .m5_wstrb  (cam6_axi_wstrb  ),
    .m5_wlast   (cam6_axi_wlast   ), .m5_wvalid (cam6_axi_wvalid ),
    .m5_wready  (cam6_axi_wready  ),
    .m5_bid     (cam6_axi_bid     ), .m5_bresp  (cam6_axi_bresp  ),
    .m5_bvalid  (cam6_axi_bvalid  ), .m5_bready (cam6_axi_bready ),
.m6_awid(4'hd),
.m6_awaddr(delivery_awaddr),
.m6_awlen(delivery_awlen),
.m6_awsize(delivery_awsize),
.m6_awburst(delivery_awburst),
.m6_awlock(1'b0),
.m6_awcache(4'd0),
.m6_awprot(3'd0),
.m6_awvalid(delivery_awvalid),
.m6_awready(delivery_awready),
.m6_wdata(delivery_wdata),
.m6_wstrb(delivery_wstrb),
.m6_wlast(delivery_wlast),
.m6_wvalid(delivery_wvalid),
.m6_wready(delivery_wready),
.m6_bid(),
.m6_bresp(delivery_bresp),
.m6_bvalid(delivery_bvalid),
.m6_bready(delivery_bready),
    .s_awid(camarb_aw[60:57]), .s_awaddr(camarb_aw[56:25]),
    .s_awlen(camarb_aw[24:17]), .s_awsize(camarb_aw[16:14]),
    .s_awburst(camarb_aw[13:12]), .s_awlock(camarb_aw[11]),
    .s_awcache(camarb_aw[10:7]), .s_awprot(camarb_aw[6:4]),
    .s_awvalid(camarb_awvalid), .s_awready(camarb_awready),
    .s_wdata(camarb_wdata), .s_wstrb(camarb_wstrb),
    .s_wlast(camarb_wlast), .s_wvalid(camarb_wvalid),
    .s_wready(camarb_wready),
    .s_bid(camarb_bid), .s_bresp(camarb_bresp),
    .s_bvalid(camarb_bvalid), .s_bready(camarb_bready)
);
assign camarb_aw[3:0] = 4'b0000;
// DDR glue AW/W side now fed by the arbiter
assign ddr_axi_awaddr     = arb_s_awaddr;
assign ddr_axi_awlen      = arb_s_awlen;
assign ddr_axi_awvalid    = arb_s_awvalid;
assign arb_s_awready      = ddr_axi_awready_xbar;
assign ddr_axi_wdata      = arb_s_wdata;
assign ddr_axi_wstrb      = arb_s_wstrb;
assign ddr_axi_wlast      = arb_s_wlast;
assign ddr_axi_wvalid     = arb_s_wvalid;
assign arb_s_wready       = !ddr_axi_fifo_full;
assign arb_s_bvalid       = ddr_axi_bvalid;
assign arb_s_bresp        = ddr_axi_bresp;
assign ddr_axi_bready     = arb_s_bready;
// awuser id now carries the arbiter's source id (m0=0001, m1=0100 4-bit form)
assign ddr_axi_awuser_id  = {3'b000, arb_s_awid};
assign ddr_axi_awuser_ap  = 1'b0;
assign arb_s_bid          = ddr3_aw_id[3:0];

/////////////////////////////////////// DDR3 B-Channel Bridge //////////////////////////////////////
reg  [AXI_ID_M_LEN-1 : AXI_ID_LEN]                  ddr_axi_aw_sid        ;//ddr_axi_awuser_id??3?
reg  [AXI_ID_M_LEN-1 : AXI_ID_LEN]                  ddr_axi_ar_sid        ;//ddr_axi_aruser_id??3?

// latch aw_sid on AW handshake
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_aw_sid <= {(AXI_ID_M_LEN - AXI_ID_LEN){1'b0}};
    end 
    else if (ddr_axi_awvalid && ddr_axi_awready_xbar) begin   // [AWFIX] ack at latch
        ddr_axi_aw_sid <= ddr_axi_awuser_id[AXI_ID_M_LEN-1 : AXI_ID_LEN];
    end
end

// latch ar_sid on AR handshake
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_ar_sid <= {(AXI_ID_M_LEN - AXI_ID_LEN){1'b0}};
    end 
    else if (ddr_axi_arvalid && ddr_axi_arready_xbar) begin   // [ARFIX] ack at latch
        ddr_axi_ar_sid <= ddr_axi_aruser_id[AXI_ID_M_LEN-1 : AXI_ID_LEN];
    end
end


reg                         ddr_axi_bvalid_int    ;
reg  [1:0]                  ddr_axi_bresp_int     ;
reg  [AXI_ID_M_LEN-1:0]     ddr_axi_bid_int       ;
always @(posedge axi_clk) begin
    if (axi_rst) begin
        ddr_axi_bvalid_int  <= 1'b0;
        ddr_axi_bresp_int   <= 2'b01;
        ddr_axi_bid_int <= {AXI_ID_M_LEN{1'b0}};
    end 
    else begin
        if (ddr_axi_wready_ddr3 && ddr_axi_wusero_last_ddr3) begin
            ddr_axi_bvalid_int <= 1'b1;
            ddr_axi_bresp_int  <= 2'b00;
            ddr_axi_bid_int <= {ddr_axi_aw_sid[AXI_ID_M_LEN-1 : AXI_ID_LEN], ddr_axi_wusero_id};
        end 
        else if (ddr_axi_bvalid && ddr_axi_bready) begin
            ddr_axi_bvalid_int <= 1'b0;
            ddr_axi_bresp_int  <= 2'b01;
            ddr_axi_bid_int <= {AXI_ID_M_LEN{1'b0}};
        end
    end
end

assign ddr_axi_bvalid = ddr_axi_bvalid_int;
assign ddr_axi_bresp  = ddr_axi_bresp_int;
assign ddr_axi_bid    = ddr_axi_bid_int;

/////////////////////////////////////// DDR3 AW/AR latch shims [AWFIX/ARFIX 2026-09-19] ///
// Proper single-handshake adapters between the crossbar and the DDR3 IP.
// The crossbar is acknowledged exactly when we latch a request; the request is
// then HELD with stable payload until the IP accepts (AXI-legal, no retraction).
// Single-outstanding end-to-end (no held request + write FIFO empty + no pending
// B for AW; read FIFO empty for AR) also keeps the aw_sid/ar_sid ID rebuilds sane.
// [STAGE 2026-09-19] The DDR3 IP's W channel is UNTHROTTLEABLE: it pulses
// wready at its own pace and counts awlen+1 beats itself (see the IP's own
// example_design -- there is no wvalid at all). Presenting an AW before its
// beats are in the FIFO let the IP consume GHOST beats from an empty FIFO;
// the real beats then stranded in the FIFO forever and blocked all later AWs
// (the permanent M00 write wedge). Hold each latched AW until its ENTIRE
// burst is staged in the FIFO, then present it: during IP consumption the
// FIFO only drains, so every demanded beat is guaranteed present.
wire aw_burst_fits   = (ddr_axi_awlen < (5'd16 - wr_water_level));
wire aw_latch_now    = ddr_axi_awvalid && !ddr3_aw_v && !aw_hold_v
                       && w_fifo_empty && aw_burst_fits && !ddr_axi_bvalid_int;
// [VKFS 2026-09-26] single-outstanding DDR read gate.  The bridge keeps ONE
// ddr_axi_ar_sid register for R-channel routing; allowing a 2nd AR to latch
// (from a different slave, e.g. cam1's KF on S05) before the 1st read's RLAST
// retags the earlier burst with the wrong slave ID -> host read never
// completes -> crossbar M00 read channel wedges.  Host frame DMA (S00) and
// KF prefetch (S05) are both low-bandwidth, so serialising is free here.
reg  rd_inflight;
wire ar_latch_now    = ddr_axi_arvalid && !ddr3_ar_v && ddr_axi_fifo_empty && !rd_inflight;
always @(posedge axi_clk) begin
    if (axi_rst)                                rd_inflight <= 1'b0;
    else if (ar_latch_now)                      rd_inflight <= 1'b1;
    else if (ddr_axi_rvalid_ddr3 && ddr_axi_rlast_ddr3) rd_inflight <= 1'b0;
end

reg              ddr3_aw_v, ddr3_ar_v;
reg              aw_hold_v;
reg [27:0]       ddr3_aw_addr, ddr3_ar_addr;
reg [3:0]        ddr3_aw_len,  ddr3_ar_len;
reg              ddr3_aw_ap,   ddr3_ar_ap;
reg [AXI_ID_M_LEN-1:0] ddr3_aw_id, ddr3_ar_id;

wire aw_stage_ok = (wr_water_level >= ({1'b0, ddr3_aw_len} + 5'd1)) && !w_fifo_empty;

always @(posedge axi_clk) begin
    if (axi_rst) begin
        aw_hold_v <= 1'b0;
        ddr3_aw_v <= 1'b0;
        ddr3_aw_id <= 0;
    end
    else begin
        if (aw_latch_now) begin
            aw_hold_v   <= 1'b1;
            ddr3_aw_addr <= ddr_axi_awaddr[27:0];
            ddr3_aw_len  <= ddr_axi_awlen;
            ddr3_aw_ap   <= ddr_axi_awuser_ap;
            ddr3_aw_id   <= ddr_axi_awuser_id;
        end
        if (aw_hold_v && !ddr3_aw_v && aw_stage_ok) begin
            aw_hold_v <= 1'b0;
            ddr3_aw_v <= 1'b1;
        end
        else if (ddr3_aw_v && ddr_axi_awready) begin
            ddr3_aw_v <= 1'b0;
        end
    end
end
always @(posedge axi_clk) begin
    if (axi_rst) ddr3_ar_v <= 1'b0;
    else if (ar_latch_now)                       ddr3_ar_v <= 1'b1;
    else if (ddr3_ar_v && ddr_axi_arready)       ddr3_ar_v <= 1'b0;
end
always @(posedge axi_clk) begin
    if (ar_latch_now) begin
        ddr3_ar_addr <= ddr_axi_araddr[27:0];
        ddr3_ar_len  <= ddr_axi_arlen;
        ddr3_ar_ap   <= ddr_axi_aruser_ap;
        ddr3_ar_id   <= ddr_axi_aruser_id;
    end
end
// crossbar-facing readies: acknowledge exactly at latch time
wire ddr_axi_awready_xbar = aw_latch_now;
wire ddr_axi_arready_xbar = ar_latch_now;


/////////////////////////////     DDR3   ///////////////////////////////////////////////////
    wire       [AXI_ID_LEN-1:0]       pcie_axi_awid   ;
    wire       [31:0]                 pcie_axi_awaddr ;
    wire       [ 3:0]                 pcie_axi_awlen  ;
    wire       [ 2:0]                 pcie_axi_awsize ;
    wire       [ 1:0]                 pcie_axi_awburst;
    wire                              pcie_axi_awlock ;
    wire       [ 3:0]                 pcie_axi_awcache;
    wire       [ 2:0]                 pcie_axi_awprot ;
    wire       [ 3:0]                 pcie_axi_awqos  ;
    wire                              pcie_axi_awvalid;
    wire                              pcie_axi_awready;

    wire       [AXI_DATA_LEN-1:0]     pcie_axi_wdata  ;
    wire       [AXI_STRB_LEN-1:0]     pcie_axi_wstrb  ;
    wire                              pcie_axi_wlast  ;
    wire                              pcie_axi_wvalid ;
    wire                              pcie_axi_wready ;

    wire       [AXI_ID_LEN-1:0]       pcie_axi_bid    ;
    wire       [ 1:0]                 pcie_axi_bresp  ;
    wire                              pcie_axi_bvalid ;
    wire                              pcie_axi_bready ;

// DDR aperture matches crossbar M00: [0, 0x20000000), including LUT 0x02400000.
// Port 0 retains ALL non-DDR writes on the existing register crossbar.
wire [121:0] host_route_aw;
wire [1:0] host_route_awvalid, host_route_awready;
wire [255:0] host_route_wdata;
wire [31:0] host_route_wstrb;
wire [1:0] host_route_wlast, host_route_wvalid, host_route_wready;
wire [7:0] host_route_bid;
wire [3:0] host_route_bresp;
wire [1:0] host_route_bvalid, host_route_bready;
wire [60:0] merged_ddr_aw;
pcie_write_demux u_pcie_write_demux (
 .clk(axi_clk), .rst(axi_rst), .s_ddr(pcie_axi_awaddr[31:29] == 3'b000),
 .s_aw({pcie_axi_awid,pcie_axi_awaddr,4'b0000,pcie_axi_awlen,
        pcie_axi_awsize,pcie_axi_awburst,pcie_axi_awlock,
        pcie_axi_awcache,pcie_axi_awprot,pcie_axi_awqos}),
 .s_awvalid(pcie_axi_awvalid), .s_awready(pcie_axi_awready),
 .s_wdata(pcie_axi_wdata), .s_wstrb(pcie_axi_wstrb),
 .s_wlast(pcie_axi_wlast), .s_wvalid(pcie_axi_wvalid), .s_wready(pcie_axi_wready),
 .s_bid(pcie_axi_bid), .s_bresp(pcie_axi_bresp),
 .s_bvalid(pcie_axi_bvalid), .s_bready(pcie_axi_bready),
 .m_aw(host_route_aw), .m_awvalid(host_route_awvalid), .m_awready(host_route_awready),
 .m_wdata(host_route_wdata), .m_wstrb(host_route_wstrb),
 .m_wlast(host_route_wlast), .m_wvalid(host_route_wvalid), .m_wready(host_route_wready),
 .m_bid(host_route_bid), .m_bresp(host_route_bresp),
 .m_bvalid(host_route_bvalid), .m_bready(host_route_bready)
);
pcie_ddr_write_merge u_pcie_ddr_write_merge (
 .clk(axi_clk), .rst(axi_rst),
 .m_aw({host_route_aw[121:61],camarb_aw}),
 .m_awvalid({host_route_awvalid[1],camarb_awvalid}),
 .m_awready({host_route_awready[1],camarb_awready}),
 .m_wdata({host_route_wdata[255:128],camarb_wdata}),
 .m_wstrb({host_route_wstrb[31:16],camarb_wstrb}),
 .m_wlast({host_route_wlast[1],camarb_wlast}),
 .m_wvalid({host_route_wvalid[1],camarb_wvalid}),
 .m_wready({host_route_wready[1],camarb_wready}),
 .m_bid({host_route_bid[7:4],camarb_bid}),
 .m_bresp({host_route_bresp[3:2],camarb_bresp}),
 .m_bvalid({host_route_bvalid[1],camarb_bvalid}),
 .m_bready({host_route_bready[1],camarb_bready}),
 .s_aw(merged_ddr_aw), .s_awvalid(arb_s_awvalid), .s_awready(arb_s_awready),
 .s_wdata(arb_s_wdata), .s_wstrb(arb_s_wstrb),
 .s_wlast(arb_s_wlast), .s_wvalid(arb_s_wvalid), .s_wready(arb_s_wready),
 .s_bid(arb_s_bid), .s_bresp(arb_s_bresp),
 .s_bvalid(arb_s_bvalid), .s_bready(arb_s_bready)
);
assign {arb_s_awid,arb_s_awaddr,arb_s_awlen,arb_s_awsize,
        arb_s_awburst,arb_s_awlock,arb_s_awcache,arb_s_awprot} = merged_ddr_aw[60:4];

    wire       [AXI_ID_LEN-1:0]       pcie_axi_arid   ;
    wire       [31:0]                 pcie_axi_araddr ;
    wire       [ 3:0]                 pcie_axi_arlen  ;
    wire       [ 2:0]                 pcie_axi_arsize ;
    wire       [ 1:0]                 pcie_axi_arburst;
    wire                              pcie_axi_arlock ;
    wire       [ 3:0]                 pcie_axi_arcache;
    wire       [ 2:0]                 pcie_axi_arprot ;
    wire       [ 3:0]                 pcie_axi_arqos  ;
    wire                              pcie_axi_arvalid;
    wire                              pcie_axi_arready;

    wire       [AXI_ID_LEN-1:0]       pcie_axi_rid    ;
    wire       [AXI_DATA_LEN-1:0]     pcie_axi_rdata  ;
    wire       [ 1:0]                 pcie_axi_rresp  ;
    wire                              pcie_axi_rlast  ;
    wire                              pcie_axi_rvalid ;
    wire                              pcie_axi_rready ;

    wire                              pcie_clk        ;
    wire                              pcie_rst        ;

    wire [MSI_NUM-2 : 0]      msi_req       ;
    wire [MSI_NUM-2 : 0]      msi_grant     ;


    assign msi_req = {1'd0, 1'b0, 2'b00}; //[MSIFIX 2026-09-13] freerun: xdma_req stuck high = MSI storm, camera MSI off

pcie_fifo #(
    .MSI_NUM(MSI_NUM)
)
pcie_fifo(
.diag_free_clk(free_clk), .diag_ddr_init(ddr_init_done),
.diag_ddr_locks({ddr_observe_fail,ddr_observe_locks}),
.diag_ddr_debug({27'd0,ddr_observe_calib,ddr_observe_slice,ddr_observe_errors,ddr_observe_dps,ddr_observe_cpd,ddr_observe_reset,ddr_observe_fail,ddr_observe_locks}),    

    .button_rst_n(button_rst_n)    ,

    ////////////////// PCIE ////////////////
    .perst_n     (perst_n     )    ,
    .ref_clk_n   (ref_clk_n   )    ,      
    .ref_clk_p   (ref_clk_p   )    ,      
    .rxn         (rxn         )    ,
    .rxp         (rxp         )    ,
    .txn         (txn         )    ,
    .txp         (txp         )    ,
    .ref_led     (ref_led     )    ,
    .pclk_led    (pclk_led    )    ,
    // .smlh_link_up(smlh_link_up)    ,
    // .rdlh_link_up(rdlh_link_up)    ,

    .fifo_pcie_clk(pcie_clk   )    ,
    .fifo_pcie_rst(pcie_rst   )    ,

    .i_msi_req  (msi_req     )     ,
    .o_msi_grant(msi_grant   )     ,
    ///////////////// AXI FOR DDR3 //////////////////////////////
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),

    .axi_awid   (pcie_axi_awid   )     ,
    .axi_awaddr (pcie_axi_awaddr )     ,
    .axi_awlen  (pcie_axi_awlen  )     ,
    .axi_awsize (pcie_axi_awsize )     ,
    .axi_awburst(pcie_axi_awburst)     ,
    .axi_awlock (pcie_axi_awlock )     ,
    .axi_awcache(pcie_axi_awcache)     ,
    .axi_awprot (pcie_axi_awprot )     ,
    .axi_awqos  (pcie_axi_awqos  )     ,
    .axi_awvalid(pcie_axi_awvalid)     ,
    .axi_awready(pcie_axi_awready)     ,
    
    .axi_wdata  (pcie_axi_wdata  )     ,
    .axi_wstrb  (pcie_axi_wstrb  )     ,
    .axi_wlast  (pcie_axi_wlast  )     ,
    .axi_wvalid (pcie_axi_wvalid )     ,
    .axi_wready (pcie_axi_wready )     ,
    
    .axi_bid    (pcie_axi_bid    )     ,
    .axi_bresp  (pcie_axi_bresp  )     ,
    .axi_bvalid (pcie_axi_bvalid )     ,
    .axi_bready (pcie_axi_bready )     ,
    
    .axi_arid   (pcie_axi_arid   )     ,
    .axi_araddr (pcie_axi_araddr )     ,
    .axi_arlen  (pcie_axi_arlen  )     ,
    .axi_arsize (pcie_axi_arsize )     ,
    .axi_arburst(pcie_axi_arburst)     ,
    .axi_arlock (pcie_axi_arlock )     ,
    .axi_arcache(pcie_axi_arcache)     ,
    .axi_arprot (pcie_axi_arprot )     ,
    .axi_arqos  (pcie_axi_arqos  )     ,
    .axi_arvalid(pcie_axi_arvalid)     ,
    .axi_arready(pcie_axi_arready)     ,
    
    .axi_rid    (pcie_axi_rid    )     ,
    .axi_rdata  (pcie_axi_rdata  )     ,
    .axi_rresp  (pcie_axi_rresp  )     ,
    .axi_rlast  (pcie_axi_rlast  )     ,
    .axi_rvalid (pcie_axi_rvalid )     ,
    .axi_rready (pcie_axi_rready )           
);


/////////////////////////////////   CMD    ////////////////////////////////////////////////
ov5640_clk ov5640_clk(
  .clkout2(clk_10m),
  .clkout1(clk_150m),      // output 150M
  .clkout0(),             //[CLKFIX 2026-09-13] PLL bypassed (never locks @25MHz in)

  .lock(locked),          // output
  .clkin1(free_clk)         // input
);

//[CLKFIX 2026-09-13] i2c domain runs on free_clk directly (25MHz)
assign clk_50m = free_clk;

///////////////////////////// AXI-Lite wires for ovreg ///////////////////////////
wire [31:0]                 ovreg_axil_awaddr   ;
wire                        ovreg_axil_awvalid  ;
wire                        ovreg_axil_awready  ;
wire [31:0]                 ovreg_axil_wdata    ;
wire [3:0]                  ovreg_axil_wstrb    ;
wire                        ovreg_axil_wvalid   ;
wire                        ovreg_axil_wready   ;
wire [1:0]                  ovreg_axil_bresp    ;
wire                        ovreg_axil_bvalid   ;
wire                        ovreg_axil_bready   ;
wire [31:0]                 ovreg_axil_araddr   ;
wire                        ovreg_axil_arvalid  ;
wire                        ovreg_axil_arready  ;
wire [31:0]                 ovreg_axil_rdata    ;
wire [1:0]                  ovreg_axil_rresp    ;
wire                        ovreg_axil_rvalid   ;
wire                        ovreg_axil_rready   ;

// --- CAM segment (decoder m0, addr[8]=0: 0x2000_0000~0x2000_00FF -> ov5640_reg) ---
wire                        cam_axil_awvalid, cam_axil_awready;
wire [31:0]                 cam_axil_awaddr;
wire                        cam_axil_wvalid, cam_axil_wready;
wire [31:0]                 cam_axil_wdata;
wire [3:0]                  cam_axil_wstrb;
wire                        cam_axil_bvalid, cam_axil_bready;
wire [1:0]                  cam_axil_bresp;
wire                        cam_axil_arvalid, cam_axil_arready;
wire [31:0]                 cam_axil_araddr;
wire                        cam_axil_rvalid, cam_axil_rready;
wire [31:0]                 cam_axil_rdata;
wire [1:0]                  cam_axil_rresp;

// --- cam2 register window (M01 sub-window 0x2000_0200~0x02FF) ---
wire                        cam2_axil_awvalid, cam2_axil_awready;
wire [31:0]                 cam2_axil_awaddr;
wire                        cam2_axil_wvalid, cam2_axil_wready;
wire [31:0]                 cam2_axil_wdata;
wire [3:0]                  cam2_axil_wstrb;
wire                        cam2_axil_bvalid, cam2_axil_bready;
wire [1:0]                  cam2_axil_bresp;
wire                        cam2_axil_arvalid, cam2_axil_arready;
wire [31:0]                 cam2_axil_araddr;
wire                        cam2_axil_rvalid, cam2_axil_rready;
wire [31:0]                 cam2_axil_rdata;
wire [1:0]                  cam2_axil_rresp;

// --- cam3 register window (M01 sub-window 0x2000_0400~0x04FF) ---
wire                        cam3_axil_awvalid, cam3_axil_awready;
wire [31:0]                 cam3_axil_awaddr;
wire                        cam3_axil_wvalid, cam3_axil_wready;
wire [31:0]                 cam3_axil_wdata;
wire [3:0]                  cam3_axil_wstrb;
wire                        cam3_axil_bvalid, cam3_axil_bready;
wire [1:0]                  cam3_axil_bresp;
wire                        cam3_axil_arvalid, cam3_axil_arready;
wire [31:0]                 cam3_axil_araddr;
wire                        cam3_axil_rvalid, cam3_axil_rready;
wire [31:0]                 cam3_axil_rdata;
wire [1:0]                  cam3_axil_rresp;

// --- cam4 register window (M01 sub-window 0x2000_0600~0x07FF) ---
wire                        cam4_axil_awvalid, cam4_axil_awready;
wire [31:0]                 cam4_axil_awaddr;
wire                        cam4_axil_wvalid, cam4_axil_wready;
wire [31:0]                 cam4_axil_wdata;
wire [3:0]                  cam4_axil_wstrb;
wire                        cam4_axil_bvalid, cam4_axil_bready;
wire [1:0]                  cam4_axil_bresp;
wire                        cam4_axil_arvalid, cam4_axil_arready;
wire [31:0]                 cam4_axil_araddr;
wire                        cam4_axil_rvalid, cam4_axil_rready;
wire [31:0]                 cam4_axil_rdata;
wire [1:0]                  cam4_axil_rresp;


// --- cam2 capture / write stream (S04) ---
wire [31 : 0]               cam2_cmd_addr    ;
wire [31 : 0]               cam2_cmd_len     ;
wire                        cam2_cmd_valid   ;
wire                        cam2_cmd_ready   ;
wire [AXI_DATA_LEN-1 : 0]   cam2_s_data      ;
wire                        cam2_s_data_valid;
wire                        cam2_s_data_last ;
wire                        cam2_s_data_ready;
wire [AXI_ID_LEN-1:0]   cam2_axi_awid    ;
wire [31:0]             cam2_axi_awaddr  ;
wire [3:0]              cam2_axi_awlen   ;
wire [2:0]              cam2_axi_awsize  ;
wire [1:0]              cam2_axi_awburst ;
wire                    cam2_axi_awlock  ;
wire [3:0]              cam2_axi_awcache ;
wire [2:0]              cam2_axi_awprot  ;
wire                    cam2_axi_awvalid ;
wire                    cam2_axi_awready ;
wire [AXI_DATA_LEN-1:0] cam2_axi_wdata   ;
wire [AXI_STRB_LEN-1:0] cam2_axi_wstrb   ;
wire                    cam2_axi_wlast   ;
wire                    cam2_axi_wvalid  ;
wire                    cam2_axi_wready  ;
wire [AXI_ID_LEN-1:0]   cam2_axi_bid     ;
wire [1:0]              cam2_axi_bresp   ;
wire                    cam2_axi_bvalid  ;
wire                    cam2_axi_bready  ;

// --- PREP segment (decoder m1, addr[8]=1: 0x2000_0100~0x2000_01FF -> prep_regs) ---
wire                        prep_axil_awvalid, prep_axil_awready;
wire [31:0]                 prep_axil_awaddr;
wire                        prep_axil_wvalid, prep_axil_wready;
wire [31:0]                 prep_axil_wdata;
wire [3:0]                  prep_axil_wstrb;
wire                        prep_axil_bvalid, prep_axil_bready;
wire [1:0]                  prep_axil_bresp;
wire                        prep_axil_arvalid, prep_axil_arready;
wire [31:0]                 prep_axil_araddr;
wire                        prep_axil_rvalid, prep_axil_rready;
wire [31:0]                 prep_axil_rdata;
wire [1:0]                  prep_axil_rresp;

///////////////////////////// ovreg_axi signals ///////////////////////////
wire [AXI_ID_M_LEN-1:0]     ovreg_axi_awid     ;
wire [31:0]                 ovreg_axi_awaddr   ;
wire [3:0]                  ovreg_axi_awlen    ;
wire [2:0]                  ovreg_axi_awsize   ;
wire [1:0]                  ovreg_axi_awburst  ;
wire                        ovreg_axi_awlock   ;
wire [3:0]                  ovreg_axi_awcache  ;
wire [2:0]                  ovreg_axi_awprot   ;
wire [3:0]                  ovreg_axi_awqos    ;
wire [3:0]                  ovreg_axi_awregion ;
wire                        ovreg_axi_awvalid  ;
wire                        ovreg_axi_awready  ;

wire [AXI_DATA_LEN-1:0]     ovreg_axi_wdata     ;
wire [AXI_STRB_LEN-1:0]     ovreg_axi_wstrb     ;
wire                        ovreg_axi_wlast     ;
wire                        ovreg_axi_wvalid    ;
wire                        ovreg_axi_wready    ;

wire [AXI_ID_M_LEN-1:0]     ovreg_axi_bid       ;
wire [1:0]                  ovreg_axi_bresp     ;
wire                        ovreg_axi_bvalid    ;
wire                        ovreg_axi_bready    ;

wire [AXI_ID_M_LEN-1:0]     ovreg_axi_arid     ;
wire [31:0]                 ovreg_axi_araddr   ;
wire [3:0]                  ovreg_axi_arlen    ;
wire [2:0]                  ovreg_axi_arsize   ;
wire [1:0]                  ovreg_axi_arburst  ;
wire                        ovreg_axi_arlock   ;
wire [3:0]                  ovreg_axi_arcache  ;
wire [2:0]                  ovreg_axi_arprot   ;
wire [3:0]                  ovreg_axi_arqos    ;
wire [3:0]                  ovreg_axi_arregion ;
wire                        ovreg_axi_arvalid  ;
wire                        ovreg_axi_arready  ;

wire [AXI_DATA_LEN-1:0]     ovreg_axi_rdata    ;
wire [AXI_ID_M_LEN-1:0]     ovreg_axi_rid      ;
wire [1:0]                  ovreg_axi_rresp    ;
wire                        ovreg_axi_rlast    ;
wire                        ovreg_axi_rvalid   ;
wire                        ovreg_axi_rready   ;


axi_to_axi_lite #(
    .AXI_ID_LEN(AXI_ID_M_LEN)
)
axi_to_axi_lite(
    .axi_clk(axi_clk),
    .axi_rst(axi_rst),
    // ==========================================
    // ??? AXI Slave  (128-bit)
    // ==========================================
    .s_axi_awid    (ovreg_axi_awid    ),
    .s_axi_awaddr  (ovreg_axi_awaddr  ),
    .s_axi_awlen   (ovreg_axi_awlen   ),
    .s_axi_awsize  (ovreg_axi_awsize  ),
    .s_axi_awburst (ovreg_axi_awburst ),
    .s_axi_awlock  (ovreg_axi_awlock  ),
    .s_axi_awcache (ovreg_axi_awcache ),
    .s_axi_awprot  (ovreg_axi_awprot  ),
    .s_axi_awqos   (ovreg_axi_awqos   ),
    .s_axi_awregion(ovreg_axi_awregion),
    .s_axi_awvalid (ovreg_axi_awvalid ),
    .s_axi_awready (ovreg_axi_awready ),

    .s_axi_wdata   (ovreg_axi_wdata  ),
    .s_axi_wstrb   (ovreg_axi_wstrb  ),
    .s_axi_wlast   (ovreg_axi_wlast  ),
    .s_axi_wvalid  (ovreg_axi_wvalid ),
    .s_axi_wready  (ovreg_axi_wready ),

    .s_axi_bid     (ovreg_axi_bid    ),
    .s_axi_bresp   (ovreg_axi_bresp  ),
    .s_axi_bvalid  (ovreg_axi_bvalid ),
    .s_axi_bready  (ovreg_axi_bready ),

    .s_axi_arid    (ovreg_axi_arid   ),
    .s_axi_araddr  (ovreg_axi_araddr ),
    .s_axi_arlen   (ovreg_axi_arlen  ),
    .s_axi_arsize  (ovreg_axi_arsize ),
    .s_axi_arburst (ovreg_axi_arburst),
    .s_axi_arlock  (ovreg_axi_arlock ),
    .s_axi_arcache (ovreg_axi_arcache),
    .s_axi_arprot  (ovreg_axi_arprot ),
    .s_axi_arqos   (ovreg_axi_arqos  ),
    .s_axi_arregion(ovreg_axi_arregion),
    .s_axi_arvalid (ovreg_axi_arvalid),
    .s_axi_arready (ovreg_axi_arready),

    .s_axi_rid     (ovreg_axi_rid    ),
    .s_axi_rdata   (ovreg_axi_rdata  ),
    .s_axi_rresp   (ovreg_axi_rresp  ),
    .s_axi_rlast   (ovreg_axi_rlast  ),
    .s_axi_rvalid  (ovreg_axi_rvalid ),
    .s_axi_rready  (ovreg_axi_rready ),


    // ==========================================
    // AXI-Lite Master  (32-bit)
    // ==========================================
    .m_axil_awaddr (ovreg_axil_awaddr ),
    .m_axil_awvalid(ovreg_axil_awvalid),
    .m_axil_awready(ovreg_axil_awready),

    .m_axil_wdata  (ovreg_axil_wdata  ),
    .m_axil_wstrb  (ovreg_axil_wstrb  ),
    .m_axil_wvalid (ovreg_axil_wvalid ),
    .m_axil_wready (ovreg_axil_wready ),

    .m_axil_bresp  (ovreg_axil_bresp  ),
    .m_axil_bvalid (ovreg_axil_bvalid ),
    .m_axil_bready (ovreg_axil_bready ),

    .m_axil_araddr (ovreg_axil_araddr ),
    .m_axil_arvalid(ovreg_axil_arvalid),
    .m_axil_arready(ovreg_axil_arready),

    .m_axil_rdata  (ovreg_axil_rdata  ),
    .m_axil_rresp  (ovreg_axil_rresp  ),
    .m_axil_rvalid (ovreg_axil_rvalid ),
    .m_axil_rready (ovreg_axil_rready )
);


wire [31 : 0]               cam_cmd_addr    /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31 : 0]               cam_cmd_len     /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_cmd_valid   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_cmd_ready   /*synthesis PAP_MARK_DEBUG="1"*/;

wire [AXI_DATA_LEN-1 : 0]   cam_s_data      /*synthesis PAP_MARK_DEBUG="1"*/;
// preprocess tap (camera raw stream -> preprocess -> processed write)
wire [AXI_DATA_LEN-1 : 0]   cam_tap_data    ;
wire                        cam_tap_data_valid;
wire                        cam_tap_data_last ;
wire                        cam_tap_data_ready;
wire                        cam_s_data_valid/*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_s_data_last /*synthesis PAP_MARK_DEBUG="1"*/;
wire                        cam_s_data_ready/*synthesis PAP_MARK_DEBUG="1"*/;

wire [1 : 0]                cam_irq;     

// --- AXI-Lite address decoder: splits M01 window by addr[8] ---
//   addr[8]=0 -> ov5640_reg segment (CAM regs)
//   addr[8]=1 -> prep_regs segment  (PREP/INJ regs, doc +0x100~0x17C)
wire [31:0] c5_legacy_awaddr,c5_mail_awaddr;
wire c5_legacy_awvalid,c5_mail_awvalid;
wire c5_legacy_awready,c5_mail_awready;
wire [31:0] c5_legacy_wdata,c5_mail_wdata;
wire [3:0] c5_legacy_wstrb,c5_mail_wstrb;
wire c5_legacy_wvalid,c5_mail_wvalid;
wire c5_legacy_wready,c5_mail_wready;
wire [1:0] c5_legacy_bresp,c5_mail_bresp;
wire c5_legacy_bvalid,c5_mail_bvalid;
wire c5_legacy_bready,c5_mail_bready;
wire [31:0] c5_legacy_araddr,c5_mail_araddr;
wire c5_legacy_arvalid,c5_mail_arvalid;
wire c5_legacy_arready,c5_mail_arready;
wire [31:0] c5_legacy_rdata,c5_mail_rdata;
wire [1:0] c5_legacy_rresp,c5_mail_rresp;
wire c5_legacy_rvalid,c5_mail_rvalid;
wire c5_legacy_rready,c5_mail_rready;
c5_axil_page_router c5_page(.clk(axi_clk),.rst(axi_rst),
.s_awaddr(ovreg_axil_awaddr),.m_awaddr({c5_mail_awaddr,c5_legacy_awaddr}),
.s_awvalid(ovreg_axil_awvalid),.m_awvalid({c5_mail_awvalid,c5_legacy_awvalid}),
.s_awready(ovreg_axil_awready),.m_awready({c5_mail_awready,c5_legacy_awready}),
.s_wdata(ovreg_axil_wdata),.m_wdata({c5_mail_wdata,c5_legacy_wdata}),
.s_wstrb(ovreg_axil_wstrb),.m_wstrb({c5_mail_wstrb,c5_legacy_wstrb}),
.s_wvalid(ovreg_axil_wvalid),.m_wvalid({c5_mail_wvalid,c5_legacy_wvalid}),
.s_wready(ovreg_axil_wready),.m_wready({c5_mail_wready,c5_legacy_wready}),
.s_bresp(ovreg_axil_bresp),.m_bresp({c5_mail_bresp,c5_legacy_bresp}),
.s_bvalid(ovreg_axil_bvalid),.m_bvalid({c5_mail_bvalid,c5_legacy_bvalid}),
.s_bready(ovreg_axil_bready),.m_bready({c5_mail_bready,c5_legacy_bready}),
.s_araddr(ovreg_axil_araddr),.m_araddr({c5_mail_araddr,c5_legacy_araddr}),
.s_arvalid(ovreg_axil_arvalid),.m_arvalid({c5_mail_arvalid,c5_legacy_arvalid}),
.s_arready(ovreg_axil_arready),.m_arready({c5_mail_arready,c5_legacy_arready}),
.s_rdata(ovreg_axil_rdata),.m_rdata({c5_mail_rdata,c5_legacy_rdata}),
.s_rresp(ovreg_axil_rresp),.m_rresp({c5_mail_rresp,c5_legacy_rresp}),
.s_rvalid(ovreg_axil_rvalid),.m_rvalid({c5_mail_rvalid,c5_legacy_rvalid}),
.s_rready(ovreg_axil_rready),.m_rready({c5_mail_rready,c5_legacy_rready}));
ovreg_axil_decode ovreg_axil_decode_u (
    .clk        (axi_clk),
    .rst        (axi_rst),
    .s_awvalid  (c5_legacy_awvalid),
    .s_awready  (c5_legacy_awready),
    .s_awaddr   (c5_legacy_awaddr),
    .s_wvalid   (c5_legacy_wvalid),
    .s_wready   (c5_legacy_wready),
    .s_wdata    (c5_legacy_wdata),
    .s_wstrb    (c5_legacy_wstrb),
    .s_bvalid   (c5_legacy_bvalid),
    .s_bready   (c5_legacy_bready),
    .s_bresp    (c5_legacy_bresp),
    .s_arvalid  (c5_legacy_arvalid),
    .s_arready  (c5_legacy_arready),
    .s_araddr   (c5_legacy_araddr),
    .s_rvalid   (c5_legacy_rvalid),
    .s_rready   (c5_legacy_rready),
    .s_rdata    (c5_legacy_rdata),
    .s_rresp    (c5_legacy_rresp),
    .m0_awvalid (cam_axil_awvalid),
    .m0_awready (cam_axil_awready),
    .m0_awaddr  (cam_axil_awaddr),
    .m0_wvalid  (cam_axil_wvalid),
    .m0_wready  (cam_axil_wready),
    .m0_wdata   (cam_axil_wdata),
    .m0_wstrb   (cam_axil_wstrb),
    .m0_bvalid  (cam_axil_bvalid),
    .m0_bready  (cam_axil_bready),
    .m0_bresp   (cam_axil_bresp),
    .m0_arvalid (cam_axil_arvalid),
    .m0_arready (cam_axil_arready),
    .m0_araddr  (cam_axil_araddr),
    .m0_rvalid  (cam_axil_rvalid),
    .m0_rready  (cam_axil_rready),
    .m0_rdata   (cam_axil_rdata),
    .m0_rresp   (cam_axil_rresp),
    .m1_awvalid (prep_axil_awvalid),
    .m1_awready (prep_axil_awready),
    .m1_awaddr  (prep_axil_awaddr),
    .m1_wvalid  (prep_axil_wvalid),
    .m1_wready  (prep_axil_wready),
    .m1_wdata   (prep_axil_wdata),
    .m1_wstrb   (prep_axil_wstrb),
    .m1_bvalid  (prep_axil_bvalid),
    .m1_bready  (prep_axil_bready),
    .m1_bresp   (prep_axil_bresp),
    .m1_arvalid (prep_axil_arvalid),
    .m1_arready (prep_axil_arready),
    .m1_araddr  (prep_axil_araddr),
    .m1_rvalid  (prep_axil_rvalid),
    .m1_rready  (prep_axil_rready),
    .m1_rdata   (prep_axil_rdata),
    .m1_rresp   (prep_axil_rresp),

    .m2_awvalid (cam2_axil_awvalid),
    .m2_awready (cam2_axil_awready),
    .m2_awaddr  (cam2_axil_awaddr),
    .m2_wvalid  (cam2_axil_wvalid),
    .m2_wready  (cam2_axil_wready),
    .m2_wdata   (cam2_axil_wdata),
    .m2_wstrb   (cam2_axil_wstrb),
    .m2_bvalid  (cam2_axil_bvalid),
    .m2_bready  (cam2_axil_bready),
    .m2_bresp   (cam2_axil_bresp),
    .m2_arvalid (cam2_axil_arvalid),
    .m2_arready (cam2_axil_arready),
    .m2_araddr  (cam2_axil_araddr),
    .m2_rvalid  (cam2_axil_rvalid),
    .m2_rready  (cam2_axil_rready),
    .m2_rdata   (cam2_axil_rdata),
    .m2_rresp   (cam2_axil_rresp),

    .m3_awvalid (cam3_axil_awvalid),
    .m3_awready (cam3_axil_awready),
    .m3_awaddr  (cam3_axil_awaddr),
    .m3_wvalid  (cam3_axil_wvalid),
    .m3_wready  (cam3_axil_wready),
    .m3_wdata   (cam3_axil_wdata),
    .m3_wstrb   (cam3_axil_wstrb),
    .m3_bvalid  (cam3_axil_bvalid),
    .m3_bready  (cam3_axil_bready),
    .m3_bresp   (cam3_axil_bresp),
    .m3_arvalid (cam3_axil_arvalid),
    .m3_arready (cam3_axil_arready),
    .m3_araddr  (cam3_axil_araddr),
    .m3_rvalid  (cam3_axil_rvalid),
    .m3_rready  (cam3_axil_rready),
    .m3_rdata   (cam3_axil_rdata),
    .m3_rresp   (cam3_axil_rresp),
    .m4_awvalid (cam4_axil_awvalid),
    .m4_awready (cam4_axil_awready),
    .m4_awaddr  (cam4_axil_awaddr),
    .m4_wvalid  (cam4_axil_wvalid),
    .m4_wready  (cam4_axil_wready),
    .m4_wdata   (cam4_axil_wdata),
    .m4_wstrb   (cam4_axil_wstrb),
    .m4_bvalid  (cam4_axil_bvalid),
    .m4_bready  (cam4_axil_bready),
    .m4_bresp   (cam4_axil_bresp),
    .m4_arvalid (cam4_axil_arvalid),
    .m4_arready (cam4_axil_arready),
    .m4_araddr  (cam4_axil_araddr),
    .m4_rvalid  (cam4_axil_rvalid),
    .m4_rready  (cam4_axil_rready),
    .m4_rdata   (cam4_axil_rdata),
    .m4_rresp   (cam4_axil_rresp)
);

// --- prep datapath wiring ---
wire                        prep_bypass_w;
wire [1:0]                  prep_mode_w;
wire [11:0]                 prep_img_width_w;
wire [7:0]                  prep_thr_sat_w, prep_thr_hue_w, prep_thr_val_w, prep_thr_low_w;
wire [10:0]                 prep_thr_edge_w;
wire [7:0]                  prep_lane_roi_top_w, prep_lane_roi_bot_w, prep_lane_row_thr_w, prep_lane_dash_thr_w;
wire cam_dma_abort, cam_dma_abort_req;
wire cam2_dma_abort, cam2_dma_abort_req;
(* syn_maxfan = 4 *) wire cam3_dma_abort;
wire cam3_dma_abort_req;
wire cam4_dma_abort, cam4_dma_abort_req;
wire [7:0]                  prep_frame_cnt;
wire [15:0]                 inj_addr_w, inj_len_w, inj_fid_w;
wire                        inj_start_w, inj_done_clr_w;
wire [3:0]                  btn_sticky_w, btn_sticky_clr_w, led_ctrl_w;
wire [31:0]                 ts0_w, ts1_w, ts2_w, ts3_w;
// [DIAG 2026-10-22] C6 line-rate counters (axi_clk) -> prep_regs 0x2000_0154/0x158
wire [31:0]                 diag_c6_lines_w /* synthesis syn_keep=1 */;
wire [31:0]                 diag_c6_line_cycles_w /* synthesis syn_keep=1 */;

wire lane_enable;
wire [7:0] lane_white_min, lane_white_span, lane_min_run;
wire [3:0] lane_line_width;
wire [15:0] cam1_lane_left_count, cam1_lane_right_count;
wire [31:0] cam1_lane_frame_sequence;
wire cam1_lane_left_valid, cam1_lane_right_valid;
wire [15:0] hdmi_lane_left_count, hdmi_lane_right_count;
wire [31:0] hdmi_lane_frame_sequence;
wire hdmi_lane_left_valid, hdmi_lane_right_valid;

// CAM1 and HDMI C5/C6 coexist in one bitstream. They share one iterative
// divider; requests are channel-locked until the matching result returns.
wire [2:0] lane_div_req_valid, lane_div_req_ready, lane_div_rsp_valid;
wire [191:0] lane_div_req_dividend, lane_div_req_divisor;
wire [127:0] lane_div_rsp_data;
lane_divider_shared_iterative lane_divider_shared_u (
    .clk(axi_clk), .rst_n(!axi_rst),
    .req_valid(lane_div_req_valid), .req_ready(lane_div_req_ready),
    .req_dividend(lane_div_req_dividend), .req_divisor(lane_div_req_divisor),
    .rsp_valid(lane_div_rsp_valid), .rsp_data(lane_div_rsp_data)
);


// --- PREP/INJ registers (doc +0x100~0x17C). Register stage only: datapath
//     inputs tied to defaults until the preprocess pipeline is integrated.
wire [319:0] cam1_motion_record, cam2_motion_record, cam3_motion_record, cam4_motion_record;
wire [191:0] cam1_motion_meta, cam2_motion_meta, cam3_motion_meta, cam4_motion_meta;
wire [1919:0] motion_records = {640'b0, cam4_motion_record, cam3_motion_record,
    cam2_motion_record, cam1_motion_record};
wire [191:0] cam5_motion_meta = {32'b0,30'b0,six_published[8 +: 2],32'b0,
    32'd614400,32'h028001e0,six_sequence[128 +: 32]};
wire [191:0] cam6_motion_meta = {32'b0,30'b0,six_published[10 +: 2],32'b0,
    32'd614400,32'h028001e0,six_sequence[160 +: 32]};
wire [1151:0] motion_frame_metadata = {cam6_motion_meta,cam5_motion_meta,
    cam4_motion_meta,cam3_motion_meta,cam2_motion_meta,cam1_motion_meta};
prep_regs #(.TICK_DIV(50), .SFP_DIAG_EN(1)) prep_regs_u (
    .motion_records(motion_records), .motion_frame_metadata(motion_frame_metadata),
    .sfp_diag_status(sfp_diag_status),
    .sfp_diag_fault5(cam5_diag_fault),
    .sfp_diag_fault6(cam6_diag_fault),
    .sfp_diag_pixels5(cam5_diag_pixels),
    .sfp_diag_pixels6(cam6_diag_pixels),
    .sfp_diag_states({cam6_diag_state[15:0], cam5_diag_state[15:0]}),
    .sfp_diag_rejects({cam6_diag_rejects[15:0], cam5_diag_rejects[15:0]}),
    // [DIAG 2026-10-22] +0x154/0x158 (C6 counters) and +0x1D0..0x1E4 (sensor).
    // The C5/C6 sensor readback values are
    // produced by reg_config_c5 on the 50K sender and never cross the SFP link,
    // so in this 100H bitstream those six slots read a constant 0. The two C6
    // line-rate counters are real measurements taken here in the receiver.
    .diag_c5_hts(32'd0), .diag_c5_vts(32'd0), .diag_c5_pll(32'd0),
    .diag_c6_hts(32'd0), .diag_c6_vts(32'd0), .diag_c6_pll(32'd0),
    .diag_c6_lines(diag_c6_lines_w), .diag_c6_line_cycles(diag_c6_line_cycles_w),
    .clk              (axi_clk),
    .rst_n            (~axi_rst),
    .s_axi_awvalid    (prep_axil_awvalid),
    .s_axi_awready    (),
    .s_axi_awaddr     (prep_axil_awaddr),
    .s_axi_wvalid     (prep_axil_wvalid),
    .s_axi_wready     (),
    .s_axi_wdata      (prep_axil_wdata),
    .s_axi_wstrb      (prep_axil_wstrb),
    .s_axi_bvalid     (),
    .s_axi_bready     (prep_axil_bready),
    .s_axi_bresp      (prep_axil_bresp),
    .s_axi_arvalid    (prep_axil_arvalid),
    .s_axi_arready    (),
    .s_axi_araddr     (prep_axil_araddr),
    .s_axi_rvalid     (),
    .s_axi_rready     (prep_axil_rready),
    .s_axi_rdata      (),
    .s_axi_rresp      (prep_axil_rresp),
    .prep_bypass      (prep_bypass_w),
    .prep_mode        (prep_mode_w),
    .prep_img_width   (prep_img_width_w),
    .prep_thr_sat     (prep_thr_sat_w),
    .prep_thr_hue     (prep_thr_hue_w),
    .prep_thr_val     (prep_thr_val_w),
    .prep_thr_low     (prep_thr_low_w),
    .prep_thr_edge    (prep_thr_edge_w),
    .prep_lane_roi_top(prep_lane_roi_top_w),
    .prep_lane_roi_bot(prep_lane_roi_bot_w),
    .prep_lane_row_thr(prep_lane_row_thr_w),
    .prep_lane_dash_thr(prep_lane_dash_thr_w),
    .lane_roi_awvalid(prep_axil_awvalid), .lane_roi_awready(prep_axil_awready),
    .lane_roi_awaddr(prep_axil_awaddr), .lane_roi_wvalid(prep_axil_wvalid),
    .lane_roi_wready(prep_axil_wready), .lane_roi_wdata(prep_axil_wdata),
    .lane_roi_wstrb(prep_axil_wstrb), .lane_roi_bvalid(prep_axil_bvalid),
    .lane_roi_bready(prep_axil_bready), .lane_roi_arvalid(prep_axil_arvalid),
    .lane_roi_arready(prep_axil_arready), .lane_roi_araddr(prep_axil_araddr),
    .lane_roi_rvalid(prep_axil_rvalid), .lane_roi_rready(prep_axil_rready),
    .lane_roi_rdata(prep_axil_rdata),
    .lane_enable(lane_enable), .lane_white_min(lane_white_min),
    .lane_white_span(lane_white_span), .lane_min_run(lane_min_run),
    .lane_line_width(lane_line_width),
    .cam1_left_count(cam1_lane_left_count), .cam1_right_count(cam1_lane_right_count),
    .cam1_frame_sequence(cam1_lane_frame_sequence),
    .cam1_left_valid(cam1_lane_left_valid), .cam1_right_valid(cam1_lane_right_valid),
    .hdmi_left_count(hdmi_lane_left_count), .hdmi_right_count(hdmi_lane_right_count),
    .hdmi_frame_sequence(hdmi_lane_frame_sequence),
    .hdmi_left_valid(hdmi_lane_left_valid), .hdmi_right_valid(hdmi_lane_right_valid),
    .inj_addr         (),
    .inj_len          (),
    .inj_frame_id     (),
    .inj_start        (),
    .inj_done_clr     (),
    .inj_busy         (1'b0),
    .inj_done         (1'b0),
    .inj_done_fid     (16'd0),
    .pipe_frame_sync  (prep_out_frame_start),
    .pipe_fifo_afull  (1'b0),
    .npu_busy         (1'b0),
    .out_frame_cnt    (prep_frame_cnt),
    .btn_toggle_evt   (4'd0),
    // [SFP-STATUS 2026-09-30] +0x144 = SFP ��·״̬: bit0=pll_lock1 bit1=txlane_done2 bit2=rxlane_done2 bit3=pcs_synced2
    .btn_level_sync   (sfp_status_bits),
    .btn_sticky       (),
    .btn_sticky_clr   (),
    .led_ctrl         (),
    .lane_left_type   (lane_left_type_w),
    .lane_right_type  (lane_right_type_w),
    .lane_left_valid  (lane_left_valid_w),
    .lane_right_valid (lane_right_valid_w),
    .lane_frame_upd   (lane_frame_upd_w),
    .ts_cap_pulse     (1'b0),
    .ts_prep_pulse    (1'b0),
    .ts_npu_pulse     (1'b0),
    .ts_dma_pulse     (1'b0),
    .ts_value0        (),
    .ts_value1        (),
    .ts_value2        (),
    .ts_value3        ()
);

reg [15:0] camera_startup_count = 16'd0;
reg camera_ctrl_rst_n = 1'b0;
always @(posedge clk_50m) begin
    if (!camera_ctrl_rst_n) begin
        if (&camera_startup_count)
            camera_ctrl_rst_n <= 1'b1;
        else
            camera_startup_count <= camera_startup_count + 1'b1;
    end
end

`ifdef USE_OV5640
ov5640_top #(
    .CAM1_RUNTIME (1'b1),
    .IODELAY_STEP  (8'd140),
    .MEDIAN_EN     (1'b0)        , // [MEDIAN] disabled; cam1 uses FIR below
    .MEDIAN_RSVD   (3'd0),
    .KF_EN         (1'b0)         , // [VKFS] disabled; cam1 uses FIR
    .KF_RD_EN      (1'b0)         // [VKFS] no previous-frame DDR read
) ov5640_top(
    .lane_enable(lane_enable), .lane_white_min(lane_white_min),
    .lane_white_span(lane_white_span), .lane_min_run(lane_min_run),
    .lane_line_width(lane_line_width),
    .lane_left_count(cam1_lane_left_count), .lane_right_count(cam1_lane_right_count),
    .lane_frame_sequence(cam1_lane_frame_sequence),
    .lane_left_valid(cam1_lane_left_valid), .lane_right_valid(cam1_lane_right_valid),
    .lane_div_req_valid(lane_div_req_valid[0]), .lane_div_req_ready(lane_div_req_ready[0]),
    .lane_div_req_dividend(lane_div_req_dividend[63:0]),
    .lane_div_req_divisor(lane_div_req_divisor[63:0]),
    .lane_div_rsp_valid(lane_div_rsp_valid[0]), .lane_div_rsp_data(lane_div_rsp_data),
    .lease_prev_base(six_prev[0 +: 32]),.lease_bank0(six_bank0[0 +: 32]),
    .lease_bank1(six_bank1[0 +: 32]),.lease_sequence(six_sequence[0 +: 32]),
    .motion_record(cam1_motion_record), .motion_frame_metadata(cam1_motion_meta),
    .lease_published(six_published[0 +: 2]),.lease_writer_idle(six_writer_idle[0]),
    .lease_pending(six_pending[0]),.lease_flush(six_flush[0]),
    .capture_hold(six_hold[0] || !runtime_allowed_mask[0] || cam_native_park),
    .runtime_allowed_mask(runtime_allowed_mask), .runtime_idle_raw(runtime_idle_raw),
    .runtime_dma_idle(six_dma_idle[0]),

    .clk_50m       (clk_50m)        ,
    .clk_50m_rst_n (camera_ctrl_rst_n),
    .dbg_locked    (locked)         ,
    .dbg_btn_rst_n (button_rst_n)   ,
    .dbg_axi_awvalid(ov5640_axi_awvalid),
    .dbg_axi_awready(ov5640_axi_awready),
    .dbg_axi_wvalid (ov5640_axi_wvalid ),
    .dbg_axi_wready (ov5640_axi_wready ),
    .dbg_axi_bvalid (ov5640_axi_bvalid ),
    .dbg_axi_bready (ov5640_axi_bready ),
        
    .cam_pclk (cmos1_pclk )             ,  
    .cam_vsync(cmos1_vsync)             ,  
    .cam_href (cmos1_href )             ,  
    .cam_data (cmos1_data )             ,  
    .cam_rst_n(cmos1_rst_n)             ,  
    // .cam_pwdn (cmos1_pwdn )             ,  
    .cam_scl  (cmos1_scl  )             ,  
    .cam_sda  (cmos1_sda  )             ,  


    
    .s_axi_awvalid(cam_axil_awvalid)        ,
    .s_axi_awready(cam_axil_awready)        ,
    .s_axi_awaddr (cam_axil_awaddr )        ,

    .s_axi_wvalid (cam_axil_wvalid)         ,
    .s_axi_wready (cam_axil_wready)         ,
    .s_axi_wdata  (cam_axil_wdata )         ,
    .s_axi_wstrb  (cam_axil_wstrb )         ,

    .s_axi_bvalid (cam_axil_bvalid)         ,
    .s_axi_bready (cam_axil_bready)         ,
    .s_axi_bresp  (cam_axil_bresp )         ,

    .s_axi_arvalid(cam_axil_arvalid)        ,
    .s_axi_arready(cam_axil_arready)        ,
    .s_axi_araddr (cam_axil_araddr )        ,

    .s_axi_rvalid (cam_axil_rvalid )        ,
    .s_axi_rready (cam_axil_rready )        ,
    .s_axi_rdata  (cam_axil_rdata  )        ,
    .s_axi_rresp  (cam_axil_rresp  )        ,



    //AXI_stream
    .video_clk(axi_clk)      ,
    .video_rst(axi_rst)      ,
    .cam_cmd_addr (cam_cmd_addr )  ,
    .cam_cmd_len  (cam_cmd_len  )  ,
    .cam_cmd_valid(cam_cmd_valid)  ,
    .cam_cmd_ready(cam_cmd_ready)  ,

    .cam_s_data      (cam_tap_data      ),
    .cam_s_data_valid(cam_tap_data_valid),
    .cam_s_data_last (cam_tap_data_last ),
    .cam_s_data_ready(cam_tap_data_ready),

    //DMA?
    .cam_dma_abort(cam_dma_abort),
    .cam_s_data_available(cam_s_data_available),
    .cam_dma_abort_req(cam_dma_abort_req),
    .cam_dma_done(cam_dma_done),
    .xdma_clk (pcie_clk) ,
    .xdma_irq (cam_irq ) ,

    // [VKFS 2026-09-25] previous-frame read master -> crossbar S05 (npu_s3_*)
    .kf_arvalid (npu_s3_axi_arvalid),
    .kf_arready (npu_s3_axi_arready),
    .kf_araddr  (npu_s3_axi_araddr ),
    .kf_arlen   (npu_s3_axi_arlen  ),
    .kf_arsize  (npu_s3_axi_arsize ),
    .kf_arburst (npu_s3_axi_arburst),
    .kf_arlock  (npu_s3_axi_arlock ),
    .kf_arcache (npu_s3_axi_arcache),
    .kf_arprot  (npu_s3_axi_arprot ),
    .kf_arid    (npu_s3_axi_arid   ),
    .kf_rready  (npu_s3_axi_rready ),
    .kf_rid     (npu_s3_axi_rid    ),
    .kf_rdata   (npu_s3_axi_rdata  ),
    .kf_rresp   (npu_s3_axi_rresp  ),
    .kf_rlast   (npu_s3_axi_rlast  ),
    .kf_rvalid  (npu_s3_axi_rvalid )

);

// [LEDGER 2026-09-19] DMA transaction-done pulses (single beat ledger)
wire cam_dma_done;
// [SFP-STATUS 2026-09-30] SFP link status -> prep_regs +0x144 (btn_level_sync slot)
wire sfp_st_pll_lock, sfp_st_txlane_done, sfp_st_rxlane_done, sfp_st_pcs_synced;
wire sfp_st_sigdet;
wire [31:0] cam5_diag_fault, cam6_diag_fault;
wire [31:0] cam5_diag_pixels, cam6_diag_pixels;
wire [31:0] cam5_diag_state, cam6_diag_state;
wire [31:0] cam5_diag_rejects, cam6_diag_rejects;
reg [1:0] sfp_sigdet_sync = 0;
wire sfp_enable_diag;
wire sfp_rx_en;
// Kept diagnostic branch only. Raw sfp_rx_en safety/ingress consumers unchanged.
c5_sfp_status_sync c5_sfp_enable_diag_sync(.clk(axi_clk),
 .async_enable(sfp_rx_en),.enable_sync(sfp_enable_diag));
wire [31:0] sfp_diag_status = {26'd0, sfp_enable_diag, sfp_sigdet_sync[1], sfp_status_bits};
always @(posedge axi_clk) begin
    sfp_sigdet_sync <= {sfp_sigdet_sync[0], sfp_st_sigdet};
    // Enable diagnostic now uses isolated preserved two-flop helper.
end
reg [3:0] sfp_status_bits = 4'b0;
reg [1:0] st_pll1_q, st_txd2_q, st_rxd2_q, st_pcs_q;
always @(posedge axi_clk) begin
    st_pll1_q <= {st_pll1_q[0], sfp_st_pll_lock};
    st_txd2_q <= {st_txd2_q[0], sfp_st_txlane_done};
    st_rxd2_q <= {st_rxd2_q[0], sfp_st_rxlane_done};
    st_pcs_q  <= {st_pcs_q[0],  sfp_st_pcs_synced};
    sfp_status_bits <= {st_pcs_q[1], st_rxd2_q[1], st_txd2_q[1], st_pll1_q[1]};
end
wire cam2_dma_done;
wire cam3_dma_done;
wire cam4_dma_done;

// ---- [SFP 2026-09-29] fiber RX link / cam5 / cam6 signals ----
wire        sfp_rx_clk, sfp_rx_rst_n;
wire t4_awready, t4_wready; wire [3:0] t4_bid; wire [1:0] t4_bresp; wire t4_bvalid;
wire t5_awready, t5_wready; wire [3:0] t5_bid; wire [1:0] t5_bresp; wire t5_bvalid;
wire [31:0] sfp_rxd;
wire [3:0]  sfp_rxk;
wire        sfp_vs, sfp_hs, sfp_de;
wire [15:0] sfp_pix;
wire        cam5_vs, cam5_hs, cam5_de;
wire [15:0] cam5_pix;
wire        cam6_vs, cam6_hs, cam6_de;
wire [15:0] cam6_pix;
wire [31:0] cam5_cmd_addr, cam5_cmd_len;
wire        cam5_cmd_valid, cam5_cmd_ready;
wire [AXI_DATA_LEN-1:0] cam5_s_data;
wire        cam5_s_data_valid, cam5_s_data_last, cam5_s_data_ready;
wire [15:0] cam5_s_data_available;
wire [AXI_ID_LEN-1:0]   cam5_axi_awid;
wire [31:0]             cam5_axi_awaddr;
wire [3:0]              cam5_axi_awlen;
wire [2:0]              cam5_axi_awsize;
wire [1:0]              cam5_axi_awburst;
wire                    cam5_axi_awlock;
wire [3:0]              cam5_axi_awcache;
wire [2:0]              cam5_axi_awprot;
wire                    cam5_axi_awvalid, cam5_axi_awready;
wire [AXI_DATA_LEN-1:0] cam5_axi_wdata;
wire [AXI_STRB_LEN-1:0] cam5_axi_wstrb;
wire                    cam5_axi_wlast, cam5_axi_wvalid, cam5_axi_wready;
wire [AXI_ID_LEN-1:0]   cam5_axi_bid;
wire [1:0]              cam5_axi_bresp;
wire                    cam5_axi_bvalid, cam5_axi_bready;
wire [31:0] cam6_cmd_addr, cam6_cmd_len;
wire        cam6_cmd_valid, cam6_cmd_ready;
wire [AXI_DATA_LEN-1:0] cam6_s_data;
wire        cam6_s_data_valid, cam6_s_data_last, cam6_s_data_ready;
wire [15:0] cam6_s_data_available;
wire [AXI_ID_LEN-1:0]   cam6_axi_awid;
wire [31:0]             cam6_axi_awaddr;
wire [3:0]              cam6_axi_awlen;
wire [2:0]              cam6_axi_awsize;
wire [1:0]              cam6_axi_awburst;
wire                    cam6_axi_awlock;
wire [3:0]              cam6_axi_awcache;
wire [2:0]              cam6_axi_awprot;
wire                    cam6_axi_awvalid, cam6_axi_awready;
wire [AXI_DATA_LEN-1:0] cam6_axi_wdata;
wire [AXI_STRB_LEN-1:0] cam6_axi_wstrb;
wire                    cam6_axi_wlast, cam6_axi_wvalid, cam6_axi_wready;
wire [AXI_ID_LEN-1:0]   cam6_axi_bid;
wire [1:0]              cam6_axi_bresp;
wire                    cam6_axi_bvalid, cam6_axi_bready;

// --- CAM3 (FMC 3rd OV5640, BASE_ADDR 0x2000_0400, 640x480, raw passthrough) ---
wire                        cam3_axil_awvalid_unused;
wire [AXI_DATA_LEN-1 : 0]   cam3_s_data      ;
wire                        cam3_s_data_valid;
wire                        cam3_s_data_last ;
wire                        cam3_s_data_ready;
wire [31:0]                 cam3_cmd_addr    ;
wire [31:0]                 cam3_cmd_len     ;
wire                        cam3_cmd_valid   ;
wire                        cam3_cmd_ready   ;
wire [3:0]                  cam3_axi_awid    ;
wire [31:0]                 cam3_axi_awaddr  ;
wire [7:0]                  cam3_axi_awlen   ;
wire [2:0]                  cam3_axi_awsize  ;
wire [1:0]                  cam3_axi_awburst ;
wire [3:0]                  cam3_axi_awcache ;
wire [2:0]                  cam3_axi_awprot  ;
wire                        cam3_axi_awvalid ;
wire                        cam3_axi_awready ;
wire [127:0]                cam3_axi_wdata   ;
wire [15:0]                 cam3_axi_wstrb   ;
wire                        cam3_axi_awlock  ;
wire                        cam3_axi_wlast   ;
wire                        cam3_axi_wvalid  ;
wire                        cam3_axi_wready  ;
wire [3:0]                  cam3_axi_bid     ;
wire [1:0]                  cam3_axi_bresp   ;
wire                        cam3_axi_bvalid  ;
wire                        cam3_axi_bready  ;
wire [31:0]                 cam3_dbg_dummy;

// ---- CAM2 (FMC 2nd OV5640, BASE_ADDR 0x2000_0200, 640x480) ----
ov5640_top #(
    .BASE_ADDR       (32'h2000_0200),
    .CAM_ADDR_1_DEF  (32'h00C0_0000),
    .CAM_ADDR_2_DEF  (32'h00E0_0000),
    .CAM_EN_DEF      (1'b1),   // [DUALCAM] keep both camera engines enabled
    .H_CMOS_DISP     (11'd640),
    .V_CMOS_DISP     (11'd480),
    .TOTAL_H_PIXEL   (12'd1896),
    .TOTAL_V_PIXEL   (12'd984)
) cam2_ov5640_top (
    .lane_enable(1'b0), .lane_white_min(8'd0), .lane_white_span(8'd0),
    .lane_min_run(8'd0), .lane_line_width(4'd0),
    .lane_left_count(), .lane_right_count(), .lane_frame_sequence(),
    .lane_left_valid(), .lane_right_valid(),
    .lease_prev_base(six_prev[32 +: 32]),.lease_bank0(six_bank0[32 +: 32]),
    .lease_bank1(six_bank1[32 +: 32]),.lease_sequence(six_sequence[32 +: 32]),
    .motion_record(cam2_motion_record), .motion_frame_metadata(cam2_motion_meta),
    .lease_published(six_published[2 +: 2]),.lease_writer_idle(six_writer_idle[1]),
    .lease_pending(six_pending[1]),.lease_flush(six_flush[1]),
    .capture_hold(six_hold[1] || !runtime_allowed_mask[1] || cam_native_park),

    .clk_50m       (clk_50m),
    .clk_50m_rst_n (camera_ctrl_rst_n),
    .dbg_locked    (locked),
    .dbg_btn_rst_n (button_rst_n),
    .dbg_axi_awvalid(cam2_axi_awvalid),
    .dbg_axi_awready(cam2_axi_awready),
    .dbg_axi_wvalid (cam2_axi_wvalid ),
    .dbg_axi_wready (cam2_axi_wready ),
    .dbg_axi_bvalid (cam2_axi_bvalid ),
    .dbg_axi_bready (cam2_axi_bready ),

    .cam_pclk (cmos2_pclk ),
    .cam_vsync(cmos2_vsync),
    .cam_href (cmos2_href ),
    .cam_data (cmos2_data ),
    .cam_rst_n(cmos2_rst_n),
    .cam_scl  (cmos2_scl  ),
    .cam_sda  (cmos2_sda  ),

    .s_axi_awvalid(cam2_axil_awvalid),
    .s_axi_awready(cam2_axil_awready),
    .s_axi_awaddr (cam2_axil_awaddr ),
    .s_axi_wvalid (cam2_axil_wvalid ),
    .s_axi_wready (cam2_axil_wready ),
    .s_axi_wdata  (cam2_axil_wdata  ),
    .s_axi_wstrb  (cam2_axil_wstrb  ),
    .s_axi_bvalid (cam2_axil_bvalid ),
    .s_axi_bready (cam2_axil_bready ),
    .s_axi_bresp  (cam2_axil_bresp  ),
    .s_axi_arvalid(cam2_axil_arvalid),
    .s_axi_arready(cam2_axil_arready),
    .s_axi_araddr (cam2_axil_araddr ),
    .s_axi_rvalid (cam2_axil_rvalid ),
    .s_axi_rready (cam2_axil_rready ),
    .s_axi_rdata  (cam2_axil_rdata  ),
    .s_axi_rresp  (cam2_axil_rresp  ),

    .video_clk(axi_clk),
    .video_rst(axi_rst),
    .cam_cmd_addr (cam2_cmd_addr ),
    .cam_cmd_len  (cam2_cmd_len  ),
    .cam_cmd_valid(cam2_cmd_valid),
    .cam_cmd_ready(cam2_cmd_ready),

    .cam_s_data      (cam2_s_data      ),
    .cam_s_data_valid(cam2_s_data_valid),
    .cam_s_data_last (cam2_s_data_last ),
    .cam_s_data_ready(cam2_s_data_ready),

    .cam_dma_abort(cam2_dma_abort),
    .cam_s_data_available(cam2_s_data_available),
    .cam_dma_abort_req(cam2_dma_abort_req),
    .cam_dma_done(cam2_dma_done),
    .xdma_clk (pcie_clk),
    .xdma_irq (          )
);

// ---- CAM3 (FMC 3rd OV5640, BASE_ADDR 0x2000_0400, 640x480, raw passthrough:
//      VSYNC qualified for 64 PCLK; pixel-path settings unchanged) ----
ov5640_top #(
    .RUNTIME_ENABLE(1'b1), .RUNTIME_BASE(32'h20000900),
    .RUNTIME_SIGNATURE(32'h43334d32),
    .I2C_FREQ(100_000), // SCCB read-rise margin; C1/C2 retain 250 kHz setting
    .CAM_DATA_LEN(9600),
    .DOWNSAMPLE_2X2(1'b1),
    .BASE_ADDR       (32'h2000_0400),
    .SENSOR_PLL_MULT (8'h36), // cam3: initialize PLL for 54 MHz PCLK
    .VSYNC_STABLE_CYCLES(64), // cam3 only: 1.185 us at 54 MHz
    .CAM_ADDR_1_DEF  (32'h0100_0000),
    .CAM_ADDR_2_DEF  (32'h0120_0000),
    .CAM_EN_DEF      (1'b1),
    .H_CMOS_DISP     (11'd640),
    .V_CMOS_DISP     (11'd480),
    .TOTAL_H_PIXEL   (12'd1896),
    .TOTAL_V_PIXEL   (12'd984)
) cam3_ov5640_top (
    .lane_enable(1'b0), .lane_white_min(8'd0), .lane_white_span(8'd0),
    .lane_min_run(8'd0), .lane_line_width(4'd0),
    .lane_left_count(), .lane_right_count(), .lane_frame_sequence(),
    .lane_left_valid(), .lane_right_valid(),
    .lease_prev_base(six_prev[64 +: 32]),.lease_bank0(six_bank0[64 +: 32]),
    .lease_bank1(six_bank1[64 +: 32]),.lease_sequence(six_sequence[64 +: 32]),
    .motion_record(cam3_motion_record), .motion_frame_metadata(cam3_motion_meta),
    .lease_published(six_published[4 +: 2]),.lease_writer_idle(six_writer_idle[2]),
    .lease_pending(six_pending[2]),.lease_flush(six_flush[2]),
    .capture_hold(six_hold[2] || !runtime_allowed_mask[2] || cam_native_park),
    .runtime_dma_idle(six_dma_idle[2]),
    .runtime_idle_raw(runtime_idle_raw),

    .clk_50m       (clk_50m),
    .clk_50m_rst_n (camera_ctrl_rst_n),
    .dbg_locked    (locked),
    .dbg_btn_rst_n (button_rst_n),
    .dbg_axi_awvalid(cam3_axi_awvalid),
    .dbg_axi_awready(cam3_axi_awready),
    .dbg_axi_wvalid (cam3_axi_wvalid ),
    .dbg_axi_wready (cam3_axi_wready ),
    .dbg_axi_bvalid (cam3_axi_bvalid ),
    .dbg_axi_bready (cam3_axi_bready ),

    .cam_pclk (cmos3_pclk ),
    .cam_vsync(cmos3_vsync),
    .cam_href (cmos3_href ),
    .cam_data (cmos3_data ),
    .cam_rst_n(cmos3_rst_n),
    .cam_scl  (cmos3_scl  ),
    .cam_sda  (cmos3_sda  ),

    .s_axi_awvalid(cam3_axil_awvalid),
    .s_axi_awready(cam3_axil_awready),
    .s_axi_awaddr (cam3_axil_awaddr ),
    .s_axi_wvalid (cam3_axil_wvalid ),
    .s_axi_wready (cam3_axil_wready ),
    .s_axi_wdata  (cam3_axil_wdata  ),
    .s_axi_wstrb  (cam3_axil_wstrb  ),
    .s_axi_bvalid (cam3_axil_bvalid ),
    .s_axi_bready (cam3_axil_bready ),
    .s_axi_bresp  (cam3_axil_bresp  ),
    .s_axi_arvalid(cam3_axil_arvalid),
    .s_axi_arready(cam3_axil_arready),
    .s_axi_araddr (cam3_axil_araddr ),
    .s_axi_rvalid (cam3_axil_rvalid ),
    .s_axi_rready (cam3_axil_rready ),
    .s_axi_rdata  (cam3_axil_rdata  ),
    .s_axi_rresp  (cam3_axil_rresp  ),

    .video_clk(axi_clk),
    .video_rst(axi_rst),
    .cam_cmd_addr (cam3_cmd_addr ),
    .cam_cmd_len  (cam3_cmd_len  ),
    .cam_cmd_valid(cam3_cmd_valid),
    .cam_cmd_ready(cam3_cmd_ready),

    .cam_s_data      (cam3_s_data      ),
    .cam_s_data_valid(cam3_s_data_valid),
    .cam_s_data_last (cam3_s_data_last ),
    .cam_s_data_ready(cam3_s_data_ready),

    .cam_dma_abort(cam3_dma_abort),
    .cam_s_data_available(cam3_s_data_available),
    .cam_dma_abort_req(cam3_dma_abort_req),
    .cam_dma_done(cam3_dma_done),
    .xdma_clk (pcie_clk),
    .xdma_irq (          )
);

// --- CAM4 (FMC 4th OV5640, BASE_ADDR 0x2000_0600, 640x480, raw passthrough:
//      same 48 MHz init PLL and VSYNC qualification as CAM3) ---
wire [AXI_DATA_LEN-1 : 0]   cam4_s_data      ;
wire                        cam4_s_data_valid;
wire                        cam4_s_data_last ;
wire                        cam4_s_data_ready;
wire [31:0]                 cam4_cmd_addr    ;
wire [31:0]                 cam4_cmd_len     ;
wire                        cam4_cmd_valid   ;
wire                        cam4_cmd_ready   ;
wire [3:0]                  cam4_axi_awid    ;
wire [31:0]                 cam4_axi_awaddr  ;
wire [7:0]                  cam4_axi_awlen   ;
wire [2:0]                  cam4_axi_awsize  ;
wire [1:0]                  cam4_axi_awburst ;
wire [3:0]                  cam4_axi_awcache ;
wire [2:0]                  cam4_axi_awprot  ;
wire                        cam4_axi_awvalid ;
wire                        cam4_axi_awready ;
wire [127:0]                cam4_axi_wdata   ;
wire [15:0]                 cam4_axi_wstrb   ;
wire                        cam4_axi_awlock  ;
wire                        cam4_axi_wlast   ;
wire                        cam4_axi_wvalid  ;
wire                        cam4_axi_wready  ;
wire [3:0]                  cam4_axi_bid     ;
wire [1:0]                  cam4_axi_bresp   ;
wire                        cam4_axi_bvalid  ;
wire                        cam4_axi_bready  ;
wire [31:0]                 cam4_dbg_dummy;

ov5640_top #(
    .RUNTIME_ENABLE(1'b1), .RUNTIME_BASE(32'h20000a00),
    .RUNTIME_SIGNATURE(32'h43344d32),
    .I2C_FREQ(100_000), // SCCB read-rise margin; C1/C2 retain 250 kHz setting
    .CAM_DATA_LEN(9600),
    .DOWNSAMPLE_2X2(1'b1),
    .BASE_ADDR       (32'h2000_0600),
    .SENSOR_PLL_MULT (8'h36), // cam4: same 54 MHz PCLK init as cam3
    .VSYNC_STABLE_CYCLES(64), // cam4 only: 1.185 us at 54 MHz
    .CAM_ADDR_1_DEF  (32'h0140_0000),
    .CAM_ADDR_2_DEF  (32'h0160_0000),
    .CAM_EN_DEF      (1'b1),
    .H_CMOS_DISP     (11'd640),
    .V_CMOS_DISP     (11'd480),
    .TOTAL_H_PIXEL   (12'd1896),
    .TOTAL_V_PIXEL   (12'd984)
) cam4_ov5640_top (
    .lane_enable(1'b0), .lane_white_min(8'd0), .lane_white_span(8'd0),
    .lane_min_run(8'd0), .lane_line_width(4'd0),
    .lane_left_count(), .lane_right_count(), .lane_frame_sequence(),
    .lane_left_valid(), .lane_right_valid(),
    .lease_prev_base(six_prev[96 +: 32]),.lease_bank0(six_bank0[96 +: 32]),
    .lease_bank1(six_bank1[96 +: 32]),.lease_sequence(six_sequence[96 +: 32]),
    .motion_record(cam4_motion_record), .motion_frame_metadata(cam4_motion_meta),
    .lease_published(six_published[6 +: 2]),.lease_writer_idle(six_writer_idle[3]),
    .lease_pending(six_pending[3]),.lease_flush(six_flush[3]),
    .capture_hold(six_hold[3] || !runtime_allowed_mask[3] || cam_native_park),
    .runtime_dma_idle(six_dma_idle[3]),
    .runtime_idle_raw(runtime_idle_raw),

    .clk_50m       (clk_50m),
    .clk_50m_rst_n (camera_ctrl_rst_n),
    .dbg_locked    (locked),
    .dbg_btn_rst_n (button_rst_n),
    .dbg_axi_awvalid(cam4_axi_awvalid),
    .dbg_axi_awready(cam4_axi_awready),
    .dbg_axi_wvalid (cam4_axi_wvalid ),
    .dbg_axi_wready (cam4_axi_wready ),
    .dbg_axi_bvalid (cam4_axi_bvalid ),
    .dbg_axi_bready (cam4_axi_bready ),

    .cam_pclk (cmos4_pclk ),
    .cam_vsync(cmos4_vsync),
    .cam_href (cmos4_href ),
    .cam_data (cmos4_data ),
    .cam_rst_n(cmos4_rst_n),
    .cam_scl  (cmos4_scl  ),
    .cam_sda  (cmos4_sda  ),

    .s_axi_awvalid(cam4_axil_awvalid),
    .s_axi_awready(cam4_axil_awready),
    .s_axi_awaddr (cam4_axil_awaddr ),
    .s_axi_wvalid (cam4_axil_wvalid ),
    .s_axi_wready (cam4_axil_wready ),
    .s_axi_wdata  (cam4_axil_wdata  ),
    .s_axi_wstrb  (cam4_axil_wstrb  ),
    .s_axi_bvalid (cam4_axil_bvalid ),
    .s_axi_bready (cam4_axil_bready ),
    .s_axi_bresp  (cam4_axil_bresp  ),
    .s_axi_arvalid(cam4_axil_arvalid),
    .s_axi_arready(cam4_axil_arready),
    .s_axi_araddr (cam4_axil_araddr ),
    .s_axi_rvalid (cam4_axil_rvalid ),
    .s_axi_rready (cam4_axil_rready ),
    .s_axi_rdata  (cam4_axil_rdata  ),
    .s_axi_rresp  (cam4_axil_rresp  ),

    .video_clk(axi_clk),
    .video_rst(axi_rst),
    .cam_cmd_addr (cam4_cmd_addr ),
    .cam_cmd_len  (cam4_cmd_len  ),
    .cam_cmd_valid(cam4_cmd_valid),
    .cam_cmd_ready(cam4_cmd_ready),

    .cam_s_data      (cam4_s_data      ),
    .cam_s_data_valid(cam4_s_data_valid),
    .cam_s_data_last (cam4_s_data_last ),
    .cam_s_data_ready(cam4_s_data_ready),

    .cam_dma_abort(cam4_dma_abort),
    .cam_s_data_available(cam4_s_data_available),
    .cam_dma_abort_req(cam4_dma_abort_req),
    .cam_dma_done(cam4_dma_done),
    .xdma_clk (pcie_clk),
    .xdma_irq (          )
);

// =====================================================================
// [SFP 2026-09-29] fiber RX path:
//   SFP(QR3 HSST CH2) -> sfp_rx_link -> sfp_video_rx (1280 wide unpack)
//   -> sfp_rx_cam_if (split 640+640 + CDC to axi_clk)
//   -> cam5/cam6 ov5640_ddr write engines -> axi_dma_write -> ddr_w_arb m4/m5
//   DDR ping-pong: cam5 0x0180_0000/0x01A0_0000, cam6 0x01C0_0000/0x01E0_0000
// =====================================================================
wire c5_tx_valid,c5_tx_ready;wire [31:0] c5_tx_data;wire [3:0] c5_tx_k;
c5_sfp_rx_link u_sfp_rx_link (
 .i_cmd_valid(c5_tx_valid),.i_cmd_data(c5_tx_data),.i_cmd_k(c5_tx_k),.o_cmd_ready(c5_tx_ready),
    .i_free_clk       (free_clk),
    .i_refckp         (ref_clk_p),      // F6, shared with PCIe
    .i_refckn         (ref_clk_n),      // E6
    .i_l2rxn          (sfp_l2rxn),      // D11
    .i_l2rxp          (sfp_l2rxp),      // C11
    .o_l2txn          (sfp_l2txn),      // D5
    .o_l2txp          (sfp_l2txp),      // C5
    .o_sfp_tx_disable (sfp_tx_disable), // L16
    .o_rx_clk         (sfp_rx_clk),
    .o_rx_rst_n       (sfp_rx_rst_n),
    .o_rxd            (sfp_rxd),
    .o_rxk            (sfp_rxk),
    .o_rx_en          (sfp_rx_en),
    .o_pll_lock       (sfp_st_pll_lock),
    .o_txlane_done    (sfp_st_txlane_done),
    .o_rxlane_done    (sfp_st_rxlane_done),
    .o_pcs_synced     (sfp_st_pcs_synced),
    .o_rx_sigdet      (sfp_st_sigdet)
);

wire c5_writer_hold,c5_local_flush,c5_hd;
wire [31:0] native_bev_rdata;
wire native_bev_control_write;
wire c5_writer_reset5 /* synthesis syn_keep=1 syn_maxfan=16 */;
wire c5_writer_reset6 /* synthesis syn_keep=1 syn_maxfan=16 */;

wire [31:0] c5_epoch,c5_frame_seq,c5_ce5,c5_cs5,c5_ce6,c5_cs6;
wire c5_commit5,c5_bank5,c5_commit6,c5_bank6;
wire [31:0] c5_commit_base5,c5_commit_base6;
// Native HDMI (1280x480 / 1280x960) receive path nets.
wire native_meta_valid;
wire native_meta_ok;
wire [159:0] native_meta_payload;
wire native_video_vs,native_video_hs,native_video_de;
wire [15:0] native_video_pix;
wire [15:0] native_pix5,native_pix6;
wire native_vs5,native_hs5,native_de5,native_vs6,native_hs6,native_de6;
wire native_fault,native_active,native_frame_done,native_deactivate;
wire [15:0] native_half_width,native_height;
wire [31:0] native_generation,native_sequence;
wire [1:0] native_mode;
wire [31:0] native_descriptor_rdata;
wire [159:0] source_diag_snapshot;
wire [95:0] native_rt_diag;
wire [31:0] sp_meta_ok,sp_eol;wire [15:0] sp_meta_bad,sp_sof,sp_fault;wire [3:0] sp_reason;wire sp_pending,sp_capturing;
c5_optical_runtime_pipe c5_runtime(.clk(axi_clk),.rst(axi_rst),.rx_clk(sfp_rx_clk),.rx_rst_n(sfp_rx_rst_n),
.link_ok(sfp_rx_en),.rxd(sfp_rxd),.rxk(sfp_rxk),
.tx_word_valid(c5_tx_valid),.tx_word_ready(c5_tx_ready),.tx_word_data(c5_tx_data),.tx_word_k(c5_tx_k),
.s_awaddr(c5_mail_awaddr),
.s_awvalid(c5_mail_awvalid),
.s_awready(c5_mail_awready),
.s_wdata(c5_mail_wdata),
.s_wstrb(c5_mail_wstrb),
.s_wvalid(c5_mail_wvalid),
.s_wready(c5_mail_wready),
.s_bresp(c5_mail_bresp),
.s_bvalid(c5_mail_bvalid),
.s_bready(c5_mail_bready),
.s_araddr(c5_mail_araddr),
.s_arvalid(c5_mail_arvalid),
.s_arready(c5_mail_arready),
.s_rdata(c5_mail_rdata),
.s_rresp(c5_mail_rresp),
.s_rvalid(c5_mail_rvalid),
.s_rready(c5_mail_rready),
.optical_idle(&runtime_idle_raw[5:4]),.writer_hold(c5_writer_hold),.local_flush(c5_local_flush),.hd(c5_hd),.epoch(c5_epoch),
.vs5(cam5_vs),.hs5(cam5_hs),.de5(cam5_de),.pix5(cam5_pix),.vs6(cam6_vs),.hs6(cam6_hs),.de6(cam6_de),.pix6(cam6_pix),
.frame_sequence(c5_frame_seq),.commit5(c5_commit5),.bank5(c5_bank5),.commit_epoch5(c5_ce5),.commit_sequence5(c5_cs5),
.commit6(c5_commit6),.bank6(c5_bank6),.commit_epoch6(c5_ce6),.commit_sequence6(c5_cs6),
.c6_lines_per_frame(diag_c6_lines_w),.c6_line_cycles(diag_c6_line_cycles_w),
 .native_meta_valid(native_meta_valid),.native_meta_payload(native_meta_payload),.native_meta_ok(native_meta_ok),
.native_video_vs(native_video_vs),.native_video_hs(native_video_hs),
.native_video_de(native_video_de),.native_video_pix(native_video_pix),
.native_descriptor_rdata(native_descriptor_rdata),.native_bev_rdata(native_bev_rdata),
 .native_bev_write_pulse(native_bev_control_write),
 .source_diag_snapshot(source_diag_snapshot),
.native_engaged(native_active),.native_deactivate(native_deactivate),.native_diag(native_rt_diag));
c5_native_raster_split u_native_raster (
    .clk(sfp_rx_clk),.rst_n(sfp_rx_rst_n),.axi_clk(axi_clk),.axi_rst_n(!axi_rst),.enable(1'b1),.deactivate(native_deactivate),
    .meta_valid(native_meta_valid),.meta_payload(native_meta_payload),.meta_ok(native_meta_ok),
    .vs_in(native_video_vs),.hs_in(native_video_hs),.de_in(native_video_de),.pix_in(native_video_pix),
    .fault(native_fault),.active(native_active),.half_width(native_half_width),
    .height(native_height),.mode(native_mode),.generation(native_generation),.frame_sequence(native_sequence),
    .frame_done(native_frame_done),
    .cnt_meta_ok(sp_meta_ok),.cnt_meta_bad(sp_meta_bad),.cnt_sof(sp_sof),.cnt_eol(sp_eol),
    .cnt_fault(sp_fault),.fault_reason(sp_reason),.is_pending(sp_pending),.is_capturing(sp_capturing),
    .vs5(native_vs5),.hs5(native_hs5),.de5(native_de5),
    .pix5(native_pix5),.vs6(native_vs6),.hs6(native_hs6),.de6(native_de6),.pix6(native_pix6));
// [2026-10-13] Register the SFP -> DDR-writer video boundary on axi_clk.
// The combinational path FIFO rbin -> RAM -> mux -> writer CE is placement
// sensitive (route dominated). One aligned stage splits it without changing
// the relative vs/hs/de/pix timing seen by the writer. cam5/cam6 outputs are
// consumed only by their own ov5640_ddr instances.
reg        cam5_vs_r, cam5_hs_r, cam5_de_r;
reg [15:0] cam5_pix_r;
reg        cam6_vs_r, cam6_hs_r, cam6_de_r;
reg [15:0] cam6_pix_r;
always @(posedge axi_clk) begin
    if (axi_rst) begin
        cam5_vs_r <= 1'b0; cam5_hs_r <= 1'b0; cam5_de_r <= 1'b0; cam5_pix_r <= 16'd0;
        cam6_vs_r <= 1'b0; cam6_hs_r <= 1'b0; cam6_de_r <= 1'b0; cam6_pix_r <= 16'd0;
    end
    else begin
        cam5_vs_r <= native_active ? native_vs5 : cam5_vs;
        cam5_hs_r <= native_active ? native_hs5 : cam5_hs;
        cam5_de_r <= native_active ? native_de5 : cam5_de;
        cam5_pix_r <= native_active ? native_pix5 : cam5_pix;
        cam6_vs_r <= native_active ? native_vs6 : cam6_vs;
        cam6_hs_r <= native_active ? native_hs6 : cam6_hs;
        cam6_de_r <= native_active ? native_de6 : cam6_de;
        cam6_pix_r <= native_active ? native_pix6 : cam6_pix;
    end
end

wire [15:0] cam5_lane_pix, cam6_lane_pix;
// Native HDMI is a separate source family. Its v2 META is decoded before
// entering the native splitter; legacy camera VGA/HD negotiation is unchanged.
c5_native_descriptor u_native_descriptor(.clk(sfp_rx_clk),.rst_n(sfp_rx_rst_n),
    .axi_clk(axi_clk),.axi_rst_n(!axi_rst),
    .address(c5_mail_araddr[8:0]),.active(native_active),.mode(native_mode),
    .generation(native_generation),.frame_id(native_sequence),.frame_done(native_frame_done),
    .source_diag_snapshot(source_diag_snapshot),
    .diag({8'd0,sp_reason,sp_pending,sp_capturing,native_active,native_fault,sp_fault,sp_eol[15:0],sp_sof,sp_meta_bad,sp_meta_ok[15:0],native_rt_diag}),
    .rdata(native_descriptor_rdata));
// Native frames must reach DDR even when the legacy mailbox is FAILED/HOLD.
(* ASYNC_REG="TRUE" *) reg [1:0] native_active_axi_sync;
always @(posedge axi_clk) native_active_axi_sync <= {native_active_axi_sync[0], native_active};
wire native_active_axi = native_active_axi_sync[1];
assign cam_native_park = native_active_axi;
// Geometry mode is stable for a whole native frame. Synchronize it per bit;
// a commit cannot coincide with a mode transition in practice, and the engine
// additionally requires native_active_axi and mode 3 before starting.
(* ASYNC_REG="TRUE" *) reg [1:0] native_mode_axi_meta,native_mode_axi_sync;
always @(posedge axi_clk) begin
    native_mode_axi_meta<=native_mode;
    native_mode_axi_sync<=native_mode_axi_meta;
end
wire [1:0] native_mode_axi=native_mode_axi_sync;
// Native HDMI owns its raster/descriptor lifecycle. The legacy mailbox's
// local_flush is for legacy C5/C6 renegotiation only; letting it reset native
// writers strands them after any failed legacy transaction. The global AXI/DMA
// reset remains authoritative for both paths. Use the AXI-domain synchronized
// active flag only: native_active itself belongs to the receiver clock domain.
c5_writer_reset_branch c5_reset_branch5(.global_axi_reset(axi_rst),.local_flush(c5_local_flush && !native_active_axi),.writer_reset(c5_writer_reset5));
c5_writer_reset_branch c5_reset_branch6(.global_axi_reset(axi_rst),.local_flush(c5_local_flush && !native_active_axi),.writer_reset(c5_writer_reset6));
wire [17:0] native_writer_beats = native_height==16'd480 ? 18'd38400 : 18'd76800;
wire [17:0] cam5_writer_beats = native_active ? native_writer_beats : (c5_hd ? 18'd115200 : 18'd38400);
wire [17:0] cam6_writer_beats = native_active ? native_writer_beats : 18'd38400;
wire [31:0] c5_commit_epoch = native_active ? native_generation : c5_epoch;
wire [31:0] c5_commit_frame_sequence = native_active ? native_sequence : c5_frame_seq;
// Both video modes remain in this bitstream. Their arithmetic shares the
// divider above, while each HDMI half keeps independent candidates/models.
// [LANE_REC] Pixels are never overlaid: each half keeps one bottom 640x360
// lane ROI whose per-frame result is written into that frame's commit tag.
// Native HDMI halves are 640x480 or 640x960; legacy C5 HD (1280x720) has none.
reg [11:0] c56_lane_height;
reg c5_lane_ok;
always @(posedge axi_clk) begin
    c56_lane_height <= (native_active && native_height == 16'd960) ? 12'd960 : 12'd480;
    c5_lane_ok <= native_active || !c5_hd;
end
wire cam5_lane_rec_valid, cam6_lane_rec_valid;
wire [95:0] cam5_lane_rec, cam6_lane_rec;
// [v9 2026-11-02] Legacy C5/C6 lane_roi_overlay removed: replaced by the
// native BEV lane engine (result page 0x20021200). Their records are tied
// off, so the C5/C6 writers no longer wait for a lane record (lane_wait=0)
// and tag[127:32] is zero. Shared-divider ports 1/2 are idle.
assign cam5_lane_rec_valid = 1'b0;
assign cam6_lane_rec_valid = 1'b0;
assign cam5_lane_rec = 96'd0;
assign cam6_lane_rec = 96'd0;
assign cam5_lane_pix = cam5_pix_r;
assign cam6_lane_pix = cam6_pix_r;
assign hdmi_lane_left_count = 16'd0;
assign hdmi_lane_right_count = 16'd0;
assign hdmi_lane_frame_sequence = 32'd0;
assign hdmi_lane_left_valid = 1'b0;
assign hdmi_lane_right_valid = 1'b0;
assign lane_div_req_valid[2:1] = 2'b00;
assign lane_div_req_dividend[191:64] = 128'd0;
assign lane_div_req_divisor[191:64] = 128'd0;

// [2026-09-30] BISECT3 uncommented: cam5/6 ��������ע��
// ---- cam5 write engine (fiber left half = 50K CMOS1) ----
wire cam5_dma_done, cam5_dma_abort, cam5_dma_abort_req;
wire cam6_dma_done, cam6_dma_abort, cam6_dma_abort_req;
c5_optical_ddr #(
    .DATA_WIDTH     (16),
    .AXI_ADDR_WIDTH (32),
    .AXI_LEN_WIDTH  (32),
    .AXI_DATA_WIDTH (128),
    .CAM_DATA_LEN   (115200),            // 640*480*2/16
    .DEVICE         ("PG")
) cam5_ov5640_ddr (
 .c5_counter_reset(axi_rst),
 .c5_epoch(c5_commit_epoch),.c5_frame_sequence(c5_commit_frame_sequence),.c5_commit(c5_commit5),.c5_bank(c5_bank5),.c5_commit_base(c5_commit_base5),
 .c5_commit_epoch(c5_ce5),.c5_commit_sequence(c5_cs5),
    .lease_prev_base(six_prev[128 +: 32]),.lease_bank0(six_bank0[128 +: 32]),
    .lease_bank1(six_bank1[128 +: 32]),.lease_sequence(six_sequence[128 +: 32]),
    .lease_published(six_published[8 +: 2]),.lease_writer_idle(six_writer_idle[4]),
    .lease_pending(six_pending[4]),.lease_flush(six_flush[4]),

    .axi_clk        (axi_clk),
    .axi_rst        (c5_writer_reset5),
    .axi_cam_en     (!delivery_hold && runtime_allowed_mask[4] && (!c5_writer_hold || native_active_axi)),
    .dbg_fault_snapshot (cam5_diag_fault), .dbg_reject_counts (cam5_diag_rejects), .dbg_input_pixels (cam5_diag_pixels),
    .dma_abort      (cam5_dma_abort),
    .dma_abort_req  (cam5_dma_abort_req),
    .axi_data_available (cam5_s_data_available),
    .dma_done       (cam5_dma_done),
    .cam_data_addr_1(32'h0180_0000),
    .cam_data_addr_2(32'h01A0_0000),
    .prev_frame_base(delivery_prev),               // [KF-unused] output: fiber channels have no KF readback
    .cam_data_len   (cam5_writer_beats),
    .s_data         (cam5_pix_r),
    .lane_wait(1'b0),.lane_rec_valid(cam5_lane_rec_valid),.lane_rec(cam5_lane_rec),
    .s_data_valid   (cam5_de_r),
    .s_hsync        (cam5_hs_r),
    .s_vsync        (cam5_vs_r),
    .axi_data       (cam5_s_data),
    .axi_data_valid (cam5_s_data_valid),
    .axi_data_last  (cam5_s_data_last),
    .axi_data_ready (cam5_s_data_ready),
    .axi_cmd_addr   (cam5_cmd_addr),
    .axi_cmd_len    (cam5_cmd_len),
    .axi_cmd_valid  (cam5_cmd_valid),
    .axi_cmd_ready  (cam5_cmd_ready),
    .dbg_axi_cnt (), .dbg_axi_num (), .dbg_zdin (), .dbg_zout (),
    .dbg_state (cam5_diag_state), .dbg_last_cnt (), .dbg_wd_cnt (),
    .xdma_req  (delivery_published),
    .xdma_ack  (2'b00)
);

axi_dma_write #(
    .WAIT_FOR_DATA(1),
    .BURST_LEN  (BURST_LEN)   ,
    .ID_WIDTH   (AXI_ID_LEN)  ,
    .DATA_WIDTH (AXI_DATA_LEN)
) cam5_axi_dma_write (
    .lease_idle(six_dma_idle[4]),
    .data_in_available(cam5_s_data_available),
    .abort_req(cam5_dma_abort_req),
    .data_in_abort(cam5_dma_abort),
    .clk(axi_clk),
    .rst(axi_rst),
    .cmd_valid (cam5_cmd_valid),
    .cmd_addr  (cam5_cmd_addr ),
    .cmd_len   (cam5_cmd_len  ),
    .cmd_id    (4'b0011),
    .cmd_ready (cam5_cmd_ready),
    .data_in       (cam5_s_data),
    .data_in_keep  ({AXI_STRB_LEN{1'b1}}),
    .data_in_valid (cam5_s_data_valid),
    .data_in_last  (cam5_dma_done),
    .data_in_ready (cam5_s_data_ready),
    .m_axi_awid    (cam5_axi_awid),
    .m_axi_awaddr  (cam5_axi_awaddr),
    .m_axi_awlen   (cam5_axi_awlen),
    .m_axi_awsize  (cam5_axi_awsize),
    .m_axi_awburst (cam5_axi_awburst),
    .m_axi_awlock  (cam5_axi_awlock),
    .m_axi_awcache (cam5_axi_awcache),
    .m_axi_awprot  (cam5_axi_awprot),
    .m_axi_awvalid (cam5_axi_awvalid),
    .m_axi_awready (cam5_axi_awready),
    .m_axi_wdata   (cam5_axi_wdata),
    .m_axi_wstrb   (cam5_axi_wstrb),
    .m_axi_wlast   (cam5_axi_wlast),
    .m_axi_wvalid  (cam5_axi_wvalid),
    .m_axi_wready  (cam5_axi_wready),
    .m_axi_bid     (cam5_axi_bid),
    .m_axi_bresp   (cam5_axi_bresp),
    .m_axi_bvalid  (cam5_axi_bvalid),
    .m_axi_bready  (cam5_axi_bready)
);

// ---- cam6 write engine (fiber right half = 50K CMOS2) ----
c5_optical_ddr #(
    .DATA_WIDTH     (16),
    .AXI_ADDR_WIDTH (32),
    .AXI_LEN_WIDTH  (32),
    .AXI_DATA_WIDTH (128),
    .CAM_DATA_LEN   (115200),
    .DEVICE         ("PG")
) cam6_ov5640_ddr (
 .c5_counter_reset(axi_rst),
 .c5_epoch(c5_commit_epoch),.c5_frame_sequence(c5_commit_frame_sequence),.c5_commit(c5_commit6),.c5_bank(c5_bank6),.c5_commit_base(c5_commit_base6),
 .c5_commit_epoch(c5_ce6),.c5_commit_sequence(c5_cs6),
    .lease_prev_base(six_prev[160 +: 32]),.lease_bank0(six_bank0[160 +: 32]),
    .lease_bank1(six_bank1[160 +: 32]),.lease_sequence(six_sequence[160 +: 32]),
    .lease_published(six_published[10 +: 2]),.lease_writer_idle(six_writer_idle[5]),
    .lease_pending(six_pending[5]),.lease_flush(six_flush[5]),

    .axi_clk        (axi_clk),
    .axi_rst        (c5_writer_reset6),
    .axi_cam_en     (!six_hold[5] && runtime_allowed_mask[5] && (!c5_writer_hold || native_active_axi)),
    .dbg_fault_snapshot (cam6_diag_fault), .dbg_reject_counts (cam6_diag_rejects), .dbg_input_pixels (cam6_diag_pixels),
    .dma_abort      (cam6_dma_abort),
    .dma_abort_req  (cam6_dma_abort_req),
    .axi_data_available (cam6_s_data_available),
    .dma_done       (cam6_dma_done),
    .cam_data_addr_1(32'h01C0_0000),
    .cam_data_addr_2(32'h01E0_0000),
    .prev_frame_base(),               // [KF-unused]
    .cam_data_len   (cam6_writer_beats),
    .s_data         (cam6_pix_r),
    .lane_wait(1'b0),.lane_rec_valid(cam6_lane_rec_valid),.lane_rec(cam6_lane_rec),
    .s_data_valid   (cam6_de_r),
    .s_hsync        (cam6_hs_r),
    .s_vsync        (cam6_vs_r),
    .axi_data       (cam6_s_data),
    .axi_data_valid (cam6_s_data_valid),
    .axi_data_last  (cam6_s_data_last),
    .axi_data_ready (cam6_s_data_ready),
    .axi_cmd_addr   (cam6_cmd_addr),
    .axi_cmd_len    (cam6_cmd_len),
    .axi_cmd_valid  (cam6_cmd_valid),
    .axi_cmd_ready  (cam6_cmd_ready),
    .dbg_axi_cnt (), .dbg_axi_num (), .dbg_zdin (), .dbg_zout (),
    .dbg_state (cam6_diag_state), .dbg_last_cnt (), .dbg_wd_cnt (),
    .xdma_req  (),
    .xdma_ack  (2'b00)
);

axi_dma_write #(
    .WAIT_FOR_DATA(1),
    .BURST_LEN  (BURST_LEN)   ,
    .ID_WIDTH   (AXI_ID_LEN)  ,
    .DATA_WIDTH (AXI_DATA_LEN)
) cam6_axi_dma_write (
    .lease_idle(six_dma_idle[5]),
    .data_in_available(cam6_s_data_available),
    .abort_req(cam6_dma_abort_req),
    .data_in_abort(cam6_dma_abort),
    .clk(axi_clk),
    .rst(axi_rst),
    .cmd_valid (cam6_cmd_valid),
    .cmd_addr  (cam6_cmd_addr ),
    .cmd_len   (cam6_cmd_len  ),
    .cmd_id    (4'b1100),
    .cmd_ready (cam6_cmd_ready),
    .data_in       (cam6_s_data),
    .data_in_keep  ({AXI_STRB_LEN{1'b1}}),
    .data_in_valid (cam6_s_data_valid),
    .data_in_last  (cam6_dma_done),
    .data_in_ready (cam6_s_data_ready),
    .m_axi_awid    (cam6_axi_awid),
    .m_axi_awaddr  (cam6_axi_awaddr),
    .m_axi_awlen   (cam6_axi_awlen),
    .m_axi_awsize  (cam6_axi_awsize),
    .m_axi_awburst (cam6_axi_awburst),
    .m_axi_awlock  (cam6_axi_awlock),
    .m_axi_awcache (cam6_axi_awcache),
    .m_axi_awprot  (cam6_axi_awprot),
    .m_axi_awvalid (cam6_axi_awvalid),
    .m_axi_awready (cam6_axi_awready),
    .m_axi_wdata   (cam6_axi_wdata),
    .m_axi_wstrb   (cam6_axi_wstrb),
    .m_axi_wlast   (cam6_axi_wlast),
    .m_axi_wvalid  (cam6_axi_wvalid),
    .m_axi_wready  (cam6_axi_wready),
    .m_axi_bid     (cam6_axi_bid),
    .m_axi_bresp   (cam6_axi_bresp),
    .m_axi_bvalid  (cam6_axi_bvalid),
    .m_axi_bready  (cam6_axi_bready)
);


// */
`elsif USE_HDMI

hdmi_top hdmi_top(
    .clk_10m(clk_10m)               ,
    .clk_10m_rst_n(locked & button_rst_n)         ,

    //HDMI�ӿ�

    //ms72XX
    .rstn_out(rstn_out),

    // FMC I2C 
    .iic_scl(iic_scl),
    .iic_sda(iic_sda), 

    // .iic_tx_scl(iic_tx_scl),
    // .iic_tx_sda(iic_tx_sda), 

    //HDMI IN
    .pixclk_in(pixclk_in),                            
    .vs_in(vs_in) , 
    .hs_in(hs_in) , 
    .de_in(de_in) ,
    .r_in (r_in ) , 
    .g_in (g_in ) , 
    .b_in (b_in ) ,  




    //����ͷ���ƼĴ���
    .s_axi_awvalid(cam_axil_awvalid)        ,
    .s_axi_awready(cam_axil_awready)        ,
    .s_axi_awaddr (cam_axil_awaddr )        ,

    .s_axi_wvalid (cam_axil_wvalid)         ,
    .s_axi_wready (cam_axil_wready)         ,
    .s_axi_wdata  (cam_axil_wdata )         ,
    .s_axi_wstrb  (cam_axil_wstrb )         ,

    .s_axi_bvalid (cam_axil_bvalid)         ,
    .s_axi_bready (cam_axil_bready)         ,
    .s_axi_bresp  (cam_axil_bresp )         ,

    .s_axi_arvalid(cam_axil_arvalid)        ,
    .s_axi_arready(cam_axil_arready)        ,
    .s_axi_araddr (cam_axil_araddr )        ,

    .s_axi_rvalid (cam_axil_rvalid )        ,
    .s_axi_rready (cam_axil_rready )        ,
    .s_axi_rdata  (cam_axil_rdata  )        ,
    .s_axi_rresp  (cam_axil_rresp  )        ,



    //AXI_stream
    .video_clk(axi_clk)      ,
    .video_rst(axi_rst)      ,
    .cam_cmd_addr (cam_cmd_addr )  ,
    .cam_cmd_len  (cam_cmd_len  )  ,
    .cam_cmd_valid(cam_cmd_valid)  ,
    .cam_cmd_ready(cam_cmd_ready)  ,

    .cam_s_data      (cam_tap_data      ),
    .cam_s_data_valid(cam_tap_data_valid),
    .cam_s_data_last (cam_tap_data_last ),
    .cam_s_data_ready(cam_tap_data_ready),

    //DMA?
    .xdma_clk (pcie_clk) ,
    .xdma_irq (cam_irq ) 

);
`endif

wire [AXI_ID_LEN-1:0]   ov5640_axi_awid    /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]             ov5640_axi_awaddr  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              ov5640_axi_awlen   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              ov5640_axi_awsize  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              ov5640_axi_awburst /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_awlock  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              ov5640_axi_awcache /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              ov5640_axi_awprot  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_awvalid /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_awready /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_DATA_LEN-1:0] ov5640_axi_wdata   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_STRB_LEN-1:0] ov5640_axi_wstrb   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_wlast   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_wvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_wready  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_ID_LEN-1:0]   ov5640_axi_bid     /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              ov5640_axi_bresp   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_bvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    ov5640_axi_bready  /*synthesis PAP_MARK_DEBUG="1"*/;

axi_dma_write #(
    .WAIT_FOR_DATA(1),
	.BURST_LEN  (BURST_LEN)   ,
	.ID_WIDTH   (AXI_ID_LEN)  ,
	.DATA_WIDTH (AXI_DATA_LEN)
)
ov5640_axi_dma_write(
    .lease_idle(six_dma_idle[0]),
    .data_in_available(cam_s_data_available),
    .abort_req(cam_dma_abort_req),
    .data_in_abort(cam_dma_abort),
	.clk(axi_clk)                   ,
	.rst(axi_rst)                   ,

	.cmd_valid (cam_cmd_valid)      ,
	.cmd_addr  (cam_cmd_addr )      ,
	.cmd_len   (cam_cmd_len  )      ,
	.cmd_id    (4'b0001)            ,
	.cmd_ready (cam_cmd_ready)      ,

	.data_in       (cam_s_data          ),
	.data_in_keep  ({AXI_STRB_LEN{1'b1}}),
	.data_in_valid (cam_s_data_valid    ),
	.data_in_last  (cam_dma_done     ),  // [LEDGER 2026-09-19]
	.data_in_ready (cam_s_data_ready    ),

	.m_axi_awid    (ov5640_axi_awid    ),
	.m_axi_awaddr  (ov5640_axi_awaddr  ),
	.m_axi_awlen   (ov5640_axi_awlen   ),
	.m_axi_awsize  (ov5640_axi_awsize  ),
	.m_axi_awburst (ov5640_axi_awburst ),
	.m_axi_awlock  (ov5640_axi_awlock  ),
	.m_axi_awcache (ov5640_axi_awcache ),
	.m_axi_awprot  (ov5640_axi_awprot  ),
	.m_axi_awvalid (ov5640_axi_awvalid ),
	.m_axi_awready (ov5640_axi_awready ),
	.m_axi_wdata   (ov5640_axi_wdata   ),
	.m_axi_wstrb   (ov5640_axi_wstrb   ),
	.m_axi_wlast   (ov5640_axi_wlast   ),
	.m_axi_wvalid  (ov5640_axi_wvalid  ),
	.m_axi_wready  (ov5640_axi_wready  ),
	.m_axi_bid     (ov5640_axi_bid     ),
	.m_axi_bresp   (ov5640_axi_bresp   ),
	.m_axi_bvalid  (ov5640_axi_bvalid  ),
	.m_axi_bready  (ov5640_axi_bready  )
);

axi_dma_write #(
    .WAIT_FOR_DATA(1),
	.BURST_LEN  (BURST_LEN)   ,
	.ID_WIDTH   (AXI_ID_LEN)  ,
	.DATA_WIDTH (AXI_DATA_LEN)
)
cam2_axi_dma_write(
    .lease_idle(six_dma_idle[1]),
    .data_in_available(cam2_s_data_available),
    .abort_req(cam2_dma_abort_req),
    .data_in_abort(cam2_dma_abort),
	.clk(axi_clk)                   ,
	.rst(axi_rst)                   ,

	.cmd_valid (cam2_cmd_valid)     ,
	.cmd_addr  (cam2_cmd_addr )     ,
	.cmd_len   (cam2_cmd_len  )     ,
	.cmd_id    (4'b0100)            ,
	.cmd_ready (cam2_cmd_ready)     ,

	.data_in       (cam2_s_data          ),
	.data_in_keep  ({AXI_STRB_LEN{1'b1}}),
	.data_in_valid (cam2_s_data_valid    ),
	.data_in_last  (cam2_dma_done    ),  // [LEDGER 2026-09-19]
	.data_in_ready (cam2_s_data_ready    ),

	.m_axi_awid    (cam2_axi_awid    ),
	.m_axi_awaddr  (cam2_axi_awaddr  ),
	.m_axi_awlen   (cam2_axi_awlen   ),
	.m_axi_awsize  (cam2_axi_awsize  ),
	.m_axi_awburst (cam2_axi_awburst ),
	.m_axi_awlock  (cam2_axi_awlock  ),
	.m_axi_awcache (cam2_axi_awcache ),
	.m_axi_awprot  (cam2_axi_awprot  ),
	.m_axi_awvalid (cam2_axi_awvalid ),
	.m_axi_awready (cam2_axi_awready ),
	.m_axi_wdata   (cam2_axi_wdata   ),
	.m_axi_wstrb   (cam2_axi_wstrb   ),
	.m_axi_wlast   (cam2_axi_wlast   ),
	.m_axi_wvalid  (cam2_axi_wvalid  ),
	.m_axi_wready  (cam2_axi_wready  ),
	.m_axi_bid     (cam2_axi_bid     ),
	.m_axi_bresp   (cam2_axi_bresp   ),
	.m_axi_bvalid  (cam2_axi_bvalid  ),
	.m_axi_bready  (cam2_axi_bready  )
);

axi_dma_write #(
    .WAIT_FOR_DATA(1),
	.BURST_LEN  (BURST_LEN)   ,
	.ID_WIDTH   (AXI_ID_LEN)  ,
	.DATA_WIDTH (AXI_DATA_LEN)
)
cam3_axi_dma_write(
    .lease_idle(six_dma_idle[2]),
    .data_in_available(cam3_s_data_available),
    .abort_req(cam3_dma_abort_req),
    .data_in_abort(cam3_dma_abort),
	.clk(axi_clk)                   ,
	.rst(axi_rst)                   ,

	.cmd_valid (cam3_cmd_valid)     ,
	.cmd_addr  (cam3_cmd_addr )     ,
	.cmd_len   (cam3_cmd_len  )     ,
	.cmd_id    (4'b0010)            ,
	.cmd_ready (cam3_cmd_ready)     ,

	.data_in       (cam3_s_data          ),
	.data_in_keep  ({AXI_STRB_LEN{1'b1}}),
	.data_in_valid (cam3_s_data_valid    ),
	.data_in_last  (cam3_dma_done    ),  // [LEDGER] per-camera single-beat marker
	.data_in_ready (cam3_s_data_ready    ),

	.m_axi_awid    (cam3_axi_awid    ),
	.m_axi_awaddr  (cam3_axi_awaddr  ),
	.m_axi_awlen   (cam3_axi_awlen   ),
	.m_axi_awsize  (cam3_axi_awsize  ),
	.m_axi_awburst (cam3_axi_awburst ),
	.m_axi_awlock  (cam3_axi_awlock  ),
	.m_axi_awcache (cam3_axi_awcache ),
	.m_axi_awprot  (cam3_axi_awprot  ),
	.m_axi_awvalid (cam3_axi_awvalid ),
	.m_axi_awready (cam3_axi_awready ),
	.m_axi_wdata   (cam3_axi_wdata   ),
	.m_axi_wstrb   (cam3_axi_wstrb   ),
	.m_axi_wlast   (cam3_axi_wlast   ),
	.m_axi_wvalid  (cam3_axi_wvalid  ),
	.m_axi_wready  (cam3_axi_wready  ),
	.m_axi_bid     (cam3_axi_bid     ),
	.m_axi_bresp   (cam3_axi_bresp   ),
	.m_axi_bvalid  (cam3_axi_bvalid  ),
	.m_axi_bready  (cam3_axi_bready  )
);

axi_dma_write #(
    .WAIT_FOR_DATA(1),
	.BURST_LEN  (BURST_LEN)   ,
	.ID_WIDTH   (AXI_ID_LEN)  ,
	.DATA_WIDTH (AXI_DATA_LEN)
)
cam4_axi_dma_write(
    .lease_idle(six_dma_idle[3]),
    .data_in_available(cam4_s_data_available),
    .abort_req(cam4_dma_abort_req),
    .data_in_abort(cam4_dma_abort),
	.clk(axi_clk)                   ,
	.rst(axi_rst)                   ,

	.cmd_valid (cam4_cmd_valid)     ,
	.cmd_addr  (cam4_cmd_addr )     ,
	.cmd_len   (cam4_cmd_len  )     ,
	.cmd_id    (4'b1000)            ,
	.cmd_ready (cam4_cmd_ready)     ,

	.data_in       (cam4_s_data          ),
	.data_in_keep  ({AXI_STRB_LEN{1'b1}}),
	.data_in_valid (cam4_s_data_valid    ),
	.data_in_last  (cam4_dma_done    ),  // [CAM4] per-camera single-beat marker
	.data_in_ready (cam4_s_data_ready    ),

	.m_axi_awid    (cam4_axi_awid    ),
	.m_axi_awaddr  (cam4_axi_awaddr  ),
	.m_axi_awlen   (cam4_axi_awlen   ),
	.m_axi_awsize  (cam4_axi_awsize  ),
	.m_axi_awburst (cam4_axi_awburst ),
	.m_axi_awlock  (cam4_axi_awlock  ),
	.m_axi_awcache (cam4_axi_awcache ),
	.m_axi_awprot  (cam4_axi_awprot  ),
	.m_axi_awvalid (cam4_axi_awvalid ),
	.m_axi_awready (cam4_axi_awready ),
	.m_axi_wdata   (cam4_axi_wdata   ),
	.m_axi_wstrb   (cam4_axi_wstrb   ),
	.m_axi_wlast   (cam4_axi_wlast   ),
	.m_axi_wvalid  (cam4_axi_wvalid  ),
	.m_axi_wready  (cam4_axi_wready  ),
	.m_axi_bid     (cam4_axi_bid     ),
	.m_axi_bresp   (cam4_axi_bresp   ),
	.m_axi_bvalid  (cam4_axi_bvalid  ),
	.m_axi_bready  (cam4_axi_bready  )
);

// ===================== preprocess datapath (PREP, batch-2) =====================
reg [7:0] prep_frame_cnt;
always @(posedge axi_clk) begin
    if (axi_rst)
        prep_frame_cnt <= 8'd0;
    else if (prep_out_frame_start)
        prep_frame_cnt <= prep_frame_cnt + 8'd1;
end
// camera raw stream -> cam_prep_link (tap) -> preprocess_top -> processed
// write engine (second axi_dma_write, crossbar S03 write channel)
wire [AXI_DATA_LEN-1:0] prep_wr_data;
wire                    prep_wr_valid;
wire                    prep_wr_ready;
wire                    prep_wr_cmd_valid;
wire                    prep_wr_cmd_ready;
wire [31:0]             prep_wr_cmd_addr;
wire [31:0]             prep_wr_cmd_len;
wire [15:0]             prep_pp_data;
wire                    prep_pp_valid;
wire                    prep_pp_ready;
wire                    prep_pp_fsync;
wire [15:0]             prep_out_data;
wire                    prep_out_valid;
wire                    prep_out_ready;
wire                    prep_out_fsync;
wire                    prep_out_frame_start;
wire                    prep_edge_valid;
wire                    prep_edge_bit;
wire [7:0]              prep_edge_center;
wire                    prep_cid_valid;
wire [1:0]              prep_cid;
wire [1:0]              lane_left_type_w, lane_right_type_w;
wire                    lane_left_valid_w, lane_right_valid_w, lane_frame_upd_w;

// [OptionB 2026-09-12] WIP pixel-path disabled: recover 53006-reg verified netlist (DOC v1.1 3.3). Phase-2: recalibrate cam_prep_link TB then restore.
// cam_prep_link #(
//     .FRAME_H (720),
//     .BUFFER0 (32'h0A00_0000),
//     .BUFFER1 (32'h0A1C_2000)
// ) cam_prep_link_u (
//     .clk            (axi_clk),
//     .rst            (axi_rst),
//     .img_width      (prep_img_width_w),
//     .bypass_mode    (prep_bypass_w),
//     .mode           (prep_mode_w),
//     .cam_data       (cam_tap_data),
//     .cam_valid      (cam_tap_data_valid),
//     .cam_ready      (cam_tap_data_ready),
//     .cam_frame_sync (cam_cmd_valid),
//     .raw_data       (cam_s_data),
//     .raw_valid      (cam_s_data_valid),
//     .raw_ready      (cam_s_data_ready),
//     .pp_data        (prep_pp_data),
//     .pp_valid       (prep_pp_valid),
//     .pp_ready       (prep_pp_ready),
//     .pp_frame_sync  (prep_pp_fsync),
//     .out_data       (prep_out_data),
//     .out_valid      (prep_out_valid),
//     .out_ready      (prep_out_ready),
//     .out_frame_sync (prep_out_fsync),
//     .wr_cmd_valid   (prep_wr_cmd_valid),
//     .wr_cmd_ready   (prep_wr_cmd_ready),
//     .wr_cmd_addr    (prep_wr_cmd_addr),
//     .wr_cmd_len     (prep_wr_cmd_len),
//     .wr_data        (prep_wr_data),
//     .wr_valid       (prep_wr_valid),
//     .wr_ready       (prep_wr_ready)
// );

// [OptionB 2026-09-12] WIP pixel-path disabled: recover 53006-reg verified netlist (DOC v1.1 3.3). Phase-2: recalibrate cam_prep_link TB then restore.
// preprocess_top #(
//     .MAX_WIDTH   (1920),
//     .FIFO_DEPTH  (512)
// ) preprocess_top_u (
//     .clk            (axi_clk),
//     .rst_n          (~axi_rst),
//     .s_rgb565       (prep_pp_data),
//     .s_valid        (prep_pp_valid),
//     .s_ready        (prep_pp_ready),
//     .s_frame_sync   (prep_pp_fsync),
//     .m_ready        (prep_out_ready),
//     .m_rgb565       (prep_out_data),
//     .m_valid        (prep_out_valid),
//     .m_frame_sync   (prep_out_fsync),
//     .reg_bypass     (prep_bypass_w),
//     .reg_mode       (prep_mode_w),
//     .reg_img_width  (prep_img_width_w),
//     .reg_thr_sat    (prep_thr_sat_w),
//     .reg_thr_hue    (prep_thr_hue_w),
//     .reg_thr_val    (prep_thr_val_w),
//     .reg_thr_low    (prep_thr_low_w),
//     .reg_thr_edge   (prep_thr_edge_w),
//     .out_frame_start(prep_out_frame_start),
//     .edge_stream_valid (prep_edge_valid),
//     .edge_stream_edge  (prep_edge_bit),
//     .edge_stream_center(prep_edge_center),
//     .color_id_valid (prep_cid_valid),
//     .color_id       (prep_cid)
// );

// [OptionB 2026-09-12] WIP pixel-path disabled: recover 53006-reg verified netlist (DOC v1.1 3.3). Phase-2: recalibrate cam_prep_link TB then restore.
// lane_detect #(
//     .MAX_WIDTH(1920)
// ) lane_detect_u (
//     .clk        (axi_clk),
//     .rst_n      (~axi_rst),
//     .img_width  (prep_img_width_w),
//     .img_height (12'd720),
//     .roi_top_pct(prep_lane_roi_top_w),
//     .roi_bot_pct(prep_lane_roi_bot_w),
//     .row_thr    (prep_lane_row_thr_w),
//     .dash_thr   (prep_lane_dash_thr_w),
//     .s_center   (prep_edge_center),
//     .s_edge     (prep_edge_bit),
//     .s_valid    (prep_edge_valid),
//     .s_frame_sync(prep_out_frame_start),
//     .m_left_type (lane_left_type_w),
//     .m_right_type(lane_right_type_w),
//     .m_left_valid (lane_left_valid_w),
//     .m_right_valid(lane_right_valid_w),
//     .m_frame_upd  (lane_frame_upd_w)
// );


// ===== [2026-09-12] RAW camera path restored =====
// OptionB commented out cam_prep_link but left cam_s_data undriven, so the
// camera never wrote DDR -> no frames / no MSI. ov5640_top already emits a
// complete raw AXI-stream write request, so wire it straight to the raw write
// engine. The preprocess tap is intentionally NOT used (its TB still fails and
// its dummy-inject can back-pressure/stall the camera).
assign cam_s_data         = cam_tap_data;
assign cam_s_data_valid   = cam_tap_data_valid;
assign cam_s_data_last    = cam_tap_data_last;
assign cam_tap_data_ready = cam_s_data_ready;

// preprocess datapath disabled: keep the processed-frame write engine idle
assign prep_wr_cmd_valid = 1'b0;
assign prep_wr_cmd_addr  = 32'b0;
assign prep_wr_cmd_len   = 32'b0;
assign prep_wr_data      = 128'b0;
assign prep_wr_valid     = 1'b0;

// processed-frame write engine (second write master -> crossbar S03 AW/W/B)
wire [AXI_ID_LEN-1:0]   prep2_axi_awid;
wire [31:0]             prep2_axi_awaddr;
wire [3:0]              prep2_axi_awlen;
wire [2:0]              prep2_axi_awsize;
wire [1:0]              prep2_axi_awburst;
wire                    prep2_axi_awlock;
wire [3:0]              prep2_axi_awcache;
wire [2:0]              prep2_axi_awprot;
wire                    prep2_axi_awvalid;
wire                    prep2_axi_awready;
wire [AXI_DATA_LEN-1:0] prep2_axi_wdata;
wire [AXI_STRB_LEN-1:0] prep2_axi_wstrb;
wire                    prep2_axi_wlast;
wire                    prep2_axi_wvalid;
wire                    prep2_axi_wready;
wire [AXI_ID_LEN-1:0]   prep2_axi_bid;
wire [1:0]              prep2_axi_bresp;
wire                    prep2_axi_bvalid;
wire                    prep2_axi_bready;

axi_dma_write #(
    .BURST_LEN  (BURST_LEN),
    .ID_WIDTH   (AXI_ID_LEN),
    .DATA_WIDTH (AXI_DATA_LEN)
) prep_axi_dma_write(
    .data_in_available(16'd0),
    .abort_req(1'b0),
    .data_in_abort(),
    .clk(axi_clk),
    .rst(axi_rst),
    .cmd_valid (prep_wr_cmd_valid),
    .cmd_addr  (prep_wr_cmd_addr),
    .cmd_len   (prep_wr_cmd_len),
    .cmd_id    (4'b0111),
    .cmd_ready (prep_wr_cmd_ready),
    .data_in       (prep_wr_data),
    .data_in_keep  ({AXI_STRB_LEN{1'b1}}),
    .data_in_valid (prep_wr_valid),
    .data_in_last  (),
    .data_in_ready (prep_wr_ready),
    .m_axi_awid    (prep2_axi_awid),
    .m_axi_awaddr  (prep2_axi_awaddr),
    .m_axi_awlen   (prep2_axi_awlen),
    .m_axi_awsize  (prep2_axi_awsize),
    .m_axi_awburst (prep2_axi_awburst),
    .m_axi_awlock  (prep2_axi_awlock),
    .m_axi_awcache (prep2_axi_awcache),
    .m_axi_awprot  (prep2_axi_awprot),
    .m_axi_awvalid (prep2_axi_awvalid),
    .m_axi_awready (prep2_axi_awready),
    .m_axi_wdata   (prep2_axi_wdata),
    .m_axi_wstrb   (prep2_axi_wstrb),
    .m_axi_wlast   (prep2_axi_wlast),
    .m_axi_wvalid  (prep2_axi_wvalid),
    .m_axi_wready  (prep2_axi_wready),
    .m_axi_bid     (prep2_axi_bid),
    .m_axi_bresp   (prep2_axi_bresp),
    .m_axi_bvalid  (prep2_axi_bvalid),
    .m_axi_bready  (prep2_axi_bready)
);
// =================== preprocess datapath end ===================


/////////////////////////////////////////////////////////////////////////////////////////////
wire [6:0]   npu_reg_axi_awid    /*synthesis PAP_MARK_DEBUG="1"*/;
wire [31:0]             npu_reg_axi_awaddr  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [7:0]              npu_reg_axi_awlen   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              npu_reg_axi_awsize  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              npu_reg_axi_awburst /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_awlock  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [3:0]              npu_reg_axi_awcache /*synthesis PAP_MARK_DEBUG="1"*/;
wire [2:0]              npu_reg_axi_awprot  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_awvalid /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_awready /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_DATA_LEN-1:0] npu_reg_axi_wdata   /*synthesis PAP_MARK_DEBUG="1"*/;
wire [AXI_STRB_LEN-1:0] npu_reg_axi_wstrb   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_wlast   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_wvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_wready  /*synthesis PAP_MARK_DEBUG="1"*/;
wire [6:0]   npu_reg_axi_bid     /*synthesis PAP_MARK_DEBUG="1"*/;
wire [1:0]              npu_reg_axi_bresp   /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_bvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
wire                    npu_reg_axi_bready  /*synthesis PAP_MARK_DEBUG="1"*/;






    








    wire [AXI_ID_LEN-1:0]   npu_out_axi_awid    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [31:0]             npu_out_axi_awaddr  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [3:0]              npu_out_axi_awlen   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [2:0]              npu_out_axi_awsize  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [1:0]              npu_out_axi_awburst /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_awlock  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [3:0]              npu_out_axi_awcache /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [2:0]              npu_out_axi_awprot  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_awvalid /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_awready /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_DATA_LEN-1:0] npu_out_axi_wdata   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_STRB_LEN-1:0] npu_out_axi_wstrb   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_wlast   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_wvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_wready  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [AXI_ID_LEN-1:0]   npu_out_axi_bid     /*synthesis PAP_MARK_DEBUG="1"*/;
    wire [1:0]              npu_out_axi_bresp   /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_bvalid  /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                    npu_out_axi_bready  /*synthesis PAP_MARK_DEBUG="1"*/;


    wire    [AXI_ID_LEN-1:0]    npu_s0_axi_arid    ;
    wire    [31:0]              npu_s0_axi_araddr  ;
    wire    [3:0]               npu_s0_axi_arlen   ;
    wire    [2:0]               npu_s0_axi_arsize  ;
    wire    [1:0]               npu_s0_axi_arburst ;
    wire                        npu_s0_axi_arlock  ;
    wire    [3:0]               npu_s0_axi_arcache ;
    wire    [2:0]               npu_s0_axi_arprot  ;
    wire                        npu_s0_axi_arvalid ;
    wire                        npu_s0_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s0_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s0_axi_rdata   ;
    wire    [1:0]               npu_s0_axi_rresp   ;
    wire                        npu_s0_axi_rlast   ;
    wire                        npu_s0_axi_rvalid  ;
    wire                        npu_s0_axi_rready  ;


    wire    [AXI_ID_LEN-1:0]    npu_s1_axi_arid    ;
    wire    [31:0]              npu_s1_axi_araddr  ;
    wire    [3:0]               npu_s1_axi_arlen   ;
    wire    [2:0]               npu_s1_axi_arsize  ;
    wire    [1:0]               npu_s1_axi_arburst ;
    wire                        npu_s1_axi_arlock  ;
    wire    [3:0]               npu_s1_axi_arcache ;
    wire    [2:0]               npu_s1_axi_arprot  ;
    wire                        npu_s1_axi_arvalid ;
    wire                        npu_s1_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s1_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s1_axi_rdata   ;
    wire    [1:0]               npu_s1_axi_rresp   ;
    wire                        npu_s1_axi_rlast   ;
    wire                        npu_s1_axi_rvalid  ;
    wire                        npu_s1_axi_rready  ;






    wire    [AXI_ID_LEN-1:0]    npu_s2_axi_arid    ;
    wire    [31:0]              npu_s2_axi_araddr  ;
    wire    [3:0]               npu_s2_axi_arlen   ;
    wire    [2:0]               npu_s2_axi_arsize  ;
    wire    [1:0]               npu_s2_axi_arburst ;
    wire                        npu_s2_axi_arlock  ;
    wire    [3:0]               npu_s2_axi_arcache ;
    wire    [2:0]               npu_s2_axi_arprot  ;
    wire                        npu_s2_axi_arvalid ;
    wire                        npu_s2_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s2_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s2_axi_rdata   ;
    wire    [1:0]               npu_s2_axi_rresp   ;
    wire                        npu_s2_axi_rlast   ;
    wire                        npu_s2_axi_rvalid  ;
    wire                        npu_s2_axi_rready  ;






    wire    [AXI_ID_LEN-1:0]    npu_s3_axi_arid    ;
    wire    [31:0]              npu_s3_axi_araddr  ;
    wire    [3:0]               npu_s3_axi_arlen   ;
    wire    [2:0]               npu_s3_axi_arsize  ;
    wire    [1:0]               npu_s3_axi_arburst ;
    wire                        npu_s3_axi_arlock  ;
    wire    [3:0]               npu_s3_axi_arcache ;
    wire    [2:0]               npu_s3_axi_arprot  ;
    wire                        npu_s3_axi_arvalid ;
    wire                        npu_s3_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s3_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s3_axi_rdata   ;
    wire    [1:0]               npu_s3_axi_rresp   ;
    wire                        npu_s3_axi_rlast   ;
    wire                        npu_s3_axi_rvalid  ;
    wire                        npu_s3_axi_rready  ;






    wire    [AXI_ID_LEN-1:0]    npu_s4_axi_arid    ;
    wire    [31:0]              npu_s4_axi_araddr  ;
    wire    [3:0]               npu_s4_axi_arlen   ;
    wire    [2:0]               npu_s4_axi_arsize  ;
    wire    [1:0]               npu_s4_axi_arburst ;
    wire                        npu_s4_axi_arlock  ;
    wire    [3:0]               npu_s4_axi_arcache ;
    wire    [2:0]               npu_s4_axi_arprot  ;
    wire                        npu_s4_axi_arvalid ;
    wire                        npu_s4_axi_arready ;
    wire    [AXI_ID_LEN-1:0]    npu_s4_axi_rid     ;
    wire    [AXI_DATA_LEN-1:0]  npu_s4_axi_rdata   ;
    wire    [1:0]               npu_s4_axi_rresp   ;
    wire                        npu_s4_axi_rlast   ;
    wire                        npu_s4_axi_rvalid  ;
    wire                        npu_s4_axi_rready  ;


// Legacy FPGA NPU absent: deterministic inactive master requests.
// Response READY only drains stale responses; no command success is generated.
// S05 = cam1 KF history, S06 = delivery reads, M02 = delivery MMIO.
assign npu_out_axi_awid = 4'd0;
assign npu_out_axi_awaddr = 32'd0;
assign npu_out_axi_awlen = 4'd0;
assign npu_out_axi_awsize = 3'd0;
assign npu_out_axi_awburst = 2'd0;
assign npu_out_axi_awlock = 1'd0;
assign npu_out_axi_awcache = 4'd0;
assign npu_out_axi_awprot = 3'd0;
assign npu_out_axi_awvalid = 1'd0;
assign npu_out_axi_wdata = 128'd0;
assign npu_out_axi_wstrb = 16'd0;
assign npu_out_axi_wlast = 1'd0;
assign npu_out_axi_wvalid = 1'd0;
assign npu_out_axi_bready = 1'd1;
assign npu_s0_axi_arid = 4'd0;
assign npu_s0_axi_araddr = 32'd0;
assign npu_s0_axi_arlen = 4'd0;
assign npu_s0_axi_arsize = 3'd0;
assign npu_s0_axi_arburst = 2'd0;
assign npu_s0_axi_arlock = 1'd0;
assign npu_s0_axi_arcache = 4'd0;
assign npu_s0_axi_arprot = 3'd0;
assign npu_s0_axi_arvalid = 1'd0;
assign npu_s0_axi_rready = 1'd1;
assign npu_s1_axi_arid = 4'd0;
assign npu_s1_axi_araddr = 32'd0;
assign npu_s1_axi_arlen = 4'd0;
assign npu_s1_axi_arsize = 3'd0;
assign npu_s1_axi_arburst = 2'd0;
assign npu_s1_axi_arlock = 1'd0;
assign npu_s1_axi_arcache = 4'd0;
assign npu_s1_axi_arprot = 3'd0;
assign npu_s1_axi_arvalid = 1'd0;
assign npu_s1_axi_rready = 1'd1;
assign npu_s2_axi_arid = 4'd0;
assign npu_s2_axi_araddr = 32'd0;
assign npu_s2_axi_arlen = 4'd0;
assign npu_s2_axi_arsize = 3'd0;
assign npu_s2_axi_arburst = 2'd0;
assign npu_s2_axi_arlock = 1'd0;
assign npu_s2_axi_arcache = 4'd0;
assign npu_s2_axi_arprot = 3'd0;
assign npu_s2_axi_arvalid = 1'd0;
assign npu_s2_axi_rready = 1'd1;

// M02 (NPU register window) response inputs





wire   [6:0]   npu_reg_axi_rid;
wire   [AXI_DATA_LEN-1:0] npu_reg_axi_rdata;
wire   [1:0]              npu_reg_axi_rresp;
wire                      npu_reg_axi_rlast;
wire                      npu_reg_axi_rvalid;
wire                      npu_reg_axi_arready;







///////////////////////////////////////////////////////////////////////////////////////////
axi_crossbar_7x3 #(
    //.DATA_WIDTH(AXI_DATA_LEN)
    .DATA_WIDTH(AXI_DATA_LEN),
    // M00 (DDR3) �ķ���Ȩ�ޣ�
    // �� DDR: ���� PCIE(S00) �� NPU����ͨ��(S02-S06)����ֹ Camera(S01)
    .M00_CONNECT_READ  (7'b1111101), 
    // д DDR: ���� PCIE(S00), Camera(S01), NPU_S0(S02)����ֹ NPU_S1~S4(S03-S06)
    .M00_CONNECT_WRITE (7'b0000000),  // [WARB 2026-09-19] write path moved to ddr_w_arb
                                      // (crossbar M00 write leaked its W-channel select
                                      //  across handoffs -> permanent wedge; bench-proven)
    
    // M01 (OV5640 ���ƼĴ���) �ķ���Ȩ�ޣ�
    // ֻ�� PCIE (S00) ���Զ�д�������ж���������ͨ���ĸ���
    .M01_CONNECT_READ  (7'b0000001),
    .M01_CONNECT_WRITE (7'b0000001),
    
    // M02 (NPU ���ƼĴ���) �ķ���Ȩ�ޣ�
    // ֻ�� PCIE (S00) ���Զ�д
    .M02_CONNECT_READ  (7'b0000001),
    .M02_CONNECT_WRITE (7'b0000001)
)
axi_crossbar_7x3
(
    .clk(axi_clk),
    .rst(axi_rst),

    /*
     * AXI slave interface
     */
    .s00_axi_awid   (host_route_aw[60:57]) ,
    .s00_axi_awaddr (host_route_aw[56:25]) ,
    .s00_axi_awlen  (host_route_aw[24:17]) ,
    .s00_axi_awsize (host_route_aw[16:14]) ,
    .s00_axi_awburst(host_route_aw[13:12]) ,
    .s00_axi_awlock (host_route_aw[11]) ,
    .s00_axi_awcache(host_route_aw[10:7]) ,
    .s00_axi_awprot (host_route_aw[6:4]) ,
    .s00_axi_awqos  (host_route_aw[3:0]) ,
    .s00_axi_awvalid(host_route_awvalid[0]) ,
    .s00_axi_awready(host_route_awready[0]) ,
    .s00_axi_awuser () ,

    .s00_axi_wdata  (host_route_wdata[127:0]) ,
    .s00_axi_wstrb  (host_route_wstrb[15:0]) ,
    .s00_axi_wlast  (host_route_wlast[0]) ,
    .s00_axi_wready (host_route_wready[0]) ,
    .s00_axi_wvalid (host_route_wvalid[0]) ,
    .s00_axi_wuser  () ,

    .s00_axi_bid     (host_route_bid[3:0]),
    .s00_axi_bresp   (host_route_bresp[1:0]),
    .s00_axi_bvalid  (host_route_bvalid[0]),
    .s00_axi_bready  (host_route_bready[0]),
    .s00_axi_buser   (),

    .s00_axi_arid    (pcie_axi_arid   )     ,
    .s00_axi_araddr  (pcie_axi_araddr )     ,
    .s00_axi_arlen   (pcie_axi_arlen  )     ,
    .s00_axi_arsize  (pcie_axi_arsize )     ,
    .s00_axi_arburst (pcie_axi_arburst)     ,
    .s00_axi_arlock  (pcie_axi_arlock )     ,
    .s00_axi_arcache (pcie_axi_arcache)     ,
    .s00_axi_arprot  (pcie_axi_arprot )     ,
    .s00_axi_arqos   (pcie_axi_arqos  )     ,
    .s00_axi_arvalid (pcie_axi_arvalid)     ,
    .s00_axi_arready (pcie_axi_arready)     ,
    .s00_axi_aruser  (),

    .s00_axi_rid     (pcie_axi_rid    ),
    .s00_axi_rdata   (pcie_axi_rdata  ),
    .s00_axi_rresp   (pcie_axi_rresp  ),
    .s00_axi_rlast   (pcie_axi_rlast  ),
    .s00_axi_rvalid  (pcie_axi_rvalid ),
    .s00_axi_rready  (pcie_axi_rready ),
    .s00_axi_ruser   (),

    // [WARB] S01 write retired (camera DMAs go through ddr_w_arb)
    .s01_axi_awid    (4'd0               ),
    .s01_axi_awaddr  (32'd0              ),
    .s01_axi_awlen   (8'd0               ),
    .s01_axi_awsize  (3'd0               ),
    .s01_axi_awburst (2'd0               ),
    .s01_axi_awlock  (1'b0               ),
    .s01_axi_awcache (4'd0               ),
    .s01_axi_awprot  (3'd0               ),
    .s01_axi_awqos   (4'd0               ),
    .s01_axi_awvalid (1'b0               ),
    .s01_axi_awready (               ),
    .s01_axi_awuser  (               ),
    .s01_axi_wdata   (128'd0             ),
    .s01_axi_wstrb   (16'd0              ),
    .s01_axi_wlast   (1'b0               ),
    .s01_axi_wvalid  (1'b0               ),
    .s01_axi_wready  (               ),
    .s01_axi_wuser   (               ),
    .s01_axi_bid     (               ),
    .s01_axi_bresp   (               ),
    .s01_axi_bvalid  (               ),
    .s01_axi_bready  (1'b0               ),
    .s01_axi_buser   (               ),
    .s01_axi_arid    (4'd0               ),
    .s01_axi_araddr  (32'd0              ),
    .s01_axi_arlen   (8'd0               ),
    .s01_axi_arsize  (3'd0               ),
    .s01_axi_arburst (2'd0               ),
    .s01_axi_arlock  (1'b0               ),
    .s01_axi_arcache (4'd0               ),
    .s01_axi_arprot  (3'd0               ),
    .s01_axi_arqos   (4'd0               ),
    .s01_axi_aruser  (1'b0               ),
    .s01_axi_arvalid (1'b0               ),
    .s01_axi_arready (),
    .s01_axi_rid     (),
    .s01_axi_rdata   (),
    .s01_axi_rresp   (),
    .s01_axi_rlast   (),
    .s01_axi_ruser   (),
    .s01_axi_rvalid  (),
    .s01_axi_rready  (1'b0               ),

    .s02_axi_awid   (npu_out_axi_awid   ),
    .s02_axi_awaddr (npu_out_axi_awaddr ),
    .s02_axi_awlen  (npu_out_axi_awlen  ),
    .s02_axi_awsize (npu_out_axi_awsize ),
    .s02_axi_awburst(npu_out_axi_awburst),
    .s02_axi_awlock (npu_out_axi_awlock ),
    .s02_axi_awcache(npu_out_axi_awcache),
    .s02_axi_awprot (npu_out_axi_awprot ),
    .s02_axi_awqos  (4'd0),
    .s02_axi_awuser (),
    .s02_axi_awvalid(npu_out_axi_awvalid),
    .s02_axi_awready(npu_out_axi_awready),
    .s02_axi_wdata  (npu_out_axi_wdata  ),
    .s02_axi_wstrb  (npu_out_axi_wstrb  ),
    .s02_axi_wlast  (npu_out_axi_wlast  ),
    .s02_axi_wvalid (npu_out_axi_wvalid ),
    .s02_axi_wready (npu_out_axi_wready ),
    .s02_axi_wuser  (),
    .s02_axi_bid    (npu_out_axi_bid    ),
    .s02_axi_bresp  (npu_out_axi_bresp  ),
    .s02_axi_bvalid (npu_out_axi_bvalid ),
    .s02_axi_bready (npu_out_axi_bready ),
    .s02_axi_buser  (),

    .s02_axi_arid   (npu_s0_axi_arid    ),
    .s02_axi_araddr (npu_s0_axi_araddr  ),
    .s02_axi_arlen  (npu_s0_axi_arlen   ),
    .s02_axi_arsize (npu_s0_axi_arsize  ),
    .s02_axi_arburst(npu_s0_axi_arburst ),
    .s02_axi_arlock (npu_s0_axi_arlock  ),
    .s02_axi_arcache(npu_s0_axi_arcache ),
    .s02_axi_arprot (npu_s0_axi_arprot  ),
    .s02_axi_arqos  (4'd0),
    .s02_axi_aruser (),
    .s02_axi_arvalid(npu_s0_axi_arvalid ),
    .s02_axi_arready(npu_s0_axi_arready ),
    .s02_axi_rid    (npu_s0_axi_rid     ),
    .s02_axi_rdata  (npu_s0_axi_rdata   ),
    .s02_axi_rresp  (npu_s0_axi_rresp   ),
    .s02_axi_rlast  (npu_s0_axi_rlast   ),
    .s02_axi_rvalid (npu_s0_axi_rvalid  ),
    .s02_axi_rready (npu_s0_axi_rready  ),
    .s02_axi_ruser  (),

    .s03_axi_awid   (prep2_axi_awid   ),
    .s03_axi_awaddr (prep2_axi_awaddr ),
    .s03_axi_awlen  (prep2_axi_awlen  ),
    .s03_axi_awsize (prep2_axi_awsize ),
    .s03_axi_awburst(prep2_axi_awburst),
    .s03_axi_awlock (prep2_axi_awlock ),
    .s03_axi_awcache(prep2_axi_awcache),
    .s03_axi_awprot (prep2_axi_awprot ),
    .s03_axi_awqos  (4'd0),
    .s03_axi_awuser (),
    .s03_axi_awvalid(prep2_axi_awvalid),
    .s03_axi_awready(prep2_axi_awready),
    .s03_axi_wdata  (prep2_axi_wdata ),
    .s03_axi_wstrb  (prep2_axi_wstrb ),
    .s03_axi_wlast  (prep2_axi_wlast ),
    .s03_axi_wuser  (),
    .s03_axi_wvalid (prep2_axi_wvalid),
    .s03_axi_wready (prep2_axi_wready),
    .s03_axi_bid    (prep2_axi_bid   ),
    .s03_axi_bresp  (prep2_axi_bresp ),
    .s03_axi_buser  (),
    .s03_axi_bvalid (prep2_axi_bvalid),
    .s03_axi_bready (prep2_axi_bready),
    .s03_axi_arid   (npu_s1_axi_arid    ),
    .s03_axi_araddr (npu_s1_axi_araddr  ),
    .s03_axi_arlen  (npu_s1_axi_arlen   ),
    .s03_axi_arsize (npu_s1_axi_arsize  ),
    .s03_axi_arburst(npu_s1_axi_arburst ),
    .s03_axi_arlock (npu_s1_axi_arlock  ),
    .s03_axi_arcache(npu_s1_axi_arcache ),
    .s03_axi_arprot (npu_s1_axi_arprot  ),
    .s03_axi_arqos  (4'd0),
    .s03_axi_aruser (),
    .s03_axi_arvalid(npu_s1_axi_arvalid ),
    .s03_axi_arready(npu_s1_axi_arready ),
    .s03_axi_rid    (npu_s1_axi_rid     ),
    .s03_axi_rdata  (npu_s1_axi_rdata   ),
    .s03_axi_rresp  (npu_s1_axi_rresp   ),
    .s03_axi_rlast  (npu_s1_axi_rlast   ),
    .s03_axi_rvalid (npu_s1_axi_rvalid  ),
    .s03_axi_rready (npu_s1_axi_rready  ),
    .s03_axi_ruser  (),

    // [WARB] S04 write retired (cam2 DMA goes through ddr_w_arb)
    .s04_axi_awid   (4'd0            ),
    .s04_axi_awaddr (32'd0           ),
    .s04_axi_awlen  (8'd0            ),
    .s04_axi_awsize (3'd0            ),
    .s04_axi_awburst(2'd0            ),
    .s04_axi_awlock (1'b0            ),
    .s04_axi_awcache(4'd0            ),
    .s04_axi_awprot (3'd0            ),
    .s04_axi_awqos  (4'd0),
    .s04_axi_awuser (),
    .s04_axi_awvalid(1'b0            ),
    .s04_axi_awready(                ),
    .s04_axi_wdata  (128'd0          ),
    .s04_axi_wstrb  (16'd0           ),
    .s04_axi_wlast  (1'b0            ),
    .s04_axi_wuser  (),
    .s04_axi_wvalid (1'b0            ),
    .s04_axi_wready (                ),
    .s04_axi_bid    (                ),
    .s04_axi_bresp  (                ),
    .s04_axi_buser  (),
    .s04_axi_bvalid (                ),
    .s04_axi_bready (1'b0            ),
    .s04_axi_arid   (npu_s2_axi_arid    ),
    .s04_axi_araddr (npu_s2_axi_araddr  ),
    .s04_axi_arlen  (npu_s2_axi_arlen   ),
    .s04_axi_arsize (npu_s2_axi_arsize  ),
    .s04_axi_arburst(npu_s2_axi_arburst ),
    .s04_axi_arlock (npu_s2_axi_arlock  ),
    .s04_axi_arcache(npu_s2_axi_arcache ),
    .s04_axi_arprot (npu_s2_axi_arprot  ),
    .s04_axi_arqos  (4'd0),
    .s04_axi_aruser (),
    .s04_axi_arvalid(npu_s2_axi_arvalid ),
    .s04_axi_arready(npu_s2_axi_arready ),
    .s04_axi_rid    (npu_s2_axi_rid     ),
    .s04_axi_rdata  (npu_s2_axi_rdata   ),
    .s04_axi_rresp  (npu_s2_axi_rresp   ),
    .s04_axi_rlast  (npu_s2_axi_rlast   ),
    .s04_axi_rvalid (npu_s2_axi_rvalid  ),
    .s04_axi_rready (npu_s2_axi_rready  ),
    .s04_axi_ruser  (),

    .s05_axi_awid(),
    .s05_axi_awaddr(),
    .s05_axi_awlen(),
    .s05_axi_awsize(),
    .s05_axi_awburst(),
    .s05_axi_awlock(),
    .s05_axi_awcache(),
    .s05_axi_awprot(),
    .s05_axi_awqos(),
    .s05_axi_awuser(),
    .s05_axi_awvalid(),
    .s05_axi_awready(),
    .s05_axi_wdata(),
    .s05_axi_wstrb(),
    .s05_axi_wlast(),
    .s05_axi_wuser(),
    .s05_axi_wvalid(),
    .s05_axi_wready(),
    .s05_axi_bid(),
    .s05_axi_bresp(),
    .s05_axi_buser(),
    .s05_axi_bvalid(),
    .s05_axi_bready(),
    .s05_axi_arid   (npu_s3_axi_arid    ),
    .s05_axi_araddr (npu_s3_axi_araddr  ),
    .s05_axi_arlen  (npu_s3_axi_arlen   ),
    .s05_axi_arsize (npu_s3_axi_arsize  ),
    .s05_axi_arburst(npu_s3_axi_arburst ),
    .s05_axi_arlock (npu_s3_axi_arlock  ),
    .s05_axi_arcache(npu_s3_axi_arcache ),
    .s05_axi_arprot (npu_s3_axi_arprot  ),
    .s05_axi_arqos  (4'd0),
    .s05_axi_aruser (),
    .s05_axi_arvalid(npu_s3_axi_arvalid ),
    .s05_axi_arready(npu_s3_axi_arready ),
    .s05_axi_rid    (npu_s3_axi_rid     ),
    .s05_axi_rdata  (npu_s3_axi_rdata   ),
    .s05_axi_rresp  (npu_s3_axi_rresp   ),
    .s05_axi_rlast  (npu_s3_axi_rlast   ),
    .s05_axi_rvalid (npu_s3_axi_rvalid  ),
    .s05_axi_rready (npu_s3_axi_rready  ),
    .s05_axi_ruser  (),

    .s06_axi_awid(),
    .s06_axi_awaddr(),
    .s06_axi_awlen(),
    .s06_axi_awsize(),
    .s06_axi_awburst(),
    .s06_axi_awlock(),
    .s06_axi_awcache(),
    .s06_axi_awprot(),
    .s06_axi_awqos(),
    .s06_axi_awuser(),
    .s06_axi_awvalid(),
    .s06_axi_awready(),
    .s06_axi_wdata(),
    .s06_axi_wstrb(),
    .s06_axi_wlast(),
    .s06_axi_wuser(),
    .s06_axi_wvalid(),
    .s06_axi_wready(),
    .s06_axi_bid(),
    .s06_axi_bresp(),
    .s06_axi_buser(),
    .s06_axi_bvalid(),
    .s06_axi_bready(),
    .s06_axi_arid   (npu_s4_axi_arid    ),
    .s06_axi_araddr (npu_s4_axi_araddr  ),
    .s06_axi_arlen  (npu_s4_axi_arlen   ),
    .s06_axi_arsize (npu_s4_axi_arsize  ),
    .s06_axi_arburst(npu_s4_axi_arburst ),
    .s06_axi_arlock (npu_s4_axi_arlock  ),
    .s06_axi_arcache(npu_s4_axi_arcache ),
    .s06_axi_arprot (npu_s4_axi_arprot  ),
    .s06_axi_arqos  (4'd0),
    .s06_axi_aruser (),
    .s06_axi_arvalid(npu_s4_axi_arvalid ),
    .s06_axi_arready(npu_s4_axi_arready ),
    .s06_axi_rid    (npu_s4_axi_rid     ),
    .s06_axi_rdata  (npu_s4_axi_rdata   ),
    .s06_axi_rresp  (npu_s4_axi_rresp   ),
    .s06_axi_rlast  (npu_s4_axi_rlast   ),
    .s06_axi_rvalid (npu_s4_axi_rvalid  ),
    .s06_axi_rready (npu_s4_axi_rready  ),
    .s06_axi_ruser  (),

    /*
     * AXI master interface
     */
    // [WARB] M00 write parked: the arbiter drives the DDR write path now
    .m00_axi_awid    (arb2x_awid                     ),
    .m00_axi_awaddr  (arb2x_awaddr                   ),
    .m00_axi_awlen   (arb2x_awlen                    ),
    .m00_axi_awsize  (arb2x_awsize                   ),
    .m00_axi_awburst (arb2x_awburst                  ),
    .m00_axi_awlock  (arb2x_awlock                   ),
    .m00_axi_awcache (arb2x_awcache                  ),
    .m00_axi_awprot  (arb2x_awprot                   ),
    .m00_axi_awqos   (arb2x_awqos                    ),
    .m00_axi_awregion(),
    .m00_axi_awuser  (arb2x_awuser                   ),
    .m00_axi_awvalid (arb2x_awvalid                  ),
    .m00_axi_awready (1'b0                           ),  // never granted (write retired)
    .m00_axi_wdata   (arb2x_wdata                    ),
    .m00_axi_wstrb   (arb2x_wstrb                    ),
    .m00_axi_wlast   (arb2x_wlast                    ),
    .m00_axi_wuser   (arb2x_wuser                    ),
    .m00_axi_wvalid  (arb2x_wvalid                   ),
    .m00_axi_wready  (1'b0                           ),
    .m00_axi_bid     (                               ),
    .m00_axi_bresp   (                               ),
    .m00_axi_buser   (                               ),
    .m00_axi_bvalid  (                               ),
    .m00_axi_bready  (                               ),  // [WARB] crossbar out, unused: write retired
    .m00_axi_arid    (ddr_axi_aruser_id              ),
    .m00_axi_araddr  (ddr_axi_araddr                 ),
    .m00_axi_arlen   (ddr_axi_arlen                  ),
    .m00_axi_arsize  (ddr_axi_arsize                 ),
    .m00_axi_arburst (ddr_axi_arburst                ),
    .m00_axi_arlock  (ddr_axi_arlock                 ),
    .m00_axi_arcache (ddr_axi_arcache                ),
    .m00_axi_arprot  (ddr_axi_arprot                 ),
    .m00_axi_arqos   (ddr_axi_arqos                  ),
    .m00_axi_arregion(),
    .m00_axi_aruser  (ddr_axi_aruser                 ),
    .m00_axi_arvalid (ddr_axi_arvalid                ),
    .m00_axi_arready (ddr_axi_arready_xbar           ),  // [ARFIX] ack at latch
    .m00_axi_rid     (ddr_axi_rid                    ),
    .m00_axi_rdata   (ddr_axi_rdata                  ),
    .m00_axi_rresp   (2'b00                          ),
    .m00_axi_rlast   (ddr_axi_rlast                  ),
    .m00_axi_ruser   (ddr_axi_ruser                  ),
    .m00_axi_rvalid  (!ddr_axi_fifo_empty            ),
    .m00_axi_rready  (ddr_axi_rready                 ),





    .m01_axi_awid    (ovreg_axi_awid     ),
    .m01_axi_awaddr  (ovreg_axi_awaddr   ),
    .m01_axi_awlen   (ovreg_axi_awlen    ),
    .m01_axi_awsize  (ovreg_axi_awsize   ),
    .m01_axi_awburst (ovreg_axi_awburst  ),
    .m01_axi_awlock  (ovreg_axi_awlock   ),
    .m01_axi_awcache (ovreg_axi_awcache  ),
    .m01_axi_awprot  (ovreg_axi_awprot   ),
    .m01_axi_awqos   (ovreg_axi_awqos    ),
    .m01_axi_awregion(ovreg_axi_awregion),
    .m01_axi_awuser  (               ),
    .m01_axi_awvalid (ovreg_axi_awvalid  ),
    .m01_axi_awready (ovreg_axi_awready  ),
    .m01_axi_wdata   (ovreg_axi_wdata    ),
    .m01_axi_wstrb   (ovreg_axi_wstrb    ),
    .m01_axi_wlast   (ovreg_axi_wlast    ),
    .m01_axi_wuser   (               ),
    .m01_axi_wvalid  (ovreg_axi_wvalid   ),
    .m01_axi_wready  (ovreg_axi_wready   ),
    .m01_axi_bid     (ovreg_axi_bid      ),
    .m01_axi_bresp   (ovreg_axi_bresp    ),
    .m01_axi_buser   (               ),
    .m01_axi_bvalid  (ovreg_axi_bvalid   ),
    .m01_axi_bready  (ovreg_axi_bready   ),
    .m01_axi_arid    (ovreg_axi_arid     ),
    .m01_axi_araddr  (ovreg_axi_araddr   ),
    .m01_axi_arlen   (ovreg_axi_arlen    ),
    .m01_axi_arsize  (ovreg_axi_arsize   ),
    .m01_axi_arburst (ovreg_axi_arburst  ),
    .m01_axi_arlock  (ovreg_axi_arlock   ),
    .m01_axi_arcache (ovreg_axi_arcache  ),
    .m01_axi_arprot  (ovreg_axi_arprot   ),
    .m01_axi_arqos   (ovreg_axi_arqos    ),
    .m01_axi_arregion(ovreg_axi_arregion ),
    .m01_axi_aruser  (               ),
    .m01_axi_arvalid (ovreg_axi_arvalid  ),
    .m01_axi_arready (ovreg_axi_arready  ),
    .m01_axi_rid     (ovreg_axi_rid      ),
    .m01_axi_rdata   (ovreg_axi_rdata    ),
    .m01_axi_rresp   (ovreg_axi_rresp    ),
    .m01_axi_rlast   (ovreg_axi_rlast    ),
    .m01_axi_ruser   (              ),
    .m01_axi_rvalid  (ovreg_axi_rvalid   ),
    .m01_axi_rready  (ovreg_axi_rready   ),



    .m02_axi_awid    (npu_reg_axi_awid    ),
    .m02_axi_awaddr  (npu_reg_axi_awaddr  ),
    .m02_axi_awlen   (npu_reg_axi_awlen   ),
    .m02_axi_awsize  (npu_reg_axi_awsize  ),
    .m02_axi_awburst (npu_reg_axi_awburst ),
    .m02_axi_awlock  (npu_reg_axi_awlock  ),
    .m02_axi_awcache (npu_reg_axi_awcache ),
    .m02_axi_awprot  (npu_reg_axi_awprot  ),
    .m02_axi_awqos   (npu_reg_axi_awqos   ),
    .m02_axi_awregion(npu_reg_axi_awregion),
    .m02_axi_awvalid (npu_reg_axi_awvalid ),
    .m02_axi_awready (npu_reg_axi_awready ),
    .m02_axi_awuser  (  ),
    .m02_axi_wdata   (npu_reg_axi_wdata   ),
    .m02_axi_wstrb   (npu_reg_axi_wstrb   ),
    .m02_axi_wlast   (npu_reg_axi_wlast   ),
    .m02_axi_wvalid  (npu_reg_axi_wvalid  ),
    .m02_axi_wready  (npu_reg_axi_wready  ),
    .m02_axi_wuser   (  ),
    .m02_axi_bid     (npu_reg_axi_bid     ),
    .m02_axi_bresp   (npu_reg_axi_bresp   ),
    .m02_axi_bvalid  (npu_reg_axi_bvalid  ),
    .m02_axi_bready  (npu_reg_axi_bready  ),
    .m02_axi_buser   (  ),
    .m02_axi_arid    (npu_reg_axi_arid    ),
    .m02_axi_araddr  (npu_reg_axi_araddr  ),
    .m02_axi_arlen   (npu_reg_axi_arlen   ),
    .m02_axi_arsize  (npu_reg_axi_arsize  ),
    .m02_axi_arburst (npu_reg_axi_arburst ),
    .m02_axi_arlock  (npu_reg_axi_arlock  ),
    .m02_axi_arcache (npu_reg_axi_arcache ),
    .m02_axi_arprot  (npu_reg_axi_arprot  ),
    .m02_axi_arqos   (npu_reg_axi_arqos   ),
    .m02_axi_arregion(npu_reg_axi_arregion),
    .m02_axi_arvalid (npu_reg_axi_arvalid ),
    .m02_axi_arready (npu_reg_axi_arready ),
    .m02_axi_aruser  (  ),
    .m02_axi_rid     (npu_reg_axi_rid     ),
    .m02_axi_rdata   (npu_reg_axi_rdata   ),
    .m02_axi_rresp   (npu_reg_axi_rresp   ),
    .m02_axi_rlast   (npu_reg_axi_rlast   ),
    .m02_axi_ruser   (  ),
    .m02_axi_rvalid  (npu_reg_axi_rvalid  ),
    .m02_axi_rready  (npu_reg_axi_rready  )  




);

// S06 is shared between host delivery and the on-FPGA BEV replay engine.
// A request is owned until RLAST, so the single-ID DDR bridge can never mix
// responses. BEV uses ID e; host delivery retains ID d.
wire bev_read_req_valid,bev_read_req_ready,bev_read_rsp_valid,bev_read_rsp_ready;
wire [31:0] bev_read_req_addr;
reg bev_bus_owner; // 0=delivery, 1=BEV; held until RLAST
wire bev_bus_complete=npu_s4_axi_rvalid && npu_s4_axi_rlast && npu_s4_axi_rready;
always @(posedge axi_clk) begin
 if(axi_rst) bev_bus_owner<=0;
 else if(bev_bus_complete) bev_bus_owner<=0;
 else if(bev_read_req_valid && !delivery_arvalid) bev_bus_owner<=1;
end
wire bev_engine_active=(bev_bus_owner || (bev_read_req_valid && !delivery_arvalid));
assign npu_s4_axi_arid=bev_engine_active?4'he:4'hd;
assign npu_s4_axi_araddr=bev_engine_active?bev_read_req_addr:delivery_araddr;
assign npu_s4_axi_arlen=bev_engine_active?4'd0:delivery_arlen[3:0];
assign npu_s4_axi_arsize=delivery_arsize;
assign npu_s4_axi_arburst=delivery_arburst;
assign npu_s4_axi_arvalid=(bev_engine_active && bev_read_req_valid) || (!bev_engine_active && delivery_arvalid);
assign npu_s4_axi_rready=bev_engine_active?bev_read_rsp_ready:delivery_rready;
assign npu_s4_axi_arlock=0;
assign npu_s4_axi_arcache=0;
assign npu_s4_axi_arprot=0;
assign delivery_arready=npu_s4_axi_arready && !bev_engine_active;
assign bev_read_req_ready=npu_s4_axi_arready && bev_engine_active;
assign delivery_rdata=npu_s4_axi_rdata;
assign delivery_rresp=npu_s4_axi_rresp;
assign delivery_rlast=npu_s4_axi_rlast;
assign delivery_rvalid=npu_s4_axi_rvalid && (npu_s4_axi_rid==4'hd);
assign bev_read_rsp_valid=npu_s4_axi_rvalid && (npu_s4_axi_rid==4'he);

wire [31:0] bev_control,bev_status,bev_generation,bev_sequence;
wire [15:0] bev_valid,bev_half,bev_candidates,bev_strength;
wire signed [31:0] bev_a,bev_b,bev_c;
wire [31:0] bev_debug_count,bev_debug_state;
wire [31:0] bev_dash_left,bev_dash_right;
wire signed [31:0] bev_left_a,bev_left_b,bev_left_c,bev_right_a,bev_right_b,bev_right_c;
wire [15:0] bev_left_n,bev_left_strength,bev_right_n,bev_right_strength;
native_bev_lane_engine native_bev_u(
 .clk(axi_clk),.rst(axi_rst),.native_active(native_active_axi),.native_mode(native_mode_axi),
 .c5_commit(c5_commit5),.c5_bank(c5_bank5),.c5_base(c5_commit_base5),
 .c5_generation(c5_ce5),.c5_sequence(c5_cs5),
 .c6_commit(c5_commit6),.c6_bank(c5_bank6),.c6_base(c5_commit_base6),
 .c6_generation(c5_ce6),.c6_sequence(c5_cs6),.control(bev_control),
 .status(bev_status),.result_generation(bev_generation),.result_sequence(bev_sequence),
 .result_valid(bev_valid),.result_half(bev_half),.result_candidates(bev_candidates),
 .result_strength(bev_strength),.result_a(bev_a),.result_b(bev_b),.result_c(bev_c),
 .req_valid(bev_read_req_valid),.req_ready(bev_read_req_ready),.req_addr(bev_read_req_addr),
 .rsp_valid(bev_read_rsp_valid),.rsp_ready(bev_read_rsp_ready),.rsp_data(npu_s4_axi_rdata),
 .debug_count(bev_debug_count),.debug_state(bev_debug_state),
 .result_dash_left(bev_dash_left),.result_dash_right(bev_dash_right),
 .result_left_a(bev_left_a),.result_left_b(bev_left_b),.result_left_c(bev_left_c),
 .result_right_a(bev_right_a),.result_right_b(bev_right_b),.result_right_c(bev_right_c),
 .result_left_n(bev_left_n),.result_left_strength(bev_left_strength),
 .result_right_n(bev_right_n),.result_right_strength(bev_right_strength));
native_bev_result_regs native_bev_regs_u(
 .clk(axi_clk),.rst(axi_rst),
 .address(c5_mail_araddr[8:0]),.waddr(c5_mail_awaddr[8:0]),
 .wdata(c5_mail_wdata),.write_enable(native_bev_control_write),
 .control(bev_control),.status(bev_status),.result_generation(bev_generation),
 .result_sequence(bev_sequence),.result_valid(bev_valid),.result_half(bev_half),
 .result_candidates(bev_candidates),.result_strength(bev_strength),
 .result_a(bev_a),.result_b(bev_b),.result_c(bev_c),
 .result_dash_left(bev_dash_left),.result_dash_right(bev_dash_right),
 .result_left_a(bev_left_a),.result_left_b(bev_left_b),.result_left_c(bev_left_c),
 .result_right_a(bev_right_a),.result_right_b(bev_right_b),.result_right_c(bev_right_c),
 .result_left_n(bev_left_n),.result_left_strength(bev_left_strength),
 .result_right_n(bev_right_n),.result_right_strength(bev_right_strength),
 .debug_count(bev_debug_count),.debug_state(bev_debug_state),.rdata(native_bev_rdata));
// Raw quiet evidence is qualified for 32 disabled cycles in cam1 registers.
assign runtime_idle_raw = six_writer_idle & six_dma_idle & ~six_pending & ~six_flush &
    ~{cam6_cmd_valid,cam5_cmd_valid,cam4_cmd_valid,cam3_cmd_valid,cam2_cmd_valid,cam_cmd_valid} &
    ~{cam6_axi_awvalid,cam5_axi_awvalid,cam4_axi_awvalid,cam3_axi_awvalid,cam2_axi_awvalid,ov5640_axi_awvalid} &
    ~{cam6_axi_wvalid,cam5_axi_wvalid,cam4_axi_wvalid,cam3_axi_wvalid,cam2_axi_wvalid,ov5640_axi_wvalid} &
    ~{cam6_dma_abort,cam5_dma_abort,cam4_dma_abort,cam3_dma_abort,cam2_dma_abort,cam_dma_abort};
delivery_top_adapter delivery_u (
.clk(axi_clk),.rst(axi_rst),
.capture_hold(six_hold),.camera_prev_base(six_prev),.camera_bank0(six_bank0),
.camera_bank1(six_bank1),.camera_sequence(six_sequence),.camera_published(six_published),
.camera_writer_idle(six_writer_idle),.camera_pending(six_pending),.camera_flush(six_flush),
.camera_dma_idle(six_dma_idle),
.camera_cmd_valid({cam6_cmd_valid,cam5_cmd_valid,cam4_cmd_valid,cam3_cmd_valid,cam2_cmd_valid,cam_cmd_valid}),
.camera_awvalid({cam6_axi_awvalid,cam5_axi_awvalid,cam4_axi_awvalid,cam3_axi_awvalid,cam2_axi_awvalid,ov5640_axi_awvalid}),
.camera_wvalid({cam6_axi_wvalid,cam5_axi_wvalid,cam4_axi_wvalid,cam3_axi_wvalid,cam2_axi_wvalid,ov5640_axi_wvalid}),
.camera_abort({cam6_dma_abort,cam5_dma_abort,cam4_dma_abort,cam3_dma_abort,cam2_dma_abort,cam_dma_abort}),
.s_axi_awid(npu_reg_axi_awid),
.s_axi_awaddr(npu_reg_axi_awaddr),
.s_axi_awlen(npu_reg_axi_awlen),
.s_axi_awsize(npu_reg_axi_awsize),
.s_axi_awburst(npu_reg_axi_awburst),
.s_axi_awlock(npu_reg_axi_awlock),
.s_axi_awcache(npu_reg_axi_awcache),
.s_axi_awprot(npu_reg_axi_awprot),
.s_axi_awqos(npu_reg_axi_awqos),
.s_axi_awregion(npu_reg_axi_awregion),
.s_axi_awvalid(npu_reg_axi_awvalid),
.s_axi_awready(npu_reg_axi_awready),
.s_axi_wdata(npu_reg_axi_wdata),
.s_axi_wstrb(npu_reg_axi_wstrb),
.s_axi_wlast(npu_reg_axi_wlast),
.s_axi_wvalid(npu_reg_axi_wvalid),
.s_axi_wready(npu_reg_axi_wready),
.s_axi_bid(npu_reg_axi_bid),
.s_axi_bresp(npu_reg_axi_bresp),
.s_axi_bvalid(npu_reg_axi_bvalid),
.s_axi_bready(npu_reg_axi_bready),
.s_axi_arid(npu_reg_axi_arid),
.s_axi_araddr(npu_reg_axi_araddr),
.s_axi_arlen(npu_reg_axi_arlen),
.s_axi_arsize(npu_reg_axi_arsize),
.s_axi_arburst(npu_reg_axi_arburst),
.s_axi_arlock(npu_reg_axi_arlock),
.s_axi_arcache(npu_reg_axi_arcache),
.s_axi_arprot(npu_reg_axi_arprot),
.s_axi_arqos(npu_reg_axi_arqos),
.s_axi_arregion(npu_reg_axi_arregion),
.s_axi_arvalid(npu_reg_axi_arvalid),
.s_axi_arready(npu_reg_axi_arready),
.s_axi_rid(npu_reg_axi_rid),
.s_axi_rdata(npu_reg_axi_rdata),
.s_axi_rresp(npu_reg_axi_rresp),
.s_axi_rlast(npu_reg_axi_rlast),
.s_axi_rvalid(npu_reg_axi_rvalid),
.s_axi_rready(npu_reg_axi_rready),
.m_axi_araddr(delivery_araddr),
.m_axi_arlen(delivery_arlen),
.m_axi_arsize(delivery_arsize),
.m_axi_arburst(delivery_arburst),
.m_axi_arvalid(delivery_arvalid),
.m_axi_arready(delivery_arready),
.m_axi_rdata(delivery_rdata),
.m_axi_rresp(delivery_rresp),
.m_axi_rlast(delivery_rlast),
.m_axi_rvalid(delivery_rvalid),
.m_axi_rready(delivery_rready),
.m_axi_awaddr(delivery_awaddr),
.m_axi_awlen(delivery_awlen),
.m_axi_awsize(delivery_awsize),
.m_axi_awburst(delivery_awburst),
.m_axi_awvalid(delivery_awvalid),
.m_axi_awready(delivery_awready),
.m_axi_wdata(delivery_wdata),
.m_axi_wstrb(delivery_wstrb),
.m_axi_wlast(delivery_wlast),
.m_axi_wvalid(delivery_wvalid),
.m_axi_wready(delivery_wready),
.m_axi_bresp(delivery_bresp),
.m_axi_bvalid(delivery_bvalid),
.m_axi_bready(delivery_bready)
);

endmodule
