module c5_optical_runtime_pipe #(parameter TIMEOUT_CYCLES=500000000)(
 input wire clk,rst,rx_clk,rx_rst_n,link_ok,
 input wire [31:0] rxd,input wire [3:0] rxk,
 output wire tx_word_valid,input wire tx_word_ready,
 output wire [31:0] tx_word_data,output wire [3:0] tx_word_k,
 input wire [31:0] s_awaddr,input wire s_awvalid,output wire s_awready,
 input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wvalid,output wire s_wready,
 output wire [1:0] s_bresp,output wire s_bvalid,input wire s_bready,
 input wire [31:0] s_araddr,input wire s_arvalid,output wire s_arready,
 output wire [31:0] s_rdata,output wire [1:0] s_rresp,output wire s_rvalid,input wire s_rready,
 input wire optical_idle,output wire writer_hold,local_flush,hd,output wire [31:0] epoch,
 output wire vs5,hs5,de5,output wire [15:0] pix5,
 output wire vs6,hs6,de6,output wire [15:0] pix6,
 output wire [31:0] frame_sequence,
 // [DIAG 2026-10-22] C6 line-rate measurement, axi_clk domain (read-only).
 // c6_lines_per_frame: number of raster rows between two merged VS edges that
 //                     actually carried C6 pixels (de6 seen at least once).
 // c6_line_cycles:     axi_clk cycles between two consecutive such rows, i.e.
 //                     C6's own line period as observed at the receiver.
 output wire [31:0] c6_lines_per_frame,
 output wire [31:0] c6_line_cycles,
 input wire commit5,bank5,input wire [31:0] commit_epoch5,commit_sequence5,
 input wire commit6,bank6,input wire [31:0] commit_epoch6,commit_sequence6,
 output wire native_meta_valid,output wire [159:0] native_meta_payload,
 output wire native_meta_ok,
 output wire native_video_vs,output wire native_video_hs,output wire native_video_de,
 output wire [15:0] native_video_pix,
 input wire [31:0] native_descriptor_rdata,
 input wire [31:0] native_bev_rdata,
 output wire native_bev_write_pulse,
 // rx_clk domain: native splitter engaged; legacy splitter input is masked.
 input wire native_engaged,
 output wire native_deactivate,
 // rx_clk domain read-only counters (descriptor words 0x04/0x08/0x0C).
  output wire [95:0] native_diag,
  output wire [159:0] source_diag_snapshot
);
 wire runtime_axi_n,runtime_rx_n,epoch_reset_n;
 // Mode-switch settle window: a 480P<->720P commit restarts the remote raster
 // and the sender briefly stops emitting valid words. Treat link loss inside
 // this bounded window as recoverable; after it the original fail-closed
 // behaviour applies and a real outage still trips the mailbox timeout.
 localparam SETTLE_CYCLES=250000000; // 2 s at 125 MHz: hard cap for an aborted switch
 wire mailbox_busy;
  (* ASYNC_REG="TRUE" *) reg [1:0] busy_rx;
  (* ASYNC_REG="TRUE" *) reg [1:0] failed_rx;
 reg switch_settle;
 // The production 250M-cycle cap needs 28 bits; 26 bits wraps before expiry.
 reg [$clog2(SETTLE_CYCLES)-1:0] settle_timer;
 wire ingress_link_lost;
 wire ingress_link_fault;
 wire ingress_loss_clear;
 c5_runtime_reset reset_pair(.axi_clk(clk),.rx_clk(rx_clk),.axi_reset(rst),
  .raw_rx_reset_n(rx_rst_n),.axi_reset_n(runtime_axi_n),.rx_reset_n(runtime_rx_n),.epoch_reset_n(epoch_reset_n));
 wire runtime_rst=!runtime_axi_n;
 // Retain the anti-replay floor across DDR resets; raw SFP POR clears it.
 // No transaction, geometry or publication state survives a DDR reset.
 reg [31:0] epoch_floor;
 wire epoch_claim;wire [31:0] epoch_claim_value;
 always @(posedge clk or negedge epoch_reset_n) begin
  if(!epoch_reset_n) epoch_floor<=0;
  else if(runtime_axi_n && epoch_claim && epoch_claim_value>epoch_floor) epoch_floor<=epoch_claim_value;
 end
 wire mailbox_hold,mailbox_flush;
 wire mail_awready,mail_wready,mail_arready,mail_bvalid,mail_rvalid;
 wire [31:0] mail_rdata;
  wire native_read_page=s_araddr[31:9]==23'h100108;
  wire native_bev_page=s_araddr[31:9]==23'h100109;
  wire native_write_page=s_awaddr[31:9]==23'h100108;
  wire native_bev_write_page=s_awaddr[31:9]==23'h100109;
 reg native_read_valid,native_read_active;
 reg native_bev_read_valid,native_bev_read_active;
 reg native_bev_bvalid_q;
 wire native_bev_write_pulse=native_bev_write_page && s_awvalid && s_wvalid && s_awready && s_wready;
 always @(posedge clk or negedge runtime_axi_n) begin
  if(!runtime_axi_n) begin native_read_valid<=0;native_read_active<=0;native_bev_read_valid<=0;native_bev_read_active<=0;native_bev_bvalid_q<=0;end
  else begin
   if(native_read_page && s_arvalid && s_arready) begin native_read_valid<=1;native_read_active<=1;end
   else if(native_read_valid && s_rready) begin native_read_valid<=0;native_read_active<=0;end
   if(native_bev_page && s_arvalid && s_arready) begin native_bev_read_valid<=1;native_bev_read_active<=1;end
   else if(native_bev_read_valid && s_rready) begin native_bev_read_valid<=0;native_bev_read_active<=0;end
   if(native_bev_write_pulse) native_bev_bvalid_q<=1;
   else if(native_bev_bvalid_q && s_bready) native_bev_bvalid_q<=0;
  end
 end
 assign s_awready=runtime_axi_n && (native_bev_write_page ? 1'b1 : (mail_awready && !native_write_page));
 assign s_wready=runtime_axi_n && (native_bev_write_page ? 1'b1 : (mail_wready && !native_write_page));
 assign s_arready=runtime_axi_n && (native_read_page ? !native_read_valid : native_bev_page ? !native_bev_read_valid : mail_arready);
 assign s_bvalid=runtime_axi_n && (mail_bvalid || native_bev_bvalid_q);
 assign s_rvalid=runtime_axi_n && (native_read_active ? native_read_valid : native_bev_read_active ? native_bev_read_valid : mail_rvalid);
 assign s_rdata=native_read_active?native_descriptor_rdata:native_bev_read_active?native_bev_rdata:mail_rdata;
 assign s_rresp=0;
 assign writer_hold=!runtime_axi_n || mailbox_hold;
 assign local_flush=runtime_axi_n && mailbox_flush;
 wire cfg_valid,cfg_ready,cfg_take;wire [33:0] cfg_data,cfg_rx;
 reg cfg_seen;
 (* ASYNC_REG="TRUE" *) reg [2:0] codec_release;
 wire cfg_apply=cfg_take && !cfg_seen;
 wire cfg_ack=cfg_seen && codec_release[2];
 wire codec_rst_n=runtime_rx_n && codec_release[2];
 wire [31:0] ingress_data;wire [3:0] ingress_k;
 wire ingress_valid /* synthesis syn_keep=1 syn_maxfan=16 */;
 wire ingress_link /* synthesis syn_keep=1 syn_maxfan=16 */;
 wire ingress_loss,ingress_activity;
 c5_rx_ingress ingress(.clk(rx_clk),.rst_n(codec_rst_n),.link_ok(link_ok),.clear_loss(ingress_loss_clear),
  .data(rxd),.k(rxk),
  .word_data(ingress_data),.word_k(ingress_k),.word_valid(ingress_valid),.word_link(ingress_link),
  .direct_loss(ingress_loss),.pending_activity(ingress_activity));
 // Absorb the switch-time dip only: while the settle window is open AND the
 // link is currently good, the stored loss is released. Steady-state loss
 // (window closed) keeps latching exactly as before.
 assign ingress_loss_clear=switch_settle && ingress_link && ingress_valid;
 assign ingress_link_lost=(ingress_valid && !ingress_link) || ingress_loss;
 assign ingress_link_fault=ingress_link_lost && !switch_settle;
 wire cmd_valid,cmd_ready,cmd_rx_valid,cmd_rx_ready;wire [159:0] cmd_data,cmd_rx;
 wire response_valid,response_ready,response_axi_valid;wire [159:0] response_data,response_axi;
 wire raster_done;wire [31:0] raster_sequence;
 reg raster_done_tog;
 (* ASYNC_REG="TRUE" *) reg [2:0] raster_tog_rx;
 always @(posedge clk or negedge runtime_axi_n) begin
  if(!runtime_axi_n) raster_done_tog<=0;
  else if(raster_done) raster_done_tog<=~raster_done_tog;
 end
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) raster_tog_rx<=0;
  else raster_tog_rx<={raster_tog_rx[1:0],raster_done_tog};
 end
 wire raster_done_pulse=raster_tog_rx[2]^raster_tog_rx[1];
 wire health_valid,health_ready,health_rx_valid,health_rx_ready;
 wire [63:0] health_request,health_rx_request;
 wire health_rx_reply_valid,health_rx_reply_ready,health_reply_valid;
 wire [64:0] health_rx_reply,health_reply;
 wire [31:0] rx_verified_frontier;
 wire video_pending,video_vs,video_hs,video_de,video_meta;
 wire split_input_pending;
 wire [15:0] video_pix;
 c5_bundle_cdc #(.WIDTH(64)) health_request_cdc(
  .s_clk(clk),.s_rst_n(runtime_axi_n),.s_valid(health_valid),.s_ready(health_ready),.s_data(health_request),
  .d_clk(rx_clk),.d_rst_n(runtime_rx_n),.d_valid(health_rx_valid),.d_ready(health_rx_ready),.d_data(health_rx_request));
 c5_bundle_cdc #(.WIDTH(65)) health_reply_cdc(
  .s_clk(rx_clk),.s_rst_n(runtime_rx_n),.s_valid(health_rx_reply_valid),.s_ready(health_rx_reply_ready),.s_data(health_rx_reply),
  .d_clk(clk),.d_rst_n(runtime_axi_n),.d_valid(health_reply_valid),.d_ready(1'b1),.d_data(health_reply));
 reg rx_hold,rx_hd,rx_running;reg [31:0] rx_epoch,errors_q;reg packet_fault;
 reg [3:0] fault_seen; // sticky {meta_geom, resp_bp, unpack, err_delta}
 // Observation only: exact eligible terminal causes since the last HOLD.
 // [7] packet latch active outside settle, [6] raster outside settle,
 // [5] remote ERROR, [4] bad current META, [3] ingress loss outside settle,
 // [2] response backpressure, [1] unpack overflow, [0] non-running error delta.
 reg [7:0] terminal_causes;
 reg [1:0] settle_frames; // completed frames seen inside the settle window
 wire packet_active;wire [31:0] packet_errors;wire raster_fault,unpack_overflow;
 wire diag_ready,diag_valid;wire [31:0] diag_axi;
 reg [31:0] diag_sent,diagnostics;
 wire [5:0] fault_src={ingress_link_lost,switch_settle,fault_seen};
  wire native_response=response_valid && response_data[7:0]==2;
  wire source_diag_response=response_valid && response_data[7:0]==3 && response_data[15:8]==7;
  reg [31:0] source_diag_count;
  reg [127:0] source_diag_payload;
  assign source_diag_snapshot={source_diag_count,source_diag_payload};
  always @(posedge rx_clk or negedge runtime_rx_n) begin
   if(!runtime_rx_n) begin source_diag_count<=0;source_diag_payload<=0;end
   else if(source_diag_response) begin
    source_diag_count<=source_diag_count+1'b1;
    source_diag_payload<=response_data[159:32];
   end
  end
  wire legacy_response=response_valid && !native_response && !source_diag_response;
  wire [1:0] remote_tail=legacy_response && response_data[15:8]!=6 ? response_data[15:8] : 2'b11;
 // Mailbox phase is the single most useful field for "where did the switch stop";
 // export it so the host probe can see WAIT_READY vs WAIT_RUNNING vs VERIFY.
 wire [3:0] diag_phase;
 // A transaction is in flight while the sequencer is not IDLE and not FAILED.
 assign mailbox_busy=(diag_phase!=4'd0) && (diag_phase!=4'd13);
 always @(posedge rx_clk or negedge runtime_rx_n) begin
   if(!runtime_rx_n) begin busy_rx<=0;failed_rx<=0;end
   else begin
    busy_rx<={busy_rx[0],mailbox_busy};
    failed_rx<={failed_rx[0],diag_phase==4'd13};
   end
 end
 // rtl100 diagnostics (32 bits):
 //   31 !ingress_link | 30 any_fault | 29:28 last remote response type
 //   27:25 {resp_backpressure, settle_open, switch_flag} | 24:21 mailbox phase
 //   20:17 latched_fault_src | 16:9 packet_errors[7:0]
 //   8 rx_running | 7:0 terminal_causes (diagnostic revision 2)
 wire [31:0] diag_rx={!ingress_link,(raster_fault || unpack_overflow || packet_fault || ingress_link_fault),
   remote_tail,legacy_response && response_data[15:8]!=6 && !response_ready,switch_settle,raster_fault,
   diag_phase,fault_seen,packet_errors[7:0],rx_running,terminal_causes};
 c5_bundle_cdc #(.WIDTH(32)) diagnostic_cdc(
  .s_clk(rx_clk),.s_rst_n(runtime_rx_n),.s_valid(diag_rx!=diag_sent),.s_ready(diag_ready),.s_data(diag_rx),
  .d_clk(clk),.d_rst_n(runtime_axi_n),.d_valid(diag_valid),.d_ready(1'b1),.d_data(diag_axi));
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) diag_sent<=0;else if(diag_ready && diag_rx!=diag_sent) diag_sent<=diag_rx;
 end
 (* ASYNC_REG="TRUE" *) reg [1:0] fault_sync;
 wire rx_fault=((packet_fault || raster_fault || unpack_overflow) && !switch_settle)
  || ingress_link_fault;
 c5_rx_health_fence health_fence(.clk(rx_clk),.rst_n(runtime_rx_n),
  .request_valid(health_rx_valid),.request_ready(health_rx_ready),.request_data(health_rx_request),
  .epoch(rx_epoch),.verified_frontier(rx_verified_frontier),.error_count(packet_errors),
  .running(rx_running && !rx_hold),.packet_active(packet_active),
  .ordered_busy(video_pending || video_de || video_meta || response_valid || ingress_activity || split_input_pending),.packet_fault(packet_fault || ingress_link_fault),
  .raster_fault(raster_fault),.decode_fault(unpack_overflow),.link_ok(ingress_link && ingress_valid),
  .reply_valid(health_rx_reply_valid),.reply_ready(health_rx_reply_ready),.reply_data(health_rx_reply));
 always @(posedge clk or negedge runtime_axi_n) begin
  if(!runtime_axi_n) begin fault_sync<=0;diagnostics<=0;end
  else begin fault_sync<={fault_sync[0],rx_fault};if(diag_valid) diagnostics<=diag_axi;end
 end
 c5_bundle_cdc #(.WIDTH(34)) config_cdc(
  .s_clk(clk),.s_rst_n(runtime_axi_n),.s_valid(cfg_valid),.s_ready(cfg_ready),.s_data(cfg_data),
  .d_clk(rx_clk),.d_rst_n(runtime_rx_n),.d_valid(cfg_take),.d_ready(cfg_ack),.d_data(cfg_rx));
 // HOLD (cfg hold bit set) re-arms the codec and clears the window; ARM opens
 // it for the subsequent COMMIT/raster restart, then it expires on its own.
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) begin switch_settle<=0;settle_timer<=0;settle_frames<=0;end
  else if(cfg_apply) begin
   switch_settle<=!cfg_rx[0];
   settle_timer<=0;
   settle_frames<=0;
  end else if(switch_settle) begin
   // Close on the first completed frame of the new epoch, so steady-state loss
   // latches exactly as before; the timer is only a backstop for a switch that
   // never produces frames (the mailbox timeout is the final gate).
   settle_timer<=settle_timer+1'b1;
   if(raster_done_pulse && rx_running && settle_frames!=2'd3)
    settle_frames<=settle_frames+1'b1;
   // Hold the window until the mailbox leaves the transaction (published or
   // failed), so a dip after the first two frames cannot latch a terminal fault.
   if(!busy_rx[1] || settle_timer>=SETTLE_CYCLES-1) switch_settle<=0;
  end
 end
 c5_bundle_cdc #(.WIDTH(160)) command_cdc(
  .s_clk(clk),.s_rst_n(runtime_axi_n),.s_valid(cmd_valid),.s_ready(cmd_ready),.s_data(cmd_data),
  .d_clk(rx_clk),.d_rst_n(runtime_rx_n),.d_valid(cmd_rx_valid),.d_ready(cmd_rx_ready),.d_data(cmd_rx));
 c5_packet_tx packet_tx(.clk(rx_clk),.rst_n(codec_rst_n),.in_valid(cmd_rx_valid),.in_ready(cmd_rx_ready),
  .in_payload(cmd_rx),.out_valid(tx_word_valid),.out_ready(tx_word_ready),.out_data(tx_word_data),.out_k(tx_word_k));
 wire native_ok,native_bad;
 c5_packet_rx #(.ALIGN_BYTES(0)) packet_rx(.clk(rx_clk),.rst_n(codec_rst_n),.link_ok(ingress_link),
  .in_valid(ingress_valid),.in_data(ingress_data),.in_k(ingress_k),.out_valid(response_valid),.out_payload(response_data),
  .error_count(packet_errors),.packet_active(packet_active),
  .native_ok(native_ok),.native_bad(native_bad));
 c5_bundle_cdc #(.WIDTH(160)) response_cdc(
   .s_clk(rx_clk),.s_rst_n(runtime_rx_n),.s_valid(legacy_response && response_data[15:8]!=6),
  .s_ready(response_ready),.s_data(response_data),
  .d_clk(clk),.d_rst_n(runtime_axi_n),.d_valid(response_axi_valid),.d_ready(1'b1),.d_data(response_axi));
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) begin cfg_seen<=0;codec_release<=0;end
  else begin
   codec_release<={codec_release[1:0],1'b1};
   if(!cfg_take) cfg_seen<=0;
   if(cfg_apply) begin
    cfg_seen<=1;
    // This hold request is issued only after both AXI writers/DMA ledgers drain.
    // Assert codec reset locally, release synchronously, THEN acknowledge hold.
    if(cfg_rx[0]) codec_release<=0;
   end
  end
 end
 wire response_geometry_ok=response_data[7:0]==1 && response_data[23:16]==5 &&
  response_data[63:32]==rx_epoch &&
  response_data[79:64]==(rx_hd?16'd1280:16'd640) &&
  response_data[95:80]==(rx_hd?16'd720:16'd480) &&
   response_data[111:96]==640 && response_data[127:112]==480;
 wire native_meta_geometry=native_response && response_data[15:8]==6 &&
   response_data[23:16]==5 && response_data[31:26]==0 &&
   ((response_data[25:24]==2 && response_data[79:64]==1280 && response_data[95:80]==480) ||
    (response_data[25:24]==3 && response_data[79:64]==1280 && response_data[95:80]==960)) &&
   response_data[63:32]!=0 && response_data[159:128]!=0;
 wire [7:0] terminal_events={
  packet_fault && !switch_settle,
  raster_fault && !switch_settle,
  response_valid && response_geometry_ok && response_data[15:8]==5,
  response_valid && response_data[15:8]==6 && response_data[7:0]==1 &&
   response_data[63:32]==rx_epoch && !response_geometry_ok,
  ingress_link_fault,
   legacy_response && response_data[15:8]!=6 && !response_ready && !switch_settle,
  unpack_overflow && !switch_settle,
  packet_errors!=errors_q && !rx_running && !switch_settle};
 // Do not reset this evidence with codec_rst_n: a codec counter reset itself
 // can produce a delta, and must remain distinguishable from the fault cause.
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) terminal_causes<=0;
  else if(cfg_apply && cfg_rx[0]) terminal_causes<=0;
  else terminal_causes<=terminal_causes | terminal_events;
 end
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) begin rx_hold<=1;rx_hd<=0;rx_epoch<=0;rx_running<=0;packet_fault<=0;errors_q<=0;fault_seen<=0;end
  else begin
   errors_q<=packet_errors;
   if(packet_errors!=errors_q) fault_seen[0]<=1;
   if(unpack_overflow) fault_seen[1]<=1;
    if(legacy_response && response_data[15:8]!=6 && !response_ready) fault_seen[2]<=1;
   // A packet still carrying the previous epoch is stale, not corrupt: after
   // COMMIT the sender's in-flight META names the old epoch. Only a
   // current-epoch packet with wrong geometry is a protocol fault.
   if(response_valid && response_data[15:8]==6 && response_data[7:0]==1 &&
      response_data[63:32]==rx_epoch && !response_geometry_ok) begin fault_seen[3]<=1;packet_fault<=1;end
   // A packet error while STREAMING is a dropped/resynced frame, not a
   // terminal transport fault: keep counting it (fault_seen[0]) but do not
   // latch packet_fault. During the transaction (rx_running==0) the original
   // fail-closed rule is preserved bit-for-bit, so handshake semantics are
   // unchanged. Overflow, response backpressure, link loss, bad geometry and
   // error responses still fault exactly as before.
   // The ARM->RUNNING reconfiguration is a settle-window event, not a
   // transport failure: the sender restarts its raster there, so packet
   // errors are expected. Gate the delta term on !switch_settle as well,
   // otherwise a 720p switch latches 0x1002 after it already published.
   if((((((packet_errors!=errors_q) && !rx_running && !switch_settle) || unpack_overflow) ||
       (legacy_response && response_data[15:8]!=6 && !response_ready)) && !switch_settle) ||
      (ingress_link_fault && rx_epoch!=0)) packet_fault<=1;
   if(response_valid && response_geometry_ok) begin
    if(response_data[15:8]==4 && !rx_hold) rx_running<=1;
    if(response_data[15:8]==5) begin packet_fault<=1;rx_running<=0;end
   end
   if(!codec_release[2]) begin packet_fault<=0;errors_q<=0;end
   if(cfg_apply) begin
    rx_hold<=cfg_rx[0];rx_hd<=cfg_rx[1];rx_epoch<=cfg_rx[33:2];rx_running<=0;
    if(cfg_rx[0]) begin packet_fault<=0;fault_seen<=0;end
   end
    else if(native_ok && rx_hold && !cfg_take && !busy_rx[1] && failed_rx[1]) rx_hold<=0;
  end
 end
 // [ROUTING/DIAG 2026-10-31] A qualified native META (CRC good, type 2) releases
 // the receiver hold on its own, so native HDMI no longer needs the mailbox ARM.
  // REQUIRE_REQUEST starts in FAILED, also permitting cold native startup. Only
  // FAILED permits recovery at a nonzero epoch: IDLE/active transaction holds
  // are not abandoned. The synchronized phase and pending config gate keep HOLD
  // authoritative; the legacy writer hold, epoch and publication remain intact.
 reg [15:0] cnt_pkt,cnt_nok,cnt_nbad;
 always @(posedge rx_clk or negedge runtime_rx_n) begin
  if(!runtime_rx_n) begin cnt_pkt<=0;cnt_nok<=0;cnt_nbad<=0;end
  else begin
   if(response_valid) cnt_pkt<=cnt_pkt+1'b1;
   if(native_ok) cnt_nok<=cnt_nok+1'b1;
   if(native_bad) cnt_nbad<=cnt_nbad+1'b1;
  end
 end
 // word0 [15:0] packet_errors, [31:16] packets; word1 nok|nbad; word2 status
 assign native_diag={16'd0,5'd0,rx_hold,ingress_link,packet_fault,unpack_overflow,diag_phase[3:0],rx_running,rx_hd,1'b0,
  cnt_nbad,cnt_nok,cnt_pkt,packet_errors[15:0]};
 wire [159:0] video_meta_payload;
 // Native META enters the same ordered symbol FIFO as video.
 assign native_meta_valid=video_meta && video_meta_payload[7:0]==2;
 assign native_meta_payload=video_meta_payload;
 assign native_video_vs=video_vs;
 assign native_video_hs=video_hs;
 assign native_video_de=video_de;
 assign native_video_pix=video_pix;
 // A legacy camera META or a receiver HOLD ends native mode.
 assign native_deactivate=rx_hold || (video_meta && video_meta_payload[7:0]==1);
 // ALIGN_BYTES=0 packet_active includes START combinationally. Mask the same
 // word, including END and malformed symbols, BEFORE the timing decoder.
 c5_video_rx video_rx(.i_clk(rx_clk),.i_rst_n(runtime_rx_n && !rx_hold),.i_en(ingress_link && ingress_valid),
  .i_meta_valid(response_valid && ((response_data[15:8]==6 && response_geometry_ok) || native_meta_geometry)),.o_meta_valid(video_meta),
   .i_meta_payload(response_data),.o_meta_payload(video_meta_payload),.o_native_meta_ok(native_meta_ok),
  .o_pending(video_pending),
  .i_rxd(ingress_data),.i_rxk(packet_active?4'hf:ingress_k),
  .o_vs(video_vs),.o_hs(video_hs),.o_de(video_de),.o_pix(video_pix),.o_overflow(unpack_overflow));
 c5_raster_split_pipe split(.rx_clk(rx_clk),.rx_rst_n(runtime_rx_n),.hold(rx_hold),.hd_in(rx_hd),
  .run_in(rx_running && !packet_fault),.settle_in(switch_settle),.epoch_in(rx_epoch),.input_pending(split_input_pending),
  .meta_valid_in(video_meta && video_meta_payload[7:0]==1),.meta_payload_in(video_meta_payload),
  .vs_in(video_vs && !native_engaged),.hs_in(video_hs && !native_engaged),.de_in(video_de && !native_engaged),
  .pix_in(video_pix),.fault(raster_fault),.rx_verified_frontier(rx_verified_frontier),
  .axi_clk(clk),.axi_rst_n(runtime_axi_n && !local_flush),
  .vs5(vs5),.hs5(hs5),.de5(de5),.pix5(pix5),.vs6(vs6),.hs6(hs6),.de6(de6),.pix6(pix6),
  .frame_sequence(frame_sequence),.raster_done(raster_done),.raster_sequence(raster_sequence));
 // [DIAG 2026-10-22] C6 line-rate measurement (read-only, prep_regs only).
 // vs6/hs6 are the merged raster; de6 marks native C6 pixels, so the module
 // counts C6-bearing rows per frame and the gap between them in axi_clk.
 // Kept nets: the only consumer of these two words is the prep_regs read mux,
 // whose value folds to a constant if these are cut first, which makes ADS then
 // delete the mux ports as well (measured: DFF total unchanged, diag_* ports
 // pruned). syn_keep stops that fixpoint from deleting the measurement.
 wire [31:0] c6_lines_keep /* synthesis syn_keep=1 syn_maxfan=16 */;
 wire [31:0] c6_cycles_keep /* synthesis syn_keep=1 syn_maxfan=16 */;
 c5_c6_line_rate c6_rate(.clk(clk),.rst_n(runtime_axi_n),
  .vs(vs6),.hs(hs6),.de(de6),
  .lines_per_frame(c6_lines_keep),.line_cycles(c6_cycles_keep));
 assign c6_lines_per_frame = c6_lines_keep;
 assign c6_line_cycles     = c6_cycles_keep;
 c5_mailbox #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES),.REQUIRE_REQUEST(1)) mailbox(
  .clk(clk),.rst(runtime_rst),.reset_epoch_floor(epoch_floor),.epoch_claim(epoch_claim),.epoch_claim_value(epoch_claim_value),
  .s_awaddr(s_awaddr),.s_awvalid(s_awvalid && runtime_axi_n && !native_write_page && !native_bev_write_page),.s_awready(mail_awready),
  .s_wdata(s_wdata),.s_wstrb(s_wstrb),.s_wvalid(s_wvalid && runtime_axi_n && !native_write_page && !native_bev_write_page),.s_wready(mail_wready),
  .s_bresp(s_bresp),.s_bvalid(mail_bvalid),.s_bready(s_bready),
  .s_araddr(s_araddr),.s_arvalid(s_arvalid && runtime_axi_n && !native_read_page && !native_bev_page),.s_arready(mail_arready),
  .s_rdata(mail_rdata),.s_rresp(),.s_rvalid(mail_rvalid),.s_rready(s_rready),
  .optical_idle(optical_idle),.transport_fault(fault_sync[1]),.diagnostics(diagnostics),
  .writer_hold(mailbox_hold),.local_flush(mailbox_flush),.hd(hd),.epoch(epoch),
  .cfg_valid(cfg_valid),.cfg_ready(cfg_ready),.cfg_data(cfg_data),
  .tx_valid(cmd_valid),.tx_ready(cmd_ready),.tx_payload(cmd_data),
  .remote_valid(response_axi_valid),.remote_payload(response_axi),
  .health_valid(health_valid),.health_ready(health_ready),.health_request(health_request),
  .health_reply_valid(health_reply_valid),.health_reply(health_reply),
  .raster_done(raster_done),.raster_sequence(raster_sequence),
  .commit5(commit5),.bank5(bank5),.commit_epoch5(commit_epoch5),.commit_sequence5(commit_sequence5),
  .commit6(commit6),.bank6(bank6),.commit_epoch6(commit_epoch6),.commit_sequence6(commit_sequence6),
 .dbg_phase(diag_phase));
endmodule
