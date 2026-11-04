// ABI v1. No success until remote READY/RUNNING, raster verification, and
// actual tag-B-response commits to BOTH banks of BOTH optical writers.
module c5_mailbox #(parameter TIMEOUT_CYCLES=500000000,parameter REQUIRE_REQUEST=0)(
 input wire clk,rst,
 input wire [31:0] reset_epoch_floor,
 (* syn_maxfan = 4 *) output wire epoch_claim,
 output wire [31:0] epoch_claim_value,
 input wire [31:0] s_awaddr,input wire s_awvalid,output wire s_awready,
 input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wvalid,output wire s_wready,
 output reg [1:0] s_bresp,output reg s_bvalid,input wire s_bready,
 input wire [31:0] s_araddr,input wire s_arvalid,output wire s_arready,
 output reg [31:0] s_rdata,output reg [1:0] s_rresp,output reg s_rvalid,input wire s_rready,
 input wire optical_idle,transport_fault,input wire [31:0] diagnostics,
 output wire writer_hold,output reg local_flush,output reg hd,
 (* syn_maxfan = 8 *) output reg [31:0] epoch,
 output wire cfg_valid,input wire cfg_ready,output wire [33:0] cfg_data,
 output wire tx_valid,input wire tx_ready,output wire [159:0] tx_payload,
 input wire remote_valid,input wire [159:0] remote_payload,
 output wire health_valid,input wire health_ready,output wire [63:0] health_request,
 input wire health_reply_valid,input wire [64:0] health_reply,
 input wire raster_done,input wire [31:0] raster_sequence,
 input wire commit5,bank5,input wire [31:0] commit_epoch5,commit_sequence5,
 input wire commit6,bank6,input wire [31:0] commit_epoch6,commit_sequence6,
 output wire [3:0] dbg_phase
);

 localparam IDLE=0,DRAIN=1,HOLD_SEND=2,HOLD_WAIT=3,SET_SEND=4,SET_WAIT=5,
 WAIT_READY=6,ARM_SEND=7,ARM_WAIT=8,COMMIT_SEND=9,COMMIT_WAIT=10,
 WAIT_RUNNING=11,VERIFY=12,FAILED=13,HEALTH_SEND=14,HEALTH_WAIT=15;
 reg [31:0] fence_frontier;
 reg [3:0] phase;reg [2:0] state;
 // Read-only sequencer observation for diagnostics; no protocol meaning.
 assign dbg_phase=phase;
 reg requested_mode,effective_mode;reg [31:0] transaction,completed,effective_epoch,published_epoch,error_code,generation;
 reg [31:0] timer,frontier,accepted_frames;
 // SET->READY needs a full sensor reconfiguration (~200 ms); RUNNING is an
 // immediate reply, so its retry interval is much shorter.
 // SET->READY needs the sender's ~200 ms SCCB reconfiguration and a SET that
 // lands in CONFIG/HOLD is answered with silence, so the interval must clear it.
 localparam SET_RETRY_CYCLES=50000000,COMMIT_RETRY_CYCLES=2000000;
 reg [1:0] set_tries,commit_tries;
 reg [31:0] diagnostics_q;
 reg [3:0] bank_seen;reg [31:0] bank_seq[0:3];
 reg ah,wh;reg [31:0] wd;reg [3:0] st;
 reg aw_mode,aw_request;
 localparam WRITE_REJECT=0,WRITE_NOP=1,WRITE_MODE=2,WRITE_REQUEST=3;
 reg write_pending;reg [1:0] write_command;
 wire page_r=s_araddr[31:8]==24'h200200 && s_araddr[3:0]==0;
 wire busy=(phase!=IDLE && phase!=FAILED);
 wire remote_match=remote_payload[63:32]==epoch && remote_payload[31:24]=={7'd0,hd};
 wire [7:0] remote_type=remote_payload[15:8];
 // Codecs validate CRC/header/geometry. These checks also protect direct harnesses.
 wire geometry_ok=remote_payload[7:0]==1 && remote_payload[23:16]==5 &&
 remote_payload[79:64]==(hd?16'd1280:16'd640) &&
 remote_payload[95:80]==(hd?16'd720:16'd480) &&
 remote_payload[111:96]==16'd640 && remote_payload[127:112]==16'd480;
 wire all_banks=(&bank_seen) && frontier!=0 &&
 bank_seq[0]<=frontier && bank_seq[1]<=frontier && bank_seq[2]<=frontier && bank_seq[3]<=frontier;
 assign writer_hold=(phase!=IDLE && phase!=VERIFY && phase!=HEALTH_SEND && phase!=HEALTH_WAIT);
 assign health_valid=phase==HEALTH_SEND;
 assign health_request={epoch,fence_frontier};
 wire remote_error=remote_valid && remote_match && remote_type==5 && busy;
 wire remote_bad=remote_valid && remote_match && !geometry_ok && busy;
 wire expired=busy && timer==TIMEOUT_CYCLES-1;
 wire bad_raster=raster_done && (phase==VERIFY || phase==HEALTH_SEND || phase==HEALTH_WAIT || (phase==IDLE && state==4)) && raster_sequence<=frontier;
 wire transport_terminal=transport_fault && (phase==WAIT_READY || phase==ARM_SEND || phase==ARM_WAIT ||
  phase==COMMIT_SEND || phase==COMMIT_WAIT || phase==WAIT_RUNNING || phase==VERIFY || phase==HEALTH_SEND || phase==HEALTH_WAIT ||
  (phase==IDLE && epoch!=0));
 wire bad_certificate=phase==HEALTH_WAIT && health_reply_valid &&
  (health_reply[63:32]!=epoch || health_reply[31:0]!=fence_frontier || !health_reply[64]);
 wire fault_now=transport_terminal || remote_error || remote_bad || expired || bad_raster || bad_certificate;
 assign epoch_claim=!rst && !fault_now && ah && wh && write_pending && !s_bvalid && write_command==WRITE_REQUEST;
 assign epoch_claim_value=wd;
 assign cfg_valid=(phase==HOLD_SEND || phase==ARM_SEND);
 assign cfg_data={epoch,hd,phase==HOLD_SEND};
 assign tx_valid=(phase==SET_SEND || phase==COMMIT_SEND);
 assign tx_payload={32'd0,16'd480,16'd640,(hd?16'd720:16'd480),
                    (hd?16'd1280:16'd640),epoch,{7'd0,hd},8'd5,
                    (phase==SET_SEND?8'd1:8'd3),8'd1};
 assign s_awready=!ah && !s_bvalid;assign s_wready=!wh && !s_bvalid;
 assign s_arready=!s_rvalid;
 function [31:0] read_slot(input [7:0] off);
  begin case(off)
   8'h00:read_slot=32'h43355331;8'h10:read_slot=32'h301;
   8'h20:read_slot=requested_mode;8'h30:read_slot=transaction;
   8'h40:read_slot=state;8'h50:read_slot=completed;
   8'h60:read_slot=effective_mode?32'h050002d0:32'h028001e0;
   8'h70:read_slot=effective_mode?32'd1843200:32'd614400;
   8'h80:read_slot=effective_mode?32'd2560:32'd1280;
   8'h90:read_slot=effective_epoch;8'ha0:read_slot=32'h028001e0;
   8'hb0:read_slot=error_code;8'hc0:read_slot=frontier;
   8'hd0:read_slot=published_epoch;8'he0:read_slot=diagnostics;
   8'hf0:read_slot=generation;default:read_slot=0;
  endcase end
 endfunction
 task fail(input [31:0] code);
  begin phase<=FAILED;state<=5;error_code<=code;generation<=generation+2;end
 endtask
 integer j;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   phase<=REQUIRE_REQUEST?FAILED:IDLE;state<=REQUIRE_REQUEST?5:0;requested_mode<=0;effective_mode<=0;transaction<=0;completed<=0;
   effective_epoch<=0;published_epoch<=0;error_code<=REQUIRE_REQUEST?32'h1007:0;generation<=0;
    local_flush<=0;hd<=0;epoch<=0;timer<=0;frontier<=0;accepted_frames<=0;bank_seen<=0;diagnostics_q<=0;fence_frontier<=0;
   ah<=0;wh<=0;aw_mode<=0;aw_request<=0;write_pending<=0;write_command<=WRITE_REJECT;
   wd<=0;st<=0;s_bvalid<=0;s_bresp<=0;s_rvalid<=0;s_rdata<=0;s_rresp<=0;
   for(j=0;j<4;j=j+1) bank_seq[j]<=0;
  end else begin
   diagnostics_q<=diagnostics;
   if(diagnostics_q!=diagnostics) generation<=generation+2;
   if(s_awvalid && s_awready) begin
    ah<=1;
    aw_mode<=s_awaddr[31:8]==24'h200200 && s_awaddr[7:0]==8'h20;
    aw_request<=s_awaddr[31:8]==24'h200200 && s_awaddr[7:0]==8'h30;
   end
   if(s_wvalid && s_wready) begin wh<=1;wd<=s_wdata;st<=s_wstrb;end
   if(s_bvalid && s_bready) s_bvalid<=0;
   if(s_rvalid && s_rready) s_rvalid<=0;
   if(s_arvalid && s_arready) begin
    s_rvalid<=1;s_rresp<=page_r?0:2;s_rdata<=page_r?read_slot(s_araddr[7:0]):0;
   end
   if(busy) begin
    if(timer==TIMEOUT_CYCLES-1) fail(32'h1001);
    else timer<=timer+1'b1;
   end else timer<=0;
    // No proof/bank/geometry update may survive a terminal fault on this edge.
    // Prior sticky faults may still drain and clear through safe HOLD recovery.
    if(!fault_now)begin
    case(phase)
    IDLE:if(epoch!=0 && state==4 && raster_done) begin
     if(raster_sequence<=frontier) fail(32'h1006);
     else begin frontier<=raster_sequence;accepted_frames<=accepted_frames+1'b1;generation<=generation+2;end
    end
    DRAIN:if(optical_idle) begin local_flush<=1;hd<=requested_mode;phase<=HOLD_SEND;timer<=0;end
    HOLD_SEND:if(cfg_ready) phase<=HOLD_WAIT;
    HOLD_WAIT:if(cfg_ready) begin phase<=SET_SEND;timer<=0;end
    SET_SEND:if(tx_ready) phase<=SET_WAIT;
    SET_WAIT:if(tx_ready) begin phase<=WAIT_READY;timer<=0;end
    WAIT_READY:if(remote_valid && remote_match && remote_type==2 && geometry_ok) begin
     state<=2;phase<=ARM_SEND;timer<=0;generation<=generation+2;
    end else if(timer>=SET_RETRY_CYCLES-1 && set_tries<2'd2) begin
     set_tries<=set_tries+1'b1;phase<=SET_SEND;
    end
    ARM_SEND:if(cfg_ready) phase<=ARM_WAIT;
    ARM_WAIT:if(cfg_ready) begin local_flush<=0;phase<=COMMIT_SEND;timer<=0;end
    COMMIT_SEND:if(tx_ready) phase<=COMMIT_WAIT;
    COMMIT_WAIT:if(tx_ready) begin phase<=WAIT_RUNNING;timer<=0;end
    WAIT_RUNNING:if(remote_valid && remote_match && remote_type==4 && geometry_ok) begin
     state<=3;phase<=VERIFY;timer<=0;generation<=generation+2;
    end else if(timer>=COMMIT_RETRY_CYCLES-1 && commit_tries<2'd3) begin
     commit_tries<=commit_tries+1'b1;phase<=COMMIT_SEND;
    end
    VERIFY:begin
     if(raster_done) begin
      if(raster_sequence<=frontier) fail(32'h1006);
      else begin frontier<=raster_sequence;accepted_frames<=accepted_frames+1'b1;generation<=generation+2;end
     end
     if(commit5 && commit_epoch5==epoch && commit_sequence5!=0) begin bank_seen[bank5]<=1;bank_seq[bank5]<=commit_sequence5;end
     if(commit6 && commit_epoch6==epoch && commit_sequence6!=0) begin bank_seen[2+bank6]<=1;bank_seq[2+bank6]<=commit_sequence6;end
      if(all_banks && accepted_frames>=2 && !fault_now) begin fence_frontier<=frontier;phase<=HEALTH_SEND;timer<=0;end
     end
     HEALTH_SEND:if(health_ready && !fault_now)phase<=HEALTH_WAIT;
     HEALTH_WAIT:if(health_reply_valid && !fault_now)begin
      if(health_reply[63:32]!=epoch || health_reply[31:0]!=fence_frontier || !health_reply[64])fail(32'h1008);
      else if(all_banks && accepted_frames>=2)begin
       state<=4;phase<=IDLE;completed<=transaction;effective_mode<=hd;
       effective_epoch<=epoch;published_epoch<=epoch;error_code<=0;generation<=generation+2;
      end
     end
    endcase
    end
   // Link/CRC/drop faults cannot reset or cancel outstanding AXI obligations.
   // Hold SOF admission immediately; reset stays unchanged until next safe drain.
   // AXI writes are atomic after independent AW/W capture. Busy duplicates are
   // no-ops; busy conflicting epochs/modes return SLVERR without replacing work.
   if(ah && wh && !s_bvalid && !write_pending) begin
    write_pending<=1;write_command<=WRITE_REJECT;
    if(!fault_now) begin
     if(aw_mode) begin
      if(!st[0]) write_command<=WRITE_NOP;
      else if(!busy && wd[7:0]<=1) write_command<=WRITE_MODE;
     end else if(aw_request && st==4'hf && wd!=0) begin
      if(busy) begin if(wd==transaction) write_command<=WRITE_NOP;end
      else if(wd==completed && state==4 && requested_mode==effective_mode) write_command<=WRITE_NOP;
      else if(wd>epoch && (!REQUIRE_REQUEST || wd>reset_epoch_floor)) write_command<=WRITE_REQUEST;
     end
    end
   end
   if(ah && wh && !s_bvalid && write_pending) begin
    ah<=0;wh<=0;write_pending<=0;s_bvalid<=1;s_bresp<=0;
    if(fault_now || write_command==WRITE_REJECT) s_bresp<=2;
    else if(write_command==WRITE_MODE) begin requested_mode<=wd[0];generation<=generation+2;end
    else if(write_command==WRITE_REQUEST) begin
      transaction<=wd;epoch<=wd;phase<=DRAIN;state<=1;error_code<=0;published_epoch<=0;
      bank_seen<=0;frontier<=0;accepted_frames<=0;timer<=0;generation<=generation+2;
      set_tries<=0;commit_tries<=0;
      for(j=0;j<4;j=j+1) bank_seq[j]<=0;
    end
   end
   // Terminal fault priority is independent of the AXI command decode.
   if(transport_terminal) fail(32'h1002);
   if(remote_error) fail(32'h2000 | remote_payload[159:128]);
   if(remote_bad) fail(32'h1003);
   if(bad_raster) fail(32'h1006);
   if(bad_certificate) fail(32'h1008);
   if(busy && timer==TIMEOUT_CYCLES-1) fail(32'h1001);
  end
 end
endmodule
